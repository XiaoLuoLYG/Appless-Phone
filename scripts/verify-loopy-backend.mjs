#!/usr/bin/env node
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..');
const hvigor = '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js';
const sdkHome = process.env.DEVECO_SDK_HOME || '/Applications/DevEco-Studio.app/Contents/sdk';

const checks = [];

function pass(name) {
  checks.push({ name, ok: true });
  console.log(`PASS ${name}`);
}

function fail(name, detail) {
  checks.push({ name, ok: false });
  console.error(`FAIL ${name}`);
  if (detail) {
    console.error(`     ${detail}`);
  }
}

function assert(condition, name, detail = '') {
  if (condition) {
    pass(name);
  } else {
    fail(name, detail);
  }
}

function read(relativePath) {
  return readFileSync(resolve(repoRoot, relativePath), 'utf8');
}

function assertContains(text, needle, name) {
  assert(text.includes(needle), name, `missing ${needle}`);
}

function runHarBuild() {
  assert(existsSync(hvigor), 'DevEco hvigor is installed', hvigor);
  assert(existsSync(sdkHome), 'DevEco SDK home exists', sdkHome);
  if (!existsSync(hvigor) || !existsSync(sdkHome)) {
    return;
  }

  const result = spawnSync(process.execPath, [
    hvigor,
    '--mode',
    'module',
    '-p',
    'module=agent_core@default',
    '-p',
    'product=default',
    'assembleHar',
    '--analyze=normal',
    '--parallel',
    '--incremental',
    '--daemon'
  ], {
    cwd: repoRoot,
    env: {
      ...process.env,
      DEVECO_SDK_HOME: sdkHome
    },
    encoding: 'utf8'
  });

  if (result.stdout.trim().length > 0) {
    console.log(result.stdout.trim());
  }
  if (result.stderr.trim().length > 0) {
    console.error(result.stderr.trim());
  }
  assert(result.status === 0, 'agent_core HAR builds', `exit status ${result.status}`);
}

function verifySourceContracts() {
  const protocol = read('agent_core/src/main/ets/a2ui/A2uiProtocol.ets');
  const llmProvider = read('agent_core/src/main/ets/model/LlmProvider.ets');
  const openAiModel = read('agent_core/src/main/ets/model/OpenAiCompatibleModel.ets');
  const aiphoneA2ui = read('agent_core/src/main/ets/aiphone/AiphoneA2ui.ets');
  const definitions = read('agent_core/src/main/ets/aiphone/AiphoneToolDefinitions.ets');
  const executor = read('agent_core/src/main/ets/aiphone/AiphoneToolExecutor.ets');
  const backend = read('agent_core/src/main/ets/aiphone/LoopBackend.ets');
  const runner = read('agent_core/src/main/ets/agent/ReActAgentRunner.ets');
  const index = read('agent_core/Index.ets');
  const runtimeDefinitions = read('agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets');
  const runtimeGateway = read('agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets');
  const composioConfig = read('agent_core/src/main/ets/composio/ComposioConfig.ets');
  const composioClient = read('agent_core/src/main/ets/composio/ComposioSessionClient.ets');
  const composioDynamic = read('agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets');
  const runtimeDir = resolve(repoRoot, 'agent_core/src/main/ets/aiphone/runtime');

  assertContains(protocol, "export const A2UI_VERSION = 'v0.9.1';", 'AIPhone A2UI version is v0.9.1');
  assertContains(llmProvider, "endsWith('/v1/chat/completions')", 'model base URL can be full chat completions URL');
  assertContains(llmProvider, "endsWith('/v1')", 'model base URL can be OpenAI v1 root');
  assertContains(openAiModel, 'buildRequestJson', 'OpenAI-compatible model applies custom parameters');
  assertContains(openAiModel, 'customParametersJson', 'OpenAI-compatible model reads custom parameter JSON');
  assertContains(openAiModel, 'search(/"model"\\s*:/)', 'custom parameters cannot replace model');
  assertContains(openAiModel, 'search(/"messages"\\s*:/)', 'custom parameters cannot replace messages');
  assertContains(aiphoneA2ui, 'export function aiphoneInfoJsonl', 'AIPhone final answer helper exists');
  assertContains(aiphoneA2ui, "component: 'InfoRows'", 'final answer helper renders InfoRows');

  const ids = [...definitions.matchAll(/toolId:\s*'([^']+)'/g)].map((match) => match[1]);
  const runtimeIds = [...runtimeDefinitions.matchAll(/toolId:\s*'([^']+)'/g)].map((match) => match[1]);
  const uniqueIds = new Set(ids);
  const runtimeUniqueIds = new Set(runtimeIds);
  assert(ids.length === uniqueIds.size, 'AIPhone tool ids are unique');
  assert(runtimeIds.length === runtimeUniqueIds.size, 'runtime tool ids are unique');
  assert(ids.length >= 22, 'AIPhone tool registry has expected breadth', `found ${ids.length}`);
  for (const id of [
    'travel.search',
    'train.search',
    'flight.search',
    'food.search',
    'social.feed.search',
    'social.reply.draft',
    'x.post.search',
    'mail.search',
    'mail.thread.read',
    'mail.draft.create',
    'gmail.mail.search',
    'gmail.thread.read',
    'gmail.draft.create',
    'gmail.message.send',
    'media.video.search',
    'youtube.video.search',
    'calendar.events.search',
    'calendar.event.create',
    'maps.place.search',
    'maps.place.details'
  ]) {
    assert(uniqueIds.has(id), `registered ${id}`);
    assert(runtimeUniqueIds.has(id), `runtime registered ${id}`);
  }
  assertContains(definitions, "toolId === 'dynamic.search'", 'dynamic.search is treated as registered');
  assertContains(definitions, 'return TOOL_DEFINITIONS.length;', 'tool definition count uses source list');
  assert(ids.every((id) => runtimeUniqueIds.has(id)), 'public and runtime tool registries align');

  const runtimeFiles = readdirSync(runtimeDir).filter((name) => name.endsWith('.ets'));
  assert(runtimeFiles.length >= 30, 'AIPhone runtime files are vendored into agent_core', `found ${runtimeFiles.length}`);

  assertContains(executor, 'isRegisteredToolId(toolId)', 'executor rejects unknown tools through runtime registry');
  assertContains(executor, 'callToolGateway(', 'executor delegates to runtime tool gateway');
  assertContains(executor, 'defaultToolGatewayUrl()', 'executor uses local AIPhone tool route');
  assertContains(executor, 'result.raw.trim().length > 0', 'executor returns runtime A2UI JSONL');

  assertContains(runtimeGateway, 'async function callLocalTravelSearch', 'runtime includes travel execution');
  assertContains(runtimeGateway, 'async function callLocalTrainSearch', 'runtime includes train execution');
  assertContains(runtimeGateway, 'async function callLocalFlightSearch', 'runtime includes flight execution');
  assertContains(runtimeGateway, 'async function callLocalFoodSearch', 'runtime includes food execution');
  assertContains(runtimeGateway, 'async function callLocalMailTool', 'runtime includes aggregate mail execution');
  assertContains(runtimeGateway, 'async function callLocalGmailTool', 'runtime includes Gmail execution');
  assertContains(runtimeGateway, 'async function callLocalMediaTool', 'runtime includes media video execution');
  assertContains(runtimeGateway, 'async function callLocalYouTubeTool', 'runtime includes YouTube execution');
  assertContains(runtimeGateway, 'async function callLocalCalendarTool', 'runtime includes Calendar execution');
  assertContains(runtimeGateway, 'async function callLocalMapsTool', 'runtime includes Maps execution');
  assertContains(runtimeGateway, 'async function callLocalSocialHubTool', 'runtime includes SocialHub execution');
  assertContains(runtimeGateway, 'async function buildDynamicToolJsonl', 'runtime includes dynamic tool execution');
  assertContains(runtimeGateway, 'callComposioDynamic', 'dynamic.search tries Composio fallback');
  assertContains(runtimeGateway, 'gmailBlockedSendA2ui(surfaceId, toolId)', 'runtime blocks Gmail direct send');
  assertContains(runtimeGateway, '不会模拟 Gmail 邮件', 'runtime does not simulate Gmail');
  assertContains(runtimeGateway, "toolId === 'social.reply.draft'", 'runtime drafts SocialHub replies instead of sending');

  assertContains(backend, 'allToolDefinitions()', 'LoopBackend registers AIPhone definitions');
  assertContains(backend, "registry.register(new AiphoneTool(\n      'dynamic.search'", 'LoopBackend registers dynamic.search');
  assertContains(backend, 'splitJsonl(jsonl)', 'LoopBackend splits AIPhone JSONL');
  assertContains(backend, 'this.callbacks.onA2uiJsonl?.(line)', 'LoopBackend emits AIPhone JSONL lines');
  assertContains(backend, 'runAiphoneTool(', 'LoopBackend delegates tool execution to AIPhone executor');
  assertContains(backend, 'a2uiLineCount === 0', 'LoopBackend only emits final surface when no tool UI exists');
  assertContains(backend, 'aiphoneInfoJsonl', 'LoopBackend emits A2UI for plain final answers');
  assertContains(backend, 'Composio-backed app/toolkit requests', 'LoopBackend describes Composio dynamic routing');
  assertContains(backend, 'Keep the query focused to the relevant 6-10 OR terms', 'LoopBackend preserves Gmail academic query expansion guidance');
  assertContains(runner, 'isA2uiObservation(observation)', 'ReAct runner stops after A2UI tool observations');

  assertContains(index, 'LoopBackend', 'public export includes LoopBackend');
  assertContains(index, "export { runAiphoneTool }", 'public export includes runAiphoneTool');
  assertContains(index, 'aiphoneInfoJsonl', 'public export includes final answer helper');
  assertContains(index, 'allToolDefinitions', 'public export includes tool definitions');
  assertContains(index, 'configureLocalProviderConfigFromRawJson', 'public export includes provider raw JSON config');
  assertContains(index, 'prepareGmailOAuthAuthorizationUrl', 'public export includes Gmail OAuth helper');
  assertContains(index, 'AssetCredentialStore', 'public export includes dynamic credential store');
  assertContains(index, 'ComposioConfig', 'public export includes ComposioConfig');
  assertContains(index, 'ComposioDynamicBackend', 'public export includes Composio dynamic backend');
  assertContains(composioConfig, 'fromRawJson', 'Composio config can load raw JSON');
  assertContains(composioClient, 'tool_router/session', 'Composio client uses tool router sessions');
  assertContains(composioDynamic, 'isComposioDynamicPrompt', 'Composio dynamic backend gates unsupported app queries');
  assertContains(composioDynamic, 'unsafe_action_blocked', 'Composio dynamic backend blocks unsafe execute');
}

runHarBuild();
verifySourceContracts();

const failed = checks.filter((check) => !check.ok);
if (failed.length > 0) {
  console.error(`\n${failed.length} verification check(s) failed.`);
  process.exit(1);
}

console.log(`\nAIPhone Loopy backend smoke passed (${checks.length} checks).`);
