import { webview } from '@kit.ArkWeb';
import { aiLogInfo } from '@loop/agent-core';
import {
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_INK,
  COLOR_PAGE
} from '../style/A2uiHomeTheme';
import { A2uiButtonView } from './common/A2uiButtonView';

@Component
export struct PaymentCheckoutOverlay {
  @Prop url: string = '';
  onClose: () => void = () => {};
  onReturnUrl: (url: string) => void = (_url: string): void => {};
  private controller: webview.WebviewController = new webview.WebviewController();

  private isAppPaymentReturnUrl(url: string): boolean {
    return url.trim().toLowerCase().startsWith('aiphone://payment/');
  }

  build() {
    Column() {
      Row() {
        A2uiButtonView({
          icon: $r('app.media.icon_back'),
          hasIcon: true,
          shape: 'circle',
          circleSize: 38,
          iconSize: 18,
          tone: 'secondary'
        })
          .onClick(() => {
            this.onClose();
          })

        Text('支付确认')
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 12, right: 12 })

        Text('')
          .width(38)
          .height(38)
      }
      .width('100%')
      .height(54)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 14, right: 14 })
      .backgroundColor(COLOR_CARD)
      .border({ width: { bottom: 1 }, color: COLOR_CARD_EDGE })

      Web({ src: this.url, controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(COLOR_PAGE)
        .onPageBegin((event) => {
          const pageUrl = event === undefined || event === null ? '' : event.url;
          aiLogInfo('[AIPhone][PaymentCheckoutPageBegin] urlChars=' + pageUrl.length.toString());
        })
        .onPageEnd((event) => {
          const pageUrl = event === undefined || event === null ? '' : event.url;
          aiLogInfo('[AIPhone][PaymentCheckoutPageEnd] urlChars=' + pageUrl.length.toString());
        })
        .onLoadIntercept((event) => {
          const request = event === undefined || event === null ? null : event.data;
          const pageUrl = request === null ? '' : request.getRequestUrl();
          if (this.isAppPaymentReturnUrl(pageUrl)) {
            aiLogInfo('[AIPhone][PaymentCheckoutReturnIntercept] urlChars=' + pageUrl.length.toString());
            this.onReturnUrl(pageUrl);
            return true;
          }
          return false;
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PAGE)
    .zIndex(20)
  }
}
