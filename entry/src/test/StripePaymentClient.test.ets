import { describe, it, expect } from '@ohos/hypium';
import {
  buildStripeCheckoutSessionRequest,
  stripeCheckoutUrlFromResponse
} from '@loop/agent-core';

export default function stripePaymentClientTest() {
  describe('stripePaymentClient', () => {
    it('builds connected merchant Checkout Session form requests', 0, () => {
      const request = buildStripeCheckoutSessionRequest({
        secretKey: 'sk_test_123',
        connectedAccountId: 'acct_123',
        amountMinor: 500,
        currency: 'USD',
        merchantName: 'Demo Vendor',
        successUrl: 'aiphone://payment/stripe/success',
        cancelUrl: 'aiphone://payment/stripe/cancel',
        idempotencyKey: 'test-key',
        note: 'coffee'
      });

      expect(request.url).assertEqual('https://api.stripe.com/v1/checkout/sessions');
      expect(request.headers.Authorization).assertEqual('Bearer sk_test_123');
      expect(request.headers.IdempotencyKey).assertEqual('test-key');
      expect(request.body.indexOf('mode=payment')).assertLarger(-1);
      expect(request.body.indexOf('line_items%5B0%5D%5Bprice_data%5D%5Bunit_amount%5D=500')).assertLarger(-1);
      expect(request.body.indexOf('payment_intent_data%5Btransfer_data%5D%5Bdestination%5D=acct_123')).assertLarger(-1);
    });

    it('extracts hosted Checkout URLs from Stripe responses', 0, () => {
      const url = stripeCheckoutUrlFromResponse(JSON.stringify({
        id: 'cs_test_123',
        url: 'https://checkout.stripe.com/c/pay/cs_test_123'
      }));

      expect(url).assertEqual('https://checkout.stripe.com/c/pay/cs_test_123');
    });
  });
}
