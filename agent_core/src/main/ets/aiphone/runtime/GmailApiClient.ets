import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { A2uiLabelValueData } from './A2uiTypes';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import {
  GmailCreateDraftArgs,
  GmailGetThreadArgs,
  GmailSearchThreadsArgs,
  gmailMcpArgsForPrompt
} from './GmailOAuthClient';
import { aiLogError, aiLogInfo } from './AiphoneLogger';
import { utf8Bytes } from './Utf8Bytes';
import { MailDetail, MailDetailRequest } from './MailToolTypes';

const GMAIL_API_BASE_URL: string = 'https://gmail.googleapis.com/gmail/v1/users/me';

interface GoogleApiError {
  code?: number;
  message?: string;
  status?: string;
}

interface GoogleApiErrorPayload {
  error?: GoogleApiError;
}

interface GmailThreadListItem {
  id?: string;
  snippet?: string;
}

interface GmailThreadsListResponse {
  threads?: GmailThreadListItem[];
  nextPageToken?: string;
  resultSizeEstimate?: number;
}

interface GmailHeader {
  name?: string;
  value?: string;
}

interface GmailMessagePayload {
  headers?: GmailHeader[];
  mimeType?: string;
  body?: GmailMessageBody;
  parts?: GmailMessagePayload[];
}

interface GmailMessageBody {
  data?: string;
  size?: number;
}

interface GmailMessage {
  id?: string;
  threadId?: string;
  labelIds?: string[];
  snippet?: string;
  internalDate?: string;
  payload?: GmailMessagePayload;
}

interface GmailThread {
  id?: string;
  historyId?: string;
  messages?: GmailMessage[];
}

interface GmailDraftResponse {
  id?: string;
  message?: GmailMessage;
}

interface GmailDraftCreateMessage {
  raw: string;
  threadId?: string;
}

interface GmailDraftCreateRequest {
  message: GmailDraftCreateMessage;
}

type GmailJsonValue = Object | string | number | boolean | null | undefined;

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

function decodeGmailText(value: string): string {
  return value
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/g, "'");
}

function decodeBase64UrlText(value: string): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let source = value.replace(/-/g, '+').replace(/_/g, '/').replace(/\s/g, '');
  while (source.length % 4 !== 0) {
    source += '=';
  }
  const bytes = new Uint8Array(Math.ceil(source.length / 4) * 3);
  let byteIndex = 0;
  for (let index = 0; index < source.length; index += 4) {
    const a = alphabet.indexOf(source.charAt(index));
    const b = alphabet.indexOf(source.charAt(index + 1));
    const c = source.charAt(index + 2) === '=' ? -1 : alphabet.indexOf(source.charAt(index + 2));
    const d = source.charAt(index + 3) === '=' ? -1 : alphabet.indexOf(source.charAt(index + 3));
    if (a < 0 || b < 0) {
      continue;
    }
    const triple = (a << 18) | (b << 12) | ((c < 0 ? 0 : c) << 6) | (d < 0 ? 0 : d);
    bytes[byteIndex] = (triple >> 16) & 0xff;
    byteIndex++;
    if (c >= 0) {
      bytes[byteIndex] = (triple >> 8) & 0xff;
      byteIndex++;
    }
    if (d >= 0) {
      bytes[byteIndex] = triple & 0xff;
      byteIndex++;
    }
  }
  return util.TextDecoder.create('utf-8').decodeToString(bytes.slice(0, byteIndex));
}

function gmailHeader(message: GmailMessage, name: string): string {
  return decodeGmailText(firstHeader(message, name));
}

function gmailAddresses(value: string): string[] {
  return value.split(',').map((item: string) => item.trim()).filter((item: string) => item.length > 0);
}

interface GmailBodyParts {
  plain: string;
  html: string;
}

function collectGmailBody(payload: GmailMessagePayload | undefined, result: GmailBodyParts): void {
  if (payload === undefined) {
    return;
  }
  const mimeType = textOf(payload.mimeType).toLowerCase();
  const data = payload.body === undefined ? '' : textOf(payload.body.data);
  if (data.length > 0) {
    const decoded = decodeBase64UrlText(data).trim();
    if (mimeType === 'text/plain' && result.plain.length === 0) {
      result.plain = decoded;
    } else if (mimeType === 'text/html' && result.html.length === 0) {
      result.html = decoded;
    }
  }
  if (Array.isArray(payload.parts)) {
    for (let index = 0; index < payload.parts.length; index++) {
      collectGmailBody(payload.parts[index], result);
    }
  }
}

function gmailTextFromHtml(value: string): string {
  return value
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, ' ')
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, ' ')
    .replace(/<br\s*\/?\s*>/gi, '\n')
    .replace(/<\/p\s*>/gi, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n\s+/g, '\n')
    .trim();
}

function responseText(result: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(result));
  }
  return textOf(result);
}

function encodeParam(value: string): string {
  return encodeURIComponent(value);
}

function urlWithParams(baseUrl: string, params: string[][]): string {
  const pairs: string[] = [];
  params.forEach((pair: string[]) => {
    if (pair.length < 2 || pair[1].length === 0) {
      return;
    }
    pairs.push(encodeParam(pair[0]) + '=' + encodeParam(pair[1]));
  });
  return pairs.length === 0 ? baseUrl : baseUrl + '?' + pairs.join('&');
}

function bearerHeaders(accessToken: string): Record<string, string> {
  return {
    'Authorization': 'Bearer ' + accessToken,
    'Accept': 'application/json'
  };
}

function requestMethodName(method: http.RequestMethod): string {
  if (method === http.RequestMethod.POST) {
    return 'POST';
  }
  if (method === http.RequestMethod.GET) {
    return 'GET';
  }
  return method.toString();
}

function gmailApiPath(url: string): string {
  let path = url;
  if (path.startsWith(GMAIL_API_BASE_URL)) {
    path = path.substring(GMAIL_API_BASE_URL.length);
  }
  const queryIndex = path.indexOf('?');
  return queryIndex >= 0 ? path.substring(0, queryIndex) : path;
}

function describeRequestError(error: Error | Object | string | number | boolean | null | undefined): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string') {
    return error;
  }
  if (typeof error === 'number' || typeof error === 'boolean') {
    return error.toString();
  }
  const json = JSON.stringify(error);
  return json.length > 0 && json !== '{}' ? json : String(error);
}

async function requestJson(
  method: http.RequestMethod,
  url: string,
  accessToken: string,
  body: Object | null,
  connectTimeoutMs: number = 10000,
  readTimeoutMs: number = 20000
): Promise<Object> {
  const request = http.createHttp();
  const methodName = requestMethodName(method);
  const path = gmailApiPath(url);
  try {
    const headers = bearerHeaders(accessToken);
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: connectTimeoutMs,
      readTimeout: readTimeoutMs
    };
    if (body !== null) {
      headers['Content-Type'] = 'application/json';
      options.extraData = JSON.stringify(body);
    }
    aiLogInfo('[AIPhone][GmailApiHttpStart] method=' + methodName +
      ' path=' + path +
      ' bodyChars=' + (body === null ? '0' : JSON.stringify(body).length.toString()));
    const response = await request.request(url, options);
    const text = responseText(response.result);
    aiLogInfo('[AIPhone][GmailApiHttpEnd] method=' + methodName +
      ' path=' + path +
      ' code=' + response.responseCode.toString() +
      ' chars=' + text.length.toString());
    const payload = text.length > 0 ? JSON.parse(text) as Object : new Object();
    if (response.responseCode < 200 || response.responseCode >= 300) {
      const errorPayload = payload as GoogleApiErrorPayload;
      const message = errorPayload.error === undefined ? '' : textOf(errorPayload.error.message);
      const status = errorPayload.error === undefined ? '' : textOf(errorPayload.error.status);
      throw new Error(message.length > 0 ? message : (status.length > 0 ? status : 'HTTP ' + response.responseCode.toString()));
    }
    return payload;
  } catch (error) {
    const message = describeRequestError(error);
    aiLogError('[AIPhone][GmailApiHttpError] method=' + methodName +
      ' path=' + path +
      ' error=' + message.substring(0, 220));
    throw new Error(message);
  } finally {
    request.destroy();
  }
}

function isTransientRequestError(error: Error | Object | string | number | boolean | null | undefined): boolean {
  const message = describeRequestError(error);
  return message.indexOf('Operation timeout') >= 0 || message.indexOf('2300028') >= 0 ||
    message.indexOf('Internal error') >= 0 || message.indexOf('2300999') >= 0;
}

async function requestJsonWithTimeoutRetry(
  method: http.RequestMethod,
  url: string,
  accessToken: string,
  body: Object | null
): Promise<Object> {
  const connectTimeouts: number[] = [10000, 20000, 20000];
  const readTimeouts: number[] = [20000, 30000, 45000];
  let lastError = '';
  for (let attempt = 0; attempt < connectTimeouts.length; attempt++) {
    try {
      return await requestJson(method, url, accessToken, body, connectTimeouts[attempt], readTimeouts[attempt]);
    } catch (error) {
      lastError = describeRequestError(error);
      if (!isTransientRequestError(error) || attempt >= connectTimeouts.length - 1) {
        throw new Error(lastError);
      }
      aiLogInfo('[AIPhone][GmailApiHttpRetry] method=' + requestMethodName(method) +
        ' path=' + gmailApiPath(url) +
        ' attempt=' + (attempt + 2).toString() +
        ' reason=' + lastError.substring(0, 160));
    }
  }
  throw new Error(lastError);
}

function bytesToBase64Url(bytes: Uint8Array): string {
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
  return result.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

function firstHeader(message: GmailMessage, headerName: string): string {
  if (message.payload === undefined || !Array.isArray(message.payload.headers)) {
    return '';
  }
  const target = headerName.toLowerCase();
  for (let index = 0; index < message.payload.headers.length; index++) {
    const header = message.payload.headers[index];
    if (textOf(header.name).toLowerCase() === target) {
      return textOf(header.value);
    }
  }
  return '';
}

function lastMessage(thread: GmailThread): GmailMessage {
  if (Array.isArray(thread.messages) && thread.messages.length > 0) {
    return thread.messages[thread.messages.length - 1];
  }
  return {};
}

function firstMessage(thread: GmailThread): GmailMessage {
  if (Array.isArray(thread.messages) && thread.messages.length > 0) {
    return thread.messages[0];
  }
  return {};
}

function labelsText(message: GmailMessage): string {
  if (!Array.isArray(message.labelIds) || message.labelIds.length === 0) {
    return '';
  }
  return message.labelIds.join(', ');
}

function messageCount(thread: GmailThread): number {
  return Array.isArray(thread.messages) ? thread.messages.length : 0;
}

function threadResult(thread: GmailThread): DynamicGenericToolResult {
  const newest = lastMessage(thread);
  const first = firstMessage(thread);
  const subject = firstHeader(first, 'Subject').length > 0 ? decodeGmailText(firstHeader(first, 'Subject')) : '(no subject)';
  const from = decodeGmailText(firstHeader(newest, 'From'));
  const date = decodeGmailText(firstHeader(newest, 'Date'));
  const snippet = decodeGmailText(textOf(newest.snippet).length > 0 ? textOf(newest.snippet) : textOf(first.snippet));
  const rows: A2uiLabelValueData[] = [
    { label: 'From', value: from.length > 0 ? from : 'Unknown sender' },
    { label: 'Date', value: date.length > 0 ? date : textOf(newest.internalDate) },
    { label: 'Messages', value: messageCount(thread).toString() },
    { label: 'Thread ID', value: textOf(thread.id) }
  ];
  const labels = labelsText(newest);
  if (labels.length > 0) {
    rows.push({ label: 'Labels', value: labels });
  }
  return {
    sourceTag: 'Gmail API',
    toolName: 'users.threads.get',
    title: subject.substring(0, 120),
    status: 'success',
    summary: snippet.length > 0 ? snippet.substring(0, 240) : 'Gmail thread retrieved.',
    rows: rows,
    rawPreview: 'threadId=' + textOf(thread.id) + ' subject=' + subject.substring(0, 160)
  };
}

function noResultsResult(query: string, estimate: number): DynamicGenericToolResult {
  return {
    sourceTag: 'Gmail API',
    toolName: 'users.threads.list',
    title: '没有找到匹配邮件',
    status: 'success',
    summary: 'Gmail API 查询成功，但当前账号没有匹配这条搜索条件的邮件。',
    rows: [
      { label: 'Query', value: query },
      { label: 'Result size', value: estimate.toString() }
    ],
    rawPreview: 'query=' + query + ' resultSize=' + estimate.toString()
  };
}

function searchSummaryResult(query: string, returned: number, estimate: number): DynamicGenericToolResult {
  return {
    sourceTag: 'Gmail API',
    toolName: 'users.threads.list',
    title: 'Gmail 搜索条件',
    status: 'success',
    summary: '已使用真实 Gmail API 搜索邮件线程；下面展示匹配结果。',
    rows: [
      { label: 'Query', value: query },
      { label: 'Returned threads', value: returned.toString() },
      { label: 'Result size', value: estimate.toString() }
    ],
    rawPreview: 'query=' + query + ' returned=' + returned.toString() + ' resultSize=' + estimate.toString()
  };
}

function errorResult(toolName: string, message: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Gmail API',
    toolName: toolName,
    title: 'Gmail API 调用失败',
    status: 'error',
    summary: message.substring(0, 240),
    rows: [
      { label: 'Tool', value: toolName },
      { label: 'Error', value: message.substring(0, 160) }
    ],
    rawPreview: 'error=' + message.substring(0, 320)
  };
}

async function getThread(accessToken: string, threadId: string): Promise<GmailThread> {
  const url = urlWithParams(GMAIL_API_BASE_URL + '/threads/' + encodeParam(threadId), [
    ['format', 'metadata'],
    ['metadataHeaders', 'Subject'],
    ['metadataHeaders', 'From'],
    ['metadataHeaders', 'Date']
  ]);
  return await requestJson(http.RequestMethod.GET, url, accessToken, null) as GmailThread;
}

function gmailJsonRecord(value: GmailJsonValue): Record<string, GmailJsonValue> | null {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, GmailJsonValue>;
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (trimmed.charAt(0) === '{') {
      try {
        const parsed = JSON.parse(trimmed) as Object;
        if (typeof parsed === 'object' && !Array.isArray(parsed)) {
          return parsed as Record<string, GmailJsonValue>;
        }
      } catch (_error) {
      }
    }
  }
  return null;
}

function gmailThreadCandidate(record: Record<string, GmailJsonValue>, args: MailDetailRequest): GmailThread | null {
  if (Array.isArray(record.messages)) {
    const threadId = textOf(record.id).length > 0 ? textOf(record.id) : textOf(record.threadId);
    if (args.threadId.length === 0 || threadId.length === 0 || threadId === args.threadId) {
      return record as GmailThread;
    }
  }
  const payload = gmailJsonRecord(record.payload);
  if (payload !== null) {
    const messageId = textOf(record.id).length > 0 ? textOf(record.id) : textOf(record.messageId);
    const threadId = textOf(record.threadId).length > 0 ? textOf(record.threadId) : args.threadId;
    if ((args.messageId.length === 0 || messageId.length === 0 || messageId === args.messageId) &&
      (args.threadId.length === 0 || threadId.length === 0 || threadId === args.threadId)) {
      const message = record as GmailMessage;
      const thread: GmailThread = {
        id: threadId,
        messages: [message]
      };
      return thread;
    }
  }
  return null;
}

function findGmailThread(value: GmailJsonValue, args: MailDetailRequest, depth: number = 0): GmailThread | null {
  if (depth > 10 || value === undefined || value === null) {
    return null;
  }
  if (Array.isArray(value)) {
    for (let index = value.length - 1; index >= 0; index--) {
      const found = findGmailThread(value[index] as GmailJsonValue, args, depth + 1);
      if (found !== null) {
        return found;
      }
    }
    return null;
  }
  const record = gmailJsonRecord(value);
  if (record === null) {
    return null;
  }
  const candidate = gmailThreadCandidate(record, args);
  if (candidate !== null) {
    return candidate;
  }
  const preferred = ['data', 'result', 'response', 'thread', 'message', 'message_data', 'messages'];
  for (let index = 0; index < preferred.length; index++) {
    const found = findGmailThread(record[preferred[index]], args, depth + 1);
    if (found !== null) {
      return found;
    }
  }
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    if (preferred.indexOf(keys[index]) >= 0) {
      continue;
    }
    const child = record[keys[index]];
    if (child !== undefined && child !== null && (typeof child === 'object' || typeof child === 'string')) {
      const found = findGmailThread(child, args, depth + 1);
      if (found !== null) {
        return found;
      }
    }
  }
  return null;
}

function gmailDetailFromThread(thread: GmailThread, args: MailDetailRequest): MailDetail {
  const newest = lastMessage(thread);
  const first = firstMessage(thread);
  const body: GmailBodyParts = { plain: '', html: '' };
  collectGmailBody(newest.payload, body);
  const bodyText = (body.plain.length > 0 ? body.plain : gmailTextFromHtml(body.html)).substring(0, 30000);
  const subject = gmailHeader(first, 'Subject').length > 0 ? gmailHeader(first, 'Subject') : args.subject;
  const detail: MailDetail = {
    requestKey: args.requestKey,
    provider: 'gmail',
    threadId: textOf(thread.id).length > 0 ? textOf(thread.id) : args.threadId,
    messageId: textOf(newest.id).length > 0 ? textOf(newest.id) : args.messageId,
    internetMessageId: gmailHeader(newest, 'Message-ID'),
    subject: subject,
    from: gmailHeader(newest, 'From'),
    replyTo: gmailHeader(newest, 'Reply-To'),
    to: gmailAddresses(gmailHeader(newest, 'To')),
    cc: gmailAddresses(gmailHeader(newest, 'Cc')),
    bodyText: bodyText,
    bodyHtml: body.html.substring(0, 30000)
  };
  return detail;
}

export function gmailMailDetailFromPayload(payload: Object, args: MailDetailRequest): MailDetail {
  const thread = findGmailThread(payload, args);
  if (thread === null) {
    throw new Error('Composio Gmail response did not contain a readable thread payload.');
  }
  const detail = gmailDetailFromThread(thread, args);
  if (detail.bodyText.length === 0 && detail.bodyHtml.length === 0) {
    throw new Error('Composio Gmail response did not include the message body.');
  }
  return detail;
}

async function getThreadFull(accessToken: string, threadId: string): Promise<GmailThread> {
  const url = urlWithParams(GMAIL_API_BASE_URL + '/threads/' + encodeParam(threadId), [
    ['format', 'full']
  ]);
  return await requestJson(http.RequestMethod.GET, url, accessToken, null) as GmailThread;
}

export async function readGmailMailDetail(
  accessToken: string,
  args: MailDetailRequest
): Promise<MailDetail> {
  if (accessToken.trim().length === 0) {
    throw new Error('Gmail detail requires an OAuth access token.');
  }
  if (args.threadId.trim().length === 0) {
    throw new Error('Gmail detail requires a thread ID.');
  }
  const thread = await getThreadFull(accessToken, args.threadId.trim());
  return gmailDetailFromThread(thread, args);
}

async function getThreadOrNull(accessToken: string, threadId: string): Promise<GmailThread | null> {
  try {
    return await getThread(accessToken, threadId);
  } catch (error) {
    aiLogError('[AIPhone][GmailThreadDetailSkipped] threadId=' + threadId +
      ' error=' + describeRequestError(error).substring(0, 160));
    return null;
  }
}

async function searchThreads(accessToken: string, prompt: string, args: Object | null = null): Promise<DynamicGenericToolResult[]> {
  const gmailArgs = gmailMcpArgsForPrompt('gmail.mail.search', prompt, args) as GmailSearchThreadsArgs;
  const pageSize = gmailArgs.pageSize > 0 ? Math.min(gmailArgs.pageSize, 10) : 10;
  const url = urlWithParams(GMAIL_API_BASE_URL + '/threads', [
    ['q', gmailArgs.query],
    ['maxResults', pageSize.toString()],
    ['includeSpamTrash', 'false']
  ]);
  aiLogInfo('[AIPhone][GmailSearchQuery] chars=' + gmailArgs.query.length.toString() +
    ' pageSize=' + pageSize.toString() +
    ' query=' + gmailArgs.query.substring(0, 220));
  let listed: GmailThreadsListResponse;
  try {
    listed = await requestJsonWithTimeoutRetry(http.RequestMethod.GET, url, accessToken, null) as GmailThreadsListResponse;
  } catch (error) {
    return [errorResult('users.threads.list', describeRequestError(error) +
      ' Query: ' + gmailArgs.query.substring(0, 180))];
  }
  const items = Array.isArray(listed.threads) ? listed.threads : [];
  if (items.length === 0) {
    return [noResultsResult(gmailArgs.query, listed.resultSizeEstimate === undefined ? 0 : listed.resultSizeEstimate)];
  }
  const tasks: Promise<GmailThread | null>[] = [];
  for (let index = 0; index < items.length && index < pageSize; index++) {
    const threadId = textOf(items[index].id);
    if (threadId.length === 0) {
      continue;
    }
    tasks.push(getThreadOrNull(accessToken, threadId));
  }
  const results: DynamicGenericToolResult[] = [];
  const threads: (GmailThread | null)[] = await Promise.all(tasks);
  for (let index = 0; index < threads.length; index++) {
    if (threads[index] !== null) {
      results.push(threadResult(threads[index] as GmailThread));
    }
  }
  const estimate = listed.resultSizeEstimate === undefined ? results.length : listed.resultSizeEstimate;
  return results.length > 0 ? [searchSummaryResult(gmailArgs.query, results.length, estimate)].concat(results) :
    [errorResult('users.threads.get', 'Gmail thread detail requests failed.')];
}

async function readThread(accessToken: string, prompt: string, args: Object | null = null): Promise<DynamicGenericToolResult[]> {
  const gmailArgs = gmailMcpArgsForPrompt('gmail.thread.read', prompt, args) as GmailGetThreadArgs;
  const threadId = gmailArgs.threadId.trim();
  if (threadId.length === 0) {
    return [errorResult('users.threads.get', 'Missing Gmail thread ID.')];
  }
  return [threadResult(await getThread(accessToken, threadId))];
}

function rfc2822Message(args: GmailCreateDraftArgs): string {
  const to = args.to.join(', ');
  const headers: string[] = [
    'To: ' + to,
    'Subject: ' + args.subject
  ];
  if (args.inReplyTo.trim().length > 0) {
    headers.push('In-Reply-To: ' + args.inReplyTo.trim());
  }
  if (args.references.trim().length > 0) {
    headers.push('References: ' + args.references.trim());
  }
  headers.push('MIME-Version: 1.0');
  headers.push('Content-Type: text/plain; charset=UTF-8');
  return headers.join('\r\n') +
    '\r\n\r\n' +
    args.body + '\r\n';
}

async function createDraft(accessToken: string, prompt: string, args: Object | null = null): Promise<DynamicGenericToolResult[]> {
  const gmailArgs = gmailMcpArgsForPrompt('gmail.draft.create', prompt, args) as GmailCreateDraftArgs;
  if (gmailArgs.to.length === 0) {
    return [errorResult('users.drafts.create', 'Missing recipient email address.')];
  }
  if (gmailArgs.body.trim().length === 0) {
    return [errorResult('users.drafts.create', 'Missing email body.')];
  }
  const threadId = gmailArgs.threadId.trim();
  const raw = bytesToBase64Url(utf8Bytes(rfc2822Message(gmailArgs)));
  const draftBody: GmailDraftCreateRequest = {
    message: {
      raw: raw
    }
  };
  if (threadId.length > 0) {
    draftBody.message.threadId = threadId;
  }
  const created = await requestJson(http.RequestMethod.POST, GMAIL_API_BASE_URL + '/drafts', accessToken, draftBody) as GmailDraftResponse;
  const draftId = textOf(created.id);
  const messageId = created.message === undefined ? '' : textOf(created.message.id);
  const resultThreadId = threadId.length > 0 ? threadId : (created.message === undefined ? '' : textOf(created.message.threadId));
  const rows: A2uiLabelValueData[] = [
    { label: 'To', value: gmailArgs.to.join(', ') },
    { label: 'Subject', value: gmailArgs.subject },
    { label: 'Draft ID', value: draftId },
    { label: 'Message ID', value: messageId }
  ];
  if (resultThreadId.length > 0) {
    rows.push({ label: 'Thread ID', value: resultThreadId });
  }
  return [{
    sourceTag: 'Gmail API',
    toolName: 'users.drafts.create',
    title: 'Gmail 草稿已创建',
    status: 'success',
    summary: '已在真实 Gmail 账号中创建草稿；尚未发送。',
    rows: rows,
    rawPreview: 'draftId=' + draftId + ' messageId=' + messageId + (resultThreadId.length > 0 ? ' threadId=' + resultThreadId : '')
  }];
}

export async function searchGmailThreadsForMail(accessToken: string, prompt: string, args: Object | null = null): Promise<DynamicGenericToolResult[]> {
  return await searchThreads(accessToken, prompt, args);
}

export async function createGmailDraftForMail(accessToken: string, prompt: string, args: Object | null = null): Promise<DynamicGenericToolResult[]> {
  return await createDraft(accessToken, prompt, args);
}

export async function callGmailApiTool(toolId: string, prompt: string, accessToken: string, args: Object | null = null): Promise<DynamicGenericToolResult[]> {
  try {
    if (toolId === 'gmail.mail.search') {
      return await searchThreads(accessToken, prompt, args);
    }
    if (toolId === 'gmail.thread.read') {
      return await readThread(accessToken, prompt, args);
    }
    if (toolId === 'gmail.draft.create' || toolId === 'gmail.draft.apply') {
      return await createDraft(accessToken, prompt, args);
    }
    return [errorResult(toolId, 'Unsupported Gmail API tool.')];
  } catch (error) {
    return [errorResult(toolId, error instanceof Error ? error.message : JSON.stringify(error))];
  }
}
