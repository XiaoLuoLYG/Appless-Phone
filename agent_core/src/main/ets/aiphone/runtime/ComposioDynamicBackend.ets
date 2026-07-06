import { ComposioConfig } from '../../composio/ComposioConfig';
import { ComposioSessionClient } from '../../composio/ComposioSessionClient';
import { A2uiLabelValueData } from './A2uiTypes';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import { isUnsafeMcpTool } from './DynamicToolRegistry';

interface ComposioExecuteArgs {
  operation?: string;
  toolSlug?: string;
  arguments?: Object;
}

interface ComposioSearchTool {
  toolSlug?: string;
  description?: string;
  inputSchema?: string;
}

interface ComposioSearchObservation {
  source?: string;
  authorizedToolkits?: string[];
  tools?: Object[];
  instruction?: string;
}

let composioConfig: ComposioConfig = new ComposioConfig('', 'https://backend.composio.dev/api/v3.1', '');
let composioClient: ComposioSessionClient | null = null;

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

function parsedExecuteArgs(args: Object | null): ComposioExecuteArgs {
  if (args === null) {
    return {};
  }
  return args as ComposioExecuteArgs;
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

function firstToolSlug(payload: ComposioSearchObservation): string {
  if (!Array.isArray(payload.tools) || payload.tools.length === 0) {
    return '';
  }
  return textOf((payload.tools[0] as ComposioSearchTool).toolSlug);
}

export function configureComposioConfigFromRawJson(rawJson: string): void {
  composioConfig = ComposioConfig.fromRawJson(rawJson);
  composioClient = null;
}

export function isComposioConfigured(): boolean {
  return composioConfig.isConfigured();
}

export function isComposioDynamicPrompt(prompt: string): boolean {
  const lower = prompt.toLowerCase();
  return lower.indexOf('notion') >= 0 ||
    lower.indexOf('google drive') >= 0 ||
    lower.indexOf('linear') >= 0 ||
    lower.indexOf('github') >= 0 ||
    lower.indexOf('asana') >= 0 ||
    lower.indexOf('trello') >= 0 ||
    lower.indexOf('hubspot') >= 0 ||
    lower.indexOf('salesforce') >= 0;
}

export function isUnsafeComposioExecute(toolSlug: string, argsJson: string): boolean {
  return isUnsafeMcpTool(toolSlug, argsJson);
}

export function composioDynamicMissingConfigResult(prompt: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Composio',
    toolName: 'dynamic.search',
    title: 'Composio 未配置',
    status: 'needs_auth',
    summary: 'Composio 未配置 apiKey/userId，无法查询已授权应用工具。',
    rows: [{ label: '请求', value: prompt.substring(0, 240) }],
    rawPreview: prompt
  };
}

export function composioDynamicResultFromObservation(phase: string, observation: string): DynamicGenericToolResult {
  try {
    const payload = JSON.parse(observation) as ComposioSearchObservation;
    const slug = firstToolSlug(payload);
    return {
      sourceTag: 'Composio',
      toolName: 'dynamic.search',
      title: phase === 'execute' ? 'Composio 执行结果' : 'Composio 工具候选',
      status: 'success',
      summary: slug.length > 0 ? 'Composio 找到候选工具：' + slug : 'Composio 返回了真实结果。',
      rows: rowsForSearch(payload),
      rawPreview: observation.substring(0, 16000)
    };
  } catch (_error) {
    const failed = observation.indexOf('失败') >= 0 || observation.indexOf('错误') >= 0 || observation.indexOf('未配置') >= 0;
    return {
      sourceTag: 'Composio',
      toolName: 'dynamic.search',
      title: failed ? 'Composio 调用失败' : 'Composio 返回',
      status: failed ? 'error' : 'success',
      summary: observation.substring(0, 240),
      rows: [{ label: '阶段', value: phase }],
      rawPreview: observation.substring(0, 16000)
    };
  }
}

async function client(): Promise<ComposioSessionClient> {
  if (composioClient === null) {
    composioClient = new ComposioSessionClient(composioConfig);
    await composioClient.initialize();
  }
  return composioClient;
}

export async function callComposioDynamic(prompt: string, args: Object | null): Promise<DynamicGenericToolResult | null> {
  const parsed = parsedExecuteArgs(args);
  const operation = textOf(parsed.operation).trim();
  if (!isComposioDynamicPrompt(prompt) && operation !== 'execute') {
    return null;
  }
  if (!composioConfig.isConfigured()) {
    return composioDynamicMissingConfigResult(prompt);
  }
  const current = await client();
  if (operation === 'execute') {
    const slug = textOf(parsed.toolSlug).trim();
    const argText = JSON.stringify(parsed.arguments ?? new Object());
    if (isUnsafeComposioExecute(slug, argText)) {
      return {
        sourceTag: 'Composio',
        toolName: 'dynamic.search',
        title: 'Composio 高风险动作已阻断',
        status: 'unsafe_action_blocked',
        summary: '该 Composio 工具可能会创建、发送、更新或删除外部数据，当前版本不会自动执行。',
        rows: [{ label: 'toolSlug', value: slug }],
        rawPreview: argText.substring(0, 16000)
      };
    }
    return composioDynamicResultFromObservation('execute', await current.execute(slug, parsed.arguments ?? new Object()));
  }
  return composioDynamicResultFromObservation('search', await current.search(prompt));
}
