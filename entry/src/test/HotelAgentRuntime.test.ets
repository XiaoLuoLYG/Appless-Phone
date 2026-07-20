import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  A2uiAction,
  CreateDataTaskPayload,
  DataResult,
  DataTaskExecutor,
  HotelDetailRequest,
  HotelDetailResult,
  HotelRatePlan,
  HotelSearchItem,
  HotelSearchRequest,
  HotelSearchResult,
  LinkedMessageBus,
  LocalModel,
  UiSurfaceWriteLease,
  UiSurfaceWriter,
  hotelCallAction,
  hotelDetailAction,
  hotelNavigateAction,
  hotelSearchDataResult,
  parseHotelSearchRequest
} from '@loop/agent-core';
import {
  HotelActionContext,
  HotelAgentRuntime,
  HotelAgentRuntimeOptions
} from '../main/ets/pages/A2uiHome/agent/HotelAgentRuntime';
import { SystemUriOpener } from '../main/ets/pages/A2uiHome/agent/HotelRegisteredActionExecutor';

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

function searchHotel(): HotelSearchItem {
  return {
    hotelId: 47675,
    bookingUrl: 'https://hotel.example/47675',
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
    tags: ['商务'],
    contact: {
      displayPhone: '+86 755 1234 5678',
      dialPhone: '+8675512345678',
      provider: 'Google Places',
      providerPlaceId: 'places/ChIJ-real-hotel'
    }
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

function options(
  bus: TrackingBus,
  provider: FakeHotelProvider,
  writer: UiSurfaceWriter,
  opener: RecordingOpener
): HotelAgentRuntimeOptions {
  return {
    model: new FixedHotelModel(),
    currentLocalDate: (): string => '2026-07-20',
    dataExecutor: provider,
    writer: writer,
    opener: opener,
    bus: bus,
    conversationId: 'hotel-page-session'
  };
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
      expect(bus.readerCountAtInput >= 4).assertTrue();
      expect(writer.writes.length).assertEqual(1);
      expect(writer.writes[0].jsonl.indexOf('RollingGo')).assertLarger(-1);
      expect(writer.writes[0].jsonl.indexOf('pending')).assertLarger(-1);
      expect(writer.writes[0].jsonl.indexOf('hotel.detail')).assertEqual(-1);
      gate.open();
      expect(await submitted).assertTrue();
      await flush();

      expect(writer.writes.length >= 2).assertTrue();
      expect(writer.writes[0].surfaceId).assertEqual(writer.writes[1].surfaceId);
      expect(writer.writes[1].jsonl.indexOf('深圳测试酒店')).assertLarger(-1);
      const uiTasks = messagesOf(bus, AgentMessageType.TASK_CREATE_UI);
      const dataTasks = messagesOf(bus, AgentMessageType.TASK_CREATE_DATA);
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
      expect(await submitted).assertTrue();
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
      expect(await runtime.submit(SEARCH_QUERY)).assertTrue();
      await flush();

      const parsedQuery = parseHotelSearchRequest(JSON.parse(SEARCH_JSON) as Object);
      if (parsedQuery.value === null) {
        runtime.stop();
        return;
      }
      const query = parsedQuery.value;
      const hotel = searchHotel();
      expect(await runtime.runAction(hotelNavigateAction(hotel))).assertTrue();
      expect(await runtime.runAction(hotelCallAction(hotel))).assertTrue();
      expect(opener.uris.length).assertEqual(2);
      expect(opener.uris[0].indexOf('petalmaps://')).assertEqual(0);
      expect(opener.uris[1]).assertEqual('tel:+8675512345678');

      const detailAction = hotelDetailAction(hotel, query);
      const oldTurn = messagesOf(bus, AgentMessageType.INPUT_USER)[0].turnId;
      expect(await runtime.runAction(detailAction)).assertTrue();
      await flush(20);

      const actionRuns = messagesOf(bus, AgentMessageType.ACTION_RUN);
      expect(actionRuns.length).assertEqual(3);
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

    it('rejects modified args and an action replayed after a newer turn', 0, async () => {
      const bus = new TrackingBus();
      const provider = new FakeHotelProvider();
      const writer = new RecordingWriter();
      const opener = new RecordingOpener();
      const runtime = new HotelAgentRuntime(options(bus, provider, writer, opener));
      expect(await runtime.submit(SEARCH_QUERY)).assertTrue();
      await flush();

      const original: A2uiAction = hotelNavigateAction(searchHotel());
      const oldContext: HotelActionContext | null = runtime.currentActionContext();
      const tampered: A2uiAction = hotelNavigateAction(searchHotel());
      const tamperedArgs = tampered.args as Record<string, Object | string | number | boolean | null | undefined>;
      tamperedArgs.latitude = 23.1;
      expect(await runtime.runAction(tampered)).assertFalse();
      expect(opener.uris.length).assertEqual(0);

      expect(await runtime.submit(SEARCH_QUERY)).assertTrue();
      await flush();
      if (oldContext === null) {
        runtime.stop();
        return;
      }
      expect(await runtime.runAction(original, oldContext)).assertFalse();
      expect(opener.uris.length).assertEqual(0);
      runtime.stop();
    });
  });
}
