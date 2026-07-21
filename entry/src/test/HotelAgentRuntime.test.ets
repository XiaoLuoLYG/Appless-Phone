import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  ActionPlanStepOutput,
  ActionResultPayload,
  ActionRunPayload,
  A2uiAction,
  A2uiSurfaceState,
  CreateDataTaskPayload,
  DataResult,
  DataResultError,
  DataTaskExecutor,
  HotelDetailRequest,
  HotelDetailResult,
  HotelBookingOpenArgs,
  HotelRatePlan,
  HotelSearchItem,
  HotelSearchRequest,
  HotelSearchResult,
  LinkedMessageBus,
  LocalModel,
  UiSurfaceWriteLease,
  UiSurfaceWriter,
  UiRenderResultPayload,
  hotelBookingOpenAction,
  hotelDetailAction,
  hotelNavigateAction,
  hotelSearchDataResult,
  parseHotelSearchRequest
} from '@loop/agent-core';
import {
  HotelActionContext,
  HotelAgentRuntime,
  HotelAgentRuntimeOptions,
  HotelTurnOutcome
} from '../main/ets/pages/A2uiHome/agent/HotelAgentRuntime';
import { SystemUriOpener } from '../main/ets/pages/A2uiHome/agent/HotelRegisteredActionExecutor';
import { createHtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeSnapshot';
import { HtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeTypes';

const SEARCH_QUERY: string = '8月15日深圳住两晚的酒店';
const SEARCH_JSON: string = '{' +
  '"originQuery":"' + SEARCH_QUERY + '",' +
  '"place":"深圳","placeType":"CITY","countryCode":"CN",' +
  '"checkInDate":"2026-08-15","stayNights":2,"adultCount":2,' +
  '"childCount":0,"childAgeDetails":[],"roomCount":1,"currency":"CNY","size":10}';

interface SurfaceWrite {
  turnId: string;
  surfaceId: string;
  jsonl: string;
}

interface EmptyHotelData {
  marker?: string;
}

interface FakeActionSuccessOutput {
  actionId: string;
  status: string;
}

interface FakeSystemIntentSuccessOutput {
  actionId: string;
  status: string;
  uri: string;
  message: string;
}

class FixedHotelModel implements LocalModel {
  async complete(_prompt: string): Promise<string> {
    return SEARCH_JSON;
  }
}

class TrackingBus extends LinkedMessageBus {
  readerCount: number = 0;
  readerCountAtInput: number = 0;
  messages: AgentMessage[] = [];

  openReader(): AgentMessageReader {
    this.readerCount += 1;
    return super.openReader();
  }

  publish(message: AgentMessage): void {
    this.messages.push(message);
    if (message.type === AgentMessageType.INPUT_USER) {
      this.readerCountAtInput = this.readerCount;
    }
    super.publish(message);
  }
}

class TestGate {
  readonly promise: Promise<void>;
  private releasePromise: (() => void) | null = null;

  constructor() {
    this.promise = new Promise<void>((resolve: () => void) => {
      this.releasePromise = resolve;
    });
  }

  open(): void {
    const release = this.releasePromise;
    this.releasePromise = null;
    if (release !== null) {
      release();
    }
  }
}

class FakeHotelProvider implements DataTaskExecutor {
  readonly calls: string[] = [];
  readonly gate: TestGate | null;

  constructor(gate: TestGate | null = null) {
    this.gate = gate;
  }

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls.push(task.toolId);
    if (this.gate !== null) {
      await this.gate.promise;
    }
    if (task.toolId === 'hotel.detail') {
      const query = task.args as HotelDetailRequest;
      const rate: HotelRatePlan = {
        roomName: 'Deluxe',
        roomNameCn: '豪华大床房',
        ratePlanId: 'rate-real-1',
        ratePlanName: '不含早餐',
        averagePrice: 550,
        bedTypeDescription: '1 大床',
        currency: 'CNY',
        mealAmount: 0,
        mealTypeStr: '不含早餐',
        isOnRequest: false,
        cancelPolicy: '免费取消截止至 2026-08-12'
      };
      const detail: HotelDetailResult = {
        ok: true,
        error: '',
        message: '实时房型',
        query: query,
        hotelId: query.hotelId,
        bookingUrl: '',
        name: '深圳测试酒店',
        nameEn: 'Shenzhen Test Hotel',
        checkIn: query.checkInDate,
        checkOut: query.checkOutDate,
        rates: [rate]
      };
      return {
        toolId: 'hotel.detail',
        outputSchema: 'hotelRatePlans',
        status: 'success',
        sources: [],
        data: detail,
        warnings: []
      };
    }
    const query = task.args as HotelSearchRequest;
    return hotelSearchDataResult(searchResult(query), []);
  }
}

class FixedResultProvider implements DataTaskExecutor {
  readonly result: DataResult;
  calls: number = 0;

  constructor(result: DataResult) {
    this.result = result;
  }

  async execute(_task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls += 1;
    return this.result;
  }
}

class FirstCallDelayedProvider implements DataTaskExecutor {
  readonly firstGate: TestGate = new TestGate();
  calls: number = 0;

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls += 1;
    const call = this.calls;
    if (call === 1) {
      await this.firstGate.promise;
    }
    const query = task.args as HotelSearchRequest;
    return hotelSearchDataResult(searchResult(query), []);
  }
}

class DeferredDetailProvider implements DataTaskExecutor {
  readonly calls: string[] = [];
  readonly detailStarted: TestGate = new TestGate();
  readonly detailRelease: TestGate = new TestGate();
  readonly failDetail: boolean;

  constructor(failDetail: boolean = false) {
    this.failDetail = failDetail;
  }

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls.push(task.toolId);
    if (task.toolId === 'hotel.search') {
      const query = task.args as HotelSearchRequest;
      return hotelSearchDataResult(searchResult(query), []);
    }
    this.detailStarted.open();
    await this.detailRelease.promise;
    const request = task.args as HotelDetailRequest;
    return this.failDetail ? detailProviderErrorResult() : detailSuccessResult(request);
  }
}

class RecordingWriter implements UiSurfaceWriter {
  readonly writes: SurfaceWrite[] = [];

  async write(
    turnId: string,
    surfaceId: string,
    jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void> {
    if (lease.isActive()) {
      this.writes.push({ turnId: turnId, surfaceId: surfaceId, jsonl: jsonl });
    }
  }
}

class NeverSettlingWriter implements UiSurfaceWriter {
  writesStarted: number = 0;

  write(
    _turnId: string,
    _surfaceId: string,
    _jsonl: string,
    _lease: UiSurfaceWriteLease
  ): Promise<void> {
    this.writesStarted += 1;
    return new Promise<void>((_resolve: () => void) => {
    });
  }
}

class ThrowingWriter implements UiSurfaceWriter {
  async write(
    _turnId: string,
    _surfaceId: string,
    _jsonl: string,
    _lease: UiSurfaceWriteLease
  ): Promise<void> {
    throw new Error('writer failed');
  }
}

class ThrowingDetailResultWriter extends RecordingWriter {
  async write(
    turnId: string,
    surfaceId: string,
    jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void> {
    if (jsonl.indexOf('rate-real-1') >= 0) {
      throw new Error('detail result writer failed');
    }
    await super.write(turnId, surfaceId, jsonl, lease);
  }
}

class DeferredFirstWriter extends RecordingWriter {
  readonly started: TestGate = new TestGate();
  readonly release: TestGate = new TestGate();
  private first: boolean = true;

  async write(
    turnId: string,
    surfaceId: string,
    jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void> {
    if (this.first) {
      this.first = false;
      this.started.open();
      await this.release.promise;
    }
    await super.write(turnId, surfaceId, jsonl, lease);
  }
}

class RecordingOpener implements SystemUriOpener {
  readonly uris: string[] = [];
  opened: boolean = true;

  async open(uri: string): Promise<boolean> {
    this.uris.push(uri);
    return this.opened;
  }
}

class DeferredFirstOpener extends RecordingOpener {
  readonly started: TestGate = new TestGate();
  readonly release: TestGate = new TestGate();
  private first: boolean = true;

  async open(uri: string): Promise<boolean> {
    this.uris.push(uri);
    if (this.first) {
      this.first = false;
      this.started.open();
      await this.release.promise;
    }
    return this.opened;
  }
}

function searchHotel(): HotelSearchItem {
  return {
    hotelId: 47675,
    bookingUrl: 'https://rollinggo.cn/pages/hotel/detail/index?id=47675&checkInDate=2026-08-15&checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0',
    name: '深圳测试酒店',
    nameEn: 'Shenzhen Test Hotel',
    brand: '',
    address: '深圳市南山区科技南路 88 号',
    destinationId: '6046792',
    latitude: 22.5431,
    longitude: 114.0579,
    distanceInMeters: 0,
    starRating: 5,
    price: {
      message: '2 晚参考价',
      hasPrice: true,
      currency: 'CNY',
      lowestPrice: 1100
    },
    areaCode: 'NANSHAN',
    description: 'provider description',
    imageUrl: 'https://img.example/hotel.jpg',
    hotelAmenities: ['Wi-Fi'],
    tags: ['商务']
  };
}

function searchResult(query: HotelSearchRequest): HotelSearchResult {
  return {
    ok: true,
    error: '',
    message: '酒店搜索成功',
    query: query,
    hotels: [searchHotel()]
  };
}

function detailSuccessResult(query: HotelDetailRequest): DataResult {
  const rate: HotelRatePlan = {
    roomName: 'Deluxe',
    roomNameCn: '豪华大床房',
    ratePlanId: 'rate-real-1',
    ratePlanName: '不含早餐',
    averagePrice: 550,
    bedTypeDescription: '1 大床',
    currency: 'CNY',
    mealAmount: 0,
    mealTypeStr: '不含早餐',
    isOnRequest: false,
    cancelPolicy: '免费取消截止至 2026-08-12'
  };
  const detail: HotelDetailResult = {
    ok: true,
    error: '',
    message: '实时房型',
    query: query,
    hotelId: query.hotelId,
    bookingUrl: '',
    name: '深圳测试酒店',
    nameEn: 'Shenzhen Test Hotel',
    checkIn: query.checkInDate,
    checkOut: query.checkOutDate,
    rates: [rate]
  };
  return {
    toolId: 'hotel.detail',
    outputSchema: 'hotelRatePlans',
    status: 'success',
    sources: [],
    data: detail,
    warnings: []
  };
}

function detailProviderErrorResult(): DataResult {
  const data: EmptyHotelData = {};
  const error: DataResultError = {
    code: 'HOTEL_DETAIL_PROVIDER_ERROR',
    message: 'RollingGo detail failed',
    retryable: true
  };
  return {
    toolId: 'hotel.detail',
    outputSchema: 'hotelRatePlans',
    status: 'error',
    sources: [],
    data: data,
    warnings: [],
    error: error
  };
}

function options(
  bus: TrackingBus,
  provider: DataTaskExecutor,
  writer: UiSurfaceWriter,
  opener: SystemUriOpener,
  onSurface?: (surface: A2uiSurfaceState) => void,
  submitTimeoutMs: number = 1000,
  actionTimeoutMs: number = 1000
): HotelAgentRuntimeOptions {
  const result: HotelAgentRuntimeOptions = {
    model: new FixedHotelModel(),
    currentLocalDate: (): string => '2026-07-20',
    dataExecutor: provider,
    writer: writer,
    opener: opener,
    bus: bus,
    conversationId: 'hotel-page-session',
    submitTimeoutMs: submitTimeoutMs,
    actionTimeoutMs: actionTimeoutMs
  };
  if (onSurface !== undefined) {
    result.onSurface = onSurface;
  }
  return result;
}

async function flush(rounds: number = 12): Promise<void> {
  for (let index = 0; index < rounds; index++) {
    await new Promise<void>((resolve: () => void) => setTimeout(resolve, 0));
  }
}

function messagesOf(bus: TrackingBus, type: AgentMessageType): AgentMessage[] {
  const result: AgentMessage[] = [];
  bus.messages.forEach((message: AgentMessage) => {
    if (message.type === type) {
      result.push(message);
    }
  });
  return result;
}

function messageCountForTurn(
  bus: TrackingBus,
  type: AgentMessageType,
  turnId: string
): number {
  let count = 0;
  bus.messages.forEach((message: AgentMessage) => {
    if (message.type === type && message.turnId === turnId) {
      count += 1;
    }
  });
  return count;
}

function searchRequest(): HotelSearchRequest {
  const parsed = parseHotelSearchRequest(JSON.parse(SEARCH_JSON) as Object);
  if (parsed.value === null) {
    throw new Error('search fixture is invalid');
  }
  return parsed.value;
}

function providerErrorResult(): DataResult {
  const data: EmptyHotelData = {};
  const error: DataResultError = {
    code: 'HOTEL_PROVIDER_ERROR',
    message: 'RollingGo business error',
    retryable: true
  };
  return {
    toolId: 'hotel.search',
    outputSchema: 'hotelSearchResults',
    status: 'error',
    sources: [],
    data: data,
    warnings: [],
    error: error
  };
}

function malformedSuccessResult(): DataResult {
  const data: EmptyHotelData = {};
  return {
    toolId: 'hotel.search',
    outputSchema: 'hotelSearchResults',
    status: 'success',
    sources: [],
    data: data,
    warnings: []
  };
}

function emptySearchResult(): DataResult {
  const result = searchResult(searchRequest());
  result.hotels = [];
  result.message = '没有符合条件的酒店';
  return hotelSearchDataResult(result, []);
}

function partialSearchResult(): DataResult {
  return hotelSearchDataResult(
    searchResult(searchRequest()),
    [],
    ['RollingGo returned partial hotel data']
  );
}

function lastWriteContains(writer: RecordingWriter, value: string): boolean {
  for (let index = writer.writes.length - 1; index >= 0; index--) {
    if (writer.writes[index].jsonl.indexOf(value) >= 0) {
      return true;
    }
  }
  return false;
}

function documentAction(document: HtmlHomeDocument, actionId: string): A2uiAction | null {
  for (let blockIndex = 0; blockIndex < document.blocks.length; blockIndex++) {
    const actions = document.blocks[blockIndex].actions;
    for (let actionIndex = 0; actionIndex < actions.length; actionIndex++) {
      const candidate = actions[actionIndex];
      if (candidate.id === actionId && candidate.args !== undefined) {
        return {
          id: candidate.id,
          label: candidate.label,
          prompt: candidate.prompt,
          variant: candidate.variant,
          kind: candidate.kind,
          args: candidate.args
        };
      }
    }
  }
  return null;
}

export default function hotelAgentRuntimeTest() {
  describe('hotelAgentRuntime', () => {
    it('opens every role before one input and renders skeleton then result on one surface', 0, async () => {
      const gate = new TestGate();
      const bus = new TrackingBus();
      const provider = new FakeHotelProvider(gate);
      const writer = new RecordingWriter();
      const runtime = new HotelAgentRuntime(options(bus, provider, writer, new RecordingOpener()));

      const submitted = runtime.submit(SEARCH_QUERY);
      await flush();

      expect(messagesOf(bus, AgentMessageType.INPUT_USER).length).assertEqual(1);
      expect(bus.readerCountAtInput).assertEqual(5);
      expect(writer.writes.length).assertEqual(1);
      expect(writer.writes[0].jsonl.indexOf('RollingGo')).assertLarger(-1);
      expect(writer.writes[0].jsonl.indexOf('pending')).assertLarger(-1);
      expect(writer.writes[0].jsonl.indexOf('hotel.detail')).assertEqual(-1);
      gate.open();
      await flush();
      expect(messagesOf(bus, AgentMessageType.TASK_RESULT_DATA).length).assertEqual(1);
      expect(messagesOf(bus, AgentMessageType.ACTION_OFFERS_READY).length).assertEqual(1);
      expect(writer.writes.length >= 2).assertTrue();
      expect(messagesOf(bus, AgentMessageType.TASK_RESULT_UI).length >= 2).assertTrue();
      const outcome: HotelTurnOutcome = await submitted;
      expect(outcome.ok).assertTrue();
      expect(outcome.status).assertEqual('success');
      await flush();

      expect(writer.writes.length >= 2).assertTrue();
      expect(writer.writes[0].surfaceId).assertEqual(writer.writes[1].surfaceId);
      expect(writer.writes[1].jsonl.indexOf('深圳测试酒店')).assertLarger(-1);
      const uiTasks = messagesOf(bus, AgentMessageType.TASK_CREATE_UI);
      const dataTasks = messagesOf(bus, AgentMessageType.TASK_CREATE_DATA);
      expect(messagesOf(bus, AgentMessageType.TASK_RESULT_DATA).length).assertEqual(1);
      expect(messagesOf(bus, AgentMessageType.TASK_RESULT_UI).length >= 2).assertTrue();
      const ui = uiTasks[0].payload as Record<string, Object | string | number | boolean | null | undefined>;
      const data = dataTasks[0].payload as Record<string, Object | string | number | boolean | null | undefined>;
      expect(ui.dataTaskId).assertEqual(data.taskId);
      expect(ui.expectedOutputSchema).assertEqual(data.outputSchema);
      runtime.stop();
    });

    it('buffers a data-first result while the skeleton writer is delayed', 0, async () => {
      const bus = new TrackingBus();
      const provider = new FakeHotelProvider();
      const writer = new DeferredFirstWriter();
      const runtime = new HotelAgentRuntime(options(bus, provider, writer, new RecordingOpener()));

      const submitted = runtime.submit(SEARCH_QUERY);
      await writer.started.promise;
      await flush();
      expect(messagesOf(bus, AgentMessageType.TASK_RESULT_DATA).length).assertEqual(1);
      expect(writer.writes.length).assertEqual(0);
      writer.release.open();
      expect((await submitted).ok).assertTrue();
      await flush();

      expect(writer.writes.length).assertEqual(2);
      expect(writer.writes[0].surfaceId).assertEqual(writer.writes[1].surfaceId);
      runtime.stop();
    });

    it('runs call navigation and detail through Action Agent with a correlated follow-up', 0, async () => {
      const bus = new TrackingBus();
      const provider = new FakeHotelProvider();
      const writer = new RecordingWriter();
      const opener = new RecordingOpener();
      const runtime = new HotelAgentRuntime(options(bus, provider, writer, opener));
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      await flush();

      const parsedQuery = parseHotelSearchRequest(JSON.parse(SEARCH_JSON) as Object);
      if (parsedQuery.value === null) {
        runtime.stop();
        return;
      }
      const query = parsedQuery.value;
      const hotel = searchHotel();
      expect(await runtime.runAction(hotelNavigateAction(hotel))).assertTrue();
      expect(opener.uris.length).assertEqual(1);
      expect(opener.uris[0].indexOf('petalmaps://')).assertEqual(0);

      const detailAction = hotelDetailAction(hotel, query);
      const oldTurn = messagesOf(bus, AgentMessageType.INPUT_USER)[0].turnId;
      expect(await runtime.runAction(detailAction)).assertTrue();
      await flush(20);

      const actionRuns = messagesOf(bus, AgentMessageType.ACTION_RUN);
      expect(actionRuns.length).assertEqual(2);
      const uiTasks = messagesOf(bus, AgentMessageType.TASK_CREATE_UI);
      const dataTasks = messagesOf(bus, AgentMessageType.TASK_CREATE_DATA);
      expect(uiTasks.length).assertEqual(2);
      expect(dataTasks.length).assertEqual(2);
      expect(uiTasks[1].turnId === oldTurn).assertFalse();
      expect(uiTasks[1].turnId).assertEqual(dataTasks[1].turnId);
      const ui = uiTasks[1].payload as Record<string, Object | string | number | boolean | null | undefined>;
      const data = dataTasks[1].payload as Record<string, Object | string | number | boolean | null | undefined>;
      expect(ui.dataTaskId).assertEqual(data.taskId);
      expect(data.toolId).assertEqual('hotel.detail');
      expect(provider.calls.join(',')).assertEqual('hotel.search,hotel.detail');
      let sawDetailRate = false;
      writer.writes.forEach((write: SurfaceWrite) => {
        if (write.jsonl.indexOf('rate-real-1') >= 0) {
          sawDetailRate = true;
        }
      });
      expect(sawDetailRate).assertTrue();
      runtime.stop();
    });

    it('settles navigation and call directly when the system opener rejects them', 0, async () => {
      const bus = new TrackingBus();
      const opener = new RecordingOpener();
      opener.opened = false;
      const runtime = new HotelAgentRuntime(options(
        bus,
        new FakeHotelProvider(),
        new RecordingWriter(),
        opener
      ));
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      const hotel = searchHotel();
      expect(await runtime.runAction(hotelNavigateAction(hotel))).assertFalse();
      const results = messagesOf(bus, AgentMessageType.ACTION_RESULT);
      expect(results.length).assertEqual(1);
      results.forEach((message: AgentMessage) => {
        const result = message.payload as ActionResultPayload;
        expect(result.status).assertEqual('error');
        expect(result.completedStepIds.length).assertEqual(0);
        expect(result.stepId).assertEqual('step-1');
      });
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      runtime.dispose();
    });

    it('rejects exact-identity action success until the expected step output is complete', 0, async () => {
      const bus = new TrackingBus();
      const opener = new DeferredFirstOpener();
      const runtime = new HotelAgentRuntime(options(
        bus,
        new FakeHotelProvider(),
        new RecordingWriter(),
        opener
      ));
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      const running = runtime.runAction(hotelNavigateAction(searchHotel()));
      let settled = false;
      running.then((_ok: boolean): void => {
        settled = true;
      });
      await opener.started.promise;
      const actionRun = messagesOf(bus, AgentMessageType.ACTION_RUN)[0];
      const run = actionRun.payload as ActionRunPayload;
      const context = runtime.currentActionContext();
      const exactBase: ActionResultPayload = {
        surfaceId: context === null ? '' : context.surfaceId,
        planId: 'direct:' + run.runId,
        runId: run.runId,
        status: 'success',
        completedStepIds: ['step-1'],
        outputs: []
      };
      const duplicateOutputs: ActionPlanStepOutput[] = [{
        stepId: 'step-1',
        output: {
          actionId: 'hotel.navigate',
          status: 'opened'
        } as FakeActionSuccessOutput
      }];
      const duplicateStep: ActionResultPayload = {
        surfaceId: exactBase.surfaceId,
        planId: exactBase.planId,
        runId: exactBase.runId,
        status: 'success',
        completedStepIds: ['step-1', 'step-1'],
        outputs: duplicateOutputs
      };
      const foreignOutputs: ActionPlanStepOutput[] = [{
        stepId: 'foreign-step',
        output: {
          actionId: 'hotel.navigate',
          status: 'opened'
        } as FakeActionSuccessOutput
      }];
      const foreignOutput: ActionResultPayload = {
        surfaceId: exactBase.surfaceId,
        planId: exactBase.planId,
        runId: exactBase.runId,
        status: 'success',
        completedStepIds: ['step-1'],
        outputs: foreignOutputs
      };
      const wrongActionOutputs: ActionPlanStepOutput[] = [{
        stepId: 'step-1',
        output: {
          actionId: 'hotel.booking.open',
          status: 'opened'
        } as FakeActionSuccessOutput
      }];
      const wrongAction: ActionResultPayload = {
        surfaceId: exactBase.surfaceId,
        planId: exactBase.planId,
        runId: exactBase.runId,
        status: 'success',
        completedStepIds: ['step-1'],
        outputs: wrongActionOutputs
      };
      const wrongPetalOutputs: ActionPlanStepOutput[] = [{
        stepId: 'step-1',
        output: {
          actionId: 'hotel.navigate',
          status: 'opened',
          uri: opener.uris[0] + '&spoofed=1',
          message: 'Petal Maps opened.'
        } as FakeSystemIntentSuccessOutput
      }];
      const wrongPetal: ActionResultPayload = {
        surfaceId: exactBase.surfaceId,
        planId: exactBase.planId,
        runId: exactBase.runId,
        status: 'success',
        completedStepIds: ['step-1'],
        outputs: wrongPetalOutputs
      };
      const swappedSchemeOutputs: ActionPlanStepOutput[] = [{
        stepId: 'step-1',
        output: {
          actionId: 'hotel.navigate',
          status: 'opened',
          uri: 'tel:+8675512345678',
          message: 'Petal Maps opened.'
        } as FakeSystemIntentSuccessOutput
      }];
      const swappedScheme: ActionResultPayload = {
        surfaceId: exactBase.surfaceId,
        planId: exactBase.planId,
        runId: exactBase.runId,
        status: 'success',
        completedStepIds: ['step-1'],
        outputs: swappedSchemeOutputs
      };
      const forgedMessageOutputs: ActionPlanStepOutput[] = [{
        stepId: 'step-1',
        output: {
          actionId: 'hotel.navigate',
          status: 'opened',
          uri: opener.uris[0],
          message: 'Maps opened.'
        } as FakeSystemIntentSuccessOutput
      }];
      const forgedMessage: ActionResultPayload = {
        surfaceId: exactBase.surfaceId,
        planId: exactBase.planId,
        runId: exactBase.runId,
        status: 'success',
        completedStepIds: ['step-1'],
        outputs: forgedMessageOutputs
      };
      const invalid: ActionResultPayload[] = [
        exactBase,
        duplicateStep,
        foreignOutput,
        wrongAction,
        wrongPetal,
        swappedScheme,
        forgedMessage
      ];
      invalid.forEach((payload: ActionResultPayload) => {
        bus.publish({
          type: AgentMessageType.ACTION_RESULT,
          conversationId: actionRun.conversationId,
          turnId: actionRun.turnId,
          taskId: actionRun.taskId,
          payload: payload
        });
      });
      await flush();
      expect(settled).assertFalse();
      opener.release.open();
      expect(await running).assertTrue();
      runtime.dispose();
    });

    it('settles actual canceled and error Action Agent result shapes without timeout', 0, async () => {
      const canceledBus = new TrackingBus();
      const canceledOpener = new DeferredFirstOpener();
      const canceledRuntime = new HotelAgentRuntime(options(
        canceledBus,
        new FakeHotelProvider(),
        new RecordingWriter(),
        canceledOpener
      ));
      expect((await canceledRuntime.submit(SEARCH_QUERY)).ok).assertTrue();
      const canceledRun = canceledRuntime.runAction(hotelNavigateAction(searchHotel()));
      let canceledSettled = false;
      let canceledOutcome = true;
      canceledRun.then((ok: boolean): void => {
        canceledSettled = true;
        canceledOutcome = ok;
      });
      await canceledOpener.started.promise;
      const canceledMessage = messagesOf(canceledBus, AgentMessageType.ACTION_RUN)[0];
      const canceledPayload = canceledMessage.payload as ActionRunPayload;
      const canceledContext = canceledRuntime.currentActionContext();
      const actualCanceled: ActionResultPayload = {
        surfaceId: canceledContext === null ? '' : canceledContext.surfaceId,
        planId: 'direct:' + canceledPayload.runId,
        runId: canceledPayload.runId,
        status: 'canceled',
        completedStepIds: [],
        errorCode: 'TURN_CANCELED',
        message: 'Action run canceled.'
      };
      canceledBus.publish({
        type: AgentMessageType.ACTION_RESULT,
        conversationId: canceledMessage.conversationId,
        turnId: canceledMessage.turnId,
        taskId: canceledMessage.taskId,
        payload: actualCanceled
      });
      await flush();
      const canceledSettledBeforeRelease = canceledSettled;
      canceledOpener.release.open();
      await canceledRun;
      expect(canceledSettledBeforeRelease).assertTrue();
      expect(canceledOutcome).assertFalse();
      canceledRuntime.dispose();

      const outcomeErrorBus = new TrackingBus();
      const outcomeErrorOpener = new DeferredFirstOpener();
      const outcomeErrorRuntime = new HotelAgentRuntime(options(
        outcomeErrorBus,
        new FakeHotelProvider(),
        new RecordingWriter(),
        outcomeErrorOpener
      ));
      expect((await outcomeErrorRuntime.submit(SEARCH_QUERY)).ok).assertTrue();
      const outcomeErrorRun = outcomeErrorRuntime.runAction(hotelNavigateAction(searchHotel()));
      let outcomeErrorSettled = false;
      let outcomeErrorValue = true;
      outcomeErrorRun.then((ok: boolean): void => {
        outcomeErrorSettled = true;
        outcomeErrorValue = ok;
      });
      await outcomeErrorOpener.started.promise;
      const outcomeErrorMessage = messagesOf(outcomeErrorBus, AgentMessageType.ACTION_RUN)[0];
      const outcomeErrorPayload = outcomeErrorMessage.payload as ActionRunPayload;
      const outcomeErrorContext = outcomeErrorRuntime.currentActionContext();
      const actualOutcomeError: ActionResultPayload = {
        surfaceId: outcomeErrorContext === null ? '' : outcomeErrorContext.surfaceId,
        planId: 'direct:' + outcomeErrorPayload.runId,
        runId: outcomeErrorPayload.runId,
        status: 'error',
        completedStepIds: [],
        stepId: '',
        errorCode: 'ACTION_EXECUTION_FAILED',
        message: 'Action failed.'
      };
      outcomeErrorBus.publish({
        type: AgentMessageType.ACTION_RESULT,
        conversationId: outcomeErrorMessage.conversationId,
        turnId: outcomeErrorMessage.turnId,
        taskId: outcomeErrorMessage.taskId,
        payload: actualOutcomeError
      });
      await flush();
      const outcomeErrorSettledBeforeRelease = outcomeErrorSettled;
      outcomeErrorOpener.release.open();
      await outcomeErrorRun;
      expect(outcomeErrorSettledBeforeRelease).assertTrue();
      expect(outcomeErrorValue).assertFalse();
      outcomeErrorRuntime.dispose();

      const inputErrorBus = new TrackingBus();
      const inputErrorOpener = new DeferredFirstOpener();
      const inputErrorRuntime = new HotelAgentRuntime(options(
        inputErrorBus,
        new FakeHotelProvider(),
        new RecordingWriter(),
        inputErrorOpener
      ));
      expect((await inputErrorRuntime.submit(SEARCH_QUERY)).ok).assertTrue();
      const inputErrorRun = inputErrorRuntime.runAction(hotelNavigateAction(searchHotel()));
      let inputErrorSettled = false;
      let inputErrorValue = true;
      inputErrorRun.then((ok: boolean): void => {
        inputErrorSettled = true;
        inputErrorValue = ok;
      });
      await inputErrorOpener.started.promise;
      const inputErrorMessage = messagesOf(inputErrorBus, AgentMessageType.ACTION_RUN)[0];
      const inputErrorPayload = inputErrorMessage.payload as ActionRunPayload;
      const inputErrorContext = inputErrorRuntime.currentActionContext();
      const actualInputError: ActionResultPayload = {
        surfaceId: inputErrorContext === null ? '' : inputErrorContext.surfaceId,
        planId: 'direct:' + inputErrorPayload.runId,
        runId: inputErrorPayload.runId,
        status: 'error',
        completedStepIds: [],
        errorCode: 'ACTION_RUN_IDENTITY_MISMATCH',
        message: 'Action run does not match a ready plan.'
      };
      inputErrorBus.publish({
        type: AgentMessageType.ACTION_RESULT,
        conversationId: inputErrorMessage.conversationId,
        turnId: inputErrorMessage.turnId,
        taskId: inputErrorMessage.taskId,
        payload: actualInputError
      });
      await flush();
      const inputErrorSettledBeforeRelease = inputErrorSettled;
      inputErrorOpener.release.open();
      await inputErrorRun;
      expect(inputErrorSettledBeforeRelease).assertTrue();
      expect(inputErrorValue).assertFalse();
      inputErrorRuntime.dispose();
    });

    it('ignores malformed canceled and error Action Agent terminal variants', 0, async () => {
      const canceledBus = new TrackingBus();
      const canceledOpener = new DeferredFirstOpener();
      const canceledRuntime = new HotelAgentRuntime(options(
        canceledBus,
        new FakeHotelProvider(),
        new RecordingWriter(),
        canceledOpener
      ));
      expect((await canceledRuntime.submit(SEARCH_QUERY)).ok).assertTrue();
      const canceledRun = canceledRuntime.runAction(hotelNavigateAction(searchHotel()));
      let canceledSettled = false;
      canceledRun.then((_ok: boolean): void => {
        canceledSettled = true;
      });
      await canceledOpener.started.promise;
      const canceledMessage = messagesOf(canceledBus, AgentMessageType.ACTION_RUN)[0];
      const canceledPayload = canceledMessage.payload as ActionRunPayload;
      const canceledContext = canceledRuntime.currentActionContext();
      const malformedCanceled: ActionResultPayload = {
        surfaceId: canceledContext === null ? '' : canceledContext.surfaceId,
        planId: 'direct:' + canceledPayload.runId,
        runId: canceledPayload.runId,
        status: 'canceled',
        completedStepIds: [],
        stepId: 'step-1',
        errorCode: 'TURN_CANCELED',
        message: 'Action run canceled.'
      };
      canceledBus.publish({
        type: AgentMessageType.ACTION_RESULT,
        conversationId: canceledMessage.conversationId,
        turnId: canceledMessage.turnId,
        taskId: canceledMessage.taskId,
        payload: malformedCanceled
      });
      await flush();
      const canceledIgnored = !canceledSettled;
      canceledOpener.release.open();
      const canceledRealOutcome = await canceledRun;
      expect(canceledIgnored).assertTrue();
      expect(canceledRealOutcome).assertTrue();
      canceledRuntime.dispose();

      const errorBus = new TrackingBus();
      const errorOpener = new DeferredFirstOpener();
      const errorRuntime = new HotelAgentRuntime(options(
        errorBus,
        new FakeHotelProvider(),
        new RecordingWriter(),
        errorOpener
      ));
      expect((await errorRuntime.submit(SEARCH_QUERY)).ok).assertTrue();
      const errorRun = errorRuntime.runAction(hotelNavigateAction(searchHotel()));
      let errorSettled = false;
      errorRun.then((_ok: boolean): void => {
        errorSettled = true;
      });
      await errorOpener.started.promise;
      const errorMessage = messagesOf(errorBus, AgentMessageType.ACTION_RUN)[0];
      const errorPayload = errorMessage.payload as ActionRunPayload;
      const errorContext = errorRuntime.currentActionContext();
      const malformedError: ActionResultPayload = {
        surfaceId: errorContext === null ? '' : errorContext.surfaceId,
        planId: 'direct:' + errorPayload.runId,
        runId: errorPayload.runId,
        status: 'error',
        completedStepIds: [],
        outputs: [],
        errorCode: 'ACTION_EXECUTION_FAILED',
        message: 'Action failed.'
      };
      errorBus.publish({
        type: AgentMessageType.ACTION_RESULT,
        conversationId: errorMessage.conversationId,
        turnId: errorMessage.turnId,
        taskId: errorMessage.taskId,
        payload: malformedError
      });
      await flush();
      const errorIgnored = !errorSettled;
      errorOpener.release.open();
      const errorRealOutcome = await errorRun;
      expect(errorIgnored).assertTrue();
      expect(errorRealOutcome).assertTrue();
      errorRuntime.dispose();
    });

    it('does not publish a system action run when its authorized URI is empty', 0, async () => {
      const bus = new TrackingBus();
      const opener = new RecordingOpener();
      const runtime = new HotelAgentRuntime(options(
        bus,
        new FakeHotelProvider(),
        new RecordingWriter(),
        opener
      ));
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      const invalidBookingArgs: HotelBookingOpenArgs = {
        hotelId: 47675,
        bookingUrl: ''
      };
      const invalidBooking: A2uiAction = {
        id: 'hotel.booking.open',
        label: '在 App 内继续预订',
        prompt: '打开 RollingGo 预订',
        kind: 'prompt',
        variant: 'primary',
        args: invalidBookingArgs
      };
      expect(await runtime.runAction(invalidBooking)).assertFalse();
      expect(messagesOf(bus, AgentMessageType.ACTION_RUN).length).assertEqual(0);
      expect(opener.uris.length).assertEqual(0);
      runtime.dispose();
    });

    it('keeps a detail action pending until its promoted provider and UI result finish', 0, async () => {
      const provider = new DeferredDetailProvider();
      const runtime = new HotelAgentRuntime(options(
        new TrackingBus(),
        provider,
        new RecordingWriter(),
        new RecordingOpener()
      ));
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      const running = runtime.runAction(
        hotelDetailAction(searchHotel(), searchRequest())
      );
      let settled = false;
      running.then((_ok: boolean): void => {
        settled = true;
      });
      await provider.detailStarted.promise;
      await flush();
      expect(settled).assertFalse();
      provider.detailRelease.open();
      expect(await running).assertTrue();
      runtime.dispose();
    });

    it('returns false when promoted detail provider or UI completion fails', 0, async () => {
      const providerFailure = new DeferredDetailProvider(true);
      const providerRuntime = new HotelAgentRuntime(options(
        new TrackingBus(),
        providerFailure,
        new RecordingWriter(),
        new RecordingOpener()
      ));
      expect((await providerRuntime.submit(SEARCH_QUERY)).ok).assertTrue();
      const providerRun = providerRuntime.runAction(
        hotelDetailAction(searchHotel(), searchRequest())
      );
      await providerFailure.detailStarted.promise;
      providerFailure.detailRelease.open();
      expect(await providerRun).assertFalse();
      providerRuntime.dispose();

      const uiProvider = new DeferredDetailProvider();
      const uiRuntime = new HotelAgentRuntime(options(
        new TrackingBus(),
        uiProvider,
        new ThrowingDetailResultWriter(),
        new RecordingOpener()
      ));
      expect((await uiRuntime.submit(SEARCH_QUERY)).ok).assertTrue();
      const uiRun = uiRuntime.runAction(
        hotelDetailAction(searchHotel(), searchRequest())
      );
      await uiProvider.detailStarted.promise;
      uiProvider.detailRelease.open();
      expect(await uiRun).assertFalse();
      uiRuntime.dispose();
    });

    it('times out a hanging promoted detail and cancels its follow-up turn', 0, async () => {
      const bus = new TrackingBus();
      const provider = new DeferredDetailProvider();
      const runtime = new HotelAgentRuntime(options(
        bus,
        provider,
        new RecordingWriter(),
        new RecordingOpener(),
        undefined,
        1000,
        20
      ));
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      const searchContext = runtime.currentActionContext();
      const running = runtime.runAction(
        hotelDetailAction(searchHotel(), searchRequest())
      );
      await provider.detailStarted.promise;
      const detailTasks = messagesOf(bus, AgentMessageType.TASK_CREATE_DATA);
      const promotedTurnId = detailTasks[detailTasks.length - 1].turnId;
      expect(await running).assertFalse();
      expect(
        messageCountForTurn(bus, AgentMessageType.TURN_CANCEL, promotedTurnId)
      ).assertEqual(1);
      if (searchContext !== null) {
        expect(
          messageCountForTurn(bus, AgentMessageType.TURN_CANCEL, searchContext.turnId)
        ).assertEqual(0);
      }
      expect(runtime.restoreSearchSurface()).assertTrue();
      provider.detailRelease.open();
      await flush(20);
      runtime.dispose();
    });

    it('rejects modified args and an action replayed after a newer turn', 0, async () => {
      const bus = new TrackingBus();
      const provider = new FakeHotelProvider();
      const writer = new RecordingWriter();
      const opener = new RecordingOpener();
      const runtime = new HotelAgentRuntime(options(bus, provider, writer, opener));
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      await flush();

      const original: A2uiAction = hotelNavigateAction(searchHotel());
      const oldContext: HotelActionContext | null = runtime.currentActionContext();
      const tampered: A2uiAction = hotelNavigateAction(searchHotel());
      const tamperedArgs = tampered.args as Record<string, Object | string | number | boolean | null | undefined>;
      tamperedArgs.latitude = 23.1;
      expect(await runtime.runAction(tampered)).assertFalse();
      expect(opener.uris.length).assertEqual(0);

      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      await flush();
      if (oldContext === null) {
        runtime.stop();
        return;
      }
      expect(await runtime.runAction(original, oldContext)).assertFalse();
      expect(opener.uris.length).assertEqual(0);
      runtime.stop();
    });

    it('requires the exact active context and current HTML document for page actions', 0, async () => {
      const surfaces: A2uiSurfaceState[] = [];
      const opener = new RecordingOpener();
      const runtime = new HotelAgentRuntime(options(
        new TrackingBus(),
        new FakeHotelProvider(),
        new RecordingWriter(),
        opener,
        (surface: A2uiSurfaceState): void => {
          surfaces.push(surface);
        }
      ));
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      const context = runtime.currentActionContext();
      const current: HtmlHomeDocument = createHtmlHomeDocument({
        surface: surfaces[surfaces.length - 1],
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const absent: HtmlHomeDocument = createHtmlHomeDocument({
        surface: surfaces[surfaces.length - 1],
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      absent.blocks.forEach((block) => {
        block.actions = block.actions.filter((candidate) => {
          return candidate.id !== 'hotel.navigate';
        });
      });
      absent.actions = absent.actions.filter((candidate) => {
        return candidate.id !== 'hotel.navigate';
      });
      if (context === null) {
        runtime.dispose();
        return;
      }
      const navigate = documentAction(current, 'hotel.navigate');
      if (navigate === null) {
        runtime.dispose();
        return;
      }

      const changedTurn: HotelActionContext = {
        conversationId: context.conversationId,
        turnId: context.turnId + '-old',
        surfaceId: context.surfaceId,
        sourceToolId: context.sourceToolId
      };
      const changedSurface: HotelActionContext = {
        conversationId: context.conversationId,
        turnId: context.turnId,
        surfaceId: context.surfaceId + '-old',
        sourceToolId: context.sourceToolId
      };
      expect(await runtime.runAction(navigate, changedTurn, current)).assertFalse();
      expect(await runtime.runAction(navigate, changedSurface, current)).assertFalse();
      expect(await runtime.runAction(navigate, context, absent)).assertFalse();
      expect(opener.uris.length).assertEqual(0);
      expect(await runtime.runAction(navigate, context, current)).assertTrue();
      expect(opener.uris.length).assertEqual(1);
      runtime.dispose();
    });

    it('renders provider business errors without casting error data as hotel results', 0, async () => {
      const bus = new TrackingBus();
      const writer = new RecordingWriter();
      const runtime = new HotelAgentRuntime(options(
        bus,
        new FixedResultProvider(providerErrorResult()),
        writer,
        new RecordingOpener()
      ));

      const outcome = await runtime.submit(SEARCH_QUERY);
      expect(outcome.ok).assertFalse();
      expect(outcome.status).assertEqual('error');
      expect(outcome.message).assertEqual('RollingGo business error');
      expect(lastWriteContains(writer, 'RollingGo business error')).assertTrue();
      expect(lastWriteContains(writer, '"id":"hotel.detail"')).assertFalse();
      runtime.dispose();
    });

    it('renders a valid empty provider result and reports an empty outcome', 0, async () => {
      const writer = new RecordingWriter();
      const runtime = new HotelAgentRuntime(options(
        new TrackingBus(),
        new FixedResultProvider(emptySearchResult()),
        writer,
        new RecordingOpener()
      ));

      const outcome = await runtime.submit(SEARCH_QUERY);
      expect(outcome.ok).assertTrue();
      expect(outcome.status).assertEqual('empty');
      expect(lastWriteContains(writer, '没有找到符合条件的酒店')).assertTrue();
      expect(lastWriteContains(writer, '"id":"hotel.detail"')).assertFalse();
      runtime.dispose();
    });

    it('preserves partial-result warnings in the visible hotel surface', 0, async () => {
      const writer = new RecordingWriter();
      const runtime = new HotelAgentRuntime(options(
        new TrackingBus(),
        new FixedResultProvider(partialSearchResult()),
        writer,
        new RecordingOpener()
      ));

      const outcome = await runtime.submit(SEARCH_QUERY);
      expect(outcome.ok).assertTrue();
      expect(outcome.status).assertEqual('partial');
      expect(lastWriteContains(writer, 'RollingGo returned partial hotel data')).assertTrue();
      runtime.dispose();
    });

    it('fails closed on malformed successful hotel data', 0, async () => {
      const writer = new RecordingWriter();
      const runtime = new HotelAgentRuntime(options(
        new TrackingBus(),
        new FixedResultProvider(malformedSuccessResult()),
        writer,
        new RecordingOpener()
      ));

      const outcome = await runtime.submit(SEARCH_QUERY);
      expect(outcome.ok).assertFalse();
      expect(outcome.status).assertEqual('error');
      expect(lastWriteContains(writer, '酒店数据格式无效')).assertTrue();
      expect(lastWriteContains(writer, '"id":"hotel.detail"')).assertFalse();
      runtime.dispose();
    });

    it('cancels an older provider turn before the next input and ignores its late result', 0, async () => {
      const bus = new TrackingBus();
      const provider = new FirstCallDelayedProvider();
      const visible: string[] = [];
      const runtime = new HotelAgentRuntime(options(
        bus,
        provider,
        new RecordingWriter(),
        new RecordingOpener(),
        (surface: A2uiSurfaceState): void => {
          visible.push(surface.surfaceId);
        }
      ));

      const first = runtime.submit(SEARCH_QUERY);
      await flush();
      const second = runtime.submit(SEARCH_QUERY);
      const firstOutcome = await first;
      expect(firstOutcome.status).assertEqual('canceled');
      const secondOutcome = await second;
      expect(secondOutcome.ok).assertTrue();
      const messages = bus.messages;
      let cancelIndex = -1;
      let secondInputIndex = -1;
      let inputCount = 0;
      for (let index = 0; index < messages.length; index++) {
        if (messages[index].type === AgentMessageType.TURN_CANCEL && cancelIndex < 0) {
          cancelIndex = index;
        }
        if (messages[index].type === AgentMessageType.INPUT_USER) {
          inputCount += 1;
          if (inputCount === 2) {
            secondInputIndex = index;
          }
        }
      }
      expect(cancelIndex >= 0 && cancelIndex < secondInputIndex).assertTrue();
      expect(visible[visible.length - 1]).assertEqual(secondOutcome.surfaceId);
      provider.firstGate.open();
      await flush(20);
      expect(visible[visible.length - 1]).assertEqual(secondOutcome.surfaceId);
      runtime.dispose();
    });

    it('does not reactivate an older surface after its delayed writer completes', 0, async () => {
      const bus = new TrackingBus();
      const writer = new DeferredFirstWriter();
      const visible: string[] = [];
      const runtime = new HotelAgentRuntime(options(
        bus,
        new FakeHotelProvider(),
        writer,
        new RecordingOpener(),
        (surface: A2uiSurfaceState): void => {
          visible.push(surface.surfaceId);
        }
      ));

      const first = runtime.submit(SEARCH_QUERY);
      await writer.started.promise;
      const second = runtime.submit(SEARCH_QUERY);
      expect((await first).status).assertEqual('canceled');
      const secondOutcome = await second;
      expect(secondOutcome.ok).assertTrue();
      expect(visible[visible.length - 1]).assertEqual(secondOutcome.surfaceId);
      writer.release.open();
      await flush(20);
      expect(visible[visible.length - 1]).assertEqual(secondOutcome.surfaceId);
      runtime.dispose();
    });

    it('clears saved hotel authority when a non-hotel prompt cancels the active turn', 0, async () => {
      const bus = new TrackingBus();
      const runtime = new HotelAgentRuntime(options(
        bus,
        new FakeHotelProvider(),
        new RecordingWriter(),
        new RecordingOpener()
      ));
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      runtime.cancelActiveTurn('non_hotel_prompt');
      expect(runtime.currentActionContext() === null).assertTrue();
      expect(runtime.restoreSearchSurface()).assertFalse();
      const cancels = messagesOf(bus, AgentMessageType.TURN_CANCEL);
      expect(cancels.length).assertEqual(1);
      runtime.dispose();
    });

    it('cancels promoted detail and saved search exactly once on non-hotel cancellation', 0, async () => {
      const bus = new TrackingBus();
      const provider = new DeferredDetailProvider();
      const visible: string[] = [];
      const runtime = new HotelAgentRuntime(options(
        bus,
        provider,
        new RecordingWriter(),
        new RecordingOpener(),
        (surface: A2uiSurfaceState): void => {
          visible.push(surface.surfaceId);
        }
      ));
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      const searchContext = runtime.currentActionContext();
      const running = runtime.runAction(
        hotelDetailAction(searchHotel(), searchRequest())
      );
      await provider.detailStarted.promise;
      const detailContext = runtime.currentActionContext();
      runtime.cancelActiveTurn('non_hotel_prompt');
      expect(await running).assertFalse();
      if (searchContext !== null && detailContext !== null) {
        expect(
          messageCountForTurn(bus, AgentMessageType.TURN_CANCEL, searchContext.turnId)
        ).assertEqual(1);
        expect(
          messageCountForTurn(bus, AgentMessageType.TURN_CANCEL, detailContext.turnId)
        ).assertEqual(1);
      }
      const visibleAtCancel = visible.length;
      provider.detailRelease.open();
      await flush(20);
      expect(visible.length).assertEqual(visibleAtCancel);
      runtime.dispose();
    });

    it('cancels both active detail and saved search exactly once during dispose', 0, async () => {
      const bus = new TrackingBus();
      const runtime = new HotelAgentRuntime(options(
        bus,
        new FakeHotelProvider(),
        new RecordingWriter(),
        new RecordingOpener()
      ));
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      const searchContext = runtime.currentActionContext();
      expect(await runtime.runAction(
        hotelDetailAction(searchHotel(), searchRequest())
      )).assertTrue();
      await flush(20);
      const detailContext = runtime.currentActionContext();
      expect(searchContext === null).assertFalse();
      expect(detailContext === null).assertFalse();
      runtime.dispose();
      if (searchContext !== null && detailContext !== null) {
        expect(
          messageCountForTurn(bus, AgentMessageType.TURN_CANCEL, searchContext.turnId)
        ).assertEqual(1);
        expect(
          messageCountForTurn(bus, AgentMessageType.TURN_CANCEL, detailContext.turnId)
        ).assertEqual(1);
      }
    });

    it('ignores spoofed UI terminal messages that do not match the exact surface identity', 0, async () => {
      const bus = new TrackingBus();
      const gate = new TestGate();
      const runtime = new HotelAgentRuntime(options(
        bus,
        new FakeHotelProvider(gate),
        new RecordingWriter(),
        new RecordingOpener()
      ));
      let settled = false;
      const submitted = runtime.submit(SEARCH_QUERY);
      submitted.then((_outcome: HotelTurnOutcome): void => {
        settled = true;
      });
      await flush();
      const inputMessage = messagesOf(bus, AgentMessageType.INPUT_USER)[0];
      const uiMessage = messagesOf(bus, AgentMessageType.TASK_CREATE_UI)[0];
      const spoofedUiResult: UiRenderResultPayload = {
        surfaceId: 'spoofed-surface',
        state: 'result'
      };
      bus.publish({
        type: AgentMessageType.TASK_RESULT_UI,
        conversationId: inputMessage.conversationId,
        turnId: inputMessage.turnId,
        taskId: uiMessage.taskId,
        payload: spoofedUiResult
      });
      await flush();
      expect(settled).assertFalse();
      gate.open();
      expect((await submitted).ok).assertTrue();
      runtime.dispose();
    });

    it('ignores spoofed action results with the wrong run identity', 0, async () => {
      const bus = new TrackingBus();
      const opener = new DeferredFirstOpener();
      const runtime = new HotelAgentRuntime(options(
        bus,
        new FakeHotelProvider(),
        new RecordingWriter(),
        opener
      ));
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      let settled = false;
      const running = runtime.runAction(hotelNavigateAction(searchHotel()));
      running.then((_ok: boolean): void => {
        settled = true;
      });
      await opener.started.promise;
      const actionRun = messagesOf(bus, AgentMessageType.ACTION_RUN)[0];
      const current = runtime.currentActionContext();
      const spoofedActionResult: ActionResultPayload = {
        surfaceId: current === null ? '' : current.surfaceId,
        planId: 'direct:spoofed-run',
        runId: 'spoofed-run',
        status: 'success',
        completedStepIds: ['step-1'],
        outputs: []
      };
      bus.publish({
        type: AgentMessageType.ACTION_RESULT,
        conversationId: actionRun.conversationId,
        turnId: actionRun.turnId,
        taskId: actionRun.taskId,
        payload: spoofedActionResult
      });
      await flush();
      expect(settled).assertFalse();
      opener.release.open();
      expect(await running).assertTrue();
      runtime.dispose();
    });

    it('restores the search document and authority before accepting hotel actions again', 0, async () => {
      const bus = new TrackingBus();
      const surfaces: A2uiSurfaceState[] = [];
      const runtime = new HotelAgentRuntime(options(
        bus,
        new FakeHotelProvider(),
        new RecordingWriter(),
        new RecordingOpener(),
        (surface: A2uiSurfaceState): void => {
          surfaces.push(surface);
        }
      ));
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      const query = searchRequest();
      const hotel = searchHotel();
      expect(await runtime.runAction(hotelDetailAction(hotel, query))).assertTrue();
      await flush(20);
      const detailContext = runtime.currentActionContext();
      expect(detailContext?.sourceToolId).assertEqual('hotel.detail');
      expect(runtime.restoreSearchSurface()).assertTrue();
      if (detailContext !== null) {
        expect(
          messageCountForTurn(bus, AgentMessageType.TURN_CANCEL, detailContext.turnId)
        ).assertEqual(1);
      }
      const restored = runtime.currentActionContext();
      expect(restored?.sourceToolId).assertEqual('hotel.search');
      const restoredSurface = surfaces[surfaces.length - 1];
      expect(restoredSurface.dataModelJson.indexOf('"toolName":"hotel.search"') >= 0).assertTrue();
      expect(restoredSurface.dataModelJson.indexOf('"dataLabel":"actionStatus"') < 0).assertTrue();
      if (detailContext !== null) {
        expect(await runtime.runAction(hotelNavigateAction(hotel), detailContext)).assertFalse();
      }
      expect(await runtime.runAction(hotelNavigateAction(hotel))).assertTrue();
      expect(await runtime.runAction(hotelDetailAction(hotel, query))).assertTrue();
      runtime.dispose();
    });

    it('times out a hanging writer and removes the timed-out turn before the next submit', 0, async () => {
      const writer = new DeferredFirstWriter();
      const runtime = new HotelAgentRuntime(options(
        new TrackingBus(),
        new FakeHotelProvider(),
        writer,
        new RecordingOpener(),
        undefined,
        20,
        1000
      ));
      const first = runtime.submit(SEARCH_QUERY);
      await writer.started.promise;
      const timedOut = await first;
      expect(timedOut.ok).assertFalse();
      expect(timedOut.status).assertEqual('timeout');
      const second = await runtime.submit(SEARCH_QUERY);
      expect(second.ok).assertTrue();
      writer.release.open();
      await flush();
      runtime.dispose();
    });

    it('times out a hanging opener and cancels the exact action turn', 0, async () => {
      const opener = new DeferredFirstOpener();
      const runtime = new HotelAgentRuntime(options(
        new TrackingBus(),
        new FakeHotelProvider(),
        new RecordingWriter(),
        opener,
        undefined,
        1000,
        20
      ));
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      const running = runtime.runAction(hotelNavigateAction(searchHotel()));
      await opener.started.promise;
      expect(await running).assertFalse();
      opener.release.open();
      await flush();
      expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      expect(await runtime.runAction(hotelNavigateAction(searchHotel()))).assertTrue();
      runtime.dispose();
    });

    it('settles writer and callback failures without leaving a pending submit', 0, async () => {
      const writerFailure = new HotelAgentRuntime(options(
        new TrackingBus(),
        new FakeHotelProvider(),
        new ThrowingWriter(),
        new RecordingOpener()
      ));
      const writerOutcome = await writerFailure.submit(SEARCH_QUERY);
      expect(writerOutcome.ok).assertFalse();
      expect(writerOutcome.status).assertEqual('error');
      writerFailure.dispose();

      const callbackFailure = new HotelAgentRuntime(options(
        new TrackingBus(),
        new FakeHotelProvider(),
        new RecordingWriter(),
        new RecordingOpener(),
        (_surface: A2uiSurfaceState): void => {
          throw new Error('callback failed');
        }
      ));
      const callbackOutcome = await callbackFailure.submit(SEARCH_QUERY);
      expect(callbackOutcome.ok).assertFalse();
      expect(callbackOutcome.status).assertEqual('error');
      callbackFailure.dispose();
    });

    it('disposes pending work and ignores the provider completion after teardown', 0, async () => {
      const gate = new TestGate();
      const provider = new FakeHotelProvider(gate);
      let visibleCount = 0;
      const runtime = new HotelAgentRuntime(options(
        new TrackingBus(),
        provider,
        new RecordingWriter(),
        new RecordingOpener(),
        (_surface: A2uiSurfaceState): void => {
          visibleCount += 1;
        }
      ));
      const running = runtime.submit(SEARCH_QUERY);
      await flush();
      expect(provider.calls.length).assertEqual(1);
      runtime.dispose();
      const disposedOutcome = await running;
      expect(disposedOutcome.status).assertEqual('canceled');
      const countAtDispose = visibleCount;
      gate.open();
      await flush(20);
      expect(visibleCount).assertEqual(countAtDispose);
      expect(runtime.retainedSurfaceCount()).assertEqual(0);
    });

    it('keeps retained surface history bounded and rejects submits after dispose', 0, async () => {
      const runtime = new HotelAgentRuntime(options(
        new TrackingBus(),
        new FakeHotelProvider(),
        new RecordingWriter(),
        new RecordingOpener()
      ));
      for (let index = 0; index < 24; index++) {
        expect((await runtime.submit(SEARCH_QUERY)).ok).assertTrue();
      }
      expect(runtime.retainedSurfaceCount() <= 20).assertTrue();
      const context = runtime.currentActionContext();
      expect(context?.sourceToolId).assertEqual('hotel.search');
      runtime.dispose();
      expect(runtime.retainedSurfaceCount()).assertEqual(0);
      const afterDispose = await runtime.submit(SEARCH_QUERY);
      expect(afterDispose.ok).assertFalse();
      expect(afterDispose.status).assertEqual('canceled');
    });

    it('bounds retained records while every surface writer remains unresolved', 0, async () => {
      const writer = new NeverSettlingWriter();
      const runtime = new HotelAgentRuntime(options(
        new TrackingBus(),
        new FakeHotelProvider(),
        writer,
        new RecordingOpener(),
        undefined,
        10,
        1000
      ));
      for (let index = 0; index < 24; index++) {
        const timedOut = await runtime.submit(SEARCH_QUERY);
        expect(timedOut.status).assertEqual('timeout');
        expect(runtime.retainedSurfaceCount() <= 20).assertTrue();
      }
      expect(writer.writesStarted >= 24).assertTrue();
      runtime.dispose();
      expect(runtime.retainedSurfaceCount()).assertEqual(0);
    });
  });
}
