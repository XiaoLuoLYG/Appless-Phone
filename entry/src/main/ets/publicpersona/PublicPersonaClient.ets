import {
  A2uiMessage,
  DataResult,
  DynamicGenericToolResult,
  LocalModelSettings,
  aiLogInfo,
  callStructuredTool
} from '@loop/agent-core';
import {
  DirectModelCallResult,
  callDirectModel
} from '../model/LocalModelClient';
import {
  PublicPersonaAccountEvidence,
  PublicPersonaCandidate,
  PublicPersonaIdentity,
  PublicPersonaInference,
  PublicPersonaPlatform,
  PublicPersonaProfileUrl,
  PublicPersonaPostEvidence,
  PublicPersonaProgress,
  PublicPersonaProviderState,
  PublicPersonaSnapshot,
  PublicPersonaSourceRef,
  parsePublicPersonaInference,
  parsePublicProfileUrl,
  publicPersonaCatalog,
  publicPersonaOwnershipBand,
  renderPublicPersonaMarkdown,
  sanitizePublicPersonaSnapshot,
  scorePublicPersonaCandidate
} from './PublicPersonaModel';

export type PublicPersonaToolCaller = (
  toolId: string,
  prompt: string,
  args: Object | null
) => Promise<DataResult>;

export type PublicPersonaModelCaller = (
  settings: LocalModelSettings,
  prompt: string,
  history: A2uiMessage[],
  systemPrompt?: string
) => Promise<DirectModelCallResult>;

export type PublicPersonaProgressListener = (progress: PublicPersonaProgress) => void;

const PUBLIC_PERSONA_TOTAL: number = 11;
const MAX_PUBLIC_POSTS: number = 30;
const MAX_PROFILE_POSTS: number = 10;
const MAX_PUBLIC_PERSONA_CANDIDATES: number = 10;
const MAX_LINKED_PROFILE_URLS: number = 10;
const PUBLIC_PERSONA_PROBE_TIMEOUT_DEFAULT_MS: number = 70000;

const PUBLIC_PERSONA_SYSTEM_PROMPT: string = [
  '你正在根据用户主动提供的公开网页资料生成个人画像。',
  '只返回 PublicPersonaInference JSON，不要 Markdown，不要解释。',
  '每句话必须能被输入的公开资料支持；缺失信息使用空数组，不要猜测。',
  '每个数组最多 3 项、每项不超过 32 个字；总 JSON 不超过 800 个字，确保能完整返回。',
  'MBTI 只是可撤回的公开资料推断，不是心理测评结论。',
  '禁止推断健康、精确位置、宗教、政治立场、性取向等敏感私人信息。'
].join('\n');

type PublicPersonaRecord = Record<string, Object | string | number | boolean | Object[]>;

interface PublicPersonaReadResult {
  state: PublicPersonaProviderState;
  identity: PublicPersonaIdentity | null;
  data: PublicPersonaRecord;
}

interface PublicPersonaEvidenceResult {
  state: PublicPersonaProviderState;
  evidence: PublicPersonaAccountEvidence | null;
}

interface PublicPersonaSearchArgs {
  query: string;
  domains: string[];
  maxResults: number;
}

interface PublicPersonaPageReadArgs {
  url: string;
  question: string;
  includeFullText: boolean;
}

interface PublicPersonaXSearchArgs {
  query: string;
  pageSize: number;
}

interface PublicPersonaCompactAccount {
  platform: PublicPersonaPlatform;
  profileUrl: string;
  displayName: string;
  username: string;
  bio: string;
  posts: PublicPersonaPostEvidence[];
}

interface PublicPersonaFallbackData {
  displayName: string;
  username: string;
  avatarUrl: string;
  canonicalUrl: string;
  linkedUrls: string[];
  publicBio: string;
  sourceUrls: string[];
}

export interface PublicPersonaMbtiResult {
  mbtiType: string;
  mbtiConfidence: number;
}

interface PublicPersonaSearchRow {
  url: string;
  title: string;
  summary: string;
}

function timedOutDataResult(toolId: string): DataResult {
  return {
    toolId: toolId,
    outputSchema: 'object',
    status: 'error',
    sources: [],
    data: new Object(),
    warnings: [],
    error: { code: 'TIMEOUT', message: '公开平台探针超时' }
  };
}

async function boundedToolCall(toolId: string, request: Promise<DataResult>, timeoutMs: number): Promise<DataResult> {
  let timerId: number = -1;
  const timeout = new Promise<DataResult>((resolve: (value: DataResult) => void): void => {
    timerId = setTimeout((): void => resolve(timedOutDataResult(toolId)), timeoutMs);
  });
  try {
    return await Promise.race<DataResult>([request, timeout]);
  } finally {
    if (timerId >= 0) {
      clearTimeout(timerId);
    }
  }
}

function record(value: Object): PublicPersonaRecord {
  return value as PublicPersonaRecord;
}

function text(value: Object | string | number | boolean | undefined): string {
  return typeof value === 'string' ? value.trim() : '';
}

function number(value: Object | string | number | boolean | undefined): number {
  return typeof value === 'number' ? value : 0;
}

function strings(value: Object | string | number | boolean | undefined): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const source = value as Object[];
  const result: string[] = [];
  for (let index = 0; index < source.length; index++) {
    const item = text(source[index]);
    if (item.length > 0) {
      result.push(item);
    }
  }
  return result;
}

function dynamicResults(result: DataResult): DynamicGenericToolResult[] {
  const data = record(result.data);
  const value = data['results'];
  if (!Array.isArray(value)) {
    return [];
  }
  return value as DynamicGenericToolResult[];
}

function previewRecord(rawPreview: string): PublicPersonaRecord | null {
  const source = rawPreview.trim();
  if (source.length === 0) {
    return null;
  }
  const parseRecord = (value: string): PublicPersonaRecord | null => {
    const trimmed = value.trim();
    try {
      const parsed = JSON.parse(trimmed) as Object;
      if (typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed)) {
        return record(parsed);
      }
    } catch (_error) {
      const start = trimmed.indexOf('{');
      const end = trimmed.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          const fenced = JSON.parse(trimmed.substring(start, end + 1)) as Object;
          if (typeof fenced === 'object' && fenced !== null && !Array.isArray(fenced)) {
            return record(fenced);
          }
        } catch (_nestedError) {
          return null;
        }
      }
    }
    return null;
  };
  try {
    const direct = parseRecord(source);
    if (direct === null) {
      return null;
    }
    const answer = text(direct['answer']);
    if (answer.length > 0) {
      const nested = parseRecord(answer);
      if (nested !== null) {
        return nested;
      }
    }
    return direct;
  } catch (_error) {
    return null;
  }
}

function previewPayload(result: DataResult): PublicPersonaRecord | null {
  const results = dynamicResults(result);
  for (let index = 0; index < results.length; index++) {
    const payload = previewRecord(results[index].rawPreview);
    if (payload !== null) {
      return payload;
    }
  }
  return null;
}

function payloadData(payload: PublicPersonaRecord): PublicPersonaRecord {
  const nested = payload['data'];
  return nested !== undefined && typeof nested === 'object' && !Array.isArray(nested) ? record(nested as Object) : payload;
}

function markdownLike(value: string): boolean {
  return value.indexOf('![') >= 0 && /^#\s+/m.test(value);
}

function profileData(result: DataResult): PublicPersonaRecord {
  const payload = previewPayload(result);
  if (payload !== null) {
    const data = payloadData(payload);
    const answer = text(data['answer']) || text(payload['answer']);
    if (text(data['markdown']).length === 0 && markdownLike(answer)) {
      data['markdown'] = answer;
    }
    return data;
  }
  const data = record(result.data);
  return payloadData(data);
}

function previewMarkdown(result: DataResult): string {
  const results = dynamicResults(result);
  for (let index = 0; index < results.length; index++) {
    const raw = results[index].rawPreview.trim();
    const payload = previewRecord(raw);
    if (payload !== null) {
      const markdown = text(payloadData(payload)['markdown']) || text(payload['markdown']);
      if (markdown.length > 0) {
        return markdown;
      }
      const answer = text(payloadData(payload)['answer']) || text(payload['answer']);
      if (markdownLike(answer)) {
        return answer;
      }
    }
    if (markdownLike(raw)) {
      return raw;
    }
  }
  const data = record(result.data);
  return text(payloadData(data)['markdown']) || text(data['markdown']);
}

function markdownIdentity(markdown: string, fallbackUrl: string): PublicPersonaIdentity | null {
  const image = /!\[[^\]]*\]\((https:\/\/[^)\s]+)\)/i.exec(markdown);
  if (image === null) {
    return null;
  }
  const heading = /^#\s+(.+)$/m.exec(markdown);
  if (heading === null) {
    return null;
  }
  const parts = heading[1].trim().split(/\s{2,}/);
  let username = '';
  let displayName = '';
  if (parts.length >= 2) {
    displayName = parts[0].trim();
    username = parts[parts.length - 1].trim().replace(/^@/, '');
  } else {
    const parsed = parsePublicProfileUrl(fallbackUrl);
    const segments = parsed === null ? [] : parsed.url.split('/').filter((value: string): boolean => value.length > 0);
    username = segments.length === 0 ? '' : segments[segments.length - 1];
    displayName = parts[0].trim();
  }
  const parsedFallback = parsePublicProfileUrl(fallbackUrl);
  const canonicalUrl = parsedFallback === null ? '' : parsedFallback.url;
  if (displayName.length === 0 || username.length === 0 || canonicalUrl.length === 0) {
    return null;
  }
  return {
    displayName: displayName,
    username: username,
    avatarUrl: image[1],
    canonicalUrl: canonicalUrl,
    linkedUrls: markdownProfileLinks(markdown)
  };
}

function markdownProfileLinks(markdown: string): string[] {
  const matches = markdown.match(/https:\/\/[^\s<>()"']+/g);
  if (matches === null) {
    return [];
  }
  const links: string[] = [];
  for (let index = 0; index < matches.length; index++) {
    const parsed = parsePublicProfileUrl(matches[index].replace(/[.,;!?]+$/, ''));
    if (parsed !== null && links.indexOf(parsed.url) < 0) {
      links.push(parsed.url);
    }
  }
  return links;
}

function markdownBio(markdown: string): string {
  const lines = markdown.split(/\r?\n/);
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index].trim().replace(/^[-*]\s+/, '');
    if (line.length < 20 || line.startsWith('#') || line.startsWith('![') || line.startsWith('[')) {
      continue;
    }
    if (line.indexOf('Skip to content') >= 0 || line.indexOf('Follow') >= 0 || line.indexOf('Overview') >= 0) {
      continue;
    }
    return line;
  }
  return '';
}

function providerStateFromStatus(value: string): PublicPersonaProviderState | null {
  const status = value.trim().toLowerCase();
  if (status === 'needs_auth' || status === 'blocked_by_site' || status === 'rate_limited' ||
    status === 'credits_exhausted' || status === 'timeout' || status === 'partial' ||
    status === 'empty' || status === 'success' || status === 'error') {
    return status as PublicPersonaProviderState;
  }
  if (status.indexOf('auth') >= 0 || status.indexOf('login') >= 0) return 'needs_auth';
  if (status.indexOf('block') >= 0 || status.indexOf('robot') >= 0) return 'blocked_by_site';
  if (status.indexOf('rate') >= 0 || status.indexOf('limit') >= 0) return 'rate_limited';
  if (status.indexOf('credit') >= 0 || status.indexOf('quota') >= 0) return 'credits_exhausted';
  if (status.indexOf('timeout') >= 0) return 'timeout';
  return null;
}

function providerState(result: DataResult): PublicPersonaProviderState {
  const statuses = dynamicResults(result);
  let nestedFallback: PublicPersonaProviderState | null = null;
  let nestedProviderProblem: PublicPersonaProviderState | null = null;
  let hasSuccessLike = false;
  for (let index = 0; index < statuses.length; index++) {
    const state = providerStateFromStatus(text(record(statuses[index])['status']));
    if (state === 'success' || state === 'partial' || state === 'empty') {
      hasSuccessLike = true;
    }
    if (state !== null && nestedFallback === null) {
      nestedFallback = state;
    }
    if (state === 'needs_auth' || state === 'blocked_by_site' || state === 'rate_limited' ||
      state === 'credits_exhausted' || state === 'timeout') {
      if (nestedProviderProblem === null) {
        nestedProviderProblem = state;
      }
    }
  }
  let topState: PublicPersonaProviderState | null = null;
  if (result.error !== undefined) {
    const messageState = providerStateFromStatus(result.error.message);
    if (messageState !== null) {
      topState = messageState;
    }
    const code = result.error.code.toUpperCase();
    if (topState === null) {
      if (code.indexOf('AUTH') >= 0 || code.indexOf('LOGIN') >= 0) topState = 'needs_auth';
      else if (code.indexOf('BLOCK') >= 0 || code.indexOf('ROBOTS') >= 0) topState = 'blocked_by_site';
      else if (code.indexOf('RATE') >= 0 || code.indexOf('LIMIT') >= 0) topState = 'rate_limited';
      else if (code.indexOf('CREDIT') >= 0 || code.indexOf('QUOTA') >= 0) topState = 'credits_exhausted';
      else if (code.indexOf('TIMEOUT') >= 0) topState = 'timeout';
      else topState = 'error';
    }
  }
  if (topState === null) {
    topState = providerStateFromStatus(result.status);
  }
  if (topState !== null && topState !== 'success') {
    return topState;
  }
  if (hasSuccessLike && nestedProviderProblem !== null) return 'partial';
  if (nestedProviderProblem !== null) return nestedProviderProblem;
  if (nestedFallback !== null) return nestedFallback;
  if (topState !== null) return topState;
  return 'error';
}

function retryDelayMs(attempt: number, timeoutMs: number): number {
  return Math.min(500, Math.max(25, timeoutMs)) * (attempt + 1);
}

function sourceRows(value: Object | string | number | boolean | undefined): PublicPersonaSearchRow[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const raw = value as Object[];
  const rows: PublicPersonaSearchRow[] = [];
  const addUrl = (value: string, title: string = '', summary: string = ''): void => {
    const parsed = parsePublicProfileUrl(value);
    if (parsed === null || rows.some((row: PublicPersonaSearchRow): boolean => row.url === parsed.url)) {
      return;
    }
    rows.push({ url: parsed.url, title: title, summary: summary });
  };
  for (let index = 0; index < raw.length; index++) {
    const item = record(raw[index]);
    const url = text(item['url']);
    const title = text(item['title']);
    const summary = text(item['summary']) || text(item['description']);
    if (url.length > 0) {
      addUrl(url, title, summary);
      continue;
    }
    const itemRows = item['rows'];
    if (Array.isArray(itemRows)) {
      const labels = itemRows as Object[];
      for (let rowIndex = 0; rowIndex < labels.length; rowIndex++) {
        const labelValue = record(labels[rowIndex]);
        const label = text(labelValue['label']).toLowerCase();
        const rowUrl = text(labelValue['value']);
        if ((label === 'url' || label === 'source url' || label === 'profile url') && rowUrl.startsWith('https://')) {
          addUrl(rowUrl, title, summary);
        }
      }
    }
    const actions = item['actions'];
    if (Array.isArray(actions)) {
      const actionItems = actions as Object[];
      for (let actionIndex = 0; actionIndex < actionItems.length; actionIndex++) {
        const action = record(actionItems[actionIndex]);
        const actionId = text(action['id']);
        const args = action['args'];
        const actionArgs = args !== undefined && typeof args === 'object' && !Array.isArray(args) ? record(args as Object) : null;
        const actionUrl = actionArgs === null ? '' : text(actionArgs['url']);
        const promptUrl = text(action['prompt']);
        if (actionUrl.startsWith('https://')) {
          addUrl(actionUrl, title, summary);
        } else if ((actionId === 'web.open.source' || actionId === 'web.page.read') && promptUrl.startsWith('https://')) {
          addUrl(promptUrl, title, summary);
        }
      }
    }
  }
  return rows;
}

function fallbackAvatarUrl(platform: PublicPersonaPlatform): string {
  if (platform === 'linkedin') return 'https://www.linkedin.com/favicon.ico';
  return '';
}

function fallbackDisplayName(row: PublicPersonaSearchRow, username: string): string {
  const title = row.title.trim();
  const separators: string[] = [' - ', ' | ', ' — ', ' – '];
  for (let index = 0; index < separators.length; index++) {
    const separatorIndex = title.indexOf(separators[index]);
    if (separatorIndex > 0) {
      return title.substring(0, separatorIndex).trim();
    }
  }
  return title.length > 0 ? title : username;
}

function identitySearchQueries(identity: PublicPersonaIdentity, domains: string[]): string[] {
  const canonical = identitySearchQuery(identity, false);
  const base = identitySearchQuery(identity, true);
  const queries: string[] = [];
  if (canonical.length > 0) {
    queries.push(canonical);
  }
  const domain = domains.length === 0 ? '' : domains[0];
  if (base.length > 0 && queries.length < 2) {
    queries.push(domain.length > 0 ? 'site:' + domain + ' ' + base : base);
  }
  return queries.length > 0 ? queries : [domain.length > 0 ? 'site:' + domain : ''];
}

function profileIdentity(result: DataResult, fallbackUrl: string = ''): PublicPersonaIdentity | null {
  const data = profileData(result);
  const identity: PublicPersonaIdentity = {
    displayName: text(data['displayName']),
    username: text(data['username']).replace(/^@/, ''),
    avatarUrl: text(data['avatarUrl']),
    canonicalUrl: text(data['canonicalUrl']),
    linkedUrls: strings(data['linkedUrls'])
  };
  if (identity.displayName.length === 0 || identity.username.length === 0 ||
    !identity.avatarUrl.startsWith('https://') || identity.avatarUrl.indexOf(' ') >= 0 || identity.avatarUrl.indexOf('\n') >= 0 ||
    parsePublicProfileUrl(identity.canonicalUrl) === null) {
    return markdownIdentity(previewMarkdown(result), fallbackUrl);
  }
  return identity;
}

function postEvidence(value: Object | string | number | boolean | undefined, limit: number = MAX_PUBLIC_POSTS): PublicPersonaPostEvidence[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const raw = value as Object[];
  const posts: PublicPersonaPostEvidence[] = [];
  const seenUrls: string[] = [];
  for (let index = 0; index < raw.length && posts.length < limit; index++) {
    const item = record(raw[index]);
    const url = text(item['url']);
    if (url.length === 0 || !url.startsWith('https://')) {
      continue;
    }
    if (seenUrls.indexOf(url) >= 0) {
      continue;
    }
    seenUrls.push(url);
    posts.push({
      url: url,
      title: text(item['title']),
      text: text(item['text']),
      publishedAt: text(item['publishedAt']),
      pinned: item['pinned'] === true
    });
  }
  return posts;
}

function profileBio(data: PublicPersonaRecord, markdown: string): string {
  return text(data['bio']) || text(data['publicBio']) || markdownBio(markdown);
}

function profilePosts(data: PublicPersonaRecord): PublicPersonaPostEvidence[] {
  const items: Object[] = [];
  const keys: string[] = ['posts', 'pinnedPosts', 'latestPosts'];
  for (let keyIndex = 0; keyIndex < keys.length; keyIndex++) {
    const value = data[keys[keyIndex]];
    if (!Array.isArray(value)) {
      continue;
    }
    const raw = value as Object[];
    for (let index = 0; index < raw.length; index++) {
      items.push(raw[index]);
    }
  }
  return postEvidence(items, MAX_PROFILE_POSTS);
}

function uniqueUrls(values: string[]): string[] {
  const result: string[] = [];
  for (let index = 0; index < values.length; index++) {
    const value = values[index];
    if (value.startsWith('https://') && result.indexOf(value) < 0) {
      result.push(value);
    }
  }
  return result;
}

function safeProgress(listener: PublicPersonaProgressListener, progress: PublicPersonaProgress): void {
  try {
    listener(progress);
  } catch (_error) {
  }
}

function profileReadArgs(url: string, fullText: boolean): PublicPersonaPageReadArgs {
  return {
    url: url,
    question: fullText ?
      'In the answer field, return a JSON string with public bio, pinned posts and latest posts. Each post needs url/title/text/publishedAt/pinned. Return at most 10 posts.' :
      'In the answer field, return a JSON string only with fields displayName, username, avatarUrl, canonicalUrl, linkedUrls. Do not infer missing values.',
    includeFullText: fullText
  };
}

function linkedProfileUrl(value: string): PublicPersonaProfileUrl | null {
  const trimmed = value.trim();
  const queryIndex = trimmed.indexOf('?');
  const hashIndex = trimmed.indexOf('#');
  let end = trimmed.length;
  if (queryIndex >= 0) {
    end = queryIndex;
  }
  if (hashIndex >= 0 && hashIndex < end) {
    end = hashIndex;
  }
  return parsePublicProfileUrl(trimmed.substring(0, end));
}

function identitySearchQuery(identity: PublicPersonaIdentity, includeUsername: boolean = true): string {
  const aliases: string[] = [];
  const addAlias = (value: string): void => {
    const alias = value.toLowerCase().replace(/[^a-z0-9\u4e00-\u9fff]/g, '');
    if (alias.length > 1 && aliases.indexOf(alias) < 0) {
      aliases.push(alias);
    }
  };
  if (includeUsername) {
    addAlias(identity.username.replace(/^@/, ''));
  }
  const tokens = identity.displayName.toLowerCase().split(/[^a-z0-9\u4e00-\u9fff]+/).filter((token: string): boolean => token.length > 1);
  addAlias(tokens.join(''));
  addAlias(tokens.slice().reverse().join(''));
  return aliases.join(' OR ');
}

function compactEvidence(accounts: PublicPersonaAccountEvidence[]): Object[] {
  return accounts.map((account: PublicPersonaAccountEvidence): Object => {
    const compact: PublicPersonaCompactAccount = {
    platform: account.platform,
    profileUrl: account.profileUrl,
    displayName: account.displayName,
    username: account.username,
    bio: account.bio,
    posts: account.posts
    };
    return compact as Object;
  });
}

function accountSource(account: PublicPersonaAccountEvidence): PublicPersonaSourceRef {
  return {
    platform: account.platform,
    profileUrl: account.profileUrl,
    avatarUrl: account.avatarUrl,
    sourceUrls: account.sourceUrls,
    fetchedAt: account.fetchedAt
  };
}

function candidateId(platform: PublicPersonaPlatform, identity: PublicPersonaIdentity): string {
  return platform + ':' + identity.username.toLowerCase();
}

function dateNow(): string {
  return new Date().toISOString();
}

export class PublicPersonaClient {
  private toolCaller: PublicPersonaToolCaller;
  private modelCaller: PublicPersonaModelCaller;
  private now: () => string;
  private probeTimeoutMs: number;

  constructor(
    toolCaller: PublicPersonaToolCaller = callStructuredTool,
    modelCaller: PublicPersonaModelCaller = callDirectModel,
    now: () => string = dateNow,
    probeTimeoutMs: number = PUBLIC_PERSONA_PROBE_TIMEOUT_DEFAULT_MS
  ) {
    this.toolCaller = toolCaller;
    this.modelCaller = modelCaller;
    this.now = now;
    this.probeTimeoutMs = probeTimeoutMs;
  }

  private async recoverLinkedInProfile(url: string): Promise<PublicPersonaReadResult> {
    const parsed = parsePublicProfileUrl(url);
    if (parsed === null || parsed.platform !== 'linkedin') {
      return { state: 'error', identity: null, data: record(new Object()) };
    }
    const username = parsed.url.substring(parsed.url.lastIndexOf('/') + 1);
    const queries: string[] = [parsed.url, 'site:linkedin.com/in/' + username];
    let last: DataResult = timedOutDataResult('web.research.search');
    for (let index = 0; index < queries.length; index++) {
      const searchArgs: PublicPersonaSearchArgs = {
        query: queries[index], domains: ['linkedin.com'], maxResults: 3
      };
      last = await boundedToolCall('web.research.search', this.toolCaller(
        'web.research.search', '读取公开搜索索引中的 LinkedIn 个人主页摘要。', searchArgs as Object), this.probeTimeoutMs);
      const state = providerState(last);
      if (state !== 'empty' && state !== 'rate_limited') {
        break;
      }
    }
    const rows = sourceRows(record(last.data)['results']);
    const row = rows.find((item: PublicPersonaSearchRow): boolean => {
      const candidate = parsePublicProfileUrl(item.url);
      return candidate !== null && candidate.platform === 'linkedin' &&
        candidate.url.toLowerCase().indexOf('/in/' + username.toLowerCase()) >= 0;
    });
    if (row === undefined) {
      return { state: providerState(last), identity: null, data: record(new Object()) };
    }
    const canonical = parsePublicProfileUrl(row.url);
    if (canonical === null) {
      return { state: 'empty', identity: null, data: record(new Object()) };
    }
    const identity: PublicPersonaIdentity = {
      displayName: fallbackDisplayName(row, username),
      username: username,
      avatarUrl: fallbackAvatarUrl('linkedin'),
      canonicalUrl: canonical.url,
      linkedUrls: []
    };
    const fallbackData: PublicPersonaFallbackData = {
      displayName: identity.displayName,
      username: identity.username,
      avatarUrl: identity.avatarUrl,
      canonicalUrl: identity.canonicalUrl,
      linkedUrls: [],
      publicBio: row.summary,
      sourceUrls: [canonical.url]
    };
    const data: PublicPersonaRecord = fallbackData as Object as PublicPersonaRecord;
    return { state: 'partial', identity: identity, data: data };
  }

  private async readProfile(url: string, fullText: boolean): Promise<PublicPersonaReadResult> {
    let result: DataResult = timedOutDataResult('web.page.read');
    let state: PublicPersonaProviderState = 'error';
    for (let attempt = 0; attempt < 3; attempt++) {
      result = await boundedToolCall('web.page.read', this.toolCaller('web.page.read', fullText ?
        '读取已确认的公开个人主页内容。' : '读取公开个人主页的可核验元数据。', profileReadArgs(url, fullText) as Object), this.probeTimeoutMs);
      state = providerState(result);
      if (state !== 'rate_limited' || attempt >= 2) {
        break;
      }
      await new Promise<void>((resolve: () => void): void => {
        setTimeout(resolve, retryDelayMs(attempt, this.probeTimeoutMs));
      });
    }
    const data = profileData(result);
    const markdown = previewMarkdown(result);
    if (text(data['markdown']).length === 0 && markdown.length > 0) {
      data['markdown'] = markdown;
    }
    const results = dynamicResults(result);
    let rawPreviewChars = 0;
    for (let index = 0; index < results.length; index++) {
      rawPreviewChars += results[index].rawPreview.length;
    }
    let identity = state === 'success' ? profileIdentity(result, url) : null;
    if (identity === null && parsePublicProfileUrl(url)?.platform === 'linkedin') {
      const fallback = await this.recoverLinkedInProfile(url);
      if (fallback.identity !== null) {
        return fallback;
      }
    }
    aiLogInfo('[AIPhone][PublicPersonaEnvelope] state=' + state +
      ' results=' + results.length.toString() + ' rawPreviewChars=' + rawPreviewChars.toString() +
      ' displayNameChars=' + (identity === null ? '0' : identity.displayName.length.toString()) +
      ' usernameChars=' + (identity === null ? '0' : identity.username.length.toString()));
    return {
      state: state,
      identity: identity,
      data: data
    };
  }

  async discover(
    profileUrl: string,
    onProgress: PublicPersonaProgressListener
  ): Promise<PublicPersonaCandidate[]> {
    const parsedSeed = parsePublicProfileUrl(profileUrl);
    const probes = publicPersonaCatalog();
    const candidates: PublicPersonaCandidate[] = [];
    if (parsedSeed === null) {
      return candidates;
    }
    const anchor = await this.readProfile(parsedSeed.url, false);
    const seed = anchor.identity;
    if (seed === null) {
      for (let index = 0; index < probes.length; index++) {
        safeProgress(onProgress, { completed: index + 1, total: PUBLIC_PERSONA_TOTAL, platform: probes[index].platform, state: anchor.state, message: '无法读取公开主页' });
      }
      return candidates;
    }
    const anchorCandidate: PublicPersonaCandidate = {
      id: candidateId(parsedSeed.platform, seed),
      platform: parsedSeed.platform,
      profileUrl: parsedSeed.url,
      displayName: seed.displayName,
      username: seed.username,
      avatarUrl: seed.avatarUrl,
      exists: true,
      ownershipConfidence: 1,
      ownershipBand: 'high',
      selected: true,
      providerState: anchor.state,
      fetchedAt: this.now(),
      sourceUrl: parsedSeed.url
    };
    candidates.push(anchorCandidate);
    const acceptCandidate = (platform: PublicPersonaPlatform, read: PublicPersonaReadResult, linked: boolean): void => {
      if (read.identity === null || (read.state !== 'success' && !(linked && read.state === 'partial'))) {
        return;
      }
      const canonical = linked ? linkedProfileUrl(read.identity.canonicalUrl) : parsePublicProfileUrl(read.identity.canonicalUrl);
      if (canonical === null || canonical.platform !== platform) {
        return;
      }
      const confidence = linked ? 1 : scorePublicPersonaCandidate(seed, read.identity);
      const band = publicPersonaOwnershipBand(confidence);
      if (band === null) {
        return;
      }
      const exists = candidates.some((item: PublicPersonaCandidate): boolean => item.profileUrl === canonical.url);
      if (exists) {
        return;
      }
      candidates.push({
        id: candidateId(platform, read.identity),
        platform: platform,
        profileUrl: canonical.url,
        displayName: read.identity.displayName,
        username: read.identity.username,
        avatarUrl: read.identity.avatarUrl,
        exists: true,
        ownershipConfidence: confidence,
        ownershipBand: band,
        selected: band === 'high',
        providerState: read.state,
        fetchedAt: this.now(),
        sourceUrl: canonical.url
      });
    };
    const linkedUrls = seed.linkedUrls.slice(0, MAX_LINKED_PROFILE_URLS);
    for (let index = 0; index < linkedUrls.length; index++) {
      const linked = linkedProfileUrl(linkedUrls[index]);
      if (linked === null) {
        continue;
      }
      const read = await this.readProfile(linked.url, false);
      acceptCandidate(linked.platform, read, true);
    }
    let completed = 0;
    let nextProbe = 0;
    const runProbe = async (): Promise<void> => {
      while (true) {
        const index = nextProbe++;
        if (index >= probes.length) {
          return;
        }
        const probe = probes[index];
        safeProgress(onProgress, { completed: completed, total: PUBLIC_PERSONA_TOTAL, platform: probe.platform, state: 'running', message: '正在查找' + probe.label + '公开主页' });
        if (probe.platform === parsedSeed.platform) {
          completed++;
          safeProgress(onProgress, { completed: completed, total: PUBLIC_PERSONA_TOTAL, platform: probe.platform, state: 'success', message: '已确认公开主页' });
          continue;
        }
        let terminal: PublicPersonaProviderState = 'empty';
        try {
          let search: DataResult = timedOutDataResult('web.research.search');
          const queries = identitySearchQueries(seed, probe.domains);
          for (let queryIndex = 0; queryIndex < queries.length; queryIndex++) {
            const searchArgs: PublicPersonaSearchArgs = {
              query: queries[queryIndex],
              domains: probe.domains,
              maxResults: MAX_PUBLIC_PERSONA_CANDIDATES
            };
            for (let attempt = 0; attempt < 3; attempt++) {
              search = await boundedToolCall('web.research.search', this.toolCaller('web.research.search', '查找同一公开身份在指定平台的公开个人主页。', searchArgs as Object), this.probeTimeoutMs);
              terminal = providerState(search);
              if (terminal !== 'rate_limited' || attempt >= 2) {
                break;
              }
              await new Promise<void>((resolve: () => void): void => {
                setTimeout(resolve, retryDelayMs(attempt, this.probeTimeoutMs));
              });
            }
            if (terminal !== 'empty' && terminal !== 'rate_limited') {
              break;
            }
          }
          terminal = providerState(search);
          if (terminal === 'success' || terminal === 'partial') {
            const rows = sourceRows(record(search.data)['results']).slice(0, MAX_PUBLIC_PERSONA_CANDIDATES);
            const readUrls: string[] = [];
            for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
              const candidateUrl = parsePublicProfileUrl(rows[rowIndex].url);
              if (candidateUrl === null || candidateUrl.platform !== probe.platform) {
                continue;
              }
              if (readUrls.indexOf(candidateUrl.url) >= 0) {
                continue;
              }
              readUrls.push(candidateUrl.url);
              const read = await this.readProfile(candidateUrl.url, false);
              if (read.state !== 'success' && terminal === 'success') {
                terminal = read.state;
              }
              acceptCandidate(probe.platform, read, false);
            }
          }
        } catch (_error) {
          terminal = 'error';
        }
        completed++;
        const hasCandidate = candidates.some((item: PublicPersonaCandidate): boolean => item.platform === probe.platform);
        aiLogInfo('[AIPhone][PublicPersonaProbe] platform=' + probe.platform +
          ' state=' + terminal + ' confirmed=' + (hasCandidate ? 'true' : 'false'));
        safeProgress(onProgress, { completed: completed, total: PUBLIC_PERSONA_TOTAL, platform: probe.platform, state: terminal, message: hasCandidate ? '已确认公开主页' : '没有确认的公开主页' });
      }
    };
    const workers: Promise<void>[] = [];
    const workerCount = 1;
    for (let index = 0; index < workerCount; index++) {
      workers.push(runProbe());
    }
    await Promise.all(workers);
    const anchorResult = candidates[0];
    const ranked = candidates.slice(1).sort((left: PublicPersonaCandidate, right: PublicPersonaCandidate): number => {
      return right.ownershipConfidence - left.ownershipConfidence;
    });
    return [anchorResult].concat(ranked).slice(0, MAX_PUBLIC_PERSONA_CANDIDATES);
  }

  private async readEvidence(candidate: PublicPersonaCandidate): Promise<PublicPersonaEvidenceResult> {
    try {
      const read = await this.readProfile(candidate.profileUrl, true);
      if (read.state !== 'success' && read.state !== 'partial') {
        return { state: read.state, evidence: null };
      }
      const data = read.data;
      const identity = read.identity;
      const displayName = candidate.displayName.length > 0 ? candidate.displayName : identity === null ? '' : identity.displayName;
      const username = candidate.username.length > 0 ? candidate.username : identity === null ? '' : identity.username;
      const avatarUrl = candidate.avatarUrl.length > 0 ? candidate.avatarUrl : identity === null ? '' : identity.avatarUrl;
      if (displayName.length === 0 || username.length === 0 || avatarUrl.length === 0 || candidate.profileUrl.length === 0) {
        return { state: 'error', evidence: null };
      }
      const profileSourceUrls = uniqueUrls([candidate.profileUrl].concat(strings(data['sourceUrls'])));
      const bio = profileBio(data, text(data['markdown']));
      const posts = profilePosts(data);
      aiLogInfo('[AIPhone][PublicPersonaRead] platform=' + candidate.platform +
        ' markdownChars=' + text(data['markdown']).length.toString() +
        ' bioChars=' + bio.length.toString() + ' posts=' + posts.length.toString() +
        ' state=' + read.state);
      if (bio.length === 0 && !posts.some((post: PublicPersonaPostEvidence): boolean => post.title.length > 0 || post.text.length > 0)) {
        return { state: 'partial', evidence: null };
      }
      const evidence: PublicPersonaAccountEvidence = {
        platform: candidate.platform,
        profileUrl: candidate.profileUrl,
        avatarUrl: avatarUrl,
        displayName: displayName,
        username: username,
        bio: bio,
        posts: posts,
        sourceUrls: profileSourceUrls,
        fetchedAt: this.now(),
        providerState: read.state
      };
      if (candidate.platform === 'x') {
        const xArgs: PublicPersonaXSearchArgs = {
          query: 'from:' + candidate.username.replace(/^@/, ''),
          pageSize: MAX_PUBLIC_POSTS
        };
        const xResult = await boundedToolCall('x.post.search', this.toolCaller('x.post.search', '搜索这个账号近期公开发布的帖子。', xArgs as Object), this.probeTimeoutMs);
        if (providerState(xResult) !== 'success') {
          evidence.providerState = providerState(xResult);
        } else {
          const xPayload = previewPayload(xResult);
          const xPosts = postEvidence(xPayload === null ? record(xResult.data)['posts'] : xPayload['posts']);
          if (xPosts.length > 0) {
            evidence.posts = xPosts;
          }
        }
      }
      return { state: evidence.providerState, evidence: evidence };
    } catch (_error) {
      return { state: 'error', evidence: null };
    }
  }

  async buildSnapshot(
    selected: PublicPersonaCandidate[],
    settings: LocalModelSettings,
    onProgress: PublicPersonaProgressListener
  ): Promise<PublicPersonaSnapshot> {
    const chosen = selected.filter((candidate: PublicPersonaCandidate): boolean => candidate.selected);
    const evidence: PublicPersonaAccountEvidence[] = [];
    for (let index = 0; index < chosen.length; index++) {
      const candidate = chosen[index];
      safeProgress(onProgress, { completed: index, total: chosen.length, platform: candidate.platform, state: 'running', message: '正在读取' + candidate.displayName + '的公开资料' });
      const result = await this.readEvidence(candidate);
      if (result.evidence !== null && result.state !== 'blocked_by_site' && result.state !== 'timeout' && result.state !== 'error') {
        evidence.push(result.evidence);
      }
      safeProgress(onProgress, { completed: index + 1, total: chosen.length, platform: candidate.platform, state: result.state, message: result.evidence === null ? '该账号读取失败，继续处理其他账号' : '已读取公开资料' });
    }
    if (evidence.length === 0) {
      throw new Error('没有可用于画像的已确认公开资料');
    }
    const prompt = JSON.stringify({ accounts: compactEvidence(evidence) });
    const model = await this.modelCaller(settings, prompt, [], PUBLIC_PERSONA_SYSTEM_PROMPT);
    if (!model.ok) {
      throw new Error(model.error.length > 0 ? model.error : '画像模型调用失败');
    }
    const inference = parsePublicPersonaInference(model.raw);
    if (inference === null) {
      throw new Error('画像模型返回了不可用的 JSON');
    }
    const sources = evidence.map((account: PublicPersonaAccountEvidence): PublicPersonaSourceRef => accountSource(account));
    const snapshotInput: PublicPersonaSnapshot = {
      schemaVersion: 1,
      personaMarkdown: renderPublicPersonaMarkdown(inference, sources),
      primaryAvatarUrl: sources[0].avatarUrl,
      sources: sources,
      generatedAt: this.now(),
      mbtiHidden: false
    };
    const snapshot = sanitizePublicPersonaSnapshot(snapshotInput as Object);
    if (snapshot === null) {
      throw new Error('画像资料未通过本地校验');
    }
    return snapshot;
  }

  async reinferMbti(
    snapshot: PublicPersonaSnapshot,
    settings: LocalModelSettings
  ): Promise<PublicPersonaMbtiResult> {
    const accounts: PublicPersonaAccountEvidence[] = [];
    for (let index = 0; index < snapshot.sources.length; index++) {
      const source = snapshot.sources[index];
      const result = await this.readEvidence({
        id: source.platform + ':' + source.profileUrl,
        platform: source.platform,
        profileUrl: source.profileUrl,
        displayName: '',
        username: source.profileUrl.substring(source.profileUrl.lastIndexOf('/') + 1),
        avatarUrl: source.avatarUrl,
        exists: true,
        ownershipConfidence: 1,
        ownershipBand: 'high',
        selected: true,
        providerState: 'success',
        fetchedAt: source.fetchedAt,
        sourceUrl: source.profileUrl
      });
      if (result.evidence !== null) {
        accounts.push(result.evidence);
      }
    }
    if (accounts.length === 0) {
      throw new Error('无法重新读取已确认公开资料');
    }
    const model = await this.modelCaller(settings, JSON.stringify({ accounts: compactEvidence(accounts), mbtiOnly: true }), [], PUBLIC_PERSONA_SYSTEM_PROMPT);
    if (!model.ok) {
      throw new Error(model.error.length > 0 ? model.error : 'MBTI 模型调用失败');
    }
    const inference: PublicPersonaInference | null = parsePublicPersonaInference(model.raw);
    if (inference === null) {
      throw new Error('MBTI 模型返回了不可用的 JSON');
    }
    return { mbtiType: inference.mbtiType, mbtiConfidence: inference.mbtiConfidence };
  }
}
