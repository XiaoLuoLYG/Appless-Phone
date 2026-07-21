import { aiLogInfo, isAllowedHotelBookingNavigationUrl } from '@loop/agent-core';
import { COLOR_CARD, COLOR_CARD_EDGE, COLOR_ERROR, COLOR_ERROR_SOFT, COLOR_INK, COLOR_MUTED, COLOR_PAGE } from '../style/A2uiHomeTheme';
import { A2uiButtonView } from './common/A2uiButtonView';
import { A2uiWebSurfaceView } from './common/A2uiWebSurfaceView';

export type CheckoutWebKind = 'payment' | 'hotel' | 'train';
export type CheckoutNavigationDecision = 'allow' | 'payment_return' | 'block';

export function isAllowed12306BookingUrl(url: string): boolean {
  const value = url.trim();
  const authority = 'https://kyfw.12306.cn';
  const lower = value.toLowerCase();
  if (!lower.startsWith(authority)) {
    return false;
  }
  const suffix = value.substring(authority.length);
  const path = '/otn/leftTicket/init';
  if (!suffix.startsWith(path)) {
    return false;
  }
  const tail = suffix.substring(path.length);
  return tail.length === 0 || tail.startsWith('?') || tail.startsWith('#');
}

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
  if (kind === 'train' && !value.startsWith('https://')) {
    return 'block';
  }
  return 'allow';
}

function webHostForDisplay(url: string): string {
  const value = url.trim();
  const schemeEnd = value.indexOf('://');
  if (schemeEnd < 0) {
    return '';
  }
  const start = schemeEnd + 3;
  let end = value.indexOf('/', start);
  if (end < 0) {
    end = value.length;
  }
  const query = value.indexOf('?', start);
  if (query >= 0 && query < end) {
    end = query;
  }
  const fragment = value.indexOf('#', start);
  if (fragment >= 0 && fragment < end) {
    end = fragment;
  }
  return value.substring(start, end);
}

@Component
export struct CheckoutWebOverlay {
  @Prop kind: CheckoutWebKind = 'payment';
  @Prop url: string = '';
  onClose: () => void = () => {};
  onReturnUrl: (url: string) => void = (_url: string): void => {};
  @State blockedNavigation: string = '';
  @State currentUrl: string = '';

  private title(): string {
    if (this.kind === 'train') {
      return '12306 官方购票';
    }
    return this.kind === 'hotel' ? 'RollingGo 酒店预订' : '安全支付确认';
  }

  private closeLabel(): string {
    if (this.kind === 'train') {
      return '返回车次';
    }
    return this.kind === 'hotel' ? '返回房型' : '关闭';
  }

  private domainText(): string {
    if (this.kind === 'hotel') {
      return 'rollinggo.cn';
    }
    if (this.kind === 'train') {
      const activeUrl = this.currentUrl.length > 0 ? this.currentUrl : this.url;
      const host = webHostForDisplay(activeUrl);
      return host.length > 0 ? host : 'kyfw.12306.cn';
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
      if (this.kind === 'train') {
        this.blockedNavigation = '已阻止离开安全的 HTTPS 页面。';
        aiLogInfo('[AIPhone][TrainBookingNavigationBlocked] chars=' + url.length.toString());
      } else {
        this.blockedNavigation = '已阻止离开 RollingGo 安全域名。';
        aiLogInfo('[AIPhone][HotelBookingNavigationBlocked] chars=' + url.length.toString());
      }
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
          label: this.closeLabel(),
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
          this.currentUrl = url;
          aiLogInfo('[AIPhone][CheckoutWebLoadEnd] kind=' + this.kind + ' chars=' + url.length.toString());
        }
      }).layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PAGE)
  }
}
