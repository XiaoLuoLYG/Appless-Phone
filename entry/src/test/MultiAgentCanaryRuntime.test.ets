import { describe, expect, it } from '@ohos/hypium';
import {
  A2uiAction,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  ActionExecutionContext,
  ActionExecutionResult,
  AgentMessage,
  AgentMessageType,
  CreateDataTaskPayload,
  DataResult,
  DataTaskExecutor,
  DynamicGenericToolResult,
  HotelDetailRequest,
  HotelDetailResult,
  HotelRatePlan,
  HotelSearchItem,
  HotelSearchRequest,
  HotelSearchResult,
  JsonValue,
  LocalModel,
  LinkedMessageBus,
  UiSurfaceWriteLease,
  UiSurfaceWriter,
  createSeedA2uiSurface,
  hotelSearchDataResult,
  parseHotelSearchRequest,
  setJsonPointer
} from '@loop/agent-core';
import { PersonaMemoryUpdateRequest } from '../main/ets/model/PersonaMemoryUpdate';
import {
  configureDefaultPersonaStoreForTests,
  personaPackForId,
  updatePersonaPackText
} from '../main/ets/model/PersonaStore';
import {
  MultiAgentCanaryOptions,
  MultiAgentCanaryRuntime
} from '../main/ets/pages/A2uiHome/agent/MultiAgentCanaryRuntime';
import { SystemUriOpener } from '../main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor';
import { MultiAgentSettledOutcome } from '../main/ets/pages/A2uiHome/agent/MultiAgentRuntimeTypes';
import { createHtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeSnapshot';
import { HtmlHomeAction, HtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeTypes';
import {
  RegisteredPageSnapshot,
  registeredPageSourceToolId
} from '../main/ets/pages/A2uiHome/agent/RegisteredPageActionRoute';

const SEARCH_TEXT: string = '帮我找深圳酒店';
const SEARCH_INPUT: string = '{"originQuery":"帮我找深圳酒店","place":"深圳",' +
  '"placeType":"CITY","countryCode":"CN","checkInDate":"2026-08-15",' +
  '"stayNights":2,"adultCount":2,"childCount":0,"childAgeDetails":[],' +
  '"roomCount":1,"currency":"CNY","size":10}';
const ANSWER_DECISION: string = '{"personaId":"default_companion","skillId":"",' +
  '"requestedCapabilityIds":[],"roundAction":"answer","dataTasks":[],' +
  '"uiIntent":{"purpose":"conversation",' +
  '"preferredDensity":"comfortable","requiredSections":[]},"answer":"你好",' +
  '"reasonCode":"greeting"}';
const MEMORY_DECISION: string = '{"personaId":"food_companion","skillId":"",' +
  '"requestedCapabilityIds":["memory.update"],"roundAction":"execute","dataTasks":[],' +
  '"uiIntent":{"purpose":"memory.update",' +
  '"preferredDensity":"comfortable","requiredSections":[]},"actionIntent":{' +
  '"goal":"remember explicit preference","allowedActionIds":["memory.update"]},' +
  '"reasonCode":"stable_preference"}';
const HOTEL_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["hotel.search"],"roundAction":"execute",' +
  '"dataTasks":[{"localId":"hotel-search",' +
  '"goal":"search real hotels","allowedToolIds":["hotel.search"],' +
  '"toolId":"hotel.search","input":' + SEARCH_INPUT + ',"required":true}],' +
  '"uiIntent":{"purpose":"hotel.search","preferredDensity":"comfortable",' +
  '"requiredSections":["hotels"]},"reasonCode":"hotel_search"}';
const HOTEL_DONE_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["hotel.search"],"roundAction":"answer","dataTasks":[],' +
  '"uiIntent":{"purpose":"hotel.search",' +
  '"preferredDensity":"comfortable","requiredSections":[]},' +
  '"answer":"酒店结果已就绪","reasonCode":"hotel_ready"}';
const TWO_TOOL_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search","train.search"],"roundAction":"execute",' +
  '"dataTasks":[{"localId":"travel","goal":"search travel options",' +
  '"allowedToolIds":["travel.search"],"toolId":"travel.search",' +
  '"input":{"query":"北京到上海"},"required":true},{"localId":"train",' +
  '"goal":"search trains","allowedToolIds":["train.search"],"toolId":"train.search",' +
  '"input":{"query":"北京到上海"},"required":true}],' +
  '"uiIntent":{"purpose":"travel.compare","preferredDensity":"comfortable",' +
  '"requiredSections":["travel","train"]},"reasonCode":"two_tool_compare"}';
const TWO_TOOL_DONE_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search","train.search"],"roundAction":"answer",' +
  '"dataTasks":[],"uiIntent":{"purpose":"travel.compare",' +
  '"preferredDensity":"comfortable","requiredSections":[]},' +
  '"answer":"出行结果已就绪","reasonCode":"two_tool_ready"}';
const C02_QUERY: string = '我明天要从北京去上海，帮我搜索出行方案';
const F01_QUERY: string = '帮我查明天北京到上海的航班';
const F02_QUERY: string = '帮我查询明天晚上六点以后深圳北到香港西九龙的高铁';
const C02_QUERY_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search"],"roundAction":"execute",' +
  '"dataTasks":[{"localId":"travel","goal":"搜索从北京到上海的出行方案",' +
  '"allowedToolIds":["travel.search"],"toolId":"travel.search",' +
  '"input":{"origin":"北京","destination":"上海","departureDate":"2026-07-23",' +
  '"query":"模型伪造的后天广州到深圳"},"required":true}],' +
  '"uiIntent":{"purpose":"travel.search","preferredDensity":"comfortable",' +
  '"requiredSections":["travel"]}}';
const C02_QUERY_DONE: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search"],"roundAction":"answer","dataTasks":[],' +
  '"uiIntent":{"purpose":"travel.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"综合出行结果已就绪"}';
const F01_QUERY_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["flight.search"],"roundAction":"execute",' +
  '"dataTasks":[{"localId":"flight","goal":"搜索北京到上海的航班",' +
  '"allowedToolIds":["flight.search"],"toolId":"flight.search",' +
  '"input":{"origin":"北京","destination":"上海","departureDate":"2026-07-23",' +
  '"query":"模型伪造的下周航班"},"required":true}],' +
  '"uiIntent":{"purpose":"flight.search","preferredDensity":"comfortable",' +
  '"requiredSections":["flight"]}}';
const F01_QUERY_DONE: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["flight.search"],"roundAction":"answer","dataTasks":[],' +
  '"uiIntent":{"purpose":"flight.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"航班结果已就绪"}';
const F02_QUERY_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["train.search"],"roundAction":"execute",' +
  '"dataTasks":[{"localId":"train","goal":"搜索深圳北到香港西九龙的高铁",' +
  '"allowedToolIds":["train.search"],"toolId":"train.search",' +
  '"input":{"origin":"深圳北","destination":"香港西九龙","departureDate":"2026-07-23",' +
  '"query":"模型伪造的全天火车"},"required":true}],' +
  '"uiIntent":{"purpose":"train.search","preferredDensity":"comfortable",' +
  '"requiredSections":["train"]}}';
const F02_QUERY_DONE: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["train.search"],"roundAction":"answer","dataTasks":[],' +
  '"uiIntent":{"purpose":"train.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"高铁结果已就绪"}';
const WORLDCUP_ACTION_DECISION: string = '{"personaId":"default_companion","skillId":"",' +
  '"requestedCapabilityIds":["worldcup.open"],"roundAction":"execute","dataTasks":[],' +
  '"uiIntent":{"purpose":"worldcup.open","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"actionIntent":{"goal":"open the World Cup page",' +
  '"allowedActionIds":["worldcup.open"]},"reasonCode":"worldcup_action"}';
const MAPS_ACTION_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["maps.route.open"],"roundAction":"execute","dataTasks":[],' +
  '"uiIntent":{"purpose":"maps.route.open","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"actionIntent":{"goal":"open the requested map route",' +
  '"allowedActionIds":["maps.route.open"]},"reasonCode":"maps_action"}';
const CALENDAR_CREATE_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.event.create"],"roundAction":"execute","dataTasks":[],' +
  '"uiIntent":{"purpose":"calendar.event.create","preferredDensity":"comfortable",' +
  '"requiredSections":["review"]},"actionIntent":{"goal":"review an exact Calendar event",' +
  '"allowedActionIds":["calendar.event.create"]},"reasonCode":"calendar_create_review"}';
const CALENDAR_UPDATE_SEARCH_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.events.search"],"roundAction":"execute",' +
  '"dataTasks":[{"localId":"calendar-search","goal":"find the exact current event",' +
  '"allowedToolIds":["calendar.events.search"],"toolId":"calendar.events.search",' +
  '"input":{"query":"产品评审","eventId":"model-forged",' +
  '"requestedAction":{"eventId":"model-forged","title":"forged"}},"required":true}],' +
  '"uiIntent":{"purpose":"calendar.event.update","preferredDensity":"comfortable",' +
  '"requiredSections":["events","review"]},"reasonCode":"calendar_update_read_first"}';
const CALENDAR_UPDATE_DONE_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.events.search"],"roundAction":"answer","dataTasks":[],' +
  '"uiIntent":{"purpose":"calendar.event.update","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"已找到唯一日程，请在卡片中核对并确认更新。",' +
  '"reasonCode":"calendar_update_review_ready"}';
const MAIL_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["mail.search"],"roundAction":"execute",' +
  '"dataTasks":[{"localId":"mail-search",' +
  '"goal":"search real mail","allowedToolIds":["mail.search"],' +
  '"toolId":"mail.search","input":{"query":"酒店确认"},"required":true}],' +
  '"uiIntent":{"purpose":"mail.search","preferredDensity":"comfortable",' +
  '"requiredSections":["mail"]},"reasonCode":"mail_search"}';
const DYNAMIC_READ_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["dynamic.search"],"roundAction":"execute",' +
  '"dataTasks":[{"localId":"dynamic-read","goal":"find the selected Notion page",' +
  '"allowedToolIds":["dynamic.search"],"toolId":"dynamic.search",' +
  '"input":{"operation":"search","qualifiedName":"NOTION_SEARCH",' +
  '"schema":{"type":"object"},"receipt":"turn-dynamic-1"},"required":true}],' +
  '"uiIntent":{"purpose":"dynamic.search","preferredDensity":"comfortable",' +
  '"requiredSections":["results"]},"reasonCode":"dynamic_read"}';
const DYNAMIC_READ_DONE: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["dynamic.search"],"roundAction":"answer","dataTasks":[],' +
  '"uiIntent":{"purpose":"dynamic.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"已返回授权 Notion 的读取结果。",' +
  '"reasonCode":"dynamic_read_done"}';
const WEATHER_HANDOFF_DECISION: string = '{"personaId":"default_companion","skillId":"",' +
  '"requestedCapabilityIds":["dynamic.search"],"roundAction":"legacy_handoff","dataTasks":[],' +
  '"uiIntent":{"purpose":"weather","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"reasonCode":"capability_unavailable"}';
const FOOD_CONTEXT_ANSWER: string = '{"personaId":"food_companion","skillId":"",' +
  '"requestedCapabilityIds":[],"roundAction":"answer","dataTasks":[],' +
  '"uiIntent":{"purpose":"conversation",' +
  '"preferredDensity":"comfortable","requiredSections":[]},' +
  '"answer":"已按更新后的瑞幸偏好继续","reasonCode":"memory_context_routed"}';
const MAIL_DIRECT_ANSWER: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["mail.search"],"roundAction":"answer","dataTasks":[],' +
  '"uiIntent":{"purpose":"mail.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"你有一封酒店确认邮件","reasonCode":"mail_search"}';
const WEATHER_DIRECT_CLARIFY: string = '{"personaId":"default_companion","skillId":"",' +
  '"requestedCapabilityIds":["dynamic.search"],"roundAction":"clarify","dataTasks":[],' +
  '"uiIntent":{"purpose":"weather","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"请确认天气地点","reasonCode":"weather_missing_location"}';
const MISLEADING_HOTEL_DIRECT_ANSWER: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["mail.search"],"roundAction":"answer","dataTasks":[],' +
  '"uiIntent":{"purpose":"mail.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"按邮件能力回答","reasonCode":"mail_search"}';
const UNOBSERVED_HOTEL_DIRECT_ANSWER: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["hotel.search"],"roundAction":"answer","dataTasks":[],' +
  '"uiIntent":{"purpose":"hotel.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"酒店价格是 500 元","reasonCode":"hotel_ready"}';

class QueueModel implements LocalModel {
  readonly prompts: string[] = [];
  private readonly outputs: string[];

  constructor(outputs: string[]) {
    this.outputs = outputs.slice();
  }

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    if (this.outputs.length === 0) {
      throw new Error('No scripted canary Leader output.');
    }
    return this.outputs.shift() as string;
  }
}

class MemoryAwareModel implements LocalModel {
  readonly prompts: string[] = [];
  secondTurnUsedUpdatedFoodContext: boolean = false;

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    if (this.prompts.length === 1) {
      return MEMORY_DECISION;
    }
    const foodStart: number = prompt.indexOf('{"personaId":"food_companion"');
    const nextPersona: number = foodStart < 0 ? -1 : prompt.indexOf('},{"personaId"', foodStart);
    const foodContext: string = foodStart < 0 ? '' : prompt.substring(
      foodStart,
      nextPersona < 0 ? prompt.length : nextPersona
    );
    this.secondTurnUsedUpdatedFoodContext =
      foodContext.indexOf('我只喝瑞幸咖啡') >= 0 &&
        foodContext.indexOf('"previous":true') >= 0;
    return this.secondTurnUsedUpdatedFoodContext ? FOOD_CONTEXT_ANSWER : ANSWER_DECISION;
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

class GatedModel implements LocalModel {
  readonly started: TestGate = new TestGate();
  readonly release: TestGate = new TestGate();
  private readonly output: string;

  constructor(output: string) {
    this.output = output;
  }

  async complete(_prompt: string): Promise<string> {
    this.started.open();
    await this.release.promise;
    return this.output;
  }
}

class CanaryHotelExecutor implements DataTaskExecutor {
  readonly calls: string[] = [];
  readonly tasks: CreateDataTaskPayload[] = [];
  readonly detailStarted: TestGate = new TestGate();
  readonly detailRelease: TestGate = new TestGate();

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls.push(task.toolId);
    this.tasks.push(task);
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

class TwoToolExecutor implements DataTaskExecutor {
  readonly calls: string[] = [];

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls.push(task.toolId);
    const data: Object = task.toolId === 'travel.search' ? JSON.parse(
      '{"title":"出行方案","body":"真实出行结果","summary":"1 result",' +
        '"options":[],"rows":[]}'
    ) as Object : JSON.parse(
      '{"title":"高铁方案","body":"真实高铁结果","summary":"1 result","trains":[]}'
    ) as Object;
    return {
      toolId: task.toolId,
      outputSchema: task.outputSchema,
      status: 'success',
      sources: [],
      data,
      warnings: []
    };
  }
}

class RecordingDynamicExecutor implements DataTaskExecutor {
  readonly tasks: CreateDataTaskPayload[] = [];

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.tasks.push(task);
    const result: DynamicGenericToolResult = {
      sourceTag: 'Composio',
      toolName: 'NOTION_SEARCH',
      title: 'Selected read result',
      status: 'success',
      summary: 'one result',
      rows: [],
      rawPreview: '{"id":"page-real-1"}'
    };
    return {
      toolId: task.toolId,
      outputSchema: task.outputSchema,
      status: 'success',
      sources: [],
      data: JSON.parse(JSON.stringify({ results: [result] })) as Object,
      warnings: []
    };
  }
}

interface StructuredToolCallRecord {
  toolId: string;
  prompt: string;
  args: Object;
}

type CanaryJsonRecord = Record<string, JsonValue | undefined>;

function c02DecisionWithInput(inputJson: string): string {
  return '{"personaId":"travel_companion","skillId":"",' +
    '"requestedCapabilityIds":["travel.search"],"roundAction":"execute",' +
    '"dataTasks":[{"localId":"travel","goal":"搜索从北京到上海的出行方案",' +
    '"allowedToolIds":["travel.search"],"toolId":"travel.search","input":' + inputJson +
    ',"required":true}],"uiIntent":{"purpose":"travel.search",' +
    '"preferredDensity":"comfortable","requiredSections":["travel"]}}';
}

function canaryStructuredResult(toolId: string, outputSchema: string): DataResult {
  let data: Object;
  if (toolId === 'travel.search') {
    data = JSON.parse('{"title":"出行方案","body":"真实结果","summary":"0 result",' +
      '"options":[],"rows":[]}') as Object;
  } else if (toolId === 'train.search') {
    data = JSON.parse('{"title":"高铁方案","body":"真实结果","summary":"0 result","trains":[]}') as Object;
  } else if (toolId === 'flight.search') {
    data = JSON.parse('{"title":"航班方案","body":"真实结果","summary":"0 result","flights":[]}') as Object;
  } else {
    data = JSON.parse('{"results":[]}') as Object;
  }
  return {
    toolId,
    outputSchema,
    status: 'success',
    sources: [],
    data,
    warnings: []
  };
}

class CalendarUpdateExecutor implements DataTaskExecutor {
  readonly tasks: CreateDataTaskPayload[] = [];
  private readonly eventIds: string[];

  constructor(eventIds: string[]) {
    this.eventIds = eventIds.slice();
  }

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.tasks.push(task);
    const values = task.args as Record<string, Object | string | number | boolean | null | undefined>;
    const rawRequestedAction = values['requestedAction'];
    const query = typeof values['query'] === 'string' ? values['query'] as string : '';
    const requestedAction: Object = rawRequestedAction !== null &&
      rawRequestedAction !== undefined && typeof rawRequestedAction === 'object' &&
      !Array.isArray(rawRequestedAction) ? rawRequestedAction as Object : JSON.parse('{}') as Object;
    const results: DynamicGenericToolResult[] = [];
    this.eventIds.forEach((eventId: string) => {
      const result: DynamicGenericToolResult = {
        sourceTag: 'Composio Google Calendar',
        toolName: 'calendar.events.search',
        title: query,
        status: 'success',
        summary: 'Real provider event.',
        rows: [
          { label: 'Event ID', value: eventId },
          { label: 'Start', value: '2026-07-30T15:00:00+08:00' },
          { label: 'End', value: '2026-07-30T15:30:00+08:00' }
        ],
        rawPreview: '{"id":' + JSON.stringify(eventId) + '}',
        providerPhase: 'execution'
      };
      results.push(result);
    });
    const data = JSON.parse(JSON.stringify({ results, requestedAction })) as Object;
    return {
      toolId: 'calendar.events.search',
      outputSchema: 'calendarEvents',
      status: results.length === 0 ? 'empty' : 'success',
      sources: results.length === 0 ? [] : [{
        provider: 'Composio Google Calendar',
        backend: 'oauth_api',
        operation: 'calendar.events.search',
        fetchedAt: '2026-07-22T00:00:00Z'
      }],
      data,
      warnings: []
    };
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
    onSurface: (surface: A2uiSurfaceState): boolean => {
      surfaces.push(surface);
      return true;
    },
    onMemoryUpdate: (update: PersonaMemoryUpdateRequest): void => {
      updates.push(update);
    },
    dataExecutor: executor,
    currentLocalDate: (): string => '2026-07-21',
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

interface RecordedPageAction {
  actionId: string;
  args: Object;
  context: ActionExecutionContext;
}

function pageSurface(
  sourceToolId: string,
  action: A2uiAction,
  sequence: number
): A2uiSurfaceState {
  const surface = createSeedA2uiSurface();
  const model = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
  model.summary.toolName = sourceToolId;
  model.summary.dataLabel = 'result';
  surface.surfaceId = 'page-surface-' + sequence.toString();
  surface.rootId = 'root';
  surface.title = sourceToolId;
  surface.intent = sourceToolId;
  surface.status = 'ready';
  surface.sequence = sequence;
  surface.runtimeOwner = 'multi_agent';
  surface.runtimeGeneration = sequence;
  surface.components = [{
    id: 'root',
    component: 'SurfaceRoot',
    actions: [action]
  }];
  surface.dataModelJson = JSON.stringify(model);
  return surface;
}

function pageSnapshot(surface: A2uiSurfaceState, generation: number): RegisteredPageSnapshot {
  return {
    surface,
    document: createHtmlHomeDocument({
      surface,
      messages: [],
      isBusy: false,
      isAwaitingFirstSurface: false
    }),
    generation
  };
}

function useLastRenderedSurfaceAsHost(
  options: MultiAgentCanaryOptions,
  surfaces: A2uiSurfaceState[]
): void {
  options.currentPageSnapshot = (): RegisteredPageSnapshot | null => surfaces.length === 0 ?
    null : pageSnapshot(surfaces[surfaces.length - 1], surfaces.length);
  options.currentHostSurface = (): A2uiSurfaceState | null => surfaces.length === 0 ?
    null : surfaces[surfaces.length - 1];
  options.currentHostGeneration = (): number => {
    if (surfaces.length === 0) {
      return 0;
    }
    const generation = surfaces[surfaces.length - 1].runtimeGeneration;
    return generation === undefined ? 0 : generation;
  };
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

    it('owns one independent two-tool turn without legacy handoff', 0, async () => {
      const executor = new TwoToolExecutor();
      const bus = new TrackingBus();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        new QueueModel([TWO_TOOL_DECISION, TWO_TOOL_DONE_DECISION]),
        executor,
        new RecordingOpener(),
        [],
        [],
        bus
      ));

      const outcome = await runtime.submit('比较北京到上海的出行和高铁', {
        text: ''
      }) as MultiAgentSettledOutcome;

      expect(outcome.kind).assertEqual('settled');
      expect(outcome.status).assertEqual('success');
      expect(executor.calls.sort().join(',')).assertEqual('train.search,travel.search');
      expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(2);
      expect(bus.count(AgentMessageType.TURN_HANDOFF)).assertEqual(0);
      runtime.dispose();
    });

    it('executes travel flight and train with the exact host query while leaving non-travel goals unchanged', 0,
      async () => {
        const calls: StructuredToolCallRecord[] = [];
        const options: MultiAgentCanaryOptions = canaryOptions(
          new QueueModel([
            C02_QUERY_DECISION, C02_QUERY_DONE,
            F01_QUERY_DECISION, F01_QUERY_DONE,
            F02_QUERY_DECISION, F02_QUERY_DONE,
            DYNAMIC_READ_DECISION, DYNAMIC_READ_DONE
          ]),
          new CanaryHotelExecutor(),
          new RecordingOpener(),
          [],
          []
        );
        options.dataExecutor = undefined;
        options.structuredToolCall = async (
          toolId: string,
          prompt: string,
          args: Object
        ): Promise<DataResult> => {
          calls.push({ toolId, prompt, args });
          const definitionOutput: string = toolId === 'travel.search' ? 'travelOptions' :
            (toolId === 'flight.search' ? 'flights' :
              (toolId === 'train.search' ? 'trains' : 'dynamicToolConnect'));
          return canaryStructuredResult(toolId, definitionOutput);
        };
        const runtime: MultiAgentCanaryRuntime = new MultiAgentCanaryRuntime(options);

        await runtime.submit(C02_QUERY, { text: '' });
        await runtime.submit(F01_QUERY, { text: '' });
        await runtime.submit(F02_QUERY, { text: '' });
        await runtime.submit('搜索我授权的 Notion 页面', { text: '' });

        expect(calls.length).assertEqual(4);
        expect(calls[0].toolId).assertEqual('travel.search');
        expect(calls[0].prompt).assertEqual(C02_QUERY);
        expect(calls[1].toolId).assertEqual('flight.search');
        expect(calls[1].prompt).assertEqual(F01_QUERY);
        expect(calls[2].toolId).assertEqual('train.search');
        expect(calls[2].prompt).assertEqual(F02_QUERY);
        expect(calls[3].toolId).assertEqual('dynamic.search');
        expect(calls[3].prompt).assertEqual('find the selected Notion page');
        const c02Args = calls[0].args as Record<string, Object | string | number | boolean>;
        const flightArgs = calls[1].args as Record<string, Object | string | number | boolean>;
        const trainArgs = calls[2].args as Record<string, Object | string | number | boolean>;
        const dynamicArgs = calls[3].args as Record<string, Object | string | number | boolean>;
        expect(c02Args['query']).assertEqual(C02_QUERY);
        expect(c02Args['departureDate']).assertEqual('2026-07-23');
        expect(c02Args['origin']).assertEqual('北京');
        expect(c02Args['destination']).assertEqual('上海');
        expect(flightArgs['query']).assertEqual(F01_QUERY);
        expect(trainArgs['query']).assertEqual(F02_QUERY);
        expect(dynamicArgs['qualifiedName']).assertEqual('NOTION_SEARCH');
        runtime.dispose();
      });

    it('executes C02 travel Data only once when round two repeats it before repair', 0, async () => {
      const model = new QueueModel([
        C02_QUERY_DECISION,
        C02_QUERY_DECISION,
        C02_QUERY_DONE
      ]);
      const bus = new TrackingBus();
      let providerCalls: number = 0;
      const options: MultiAgentCanaryOptions = canaryOptions(
        model,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        [],
        bus
      );
      options.dataExecutor = undefined;
      options.structuredToolCall = async (
        toolId: string,
        prompt: string,
        _args: Object
      ): Promise<DataResult> => {
        providerCalls += 1;
        expect(toolId).assertEqual('travel.search');
        expect(prompt).assertEqual(C02_QUERY);
        return canaryStructuredResult(toolId, 'travelOptions');
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(C02_QUERY, { text: '' }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(providerCalls).assertEqual(1);
      expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(1);
      expect(model.prompts.length).assertEqual(3);
      runtime.dispose();
    });

    it('rejects prototype member names in travel inputs before the structured provider', 0, async () => {
      const unsafeInputs: string[] = [
        '{"query":"forged","__proto__":{"polluted":"yes"}}',
        '{"query":"forged","nested":{"__proto__":{"polluted":"yes"}}}',
        '{"query":"forged","constructor":{"polluted":"yes"}}',
        '{"query":"forged","nested":{"constructor":{"polluted":"yes"}}}',
        '{"query":"forged","prototype":{"polluted":"yes"}}',
        '{"query":"forged","nested":{"prototype":{"polluted":"yes"}}}'
      ];
      let providerCalls: number = 0;
      for (let index: number = 0; index < unsafeInputs.length; index++) {
        const options: MultiAgentCanaryOptions = canaryOptions(
          new QueueModel([c02DecisionWithInput(unsafeInputs[index]), C02_QUERY_DONE]),
          new CanaryHotelExecutor(),
          new RecordingOpener(),
          [],
          []
        );
        options.dataExecutor = undefined;
        options.structuredToolCall = async (
          toolId: string,
          _prompt: string,
          _args: Object
        ): Promise<DataResult> => {
          providerCalls += 1;
          return canaryStructuredResult(toolId, 'travelOptions');
        };
        const runtime: MultiAgentCanaryRuntime = new MultiAgentCanaryRuntime(options);

        const outcome = await runtime.submit(C02_QUERY, { text: '' }) as MultiAgentSettledOutcome;

        expect(outcome.status).assertEqual('error');
        runtime.dispose();
      }
      const clean: CanaryJsonRecord = {};
      expect(providerCalls).assertEqual(0);
      expect(clean['polluted'] === undefined).assertTrue();
    });

    it('uses the shared JSON Pointer boundary for deep clones and non-JSON shapes', 0, () => {
      const shared = JSON.parse('{"value":"shared"}') as CanaryJsonRecord;
      const source = JSON.parse(
        '{"query":"forged","nested":{"keep":true},"list":[{"name":"first"}]}'
      ) as CanaryJsonRecord;
      source['left'] = shared;
      source['right'] = shared;
      const assigned = setJsonPointer(source, '/query', C02_QUERY);

      expect(assigned.ok).assertTrue();
      const cloned = assigned.value as CanaryJsonRecord;
      expect(cloned['query'] as string).assertEqual(C02_QUERY);
      expect(JSON.stringify(cloned['nested'])).assertEqual('{"keep":true}');
      expect(JSON.stringify(cloned['list'])).assertEqual('[{"name":"first"}]');
      expect(cloned['nested'] === source['nested']).assertFalse();
      expect(cloned['list'] === source['list']).assertFalse();
      expect(cloned['left'] === cloned['right']).assertFalse();
      (source['nested'] as CanaryJsonRecord)['keep'] = false;
      expect(JSON.stringify(cloned['nested'])).assertEqual('{"keep":true}');

      const namedArray: JsonValue[] = ['safe'];
      (namedArray as Object as CanaryJsonRecord)['named'] = 'unsafe';
      const namedSource = JSON.parse('{}') as CanaryJsonRecord;
      namedSource['values'] = namedArray;
      expect(setJsonPointer(namedSource, '/query', C02_QUERY).ok).assertFalse();

      const sparseArray: JsonValue[] = [];
      sparseArray.length = 2;
      sparseArray[1] = 'unsafe';
      const sparseSource = JSON.parse('{}') as CanaryJsonRecord;
      sparseSource['values'] = sparseArray;
      expect(setJsonPointer(sparseSource, '/query', C02_QUERY).ok).assertFalse();

      const cyclic: CanaryJsonRecord = {};
      cyclic['self'] = cyclic;
      expect(setJsonPointer(cyclic, '/query', C02_QUERY).ok).assertFalse();
      const clean: CanaryJsonRecord = {};
      expect(clean['polluted'] === undefined).assertTrue();
    });

    it('keeps C13 dynamic read in MultiAgent Data and executes only the selected read slug', 0, async () => {
      const executor = new RecordingDynamicExecutor();
      const bus = new TrackingBus();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        new QueueModel([DYNAMIC_READ_DECISION, DYNAMIC_READ_DONE]),
        executor,
        new RecordingOpener(),
        [],
        [],
        bus
      ));

      const outcome = await runtime.submit('搜索我授权的 Notion 页面', { text: '' });

      expect(outcome.kind).assertEqual('settled');
      expect(executor.tasks.length).assertEqual(1);
      expect(executor.tasks[0].toolId).assertEqual('dynamic.search');
      expect(executor.tasks[0].allowedToolIds.join(',')).assertEqual('dynamic.search');
      const args = executor.tasks[0].args as Record<string, Object | string | number | boolean | null | undefined>;
      expect(args['operation'] as string).assertEqual('search');
      expect(args['qualifiedName'] as string).assertEqual('NOTION_SEARCH');
      expect(bus.count(AgentMessageType.TURN_HANDOFF)).assertEqual(0);
      runtime.dispose();
    });

    it('keeps known direct-answer planner errors inside multi-agent and hands off only unmigrated IDs', 0, async () => {
      const model = new QueueModel([
        ANSWER_DECISION,
        MAIL_DIRECT_ANSWER,
        WEATHER_DIRECT_CLARIFY,
        MISLEADING_HOTEL_DIRECT_ANSWER,
        UNOBSERVED_HOTEL_DIRECT_ANSWER
      ]);
      const executor = new CanaryHotelExecutor();
      const bus = new TrackingBus();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        [],
        [],
        bus
      ));

      const greeting = await runtime.submit('你好', { text: '' });
      const mail = await runtime.submit('查一下酒店确认邮件', { text: '' });
      const weather = await runtime.submit('查询天气', { text: '' });
      const misleadingHotel = await runtime.submit('酒店两个字不要误导，查我的邮件', { text: '' });
      const unobservedHotel = await runtime.submit('深圳酒店多少钱', { text: '' });

      expect(greeting.kind).assertEqual('settled');
      expect((greeting as MultiAgentSettledOutcome).message).assertEqual('你好');
      expect(mail.kind).assertEqual('settled');
      expect((mail as MultiAgentSettledOutcome).status).assertEqual('error');
      expect(weather.kind).assertEqual('settled');
      expect((weather as MultiAgentSettledOutcome).status).assertEqual('error');
      expect(misleadingHotel.kind).assertEqual('settled');
      expect((misleadingHotel as MultiAgentSettledOutcome).status).assertEqual('error');
      expect(unobservedHotel.kind).assertEqual('settled');
      expect((unobservedHotel as MultiAgentSettledOutcome).status).assertEqual('error');
      expect(executor.calls.length).assertEqual(0);
      expect(bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_DATA ||
          message.type === AgentMessageType.TASK_CREATE_UI ||
          message.type === AgentMessageType.ACTION_PLAN_REQUEST
      ).length).assertEqual(0);
      expect(model.prompts[0].indexOf('"requestedCapabilityIds"') >= 0).assertTrue();
      runtime.dispose();
    });

    it('rejects a legacy handoff claim for the newly owned dynamic read tool', 0, async () => {
      const model = new QueueModel([WEATHER_HANDOFF_DECISION]);
      const executor = new CanaryHotelExecutor();
      const bus = new TrackingBus();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        [],
        [],
        bus
      ));

      const weather = await runtime.submit('查询北京天气', { text: '' });

      expect(weather.kind).assertEqual('settled');
      expect((weather as MultiAgentSettledOutcome).status).assertEqual('error');
      expect(bus.count(AgentMessageType.TURN_HANDOFF)).assertEqual(0);
      expect(executor.calls.length).assertEqual(0);
      expect(bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_DATA ||
          message.type === AgentMessageType.TASK_CREATE_UI ||
          message.type === AgentMessageType.ACTION_PLAN_REQUEST
      ).length).assertEqual(0);
      expect(model.prompts[0].indexOf('LeaderDecision schema:') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('"roundAction":"execute|answer|clarify|legacy_handoff"') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('unavailable or not runtime-owned') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('Runtime-owned tool IDs:') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('mail.search') >= 0).assertTrue();
      runtime.dispose();
    });

    it('rejects malformed hotel destination date year guests and origin before task publication', 0, async () => {
      const mutations: string[] = [
        SEARCH_INPUT.replace('"place":"深圳"', '"place":""'),
        SEARCH_INPUT.replace('2026-08-15', '2026-02-30'),
        SEARCH_INPUT.replace('2026-08-15', '26-08-15'),
        SEARCH_INPUT.replace('"adultCount":2', '"adultCount":0'),
        SEARCH_INPUT.replace('"originQuery":"帮我找深圳酒店"', '"originQuery":"默认曼谷酒店"')
      ];
      for (let index = 0; index < mutations.length; index++) {
        const decision: string = HOTEL_DECISION.replace(SEARCH_INPUT, mutations[index]);
        const executor = new CanaryHotelExecutor();
        const bus = new TrackingBus();
        const runtime = new MultiAgentCanaryRuntime(canaryOptions(
          new QueueModel([decision]),
          executor,
          new RecordingOpener(),
          [],
          [],
          bus
        ));

        const outcome = await runtime.submit(SEARCH_TEXT, { text: '' }) as MultiAgentSettledOutcome;

        expect(outcome.status).assertEqual('error');
        expect(executor.calls.length).assertEqual(0);
        expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(0);
        expect(bus.count(AgentMessageType.TASK_CREATE_UI)).assertEqual(0);
        runtime.dispose();
      }
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

    it('keeps a reentrant virtual memory surface on its captured host generation', 0, async () => {
      const surfaceGenerations: number[] = [];
      const updateGenerations: number[] = [];
      const options = canaryOptions(
        new QueueModel([MEMORY_DECISION, ANSWER_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      let runtime: MultiAgentCanaryRuntime;
      let newerTurn: Promise<MultiAgentSettledOutcome> | null = null;
      options.onSurface = (_surface: A2uiSurfaceState, runtimeGeneration: number): boolean => {
        surfaceGenerations.push(runtimeGeneration);
        return true;
      };
      options.onMemoryUpdate = (
        _update: PersonaMemoryUpdateRequest,
        runtimeGeneration: number
      ): void => {
        updateGenerations.push(runtimeGeneration);
        if (newerTurn === null) {
          newerTurn = runtime.submit('newer turn', { text: '' }, 202) as
            Promise<MultiAgentSettledOutcome>;
        }
      };
      runtime = new MultiAgentCanaryRuntime(options);

      const oldTurn = runtime.submit('我只喝瑞幸咖啡', {
        text: '',
        previousPersonaId: 'food_companion'
      }, 101) as Promise<MultiAgentSettledOutcome>;
      await oldTurn;
      await newerTurn;

      expect(updateGenerations.length).assertEqual(1);
      expect(updateGenerations[0]).assertEqual(101);
      expect(surfaceGenerations.length).assertEqual(1);
      expect(surfaceGenerations[0]).assertEqual(101);
      runtime.dispose();
    });

    it('owns initial fixed Actions through the real Leader actionIntent path', 0, async () => {
      const calls: RecordedPageAction[] = [];
      const bus = new TrackingBus();
      const options = canaryOptions(
        new QueueModel([WORLDCUP_ACTION_DECISION, MAPS_ACTION_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        [],
        bus
      );
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        return {
          status: 'success',
          output: JSON.parse('{"route":"pages/A2uiHome/AnythingDemo","status":"opened"}') as Object
        };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('打开世界杯页面', { text: '' }) as MultiAgentSettledOutcome;
      const mapsOutcome = await runtime.submit('打开深圳北到香港西九龙的路线', { text: '' }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(mapsOutcome.status).assertEqual('success');
      expect(calls.length).assertEqual(2);
      expect(calls[0].actionId).assertEqual('worldcup.open');
      expect(JSON.stringify(calls[0].args)).assertEqual(
        '{"route":"pages/A2uiHome/AnythingDemo"}'
      );
      expect(calls[0].context.sourceToolId).assertEqual('virtual.action-intent');
      expect(calls[1].actionId).assertEqual('maps.route.open');
      expect(JSON.stringify(calls[1].args)).assertEqual(
        '{"origin":"深圳北","destination":"香港西九龙","travelMode":"driving","navigate":false}'
      );
      expect(calls[1].context.sourceToolId).assertEqual('virtual.action-intent');
      expect(bus.count(AgentMessageType.ACTION_PLAN_REQUEST)).assertEqual(2);
      expect(bus.count(AgentMessageType.ACTION_RESULT)).assertEqual(2);
      expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(0);
      runtime.dispose();
    });

    it('renders an exact Calendar create review and calls the provider only after the current click', 0, async () => {
      const surfaces: A2uiSurfaceState[] = [];
      const calls: RecordedPageAction[] = [];
      let current: RegisteredPageSnapshot | null = null;
      let generation = 0;
      const options = canaryOptions(
        new QueueModel([CALENDAR_CREATE_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        surfaces,
        []
      );
      options.onSurface = (surface: A2uiSurfaceState): boolean => {
        surfaces.push(surface);
        generation++;
        current = {
          surface,
          document: createHtmlHomeDocument({
            surface,
            messages: [],
            isBusy: false,
            isAwaitingFirstSurface: false
          }),
          generation
        };
        return true;
      };
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => current;
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        return {
          status: 'success',
          output: JSON.parse('{"eventId":"event-provider-real-1"}') as Object
        };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '帮我在 2026年7月30日下午3点创建一个title为AIPhoneDemo的30分钟日程',
        { text: '' }
      ) as MultiAgentSettledOutcome;
      const exact = renderedAction(surfaces[surfaces.length - 1], 'calendar.event.create');
      const forged = JSON.parse(JSON.stringify(exact)) as A2uiAction;
      (forged.args as Record<string, Object | string | number | boolean | null | undefined>)['title'] = '伪造标题';

      expect(outcome.status).assertEqual('success');
      expect(calls.length).assertEqual(0);
      expect(exact === null).assertFalse();
      expect(await runtime.runPageAction(forged)).assertFalse();
      expect(await runtime.runPageAction(exact as A2uiAction)).assertTrue();
      expect(calls.length).assertEqual(1);
      expect(calls[0].actionId).assertEqual('calendar.event.create');
      expect(calls[0].context.pageActionId).assertEqual('calendar.event.create');
      current = null;
      expect(await runtime.runPageAction(exact as A2uiAction)).assertFalse();
      expect(calls.length).assertEqual(1);
      runtime.dispose();
    });

    it('binds Calendar update to one real search event before review and never trusts a model eventId', 0, async () => {
      const executor = new CalendarUpdateExecutor(['event-provider-real-1']);
      const surfaces: A2uiSurfaceState[] = [];
      const calls: RecordedPageAction[] = [];
      let current: RegisteredPageSnapshot | null = null;
      const options = canaryOptions(
        new QueueModel([CALENDAR_UPDATE_SEARCH_DECISION, CALENDAR_UPDATE_DONE_DECISION]),
        executor,
        new RecordingOpener(),
        surfaces,
        []
      );
      options.onSurface = (surface: A2uiSurfaceState): boolean => {
        surfaces.push(surface);
        current = {
          surface,
          document: createHtmlHomeDocument({
            surface,
            messages: [],
            isBusy: false,
            isAwaitingFirstSurface: false
          }),
          generation: 1
        };
        return true;
      };
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => current;
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        return {
          status: 'success',
          output: JSON.parse('{"eventId":"event-provider-real-1"}') as Object
        };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '把 2026年7月30日 的 Appless QA run-1 日程改到下午4点',
        { text: '' }
      ) as MultiAgentSettledOutcome;
      const review = renderedAction(surfaces[surfaces.length - 1], 'calendar.event.update');
      const taskJson = JSON.stringify(executor.tasks[0].args);

      expect(outcome.status).assertEqual('success');
      expect(review === null).assertFalse();
      expect(taskJson.indexOf('model-forged')).assertEqual(-1);
      expect(JSON.stringify((review as A2uiAction).args).indexOf('event-provider-real-1')).assertLarger(-1);
      expect(calls.length).assertEqual(0);
      expect(await runtime.runPageAction(review as A2uiAction)).assertTrue();
      expect(calls.length).assertEqual(1);
      expect(calls[0].actionId).assertEqual('calendar.event.update');
      expect(JSON.stringify(calls[0].args).indexOf('event-provider-real-1')).assertLarger(-1);
      runtime.dispose();
    });

    it('cancels Calendar create planning before review without a provider call or late surface', 0, async () => {
      const model = new GatedModel(CALENDAR_CREATE_DECISION);
      const surfaces: A2uiSurfaceState[] = [];
      let providerCalls = 0;
      const options = canaryOptions(
        model,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        surfaces,
        []
      );
      options.pageAction = async (): Promise<ActionExecutionResult> => {
        providerCalls++;
        return { status: 'success', output: JSON.parse('{"eventId":"unexpected"}') as Object };
      };
      const runtime = new MultiAgentCanaryRuntime(options);
      const pending = runtime.submit(
        '创建日程；标题：产品评审；时间：2026-07-30 15:00 至 2026-07-30 15:30',
        { text: '' }
      );
      await model.started.promise;
      runtime.cancelActiveTurn('user_cancel');
      model.release.open();
      const outcome = await pending as MultiAgentSettledOutcome;
      await flush();

      expect(outcome.status).assertEqual('canceled');
      expect(surfaces.length).assertEqual(0);
      expect(providerCalls).assertEqual(0);
      runtime.dispose();
    });

    it('refreshes second-turn planning from the updated C11 persona memory', 0, async () => {
      configureDefaultPersonaStoreForTests();
      const updates: PersonaMemoryUpdateRequest[] = [];
      const model = new MemoryAwareModel();
      const options = canaryOptions(
        model,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        updates
      );
      options.selectedPersonaId = (): string => 'food_companion';
      options.onMemoryUpdate = (update: PersonaMemoryUpdateRequest): void => {
        updates.push(update);
        const pack = personaPackForId(update.personaId);
        updatePersonaPackText(update.personaId, pack.soul, update.memoryText);
      };
      const runtime = new MultiAgentCanaryRuntime(options);
      try {
        const remembered = await runtime.submit('我只喝瑞幸咖啡', {
          text: '',
          previousPersonaId: 'food_companion'
        }) as MultiAgentSettledOutcome;
        const continued = await runtime.submit('继续', {
          text: '',
          previousPersonaId: 'food_companion'
        }) as MultiAgentSettledOutcome;

        expect(remembered.status).assertEqual('success');
        expect(continued.status).assertEqual('success');
        expect(continued.message).assertEqual('已按更新后的瑞幸偏好继续');
        expect(updates.length).assertEqual(1);
        expect(model.prompts.length).assertEqual(2);
        expect(model.secondTurnUsedUpdatedFoodContext).assertTrue();
      } finally {
        runtime.dispose();
        configureDefaultPersonaStoreForTests();
      }
    });

    it('keeps C20 search navigation detail booking and return under the canary runtime', 0, async () => {
      const executor = new CanaryHotelExecutor();
      const opener = new RecordingOpener();
      const bus = new TrackingBus();
      const surfaces: A2uiSurfaceState[] = [];
      let currentHost: A2uiSurfaceState | null = null;
      let currentSnapshot: RegisteredPageSnapshot | null = null;
      let renderGeneration = 0;
      const options = canaryOptions(
        new QueueModel([HOTEL_DECISION, HOTEL_DONE_DECISION]),
        executor,
        opener,
        surfaces,
        [],
        bus
      );
      options.onSurface = (
        surface: A2uiSurfaceState,
        runtimeGeneration: number
      ): boolean => {
        if (currentHost !== null &&
          (currentHost.runtimeOwner !== 'multi_agent' ||
            currentHost.runtimeGeneration !== runtimeGeneration)) {
          return false;
        }
        surfaces.push(surface);
        currentHost = surface;
        renderGeneration++;
        currentSnapshot = pageSnapshot(surface, renderGeneration);
        return true;
      };
      options.currentHostSurface = (): A2uiSurfaceState | null => currentHost;
      options.currentHostGeneration = (): number => currentHost === null ||
        currentHost.runtimeGeneration === undefined ? 0 : currentHost.runtimeGeneration;
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => currentSnapshot;
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(SEARCH_TEXT, { text: '' }) as MultiAgentSettledOutcome;
      const searchContext = runtime.currentActionContext();
      const originalSearchSurfaceId = surfaces[surfaces.length - 1].surfaceId;
      expect(outcome.status).assertEqual('success');
      expect(searchContext?.sourceToolId).assertEqual('hotel.search');
      expect(executor.calls.join(',')).assertEqual('hotel.search');
      const normalizedSearch = executor.tasks[0].args as Record<string, Object | string | number | boolean | null | undefined>;
      expect(normalizedSearch.originQuery).assertEqual(SEARCH_TEXT);
      expect(normalizedSearch.checkOutDate).assertEqual('2026-08-17');

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
      await flush();
      expect(executor.calls.join(',')).assertEqual('hotel.search,hotel.detail');
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

      const visibleDetail = surfaces[surfaces.length - 1];
      const newerHost = pageSurface('hotel.detail', booking!, 202);
      currentHost = newerHost;
      currentSnapshot = pageSnapshot(newerHost, renderGeneration + 1);
      expect(runtime.restoreSearchSurface()).assertFalse();
      expect(surfaces[surfaces.length - 1].surfaceId).assertEqual(visibleDetail.surfaceId);
      const legacyHost = pageSurface('hotel.detail', booking!, 101);
      legacyHost.runtimeOwner = 'legacy';
      currentHost = legacyHost;
      currentSnapshot = pageSnapshot(legacyHost, renderGeneration + 2);
      expect(runtime.restoreSearchSurface()).assertFalse();
      expect(runtime.currentActionContext()?.sourceToolId).assertEqual('hotel.detail');
      currentHost = visibleDetail;
      currentSnapshot = pageSnapshot(visibleDetail, renderGeneration + 3);
      expect(runtime.restoreSearchSurface()).assertTrue();
      expect(surfaces[surfaces.length - 1].surfaceId).assertEqual(originalSearchSurfaceId);
      expect(registeredPageSourceToolId(surfaces[surfaces.length - 1])).assertEqual('hotel.search');
      expect(runtime.currentActionContext()?.sourceToolId).assertEqual('hotel.search');
      runtime.dispose();
    });

    it('runs hotel detail only for the exact current host search surface', 0, async () => {
      const executor = new CanaryHotelExecutor();
      const surfaces: A2uiSurfaceState[] = [];
      let currentHost: A2uiSurfaceState | null = null;
      let currentSnapshot: RegisteredPageSnapshot | null = null;
      let renderGeneration = 0;
      const options = canaryOptions(
        new QueueModel([HOTEL_DECISION, HOTEL_DONE_DECISION]),
        executor,
        new RecordingOpener(),
        surfaces,
        []
      );
      options.onSurface = (
        surface: A2uiSurfaceState,
        runtimeGeneration: number
      ): boolean => {
        if (currentHost !== null &&
          (currentHost.runtimeOwner !== 'multi_agent' ||
            currentHost.runtimeGeneration !== runtimeGeneration)) {
          return false;
        }
        surfaces.push(surface);
        currentHost = surface;
        renderGeneration++;
        currentSnapshot = pageSnapshot(surface, renderGeneration);
        return true;
      };
      options.currentHostSurface = (): A2uiSurfaceState | null => currentHost;
      options.currentHostGeneration = (): number => currentHost === null ||
        currentHost.runtimeGeneration === undefined ? 0 : currentHost.runtimeGeneration;
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => currentSnapshot;
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(SEARCH_TEXT, { text: '' }, 101) as MultiAgentSettledOutcome;
      const searchSurface = surfaces[surfaces.length - 1];
      const searchSnapshot = pageSnapshot(searchSurface, renderGeneration);
      const context = runtime.currentActionContext();
      const detail = renderedAction(searchSurface, 'hotel.detail');
      const newerSurface = pageSurface('hotel.search', detail!, 202);
      currentHost = newerSurface;
      currentSnapshot = pageSnapshot(newerSurface, renderGeneration + 1);

      expect(outcome.status).assertEqual('success');
      expect(await runtime.runAction(detail!, context!)).assertFalse();
      expect(executor.calls.join(',')).assertEqual('hotel.search');
      expect(executor.tasks.length).assertEqual(1);

      currentHost = searchSurface;
      currentSnapshot = searchSnapshot;
      const detailPending = runtime.runAction(detail!, context!);
      await executor.detailStarted.promise;
      expect(executor.calls.join(',')).assertEqual('hotel.search,hotel.detail');
      expect(executor.tasks.length).assertEqual(2);
      executor.detailRelease.open();
      expect(await detailPending).assertTrue();
      runtime.dispose();
    });

    it('routes exact declared and existing adapted product buttons through one ActionAgent run', 0, async () => {
      const calls: RecordedPageAction[] = [];
      const bus = new TrackingBus();
      let currentSnapshot: RegisteredPageSnapshot | null = null;
      const options = canaryOptions(
        new QueueModel([]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        [],
        bus
      );
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        return {
          status: 'success',
          output: JSON.parse('{"providerStatus":"exact"}') as Object
        };
      };
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => currentSnapshot;
      const runtime = new MultiAgentCanaryRuntime(options);
      const routes: Array<[string, string, string, Object, string]> = [
        ['social.feed.search', 'social.reply.draft', 'social.reply.draft',
          JSON.parse('{"itemId":"post-1","platform":"x","instruction":"draft"}') as Object, 'prompt'],
        ['mail.search', 'mail.draft.create', 'mail.draft.create',
          JSON.parse('{"provider":"qq","to":"a@example.com","subject":"QA","body":"draft"}') as Object, 'prompt'],
        ['gmail.thread.read', 'gmail.draft.create', 'gmail.draft.create',
          JSON.parse('{"to":"a@example.com","subject":"QA","body":"draft"}') as Object, 'prompt'],
        ['gmail.draft.create', 'gmail.draft.apply', 'gmail.draft.apply',
          JSON.parse('{"threadId":"thread-1","to":"a@example.com","subject":"QA",' +
            '"replyMode":"reply","body":"exact"}') as Object, 'prompt'],
        ['gmail.draft.apply', 'gmail.open.web', 'gmail.open.web',
          JSON.parse('{"url":"https://mail.google.com/"}') as Object, 'client'],
        ['luckin.order.preview', 'luckin.order.preview', 'luckin.order.preview',
          JSON.parse('{"deptId":"shop-1","location":"114.0,22.5"}') as Object, 'prompt'],
        ['payment.send', 'payment.confirm', 'payment.send',
          JSON.parse('{"provider":"stripe","recipient":"real-user","amountText":"5.00",' +
            '"currency":"USD","phase":"confirm"}') as Object, 'prompt'],
        ['payment.account.setup', 'stripe.account.create', 'payment.account.setup',
          JSON.parse('{"country":"US","businessType":"individual"}') as Object, 'client']
      ];

      for (let index = 0; index < routes.length; index++) {
        const route = routes[index];
        const clicked: A2uiAction = {
          id: route[1],
          label: route[1],
          prompt: route[1],
          variant: 'primary',
          kind: route[4],
          args: route[3]
        };
        const surface = pageSurface(route[0], clicked, index + 1);
        const document = createHtmlHomeDocument({
          surface,
          messages: [],
          isBusy: false,
          isAwaitingFirstSurface: false
        });
        currentSnapshot = { surface, document, generation: index + 1 };
        expect(await runtime.runPageAction(clicked)).assertTrue();
        expect(calls[index].actionId).assertEqual(route[2]);
        expect(JSON.stringify(calls[index].args)).assertEqual(JSON.stringify(route[3]));
      }
      expect(calls.length).assertEqual(routes.length);
      expect(bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.ACTION_RESULT &&
          JSON.stringify(message.payload).indexOf('"status":"paused"') >= 0
      ).length).assertEqual(0);
      runtime.dispose();
    });

    it('rejects a legacy-stamped surface action and accepts the exact multi-agent owner', 0, async () => {
      const calls: RecordedPageAction[] = [];
      const action: A2uiAction = {
        id: 'mail.draft.create',
        label: '创建草稿',
        prompt: '创建草稿',
        variant: 'primary',
        kind: 'prompt',
        args: JSON.parse(
          '{"provider":"qq","to":"a@example.com","subject":"QA","body":"draft"}'
        ) as Object
      };
      const surface = pageSurface('mail.search', action, 30);
      const document = createHtmlHomeDocument({
        surface,
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      let current: RegisteredPageSnapshot = { surface, document, generation: 30 };
      const options = canaryOptions(
        new QueueModel([]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => current;
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        return { status: 'success', output: JSON.parse('{"status":"drafted"}') as Object };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      surface.runtimeOwner = 'legacy';
      current = { surface, document, generation: 30 };
      expect(await runtime.runPageAction(action)).assertFalse();
      surface.runtimeOwner = 'multi_agent';
      current = { surface, document, generation: 31 };
      expect(await runtime.runPageAction(action)).assertTrue();
      expect(calls.length).assertEqual(1);
      runtime.dispose();
    });

    it('rejects stale mutated client-only and deferred page actions before callback', 0, async () => {
      const calls: string[] = [];
      let currentSnapshot: RegisteredPageSnapshot | null = null;
      const options = canaryOptions(
        new QueueModel([]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.pageAction = async (
        actionId: string,
        _args: Object,
        _context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push(actionId);
        return { status: 'success', output: new Object() };
      };
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => currentSnapshot;
      const runtime = new MultiAgentCanaryRuntime(options);
      const args = JSON.parse('{"provider":"stripe","recipient":"real-user","amountText":"5.00",' +
        '"currency":"USD","phase":"confirm"}') as Object;
      const clicked: A2uiAction = {
        id: 'payment.confirm',
        label: 'payment.confirm',
        prompt: 'payment.confirm',
        variant: 'primary',
        kind: 'prompt',
        args
      };
      const surface = pageSurface('payment.send', clicked, 10);
      const document = createHtmlHomeDocument({
        surface,
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      currentSnapshot = { surface, document, generation: 10 };
      const mutated: A2uiAction = {
        id: clicked.id,
        label: clicked.label,
        prompt: clicked.prompt,
        variant: clicked.variant,
        kind: clicked.kind,
        args: JSON.parse('{"provider":"stripe","recipient":"mallory","amountText":"5000",' +
          '"currency":"USD","phase":"confirm"}') as Object
      };
      const clientOnly: A2uiAction = {
        id: 'payment.cancel',
        label: 'payment.cancel',
        prompt: 'payment.cancel',
        variant: 'secondary',
        kind: 'client',
        args
      };
      const deferred: A2uiAction = {
        id: 'gmail.message.send',
        label: 'gmail.message.send',
        prompt: 'gmail.message.send',
        variant: 'primary',
        kind: 'prompt',
        args
      };

      expect(await runtime.runPageAction(clicked)).assertTrue();
      expect(await runtime.runPageAction(mutated)).assertFalse();
      expect(await runtime.runPageAction(clientOnly)).assertFalse();
      expect(await runtime.runPageAction(deferred)).assertFalse();
      currentSnapshot = { surface, document, generation: 9 };
      expect(await runtime.runPageAction(clicked)).assertFalse();
      expect(calls.length).assertEqual(1);
      runtime.dispose();
    });

    it('cancels and times out the exact C20 child turn without a late success', 1000, async () => {
      const timeoutExecutor = new CanaryHotelExecutor();
      const timeoutBus = new TrackingBus();
      const timeoutSurfaces: A2uiSurfaceState[] = [];
      const timeoutOptions = canaryOptions(
        new QueueModel([HOTEL_DECISION, HOTEL_DONE_DECISION]),
        timeoutExecutor,
        new RecordingOpener(),
        timeoutSurfaces,
        [],
        timeoutBus,
        20
      );
      useLastRenderedSurfaceAsHost(timeoutOptions, timeoutSurfaces);
      const timeoutRuntime = new MultiAgentCanaryRuntime(timeoutOptions);
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
      const cancelOptions = canaryOptions(
        new QueueModel([HOTEL_DECISION, HOTEL_DONE_DECISION]),
        cancelExecutor,
        new RecordingOpener(),
        cancelSurfaces,
        [],
        cancelBus
      );
      useLastRenderedSurfaceAsHost(cancelOptions, cancelSurfaces);
      const cancelRuntime = new MultiAgentCanaryRuntime(cancelOptions);
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
