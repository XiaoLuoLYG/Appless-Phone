import { MessageDrivenAgent } from '../MessageDrivenAgent';
import { CreateDataTaskPayload } from '../data/DataAgentTypes';
import { AgentMessage, AgentMessageType } from '../message/AgentMessage';
import { DataResult } from '../message/DataResult';
import { LinkedMessageBus } from '../message/LinkedMessageBus';
import { CreateUiTaskPayload, UiRenderResultPayload } from '../ui/UiAgentTypes';
import { ActionCatalog } from './ActionCatalog';
import { ActionCatalogResult } from './ActionCatalogTypes';
import {
  ActionExecutionResult,
  ActionFollowUp,
  ActionPlanDraftPayload,
  ActionPlanRequestPayload,
  ActionPlanReadyPayload,
  ActionProgressPayload,
  ActionResultPayload,
  ActionRunPayload,
  PausedActionRun,
  RegisteredActionExecutor,
  VIRTUAL_ACTION_INTENT_SOURCE_TOOL_ID,
  VirtualActionIntent,
  VirtualActionIntentResolver,
  WorkflowRunArgs
} from './ActionAgentTypes';
import {
  ActionOffer,
  ActionOfferContext,
  ActionOfferResolver,
  ActionOffersReadyPayload
} from './ActionOfferTypes';
import { ActionPlanRunner } from './ActionPlanRunner';
import {
  ActionExecutionContext,
  ActionPlan,
  ActionPlanCompiler,
  ActionPlanDraft,
  ActionPlanOutcome,
  ActionPlanPausedOutcome,
  ActionPlanRunContext,
  ActionPlanStepOutput,
  ActionStepExecutionResult,
  ActionStepExecutor,
  JsonValue
} from './ActionPlanTypes';
import { cloneJsonValue } from './JsonPointer';

const WORKFLOW_RUN_ACTION_ID: string = 'workflow.run';
const LIVE_RUN_LIMIT: number = 128;
let followUpTurnSequence: number = 0;

interface StoredActionRun {
  planId: string;
  runId: string;
  plan: ActionPlan;
  context: ActionPlanRunContext;
  taskId: string;
  followUpPublished: boolean;
}

interface ActiveActionRun {
  stored: StoredActionRun;
  canceled: boolean;
  followUpPublished: boolean;
  completedStepIds: string[];
  outputs: ActionPlanStepOutput[];
  generation: number;
}

interface RunIdentityResult {
  ok: boolean;
  planId: string;
  runId: string;
  errorCode: string;
  message: string;
}

interface SanitizedFollowUp {
  uiTask: CreateUiTaskPayload;
  dataTask: CreateDataTaskPayload;
}

interface ObservedDataTask {
  conversationId: string;
  turnId: string;
  taskId: string;
  toolId: string;
  outputSchema: string;
  generation: number;
  token: number;
  resolving: boolean;
}

interface StoredActionDraft {
  conversationId: string;
  turnId: string;
  taskId: string;
  uiTaskId: string;
  dataTaskId: string;
  sourceToolId: string;
  draft: ActionPlanDraft;
}

interface StoredAvailableOffers {
  sourceToolId: string;
  offers: ActionOffer[];
}

interface StoredPlanRequest {
  message: AgentMessage;
  request: ActionPlanRequestPayload;
  compiling: boolean;
  generation: number;
}

interface MatchedActionOffer {
  dataTaskId: string;
  sourceToolId: string;
  offer: ActionOffer;
}

interface DirectSurfaceAuthorization {
  conversationId: string;
  turnId: string;
  taskId: string;
  surfaceId: string;
  sourceToolId: string;
  runId: string;
  actionId: string;
  args: Object;
  pageActionId: string;
  confirmed: boolean;
  generation: number;
}

function nonempty(value: string | undefined): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function copyContext(context: ActionPlanRunContext): ActionPlanRunContext {
  const copy: ActionPlanRunContext = {
    conversationId: context.conversationId,
    turnId: context.turnId,
    surfaceId: context.surfaceId,
    sourceToolId: context.sourceToolId,
    planId: context.planId,
    runId: context.runId
  };
  if (context.pageActionId !== undefined && context.pageActionId.length > 0) {
    copy.pageActionId = context.pageActionId;
  }
  if (context.virtualAction === true) {
    copy.virtualAction = true;
  }
  return copy;
}

function clonePlan(plan: ActionPlan): ActionPlan | null {
  const cloned = cloneJsonValue(plan as Object);
  if (!cloned.ok ||
    cloned.value === null ||
    typeof cloned.value !== 'object' ||
    Array.isArray(cloned.value)) {
    return null;
  }
  return cloned.value as ActionPlan;
}

function cloneDraft(draft: ActionPlanDraft): ActionPlanDraft | null {
  const cloned = cloneJsonValue(draft as Object);
  if (!cloned.ok || cloned.value === null || typeof cloned.value !== 'object' ||
    Array.isArray(cloned.value)) {
    return null;
  }
  return cloned.value as ActionPlanDraft;
}

function cloneOutputs(outputs: ActionPlanStepOutput[]): ActionPlanStepOutput[] | null {
  const cloned = cloneJsonValue(outputs as Object);
  if (!cloned.ok || !Array.isArray(cloned.value)) {
    return null;
  }
  return cloned.value as ActionPlanStepOutput[];
}

function sameJson(left: JsonValue | undefined, right: JsonValue | undefined): boolean {
  if (left === null || right === null ||
    typeof left !== 'object' || typeof right !== 'object') {
    return left === right;
  }
  if (Array.isArray(left) || Array.isArray(right)) {
    if (!Array.isArray(left) || !Array.isArray(right) || left.length !== right.length) {
      return false;
    }
    const leftItems = left as JsonValue[];
    const rightItems = right as JsonValue[];
    for (let index = 0; index < leftItems.length; index++) {
      if (!sameJson(leftItems[index], rightItems[index])) {
        return false;
      }
    }
    return true;
  }
  const leftKeys = Object.keys(left).sort();
  const rightKeys = Object.keys(right).sort();
  if (leftKeys.join(',') !== rightKeys.join(',')) {
    return false;
  }
  const leftRecord = left as Record<string, JsonValue | undefined>;
  const rightRecord = right as Record<string, JsonValue | undefined>;
  for (let index = 0; index < leftKeys.length; index++) {
    if (!sameJson(leftRecord[leftKeys[index]], rightRecord[leftKeys[index]])) {
      return false;
    }
  }
  return true;
}

function directPlan(
  message: AgentMessage,
  payload: ActionRunPayload
): ActionPlan {
  return {
    planId: `direct:${payload.runId}`,
    turnId: message.turnId,
    surfaceId: payload.surfaceId,
    label: payload.actionId,
    steps: [{
      stepId: 'step-1',
      actionId: payload.actionId,
      args: payload.args
    }]
  };
}

export class ActionAgent extends MessageDrivenAgent implements ActionStepExecutor {
  private readonly bus: LinkedMessageBus;
  private readonly catalog: ActionCatalog;
  private readonly offerResolver: ActionOfferResolver;
  private readonly registeredExecutor: RegisteredActionExecutor;
  private readonly compiler: ActionPlanCompiler | null;
  private readonly virtualResolver: VirtualActionIntentResolver | null;
  private readonly runner: ActionPlanRunner;
  private readonly readyRuns: Map<string, StoredActionRun> =
    new Map<string, StoredActionRun>();
  private readonly pausedRuns: Map<string, PausedActionRun> =
    new Map<string, PausedActionRun>();
  private readonly activeRuns: Map<string, ActiveActionRun> =
    new Map<string, ActiveActionRun>();
  // Compact identities intentionally live for this ActionAgent session. Evicting
  // them would allow an old write or confirmed workflow to execute twice.
  private readonly terminalRuns: Set<string> = new Set<string>();
  private readonly canceledTurns: Set<string> = new Set<string>();
  private readonly observedDataTasks: Map<string, ObservedDataTask> =
    new Map<string, ObservedDataTask>();
  private readonly pendingDrafts: Map<string, StoredActionDraft> =
    new Map<string, StoredActionDraft>();
  private readonly availableOffers: Map<string, StoredAvailableOffers> =
    new Map<string, StoredAvailableOffers>();
  private readonly pendingPlanRequests: Map<string, StoredPlanRequest> =
    new Map<string, StoredPlanRequest>();
  private readonly terminalPlanRequests: Set<string> = new Set<string>();
  private readonly terminalPlanRequestOrder: string[] = [];
  private readonly uiSurfaces: Map<string, string> = new Map<string, string>();
  private readonly directSurfaceAuthorizations: Map<string, DirectSurfaceAuthorization> =
    new Map<string, DirectSurfaceAuthorization>();
  private generation: number = 0;
  private observationSequence: number = 0;
  private active: boolean = false;

  constructor(
    bus: LinkedMessageBus,
    catalog: ActionCatalog,
    offerResolver: ActionOfferResolver,
    executor: RegisteredActionExecutor,
    compiler?: ActionPlanCompiler,
    virtualResolver?: VirtualActionIntentResolver
  ) {
    super(bus);
    this.bus = bus;
    this.catalog = catalog;
    this.offerResolver = offerResolver;
    this.registeredExecutor = executor;
    this.compiler = compiler === undefined ? null : compiler;
    this.virtualResolver = virtualResolver === undefined ? null : virtualResolver;
    this.runner = new ActionPlanRunner(catalog, this);
  }

  start(): void {
    if (this.active) {
      return;
    }
    this.active = true;
    this.generation++;
    super.start();
  }

  stop(): void {
    this.active = false;
    this.generation++;
    super.stop();
    this.readyRuns.clear();
    this.pausedRuns.clear();
    this.activeRuns.clear();
    this.terminalRuns.clear();
    this.canceledTurns.clear();
    this.observedDataTasks.clear();
    this.pendingDrafts.clear();
    this.availableOffers.clear();
    this.pendingPlanRequests.clear();
    this.terminalPlanRequests.clear();
    this.terminalPlanRequestOrder.splice(0, this.terminalPlanRequestOrder.length);
    this.uiSurfaces.clear();
    this.directSurfaceAuthorizations.clear();
  }

  authorizeDirectSurfaceRun(message: AgentMessage, pageActionId: string = ''): boolean {
    if (!this.active || message.type !== AgentMessageType.ACTION_RUN) {
      return false;
    }
    const payload = this.actionRunPayload(message.payload);
    if (payload === null || payload.actionId === WORKFLOW_RUN_ACTION_ID ||
      payload.confirmedStepId !== undefined || !nonempty(payload.sourceToolId)) {
      return false;
    }
    const exactPageActionId = pageActionId.trim();
    const current = exactPageActionId.length > 0 ?
      this.catalog.validatePageExecution(
        message.conversationId,
        message.turnId,
        payload.surfaceId,
        payload.actionId,
        payload.args
      ) :
      this.catalog.validateSurfaceExecution(
        message.conversationId,
        message.turnId,
        payload.surfaceId,
        payload.sourceToolId as string,
        payload.actionId,
        payload.args
      );
    if (!current.ok || current.definition === null) {
      return false;
    }
    const confirmed = current.definition.riskLevel === 'confirm_required';
    if (!confirmed && exactPageActionId.length === 0) {
      return true;
    }
    const key = this.runKey(
      message.conversationId,
      message.turnId,
      payload.surfaceId,
      payload.runId
    );
    if (this.runExists(key) || this.directSurfaceAuthorizations.has(key) ||
      this.directSurfaceAuthorizations.size >= LIVE_RUN_LIMIT) {
      return false;
    }
    const cloned = cloneJsonValue(payload.args as Object);
    if (!cloned.ok || cloned.value === null || typeof cloned.value !== 'object' ||
      Array.isArray(cloned.value)) {
      return false;
    }
    this.directSurfaceAuthorizations.set(key, {
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: message.taskId,
      surfaceId: payload.surfaceId,
      sourceToolId: payload.sourceToolId as string,
      runId: payload.runId,
      actionId: payload.actionId,
      args: cloned.value as Object,
      pageActionId: exactPageActionId,
      confirmed,
      generation: this.generation
    });
    return true;
  }

  inspectPausedRun(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    runId: string
  ): PausedActionRun | null {
    const paused = this.pausedRuns.get(
      this.runKey(conversationId, turnId, surfaceId, runId)
    );
    if (paused === undefined) {
      return null;
    }
    const cloned = cloneJsonValue(paused as Object);
    if (!cloned.ok ||
      cloned.value === null ||
      typeof cloned.value !== 'object' ||
      Array.isArray(cloned.value)) {
      return null;
    }
    return cloned.value as PausedActionRun;
  }

  protected accepts(message: AgentMessage): boolean {
    return message.type === AgentMessageType.ACTION_PLAN_REQUEST ||
      message.type === AgentMessageType.ACTION_PLAN_DRAFT ||
      message.type === AgentMessageType.TASK_CREATE_DATA ||
      message.type === AgentMessageType.TASK_RESULT_UI ||
      message.type === AgentMessageType.TASK_RESULT_DATA ||
      message.type === AgentMessageType.TASK_ERROR ||
      message.type === AgentMessageType.ACTION_RUN ||
      message.type === AgentMessageType.TURN_CANCEL;
  }

  protected async process(message: AgentMessage): Promise<void> {
    try {
      if (message.type === AgentMessageType.TURN_CANCEL) {
        this.cancelTurn(message);
        return;
      }
      if (this.canceledTurns.has(this.turnKey(message.conversationId, message.turnId))) {
        return;
      }
      if (message.type === AgentMessageType.TASK_CREATE_DATA) {
        this.observeDataTask(message);
        return;
      }
      if (message.type === AgentMessageType.ACTION_PLAN_REQUEST) {
        this.storePlanRequest(message);
        return;
      }
      if (message.type === AgentMessageType.TASK_RESULT_DATA ||
        message.type === AgentMessageType.TASK_ERROR) {
        this.startOfferResolution(message);
        return;
      }
      if (message.type === AgentMessageType.ACTION_PLAN_DRAFT) {
        this.storeDraft(message);
        return;
      }
      if (message.type === AgentMessageType.TASK_RESULT_UI) {
        this.bindDrafts(message);
        return;
      }
      this.startRun(message);
    } catch (_error) {
      this.publishInputError(
        message,
        '',
        this.payloadString(message.payload, 'runId'),
        this.payloadString(message.payload, 'surfaceId'),
        'ACTION_AGENT_MESSAGE_FAILED',
        'Action agent rejected a malformed message.'
      );
    }
  }

  async execute(
    actionId: string,
    args: Object,
    context: ActionExecutionContext
  ): Promise<ActionStepExecutionResult> {
    const key = this.runKey(
      context.conversationId,
      context.turnId,
      context.surfaceId,
      context.runId
    );
    const active = this.activeRuns.get(key);
    if (!this.matchesExecution(active, actionId, context)) {
      return {
        status: 'canceled',
        errorCode: 'ACTION_RUN_INACTIVE',
        message: 'Action run is no longer active.'
      };
    }
    this.publishProgress(active as ActiveActionRun, context, actionId, 'running');
    const current = this.catalogImmediatelyBeforeInvoke(
      active as ActiveActionRun,
      context,
      actionId,
      args
    );
    if (!current.ok) {
      return {
        status: 'error',
        errorCode: current.code,
        message: current.message
      };
    }
    let raw: ActionExecutionResult;
    try {
      raw = await this.registeredExecutor.execute(actionId, args, context);
    } catch (_error) {
      return {
        status: 'error',
        errorCode: 'ACTION_EXECUTOR_FAILED',
        message: 'Registered action executor failed.'
      };
    }
    const stillActive = this.activeRuns.get(key);
    if (stillActive !== active ||
      stillActive === undefined ||
      stillActive.canceled ||
      !this.active ||
      stillActive.generation !== this.generation) {
      return {
        status: 'canceled',
        errorCode: 'ACTION_RUN_CANCELED',
        message: 'Action run was canceled.'
      };
    }
    const cloned = cloneJsonValue(raw as Object);
    if (!cloned.ok ||
      cloned.value === null ||
      typeof cloned.value !== 'object' ||
      Array.isArray(cloned.value)) {
      return {
        status: 'error',
        errorCode: 'ACTION_EXECUTOR_RESULT_INVALID',
        message: 'Registered action executor returned an invalid result.'
      };
    }
    const result = cloned.value as ActionExecutionResult;
    if (result.status === 'success') {
      if (result.output === undefined) {
        return {
          status: 'error',
          errorCode: 'ACTION_OUTPUT_INVALID',
          message: 'Registered action output is invalid.'
        };
      }
      if (result.followUp !== undefined) {
        const followUpError = this.publishFollowUp(stillActive, result.followUp);
        if (followUpError !== null) {
          return followUpError;
        }
      }
      const outputClone = cloneJsonValue(result.output);
      if (!outputClone.ok || outputClone.value === undefined) {
        return {
          status: 'error',
          errorCode: 'ACTION_OUTPUT_INVALID',
          message: 'Registered action output is invalid.'
        };
      }
      stillActive.completedStepIds.push(context.stepId);
      stillActive.outputs.push({
        stepId: context.stepId,
        output: outputClone.value as JsonValue
      });
      this.publishProgress(stillActive, context, actionId, 'success');
      return {
        status: 'success',
        output: result.output
      };
    }
    if ((result.status === 'canceled' || result.status === 'error') &&
      typeof result.errorCode === 'string' &&
      typeof result.message === 'string') {
      return {
        status: result.status,
        errorCode: result.errorCode,
        message: result.message
      };
    }
    return {
      status: 'error',
      errorCode: 'ACTION_EXECUTOR_RESULT_INVALID',
      message: 'Registered action executor returned an unknown result.'
    };
  }

  private observeDataTask(message: AgentMessage): void {
    const task = this.dataTask(message.payload, message.taskId);
    if (task === null || this.observedDataTasks.size >= LIVE_RUN_LIMIT) {
      return;
    }
    const key = this.dataTaskKey(message.conversationId, message.turnId, message.taskId);
    if (!this.observedDataTasks.has(key)) {
      this.observationSequence++;
      this.observedDataTasks.set(key, {
        conversationId: message.conversationId,
        turnId: message.turnId,
        taskId: message.taskId,
        toolId: task.toolId,
        outputSchema: task.outputSchema,
        generation: this.generation,
        token: this.observationSequence,
        resolving: false
      });
    }
  }

  private startOfferResolution(message: AgentMessage): void {
    const key = this.dataTaskKey(message.conversationId, message.turnId, message.taskId);
    const observed = this.observedDataTasks.get(key);
    if (observed === undefined || observed.resolving) {
      return;
    }
    observed.resolving = true;
    if (message.type === AgentMessageType.TASK_ERROR) {
      this.finishOfferResolution(key, message, observed, []);
      return;
    }
    const data = this.dataResult(message.payload, observed);
    if (data === null) {
      this.finishOfferResolution(key, message, observed, []);
      return;
    }
    const context: ActionOfferContext = {
      conversationId: message.conversationId,
      turnId: message.turnId,
      dataTaskId: message.taskId
    };
    try {
      this.offerResolver(data, context).then((resolved: ActionOffer[]) => {
        this.finishOfferResolution(
          key,
          message,
          observed,
          this.sanitizeOffers(data.toolId, resolved)
        );
      }).catch((_error: Object) => {
        this.finishOfferResolution(key, message, observed, []);
      });
    } catch (_error) {
      this.finishOfferResolution(key, message, observed, []);
    }
  }

  private finishOfferResolution(
    key: string,
    message: AgentMessage,
    observed: ObservedDataTask,
    offers: ActionOffer[]
  ): void {
    const current = this.observedDataTasks.get(key);
    if (!this.active || observed.generation !== this.generation ||
      current !== observed || current.token !== observed.token ||
      this.canceledTurns.has(this.turnKey(observed.conversationId, observed.turnId))) {
      return;
    }
    this.observedDataTasks.delete(key);
    this.publishOffers(message, observed, offers);
  }

  private publishOffers(
    message: AgentMessage,
    observed: ObservedDataTask,
    offers: ActionOffer[]
  ): void {
    if (!this.rememberAvailableOffers(message, observed, offers)) {
      this.publishInputError(
        message, '', '', '', 'ACTION_STATE_CAPACITY',
        'Action agent live state capacity is exhausted.'
      );
    }
    const payload: ActionOffersReadyPayload = {
      dataTaskId: observed.taskId,
      sourceToolId: observed.toolId,
      offers
    };
    this.bus.publish({
      type: AgentMessageType.ACTION_OFFERS_READY,
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: observed.taskId,
      payload
    });
    this.compileReadyRequests(message.conversationId, message.turnId);
  }

  private sanitizeOffers(sourceToolId: string, candidates: ActionOffer[]): ActionOffer[] {
    if (!Array.isArray(candidates)) {
      return [];
    }
    const safe: ActionOffer[] = [];
    const ids: Set<string> = new Set<string>();
    for (let index = 0; index < candidates.length; index++) {
      const candidate = candidates[index];
      if (candidate === null || typeof candidate !== 'object' ||
        !nonempty(candidate.offerId) || ids.has(candidate.offerId) ||
        !nonempty(candidate.actionId) || !nonempty(candidate.label) ||
        !nonempty(candidate.variant) || candidate.args === null ||
        typeof candidate.args !== 'object' || Array.isArray(candidate.args)) {
        continue;
      }
      const cloned = cloneJsonValue(candidate.args);
      if (!cloned.ok || cloned.value === null || typeof cloned.value !== 'object' ||
        Array.isArray(cloned.value)) {
        continue;
      }
      const args = cloned.value as Object;
      if (!this.catalog.validatePlacement(sourceToolId, candidate.actionId, args).ok) {
        continue;
      }
      ids.add(candidate.offerId);
      safe.push({
        offerId: candidate.offerId,
        actionId: candidate.actionId,
        label: candidate.label,
        variant: candidate.variant,
        args
      });
    }
    return safe;
  }

  private rememberAvailableOffers(
    message: AgentMessage,
    observed: ObservedDataTask,
    offers: ActionOffer[]
  ): boolean {
    const cloned = cloneJsonValue(offers as Object);
    if (!cloned.ok || !Array.isArray(cloned.value)) {
      return true;
    }
    const key = this.dataTaskKey(message.conversationId, message.turnId, observed.taskId);
    if (!this.hasLiveStateCapacity(
      this.availableOffers.size,
      this.availableOffers.has(key)
    )) {
      return false;
    }
    this.availableOffers.set(key, {
      sourceToolId: observed.toolId,
      offers: cloned.value as ActionOffer[]
    });
    return true;
  }

  private storePlanRequest(message: AgentMessage): void {
    const parsed = this.planRequestPayload(message.payload);
    if (parsed === null) {
      this.publishInputError(
        message, '', '', '', 'ACTION_PLAN_REQUEST_INVALID',
        'Action plan request payload is malformed.'
      );
      return;
    }
    const request: ActionPlanRequestPayload = {
      uiTaskId: parsed.uiTaskId,
      dataTaskIds: parsed.dataTaskIds.slice(),
      goal: parsed.goal,
      allowedActionIds: parsed.allowedActionIds.slice(),
      skillId: parsed.skillId
    };
    if (parsed.personaId !== undefined) {
      request.personaId = parsed.personaId;
    }
    if (parsed.inputText !== undefined) {
      request.inputText = parsed.inputText;
    }
    if (parsed.currentLocalDate !== undefined) {
      request.currentLocalDate = parsed.currentLocalDate;
    }
    if (parsed.virtual !== undefined) {
      request.virtual = parsed.virtual;
    }
    const key = this.planRequestKey(
      message.conversationId,
      message.turnId,
      request.uiTaskId
    );
    if (this.pendingPlanRequests.has(key) || this.terminalPlanRequests.has(key)) {
      this.publishInputError(
        message, '', '', '', 'ACTION_PLAN_REQUEST_DUPLICATE',
        'Action plan request identity already exists.'
      );
      return;
    }
    for (let index = 0; index < request.allowedActionIds.length; index++) {
      const current = this.catalog.validateRegisteredAction(request.allowedActionIds[index]);
      if (!current.ok) {
        this.rememberTerminalPlanRequest(key);
        this.publishInputError(message, '', '', '', current.code, current.message);
        return;
      }
    }
    if (this.pendingPlanRequests.size >= LIVE_RUN_LIMIT) {
      this.publishInputError(
        message, '', '', '', 'ACTION_STATE_CAPACITY',
        'Action agent live state capacity is exhausted.'
      );
      return;
    }
    const storedMessage: AgentMessage = {
      type: message.type,
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: message.taskId,
      payload: request
    };
    const stored: StoredPlanRequest = {
      message: storedMessage,
      request,
      compiling: false,
      generation: this.generation
    };
    this.pendingPlanRequests.set(key, stored);
    if (request.dataTaskIds.length === 0) {
      if (this.virtualResolver === null) {
        this.pendingPlanRequests.delete(key);
        this.rememberTerminalPlanRequest(key);
        this.publishInputError(
          message, '', '', '', 'ACTION_VIRTUAL_INTENT_UNAVAILABLE',
          'No virtual Action resolver owns this request.'
        );
        return;
      }
      this.startVirtualResolution(key, stored);
      return;
    }
    if (this.compiler === null) {
      this.pendingPlanRequests.delete(key);
      this.rememberTerminalPlanRequest(key);
      this.publishInputError(
        message, '', '', '', 'ACTION_PLAN_COMPILER_UNAVAILABLE',
        'Action plan compiler is unavailable.'
      );
      return;
    }
    this.startCompilation(key, stored);
  }

  private startVirtualResolution(key: string, stored: StoredPlanRequest): void {
    const resolver: VirtualActionIntentResolver | null = this.virtualResolver;
    if (resolver === null || stored.compiling || !this.compilationIsActive(key, stored)) {
      return;
    }
    stored.compiling = true;
    try {
      resolver.resolve(stored.request).then((intent: VirtualActionIntent | null) => {
        this.finishVirtualResolution(key, stored, intent);
      }).catch((_error: Object) => {
        this.finishVirtualResolution(key, stored, null);
      });
    } catch (_error) {
      this.finishVirtualResolution(key, stored, null);
    }
  }

  private finishVirtualResolution(
    key: string,
    stored: StoredPlanRequest,
    intent: VirtualActionIntent | null
  ): void {
    if (!this.compilationIsActive(key, stored)) {
      return;
    }
    this.pendingPlanRequests.delete(key);
    this.rememberTerminalPlanRequest(key);
    if (intent === null || typeof intent !== 'object' || Array.isArray(intent) ||
      Object.keys(intent).sort().join(',') !== 'autoRun,offer,sourceToolId' ||
      intent.autoRun !== true || !nonempty(intent.sourceToolId) ||
      intent.offer === null || typeof intent.offer !== 'object' || Array.isArray(intent.offer) ||
      stored.request.allowedActionIds.indexOf(intent.offer.actionId) < 0) {
      this.publishInputError(
        stored.message, '', '', '', 'ACTION_VIRTUAL_INTENT_INVALID',
        'Virtual Action resolver returned an invalid intent.'
      );
      return;
    }
    const actionIntent = intent.sourceToolId === VIRTUAL_ACTION_INTENT_SOURCE_TOOL_ID;
    let offer: ActionOffer | null = null;
    if (actionIntent) {
      offer = this.sanitizeActionIntentOffer(intent.offer);
    } else {
      const placed = this.sanitizeOffers(intent.sourceToolId, [intent.offer]);
      offer = placed.length === 1 ? placed[0] : null;
    }
    if (offer === null) {
      this.publishInputError(
        stored.message, '', '', '', 'ACTION_VIRTUAL_INTENT_INVALID',
        'Virtual Action resolver returned an unauthorized offer.'
      );
      return;
    }
    const payload: ActionRunPayload = {
      surfaceId: 'virtual:' + stored.message.taskId,
      runId: 'virtual:' + stored.message.taskId,
      sourceToolId: intent.sourceToolId,
      actionId: offer.actionId,
      args: offer.args
    };
    this.startDirectRun(stored.message, payload, actionIntent);
  }

  private sanitizeActionIntentOffer(candidate: ActionOffer): ActionOffer | null {
    if (candidate === null || typeof candidate !== 'object' ||
      !nonempty(candidate.offerId) || !nonempty(candidate.actionId) ||
      !nonempty(candidate.label) || !nonempty(candidate.variant) ||
      candidate.args === null || typeof candidate.args !== 'object' ||
      Array.isArray(candidate.args)) {
      return null;
    }
    const cloned = cloneJsonValue(candidate.args);
    if (!cloned.ok || cloned.value === null || typeof cloned.value !== 'object' ||
      Array.isArray(cloned.value)) {
      return null;
    }
    const args = cloned.value as Object;
    if (!this.catalog.validateActionIntentExecution(candidate.actionId, args).ok) {
      return null;
    }
    return {
      offerId: candidate.offerId,
      actionId: candidate.actionId,
      label: candidate.label,
      variant: candidate.variant,
      args
    };
  }

  private compileReadyRequests(conversationId: string, turnId: string): void {
    const matches: string[] = [];
    this.pendingPlanRequests.forEach((stored: StoredPlanRequest, key: string) => {
      if (stored.message.conversationId === conversationId &&
        stored.message.turnId === turnId) {
        matches.push(key);
      }
    });
    for (let index = 0; index < matches.length; index++) {
      const stored = this.pendingPlanRequests.get(matches[index]);
      if (stored !== undefined) {
        this.startCompilation(matches[index], stored);
      }
    }
  }

  private startCompilation(key: string, stored: StoredPlanRequest): void {
    if (stored.compiling || this.pendingPlanRequests.get(key) !== stored ||
      stored.generation !== this.generation || !this.active) {
      return;
    }
    const matches: MatchedActionOffer[] = [];
    for (let taskIndex = 0; taskIndex < stored.request.dataTaskIds.length; taskIndex++) {
      const dataTaskId = stored.request.dataTaskIds[taskIndex];
      const available = this.availableOffers.get(this.dataTaskKey(
        stored.message.conversationId,
        stored.message.turnId,
        dataTaskId
      ));
      if (available === undefined) {
        return;
      }
      for (let offerIndex = 0; offerIndex < available.offers.length; offerIndex++) {
        const offer = available.offers[offerIndex];
        if (stored.request.allowedActionIds.indexOf(offer.actionId) >= 0) {
          matches.push({
            dataTaskId,
            sourceToolId: available.sourceToolId,
            offer
          });
        }
      }
    }
    const compiler = this.compiler;
    if (compiler === null) {
      return;
    }
    const offers: ActionOffer[] = [];
    for (let index = 0; index < matches.length; index++) {
      const cloned = cloneJsonValue(matches[index].offer as Object);
      if (!cloned.ok || cloned.value === null || typeof cloned.value !== 'object' ||
        Array.isArray(cloned.value)) {
        this.finishCompilationError(key, stored, 'ACTION_PLAN_OFFERS_INVALID');
        return;
      }
      offers.push(cloned.value as ActionOffer);
    }
    stored.compiling = true;
    try {
      compiler.compile(
        stored.request.goal,
        offers,
        stored.request.allowedActionIds.slice()
      ).then((draft: ActionPlanDraft) => {
        this.finishCompilation(key, stored, matches, draft);
      }).catch((_error: Object) => {
        this.finishCompilationError(key, stored, 'ACTION_PLAN_COMPILE_FAILED');
      });
    } catch (_error) {
      this.finishCompilationError(key, stored, 'ACTION_PLAN_COMPILE_FAILED');
    }
  }

  private finishCompilation(
    key: string,
    stored: StoredPlanRequest,
    offers: MatchedActionOffer[],
    candidate: ActionPlanDraft
  ): void {
    if (!this.compilationIsActive(key, stored)) {
      return;
    }
    this.pendingPlanRequests.delete(key);
    this.rememberTerminalPlanRequest(key);
    const draft = cloneDraft(candidate);
    if (draft === null || !this.validDraft(draft)) {
      this.publishInputError(
        stored.message, '', '', '', 'ACTION_PLAN_MALFORMED',
        'Compiled action plan is malformed.'
      );
      return;
    }
    let entry: MatchedActionOffer | null = null;
    for (let stepIndex = 0; stepIndex < draft.steps.length; stepIndex++) {
      const step = draft.steps[stepIndex];
      const args = step.args === undefined ? new Object() : step.args;
      let matched: MatchedActionOffer | null = null;
      for (let offerIndex = 0; offerIndex < offers.length; offerIndex++) {
        if (offers[offerIndex].offer.actionId === step.actionId &&
          sameJson(offers[offerIndex].offer.args as JsonValue, args as JsonValue)) {
          matched = offers[offerIndex];
          break;
        }
      }
      if (matched === null) {
        this.publishInputError(
          stored.message, draft.planId, draft.runId, '',
          'ACTION_PLAN_OFFER_MISMATCH',
          'Compiled action steps must match current immutable offers.',
          step.stepId
        );
        return;
      }
      if (stepIndex === 0) {
        entry = matched;
      }
    }
    const first = entry as MatchedActionOffer;
    const validation = this.runner.validateDraft(draft, first.sourceToolId);
    if (!validation.ok) {
      this.publishInputError(
        stored.message,
        draft.planId,
        draft.runId,
        '',
        validation.errorCode,
        validation.message,
        validation.failedStepId
      );
      return;
    }
    const payload: ActionPlanDraftPayload = {
      uiTaskId: stored.request.uiTaskId,
      dataTaskId: first.dataTaskId,
      sourceToolId: first.sourceToolId,
      draft
    };
    this.bus.publish({
      type: AgentMessageType.ACTION_PLAN_DRAFT,
      conversationId: stored.message.conversationId,
      turnId: stored.message.turnId,
      taskId: stored.message.taskId,
      payload
    });
  }

  private finishCompilationError(
    key: string,
    stored: StoredPlanRequest,
    errorCode: string
  ): void {
    if (!this.compilationIsActive(key, stored)) {
      return;
    }
    this.pendingPlanRequests.delete(key);
    this.rememberTerminalPlanRequest(key);
    this.publishInputError(
      stored.message, '', '', '', errorCode,
      errorCode === 'ACTION_PLAN_COMPILE_FAILED' ?
        'Action plan compiler failed.' : 'Action plan offers are invalid.'
    );
  }

  private compilationIsActive(key: string, stored: StoredPlanRequest): boolean {
    return this.active && stored.generation === this.generation &&
      this.pendingPlanRequests.get(key) === stored &&
      !this.canceledTurns.has(this.turnKey(
        stored.message.conversationId,
        stored.message.turnId
      ));
  }

  private storeDraft(message: AgentMessage): void {
    const payload = this.planDraftPayload(message.payload);
    if (payload === null) {
      this.publishInputError(
        message,
        this.nestedPayloadString(message.payload, 'draft', 'planId'),
        this.nestedPayloadString(message.payload, 'draft', 'runId'),
        '',
        'ACTION_PLAN_DRAFT_INVALID',
        'Action plan draft payload is malformed.'
      );
      return;
    }
    const draft = cloneDraft(payload.draft);
    if (draft === null || !this.validDraft(draft)) {
      this.publishInputError(
        message,
        this.payloadString(payload.draft as Object, 'planId'),
        this.payloadString(payload.draft as Object, 'runId'),
        '',
        'ACTION_PLAN_MALFORMED',
        'Action plan draft is not valid JSON data.'
      );
      return;
    }
    const key = this.draftKey(message.conversationId, message.turnId, payload.uiTaskId, draft.runId);
    if (this.pendingDrafts.has(key)) {
      this.publishInputError(
        message,
        draft.planId,
        draft.runId,
        '',
        'ACTION_RUN_DUPLICATE',
        'Action run identity already exists.'
      );
      return;
    }
    if (this.pendingDrafts.size >= LIVE_RUN_LIMIT) {
      this.publishInputError(
        message,
        draft.planId,
        draft.runId,
        '',
        'ACTION_STATE_CAPACITY',
        'Action agent live state capacity is exhausted.'
      );
      return;
    }
    const stored: StoredActionDraft = {
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: message.taskId,
      uiTaskId: payload.uiTaskId,
      dataTaskId: payload.dataTaskId,
      sourceToolId: payload.sourceToolId,
      draft
    };
    this.pendingDrafts.set(key, stored);
    const surfaceId = this.uiSurfaces.get(this.uiSurfaceKey(
      message.conversationId,
      message.turnId,
      payload.uiTaskId
    ));
    if (surfaceId !== undefined) {
      this.bindDraft(stored, surfaceId);
    }
  }

  private bindDrafts(message: AgentMessage): void {
    const ui = this.uiResult(message.payload);
    if (ui === null || ui.state !== 'result') {
      return;
    }
    if (!this.rememberUiSurface(message, ui.surfaceId)) {
      this.publishInputError(
        message, '', '', ui.surfaceId, 'ACTION_STATE_CAPACITY',
        'Action agent live state capacity is exhausted.'
      );
    }
    const matches: StoredActionDraft[] = [];
    this.pendingDrafts.forEach((stored: StoredActionDraft) => {
      if (stored.conversationId === message.conversationId &&
        stored.turnId === message.turnId && stored.uiTaskId === message.taskId) {
        matches.push(stored);
      }
    });
    for (let index = 0; index < matches.length; index++) {
      this.bindDraft(matches[index], ui.surfaceId);
    }
  }

  private rememberUiSurface(message: AgentMessage, surfaceId: string): boolean {
    const key = this.uiSurfaceKey(message.conversationId, message.turnId, message.taskId);
    const current = this.uiSurfaces.get(key);
    if (current !== undefined) {
      return true;
    }
    if (!this.hasLiveStateCapacity(this.uiSurfaces.size, false)) {
      return false;
    }
    this.uiSurfaces.set(key, surfaceId);
    return true;
  }

  private bindDraft(storedDraft: StoredActionDraft, surfaceId: string): void {
    this.pendingDrafts.delete(this.draftKey(
      storedDraft.conversationId,
      storedDraft.turnId,
      storedDraft.uiTaskId,
      storedDraft.draft.runId
    ));
    const plan: ActionPlan = {
      planId: storedDraft.draft.planId,
      turnId: storedDraft.turnId,
      surfaceId,
      label: storedDraft.draft.label,
      steps: storedDraft.draft.steps
    };
    const context: ActionPlanRunContext = {
      conversationId: storedDraft.conversationId,
      turnId: storedDraft.turnId,
      surfaceId,
      sourceToolId: storedDraft.sourceToolId,
      planId: plan.planId,
      runId: storedDraft.draft.runId
    };
    const validation = this.runner.validate(plan, context);
    if (!validation.ok) {
      this.publishInputError(
        this.draftMessage(storedDraft),
        plan.planId,
        storedDraft.draft.runId,
        surfaceId,
        validation.errorCode,
        validation.message,
        validation.failedStepId
      );
      return;
    }
    const key = this.contextRunKey(context);
    if (this.runExists(key)) {
      this.publishInputError(
        this.draftMessage(storedDraft),
        plan.planId,
        storedDraft.draft.runId,
        surfaceId,
        'ACTION_RUN_DUPLICATE',
        'Action run identity already exists.'
      );
      return;
    }
    if (!this.hasLiveCapacity()) {
      this.publishInputError(
        this.draftMessage(storedDraft),
        plan.planId,
        storedDraft.draft.runId,
        surfaceId,
        'ACTION_STATE_CAPACITY',
        'Action agent live state capacity is exhausted.'
      );
      return;
    }
    const stored: StoredActionRun = {
      planId: plan.planId,
      runId: storedDraft.draft.runId,
      plan,
      context: copyContext(context),
      taskId: storedDraft.taskId,
      followUpPublished: false
    };
    this.readyRuns.set(key, stored);
    const args: WorkflowRunArgs = {
      planId: plan.planId,
      runId: storedDraft.draft.runId
    };
    const ready: ActionPlanReadyPayload = {
      uiTaskId: storedDraft.uiTaskId,
      surfaceId,
      planId: plan.planId,
      runId: storedDraft.draft.runId,
      label: plan.label,
      actionId: 'workflow.run',
      args
    };
    this.bus.publish({
      type: AgentMessageType.ACTION_PLAN_READY,
      conversationId: storedDraft.conversationId,
      turnId: storedDraft.turnId,
      taskId: storedDraft.taskId,
      payload: ready
    });
  }

  private startRun(message: AgentMessage): void {
    const payload = this.actionRunPayload(message.payload);
    if (payload === null) {
      this.publishInputError(
        message,
        this.nestedPayloadString(message.payload, 'args', 'planId'),
        this.payloadString(message.payload, 'runId'),
        this.payloadString(message.payload, 'surfaceId'),
        'ACTION_RUN_INVALID',
        'Action run payload is malformed.'
      );
      return;
    }
    if (payload.actionId === WORKFLOW_RUN_ACTION_ID) {
      this.startStoredRun(message, payload);
      return;
    }
    this.startDirectRun(message, payload);
  }

  private startDirectRun(
    message: AgentMessage,
    payload: ActionRunPayload,
    virtualAction: boolean = false
  ): void {
    const key = this.runKey(
      message.conversationId,
      message.turnId,
      payload.surfaceId,
      payload.runId
    );
    if (this.runExists(key)) {
      this.publishInputError(
        message,
        `direct:${payload.runId}`,
        payload.runId,
        payload.surfaceId,
        'ACTION_RUN_DUPLICATE',
        'Action run identity already exists.'
      );
      return;
    }
    if (!nonempty(payload.sourceToolId) ||
      payload.confirmedStepId !== undefined) {
      this.publishInputError(
        message,
        `direct:${payload.runId}`,
        payload.runId,
        payload.surfaceId,
        'ACTION_DIRECT_RUN_INVALID',
        'Direct action run identity is malformed.'
      );
      return;
    }
    if (!this.hasLiveCapacity()) {
      this.publishInputError(
        message,
        `direct:${payload.runId}`,
        payload.runId,
        payload.surfaceId,
        'ACTION_STATE_CAPACITY',
        'Action agent live state capacity is exhausted.'
      );
      return;
    }
    const authorization = this.directSurfaceAuthorization(message, payload, key, false);
    const plan = directPlan(message, payload);
    const context: ActionPlanRunContext = {
      conversationId: message.conversationId,
      turnId: message.turnId,
      surfaceId: payload.surfaceId,
      sourceToolId: payload.sourceToolId as string,
      planId: plan.planId,
      runId: payload.runId
    };
    if (authorization !== null && authorization.pageActionId.length > 0) {
      context.pageActionId = authorization.pageActionId;
    }
    if (virtualAction) {
      context.virtualAction = true;
    }
    const validation = this.runner.validate(plan, context);
    if (!validation.ok) {
      this.publishInputError(
        message,
        plan.planId,
        payload.runId,
        payload.surfaceId,
        validation.errorCode,
        validation.message,
        validation.failedStepId
      );
      return;
    }
    const consumed = this.directSurfaceAuthorization(message, payload, key, true);
    this.executeStored({
      planId: plan.planId,
      runId: payload.runId,
      plan,
      context,
      taskId: message.taskId,
      followUpPublished: false
    }, null, virtualAction || (consumed !== null && consumed.confirmed) ? 'step-1' : '');
  }

  private startStoredRun(message: AgentMessage, payload: ActionRunPayload): void {
    const identity = this.workflowIdentity(payload);
    if (!identity.ok) {
      this.publishInputError(
        message,
        identity.planId,
        identity.runId,
        payload.surfaceId,
        identity.errorCode,
        identity.message
      );
      return;
    }
    const key = this.runKey(
      message.conversationId,
      message.turnId,
      payload.surfaceId,
      identity.runId
    );
    if (this.terminalRuns.has(key)) {
      this.publishInputError(
        message,
        identity.planId,
        identity.runId,
        payload.surfaceId,
        'ACTION_RUN_DUPLICATE',
        'Action run identity already exists.'
      );
      return;
    }
    const paused = this.pausedRuns.get(key);
    const ready = this.readyRuns.get(key);
    if (paused !== undefined) {
      if (!this.matchesPaused(message, payload, identity.planId, paused)) {
        this.publishInputError(
          message,
          identity.planId,
          identity.runId,
          payload.surfaceId,
          'ACTION_RESUME_IDENTITY_MISMATCH',
          'Action confirmation does not match the paused run.'
        );
        return;
      }
      this.pausedRuns.delete(key);
      const stored: StoredActionRun = {
        planId: paused.planId,
        runId: paused.runId,
        plan: paused.plan,
        context: copyContext(paused.context),
        taskId: message.taskId,
        followUpPublished: paused.followUpPublished
      };
      this.executeStored(stored, paused);
      return;
    }
    if (ready === undefined ||
      payload.confirmedStepId !== undefined ||
      !this.matchesStored(message, payload, identity.planId, ready)) {
      this.publishInputError(
        message,
        identity.planId,
        identity.runId,
        payload.surfaceId,
        'ACTION_RUN_IDENTITY_MISMATCH',
        'Action run does not match a ready plan.'
      );
      return;
    }
    this.readyRuns.delete(key);
    const current: StoredActionRun = {
      planId: ready.planId,
      runId: ready.runId,
      plan: ready.plan,
      context: copyContext(ready.context),
      taskId: message.taskId,
      followUpPublished: ready.followUpPublished
    };
    this.executeStored(current, null);
  }

  private executeStored(
    stored: StoredActionRun,
    paused: PausedActionRun | null,
    directConfirmedStepId: string = ''
  ): void {
    const priorOutputs = paused === null ? [] : cloneOutputs(paused.outputs);
    if (priorOutputs === null) {
      this.rememberTerminal(this.storedRunKey(stored));
      this.publishOutcome(stored, {
        status: 'error',
        failedStepId: paused === null ? '' : paused.stepId,
        errorCode: 'ACTION_PAUSED_STATE_INVALID',
        message: 'Paused action state is invalid.',
        completedStepIds: []
      });
      return;
    }
    const completedStepIds: string[] = [];
    for (let index = 0; index < priorOutputs.length; index++) {
      completedStepIds.push(priorOutputs[index].stepId);
    }
    const active: ActiveActionRun = {
      stored,
      canceled: false,
      followUpPublished: stored.followUpPublished,
      completedStepIds,
      outputs: priorOutputs,
      generation: this.generation
    };
    this.activeRuns.set(this.storedRunKey(stored), active);
    let execution: Promise<ActionPlanOutcome>;
    if (paused === null && directConfirmedStepId.length === 0) {
      execution = this.runner.run(stored.plan, stored.context);
    } else if (paused !== null) {
      execution = this.runner.resume(
        stored.plan,
        stored.context,
        paused.nextStepIndex,
        paused.outputs,
        paused.stepId
      );
    } else {
      execution = this.runner.resume(
        stored.plan,
        stored.context,
        0,
        [],
        directConfirmedStepId
      );
    }
    execution
      .then((outcome: ActionPlanOutcome) => {
        this.finishRun(active, outcome);
      })
      .catch((_error: Object) => {
        this.finishRun(active, {
          status: 'error',
          failedStepId: '',
          errorCode: 'ACTION_AGENT_RUN_FAILED',
          message: 'Action agent failed closed.',
          completedStepIds: []
        });
      });
  }

  private finishRun(active: ActiveActionRun, outcome: ActionPlanOutcome): void {
    const stored = active.stored;
    const key = this.storedRunKey(stored);
    if (this.activeRuns.get(key) !== active ||
      active.canceled ||
      !this.active ||
      active.generation !== this.generation) {
      return;
    }
    this.activeRuns.delete(key);
    if (outcome.status === 'paused' &&
      outcome.errorCode === 'ACTION_CONFIRMATION_REQUIRED') {
      const pausedOutcome = outcome as ActionPlanPausedOutcome;
      const plan = clonePlan(stored.plan);
      const outputs = cloneOutputs(pausedOutcome.outputs);
      if (plan === null || outputs === null) {
        this.rememberTerminal(key);
        this.publishOutcome(stored, {
          status: 'error',
          failedStepId: pausedOutcome.failedStepId,
          errorCode: 'ACTION_PAUSED_STATE_INVALID',
          message: 'Paused action state is invalid.',
          completedStepIds: pausedOutcome.completedStepIds
        });
        return;
      }
      const paused: PausedActionRun = {
        planId: stored.planId,
        runId: stored.runId,
        stepId: pausedOutcome.failedStepId,
        nextStepIndex: pausedOutcome.nextStepIndex,
        outputs,
        plan,
        context: copyContext(stored.context),
        followUpPublished: active.followUpPublished
      };
      this.pausedRuns.set(key, paused);
      this.publishOutcome(stored, outcome);
      return;
    }
    this.rememberTerminal(key);
    this.publishOutcome(stored, outcome);
  }

  private cancelTurn(message: AgentMessage): void {
    this.rememberCanceledTurn(message.conversationId, message.turnId);
    this.observedDataTasks.forEach((task: ObservedDataTask, key: string) => {
      if (task.conversationId === message.conversationId && task.turnId === message.turnId) {
        this.observedDataTasks.delete(key);
      }
    });
    this.pendingDrafts.forEach((draft: StoredActionDraft, key: string) => {
      if (draft.conversationId === message.conversationId && draft.turnId === message.turnId) {
        this.pendingDrafts.delete(key);
      }
    });
    this.pendingPlanRequests.forEach((request: StoredPlanRequest, key: string) => {
      if (request.message.conversationId === message.conversationId &&
        request.message.turnId === message.turnId) {
        this.pendingPlanRequests.delete(key);
      }
    });
    const prefix = this.turnPrefix(message.conversationId, message.turnId);
    this.directSurfaceAuthorizations.forEach(
      (authorization: DirectSurfaceAuthorization, key: string) => {
        if (authorization.conversationId === message.conversationId &&
          authorization.turnId === message.turnId) {
          this.directSurfaceAuthorizations.delete(key);
        }
      }
    );
    this.availableOffers.forEach((_offers: StoredAvailableOffers, key: string) => {
      if (key.startsWith(prefix)) {
        this.availableOffers.delete(key);
      }
    });
    this.uiSurfaces.forEach((_surfaceId: string, key: string) => {
      if (key.startsWith(prefix)) {
        this.uiSurfaces.delete(key);
      }
    });
    const canceled: Set<string> = new Set<string>();
    this.readyRuns.forEach((stored: StoredActionRun, key: string) => {
      if (this.sameTurn(stored.context, message)) {
        this.readyRuns.delete(key);
        canceled.add(key);
        this.publishCanceled(stored, message.taskId, [], []);
      }
    });
    this.pausedRuns.forEach((paused: PausedActionRun, key: string) => {
      if (this.sameTurn(paused.context, message)) {
        this.pausedRuns.delete(key);
        canceled.add(key);
        this.publishCanceled({
          planId: paused.planId,
          runId: paused.runId,
          plan: paused.plan,
          context: paused.context,
          taskId: message.taskId,
          followUpPublished: paused.followUpPublished
        }, message.taskId, this.outputStepIds(paused.outputs), paused.outputs);
      }
    });
    this.activeRuns.forEach((active: ActiveActionRun, key: string) => {
      if (this.sameTurn(active.stored.context, message)) {
        active.canceled = true;
        this.activeRuns.delete(key);
        if (!canceled.has(key)) {
          this.publishCanceled(
            active.stored,
            message.taskId,
            active.completedStepIds,
            active.outputs
          );
        }
      }
    });
  }

  private publishCanceled(
    stored: StoredActionRun,
    taskId: string,
    completedStepIds: string[],
    outputs: ActionPlanStepOutput[]
  ): void {
    const safeOutputs = cloneOutputs(outputs);
    const safeStepIds = completedStepIds.slice();
    this.rememberTerminal(this.storedRunKey(stored));
    const payload: ActionResultPayload = {
      surfaceId: stored.context.surfaceId,
      planId: stored.planId,
      runId: stored.runId,
      status: 'canceled',
      completedStepIds: safeStepIds,
      errorCode: 'TURN_CANCELED',
      message: 'Action run canceled.'
    };
    if (safeOutputs !== null && safeOutputs.length > 0) {
      payload.outputs = safeOutputs;
    }
    this.bus.publish({
      type: AgentMessageType.ACTION_RESULT,
      conversationId: stored.context.conversationId,
      turnId: stored.context.turnId,
      taskId,
      payload
    });
  }

  private publishOutcome(stored: StoredActionRun, outcome: ActionPlanOutcome): void {
    const payload: ActionResultPayload = {
      surfaceId: stored.context.surfaceId,
      planId: stored.planId,
      runId: stored.runId,
      status: outcome.status,
      completedStepIds: outcome.completedStepIds.slice()
    };
    if (outcome.status === 'success') {
      payload.outputs = outcome.outputs;
    } else {
      payload.stepId = outcome.failedStepId;
      payload.errorCode = outcome.errorCode;
      payload.message = outcome.message;
      if (outcome.status === 'paused') {
        payload.outputs = outcome.outputs;
      }
    }
    this.bus.publish({
      type: AgentMessageType.ACTION_RESULT,
      conversationId: stored.context.conversationId,
      turnId: stored.context.turnId,
      taskId: stored.taskId,
      payload
    });
  }

  private publishInputError(
    message: AgentMessage,
    planId: string,
    runId: string,
    surfaceId: string,
    errorCode: string,
    detail: string,
    stepId: string = ''
  ): void {
    const payload: ActionResultPayload = {
      surfaceId,
      planId,
      runId,
      status: 'error',
      completedStepIds: [],
      errorCode,
      message: detail
    };
    if (stepId.length > 0) {
      payload.stepId = stepId;
    }
    this.bus.publish({
      type: AgentMessageType.ACTION_RESULT,
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: message.taskId,
      payload
    });
  }

  private publishProgress(
    active: ActiveActionRun,
    context: ActionExecutionContext,
    actionId: string,
    status: 'running' | 'success'
  ): void {
    const key = this.runKey(
      context.conversationId,
      context.turnId,
      context.surfaceId,
      context.runId
    );
    if (this.activeRuns.get(key) !== active || active.canceled) {
      return;
    }
    const payload: ActionProgressPayload = {
      surfaceId: context.surfaceId,
      planId: context.planId,
      runId: context.runId,
      stepId: context.stepId,
      actionId,
      status
    };
    this.bus.publish({
      type: AgentMessageType.ACTION_PROGRESS,
      conversationId: context.conversationId,
      turnId: context.turnId,
      taskId: active.stored.taskId,
      payload
    });
  }

  private publishFollowUp(
    active: ActiveActionRun,
    followUp: ActionFollowUp
  ): ActionStepExecutionResult | null {
    if (active.followUpPublished) {
      return null;
    }
    const safe = this.sanitizeFollowUp(followUp);
    if (safe === null) {
      return {
        status: 'error',
        errorCode: 'ACTION_FOLLOW_UP_INVALID',
        message: 'Action follow-up is malformed.'
      };
    }
    active.followUpPublished = true;
    active.stored.followUpPublished = true;
    followUpTurnSequence++;
    const followUpTurnId =
      `${active.stored.context.conversationId}:` +
        `${active.stored.context.turnId}:follow-up:` +
        `${Date.now()}:${followUpTurnSequence}`;
    this.bus.publish({
      type: AgentMessageType.TASK_CREATE_UI,
      conversationId: active.stored.context.conversationId,
      turnId: followUpTurnId,
      taskId: safe.uiTask.taskId,
      payload: safe.uiTask
    });
    this.bus.publish({
      type: AgentMessageType.TASK_CREATE_DATA,
      conversationId: active.stored.context.conversationId,
      turnId: followUpTurnId,
      taskId: safe.dataTask.taskId,
      payload: safe.dataTask
    });
    return null;
  }

  private sanitizeFollowUp(followUp: ActionFollowUp): SanitizedFollowUp | null {
    if (followUp === null ||
      typeof followUp !== 'object' ||
      Array.isArray(followUp) ||
      Object.keys(followUp).sort().join(',') !== 'dataTask,uiTask' ||
      followUp.uiTask === null ||
      typeof followUp.uiTask !== 'object' ||
      Array.isArray(followUp.uiTask) ||
      followUp.dataTask === null ||
      typeof followUp.dataTask !== 'object' ||
      Array.isArray(followUp.dataTask) ||
      Object.keys(followUp.uiTask).sort().join(',') !==
        'dataTaskIds,expectedOutputSchema,intent,skillId,taskId' ||
      Object.keys(followUp.dataTask).sort().join(',') !==
        'allowedToolIds,args,goal,outputSchema,required,roundId,skillId,taskId,toolId') {
      return null;
    }
    const ui: CreateUiTaskPayload = followUp.uiTask;
    const data: CreateDataTaskPayload = followUp.dataTask;
    if (!nonempty(ui.taskId) ||
      !Array.isArray(ui.dataTaskIds) || ui.dataTaskIds.length !== 1 ||
      !nonempty(ui.dataTaskIds[0]) ||
      !nonempty(ui.intent) ||
      !nonempty(ui.expectedOutputSchema) ||
      typeof ui.skillId !== 'string' || ui.skillId !== data.skillId ||
      !nonempty(data.taskId) ||
      !nonempty(data.roundId) ||
      !nonempty(data.goal) ||
      !Array.isArray(data.allowedToolIds) || data.allowedToolIds.length === 0 ||
      !nonempty(data.toolId) ||
      !nonempty(data.outputSchema) ||
      ui.taskId === data.taskId ||
      ui.dataTaskIds[0] !== data.taskId ||
      ui.expectedOutputSchema !== data.outputSchema ||
      data.args === null ||
      typeof data.args !== 'object' ||
      Array.isArray(data.args)) {
      return null;
    }
    const argsClone = cloneJsonValue(data.args as Object);
    if (!argsClone.ok ||
      argsClone.value === null ||
      typeof argsClone.value !== 'object' ||
      Array.isArray(argsClone.value)) {
      return null;
    }
    return {
      uiTask: {
        taskId: ui.taskId,
        dataTaskIds: [ui.dataTaskIds[0]],
        skillId: ui.skillId,
        intent: ui.intent,
        expectedOutputSchema: ui.expectedOutputSchema
      },
      dataTask: {
        taskId: data.taskId,
        roundId: data.roundId,
        skillId: data.skillId,
        goal: data.goal,
        allowedToolIds: data.allowedToolIds.slice(),
        toolId: data.toolId,
        outputSchema: data.outputSchema,
        args: argsClone.value as Object,
        required: data.required
      }
    };
  }

  private catalogImmediatelyBeforeInvoke(
    active: ActiveActionRun,
    context: ActionExecutionContext,
    actionId: string,
    args: Object
  ): ActionCatalogResult {
    const steps = active.stored.plan.steps;
    let stepIndex: number = -1;
    for (let index = 0; index < steps.length; index++) {
      if (steps[index].stepId === context.stepId &&
        steps[index].actionId === actionId) {
        stepIndex = index;
        break;
      }
    }
    if (stepIndex === 0) {
      if (active.stored.context.virtualAction === true) {
        return this.catalog.validateActionIntentExecution(actionId, args);
      }
      if (active.stored.context.pageActionId !== undefined &&
        active.stored.context.pageActionId.length > 0) {
        return this.catalog.validatePageExecution(
          context.conversationId,
          context.turnId,
          context.surfaceId,
          actionId,
          args
        );
      }
      return this.catalog.validateSurfaceExecution(
        context.conversationId,
        context.turnId,
        context.surfaceId,
        context.sourceToolId,
        actionId,
        args
      );
    }
    if (stepIndex > 0) {
      return this.catalog.validateRegisteredStep(actionId, args);
    }
    return {
      ok: false,
      code: 'ACTION_STEP_IDENTITY_MISMATCH',
      message: 'Action step is not part of the active plan.',
      definition: null
    };
  }

  private matchesExecution(
    active: ActiveActionRun | undefined,
    actionId: string,
    context: ActionExecutionContext
  ): boolean {
    if (active === undefined ||
      active.canceled ||
      active.generation !== this.generation) {
      return false;
    }
    const stored = active.stored;
    if (stored.runId !== context.runId ||
      stored.planId !== context.planId ||
      stored.context.conversationId !== context.conversationId ||
      stored.context.turnId !== context.turnId ||
      stored.context.surfaceId !== context.surfaceId ||
      stored.context.sourceToolId !== context.sourceToolId ||
      stored.context.pageActionId !== context.pageActionId ||
      (stored.context.virtualAction === true) !== (context.virtualAction === true)) {
      return false;
    }
    for (let index = 0; index < stored.plan.steps.length; index++) {
      if (stored.plan.steps[index].stepId === context.stepId &&
        stored.plan.steps[index].actionId === actionId) {
        return true;
      }
    }
    return false;
  }

  private matchesStored(
    message: AgentMessage,
    payload: ActionRunPayload,
    planId: string,
    stored: StoredActionRun
  ): boolean {
    return stored.planId === planId &&
      stored.runId === payload.runId &&
      stored.context.conversationId === message.conversationId &&
      stored.context.turnId === message.turnId &&
      stored.context.surfaceId === payload.surfaceId;
  }

  private directSurfaceAuthorization(
    message: AgentMessage,
    payload: ActionRunPayload,
    key: string,
    consume: boolean
  ): DirectSurfaceAuthorization | null {
    const authorization = this.directSurfaceAuthorizations.get(key);
    if (authorization === undefined || authorization.generation !== this.generation ||
      authorization.conversationId !== message.conversationId ||
      authorization.turnId !== message.turnId ||
      authorization.taskId !== message.taskId ||
      authorization.surfaceId !== payload.surfaceId ||
      authorization.sourceToolId !== payload.sourceToolId ||
      authorization.runId !== payload.runId ||
      authorization.actionId !== payload.actionId ||
      !sameJson(authorization.args as JsonValue, payload.args as JsonValue)) {
      return null;
    }
    if (consume) {
      this.directSurfaceAuthorizations.delete(key);
    }
    return authorization;
  }

  private matchesPaused(
    message: AgentMessage,
    payload: ActionRunPayload,
    planId: string,
    paused: PausedActionRun
  ): boolean {
    return paused.planId === planId &&
      paused.runId === payload.runId &&
      paused.stepId === payload.confirmedStepId &&
      paused.context.conversationId === message.conversationId &&
      paused.context.turnId === message.turnId &&
      paused.context.surfaceId === payload.surfaceId;
  }

  private sameTurn(context: ActionPlanRunContext, message: AgentMessage): boolean {
    return context.conversationId === message.conversationId &&
      context.turnId === message.turnId;
  }

  private planDraftPayload(payload: Object): ActionPlanDraftPayload | null {
    if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
      return null;
    }
    const current = payload as ActionPlanDraftPayload;
    if (Object.keys(payload).sort().join(',') !== 'dataTaskId,draft,sourceToolId,uiTaskId' ||
      !nonempty(current.uiTaskId) || !nonempty(current.dataTaskId) ||
      current.uiTaskId === current.dataTaskId ||
      !nonempty(current.sourceToolId) ||
      current.draft === null || typeof current.draft !== 'object' ||
      Array.isArray(current.draft)) {
      return null;
    }
    return current;
  }

  private planRequestPayload(payload: Object): ActionPlanRequestPayload | null {
    if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
      return null;
    }
    const current = payload as ActionPlanRequestPayload;
    const keys: string = Object.keys(payload).sort().join(',');
    if (keys !== 'allowedActionIds,dataTaskIds,goal,skillId,uiTaskId' &&
      keys !== 'allowedActionIds,dataTaskIds,goal,inputText,personaId,skillId,uiTaskId' &&
      keys !== 'allowedActionIds,currentLocalDate,dataTaskIds,goal,inputText,personaId,skillId,uiTaskId' &&
      keys !== 'allowedActionIds,dataTaskIds,goal,inputText,personaId,skillId,uiTaskId,virtual' &&
      keys !== 'allowedActionIds,currentLocalDate,dataTaskIds,goal,inputText,personaId,skillId,uiTaskId,virtual') {
      return null;
    }
    const virtual: boolean = current.virtual === true;
    const hasContext: boolean = nonempty(current.personaId) && nonempty(current.inputText);
    if (
      !nonempty(current.uiTaskId) || !nonempty(current.goal) ||
      typeof current.skillId !== 'string' ||
      !Array.isArray(current.dataTaskIds) ||
      !Array.isArray(current.allowedActionIds) || current.allowedActionIds.length === 0 ||
      !this.validUniqueIds(current.dataTaskIds, current.uiTaskId) ||
      !this.validUniqueIds(current.allowedActionIds, '') ||
      (keys !== 'allowedActionIds,dataTaskIds,goal,skillId,uiTaskId' && !hasContext) ||
      (current.currentLocalDate !== undefined && !nonempty(current.currentLocalDate)) ||
      (virtual && current.dataTaskIds.length !== 0) ||
      (!virtual && current.dataTaskIds.length === 0)) {
      return null;
    }
    return current;
  }

  private validUniqueIds(ids: string[], forbiddenId: string): boolean {
    const seen: Set<string> = new Set<string>();
    for (let index = 0; index < ids.length; index++) {
      if (!nonempty(ids[index]) || ids[index] === forbiddenId || seen.has(ids[index])) {
        return false;
      }
      seen.add(ids[index]);
    }
    return true;
  }

  private validDraft(draft: ActionPlanDraft): boolean {
    if (Object.keys(draft).sort().join(',') !== 'label,planId,runId,steps' ||
      !nonempty(draft.planId) || !nonempty(draft.runId) ||
      !nonempty(draft.label) || !Array.isArray(draft.steps) ||
      draft.steps.length === 0 || draft.steps.length > 5) {
      return false;
    }
    const stepIds: Set<string> = new Set<string>();
    for (let index = 0; index < draft.steps.length; index++) {
      const step = draft.steps[index];
      if (step === undefined || !nonempty(step.stepId) ||
        !nonempty(step.actionId) || stepIds.has(step.stepId)) {
        return false;
      }
      stepIds.add(step.stepId);
    }
    return true;
  }

  private uiResult(payload: Object): UiRenderResultPayload | null {
    if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
      return null;
    }
    const result = payload as UiRenderResultPayload;
    if (Object.keys(payload).sort().join(',') !== 'state,surfaceId' ||
      !nonempty(result.surfaceId) ||
      (result.state !== 'skeleton' && result.state !== 'result' &&
        result.state !== 'error' && result.state !== 'action')) {
      return null;
    }
    return result;
  }

  private dataTask(payload: Object, taskId: string): CreateDataTaskPayload | null {
    if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
      return null;
    }
    const task = payload as CreateDataTaskPayload;
    if (Object.keys(payload).sort().join(',') !== 'allowedToolIds,args,goal,outputSchema,required,roundId,skillId,taskId,toolId' ||
      task.taskId !== taskId || typeof task.skillId !== 'string' ||
      !nonempty(task.roundId) || !nonempty(task.goal) ||
      !Array.isArray(task.allowedToolIds) || task.allowedToolIds.length === 0 ||
      !nonempty(task.toolId) || !nonempty(task.outputSchema) ||
      task.args === null || typeof task.args !== 'object' || Array.isArray(task.args) ||
      typeof task.required !== 'boolean') {
      return null;
    }
    return task;
  }

  private dataResult(payload: Object, task: ObservedDataTask): DataResult | null {
    if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
      return null;
    }
    const data = payload as DataResult;
    if (data.toolId !== task.toolId || data.outputSchema !== task.outputSchema ||
      !Array.isArray(data.sources) || !Array.isArray(data.warnings) ||
      (data.status !== 'success' && data.status !== 'partial' &&
        data.status !== 'empty' && data.status !== 'error')) {
      return null;
    }
    return data;
  }

  private draftMessage(stored: StoredActionDraft): AgentMessage {
    return {
      type: AgentMessageType.ACTION_PLAN_DRAFT,
      conversationId: stored.conversationId,
      turnId: stored.turnId,
      taskId: stored.taskId,
      payload: stored.draft
    };
  }

  private actionRunPayload(payload: Object): ActionRunPayload | null {
    if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
      return null;
    }
    const current = payload as ActionRunPayload;
    if (!nonempty(current.surfaceId) ||
      !nonempty(current.runId) ||
      !nonempty(current.actionId) ||
      current.args === null ||
      typeof current.args !== 'object' ||
      Array.isArray(current.args) ||
      (current.confirmedStepId !== undefined &&
        !nonempty(current.confirmedStepId))) {
      return null;
    }
    const allowed = current.actionId === WORKFLOW_RUN_ACTION_ID ?
      ['actionId', 'args', 'confirmedStepId', 'runId', 'surfaceId'] :
      ['actionId', 'args', 'runId', 'sourceToolId', 'surfaceId'];
    const keys = Object.keys(payload);
    for (let index = 0; index < keys.length; index++) {
      if (allowed.indexOf(keys[index]) < 0) {
        return null;
      }
    }
    return current;
  }

  private workflowIdentity(payload: ActionRunPayload): RunIdentityResult {
    const args = payload.args as WorkflowRunArgs;
    if (args === null ||
      typeof args !== 'object' ||
      Array.isArray(args) ||
      Object.keys(args).sort().join(',') !== 'planId,runId' ||
      !nonempty(args.planId) ||
      args.runId !== payload.runId) {
      return {
        ok: false,
        planId: this.payloadString(payload.args, 'planId'),
        runId: payload.runId,
        errorCode: 'ACTION_WORKFLOW_IDENTITY_INVALID',
        message: 'Workflow run args must contain only exact plan and run identity.'
      };
    }
    return {
      ok: true,
      planId: args.planId,
      runId: args.runId,
      errorCode: '',
      message: ''
    };
  }

  private payloadString(payload: Object, key: string): string {
    if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
      return '';
    }
    const record =
      payload as Record<string, Object | string | number | boolean | null | undefined>;
    const value = record[key];
    return typeof value === 'string' ? value : '';
  }

  private nestedPayloadString(
    payload: Object,
    objectKey: string,
    valueKey: string
  ): string {
    if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
      return '';
    }
    const record =
      payload as Record<string, Object | string | number | boolean | null | undefined>;
    const nested = record[objectKey];
    if (nested === null ||
      nested === undefined ||
      typeof nested !== 'object' ||
      Array.isArray(nested)) {
      return '';
    }
    return this.payloadString(nested as Object, valueKey);
  }

  private outputStepIds(outputs: ActionPlanStepOutput[]): string[] {
    const stepIds: string[] = [];
    for (let index = 0; index < outputs.length; index++) {
      stepIds.push(outputs[index].stepId);
    }
    return stepIds;
  }

  private hasLiveCapacity(): boolean {
    return this.readyRuns.size + this.pausedRuns.size + this.activeRuns.size <
      LIVE_RUN_LIMIT;
  }

  private hasLiveStateCapacity(size: number, alreadyPresent: boolean): boolean {
    return alreadyPresent || size < LIVE_RUN_LIMIT;
  }

  private runExists(key: string): boolean {
    return this.readyRuns.has(key) ||
      this.pausedRuns.has(key) ||
      this.activeRuns.has(key) ||
      this.terminalRuns.has(key);
  }

  private rememberTerminal(key: string): void {
    if (this.terminalRuns.has(key)) {
      return;
    }
    this.terminalRuns.add(key);
  }

  private rememberTerminalPlanRequest(key: string): void {
    if (this.terminalPlanRequests.has(key)) {
      return;
    }
    while (this.terminalPlanRequestOrder.length >= LIVE_RUN_LIMIT) {
      const oldest = this.terminalPlanRequestOrder.shift();
      if (oldest !== undefined) {
        this.terminalPlanRequests.delete(oldest);
      }
    }
    this.terminalPlanRequests.add(key);
    this.terminalPlanRequestOrder.push(key);
  }

  private rememberCanceledTurn(conversationId: string, turnId: string): void {
    const key = this.turnKey(conversationId, turnId);
    if (this.canceledTurns.has(key)) {
      return;
    }
    this.canceledTurns.add(key);
  }

  private turnKey(conversationId: string, turnId: string): string {
    return `${conversationId.length}:${conversationId}${turnId}`;
  }

  private dataTaskKey(conversationId: string, turnId: string, taskId: string): string {
    return this.turnPrefix(conversationId, turnId) + `${taskId.length}:${taskId}`;
  }

  private planRequestKey(conversationId: string, turnId: string, uiTaskId: string): string {
    return this.turnPrefix(conversationId, turnId) + `${uiTaskId.length}:${uiTaskId}`;
  }

  private uiSurfaceKey(conversationId: string, turnId: string, uiTaskId: string): string {
    return this.planRequestKey(conversationId, turnId, uiTaskId);
  }

  private turnPrefix(conversationId: string, turnId: string): string {
    return `${conversationId.length}:${conversationId}${turnId.length}:${turnId}`;
  }

  private draftKey(
    conversationId: string,
    turnId: string,
    uiTaskId: string,
    runId: string
  ): string {
    return `${conversationId.length}:${conversationId}` +
      `${turnId.length}:${turnId}${uiTaskId.length}:${uiTaskId}${runId.length}:${runId}`;
  }

  private contextRunKey(context: ActionPlanRunContext): string {
    return this.runKey(
      context.conversationId,
      context.turnId,
      context.surfaceId,
      context.runId
    );
  }

  private storedRunKey(stored: StoredActionRun): string {
    return this.contextRunKey(stored.context);
  }

  private runKey(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    runId: string
  ): string {
    return `${conversationId.length}:${conversationId}` +
      `${turnId.length}:${turnId}` +
      `${surfaceId.length}:${surfaceId}` +
      `${runId.length}:${runId}`;
  }
}
