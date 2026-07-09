import http from '@ohos.net.http';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0x1200;
const LOG_TAG: string = 'LoopComposioAuth';
const CONNECT_TIMEOUT_MS: number = 10000;
const READ_TIMEOUT_MS: number = 20000;

export interface ComposioAuthConfigItem {
  authConfigId: string;
  toolkitSlug: string;
  toolkitName: string;
  logoUrl: string;
  authScheme: string;
  management: string;
  status: string;
  connectedAccountId: string;
  connectedAccountLabel: string;
  lastConnectedAt: string;
  canExecute: boolean;
}

export interface ComposioAuthConfigsResult {
  ok: boolean;
  userId: string;
  items: ComposioAuthConfigItem[];
  error: string;
}

export interface ComposioLinkResult {
  ok: boolean;
  redirectUrl: string;
  error: string;
}

interface ComposioLinkRequest {
  userId: string;
  authConfigId: string;
  toolkitSlug: string;
}

interface DirectComposioLinkRequest {
  auth_config_id: string;
  user_id: string;
  callback_url: string;
  alias: string;
}

interface ComposioHttpErrorPayload {
  ok: boolean;
  error: string;
}

type AnyRecord = Record<string, Object | string | number | boolean | null | undefined>;

function recordOf(value: Object | string | number | boolean | null | undefined): AnyRecord {
  return typeof value === 'object' && value !== null ? value as AnyRecord : new Object() as AnyRecord;
}

function textOf(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'object') {
    try {
      return JSON.stringify(value);
    } catch (_error) {
      return `${value}`;
    }
  }
  return `${value}`;
}

function boolOf(value: Object | string | number | boolean | null | undefined): boolean {
  return value === true || textOf(value).toLowerCase() === 'true';
}

function itemOf(value: Object | string | number | boolean | null | undefined): ComposioAuthConfigItem {
  const record = recordOf(value);
  return {
    authConfigId: textOf(record.authConfigId).trim(),
    toolkitSlug: textOf(record.toolkitSlug).trim().toLowerCase(),
    toolkitName: textOf(record.toolkitName).trim(),
    logoUrl: textOf(record.logoUrl).trim(),
    authScheme: textOf(record.authScheme).trim(),
    management: textOf(record.management).trim(),
    status: textOf(record.status).trim(),
    connectedAccountId: textOf(record.connectedAccountId).trim(),
    connectedAccountLabel: textOf(record.connectedAccountLabel).trim(),
    lastConnectedAt: textOf(record.lastConnectedAt).trim(),
    canExecute: boolOf(record.canExecute)
  };
}

function directToolkitSlug(value: Object | string | number | boolean | null | undefined): string {
  if (typeof value === 'string') {
    return value.trim().toLowerCase();
  }
  const record = recordOf(value);
  return textOf(record.slug).trim().toLowerCase();
}

function directConnectedByToolkit(payload: Object): Map<string, AnyRecord> {
  const record = payload as AnyRecord;
  const items: Object[] = Array.isArray(record.items) ? record.items as Object[] : [];
  const result: Map<string, AnyRecord> = new Map();
  for (let index = 0; index < items.length; index++) {
    const item = recordOf(items[index]);
    const slug = directToolkitSlug(item.toolkit ?? item.toolkit_slug);
    if (slug.length > 0 && !result.has(slug)) {
      result.set(slug, item);
    }
  }
  return result;
}

function directAuthItemOf(value: Object, connectedByToolkit: Map<string, AnyRecord>): ComposioAuthConfigItem {
  const record = recordOf(value);
  const toolkit = recordOf(record.toolkit);
  const slug = directToolkitSlug(record.toolkit ?? record.toolkit_slug);
  const maybeConnected = connectedByToolkit.get(slug);
  const connected = maybeConnected === undefined ? new Object() as AnyRecord : maybeConnected;
  const connectedId = textOf(connected.id).trim();
  return {
    authConfigId: textOf(record.id ?? record.auth_config_id).trim(),
    toolkitSlug: slug,
    toolkitName: textOf(toolkit.name ?? record.name ?? slug).trim(),
    logoUrl: textOf(toolkit.logo ?? toolkit.logo_url ?? record.logo_url).trim(),
    authScheme: textOf(record.auth_scheme ?? record.scheme).trim(),
    management: textOf(record.management ?? record.type).trim(),
    status: connectedId.length > 0 ? 'connected' : 'needs_auth',
    connectedAccountId: connectedId,
    connectedAccountLabel: textOf(connected.account_id ?? connected.email ?? connected.name).trim(),
    lastConnectedAt: textOf(connected.updated_at ?? connected.created_at).trim(),
    canExecute: connectedId.length > 0
  };
}

function directError(payload: Object): string {
  const record = payload as AnyRecord;
  if (record.ok === false) {
    const error = textOf(record.error).trim();
    return error.length > 0 ? error : 'Composio request failed.';
  }
  if (!Array.isArray(record.items)) {
    const error = textOf(record.error).trim();
    const message = textOf(record.message).trim();
    return error.length > 0 ? error : (message.length > 0 ? message : 'Composio response missing items.');
  }
  return '';
}

export function normalizeDirectComposioAuthConfigsResponse(userId: string, authConfigs: Object, accounts: Object): ComposioAuthConfigsResult {
  const error = directError(authConfigs).length > 0 ? directError(authConfigs) : directError(accounts);
  if (error.length > 0) {
    return { ok: false, userId: userId, items: [], error: error };
  }
  const record = authConfigs as AnyRecord;
  const itemsRaw: Object[] = Array.isArray(record.items) ? record.items as Object[] : [];
  const connectedByToolkit = directConnectedByToolkit(accounts);
  const items: ComposioAuthConfigItem[] = [];
  for (let index = 0; index < itemsRaw.length; index++) {
    const item = directAuthItemOf(itemsRaw[index], connectedByToolkit);
    if (item.authConfigId.length > 0 && item.toolkitSlug.length > 0) {
      items.push(item);
    }
  }
  return { ok: true, userId: userId, items: items, error: '' };
}

function trimTrailingSlash(value: string): string {
  let result = value.trim();
  while (result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

export function normalizeComposioHttpResponse(statusCode: number, text: string): Object {
  const trimmed = text.trim();
  let payload: Object = new Object();
  if (trimmed.length > 0) {
    try {
      payload = JSON.parse(trimmed) as Object;
    } catch (_error) {
      const invalidJsonPayload: ComposioHttpErrorPayload = {
        ok: false,
        error: trimmed
      };
      payload = invalidJsonPayload as Object;
    }
  }
  if (statusCode >= 200 && statusCode < 300) {
    return payload;
  }
  const record = payload as AnyRecord;
  const error = textOf(record.error).trim();
  const message = textOf(record.message).trim();
  const errorPayload: ComposioHttpErrorPayload = {
    ok: false,
    error: error.length > 0 ? error : (message.length > 0 ? message : ('HTTP ' + statusCode.toString()))
  };
  return errorPayload as Object;
}

export function normalizeComposioAuthConfigsResponse(payload: Object): ComposioAuthConfigsResult {
  const record = payload as AnyRecord;
  const itemsRaw: Object[] = Array.isArray(record.items) ? record.items as Object[] : [];
  const items: ComposioAuthConfigItem[] = [];
  for (let index = 0; index < itemsRaw.length; index++) {
    const item = itemOf(itemsRaw[index] as Object);
    if (item.authConfigId.length > 0 && item.toolkitSlug.length > 0) {
      items.push(item);
    }
  }
  return {
    ok: record.ok !== false,
    userId: textOf(record.userId).trim(),
    items: items,
    error: textOf(record.error).trim()
  };
}

export function normalizeComposioLinkResponse(payload: Object): ComposioLinkResult {
  const record = payload as AnyRecord;
  const redirectUrl = textOf(record.redirectUrl ?? record.redirect_url ?? record.link ?? record.url).trim();
  if (record.ok === false || !redirectUrl.startsWith('https://')) {
    const error = textOf(record.error).trim();
    return {
      ok: false,
      redirectUrl: '',
      error: error.length > 0 ? error : 'Composio link response missing redirectUrl.'
    };
  }
  return {
    ok: true,
    redirectUrl: redirectUrl,
    error: ''
  };
}

export class ComposioAuthProxyClient {
  readonly baseUrl: string;
  readonly apiKey: string;
  readonly directApi: boolean;

  constructor(baseUrl: string, apiKey: string = '', directApi: boolean = false) {
    this.baseUrl = trimTrailingSlash(baseUrl);
    this.apiKey = apiKey.trim();
    this.directApi = directApi;
  }

  private headers(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
    if (this.apiKey.length > 0 && this.directApi) {
      headers['x-api-key'] = this.apiKey;
    } else if (this.apiKey.length > 0) {
      headers['X-API-Key'] = this.apiKey;
    }
    return headers;
  }

  private async requestJson(method: http.RequestMethod, path: string, body: Object | null): Promise<Object> {
    const request = http.createHttp();
    hilog.info(LOG_DOMAIN, LOG_TAG, 'request method=%{public}s direct=%{public}s path=%{public}s', `${method}`, this.directApi ? 'true' : 'false', path);
    try {
      const options: http.HttpRequestOptions = {
        method: method,
        header: this.headers(),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS
      };
      if (body !== null) {
        options.extraData = JSON.stringify(body);
      } else {
        options.extraData = '';
      }
      const response = await request.request(this.baseUrl + path, options);
      const text = typeof response.result === 'string' ? response.result : `${response.result ?? ''}`;
      hilog.info(LOG_DOMAIN, LOG_TAG, 'response status=%{public}d path=%{public}s', response.responseCode, path);
      return normalizeComposioHttpResponse(response.responseCode, text);
    } finally {
      request.destroy();
    }
  }

  async listAuthConfigs(userId: string): Promise<ComposioAuthConfigsResult> {
    if (this.directApi) {
      if (this.apiKey.length === 0) {
        return { ok: false, userId: userId, items: [], error: 'Composio apiKey is missing from device config.' };
      }
      const accounts = await this.requestJson(http.RequestMethod.GET, '/connected_accounts?user_ids=' + encodeURIComponent(userId) + '&statuses=ACTIVE&limit=100', null);
      const authConfigs = await this.requestJson(http.RequestMethod.GET, '/auth_configs?limit=100', null);
      return normalizeDirectComposioAuthConfigsResponse(userId, authConfigs, accounts);
    }
    const payload = await this.requestJson(http.RequestMethod.GET, '/v1/composio/auth-configs?userId=' + encodeURIComponent(userId), null);
    return normalizeComposioAuthConfigsResponse(payload);
  }

  async createLink(userId: string, authConfigId: string, toolkitSlug: string): Promise<ComposioLinkResult> {
    if (this.directApi) {
      const requestBody: DirectComposioLinkRequest = {
        auth_config_id: authConfigId,
        user_id: userId,
        callback_url: 'aiphone://composio/callback',
        alias: toolkitSlug.trim().length > 0 ? toolkitSlug.trim().toLowerCase() + ':' + userId : userId
      };
      const payload = await this.requestJson(http.RequestMethod.POST, '/connected_accounts/link', requestBody);
      return normalizeComposioLinkResponse(payload);
    }
    const requestBody: ComposioLinkRequest = {
      userId: userId,
      authConfigId: authConfigId,
      toolkitSlug: toolkitSlug
    };
    const payload = await this.requestJson(http.RequestMethod.POST, '/v1/composio/link', requestBody);
    return normalizeComposioLinkResponse(payload);
  }
}
