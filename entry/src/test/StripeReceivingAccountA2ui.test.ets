import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiSurfaceStore,
  componentById,
  parseA2uiJsonl,
  stripeReceivingAccount,
  stripeReceivingAccountA2ui
} from '@loop/agent-core';
import { StripeReceivingAccountCardData } from '@loop/agent-core';

function surfaceFromJsonl(jsonl: string): A2uiSurfaceStore {
  const parsed = parseA2uiJsonl(jsonl);
  const store = new A2uiSurfaceStore();

  expect(parsed.error).assertEqual('');
  parsed.envelopes.forEach(envelope => {
    store.apply(envelope);
  });
  return store;
}

export default function stripeReceivingAccountA2uiTest() {
  describe('stripeReceivingAccountA2ui', () => {
    it('renders setup card with create action', 0, () => {
      const card: StripeReceivingAccountCardData = {
        status: 'not_created',
        title: 'Stripe 收款账户',
        message: 'Stripe 会负责实名、税务和银行卡信息收集。',
        agentId: 'agent_phone_owner',
        deviceId: 'phone_local_device',
        displayName: 'My Agent',
        email: 'owner@example.com',
        country: 'US',
        businessType: 'individual',
        stripeAccountId: '',
        onboardingUrl: '',
        currentlyDue: [],
        actions: []
      };

      const store = surfaceFromJsonl(stripeReceivingAccountA2ui('stripe_receiving', card));
      const surface = store.getSurface();
      const component = componentById(surface, 'stripe_receiving_account');
      const data = stripeReceivingAccount(surface);

      expect(surface.intent).assertEqual('payment.account.setup');
      expect(component !== null).assertTrue();
      if (component !== null) {
        expect(component.component).assertEqual('StripeReceivingAccountCard');
        expect(component.dataPath).assertEqual('/stripeReceivingAccount');
      }
      expect(data.status).assertEqual('not_created');
      expect(data.actions[0].id).assertEqual('stripe.account.create');
    });

    it('renders onboarding and receivable actions without replacing explicit actions', 0, () => {
      const card: StripeReceivingAccountCardData = {
        status: 'onboarding_required',
        title: 'Stripe 收款账户',
        message: '需要继续认证。',
        agentId: 'agent_phone_owner',
        deviceId: 'phone_local_device',
        displayName: 'My Agent',
        email: 'owner@example.com',
        country: 'US',
        businessType: 'individual',
        stripeAccountId: 'acct_123',
        onboardingUrl: 'https://connect.stripe.com/setup/test',
        currentlyDue: ['individual.dob.day'],
        actions: []
      };

      const onboarding = stripeReceivingAccount(surfaceFromJsonl(stripeReceivingAccountA2ui('stripe_receiving_onboard', card)).getSurface());
      expect(onboarding.actions[0].id).assertEqual('stripe.account.open');
      expect(onboarding.actions[0].prompt).assertEqual('https://connect.stripe.com/setup/test');
      expect(onboarding.currentlyDue[0]).assertEqual('individual.dob.day');

      card.onboardingUrl = '';
      const relink = stripeReceivingAccount(surfaceFromJsonl(stripeReceivingAccountA2ui('stripe_receiving_relink', card)).getSurface());
      expect(relink.actions[0].id).assertEqual('stripe.account.onboard');
      expect(relink.actions[0].label).assertEqual('打开 Stripe 托管认证');

      card.status = 'receivable';
      const receivable = stripeReceivingAccount(surfaceFromJsonl(stripeReceivingAccountA2ui('stripe_receiving_ready', card)).getSurface());
      expect(receivable.actions[0].id).assertEqual('stripe.account.refresh');
    });

    it('does not show refresh for blocked profiles without a Stripe account id', 0, () => {
      const card: StripeReceivingAccountCardData = {
        status: 'blocked',
        title: 'Stripe 收款账户',
        message: 'Stripe Dashboard 还需要确认。',
        agentId: 'agent_phone_owner',
        deviceId: 'phone_local_device',
        displayName: 'My Agent',
        email: 'owner@example.com',
        country: 'US',
        businessType: 'individual',
        stripeAccountId: '',
        onboardingUrl: '',
        currentlyDue: [],
        actions: []
      };

      const blocked = stripeReceivingAccount(surfaceFromJsonl(stripeReceivingAccountA2ui('stripe_receiving_blocked', card)).getSurface());
      expect(blocked.actions[0].id).assertEqual('stripe.account.create');
      expect(blocked.actions[0].label).assertEqual('重试绑定');
    });
  });
}
