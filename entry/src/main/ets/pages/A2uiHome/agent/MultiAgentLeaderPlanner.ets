import {
  AgentMessage,
  InputUserPayload,
  LeaderActionIntent,
  LeaderDecision,
  LeaderDecisionDataTask,
  LeaderPersonaMetadata,
  LeaderPlanner,
  LeaderPlanningContext,
  LeaderRoundAction,
  LeaderSkillMetadata,
  LeaderToolMetadata,
  LeaderUiIntent,
  LocalModel,
  ToolDefinition,
  dataAgentToolDefinitions
} from '@loop/agent-core';
import { HotelLocalDateProvider, hotelSearchPlanningContract } from './HotelLeaderPlanner';

const DECISION_KEYS: string[] = [
  'dataTasks,personaId,reasonCode,requestedCapabilityIds,roundAction,skillId,uiIntent',
  'answer,dataTasks,personaId,reasonCode,requestedCapabilityIds,roundAction,skillId,uiIntent',
  'actionIntent,dataTasks,personaId,reasonCode,requestedCapabilityIds,roundAction,skillId,uiIntent',
  'actionIntent,answer,dataTasks,personaId,reasonCode,requestedCapabilityIds,roundAction,skillId,uiIntent'
];
const DATA_TASK_KEYS: string = 'allowedToolIds,goal,input,localId,required,toolId';
const UI_INTENT_KEYS: string = 'preferredDensity,purpose,requiredSections';
const ACTION_INTENT_KEYS: string = 'allowedActionIds,goal';
const ANSWER_FIELD_RULE: string = 'For roundAction answer or clarify, include answer as a non-empty string. ' +
  'For roundAction execute or legacy_handoff, omit answer.';
const LEADER_SYSTEM_PROMPT: string = 'Return exactly one JSON object and nothing else. ' +
  'Do not include Thought, markdown, or code fences. ' + ANSWER_FIELD_RULE;
const REPAIR_INSTRUCTION: string = 'Correction: previous decision rejected by strict schema. ' +
  'Return one corrected decision matching the schema exactly.';

interface JsonContainerFrame {
  object: boolean;
  expectingKey: boolean;
  keys: Set<string>;
}

export class MultiAgentLeaderPlanner implements LeaderPlanner {
  private readonly model: LocalModel;
  private readonly dataToolIds: Set<string>;
  private readonly currentLocalDate: HotelLocalDateProvider;

  constructor(model: LocalModel, currentLocalDate?: HotelLocalDateProvider) {
    this.model = model;
    this.currentLocalDate = currentLocalDate === undefined ? (): string => {
      const now = new Date();
      const month: string = (now.getMonth() + 1).toString().padStart(2, '0');
      const day: string = now.getDate().toString().padStart(2, '0');
      return now.getFullYear().toString() + '-' + month + '-' + day;
    } : currentLocalDate;
    this.dataToolIds = new Set<string>(dataAgentToolDefinitions().map(
      (definition: ToolDefinition): string => definition.toolId
    ));
    this.dataToolIds.add('dynamic.search');
  }

  async plan(
    _message: AgentMessage,
    input: InputUserPayload,
    context: LeaderPlanningContext,
    round: number = 1
  ): Promise<LeaderDecision> {
    if (!Number.isInteger(round) || round < 1 || round > 3) {
      throw new Error('LEADER_ROUND_LIMIT');
    }
    const prompt: string = this.prompt(input, context, round);
    const output: string = await this.model.complete(
      prompt,
      undefined,
      LEADER_SYSTEM_PROMPT
    );
    try {
      return this.parseDecision(output, context);
    } catch (_error) {
      const repaired: string = await this.model.complete(
        prompt + '\n' + REPAIR_INSTRUCTION,
        undefined,
        LEADER_SYSTEM_PROMPT
      );
      return this.parseDecision(repaired, context);
    }
  }

  private parseDecision(output: string, context: LeaderPlanningContext): LeaderDecision {
    const trimmed: string = output.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      throw new Error('Leader planner requires exactly one JSON object.');
    }
    let parsed: Object;
    try {
      parsed = JSON.parse(trimmed) as Object;
    } catch (_error) {
      throw new Error('Leader planner requires exactly one JSON object.');
    }
    if (this.hasDuplicateObjectKeys(trimmed)) {
      throw new Error('Leader planner JSON contains duplicate object keys.');
    }
    return this.decision(parsed, context);
  }

  private hasDuplicateObjectKeys(json: string): boolean {
    const frames: JsonContainerFrame[] = [];
    for (let index = 0; index < json.length; index++) {
      const character: string = json[index];
      if (character === '{' || character === '[') {
        frames.push({
          object: character === '{',
          expectingKey: character === '{',
          keys: new Set<string>()
        });
        continue;
      }
      if (character === '}' || character === ']') {
        frames.pop();
        continue;
      }
      if (character === ',') {
        if (frames.length > 0 && frames[frames.length - 1].object) {
          frames[frames.length - 1].expectingKey = true;
        }
        continue;
      }
      if (character !== '"') {
        continue;
      }
      let end: number = index + 1;
      let escaped: boolean = false;
      while (end < json.length) {
        const next: string = json[end];
        if (escaped) {
          escaped = false;
        } else if (next === '\\') {
          escaped = true;
        } else if (next === '"') {
          break;
        }
        end++;
      }
      const frame: JsonContainerFrame | undefined = frames.length === 0 ? undefined :
        frames[frames.length - 1];
      if (frame !== undefined && frame.object && frame.expectingKey) {
        const key: string = JSON.parse(json.substring(index, end + 1)) as string;
        if (frame.keys.has(key)) {
          return true;
        }
        frame.keys.add(key);
        frame.expectingKey = false;
      }
      index = end;
    }
    return false;
  }

  private prompt(input: InputUserPayload, context: LeaderPlanningContext, round: number): string {
    return [
      'You are the Appless Leader Agent.',
      'Return exactly one LeaderDecision JSON object.',
      'LeaderDecision schema: {"personaId":"string","skillId":"string",' +
        '"requestedCapabilityIds":["registered tool or action ID"],' +
        '"roundAction":"execute|answer|clarify|legacy_handoff","dataTasks":[' +
        '{"localId":"string","goal":"string","allowedToolIds":["string"],' +
        '"toolId":"string","input":{},"required":true}],"uiIntent":{' +
        '"purpose":"string","preferredDensity":"string","requiredSections":["string"]},' +
        '"actionIntent":{"goal":"string","allowedActionIds":["string"]} optional,' +
        '"answer":"required non-empty string for answer|clarify; omit for execute|legacy_handoff",' +
        '"reasonCode":"string"}.',
      ANSWER_FIELD_RULE,
      'Select one persona and at most one active skill.',
      'requestedCapabilityIds is mandatory, unique, and contains exact registered tool/action IDs. ' +
        'Use [] only for ordinary direct conversation that needs no tool-backed fact.',
      'Mail, weather, travel, and other capability-backed answer or clarify decisions must name ' +
        'their requested registered capability. For execute, requestedCapabilityIds must be exactly ' +
        'the unique union of every selected Data tool, allowed tool, and Action ID.',
      'Tasks in this round must be independent. Put dependent work in a later round.',
      'Never emit provider facts, action args, A2UI, credentials, or unregistered tool IDs.',
      hotelSearchPlanningContract(this.currentLocalDate()),
      'Use legacy_handoff with no tasks whenever the requested capability is not ordinary ' +
        'conversation and is unavailable or not runtime-owned.',
      'Maximum planning rounds: 3.',
      'Round: ' + round.toString(),
      'Context: ' + JSON.stringify(input),
      'Registry capabilities: ' + JSON.stringify(context.tools),
      'Runtime-owned tool IDs: ' + JSON.stringify(
        context.runtimeOwnedToolIds === undefined ? [] : context.runtimeOwnedToolIds
      ),
      'Personas: ' + JSON.stringify(context.personas)
    ].join('\n');
  }

  private decision(parsed: Object, context: LeaderPlanningContext): LeaderDecision {
    if (parsed === null || Array.isArray(parsed) ||
      DECISION_KEYS.indexOf(Object.keys(parsed).sort().join(',')) < 0) {
      throw new Error('Leader decision contains missing or unknown fields.');
    }
    const values = parsed as Record<string, Object | string | number | boolean | null | undefined>;
    const personaId = values['personaId'];
    const skillId = values['skillId'];
    const roundAction = values['roundAction'];
    const rawTasks = values['dataTasks'];
    const rawUiIntent = values['uiIntent'];
    const reasonCode = values['reasonCode'];
    const rawRequestedCapabilities = values['requestedCapabilityIds'];
    if (typeof personaId !== 'string' || personaId.trim().length === 0 ||
      typeof skillId !== 'string' ||
      !this.validRoundAction(roundAction) ||
      !Array.isArray(rawTasks) ||
      !Array.isArray(rawRequestedCapabilities) ||
      rawUiIntent === null || typeof rawUiIntent !== 'object' || Array.isArray(rawUiIntent) ||
      typeof reasonCode !== 'string' || reasonCode.trim().length === 0) {
      throw new Error('Leader decision fields are malformed.');
    }
    if (!this.validPersonaSkill(context, personaId, skillId)) {
      throw new Error('Leader persona and skill must be an exact registered pair.');
    }
    const selectedAction: LeaderRoundAction = roundAction as LeaderRoundAction;
    const tasks: LeaderDecisionDataTask[] = this.dataTasks(rawTasks as Object[], context);
    const requestedCapabilityIds: string[] = this.requestedCapabilities(
      rawRequestedCapabilities as Object[],
      context
    );
    const actionValue = values['actionIntent'];
    const actionIntent: LeaderActionIntent | null = actionValue === undefined ? null :
      this.actionIntent(actionValue, context);
    if ((selectedAction === 'execute' && tasks.length === 0 && actionIntent === null) ||
      (selectedAction !== 'execute' && tasks.length !== 0)) {
      throw new Error('Leader round action does not match its Data tasks.');
    }
    if (selectedAction === 'execute' &&
      !this.requestedCapabilitiesMatchExecution(requestedCapabilityIds, tasks, actionIntent)) {
      throw new Error('Leader requested capabilities do not exactly match its execution plan.');
    }
    const uiIntent: LeaderUiIntent = this.uiIntent(rawUiIntent);
    const answerValue = values['answer'];
    if (answerValue !== undefined &&
      (typeof answerValue !== 'string' || answerValue.trim().length === 0)) {
      throw new Error('Leader answer must be a non-empty string when present.');
    }
    if ((selectedAction === 'answer' || selectedAction === 'clarify') &&
      typeof answerValue !== 'string') {
      throw new Error('Leader answer and clarify decisions require answer text.');
    }
    const decision: LeaderDecision = {
      personaId,
      skillId,
      requestedCapabilityIds,
      roundAction: selectedAction,
      dataTasks: tasks,
      uiIntent,
      reasonCode
    };
    if (typeof answerValue === 'string') {
      decision.answer = answerValue;
    }
    if (actionIntent !== null) {
      decision.actionIntent = actionIntent;
    }
    return decision;
  }

  private requestedCapabilities(raw: Object[], context: LeaderPlanningContext): string[] {
    const result: string[] = [];
    for (let index = 0; index < raw.length; index++) {
      const value = raw[index];
      if (typeof value !== 'string' || value.trim().length === 0 ||
        result.indexOf(value) >= 0 || !this.registeredCapability(context, value)) {
        throw new Error('Leader requested capabilities must be unique registered IDs.');
      }
      result.push(value);
    }
    return result;
  }

  private registeredCapability(context: LeaderPlanningContext, id: string): boolean {
    for (let index = 0; index < context.tools.length; index++) {
      const tool = context.tools[index];
      if (tool.toolId === id || tool.actions.indexOf(id) >= 0) {
        return true;
      }
    }
    return false;
  }

  private requestedCapabilitiesMatchExecution(
    requested: string[],
    tasks: LeaderDecisionDataTask[],
    actionIntent: LeaderActionIntent | null
  ): boolean {
    const required: Set<string> = new Set<string>();
    for (let taskIndex = 0; taskIndex < tasks.length; taskIndex++) {
      required.add(tasks[taskIndex].toolId);
      for (let allowedIndex = 0; allowedIndex < tasks[taskIndex].allowedToolIds.length; allowedIndex++) {
        required.add(tasks[taskIndex].allowedToolIds[allowedIndex]);
      }
    }
    if (actionIntent !== null) {
      for (let index = 0; index < actionIntent.allowedActionIds.length; index++) {
        required.add(actionIntent.allowedActionIds[index]);
      }
    }
    if (requested.length !== required.size) {
      return false;
    }
    for (let index = 0; index < requested.length; index++) {
      if (!required.has(requested[index])) {
        return false;
      }
    }
    return true;
  }

  private dataTasks(rawTasks: Object[], context: LeaderPlanningContext): LeaderDecisionDataTask[] {
    const tasks: LeaderDecisionDataTask[] = [];
    const localIds: Set<string> = new Set<string>();
    for (let index = 0; index < rawTasks.length; index++) {
      const rawTask = rawTasks[index];
      if (rawTask === null || Array.isArray(rawTask) ||
        Object.keys(rawTask).sort().join(',') !== DATA_TASK_KEYS) {
        throw new Error('Leader Data task contains missing or unknown fields.');
      }
      const values = rawTask as Record<string, Object | string | number | boolean | null | undefined>;
      const localId = values['localId'];
      const goal = values['goal'];
      const allowedToolIds = values['allowedToolIds'];
      const toolId = values['toolId'];
      const input = values['input'];
      const required = values['required'];
      if (typeof localId !== 'string' || localId.trim().length === 0 || localIds.has(localId) ||
        typeof goal !== 'string' || goal.trim().length === 0 ||
        !Array.isArray(allowedToolIds) || allowedToolIds.length === 0 ||
        typeof toolId !== 'string' || toolId.trim().length === 0 ||
        input === null || typeof input !== 'object' || Array.isArray(input) ||
        typeof required !== 'boolean') {
        throw new Error('Leader Data task fields must be non-empty and unique.');
      }
      const allowed: string[] = this.allowedReadTools(allowedToolIds as Object[], context);
      if (allowed.indexOf(toolId) < 0 || this.readTool(context, toolId) === null) {
        throw new Error('Leader Data task selected a tool outside its read-only allowlist.');
      }
      localIds.add(localId);
      tasks.push({
        localId,
        goal,
        allowedToolIds: allowed,
        toolId,
        input,
        required
      });
    }
    return tasks;
  }

  private allowedReadTools(rawIds: Object[], context: LeaderPlanningContext): string[] {
    const ids: string[] = [];
    for (let index = 0; index < rawIds.length; index++) {
      const value = rawIds[index];
      if (typeof value !== 'string' || value.trim().length === 0 || ids.indexOf(value) >= 0 ||
        this.readTool(context, value) === null) {
        throw new Error('Leader Data task allowlist must contain unique registered read tools.');
      }
      ids.push(value);
    }
    return ids;
  }

  private uiIntent(raw: Object): LeaderUiIntent {
    if (Object.keys(raw).sort().join(',') !== UI_INTENT_KEYS) {
      throw new Error('Leader UI intent contains missing or unknown fields.');
    }
    const values = raw as Record<string, Object | string | number | boolean | null | undefined>;
    const purpose = values['purpose'];
    const preferredDensity = values['preferredDensity'];
    const requiredSections = values['requiredSections'];
    if (typeof purpose !== 'string' || purpose.trim().length === 0 ||
      typeof preferredDensity !== 'string' || preferredDensity.trim().length === 0 ||
      !Array.isArray(requiredSections)) {
      throw new Error('Leader UI intent fields are malformed.');
    }
    return {
      purpose,
      preferredDensity,
      requiredSections: this.uniqueStrings(requiredSections as Object[], 'Leader UI sections')
    };
  }

  private actionIntent(
    raw: Object | string | number | boolean | null | undefined,
    context: LeaderPlanningContext
  ): LeaderActionIntent {
    if (raw === null || raw === undefined || typeof raw !== 'object' || Array.isArray(raw) ||
      Object.keys(raw).sort().join(',') !== ACTION_INTENT_KEYS) {
      throw new Error('Leader action intent contains missing or unknown fields.');
    }
    const values = raw as Record<string, Object | string | number | boolean | null | undefined>;
    const goal = values['goal'];
    const allowedActionIds = values['allowedActionIds'];
    if (typeof goal !== 'string' || goal.trim().length === 0 ||
      !Array.isArray(allowedActionIds) || allowedActionIds.length === 0) {
      throw new Error('Leader action intent fields are malformed.');
    }
    const ids: string[] = this.uniqueStrings(allowedActionIds as Object[], 'Leader action allowlist');
    const registered: string[] = [];
    for (let toolIndex = 0; toolIndex < context.tools.length; toolIndex++) {
      const actions = context.tools[toolIndex].actions;
      for (let actionIndex = 0; actionIndex < actions.length; actionIndex++) {
        if (registered.indexOf(actions[actionIndex]) < 0) {
          registered.push(actions[actionIndex]);
        }
      }
    }
    for (let index = 0; index < ids.length; index++) {
      if (registered.indexOf(ids[index]) < 0) {
        throw new Error('Leader action allowlist contains an unregistered action ID.');
      }
    }
    return { goal, allowedActionIds: ids };
  }

  private uniqueStrings(values: Object[], label: string): string[] {
    const result: string[] = [];
    for (let index = 0; index < values.length; index++) {
      const value = values[index];
      if (typeof value !== 'string' || value.trim().length === 0 || result.indexOf(value) >= 0) {
        throw new Error(label + ' must contain unique non-empty strings.');
      }
      result.push(value);
    }
    return result;
  }

  private validPersonaSkill(context: LeaderPlanningContext, personaId: string, skillId: string): boolean {
    for (let personaIndex = 0; personaIndex < context.personas.length; personaIndex++) {
      const persona: LeaderPersonaMetadata = context.personas[personaIndex];
      if (persona.personaId !== personaId) {
        continue;
      }
      if (skillId.length === 0) {
        return true;
      }
      for (let skillIndex = 0; skillIndex < persona.activeSkills.length; skillIndex++) {
        const skill: LeaderSkillMetadata = persona.activeSkills[skillIndex];
        if (skill.skillId === skillId && skill.status === 'active') {
          return true;
        }
      }
      return false;
    }
    return false;
  }

  private readTool(context: LeaderPlanningContext, toolId: string): LeaderToolMetadata | null {
    if (!this.dataToolIds.has(toolId)) {
      return null;
    }
    for (let index = 0; index < context.tools.length; index++) {
      const tool = context.tools[index];
      if (tool.toolId === toolId && tool.riskLevel === 'read') {
        return tool;
      }
    }
    return null;
  }

  private validRoundAction(value: Object | string | number | boolean | null | undefined): boolean {
    return value === 'execute' || value === 'answer' || value === 'clarify' || value === 'legacy_handoff';
  }
}
