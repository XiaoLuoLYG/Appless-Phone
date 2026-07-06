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

function normalizedComposioUseCase(prompt: string): string {
  const keyword = promptSearchKeyword(prompt);
  if (containsAny(prompt, ['slack']) && containsAny(prompt, ['消息', 'message', 'mention', '提到'])) {
    return 'Search Slack messages mentioning ' + keyword;
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

function preferredToolScore(prompt: string, tool: ComposioSearchTool): number {
  const slug = textOf(tool.toolSlug).toLowerCase();
  const description = textOf(tool.description).toLowerCase();
  if (slug.length === 0 || isUnsafeComposioExecute(slug, '{}')) {
    return -10000;
  }
  let score = 0;
  if (slug.indexOf('search') >= 0 || slug.indexOf('find') >= 0) {
    score += 24;
  }
  if (slug.indexOf('list') >= 0 || slug.indexOf('get') >= 0 || slug.indexOf('fetch') >= 0 || slug.indexOf('retrieve') >= 0) {
    score += 8;
  }
  if (description.indexOf('search') >= 0 || description.indexOf('find') >= 0) {
    score += 6;
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

function bestToolForPrompt(payload: ComposioSearchObservation, prompt: string): ComposioSearchTool | null {
  if (!Array.isArray(payload.tools) || payload.tools.length === 0) {
    return null;
  }
  let best: ComposioSearchTool | null = null;
  let bestScore = -10000;
  payload.tools.forEach((item: Object) => {
    const tool = item as ComposioSearchTool;
    const score = preferredToolScore(prompt, tool);
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
    setIfSupported(args, schema, 'limit', 5);
    setIfSupported(args, schema, 'page_size', 5);
    return args;
  }
  if (lower === 'slack_search_messages') {
    setIfSupported(args, schema, 'query', keyword);
    setIfSupported(args, schema, 'sort', 'timestamp');
    setIfSupported(args, schema, 'count', 5);
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
  if (lower === 'page' || lower.indexOf('page') >= 0) {
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

function argumentsForTool(tool: ComposioSearchTool, prompt: string): Object {
  const schema = parsedInputSchema(textOf(tool.inputSchema));
  const slug = textOf(tool.toolSlug).trim();
  const args = specialArgumentsForTool(slug, prompt, schema);
  const properties = schema.properties ?? {};
  const names = propertyNames(schema);
  names.forEach((name: string) => {
    if (args[name] !== undefined) {
      return;
    }
    const lower = name.toLowerCase();
    if (lower === 'query' || lower === 'q' || lower.indexOf('search') >= 0 || lower.indexOf('keyword') >= 0 ||
      lower.indexOf('limit') >= 0 || lower.indexOf('count') >= 0 || lower.indexOf('page') >= 0 ||
      lower.indexOf('sort') >= 0 || lower.indexOf('order') >= 0) {
      args[name] = fallbackValueForProperty(name, properties[name], prompt);
    }
  });
  const required = schema.required ?? [];
  required.forEach((name: string) => {
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
  const record = item as Record<string, Object | string | number | boolean | null | undefined>;
  const title = stringField(record, ['title', 'name', 'subject', 'filename', 'file_name']);
  if (title.length > 0) {
    return title;
  }
  const text = stringField(record, ['text', 'message', 'body', 'snippet']);
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
  const record = item as Record<string, Object | string | number | boolean | null | undefined>;
  const parts: string[] = [];
  const number = stringField(record, ['number', 'id']);
  if (number.length > 0) {
    parts.push('#' + number);
  }
  const state = stringField(record, ['state', 'status', 'mimeType']);
  if (state.length > 0) {
    parts.push(state);
  }
  const author = nestedStringField(record, ['author', 'user', 'from', 'owner']);
  if (author.length > 0) {
    parts.push(author);
  }
  const time = stringField(record, ['updated_at', 'updatedAt', 'modifiedTime', 'created_at', 'createdTime', 'timestamp', 'ts']);
  if (time.length > 0) {
    parts.push(time);
  }
  const url = stringField(record, ['html_url', 'url', 'web_url', 'webViewLink', 'permalink']);
  if (url.length > 0) {
    parts.push(url);
  }
  const snippet = stringField(record, ['snippet', 'text', 'message', 'body']);
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
  const preferred = ['pull_requests', 'files', 'matches', 'items', 'results', 'documents'];
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

function topLevelMessage(payload: Record<string, Object | string | number | boolean | null | undefined>): string {
  const data = payload.data;
  if (data !== undefined && data !== null && typeof data === 'object' && !Array.isArray(data)) {
    const dataRecord = data as Record<string, Object | string | number | boolean | null | undefined>;
    return stringField(dataRecord, ['composio_execution_message', 'message', 'summary']);
  }
  return stringField(payload, ['message', 'summary', 'error']);
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
  return 'Composio 工具结果';
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
  composioClient = null;
}

export function isComposioConfigured(): boolean {
  return composioConfig.isConfigured();
}

export function isComposioDynamicPrompt(prompt: string): boolean {
  const lower = prompt.toLowerCase();
  return lower.indexOf('notion') >= 0 ||
    lower.indexOf('google drive') >= 0 ||
    lower.indexOf('google docs') >= 0 ||
    lower.indexOf('google doc') >= 0 ||
    lower.indexOf('linear') >= 0 ||
    lower.indexOf('github') >= 0 ||
    lower.indexOf('asana') >= 0 ||
    lower.indexOf('trello') >= 0 ||
    lower.indexOf('hubspot') >= 0 ||
    lower.indexOf('salesforce') >= 0 ||
    lower.indexOf('composio') >= 0;
}

function isReadOnlyComposioTool(toolSlug: string): boolean {
  const lower = toolSlug.toLowerCase();
  return lower === 'github_find_pull_requests' ||
    lower === 'googledrive_find_file' ||
    lower === 'googledocs_search_documents' ||
    lower === 'slack_search_messages' ||
    lower.indexOf('_search') >= 0 ||
    lower.indexOf('_find') >= 0 ||
    lower.indexOf('_list') >= 0 ||
    lower.indexOf('_get') >= 0 ||
    lower.indexOf('_fetch') >= 0 ||
    lower.indexOf('_retrieve') >= 0;
}

export function isUnsafeComposioExecute(toolSlug: string, argsJson: string): boolean {
  if (isReadOnlyComposioTool(toolSlug)) {
    return false;
  }
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

export function composioDynamicResultFromObservation(
  phase: string,
  observation: string,
  toolSlug: string = '',
  prompt: string = ''
): DynamicGenericToolResult {
  try {
    const payload = JSON.parse(observation) as ComposioSearchObservation;
    if (phase === 'execute') {
      const rows = rowsForExecute(payload as Object, prompt, toolSlug.length > 0 ? toolSlug : 'dynamic.search');
      return {
        sourceTag: 'Composio',
        toolName: toolSlug.length > 0 ? toolSlug : 'dynamic.search',
        title: resultTitleForTool(toolSlug),
        status: 'success',
        summary: executeSummary(toolSlug.length > 0 ? toolSlug : 'dynamic.search', rows),
        rows: rows,
        rawPreview: observation.substring(0, 16000)
      };
    }
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

async function callComposioSearchAndExecute(current: ComposioSessionClient, prompt: string): Promise<DynamicGenericToolResult> {
  const searchObservation = await current.search(normalizedComposioUseCase(prompt));
  let payload: ComposioSearchObservation;
  try {
    payload = JSON.parse(searchObservation) as ComposioSearchObservation;
  } catch (_error) {
    return composioDynamicResultFromObservation('search', searchObservation);
  }
  const tool = bestToolForPrompt(payload, prompt);
  if (tool === null) {
    return composioDynamicResultFromObservation('search', searchObservation);
  }
  const slug = textOf(tool.toolSlug).trim();
  const args = argumentsForTool(tool, prompt);
  const argText = JSON.stringify(args);
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
  return composioDynamicResultFromObservation('execute', await current.execute(slug, args), slug, prompt);
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
    return composioDynamicResultFromObservation('execute', await current.execute(slug, parsed.arguments ?? new Object()), slug, prompt);
  }
  return callComposioSearchAndExecute(current, prompt);
}
