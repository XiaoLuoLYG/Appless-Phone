import { DynamicGenericToolResult } from './DynamicToolTypes';
import {
  A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_TOOL_CONNECT_CARD,
  A2UI_VERSION,
  A2uiAction,
  A2uiComponent,
  A2uiDynamicToolConnectData,
  A2uiEnvelope,
  A2uiGenericToolResultData,
  A2uiSummaryData
} from './A2uiTypes';

export const GMAIL_WEB_URL: string = 'https://mail.google.com/mail/u/0/#inbox';
export const GMAIL_MCP_SERVER_URL: string = 'https://gmailmcp.googleapis.com/mcp/v1';
export const GMAIL_MCP_AUTH_SETUP_URL: string = 'https://developers.google.com/workspace/gmail/api/guides/configure-mcp-server';
const GMAIL_OAUTH_AUTH_URL: string = 'https://accounts.google.com/o/oauth2/v2/auth';
const GMAIL_OAUTH_SCOPES: string = 'https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.compose';
const GMAIL_MANIFEST_ID: string = 'google.gmail';
const GMAIL_DISPLAY_NAME: string = 'Gmail';
const GENERIC_RESULTS_PATH: string = '/genericToolResults';
const SUMMARY_PATH: string = '/summary';
const CONNECT_PATH: string = '/dynamicToolConnect';

function action(id: string, label: string, prompt: string, variant: string, kind: string): A2uiAction {
  return {
    id: id,
    label: label,
    prompt: prompt,
    variant: variant,
    kind: kind
  };
}

export function gmailOAuthAuthorizationUrl(clientId: string, redirectUri: string): string {
  const cleanedClientId = clientId.trim();
  const cleanedRedirectUri = redirectUri.trim();
  if (cleanedClientId.length === 0 || cleanedRedirectUri.length === 0) {
    return GMAIL_MCP_AUTH_SETUP_URL;
  }
  return GMAIL_OAUTH_AUTH_URL +
    '?client_id=' + encodeURIComponent(cleanedClientId) +
    '&redirect_uri=' + encodeURIComponent(cleanedRedirectUri) +
    '&response_type=code' +
    '&scope=' + encodeURIComponent(GMAIL_OAUTH_SCOPES) +
    '&access_type=offline' +
    '&prompt=consent' +
    '&include_granted_scopes=true' +
    '&state=aiphone_gmail_mcp';
}

function jsonLine(envelope: A2uiEnvelope): string {
  return JSON.stringify(envelope) + '\n';
}

function createSurfaceLine(surfaceId: string, title: string, status: string): string {
  return jsonLine({
    version: A2UI_VERSION,
    createSurface: {
      surfaceId: surfaceId,
      root: 'root',
      title: title,
      intent: 'gmail',
      status: status
    }
  });
}

function componentsLine(surfaceId: string, components: A2uiComponent[]): string {
  return jsonLine({
    version: A2UI_VERSION,
    updateComponents: {
      surfaceId: surfaceId,
      components: components
    }
  });
}

function dataLine(
  surfaceId: string,
  path: string,
  value: A2uiDynamicToolConnectData | A2uiGenericToolResultData[] | A2uiSummaryData
): string {
  return jsonLine({
    version: A2UI_VERSION,
    updateDataModel: {
      surfaceId: surfaceId,
      path: path,
      value: value
    }
  });
}

function rootComponent(title: string, status: string): A2uiComponent {
  return {
    id: 'root',
    component: A2UI_COMPONENT_SURFACE_ROOT,
    child: 'gmail_results',
    title: title,
    status: status
  };
}

function genericResultsComponent(title: string, status: string): A2uiComponent {
  return {
    id: 'gmail_results',
    component: A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
    title: title,
    dataPath: GENERIC_RESULTS_PATH,
    status: status
  };
}

function summary(text: string, toolName: string, count: number): A2uiSummaryData {
  return {
    text: text,
    toolName: toolName,
    dataLabel: GENERIC_RESULTS_PATH,
    count: count
  };
}

function genericResultsA2ui(
  surfaceId: string,
  title: string,
  surfaceStatus: string,
  componentStatus: string,
  results: A2uiGenericToolResultData[],
  summaryData: A2uiSummaryData
): string {
  return createSurfaceLine(surfaceId, title, surfaceStatus) +
    componentsLine(surfaceId, [
      rootComponent(title, componentStatus),
      genericResultsComponent(title, componentStatus)
    ]) +
    dataLine(surfaceId, GENERIC_RESULTS_PATH, results) +
    dataLine(surfaceId, SUMMARY_PATH, summaryData);
}

function genericResultsFromDynamic(results: DynamicGenericToolResult[]): A2uiGenericToolResultData[] {
  const mapped: A2uiGenericToolResultData[] = [];
  results.forEach((result: DynamicGenericToolResult) => {
    mapped.push({
      sourceTag: result.sourceTag,
      toolName: result.toolName,
      title: result.title,
      status: result.status,
      summary: result.summary,
      rows: result.rows,
      rawPreview: result.rawPreview
    });
  });
  return mapped;
}

export function gmailAuthRequiredA2ui(
  surfaceId: string,
  toolId: string,
  message: string,
  authorizeUrl: string = GMAIL_MCP_AUTH_SETUP_URL
): string {
  const connectData: A2uiDynamicToolConnectData = {
    toolId: toolId,
    prompt: '',
    manifestId: GMAIL_MANIFEST_ID,
    displayName: GMAIL_DISPLAY_NAME,
    sourceUrl: GMAIL_MCP_SERVER_URL,
    status: 'needs_auth',
    message: message,
    credentialName: 'Google Workspace MCP OAuth',
    credentialRef: 'gmail:mcp_oauth',
    registrationUrl: authorizeUrl.length > 0 ? authorizeUrl : GMAIL_MCP_AUTH_SETUP_URL,
    actions: [
      action('gmail.authorize', '授权 Gmail', authorizeUrl.length > 0 ? authorizeUrl : GMAIL_MCP_AUTH_SETUP_URL, 'primary', 'client'),
      action('gmail.open.web', '打开 Gmail Web', GMAIL_WEB_URL, 'secondary', 'client'),
      action('gmail_retry_auth', '重试认证', '重新检测 Gmail 登录状态', 'secondary', 'prompt')
    ]
  };
  const root: A2uiComponent = {
    id: 'root',
    component: A2UI_COMPONENT_SURFACE_ROOT,
    child: 'gmail_connect',
    title: GMAIL_DISPLAY_NAME,
    status: 'needs_auth'
  };
  const connect: A2uiComponent = {
    id: 'gmail_connect',
    component: A2UI_COMPONENT_TOOL_CONNECT_CARD,
    title: GMAIL_DISPLAY_NAME,
    dataPath: CONNECT_PATH,
    status: 'needs_auth'
  };

  return createSurfaceLine(surfaceId, GMAIL_DISPLAY_NAME, 'needs_input') +
    componentsLine(surfaceId, [root, connect]) +
    dataLine(surfaceId, CONNECT_PATH, connectData);
}

export function gmailThreadResultsA2ui(surfaceId: string, toolId: string, results: DynamicGenericToolResult[]): string {
  const mapped = genericResultsFromDynamic(results);
  const count = mapped.length;
  const resultLabel = count === 1 ? 'Gmail result' : 'Gmail results';
  const text = count.toString() + ' ' + resultLabel + ' returned for review.';
  return genericResultsA2ui(
    surfaceId,
    GMAIL_DISPLAY_NAME,
    'ready',
    'ready',
    mapped,
    summary(text, toolId, count)
  );
}

export function gmailDraftPreviewA2ui(surfaceId: string, result: DynamicGenericToolResult): string {
  const mapped = genericResultsFromDynamic([result]);
  return genericResultsA2ui(
    surfaceId,
    'Gmail Draft Preview',
    'ready',
    'draft',
    mapped,
    summary('Draft prepared for review. It has not been sent.', result.toolName, 1)
  );
}

export function gmailBlockedSendA2ui(surfaceId: string, toolId: string): string {
  const blockedSummary = 'UnsafeActionBlocked：不会自动发送 Gmail。请先查看草稿内容，确认收件人和正文后，创建或打开 Gmail 草稿由用户手动发送。';
  const result: A2uiGenericToolResultData = {
    sourceTag: 'Safety policy',
    toolName: toolId,
    title: 'UnsafeActionBlocked',
    status: 'blocked',
    summary: blockedSummary,
    rows: [
      { label: 'Blocked action', value: toolId },
      { label: 'Next step', value: '创建或打开 Gmail 草稿，用户确认后手动发送。' }
    ],
    rawPreview: JSON.stringify({
      blocked: true,
      reason: 'unsafe_action_blocked',
      toolId: toolId
    })
  };

  return genericResultsA2ui(
    surfaceId,
    'UnsafeActionBlocked',
    'blocked',
    'blocked',
    [result],
    summary(blockedSummary, toolId, 1)
  );
}

export function gmailOpenWebA2ui(surfaceId: string, url: string): string {
  const result: A2uiGenericToolResultData = {
    sourceTag: 'System intent',
    toolName: 'gmail.open.web',
    title: 'Gmail Web',
    status: 'needs_user',
    summary: 'Open Gmail Web to continue in the signed-in browser session.',
    rows: [
      { label: 'URL', value: url }
    ],
    rawPreview: JSON.stringify({
      url: url
    })
  };

  return genericResultsA2ui(
    surfaceId,
    'Gmail Web',
    'needs_input',
    'needs_user',
    [result],
    summary('Open Gmail Web to continue in the signed-in browser session.', 'gmail.open.web', 1)
  );
}
