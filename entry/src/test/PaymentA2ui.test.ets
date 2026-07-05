import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiSurfaceStore,
  actionsOf,
  genericToolResults,
  parseA2uiJsonl,
  paymentValidationA2ui
} from '@loop/agent-core';
import { PaymentValidationResult } from '@loop/agent-core';

function applyJsonl(jsonl: string): A2uiSurfaceStore {
  const parsed = parseA2uiJsonl(jsonl);
  const store = new A2uiSurfaceStore();
  parsed.envelopes.forEach((envelope) => {
    store.apply(envelope);
  });
  return store;
}

function validation(status: string, targetType: string, amountMinor: number, amountText: string): PaymentValidationResult {
  return {
    status: status,
    targetType: targetType,
    reason: '',
    recipient: '罗一格',
    accountId: 'luoyige',
    displayName: '罗一格',
    provider: 'paypal',
    fundingSource: '',
    amountMinor: amountMinor,
    amountText: amountText,
    currency: 'USD',
    note: 'coffee',
    mode: 'test',
    paypalEmail: 'yl732@cantab.ac.uk',
    paypalMerchantId: '',
    stripeAccountId: '',
    stripePaymentLinkUrl: ''
  } as PaymentValidationResult;
}

export default function paymentA2uiTest() {
  describe('paymentA2ui', () => {
    it('renders a confirmation card with confirm and cancel actions', 0, () => {
      const store = applyJsonl(paymentValidationA2ui('surface_payment', validation('confirm', 'paypal', 500, '5')));
      const surface = store.getSurface();
      const result = genericToolResults(surface)[0];
      const actions = actionsOf(surface.components[1]);

      expect(surface.title).assertEqual('AIPhone Pay');
      expect(result.title).assertEqual('确认支付');
      expect(result.summary.indexOf('罗一格')).assertLarger(-1);
      expect(result.rows[0].label).assertEqual('收款方');
      expect(result.rows[0].value).assertEqual('罗一格');
      expect(actions[0].id).assertEqual('payment.confirm');
      expect(actions[1].id).assertEqual('payment.cancel');
    });

    it('renders amount choices when amount is missing', 0, () => {
      const store = applyJsonl(paymentValidationA2ui('surface_payment', validation('needs_amount', 'paypal', 0, '')));
      const surface = store.getSurface();
      const result = genericToolResults(surface)[0];
      const actions = actionsOf(surface.components[1]);

      expect(result.title).assertEqual('补充金额');
      expect(actions[0].id).assertEqual('payment.amount.select');
      expect(actions[0].label.indexOf('1')).assertLarger(-1);
      expect(actions[1].id).assertEqual('payment.amount.select');
      expect(actions[2].id).assertEqual('payment.amount.select');
    });

    it('does not render missing recipient as a dead confirmation card', 0, () => {
      const missing = validation('needs_recipient', 'none', 0, '');
      missing.reason = 'Recipient is required.';
      const store = applyJsonl(paymentValidationA2ui('surface_payment', missing));
      const surface = store.getSurface();
      const result = genericToolResults(surface)[0];
      const actions = actionsOf(surface.components[1]);

      expect(result.title).assertEqual('补充收款方');
      expect(actions.length).assertEqual(1);
      expect(actions[0].id).assertEqual('payment.cancel');
    });

    it('renders checkout action with provider url', 0, () => {
      const checkout = validation('checkout', 'stripe_payment_link', 0, '');
      checkout.provider = 'stripe';
      checkout.stripePaymentLinkUrl = 'https://buy.stripe.com/test_external_cafe';
      checkout.checkoutUrl = 'https://buy.stripe.com/test_external_cafe';
      const store = applyJsonl(paymentValidationA2ui('surface_payment', checkout));
      const surface = store.getSurface();
      const result = genericToolResults(surface)[0];
      const actions = actionsOf(surface.components[1]);

      expect(result.title).assertEqual('打开支付确认页');
      expect(JSON.stringify(result.rows).indexOf('https://buy.stripe.com/')).assertLarger(-1);
      expect(actions[0].id).assertEqual('payment.checkout.open');
      expect(actions[0].kind).assertEqual('client');
      expect(actions[0].prompt.indexOf('https://buy.stripe.com/test_external_cafe')).assertLarger(-1);
      expect(JSON.stringify(actions[0].args).indexOf('https://buy.stripe.com/test_external_cafe')).assertLarger(-1);
    });

    it('renders Google Pay as a funding method, not a payment provider', 0, () => {
      const googlePay = validation('confirm', 'paypal', 500, '5');
      googlePay.fundingSource = 'google_pay';
      const store = applyJsonl(paymentValidationA2ui('surface_payment', googlePay));
      const surface = store.getSurface();
      const result = genericToolResults(surface)[0];
      const actions = actionsOf(surface.components[1]);

      expect(JSON.stringify(result.rows).indexOf('Google Pay')).assertLarger(-1);
      expect(result.rows[1].value).assertEqual('PayPal');
      expect(JSON.stringify(actions[0].args).indexOf('google_pay')).assertLarger(-1);
    });
  });
}
