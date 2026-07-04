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
    recipient: 'Alex',
    accountId: 'alex',
    displayName: 'Alex',
    provider: 'paypal',
    amountMinor: amountMinor,
    amountText: amountText,
    currency: 'USD',
    note: 'coffee',
    mode: 'test',
    paypalEmail: 'alex@example.com',
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
      expect(result.summary.indexOf('Alex')).assertLarger(-1);
      expect(result.rows[0].label).assertEqual('收款方');
      expect(result.rows[0].value).assertEqual('Alex');
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
  });
}
