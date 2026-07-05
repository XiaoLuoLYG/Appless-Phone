import { describe, it, expect } from '@ohos/hypium';
import {
  blankStripeReceivingProfile,
  mapStripeReceivingStatus,
  validateStripeReceivingProfile
} from '@loop/agent-core';
import { StripeReceivingAccountStatusPayload } from '@loop/agent-core';

export default function stripeReceivingAccountCoreTest() {
  describe('stripeReceivingAccountCore', () => {
    it('validates the minimum non-sensitive profile', 0, () => {
      const blank = blankStripeReceivingProfile();
      expect(validateStripeReceivingProfile(blank).ok).assertFalse();

      const valid = validateStripeReceivingProfile({
        agentId: 'agent_phone_owner',
        deviceId: 'phone_local_device',
        displayName: 'My Agent',
        email: 'owner@example.com',
        country: 'US',
        businessType: 'individual',
        stripeAccountId: '',
        status: 'not_created'
      });

      expect(valid.ok).assertTrue();
      expect(valid.reason).assertEqual('');
    });

    it('maps Stripe account status into card states', 0, () => {
      const receivable: StripeReceivingAccountStatusPayload = {
        stripeAccountId: 'acct_123',
        chargesEnabled: true,
        payoutsEnabled: true,
        cardPayments: 'active',
        transfers: 'active',
        currentlyDue: []
      };
      expect(mapStripeReceivingStatus(receivable).status).assertEqual('receivable');

      const missing: StripeReceivingAccountStatusPayload = {
        stripeAccountId: 'acct_123',
        chargesEnabled: false,
        payoutsEnabled: false,
        cardPayments: 'inactive',
        transfers: 'inactive',
        currentlyDue: ['individual.dob.day']
      };
      const mapped = mapStripeReceivingStatus(missing);
      expect(mapped.status).assertEqual('onboarding_required');
      expect(mapped.message.indexOf('individual.dob.day')).assertLarger(-1);
    });
  });
}
