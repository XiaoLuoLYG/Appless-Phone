import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { callComposioDynamic } from './ComposioDynamicBackend';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import { callMediaVideoSearch } from './MediaVideoClient';
import {
  AggregateSearchPost,
  AggregateSearchResult,
  AggregateSearchRowData,
  AggregateSearchSource,
  AggregateSearchStatus,
  AggregateSearchSourceStatus,
  AggregateSearchVideo,
  aggregateSourceLabel
} from './AggregateSearchTypes';

type AggregateArgValue = Object | string | number | boolean | null | undefined;
type AggregateArgRecord = Record<string, AggregateArgValue>;
type DynamicPostValue = Object | string | number | boolean | null | undefined;
type DynamicPostRecord = Record<string, DynamicPostValue>;

interface AggregateMediaSearchArgs {
  query: string;
  sources: string[];
}

interface AggregateComposioFixedRequest {
  fixedToolId: string;
  fixedArgs: Object;
}

interface AggregateXSearchArgs {
  query: string;
  pageSize: number;
}

export interface AggregateZhihuConfig {
  apiKey: string;
}

interface AggregateHttpResult {
  code: number;
  text: string;
}

const DEFAULT_SOURCES: AggregateSearchSource[] = ['youtube', 'bilibili', 'x', 'hackernews', 'reddit', 'zhihu'];
const X_PUBLIC_SEARCH_MARKER: string = 'X 公开 post 搜索关键词:';
const ZHIHU_SEARCH_URL: string = 'https://developer.zhihu.com/api/v1/content/zhihu_search';

function textOf(value: AggregateArgValue): string {
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

function errorText(error: Error | Object | string | number | boolean | null | undefined): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string') {
    return error;
  }
  if (error === undefined || error === null) {
    return '';
  }
  return JSON.stringify(error);
}

export function aggregateXPostSearchPrompt(query: string): string {
  return X_PUBLIC_SEARCH_MARKER + ' ' + query.trim();
}

function cleanAggregateSearchQuery(value: string): string {
  const original = value.trim();
  let query = original;
  ['有关', '关于'].forEach((marker: string) => {
    const start = query.indexOf(marker);
    if (start >= 0 && start + marker.length < query.length) {
      query = query.substring(start + marker.length).trim();
    }
  });
  ['我想看看', '我想看', '帮我看看', '帮我看', '帮我搜索', '帮我搜', '帮我查询', '帮我查',
    '聚合搜索', '搜索', '查询', '看看', '聚合', '汇总', '整理', '了解', '搜', '查'].forEach((prefix: string) => {
    if (query.indexOf(prefix) === 0 && query.length > prefix.length) {
      query = query.substring(prefix.length).trim();
    }
  });
  ['的相关新闻和讨论', '相关新闻和讨论', '的新闻和讨论', '新闻和讨论', '的相关新闻讨论', '相关新闻讨论',
    '新闻讨论', '的相关新闻', '相关新闻', '的相关讨论', '相关讨论', '的新闻', '新闻',
    '的讨论', '讨论', '热议', '观点', '帖子', 'po文', '公开动态',
    '，知乎也看', '，Reddit也看', '，reddit也看'].forEach((tail: string) => {
    if (query.length > tail.length && query.substring(query.length - tail.length) === tail) {
      query = query.substring(0, query.length - tail.length).trim();
    }
  });
  return query.length > 0 ? query : original;
}

export function aggregateSearchQueryFromArgs(prompt: string, args: Object | null): string {
  if (args !== null) {
    const query = cleanAggregateSearchQuery(textOf((args as AggregateArgRecord).query));
    if (query.length > 0) {
      return query;
    }
  }
  return cleanAggregateSearchQuery(prompt);
}

export function aggregateSearchSourcesFromArgs(args: Object | null): AggregateSearchSource[] {
  if (args === null) {
    return DEFAULT_SOURCES.slice();
  }
  const raw = (args as AggregateArgRecord).sources;
  if (!Array.isArray(raw)) {
    return DEFAULT_SOURCES.slice();
  }
  const sources: AggregateSearchSource[] = [];
  raw.forEach((item: AggregateArgValue) => {
    let value = textOf(item).trim().toLowerCase();
    if (value === 'hn' || value === 'hacknews' || value === 'hacker news') {
      value = 'hackernews';
    }
    if (value === 'b站' || value === 'b 站') {
      value = 'bilibili';
    }
    if (value === '知乎') {
      value = 'zhihu';
    }
    if (value === '红迪') {
      value = 'reddit';
    }
    if (DEFAULT_SOURCES.indexOf(value as AggregateSearchSource) >= 0 &&
      sources.indexOf(value as AggregateSearchSource) < 0) {
      sources.push(value as AggregateSearchSource);
    }
  });
  return sources.length > 0 ? sources : DEFAULT_SOURCES.slice();
}

export function unsupportedSourceStatus(source: AggregateSearchSource, message: string): AggregateSearchSourceStatus {
  return {
    source: source,
    label: aggregateSourceLabel(source),
    status: 'unsupported',
    message: message,
    count: 0
  };
}

function dedupeVideos(videos: AggregateSearchVideo[]): AggregateSearchVideo[] {
  const seen: string[] = [];
  const kept: AggregateSearchVideo[] = [];
  videos.forEach((video: AggregateSearchVideo) => {
    const key = video.url.length > 0 ? video.url : video.id;
    if (seen.indexOf(key) < 0) {
      seen.push(key);
      kept.push(video);
    }
  });
  return kept;
}

function dedupePosts(posts: AggregateSearchPost[]): AggregateSearchPost[] {
  const seen: string[] = [];
  const kept: AggregateSearchPost[] = [];
  posts.forEach((post: AggregateSearchPost) => {
    const key = post.url.length > 0 ? post.url : post.id;
    if (seen.indexOf(key) < 0) {
      seen.push(key);
      kept.push(post);
    }
  });
  return kept;
}

export function aggregateSearchResultFromParts(
  query: string,
  videos: AggregateSearchVideo[],
  posts: AggregateSearchPost[],
  statuses: AggregateSearchSourceStatus[]
): AggregateSearchResult {
  const keptVideos = dedupeVideos(videos);
  const keptPosts = dedupePosts(posts);
  return {
    query: query,
    videos: keptVideos,
    posts: keptPosts,
    sourceStatuses: statuses,
    summary: keptVideos.length.toString() + ' video' + (keptVideos.length === 1 ? '' : 's') +
      ', ' + keptPosts.length.toString() + ' discussion' + (keptPosts.length === 1 ? '' : 's')
  };
}

function rowValue(result: DynamicGenericToolResult, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value.trim();
    }
  }
  return '';
}

export function normalizeAggregateSearchStatus(status: string, count: number): AggregateSearchStatus {
  if (status === 'empty') {
    return 'empty';
  }
  if (status === 'success' || status === 'connected') {
    return count > 0 ? 'success' : 'empty';
  }
  if (status === 'needs_auth' || status === 'auth_required') {
    return 'needs_auth';
  }
  return 'error';
}

function statusFor(source: AggregateSearchSource, status: string, message: string, count: number): AggregateSearchSourceStatus {
  return {
    source: source,
    label: aggregateSourceLabel(source),
    status: normalizeAggregateSearchStatus(status, count),
    message: message,
    count: count
  };
}

function dynamicSource(result: DynamicGenericToolResult): AggregateSearchSource {
  return result.sourceTag === 'YouTube Data API' ? 'youtube' : 'bilibili';
}

function dynamicVideoUrl(result: DynamicGenericToolResult): string {
  const watchUrl = rowValue(result, 'Watch URL');
  if (watchUrl.length > 0) {
    return watchUrl;
  }
  const playbackUrl = rowValue(result, 'Playback URL');
  if (playbackUrl.length > 0) {
    return playbackUrl;
  }
  return rowValue(result, 'Share URL');
}

function videoFromDynamic(source: AggregateSearchSource, result: DynamicGenericToolResult, index: number): AggregateSearchVideo {
  return {
    id: source + '-' + index.toString(),
    source: source,
    provider: result.sourceTag,
    title: result.title,
    summary: result.summary,
    url: dynamicVideoUrl(result),
    thumbnail: rowValue(result, 'Thumbnail'),
    publishedAt: rowValue(result, 'Published'),
    duration: rowValue(result, 'Duration'),
    status: result.status === 'success' ? 'success' : 'error',
    rows: result.rows.slice()
  };
}

function urlFromText(value: string): string {
  const urlStart = value.indexOf('http');
  return urlStart >= 0 ? value.substring(urlStart).split(' ')[0].trim() : '';
}

function imageUrlsFromText(value: string): string[] {
  const matches = value.match(/https?:\/\/[^\s,，"'\]}]+/g);
  if (matches === null) {
    return [];
  }
  const urls: string[] = [];
  matches.forEach((raw: string) => {
    const lower = raw.toLowerCase();
    if ((lower.indexOf('.jpg') < 0 && lower.indexOf('.jpeg') < 0 && lower.indexOf('.png') < 0 &&
      lower.indexOf('.webp') < 0 && lower.indexOf('.gif') < 0 && lower.indexOf('image') < 0 &&
      lower.indexOf('pic') < 0) || urls.indexOf(raw) >= 0) {
      return;
    }
    urls.push(raw);
  });
  return urls;
}

function plainPostText(value: string): string {
  return value
    .replace(/<br\s*\/?>/g, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .trim();
}

function parsedDynamicPostRecord(value: string): DynamicPostRecord | null {
  try {
    const parsed = JSON.parse(value) as Object;
    if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
      return null;
    }
    return parsed as DynamicPostRecord;
  } catch (_error) {
    return null;
  }
}

function dynamicPostRecord(value: string): DynamicPostRecord | null {
  const record = parsedDynamicPostRecord(value);
  if (record === null) {
    return null;
  }
  const data = record.data;
  if (data !== undefined && data !== null && typeof data === 'object' && !Array.isArray(data)) {
    return data as DynamicPostRecord;
  }
  return record;
}

function recordText(record: DynamicPostRecord, names: string[]): string {
  for (let index = 0; index < names.length; index++) {
    const value = textOf(record[names[index]]).trim();
    if (value.length > 0) {
      return value;
    }
  }
  return '';
}

function nestedRecordText(record: DynamicPostRecord, key: string, names: string[]): string {
  const value = record[key];
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return '';
  }
  return recordText(value as DynamicPostRecord, names);
}

function dynamicPostText(value: string): string {
  const record = dynamicPostRecord(value);
  if (record !== null) {
    const text = recordText(record, ['full_text', 'selftext', 'text', 'body', 'content', 'excerpt', 'summary', 'description', 'title', 'question']);
    if (text.length > 0) {
      return plainPostText(text);
    }
  }
  return plainPostText(value);
}

function dynamicPostTitle(label: string, value: string): string {
  const record = dynamicPostRecord(value);
  if (record !== null) {
    const title = recordText(record, ['title', 'question', 'name']);
    if (title.length > 0) {
      return plainPostText(title);
    }
    const user = nestedRecordText(record, 'user', ['screen_name', 'name']);
    if (user.length > 0) {
      return user;
    }
  }
  return label;
}

function dynamicPostAuthor(value: string): string {
  const record = dynamicPostRecord(value);
  if (record === null) {
    return '';
  }
  const author = nestedRecordText(record, 'author', ['name', 'headline']);
  if (author.length > 0) {
    return author;
  }
  const user = nestedRecordText(record, 'user', ['screen_name', 'name']);
  return user.length > 0 ? user : recordText(record, ['author', 'screen_name', 'user_name']);
}

function dynamicPostUrl(value: string): string {
  const record = dynamicPostRecord(value);
  if (record !== null) {
    const direct = recordText(record, ['url', 'html_url', 'link', 'share_url', 'permalink', 'url_overridden_by_dest']);
    if (direct.length > 0) {
      return direct.charAt(0) === '/' ? 'https://www.reddit.com' + direct : direct;
    }
  }
  return urlFromText(value);
}

function appendImageUrl(urls: string[], value: string): void {
  if (value.length > 0 && urls.indexOf(value) < 0) {
    urls.push(value);
  }
}

function imageUrlsFromDynamicPost(value: string): string[] {
  const urls = imageUrlsFromText(value);
  const record = dynamicPostRecord(value);
  if (record === null) {
    return urls;
  }
  ['thumbnail_pic', 'bmiddle_pic', 'original_pic', 'image_url', 'cover', 'thumbnail', 'url_overridden_by_dest'].forEach((key: string) => {
    appendImageUrl(urls, textOf(record[key]).trim());
  });
  const pics = record.pics;
  if (Array.isArray(pics)) {
    pics.forEach((item: DynamicPostValue) => {
      if (item === null || item === undefined) {
        return;
      }
      if (typeof item === 'string') {
        appendImageUrl(urls, item);
        return;
      }
      if (typeof item === 'object') {
        appendImageUrl(urls, recordText(item as DynamicPostRecord, ['url', 'large_url', 'thumbnail_pic', 'bmiddle_pic', 'original_pic']));
      }
    });
  }
  return urls;
}

function dynamicPostPublishedAt(value: string): string {
  const record = dynamicPostRecord(value);
  return record === null ? '' : recordText(record, ['created_at', 'created_utc', 'published_at', 'updated_at', 'time', 'date']);
}

function dynamicPostScore(value: string): string {
  const record = dynamicPostRecord(value);
  return record === null ? '' : recordText(record, ['points', 'score', 'ups', 'attitudes_count', 'voteup_count', 'likes']);
}

function dynamicPostCommentCount(value: string): string {
  const record = dynamicPostRecord(value);
  return record === null ? '' : recordText(record, ['num_comments', 'commentCount', 'comments_count', 'answer_count']);
}

function postFromDynamicRow(
  source: AggregateSearchSource,
  provider: string,
  result: DynamicGenericToolResult,
  rowIndex: number
): AggregateSearchPost {
  const row = result.rows[rowIndex];
  const url = dynamicPostUrl(row.value);
  const rows = [row];
  const images = imageUrlsFromDynamicPost(row.value);
  if (images.length > 0) {
    rows.push({ label: 'images', value: images.join(' ') });
  }
  const text = dynamicPostText(row.value);
  return {
    id: source + '-' + rowIndex.toString(),
    source: source,
    provider: provider,
    title: dynamicPostTitle(row.label, row.value),
    author: dynamicPostAuthor(row.value),
    handle: '',
    text: text.length > 0 ? text : row.value,
    url: url,
    publishedAt: dynamicPostPublishedAt(row.value),
    score: dynamicPostScore(row.value),
    commentCount: dynamicPostCommentCount(row.value),
    status: result.status === 'success' ? 'success' : 'error',
    rows: rows
  };
}

function objectArrayFrom(value: DynamicPostValue): Object[] {
  const items: Object[] = [];
  if (!Array.isArray(value)) {
    return items;
  }
  value.forEach((item: DynamicPostValue) => {
    if (item !== undefined && item !== null && typeof item === 'object') {
      items.push(item as Object);
    }
  });
  return items;
}

function looksLikeDynamicPostObject(item: Object): boolean {
  const record = item as DynamicPostRecord;
  if (recordText(record, ['title', 'name', 'full_text', 'selftext', 'text', 'body', 'content', 'excerpt', 'summary', 'description', 'question']).length > 0) {
    return true;
  }
  const data = record.data;
  return data !== undefined && data !== null && typeof data === 'object' && !Array.isArray(data) &&
    recordText(data as DynamicPostRecord, ['title', 'name', 'full_text', 'selftext', 'text', 'body', 'content', 'excerpt', 'summary', 'description', 'question']).length > 0;
}

function firstObjectArray(value: DynamicPostValue): Object[] {
  if (Array.isArray(value)) {
    const direct = objectArrayFrom(value);
    const flattened: Object[] = [];
    let replaced = false;
    direct.forEach((item: Object) => {
      if (looksLikeDynamicPostObject(item)) {
        flattened.push(item);
        return;
      }
      const nested = firstObjectArray(item);
      if (nested.length > 0) {
        replaced = true;
        nested.forEach((nestedItem: Object) => flattened.push(nestedItem));
        return;
      }
      flattened.push(item);
    });
    return replaced ? flattened : direct;
  }
  if (typeof value === 'string') {
    const clean = value.trim();
    if (clean.charAt(0) !== '{' && clean.charAt(0) !== '[') {
      return [];
    }
    try {
      return firstObjectArray(JSON.parse(clean) as DynamicPostValue);
    } catch (_error) {
      return [];
    }
  }
  if (value === undefined || value === null || typeof value !== 'object') {
    return [];
  }
  const record = value as DynamicPostRecord;
  const preferred = ['hits', 'posts', 'items', 'results', 'data', 'children', 'preview'];
  for (let index = 0; index < preferred.length; index++) {
    const items = firstObjectArray(record[preferred[index]]);
    if (items.length > 0) {
      return items;
    }
  }
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    const items = firstObjectArray(record[keys[index]]);
    if (items.length > 0) {
      return items;
    }
  }
  return [];
}

function postFromDynamicObject(source: AggregateSearchSource, provider: string, item: Object, index: number): AggregateSearchPost {
  const value = JSON.stringify(item);
  const row: AggregateSearchRowData = {
    label: dynamicPostTitle('result ' + (index + 1).toString(), value),
    value: value
  };
  const result: DynamicGenericToolResult = {
    sourceTag: provider,
    toolName: source,
    title: provider,
    status: 'success',
    summary: '',
    rows: [row],
    rawPreview: value
  };
  return postFromDynamicRow(source, provider, result, 0);
}

function postsFromDynamicRawPreview(
  source: AggregateSearchSource,
  provider: string,
  result: DynamicGenericToolResult
): AggregateSearchPost[] {
  try {
    const items = firstObjectArray(JSON.parse(result.rawPreview) as DynamicPostValue);
    return items.slice(0, 5).map((item: Object, index: number) => postFromDynamicObject(source, provider, item, index));
  } catch (_error) {
    return [];
  }
}

function shouldKeepDynamicRow(label: string): boolean {
  return label !== '执行工具' &&
    label !== '查询' &&
    label !== '结果数量' &&
    label !== '结果摘要' &&
    label !== '授权 Toolkit' &&
    label !== '阶段' &&
    label !== 'source' &&
    label !== 'truncated' &&
    label !== 'preview';
}

function postsFromDynamicResult(
  source: AggregateSearchSource,
  provider: string,
  result: DynamicGenericToolResult
): AggregateSearchPost[] {
  if (result.status !== 'success') {
    return [];
  }
  const rawPosts = postsFromDynamicRawPreview(source, provider, result);
  if (rawPosts.length > 0) {
    return rawPosts;
  }
  const posts: AggregateSearchPost[] = [];
  for (let rowIndex = 0; rowIndex < result.rows.length; rowIndex++) {
    if (!shouldKeepDynamicRow(result.rows[rowIndex].label)) {
      continue;
    }
    posts.push(postFromDynamicRow(source, provider, result, rowIndex));
  }
  if (posts.length === 0 && result.summary.length > 0) {
    const fallbackResult: DynamicGenericToolResult = {
      sourceTag: result.sourceTag,
      toolName: result.toolName,
      title: result.title,
      status: result.status,
      summary: result.summary,
      rows: [{ label: result.title, value: result.summary }],
      rawPreview: result.rawPreview
    };
    posts.push(postFromDynamicRow(source, provider, fallbackResult, 0));
  }
  return posts;
}

export function hackerNewsPostsFromComposioResult(result: DynamicGenericToolResult): AggregateSearchPost[] {
  return postsFromDynamicResult('hackernews', 'Hacker News', result);
}

export function redditPostsFromComposioResult(result: DynamicGenericToolResult): AggregateSearchPost[] {
  return postsFromDynamicResult('reddit', 'Reddit', result);
}

export function xPostsFromComposioResult(result: DynamicGenericToolResult): AggregateSearchPost[] {
  return postsFromDynamicResult('x', 'X', result);
}

function mediaMessage(source: AggregateSearchSource, count: number, results: DynamicGenericToolResult[]): string {
  if (count > 0) {
    return aggregateSourceLabel(source) + ' returned ' + count.toString() + ' rows.';
  }
  if (results.length > 0) {
    return results[0].summary;
  }
  return aggregateSourceLabel(source) + ' returned 0 rows.';
}

function statusFromComposioError(error: Error | Object | string | number | boolean | null | undefined): string {
  const message = errorText(error);
  if (message.indexOf('未配置') >= 0 || message.indexOf('授权') >= 0 ||
    message.indexOf('ACTIVE connected account') >= 0 || message.toLowerCase().indexOf('auth') >= 0) {
    return 'needs_auth';
  }
  return 'error';
}

async function appendComposioPosts(
  source: AggregateSearchSource,
  provider: string,
  prompt: string,
  posts: AggregateSearchPost[],
  statuses: AggregateSearchSourceStatus[],
  fixedToolId: string = '',
  fixedArgs: Object | null = null
): Promise<void> {
  try {
    let request: Object | null = null;
    if (fixedToolId.length > 0 && fixedArgs !== null) {
      const fixedRequest: AggregateComposioFixedRequest = {
        fixedToolId: fixedToolId,
        fixedArgs: fixedArgs
      };
      request = fixedRequest as Object;
    }
    const result = await callComposioDynamic(prompt, request);
    if (result === null) {
      statuses.push(statusFor(source, 'error', 'Composio ' + provider + ' did not run.', 0));
      return;
    }
    const nextPosts = postsFromDynamicResult(source, provider, result);
    nextPosts.forEach((post: AggregateSearchPost) => posts.push(post));
    statuses.push(statusFor(source, result.status, result.summary, nextPosts.length));
  } catch (error) {
    statuses.push(statusFor(
      source,
      statusFromComposioError(error),
      'Composio ' + provider + ' failed: ' + errorText(error),
      0
    ));
  }
}

function responseText(value: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof value === 'string') {
    return value;
  }
  if (value instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(value));
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

export function zhihuSearchUrl(query: string, count: number = 10): string {
  return ZHIHU_SEARCH_URL + '?Query=' + encodeURIComponent(query) + '&Count=' + encodeURIComponent(count.toString());
}

function zhihuTimestamp(): string {
  return Math.floor(Date.now() / 1000).toString();
}

async function requestZhihuSearch(query: string, apiKey: string): Promise<AggregateHttpResult> {
  const request = http.createHttp();
  try {
    const response = await request.request(zhihuSearchUrl(query, 10), {
      method: http.RequestMethod.GET,
      header: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ' + apiKey.trim(),
        'X-Request-Timestamp': zhihuTimestamp(),
        'Content-Type': 'application/json'
      },
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

function zhihuDataRecord(payload: DynamicPostRecord): DynamicPostRecord {
  const data = payload.Data ?? payload.data;
  if (data !== undefined && data !== null && typeof data === 'object' && !Array.isArray(data)) {
    return data as DynamicPostRecord;
  }
  return payload;
}

function zhihuItemsFromPayload(rawJson: string): Object[] {
  const payload = JSON.parse(rawJson) as DynamicPostRecord;
  const code = textOf(payload.Code ?? payload.code).trim();
  if (code.length > 0 && code !== '0') {
    throw new Error(recordText(payload, ['Message', 'message', 'msg']) || 'Zhihu API returned Code=' + code);
  }
  const data = zhihuDataRecord(payload);
  const items = data.Items ?? data.items ?? data.Results ?? data.results ?? data.List ?? data.list;
  return Array.isArray(items) ? items as Object[] : [];
}

function zhihuTimeText(value: string): string {
  const stamp = Number(value);
  if (!Number.isFinite(stamp) || stamp <= 0) {
    return value;
  }
  return new Date(stamp * 1000).toISOString();
}

function zhihuPostFromItem(item: Object, index: number): AggregateSearchPost {
  const record = item as DynamicPostRecord;
  const title = plainPostText(recordText(record, ['Title', 'title']));
  const text = plainPostText(recordText(record, ['ContentText', 'contentText', 'content_text', 'Snippet', 'snippet', 'Summary', 'summary', 'Abstract', 'abstract', 'Description', 'description']));
  const url = recordText(record, ['Url', 'url', 'URI', 'uri', 'Link', 'link']);
  const author = recordText(record, ['AuthorName', 'authorName', 'author', 'Source', 'source', 'Site', 'site']);
  const score = recordText(record, ['VoteUpCount', 'voteUpCount', 'Score', 'score', 'Relevance', 'relevance']);
  const commentCount = recordText(record, ['CommentCount', 'commentCount', 'comments_count', 'num_comments']);
  const rows: AggregateSearchRowData[] = [
    { label: 'author', value: author },
    { label: 'contentType', value: recordText(record, ['ContentType', 'contentType']) },
    { label: 'text', value: text },
    { label: 'url', value: url },
    { label: 'score', value: score },
    { label: 'comments', value: commentCount }
  ];
  const avatar = recordText(record, ['AuthorAvatar', 'authorAvatar', 'AuthorBadge', 'authorBadge']);
  if (avatar.length > 0) {
    rows.push({ label: 'images', value: avatar });
  }
  return {
    id: 'zhihu-' + (recordText(record, ['ContentID', 'contentID', 'id']) || index.toString()),
    source: 'zhihu',
    provider: '知乎',
    title: title.length > 0 ? title : '知乎内容',
    author: author,
    handle: '',
    text: text,
    url: url,
    publishedAt: zhihuTimeText(recordText(record, ['EditTime', 'editTime', 'created_at', 'published_at'])),
    score: score,
    commentCount: commentCount,
    status: 'success',
    rows: rows
  };
}

export function zhihuPostsFromSearchPayload(rawJson: string): AggregateSearchPost[] {
  const posts: AggregateSearchPost[] = [];
  zhihuItemsFromPayload(rawJson).forEach((item: Object, index: number) => {
    const post = zhihuPostFromItem(item, index);
    if (post.title.length > 0 || post.text.length > 0 || post.url.length > 0) {
      posts.push(post);
    }
  });
  return posts;
}

function statusFromZhihuError(error: Error | Object | string | number | boolean | null | undefined): string {
  const message = errorText(error);
  const lower = message.toLowerCase();
  if (message.indexOf('401') >= 0 || message.indexOf('403') >= 0 ||
    lower.indexOf('authorization') >= 0 || lower.indexOf('auth') >= 0 || message.indexOf('鉴权') >= 0) {
    return 'needs_auth';
  }
  return 'error';
}

async function appendZhihuPosts(
  config: AggregateZhihuConfig,
  query: string,
  posts: AggregateSearchPost[],
  statuses: AggregateSearchSourceStatus[]
): Promise<void> {
  const apiKey = config.apiKey.trim();
  if (apiKey.length === 0) {
    statuses.push(statusFor('zhihu', 'needs_auth', '未配置 ZHIHU_API_KEY（知乎 Access Secret）。', 0));
    return;
  }
  try {
    const response = await requestZhihuSearch(query, apiKey);
    if (response.code < 200 || response.code >= 300) {
      throw new Error('HTTP ' + response.code.toString() + ': ' + response.text.substring(0, 240));
    }
    const nextPosts = zhihuPostsFromSearchPayload(response.text);
    nextPosts.forEach((post: AggregateSearchPost) => posts.push(post));
    statuses.push(statusFor('zhihu', nextPosts.length > 0 ? 'success' : 'empty', '知乎返回 ' + nextPosts.length.toString() + ' 条。', nextPosts.length));
  } catch (error) {
    statuses.push(statusFor('zhihu', statusFromZhihuError(error), '知乎 API 调用失败：' + errorText(error), 0));
  }
}

function emptyZhihuConfig(): AggregateZhihuConfig {
  return {
    apiKey: ''
  };
}

export async function callAggregateSearch(
  prompt: string,
  args: Object | null,
  youtubeApiKey: string,
  zhihuConfig: AggregateZhihuConfig = emptyZhihuConfig()
): Promise<AggregateSearchResult> {
  const query = aggregateSearchQueryFromArgs(prompt, args);
  const sources = aggregateSearchSourcesFromArgs(args);
  const videos: AggregateSearchVideo[] = [];
  const posts: AggregateSearchPost[] = [];
  const statuses: AggregateSearchSourceStatus[] = [];

  if (sources.indexOf('youtube') >= 0 || sources.indexOf('bilibili') >= 0) {
    const mediaSources: string[] = [];
    if (sources.indexOf('youtube') >= 0) {
      mediaSources.push('youtube');
    }
    if (sources.indexOf('bilibili') >= 0) {
      mediaSources.push('bilibili');
    }
    const mediaArgs: AggregateMediaSearchArgs = {
      query: query,
      sources: mediaSources
    };
    const mediaResults = await callMediaVideoSearch(query, mediaArgs as Object, youtubeApiKey);
    mediaResults.forEach((result: DynamicGenericToolResult, index: number) => {
      if (result.status !== 'success') {
        return;
      }
      const video = videoFromDynamic(dynamicSource(result), result, index);
      if (video.url.length > 0) {
        videos.push(video);
      }
    });
    if (sources.indexOf('youtube') >= 0) {
      const youtubeResults = mediaResults.filter((result: DynamicGenericToolResult) => dynamicSource(result) === 'youtube');
      const youtubeCount = videos.filter((video: AggregateSearchVideo) => video.source === 'youtube').length;
      const youtubeStatus = youtubeCount > 0 ? 'success' : (youtubeResults.length > 0 ? youtubeResults[0].status : 'empty');
      statuses.push(statusFor('youtube', youtubeStatus, mediaMessage('youtube', youtubeCount, youtubeResults), youtubeCount));
    }
    if (sources.indexOf('bilibili') >= 0) {
      const bilibiliResults = mediaResults.filter((result: DynamicGenericToolResult) => dynamicSource(result) === 'bilibili');
      const bilibiliCount = videos.filter((video: AggregateSearchVideo) => video.source === 'bilibili').length;
      const bilibiliStatus = bilibiliCount > 0 ? 'success' : (bilibiliResults.length > 0 ? bilibiliResults[0].status : 'empty');
      statuses.push(statusFor('bilibili', bilibiliStatus, mediaMessage('bilibili', bilibiliCount, bilibiliResults), bilibiliCount));
    }
  }

  if (sources.indexOf('x') >= 0) {
    const xArgs: AggregateXSearchArgs = {
      query: query,
      pageSize: 5
    };
    await appendComposioPosts(
      'x',
      'X',
      '帮我用 Composio X 搜索 ' + query + ' 的公开 post',
      posts,
      statuses,
      'x.post.search',
      xArgs as Object
    );
  }

  if (sources.indexOf('hackernews') >= 0) {
    await appendComposioPosts('hackernews', 'Hacker News', '帮我用 Composio Hacker News 查 ' + query, posts, statuses);
  }
  if (sources.indexOf('reddit') >= 0) {
    await appendComposioPosts('reddit', 'Reddit', '帮我用 Composio Reddit 查 ' + query + ' 的帖子', posts, statuses);
  }
  if (sources.indexOf('zhihu') >= 0) {
    await appendZhihuPosts(zhihuConfig, query, posts, statuses);
  }

  return aggregateSearchResultFromParts(query, videos, posts, statuses);
}
