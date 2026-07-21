import { A2uiAction, A2uiLabelValueData } from './A2uiTypes';

export type DynamicToolTransportType = 'streamable_http' | 'sse' | 'stdio' | 'http_api' | 'unsupported';
export type DynamicToolStatus = 'candidate' | 'enabled' | 'needs_auth' | 'preflight_failed' | 'unsupported_transport' | 'unsafe_action_blocked';

export interface DynamicCredentialSpec {
  name: string;
  description: string;
  required: boolean;
  placement: string;
  scheme: string;
  testValue: string;
}

export interface DynamicToolTransport {
  type: DynamicToolTransportType;
  url: string;
  command: string;
  args: string[];
  headers: Record<string, string>;
  env: Record<string, string>;
  method?: string;
  credentialPlacement?: string;
  credentialParam?: string;
  queryParam?: string;
  fixedQuery?: string;
  forecastQuery?: string;
}

export interface McpToolAnnotations {
  title?: string;
  readOnlyHint?: boolean;
  destructiveHint?: boolean;
  idempotentHint?: boolean;
  openWorldHint?: boolean;
}

export interface DynamicMcpTool {
  name: string;
  description: string;
  inputSchema: Object;
  outputSchema?: Object;
  annotations?: McpToolAnnotations;
}

export interface DynamicToolManifest {
  id: string;
  displayName: string;
  sourceUrl: string;
  hosted: boolean;
  fromSiteUrl: string;
  capabilities: string[];
  requiredCredentials: DynamicCredentialSpec[];
  transports: DynamicToolTransport[];
  tools: DynamicMcpTool[];
}

export interface DynamicToolRegistration {
  toolId: string;
  manifestId: string;
  displayName: string;
  status: DynamicToolStatus;
  transport: DynamicToolTransport;
  mcpToolName: string;
  credentialRef: string;
  sourceUrl: string;
  lastError: string;
}

export interface DynamicPreflightResult {
  ok: boolean;
  status: DynamicToolStatus;
  httpStatus: number;
  message: string;
  inferredCredential: DynamicCredentialSpec | null;
  tools: DynamicMcpTool[];
}

export interface DynamicGenericToolResult {
  sourceTag: string;
  toolName: string;
  title: string;
  status: string;
  summary: string;
  rows: A2uiLabelValueData[];
  rawPreview: string;
  actions?: A2uiAction[];
  registration?: DynamicRegistrationMetadata;
  providerPhase?: 'discovery' | 'execution';
}

export interface GenericStructuredData {
  results: DynamicGenericToolResult[];
}

export interface DynamicRegistrationMetadata {
  provider: string;
  qualifiedName: string;
  inputSchema: Object;
  outputSchema: Object;
  receipt: string;
}

interface DynamicReceiptEnvelope {
  request_id?: Object | string | number | boolean | null;
  requestId?: Object | string | number | boolean | null;
  execution_id?: Object | string | number | boolean | null;
  executionId?: Object | string | number | boolean | null;
  trace_id?: Object | string | number | boolean | null;
  traceId?: Object | string | number | boolean | null;
  tool_call_id?: Object | string | number | boolean | null;
  toolCallId?: Object | string | number | boolean | null;
  error?: Object | string | number | boolean | null;
  metadata?: Object | string | number | boolean | null;
}

function receiptText(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null || typeof value === 'object') {
    return '';
  }
  return `${value}`.trim();
}

function boundedReceipt(value: string): string {
  const source = value.trim();
  let result = '';
  for (let index = 0; index < source.length && result.length < 128; index++) {
    const char = source.charAt(index);
    const code = source.charCodeAt(index);
    const allowed = code >= 48 && code <= 57 || code >= 65 && code <= 90 || code >= 97 && code <= 122 ||
      char === '.' || char === '_' || char === '-' || char === ':';
    if (allowed) {
      result += char;
    }
  }
  return result;
}

function receiptFromEnvelope(envelope: DynamicReceiptEnvelope): string {
  const values = [
    envelope.request_id, envelope.requestId, envelope.execution_id, envelope.executionId,
    envelope.trace_id, envelope.traceId, envelope.tool_call_id, envelope.toolCallId
  ];
  for (let index = 0; index < values.length; index++) {
    const receipt = boundedReceipt(receiptText(values[index]));
    if (receipt.length > 0) {
      return receipt;
    }
  }
  return '';
}

function nestedReceipt(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return '';
  }
  return receiptFromEnvelope(value as DynamicReceiptEnvelope);
}

export function dynamicReceiptFromProviderPayload(payload: string): string {
  try {
    const envelope = JSON.parse(payload) as DynamicReceiptEnvelope;
    const direct = receiptFromEnvelope(envelope);
    if (direct.length > 0) {
      return direct;
    }
    const errorReceipt = nestedReceipt(envelope.error);
    return errorReceipt.length > 0 ? errorReceipt : nestedReceipt(envelope.metadata);
  } catch (_error) {
    return '';
  }
}

export interface DynamicStructuredData extends GenericStructuredData {
  registration: DynamicRegistrationMetadata;
}

export interface DynamicReadExecution extends GenericStructuredData {
  registration: DynamicRegistrationMetadata;
}

export type DynamicReadExecutor = (prompt: string, args: Object | null) => Promise<DynamicReadExecution>;

export interface ModelScopeSchemaProperty {
  type?: string;
  description?: string;
  placeholder?: string;
  test_value?: string;
}

export interface ModelScopeEnvSchema {
  type?: string;
  required?: string[];
  properties?: Record<string, ModelScopeSchemaProperty>;
}

export interface ModelScopeMcpTool {
  name?: string;
  description?: string;
  inputSchema?: Object;
  outputSchema?: Object;
}

export interface ModelScopeMcpServer {
  type?: string;
  url?: string;
  command?: string;
  args?: string[];
  env?: Record<string, string>;
  headers?: Record<string, string>;
}

export interface ModelScopeMcpServerConfig {
  mcpServers?: Record<string, ModelScopeMcpServer>;
}

export interface ModelScopeMcpDetail {
  ChineseName?: string;
  Name?: string;
  Path?: string;
  Hosted?: boolean;
  FromSiteUrl?: string;
  Category?: string[];
  EnvSchema?: ModelScopeEnvSchema;
  ServerConfig?: ModelScopeMcpServerConfig[] | null;
  SSEServerConfig?: ModelScopeMcpServerConfig[] | null;
  StreamableHTTPServerConfig?: ModelScopeMcpServerConfig[] | null;
  SupportedDeployTransportType?: string[];
  Tools?: ModelScopeMcpTool[];
}
