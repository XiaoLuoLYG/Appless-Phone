import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  CreateDataTaskPayload,
  DataAgent,
  DataResult,
  DataSource,
  DataStepDecision,
  DataTaskAuthorizationResult,
  DataTaskExecutor,
  DataTaskPlanner,
  LinkedMessageBus,
  ObservationDigest,
  TaskErrorPayload
} from '@loop/agent-core';

interface HotelResult {
  hotelId: number;
  ratePlanId: string;
  name: string;
}

interface HotelSearchArgs {
  city: string;
  checkIn: string;
  checkOut: string;
  guests: number;
}

interface DynamicResultData {
  entityRefs: string[];
  recordId: string;
  privatePayload: string;
}

interface DynamicQueryArgs {
  query: string;
}

class TestGate {
  readonly promise: Promise<void>;
  private resolvePromise: (() => void) | null = null;

  constructor() {
    this.promise = new Promise<void>((resolve: () => void) => {
      this.resolvePromise = resolve;
    });
  }

  open(): void {
    const resolve: (() => void) | null = this.resolvePromise;
    this.resolvePromise = null;
    if (resolve !== null) {
      resolve();
    }
  }
}

class ScriptedDataExecutor implements DataTaskExecutor {
  calls: number = 0;
  lastTask: CreateDataTaskPayload | null = null;
  private readonly scriptedResult: DataResult;

  constructor(scriptedResult: DataResult) {
    this.scriptedResult = scriptedResult;
  }

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls++;
    this.lastTask = task;
    return this.scriptedResult;
  }
}

class SequenceDataExecutor implements DataTaskExecutor {
  calls: number = 0;
  tasks: CreateDataTaskPayload[] = [];
  private readonly results: DataResult[];

  constructor(results: DataResult[]) {
    this.results = results.slice();
  }

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls++;
    this.tasks.push(task);
    if (this.results.length === 0) {
      throw new Error('No scripted Data result');
    }
    return this.results.shift() as DataResult;
  }
}

class ScriptedDataPlanner implements DataTaskPlanner {
  steps: number[] = [];
  observationJson: string[] = [];
  private readonly decisions: DataStepDecision[];

  constructor(decisions: DataStepDecision[]) {
    this.decisions = decisions.slice();
  }

  async next(
    _task: CreateDataTaskPayload,
    observations: ObservationDigest[],
    step: number
  ): Promise<DataStepDecision> {
    this.steps.push(step);
    this.observationJson.push(JSON.stringify(observations));
    if (this.decisions.length === 0) {
      throw new Error('No scripted Data decision');
    }
    return this.decisions.shift() as DataStepDecision;
  }
}

class ThrowingDataExecutor implements DataTaskExecutor {
  calls: number = 0;

  async execute(_task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls++;
    throw new Error('provider unavailable');
  }
}

class TwoControlledDataExecutor implements DataTaskExecutor {
  readonly bothStarted: TestGate = new TestGate();
  private calls: number = 0;
  private firstResolve: ((result: DataResult) => void) | null = null;
  private firstReject: ((error: Error) => void) | null = null;
  private secondResolve: ((result: DataResult) => void) | null = null;

  async execute(_task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls++;
    return new Promise<DataResult>((
      resolve: (result: DataResult) => void,
      reject: (error: Error) => void
    ) => {
      if (this.calls === 1) {
        this.firstResolve = resolve;
        this.firstReject = reject;
      } else {
        this.secondResolve = resolve;
        this.bothStarted.open();
      }
    });
  }

  completeFirst(result: DataResult): void {
    const resolve: ((result: DataResult) => void) | null = this.firstResolve;
    this.firstResolve = null;
    this.firstReject = null;
    if (resolve !== null) {
      resolve(result);
    }
  }

  rejectFirst(error: Error): void {
    const reject: ((error: Error) => void) | null = this.firstReject;
    this.firstResolve = null;
    this.firstReject = null;
    if (reject !== null) {
      reject(error);
    }
  }

  completeSecond(result: DataResult): void {
    const resolve: ((result: DataResult) => void) | null = this.secondResolve;
    this.secondResolve = null;
    if (resolve !== null) {
      resolve(result);
    }
  }
}

class SingleControlledDataExecutor implements DataTaskExecutor {
  readonly started: TestGate = new TestGate();
  private resolveResult: ((result: DataResult) => void) | null = null;

  async execute(_task: CreateDataTaskPayload): Promise<DataResult> {
    return new Promise<DataResult>((resolve: (result: DataResult) => void) => {
      this.resolveResult = resolve;
      this.started.open();
    });
  }

  complete(result: DataResult): void {
    const resolve: ((result: DataResult) => void) | null = this.resolveResult;
    this.resolveResult = null;
    if (resolve !== null) {
      resolve(result);
    }
  }
}

function hotelDataResult(status: 'success' | 'partial' = 'partial'): DataResult {
  const source: DataSource = {
    provider: 'rollinggo',
    backend: 'oauth_api',
    operation: 'searchHotels',
    fetchedAt: '2026-07-20T02:00:00.000Z',
    accountHint: 'rollinggo-account'
  };
  const hotel: HotelResult = {
    hotelId: 987654,
    ratePlanId: 'rate-plan-real-42',
    name: '深圳真实酒店'
  };
  return {
    toolId: 'hotel.search',
    outputSchema: 'hotelSearchResults',
    status,
    sources: [source],
    data: hotel,
    warnings: []
  };
}

function dynamicDataResult(index: number = 1): DataResult {
  const source: DataSource = {
    provider: 'composio',
    backend: 'mcp_remote',
    operation: 'WEATHER_SEARCH',
    fetchedAt: '2026-07-21T10:00:00.000Z'
  };
  const entityRefs: string[] = [];
  for (let refIndex = 0; refIndex < 20; refIndex++) {
    entityRefs.push('weather-record-' + refIndex.toString() + '-'.repeat(130));
  }
  const data: DynamicResultData = {
    entityRefs,
    recordId: 'weather-record-real-' + index.toString(),
    privatePayload: 'provider-secret-must-not-reach-model'
  };
  return {
    toolId: 'dynamic.search',
    outputSchema: 'dynamicToolConnect',
    status: 'success',
    sources: [source],
    data,
    warnings: []
  };
}

function decision(
  kind: 'call' | 'finish',
  toolId: string,
  args: Object = new Object()
): DataStepDecision {
  return {
    kind,
    toolId,
    args,
    summary: kind === 'finish' ? 'invented model summary must be ignored' : 'read provider'
  };
}

function dataTaskMessage(
  conversationId: string = 'conversation-hotel',
  turnId: string = 'turn-1',
  taskId: string = 'data-1'
): AgentMessage {
  const args: HotelSearchArgs = {
    city: 'Shenzhen',
    checkIn: '2026-07-21',
    checkOut: '2026-07-22',
    guests: 2
  };
  const payload: CreateDataTaskPayload = {
    taskId,
    roundId: turnId,
    skillId: 'hotel-search',
    goal: 'hotel.search',
    allowedToolIds: ['hotel.search'],
    toolId: 'hotel.search',
    outputSchema: 'hotelSearchResults',
    args,
    required: true
  };
  return {
    type: AgentMessageType.TASK_CREATE_DATA,
    conversationId,
    turnId,
    taskId,
    payload
  };
}

function dynamicDataTaskMessage(
  taskId: string,
  allowedToolIds: string[] = ['dynamic.search']
): AgentMessage {
  const payload: CreateDataTaskPayload = {
    taskId,
    roundId: 'round-1',
    skillId: '',
    goal: '查天气',
    allowedToolIds,
    toolId: 'dynamic.search',
    outputSchema: 'dynamicToolConnect',
    args: new Object(),
    required: true
  };
  return {
    type: AgentMessageType.TASK_CREATE_DATA,
    conversationId: 'conversation-data-planner',
    turnId: 'turn-data-planner',
    taskId,
    payload
  };
}

function allowDataTask(_task: CreateDataTaskPayload): DataTaskAuthorizationResult {
  return { ok: true, code: '', message: '' };
}

function denyDataTask(_task: CreateDataTaskPayload): DataTaskAuthorizationResult {
  return {
    ok: false,
    code: 'DATA_TASK_READ_ONLY_REQUIRED',
    message: 'Only registered read tools can run in Data Agent.'
  };
}

function message(type: AgentMessageType, conversationId: string, turnId: string, taskId: string): AgentMessage {
  return {
    type,
    conversationId,
    turnId,
    taskId,
    payload: new Object()
  };
}

async function receive(reader: AgentMessageReader): Promise<AgentMessage> {
  const received: AgentMessage | null = await reader.receive();
  if (received === null) {
    throw new Error('observer closed before receiving a message');
  }
  return received;
}

async function receiveType(reader: AgentMessageReader, type: AgentMessageType): Promise<AgentMessage> {
  while (true) {
    const received: AgentMessage = await receive(reader);
    if (received.type === type) {
      return received;
    }
  }
}

async function settle(): Promise<void> {
  await Promise.resolve();
  await Promise.resolve();
}

export default function dataAgentTest() {
  describe('dataAgent', () => {
    it('runs call observe finish and publishes only the actual read result', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: SequenceDataExecutor = new SequenceDataExecutor([dynamicDataResult()]);
      const args: DynamicQueryArgs = { query: '深圳天气' };
      const planner: ScriptedDataPlanner = new ScriptedDataPlanner([
        decision('call', 'dynamic.search', args),
        decision('finish', 'dynamic.search')
      ]);
      const agent: DataAgent = new DataAgent(bus, allowDataTask, executor, planner);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(dynamicDataTaskMessage('data-react'));
      const resultMessage: AgentMessage = await receiveType(observer, AgentMessageType.TASK_RESULT_DATA);
      const result: DataResult = resultMessage.payload as DataResult;
      const data: DynamicResultData = result.data as DynamicResultData;

      expect(executor.calls).assertEqual(1);
      expect(planner.steps.join(',')).assertEqual('1,2');
      expect(planner.observationJson[0]).assertEqual('[]');
      expect(planner.observationJson[1].indexOf('provider-secret-must-not-reach-model')).assertEqual(-1);
      expect((JSON.parse(planner.observationJson[1]) as ObservationDigest[])[0].entityRefs.length)
        .assertEqual(16);
      expect(result.toolId).assertEqual('dynamic.search');
      expect(result.sources[0].provider).assertEqual('composio');
      expect(data.recordId).assertEqual('weather-record-real-1');
      expect(resultMessage.taskId).assertEqual('data-react');

      bus.publish(message(AgentMessageType.ACTION_RUN, 'marker', 'marker', 'marker'));
      expect((await receiveType(observer, AgentMessageType.ACTION_RUN)).type)
        .assertEqual(AgentMessageType.ACTION_RUN);
      agent.stop();
      observer.close();
    });

    it('rejects an attempted fourth read before invoking the executor', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: SequenceDataExecutor = new SequenceDataExecutor([
        dynamicDataResult(1), dynamicDataResult(2), dynamicDataResult(3)
      ]);
      const planner: ScriptedDataPlanner = new ScriptedDataPlanner([
        decision('call', 'dynamic.search'), decision('call', 'dynamic.search'),
        decision('call', 'dynamic.search'), decision('call', 'dynamic.search')
      ]);
      let authorizationCalls: number = 0;
      const agent: DataAgent = new DataAgent(bus, (task: CreateDataTaskPayload): DataTaskAuthorizationResult => {
        authorizationCalls++;
        return allowDataTask(task);
      }, executor, planner);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(dynamicDataTaskMessage('data-step-limit'));
      const errorMessage: AgentMessage = await receiveType(observer, AgentMessageType.TASK_ERROR);
      const error: TaskErrorPayload = errorMessage.payload as TaskErrorPayload;

      expect(error.code).assertEqual('DATA_STEP_LIMIT');
      expect(executor.calls).assertEqual(3);
      expect(authorizationCalls).assertEqual(3);
      expect(planner.steps.join(',')).assertEqual('1,2,3,4');
      agent.stop();
      observer.close();
    });

    it('fails closed for write unknown and outside-allowlist calls before authorization', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: SequenceDataExecutor = new SequenceDataExecutor([]);
      const planner: ScriptedDataPlanner = new ScriptedDataPlanner([
        decision('call', 'hotel.booking.open'),
        decision('call', 'missing.search'),
        decision('call', 'hotel.search')
      ]);
      let authorizationCalls: number = 0;
      const agent: DataAgent = new DataAgent(bus, (task: CreateDataTaskPayload): DataTaskAuthorizationResult => {
        authorizationCalls++;
        return allowDataTask(task);
      }, executor, planner);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(dynamicDataTaskMessage('data-write', ['dynamic.search', 'hotel.booking.open']));
      const write: TaskErrorPayload = (await receiveType(observer, AgentMessageType.TASK_ERROR)).payload as TaskErrorPayload;
      bus.publish(dynamicDataTaskMessage('data-unknown', ['dynamic.search', 'missing.search']));
      const unknown: TaskErrorPayload = (await receiveType(observer, AgentMessageType.TASK_ERROR)).payload as TaskErrorPayload;
      bus.publish(dynamicDataTaskMessage('data-outside'));
      const outside: TaskErrorPayload = (await receiveType(observer, AgentMessageType.TASK_ERROR)).payload as TaskErrorPayload;

      expect(write.code).assertEqual('TOOL_NOT_ALLOWED');
      expect(unknown.code).assertEqual('TOOL_NOT_ALLOWED');
      expect(outside.code).assertEqual('TOOL_NOT_ALLOWED');
      expect(executor.calls).assertEqual(0);
      expect(authorizationCalls).assertEqual(0);
      agent.stop();
      observer.close();
    });

    it('executes one planned task once when its message is duplicated', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: SequenceDataExecutor = new SequenceDataExecutor([dynamicDataResult()]);
      const planner: ScriptedDataPlanner = new ScriptedDataPlanner([
        decision('call', 'dynamic.search'), decision('finish', 'dynamic.search')
      ]);
      const agent: DataAgent = new DataAgent(bus, allowDataTask, executor, planner);
      const observer: AgentMessageReader = bus.openReader();
      const task: AgentMessage = dynamicDataTaskMessage('data-duplicate');
      agent.start();

      bus.publish(task);
      bus.publish(task);
      expect((await receiveType(observer, AgentMessageType.TASK_RESULT_DATA)).taskId)
        .assertEqual('data-duplicate');
      bus.publish(task);
      await settle();
      bus.publish(message(AgentMessageType.ACTION_RUN, 'marker', 'marker', 'marker'));

      expect((await receiveType(observer, AgentMessageType.ACTION_RUN)).type)
        .assertEqual(AgentMessageType.ACTION_RUN);
      expect(executor.calls).assertEqual(1);
      agent.stop();
      observer.close();
    });

    it('accepts only Data tasks and preserves the full structured result with correlation', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: ScriptedDataExecutor = new ScriptedDataExecutor(hotelDataResult());
      const agent: DataAgent = new DataAgent(bus, allowDataTask, executor);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(message(AgentMessageType.TASK_CREATE_UI, 'conversation-hotel', 'turn-1', 'ui-1'));
      bus.publish(dataTaskMessage());
      const resultMessage: AgentMessage = await receiveType(observer, AgentMessageType.TASK_RESULT_DATA);
      const result: DataResult = resultMessage.payload as DataResult;
      const source: DataSource = result.sources[0];
      const hotel: HotelResult = result.data as HotelResult;

      expect(executor.calls).assertEqual(1);
      expect(executor.lastTask === null ? '' : executor.lastTask.toolId).assertEqual('hotel.search');
      expect(resultMessage.conversationId).assertEqual('conversation-hotel');
      expect(resultMessage.turnId).assertEqual('turn-1');
      expect(resultMessage.taskId).assertEqual('data-1');
      expect(result.status).assertEqual('partial');
      expect(result.outputSchema).assertEqual('hotelSearchResults');
      expect(source.provider).assertEqual('rollinggo');
      expect(source.accountHint).assertEqual('rollinggo-account');
      expect(result.warnings.length).assertEqual(0);
      expect(hotel.hotelId).assertEqual(987654);
      expect(hotel.ratePlanId).assertEqual('rate-plan-real-42');
      expect(Object.keys(result.data).sort().join(',')).assertEqual('hotelId,name,ratePlanId');

      agent.stop();
      observer.close();
    });

    it('publishes a correlated Data task error without retrying', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: ThrowingDataExecutor = new ThrowingDataExecutor();
      const agent: DataAgent = new DataAgent(bus, allowDataTask, executor);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(dataTaskMessage('conversation-error', 'turn-error', 'data-error'));
      const errorMessage: AgentMessage = await receiveType(observer, AgentMessageType.TASK_ERROR);
      const error: TaskErrorPayload = errorMessage.payload as TaskErrorPayload;

      expect(errorMessage.conversationId).assertEqual('conversation-error');
      expect(errorMessage.turnId).assertEqual('turn-error');
      expect(errorMessage.taskId).assertEqual('data-error');
      expect(error.code).assertEqual('DATA_TASK_FAILED');
      expect(error.message).assertEqual('provider unavailable');
      expect(executor.calls).assertEqual(1);

      agent.stop();
      observer.close();
    });

    it('keeps cancellation terminal across two later successful completions', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: TwoControlledDataExecutor = new TwoControlledDataExecutor();
      const agent: DataAgent = new DataAgent(bus, allowDataTask, executor);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(dataTaskMessage('conversation-hotel', 'turn-1', 'data-1'));
      bus.publish(dataTaskMessage('conversation-hotel', 'turn-1', 'data-2'));
      await executor.bothStarted.promise;
      bus.publish(message(AgentMessageType.TURN_CANCEL, 'conversation-hotel', 'turn-1', 'cancel-1'));
      expect((await receiveType(observer, AgentMessageType.TURN_CANCEL)).conversationId).assertEqual('conversation-hotel');
      executor.completeFirst(hotelDataResult('success'));
      await settle();
      executor.completeSecond(hotelDataResult('success'));
      await settle();
      bus.publish(message(AgentMessageType.ACTION_RUN, 'marker', 'marker', 'marker'));

      expect((await receive(observer)).type).assertEqual(AgentMessageType.ACTION_RUN);
      agent.stop();
      observer.close();
    });

    it('keeps cancellation terminal when rejection precedes another completion', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: TwoControlledDataExecutor = new TwoControlledDataExecutor();
      const agent: DataAgent = new DataAgent(bus, allowDataTask, executor);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(dataTaskMessage('conversation-hotel', 'turn-1', 'data-1'));
      bus.publish(dataTaskMessage('conversation-hotel', 'turn-1', 'data-2'));
      await executor.bothStarted.promise;
      bus.publish(message(AgentMessageType.TURN_CANCEL, 'conversation-hotel', 'turn-1', 'cancel-1'));
      await receiveType(observer, AgentMessageType.TURN_CANCEL);
      executor.rejectFirst(new Error('late provider error'));
      await settle();
      executor.completeSecond(hotelDataResult('success'));
      await settle();
      bus.publish(message(AgentMessageType.ACTION_RUN, 'marker', 'marker', 'marker'));

      expect((await receive(observer)).type).assertEqual(AgentMessageType.ACTION_RUN);
      agent.stop();
      observer.close();
    });

    it('rejects a valid Data task replay after turn cancellation', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: ScriptedDataExecutor = new ScriptedDataExecutor(hotelDataResult('success'));
      const agent: DataAgent = new DataAgent(bus, allowDataTask, executor);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(message(AgentMessageType.TURN_CANCEL, 'conversation-replay', 'turn-replay', 'cancel-replay'));
      await receiveType(observer, AgentMessageType.TURN_CANCEL);
      bus.publish(dataTaskMessage('conversation-replay', 'turn-replay', 'data-replay'));
      await settle();
      bus.publish(message(AgentMessageType.ACTION_RUN, 'marker', 'marker', 'marker'));
      let terminalOutputs: number = 0;
      let observed: AgentMessage = await receive(observer);
      while (observed.type !== AgentMessageType.ACTION_RUN) {
        if (observed.type === AgentMessageType.TASK_RESULT_DATA ||
          observed.type === AgentMessageType.TASK_ERROR) {
          terminalOutputs++;
        }
        observed = await receive(observer);
      }

      expect(executor.calls).assertEqual(0);
      expect(terminalOutputs).assertEqual(0);
      agent.stop();
      observer.close();
    });

    it('silently rejects a malformed Data task replay after turn cancellation', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: ScriptedDataExecutor = new ScriptedDataExecutor(hotelDataResult('success'));
      const agent: DataAgent = new DataAgent(bus, allowDataTask, executor);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(message(AgentMessageType.TURN_CANCEL, 'conversation-invalid-replay', 'turn-replay', 'cancel-replay'));
      await receiveType(observer, AgentMessageType.TURN_CANCEL);
      bus.publish({
        type: AgentMessageType.TASK_CREATE_DATA,
        conversationId: 'conversation-invalid-replay',
        turnId: 'turn-replay',
        taskId: 'data-invalid-replay',
        payload: JSON.parse('null') as Object
      });
      await settle();
      bus.publish(message(AgentMessageType.ACTION_RUN, 'marker', 'marker', 'marker'));
      let terminalOutputs: number = 0;
      let observed: AgentMessage = await receive(observer);
      while (observed.type !== AgentMessageType.ACTION_RUN) {
        if (observed.type === AgentMessageType.TASK_RESULT_DATA ||
          observed.type === AgentMessageType.TASK_ERROR) {
          terminalOutputs++;
        }
        observed = await receive(observer);
      }

      expect(executor.calls).assertEqual(0);
      expect(terminalOutputs).assertEqual(0);
      agent.stop();
      observer.close();
    });

    it('retains canceled turn identities during a long session', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: ScriptedDataExecutor = new ScriptedDataExecutor(hotelDataResult('success'));
      const agent: DataAgent = new DataAgent(bus, allowDataTask, executor);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      for (let index = 0; index < 129; index++) {
        bus.publish(message(
          AgentMessageType.TURN_CANCEL,
          'conversation-capacity',
          `turn-${index}`,
          `cancel-${index}`
        ));
        await settle();
      }
      bus.publish(dataTaskMessage('conversation-capacity', 'turn-0', 'data-reused'));
      await settle();
      bus.publish(message(AgentMessageType.ACTION_RUN, 'marker', 'marker', 'marker'));
      let dataResults: number = 0;
      let observed: AgentMessage = await receive(observer);
      while (observed.type !== AgentMessageType.ACTION_RUN) {
        if (observed.type === AgentMessageType.TASK_RESULT_DATA) {
          dataResults++;
        }
        observed = await receive(observer);
      }

      expect(executor.calls).assertEqual(0);
      expect(dataResults).assertEqual(0);
      agent.stop();
      observer.close();
    });

    it('suppresses a detached executor completion after stop', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: SingleControlledDataExecutor = new SingleControlledDataExecutor();
      const agent: DataAgent = new DataAgent(bus, allowDataTask, executor);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(dataTaskMessage('conversation-stop', 'turn-stop', 'data-stop'));
      await executor.started.promise;
      agent.stop();
      executor.complete(hotelDataResult('success'));
      await settle();
      bus.publish(message(AgentMessageType.ACTION_RUN, 'marker', 'marker', 'marker'));

      expect((await receiveType(observer, AgentMessageType.ACTION_RUN)).taskId).assertEqual('marker');
      observer.close();
    });

    it('does not let an old stopped agent publish into a restarted bus lifecycle', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const oldExecutor: SingleControlledDataExecutor = new SingleControlledDataExecutor();
      const oldAgent: DataAgent = new DataAgent(bus, allowDataTask, oldExecutor);
      const observer: AgentMessageReader = bus.openReader();
      oldAgent.start();

      bus.publish(dataTaskMessage('conversation-old', 'turn-old', 'data-old'));
      await oldExecutor.started.promise;
      oldAgent.stop();
      const newAgent: DataAgent = new DataAgent(
        bus,
        allowDataTask,
        new ScriptedDataExecutor(hotelDataResult('success'))
      );
      newAgent.start();
      bus.publish(dataTaskMessage('conversation-new', 'turn-new', 'data-new'));
      const currentResult: AgentMessage = await receiveType(observer, AgentMessageType.TASK_RESULT_DATA);
      expect(currentResult.taskId).assertEqual('data-new');
      oldExecutor.complete(hotelDataResult('success'));
      await settle();
      bus.publish(message(AgentMessageType.ACTION_RUN, 'marker', 'marker', 'marker'));

      expect((await receive(observer)).type).assertEqual(AgentMessageType.ACTION_RUN);
      newAgent.stop();
      observer.close();
    });

    it('rejects malformed Data tasks and keeps the pump available', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: ScriptedDataExecutor = new ScriptedDataExecutor(hotelDataResult('success'));
      const agent: DataAgent = new DataAgent(bus, allowDataTask, executor);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish({
        type: AgentMessageType.TASK_CREATE_DATA,
        conversationId: 'conversation-invalid',
        turnId: 'turn-invalid',
        taskId: 'data-invalid',
        payload: JSON.parse('null') as Object
      });
      const invalid: AgentMessage = await receiveType(observer, AgentMessageType.TASK_ERROR);
      expect(invalid.taskId).assertEqual('data-invalid');
      expect((invalid.payload as TaskErrorPayload).code).assertEqual('DATA_TASK_INVALID');
      bus.publish(dataTaskMessage('conversation-valid', 'turn-valid', 'data-valid'));
      const valid: AgentMessage = await receiveType(observer, AgentMessageType.TASK_RESULT_DATA);

      expect(valid.taskId).assertEqual('data-valid');
      expect(executor.calls).assertEqual(1);
      agent.stop();
      observer.close();
    });

    it('does not call the executor when the exact Data task is not authorized', 0, async () => {
      const bus = new LinkedMessageBus();
      const executor = new ScriptedDataExecutor(hotelDataResult('success'));
      const agent = new DataAgent(bus, denyDataTask, executor);
      const observer = bus.openReader();
      agent.start();

      bus.publish(dataTaskMessage('conversation-denied', 'turn-denied', 'data-denied'));
      const denied = await receiveType(observer, AgentMessageType.TASK_ERROR);
      const error = denied.payload as TaskErrorPayload;

      expect(error.code).assertEqual('DATA_TASK_READ_ONLY_REQUIRED');
      expect(executor.calls).assertEqual(0);
      agent.stop();
      observer.close();
    });
  });
}
