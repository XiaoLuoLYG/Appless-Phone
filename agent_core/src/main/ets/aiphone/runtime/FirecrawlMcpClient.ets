import { A2uiAction, A2uiLabelValueData } from './A2uiTypes';
import { aiLogError, aiLogInfo } from './AiphoneLogger';
import {
  DynamicGenericToolResult,
  DynamicPreflightResult,
  DynamicToolRegistration
} from './DynamicToolTypes';
import {
  GenericMcpClient,
  McpToolCallResult,
  McpToolContentItem,
  McpToolResultPayload
} from './GenericMcpClient';

export type FirecrawlResultStatus =
  'success' | 'partial' | 'empty' | 'needs_auth' | 'credits_exhausted' |
  'rate_limited' | 'blocked_by_site' | 'timeout' | 'error';

export interface FirecrawlConfig {
  apiKey: string;
  mcpUrl: string;
}

export interface FirecrawlToolOutput {
  title: string;
  intent: string;
  results: DynamicGenericToolResult[];
}

export const DEFAULT_FIRECRAWL_MCP_URL: string = 'https://mcp.firecrawl.dev/v2/mcp';
export const FIRECRAWL_MCP_READ_TIMEOUT_MS: number = 60000;

const REQUIRED_MCP_TOOLS: string[] = [
  'firecrawl_search',
  'firecrawl_scrape',
  'firecrawl_monitor_create',
  'firecrawl_monitor_list',
  'firecrawl_monitor_get',
  'firecrawl_monitor_update',
  'firecrawl_monitor_delete',
  'firecrawl_monitor_run',
  'firecrawl_monitor_checks',
  'firecrawl_monitor_check'
];

const SHORT_PREVIEW_CHARS: number = 1200;
const FULL_PREVIEW_CHARS: number = 12000;
const SUMMARY_CHARS: number = 600;
const XIAOHONGSHU_PROFILE: string = 'aiphone-xiaohongshu-login';
const SHOPPING_SOURCE_DOMAINS: string[] = [
  'zol.com.cn',
  'pconline.com.cn',
  'jd.com',
  'tmall.com',
  'taobao.com',
  'idealo.de',
  'amazon.com',
  'bestbuy.com',
  'bhphotovideo.com'
];

interface FirecrawlPageReadArgs {
  url?: Object | string | number | boolean | null;
  question?: string;
  includeFullText?: boolean;
}

interface MarkdownPageReadCallArgs {
  url: string;
  formats: string[];
  onlyMainContent: boolean;
}

interface FirecrawlQuestionData {
  answer?: string;
  evidence?: Object | string | number | boolean | null;
}

interface FirecrawlPageMetadata {
  title?: string;
  sourceURL?: string;
  url?: string;
  scrapeId?: string;
  publishedTime?: string;
  publishedAt?: string;
  statusCode?: number;
  warning?: string;
  warnings?: Object | string | number | boolean | null;
}

interface FirecrawlUsageEnvelope {
  creditsUsed?: number | string;
  creditsBilled?: number | string;
  warning?: string;
  warnings?: Object | string | number | boolean | null;
  metadata?: FirecrawlPageMetadata | null;
}

interface FirecrawlPageResponse extends FirecrawlUsageEnvelope {
  success?: boolean;
  data?: Object;
  markdown?: string;
  json?: Object | null;
  error?: string;
  message?: string;
  status?: string;
}

interface ParsedFirecrawlPayload {
  value: FirecrawlPageResponse | null;
  rawText: string;
}

interface FirecrawlResearchArgs {
  query?: string;
  domains?: string[];
  maxResults?: number;
  recency?: string;
}

interface FirecrawlShoppingArgs {
  query?: string;
  domains?: string[];
  maxProducts?: number;
  preferences?: string[];
}

interface FirecrawlSocialArgs {
  query?: string;
  platforms?: string[];
  maxResults?: number;
  recency?: string;
}

interface FirecrawlMonitorCreateArgs {
  pages?: string[];
  queries?: string[];
  goal?: string;
  name?: string;
  scheduleText?: string;
  timezone?: string;
  email?: string;
  confirmed?: boolean;
}

interface FirecrawlMonitorActionArgs {
  id?: string;
  checkId?: string;
  limit?: number;
  offset?: number;
  confirmed?: boolean;
}

interface FirecrawlMonitorItem {
  id?: string;
  checkId?: string;
  monitorId?: string;
  name?: string;
  status?: string;
  goal?: string;
  schedule?: Object | string | number | boolean | null;
  lastRunAt?: string;
  nextRunAt?: string;
  currentCheckId?: string;
  lastCheckId?: string;
  lastCheckStatus?: string;
  lastCheckAt?: string;
  lastCheck?: Object | string | number | boolean | null;
}

interface FirecrawlMonitorCheckSummary {
  id?: string;
  checkId?: string;
  status?: string;
  createdAt?: string;
  updatedAt?: string;
  completedAt?: string;
}

interface FirecrawlMonitorEnvelope extends FirecrawlUsageEnvelope {
  success?: boolean;
  data?: Object | string | number | boolean | null;
  monitors?: (Object | string | number | boolean | null)[];
  checks?: (Object | string | number | boolean | null)[];
  id?: string;
  checkId?: string;
  monitorId?: string;
  name?: string;
  status?: string;
  goal?: string;
  error?: string;
  message?: string;
}

interface MonitorCallOutcome {
  ok: boolean;
  providerCalled: boolean;
  status: FirecrawlResultStatus;
  value: FirecrawlMonitorEnvelope | null;
  message: string;
  rawPreview: string;
  httpStatus: number;
  usage: UsageSnapshot;
}

interface FirecrawlSearchItem {
  url?: string;
  title?: string;
  description?: string;
  markdown?: string;
  publishedDate?: string;
}

interface FirecrawlSearchData {
  web?: (Object | string | number | boolean | null)[];
}

interface FirecrawlSearchResponse extends FirecrawlUsageEnvelope {
  success?: boolean;
  data?: FirecrawlSearchData | null;
  id?: string;
  error?: string;
  message?: string;
}

interface SearchOutcome {
  status: FirecrawlResultStatus;
  items: FirecrawlSearchItem[];
  message: string;
  rawPreview: string;
  httpStatus: number;
  requestId: string;
  usage: UsageSnapshot;
}

interface ScrapeOutcome {
  status: FirecrawlResultStatus;
  page: FirecrawlPageResponse | null;
  message: string;
  rawPreview: string;
  httpStatus: number;
  usage: UsageSnapshot;
}

interface FirecrawlInteractResponse extends FirecrawlUsageEnvelope {
  success?: boolean;
  stdout?: string;
  stderr?: string;
  error?: string;
  message?: string;
}

interface InteractOutcome {
  status: FirecrawlResultStatus;
  stdout: string;
  message: string;
  rawPreview: string;
  httpStatus: number;
  usage: UsageSnapshot;
}

interface UsageSnapshot {
  credits: string;
  warnings: string[];
}

interface DomainFilter {
  valid: boolean;
  domains: string[];
}

interface FirecrawlProductData {
  name?: string;
  brand?: string;
  model?: string;
  variant?: string;
  seller?: string;
  priceText?: string;
  listPriceText?: string;
  salePriceText?: string;
  estimatedPriceText?: string;
  couponText?: string;
  shippingText?: string;
  imageUrl?: string;
  specifications?: Object | string | number | boolean | null;
  strengths?: Object | string | number | boolean | null;
  limitations?: Object | string | number | boolean | null;
}

interface FirecrawlOfferData extends FirecrawlProductData {
  platform?: string;
  offerUrl?: string;
  evidenceUrl?: string;
  market?: string;
  currency?: string;
}

interface FirecrawlOfferEnvelope {
  offers?: (Object | string | number | boolean | null)[];
}

interface ShoppingPrice {
  text: string;
  kind: string;
  valueFen: number;
  comparable: boolean;
}

interface SocialPlatform {
  name: string;
  domain: string;
}

interface XiaohongshuSearchCard {
  title?: string;
  author?: string;
  published?: string;
  url?: string;
  coverUrl?: string;
  isVideo?: boolean;
}

interface XiaohongshuNoteDetail {
  title?: string;
  author?: string;
  description?: string;
  url?: string;
  imageUrls?: string[];
  isVideo?: boolean;
  videoDuration?: number;
}

interface SourceUrlArgs {
  url: string;
}

export function directFirecrawlToolIdForActionId(actionId: string): string {
  if (actionId === 'web.page.read') {
    return 'web.page.read';
  }
  if (actionId === 'web.monitor.create.confirm') {
    return 'web.monitor.create';
  }
  if (actionId === 'web.monitor.detail' || actionId === 'web.monitor.checks' ||
    actionId === 'web.monitor.check' || actionId === 'web.monitor.run' ||
    actionId === 'web.monitor.run.confirm' || actionId === 'web.monitor.pause' ||
    actionId === 'web.monitor.pause.confirm' || actionId === 'web.monitor.resume' ||
    actionId === 'web.monitor.resume.confirm' || actionId === 'web.monitor.delete' ||
    actionId === 'web.monitor.delete.confirm') {
    return 'web.monitor.list';
  }
  return '';
}

function textOf(value: string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  return typeof value === 'string' ? value : value.toString();
}

function nowIso(): string {
  return new Date().toISOString();
}

function validPortSuffix(value: string): boolean {
  if (value.length === 0) {
    return true;
  }
  if (!value.startsWith(':') || value.length === 1) {
    return false;
  }
  const digits = value.substring(1);
  for (let index = 0; index < digits.length; index++) {
    const code = digits.charCodeAt(index);
    if (code < 48 || code > 57) {
      return false;
    }
  }
  const port = Number.parseInt(digits, 10);
  return port >= 1 && port <= 65535;
}

function validIpv6Literal(value: string): boolean {
  const compression = value.indexOf('::');
  if (value.length === 0 || value.indexOf(':::') >= 0 ||
    (compression >= 0 && value.indexOf('::', compression + 2) >= 0)) {
    return false;
  }
  if ((value.startsWith(':') && !value.startsWith('::')) ||
    (value.endsWith(':') && !value.endsWith('::'))) {
    return false;
  }
  const groups = value.split(':');
  let groupCount = 0;
  for (let groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    const group = groups[groupIndex];
    if (group.length === 0) {
      continue;
    }
    if (group.length > 4) {
      return false;
    }
    groupCount++;
    for (let charIndex = 0; charIndex < group.length; charIndex++) {
      const code = group.charCodeAt(charIndex);
      const isDigit = code >= 48 && code <= 57;
      const isLowerHex = code >= 97 && code <= 102;
      const isUpperHex = code >= 65 && code <= 70;
      if (!isDigit && !isLowerHex && !isUpperHex) {
        return false;
      }
    }
  }
  return compression >= 0 ? groupCount < 8 : groupCount === 8;
}

function normalizedIpv4(value: string): string {
  const parts = value.split('.');
  if (parts.length !== 4) {
    return '';
  }
  const normalized: string[] = [];
  for (let partIndex = 0; partIndex < parts.length; partIndex++) {
    const part = parts[partIndex];
    if (part.length === 0 || part.length > 3) {
      return '';
    }
    for (let charIndex = 0; charIndex < part.length; charIndex++) {
      const code = part.charCodeAt(charIndex);
      if (code < 48 || code > 57) {
        return '';
      }
    }
    const octet = Number.parseInt(part, 10);
    if (octet < 0 || octet > 255) {
      return '';
    }
    normalized.push(octet.toString());
  }
  return normalized.join('.');
}

function normalizedDomain(value: string): string {
  if (value.length === 0 || value.length > 253) {
    return '';
  }
  const labels = value.toLowerCase().split('.');
  let numericSingleLabel = labels.length === 1;
  for (let labelIndex = 0; labelIndex < labels.length; labelIndex++) {
    const label = labels[labelIndex];
    if (label.length === 0 || label.length > 63 ||
      label.startsWith('-') || label.endsWith('-') || label.startsWith('xn--')) {
      return '';
    }
    for (let charIndex = 0; charIndex < label.length; charIndex++) {
      const code = label.charCodeAt(charIndex);
      const isDigit = code >= 48 && code <= 57;
      const isLetter = code >= 97 && code <= 122;
      if (!isDigit && !isLetter && code !== 45) {
        return '';
      }
      if (!isDigit) {
        numericSingleLabel = false;
      }
    }
  }
  if (numericSingleLabel) {
    return '';
  }
  return labels.join('.');
}

export function firecrawlHttpUrlOf(
  value: Object | string | number | boolean | null | undefined
): string {
  if (typeof value !== 'string' || value.length === 0) {
    return '';
  }
  for (let index = 0; index < value.length; index++) {
    const code = value.charCodeAt(index);
    const isUnicodeWhitespace = code === 160 || code === 5760 ||
      (code >= 8192 && code <= 8202) || code === 8232 || code === 8233 ||
      code === 8239 || code === 8287 || code === 12288 || code === 65279;
    if (code <= 32 || code === 127 || isUnicodeWhitespace || code === 92) {
      return '';
    }
  }
  const lower = value.toLowerCase();
  let authorityStart = 0;
  let scheme = '';
  if (lower.startsWith('https://')) {
    authorityStart = 8;
    scheme = 'https';
  } else if (lower.startsWith('http://')) {
    authorityStart = 7;
    scheme = 'http';
  } else {
    return '';
  }
  let authorityEnd = value.length;
  const pathStart = value.indexOf('/', authorityStart);
  const queryStart = value.indexOf('?', authorityStart);
  const fragmentStart = value.indexOf('#', authorityStart);
  if (pathStart >= 0 && pathStart < authorityEnd) {
    authorityEnd = pathStart;
  }
  if (queryStart >= 0 && queryStart < authorityEnd) {
    authorityEnd = queryStart;
  }
  if (fragmentStart >= 0 && fragmentStart < authorityEnd) {
    authorityEnd = fragmentStart;
  }
  const authority = value.substring(authorityStart, authorityEnd);
  if (authority.length === 0 || authority.indexOf('@') >= 0) {
    return '';
  }
  const hostAndPort = authority;
  let normalizedHost = '';
  let portSuffix = '';
  if (hostAndPort.startsWith('[')) {
    const bracketEnd = hostAndPort.indexOf(']');
    if (bracketEnd <= 1) {
      return '';
    }
    const literal = hostAndPort.substring(1, bracketEnd);
    if (!validIpv6Literal(literal)) {
      return '';
    }
    normalizedHost = '[' + literal.toLowerCase() + ']';
    portSuffix = hostAndPort.substring(bracketEnd + 1);
  } else {
    if (hostAndPort.indexOf(':') !== hostAndPort.lastIndexOf(':')) {
      return '';
    }
    const portStart = hostAndPort.lastIndexOf(':');
    const hostname = portStart >= 0 ? hostAndPort.substring(0, portStart) : hostAndPort;
    portSuffix = portStart >= 0 ? hostAndPort.substring(portStart) : '';
    let numericOrDot = hostname.indexOf('.') >= 0;
    for (let index = 0; index < hostname.length && numericOrDot; index++) {
      const code = hostname.charCodeAt(index);
      numericOrDot = (code >= 48 && code <= 57) || code === 46;
    }
    normalizedHost = numericOrDot ? normalizedIpv4(hostname) : normalizedDomain(hostname);
  }
  if (normalizedHost.length === 0 || !validPortSuffix(portSuffix)) {
    return '';
  }
  let normalizedPort = '';
  if (portSuffix.length > 0) {
    const port = Number.parseInt(portSuffix.substring(1), 10);
    if ((scheme === 'http' && port !== 80) || (scheme === 'https' && port !== 443)) {
      normalizedPort = ':' + port.toString();
    }
  }
  return scheme + '://' + normalizedHost + normalizedPort + value.substring(authorityEnd);
}

function redactExact(value: string, config: FirecrawlConfig): string {
  let safe = value;
  if (config.apiKey.length > 0) {
    safe = safe.split(config.apiKey).join('[REDACTED]');
  }
  if (config.mcpUrl.length > 0) {
    safe = safe.split(config.mcpUrl).join('[REDACTED]');
  }
  return safe;
}

function providerStateText(parsed: FirecrawlPageResponse | null): string {
  const parts: string[] = [];
  if (parsed !== null) {
    parts.push(textOf(parsed.error));
    parts.push(textOf(parsed.message));
    parts.push(textOf(parsed.status));
  }
  return parts.join(' ').trim();
}

function failureText(call: McpToolCallResult, parsed: FirecrawlPageResponse | null): string {
  return [call.errorMessage, call.rawPreview, providerStateText(parsed)].join(' ').trim();
}

function normalizedStatus(httpStatus: number, message: string): FirecrawlResultStatus {
  const lower = message.toLowerCase();
  if (httpStatus === 401 || lower.indexOf('unauthorized') >= 0 ||
    lower.indexOf('authentication') >= 0 || lower.indexOf('api key') >= 0 ||
    lower.indexOf('credential') >= 0 || lower.indexOf('bearer') >= 0) {
    return 'needs_auth';
  }
  if (httpStatus === 402 || lower.indexOf('credit') >= 0 ||
    lower.indexOf('payment required') >= 0) {
    return 'credits_exhausted';
  }
  if (httpStatus === 429 || lower.indexOf('rate limit') >= 0 ||
    lower.indexOf('too many requests') >= 0) {
    return 'rate_limited';
  }
  if (lower.indexOf('timeout') >= 0 || lower.indexOf('timed out') >= 0) {
    return 'timeout';
  }
  return 'error';
}

function originBlockedSignal(message: string): boolean {
  const lower = message.toLowerCase();
  return lower.indexOf('login required') >= 0 ||
    lower.indexOf('log in to continue') >= 0 ||
    lower.indexOf('sign in to continue') >= 0 ||
    lower.indexOf('captcha') >= 0 ||
    lower.indexOf('robots.txt') >= 0 ||
    lower.indexOf('access denied') >= 0 ||
    lower.indexOf('blocked by site') >= 0 ||
    lower.indexOf('blocked-by-site') >= 0 ||
    lower.indexOf('forbidden by site') >= 0 ||
    lower.indexOf('请先登录') >= 0 ||
    lower.indexOf('登录后继续') >= 0 ||
    lower.indexOf('请输入验证码') >= 0 ||
    lower.indexOf('安全验证') >= 0;
}

function normalizedOriginStatus(httpStatus: number, message: string): FirecrawlResultStatus {
  if (httpStatus === 401 || httpStatus === 403 || originBlockedSignal(message)) {
    return 'blocked_by_site';
  }
  return normalizedStatus(httpStatus, message);
}

function normalizedScrapeFailureStatus(
  call: McpToolCallResult,
  page: FirecrawlPageResponse | null,
  parsed: ParsedFirecrawlPayload,
  metadataStatus: number
): FirecrawlResultStatus {
  const failure = [
    failureText(call, page),
    parsed.rawText
  ].join(' ').trim();
  if (page?.metadata?.statusCode !== undefined) {
    return normalizedOriginStatus(metadataStatus, failure);
  }
  const providerStatus = normalizedStatus(call.httpStatus, failure);
  if (providerStatus !== 'error') {
    return providerStatus;
  }
  return originBlockedSignal(failure) ? 'blocked_by_site' : 'error';
}

function explicitDnsFailure(message: string): boolean {
  const lower = message.toLowerCase();
  return lower.indexOf('could not resolve host') >= 0 ||
    lower.indexOf('dns_error') >= 0 ||
    lower.indexOf('name resolution') >= 0 ||
    lower.indexOf('curlcode result 6') >= 0 ||
    lower.indexOf('2300006') >= 0;
}

function loginOnlyBody(body: string): boolean {
  const lower = body.trim().toLowerCase();
  const gate = lower.indexOf('login required') >= 0 ||
    lower.indexOf('please log in') >= 0 ||
    lower.indexOf('sign in to continue') >= 0 ||
    lower.indexOf('verify human') >= 0 ||
    lower.indexOf('verify you are human') >= 0 ||
    lower.indexOf('登录后继续') >= 0 ||
    lower.indexOf('请先登录') >= 0 ||
    lower.indexOf('登录即可查看完整内容') >= 0 ||
    lower.indexOf('请输入验证码') >= 0 ||
    lower.indexOf('完成安全验证') >= 0 ||
    lower.indexOf('请进行安全验证') >= 0 ||
    lower.indexOf('打开 app 查看完整内容') >= 0 ||
    lower.indexOf('打开app查看完整内容') >= 0 ||
    lower.indexOf('打开小红书app查看完整内容') >= 0;
  if (!gate) {
    return false;
  }
  if (lower.length <= 600) {
    return true;
  }
  const withoutChrome = lower.split('navigation').join('').split('menu').join('').trim();
  return withoutChrome.length <= 600;
}

function registrationFor(
  businessToolId: string,
  mcpToolName: string,
  config: FirecrawlConfig
): DynamicToolRegistration {
  return {
    toolId: businessToolId,
    manifestId: 'firecrawl-hosted-mcp',
    displayName: 'Firecrawl',
    status: 'enabled',
    transport: {
      type: 'streamable_http',
      url: config.mcpUrl,
      command: '',
      args: [],
      headers: {},
      env: {}
    },
    mcpToolName: mcpToolName,
    credentialRef: 'provider:firecrawl',
    sourceUrl: config.mcpUrl,
    lastError: ''
  };
}

function parsePayload(result: McpToolResultPayload | null): ParsedFirecrawlPayload {
  if (result === null) {
    return { value: null, rawText: '' };
  }
  if (result.structuredContent !== undefined && result.structuredContent !== null) {
    return {
      value: result.structuredContent as FirecrawlPageResponse,
      rawText: ''
    };
  }
  const content: McpToolContentItem[] = result.content === undefined ? [] : result.content;
  for (let index = 0; index < content.length; index++) {
    if (content[index].type === 'text' && content[index].text !== undefined) {
      const rawText = content[index].text as string;
      try {
        return {
          value: JSON.parse(rawText) as FirecrawlPageResponse,
          rawText: rawText
        };
      } catch (_error) {
        return {
          value: null,
          rawText: rawText
        };
      }
    }
  }
  return { value: null, rawText: '' };
}

function pageResponseOf(value: FirecrawlPageResponse): FirecrawlPageResponse {
  const hasPageData = value.markdown !== undefined || value.json !== undefined ||
    value.metadata !== undefined || value.error !== undefined || value.message !== undefined;
  if (!hasPageData && value.data !== undefined && value.data !== null) {
    return value.data as FirecrawlPageResponse;
  }
  return value;
}

function warningsOf(value: FirecrawlUsageEnvelope | null): string[] {
  const warnings: string[] = [];
  if (value === null) {
    return warnings;
  }
  const metadata = value.metadata === null ? undefined : value.metadata;
  if (textOf(value.warning).trim().length > 0) {
    warnings.push(textOf(value.warning).trim());
  }
  if (Array.isArray(value.warnings)) {
    const topWarnings = value.warnings as (Object | string | number | boolean | null)[];
    for (let index = 0; index < topWarnings.length; index++) {
      if (typeof topWarnings[index] === 'string' && (topWarnings[index] as string).trim().length > 0) {
        const warning = (topWarnings[index] as string).trim();
        if (warnings.indexOf(warning) < 0) {
          warnings.push(warning);
        }
      }
    }
  }
  if (metadata !== undefined && textOf(metadata.warning).trim().length > 0) {
    const warning = textOf(metadata.warning).trim();
    if (warnings.indexOf(warning) < 0) {
      warnings.push(warning);
    }
  }
  if (metadata !== undefined && Array.isArray(metadata.warnings)) {
    const metadataWarnings = metadata.warnings as (Object | string | number | boolean | null)[];
    for (let index = 0; index < metadataWarnings.length; index++) {
      if (typeof metadataWarnings[index] === 'string' &&
        (metadataWarnings[index] as string).trim().length > 0) {
        const warning = (metadataWarnings[index] as string).trim();
        if (warnings.indexOf(warning) < 0) {
          warnings.push(warning);
        }
      }
    }
  }
  return warnings;
}

function usageOf(
  primary: FirecrawlUsageEnvelope | null,
  fallback: FirecrawlUsageEnvelope | null = null
): UsageSnapshot {
  const primaryCredits = primary === null ? '' :
    (textOf(primary.creditsUsed).trim().length > 0 ?
      textOf(primary.creditsUsed).trim() : textOf(primary.creditsBilled).trim());
  const fallbackCredits = fallback === null ? '' :
    (textOf(fallback.creditsUsed).trim().length > 0 ?
      textOf(fallback.creditsUsed).trim() : textOf(fallback.creditsBilled).trim());
  const warnings = warningsOf(primary);
  const fallbackWarnings = warningsOf(fallback);
  for (let index = 0; index < fallbackWarnings.length; index++) {
    if (warnings.indexOf(fallbackWarnings[index]) < 0) {
      warnings.push(fallbackWarnings[index]);
    }
  }
  return {
    credits: primaryCredits.length > 0 ? primaryCredits : fallbackCredits,
    warnings: warnings
  };
}

function aggregateUsage(values: UsageSnapshot[]): UsageSnapshot {
  let creditTotal = 0;
  let hasNumericCredits = false;
  const otherCredits: string[] = [];
  const warnings: string[] = [];
  for (let index = 0; index < values.length; index++) {
    const credits = values[index].credits.trim();
    if (credits.length > 0) {
      const numericCredits = Number(credits);
      if (Number.isFinite(numericCredits)) {
        creditTotal += numericCredits;
        hasNumericCredits = true;
      } else {
        otherCredits.push(credits);
      }
    }
    for (let warningIndex = 0; warningIndex < values[index].warnings.length; warningIndex++) {
      const warning = values[index].warnings[warningIndex];
      if (warnings.indexOf(warning) < 0) {
        warnings.push(warning);
      }
    }
  }
  const creditParts: string[] = [];
  if (hasNumericCredits) {
    creditParts.push(creditTotal.toString());
  }
  for (let index = 0; index < otherCredits.length; index++) {
    creditParts.push(otherCredits[index]);
  }
  return { credits: creditParts.join(' + '), warnings: warnings };
}

function usageRows(
  usage: UsageSnapshot,
  config: FirecrawlConfig,
  creditLabel: string = 'Credits'
): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [{
    label: creditLabel,
    value: usage.credits.length > 0 ? usage.credits : '未返回，以 Firecrawl 账户为准'
  }];
  if (usage.warnings.length > 0) {
    rows.push({
      label: '警告',
      value: redactExact(usage.warnings.join('\n'), config).substring(0, SHORT_PREVIEW_CHARS)
    });
  }
  return rows;
}

function appendRows(
  rows: A2uiLabelValueData[],
  additions: A2uiLabelValueData[]
): void {
  for (let index = 0; index < additions.length; index++) {
    rows.push(additions[index]);
  }
}

function resultWithRows(
  result: DynamicGenericToolResult,
  additions: A2uiLabelValueData[]
): DynamicGenericToolResult {
  appendRows(result.rows, additions);
  return result;
}

function searchUsageRows(
  search: SearchOutcome,
  config: FirecrawlConfig
): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  if (search.requestId.length > 0) {
    rows.push({ label: 'Search ID', value: search.requestId.substring(0, SUMMARY_CHARS) });
  }
  return rows.concat(usageRows(search.usage, config, 'Search Credits'));
}

function pageReadArguments(url: string, question: string): Object {
  if (question.length === 0) {
    const args: MarkdownPageReadCallArgs = {
      url: url,
      formats: ['markdown'],
      onlyMainContent: true
    };
    return args;
  }
  return JSON.parse(
    '{"url":' + JSON.stringify(url) + ',"formats":["json"],"jsonOptions":{"prompt":' +
    JSON.stringify(question) + ',"schema":{"type":"object","properties":{' +
    '"answer":{"type":"string"},"evidence":{"type":"array","items":{"type":"string"}}},' +
    '"required":["answer","evidence"]}},"onlyMainContent":true}'
  ) as Object;
}

function xiaohongshuSearchArguments(query: string): Object {
  return JSON.parse(
    '{"url":"https://www.xiaohongshu.com/search_result?keyword=' +
    encodeURIComponent(query) + '&source=web_search_result_notes",' +
    '"formats":["markdown"],"onlyMainContent":false,"waitFor":5000,"maxAge":0,' +
    '"storeInCache":false,"proxy":"auto","profile":{"name":' +
    JSON.stringify(XIAOHONGSHU_PROFILE) + ',"saveChanges":true}}'
  ) as Object;
}

function xiaohongshuCardsCode(limit: number): string {
  return "agent-browser eval 'JSON.stringify([...document.querySelectorAll(\"section.note-item\")]" +
    '.slice(0,' + limit.toString() + ').map(s=>({' +
    'title:(s.querySelector(\"a.title\")?.textContent||\"\").trim(),' +
    'author:(s.querySelector(\".name\")?.textContent||\"\").trim(),' +
    'published:(s.querySelector(\".time\")?.textContent||\"\").trim(),' +
    'url:new URL(s.querySelector(\"a.title\")?.getAttribute(\"href\")||\"\",location.origin).href,' +
    'coverUrl:(s.querySelector(\"a.cover img,img\")?.currentSrc||' +
    's.querySelector(\"a.cover img,img\")?.src||' +
    's.querySelector(\"a.cover img,img\")?.getAttribute(\"src\")||\"\"),' +
    'isVideo:!!s.querySelector(\"a.cover video,.video-icon,.play-icon,' +
    '[class*=video-icon],[class*=play-icon]\")' +
    "})))'";
}

function xiaohongshuDetailCode(url: string): string {
  return 'agent-browser open ' + JSON.stringify(url) + ' >/dev/null' +
    " && agent-browser wait 3500 >/dev/null && agent-browser eval 'JSON.stringify({" +
    'title:(document.querySelector(\".note-content .title\")?.textContent||\"\").trim(),' +
    'author:(document.querySelector(\".note-container .username\")?.textContent||\"\").trim(),' +
    'description:(document.querySelector(\".note-content .desc\")?.textContent||\"\").trim(),' +
    'imageUrls:[...new Set([...document.querySelectorAll(\".note-slider .swiper-slide img,' +
    '.xhs-slider-container .swiper-slide img\")].map(i=>i.currentSrc||i.src||' +
    'i.getAttribute(\"src\")||\"\").filter(u=>u.startsWith(\"http\")))].slice(0,12),' +
    'isVideo:!!document.querySelector(\".note-slider video,.xhs-video-player video,' +
    '[class*=video-player] video\"),' +
    'videoDuration:(()=>{const v=document.querySelector(\".note-slider video,' +
    '.xhs-video-player video,[class*=video-player] video\");' +
    'return v&&Number.isFinite(v.duration)?Math.round(v.duration):0})(),' +
    "url:location.href})'";
}

function agentBrowserJson(
  stdout: string
): Object | Object[] | string | number | boolean | null {
  let value: Object | Object[] | string | number | boolean | null;
  try {
    value = JSON.parse(stdout) as Object | Object[] | string | number | boolean | null;
  } catch (_error) {
    return null;
  }
  if (typeof value !== 'string') {
    return value;
  }
  try {
    return JSON.parse(value) as Object | Object[] | string | number | boolean | null;
  } catch (_error) {
    return null;
  }
}

function xiaohongshuCards(stdout: string, limit: number): XiaohongshuSearchCard[] {
  const value = agentBrowserJson(stdout);
  if (!Array.isArray(value)) {
    return [];
  }
  const candidates = value as (Object | string | number | boolean | null)[];
  const cards: XiaohongshuSearchCard[] = [];
  for (let index = 0; index < candidates.length && cards.length < limit; index++) {
    const candidate = candidates[index];
    if (candidate === null || typeof candidate !== 'object' || Array.isArray(candidate)) {
      continue;
    }
    const card = candidate as XiaohongshuSearchCard;
    const url = firecrawlHttpUrlOf(card.url);
    if (!domainMatches(url, 'xiaohongshu.com') ||
      (url.indexOf('/search_result/') < 0 && !isXiaohongshuPublicPost(url))) {
      continue;
    }
    cards.push({
      title: textOf(card.title).trim(),
      author: textOf(card.author).trim(),
      published: textOf(card.published).trim(),
      url: url,
      coverUrl: xiaohongshuMediaUrlOf(card.coverUrl),
      isVideo: card.isVideo === true
    });
  }
  return cards;
}

function xiaohongshuDetail(stdout: string): XiaohongshuNoteDetail | null {
  const value = agentBrowserJson(stdout);
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  const detail = value as XiaohongshuNoteDetail;
  const url = firecrawlHttpUrlOf(detail.url);
  if (!domainMatches(url, 'xiaohongshu.com')) {
    return null;
  }
  const imageUrls: string[] = [];
  const candidates = Array.isArray(detail.imageUrls) ? detail.imageUrls : [];
  for (let index = 0; index < candidates.length && imageUrls.length < 12; index++) {
    const imageUrl = xiaohongshuMediaUrlOf(candidates[index]);
    if (imageUrl.length > 0 && imageUrls.indexOf(imageUrl) < 0) {
      imageUrls.push(imageUrl);
    }
  }
  return {
    title: textOf(detail.title).trim(),
    author: textOf(detail.author).trim(),
    description: textOf(detail.description).trim(),
    url: url,
    imageUrls: imageUrls,
    isVideo: detail.isVideo === true,
    videoDuration: Number.isFinite(detail.videoDuration) ?
      Math.max(0, Math.floor(detail.videoDuration as number)) : 0
  };
}

function xiaohongshuMediaUrlOf(value: Object | string | number | boolean | null | undefined): string {
  const url = firecrawlHttpUrlOf(value);
  if (domainMatches(url, 'xhscdn.com') || domainMatches(url, 'xiaohongshu.com')) {
    return url;
  }
  return '';
}

function xiaohongshuLoginRequired(markdown: string): boolean {
  return markdown.indexOf('登录后查看搜索结果') >= 0 ||
    (markdown.indexOf('手机号登录') >= 0 && markdown.indexOf('获取验证码') >= 0);
}

function bounded(value: number | undefined, defaultValue: number, maximum: number): number {
  if (value === undefined || !Number.isFinite(value)) {
    return defaultValue;
  }
  return Math.max(1, Math.min(maximum, Math.floor(value)));
}

function normalizedDomains(values: string[] | undefined): DomainFilter {
  if (values === undefined) {
    return { valid: true, domains: [] };
  }
  if (!Array.isArray(values) || values.length === 0) {
    return { valid: false, domains: [] };
  }
  const domains: string[] = [];
  for (let index = 0; index < values.length; index++) {
    if (typeof values[index] !== 'string') {
      return { valid: false, domains: [] };
    }
    const candidate = values[index].trim();
    const domain = normalizedDomain(candidate);
    if (candidate.length === 0 || domain.length === 0) {
      return { valid: false, domains: [] };
    }
    if (domains.indexOf(domain) < 0) {
      domains.push(domain);
    }
  }
  return { valid: true, domains: domains };
}

function searchArguments(
  query: string,
  limit: number,
  domains: string[],
  tbs: string
): Object {
  const normalizedTbs = tbs.trim();
  const recency = normalizedTbs.length > 0 ?
    ',"tbs":' + JSON.stringify(normalizedTbs) : '';
  const includeDomains = domains.length > 0 ?
    ',"includeDomains":' + JSON.stringify(domains) : '';
  return JSON.parse(
    '{"query":' + JSON.stringify(query) + recency + ',"highlights":true,"limit":' +
    limit.toString() + includeDomains + ',"sources":[{"type":"web"}]}'
  ) as Object;
}

function productArguments(url: string): Object {
  return JSON.parse(
    '{"url":' + JSON.stringify(url) + ',"proxy":"basic","formats":["json"],' +
    '"jsonOptions":{"prompt":"Extract only independently attributable product offers explicitly ' +
    'visible on this exact page. Each merchant offer needs its platform, visible price, product ' +
    'identity and direct merchant or offer URL. Keep the evidence page URL. For a page-level ' +
    'reference price, return one offer using the page publisher and page URL. Keep model and ' +
    'variant separate. Never infer price, seller, URL, model or variant.",' +
    '"schema":{"type":"object","properties":{"offers":{"type":"array","maxItems":6,' +
    '"items":{"type":"object","properties":{"name":{"type":"string"},' +
    '"brand":{"type":"string"},"model":{"type":"string"},"variant":{"type":"string"},' +
    '"platform":{"type":"string"},"seller":{"type":"string"},' +
    '"offerUrl":{"type":"string"},"evidenceUrl":{"type":"string"},' +
    '"market":{"type":"string"},"currency":{"type":"string"},' +
    '"priceText":{"type":"string"},"listPriceText":{"type":"string"},' +
    '"salePriceText":{"type":"string"},"estimatedPriceText":{"type":"string"},' +
    '"couponText":{"type":"string"},"shippingText":{"type":"string"},' +
    '"specifications":{"type":"array","items":{"type":"string"}},' +
    '"strengths":{"type":"array","items":{"type":"string"}},' +
    '"limitations":{"type":"array","items":{"type":"string"}}},' +
    '"required":["name"]}}},"required":["offers"]}},' +
    '"onlyMainContent":true}'
  ) as Object;
}

function shoppingPrice(text: string, kind: string, currency: string = ''): ShoppingPrice {
  const normalized = text.trim().split('，').join(',').split(' ').join('');
  const lower = normalized.toLowerCase();
  const hasRange = normalized.indexOf('-') >= 0 || normalized.indexOf('~') >= 0 ||
    normalized.indexOf('至') >= 0;
  const hasStartingPrice = normalized.indexOf('起') >= 0 || lower.indexOf('from') >= 0;
  const isRmb = currency === 'CNY' ||
    normalized.indexOf('¥') >= 0 || normalized.indexOf('￥') >= 0 ||
    normalized.indexOf('元') >= 0;
  const priceLabels: string[] = [
    '预估到手价', '预估到手', '券后价', '到手价', '销售价', '售价', '现价',
    '成交价', '优惠价', '价格'
  ];
  let digits = normalized;
  for (let index = 0; index < priceLabels.length; index++) {
    digits = digits.split(priceLabels[index]).join('');
  }
  digits = digits.split('¥').join('').split('￥').join('')
    .split('元').join('').split(',').join('');
  const value = Number(digits);
  const comparableKind = kind === 'public' || kind === 'estimated';
  const comparable = comparableKind && isRmb && !hasRange && !hasStartingPrice &&
    Number.isFinite(value) && value > 0;
  return {
    text: text.trim(),
    kind: kind,
    valueFen: comparable ? Math.round(value * 100) : 0,
    comparable: comparable
  };
}

function shoppingOptionalText(value: string): string {
  const text = value.trim();
  const normalized = normalizedProductText(text);
  const absent: string[] = [
    '', '无', '暂无', '未知', '未提供', '不详', 'none', 'null', 'n a', 'na', '-', '—'
  ];
  return absent.indexOf(normalized) >= 0 ? '' : text;
}

function shoppingPlatformForUrl(url: string): string {
  if (domainMatches(url, 'zol.com.cn')) {
    return '中关村在线';
  }
  if (domainMatches(url, 'pconline.com.cn')) {
    return '太平洋电脑网';
  }
  if (domainMatches(url, 'jd.com')) {
    return '京东';
  }
  if (domainMatches(url, 'tmall.com')) {
    return '天猫';
  }
  if (domainMatches(url, 'taobao.com')) {
    return '淘宝';
  }
  if (domainMatches(url, 'idealo.de')) {
    return 'Idealo';
  }
  if (domainMatches(url, 'amazon.com')) {
    return 'Amazon';
  }
  if (domainMatches(url, 'bestbuy.com')) {
    return 'Best Buy';
  }
  if (domainMatches(url, 'bhphotovideo.com')) {
    return 'B&H';
  }
  return '';
}

function shoppingOfferCurrency(offer: FirecrawlOfferData): string {
  const explicit = shoppingOptionalText(textOf(offer.currency)).toUpperCase();
  if (explicit.length > 0) {
    return explicit;
  }
  const price = textOf(offer.salePriceText) + textOf(offer.estimatedPriceText) +
    textOf(offer.priceText) + textOf(offer.listPriceText);
  if (price.indexOf('¥') >= 0 || price.indexOf('￥') >= 0 || price.indexOf('元') >= 0) {
    return 'CNY';
  }
  if (price.indexOf('€') >= 0) {
    return 'EUR';
  }
  if (price.indexOf('$') >= 0) {
    return 'USD';
  }
  if (price.indexOf('£') >= 0) {
    return 'GBP';
  }
  return '';
}

function shoppingOfferMarket(offer: FirecrawlOfferData, evidenceUrl: string): string {
  const explicit = shoppingOptionalText(textOf(offer.market)).toUpperCase();
  if (explicit.length > 0) {
    return explicit;
  }
  const currency = shoppingOfferCurrency(offer);
  if (currency === 'CNY' || domainMatches(evidenceUrl, 'zol.com.cn') ||
    domainMatches(evidenceUrl, 'pconline.com.cn') || domainMatches(evidenceUrl, 'jd.com') ||
    domainMatches(evidenceUrl, 'tmall.com') || domainMatches(evidenceUrl, 'taobao.com')) {
    return 'CN';
  }
  return 'INTL';
}

function shoppingOffersOf(value: Object, evidenceUrl: string): FirecrawlOfferData[] {
  const envelope = value as FirecrawlOfferEnvelope;
  const rawOffers = Array.isArray(envelope.offers) ?
    envelope.offers as (Object | string | number | boolean | null)[] : [];
  const offers: FirecrawlOfferData[] = [];
  let pageReferenceAdded = false;
  for (let index = 0; index < rawOffers.length; index++) {
    const raw = rawOffers[index];
    if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
      continue;
    }
    const offer = raw as FirecrawlOfferData;
    if (shoppingOptionalText(textOf(offer.name)).length === 0) {
      continue;
    }
    let offerUrl = firecrawlHttpUrlOf(offer.offerUrl);
    let platform = shoppingOptionalText(textOf(offer.platform));
    if (offerUrl.length > 0 && platform.length === 0) {
      platform = shoppingPlatformForUrl(offerUrl);
    }
    if (offerUrl.length === 0) {
      if (pageReferenceAdded) {
        continue;
      }
      offerUrl = evidenceUrl;
      platform = shoppingPlatformForUrl(evidenceUrl);
      pageReferenceAdded = true;
    }
    if (offerUrl.length === 0 || platform.length === 0) {
      continue;
    }
    offer.offerUrl = offerUrl;
    offer.platform = platform;
    if (firecrawlHttpUrlOf(offer.evidenceUrl).length === 0) {
      offer.evidenceUrl = evidenceUrl;
    }
    offers.push(offer);
  }
  if (offers.length > 0) {
    return offers;
  }
  const legacy = value as FirecrawlOfferData;
  if (shoppingOptionalText(textOf(legacy.name)).length === 0) {
    return [];
  }
  const platform = shoppingPlatformForUrl(evidenceUrl);
  if (platform.length === 0) {
    return [];
  }
  legacy.platform = platform;
  legacy.offerUrl = evidenceUrl;
  legacy.evidenceUrl = evidenceUrl;
  legacy.market = shoppingOfferMarket(legacy, evidenceUrl);
  legacy.currency = shoppingOfferCurrency(legacy);
  return [legacy];
}

function shoppingPriceEvidenceText(value: string, currency: string = ''): string {
  const text = shoppingOptionalText(value);
  const compact = text.split(' ').join('');
  const explicitPriceLabels: string[] = [
    '预估到手价', '预估到手', '券后价', '到手价', '销售价', '售价', '现价',
    '成交价', '优惠价', '价格'
  ];
  const savingsLabels: string[] = [
    '立减', '直降', '节省', '优惠', '省', '减免', '返现'
  ];
  let explicitPrice = false;
  for (let index = 0; index < explicitPriceLabels.length; index++) {
    if (compact.indexOf(explicitPriceLabels[index]) >= 0) {
      explicitPrice = true;
      break;
    }
  }
  if (!explicitPrice) {
    for (let index = 0; index < savingsLabels.length; index++) {
      if (compact.indexOf(savingsLabels[index]) >= 0) {
        return '';
      }
    }
  }
  const hasCurrency = currency.length > 0 ||
    text.indexOf('¥') >= 0 || text.indexOf('￥') >= 0 ||
    text.indexOf('元') >= 0 || text.indexOf('$') >= 0 ||
    text.indexOf('€') >= 0 || text.indexOf('£') >= 0;
  let hasDigit = false;
  for (let index = 0; index < text.length; index++) {
    const code = text.charCodeAt(index);
    if (code >= 48 && code <= 57) {
      hasDigit = true;
      break;
    }
  }
  return hasCurrency && hasDigit ? text : '';
}

function normalizedProductText(value: string): string {
  const source = value.trim().toLowerCase();
  const separators = '，,。；;：:（）()[]【】{}-_+/\\';
  let normalized = '';
  let previousWasSpace = true;
  for (let index = 0; index < source.length; index++) {
    const char = source.charAt(index);
    const isSpace = source.charCodeAt(index) <= 32 || separators.indexOf(char) >= 0;
    if (isSpace) {
      if (!previousWasSpace) {
        normalized += ' ';
      }
      previousWasSpace = true;
    } else {
      normalized += char;
      previousWasSpace = false;
    }
  }
  return normalized.trim();
}

function productCapacity(value: string): string {
  const tokens = normalizedProductText(value).split(' ');
  for (let index = 0; index < tokens.length; index++) {
    const token = tokens[index];
    const unit = token.endsWith('gb') || token.endsWith('tb') || token.endsWith('mb');
    const digits = token.substring(0, token.length - 2);
    if (!unit || digits.length === 0) {
      continue;
    }
    let numeric = true;
    for (let digitIndex = 0; digitIndex < digits.length; digitIndex++) {
      const code = digits.charCodeAt(digitIndex);
      if (code < 48 || code > 57) {
        numeric = false;
        break;
      }
    }
    if (numeric) {
      return token;
    }
  }
  return '';
}

function productSize(value: string): string {
  const normalized = value.toLowerCase().split(' ').join('');
  const marker = normalized.indexOf('英寸') >= 0 ? '英寸' : (normalized.indexOf('寸') >= 0 ? '寸' : '');
  const markerIndex = marker.length === 0 ? -1 : normalized.indexOf(marker);
  if (markerIndex <= 0) {
    return '';
  }
  let start = markerIndex - 1;
  while (start >= 0) {
    const code = normalized.charCodeAt(start);
    if ((code < 48 || code > 57) && normalized.charAt(start) !== '.') {
      break;
    }
    start--;
  }
  return normalized.substring(start + 1, markerIndex + marker.length);
}

function productTextTokens(value: string): string[] {
  const source = normalizedProductText(value);
  const tokens: string[] = [];
  let token = '';
  for (let index = 0; index < source.length; index++) {
    const code = source.charCodeAt(index);
    const isAsciiLetter = (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
    if (isAsciiLetter) {
      token += source.charAt(index);
    } else if (token.length > 0) {
      if (tokens.indexOf(token) < 0) {
        tokens.push(token);
      }
      token = '';
    }
  }
  if (token.length > 0 && tokens.indexOf(token) < 0) {
    tokens.push(token);
  }
  return tokens;
}

function shoppingTitleHasUnexpectedTier(name: string, model: string, query: string): boolean {
  const nameTokens = productTextTokens(name);
  const modelTokens = productTextTokens(model);
  const queryTokens = productTextTokens(query);
  const tierTokens: string[] = ['max', 'ultra', 'plus'];
  for (let index = 0; index < tierTokens.length; index++) {
    if ((nameTokens.indexOf(tierTokens[index]) >= 0 ||
      modelTokens.indexOf(tierTokens[index]) >= 0) &&
      queryTokens.indexOf(tierTokens[index]) < 0) {
      return true;
    }
  }
  return false;
}

function shoppingChineseRuns(value: string): string[] {
  const runs: string[] = [];
  let run = '';
  for (let index = 0; index < value.length; index++) {
    const code = value.charCodeAt(index);
    if (code >= 19968 && code <= 40959) {
      run += value.charAt(index);
    } else if (run.length > 0) {
      runs.push(run);
      run = '';
    }
  }
  if (run.length > 0) {
    runs.push(run);
  }
  return runs;
}

function shoppingSuffixTerm(value: string, suffixEnd: number): string {
  const beforeSuffix = value.substring(0, suffixEnd + 1);
  const prefixes: string[] = ['比较', '对比', '我想要', '我想买', '想要', '想买', '需要', '我要', '的', '要', '买'];
  let start = 0;
  for (let index = 0; index < prefixes.length; index++) {
    const prefixIndex = beforeSuffix.lastIndexOf(prefixes[index]);
    if (prefixIndex >= 0 && prefixIndex + prefixes[index].length > start) {
      start = prefixIndex + prefixes[index].length;
    }
  }
  return beforeSuffix.substring(start);
}

function shoppingVariantTokens(query: string): string[] {
  const tokens: string[] = [];
  const runs = shoppingChineseRuns(normalizedProductText(query));
  for (let index = 0; index < runs.length; index++) {
    const colorEnd = runs[index].indexOf('色');
    const bundleEnd = runs[index].indexOf('装');
    if (colorEnd >= 0) {
      const color = shoppingSuffixTerm(runs[index], colorEnd);
      if (color !== '颜色' && tokens.indexOf(color) < 0) {
        tokens.push(color);
      }
    }
    if (bundleEnd >= 0) {
      const bundle = shoppingSuffixTerm(runs[index], bundleEnd);
      if (tokens.indexOf(bundle) < 0) {
        tokens.push(bundle);
      }
    }
  }
  return tokens;
}

function shoppingVariantEvidence(product: FirecrawlProductData): string {
  return normalizedProductText(
    textOf(product.name) + ' ' + textOf(product.model) + ' ' + textOf(product.variant)
  );
}

function shoppingRequestedVariantConflicts(
  query: string,
  product: FirecrawlProductData
): boolean {
  const evidence = shoppingVariantEvidence(product);
  const capacity = productCapacity(query);
  const observedCapacity = productCapacity(evidence);
  if (capacity.length > 0 && observedCapacity.length > 0 && observedCapacity !== capacity) {
    return true;
  }
  const size = productSize(query);
  const observedSize = productSize(evidence);
  if (size.length > 0 && observedSize.length > 0 && observedSize !== size) {
    return true;
  }
  const tokens = shoppingVariantTokens(query);
  for (let index = 0; index < tokens.length; index++) {
    if (evidence.indexOf(tokens[index]) >= 0) {
      continue;
    }
    const marker = tokens[index].indexOf('色') >= 0 ? '色' :
      (tokens[index].indexOf('装') >= 0 ? '装' : '');
    if (marker.length > 0 && evidence.indexOf(marker) >= 0) {
      return true;
    }
  }
  return false;
}

function shoppingRequestedVariantConfirmed(
  query: string,
  product: FirecrawlProductData
): boolean {
  const evidence = shoppingVariantEvidence(product);
  const capacity = productCapacity(query);
  if (capacity.length > 0 && evidence.indexOf(capacity) < 0) {
    return false;
  }
  const size = productSize(query);
  if (size.length > 0 && evidence.indexOf(size) < 0) {
    return false;
  }
  const tokens = shoppingVariantTokens(query);
  for (let index = 0; index < tokens.length; index++) {
    if (evidence.indexOf(tokens[index]) < 0) {
      return false;
    }
  }
  return true;
}

function shoppingProductMatches(query: string, product: FirecrawlProductData): boolean {
  const name = typeof product.name === 'string' ? product.name : '';
  const model = typeof product.model === 'string' ? product.model : '';
  const queryText = normalizedProductText(query);
  const accessoryMarkers: string[] = ['壳', '保护套', '贴膜', '配件', '滤芯'];
  for (let index = 0; index < accessoryMarkers.length; index++) {
    if (normalizedProductText(name).indexOf(accessoryMarkers[index]) >= 0 &&
      queryText.indexOf(accessoryMarkers[index]) < 0) {
      return false;
    }
  }
  if (shoppingRequestedVariantConflicts(query, product)) {
    return false;
  }
  return !shoppingTitleHasUnexpectedTier(name, model, query);
}

function shoppingComparisonBrand(value: string): string {
  const normalized = normalizedProductText(value);
  const padded = ' ' + normalized + ' ';
  if (normalized.indexOf('索尼') >= 0 || padded.indexOf(' sony ') >= 0) {
    return 'sony';
  }
  if (normalized.indexOf('戴森') >= 0 || padded.indexOf(' dyson ') >= 0) {
    return 'dyson';
  }
  if (normalized.indexOf('苹果') >= 0 || padded.indexOf(' apple ') >= 0) {
    return 'apple';
  }
  if (normalized.indexOf('乐高') >= 0 || padded.indexOf(' lego ') >= 0) {
    return 'lego';
  }
  if (normalized.indexOf('米家') >= 0 || padded.indexOf(' mijia ') >= 0) {
    return 'mijia';
  }
  if (normalized.indexOf('小米') >= 0 || padded.indexOf(' xiaomi ') >= 0) {
    return 'xiaomi';
  }
  return normalized;
}

function shoppingComparisonVariant(value: string): string {
  return normalizedProductText(shoppingOptionalText(value));
}

function shoppingComparisonBrandFromName(value: string): string {
  const brand = shoppingComparisonBrand(value);
  const known: string[] = ['sony', 'dyson', 'apple', 'lego', 'mijia', 'xiaomi'];
  return known.indexOf(brand) >= 0 ? brand : '';
}

function shoppingComparisonKey(product: FirecrawlProductData): string {
  const brand = typeof product.brand === 'string' ?
    shoppingOptionalText(product.brand) : '';
  const name = typeof product.name === 'string' ? product.name : '';
  const model = typeof product.model === 'string' && product.model.trim().length > 0 ?
    product.model : name;
  const comparisonBrand = brand.length > 0 ?
    shoppingComparisonBrand(brand) : shoppingComparisonBrandFromName(name);
  const identity = normalizedProductText(
    (comparisonBrand + ' ' + model).trim()
  );
  const variant = typeof product.variant === 'string' ?
    shoppingComparisonVariant(product.variant) : '';
  return variant.length > 0 ? identity + '|' + variant : identity;
}

function shoppingCandidateScore(query: string, item: FirecrawlSearchItem): number {
  const shortInstructionTokens: string[] = ['的', '要', '买', '查', '找', '搜', '看', '比', '价'];
  const tokens = query.trim().split(' ').filter((token: string): boolean =>
    token.length > 0 && !(token.length < 2 && shortInstructionTokens.indexOf(token) >= 0)
  );
  const title = textOf(item.title).toLowerCase();
  const description = textOf(item.description).toLowerCase();
  let score = 0;
  for (let index = 0; index < tokens.length; index++) {
    const token = tokens[index].toLowerCase();
    if (title.indexOf(token) >= 0) {
      score += 2;
    }
    if (description.indexOf(token) >= 0) {
      score++;
    }
  }
  const accessoryMarkers: string[] = ['配件', '滤芯', '保护套'];
  for (let index = 0; index < accessoryMarkers.length; index++) {
    if (title.indexOf(accessoryMarkers[index]) >= 0 &&
      query.indexOf(accessoryMarkers[index]) < 0) {
      score -= 20;
    }
  }
  return score;
}

function shoppingDomainRank(url: string, domains: string[]): number {
  for (let index = 0; index < domains.length; index++) {
    if (domainMatches(url, domains[index])) {
      return index;
    }
  }
  return domains.length;
}

function rankedShoppingCandidates(
  query: string,
  items: FirecrawlSearchItem[],
  domains: string[]
): FirecrawlSearchItem[] {
  const candidates = uniqueSearchItems(items.filter(
    (item: FirecrawlSearchItem): boolean => {
      const url = textOf(item.url);
      if (!isProductEvidenceSource(url)) {
        return false;
      }
      for (let index = 0; index < domains.length; index++) {
        if (domainMatches(url, domains[index])) {
          return true;
        }
      }
      return false;
    }
  ), 12);
  candidates.sort((left: FirecrawlSearchItem, right: FirecrawlSearchItem): number => {
    const scoreDifference =
      shoppingCandidateScore(query, right) - shoppingCandidateScore(query, left);
    if (scoreDifference !== 0) {
      return scoreDifference;
    }
    return shoppingDomainRank(textOf(left.url), domains) -
      shoppingDomainRank(textOf(right.url), domains);
  });
  return candidates;
}

function hasTwoComparableShoppingOffers(results: DynamicGenericToolResult[]): boolean {
  for (let index = 0; index < results.length; index++) {
    if (rowValueOf(results[index].rows, 'comparisonEligible') !== 'true') {
      continue;
    }
    const key = rowValueOf(results[index].rows, 'comparisonKey');
    if (key.length === 0) {
      continue;
    }
    for (let other = index + 1; other < results.length; other++) {
      if (rowValueOf(results[other].rows, 'comparisonEligible') === 'true' &&
        rowValueOf(results[other].rows, 'comparisonKey') === key) {
        return true;
      }
    }
  }
  return false;
}

function shoppingResultSort(
  left: DynamicGenericToolResult,
  right: DynamicGenericToolResult
): number {
  const leftEligible = rowValueOf(left.rows, 'comparisonEligible') === 'true';
  const rightEligible = rowValueOf(right.rows, 'comparisonEligible') === 'true';
  const leftPriceText = rowValueOf(left.rows, '价格');
  const rightPriceText = rowValueOf(right.rows, '价格');
  const leftPrice = (leftPriceText.length > 0 && leftPriceText !== '价格未知') ||
    rowValueOf(left.rows, '预估到手价').length > 0;
  const rightPrice = (rightPriceText.length > 0 && rightPriceText !== '价格未知') ||
    rowValueOf(right.rows, '预估到手价').length > 0;
  const leftRank = leftEligible ? 0 : (leftPrice ? 1 : 2);
  const rightRank = rightEligible ? 0 : (rightPrice ? 1 : 2);
  if (leftRank !== rightRank) {
    return leftRank - rightRank;
  }
  const leftKey = rowValueOf(left.rows, 'comparisonKey');
  const rightKey = rowValueOf(right.rows, 'comparisonKey');
  if (leftRank === 0 && leftKey === rightKey) {
    const priceDifference = Number(rowValueOf(left.rows, 'comparisonPriceFen')) -
      Number(rowValueOf(right.rows, 'comparisonPriceFen'));
    if (priceDifference !== 0) {
      return priceDifference;
    }
  }
  const leftUrl = rowValueOf(left.rows, 'URL');
  const rightUrl = rowValueOf(right.rows, 'URL');
  let leftHost = leftUrl;
  let rightHost = rightUrl;
  for (let index = 0; index < SHOPPING_SOURCE_DOMAINS.length; index++) {
    if (domainMatches(leftUrl, SHOPPING_SOURCE_DOMAINS[index])) {
      leftHost = SHOPPING_SOURCE_DOMAINS[index];
    }
    if (domainMatches(rightUrl, SHOPPING_SOURCE_DOMAINS[index])) {
      rightHost = SHOPPING_SOURCE_DOMAINS[index];
    }
  }
  return leftHost < rightHost ? -1 : (leftHost > rightHost ? 1 : 0);
}

function stringList(value: Object | string | number | boolean | null | undefined): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const items = value as (Object | string | number | boolean | null)[];
  const strings: string[] = [];
  for (let index = 0; index < items.length; index++) {
    if (typeof items[index] === 'string') {
      const item = (items[index] as string).trim();
      if (item.length > 0 && strings.indexOf(item) < 0) {
        strings.push(item);
      }
    }
  }
  return strings;
}

function preferenceList(
  value: Object | string | number | boolean | null | undefined
): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const items = value as (Object | string | number | boolean | null)[];
  const preferences: string[] = [];
  let totalLength = 0;
  for (let index = 0; index < items.length && preferences.length < 5; index++) {
    if (typeof items[index] !== 'string') {
      continue;
    }
    const item = (items[index] as string).trim().substring(0, 80);
    if (item.length === 0 || preferences.indexOf(item) >= 0) {
      continue;
    }
    const separatorLength = preferences.length > 0 ? 1 : 0;
    const remaining = 240 - totalLength - separatorLength;
    if (remaining <= 0) {
      break;
    }
    if (item.length > remaining) {
      const truncated = item.substring(0, remaining);
      if (preferences.indexOf(truncated) >= 0) {
        continue;
      }
      preferences.push(truncated);
      break;
    }
    preferences.push(item);
    totalLength += separatorLength + item.length;
  }
  return preferences;
}

function sourceActions(url: string): A2uiAction[] {
  const open: A2uiAction = {
    id: 'web.open.source',
    label: '打开原网页',
    prompt: url,
    kind: 'client',
    variant: 'secondary'
  };
  const readArgs: SourceUrlArgs = { url: url };
  const read: A2uiAction = {
    id: 'web.page.read',
    label: '深入阅读此来源',
    prompt: '深入阅读此来源',
    kind: 'prompt',
    variant: 'secondary',
    args: readArgs
  };
  return [open, read];
}

function monitorPages(values: string[] | undefined): string[] {
  if (values === undefined || !Array.isArray(values)) {
    return [];
  }
  const pages: string[] = [];
  for (let index = 0; index < values.length && pages.length < 5; index++) {
    if (typeof values[index] !== 'string') {
      continue;
    }
    const page = firecrawlHttpUrlOf(values[index]);
    if (page.length > 0 && pages.indexOf(page) < 0) {
      pages.push(page);
    }
  }
  return pages;
}

function monitorQueries(values: string[] | undefined): string[] {
  if (values === undefined || !Array.isArray(values)) {
    return [];
  }
  const queries: string[] = [];
  for (let index = 0; index < values.length && queries.length < 3; index++) {
    if (typeof values[index] !== 'string') {
      continue;
    }
    const query = values[index].trim();
    if (query.length > 0 && queries.indexOf(query) < 0) {
      queries.push(query);
    }
  }
  return queries;
}

function monitorCreateArgs(
  pages: string[],
  queries: string[],
  goal: string,
  name: string,
  scheduleText: string,
  timezone: string,
  email: string,
  confirmation: boolean
): Object {
  const fields: string[] = [];
  if (pages.length > 0) {
    if (confirmation || pages.length > 1) {
      fields.push('"pages":' + JSON.stringify(pages));
    } else {
      fields.push('"page":' + JSON.stringify(pages[0]));
    }
  }
  if (queries.length > 0) {
    fields.push('"queries":' + JSON.stringify(queries));
  }
  fields.push('"goal":' + JSON.stringify(goal));
  if (name.length > 0) {
    fields.push('"name":' + JSON.stringify(name));
  }
  fields.push('"scheduleText":' + JSON.stringify(scheduleText));
  fields.push('"timezone":' + JSON.stringify(timezone));
  if (email.length > 0) {
    fields.push('"email":' + JSON.stringify(email));
  }
  if (confirmation) {
    fields.push('"confirmed":true');
  }
  return JSON.parse('{' + fields.join(',') + '}') as Object;
}

function monitorEstimate(pages: string[], queries: string[], scheduleText: string): string {
  if (queries.length > 0) {
    return '近似值；Provider 实际用量未知';
  }
  let checks = 0;
  if (scheduleText.toLowerCase() === 'daily') {
    checks = 30;
  } else if (scheduleText.toLowerCase() === 'hourly') {
    checks = 720;
  } else if (scheduleText.toLowerCase() === 'weekly') {
    checks = 4;
  }
  return checks > 0 ?
    (pages.length * checks).toString() + ' checks/month（估算）' :
    'Provider estimate unavailable';
}

function monitorArgs(id: string, checkId: string = '', confirmed: boolean = false): Object {
  const fields: string[] = ['"id":' + JSON.stringify(id)];
  if (checkId.length > 0) {
    fields.push('"checkId":' + JSON.stringify(checkId));
  }
  if (confirmed) {
    fields.push('"confirmed":true');
  }
  return JSON.parse('{' + fields.join(',') + '}') as Object;
}

function monitorAction(
  actionId: string,
  label: string,
  id: string,
  variant: string = 'secondary',
  confirmed: boolean = false
): A2uiAction {
  return {
    id: actionId,
    label: label,
    prompt: label,
    kind: 'prompt',
    variant: variant,
    args: monitorArgs(id, '', confirmed)
  };
}

function monitorActions(id: string): A2uiAction[] {
  return [
    monitorAction('web.monitor.detail', '查看详情', id),
    monitorAction('web.monitor.checks', '查看检查记录', id),
    monitorAction('web.monitor.run', '立即运行', id),
    monitorAction('web.monitor.pause', '暂停监控', id),
    monitorAction('web.monitor.resume', '恢复监控', id),
    monitorAction('web.monitor.delete', '删除监控', id, 'danger')
  ];
}

function monitorItems(
  value: FirecrawlMonitorEnvelope,
  collection: string
): FirecrawlMonitorItem[] {
  let candidates: (Object | string | number | boolean | null)[] = [];
  const data = value.data;
  if (Array.isArray(data)) {
    candidates = data as (Object | string | number | boolean | null)[];
  } else if (data !== null && data !== undefined && typeof data === 'object') {
    const dataEnvelope = data as FirecrawlMonitorEnvelope;
    const nested = collection === 'checks' ? dataEnvelope.checks : dataEnvelope.monitors;
    if (Array.isArray(nested)) {
      candidates = nested;
    } else {
      candidates = [data];
    }
  } else {
    const topLevel = collection === 'checks' ? value.checks : value.monitors;
    if (Array.isArray(topLevel)) {
      candidates = topLevel;
    } else if (textOf(value.id).trim().length > 0) {
      candidates = [value as Object];
    }
  }
  const items: FirecrawlMonitorItem[] = [];
  for (let index = 0; index < candidates.length; index++) {
    if (candidates[index] !== null && typeof candidates[index] === 'object' &&
      !Array.isArray(candidates[index])) {
      items.push(candidates[index] as FirecrawlMonitorItem);
    }
  }
  return items;
}

function sourceRows(
  url: string,
  status: FirecrawlResultStatus,
  fetchedAt: string,
  publishedAt: string = ''
): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [
    { label: 'URL', value: url },
    { label: '抓取时间', value: fetchedAt }
  ];
  if (publishedAt.length > 0) {
    rows.push({ label: '发布时间', value: publishedAt });
  }
  rows.push({ label: 'Provider 状态', value: status });
  return rows;
}

function rowValueOf(rows: A2uiLabelValueData[], label: string): string {
  const row = rows.find((item: A2uiLabelValueData): boolean => item.label === label);
  return row === undefined ? '' : row.value;
}

function wantsDeepResearch(prompt: string): boolean {
  const lower = prompt.toLowerCase();
  const markers: string[] = [
    '研究', '比较', '对比', '总结', '综合',
    'research', 'compare', 'comparison', 'summary', 'summarize'
  ];
  for (let index = 0; index < markers.length; index++) {
    if (lower.indexOf(markers[index]) >= 0) {
      return true;
    }
  }
  return false;
}

function uniqueSearchItems(items: FirecrawlSearchItem[], limit: number): FirecrawlSearchItem[] {
  const unique: FirecrawlSearchItem[] = [];
  const urls: string[] = [];
  for (let index = 0; index < items.length && unique.length < limit; index++) {
    const url = firecrawlHttpUrlOf(items[index].url);
    const fragmentStart = url.indexOf('#');
    const dedupeUrl = fragmentStart >= 0 ? url.substring(0, fragmentStart) : url;
    if (url.length > 0 && urls.indexOf(dedupeUrl) < 0) {
      urls.push(dedupeUrl);
      unique.push({
        url: url,
        title: textOf(items[index].title).trim(),
        description: textOf(items[index].description).trim(),
        markdown: textOf(items[index].markdown).trim(),
        publishedDate: textOf(items[index].publishedDate).trim()
      });
    }
  }
  return unique;
}

function aggregateStatus(results: DynamicGenericToolResult[]): FirecrawlResultStatus {
  let successes = 0;
  let hasPartial = false;
  let firstFailure: FirecrawlResultStatus = 'empty';
  for (let index = 0; index < results.length; index++) {
    if (results[index].status === 'success') {
      successes++;
    } else if (results[index].status === 'partial') {
      hasPartial = true;
    } else if (firstFailure === 'empty' && results[index].status !== 'empty') {
      firstFailure = results[index].status as FirecrawlResultStatus;
    }
  }
  if (successes === results.length && successes > 0) {
    return 'success';
  }
  if (successes > 0 || hasPartial) {
    return 'partial';
  }
  return firstFailure;
}

function socialPlatformStatus(results: DynamicGenericToolResult[]): FirecrawlResultStatus {
  if (results.length === 0) {
    return 'empty';
  }
  let successCount = 0;
  let hasPartialEvidence = false;
  let hasBlocked = false;
  for (let index = 0; index < results.length; index++) {
    const status = results[index].status;
    if (status === 'success') {
      successCount++;
    } else if (status === 'partial') {
      hasPartialEvidence = true;
    } else if (status === 'blocked_by_site') {
      hasBlocked = true;
    } else if (status !== 'empty') {
      hasPartialEvidence = true;
    }
  }
  if (successCount === results.length) {
    return 'success';
  }
  if (successCount > 0 || hasPartialEvidence) {
    return 'partial';
  }
  return hasBlocked ? 'blocked_by_site' : 'empty';
}

function socialPlatforms(_values: string[] | undefined): SocialPlatform[] {
  // social.public.search is intentionally a Xiaohongshu-only product surface.
  // Keep the execution boundary aligned even when an LLM omits or overfills platforms.
  return [{ name: '小红书', domain: 'xiaohongshu.com' }];
}

function domainMatches(url: string, domain: string): boolean {
  const schemeEnd = url.indexOf('://');
  if (schemeEnd < 0) {
    return false;
  }
  let hostEnd = url.length;
  const pathStart = url.indexOf('/', schemeEnd + 3);
  const queryStart = url.indexOf('?', schemeEnd + 3);
  const fragmentStart = url.indexOf('#', schemeEnd + 3);
  if (pathStart >= 0 && pathStart < hostEnd) {
    hostEnd = pathStart;
  }
  if (queryStart >= 0 && queryStart < hostEnd) {
    hostEnd = queryStart;
  }
  if (fragmentStart >= 0 && fragmentStart < hostEnd) {
    hostEnd = fragmentStart;
  }
  const authority = url.substring(schemeEnd + 3, hostEnd);
  const portStart = authority.lastIndexOf(':');
  const host = (portStart >= 0 ? authority.substring(0, portStart) : authority).toLowerCase();
  return host === domain || host.endsWith('.' + domain);
}

function isXiaohongshuPublicPost(url: string): boolean {
  const normalized = firecrawlHttpUrlOf(url).toLowerCase();
  return normalized.indexOf('://xiaohongshu.com/explore/') >= 0 ||
    normalized.indexOf('://www.xiaohongshu.com/explore/') >= 0 ||
    normalized.indexOf('://xiaohongshu.com/discovery/item/') >= 0 ||
    normalized.indexOf('://www.xiaohongshu.com/discovery/item/') >= 0;
}

function isProductEvidenceSource(url: string): boolean {
  return !domainMatches(url, 'youtube.com') && !domainMatches(url, 'bilibili.com') &&
    !domainMatches(url, 'xiaohongshu.com') && !domainMatches(url, 'zhihu.com') &&
    !domainMatches(url, 'weibo.com') && !domainMatches(url, 'reddit.com');
}

function shoppingDomains(inputDomains: string[]): string[] {
  if (inputDomains.length === 0) {
    return SHOPPING_SOURCE_DOMAINS.slice();
  }
  return SHOPPING_SOURCE_DOMAINS.filter((domain: string): boolean =>
    inputDomains.indexOf(domain) >= 0
  );
}

function shoppingQuery(query: string, preferenceText: string): string {
  const suffixes: string[] = [
    '现在多少钱', '多少钱', '各平台价格', '公开价格', '比价', '返回5条', '返回 5 条'
  ];
  let value = query.trim();
  for (let index = 0; index < suffixes.length; index++) {
    value = value.split(suffixes[index]).join(' ').trim();
  }
  return value + (preferenceText.length > 0 ? ' ' + preferenceText : '');
}

function errorResult(
  toolId: string,
  status: FirecrawlResultStatus,
  message: string,
  rawPreview: string,
  httpStatus: number,
  config: FirecrawlConfig
): DynamicGenericToolResult {
  const safeMessage = redactExact(message, config).substring(0, SHORT_PREVIEW_CHARS);
  const rows: A2uiLabelValueData[] = [{ label: 'Provider 状态', value: status }];
  if (httpStatus > 0) {
    rows.push({ label: 'HTTP 状态', value: httpStatus.toString() });
  }
  return {
    sourceTag: 'Firecrawl',
    toolName: toolId,
    title: status === 'needs_auth' ? 'Firecrawl 需要授权' :
      (toolId === 'web.monitor.create' || toolId === 'web.monitor.list' ?
        'Firecrawl Monitor 操作失败' : 'Firecrawl 网页读取失败'),
    status: status,
    summary: safeMessage.length > 0 ? safeMessage : status,
    rows: rows,
    rawPreview: redactExact(rawPreview, config).substring(0, SHORT_PREVIEW_CHARS)
  };
}

function outputWith(
  result: DynamicGenericToolResult,
  title: string = '网页读取',
  intent: string = 'web.page.read'
): FirecrawlToolOutput {
  return {
    title: title,
    intent: intent,
    results: [result]
  };
}

export class FirecrawlMcpClient {
  private readonly client: GenericMcpClient;
  private readonly timestampProvider: () => string;
  private cachedConfigSignature: string = '';
  private cachedToolNames: string[] = [];

  constructor(client: GenericMcpClient, timestampProvider: () => string = nowIso) {
    this.client = client;
    this.timestampProvider = timestampProvider;
  }

  private lifecycle(
    isError: boolean,
    toolId: string,
    mcpToolName: string,
    phase: string,
    httpStatus: number,
    status: string,
    resultCount: number,
    startedAt: number
  ): void {
    const message = '[AIPhone][FirecrawlMcp] toolId=' + toolId +
      ' mcpTool=' + mcpToolName +
      ' preflightPhase=' + phase +
      ' httpStatus=' + httpStatus.toString() +
      ' providerStatus=' + status +
      ' resultCount=' + resultCount.toString() +
      ' durationMs=' + (Date.now() - startedAt).toString();
    if (isError) {
      aiLogError(message);
    } else {
      aiLogInfo(message);
    }
  }

  private async ensurePreflight(
    toolId: string,
    registration: DynamicToolRegistration,
    config: FirecrawlConfig
  ): Promise<DynamicGenericToolResult | null> {
    const signature = config.mcpUrl + '\n' + config.apiKey;
    if (signature === this.cachedConfigSignature && this.cachedToolNames.length > 0) {
      return null;
    }
    const startedAt = Date.now();
    this.lifecycle(false, toolId, registration.mcpToolName, 'start', 0, 'pending', 0, startedAt);
    let preflight: DynamicPreflightResult;
    try {
      preflight = await this.client.preflight(registration, config.apiKey);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Firecrawl preflight failed.';
      const status = normalizedStatus(0, message);
      this.lifecycle(true, toolId, registration.mcpToolName, 'exception', 0, status, 0, startedAt);
      return errorResult(toolId, status, message, message, 0, config);
    }
    if (!preflight.ok) {
      const status: FirecrawlResultStatus =
        preflight.status === 'needs_auth' || preflight.inferredCredential !== null ?
        'needs_auth' : normalizedStatus(preflight.httpStatus, preflight.message);
      this.lifecycle(true, toolId, registration.mcpToolName, 'failed',
        preflight.httpStatus, status, 0, startedAt);
      return errorResult(toolId, status, preflight.message, preflight.message,
        preflight.httpStatus, config);
    }
    const toolNames = preflight.tools.map((item): string => item.name);
    const missing = REQUIRED_MCP_TOOLS.filter((name: string): boolean => toolNames.indexOf(name) < 0);
    if (missing.length > 0) {
      this.lifecycle(true, toolId, registration.mcpToolName, 'missing_tools',
        preflight.httpStatus, 'error', 0, startedAt);
      return errorResult(
        toolId,
        'error',
        'Firecrawl MCP is missing required tools: ' + missing.join(', '),
        '',
        preflight.httpStatus,
        config
      );
    }
    this.cachedConfigSignature = signature;
    this.cachedToolNames = toolNames;
    this.lifecycle(false, toolId, registration.mcpToolName, 'success',
      preflight.httpStatus, 'success', toolNames.length, startedAt);
    return null;
  }

  private async callSearch(
    toolId: string,
    query: string,
    limit: number,
    domains: string[],
    tbs: string,
    config: FirecrawlConfig
  ): Promise<SearchOutcome> {
    const registration = registrationFor(toolId, 'firecrawl_search', config);
    const startedAt = Date.now();
    let call: McpToolCallResult;
    try {
      call = await this.client.callToolPayload(
        registration,
        config.apiKey,
        searchArguments(query, limit, domains, tbs)
      );
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Firecrawl search failed.';
      return {
        status: normalizedStatus(0, message),
        items: [],
        message: message,
        rawPreview: message,
        httpStatus: 0,
        requestId: '',
        usage: usageOf(null)
      };
    }
    const parsed = parsePayload(call.result);
    const root = parsed.value as FirecrawlSearchResponse | null;
    const requestId = root === null ? '' : textOf(root.id).trim();
    const usage = usageOf(root);
    const message = failureText(call, parsed.value);
    if (!call.ok || call.result === null || call.result.isError === true ||
      root === null || root.success === false) {
      const status = root === null && call.ok && parsed.rawText.trim().length === 0 ?
        'empty' : normalizedStatus(call.httpStatus, message);
      this.lifecycle(true, toolId, registration.mcpToolName, 'search_failed',
        call.httpStatus, status, 0, startedAt);
      return {
        status: status,
        items: [],
        message: message.length > 0 ? message : 'Firecrawl search returned no usable results.',
        rawPreview: parsed.rawText.length > 0 ? parsed.rawText : call.rawPreview,
        httpStatus: call.httpStatus,
        requestId: requestId,
        usage: usage
      };
    }
    const web = root.data === undefined || root.data === null ||
      !Array.isArray(root.data.web) ?
      [] : root.data.web as (Object | string | number | boolean | null)[];
    const items: FirecrawlSearchItem[] = [];
    for (let index = 0; index < web.length; index++) {
      const raw = web[index];
      if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
        continue;
      }
      const item = raw as FirecrawlSearchItem;
      const url = firecrawlHttpUrlOf(item.url);
      if (url.length === 0) {
        continue;
      }
      items.push({
        url: url,
        title: typeof item.title === 'string' ? item.title : '',
        description: typeof item.description === 'string' ? item.description : '',
        markdown: typeof item.markdown === 'string' ? item.markdown : '',
        publishedDate: typeof item.publishedDate === 'string' ? item.publishedDate : ''
      });
    }
    const status: FirecrawlResultStatus = items.length > 0 ? 'success' : 'empty';
    this.lifecycle(false, toolId, registration.mcpToolName, 'search_success',
      call.httpStatus, status, items.length, startedAt);
    return {
      status: status,
      items: items,
      message: items.length > 0 ? '' : 'Firecrawl search returned no results.',
      rawPreview: parsed.rawText,
      httpStatus: call.httpStatus,
      requestId: requestId,
      usage: usage
    };
  }

  private async callScrape(
    toolId: string,
    url: string,
    args: Object,
    config: FirecrawlConfig
  ): Promise<ScrapeOutcome> {
    const registration = registrationFor(toolId, 'firecrawl_scrape', config);
    let call: McpToolCallResult;
    try {
      call = await this.client.callToolPayload(registration, config.apiKey, args);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Firecrawl scrape failed.';
      return {
        status: normalizedStatus(0, message),
        page: null,
        message: message,
        rawPreview: message,
        httpStatus: 0,
        usage: usageOf(null)
      };
    }
    const parsed = parsePayload(call.result);
    const root = parsed.value;
    const page = root === null ? null : pageResponseOf(root);
    const usage = usageOf(
      page,
      root === null || page === root ? null : root
    );
    const metadataStatus = page?.metadata?.statusCode === undefined ?
      call.httpStatus : page.metadata.statusCode as number;
    const message = failureText(call, page);
    if (!call.ok || call.result === null || call.result.isError === true ||
      page?.success === false) {
      return {
        status: normalizedScrapeFailureStatus(call, page, parsed, metadataStatus),
        page: page,
        message: message,
        rawPreview: parsed.rawText.length > 0 ? parsed.rawText : call.rawPreview,
        httpStatus: metadataStatus,
        usage: usage
      };
    }
    if (page === null) {
      return {
        status: parsed.rawText.trim().length === 0 ? 'empty' : 'error',
        page: null,
        message: parsed.rawText.trim().length === 0 ?
          'Firecrawl returned an empty body.' : 'Firecrawl returned unparseable text.',
        rawPreview: parsed.rawText,
        httpStatus: metadataStatus,
        usage: usage
      };
    }
    const providerSignal = providerStateText(page);
    const originStatus = normalizedOriginStatus(metadataStatus, providerSignal);
    if (metadataStatus >= 400 || originStatus !== 'error') {
      return {
        status: originStatus,
        page: page,
        message: providerSignal,
        rawPreview: parsed.rawText,
        httpStatus: metadataStatus,
        usage: usage
      };
    }
    return {
      status: 'success',
      page: page,
      message: '',
      rawPreview: parsed.rawText,
      httpStatus: metadataStatus,
      usage: usage
    };
  }

  private async callInteract(
    toolId: string,
    scrapeId: string,
    code: string,
    config: FirecrawlConfig
  ): Promise<InteractOutcome> {
    const registration = registrationFor(toolId, 'firecrawl_interact', config);
    const startedAt = Date.now();
    let call: McpToolCallResult;
    try {
      call = await this.client.callToolPayload(
        registration,
        config.apiKey,
        JSON.parse(
          '{"scrapeId":' + JSON.stringify(scrapeId) + ',"code":' +
          JSON.stringify(code) + ',"language":"bash","timeout":30}'
        ) as Object
      );
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Firecrawl interact failed.';
      this.lifecycle(true, toolId, registration.mcpToolName, 'call_exception',
        0, normalizedStatus(0, message), 0, startedAt);
      return {
        status: normalizedStatus(0, message),
        stdout: '',
        message: message,
        rawPreview: message,
        httpStatus: 0,
        usage: usageOf(null)
      };
    }
    const parsed = parsePayload(call.result);
    const root = parsed.value as FirecrawlInteractResponse | null;
    const message = root === null ? failureText(call, null) :
      [
        textOf(root.error).trim(),
        textOf(root.message).trim(),
        textOf(root.stderr).trim(),
        failureText(call, root as FirecrawlPageResponse)
      ].join(' ').trim();
    if (!call.ok || call.result === null || call.result.isError === true ||
      root === null || root.success === false) {
      const status = normalizedStatus(call.httpStatus, message);
      this.lifecycle(true, toolId, registration.mcpToolName, 'call_failed',
        call.httpStatus, status, 0, startedAt);
      return {
        status: status,
        stdout: '',
        message: message.length > 0 ? message : 'Firecrawl interact returned no usable result.',
        rawPreview: parsed.rawText.length > 0 ? parsed.rawText : call.rawPreview,
        httpStatus: call.httpStatus,
        usage: usageOf(root)
      };
    }
    const status: FirecrawlResultStatus =
      textOf(root.stdout).trim().length > 0 ? 'success' : 'empty';
    this.lifecycle(status !== 'success', toolId, registration.mcpToolName, 'call_success',
      call.httpStatus, status, status === 'success' ? 1 : 0, startedAt);
    return {
      status: status,
      stdout: textOf(root.stdout).trim(),
      message: '',
      rawPreview: parsed.rawText,
      httpStatus: call.httpStatus,
      usage: usageOf(root)
    };
  }

  private async stopInteract(
    toolId: string,
    scrapeId: string,
    config: FirecrawlConfig
  ): Promise<void> {
    try {
      await this.client.callToolPayload(
        registrationFor(toolId, 'firecrawl_interact_stop', config),
        config.apiKey,
        JSON.parse('{"scrapeId":' + JSON.stringify(scrapeId) + '}') as Object
      );
    } catch (_error) {
      // Session cleanup is best-effort; the user-visible result already reflects provider data.
    }
  }

  private sourceResult(
    toolId: string,
    item: FirecrawlSearchItem,
    status: FirecrawlResultStatus,
    summary: string,
    rawPreview: string,
    config: FirecrawlConfig,
    usage: UsageSnapshot | null = null
  ): DynamicGenericToolResult {
    const url = textOf(item.url);
    const title = textOf(item.title).trim().length > 0 ? textOf(item.title).trim() : url;
    const rows = sourceRows(url, status, this.timestampProvider(), textOf(item.publishedDate).trim());
    if (usage !== null) {
      appendRows(rows, usageRows(usage, config, 'Scrape Credits'));
    }
    return {
      sourceTag: 'Firecrawl',
      toolName: toolId,
      title: title,
      status: status,
      summary: redactExact(summary, config).substring(0, SUMMARY_CHARS),
      rows: rows,
      rawPreview: redactExact(rawPreview, config).substring(0, SHORT_PREVIEW_CHARS),
      actions: sourceActions(url)
    };
  }

  private async executeAuthenticatedSocial(
    query: string,
    limit: number,
    platforms: SocialPlatform[],
    config: FirecrawlConfig,
    onPartial: ((output: FirecrawlToolOutput) => void) | null
  ): Promise<FirecrawlToolOutput | null> {
    const toolId = 'social.public.search';
    const searchUrl = 'https://www.xiaohongshu.com/search_result?keyword=' +
      encodeURIComponent(query) + '&source=web_search_result_notes';
    const scrape = await this.callScrape(
      toolId,
      searchUrl,
      xiaohongshuSearchArguments(query),
      config
    );
    if (scrape.status !== 'success') {
      return outputWith(
        resultWithRows(
          errorResult(
            toolId, scrape.status, scrape.message, scrape.rawPreview,
            scrape.httpStatus, config
          ),
          usageRows(scrape.usage, config, 'Scrape Credits')
        ),
        '公开社交搜索',
        toolId
      );
    }
    const markdown = scrape.page === null ? '' : textOf(scrape.page.markdown).trim();
    const loginRequired = xiaohongshuLoginRequired(markdown);
    const scrapeId = scrape.page?.metadata?.scrapeId === undefined ?
      '' : textOf(scrape.page?.metadata?.scrapeId).trim();
    if (scrapeId.length === 0) {
      return null;
    }
    const startedAt = Date.now();
    let phase = 'cards_call';
    try {
      let cardCall = await this.callInteract(
        toolId, scrapeId, xiaohongshuCardsCode(limit), config
      );
      if (cardCall.status !== 'success') {
        cardCall = await this.callInteract(
          toolId, scrapeId, xiaohongshuCardsCode(limit), config
        );
      }
      if (cardCall.status !== 'success') {
        return outputWith(
          resultWithRows(
            errorResult(
              toolId, cardCall.status, cardCall.message, cardCall.rawPreview,
              cardCall.httpStatus, config
            ),
            usageRows(cardCall.usage, config, 'Browser Credits')
          ),
          '公开社交搜索',
          toolId
        );
      }
      phase = 'cards_parse';
      let cards = xiaohongshuCards(cardCall.stdout, limit);
      if (cards.length === 0) {
        const retryCall = await this.callInteract(
          toolId, scrapeId, xiaohongshuCardsCode(limit), config
        );
        if (retryCall.status === 'success') {
          cardCall = retryCall;
          cards = xiaohongshuCards(cardCall.stdout, limit);
        }
      }
      this.lifecycle(cards.length === 0, toolId, 'firecrawl_interact', phase,
        cardCall.httpStatus, cards.length > 0 ? 'success' : 'empty', cards.length, startedAt);
      if (cards.length === 0 && loginRequired) {
        return outputWith(
          resultWithRows(
            errorResult(
              toolId,
              'needs_auth',
              '小红书登录态已失效，请重新登录 Firecrawl 小红书浏览器会话。',
              markdown,
              scrape.httpStatus,
              config
            ),
            usageRows(scrape.usage, config, 'Scrape Credits')
          ),
          '公开社交搜索',
          toolId
        );
      }
      const sources: DynamicGenericToolResult[] = [];
      for (let index = 0; index < cards.length; index++) {
        const card = cards[index];
        let detail: XiaohongshuNoteDetail | null = null;
        let detailUsage: UsageSnapshot | null = null;
        phase = 'detail_call';
        const detailCall = await this.callInteract(
          toolId,
          scrapeId,
          xiaohongshuDetailCode(textOf(card.url)),
          config
        );
        detailUsage = detailCall.usage;
        if (detailCall.status === 'success') {
          phase = 'detail_parse';
          detail = xiaohongshuDetail(detailCall.stdout);
          this.lifecycle(detail === null, toolId, 'firecrawl_interact', phase,
            detailCall.httpStatus, detail === null ? 'empty' : 'success',
            detail === null ? 0 : 1, startedAt);
        }
        const url = detail === null ? textOf(card.url) : textOf(detail.url);
        const title = detail !== null && textOf(detail.title).length > 0 ?
          textOf(detail.title) : textOf(card.title);
        const author = detail !== null && textOf(detail.author).length > 0 ?
          textOf(detail.author) : textOf(card.author);
        const summary = detail !== null && textOf(detail.description).length > 0 ?
          textOf(detail.description) :
          (author.length > 0 ? '作者：' + author : '已找到可打开的小红书笔记。');
        const item: FirecrawlSearchItem = {
          url: url,
          title: title,
          description: summary,
          publishedDate: textOf(card.published)
        };
        const source = this.sourceResult(
          toolId,
          item,
          detail !== null && textOf(detail.description).length > 0 ? 'success' : 'partial',
          summary,
          summary,
          config,
          detailUsage
        );
        if (author.length > 0) {
          source.rows.push({ label: '作者', value: author });
        }
        if (detail !== null && textOf(detail.description).length > 0) {
          source.rows.push({ label: '完整正文', value: textOf(detail.description) });
        }
        const imageUrls = detail === null || detail.imageUrls === undefined ?
          [] : detail.imageUrls;
        const coverUrl = imageUrls.length > 0 ?
          imageUrls[0] : textOf(card.coverUrl);
        const isVideo = (detail !== null && detail.isVideo === true) || card.isVideo === true;
        if (coverUrl.length > 0) {
          source.rows.push({ label: '封面图', value: coverUrl });
        }
        if (imageUrls.length > 0) {
          source.rows.push({ label: '图片列表', value: imageUrls.join('\n') });
          source.rows.push({ label: '图片数量', value: imageUrls.length.toString() });
        }
        if (coverUrl.length > 0 || isVideo) {
          source.rows.push({ label: '内容类型', value: isVideo ? '视频' : '图文' });
        }
        if (detail !== null && detail.videoDuration !== undefined &&
          detail.videoDuration > 0) {
          const minutes = Math.floor(detail.videoDuration / 60);
          const seconds = Math.floor(detail.videoDuration % 60);
          source.rows.push({
            label: '视频时长',
            value: minutes.toString() + ':' + (seconds < 10 ? '0' : '') + seconds.toString()
          });
        }
        source.actions = [];
        sources.push(source);
        if (onPartial !== null) {
          onPartial({
            title: '公开社交搜索',
            intent: toolId,
            results: sources.slice()
          });
        }
      }
      const platformCards: DynamicGenericToolResult[] = platforms.map(
        (platform: SocialPlatform): DynamicGenericToolResult => {
          const status = socialPlatformStatus(sources);
          return {
            sourceTag: 'Firecrawl',
            toolName: toolId,
            title: platform.name,
            status: status,
            summary: status === 'empty' ?
              '该平台没有返回可核验的笔记。' :
              '该平台笔记状态：' + status,
            rows: [
              { label: '平台域名', value: platform.domain },
              { label: 'Provider 状态', value: status }
            ],
            rawPreview: ''
          };
        }
      );
      const overviewRows: A2uiLabelValueData[] = [
        { label: 'Provider 状态', value: aggregateStatus(sources) },
        { label: '来源数', value: sources.length.toString() }
      ];
      appendRows(overviewRows, usageRows(scrape.usage, config, 'Scrape Credits'));
      appendRows(overviewRows, usageRows(cardCall.usage, config, 'Browser Credits'));
      const overview: DynamicGenericToolResult = {
        sourceTag: 'Firecrawl',
        toolName: toolId,
        title: '小红书搜索综述',
        status: aggregateStatus(sources),
        summary: '本次小红书搜索返回 ' + sources.length.toString() + ' 篇可打开的笔记。',
        rows: overviewRows,
        rawPreview: ''
      };
      return {
        title: '公开社交搜索',
        intent: toolId,
        results: sources.concat(platformCards).concat([overview])
      };
    } catch (error) {
      const message = error instanceof Error ? error.message :
        'Firecrawl Xiaohongshu browser result could not be parsed.';
      this.lifecycle(true, toolId, 'firecrawl_interact', phase + '_exception',
        0, 'error', 0, startedAt);
      return outputWith(
        errorResult(toolId, 'error', message, message, 0, config),
        '公开社交搜索',
        toolId
      );
    } finally {
      await this.stopInteract(toolId, scrapeId, config);
    }
  }

  private async executeResearch(
    prompt: string,
    args: Object | null,
    config: FirecrawlConfig
  ): Promise<FirecrawlToolOutput> {
    const toolId = 'web.research.search';
    const input: FirecrawlResearchArgs = args === null ? {} : args as FirecrawlResearchArgs;
    const query = textOf(input.query).trim();
    if (query.length === 0) {
      return outputWith(
        errorResult(toolId, 'error', 'A research query is required.', '', 0, config),
        '网页研究',
        toolId
      );
    }
    const limit = bounded(input.maxResults, 5, 10);
    const domainFilter = normalizedDomains(input.domains);
    if (!domainFilter.valid) {
      return outputWith(
        errorResult(
          toolId,
          'error',
          'Domains must be non-empty ASCII hostname-only values; URLs and IDNs are not accepted.',
          '',
          0,
          config
        ),
        '网页研究',
        toolId
      );
    }
    const domains = domainFilter.domains;
    const recency = textOf(input.recency);
    const registration = registrationFor(toolId, 'firecrawl_search', config);
    const preflightFailure = await this.ensurePreflight(toolId, registration, config);
    if (preflightFailure !== null) {
      return outputWith(preflightFailure, '网页研究', toolId);
    }
    const search = await this.callSearch(toolId, query, limit, domains, recency, config);
    if (search.status !== 'success' && search.status !== 'empty') {
      return outputWith(
        resultWithRows(
          errorResult(toolId, search.status, search.message, search.rawPreview,
            search.httpStatus, config),
          searchUsageRows(search, config)
        ),
        '网页研究',
        toolId
      );
    }
    const items = uniqueSearchItems(search.items, limit);
    const sources: DynamicGenericToolResult[] = [];
    let scrapeCount = 0;
    const deepResearch = wantsDeepResearch(prompt);
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      const searchSummary = textOf(item.description).trim().length > 0 ?
        textOf(item.description).trim() : textOf(item.markdown).trim();
      let status: FirecrawlResultStatus = searchSummary.length > 0 ? 'success' : 'empty';
      let summary = searchSummary;
      let rawPreview = searchSummary;
      let scrapeUsage: UsageSnapshot | null = null;
      if (scrapeCount < 3 && (deepResearch || searchSummary.length === 0)) {
        scrapeCount++;
        const scrape = await this.callScrape(
          toolId,
          textOf(item.url),
          pageReadArguments(textOf(item.url), ''),
          config
        );
        scrapeUsage = scrape.usage;
        status = scrape.status;
        if (scrape.status === 'success') {
          const markdown = scrape.page === null ? '' : textOf(scrape.page.markdown).trim();
          if (markdown.length === 0) {
            status = 'empty';
          } else {
            summary = markdown;
            rawPreview = markdown;
          }
          if (loginOnlyBody(markdown)) {
            status = 'blocked_by_site';
          }
        }
        if (status !== 'success') {
          summary = searchSummary.length > 0 ? searchSummary : scrape.message;
          rawPreview = scrape.rawPreview;
        }
      }
      sources.push(this.sourceResult(
        toolId, item, status, summary, rawPreview, config, scrapeUsage
      ));
    }
    const status = aggregateStatus(sources);
    let verifiedCount = 0;
    for (let index = 0; index < sources.length; index++) {
      if ((sources[index].status === 'success' || sources[index].status === 'partial') &&
        sources[index].summary.trim().length > 0) {
        verifiedCount++;
      }
    }
    const candidateCount = sources.length - verifiedCount;
    const overviewRows: A2uiLabelValueData[] = [
      { label: 'Provider 状态', value: status },
      { label: '来源数', value: sources.length.toString() },
      { label: '已核验来源', value: verifiedCount.toString() },
      { label: '候选来源', value: candidateCount.toString() }
    ];
    appendRows(overviewRows, searchUsageRows(search, config));
    const overview: DynamicGenericToolResult = {
      sourceTag: 'Firecrawl',
      toolName: toolId,
      title: '网页研究综述',
      status: status,
      summary: '已核验 ' + verifiedCount.toString() + ' 个公开来源；候选 ' +
        candidateCount.toString() + ' 个公开来源。',
      rows: overviewRows,
      rawPreview: ''
    };
    return {
      title: '网页研究',
      intent: toolId,
      results: [overview].concat(sources)
    };
  }

  private shoppingOfferResults(
    toolId: string,
    cleanQuery: string,
    preferenceText: string,
    item: FirecrawlSearchItem,
    scrape: ScrapeOutcome,
    search: SearchOutcome,
    config: FirecrawlConfig
  ): DynamicGenericToolResult[] {
    const pageUrl = textOf(item.url);
    if (scrape.status !== 'success' ||
      scrape.page?.json === undefined || scrape.page?.json === null) {
      return [];
    }
    const offers = shoppingOffersOf(scrape.page.json, pageUrl);
    const results: DynamicGenericToolResult[] = [];
    for (let index = 0; index < offers.length; index++) {
      const product = offers[index];
      const name = typeof product.name === 'string' ? product.name.trim() : '';
      if (name.length === 0 || !shoppingProductMatches(cleanQuery, product)) {
        continue;
      }
      const offerUrl = firecrawlHttpUrlOf(product.offerUrl);
      const evidenceUrl = firecrawlHttpUrlOf(product.evidenceUrl).length > 0 ?
        firecrawlHttpUrlOf(product.evidenceUrl) : pageUrl;
      const platform = shoppingOptionalText(textOf(product.platform));
      if (offerUrl.length === 0 || evidenceUrl.length === 0 || platform.length === 0) {
        continue;
      }
      const brand = typeof product.brand === 'string' ? product.brand.trim() : '';
      const seller = typeof product.seller === 'string' ? product.seller.trim() : '';
      const currency = shoppingOfferCurrency(product);
      const priceText = typeof product.priceText === 'string' ?
        shoppingPriceEvidenceText(product.priceText, currency) : '';
      const listPriceText = typeof product.listPriceText === 'string' ?
        shoppingPriceEvidenceText(product.listPriceText, currency) : '';
      const salePriceText = typeof product.salePriceText === 'string' ?
        shoppingPriceEvidenceText(product.salePriceText, currency) : '';
      const estimatedPriceText = typeof product.estimatedPriceText === 'string' ?
        shoppingPriceEvidenceText(product.estimatedPriceText, currency) : '';
      const couponText = typeof product.couponText === 'string' ?
        product.couponText.trim() : '';
      const shippingText = typeof product.shippingText === 'string' ?
        product.shippingText.trim() : '';
      let price = shoppingPrice('', 'public', currency);
      if (salePriceText.length > 0) {
        price = shoppingPrice(salePriceText, 'public', currency);
      } else if (estimatedPriceText.length > 0) {
        price = shoppingPrice(estimatedPriceText, 'estimated', currency);
      } else if (priceText.length > 0) {
        price = shoppingPrice(priceText, 'public', currency);
      } else if (listPriceText.length > 0) {
        price = shoppingPrice(listPriceText, 'list', currency);
      }
      if (price.text.length === 0) {
        continue;
      }
      const market = shoppingOfferMarket(product, evidenceUrl);
      const comparable = market === 'CN' && currency === 'CNY' && price.comparable &&
        shoppingRequestedVariantConfirmed(cleanQuery, product);
      const specifications = stringList(product.specifications);
      const strengths = stringList(product.strengths);
      const limitations = stringList(product.limitations);
      const rows = sourceRows(offerUrl, scrape.status, this.timestampProvider());
      appendRows(rows, searchUsageRows(search, config));
      appendRows(rows, usageRows(scrape.usage, config, 'Scrape Credits'));
      rows.push({ label: '平台', value: platform });
      rows.push({ label: '数据页面', value: evidenceUrl });
      rows.push({ label: '市场', value: market });
      rows.push({ label: '币种', value: currency });
      if (preferenceText.length > 0) {
        rows.push({ label: '检索偏好', value: preferenceText });
      }
      rows.push({ label: '品牌', value: brand.length > 0 ? brand : '未知' });
      rows.push({
        label: price.kind === 'estimated' ? '预估到手价' : '价格',
        value: price.text
      });
      if (seller.length > 0) {
        rows.push({ label: '卖家', value: seller });
      }
      if (listPriceText.length > 0) {
        rows.push({ label: '标价', value: listPriceText });
      }
      if (salePriceText.length > 0) {
        rows.push({ label: '销售价', value: salePriceText });
      }
      if (estimatedPriceText.length > 0 && price.kind !== 'estimated') {
        rows.push({ label: '预估到手价', value: estimatedPriceText });
      }
      if (couponText.length > 0) {
        rows.push({ label: '优惠券', value: couponText });
      }
      if (shippingText.length > 0) {
        rows.push({ label: '运费', value: shippingText });
      }
      rows.push({ label: 'comparisonEligible', value: comparable ? 'true' : 'false' });
      rows.push({ label: 'comparisonPriceFen', value: price.valueFen.toString() });
      rows.push({ label: 'comparisonPriceKind', value: price.kind });
      rows.push({
        label: 'comparisonKey',
        value: market + '|' + currency + '|' + shoppingComparisonKey(product)
      });
      rows.push({ label: '规格', value: specifications.join('\n') });
      rows.push({ label: '优点', value: strengths.join('\n') });
      rows.push({ label: '限制', value: limitations.join('\n') });
      const fallbackSummary = textOf(item.description).trim();
      const summary = strengths.length > 0 ? strengths.join('；') :
        (fallbackSummary.length > 0 ? fallbackSummary : scrape.message);
      results.push({
        sourceTag: 'Firecrawl',
        toolName: toolId,
        title: name,
        status: scrape.status,
        summary: redactExact(summary, config).substring(0, SUMMARY_CHARS),
        rows: rows,
        rawPreview: redactExact(JSON.stringify(product), config)
          .substring(0, SHORT_PREVIEW_CHARS),
        actions: sourceActions(offerUrl)
      });
    }
    return results;
  }

  private async executeShopping(
    args: Object | null,
    config: FirecrawlConfig,
    onPartial: ((output: FirecrawlToolOutput) => void) | null
  ): Promise<FirecrawlToolOutput> {
    const toolId = 'shopping.research';
    const input: FirecrawlShoppingArgs = args === null ? {} : args as FirecrawlShoppingArgs;
    const query = textOf(input.query).trim();
    if (query.length === 0) {
      return outputWith(
        errorResult(toolId, 'error', 'A shopping research query is required.', '', 0, config),
        '商品比价',
        toolId
      );
    }
    const domainFilter = normalizedDomains(input.domains);
    if (!domainFilter.valid) {
      return outputWith(
        errorResult(
          toolId,
          'error',
          'Domains must be non-empty ASCII hostname-only values; URLs and IDNs are not accepted.',
          '',
          0,
          config
        ),
        '商品比价',
        toolId
      );
    }
    const domains = shoppingDomains(domainFilter.domains);
    if (domains.length === 0) {
      return outputWith(
        errorResult(
          toolId,
          'empty',
          '所选来源暂未通过公开价格验证，请使用当前支持的固定来源。',
          '',
          0,
          config
        ),
        '商品比价',
        toolId
      );
    }
    const preferenceText = preferenceList(input.preferences).join('；');
    const cleanQuery = shoppingQuery(query, '');
    const searchQuery = shoppingQuery(query, preferenceText);
    const visibleLimit = bounded(input.maxProducts, 3, 3);
    const registration = registrationFor(toolId, 'firecrawl_search', config);
    const preflightFailure = await this.ensurePreflight(toolId, registration, config);
    if (preflightFailure !== null) {
      return outputWith(preflightFailure, '商品比价', toolId);
    }
    const results: DynamicGenericToolResult[] = [];
    const searchUsages: UsageSnapshot[] = [];
    const scrapeUsages: UsageSnapshot[] = [];
    const seenOfferIds: string[] = [];
    const search = await this.callSearch(toolId, searchQuery, 12, domains, '', config);
    searchUsages.push(search.usage);
    const candidates = search.status === 'success' ?
      rankedShoppingCandidates(cleanQuery, search.items, domains) : [];
    let scrapeCount = 0;
    for (let index = 0; index < candidates.length && scrapeCount < 3 &&
      (visibleLimit === 1 ? results.length === 0 :
        !hasTwoComparableShoppingOffers(results.slice(0, visibleLimit))); index++) {
      const pageUrl = textOf(candidates[index].url);
      scrapeCount++;
      const scrape = await this.callScrape(toolId, pageUrl, productArguments(pageUrl), config);
      scrapeUsages.push(scrape.usage);
      const additions = this.shoppingOfferResults(
        toolId, cleanQuery, preferenceText, candidates[index], scrape, search, config
      );
      for (let resultIndex = 0; resultIndex < additions.length; resultIndex++) {
        const sourceId = rowValueOf(additions[resultIndex].rows, '平台').toLowerCase() +
          '|' + rowValueOf(additions[resultIndex].rows, 'URL').toLowerCase();
        if (seenOfferIds.indexOf(sourceId) >= 0) {
          continue;
        }
        seenOfferIds.push(sourceId);
        results.push(additions[resultIndex]);
        results.sort(shoppingResultSort);
        if (onPartial !== null) {
          onPartial({
            title: '商品比价',
            intent: toolId,
            results: results.slice(0, visibleLimit)
          });
        }
      }
    }
    const visibleResults = results.slice(0, visibleLimit);
    let comparableCount = 0;
    let comparableGroupCount = 0;
    const comparisonKeys: string[] = [];
    for (let index = 0; index < visibleResults.length; index++) {
      const key = rowValueOf(visibleResults[index].rows, 'comparisonKey');
      if (comparisonKeys.indexOf(key) < 0) {
        comparisonKeys.push(key);
      }
      if (rowValueOf(visibleResults[index].rows, 'comparisonEligible') !== 'true') {
        continue;
      }
      comparableCount++;
      let groupCount = 0;
      for (let other = 0; other < visibleResults.length; other++) {
        if (rowValueOf(visibleResults[other].rows, 'comparisonEligible') === 'true' &&
          rowValueOf(visibleResults[other].rows, 'comparisonKey') === key) {
          groupCount++;
        }
      }
      if (groupCount > comparableGroupCount) {
        comparableGroupCount = groupCount;
      }
    }
    let summary = '暂未找到可核验的同款公开价格。';
    if (comparableGroupCount >= 2) {
      summary = '已找到 ' + comparableGroupCount.toString() + ' 个同规格公开价格来源。';
    } else if (comparisonKeys.length > 1) {
      summary = '来源规格不同，暂不计算最低价。';
    } else if (visibleResults.length > 0) {
      summary = '来源不足，暂不能形成比价。';
    }
    const overviewRows: A2uiLabelValueData[] = [
      { label: 'Provider 状态', value: aggregateStatus(visibleResults) },
      { label: '来源数', value: visibleResults.length.toString() },
      { label: '可比来源数', value: comparableCount.toString() }
    ];
    appendRows(overviewRows, usageRows(
      aggregateUsage(searchUsages), config, 'Search Credits'
    ));
    if (scrapeUsages.length > 0) {
      appendRows(overviewRows, usageRows(
        aggregateUsage(scrapeUsages), config, 'Scrape Credits'
      ));
    }
    const overview: DynamicGenericToolResult = {
      sourceTag: 'Firecrawl',
      toolName: toolId,
      title: '商品研究综述',
      status: aggregateStatus(visibleResults),
      summary: summary,
      rows: overviewRows,
      rawPreview: ''
    };
    return {
      title: '商品比价',
      intent: toolId,
      results: visibleResults.concat([overview])
    };
  }

  private async executeSocial(
    args: Object | null,
    config: FirecrawlConfig,
    onPartial: ((output: FirecrawlToolOutput) => void) | null
  ): Promise<FirecrawlToolOutput> {
    const toolId = 'social.public.search';
    const input: FirecrawlSocialArgs = args === null ? {} : args as FirecrawlSocialArgs;
    const query = textOf(input.query).trim();
    const platforms = socialPlatforms(input.platforms);
    if (query.length === 0 || platforms.length === 0) {
      return outputWith(
        errorResult(toolId, 'error', 'A query and supported public platform are required.', '', 0, config),
        '公开社交搜索',
        toolId
      );
    }
    const limit = bounded(input.maxResults, 5, 10);
    const domains = platforms.map((item: SocialPlatform): string => item.domain);
    const recency = textOf(input.recency);
    const registration = registrationFor(toolId, 'firecrawl_search', config);
    const preflightFailure = await this.ensurePreflight(toolId, registration, config);
    if (preflightFailure !== null) {
      return outputWith(preflightFailure, '公开社交搜索', toolId);
    }
    if (this.cachedToolNames.indexOf('firecrawl_interact') >= 0 &&
      this.cachedToolNames.indexOf('firecrawl_interact_stop') >= 0) {
      const authenticated = await this.executeAuthenticatedSocial(
        query, limit, platforms, config, onPartial
      );
      if (authenticated !== null) {
        return authenticated;
      }
    }
    const search = await this.callSearch(toolId, query, limit, domains, recency, config);
    if (search.status !== 'success' && search.status !== 'empty') {
      return outputWith(
        resultWithRows(
          errorResult(toolId, search.status, search.message, search.rawPreview,
            search.httpStatus, config),
          searchUsageRows(search, config)
        ),
        '公开社交搜索',
        toolId
      );
    }
    const items = uniqueSearchItems(search.items.filter((item: FirecrawlSearchItem): boolean =>
      platforms.find((platform: SocialPlatform): boolean =>
        domainMatches(textOf(item.url), platform.domain)
      ) !== undefined && isXiaohongshuPublicPost(textOf(item.url))
    ), limit);
    const sources: DynamicGenericToolResult[] = [];
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      const searchSummary = textOf(item.description).trim().length > 0 ?
        textOf(item.description).trim() : textOf(item.markdown).trim();
      let status: FirecrawlResultStatus = searchSummary.length > 0 ? 'partial' : 'empty';
      let summary = searchSummary;
      let rawPreview = searchSummary;
      let scrapeUsage: UsageSnapshot | null = null;
      if (index < 2) {
        const scrape = await this.callScrape(
          toolId,
          textOf(item.url),
          pageReadArguments(textOf(item.url), ''),
          config
        );
        scrapeUsage = scrape.usage;
        status = scrape.status;
        if (scrape.status === 'success') {
          const markdown = scrape.page === null ? '' : textOf(scrape.page.markdown).trim();
          if (markdown.length === 0) {
            status = 'empty';
          } else if (loginOnlyBody(markdown)) {
            status = 'blocked_by_site';
          } else {
            summary = markdown;
            rawPreview = markdown;
          }
        }
        if (status !== 'success') {
          summary = searchSummary.length > 0 ? searchSummary : scrape.message;
          rawPreview = scrape.rawPreview;
        }
      }
      sources.push(this.sourceResult(
        toolId, item, status, summary, rawPreview, config, scrapeUsage
      ));
    }
    const platformCards: DynamicGenericToolResult[] = platforms.map(
      (platform: SocialPlatform): DynamicGenericToolResult => {
        const matching = sources.filter((result: DynamicGenericToolResult): boolean =>
          domainMatches(rowValueOf(result.rows, 'URL'), platform.domain)
        );
        const status = socialPlatformStatus(matching);
        return {
          sourceTag: 'Firecrawl',
          toolName: toolId,
          title: platform.name,
          status: status,
          summary: status === 'empty' ?
            '该平台没有返回可核验的公开结果。' :
            '该平台公开结果状态：' + status,
          rows: [
            { label: '平台域名', value: platform.domain },
            { label: 'Provider 状态', value: status }
          ],
          rawPreview: ''
        };
      }
    );
    const overviewRows: A2uiLabelValueData[] = [
      { label: 'Provider 状态', value: aggregateStatus(sources) },
      { label: '来源数', value: sources.length.toString() }
    ];
    appendRows(overviewRows, searchUsageRows(search, config));
    const overview: DynamicGenericToolResult = {
      sourceTag: 'Firecrawl',
      toolName: toolId,
      title: '公开社交搜索综述',
      status: aggregateStatus(sources),
      summary: '本次公开社交搜索返回 ' + sources.length.toString() + ' 个公开来源。',
      rows: overviewRows,
      rawPreview: ''
    };
    return {
      title: '公开社交搜索',
      intent: toolId,
      results: sources.concat(platformCards).concat([overview])
    };
  }

  private async callMonitor(
    toolId: string,
    mcpToolName: string,
    args: Object,
    mutation: boolean,
    config: FirecrawlConfig
  ): Promise<MonitorCallOutcome> {
    const registration = registrationFor(toolId, mcpToolName, config);
    const preflightFailure = await this.ensurePreflight(toolId, registration, config);
    if (preflightFailure !== null) {
      return {
        ok: false,
        providerCalled: false,
        status: preflightFailure.status as FirecrawlResultStatus,
        value: null,
        message: preflightFailure.summary,
        rawPreview: preflightFailure.rawPreview,
        httpStatus: 0,
        usage: usageOf(null)
      };
    }
    const startedAt = Date.now();
    let call: McpToolCallResult;
    try {
      call = await this.client.callToolPayload(registration, config.apiKey, args);
    } catch (error) {
      const detail = error instanceof Error ? error.message : 'Firecrawl monitor request failed.';
      const message = mutation ?
        detail + '；结果未知，先重新查询 Provider 状态，确认真实 Monitor 状态后再操作。' :
        detail;
      this.lifecycle(true, toolId, mcpToolName, 'call_exception', 0, 'error', 0, startedAt);
      return {
        ok: false,
        providerCalled: true,
        status: mutation ? 'error' : normalizedStatus(0, detail),
        value: null,
        message: message,
        rawPreview: detail,
        httpStatus: 0,
        usage: usageOf(null)
      };
    }
    const parsed = parsePayload(call.result);
    const validRoot = parsed.value !== null && typeof parsed.value === 'object' &&
      !Array.isArray(parsed.value);
    const value = validRoot ? parsed.value as FirecrawlMonitorEnvelope : null;
    const nestedUsage = value !== null && value.data !== null && value.data !== undefined &&
      typeof value.data === 'object' && !Array.isArray(value.data) ?
      value.data as FirecrawlUsageEnvelope : null;
    const usage = usageOf(value, nestedUsage);
    const providerMessage = value === null ? '' :
      (textOf(value.error).trim().length > 0 ? textOf(value.error).trim() :
        textOf(value.message).trim());
    const failed = !call.ok || call.result === null || call.result.isError === true ||
      value === null || value.success !== true;
    if (failed) {
      const failureParts: string[] = [];
      if (call.errorMessage.trim().length > 0) {
        failureParts.push(call.errorMessage.trim());
      }
      if (providerMessage.length > 0 && failureParts.indexOf(providerMessage) < 0) {
        failureParts.push(providerMessage);
      }
      const rawFailure = parsed.rawText.trim().length > 0 ?
        parsed.rawText.trim().substring(0, SHORT_PREVIEW_CHARS) :
        call.rawPreview.trim().substring(0, SHORT_PREVIEW_CHARS);
      if (rawFailure.length > 0 && failureParts.indexOf(rawFailure) < 0) {
        failureParts.push(rawFailure);
      }
      const detail = failureParts.length > 0 ?
        failureParts.join('；') : 'Invalid Firecrawl Monitor Provider response.';
      const normalized = normalizedStatus(call.httpStatus, detail);
      const contractUnknown = call.ok && call.httpStatus >= 200 && call.httpStatus < 300 &&
        (value === null || value.success === undefined ||
        (value.success === false && providerMessage.length === 0 &&
          call.errorMessage.trim().length === 0));
      const serverUnknown = call.httpStatus >= 500 && call.httpStatus <= 599;
      const transportUnknown = call.httpStatus === 0 && !explicitDnsFailure(detail);
      const unknown = mutation &&
        (serverUnknown || transportUnknown || normalized === 'timeout' || contractUnknown);
      const message = unknown ?
        detail + '；结果未知，先重新查询 Provider 状态，确认真实 Monitor 状态后再操作。' :
        detail;
      const status: FirecrawlResultStatus = unknown ? 'error' : normalized;
      this.lifecycle(true, toolId, mcpToolName, 'call_failed',
        call.httpStatus, status, 0, startedAt);
      return {
        ok: false,
        providerCalled: true,
        status: status,
        value: value,
        message: message,
        rawPreview: rawFailure,
        httpStatus: call.httpStatus,
        usage: usage
      };
    }
    const rawPreview = parsed.rawText.length > 0 ? parsed.rawText : JSON.stringify(value);
    this.lifecycle(false, toolId, mcpToolName, 'call_success',
      call.httpStatus, 'success', 1, startedAt);
    return {
      ok: true,
      providerCalled: true,
      status: 'success',
      value: value,
      message: '',
      rawPreview: rawPreview,
      httpStatus: call.httpStatus,
      usage: usage
    };
  }

  private monitorResult(
    toolId: string,
    item: FirecrawlMonitorItem,
    id: string,
    rawPreview: string,
    config: FirecrawlConfig,
    usage: UsageSnapshot | null = null
  ): DynamicGenericToolResult {
    const providerStatus = textOf(item.status).trim();
    const rows: A2uiLabelValueData[] = [
      { label: 'Monitor ID', value: id },
      { label: 'Provider 状态', value: providerStatus.length > 0 ? providerStatus : 'returned' }
    ];
    if (textOf(item.goal).trim().length > 0) {
      rows.push({ label: '目标', value: textOf(item.goal).trim() });
    }
    if (item.schedule !== undefined && item.schedule !== null) {
      const schedule = typeof item.schedule === 'string' ?
        item.schedule : JSON.stringify(item.schedule);
      rows.push({ label: '计划', value: schedule.substring(0, SUMMARY_CHARS) });
    }
    if (textOf(item.lastRunAt).trim().length > 0) {
      rows.push({ label: '上次运行', value: textOf(item.lastRunAt).trim() });
    }
    if (textOf(item.nextRunAt).trim().length > 0) {
      rows.push({ label: '下次运行', value: textOf(item.nextRunAt).trim() });
    }
    const lastCheck: FirecrawlMonitorCheckSummary | null =
      item.lastCheck !== null && item.lastCheck !== undefined &&
      typeof item.lastCheck === 'object' && !Array.isArray(item.lastCheck) ?
        item.lastCheck as FirecrawlMonitorCheckSummary : null;
    const lastCheckId = textOf(item.currentCheckId).trim().length > 0 ?
      textOf(item.currentCheckId).trim() :
      (textOf(item.lastCheckId).trim().length > 0 ?
        textOf(item.lastCheckId).trim() :
        (lastCheck === null ? '' :
          (textOf(lastCheck.checkId).trim().length > 0 ?
            textOf(lastCheck.checkId).trim() : textOf(lastCheck.id).trim())));
    const lastCheckStatus = textOf(item.lastCheckStatus).trim().length > 0 ?
      textOf(item.lastCheckStatus).trim() :
      (lastCheck === null ? '' : textOf(lastCheck.status).trim());
    const lastCheckAt = textOf(item.lastCheckAt).trim().length > 0 ?
      textOf(item.lastCheckAt).trim() :
      (lastCheck === null ? '' :
        (textOf(lastCheck.completedAt).trim().length > 0 ?
          textOf(lastCheck.completedAt).trim() :
          (textOf(lastCheck.updatedAt).trim().length > 0 ?
            textOf(lastCheck.updatedAt).trim() : textOf(lastCheck.createdAt).trim())));
    if (lastCheckId.length > 0) {
      rows.push({ label: '最近 Check ID', value: lastCheckId });
    }
    if (lastCheckStatus.length > 0) {
      rows.push({ label: '最近 Check 状态', value: lastCheckStatus });
    }
    if (lastCheckAt.length > 0) {
      rows.push({ label: '最近 Check 时间', value: lastCheckAt });
    }
    if (usage !== null) {
      appendRows(rows, usageRows(usage, config));
    }
    const actions = monitorActions(id);
    if (lastCheckId.length > 0) {
      const checkAction: A2uiAction = {
        id: 'web.monitor.check',
        label: '查看最近检查',
        prompt: '查看最近检查',
        kind: 'prompt',
        variant: 'secondary',
        args: monitorArgs(id, lastCheckId)
      };
      actions.push(checkAction);
    }
    return {
      sourceTag: 'Firecrawl',
      toolName: toolId,
      title: textOf(item.name).trim().length > 0 ? textOf(item.name).trim() : id,
      status: 'success',
      summary: 'Firecrawl 返回了真实 Monitor 状态。',
      rows: rows,
      rawPreview: redactExact(rawPreview, config).substring(0, SHORT_PREVIEW_CHARS),
      actions: actions
    };
  }

  private monitorCheckResult(
    toolId: string,
    item: FirecrawlMonitorItem,
    id: string,
    checkId: string,
    rawPreview: string,
    config: FirecrawlConfig,
    usage: UsageSnapshot | null = null
  ): DynamicGenericToolResult {
    const refresh: A2uiAction = {
      id: 'web.monitor.check',
      label: '刷新检查详情',
      prompt: '刷新检查详情',
      kind: 'prompt',
      variant: 'secondary',
      args: monitorArgs(id, checkId)
    };
    const rows: A2uiLabelValueData[] = [
      { label: 'Monitor ID', value: id },
      { label: 'Check ID', value: checkId },
      {
        label: 'Provider 状态',
        value: textOf(item.status).trim().length > 0 ? textOf(item.status).trim() : 'returned'
      }
    ];
    if (usage !== null) {
      appendRows(rows, usageRows(usage, config));
    }
    return {
      sourceTag: 'Firecrawl',
      toolName: toolId,
      title: 'Monitor 检查 ' + checkId,
      status: 'success',
      summary: 'Firecrawl 返回了真实检查记录。',
      rows: rows,
      rawPreview: redactExact(rawPreview, config).substring(0, SHORT_PREVIEW_CHARS),
      actions: [
        refresh,
        monitorAction('web.monitor.detail', '查看 Monitor', id)
      ]
    };
  }

  private async executeMonitorCreate(
    actionId: string,
    args: Object | null,
    config: FirecrawlConfig
  ): Promise<FirecrawlToolOutput> {
    const toolId = 'web.monitor.create';
    const input: FirecrawlMonitorCreateArgs =
      args === null ? {} : args as FirecrawlMonitorCreateArgs;
    const hasPages = Array.isArray(input.pages) && input.pages.length > 0;
    const hasQueries = Array.isArray(input.queries) && input.queries.length > 0;
    const pages = monitorPages(input.pages);
    const queries = monitorQueries(input.queries);
    const goal = textOf(input.goal).trim();
    const name = textOf(input.name).trim();
    const scheduleText = textOf(input.scheduleText).trim().length > 0 ?
      textOf(input.scheduleText).trim() : 'daily';
    const timezone = textOf(input.timezone).trim().length > 0 ?
      textOf(input.timezone).trim() : 'Asia/Shanghai';
    const email = textOf(input.email).trim();
    if (hasPages === hasQueries || (hasPages && pages.length === 0) ||
      (hasQueries && queries.length === 0) || goal.length === 0) {
      return outputWith(
        errorResult(
          toolId,
          'error',
          'Provide valid pages (max 5) XOR queries (max 3), plus a goal.',
          '',
          0,
          config
        ),
        '创建网页监控',
        toolId
      );
    }
    if (actionId.length === 0) {
      const rows: A2uiLabelValueData[] = [
        { label: pages.length > 0 ? '页面数' : '查询数',
          value: (pages.length > 0 ? pages.length : queries.length).toString() },
        { label: 'Monitor 名称',
          value: name.length > 0 ? name : '未设置（由 Provider 生成）' },
        { label: '目标', value: goal },
        { label: '计划', value: scheduleText },
        { label: '时区', value: timezone },
        { label: '运行方式', value: '持续运行；Firecrawl 按计划执行' },
        { label: '停止方式', value: '创建后可暂停或删除 Monitor' },
        { label: '月度检查估算', value: monitorEstimate(pages, queries, scheduleText) }
      ];
      const targets = pages.length > 0 ? pages : queries;
      const targetLabel = pages.length > 0 ? '页面 ' : '查询 ';
      for (let index = 0; index < targets.length; index++) {
        rows.splice(index + 2, 0, {
          label: targetLabel + (index + 1).toString(),
          value: targets[index]
        });
      }
      if (email.length > 0) {
        rows.push({ label: 'Email', value: email });
      }
      const confirm: A2uiAction = {
        id: 'web.monitor.create.confirm',
        label: '确认创建监控',
        prompt: '确认创建 Firecrawl Monitor',
        kind: 'prompt',
        variant: 'primary',
        args: monitorCreateArgs(
          pages, queries, goal, name, scheduleText, timezone, email, true
        )
      };
      return outputWith({
        sourceTag: 'Firecrawl',
        toolName: toolId,
        title: '确认创建 Firecrawl Monitor',
        status: 'confirm_required',
        summary: '确认后才会调用 Provider 创建真实 Monitor。',
        rows: rows,
        rawPreview: '',
        actions: [confirm]
      }, '创建网页监控', toolId);
    }
    if (actionId !== 'web.monitor.create.confirm' || input.confirmed !== true) {
      return outputWith(
        errorResult(toolId, 'error', 'A matching visible confirmation is required.', '', 0, config),
        '创建网页监控',
        toolId
      );
    }
    const outcome = await this.callMonitor(
      toolId,
      'firecrawl_monitor_create',
      monitorCreateArgs(pages, queries, goal, name, scheduleText, timezone, email, false),
      true,
      config
    );
    if (!outcome.ok || outcome.value === null) {
      const result = errorResult(
        toolId, outcome.status, outcome.message, outcome.rawPreview, outcome.httpStatus, config
      );
      return outputWith(
        outcome.providerCalled ? resultWithRows(result, usageRows(outcome.usage, config)) : result,
        '创建网页监控',
        toolId
      );
    }
    const items = monitorItems(outcome.value, 'monitors');
    const item: FirecrawlMonitorItem = items.length > 0 ? items[0] : {};
    const id = textOf(item.id).trim();
    const providerName = textOf(item.name).trim();
    const monitorName = providerName.length > 0 ? providerName :
      (id.length > 0 ? name : '');
    const rows: A2uiLabelValueData[] = [
      { label: 'Monitor 名称', value: monitorName },
      { label: '名称来源', value: providerName.length > 0 ?
        'Provider 响应' : '本次已确认创建请求' },
      { label: 'Monitor ID', value: id },
      { label: 'Provider 状态', value: textOf(item.status).trim() }
    ];
    appendRows(rows, usageRows(outcome.usage, config));
    return outputWith({
      sourceTag: 'Firecrawl',
      toolName: toolId,
      title: id.length > 0 ? 'Monitor 已创建' : 'Provider 已接受创建请求',
      status: id.length > 0 ? 'success' : 'partial',
      summary: id.length > 0 ?
        'Firecrawl 返回了真实 Monitor ID。' :
        'Provider 响应未包含 Monitor ID，请重新查询 Monitor 列表确认。',
      rows: rows,
      rawPreview: redactExact(outcome.rawPreview, config).substring(0, SHORT_PREVIEW_CHARS),
      actions: id.length > 0 ? monitorActions(id) : []
    }, '创建网页监控', toolId);
  }

  private mutationPreview(
    toolId: string,
    actionId: string,
    id: string
  ): FirecrawlToolOutput {
    const destructive = actionId === 'web.monitor.delete';
    const labels: string[] = actionId === 'web.monitor.run' ?
      ['确认立即运行', '立即运行会触发一次真实 Provider 检查。'] :
      (actionId === 'web.monitor.pause' ?
        ['确认暂停监控', '暂停会修改真实 Provider Monitor 状态。'] :
        (actionId === 'web.monitor.resume' ?
          ['确认恢复监控', '恢复会修改真实 Provider Monitor 状态。'] :
          ['确认删除监控', '删除不可撤销，且返回成功后仍需重新查询确认。']));
    const confirm = monitorAction(
      actionId + '.confirm',
      labels[0],
      id,
      destructive ? 'danger' : 'primary',
      true
    );
    return outputWith({
      sourceTag: 'Firecrawl',
      toolName: toolId,
      title: labels[0],
      status: 'confirm_required',
      summary: labels[1],
      rows: [
        { label: 'Monitor ID', value: id },
        { label: 'Provider 状态', value: '尚未调用' }
      ],
      rawPreview: '',
      actions: [confirm]
    }, 'Firecrawl Monitor', toolId);
  }

  private async executeMonitorList(
    actionId: string,
    args: Object | null,
    config: FirecrawlConfig
  ): Promise<FirecrawlToolOutput> {
    const toolId = 'web.monitor.list';
    const input: FirecrawlMonitorActionArgs =
      args === null ? {} : args as FirecrawlMonitorActionArgs;
    const id = textOf(input.id).trim();
    const checkId = textOf(input.checkId).trim();
    const mutationActions: string[] = [
      'web.monitor.run', 'web.monitor.pause', 'web.monitor.resume', 'web.monitor.delete'
    ];
    if (mutationActions.indexOf(actionId) >= 0) {
      if (id.length === 0) {
        return outputWith(
          errorResult(toolId, 'error', 'A real Monitor ID is required.', '', 0, config),
          'Firecrawl Monitor',
          toolId
        );
      }
      return this.mutationPreview(toolId, actionId, id);
    }

    let mcpToolName = 'firecrawl_monitor_list';
    let callArgs = JSON.parse('{}') as Object;
    let mutation = false;
    if (actionId === 'web.monitor.detail') {
      mcpToolName = 'firecrawl_monitor_get';
      callArgs = monitorArgs(id);
    } else if (actionId === 'web.monitor.checks') {
      mcpToolName = 'firecrawl_monitor_checks';
      const limit = bounded(input.limit, 10, 100);
      callArgs = JSON.parse(
        '{"id":' + JSON.stringify(id) + ',"limit":' + limit.toString() + '}'
      ) as Object;
    } else if (actionId === 'web.monitor.check') {
      mcpToolName = 'firecrawl_monitor_check';
      callArgs = monitorArgs(id, checkId);
    } else if (actionId.endsWith('.confirm')) {
      mutation = true;
      if (input.confirmed !== true) {
        return outputWith(
          errorResult(toolId, 'error', 'A matching visible confirmation is required.', '', 0, config),
          'Firecrawl Monitor',
          toolId
        );
      }
      if (actionId === 'web.monitor.run.confirm') {
        mcpToolName = 'firecrawl_monitor_run';
        callArgs = monitorArgs(id);
      } else if (actionId === 'web.monitor.pause.confirm') {
        mcpToolName = 'firecrawl_monitor_update';
        callArgs = JSON.parse(
          '{"id":' + JSON.stringify(id) + ',"body":{"status":"paused"}}'
        ) as Object;
      } else if (actionId === 'web.monitor.resume.confirm') {
        mcpToolName = 'firecrawl_monitor_update';
        callArgs = JSON.parse(
          '{"id":' + JSON.stringify(id) + ',"body":{"status":"active"}}'
        ) as Object;
      } else if (actionId === 'web.monitor.delete.confirm') {
        mcpToolName = 'firecrawl_monitor_delete';
        callArgs = monitorArgs(id);
      } else {
        return outputWith(
          errorResult(toolId, 'error', 'Unsupported Monitor confirmation.', '', 0, config),
          'Firecrawl Monitor',
          toolId
        );
      }
    } else if (actionId.length === 0) {
      const fields: string[] = [];
      if (input.limit !== undefined && Number.isFinite(input.limit) && input.limit > 0) {
        fields.push('"limit":' + Math.floor(input.limit).toString());
      }
      if (input.offset !== undefined && Number.isFinite(input.offset) && input.offset >= 0) {
        fields.push('"offset":' + Math.floor(input.offset).toString());
      }
      callArgs = JSON.parse('{' + fields.join(',') + '}') as Object;
    } else {
      return outputWith(
        errorResult(toolId, 'error', 'Unsupported Monitor action.', '', 0, config),
        'Firecrawl Monitor',
        toolId
      );
    }
    if ((actionId.length > 0 && id.length === 0) ||
      (actionId === 'web.monitor.check' && checkId.length === 0)) {
      return outputWith(
        errorResult(toolId, 'error', 'Real Monitor and Check IDs are required.', '', 0, config),
        'Firecrawl Monitor',
        toolId
      );
    }

    const outcome = await this.callMonitor(
      toolId, mcpToolName, callArgs, mutation, config
    );
    if (!outcome.ok || outcome.value === null) {
      const result = errorResult(
        toolId, outcome.status, outcome.message, outcome.rawPreview, outcome.httpStatus, config
      );
      return outputWith(
        outcome.providerCalled ? resultWithRows(result, usageRows(outcome.usage, config)) : result,
        'Firecrawl Monitor',
        toolId
      );
    }
    if (mutation) {
      const deleting = actionId === 'web.monitor.delete.confirm';
      const rows: A2uiLabelValueData[] = [
        { label: 'Monitor ID', value: id },
        { label: 'Provider 状态', value: deleting ? '待重新查询确认' : 'success' }
      ];
      appendRows(rows, usageRows(outcome.usage, config));
      return outputWith({
        sourceTag: 'Firecrawl',
        toolName: toolId,
        title: deleting ? '删除请求已返回' : 'Monitor 变更已返回',
        status: deleting ? 'partial' : 'success',
        summary: deleting ?
          'Provider 已返回删除成功，但这不是最终删除证明；请重新列表或查看详情，确认该 ID 不再返回。' :
          'Provider 已返回真实 Monitor 变更结果。',
        rows: rows,
        rawPreview: redactExact(outcome.rawPreview, config).substring(0, SHORT_PREVIEW_CHARS),
        actions: deleting ?
          [monitorAction('web.monitor.detail', '查询删除状态', id)] : monitorActions(id)
      }, 'Firecrawl Monitor', toolId);
    }

    if (actionId === 'web.monitor.checks' || actionId === 'web.monitor.check') {
      const items = monitorItems(outcome.value, 'checks');
      const results: DynamicGenericToolResult[] = [];
      for (let index = 0; index < items.length; index++) {
        const realCheckId = textOf(items[index].checkId).trim().length > 0 ?
          textOf(items[index].checkId).trim() : textOf(items[index].id).trim();
        const realMonitorId = textOf(items[index].monitorId).trim();
        const validCheck = realCheckId.length > 0 && realMonitorId === id &&
          (actionId !== 'web.monitor.check' || realCheckId === checkId);
        if (validCheck) {
          results.push(this.monitorCheckResult(
            toolId,
            items[index],
            id,
            realCheckId,
            outcome.rawPreview,
            config,
            results.length === 0 ? outcome.usage : null
          ));
        }
      }
      if (results.length > 0) {
        return { title: 'Firecrawl Monitor', intent: toolId, results: results };
      }
      return outputWith(
        resultWithRows(
          errorResult(toolId, actionId === 'web.monitor.check' ? 'error' : 'empty',
            actionId === 'web.monitor.check' ?
              'Provider Check ID or Monitor ID was empty or did not match the request.' :
              'Provider returned no valid Monitor checks.',
            '',
            outcome.httpStatus, config),
          usageRows(outcome.usage, config)
        ),
        'Firecrawl Monitor',
        toolId
      );
    }

    const items = monitorItems(outcome.value, 'monitors');
    const results: DynamicGenericToolResult[] = [];
    for (let index = 0; index < items.length; index++) {
      const realId = textOf(items[index].id).trim();
      if (realId.length > 0 && (actionId !== 'web.monitor.detail' || realId === id)) {
        results.push(this.monitorResult(
          toolId,
          items[index],
          realId,
          outcome.rawPreview,
          config,
          results.length === 0 ? outcome.usage : null
        ));
      }
    }
    if (results.length > 0) {
      return { title: 'Firecrawl Monitor', intent: toolId, results: results };
    }
    return outputWith(
      resultWithRows(
        errorResult(toolId, actionId === 'web.monitor.detail' ? 'error' : 'empty',
          actionId === 'web.monitor.detail' ?
            'Provider Monitor ID was empty or did not match the request.' :
            'Provider returned no valid Monitors.',
          '',
          outcome.httpStatus, config),
        usageRows(outcome.usage, config)
      ),
      'Firecrawl Monitor',
      toolId
    );
  }

  async execute(
    toolId: string,
    prompt: string,
    actionId: string,
    args: Object | null,
    config: FirecrawlConfig,
    onPartial: ((output: FirecrawlToolOutput) => void) | null = null
  ): Promise<FirecrawlToolOutput> {
    if (config.apiKey.trim().length === 0) {
      return outputWith(errorResult(
        toolId, 'needs_auth', 'Firecrawl API key is required.', '', 0, config
      ), toolId === 'web.page.read' ? '网页读取' : toolId, toolId);
    }
    if (toolId === 'web.research.search') {
      return this.executeResearch(prompt, args, config);
    }
    if (toolId === 'shopping.research') {
      return this.executeShopping(args, config, onPartial);
    }
    if (toolId === 'social.public.search') {
      return this.executeSocial(args, config, onPartial);
    }
    if (toolId === 'web.monitor.create') {
      return this.executeMonitorCreate(actionId, args, config);
    }
    if (toolId === 'web.monitor.list') {
      return this.executeMonitorList(actionId, args, config);
    }
    if (toolId !== 'web.page.read') {
      return outputWith(errorResult(
        toolId, 'error', 'Unsupported Firecrawl business tool.', '', 0, config
      ), toolId, toolId);
    }
    const pageArgs: FirecrawlPageReadArgs = args === null ? {} : args as FirecrawlPageReadArgs;
    const url = firecrawlHttpUrlOf(pageArgs.url);
    if (url.length === 0) {
      return outputWith(errorResult(
        toolId, 'error', 'A single HTTP(S) URL is required.', '', 0, config
      ));
    }

    const registration = registrationFor(toolId, 'firecrawl_scrape', config);
    const preflightFailure = await this.ensurePreflight(toolId, registration, config);
    if (preflightFailure !== null) {
      return outputWith(preflightFailure);
    }

    const question = textOf(pageArgs.question).trim();
    const startedAt = Date.now();
    let call: McpToolCallResult;
    try {
      call = await this.client.callToolPayload(
        registration,
        config.apiKey,
        pageReadArguments(url, question)
      );
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Firecrawl request failed.';
      const status = normalizedStatus(0, message);
      this.lifecycle(true, toolId, registration.mcpToolName, 'call_exception',
        0, status, 0, startedAt);
      return outputWith(resultWithRows(
        errorResult(toolId, status, message, message, 0, config),
        usageRows(usageOf(null), config)
      ));
    }

    const parsed = parsePayload(call.result);
    const root = parsed.value;
    const page = root === null ? null : pageResponseOf(root);
    const usage = usageOf(
      page,
      root === null || page === root ? null : root
    );
    const metadataStatus = page?.metadata?.statusCode === undefined ? call.httpStatus :
      page.metadata.statusCode as number;
    const errorMessage = failureText(call, page);
    if (!call.ok || call.result === null || call.result.isError === true ||
      page?.success === false) {
      const status = normalizedScrapeFailureStatus(call, page, parsed, metadataStatus);
      this.lifecycle(true, toolId, registration.mcpToolName, 'call_failed',
        metadataStatus, status, 1, startedAt);
      return outputWith(resultWithRows(
        errorResult(
          toolId,
          status,
          errorMessage,
          parsed.rawText.length > 0 ? parsed.rawText : call.rawPreview,
          metadataStatus,
          config
        ),
        usageRows(usage, config)
      ));
    }
    if (page === null) {
      const status: FirecrawlResultStatus = parsed.rawText.trim().length === 0 ? 'empty' : 'error';
      this.lifecycle(status === 'error', toolId, registration.mcpToolName, 'parse',
        metadataStatus, status, 1, startedAt);
      return outputWith(resultWithRows(
        errorResult(
          toolId,
          status,
          status === 'empty' ?
            'Firecrawl returned an empty body.' : 'Firecrawl returned unparseable text.',
          parsed.rawText,
          metadataStatus,
          config
        ),
        usageRows(usage, config)
      ));
    }

    const metadata: FirecrawlPageMetadata =
      page.metadata === undefined || page.metadata === null ? {} : page.metadata;
    const providerSignal = providerStateText(page);
    const originStatus = normalizedOriginStatus(metadataStatus, providerSignal);
    if (metadataStatus >= 400 || originStatus !== 'error') {
      this.lifecycle(true, toolId, registration.mcpToolName, 'origin_failed',
        metadataStatus, originStatus, 1, startedAt);
      return outputWith(resultWithRows(
        errorResult(
          toolId, originStatus, providerSignal, parsed.rawText, metadataStatus, config
        ),
        usageRows(usage, config)
      ));
    }

    const questionData: FirecrawlQuestionData | undefined =
      page.json === undefined || page.json === null ?
      undefined : page.json as FirecrawlQuestionData;
    const answer = questionData === undefined ? '' : textOf(questionData.answer).trim();
    const markdown = textOf(page.markdown);
    const body = question.length > 0 ? answer : markdown;
    if (body.trim().length === 0) {
      this.lifecycle(false, toolId, registration.mcpToolName, 'empty',
        metadataStatus, 'empty', 1, startedAt);
      return outputWith(resultWithRows(
        errorResult(
          toolId, 'empty', 'Firecrawl returned an empty page body.', '', metadataStatus, config
        ),
        usageRows(usage, config)
      ));
    }
    if (loginOnlyBody(body)) {
      this.lifecycle(true, toolId, registration.mcpToolName, 'blocked',
        metadataStatus, 'blocked_by_site', 1, startedAt);
      return outputWith(resultWithRows(
        errorResult(
          toolId, 'blocked_by_site', 'The page requires login or CAPTCHA access.',
          body, metadataStatus, config
        ),
        usageRows(usage, config)
      ));
    }

    const providerSourceUrl = textOf(metadata.sourceURL).trim().length > 0 ?
      textOf(metadata.sourceURL).trim() : textOf(metadata.url).trim();
    const validatedSourceUrl = firecrawlHttpUrlOf(providerSourceUrl);
    const sourceUrl = validatedSourceUrl.length > 0 ? validatedSourceUrl : url;
    const fetchedAt = this.timestampProvider();
    const publishedAt = textOf(metadata.publishedTime).trim().length > 0 ?
      textOf(metadata.publishedTime).trim() : textOf(metadata.publishedAt).trim();
    const rows: A2uiLabelValueData[] = [
      { label: 'URL', value: sourceUrl },
      { label: '抓取时间', value: fetchedAt }
    ];
    if (publishedAt.length > 0) {
      rows.push({ label: '发布时间', value: publishedAt });
    }
    rows.push({ label: 'Provider 状态', value: 'success' });
    appendRows(rows, usageRows(usage, config));
    if (questionData !== undefined && Array.isArray(questionData.evidence) &&
      questionData.evidence.length > 0) {
      const evidence = questionData.evidence as string[];
      rows.push({ label: '证据', value: evidence.join('\n') });
    }
    const previewSource = question.length > 0 && questionData !== undefined ?
      JSON.stringify(questionData) : markdown;
    const previewLimit = pageArgs.includeFullText === true ? FULL_PREVIEW_CHARS : SHORT_PREVIEW_CHARS;
    if (previewSource.length > previewLimit) {
      rows.push({ label: '正文状态', value: '已截断' });
    }
    const action: A2uiAction = {
      id: 'web.open.source',
      label: '打开原网页',
      prompt: sourceUrl,
      kind: 'client',
      variant: 'secondary'
    };
    const summary = (question.length > 0 ? answer : markdown.trim()).substring(0, SUMMARY_CHARS);
    const result: DynamicGenericToolResult = {
      sourceTag: 'Firecrawl',
      toolName: toolId,
      title: textOf(metadata.title).trim().length > 0 ? textOf(metadata.title).trim() : sourceUrl,
      status: 'success',
      summary: summary,
      rows: rows,
      rawPreview: redactExact(previewSource, config).substring(0, previewLimit),
      actions: [action]
    };
    this.lifecycle(false, toolId, registration.mcpToolName, 'call_success',
      metadataStatus, 'success', 1, startedAt);
    return outputWith(result);
  }
}
