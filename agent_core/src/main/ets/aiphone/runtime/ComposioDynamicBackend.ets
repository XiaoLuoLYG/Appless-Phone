import { ComposioConfig } from '../../composio/ComposioConfig';
import { ComposioSessionClient, proxyToolkitAccountsFromAuthConfigs } from '../../composio/ComposioSessionClient';
import { A2uiLabelValueData } from './A2uiTypes';
import {
  dynamicCompoundControlPrefix,
  dynamicMutationActionPrefix,
  isDynamicCompoundControlToken,
  isDynamicMutationActionToken,
  isUnsafeMcpTool,
  normalizedDynamicToolTokens
} from './DynamicToolRegistry';
import { DynamicGenericToolResult, dynamicReceiptFromProviderPayload } from './DynamicToolTypes';

interface ComposioExecuteArgs {
  operation?: string;
  toolSlug?: string;
  arguments?: Object;
  fixedToolId?: string;
  fixedArgs?: Object;
}

export interface ComposioRawExecution {
  toolSlug: string;
  observation: string;
}

export interface ComposioSearchTool {
  toolSlug?: string;
  description?: string;
  inputSchema?: string;
  outputSchema?: string;
}

export interface ComposioSearchExecuteClient {
  search(useCase: string): Promise<string>;
  execute(toolSlug: string, args: Object): Promise<string>;
}

interface ComposioSearchObservation {
  source?: string;
  authorizedToolkits?: string[];
  tools?: Object[];
  instruction?: string;
}

interface ComposioInputSchemaProperty {
  type?: string;
  default?: Object | string | number | boolean | null;
  enum?: string[];
  description?: string;
}

interface ComposioInputSchema {
  required?: string[];
  properties?: Record<string, ComposioInputSchemaProperty>;
}

interface ComposioArrayHit {
  found: boolean;
  label: string;
  items: Object[];
}

interface FixedArgumentAlias {
  source: string;
  targets: string[];
}

let composioConfig: ComposioConfig = new ComposioConfig('', 'https://backend.composio.dev/api/v3.1', '', '', '');
let composioClient: ComposioSessionClient | null = null;
let scopedComposioClients: Map<string, ComposioSessionClient> = new Map();
let runtimeComposioUserId: string = '';

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

function argumentRecord(value: Object | null | undefined): Record<string, Object | string | number | boolean | null | undefined> {
  if (value === undefined || value === null || Array.isArray(value) || typeof value !== 'object') {
    return {};
  }
  return value as Record<string, Object | string | number | boolean | null | undefined>;
}

function hasMeaningfulValue(value: Object | string | number | boolean | null | undefined): boolean {
  if (value === undefined || value === null) {
    return false;
  }
  if (typeof value === 'string') {
    return value.trim().length > 0;
  }
  if (Array.isArray(value)) {
    for (let index = 0; index < value.length; index++) {
      if (hasMeaningfulValue(value[index] as Object | string | number | boolean | null | undefined)) {
        return true;
      }
    }
    return false;
  }
  return true;
}

function parsedExecuteArgs(args: Object | null): ComposioExecuteArgs {
  if (args === null) {
    return {};
  }
  return args as ComposioExecuteArgs;
}

function composioToolSchema(rawSchema: string | undefined): Object {
  const raw = textOf(rawSchema).trim();
  if (raw.length === 0) {
    return new Object();
  }
  try {
    return JSON.parse(raw) as Object;
  } catch (_error) {
    return new Object();
  }
}

function slugContainsAny(slug: string, parts: string[]): boolean {
  for (let index = 0; index < parts.length; index++) {
    if (slug.indexOf(parts[index]) >= 0) {
      return true;
    }
  }
  return false;
}

function isSafeGmailDraftMutationSlug(slug: string): boolean {
  return slugContainsAny(slug, ['draft']) &&
    !slugContainsAny(slug, ['send', 'delete', 'publish', 'remove']);
}

function isSafeGmailDraftCreateSlug(slug: string): boolean {
  return isSafeGmailDraftMutationSlug(slug) &&
    slugContainsAny(slug, ['create', 'upsert', 'save']) &&
    !slugContainsAny(slug, ['update', 'edit', 'apply']);
}

function isSafeGmailDraftApplySlug(slug: string): boolean {
  return slug.trim().toLowerCase() === 'gmail_update_draft';
}

function rowsForSearch(payload: ComposioSearchObservation): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  const toolkits = Array.isArray(payload.authorizedToolkits) ? payload.authorizedToolkits.join(', ') : '';
  if (toolkits.length > 0) {
    rows.push({ label: '授权 Toolkit', value: toolkits });
  }
  if (Array.isArray(payload.tools)) {
    payload.tools.forEach((item: Object) => {
      const tool = item as ComposioSearchTool;
      rows.push({
        label: textOf(tool.toolSlug),
        value: textOf(tool.description).substring(0, 240)
      });
    });
  }
  return rows;
}

function lowerText(value: string): string {
  return value.toLowerCase();
}

function containsAny(value: string, needles: string[]): boolean {
  const lower = lowerText(value);
  for (let index = 0; index < needles.length; index++) {
    if (lower.indexOf(lowerText(needles[index])) >= 0) {
      return true;
    }
  }
  return false;
}

function composioToolkitFromPrompt(prompt: string): string {
  const lower = prompt.toLowerCase();
  if (lower.indexOf('composio twitter') >= 0 || lower.indexOf('composio x') >= 0) {
    return 'twitter';
  }
  if (lower.indexOf('composio slack') >= 0) {
    return 'slack';
  }
  if (lower.indexOf('composio discord') >= 0) {
    return 'discord';
  }
  if (lower.indexOf('composio linkedin') >= 0) {
    return 'linkedin';
  }
  if (lower.indexOf('composio whatsapp') >= 0 || lower.indexOf('composio whats app') >= 0) {
    return 'whatsapp';
  }
  if (lower.indexOf('composio instagram') >= 0 || lower.indexOf('composio instgram') >= 0) {
    return 'instagram';
  }
  if (lower.indexOf('gmail') >= 0 || prompt.indexOf('谷歌邮箱') >= 0 || prompt.indexOf('谷歌邮件') >= 0) {
    return 'gmail';
  }
  if (lower.indexOf('google calendar') >= 0 || lower.indexOf('calendar') >= 0 || prompt.indexOf('谷歌日历') >= 0) {
    return 'googlecalendar';
  }
  if (lower.indexOf('youtube') >= 0 || prompt.indexOf('油管') >= 0) {
    return 'youtube';
  }
  if (lower.indexOf('google drive') >= 0) {
    return 'googledrive';
  }
  if (lower.indexOf('google docs') >= 0 || lower.indexOf('google doc') >= 0) {
    return 'googledocs';
  }
  if (lower.indexOf('outlook') >= 0 || lower.indexOf('微软邮箱') >= 0) {
    return 'outlook';
  }
  if (lower.indexOf('slack') >= 0) {
    return 'slack';
  }
  if (lower.indexOf('discord') >= 0) {
    return 'discord';
  }
  if (lower.indexOf('linkedin') >= 0 || prompt.indexOf('领英') >= 0) {
    return 'linkedin';
  }
  if (lower.indexOf('whatsapp') >= 0 || lower.indexOf('whats app') >= 0) {
    return 'whatsapp';
  }
  if (lower.indexOf('instagram') >= 0 || lower.indexOf('instgram') >= 0 || lower.indexOf(' ig ') >= 0) {
    return 'instagram';
  }
  if (lower.indexOf('twitter') >= 0 || lower.indexOf(' x ') >= 0 || lower.indexOf('x/twitter') >= 0) {
    return 'twitter';
  }
  if (lower.indexOf('spotify') >= 0 || lower.indexOf('soptify') >= 0) {
    return 'spotify';
  }
  if (lower.indexOf('tiktok') >= 0 || lower.indexOf('tik tok') >= 0) {
    return 'tiktok';
  }
  if (lower.indexOf('ticketmaster') >= 0 || lower.indexOf('ticket master') >= 0) {
    return 'ticketmaster';
  }
  if (lower.indexOf('hacker news') >= 0 || lower.indexOf('hackernews') >= 0 || prompt.indexOf('黑客新闻') >= 0) {
    return 'hackernews';
  }
  if (lower.indexOf('reddit') >= 0 || prompt.indexOf('红迪') >= 0) {
    return 'reddit';
  }
  if (lower.indexOf('github') >= 0) {
    return 'github';
  }
  if (lower.indexOf('notion') >= 0) {
    return 'notion';
  }
  if (lower.indexOf('linear') >= 0) {
    return 'linear';
  }
  if (lower.indexOf('asana') >= 0) {
    return 'asana';
  }
  if (lower.indexOf('trello') >= 0) {
    return 'trello';
  }
  if (lower.indexOf('hubspot') >= 0) {
    return 'hubspot';
  }
  if (lower.indexOf('salesforce') >= 0) {
    return 'salesforce';
  }
  return '';
}

function promptSearchKeyword(prompt: string): string {
  const trimmed = prompt.trim();
  const mentionedIndex = trimmed.indexOf('提到');
  if (mentionedIndex >= 0) {
    let result = trimmed.substring(mentionedIndex + 2).trim();
    const endIndex = result.indexOf('的消息');
    if (endIndex >= 0) {
      result = result.substring(0, endIndex).trim();
    }
    if (result.length > 0) {
      return result;
    }
  }
  const findIndex = trimmed.lastIndexOf('找');
  if (findIndex >= 0) {
    const result = trimmed.substring(findIndex + 1).trim();
    if (result.length > 0) {
      return result;
    }
  }
  const searchIndex = trimmed.lastIndexOf('查');
  if (searchIndex >= 0) {
    const result = trimmed.substring(searchIndex + 1).trim();
    if (result.length > 0) {
      return result;
    }
  }
  return trimmed;
}

function isoDateDaysAgo(days: number): string {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString().substring(0, 10);
}

export function slackSearchQueryForPrompt(prompt: string): string {
  const keyword = promptSearchKeyword(prompt).trim();
  if (prompt.indexOf('提到') >= 0 && keyword.length > 0) {
    return keyword;
  }
  if (containsAny(prompt, ['最近30', '最近 30', '近30', '近 30', '私信', '消息', 'dm', 'direct message'])) {
    return 'after:' + isoDateDaysAgo(30);
  }
  return keyword;
}

function repoNameFromPrompt(prompt: string): string {
  if (prompt.indexOf('Appless-Phone') >= 0) {
    return 'Appless-Phone';
  }
  return '';
}

function ownerNameFromPrompt(prompt: string): string {
  if (prompt.indexOf('XiaoLuoLYG/Appless-Phone') >= 0 || prompt.indexOf('Appless-Phone') >= 0) {
    return 'XiaoLuoLYG';
  }
  return '';
}

export function normalizedComposioUseCase(prompt: string, fixedToolId: string = ''): string {
  const keyword = promptSearchKeyword(prompt);
  const toolkit = composioToolkitFromPrompt(prompt);
  if (fixedToolId === 'social.x.profile') {
    return 'Get authenticated X Twitter user profile';
  }
  if (fixedToolId === 'social.x.dm.list') {
    return 'List recent X Twitter direct message events';
  }
  if (fixedToolId === 'social.slack.message.search') {
    return 'Search recent Slack direct messages';
  }
  if (fixedToolId === 'social.slack.message.send') {
    return 'Reply to a Slack message in its thread';
  }
  if (fixedToolId === 'social.instagram.conversations.list') {
    return 'List Instagram messaging conversations';
  }
  if (fixedToolId === 'social.instagram.profile') {
    return 'Get authenticated Instagram user profile';
  }
  if (fixedToolId === 'social.instagram.messages.list') {
    return 'List messages in an Instagram conversation';
  }
  if (fixedToolId === 'whatsapp.phone_numbers.list') {
    return 'List WhatsApp Business phone numbers for the authenticated account';
  }
  if (fixedToolId === 'whatsapp.message.send') {
    return 'Send a WhatsApp Business text message';
  }
  if (fixedToolId === 'calendar.events.search') {
    return 'List Google Calendar events';
  }
  if (fixedToolId === 'calendar.event.create') {
    return 'Create a Google Calendar event';
  }
  if (fixedToolId === 'calendar.event.update') {
    return 'Patch a Google Calendar event';
  }
  if (fixedToolId === 'calendar.event.delete') {
    return 'Delete a Google Calendar event by event ID';
  }
  if (fixedToolId === 'youtube.mine.playlists') {
    return 'List my YouTube playlists for the authenticated user';
  }
  if (fixedToolId === 'youtube.mine.subscriptions') {
    return 'List my YouTube subscriptions for the authenticated user';
  }
  if (fixedToolId === 'gmail.draft.create' || fixedToolId === 'gmail.draft.apply') {
    return fixedToolId === 'gmail.draft.apply' ?
      'Update an existing Gmail draft for review' : 'Create a Gmail draft for review';
  }
  if (fixedToolId === 'gmail.reply.send') {
    return 'Reply to an existing Gmail thread';
  }
  if (fixedToolId === 'gmail.thread.read') {
    return 'Read the full Gmail thread content by thread ID';
  }
  if (toolkit === 'gmail') {
    return 'Search Gmail messages for ' + keyword;
  }
  if (toolkit === 'googlecalendar') {
    return 'Search Google Calendar events for ' + keyword;
  }
  if (toolkit === 'youtube') {
    return 'List YouTube account data or search YouTube for ' + keyword;
  }
  if (toolkit === 'twitter') {
    return 'Search X Twitter posts or direct messages for ' + keyword;
  }
  if (toolkit === 'outlook') {
    return 'Search Outlook mail messages for ' + keyword;
  }
  if (toolkit === 'discord') {
    return 'Search Discord messages mentioning ' + keyword;
  }
  if (toolkit === 'linkedin') {
    return 'Find LinkedIn profile or post information about ' + keyword;
  }
  if (toolkit === 'whatsapp') {
    return 'Search WhatsApp messages mentioning ' + keyword;
  }
  if (toolkit === 'instagram') {
    return 'Search Instagram messages, comments, or media about ' + keyword;
  }
  if (toolkit === 'spotify') {
    return 'Search Spotify tracks, albums, or playlists for ' + keyword;
  }
  if (toolkit === 'tiktok') {
    return 'Search TikTok videos for ' + keyword;
  }
  if (toolkit === 'ticketmaster') {
    return 'Search Ticketmaster events for ' + keyword;
  }
  if (toolkit === 'hackernews') {
    return 'Search Hacker News posts for ' + keyword;
  }
  if (toolkit === 'reddit') {
    return 'Search Reddit posts for ' + keyword;
  }
  if (containsAny(prompt, ['slack']) && containsAny(prompt, ['最近30', '最近 30', '近30', '近 30', '私信', 'dm', 'direct message'])) {
    return 'List recent Slack direct messages and channel messages from the last 30 days';
  }
  if (containsAny(prompt, ['slack']) && containsAny(prompt, ['消息', 'message', 'mention', '提到'])) {
    return 'Search Slack messages mentioning ' + slackSearchQueryForPrompt(prompt);
  }
  if (containsAny(prompt, ['github']) && containsAny(prompt, ['pr', 'pull request', 'pull requests'])) {
    const owner = ownerNameFromPrompt(prompt);
    const repo = repoNameFromPrompt(prompt);
    const repoText = owner.length > 0 && repo.length > 0 ? owner + '/' + repo : (repo.length > 0 ? repo : keyword);
    return 'Find recent pull requests for GitHub repository ' + repoText;
  }
  if (containsAny(prompt, ['google drive'])) {
    return 'Find Google Drive files named or containing ' + keyword;
  }
  if (containsAny(prompt, ['google docs', 'google doc'])) {
    return 'Search Google Docs documents for ' + keyword;
  }
  return prompt;
}

function fixedToolAllowsSideEffectSlug(fixedToolId: string, slug: string): boolean {
  if (fixedToolId === 'gmail.draft.create') {
    return isSafeGmailDraftCreateSlug(slug);
  }
  if (fixedToolId === 'gmail.draft.apply') {
    return isSafeGmailDraftApplySlug(slug);
  }
  if (fixedToolId === 'gmail.reply.send') {
    return slug === 'gmail_reply_to_thread';
  }
  if (fixedToolId === 'calendar.event.create') {
    return slug === 'googlecalendar_create_event';
  }
  if (fixedToolId === 'calendar.event.update') {
    return slug === 'googlecalendar_patch_event';
  }
  if (fixedToolId === 'calendar.event.delete') {
    return slug === 'googlecalendar_delete_event';
  }
  if (fixedToolId === 'whatsapp.message.send') {
    return slug === 'whatsapp_send_message';
  }
  if (fixedToolId === 'social.slack.message.send') {
    return slug === 'slack_chat_post_message';
  }
  return false;
}

function fixedArgumentAliases(toolId: string): FixedArgumentAlias[] {
  if (toolId === 'gmail.mail.search') {
    return [
      { source: 'query', targets: ['query', 'q', 'search', 'keyword'] },
      { source: 'pageSize', targets: ['pageSize', 'page_size', 'limit', 'count', 'maxResults', 'max_results'] }
    ];
  }
  if (toolId === 'gmail.thread.read') {
    return [{ source: 'threadId', targets: ['threadId', 'thread_id', 'id'] }];
  }
  if (toolId === 'gmail.draft.create' || toolId === 'gmail.draft.apply') {
    return [
      { source: 'draftId', targets: ['draft_id', 'draftId'] },
      { source: 'to', targets: ['to', 'to_addresses', 'recipients', 'emails'] },
      { source: 'recipientEmail', targets: ['recipient_email'] },
      { source: 'subject', targets: ['subject', 'title'] },
      { source: 'body', targets: ['body', 'message', 'content', 'text'] },
      { source: 'threadId', targets: ['threadId', 'thread_id'] },
      { source: 'replyMode', targets: ['replyMode', 'reply_mode', 'mode'] }
    ];
  }
  if (toolId === 'gmail.reply.send') {
    return [
      { source: 'recipientEmail', targets: ['recipient_email'] },
      { source: 'body', targets: ['message_body', 'body', 'message'] },
      { source: 'threadId', targets: ['thread_id', 'threadId'] }
    ];
  }
  if (toolId === 'calendar.events.search') {
    return [
      { source: 'query', targets: ['query', 'q', 'search', 'keyword'] },
      { source: 'timeRange', targets: ['timeRange', 'time_range'] },
      { source: 'timeMin', targets: ['timeMin', 'time_min', 'start', 'startDateTime', 'start_time'] },
      { source: 'timeMax', targets: ['timeMax', 'time_max', 'end', 'endDateTime', 'end_time'] },
      { source: 'timezone', targets: ['timezone', 'timeZone'] },
      { source: 'calendarId', targets: ['calendarId', 'calendar_id'] }
    ];
  }
  if (toolId === 'calendar.event.create' || toolId === 'calendar.event.update') {
    return [
      { source: 'eventId', targets: ['eventId', 'event_id', 'id'] },
      { source: 'title', targets: ['title', 'summary', 'name'] },
      { source: 'start', targets: ['start_datetime', 'start', 'startDateTime', 'start_time', 'startTime'] },
      { source: 'end', targets: ['end_datetime', 'end', 'endDateTime', 'end_time', 'endTime'] },
      { source: 'timezone', targets: ['timezone', 'timeZone'] },
      { source: 'calendarId', targets: ['calendarId', 'calendar_id'] }
    ];
  }
  if (toolId === 'calendar.event.delete') {
    return [
      { source: 'eventId', targets: ['event_id', 'eventId', 'id'] },
      { source: 'calendarId', targets: ['calendar_id', 'calendarId'] },
      { source: 'sendUpdates', targets: ['send_updates', 'sendUpdates'] }
    ];
  }
  if (toolId === 'whatsapp.phone_numbers.list') {
    return [
      { source: 'wabaId', targets: ['waba_id'] }
    ];
  }
  if (toolId === 'whatsapp.message.send') {
    return [
      { source: 'phoneNumberId', targets: ['phone_number_id'] },
      { source: 'toNumber', targets: ['to_number'] },
      { source: 'text', targets: ['text'] },
      { source: 'previewUrl', targets: ['preview_url'] }
    ];
  }
  if (toolId === 'social.x.dm.list') {
    return [
      { source: 'maxResults', targets: ['max_results', 'maxResults'] },
      { source: 'expansions', targets: ['expansions'] },
      { source: 'eventTypes', targets: ['event_types'] },
      { source: 'userFields', targets: ['user_fields'] },
      { source: 'dmEventFields', targets: ['dm_event_fields'] }
    ];
  }
  if (toolId === 'social.x.profile') {
    return [
      { source: 'userFields', targets: ['user_fields'] }
    ];
  }
  if (toolId === 'social.slack.message.search') {
    return [
      { source: 'query', targets: ['query'] },
      { source: 'sort', targets: ['sort'] },
      { source: 'count', targets: ['count'] }
    ];
  }
  if (toolId === 'social.slack.message.send') {
    return [
      { source: 'channel', targets: ['channel'] },
      { source: 'text', targets: ['text'] },
      { source: 'threadTs', targets: ['thread_ts'] }
    ];
  }
  if (toolId === 'social.instagram.conversations.list') {
    return [
      { source: 'limit', targets: ['limit'] }
    ];
  }
  if (toolId === 'social.instagram.profile') {
    return [
      { source: 'igUserId', targets: ['ig_user_id'] }
    ];
  }
  if (toolId === 'social.instagram.messages.list') {
    return [
      { source: 'conversationId', targets: ['conversation_id'] },
      { source: 'limit', targets: ['limit'] }
    ];
  }
  if (toolId === 'x.post.search') {
    return [
      { source: 'query', targets: ['query', 'q', 'search', 'keyword'] },
      { source: 'pageSize', targets: ['pageSize', 'page_size', 'limit', 'count', 'maxResults'] }
    ];
  }
  return [];
}

function fixedWritePreservedArgs(toolId: string): string[] {
  if (toolId === 'gmail.draft.create') {
    return ['to', 'subject', 'body', 'threadId', 'replyMode'];
  }
  if (toolId === 'gmail.draft.apply') {
    return ['draftId', 'to', 'subject', 'body', 'threadId'];
  }
  if (toolId === 'gmail.reply.send') {
    return ['recipientEmail', 'body', 'threadId'];
  }
  if (toolId === 'calendar.event.create' || toolId === 'calendar.event.update') {
    return ['eventId', 'title', 'start', 'end', 'timezone', 'calendarId'];
  }
  if (toolId === 'calendar.event.delete') {
    return ['eventId', 'calendarId', 'sendUpdates'];
  }
  if (toolId === 'whatsapp.message.send') {
    return ['phoneNumberId', 'toNumber', 'text', 'previewUrl'];
  }
  if (toolId === 'social.slack.message.send') {
    return ['channel', 'text', 'threadTs'];
  }
  return [];
}

function shouldPreserveMissingFixedWriteArg(toolId: string, targetName: string): boolean {
  const preserved = fixedWritePreservedArgs(toolId);
  if (preserved.length === 0) {
    return false;
  }
  const aliases = fixedArgumentAliases(toolId);
  for (let index = 0; index < aliases.length; index++) {
    const alias = aliases[index];
    if (preserved.indexOf(alias.source) < 0) {
      continue;
    }
    if (alias.source === targetName || alias.targets.indexOf(targetName) >= 0) {
      return true;
    }
  }
  return false;
}

function missingFixedWriteArgs(fixedToolId: string, fixedArgs: Object | null): string[] {
  const record = argumentRecord(fixedArgs);
  if (fixedToolId === 'gmail.draft.create') {
    const missing: string[] = [];
    ['to', 'body'].forEach((name: string) => {
      if (!hasMeaningfulValue(record[name])) {
        missing.push(name);
      }
    });
    return missing;
  }
  if (fixedToolId === 'gmail.draft.apply') {
    const missing: string[] = [];
    ['draftId', 'to', 'body'].forEach((name: string) => {
      if (!hasMeaningfulValue(record[name])) {
        missing.push(name);
      }
    });
    return missing;
  }
  if (fixedToolId === 'gmail.reply.send') {
    const missing: string[] = [];
    ['threadId', 'recipientEmail', 'body'].forEach((name: string) => {
      if (!hasMeaningfulValue(record[name])) {
        missing.push(name);
      }
    });
    return missing;
  }
  if (fixedToolId === 'calendar.event.create') {
    const missing: string[] = [];
    ['title', 'start', 'end'].forEach((name: string) => {
      if (!hasMeaningfulValue(record[name])) {
        missing.push(name);
      }
    });
    return missing;
  }
  if (fixedToolId === 'calendar.event.update') {
    const missing: string[] = [];
    if (!hasMeaningfulValue(record.eventId)) {
      missing.push('eventId');
    }
    if (!hasMeaningfulValue(record.title) && !hasMeaningfulValue(record.start) && !hasMeaningfulValue(record.end)) {
      missing.push('title/start/end');
    }
    return missing;
  }
  if (fixedToolId === 'calendar.event.delete') {
    return hasMeaningfulValue(record.eventId) ? [] : ['eventId'];
  }
  if (fixedToolId === 'whatsapp.message.send') {
    const missing: string[] = [];
    ['phoneNumberId', 'toNumber', 'text'].forEach((name: string) => {
      if (!hasMeaningfulValue(record[name])) {
        missing.push(name);
      }
    });
    return missing;
  }
  if (fixedToolId === 'social.slack.message.send') {
    const missing: string[] = [];
    ['channel', 'text'].forEach((name: string) => {
      if (!hasMeaningfulValue(record[name])) {
        missing.push(name);
      }
    });
    return missing;
  }
  return [];
}

export function composioExactToolSlugForFixedTool(fixedToolId: string): string {
  if (fixedToolId === 'social.x.profile') return 'TWITTER_USER_LOOKUP_ME';
  if (fixedToolId === 'social.x.dm.list') return 'TWITTER_GET_RECENT_DM_EVENTS';
  if (fixedToolId === 'social.slack.message.search') return 'SLACK_SEARCH_MESSAGES';
  if (fixedToolId === 'social.slack.message.send') return 'SLACK_CHAT_POST_MESSAGE';
  if (fixedToolId === 'social.instagram.profile') return 'INSTAGRAM_GET_USER_INFO';
  if (fixedToolId === 'social.instagram.conversations.list') return 'INSTAGRAM_LIST_ALL_CONVERSATIONS';
  if (fixedToolId === 'social.instagram.messages.list') return 'INSTAGRAM_LIST_ALL_MESSAGES';
  if (fixedToolId === 'whatsapp.phone_numbers.list') return 'WHATSAPP_GET_PHONE_NUMBERS';
  if (fixedToolId === 'whatsapp.message.send') return 'WHATSAPP_SEND_MESSAGE';
  if (fixedToolId === 'calendar.events.search') return 'GOOGLECALENDAR_EVENTS_LIST';
  if (fixedToolId === 'calendar.event.create') return 'GOOGLECALENDAR_CREATE_EVENT';
  if (fixedToolId === 'calendar.event.update') return 'GOOGLECALENDAR_PATCH_EVENT';
  if (fixedToolId === 'calendar.event.delete') return 'GOOGLECALENDAR_DELETE_EVENT';
  if (fixedToolId === 'gmail.reply.send') return 'GMAIL_REPLY_TO_THREAD';
  if (fixedToolId === 'gmail.draft.apply') return 'GMAIL_UPDATE_DRAFT';
  return '';
}

function missingFixedWriteArgsResult(
  prompt: string,
  fixedToolId: string,
  missing: string[]
): DynamicGenericToolResult {
  const rows: A2uiLabelValueData[] = [{ label: 'Tool ID', value: fixedToolId }];
  missing.forEach((name: string) => rows.push({ label: 'Missing', value: name }));
  return {
    sourceTag: 'Composio',
    toolName: fixedToolId,
    title: resultTitleForPrompt(prompt) + ' 参数不完整',
    status: 'error',
    summary: '缺少字段：' + missing.join(', ') + '。固定写工具不会从 prompt 补全这些参数。',
    rows: rows,
    rawPreview: prompt.substring(0, 16000)
  };
}

function mergeFixedArguments(
  target: Record<string, Object | string | number | boolean>,
  schema: ComposioInputSchema,
  fixedToolId: string,
  fixedArgs: Object | null
): void {
  if (fixedToolId.length === 0 || fixedArgs === null) {
    return;
  }
  const record = argumentRecord(fixedArgs);
  if (fixedToolId === 'calendar.events.search' && !schemaHasProperties(schema)) {
    const names: string[][] = [
      ['query', 'q'],
      ['timeMin', 'timeMin'],
      ['timeMax', 'timeMax'],
      ['timezone', 'timeZone'],
      ['calendarId', 'calendarId']
    ];
    names.forEach((pair: string[]) => {
      const value = record[pair[0]];
      if (hasMeaningfulValue(value)) {
        target[pair[1]] = value as Object | string | number | boolean;
      }
    });
    target.singleEvents = true;
    target.orderBy = 'startTime';
    return;
  }
  fixedArgumentAliases(fixedToolId).forEach((alias: FixedArgumentAlias) => {
    const value = record[alias.source];
    const explicitEmptyQuery = alias.source === 'query' && value === '';
    if (!hasMeaningfulValue(value) && !explicitEmptyQuery) {
      return;
    }
    alias.targets.forEach((targetName: string) => setIfSupported(target, schema, targetName, value as Object | string | number | boolean));
    setIfSupported(target, schema, alias.source, value as Object | string | number | boolean);
  });
}

export function composioPreferredToolScore(prompt: string, tool: ComposioSearchTool, fixedToolId: string = ''): number {
  const slug = textOf(tool.toolSlug).toLowerCase();
  const description = textOf(tool.description).toLowerCase();
  if (slug.length === 0 ||
    (isUnsafeComposioExecute(slug, '{}') && !fixedToolAllowsSideEffectSlug(fixedToolId, slug))) {
    return -10000;
  }
  let score = 0;
  const sideEffectSlug = slugContainsAny(slug, ['send', 'delete', 'publish', 'post_tweet', 'create', 'update', 'insert', 'draft', 'patch', 'edit']);
  if (slug.indexOf('search') >= 0 || slug.indexOf('find') >= 0) {
    score += 24;
  }
  if (slug.indexOf('list') >= 0 || slug.indexOf('get') >= 0 || slug.indexOf('fetch') >= 0 || slug.indexOf('retrieve') >= 0) {
    score += 8;
  }
  if (description.indexOf('search') >= 0 || description.indexOf('find') >= 0) {
    score += 6;
  }
  const toolkit = composioToolkitFromPrompt(prompt);
  if (toolkit.length > 0 && slug.indexOf(toolkit) >= 0) {
    score += 160;
  }
  if ((toolkit === 'gmail' || toolkit === 'googlecalendar' || toolkit === 'youtube' || toolkit === 'twitter') &&
    (slug.indexOf('search') >= 0 || slug.indexOf('list') >= 0 || slug.indexOf('get') >= 0 || slug.indexOf('message') >= 0)) {
    score += 90;
  }
  if (sideEffectSlug && !fixedToolAllowsSideEffectSlug(fixedToolId, slug)) {
    score -= 700;
  }
  if (fixedToolId === 'gmail.mail.search' &&
    (slugContainsAny(slug, ['search', 'find', 'list']) && slugContainsAny(slug, ['gmail', 'mail', 'message', 'thread']))) {
    score += 260;
  }
  if (fixedToolId === 'gmail.mail.search' && slug === 'gmail_fetch_emails') {
    score += 500;
  }
  if (fixedToolId === 'gmail.mail.search' &&
    slugContainsAny(slug, ['people', 'person', 'contact', 'profile'])) {
    score -= 800;
  }
  if (fixedToolId === 'gmail.thread.read' &&
    (slugContainsAny(slug, ['get', 'read', 'fetch']) && slugContainsAny(slug, ['gmail', 'thread', 'message']))) {
    score += 400;
  }
  if (fixedToolId === 'gmail.thread.read' && slug === 'gmail_fetch_message_by_thread_id') {
    score += 1000;
  }
  if (fixedToolId === 'gmail.thread.read' && slug === 'gmail_fetch_emails') {
    score -= 900;
  }
  if (fixedToolId === 'gmail.draft.create' && isSafeGmailDraftCreateSlug(slug)) {
    score += 700;
  }
  if (fixedToolId === 'gmail.draft.apply' && isSafeGmailDraftApplySlug(slug)) {
    score += 700;
  }
  if (fixedToolId === 'gmail.reply.send' && slug === 'gmail_reply_to_thread') {
    score += 1200;
  }
  if (fixedToolId === 'calendar.events.search' &&
    (slugContainsAny(slug, ['search', 'find', 'list', 'get']) && slugContainsAny(slug, ['calendar', 'event']))) {
    score += 400;
  }
  if (fixedToolId === 'calendar.event.create' &&
    (slugContainsAny(slug, ['create', 'insert', 'add']) && slugContainsAny(slug, ['calendar', 'event']))) {
    score += 700;
  }
  if (fixedToolId === 'calendar.event.update' &&
    (slugContainsAny(slug, ['update', 'patch', 'edit']) && slugContainsAny(slug, ['calendar', 'event']))) {
    score += 700;
  }
  if (fixedToolId === 'youtube.mine.playlists' &&
    (slugContainsAny(slug, ['playlist']) && slugContainsAny(slug, ['list', 'get', 'search']))) {
    score += 400;
  }
  if (fixedToolId === 'youtube.mine.playlists' &&
    (slug.indexOf('user_playlist') >= 0 || slug.indexOf('user_playlists') >= 0 ||
      slug.indexOf('my_playlist') >= 0 || description.indexOf('user playlist') >= 0)) {
    score += 700;
  }
  if (fixedToolId === 'youtube.mine.playlists' &&
    (slug.indexOf('playlist_item') >= 0 || slug.indexOf('playlist_items') >= 0 ||
      description.indexOf('playlist item') >= 0)) {
    score -= 700;
  }
  if (fixedToolId === 'youtube.mine.subscriptions' &&
    (slugContainsAny(slug, ['subscription']) && slugContainsAny(slug, ['list', 'get', 'search']))) {
    score += 400;
  }
  if (fixedToolId === 'x.post.search' &&
    (slugContainsAny(slug, ['search', 'find', 'list']) && slugContainsAny(slug, ['twitter', 'tweet', 'post', 'x_']))) {
    score += 400;
  }
  if (toolkit === 'outlook' && (slug.indexOf('mail') >= 0 || slug.indexOf('message') >= 0 || description.indexOf('mail') >= 0)) {
    score += 90;
  }
  if ((toolkit === 'discord' || toolkit === 'whatsapp' || toolkit === 'instagram') &&
    (slug.indexOf('message') >= 0 || slug.indexOf('comment') >= 0 || description.indexOf('message') >= 0)) {
    score += 80;
  }
  if (toolkit === 'spotify' && (slug.indexOf('track') >= 0 || slug.indexOf('playlist') >= 0 || slug.indexOf('album') >= 0)) {
    score += 70;
  }
  if (toolkit === 'tiktok' && slug.indexOf('video') >= 0) {
    score += 70;
  }
  if (toolkit === 'ticketmaster' && (slug.indexOf('event') >= 0 || description.indexOf('event') >= 0)) {
    score += 80;
  }
  if (toolkit === 'hackernews') {
    if (slug === 'hackernews_search_posts') {
      score += 220;
    }
    if (slug.indexOf('search') >= 0 && (slug.indexOf('post') >= 0 || description.indexOf('post') >= 0)) {
      score += 80;
    }
  }
  if (toolkit === 'reddit') {
    if (slug === 'reddit_search_across_subreddits') {
      score += 260;
    }
    if (slug === 'reddit_search_posts') {
      score += 240;
    }
    if (slug.indexOf('post') >= 0 || description.indexOf('post') >= 0) {
      score += 120;
    }
    if (slug === 'reddit_get_r_top' || slug === 'reddit_retrieve_reddit_post') {
      score -= 260;
    }
    if (slug.indexOf('subreddit') >= 0 && slug !== 'reddit_search_across_subreddits' && slug.indexOf('post') < 0) {
      score -= 180;
    }
  }
  if (containsAny(prompt, ['github']) && containsAny(prompt, ['pr', 'pull request', 'pull requests'])) {
    if (slug === 'github_find_pull_requests') {
      score += 200;
    }
    if (slug.indexOf('pull_request') >= 0) {
      score += 80;
    }
  }
  if (containsAny(prompt, ['google drive'])) {
    if (slug === 'googledrive_find_file') {
      score += 200;
    }
  }
  if (containsAny(prompt, ['google docs', 'google doc'])) {
    if (slug === 'googledocs_search_documents') {
      score += 200;
    }
  }
  if (containsAny(prompt, ['slack']) && containsAny(prompt, ['消息', 'message', 'mention', '提到'])) {
    if (slug === 'slack_search_messages') {
      score += 220;
    }
    if (slug.indexOf('message') >= 0 || slug.indexOf('history') >= 0) {
      score += 80;
    }
    if (slug.indexOf('team') >= 0 || slug.indexOf('channel') >= 0 || slug.indexOf('auth') >= 0) {
      score -= 80;
    }
  }
  return score;
}

function bestToolForPrompt(payload: ComposioSearchObservation, prompt: string, fixedToolId: string = ''): ComposioSearchTool | null {
  if (!Array.isArray(payload.tools) || payload.tools.length === 0) {
    return null;
  }
  const exactSlug = composioExactToolSlugForFixedTool(fixedToolId).toLowerCase();
  if (exactSlug.length > 0) {
    for (let index = 0; index < payload.tools.length; index++) {
      const exactTool = payload.tools[index] as ComposioSearchTool;
      if (textOf(exactTool.toolSlug).trim().toLowerCase() === exactSlug) {
        return exactTool;
      }
    }
    return null;
  }
  let best: ComposioSearchTool | null = null;
  let bestScore = -10000;
  payload.tools.forEach((item: Object) => {
    const tool = item as ComposioSearchTool;
    const score = composioPreferredToolScore(prompt, tool, fixedToolId);
    if (score > bestScore) {
      bestScore = score;
      best = tool;
    }
  });
  return bestScore > 0 ? best : null;
}

function firstToolSlug(payload: ComposioSearchObservation): string {
  if (!Array.isArray(payload.tools) || payload.tools.length === 0) {
    return '';
  }
  return textOf((payload.tools[0] as ComposioSearchTool).toolSlug);
}

function parsedInputSchema(raw: string): ComposioInputSchema {
  try {
    return JSON.parse(raw.length > 0 ? raw : '{}') as ComposioInputSchema;
  } catch (_error) {
    return {};
  }
}

function propertyNames(schema: ComposioInputSchema): string[] {
  const properties = schema.properties ?? {};
  return Object.keys(properties);
}

function hasProperty(schema: ComposioInputSchema, name: string): boolean {
  const properties = schema.properties ?? {};
  return properties[name] !== undefined;
}

function schemaHasProperties(schema: ComposioInputSchema): boolean {
  const properties = schema.properties ?? {};
  return Object.keys(properties).length > 0;
}

function setIfSupported(
  target: Record<string, Object | string | number | boolean>,
  schema: ComposioInputSchema,
  name: string,
  value: Object | string | number | boolean
): void {
  if (!schemaHasProperties(schema) || hasProperty(schema, name)) {
    target[name] = value;
  }
}

function isPaginationTokenName(name: string): boolean {
  const lower = name.toLowerCase();
  return lower.indexOf('token') >= 0 || lower.indexOf('cursor') >= 0;
}

function isOpaqueIdentifierName(name: string): boolean {
  const lower = name.toLowerCase();
  return lower === 'id' || lower.endsWith('_id') || lower.endsWith('id');
}

function driveQueryFor(keyword: string): string {
  const escaped = keyword.replace(/'/g, "\\'");
  return "name contains '" + escaped + "' and trashed = false";
}

function specialArgumentsForTool(toolSlug: string, prompt: string, schema: ComposioInputSchema): Record<string, Object | string | number | boolean> {
  const lower = toolSlug.toLowerCase();
  const keyword = promptSearchKeyword(prompt);
  const args: Record<string, Object | string | number | boolean> = {};
  if (lower === 'github_find_pull_requests') {
    setIfSupported(args, schema, 'owner', ownerNameFromPrompt(prompt));
    setIfSupported(args, schema, 'repo', repoNameFromPrompt(prompt));
    setIfSupported(args, schema, 'state', 'all');
    setIfSupported(args, schema, 'sort', 'updated');
    setIfSupported(args, schema, 'order', 'desc');
    setIfSupported(args, schema, 'page', 1);
    setIfSupported(args, schema, 'per_page', 5);
    setIfSupported(args, schema, 'limit', 5);
    return args;
  }
  if (lower === 'googledrive_find_file') {
    setIfSupported(args, schema, 'q', driveQueryFor(keyword));
    setIfSupported(args, schema, 'pageSize', 5);
    setIfSupported(args, schema, 'page_size', 5);
    setIfSupported(args, schema, 'fields', 'files(id,name,mimeType,webViewLink,modifiedTime),nextPageToken');
    return args;
  }
  if (lower === 'googledocs_search_documents') {
    setIfSupported(args, schema, 'query', keyword);
    setIfSupported(args, schema, 'order_by', 'modifiedTime desc');
    setIfSupported(args, schema, 'max_results', 5);
    setIfSupported(args, schema, 'limit', 5);
    setIfSupported(args, schema, 'page_size', 5);
    return args;
  }
  if (lower === 'gmail_fetch_emails') {
    setIfSupported(args, schema, 'query', keyword);
    setIfSupported(args, schema, 'max_results', 5);
    setIfSupported(args, schema, 'include_payload', false);
    setIfSupported(args, schema, 'verbose', true);
    return args;
  }
  if (lower === 'slack_search_messages') {
    setIfSupported(args, schema, 'query', slackSearchQueryForPrompt(prompt));
    setIfSupported(args, schema, 'sort', 'timestamp');
    setIfSupported(args, schema, 'count', 5);
    return args;
  }
  if (lower === 'hackernews_search_posts') {
    setIfSupported(args, schema, 'query', keyword);
    setIfSupported(args, schema, 'size', 5);
    setIfSupported(args, schema, 'page', 0);
    return args;
  }
  if (lower === 'reddit_search_across_subreddits') {
    setIfSupported(args, schema, 'search_query', keyword);
    setIfSupported(args, schema, 'query', keyword);
    setIfSupported(args, schema, 'limit', 5);
    setIfSupported(args, schema, 'count', 5);
    return args;
  }
  const toolkit = composioToolkitFromPrompt(prompt);
  if (toolkit === 'outlook' || toolkit === 'discord' || toolkit === 'linkedin' || toolkit === 'whatsapp' ||
    toolkit === 'instagram' || toolkit === 'spotify' || toolkit === 'tiktok' || toolkit === 'ticketmaster' ||
    toolkit === 'reddit') {
    setIfSupported(args, schema, 'query', keyword);
    setIfSupported(args, schema, 'q', keyword);
    setIfSupported(args, schema, 'search', keyword);
    setIfSupported(args, schema, 'keyword', keyword);
    setIfSupported(args, schema, 'limit', 5);
    setIfSupported(args, schema, 'count', 5);
    setIfSupported(args, schema, 'page_size', 5);
    setIfSupported(args, schema, 'pageSize', 5);
    return args;
  }
  return args;
}

function fallbackValueForProperty(name: string, property: ComposioInputSchemaProperty, prompt: string): Object | string | number | boolean {
  const lower = name.toLowerCase();
  const keyword = promptSearchKeyword(prompt);
  if (property.default !== undefined && property.default !== null) {
    return property.default;
  }
  if (property.enum !== undefined && property.enum.length > 0) {
    if (property.enum.indexOf('desc') >= 0 && lower.indexOf('order') >= 0) {
      return 'desc';
    }
    if (property.enum.indexOf('updated') >= 0 && lower.indexOf('sort') >= 0) {
      return 'updated';
    }
    if (property.enum.indexOf('timestamp') >= 0 && lower.indexOf('sort') >= 0) {
      return 'timestamp';
    }
    return property.enum[0];
  }
  if (lower === 'query' || lower === 'q' || lower.indexOf('search') >= 0 || lower.indexOf('keyword') >= 0) {
    return keyword;
  }
  if (lower.indexOf('repo') >= 0) {
    return repoNameFromPrompt(prompt);
  }
  if (lower.indexOf('owner') >= 0) {
    return ownerNameFromPrompt(prompt);
  }
  if (lower.indexOf('limit') >= 0 || lower.indexOf('count') >= 0 || lower.indexOf('page_size') >= 0 || lower.indexOf('pagesize') >= 0) {
    return 5;
  }
  if (lower === 'page') {
    return 1;
  }
  if (property.type === 'integer' || property.type === 'number') {
    return 5;
  }
  if (property.type === 'boolean') {
    return false;
  }
  if (property.type === 'array') {
    return [];
  }
  return keyword.length > 0 ? keyword : prompt;
}

export function composioArgumentsForTool(
  tool: ComposioSearchTool,
  prompt: string,
  fixedToolId: string = '',
  fixedArgs: Object | null = null
): Object {
  const schema = parsedInputSchema(textOf(tool.inputSchema));
  const slug = textOf(tool.toolSlug).trim();
  const args = specialArgumentsForTool(slug, prompt, schema);
  mergeFixedArguments(args, schema, fixedToolId, fixedArgs);
  const properties = schema.properties ?? {};
  const names = propertyNames(schema);
  names.forEach((name: string) => {
    if (args[name] !== undefined) {
      return;
    }
    const lower = name.toLowerCase();
    if (isPaginationTokenName(lower)) {
      return;
    }
    if (lower === 'query' || lower === 'q' || lower.indexOf('search') >= 0 || lower.indexOf('keyword') >= 0 ||
      lower.indexOf('limit') >= 0 || lower.indexOf('count') >= 0 ||
      lower.indexOf('page_size') >= 0 || lower.indexOf('pagesize') >= 0 || lower === 'page' ||
      lower.indexOf('sort') >= 0 || lower.indexOf('order') >= 0) {
      args[name] = fallbackValueForProperty(name, properties[name], prompt);
    }
  });
  const required = schema.required ?? [];
  required.forEach((name: string) => {
    if (args[name] === undefined && shouldPreserveMissingFixedWriteArg(fixedToolId, name)) {
      return;
    }
    if (args[name] === undefined && isOpaqueIdentifierName(name)) {
      return;
    }
    if (args[name] === undefined && properties[name] !== undefined) {
      args[name] = fallbackValueForProperty(name, properties[name], prompt);
    }
  });
  return args;
}

function appendRow(rows: A2uiLabelValueData[], label: string, value: string): void {
  const clean = value.trim();
  if (label.trim().length === 0 || clean.length === 0) {
    return;
  }
  rows.push({ label: label, value: clean.substring(0, 360) });
}

function stringField(record: Record<string, Object | string | number | boolean | null | undefined>, names: string[]): string {
  for (let index = 0; index < names.length; index++) {
    const value = record[names[index]];
    const text = textOf(value).trim();
    if (text.length > 0) {
      return text;
    }
  }
  return '';
}

function nestedStringField(record: Record<string, Object | string | number | boolean | null | undefined>, names: string[]): string {
  const direct = stringField(record, names);
  if (direct.length > 0 && direct.charAt(0) !== '{') {
    return direct;
  }
  for (let index = 0; index < names.length; index++) {
    const value = record[names[index]];
    if (value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value)) {
      const nested = value as Record<string, Object | string | number | boolean | null | undefined>;
      const text = stringField(nested, ['login', 'name', 'display_name', 'real_name', 'username', 'id']);
      if (text.length > 0) {
        return text;
      }
    }
  }
  return '';
}

function itemTitle(item: Object, index: number): string {
  const wrapper = item as Record<string, Object | string | number | boolean | null | undefined>;
  const record = objectRecord(wrapper.data) || wrapper;
  const title = stringField(record, ['title', 'name', 'subject', 'filename', 'file_name', 'display_name', 'event_name']);
  if (title.length > 0) {
    return title;
  }
  const text = stringField(record, ['text', 'message', 'body', 'snippet', 'content', 'description']);
  if (text.length > 0) {
    return text.substring(0, 80);
  }
  const url = stringField(record, ['url', 'html_url', 'web_url', 'webViewLink', 'permalink']);
  if (url.length > 0) {
    return url;
  }
  return '结果 ' + (index + 1).toString();
}

function itemDetail(item: Object): string {
  const wrapper = item as Record<string, Object | string | number | boolean | null | undefined>;
  const record = objectRecord(wrapper.data) || wrapper;
  const parts: string[] = [];
  const number = stringField(record, ['number', 'id']);
  if (number.length > 0) {
    parts.push('#' + number);
  }
  const state = stringField(record, ['state', 'status', 'mimeType']);
  if (state.length > 0) {
    parts.push(state);
  }
  const author = nestedStringField(record, ['author', 'user', 'from', 'owner', 'sender', 'creator', 'artist']);
  if (author.length > 0) {
    parts.push(author);
  }
  const time = stringField(record, ['updated_at', 'updatedAt', 'modifiedTime', 'created_at', 'createdTime', 'timestamp', 'ts', 'date', 'start_time', 'startDateTime', 'receivedDateTime']);
  if (time.length > 0) {
    parts.push(time);
  }
  const channel = nestedStringField(record, ['channel', 'guild', 'server', 'conversation', 'chat', 'venue', 'location']);
  if (channel.length > 0) {
    parts.push(channel);
  }
  const url = stringField(record, ['html_url', 'url', 'web_url', 'webViewLink', 'webLink', 'permalink']);
  if (url.length > 0) {
    parts.push(url);
  }
  const image = stringField(record, ['thumbnail_pic', 'bmiddle_pic', 'original_pic', 'image', 'image_url', 'imageUrl', 'cover', 'thumbnail', 'pic', 'pics', 'images']);
  if (image.length > 0) {
    parts.push(image);
  }
  const snippet = stringField(record, ['snippet', 'text', 'message', 'body', 'content', 'description']);
  if (snippet.length > 0 && parts.join(' ').indexOf(snippet.substring(0, 40)) < 0) {
    parts.push(snippet.substring(0, 180));
  }
  return parts.join(' | ');
}

function objectItems(value: Object | string | number | boolean | null | undefined): Object[] {
  const items: Object[] = [];
  if (!Array.isArray(value)) {
    return items;
  }
  value.forEach((item: Object | string | number | boolean | null | undefined) => {
    if (item !== undefined && item !== null && typeof item === 'object') {
      items.push(item as Object);
    }
  });
  return items;
}

function arrayHit(label: string, value: Object | string | number | boolean | null | undefined): ComposioArrayHit {
  if (Array.isArray(value)) {
    return { found: true, label: label, items: objectItems(value) };
  }
  return { found: false, label: '', items: [] };
}

function firstArrayHit(value: Object | string | number | boolean | null | undefined): ComposioArrayHit {
  if (Array.isArray(value)) {
    return { found: true, label: 'items', items: objectItems(value) };
  }
  if (value === undefined || value === null || typeof value !== 'object') {
    return { found: false, label: '', items: [] };
  }
  const record = value as Record<string, Object | string | number | boolean | null | undefined>;
  const preferred = ['pull_requests', 'files', 'matches', 'items', 'results', 'documents', 'messages', 'emails', 'mails',
    'posts', 'comments', 'answers', 'articles', 'questions', 'statuses', 'feeds', 'tracks', 'playlists', 'videos', 'events'];
  for (let index = 0; index < preferred.length; index++) {
    const hit = arrayHit(preferred[index], record[preferred[index]]);
    if (hit.found) {
      return hit;
    }
  }
  const nested = ['data', 'messages', 'result', 'response'];
  for (let index = 0; index < nested.length; index++) {
    const hit = firstArrayHit(record[nested[index]]);
    if (hit.found) {
      return hit;
    }
  }
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    const hit = firstArrayHit(record[keys[index]]);
    if (hit.found) {
      return hit;
    }
  }
  return { found: false, label: '', items: [] };
}

function digitsOnly(value: string): boolean {
  if (value.length === 0) {
    return false;
  }
  for (let index = 0; index < value.length; index++) {
    const char = value.charAt(index);
    if (char < '0' || char > '9') {
      return false;
    }
  }
  return true;
}

export function composioPhoneNumberIdsFromObservation(observation: string): string[] {
  try {
    const hit = firstArrayHit(JSON.parse(observation) as Object);
    const ids: string[] = [];
    hit.items.forEach((item: Object) => {
      const record = item as Record<string, Object | string | number | boolean | null | undefined>;
      const id = textOf(record.id).trim();
      if (digitsOnly(id) && ids.indexOf(id) < 0) {
        ids.push(id);
      }
    });
    return ids;
  } catch (_error) {
    return [];
  }
}

function topLevelMessage(payload: Record<string, Object | string | number | boolean | null | undefined>): string {
  const data = payload.data;
  if (data !== undefined && data !== null && typeof data === 'object' && !Array.isArray(data)) {
    const dataRecord = data as Record<string, Object | string | number | boolean | null | undefined>;
    return stringField(dataRecord, ['composio_execution_message', 'message', 'summary']);
  }
  return stringField(payload, ['message', 'summary', 'error']);
}

function objectRecord(value: Object | string | number | boolean | null | undefined): Record<string, Object | string | number | boolean | null | undefined> | null {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, Object | string | number | boolean | null | undefined>;
  }
  if (typeof value === 'string' && value.trim().charAt(0) === '{') {
    try {
      const parsed = JSON.parse(value) as Object;
      if (typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed as Record<string, Object | string | number | boolean | null | undefined>;
      }
    } catch (_error) {
    }
  }
  return null;
}

function valueLooksLikeGmailDraft(value: Object | string | number | boolean | null | undefined): boolean {
  const record = objectRecord(value);
  if (record === null) {
    return false;
  }
  const id = stringField(record, ['id', 'draftId', 'draft_id']);
  const threadId = stringField(record, ['threadId', 'thread_id']);
  const url = stringField(record, ['display_url', 'url', 'web_url']);
  return id.length > 0 && (threadId.length > 0 || url.indexOf('mail.google.com') >= 0);
}

function successfulGmailDraftPayload(payload: Object, toolSlug: string): boolean {
  const lower = toolSlug.toLowerCase();
  if (lower.indexOf('gmail') < 0 || lower.indexOf('draft') < 0) {
    return false;
  }
  const record = payload as Record<string, Object | string | number | boolean | null | undefined>;
  return valueLooksLikeGmailDraft(record.data) || valueLooksLikeGmailDraft(record.error) || valueLooksLikeGmailDraft(record);
}

function executionStatusValue(
  record: Record<string, Object | string | number | boolean | null | undefined>,
  expected: boolean
): boolean {
  if (record.successful === expected || record.success === expected) {
    return true;
  }
  const data = record.data;
  if (data === undefined || data === null || typeof data !== 'object' || Array.isArray(data)) {
    return false;
  }
  const dataRecord = data as Record<string, Object | string | number | boolean | null | undefined>;
  return dataRecord.successful === expected || dataRecord.success === expected;
}

function nestedExecutionError(
  record: Record<string, Object | string | number | boolean | null | undefined>
): string {
  const data = record.data;
  if (data === undefined || data === null || typeof data !== 'object' || Array.isArray(data)) {
    return '';
  }
  return stringField(
    data as Record<string, Object | string | number | boolean | null | undefined>,
    ['error']
  );
}

function executionErrorMessage(payload: Object, toolSlug: string = ''): string {
  const record = payload as Record<string, Object | string | number | boolean | null | undefined>;
  if (executionStatusValue(record, false)) {
    const explicitError = stringField(record, ['error']);
    const nestedError = nestedExecutionError(record);
    return explicitError.length > 0 ? explicitError :
      (nestedError.length > 0 ? nestedError : 'Provider returned an unsuccessful execution status.');
  }
  if (successfulGmailDraftPayload(payload, toolSlug)) {
    return '';
  }
  const direct = stringField(record, ['error']);
  if (direct.length > 0) {
    return direct;
  }
  const nestedError = nestedExecutionError(record);
  if (nestedError.length > 0) {
    return nestedError;
  }
  if (executionStatusValue(record, true)) {
    return '';
  }
  if (isUnsafeComposioExecute(toolSlug, '{}')) {
    return 'Provider did not return positive execution evidence.';
  }
  const data = record.data;
  if (data !== undefined && data !== null && typeof data === 'object' && !Array.isArray(data)) {
    return stringField(data as Record<string, Object | string | number | boolean | null | undefined>, ['message']);
  }
  return '';
}

function compactNestedText(record: Record<string, Object | string | number | boolean | null | undefined>, fieldName: string): string {
  const value = record[fieldName];
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'object' && !Array.isArray(value)) {
    const nested = value as Record<string, Object | string | number | boolean | null | undefined>;
    return stringField(nested, ['body', 'text', 'snippet', 'summary', 'title', 'url']);
  }
  return textOf(value);
}

function compactComposioItem(item: Object): Object {
  const record = item as Record<string, Object | string | number | boolean | null | undefined>;
  const compact: Record<string, Object | string | number | boolean> = {};
  const fields = [
    'id', 'threadId', 'thread_id', 'messageId', 'message_id', 'display_url',
    'sender', 'from', 'to', 'subject', 'title', 'name', 'snippet',
    'messageTimestamp', 'date', 'timestamp', 'publishedAt', 'url'
  ];
  fields.forEach((name: string) => {
    const value = record[name];
    if (value !== undefined && value !== null && typeof value !== 'object') {
      compact[name] = textOf(value).substring(0, 1000);
    }
  });
  const preview = compactNestedText(record, 'preview');
  if (preview.length > 0) {
    compact.preview = preview.substring(0, 1000);
  }
  const messageText = stringField(record, ['messageText', 'text', 'description']);
  if (messageText.length > 0) {
    compact.messageText = messageText.substring(0, 1000);
  }
  const snippet = record.snippet;
  if (snippet !== undefined && snippet !== null && typeof snippet === 'object' && !Array.isArray(snippet)) {
    const snippetRecord = snippet as Record<string, Object | string | number | boolean | null | undefined>;
    const title = nestedStringField(snippetRecord, ['localized', 'title']);
    if (title.length > 0) {
      compact.title = title;
    } else {
      appendCompactString(compact, 'title', stringField(snippetRecord, ['title']));
    }
    appendCompactString(compact, 'channelTitle', stringField(snippetRecord, ['channelTitle']));
    appendCompactString(compact, 'publishedAt', stringField(snippetRecord, ['publishedAt']));
    const thumbnail = youtubeThumbnailUrl(snippetRecord);
    if (thumbnail.length > 0) {
      compact.thumbnail = thumbnail;
    }
  }
  return compact;
}

function appendCompactString(target: Record<string, Object | string | number | boolean>, key: string, value: string): void {
  const clean = value.trim();
  if (clean.length > 0 && target[key] === undefined) {
    target[key] = clean.substring(0, 1000);
  }
}

function youtubeThumbnailUrl(record: Record<string, Object | string | number | boolean | null | undefined>): string {
  const thumbnails = record.thumbnails;
  if (thumbnails === undefined || thumbnails === null || typeof thumbnails !== 'object' || Array.isArray(thumbnails)) {
    return '';
  }
  const sizes = thumbnails as Record<string, Object | string | number | boolean | null | undefined>;
  const keys = ['maxres', 'standard', 'high', 'medium', 'default'];
  for (let index = 0; index < keys.length; index++) {
    const item = sizes[keys[index]];
    if (item !== undefined && item !== null && typeof item === 'object' && !Array.isArray(item)) {
      const url = stringField(item as Record<string, Object | string | number | boolean | null | undefined>, ['url']);
      if (url.length > 0) {
        return url;
      }
    }
  }
  return '';
}

function rawPreviewForExecute(payload: Object, observation: string): string {
  const hit = firstArrayHit(payload);
  if (!hit.found) {
    return observation.substring(0, 16000);
  }
  const items: Object[] = [];
  for (let index = 0; index < hit.items.length && index < 10; index++) {
    items.push(compactComposioItem(hit.items[index]));
  }
  const compact: Record<string, Object[]> = {};
  compact[hit.label] = items;
  return JSON.stringify(compact).substring(0, 16000);
}

function rowsForExecute(payload: Object, prompt: string, toolSlug: string): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  appendRow(rows, '执行工具', toolSlug);
  appendRow(rows, '查询', promptSearchKeyword(prompt));
  const hit = firstArrayHit(payload);
  if (hit.found) {
    appendRow(rows, '结果数量', hit.items.length.toString());
    for (let index = 0; index < hit.items.length && index < 5; index++) {
      appendRow(rows, itemTitle(hit.items[index], index), itemDetail(hit.items[index]));
    }
    return rows;
  }
  const record = payload as Record<string, Object | string | number | boolean | null | undefined>;
  appendRow(rows, '结果摘要', topLevelMessage(record));
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length && rows.length < 8; index++) {
    const value = record[keys[index]];
    if (value === undefined || value === null || typeof value === 'object') {
      continue;
    }
    appendRow(rows, keys[index], textOf(value));
  }
  if (rows.length <= 2) {
    appendRow(rows, '结果数量', '0');
  }
  return rows;
}

function resultTitleForTool(toolSlug: string): string {
  const lower = toolSlug.toLowerCase();
  if (lower.indexOf('gmail') >= 0) {
    return 'Composio Gmail 结果';
  }
  if (lower.indexOf('googlecalendar') >= 0) {
    return 'Composio Google Calendar 结果';
  }
  if (lower.indexOf('youtube') >= 0) {
    return 'Composio YouTube 结果';
  }
  if (lower.indexOf('twitter') >= 0) {
    return 'Composio Twitter 结果';
  }
  if (lower.indexOf('github') >= 0) {
    return 'Composio GitHub 结果';
  }
  if (lower.indexOf('googledrive') >= 0) {
    return 'Composio Google Drive 结果';
  }
  if (lower.indexOf('googledocs') >= 0) {
    return 'Composio Google Docs 结果';
  }
  if (lower.indexOf('slack') >= 0) {
    return 'Composio Slack 结果';
  }
  if (lower.indexOf('outlook') >= 0) {
    return 'Composio Outlook 结果';
  }
  if (lower.indexOf('discord') >= 0) {
    return 'Composio Discord 结果';
  }
  if (lower.indexOf('linkedin') >= 0) {
    return 'Composio LinkedIn 结果';
  }
  if (lower.indexOf('whatsapp') >= 0) {
    return 'Composio WhatsApp 结果';
  }
  if (lower.indexOf('instagram') >= 0) {
    return 'Composio Instagram 结果';
  }
  if (lower.indexOf('spotify') >= 0) {
    return 'Composio Spotify 结果';
  }
  if (lower.indexOf('tiktok') >= 0) {
    return 'Composio TikTok 结果';
  }
  if (lower.indexOf('ticketmaster') >= 0) {
    return 'Composio Ticketmaster 结果';
  }
  if (lower.indexOf('hackernews') >= 0 || lower.indexOf('hacker_news') >= 0) {
    return 'Composio Hacker News 结果';
  }
  if (lower.indexOf('reddit') >= 0) {
    return 'Composio Reddit 结果';
  }
  return 'Composio 工具结果';
}

function resultTitleForPrompt(prompt: string): string {
  const toolkit = composioToolkitFromPrompt(prompt);
  return toolkit.length > 0 ? resultTitleForTool(toolkit) : 'Composio 工具候选';
}

function executeSummary(toolSlug: string, rows: A2uiLabelValueData[]): string {
  let count = '';
  rows.forEach((row: A2uiLabelValueData) => {
    if (row.label === '结果数量') {
      count = row.value;
    }
  });
  return count.length > 0
    ? 'Composio 已执行 ' + toolSlug + '，返回 ' + count + ' 条可展示结果。'
    : 'Composio 已执行 ' + toolSlug + '，返回真实结果。';
}

export function configureComposioConfigFromRawJson(rawJson: string): void {
  composioConfig = ComposioConfig.fromRawJson(rawJson);
  refreshComposioConnections();
}

export function refreshComposioConnections(): void {
  composioClient = null;
  scopedComposioClients.clear();
}

export function configureComposioUserId(userId: string): void {
  runtimeComposioUserId = userId.trim();
  refreshComposioConnections();
}

export function currentComposioUserId(): string {
  return runtimeComposioUserId.length > 0 ? runtimeComposioUserId : composioConfig.userId;
}

function configForCurrentUser(): ComposioConfig {
  return new ComposioConfig(
    composioConfig.apiKey,
    composioConfig.baseUrl,
    currentComposioUserId(),
    composioConfig.proxyBaseUrl,
    composioConfig.proxyApiKey
  );
}

export function currentComposioConfig(): ComposioConfig {
  return configForCurrentUser();
}

export function isComposioConfigured(): boolean {
  return composioConfig.isConfigured();
}

export function isComposioDynamicPrompt(prompt: string): boolean {
  const lower = prompt.toLowerCase();
  if (lower.indexOf('weibo') >= 0 || prompt.indexOf('微博') >= 0 ||
    lower.indexOf('zhihu') >= 0 || prompt.indexOf('知乎') >= 0) {
    return false;
  }
  return lower.indexOf('notion') >= 0 ||
    lower.indexOf('gmail') >= 0 ||
    lower.indexOf('google calendar') >= 0 ||
    lower.indexOf('calendar') >= 0 ||
    lower.indexOf('youtube') >= 0 ||
    lower.indexOf('twitter') >= 0 ||
    lower.indexOf(' x ') >= 0 ||
    lower.indexOf('x/twitter') >= 0 ||
    lower.indexOf('google drive') >= 0 ||
    lower.indexOf('google docs') >= 0 ||
    lower.indexOf('google doc') >= 0 ||
    lower.indexOf('linear') >= 0 ||
    lower.indexOf('github') >= 0 ||
    lower.indexOf('asana') >= 0 ||
    lower.indexOf('trello') >= 0 ||
    lower.indexOf('hubspot') >= 0 ||
    lower.indexOf('salesforce') >= 0 ||
    lower.indexOf('outlook') >= 0 ||
    lower.indexOf('discord') >= 0 ||
    lower.indexOf('linkedin') >= 0 ||
    lower.indexOf('whatsapp') >= 0 ||
    lower.indexOf('whats app') >= 0 ||
    lower.indexOf('instagram') >= 0 ||
    lower.indexOf('instgram') >= 0 ||
    lower.indexOf('spotify') >= 0 ||
    lower.indexOf('soptify') >= 0 ||
    lower.indexOf('tiktok') >= 0 ||
    lower.indexOf('tik tok') >= 0 ||
    lower.indexOf('ticketmaster') >= 0 ||
    lower.indexOf('ticket master') >= 0 ||
    lower.indexOf('hacker news') >= 0 ||
    lower.indexOf('hackernews') >= 0 ||
    lower.indexOf('reddit') >= 0 ||
    prompt.indexOf('黑客新闻') >= 0 ||
    prompt.indexOf('红迪') >= 0 ||
    prompt.indexOf('谷歌邮箱') >= 0 ||
    prompt.indexOf('谷歌邮件') >= 0 ||
    prompt.indexOf('谷歌日历') >= 0 ||
    prompt.indexOf('油管') >= 0 ||
    lower.indexOf('composio') >= 0;
}

export function shouldAttemptComposioDynamic(prompt: string, operation: string, _configured: boolean): boolean {
  if (operation === 'execute') {
    return isComposioDynamicPrompt(prompt);
  }
  return isComposioDynamicPrompt(prompt);
}

export function proxyToolkitAccountsPreview(payload: Object, toolkitAllowlist: string[] = []): Record<string, string> {
  return proxyToolkitAccountsFromAuthConfigs(payload, toolkitAllowlist);
}

export function isUnsafeComposioExecute(toolSlug: string, _argsJson: string): boolean {
  return isUnsafeMcpTool(toolSlug, '');
}

const SELECTED_READ_OPERATIONS: string[] = ['read', 'search', 'list', 'get'];
const SELECTED_PROVIDER_PREFIXES: string[] = [
  'googlecalendar', 'googledrive', 'googledocs', 'ticketmaster', 'hackernews', 'salesforce',
  'composio', 'instagram', 'linkedin', 'whatsapp', 'github', 'twitter', 'youtube',
  'outlook', 'discord', 'spotify', 'tiktok', 'hubspot', 'notion', 'slack', 'gmail',
  'reddit', 'linear', 'trello', 'asana', 'google', 'calendar', 'drive', 'hacker',
  'news', 'git', 'hub', 'x'
];
const SELECTED_READ_NOUNS: string[] = [
  'phonenumbers', 'pullrequests', 'subscriptions', 'conversations', 'repositories',
  'spreadsheets', 'documents', 'playlists', 'permissions', 'notifications', 'activities',
  'channels', 'messages', 'threads', 'profiles', 'statuses', 'settings', 'comments',
  'replies', 'orders', 'posts', 'tweets', 'events', 'emails', 'accounts', 'members',
  'numbers', 'repository', 'spreadsheet', 'document', 'playlist', 'permission',
  'notification', 'activity', 'channel', 'message', 'thread', 'profile', 'status',
  'event', 'email', 'account', 'member', 'phone', 'conversation', 'subscription',
  'pullrequest', 'pull', 'requests', 'videos', 'video', 'people', 'contacts', 'contact',
  'files', 'pages', 'users', 'items', 'results', 'details', 'information',
  'file', 'page', 'user', 'item', 'result', 'data', 'weather', 'forecast', 'info',
  'code', 'issues', 'issue', 'subreddits', 'subreddit', 'across', 'recent', 'all', 'mine',
  'my', 'by', 'for', 'from', 'in', 'of'
];

function stripSelectedProviderPrefixes(value: string): string {
  let remaining = value;
  let removed = true;
  while (remaining.length > 0 && removed) {
    removed = false;
    for (let index = 0; index < SELECTED_PROVIDER_PREFIXES.length; index++) {
      const prefix = SELECTED_PROVIDER_PREFIXES[index];
      if (remaining === prefix) {
        return '';
      }
      if (remaining.startsWith(prefix) && remaining.length > prefix.length) {
        remaining = remaining.substring(prefix.length);
        removed = true;
        break;
      }
    }
  }
  return remaining;
}

function selectedSemanticTokens(toolSlug: string): string[] {
  const tokens = normalizedDynamicToolTokens(toolSlug);
  while (tokens.length > 0) {
    const stripped = stripSelectedProviderPrefixes(tokens[0]);
    if (stripped.length === 0) {
      tokens.shift();
      continue;
    }
    if (stripped !== tokens[0]) {
      tokens[0] = stripped;
    }
    break;
  }
  return tokens;
}

function readNounPrefix(value: string): string {
  for (let index = 0; index < SELECTED_READ_NOUNS.length; index++) {
    if (value.startsWith(SELECTED_READ_NOUNS[index])) {
      return SELECTED_READ_NOUNS[index];
    }
  }
  return '';
}

function compactReadTailAllowed(value: string): boolean {
  let remaining = value;
  while (remaining.length > 0) {
    const noun = readNounPrefix(remaining);
    if (noun.length > 0) {
      remaining = remaining.substring(noun.length);
      continue;
    }
    if (dynamicCompoundControlPrefix(remaining).length > 0 || dynamicMutationActionPrefix(remaining).length > 0) {
      return false;
    }
    return false;
  }
  return true;
}

function compactSelectedReadOperation(value: string): string {
  for (let index = 0; index < SELECTED_READ_OPERATIONS.length; index++) {
    const operation = SELECTED_READ_OPERATIONS[index];
    if (value.length > operation.length && value.substring(0, operation.length) === operation) {
      return operation;
    }
  }
  return '';
}

function selectedSlugGrammarMessage(toolSlug: string): string {
  const semantic = selectedSemanticTokens(toolSlug);
  if (semantic.length === 0) {
    return 'Selected Composio tool has no semantic operation: ' + toolSlug + '.';
  }
  let operation = semantic[0];
  let compactTail = '';
  if (SELECTED_READ_OPERATIONS.indexOf(operation) < 0) {
    const compactOperation = compactSelectedReadOperation(operation);
    if (compactOperation.length > 0) {
      operation = compactOperation;
      compactTail = semantic[0].substring(compactOperation.length);
    }
  }
  if (SELECTED_READ_OPERATIONS.indexOf(operation) < 0) {
    return 'Selected Composio tool has an unknown operation: ' + toolSlug + '.';
  }
  if (compactTail.length > 0 && !compactReadTailAllowed(compactTail)) {
    return 'Selected Composio tool has an ambiguous compact operation: ' + toolSlug + '.';
  }
  for (let index = 1; index < semantic.length; index++) {
    const token = semantic[index];
    if (isDynamicCompoundControlToken(token)) {
      return 'Selected Composio tool is a compound operation: ' + toolSlug + '.';
    }
    if (isDynamicMutationActionToken(token)) {
      return 'Selected Composio tool is write-like: ' + toolSlug + '.';
    }
    if (SELECTED_READ_NOUNS.indexOf(token) < 0) {
      return 'Selected Composio tool has an unknown semantic token: ' + toolSlug + '.';
    }
  }
  return '';
}

function selectedSlugAuthorizationMessage(
  toolSlug: string,
  fixedToolId: string,
  allowFixedContract: boolean = false
): string {
  const lowerSlug = toolSlug.trim().toLowerCase();
  const exactFixed = composioExactToolSlugForFixedTool(fixedToolId).toLowerCase();
  if (allowFixedContract && ((exactFixed.length > 0 && lowerSlug === exactFixed) ||
    fixedToolAllowsSideEffectSlug(fixedToolId, lowerSlug))) {
    return '';
  }
  return selectedSlugGrammarMessage(toolSlug);
}

function blockedSelectedSlugResult(toolSlug: string, message: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Composio',
    toolName: toolSlug.length > 0 ? toolSlug : 'dynamic.search',
    title: 'UnsafeActionBlocked',
    status: 'unsafe_action_blocked',
    summary: message,
    rows: [
      { label: 'Blocked action', value: toolSlug.length > 0 ? toolSlug : 'unknown' },
      { label: 'Next step', value: '使用带确认流程的固定工具。' }
    ],
    rawPreview: JSON.stringify({ blocked: true, reason: 'unsafe_action_blocked', toolSlug: toolSlug }),
    providerPhase: 'discovery'
  };
}

function isXPostReadSlug(toolSlug: string): boolean {
  if (selectedSlugGrammarMessage(toolSlug).length > 0) {
    return false;
  }
  const compact = normalizedDynamicToolTokens(toolSlug).join('');
  return compact.indexOf('tweet') >= 0 || compact.indexOf('posts') >= 0 || compact.indexOf('status') >= 0;
}

function xDiscoveryFailure(prompt: string, observation: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Composio',
    toolName: 'x.post.search',
    title: 'Composio X post tool unavailable',
    status: 'error',
    summary: 'Composio discovery did not return an executable X post read tool.',
    rows: [{ label: '查询', value: promptSearchKeyword(prompt) }],
    rawPreview: observation.substring(0, 16000),
    providerPhase: 'discovery'
  };
}

export function composioDynamicMissingConfigResult(prompt: string): DynamicGenericToolResult {
  const title = composioToolkitFromPrompt(prompt).length > 0 ? resultTitleForPrompt(prompt) : 'Composio 未配置';
  const missing = composioConfig.missingConfiguration();
  const summary = 'Composio 未配置' + (missing.length > 0 ? '：' + missing : '') + '，无法查询已授权应用工具。';
  return {
    sourceTag: 'Composio',
    toolName: 'dynamic.search',
    title: title,
    status: 'needs_auth',
    summary: summary,
    rows: [
      { label: '请求', value: prompt.substring(0, 240) },
      { label: '结果摘要', value: summary }
    ],
    rawPreview: prompt
  };
}

export function composioDynamicResultFromObservation(
  phase: string,
  observation: string,
  toolSlug: string = '',
  prompt: string = ''
): DynamicGenericToolResult {
  try {
    const payload = JSON.parse(observation) as ComposioSearchObservation;
    if (phase === 'execute') {
      const errorMessage = executionErrorMessage(payload as Object, toolSlug);
      const rows = rowsForExecute(payload as Object, prompt, toolSlug.length > 0 ? toolSlug : 'dynamic.search');
      if (errorMessage.length > 0) {
        return {
          sourceTag: 'Composio',
          toolName: toolSlug.length > 0 ? toolSlug : 'dynamic.search',
          title: 'Composio 调用失败',
          status: 'error',
          summary: 'Composio 执行 ' + (toolSlug.length > 0 ? toolSlug : 'dynamic.search') + ' 失败：' + errorMessage,
          rows: rows,
          rawPreview: observation.substring(0, 16000),
          providerPhase: 'execution'
        };
      }
      return {
        sourceTag: 'Composio',
        toolName: toolSlug.length > 0 ? toolSlug : 'dynamic.search',
        title: resultTitleForTool(toolSlug),
        status: 'success',
        summary: executeSummary(toolSlug.length > 0 ? toolSlug : 'dynamic.search', rows),
        rows: rows,
        rawPreview: rawPreviewForExecute(payload as Object, observation),
        providerPhase: 'execution'
      };
    }
    const slug = firstToolSlug(payload);
    const rows = rowsForSearch(payload);
    if (prompt.length > 0) {
      appendRow(rows, '查询', promptSearchKeyword(prompt));
    }
    return {
      sourceTag: 'Composio',
      toolName: 'dynamic.search',
      title: phase === 'execute' ? 'Composio 执行结果' : resultTitleForPrompt(prompt),
      status: 'success',
      summary: slug.length > 0 ? 'Composio 找到候选工具：' + slug : 'Composio 返回了真实结果。',
      rows: rows,
      rawPreview: observation.substring(0, 16000),
      providerPhase: 'discovery'
    };
  } catch (_error) {
    const unparseableWrite = phase === 'execute' && isUnsafeComposioExecute(toolSlug, '{}');
    const failed = unparseableWrite || observation.indexOf('失败') >= 0 || observation.indexOf('错误') >= 0 ||
      observation.indexOf('未配置') >= 0 || observation.indexOf('没有') >= 0;
    const rows: A2uiLabelValueData[] = [{ label: '阶段', value: phase }];
    if (prompt.length > 0) {
      appendRow(rows, '查询', promptSearchKeyword(prompt));
    }
    appendRow(rows, '结果摘要', observation);
    return {
      sourceTag: 'Composio',
      toolName: toolSlug.length > 0 ? toolSlug : 'dynamic.search',
      title: prompt.length > 0 ? resultTitleForPrompt(prompt) : (failed ? 'Composio 调用失败' : 'Composio 返回'),
      status: failed ? 'error' : 'success',
      summary: unparseableWrite ? 'Composio 写工具返回了无法验证的非 JSON 结果。' : observation.substring(0, 240),
      rows: rows,
      rawPreview: observation.substring(0, 16000),
      providerPhase: phase === 'execute' ? 'execution' : 'discovery'
    };
  }
}

async function callComposioSearchAndExecuteParsed(
  current: ComposioSearchExecuteClient | ComposioSessionClient,
  prompt: string,
  parsed: ComposioExecuteArgs,
  allowFixedContract: boolean
): Promise<DynamicGenericToolResult> {
  const fixedToolId = textOf(parsed.fixedToolId).trim();
  const searchObservation = await current.search(normalizedComposioUseCase(prompt, fixedToolId));
  let payload: ComposioSearchObservation;
  try {
    payload = JSON.parse(searchObservation) as ComposioSearchObservation;
  } catch (_error) {
    if (fixedToolId === 'x.post.search') {
      return xDiscoveryFailure(prompt, searchObservation);
    }
    return composioDynamicResultFromObservation('search', searchObservation, '', prompt);
  }
  let tool = bestToolForPrompt(payload, prompt, fixedToolId);
  const expected = composioExactToolSlugForFixedTool(fixedToolId);
  if (tool === null && expected.length > 0) {
    return {
      sourceTag: 'Composio',
      toolName: fixedToolId,
      title: 'Composio 工具不可用',
      status: 'error',
      summary: 'Composio 没有返回必需工具 ' + expected + '。',
      rows: [{ label: 'Expected Tool', value: expected }],
      rawPreview: searchObservation.substring(0, 16000),
      providerPhase: 'discovery'
    };
  }
  if (tool === null && Array.isArray(payload.tools) && payload.tools.length === 1) {
    tool = payload.tools[0] as ComposioSearchTool;
  }
  if (tool === null) {
    if (fixedToolId === 'x.post.search') {
      return xDiscoveryFailure(prompt, searchObservation);
    }
    return composioDynamicResultFromObservation('search', searchObservation, '', prompt);
  }
  const slug = textOf(tool.toolSlug).trim();
  if (fixedToolId === 'x.post.search' && !isXPostReadSlug(slug)) {
    return xDiscoveryFailure(prompt, searchObservation);
  }
  const args = composioArgumentsForTool(tool, prompt, fixedToolId, parsed.fixedArgs ?? null);
  const authorizationMessage = selectedSlugAuthorizationMessage(slug, fixedToolId, allowFixedContract);
  if (authorizationMessage.length > 0) {
    return blockedSelectedSlugResult(slug, authorizationMessage);
  }
  const executionObservation = await current.execute(slug, args);
  const result = composioDynamicResultFromObservation('execute', executionObservation, slug, prompt);
  result.registration = {
    provider: 'Composio',
    qualifiedName: slug,
    inputSchema: composioToolSchema(tool.inputSchema),
    outputSchema: composioToolSchema(tool.outputSchema),
    receipt: dynamicReceiptFromProviderPayload(executionObservation)
  };
  return result;
}

export async function callComposioSearchAndExecute(
  current: ComposioSearchExecuteClient | ComposioSessionClient,
  prompt: string,
  requestArgs: Object | null
): Promise<DynamicGenericToolResult> {
  return callComposioSearchAndExecuteParsed(current, prompt, parsedExecuteArgs(requestArgs), false);
}

export async function callComposioFixedSearchAndExecuteForTest(
  current: ComposioSearchExecuteClient,
  prompt: string,
  fixedToolId: string,
  fixedArgs: Object
): Promise<DynamicGenericToolResult> {
  const parsed: ComposioExecuteArgs = {
    fixedToolId: fixedToolId,
    fixedArgs: fixedArgs
  };
  return callComposioSearchAndExecuteParsed(current, prompt, parsed, true);
}

export async function callComposioFixedRaw(
  prompt: string,
  fixedToolId: string,
  fixedArgs: Object
): Promise<ComposioRawExecution> {
  const current = await clientForPrompt(prompt);
  const searchObservation = await current.search(normalizedComposioUseCase(prompt, fixedToolId));
  let payload: ComposioSearchObservation;
  try {
    payload = JSON.parse(searchObservation) as ComposioSearchObservation;
  } catch (_error) {
    throw new Error('Composio returned an invalid tool search response.');
  }
  const tool = bestToolForPrompt(payload, prompt, fixedToolId);
  if (tool === null) {
    const expected = composioExactToolSlugForFixedTool(fixedToolId);
    throw new Error(expected.length > 0 ? 'Composio did not find required tool ' + expected + '.' : 'Composio did not find a matching tool.');
  }
  const toolSlug = textOf(tool.toolSlug).trim();
  const toolArgs = composioArgumentsForTool(tool, prompt, fixedToolId, fixedArgs);
  const authorizationMessage = selectedSlugAuthorizationMessage(toolSlug, fixedToolId, true);
  if (authorizationMessage.length > 0) {
    throw new Error(authorizationMessage);
  }
  const observation = await current.execute(toolSlug, toolArgs);
  const result: ComposioRawExecution = {
    toolSlug: toolSlug,
    observation: observation
  };
  return result;
}

async function client(): Promise<ComposioSessionClient> {
  if (composioClient === null) {
    composioClient = new ComposioSessionClient(configForCurrentUser());
    await composioClient.initialize();
  }
  return composioClient;
}

async function clientForPrompt(prompt: string): Promise<ComposioSessionClient> {
  const toolkit = composioToolkitFromPrompt(prompt);
  if (toolkit.length === 0) {
    return client();
  }
  let scoped = scopedComposioClients.get(toolkit);
  if (scoped === undefined) {
    scoped = new ComposioSessionClient(configForCurrentUser(), [toolkit]);
    await scoped.initialize();
    scopedComposioClients.set(toolkit, scoped);
  }
  return scoped;
}

async function callComposioParsed(
  prompt: string,
  parsed: ComposioExecuteArgs,
  allowFixedContract: boolean
): Promise<DynamicGenericToolResult | null> {
  const fixedToolId = textOf(parsed.fixedToolId).trim();
  const missingFixedArgs = missingFixedWriteArgs(fixedToolId, parsed.fixedArgs ?? null);
  if (missingFixedArgs.length > 0) {
    return missingFixedWriteArgsResult(prompt, fixedToolId, missingFixedArgs);
  }
  const operation = textOf(parsed.operation).trim();
  if (!shouldAttemptComposioDynamic(prompt, operation, composioConfig.isConfigured())) {
    return null;
  }
  if (operation === 'execute') {
    const slug = textOf(parsed.toolSlug).trim();
    const authorizationMessage = selectedSlugAuthorizationMessage(slug, fixedToolId, allowFixedContract);
    if (authorizationMessage.length > 0) {
      return blockedSelectedSlugResult(slug, authorizationMessage);
    }
  }
  if (!composioConfig.isConfigured()) {
    return composioDynamicMissingConfigResult(prompt);
  }
  const current = await clientForPrompt(prompt);
  if (operation === 'execute') {
    const slug = textOf(parsed.toolSlug).trim();
    const authorizationMessage = selectedSlugAuthorizationMessage(slug, fixedToolId, allowFixedContract);
    if (authorizationMessage.length > 0) {
      return blockedSelectedSlugResult(slug, authorizationMessage);
    }
    return composioDynamicResultFromObservation('execute', await current.execute(slug, parsed.arguments ?? new Object()), slug, prompt);
  }
  return callComposioSearchAndExecuteParsed(current, prompt, parsed, allowFixedContract);
}

export async function callComposioDynamic(prompt: string, args: Object | null): Promise<DynamicGenericToolResult | null> {
  return callComposioParsed(prompt, parsedExecuteArgs(args), false);
}

export async function callComposioFixedDynamic(
  prompt: string,
  fixedToolId: string,
  fixedArgs: Object | null
): Promise<DynamicGenericToolResult | null> {
  const parsed: ComposioExecuteArgs = {
    fixedToolId: fixedToolId,
    fixedArgs: fixedArgs ?? new Object()
  };
  return callComposioParsed(prompt, parsed, true);
}
