import { describe, it, expect } from '@ohos/hypium';
import { A2uiAction } from '@loop/agent-core';
import { isHtmlHomeActionAllowed } from '../main/ets/pages/A2uiHome/html/HtmlHomeActionPolicy';
import { HtmlHomeAction, HtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeTypes';

interface ThreadOnlyArgsFixture {
  threadId: string;
}

interface StripeOnboardingArgsFixture {
  onboardingUrl: string;
}

interface PaymentCaptureArgsFixture {
  provider: string;
  phase: string;
  providerSessionId: string;
}

interface PaymentCheckoutArgsFixture {
  provider: string;
  providerSessionId: string;
}

interface MailReplyArgsFixture {
  requestKey: string;
  provider: string;
  threadId: string;
  messageId: string;
  to: string[];
  subject: string;
  body: string;
}

function action(id: string, prompt: string, kind: string = 'client', args: Object | null = null): A2uiAction {
  const next: A2uiAction = {
    id: id,
    label: id,
    prompt: prompt,
    variant: 'primary',
    kind: kind
  };
  if (args !== null) {
    next.args = args;
  }
  return next;
}

function documentFixture(): HtmlHomeDocument {
  return {
    version: 1,
    source: 'tool',
    kind: 'dynamic-tools',
    title: 'Tool',
    subtitle: '',
    chips: [],
    metrics: [],
    timeline: [],
    blocks: [{
      id: 'connect',
      kind: 'dynamic-tool-connect',
      title: 'Weather',
      subtitle: '',
      status: 'needs_auth',
      credentialName: 'Authorization',
      credentialRef: 'dynamic:weather:Authorization',
      toolId: 'weather.query',
      prompt: '深圳天气',
      metrics: [],
      rows: [],
      actions: [{ id: 'dynamic_test_connection', label: '测试连接', prompt: '深圳天气', variant: 'primary', kind: 'client' }]
    }, {
      id: 'food-1',
      kind: 'food-result',
      title: 'Coffee',
      subtitle: '',
      status: 'ready',
      source: 'amap',
      metrics: [],
      rows: [],
      actions: [{ id: 'html_open_food_map', label: '打开地图', prompt: '{"index":0,"name":"Coffee"}', variant: 'primary', kind: 'client' }]
    }],
    actions: [{ id: 'gmail.open.web', label: 'Gmail Web', prompt: 'https://mail.google.com/', variant: 'secondary', kind: 'client' }],
    history: [],
    persona: { id: '', name: '', avatarKey: '', status: '', reason: '' },
    personaMemory: { summary: '', preferences: [] },
    rawSurfaceRoot: null,
    generatedAt: '2026-06-26T00:00:00.000Z'
  };
}

export default function htmlHomeActionPolicyTest() {
  describe('htmlHomeActionPolicy', () => {
    it('allows only actions from the current HTML document snapshot', 0, () => {
      const doc = documentFixture();

      expect(isHtmlHomeActionAllowed(doc, action('gmail.open.web', 'https://mail.google.com/'))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('gmail.open.web', 'https://evil.example/'))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, action('html_open_food_map', '{"index":0,"name":"Coffee"}'))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('html_open_food_map', '{"index":99,"name":"Other"}'))).assertFalse();
    });

    it('allows dynamic credential save only for the current dynamic block', 0, () => {
      const doc = documentFixture();
      const allowedPayload = JSON.stringify({
        credentialRef: 'dynamic:weather:Authorization',
        credentialValue: 'secret',
        toolId: 'weather.query',
        prompt: '深圳天气'
      });
      const blockedPayload = JSON.stringify({
        credentialRef: 'dynamic:other:Authorization',
        credentialValue: 'secret',
        toolId: 'statistics.search',
        prompt: 'GDP'
      });

      expect(isHtmlHomeActionAllowed(doc, action('html_dynamic_save_and_test', allowedPayload))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('html_dynamic_save_and_test', blockedPayload))).assertFalse();
    });

    it('checks action args when allowing HTML actions', 0, () => {
      const doc = documentFixture();
      const expectedArgs: ThreadOnlyArgsFixture = {
        threadId: 'thread-123'
      };
      const blockedArgs: ThreadOnlyArgsFixture = {
        threadId: 'thread-999'
      };
      doc.actions.push({
        id: 'gmail.ai.reply.draft',
        label: 'AI 回复草稿',
        prompt: 'reply',
        variant: 'primary',
        kind: 'prompt',
        args: expectedArgs
      });

      expect(isHtmlHomeActionAllowed(doc, action('gmail.ai.reply.draft', 'reply', 'prompt', expectedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('gmail.ai.reply.draft', 'reply', 'prompt', blockedArgs))).assertFalse();
    });

    it('allows mail reply submissions only for the matching visible mail card', 0, () => {
      const doc = documentFixture();
      const template: MailReplyArgsFixture = {
        requestKey: '',
        provider: 'gmail',
        threadId: 'thread-123',
        messageId: 'message-123',
        to: ['alice@example.com'],
        subject: 'Re: Status update',
        body: ''
      };
      doc.blocks.push({
        id: 'gmail-message-123',
        kind: 'generic-tool-result',
        title: 'Status update',
        subtitle: '',
        status: 'success',
        source: 'Gmail',
        metrics: [],
        rows: [],
        actions: [{
          id: 'html_mail_detail_read',
          label: '加载正文',
          prompt: 'gmail:thread-123',
          variant: 'secondary',
          kind: 'client'
        }, {
          id: 'gmail.ai.reply.draft',
          label: 'AI 回复草稿',
          prompt: 'reply',
          variant: 'primary',
          kind: 'prompt',
          args: template
        }]
      });
      const allowed: MailReplyArgsFixture = {
        requestKey: 'gmail:thread-123',
        provider: 'gmail',
        threadId: 'thread-123',
        messageId: 'message-123',
        to: ['alice@example.com'],
        subject: 'Re: Status update',
        body: 'Confirmed.'
      };
      const blocked: MailReplyArgsFixture = {
        requestKey: 'gmail:thread-123',
        provider: 'gmail',
        threadId: 'thread-other',
        messageId: 'message-123',
        to: ['alice@example.com'],
        subject: 'Re: Status update',
        body: 'Confirmed.'
      };

      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_save', 'gmail:thread-123', 'client', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_send', 'gmail:thread-123', 'client', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_ai_generate', 'gmail:thread-123', 'client', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_send', 'gmail:thread-123', 'client', blocked))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_ai_generate', 'gmail:thread-123', 'client', blocked))).assertFalse();
    });

    it('allows only matching payment actions from the current HTML document', 0, () => {
      const doc = documentFixture();
      const expectedArgs: ThreadOnlyArgsFixture = {
        threadId: 'payment-123'
      };
      const blockedArgs: ThreadOnlyArgsFixture = {
        threadId: 'payment-999'
      };
      doc.actions.push({
        id: 'payment.confirm',
        label: '确认支付',
        prompt: 'confirm',
        variant: 'primary',
        kind: 'prompt',
        args: expectedArgs
      });

      expect(isHtmlHomeActionAllowed(doc, action('payment.confirm', 'confirm', 'prompt', expectedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('payment.confirm', 'confirm', 'prompt', blockedArgs))).assertFalse();
    });

    it('allows payment account saves only on payment pages with a usable target', 0, () => {
      const doc = documentFixture();
      doc.kind = 'payment';
      doc.blocks = [{
        id: 'payment-save',
        kind: 'generic-tool-result',
        title: '补充金额',
        subtitle: 'Payment target resolved.',
        status: 'ready',
        source: 'PayPal',
        metrics: [
          { label: 'source', value: 'PayPal' },
          { label: 'toolName', value: 'payment.send' }
        ],
        rows: [{ label: '收款方', value: 'Dana' }],
        actions: []
      }];
      const allowed = JSON.stringify({
        displayName: 'Dana',
        aliases: '小丹',
        paypalEmail: 'dana@example.com'
      });
      const missingTarget = JSON.stringify({
        displayName: 'Dana'
      });

      expect(isHtmlHomeActionAllowed(doc, action('payment.account.save', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('payment.account.save', missingTarget))).assertFalse();
      doc.kind = 'generic';
      expect(isHtmlHomeActionAllowed(doc, action('payment.account.save', allowed))).assertFalse();
    });

    it('allows PayPal Google Pay capture only for the current checkout order', 0, () => {
      const doc = documentFixture();
      const checkoutArgs: PaymentCheckoutArgsFixture = {
        provider: 'paypal',
        providerSessionId: 'ORDER-1'
      };
      const checkoutAction: HtmlHomeAction = {
        id: 'payment.checkout.open',
        label: '打开确认页',
        prompt: 'https://www.sandbox.paypal.com/checkoutnow?token=ORDER-1',
        variant: 'primary',
        kind: 'client',
        args: checkoutArgs
      };
      doc.kind = 'payment';
      doc.blocks = [{
        id: 'payment-google-pay',
        kind: 'generic-tool-result',
        title: '打开支付确认页',
        subtitle: 'PayPal Google Pay',
        status: 'needs_user',
        source: 'PayPal',
        metrics: [
          { label: 'source', value: 'PayPal' },
          { label: 'toolName', value: 'payment.send' }
        ],
        rows: [
          { label: '支付方式', value: 'PayPal' },
          { label: '付款方式偏好', value: 'Google Pay' }
        ],
        actions: [checkoutAction]
      }];
      const allowed: PaymentCaptureArgsFixture = {
        provider: 'paypal',
        phase: 'capture',
        providerSessionId: 'ORDER-1'
      };
      const wrongOrder: PaymentCaptureArgsFixture = {
        provider: 'paypal',
        phase: 'capture',
        providerSessionId: 'ORDER-2'
      };

      expect(isHtmlHomeActionAllowed(doc, action('payment.capture', 'capture', 'prompt', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('payment.capture', 'capture', 'prompt', wrongOrder))).assertFalse();
    });

    it('allows only the current Stripe onboarding URL to open from HTML', 0, () => {
      const doc = documentFixture();
      doc.blocks.push({
        id: 'stripe-receiving',
        kind: 'StripeReceivingAccountCard',
        title: 'Stripe 收款账户',
        subtitle: '继续认证',
        status: 'onboarding_required',
        source: 'stripe',
        metrics: [],
        rows: [],
        actions: [],
        stripeReceiving: {
          status: 'onboarding_required',
          message: '继续认证',
          stripeAccountId: 'acct_123',
          onboardingUrl: 'https://connect.stripe.com/setup/s/acct_123',
          currentlyDue: []
        }
      });

      const allowedArgs: StripeOnboardingArgsFixture = {
        onboardingUrl: 'https://connect.stripe.com/setup/s/acct_123'
      };
      const blockedArgs: StripeOnboardingArgsFixture = {
        onboardingUrl: 'https://evil.example/setup'
      };

      expect(isHtmlHomeActionAllowed(doc, action('stripe.account.open', 'https://connect.stripe.com/setup/s/acct_123', 'client', allowedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('stripe.account.open', 'https://evil.example/setup', 'client', blockedArgs))).assertFalse();
    });
  });
}
