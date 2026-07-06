import http from '@ohos.net.http';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ComposioConfig } from './ComposioConfig';

const LOG_DOMAIN: number = 0x1200;
const LOG_TAG: string = 'LoopComposio';
const CONNECT_TIMEOUT_MS: number = 15000;
const READ_TIMEOUT_MS: number = 30000;
const MAX_OBSERVATION_CHARS: number = 16000;
const MAX_ACCOUNT_PAGES: number = 10;

interface ConnectedAccountToolkit {
  slug?: string;
}

interface ConnectedAccount {
  id?: string;
  user_id?: string;
  status?: string;
  is_disabled?: boolean;
  toolkit?: ConnectedAccountToolkit;
}

interface ConnectedAccountsResponse {
  items?: ConnectedAccount[];
  next_cursor?: string;
}

interface SessionToolkits {
  enable: string[];
}

interface EnableSetting {
  enable: boolean;
}

interface ExecuteSetting {
  enable_multi_execute: boolean;
}

interface SessionCreateRequest {
  user_id: string;
  toolkits: SessionToolkits;
  connected_accounts: Record<string, string[]>;
  manage_connections: EnableSetting;
  workbench: EnableSetting;
  multi_account: EnableSetting;
  search: EnableSetting;
  execute: ExecuteSetting;
}

interface SessionCreateResponse {
  session_id?: string;
}

interface SearchQuery {
  use_case: string;
}

interface SearchRequest {
  queries: SearchQuery[];
}

interface SearchResult {
  primary_tool_slugs?: string[];
  related_tool_slugs?: string[];
  error?: string;
}

interface SearchToolSchema {
  tool_slug?: string;
  description?: string;
  input_schema?: Object;
}

interface SearchResponse {
  success?: boolean;
  error?: string;
  results?: SearchResult[];
  tool_schemas?: Record<string, SearchToolSchema>;
}

interface SearchCandidate {
  toolSlug: string;
  description: string;
  inputSchema: string;
}

interface SearchObservation {
  source: string;
  authorizedToolkits: string[];
  tools: SearchCandidate[];
  instruction: string;
}

interface ExecuteRequest {
  tool_slug: string;
  arguments: Object;
  enable_auto_workbench_offload: boolean;
}

interface TruncatedObservation {
  source: string;
  truncated: boolean;
  preview: string;
}

interface HttpResult {
  code: number;
  text: string;
}

interface ComposioErrorDetail {
  message?: string;
  suggested_fix?: string;
  request_id?: string;
}

interface ComposioErrorResponse {
  error?: ComposioErrorDetail | string;
  message?: string;
  suggested_fix?: string;
  request_id?: string;
}

export class ComposioSessionClient {
  private config: ComposioConfig;
  private toolkitAccounts: Map<string, string> = new Map();
  private discoveryError: string = '';
  private initialized: boolean = false;
  private sessionId: string = '';
  private sessionPromise: Promise<string> | null = null;
  private discoveredTools: Set<string> = new Set();

  constructor(config: ComposioConfig) {
    this.config = config;
  }

  async initialize(): Promise<void> {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    if (!this.config.isConfigured()) {
      this.discoveryError = `Composio 未配置：${this.config.missingConfiguration()}`;
      return;
    }
    try {
      await this.discoverConnectedAccounts();
      if (this.toolkitAccounts.size === 0) {
        this.discoveryError = `Composio 用户 ${this.config.userId} 没有 ACTIVE connected account`;
      }
    } catch (error) {
      this.discoveryError = this.safeFailure('发现授权 Toolkit', error);
    }
  }

  toolDescription(): string {
    const toolkits = this.authorizedToolkits();
    const availability = toolkits.length > 0
      ? `Authorized toolkits: ${toolkits.join(', ')}.`
      : `No authorized toolkit discovered${this.discoveryError.length > 0 ? ` (${this.discoveryError})` : ''}.`;
    return 'Use only when the user request needs one of the authorized Composio toolkits. ' +
      `${availability} Do not call for unrelated requests. Two phases are mandatory: first call ` +
      '{"operation":"search","useCase":"the full user task"}, then use a returned schema and call ' +
      '{"operation":"execute","toolSlug":"returned slug","arguments":{...}}. ' +
      'Discovered tools execute immediately, including tools with side effects.';
  }

  async search(useCase: string): Promise<string> {
    if (useCase.trim().length === 0) {
      return 'Composio 搜索参数错误：useCase 不能为空。';
    }
    try {
      const sessionId = await this.ensureSession();
      const query: SearchQuery = { use_case: useCase.trim() };
      const body: SearchRequest = { queries: [query] };
      const response = await this.request(
        http.RequestMethod.POST,
        `/tool_router/session/${sessionId}/search`,
        JSON.stringify(body)
      );
      if (!this.isSuccess(response.code)) {
        return this.httpError('搜索工具', response);
      }
      return this.parseSearchResponse(response.text);
    } catch (error) {
      return this.safeFailure('搜索工具', error);
    }
  }

  async execute(toolSlug: string, args: Object): Promise<string> {
    const normalizedSlug = toolSlug.trim().toUpperCase();
    if (!this.discoveredTools.has(normalizedSlug)) {
      return `Composio 拒绝执行：${normalizedSlug} 尚未通过当前 Session 的 search 发现。`;
    }
    try {
      const sessionId = await this.ensureSession();
      const body: ExecuteRequest = {
        tool_slug: normalizedSlug,
        arguments: args,
        enable_auto_workbench_offload: false
      };
      const response = await this.request(
        http.RequestMethod.POST,
        `/tool_router/session/${sessionId}/execute`,
        JSON.stringify(body)
      );
      if (!this.isSuccess(response.code)) {
        return this.httpError('执行工具', response);
      }
      return this.limitObservation(response.text);
    } catch (error) {
      return this.safeFailure('执行工具', error);
    }
  }

  async close(): Promise<void> {
    const id = this.sessionId;
    this.sessionId = '';
    this.sessionPromise = null;
    this.discoveredTools.clear();
    if (id.length === 0 || !this.config.isConfigured()) {
      return;
    }
    try {
      await this.request(http.RequestMethod.DELETE, `/tool_router/session/${id}`, '');
      hilog.info(LOG_DOMAIN, LOG_TAG, 'session closed');
    } catch (_error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'session close failed');
    }
  }

  private async discoverConnectedAccounts(): Promise<void> {
    let cursor = '';
    for (let page = 0; page < MAX_ACCOUNT_PAGES; page++) {
      let path = `/connected_accounts?user_ids=${encodeURIComponent(this.config.userId)}` +
        '&statuses=ACTIVE&limit=100&order_by=updated_at&order_direction=desc';
      if (cursor.length > 0) {
        path += `&cursor=${encodeURIComponent(cursor)}`;
      }
      const response = await this.request(http.RequestMethod.GET, path, '');
      if (!this.isSuccess(response.code)) {
        throw new Error(this.httpError('查询 Connected Accounts', response));
      }
      let parsed: ConnectedAccountsResponse;
      try {
        parsed = JSON.parse(response.text) as ConnectedAccountsResponse;
      } catch (_error) {
        throw new Error('Composio Connected Accounts 返回了非 JSON 响应');
      }
      const items = parsed.items ?? [];
      for (let index = 0; index < items.length; index++) {
        const account = items[index];
        const toolkit = account.toolkit?.slug?.trim().toLowerCase() ?? '';
        const accountId = account.id?.trim() ?? '';
        if (toolkit.length === 0 || accountId.length === 0 || account.is_disabled === true) {
          continue;
        }
        if (!this.toolkitAccounts.has(toolkit)) {
          this.toolkitAccounts.set(toolkit, accountId);
        }
      }
      cursor = parsed.next_cursor ?? '';
      if (cursor.length === 0) {
        break;
      }
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, 'authorized toolkits=%{public}d', this.toolkitAccounts.size);
  }

  private async ensureSession(): Promise<string> {
    await this.initialize();
    if (this.sessionId.length > 0) {
      return this.sessionId;
    }
    if (this.toolkitAccounts.size === 0) {
      throw new Error(this.discoveryError.length > 0 ? this.discoveryError : 'Composio 没有已授权 Toolkit');
    }
    if (this.sessionPromise === null) {
      this.sessionPromise = this.createSession();
    }
    try {
      this.sessionId = await this.sessionPromise;
      return this.sessionId;
    } finally {
      this.sessionPromise = null;
    }
  }

  private async createSession(): Promise<string> {
    const toolkits = this.authorizedToolkits();
    const connectedAccounts: Record<string, string[]> = {};
    for (let index = 0; index < toolkits.length; index++) {
      const toolkit = toolkits[index];
      const accountId = this.toolkitAccounts.get(toolkit);
      if (accountId !== undefined) {
        connectedAccounts[toolkit] = [accountId];
      }
    }
    const body: SessionCreateRequest = {
      user_id: this.config.userId,
      toolkits: { enable: toolkits },
      connected_accounts: connectedAccounts,
      manage_connections: { enable: false },
      workbench: { enable: false },
      multi_account: { enable: false },
      search: { enable: true },
      execute: { enable_multi_execute: false }
    };
    const response = await this.request(
      http.RequestMethod.POST,
      '/tool_router/session',
      JSON.stringify(body)
    );
    if (response.code !== 201 && response.code !== 200) {
      throw new Error(this.httpError('创建 Session', response));
    }
    let parsed: SessionCreateResponse;
    try {
      parsed = JSON.parse(response.text) as SessionCreateResponse;
    } catch (_error) {
      throw new Error('Composio 创建 Session 返回了非 JSON 响应');
    }
    const id = parsed.session_id ?? '';
    if (id.length === 0) {
      throw new Error('Composio 创建 Session 成功但未返回 session_id');
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, 'session created');
    return id;
  }

  private parseSearchResponse(text: string): string {
    let parsed: SearchResponse;
    try {
      parsed = JSON.parse(text) as SearchResponse;
    } catch (_error) {
      return 'Composio 搜索工具失败：响应不是有效 JSON。';
    }
    if (parsed.success === false || (parsed.error ?? '').length > 0) {
      return `Composio 搜索工具失败：${parsed.error ?? '服务返回失败状态'}`;
    }
    const slugs: Set<string> = new Set();
    const results = parsed.results ?? [];
    for (let index = 0; index < results.length; index++) {
      this.addSlugs(slugs, results[index].primary_tool_slugs);
      this.addSlugs(slugs, results[index].related_tool_slugs);
    }
    const schemas = parsed.tool_schemas ?? {};
    this.addSlugs(slugs, Object.keys(schemas));

    const candidates: SearchCandidate[] = [];
    slugs.forEach((slug: string) => {
      const normalized = slug.toUpperCase();
      this.discoveredTools.add(normalized);
      const schema = schemas[slug] ?? schemas[normalized];
      candidates.push({
        toolSlug: normalized,
        description: schema?.description ?? '',
        inputSchema: schema?.input_schema === undefined ? '{}' : JSON.stringify(schema.input_schema)
      });
    });
    if (candidates.length === 0) {
      return 'Composio 没有在已授权 Toolkit 中找到匹配工具。';
    }
    const observation: SearchObservation = {
      source: 'Composio',
      authorizedToolkits: this.authorizedToolkits(),
      tools: candidates,
      instruction: 'Choose one returned toolSlug and call composio with operation=execute and arguments matching inputSchema.'
    };
    return this.limitObservation(JSON.stringify(observation));
  }

  private authorizedToolkits(): string[] {
    const result: string[] = [];
    this.toolkitAccounts.forEach((_accountId: string, toolkit: string) => {
      result.push(toolkit);
    });
    result.sort();
    return result;
  }

  private addSlugs(target: Set<string>, values: string[] | undefined): void {
    if (values === undefined) {
      return;
    }
    for (let index = 0; index < values.length; index++) {
      target.add(values[index]);
    }
  }

  private async request(method: http.RequestMethod, path: string, body: string): Promise<HttpResult> {
    const request = http.createHttp();
    const url = `${this.config.baseUrl}${path}`;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'request method=%{public}s path=%{public}s', `${method}`, path);
    try {
      const response = await request.request(url, {
        method: method,
        header: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
          'x-api-key': this.config.apiKey
        },
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS
      });
      const result: HttpResult = {
        code: response.responseCode,
        text: `${response.result ?? ''}`
      };
      hilog.info(LOG_DOMAIN, LOG_TAG, 'response status=%{public}d', result.code);
      return result;
    } finally {
      request.destroy();
    }
  }

  private isSuccess(code: number): boolean {
    return code >= 200 && code < 300;
  }

  private httpError(action: string, response: HttpResult): string {
    let message = '';
    let suggestedFix = '';
    let requestId = '';
    try {
      const parsed = JSON.parse(response.text) as ComposioErrorResponse;
      if (typeof parsed.error === 'string') {
        message = parsed.error.trim();
      } else if (parsed.error !== undefined) {
        message = parsed.error.message?.trim() ?? '';
        suggestedFix = parsed.error.suggested_fix?.trim() ?? '';
        requestId = parsed.error.request_id?.trim() ?? '';
      }
      if (message.length === 0) {
        message = parsed.message?.trim() ?? '';
      }
      if (suggestedFix.length === 0) {
        suggestedFix = parsed.suggested_fix?.trim() ?? '';
      }
      if (requestId.length === 0) {
        requestId = parsed.request_id?.trim() ?? '';
      }
    } catch (_error) {
    }
    let result = `Composio ${action}失败：HTTP ${response.code}`;
    if (message.length > 0) {
      result += `；${message}`;
    }
    if (suggestedFix.length > 0) {
      result += `；建议：${suggestedFix}`;
    }
    if (requestId.length > 0) {
      result += `；request_id=${requestId}`;
    }
    return `${result}。`;
  }

  private safeFailure(action: string, error: Error | Object | string): string {
    const message = error instanceof Error ? error.message : `${error}`;
    return `Composio ${action}失败：${message}`;
  }

  private limitObservation(text: string): string {
    if (text.length <= MAX_OBSERVATION_CHARS) {
      return text;
    }
    const truncated: TruncatedObservation = {
      source: 'Composio',
      truncated: true,
      preview: text.substring(0, MAX_OBSERVATION_CHARS)
    };
    return JSON.stringify(truncated);
  }
}
