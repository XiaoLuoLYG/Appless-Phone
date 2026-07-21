import { describe, expect, it } from '@ohos/hypium';
import {
  A2uiAction,
  A2uiSurfaceState,
  AgentMessage,
  AgentMessageType,
  CreateDataTaskPayload,
  DataResult,
  DataTaskExecutor,
  HotelDetailRequest,
  HotelDetailResult,
  HotelRatePlan,
  HotelSearchItem,
  HotelSearchRequest,
  HotelSearchResult,
  LocalModel,
  LinkedMessageBus,
  UiSurfaceWriteLease,
  UiSurfaceWriter,
  hotelSearchDataResult,
  parseHotelSearchRequest
} from '@loop/agent-core';
import { PersonaMemoryUpdateRequest } from '../main/ets/model/PersonaMemoryUpdate';
import {
  MultiAgentCanaryOptions,
  MultiAgentCanaryRuntime
} from '../main/ets/pages/A2uiHome/agent/MultiAgentCanaryRuntime';
import { SystemUriOpener } from '../main/ets/pages/A2uiHome/agent/HotelRegisteredActionExecutor';
import { MultiAgentSettledOutcome } from '../main/ets/pages/A2uiHome/agent/MultiAgentRuntimeTypes';
import { createHtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeSnapshot';
import { HtmlHomeAction, HtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeTypes';

const SEARCH_TEXT: string = '帮我找深圳酒店';
const SEARCH_INPUT: string = '{"originQuery":"帮我找深圳酒店","place":"深圳",' +
  '"placeType":"CITY","countryCode":"CN","checkInDate":"2026-08-15",' +
  '"stayNights":2,"adultCount":2,"childCount":0,"childAgeDetails":[],' +
  '"roomCount":1,"currency":"CNY","size":10}';
const ANSWER_DECISION: string = '{"personaId":"default_companion","skillId":"",' +
  '"roundAction":"answer","dataTasks":[],"uiIntent":{"purpose":"conversation",' +
  '"preferredDensity":"comfortable","requiredSections":[]},"answer":"你好",' +
  '"reasonCode":"greeting"}';
const MEMORY_DECISION: string = '{"personaId":"food_companion","skillId":"",' +
  '"roundAction":"execute","dataTasks":[],"uiIntent":{"purpose":"memory.update",' +
  '"preferredDensity":"comfortable","requiredSections":[]},"actionIntent":{' +
  '"goal":"remember explicit preference","allowedActionIds":["memory.update"]},' +
  '"reasonCode":"stable_preference"}';
const HOTEL_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"roundAction":"execute","dataTasks":[{"localId":"hotel-search",' +
  '"goal":"search real hotels","allowedToolIds":["hotel.search"],' +
  '"toolId":"hotel.search","input":' + SEARCH_INPUT + ',"required":true}],' +
  '"uiIntent":{"purpose":"hotel.search","preferredDensity":"comfortable",' +
  '"requiredSections":["hotels"]},"reasonCode":"hotel_search"}';
const HOTEL_DONE_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"roundAction":"answer","dataTasks":[],"uiIntent":{"purpose":"hotel.search",' +
  '"preferredDensity":"comfortable","requiredSections":[]},' +
  '"answer":"酒店结果已就绪","reasonCode":"hotel_ready"}';

class QueueModel implements LocalModel {
  private readonly outputs: string[];

  constructor(outputs: string[]) {
    this.outputs = outputs.slice();
  }

  async complete(_prompt: string): Promise<string> {
    if (this.outputs.length === 0) {
      throw new Error('No scripted canary Leader output.');
    }
    return this.outputs.shift() as string;
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

class CanaryHotelExecutor implements DataTaskExecutor {
  readonly calls: string[] = [];
  readonly detailStarted: TestGate = new TestGate();
  readonly detailRelease: TestGate = new TestGate();

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls.push(task.toolId);
    if (task.toolId === 'hotel.detail') {
      this.detailStarted.open();
      await this.detailRelease.promise;
      return detailData(task.args as HotelDetailRequest);
    }
    const parsed = parseHotelSearchRequest(task.args);
    if (parsed.value === null) {
      throw new Error('Invalid canary hotel search task.');
    }
    return hotelSearchDataResult(searchResult(parsed.value), []);
  }
}

class RecordingOpener implements SystemUriOpener {
  readonly uris: string[] = [];

  async open(uri: string): Promise<boolean> {
    this.uris.push(uri);
    return true;
  }
}

class RecordingWriter implements UiSurfaceWriter {
  writes: number = 0;

  async write(
    _turnId: string,
    _surfaceId: string,
    _jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void> {
    if (lease.isActive()) {
      this.writes++;
    }
  }
}

class TrackingBus extends LinkedMessageBus {
  readonly messages: AgentMessage[] = [];

  publish(message: AgentMessage): void {
    this.messages.push(message);
    super.publish(message);
  }

  count(type: AgentMessageType): number {
    let total = 0;
    this.messages.forEach((message: AgentMessage) => {
      if (message.type === type) {
        total++;
      }
    });
    return total;
  }
}

function searchRequest(): HotelSearchRequest {
  const parsed = parseHotelSearchRequest(JSON.parse(SEARCH_INPUT) as Object);
  if (parsed.value === null) {
    throw new Error('Invalid hotel search fixture.');
  }
  return parsed.value;
}

function hotelItem(): HotelSearchItem {
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
    price: { message: '2 晚参考价', hasPrice: true, currency: 'CNY', lowestPrice: 1100 },
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
    query,
    hotels: [hotelItem()]
  };
}

function detailResult(query: HotelDetailRequest): HotelDetailResult {
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
  return {
    ok: true,
    error: '',
    message: '实时房型',
    query,
    hotelId: query.hotelId,
    bookingUrl: hotelItem().bookingUrl,
    name: '深圳测试酒店',
    nameEn: 'Shenzhen Test Hotel',
    checkIn: query.checkInDate,
    checkOut: query.checkOutDate,
    rates: [rate]
  };
}

function detailData(query: HotelDetailRequest): DataResult {
  return {
    toolId: 'hotel.detail',
    outputSchema: 'hotelRatePlans',
    status: 'success',
    sources: [],
    data: detailResult(query),
    warnings: []
  };
}

function canaryOptions(
  model: LocalModel,
  executor: DataTaskExecutor,
  opener: SystemUriOpener,
  surfaces: A2uiSurfaceState[],
  updates: PersonaMemoryUpdateRequest[],
  bus?: LinkedMessageBus,
  actionTimeoutMs: number = 1000
): MultiAgentCanaryOptions {
  return {
    model,
    selectedPersonaId: (): string => 'travel_companion',
    opener,
    onSurface: (surface: A2uiSurfaceState): void => {
      surfaces.push(surface);
    },
    onMemoryUpdate: (update: PersonaMemoryUpdateRequest): void => {
      updates.push(update);
    },
    dataExecutor: executor,
    bus,
    conversationId: 'canary-test',
    downstreamWriter: new RecordingWriter(),
    submitTimeoutMs: 1000,
    actionTimeoutMs
  };
}

async function flush(rounds: number = 12): Promise<void> {
  for (let index = 0; index < rounds; index++) {
    await new Promise<void>((resolve: () => void) => setTimeout(resolve, 0));
  }
}

function renderedAction(surface: A2uiSurfaceState, actionId: string): A2uiAction | null {
  const document: HtmlHomeDocument = createHtmlHomeDocument({
    surface,
    messages: [],
    isBusy: false,
    isAwaitingFirstSurface: false
  });
  const candidates: HtmlHomeAction[] = document.actions.slice();
  document.blocks.forEach((block) => {
    candidates.push(...block.actions);
  });
  for (let index = 0; index < candidates.length; index++) {
    const candidate = candidates[index];
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
  return null;
}

export default function multiAgentCanaryRuntimeTest() {
  describe('multiAgentCanaryRuntime', () => {
    it('owns C01 greeting without a tool surface', 0, async () => {
      const surfaces: A2uiSurfaceState[] = [];
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        new QueueModel([ANSWER_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        surfaces,
        []
      ));

      const outcome = await runtime.submit('你好', { text: '' }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(outcome.message).assertEqual('你好');
      expect(surfaces.length).assertEqual(0);
      runtime.dispose();
    });

    it('owns C11 as one virtual memory action and renders the real update', 0, async () => {
      const updates: PersonaMemoryUpdateRequest[] = [];
      const surfaces: A2uiSurfaceState[] = [];
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        new QueueModel([MEMORY_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        surfaces,
        updates
      ));

      const outcome = await runtime.submit('我只喝瑞幸咖啡', {
        text: '',
        previousPersonaId: 'food_companion'
      }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(updates.length).assertEqual(1);
      expect(updates[0].personaId).assertEqual('food_companion');
      expect(updates[0].memoryText.indexOf('我只喝瑞幸咖啡') >= 0).assertTrue();
      expect(surfaces.length).assertEqual(1);
      runtime.dispose();
    });

    it('keeps C20 search navigation detail booking and return under the canary runtime', 0, async () => {
      const executor = new CanaryHotelExecutor();
      const opener = new RecordingOpener();
      const bus = new TrackingBus();
      const surfaces: A2uiSurfaceState[] = [];
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        new QueueModel([HOTEL_DECISION, HOTEL_DONE_DECISION]),
        executor,
        opener,
        surfaces,
        [],
        bus
      ));

      const outcome = await runtime.submit(SEARCH_TEXT, { text: '' }) as MultiAgentSettledOutcome;
      const searchContext = runtime.currentActionContext();
      expect(outcome.status).assertEqual('success');
      expect(searchContext?.sourceToolId).assertEqual('hotel.search');
      expect(executor.calls.join(',')).assertEqual('hotel.search');

      const navigate = renderedAction(surfaces[surfaces.length - 1], 'hotel.navigate');
      expect(navigate === null).assertFalse();
      expect(await runtime.runAction(navigate!, searchContext!)).assertTrue();
      expect(opener.uris[0].indexOf('petalmaps://')).assertEqual(0);
      expect(runtime.restoreSearchSurface()).assertTrue();
      const restoredSearchContext = runtime.currentActionContext();
      expect(restoredSearchContext?.sourceToolId).assertEqual('hotel.search');

      const detail = renderedAction(surfaces[surfaces.length - 1], 'hotel.detail');
      expect(detail === null).assertFalse();
      let detailSettled = false;
      const detailPending = runtime.runAction(detail!, restoredSearchContext!);
      detailPending.then((_ok: boolean): void => {
        detailSettled = true;
      });
      await executor.detailStarted.promise;
      await flush();
      expect(bus.count(AgentMessageType.TASK_CREATE_UI)).assertEqual(2);
      expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(2);
      expect(detailSettled).assertFalse();
      executor.detailRelease.open();
      expect(await detailPending).assertTrue();

      const detailContext = runtime.currentActionContext();
      expect(detailContext?.sourceToolId).assertEqual('hotel.detail');
      const booking = renderedAction(surfaces[surfaces.length - 1], 'hotel.booking.open');
      expect(booking === null).assertFalse();
      expect(await runtime.runAction(booking!, detailContext!)).assertTrue();
      expect(opener.uris[opener.uris.length - 1].indexOf('https://rollinggo.cn/')).assertEqual(0);

      expect(runtime.restoreSearchSurface()).assertTrue();
      expect(runtime.currentActionContext()?.sourceToolId).assertEqual('hotel.search');
      runtime.dispose();
    });

    it('cancels and times out the exact C20 child turn without a late success', 1000, async () => {
      const timeoutExecutor = new CanaryHotelExecutor();
      const timeoutBus = new TrackingBus();
      const timeoutSurfaces: A2uiSurfaceState[] = [];
      const timeoutRuntime = new MultiAgentCanaryRuntime(canaryOptions(
        new QueueModel([HOTEL_DECISION, HOTEL_DONE_DECISION]),
        timeoutExecutor,
        new RecordingOpener(),
        timeoutSurfaces,
        [],
        timeoutBus,
        20
      ));
      await timeoutRuntime.submit(SEARCH_TEXT, { text: '' });
      const timeoutDetail = renderedAction(
        timeoutSurfaces[timeoutSurfaces.length - 1],
        'hotel.detail'
      );
      const timedOut = timeoutRuntime.runAction(
        timeoutDetail!,
        timeoutRuntime.currentActionContext()!
      );
      await timeoutExecutor.detailStarted.promise;
      expect(await timedOut).assertFalse();
      expect(timeoutBus.count(AgentMessageType.TURN_CANCEL) >= 2).assertTrue();
      timeoutExecutor.detailRelease.open();
      await flush();
      timeoutRuntime.dispose();

      const cancelExecutor = new CanaryHotelExecutor();
      const cancelBus = new TrackingBus();
      const cancelSurfaces: A2uiSurfaceState[] = [];
      const cancelRuntime = new MultiAgentCanaryRuntime(canaryOptions(
        new QueueModel([HOTEL_DECISION, HOTEL_DONE_DECISION]),
        cancelExecutor,
        new RecordingOpener(),
        cancelSurfaces,
        [],
        cancelBus
      ));
      await cancelRuntime.submit(SEARCH_TEXT, { text: '' });
      const cancelDetail = renderedAction(
        cancelSurfaces[cancelSurfaces.length - 1],
        'hotel.detail'
      );
      const canceled = cancelRuntime.runAction(
        cancelDetail!,
        cancelRuntime.currentActionContext()!
      );
      await cancelExecutor.detailStarted.promise;
      cancelRuntime.cancelActiveTurn('user_cancel');
      expect(await canceled).assertFalse();
      expect(cancelBus.count(AgentMessageType.TURN_CANCEL) >= 2).assertTrue();
      cancelExecutor.detailRelease.open();
      await flush();
      cancelRuntime.dispose();
    });
  });
}
