import { describe, it, expect } from '@ohos/hypium';
import {
  checkoutWebNavigationDecision,
  isAllowed12306BookingUrl
} from '../main/ets/pages/A2uiHome/components/CheckoutWebOverlay';

export default function checkoutWebOverlayTest() {
  describe('checkoutWebOverlay', () => {
    it('accepts only the official 12306 route entry URL', 0, () => {
      expect(isAllowed12306BookingUrl(
        'https://kyfw.12306.cn/otn/leftTicket/init?date=2026-07-22'
      )).assertTrue();
      expect(isAllowed12306BookingUrl(
        'http://kyfw.12306.cn/otn/leftTicket/init?date=2026-07-22'
      )).assertFalse();
      expect(isAllowed12306BookingUrl(
        'https://kyfw.12306.cn.evil.example/otn/leftTicket/init'
      )).assertFalse();
      expect(isAllowed12306BookingUrl(
        'https://kyfw.12306.cn/otn/leftTicket/query'
      )).assertFalse();
      expect(isAllowed12306BookingUrl(
        'https://kyfw.12306.cn/otn/leftTicket/init.evil'
      )).assertFalse();
    });

    it('keeps HTTPS train navigation in WebView and blocks unverified schemes', 0, () => {
      expect(checkoutWebNavigationDecision(
        'train',
        'https://kyfw.12306.cn/otn/leftTicket/init',
        true
      )).assertEqual('allow');
      expect(checkoutWebNavigationDecision(
        'train',
        'https://epay.12306.cn/pay/webBusiness',
        true
      )).assertEqual('allow');
      expect(checkoutWebNavigationDecision('train', 'alipays://platformapi/startapp', true)).assertEqual('block');
      expect(checkoutWebNavigationDecision('train', 'javascript:alert(1)', true)).assertEqual('block');
      expect(checkoutWebNavigationDecision('train', 'alipays://platformapi/startapp', false)).assertEqual('allow');
    });

    it('does not regress payment and hotel decisions', 0, () => {
      expect(checkoutWebNavigationDecision(
        'payment',
        'aiphone://payment/success',
        true
      )).assertEqual('payment_return');
      expect(checkoutWebNavigationDecision(
        'hotel',
        'https://evil.example/',
        true
      )).assertEqual('block');
    });
  });
}
