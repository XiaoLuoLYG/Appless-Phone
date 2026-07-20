import http from '@ohos.net.http';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  DynamicGenericToolResult,
  DynamicMcpTool,
  DynamicToolRegistration,
  McpToolAnnotations
} from '../aiphone/runtime/DynamicToolTypes';
import { GenericMcpClient } from '../aiphone/runtime/GenericMcpClient';
import { ModelScopeClient } from './ModelScopeClient';
import { ModelScopeConfig } from './ModelScopeConfig';

const LOG_DOMAIN: number = 0x1200;
const LOG_TAG: string = 'LoopModelScope';
const CONNECT_TIMEOUT_MS: number = 15000;
const READ_TIMEOUT_MS: number = 90000;
const MAX_OBSERVATION_CHARS: number = 16000;
const MAX_SEARCH_TOOLS: number = 24;
const MAX_DESCRIPTION_TOOLS: number = 36;
const MAX_TOOL_DESCRIPTION_CHARS: number = 220;

interface HttpResult {
  code: number;
  text: string;
}

interface OperationalEnvelope {
  success?: boolean;
  message?: string;
  error?: string;
  data?: Object;
}

interface OperationalPayload {
  mcp_server_list?: Object[];
  servers?: Object[];
}

interface RawOperationalServer {
  id?: string;
  name?: string;
  description?: string;
  mcp_servers?: Object[];
  operational_urls?: Object[];
}

interface RawOperationalUrl {
  url?: string;
  type?: string;
}

interface DirectServer {
  serverId: string;
  name: string;
  description: string;
  endpoint: string;
}

interface DirectTool {
  qualifiedName: string;
  serverId: string;
  serverName: string;
  name: string;
  description: string;
  risk: string;
  inputSchema: Object;
  mcpTool: DynamicMcpTool;
  registration: DynamicToolRegistration;
}

interface SearchCandidate {
  qualifiedName: string;
  serverId: string;
  serverName: string;
  name: string;
  description: string;
  risk: string;
  inputSchema: Object;
  annotations?: McpToolAnnotations;
}

interface SearchObservation {
  source: string;
  mode: string;
  useCase: string;
  tools: SearchCandidate[];
  instruction: string;
}

interface ScoredTool {
  tool: DirectTool;
  score: number;
}

interface TruncatedObservation {
  source: string;
  truncated: boolean;
  preview: string;
}

export type ModelScopeExecutionDecision = 'allow' | 'unsearched' | 'missing' | 'unsafe';

export function modelScopeExecutionDecision(
  wasDiscovered: boolean,
  tool: DynamicMcpTool | null
): ModelScopeExecutionDecision {
  if (!wasDiscovered) {
    return 'unsearched';
  }
  if (tool === null) {
    return 'missing';
  }
  const annotations = tool.annotations;
  if (annotations === undefined ||
    annotations.readOnlyHint !== true ||
    annotations.destructiveHint === true) {
    return 'unsafe';
  }
  return 'allow';
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

function safeSegment(value: string): string {
  let result = '';
  const chars = Array.from(value);
  for (let index = 0; index < chars.length; index++) {
    const char = chars[index];
    result += /[A-Za-z0-9_-]/.test(char) ? char : '_';
  }
  return result.length > 0 ? result : 'tool';
}

export class ModelScopeDirectClient implements ModelScopeClient {
  private config: ModelScopeConfig;
  private mcp: GenericMcpClient = new GenericMcpClient();
  private initialized: boolean = false;
  private syncError: string = '';
  private serverCount: number = 0;
  private toolCount: number = 0;
  private tools: DirectTool[] = [];
  private discoveredTools: Set<string> = new Set();

  constructor(config: ModelScopeConfig) {
    this.config = config;
  }

  async initialize(): Promise<void> {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    if (!this.config.isConfigured()) {
      this.syncError = `ModelScope Direct 未配置：${this.config.missingConfiguration()}`;
      return;
    }
    try {
      const servers = await this.fetchOperationalServers();
      this.serverCount = servers.length;
      const loadedTools: DirectTool[] = [];
      const errors: string[] = [];
      for (let serverIndex = 0; serverIndex < servers.length; serverIndex++) {
        const server = servers[serverIndex];
        try {
          const preflightRegistration = this.registrationFor(server, '');
          const preflight = await this.mcp.preflight(preflightRegistration, '');
          if (!preflight.ok) {
            throw new Error(preflight.message.length > 0 ? preflight.message : `MCP HTTP ${preflight.httpStatus}`);
          }
          for (let toolIndex = 0; toolIndex < preflight.tools.length; toolIndex++) {
            const tool = preflight.tools[toolIndex];
            const qualifiedName = this.qualifiedToolName(serverIndex, server.serverId, tool.name);
            loadedTools.push({
              qualifiedName: qualifiedName,
              serverId: server.serverId,
              serverName: server.name,
              name: tool.name,
              description: tool.description,
              risk: modelScopeExecutionDecision(true, tool) === 'allow' ? 'read' : 'blocked',
              inputSchema: tool.inputSchema,
              mcpTool: tool,
              registration: this.registrationFor(server, tool.name)
            });
          }
        } catch (error) {
          errors.push(`${server.name.length > 0 ? server.name : server.serverId}: ${this.errorMessage(error)}`);
        }
      }
      this.tools = loadedTools;
      this.toolCount = loadedTools.length;
      if (errors.length > 0) {
        this.syncError = `部分 MCP 同步失败：${errors.join('；')}`;
      }
      hilog.info(LOG_DOMAIN, LOG_TAG, 'direct synced servers=%{public}d tools=%{public}d', this.serverCount, this.toolCount);
    } catch (error) {
      this.syncError = this.safeFailure('同步 MCP', error);
    }
  }

  toolDescription(): string {
    if (!this.config.isConfigured()) {
      return `ModelScope Direct unavailable (${this.syncError}). Do not call this tool.`;
    }
    const availability = this.syncError.length === 0
      ? `${this.serverCount} activated MCP servers and ${this.toolCount} tools are available via direct ModelScope.`
      : `${this.serverCount} servers are available via direct ModelScope with warning: ${this.syncError}.`;
    return 'Use only when the user request can be fulfilled by an activated ModelScope MCP tool. ' +
      `${availability} Available tools: ${this.catalogSummary()} ` +
      'Two phases are mandatory: search with the full use case, then execute one returned qualifiedName. ' +
      'Never invent qualifiedName. Only risk=read tools execute; all other tools are blocked.';
  }

  async search(useCase: string): Promise<string> {
    const query = useCase.trim();
    if (query.length === 0) {
      return 'ModelScope 搜索参数错误：useCase 不能为空。';
    }
    await this.initialize();
    if (!this.config.isConfigured()) {
      return this.syncError;
    }
    if (this.tools.length === 0) {
      return this.syncError.length > 0
        ? `ModelScope Direct 没有可用工具：${this.syncError}`
        : 'ModelScope Direct 没有在已激活 MCP 中找到可用工具。';
    }
    this.discoveredTools.clear();
    const selected = this.rankTools(this.tools, query);
    const candidates: SearchCandidate[] = [];
    const observation: SearchObservation = {
      source: 'ModelScope',
      mode: 'direct',
      useCase: query,
      tools: candidates,
      instruction: 'Choose exactly one returned qualifiedName. Arguments must match inputSchema. Execute only tools whose risk is read. Output <appless_tool>modelscope({"operation":"execute","qualifiedName":"returned qualifiedName","arguments":{}})</appless_tool>. Ordinary status text may follow the closing tag, but do not emit another tool call.'
    };
    const emptyObservation = JSON.stringify(observation);
    if (emptyObservation.length > MAX_OBSERVATION_CHARS) {
      return this.limitObservation(emptyObservation);
    }
    for (let index = 0; index < selected.length; index++) {
      const tool = selected[index].tool;
      candidates.push({
        qualifiedName: tool.qualifiedName,
        serverId: tool.serverId,
        serverName: tool.serverName,
        name: tool.name,
        description: tool.description,
        risk: tool.risk,
        inputSchema: tool.inputSchema,
        annotations: tool.mcpTool.annotations
      });
      const candidateObservation = JSON.stringify(observation);
      if (candidateObservation.length > MAX_OBSERVATION_CHARS) {
        candidates.pop();
        break;
      }
    }
    for (let index = 0; index < candidates.length; index++) {
      this.discoveredTools.add(candidates[index].qualifiedName);
    }
    return JSON.stringify(observation);
  }

  async execute(qualifiedName: string, args: Object): Promise<string> {
    const normalized = qualifiedName.trim();
    if (normalized.length === 0) {
      return 'ModelScope 执行参数错误：qualifiedName 不能为空。';
    }
    const tool = this.findTool(normalized);
    const selectedMcpTool = tool === null ? null : tool.mcpTool;
    const decision = modelScopeExecutionDecision(this.discoveredTools.has(normalized), selectedMcpTool);
    if (decision === 'unsearched') {
      return `ModelScope 拒绝执行：${normalized} 尚未通过最近一次 search 发现。`;
    }
    if (decision === 'missing' || tool === null) {
      return `ModelScope 执行失败：${normalized} 不在当前同步工具列表中。`;
    }
    if (decision === 'unsafe') {
      return `UnsafeActionBlocked: ${normalized} 未明确标记为只读工具，当前版本拒绝执行。`;
    }
    try {
      const content: DynamicGenericToolResult = await this.mcp.callTool(tool.registration, '', args);
      return this.limitObservation(JSON.stringify({
        source: 'ModelScope',
        mode: 'direct',
        status: content.status,
        qualifiedName: normalized,
        risk: tool.risk,
        content: content
      }));
    } catch (error) {
      return this.safeFailure('执行工具', error);
    }
  }

  private async fetchOperationalServers(): Promise<DirectServer[]> {
    const response = await this.request(`${this.config.modelscopeApiBaseUrl}/openapi/v1/mcp/servers/operational`);
    if (response.code < 200 || response.code >= 300) {
      throw new Error(`ModelScope HTTP ${response.code}: ${response.text.substring(0, 500)}`);
    }
    const envelope = JSON.parse(response.text) as OperationalEnvelope;
    if (envelope.success === false) {
      const message = textOf(envelope.message).length > 0 ? textOf(envelope.message) : textOf(envelope.error);
      throw new Error(message.length > 0 ? message : 'ModelScope rejected the request');
    }
    const payload = envelope.data as OperationalPayload;
    if (payload === undefined || payload === null) {
      throw new Error('ModelScope response is missing data');
    }
    const rawServers = Array.isArray(payload.mcp_server_list) ? payload.mcp_server_list : (payload.servers ?? []);
    const servers: DirectServer[] = [];
    for (let index = 0; index < rawServers.length; index++) {
      const raw = rawServers[index] as RawOperationalServer;
      const endpoint = this.endpointFromServer(raw);
      const serverId = textOf(raw.id);
      if (serverId.length === 0 || endpoint.length === 0) {
        continue;
      }
      servers.push({
        serverId: serverId,
        name: textOf(raw.name).length > 0 ? textOf(raw.name) : serverId,
        description: textOf(raw.description),
        endpoint: endpoint
      });
    }
    return servers;
  }

  private endpointFromServer(raw: RawOperationalServer): string {
    const urls = Array.isArray(raw.mcp_servers) && raw.mcp_servers.length > 0
      ? raw.mcp_servers
      : (raw.operational_urls ?? []);
    for (let index = 0; index < urls.length; index++) {
      const item = urls[index] as RawOperationalUrl;
      const url = textOf(item.url);
      const type = textOf(item.type).toLowerCase();
      if (url.length > 0 && (type.length === 0 || type === 'streamable_http' ||
        url.endsWith('/mcp') || url.endsWith('/streamable_http'))) {
        return url;
      }
    }
    return '';
  }

  private async request(url: string): Promise<HttpResult> {
    const request = http.createHttp();
    hilog.info(LOG_DOMAIN, LOG_TAG, 'direct request url=%{public}s', url);
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json',
          'Authorization': `Bearer ${this.config.modelscopeToken}`
        },
        expectDataType: http.HttpDataType.STRING,
        usingProxy: false,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS
      });
      return {
        code: response.responseCode,
        text: textOf(response.result)
      };
    } finally {
      request.destroy();
    }
  }

  private registrationFor(server: DirectServer, mcpToolName: string): DynamicToolRegistration {
    return {
      toolId: `modelscope.${safeSegment(server.serverId)}.${safeSegment(mcpToolName)}`,
      manifestId: `modelscope.${server.serverId}`,
      displayName: server.name,
      status: 'enabled',
      transport: {
        type: 'streamable_http',
        url: server.endpoint,
        command: '',
        args: [],
        headers: {},
        env: {}
      },
      mcpToolName: mcpToolName,
      credentialRef: '',
      sourceUrl: server.endpoint,
      lastError: ''
    };
  }

  private qualifiedToolName(serverIndex: number, serverId: string, toolName: string): string {
    const serverPart = safeSegment(serverId).substring(0, 20);
    const toolPart = safeSegment(toolName);
    return `mcp__${serverIndex.toString()}_${serverPart}__${toolPart}`.substring(0, 96);
  }

  private findTool(qualifiedName: string): DirectTool | null {
    for (let index = 0; index < this.tools.length; index++) {
      if (this.tools[index].qualifiedName === qualifiedName) {
        return this.tools[index];
      }
    }
    return null;
  }

  private rankTools(tools: DirectTool[], useCase: string): ScoredTool[] {
    const normalizedQuery = useCase.toLowerCase();
    const words = normalizedQuery.split(/[\s,，。；;：:、]+/);
    const scored: ScoredTool[] = [];
    for (let index = 0; index < tools.length; index++) {
      const tool = tools[index];
      const text = `${tool.name} ${tool.description} ${JSON.stringify(tool.inputSchema)}`.toLowerCase();
      let score = 0;
      for (let wordIndex = 0; wordIndex < words.length; wordIndex++) {
        const word = words[wordIndex];
        if (word.length > 0 && text.indexOf(word) >= 0) {
          score += word.length + 2;
        }
      }
      const chars = Array.from(normalizedQuery);
      for (let charIndex = 0; charIndex < chars.length; charIndex++) {
        const char = chars[charIndex];
        if (char.trim().length > 0 && text.indexOf(char) >= 0) {
          score += 1;
        }
      }
      scored.push({ tool: tool, score: score });
    }
    scored.sort((left: ScoredTool, right: ScoredTool): number => right.score - left.score);
    return scored.slice(0, MAX_SEARCH_TOOLS);
  }

  private catalogSummary(): string {
    if (!this.config.isConfigured()) {
      return 'not configured.';
    }
    if (!this.initialized) {
      return 'initializing.';
    }
    if (this.tools.length === 0) {
      return this.syncError.length > 0 ? `none (${this.syncError})` : 'none.';
    }
    const parts: string[] = [];
    const count = Math.min(this.tools.length, MAX_DESCRIPTION_TOOLS);
    for (let index = 0; index < count; index++) {
      const tool = this.tools[index];
      const description = tool.description.length > MAX_TOOL_DESCRIPTION_CHARS
        ? `${tool.description.substring(0, MAX_TOOL_DESCRIPTION_CHARS)}…`
        : tool.description;
      parts.push(`${tool.serverName}/${tool.name}: ${description}`);
    }
    if (this.tools.length > count) {
      parts.push(`...and ${this.tools.length - count} more`);
    }
    return parts.join(' | ');
  }

  private errorMessage(error: Error | Object | string): string {
    return error instanceof Error ? error.message : `${error}`;
  }

  private safeFailure(action: string, error: Error | Object | string): string {
    return `ModelScope Direct ${action}失败：${this.errorMessage(error)}`;
  }

  private limitObservation(text: string): string {
    if (text.length <= MAX_OBSERVATION_CHARS) {
      return text;
    }
    const observation: TruncatedObservation = {
      source: 'ModelScope',
      truncated: true,
      preview: text.substring(0, MAX_OBSERVATION_CHARS)
    };
    return JSON.stringify(observation);
  }
}
