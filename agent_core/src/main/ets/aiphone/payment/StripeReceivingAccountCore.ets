export type StripeReceivingAccountStatus =
  'not_created' | 'onboarding_required' | 'pending_review' | 'receivable' | 'blocked' | 'config_missing';

export interface StripeReceivingProfile {
  agentId: string;
  deviceId: string;
  displayName: string;
  email: string;
  country: string;
  businessType: string;
  stripeAccountId: string;
  status: StripeReceivingAccountStatus;
}

export interface StripeReceivingValidation {
  ok: boolean;
  reason: string;
}

export interface StripeReceivingAccountStatusPayload {
  stripeAccountId: string;
  chargesEnabled: boolean;
  payoutsEnabled: boolean;
  cardPayments: string;
  transfers: string;
  currentlyDue: string[];
}

export interface StripeReceivingStatusSummary {
  status: StripeReceivingAccountStatus;
  message: string;
}

export function blankStripeReceivingProfile(): StripeReceivingProfile {
  return {
    agentId: '',
    deviceId: '',
    displayName: '',
    email: '',
    country: '',
    businessType: 'individual',
    stripeAccountId: '',
    status: 'not_created'
  };
}

function missing(label: string): StripeReceivingValidation {
  return {
    ok: false,
    reason: 'Missing ' + label + '.'
  };
}

export function validateStripeReceivingProfile(profile: StripeReceivingProfile): StripeReceivingValidation {
  if (profile.agentId.trim().length === 0) {
    return missing('agentId');
  }
  if (profile.deviceId.trim().length === 0) {
    return missing('deviceId');
  }
  if (profile.displayName.trim().length === 0) {
    return missing('displayName');
  }
  if (profile.email.trim().length === 0 || profile.email.indexOf('@') < 1) {
    return missing('email');
  }
  if (profile.country.trim().length !== 2) {
    return {
      ok: false,
      reason: 'country must be a two-letter country code.'
    };
  }
  return {
    ok: true,
    reason: ''
  };
}

export function mapStripeReceivingStatus(payload: StripeReceivingAccountStatusPayload): StripeReceivingStatusSummary {
  if (payload.stripeAccountId.trim().length === 0) {
    return {
      status: 'not_created',
      message: '还没有 Stripe connected account。'
    };
  }
  if (payload.currentlyDue.length > 0) {
    return {
      status: 'onboarding_required',
      message: 'Stripe 仍需资料：' + payload.currentlyDue.join(', ')
    };
  }
  if (payload.chargesEnabled && payload.payoutsEnabled && payload.cardPayments === 'active' && payload.transfers === 'active') {
    return {
      status: 'receivable',
      message: '这个 agent 已可接收 Stripe 付款。'
    };
  }
  if (payload.chargesEnabled || payload.payoutsEnabled) {
    return {
      status: 'pending_review',
      message: 'Stripe 正在完成收款或提现能力审核。'
    };
  }
  return {
    status: 'blocked',
    message: 'Stripe 尚未启用收款能力。请继续认证。'
  };
}
