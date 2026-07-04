export type PaymentProvider = '' | 'paypal' | 'stripe';
export type PaymentTargetType = 'none' | 'paypal' | 'stripe_connected' | 'stripe_payment_link' | 'choice';
export type PaymentMode = 'test' | 'live';
export type PaymentValidationStatus =
  'needs_recipient' | 'needs_provider' | 'needs_amount' | 'confirm' | 'checkout' | 'blocked' | 'cancelled';
export type PaymentRecipientResolutionStatus = 'resolved' | 'unknown' | 'ambiguous';

export interface PaymentAccount {
  id: string;
  displayName: string;
  aliases: string[];
  email: string;
  paypalEmail: string;
  paypalMerchantId: string;
  stripeAccountId: string;
  stripePaymentLinkUrl: string;
  enabled: boolean;
}

export interface PaymentRequestDraft {
  recipient: string;
  provider: PaymentProvider;
  amountText: string;
  currency: string;
  note: string;
  phase?: string;
}

export interface PaymentPolicy {
  mode: PaymentMode;
  defaultCurrency: string;
  liveMaxAmountMinor: number;
  liveAllowedStripeAccountIds: string[];
}

export interface PaymentProviderSelection {
  targetType: PaymentTargetType;
  reason: string;
}

export interface PaymentRecipientResolution {
  status: PaymentRecipientResolutionStatus;
  matches: PaymentAccount[];
  account: PaymentAccount | null;
}

export interface NormalizedPaymentAmount {
  ok: boolean;
  amountMinor: number;
  currency: string;
  reason: string;
}

export interface PaymentValidationResult {
  status: PaymentValidationStatus;
  targetType: PaymentTargetType;
  reason: string;
  recipient: string;
  accountId: string;
  displayName: string;
  provider: PaymentProvider;
  amountMinor: number;
  amountText: string;
  currency: string;
  note: string;
  mode: PaymentMode;
  paypalEmail: string;
  paypalMerchantId: string;
  stripeAccountId: string;
  stripePaymentLinkUrl: string;
}

function cleanText(value: string): string {
  return value.trim();
}

function normalizeKey(value: string): string {
  return cleanText(value).toLowerCase();
}

function hasText(value: string): boolean {
  return cleanText(value).length > 0;
}

function enabledAccount(account: PaymentAccount): boolean {
  return account.enabled;
}

function aliasesForAccount(account: PaymentAccount): string[] {
  const aliases: string[] = [account.id, account.displayName, account.email, account.paypalEmail, account.paypalMerchantId];
  for (let index = 0; index < account.aliases.length; index += 1) {
    aliases.push(account.aliases[index]);
  }
  return aliases;
}

function sameAccountToken(query: string, candidate: string): boolean {
  const left = normalizeKey(query);
  const right = normalizeKey(candidate);
  return left.length > 0 && left === right;
}

function hasPayPalTarget(account: PaymentAccount): boolean {
  return hasText(account.paypalEmail) || hasText(account.paypalMerchantId);
}

function hasStripeConnectedTarget(account: PaymentAccount): boolean {
  return hasText(account.stripeAccountId);
}

function hasStripePaymentLinkTarget(account: PaymentAccount): boolean {
  return hasText(account.stripePaymentLinkUrl);
}

function currencyOrDefault(currency: string, fallback: string): string {
  const value = cleanText(currency).toUpperCase();
  if (value.length > 0) {
    return value;
  }
  return cleanText(fallback).toUpperCase();
}

function minorUnitsForCurrency(currency: string): number {
  const upper = currency.toUpperCase();
  if (upper === 'JPY' || upper === 'KRW' || upper === 'VND') {
    return 0;
  }
  return 2;
}

function allDigits(value: string): boolean {
  if (value.length === 0) {
    return false;
  }
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index);
    if (code < 48 || code > 57) {
      return false;
    }
  }
  return true;
}

function amountMinorFromDecimal(normalized: string, currency: string): NormalizedPaymentAmount {
  const units = minorUnitsForCurrency(currency);
  const parts = normalized.split('.');
  if (parts.length > 2 || !allDigits(parts[0])) {
    return { ok: false, amountMinor: 0, currency: currency, reason: 'Invalid payment amount.' };
  }
  const whole = Number(parts[0]);
  if (units === 0) {
    if (parts.length > 1 && Number(parts[1]) > 0) {
      return { ok: false, amountMinor: 0, currency: currency, reason: 'Currency does not support decimal amounts.' };
    }
    if (whole <= 0) {
      return { ok: false, amountMinor: 0, currency: currency, reason: 'Amount must be greater than zero.' };
    }
    return { ok: true, amountMinor: whole, currency: currency, reason: '' };
  }

  let fraction = '';
  if (parts.length > 1) {
    fraction = parts[1];
  }
  if (fraction.length > units || (fraction.length > 0 && !allDigits(fraction))) {
    return { ok: false, amountMinor: 0, currency: currency, reason: 'Amount has too many decimal places.' };
  }
  while (fraction.length < units) {
    fraction += '0';
  }
  const minor = whole * 100 + Number(fraction);
  if (minor <= 0) {
    return { ok: false, amountMinor: 0, currency: currency, reason: 'Amount must be greater than zero.' };
  }
  return { ok: true, amountMinor: minor, currency: currency, reason: '' };
}

function emptyValidation(
  status: PaymentValidationStatus,
  reason: string,
  draft: PaymentRequestDraft,
  policy: PaymentPolicy,
  targetType: PaymentTargetType
): PaymentValidationResult {
  return {
    status: status,
    targetType: targetType,
    reason: reason,
    recipient: draft.recipient,
    accountId: '',
    displayName: '',
    provider: draft.provider,
    amountMinor: 0,
    amountText: cleanText(draft.amountText),
    currency: currencyOrDefault(draft.currency, policy.defaultCurrency),
    note: draft.note,
    mode: policy.mode,
    paypalEmail: '',
    paypalMerchantId: '',
    stripeAccountId: '',
    stripePaymentLinkUrl: ''
  };
}

function validationForAccount(
  status: PaymentValidationStatus,
  reason: string,
  draft: PaymentRequestDraft,
  policy: PaymentPolicy,
  account: PaymentAccount,
  targetType: PaymentTargetType,
  amount: NormalizedPaymentAmount
): PaymentValidationResult {
  return {
    status: status,
    targetType: targetType,
    reason: reason,
    recipient: draft.recipient,
    accountId: account.id,
    displayName: account.displayName,
    provider: draft.provider,
    amountMinor: amount.amountMinor,
    amountText: cleanText(draft.amountText),
    currency: amount.currency,
    note: draft.note,
    mode: policy.mode,
    paypalEmail: account.paypalEmail,
    paypalMerchantId: account.paypalMerchantId,
    stripeAccountId: account.stripeAccountId,
    stripePaymentLinkUrl: account.stripePaymentLinkUrl
  };
}

export function defaultPaymentAccountBook(): PaymentAccount[] {
  return [
    {
      id: 'alex',
      displayName: 'Alex',
      aliases: ['Alex', '小明', '朋友 Alex'],
      email: '',
      paypalEmail: 'alex.paypal@example.com',
      paypalMerchantId: '',
      stripeAccountId: '',
      stripePaymentLinkUrl: '',
      enabled: true
    },
    {
      id: 'demo_vendor',
      displayName: 'Demo Vendor',
      aliases: ['Demo Vendor', '测试商户', 'demo 商户'],
      email: '',
      paypalEmail: '',
      paypalMerchantId: '',
      stripeAccountId: 'acct_test_demo_vendor',
      stripePaymentLinkUrl: '',
      enabled: true
    },
    {
      id: 'external_cafe',
      displayName: 'External Cafe',
      aliases: ['External Cafe', '外部咖啡店', 'external cafe'],
      email: '',
      paypalEmail: '',
      paypalMerchantId: '',
      stripeAccountId: '',
      stripePaymentLinkUrl: 'https://buy.stripe.com/test_external_cafe',
      enabled: true
    }
  ];
}

export function resolvePaymentAccount(query: string, book: PaymentAccount[]): PaymentRecipientResolution {
  const matches: PaymentAccount[] = [];
  for (let accountIndex = 0; accountIndex < book.length; accountIndex += 1) {
    const account = book[accountIndex];
    if (!enabledAccount(account)) {
      continue;
    }
    const aliases = aliasesForAccount(account);
    for (let aliasIndex = 0; aliasIndex < aliases.length; aliasIndex += 1) {
      if (sameAccountToken(query, aliases[aliasIndex])) {
        matches.push(account);
        break;
      }
    }
  }
  if (matches.length === 1) {
    return { status: 'resolved', matches: matches, account: matches[0] };
  }
  if (matches.length > 1) {
    return { status: 'ambiguous', matches: matches, account: null };
  }
  return { status: 'unknown', matches: matches, account: null };
}

export function normalizePaymentAmount(text: string, currency: string): NormalizedPaymentAmount {
  const normalizedCurrency = currencyOrDefault(currency, 'USD');
  let normalized = cleanText(text);
  if (normalized.startsWith('$')) {
    normalized = normalized.substring(1);
  }
  normalized = normalized.replace(',', '');
  if (!hasText(normalized)) {
    return { ok: false, amountMinor: 0, currency: normalizedCurrency, reason: 'Amount is required.' };
  }
  if (normalized.indexOf('-') >= 0 || normalized.indexOf('+') >= 0) {
    return { ok: false, amountMinor: 0, currency: normalizedCurrency, reason: 'Invalid payment amount.' };
  }
  return amountMinorFromDecimal(normalized, normalizedCurrency);
}

export function isStripePaymentLinkUrl(url: string): boolean {
  const trimmed = cleanText(url);
  if (!trimmed.startsWith('https://')) {
    return false;
  }
  const lower = trimmed.toLowerCase();
  return lower.startsWith('https://buy.stripe.com/') || lower.startsWith('https://checkout.stripe.com/');
}

export function paymentProviderForAccount(account: PaymentAccount, requestedProvider: PaymentProvider): PaymentProviderSelection {
  const hasPayPal = hasPayPalTarget(account);
  const hasStripeConnected = hasStripeConnectedTarget(account);
  const hasStripeLink = hasStripePaymentLinkTarget(account);
  const hasStripe = hasStripeConnected || hasStripeLink;

  if (requestedProvider === 'paypal') {
    if (hasPayPal) {
      return { targetType: 'paypal', reason: '' };
    }
    return { targetType: 'none', reason: 'Recipient has no PayPal account mapping.' };
  }

  if (requestedProvider === 'stripe') {
    if (hasStripeConnected) {
      return { targetType: 'stripe_connected', reason: '' };
    }
    if (hasStripeLink) {
      return { targetType: 'stripe_payment_link', reason: '' };
    }
    return { targetType: 'none', reason: 'Recipient has no Stripe merchant mapping.' };
  }

  if (hasPayPal && hasStripe) {
    return { targetType: 'choice', reason: 'Recipient supports both PayPal and Stripe.' };
  }
  if (hasPayPal) {
    return { targetType: 'paypal', reason: '' };
  }
  if (hasStripeConnected) {
    return { targetType: 'stripe_connected', reason: '' };
  }
  if (hasStripeLink) {
    return { targetType: 'stripe_payment_link', reason: '' };
  }
  return { targetType: 'none', reason: 'Recipient has no payment account mapping.' };
}

export function validatePaymentRequest(
  draft: PaymentRequestDraft,
  book: PaymentAccount[],
  policy: PaymentPolicy
): PaymentValidationResult {
  if (!hasText(draft.recipient)) {
    return emptyValidation('needs_recipient', 'Recipient is required.', draft, policy, 'none');
  }

  const resolution = resolvePaymentAccount(draft.recipient, book);
  if (resolution.status === 'unknown' || resolution.account === null) {
    return emptyValidation('needs_recipient', 'Recipient is not in the payment account book.', draft, policy, 'none');
  }
  if (resolution.status === 'ambiguous') {
    return emptyValidation('needs_recipient', 'Recipient matches multiple payment accounts.', draft, policy, 'none');
  }

  const account = resolution.account;
  const selection = paymentProviderForAccount(account, draft.provider);
  if (selection.targetType === 'none') {
    return validationForAccount(
      'blocked',
      selection.reason,
      draft,
      policy,
      account,
      'none',
      { ok: false, amountMinor: 0, currency: currencyOrDefault(draft.currency, policy.defaultCurrency), reason: selection.reason }
    );
  }
  if (selection.targetType === 'choice') {
    return validationForAccount(
      'needs_provider',
      selection.reason,
      draft,
      policy,
      account,
      'choice',
      { ok: false, amountMinor: 0, currency: currencyOrDefault(draft.currency, policy.defaultCurrency), reason: selection.reason }
    );
  }

  if (selection.targetType === 'stripe_payment_link' && !isStripePaymentLinkUrl(account.stripePaymentLinkUrl)) {
    return validationForAccount(
      'blocked',
      'Stripe payment URL must be an HTTPS Stripe Checkout or Payment Link URL.',
      draft,
      policy,
      account,
      selection.targetType,
      { ok: false, amountMinor: 0, currency: currencyOrDefault(draft.currency, policy.defaultCurrency), reason: '' }
    );
  }

  const amount = normalizePaymentAmount(draft.amountText, currencyOrDefault(draft.currency, policy.defaultCurrency));
  if (!amount.ok && selection.targetType !== 'stripe_payment_link') {
    return validationForAccount('needs_amount', amount.reason, draft, policy, account, selection.targetType, amount);
  }

  if (policy.mode === 'live' && selection.targetType === 'stripe_connected') {
    if (policy.liveAllowedStripeAccountIds.indexOf(account.stripeAccountId) < 0) {
      return validationForAccount(
        'blocked',
        'Live Stripe merchant is not on the allowlist.',
        draft,
        policy,
        account,
        selection.targetType,
        amount
      );
    }
    if (amount.amountMinor > policy.liveMaxAmountMinor) {
      return validationForAccount(
        'blocked',
        'Live amount exceeds the local safety cap.',
        draft,
        policy,
        account,
        selection.targetType,
        amount
      );
    }
  }

  if (selection.targetType === 'stripe_payment_link' && !amount.ok) {
    return validationForAccount(
      'confirm',
      'Amount will be controlled by the merchant Stripe Payment Link.',
      draft,
      policy,
      account,
      selection.targetType,
      { ok: true, amountMinor: 0, currency: currencyOrDefault(draft.currency, policy.defaultCurrency), reason: '' }
    );
  }

  return validationForAccount('confirm', '', draft, policy, account, selection.targetType, amount);
}

export function paymentIdempotencyKey(result: PaymentValidationResult): string {
  return [
    result.mode,
    result.accountId,
    result.targetType,
    result.amountMinor.toString(),
    result.currency,
    result.note
  ].join(':');
}
