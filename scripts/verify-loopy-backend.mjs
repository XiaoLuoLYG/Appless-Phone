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

function indexExportMatches(indexExports, modulePath, expectedNames) {
  const actualNames = indexExports.get(modulePath) ?? [];
  return expectedNames.every((expected) => actualNames.indexOf(expected) >= 0) &&
    actualNames.every((actual) => expectedNames.indexOf(actual) >= 0);
}

function assertIndexExport(indexExports, modulePath, expectedNames, name) {
  const actualNames = indexExports.get(modulePath) ?? [];
  const missing = expectedNames.filter((expected) => actualNames.indexOf(expected) < 0);
  const extra = actualNames.filter((actual) => expectedNames.indexOf(actual) < 0);
  assert(
    indexExportMatches(indexExports, modulePath, expectedNames),
    name,
    `${modulePath}: missing=[${missing.join(', ')}] extra=[${extra.join(', ')}]`
  );
}

function blockBody(source, bodyStart) {
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

function declarationBody(source, declaration) {
  const declarationStart = source.indexOf(declaration);
  return blockBody(source, declarationStart < 0 ? -1 : source.indexOf('{', declarationStart));
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function hasEnumMember(body, member, value) {
  return new RegExp(`\\b${member}\\s*=\\s*'${escapeRegex(value)}'\\s*,?`).test(body);
}

function hasInterfaceField(body, field, type) {
  return new RegExp(`\\b${field}\\s*:\\s*${type}\\s*;`).test(body);
}

function hasNamedPlanStepCap(source) {
  return /const\s+MAX_ACTION_PLAN_STEPS\s*:\s*number\s*=\s*5\s*;/.test(source) &&
    /plan\.steps\.length\s*>\s*MAX_ACTION_PLAN_STEPS/.test(source);
}

function hasLiveToken(source, token) {
  return source.includes(token);
}

function hasLiveClass(source, name) {
  return new RegExp(`\\bclass\\s+${name}\\b`).test(source);
}

function hasRegisteredActionExecutorDependency(source) {
  const field = source.match(
    /private\s+readonly\s+([A-Za-z_$][\w$]*)\s*:\s*RegisteredActionExecutor\s*;/
  );
  if (field === null) {
    return false;
  }
  for (const constructor of source.matchAll(/constructor\s*\(([\s\S]*?)\)\s*\{/g)) {
    const parameter = constructor[1].match(
      /\b([A-Za-z_$][\w$]*)\s*:\s*RegisteredActionExecutor\b/
    );
    const body = blockBody(source, (constructor.index ?? 0) + constructor[0].length - 1);
    if (parameter !== null &&
      new RegExp(`\\bthis\\.${escapeRegex(field[1])}\\s*=\\s*${escapeRegex(parameter[1])}\\s*;`).test(body)) {
      return true;
    }
  }
  return false;
}

function toolDefinitionBody(source, toolId) {
  const liveSource = stripComments(source);
  const toolIdStart = liveSource.indexOf(`toolId: '${toolId}'`);
  return blockBody(liveSource, toolIdStart < 0 ? -1 : liveSource.lastIndexOf('{', toolIdStart));
}

function hasSystemIntentDefinition(source, toolId) {
  const body = toolDefinitionBody(source, toolId);
  return body.length > 0 && /backendPriority:\s*\[\s*'system_intent'\s*\]/.test(body);
}

function fieldMaskValue(source, name) {
  const match = stripComments(source).match(new RegExp(`${escapeRegex(name)}\\s*:\\s*string\\s*=\\s*'([^']+)'`));
  return match === null ? '' : match[1];
}

function hotelPhoneFieldsOnlyInDetailMask(source) {
  const liveSource = stripComments(source);
  const phoneFields = ['nationalPhoneNumber', 'internationalPhoneNumber'];
  const searchMask = fieldMaskValue(liveSource, 'HOTEL_CONTACT_SEARCH_FIELD_MASK');
  const detailMask = fieldMaskValue(liveSource, 'HOTEL_CONTACT_DETAIL_FIELD_MASK');
  if (phoneFields.some((field) => searchMask.split(',').indexOf(field) >= 0) ||
    !phoneFields.every((field) => detailMask.split(',').indexOf(field) >= 0)) {
    return false;
  }
  for (const match of liveSource.matchAll(/(?:export\s+)?const\s+([A-Z_]*FIELD_MASK)\s*:\s*string\s*=\s*'([^']+)'/g)) {
    if (match[1] !== 'HOTEL_CONTACT_DETAIL_FIELD_MASK' &&
      phoneFields.some((field) => match[2].split(',').indexOf(field) >= 0)) {
      return false;
    }
  }
  return true;
}

function liveDeclarationBody(source, declaration) {
  return declarationBody(stripComments(source), declaration);
}

function hasStructuredHotelGateway(source) {
  return liveDeclarationBody(source, 'export async function callStructuredHotelTool').length > 0;
}

function hasHotelSearchActions(source) {
  return /actions:\s*\[\s*'hotel.detail'\s*,\s*'hotel.navigate'\s*,\s*'hotel.call'\s*\]/
    .test(toolDefinitionBody(source, 'hotel.search'));
}

function hotelButtonGuards(a2uiSource, actionSource) {
  const resultBody = liveDeclarationBody(a2uiSource, 'function searchResultFor');
  const actionsBody = liveDeclarationBody(actionSource, 'export function hotelActionsFor');
  const navigationPlacement = /if\s*\(\s*hasValidHotelCoordinates\(hotel\)\s*\)\s*\{\s*const\s+navigate\s*=\s*hotelNavigateAction\(hotel\);\s*if\s*\(\s*validHotelNavigateArgs\(navigate\.args as HotelNavigateArgs\)\.ok\s*&&\s*canPlace\(navigate\)\s*\)\s*\{\s*actions\.push\(navigate\);/s;
  const callPlacement = /if\s*\(\s*hotel\.contact\s*!==\s*undefined\s*\)\s*\{\s*const\s+call\s*=\s*hotelCallAction\(hotel\);\s*if\s*\(\s*validHotelCallArgs\(call\.args as HotelCallArgs\)\.ok\s*&&\s*canPlace\(call\)\s*\)\s*\{\s*actions\.push\(call\);/s;
  return /actions:\s*hotelActionsFor\(hotel,\s*request,\s*canPlace\)/.test(resultBody) &&
    navigationPlacement.test(actionsBody) && callPlacement.test(actionsBody);
}

function hasConditionalHotelButtons(a2uiSource, actionSource) {
  const actionsBody = liveDeclarationBody(actionSource, 'export function hotelActionsFor');
  const navigationPushes = actionsBody.match(/\bactions\.push\(navigate\);/g) ?? [];
  const callPushes = actionsBody.match(/\bactions\.push\(call\);/g) ?? [];
  return hotelButtonGuards(a2uiSource, actionSource) &&
    navigationPushes.length === 1 && callPushes.length === 1;
}

function hasHotelContactLookupMasks(source) {
  const body = liveDeclarationBody(source, 'export async function callHotelContactLookup');
  const searchCall = /requestJson\(\s*http\.RequestMethod\.POST,\s*PLACES_SEARCH_URL,\s*key,\s*HOTEL_CONTACT_SEARCH_FIELD_MASK,\s*mapsTextSearchBody\(hotelContactSearchQuery\(hotel\)\),\s*responseMarker\s*\)/s;
  const detailCall = /requestJson\(\s*http\.RequestMethod\.GET,\s*PLACES_BASE_URL\s*\+\s*encodeParam\(match\.candidate\.providerPlaceId\),\s*key,\s*HOTEL_CONTACT_DETAIL_FIELD_MASK,\s*null,\s*responseMarker\s*\)/s;
  return searchCall.test(body) && detailCall.test(body);
}

function hasLegacyHotelUnknownActionRejection(source) {
  const body = liveDeclarationBody(source, 'async function callLocalHotelTool');
  return body.includes("if (toolId !== 'hotel.search' && toolId !== 'hotel.detail')") &&
    body.includes("return hotelFailureA2ui(surfaceId, toolId, 'Unsupported hotel tool: ' + toolId + '.');");
}

function hasTravelRoute(source) {
  const body = liveDeclarationBody(source, 'async function buildLocalToolJsonl');
  return /if\s*\(\s*toolId\s*===\s*'travel\.search'\s*\)\s*\{\s*return\s+callLocalTravelSearch\(prompt,\s*surfaceId\);\s*\}/s.test(body);
}

function hasHotelRolesOnBus(source) {
  const body = liveDeclarationBody(source, 'constructor(options: HotelAgentRuntimeOptions)');
  return [
    ['leader', 'LeaderAgent'],
    ['data', 'DataAgent'],
    ['ui', 'UiAgent'],
    ['action', 'ActionAgent']
  ].every(([field, role]) =>
    new RegExp(`this\\.${field}\\s*=\\s*new\\s+${role}\\s*\\(\\s*this\\.bus\\b`).test(body));
}

function verifyArchitectureVerifier() {
  const fixtureIndex = parseIndexExports(stripComments(`
    export { AgentMessage } from './message/AgentMessage';
    // export { DataResult } from './message/DataResult';
  `));
  assert(
    indexExportMatches(fixtureIndex, './message/AgentMessage', ['AgentMessage']),
    'verifier accepts a live exact Index export'
  );
  assert(
    !indexExportMatches(fixtureIndex, './message/DataResult', ['DataResult']),
    'verifier ignores a commented Index export'
  );
  assert(
    !indexExportMatches(fixtureIndex, './message/AgentMessage', ['AgentMessage', 'DataResult']),
    'verifier rejects a removed exact Index export'
  );

  const fixtureMessage = stripComments(`
    export enum AgentMessageType {
      INPUT_USER = 'INPUT.USER',
      // TASK_ERROR = 'TASK.ERROR'
    }
    export interface AgentMessage {
      conversationId: string;
      // taskId: string;
    }
  `);
  assert(
    hasEnumMember(declarationBody(fixtureMessage, 'export enum AgentMessageType'), 'INPUT_USER', 'INPUT.USER'),
    'verifier accepts a live message enum member'
  );
  assert(
    !hasEnumMember(declarationBody(fixtureMessage, 'export enum AgentMessageType'), 'TASK_ERROR', 'TASK.ERROR'),
    'verifier ignores a commented message enum member'
  );
  assert(
    !hasInterfaceField(declarationBody(fixtureMessage, 'export interface AgentMessage'), 'taskId', 'string'),
    'verifier rejects a missing or commented message envelope field'
  );

  assert(
    hasNamedPlanStepCap('const MAX_ACTION_PLAN_STEPS: number = 5; plan.steps.length > MAX_ACTION_PLAN_STEPS'),
    'verifier accepts an active named action-plan cap'
  );
  assert(
    !hasNamedPlanStepCap('const MAX_ACTION_PLAN_STEPS: number = 5; plan.steps.length > 5'),
    'verifier rejects an unused action-plan cap'
  );

  const commentedRuntime = stripComments('// BATCH_PENDING\n/* class Coordinator {} */');
  const liveRuntime = stripComments('const BATCH_PENDING = 1; class Coordinator {}');
  assert(
    !hasLiveToken(commentedRuntime, 'BATCH_PENDING') && !hasLiveClass(commentedRuntime, 'Coordinator'),
    'verifier ignores commented forbidden runtime state'
  );
  assert(
    hasLiveToken(liveRuntime, 'BATCH_PENDING') && hasLiveClass(liveRuntime, 'Coordinator'),
    'verifier detects live forbidden runtime state'
  );

  const reorderedExecutor = stripComments(`
    class ActionAgent {
      private readonly dispatcher: RegisteredActionExecutor;
      constructor(label: string, handler: RegisteredActionExecutor, bus: Object) {
        this.dispatcher = handler;
      }
    }
  `);
  const unusedExecutorImport = stripComments(`
    import { RegisteredActionExecutor } from './ActionAgentTypes';
    class ActionAgent {
      private readonly dispatcher: Object;
      constructor(handler: Object) {
        this.dispatcher = handler;
      }
    }
  `);
  assert(
    hasRegisteredActionExecutorDependency(reorderedExecutor),
    'verifier accepts renamed and reordered executor injection'
  );
  assert(
    !hasRegisteredActionExecutorDependency(unusedExecutorImport),
    'verifier rejects an unused executor import without typed injection'
  );

  const commentOnlyHotelSource = `
    // export async function callStructuredHotelTool() { return {}; }
    /* {
      toolId: 'hotel.search',
      actions: ['hotel.detail', 'hotel.navigate', 'hotel.call']
    }
    {
      toolId: 'hotel.navigate',
      backendPriority: ['system_intent']
    }
    async function callLocalHotelTool() {
      if (toolId !== 'hotel.search' && toolId !== 'hotel.detail') {
        return hotelFailureA2ui(surfaceId, toolId, 'Unsupported hotel tool: ' + toolId + '.');
      }
    }
    async function buildLocalToolJsonl() {
      if (toolId === 'travel.search') {
        return callLocalTravelSearch(prompt, surfaceId);
      }
    } */
  `;
  assert(
    !hasStructuredHotelGateway(commentOnlyHotelSource) &&
      !hasHotelSearchActions(commentOnlyHotelSource) &&
      !hasSystemIntentDefinition(commentOnlyHotelSource, 'hotel.navigate') &&
      !hasLegacyHotelUnknownActionRejection(commentOnlyHotelSource) &&
      !hasTravelRoute(commentOnlyHotelSource),
    'verifier rejects comment-only hotel contracts'
  );

  const unconditionalButtons = `
    function searchResultFor() {
      return { actions: hotelActionsFor(hotel, request, canPlace) };
    }
    export function hotelActionsFor() {
      const navigate = hotelNavigateAction(hotel);
      actions.push(navigate);
      const call = hotelCallAction(hotel);
      actions.push(call);
    }
  `;
  assert(
    !hasConditionalHotelButtons(unconditionalButtons, unconditionalButtons),
    'verifier rejects unconditional hotel navigation and call buttons'
  );

  const duplicateButtonPushes = `
    function searchResultFor() {
      return { actions: hotelActionsFor(hotel, request, canPlace) };
    }
    export function hotelActionsFor() {
      const navigate = hotelNavigateAction(hotel);
      actions.push(navigate);
      if (hasValidHotelCoordinates(hotel)) {
        const navigate = hotelNavigateAction(hotel);
        if (validHotelNavigateArgs(navigate.args as HotelNavigateArgs).ok && canPlace(navigate)) {
          actions.push(navigate);
        }
      }
      const call = hotelCallAction(hotel);
      actions.push(call);
      if (hotel.contact !== undefined) {
        const call = hotelCallAction(hotel);
        if (validHotelCallArgs(call.args as HotelCallArgs).ok && canPlace(call)) {
          actions.push(call);
        }
      }
    }
  `;
  assert(hotelButtonGuards(duplicateButtonPushes, duplicateButtonPushes), 'fixture reproduces former guarded-button predicate');
  assert(!hasConditionalHotelButtons(duplicateButtonPushes, duplicateButtonPushes), 'verifier rejects buttons pushed before guarded placement');

  const swappedHotelMasks = `
    export const HOTEL_CONTACT_SEARCH_FIELD_MASK: string = 'places.id,nationalPhoneNumber,internationalPhoneNumber';
    export const HOTEL_CONTACT_DETAIL_FIELD_MASK: string = 'id,displayName';
  `;
  assert(!hotelPhoneFieldsOnlyInDetailMask(swappedHotelMasks), 'verifier rejects swapped hotel phone field masks');

  const swappedHotelMaskUsage = `
    export const HOTEL_CONTACT_SEARCH_FIELD_MASK: string = 'places.id';
    export const HOTEL_CONTACT_DETAIL_FIELD_MASK: string = 'id,nationalPhoneNumber,internationalPhoneNumber';
    export async function callHotelContactLookup() {
      const searchPayload = await requestJson(
        http.RequestMethod.POST, PLACES_SEARCH_URL, key, HOTEL_CONTACT_DETAIL_FIELD_MASK,
        mapsTextSearchBody(hotelContactSearchQuery(hotel)), responseMarker
      );
      const detailPayload = await requestJson(
        http.RequestMethod.GET, PLACES_BASE_URL + encodeParam(match.candidate.providerPlaceId), key,
        HOTEL_CONTACT_SEARCH_FIELD_MASK, null, responseMarker
      );
    }
  `;
  assert(hotelPhoneFieldsOnlyInDetailMask(swappedHotelMaskUsage), 'fixture reproduces former field-mask declaration predicate');
  assert(!hasHotelContactLookupMasks(swappedHotelMaskUsage), 'verifier rejects swapped hotel field-mask callsites');

  const splitTravelRoute = `
    async function buildLocalToolJsonl() {
      if (toolId === 'travel.search') {
        return callLocalFoodSearch(prompt, surfaceId);
      }
      if (toolId === 'food.search') {
        return callLocalTravelSearch(prompt, surfaceId);
      }
    }
  `;
  const splitTravelBody = liveDeclarationBody(splitTravelRoute, 'async function buildLocalToolJsonl');
  assert(splitTravelBody.includes("if (toolId === 'travel.search')") && splitTravelBody.includes('return callLocalTravelSearch(prompt, surfaceId);'), 'fixture reproduces former travel token predicate');
  assert(!hasTravelRoute(splitTravelRoute), 'verifier rejects cross-branch travel routing');

  const decoyBusRuntime = `
    export class HotelAgentRuntime {
      constructor(options: HotelAgentRuntimeOptions) {
        const decoy = 'new LeaderAgent(this.bus) new DataAgent(this.bus) new UiAgent(this.bus) new ActionAgent(this.bus)';
        this.leader = new LeaderAgent(otherBus, planner);
        this.data = new DataAgent(otherBus, executor);
        this.ui = new UiAgent(otherBus, renderer, writer);
        this.action = new ActionAgent(otherBus, catalog, registered);
      }
    }
  `;
  const decoyConstructor = liveDeclarationBody(decoyBusRuntime, 'constructor(options: HotelAgentRuntimeOptions)');
  assert(['LeaderAgent', 'DataAgent', 'UiAgent', 'ActionAgent'].every((role) => new RegExp(`new\\s+${role}\\s*\\(\\s*this\\.bus\\b`).test(decoyConstructor)), 'fixture reproduces former bus-token predicate');
  assert(!hasHotelRolesOnBus(decoyBusRuntime), 'verifier rejects constructor string bus decoys');
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
  const index = stripComments(read('agent_core/Index.ets'));
  const indexExports = parseIndexExports(index);
  const agentRuntimeSources = readAgentRuntimeSources();
  const runtimeDefinitions = read('agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets');
  const runtimeGateway = read('agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets');
  const hotelA2ui = stripComments(read('agent_core/src/main/ets/aiphone/runtime/HotelToolA2ui.ets'));
  const hotelActions = stripComments(read('agent_core/src/main/ets/aiphone/runtime/HotelActions.ets'));
  const hotelRuntime = stripComments(read('entry/src/main/ets/pages/A2uiHome/agent/HotelAgentRuntime.ets'));
  const mapsApiClient = stripComments(read('agent_core/src/main/ets/aiphone/runtime/MapsApiClient.ets'));
  const composioConfig = read('agent_core/src/main/ets/composio/ComposioConfig.ets');
  const composioClient = read('agent_core/src/main/ets/composio/ComposioSessionClient.ets');
  const composioDynamic = read('agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets');
  const conversationContext = read('agent_core/src/main/ets/agent/ConversationContext.ets');
  const agentMessage = stripComments(read('agent_core/src/main/ets/agent/message/AgentMessage.ets'));
  const messageBus = stripComments(read('agent_core/src/main/ets/agent/message/LinkedMessageBus.ets'));
  const leaderAgent = stripComments(read('agent_core/src/main/ets/agent/leader/LeaderAgent.ets'));
  const dataAgent = stripComments(read('agent_core/src/main/ets/agent/data/DataAgent.ets'));
  const uiAgent = stripComments(read('agent_core/src/main/ets/agent/ui/UiAgent.ets'));
  const actionCatalog = stripComments(read('agent_core/src/main/ets/agent/action/ActionCatalog.ets'));
  const actionPlanRunner = stripComments(read('agent_core/src/main/ets/agent/action/ActionPlanRunner.ets'));
  const jsonPointer = stripComments(read('agent_core/src/main/ets/agent/action/JsonPointer.ets'));
  const actionAgent = stripComments(read('agent_core/src/main/ets/agent/action/ActionAgent.ets'));
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

  const forbiddenHotelTools = ['hotel.book', 'hotel.create', 'hotel.status', 'hotel.cancel'];
  assert(hasStructuredHotelGateway(runtimeGateway), 'structured hotel gateway export exists');
  assert(hasHotelSearchActions(runtimeDefinitions), 'hotel search declares detail navigation and conditional call actions');
  assert(hasSystemIntentDefinition(runtimeDefinitions, 'hotel.navigate'), 'hotel navigation is a system intent');
  assert(hasSystemIntentDefinition(runtimeDefinitions, 'hotel.call'), 'hotel call is a system intent');
  assert(
    forbiddenHotelTools.every((toolId) => !uniqueIds.has(toolId) && !runtimeUniqueIds.has(toolId)),
    'hotel transaction tools are absent from both registries'
  );
  assert(hasHotelRolesOnBus(hotelRuntime), 'HotelAgentRuntime assigns all four roles to one broadcast bus');
  assert(hasConditionalHotelButtons(hotelA2ui, hotelActions), 'HotelToolA2ui derives buttons only from structured coordinates and verified contact fields');
  assert(hotelPhoneFieldsOnlyInDetailMask(mapsApiClient), 'Google Places phone fields appear only in the hotel details field mask');
  assert(hasHotelContactLookupMasks(mapsApiClient), 'Google Places contact lookup binds POST search and GET detail field masks');
  assert(hasLegacyHotelUnknownActionRejection(runtimeGateway), 'legacy hotel gateway rejects unknown hotel actions');
  assert(hasTravelRoute(runtimeGateway), 'pre-existing non-hotel travel route remains present');

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
      hasEnumMember(agentMessageEnum, member, value),
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
      hasInterfaceField(agentEnvelope, field, type),
      `agent message envelope has ${field}`
    );
  }
  assert(/export\s+function\s+resolveJsonPointer\s*\(/.test(jsonPointer), 'JSON Pointer resolver is declared');
  assert(/export\s+function\s+setJsonPointer\s*\(/.test(jsonPointer), 'JSON Pointer setter is declared');
  assert(
    hasNamedPlanStepCap(actionPlanRunner),
    'action plans use the named five-step cap'
  );
  assert(
    hasRegisteredActionExecutorDependency(actionAgent),
    'Action Agent injects and stores RegisteredActionExecutor'
  );
  assert(!hasLiveToken(agentRuntimeSources, 'BATCH_PENDING'), 'agent runtime has no BATCH_PENDING state');
  assert(!hasLiveClass(agentRuntimeSources, 'Coordinator'), 'agent runtime has no Coordinator class');
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

verifyArchitectureVerifier();
runHarBuild();
verifySourceContracts();

const failed = checks.filter((check) => !check.ok);
if (failed.length > 0) {
  console.error(`\n${failed.length} verification check(s) failed.`);
  process.exit(1);
}

console.log(`\nAIPhone Loopy backend smoke passed (${checks.length} checks).`);
