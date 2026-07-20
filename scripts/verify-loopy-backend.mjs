#!/usr/bin/env node
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  symlinkSync
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..');
const hvigorRoot = '/Applications/DevEco-Studio.app/Contents/tools/hvigor';
const hvigor = '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js';
const sdkHome = process.env.DEVECO_SDK_HOME || '/Applications/DevEco-Studio.app/Contents/sdk';
const jbrHome = '/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home';
const harOutput = resolve(repoRoot, 'agent_core/build/default/outputs/default/agent_core.har');

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

function stripComments(source) {
  return source.replace(/\/\*[\s\S]*?\*\/|\/\/[^\r\n]*/g, '');
}

function readAgentRuntimeSources() {
  const sources = [];
  function visit(directory) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const entryPath = resolve(directory, entry.name);
      if (entry.isDirectory()) {
        visit(entryPath);
      } else if (entry.isFile() && entry.name.endsWith('.ets')) {
        sources.push(readFileSync(entryPath, 'utf8'));
      }
    }
  }
  visit(resolve(repoRoot, 'agent_core/src/main/ets/agent'));
  return stripComments(sources.join('\n'));
}

function parseIndexExports(index) {
  const exports = new Map();
  for (const match of index.matchAll(/export\s+(\*|\{[\s\S]*?\})\s+from\s+'([^']+)';/g)) {
    const names = match[1] === '*' ? ['*'] : match[1]
      .slice(1, -1)
      .split(',')
      .map((name) => name.trim())
      .filter((name) => name.length > 0);
    exports.set(match[2], names);
  }
  return exports;
}

function assertIndexExport(indexExports, modulePath, expectedNames, name) {
  const actualNames = indexExports.get(modulePath) ?? [];
  const missing = expectedNames.filter((expected) => actualNames.indexOf(expected) < 0);
  const extra = actualNames.filter((actual) => expectedNames.indexOf(actual) < 0);
  assert(
    missing.length === 0 && extra.length === 0,
    name,
    `${modulePath}: missing=[${missing.join(', ')}] extra=[${extra.join(', ')}]`
  );
}

function declarationBody(source, declaration) {
  const declarationStart = source.indexOf(declaration);
  const bodyStart = declarationStart < 0 ? -1 : source.indexOf('{', declarationStart);
  if (bodyStart < 0) {
    return '';
  }
  let depth = 0;
  for (let index = bodyStart; index < source.length; index++) {
    if (source.charAt(index) === '{') {
      depth++;
    } else if (source.charAt(index) === '}') {
      depth--;
      if (depth === 0) {
        return source.slice(bodyStart + 1, index);
      }
    }
  }
  return '';
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function runHarBuild() {
  assert(existsSync(hvigor), 'DevEco hvigor is installed', hvigor);
  assert(existsSync(sdkHome), 'DevEco SDK home exists', sdkHome);
  if (!existsSync(hvigor) || !existsSync(sdkHome)) {
    return;
  }

  const nodePathRoot = mkdtempSync(resolve(tmpdir(), 'aiphone-hvigor-'));
  const scopeRoot = resolve(nodePathRoot, '@ohos');
  mkdirSync(scopeRoot, { recursive: true });
  symlinkSync(resolve(hvigorRoot, 'hvigor'), resolve(scopeRoot, 'hvigor'), 'dir');
  symlinkSync(resolve(hvigorRoot, 'hvigor-ohos-plugin'), resolve(scopeRoot, 'hvigor-ohos-plugin'), 'dir');

  let result;
  try {
    result = spawnSync(process.execPath, [
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
      '--no-daemon'
    ], {
      cwd: repoRoot,
      env: {
        ...process.env,
        DEVECO_SDK_HOME: sdkHome,
        OHOS_SDK_HOME: resolve(sdkHome, 'default/openharmony'),
        JAVA_HOME: jbrHome,
        NODE_PATH: nodePathRoot,
        PATH: `${resolve(jbrHome, 'bin')}:${process.env.PATH ?? ''}`
      },
      encoding: 'utf8'
    });
  } finally {
    rmSync(nodePathRoot, { recursive: true, force: true });
  }

  if (result.stdout.trim().length > 0) {
    console.log(result.stdout.trim());
  }
  if (result.stderr.trim().length > 0) {
    console.error(result.stderr.trim());
  }
  const built = result.status === 0 &&
    result.stdout.includes('BUILD SUCCESSFUL') &&
    existsSync(harOutput);
  assert(built, 'agent_core HAR builds', `exit status ${result.status}; HAR exists=${existsSync(harOutput)}`);
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
  const indexExports = parseIndexExports(index);
  const agentRuntimeSources = readAgentRuntimeSources();
  const runtimeDefinitions = read('agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets');
  const runtimeGateway = read('agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets');
  const composioConfig = read('agent_core/src/main/ets/composio/ComposioConfig.ets');
  const composioClient = read('agent_core/src/main/ets/composio/ComposioSessionClient.ets');
  const composioDynamic = read('agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets');
  const conversationContext = read('agent_core/src/main/ets/agent/ConversationContext.ets');
  const agentMessage = read('agent_core/src/main/ets/agent/message/AgentMessage.ets');
  const messageBus = read('agent_core/src/main/ets/agent/message/LinkedMessageBus.ets');
  const leaderAgent = read('agent_core/src/main/ets/agent/leader/LeaderAgent.ets');
  const dataAgent = read('agent_core/src/main/ets/agent/data/DataAgent.ets');
  const uiAgent = read('agent_core/src/main/ets/agent/ui/UiAgent.ets');
  const actionCatalog = read('agent_core/src/main/ets/agent/action/ActionCatalog.ets');
  const actionPlanRunner = read('agent_core/src/main/ets/agent/action/ActionPlanRunner.ets');
  const jsonPointer = read('agent_core/src/main/ets/agent/action/JsonPointer.ets');
  const actionAgent = read('agent_core/src/main/ets/agent/action/ActionAgent.ets');
  const conversationStore = read('agent_core/src/main/ets/agent/ConversationStore.ets');
  const skillParser = read('agent_core/src/main/ets/skill/SkillMarkdownParser.ets');
  const skillStore = read('agent_core/src/main/ets/skill/SkillStore.ets');
  const genericMcp = read('agent_core/src/main/ets/aiphone/runtime/GenericMcpClient.ets');
  const modelScope = read('agent_core/src/main/ets/modelscope/ModelScopeDirectClient.ets');
  const modelScopeSearchStart = modelScope.indexOf('async search(useCase: string)');
  const modelScopeExecuteStart = modelScope.indexOf('async execute(qualifiedName: string', modelScopeSearchStart);
  const modelScopeExecuteEnd = modelScope.indexOf('private async fetchOperationalServers', modelScopeExecuteStart);
  const modelScopeSearch = modelScopeSearchStart >= 0 && modelScopeExecuteStart > modelScopeSearchStart
    ? modelScope.slice(modelScopeSearchStart, modelScopeExecuteStart)
    : '';
  const modelScopeExecute = modelScopeExecuteStart >= 0 && modelScopeExecuteEnd > modelScopeExecuteStart
    ? modelScope.slice(modelScopeExecuteStart, modelScopeExecuteEnd)
    : '';
  const modelScopeEmptyGuard = modelScopeSearch.indexOf('if (emptyObservation.length > MAX_OBSERVATION_CHARS)');
  const modelScopeCandidateLoop = modelScopeSearch.indexOf('for (let index = 0; index < selected.length; index++)');
  const modelScopeCandidateBound = modelScopeSearch.indexOf('if (candidateObservation.length > MAX_OBSERVATION_CHARS)');
  const modelScopeCandidateRollback = modelScopeSearch.indexOf('candidates.pop()', modelScopeCandidateBound);
  const modelScopeAuthorization = modelScopeSearch.indexOf(
    'this.discoveredTools.add(candidates[index].qualifiedName)',
    modelScopeCandidateRollback
  );
  const registry = read('agent_core/src/main/ets/agent/ToolRegistry.ets');
  const runtimeDir = resolve(repoRoot, 'agent_core/src/main/ets/aiphone/runtime');
  const streamablePath = resolve(repoRoot, 'agent_core/src/main/ets/modelscope/StreamableMcpClient.ets');
  const legacySocialPaths = [
    'SocialBridge.ets',
    'SocialCapabilityProbe.ets',
    'SocialNotificationArchive.ets'
  ].map((name) => resolve(runtimeDir, name));

  assertContains(protocol, "export const A2UI_VERSION = 'v0.9.1';", 'AIPhone A2UI version is v0.9.1');
  assertContains(llmProvider, "endsWith('/v1/chat/completions')", 'model base URL can be full chat completions URL');
  assertContains(llmProvider, "endsWith('/v1')", 'model base URL can be OpenAI v1 root');
  assertContains(openAiModel, 'buildRequestJson', 'OpenAI-compatible model applies custom parameters');
  assertContains(openAiModel, 'customParametersJson', 'OpenAI-compatible model reads custom parameter JSON');
  assertContains(openAiModel, 'search(/"model"\\s*:/)', 'custom parameters cannot replace model');
  assertContains(openAiModel, 'search(/"messages"\\s*:/)', 'custom parameters cannot replace messages');
  assertContains(
    openAiModel,
    'streamEndResolve();\n      await streamEnd;',
    'OpenAI-compatible stream completion does not rely only on dataEnd'
  );
  assertContains(aiphoneA2ui, 'export function aiphoneInfoJsonl', 'AIPhone final answer helper exists');
  assertContains(aiphoneA2ui, "component: 'InfoRows'", 'final answer helper renders InfoRows');

  const ids = [...definitions.matchAll(/toolId:\s*'([^']+)'/g)].map((match) => match[1]);
  const runtimeIds = [...runtimeDefinitions.matchAll(/toolId:\s*'([^']+)'/g)].map((match) => match[1]);
  const uniqueIds = new Set(ids);
  const runtimeUniqueIds = new Set(runtimeIds);
  const publicOnlyToolIds = ids.filter((id) => !runtimeUniqueIds.has(id));
  const runtimeOnlyToolIds = runtimeIds.filter((id) => !uniqueIds.has(id));
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
  assertContains(runtimeGateway, "if (toolId === 'dynamic.search')", 'runtime registry explicitly handles dynamic.search');
  assertContains(definitions, 'return TOOL_DEFINITIONS.length;', 'tool definition count uses source list');
  assert(
    ids.length === runtimeIds.length &&
      publicOnlyToolIds.length === 0 &&
      runtimeOnlyToolIds.length === 0,
    'public and runtime tool registries align exactly',
    `public=${ids.length}; runtime=${runtimeIds.length}; public-only=[${publicOnlyToolIds.join(', ')}]; runtime-only=[${runtimeOnlyToolIds.join(', ')}]`
  );

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
  assertContains(runner, 'digest.isA2ui && digest.shouldStop', 'ReAct runner stops after terminal A2UI tool observations');

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
  assertContains(conversationContext, 'static fromMessages', 'conversation context can restore messages');
  const requiredIndexExports = [
    ['./src/main/ets/agent/message/AgentMessage', ['*'], 'message contract exports'],
    ['./src/main/ets/agent/message/DataResult', ['*'], 'data result exports'],
    ['./src/main/ets/agent/message/LinkedMessageBus', ['AgentMessageReader', 'LinkedMessageBus'], 'message bus exports'],
    ['./src/main/ets/agent/MessageDrivenAgent', ['MessageDrivenAgent'], 'message-driven base exports'],
    ['./src/main/ets/agent/leader/LeaderAgent', ['LeaderAgent'], 'Leader Agent exports'],
    ['./src/main/ets/agent/leader/LeaderTypes', ['*'], 'Leader Agent types export'],
    ['./src/main/ets/agent/data/DataAgent', ['DataAgent'], 'Data Agent exports'],
    ['./src/main/ets/agent/data/DataAgentTypes', ['*'], 'Data Agent types export'],
    ['./src/main/ets/agent/ui/UiAgent', ['UiAgent'], 'UI Agent exports'],
    ['./src/main/ets/agent/ui/UiAgentTypes', ['*'], 'UI Agent types export'],
    ['./src/main/ets/agent/action/ActionCatalog', ['ActionCatalog'], 'Action catalog exports'],
    ['./src/main/ets/agent/action/ActionCatalogTypes', ['*'], 'Action catalog types export'],
    ['./src/main/ets/agent/action/ActionPlanTypes', ['*'], 'Action plan types export'],
    ['./src/main/ets/agent/action/JsonPointer', [
      'JsonPointerResult',
      'JsonPointerSetResult',
      'resolveJsonPointer',
      'setJsonPointer'
    ], 'JSON Pointer exports'],
    ['./src/main/ets/agent/action/ActionPlanRunner', ['ActionPlanRunner'], 'Action plan runner exports'],
    ['./src/main/ets/agent/action/ActionAgent', ['ActionAgent'], 'Action Agent exports'],
    ['./src/main/ets/agent/action/ActionAgentTypes', ['*'], 'Action Agent types export']
  ];
  for (const [modulePath, names, name] of requiredIndexExports) {
    assertIndexExport(indexExports, modulePath, names, name);
  }
  assert(
    !/\b(?:MessageNode|LeaderTurnState|UiTurnContext|PendingDataEntry|PendingPlanCorrelation|ContextSurfaceWriteLease|StoredActionRun|ActiveActionRun)\b/.test(index),
    'public API omits linked nodes and mutable role contexts'
  );
  for (const [role, source] of [
    ['LeaderAgent', leaderAgent],
    ['DataAgent', dataAgent],
    ['UiAgent', uiAgent],
    ['ActionAgent', actionAgent]
  ]) {
    assert(new RegExp(`export\\s+class\\s+${role}\\b`).test(source), `four-role runtime includes ${role}`);
  }
  assert(/export\s+class\s+AgentMessageReader\b/.test(messageBus), 'message bus reader is public');
  assert(/export\s+class\s+LinkedMessageBus\b/.test(messageBus), 'linked message bus is public');
  assert(/export\s+class\s+ActionCatalog\b/.test(actionCatalog), 'action catalog is public');

  const agentMessageEnum = declarationBody(agentMessage, 'export enum AgentMessageType');
  const agentEnvelope = declarationBody(agentMessage, 'export interface AgentMessage');
  for (const [member, value] of [
    ['INPUT_USER', 'INPUT.USER'],
    ['TASK_CREATE_UI', 'TASK.CREATE.UI'],
    ['TASK_CREATE_DATA', 'TASK.CREATE.DATA'],
    ['TASK_RESULT_UI', 'TASK.RESULT.UI'],
    ['TASK_RESULT_DATA', 'TASK.RESULT.DATA'],
    ['TASK_ERROR', 'TASK.ERROR'],
    ['ACTION_PLAN_CREATE', 'ACTION.PLAN.CREATE'],
    ['ACTION_PLAN_READY', 'ACTION.PLAN.READY'],
    ['ACTION_RUN', 'ACTION.RUN'],
    ['ACTION_PROGRESS', 'ACTION.PROGRESS'],
    ['ACTION_RESULT', 'ACTION.RESULT'],
    ['TURN_CANCEL', 'TURN.CANCEL']
  ]) {
    assert(
      new RegExp(`\\b${member}\\s*=\\s*'${escapeRegex(value)}'\\s*,?`).test(agentMessageEnum),
      `agent message enum includes ${value}`
    );
  }
  for (const [field, type] of [
    ['type', 'AgentMessageType'],
    ['conversationId', 'string'],
    ['turnId', 'string'],
    ['taskId', 'string'],
    ['payload', 'Object']
  ]) {
    assert(
      new RegExp(`\\b${field}\\s*:\\s*${type}\\s*;`).test(agentEnvelope),
      `agent message envelope has ${field}`
    );
  }
  assert(/export\s+function\s+resolveJsonPointer\s*\(/.test(jsonPointer), 'JSON Pointer resolver is declared');
  assert(/export\s+function\s+setJsonPointer\s*\(/.test(jsonPointer), 'JSON Pointer setter is declared');
  assert(
    /const\s+MAX_ACTION_PLAN_STEPS\s*:\s*number\s*=\s*5\s*;/.test(actionPlanRunner) &&
      /plan\.steps\.length\s*>\s*MAX_ACTION_PLAN_STEPS/.test(actionPlanRunner),
    'action plans use the named five-step cap'
  );
  const actionAgentSource = stripComments(actionAgent);
  const actionAgentConstructor = actionAgentSource.match(
    /constructor\s*\(\s*bus\s*:\s*LinkedMessageBus\s*,\s*catalog\s*:\s*ActionCatalog\s*,\s*executor\s*:\s*RegisteredActionExecutor\s*\)\s*\{([\s\S]*?)\n\s*\}/
  );
  assert(
    /private\s+readonly\s+registeredExecutor\s*:\s*RegisteredActionExecutor\s*;/.test(actionAgentSource) &&
      actionAgentConstructor !== null &&
      /this\.registeredExecutor\s*=\s*executor\s*;/.test(actionAgentConstructor[1]),
    'Action Agent injects and stores RegisteredActionExecutor'
  );
  assert(!agentRuntimeSources.includes('BATCH_PENDING'), 'agent runtime has no BATCH_PENDING state');
  assert(!/\bclass\s+Coordinator\b/.test(agentRuntimeSources), 'agent runtime has no Coordinator class');
  assertContains(conversationStore, 'MAX_STORED_TURNS: number = 50', 'conversation store keeps the last 50 turns');
  assertContains(conversationStore, 'JSON.parse(raw)', 'conversation store parses persisted JSON defensively');
  assertContains(conversationStore, 'role !== ConversationRole.USER && role !== ConversationRole.ASSISTANT', 'conversation store ignores unknown roles');
  assertContains(conversationStore, 'return new ConversationContext()', 'conversation store falls back to an empty conversation');
  assertContains(skillParser, 'export function parseSkillMarkdown', 'skill markdown parser is present');
  assertContains(skillStore, 'if (pathExists(targetPath))', 'bundled skills do not overwrite sandbox files');
  assertContains(skillStore, 'await ensureBundledSkillsInSandbox(context)', 'sandbox skills are initialized before loading');
  assertContains(runner, 'AgentEventKind.SKILL', 'ReAct emits selected skills');
  assertContains(genericMcp, 'annotations: tool.annotations', 'MCP annotations are preserved');
  assertContains(modelScope, "from '../aiphone/runtime/GenericMcpClient'", 'ModelScope reuses GenericMcpClient');
  assertContains(modelScope, 'annotations.readOnlyHint !== true', 'ModelScope requires explicit read-only annotations');
  assertContains(modelScope, 'annotations.destructiveHint === true', 'ModelScope blocks destructive annotations');
  assertContains(modelScopeSearch, 'this.discoveredTools.clear()', 'ModelScope search resets the executable discovery set');
  assertContains(modelScopeSearch, 'annotations: tool.mcpTool.annotations', 'ModelScope search returns MCP annotations');
  assert(
    modelScopeEmptyGuard >= 0 &&
      modelScopeCandidateLoop > modelScopeEmptyGuard &&
      modelScopeCandidateBound > modelScopeCandidateLoop &&
      modelScopeCandidateRollback > modelScopeCandidateBound &&
      modelScopeAuthorization > modelScopeCandidateRollback &&
      modelScopeSearch.indexOf('return JSON.stringify(observation)', modelScopeAuthorization) > modelScopeAuthorization,
    'ModelScope authorizes only complete bounded search candidates',
    'missing ordered empty guard, candidate rollback, final-set authorization, or complete observation return'
  );
  assertContains(
    modelScopeExecute,
    'modelScopeExecutionDecision(this.discoveredTools.has(normalized), selectedMcpTool)',
    'ModelScope execute uses the latest-search safety gate'
  );
  assertContains(
    modelScopeExecute,
    "this.mcp.callTool(tool.registration, '', args)",
    'ModelScope execute calls the selected MCP registration'
  );
  assert(!modelScope.includes('domainBoost'), 'ModelScope has no domain boost');
  assert(!/飞常准|12306|天气|weather|searchFlightsByDepArr|searchFlightItineraries|getFlightPriceByCities/i.test(modelScope), 'ModelScope has no domain-specific routing');
  assert(!existsSync(streamablePath), 'ModelScope does not duplicate MCP transport');
  assertContains(registry, 'new ModelScopeTool', 'configured registry exposes ModelScope');
  assertContains(runner, "this.tools.has('modelscope')", 'ModelScope prompt is gated by actual registration');
  assertContains(index, "./src/main/ets/modelscope/ModelScopeTool", 'public export includes ModelScope');
  assert(!legacySocialPaths.some((path) => existsSync(path)), 'obsolete social bridge files are absent');
}

runHarBuild();
verifySourceContracts();

const failed = checks.filter((check) => !check.ok);
if (failed.length > 0) {
  console.error(`\n${failed.length} verification check(s) failed.`);
  process.exit(1);
}

console.log(`\nAIPhone Loopy backend smoke passed (${checks.length} checks).`);
