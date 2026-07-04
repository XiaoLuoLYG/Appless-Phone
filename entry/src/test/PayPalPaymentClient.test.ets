import { describe, it, expect } from '@ohos/hypium';
import {
  buildPayPalOrderRequest,
  buildPayPalTokenRequest,
  paypalApprovalUrlFromOrder
} from '@loop/agent-core';

interface PayPalAmountFixture {
  value: string;
  currency_code: string;
}

interface PayPalPayeeFixture {
  email_address?: string;
  merchant_id?: string;
}

interface PayPalPurchaseUnitFixture {
  amount: PayPalAmountFixture;
  payee: PayPalPayeeFixture;
}

interface PayPalOrderFixture {
  intent: string;
  purchase_units: PayPalPurchaseUnitFixture[];
}

interface PayPalLinkFixture {
  rel: string;
  href: string;
}

interface PayPalOrderResponseFixture {
  id: string;
  links: PayPalLinkFixture[];
}

export default function payPalPaymentClientTest() {
  describe('payPalPaymentClient', () => {
    it('builds token and account-directed order requests', 0, () => {
      const token = buildPayPalTokenRequest({
        environment: 'sandbox',
        clientId: 'client',
        clientSecret: 'secret'
      });
      const order = buildPayPalOrderRequest({
        environment: 'sandbox',
        accessToken: 'access',
        amountText: '5.00',
        currency: 'USD',
        payeeEmail: 'alex@example.com',
        payeeMerchantId: '',
        returnUrl: 'aiphone://payment/paypal/success',
        cancelUrl: 'aiphone://payment/paypal/cancel',
        note: 'coffee'
      });
      const body = JSON.parse(order.body) as PayPalOrderFixture;

      expect(token.url).assertEqual('https://api-m.sandbox.paypal.com/v1/oauth2/token');
      expect(token.headers.Authorization).assertEqual('Basic Y2xpZW50OnNlY3JldA==');
      expect(token.body).assertEqual('grant_type=client_credentials');
      expect(order.url).assertEqual('https://api-m.sandbox.paypal.com/v2/checkout/orders');
      expect(order.headers.Authorization).assertEqual('Bearer access');
      expect(body.intent).assertEqual('CAPTURE');
      expect(body.purchase_units[0].amount.value).assertEqual('5.00');
      expect(body.purchase_units[0].payee.email_address).assertEqual('alex@example.com');
    });

    it('extracts the PayPal approval URL from order links', 0, () => {
      const response: PayPalOrderResponseFixture = {
        id: 'ORDER-1',
        links: [{
          rel: 'self',
          href: 'https://api-m.sandbox.paypal.com/v2/checkout/orders/ORDER-1'
        }, {
          rel: 'approve',
          href: 'https://www.sandbox.paypal.com/checkoutnow?token=ORDER-1'
        }]
      };
      const url = paypalApprovalUrlFromOrder(JSON.stringify(response));

      expect(url).assertEqual('https://www.sandbox.paypal.com/checkoutnow?token=ORDER-1');
    });
  });
}
