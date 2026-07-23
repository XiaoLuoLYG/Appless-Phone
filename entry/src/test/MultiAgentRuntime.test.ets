import { describe, expect, it } from '@ohos/hypium';
import {
  ActionArgsValidator,
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionOffer,
  ActionOfferContext,
  ActionPlanCompiler,
  ActionPlanDraft,
  ActionPlanReadyPayload,
  ActionPlanRequestPayload,
  ActionRunPayload,
  ActionResultPayload,
  ActionValidationResult,
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  ClientActionAuthorizer,
  ConversationTurnMessage,
  CreateDataTaskPayload,
  CreateUiTaskPayload,
  DataResult,
  DataTaskAuthorizationResult,
  DataTaskExecutor,
  InputUserPayload,
  LeaderDecision,
  LeaderDecisionDataTask,
  LeaderPlanner,
  LeaderPlanningContext,
  LinkedMessageBus,
  RegisteredActionExecutor,
  SurfaceActionAuthorizer,
  TaskErrorPayload,
  ToolDefinition,
  ToolDefinitionLookup,
  TurnResultPayload,
  UiRenderResultPayload,
  UiRenderResult,
  UiSurfaceWriteLease,
  UiSurfaceWriter,
  UiTaskRenderer,
  VirtualActionIntent,
  VirtualActionIntentResolver
} from '@loop/agent-core';
import {
  MultiAgentEvidenceFormatter,
  MultiAgentRuntime
} from '../main/ets/pages/A2uiHome/agent/MultiAgentRuntime';
import {
  MultiAgentRuntimeOptions,
  MultiAgentSettledOutcome
} from '../main/ets/pages/A2uiHome/agent/MultiAgentRuntimeTypes';

class TestGate {
  readonly promise: Promise<void>;
  private resolvePromise: (() => void) | null = null;

  constructor() {
    this.promise = new Promise<void>((resolve: () => void) => {
      this.resolvePromise = resolve;
    });
  }

  open(): void {
    const resolve = this.resolvePromise;
    this.resolvePromise = null;
    if (resolve !== null) {
      resolve();
    }
  }
}

class CountingBus extends LinkedMessageBus {
  openedReaders: number = 0;
  readerCountAtInput: number = 0;
  readonly published: AgentMessage[] = [];
  readonly inputSeen: TestGate = new TestGate();
  input: AgentMessage | null = null;

  openReader(): AgentMessageReader {
    this.openedReaders++;
    return super.openReader();
  }

  publish(message: AgentMessage): void {
    this.published.push(message);
    if (message.type === AgentMessageType.INPUT_USER) {
      this.readerCountAtInput = this.openedReaders;
      this.input = message;
      this.inputSeen.open();
    }
    super.publish(message);
  }
}

class AnswerPlanner implements LeaderPlanner {
  lastInput: InputUserPayload | null = null;

  async plan(
    _message: AgentMessage,
    input: InputUserPayload,
    _context: LeaderPlanningContext,
    _round: number = 1
  ): Promise<LeaderDecision> {
    this.lastInput = input;
    return answerDecision(input.text === '查询天气' ? '我会保留上轮地点上下文。' : '你好');
  }
}

class HotelRoundPlanner implements LeaderPlanner {
  async plan(
    _message: AgentMessage,
    input: InputUserPayload,
    _context: LeaderPlanningContext,
    _round: number = 1
  ): Promise<LeaderDecision> {
    if (input.recentObservations !== undefined && input.recentObservations.length > 0) {
      return answerDecision('酒店结果已就绪', ['hotel.search']);
    }
    const task: LeaderDecisionDataTask = {
      localId: 'hotel-search',
      goal: 'Search real hotels',
      allowedToolIds: ['hotel.search'],
      toolId: 'hotel.search',
      input: JSON.parse(
        '{"city":"Shenzhen","checkIn":"2026-07-21","checkOut":"2026-07-22","guests":2}'
      ) as Object,
      required: true
    };
    return {
      personaId: 'travel_companion',
      skillId: '',
      requestedCapabilityIds: ['hotel.search'],
      roundAction: 'execute',
      dataTasks: [task],
      uiIntent: {
        purpose: 'hotel.search',
        preferredDensity: 'comfortable',
        requiredSections: ['hotels']
      },
      reasonCode: 'hotel_search'
    };
  }
}

class DataBackedActionPlanner implements LeaderPlanner {
  async plan(
    _message: AgentMessage,
    input: InputUserPayload,
    _context: LeaderPlanningContext,
    _round: number = 1
  ): Promise<LeaderDecision> {
    if (input.recentObservations !== undefined && input.recentObservations.length > 0) {
      return answerDecision('酒店结果和详情动作已就绪', ['hotel.search', 'hotel.detail']);
    }
    const decision = await new HotelRoundPlanner().plan(_message, input, _context, _round);
    decision.requestedCapabilityIds = ['hotel.search', 'hotel.detail'];
    decision.actionIntent = {
      goal: 'Open the selected real hotel detail',
      allowedActionIds: ['hotel.detail']
    };
    return decision;
  }
}

class TwoDataRoundPlanner implements LeaderPlanner {
  async plan(
    _message: AgentMessage,
    input: InputUserPayload,
    _context: LeaderPlanningContext,
    _round: number = 1
  ): Promise<LeaderDecision> {
    const observations = input.recentObservations === undefined ? [] : input.recentObservations;
    if (observations.length >= 2) {
      return answerDecision('两轮真实数据已就绪', ['hotel.search']);
    }
    if (observations.length === 1) {
      return {
        personaId: 'travel_companion', skillId: '',
        requestedCapabilityIds: ['maps.place.details'], roundAction: 'execute',
        dataTasks: [{
          localId: 'place-details', goal: 'Read the selected place',
          allowedToolIds: ['maps.place.details'], toolId: 'maps.place.details',
          input: JSON.parse('{"placeId":"hotel-101"}') as Object, required: true
        }],
        uiIntent: {
          purpose: 'combined results', preferredDensity: 'comfortable', requiredSections: ['hotel', 'place']
        },
        reasonCode: 'dependent_details'
      };
    }
    return {
      personaId: 'travel_companion', skillId: '',
      requestedCapabilityIds: ['maps.place.search'], roundAction: 'execute',
      dataTasks: [{
        localId: 'place-search', goal: 'Search real places',
        allowedToolIds: ['maps.place.search'], toolId: 'maps.place.search',
        input: JSON.parse('{"query":"Shenzhen hotel"}') as Object, required: true
      }],
      uiIntent: {
        purpose: 'combined results', preferredDensity: 'comfortable', requiredSections: ['place']
      },
      reasonCode: 'place_search'
    };
  }
}

class HangingPlanner implements LeaderPlanner {
  async plan(
    _message: AgentMessage,
    _input: InputUserPayload,
    _context: LeaderPlanningContext,
    _round: number = 1
  ): Promise<LeaderDecision> {
    return new Promise<LeaderDecision>((_resolve: (value: LeaderDecision) => void) => {
    });
  }
}

class SuccessDataExecutor implements DataTaskExecutor {
  calls: number = 0;

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls++;
    return {
      toolId: task.toolId,
      outputSchema: task.outputSchema,
      status: 'success',
      sources: [],
      data: JSON.parse('{"summary":"one hotel","entityRefs":["hotel-101"]}') as Object,
      warnings: []
    };
  }
}

class SimpleRenderer implements UiTaskRenderer {
  async skeleton(_task: CreateUiTaskPayload, _surfaceId: string): Promise<UiRenderResult> {
    return { jsonl: JSON.stringify('skeleton') };
  }

  async result(
    _task: CreateUiTaskPayload,
    _data: DataResult[],
    _offers: ActionOffer[],
    _surfaceId: string
  ): Promise<UiRenderResult> {
    return { jsonl: JSON.stringify('result') };
  }

  async error(
    _task: CreateUiTaskPayload,
    _message: string,
    _surfaceId: string
  ): Promise<UiRenderResult> {
    return { jsonl: JSON.stringify('error') };
  }

  async actionStatus(_payload: Object, _surfaceId: string): Promise<UiRenderResult> {
    return { jsonl: JSON.stringify('action') };
  }
}

class RecordingRenderer implements UiTaskRenderer {
  skeletonCalls: number = 0;
  resultCalls: number = 0;
  dataTaskIds: string[] = [];

  async skeleton(task: CreateUiTaskPayload, _surfaceId: string): Promise<UiRenderResult> {
    this.skeletonCalls++;
    this.dataTaskIds = task.dataTaskIds.slice();
    return { jsonl: JSON.stringify('skeleton') };
  }

  async result(
    _task: CreateUiTaskPayload,
    data: DataResult[],
    _offers: ActionOffer[],
    _surfaceId: string
  ): Promise<UiRenderResult> {
    this.resultCalls++;
    return { jsonl: JSON.stringify('result-' + data.length.toString()) };
  }

  async error(
    _task: CreateUiTaskPayload,
    _message: string,
    _surfaceId: string
  ): Promise<UiRenderResult> {
    return { jsonl: JSON.stringify('error') };
  }

  async actionStatus(_payload: Object, _surfaceId: string): Promise<UiRenderResult> {
    return { jsonl: JSON.stringify('action') };
  }
}

class RecordingWriter implements UiSurfaceWriter {
  writes: string[] = [];
  surfaces: string[] = [];

  async write(
    _turnId: string,
    surfaceId: string,
    jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void> {
    if (!lease.isActive()) {
      return;
    }
    this.writes.push(jsonl);
    this.surfaces.push(surfaceId);
  }
}

class ControlledWriter implements UiSurfaceWriter {
  readonly resultStarted: TestGate = new TestGate();
  private readonly releaseResult: TestGate = new TestGate();
  blockResult: boolean = false;
  resultSurfaceId: string = '';

  async write(
    _turnId: string,
    surfaceId: string,
    jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void> {
    if (this.blockResult && jsonl.indexOf('result') >= 0) {
      this.resultStarted.open();
      await this.releaseResult.promise;
    }
    if (!lease.isActive()) {
      return;
    }
    if (jsonl.indexOf('result') >= 0) {
      this.resultSurfaceId = surfaceId;
    }
  }

  release(): void {
    this.releaseResult.open();
  }
}

class TestLookup implements ToolDefinitionLookup {
  find(toolId: string): ToolDefinition | null {
    if (toolId === 'memory.update') {
      return {
        toolId,
        domain: 'memory',
        intent: toolId,
        riskLevel: 'draft',
        backendPriority: ['local_adapter'],
        authModes: ['none'],
        inputSchema: 'memoryUpdateRequest',
        outputSchema: 'memoryUpdateResult',
        a2uiComponent: 'MemoryUpdate',
        actions: ['memory.update']
      };
    }
    if (toolId === 'hotel.detail') {
      return {
        toolId,
        domain: 'hotel',
        intent: toolId,
        riskLevel: 'read',
        backendPriority: ['local_adapter'],
        authModes: ['none'],
        inputSchema: 'hotelDetailRequest',
        outputSchema: 'hotelRatePlans',
        a2uiComponent: 'HotelDetails',
        actions: []
      };
    }
    if (toolId !== 'hotel.search') {
      return null;
    }
    return {
      toolId,
      domain: 'hotel',
      intent: toolId,
      riskLevel: 'read',
      backendPriority: ['local_adapter'],
      authModes: ['none'],
      inputSchema: 'hotelSearchRequest',
      outputSchema: 'hotelSearchResults',
      a2uiComponent: 'HotelResults',
      actions: ['hotel.detail']
    };
  }
}

class AllowSurface implements SurfaceActionAuthorizer {
  allows(
    _conversationId: string,
    _turnId: string,
    _surfaceId: string,
    _actionId: string,
    _args: Object
  ): boolean {
    return true;
  }
}

class RejectClient implements ClientActionAuthorizer {
  allows(_actionId: string, _args: Object): boolean {
    return false;
  }
}

class AllowArgs implements ActionArgsValidator {
  validate(_actionId: string, _args: Object): ActionValidationResult {
    return { ok: true, code: '', message: '' };
  }
}

class NoopRegisteredExecutor implements RegisteredActionExecutor {
  async execute(
    _actionId: string,
    _args: Object,
    _context: ActionExecutionContext
  ): Promise<ActionExecutionResult> {
    return { status: 'success', output: new Object() };
  }
}

class RecordingActionCompiler implements ActionPlanCompiler {
  offers: ActionOffer[] = [];
  allowedActionIds: string[] = [];

  async compile(
    _goal: string,
    offers: ActionOffer[],
    allowedActionIds: string[]
  ): Promise<ActionPlanDraft> {
    this.offers = offers.slice();
    this.allowedActionIds = allowedActionIds.slice();
    const offer: ActionOffer = offers[0];
    return {
      planId: 'plan-hotel-detail',
      runId: 'run-hotel-detail',
      label: '查看酒店详情',
      steps: [{
        stepId: 'step-1',
        actionId: offer.actionId,
        args: offer.args
      }]
    };
  }
}

class VirtualMemoryPlanner implements LeaderPlanner {
  async plan(
    _message: AgentMessage,
    _input: InputUserPayload,
    _context: LeaderPlanningContext,
    _round: number = 1
  ): Promise<LeaderDecision> {
    return {
      personaId: 'travel_companion',
      skillId: '',
      requestedCapabilityIds: ['memory.update'],
      roundAction: 'execute',
      dataTasks: [],
      uiIntent: {
        purpose: 'memory.update',
        preferredDensity: 'comfortable',
        requiredSections: []
      },
      actionIntent: {
        goal: 'Remember an explicit preference',
        allowedActionIds: ['memory.update']
      },
      reasonCode: 'stable_preference'
    };
  }
}

class StaticVirtualResolver implements VirtualActionIntentResolver {
  async resolve(_request: ActionPlanRequestPayload): Promise<VirtualActionIntent | null> {
    return {
      sourceToolId: 'memory.update',
      offer: {
        offerId: 'memory-offer',
        actionId: 'memory.update',
        label: 'Remember',
        variant: 'primary',
        args: JSON.parse('{"value":"remember me"}') as Object
      },
      autoRun: true
    };
  }
}

class BlockingVirtualExecutor implements RegisteredActionExecutor {
  readonly started: TestGate = new TestGate();
  readonly release: TestGate = new TestGate();

  async execute(
    _actionId: string,
    _args: Object,
    _context: ActionExecutionContext
  ): Promise<ActionExecutionResult> {
    this.started.open();
    await this.release.promise;
    return { status: 'success', output: new Object() };
  }
}

function answerDecision(answer: string, requestedCapabilityIds: string[] = []): LeaderDecision {
  return {
    personaId: 'travel_companion',
    skillId: '',
    requestedCapabilityIds: requestedCapabilityIds.slice(),
    roundAction: 'answer',
    dataTasks: [],
    uiIntent: {
      purpose: 'conversation',
      preferredDensity: 'comfortable',
      requiredSections: []
    },
    answer,
    reasonCode: 'answer'
  };
}

function planningContext(): LeaderPlanningContext {
  return {
    tools: [
      {
        toolId: 'hotel.search',
        domain: 'hotel',
        intent: 'hotel.search',
        riskLevel: 'read',
        registeredBackends: ['mcp_remote'],
        inputSchema: 'hotelSearchRequest',
        outputSchema: 'hotelSearchResults',
        actions: ['legacy.action', 'hotel.detail']
      },
      {
        toolId: 'hotel.detail',
        domain: 'hotel',
        intent: 'hotel.detail',
        riskLevel: 'read',
        registeredBackends: ['local_adapter'],
        inputSchema: 'hotelDetailRequest',
        outputSchema: 'hotelRatePlans',
        actions: []
      },
      {
        toolId: 'legacy.action',
        domain: 'legacy',
        intent: 'legacy.action',
        riskLevel: 'draft',
        registeredBackends: ['local_adapter'],
        inputSchema: 'legacyActionRequest',
        outputSchema: 'legacyActionResult',
        actions: []
      },
      {
        toolId: 'maps.place.search',
        domain: 'maps',
        intent: 'maps.place.search',
        riskLevel: 'read',
        registeredBackends: ['oauth_api'],
        inputSchema: 'mapsPlaceSearchQuery',
        outputSchema: 'places',
        actions: []
      },
      {
        toolId: 'maps.place.details',
        domain: 'maps',
        intent: 'maps.place.details',
        riskLevel: 'read',
        registeredBackends: ['oauth_api'],
        inputSchema: 'mapsPlaceDetailsQuery',
        outputSchema: 'place',
        actions: []
      },
      {
        toolId: 'memory.update',
        domain: 'persona',
        intent: 'memory.update',
        riskLevel: 'draft',
        registeredBackends: ['local_adapter'],
        inputSchema: 'memoryUpdateRequest',
        outputSchema: 'memoryUpdateResult',
        actions: ['memory.update']
      },
      {
        toolId: 'dynamic.search',
        domain: 'dynamic',
        intent: 'dynamic.search',
        riskLevel: 'read',
        registeredBackends: ['mcp_remote', 'oauth_api'],
        inputSchema: 'dynamicToolSearchQuery',
        outputSchema: 'dynamicToolConnect',
        actions: []
      },
      {
        toolId: 'unknown.search',
        domain: 'unknown',
        intent: 'unknown.search',
        riskLevel: 'read',
        registeredBackends: [],
        inputSchema: 'unknownSearchQuery',
        outputSchema: 'unknownSearchResults',
        actions: []
      }
    ],
    personas: [{
      personaId: 'travel_companion',
      name: 'Travel Companion',
      soul: 'Use real data.',
      memory: '常用出发地：北京。',
      previous: true,
      activeSkills: []
    }]
  };
}

async function noOffers(
  _data: DataResult,
  _context: ActionOfferContext
): Promise<ActionOffer[]> {
  return [];
}

async function realHotelDetailOffer(
  data: DataResult,
  _context: ActionOfferContext
): Promise<ActionOffer[]> {
  const record = data.data as Record<string, Object | string[] | undefined>;
  const refs = record['entityRefs'];
  if (!Array.isArray(refs) || refs.length === 0 || refs[0] !== 'hotel-101') {
    return [];
  }
  return [{
    offerId: 'offer-hotel-detail',
    actionId: 'hotel.detail',
    label: '查看酒店详情',
    variant: 'primary',
    args: JSON.parse('{"hotelId":"hotel-101"}') as Object
  }];
}

function authorize(_task: CreateDataTaskPayload): DataTaskAuthorizationResult {
  return { ok: true, code: '', message: '' };
}

function runtimeOptions(
  bus: CountingBus,
  planner: LeaderPlanner,
  writer: ControlledWriter,
  timeoutMs: number = 200
): MultiAgentRuntimeOptions {
  return {
    bus,
    conversationId: 'conversation-runtime',
    planner,
    planningContext: planningContext(),
    dataAuthorizer: authorize,
    dataExecutor: new SuccessDataExecutor(),
    uiRenderer: new SimpleRenderer(),
    surfaceWriter: writer,
    actionCatalog: new ActionCatalog(
      new TestLookup(),
      new AllowSurface(),
      new RejectClient(),
      new AllowArgs()
    ),
    actionOfferResolver: noOffers,
    actionExecutor: new NoopRegisteredExecutor(),
    submitTimeoutMs: timeoutMs,
    actionTimeoutMs: timeoutMs,
    settingsFingerprint: 'runtime-settings-v1'
  };
}

async function settle(): Promise<void> {
  for (let index = 0; index < 16; index++) {
    await Promise.resolve();
  }
}

function latestInput(bus: CountingBus): AgentMessage {
  const inputs: AgentMessage[] = bus.published.filter((message: AgentMessage): boolean =>
    message.type === AgentMessageType.INPUT_USER
  );
  return inputs[inputs.length - 1];
}

function publishUiTask(bus: CountingBus, input: AgentMessage, taskId: string): void {
  const payload: CreateUiTaskPayload = {
    taskId,
    dataTaskIds: [taskId + ':data'],
    skillId: '',
    intent: 'manual UI correlation',
    expectedOutputSchema: 'hotelSearchResults'
  };
  bus.publish({
    type: AgentMessageType.TASK_CREATE_UI,
    conversationId: input.conversationId,
    turnId: input.turnId,
    taskId,
    payload
  });
}

function publishUiTerminal(
  bus: CountingBus,
  input: AgentMessage,
  taskId: string,
  surfaceId: string,
  state: 'result' | 'error'
): void {
  const payload: UiRenderResultPayload = { surfaceId, state };
  bus.publish({
    type: AgentMessageType.TASK_RESULT_UI,
    conversationId: input.conversationId,
    turnId: input.turnId,
    taskId,
    payload
  });
}

function publishTurnTerminal(
  bus: CountingBus,
  input: AgentMessage,
  status: 'success' | 'error',
  message: string,
  surfaceId: string = ''
): void {
  const payload: TurnResultPayload = { status, roundCount: 2, message };
  if (surfaceId.length > 0) {
    payload.surfaceId = surfaceId;
  }
  bus.publish({
    type: AgentMessageType.TURN_RESULT,
    conversationId: input.conversationId,
    turnId: input.turnId,
    taskId: input.taskId,
    payload
  });
}

export default function multiAgentRuntimeTest() {
  describe('multiAgentRuntime', () => {
    it('uses stable privacy tokens for the actual C19 click identity and rejects invalid action surfaces', 0, () => {
      const formatter = new MultiAgentEvidenceFormatter(32);
      const payload: ActionRunPayload = {
        actionId: 'calendar.event.create', sourceToolId: 'calendar.events.search',
        args: JSON.parse('{"title":"Appless QA"}') as Object, runId: 'run-1', surfaceId: 'calendar-review:1'
      };
      const message: AgentMessage = {
        type: AgentMessageType.ACTION_RUN,
        conversationId: 'conversation-raw-1', turnId: 'page-turn-raw-7', taskId: 'action-1',
        payload
      };
      const valid = formatter.line(message);
      const invalidPayload: ActionRunPayload = {
        actionId: 'calendar.event.create', sourceToolId: 'calendar.events.search',
        args: JSON.parse('{"title":"Appless QA"}') as Object, runId: 'run-1', surfaceId: 'invalid'
      };
      const invalidMessage: AgentMessage = {
        type: AgentMessageType.ACTION_RUN,
        conversationId: 'conversation-raw-1', turnId: 'page-turn-raw-7', taskId: 'action-1',
        payload: invalidPayload
      };
      const invalid = formatter.line(invalidMessage);

      expect(valid.indexOf('conversation=c6444c223')).assertLarger(-1);
      expect(valid.indexOf('turn=t2442801d')).assertLarger(-1);
      expect(valid.indexOf('conversation-raw-1')).assertEqual(-1);
      expect(invalid.indexOf('surface=invalid')).assertLarger(-1);
    });

    it('formats a virtual client Action terminal with its returned current surface', 0, () => {
      const formatter = new MultiAgentEvidenceFormatter(32);
      const payload: ActionResultPayload = {
        surfaceId: 'virtual:input-1:round-1:virtual',
        planId: 'direct:virtual:input-1:round-1:virtual',
        runId: 'virtual:input-1:round-1:virtual',
        status: 'success',
        completedStepIds: ['step-1'],
        outputs: [{
          stepId: 'step-1',
          output: JSON.parse('{"surfaceId":"surface_seed"}') as Object
        }]
      };
      const line = formatter.line({
        type: AgentMessageType.ACTION_RESULT,
        conversationId: 'conversation-virtual', turnId: 'turn-virtual', taskId: 'virtual-task', payload
      });

      expect(line.indexOf('surface=surface_seed')).assertLarger(-1);
      expect(line.indexOf('surface=invalid')).assertEqual(-1);
    });

    it('formats bounded opaque lifecycle evidence without raw identities or values', 0, () => {
      const formatter = new MultiAgentEvidenceFormatter(32);
      const inputPayload: InputUserPayload = {
        text: 'secret prompt and recipient@example.com'
      };
      const inputMessage: AgentMessage = {
        type: AgentMessageType.INPUT_USER,
        conversationId: 'conversation-1',
        turnId: 'turn-1',
        taskId: 'input-1',
        payload: inputPayload
      };
      const firstDataPayload: CreateDataTaskPayload = {
        taskId: 'search-private',
        roundId: 'turn-1:round-1',
        skillId: '',
        goal: 'must not log',
        allowedToolIds: ['maps.place.search'],
        toolId: 'maps.place.search',
        outputSchema: 'places',
        args: JSON.parse('{"query":"private query"}') as Object,
        required: true
      };
      const firstDataMessage: AgentMessage = {
        type: AgentMessageType.TASK_CREATE_DATA,
        conversationId: 'conversation-1',
        turnId: 'turn-1',
        taskId: 'search-private',
        payload: firstDataPayload
      };
      const firstResult: DataResult = {
        toolId: 'maps.place.search',
        outputSchema: 'places',
        status: 'success',
        sources: [],
        data: JSON.parse('{"places":[{"placeId":"private-place-id"}]}') as Object,
        warnings: []
      };
      const firstResultMessage: AgentMessage = {
        type: AgentMessageType.TASK_RESULT_DATA,
        conversationId: 'conversation-1',
        turnId: 'turn-1',
        taskId: 'search-private',
        payload: firstResult
      };
      const dataPayload: CreateDataTaskPayload = {
        taskId: 'data-1',
        roundId: 'turn-1:round-2',
        skillId: '',
        goal: 'must not log',
        allowedToolIds: ['maps.place.details'],
        toolId: 'maps.place.details',
        outputSchema: 'place',
        args: JSON.parse('{"placeId":"private-place-id"}') as Object,
        required: true
      };
      const dataMessage: AgentMessage = {
        type: AgentMessageType.TASK_CREATE_DATA,
        conversationId: 'conversation-1',
        turnId: 'turn-1',
        taskId: 'data-1',
        payload: dataPayload
      };
      const turnPayload: TurnResultPayload = {
        status: 'partial',
        surfaceId: 'loop_surface_1784700000000_2',
        roundCount: 2,
        message: 'provider message must not log'
      };
      const uiPayload: UiRenderResultPayload = {
        surfaceId: 'loop_surface_1784700000000_2',
        state: 'result'
      };
      const uiMessage: AgentMessage = {
        type: AgentMessageType.TASK_RESULT_UI,
        conversationId: 'conversation-1',
        turnId: 'turn-1',
        taskId: 'input-1',
        payload: uiPayload
      };
      const turnMessage: AgentMessage = {
        type: AgentMessageType.TURN_RESULT,
        conversationId: 'conversation-1',
        turnId: 'turn-1',
        taskId: 'input-1',
        payload: turnPayload
      };
      const inputLine = formatter.line(inputMessage);
      const firstDataLine = formatter.line(firstDataMessage);
      const firstResultLine = formatter.line(firstResultMessage);
      const dataLine = formatter.line(dataMessage);
      const uiLine = formatter.line(uiMessage);
      const turnLine = formatter.line(turnMessage);

      expect(inputLine).assertEqual(
        '[AIPhone][MultiAgentInput] conversation=caf571c80 turn=t18046e8c task=k1'
      );
      expect(firstDataLine).assertEqual(
        '[AIPhone][MultiAgentDataTask] conversation=caf571c80 turn=t18046e8c task=k2 ' +
          'round=1 tool=maps.place.search predecessor=none path=none target=none binding=false'
      );
      expect(firstResultLine).assertEqual(
        '[AIPhone][MultiAgentDataResult] conversation=caf571c80 turn=t18046e8c task=k2 ' +
          'tool=maps.place.search status=success sources=0 error=false'
      );
      expect(dataLine).assertEqual(
        '[AIPhone][MultiAgentDataTask] conversation=caf571c80 turn=t18046e8c task=k3 ' +
          'round=2 tool=maps.place.details predecessor=k2 ' +
          'path=/places/0/placeId target=/placeId binding=true'
      );
      expect(uiLine).assertEqual(
        '[AIPhone][MultiAgentUiResult] conversation=caf571c80 turn=t18046e8c task=k1 ' +
          'surface=loop_surface_1784700000000_2 state=result'
      );
      expect(turnLine).assertEqual(
        '[AIPhone][MultiAgentTurnResult] conversation=caf571c80 turn=t18046e8c task=k1 ' +
          'status=partial surface=loop_surface_1784700000000_2 roundCount=2 messageChars=29'
      );
      expect(inputLine.indexOf('secret')).assertEqual(-1);
      expect(inputLine.indexOf('conversation-1')).assertEqual(-1);
      expect(inputLine.indexOf('turn-1')).assertEqual(-1);
      expect(inputLine.indexOf('input-1')).assertEqual(-1);
      expect(dataLine.indexOf('private-place-id')).assertEqual(-1);
      expect(turnLine.indexOf('provider message')).assertEqual(-1);
      expect(inputLine.indexOf('\n')).assertEqual(-1);
      expect(dataLine.length < 320).assertTrue();

      const noProvenance = new MultiAgentEvidenceFormatter(32);
      noProvenance.line(inputMessage);
      noProvenance.line(firstDataMessage);
      const unbound: string = noProvenance.line(dataMessage);
      expect(unbound.indexOf('predecessor=none path=none target=none binding=false')).assertLarger(-1);
    });

    it('formats correlated dynamic discovery only from registration and matching provider source facts', 0, () => {
      const formatter = new MultiAgentEvidenceFormatter(32);
      const result: DataResult = {
        toolId: 'dynamic.search',
        outputSchema: 'dynamicToolConnect',
        status: 'empty',
        sources: [{
          provider: 'Composio',
          backend: 'oauth_api',
          operation: 'GOOGLEDOCS_SEARCH_DOCUMENTS',
          fetchedAt: '2026-07-23T00:00:00Z'
        }],
        data: JSON.parse(
          '{"results":[],"registration":{"provider":"Composio",' +
          '"qualifiedName":"GOOGLEDOCS_SEARCH_DOCUMENTS","inputSchema":{},' +
          '"outputSchema":{},"receipt":""}}'
        ) as Object,
        warnings: []
      };
      const message: AgentMessage = {
        type: AgentMessageType.TASK_RESULT_DATA,
        conversationId: 'conversation-dynamic',
        turnId: 'turn-dynamic',
        taskId: 'data-dynamic',
        payload: result
      };

      const line = formatter.dynamicDiscoveryLine(message);
      expect(line.indexOf('[AIPhone][DynamicToolDiscovery]')).assertEqual(0);
      expect(line.indexOf('selectedToolId=dynamic.search')).assertLarger(-1);
      expect(line.indexOf('provider=composio')).assertLarger(-1);
      expect(line.indexOf('qualifiedName=googledocs_search_documents')).assertLarger(-1);
      expect(line.indexOf('status=empty source=true auth=false receipt=absent')).assertLarger(-1);
      expect(line.indexOf('GOOGLEDOCS_SEARCH_DOCUMENTS')).assertEqual(-1);

      result.sources[0].operation = 'WRONG_TOOL';
      expect(formatter.dynamicDiscoveryLine(message).indexOf('source=false')).assertLarger(-1);
      result.sources[0].operation = 'GOOGLEDOCS_SEARCH_DOCUMENTS';
      result.sources[0].receipt = 'different-receipt';
      const registration = (result.data as Record<string, Object>)['registration'] as
        Record<string, Object | string>;
      registration['receipt'] = 'provider-receipt';
      expect(formatter.dynamicDiscoveryLine(message).indexOf('receipt=mismatch')).assertLarger(-1);
      result.sources[0].receipt = 'provider-receipt';
      expect(formatter.dynamicDiscoveryLine(message).indexOf('receipt=matched')).assertLarger(-1);

      const results = (result.data as Record<string, Object>)['results'] as Object[];
      results.push(JSON.parse('{"status":"needs_auth"}') as Object);
      expect(formatter.dynamicDiscoveryLine(message).indexOf('auth=true')).assertLarger(-1);
    });

    it('rejects unsafe registry ids and bounds then disposes opaque correlations', 0, () => {
      const formatter = new MultiAgentEvidenceFormatter(8);
      const payload: InputUserPayload = { text: 'not logged' };
      const longIdentity: string = 'local@example.com\n+8613800138000-' + 'x'.repeat(400);
      const input: AgentMessage = {
        type: AgentMessageType.INPUT_USER,
        conversationId: longIdentity,
        turnId: longIdentity,
        taskId: longIdentity,
        payload
      };
      const first: string = formatter.line(input);
      expect(first.indexOf('local@example.com')).assertEqual(-1);
      expect(first.indexOf('+8613800138000')).assertEqual(-1);
      expect(first.indexOf('\n')).assertEqual(-1);

      const unsafeTaskPayload: CreateDataTaskPayload = {
        taskId: longIdentity,
        roundId: longIdentity + ':round-1',
        skillId: '',
        goal: '',
        allowedToolIds: ['alice@example.com'],
        toolId: 'alice@example.com',
        outputSchema: '',
        args: new Object(),
        required: true
      };
      const unsafeTask: AgentMessage = {
        type: AgentMessageType.TASK_CREATE_DATA,
        conversationId: longIdentity,
        turnId: longIdentity,
        taskId: longIdentity,
        payload: unsafeTaskPayload
      };
      expect(formatter.line(unsafeTask).indexOf('tool=invalid')).assertLarger(-1);
      expect(formatter.line(unsafeTask).indexOf('alice@example.com')).assertEqual(-1);

      const terminalPayload: TurnResultPayload = {
        status: 'success',
        surfaceId: longIdentity,
        roundCount: 1,
        message: 'done'
      };
      const terminal: AgentMessage = {
        type: AgentMessageType.TURN_RESULT,
        conversationId: longIdentity,
        turnId: longIdentity,
        taskId: longIdentity,
        payload: terminalPayload
      };
      const invalidSurface: string = formatter.line(terminal);
      expect(invalidSurface.indexOf('surface=invalid')).assertLarger(-1);
      expect(invalidSurface.indexOf('local@example.com')).assertEqual(-1);
      expect(invalidSurface.indexOf('\n')).assertEqual(-1);
      formatter.dispose();
      const afterTerminal: string = formatter.line(input);
      expect(afterTerminal).assertEqual(first);
    });

    it('opens exactly four Agent readers and one observer before bounded INPUT.USER', 0, async () => {
      const bus = new CountingBus();
      const planner = new AnswerPlanner();
      const runtime = new MultiAgentRuntime(runtimeOptions(bus, planner, new ControlledWriter()));
      const recentMessages: ConversationTurnMessage[] = [];
      for (let index = 0; index < 10; index++) {
        recentMessages.push({
          role: index % 2 === 0 ? 'user' : 'assistant',
          content: 'message-' + index.toString()
        });
      }

      const raw = await runtime.submit('查询天气', {
        text: 'must-be-replaced',
        recentMessages,
        previousPersonaId: 'travel_companion',
        currentSurfaceSummary: {
          surfaceId: 'surface-previous',
          kind: 'weather',
          status: 'result',
          entityRefs: ['北京'],
          actionOfferIds: []
        },
        recentObservations: []
      });
      const result = raw as MultiAgentSettledOutcome;

      expect(bus.openedReaders).assertEqual(5);
      expect(bus.readerCountAtInput).assertEqual(5);
      expect(result.kind).assertEqual('settled');
      expect(result.status).assertEqual('success');
      expect(result.message).assertEqual('我会保留上轮地点上下文。');
      expect(result.surfaceId).assertEqual('');
      const input = planner.lastInput as InputUserPayload;
      expect(input.text).assertEqual('查询天气');
      expect(input.recentMessages!.length).assertEqual(8);
      expect(input.recentMessages![0].content).assertEqual('message-2');
      expect(input.previousPersonaId).assertEqual('travel_companion');
      expect(input.currentSurfaceSummary!.surfaceId).assertEqual('surface-previous');
      runtime.dispose();
    });

    it('waits for the exact final UI result after Leader TURN.RESULT', 0, async () => {
      const bus = new CountingBus();
      const writer = new ControlledWriter();
      writer.blockResult = true;
      const runtime = new MultiAgentRuntime(runtimeOptions(bus, new HotelRoundPlanner(), writer));
      let resolved = false;
      const pending = runtime.submit('帮我找深圳酒店', { text: '' });
      pending.then(() => {
        resolved = true;
      });

      await writer.resultStarted.promise;
      await settle();
      expect(resolved).assertFalse();
      writer.release();
      const result = await pending as MultiAgentSettledOutcome;

      expect(result.kind).assertEqual('settled');
      expect(result.status).assertEqual('success');
      expect(result.message).assertEqual('酒店结果已就绪');
      expect(writer.resultSurfaceId.length > 0).assertTrue();
      expect(result.surfaceId).assertEqual(writer.resultSurfaceId);
      runtime.dispose();
    });

    it('completes final UI after the old proportional deadline but before the configured deadline', 1000, async () => {
      const oldProportionalDeadlineMs: number = 80;
      const configuredDeadlineMs: number = 120;
      const bus = new CountingBus();
      const writer = new ControlledWriter();
      writer.blockResult = true;
      const runtime = new MultiAgentRuntime(runtimeOptions(
        bus,
        new HotelRoundPlanner(),
        writer,
        configuredDeadlineMs
      ));
      let resolved: boolean = false;
      const pending = runtime.submit('bounded delayed UI', { text: '' });
      pending.then((): void => {
        resolved = true;
      });

      await writer.resultStarted.promise;
      await new Promise<void>((resolve: () => void) =>
        setTimeout(resolve, oldProportionalDeadlineMs + 5));
      expect(resolved).assertFalse();
      writer.release();
      const result = await pending as MultiAgentSettledOutcome;
      const correlated = bus.published.filter((message: AgentMessage): boolean =>
        message.turnId === (bus.input as AgentMessage).turnId
      );

      expect(result.status).assertEqual('success');
      expect(result.surfaceId).assertEqual(writer.resultSurfaceId);
      expect(correlated.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_DATA
      ).length).assertEqual(1);
      expect(correlated.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_UI
      ).length).assertEqual(1);
      expect(correlated.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TURN_CANCEL
      ).length).assertEqual(0);
      expect(correlated.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TURN_RESULT
      ).length).assertEqual(1);
      runtime.dispose();
    });

    it('renders two dependent Data rounds with one skeleton one final surface and one TurnResult', 0, async () => {
      const bus = new CountingBus();
      const renderer = new RecordingRenderer();
      const writer = new RecordingWriter();
      const options = runtimeOptions(bus, new TwoDataRoundPlanner(), new ControlledWriter());
      options.uiRenderer = renderer;
      options.surfaceWriter = writer;
      const runtime = new MultiAgentRuntime(options);

      const outcome = await runtime.submit('search then details', { text: '' }) as MultiAgentSettledOutcome;
      const uiTasks = bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_UI
      );
      const dataTasks = bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_DATA
      );
      const terminals = bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TURN_RESULT
      );

      expect(outcome.status).assertEqual('success');
      expect(dataTasks.length).assertEqual(2);
      expect(uiTasks.length).assertEqual(1);
      expect(terminals.length).assertEqual(1);
      const searchPayload = dataTasks[0].payload as CreateDataTaskPayload;
      const detailsPayload = dataTasks[1].payload as CreateDataTaskPayload;
      expect(searchPayload.toolId).assertEqual('maps.place.search');
      expect(searchPayload.roundId.endsWith(':round-1')).assertTrue();
      expect(detailsPayload.toolId).assertEqual('maps.place.details');
      expect(detailsPayload.roundId.endsWith(':round-2')).assertTrue();
      expect((detailsPayload.args as Record<string, string>)['placeId']).assertEqual('hotel-101');
      expect(renderer.skeletonCalls).assertEqual(1);
      expect(renderer.resultCalls).assertEqual(1);
      expect(renderer.dataTaskIds.join(',')).assertEqual(dataTasks[0].taskId + ',' + dataTasks[1].taskId);
      expect(writer.writes.length).assertEqual(2);
      expect(writer.surfaces[0]).assertEqual(writer.surfaces[1]);
      expect(outcome.surfaceId).assertEqual(writer.surfaces[1]);
      runtime.dispose();
    });

    it('binds a Data-backed actionIntent to the one final UI and real current offer', 0, async () => {
      const bus = new CountingBus();
      const compiler = new RecordingActionCompiler();
      const options = runtimeOptions(
        bus,
        new DataBackedActionPlanner(),
        new ControlledWriter()
      );
      options.actionOfferResolver = realHotelDetailOffer;
      options.actionCompiler = compiler;
      const runtime = new MultiAgentRuntime(options);

      const outcome = await runtime.submit('search hotel and offer detail', { text: '' }) as
        MultiAgentSettledOutcome;
      await settle();
      const dataTasks = bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_DATA
      );
      const uiTasks = bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_UI
      );
      const requests = bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.ACTION_PLAN_REQUEST
      );
      const readyMessages = bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.ACTION_PLAN_READY
      );
      const request = requests[0].payload as ActionPlanRequestPayload;
      const ready = readyMessages[0].payload as ActionPlanReadyPayload;

      expect(outcome.status).assertEqual('success');
      expect(dataTasks.length).assertEqual(1);
      expect(uiTasks.length).assertEqual(1);
      expect(requests.length).assertEqual(1);
      expect(readyMessages.length).assertEqual(1);
      expect(request.uiTaskId).assertEqual(uiTasks[0].taskId);
      expect(request.dataTaskIds.join(',')).assertEqual(dataTasks[0].taskId);
      expect(compiler.allowedActionIds.join(',')).assertEqual('hotel.detail');
      expect(compiler.offers.length).assertEqual(1);
      expect(compiler.offers[0].offerId).assertEqual('offer-hotel-detail');
      expect((compiler.offers[0].args as Record<string, string>)['hotelId']).assertEqual('hotel-101');
      expect(ready.uiTaskId).assertEqual(uiTasks[0].taskId);
      expect(ready.surfaceId).assertEqual(outcome.surfaceId);
      runtime.dispose();
    });

    it('settles an exact UI error with one Leader-owned terminal', 0, async () => {
      const bus = new CountingBus();
      const runtime = new MultiAgentRuntime(runtimeOptions(
        bus,
        new HangingPlanner(),
        new ControlledWriter(),
        1000
      ));
      let resolved: boolean = false;
      const pending = runtime.submit('manual UI error', { text: '' });
      pending.then((): void => {
        resolved = true;
      });
      await bus.inputSeen.promise;
      const input: AgentMessage = latestInput(bus);
      publishUiTask(bus, input, 'manual-ui');
      publishUiTerminal(bus, input, 'manual-ui', 'surface-error', 'error');
      await settle();

      expect(resolved).assertFalse();
      publishTurnTerminal(bus, input, 'error', 'UI rendering failed', 'surface-error');
      const result = await pending as MultiAgentSettledOutcome;
      const correlated: AgentMessage[] = bus.published.filter((message: AgentMessage): boolean =>
        message.turnId === input.turnId &&
          (message.type === AgentMessageType.TURN_CANCEL ||
            message.type === AgentMessageType.TURN_RESULT)
      );
      const terminals: AgentMessage[] = correlated.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TURN_RESULT
      );
      const cancels: AgentMessage[] = correlated.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TURN_CANCEL
      );

      expect(result.status).assertEqual('error');
      expect(result.surfaceId).assertEqual('surface-error');
      expect(terminals.length).assertEqual(1);
      expect((terminals[0].payload as TurnResultPayload).status).assertEqual('error');
      expect((terminals[0].payload as TurnResultPayload).surfaceId).assertEqual('surface-error');
      expect(cancels.length).assertEqual(0);
      runtime.dispose();
    });

    it('cancels an old UI-error turn before a new surface and rejects its late replan', 0, async () => {
      const bus = new CountingBus();
      const activated: string[] = [];
      const options = runtimeOptions(bus, new HangingPlanner(), new ControlledWriter(), 1000);
      options.surfaceTurnActivator = (turnId: string): void => {
        activated.push(turnId);
      };
      const runtime = new MultiAgentRuntime(options);
      const oldPending = runtime.submit('old turn', { text: '' });
      await bus.inputSeen.promise;
      const oldInput: AgentMessage = latestInput(bus);
      publishUiTask(bus, oldInput, 'old-ui');
      publishUiTerminal(bus, oldInput, 'old-ui', 'surface-old-error', 'error');
      await settle();

      const newPending = runtime.submit('new turn', { text: '' });
      const old = await oldPending as MultiAgentSettledOutcome;
      await settle();
      const newInput: AgentMessage = latestInput(bus);
      publishUiTask(bus, newInput, 'new-ui');
      publishTurnTerminal(bus, newInput, 'success', 'new ready');
      publishUiTerminal(bus, newInput, 'new-ui', 'surface-new', 'result');
      const current = await newPending as MultiAgentSettledOutcome;

      publishUiTask(bus, oldInput, 'old-late-ui');
      publishUiTerminal(bus, oldInput, 'old-late-ui', 'surface-old-late', 'result');
      publishTurnTerminal(bus, oldInput, 'success', 'old late replan');
      await settle();

      expect(old.status).assertEqual('canceled');
      expect(current.status).assertEqual('success');
      expect(current.surfaceId).assertEqual('surface-new');
      expect(activated[activated.length - 1]).assertEqual(newInput.turnId);
      expect(activated.filter((turnId: string): boolean => turnId === oldInput.turnId).length).assertEqual(1);
      runtime.dispose();
    });

    it('publishes TURN.CANCEL before a host-forced task-error terminal', 0, async () => {
      const bus = new CountingBus();
      const runtime = new MultiAgentRuntime(runtimeOptions(
        bus,
        new HangingPlanner(),
        new ControlledWriter(),
        1000
      ));
      const pending = runtime.submit('forced error', { text: '' });
      await bus.inputSeen.promise;
      const input: AgentMessage = latestInput(bus);
      const error: TaskErrorPayload = { code: 'FORCED', message: 'forced failure' };
      bus.publish({
        type: AgentMessageType.TASK_ERROR,
        conversationId: input.conversationId,
        turnId: input.turnId,
        taskId: input.taskId,
        payload: error
      });
      const result = await pending as MultiAgentSettledOutcome;
      const correlated: AgentMessage[] = bus.published.filter((message: AgentMessage): boolean =>
        message.turnId === input.turnId &&
          (message.type === AgentMessageType.TURN_CANCEL ||
            message.type === AgentMessageType.TURN_RESULT)
      );

      expect(result.status).assertEqual('error');
      expect(correlated[0].type).assertEqual(AgentMessageType.TURN_CANCEL);
      expect(correlated[1].type).assertEqual(AgentMessageType.TURN_RESULT);
      runtime.dispose();
    });

    it('rejects exact-task virtual results with forged surface, plan, or run identity', 0, async () => {
      const bus = new CountingBus();
      const executor = new BlockingVirtualExecutor();
      const options = runtimeOptions(
        bus,
        new VirtualMemoryPlanner(),
        new ControlledWriter(),
        1000
      );
      options.virtualActionResolver = new StaticVirtualResolver();
      options.actionExecutor = executor;
      const runtime = new MultiAgentRuntime(options);
      let resolved: boolean = false;
      const pending = runtime.submit('remember me', { text: '' });
      pending.then((): void => {
        resolved = true;
      });
      await executor.started.promise;
      const requests: AgentMessage[] = bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.ACTION_PLAN_REQUEST
      );
      const request: AgentMessage = requests[0];
      const surfaceId: string = 'virtual:' + request.taskId;
      const planId: string = 'direct:' + surfaceId;
      const accepted: boolean[] = [];
      const forgeries: ActionResultPayload[] = [
        {
          surfaceId: 'virtual:forged',
          planId,
          runId: surfaceId,
          status: 'success',
          completedStepIds: []
        },
        {
          surfaceId,
          planId: 'direct:forged',
          runId: surfaceId,
          status: 'success',
          completedStepIds: []
        },
        {
          surfaceId,
          planId,
          runId: 'virtual:forged',
          status: 'success',
          completedStepIds: []
        },
        {
          surfaceId,
          planId,
          runId: surfaceId,
          status: 'paused',
          completedStepIds: []
        },
        JSON.parse('{"surfaceId":"' + surfaceId + '","planId":"' + planId +
          '","runId":"' + surfaceId + '","status":"unexpected","completedStepIds":[]}') as ActionResultPayload
      ];
      for (let index = 0; index < forgeries.length; index++) {
        bus.publish({
          type: AgentMessageType.ACTION_RESULT,
          conversationId: request.conversationId,
          turnId: request.turnId,
          taskId: request.taskId,
          payload: forgeries[index]
        });
        await settle();
        accepted.push(resolved);
      }
      executor.release.open();
      const result = await pending as MultiAgentSettledOutcome;

      expect(accepted.join(',')).assertEqual('false,false,false,false,false');
      expect(result.status).assertEqual('success');
      runtime.dispose();
    });

    it('rejects a shape-valid virtual output surface unrelated to its host action', 0, async () => {
      const bus = new CountingBus();
      const executor = new BlockingVirtualExecutor();
      const options = runtimeOptions(
        bus,
        new VirtualMemoryPlanner(),
        new ControlledWriter(),
        1000
      );
      options.virtualActionResolver = new StaticVirtualResolver();
      options.actionExecutor = executor;
      const runtime = new MultiAgentRuntime(options);
      const pending = runtime.submit('remember me', { text: '' });
      await executor.started.promise;
      const request = bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.ACTION_PLAN_REQUEST
      )[0];
      const surfaceId = 'virtual:' + request.taskId;
      bus.publish({
        type: AgentMessageType.ACTION_RESULT,
        conversationId: request.conversationId,
        turnId: request.turnId,
        taskId: request.taskId,
        payload: {
          surfaceId,
          planId: 'direct:' + surfaceId,
          runId: surfaceId,
          status: 'success',
          completedStepIds: ['step-1'],
          outputs: [{
            stepId: 'step-1',
            output: JSON.parse('{"surfaceId":"calendar-review:999"}') as Object
          }]
        } as ActionResultPayload
      });
      const result = await pending as MultiAgentSettledOutcome;

      expect(result.status).assertEqual('success');
      expect(result.surfaceId).assertEqual(surfaceId);
      executor.release.open();
      runtime.dispose();
    });

    it('keeps a virtual output surface that is the exact current host surface', 0, async () => {
      const bus = new CountingBus();
      const executor = new BlockingVirtualExecutor();
      const options = runtimeOptions(
        bus,
        new VirtualMemoryPlanner(),
        new ControlledWriter(),
        1000
      );
      options.virtualActionResolver = new StaticVirtualResolver();
      options.actionExecutor = executor;
      const runtime = new MultiAgentRuntime(options);
      const pending = runtime.submit('remember me', {
        text: '',
        currentSurfaceSummary: {
          surfaceId: 'surface_seed', kind: 'local_tool', status: 'ready', entityRefs: [], actionOfferIds: []
        }
      });
      await executor.started.promise;
      const request = bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.ACTION_PLAN_REQUEST
      )[0];
      const surfaceId = 'virtual:' + request.taskId;
      bus.publish({
        type: AgentMessageType.ACTION_RESULT,
        conversationId: request.conversationId,
        turnId: request.turnId,
        taskId: request.taskId,
        payload: {
          surfaceId,
          planId: 'direct:' + surfaceId,
          runId: surfaceId,
          status: 'success',
          completedStepIds: ['step-1'],
          outputs: [{
            stepId: 'step-1',
            output: JSON.parse('{"surfaceId":"surface_seed"}') as Object
          }]
        } as ActionResultPayload
      });
      const result = await pending as MultiAgentSettledOutcome;

      expect(result.status).assertEqual('success');
      expect(result.surfaceId).assertEqual('surface_seed');
      executor.release.open();
      runtime.dispose();
    });

    it('ignores wrong correlation and accepts only the exact terminal result', 0, async () => {
      const bus = new CountingBus();
      const runtime = new MultiAgentRuntime(runtimeOptions(
        bus,
        new HangingPlanner(),
        new ControlledWriter()
      ));
      let resolved = false;
      const pending = runtime.submit('manual-result', { text: '' });
      pending.then(() => {
        resolved = true;
      });
      await bus.inputSeen.promise;
      const input = bus.input as AgentMessage;
      const payload: TurnResultPayload = {
        status: 'success',
        roundCount: 1,
        message: 'exact answer'
      };
      bus.publish({
        type: AgentMessageType.TURN_RESULT,
        conversationId: input.conversationId,
        turnId: 'wrong-turn',
        taskId: input.taskId,
        payload
      });
      await settle();
      expect(resolved).assertFalse();
      bus.publish({
        type: AgentMessageType.TURN_RESULT,
        conversationId: input.conversationId,
        turnId: input.turnId,
        taskId: input.taskId,
        payload
      });
      const result = await pending as MultiAgentSettledOutcome;

      expect(result.status).assertEqual('success');
      expect(result.message).assertEqual('exact answer');
      runtime.dispose();
    });

    it('rejects missing or mismatched terminal persona after an exact UI authority', 0, async () => {
      const bus = new CountingBus();
      const runtime = new MultiAgentRuntime(runtimeOptions(
        bus,
        new HangingPlanner(),
        new ControlledWriter()
      ));
      let resolved = false;
      const pending = runtime.submit('manual-persona-result', { text: '' });
      pending.then(() => {
        resolved = true;
      });
      await bus.inputSeen.promise;
      const input = bus.input as AgentMessage;
      const uiTaskId = 'manual-ui-authority';
      const uiPayload: CreateUiTaskPayload = {
        taskId: uiTaskId,
        dataTaskIds: ['manual-data-authority'],
        personaId: 'travel_companion',
        skillId: 'travel-planning',
        intent: 'manual UI authority',
        expectedOutputSchema: 'hotelSearchResults'
      };
      bus.publish({
        type: AgentMessageType.TASK_CREATE_UI,
        conversationId: input.conversationId,
        turnId: input.turnId,
        taskId: uiTaskId,
        payload: uiPayload
      });
      publishUiTerminal(bus, input, uiTaskId, 'surface-authority', 'result');

      const mismatch: TurnResultPayload = {
        status: 'success',
        roundCount: 1,
        message: 'forged persona',
        personaId: 'work_companion',
        skillId: 'work-assistant'
      };
      bus.publish({
        type: AgentMessageType.TURN_RESULT,
        conversationId: input.conversationId,
        turnId: input.turnId,
        taskId: input.taskId,
        payload: mismatch
      });
      await settle();
      expect(resolved).assertFalse();

      publishTurnTerminal(bus, input, 'success', 'missing persona');
      await settle();
      expect(resolved).assertFalse();

      const exact: TurnResultPayload = {
        status: 'success',
        roundCount: 1,
        message: 'exact persona',
        personaId: 'travel_companion',
        skillId: 'travel-planning'
      };
      bus.publish({
        type: AgentMessageType.TURN_RESULT,
        conversationId: input.conversationId,
        turnId: input.turnId,
        taskId: input.taskId,
        payload: exact
      });
      const outcome = await pending as MultiAgentSettledOutcome;

      expect(outcome.personaId).assertEqual('travel_companion');
      expect(outcome.skillId).assertEqual('travel-planning');
      runtime.dispose();
    });

    it('preserves persona and skill from an exact action-only plan request', 0, async () => {
      const bus = new CountingBus();
      const runtime = new MultiAgentRuntime(runtimeOptions(
        bus,
        new HangingPlanner(),
        new ControlledWriter()
      ));
      const pending = runtime.submit('manual-action-persona', { text: '' });
      await bus.inputSeen.promise;
      const input = bus.input as AgentMessage;
      const request: ActionPlanRequestPayload = {
        uiTaskId: 'virtual-action-authority',
        dataTaskIds: [],
        goal: 'remember preference',
        allowedActionIds: ['memory.update'],
        personaId: 'food_companion',
        skillId: 'food-search',
        inputText: '我只喝瑞幸咖啡',
        virtual: true
      };
      bus.publish({
        type: AgentMessageType.ACTION_PLAN_REQUEST,
        conversationId: input.conversationId,
        turnId: input.turnId,
        taskId: request.uiTaskId,
        payload: request
      });
      const result: TurnResultPayload = {
        status: 'success',
        roundCount: 1,
        message: 'memory updated',
        personaId: 'food_companion',
        skillId: 'food-search'
      };
      bus.publish({
        type: AgentMessageType.TURN_RESULT,
        conversationId: input.conversationId,
        turnId: input.turnId,
        taskId: input.taskId,
        payload: result
      });
      const outcome = await pending as MultiAgentSettledOutcome;

      expect(outcome.personaId).assertEqual('food_companion');
      expect(outcome.skillId).assertEqual('food-search');
      runtime.dispose();
    });

    it('fails a malformed action request without retaining its forged persona', 0, async () => {
      const bus = new CountingBus();
      const runtime = new MultiAgentRuntime(runtimeOptions(
        bus,
        new HangingPlanner(),
        new ControlledWriter(),
        100
      ));
      const pending = runtime.submit('manual-action-persona-after-forgery', { text: '' });
      await bus.inputSeen.promise;
      const input = bus.input as AgentMessage;
      const forged: Object = JSON.parse('{' +
        '"uiTaskId":"forged-action-authority","dataTaskIds":[],' +
        '"goal":"forge preference","allowedActionIds":["memory.update"],' +
        '"personaId":"travel_companion","skillId":"travel-search",' +
        '"inputText":"forged","virtual":true,"unexpected":true}');
      bus.publish({
        type: AgentMessageType.ACTION_PLAN_REQUEST,
        conversationId: input.conversationId,
        turnId: input.turnId,
        taskId: 'forged-action-authority',
        payload: forged
      });
      const failed = await pending as MultiAgentSettledOutcome;

      expect(failed.status).assertEqual('error');
      expect(failed.personaId).assertEqual('');
      expect(failed.skillId).assertEqual('');

      const nextPending = runtime.submit('manual-after-forgery', {
        text: '',
        previousPersonaId: 'travel_companion'
      });
      await settle();
      const inputs = bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.INPUT_USER
      );
      const nextInput = inputs[inputs.length - 1];
      publishTurnTerminal(bus, nextInput, 'success', 'next turn');
      const next = await nextPending as MultiAgentSettledOutcome;

      expect(next.status).assertEqual('success');
      expect(next.personaId).assertEqual('');
      expect(next.skillId).assertEqual('');
      runtime.dispose();
    });

    it('rejects a final UI writer released after the fixed turn deadline', 1000, async () => {
      const bus = new CountingBus();
      const writer = new ControlledWriter();
      writer.blockResult = true;
      const runtime = new MultiAgentRuntime(runtimeOptions(
        bus,
        new HotelRoundPlanner(),
        writer,
        30
      ));
      const pending = runtime.submit('late final UI', { text: '' });

      await writer.resultStarted.promise;
      const result = await pending as MultiAgentSettledOutcome;
      writer.release();
      await settle();
      const input = bus.input as AgentMessage;
      const correlated = bus.published.filter((message: AgentMessage): boolean =>
        message.turnId === input.turnId
      );
      const terminals = correlated.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TURN_RESULT
      );
      const finalUiResults = correlated.filter((message: AgentMessage): boolean => {
        if (message.type !== AgentMessageType.TASK_RESULT_UI) {
          return false;
        }
        return (message.payload as UiRenderResultPayload).state === 'result';
      });

      expect(result.status).assertEqual('error');
      expect(writer.resultSurfaceId).assertEqual('');
      expect(finalUiResults.length).assertEqual(0);
      expect(correlated.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TURN_CANCEL
      ).length).assertEqual(1);
      expect(terminals.length).assertEqual(1);
      expect((terminals[0].payload as TurnResultPayload).status).assertEqual('error');
      runtime.dispose();
    });

    it('settles timeout, cancel, and dispose without accepting late writes', 1000, async () => {
      const timeoutRuntime = new MultiAgentRuntime(runtimeOptions(
        new CountingBus(),
        new HangingPlanner(),
        new ControlledWriter(),
        10
      ));
      const timeout = await timeoutRuntime.submit('timeout', { text: '' }) as MultiAgentSettledOutcome;
      expect(timeout.status).assertEqual('error');
      timeoutRuntime.dispose();

      const cancelRuntime = new MultiAgentRuntime(runtimeOptions(
        new CountingBus(),
        new HangingPlanner(),
        new ControlledWriter()
      ));
      const canceledPending = cancelRuntime.submit('cancel', { text: '' });
      cancelRuntime.cancelActiveTurn('user_cancel');
      const canceled = await canceledPending as MultiAgentSettledOutcome;
      expect(canceled.status).assertEqual('canceled');

      const disposedPending = cancelRuntime.submit('dispose', { text: '' });
      cancelRuntime.dispose();
      const disposed = await disposedPending as MultiAgentSettledOutcome;
      expect(disposed.status).assertEqual('canceled');
    });
  });
}
