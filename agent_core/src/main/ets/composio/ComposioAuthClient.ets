import http from '@ohos.net.http';

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

type AnyRecord = Record<string, Object | string | number | boolean | null | undefined>;

function textOf(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  return typeof value === 'string' ? value : `${value}`;
}

function boolOf(value: Object | string | number | boolean | null | undefined): boolean {
  return value === true || textOf(value).toLowerCase() === 'true';
}

function itemOf(value: Object | string | number | boolean | null | undefined): ComposioAuthConfigItem {
  const record = (value ?? {}) as AnyRecord;
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

function trimTrailingSlash(value: string): string {
  let result = value.trim();
  while (result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
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
  const redirectUrl = textOf(record.redirectUrl).trim();
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

  constructor(baseUrl: string, apiKey: string = '') {
    this.baseUrl = trimTrailingSlash(baseUrl);
    this.apiKey = apiKey.trim();
  }

  private headers(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
    if (this.apiKey.length > 0) {
      headers['X-API-Key'] = this.apiKey;
    }
    return headers;
  }

  private async requestJson(method: http.RequestMethod, path: string, body: Object | null): Promise<Object> {
    const request = http.createHttp();
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
      return text.length > 0 ? JSON.parse(text) as Object : new Object();
    } finally {
      request.destroy();
    }
  }

  async listAuthConfigs(userId: string): Promise<ComposioAuthConfigsResult> {
    const payload = await this.requestJson(http.RequestMethod.GET, '/v1/composio/auth-configs?userId=' + encodeURIComponent(userId), null);
    return normalizeComposioAuthConfigsResponse(payload);
  }

  async createLink(userId: string, authConfigId: string, toolkitSlug: string): Promise<ComposioLinkResult> {
    const requestBody: ComposioLinkRequest = {
      userId: userId,
      authConfigId: authConfigId,
      toolkitSlug: toolkitSlug
    };
    const payload = await this.requestJson(http.RequestMethod.POST, '/v1/composio/link', requestBody);
    return normalizeComposioLinkResponse(payload);
  }
}
