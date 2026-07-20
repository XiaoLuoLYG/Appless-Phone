import { MessageDrivenAgent } from '../MessageDrivenAgent';
import { CreateDataTaskPayload } from '../data/DataAgentTypes';
import { AgentMessage, AgentMessageType } from '../message/AgentMessage';
import { LinkedMessageBus } from '../message/LinkedMessageBus';
import { CreateUiTaskPayload } from '../ui/UiAgentTypes';
import { ActionCatalog } from './ActionCatalog';
import { ActionCatalogResult } from './ActionCatalogTypes';
import {
  ActionExecutionResult,
  ActionFollowUp,
  ActionPlanCreatePayload,
  ActionPlanReadyPayload,
  ActionProgressPayload,
  ActionResultPayload,
  ActionRunPayload,
  PausedActionRun,
  RegisteredActionExecutor,
  WorkflowRunArgs
} from './ActionAgentTypes';
import { ActionPlanRunner } from './ActionPlanRunner';
import {
  ActionExecutionContext,
  ActionPlan,
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

function nonempty(value: string | undefined): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function copyContext(context: ActionPlanRunContext): ActionPlanRunContext {
  return {
    conversationId: context.conversationId,
    turnId: context.turnId,
    surfaceId: context.surfaceId,
    sourceToolId: context.sourceToolId,
    planId: context.planId,
    runId: context.runId
  };
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

function cloneOutputs(outputs: ActionPlanStepOutput[]): ActionPlanStepOutput[] | null {
  const cloned = cloneJsonValue(outputs as Object);
  if (!cloned.ok || !Array.isArray(cloned.value)) {
    return null;
  }
  return cloned.value as ActionPlanStepOutput[];
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
  private readonly registeredExecutor: RegisteredActionExecutor;
  private readonly runner: ActionPlanRunner;
  private readonly readyRuns: Map<string, StoredActionRun> =
    new Map<string, StoredActionRun>();
  private readonly pausedRuns: Map<string, PausedActionRun> =
    new Map<string, PausedActionRun>();
  private readonly activeRuns: Map<string, ActiveActionRun> =
    new Map<string, ActiveActionRun>();
  // Payload-free idempotency identities live for this ActionAgent session.
  // stop() clears them; replay protection never evicts an earlier exact key.
  private readonly terminalRuns: Set<string> = new Set<string>();
  private readonly canceledTurns: Set<string> = new Set<string>();
  private generation: number = 0;
  private active: boolean = false;

  constructor(
    bus: LinkedMessageBus,
    catalog: ActionCatalog,
    executor: RegisteredActionExecutor
  ) {
    super(bus);
    this.bus = bus;
    this.catalog = catalog;
    this.registeredExecutor = executor;
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
    return message.type === AgentMessageType.ACTION_PLAN_CREATE ||
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
      if (message.type === AgentMessageType.ACTION_PLAN_CREATE) {
        this.createPlan(message);
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

  private createPlan(message: AgentMessage): void {
    const payload = this.planCreatePayload(message.payload);
    if (payload === null) {
      this.publishInputError(
        message,
        this.nestedPayloadString(message.payload, 'plan', 'planId'),
        this.payloadString(message.payload, 'runId'),
        this.nestedPayloadString(message.payload, 'plan', 'surfaceId'),
        'ACTION_PLAN_CREATE_INVALID',
        'Action plan create payload is malformed.'
      );
      return;
    }
    const plan = clonePlan(payload.plan);
    if (plan === null) {
      this.publishInputError(
        message,
        this.payloadString(payload.plan as Object, 'planId'),
        payload.runId,
        this.payloadString(payload.plan as Object, 'surfaceId'),
        'ACTION_PLAN_MALFORMED',
        'Action plan is not valid JSON data.'
      );
      return;
    }
    const safePlanId = typeof plan.planId === 'string' ? plan.planId : '';
    const safeSurfaceId = typeof plan.surfaceId === 'string' ? plan.surfaceId : '';
    const context: ActionPlanRunContext = {
      conversationId: message.conversationId,
      turnId: message.turnId,
      surfaceId: safeSurfaceId,
      sourceToolId: payload.sourceToolId,
      planId: safePlanId,
      runId: payload.runId
    };
    const validation = this.runner.validate(plan, context);
    if (!validation.ok) {
      this.publishInputError(
        message,
        safePlanId,
        payload.runId,
        safeSurfaceId,
        validation.errorCode,
        validation.message,
        validation.failedStepId
      );
      return;
    }
    const key = this.contextRunKey(context);
    if (this.runExists(key)) {
      this.publishInputError(
        message,
        safePlanId,
        payload.runId,
        safeSurfaceId,
        'ACTION_RUN_DUPLICATE',
        'Action run identity already exists.'
      );
      return;
    }
    if (!this.hasLiveCapacity()) {
      this.publishInputError(
        message,
        safePlanId,
        payload.runId,
        safeSurfaceId,
        'ACTION_STATE_CAPACITY',
        'Action agent live state capacity is exhausted.'
      );
      return;
    }
    const stored: StoredActionRun = {
      planId: safePlanId,
      runId: payload.runId,
      plan,
      context: copyContext(context),
      taskId: message.taskId,
      followUpPublished: false
    };
    this.readyRuns.set(key, stored);
    const args: WorkflowRunArgs = {
      planId: safePlanId,
      runId: payload.runId
    };
    const ready: ActionPlanReadyPayload = {
      surfaceId: safeSurfaceId,
      planId: safePlanId,
      runId: payload.runId,
      label: plan.label,
      actionId: 'workflow.run',
      args
    };
    this.bus.publish({
      type: AgentMessageType.ACTION_PLAN_READY,
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: message.taskId,
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

  private startDirectRun(message: AgentMessage, payload: ActionRunPayload): void {
    const key = this.runKey(
      message.conversationId,
      message.turnId,
      payload.surfaceId,
      payload.runId
    );
    if (!nonempty(payload.sourceToolId) ||
      payload.confirmedStepId !== undefined ||
      this.runExists(key)) {
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
    const plan = directPlan(message, payload);
    const context: ActionPlanRunContext = {
      conversationId: message.conversationId,
      turnId: message.turnId,
      surfaceId: payload.surfaceId,
      sourceToolId: payload.sourceToolId as string,
      planId: plan.planId,
      runId: payload.runId
    };
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
    this.executeStored({
      planId: plan.planId,
      runId: payload.runId,
      plan,
      context,
      taskId: message.taskId,
      followUpPublished: false
    }, null);
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

  private executeStored(stored: StoredActionRun, paused: PausedActionRun | null): void {
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
    if (paused === null) {
      execution = this.runner.run(stored.plan, stored.context);
    } else {
      execution = this.runner.resume(
        stored.plan,
        stored.context,
        paused.nextStepIndex,
        paused.outputs,
        paused.stepId
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
        'dataTaskId,expectedOutputSchema,intent,taskId' ||
      Object.keys(followUp.dataTask).sort().join(',') !==
        'args,outputSchema,taskId,toolId') {
      return null;
    }
    const ui: CreateUiTaskPayload = followUp.uiTask;
    const data: CreateDataTaskPayload = followUp.dataTask;
    if (!nonempty(ui.taskId) ||
      !nonempty(ui.dataTaskId) ||
      !nonempty(ui.intent) ||
      !nonempty(ui.expectedOutputSchema) ||
      !nonempty(data.taskId) ||
      !nonempty(data.toolId) ||
      !nonempty(data.outputSchema) ||
      ui.taskId === data.taskId ||
      ui.dataTaskId !== data.taskId ||
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
        dataTaskId: ui.dataTaskId,
        intent: ui.intent,
        expectedOutputSchema: ui.expectedOutputSchema
      },
      dataTask: {
        taskId: data.taskId,
        toolId: data.toolId,
        outputSchema: data.outputSchema,
        args: argsClone.value as Object
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
      stored.context.sourceToolId !== context.sourceToolId) {
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

  private planCreatePayload(payload: Object): ActionPlanCreatePayload | null {
    if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
      return null;
    }
    const current = payload as ActionPlanCreatePayload;
    if (Object.keys(payload).sort().join(',') !== 'plan,runId,sourceToolId' ||
      !nonempty(current.runId) ||
      !nonempty(current.sourceToolId) ||
      current.plan === null ||
      typeof current.plan !== 'object' ||
      Array.isArray(current.plan)) {
      return null;
    }
    return current;
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
