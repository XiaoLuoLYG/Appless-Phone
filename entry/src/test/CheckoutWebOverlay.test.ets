import { describe, it, expect } from '@ohos/hypium';
import {
  checkoutWebInitialSource,
  checkoutWebNavigationDecision,
  isAllowed12306BookingUrl,
  webHostForDisplay
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
      expect(isAllowed12306BookingUrl(
        'https://user:secret@kyfw.12306.cn/otn/leftTicket/init'
      )).assertFalse();
      expect(isAllowed12306BookingUrl(
        'https://kyfw.12306.cn:8443/otn/leftTicket/init'
      )).assertFalse();
      expect(isAllowed12306BookingUrl(
        'https://KYFW.12306.CN/otn/leftTicket/init'
      )).assertTrue();
      expect(isAllowed12306BookingUrl(
        'https://kyfw.12306.cn/otn/leftticket/init'
      )).assertFalse();
    });

    it('filters the initial train source before handing it to WebView', 0, () => {
      const official = 'https://kyfw.12306.cn/otn/leftTicket/init?date=2026-07-22';
      expect(checkoutWebInitialSource('train', official)).assertEqual(official);
      expect(checkoutWebInitialSource(
        'train',
        'https://kyfw.12306.cn.evil.example/otn/leftTicket/init'
      )).assertEqual('');
      expect(checkoutWebInitialSource(
        'train',
        'https://kyfw.12306.cn@evil.example/otn/leftTicket/init'
      )).assertEqual('');
      expect(checkoutWebInitialSource('payment', 'https://checkout.stripe.com/pay')).assertEqual(
        'https://checkout.stripe.com/pay'
      );
      expect(checkoutWebInitialSource('hotel', 'https://rollinggo.cn/hotel')).assertEqual(
        'https://rollinggo.cn/hotel'
      );
    });

    it('shows only the parsed hostname for loaded pages', 0, () => {
      expect(webHostForDisplay(
        'https://kyfw.12306.cn:user-secret@evil.example/otn/leftTicket/init'
      )).assertEqual('evil.example');
      expect(webHostForDisplay('https://epay.12306.cn:8443/pay/webBusiness')).assertEqual('epay.12306.cn');
      expect(webHostForDisplay('https://cashier.example.com/payment/return')).assertEqual('cashier.example.com');
      expect(webHostForDisplay('not a URL')).assertEqual('');
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
