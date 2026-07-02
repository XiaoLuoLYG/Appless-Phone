import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import {
  normalizeSocialHubConnection,
  normalizeSocialHubDraft,
  normalizeSocialHubItem,
  SocialHubConnectionData,
  SocialHubDraftData,
  SocialHubItemData,
  SocialHubPlatform
} from './SocialHubTypes';

export interface SocialHubFeedResult {
  items: SocialHubItemData[];
  connections: SocialHubConnectionData[];
}

export interface SocialHubProviderConfig {
  xBearerToken: string;
  xUsername: string;
  xUserAccessToken: string;
  slackUserToken: string;
  slackBotToken: string;
}

interface SocialHubBridgeFeedPayload {
  items?: Object[];
  connections?: Object[];
}

interface SocialHubBridgeDraftPayload {
  draft?: Object;
}

interface XUserPayload {
  id?: string;
  username?: string;
  name?: string;
}

interface XTweetPayload {
  id?: string;
  author_id?: string;
  text?: string;
  created_at?: string;
  conversation_id?: string;
  attachments?: XTweetAttachmentsPayload;
}

interface XTweetAttachmentsPayload {
  media_keys?: string[];
}

interface XMediaPayload {
  media_key?: string;
  type?: string;
  url?: string;
  preview_image_url?: string;
}

interface XIncludesPayload {
  users?: Object[];
  media?: Object[];
}

interface XSearchPayload {
  data?: Object[];
  includes?: XIncludesPayload;
}

interface XDmEventPayload {
  id?: string;
  event_type?: string;
  text?: string;
  sender_id?: string;
  dm_conversation_id?: string;
  created_at?: string;
}

interface XDmEventsPayload {
  data?: Object[];
  includes?: XIncludesPayload;
}

interface SlackChannelPayload {
  id?: string;
  name?: string;
}

interface SlackPreviousPayload {
  ts?: string;
}

interface SlackMatchPayload {
  ts?: string;
  iid?: string;
  channel?: SlackChannelPayload;
  channel_name?: string;
  user_name?: string;
  username?: string;
  user?: string;
  text?: string;
  permalink?: string;
  thread_ts?: string;
  previous?: SlackPreviousPayload;
  type?: string;
}

interface SlackSearchPayload {
  ok?: boolean;
  error?: string;
  messages?: SlackMessagesPayload;
}

interface SlackMessagesPayload {
  matches?: Object[];
}

interface SlackPostMessagePayload {
  ok?: boolean;
  error?: string;
  channel?: string;
  ts?: string;
}

interface SlackPostMessageBody {
  channel: string;
  text: string;
  thread_ts?: string;
}

interface HttpTextResult {
  code: number;
  text: string;
}

const X_RECENT_SEARCH_URL = 'https://api.x.com/2/tweets/search/recent';
const X_DM_EVENTS_URL = 'https://api.x.com/2/dm_events';
const SLACK_SEARCH_MESSAGES_URL = 'https://slack.com/api/search.messages';
const SLACK_POST_MESSAGE_URL = 'https://slack.com/api/chat.postMessage';

function emptySocialHubProviderConfig(): SocialHubProviderConfig {
  return {
    xBearerToken: '',
    xUsername: '',
    xUserAccessToken: '',
    slackUserToken: '',
    slackBotToken: ''
  };
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

function responseText(value: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof value === 'string') {
    return value;
  }
  if (value instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(value));
  }
  return textOf(value);
}

function connection(platform: SocialHubPlatform, status: string, message: string): SocialHubConnectionData {
  return {
    platform: platform,
    status: status,
    displayName: platform === 'x' ? 'X' : (platform === 'slack' ? 'Slack' : '企业微信'),
    accountId: '',
    message: message
  } as SocialHubConnectionData;
}

async function requestJsonText(url: string, headers: Record<string, string>): Promise<HttpTextResult> {
  const request = http.createHttp();
  try {
    const response = await request.request(url, {
      method: http.RequestMethod.GET,
      header: headers,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 30000
    });
    return {
      code: response.responseCode,
      text: responseText(response.result)
    };
  } finally {
    request.destroy();
  }
}

async function postJsonText(url: string, headers: Record<string, string>, body: string): Promise<HttpTextResult> {
  const request = http.createHttp();
  try {
    const response = await request.request(url, {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: body,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 30000
    });
    return {
      code: response.responseCode,
      text: responseText(response.result)
    };
  } finally {
    request.destroy();
  }
}

function appendParam(url: string, key: string, value: string): string {
  const joiner = url.indexOf('?') >= 0 ? '&' : '?';
  return url + joiner + encodeURIComponent(key) + '=' + encodeURIComponent(value);
}

function pad2(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

function addDays(date: Date, days: number): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
}

function localDateText(date: Date): string {
  return date.getFullYear().toString() + '-' + pad2(date.getMonth() + 1) + '-' + pad2(date.getDate());
}

function localDayIso(offset: number): string {
  const now = new Date();
  const day = addDays(now, offset);
  return new Date(day.getFullYear(), day.getMonth(), day.getDate()).toISOString();
}

function mentionsToday(prompt: string): boolean {
  return prompt.indexOf('今天') >= 0 || prompt.indexOf('今日') >= 0 || prompt.toLowerCase().indexOf('today') >= 0;
}

function stripSlackPrompt(prompt: string): string {
  const trimmed = prompt.trim();
  const first = /(?:Slack|slack)\s*(?:搜索|查找|查看|search)?\s*[:：]?\s*(.+)$/i.exec(trimmed);
  if (first !== null) {
    return textOf(first[1]).trim();
  }
  const second = /(?:搜索|查找|查看)\s*(?:Slack|slack)\s*(?:消息)?\s*[:：]?\s*(.+)$/i.exec(trimmed);
  return second === null ? trimmed : textOf(second[1]).trim();
}

function slackSearchQuery(prompt: string): string {
  const stripped = stripSlackPrompt(prompt);
  if (/\b(?:from|after|before|in|on):[^\s,，]+/i.test(stripped)) {
    return stripped;
  }
  if (mentionsToday(prompt)) {
    const now = new Date();
    return 'on:' + localDateText(now);
  }
  return stripped.length > 0 ? stripped : 'from:me';
}

function promptRequestsXPrivateMessages(prompt: string): boolean {
  const lower = prompt.toLowerCase();
  const mentionsX = lower.indexOf('x') >= 0 || lower.indexOf('twitter') >= 0 || prompt.indexOf('推特') >= 0;
  const mentionsMessage = lower.indexOf('chat') >= 0 || lower.indexOf('dm') >= 0 ||
    prompt.indexOf('私信') >= 0 || prompt.indexOf('消息') >= 0;
  const mentionsPublicPost = lower.indexOf('post') >= 0 || prompt.indexOf('帖子') >= 0 ||
    prompt.indexOf('推文') >= 0 || prompt.indexOf('公开') >= 0;
  return mentionsMessage && !mentionsPublicPost && (mentionsX || prompt.indexOf('消息') >= 0);
}

function xHandleFromPrompt(prompt: string): string {
  const urlMatch = /(?:x\.com|twitter\.com)\/([A-Za-z0-9_]{1,15})/i.exec(prompt);
  if (urlMatch !== null) {
    return textOf(urlMatch[1]);
  }
  const atMatch = /@([A-Za-z0-9_]{1,15})/.exec(prompt);
  if (atMatch !== null) {
    return textOf(atMatch[1]);
  }
  const named = /(?:x|X|Twitter|twitter)\s*(?:上|的|里)?\s*([A-Za-z0-9_]{2,15})\s*(?:的)?\s*(?:post|帖子|推文)/.exec(prompt);
  if (named !== null) {
    return textOf(named[1]);
  }
  if (prompt.toLowerCase().indexOf('openai') >= 0) {
    return 'openai';
  }
  return '';
}

function xSearchQuery(prompt: string, xUsername: string): string {
  if (/\b(?:from|to|@)[A-Za-z0-9_]/.test(prompt)) {
    return prompt.trim();
  }
  const handle = xHandleFromPrompt(prompt);
  if (handle.length > 0) {
    return 'from:' + handle.replace('@', '');
  }
  if ((prompt.indexOf('我') >= 0 || prompt.toLowerCase().indexOf('my ') >= 0) && xUsername.trim().length > 0) {
    return 'from:' + xUsername.trim().replace('@', '');
  }
  return '';
}

function findXUser(users: XUserPayload[], id: string): XUserPayload {
  for (let index = 0; index < users.length; index++) {
    if (textOf(users[index].id) === id) {
      return users[index];
    }
  }
  return {};
}

function findXMediaUrl(media: XMediaPayload[], tweet: XTweetPayload): string {
  if (tweet.attachments === undefined || !Array.isArray(tweet.attachments.media_keys)) {
    return '';
  }
  for (let keyIndex = 0; keyIndex < tweet.attachments.media_keys.length; keyIndex++) {
    const mediaKey = textOf(tweet.attachments.media_keys[keyIndex]);
    for (let mediaIndex = 0; mediaIndex < media.length; mediaIndex++) {
      if (textOf(media[mediaIndex].media_key) === mediaKey) {
        const imageUrl = textOf(media[mediaIndex].url);
        return imageUrl.length > 0 ? imageUrl : textOf(media[mediaIndex].preview_image_url);
      }
    }
  }
  return '';
}

function isSameLocalDayIso(timestamp: string, expected: Date): boolean {
  const value = new Date(timestamp);
  if (Number.isNaN(value.getTime())) {
    return false;
  }
  return localDateText(value) === localDateText(expected);
}

async function fetchXDirectMessages(prompt: string, config: SocialHubProviderConfig): Promise<SocialHubFeedResult> {
  const token = config.xUserAccessToken.trim();
  if (token.length === 0) {
    return {
      items: [],
      connections: [connection('x', 'needs_auth', 'X 公开 post 搜索可用；读取 X Chat/DM 需要先授权 X OAuth。')]
    };
  }
  let url = appendParam(X_DM_EVENTS_URL, 'max_results', '100');
  url = appendParam(url, 'dm_event.fields', 'created_at,sender_id,text,dm_conversation_id,event_type');
  url = appendParam(url, 'expansions', 'sender_id');
  url = appendParam(url, 'user.fields', 'username,name,profile_image_url');
  const response = await requestJsonText(url, {
    'Accept': 'application/json',
    'Authorization': 'Bearer ' + token
  });
  if (response.code < 200 || response.code >= 300) {
    return { items: [], connections: [connection('x', 'error', 'X DM lookup failed: HTTP ' + response.code.toString() + ' ' + response.text.substring(0, 220))] };
  }
  const payload = JSON.parse(response.text) as XDmEventsPayload;
  const users: XUserPayload[] = [];
  if (payload.includes !== undefined && Array.isArray(payload.includes.users)) {
    payload.includes.users.forEach((user: Object) => users.push(user as XUserPayload));
  }
  const items: SocialHubItemData[] = [];
  if (Array.isArray(payload.data)) {
    payload.data.forEach((eventObject: Object) => {
      const event = eventObject as XDmEventPayload;
      const createdAt = textOf(event.created_at);
      if (mentionsToday(prompt) && !isSameLocalDayIso(createdAt, new Date())) {
        return;
      }
      if (textOf(event.event_type).length > 0 && textOf(event.event_type) !== 'MessageCreate') {
        return;
      }
      const user = findXUser(users, textOf(event.sender_id));
      const username = textOf(user.username);
      items.push({
        id: 'x-dm-' + textOf(event.id),
        platform: 'x',
        kind: 'message',
        author: textOf(user.name || username || event.sender_id),
        handle: username.length > 0 ? '@' + username : '',
        text: textOf(event.text),
        timestamp: createdAt,
        url: 'https://x.com/messages',
        mediaUrl: '',
        channel: 'X Chat',
        channelId: textOf(event.dm_conversation_id),
        threadId: textOf(event.dm_conversation_id),
        unread: false
      });
    });
  }
  return { items, connections: [connection('x', 'connected', items.length > 0 ? 'X DM lookup connected.' : 'X DM lookup connected, but returned 0 messages.')] };
}

async function fetchXRecentSearch(prompt: string, config: SocialHubProviderConfig): Promise<SocialHubFeedResult> {
  const token = config.xBearerToken.trim();
  if (token.length === 0) {
    return { items: [], connections: [connection('x', 'disabled', '未配置 X_BEARER_TOKEN。')] };
  }
  if (promptRequestsXPrivateMessages(prompt)) {
    return fetchXDirectMessages(prompt, config);
  }
  const query = xSearchQuery(prompt, config.xUsername);
  if (query.length === 0) {
    return {
      items: [],
      connections: [connection('x', 'limited', 'X bearer 已配置；公开 post 搜索需要关键词。读取“我的 X 消息”还需要 X_USERNAME 或 X OAuth 用户授权。')]
    };
  }
  let url = appendParam(X_RECENT_SEARCH_URL, 'query', query);
  url = appendParam(url, 'max_results', '10');
  url = appendParam(url, 'tweet.fields', 'created_at,author_id,conversation_id,attachments');
  url = appendParam(url, 'expansions', 'author_id,attachments.media_keys');
  url = appendParam(url, 'user.fields', 'username,name');
  url = appendParam(url, 'media.fields', 'url,preview_image_url,type');
  if (mentionsToday(prompt)) {
    url = appendParam(url, 'start_time', localDayIso(0));
    url = appendParam(url, 'end_time', localDayIso(1));
  }
  const response = await requestJsonText(url, {
    'Accept': 'application/json',
    'Authorization': 'Bearer ' + token
  });
  if (response.code < 200 || response.code >= 300) {
    return { items: [], connections: [connection('x', 'error', 'X recent search failed: HTTP ' + response.code.toString() + ' ' + response.text.substring(0, 220))] };
  }
  const payload = JSON.parse(response.text) as XSearchPayload;
  const users: XUserPayload[] = [];
  if (payload.includes !== undefined && Array.isArray(payload.includes.users)) {
    payload.includes.users.forEach((user: Object) => users.push(user as XUserPayload));
  }
  const media: XMediaPayload[] = [];
  if (payload.includes !== undefined && Array.isArray(payload.includes.media)) {
    payload.includes.media.forEach((item: Object) => media.push(item as XMediaPayload));
  }
  const items: SocialHubItemData[] = [];
  if (Array.isArray(payload.data)) {
    payload.data.forEach((tweetObject: Object) => {
      const tweet = tweetObject as XTweetPayload;
      const user = findXUser(users, textOf(tweet.author_id));
      const username = textOf(user.username);
      items.push({
        id: 'x-' + textOf(tweet.id),
        platform: 'x',
        kind: 'post',
        author: textOf(user.name || username),
        handle: username.length > 0 ? '@' + username : '',
        text: textOf(tweet.text),
        timestamp: textOf(tweet.created_at),
        url: username.length > 0 && textOf(tweet.id).length > 0 ? 'https://x.com/' + username + '/status/' + textOf(tweet.id) : '',
        mediaUrl: findXMediaUrl(media, tweet),
        channel: 'X',
        channelId: '',
        threadId: textOf(tweet.conversation_id || tweet.id),
        unread: false
      });
    });
  }
  return { items, connections: [connection('x', 'connected', items.length > 0 ? 'X public search connected.' : 'X public search connected, but returned 0 posts.')] };
}

async function fetchSlackSearch(prompt: string, config: SocialHubProviderConfig): Promise<SocialHubFeedResult> {
  const token = config.slackUserToken.trim();
  if (token.length === 0) {
    return { items: [], connections: [connection('slack', 'disabled', '未配置 SLACK_USER_TOKEN。')] };
  }
  let url = appendParam(SLACK_SEARCH_MESSAGES_URL, 'query', slackSearchQuery(prompt));
  url = appendParam(url, 'count', '10');
  url = appendParam(url, 'sort', 'timestamp');
  url = appendParam(url, 'sort_dir', 'desc');
  const response = await requestJsonText(url, {
    'Accept': 'application/json',
    'Authorization': 'Bearer ' + token
  });
  if (response.code < 200 || response.code >= 300) {
    return { items: [], connections: [connection('slack', 'error', 'Slack search.messages failed: HTTP ' + response.code.toString() + ' ' + response.text.substring(0, 220))] };
  }
  const payload = JSON.parse(response.text) as SlackSearchPayload;
  if (payload.ok === false) {
    return { items: [], connections: [connection('slack', 'error', 'Slack search.messages failed: ' + textOf(payload.error || 'ok:false'))] };
  }
  const items: SocialHubItemData[] = [];
  if (payload.messages !== undefined && Array.isArray(payload.messages.matches)) {
    payload.messages.matches.forEach((matchObject: Object) => {
      const match = matchObject as SlackMatchPayload;
      const channel = match.channel || {};
      const ts = textOf(match.ts || match.iid);
      items.push({
        id: ('slack-' + textOf(channel.id || match.channel_name) + '-' + ts).replace(/\s+/g, '_'),
        platform: 'slack',
        kind: 'message',
        author: textOf(match.user_name || match.username || match.user),
        handle: textOf(match.user_name || match.username || match.user),
        text: textOf(match.text),
        timestamp: ts,
        url: textOf(match.permalink),
        mediaUrl: '',
        channel: textOf(channel.name || match.channel_name || match.type),
        channelId: textOf(channel.id),
        threadId: textOf(match.thread_ts || (match.previous === undefined ? '' : match.previous.ts) || ts),
        unread: false
      });
    });
  }
  return { items, connections: [connection('slack', 'connected', items.length > 0 ? 'Slack search.messages connected.' : 'Slack connected, but returned 0 messages.')] };
}

function socialHubReplyResult(item: SocialHubItemData, text: string, status: string, error: string, localOnly: boolean, sent: boolean): SocialHubDraftData {
  return {
    itemId: item.id,
    platform: item.platform,
    text: text,
    status: status,
    error: error,
    localOnly: localOnly,
    sent: sent
  } as SocialHubDraftData;
}

async function slackPostMessageError(token: string, body: SlackPostMessageBody): Promise<string> {
  const response = await postJsonText(SLACK_POST_MESSAGE_URL, {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
    'Authorization': 'Bearer ' + token
  }, JSON.stringify(body));
  if (response.code < 200 || response.code >= 300) {
    return 'HTTP ' + response.code.toString() + ' ' + response.text.substring(0, 220);
  }
  const payload = JSON.parse(response.text) as SlackPostMessagePayload;
  if (payload.ok === false) {
    return textOf(payload.error || 'ok:false');
  }
  return '';
}

async function sendSlackReply(item: SocialHubItemData, text: string, config: SocialHubProviderConfig): Promise<SocialHubDraftData> {
  const message = text.trim();
  if (message.length === 0) {
    return socialHubReplyResult(item, '', 'error', '请输入要发送的 Slack 回复。', true, false);
  }
  const channelId = item.channelId.trim().length > 0 ? item.channelId.trim() : item.channel.trim();
  if (channelId.length === 0) {
    return socialHubReplyResult(item, '', 'error', 'Slack search result missing channel id; cannot send a reply.', true, false);
  }
  const userToken = config.slackUserToken.trim();
  if (userToken.length === 0) {
    return socialHubReplyResult(item, '', 'error', '未配置 SLACK_USER_TOKEN。', true, false);
  }
  const threadTs = item.threadId.trim().length > 0 ? item.threadId.trim() : item.timestamp.trim();
  const body: SlackPostMessageBody = {
    channel: channelId,
    text: message
  };
  if (threadTs.length > 0) {
    body.thread_ts = threadTs;
  }
  const error = await slackPostMessageError(userToken, body);
  if (error.length > 0) {
    return socialHubReplyResult(item, '', 'error', 'Slack chat.postMessage failed: ' + error, true, false);
  }
  return socialHubReplyResult(item, '已发送到 Slack：' + message, 'draft', '', false, true);
}

function uniqueSocialItems(items: SocialHubItemData[]): SocialHubItemData[] {
  const ids: string[] = [];
  const result: SocialHubItemData[] = [];
  items.forEach((item: SocialHubItemData) => {
    if (item.id.length === 0 || ids.indexOf(item.id) >= 0) {
      return;
    }
    ids.push(item.id);
    result.push(item);
  });
  return result;
}

function mergeFeedResults(results: SocialHubFeedResult[]): SocialHubFeedResult {
  const items: SocialHubItemData[] = [];
  const connections: SocialHubConnectionData[] = [];
  results.forEach((result: SocialHubFeedResult) => {
    result.items.forEach((item: SocialHubItemData) => items.push(item));
    result.connections.forEach((current: SocialHubConnectionData) => connections.push(current));
  });
  return {
    items: uniqueSocialItems(items),
    connections: connections
  };
}

export function socialHubBridgeHeaders(gatewayApiKey: string): Record<string, string> {
  const headers: Record<string, string> = {
    'Accept': 'application/json'
  };
  const apiKey = gatewayApiKey.trim();
  if (apiKey.length > 0) {
    headers['X-API-Key'] = apiKey;
  }
  return headers;
}

export function parseSocialHubFeedPayload(raw: string): SocialHubFeedResult {
  const payload = JSON.parse(raw) as SocialHubBridgeFeedPayload;
  const items: SocialHubItemData[] = [];
  const connections: SocialHubConnectionData[] = [];
  if (Array.isArray(payload.items)) {
    payload.items.forEach((item: Object) => {
      items.push(normalizeSocialHubItem(item));
    });
  }
  if (Array.isArray(payload.connections)) {
    payload.connections.forEach((current: Object) => {
      connections.push(normalizeSocialHubConnection(current));
    });
  }
  return { items: items, connections: connections };
}

export function parseSocialHubDraftPayload(raw: string): SocialHubDraftData {
  const payload = JSON.parse(raw) as SocialHubBridgeDraftPayload;
  return normalizeSocialHubDraft(payload.draft);
}

export function socialHubXPostResult(result: SocialHubFeedResult): SocialHubFeedResult {
  const items: SocialHubItemData[] = [];
  const connections: SocialHubConnectionData[] = [];
  result.items.forEach((item: SocialHubItemData) => {
    if (item.platform === 'x' && item.kind === 'post') {
      items.push(item);
    }
  });
  result.connections.forEach((current: SocialHubConnectionData) => {
    if (current.platform === 'x') {
      connections.push(current);
    }
  });
  return {
    items: items,
    connections: connections
  };
}

function connectionError(platform: SocialHubPlatform, message: string): SocialHubConnectionData {
  return connection(platform, 'error', message);
}

export function socialHubBridgeUnavailableFeed(message: string): SocialHubFeedResult {
  const detail = 'Social bridge unavailable: ' + message;
  return {
    items: [],
    connections: [
      connectionError('x', detail),
      connectionError('slack', detail),
      connectionError('wecom', detail)
    ]
  };
}

export function socialHubBridgeDraftError(itemId: string, platform: SocialHubPlatform, message: string): SocialHubDraftData {
  return {
    itemId: itemId,
    platform: platform,
    text: '',
    status: 'error',
    error: 'Social bridge unavailable: ' + message,
    localOnly: true,
    sent: false
  };
}

function describeThrown(error: Error | Object | string | number | boolean | null | undefined): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string') {
    return error;
  }
  if (typeof error === 'number' || typeof error === 'boolean') {
    return error.toString();
  }
  return JSON.stringify(error);
}

function isRetryableNetworkError(error: Error | Object | string | number | boolean | null | undefined): boolean {
  const message = describeThrown(error).toLowerCase();
  return message.indexOf('2300028') >= 0 ||
    message.indexOf('operation timeout') >= 0 ||
    message.indexOf('timeout') >= 0 ||
    message.indexOf('timed out') >= 0;
}

function slackErrorMessage(error: Error | Object | string | number | boolean | null | undefined): string {
  const message = describeThrown(error);
  if (isRetryableNetworkError(error)) {
    return 'Slack API 连接超时，已自动重试；请检查手机网络/VPN 后再试。';
  }
  return message;
}

export class SocialHubClient {
  async feed(query: string, _gatewayApiKey: string = '', providerConfig: SocialHubProviderConfig = emptySocialHubProviderConfig()): Promise<SocialHubFeedResult> {
    const results: SocialHubFeedResult[] = [];
    try {
      results.push(await fetchXRecentSearch(query, providerConfig));
    } catch (error) {
      results.push({ items: [], connections: [connectionError('x', describeThrown(error))] });
    }
    try {
      try {
        results.push(await fetchSlackSearch(query, providerConfig));
      } catch (firstError) {
        if (!isRetryableNetworkError(firstError)) {
          throw new Error(describeThrown(firstError));
        }
        results.push(await fetchSlackSearch(query, providerConfig));
      }
    } catch (error) {
      results.push({ items: [], connections: [connectionError('slack', slackErrorMessage(error))] });
    }
    results.push({ items: [], connections: [connection('wecom', 'needs_auth', 'Set WECOM_CORP_ID, WECOM_AGENT_ID, WECOM_SECRET, WECOM_CALLBACK_TOKEN, and WECOM_ENCODING_AES_KEY.')] });
    return mergeFeedResults(results);
  }

  async xPostSearch(query: string, _gatewayApiKey: string = '', providerConfig: SocialHubProviderConfig = emptySocialHubProviderConfig()): Promise<SocialHubFeedResult> {
    try {
      return socialHubXPostResult(await fetchXRecentSearch(query, providerConfig));
    } catch (error) {
      return socialHubXPostResult({ items: [], connections: [connectionError('x', describeThrown(error))] });
    }
  }

  async draft(itemId: string, platform: SocialHubPlatform, instruction: string, _gatewayApiKey: string = '', _providerConfig: SocialHubProviderConfig = emptySocialHubProviderConfig()): Promise<SocialHubDraftData> {
    return {
      itemId: itemId,
      platform: platform,
      text: instruction.trim(),
      status: instruction.trim().length > 0 ? 'draft' : 'error',
      error: instruction.trim().length > 0 ? '' : 'Draft instruction is empty.',
      localOnly: true,
      sent: false
    };
  }

  async sendReply(item: SocialHubItemData, text: string, _gatewayApiKey: string = '', providerConfig: SocialHubProviderConfig = emptySocialHubProviderConfig()): Promise<SocialHubDraftData> {
    if (item.platform === 'slack') {
      return sendSlackReply(item, text, providerConfig);
    }
    if (item.platform === 'x') {
      return socialHubReplyResult(item, '', 'error', 'X Chat/DM 回复需要 X OAuth 用户授权和 dm.write；当前只支持公开 post 搜索。', true, false);
    }
    return socialHubReplyResult(item, '', 'error', '当前平台还不支持直接回复。', true, false);
  }
}
