import { webview } from '@kit.ArkWeb';
import { aiLogError, aiLogInfo } from '@loop/agent-core';
import { COLOR_CARD, COLOR_ERROR, COLOR_ERROR_SOFT, COLOR_INK, COLOR_MUTED, COLOR_PAGE } from '../../style/A2uiHomeTheme';
import { A2uiWebBridge, A2uiWebMessage } from './A2uiWebBridge';

export type A2uiWebSurfaceMode = 'html' | 'url';
export type A2uiWebControllerIdentity = 'none' | 'main' | 'popup';

export interface A2uiWebExecutionOwnership {
  active: A2uiWebControllerIdentity;
  mainGeneration: number;
  popupGeneration: number;
  disposed: boolean;
}

export interface A2uiWebExecutionToken {
  controller: 'main' | 'popup';
  generation: number;
  session: number;
}

export interface A2uiWebNavigationBinding extends A2uiWebExecutionToken {
  url: string;
  ambiguous: boolean;
}

export function initialA2uiWebExecutionOwnership(): A2uiWebExecutionOwnership {
  return { active: 'main', mainGeneration: 0, popupGeneration: 0, disposed: false };
}

export function a2uiWebOwnershipAfterPopupOpen(state: A2uiWebExecutionOwnership): A2uiWebExecutionOwnership {
  return { active: 'popup', mainGeneration: state.mainGeneration + 1,
    popupGeneration: state.popupGeneration + 1, disposed: state.disposed };
}

export function a2uiWebOwnershipAfterPopupClose(state: A2uiWebExecutionOwnership): A2uiWebExecutionOwnership {
  return { active: 'main', mainGeneration: state.mainGeneration + 1,
    popupGeneration: state.popupGeneration + 1, disposed: state.disposed };
}

export function a2uiWebOwnershipAfterNavigationBegin(state: A2uiWebExecutionOwnership,
  controller: 'main' | 'popup'): A2uiWebExecutionOwnership {
  return { active: state.active,
    mainGeneration: controller === 'main' ? state.mainGeneration + 1 : state.mainGeneration,
    popupGeneration: controller === 'popup' ? state.popupGeneration + 1 : state.popupGeneration,
    disposed: state.disposed };
}

export function invalidateA2uiWebExecutionOwnership(state: A2uiWebExecutionOwnership,
  disposed: boolean = false): A2uiWebExecutionOwnership {
  return { active: disposed ? 'none' : state.active, mainGeneration: state.mainGeneration + 1,
    popupGeneration: state.popupGeneration + 1, disposed: disposed || state.disposed };
}

export function isCurrentA2uiWebExecutionToken(state: A2uiWebExecutionOwnership,
  token: A2uiWebExecutionToken): boolean {
  return !state.disposed && state.active === token.controller &&
    (token.controller === 'main' ? state.mainGeneration : state.popupGeneration) === token.generation;
}

export function a2uiWebExecutionTokenForRequest(state: A2uiWebExecutionOwnership,
  target: A2uiWebControllerIdentity, targetGeneration: number, session: number, script: string,
  mainReady: boolean, popupReady: boolean): A2uiWebExecutionToken | undefined {
  if (script.length === 0 || state.disposed || (state.active !== 'main' && state.active !== 'popup') ||
    state.active !== target) return undefined;
  const ready = state.active === 'main' ? mainReady : popupReady;
  const generation = state.active === 'main' ? state.mainGeneration : state.popupGeneration;
  return ready && generation === targetGeneration ?
    { controller: state.active, generation, session } as A2uiWebExecutionToken : undefined;
}

export function a2uiWebNavigationBindingForBegin(previous: A2uiWebNavigationBinding | undefined,
  state: A2uiWebExecutionOwnership, controller: 'main' | 'popup', session: number,
  url: string): A2uiWebNavigationBinding {
  return { controller, generation: controller === 'main' ? state.mainGeneration : state.popupGeneration,
    session, url, ambiguous: previous !== undefined && previous.controller === controller && previous.url === url };
}

export function a2uiWebNavigationTokenForEvent(state: A2uiWebExecutionOwnership,
  binding: A2uiWebNavigationBinding | undefined, eventUrl: string): A2uiWebExecutionToken | undefined {
  if (binding === undefined || binding.ambiguous || binding.url.length === 0 || binding.url !== eventUrl ||
    state.disposed) return undefined;
  const generation = binding.controller === 'main' ? state.mainGeneration : state.popupGeneration;
  return generation === binding.generation ? { controller: binding.controller,
    generation: binding.generation, session: binding.session } : undefined;
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
  @Prop @Watch('onPageScriptValueChange') pageScript: string = '';
  @Prop @Watch('onPageScriptRequest') pageScriptSession: number = 0;
  @Prop @Watch('onPageScriptRequest') pageScriptTarget: A2uiWebControllerIdentity = 'none';
  @Prop @Watch('onPageScriptRequest') pageScriptTargetGeneration: number = -1;
  @Prop @Watch('onPageScriptCancel') pageScriptCancelToken: number = 0;
  onMessage: (message: A2uiWebMessage) => void = (_message: A2uiWebMessage): void => {};
  onUrlIntercept: (url: string, isMainFrame: boolean) => boolean =
    (_url: string, _isMainFrame: boolean): boolean => false;
  onLoadEnd: (url: string, controller: 'main' | 'popup') => void =
    (_url: string, _controller: 'main' | 'popup'): void => {};
  onLoadError: (reason: string, controller: 'main' | 'popup', generation: number, session: number) => void =
    (_reason: string, _controller: 'main' | 'popup', _generation: number, _session: number): void => {};
  onActiveControllerChange: (controller: A2uiWebControllerIdentity, url: string, generation: number) => void =
    (_controller: A2uiWebControllerIdentity, _url: string, _generation: number): void => {};
  onPageScriptWillExecute: (sourceUrl: string, controller: 'main' | 'popup', generation: number,
    session: number) => string = (_sourceUrl: string, _controller: 'main' | 'popup',
      _generation: number, _session: number): string => '';
  onPageScriptResult: (result: string, sourceUrl: string, controller: 'main' | 'popup',
    generation: number, session: number) => void =
    (_result: string, _sourceUrl: string, _controller: 'main' | 'popup',
      _generation: number, _session: number): void => {};
  private controller: webview.WebviewController = new webview.WebviewController();
  private popupController: webview.WebviewController = new webview.WebviewController();
  private bridge: A2uiWebBridge = new A2uiWebBridge();
  private webReady: boolean = false;
  private popupReady: boolean = false;
  private loadedHtml: string = '';
  private ownership: A2uiWebExecutionOwnership = initialA2uiWebExecutionOwnership();
  private mainNavigationBinding: A2uiWebNavigationBinding | undefined = undefined;
  private popupNavigationBinding: A2uiWebNavigationBinding | undefined = undefined;
  private completedExecutionKey: string = '';
  @State private loading: boolean = true;
  @State private errorText: string = '';
  @State private popupVisible: boolean = false;

  aboutToAppear(): void {
    this.ownership = initialA2uiWebExecutionOwnership();
    this.mainNavigationBinding = undefined;
    this.popupNavigationBinding = undefined;
    this.bridge.onMessage = (message: A2uiWebMessage): void => {
      this.onMessage(message);
    };
  }

  aboutToDisappear(): void {
    this.invalidateAllExecutions(true);
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

  onPageScriptRequest(): void {
    this.executeActiveRequest();
  }

  onPageScriptValueChange(): void {
    if (this.pageScript.length === 0) this.invalidateAllExecutions(false);
  }

  onPageScriptCancel(): void {
    this.invalidateAllExecutions(false);
  }

  private currentUrl(controller: webview.WebviewController): string {
    try { return controller.getUrl(); } catch (_error) { return ''; }
  }

  private invalidateAllExecutions(disposed: boolean): void {
    this.ownership = invalidateA2uiWebExecutionOwnership(this.ownership, disposed);
    this.completedExecutionKey = '';
    if (disposed) {
      this.mainNavigationBinding = undefined;
      this.popupNavigationBinding = undefined;
    }
  }

  private executeActiveRequest(): void {
    if (this.pageScript.length === 0) {
      this.invalidateAllExecutions(false);
      return;
    }
    const token = a2uiWebExecutionTokenForRequest(this.ownership, this.pageScriptTarget,
      this.pageScriptTargetGeneration, this.pageScriptSession, this.pageScript, this.webReady, this.popupReady);
    if (token === undefined) return;
    const key = token.controller + ':' + token.generation.toString() + ':' + token.session.toString();
    if (key === this.completedExecutionKey) return;
    this.completedExecutionKey = key;
    const controller = token.controller === 'main' ? this.controller : this.popupController;
    const sourceUrl = this.currentUrl(controller);
    const blockedResult = this.onPageScriptWillExecute(sourceUrl, token.controller,
      token.generation, token.session);
    if (blockedResult.length > 0) {
      if (isCurrentA2uiWebExecutionToken(this.ownership, token)) {
        this.onPageScriptResult(blockedResult, sourceUrl, token.controller, token.generation, token.session);
      }
      return;
    }
    let execution: Promise<string>;
    try {
      execution = controller.runJavaScript(this.pageScript);
    } catch (_error) {
      if (isCurrentA2uiWebExecutionToken(this.ownership, token)) {
        this.onPageScriptResult('{"state":"needs_user","reason":"script_error"}', this.currentUrl(controller),
          token.controller, token.generation, token.session);
      }
      return;
    }
    execution
      .then((result: string) => {
        if (!isCurrentA2uiWebExecutionToken(this.ownership, token) ||
          this.pageScriptSession !== token.session) return;
        this.onPageScriptResult(result, this.currentUrl(controller), token.controller,
          token.generation, token.session);
      })
      .catch((_error: Error) => {
        if (isCurrentA2uiWebExecutionToken(this.ownership, token) && this.pageScriptSession === token.session) {
          aiLogError('[AIPhone][A2uiWebSurfacePageScriptError]');
          this.onPageScriptResult('{"state":"needs_user","reason":"script_error"}',
            this.currentUrl(controller), token.controller, token.generation, token.session);
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

  private notifyLoadError(controller: 'main' | 'popup', eventUrl: string): boolean {
    const binding = controller === 'main' ? this.mainNavigationBinding : this.popupNavigationBinding;
    const token = a2uiWebNavigationTokenForEvent(this.ownership, binding, eventUrl);
    if (token === undefined) return false;
    if (controller === 'main') this.mainNavigationBinding = undefined;
    else this.popupNavigationBinding = undefined;
    this.onLoadError('page_mismatch', token.controller, token.generation, token.session);
    return true;
  }

  private closePopup(): void {
    this.ownership = a2uiWebOwnershipAfterPopupClose(this.ownership);
    this.popupNavigationBinding = undefined;
    this.popupReady = false;
    this.popupVisible = false;
    this.onActiveControllerChange('main', this.webReady ? this.currentUrl(this.controller) : '',
      this.ownership.mainGeneration);
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
        .onPageBegin((event) => {
          const pageUrl = event === undefined || event === null ? '' : event.url;
          this.webReady = false;
          this.ownership = a2uiWebOwnershipAfterNavigationBegin(this.ownership, 'main');
          this.mainNavigationBinding = a2uiWebNavigationBindingForBegin(this.mainNavigationBinding,
            this.ownership, 'main', this.pageScriptSession, pageUrl);
          this.loading = true;
          this.errorText = '';
          if (this.ownership.active === 'main') {
            this.onActiveControllerChange('main', '', this.ownership.mainGeneration);
          }
        })
        .onPageEnd((event) => {
          const pageUrl = event === undefined || event === null ? '' : event.url;
          const token = a2uiWebNavigationTokenForEvent(this.ownership, this.mainNavigationBinding, pageUrl);
          if (token === undefined) return;
          this.mainNavigationBinding = undefined;
          this.webReady = true;
          this.loading = false;
          this.loadHtmlIfNeeded();
          this.onLoadEnd(pageUrl, 'main');
          if (this.ownership.active === 'main') {
            this.onActiveControllerChange('main', pageUrl, token.generation);
          }
        })
        .onErrorReceive((event) => {
          if (event !== undefined && event !== null && this.mainFrameError(event)) {
            if (this.notifyLoadError('main', event.request.getRequestUrl())) {
              this.errorText = this.webErrorText(event);
              this.loading = false;
              this.webReady = false;
            }
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
          this.ownership = a2uiWebOwnershipAfterPopupOpen(this.ownership);
          this.popupNavigationBinding = undefined;
          this.popupVisible = true;
          this.popupReady = false;
          this.onActiveControllerChange('popup', '', this.ownership.popupGeneration);
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
            .onPageBegin((event) => {
              const pageUrl = event === undefined || event === null ? '' : event.url;
              this.popupReady = false;
              this.ownership = a2uiWebOwnershipAfterNavigationBegin(this.ownership, 'popup');
              this.popupNavigationBinding = a2uiWebNavigationBindingForBegin(this.popupNavigationBinding,
                this.ownership, 'popup', this.pageScriptSession, pageUrl);
              if (this.ownership.active === 'popup') {
                this.onActiveControllerChange('popup', '', this.ownership.popupGeneration);
              }
            })
            .onPageEnd((event) => {
              const pageUrl = event === undefined || event === null ? '' : event.url;
              const token = a2uiWebNavigationTokenForEvent(this.ownership, this.popupNavigationBinding, pageUrl);
              if (token === undefined) return;
              this.popupNavigationBinding = undefined;
              this.popupReady = true;
              this.onLoadEnd(pageUrl, 'popup');
              if (this.ownership.active === 'popup') {
                this.onActiveControllerChange('popup', pageUrl, token.generation);
              }
            })
            .onLoadIntercept((event) => {
              const request = event === undefined || event === null ? null : event.data;
              const pageUrl = request === null ? '' : request.getRequestUrl();
              const isMainFrame = request !== null && request.isMainFrame();
              return pageUrl.length > 0 ? this.onUrlIntercept(pageUrl, isMainFrame) : false;
            })
            .onErrorReceive((event) => {
              if (event !== undefined && event !== null && this.mainFrameError(event)) {
                if (this.notifyLoadError('popup', event.request.getRequestUrl())) this.popupReady = false;
              }
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
