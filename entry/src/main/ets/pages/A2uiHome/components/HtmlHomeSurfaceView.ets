import { webview } from '@kit.ArkWeb';
import { A2uiAction } from '@loop/agent-core';
import { aiLogError, aiLogInfo } from '@loop/agent-core';
import { COLOR_PAGE } from '../style/A2uiHomeTheme';

type HtmlHomeActionValue = Object | string | number | boolean | null | undefined;

type HtmlHomePostedAction = Record<string, HtmlHomeActionValue>;

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
  @Prop @Watch('onHtmlOrBusyChange') html: string = '';
  @Prop @Watch('onMultiTaskPayloadChange') multiTaskPayloadJson: string = '';
  @Prop @Watch('onMultiTaskPayloadChange') multiTaskPayloadTick: number = 0;
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
  private webReady: boolean = false;
  private lastMailDetailEventJson: string = '';
  private lastMailReplyEventJson: string = '';
  private lastMailCalendarEventJson: string = '';
  private lastMultiTaskPayloadJson: string = '';
  private lastMultiTaskPayloadTick: number = -1;
  private appliedLuckinPatchTick: number = -1;
  @State private popupVisible: boolean = false;
  @State private popupTitle: string = '支付确认';

  aboutToAppear(): void {
    this.bridge.onAction = (action: A2uiAction): void => {
      this.onAction(action);
    };
  }

  private loadHtmlIfNeeded(): void {
    if (!this.webReady) {
      return;
    }
    const patchPending = this.luckinInlinePatchTick > this.appliedLuckinPatchTick &&
      this.luckinInlinePatchJson.length > 0;
    if (patchPending && this.html === this.loadedKey) {
      return;
    }
    if (this.html.length === 0 || this.html === this.loadedKey) {
      return;
    }
    try {
      this.webReady = false;
      this.controller.loadData(this.html, 'text/html', 'UTF-8', 'https://aiphone.local/');
      this.loadedKey = this.html;
      this.lastMailDetailEventJson = '';
      this.lastMailReplyEventJson = '';
      this.lastMailCalendarEventJson = '';
      this.lastMultiTaskPayloadJson = '';
      this.lastMultiTaskPayloadTick = -1;
      this.appliedLuckinPatchTick = this.luckinInlinePatchTick;
      aiLogInfo('[AIPhone][HtmlHomeSurfaceLoad] chars=' + this.html.length.toString() +
        ' renderTick=' + this.renderTick.toString() +
        ' busy=' + (this.isBusy ? 'true' : 'false'));
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeSurfaceLoadError] ' + JSON.stringify(error));
    }
  }

  onHtmlOrBusyChange(): void {
    this.loadHtmlIfNeeded();
  }

  onMultiTaskPayloadChange(): void {
    this.pushMultiTaskPayloadIfNeeded();
  }

  private pushMultiTaskPayloadIfNeeded(): void {
    if (!this.webReady || this.multiTaskPayloadJson.length === 0 ||
      (this.multiTaskPayloadJson === this.lastMultiTaskPayloadJson &&
        this.multiTaskPayloadTick === this.lastMultiTaskPayloadTick)) {
      return;
    }
    try {
      this.controller.runJavaScript(
        'if (window.__aiphoneApplyMultiTaskUpdate) { window.__aiphoneApplyMultiTaskUpdate(' + this.multiTaskPayloadJson + '); }'
      );
      this.lastMultiTaskPayloadJson = this.multiTaskPayloadJson;
      this.lastMultiTaskPayloadTick = this.multiTaskPayloadTick;
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeMultiTaskPushError] ' + JSON.stringify(error));
    }
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
    let script = '';
    try {
      const parsed = JSON.parse(this.luckinInlinePatchJson) as Record<string, Object | string | number | boolean | null | undefined>;
      if (parsed.kind === 'payment-status') {
        const sectionId = typeof parsed.sectionId === 'string' ? parsed.sectionId.trim() : '';
        if (sectionId.length > 0) {
          script = 'try{if(window.__aiphonePatchEmbeddedLuckinPaymentStatus){window.__aiphonePatchEmbeddedLuckinPaymentStatus(' +
            JSON.stringify(this.luckinInlinePatchJson) + ');}}catch(e){}';
        } else {
          script = 'try{if(window.AIPhoneHome&&AIPhoneHome.patchLuckinPaymentStatus){AIPhoneHome.patchLuckinPaymentStatus(' +
            JSON.stringify(this.luckinInlinePatchJson) + ');}}catch(e){}';
        }
      } else {
        script = 'try{if(window.AIPhoneHome&&AIPhoneHome.patchLuckinConfirm){AIPhoneHome.patchLuckinConfirm(' +
          JSON.stringify(this.luckinInlinePatchJson) + ');}}catch(e){}';
      }
    } catch (_error) {
      script = 'try{if(window.AIPhoneHome&&AIPhoneHome.patchLuckinConfirm){AIPhoneHome.patchLuckinConfirm(' +
        JSON.stringify(this.luckinInlinePatchJson) + ');}}catch(e){}';
    }
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
        .opacity(1)
        .onPageEnd(() => {
          this.webReady = true;
          this.loadHtmlIfNeeded();
          this.pushMultiTaskPayloadIfNeeded();
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
              Text(popupSubtitleFromTitle(this.popupTitle))
                .fontSize(12)
                .fontColor('#786E66')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 3 })
            }
            .layoutWeight(1)

            Button('返回')
              .height(36)
              .width(68)
              .fontSize(13)
              .fontColor('#493F38')
              .backgroundColor('#F5F2EE')
              .borderRadius(18)
              .onClick(() => {
                if (this.popupController.accessBackward()) {
                  this.popupController.backward();
                } else {
                  this.popupVisible = false;
                }
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
  if (lower.indexOf('google.com/maps/') >= 0 || lower.indexOf('maps.google.com/') >= 0) {
    return 'Google Maps 路线';
  }
  if (lower.indexOf('google') >= 0 || lower.indexOf('gpay') >= 0) {
    return 'Google Pay 确认';
  }
  if (lower.indexOf('paypal') >= 0) {
    return 'PayPal 确认';
  }
  return '支付确认';
}

function popupSubtitleFromTitle(title: string): string {
  return title === 'Google Maps 路线' ? '路线由 Google Maps 实时提供' : '安全确认页面';
}
