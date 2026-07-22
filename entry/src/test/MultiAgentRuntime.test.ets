import { describe, expect, it } from '@ohos/hypium';
import {
  ActionArgsValidator,
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionOffer,
  ActionOfferContext,
  ActionPlanRequestPayload,
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
  LegacyHandoff,
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
  VirtualActionIntentResolver,
  allToolDefinitions
} from '@loop/agent-core';
import {
  multiAgentEvidenceLine,
  MultiAgentRuntime
} from '../main/ets/pages/A2uiHome/agent/MultiAgentRuntime';
import {
  MultiAgentHandoffOutcome,
  MIGRATED_TOOL_IDS,
  MultiAgentRuntimeOptions,
  MultiAgentSettledOutcome,
  ownershipForPlan
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

class HandoffMutatingBus extends CountingBus {
  private readonly replacementIds: string[];

  constructor(replacementIds: string[]) {
    super();
    this.replacementIds = replacementIds.slice();
  }

  publish(message: AgentMessage): void {
    if (message.type === AgentMessageType.TURN_HANDOFF) {
      const payload = message.payload as LegacyHandoff;
      payload.unmigratedToolIds = this.replacementIds.slice();
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

class HandoffPlanner implements LeaderPlanner {
  async plan(
    _message: AgentMessage,
    _input: InputUserPayload,
    _context: LeaderPlanningContext,
    _round: number = 1
  ): Promise<LeaderDecision> {
    return {
      personaId: 'travel_companion',
      skillId: '',
      requestedCapabilityIds: ['unknown.search'],
      roundAction: 'legacy_handoff',
      dataTasks: [],
      uiIntent: {
        purpose: 'handoff',
        preferredDensity: 'comfortable',
        requiredSections: []
      },
      reasonCode: 'unmigrated_tool'
    };
  }
}

class GenericHandoffPlanner implements LeaderPlanner {
  async plan(
    _message: AgentMessage,
    _input: InputUserPayload,
    _context: LeaderPlanningContext,
    _round: number = 1
  ): Promise<LeaderDecision> {
    return {
      personaId: 'travel_companion',
      skillId: '',
      requestedCapabilityIds: [],
      roundAction: 'legacy_handoff',
      dataTasks: [],
      uiIntent: {
        purpose: 'handoff',
        preferredDensity: 'comfortable',
        requiredSections: []
      },
      reasonCode: 'model_failed'
    };
  }
}

class MixedOwnershipPlanner implements LeaderPlanner {
  async plan(
    _message: AgentMessage,
    _input: InputUserPayload,
    _context: LeaderPlanningContext,
    _round: number = 1
  ): Promise<LeaderDecision> {
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
      requestedCapabilityIds: ['hotel.search', 'legacy.action'],
      roundAction: 'execute',
      dataTasks: [task],
      uiIntent: {
        purpose: 'mixed ownership',
        preferredDensity: 'comfortable',
        requiredSections: ['hotels']
      },
      actionIntent: {
        goal: 'Run an unmigrated action',
        allowedActionIds: ['legacy.action']
      },
      reasonCode: 'mixed_plan'
    };
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

class PostExecutionHandoffPlanner implements LeaderPlanner {
  async plan(
    _message: AgentMessage,
    input: InputUserPayload,
    _context: LeaderPlanningContext,
    _round: number = 1
  ): Promise<LeaderDecision> {
    if (input.recentObservations !== undefined && input.recentObservations.length > 0) {
      return {
        personaId: 'travel_companion',
        skillId: '',
        requestedCapabilityIds: ['unknown.search'],
        roundAction: 'legacy_handoff',
        dataTasks: [],
        uiIntent: {
          purpose: 'unknown.search',
          preferredDensity: 'comfortable',
          requiredSections: []
        },
        reasonCode: 'unmigrated_tool'
      };
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

class ControlledWriter implements UiSurfaceWriter {
  readonly resultStarted: TestGate = new TestGate();
  private readonly releaseResult: TestGate = new TestGate();
  blockResult: boolean = false;

  async write(
    _turnId: string,
    _surfaceId: string,
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
      actions: []
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
        intent: 'hotel.search',
        riskLevel: 'read',
        inputSchema: 'hotelSearchRequest',
        outputSchema: 'hotelSearchResults',
        actions: ['legacy.action']
      },
      {
        toolId: 'memory.update',
        intent: 'memory.update',
        riskLevel: 'draft',
        inputSchema: 'memoryUpdateRequest',
        outputSchema: 'memoryUpdateResult',
        actions: ['memory.update']
      },
      {
        toolId: 'dynamic.search',
        intent: 'dynamic.search',
        riskLevel: 'read',
        inputSchema: 'dynamicToolSearchQuery',
        outputSchema: 'dynamicToolConnect',
        actions: []
      },
      {
        toolId: 'unknown.search',
        intent: 'unknown.search',
        riskLevel: 'read',
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
    }],
    runtimeOwnedToolIds: migratedRuntimeIds()
  };
}

function migratedRuntimeIds(): string[] {
  const ids: string[] = [];
  MIGRATED_TOOL_IDS.forEach((toolId: string): void => {
    ids.push(toolId);
  });
  ids.push('memory.update');
  return ids;
}

async function noOffers(
  _data: DataResult,
  _context: ActionOfferContext
): Promise<ActionOffer[]> {
  return [];
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
  message: string
): void {
  const payload: TurnResultPayload = { status, roundCount: 2, message };
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
    it('formats bounded redacted lifecycle evidence from typed messages', 0, () => {
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
        surfaceId: 'surface-2',
        roundCount: 2,
        message: 'provider message must not log'
      };
      const turnMessage: AgentMessage = {
        type: AgentMessageType.TURN_RESULT,
        conversationId: 'conversation-1',
        turnId: 'turn-1',
        taskId: 'input-1',
        payload: turnPayload
      };
      const inputLine = multiAgentEvidenceLine(inputMessage);
      const dataLine = multiAgentEvidenceLine(dataMessage);
      const turnLine = multiAgentEvidenceLine(turnMessage);

      expect(inputLine).assertEqual(
        '[AIPhone][MultiAgentInput] conversation=conversation-1 turn=turn-1 task=input-1'
      );
      expect(dataLine).assertEqual(
        '[AIPhone][MultiAgentDataTask] conversation=conversation-1 turn=turn-1 task=data-1 ' +
          'round=turn-1:round-2 tool=maps.place.details'
      );
      expect(turnLine).assertEqual(
        '[AIPhone][MultiAgentTurnResult] conversation=conversation-1 turn=turn-1 task=input-1 ' +
          'status=partial surface=surface-2 roundCount=2 messageChars=29'
      );
      expect(inputLine.indexOf('secret')).assertEqual(-1);
      expect(dataLine.indexOf('private-place-id')).assertEqual(-1);
      expect(turnLine.indexOf('provider message')).assertEqual(-1);
    });

    it('owns all 44 fixed tools plus the bounded dynamic read virtual tool', 0, () => {
      const registryIds = allToolDefinitions().map(
        (definition: ToolDefinition): string => definition.toolId
      );
      const known = ownershipForPlan(registryIds, MIGRATED_TOOL_IDS);
      const unknown = ownershipForPlan(
        ['travel.search', 'unknown.tool', 'unknown.tool'],
        MIGRATED_TOOL_IDS
      );

      expect(MIGRATED_TOOL_IDS.size).assertEqual(45);
      expect(MIGRATED_TOOL_IDS.has('dynamic.search')).assertTrue();
      expect(new Set<string>(registryIds).size).assertEqual(44);
      expect(known.owner).assertEqual('multi_agent');
      expect(known.unmigratedToolIds.length).assertEqual(0);
      const handoff = unknown as LegacyHandoff;
      expect(handoff.owner).assertEqual('legacy');
      expect(handoff.reason).assertEqual('unmigrated_tool');
      expect(handoff.unmigratedToolIds.join(',')).assertEqual('unknown.tool');
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
      expect(result.surfaceId.length > 0).assertTrue();
      runtime.dispose();
    });

    it('joins an exact UI error with Leader terminal before canceling and settling', 0, async () => {
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
      publishTurnTerminal(bus, input, 'success', 'provider work completed');
      const result = await pending as MultiAgentSettledOutcome;
      const correlated: AgentMessage[] = bus.published.filter((message: AgentMessage): boolean =>
        message.turnId === input.turnId &&
          (message.type === AgentMessageType.TURN_CANCEL ||
            message.type === AgentMessageType.TURN_RESULT)
      );

      expect(result.status).assertEqual('error');
      expect(result.surfaceId).assertEqual('surface-error');
      expect(correlated[correlated.length - 2].type).assertEqual(AgentMessageType.TURN_CANCEL);
      expect(correlated[correlated.length - 1].type).assertEqual(AgentMessageType.TURN_RESULT);
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
        }
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

      expect(accepted.join(',')).assertEqual('false,false,false');
      expect(result.status).assertEqual('success');
      runtime.dispose();
    });

    it('returns a typed handoff before any Data, UI, or Action execution', 0, async () => {
      const bus = new CountingBus();
      const runtime = new MultiAgentRuntime(runtimeOptions(
        bus,
        new HandoffPlanner(),
        new ControlledWriter()
      ));
      const raw = await runtime.submit('non-canary', { text: '' });
      const handoff = raw as MultiAgentHandoffOutcome;

      expect(handoff.kind).assertEqual('handoff');
      expect(handoff.owner).assertEqual('legacy');
      expect(handoff.reason).assertEqual('unmigrated_tool');
      expect(handoff.reasonCode).assertEqual('unmigrated_tool');
      expect(handoff.unmigratedToolIds.join(',')).assertEqual('unknown.search');
      expect(handoff.personaId).assertEqual('travel_companion');
      expect(bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_DATA ||
          message.type === AgentMessageType.TASK_CREATE_UI ||
          message.type === AgentMessageType.ACTION_RUN
      ).length).assertEqual(0);
      runtime.dispose();
    });

    it('rejects a truly unknown handoff after owned provider execution starts', 0, async () => {
      const bus = new CountingBus();
      const executor = new SuccessDataExecutor();
      const options = runtimeOptions(
        bus,
        new PostExecutionHandoffPlanner(),
        new ControlledWriter()
      );
      options.dataExecutor = executor;
      const runtime = new MultiAgentRuntime(options);

      const outcome = await runtime.submit('search then hand off', { text: '' }) as
        MultiAgentSettledOutcome;
      const errors = bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_ERROR
      );

      expect(outcome.kind).assertEqual('settled');
      expect(outcome.status).assertEqual('error');
      expect(outcome.message).assertEqual('Leader cannot hand off after runtime execution has started');
      expect(executor.calls).assertEqual(1);
      expect(bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TURN_HANDOFF
      ).length).assertEqual(0);
      expect(errors.length).assertEqual(1);
      expect((errors[0].payload as TaskErrorPayload).code)
        .assertEqual('LEADER_RUNTIME_OWNERSHIP_VIOLATION');
      runtime.dispose();
    });

    it('rejects forged known missing extra and case-mutated handoff capability sets', 0, async () => {
      const forgeries: string[][] = [
        ['travel.search'],
        [],
        ['unknown.search', 'extra.search'],
        ['UNKNOWN.SEARCH']
      ];
      for (let index = 0; index < forgeries.length; index++) {
        const bus = new HandoffMutatingBus(forgeries[index]);
        const runtime = new MultiAgentRuntime(runtimeOptions(
          bus,
          new HandoffPlanner(),
          new ControlledWriter(),
          20
        ));
        const outcome = await runtime.submit('unknown capability', { text: '' });
        expect(outcome.kind).assertEqual('settled');
        expect((outcome as MultiAgentSettledOutcome).status).assertEqual('error');
        runtime.dispose();
      }
    });

    it('hands a mixed plan wholly to legacy before publishing its known Data task', 0, async () => {
      const bus = new CountingBus();
      const executor = new SuccessDataExecutor();
      const options = runtimeOptions(bus, new MixedOwnershipPlanner(), new ControlledWriter());
      options.dataExecutor = executor;
      const runtime = new MultiAgentRuntime(options);

      const handoff = await runtime.submit('mixed plan', { text: '' }) as MultiAgentHandoffOutcome;

      expect(handoff.kind).assertEqual('handoff');
      expect(handoff.unmigratedToolIds.join(',')).assertEqual('legacy.action');
      expect(executor.calls).assertEqual(0);
      expect(bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_DATA ||
          message.type === AgentMessageType.TASK_CREATE_UI ||
          message.type === AgentMessageType.ACTION_PLAN_REQUEST ||
          message.type === AgentMessageType.ACTION_RUN
      ).length).assertEqual(0);
      runtime.dispose();
    });

    it('rejects a generic planner handoff before publication instead of invoking legacy', 0, async () => {
      const bus = new CountingBus();
      const runtime = new MultiAgentRuntime(runtimeOptions(
        bus,
        new GenericHandoffPlanner(),
        new ControlledWriter()
      ));

      const outcome = await runtime.submit('generic failure', { text: '' }) as MultiAgentSettledOutcome;

      expect(outcome.kind).assertEqual('settled');
      expect(outcome.status).assertEqual('error');
      expect(bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TURN_HANDOFF
      ).length).assertEqual(0);
      runtime.dispose();
    });

    it('isolates concurrent ownership decisions by runtime conversation', 0, async () => {
      const migratedBus = new CountingBus();
      const legacyBus = new CountingBus();
      const migrated = new MultiAgentRuntime(runtimeOptions(
        migratedBus,
        new AnswerPlanner(),
        new ControlledWriter()
      ));
      const legacy = new MultiAgentRuntime(runtimeOptions(
        legacyBus,
        new HandoffPlanner(),
        new ControlledWriter()
      ));

      const outcomes = await Promise.all([
        migrated.submit('你好', { text: '' }),
        legacy.submit('dynamic tool', { text: '' })
      ]);

      expect(outcomes[0].kind).assertEqual('settled');
      expect(outcomes[1].kind).assertEqual('handoff');
      expect((outcomes[1] as MultiAgentHandoffOutcome).unmigratedToolIds[0])
        .assertEqual('unknown.search');
      migrated.dispose();
      legacy.dispose();
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
