import {
  AgentMessage,
  HotelSearchParseResult,
  HotelSearchRequest,
  InputUserPayload,
  LeaderDecisionDataTask,
  LeaderPlan,
  LeaderPlanner,
  LeaderPlanningContext,
  LeaderToolMetadata,
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
  size: number | string;
}

export interface HotelPlannerIdFactory {
  nextId(prefix: string): string;
}

export type HotelLocalDateProvider = () => string;

export function hotelSearchPlanningContract(currentLocalDate: string): string {
  return 'Current local date: ' + currentLocalDate + '. Resolve relative dates from this date.\n' +
    'For hotel.search, input must contain exactly originQuery, place, placeType, countryCode, ' +
    'checkInDate, stayNights, adultCount, childCount, childAgeDetails, roomCount, currency, and size.\n' +
    'Use currency "" when the user does not specify it; local code applies the bounded CNY default.\n' +
    'Use size 0 when the user does not specify a positive result limit; bounded local code applies the default.\n' +
    'Do not invent missing destination, date, year, guest, child-age, or room values.\n' +
    'Chinese 预订酒店 and English book hotel wording mean search real RollingGo inventory and rates only. ' +
    'No hotel.book or transaction capability exists.\n' +
    'Preserve originQuery exactly.';
}

function normalizeHotelSearchInput(query: string, value: Object): Object {
  if (value === null || Array.isArray(value) ||
    Object.keys(value).sort().join(',') !== HOTEL_SEARCH_KEYS) {
    throw new Error('Hotel planner output contains missing or unknown fields.');
  }
  const raw = value as HotelSearchModelArgs;
  if (raw.originQuery !== query.trim() || raw.countryCode.trim().length === 0) {
    throw new Error('Hotel planner output changed the query or omitted countryCode.');
  }
  const parsed: HotelSearchParseResult = parseHotelSearchRequest(value);
  if (!parsed.ok || parsed.value === null) {
    throw new Error(parsed.error.length > 0 ? parsed.error : 'Invalid hotel search request.');
  }
  return parsed.value;
}

export function normalizeHotelSearchTaskInput(
  input: InputUserPayload,
  task: LeaderDecisionDataTask
): Object {
  return task.toolId === 'hotel.search' ?
    normalizeHotelSearchInput(input.text, task.input) : task.input;
}

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

  async plan(
    _message: AgentMessage,
    input: InputUserPayload,
    context: LeaderPlanningContext
  ): Promise<LeaderPlan> {
    const query = input.text.trim();
    if (query.length === 0) {
      throw new Error('Hotel query must not be empty.');
    }
    const definition = this.hotelSearchDefinition(context);
    const output = await this.model.complete(this.prompt(query));
    const objects = extractJsonObjects(output);
    if (objects.length !== 1) {
      throw new Error('Hotel planner requires exactly one JSON object.');
    }
    const parsedObject = JSON.parse(objects[0]) as Object;
    return this.pairedPlan(
      normalizeHotelSearchInput(query, parsedObject) as HotelSearchRequest,
      definition
    );
  }

  private pairedPlan(request: HotelSearchRequest, definition: LeaderToolMetadata): LeaderPlan {
    const uiTaskId = this.ids.nextId('hotel-search-ui');
    const dataTaskId = this.ids.nextId('hotel-search-data');
    if (uiTaskId.length === 0 || dataTaskId.length === 0 || uiTaskId === dataTaskId) {
      throw new Error('Hotel planner task IDs must be non-empty and unique.');
    }
    return {
      personaId: '',
      skillId: '',
      roundAction: 'execute',
      ui: {
        taskId: uiTaskId,
        intent: definition.intent,
        expectedOutputSchema: definition.outputSchema
      },
      dataTasks: [{
        taskId: dataTaskId,
        toolId: definition.toolId,
        outputSchema: definition.outputSchema,
        args: request
      }],
      reasonCode: 'hotel_search'
    };
  }

  private hotelSearchDefinition(context: LeaderPlanningContext): LeaderToolMetadata {
    for (let index = 0; index < context.tools.length; index++) {
      const definition = context.tools[index];
      if (definition.toolId === 'hotel.search' && definition.riskLevel === 'read') {
        return definition;
      }
    }
    throw new Error('hotel.search is not available to the Leader.');
  }

  private prompt(query: string): string {
    return 'Extract one validated hotel.search request from the user text.\n' +
      hotelSearchPlanningContract(this.currentLocalDate()) + '\n' +
      'Return exactly one JSON object with that hotel.search input shape.\n' +
      'Do not return a tool ID, action ID, markdown explanation, or multiple objects.\n' +
      'User text: ' + query;
  }
}
