import { aiLogInfo, isAllowedHotelBookingNavigationUrl } from '@loop/agent-core';
import { COLOR_CARD, COLOR_CARD_EDGE, COLOR_ERROR, COLOR_ERROR_SOFT, COLOR_INK, COLOR_MUTED, COLOR_PAGE } from '../style/A2uiHomeTheme';
import { A2uiButtonView } from './common/A2uiButtonView';
import { A2uiWebSurfaceView } from './common/A2uiWebSurfaceView';

export type CheckoutWebKind = 'payment' | 'hotel';
export type CheckoutNavigationDecision = 'allow' | 'payment_return' | 'block';

export function checkoutWebNavigationDecision(
  kind: CheckoutWebKind,
  url: string,
  isMainFrame: boolean
): CheckoutNavigationDecision {
  if (!isMainFrame) {
    return 'allow';
  }
  const value = url.trim().toLowerCase();
  if (kind === 'payment' && value.startsWith('aiphone://payment/')) {
    return 'payment_return';
  }
  if (kind === 'hotel' && !isAllowedHotelBookingNavigationUrl(url)) {
    return 'block';
  }
  return 'allow';
}

@Component
export struct CheckoutWebOverlay {
  @Prop kind: CheckoutWebKind = 'payment';
  @Prop url: string = '';
  onClose: () => void = () => {};
  onReturnUrl: (url: string) => void = (_url: string): void => {};
  @State blockedNavigation: string = '';

  private title(): string {
    return this.kind === 'hotel' ? 'RollingGo 酒店预订' : '安全支付确认';
  }

  private domainText(): string {
    if (this.kind === 'hotel') {
      return 'rollinggo.cn';
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
      this.blockedNavigation = '已阻止离开 RollingGo 安全域名。';
      aiLogInfo('[AIPhone][HotelBookingNavigationBlocked] chars=' + url.length.toString());
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
          label: this.kind === 'hotel' ? '返回房型' : '关闭',
          shape: 'pill',
          tone: 'secondary'
        }).onClick(() => this.onClose())
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
        url: this.url,
        allowPopup: true,
        javaScriptEnabled: true,
        domStorageEnabled: true,
        onUrlIntercept: (url: string, isMainFrame: boolean): boolean => this.intercept(url, isMainFrame),
        onLoadEnd: (url: string): void => {
          aiLogInfo('[AIPhone][CheckoutWebLoadEnd] kind=' + this.kind + ' chars=' + url.length.toString());
        }
      }).layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PAGE)
  }
}
