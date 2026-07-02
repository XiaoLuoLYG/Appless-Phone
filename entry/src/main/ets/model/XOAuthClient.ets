import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { CredentialStore } from './DynamicCredentialStore';
import { aiLogInfo } from './AiphoneLogger';
import { gmailPkceChallengeS256 } from './GmailOAuthClient';

export const X_OAUTH_ACCESS_TOKEN_REF: string = 'x:oauth_access';
export const X_OAUTH_REFRESH_TOKEN_REF: string = 'x:oauth_refresh';
export const X_OAUTH_TOKEN_SET_REF: string = 'x:oauth_tokens';
export const X_PENDING_OAUTH_REF: string = 'x:oauth_pending';
export const X_DEFAULT_REDIRECT_URI: string = 'aiphone://oauth/x';
export const X_OAUTH_SCOPES: string = 'dm.read tweet.read users.read offline.access';

const X_OAUTH_AUTH_URL: string = 'https://twitter.com/i/oauth2/authorize';
const X_OAUTH_TOKEN_URL: string = 'https://api.x.com/2/oauth2/token';
const TOKEN_EXPIRY_SKEW_MS: number = 60000;

export interface XOAuthConfig {
  clientId: string;
  redirectUri: string;
  scopes?: string;
}

export interface XOAuthPending {
  state: string;
  codeVerifier: string;
  createdAtMs: number;
}

export interface XOAuthTokenResponse {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  token_type?: string;
  scope?: string;
  error?: string;
  error_description?: string;
}

export interface XOAuthTokenSet {
  accessToken: string;
  refreshToken: string;
  expiresAtMs: number;
  tokenType: string;
  scope: string;
}

type QueryValueMap = Record<string, string>;

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

function numberOf(value: number | undefined, fallback: number): number {
  if (value === undefined || value <= 0) {
    return fallback;
  }
  return value;
}

function appendFormPair(parts: string[], key: string, value: string): void {
  if (value.length === 0) {
    return;
  }
  parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(value));
}

function parseQuery(query: string): QueryValueMap {
  const values: QueryValueMap = {};
  if (query.length === 0) {
    return values;
  }
  query.split('&').forEach((pair: string) => {
    const eq = pair.indexOf('=');
    const key = eq < 0 ? pair : pair.substring(0, eq);
    const value = eq < 0 ? '' : pair.substring(eq + 1);
    values[decodeURIComponent(key)] = decodeURIComponent(value.replace(/\+/g, ' '));
  });
  return values;
}

function queryStringFromUri(uri: string): string {
  const queryStart = uri.indexOf('?');
  if (queryStart < 0) {
    return '';
  }
  const hashStart = uri.indexOf('#', queryStart + 1);
  return hashStart < 0 ? uri.substring(queryStart + 1) : uri.substring(queryStart + 1, hashStart);
}

function responseText(result: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(result));
  }
  return textOf(result);
}

function tokenSummary(response: XOAuthTokenResponse): string {
  return 'accessChars=' + textOf(response.access_token).length.toString() +
    ' refreshChars=' + textOf(response.refresh_token).length.toString() +
    ' expiresIn=' + numberOf(response.expires_in, 0).toString() +
    ' scopeChars=' + textOf(response.scope).length.toString();
}

export function createXOAuthPending(nowMs: number = Date.now()): XOAuthPending {
  return {
    state: util.generateRandomUUID(true).replace(/-/g, ''),
    codeVerifier: util.generateRandomUUID(true).replace(/-/g, '') + util.generateRandomUUID(true).replace(/-/g, ''),
    createdAtMs: nowMs
  };
}

export function buildXOAuthAuthorizationUrl(config: XOAuthConfig, pending: XOAuthPending): string {
  const parts: string[] = [];
  appendFormPair(parts, 'response_type', 'code');
  appendFormPair(parts, 'client_id', config.clientId.trim());
  appendFormPair(parts, 'redirect_uri', config.redirectUri.trim());
  appendFormPair(parts, 'scope', (config.scopes === undefined || config.scopes.trim().length === 0) ? X_OAUTH_SCOPES : config.scopes.trim());
  appendFormPair(parts, 'state', pending.state);
  appendFormPair(parts, 'code_challenge', gmailPkceChallengeS256(pending.codeVerifier));
  appendFormPair(parts, 'code_challenge_method', 'S256');
  return X_OAUTH_AUTH_URL + '?' + parts.join('&');
}

function buildXTokenExchangeBody(config: XOAuthConfig, code: string, codeVerifier: string): string {
  const parts: string[] = [];
  appendFormPair(parts, 'client_id', config.clientId.trim());
  appendFormPair(parts, 'code', code);
  appendFormPair(parts, 'code_verifier', codeVerifier);
  appendFormPair(parts, 'redirect_uri', config.redirectUri.trim());
  appendFormPair(parts, 'grant_type', 'authorization_code');
  return parts.join('&');
}

function buildXRefreshTokenBody(config: XOAuthConfig, refreshToken: string): string {
  const parts: string[] = [];
  appendFormPair(parts, 'client_id', config.clientId.trim());
  appendFormPair(parts, 'refresh_token', refreshToken);
  appendFormPair(parts, 'grant_type', 'refresh_token');
  return parts.join('&');
}

async function postXTokenForm(body: string): Promise<XOAuthTokenResponse> {
  const request = http.createHttp();
  try {
    const response = await request.request(X_OAUTH_TOKEN_URL, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json'
      },
      extraData: body,
      connectTimeout: 10000,
      readTimeout: 30000
    });
    const text = responseText(response.result);
    const payload = JSON.parse(text) as XOAuthTokenResponse;
    aiLogInfo('[AIPhone][XOAuthTokenHttp] code=' + response.responseCode.toString() +
      ' responseChars=' + text.length.toString() +
      ' hasOAuthError=' + (textOf(payload.error).length > 0 ? 'true' : 'false'));
    if (response.responseCode < 200 || response.responseCode >= 300 || textOf(payload.error).length > 0) {
      const message = textOf(payload.error_description).length > 0 ? textOf(payload.error_description) : textOf(payload.error);
      throw new Error(message.length > 0 ? message : 'X OAuth token exchange failed');
    }
    aiLogInfo('[AIPhone][XOAuthTokenOk] ' + tokenSummary(payload));
    return payload;
  } finally {
    request.destroy();
  }
}

export async function exchangeXOAuthCode(config: XOAuthConfig, code: string, codeVerifier: string): Promise<XOAuthTokenResponse> {
  return postXTokenForm(buildXTokenExchangeBody(config, code, codeVerifier));
}

export async function refreshXOAuthAccessToken(config: XOAuthConfig, refreshToken: string): Promise<XOAuthTokenResponse> {
  return postXTokenForm(buildXRefreshTokenBody(config, refreshToken));
}

export async function saveXOAuthPending(store: CredentialStore, pending: XOAuthPending): Promise<void> {
  await store.put(X_PENDING_OAUTH_REF, JSON.stringify(pending));
}

export async function consumeXOAuthPending(store: CredentialStore): Promise<XOAuthPending | null> {
  const raw = await store.get(X_PENDING_OAUTH_REF);
  await store.remove(X_PENDING_OAUTH_REF);
  if (raw.length === 0) {
    return null;
  }
  try {
    return JSON.parse(raw) as XOAuthPending;
  } catch (_error) {
    return null;
  }
}

export async function loadXOAuthTokenSet(store: CredentialStore): Promise<XOAuthTokenSet | null> {
  const raw = await store.get(X_OAUTH_TOKEN_SET_REF);
  if (raw.length === 0) {
    return null;
  }
  try {
    return JSON.parse(raw) as XOAuthTokenSet;
  } catch (_error) {
    return null;
  }
}

export function isXAccessTokenFresh(token: XOAuthTokenSet, nowMs: number = Date.now()): boolean {
  return token.accessToken.length > 0 && nowMs + TOKEN_EXPIRY_SKEW_MS < token.expiresAtMs;
}

export async function saveXOAuthTokenSet(
  store: CredentialStore,
  response: XOAuthTokenResponse,
  nowMs: number = Date.now()
): Promise<XOAuthTokenSet> {
  const accessToken = textOf(response.access_token);
  if (accessToken.length === 0) {
    throw new Error('X OAuth response did not include an access token');
  }
  const existing = await loadXOAuthTokenSet(store);
  const refreshToken = textOf(response.refresh_token).length > 0 ? textOf(response.refresh_token) :
    (existing === null ? await store.get(X_OAUTH_REFRESH_TOKEN_REF) : existing.refreshToken);
  const token: XOAuthTokenSet = {
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAtMs: nowMs + numberOf(response.expires_in, 7200) * 1000 - TOKEN_EXPIRY_SKEW_MS,
    tokenType: textOf(response.token_type).length > 0 ? textOf(response.token_type) : 'Bearer',
    scope: textOf(response.scope).length > 0 ? textOf(response.scope) : (existing === null ? '' : existing.scope)
  };
  await store.put(X_OAUTH_TOKEN_SET_REF, JSON.stringify(token));
  await store.put(X_OAUTH_ACCESS_TOKEN_REF, token.accessToken);
  if (token.refreshToken.length > 0) {
    await store.put(X_OAUTH_REFRESH_TOKEN_REF, token.refreshToken);
  }
  aiLogInfo('[AIPhone][XOAuthTokenSaved] accessChars=' + token.accessToken.length.toString() +
    ' refreshChars=' + token.refreshToken.length.toString());
  return token;
}

export async function handleXOAuthRedirect(
  store: CredentialStore,
  config: XOAuthConfig,
  uri: string,
  nowMs: number = Date.now()
): Promise<XOAuthTokenSet> {
  const values = parseQuery(queryStringFromUri(uri));
  const error = values.error === undefined ? '' : values.error;
  if (error.length > 0) {
    throw new Error(error);
  }
  const code = values.code === undefined ? '' : values.code;
  if (code.length === 0) {
    throw new Error('missing_code');
  }
  const state = values.state === undefined ? '' : values.state;
  const pending = await consumeXOAuthPending(store);
  if (pending === null || pending.state !== state) {
    throw new Error('X OAuth state did not match');
  }
  const response = await exchangeXOAuthCode(config, code, pending.codeVerifier);
  return saveXOAuthTokenSet(store, response, nowMs);
}
