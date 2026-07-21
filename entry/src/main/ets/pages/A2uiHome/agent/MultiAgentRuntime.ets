import {
  ActionAgent,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionPlanRequestPayload,
  ActionResultPayload,
  ActionRunPayload,
  ActionOffer,
  ActionOfferContext,
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  A2uiAction,
  RegisteredActionExecutor,
  ConversationTurnMessage,
  CreateDataTaskPayload,
  CreateUiTaskPayload,
  CurrentSurfaceSummary,
  DataAgent,
  DataResult,
  LeaderAgent,
  LeaderPlanningContext,
  LegacyHandoffPayload,
  LinkedMessageBus,
  ObservationDigest,
  TaskErrorPayload,
  TurnResultPayload,
  TurnResultStatus,
  UiAgent,
  UiRenderResultPayload,
  UserInputPayload
} from '@loop/agent-core';
import {
  MultiAgentHandoffOutcome,
  MultiAgentRuntimeOptions,
  MultiAgentSettledOutcome,
  MultiAgentTurnOutcome
} from './MultiAgentRuntimeTypes';
import {
  AiphoneRegisteredActionExecutor,
  HotelActionIdFactory,
  RegisteredPageAction,
  SystemUriOpener
} from './AiphoneRegisteredActionExecutor';
import { RegisteredActionOfferResolver } from './RegisteredActionOfferResolver';
import { StructuredToolUiRenderer } from './StructuredToolUiRenderer';

const DEFAULT_SUBMIT_TIMEOUT_MS: number = 30000;
const DEFAULT_ACTION_TIMEOUT_MS: number = 15000;
const MAX_TIMEOUT_MS: number = 120000;
const CONTEXT_MESSAGE_LIMIT: number = 8;
const CONTEXT_OBSERVATION_LIMIT: number = 8;

interface PendingTurn {
  conversationId: string;
  turnId: string;
  inputTaskId: string;
  generation: number;
  uiTaskId: string;
  uiTerminal: boolean;
  uiState: '' | 'result' | 'error';
  uiSurfaceId: string;
  terminal: TurnResultPayload | null;
  virtualActionTaskId: string;
  virtualActionSurfaceId: string;
  virtualActionPlanId: string;
  virtualActionRunId: string;
  timerId: number;
  resolve: (outcome: MultiAgentTurnOutcome) => void;
}

interface PendingAction {
  conversationId: string;
  turnId: string;
  taskId: string;
  surfaceId: string;
  planId: string;
  runId: string;
  generation: number;
  directTerminal: boolean;
  directSucceeded: boolean;
  followUpTurnId: string;
  followUpUiTaskId: string;
  followUpDataTaskId: string;
  followUpUiSeen: boolean;
  followUpDataSeen: boolean;
  followUpTerminal: boolean;
  followUpSucceeded: boolean;
  timerId: number;
  resolve: (ok: boolean) => void;
}

interface RuntimeCancelPayload {
  reason: string;
}

function boundedTimeout(value: number | undefined, fallback: number): number {
  if (value === undefined || !Number.isFinite(value) || value <= 0) {
    return fallback;
  }
  return Math.min(Math.floor(value), MAX_TIMEOUT_MS);
}

function settled(
  status: TurnResultStatus,
  message: string,
  surfaceId: string = ''
): MultiAgentSettledOutcome {
  return {
    kind: 'settled',
    ok: status === 'success' || status === 'partial' || status === 'empty',
    status,
    surfaceId,
    message
  };
}

function nonempty(value: string | undefined): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

class RuntimeActionIds implements HotelActionIdFactory {
  private sequence: number = 0;

  nextId(prefix: string): string {
    this.sequence++;
    return prefix + '-' + this.sequence.toString();
  }
}

class RejectSystemUriOpener implements SystemUriOpener {
  async open(_uri: string): Promise<boolean> {
    return false;
  }
}

const rejectPageAction: RegisteredPageAction = async (): Promise<ActionExecutionResult> => ({
  status: 'error',
  errorCode: 'ACTION_PAGE_ROUTE_UNAVAILABLE',
  message: 'Registered page action is unavailable.'
});

export class MultiAgentRuntime {
  private readonly bus: LinkedMessageBus;
  private readonly reader: AgentMessageReader;
  private readonly conversationId: string;
  private readonly settingsFingerprint: string;
  private readonly submitTimeoutMs: number;
  private readonly actionTimeoutMs: number;
  private readonly surfaceTurnActivator: ((turnId: string) => void) | null;
  private readonly leader: LeaderAgent;
  private readonly planningContextProvider: (() => LeaderPlanningContext) | null;
  private readonly data: DataAgent;
  private readonly ui: UiAgent;
  private readonly action: ActionAgent;
  private readonly ownedActionExecutor: AiphoneRegisteredActionExecutor | null;
  private pendingTurn: PendingTurn | null = null;
  private readonly pendingActions: Map<string, PendingAction> = new Map<string, PendingAction>();
  private generation: number = 0;
  private sequence: number = 0;
  private active: boolean = true;
  private activeConversationId: string = '';
  private activeTurnId: string = '';
  private activeSurfaceId: string = '';

  constructor(options: MultiAgentRuntimeOptions) {
    this.bus = options.bus === undefined ? new LinkedMessageBus() : options.bus;
    this.conversationId = nonempty(options.conversationId) ?
      options.conversationId as string : 'multi-agent-' + Date.now().toString();
    this.settingsFingerprint = options.settingsFingerprint === undefined ?
      '' : options.settingsFingerprint;
    this.submitTimeoutMs = boundedTimeout(options.submitTimeoutMs, DEFAULT_SUBMIT_TIMEOUT_MS);
    this.actionTimeoutMs = boundedTimeout(options.actionTimeoutMs, DEFAULT_ACTION_TIMEOUT_MS);
    this.surfaceTurnActivator = options.surfaceTurnActivator === undefined ?
      null : options.surfaceTurnActivator;
    this.leader = new LeaderAgent(
      this.bus,
      options.planner,
      options.planningContext,
      this.submitTimeoutMs,
      options.dataTaskInputNormalizer
    );
    this.planningContextProvider = options.planningContextProvider === undefined ?
      null : options.planningContextProvider;
    this.data = new DataAgent(
      this.bus,
      options.dataAuthorizer,
      options.dataExecutor,
      options.dataPlanner
    );
    const uiRenderer = options.uiRenderer === undefined ?
      new StructuredToolUiRenderer(
        options.uiLayoutPlanner === undefined ? null : options.uiLayoutPlanner,
        options.uiLayoutTimeoutMs
      ) : options.uiRenderer;
    const registeredOfferResolver = new RegisteredActionOfferResolver(options.actionCatalog);
    const actionOfferResolver = options.actionOfferResolver === undefined ?
      async (dataResult: DataResult, context: ActionOfferContext): Promise<ActionOffer[]> =>
        registeredOfferResolver.resolve(dataResult, context) : options.actionOfferResolver;
    let actionExecutor: RegisteredActionExecutor;
    if (options.actionExecutor === undefined) {
      const ownedActionExecutor = new AiphoneRegisteredActionExecutor(
        options.actionCatalog,
        options.systemUriOpener === undefined ? new RejectSystemUriOpener() : options.systemUriOpener,
        options.actionIdFactory === undefined ? new RuntimeActionIds() : options.actionIdFactory,
        options.registeredPageAction === undefined ? rejectPageAction : options.registeredPageAction
      );
      this.ownedActionExecutor = ownedActionExecutor;
      actionExecutor = ownedActionExecutor;
    } else {
      this.ownedActionExecutor = null;
      actionExecutor = options.actionExecutor;
    }
    this.ui = new UiAgent(this.bus, uiRenderer, options.surfaceWriter);
    this.action = new ActionAgent(
      this.bus,
      options.actionCatalog,
      actionOfferResolver,
      actionExecutor,
      options.actionCompiler,
      options.virtualActionResolver
    );
    // The observer is the fifth and final reader. All five exist before any
    // public method can publish INPUT.USER.
    this.reader = this.bus.openReader();
    this.leader.start();
    this.data.start();
    this.ui.start();
    this.action.start();
    this.observe();
  }

  submit(text: string, context: UserInputPayload): Promise<MultiAgentTurnOutcome> {
    const prompt: string = text.trim();
    if (!this.active || prompt.length === 0) {
      return Promise.resolve(settled('canceled', 'Multi-agent runtime is unavailable.'));
    }
    this.cancelActiveTurn('superseded');
    const contextProvider: (() => LeaderPlanningContext) | null = this.planningContextProvider;
    if (contextProvider !== null) {
      try {
        this.leader.updatePlanningContext(contextProvider());
      } catch (_error) {
        return Promise.resolve(settled('error', 'Multi-agent planning context refresh failed.'));
      }
    }
    this.generation++;
    const turnId: string = this.nextId('turn');
    const inputTaskId: string = this.nextId('input');
    const payload: UserInputPayload = this.boundedInput(prompt, context);
    return new Promise<MultiAgentTurnOutcome>((resolve: (outcome: MultiAgentTurnOutcome) => void) => {
      const pending: PendingTurn = {
        conversationId: this.conversationId,
        turnId,
        inputTaskId,
        generation: this.generation,
        uiTaskId: '',
        uiTerminal: false,
        uiState: '',
        uiSurfaceId: '',
        terminal: null,
        virtualActionTaskId: '',
        virtualActionSurfaceId: '',
        virtualActionPlanId: '',
        virtualActionRunId: '',
        timerId: -1,
        resolve
      };
      pending.timerId = setTimeout(() => {
        this.timeoutTurn(pending);
      }, this.submitTimeoutMs);
      this.pendingTurn = pending;
      this.bus.publish({
        type: AgentMessageType.INPUT_USER,
        conversationId: pending.conversationId,
        turnId: pending.turnId,
        taskId: pending.inputTaskId,
        payload
      });
    });
  }

  runAction(action: A2uiAction, context: ActionExecutionContext): Promise<boolean> {
    if (!this.active || action.args === undefined || this.pendingActions.size > 0 ||
      !nonempty(context.conversationId) || !nonempty(context.turnId) ||
      !nonempty(context.surfaceId) || !nonempty(context.sourceToolId)) {
      return Promise.resolve(false);
    }
    const taskId: string = this.nextId('action-task');
    const runId: string = this.nextId('action-run');
    const planId: string = 'direct:' + runId;
    const payload: ActionRunPayload = {
      surfaceId: context.surfaceId,
      runId,
      sourceToolId: context.sourceToolId,
      actionId: action.id,
      args: action.args
    };
    const message: AgentMessage = {
      type: AgentMessageType.ACTION_RUN,
      conversationId: context.conversationId,
      turnId: context.turnId,
      taskId,
      payload
    };
    if (!this.action.authorizeDirectSurfaceRun(message)) {
      return Promise.resolve(false);
    }
    return new Promise<boolean>((resolve: (ok: boolean) => void) => {
      const pending: PendingAction = {
        conversationId: context.conversationId,
        turnId: context.turnId,
        taskId,
        surfaceId: context.surfaceId,
        planId,
        runId,
        generation: this.generation,
        directTerminal: false,
        directSucceeded: false,
        followUpTurnId: '',
        followUpUiTaskId: '',
        followUpDataTaskId: '',
        followUpUiSeen: false,
        followUpDataSeen: false,
        followUpTerminal: false,
        followUpSucceeded: false,
        timerId: -1,
        resolve
      };
      pending.timerId = setTimeout(() => {
        this.timeoutAction(pending);
      }, this.actionTimeoutMs);
      this.pendingActions.set(taskId, pending);
      this.bus.publish(message);
    });
  }

  cancelActiveTurn(reason: string = 'canceled'): void {
    if (!this.active) {
      return;
    }
    const pending: PendingTurn | null = this.pendingTurn;
    if (pending !== null) {
      this.publishCancel(pending.turnId, reason);
      this.publishRuntimeTurnResult(pending, 'canceled', 'Multi-agent turn canceled.', '');
      this.settleTurn(pending, settled('canceled', 'Multi-agent turn canceled.'));
    }
    this.pendingActions.forEach((action: PendingAction) => {
      this.cancelAction(action, reason);
      this.settleAction(action, false);
    });
  }

  dispose(): void {
    if (!this.active) {
      return;
    }
    this.cancelActiveTurn('disposed');
    this.active = false;
    this.generation++;
    this.reader.close();
    this.leader.stop();
    this.data.stop();
    this.ui.stop();
    this.action.stop();
    if (this.ownedActionExecutor !== null) {
      this.ownedActionExecutor.dispose();
    }
    const pending: PendingTurn | null = this.pendingTurn;
    if (pending !== null) {
      this.settleTurn(pending, settled('canceled', 'Multi-agent runtime disposed.'));
    }
    this.pendingActions.forEach((action: PendingAction) => {
      this.settleAction(action, false);
    });
    this.activeConversationId = '';
    this.activeTurnId = '';
    this.activeSurfaceId = '';
  }

  private async observe(): Promise<void> {
    while (this.active) {
      let message: AgentMessage | null = null;
      try {
        message = await this.reader.receive();
      } catch (_error) {
        this.failPending('Multi-agent observer failed.');
        return;
      }
      if (message === null || !this.active) {
        return;
      }
      try {
        this.observeMessage(message);
      } catch (_error) {
        this.failPending('Multi-agent correlation failed.');
      }
    }
  }

  private observeMessage(message: AgentMessage): void {
    if (message.conversationId !== this.conversationId) {
      return;
    }
    const action: PendingAction | undefined = this.pendingActions.get(message.taskId);
    if (message.type === AgentMessageType.ACTION_RESULT && action !== undefined) {
      this.observeActionResult(message, action);
      return;
    }
    const followUp: PendingAction | null = this.followUpAction(message);
    if (followUp !== null) {
      if (message.type === AgentMessageType.TASK_CREATE_UI) {
        this.observeFollowUpUiTask(message, followUp);
        return;
      }
      if (message.type === AgentMessageType.TASK_CREATE_DATA) {
        this.observeFollowUpDataTask(message, followUp);
        return;
      }
      if (message.type === AgentMessageType.TASK_RESULT_UI) {
        this.observeFollowUpUiResult(message, followUp);
        return;
      }
      if (message.type === AgentMessageType.TASK_ERROR) {
        this.observeFollowUpError(message, followUp);
        return;
      }
    }
    const pending: PendingTurn | null = this.pendingTurn;
    if (pending === null || message.turnId !== pending.turnId ||
      pending.generation !== this.generation) {
      return;
    }
    if (message.type === AgentMessageType.TASK_CREATE_UI) {
      this.activateSurfaceTurn(message.turnId);
      pending.uiTaskId = message.taskId;
      pending.uiTerminal = false;
      pending.uiState = '';
      pending.uiSurfaceId = '';
      return;
    }
    if (message.type === AgentMessageType.TASK_RESULT_UI) {
      this.observeUiResult(message, pending);
      return;
    }
    if (message.type === AgentMessageType.ACTION_PLAN_REQUEST) {
      this.observeActionRequest(message, pending);
      return;
    }
    if (message.type === AgentMessageType.ACTION_RESULT) {
      this.observeVirtualActionResult(message, pending);
      return;
    }
    if (message.type === AgentMessageType.TURN_RESULT) {
      this.observeTurnResult(message, pending);
      return;
    }
    if (message.type === AgentMessageType.TURN_HANDOFF) {
      this.observeHandoff(message, pending);
      return;
    }
    if (message.type === AgentMessageType.TASK_ERROR) {
      const error: TaskErrorPayload = message.payload as TaskErrorPayload;
      if (message.taskId === pending.inputTaskId || message.taskId === pending.uiTaskId ||
        message.taskId === pending.virtualActionTaskId) {
        const detail: string = nonempty(error.message) ? error.message : 'Multi-agent task failed.';
        this.forceTurn(pending, 'error', detail, pending.uiSurfaceId, 'task_error');
      }
    }
  }

  private observeUiResult(message: AgentMessage, pending: PendingTurn): void {
    if (message.taskId !== pending.uiTaskId) {
      return;
    }
    const result: UiRenderResultPayload = message.payload as UiRenderResultPayload;
    if (!nonempty(result.surfaceId) ||
      (result.state !== 'result' && result.state !== 'error')) {
      return;
    }
    pending.uiTerminal = true;
    pending.uiState = result.state;
    pending.uiSurfaceId = result.surfaceId;
    this.trySettleTurn(pending);
  }

  private observeActionRequest(message: AgentMessage, pending: PendingTurn): void {
    const request: ActionPlanRequestPayload = message.payload as ActionPlanRequestPayload;
    if (request.virtual === true && Array.isArray(request.dataTaskIds) &&
      request.dataTaskIds.length === 0) {
      pending.virtualActionTaskId = message.taskId;
      pending.virtualActionSurfaceId = 'virtual:' + message.taskId;
      pending.virtualActionRunId = pending.virtualActionSurfaceId;
      pending.virtualActionPlanId = 'direct:' + pending.virtualActionRunId;
    }
  }

  private observeVirtualActionResult(message: AgentMessage, pending: PendingTurn): void {
    if (message.taskId !== pending.virtualActionTaskId || pending.virtualActionTaskId.length === 0) {
      return;
    }
    const result: ActionResultPayload = message.payload as ActionResultPayload;
    if (result.surfaceId !== pending.virtualActionSurfaceId ||
      result.planId !== pending.virtualActionPlanId ||
      result.runId !== pending.virtualActionRunId ||
      result.status === 'paused') {
      return;
    }
    const status: TurnResultStatus = result.status === 'success' ? 'success' :
      result.status === 'canceled' ? 'canceled' : 'error';
    const messageText: string = result.status === 'success' ?
      'Action completed.' : nonempty(result.message) ? result.message as string : 'Action failed.';
    const surfaceId: string = this.actionOutputSurfaceId(result);
    if (status !== 'success') {
      this.publishCancel(pending.turnId, 'virtual_action_' + status);
    }
    this.publishRuntimeTurnResult(pending, status, messageText, surfaceId);
  }

  private observeTurnResult(message: AgentMessage, pending: PendingTurn): void {
    if (message.taskId !== pending.inputTaskId || pending.terminal !== null) {
      return;
    }
    const result: TurnResultPayload = message.payload as TurnResultPayload;
    if (!this.validTurnResult(result)) {
      return;
    }
    pending.terminal = result;
    this.trySettleTurn(pending);
  }

  private observeHandoff(message: AgentMessage, pending: PendingTurn): void {
    if (message.taskId !== pending.inputTaskId) {
      return;
    }
    const payload: LegacyHandoffPayload = message.payload as LegacyHandoffPayload;
    if (!nonempty(payload.reasonCode) || !nonempty(payload.personaId) ||
      typeof payload.skillId !== 'string') {
      return;
    }
    const outcome: MultiAgentHandoffOutcome = {
      kind: 'handoff',
      reasonCode: payload.reasonCode,
      personaId: payload.personaId,
      skillId: payload.skillId
    };
    this.settleTurn(pending, outcome);
  }

  private trySettleTurn(pending: PendingTurn): void {
    if (this.pendingTurn !== pending || pending.terminal === null ||
      (pending.uiTaskId.length > 0 && !pending.uiTerminal)) {
      return;
    }
    const result: TurnResultPayload = pending.terminal;
    const surfaceId: string = pending.uiTaskId.length > 0 ?
      pending.uiSurfaceId : result.surfaceId === undefined ? '' : result.surfaceId;
    if (pending.uiState === 'error') {
      this.forceTurn(
        pending,
        'error',
        'Multi-agent UI rendering failed.',
        surfaceId,
        'ui_error'
      );
      return;
    }
    this.activeConversationId = pending.conversationId;
    this.activeTurnId = pending.turnId;
    this.activeSurfaceId = surfaceId;
    this.settleTurn(pending, settled(result.status, result.message, surfaceId));
  }

  private observeActionResult(message: AgentMessage, pending: PendingAction): void {
    const result: ActionResultPayload = message.payload as ActionResultPayload;
    if (pending.generation !== this.generation ||
      message.conversationId !== pending.conversationId ||
      message.turnId !== pending.turnId ||
      result.surfaceId !== pending.surfaceId ||
      result.planId !== pending.planId ||
      result.runId !== pending.runId ||
      result.status === 'paused') {
      return;
    }
    pending.directTerminal = true;
    pending.directSucceeded = result.status === 'success';
    this.trySettleAction(pending);
  }

  private followUpAction(message: AgentMessage): PendingAction | null {
    let found: PendingAction | null = null;
    this.pendingActions.forEach((pending: PendingAction) => {
      if (found !== null || pending.generation !== this.generation ||
        message.conversationId !== pending.conversationId ||
        message.turnId === pending.turnId) {
        return;
      }
      if (pending.followUpTurnId.length > 0) {
        if (message.turnId === pending.followUpTurnId &&
          (message.taskId === pending.followUpUiTaskId ||
            message.taskId === pending.followUpDataTaskId)) {
          found = pending;
        }
        return;
      }
      if (message.type === AgentMessageType.TASK_CREATE_UI) {
        found = pending;
      }
    });
    return found;
  }

  private observeFollowUpUiTask(message: AgentMessage, pending: PendingAction): void {
    const task = message.payload as CreateUiTaskPayload;
    if (pending.followUpTurnId.length > 0 || task === null || typeof task !== 'object' ||
      Array.isArray(task) || task.taskId !== message.taskId ||
      !Array.isArray(task.dataTaskIds) || task.dataTaskIds.length !== 1 ||
      !nonempty(task.dataTaskIds[0]) || task.dataTaskIds[0] === message.taskId ||
      !nonempty(task.intent) || !nonempty(task.expectedOutputSchema)) {
      return;
    }
    pending.followUpTurnId = message.turnId;
    pending.followUpUiTaskId = message.taskId;
    pending.followUpDataTaskId = task.dataTaskIds[0];
    pending.followUpUiSeen = true;
    this.activateSurfaceTurn(message.turnId);
  }

  private activateSurfaceTurn(turnId: string): void {
    const activate = this.surfaceTurnActivator;
    if (activate === null) {
      return;
    }
    try {
      activate(turnId);
    } catch (_error) {
    }
  }

  private observeFollowUpDataTask(message: AgentMessage, pending: PendingAction): void {
    const task = message.payload as CreateDataTaskPayload;
    if (pending.followUpTurnId !== message.turnId ||
      pending.followUpDataTaskId !== message.taskId || task === null ||
      typeof task !== 'object' || Array.isArray(task) || task.taskId !== message.taskId ||
      !nonempty(task.toolId) || !nonempty(task.outputSchema)) {
      return;
    }
    pending.followUpDataSeen = true;
  }

  private observeFollowUpUiResult(message: AgentMessage, pending: PendingAction): void {
    const result = message.payload as UiRenderResultPayload;
    if (!pending.followUpUiSeen || !pending.followUpDataSeen ||
      message.turnId !== pending.followUpTurnId ||
      message.taskId !== pending.followUpUiTaskId || !nonempty(result.surfaceId) ||
      (result.state !== 'result' && result.state !== 'error')) {
      return;
    }
    pending.followUpTerminal = true;
    pending.followUpSucceeded = result.state === 'result';
    this.trySettleAction(pending);
  }

  private observeFollowUpError(message: AgentMessage, pending: PendingAction): void {
    if (message.turnId !== pending.followUpTurnId ||
      (message.taskId !== pending.followUpUiTaskId &&
        message.taskId !== pending.followUpDataTaskId)) {
      return;
    }
    // UiAgent normally converts an owned Data error into its exact terminal
    // UI error. If the UI task itself fails, no later terminal write is safe.
    if (message.taskId === pending.followUpUiTaskId) {
      pending.followUpTerminal = true;
      pending.followUpSucceeded = false;
      this.trySettleAction(pending);
    }
  }

  private trySettleAction(pending: PendingAction): void {
    if (this.pendingActions.get(pending.taskId) !== pending || !pending.directTerminal) {
      return;
    }
    if (!pending.directSucceeded) {
      this.settleAction(pending, false);
      return;
    }
    if (pending.followUpTurnId.length === 0) {
      this.settleAction(pending, true);
      return;
    }
    if (!pending.followUpUiSeen || !pending.followUpDataSeen || !pending.followUpTerminal) {
      return;
    }
    this.settleAction(pending, pending.followUpSucceeded);
  }

  private timeoutTurn(pending: PendingTurn): void {
    if (this.pendingTurn !== pending || pending.generation !== this.generation) {
      return;
    }
    this.publishCancel(pending.turnId, 'timeout');
    this.publishRuntimeTurnResult(pending, 'error', 'Multi-agent turn timed out.', pending.uiSurfaceId);
    this.settleTurn(
      pending,
      settled('error', 'Multi-agent turn timed out.', pending.uiSurfaceId)
    );
  }

  private timeoutAction(pending: PendingAction): void {
    if (this.pendingActions.get(pending.taskId) !== pending ||
      pending.generation !== this.generation) {
      return;
    }
    this.cancelAction(pending, 'action_timeout');
    this.settleAction(pending, false);
  }

  private cancelAction(pending: PendingAction, reason: string): void {
    this.publishCancel(pending.turnId, reason);
    if (pending.followUpTurnId.length > 0 && pending.followUpTurnId !== pending.turnId) {
      this.publishCancel(pending.followUpTurnId, reason);
    }
  }

  private publishRuntimeTurnResult(
    pending: PendingTurn,
    status: TurnResultStatus,
    message: string,
    surfaceId: string
  ): void {
    const payload: TurnResultPayload = {
      status,
      roundCount: 0,
      message
    };
    if (surfaceId.length > 0) {
      payload.surfaceId = surfaceId;
    }
    this.bus.publish({
      type: AgentMessageType.TURN_RESULT,
      conversationId: pending.conversationId,
      turnId: pending.turnId,
      taskId: pending.inputTaskId,
      payload
    });
  }

  private publishCancel(turnId: string, reason: string): void {
    const payload: RuntimeCancelPayload = { reason };
    this.bus.publish({
      type: AgentMessageType.TURN_CANCEL,
      conversationId: this.conversationId,
      turnId,
      taskId: this.nextId('cancel'),
      payload
    });
  }

  private settleTurn(pending: PendingTurn, outcome: MultiAgentTurnOutcome): void {
    if (this.pendingTurn !== pending) {
      return;
    }
    this.pendingTurn = null;
    if (pending.timerId >= 0) {
      clearTimeout(pending.timerId);
      pending.timerId = -1;
    }
    pending.resolve(outcome);
  }

  private settleAction(pending: PendingAction, ok: boolean): void {
    if (this.pendingActions.get(pending.taskId) !== pending) {
      return;
    }
    this.pendingActions.delete(pending.taskId);
    if (pending.timerId >= 0) {
      clearTimeout(pending.timerId);
      pending.timerId = -1;
    }
    pending.resolve(ok);
  }

  private failPending(message: string): void {
    const pending: PendingTurn | null = this.pendingTurn;
    if (pending !== null) {
      this.forceTurn(pending, 'error', message, pending.uiSurfaceId, 'observer_error');
    }
    this.pendingActions.forEach((action: PendingAction) => {
      this.settleAction(action, false);
    });
  }

  private forceTurn(
    pending: PendingTurn,
    status: TurnResultStatus,
    message: string,
    surfaceId: string,
    reason: string
  ): void {
    if (this.pendingTurn !== pending) {
      return;
    }
    this.publishCancel(pending.turnId, reason);
    this.publishRuntimeTurnResult(pending, status, message, surfaceId);
    this.settleTurn(pending, settled(status, message, surfaceId));
  }

  private validTurnResult(result: TurnResultPayload): boolean {
    if (result === null || typeof result !== 'object' || Array.isArray(result)) {
      return false;
    }
    const keys: string = Object.keys(result).sort().join(',');
    return (keys === 'message,roundCount,status' ||
      keys === 'message,roundCount,status,surfaceId') &&
      (result.status === 'success' || result.status === 'partial' ||
        result.status === 'empty' || result.status === 'error' ||
        result.status === 'canceled') &&
      Number.isInteger(result.roundCount) && result.roundCount >= 0 &&
      typeof result.message === 'string' &&
      (result.surfaceId === undefined || nonempty(result.surfaceId));
  }

  private actionOutputSurfaceId(result: ActionResultPayload): string {
    if (result.outputs === undefined || result.outputs.length === 0) {
      return result.surfaceId;
    }
    const output = result.outputs[result.outputs.length - 1].output;
    if (output === null || typeof output !== 'object' || Array.isArray(output)) {
      return result.surfaceId;
    }
    const surfaceId = (output as Record<string, Object | string | number | boolean | null | undefined>)['surfaceId'];
    return typeof surfaceId === 'string' && surfaceId.length > 0 ? surfaceId : result.surfaceId;
  }

  private boundedInput(text: string, context: UserInputPayload): UserInputPayload {
    const result: UserInputPayload = {
      text,
      recentMessages: this.boundedMessages(context.recentMessages),
      previousPersonaId: context.previousPersonaId === undefined ? '' : context.previousPersonaId,
      currentSurfaceSummary: this.copySurface(context.currentSurfaceSummary),
      recentObservations: this.boundedObservations(context.recentObservations)
    };
    return result;
  }

  private boundedMessages(values: ConversationTurnMessage[] | undefined): ConversationTurnMessage[] {
    if (values === undefined) {
      return [];
    }
    const messages: ConversationTurnMessage[] = [];
    const start: number = values.length > CONTEXT_MESSAGE_LIMIT ?
      values.length - CONTEXT_MESSAGE_LIMIT : 0;
    for (let index = start; index < values.length; index++) {
      const message = values[index];
      if ((message.role === 'user' || message.role === 'assistant') &&
        typeof message.content === 'string' && message.content.trim().length > 0) {
        messages.push({ role: message.role, content: message.content.substring(0, 2000) });
      }
    }
    return messages;
  }

  private boundedObservations(values: ObservationDigest[] | undefined): ObservationDigest[] {
    if (values === undefined) {
      return [];
    }
    const observations: ObservationDigest[] = [];
    const start: number = values.length > CONTEXT_OBSERVATION_LIMIT ?
      values.length - CONTEXT_OBSERVATION_LIMIT : 0;
    for (let index = start; index < values.length; index++) {
      const value = values[index];
      observations.push({
        taskId: value.taskId.substring(0, 128),
        toolId: value.toolId.substring(0, 128),
        status: value.status.substring(0, 32),
        summary: value.summary.substring(0, 240),
        entityRefs: value.entityRefs.slice(0, 16)
      });
    }
    return observations;
  }

  private copySurface(value: CurrentSurfaceSummary | undefined): CurrentSurfaceSummary {
    if (value === undefined) {
      return { surfaceId: '', kind: '', status: '', entityRefs: [], actionOfferIds: [] };
    }
    return {
      surfaceId: value.surfaceId,
      kind: value.kind,
      status: value.status,
      entityRefs: value.entityRefs.slice(0, 16),
      actionOfferIds: value.actionOfferIds.slice(0, 16)
    };
  }

  private nextId(kind: string): string {
    this.sequence++;
    const fingerprint: string = this.settingsFingerprint.length === 0 ?
      'default' : this.settingsFingerprint.substring(0, 16);
    return kind + ':' + fingerprint + ':' + this.sequence.toString();
  }
}
