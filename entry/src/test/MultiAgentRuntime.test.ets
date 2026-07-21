import { describe, expect, it } from '@ohos/hypium';
import {
  ActionArgsValidator,
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionOffer,
  ActionOfferContext,
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
  ToolDefinition,
  ToolDefinitionLookup,
  TurnResultPayload,
  UiRenderResult,
  UiSurfaceWriteLease,
  UiSurfaceWriter,
  UiTaskRenderer
} from '@loop/agent-core';
import { MultiAgentRuntime } from '../main/ets/pages/A2uiHome/agent/MultiAgentRuntime';
import {
  MultiAgentHandoffOutcome,
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
      roundAction: 'legacy_handoff',
      dataTasks: [],
      uiIntent: {
        purpose: 'handoff',
        preferredDensity: 'comfortable',
        requiredSections: []
      },
      reasonCode: 'outside_canary'
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
      return answerDecision('酒店结果已就绪');
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

function answerDecision(answer: string): LeaderDecision {
  return {
    personaId: 'travel_companion',
    skillId: '',
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
    tools: [{
      toolId: 'hotel.search',
      intent: 'hotel.search',
      riskLevel: 'read',
      inputSchema: 'hotelSearchRequest',
      outputSchema: 'hotelSearchResults',
      actions: []
    }],
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

export default function multiAgentRuntimeTest() {
  describe('multiAgentRuntime', () => {
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
      expect(handoff.reasonCode).assertEqual('outside_canary');
      expect(handoff.personaId).assertEqual('travel_companion');
      expect(bus.published.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_DATA ||
          message.type === AgentMessageType.TASK_CREATE_UI ||
          message.type === AgentMessageType.ACTION_RUN
      ).length).assertEqual(0);
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
