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
  UserInputPayload,
  aiLogInfo
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
  hostGeneration: number;
  requestedCapabilityIds: string[];
  runtimeOwnedToolIds: string[];
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
  hostGeneration: number;
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

type MailIdentityValue = Object | string | number | boolean | null | undefined;

function mailIdentityText(value: MailIdentityValue): string {
  return typeof value === 'string' ? value.trim() : '';
}

function mailIdentityHash(value: string): string {
  let hash: number = 2166136261;
  for (let index: number = 0; index < value.length; index++) {
    hash = Math.imul(hash ^ value.charCodeAt(index), 16777619) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}

export function mailDetailIdentityDigest(value: Object): string {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return '';
  }
  const record = value as Record<string, MailIdentityValue>;
  const provider = mailIdentityText(record['provider']).toLowerCase();
  const requestKey = mailIdentityText(record['requestKey']);
  const threadId = mailIdentityText(record['threadId']);
  const messageId = mailIdentityText(record['messageId']);
  if ((provider !== 'gmail' && provider !== 'qq') || requestKey.length === 0 || messageId.length === 0) {
    return '';
  }
  const material = provider.length.toString() + ':' + provider + '|' +
    requestKey.length.toString() + ':' + requestKey + '|' +
    threadId.length.toString() + ':' + threadId + '|' +
    messageId.length.toString() + ':' + messageId;
  return mailIdentityHash(material);
}

function mailEvidenceSuffix(toolId: string, value: Object): string {
  if (toolId !== 'mail.thread.read' && toolId !== 'gmail.thread.read') {
    return '';
  }
  const record = value as Record<string, MailIdentityValue>;
  const provider = mailIdentityText(record['provider']).toLowerCase();
  const digest = mailDetailIdentityDigest(value);
  return ' provider=' + evidenceAllowed(provider, ['gmail', 'qq']) +
    ' identity=' + (digest.length > 0 ? digest : 'invalid');
}

function evidenceAllowed(
  value: string | undefined, values: string[] = [],
  pattern: RegExp = /^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$/
): string {
  return value !== undefined && value.length > 0 && value.length <= 96 &&
    (values.length > 0 ? values.indexOf(value) >= 0 : pattern.test(value)) ? value : 'invalid';
}

export class MultiAgentEvidenceFormatter {
  private readonly limit: number;
  private readonly tokens: Map<string, string> = new Map<string, string>();
  private readonly order: string[] = [];
  private sequence: number = 0;
  constructor(limit: number = 128) { this.limit = Number.isInteger(limit) && limit >= 8 ? Math.min(limit, 512) : 128; }
  dispose(): void { this.tokens.clear(); this.order.splice(0, this.order.length); this.sequence = 0; }
  pageActionDispatchLine(
    conversationId: string,
    originTurnId: string,
    turnId: string,
    surfaceId: string,
    sourceToolId: string,
    actionId: string,
    runId: string
  ): string {
    return '[AIPhone][MultiAgentPageActionDispatch] conversation=' + this.token('c', conversationId) +
      ' origin=' + this.token('t', originTurnId) + ' turn=' + this.token('t', turnId) +
      ' surface=' + evidenceAllowed(surfaceId, [], /^loop_surface_[0-9]+(?:_[0-9]+)?$/) +
      ' source=' + evidenceAllowed(sourceToolId) + ' action=' + evidenceAllowed(actionId) +
      ' dispatch=' + this.token('r', runId);
  }
  line(message: AgentMessage): string {
    const identity: string = ' conversation=' + this.token('c', message.conversationId) +
      ' turn=' + this.token('t', message.turnId) +
      ' task=' + this.token('k', message.taskId);
    switch (message.type) {
      case AgentMessageType.INPUT_USER: return '[AIPhone][MultiAgentInput]' + identity;
      case AgentMessageType.TASK_CREATE_DATA: return this.dataTaskLine(message, identity);
      case AgentMessageType.TASK_RESULT_DATA: {
        const payload = message.payload as DataResult;
        this.rememberEntities(payload.data, this.token('k', message.taskId));
        return '[AIPhone][MultiAgentDataResult]' + identity + ' tool=' + evidenceAllowed(payload.toolId) +
          ' status=' + evidenceAllowed(payload.status, ['success', 'partial', 'empty', 'error']) +
          ' sources=' + payload.sources.length.toString() + ' error=' + (payload.error === undefined ? 'false' : 'true') +
          mailEvidenceSuffix(payload.toolId, payload.data);
      }
      case AgentMessageType.TASK_CREATE_UI: {
        const payload = message.payload as CreateUiTaskPayload;
        return '[AIPhone][MultiAgentUiTask]' + identity + ' dataTasks=' + this.values(payload.dataTaskIds, 'k');
      }
      case AgentMessageType.TASK_RESULT_UI: {
        const payload = message.payload as UiRenderResultPayload;
        return '[AIPhone][MultiAgentUiResult]' + identity + ' surface=' + evidenceAllowed(payload.surfaceId, [], /^loop_surface_[0-9]+(?:_[0-9]+)?$/) +
          ' state=' + evidenceAllowed(payload.state, ['skeleton', 'result', 'error', 'action']);
      }
      case AgentMessageType.TASK_ERROR: {
        const payload = message.payload as TaskErrorPayload;
        return '[AIPhone][MultiAgentTaskError]' + identity + ' code=' +
          evidenceAllowed(payload.code, [], /^[A-Z][A-Z0-9_]*$/);
      }
      case AgentMessageType.ACTION_PLAN_REQUEST: {
        const payload = message.payload as ActionPlanRequestPayload;
        return '[AIPhone][MultiAgentActionPlan]' + identity + ' uiTask=' + this.token('k', payload.uiTaskId) +
          ' dataTasks=' + this.values(payload.dataTaskIds, 'k') + ' actions=' +
          this.values(payload.allowedActionIds, '') + ' virtual=' + (payload.virtual === true ? 'true' : 'false');
      }
      case AgentMessageType.ACTION_RUN: {
        const payload = message.payload as ActionRunPayload;
        return '[AIPhone][MultiAgentActionRun]' + identity + ' surface=' + evidenceAllowed(payload.surfaceId, [], /^loop_surface_[0-9]+(?:_[0-9]+)?$/) +
          ' plan=' + this.token('p', 'direct:' + payload.runId) + ' run=' + this.token('r', payload.runId) +
          ' action=' + evidenceAllowed(payload.actionId) + ' source=' + evidenceAllowed(payload.sourceToolId) +
          mailEvidenceSuffix(payload.actionId, payload.args);
      }
      case AgentMessageType.ACTION_RESULT: {
        const payload = message.payload as ActionResultPayload;
        return '[AIPhone][MultiAgentActionResult]' + identity + ' surface=' + evidenceAllowed(payload.surfaceId, [], /^loop_surface_[0-9]+(?:_[0-9]+)?$/) +
          ' plan=' + this.token('p', payload.planId) + ' run=' + this.token('r', payload.runId) +
          ' status=' + evidenceAllowed(payload.status, ['success', 'error', 'canceled', 'paused']);
      }
      case AgentMessageType.TURN_RESULT: {
        const payload = message.payload as TurnResultPayload;
        return '[AIPhone][MultiAgentTurnResult]' + identity + ' status=' +
          evidenceAllowed(payload.status, ['success', 'partial', 'empty', 'error', 'canceled']) + ' surface=' +
          (payload.surfaceId === undefined ? 'none' : evidenceAllowed(payload.surfaceId, [], /^loop_surface_[0-9]+(?:_[0-9]+)?$/)) + ' roundCount=' +
          payload.roundCount.toString() + ' messageChars=' + payload.message.length.toString();
      }
      default: return '';
    }
  }
  private dataTaskLine(message: AgentMessage, identity: string): string {
    const payload = message.payload as CreateDataTaskPayload;
    const prefix: string = message.turnId + ':round-';
    const suffix: string = payload.roundId.startsWith(prefix) ? payload.roundId.substring(prefix.length) : '';
    const round: string = /^[1-9]\d*$/.test(suffix) ? suffix : 'invalid';
    let predecessor: string = 'none';
    let path: string = 'none';
    const args = payload.args as Record<string, Object | string | number | boolean | null | undefined>;
    const placeId = args['placeId'];
    const provenance: string | undefined = typeof placeId === 'string' ? this.tokens.get('e:' + placeId) : undefined;
    if (provenance !== undefined) {
      const separator: number = provenance.indexOf('|');
      predecessor = provenance.substring(0, separator);
      path = provenance.substring(separator + 1);
    }
    return '[AIPhone][MultiAgentDataTask]' + identity + ' round=' + round +
      ' tool=' + evidenceAllowed(payload.toolId) + ' predecessor=' + predecessor +
      ' path=' + path + ' target=' + (provenance === undefined ? 'none' : '/placeId') +
      ' binding=' + (provenance === undefined ? 'false' : 'true') +
      mailEvidenceSuffix(payload.toolId, payload.args);
  }
  private rememberEntities(data: Object, task: string): void {
    if (data === null || typeof data !== 'object' || Array.isArray(data)) return;
    const values = data as Record<string, Object | string | number | boolean | null | undefined>;
    const refs = values['entityRefs'];
    if (Array.isArray(refs)) refs.slice(0, 16).forEach((ref: Object, index: number) =>
      this.remember(ref, task, '/entityRefs/' + index.toString()));
    const places = values['places'];
    if (Array.isArray(places)) places.slice(0, 16).forEach((place: Object, index: number) => {
      if (place !== null && typeof place === 'object' && !Array.isArray(place)) {
        this.remember((place as Record<string, Object>)['placeId'], task, '/places/' + index.toString() + '/placeId');
      }
    });
  }
  private remember(ref: Object, task: string, path: string): void {
    if (typeof ref === 'string' && ref.length > 0 && ref.length <= 256 && ref.indexOf('\n') < 0) {
      this.put('e:' + ref, task + '|' + path);
    }
  }
  private values(values: string[], kind: string): string {
    if (values.length === 0) return 'none';
    const result: string[] = [];
    for (let index = 0; index < values.length; index++) {
      result.push(kind.length > 0 ? this.token(kind, values[index]) : evidenceAllowed(values[index]));
    }
    return result.join(',');
  }
  private token(kind: string, value: string): string {
    if (value.length === 0) return 'none';
    if (value.length > 256 || value.indexOf('\n') >= 0 || value.indexOf('\r') >= 0) {
      return 'invalid';
    }
    const key: string = kind + ':' + value;
    const existing: string | undefined = this.tokens.get(key);
    if (existing !== undefined) return existing;
    this.sequence++;
    const token: string = kind + this.sequence.toString();
    this.put(key, token);
    return token;
  }
  private put(key: string, value: string): void {
    if (this.tokens.has(key)) { this.tokens.set(key, value); return; }
    while (this.order.length >= this.limit) {
      const oldest: string | undefined = this.order.shift();
      if (oldest !== undefined) {
        this.tokens.delete(oldest);
      }
    }
    this.tokens.set(key, value);
    this.order.push(key);
  }
}

function emitEvidence(formatter: MultiAgentEvidenceFormatter, message: AgentMessage): void {
  try {
    const line: string = formatter.line(message);
    if (line.length > 0) aiLogInfo(line);
  } catch (_error) {}
}

function runtimeOwnedIds(context: LeaderPlanningContext): string[] {
  return context.runtimeOwnedToolIds === undefined ? [] : context.runtimeOwnedToolIds.slice();
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
  private readonly surfaceTurnActivator: ((turnId: string, hostGeneration: number) => void) | null;
  private readonly turnGenerationObserver: ((turnId: string, hostGeneration: number) => void) | null;
  private readonly leader: LeaderAgent;
  private readonly planningContextProvider: (() => LeaderPlanningContext) | null;
  private runtimeOwnedToolIds: string[];
  private readonly data: DataAgent;
  private readonly ui: UiAgent;
  private readonly action: ActionAgent;
  private readonly ownedActionExecutor: AiphoneRegisteredActionExecutor | null;
  private readonly evidenceFormatter: MultiAgentEvidenceFormatter = new MultiAgentEvidenceFormatter();
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
    this.turnGenerationObserver = options.turnGenerationObserver === undefined ?
      null : options.turnGenerationObserver;
    this.runtimeOwnedToolIds = runtimeOwnedIds(options.planningContext);
    this.leader = new LeaderAgent(
      this.bus,
      options.planner,
      options.planningContext,
      this.submitTimeoutMs,
      options.dataTaskInputNormalizer,
      (
        conversationId: string,
        turnId: string,
        taskId: string,
        requestedCapabilityIds: string[]
      ): void => this.recordRequestedCapabilities(
        conversationId, turnId, taskId, requestedCapabilityIds
      )
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

  submit(
    text: string,
    context: UserInputPayload,
    hostGeneration: number = 0
  ): Promise<MultiAgentTurnOutcome> {
    const prompt: string = text.trim();
    if (!this.active || prompt.length === 0) {
      return Promise.resolve(settled('canceled', 'Multi-agent runtime is unavailable.'));
    }
    this.cancelActiveTurn('superseded');
    const contextProvider: (() => LeaderPlanningContext) | null = this.planningContextProvider;
    if (contextProvider !== null) {
      try {
        const planningContext = contextProvider();
        this.leader.updatePlanningContext(planningContext);
        this.runtimeOwnedToolIds = runtimeOwnedIds(planningContext);
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
        hostGeneration,
        requestedCapabilityIds: [],
        runtimeOwnedToolIds: this.runtimeOwnedToolIds.slice(),
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
      const observeGeneration = this.turnGenerationObserver;
      if (observeGeneration !== null) {
        try {
          observeGeneration(pending.turnId, pending.hostGeneration);
        } catch (_error) {
          this.cancelActiveTurn('turn_generation_observer_failed');
          return;
        }
      }
      this.bus.publish({
        type: AgentMessageType.INPUT_USER,
        conversationId: pending.conversationId,
        turnId: pending.turnId,
        taskId: pending.inputTaskId,
        payload
      });
    });
  }

  runAction(
    action: A2uiAction,
    context: ActionExecutionContext,
    hostGeneration: number = 0
  ): Promise<boolean> {
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
    if (!this.action.authorizeDirectSurfaceRun(
      message,
      context.pageActionId === undefined ? '' : context.pageActionId
    )) {
      return Promise.resolve(false);
    }
    try {
      const originTurnId: string = this.activeConversationId === context.conversationId &&
        this.activeSurfaceId === context.surfaceId ? this.activeTurnId : '';
      aiLogInfo(this.evidenceFormatter.pageActionDispatchLine(
        context.conversationId,
        originTurnId,
        context.turnId,
        context.surfaceId,
        context.sourceToolId,
        action.id,
        runId
      ));
    } catch (_error) {}
    return new Promise<boolean>((resolve: (ok: boolean) => void) => {
      const pending: PendingAction = {
        conversationId: context.conversationId,
        turnId: context.turnId,
        taskId,
        surfaceId: context.surfaceId,
        planId,
        runId,
        generation: this.generation,
        hostGeneration,
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
    this.evidenceFormatter.dispose();
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
    emitEvidence(this.evidenceFormatter, message);
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
      this.activateSurfaceTurn(message.turnId, pending.hostGeneration);
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
    if (payload.owner !== 'legacy' || payload.reason !== 'unmigrated_tool' ||
      payload.reasonCode !== 'unmigrated_tool' || !nonempty(payload.personaId) ||
      typeof payload.skillId !== 'string' ||
      !this.validUnmigratedToolIds(payload.unmigratedToolIds) ||
      !this.exactPendingHandoff(payload.unmigratedToolIds, pending)) {
      return;
    }
    const outcome: MultiAgentHandoffOutcome = {
      kind: 'handoff',
      owner: 'legacy',
      reason: 'unmigrated_tool',
      unmigratedToolIds: payload.unmigratedToolIds.slice(),
      reasonCode: payload.reasonCode,
      personaId: payload.personaId,
      skillId: payload.skillId
    };
    this.settleTurn(pending, outcome);
  }

  private recordRequestedCapabilities(
    conversationId: string,
    turnId: string,
    taskId: string,
    requestedCapabilityIds: string[]
  ): void {
    const pending = this.pendingTurn;
    if (pending === null || pending.generation !== this.generation ||
      pending.conversationId !== conversationId || pending.turnId !== turnId ||
      pending.inputTaskId !== taskId) {
      return;
    }
    pending.requestedCapabilityIds = requestedCapabilityIds.slice();
  }

  private exactPendingHandoff(ids: string[], pending: PendingTurn): boolean {
    if (pending.requestedCapabilityIds.length === 0) {
      return false;
    }
    const owned = new Set<string>(pending.runtimeOwnedToolIds);
    const expected: string[] = [];
    for (let index = 0; index < pending.requestedCapabilityIds.length; index++) {
      const toolId = pending.requestedCapabilityIds[index];
      if (!owned.has(toolId)) {
        expected.push(toolId);
      }
    }
    if (expected.length === 0 || expected.length !== ids.length) {
      return false;
    }
    for (let index = 0; index < expected.length; index++) {
      if (expected[index] !== ids[index]) {
        return false;
      }
    }
    return true;
  }

  private validUnmigratedToolIds(ids: string[]): boolean {
    if (!Array.isArray(ids) || ids.length === 0) {
      return false;
    }
    const unique: Set<string> = new Set<string>();
    for (let index = 0; index < ids.length; index++) {
      const toolId: string = ids[index];
      if (!nonempty(toolId) || unique.has(toolId)) {
        return false;
      }
      unique.add(toolId);
    }
    return true;
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
      this.activeConversationId = pending.conversationId;
      this.activeTurnId = pending.turnId;
      this.activeSurfaceId = surfaceId;
      const message: string = result.status === 'error' ?
        result.message : 'Multi-agent UI rendering failed.';
      this.settleTurn(pending, settled('error', message, surfaceId));
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
    this.activateSurfaceTurn(message.turnId, pending.hostGeneration);
  }

  private activateSurfaceTurn(turnId: string, hostGeneration: number): void {
    const activate = this.surfaceTurnActivator;
    if (activate === null) {
      return;
    }
    try {
      activate(turnId, hostGeneration);
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
