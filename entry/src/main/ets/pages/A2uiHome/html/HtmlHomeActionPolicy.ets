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

interface HtmlMailReplyPayload {
  requestKey?: HtmlHomePolicyValue;
  provider?: HtmlHomePolicyValue;
  accountLabel?: HtmlHomePolicyValue;
  threadId?: HtmlHomePolicyValue;
  messageId?: HtmlHomePolicyValue;
  to?: HtmlHomePolicyValue;
  subject?: HtmlHomePolicyValue;
  body?: HtmlHomePolicyValue;
  replyMode?: HtmlHomePolicyValue;
}

interface HtmlMailCalendarPayload {
  requestKey?: HtmlHomePolicyValue;
  provider?: HtmlHomePolicyValue;
  threadId?: HtmlHomePolicyValue;
  messageId?: HtmlHomePolicyValue;
}

interface HtmlCalendarDeletePayload {
  eventId?: HtmlHomePolicyValue;
  calendarId?: HtmlHomePolicyValue;
  confirmed?: HtmlHomePolicyValue;
}

interface LuckinPreviewArgs {
  deptId?: HtmlHomePolicyValue;
  productId?: HtmlHomePolicyValue;
  skuCode?: HtmlHomePolicyValue;
  location?: HtmlHomePolicyValue;
  attrGroup?: HtmlHomePolicyValue;
  attrChoice?: HtmlHomePolicyValue;
  locationSource?: HtmlHomePolicyValue;
}

interface LuckinCreateArgs {
  deptId?: HtmlHomePolicyValue;
  productId?: HtmlHomePolicyValue;
  skuCode?: HtmlHomePolicyValue;
  location?: HtmlHomePolicyValue;
}

interface LuckinPaymentArgs {
  orderId?: HtmlHomePolicyValue;
  payOrderUrl?: HtmlHomePolicyValue;
  payOrderQrCodeUrl?: HtmlHomePolicyValue;
}

export function isHtmlHomeActionAllowed(document: HtmlHomeDocument, action: A2uiAction): boolean {
  if (action.id.length === 0 || action.id === 'hotel.book') {
    return false;
  }
  if (action.id === 'flight_retry_date') {
    return hasBlockKind(document, 'flight-option');
  }
  if (action.id === 'payment.account.save' && paymentAccountSaveAllowed(document, action)) {
    return true;
  }
  if (action.id === 'calendar.event.delete.confirm' && calendarDeleteConfirmAllowed(document, action)) {
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
    if ((action.id === 'html_mail_reply_save' || action.id === 'html_mail_reply_send') &&
      mailReplySubmissionAllowed(block, action)) {
      return true;
    }
    if (action.id === 'html_mail_reply_ai_generate' && mailReplyAiGenerateAllowed(block, action)) {
      return true;
    }
    if (action.id === 'html_mail_calendar_add' && mailCalendarAddAllowed(block, action)) {
      return true;
    }
    for (let actionIndex = 0; actionIndex < block.actions.length; actionIndex++) {
      if (sameAction(block.actions[actionIndex], action)) {
        return true;
      }
    }
  }
  if (luckinPreviewAllowed(document, action)) {
    return true;
  }
  if (luckinCreateAllowed(document, action)) {
    return true;
  }
  if (luckinPaymentPageAllowed(document, action)) {
    return true;
  }
  return false;
}

function calendarDeleteConfirmAllowed(document: HtmlHomeDocument, action: A2uiAction): boolean {
  if (action.kind !== 'prompt' || action.args === undefined) {
    return false;
  }
  const args = action.args as HtmlCalendarDeletePayload;
  const eventId = policyText(args.eventId).trim();
  if (eventId.length === 0 || args.confirmed !== true) {
    return false;
  }
  for (let blockIndex = 0; blockIndex < document.blocks.length; blockIndex++) {
    const block = document.blocks[blockIndex];
    const calendarBlock = policyText(block.toolId).indexOf('calendar.') === 0 ||
      policyText(block.source).indexOf('Google Calendar') >= 0;
    if (!calendarBlock) {
      continue;
    }
    for (let rowIndex = 0; rowIndex < block.rows.length; rowIndex++) {
      if (policyText(block.rows[rowIndex].label).trim() === 'Event ID' &&
        policyText(block.rows[rowIndex].value).trim() === eventId) {
        return true;
      }
    }
  }
  return false;
}

function mailCalendarAddAllowed(block: HtmlHomeBlock, action: A2uiAction): boolean {
  if (block.kind !== 'generic-tool-result' || action.kind !== 'client' || action.args === undefined) {
    return false;
  }
  const actual = action.args as HtmlMailCalendarPayload;
  let detailKey = '';
  let detailExpected: HtmlMailCalendarPayload | null = null;
  for (let index = 0; index < block.actions.length; index++) {
    const candidate = block.actions[index];
    if (candidate.id === 'html_mail_detail_read') {
      detailKey = candidate.prompt;
      if (candidate.args !== undefined) {
        detailExpected = candidate.args as HtmlMailCalendarPayload;
      }
    }
  }
  if (detailExpected === null || detailKey.length === 0 ||
    action.prompt !== detailKey || policyText(actual.requestKey) !== detailKey) {
    return false;
  }
  return matchesOptionalMailIdentity(actual.provider, detailExpected.provider) &&
    matchesOptionalMailIdentity(actual.threadId, detailExpected.threadId) &&
    matchesOptionalMailIdentity(actual.messageId, detailExpected.messageId);
}

function policyStringList(value: HtmlHomePolicyValue): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const result: string[] = [];
  value.forEach((item: Object | string | number | boolean | null | undefined) => {
    const text = policyText(item).trim();
    if (text.length > 0) {
      result.push(text);
    }
  });
  return result;
}

function mailReplySubmissionAllowed(block: HtmlHomeBlock, action: A2uiAction): boolean {
  if (block.kind !== 'generic-tool-result' || action.kind !== 'client' || action.args === undefined) {
    return false;
  }
  const actual = action.args as HtmlMailReplyPayload;
  const recipients = policyStringList(actual.to);
  if (policyText(actual.body).trim().length === 0 || recipients.length === 0) {
    return false;
  }
  let detailKey = '';
  let detailExpected: HtmlMailReplyPayload | null = null;
  let expected: HtmlMailReplyPayload | null = null;
  for (let index = 0; index < block.actions.length; index++) {
    const candidate = block.actions[index];
    if (candidate.id === 'html_mail_detail_read') {
      detailKey = candidate.prompt;
      if (candidate.args !== undefined) {
        detailExpected = candidate.args as HtmlMailReplyPayload;
      }
    }
    if ((candidate.id === 'mail.ai.reply.draft' || candidate.id === 'gmail.ai.reply.draft') &&
      candidate.args !== undefined) {
      expected = candidate.args as HtmlMailReplyPayload;
    }
  }
  if (detailExpected === null || expected === null || detailKey.length === 0 || action.prompt !== detailKey ||
    policyText(actual.requestKey) !== detailKey) {
    return false;
  }
  return matchesRequiredMailIdentity(actual.provider, detailExpected.provider) &&
    matchesRequiredMailIdentity(actual.threadId, detailExpected.threadId) &&
    matchesRequiredMailIdentity(actual.messageId, detailExpected.messageId) &&
    matchesOptionalMailIdentity(actual.accountLabel, expected.accountLabel) &&
    matchesOptionalMailIdentity(actual.subject, expected.subject) &&
    matchesOptionalMailIdentity(actual.replyMode, expected.replyMode) &&
    policyStringList(actual.to).join('\n') === policyStringList(expected.to).join('\n');
}

function mailReplyAiGenerateAllowed(block: HtmlHomeBlock, action: A2uiAction): boolean {
  if (block.kind !== 'generic-tool-result' || action.kind !== 'client' || action.args === undefined) {
    return false;
  }
  const actual = action.args as HtmlMailReplyPayload;
  let detailKey = '';
  let expected: HtmlMailReplyPayload | null = null;
  for (let index = 0; index < block.actions.length; index++) {
    const candidate = block.actions[index];
    if (candidate.id === 'html_mail_detail_read') {
      detailKey = candidate.prompt;
      if (candidate.args !== undefined) {
        expected = candidate.args as HtmlMailReplyPayload;
      }
    }
    if ((candidate.id === 'mail.ai.reply.draft' || candidate.id === 'gmail.ai.reply.draft') &&
      candidate.args !== undefined) {
      expected = candidate.args as HtmlMailReplyPayload;
    }
  }
  if (expected === null || detailKey.length === 0 ||
    action.prompt !== detailKey || policyText(actual.requestKey) !== detailKey) {
    return false;
  }
  return matchesOptionalMailIdentity(actual.provider, expected.provider) &&
    matchesOptionalMailIdentity(actual.threadId, expected.threadId) &&
    matchesOptionalMailIdentity(actual.messageId, expected.messageId);
}

function matchesOptionalMailIdentity(actual: HtmlHomePolicyValue, expected: HtmlHomePolicyValue): boolean {
  const expectedText = policyText(expected).trim();
  return expectedText.length === 0 || policyText(actual).trim() === expectedText;
}

function matchesRequiredMailIdentity(actual: HtmlHomePolicyValue, expected: HtmlHomePolicyValue): boolean {
  const expectedText = policyText(expected).trim();
  return expectedText.length > 0 && policyText(actual).trim() === expectedText;
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

function hasLuckinConfirmOrderBlock(document: HtmlHomeDocument): boolean {
  for (let index = 0; index < document.blocks.length; index++) {
    const title = policyText(document.blocks[index].title).trim();
    if (title.indexOf('确认瑞幸订单') >= 0) {
      return true;
    }
  }
  return false;
}

function hasLuckinPaymentOrderBlock(document: HtmlHomeDocument): boolean {
  for (let index = 0; index < document.blocks.length; index++) {
    const title = policyText(document.blocks[index].title).trim();
    if (title.indexOf('瑞幸订单已创建') >= 0) {
      return true;
    }
  }
  return false;
}

function luckinPaymentOrderId(action: A2uiAction): string {
  if (action.args === undefined) {
    return '';
  }
  const args = action.args as LuckinPaymentArgs;
  return policyText(args.orderId).trim();
}

function luckinPaymentPageAllowed(document: HtmlHomeDocument, action: A2uiAction): boolean {
  if (document.kind !== 'luckin' || !hasLuckinPaymentOrderBlock(document)) {
    return false;
  }
  if (action.id === 'luckin.pay.open' && action.kind === 'client') {
    return true;
  }
  if (action.id === 'luckin.demo.alipay.open' && action.kind === 'client') {
    return true;
  }
  if (action.id === 'luckin.demo.googlepay.open' && action.kind === 'client') {
    return true;
  }
  if (action.id === 'luckin.order.status' && action.kind === 'prompt') {
    return action.prompt.indexOf('查询瑞幸订单状态') >= 0 || luckinPaymentOrderId(action).length > 0;
  }
  return false;
}

function luckinPreviewAllowed(document: HtmlHomeDocument, action: A2uiAction): boolean {
  if (document.kind !== 'luckin' || action.id !== 'luckin.order.preview') {
    return false;
  }
  if (action.args === undefined) {
    return false;
  }
  const args = action.args as LuckinPreviewArgs;
  const deptId = policyText(args.deptId).trim();
  const attrGroup = policyText(args.attrGroup).trim();
  const attrChoice = policyText(args.attrChoice).trim();
  if (deptId.length > 0) {
    if (attrGroup.length > 0 && attrChoice.length > 0) {
      return hasLuckinConfirmOrderBlock(document) &&
        policyText(args.productId).trim().length > 0 &&
        policyText(args.skuCode).trim().length > 0 &&
        policyText(args.location).trim().length > 0;
    }
    return true;
  }
  return policyText(args.locationSource).trim() === 'refresh';
}

function luckinCreateAllowed(document: HtmlHomeDocument, action: A2uiAction): boolean {
  if (document.kind !== 'luckin' || action.id !== 'luckin.order.create') {
    return false;
  }
  if (!hasLuckinConfirmOrderBlock(document)) {
    return false;
  }
  if (action.args === undefined) {
    return false;
  }
  const args = action.args as LuckinCreateArgs;
  const deptId = policyText(args.deptId).trim();
  const productId = policyText(args.productId).trim();
  const skuCode = policyText(args.skuCode).trim();
  if (deptId.length === 0 || productId.length === 0 || skuCode.length === 0) {
    return false;
  }
  for (let blockIndex = 0; blockIndex < document.blocks.length; blockIndex++) {
    const block = document.blocks[blockIndex];
    if (policyText(block.title).indexOf('确认瑞幸订单') < 0) {
      continue;
    }
    for (let actionIndex = 0; actionIndex < block.actions.length; actionIndex++) {
      const expected = block.actions[actionIndex];
      if (expected.id !== 'luckin.order.create' || expected.args === undefined) {
        continue;
      }
      const expectedArgs = expected.args as LuckinCreateArgs;
      if (policyText(expectedArgs.deptId).trim() === deptId &&
        policyText(expectedArgs.productId).trim() === productId) {
        return true;
      }
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
