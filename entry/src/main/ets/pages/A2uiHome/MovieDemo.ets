import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import router from '@ohos.router';
import util from '@ohos.util';
import { aiLogError, aiLogInfo } from '@loop/agent-core';
import {
  MOVIE_DEMO_MARKER,
  MOVIE_DEMO_RAWFILE,
  isTrustedMovieSourceUrl
} from './MovieDemoContract';

const MOVIE_BASE_URL: string = 'https://aiphone.movie.local/';

interface MovieAction {
  url?: string;
}

class MovieBridge {
  onOpenUrl: (url: string) => void = (_url: string): void => {};

  postAction(raw: string): void {
    try {
      const action = JSON.parse(raw) as MovieAction;
      const url = action.url === undefined || action.url === null ? '' : action.url.toString();
      if (isTrustedMovieSourceUrl(url)) {
        this.onOpenUrl(url);
      }
    } catch (_error) {
    }
  }
}

@Entry
@Component
struct MovieDemo {
  @State errorText: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: MovieBridge = new MovieBridge();
  private loaded: boolean = false;

  aboutToAppear(): void {
    this.bridge.onOpenUrl = (url: string): void => {
      this.openExternalUrl(url);
    };
  }

  private loadMovieHtml(): void {
    if (this.loaded) {
      return;
    }
    this.loaded = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const bytes = context.resourceManager.getRawFileContentSync(MOVIE_DEMO_RAWFILE);
      const html = util.TextDecoder.create('utf-8').decodeToString(bytes);
      this.controller.loadData(html, 'text/html', 'UTF-8', MOVIE_BASE_URL);
      this.errorText = '';
      aiLogInfo('[AIPhone][MovieDemoLoad] marker=' + MOVIE_DEMO_MARKER + ' chars=' + html.length.toString());
    } catch (error) {
      this.loaded = false;
      this.errorText = '电影页面加载失败，请返回后重试。';
      aiLogError('[AIPhone][MovieDemoLoadError] ' + JSON.stringify(error));
    }
  }

  private async openExternalUrl(url: string): Promise<void> {
    if (!isTrustedMovieSourceUrl(url)) {
      return;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: url
      });
    } catch (error) {
      const businessError = error as BusinessError;
      this.errorText = '官方来源打开失败：' + businessError.message;
      aiLogError('[AIPhone][MovieDemoOpenUrlError] message=' + businessError.message);
    }
  }

  build() {
    Column() {
      Row() {
        Button('返回')
          .height(38)
          .width(68)
          .fontSize(13)
          .fontColor('#F3F0EA')
          .backgroundColor('#242321')
          .borderRadius(18)
          .border({ width: 1, color: '#403E3A' })
          .onClick(() => {
            router.back();
          })

        Text('电影')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F3F0EA')
          .margin({ left: 12 })
          .layoutWeight(1)

        Text('NOW')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FF765F')
          .letterSpacing(1.2)
      }
      .width('100%')
      .height(54)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 14, right: 18 })
      .backgroundColor('#151513')

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(12)
          .fontColor('#FF9582')
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .backgroundColor('#2B1E1B')
      }

      Web({
        src: 'data:text/html;charset=utf-8,<body style="margin:0;background:%23151513"></body>',
        controller: this.controller
      })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .javaScriptProxy({
          object: this.bridge,
          name: 'AIPhoneMovie',
          methodList: ['postAction'],
          controller: this.controller
        })
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#151513')
        .onPageEnd(() => {
          this.loadMovieHtml();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#151513')
  }
}
