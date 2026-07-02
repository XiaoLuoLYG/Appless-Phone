import { http } from '@kit.NetworkKit';
import {
  DynamicCredentialSpec,
  DynamicGenericToolResult,
  DynamicMcpTool,
  DynamicPreflightResult,
  DynamicToolRegistration
} from './DynamicToolTypes';
import { A2uiLabelValueData } from './A2uiTypes';

const MCP_PROTOCOL_VERSION: string = '2025-06-18';

class EmptyMcpCapabilities {}

class EmptyMcpParams {}

interface McpInitializeClientInfo {
  name: string;
  version: string;
}

interface McpInitializeParams {
  protocolVersion: string;
  capabilities: EmptyMcpCapabilities;
  clientInfo: McpInitializeClientInfo;
}

interface McpToolsCallParams {
  name: string;
  arguments: Object;
}

type McpJsonRpcParams = McpInitializeParams | EmptyMcpParams | McpToolsCallParams;

export interface McpJsonRpcRequest {
  jsonrpc: string;
  id: number;
  method: string;
  params: McpJsonRpcParams;
}

export interface McpToolsCallRequest {
  jsonrpc: string;
  id: number;
  method: string;
  params: McpToolsCallParams;
}

type McpPostRequest = McpJsonRpcRequest | McpToolsCallRequest;

interface McpJsonRpcError {
  code?: number;
  message?: string;
  data?: Object | string | number | boolean;
}

interface McpJsonRpcPayload {
  result?: Object;
  error?: McpJsonRpcError;
}

interface McpToolListResult {
  tools?: Object[];
}

interface McpToolRecord {
  name?: string;
  description?: string;
  inputSchema?: Object;
}

export interface McpToolContentItem {
  type?: string;
  text?: string;
  data?: Object | string | number | boolean;
}

export interface McpToolResultPayload {
  content?: McpToolContentItem[];
  structuredContent?: Object;
  isError?: boolean;
}

export interface ParsedMcpResponse {
  ok: boolean;
  errorMessage: string;
  tools: DynamicMcpTool[];
  result: McpToolResultPayload | null;
}

interface HttpMcpResponse {
  status: number;
  text: string;
  sessionId: string;
}

export function buildInitializeRequest(id: number): McpJsonRpcRequest {
  return {
    jsonrpc: '2.0',
    id: id,
    method: 'initialize',
    params: {
      protocolVersion: MCP_PROTOCOL_VERSION,
      capabilities: new EmptyMcpCapabilities(),
      clientInfo: {
        name: 'aiphone-dynamic-mcp',
        version: '0.1'
      }
    }
  };
}

export function buildToolsListRequest(id: number): McpJsonRpcRequest {
  return {
    jsonrpc: '2.0',
    id: id,
    method: 'tools/list',
    params: new EmptyMcpParams()
  };
}

export function buildToolsCallRequest(id: number, name: string, args: Object): McpToolsCallRequest {
  return {
    jsonrpc: '2.0',
    id: id,
    method: 'tools/call',
    params: {
      name: name,
      arguments: args
    }
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

function toolsFromResult(result: Object | undefined): DynamicMcpTool[] {
  if (result === undefined || result === null) {
    return [];
  }
  const record = result as McpToolListResult;
  if (!Array.isArray(record.tools)) {
    return [];
  }
  return record.tools.map((item: Object): DynamicMcpTool => {
    const tool = item as McpToolRecord;
    return {
      name: textOf(tool.name),
      description: textOf(tool.description),
      inputSchema: tool.inputSchema === undefined || tool.inputSchema === null ? new Object() : tool.inputSchema
    };
  }).filter((tool: DynamicMcpTool) => tool.name.length > 0);
}

export function parseMcpJsonRpcResponse(raw: string): ParsedMcpResponse {
  try {
    const payload = JSON.parse(jsonRpcPayloadText(raw)) as McpJsonRpcPayload;
    if (payload.error !== undefined && payload.error !== null) {
      return {
        ok: false,
        errorMessage: textOf(payload.error.message),
        tools: [],
        result: null
      };
    }
    return {
      ok: true,
      errorMessage: '',
      tools: toolsFromResult(payload.result),
      result: payload.result as McpToolResultPayload
    };
  } catch (error) {
    return {
      ok: false,
      errorMessage: error instanceof Error ? error.message : JSON.stringify(error),
      tools: [],
      result: null
    };
  }
}

function jsonRpcPayloadText(raw: string): string {
  const trimmed = raw.trim();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return trimmed;
  }

  const lines = raw.split('\n');
  let payload = '';
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index].trim();
    if (!line.startsWith('data:')) {
      continue;
    }
    const data = line.substring(5).trim();
    if (data.length === 0 || data === '[DONE]') {
      continue;
    }
    payload = data;
  }
  return payload.length > 0 ? payload : trimmed;
}

export function inferCredentialFromMcpFailure(httpStatus: number, message: string): DynamicCredentialSpec | null {
  const lower = message.toLowerCase();
  if (httpStatus === 401 ||
    lower.indexOf('authorization') >= 0 ||
    lower.indexOf('unauthorized') >= 0 ||
    lower.indexOf('missing authorization') >= 0) {
    return {
      name: 'Authorization',
      description: 'Bearer token required by the MCP server',
      required: true,
      placement: 'header',
      scheme: 'Bearer',
      testValue: ''
    };
  }
  if (lower.indexOf('api key') >= 0 || lower.indexOf('apikey') >= 0) {
    return {
      name: 'api_key',
      description: 'API key required by the MCP server',
      required: true,
      placement: 'query',
      scheme: '',
      testValue: ''
    };
  }
  return null;
}

function rowsFromObject(value: Object): A2uiLabelValueData[] {
  return Object.keys(value).slice(0, 8).map((key: string) => {
    const record = value as Record<string, Object | string | number | boolean | null | undefined>;
    const row: A2uiLabelValueData = {
      label: key,
      value: textOf(record[key]).substring(0, 160)
    };
    return row;
  });
}

export function summarizeMcpToolResult(payload: McpToolResultPayload): DynamicGenericToolResult {
  const textParts: string[] = [];
  if (Array.isArray(payload.content)) {
    payload.content.forEach((item: McpToolContentItem) => {
      const itemText = textOf(item.text);
      const text = itemText.length > 0 ? itemText : textOf(item.data);
      if (text.length > 0) {
        textParts.push(text);
      }
    });
  }
  const structured = payload.structuredContent === undefined || payload.structuredContent === null ? new Object() : payload.structuredContent;
  const rawPreview = JSON.stringify(payload).substring(0, 1200);
  return {
    sourceTag: 'MCP',
    toolName: '',
    title: payload.isError === true ? 'MCP 工具返回错误' : 'MCP 工具结果',
    status: payload.isError === true ? 'error' : 'success',
    summary: textParts.length > 0 ? textParts.join(' · ').substring(0, 240) : rawPreview.substring(0, 240),
    rows: rowsFromObject(structured),
    rawPreview: rawPreview
  };
}

function headerValue(headers: Object, key: string): string {
  const record = headers as Record<string, Object | string | number | boolean | null | undefined>;
  const lower = key.toLowerCase();
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    if (keys[index].toLowerCase() === lower) {
      return textOf(record[keys[index]]);
    }
  }
  return '';
}

async function postMcpJson(url: string, body: McpPostRequest, headers: Record<string, string>, sessionId: string): Promise<HttpMcpResponse> {
  const request = http.createHttp();
  try {
    const requestHeaders: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/event-stream',
      'MCP-Protocol-Version': MCP_PROTOCOL_VERSION
    };
    Object.keys(headers).forEach((key: string) => requestHeaders[key] = headers[key]);
    if (sessionId.length > 0) {
      requestHeaders['Mcp-Session-Id'] = sessionId;
    }
    const response = await request.request(url, {
      method: http.RequestMethod.POST,
      header: requestHeaders,
      extraData: JSON.stringify(body),
      connectTimeout: 10000,
      readTimeout: 20000
    });
    return {
      status: response.responseCode,
      text: textOf(response.result),
      sessionId: headerValue(response.header, 'Mcp-Session-Id')
    };
  } finally {
    request.destroy();
  }
}

function headersForRegistration(registration: DynamicToolRegistration, credentialValue: string): Record<string, string> {
  const headers: Record<string, string> = {};
  Object.keys(registration.transport.headers).forEach((key: string) => headers[key] = registration.transport.headers[key]);
  if (credentialValue.length > 0 && headers.Authorization === undefined) {
    headers.Authorization = 'Bearer ' + credentialValue;
  }
  return headers;
}

function failedPreflight(
  status: number,
  message: string,
  resultStatus: 'needs_auth' | 'preflight_failed'
): DynamicPreflightResult {
  return {
    ok: false,
    status: resultStatus,
    httpStatus: status,
    message: message,
    inferredCredential: inferCredentialFromMcpFailure(status, message),
    tools: []
  };
}

export class GenericMcpClient {
  async preflight(registration: DynamicToolRegistration, credentialValue: string): Promise<DynamicPreflightResult> {
    const headers = headersForRegistration(registration, credentialValue);
    const init = await postMcpJson(registration.transport.url, buildInitializeRequest(1), headers, '');
    const initParsed = parseMcpJsonRpcResponse(init.text);
    if (init.status < 200 || init.status >= 300) {
      const message = initParsed.errorMessage.length > 0 ? initParsed.errorMessage : 'HTTP ' + init.status.toString();
      const status = inferCredentialFromMcpFailure(init.status, message) === null ? 'preflight_failed' : 'needs_auth';
      return failedPreflight(init.status, message, status);
    }
    if (!initParsed.ok) {
      const status = inferCredentialFromMcpFailure(init.status, initParsed.errorMessage) === null ? 'preflight_failed' : 'needs_auth';
      return failedPreflight(init.status, initParsed.errorMessage, status);
    }
    const listed = await postMcpJson(registration.transport.url, buildToolsListRequest(2), headers, init.sessionId);
    const parsed = parseMcpJsonRpcResponse(listed.text);
    const ok = listed.status >= 200 && listed.status < 300 && parsed.ok;
    const message = parsed.errorMessage.length > 0 ? parsed.errorMessage : (ok ? '' : 'HTTP ' + listed.status.toString());
    return {
      ok: ok,
      status: ok ? 'enabled' : 'preflight_failed',
      httpStatus: listed.status,
      message: message,
      inferredCredential: inferCredentialFromMcpFailure(listed.status, message),
      tools: parsed.tools
    };
  }

  async callTool(registration: DynamicToolRegistration, credentialValue: string, args: Object): Promise<DynamicGenericToolResult> {
    const headers = headersForRegistration(registration, credentialValue);
    const init = await postMcpJson(registration.transport.url, buildInitializeRequest(1), headers, '');
    const initParsed = parseMcpJsonRpcResponse(init.text);
    if (init.status < 200 || init.status >= 300 || !initParsed.ok) {
      return {
        sourceTag: registration.displayName,
        toolName: registration.mcpToolName,
        title: 'MCP 初始化失败',
        status: 'error',
        summary: initParsed.errorMessage.length > 0 ? initParsed.errorMessage : 'HTTP ' + init.status.toString(),
        rows: [{ label: '状态', value: init.status.toString() }],
        rawPreview: init.text.substring(0, 1200)
      };
    }
    const response = await postMcpJson(registration.transport.url, buildToolsCallRequest(3, registration.mcpToolName, args), headers, init.sessionId);
    const parsed = parseMcpJsonRpcResponse(response.text);
    if (response.status < 200 || response.status >= 300 || !parsed.ok || parsed.result === null) {
      return {
        sourceTag: registration.displayName,
        toolName: registration.mcpToolName,
        title: 'MCP 工具调用失败',
        status: 'error',
        summary: parsed.errorMessage.length > 0 ? parsed.errorMessage : 'HTTP ' + response.status.toString(),
        rows: [{ label: '状态', value: response.status.toString() }],
        rawPreview: response.text.substring(0, 1200)
      };
    }
    const result = summarizeMcpToolResult(parsed.result);
    result.sourceTag = registration.displayName;
    result.toolName = registration.mcpToolName;
    return result;
  }
}
