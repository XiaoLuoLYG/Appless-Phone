import { webview } from '@kit.ArkWeb';
import { aiLogError, aiLogInfo } from '@loop/agent-core';
import { COLOR_CARD, COLOR_ERROR, COLOR_ERROR_SOFT, COLOR_INK, COLOR_MUTED, COLOR_PAGE } from '../../style/A2uiHomeTheme';
import { A2uiWebBridge, A2uiWebMessage } from './A2uiWebBridge';

export type A2uiWebSurfaceMode = 'html' | 'url';

export function shouldRunOneShotPageScript(
  pageScript: string,
  navigationId: number,
  completedNavigationId: number
): boolean {
  return pageScript.length > 0 && navigationId !== completedNavigationId;
}

interface PageScriptRetryProtocol { state?: string; stage?: string; progress?: string; }

export function boundedPageScriptRetryLimit(raw: string): number {
  try {
    const value = JSON.parse(raw) as PageScriptRetryProtocol;
    const keys = Object.keys(value).sort();
    if (JSON.stringify(keys) !== JSON.stringify(['progress', 'stage', 'state']) || value.state !== 'retry' ||
      typeof value.progress !== 'string' || value.progress.length === 0 || value.progress.length > 40) return 0;
    if (value.stage === 'query') return 20;
    if (value.stage === 'passenger' || value.stage === 'confirm') return 40;
  } catch (_error) {}
  return 0;
}

export function isBoundedPageScriptRetryExhausted(raw: string, attempts: number): boolean {
  const limit = boundedPageScriptRetryLimit(raw);
  return limit > 0 && attempts >= limit;
}

@Component
export struct A2uiWebSurfaceView {
  @Prop @Watch('onSourceChange') mode: A2uiWebSurfaceMode = 'html';
  @Prop @Watch('onSourceChange') html: string = '';
  @Prop @Watch('onSourceChange') url: string = '';
  @Prop baseUrl: string = 'https://aiphone.local/';
  @Prop bridgeName: string = 'A2uiWeb';
  @Prop allowPopup: boolean = false;
  @Prop mobileReadable: boolean = false;
  @Prop javaScriptEnabled: boolean = true;
  @Prop domStorageEnabled: boolean = true;
  @Prop showLoading: boolean = true;
  @Prop @Watch('onPageScriptChange') pageScript: string = '';
  @Prop @Watch('onPageScriptChange') pageScriptSession: number = 0;
  onMessage: (message: A2uiWebMessage) => void = (_message: A2uiWebMessage): void => {};
  onUrlIntercept: (url: string, isMainFrame: boolean) => boolean =
    (_url: string, _isMainFrame: boolean): boolean => false;
  onLoadEnd: (url: string) => void = (_url: string): void => {};
  onLoadError: (message: string) => void = (_message: string): void => {};
  onPageScriptResult: (result: string, sourceUrl: string) => void =
    (_result: string, _sourceUrl: string): void => {};
  private controller: webview.WebviewController = new webview.WebviewController();
  private popupController: webview.WebviewController = new webview.WebviewController();
  private bridge: A2uiWebBridge = new A2uiWebBridge();
  private webReady: boolean = false;
  private popupReady: boolean = false;
  private loadedHtml: string = '';
  private mainNavigationId: number = 0;
  private popupNavigationId: number = 0;
  private mainScriptNavigationId: number = -1;
  private popupScriptNavigationId: number = -1;
  private mainScriptSession: number = -1;
  private popupScriptSession: number = -1;
  private mainScriptAttempts: number = 0;
  private popupScriptAttempts: number = 0;
  private mainRetryTimer: number = -1;
  private popupRetryTimer: number = -1;
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

  onPageScriptChange(): void {
    if (this.webReady) {
      this.startPageScript(this.controller, this.mainNavigationId, false);
    }
    if (this.popupVisible && this.popupReady) {
      this.startPageScript(this.popupController, this.popupNavigationId, true);
    }
  }

  private cancelRetry(popup: boolean): void {
    const timer = popup ? this.popupRetryTimer : this.mainRetryTimer;
    if (timer >= 0) clearTimeout(timer);
    if (popup) this.popupRetryTimer = -1; else this.mainRetryTimer = -1;
  }

  private currentUrl(controller: webview.WebviewController): string {
    try { return controller.getUrl(); } catch (_error) { return ''; }
  }

  private startPageScript(
    controller: webview.WebviewController,
    navigationId: number,
    popup: boolean
  ): void {
    const completedNavigationId = popup ? this.popupScriptNavigationId : this.mainScriptNavigationId;
    const completedSession = popup ? this.popupScriptSession : this.mainScriptSession;
    if (this.pageScript.length === 0 || (navigationId === completedNavigationId &&
      completedSession === this.pageScriptSession)) {
      return;
    }
    this.cancelRetry(popup);
    if (popup) {
      this.popupScriptNavigationId = navigationId;
      this.popupScriptSession = this.pageScriptSession;
      this.popupScriptAttempts = 0;
    } else {
      this.mainScriptNavigationId = navigationId;
      this.mainScriptSession = this.pageScriptSession;
      this.mainScriptAttempts = 0;
    }
    this.runPageScript(controller, navigationId, this.pageScriptSession, popup);
  }

  private runPageScript(controller: webview.WebviewController, navigationId: number,
    session: number, popup: boolean): void {
    const attempts = (popup ? this.popupScriptAttempts : this.mainScriptAttempts) + 1;
    if (popup) this.popupScriptAttempts = attempts; else this.mainScriptAttempts = attempts;
    let execution: Promise<string>;
    try {
      execution = controller.runJavaScript(this.pageScript);
    } catch (_error) {
      this.onPageScriptResult('{"state":"needs_user","reason":"script_error"}', this.currentUrl(controller));
      return;
    }
    execution
      .then((result: string) => {
        const currentNavigationId = popup ? this.popupNavigationId : this.mainNavigationId;
        const currentSession = popup ? this.popupScriptSession : this.mainScriptSession;
        if (currentNavigationId !== navigationId || currentSession !== session) return;
        const limit = boundedPageScriptRetryLimit(result);
        if (limit === 0) {
          this.onPageScriptResult(result, this.currentUrl(controller));
          return;
        }
        if (isBoundedPageScriptRetryExhausted(result, attempts)) {
          this.onPageScriptResult('{"state":"needs_user","reason":"no_navigation"}',
            this.currentUrl(controller));
          return;
        }
        const timer = setTimeout(() => {
          const generationNow = popup ? this.popupNavigationId : this.mainNavigationId;
          const sessionNow = popup ? this.popupScriptSession : this.mainScriptSession;
          if (generationNow === navigationId && sessionNow === session) {
            this.runPageScript(controller, navigationId, session, popup);
          }
        }, 250);
        if (popup) this.popupRetryTimer = timer; else this.mainRetryTimer = timer;
      })
      .catch((_error: Error) => {
        const currentNavigationId = popup ? this.popupNavigationId : this.mainNavigationId;
        const currentSession = popup ? this.popupScriptSession : this.mainScriptSession;
        if (currentNavigationId === navigationId && currentSession === session) {
          aiLogError('[AIPhone][A2uiWebSurfacePageScriptError]');
          this.onPageScriptResult('{"state":"needs_user","reason":"script_error"}',
            this.currentUrl(controller));
        }
      });
  }

  private mainFrameError(event: OnErrorReceiveEvent): boolean {
    return event.request !== undefined && event.request !== null && event.request.isMainFrame();
  }

  private webErrorText(event: OnErrorReceiveEvent): string {
    const info = event.error === undefined || event.error === null ? '' : event.error.getErrorInfo();
    return info.length > 0 ? '页面加载失败：' + info : '页面加载失败，请检查网络后重试。';
  }

  private closePopup(): void {
    this.cancelRetry(true);
    this.popupNavigationId += 1;
    this.popupReady = false;
    this.popupVisible = false;
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
        .overviewModeAccess(!this.mobileReadable)
        .textZoomRatio(this.mobileReadable ? 130 : 100)
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
          this.cancelRetry(false);
          this.mainNavigationId += 1;
          this.loading = true;
          this.errorText = '';
        })
        .onPageEnd((event) => {
          const pageUrl = event === undefined || event === null ? '' : event.url;
          this.webReady = true;
          this.loading = false;
          this.loadHtmlIfNeeded();
          this.onLoadEnd(pageUrl);
          this.startPageScript(this.controller, this.mainNavigationId, false);
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
          const isMainFrame = request !== null && request.isMainFrame();
          return pageUrl.length > 0 ? this.onUrlIntercept(pageUrl, isMainFrame) : false;
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
                this.closePopup();
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
            .overviewModeAccess(!this.mobileReadable)
            .textZoomRatio(this.mobileReadable ? 130 : 100)
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(COLOR_PAGE)
            .onPageBegin(() => {
              this.cancelRetry(true);
              this.popupNavigationId += 1;
              this.popupReady = false;
            })
            .onPageEnd((event) => {
              const pageUrl = event === undefined || event === null ? '' : event.url;
              this.popupReady = true;
              this.onLoadEnd(pageUrl);
              this.startPageScript(this.popupController, this.popupNavigationId, true);
            })
            .onLoadIntercept((event) => {
              const request = event === undefined || event === null ? null : event.data;
              const pageUrl = request === null ? '' : request.getRequestUrl();
              const isMainFrame = request !== null && request.isMainFrame();
              return pageUrl.length > 0 ? this.onUrlIntercept(pageUrl, isMainFrame) : false;
            })
            .onWindowExit(() => {
              this.popupReady = false;
              this.closePopup();
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
