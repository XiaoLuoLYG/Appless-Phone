export interface StripeCheckoutSessionInput {
  secretKey: string;
  connectedAccountId: string;
  amountMinor: number;
  currency: string;
  merchantName: string;
  successUrl: string;
  cancelUrl: string;
  idempotencyKey: string;
  note: string;
}

export interface StripeCheckoutHeaders {
  Authorization: string;
  ContentType: string;
  IdempotencyKey: string;
}

export interface StripeHttpRequest {
  method: string;
  url: string;
  headers: StripeCheckoutHeaders;
  body: string;
}

interface StripeCheckoutSessionResponse {
  id?: string;
  url?: string;
  status?: string;
  payment_status?: string;
}

interface FormPair {
  key: string;
  value: string;
}

function formPair(key: string, value: string): FormPair {
  return {
    key: key,
    value: value
  };
}

function formEncode(pairs: FormPair[]): string {
  const parts: string[] = [];
  pairs.forEach((pair: FormPair) => {
    parts.push(encodeURIComponent(pair.key) + '=' + encodeURIComponent(pair.value));
  });
  return parts.join('&');
}

function normalizedCurrency(currency: string): string {
  const trimmed = currency.trim();
  return trimmed.length > 0 ? trimmed.toLowerCase() : 'usd';
}

function productName(input: StripeCheckoutSessionInput): string {
  const merchant = input.merchantName.trim();
  return merchant.length > 0 ? merchant + ' payment' : 'AIPhone payment';
}

export function buildStripeCheckoutSessionRequest(input: StripeCheckoutSessionInput): StripeHttpRequest {
  const pairs: FormPair[] = [
    formPair('mode', 'payment'),
    formPair('success_url', input.successUrl.trim()),
    formPair('cancel_url', input.cancelUrl.trim()),
    formPair('line_items[0][price_data][currency]', normalizedCurrency(input.currency)),
    formPair('line_items[0][price_data][product_data][name]', productName(input)),
    formPair('line_items[0][price_data][unit_amount]', input.amountMinor.toString()),
    formPair('line_items[0][quantity]', '1'),
    formPair('payment_intent_data[transfer_data][destination]', input.connectedAccountId.trim())
  ];
  if (input.note.trim().length > 0) {
    pairs.push(formPair('metadata[note]', input.note.trim()));
    pairs.push(formPair('payment_intent_data[metadata][note]', input.note.trim()));
  }
  return {
    method: 'POST',
    url: 'https://api.stripe.com/v1/checkout/sessions',
    headers: {
      Authorization: 'Bearer ' + input.secretKey.trim(),
      ContentType: 'application/x-www-form-urlencoded',
      IdempotencyKey: input.idempotencyKey.trim()
    },
    body: formEncode(pairs)
  };
}

export function stripeCheckoutUrlFromResponse(rawJson: string): string {
  let parsed: StripeCheckoutSessionResponse;
  try {
    parsed = JSON.parse(rawJson) as StripeCheckoutSessionResponse;
  } catch (_error) {
    return '';
  }
  const url = parsed.url === undefined ? '' : parsed.url;
  return url.indexOf('https://checkout.stripe.com/') === 0 ? url : '';
}
