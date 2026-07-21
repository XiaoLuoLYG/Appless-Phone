import { aiLogError, aiLogInfo, isAllowedHotelBookingNavigationUrl } from '@loop/agent-core';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { webview } from '@kit.ArkWeb';
import { url as arkUrl } from '@kit.ArkTS';
import {
  transitionTrainPresaleHandoff,
  TRAIN_PRESALE_PENDING_TASK_KEY,
  TRAIN_PRESALE_HANDOFF_EVENT,
  TrainPresaleHandoffTransitionResult
} from '../../../entryability/EntryAbility';
import {
  buildTrainPresaleFinalConfirmScript,
  parseTrainWebAssistOutcome,
  trainPresaleWebAssistScriptForCheckout,
  trainWebAssistReasonText,
  trainWebAssistTargetState,
  TrainWebAssistOutcome
} from '../train/TrainPresaleWebAutomation';
import {
  TRAIN_PRESALE_TASK_STORE_NAME,
  TrainPresaleTask,
  TrainPresaleTaskState,
  TrainPresaleTaskStore
} from '../train/TrainPresaleTaskStore';
import { COLOR_CARD, COLOR_CARD_EDGE, COLOR_ERROR, COLOR_ERROR_SOFT, COLOR_INK, COLOR_MUTED, COLOR_PAGE } from '../style/A2uiHomeTheme';
import { A2uiButtonView } from './common/A2uiButtonView';
import { A2uiWebSurfaceView } from './common/A2uiWebSurfaceView';

export type CheckoutWebKind = 'payment' | 'hotel' | 'train';
export type CheckoutNavigationDecision = 'allow' | 'payment_return' | 'block';

export function isAllowed12306BookingUrl(url: string): boolean {
  try {
    const parsed = new arkUrl.URL(url.trim());
    if (parsed.protocol.length > 0) {
      return parsed.protocol.toLowerCase() === 'https:' &&
        parsed.hostname.toLowerCase() === 'kyfw.12306.cn' &&
        parsed.port.length === 0 &&
        parsed.username.length === 0 &&
        parsed.password.length === 0 &&
        parsed.pathname === '/otn/leftTicket/init';
    }
  } catch (_error) {}
  const value = url.trim();
  const authority = 'https://kyfw.12306.cn';
  if (!value.toLowerCase().startsWith(authority)) {
    return false;
  }
  const suffix = value.substring(authority.length);
  const path = '/otn/leftTicket/init';
  if (!suffix.startsWith(path)) {
    return false;
  }
  const tail = suffix.substring(path.length);
  return tail.length === 0 || tail.startsWith('?') || tail.startsWith('#');
}

export function checkoutWebInitialSource(kind: CheckoutWebKind, url: string): string {
  return kind === 'train' && !isAllowed12306BookingUrl(url) ? '' : url;
}

export function checkoutWebMobileReadable(kind: CheckoutWebKind): boolean {
  return kind === 'train';
}

export function isOfficial12306PaymentUrl(value: string): boolean {
  try {
    const parsed = new arkUrl.URL(value.trim());
    if (parsed.protocol.length > 0) {
      return parsed.protocol.toLowerCase() === 'https:' && parsed.port.length === 0 &&
        parsed.username.length === 0 && parsed.password.length === 0 &&
        (parsed.hostname.toLowerCase() === 'epay.12306.cn' ||
          (parsed.hostname.toLowerCase() === 'kyfw.12306.cn' && parsed.pathname.indexOf('/payOrder/') === 0));
    }
  } catch (_error) {}
  // ponytail: local Hypium URL stubs do not parse absolute URLs, so retain a small exact fallback.
  const normalized = value.trim().toLowerCase();
  if (!normalized.startsWith('https://')) return false;
  const afterScheme = normalized.substring(8);
  let authorityEnd = afterScheme.length;
  const slash = afterScheme.indexOf('/');
  const query = afterScheme.indexOf('?');
  const fragment = afterScheme.indexOf('#');
  if (slash >= 0 && slash < authorityEnd) authorityEnd = slash;
  if (query >= 0 && query < authorityEnd) authorityEnd = query;
  if (fragment >= 0 && fragment < authorityEnd) authorityEnd = fragment;
  const authority = afterScheme.substring(0, authorityEnd);
  const path = slash >= 0 ? afterScheme.substring(slash) : '';
  return authority === 'epay.12306.cn' || (authority === 'kyfw.12306.cn' && path.indexOf('/payorder/') === 0);
}

export function checkoutWebNavigationDecision(
  kind: CheckoutWebKind,
  url: string,
  isMainFrame: boolean
): CheckoutNavigationDecision {
  const value = url.trim().toLowerCase();
  if (kind === 'train' && !value.startsWith('https://')) {
    return 'block';
  }
  if (!isMainFrame) {
    return 'allow';
  }
  if (kind === 'payment' && value.startsWith('aiphone://payment/')) {
    return 'payment_return';
  }
  if (kind === 'hotel' && !isAllowedHotelBookingNavigationUrl(url)) {
    return 'block';
  }
  return 'allow';
}

export function webHostForDisplay(url: string): string {
  try {
    const hostname = new arkUrl.URL(url.trim()).hostname;
    if (hostname.length > 0) {
      return hostname;
    }
  } catch (_error) {}
  // ponytail: local Hypium stubs return an empty native URL; remove this fallback when they parse absolute URLs.
  const value = url.trim();
  const schemeEnd = value.indexOf('://');
  if (schemeEnd <= 0) {
    return '未加载';
  }
  const start = schemeEnd + 3;
  let end = value.length;
  const path = value.indexOf('/', start);
  const query = value.indexOf('?', start);
  const fragment = value.indexOf('#', start);
  if (path >= 0 && path < end) {
    end = path;
  }
  if (query >= 0 && query < end) {
    end = query;
  }
  if (fragment >= 0 && fragment < end) {
    end = fragment;
  }
  const authority = value.substring(start, end);
  const userInfoEnd = authority.lastIndexOf('@');
  const hostAndPort = authority.substring(userInfoEnd + 1);
  if (hostAndPort.startsWith('[')) {
    const bracketEnd = hostAndPort.indexOf(']');
    return bracketEnd > 1 ? hostAndPort.substring(0, bracketEnd + 1).toLowerCase() : '未加载';
  }
  const portStart = hostAndPort.lastIndexOf(':');
  const hostname = portStart >= 0 ? hostAndPort.substring(0, portStart) : hostAndPort;
  return hostname.length > 0 && hostname.indexOf(' ') < 0 && hostname.indexOf('\\') < 0 ?
    hostname.toLowerCase() : '未加载';
}

@Component
export struct CheckoutWebOverlay {
  @Prop kind: CheckoutWebKind = 'payment';
  @Prop url: string = '';
  @Prop taskId: string = '';
  onClose: (taskId: string) => void = (_taskId: string): void => {};
  onReturnUrl: (url: string) => void = (_url: string): void => {};
  @State blockedNavigation: string = '';
  @State currentUrl: string = '';
  @State assistScript: string = '';
  @State assistScriptSession: number = 0;

  aboutToAppear(): void {
    this.assistScript = this.trainAssistScript();
  }

  private trainPreferences(): preferences.Preferences | null {
    if (this.kind !== 'train' || this.taskId.length === 0) {
      return null;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.Context;
      return preferences.getPreferencesSync(context, { name: TRAIN_PRESALE_TASK_STORE_NAME });
    } catch (_error) {
      aiLogError('[AIPhone][TrainWebAssistStore] ok=false');
      return null;
    }
  }

  private trainAssistScript(): string {
    const nativeStore = this.trainPreferences();
    if (nativeStore === null) {
      return '';
    }
    const task: TrainPresaleTask | undefined = new TrainPresaleTaskStore(nativeStore).get(this.taskId);
    return trainPresaleWebAssistScriptForCheckout(this.kind, this.taskId, task);
  }

  private saveTrainCookies(): void {
    if (this.kind !== 'train') {
      return;
    }
    webview.WebCookieManager.saveCookieAsync()
      .catch((_error: Error) => {
        aiLogError('[AIPhone][TrainWebCookieSave] ok=false');
      });
  }

  private close(): void {
    this.saveTrainCookies();
    this.onClose(this.taskId);
  }

  private handleAssistResult(raw: string, sourceUrl: string): void {
    if (this.assistScript.length === 0 || this.taskId.length === 0) {
      return;
    }
    const outcome: TrainWebAssistOutcome = parseTrainWebAssistOutcome(raw);
    if (outcome.state === 'retry') {
      return;
    }
    if (outcome.state === 'ready_to_confirm') {
      const nativeStore = this.trainPreferences();
      if (nativeStore === null) {
        this.assistScript = '';
        return;
      }
      const pendingValue = nativeStore.getSync(TRAIN_PRESALE_PENDING_TASK_KEY, '');
      const pending = typeof pendingValue === 'string' ? pendingValue.trim() : '';
      const current = new TrainPresaleTaskStore(nativeStore).get(this.taskId);
      if (pending !== this.taskId || current === undefined || current.taskId !== this.taskId ||
        current.state !== 'executing' || !current.unpaidOrderAuthorized) {
        this.handleAssistResult('{"state":"needs_user","reason":"not_authorized"}', sourceUrl);
        return;
      }
      this.assistScript = buildTrainPresaleFinalConfirmScript(current);
      this.assistScriptSession += 1;
      return;
    }
    if (outcome.state === 'awaiting_payment' && !isOfficial12306PaymentUrl(sourceUrl)) {
      this.handleAssistResult('{"state":"needs_user","reason":"page_mismatch"}', sourceUrl);
      return;
    }
    const targetState: TrainPresaleTaskState | undefined = trainWebAssistTargetState(outcome);
    if (targetState === undefined) {
      return;
    }
    this.assistScript = '';
    const nativeStore = this.trainPreferences();
    if (nativeStore === null) {
      return;
    }
    const reason = outcome.state === 'needs_user' ? trainWebAssistReasonText(outcome.reason) : '';
    try {
      const transition: TrainPresaleHandoffTransitionResult = transitionTrainPresaleHandoff(
        nativeStore, this.taskId, targetState, reason);
      if (transition.task === undefined || transition.task.state !== targetState || !transition.cleared) {
        aiLogError('[AIPhone][TrainWebAssistTransition] ok=false');
        return;
      }
      const context = this.getUIContext().getHostContext() as common.Context;
      context.getApplicationContext().eventHub.emit(TRAIN_PRESALE_HANDOFF_EVENT);
      aiLogInfo('[AIPhone][TrainWebAssistTransition] state=' + targetState);
    } catch (_error) {
      aiLogError('[AIPhone][TrainWebAssistTransition] ok=false');
    }
  }

  private title(): string {
    if (this.kind === 'train') {
      return '12306 官方购票';
    }
    return this.kind === 'hotel' ? 'RollingGo 酒店预订' : '安全支付确认';
  }

  private closeLabel(): string {
    if (this.kind === 'train') {
      return '返回车次';
    }
    return this.kind === 'hotel' ? '返回房型' : '关闭';
  }

  private domainText(): string {
    if (this.kind === 'hotel') {
      return 'rollinggo.cn';
    }
    if (this.kind === 'train') {
      const activeUrl = this.currentUrl.length > 0 ? this.currentUrl : checkoutWebInitialSource(this.kind, this.url);
      return webHostForDisplay(activeUrl);
    }
    const lower = this.url.trim().toLowerCase();
    return lower.indexOf('paypal.com') >= 0 ? 'paypal.com' :
      (lower.indexOf('stripe.com') >= 0 ? 'stripe.com' : 'secure checkout');
  }

  private intercept(url: string, isMainFrame: boolean): boolean {
    const decision = checkoutWebNavigationDecision(this.kind, url, isMainFrame);
    if (decision === 'payment_return') {
      this.onReturnUrl(url);
      return true;
    }
    if (decision === 'block') {
      if (this.kind === 'train') {
        this.blockedNavigation = '已阻止离开安全的 HTTPS 页面。';
        aiLogInfo('[AIPhone][TrainBookingNavigationBlocked] chars=' + url.length.toString());
      } else {
        this.blockedNavigation = '已阻止离开 RollingGo 安全域名。';
        aiLogInfo('[AIPhone][HotelBookingNavigationBlocked] chars=' + url.length.toString());
      }
      return true;
    }
    this.blockedNavigation = '';
    return false;
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.title()).fontSize(15).fontWeight(FontWeight.Bold).fontColor(COLOR_INK)
          Text('安全页面 · ' + this.domainText()).fontSize(12).fontColor(COLOR_MUTED).margin({ top: 3 })
        }.layoutWeight(1).margin({ left: 14, right: 12 })
        A2uiButtonView({
          label: this.closeLabel(),
          shape: 'pill',
          tone: 'secondary'
        }).onClick(() => this.close())
      }
      .width('100%')
      .height(72)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 12, right: 12 })
      .backgroundColor(COLOR_CARD)
      .border({ width: { bottom: 1 }, color: COLOR_CARD_EDGE })

      if (this.blockedNavigation.length > 0) {
        Text(this.blockedNavigation)
          .width('100%')
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .fontSize(12)
          .fontColor(COLOR_ERROR)
          .backgroundColor(COLOR_ERROR_SOFT)
      }

      A2uiWebSurfaceView({
        mode: 'url',
        url: checkoutWebInitialSource(this.kind, this.url),
        mobileReadable: checkoutWebMobileReadable(this.kind),
        allowPopup: true,
        javaScriptEnabled: true,
        domStorageEnabled: true,
        pageScript: this.assistScript,
        pageScriptSession: this.assistScriptSession,
        onPageScriptResult: (result: string, sourceUrl: string): void =>
          this.handleAssistResult(result, sourceUrl),
        onUrlIntercept: (url: string, isMainFrame: boolean): boolean => this.intercept(url, isMainFrame),
        onLoadEnd: (url: string): void => {
          this.currentUrl = url;
          if (this.kind === 'train' && url.trim().toLowerCase().startsWith('https://kyfw.12306.cn/')) {
            this.saveTrainCookies();
          }
          aiLogInfo('[AIPhone][CheckoutWebLoadEnd] kind=' + this.kind + ' chars=' + url.length.toString());
        }
      }).layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PAGE)
  }
}
