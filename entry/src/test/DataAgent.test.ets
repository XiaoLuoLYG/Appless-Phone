import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  CreateDataTaskPayload,
  DataAgent,
  DataResult,
  DataSource,
  DataTaskExecutor,
  LinkedMessageBus,
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

class ThrowingDataExecutor implements DataTaskExecutor {
  calls: number = 0;

  async execute(_task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls++;
    throw new Error('provider unavailable');
  }
}

class ControlledDataExecutor implements DataTaskExecutor {
  readonly started: TestGate = new TestGate();
  private resolveResult: ((result: DataResult) => void) | null = null;
  private rejectResult: ((error: Error) => void) | null = null;

  async execute(_task: CreateDataTaskPayload): Promise<DataResult> {
    return new Promise<DataResult>((
      resolve: (result: DataResult) => void,
      reject: (error: Error) => void
    ) => {
      this.resolveResult = resolve;
      this.rejectResult = reject;
      this.started.open();
    });
  }

  complete(result: DataResult): void {
    const resolve: ((result: DataResult) => void) | null = this.resolveResult;
    this.resolveResult = null;
    this.rejectResult = null;
    if (resolve !== null) {
      resolve(result);
    }
  }

  fail(error: Error): void {
    const reject: ((error: Error) => void) | null = this.rejectResult;
    this.resolveResult = null;
    this.rejectResult = null;
    if (reject !== null) {
      reject(error);
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
    warnings: ['Google Places phone enrichment unavailable']
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
    toolId: 'hotel.search',
    outputSchema: 'hotelSearchResults',
    args
  };
  return {
    type: AgentMessageType.TASK_CREATE_DATA,
    conversationId,
    turnId,
    taskId,
    payload
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
    it('accepts only Data tasks and preserves the full structured result with correlation', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: ScriptedDataExecutor = new ScriptedDataExecutor(hotelDataResult());
      const agent: DataAgent = new DataAgent(bus, executor);
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
      expect(result.warnings[0]).assertEqual('Google Places phone enrichment unavailable');
      expect(hotel.hotelId).assertEqual(987654);
      expect(hotel.ratePlanId).assertEqual('rate-plan-real-42');
      expect(Object.keys(result.data).sort().join(',')).assertEqual('hotelId,name,ratePlanId');

      agent.stop();
      observer.close();
    });

    it('publishes a correlated Data task error without retrying', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: ThrowingDataExecutor = new ThrowingDataExecutor();
      const agent: DataAgent = new DataAgent(bus, executor);
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

    it('suppresses a result that completes after matching turn cancellation', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: ControlledDataExecutor = new ControlledDataExecutor();
      const agent: DataAgent = new DataAgent(bus, executor);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(dataTaskMessage());
      await executor.started.promise;
      bus.publish(message(AgentMessageType.TURN_CANCEL, 'conversation-other', 'turn-1', 'cancel-other'));
      bus.publish(message(AgentMessageType.TURN_CANCEL, 'conversation-hotel', 'turn-1', 'cancel-1'));
      expect((await receiveType(observer, AgentMessageType.TURN_CANCEL)).conversationId).assertEqual('conversation-other');
      expect((await receiveType(observer, AgentMessageType.TURN_CANCEL)).conversationId).assertEqual('conversation-hotel');
      executor.complete(hotelDataResult('success'));
      await settle();
      bus.publish(message(AgentMessageType.ACTION_RUN, 'marker', 'marker', 'marker'));

      expect((await receive(observer)).type).assertEqual(AgentMessageType.ACTION_RUN);
      agent.stop();
      observer.close();
    });

    it('suppresses an executor error that arrives after cancellation', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const executor: ControlledDataExecutor = new ControlledDataExecutor();
      const agent: DataAgent = new DataAgent(bus, executor);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(dataTaskMessage());
      await executor.started.promise;
      bus.publish(message(AgentMessageType.TURN_CANCEL, 'conversation-hotel', 'turn-1', 'cancel-1'));
      await receiveType(observer, AgentMessageType.TURN_CANCEL);
      executor.fail(new Error('late provider error'));
      await settle();
      bus.publish(message(AgentMessageType.ACTION_RUN, 'marker', 'marker', 'marker'));

      expect((await receive(observer)).type).assertEqual(AgentMessageType.ACTION_RUN);
      agent.stop();
      observer.close();
    });
  });
}
