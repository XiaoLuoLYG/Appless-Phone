import {
  normalizeSocialHubConnection,
  normalizeSocialHubDraft,
  normalizeSocialHubItem,
  normalizeSocialHubPublication,
  SocialHubConnectionData,
  SocialHubDraftData,
  SocialHubItemData,
  SocialHubPlatform,
  SocialHubPublicationData
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

export interface SocialHubPublicationPreviewInput {
  platform: SocialHubPlatform;
  operation: string;
  accountId?: string;
  accountName?: string;
  text?: string;
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

interface XIncludesPayload {
  users?: Object[];
  media?: Object[];
}

const X_PUBLIC_SEARCH_MARKER: string = 'X 公开 post 搜索关键词:';

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

interface InstagramUserPayload {
  id?: string;
  username?: string;
}

interface InstagramRecipientsPayload {
  data?: Object[];
}

interface InstagramMessagePayload {
  id?: string;
  created_time?: string;
  from?: InstagramUserPayload;
  message?: string;
  to?: InstagramRecipientsPayload;
}

interface InstagramMessagesPayload {
  data?: Object[];
}

interface ComposioSocialErrorPayload {
  message?: Object | string | number | boolean | null;
}

interface ComposioSocialEnvelope {
  data?: Object | null;
  error?: Object | string | number | boolean | null;
  successful?: boolean | string;
}

type SocialCommunityValue = Object | string | number | boolean | null | undefined;
type SocialCommunityRecord = Record<string, SocialCommunityValue>;

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

export function createSocialHubPublicationPreview(
  input: SocialHubPublicationPreviewInput,
  nowIso: string = new Date().toISOString()
): SocialHubPublicationData {
  const platform = input.platform;
  const text = (input.text ?? '').trim();
  const accountId = (input.accountId ?? '').trim();
  const supported = platform === 'x' || platform === 'linkedin' ||
    platform === 'instagram' || platform === 'reddit';
  let error = '';
  if (input.operation !== 'publish') {
    error = 'Social post preview requires operation=publish.';
  } else if (!supported) {
    error = '请选择 X、LinkedIn、Instagram 或 Reddit。';
  } else if (text.length === 0 || text.length > 3000) {
    error = '公开帖子预览需要 1–3000 个字符的正文。';
  } else if (accountId.length === 0) {
    error = 'Provider 没有返回真实账号 ID；不会创建或发布帖子。';
  }
  return normalizeSocialHubPublication({
    platform,
    operation: 'publish',
    accountId,
    accountName: (input.accountName ?? '').trim(),
    text,
    status: error.length > 0 ? 'error' : 'preview',
    updatedAt: nowIso,
    error
  });
}

function platformDisplayName(platform: SocialHubPlatform): string {
  if (platform === 'x') {
    return 'X';
  }
  if (platform === 'slack') {
    return 'Slack';
  }
  if (platform === 'wecom') {
    return '企业微信';
  }
  if (platform === 'discord') {
    return 'Discord';
  }
  if (platform === 'linkedin') {
    return 'LinkedIn';
  }
  if (platform === 'whatsapp') {
    return 'WhatsApp';
  }
  if (platform === 'instagram') {
    return 'Instagram';
  }
  if (platform === 'reddit') {
    return 'Reddit';
  }
  return 'SocialHub';
}

function connection(platform: SocialHubPlatform, status: string, message: string): SocialHubConnectionData {
  return {
    platform: platform,
    status: status,
    displayName: platformDisplayName(platform),
    accountId: '',
    message: message
  } as SocialHubConnectionData;
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

export function xSearchQuery(prompt: string, xUsername: string): string {
  const markerIndex = prompt.indexOf(X_PUBLIC_SEARCH_MARKER);
  if (markerIndex >= 0) {
    const keyword = prompt.substring(markerIndex + X_PUBLIC_SEARCH_MARKER.length).trim();
    if (keyword.length > 0) {
      return keyword;
    }
  }
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

export function socialHubPrivateItems(items: SocialHubItemData[]): SocialHubItemData[] {
  const result: SocialHubItemData[] = [];
  items.forEach((item: SocialHubItemData) => {
    if (item.kind === 'message') {
      result.push(item);
    }
  });
  return result;
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

function composioSocialError(payload: ComposioSocialEnvelope): string {
  if (payload.error !== undefined && payload.error !== null) {
    if (typeof payload.error === 'object') {
      const error = payload.error as ComposioSocialErrorPayload;
      const message = textOf(error.message).trim();
      return message.length > 0 ? message : textOf(payload.error);
    }
    return textOf(payload.error);
  }
  return payload.successful === false || payload.successful === 'false' ?
    'Provider returned an unsuccessful execution status.' : '';
}

function xUserForId(includes: XIncludesPayload | undefined, id: string): XUserPayload {
  if (includes !== undefined && Array.isArray(includes.users)) {
    for (let index = 0; index < includes.users.length; index++) {
      const user = includes.users[index] as XUserPayload;
      if (textOf(user.id) === id) {
        return user;
      }
    }
  }
  return {};
}

function slackTimestamp(value: string): string {
  const seconds = Number(value.split('.')[0]);
  if (!Number.isFinite(seconds) || seconds <= 0) {
    return '';
  }
  return new Date(seconds * 1000).toISOString();
}

function parseComposioXMessages(data: Object, ownAccountId: string): SocialHubItemData[] {
  const payload = data as XDmEventsPayload;
  const items: SocialHubItemData[] = [];
  if (!Array.isArray(payload.data)) {
    return items;
  }
  payload.data.forEach((value: Object) => {
    const event = value as XDmEventPayload;
    const senderId = textOf(event.sender_id);
    if (textOf(event.event_type) !== 'MessageCreate' || textOf(event.text).trim().length === 0 ||
      (ownAccountId.length > 0 && senderId === ownAccountId)) {
      return;
    }
    const user = xUserForId(payload.includes, senderId);
    const username = textOf(user.username);
    items.push({
      id: textOf(event.id),
      platform: 'x',
      kind: 'message',
      author: textOf(user.name).trim().length > 0 ? textOf(user.name) : (username.length > 0 ? username : senderId),
      handle: username.length > 0 ? '@' + username : senderId,
      text: textOf(event.text),
      timestamp: textOf(event.created_at),
      url: '',
      mediaUrl: '',
      channel: '私信',
      channelId: textOf(event.dm_conversation_id),
      threadId: textOf(event.dm_conversation_id),
      unread: false
    } as SocialHubItemData);
  });
  return items;
}

function parseComposioSlackMessages(data: Object): SocialHubItemData[] {
  const payload = data as SlackSearchPayload;
  const items: SocialHubItemData[] = [];
  if (payload.messages === undefined || !Array.isArray(payload.messages.matches)) {
    return items;
  }
  payload.messages.matches.forEach((value: Object) => {
    const match = value as SlackMatchPayload;
    const channel = match.channel ?? {};
    const channelId = textOf(channel.id);
    const permalink = textOf(match.permalink);
    if (textOf(match.text).trim().length === 0 ||
      (channelId.indexOf('D') !== 0 && permalink.toLowerCase().indexOf('/archives/d') < 0)) {
      return;
    }
    const username = textOf(match.username).trim().length > 0 ? textOf(match.username) :
      (textOf(match.user_name).trim().length > 0 ? textOf(match.user_name) : textOf(match.user));
    items.push({
      id: textOf(match.iid).trim().length > 0 ? textOf(match.iid) : textOf(match.ts),
      platform: 'slack',
      kind: 'message',
      author: username.length > 0 ? username : textOf(channel.name),
      handle: '',
      text: textOf(match.text),
      timestamp: slackTimestamp(textOf(match.ts)),
      url: permalink,
      mediaUrl: '',
      channel: textOf(channel.name).trim().length > 0 ? textOf(channel.name) : '私信',
      channelId: channelId,
      threadId: textOf(match.thread_ts).trim().length > 0 ? textOf(match.thread_ts) : textOf(match.ts),
      unread: false
    } as SocialHubItemData);
  });
  return items;
}

function parseComposioInstagramMessages(data: Object, conversationId: string, ownAccountId: string): SocialHubItemData[] {
  const payload = data as InstagramMessagesPayload;
  const items: SocialHubItemData[] = [];
  if (!Array.isArray(payload.data)) {
    return items;
  }
  payload.data.forEach((value: Object) => {
    const message = value as InstagramMessagePayload;
    const sender = message.from ?? {};
    const senderId = textOf(sender.id);
    if (textOf(message.message).trim().length === 0 ||
      (ownAccountId.length > 0 && senderId === ownAccountId)) {
      return;
    }
    const username = textOf(sender.username);
    items.push({
      id: textOf(message.id),
      platform: 'instagram',
      kind: 'message',
      author: username.length > 0 ? username : senderId,
      handle: username.length > 0 ? '@' + username : senderId,
      text: textOf(message.message),
      timestamp: textOf(message.created_time),
      url: '',
      mediaUrl: '',
      channel: '私信',
      channelId: conversationId,
      threadId: conversationId,
      unread: false
    } as SocialHubItemData);
  });
  return items;
}

export function parseComposioSocialFeed(
  platform: SocialHubPlatform,
  raw: string,
  conversationId: string = '',
  ownAccountId: string = ''
): SocialHubFeedResult {
  let payload: ComposioSocialEnvelope;
  try {
    payload = JSON.parse(raw) as ComposioSocialEnvelope;
  } catch (_error) {
    return { items: [], connections: [connection(platform, 'error', 'Provider 返回了无法解析的数据。')] };
  }
  const error = composioSocialError(payload);
  if (error.length > 0) {
    return { items: [], connections: [connection(platform, 'error', error)] };
  }
  const data = payload.data;
  let items: SocialHubItemData[] = [];
  if (data !== undefined && data !== null) {
    if (platform === 'x') {
      items = parseComposioXMessages(data, ownAccountId);
    } else if (platform === 'slack') {
      items = parseComposioSlackMessages(data);
    } else if (platform === 'instagram') {
      items = parseComposioInstagramMessages(data, conversationId, ownAccountId);
    }
  }
  return {
    items: items,
    connections: [connection(platform, 'connected', platformDisplayName(platform) + ' 已连接')]
  };
}

function communityString(record: SocialCommunityRecord, names: string[]): string {
  for (let index = 0; index < names.length; index++) {
    const value = textOf(record[names[index]]).trim();
    if (value.length > 0 && value.charAt(0) !== '{' && value.charAt(0) !== '[') {
      return value;
    }
  }
  return '';
}

function communityNestedString(
  record: SocialCommunityRecord,
  key: string,
  names: string[]
): string {
  const value = record[key];
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return '';
  }
  return communityString(value as SocialCommunityRecord, names);
}

function looksLikeCommunityItem(record: SocialCommunityRecord): boolean {
  return communityString(record, [
    'title', 'text', 'full_text', 'selftext', 'caption', 'commentary', 'body',
    'permalink', 'media_url', 'web_url'
  ]).length > 0;
}

function collectCommunityRecords(
  value: SocialCommunityValue,
  records: Object[],
  depth: number
): void {
  if (depth > 7 || value === undefined || value === null) {
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item: SocialCommunityValue) =>
      collectCommunityRecords(item, records, depth + 1)
    );
    return;
  }
  if (typeof value !== 'object') {
    return;
  }
  const record = value as SocialCommunityRecord;
  if (looksLikeCommunityItem(record)) {
    records.push(record as Object);
    return;
  }
  const preferred = ['data', 'children', 'results', 'items', 'posts', 'media', 'elements', 'response'];
  for (let index = 0; index < preferred.length; index++) {
    const nested = record[preferred[index]];
    if (nested !== undefined && nested !== null) {
      collectCommunityRecords(nested, records, depth + 1);
    }
  }
}

function communityRecordItem(platform: SocialHubPlatform, value: Object): SocialHubItemData {
  const record = value as SocialCommunityRecord;
  const id = communityString(record, ['id', 'name', 'fullname', 'post_id', 'media_id', 'urn']);
  const title = communityString(record, ['title']);
  const body = communityString(
    record,
    ['full_text', 'text', 'selftext', 'caption', 'commentary', 'body']
  );
  const author = communityString(record, ['author', 'username', 'user_name', 'owner_name']);
  const nestedAuthor = communityNestedString(record, 'author', ['name', 'username', 'id']);
  const nestedUser = communityNestedString(record, 'user', ['name', 'username', 'screen_name', 'id']);
  const resolvedAuthor = author.length > 0 ? author :
    (nestedAuthor.length > 0 ? nestedAuthor : nestedUser);
  const directUrl = communityString(record, ['permalink', 'url', 'web_url', 'webLink']);
  let url = directUrl.charAt(0) === '/' ? 'https://www.reddit.com' + directUrl : directUrl;
  if (url.length === 0 && platform === 'x' && /^[0-9]{1,19}$/.test(id)) {
    url = 'https://x.com/i/web/status/' + id;
  }
  const mediaUrl = communityString(
    record,
    ['media_url', 'thumbnail', 'image_url', 'preview_image_url']
  );
  const timestamp = communityString(
    record,
    ['created_at', 'created_time', 'timestamp', 'publishedAt', 'created_utc']
  );
  const subreddit = communityString(record, ['subreddit', 'subreddit_name_prefixed']);
  const text = title.length > 0 && body.length > 0 && title !== body ?
    title + '\n' + body : (title.length > 0 ? title : body);
  return normalizeSocialHubItem({
    id,
    platform,
    kind: 'post',
    author: resolvedAuthor,
    handle: resolvedAuthor,
    text,
    timestamp,
    url,
    mediaUrl,
    channel: subreddit,
    channelId: subreddit.replace(/^r\//, ''),
    threadId: id,
    unread: false
  });
}

export function parseComposioCommunityFeed(
  platform: SocialHubPlatform,
  raw: string
): SocialHubFeedResult {
  let payload: ComposioSocialEnvelope;
  try {
    payload = JSON.parse(raw) as ComposioSocialEnvelope;
  } catch (_error) {
    return {
      items: [],
      connections: [connection(platform, 'error', 'Provider 返回了无法解析的数据。')]
    };
  }
  const error = composioSocialError(payload);
  if (error.length > 0) {
    return { items: [], connections: [connection(platform, 'error', error)] };
  }
  const records: Object[] = [];
  collectCommunityRecords(payload.data, records, 0);
  const items: SocialHubItemData[] = [];
  const seen: string[] = [];
  records.forEach((record: Object) => {
    const item = communityRecordItem(platform, record);
    const key = item.id.length > 0 ? item.id : item.url;
    if ((key.length > 0 || item.text.length > 0) && seen.indexOf(key) < 0) {
      seen.push(key);
      items.push(item);
    }
  });
  return {
    items,
    connections: [connection(platform, 'connected', platformDisplayName(platform) + ' 已连接')]
  };
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
  async feed(_query: string, _gatewayApiKey: string = '', _providerConfig: SocialHubProviderConfig = emptySocialHubProviderConfig()): Promise<SocialHubFeedResult> {
    return {
      items: [],
      connections: [
        connection('x', 'needs_auth', 'X 读取已统一到当前用户的 Composio connected account，请通过产品 SocialHub 入口调用。'),
        connection('slack', 'needs_auth', 'Slack 读取已统一到当前用户的 Composio connected account，请通过产品 SocialHub 入口调用。'),
        connection('wecom', 'needs_auth', 'Set WECOM_CORP_ID, WECOM_AGENT_ID, WECOM_SECRET, WECOM_CALLBACK_TOKEN, and WECOM_ENCODING_AES_KEY.')
      ]
    };
  }

  async xPostSearch(_query: string, _gatewayApiKey: string = '', _providerConfig: SocialHubProviderConfig = emptySocialHubProviderConfig()): Promise<SocialHubFeedResult> {
    return {
      items: [],
      connections: [
        connection('x', 'needs_auth', 'X 公开 post 搜索已统一到当前用户的 Composio connected account，请通过产品 X 搜索入口调用。')
      ]
    };
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

  async sendReply(item: SocialHubItemData, _text: string, _gatewayApiKey: string = '', _providerConfig: SocialHubProviderConfig = emptySocialHubProviderConfig()): Promise<SocialHubDraftData> {
    if (item.platform === 'slack') {
      return socialHubReplyResult(item, '', 'error', 'Slack 回复已统一到 Composio，请通过产品内已确认的 Slack 回复动作发送。', true, false);
    }
    if (item.platform === 'x') {
      return socialHubReplyResult(item, '', 'error', 'X 私信回复尚未通过 Composio 接通；当前只支持读取私信和公开 post 搜索。', true, false);
    }
    return socialHubReplyResult(item, '', 'error', '当前平台还不支持直接回复。', true, false);
  }
}
