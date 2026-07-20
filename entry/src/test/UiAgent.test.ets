import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  ActionPlan,
  ActionPlanCreatePayload,
  ActionPlanReadyPayload,
  ActionResultPayload,
  CreateUiTaskPayload,
  DataResult,
  DataSource,
  LinkedMessageBus,
  TaskErrorPayload,
  UiAgent,
  UiRenderResult,
  UiRenderResultPayload,
  UiSurfaceWriteLease,
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

  async skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult> {
    this.calls.push(`skeleton:${task.taskId}:${surfaceId}`);
    return render(`skeleton:${task.taskId}`);
  }

  async result(
    task: CreateUiTaskPayload,
    data: DataResult,
    surfaceId: string
  ): Promise<UiRenderResult> {
    const hotel: HotelResult = data.data as HotelResult;
    this.calls.push(`result:${task.taskId}:${surfaceId}`);
    this.resultHotelIds.push(hotel.hotelId);
    return render(`result:${hotel.hotelId}`);
  }

  async error(
    task: CreateUiTaskPayload,
    message: string,
    surfaceId: string
  ): Promise<UiRenderResult> {
    this.calls.push(`error:${task.taskId}:${surfaceId}`);
    return render(`error:${message}`);
  }

  async actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult> {
    const status: ActionStatusPayload = payload as ActionStatusPayload;
    this.calls.push(`action:${status.runId}:${surfaceId}`);
    return render(`action:${status.status}`);
  }
}

class ProposalRenderer extends RecordingRenderer {
  proposalSurfaceId: string = '';
  readyKeys: string = '';
  readyLabel: string = '';

  async result(
    task: CreateUiTaskPayload,
    data: DataResult,
    surfaceId: string
  ): Promise<UiRenderResult> {
    const base = await super.result(task, data, surfaceId);
    this.proposalSurfaceId = surfaceId;
    const proposal: ActionPlan = JSON.parse(
      '{"planId":"plan-ui-1","turnId":"turn-1","surfaceId":"' + surfaceId + '",' +
        '"label":"Open detail and navigate","steps":[' +
        '{"stepId":"detail","actionId":"hotel.detail","args":{"hotelId":101}},' +
        '{"stepId":"navigate","actionId":"hotel.navigate","args":{},' +
        '"inputFrom":[{"target":"/latitude","stepId":"detail","path":"/latitude"}]}]}'
    ) as ActionPlan;
    return {
      jsonl: base.jsonl,
      proposals: [proposal]
    };
  }

  async actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult> {
    const ready = payload as ActionPlanReadyPayload;
    this.readyKeys = Object.keys(payload).sort().join(',');
    this.readyLabel = ready.label;
    this.calls.push(`ready:${ready.runId}:${surfaceId}`);
    return {
      jsonl: `{"workflow":{"name":"${ready.actionId}",` +
        `"args":${JSON.stringify(ready.args)}}}`,
      proposals: []
    };
  }
}

class EarlyWorkflowRenderer extends ProposalRenderer {
  async result(
    task: CreateUiTaskPayload,
    data: DataResult,
    surfaceId: string
  ): Promise<UiRenderResult> {
    const proposed = await super.result(task, data, surfaceId);
    proposed.jsonl =
      '{"surfaceUpdate":{"actions":[{"name":"workflow.run","args":{"planId":"early"}}]}}';
    return proposed;
  }
}

class JsonlProbeRenderer extends RecordingRenderer {
  skeletonJsonl: string = JSON.stringify('safe-skeleton');
  resultJsonl: string = JSON.stringify('safe-result');
  errorJsonl: string = JSON.stringify('safe-error');
  actionJsonl: string = JSON.stringify('safe-action');

  async skeleton(
    task: CreateUiTaskPayload,
    surfaceId: string
  ): Promise<UiRenderResult> {
    const rendered = await super.skeleton(task, surfaceId);
    rendered.jsonl = this.skeletonJsonl;
    return rendered;
  }

  async result(
    task: CreateUiTaskPayload,
    data: DataResult,
    surfaceId: string
  ): Promise<UiRenderResult> {
    const rendered = await super.result(task, data, surfaceId);
    rendered.jsonl = this.resultJsonl;
    return rendered;
  }

  async error(
    task: CreateUiTaskPayload,
    message: string,
    surfaceId: string
  ): Promise<UiRenderResult> {
    const rendered = await super.error(task, message, surfaceId);
    rendered.jsonl = this.errorJsonl;
    return rendered;
  }

  async actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult> {
    const rendered = await super.actionStatus(payload, surfaceId);
    rendered.jsonl = this.actionJsonl;
    return rendered;
  }
}

class ManyProposalRenderer extends RecordingRenderer {
  private readonly proposalCount: number;

  constructor(proposalCount: number) {
    super();
    this.proposalCount = proposalCount;
  }

  async result(
    task: CreateUiTaskPayload,
    data: DataResult,
    surfaceId: string
  ): Promise<UiRenderResult> {
    const rendered = await super.result(task, data, surfaceId);
    const proposals: ActionPlan[] = [];
    for (let index = 0; index < this.proposalCount; index++) {
      proposals.push(JSON.parse(
        `{"planId":"plan-cap-${index}","turnId":"turn-1",` +
          `"surfaceId":"${surfaceId}","label":"Proposal ${index}",` +
          '"steps":[{"stepId":"detail","actionId":"hotel.detail",' +
          '"args":{"hotelId":101}}]}'
      ) as ActionPlan);
    }
    rendered.proposals = proposals;
    return rendered;
  }
}

class RecordingSurfaceWriter implements UiSurfaceWriter {
  readonly writes: SurfaceWrite[] = [];

  async write(
    turnId: string,
    surfaceId: string,
    jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void> {
    if (lease.isActive()) {
      this.writes.push({ turnId, surfaceId, jsonl });
    }
  }
}

class DeferredSurfaceWriter implements UiSurfaceWriter {
  readonly writes: SurfaceWrite[] = [];
  readonly started: TestGate = new TestGate();
  turnId: string = '';
  surfaceId: string = '';
  private releaseWrite: TestGate = new TestGate();

  async write(
    turnId: string,
    surfaceId: string,
    jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void> {
    this.turnId = turnId;
    this.surfaceId = surfaceId;
    this.started.open();
    await this.releaseWrite.promise;
    if (lease.isActive()) {
      this.writes.push({ turnId, surfaceId, jsonl });
    }
  }

  release(): void {
    this.releaseWrite.open();
  }
}

class DeferredSkeletonRenderer implements UiTaskRenderer {
  readonly started: TestGate = new TestGate();
  surfaceId: string = '';
  private resolveSkeleton: ((jsonl: string) => void) | null = null;

  async skeleton(_task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult> {
    this.surfaceId = surfaceId;
    this.started.open();
    return new Promise<UiRenderResult>((resolve: (result: UiRenderResult) => void) => {
      this.resolveSkeleton = (jsonl: string): void => {
        resolve(render(jsonl));
      };
    });
  }

  async result(
    _task: CreateUiTaskPayload,
    _data: DataResult,
    _surfaceId: string
  ): Promise<UiRenderResult> {
    return render('result');
  }

  async error(
    _task: CreateUiTaskPayload,
    message: string,
    _surfaceId: string
  ): Promise<UiRenderResult> {
    return render(`error:${message}`);
  }

  async actionStatus(_payload: Object, _surfaceId: string): Promise<UiRenderResult> {
    return render('action');
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

  async skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult> {
    if (this.rejectNext) {
      this.rejectNext = false;
      throw new Error('renderer rejected');
    }
    return super.skeleton(task, surfaceId);
  }
}

class SlowProgressRenderer extends RecordingRenderer {
  readonly progressStarted: TestGate = new TestGate();
  private releaseProgress: TestGate = new TestGate();

  async actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult> {
    const status: ActionStatusPayload = payload as ActionStatusPayload;
    this.calls.push(`action:${status.runId}:${surfaceId}`);
    if (status.status === 'running') {
      this.progressStarted.open();
      await this.releaseProgress.promise;
    }
    return render(`action:${status.status}`);
  }

  finishProgress(): void {
    this.releaseProgress.open();
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

function render(jsonl: string): UiRenderResult {
  return {
    jsonl: JSON.stringify(jsonl),
    proposals: []
  };
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

async function receiveTaskErrorCode(
  reader: AgentMessageReader,
  code: string
): Promise<AgentMessage> {
  while (true) {
    const received = await receive(reader);
    if (received.type === AgentMessageType.TASK_ERROR &&
      (received.payload as TaskErrorPayload).code === code) {
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
      expect(writer.writes[0].jsonl).assertEqual(JSON.stringify('skeleton:ui-1'));
      expect(writer.writes[1].jsonl).assertEqual(JSON.stringify('result:101'));
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
      expect(writer.writes[0].jsonl).assertEqual(JSON.stringify('skeleton:ui-1'));
      expect(writer.writes[1].jsonl).assertEqual(JSON.stringify('result:202'));
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

    it('selects owned Data when wrong-first and owned-later both arrive before UI', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-wrong', 911));
      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-1', 912));
      bus.publish(uiTaskMessage());
      await receiveUiState(observer, 'skeleton');
      await receiveUiState(observer, 'result');

      expect(renderer.resultHotelIds.join(',')).assertEqual('912');
      agent.stop();
      observer.close();
    });

    it('preserves owned Data when a later wrong malformed result arrives before UI', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-1', 913));
      bus.publish(turnMessage(
        AgentMessageType.TASK_RESULT_DATA,
        'conversation-a',
        'turn-1',
        'data-wrong',
        JSON.parse('null') as Object
      ));
      bus.publish(uiTaskMessage());
      await receiveUiState(observer, 'skeleton');
      await receiveUiState(observer, 'result');

      expect(renderer.resultHotelIds.join(',')).assertEqual('913');
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
        .assertEqual(
          `${JSON.stringify('deferred-skeleton')},` +
            `${JSON.stringify('error:provider unavailable')}`
        );
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

    it('publishes composite proposals and renders only the exact ready workflow identity', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: ProposalRenderer = new ProposalRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage());
      await receiveUiState(observer, 'skeleton');
      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-1', 101));
      const createMessage = await receiveType(observer, AgentMessageType.ACTION_PLAN_CREATE);
      const create = createMessage.payload as ActionPlanCreatePayload;

      expect(writer.writes.length).assertEqual(2);
      expect(writer.writes[1].jsonl).assertEqual(JSON.stringify('result:101'));
      expect(create.sourceToolId).assertEqual('hotel.search');
      expect(create.plan.planId).assertEqual('plan-ui-1');
      expect(create.plan.surfaceId).assertEqual(renderer.proposalSurfaceId);

      const ready: ActionPlanReadyPayload = {
        surfaceId: create.plan.surfaceId,
        planId: create.plan.planId,
        runId: create.runId,
        label: create.plan.label,
        actionId: 'workflow.run',
        args: {
          planId: create.plan.planId,
          runId: create.runId
        }
      };
      bus.publish(turnMessage(
        AgentMessageType.ACTION_PLAN_READY,
        'conversation-a',
        'turn-wrong',
        createMessage.taskId,
        ready
      ));
      const wrongSurface: ActionPlanReadyPayload = {
        surfaceId: 'surface-wrong',
        planId: ready.planId,
        runId: ready.runId,
        label: ready.label,
        actionId: ready.actionId,
        args: ready.args
      };
      bus.publish(turnMessage(
        AgentMessageType.ACTION_PLAN_READY,
        'conversation-a',
        'turn-1',
        createMessage.taskId,
        wrongSurface
      ));
      const wrongLabel: ActionPlanReadyPayload = {
        surfaceId: ready.surfaceId,
        planId: ready.planId,
        runId: ready.runId,
        label: 'Tampered workflow label',
        actionId: ready.actionId,
        args: ready.args
      };
      bus.publish(turnMessage(
        AgentMessageType.ACTION_PLAN_READY,
        'conversation-a',
        'turn-1',
        createMessage.taskId,
        wrongLabel
      ));
      const extraReady = JSON.parse(JSON.stringify(ready)) as Object;
      const extraRecord =
        extraReady as Record<string, Object | string | number | boolean | null | undefined>;
      extraRecord['extra'] = 'must be rejected';
      bus.publish(turnMessage(
        AgentMessageType.ACTION_PLAN_READY,
        'conversation-a',
        'turn-1',
        createMessage.taskId,
        extraReady
      ));
      await settle();
      expect(writer.writes.length).assertEqual(2);

      bus.publish(turnMessage(
        AgentMessageType.ACTION_PLAN_READY,
        'conversation-a',
        'turn-1',
        createMessage.taskId,
        ready
      ));
      await receiveUiState(observer, 'action');

      expect(writer.writes.length).assertEqual(3);
      expect(writer.writes[2].jsonl).assertEqual(
        `{"workflow":{"name":"workflow.run","args":` +
          `{"planId":"plan-ui-1","runId":"${create.runId}"}}}`
      );
      expect(Object.keys(ready.args).sort().join(',')).assertEqual('planId,runId');
      expect(renderer.readyKeys).assertEqual(
        'actionId,args,label,planId,runId,surfaceId'
      );
      expect(renderer.readyLabel).assertEqual('Open detail and navigate');

      agent.stop();
      observer.close();
    });

    it('fails closed before writing a renderer-proposed early workflow affordance', 0, async () => {
      const bus = new LinkedMessageBus();
      const renderer = new EarlyWorkflowRenderer();
      const writer = new RecordingSurfaceWriter();
      const agent = new UiAgent(bus, renderer, writer);
      const observer = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage());
      await receiveUiState(observer, 'skeleton');
      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-1', 101));
      const failed = await receiveType(observer, AgentMessageType.TASK_ERROR);
      await settle();

      expect((failed.payload as TaskErrorPayload).code).assertEqual('UI_RENDER_FAILED');
      expect(writer.writes.length).assertEqual(1);
      expect(renderer.calls.filter(
        (call: string): boolean => call.startsWith('ready:')
      ).length).assertEqual(0);

      agent.stop();
      observer.close();
    });

    it('rejects a nested Unicode-escaped workflow action in skeleton JSONL', 0, async () => {
      const bus = new LinkedMessageBus();
      const renderer = new JsonlProbeRenderer();
      renderer.skeletonJsonl =
        '{"nested":[{"action":"workflow.\\u0072un"}]}';
      const writer = new RecordingSurfaceWriter();
      const agent = new UiAgent(bus, renderer, writer);
      const observer = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage());
      await receiveTaskErrorCode(observer, 'UI_RENDER_FAILED');

      expect(writer.writes.length).assertEqual(0);
      agent.stop();
      observer.close();
    });

    it('rejects a malformed nonempty result JSONL line before writing', 0, async () => {
      const bus = new LinkedMessageBus();
      const renderer = new JsonlProbeRenderer();
      renderer.resultJsonl = '{"valid":true}\n\n{"broken":';
      const writer = new RecordingSurfaceWriter();
      const agent = new UiAgent(bus, renderer, writer);
      const observer = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage());
      await receiveUiState(observer, 'skeleton');
      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-1', 101));
      await receiveTaskErrorCode(observer, 'UI_RENDER_FAILED');

      expect(writer.writes.length).assertEqual(1);
      agent.stop();
      observer.close();
    });

    it('rejects nested workflow JSONL from error and progress render paths', 0, async () => {
      const errorBus = new LinkedMessageBus();
      const errorRenderer = new JsonlProbeRenderer();
      errorRenderer.errorJsonl =
        '["safe",{"deep":{"action":"workflow.\\u0072un"}}]';
      const errorWriter = new RecordingSurfaceWriter();
      const errorAgent = new UiAgent(errorBus, errorRenderer, errorWriter);
      const errorObserver = errorBus.openReader();
      errorAgent.start();
      const providerError: TaskErrorPayload = {
        code: 'DATA_TASK_FAILED',
        message: 'provider unavailable'
      };

      errorBus.publish(uiTaskMessage());
      await receiveUiState(errorObserver, 'skeleton');
      errorBus.publish(turnMessage(
        AgentMessageType.TASK_ERROR,
        'conversation-a',
        'turn-1',
        'data-1',
        providerError
      ));
      await receiveTaskErrorCode(errorObserver, 'UI_RENDER_FAILED');
      expect(errorWriter.writes.length).assertEqual(1);
      errorAgent.stop();
      errorObserver.close();

      const progressBus = new LinkedMessageBus();
      const progressRenderer = new JsonlProbeRenderer();
      progressRenderer.actionJsonl =
        '{"deep":[{"action":"workflow.\\u0072un"}]}';
      const progressWriter = new RecordingSurfaceWriter();
      const progressAgent = new UiAgent(
        progressBus,
        progressRenderer,
        progressWriter
      );
      const progressObserver = progressBus.openReader();
      progressAgent.start();
      progressBus.publish(uiTaskMessage());
      await receiveUiState(progressObserver, 'skeleton');
      progressBus.publish(turnMessage(
        AgentMessageType.ACTION_PROGRESS,
        'conversation-a',
        'turn-1',
        'progress-jsonl',
        actionPayload(
          progressWriter.writes[0].surfaceId,
          'progress-jsonl-run',
          'running'
        )
      ));
      await receiveTaskErrorCode(progressObserver, 'UI_RENDER_FAILED');
      expect(progressWriter.writes.length).assertEqual(1);
      progressAgent.stop();
      progressObserver.close();
    });

    it('rejects more than five proposals before result write or publication', 0, async () => {
      const bus = new LinkedMessageBus();
      const renderer = new ManyProposalRenderer(6);
      const writer = new RecordingSurfaceWriter();
      const agent = new UiAgent(bus, renderer, writer);
      const observer = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage());
      await receiveUiState(observer, 'skeleton');
      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-1', 101));
      let createCount = 0;
      let resultCount = 0;
      while (true) {
        const current = await receive(observer);
        if (current.type === AgentMessageType.ACTION_PLAN_CREATE) {
          createCount++;
        }
        if (current.type === AgentMessageType.TASK_RESULT_UI &&
          (current.payload as UiRenderResultPayload).state === 'result') {
          resultCount++;
        }
        if (current.type === AgentMessageType.TASK_ERROR &&
          (current.payload as TaskErrorPayload).code === 'UI_RENDER_FAILED') {
          break;
        }
      }
      await settle();
      bus.publish(turnMessage(
        AgentMessageType.INPUT_USER,
        'marker',
        'marker',
        'proposal-cap-marker'
      ));
      let observed = await receive(observer);
      while (observed.type !== AgentMessageType.INPUT_USER) {
        if (observed.type === AgentMessageType.ACTION_PLAN_CREATE) {
          createCount++;
        }
        if (observed.type === AgentMessageType.TASK_RESULT_UI &&
          (observed.payload as UiRenderResultPayload).state === 'result') {
          resultCount++;
        }
        observed = await receive(observer);
      }

      expect(createCount).assertEqual(0);
      expect(resultCount).assertEqual(0);
      expect(writer.writes.length).assertEqual(1);
      agent.stop();
      observer.close();
    });

    it('clears exact proposal correlations on invalid and capacity results', 0, async () => {
      const bus = new LinkedMessageBus();
      const renderer = new ManyProposalRenderer(2);
      const writer = new RecordingSurfaceWriter();
      const agent = new UiAgent(bus, renderer, writer);
      const observer = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage());
      await receiveUiState(observer, 'skeleton');
      bus.publish(dataResultMessage('conversation-a', 'turn-1', 'data-1', 101));
      const firstCreateMessage = await receiveType(
        observer,
        AgentMessageType.ACTION_PLAN_CREATE
      );
      const secondCreateMessage = await receiveType(
        observer,
        AgentMessageType.ACTION_PLAN_CREATE
      );
      const firstCreate = firstCreateMessage.payload as ActionPlanCreatePayload;
      const secondCreate = secondCreateMessage.payload as ActionPlanCreatePayload;
      const firstFailure: ActionResultPayload = {
        surfaceId: firstCreate.plan.surfaceId,
        planId: firstCreate.plan.planId,
        runId: firstCreate.runId,
        status: 'error',
        completedStepIds: [],
        errorCode: 'ACTION_PLAN_CREATE_INVALID',
        message: 'Invalid proposal.'
      };
      const secondFailure: ActionResultPayload = {
        surfaceId: secondCreate.plan.surfaceId,
        planId: secondCreate.plan.planId,
        runId: secondCreate.runId,
        status: 'error',
        completedStepIds: [],
        errorCode: 'ACTION_STATE_CAPACITY',
        message: 'Capacity exhausted.'
      };
      bus.publish(turnMessage(
        AgentMessageType.ACTION_RESULT,
        'conversation-a',
        'turn-1',
        firstCreateMessage.taskId,
        firstFailure
      ));
      bus.publish(turnMessage(
        AgentMessageType.ACTION_RESULT,
        'conversation-a',
        'turn-1',
        secondCreateMessage.taskId,
        secondFailure
      ));
      await receiveUiState(observer, 'action');
      await receiveUiState(observer, 'action');
      const writesBeforeReady = writer.writes.length;
      const replayReady: ActionPlanReadyPayload = {
        surfaceId: firstCreate.plan.surfaceId,
        planId: firstCreate.plan.planId,
        runId: firstCreate.runId,
        label: firstCreate.plan.label,
        actionId: 'workflow.run',
        args: {
          planId: firstCreate.plan.planId,
          runId: firstCreate.runId
        }
      };
      bus.publish(turnMessage(
        AgentMessageType.ACTION_PLAN_READY,
        'conversation-a',
        'turn-1',
        firstCreateMessage.taskId,
        replayReady
      ));
      bus.publish(turnMessage(
        AgentMessageType.INPUT_USER,
        'marker',
        'marker',
        'proposal-clear-marker'
      ));
      let observed = await receive(observer);
      while (observed.type !== AgentMessageType.INPUT_USER) {
        observed = await receive(observer);
      }

      expect(writer.writes.length).assertEqual(writesBeforeReady);
      agent.stop();
      observer.close();
    });

    it('serializes slow Action progress before a fast Action result', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: SlowProgressRenderer = new SlowProgressRenderer();
      const writer: RecordingSurfaceWriter = new RecordingSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage());
      await receiveUiState(observer, 'skeleton');
      const surfaceId: string = writer.writes[0].surfaceId;
      bus.publish(turnMessage(
        AgentMessageType.ACTION_PROGRESS,
        'conversation-a',
        'turn-1',
        'action-progress',
        actionPayload(surfaceId, 'run-1', 'running')
      ));
      await renderer.progressStarted.promise;
      bus.publish(turnMessage(
        AgentMessageType.ACTION_RESULT,
        'conversation-a',
        'turn-1',
        'action-result',
        actionPayload(surfaceId, 'run-1', 'success')
      ));
      await settle();
      expect(writer.writes.length).assertEqual(1);
      renderer.finishProgress();
      await receiveUiState(observer, 'action');
      await receiveUiState(observer, 'action');

      expect(writer.writes.map((write: SurfaceWrite): string => write.jsonl).join(','))
        .assertEqual(
          `${JSON.stringify('skeleton:ui-1')},` +
            `${JSON.stringify('action:running')},` +
            `${JSON.stringify('action:success')}`
        );
      agent.stop();
      observer.close();
    });

    it('writer lease blocks mutation when turn is canceled during an internal write await', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: DeferredSurfaceWriter = new DeferredSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage());
      await writer.started.promise;
      bus.publish(turnMessage(AgentMessageType.TURN_CANCEL, 'conversation-a', 'turn-1', 'cancel-1'));
      await settle();
      writer.release();
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

    it('writer lease blocks mutation when surface is replaced during an internal write await', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const renderer: RecordingRenderer = new RecordingRenderer();
      const writer: DeferredSurfaceWriter = new DeferredSurfaceWriter();
      const agent: UiAgent = new UiAgent(bus, renderer, writer);
      const observer: AgentMessageReader = bus.openReader();
      agent.start();

      bus.publish(uiTaskMessage());
      await writer.started.promise;
      agent.surfaceReplaced('conversation-a', 'turn-1', writer.surfaceId);
      writer.release();
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
      expect(writer.writes[1].jsonl).assertEqual(
        JSON.stringify('error:provider unavailable')
      );
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
