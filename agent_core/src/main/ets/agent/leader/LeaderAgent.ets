import { MessageDrivenAgent } from '../MessageDrivenAgent';
import {
  AgentMessage,
  AgentMessageType,
  ConversationTurnMessage,
  CurrentSurfaceSummary,
  LegacyHandoffPayload,
  ObservationDigest,
  TaskErrorPayload,
  TurnResultPayload
} from '../message/AgentMessage';
import { LinkedMessageBus } from '../message/LinkedMessageBus';
import {
  InputUserPayload,
  LeaderDataTask,
  LeaderDataTaskInputNormalizer,
  LeaderDecision,
  LeaderDecisionDataTask,
  LeaderPlan,
  LeaderPlanner,
  LeaderPlannerResult,
  LeaderPersonaMetadata,
  LeaderPlanningContext,
  LeaderSkillMetadata,
  LeaderToolMetadata,
  LeaderUiTask
} from './LeaderTypes';
import { CreateUiTaskPayload } from '../ui/UiAgentTypes';
import { CreateDataTaskPayload } from '../data/DataAgentTypes';
import { dataAgentToolDefinitions } from '../../aiphone/runtime/ToolDefinitionRegistry';
import { ToolDefinition } from '../../aiphone/runtime/ToolDefinitionTypes';
import { ActionPlanRequestPayload } from '../action/ActionAgentTypes';

interface LeaderTurnState {
  conversationId: string;
  turnId: string;
  inputTaskId: string;
  uiTaskId: string;
  dataTaskId: string;
  input: InputUserPayload;
  round: number;
  semantic: boolean;
  planning: boolean;
  pendingDataTools: Map<string, LeaderPendingDataTask>;
  observations: ObservationDigest[];
  turnObservations: ObservationDigest[];
  skillId: string;
  uiDone: boolean;
  dataDone: boolean;
  terminal: boolean;
  timerId: number;
  releasePlanning: (() => void) | null;
}

interface LeaderPendingDataTask {
  toolId: string;
  outputSchema: string;
}

export class LeaderAgent extends MessageDrivenAgent {
  private readonly bus: LinkedMessageBus;
  private readonly planner: LeaderPlanner;
  private planningContext: LeaderPlanningContext;
  private readonly timeoutMs: number;
  private readonly dataToolIds: Set<string>;
  private readonly dataTaskInputNormalizer: LeaderDataTaskInputNormalizer | null;
  private readonly turns: Map<string, LeaderTurnState> = new Map<string, LeaderTurnState>();
  // Terminal state is reduced to exact identities so active turn payloads and
  // timers are released without permitting an old input to be dispatched twice.
  private readonly terminalTurns: Set<string> = new Set<string>();

  constructor(
    bus: LinkedMessageBus,
    planner: LeaderPlanner,
    planningContext: LeaderPlanningContext,
    timeoutMs: number = 30000,
    dataTaskInputNormalizer?: LeaderDataTaskInputNormalizer
  ) {
    super(bus);
    this.bus = bus;
    this.planner = planner;
    this.planningContext = this.copyPlanningContext(planningContext);
    this.dataToolIds = new Set<string>(dataAgentToolDefinitions().map(
      (definition: ToolDefinition): string => definition.toolId
    ));
    this.timeoutMs = timeoutMs > 0 ? timeoutMs : 30000;
    this.dataTaskInputNormalizer = dataTaskInputNormalizer === undefined ?
      null : dataTaskInputNormalizer;
  }

  stop(): void {
    this.turns.forEach((state: LeaderTurnState) => {
      this.finishTurn(state);
    });
    this.turns.clear();
    this.terminalTurns.clear();
    super.stop();
  }

  updatePlanningContext(context: LeaderPlanningContext): void {
    this.planningContext = this.copyPlanningContext(context);
  }

  protected accepts(message: AgentMessage): boolean {
    return message.type === AgentMessageType.INPUT_USER ||
      message.type === AgentMessageType.TASK_RESULT_UI ||
      message.type === AgentMessageType.TASK_RESULT_DATA ||
      message.type === AgentMessageType.ACTION_RESULT ||
      message.type === AgentMessageType.TASK_ERROR ||
      message.type === AgentMessageType.TURN_CANCEL;
  }

  protected async process(message: AgentMessage): Promise<void> {
    if (message.type === AgentMessageType.INPUT_USER) {
      this.handleInput(message);
      return;
    }
    if (!this.hasCorrelation(message)) {
      return;
    }
    const state: LeaderTurnState | undefined = this.turns.get(this.turnKey(message));
    if (state === undefined || state.terminal) {
      return;
    }
    if (message.type === AgentMessageType.TURN_CANCEL) {
      this.finishTurn(state);
      return;
    }
    if (message.type === AgentMessageType.ACTION_RESULT) {
      return;
    }
    if (message.type === AgentMessageType.TASK_ERROR && message.taskId === state.inputTaskId) {
      this.finishTurn(state);
      return;
    }
    if (state.semantic) {
      if (message.type === AgentMessageType.TASK_RESULT_DATA ||
        message.type === AgentMessageType.TASK_ERROR) {
        this.handleSemanticObservation(state, message);
      }
      return;
    }
    if (message.type === AgentMessageType.TASK_RESULT_UI && message.taskId === state.uiTaskId) {
      state.uiDone = true;
    } else if (message.type === AgentMessageType.TASK_RESULT_DATA && message.taskId === state.dataTaskId) {
      state.dataDone = true;
    } else if (message.type === AgentMessageType.TASK_ERROR) {
      if (message.taskId === state.uiTaskId) {
        state.uiDone = true;
      } else if (message.taskId === state.dataTaskId) {
        state.dataDone = true;
      } else if (message.taskId === state.inputTaskId) {
        this.finishTurn(state);
        return;
      } else {
        return;
      }
    } else {
      return;
    }
    if (state.uiDone && state.dataDone) {
      this.finishTurn(state);
    }
  }

  private handleInput(message: AgentMessage): void {
    if (!this.hasCorrelation(message)) {
      return;
    }
    const inputRecord = message.payload as Record<string, Object | string | number | boolean | null | undefined>;
    const inputText: Object | string | number | boolean | null | undefined = inputRecord['text'];
    if (typeof inputText !== 'string' || inputText.trim().length === 0) {
      this.publishError(message, 'LEADER_INPUT_INVALID', 'User input text must not be empty');
      return;
    }
    const recentMessages = inputRecord['recentMessages'];
    const previousPersonaId = inputRecord['previousPersonaId'];
    const currentSurfaceSummary = inputRecord['currentSurfaceSummary'];
    const recentObservations = inputRecord['recentObservations'];
    const input: InputUserPayload = {
      text: inputText,
      recentMessages: Array.isArray(recentMessages) ? recentMessages as ConversationTurnMessage[] : [],
      previousPersonaId: typeof previousPersonaId === 'string' ? previousPersonaId : '',
      currentSurfaceSummary: currentSurfaceSummary !== null &&
        typeof currentSurfaceSummary === 'object' && !Array.isArray(currentSurfaceSummary) ?
        currentSurfaceSummary as CurrentSurfaceSummary : {
          surfaceId: '', kind: '', status: '', entityRefs: [], actionOfferIds: []
        },
      recentObservations: Array.isArray(recentObservations) ?
        this.boundedObservations(recentObservations as Object[]) : []
    };
    const key: string = this.turnKey(message);
    if (this.turns.has(key) || this.terminalTurns.has(key)) {
      return;
    }
    const state: LeaderTurnState = {
      conversationId: message.conversationId,
      turnId: message.turnId,
      inputTaskId: message.taskId,
      uiTaskId: '',
      dataTaskId: '',
      input,
      round: 1,
      semantic: false,
      planning: false,
      pendingDataTools: new Map<string, LeaderPendingDataTask>(),
      observations: input.recentObservations as ObservationDigest[],
      turnObservations: [],
      skillId: '',
      uiDone: false,
      dataDone: false,
      terminal: false,
      timerId: -1,
      releasePlanning: null
    };
    this.turns.set(key, state);
    state.timerId = setTimeout(() => {
      this.timeoutTurn(key);
    }, this.timeoutMs);
    this.startPlanning(message, input, state);
  }

  private startPlanning(
    message: AgentMessage,
    input: InputUserPayload,
    state: LeaderTurnState
  ): void {
    if (state.terminal || state.planning) {
      return;
    }
    state.planning = true;
    const timeoutSignal: Promise<void> = new Promise<void>((resolve: () => void) => {
      state.releasePlanning = resolve;
    });
    try {
      Promise.race([
        this.planner.plan(
          message,
          input,
          this.copyPlanningContext(this.planningContext),
          state.round
        ),
        timeoutSignal
      ])
        .then((outcome: LeaderPlannerResult | void) => {
          this.completePlanning(message, state, outcome);
        })
        .catch((error: Object) => {
          this.failPlanning(message, state, error);
        });
    } catch (error) {
      this.failPlanning(message, state, error);
    }
  }

  private completePlanning(
    message: AgentMessage,
    state: LeaderTurnState,
    outcome: LeaderPlannerResult | void
  ): void {
    state.planning = false;
    if (state.terminal) {
      return;
    }
    if (outcome === undefined) {
      this.finishTurn(state);
      this.publishError(message, 'LEADER_PLAN_FAILED', 'Leader planner returned no decision');
      return;
    }
    const result: LeaderPlannerResult = outcome as LeaderPlannerResult;
    if (this.isExactLegacyPlan(result)) {
      if (state.round !== 1 || state.semantic) {
        this.finishTurn(state);
        this.publishError(message, 'LEADER_PLAN_INVALID', 'Legacy plan is allowed only as the first planner outcome');
        return;
      }
      this.completeLegacyPlanning(message, state, result as LeaderPlan);
      return;
    }
    this.completeDecisionPlanning(message, state, result as LeaderDecision);
  }

  private completeLegacyPlanning(message: AgentMessage, state: LeaderTurnState, plan: LeaderPlan): void {
    if (!this.validPlan(plan)) {
      this.finishTurn(state);
      this.publishError(message, 'LEADER_PLAN_INVALID', 'Leader plan task fields must be non-empty and unique');
      return;
    }
    state.uiTaskId = plan.ui.taskId;
    const dataTask: LeaderDataTask = plan.dataTasks[0];
    state.dataTaskId = dataTask.taskId;
    state.skillId = plan.skillId;
    this.publishUiTask(message, plan.ui, dataTask.taskId);
    this.publishDataTask(message, dataTask);
  }

  private completeDecisionPlanning(
    message: AgentMessage,
    state: LeaderTurnState,
    decision: LeaderDecision
  ): void {
    if (!this.validDecision(decision)) {
      this.finishTurn(state);
      this.publishError(message, 'LEADER_PLAN_INVALID', 'Leader decision violates its exact capability contract');
      return;
    }
    if (!this.runtimeOwnsDecision(decision)) {
      this.publishHandoff(message, decision);
      this.finishTurn(state);
      return;
    }
    try {
      this.normalizeDecisionInputs(state.input, decision);
    } catch (error) {
      this.finishTurn(state);
      const detail: string = error instanceof Error ? error.message : `${error}`;
      this.publishError(message, 'LEADER_TASK_INPUT_INVALID', detail);
      return;
    }
    state.semantic = true;
    state.skillId = decision.skillId;
    if (decision.roundAction === 'legacy_handoff') {
      this.publishHandoff(message, decision);
      this.finishTurn(state);
      return;
    }
    if (decision.roundAction === 'answer' || decision.roundAction === 'clarify') {
      if (state.turnObservations.length === 0 && decision.requestedCapabilityIds.length > 0) {
        this.publishHandoff(message, decision);
        this.finishTurn(state);
        return;
      }
      this.publishTurnResult(message, state, decision.answer as string);
      this.finishTurn(state);
      return;
    }
    const dataTaskIds: string[] = this.decisionDataTaskIds(state, decision.dataTasks);
    let uiTaskId: string = state.inputTaskId + ':round-' + state.round.toString() + ':virtual';
    if (dataTaskIds.length > 0) {
      uiTaskId = state.inputTaskId + ':round-' + state.round.toString() + ':ui';
      this.publishDecisionUiTask(message, state, decision, uiTaskId, dataTaskIds);
    }
    for (let index = 0; index < decision.dataTasks.length; index++) {
      this.publishDecisionDataTask(message, state, decision.dataTasks[index]);
    }
    if (decision.actionIntent !== undefined) {
      this.publishActionPlanRequest(
        message,
        decision,
        uiTaskId,
        dataTaskIds,
        dataTaskIds.length === 0
      );
    }
  }

  private failPlanning(message: AgentMessage, state: LeaderTurnState, error: Object): void {
    state.planning = false;
    if (state.terminal) {
      return;
    }
    this.finishTurn(state);
    const detail: string = error instanceof Error ? error.message : `${error}`;
    this.publishError(message, 'LEADER_PLAN_FAILED', detail);
  }

  private handleSemanticObservation(state: LeaderTurnState, message: AgentMessage): void {
    const pending: LeaderPendingDataTask | undefined = state.pendingDataTools.get(message.taskId);
    if (pending === undefined) {
      return;
    }
    const digest: ObservationDigest = message.type === AgentMessageType.TASK_RESULT_DATA ?
      this.resultDigest(message, pending) : this.errorDigest(message, pending.toolId);
    state.pendingDataTools.delete(message.taskId);
    state.observations.push(digest);
    state.turnObservations.push(digest);
    state.observations = this.boundedObservations(state.observations as Object[]);
    if (state.pendingDataTools.size > 0) {
      return;
    }
    if (state.round >= 3) {
      const inputMessage: AgentMessage = this.inputMessage(state);
      this.finishTurn(state);
      this.publishError(inputMessage, 'LEADER_ROUND_LIMIT', 'Leader cannot plan more than three rounds');
      return;
    }
    state.round++;
    state.input = this.inputWithObservations(state.input, state.observations);
    this.startPlanning(this.inputMessage(state), state.input, state);
  }

  private resultDigest(message: AgentMessage, pending: LeaderPendingDataTask): ObservationDigest {
    const payload = message.payload as Object | null;
    if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
      return this.invalidResultDigest(message, pending.toolId);
    }
    const values = payload as Record<string, Object | string | number | boolean | null | undefined>;
    const toolId = values['toolId'];
    const outputSchema = values['outputSchema'];
    const resultStatus = values['status'];
    const sources = values['sources'];
    const data = values['data'];
    const warnings = values['warnings'];
    const error = values['error'];
    const validStatus: boolean = resultStatus === 'success' || resultStatus === 'partial' ||
      resultStatus === 'empty' || resultStatus === 'error';
    const validError: boolean = error === undefined || this.validResultError(error);
    const validResult: boolean = toolId === pending.toolId && outputSchema === pending.outputSchema &&
      validStatus && Array.isArray(sources) && data !== null && typeof data === 'object' &&
      !Array.isArray(data) && Array.isArray(warnings) && validError;
    const status: string = validResult ? resultStatus as string : 'error';
    let summary: string = validResult ? pending.toolId + ' returned ' + status : 'Data task output was invalid';
    let entityRefs: string[] = [];
    if (validResult) {
      const dataValues = data as Record<string, Object | string | number | boolean | null | undefined>;
      const dataSummary = dataValues['summary'];
      const dataEntityRefs = dataValues['entityRefs'];
      if (typeof dataSummary === 'string' && dataSummary.trim().length > 0) {
        summary = dataSummary;
      }
      if (Array.isArray(dataEntityRefs)) {
        entityRefs = this.boundedStrings(dataEntityRefs as Object[], 16, 128);
      }
      if (summary === pending.toolId + ' returned ' + status &&
        error !== undefined) {
        const errorValues = error as Record<string, Object | string | number | boolean | null | undefined>;
        summary = 'Data task failed: ' + (errorValues['code'] as string);
      }
    }
    return {
      taskId: this.boundedText(message.taskId, 128),
      toolId: pending.toolId,
      status,
      summary: this.boundedText(summary, 240),
      entityRefs
    };
  }

  private invalidResultDigest(message: AgentMessage, toolId: string): ObservationDigest {
    return {
      taskId: this.boundedText(message.taskId, 128),
      toolId,
      status: 'error',
      summary: 'Data task output was invalid',
      entityRefs: []
    };
  }

  private validResultError(error: Object | string | number | boolean | null): boolean {
    if (error === null || typeof error !== 'object' || Array.isArray(error)) {
      return false;
    }
    const keys: string = Object.keys(error).sort().join(',');
    if (keys !== 'code,message' && keys !== 'code,message,retryable') {
      return false;
    }
    const values = error as Record<string, Object | string | number | boolean | null | undefined>;
    return typeof values['code'] === 'string' && (values['code'] as string).trim().length > 0 &&
      typeof values['message'] === 'string' &&
      (values['retryable'] === undefined || typeof values['retryable'] === 'boolean');
  }

  private errorDigest(message: AgentMessage, toolId: string): ObservationDigest {
    const payload: TaskErrorPayload = message.payload as TaskErrorPayload;
    const summary: string = payload !== null && typeof payload === 'object' &&
      typeof payload.code === 'string' && payload.code.trim().length > 0 ?
      'Data task failed: ' + payload.code : 'Data task failed';
    return {
      taskId: this.boundedText(message.taskId, 128),
      toolId,
      status: 'error',
      summary: this.boundedText(summary, 240),
      entityRefs: []
    };
  }

  private inputWithObservations(
    input: InputUserPayload,
    observations: ObservationDigest[]
  ): InputUserPayload {
    return {
      text: input.text,
      recentMessages: input.recentMessages,
      previousPersonaId: input.previousPersonaId,
      currentSurfaceSummary: input.currentSurfaceSummary,
      recentObservations: this.boundedObservations(observations as Object[])
    };
  }

  private inputMessage(state: LeaderTurnState): AgentMessage {
    return {
      type: AgentMessageType.INPUT_USER,
      conversationId: state.conversationId,
      turnId: state.turnId,
      taskId: state.inputTaskId,
      payload: state.input
    };
  }

  private hasCorrelation(message: AgentMessage): boolean {
    return this.nonEmptyString(message.conversationId) &&
      this.nonEmptyString(message.turnId) &&
      this.nonEmptyString(message.taskId);
  }

  private nonEmptyString(value: string): boolean {
    return typeof value === 'string' && value.trim().length > 0;
  }

  private validPlan(plan: LeaderPlan): boolean {
    if (plan === undefined || plan === null ||
      Array.isArray(plan) ||
      !this.validLegacyPlanKeys(plan) ||
      typeof plan.personaId !== 'string' ||
      typeof plan.skillId !== 'string' ||
      !this.validSelectedSkill(plan.personaId, plan.skillId) ||
      plan.roundAction !== 'execute' ||
      typeof plan.reasonCode !== 'string' || plan.reasonCode.trim().length === 0 ||
      !this.validLegacyUi(plan.ui) ||
      !Array.isArray(plan.dataTasks) || plan.dataTasks.length !== 1) {
      return false;
    }
    const dataTask: LeaderDataTask = plan.dataTasks[0];
    if (!this.validLegacyDataTask(dataTask)) {
      return false;
    }
    const tool: LeaderToolMetadata | null = this.toolMetadata(dataTask.toolId);
    if (tool === null || tool.riskLevel !== 'read' ||
      tool.outputSchema !== dataTask.outputSchema ||
      tool.outputSchema !== plan.ui.expectedOutputSchema) {
      return false;
    }
    return plan.ui.taskId.trim().length > 0 &&
      dataTask.taskId.trim().length > 0 &&
      plan.ui.taskId !== dataTask.taskId &&
      plan.ui.intent.trim().length > 0 &&
      plan.ui.expectedOutputSchema.trim().length > 0 &&
      plan.ui.expectedOutputSchema === dataTask.outputSchema &&
      dataTask.toolId.trim().length > 0 &&
      dataTask.outputSchema.trim().length > 0;
  }

  private validLegacyPlanKeys(plan: LeaderPlan): boolean {
    const keys: string = Object.keys(plan).sort().join(',');
    if (keys !== 'dataTasks,personaId,reasonCode,roundAction,skillId,ui' &&
      keys !== 'actionIntent,dataTasks,personaId,reasonCode,roundAction,skillId,ui' &&
      keys !== 'answer,dataTasks,personaId,reasonCode,roundAction,skillId,ui' &&
      keys !== 'actionIntent,answer,dataTasks,personaId,reasonCode,roundAction,skillId,ui') {
      return false;
    }
    if (plan.actionIntent !== undefined && !this.validActionIntent(plan.actionIntent)) {
      return false;
    }
    return plan.answer === undefined ||
      (typeof plan.answer === 'string' && plan.answer.trim().length > 0);
  }

  private validLegacyUi(ui: LeaderUiTask): boolean {
    return ui !== undefined && ui !== null && !Array.isArray(ui) &&
      Object.keys(ui).sort().join(',') === 'expectedOutputSchema,intent,taskId' &&
      typeof ui.taskId === 'string' &&
      typeof ui.intent === 'string' &&
      typeof ui.expectedOutputSchema === 'string';
  }

  private validLegacyDataTask(task: LeaderDataTask): boolean {
    return task !== undefined && task !== null && !Array.isArray(task) &&
      Object.keys(task).sort().join(',') === 'args,outputSchema,taskId,toolId' &&
      typeof task.taskId === 'string' &&
      typeof task.toolId === 'string' &&
      typeof task.outputSchema === 'string' &&
      task.args !== null && typeof task.args === 'object' && !Array.isArray(task.args);
  }

  private isExactLegacyPlan(result: LeaderPlannerResult): boolean {
    return result !== undefined && result !== null && !Array.isArray(result) &&
      this.validPlan(result as LeaderPlan);
  }

  private validDecision(decision: LeaderDecision): boolean {
    if (decision === undefined || decision === null) {
      return false;
    }
    const keys: string = Object.keys(decision).sort().join(',');
    if (keys !== 'dataTasks,personaId,reasonCode,requestedCapabilityIds,roundAction,skillId,uiIntent' &&
      keys !== 'answer,dataTasks,personaId,reasonCode,requestedCapabilityIds,roundAction,skillId,uiIntent' &&
      keys !== 'actionIntent,dataTasks,personaId,reasonCode,requestedCapabilityIds,roundAction,skillId,uiIntent' &&
      keys !== 'actionIntent,answer,dataTasks,personaId,reasonCode,requestedCapabilityIds,roundAction,skillId,uiIntent') {
      return false;
    }
    if (typeof decision.personaId !== 'string' || decision.personaId.trim().length === 0 ||
      typeof decision.skillId !== 'string' ||
      !this.validDecisionPersonaSkill(decision.personaId, decision.skillId) ||
      !this.validRoundAction(decision.roundAction) ||
      typeof decision.reasonCode !== 'string' || decision.reasonCode.trim().length === 0 ||
      !Array.isArray(decision.dataTasks) || !this.validUiIntent(decision.uiIntent) ||
      !this.validRequestedCapabilityIds(decision.requestedCapabilityIds)) {
      return false;
    }
    if ((decision.roundAction === 'execute' && decision.dataTasks.length === 0 &&
      decision.actionIntent === undefined) ||
      (decision.roundAction !== 'execute' && decision.dataTasks.length !== 0)) {
      return false;
    }
    const answer = decision.answer;
    if (answer !== undefined && (typeof answer !== 'string' || answer.trim().length === 0)) {
      return false;
    }
    if ((decision.roundAction === 'answer' || decision.roundAction === 'clarify') &&
      typeof answer !== 'string') {
      return false;
    }
    if (!this.validDecisionTasks(decision.dataTasks)) {
      return false;
    }
    const actionIntent = decision.actionIntent;
    return (actionIntent === undefined || this.validActionIntent(actionIntent)) &&
      this.requestedCapabilitiesCoverExecution(decision);
  }

  private runtimeOwnsDecision(decision: LeaderDecision): boolean {
    const ownedIds: string[] | undefined = this.planningContext.runtimeOwnedToolIds;
    if (ownedIds === undefined) {
      return true;
    }
    for (let index = 0; index < decision.requestedCapabilityIds.length; index++) {
      if (ownedIds.indexOf(decision.requestedCapabilityIds[index]) < 0) {
        return false;
      }
    }
    return true;
  }

  private validRequestedCapabilityIds(ids: string[]): boolean {
    if (!Array.isArray(ids)) {
      return false;
    }
    const unique: Set<string> = new Set<string>();
    for (let index = 0; index < ids.length; index++) {
      const id: string = ids[index];
      if (typeof id !== 'string' || id.trim().length === 0 || unique.has(id) ||
        !this.registeredCapability(id)) {
        return false;
      }
      unique.add(id);
    }
    return true;
  }

  private registeredCapability(id: string): boolean {
    for (let index = 0; index < this.planningContext.tools.length; index++) {
      const tool = this.planningContext.tools[index];
      if (tool.toolId === id || tool.actions.indexOf(id) >= 0) {
        return true;
      }
    }
    return false;
  }

  private requestedCapabilitiesCoverExecution(decision: LeaderDecision): boolean {
    if (decision.roundAction !== 'execute') {
      return true;
    }
    const requested: string[] = decision.requestedCapabilityIds;
    for (let taskIndex = 0; taskIndex < decision.dataTasks.length; taskIndex++) {
      const task = decision.dataTasks[taskIndex];
      if (requested.indexOf(task.toolId) < 0) {
        return false;
      }
      for (let allowedIndex = 0; allowedIndex < task.allowedToolIds.length; allowedIndex++) {
        if (requested.indexOf(task.allowedToolIds[allowedIndex]) < 0) {
          return false;
        }
      }
    }
    if (decision.actionIntent !== undefined) {
      for (let index = 0; index < decision.actionIntent.allowedActionIds.length; index++) {
        if (requested.indexOf(decision.actionIntent.allowedActionIds[index]) < 0) {
          return false;
        }
      }
    }
    return true;
  }

  private normalizeDecisionInputs(input: InputUserPayload, decision: LeaderDecision): void {
    const normalizer: LeaderDataTaskInputNormalizer | null = this.dataTaskInputNormalizer;
    if (normalizer === null) {
      return;
    }
    for (let index = 0; index < decision.dataTasks.length; index++) {
      decision.dataTasks[index].input = normalizer(input, decision.dataTasks[index]);
    }
  }

  private validDecisionTasks(tasks: LeaderDecisionDataTask[]): boolean {
    const localIds: Set<string> = new Set<string>();
    for (let index = 0; index < tasks.length; index++) {
      const task = tasks[index];
      if (task === undefined || task === null ||
        Object.keys(task).sort().join(',') !== 'allowedToolIds,goal,input,localId,required,toolId' ||
        typeof task.localId !== 'string' || task.localId.trim().length === 0 || localIds.has(task.localId) ||
        typeof task.goal !== 'string' || task.goal.trim().length === 0 ||
        !Array.isArray(task.allowedToolIds) || task.allowedToolIds.length === 0 ||
        typeof task.toolId !== 'string' || task.toolId.trim().length === 0 ||
        task.input === null || typeof task.input !== 'object' || Array.isArray(task.input) ||
        typeof task.required !== 'boolean') {
        return false;
      }
      const allowed: Set<string> = new Set<string>();
      for (let allowedIndex = 0; allowedIndex < task.allowedToolIds.length; allowedIndex++) {
        const allowedId = task.allowedToolIds[allowedIndex];
        if (typeof allowedId !== 'string' || allowedId.trim().length === 0 ||
          allowed.has(allowedId) || !this.dataToolIds.has(allowedId) ||
          this.toolMetadata(allowedId)?.riskLevel !== 'read') {
          return false;
        }
        allowed.add(allowedId);
      }
      if (!allowed.has(task.toolId)) {
        return false;
      }
      localIds.add(task.localId);
    }
    return true;
  }

  private validUiIntent(intent: Object): boolean {
    if (intent === undefined || intent === null || Array.isArray(intent) ||
      Object.keys(intent).sort().join(',') !== 'preferredDensity,purpose,requiredSections') {
      return false;
    }
    const values = intent as Record<string, Object | string | number | boolean | null | undefined>;
    return typeof values['purpose'] === 'string' && (values['purpose'] as string).trim().length > 0 &&
      typeof values['preferredDensity'] === 'string' &&
      (values['preferredDensity'] as string).trim().length > 0 &&
      Array.isArray(values['requiredSections']) &&
      this.validUniqueStrings(values['requiredSections'] as Object[], true);
  }

  private validActionIntent(intent: Object | string | number | boolean | null): boolean {
    if (intent === null || typeof intent !== 'object' || Array.isArray(intent) ||
      Object.keys(intent).sort().join(',') !== 'allowedActionIds,goal') {
      return false;
    }
    const values = intent as Record<string, Object | string | number | boolean | null | undefined>;
    const allowedIds = values['allowedActionIds'];
    if (typeof values['goal'] !== 'string' || (values['goal'] as string).trim().length === 0 ||
      !Array.isArray(allowedIds) || !this.validUniqueStrings(allowedIds as Object[], false)) {
      return false;
    }
    const registered: Set<string> = new Set<string>();
    for (let toolIndex = 0; toolIndex < this.planningContext.tools.length; toolIndex++) {
      const actions = this.planningContext.tools[toolIndex].actions;
      for (let actionIndex = 0; actionIndex < actions.length; actionIndex++) {
        registered.add(actions[actionIndex]);
      }
    }
    for (let index = 0; index < allowedIds.length; index++) {
      if (!registered.has(allowedIds[index] as string)) {
        return false;
      }
    }
    return true;
  }

  private validUniqueStrings(values: Object[], allowEmpty: boolean): boolean {
    if (!allowEmpty && values.length === 0) {
      return false;
    }
    const seen: Set<string> = new Set<string>();
    for (let index = 0; index < values.length; index++) {
      const value = values[index];
      if (typeof value !== 'string' || value.trim().length === 0 || seen.has(value)) {
        return false;
      }
      seen.add(value);
    }
    return true;
  }

  private validDecisionPersonaSkill(personaId: string, skillId: string): boolean {
    for (let personaIndex = 0; personaIndex < this.planningContext.personas.length; personaIndex++) {
      const persona = this.planningContext.personas[personaIndex];
      if (persona.personaId !== personaId) {
        continue;
      }
      if (skillId.length === 0) {
        return true;
      }
      for (let skillIndex = 0; skillIndex < persona.activeSkills.length; skillIndex++) {
        const skill = persona.activeSkills[skillIndex];
        if (skill.skillId === skillId && skill.status === 'active') {
          return true;
        }
      }
      return false;
    }
    return false;
  }

  private validRoundAction(value: string): boolean {
    return value === 'execute' || value === 'answer' || value === 'clarify' || value === 'legacy_handoff';
  }

  private validSelectedSkill(personaId: string, skillId: string): boolean {
    if (skillId.trim().length === 0) {
      return true;
    }
    if (personaId.trim().length === 0) {
      return false;
    }
    for (let personaIndex = 0; personaIndex < this.planningContext.personas.length; personaIndex++) {
      const persona = this.planningContext.personas[personaIndex];
      if (persona.personaId !== personaId) {
        continue;
      }
      const skills = persona.activeSkills;
      for (let skillIndex = 0; skillIndex < skills.length; skillIndex++) {
        if (skills[skillIndex].skillId === skillId) {
          return true;
        }
      }
      return false;
    }
    return false;
  }

  private toolMetadata(toolId: string): LeaderToolMetadata | null {
    for (let index = 0; index < this.planningContext.tools.length; index++) {
      const tool = this.planningContext.tools[index];
      if (tool.toolId === toolId) {
        return tool;
      }
    }
    return null;
  }

  private turnKey(message: AgentMessage): string {
    return this.turnKeyFor(message.conversationId, message.turnId);
  }

  private boundedObservations(values: Object[]): ObservationDigest[] {
    const result: ObservationDigest[] = [];
    const start: number = values.length > 8 ? values.length - 8 : 0;
    for (let index = start; index < values.length; index++) {
      const value = values[index];
      if (value === null || typeof value !== 'object' || Array.isArray(value)) {
        continue;
      }
      const fields = value as Record<string, Object | string | number | boolean | null | undefined>;
      const taskId = fields['taskId'];
      const toolId = fields['toolId'];
      const status = fields['status'];
      const summary = fields['summary'];
      const entityRefs = fields['entityRefs'];
      if (typeof taskId !== 'string' || typeof toolId !== 'string' ||
        typeof status !== 'string' || typeof summary !== 'string' || !Array.isArray(entityRefs)) {
        continue;
      }
      result.push({
        taskId: this.boundedText(taskId, 128),
        toolId: this.boundedText(toolId, 128),
        status: this.boundedText(status, 32),
        summary: this.boundedText(summary, 240),
        entityRefs: this.boundedStrings(entityRefs as Object[], 16, 128)
      });
    }
    return result;
  }

  private boundedStrings(values: Object[], maximum: number, length: number): string[] {
    const result: string[] = [];
    for (let index = 0; index < values.length && result.length < maximum; index++) {
      const value = values[index];
      if (typeof value === 'string' && value.trim().length > 0) {
        result.push(this.boundedText(value, length));
      }
    }
    return result;
  }

  private boundedText(value: string, maximum: number): string {
    const trimmed: string = value.trim();
    return trimmed.length > maximum ? trimmed.substring(0, maximum) : trimmed;
  }

  private publishUiTask(input: AgentMessage, task: LeaderUiTask, dataTaskId: string): void {
    const payload: CreateUiTaskPayload = {
      taskId: task.taskId,
      dataTaskIds: [dataTaskId],
      skillId: this.currentSkillId(input),
      intent: task.intent,
      expectedOutputSchema: task.expectedOutputSchema
    };
    this.bus.publish({
      type: AgentMessageType.TASK_CREATE_UI,
      conversationId: input.conversationId,
      turnId: input.turnId,
      taskId: task.taskId,
      payload
    });
  }

  private publishDataTask(input: AgentMessage, task: LeaderDataTask): void {
    const payload: CreateDataTaskPayload = {
      taskId: task.taskId,
      roundId: input.turnId,
      skillId: this.currentSkillId(input),
      goal: task.toolId,
      allowedToolIds: [task.toolId],
      toolId: task.toolId,
      outputSchema: task.outputSchema,
      args: task.args,
      required: true
    };
    this.bus.publish({
      type: AgentMessageType.TASK_CREATE_DATA,
      conversationId: input.conversationId,
      turnId: input.turnId,
      taskId: task.taskId,
      payload
    });
  }

  private publishDecisionDataTask(
    input: AgentMessage,
    state: LeaderTurnState,
    task: LeaderDecisionDataTask
  ): void {
    const definition: LeaderToolMetadata = this.toolMetadata(task.toolId) as LeaderToolMetadata;
    const taskId: string = state.inputTaskId + ':round-' + state.round.toString() + ':' + task.localId;
    const payload: CreateDataTaskPayload = {
      taskId,
      roundId: state.turnId + ':round-' + state.round.toString(),
      skillId: state.skillId,
      goal: task.goal,
      allowedToolIds: task.allowedToolIds.slice(),
      toolId: task.toolId,
      outputSchema: definition.outputSchema,
      args: task.input,
      required: task.required
    };
    state.pendingDataTools.set(taskId, {
      toolId: task.toolId,
      outputSchema: definition.outputSchema
    });
    this.bus.publish({
      type: AgentMessageType.TASK_CREATE_DATA,
      conversationId: input.conversationId,
      turnId: input.turnId,
      taskId,
      payload
    });
  }

  private decisionDataTaskIds(
    state: LeaderTurnState,
    tasks: LeaderDecisionDataTask[]
  ): string[] {
    const ids: string[] = [];
    for (let index = 0; index < tasks.length; index++) {
      ids.push(
        state.inputTaskId + ':round-' + state.round.toString() + ':' + tasks[index].localId
      );
    }
    return ids;
  }

  private publishDecisionUiTask(
    input: AgentMessage,
    state: LeaderTurnState,
    decision: LeaderDecision,
    taskId: string,
    dataTaskIds: string[]
  ): void {
    const first: LeaderDecisionDataTask = decision.dataTasks[0];
    const definition: LeaderToolMetadata = this.toolMetadata(first.toolId) as LeaderToolMetadata;
    const payload: CreateUiTaskPayload = {
      taskId,
      dataTaskIds: dataTaskIds.slice(),
      skillId: state.skillId,
      intent: decision.uiIntent.purpose,
      expectedOutputSchema: definition.outputSchema
    };
    state.uiTaskId = taskId;
    this.bus.publish({
      type: AgentMessageType.TASK_CREATE_UI,
      conversationId: input.conversationId,
      turnId: input.turnId,
      taskId,
      payload
    });
  }

  private publishActionPlanRequest(
    input: AgentMessage,
    decision: LeaderDecision,
    uiTaskId: string,
    dataTaskIds: string[],
    virtual: boolean
  ): void {
    const intent = decision.actionIntent as Object as Record<string, Object | string[]>;
    const payload: ActionPlanRequestPayload = {
      uiTaskId,
      dataTaskIds: dataTaskIds.slice(),
      goal: intent['goal'] as string,
      allowedActionIds: (intent['allowedActionIds'] as string[]).slice(),
      personaId: decision.personaId,
      inputText: (input.payload as InputUserPayload).text
    };
    if (virtual) {
      payload.virtual = true;
    }
    this.bus.publish({
      type: AgentMessageType.ACTION_PLAN_REQUEST,
      conversationId: input.conversationId,
      turnId: input.turnId,
      taskId: uiTaskId,
      payload
    });
  }

  private publishTurnResult(
    input: AgentMessage,
    state: LeaderTurnState,
    answer: string
  ): void {
    const payload: TurnResultPayload = {
      status: this.turnResultStatus(state),
      roundCount: state.round,
      message: answer
    };
    const surfaceId: string = state.input.currentSurfaceSummary?.surfaceId as string;
    if (typeof surfaceId === 'string' && surfaceId.length > 0) {
      payload.surfaceId = surfaceId;
    }
    this.bus.publish({
      type: AgentMessageType.TURN_RESULT,
      conversationId: input.conversationId,
      turnId: input.turnId,
      taskId: state.inputTaskId,
      payload
    });
  }

  private turnResultStatus(state: LeaderTurnState): 'success' | 'partial' | 'empty' | 'error' {
    if (state.turnObservations.length === 0) {
      return 'success';
    }
    let hasSuccess: boolean = false;
    let hasError: boolean = false;
    for (let index = 0; index < state.turnObservations.length; index++) {
      const status: string = state.turnObservations[index].status;
      if (status === 'partial') {
        return 'partial';
      }
      hasSuccess = hasSuccess || status === 'success';
      hasError = hasError || status === 'error';
    }
    if (hasSuccess) {
      return state.turnObservations.every((item: ObservationDigest): boolean =>
        item.status === 'success') ? 'success' : 'partial';
    }
    return hasError ? 'error' : 'empty';
  }

  private publishHandoff(input: AgentMessage, decision: LeaderDecision): void {
    const payload: LegacyHandoffPayload = {
      reasonCode: decision.reasonCode,
      personaId: decision.personaId,
      skillId: decision.skillId
    };
    this.bus.publish({
      type: AgentMessageType.TURN_HANDOFF,
      conversationId: input.conversationId,
      turnId: input.turnId,
      taskId: input.taskId,
      payload
    });
  }

  private currentSkillId(input: AgentMessage): string {
    const state: LeaderTurnState | undefined = this.turns.get(this.turnKey(input));
    if (state === undefined) {
      return '';
    }
    return state.skillId;
  }

  private copyPlanningContext(context: LeaderPlanningContext): LeaderPlanningContext {
    const tools: LeaderToolMetadata[] = [];
    const personas: LeaderPersonaMetadata[] = [];
    for (let index = 0; index < context.tools.length; index++) {
      const tool = context.tools[index];
      tools.push({
        toolId: tool.toolId,
        intent: tool.intent,
        riskLevel: tool.riskLevel,
        inputSchema: tool.inputSchema,
        outputSchema: tool.outputSchema,
        actions: tool.actions.slice()
      });
    }
    for (let index = 0; index < context.personas.length; index++) {
      const persona = context.personas[index];
      personas.push({
        personaId: persona.personaId,
        name: persona.name,
        soul: persona.soul,
        memory: persona.memory,
        previous: persona.previous,
        activeSkills: persona.activeSkills.map((skill: LeaderSkillMetadata): LeaderSkillMetadata => ({
          skillId: skill.skillId,
          description: skill.description,
          instructions: skill.instructions,
          status: skill.status
        }))
      });
    }
    const runtimeOwnedToolIds: string[] | undefined = context.runtimeOwnedToolIds === undefined ?
      undefined : context.runtimeOwnedToolIds.slice();
    return { tools, personas, runtimeOwnedToolIds };
  }

  private publishError(message: AgentMessage, code: string, detail: string): void {
    const payload: TaskErrorPayload = {
      code,
      message: detail
    };
    this.bus.publish({
      type: AgentMessageType.TASK_ERROR,
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: message.taskId,
      payload
    });
  }

  private timeoutTurn(key: string): void {
    const state: LeaderTurnState | undefined = this.turns.get(key);
    if (state === undefined || state.terminal) {
      return;
    }
    this.finishTurn(state);
    const payload: TaskErrorPayload = {
      code: 'LEADER_TURN_TIMEOUT',
      message: 'Leader turn timed out'
    };
    this.bus.publish({
      type: AgentMessageType.TASK_ERROR,
      conversationId: state.conversationId,
      turnId: state.turnId,
      taskId: state.inputTaskId,
      payload
    });
  }

  private finishTurn(state: LeaderTurnState): void {
    if (state.terminal) {
      return;
    }
    state.terminal = true;
    this.clearTurnTimer(state);
    this.releasePlanning(state);
    const key: string = this.turnKeyFor(state.conversationId, state.turnId);
    if (this.turns.get(key) === state) {
      this.turns.delete(key);
    }
    this.rememberTerminalTurn(key);
  }

  private clearTurnTimer(state: LeaderTurnState): void {
    if (state.timerId >= 0) {
      clearTimeout(state.timerId);
      state.timerId = -1;
    }
  }

  private releasePlanning(state: LeaderTurnState): void {
    const release: (() => void) | null = state.releasePlanning;
    state.releasePlanning = null;
    if (release !== null) {
      release();
    }
  }

  private rememberTerminalTurn(key: string): void {
    if (this.terminalTurns.has(key)) {
      return;
    }
    this.terminalTurns.add(key);
  }

  private turnKeyFor(conversationId: string, turnId: string): string {
    return `${conversationId.length}:${conversationId}${turnId}`;
  }
}
