import { A2uiAction } from '@loop/agent-core';
import { HtmlHomeAction, HtmlHomeBlock, HtmlHomeDocument } from './HtmlHomeTypes';

type HtmlHomePolicyValue = Object | string | number | boolean | null | undefined;

interface HtmlDynamicCredentialPayload {
  credentialRef?: string;
  credentialValue?: string;
  toolId?: string;
  prompt?: string;
}

interface HtmlPaymentAccountPayload {
  displayName?: HtmlHomePolicyValue;
  aliases?: HtmlHomePolicyValue;
  paypalEmail?: HtmlHomePolicyValue;
  paypalMerchantId?: HtmlHomePolicyValue;
  stripeAccountId?: HtmlHomePolicyValue;
  stripePaymentLinkUrl?: HtmlHomePolicyValue;
}

interface HtmlStripeOnboardingPayload {
  onboardingUrl?: HtmlHomePolicyValue;
}

interface HtmlPaymentCapturePayload {
  provider?: HtmlHomePolicyValue;
  phase?: HtmlHomePolicyValue;
  providerSessionId?: HtmlHomePolicyValue;
}

export function isHtmlHomeActionAllowed(document: HtmlHomeDocument, action: A2uiAction): boolean {
  if (action.id.length === 0) {
    return false;
  }
  if (action.id === 'flight_retry_date') {
    return hasBlockKind(document, 'flight-option');
  }
  if (action.id === 'payment.account.save' && paymentAccountSaveAllowed(document, action)) {
    return true;
  }
  for (let index = 0; index < document.actions.length; index++) {
    if (sameAction(document.actions[index], action)) {
      return true;
    }
  }
  for (let blockIndex = 0; blockIndex < document.blocks.length; blockIndex++) {
    const block = document.blocks[blockIndex];
    if (action.id === 'html_dynamic_save_and_test' && dynamicCredentialAllowed(block, action)) {
      return true;
    }
    if (action.id === 'stripe.account.open' && stripeReceivingOpenAllowed(block, action)) {
      return true;
    }
    if (action.id === 'payment.capture' && paymentCaptureAllowed(block, action)) {
      return true;
    }
    for (let actionIndex = 0; actionIndex < block.actions.length; actionIndex++) {
      if (sameAction(block.actions[actionIndex], action)) {
        return true;
      }
    }
  }
  return false;
}

function sameAction(expected: HtmlHomeAction, actual: A2uiAction): boolean {
  return expected.id === actual.id &&
    expected.kind === actual.kind &&
    expected.prompt === actual.prompt &&
    actionArgsJson(expected.args) === actionArgsJson(actual.args);
}

function actionArgsJson(args: Object | undefined): string {
  if (args === undefined || args === null) {
    return '';
  }
  return JSON.stringify(args);
}

function hasBlockKind(document: HtmlHomeDocument, kind: string): boolean {
  for (let index = 0; index < document.blocks.length; index++) {
    if (document.blocks[index].kind === kind) {
      return true;
    }
  }
  return false;
}

function dynamicCredentialAllowed(block: HtmlHomeBlock, action: A2uiAction): boolean {
  if (block.kind !== 'dynamic-tool-connect') {
    return false;
  }
  let payload: HtmlDynamicCredentialPayload;
  try {
    payload = JSON.parse(action.prompt) as HtmlDynamicCredentialPayload;
  } catch (_error) {
    return false;
  }
  const credentialValue = policyText(payload.credentialValue).trim();
  return credentialValue.length > 0 &&
    policyText(payload.credentialRef) === policyText(block.credentialRef) &&
    policyText(payload.toolId) === policyText(block.toolId) &&
    policyText(payload.prompt) === policyText(block.prompt);
}

function paymentAccountSaveAllowed(document: HtmlHomeDocument, action: A2uiAction): boolean {
  if (document.kind !== 'payment' || !hasPaymentSendBlock(document)) {
    return false;
  }
  let payload: HtmlPaymentAccountPayload;
  try {
    payload = JSON.parse(action.prompt) as HtmlPaymentAccountPayload;
  } catch (_error) {
    return false;
  }
  return policyText(payload.displayName).trim().length > 0 &&
    (policyText(payload.paypalEmail).trim().length > 0 ||
      policyText(payload.paypalMerchantId).trim().length > 0 ||
      policyText(payload.stripeAccountId).trim().length > 0 ||
      policyText(payload.stripePaymentLinkUrl).trim().length > 0);
}

function hasPaymentSendBlock(document: HtmlHomeDocument): boolean {
  for (let index = 0; index < document.blocks.length; index++) {
    const block = document.blocks[index];
    if (block.kind === 'generic-tool-result' && blockHasMetric(block, 'toolName', 'payment.send')) {
      return true;
    }
  }
  return false;
}

function stripeReceivingOpenAllowed(block: HtmlHomeBlock, action: A2uiAction): boolean {
  if (block.kind !== 'StripeReceivingAccountCard' || block.stripeReceiving === undefined) {
    return false;
  }
  const expected = policyText(block.stripeReceiving.onboardingUrl).trim();
  if (!expected.startsWith('https://connect.stripe.com/')) {
    return false;
  }
  let candidate = action.prompt.trim();
  if (action.args !== undefined) {
    const payload = action.args as HtmlStripeOnboardingPayload;
    const fromArgs = policyText(payload.onboardingUrl).trim();
    if (fromArgs.length > 0) {
      candidate = fromArgs;
    }
  }
  return candidate === expected;
}

function paymentCaptureAllowed(block: HtmlHomeBlock, action: A2uiAction): boolean {
  if (block.kind !== 'generic-tool-result' || !blockHasMetric(block, 'toolName', 'payment.send')) {
    return false;
  }
  if (block.status !== 'needs_user' || !blockHasMetric(block, '付款方式偏好', 'Google Pay')) {
    return false;
  }
  if (action.args === undefined) {
    return false;
  }
  const actual = action.args as HtmlPaymentCapturePayload;
  const actualProvider = policyText(actual.provider).trim().toLowerCase();
  const actualPhase = policyText(actual.phase).trim().toLowerCase();
  const actualSession = policyText(actual.providerSessionId).trim();
  if (actualProvider !== 'paypal' || actualPhase !== 'capture' || actualSession.length === 0) {
    return false;
  }
  for (let index = 0; index < block.actions.length; index++) {
    const expected = block.actions[index];
    if (expected.id !== 'payment.checkout.open' || expected.args === undefined) {
      continue;
    }
    const payload = expected.args as HtmlPaymentCapturePayload;
    if (policyText(payload.provider).trim().toLowerCase() === 'paypal' &&
      policyText(payload.providerSessionId).trim() === actualSession) {
      return true;
    }
  }
  return false;
}

function blockHasMetric(block: HtmlHomeBlock, label: string, value: string): boolean {
  const rows = block.rows.concat(block.metrics);
  for (let index = 0; index < rows.length; index++) {
    if (policyText(rows[index].label).trim().toLowerCase() === label.toLowerCase() &&
      policyText(rows[index].value).trim() === value) {
      return true;
    }
  }
  return false;
}

function policyText(value: HtmlHomePolicyValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}
