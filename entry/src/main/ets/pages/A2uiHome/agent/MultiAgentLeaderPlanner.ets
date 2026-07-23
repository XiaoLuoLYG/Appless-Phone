import {
  AgentMessage,
  InputUserPayload,
  LeaderActionIntent,
  LeaderDataTaskInputNormalizer,
  LeaderDecision,
  LeaderDecisionDataTask,
  LeaderPersonaMetadata,
  LeaderPlanner,
  LeaderPlanningSignal,
  LeaderPlanningContext,
  LeaderRoundAction,
  LeaderSkillMetadata,
  LeaderToolMetadata,
  LeaderUiIntent,
  LocalModel,
  MAX_LEADER_DATA_TASKS_PER_ROUND,
  ObservationDigest,
  leaderActionCapabilityIds,
  leaderDataCapabilityIds,
  leaderInputHasEntityAuthority,
  leaderIsActionCapability,
  leaderIsDataCapability,
  leaderSameRoundDependencyConsumerTasksLackEntityInput,
  leaderSameRoundDependencyConsumerTaskToolIds,
  leaderSameRoundDependencyProducerTaskToolIds,
  leaderTasksHaveSameRoundDependency
} from '@loop/agent-core';
import { HotelLocalDateProvider, hotelSearchPlanningContract } from './HotelLeaderPlanner';

const DECISION_KEYS: string[] = [
  'dataTasks,personaId,requestedCapabilityIds,roundAction,skillId,uiIntent',
  'answer,dataTasks,personaId,requestedCapabilityIds,roundAction,skillId,uiIntent',
  'actionIntent,dataTasks,personaId,requestedCapabilityIds,roundAction,skillId,uiIntent',
  'actionIntent,answer,dataTasks,personaId,requestedCapabilityIds,roundAction,skillId,uiIntent'
];
const DATA_TASK_KEYS: string = 'allowedToolIds,goal,input,localId,required,toolId';
const UI_INTENT_KEYS: string = 'preferredDensity,purpose,requiredSections';
const ACTION_INTENT_KEYS: string = 'allowedActionIds,goal';
const ANSWER_FIELD_RULE: string = 'For roundAction answer or clarify, include answer as a non-empty string. ' +
  'For roundAction execute or legacy_handoff, omit answer.';
const REASON_CODE_FIELD_RULE: string = 'Omit reasonCode. The host creates deterministic diagnostic reason metadata.';
const FULL_DECISION_CONTRACT: string =
  'Every decision, including a correction or repair, must include personaId, skillId, requestedCapabilityIds, ' +
  'roundAction, dataTasks, and uiIntent. For answer or clarify, set dataTasks to [] and include a non-empty answer. ' +
  'uiIntent must contain exactly purpose, preferredDensity, and requiredSections. Choose purpose, preferredDensity, ' +
  'and requiredSections from the current user request and real recentObservations when present; never omit them.';
const REQUEST_SCOPE_CONTRACT: string =
  'Request scope contract: The current user request defines a closed capability and source set. ' +
  'Persona, active Skill, saved Memory, defaults, and available tools may shape behavior but must not add an ' +
  'unrequested capability, provider, account, source, or channel. Every Data task and Action must directly serve ' +
  'an explicit current-user request or a real dependency from prior current-turn observations. When the user names ' +
  'platforms or sources, select only those sources; do not add channels. X or Slack inbox/message requests use ' +
  'social.feed.search, and mail.search may run in parallel only when the current request also explicitly asks for ' +
  'mail or email. Explicit multi-domain requests remain valid and should keep independent tasks in the same round. ' +
  'Before returning JSON, silently scope-check every requestedCapabilityId, Data task, allowed tool, and Action ' +
  'against that closed set; do not output the check.';
const LEADER_SYSTEM_PROMPT: string = 'Return exactly one JSON object and nothing else. ' +
  'Do not include Thought, markdown, or code fences. ' + ANSWER_FIELD_RULE + ' ' + REASON_CODE_FIELD_RULE + ' ' +
  REQUEST_SCOPE_CONTRACT + ' ' + FULL_DECISION_CONTRACT;
const REPAIR_INSTRUCTION: string = 'Correction: previous decision rejected by strict schema. ' +
  'Return one corrected decision matching the schema exactly. ' + FULL_DECISION_CONTRACT;
const COMPLETED_TOOL_REUSE_ERROR: string = 'LEADER_COMPLETED_TOOL_REUSE';
const UNBOUND_LATER_TOOL_ERROR: string = 'LEADER_UNBOUND_LATER_TOOL';
const SAME_ROUND_DEPENDENCY_ERROR: string = 'LEADER_SAME_ROUND_DEPENDENCY';
const OVERLAPPING_VIDEO_TOOLS_ERROR: string = 'LEADER_OVERLAPPING_VIDEO_TOOLS';
const TASK_INPUT_INVALID_ERROR: string = 'LEADER_TASK_INPUT_INVALID';
const ACTION_OWNED_DATA_TASK_ERROR: string = 'LEADER_ACTION_OWNED_DATA_TASK';
const SKILL_CAPABILITY_ERROR: string = 'LEADER_SKILL_CAPABILITY_VIOLATION';
const REPAIR_SCOPE_INVALID_ERROR: string = 'LEADER_REPAIR_SCOPE_INVALID';
const COMPLETED_TOOL_REPAIR_INSTRUCTION: string =
  'Correction: previous decision repeated a completed Data tool. ' +
  'Every completed Data tool is terminal for this turn. Return answer or clarify with a truthful summary, ' +
  'or execute only a different tool that depends on real prior output. Base any terminal summary only on real ' +
  'recentObservations; do not reschedule a completed tool or invent provider facts. ' + FULL_DECISION_CONTRACT;
const UNBOUND_LATER_TOOL_REPAIR_INSTRUCTION: string =
  'Correction: LEADER_UNBOUND_LATER_TOOL. A later-round Data task did not contain any real entity reference ' +
  'from a successful or partial earlier round. Return answer or clarify from existing observations, or execute ' +
  'only tasks whose own input contains an exact earlier entity reference. Base any terminal summary only on real ' +
  'recentObservations; do not reschedule a completed tool or invent provider facts. ' + FULL_DECISION_CONTRACT;
const OVERLAPPING_VIDEO_TOOLS_REPAIR_INSTRUCTION: string =
  'Correction: LEADER_OVERLAPPING_VIDEO_TOOLS. media.video.search already covers both YouTube and Bilibili. ' +
  'For a request naming both sources, return exactly one media.video.search Data task with sources ' +
  '["youtube","bilibili"]; do not also schedule youtube.video.search. ' + FULL_DECISION_CONTRACT;
const TASK_INPUT_REPAIR_INSTRUCTION: string =
  'Correction: LEADER_TASK_INPUT_INVALID. Change only dataTasks[].input so every selected tool receives its exact ' +
  'registered input shape. Keep personaId, skillId, requestedCapabilityIds, roundAction, each Data task localId, ' +
  'goal, allowedToolIds, toolId and required value, uiIntent, actionIntent, answer, and Data task order exactly ' +
  'unchanged. The only permitted difference is inside dataTasks[].input. ' + FULL_DECISION_CONTRACT;
const CALENDAR_DELETE_SELECTION_CONTRACT: string =
  'Calendar delete contract: for a natural-language delete without a real Event ID on the current surface, ' +
  'select calendar.events.search as the read-first Data task. Do not select calendar.event.delete as a zero-Data ' +
  'Action or include a delete actionIntent in the search round. The host offers the existing delete confirmation ' +
  'only after one exact provider result.';
const CALENDAR_UPDATE_SELECTION_CONTRACT: string =
  'Calendar update contract: for a natural-language update or move without a real Event ID on the current surface, ' +
  'select calendar.events.search as the read-first Data task. Do not select calendar.event.update as a zero-Data ' +
  'Action or include an update actionIntent in the search round. The host offers the existing update confirmation ' +
  'only after one exact provider result.';
const ACTION_OWNED_DATA_TASK_REPAIR_INSTRUCTION: string =
  'Correction: LEADER_ACTION_OWNED_DATA_TASK. An Action-owned capability was placed in dataTasks. ' +
  'Keep the same requested capability and current-user intent. Remove Action-owned IDs from dataTasks and put ' +
  'them in actionIntent.allowedActionIds. If the Action requires a real ID, add only the necessary independent ' +
  'Data-owned read task and use its real result in a later planning round; never invent an ID or replace the ' +
  'requested capability. The Host validates ownership but does not rewrite planning semantics. ' +
  FULL_DECISION_CONTRACT;
const SKILL_CAPABILITY_REPAIR_INSTRUCTION: string =
  'Correction: LEADER_SKILL_CAPABILITY_VIOLATION. Keep personaId and the complete requested capability set ' +
  'unchanged. Choose an active skill only when that one skill declares every requested Data and Action ' +
  'capability in its toolIds. Otherwise set skillId to the empty string. Do not change, add, remove, or move ' +
  'any capability while correcting skillId. ' + FULL_DECISION_CONTRACT;
const MAX_COMPLETED_TOOL_IDS: number = 8;
const MAX_LEADER_TOOL_CATALOG_CHARS: number = 64000;
const MAX_LEADER_PROMPT_CHARS: number = 100000;
const TRAVEL_SELECTION_CONTRACT: string =
  'Travel selection contract: Explicitly naming both flight/航班/飞机 and train/高铁/火车 takes precedence over broad words ' +
  'such as 比较. In that case, select flight.search and train.search as two independent tasks in the same round. ' +
  'Use flight.search only when the user explicitly asks only for flight/航班/飞机. Use train.search only when the ' +
  'user explicitly asks only for train/高铁/火车. For requests that do not explicitly name those concrete modes, ' +
  'broad or multimodal wording such as 出行方案, 怎么去, or 综合比较 means exactly ' +
  'one travel.search Data task. Preserve route fields and relative date wording such as 明天 in the selected ' +
  'task input; do not drop or silently replace them.';
const VIDEO_SELECTION_CONTRACT: string =
  'Video selection contract: A video-only request that explicitly names both YouTube and Bilibili means exactly ' +
  'one media.video.search Data task with sources ["youtube","bilibili"]. Never schedule youtube.video.search in ' +
  'the same decision as media.video.search. Use youtube.video.search only for explicit YouTube-only requests. ' +
  'Use media.video.search for Bilibili-only or multi-source video requests. Other independent tools may still run ' +
  'in parallel when the user actually requested them.';
const C10_C11_SELECTION_CONTRACT: string =
  'C10/C11 selection contract: Explicit X/Twitter public post searches use x.post.search. X or Slack inbox/message ' +
  'requests use social.feed.search. A generic request to 点一杯咖啡 uses food.search. Stable preference text such as ' +
  '我只喝瑞幸咖啡, 以后只喝..., or an explicit remember-preference request uses only memory.update. Use ' +
  'luckin.order.preview only for an explicit Luckin/Ruixing order request with a concrete product or specification, ' +
  'for example 帮我点一杯瑞幸生椰拿铁，半糖少冰. A Luckin product or price question uses food.search; ' +
  'luckin.order.status is only for an explicit existing-order status or pickup-code request. Do not infer ordering ' +
  'or order status from generic coffee, a product/price question, or saved preference text.';
const SOCIAL_SELECTION_CONTRACT: string =
  'Social selection contract: Reddit/LinkedIn/Instagram/public community reading -> ' +
  'social.community.search. Standalone public post draft -> social.post.preview. ' +
  'social.reply.draft only after a selected real inbox/feed item. social.post.preview is preview-only; ' +
  'never infer or invoke a provider publish write from the preview request.';
const OBSERVATION_REUSE_CONTRACT: string =
  'Never schedule a listed tool again in a later round, regardless of success, partial, empty, or error status. ' +
  'Data Agent owns same-tool adapter fallback and retry. A different later-round tool is allowed only when it ' +
  'requires real prior output. Otherwise answer truthfully from the observations.';
const DATA_SCOPE_CONTRACT: string =
  'Explicit provider, app, account, source, or independently named source scope belongs in round 1. ' +
  'Put multiple independent sources in the same round. After round 1, every Data task input must contain an ' +
  'exact entity reference from a successful or partial earlier current-turn observation.';

interface JsonContainerFrame {
  object: boolean;
  expectingKey: boolean;
  keys: Set<string>;
}

interface LeaderRepairScope {
  requestedCapabilityIds: string[];
  dataCapabilityIds: string[];
  actionCapabilityIds: string[];
  roundAction: LeaderRoundAction;
}

export class MultiAgentLeaderPlanner implements LeaderPlanner {
  private readonly model: LocalModel;
  private readonly currentLocalDate: HotelLocalDateProvider;
  private readonly dataTaskInputNormalizer: LeaderDataTaskInputNormalizer | null;

  constructor(
    model: LocalModel,
    currentLocalDate?: HotelLocalDateProvider,
    dataTaskInputNormalizer?: LeaderDataTaskInputNormalizer
  ) {
    this.model = model;
    this.currentLocalDate = currentLocalDate === undefined ? (): string => {
      const now = new Date();
      const month: string = (now.getMonth() + 1).toString().padStart(2, '0');
      const day: string = now.getDate().toString().padStart(2, '0');
      return now.getFullYear().toString() + '-' + month + '-' + day;
    } : currentLocalDate;
    this.dataTaskInputNormalizer = dataTaskInputNormalizer === undefined ?
      null : dataTaskInputNormalizer;
  }

  async plan(
    message: AgentMessage,
    input: InputUserPayload,
    context: LeaderPlanningContext,
    round: number = 1,
    signal?: LeaderPlanningSignal,
    trustedCurrentLocalDate?: string
  ): Promise<LeaderDecision> {
    if (!Number.isInteger(round) || round < 1 || round > 3) {
      throw new Error('LEADER_ROUND_LIMIT');
    }
    const currentLocalDate: string = trustedCurrentLocalDate === undefined ?
      this.currentLocalDate() : trustedCurrentLocalDate;
    const prompt: string = this.prompt(message, input, context, round, currentLocalDate);
    const output: string = await this.completeBounded(prompt);
    let sameRoundProducerTaskToolIds: string[] = [];
    let sameRoundConsumerTaskToolIds: string[] = [];
    let rejectedDecision: LeaderDecision | null = null;
    try {
      const decision: LeaderDecision = this.parseDecision(output, context);
      rejectedDecision = decision;
      sameRoundProducerTaskToolIds = leaderSameRoundDependencyProducerTaskToolIds(decision.dataTasks);
      sameRoundConsumerTaskToolIds = leaderSameRoundDependencyConsumerTaskToolIds(decision.dataTasks);
      this.rejectSkillCapabilityViolation(decision, context);
      this.rejectOverlappingVideoTools(decision);
      this.normalizeSameRoundDependency(
        decision,
        sameRoundProducerTaskToolIds,
        sameRoundConsumerTaskToolIds
      );
      this.rejectSameRoundDependency(decision);
      this.rejectCompletedToolReuse(
        decision,
        this.currentTurnCompletedToolIds(message, input, context, round)
      );
      this.rejectUnboundLaterTool(
        decision,
        this.currentTurnDependencyObservations(message, input, round),
        round
      );
      this.validateDecisionInputs(input, decision, currentLocalDate);
      decision.normalizationCurrentLocalDate = currentLocalDate;
      return decision;
    } catch (error) {
      if (error instanceof Error && error.message === SAME_ROUND_DEPENDENCY_ERROR) {
        throw error;
      }
      if (signal === undefined || !signal()) {
        const failure: Error = error instanceof Error ? error :
          new Error('Leader decision failed strict validation.');
        throw failure;
      }
      const frozenScope: LeaderRepairScope | null = this.repairScope(output);
      if (frozenScope === null) {
        const failure: Error = error instanceof Error ? error :
          new Error(REPAIR_SCOPE_INVALID_ERROR);
        throw failure;
      }
      let correction: string = REPAIR_INSTRUCTION;
      if (error instanceof Error && error.message === COMPLETED_TOOL_REUSE_ERROR) {
        correction = COMPLETED_TOOL_REPAIR_INSTRUCTION;
      } else if (error instanceof Error && error.message === UNBOUND_LATER_TOOL_ERROR) {
        correction = UNBOUND_LATER_TOOL_REPAIR_INSTRUCTION;
      } else if (error instanceof Error && error.message === OVERLAPPING_VIDEO_TOOLS_ERROR) {
        correction = OVERLAPPING_VIDEO_TOOLS_REPAIR_INSTRUCTION;
      } else if (error instanceof Error && error.message === TASK_INPUT_INVALID_ERROR) {
        correction = TASK_INPUT_REPAIR_INSTRUCTION + '\nRejected decision: ' + output;
      } else if (error instanceof Error && error.message === ACTION_OWNED_DATA_TASK_ERROR) {
        correction = ACTION_OWNED_DATA_TASK_REPAIR_INSTRUCTION + '\nRejected decision: ' + output;
      } else if (error instanceof Error && error.message === SKILL_CAPABILITY_ERROR) {
        correction = SKILL_CAPABILITY_REPAIR_INSTRUCTION + '\nRejected decision: ' + output;
      }
      const actionOwnedRepair: boolean = error instanceof Error &&
        error.message === ACTION_OWNED_DATA_TASK_ERROR;
      const allowsTerminalExecutionDrop: boolean = error instanceof Error &&
        (error.message === COMPLETED_TOOL_REUSE_ERROR ||
          error.message === UNBOUND_LATER_TOOL_ERROR);
      correction += '\nFrozen requestedCapabilityIds: ' +
        JSON.stringify(frozenScope.requestedCapabilityIds) +
        '\nFrozen Data-position capability IDs: ' +
        JSON.stringify(frozenScope.dataCapabilityIds) +
        '\nFrozen actionIntent-position capability IDs: ' +
        JSON.stringify(frozenScope.actionCapabilityIds);
      correction += actionOwnedRepair ?
        '\nAction-owned repair freeze: preserve personaId, skillId, requestedCapabilityIds, roundAction, answer, ' +
          'uiIntent, each non-Action Data task, all existing Action IDs, and the original request intent exactly. ' +
          'Move exactly one Action-only capability ID from Data positions to actionIntent.allowedActionIds. ' +
          'Do not add, remove, reorder, or change any other field or capability.' :
        allowsTerminalExecutionDrop ?
        '\nA corrected answer or clarify decision may clear both execution-position sets to empty. ' +
          'It must preserve requestedCapabilityIds exactly and must not introduce any new Data or Action capability.' :
        '\nThe corrected decision must preserve all three frozen sets exactly and must not move a ' +
          'capability between Data and actionIntent positions.';
      const repaired: string = await this.completeBounded(prompt + '\n' + correction);
      try {
        const repairedScope: LeaderRepairScope | null = this.repairScope(repaired);
        if (repairedScope === null || (actionOwnedRepair ?
          !this.sameActionOwnedRepair(output, repaired, context, frozenScope, repairedScope) :
          !this.sameRepairScope(frozenScope, repairedScope, allowsTerminalExecutionDrop))) {
          throw new Error(REPAIR_SCOPE_INVALID_ERROR);
        }
        const repairedDecision: LeaderDecision = this.parseDecision(repaired, context);
        if (error instanceof Error && error.message === SKILL_CAPABILITY_ERROR &&
          (rejectedDecision === null || !this.skillOnlyRepair(rejectedDecision, repairedDecision))) {
          throw new Error(SKILL_CAPABILITY_ERROR);
        }
        this.rejectSkillCapabilityViolation(repairedDecision, context);
        if (error instanceof Error && error.message === TASK_INPUT_INVALID_ERROR &&
          (rejectedDecision === null || !this.inputOnlyRepair(rejectedDecision, repairedDecision))) {
          throw new Error(TASK_INPUT_INVALID_ERROR);
        }
        this.rejectOverlappingVideoTools(repairedDecision);
        this.normalizeSameRoundDependency(
          repairedDecision,
          leaderSameRoundDependencyProducerTaskToolIds(repairedDecision.dataTasks),
          leaderSameRoundDependencyConsumerTaskToolIds(repairedDecision.dataTasks)
        );
        this.rejectSameRoundDependency(repairedDecision);
        this.rejectCompletedToolReuse(
          repairedDecision,
          this.currentTurnCompletedToolIds(message, input, context, round)
        );
        this.rejectUnboundLaterTool(
          repairedDecision,
          this.currentTurnDependencyObservations(message, input, round),
          round
        );
        this.validateDecisionInputs(input, repairedDecision, currentLocalDate);
        repairedDecision.normalizationCurrentLocalDate = currentLocalDate;
        return repairedDecision;
      } catch (repairError) {
        if (error instanceof Error && error.message === TASK_INPUT_INVALID_ERROR) {
          throw new Error(TASK_INPUT_INVALID_ERROR);
        }
        const failure: Error = repairError instanceof Error ? repairError :
          new Error('Leader decision repair failed strict validation.');
        throw failure;
      }
    }
  }

  private validateDecisionInputs(
    input: InputUserPayload,
    decision: LeaderDecision,
    currentLocalDate: string
  ): void {
    const normalizer: LeaderDataTaskInputNormalizer | null = this.dataTaskInputNormalizer;
    if (normalizer === null) {
      return;
    }
    try {
      for (let index = 0; index < decision.dataTasks.length; index++) {
        normalizer(input, decision.dataTasks[index], currentLocalDate);
      }
    } catch (_error) {
      throw new Error(TASK_INPUT_INVALID_ERROR);
    }
  }

  private inputOnlyRepair(original: LeaderDecision, repaired: LeaderDecision): boolean {
    if (original.personaId !== repaired.personaId ||
      original.skillId !== repaired.skillId ||
      original.roundAction !== repaired.roundAction ||
      original.answer !== repaired.answer ||
      !this.sameStrings(original.requestedCapabilityIds, repaired.requestedCapabilityIds) ||
      original.uiIntent.purpose !== repaired.uiIntent.purpose ||
      original.uiIntent.preferredDensity !== repaired.uiIntent.preferredDensity ||
      !this.sameStrings(original.uiIntent.requiredSections, repaired.uiIntent.requiredSections) ||
      !this.sameActionIntent(original.actionIntent, repaired.actionIntent) ||
      original.dataTasks.length !== repaired.dataTasks.length) {
      return false;
    }
    for (let index = 0; index < original.dataTasks.length; index++) {
      const first: LeaderDecisionDataTask = original.dataTasks[index];
      const second: LeaderDecisionDataTask = repaired.dataTasks[index];
      if (first.localId !== second.localId ||
        first.goal !== second.goal ||
        first.toolId !== second.toolId ||
        first.required !== second.required ||
        !this.sameStrings(first.allowedToolIds, second.allowedToolIds)) {
        return false;
      }
    }
    return true;
  }

  private skillOnlyRepair(original: LeaderDecision, repaired: LeaderDecision): boolean {
    if (original.personaId !== repaired.personaId ||
      original.roundAction !== repaired.roundAction ||
      original.answer !== repaired.answer ||
      original.reasonCode !== repaired.reasonCode ||
      !this.sameStrings(original.requestedCapabilityIds, repaired.requestedCapabilityIds) ||
      original.uiIntent.purpose !== repaired.uiIntent.purpose ||
      original.uiIntent.preferredDensity !== repaired.uiIntent.preferredDensity ||
      !this.sameStrings(original.uiIntent.requiredSections, repaired.uiIntent.requiredSections) ||
      !this.sameActionIntent(original.actionIntent, repaired.actionIntent) ||
      original.dataTasks.length !== repaired.dataTasks.length) {
      return false;
    }
    for (let index = 0; index < original.dataTasks.length; index++) {
      const first: LeaderDecisionDataTask = original.dataTasks[index];
      const second: LeaderDecisionDataTask = repaired.dataTasks[index];
      if (first.localId !== second.localId ||
        first.goal !== second.goal ||
        first.toolId !== second.toolId ||
        first.required !== second.required ||
        !this.sameStrings(first.allowedToolIds, second.allowedToolIds) ||
        !this.sameJsonValue(first.input, second.input)) {
        return false;
      }
    }
    return true;
  }

  private sameJsonValue(
    original: Object | string | number | boolean | null | undefined,
    repaired: Object | string | number | boolean | null | undefined
  ): boolean {
    if (original === null || repaired === null ||
      typeof original !== 'object' || typeof repaired !== 'object') {
      return original === repaired;
    }
    if (Array.isArray(original) || Array.isArray(repaired)) {
      if (!Array.isArray(original) || !Array.isArray(repaired) || original.length !== repaired.length) {
        return false;
      }
      const firstItems = original as Object[];
      const secondItems = repaired as Object[];
      for (let index = 0; index < firstItems.length; index++) {
        if (!this.sameJsonValue(firstItems[index], secondItems[index])) {
          return false;
        }
      }
      return true;
    }
    const firstKeys: string[] = Object.keys(original).sort();
    const secondKeys: string[] = Object.keys(repaired).sort();
    if (!this.sameStrings(firstKeys, secondKeys)) {
      return false;
    }
    const firstRecord = original as
      Record<string, Object | string | number | boolean | null | undefined>;
    const secondRecord = repaired as
      Record<string, Object | string | number | boolean | null | undefined>;
    for (let index = 0; index < firstKeys.length; index++) {
      const key: string = firstKeys[index];
      if (!this.sameJsonValue(firstRecord[key], secondRecord[key])) {
        return false;
      }
    }
    return true;
  }

  private sameActionIntent(
    original: LeaderActionIntent | undefined,
    repaired: LeaderActionIntent | undefined
  ): boolean {
    if (original === undefined || repaired === undefined) {
      return original === undefined && repaired === undefined;
    }
    return original.goal === repaired.goal &&
      this.sameStrings(original.allowedActionIds, repaired.allowedActionIds);
  }

  private sameStrings(original: string[], repaired: string[]): boolean {
    if (original.length !== repaired.length) {
      return false;
    }
    for (let index = 0; index < original.length; index++) {
      if (original[index] !== repaired[index]) {
        return false;
      }
    }
    return true;
  }

  private sameRepairScope(
    original: LeaderRepairScope,
    repaired: LeaderRepairScope,
    allowsTerminalExecutionDrop: boolean
  ): boolean {
    if (!this.sameStringSet(
      original.requestedCapabilityIds,
      repaired.requestedCapabilityIds
    )) {
      return false;
    }
    if (this.sameStringSet(
      original.dataCapabilityIds,
      repaired.dataCapabilityIds
    ) && this.sameStringSet(
      original.actionCapabilityIds,
      repaired.actionCapabilityIds
    )) {
      return true;
    }
    return allowsTerminalExecutionDrop &&
      (repaired.roundAction === 'answer' || repaired.roundAction === 'clarify') &&
      repaired.dataCapabilityIds.length === 0 &&
      repaired.actionCapabilityIds.length === 0;
  }

  private sameActionOwnedRepair(
    originalOutput: string,
    repairedOutput: string,
    context: LeaderPlanningContext,
    originalScope: LeaderRepairScope,
    repairedScope: LeaderRepairScope
  ): boolean {
    const original = this.rawDecisionObject(originalOutput);
    const repaired = this.rawDecisionObject(repairedOutput);
    if (original === null || repaired === null ||
      original['personaId'] !== repaired['personaId'] ||
      original['skillId'] !== repaired['skillId'] ||
      original['roundAction'] !== repaired['roundAction'] ||
      original['answer'] !== repaired['answer'] ||
      !this.sameJsonValue(original['uiIntent'], repaired['uiIntent']) ||
      !this.sameStringSet(originalScope.requestedCapabilityIds, repairedScope.requestedCapabilityIds)) {
      return false;
    }
    const rawOriginalTasks = original['dataTasks'];
    const rawRepairedTasks = repaired['dataTasks'];
    if (!Array.isArray(rawOriginalTasks) || !Array.isArray(rawRepairedTasks)) {
      return false;
    }
    const misplacedIds: string[] = [];
    let misplacedGoal: string = '';
    const preservedTasks: LeaderDecisionDataTask[] = [];
    const originalTasks = rawOriginalTasks as Object[];
    for (let index = 0; index < originalTasks.length; index++) {
      const value: Object = originalTasks[index];
      if (value === null || typeof value !== 'object' || Array.isArray(value)) {
        return false;
      }
      const task = value as Record<string, Object | string | number | boolean | null | undefined>;
      const toolId = task['toolId'];
      const rawAllowed = task['allowedToolIds'];
      const localId = task['localId'];
      const goal = task['goal'];
      const input = task['input'];
      const required = task['required'];
      if (typeof toolId !== 'string' || typeof localId !== 'string' || typeof goal !== 'string' ||
        input === null || typeof input !== 'object' || Array.isArray(input) ||
        typeof required !== 'boolean' || !Array.isArray(rawAllowed)) {
        return false;
      }
      const allowed: string[] = [];
      const rawAllowedIds = rawAllowed as Object[];
      for (let allowedIndex = 0; allowedIndex < rawAllowedIds.length; allowedIndex++) {
        const allowedId: Object = rawAllowedIds[allowedIndex];
        if (typeof allowedId !== 'string') {
          return false;
        }
        if (this.actionOnlyCapability(context, allowedId)) {
          this.rememberScopeId(allowedId, misplacedIds);
          misplacedGoal = goal;
        } else {
          allowed.push(allowedId);
        }
      }
      if (this.actionOnlyCapability(context, toolId)) {
        this.rememberScopeId(toolId, misplacedIds);
        misplacedGoal = goal;
        continue;
      }
      preservedTasks.push({
        localId: localId,
        goal: goal,
        allowedToolIds: allowed,
        toolId: toolId,
        input: input,
        required: required
      });
    }
    if (misplacedIds.length !== 1 ||
      originalScope.requestedCapabilityIds.indexOf(misplacedIds[0]) < 0 ||
      !this.sameJsonValue(preservedTasks, rawRepairedTasks as Object[])) {
      return false;
    }
    const originalAction = original['actionIntent'];
    const repairedAction = repaired['actionIntent'];
    if (repairedAction === null || typeof repairedAction !== 'object' || Array.isArray(repairedAction)) {
      return false;
    }
    const repairedActionRecord = repairedAction as
      Record<string, Object | string | number | boolean | null | undefined>;
    if (originalAction === undefined) {
      if (repairedActionRecord['goal'] !== misplacedGoal) {
        return false;
      }
    } else {
      if (originalAction === null || typeof originalAction !== 'object' || Array.isArray(originalAction)) {
        return false;
      }
      const originalActionRecord = originalAction as
        Record<string, Object | string | number | boolean | null | undefined>;
      if (repairedActionRecord['goal'] !== originalActionRecord['goal']) {
        return false;
      }
    }
    const expectedDataIds: string[] = originalScope.dataCapabilityIds.filter(
      (toolId: string): boolean => toolId !== misplacedIds[0]
    );
    const expectedActionIds: string[] = originalScope.actionCapabilityIds.slice();
    this.rememberScopeId(misplacedIds[0], expectedActionIds);
    return this.sameStringSet(expectedDataIds, repairedScope.dataCapabilityIds) &&
      this.sameStringSet(expectedActionIds, repairedScope.actionCapabilityIds);
  }

  private actionOnlyCapability(context: LeaderPlanningContext, toolId: string): boolean {
    return !leaderIsDataCapability(context, toolId) && leaderIsActionCapability(context, toolId);
  }

  private sameStringSet(original: string[], repaired: string[]): boolean {
    if (original.length !== repaired.length) {
      return false;
    }
    for (let index = 0; index < original.length; index++) {
      if (repaired.indexOf(original[index]) < 0) {
        return false;
      }
    }
    return true;
  }

  private repairScope(output: string): LeaderRepairScope | null {
    const raw: Record<string, Object | string | number | boolean | null | undefined> | null =
      this.rawDecisionObject(output);
    if (raw === null) {
      return null;
    }
    const requested: string[] | null = this.scopeStrings(raw['requestedCapabilityIds']);
    const rawTasks = raw['dataTasks'];
    const rawRoundAction = raw['roundAction'];
    if (requested === null || !Array.isArray(rawTasks) ||
      typeof rawRoundAction !== 'string' ||
      !this.validRoundAction(rawRoundAction)) {
      return null;
    }
    const dataIds: string[] = [];
    const actionIds: string[] = [];
    const tasks: Object[] = rawTasks as Object[];
    for (let taskIndex = 0; taskIndex < tasks.length; taskIndex++) {
      const rawTask: Object = tasks[taskIndex];
      if (rawTask === null || typeof rawTask !== 'object' || Array.isArray(rawTask)) {
        return null;
      }
      const task = rawTask as
        Record<string, Object | string | number | boolean | null | undefined>;
      const toolId = task['toolId'];
      const allowed: string[] | null = this.scopeStrings(task['allowedToolIds']);
      if (typeof toolId !== 'string' || toolId.trim().length === 0 || allowed === null) {
        return null;
      }
      this.rememberScopeId(toolId, dataIds);
      for (let allowedIndex = 0; allowedIndex < allowed.length; allowedIndex++) {
        this.rememberScopeId(allowed[allowedIndex], dataIds);
      }
    }
    const rawAction = raw['actionIntent'];
    if (rawAction !== undefined) {
      if (rawAction === null || typeof rawAction !== 'object' || Array.isArray(rawAction)) {
        return null;
      }
      const action = rawAction as
        Record<string, Object | string | number | boolean | null | undefined>;
      const allowedActions: string[] | null = this.scopeStrings(action['allowedActionIds']);
      if (allowedActions === null) {
        return null;
      }
      for (let index = 0; index < allowedActions.length; index++) {
        if (actionIds.indexOf(allowedActions[index]) < 0) {
          actionIds.push(allowedActions[index]);
        }
      }
    }
    return {
      requestedCapabilityIds: requested,
      dataCapabilityIds: dataIds,
      actionCapabilityIds: actionIds,
      roundAction: rawRoundAction as LeaderRoundAction
    };
  }

  private rawDecisionObject(
    output: string
  ): Record<string, Object | string | number | boolean | null | undefined> | null {
    const trimmed: string = output.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}') ||
      this.hasDuplicateObjectKeys(trimmed)) {
      return null;
    }
    try {
      const parsed: Object = JSON.parse(trimmed) as Object;
      if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
        return null;
      }
      return parsed as Record<string, Object | string | number | boolean | null | undefined>;
    } catch (_error) {
      return null;
    }
  }

  private scopeStrings(
    value: Object | string | number | boolean | null | undefined
  ): string[] | null {
    if (!Array.isArray(value)) {
      return null;
    }
    const result: string[] = [];
    const values: Object[] = value as Object[];
    for (let index = 0; index < values.length; index++) {
      const item: Object = values[index];
      if (typeof item !== 'string' || item.trim().length === 0 || result.indexOf(item) >= 0) {
        return null;
      }
      result.push(item);
    }
    return result;
  }

  private rememberScopeId(
    capabilityId: string,
    ids: string[]
  ): void {
    if (ids.indexOf(capabilityId) < 0) {
      ids.push(capabilityId);
    }
  }

  private completeBounded(prompt: string): Promise<string> {
    if (prompt.length > MAX_LEADER_PROMPT_CHARS) {
      throw new Error('LEADER_PROMPT_LIMIT');
    }
    return this.model.complete(prompt, undefined, LEADER_SYSTEM_PROMPT);
  }

  private rejectOverlappingVideoTools(decision: LeaderDecision): void {
    if (decision.roundAction !== 'execute') {
      return;
    }
    let aggregate: boolean = false;
    let youtubeOnly: boolean = false;
    for (let taskIndex = 0; taskIndex < decision.dataTasks.length; taskIndex++) {
      const task: LeaderDecisionDataTask = decision.dataTasks[taskIndex];
      const toolIds: string[] = [task.toolId].concat(task.allowedToolIds);
      aggregate = aggregate || toolIds.indexOf('media.video.search') >= 0;
      youtubeOnly = youtubeOnly || toolIds.indexOf('youtube.video.search') >= 0;
    }
    if (aggregate && youtubeOnly) {
      throw new Error(OVERLAPPING_VIDEO_TOOLS_ERROR);
    }
  }

  private rejectSameRoundDependency(decision: LeaderDecision): void {
    if (decision.roundAction === 'execute' &&
      leaderTasksHaveSameRoundDependency(decision.dataTasks)) {
      throw new Error(SAME_ROUND_DEPENDENCY_ERROR);
    }
  }

  private normalizeSameRoundDependency(
    decision: LeaderDecision,
    producerTaskToolIds: string[],
    consumerTaskToolIds: string[]
  ): void {
    if (producerTaskToolIds.length === 0 && consumerTaskToolIds.length === 0) {
      return;
    }
    if (producerTaskToolIds.length === 0 || consumerTaskToolIds.length === 0) {
      throw new Error(SAME_ROUND_DEPENDENCY_ERROR);
    }
    if (!leaderSameRoundDependencyConsumerTasksLackEntityInput(decision.dataTasks)) {
      throw new Error(SAME_ROUND_DEPENDENCY_ERROR);
    }
    const producerToolIds: Set<string> = new Set<string>(producerTaskToolIds);
    const consumerToolIds: Set<string> = new Set<string>(consumerTaskToolIds);
    const retained: LeaderDecisionDataTask[] = [];
    for (let taskIndex = 0; taskIndex < decision.dataTasks.length; taskIndex++) {
      const task: LeaderDecisionDataTask = decision.dataTasks[taskIndex];
      if (!consumerToolIds.has(task.toolId)) {
        retained.push(task);
      }
    }
    if (retained.length === 0) {
      throw new Error(SAME_ROUND_DEPENDENCY_ERROR);
    }
    let hasProducer: boolean = false;
    const currentRoundIds: string[] = [];
    for (let index = 0; index < retained.length; index++) {
      const task: LeaderDecisionDataTask = retained[index];
      hasProducer = hasProducer || producerToolIds.has(task.toolId);
      this.rememberScopeId(task.toolId, currentRoundIds);
      for (let allowedIndex = 0;
        allowedIndex < task.allowedToolIds.length;
        allowedIndex++) {
        const allowedToolId: string = task.allowedToolIds[allowedIndex];
        if (consumerToolIds.has(allowedToolId)) {
          throw new Error(SAME_ROUND_DEPENDENCY_ERROR);
        }
        this.rememberScopeId(allowedToolId, currentRoundIds);
      }
    }
    if (!hasProducer) {
      throw new Error(SAME_ROUND_DEPENDENCY_ERROR);
    }
    if (decision.actionIntent !== undefined) {
      for (let index = 0; index < decision.actionIntent.allowedActionIds.length; index++) {
        this.rememberScopeId(decision.actionIntent.allowedActionIds[index], currentRoundIds);
      }
    }
    const normalizedRequested: string[] = decision.requestedCapabilityIds.filter(
      (capabilityId: string): boolean =>
        currentRoundIds.indexOf(capabilityId) >= 0
    );
    if (!this.sameStringSet(currentRoundIds, normalizedRequested)) {
      throw new Error(SAME_ROUND_DEPENDENCY_ERROR);
    }
    decision.dataTasks = retained;
    decision.requestedCapabilityIds = normalizedRequested;
  }

  private rejectUnboundLaterTool(
    decision: LeaderDecision,
    observations: ObservationDigest[],
    round: number
  ): void {
    if (round <= 1 || decision.roundAction !== 'execute') {
      return;
    }
    for (let index = 0; index < decision.dataTasks.length; index++) {
      if (!leaderInputHasEntityAuthority(
        decision.dataTasks[index].toolId,
        decision.dataTasks[index].input,
        observations
      )) {
        throw new Error(UNBOUND_LATER_TOOL_ERROR);
      }
    }
  }

  private rejectCompletedToolReuse(decision: LeaderDecision, completedToolIds: string[]): void {
    if (decision.roundAction !== 'execute' || completedToolIds.length === 0) {
      return;
    }
    for (let taskIndex = 0; taskIndex < decision.dataTasks.length; taskIndex++) {
      const task: LeaderDecisionDataTask = decision.dataTasks[taskIndex];
      if (completedToolIds.indexOf(task.toolId) >= 0) {
        throw new Error(COMPLETED_TOOL_REUSE_ERROR);
      }
      for (let allowedIndex = 0; allowedIndex < task.allowedToolIds.length; allowedIndex++) {
        if (completedToolIds.indexOf(task.allowedToolIds[allowedIndex]) >= 0) {
          throw new Error(COMPLETED_TOOL_REUSE_ERROR);
        }
      }
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

  private prompt(
    message: AgentMessage,
    input: InputUserPayload,
    context: LeaderPlanningContext,
    round: number,
    currentLocalDate: string
  ): string {
    const completedToolIds: string[] = this.currentTurnCompletedToolIds(message, input, context, round);
    const dataOwnerIds: string[] = leaderDataCapabilityIds(context);
    const actionOwnerIds: string[] = leaderActionCapabilityIds(context);
    const toolCatalog: string = JSON.stringify(context.tools);
    if (toolCatalog.length > MAX_LEADER_TOOL_CATALOG_CHARS) {
      throw new Error('LEADER_TOOL_CATALOG_LIMIT');
    }
    const result: string = [
      'You are the Appless Leader Agent.',
      'Return exactly one LeaderDecision JSON object.',
      REQUEST_SCOPE_CONTRACT,
      'LeaderDecision schema: {"personaId":"string","skillId":"string",' +
        '"requestedCapabilityIds":["registered tool or action ID"],' +
        '"roundAction":"execute|answer|clarify|legacy_handoff","dataTasks":[' +
        '{"localId":"string","goal":"string","allowedToolIds":["string"],' +
        '"toolId":"string","input":{},"required":true}],"uiIntent":{' +
        '"purpose":"string","preferredDensity":"string","requiredSections":["string"]},' +
        '"actionIntent":{"goal":"string","allowedActionIds":["string"]} optional,' +
        '"answer":"required non-empty string for answer|clarify; omit for execute|legacy_handoff"}.',
      ANSWER_FIELD_RULE,
      REASON_CODE_FIELD_RULE,
      'Select one persona and at most one active skill.',
      'If skillId is non-empty, every requested Data tool and Action ID must be listed in that skill toolIds. ' +
        'Use skillId="" when no single active skill declares the complete requested capability set.',
      'requestedCapabilityIds is mandatory, unique, and contains exact registered tool/action IDs. ' +
        'Use [] only for ordinary direct conversation that needs no tool-backed fact.',
      'Mail, weather, travel, and other capability-backed answer or clarify decisions must name ' +
        'their requested registered capability. For execute, requestedCapabilityIds must be exactly ' +
        'the unique union of every selected Data tool, allowed tool, and Action ID. In other words, ' +
        'requestedCapabilityIds is the exact current-round execution union, not a list of future-round tools.',
      'Tasks in this round must be independent. Put dependent work in a later round.',
      'Ownership contract: Data-owned capability IDs belong in dataTasks toolId and allowedToolIds. ' +
        'Action-owned capability IDs belong in actionIntent.allowedActionIds. A Data-owned ID may also appear in ' +
        'actionIntent only when a source tool explicitly declares that exact ID in actions. Never place an ' +
        'Action-only capability in dataTasks.',
      'When an Action requires a real provider ID, plan the necessary Data-owned read task first and the ' +
        'Action-owned capability in actionIntent. Use only a real observed ID in a later round; never invent one.',
      'Available Data owner IDs: ' + JSON.stringify(dataOwnerIds),
      'Available Action owner IDs: ' + JSON.stringify(actionOwnerIds),
      'Maximum Data tasks in one round: ' + MAX_LEADER_DATA_TASKS_PER_ROUND.toString() + '.',
      TRAVEL_SELECTION_CONTRACT,
      VIDEO_SELECTION_CONTRACT,
      C10_C11_SELECTION_CONTRACT,
      SOCIAL_SELECTION_CONTRACT,
      CALENDAR_UPDATE_SELECTION_CONTRACT,
      CALENDAR_DELETE_SELECTION_CONTRACT,
      'Current-turn completed Data tool IDs: ' + JSON.stringify(completedToolIds),
      OBSERVATION_REUSE_CONTRACT,
      DATA_SCOPE_CONTRACT,
      'Never emit provider facts, action args, A2UI, credentials, or unregistered tool IDs.',
      hotelSearchPlanningContract(currentLocalDate),
      'Use legacy_handoff with no tasks whenever the requested capability is not ordinary ' +
        'conversation and is unavailable or not runtime-owned.',
      'Maximum planning rounds: 3.',
      'Round: ' + round.toString(),
      'Context: ' + JSON.stringify(input),
      'Registry capabilities: ' + toolCatalog,
      'Runtime-owned tool IDs: ' + JSON.stringify(
        context.runtimeOwnedToolIds === undefined ? [] : context.runtimeOwnedToolIds
      ),
      'Personas: ' + JSON.stringify(context.personas)
    ].join('\n');
    if (result.length > MAX_LEADER_PROMPT_CHARS) {
      throw new Error('LEADER_PROMPT_LIMIT');
    }
    return result;
  }

  private currentTurnCompletedToolIds(
    message: AgentMessage,
    input: InputUserPayload,
    context: LeaderPlanningContext,
    currentRound: number
  ): string[] {
    if (currentRound <= 1) {
      return [];
    }
    const observations: ObservationDigest[] = input.recentObservations === undefined ? [] :
      input.recentObservations;
    const result: string[] = [];
    for (let index = 0; index < observations.length && result.length < MAX_COMPLETED_TOOL_IDS; index++) {
      const observation: ObservationDigest = observations[index];
      const terminal: boolean = observation.status === 'success' || observation.status === 'partial' ||
        observation.status === 'empty' || observation.status === 'error';
      const observationRound: number = this.observationRound(message.taskId, observation.taskId);
      const toolId: string = observation.toolId;
      if (terminal && observationRound > 0 && observationRound < currentRound &&
        leaderIsDataCapability(context, toolId) && result.indexOf(toolId) < 0) {
        result.push(toolId);
      }
    }
    return result;
  }

  private currentTurnDependencyObservations(
    message: AgentMessage,
    input: InputUserPayload,
    currentRound: number
  ): ObservationDigest[] {
    if (currentRound <= 1) {
      return [];
    }
    const observations: ObservationDigest[] = input.recentObservations === undefined ? [] :
      input.recentObservations;
    const result: ObservationDigest[] = [];
    for (let index = 0; index < observations.length; index++) {
      const observation: ObservationDigest = observations[index];
      const observationRound: number = this.observationRound(message.taskId, observation.taskId);
      if ((observation.status !== 'success' && observation.status !== 'partial') ||
        observationRound <= 0 || observationRound >= currentRound) {
        continue;
      }
      result.push(observation);
    }
    return result;
  }

  private observationRound(inputTaskId: string, observationTaskId: string): number {
    const prefix: string = inputTaskId + ':round-';
    if (!observationTaskId.startsWith(prefix)) {
      return 0;
    }
    const suffix: string = observationTaskId.substring(prefix.length);
    const separator: number = suffix.indexOf(':');
    if (separator <= 0 || separator >= suffix.length - 1 ||
      suffix.substring(separator + 1).trim().length === 0) {
      return 0;
    }
    const roundText: string = suffix.substring(0, separator);
    if (roundText[0] === '0') {
      return 0;
    }
    for (let index = 0; index < roundText.length; index++) {
      const code: number = roundText.charCodeAt(index);
      if (code < 48 || code > 57) {
        return 0;
      }
    }
    const round: number = Number(roundText);
    return Number.isInteger(round) && round > 0 ? round : 0;
  }

  private decision(parsed: Object, context: LeaderPlanningContext): LeaderDecision {
    if (parsed === null || Array.isArray(parsed)) {
      throw new Error('Leader decision contains missing or unknown fields.');
    }
    const decisionKeys: string = Object.keys(parsed)
      .filter((key: string): boolean => key !== 'reasonCode')
      .sort()
      .join(',');
    if (DECISION_KEYS.indexOf(decisionKeys) < 0) {
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
      (reasonCode !== undefined &&
        (typeof reasonCode !== 'string' || reasonCode.trim().length === 0))) {
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
      this.actionIntent(actionValue, context, selectedAction === 'legacy_handoff');
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
      reasonCode: this.hostReasonCode(selectedAction)
    };
    if (typeof answerValue === 'string') {
      decision.answer = answerValue;
    }
    if (actionIntent !== null) {
      decision.actionIntent = actionIntent;
    }
    return decision;
  }

  private hostReasonCode(action: LeaderRoundAction): string {
    if (action === 'legacy_handoff') {
      return 'unmigrated_tool';
    }
    if (action === 'execute') {
      return 'host_execute';
    }
    if (action === 'answer') {
      return 'host_answer';
    }
    return 'host_clarify';
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
      if (tool.toolId === id) {
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
    if (rawTasks.length > MAX_LEADER_DATA_TASKS_PER_ROUND) {
      throw new Error('LEADER_DATA_TASK_LIMIT');
    }
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
      if (!leaderIsDataCapability(context, toolId) &&
        leaderIsActionCapability(context, toolId)) {
        throw new Error(ACTION_OWNED_DATA_TASK_ERROR);
      }
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
      if (typeof value === 'string' &&
        !leaderIsDataCapability(context, value) &&
        leaderIsActionCapability(context, value)) {
        throw new Error(ACTION_OWNED_DATA_TASK_ERROR);
      }
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
    context: LeaderPlanningContext,
    allowRegisteredHandoff: boolean = false
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
    for (let index = 0; index < ids.length; index++) {
      if (allowRegisteredHandoff ?
        !this.registeredCapability(context, ids[index]) :
        !leaderIsActionCapability(context, ids[index])) {
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

  private rejectSkillCapabilityViolation(
    decision: LeaderDecision,
    context: LeaderPlanningContext
  ): void {
    if (decision.skillId.length === 0) {
      return;
    }
    for (let personaIndex = 0; personaIndex < context.personas.length; personaIndex++) {
      const persona: LeaderPersonaMetadata = context.personas[personaIndex];
      if (persona.personaId !== decision.personaId) {
        continue;
      }
      for (let skillIndex = 0; skillIndex < persona.activeSkills.length; skillIndex++) {
        const skill: LeaderSkillMetadata = persona.activeSkills[skillIndex];
        if (skill.skillId !== decision.skillId || skill.status !== 'active') {
          continue;
        }
        for (let capabilityIndex = 0;
          capabilityIndex < decision.requestedCapabilityIds.length;
          capabilityIndex++) {
          if (skill.toolIds.indexOf(decision.requestedCapabilityIds[capabilityIndex]) < 0) {
            throw new Error(SKILL_CAPABILITY_ERROR);
          }
        }
        return;
      }
    }
    throw new Error(SKILL_CAPABILITY_ERROR);
  }

  private readTool(context: LeaderPlanningContext, toolId: string): LeaderToolMetadata | null {
    if (!leaderIsDataCapability(context, toolId)) {
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
