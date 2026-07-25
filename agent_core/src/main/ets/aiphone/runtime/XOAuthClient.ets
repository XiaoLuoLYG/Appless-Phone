import util from '@ohos.util';
import { CredentialStore } from './DynamicCredentialStore';
import { gmailPkceChallengeS256 } from './GmailOAuthClient';

export const X_PENDING_OAUTH_REF: string = 'x:oauth_pending';
export const X_DEFAULT_REDIRECT_URI: string = 'aiphone://oauth/x';
export const X_OAUTH_SCOPES: string = 'dm.read tweet.read users.read offline.access';

const X_OAUTH_AUTH_URL: string = 'https://twitter.com/i/oauth2/authorize';

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

function appendFormPair(parts: string[], key: string, value: string): void {
  if (value.length > 0) {
    parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(value));
  }
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
  appendFormPair(parts, 'scope', config.scopes === undefined || config.scopes.trim().length === 0 ? X_OAUTH_SCOPES : config.scopes.trim());
  appendFormPair(parts, 'state', pending.state);
  appendFormPair(parts, 'code_challenge', gmailPkceChallengeS256(pending.codeVerifier));
  appendFormPair(parts, 'code_challenge_method', 'S256');
  return X_OAUTH_AUTH_URL + '?' + parts.join('&');
}

export async function saveXOAuthPending(store: CredentialStore, pending: XOAuthPending): Promise<void> {
  await store.put(X_PENDING_OAUTH_REF, JSON.stringify(pending));
}
