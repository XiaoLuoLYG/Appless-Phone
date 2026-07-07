# Composio User Auth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-app Composio authorization page where each AIPhoneDemo user authorizes their own Composio-connected accounts, without replacing existing local Gmail, Slack, Calendar, Maps, Stripe, or YouTube tools.

**Architecture:** Extend the existing `tool-gateway/server.mjs` as the Composio proxy so the HAP never ships a Composio API key. Add small agent-core client/parsing utilities, then wire the existing A2UI settings surface to a dedicated `ComposioAuthPage`. Keep current static tool routing unchanged; only Composio dynamic search/execute uses the new per-user auth flow.

**Tech Stack:** HarmonyOS ArkTS, Hypium tests, existing Node `tool-gateway`, Composio v3.1 REST API, existing A2UI theme/components.

## Global Constraints

- Do not replace existing Gmail, SocialHub Slack, X, Google Calendar, Google Maps, Stripe, or YouTube data sources.
- Do not change existing static `toolId` routing or UI.
- Do not put the Composio API key in the HAP.
- Support all enabled Composio Auth Configs returned by the backend, not a fixed app list.
- Each App user has a stable `composioUserId`.
- Composio create/send/update tools may auto-execute only after the current session search returns the exact tool slug.
- Failed provider calls must show the real Composio or proxy error.

---

## File Structure

- `tool-gateway/server.mjs`: add Composio proxy endpoints and environment handling.
- `tool-gateway/smoke-test.mjs`: add host-level auth proxy smoke cases.
- `agent_core/src/main/ets/composio/ComposioAuthClient.ets`: parse proxy responses and call auth proxy endpoints.
- `agent_core/src/main/ets/composio/ComposioUserId.ets`: normalize, generate, and shorten app-scoped Composio user IDs.
- `agent_core/src/main/ets/composio/ComposioSessionClient.ets`: optionally execute through proxy session/search/execute when a proxy base URL is configured.
- `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`: export the configured gateway API key for Composio proxy calls.
- `agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets`: use current app user ID and stop blocking Composio side-effect tools before execute.
- `agent_core/Index.ets`: export new Composio auth utilities.
- `entry/src/main/ets/pages/A2uiHome/components/ComposioAuthPage.ets`: dedicated authorization page.
- `entry/src/main/ets/pages/A2uiHome/components/ComposioAuthViewData.ets`: tiny view helpers for labels and sorting.
- `entry/src/main/ets/pages/A2uiHome/components/ConfigPage.ets`: add settings entry button.
- `entry/src/main/ets/pages/A2uiHome/Index.ets`: own page state, user ID preferences, refresh/link actions, and route back.
- `entry/src/main/module.json5`: register `aiphone://composio/callback` as a browsable callback URI.
- `entry/src/main/ets/entryability/EntryAbility.ets`: recognize Composio callback wants and log them without Gmail/X OAuth handling.
- `entry/src/test/ComposioAuthClient.test.ets`: unit tests for parsing and user ID helpers.
- `entry/src/test/ComposioDynamicBackend.test.ets`: update side-effect execute expectation.
- `entry/src/test/ComposioAuthViewData.test.ets`: unit tests for authorization page labels and ordering.
- `entry/src/test/List.test.ets`: include new test modules.
- `scripts/aiphone-device-smoke.mjs`: add optional Composio auth-page smoke markers.

---

### Task 1: Composio Proxy Endpoints

**Files:**
- Modify: `tool-gateway/server.mjs`
- Modify: `tool-gateway/smoke-test.mjs`

**Interfaces:**
- Consumes: environment variables `COMPOSIO_API_KEY`, `COMPOSIO_BASE_URL`, optional `COMPOSIO_AUTH_MOCK=1`
- Produces: `GET /v1/composio/auth-configs`, `POST /v1/composio/link`, `POST /v1/composio/session`, `POST /v1/composio/session/:sessionId/search`, `POST /v1/composio/session/:sessionId/execute`, `DELETE /v1/composio/session/:sessionId`

- [ ] **Step 1: Write failing smoke coverage**

Add this case block to `tool-gateway/smoke-test.mjs` after the social bridge constants:

```js
const COMPOSIO_AUTH_CASES = [
  {
    name: 'composio_auth_configs',
    path: '/v1/composio/auth-configs?userId=app-user-smoke',
    method: 'GET',
    expect: ['"ok":true', '"toolkitSlug":"github"', '"authConfigId":"ac_mock_github"']
  },
  {
    name: 'composio_link',
    path: '/v1/composio/link',
    method: 'POST',
    body: {
      userId: 'app-user-smoke',
      authConfigId: 'ac_mock_github',
      toolkitSlug: 'github'
    },
    expect: ['"ok":true', '"redirectUrl":"https://mock.composio.local/connect/github"']
  },
  {
    name: 'composio_proxy_session',
    path: '/v1/composio/session',
    method: 'POST',
    body: {
      user_id: 'app-user-smoke',
      toolkits: { enable: ['github'] },
      connected_accounts: { github: ['ca_mock_github'] },
      manage_connections: { enable: false },
      workbench: { enable: false },
      multi_account: { enable: false },
      search: { enable: true },
      execute: { enable_multi_execute: false }
    },
    expect: ['"session_id":"mock-session"']
  },
  {
    name: 'composio_proxy_search',
    path: '/v1/composio/session/mock-session/search',
    method: 'POST',
    body: { queries: [{ use_case: 'find recent Appless-Phone pull requests' }] },
    expect: ['"success":true', '"GITHUB_FIND_PULL_REQUESTS"']
  },
  {
    name: 'composio_proxy_execute',
    path: '/v1/composio/session/mock-session/execute',
    method: 'POST',
    body: { tool_slug: 'GITHUB_FIND_PULL_REQUESTS', arguments: {} },
    expect: ['"ok":true', '"mock Composio execute"']
  }
];
```

Add this runner near `runSocialBridgeCases()`:

```js
async function runComposioAuthCases() {
  const baseHeaders = {
    ...(gatewayApiKey.length > 0 ? { 'X-API-Key': gatewayApiKey } : {}),
    'Content-Type': 'application/json'
  };
  for (const testCase of COMPOSIO_AUTH_CASES) {
    const response = await fetch(`${gatewayUrl}${testCase.path}`, {
      method: testCase.method,
      headers: baseHeaders,
      body: testCase.body ? JSON.stringify(testCase.body) : undefined,
      signal: AbortSignal.timeout(5000)
    });
    const text = await response.text();
    if (!response.ok) {
      throw new Error(`${testCase.name} failed: HTTP ${response.status} ${text}`);
    }
    testCase.expect.forEach(marker => {
      if (!text.includes(marker)) {
        throw new Error(`${testCase.name} missing marker: ${marker}`);
      }
    });
    console.log(`PASS host/${testCase.name}`);
  }
}
```

Call it when `process.argv` contains `--composio-auth`:

```js
if (args.has('--composio-auth')) {
  process.env.COMPOSIO_AUTH_MOCK = process.env.COMPOSIO_AUTH_MOCK || '1';
  await runComposioAuthCases();
}
```

- [ ] **Step 2: Run smoke to verify it fails**

Run:

```bash
COMPOSIO_AUTH_MOCK=1 node tool-gateway/smoke-test.mjs --composio-auth
```

Expected: FAIL with `Not found` or missing Composio auth markers.

- [ ] **Step 3: Add proxy helper functions**

Add this code in `tool-gateway/server.mjs` after `describeError()`:

```js
function composioBaseUrl() {
  return textOf(process.env.COMPOSIO_BASE_URL || 'https://backend.composio.dev/api/v3.1').replace(/\/+$/, '');
}

function composioApiKey() {
  return textOf(process.env.COMPOSIO_API_KEY).trim();
}

function composioMockEnabled() {
  return textOf(process.env.COMPOSIO_AUTH_MOCK).trim() === '1';
}

function composioHeaders() {
  const apiKey = composioApiKey();
  if (apiKey.length === 0) {
    throw new Error('Configure COMPOSIO_API_KEY in tool-gateway/.env.local.');
  }
  return {
    'x-api-key': apiKey,
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  };
}

function normalizeComposioAuthItem(item, connectedByToolkit) {
  const toolkit = item.toolkit || {};
  const toolkitSlug = textOf(toolkit.slug || item.toolkit_slug || item.toolkit).trim().toLowerCase();
  const connected = connectedByToolkit.get(toolkitSlug) || {};
  return {
    authConfigId: textOf(item.id || item.auth_config_id).trim(),
    toolkitSlug,
    toolkitName: textOf(toolkit.name || item.name || toolkitSlug).trim(),
    logoUrl: textOf(toolkit.logo || toolkit.logo_url || item.logo_url).trim(),
    authScheme: textOf(item.auth_scheme || item.scheme).trim(),
    management: textOf(item.management || item.type).trim(),
    status: textOf(connected.id).length > 0 ? 'connected' : 'needs_auth',
    connectedAccountId: textOf(connected.id).trim(),
    connectedAccountLabel: textOf(connected.account_id || connected.email || connected.name).trim(),
    lastConnectedAt: textOf(connected.updated_at || connected.created_at).trim(),
    canExecute: textOf(connected.id).length > 0
  };
}

function mockComposioAuthConfigs(userId) {
  return {
    ok: true,
    userId,
    items: [
      {
        authConfigId: 'ac_mock_github',
        toolkitSlug: 'github',
        toolkitName: 'GitHub',
        logoUrl: '',
        authScheme: 'OAuth2',
        management: 'managed',
        status: 'needs_auth',
        connectedAccountId: '',
        connectedAccountLabel: '',
        lastConnectedAt: '',
        canExecute: false
      }
    ]
  };
}

function mockComposioSessionResponse(pathname) {
  if (pathname === '/tool_router/session') {
    return { session_id: 'mock-session' };
  }
  if (pathname.endsWith('/search')) {
    return {
      success: true,
      results: [{ primary_tool_slugs: ['GITHUB_FIND_PULL_REQUESTS'], related_tool_slugs: [] }],
      tool_schemas: {
        GITHUB_FIND_PULL_REQUESTS: {
          tool_slug: 'GITHUB_FIND_PULL_REQUESTS',
          description: 'Find GitHub pull requests',
          input_schema: { type: 'object', properties: {} }
        }
      }
    };
  }
  if (pathname.endsWith('/execute')) {
    return { ok: true, message: 'mock Composio execute' };
  }
  return { ok: true };
}
```

- [ ] **Step 4: Add proxy handlers**

Add these handlers before `handleAiphoneTool()`:

```js
async function composioFetch(pathname, options = {}) {
  const response = await fetch(`${composioBaseUrl()}${pathname}`, {
    ...options,
    headers: {
      ...composioHeaders(),
      ...(options.headers || {})
    },
    signal: AbortSignal.timeout(20000)
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Composio HTTP ${response.status}: ${text.slice(0, 500)}`);
  }
  return text.length > 0 ? JSON.parse(text) : {};
}

async function handleComposioAuthConfigs(req, res, url) {
  if (!isGatewayAuthorized(req)) {
    rejectUnauthorized(res);
    return;
  }
  const userId = textOf(url.searchParams.get('userId')).trim();
  if (userId.length === 0) {
    sendJson(res, 400, { ok: false, error: 'userId is required.' });
    return;
  }
  if (composioMockEnabled()) {
    sendJson(res, 200, mockComposioAuthConfigs(userId));
    return;
  }
  const accounts = await composioFetch(`/connected_accounts?user_ids=${encodeURIComponent(userId)}&statuses=ACTIVE&limit=100`);
  const connectedByToolkit = new Map();
  for (const account of accounts.items || []) {
    const slug = textOf(account.toolkit?.slug || account.toolkit_slug).trim().toLowerCase();
    if (slug.length > 0 && !connectedByToolkit.has(slug)) {
      connectedByToolkit.set(slug, account);
    }
  }
  const authConfigs = await composioFetch('/auth_configs?limit=100');
  const items = (authConfigs.items || [])
    .filter(item => textOf(item.status || 'enabled').toLowerCase() !== 'disabled')
    .map(item => normalizeComposioAuthItem(item, connectedByToolkit))
    .filter(item => item.authConfigId.length > 0 && item.toolkitSlug.length > 0);
  sendJson(res, 200, { ok: true, userId, items });
}

async function handleComposioLink(req, res) {
  if (!isGatewayAuthorized(req)) {
    rejectUnauthorized(res);
    return;
  }
  const body = await readJson(req);
  const userId = textOf(body.userId).trim();
  const authConfigId = textOf(body.authConfigId).trim();
  const toolkitSlug = textOf(body.toolkitSlug).trim().toLowerCase();
  if (userId.length === 0 || authConfigId.length === 0) {
    sendJson(res, 400, { ok: false, error: 'userId and authConfigId are required.' });
    return;
  }
  if (composioMockEnabled()) {
    sendJson(res, 200, { ok: true, redirectUrl: `https://mock.composio.local/connect/${toolkitSlug || 'toolkit'}` });
    return;
  }
  const payload = await composioFetch('/connected_accounts/link', {
    method: 'POST',
    body: JSON.stringify({
      auth_config_id: authConfigId,
      user_id: userId,
      callback_url: textOf(process.env.COMPOSIO_CALLBACK_URL || 'aiphone://composio/callback'),
      alias: toolkitSlug.length > 0 ? `${toolkitSlug}:${userId}` : userId
    })
  });
  const redirectUrl = textOf(payload.redirect_url || payload.link || payload.url).trim();
  if (!redirectUrl.startsWith('https://')) {
    sendJson(res, 502, { ok: false, error: 'Composio did not return an HTTPS redirect URL.' });
    return;
  }
  sendJson(res, 200, { ok: true, redirectUrl });
}

async function handleComposioProxyJson(req, res, composioPath, successStatus = 200) {
  if (!isGatewayAuthorized(req)) {
    rejectUnauthorized(res);
    return;
  }
  const body = req.method === 'DELETE' ? null : await readJson(req);
  if (composioMockEnabled()) {
    sendJson(res, successStatus, mockComposioSessionResponse(composioPath));
    return;
  }
  const payload = await composioFetch(composioPath, {
    method: req.method,
    body: body === null ? undefined : JSON.stringify(body)
  });
  sendJson(res, successStatus, payload);
}
```

- [ ] **Step 5: Add routes**

Add these route branches before `/mcp/call`:

```js
if (req.method === 'GET' && url.pathname === '/v1/composio/auth-configs') {
  await handleComposioAuthConfigs(req, res, url);
  return;
}
if (req.method === 'POST' && url.pathname === '/v1/composio/link') {
  await handleComposioLink(req, res);
  return;
}
if (req.method === 'POST' && url.pathname === '/v1/composio/session') {
  await handleComposioProxyJson(req, res, '/tool_router/session', 200);
  return;
}
const composioSessionRoute = url.pathname.match(/^\/v1\/composio\/session\/([^/]+)(\/search|\/execute)?$/);
if (composioSessionRoute !== null) {
  const sessionId = decodeURIComponent(composioSessionRoute[1]);
  const suffix = composioSessionRoute[2] ?? '';
  if (req.method === 'DELETE' && suffix.length === 0) {
    await handleComposioProxyJson(req, res, `/tool_router/session/${encodeURIComponent(sessionId)}`, 200);
    return;
  }
  if (req.method === 'POST' && (suffix === '/search' || suffix === '/execute')) {
    await handleComposioProxyJson(req, res, `/tool_router/session/${encodeURIComponent(sessionId)}${suffix}`, 200);
    return;
  }
}
```

- [ ] **Step 6: Run smoke to verify it passes**

Run:

```bash
COMPOSIO_AUTH_MOCK=1 node tool-gateway/smoke-test.mjs --composio-auth
```

Expected: PASS lines for `host/composio_auth_configs`, `host/composio_link`, `host/composio_proxy_session`, `host/composio_proxy_search`, and `host/composio_proxy_execute`.

- [ ] **Step 7: Commit**

```bash
git add tool-gateway/server.mjs tool-gateway/smoke-test.mjs
git commit -m "Add Composio auth proxy endpoints"
```

---

### Task 2: Agent-Core Composio Auth Client

**Files:**
- Create: `agent_core/src/main/ets/composio/ComposioAuthClient.ets`
- Create: `agent_core/src/main/ets/composio/ComposioUserId.ets`
- Modify: `agent_core/Index.ets`
- Create: `entry/src/test/ComposioAuthClient.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Interfaces:**
- Consumes: Task 1 proxy JSON
- Produces: `ComposioAuthConfigItem`, `ComposioAuthProxyClient`, `normalizeComposioUserId(value)`, `shortComposioUserId(value)`

- [ ] **Step 1: Write failing tests**

Create `entry/src/test/ComposioAuthClient.test.ets`:

```ts
import { describe, it, expect } from '@ohos/hypium';
import {
  normalizeComposioAuthConfigsResponse,
  normalizeComposioLinkResponse,
  normalizeComposioUserId,
  shortComposioUserId
} from '@loop/agent-core';

export default function composioAuthClientTest() {
  describe('composioAuthClient', () => {
    it('normalizes auth configs without a fixed toolkit list', 0, () => {
      const payload = JSON.parse('{"ok":true,"userId":"app-user-1","items":[{"authConfigId":"ac_1","toolkitSlug":"github","toolkitName":"GitHub","status":"connected","connectedAccountId":"ca_1"},{"authConfigId":"ac_2","toolkitSlug":"ticketmaster","toolkitName":"Ticketmaster","status":"needs_auth"}]}') as Object;
      const result = normalizeComposioAuthConfigsResponse(payload);

      expect(result.ok).assertTrue();
      expect(result.userId).assertEqual('app-user-1');
      expect(result.items.length).assertEqual(2);
      expect(result.items[1].toolkitSlug).assertEqual('ticketmaster');
      expect(result.items[1].status).assertEqual('needs_auth');
    });

    it('keeps valid redirect URLs and rejects missing links', 0, () => {
      const ok = normalizeComposioLinkResponse(JSON.parse('{"ok":true,"redirectUrl":"https://mock.composio.local/connect/github"}') as Object);
      const bad = normalizeComposioLinkResponse(JSON.parse('{"ok":true}') as Object);

      expect(ok.redirectUrl).assertEqual('https://mock.composio.local/connect/github');
      expect(bad.ok).assertFalse();
      expect(bad.error.indexOf('redirectUrl')).assertLarger(-1);
    });

    it('normalizes and shortens app user ids', 0, () => {
      expect(normalizeComposioUserId(' User 1 / Device ')).assertEqual('user-1-device');
      expect(shortComposioUserId('aiphone-user-abcdef123456')).assertEqual('abcdef123456');
    });
  });
}
```

Modify `entry/src/test/List.test.ets`:

```ts
import composioAuthClientTest from './ComposioAuthClient.test';
```

and call:

```ts
  composioAuthClientTest();
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk node /Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js test --no-daemon
```

Expected: FAIL with missing exports from `@loop/agent-core`.

- [ ] **Step 3: Add user ID helpers**

Create `agent_core/src/main/ets/composio/ComposioUserId.ets`:

```ts
export const COMPOSIO_USER_ID_PREFIX: string = 'aiphone-user-';

export function normalizeComposioUserId(value: string): string {
  const lower = value.trim().toLowerCase();
  let result = '';
  for (let index = 0; index < lower.length; index++) {
    const ch = lower.charAt(index);
    const ok = (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9');
    if (ok) {
      result += ch;
    } else if (result.length > 0 && !result.endsWith('-')) {
      result += '-';
    }
  }
  while (result.endsWith('-')) {
    result = result.substring(0, result.length - 1);
  }
  return result.length > 0 ? result : COMPOSIO_USER_ID_PREFIX + 'local';
}

export function shortComposioUserId(value: string): string {
  const normalized = normalizeComposioUserId(value);
  return normalized.startsWith(COMPOSIO_USER_ID_PREFIX)
    ? normalized.substring(COMPOSIO_USER_ID_PREFIX.length)
    : normalized.substring(Math.max(0, normalized.length - 12));
}
```

- [ ] **Step 4: Add auth response parsing and proxy client**

Create `agent_core/src/main/ets/composio/ComposioAuthClient.ets`:

```ts
import http from '@ohos.net.http';

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

export function normalizeComposioAuthConfigsResponse(payload: Object): ComposioAuthConfigsResult {
  const record = payload as AnyRecord;
  const itemsRaw = Array.isArray(record.items) ? record.items : [];
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
    items,
    error: textOf(record.error).trim()
  };
}

export function normalizeComposioLinkResponse(payload: Object): ComposioLinkResult {
  const record = payload as AnyRecord;
  const redirectUrl = textOf(record.redirectUrl).trim();
  if (record.ok === false || !redirectUrl.startsWith('https://')) {
    return {
      ok: false,
      redirectUrl: '',
      error: textOf(record.error).trim().length > 0 ? textOf(record.error).trim() : 'Composio link response missing redirectUrl.'
    };
  }
  return { ok: true, redirectUrl, error: '' };
}

export class ComposioAuthProxyClient {
  readonly baseUrl: string;
  readonly apiKey: string;

  constructor(baseUrl: string, apiKey: string = '') {
    this.baseUrl = baseUrl.trim().replace(/\/+$/, '');
    this.apiKey = apiKey.trim();
  }

  private headers(): Record<string, string> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (this.apiKey.length > 0) {
      headers['X-API-Key'] = this.apiKey;
    }
    return headers;
  }

  private async requestJson(method: http.RequestMethod, path: string, body: Object | null): Promise<Object> {
    const response = await http.createHttp().request(this.baseUrl + path, {
      method,
      header: this.headers(),
      extraData: body === null ? '' : JSON.stringify(body),
      readTimeout: 20000,
      connectTimeout: 10000
    });
    const text = typeof response.result === 'string' ? response.result : `${response.result}`;
    return JSON.parse(text.length > 0 ? text : '{}') as Object;
  }

  async listAuthConfigs(userId: string): Promise<ComposioAuthConfigsResult> {
    const payload = await this.requestJson(http.RequestMethod.GET, '/v1/composio/auth-configs?userId=' + encodeURIComponent(userId), null);
    return normalizeComposioAuthConfigsResponse(payload);
  }

  async createLink(userId: string, authConfigId: string, toolkitSlug: string): Promise<ComposioLinkResult> {
    const payload = await this.requestJson(http.RequestMethod.POST, '/v1/composio/link', { userId, authConfigId, toolkitSlug });
    return normalizeComposioLinkResponse(payload);
  }
}
```

- [ ] **Step 5: Export utilities**

Modify `agent_core/Index.ets`:

```ts
export * from './src/main/ets/composio/ComposioAuthClient';
export * from './src/main/ets/composio/ComposioUserId';
```

- [ ] **Step 6: Run tests**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk node /Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js test --no-daemon
```

Expected: BUILD SUCCESSFUL.

- [ ] **Step 7: Commit**

```bash
git add agent_core/src/main/ets/composio/ComposioAuthClient.ets agent_core/src/main/ets/composio/ComposioUserId.ets agent_core/Index.ets entry/src/test/ComposioAuthClient.test.ets entry/src/test/List.test.ets
git commit -m "Add Composio auth client utilities"
```

---

### Task 3: Dynamic Runtime Uses Current Composio User

**Files:**
- Modify: `agent_core/src/main/ets/composio/ComposioConfig.ets`
- Modify: `agent_core/src/main/ets/composio/ComposioSessionClient.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets`
- Modify: `entry/src/test/ComposioConfig.test.ets`
- Modify: `entry/src/test/ComposioDynamicBackend.test.ets`

**Interfaces:**
- Consumes: `composioUserId`, proxy base URL, optional gateway API key
- Produces: `configureComposioUserId(userId: string)`, side-effect Composio execute no longer pre-blocked

- [ ] **Step 1: Write failing tests**

Update `entry/src/test/ComposioConfig.test.ets` first test:

```ts
const config: ComposioConfig = ComposioConfig.fromRawJson('{"apiKey":" key ","baseUrl":"https://example.test/api/","userId":" user ","proxyBaseUrl":"http://127.0.0.1:8787"}');

expect(config.proxyBaseUrl).assertEqual('http://127.0.0.1:8787');
```

Add a proxy-only config assertion:

```ts
const proxyOnly = ComposioConfig.fromRawJson('{"userId":"user-1","proxyBaseUrl":"http://127.0.0.1:8787"}');

expect(proxyOnly.isConfigured()).assertTrue();
expect(proxyOnly.missingConfiguration()).assertEqual('');
```

Update `entry/src/test/ComposioDynamicBackend.test.ets` side-effect test:

```ts
it('allows Composio side-effect execute after session search selection', 0, () => {
  expect(isUnsafeComposioExecute('GMAIL_SEND_EMAIL', '{}')).assertFalse();
  expect(isUnsafeComposioExecute('NOTION_CREATE_PAGE', '{"title":"AIPhoneDemo"}')).assertFalse();
  expect(isUnsafeComposioExecute('GITHUB_FIND_PULL_REQUESTS', '{"sort":"updated"}')).assertFalse();
});
```

Add a user-scope test:

```ts
it('keeps configured app user id for Composio dynamic calls', 0, () => {
  configureComposioUserId('aiphone-user-device-1');
  expect(currentComposioUserId()).assertEqual('aiphone-user-device-1');
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk node /Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js test --no-daemon
```

Expected: FAIL for missing `proxyBaseUrl`, `configureComposioUserId`, or old unsafe expectation.

- [ ] **Step 3: Extend config**

Modify `agent_core/src/main/ets/composio/ComposioConfig.ets`:

```ts
interface ComposioConfigJson {
  apiKey?: string;
  baseUrl?: string;
  userId?: string;
  proxyBaseUrl?: string;
  proxyApiKey?: string;
}
```

Add a field and constructor argument:

```ts
readonly proxyBaseUrl: string;
readonly proxyApiKey: string;

constructor(apiKey: string, baseUrl: string, userId: string, proxyBaseUrl: string = '', proxyApiKey: string = '') {
  this.apiKey = apiKey.trim();
  this.baseUrl = ComposioConfig.trimTrailingSlash(
    baseUrl.trim().length > 0 ? baseUrl : DEFAULT_COMPOSIO_URL
  );
  this.userId = userId.trim();
  this.proxyBaseUrl = ComposioConfig.trimTrailingSlash(proxyBaseUrl.trim());
  this.proxyApiKey = proxyApiKey.trim();
}
```

Pass `parsed.proxyBaseUrl ?? ''` and `parsed.proxyApiKey ?? ''` in `fromContext()` and `fromRawJson()`.

Update configuration checks:

```ts
isConfigured(): boolean {
  if (this.userId.length === 0) {
    return false;
  }
  if (this.proxyBaseUrl.length > 0) {
    return true;
  }
  return this.apiKey.length > 0 && this.baseUrl.length > 0;
}

missingConfiguration(): string {
  const missing: string[] = [];
  if (this.userId.length === 0) {
    missing.push('userId');
  }
  if (this.proxyBaseUrl.length === 0 && this.apiKey.length === 0) {
    missing.push('apiKey or proxyBaseUrl');
  }
  return missing.join(', ');
}
```

- [ ] **Step 4: Export gateway API key accessor**

Modify `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets` near `defaultToolGatewayUrl()`:

```ts
export function currentToolGatewayApiKey(): string {
  return localProviderConfig.toolGatewayApiKey;
}
```

- [ ] **Step 5: Add proxy-mode session requests**

Modify `agent_core/src/main/ets/composio/ComposioSessionClient.ets`.

Add a proxy-path mapper:

```ts
private requestBaseUrl(): string {
  return this.config.proxyBaseUrl.length > 0 ? this.config.proxyBaseUrl : this.config.baseUrl;
}

private requestPath(path: string): string {
  if (this.config.proxyBaseUrl.length === 0) {
    return path;
  }
  if (path === '/tool_router/session') {
    return '/v1/composio/session';
  }
  if (path.startsWith('/tool_router/session/')) {
    return '/v1/composio/session/' + path.substring('/tool_router/session/'.length);
  }
  return path;
}

private requestHeaders(): Record<string, string> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json'
  };
  if (this.config.proxyBaseUrl.length > 0) {
    if (this.config.proxyApiKey.length > 0) {
      headers.Authorization = 'Bearer ' + this.config.proxyApiKey;
    }
    return headers;
  }
  headers['x-api-key'] = this.config.apiKey;
  return headers;
}
```

Change `request()` to use `this.requestBaseUrl() + this.requestPath(path)` and `this.requestHeaders()`.

Keep `parseSearchResponse()` unchanged so proxy search still populates `discoveredTools`, and keep the existing execute guard:

```ts
if (!this.discoveredTools.has(normalizedSlug)) {
  return `Composio 拒绝执行：${normalizedSlug} 尚未通过当前 Session 的 search 发现。`;
}
```

- [ ] **Step 6: Add dynamic user configuration**

Modify `agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets` near the module-level config variables:

```ts
let runtimeComposioUserId: string = '';

export function configureComposioUserId(userId: string): void {
  runtimeComposioUserId = userId.trim();
  composioClient = null;
  scopedComposioClients.clear();
}

export function currentComposioUserId(): string {
  return runtimeComposioUserId.length > 0 ? runtimeComposioUserId : composioConfig.userId;
}

function configForCurrentUser(): ComposioConfig {
  return new ComposioConfig(
    composioConfig.apiKey,
    composioConfig.baseUrl,
    currentComposioUserId(),
    composioConfig.proxyBaseUrl,
    composioConfig.proxyApiKey
  );
}
```

Change `new ComposioSessionClient(composioConfig` calls to `new ComposioSessionClient(configForCurrentUser()`.

- [ ] **Step 7: Stop pre-blocking Composio side-effect tools**

Replace `isUnsafeComposioExecute()` body:

```ts
export function isUnsafeComposioExecute(_toolSlug: string, _argsJson: string): boolean {
  return false;
}
```

Keep `ComposioSessionClient.execute()` search-discovery enforcement intact:

```ts
if (!this.discoveredTools.has(normalizedSlug)) {
  return `Composio 拒绝执行：${normalizedSlug} 尚未通过当前 Session 的 search 发现。`;
}
```

- [ ] **Step 8: Run tests**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk node /Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js test --no-daemon
```

Expected: BUILD SUCCESSFUL.

- [ ] **Step 9: Commit**

```bash
git add agent_core/src/main/ets/composio/ComposioConfig.ets agent_core/src/main/ets/composio/ComposioSessionClient.ets agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets entry/src/test/ComposioConfig.test.ets entry/src/test/ComposioDynamicBackend.test.ets
git commit -m "Scope Composio dynamic calls to app users"
```

---

### Task 4: In-App Composio Authorization Page

**Files:**
- Create: `entry/src/main/ets/pages/A2uiHome/components/ComposioAuthViewData.ets`
- Create: `entry/src/main/ets/pages/A2uiHome/components/ComposioAuthPage.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/components/ConfigPage.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/Index.ets`
- Modify: `entry/src/main/module.json5`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Create: `entry/src/test/ComposioAuthViewData.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Interfaces:**
- Consumes: `ComposioAuthConfigItem[]`, `ComposioAuthProxyClient`, `configureComposioUserId(userId)`, `configureComposioConfigFromRawJson(rawJson)`
- Produces: settings entry and standalone `ComposioAuthPage`

- [ ] **Step 1: Write view-data tests**

Create `entry/src/test/ComposioAuthViewData.test.ets`:

```ts
import { describe, it, expect } from '@ohos/hypium';
import {
  composioAuthActionLabel,
  composioAuthStatusLabel,
  sortedComposioAuthConfigs
} from '../main/ets/pages/A2uiHome/components/ComposioAuthViewData';
import { ComposioAuthConfigItem } from '@loop/agent-core';

function item(slug: string, status: string): ComposioAuthConfigItem {
  return {
    authConfigId: 'ac_' + slug,
    toolkitSlug: slug,
    toolkitName: slug,
    logoUrl: '',
    authScheme: 'OAuth2',
    management: 'managed',
    status,
    connectedAccountId: status === 'connected' ? 'ca_' + slug : '',
    connectedAccountLabel: '',
    lastConnectedAt: '',
    canExecute: status === 'connected'
  };
}

export default function composioAuthViewDataTest() {
  describe('composioAuthViewData', () => {
    it('labels auth status and actions', 0, () => {
      expect(composioAuthStatusLabel('connected')).assertEqual('已连接');
      expect(composioAuthStatusLabel('needs_auth')).assertEqual('待授权');
      expect(composioAuthActionLabel(item('github', 'connected'))).assertEqual('重新授权');
      expect(composioAuthActionLabel(item('github', 'needs_auth'))).assertEqual('授权');
    });

    it('sorts connected configs first then by toolkit name', 0, () => {
      const sorted = sortedComposioAuthConfigs([item('slack', 'needs_auth'), item('github', 'connected'), item('asana', 'needs_auth')]);

      expect(sorted[0].toolkitSlug).assertEqual('github');
      expect(sorted[1].toolkitSlug).assertEqual('asana');
      expect(sorted[2].toolkitSlug).assertEqual('slack');
    });
  });
}
```

Modify `entry/src/test/List.test.ets`:

```ts
import composioAuthViewDataTest from './ComposioAuthViewData.test';
```

and call:

```ts
  composioAuthViewDataTest();
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk node /Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js test --no-daemon
```

Expected: FAIL with missing `ComposioAuthViewData`.

- [ ] **Step 3: Add view helpers**

Create `entry/src/main/ets/pages/A2uiHome/components/ComposioAuthViewData.ets`:

```ts
import { ComposioAuthConfigItem } from '@loop/agent-core';

export function composioAuthStatusLabel(status: string): string {
  if (status === 'connected') {
    return '已连接';
  }
  if (status === 'error') {
    return '异常';
  }
  if (status === 'disabled') {
    return '已停用';
  }
  return '待授权';
}

export function composioAuthActionLabel(item: ComposioAuthConfigItem): string {
  return item.status === 'connected' ? '重新授权' : '授权';
}

export function sortedComposioAuthConfigs(items: ComposioAuthConfigItem[]): ComposioAuthConfigItem[] {
  return items.slice().sort((left, right) => {
    const leftRank = left.status === 'connected' ? 0 : 1;
    const rightRank = right.status === 'connected' ? 0 : 1;
    if (leftRank !== rightRank) {
      return leftRank - rightRank;
    }
    return left.toolkitName.localeCompare(right.toolkitName);
  });
}
```

- [ ] **Step 4: Add the auth page**

Create `entry/src/main/ets/pages/A2uiHome/components/ComposioAuthPage.ets`:

```ts
import { ComposioAuthConfigItem } from '@loop/agent-core';
import {
  COLOR_ACCENT,
  COLOR_CARD_EDGE,
  COLOR_CARD_RAISED,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_PANEL,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { composioAuthActionLabel, composioAuthStatusLabel, sortedComposioAuthConfigs } from './ComposioAuthViewData';
import { StatusBadgeView } from './StatusBadgeView';

@Component
export struct ComposioAuthPage {
  @Prop userShortId: string = '';
  @Prop items: ComposioAuthConfigItem[] = [];
  @Prop message: string = '';
  @Prop isBusy: boolean = false;
  onBack: () => void = () => {};
  onRefresh: () => void = () => {};
  onAuthorize: (item: ComposioAuthConfigItem) => void = (_item: ComposioAuthConfigItem) => {};
  onResetUser: () => void = () => {};

  private visibleItems(): ComposioAuthConfigItem[] {
    return sortedComposioAuthConfigs(this.items);
  }

  @Builder
  AuthCard(item: ComposioAuthConfigItem) {
    Column() {
      Row() {
        Column() {
          Text(item.toolkitName.length > 0 ? item.toolkitName : item.toolkitSlug)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text(item.connectedAccountLabel.length > 0 ? item.connectedAccountLabel : item.authScheme)
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        StatusBadgeView({ status: item.status, label: composioAuthStatusLabel(item.status) })
      }
      .width('100%')

      Row() {
        Text(item.management.length > 0 ? item.management : 'Composio')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .layoutWeight(1)
        Button(composioAuthActionLabel(item))
          .height(34)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor(COLOR_ACCENT)
          .borderRadius(9)
          .enabled(!this.isBusy && item.authConfigId.length > 0)
          .onClick(() => this.onAuthorize(item))
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(COLOR_CARD_RAISED)
    .borderRadius(12)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ bottom: 10 })
  }

  build() {
    Column() {
      Row() {
        Button('返回')
          .height(34)
          .fontSize(12)
          .onClick(() => this.onBack())
        Text('Composio 授权')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button('刷新')
          .height(34)
          .fontSize(12)
          .enabled(!this.isBusy)
          .onClick(() => this.onRefresh())
      }
      .width('100%')

      Text('当前用户 ' + (this.userShortId.length > 0 ? this.userShortId : '未初始化'))
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .margin({ top: 10, bottom: 12 })

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ bottom: 12 })
      }

      if (this.visibleItems().length === 0) {
        Text('当前没有可授权的 Composio Auth Config。')
          .fontSize(14)
          .fontColor(COLOR_TEXT)
          .padding(18)
          .backgroundColor(COLOR_CARD_RAISED)
          .borderRadius(12)
          .border({ width: 1, color: COLOR_CARD_EDGE })
      } else {
        ForEach(this.visibleItems(), (item: ComposioAuthConfigItem) => {
          this.AuthCard(item)
        }, (item: ComposioAuthConfigItem) => item.authConfigId)
      }

      Button('重置测试用户')
        .height(36)
        .fontSize(12)
        .margin({ top: 8 })
        .onClick(() => this.onResetUser())
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor(COLOR_PANEL)
  }
}
```

- [ ] **Step 5: Add settings entry**

Modify `entry/src/main/ets/pages/A2uiHome/components/ConfigPage.ets` props:

```ts
onOpenComposioAuth: () => void = () => {};
```

Add a button near the existing model setup buttons:

```ts
Button('Composio 授权')
  .height(36)
  .width('100%')
  .fontSize(12)
  .fontColor(COLOR_INK)
  .backgroundColor(COLOR_CARD_RAISED)
  .borderRadius(9)
  .border({ width: 1, color: COLOR_CARD_EDGE })
  .margin({ bottom: 14 })
  .onClick(() => {
    this.onOpenComposioAuth();
  })
```

- [ ] **Step 6: Wire page state in Index**

Modify `entry/src/main/ets/pages/A2uiHome/Index.ets` imports:

```ts
import {
  ComposioAuthConfigItem,
  ComposioAuthProxyClient,
  COMPOSIO_USER_ID_PREFIX,
  configureComposioConfigFromRawJson,
  configureComposioUserId,
  currentToolGatewayApiKey,
  normalizeComposioUserId,
  shortComposioUserId
} from '@loop/agent-core';
import util from '@ohos.util';
import { ComposioAuthPage } from './components/ComposioAuthPage';
```

Add state:

```ts
@State showComposioAuthPage: boolean = false;
@State composioUserId: string = '';
@State composioAuthItems: ComposioAuthConfigItem[] = [];
@State composioAuthMessage: string = '';
@State composioAuthBusy: boolean = false;
```

Add helpers:

```ts
private composioProxyBaseUrl(): string {
  let value = TOOL_GATEWAY_URL.trim();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value.endsWith('/api/aiphone/tool')
    ? value.substring(0, value.length - '/api/aiphone/tool'.length)
    : value;
}

private composioAuthClient(): ComposioAuthProxyClient {
  return new ComposioAuthProxyClient(this.composioProxyBaseUrl(), currentToolGatewayApiKey());
}

private ensureComposioUserId(): string {
  if (this.composioUserId.length > 0) {
    return this.composioUserId;
  }
  const generated = normalizeComposioUserId(COMPOSIO_USER_ID_PREFIX + util.generateRandomUUID(false));
  this.composioUserId = generated;
  configureComposioUserId(generated);
  return generated;
}

private configureComposioRuntimeForCurrentUser(): void {
  const userId = this.ensureComposioUserId();
  configureComposioUserId(userId);
  configureComposioConfigFromRawJson(JSON.stringify({
    userId: userId,
    proxyBaseUrl: this.composioProxyBaseUrl(),
    proxyApiKey: currentToolGatewayApiKey()
  }));
}

private async refreshComposioAuth(): Promise<void> {
  this.composioAuthBusy = true;
  try {
    this.configureComposioRuntimeForCurrentUser();
    const userId = this.ensureComposioUserId();
    const result = await this.composioAuthClient().listAuthConfigs(userId);
    this.composioAuthItems = result.items;
    this.composioAuthMessage = result.ok ? '已刷新 Composio 授权状态。' : result.error;
  } catch (error) {
    this.composioAuthMessage = error instanceof Error ? error.message : JSON.stringify(error);
  } finally {
    this.composioAuthBusy = false;
  }
}

private async openComposioAuthLink(item: ComposioAuthConfigItem): Promise<void> {
  this.composioAuthBusy = true;
  try {
    this.configureComposioRuntimeForCurrentUser();
    const link = await this.composioAuthClient().createLink(this.ensureComposioUserId(), item.authConfigId, item.toolkitSlug);
    if (!link.ok) {
      this.composioAuthMessage = link.error;
      return;
    }
    await this.openExternalUrl(link.redirectUrl);
  } catch (error) {
    this.composioAuthMessage = error instanceof Error ? error.message : JSON.stringify(error);
  } finally {
    this.composioAuthBusy = false;
  }
}
```

Add render branch before `ConfigPage`:

```ts
if (this.showComposioAuthPage) {
  ComposioAuthPage({
    userShortId: shortComposioUserId(this.ensureComposioUserId()),
    items: this.composioAuthItems,
    message: this.composioAuthMessage,
    isBusy: this.composioAuthBusy,
    onBack: () => { this.showComposioAuthPage = false; },
    onRefresh: () => { this.refreshComposioAuth(); },
    onAuthorize: (item: ComposioAuthConfigItem) => { this.openComposioAuthLink(item); },
    onResetUser: () => {
      this.composioUserId = '';
      this.composioAuthItems = [];
      this.composioAuthMessage = '已重置测试用户。';
      this.configureComposioRuntimeForCurrentUser();
    }
  })
  return;
}
```

Pass the settings entry callback into `ConfigPage`:

```ts
onOpenComposioAuth: () => {
  this.showComposioAuthPage = true;
  this.configureComposioRuntimeForCurrentUser();
  this.refreshComposioAuth();
}
```

- [ ] **Step 7: Register callback URI**

Modify `entry/src/main/module.json5` in the existing browsable URI list:

```json5
{
  "scheme": "aiphone",
  "host": "composio",
  "pathStartWith": "callback"
}
```

Modify `entry/src/main/ets/entryability/EntryAbility.ets`:

```ts
const COMPOSIO_CALLBACK_URI_HINTS: string[] = [
  'aiphone://composio/callback'
];

function isComposioCallbackUri(uri: string): boolean {
  return hasUriHint(uri, COMPOSIO_CALLBACK_URI_HINTS);
}
```

At the top of `handleOAuthWant(want)` after `const uri = oauthUriFromWant(want);`:

```ts
if (isComposioCallbackUri(uri)) {
  aiLogInfo('[AIPhone][ComposioCallbackWantReceived] uriChars=' + uri.length.toString());
  return;
}
```

The callback does not exchange tokens in-app; Composio finishes account linking on its hosted page. The user returns to the auth page and taps refresh, or the page can refresh on app resume in a later enhancement.

- [ ] **Step 8: Run tests**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk node /Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js test --no-daemon
```

Expected: BUILD SUCCESSFUL.

- [ ] **Step 9: Commit**

```bash
git add entry/src/main/ets/pages/A2uiHome/components/ComposioAuthViewData.ets entry/src/main/ets/pages/A2uiHome/components/ComposioAuthPage.ets entry/src/main/ets/pages/A2uiHome/components/ConfigPage.ets entry/src/main/ets/pages/A2uiHome/Index.ets entry/src/main/module.json5 entry/src/main/ets/entryability/EntryAbility.ets entry/src/test/ComposioAuthViewData.test.ets entry/src/test/List.test.ets
git commit -m "Add Composio authorization page"
```

---

### Task 5: Verification and Smoke Coverage

**Files:**
- Modify: `scripts/aiphone-device-smoke.mjs`
- Modify: `docs/current-capabilities.md`

**Interfaces:**
- Consumes: Tasks 1-4
- Produces: repeatable host and device verification for auth page and existing Composio queries

- [ ] **Step 1: Add optional smoke flag**

Modify `scripts/aiphone-device-smoke.mjs` near the option parsing:

```js
const runComposioAuthCases = argv.includes('--composio-auth');
```

Add one auth-page case to the selected cases when the flag is present:

```js
const composioAuthCases = [
  {
    query: '打开 Composio 授权页',
    expectedToolId: '',
    expectedTexts: ['Composio 授权', '当前用户', '授权']
  }
];
```

Merge it into selected cases:

```js
const selectedDefaultCases = runComposioAuthCases
  ? composioAuthCases
  : (runComposioCases ? composioCases : (runFullRegression ? fullRegressionCases : (runGoogleApps ? defaultCases.concat(googleAppCases) : (runDynamicCases ? defaultCases.concat(dynamicCases) : defaultCases))));
```

- [ ] **Step 2: Update docs**

Add this row to `docs/current-capabilities.md` optional smoke table:

```md
| `--composio-auth` | `打开 Composio 授权页` | 无工具 | 授权页显示当前用户和全部 Auth Config 卡片 |
```

Add this note under the Composio dynamic section:

```md
Composio 授权页只管理 Composio connected accounts，不替换现有静态工具的数据来源。App 端只保存 proxyBaseUrl、TOOL_GATEWAY_API_KEY 和 app-scoped userId，Composio API key 只存在于 tool-gateway。发送、创建、更新类 Composio 工具允许执行，但必须来自当前 session search 返回的 tool slug。
```

- [ ] **Step 3: Run full local checks**

Run:

```bash
COMPOSIO_AUTH_MOCK=1 node tool-gateway/smoke-test.mjs --composio-auth
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk node /Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js test --no-daemon
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk node /Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js assembleHap --no-daemon
```

Expected:

- gateway smoke prints PASS for Composio auth cases
- tests finish with BUILD SUCCESSFUL
- HAP assembly finishes with BUILD SUCCESSFUL

- [ ] **Step 4: Run device verification**

Run with a connected device:

```bash
hdc list targets
hdc -t <device-id> install -r entry/build/default/outputs/default/entry-default-signed.hap
COMPOSIO_AUTH_MOCK=1 AIPHONE_HDC_TARGET=<device-id> node scripts/aiphone-device-smoke.mjs --composio-auth
node scripts/aiphone-device-smoke.mjs --composio-tools
```

Expected:

- `--composio-auth` shows `Composio 授权`, `当前用户`, and at least one Auth Config card.
- `--composio-tools` keeps the existing GitHub, Drive, Docs, and Slack Composio query behavior working.

- [ ] **Step 5: Commit**

```bash
git add scripts/aiphone-device-smoke.mjs docs/current-capabilities.md
git commit -m "Cover Composio auth smoke"
```

---

## Self-Review

- Spec coverage: Tasks 1-4 implement the proxy, per-user ID, independent auth page, all Auth Config display, and dynamic user scoping. Task 5 covers docs and verification.
- Scope check: No task changes static Gmail, SocialHub Slack, X, Calendar, Maps, Stripe, or YouTube tool routing.
- Safety check: Composio API key stays in `tool-gateway/.env.local`; HAP only knows proxy URL and gateway API key.
- Type consistency: `ComposioAuthConfigItem`, `ComposioAuthProxyClient`, `normalizeComposioUserId`, and `configureComposioUserId` are introduced before UI tasks consume them.
