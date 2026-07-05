import { describe, it, expect } from '@ohos/hypium';
import {
  defaultPaymentAccountBook,
  normalizePaymentAmount,
  paymentProviderForAccount,
  resolvePaymentAccount,
  validatePaymentRequest
} from '@loop/agent-core';
import { PaymentAccount, PaymentPolicy, PaymentRequestDraft } from '@loop/agent-core';

function acct(
  id: string,
  displayName: string,
  aliases: string[],
  paypalEmail: string,
  stripeAccountId: string,
  stripePaymentLinkUrl: string
): PaymentAccount {
  return {
    id: id,
    displayName: displayName,
    aliases: aliases,
    email: '',
    paypalEmail: paypalEmail,
    paypalMerchantId: '',
    stripeAccountId: stripeAccountId,
    stripePaymentLinkUrl: stripePaymentLinkUrl,
    enabled: true
  };
}

const policy: PaymentPolicy = {
  mode: 'test',
  defaultCurrency: 'USD',
  liveMaxAmountMinor: 100,
  liveAllowedStripeAccountIds: ['acct_live_ok']
};

export default function paymentCoreTest() {
  describe('paymentCore', () => {
    it('resolves aliases and blocks unknown recipients', 0, () => {
      expect(resolvePaymentAccount('alex', [acct('alex', 'Alex', ['Alex'], '', '', '')]).status).assertEqual('resolved');
      expect(resolvePaymentAccount('nobody', [acct('alex', 'Alex', ['Alex'], '', '', '')]).status).assertEqual('unknown');
    });

    it('selects paypal, stripe connected, and stripe payment link targets', 0, () => {
      expect(paymentProviderForAccount(acct('alex', 'Alex', ['Alex'], 'alex@example.com', '', ''), '').targetType)
        .assertEqual('paypal');
      expect(paymentProviderForAccount(acct('vendor', 'Vendor', ['Vendor'], '', 'acct_123', ''), '').targetType)
        .assertEqual('stripe_connected');
      expect(paymentProviderForAccount(acct('cafe', 'Cafe', ['Cafe'], '', '', 'https://buy.stripe.com/test'), '').targetType)
        .assertEqual('stripe_payment_link');
    });

    it('returns provider choice when both PayPal and Stripe are available', 0, () => {
      const result = validatePaymentRequest({
        recipient: 'Alex',
        provider: '',
        fundingSource: '',
        amountText: '5',
        currency: 'USD',
        note: ''
      } as PaymentRequestDraft, [acct('alex', 'Alex', ['Alex'], 'alex@example.com', 'acct_123', '')], policy);
      expect(result.status).assertEqual('needs_provider');
    });

    it('normalizes amounts and blocks invalid Stripe URLs', 0, () => {
      expect(normalizePaymentAmount('5.25', 'USD').amountMinor).assertEqual(525);
      const result = validatePaymentRequest({
        recipient: 'Cafe',
        provider: 'stripe',
        fundingSource: '',
        amountText: '',
        currency: 'USD',
        note: ''
      } as PaymentRequestDraft, [acct('cafe', 'Cafe', ['Cafe'], '', '', 'http://evil.example/pay')], policy);
      expect(result.status).assertEqual('blocked');
      expect(result.reason.indexOf('Stripe payment URL')).assertLarger(-1);
    });

    it('blocks Stripe test Payment Links in live mode', 0, () => {
      const result = validatePaymentRequest({
        recipient: 'Cafe',
        provider: 'stripe',
        fundingSource: '',
        amountText: '',
        currency: 'USD',
        note: ''
      } as PaymentRequestDraft, [acct('cafe', 'Cafe', ['Cafe'], '', '', 'https://buy.stripe.com/test_123')], {
        mode: 'live',
        defaultCurrency: 'USD',
        liveMaxAmountMinor: 500,
        liveAllowedStripeAccountIds: []
      } as PaymentPolicy);
      expect(result.status).assertEqual('blocked');
      expect(result.reason.indexOf('test Payment Link')).assertLarger(-1);
    });

    it('keeps seeded demo accounts local and nonempty', 0, () => {
      expect(defaultPaymentAccountBook().length).assertLarger(0);
    });
  });
}
