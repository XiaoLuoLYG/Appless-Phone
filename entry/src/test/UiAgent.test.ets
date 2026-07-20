import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  CreateUiTaskPayload,
  DataResult,
  DataSource,
  LinkedMessageBus,
  TaskErrorPayload,
  UiAgent,
  UiRenderResultPayload,
  UiSurfaceWriter,
  UiTaskRenderer
} from '@loop/agent-core';

interface HotelResult {
  hotelId: number;
  name: string;
}

interface SurfaceWrite {
  turnId: string;
  surfaceId: string;
  jsonl: string;
}

interface ActionStatusPayload {
  surfaceId: string;
  runId: string;
  status: string;
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

class RecordingRenderer implements UiTaskRenderer {
  readonly calls: string[] = [];
  readonly resultHotelIds: number[] = [];

  async skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<string> {
    this.calls.push(`skeleton:${task.taskId}:${surfaceId}`);
    return `skeleton:${task.taskId}`;
  }

  async result(task: CreateUiTaskPayload, data: DataResult, surfaceId: string): Promise<string> {
    const hotel: HotelResult = data.data as HotelResult;
    this.calls.push(`result:${task.taskId}:${surfaceId}`);
    this.resultHotelIds.push(hotel.hotelId);
    return `result:${hotel.hotelId}`;
  }

  async error(task: CreateUiTaskPayload, message: string, surfaceId: string): Promise<string> {
    this.calls.push(`error:${task.taskId}:${surfaceId}`);
    return `error:${message}`;
  }

  async actionStatus(payload: Object, surfaceId: string): Promise<string> {
    const status: ActionStatusPayload = payload as ActionStatusPayload;
    this.calls.push(`action:${status.runId}:${surfaceId}`);
    return `action:${status.status}`;
  }
}

class RecordingSurfaceWriter implements UiSurfaceWriter {
  readonly writes: SurfaceWrite[] = [];

  async write(turnId: string, surfaceId: string, jsonl: string): Promise<void> {
    this.writes.push({ turnId, surfaceId, jsonl });
  }
}

class DeferredSkeletonRenderer implements UiTaskRenderer {
  readonly started: TestGate = new TestGate();
  surfaceId: string = '';
  private resolveSkeleton: ((jsonl: string) => void) | null = null;

  async skeleton(_task: CreateUiTaskPayload, surfaceId: string): Promise<string> {
    this.surfaceId = surfaceId;
    this.started.open();
    return new Promise<string>((resolve: (jsonl: string) => void) => {
      this.resolveSkeleton = resolve;
    });
  }

  async result(_task: CreateUiTaskPayload, _data: DataResult, _surfaceId: string): Promise<string> {
    return 'result';
  }

  async error(_task: CreateUiTaskPayload, message: string, _surfaceId: string): Promise<string> {
    return `error:${message}`;
  }

  async actionStatus(_payload: Object, _surfaceId: string): Promise<string> {
    return 'action';
  }

  finish(): void {
    const resolve: ((jsonl: string) => void) | null = this.resolveSkeleton;
    this.resolveSkeleton = null;
    if (resolve !== null) {
      resolve('deferred-skeleton');
    }
  }
}

class RejectOnceRenderer extends RecordingRenderer {
  private rejectNext: boolean = true;

  async skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<string> {
    if (this.rejectNext) {
      this.rejectNext = false;
      throw new Error('renderer rejected');
    }
    return super.skeleton(task, surfaceId);
  }
}

function uiTaskMessage(
  conversationId: string = 'conversation-a',
  turnId: string = 'turn-1',
  taskId: string = 'ui-1',
  dataTaskId: string = 'data-1',
  expectedOutputSchema: string = 'hotelSearchResults'
): AgentMessage {
  const payload: CreateUiTaskPayload = {
    taskId,
    intent: 'Show hotel results',
    expectedOutputSchema,
    dataTaskId
  };
  return {
    type: AgentMessageType.TASK_CREATE_UI,
    conversationId,
    turnId,
    taskId,
    payload
  };
}

function hotelDataResult(hotelId: number): DataResult {
  const source: DataSource = {
    provider: 'rollinggo',
    backend: 'oauth_api',
    operation: 'searchHotels',
    fetchedAt: '2026-07-20T02:00:00.000Z'
  };
  const hotel: HotelResult = {
    hotelId,
    name: `Hotel ${hotelId}`
  };
  return {
    toolId: 'hotel.search',
    outputSchema: 'hotelSearchResults',
    status: 'success',
    sources: [source],
    data: hotel,
    warnings: []
  };
}

function dataResultMessage(
  conversationId: string,
  turnId: string,
  taskId: string,
  hotelId: number,
  outputSchema: string = 'hotelSearchResults'
): AgentMessage {
  const result: DataResult = hotelDataResult(hotelId);
  result.outputSchema = outputSchema;
  return {
    type: AgentMessageType.TASK_RESULT_DATA,
    conversationId,
    turnId,
    taskId,
    payload: result
  };
}

function turnMessage(
  type: AgentMessageType,
  conversationId: string,
  turnId: string,
  taskId: string,
  payload: Object = new Object()
): AgentMessage {
  return {
    type,
    conversationId,
    turnId,
    taskId,
    payload
  };
}

function actionPayload(surfaceId: string, runId: string, status: string): ActionStatusPayload {
  return { surfaceId, runId, status };
}

async function receive(reader: AgentMessageReader): Promise<AgentMessage> {
  const received: AgentMessage | null = await reader.receive();
  if (received === null) {
    throw new Error('observer closed before receiving a message');
  }
  return received;
}

async function receiveUiState(reader: AgentMessageReader, state: string): Promise<AgentMessage> {
  while (true) {
    const received: AgentMessage = await receive(reader);
    if (received.type === AgentMessageType.TASK_RESULT_UI &&
      (received.payload as UiRenderResultPayload).state === state) {
      return received;
    }
  }
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

export default function uiAgentTest() {
  describe('uiAgent', () => {
    it('writes a skeleton then patches the same surface when UI arrives first', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage());
      const skeletonMessage: AgentMessage = await receiveUiState(observer, 'skeleton');
      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-1', 101));
      const resultMessage: AgentMessage = await receiveUiState(observer, 'result');
      const skeleton: UiRenderResultPayload = skeletonMessage.payload as UiRenderResultPayload;
      const result: UiRenderResultPayload = resultMessage.payload as UiRenderResultPayload;

      expect(writer.writes.length).assertEqual(2);
      expect(writer.writes[0].jsonl).assertEqual('skeleton:ui-1');
      expect(writer.writes[1].jsonl).assertEqual('result:101');
      expect(writer.writes[0].surfaceId).assertEqual(writer.writes[1].surfaceId);
      expect(skeleton.surfaceId).assertEqual(result.surfaceId);
      expect(skeletonMessage.taskId).assertEqual('ui-1');
      expect(resultMessage.taskId).assertEqual('ui-1');

      agent.stop();
      observer.close();
    });

    it('caches Data first then writes skeleton and result once on one surface', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-1', 202));
      bus.publish(uiTaskMessage());
      await receiveUiState(observer, 'skeleton');
      await receiveUiState(observer, 'result');
      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-1', 202));
      bus.publish(turnMessage(
        AgentMessageType.ACTION_PROGRESS,
        'conversation-a',
        'turn-1',
        'action-1',
        actionPayload(writer.writes[0].surfaceId, 'run-1', 'running')
      ));
      await receiveUiState(observer, 'action');

      expect(writer.writes.length).assertEqual(3);
      expect(writer.writes[0].jsonl).assertEqual('skeleton:ui-1');
      expect(writer.writes[1].jsonl).assertEqual('result:202');
      expect(writer.writes[0].surfaceId).assertEqual(writer.writes[1].surfaceId);
      expect(renderer.resultHotelIds.join(',')).assertEqual('202');

      agent.stop();
      observer.close();
    });

    it('does not share pending Data between two turns in one conversation', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-1', 301));
      bus.publish(uiTaskMessage('conversation-a', 'turn-2', 'ui-2', 'data-2'));
      await receiveUiState(observer, 'skeleton');
      expect(renderer.resultHotelIds.length).assertEqual(0);
      bus.publish(dataResultMessage('conversation-a', 'turn-2', 'data-2', 302));
      await receiveUiState(observer, 'result');

      expect(renderer.resultHotelIds.join(',')).assertEqual('302');
      expect(writer.writes[0].turnId).assertEqual('turn-2');
      expect(writer.writes[1].turnId).assertEqual('turn-2');

      agent.stop();
      observer.close();
    });

    it('accepts only the expected Data task and owned Data error', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();
      const wrongError: TaskErrorPayload = {
        code: 'DATA_TASK_FAILED',
        message: 'wrong task must not render'
      };

      bus.publish(uiTaskMessage());
      await receiveUiState(observer, 'skeleton');
      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-wrong', 901));
      bus.publish(turnMessage(AgentMessageType.TASK_ERROR, 'conversation-a', 'turn-1', 'data-wrong', wrongError));
      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-1', 902));
      await receiveUiState(observer, 'result');

      expect(renderer.resultHotelIds.join(',')).assertEqual('902');
      expect(renderer.calls.filter((call: string): boolean => call.startsWith('error:')).length).assertEqual(0);
      agent.stop();
      observer.close();
    });

    it('discards a wrong Data-first task when the owning UI task arrives', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-wrong', 911));
      bus.publish(uiTaskMessage());
      await receiveUiState(observer, 'skeleton');
      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-1', 912));
      await receiveUiState(observer, 'result');

      expect(renderer.resultHotelIds.join(',')).assertEqual('912');
      agent.stop();
      observer.close();
    });

    it('rejects an owned Data result whose output schema does not match', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage());
      await receiveUiState(observer, 'skeleton');
      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-1', 921, 'wrongSchema'));
      const errorMessage: AgentMessage = await receiveType(observer, AgentMessageType.TASK_ERROR);

      expect(errorMessage.taskId).assertEqual('data-1');
      expect((errorMessage.payload as TaskErrorPayload).code).assertEqual('UI_DATA_SCHEMA_MISMATCH');
      expect(renderer.resultHotelIds.length).assertEqual(0);
      agent.stop();
      observer.close();
    });

    it('uses distinct surfaces for two conversations with the same turn id', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage('conversation-a', 'same-turn', 'ui-a'));
      await receiveUiState(observer, 'skeleton');
      bus.publish(uiTaskMessage('conversation-b', 'same-turn', 'ui-b'));
      await receiveUiState(observer, 'skeleton');

      expect(writer.writes.length).assertEqual(2);
      expect(writer.writes[0].surfaceId === writer.writes[1].surfaceId).assertFalse();

      agent.stop();
      observer.close();
    });

    it('drops canceled and replaced turn context so late Data cannot write a surface', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage('conversation-a', 'turn-old', 'ui-old'));
      await receiveUiState(observer, 'skeleton');
      const oldSurface: string = writer.writes[0].surfaceId;
      agent.surfaceReplaced('conversation-a', 'turn-old', oldSurface);
      bus.publish(dataResultMessage('conversation-a', 'turn-old', 'data-old', 401));
      bus.publish(uiTaskMessage('conversation-a', 'turn-cancel', 'ui-cancel'));
      await receiveUiState(observer, 'skeleton');
      bus.publish(turnMessage(AgentMessageType.TURN_CANCEL, 'conversation-a', 'turn-cancel', 'cancel-1'));
      bus.publish(dataResultMessage('conversation-a', 'turn-cancel', 'data-cancel', 402));
      await settle();
      bus.publish(turnMessage(AgentMessageType.INPUT_USER, 'marker', 'marker', 'marker'));
      while ((await receive(observer)).type !== AgentMessageType.INPUT_USER) {
      }

      expect(writer.writes.length).assertEqual(2);
      expect(renderer.resultHotelIds.length).assertEqual(0);

      agent.stop();
      observer.close();
    });

    it('revalidates replacement while skeleton rendering is pending', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: DeferredSkeletonRenderer = new DeferredSkeletonRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage());
      await renderer.started.promise;
      agent.surfaceReplaced('conversation-a', 'turn-1', renderer.surfaceId);
      renderer.finish();
      await settle();
      bus.publish(turnMessage(AgentMessageType.INPUT_USER, 'marker', 'marker', 'marker'));
      let uiResults: number = 0;
      let observed: AgentMessage = await receive(observer);
      while (observed.type !== AgentMessageType.INPUT_USER) {
        if (observed.type === AgentMessageType.TASK_RESULT_UI) {
          uiResults++;
        }
        observed = await receive(observer);
      }

      expect(writer.writes.length).assertEqual(0);
      expect(uiResults).assertEqual(0);
      agent.stop();
      observer.close();
    });

    it('processes cancellation while skeleton rendering is pending', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: DeferredSkeletonRenderer = new DeferredSkeletonRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage());
      await renderer.started.promise;
      bus.publish(turnMessage(AgentMessageType.TURN_CANCEL, 'conversation-a', 'turn-1', 'cancel-1'));
      await settle();
      renderer.finish();
      await settle();
      bus.publish(turnMessage(AgentMessageType.INPUT_USER, 'marker', 'marker', 'marker'));
      let uiResults: number = 0;
      let observed: AgentMessage = await receive(observer);
      while (observed.type !== AgentMessageType.INPUT_USER) {
        if (observed.type === AgentMessageType.TASK_RESULT_UI) {
          uiResults++;
        }
        observed = await receive(observer);
      }

      expect(writer.writes.length).assertEqual(0);
      expect(uiResults).assertEqual(0);
      agent.stop();
      observer.close();
    });

    it('keeps an owned Data error behind a pending skeleton write', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: DeferredSkeletonRenderer = new DeferredSkeletonRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      const error: TaskErrorPayload = {
        code: 'DATA_TASK_FAILED',
        message: 'provider unavailable'
      };
      agent.start();

      bus.publish(uiTaskMessage());
      await renderer.started.promise;
      bus.publish(turnMessage(AgentMessageType.TASK_ERROR, 'conversation-a', 'turn-1', 'data-1', error));
      await settle();
      expect(writer.writes.length).assertEqual(0);
      renderer.finish();
      await receiveUiState(observer, 'skeleton');
      await receiveUiState(observer, 'error');

      expect(writer.writes.map((write: SurfaceWrite): string => write.jsonl).join(','))
        .assertEqual('deferred-skeleton,error:provider unavailable');
      agent.stop();
      observer.close();
    });

    it('bounds terminal tombstones with deterministic FIFO eviction', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      for (let index = 0; index < 129; index++) {
        bus.publish(turnMessage(
          AgentMessageType.TURN_CANCEL,
          'conversation-cap',
          `turn-${index}`,
          `cancel-${index}`
        ));
      }
      bus.publish(uiTaskMessage('conversation-cap', 'turn-0', 'ui-oldest', 'data-oldest'));
      bus.publish(uiTaskMessage('conversation-cap', 'turn-128', 'ui-newest', 'data-newest'));
      bus.publish(uiTaskMessage('conversation-live', 'turn-live', 'ui-live', 'data-live'));
      await receiveUiState(observer, 'skeleton');
      await receiveUiState(observer, 'skeleton');

      expect(writer.writes.length).assertEqual(2);
      expect(writer.writes.map((write: SurfaceWrite): string => write.turnId).join(','))
        .assertEqual('turn-0,turn-live');
      agent.stop();
      observer.close();
    });

    it('applies Action status only to the exact conversation turn and surface', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage('conversation-a', 'same-turn', 'ui-a'));
      await receiveUiState(observer, 'skeleton');
      bus.publish(uiTaskMessage('conversation-b', 'same-turn', 'ui-b'));
      await receiveUiState(observer, 'skeleton');
      const surfaceA: string = writer.writes[0].surfaceId;
      const surfaceB: string = writer.writes[1].surfaceId;

      bus.publish(turnMessage(
        AgentMessageType.ACTION_PROGRESS,
        'conversation-a',
        'same-turn',
        'action-wrong-surface',
        actionPayload(surfaceB, 'run-wrong-surface', 'running')
      ));
      bus.publish(turnMessage(
        AgentMessageType.ACTION_RESULT,
        'conversation-b',
        'other-turn',
        'action-wrong-turn',
        actionPayload(surfaceB, 'run-wrong-turn', 'success')
      ));
      bus.publish(turnMessage(
        AgentMessageType.ACTION_RESULT,
        'conversation-b',
        'same-turn',
        'action-exact',
        actionPayload(surfaceB, 'run-exact', 'success')
      ));
      const actionMessage: AgentMessage = await receiveUiState(observer, 'action');
      const actionResult: UiRenderResultPayload = actionMessage.payload as UiRenderResultPayload;

      expect(writer.writes.length).assertEqual(3);
      expect(writer.writes[2].surfaceId).assertEqual(surfaceB);
      expect(writer.writes[2].surfaceId === surfaceA).assertFalse();
      expect(renderer.calls.filter((call: string): boolean => call.startsWith('action:')).length).assertEqual(1);
      expect(actionResult.surfaceId).assertEqual(surfaceB);

      agent.stop();
      observer.close();
    });

    it('renders a correlated Data error through the only surface writer', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();
      const error: TaskErrorPayload = {
        code: 'DATA_TASK_FAILED',
        message: 'provider unavailable'
      };

      bus.publish(uiTaskMessage());
      await receiveUiState(observer, 'skeleton');
      bus.publish(turnMessage(AgentMessageType.TASK_ERROR, 'conversation-a', 'turn-1', 'data-1', error));
      await receiveUiState(observer, 'error');

      expect(writer.writes.length).assertEqual(2);
      expect(writer.writes[1].jsonl).assertEqual('error:provider unavailable');
      expect(writer.writes[0].surfaceId).assertEqual(writer.writes[1].surfaceId);

      agent.stop();
      observer.close();
    });

    it('contains malformed payloads and survives a rejecting renderer', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RejectOnceRenderer = new RejectOnceRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(turnMessage(
        AgentMessageType.TASK_CREATE_UI,
        'conversation-invalid',
        'turn-invalid',
        'ui-invalid',
        JSON.parse('null') as Object
      ));
      const invalidUi: AgentMessage = await receiveType(observer, AgentMessageType.TASK_ERROR);
      expect((invalidUi.payload as TaskErrorPayload).code).assertEqual('UI_TASK_INVALID');

      bus.publish(uiTaskMessage('conversation-reject', 'turn-reject', 'ui-reject', 'data-reject'));
      const renderError: AgentMessage = await receiveType(observer, AgentMessageType.TASK_ERROR);
      expect((renderError.payload as TaskErrorPayload).code).assertEqual('UI_RENDER_FAILED');

      bus.publish(uiTaskMessage('conversation-live', 'turn-live', 'ui-live', 'data-live'));
      await receiveUiState(observer, 'skeleton');
      bus.publish(turnMessage(
        AgentMessageType.ACTION_PROGRESS,
        'conversation-live',
        'turn-live',
        'action-malformed',
        JSON.parse('null') as Object
      ));
      bus.publish(turnMessage(
        AgentMessageType.TASK_RESULT_DATA,
        'conversation-live',
        'turn-live',
        'data-live',
        JSON.parse('null') as Object
      ));
      const invalidData: AgentMessage = await receiveType(observer, AgentMessageType.TASK_ERROR);
      expect((invalidData.payload as TaskErrorPayload).code).assertEqual('UI_DATA_INVALID');
      await receiveUiState(observer, 'error');

      bus.publish(uiTaskMessage('conversation-next', 'turn-next', 'ui-next', 'data-next'));
      await receiveUiState(observer, 'skeleton');
      bus.publish(dataResultMessage('conversation-next', 'turn-next', 'data-next', 931));
      await receiveUiState(observer, 'result');

      expect(renderer.resultHotelIds.join(',')).assertEqual('931');
      expect(writer.writes.length).assertEqual(4);
      agent.stop();
      observer.close();
    });
  });
}
