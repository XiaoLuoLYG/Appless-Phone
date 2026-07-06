# AIPhone Composio Loopy Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Loopy's Composio support as an AIPhone `dynamic.search` backend, then sync the latest AIPhone runtime back to Loopy without removing Loopy's Composio code.

**Architecture:** Keep AIPhoneDemo's `LoopBackend` as the product runtime. Vendor Loopy's Composio client files into local `agent_core`, load `composio_config.json` through `EntryAbility`, and call Composio only from the existing dynamic tool path when the local catalog cannot cover the query or the model asks for a Composio execute phase.

**Tech Stack:** HarmonyOS ArkTS, existing `@loop/agent-core`, Loopy `hos` Composio ArkTS files, existing A2UI JSONL helpers, existing Hypium tests, DevEco `hvigor`, GitHub PR flow.

---

## File Structure

- Create `agent_core/src/main/ets/composio/ComposioConfig.ets`: copied from Loopy, plus a raw-JSON parser for tests and `EntryAbility`.
- Create `agent_core/src/main/ets/composio/ComposioSessionClient.ets`: copied from Loopy unchanged unless compile errors require local SDK import fixes.
- Create `agent_core/src/main/ets/composio/ComposioTool.ets`: copied from Loopy for export parity; AIPhoneDemo does not register it as a visible fixed tool.
- Create `agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets`: small AIPhone adapter that maps Composio search/execute into existing dynamic tool result data and blocks unsafe execute requests.
- Modify `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`: store Composio config, pass `dynamic.search` args to the Composio adapter after local discovery misses.
- Modify `agent_core/src/main/ets/aiphone/runtime/DynamicToolRegistry.ets`: extend existing unsafe action detection with common side-effect verbs.
- Modify `agent_core/src/main/ets/aiphone/LoopBackend.ets`: make the `dynamic.search` tool description mention the Composio two-phase fallback.
- Modify `agent_core/Index.ets`: export Composio files and the dynamic adapter test helpers.
- Modify `entry/src/main/ets/entryability/EntryAbility.ets`: optionally load `composio_config.json` after the dynamic adapter exposes the config function.
- Create `entry/src/main/resources/rawfile/composio_config.example.json`: tracked schema only.
- Modify `.gitignore`: ignore the real `entry/src/main/resources/rawfile/composio_config.json`.
- Create `entry/src/test/ComposioConfig.test.ets`.
- Create `entry/src/test/ComposioDynamicBackend.test.ets`.
- Modify `entry/src/test/ToolGatewayClient.test.ets`: add the missing-config Notion smoke for `dynamic.search`.
- Modify `entry/src/test/List.test.ets`: register the two new test files.
- Modify `scripts/verify-loopy-backend.mjs`: assert Composio exports and dynamic fallback contracts.
- Modify `scripts/aiphone-device-smoke.mjs`: add a focused `--composio-tools` query set.

## Task 0: Protect The Current Dirty Worktree

**Files:**
- Read-only: current worktree

- [ ] **Step 1: Record current branch and dirty files**

Run:

```bash
git branch --show-current
git status -sb
git diff --name-only HEAD --
git ls-files --others --exclude-standard
```

Expected:

```text
aiphone-composio-loopy-sync
```

The status includes user-local modified files from the latest payment/runtime work. Do not stage those files unless a task explicitly modifies the same file for Composio.

- [ ] **Step 2: Verify only planning commits are on this branch**

Run:

```bash
git log --oneline --decorate --max-count=3
git show --stat --name-status --max-count=1 HEAD
```

Expected: `HEAD` is the Composio sync implementation plan commit, preceded by the design commit. The shown file for `HEAD` is only `docs/superpowers/plans/2026-07-06-aiphone-composio-loopy-sync.md`.

- [ ] **Step 3: Keep staging narrow for every commit**

Before each commit in later tasks, run:

```bash
git diff --cached --name-status
```

Expected: only files listed in that task are staged. If unrelated files appear, unstage them with:

```bash
git restore --staged <path>
```

## Task 1: Vendor Composio Files And Load Config

**Files:**
- Create: `agent_core/src/main/ets/composio/ComposioConfig.ets`
- Create: `agent_core/src/main/ets/composio/ComposioSessionClient.ets`
- Create: `agent_core/src/main/ets/composio/ComposioTool.ets`
- Modify: `agent_core/Index.ets`
- Create: `entry/src/main/resources/rawfile/composio_config.example.json`
- Modify: `.gitignore`
- Test: `entry/src/test/ComposioConfig.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: Write the failing config tests**

Create `entry/src/test/ComposioConfig.test.ets`:

```ts
import { describe, it, expect } from '@ohos/hypium';
import { ComposioConfig } from '@loop/agent-core';

export default function composioConfigTest() {
  describe('composioConfig', () => {
    it('parses raw JSON config and trims trailing slashes', 0, () => {
      const config = ComposioConfig.fromRawJson('{"apiKey":" key ","baseUrl":"https://example.test/api/","userId":" user "}');

      expect(config.apiKey).assertEqual('key');
      expect(config.baseUrl).assertEqual('https://example.test/api');
      expect(config.userId).assertEqual('user');
      expect(config.isConfigured()).assertTrue();
    });

    it('returns a safe empty config for invalid JSON', 0, () => {
      const config = ComposioConfig.fromRawJson('{broken');

      expect(config.apiKey).assertEqual('');
      expect(config.baseUrl).assertEqual('https://backend.composio.dev/api/v3.1');
      expect(config.userId).assertEqual('');
      expect(config.isConfigured()).assertFalse();
      expect(config.missingConfiguration()).assertEqual('apiKey, userId');
    });
  });
}
```

Modify `entry/src/test/List.test.ets`:

```ts
import composioConfigTest from './ComposioConfig.test';
```

Call it next to the other runtime/config tests:

```ts
  composioConfigTest();
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test --no-daemon
```

Expected: compile fails because `ComposioConfig` is not exported or `fromRawJson` is missing.

- [ ] **Step 3: Copy Loopy Composio files**

Run:

```bash
mkdir -p agent_core/src/main/ets/composio
cp /tmp/loopy-hos-latest-design/harmony/agent_core/src/main/ets/composio/ComposioConfig.ets agent_core/src/main/ets/composio/ComposioConfig.ets
cp /tmp/loopy-hos-latest-design/harmony/agent_core/src/main/ets/composio/ComposioSessionClient.ets agent_core/src/main/ets/composio/ComposioSessionClient.ets
cp /tmp/loopy-hos-latest-design/harmony/agent_core/src/main/ets/composio/ComposioTool.ets agent_core/src/main/ets/composio/ComposioTool.ets
```

Expected: three new files exist under `agent_core/src/main/ets/composio/`.

- [ ] **Step 4: Add raw JSON parsing to ComposioConfig**

Modify `agent_core/src/main/ets/composio/ComposioConfig.ets` by adding this method inside `export class ComposioConfig`:

```ts
  static fromRawJson(rawJson: string): ComposioConfig {
    try {
      const parsed = JSON.parse(rawJson) as ComposioConfigJson;
      return new ComposioConfig(
        parsed.apiKey ?? '',
        parsed.baseUrl ?? DEFAULT_COMPOSIO_URL,
        parsed.userId ?? ''
      );
    } catch (_error) {
      return new ComposioConfig('', DEFAULT_COMPOSIO_URL, '');
    }
  }
```

Keep Loopy's existing `fromContext()` method intact.

- [ ] **Step 5: Export Composio classes**

Add these exports to `agent_core/Index.ets` near the model exports:

```ts
export { ComposioConfig } from './src/main/ets/composio/ComposioConfig';
export { ComposioSessionClient } from './src/main/ets/composio/ComposioSessionClient';
export { ComposioTool } from './src/main/ets/composio/ComposioTool';
```

- [ ] **Step 6: Add tracked example and ignore real config**

Create `entry/src/main/resources/rawfile/composio_config.example.json`:

```json
{
  "apiKey": "",
  "baseUrl": "https://backend.composio.dev/api/v3.1",
  "userId": ""
}
```

Add this line to `.gitignore` near the existing rawfile secret ignores:

```gitignore
entry/src/main/resources/rawfile/composio_config.json
```

- [ ] **Step 7: Run config tests**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test --no-daemon
```

Expected: `ComposioConfig.test.ets` passes. If unrelated existing tests fail, record the failing names and continue only after confirming Composio tests pass.

- [ ] **Step 8: Commit config/vendor work**

Run:

```bash
git add .gitignore agent_core/src/main/ets/composio agent_core/Index.ets entry/src/main/resources/rawfile/composio_config.example.json entry/src/test/ComposioConfig.test.ets entry/src/test/List.test.ets
git diff --cached --name-status
git commit -m "feat: add composio config support"
```

Expected: staged files match this task only.

## Task 2: Add The AIPhone Composio Dynamic Adapter

**Files:**
- Create: `agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/DynamicToolRegistry.ets`
- Modify: `agent_core/Index.ets`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Test: `entry/src/test/ComposioDynamicBackend.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: Write failing adapter tests**

Create `entry/src/test/ComposioDynamicBackend.test.ets`:

```ts
import { describe, it, expect } from '@ohos/hypium';
import {
  composioDynamicMissingConfigResult,
  composioDynamicResultFromObservation,
  isComposioDynamicPrompt,
  isUnsafeComposioExecute
} from '@loop/agent-core';

export default function composioDynamicBackendTest() {
  describe('composioDynamicBackend', () => {
    it('recognizes unsupported high-frequency app queries', 0, () => {
      expect(isComposioDynamicPrompt('帮我在 Notion 里找一下 7 月旅行计划相关页面')).assertTrue();
      expect(isComposioDynamicPrompt('帮我查 Linear 里分配给我的高优先级 bug')).assertTrue();
      expect(isComposioDynamicPrompt('帮我查最近重要邮件')).assertFalse();
    });

    it('maps missing config to a truthful result', 0, () => {
      const result = composioDynamicMissingConfigResult('帮我在 Notion 里找签证材料');

      expect(result.sourceTag).assertEqual('Composio');
      expect(result.toolName).assertEqual('dynamic.search');
      expect(result.status).assertEqual('needs_auth');
      expect(result.summary.indexOf('Composio 未配置')).assertLarger(-1);
      expect(result.rawPreview.indexOf('Notion')).assertLarger(-1);
    });

    it('blocks likely side-effect execute requests', 0, () => {
      expect(isUnsafeComposioExecute('GMAIL_SEND_EMAIL', '{}')).assertTrue();
      expect(isUnsafeComposioExecute('NOTION_SEARCH', '{"query":"visa"}')).assertFalse();
    });

    it('maps a Composio search observation to a generic result', 0, () => {
      const result = composioDynamicResultFromObservation('search', '{"source":"Composio","authorizedToolkits":["notion"],"tools":[{"toolSlug":"NOTION_SEARCH","description":"Search pages","inputSchema":"{}"}],"instruction":"Choose one returned toolSlug"}');

      expect(result.sourceTag).assertEqual('Composio');
      expect(result.toolName).assertEqual('dynamic.search');
      expect(result.status).assertEqual('success');
      expect(result.summary.indexOf('NOTION_SEARCH')).assertLarger(-1);
      expect(result.rawPreview.indexOf('authorizedToolkits')).assertLarger(-1);
    });
  });
}
```

Modify `entry/src/test/List.test.ets`:

```ts
import composioDynamicBackendTest from './ComposioDynamicBackend.test';
```

Call it after `dynamicToolA2uiTest();`:

```ts
  composioDynamicBackendTest();
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test --no-daemon
```

Expected: compile fails because `ComposioDynamicBackend` exports do not exist.

- [ ] **Step 3: Create the adapter**

Create `agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets`:

```ts
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
```

- [ ] **Step 4: Extend unsafe tool detection**

Modify `UNSAFE_TOOL_PATTERNS` in `agent_core/src/main/ets/aiphone/runtime/DynamicToolRegistry.ets`:

```ts
const UNSAFE_TOOL_PATTERNS: string[] = [
  'book',
  'pay',
  'create',
  'create_order',
  'submit_order',
  'send',
  'update',
  'delete',
  'cancel',
  'refund',
  'redeem',
  'grab_ticket',
  'purchase',
  'transfer',
  'post',
  'invite',
  'share'
];
```

- [ ] **Step 5: Export adapter helpers**

Add to `agent_core/Index.ets` near other runtime exports:

```ts
export * from './src/main/ets/aiphone/runtime/ComposioDynamicBackend';
```

- [ ] **Step 6: Load optional Composio rawfile in EntryAbility**

Modify the import from `@loop/agent-core` in `entry/src/main/ets/entryability/EntryAbility.ets`:

```ts
  configureComposioConfigFromRawJson,
```

Add a rawfile constant:

```ts
const COMPOSIO_CONFIG_RAWFILE = 'composio_config.json';
```

Call this after `this.loadLocalProviderConfig();` in `onCreate()` and `onNewWant()`:

```ts
    this.loadComposioConfig();
```

Add this method next to `loadLocalProviderConfig()`:

```ts
  private loadComposioConfig(): void {
    try {
      configureComposioConfigFromRawJson(this.rawfileText(COMPOSIO_CONFIG_RAWFILE));
      hilog.info(DOMAIN, 'testTag', 'Loaded Composio config.');
    } catch (err) {
      hilog.info(DOMAIN, 'testTag', 'Composio config not loaded from %{public}s. Cause: %{public}s', COMPOSIO_CONFIG_RAWFILE, JSON.stringify(err));
    }
  }
```

- [ ] **Step 7: Run adapter tests**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test --no-daemon
```

Expected: `ComposioDynamicBackend.test.ets` passes.

- [ ] **Step 8: Commit adapter work**

Run:

```bash
git add agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets agent_core/src/main/ets/aiphone/runtime/DynamicToolRegistry.ets agent_core/Index.ets entry/src/main/ets/entryability/EntryAbility.ets entry/src/test/ComposioDynamicBackend.test.ets entry/src/test/List.test.ets
git diff --cached --name-status
git commit -m "feat: add composio dynamic adapter"
```

Expected: staged files match this task only.

## Task 3: Wire Composio Into `dynamic.search`

**Files:**
- Modify: `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`
- Modify: `agent_core/src/main/ets/aiphone/LoopBackend.ets`
- Test: `entry/src/test/ToolGatewayClient.test.ets`

- [ ] **Step 1: Write failing gateway test**

Add this test inside `describe('toolGatewayClient', () => { ... })` in `entry/src/test/ToolGatewayClient.test.ets`:

```ts
    it('uses Composio missing-config result for unsupported app dynamic queries', 0, async () => {
      configureComposioConfigFromRawJson('{}');
      let latest: A2uiSurfaceState | null = null;

      const result = await callToolGateway(
        defaultToolGatewayUrl(),
        'dynamic.search',
        '帮我在 Notion 里找一下 7 月旅行计划相关页面',
        'surface_composio',
        '',
        (surface: A2uiSurfaceState): void => {
          latest = surface;
        }
      );

      const surface = latest as A2uiSurfaceState;
      const serialized = JSON.stringify(surface.data);
      expect(result.ok).assertTrue();
      expect(serialized.indexOf('Composio')).assertLarger(-1);
      expect(serialized.indexOf('needs_auth')).assertLarger(-1);
      expect(serialized.indexOf('Notion')).assertLarger(-1);
    });
```

Add `configureComposioConfigFromRawJson` to the existing import from `@loop/agent-core`.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test --no-daemon
```

Expected: the new test fails because `dynamic.search` still returns the ModelScope no-tool-found card for Notion.

- [ ] **Step 3: Import and call Composio fallback**

Modify imports in `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`:

```ts
import { callComposioDynamic } from './ComposioDynamicBackend';
```

Exported `configureComposioConfigFromRawJson` can be re-exported through `Index.ets` from Task 2. If `ToolGatewayClient.ets` already exports config helpers in its explicit export list, do not duplicate the function there.

Modify `buildDiscoveredDynamicToolJsonl()`:

```ts
async function buildDiscoveredDynamicToolJsonl(prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  const discovery: DynamicToolDiscoveryResult | null = discoverDynamicToolForPrompt(prompt);
  if (discovery === null) {
    const composioResult = await callComposioDynamic(prompt, args);
    if (composioResult !== null) {
      aiLogInfo('[AIPhone][DynamicToolDiscovery] query=' + prompt + ' selectedToolId=dynamic.search source=composio status=' + composioResult.status);
      return genericToolResultsA2ui(surfaceId, 'dynamic.search', [composioResult]);
    }
    aiLogInfo('[AIPhone][DynamicToolDiscovery] query=' + prompt + ' selectedToolId=none source=modelscope-local-catalog');
    return connectCardA2ui(
      surfaceId,
      'dynamic.search',
      dynamicDiscoveryMissingManifest(prompt),
      'no_tool_found',
      '已根据用户请求搜索本机 ModelScope MCP 候选目录，但没有找到可直接接入的远程 MCP/API。',
      prompt
    );
  }
  aiLogInfo('[AIPhone][DynamicToolDiscovery] query=' + prompt +
    ' selectedToolId=' + discovery.toolId +
    ' manifestId=' + discovery.manifest.id +
    ' source=' + discovery.source +
    ' score=' + discovery.score.toString() +
    ' reason=' + discovery.reason);
  return buildDynamicToolJsonlWithManifest(discovery.toolId, prompt, surfaceId, discovery.manifest);
}
```

Modify `buildDynamicToolJsonl()`:

```ts
async function buildDynamicToolJsonl(toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  if (toolId === 'dynamic.search') {
    return buildDiscoveredDynamicToolJsonl(prompt, surfaceId, args);
  }
```

Modify the caller in `buildLocalToolJsonl()`:

```ts
  return buildDynamicToolJsonl(toolId, prompt, surfaceId, args);
```

- [ ] **Step 4: Update dynamic.search description**

Modify the `dynamic.search` registration text in `agent_core/src/main/ets/aiphone/LoopBackend.ets`:

```ts
      'dynamic.search inputSchema=dynamicToolSearchQuery outputSchema=dynamicToolConnect. Use for ModelScope/remote MCP discovery, weather requests, Composio-backed app/toolkit requests, and domains not covered by fixed tools. For Composio, first call with the full user task to discover candidate tools; only call again with {"operation":"execute","toolSlug":"returned slug","arguments":{...}} for read/search/list/get actions. Do not use Composio for payment, Gmail, Calendar, SocialHub, Maps, Food, Travel, or other fixed-tool domains unless the user explicitly asks for an unsupported external app/toolkit.',
```

- [ ] **Step 5: Run gateway test**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test --no-daemon
```

Expected: the new Notion missing-config test passes, and existing dynamic/weather tests still pass.

- [ ] **Step 6: Commit dynamic wiring**

Run:

```bash
git add agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets agent_core/src/main/ets/aiphone/LoopBackend.ets entry/src/test/ToolGatewayClient.test.ets
git diff --cached --name-status
git commit -m "feat: route dynamic search through composio"
```

Expected: staged files match this task only.

## Task 4: Add Verification Coverage

**Files:**
- Modify: `scripts/verify-loopy-backend.mjs`
- Modify: `scripts/aiphone-device-smoke.mjs`
- Modify: `docs/current-capabilities.md` if that file is intended to be committed with the current branch

- [ ] **Step 1: Update static backend verification**

In `scripts/verify-loopy-backend.mjs`, add these reads near the other source reads:

```js
  const composioConfig = read('agent_core/src/main/ets/composio/ComposioConfig.ets');
  const composioClient = read('agent_core/src/main/ets/composio/ComposioSessionClient.ets');
  const composioDynamic = read('agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets');
```

Add these assertions near the dynamic runtime assertions:

```js
  assertContains(index, 'ComposioConfig', 'public export includes ComposioConfig');
  assertContains(index, 'ComposioDynamicBackend', 'public export includes Composio dynamic backend');
  assertContains(composioConfig, 'fromRawJson', 'Composio config can load raw JSON');
  assertContains(composioClient, 'tool_router/session', 'Composio client uses tool router sessions');
  assertContains(composioDynamic, 'isComposioDynamicPrompt', 'Composio dynamic backend gates unsupported app queries');
  assertContains(composioDynamic, 'unsafe_action_blocked', 'Composio dynamic backend blocks unsafe execute');
  assertContains(runtimeGateway, 'callComposioDynamic', 'dynamic.search tries Composio fallback');
  assertContains(backend, 'Composio-backed app/toolkit requests', 'LoopBackend describes Composio dynamic routing');
```

- [ ] **Step 2: Run backend verification**

Run:

```bash
node scripts/verify-loopy-backend.mjs
```

Expected: `AIPhone Loopy backend smoke passed` and the check count increases.

- [ ] **Step 3: Add Composio device smoke query group**

In `scripts/aiphone-device-smoke.mjs`, add a flag next to the existing mode flags:

```js
const useComposioTools = args.includes('--composio-tools');
```

Add cases:

```js
const composioToolCases = [
  { query: '帮我在 Notion 里找一下 7 月旅行计划相关页面', expectsTool: true, expectedToolId: 'dynamic.search', expectedDiscovery: /Composio|needs_auth|no connected account|未配置/ },
  { query: '帮我在 Google Drive 里找签证材料', expectsTool: true, expectedToolId: 'dynamic.search', expectedDiscovery: /Composio|needs_auth|no connected account|未配置/ },
  { query: '帮我查 Linear 里分配给我的高优先级 bug', expectsTool: true, expectedToolId: 'dynamic.search', expectedDiscovery: /Composio|needs_auth|no connected account|未配置/ },
  { query: '帮我给本周发布创建一个 checklist', expectsTool: true, expectedToolId: 'dynamic.search', expectedDiscovery: /unsafe_action_blocked|确认|Composio|未配置/ }
];
```

Update query selection:

```js
const selectedDefaultCases = useComposioTools ? composioToolCases : (useDynamicTools ? dynamicToolCases : defaultCases);
```

If this exact variable is already shaped differently in the latest file, keep the existing style and add `composioToolCases` as the third explicit mode without changing default cases.

- [ ] **Step 4: Run script syntax check**

Run:

```bash
node --check scripts/aiphone-device-smoke.mjs
node scripts/aiphone-device-smoke.mjs --help >/tmp/aiphone-smoke-help.txt 2>&1 || true
```

Expected: `node --check` exits 0. The help command may exit nonzero if the script requires device context; syntax must be clean.

- [ ] **Step 5: Commit verification work**

Run:

```bash
git add scripts/verify-loopy-backend.mjs scripts/aiphone-device-smoke.mjs
git diff --cached --name-status
git commit -m "test: cover composio dynamic backend"
```

If `docs/current-capabilities.md` is updated as user-facing docs for Composio, stage it in a separate docs commit:

```bash
git add docs/current-capabilities.md
git commit -m "docs: document composio dynamic backend"
```

Expected: no local debug directory is staged.

## Task 5: Verify Local Branch

**Files:**
- No planned source edits

- [ ] **Step 1: Run focused tests**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test --no-daemon
node scripts/verify-loopy-backend.mjs
```

Expected:

- Composio config tests pass.
- Composio dynamic backend tests pass.
- Notion missing-config dynamic gateway test passes.
- `verify-loopy-backend.mjs` passes.

- [ ] **Step 2: Run local build**

Run:

```bash
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp --no-daemon
```

Expected: build succeeds. Existing ArkTS warnings are acceptable if they match the current warning class and no new error appears.

- [ ] **Step 3: Run targeted device smoke when a 6w device is available**

Run:

```bash
node scripts/aiphone-device-smoke.mjs --composio-tools
node scripts/aiphone-device-smoke.mjs --query '帮我查今天 X 和 Slack 上的消息'
node scripts/aiphone-device-smoke.mjs --query '用 PayPal 给罗一格转 5 美元'
```

Expected:

- Composio app queries route to `dynamic.search`.
- Missing Composio config or missing connected account is visible and truthful.
- Create/checklist-style Composio query does not silently write.
- Existing SocialHub and payment routes still use fixed tools.

## Task 6: Reverse Sync To Loopy

**Files:**
- Loopy temp clone/worktree under `/tmp` or `/Users/luoyige/DevEcoStudioProjects/loopy`
- Modify Loopy paths under `harmony/agent_core`, `harmony/scripts`

- [ ] **Step 1: Refresh Loopy and inspect PR state**

Run:

```bash
rm -rf /tmp/loopy-aiphone-sync
git clone --branch hos --single-branch https://github.com/Raym0ndKwan/loopy.git /tmp/loopy-aiphone-sync
git -C /tmp/loopy-aiphone-sync log --oneline --decorate --max-count=8
gh pr list --repo Raym0ndKwan/loopy --state open --limit 10
```

Expected: `hos` includes `bd5f873` or a newer commit. If `hos` is newer, inspect new commits before copying files.

- [ ] **Step 2: Create or update a Loopy sync branch**

If PR #3 is still open and belongs to the user fork, update that branch. Otherwise create a new branch:

```bash
git -C /tmp/loopy-aiphone-sync switch -c aiphone-runtime-composio-sync
```

Expected: a branch based on current Loopy `hos`.

- [ ] **Step 3: Copy AIPhone runtime paths without deleting Composio**

Run from AIPhoneDemo repo:

```bash
rsync -a --delete \
  --exclude 'src/main/ets/composio/' \
  agent_core/ /tmp/loopy-aiphone-sync/harmony/agent_core/
rsync -a scripts/verify-loopy-backend.mjs /tmp/loopy-aiphone-sync/harmony/scripts/verify-aiphone-backend.mjs
rsync -a scripts/aiphone-device-smoke.mjs /tmp/loopy-aiphone-sync/harmony/scripts/aiphone-device-smoke.mjs
```

Expected: Loopy keeps `harmony/agent_core/src/main/ets/composio/*`.

- [ ] **Step 4: Restore Loopy-specific generic Composio registry if rsync changed it**

Inspect:

```bash
git -C /tmp/loopy-aiphone-sync diff -- harmony/agent_core/src/main/ets/agent/ToolRegistry.ets harmony/agent_core/Index.ets
```

If `ToolRegistry.ets` lost Loopy's `createConfiguredLoopToolRegistry`, restore it from `hos` and re-apply only AIPhone-compatible exports:

```bash
git -C /tmp/loopy-aiphone-sync checkout hos -- harmony/agent_core/src/main/ets/agent/ToolRegistry.ets
```

Then ensure `harmony/agent_core/Index.ets` exports both local AIPhone additions and Loopy Composio exports:

```ts
export { ToolRegistry, ToolRegistryCloseHandler, createConfiguredLoopToolRegistry, createLoopToolRegistry } from './src/main/ets/agent/ToolRegistry';
export { ComposioConfig } from './src/main/ets/composio/ComposioConfig';
export { ComposioSessionClient } from './src/main/ets/composio/ComposioSessionClient';
export { ComposioTool } from './src/main/ets/composio/ComposioTool';
```

- [ ] **Step 5: Run Loopy verification**

Run:

```bash
node /tmp/loopy-aiphone-sync/harmony/scripts/verify-aiphone-backend.mjs
```

Expected: Loopy backend smoke passes and includes Composio plus current AIPhone runtime checks.

- [ ] **Step 6: Commit and push Loopy branch**

Run:

```bash
git -C /tmp/loopy-aiphone-sync status -sb
git -C /tmp/loopy-aiphone-sync add harmony/agent_core harmony/scripts/verify-aiphone-backend.mjs harmony/scripts/aiphone-device-smoke.mjs
git -C /tmp/loopy-aiphone-sync diff --cached --name-status
git -C /tmp/loopy-aiphone-sync commit -m "Sync latest AIPhone runtime with Composio"
git -C /tmp/loopy-aiphone-sync push -u origin aiphone-runtime-composio-sync
```

Expected: staged Loopy files preserve `harmony/agent_core/src/main/ets/composio/*`.

- [ ] **Step 7: Open or update the Loopy PR**

Run:

```bash
gh pr create --repo Raym0ndKwan/loopy --base hos --head aiphone-runtime-composio-sync --title "Sync latest AIPhone runtime with Composio" --body "Syncs current AIPhone runtime into Loopy while preserving Loopy Composio support. Verification: node harmony/scripts/verify-aiphone-backend.mjs."
```

If the branch updates existing PR #3, use:

```bash
gh pr edit 3 --repo Raym0ndKwan/loopy --title "Sync latest AIPhone runtime with Composio" --body "Syncs current AIPhone runtime into Loopy while preserving Loopy Composio support. Verification: node harmony/scripts/verify-aiphone-backend.mjs."
```

Expected: Loopy PR exists against `hos`.

## Task 7: Final Local PR Prep

**Files:**
- No planned source edits

- [ ] **Step 1: Confirm local branch status**

Run:

```bash
git status -sb
git log --oneline --decorate --max-count=8
```

Expected: branch contains separate commits for design, config/vendor, adapter, wiring, verification. User-local files are either intentionally committed or still visible as unstaged user changes.

- [ ] **Step 2: Push local branch**

Run:

```bash
git push -u origin aiphone-composio-loopy-sync
```

Expected: branch pushes to the AIPhoneDemo remote.

- [ ] **Step 3: Open local PR**

Run:

```bash
gh pr create --base main --head aiphone-composio-loopy-sync --title "Add Composio dynamic backend" --body "Adds Loopy Composio support as an AIPhone dynamic.search backend, keeps fixed tool routes unchanged, and adds Composio-focused verification queries. Verification: hvigor test; node scripts/verify-loopy-backend.mjs; targeted device smoke for --composio-tools when configured."
```

Expected: PR is created without a `[codex]` title prefix.

## Self-Review

- Spec coverage: local Composio import, dynamic backend routing, config hygiene, safety blocking, verification queries, and Loopy reverse sync each map to tasks above.
- Placeholder scan: no task relies on unspecified files or unnamed tests.
- Type consistency: exported helper names in tests match the adapter names defined in Task 2.
- Scope check: the plan keeps the local repo as source of day-to-day development and avoids switching AIPhoneDemo to an external Loopy package.
