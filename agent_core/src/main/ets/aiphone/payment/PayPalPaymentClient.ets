import { utf8Bytes } from '../runtime/Utf8Bytes';

export type PayPalEnvironment = 'sandbox' | 'live';

export interface PayPalTokenRequestInput {
  environment: PayPalEnvironment;
  clientId: string;
  clientSecret: string;
}

export interface PayPalOrderRequestInput {
  environment: PayPalEnvironment;
  accessToken: string;
  amountText: string;
  currency: string;
  payeeEmail: string;
  payeeMerchantId: string;
  returnUrl: string;
  cancelUrl: string;
  note: string;
}

export interface PayPalHttpHeaders {
  Authorization: string;
  'Content-Type': string;
  Accept: string;
}

export interface PayPalHttpRequest {
  method: string;
  url: string;
  headers: PayPalHttpHeaders;
  body: string;
}

interface PayPalAmountPayload {
  value: string;
  currency_code: string;
}

interface PayPalPayeePayload {
  email_address?: string;
  merchant_id?: string;
}

interface PayPalPurchaseUnitPayload {
  amount: PayPalAmountPayload;
  payee: PayPalPayeePayload;
  description?: string;
}

interface PayPalApplicationContextPayload {
  return_url: string;
  cancel_url: string;
  user_action: string;
}

interface PayPalOrderPayload {
  intent: string;
  purchase_units: PayPalPurchaseUnitPayload[];
  application_context: PayPalApplicationContextPayload;
}

interface PayPalLinkPayload {
  rel?: string;
  href?: string;
}

interface PayPalOrderResponsePayload {
  links?: PayPalLinkPayload[];
}

function paypalBaseUrl(environment: PayPalEnvironment): string {
  return environment === 'live' ? 'https://api-m.paypal.com' : 'https://api-m.sandbox.paypal.com';
}

function bytesToBase64(bytes: Uint8Array): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let result = '';
  for (let index = 0; index < bytes.length; index += 3) {
    const first = bytes[index];
    const second = index + 1 < bytes.length ? bytes[index + 1] : 0;
    const third = index + 2 < bytes.length ? bytes[index + 2] : 0;
    const triple = (first << 16) | (second << 8) | third;
    result += alphabet.charAt((triple >> 18) & 0x3f);
    result += alphabet.charAt((triple >> 12) & 0x3f);
    result += index + 1 < bytes.length ? alphabet.charAt((triple >> 6) & 0x3f) : '=';
    result += index + 2 < bytes.length ? alphabet.charAt(triple & 0x3f) : '=';
  }
  return result;
}

function basicAuth(clientId: string, clientSecret: string): string {
  return 'Basic ' + bytesToBase64(utf8Bytes(clientId + ':' + clientSecret));
}

function tokenHeaders(input: PayPalTokenRequestInput): PayPalHttpHeaders {
  return {
    Authorization: basicAuth(input.clientId, input.clientSecret),
    'Content-Type': 'application/x-www-form-urlencoded',
    Accept: 'application/json'
  };
}

function bearerHeaders(accessToken: string): PayPalHttpHeaders {
  return {
    Authorization: 'Bearer ' + accessToken,
    'Content-Type': 'application/json',
    Accept: 'application/json'
  };
}

function orderPayee(input: PayPalOrderRequestInput): PayPalPayeePayload {
  const payee: PayPalPayeePayload = {};
  if (input.payeeEmail.trim().length > 0) {
    payee.email_address = input.payeeEmail.trim();
  }
  if (input.payeeMerchantId.trim().length > 0) {
    payee.merchant_id = input.payeeMerchantId.trim();
  }
  return payee;
}

function orderPayload(input: PayPalOrderRequestInput): PayPalOrderPayload {
  const purchaseUnit: PayPalPurchaseUnitPayload = {
    amount: {
      value: input.amountText.trim(),
      currency_code: input.currency.trim().toUpperCase()
    },
    payee: orderPayee(input)
  };
  if (input.note.trim().length > 0) {
    purchaseUnit.description = input.note.trim();
  }
  return {
    intent: 'CAPTURE',
    purchase_units: [purchaseUnit],
    application_context: {
      return_url: input.returnUrl.trim(),
      cancel_url: input.cancelUrl.trim(),
      user_action: 'PAY_NOW'
    }
  };
}

export function buildPayPalTokenRequest(input: PayPalTokenRequestInput): PayPalHttpRequest {
  return {
    method: 'POST',
    url: paypalBaseUrl(input.environment) + '/v1/oauth2/token',
    headers: tokenHeaders(input),
    body: 'grant_type=client_credentials'
  };
}

export function buildPayPalOrderRequest(input: PayPalOrderRequestInput): PayPalHttpRequest {
  return {
    method: 'POST',
    url: paypalBaseUrl(input.environment) + '/v2/checkout/orders',
    headers: bearerHeaders(input.accessToken.trim()),
    body: JSON.stringify(orderPayload(input))
  };
}

export function paypalApprovalUrlFromOrder(rawJson: string): string {
  let parsed: PayPalOrderResponsePayload;
  try {
    parsed = JSON.parse(rawJson) as PayPalOrderResponsePayload;
  } catch (_error) {
    return '';
  }
  const links = parsed.links === undefined ? [] : parsed.links;
  for (let index = 0; index < links.length; index++) {
    const link = links[index];
    const rel = link.rel === undefined ? '' : link.rel;
    const href = link.href === undefined ? '' : link.href;
    if (rel.toLowerCase() === 'approve' && href.indexOf('https://') === 0) {
      return href;
    }
  }
  return '';
}
