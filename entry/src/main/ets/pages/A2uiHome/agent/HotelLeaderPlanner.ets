import {
  AgentMessage,
  HotelSearchParseResult,
  HotelSearchRequest,
  InputUserPayload,
  LeaderPlan,
  LeaderPlanner,
  LocalModel,
  extractJsonObjects,
  parseHotelSearchRequest
} from '@loop/agent-core';

const HOTEL_SEARCH_KEYS: string = [
  'adultCount',
  'checkInDate',
  'childAgeDetails',
  'childCount',
  'countryCode',
  'currency',
  'originQuery',
  'place',
  'placeType',
  'roomCount',
  'size',
  'stayNights'
].join(',');

interface HotelSearchModelArgs {
  originQuery: string;
  place: string;
  placeType: string;
  countryCode: string;
  checkInDate: string;
  stayNights: number;
  adultCount: number;
  childCount: number;
  childAgeDetails: number[];
  roomCount: number;
  currency: string;
  size: number;
}

export interface HotelPlannerIdFactory {
  nextId(prefix: string): string;
}

export type HotelLocalDateProvider = () => string;

export class HotelLeaderPlanner implements LeaderPlanner {
  private readonly model: LocalModel;
  private readonly currentLocalDate: HotelLocalDateProvider;
  private readonly ids: HotelPlannerIdFactory;

  constructor(
    model: LocalModel,
    currentLocalDate: HotelLocalDateProvider,
    ids: HotelPlannerIdFactory
  ) {
    this.model = model;
    this.currentLocalDate = currentLocalDate;
    this.ids = ids;
  }

  async plan(_message: AgentMessage, input: InputUserPayload): Promise<LeaderPlan> {
    const query = input.text.trim();
    if (query.length === 0) {
      throw new Error('Hotel query must not be empty.');
    }
    const output = await this.model.complete(this.prompt(query));
    const objects = extractJsonObjects(output);
    if (objects.length !== 1) {
      throw new Error('Hotel planner requires exactly one JSON object.');
    }
    const parsedObject = JSON.parse(objects[0]) as Object;
    if (parsedObject === null || Array.isArray(parsedObject) ||
      Object.keys(parsedObject).sort().join(',') !== HOTEL_SEARCH_KEYS) {
      throw new Error('Hotel planner output contains missing or unknown fields.');
    }
    const raw = parsedObject as HotelSearchModelArgs;
    if (raw.originQuery !== query ||
      raw.countryCode.trim().length === 0 ||
      raw.currency.trim().length === 0 ||
      !Number.isInteger(raw.size) || raw.size <= 0) {
      throw new Error('Hotel planner output changed the query or defaulted required fields.');
    }
    const parsed: HotelSearchParseResult = parseHotelSearchRequest(parsedObject);
    if (!parsed.ok || parsed.value === null) {
      throw new Error(parsed.error.length > 0 ? parsed.error : 'Invalid hotel search request.');
    }
    return this.pairedPlan(parsed.value);
  }

  private pairedPlan(request: HotelSearchRequest): LeaderPlan {
    const uiTaskId = this.ids.nextId('hotel-search-ui');
    const dataTaskId = this.ids.nextId('hotel-search-data');
    if (uiTaskId.length === 0 || dataTaskId.length === 0 || uiTaskId === dataTaskId) {
      throw new Error('Hotel planner task IDs must be non-empty and unique.');
    }
    return {
      ui: {
        taskId: uiTaskId,
        intent: 'hotel',
        expectedOutputSchema: 'hotelSearchResults'
      },
      data: {
        taskId: dataTaskId,
        toolId: 'hotel.search',
        outputSchema: 'hotelSearchResults',
        args: request
      }
    };
  }

  private prompt(query: string): string {
    return 'Extract one validated hotel.search request from the user text.\n' +
      'Current local date: ' + this.currentLocalDate() + '. Resolve relative dates from this date.\n' +
      'Return exactly one JSON object containing only originQuery, place, placeType, countryCode, ' +
      'checkInDate, stayNights, adultCount, childCount, childAgeDetails, roomCount, currency, and size.\n' +
      'Do not return a tool ID, action ID, markdown explanation, or multiple objects.\n' +
      'Do not invent missing destination, date, guest, child-age, or room values.\n' +
      'Chinese 预订酒店 and English book hotel wording mean search real RollingGo inventory and rates only. ' +
      'No hotel.book or transaction capability exists.\n' +
      'Preserve originQuery exactly.\n' +
      'User text: ' + query;
  }
}
