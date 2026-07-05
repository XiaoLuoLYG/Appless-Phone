import { webview } from '@kit.ArkWeb';
import { aiLogInfo } from '@loop/agent-core';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_ERROR,
  COLOR_ERROR_SOFT,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_PAGE
} from '../style/A2uiHomeTheme';
import { A2uiButtonView } from './common/A2uiButtonView';

@Component
export struct PaymentCheckoutOverlay {
  @Prop url: string = '';
  onClose: () => void = () => {};
  onReturnUrl: (url: string) => void = (_url: string): void => {};
  @State progress: number = 0;
  @State errorText: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();

  private isAppPaymentReturnUrl(url: string): boolean {
    return url.trim().toLowerCase().startsWith('aiphone://payment/');
  }

  private providerName(): string {
    const lower = this.url.trim().toLowerCase();
    if (lower.indexOf('paypal.com') >= 0) {
      return 'PayPal';
    }
    if (lower.indexOf('stripe.com') >= 0 || lower.indexOf('buy.stripe.com') >= 0) {
      return 'Stripe';
    }
    return '支付供应商';
  }

  private domainText(): string {
    const lower = this.url.trim().toLowerCase();
    if (lower.indexOf('paypal.com') >= 0) {
      return 'paypal.com';
    }
    if (lower.indexOf('stripe.com') >= 0 || lower.indexOf('buy.stripe.com') >= 0) {
      return 'stripe.com';
    }
    return 'secure checkout';
  }

  private isLoading(): boolean {
    return this.progress > 0 && this.progress < 100 && this.errorText.length === 0;
  }

  private progressWidth(): string {
    const safeProgress = Math.max(8, Math.min(100, this.progress));
    return safeProgress.toString() + '%';
  }

  private mainFrameError(event: OnErrorReceiveEvent): boolean {
    return event.request !== undefined && event.request !== null && event.request.isMainFrame();
  }

  private mainFrameHttpError(event: OnHttpErrorReceiveEvent): boolean {
    return event.request !== undefined && event.request !== null && event.request.isMainFrame();
  }

  private webErrorText(event: OnErrorReceiveEvent): string {
    const code = event.error === undefined || event.error === null ? '' : event.error.getErrorCode().toString();
    const info = event.error === undefined || event.error === null ? '' : event.error.getErrorInfo();
    if (info.length > 0) {
      return '页面加载失败：' + info + (code.length > 0 ? ' (' + code + ')' : '');
    }
    return code.length > 0 ? '页面加载失败：' + code : '页面加载失败，请检查网络后重试。';
  }

  private httpErrorText(event: OnHttpErrorReceiveEvent): string {
    const code = event.response === undefined || event.response === null ? 0 : event.response.getResponseCode();
    const reason = event.response === undefined || event.response === null ? '' : event.response.getReasonMessage();
    if (code > 0) {
      return '支付页面返回 HTTP ' + code.toString() + (reason.length > 0 ? '：' + reason : '');
    }
    return '支付页面返回错误，请稍后重试。';
  }

  @Builder
  private ProviderMark() {
    Stack() {
      Text(this.providerName() === 'PayPal' ? 'PayPal' : (this.providerName() === 'Stripe' ? 'stripe' : 'Pay'))
        .fontSize(this.providerName() === 'PayPal' ? 10 : 12)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(48)
    .height(48)
    .borderRadius(14)
    .backgroundColor(this.providerName() === 'PayPal' ? '#003087' : (this.providerName() === 'Stripe' ? '#635BFF' : COLOR_ACCENT_DEEP))
  }

  @Builder
  private LoadingView() {
    Column() {
      Text('正在载入安全确认页')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_INK)
      Text(this.domainText())
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .margin({ top: 4 })
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .height(6)
          .width('100%')
          .borderRadius(3)
          .backgroundColor(COLOR_ACCENT_SOFT)
        Row()
          .height(6)
          .width(this.progressWidth())
          .borderRadius(3)
          .backgroundColor(COLOR_ACCENT)
      }
      .width('56%')
      .height(6)
      .margin({ top: 14 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(COLOR_PAGE)
  }

  @Builder
  private ErrorView() {
    Column() {
      Text('支付页面没有加载出来')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_ERROR)
      Text(this.errorText.length > 0 ? this.errorText : '请关闭后重新打开确认页。')
        .fontSize(13)
        .lineHeight(19)
        .fontColor(COLOR_INK)
        .textAlign(TextAlign.Center)
        .margin({ top: 8, left: 28, right: 28 })
      A2uiButtonView({
        label: '关闭',
        shape: 'pill',
        tone: 'danger'
      })
        .margin({ top: 16 })
        .onClick(() => {
          this.onClose();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(COLOR_ERROR_SOFT)
  }

  build() {
    Column() {
      Row() {
        this.ProviderMark()

        Column() {
          Text(this.providerName() + ' 确认')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('安全页面 · ' + this.domainText())
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
        }
          .layoutWeight(1)
          .margin({ left: 12, right: 12 })

        A2uiButtonView({
          label: '关闭',
          shape: 'pill',
          tone: 'secondary'
        })
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')
      .height(72)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 14, right: 12 })
      .backgroundColor(COLOR_CARD)
      .border({ width: { bottom: 1 }, color: COLOR_CARD_EDGE })

      Stack() {
        Web({ src: this.url, controller: this.controller })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .width('100%')
          .height('100%')
          .backgroundColor(COLOR_PAGE)
          .onPageBegin((event) => {
            const pageUrl = event === undefined || event === null ? '' : event.url;
            this.errorText = '';
            if (this.progress === 0 || this.progress === 100) {
              this.progress = 8;
            }
            aiLogInfo('[AIPhone][PaymentCheckoutPageBegin] urlChars=' + pageUrl.length.toString());
          })
          .onPageEnd((event) => {
            const pageUrl = event === undefined || event === null ? '' : event.url;
            this.progress = 100;
            aiLogInfo('[AIPhone][PaymentCheckoutPageEnd] urlChars=' + pageUrl.length.toString());
          })
          .onProgressChange((event) => {
            if (event !== undefined && event !== null) {
              this.progress = Math.max(this.progress, event.newProgress);
            }
          })
          .onErrorReceive((event) => {
            if (event !== undefined && event !== null && this.mainFrameError(event)) {
              this.errorText = this.webErrorText(event);
              aiLogInfo('[AIPhone][PaymentCheckoutError] ' + this.errorText);
            }
          })
          .onHttpErrorReceive((event) => {
            if (event !== undefined && event !== null && this.mainFrameHttpError(event)) {
              this.errorText = this.httpErrorText(event);
              aiLogInfo('[AIPhone][PaymentCheckoutHttpError] ' + this.errorText);
            }
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

        if (this.isLoading()) {
          this.LoadingView()
        }

        if (this.errorText.length > 0) {
          this.ErrorView()
        }
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(COLOR_PAGE)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_CARD)
  }
}
