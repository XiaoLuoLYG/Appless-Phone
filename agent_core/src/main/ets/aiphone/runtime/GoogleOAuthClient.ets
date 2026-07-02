export interface GoogleOAuthAuthorizeParams {
  authUrl: string;
  clientId: string;
  redirectUri: string;
  state: string;
  codeChallenge: string;
  scopes: string;
  resource: string;
}

export interface GoogleOAuthConfig {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  resource: string;
}

export interface GoogleOAuthRedirectResult {
  ok: boolean;
  code: string;
  state: string;
  error: string;
}

type QueryValueMap = Record<string, string>;

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
  const pairs = query.split('&');
  for (let index = 0; index < pairs.length; index++) {
    const pair = pairs[index];
    if (pair.length === 0) {
      continue;
    }
    const eq = pair.indexOf('=');
    const key = eq < 0 ? pair : pair.substring(0, eq);
    const value = eq < 0 ? '' : pair.substring(eq + 1);
    values[decodeURIComponent(key)] = decodeURIComponent(value.replace(/\+/g, ' '));
  }
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

export function buildGoogleOAuthAuthorizationUrl(params: GoogleOAuthAuthorizeParams): string {
  const parts: string[] = [];
  appendFormPair(parts, 'client_id', params.clientId.trim());
  appendFormPair(parts, 'redirect_uri', params.redirectUri.trim());
  appendFormPair(parts, 'response_type', 'code');
  appendFormPair(parts, 'scope', params.scopes.trim());
  appendFormPair(parts, 'access_type', 'offline');
  appendFormPair(parts, 'prompt', 'consent');
  appendFormPair(parts, 'include_granted_scopes', 'true');
  appendFormPair(parts, 'resource', params.resource.trim());
  appendFormPair(parts, 'state', params.state.trim());
  appendFormPair(parts, 'code_challenge', params.codeChallenge.trim());
  appendFormPair(parts, 'code_challenge_method', 'S256');
  return params.authUrl + '?' + parts.join('&');
}

export function parseGoogleOAuthRedirect(uri: string): GoogleOAuthRedirectResult {
  const values = parseQuery(queryStringFromUri(uri));
  const error = values.error === undefined ? '' : values.error;
  if (error.length > 0) {
    return { ok: false, code: '', state: values.state === undefined ? '' : values.state, error: error };
  }
  const code = values.code === undefined ? '' : values.code;
  if (code.length === 0) {
    return { ok: false, code: '', state: values.state === undefined ? '' : values.state, error: 'missing_code' };
  }
  return { ok: true, code: code, state: values.state === undefined ? '' : values.state, error: '' };
}

export function buildGoogleTokenExchangeBody(config: GoogleOAuthConfig, code: string, codeVerifier: string): string {
  const parts: string[] = [];
  appendFormPair(parts, 'client_id', config.clientId);
  appendFormPair(parts, 'client_secret', config.clientSecret);
  appendFormPair(parts, 'code', code);
  appendFormPair(parts, 'code_verifier', codeVerifier);
  appendFormPair(parts, 'redirect_uri', config.redirectUri);
  appendFormPair(parts, 'grant_type', 'authorization_code');
  appendFormPair(parts, 'resource', config.resource);
  return parts.join('&');
}

export function buildGoogleRefreshTokenBody(config: GoogleOAuthConfig, refreshToken: string): string {
  const parts: string[] = [];
  appendFormPair(parts, 'client_id', config.clientId);
  appendFormPair(parts, 'client_secret', config.clientSecret);
  appendFormPair(parts, 'refresh_token', refreshToken);
  appendFormPair(parts, 'grant_type', 'refresh_token');
  appendFormPair(parts, 'resource', config.resource);
  return parts.join('&');
}
