import { describe, it, expect } from '@ohos/hypium';
import {
  buildStripeConnectAccountRequest,
  buildStripeConnectOnboardingLinkRequest,
  buildStripeConnectStatusRequest,
  parseStripeConnectAccountResponse,
  parseStripeConnectOnboardingLinkResponse,
  parseStripeConnectStatusResponse
} from '@loop/agent-core';

interface StripeConnectGatewayBodyFixture {
  agentId: string;
  email: string;
  country: string;
  businessType: string;
}

interface StripeConnectAccountIdFixture {
  stripeAccountId: string;
}

export default function stripeConnectClientTest() {
  describe('stripeConnectClient', () => {
    it('builds direct Stripe Connect requests from phone-local config', 0, () => {
      const body: StripeConnectGatewayBodyFixture = {
        agentId: 'agent_phone_owner',
        email: 'owner@example.com',
        country: 'US',
        businessType: 'individual'
      };
      const account: StripeConnectAccountIdFixture = { stripeAccountId: 'acct_123' };
      const request = buildStripeConnectAccountRequest('sk_test_phone_local', body);
      const link = buildStripeConnectOnboardingLinkRequest('sk_test_phone_local', account,
        'https://example.com/return', 'https://example.com/refresh');
      const status = buildStripeConnectStatusRequest('sk_test_phone_local', account);

      expect(request.url).assertEqual('https://api.stripe.com/v1/accounts');
      expect(request.method).assertEqual('POST');
      expect(request.headers['Authorization']).assertEqual('Bearer sk_test_phone_local');
      expect(request.headers['Content-Type']).assertEqual('application/x-www-form-urlencoded');
      expect(request.body.indexOf('email=owner%40example.com')).assertLarger(-1);
      expect(request.body.indexOf('capabilities%5Bcard_payments%5D%5Brequested%5D=true')).assertLarger(-1);
      expect(link.url).assertEqual('https://api.stripe.com/v1/account_links');
      expect(link.body.indexOf('account=acct_123')).assertLarger(-1);
      expect(status.method).assertEqual('GET');
      expect(status.url).assertEqual('https://api.stripe.com/v1/accounts/acct_123');
    });

    it('parses create account, onboarding link, and status responses', 0, () => {
      const account = parseStripeConnectAccountResponse('{"id":"acct_123"}');
      expect(account.ok).assertTrue();
      expect(account.stripeAccountId).assertEqual('acct_123');

      const link = parseStripeConnectOnboardingLinkResponse('{"url":"https://connect.stripe.com/setup/test"}');
      expect(link.ok).assertTrue();
      expect(link.url.indexOf('connect.stripe.com')).assertLarger(-1);

      const status = parseStripeConnectStatusResponse('{"id":"acct_123","charges_enabled":true,"payouts_enabled":true,"capabilities":{"card_payments":"active","transfers":"active"},"requirements":{"currently_due":[]}}');
      expect(status.ok).assertTrue();
      expect(status.payload.chargesEnabled).assertTrue();
      expect(status.payload.currentlyDue.length).assertEqual(0);
    });

    it('surfaces Stripe errors instead of inventing account ids', 0, () => {
      const account = parseStripeConnectAccountResponse('{"error":{"message":"Missing STRIPE_TEST_SECRET_KEY."}}');
      expect(account.ok).assertFalse();
      expect(account.error.indexOf('Missing')).assertEqual(0);

      const link = parseStripeConnectOnboardingLinkResponse('{"url":"http://not-allowed"}');
      expect(link.ok).assertFalse();
      expect(link.error.length).assertLarger(0);
    });
  });
}
