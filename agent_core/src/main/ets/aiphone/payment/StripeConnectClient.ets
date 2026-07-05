import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { StripeReceivingAccountStatusPayload } from './StripeReceivingAccountCore';

export const STRIPE_CONNECT_ACCOUNTS_URL: string = 'https://api.stripe.com/v1/accounts';
export const STRIPE_CONNECT_ACCOUNT_LINKS_URL: string = 'https://api.stripe.com/v1/account_links';
const STRIPE_CONNECT_API_VERSION: string = '2025-09-30.clover';

export interface StripeConnectApiRequest {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: string;
}

export interface StripeConnectAccountResult {
  ok: boolean;
  stripeAccountId: string;
  error: string;
}

export interface StripeConnectOnboardingLinkResult {
  ok: boolean;
  url: string;
  error: string;
}

export interface StripeConnectStatusResult {
  ok: boolean;
  payload: StripeReceivingAccountStatusPayload;
  error: string;
}

function responseText(result: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(result));
  }
  if (typeof result === 'number' || typeof result === 'boolean') {
    return result.toString();
  }
  return JSON.stringify(result);
}

function textOf(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

function objectOf(value: Object | string | number | boolean | null | undefined): Record<string, Object | string | number | boolean | string[] | null | undefined> {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return JSON.parse('{}') as Record<string, Object | string | number | boolean | string[] | null | undefined>;
  }
  return value as Record<string, Object | string | number | boolean | string[] | null | undefined>;
}

function boolOf(value: Object | string | number | boolean | null | undefined): boolean {
  return value === true || value === 'true';
}

function appendFormPair(parts: string[], key: string, value: string): void {
  if (value.length === 0) {
    return;
  }
  parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(value));
}

function stripeHeaders(secretKey: string): Record<string, string> {
  return {
    'Authorization': 'Bearer ' + secretKey.trim(),
    'Content-Type': 'application/x-www-form-urlencoded',
    'Stripe-Version': STRIPE_CONNECT_API_VERSION
  };
}

function stripeErrorText(parsed: Record<string, Object | string | number | boolean | null | undefined>): string {
  const error = objectOf(parsed.error);
  const message = textOf(error.message).trim();
  if (message.length > 0) {
    return message;
  }
  return textOf(parsed.error).trim();
}

function emptyStatusPayload(): StripeReceivingAccountStatusPayload {
  return {
    stripeAccountId: '',
    chargesEnabled: false,
    payoutsEnabled: false,
    cardPayments: '',
    transfers: '',
    currentlyDue: []
  };
}

export function buildStripeConnectAccountRequest(secretKey: string, body: Object): StripeConnectApiRequest {
  const record = objectOf(body);
  const parts: string[] = [];
  appendFormPair(parts, 'type', 'express');
  appendFormPair(parts, 'country', textOf(record.country || 'US').toUpperCase());
  appendFormPair(parts, 'email', textOf(record.email));
  appendFormPair(parts, 'business_type', textOf(record.businessType || 'individual'));
  appendFormPair(parts, 'capabilities[card_payments][requested]', 'true');
  appendFormPair(parts, 'capabilities[transfers][requested]', 'true');
  appendFormPair(parts, 'metadata[aiphone_agent_id]', textOf(record.agentId));
  appendFormPair(parts, 'metadata[aiphone_device_id]', textOf(record.deviceId));
  return {
    url: STRIPE_CONNECT_ACCOUNTS_URL,
    method: 'POST',
    headers: stripeHeaders(secretKey),
    body: parts.join('&')
  };
}

export function buildStripeConnectOnboardingLinkRequest(secretKey: string, body: Object, returnUrl: string, refreshUrl: string): StripeConnectApiRequest {
  const record = objectOf(body);
  const parts: string[] = [];
  appendFormPair(parts, 'account', textOf(record.stripeAccountId));
  appendFormPair(parts, 'type', 'account_onboarding');
  appendFormPair(parts, 'refresh_url', refreshUrl);
  appendFormPair(parts, 'return_url', returnUrl);
  return {
    url: STRIPE_CONNECT_ACCOUNT_LINKS_URL,
    method: 'POST',
    headers: stripeHeaders(secretKey),
    body: parts.join('&')
  };
}

export function buildStripeConnectStatusRequest(secretKey: string, body: Object): StripeConnectApiRequest {
  const record = objectOf(body);
  return {
    url: STRIPE_CONNECT_ACCOUNTS_URL + '/' + encodeURIComponent(textOf(record.stripeAccountId)),
    method: 'GET',
    headers: stripeHeaders(secretKey),
    body: ''
  };
}

export function parseStripeConnectAccountResponse(rawJson: string): StripeConnectAccountResult {
  try {
    const parsed = JSON.parse(rawJson) as Record<string, Object | string | number | boolean | null | undefined>;
    const accountId = textOf(parsed.id).trim();
    if (accountId.indexOf('acct_') !== 0) {
      const error = stripeErrorText(parsed);
      return {
        ok: false,
        stripeAccountId: '',
        error: error.length > 0 ? error : 'Missing stripeAccountId.'
      };
    }
    return {
      ok: true,
      stripeAccountId: accountId,
      error: ''
    };
  } catch (_error) {
    return {
      ok: false,
      stripeAccountId: '',
      error: 'Invalid JSON response.'
    };
  }
}

export function parseStripeConnectOnboardingLinkResponse(rawJson: string): StripeConnectOnboardingLinkResult {
  try {
    const parsed = JSON.parse(rawJson) as Record<string, Object | string | number | boolean | null | undefined>;
    const url = textOf(parsed.url).trim();
    if (url.indexOf('https://') !== 0) {
      const error = stripeErrorText(parsed);
      return {
        ok: false,
        url: '',
        error: error.length > 0 ? error : 'Missing onboarding URL.'
      };
    }
    return {
      ok: true,
      url: url,
      error: ''
    };
  } catch (_error) {
    return {
      ok: false,
      url: '',
      error: 'Invalid JSON response.'
    };
  }
}

export function parseStripeConnectStatusResponse(rawJson: string): StripeConnectStatusResult {
  try {
    const parsed = JSON.parse(rawJson) as Record<string, Object | string | number | boolean | null | undefined>;
    const error = stripeErrorText(parsed);
    if (error.length > 0) {
      return {
        ok: false,
        payload: emptyStatusPayload(),
        error: error
      };
    }
    const requirements = objectOf(parsed.requirements);
    const capabilities = objectOf(parsed.capabilities);
    const due = Array.isArray(requirements.currently_due) ? requirements.currently_due as string[] : [];
    return {
      ok: true,
      payload: {
        stripeAccountId: textOf(parsed.id).trim(),
        chargesEnabled: boolOf(parsed.charges_enabled),
        payoutsEnabled: boolOf(parsed.payouts_enabled),
        cardPayments: textOf(capabilities.card_payments).trim(),
        transfers: textOf(capabilities.transfers).trim(),
        currentlyDue: due
      },
      error: ''
    };
  } catch (_error) {
    return {
      ok: false,
      payload: emptyStatusPayload(),
      error: 'Invalid JSON response.'
    };
  }
}

async function requestStripe(requestData: StripeConnectApiRequest): Promise<string> {
  const request = http.createHttp();
  try {
    const response = await request.request(requestData.url, {
      method: requestData.method === 'GET' ? http.RequestMethod.GET : http.RequestMethod.POST,
      header: requestData.headers,
      extraData: requestData.body.length > 0 ? requestData.body : undefined,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 20000
    });
    return responseText(response.result);
  } finally {
    request.destroy();
  }
}

export async function createStripeConnectAccount(secretKey: string, body: Object): Promise<StripeConnectAccountResult> {
  if (secretKey.trim().length === 0) {
    return { ok: false, stripeAccountId: '', error: 'Missing Stripe secret key.' };
  }
  return parseStripeConnectAccountResponse(await requestStripe(buildStripeConnectAccountRequest(secretKey, body)));
}

export async function createStripeConnectOnboardingLink(secretKey: string, body: Object, returnUrl: string, refreshUrl: string): Promise<StripeConnectOnboardingLinkResult> {
  if (secretKey.trim().length === 0) {
    return { ok: false, url: '', error: 'Missing Stripe secret key.' };
  }
  return parseStripeConnectOnboardingLinkResponse(await requestStripe(buildStripeConnectOnboardingLinkRequest(secretKey, body, returnUrl, refreshUrl)));
}

export async function fetchStripeConnectStatus(secretKey: string, body: Object): Promise<StripeConnectStatusResult> {
  if (secretKey.trim().length === 0) {
    return { ok: false, payload: emptyStatusPayload(), error: 'Missing Stripe secret key.' };
  }
  return parseStripeConnectStatusResponse(await requestStripe(buildStripeConnectStatusRequest(secretKey, body)));
}
