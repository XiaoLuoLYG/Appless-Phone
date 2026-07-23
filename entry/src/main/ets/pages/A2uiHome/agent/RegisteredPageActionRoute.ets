import {
  A2uiAction,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  JsonValue,
  CalendarEventArgs,
  MapsRouteArgs,
  ToolDefinition,
  actionAgentToolDefinitions,
  calendarEventRequiredFields,
  mapsRouteInputFromPrompt,
  normalizedCalendarArgsForPrompt,
  toolDefinitionForToolId
} from '@loop/agent-core';
import { HtmlHomeDocument } from '../html/HtmlHomeTypes';

const PAGE_ACTION_CANDIDATE_IDS: string[] = [
  'luckin.order.preview',
  'luckin.order.create',
  'social.post.preview',
  'social.reply.draft',
  'mail.draft.create',
  'gmail.draft.create',
  'gmail.draft.apply',
  'gmail.open.web',
  'worldcup.open',
  'payment.confirm',
  'payment.send',
  'stripe.account.create',
  'stripe.account.onboard',
  'stripe.account.refresh',
  'payment.account.setup',
  'maps.route.open',
  'calendar.event.create',
  'calendar.event.update',
  'calendar.event.delete.confirm',
  'whatsapp.message.send.confirm',
  'ride.order.confirm',
  'ride.order.cancel',
  'hotel.navigate',
  'hotel.booking.open',
  'html_mail_detail_read'
];

export interface RegisteredPageActionResolution {
  action: A2uiAction;
  pageActionId: string;
}

export interface RegisteredPageSnapshot {
  surface: A2uiSurfaceState;
  document: HtmlHomeDocument;
  generation: number;
}

interface RegisteredPageSnapshotMaterial {
  surface: A2uiSurfaceState;
  document: HtmlHomeDocument;
}

export interface RegisteredPageDispatchResult {
  candidate: boolean;
  ok: boolean;
}

export type RegisteredPageCandidateRunner = (action: A2uiAction) => Promise<boolean>;
export type LegacyPageActionRunner = (action: A2uiAction) => Promise<void>;

interface WorldCupVirtualArgs {
  route: string;
}

interface OriginalQueryVirtualArgs {
  originalQuery: string;
}

interface SocialPostPreviewVirtualArgs {
  platform: string;
  operation: string;
  text: string;
}

interface WhatsAppVirtualArgs {
  toNumber: string;
  text: string;
}

interface GmailDraftVirtualArgs {
  to: string[];
  subject: string;
  body: string;
}

function virtualAction(actionId: string, inputText: string, args: Object): A2uiAction {
  return {
    id: actionId,
    label: actionId,
    prompt: inputText,
    variant: 'primary',
    kind: 'prompt',
    args
  };
}

function socialPostPreviewVirtualArgs(inputText: string): SocialPostPreviewVirtualArgs | null {
  const value = inputText.trim();
  const lower = value.toLowerCase();
  const chineseMarker = value.indexOf('发帖：');
  const asciiMarker = value.indexOf('发帖:');
  const postMarker = lower.indexOf('post:');
  let marker = chineseMarker >= 0 ? chineseMarker : asciiMarker;
  let markerLength = chineseMarker >= 0 ? '发帖：'.length : '发帖:'.length;
  if (marker < 0 && postMarker >= 0) {
    marker = postMarker;
    markerLength = 'post:'.length;
  }
  const draftMarker = value.indexOf('起草');
  const naturalDraft = marker < 0 && draftMarker >= 0;
  if (naturalDraft) {
    marker = draftMarker;
    markerLength = '起草'.length;
  }
  if (marker < 0) {
    return null;
  }
  const target = value.substring(0, marker);
  const targetLower = target.toLowerCase();
  const platforms: string[] = [];
  if (/(^|[^a-z])x([^a-z]|$)|twitter|x\.com/i.test(target)) {
    platforms.push('x');
  }
  if (targetLower.indexOf('linkedin') >= 0) {
    platforms.push('linkedin');
  }
  if (targetLower.indexOf('instagram') >= 0) {
    platforms.push('instagram');
  }
  if (targetLower.indexOf('reddit') >= 0) {
    platforms.push('reddit');
  }
  if (platforms.length !== 1) {
    return null;
  }
  let text = value.substring(marker + markerLength)
    .replace(/（只生成预览，不发布）$/, '')
    .replace(/\(preview only,? do not publish\)$/i, '')
    .trim();
  if (naturalDraft) {
    text = text.replace(/^一[条篇]/, '').replace(/的帖子$/, '').replace(/帖子$/, '').trim();
  }
  if (text.length === 0 || text.length > 3000) {
    return null;
  }
  return { platform: platforms[0], operation: 'publish', text };
}

function whatsAppVirtualArgs(inputText: string): WhatsAppVirtualArgs | null {
  const numbers = inputText.match(/\+[1-9][0-9]{7,14}/g);
  const chineseMarker = inputText.indexOf('发送消息：');
  const asciiMarker = inputText.indexOf('发送消息:');
  const marker = chineseMarker >= 0 ? chineseMarker : asciiMarker;
  const markerLength = chineseMarker >= 0 ? '发送消息：'.length : '发送消息:'.length;
  const numberIndex = numbers === null || numbers.length !== 1 ?
    -1 : inputText.indexOf(numbers[0]);
  const previous = numberIndex > 0 ? inputText.charAt(numberIndex - 1) : '';
  const nextIndex = numberIndex < 0 || numbers === null ?
    -1 : numberIndex + numbers[0].length;
  const next = nextIndex >= 0 && nextIndex < inputText.length ?
    inputText.charAt(nextIndex) : '';
  if (numbers === null || numbers.length !== 1 || marker < 0 ||
    numberIndex >= marker || previous === '+' || (next >= '0' && next <= '9')) {
    return null;
  }
  const text = inputText.substring(marker + markerLength).trim();
  if (text.length === 0 || text.length > 4096) {
    return null;
  }
  return { toNumber: numbers[0], text };
}

function gmailDraftVirtualArgs(inputText: string): GmailDraftVirtualArgs | null {
  const value = inputText.trim();
  const emails = value.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g);
  if (emails === null || emails.length !== 1 ||
    value.indexOf('Gmail') < 0 || value.indexOf('写一封邮件给') < 0) {
    return null;
  }
  const email = emails[0];
  const emailIndex = value.indexOf(email);
  const marker = value.indexOf('说', emailIndex + email.length);
  if (emailIndex < 0 || marker < 0 ||
    value.substring(emailIndex + email.length, marker).replace(/[，,\s]/g, '').length > 0) {
    return null;
  }
  const body = value.substring(marker + 1).trim();
  if (body.length === 0 || body.length > 4096) {
    return null;
  }
  return { to: [email], subject: '', body };
}

function registeredProductAction(actionId: string): boolean {
  return actionAgentToolDefinitions().some(
    (definition: ToolDefinition): boolean => definition.toolId === actionId
  );
}

function adaptedTarget(sourceToolId: string, clickedActionId: string): string {
  if (sourceToolId === 'payment.send' && clickedActionId === 'payment.confirm') {
    return 'payment.send';
  }
  if (sourceToolId === 'payment.account.setup' &&
    (clickedActionId === 'stripe.account.create' ||
      clickedActionId === 'stripe.account.onboard' ||
      clickedActionId === 'stripe.account.refresh')) {
    return 'payment.account.setup';
  }
  if ((sourceToolId === 'calendar.events.search' || sourceToolId === 'calendar.event.delete') &&
    clickedActionId === 'calendar.event.delete.confirm') {
    return 'calendar.event.delete';
  }
  if (sourceToolId === 'whatsapp.message.send' &&
    clickedActionId === 'whatsapp.message.send.confirm') {
    return 'whatsapp.message.send';
  }
  if (sourceToolId === 'ride.estimate' && clickedActionId === 'ride.order.confirm') {
    return 'ride.order.create';
  }
  return '';
}

function gmailReplySendTarget(sourceToolId: string, clicked: A2uiAction): string {
  if (clicked.id !== 'html_mail_reply_send' || clicked.kind !== 'client' ||
    clicked.args === undefined || clicked.args === null || Array.isArray(clicked.args) ||
    (sourceToolId !== 'mail.search' && sourceToolId !== 'mail.thread.read' &&
      sourceToolId !== 'gmail.mail.search' && sourceToolId !== 'gmail.thread.read')) {
    return '';
  }
  const values = clicked.args as Record<string, Object | string | number | boolean | null | undefined>;
  const provider = values['provider'];
  return typeof provider === 'string' && provider.trim().toLowerCase() === 'gmail' ?
    'gmail.message.send' : '';
}

function isGmailReplySendCandidate(action: A2uiAction): boolean {
  if (action.id !== 'html_mail_reply_send' || action.kind !== 'client' ||
    action.args === undefined || action.args === null || Array.isArray(action.args)) {
    return false;
  }
  const values = action.args as Record<string, Object | string | number | boolean | null | undefined>;
  const provider = values['provider'];
  return typeof provider === 'string' && provider.trim().toLowerCase() === 'gmail';
}

function mailDetailReadTarget(sourceToolId: string, clicked: A2uiAction): string {
  if (clicked.id !== 'html_mail_detail_read' || clicked.kind !== 'client' ||
    clicked.args === undefined || clicked.args === null || Array.isArray(clicked.args) ||
    (sourceToolId !== 'mail.search' && sourceToolId !== 'mail.thread.read' &&
      sourceToolId !== 'gmail.mail.search' && sourceToolId !== 'gmail.thread.read')) {
    return '';
  }
  const values = clicked.args as Record<string, Object | string | number | boolean | null | undefined>;
  const provider = values['provider'];
  if (typeof provider !== 'string') {
    return '';
  }
  const normalized = provider.trim().toLowerCase();
  return normalized === 'gmail' ? 'gmail.thread.read' :
    normalized === 'qq' ? 'mail.thread.read' : '';
}

function cloneSnapshot(snapshot: RegisteredPageSnapshot): RegisteredPageSnapshot | null {
  try {
    return JSON.parse(JSON.stringify(snapshot)) as RegisteredPageSnapshot;
  } catch (_error) {
    return null;
  }
}

function canonicalJson(value: JsonValue | undefined): string {
  if (value === undefined) {
    return '';
  }
  if (value === null || typeof value === 'string' ||
    typeof value === 'number' || typeof value === 'boolean') {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    const values = value as JsonValue[];
    const parts: string[] = [];
    for (let index = 0; index < values.length; index++) {
      parts.push(canonicalJson(values[index]));
    }
    return '[' + parts.join(',') + ']';
  }
  const record = value as Record<string, JsonValue | undefined>;
  const keys = Object.keys(record).sort();
  const parts: string[] = [];
  for (let index = 0; index < keys.length; index++) {
    const current = record[keys[index]];
    if (current !== undefined) {
      parts.push(JSON.stringify(keys[index]) + ':' + canonicalJson(current));
    }
  }
  return '{' + parts.join(',') + '}';
}

export function registeredPageSnapshotFingerprint(snapshot: RegisteredPageSnapshot): string {
  const material: RegisteredPageSnapshotMaterial = {
    surface: snapshot.surface,
    document: snapshot.document
  };
  return canonicalJson(material as Object);
}

export class RegisteredPageSnapshotStore {
  private snapshot: RegisteredPageSnapshot | null = null;
  private fingerprint: string = '';

  record(
    surface: A2uiSurfaceState,
    document: HtmlHomeDocument,
    generation: number
  ): boolean {
    if (!Number.isSafeInteger(generation) || generation <= 0 ||
      surface.surfaceId.trim().length === 0 ||
      document.surfaceId === undefined ||
      document.surfaceId !== surface.surfaceId ||
      document.generatedAt.trim().length === 0) {
      return false;
    }
    const candidate: RegisteredPageSnapshot = { surface, document, generation };
    const cloned = cloneSnapshot(candidate);
    if (cloned === null) {
      return false;
    }
    const nextFingerprint = registeredPageSnapshotFingerprint(cloned);
    if (this.snapshot !== null &&
      (generation < this.snapshot.generation ||
        (generation === this.snapshot.generation && nextFingerprint !== this.fingerprint))) {
      return false;
    }
    this.snapshot = cloned;
    this.fingerprint = nextFingerprint;
    return true;
  }

  current(): RegisteredPageSnapshot | null {
    return this.snapshot === null ? null : cloneSnapshot(this.snapshot);
  }

  clear(): void {
    this.snapshot = null;
    this.fingerprint = '';
  }
}

export function registeredPageSourceToolId(surface: A2uiSurfaceState): string {
  try {
    const model = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
    const sourceToolId = model.summary.toolName.trim();
    return toolDefinitionForToolId(sourceToolId) === null ? '' : sourceToolId;
  } catch (_error) {
    return '';
  }
}

export function resolveRegisteredPageAction(
  sourceToolId: string,
  clicked: A2uiAction
): RegisteredPageActionResolution | null {
  if (clicked.args === undefined || clicked.args === null ||
    typeof clicked.args !== 'object' || Array.isArray(clicked.args)) {
    return null;
  }
  const source = toolDefinitionForToolId(sourceToolId);
  if (source === null) {
    return null;
  }
  let targetId = '';
  const mailReadTarget = mailDetailReadTarget(sourceToolId, clicked);
  if (mailReadTarget.length > 0) {
    targetId = mailReadTarget;
  } else if ((source.actions.indexOf(clicked.id) >= 0 || sourceToolId === clicked.id) &&
    registeredProductAction(clicked.id)) {
    targetId = clicked.id;
  } else if (sourceToolId === 'luckin.order.preview' && clicked.id === 'luckin.order.preview') {
    targetId = clicked.id;
  } else {
    targetId = gmailReplySendTarget(sourceToolId, clicked);
    if (targetId.length === 0) {
      targetId = adaptedTarget(sourceToolId, clicked.id);
    }
  }
  if (!registeredProductAction(targetId) &&
    targetId !== 'mail.thread.read' && targetId !== 'gmail.thread.read') {
    return null;
  }
  return {
    pageActionId: clicked.id,
    action: {
      id: targetId,
      label: clicked.label,
      prompt: clicked.prompt,
      variant: clicked.variant,
      kind: clicked.kind,
      args: clicked.args
    }
  };
}

export function isRegisteredPageActionCandidate(actionId: string): boolean {
  return PAGE_ACTION_CANDIDATE_IDS.indexOf(actionId) >= 0;
}

export async function dispatchRegisteredPageActionCandidate(
  action: A2uiAction,
  registered: RegisteredPageCandidateRunner,
  legacy: LegacyPageActionRunner
): Promise<RegisteredPageDispatchResult> {
  if (isRegisteredPageActionCandidate(action.id) || isGmailReplySendCandidate(action)) {
    let ok = false;
    try {
      ok = await registered(action);
    } catch (_error) {
      ok = false;
    }
    return { candidate: true, ok };
  }
  await legacy(action);
  return { candidate: false, ok: true };
}

export function resolveVirtualRegisteredPageAction(
  actionId: string,
  inputText: string,
  now: Date = new Date()
): A2uiAction | null {
  if (actionId === 'gmail.draft.create') {
    const args = gmailDraftVirtualArgs(inputText);
    return args === null ? null :
      virtualAction(actionId, inputText.trim(), args as Object);
  }
  if (actionId === 'worldcup.open' && inputText.trim().length > 0) {
    const args: WorldCupVirtualArgs = { route: 'pages/A2uiHome/AnythingDemo' };
    return virtualAction(actionId, inputText.trim(), args as Object);
  }
  if (actionId === 'maps.route.open') {
    const args: MapsRouteArgs | null = mapsRouteInputFromPrompt(inputText);
    if (args === null) {
      return null;
    }
    return virtualAction(actionId, inputText.trim(), args as Object);
  }
  if (actionId === 'social.post.preview') {
    const args = socialPostPreviewVirtualArgs(inputText);
    return args === null ? null :
      virtualAction(actionId, inputText.trim(), args as Object);
  }
  if (actionId === 'luckin.order.preview' || actionId === 'payment.send' ||
    actionId === 'payment.account.setup') {
    const originalQuery = inputText.trim();
    if (originalQuery.length === 0) {
      return null;
    }
    const args: OriginalQueryVirtualArgs = { originalQuery };
    return virtualAction(actionId, originalQuery, args as Object);
  }
  if (actionId === 'whatsapp.message.send') {
    const args = whatsAppVirtualArgs(inputText.trim());
    return args === null ? null :
      virtualAction(actionId, inputText.trim(), args as Object);
  }
  if (actionId === 'calendar.event.create') {
    const normalized = normalizedCalendarArgsForPrompt(actionId, inputText, {}, now, true);
    if (calendarEventRequiredFields(actionId, normalized).length > 0) {
      return null;
    }
    const args: CalendarEventArgs = {
      title: normalized.title,
      start: normalized.start,
      end: normalized.end,
      timezone: normalized.timezone,
      calendarId: normalized.calendarId
    };
    const action = virtualAction(actionId, inputText.trim(), args as Object);
    action.label = '确认创建日程';
    return action;
  }
  return null;
}
