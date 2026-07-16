import { webview } from '@kit.ArkWeb';
import { A2uiAction } from '@loop/agent-core';
import { aiLogError, aiLogInfo } from '@loop/agent-core';
import { COLOR_PAGE } from '../style/A2uiHomeTheme';
import {
  HtmlHomeSceneUpdate,
  HtmlHomeSceneUpdateListener,
  registerHtmlHomeSceneUpdateListener,
  unregisterHtmlHomeSceneUpdateListener
} from './HtmlHomeSceneUpdates';

type HtmlHomeActionValue = Object | string | number | boolean | null | undefined;

type HtmlHomePostedAction = Record<string, HtmlHomeActionValue>;

interface HtmlHomeDocumentVersion {
  surfaceId: string;
  sequence: number;
  status: string;
}

function parseHtmlHomeDocumentVersion(key: string): HtmlHomeDocumentVersion | null {
  const parts = key.split(':');
  if (parts.length !== 3) {
    return null;
  }
  const sequence = Number(parts[1]);
  if (parts[0].length === 0 || sequence < 0 || Math.floor(sequence) !== sequence) {
    return null;
  }
  return {
    surfaceId: parts[0],
    sequence: sequence,
    status: parts[2]
  };
}

function isBusyDocumentStatus(status: string): boolean {
  return status === 'thinking' || status === 'calling_tool';
}

function isSameOrStaleDocument(requestedKey: string, loadedKey: string): boolean {
  if (requestedKey === loadedKey) {
    return true;
  }
  const requested = parseHtmlHomeDocumentVersion(requestedKey);
  const loaded = parseHtmlHomeDocumentVersion(loadedKey);
  if (requested === null || loaded === null || requested.surfaceId !== loaded.surfaceId) {
    return false;
  }
  if (requested.sequence < loaded.sequence) {
    return true;
  }
  return isBusyDocumentStatus(requested.status) && isBusyDocumentStatus(loaded.status);
}

class HtmlHomeActionBridge {
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  postAction(raw: string): void {
    const action = parseHtmlHomeAction(raw);
    if (action !== null) {
      if (action.id === 'ride.map.route.log') {
        aiLogInfo('[AIPhone][RideMapRoute] ' + JSON.stringify(action.args));
        return;
      }
      if (action.id === 'luckin.pay.open' ||
        action.id === 'luckin.demo.alipay.open' ||
        action.id === 'luckin.demo.googlepay.open' ||
        action.id === 'luckin.order.status') {
        aiLogInfo('[AIPhone][HtmlHomePostAction] id=' + action.id +
          ' kind=' + action.kind +
          ' promptChars=' + action.prompt.length.toString());
      }
      this.onAction(action);
      return;
    }
    aiLogError('[AIPhone][HtmlHomePostActionParseError] rawChars=' + raw.length.toString());
  }
}

@Component
export struct HtmlHomeSurfaceView {
  @Prop surfaceId: string = '';
  @Prop @Watch('onHtmlOrBusyChange') html: string = '';
  @Prop @Watch('onHtmlOrBusyChange') documentKey: string = '';
  @Prop @Watch('onMailDetailEventChange') mailDetailEventJson: string = '';
  @Prop @Watch('onMailReplyEventChange') mailReplyEventJson: string = '';
  @Prop @Watch('onMailCalendarEventChange') mailCalendarEventJson: string = '';
  @Prop @Watch('onHtmlOrBusyChange') isBusy: boolean = false;
  @Prop @Watch('onHtmlOrBusyChange') renderTick: number = 0;
  @Prop luckinInlinePatchJson: string = '';
  @Prop @Watch('onLuckinPatchTickChange') luckinInlinePatchTick: number = 0;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};
  private controller: webview.WebviewController = new webview.WebviewController();
  private popupController: webview.WebviewController = new webview.WebviewController();
  private bridge: HtmlHomeActionBridge = new HtmlHomeActionBridge();
  private loadedKey: string = '';
  private loadedDocumentKey: string = '';
  private webReady: boolean = false;
  private busyFrameLoaded: boolean = false;
  private lastMailDetailEventJson: string = '';
  private lastMailReplyEventJson: string = '';
  private lastMailCalendarEventJson: string = '';
  private appliedLuckinPatchTick: number = -1;
  private pendingSceneUpdate: HtmlHomeSceneUpdate | null = null;
  private sceneUpdateListener: HtmlHomeSceneUpdateListener = (update: HtmlHomeSceneUpdate): void => {
    this.receiveSceneUpdate(update);
  };
  @State private documentLoading: boolean = false;
  @State private popupVisible: boolean = false;
  @State private popupTitle: string = '支付确认';

  aboutToAppear(): void {
    this.bridge.onAction = (action: A2uiAction): void => {
      this.onAction(action);
    };
    registerHtmlHomeSceneUpdateListener(this.surfaceId, this.sceneUpdateListener);
  }

  aboutToDisappear(): void {
    unregisterHtmlHomeSceneUpdateListener(this.surfaceId, this.sceneUpdateListener);
  }

  private receiveSceneUpdate(update: HtmlHomeSceneUpdate): void {
    if (update.surfaceId !== this.surfaceId || update.html.length === 0 ||
      isSameOrStaleDocument(update.documentKey, this.loadedDocumentKey)) {
      return;
    }
    if (!this.webReady || this.documentLoading) {
      this.pendingSceneUpdate = update;
      return;
    }
    this.rewriteSceneDocument(update);
  }

  private rewriteSceneDocument(update: HtmlHomeSceneUpdate): void {
    try {
      const encodedHtml = JSON.stringify(update.html);
      this.controller.runJavaScript(
        '(function(){var nextHtml=' + encodedHtml +
          ';document.open();document.write(nextHtml);document.close();})();'
      );
      this.loadedKey = update.html;
      this.loadedDocumentKey = update.documentKey;
      this.busyFrameLoaded = update.isBusy;
      this.pendingSceneUpdate = null;
      this.lastMailDetailEventJson = '';
      this.lastMailReplyEventJson = '';
      this.lastMailCalendarEventJson = '';
      aiLogInfo('[AIPhone][HtmlHomeSceneRewrite] surfaceId=' + update.surfaceId +
        ' chars=' + update.html.length.toString() +
        ' renderTick=' + update.renderTick.toString());
    } catch (error) {
      this.pendingSceneUpdate = update;
      aiLogError('[AIPhone][HtmlHomeSceneRewriteError] surfaceId=' + update.surfaceId +
        ' error=' + JSON.stringify(error));
    }
  }

  private applyPendingSceneUpdate(): void {
    const update = this.pendingSceneUpdate;
    if (update !== null && !this.documentLoading) {
      this.rewriteSceneDocument(update);
    }
  }

  private loadHtmlIfNeeded(): void {
    if (!this.webReady) {
      return;
    }
    const requestedKey = this.documentKey.length > 0 ? this.documentKey : this.html;
    const patchPending = this.luckinInlinePatchTick > this.appliedLuckinPatchTick &&
      this.luckinInlinePatchJson.length > 0;
    if (patchPending && isSameOrStaleDocument(requestedKey, this.loadedDocumentKey)) {
      return;
    }
    if (this.html.length === 0 || isSameOrStaleDocument(requestedKey, this.loadedDocumentKey)) {
      return;
    }
    if (this.isBusy && this.busyFrameLoaded) {
      return;
    }
    try {
      this.documentLoading = true;
      this.controller.loadData(this.html, 'text/html', 'UTF-8', 'https://aiphone.local/');
      this.loadedKey = this.html;
      this.loadedDocumentKey = requestedKey;
      this.lastMailDetailEventJson = '';
      this.lastMailReplyEventJson = '';
      this.lastMailCalendarEventJson = '';
      this.appliedLuckinPatchTick = this.luckinInlinePatchTick;
      if (this.isBusy) {
        this.busyFrameLoaded = true;
      }
      aiLogInfo('[AIPhone][HtmlHomeSurfaceLoad] chars=' + this.html.length.toString() +
        ' renderTick=' + this.renderTick.toString());
    } catch (error) {
      this.documentLoading = false;
      aiLogError('[AIPhone][HtmlHomeSurfaceLoadError] ' + JSON.stringify(error));
    }
  }

  onHtmlOrBusyChange(): void {
    if (!this.isBusy) {
      this.busyFrameLoaded = false;
    }
    this.loadHtmlIfNeeded();
  }

  private pushMailDetailEventIfNeeded(): void {
    if (!this.webReady || this.mailDetailEventJson.length === 0 ||
      this.mailDetailEventJson === this.lastMailDetailEventJson) {
      return;
    }
    try {
      const encoded = JSON.stringify(this.mailDetailEventJson);
      this.controller.runJavaScript(
        'if (window.__aiphoneApplyMailDetail) { window.__aiphoneApplyMailDetail(JSON.parse(' + encoded + ')); }'
      );
      this.lastMailDetailEventJson = this.mailDetailEventJson;
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeMailDetailPushError] ' + JSON.stringify(error));
    }
  }

  onMailDetailEventChange(): void {
    this.pushMailDetailEventIfNeeded();
  }

  private pushMailReplyEventIfNeeded(): void {
    if (!this.webReady || this.mailReplyEventJson.length === 0 ||
      this.mailReplyEventJson === this.lastMailReplyEventJson) {
      return;
    }
    try {
      const encoded = JSON.stringify(this.mailReplyEventJson);
      this.controller.runJavaScript(
        'if (window.__aiphoneApplyMailReply) { window.__aiphoneApplyMailReply(JSON.parse(' + encoded + ')); }'
      );
      this.lastMailReplyEventJson = this.mailReplyEventJson;
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeMailReplyPushError] ' + JSON.stringify(error));
    }
  }

  onMailReplyEventChange(): void {
    this.pushMailReplyEventIfNeeded();
  }

  private pushMailCalendarEventIfNeeded(): void {
    if (!this.webReady || this.mailCalendarEventJson.length === 0 ||
      this.mailCalendarEventJson === this.lastMailCalendarEventJson) {
      return;
    }
    try {
      const encoded = JSON.stringify(this.mailCalendarEventJson);
      this.controller.runJavaScript(
        'if (window.__aiphoneApplyMailCalendar) { window.__aiphoneApplyMailCalendar(JSON.parse(' + encoded + ')); }'
      );
      this.lastMailCalendarEventJson = this.mailCalendarEventJson;
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeMailCalendarPushError] ' + JSON.stringify(error));
    }
  }

  onMailCalendarEventChange(): void {
    this.pushMailCalendarEventIfNeeded();
  }

  onLuckinPatchTickChange(): void {
    this.tryApplyLuckinInlinePatch();
  }

  private tryApplyLuckinInlinePatch(): boolean {
    if (!this.webReady || this.luckinInlinePatchTick <= this.appliedLuckinPatchTick ||
      this.luckinInlinePatchJson.length === 0) {
      return false;
    }
    this.appliedLuckinPatchTick = this.luckinInlinePatchTick;
    const script = 'try{if(window.AIPhoneHome&&AIPhoneHome.patchLuckinConfirm){AIPhoneHome.patchLuckinConfirm(' +
      JSON.stringify(this.luckinInlinePatchJson) + ');}}catch(e){}';
    try {
      this.controller.runJavaScript(script);
      aiLogInfo('[AIPhone][HtmlHomeLuckinPatch] tick=' + this.luckinInlinePatchTick.toString());
      return true;
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeLuckinPatchError] ' + JSON.stringify(error));
      this.clearLuckinOptionUpdating();
      return false;
    }
  }

  private clearLuckinOptionUpdating(): void {
    try {
      this.controller.runJavaScript('try{if(window.AIPhoneHome&&AIPhoneHome.clearLuckinOptionUpdating){AIPhoneHome.clearLuckinOptionUpdating();}}catch(e){}');
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeLuckinUpdatingClearError] ' + JSON.stringify(error));
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Web({ src: 'data:text/html;charset=utf-8,<body style="margin:0;background:%23F5F2EE"></body>', controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .multiWindowAccess(true)
        .allowWindowOpenMethod(true)
        .javaScriptProxy({
          object: this.bridge,
          name: 'AIPhoneHome',
          methodList: ['postAction'],
          controller: this.controller
        })
        .width('100%')
        .height('100%')
        .backgroundColor(COLOR_PAGE)
        .opacity(this.documentLoading || (this.html.length > 0 &&
          (this.documentKey.length > 0 ? !isSameOrStaleDocument(this.documentKey, this.loadedDocumentKey) :
            this.html !== this.loadedKey)) ? 0 : 1)
        .onPageEnd(() => {
          const firstPage = !this.webReady;
          this.webReady = true;
          if (!firstPage) {
            this.documentLoading = false;
          }
          this.loadHtmlIfNeeded();
          if (!firstPage) {
            this.applyPendingSceneUpdate();
          }
          this.pushMailDetailEventIfNeeded();
          this.pushMailReplyEventIfNeeded();
          this.pushMailCalendarEventIfNeeded();
        })
        .onWindowNew((event: OnWindowNewEvent) => {
          this.popupTitle = popupTitleFromUrl(event.targetUrl);
          this.popupVisible = true;
          event.handler.setWebController(this.popupController);
          aiLogInfo('[AIPhone][HtmlHomeWindowNew] targetChars=' + event.targetUrl.length.toString() +
            ' userTrigger=' + event.isUserTrigger.toString());
        })

      if (this.popupVisible) {
        Column() {
          Row() {
            Column() {
              Text(this.popupTitle)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#211B17')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('安全弹窗 · 仍在 App 内')
                .fontSize(12)
                .fontColor('#786E66')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 3 })
            }
            .layoutWeight(1)

            Button('关闭')
              .height(36)
              .width(68)
              .fontSize(13)
              .fontColor('#493F38')
              .backgroundColor('#F5F2EE')
              .borderRadius(18)
              .onClick(() => {
                this.popupVisible = false;
              })
          }
          .width('100%')
          .height(64)
          .padding({ left: 14, right: 12 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor('#FFFAF4')

          Web({ src: 'about:blank', controller: this.popupController })
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .multiWindowAccess(true)
            .allowWindowOpenMethod(true)
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(COLOR_PAGE)
            .onWindowExit(() => {
              this.popupVisible = false;
              aiLogInfo('[AIPhone][HtmlHomeWindowExit]');
            })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(COLOR_PAGE)
      }

      Row()
        .width('100%')
        .height(8)
        .linearGradient({
          angle: 180,
          colors: [[COLOR_PAGE, 0], ['#00F5F2EE', 1]]
        })
        .hitTestBehavior(HitTestMode.Transparent)
    }
      .width('100%')
      .height('100%')
      .backgroundColor(COLOR_PAGE)
  }
}

function parseHtmlHomeAction(raw: string): A2uiAction | null {
  try {
    const parsed = JSON.parse(raw) as HtmlHomePostedAction;
    const keys = Object.keys(parsed);
    if (keys.indexOf('id') < 0 || keys.indexOf('label') < 0 ||
      keys.indexOf('prompt') < 0 || keys.indexOf('kind') < 0) {
      return null;
    }
    return {
      id: actionText(parsed['id']),
      label: actionText(parsed['label']),
      prompt: actionText(parsed['prompt']),
      variant: actionText(parsed['variant']),
      kind: actionText(parsed['kind']),
      args: actionObject(parsed['args'])
    };
  } catch (error) {
    return null;
  }
}

function actionText(value: HtmlHomeActionValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function actionObject(value: HtmlHomeActionValue): Object | undefined {
  if (value === undefined || value === null || typeof value !== 'object') {
    return undefined;
  }
  return value;
}

function popupTitleFromUrl(url: string): string {
  const lower = url.toLowerCase();
  if (lower.indexOf('google') >= 0 || lower.indexOf('gpay') >= 0) {
    return 'Google Pay 确认';
  }
  if (lower.indexOf('paypal') >= 0) {
    return 'PayPal 确认';
  }
  return '支付确认';
}
