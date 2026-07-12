import { webview } from '@kit.ArkWeb';
import { aiLogError, aiLogInfo } from '@loop/agent-core';
import { COLOR_CARD, COLOR_ERROR, COLOR_ERROR_SOFT, COLOR_INK, COLOR_MUTED, COLOR_PAGE } from '../../style/A2uiHomeTheme';
import { A2uiWebBridge, A2uiWebMessage } from './A2uiWebBridge';

export type A2uiWebSurfaceMode = 'html' | 'url';

@Component
export struct A2uiWebSurfaceView {
  @Prop @Watch('onSourceChange') mode: A2uiWebSurfaceMode = 'html';
  @Prop @Watch('onSourceChange') html: string = '';
  @Prop @Watch('onSourceChange') url: string = '';
  @Prop baseUrl: string = 'https://aiphone.local/';
  @Prop bridgeName: string = 'A2uiWeb';
  @Prop allowPopup: boolean = false;
  @Prop javaScriptEnabled: boolean = true;
  @Prop domStorageEnabled: boolean = true;
  @Prop showLoading: boolean = true;
  onMessage: (message: A2uiWebMessage) => void = (_message: A2uiWebMessage): void => {};
  onUrlIntercept: (url: string) => boolean = (_url: string): boolean => false;
  onLoadEnd: (url: string) => void = (_url: string): void => {};
  onLoadError: (message: string) => void = (_message: string): void => {};
  private controller: webview.WebviewController = new webview.WebviewController();
  private popupController: webview.WebviewController = new webview.WebviewController();
  private bridge: A2uiWebBridge = new A2uiWebBridge();
  private webReady: boolean = false;
  private loadedHtml: string = '';
  @State private loading: boolean = true;
  @State private errorText: string = '';
  @State private popupVisible: boolean = false;

  aboutToAppear(): void {
    this.bridge.onMessage = (message: A2uiWebMessage): void => {
      this.onMessage(message);
    };
  }

  private startSrc(): string {
    if (this.mode === 'url' && this.url.trim().length > 0) {
      return this.url.trim();
    }
    return 'data:text/html;charset=utf-8,<body style="margin:0;background:%23F5F2EE"></body>';
  }

  private shouldLoadHtml(): boolean {
    return this.mode === 'html' && this.html.length > 0 && this.html !== this.loadedHtml;
  }

  private loadHtmlIfNeeded(): void {
    if (!this.webReady || !this.shouldLoadHtml()) {
      return;
    }
    try {
      this.loading = true;
      this.errorText = '';
      this.controller.loadData(this.html, 'text/html', 'UTF-8', this.baseUrl);
      this.loadedHtml = this.html;
      aiLogInfo('[AIPhone][A2uiWebSurfaceLoadHtml] chars=' + this.html.length.toString());
    } catch (error) {
      this.errorText = '页面载入失败';
      this.loading = false;
      aiLogError('[AIPhone][A2uiWebSurfaceLoadHtmlError] ' + JSON.stringify(error));
    }
  }

  onSourceChange(): void {
    if (this.mode === 'html') {
      this.loadHtmlIfNeeded();
    }
  }

  private mainFrameError(event: OnErrorReceiveEvent): boolean {
    return event.request !== undefined && event.request !== null && event.request.isMainFrame();
  }

  private webErrorText(event: OnErrorReceiveEvent): string {
    const info = event.error === undefined || event.error === null ? '' : event.error.getErrorInfo();
    return info.length > 0 ? '页面加载失败：' + info : '页面加载失败，请检查网络后重试。';
  }

  @Builder
  private LoadingView() {
    if (this.showLoading && this.loading && this.errorText.length === 0) {
      Column() {
        Text('正在载入')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(COLOR_PAGE)
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  @Builder
  private ErrorView() {
    if (this.errorText.length > 0) {
      Column() {
        Text('页面没有加载出来')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_ERROR)
        Text(this.errorText)
          .fontSize(12)
          .fontColor(COLOR_INK)
          .textAlign(TextAlign.Center)
          .lineHeight(18)
          .margin({ top: 8, left: 18, right: 18 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(COLOR_ERROR_SOFT)
    }
  }

  build() {
    Stack() {
      Web({ src: this.startSrc(), controller: this.controller })
        .javaScriptAccess(this.javaScriptEnabled)
        .domStorageAccess(this.domStorageEnabled)
        .multiWindowAccess(this.allowPopup)
        .allowWindowOpenMethod(this.allowPopup)
        .javaScriptProxy({
          object: this.bridge,
          name: this.bridgeName,
          methodList: ['postMessage'],
          controller: this.controller
        })
        .width('100%')
        .height('100%')
        .backgroundColor(COLOR_PAGE)
        .onPageBegin(() => {
          this.loading = true;
          this.errorText = '';
        })
        .onPageEnd((event) => {
          const pageUrl = event === undefined || event === null ? '' : event.url;
          this.webReady = true;
          this.loading = false;
          this.loadHtmlIfNeeded();
          this.onLoadEnd(pageUrl);
        })
        .onErrorReceive((event) => {
          if (event !== undefined && event !== null && this.mainFrameError(event)) {
            this.errorText = this.webErrorText(event);
            this.loading = false;
            this.onLoadError(this.errorText);
          }
        })
        .onLoadIntercept((event) => {
          const request = event === undefined || event === null ? null : event.data;
          const pageUrl = request === null ? '' : request.getRequestUrl();
          return pageUrl.length > 0 ? this.onUrlIntercept(pageUrl) : false;
        })
        .onWindowNew((event: OnWindowNewEvent) => {
          if (!this.allowPopup) {
            return;
          }
          this.popupVisible = true;
          event.handler.setWebController(this.popupController);
        })

      this.LoadingView()
      this.ErrorView()

      if (this.popupVisible) {
        Column() {
          Row() {
            Text('新窗口')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
              .layoutWeight(1)
            Button('关闭')
              .fontSize(12)
              .fontColor(COLOR_INK)
              .backgroundColor(COLOR_CARD)
              .borderRadius(16)
              .onClick(() => {
                this.popupVisible = false;
              })
          }
          .height(50)
          .width('100%')
          .padding({ left: 14, right: 12 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor(COLOR_CARD)

          Web({ src: 'about:blank', controller: this.popupController })
            .javaScriptAccess(this.javaScriptEnabled)
            .domStorageAccess(this.domStorageEnabled)
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(COLOR_PAGE)
            .onWindowExit(() => {
              this.popupVisible = false;
            })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(COLOR_PAGE)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PAGE)
  }
}
