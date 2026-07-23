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

function personaSkillToolIds(source) {
  const frontmatter = source.match(/^---\s*\n([\s\S]*?)\n---/);
  if (frontmatter === null) {
    return [];
  }
  const tools = [];
  let inTools = false;
  for (const line of frontmatter[1].split(/\r?\n/)) {
    if (/^tools:\s*$/.test(line)) {
      inTools = true;
      continue;
    }
    if (inTools && /^  -\s+/.test(line)) {
      tools.push(line.replace(/^  -\s+/, '').trim());
      continue;
    }
    if (inTools && /^\S/.test(line)) {
      break;
    }
  }
  return tools;
}

function exactPersonaSkillToolIds(source, expectedIds) {
  const actualIds = personaSkillToolIds(source);
  return actualIds.length === expectedIds.length &&
    new Set(actualIds).size === actualIds.length &&
    expectedIds.every((toolId) => actualIds.includes(toolId));
}

function personaSkillBody(source) {
  const frontmatter = source.match(/^---\s*\n[\s\S]*?\n---\s*\n/);
  if (frontmatter === null) {
    return '';
  }
  return source.substring(frontmatter[0].length).replace(/<!--[\s\S]*?-->/g, '');
}

function stripComments(source) {
  return source.replace(/\/\*[\s\S]*?\*\/|\/\/[^\r\n]*/g, '');
}

function stripStrings(source) {
  return source.replace(/'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|`(?:\\.|[^`\\])*`/g, "''");
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
  sources.push(read('agent_core/src/main/ets/agent/MessageDrivenAgent.ets'));
  for (const name of ['action', 'data', 'leader', 'message', 'ui']) {
    visit(resolve(repoRoot, 'agent_core/src/main/ets/agent', name));
  }
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

function maskNonCode(source) {
  return source.replace(
    /'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|`(?:\\.|[^`\\])*`|\/(?:\\.|[^/\\\r\n])+\/[dgimsuvy]*|\/\/[^\r\n]*|\/\*[\s\S]*?\*\//g,
    (token) => token.replace(/[^\r\n]/g, ' ')
  );
}

function hasProductionCanarySubmitTimeout(source) {
  const code = maskNonCode(source);
  const declaration = 'const options: MultiAgentCanaryOptions = {';
  const optionsStart = code.indexOf(declaration);
  if (optionsStart < 0) {
    return false;
  }
  const bodyStart = code.indexOf('{', optionsStart);
  let depth = 0;
  let parentheses = 0;
  let brackets = 0;
  let propertyStart = bodyStart + 1;
  let directProperties = 0;
  let exactProperties = 0;
  for (let index = bodyStart; index < code.length; index++) {
    const char = code.charAt(index);
    if (char === '{') {
      depth++;
      continue;
    }
    if (char === '}') {
      depth--;
      if (depth === 0) {
        return directProperties === 1 && exactProperties === 1;
      }
      continue;
    }
    if (char === '(') {
      parentheses++;
      continue;
    }
    if (char === ')') {
      parentheses--;
      continue;
    }
    if (char === '[') {
      brackets++;
      continue;
    }
    if (char === ']') {
      brackets--;
      continue;
    }
    if (depth === 1 && parentheses === 0 && brackets === 0 && char === ',') {
      propertyStart = index + 1;
      continue;
    }
    if (depth !== 1 || parentheses !== 0 || brackets !== 0 ||
      code.slice(propertyStart, index).trim().length > 0 ||
      !/^submitTimeoutMs(?![A-Za-z0-9_$])\s*:/.test(code.slice(index))) {
      continue;
    }
    directProperties++;
    if (/^submitTimeoutMs\s*:\s*45000\s*[,}]/.test(code.slice(index))) {
      exactProperties++;
    }
    index += 'submitTimeoutMs'.length - 1;
  }
  return false;
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

function toolDefinitionStringField(source, toolId, field) {
  const body = toolDefinitionBody(source, toolId);
  const match = body.match(new RegExp(`\\b${escapeRegex(field)}\\s*:\\s*'([^']*)'`));
  return match === null ? '' : match[1];
}

function toolDefinitionStringArrayField(source, toolId, field) {
  const body = toolDefinitionBody(source, toolId);
  const match = body.match(new RegExp(`\\b${escapeRegex(field)}\\s*:\\s*\\[([\\s\\S]*?)\\]`));
  return match === null ? [] : [...match[1].matchAll(/'([^']*)'/g)].map((item) => item[1]);
}

function toolDefinitionContract(source, toolId) {
  return {
    toolId: toolDefinitionStringField(source, toolId, 'toolId'),
    domain: toolDefinitionStringField(source, toolId, 'domain'),
    intent: toolDefinitionStringField(source, toolId, 'intent'),
    riskLevel: toolDefinitionStringField(source, toolId, 'riskLevel'),
    backendPriority: toolDefinitionStringArrayField(source, toolId, 'backendPriority'),
    authModes: toolDefinitionStringArrayField(source, toolId, 'authModes'),
    inputSchema: toolDefinitionStringField(source, toolId, 'inputSchema'),
    outputSchema: toolDefinitionStringField(source, toolId, 'outputSchema'),
    a2uiComponent: toolDefinitionStringField(source, toolId, 'a2uiComponent'),
    actions: toolDefinitionStringArrayField(source, toolId, 'actions')
  };
}

function toolDefinitionContractsMatch(left, right, toolId) {
  return JSON.stringify(toolDefinitionContract(left, toolId)) ===
    JSON.stringify(toolDefinitionContract(right, toolId));
}

const calendarUpdateOptionalSchema =
  'eventId?:string,query?:string,timeMin?:string,timeMax?:string,title?:string,' +
  'start?:string,end?:string,timezone?:string,calendarId?:string';

function hasOptionalCalendarUpdateSchema(source) {
  return toolDefinitionStringField(source, 'calendar.event.update', 'inputSchema') ===
    calendarUpdateOptionalSchema;
}

function hasSystemIntentDefinition(source, toolId) {
  const body = toolDefinitionBody(source, toolId);
  return body.length > 0 && /backendPriority:\s*\[\s*'system_intent'\s*\]/.test(body);
}

function liveDeclarationBody(source, declaration) {
  return declarationBody(stripComments(source), declaration);
}

function hasBoundedLeaderModelCalls(source) {
  const live = stripComments(source);
  const plan = declarationBody(live, 'async plan(');
  const prompt = declarationBody(live, 'private prompt(');
  const bounded = declarationBody(live, 'private completeBounded(');
  const modelCalls = live.match(/this\.model\.complete\s*\(/g) ?? [];
  return /const\s+MAX_LEADER_TOOL_CATALOG_CHARS\s*:\s*number\s*=\s*64000\s*;/.test(live) &&
    /const\s+MAX_LEADER_PROMPT_CHARS\s*:\s*number\s*=\s*100000\s*;/.test(live) &&
    prompt.includes('toolCatalog.length > MAX_LEADER_TOOL_CATALOG_CHARS') &&
    prompt.includes("throw new Error('LEADER_TOOL_CATALOG_LIMIT')") &&
    bounded.includes('prompt.length > MAX_LEADER_PROMPT_CHARS') &&
    bounded.includes("throw new Error('LEADER_PROMPT_LIMIT')") &&
    bounded.includes('return this.model.complete(prompt, undefined, LEADER_SYSTEM_PROMPT)') &&
    plan.includes('await this.completeBounded(prompt)') &&
    plan.includes('await this.completeBounded(prompt +') &&
    plan.includes('correction') &&
    modelCalls.length === 1;
}

function hasStructuredHotelGateway(source) {
  return liveDeclarationBody(source, 'export async function callStructuredHotelTool').length > 0;
}

function hasHotelSearchActions(source) {
  return /actions:\s*\[\s*'hotel.detail'\s*,\s*'hotel.navigate'\s*\]/
    .test(toolDefinitionBody(source, 'hotel.search'));
}

function hasHotelDetailBookingAction(source) {
  return /actions:\s*\[\s*'hotel\.booking\.open'\s*\]/
    .test(toolDefinitionBody(source, 'hotel.detail'));
}

function hasHotelBookingBackend(source) {
  return /backendPriority:\s*\[\s*'web_session'\s*\]/
    .test(toolDefinitionBody(source, 'hotel.booking.open'));
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
  const body = stripStrings(liveDeclarationBody(source, 'constructor(options: HotelAgentRuntimeOptions)'));
  return [
    ['leader', 'LeaderAgent'],
    ['data', 'DataAgent'],
    ['ui', 'UiAgent'],
    ['action', 'ActionAgent']
  ].every(([field, role]) =>
    new RegExp(`this\\.${field}\\s*=\\s*new\\s+${role}\\s*\\(\\s*this\\.bus\\b`).test(body));
}

function verifyArchitectureVerifier() {
  const exactSkillFixture = `---
name: test
tools:
  - food.search
  - maps.place.search
status: active
---
Use Google Maps for explicit provider requests.`;
  const wrongIndentSkillFixture = exactSkillFixture.replace('  - maps.place.search', '    - maps.place.search');
  const extraToolSkillFixture = exactSkillFixture.replace(
    '  - maps.place.search',
    '  - maps.place.search\n  - gmail.message.send'
  );
  const commentOnlyInstructionFixture = exactSkillFixture.replace(
    'Use Google Maps for explicit provider requests.',
    '<!-- Use Google Maps for explicit provider requests. -->'
  );
  assert(
    exactPersonaSkillToolIds(exactSkillFixture, ['food.search', 'maps.place.search']),
    'verifier accepts exact persona skill tool IDs with runtime indentation'
  );
  assert(
    !exactPersonaSkillToolIds(wrongIndentSkillFixture, ['food.search', 'maps.place.search']),
    'verifier rejects persona skill tools with indentation ignored by runtime parser'
  );
  assert(
    !exactPersonaSkillToolIds(extraToolSkillFixture, ['food.search', 'maps.place.search']),
    'verifier rejects an extra persona skill tool'
  );
  assert(
    personaSkillBody(commentOnlyInstructionFixture).indexOf('Google Maps') < 0,
    'verifier ignores comment-only persona skill instructions'
  );

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

  const canaryOptionsFixture = (property) => `
    const options: MultiAgentCanaryOptions = {
      model: model,
      ${property}
    };
  `;
  assert(
    hasProductionCanarySubmitTimeout(canaryOptionsFixture('submitTimeoutMs: 45000,')),
    'verifier accepts a live direct production timeout'
  );
  assert(
    !hasProductionCanarySubmitTimeout(canaryOptionsFixture('// submitTimeoutMs: 45000,')),
    'verifier rejects a commented production timeout decoy'
  );
  assert(
    !hasProductionCanarySubmitTimeout(canaryOptionsFixture("label: 'submitTimeoutMs: 45000',")),
    'verifier rejects a string production timeout decoy'
  );
  assert(
    !hasProductionCanarySubmitTimeout(canaryOptionsFixture('nested: { submitTimeoutMs: 45000 },')),
    'verifier rejects a nested production timeout decoy'
  );
  assert(
    !hasProductionCanarySubmitTimeout(canaryOptionsFixture('not_submitTimeoutMs: 45000,')),
    'verifier rejects a longer identifier production timeout decoy'
  );
  assert(
    !hasProductionCanarySubmitTimeout(canaryOptionsFixture(
      'settingsFingerprint: /submitTimeoutMs: 45000,/.source,'
    )),
    'verifier rejects a regex expression production timeout decoy'
  );
  assert(
    !hasProductionCanarySubmitTimeout(canaryOptionsFixture('settingsFingerprint: fingerprint,')),
    'verifier rejects a missing production timeout'
  );
  assert(
    !hasProductionCanarySubmitTimeout(canaryOptionsFixture('submitTimeoutMs: 30000,')),
    'verifier rejects a wrong production timeout'
  );
  assert(
    !hasProductionCanarySubmitTimeout(canaryOptionsFixture(
      'submitTimeoutMs: 45000,\n      submitTimeoutMs: 45000,'
    )),
    'verifier rejects duplicate direct production timeouts'
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
      actions: ['hotel.detail', 'hotel.navigate']
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
        const decoy = 'this.leader = new LeaderAgent(this.bus, planner); this.data = new DataAgent(this.bus, executor); this.ui = new UiAgent(this.bus, renderer, writer); this.action = new ActionAgent(this.bus, catalog, registered);';
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

  const registryContract = `{
    toolId: 'gmail.message.send', domain: 'gmail', intent: 'gmail.message.send',
    riskLevel: 'confirm_required', backendPriority: ['oauth_api'], authModes: ['oauth'],
    inputSchema: 'mailReplyCommand', outputSchema: 'mailReplyOperationResult',
    a2uiComponent: 'GenericToolResults', actions: []
  }`;
  const driftedRegistryContract = registryContract.replace("riskLevel: 'confirm_required'", "riskLevel: 'blocked'");
  assert(
    toolDefinitionContractsMatch(registryContract, registryContract, 'gmail.message.send'),
    'verifier accepts semantically equal tool definitions'
  );
  assert(
    !toolDefinitionContractsMatch(registryContract, driftedRegistryContract, 'gmail.message.send'),
    'verifier rejects tool-definition field drift'
  );
  const optionalCalendarContract = `{
    toolId: 'calendar.event.update', inputSchema: '${calendarUpdateOptionalSchema}'
  }`;
  const requiredCalendarContract = optionalCalendarContract.replace('start?:string', 'start:string');
  assert(hasOptionalCalendarUpdateSchema(optionalCalendarContract), 'verifier accepts optional Calendar update fields');
  assert(!hasOptionalCalendarUpdateSchema(requiredCalendarContract), 'verifier rejects required Calendar update fields');
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
  const a2uiHome = read('entry/src/main/ets/pages/A2uiHome/Index.ets');
  const protocol = read('agent_core/src/main/ets/a2ui/A2uiProtocol.ets');
  const llmProvider = read('agent_core/src/main/ets/model/LlmProvider.ets');
  const openAiModel = read('agent_core/src/main/ets/model/OpenAiCompatibleModel.ets');
  const aiphoneA2ui = read('agent_core/src/main/ets/aiphone/AiphoneA2ui.ets');
  const definitions = read('agent_core/src/main/ets/aiphone/AiphoneToolDefinitions.ets');
  const executor = read('agent_core/src/main/ets/aiphone/AiphoneToolExecutor.ets');
  const backend = read('agent_core/src/main/ets/aiphone/LoopBackend.ets');
  const canaryRuntime = read('entry/src/main/ets/pages/A2uiHome/agent/MultiAgentCanaryRuntime.ets');
  const canaryLeaderPlanner = read('entry/src/main/ets/pages/A2uiHome/agent/MultiAgentLeaderPlanner.ets');
  const liveCanaryLeaderPlanner = stripComments(canaryLeaderPlanner);
  const runner = read('agent_core/src/main/ets/agent/ReActAgentRunner.ets');
  const index = stripComments(read('agent_core/Index.ets'));
  const indexExports = parseIndexExports(index);
  const agentRuntimeSources = readAgentRuntimeSources();
  const runtimeDefinitions = read('agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets');
  const runtimeGateway = read('agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets');
  const localGmailTool = liveDeclarationBody(runtimeGateway, 'async function callLocalGmailTool');
  const registeredGmailReply = liveDeclarationBody(a2uiHome, 'private async executeRegisteredGmailReply');
  const gmailNormalizer = read('agent_core/src/main/ets/aiphone/runtime/GmailToolNormalizer.ets');
  const gmailStructuredNormalizer = liveDeclarationBody(
    gmailNormalizer,
    'export function gmailSearchStructuredDataFromResults'
  );
  const hotelA2ui = stripComments(read('agent_core/src/main/ets/aiphone/runtime/HotelToolA2ui.ets'));
  const hotelActions = stripComments(read('agent_core/src/main/ets/aiphone/runtime/HotelActions.ets'));
  const hotelRuntime = stripComments(read('entry/src/main/ets/pages/A2uiHome/agent/HotelAgentRuntime.ets'));
  const composioConfig = read('agent_core/src/main/ets/composio/ComposioConfig.ets');
  const composioClient = read('agent_core/src/main/ets/composio/ComposioSessionClient.ets');
  const composioDynamic = read('agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets');
  const conversationContext = read('agent_core/src/main/ets/agent/ConversationContext.ets');
  const agentMessage = stripComments(read('agent_core/src/main/ets/agent/message/AgentMessage.ets'));
  const messageBus = stripComments(read('agent_core/src/main/ets/agent/message/LinkedMessageBus.ets'));
  const leaderAgent = stripComments(read('agent_core/src/main/ets/agent/leader/LeaderAgent.ets'));
  const leaderOwnership = stripComments(
    read('agent_core/src/main/ets/agent/leader/LeaderCapabilityOwnership.ets')
  );
  const dataAgent = stripComments(read('agent_core/src/main/ets/agent/data/DataAgent.ets'));
  const uiAgent = stripComments(read('agent_core/src/main/ets/agent/ui/UiAgent.ets'));
  const actionCatalog = stripComments(read('agent_core/src/main/ets/agent/action/ActionCatalog.ets'));
  const actionPlanRunner = stripComments(read('agent_core/src/main/ets/agent/action/ActionPlanRunner.ets'));
  const jsonPointer = stripComments(read('agent_core/src/main/ets/agent/action/JsonPointer.ets'));
  const actionAgent = stripComments(read('agent_core/src/main/ets/agent/action/ActionAgent.ets'));
  const messageDrivenAgent = stripComments(read('agent_core/src/main/ets/agent/MessageDrivenAgent.ets'));
  const layoutMerger = stripComments(read('agent_core/src/main/ets/a2ui/A2uiLayoutMerger.ets'));
  const a2uiRunner = stripComments(read('agent_core/src/main/ets/a2ui/A2uiAgentRunner.ets'));
  const a2uiModel = stripComments(read('agent_core/src/main/ets/a2ui/OpenAiA2uiModel.ets'));
  const conversationStore = read('agent_core/src/main/ets/agent/ConversationStore.ets');
  const skillParser = read('agent_core/src/main/ets/skill/SkillMarkdownParser.ets');
  const skillStore = read('agent_core/src/main/ets/skill/SkillStore.ets');
  const foodSearchSkill = read(
    'entry/src/main/resources/rawfile/personas/food_companion/skills/food-search/SKILL.md'
  );
  const mediaSearchSkill = read(
    'entry/src/main/resources/rawfile/personas/entertainment_companion/skills/media-search/SKILL.md'
  );
  const travelPlanningSkill = read(
    'entry/src/main/resources/rawfile/personas/travel_companion/skills/travel-planning/SKILL.md'
  );
  const workAssistantSkill = read(
    'entry/src/main/resources/rawfile/personas/work_companion/skills/work-assistant/SKILL.md'
  );
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
  const externalUrlOpener = liveDeclarationBody(a2uiHome, 'private async openExternalUrl');

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
  assert(
    externalUrlOpener.includes("const schemeMatch = /^([A-Za-z][A-Za-z0-9+.-]*):/.exec(url);") &&
      externalUrlOpener.includes("allowedSchemes.indexOf(scheme) < 0") &&
      externalUrlOpener.indexOf("allowedSchemes.indexOf(scheme) < 0") <
        externalUrlOpener.indexOf('await context.startAbility') &&
      externalUrlOpener.includes('code=SCHEME_NOT_ALLOWED') &&
      externalUrlOpener.includes("const urlMeta = ' scheme=' + scheme + ' chars=' + url.length.toString();") &&
      externalUrlOpener.includes("aiLogInfo('[AIPhone][A2uiHomeOpenUrl] ok=true' + urlMeta);") &&
      externalUrlOpener.includes("aiLogError('[AIPhone][A2uiHomeOpenUrl] ok=false' + urlMeta") &&
      !externalUrlOpener.includes("url=' + url") &&
      !externalUrlOpener.includes("message=' + businessError.message"),
    'external URL opener rejects unapproved schemes and redacts the URI payload'
  );
  assertContains(
    a2uiHome,
    "allowedSchemes: string[] = ['https']",
    'external URL opener defaults ordinary web and OAuth links to HTTPS'
  );
  assertContains(
    a2uiHome,
    "this.openExternalUrl(uri, ['petalmaps'])",
    'hotel opener only authorizes Petal Maps for navigation'
  );
  assert(
    hasProductionCanarySubmitTimeout(a2uiHome),
    'production multi-agent turn deadline is 45000 ms'
  );
  assert(!a2uiHome.includes("this.openExternalUrl(uri, ['tel'"), 'hotel opener does not authorize dialer schemes');
  assert(
    !a2uiHome.includes("aiLogInfo('[AIPhone][LuckinWechatPayOpen] url=' + payUrl)") &&
      a2uiHome.includes("aiLogInfo('[AIPhone][LuckinWechatPayOpen] chars=' + payUrl.length.toString())"),
    'payment handoff logs redact the URL payload'
  );

  const ids = [...definitions.matchAll(/toolId:\s*'([^']+)'/g)].map((match) => match[1]);
  const runtimeIds = [...runtimeDefinitions.matchAll(/toolId:\s*'([^']+)'/g)].map((match) => match[1]);
  const uniqueIds = new Set(ids);
  const runtimeUniqueIds = new Set(runtimeIds);
  const publicOnlyToolIds = ids.filter((id) => !runtimeUniqueIds.has(id));
  const runtimeOnlyToolIds = runtimeIds.filter((id) => !uniqueIds.has(id));
  const semanticDriftToolIds = ids.filter((id) =>
    runtimeUniqueIds.has(id) && !toolDefinitionContractsMatch(definitions, runtimeDefinitions, id));
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
  assert(
    semanticDriftToolIds.length === 0,
    'public and runtime tool registries align semantically',
    `drift=[${semanticDriftToolIds.join(', ')}]`
  );
  assert(
    hasOptionalCalendarUpdateSchema(definitions) && hasOptionalCalendarUpdateSchema(runtimeDefinitions),
    'Calendar update schema keeps lookup and destination fields optional'
  );

  const forbiddenHotelTools = ['hotel.book', 'hotel.create', 'hotel.status', 'hotel.cancel'];
  assert(hasStructuredHotelGateway(runtimeGateway), 'structured hotel gateway export exists');
  assert(hasHotelSearchActions(runtimeDefinitions), 'hotel search exposes only detail and navigation actions');
  assert(hasHotelDetailBookingAction(runtimeDefinitions), 'hotel detail exposes one booking action');
  assert(hasHotelBookingBackend(runtimeDefinitions), 'hotel booking uses the web session backend');
  assert(hasSystemIntentDefinition(runtimeDefinitions, 'hotel.navigate'), 'hotel navigation is a system intent');
  assert(
    forbiddenHotelTools.every((toolId) => !uniqueIds.has(toolId) && !runtimeUniqueIds.has(toolId)),
    'hotel transaction tools are absent from both registries'
  );
  assert(hasHotelRolesOnBus(hotelRuntime), 'HotelAgentRuntime assigns all four roles to one broadcast bus');
  assert(
    (hotelA2ui.includes("id: 'hotel.booking.open'") || hotelActions.includes("id: 'hotel.booking.open'")) &&
      !hotelA2ui.includes("row('第三方预订（离开 Appless）'"),
    'hotel A2UI uses a registered booking action instead of a raw URL row'
  );
  assert(!existsSync(resolve(runtimeDir, 'HotelContactLookup.ets')), 'hotel contact lookup file is absent');
  assert(!runtimeGateway.includes('HotelContactLookup') && !runtimeGateway.includes('enrichHotelContacts'),
    'hotel gateway is RollingGo-only');
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
  assert(
    gmailStructuredNormalizer.length > 0 &&
      !/A2ui|gmailComposioThreadResults|Card/.test(gmailStructuredNormalizer) &&
      !gmailNormalizer.includes("from './GmailToolA2ui'"),
    'Gmail structured normalization has no A2UI or card round trip'
  );
  assertContains(runtimeGateway, 'async function callLocalMediaTool', 'runtime includes media video execution');
  assertContains(runtimeGateway, 'async function callLocalYouTubeTool', 'runtime includes YouTube execution');
  assertContains(runtimeGateway, 'async function callLocalCalendarTool', 'runtime includes Calendar execution');
  assertContains(runtimeGateway, 'async function callLocalMapsTool', 'runtime includes Maps execution');
  assertContains(runtimeGateway, 'async function callLocalSocialHubTool', 'runtime includes SocialHub execution');
  assertContains(runtimeGateway, 'async function buildDynamicToolJsonl', 'runtime includes dynamic tool execution');
  assertContains(runtimeGateway, 'callComposioDynamic', 'dynamic.search tries Composio fallback');
  assert(
    localGmailTool.length > 0 && !localGmailTool.includes('sendConfiguredMailReply'),
    'runtime Gmail fallback cannot invoke the reply provider'
  );
  assertContains(registeredGmailReply, 'await sendConfiguredMailReply(command)', 'registered Gmail action owns provider execution');
  assertContains(composioDynamic, "if (fixedToolId === 'gmail.reply.send') return 'GMAIL_REPLY_TO_THREAD';", 'Gmail reply send pins the exact Composio write tool');
  assertContains(runtimeGateway, '不会模拟 Gmail 邮件', 'runtime does not simulate Gmail');
  assertContains(runtimeGateway, "toolId === 'social.reply.draft'", 'runtime drafts SocialHub replies instead of sending');

  assertContains(backend, 'allToolDefinitions()', 'LoopBackend registers AIPhone definitions');
  assertContains(backend, "registry.register(new AiphoneTool(\n      'dynamic.search'", 'LoopBackend registers dynamic.search');
  assertContains(backend, 'splitJsonl(jsonl)', 'LoopBackend splits AIPhone JSONL');
  assertContains(backend, 'this.callbacks.onA2uiJsonl?.(line)', 'LoopBackend emits AIPhone JSONL lines');
  assertContains(backend, 'runAiphoneTool(', 'LoopBackend delegates tool execution to AIPhone executor');
  assertContains(backend, 'a2uiLineCount === 0', 'LoopBackend only emits final surface when no tool UI exists');
  assertContains(backend, 'aiphoneInfoJsonl', 'LoopBackend emits A2UI for plain final answers');
  assertContains(runtimeDefinitions, 'Composio-backed app/toolkit requests', 'registry describes Composio dynamic routing');
  assertContains(runtimeDefinitions, 'Keep the query focused to the relevant 6-10 OR terms', 'registry preserves Gmail academic query expansion guidance');
  assertContains(runtimeDefinitions, 'toolPlanningDescriptionForToolId', 'registry owns the shared planning description projection');
  assertContains(backend, 'toolPlanningDescriptionForToolId(toolId)', 'LoopBackend consumes the registry planning projection');
  assert(!backend.includes('private describeAiphoneTool'), 'LoopBackend has no duplicate private planning table');
  assertContains(canaryRuntime, 'toolPlanningDescriptionForToolId(definition.toolId)', 'multi-agent canary consumes the registry planning projection');
  assertContains(canaryRuntime, "definition.toolId !== 'gmail.message.send'", 'multi-agent planner excludes direct Gmail send');
  assertContains(canaryRuntime, 'domain: definition.domain', 'multi-agent planner projects registry domains');
  assertContains(canaryRuntime, 'registeredBackends: definition.backendPriority.slice()', 'multi-agent planner projects cloned registered backend candidates');
  assertContains(leaderAgent, 'registeredBackends: tool.registeredBackends.slice()', 'Leader context clone preserves registered backend candidates');
  assertContains(
    leaderOwnership,
    'sourceDeclaresAction(context, capabilityId)',
    'shared Leader ownership accepts source-declared dual-role actions'
  );
  assertContains(
    liveCanaryLeaderPlanner,
    'leaderIsActionCapability(context, ids[index])',
    'model planner uses shared Action ownership'
  );
  assertContains(
    leaderAgent,
    'leaderIsActionCapability(this.planningContext, actionId)',
    'runtime Leader uses shared Action ownership'
  );
  assertContains(
    leaderAgent,
    'trustedCurrentLocalDate = this.currentLocalDate()',
    'Leader captures one host date snapshot for each planning round'
  );
  assertContains(
    leaderAgent,
    'decision.normalizationCurrentLocalDate === trustedCurrentLocalDate',
    'Leader rejects a planner date that differs from host authority'
  );
  assertContains(
    leaderAgent,
    'normalizer(input, decision.dataTasks[index], trustedCurrentLocalDate)',
    'Leader normalizes Data inputs with the trusted date snapshot'
  );
  assertContains(
    canaryRuntime,
    'currentLocalDateProvider: options.currentLocalDate',
    'multi-agent runtime delegates date authority to Leader'
  );
  assertContains(
    canaryRuntime,
    'calendarNow(request.currentLocalDate)',
    'virtual Calendar actions consume the Leader date snapshot'
  );
  assert(
    !canaryRuntime.includes('new MemoryIntentResolver(options.currentLocalDate)'),
    'virtual Action resolver does not read the date provider again'
  );
  assert(hasBoundedLeaderModelCalls(canaryLeaderPlanner), 'every Leader model call uses the structural prompt and catalog bounds');
  assert(
    !hasBoundedLeaderModelCalls(
      canaryLeaderPlanner.replace(
        'await this.completeBounded(prompt + \'\\n\' + correction)',
        'await this.model.complete(prompt + \'\\n\' + correction)'
      )
    ),
    'verifier rejects a repair model call that bypasses the prompt bound'
  );
  assert(
    !hasBoundedLeaderModelCalls(
      canaryLeaderPlanner.replace(
        'await this.completeBounded(prompt)',
        'await this.model.complete(prompt)'
      )
    ),
    'verifier rejects an initial model call that bypasses the prompt bound'
  );
  assert(
    !hasBoundedLeaderModelCalls(
      canaryLeaderPlanner.replace(
        'toolCatalog.length > MAX_LEADER_TOOL_CATALOG_CHARS',
        'false'
      )
    ),
    'verifier rejects removal of the live tool catalog bound'
  );
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
    ['./src/main/ets/agent/leader/LeaderCapabilityOwnership', [
      'leaderActionCapabilityIds',
      'leaderDataCapabilityIds',
      'leaderIsActionCapability',
      'leaderIsDataCapability',
      'leaderIsExplicitActionOwner'
    ], 'Leader capability ownership exports'],
    ['./src/main/ets/agent/data/DataAgent', ['DataAgent'], 'Data Agent exports'],
    ['./src/main/ets/agent/data/DataAgentTypes', ['*'], 'Data Agent types export'],
    ['./src/main/ets/agent/ui/UiAgent', ['UiAgent'], 'UI Agent exports'],
    ['./src/main/ets/agent/ui/UiAgentTypes', ['*'], 'UI Agent types export'],
    ['./src/main/ets/agent/action/ActionCatalog', ['ActionCatalog'], 'Action catalog exports'],
    ['./src/main/ets/agent/action/ActionCatalogTypes', ['*'], 'Action catalog types export'],
    ['./src/main/ets/agent/action/ActionOfferTypes', ['*'], 'Action offer types export'],
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
  assert(/export\s+abstract\s+class\s+MessageDrivenAgent\b/.test(messageDrivenAgent), 'single subscriber base is public');
  assert(!index.includes('ReactLinkedMessageBus'), 'public API has no second ReAct message bus');
  assert(
    leaderOwnership.includes('toolMetadata(context, capabilityId) === null') &&
      leaderOwnership.includes('!DATA_OWNER_IDS.has(capabilityId)') &&
      leaderOwnership.includes('!leaderIsExplicitActionOwner(context, capabilityId)'),
    'source-declared actions still require metadata and a Data or explicit Action owner'
  );
  assertContains(
    leaderOwnership,
    'leaderIsActionCapability(context, actionId)',
    'Leader prompt filters renderer-local actions through executable ownership'
  );
  assert(!index.includes('ReactLeaderAgent'), 'public API has no second ReAct leader');
  assert(!index.includes('UIMakerAgent'), 'public API has no UIMaker compatibility agent');
  assertContains(index, 'ReActRunOptions', 'public API exposes role-specific ReAct options');

  const obsoleteAgentFiles = [
    'AgentMessageTypes.ets',
    'CreateUiTaskTool.ets',
    'LeaderAgent.ets',
    'LeaderAgentPrompt.ets',
    'LeaderToolRegistry.ets',
    'LoopAgentPrompt.ets',
    'MessageBus.ets',
    'ReActAgent.ets',
    'StructuredMessageDrivenAgent.ets',
    'UIMakerAgent.ets',
    'UIMakerAgentPrompt.ets',
    'UIMakerToolRegistry.ets'
  ];
  assert(
    obsoleteAgentFiles.every((name) => !existsSync(resolve(repoRoot, 'agent_core/src/main/ets/agent', name))),
    'obsolete second agent runtime files are absent'
  );
  for (const [role, source] of [
    ['LeaderAgent', leaderAgent],
    ['DataAgent', dataAgent],
    ['UiAgent', uiAgent],
    ['ActionAgent', actionAgent]
  ]) {
    assertContains(source, `class ${role} extends MessageDrivenAgent`, `${role} uses the single subscriber base`);
  }

  const agentMessageEnum = declarationBody(agentMessage, 'export enum AgentMessageType');
  const agentEnvelope = declarationBody(agentMessage, 'export interface AgentMessage');
  for (const [member, value] of [
    ['INPUT_USER', 'INPUT.USER'],
    ['TASK_CREATE_UI', 'TASK.CREATE.UI'],
    ['TASK_CREATE_DATA', 'TASK.CREATE.DATA'],
    ['TASK_RESULT_UI', 'TASK.RESULT.UI'],
    ['TASK_RESULT_DATA', 'TASK.RESULT.DATA'],
    ['TASK_ERROR', 'TASK.ERROR'],
    ['ACTION_PLAN_DRAFT', 'ACTION.PLAN.DRAFT'],
    ['ACTION_OFFERS_READY', 'ACTION.OFFERS.READY'],
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
  assertContains(dataAgent, 'authorizer(task)', 'Data Agent authorizes exact tasks before execution');
  assertContains(dataAgent, 'result.toolId === task.toolId && result.outputSchema === task.outputSchema',
    'Data Agent validates result identity and schema');
  assertContains(actionAgent, 'this.catalog.validatePlacement(sourceToolId, candidate.actionId, args)',
    'Action Agent derives only catalog-approved offers');
  assertContains(actionAgent, 'type: AgentMessageType.ACTION_OFFERS_READY',
    'Action Agent publishes immutable offers');
  assertContains(actionAgent, 'type: AgentMessageType.ACTION_PLAN_DRAFT',
    'Action Agent binds Leader action plan drafts');
  assertContains(uiAgent, 'message.type === AgentMessageType.ACTION_OFFERS_READY',
    'UI Agent joins data with Action Agent offers');
  assertContains(hotelRuntime, 'mergeA2uiLayout(baseline, candidate, surfaceId, offers)',
    'hotel UI keeps deterministic output as the constrained layout baseline');
  assertContains(layoutMerger, 'return baselineJsonl', 'invalid model layouts fall back exactly');
  assertContains(layoutMerger, "exactKeys(reference, ['offerId'])",
    'model layout actions can reference only immutable offer ids');
  assertContains(a2uiRunner, 'implements UiLayoutPlanner', 'existing A2UI runner is reused as the layout planner');
  assertContains(a2uiModel, 'Output exactly one compact JSON line', 'A2UI model is constrained to one layout envelope');
  assertContains(backend, 'new ReActAgentRunner', 'legacy scene backend remains a real ReAct runner caller');
  assert(!agentRuntimeSources.includes('ReActAgentRunner'), 'four-agent runtime does not create a second ReAct execution loop');
  assert(!hasLiveToken(agentRuntimeSources, 'BATCH_PENDING'), 'agent runtime has no BATCH_PENDING state');
  assert(!hasLiveClass(agentRuntimeSources, 'Coordinator'), 'agent runtime has no Coordinator class');
  assertContains(conversationStore, 'MAX_STORED_TURNS: number = 50', 'conversation store keeps the last 50 turns');
  assertContains(conversationStore, 'JSON.parse(raw)', 'conversation store parses persisted JSON defensively');
  assertContains(conversationStore, 'role !== ConversationRole.USER && role !== ConversationRole.ASSISTANT', 'conversation store ignores unknown roles');
  assertContains(conversationStore, 'return new ConversationContext()', 'conversation store falls back to an empty conversation');
  assertContains(skillParser, 'export function parseSkillMarkdown', 'skill markdown parser is present');
  assertContains(skillStore, 'if (pathExists(targetPath))', 'bundled skills do not overwrite sandbox files');
  assertContains(skillStore, 'await ensureBundledSkillsInSandbox(context)', 'sandbox skills are initialized before loading');
  for (const [skillName, source, expectedIds] of [
    ['food search', foodSearchSkill, [
      'food.search', 'luckin.order.preview', 'memory.update',
      'maps.place.search', 'maps.place.details'
    ]],
    ['media search', mediaSearchSkill, [
      'media.video.search', 'media.aggregate.search', 'youtube.video.search',
      'youtube.mine.playlists', 'youtube.mine.subscriptions', 'worldcup.open', 'memory.update'
    ]],
    ['travel planning', travelPlanningSkill, [
      'travel.search', 'train.search', 'flight.search', 'memory.update'
    ]],
    ['work assistant', workAssistantSkill, [
      'mail.search', 'mail.thread.read', 'gmail.mail.search', 'gmail.thread.read',
      'mail.draft.create', 'gmail.draft.create', 'gmail.draft.apply',
      'calendar.events.search', 'calendar.event.create', 'calendar.event.update',
      'calendar.event.delete', 'memory.update'
    ]]
  ]) {
    assert(
      exactPersonaSkillToolIds(source, expectedIds),
      `${skillName} skill has the exact reviewed tool set`,
      `actual ${JSON.stringify(personaSkillToolIds(source))}`
    );
  }
  assert(
    personaSkillBody(foodSearchSkill).includes('Google Maps'),
    'food search skill tells the model to honor an explicit Google Maps provider request'
  );
  for (const [skillName, source] of [
    ['food search', foodSearchSkill],
    ['media search', mediaSearchSkill],
    ['travel planning', travelPlanningSkill],
    ['work assistant', workAssistantSkill]
  ]) {
    const toolIds = personaSkillToolIds(source);
    for (const restrictedActionId of [
      'gmail.message.send',
      'hotel.navigate',
      'hotel.booking.open'
    ]) {
      assert(
        !toolIds.includes(restrictedActionId),
        `${skillName} keeps ${restrictedActionId} on the exact-surface action path`
      );
    }
  }
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
