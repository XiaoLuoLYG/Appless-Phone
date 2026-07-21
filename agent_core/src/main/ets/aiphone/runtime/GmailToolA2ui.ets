import { DynamicGenericToolResult } from './DynamicToolTypes';
import { MailProviderStatus, MailThreadResult } from './MailToolTypes';
import {
  A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_TOOL_CONNECT_CARD,
  A2UI_VERSION,
  A2uiAction,
  A2uiComponent,
  A2uiDynamicToolConnectData,
  A2uiEnvelope,
  A2uiGenericToolResultData,
  A2uiLabelValueData,
  A2uiSummaryData
} from './A2uiTypes';

export const GMAIL_WEB_URL: string = 'https://mail.google.com/mail/u/0/#inbox';
export const GMAIL_DRAFTS_URL: string = 'https://mail.google.com/mail/u/0/#drafts';
export const GMAIL_MCP_SERVER_URL: string = 'https://gmailmcp.googleapis.com/mcp/v1';
export const GMAIL_MCP_AUTH_SETUP_URL: string = 'https://developers.google.com/workspace/gmail/api/guides/configure-mcp-server';
export const GOOGLE_OAUTH_SETUP_URL: string = 'https://console.cloud.google.com/apis/credentials';
export const GOOGLE_CALENDAR_WEB_URL: string = 'https://calendar.google.com/calendar/u/0/r';
export const GOOGLE_CALENDAR_API_URL: string = 'https://www.googleapis.com/calendar/v3';
const GMAIL_MANIFEST_ID: string = 'google.gmail';
const GMAIL_DISPLAY_NAME: string = 'Gmail';
const CALENDAR_MANIFEST_ID: string = 'google.calendar';
const CALENDAR_DISPLAY_NAME: string = 'Google Calendar';
const GENERIC_RESULTS_PATH: string = '/genericToolResults';
const SUMMARY_PATH: string = '/summary';
const CONNECT_PATH: string = '/dynamicToolConnect';

interface GmailReplyDraftActionArgs {
  threadId: string;
  to: string[];
  subject: string;
  replyMode: string;
  contextSummary: string;
}

type GmailJsonValue = Object | string | number | boolean | null | undefined;

function action(id: string, label: string, prompt: string, variant: string, kind: string, args: Object | null = null): A2uiAction {
  const next: A2uiAction = {
    id: id,
    label: label,
    prompt: prompt,
    variant: variant,
    kind: kind
  };
  if (args !== null) {
    next.args = args;
  }
  return next;
}

function jsonLine(envelope: A2uiEnvelope): string {
  return JSON.stringify(envelope) + '\n';
}

function createSurfaceLine(surfaceId: string, title: string, status: string, intent: string = 'gmail'): string {
  return jsonLine({
    version: A2UI_VERSION,
    createSurface: {
      surfaceId: surfaceId,
      root: 'root',
      title: title,
      intent: intent,
      status: status
    }
  });
}

function componentsLine(surfaceId: string, components: A2uiComponent[]): string {
  return jsonLine({
    version: A2UI_VERSION,
    updateComponents: {
      surfaceId: surfaceId,
      components: components
    }
  });
}

function dataLine(
  surfaceId: string,
  path: string,
  value: A2uiDynamicToolConnectData | A2uiGenericToolResultData[] | A2uiSummaryData
): string {
  return jsonLine({
    version: A2UI_VERSION,
    updateDataModel: {
      surfaceId: surfaceId,
      path: path,
      value: value
    }
  });
}

function rootComponent(title: string, status: string): A2uiComponent {
  return {
    id: 'root',
    component: A2UI_COMPONENT_SURFACE_ROOT,
    child: 'gmail_results',
    title: title,
    status: status
  };
}

function genericResultsComponent(title: string, status: string, actions?: A2uiAction[]): A2uiComponent {
  const component: A2uiComponent = {
    id: 'gmail_results',
    component: A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
    title: title,
    dataPath: GENERIC_RESULTS_PATH,
    status: status
  };
  if (actions !== undefined && actions.length > 0) {
    component.actions = actions;
  }
  return component;
}

function summary(text: string, toolName: string, count: number): A2uiSummaryData {
  return {
    text: text,
    toolName: toolName,
    dataLabel: GENERIC_RESULTS_PATH,
    count: count
  };
}

function resultFromDynamic(result: DynamicGenericToolResult): A2uiGenericToolResultData {
  const source = result.sourceTag.toLowerCase();
  const title = result.title.toLowerCase();
  const isComposioGmailFailure = result.status !== 'success' &&
    (source.indexOf('composio') >= 0 || title.indexOf('composio') >= 0) &&
    (source.indexOf('gmail') >= 0 || title.indexOf('gmail') >= 0 || result.toolName.toLowerCase().indexOf('gmail') >= 0);
  return {
    sourceTag: isComposioGmailFailure ? 'Gmail' : result.sourceTag,
    toolName: result.toolName,
    title: isComposioGmailFailure ? 'Gmail 调用失败' : result.title,
    status: result.status,
    summary: result.summary,
    rows: result.rows,
    rawPreview: ''
  };
}

function genericResultsA2ui(
  surfaceId: string,
  title: string,
  surfaceStatus: string,
  componentStatus: string,
  results: A2uiGenericToolResultData[],
  summaryData: A2uiSummaryData
): string {
  return createSurfaceLine(surfaceId, title, surfaceStatus) +
    componentsLine(surfaceId, [
      rootComponent(title, componentStatus),
      genericResultsComponent(title, componentStatus)
    ]) +
    dataLine(surfaceId, GENERIC_RESULTS_PATH, results) +
    dataLine(surfaceId, SUMMARY_PATH, summaryData);
}

function genericResultsFromDynamic(results: DynamicGenericToolResult[]): A2uiGenericToolResultData[] {
  const mapped: A2uiGenericToolResultData[] = [];
  results.forEach((result: DynamicGenericToolResult) => {
    const gmailRows = gmailComposioThreadResults(result);
    if (gmailRows.length > 0) {
      gmailRows.forEach((item: A2uiGenericToolResultData) => mapped.push(item));
    } else {
      mapped.push(resultFromDynamic(result));
    }
  });
  return mapped;
}

function textValue(value: GmailJsonValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value.trim();
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function field(record: Record<string, GmailJsonValue>, names: string[]): string {
  for (let index = 0; index < names.length; index++) {
    const value = textValue(record[names[index]]);
    if (value.length > 0 && value.charAt(0) !== '{') {
      return value;
    }
  }
  return '';
}

function nestedField(record: Record<string, GmailJsonValue>, names: string[]): string {
  const direct = field(record, names);
  if (direct.length > 0) {
    return direct;
  }
  for (let index = 0; index < names.length; index++) {
    const value = record[names[index]];
    if (value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value)) {
      const nested = value as Record<string, GmailJsonValue>;
      const text = field(nested, ['email', 'address', 'name', 'displayName', 'display_name', 'value', 'id']);
      if (text.length > 0) {
        return text;
      }
    }
  }
  return '';
}

function appendRow(rows: A2uiLabelValueData[], label: string, value: string): void {
  const clean = value.trim();
  if (label.length > 0 && clean.length > 0) {
    rows.push({ label: label, value: clean.substring(0, 360) });
  }
}

function collectObjects(value: GmailJsonValue, records: Object[], depth: number): void {
  if (records.length >= 12 || depth > 6 || value === undefined || value === null) {
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item: GmailJsonValue) => {
      if (records.length < 12 && item !== undefined && item !== null && typeof item === 'object') {
        records.push(item as Object);
      }
    });
    return;
  }
  if (typeof value !== 'object') {
    return;
  }
  const record = value as Record<string, GmailJsonValue>;
  const preferred = ['threads', 'messages', 'emails', 'mails', 'items', 'results'];
  for (let index = 0; index < preferred.length; index++) {
    const child = record[preferred[index]];
    if (Array.isArray(child)) {
      collectObjects(child, records, depth + 1);
      if (records.length > 0) {
        return;
      }
    }
  }
  const nested = ['data', 'result', 'response', 'response_data'];
  for (let index = 0; index < nested.length; index++) {
    collectObjects(record[nested[index]], records, depth + 1);
    if (records.length > 0) {
      return;
    }
  }
}

function rawRecords(rawPreview: string): Object[] {
  const records: Object[] = [];
  if (rawPreview.trim().length === 0) {
    return records;
  }
  try {
    collectObjects(JSON.parse(rawPreview) as GmailJsonValue, records, 0);
  } catch (_error) {
  }
  return records;
}

function isComposioGmailReadResult(result: DynamicGenericToolResult): boolean {
  if (result.status !== 'success') {
    return false;
  }
  const source = result.sourceTag.toLowerCase();
  const title = result.title.toLowerCase();
  const tool = result.toolName.toLowerCase();
  if (source.indexOf('composio') < 0 && title.indexOf('composio') < 0) {
    return false;
  }
  if (tool.indexOf('draft') >= 0 || tool.indexOf('send') >= 0 || tool.indexOf('delete') >= 0 ||
    tool.indexOf('update') >= 0 || tool.indexOf('apply') >= 0) {
    return false;
  }
  return source.indexOf('gmail') >= 0 || title.indexOf('gmail') >= 0 || tool.indexOf('gmail') >= 0;
}

export interface GmailThreadSummary extends MailThreadResult {
  requestKey: string;
}

export interface GmailSearchStructuredData {
  threads: GmailThreadSummary[];
  statuses: MailProviderStatus[];
  extras: DynamicGenericToolResult[];
}

function structuredRowValue(result: A2uiGenericToolResultData, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value.trim();
    }
  }
  return '';
}

function gmailSummaryFromCard(card: A2uiGenericToolResultData): GmailThreadSummary | null {
  const threadId = structuredRowValue(card, 'Thread ID');
  const messageId = structuredRowValue(card, 'Message ID');
  if (threadId.length === 0) {
    return null;
  }
  const from = structuredRowValue(card, 'From');
  const to = structuredRowValue(card, 'To');
  const participants: string[] = [];
  if (from.length > 0) {
    participants.push(from);
  }
  if (to.length > 0) {
    participants.push(to);
  }
  return {
    provider: 'gmail',
    accountLabel: 'Gmail',
    threadId: threadId,
    messageId: messageId,
    subject: card.title,
    from: from,
    to: to.length > 0 ? [to] : [],
    participants: participants,
    snippet: card.summary,
    receivedAt: structuredRowValue(card, 'Date'),
    unread: false,
    important: false,
    sourceUrl: GMAIL_WEB_URL,
    rawProviderRef: JSON.stringify({ threadId: threadId, messageId: messageId }),
    requestKey: 'gmail:' + threadId
  };
}

export function gmailSearchStructuredDataFromResults(results: DynamicGenericToolResult[]): GmailSearchStructuredData {
  const threads: GmailThreadSummary[] = [];
  const statuses: MailProviderStatus[] = [];
  const extras: DynamicGenericToolResult[] = [];
  results.forEach((result: DynamicGenericToolResult) => {
    let readResult = result;
    if (result.sourceTag.toLowerCase().indexOf('gmail') >= 0 &&
      result.sourceTag.toLowerCase().indexOf('composio') < 0) {
      readResult = {
        sourceTag: 'Composio Gmail', toolName: result.toolName, title: result.title,
        status: result.status, summary: result.summary, rows: result.rows,
        rawPreview: result.rawPreview
      };
    }
    const cards = gmailComposioThreadResults(readResult);
    let addedThread = false;
    cards.forEach((card: A2uiGenericToolResultData) => {
      const thread = gmailSummaryFromCard(card);
      if (thread !== null) {
        threads.push(thread);
        addedThread = true;
      }
    });
    if (!addedThread) {
      if (result.status === 'success' || result.status === 'empty') {
        extras.push(result);
      } else {
        statuses.push({
          provider: 'gmail',
          status: result.status,
          title: result.title,
          message: result.summary
        });
        extras.push(result);
      }
    }
  });
  return { threads: threads, statuses: statuses, extras: extras };
}

function gmailCardFromSummary(thread: GmailThreadSummary): A2uiGenericToolResultData {
  const rows: A2uiLabelValueData[] = [];
  appendRow(rows, 'Thread ID', thread.threadId);
  appendRow(rows, 'Message ID', thread.messageId);
  appendRow(rows, 'From', thread.from);
  appendRow(rows, 'To', thread.to.join(', '));
  appendRow(rows, 'Date', thread.receivedAt);
  appendRow(rows, 'Source', 'Composio Gmail');
  return {
    sourceTag: 'Gmail API',
    toolName: 'users.threads.get',
    title: thread.subject,
    status: 'success',
    summary: thread.snippet,
    rows: rows,
    rawPreview: JSON.stringify({ source: 'Composio Gmail', threadId: thread.threadId, messageId: thread.messageId })
  };
}

export function gmailSearchStructuredDataA2ui(
  surfaceId: string,
  toolId: string,
  data: GmailSearchStructuredData
): string {
  const mapped: A2uiGenericToolResultData[] = [];
  data.threads.forEach((thread: GmailThreadSummary) => mapped.push(gmailCardFromSummary(thread)));
  genericResultsFromDynamic(data.extras).forEach((result: A2uiGenericToolResultData) => mapped.push(result));
  const count = mapped.length;
  return genericResultsA2ui(
    surfaceId,
    GMAIL_DISPLAY_NAME,
    'ready',
    'ready',
    mapped,
    summary(count.toString() + (count === 1 ? ' Gmail result returned for review.' : ' Gmail results returned for review.'), toolId, count)
  );
}

function gmailCardFromRecord(record: Object, fallbackTitle: string, fallbackSummary: string, index: number): A2uiGenericToolResultData {
  const row = record as Record<string, GmailJsonValue>;
  const threadId = field(row, ['threadId', 'thread_id', 'threadID', 'id']);
  const messageId = field(row, ['messageId', 'message_id', 'messageID', 'id']);
  const from = nestedField(row, ['from', 'sender', 'author']);
  const to = nestedField(row, ['to', 'recipient', 'recipients']);
  const date = field(row, ['date', 'receivedDateTime', 'received_at', 'createdAt', 'created_at', 'updatedAt', 'updated_at', 'internalDate']);
  const subject = field(row, ['subject', 'title', 'name']);
  const snippet = field(row, ['snippet', 'preview', 'summary', 'description', 'text', 'message', 'messageText', 'message_text']);
  const title = subject.length > 0 ? subject : (snippet.length > 0 ? snippet.substring(0, 80) :
    (fallbackTitle.length > 0 ? fallbackTitle : 'Gmail message ' + (index + 1).toString()));
  const rows: A2uiLabelValueData[] = [];
  appendRow(rows, 'Thread ID', threadId);
  appendRow(rows, 'Message ID', messageId);
  appendRow(rows, 'From', from);
  appendRow(rows, 'To', to);
  appendRow(rows, 'Date', date);
  appendRow(rows, 'Source', 'Composio Gmail');
  return {
    sourceTag: 'Gmail API',
    toolName: 'users.threads.get',
    title: title,
    status: 'success',
    summary: snippet.length > 0 ? snippet : fallbackSummary,
    rows: rows,
    rawPreview: JSON.stringify({ source: 'Composio Gmail', threadId: threadId, messageId: messageId })
  };
}

function firstRowPart(parts: string[], match: (value: string) => boolean): string {
  for (let index = 0; index < parts.length; index++) {
    const value = parts[index].trim();
    if (match(value)) {
      return value;
    }
  }
  return '';
}

function gmailCardFromRow(row: A2uiLabelValueData, fallbackSummary: string, index: number): A2uiGenericToolResultData | null {
  const label = row.label.trim();
  const value = row.value.trim();
  const lowerLabel = label.toLowerCase();
  if (label.length === 0 || value.length === 0 ||
    label === '执行工具' || label === '查询' || label === '结果数量' ||
      lowerLabel === 'query' || lowerLabel === 'provider' || lowerLabel === 'tool id') {
    return null;
  }
  const parts = value.split('|');
  const idPart = firstRowPart(parts, (part: string): boolean => part.charAt(0) === '#');
  const from = firstRowPart(parts, (part: string): boolean => part.indexOf('@') >= 0 || part.indexOf('<') >= 0);
  const date = firstRowPart(parts, (part: string): boolean => Date.parse(part) > 0);
  const summaryPart = firstRowPart(parts, (part: string): boolean =>
    part.charAt(0) !== '#' && part.indexOf('http://') !== 0 && part.indexOf('https://') !== 0 &&
      part !== from && part !== date);
  const threadId = idPart.charAt(0) === '#' ? idPart.substring(1) : '';
  const rows: A2uiLabelValueData[] = [];
  appendRow(rows, 'Thread ID', threadId);
  appendRow(rows, 'Message ID', threadId);
  appendRow(rows, 'From', from);
  appendRow(rows, 'Date', date);
  appendRow(rows, 'Source', 'Composio Gmail');
  return {
    sourceTag: 'Gmail API',
    toolName: 'users.threads.get',
    title: label.indexOf('结果 ') === 0 ? 'Gmail message ' + (index + 1).toString() : label,
    status: 'success',
    summary: summaryPart.length > 0 ? summaryPart : (value.length > 0 ? value : fallbackSummary),
    rows: rows,
    rawPreview: JSON.stringify({ source: 'Composio Gmail', threadId: threadId })
  };
}

export function gmailComposioThreadResults(result: DynamicGenericToolResult): A2uiGenericToolResultData[] {
  const mapped: A2uiGenericToolResultData[] = [];
  if (!isComposioGmailReadResult(result)) {
    return mapped;
  }
  const records = rawRecords(result.rawPreview);
  records.forEach((record: Object, index: number) => {
    mapped.push(gmailCardFromRecord(record, result.title, result.summary, index));
  });
  if (mapped.length > 0) {
    return mapped;
  }
  result.rows.forEach((row: A2uiLabelValueData, index: number) => {
    const card = gmailCardFromRow(row, result.summary, index);
    if (card !== null) {
      mapped.push(card);
    }
  });
  return mapped;
}

function rowValue(result: A2uiGenericToolResultData, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value.trim();
    }
  }
  return '';
}

function emailFromHeader(value: string): string {
  const trimmed = value.trim();
  const left = trimmed.indexOf('<');
  const right = trimmed.indexOf('>');
  if (left >= 0 && right > left) {
    return trimmed.substring(left + 1, right).trim();
  }
  return trimmed;
}

export function gmailReplyDraftAction(result: A2uiGenericToolResultData): A2uiAction | null {
  if (result.status !== 'success' || result.sourceTag !== 'Gmail API' || result.toolName.indexOf('users.threads') !== 0) {
    return null;
  }
  const threadId = rowValue(result, 'Thread ID');
  const from = rowValue(result, 'From');
  if (threadId.length === 0 || from.length === 0) {
    return null;
  }
  const email = emailFromHeader(from);
  if (email.length === 0) {
    return null;
  }
  const subject = result.title.indexOf('Re:') === 0 ? result.title : 'Re: ' + result.title;
  const args: GmailReplyDraftActionArgs = {
    threadId: threadId,
    to: [email],
    subject: subject,
    replyMode: 'reply',
    contextSummary: result.summary
  };
  const prompt = 'Action ID: gmail.ai.reply.draft。请只基于 args.contextSummary 中的真实邮件标题与正文生成一封简短、礼貌、可审核的回复草稿。只选择 gmail.draft.create，不要发送，不要编造事实。' +
    '/toolRequest.args 必须保留 threadId、to、subject、replyMode，并由你撰写 args.body；args.body 必须是单行 JSON 字符串，换行写成 \\n，不要在 JSON 字符串里输出真实换行。Structured action args JSON: ' + JSON.stringify(args);
  return action('gmail.ai.reply.draft', 'AI 回复草稿', prompt, 'primary', 'prompt', args);
}

export function gmailOpenDraftAction(result: A2uiGenericToolResultData): A2uiAction | null {
  const lowerTool = result.toolName.toLowerCase();
  if (result.toolName !== 'gmail.draft.create' &&
    result.toolName !== 'create_draft' &&
    result.toolName.indexOf('users.drafts') !== 0 &&
      (lowerTool.indexOf('gmail') < 0 || lowerTool.indexOf('draft') < 0)) {
    return null;
  }
  return action('gmail.open.web', '跳转到Gmail', GMAIL_DRAFTS_URL, 'secondary', 'client');
}

export function gmailAuthRequiredA2ui(
  surfaceId: string,
  toolId: string,
  message: string,
  authorizeUrl: string = GMAIL_MCP_AUTH_SETUP_URL
): string {
  const connectData: A2uiDynamicToolConnectData = {
    toolId: toolId,
    prompt: '',
    manifestId: GMAIL_MANIFEST_ID,
    displayName: GMAIL_DISPLAY_NAME,
    sourceUrl: GMAIL_MCP_SERVER_URL,
    status: 'needs_auth',
    message: message,
    credentialName: 'Google Workspace MCP OAuth',
    credentialRef: '',
    registrationUrl: authorizeUrl.length > 0 ? authorizeUrl : GMAIL_MCP_AUTH_SETUP_URL,
    actions: [
      action('gmail.authorize', '授权 Gmail', authorizeUrl.length > 0 ? authorizeUrl : GMAIL_MCP_AUTH_SETUP_URL, 'primary', 'client'),
      action('gmail.open.web', '打开 Gmail Web', GMAIL_WEB_URL, 'secondary', 'client'),
      action('gmail_retry_auth', '重试认证', '重新检测 Gmail 登录状态', 'secondary', 'prompt')
    ]
  };
  const root: A2uiComponent = {
    id: 'root',
    component: A2UI_COMPONENT_SURFACE_ROOT,
    child: 'gmail_connect',
    title: GMAIL_DISPLAY_NAME,
    status: 'needs_auth'
  };
  const connect: A2uiComponent = {
    id: 'gmail_connect',
    component: A2UI_COMPONENT_TOOL_CONNECT_CARD,
    title: GMAIL_DISPLAY_NAME,
    dataPath: CONNECT_PATH,
    status: 'needs_auth'
  };

  return createSurfaceLine(surfaceId, GMAIL_DISPLAY_NAME, 'needs_input') +
    componentsLine(surfaceId, [root, connect]) +
    dataLine(surfaceId, CONNECT_PATH, connectData);
}

export function calendarAuthRequiredA2ui(
  surfaceId: string,
  toolId: string,
  message: string,
  authorizeUrl: string = GOOGLE_OAUTH_SETUP_URL
): string {
  const connectData: A2uiDynamicToolConnectData = {
    toolId: toolId,
    prompt: '',
    manifestId: CALENDAR_MANIFEST_ID,
    displayName: CALENDAR_DISPLAY_NAME,
    sourceUrl: GOOGLE_CALENDAR_API_URL,
    status: 'needs_auth',
    message: message,
    credentialName: 'Google OAuth',
    credentialRef: '',
    registrationUrl: authorizeUrl.length > 0 ? authorizeUrl : GOOGLE_OAUTH_SETUP_URL,
    actions: [
      action('calendar.authorize', '授权 Calendar', authorizeUrl.length > 0 ? authorizeUrl : GOOGLE_OAUTH_SETUP_URL, 'primary', 'client'),
      action('calendar.open.web', '打开 Calendar Web', GOOGLE_CALENDAR_WEB_URL, 'secondary', 'client'),
      action('calendar_retry_auth', '重试认证', '重新检测 Google Calendar 授权状态', 'secondary', 'prompt')
    ]
  };
  const root: A2uiComponent = {
    id: 'root',
    component: A2UI_COMPONENT_SURFACE_ROOT,
    child: 'calendar_connect',
    title: CALENDAR_DISPLAY_NAME,
    status: 'needs_auth'
  };
  const connect: A2uiComponent = {
    id: 'calendar_connect',
    component: A2UI_COMPONENT_TOOL_CONNECT_CARD,
    title: CALENDAR_DISPLAY_NAME,
    dataPath: CONNECT_PATH,
    status: 'needs_auth'
  };

  return createSurfaceLine(surfaceId, CALENDAR_DISPLAY_NAME, 'needs_input', 'calendar') +
    componentsLine(surfaceId, [root, connect]) +
    dataLine(surfaceId, CONNECT_PATH, connectData);
}

export function gmailThreadResultsA2ui(surfaceId: string, toolId: string, results: DynamicGenericToolResult[]): string {
  const mapped = genericResultsFromDynamic(results);
  const count = mapped.length;
  const resultLabel = count === 1 ? 'Gmail result' : 'Gmail results';
  const text = count.toString() + ' ' + resultLabel + ' returned for review.';
  return genericResultsA2ui(
    surfaceId,
    GMAIL_DISPLAY_NAME,
    'ready',
    'ready',
    mapped,
    summary(text, toolId, count)
  );
}

export function gmailDraftPreviewA2ui(surfaceId: string, result: DynamicGenericToolResult): string {
  const mapped = genericResultsFromDynamic([result]);
  return genericResultsA2ui(
    surfaceId,
    'Gmail Draft Preview',
    'ready',
    'draft',
    mapped,
    summary('Draft prepared for review. It has not been sent.', result.toolName, 1)
  );
}

export function gmailBlockedSendA2ui(surfaceId: string, toolId: string): string {
  const blockedSummary = 'UnsafeActionBlocked：不会自动发送 Gmail。请先查看草稿内容，确认收件人和正文后，创建或打开 Gmail 草稿由用户手动发送。';
  const result: A2uiGenericToolResultData = {
    sourceTag: 'Safety policy',
    toolName: toolId,
    title: 'UnsafeActionBlocked',
    status: 'blocked',
    summary: blockedSummary,
    rows: [
      { label: 'Blocked action', value: toolId },
      { label: 'Next step', value: '创建或打开 Gmail 草稿，用户确认后手动发送。' }
    ],
    rawPreview: JSON.stringify({
      blocked: true,
      reason: 'unsafe_action_blocked',
      toolId: toolId
    })
  };

  return genericResultsA2ui(
    surfaceId,
    'UnsafeActionBlocked',
    'blocked',
    'blocked',
    [result],
    summary(blockedSummary, toolId, 1)
  );
}

export function gmailOpenWebA2ui(surfaceId: string, url: string): string {
  const openSummary = '已打开 Gmail 网页版，可使用当前浏览器会话继续处理邮件。';
  const result: A2uiGenericToolResultData = {
    sourceTag: 'System intent',
    toolName: 'gmail.open.web',
    title: 'Gmail Web',
    status: 'needs_user',
    summary: openSummary,
    rows: [
      { label: 'URL', value: url }
    ],
    rawPreview: JSON.stringify({
      url: url
    })
  };

  return createSurfaceLine(surfaceId, 'Gmail Web', 'needs_input') +
    componentsLine(surfaceId, [
      rootComponent('Gmail Web', 'needs_user'),
      genericResultsComponent('Gmail Web', 'needs_user', [
        action('gmail.open.web', '打开 Gmail Web', url, 'primary', 'client')
      ])
    ]) +
    dataLine(surfaceId, GENERIC_RESULTS_PATH, [result]) +
    dataLine(surfaceId, SUMMARY_PATH, summary(openSummary, 'gmail.open.web', 1));
}
