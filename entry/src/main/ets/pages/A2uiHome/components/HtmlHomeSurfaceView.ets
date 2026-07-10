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
      this.onAction(action);
    }
  }
}

@Component
export struct HtmlHomeSurfaceView {
  @Prop @Watch('onRenderStateChange') html: string = '';
  @Prop @Watch('onMailDetailEventChange') mailDetailEventJson: string = '';
  @Prop @Watch('onMailReplyEventChange') mailReplyEventJson: string = '';
  @Prop @Watch('onRenderStateChange') isBusy: boolean = false;
  @Prop renderTick: number = 0;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};
  private controller: webview.WebviewController = new webview.WebviewController();
  private popupController: webview.WebviewController = new webview.WebviewController();
  private bridge: HtmlHomeActionBridge = new HtmlHomeActionBridge();
  private loadedKey: string = '';
  private webReady: boolean = false;
  private busyFrameLoaded: boolean = false;
  private lastMailDetailEventJson: string = '';
  private lastMailReplyEventJson: string = '';
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
    if (this.html.length === 0 || this.html === this.loadedKey) {
      return;
    }
    if (this.isBusy && this.busyFrameLoaded) {
      return;
    }
    try {
      this.controller.loadData(this.html, 'text/html', 'UTF-8', 'https://aiphone.local/');
      this.loadedKey = this.html;
      this.lastMailDetailEventJson = '';
      this.lastMailReplyEventJson = '';
      if (this.isBusy) {
        this.busyFrameLoaded = true;
      }
      aiLogInfo('[AIPhone][HtmlHomeSurfaceLoad] chars=' + this.html.length.toString() +
        ' renderTick=' + this.renderTick.toString());
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeSurfaceLoadError] ' + JSON.stringify(error));
    }
  }

  onRenderStateChange(): void {
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
          this.pushMailDetailEventIfNeeded();
          this.pushMailReplyEventIfNeeded();
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
