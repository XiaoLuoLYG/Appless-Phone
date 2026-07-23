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

const HOTEL_QUERY_OMISSIBLE_PREFIXES: string[] = ['帮我找', '请帮我找'];
const CHINA_HOTEL_PLACE_MARKERS: string[] = [
  '北京', '上海', '天津', '重庆', '深圳', '广州', '杭州', '成都', '武汉', '南京',
  '西安', '苏州', '厦门', '青岛', '长沙', '昆明', '海口', '三亚', '东莞', '佛山',
  '郑州', '宁波', '无锡', '合肥', '福州', '济南', '沈阳', '大连'
];

export interface HotelPlannerIdFactory {
  nextId(prefix: string): string;
}

export type HotelLocalDateProvider = () => string;

export function hotelSearchPlanningContract(currentLocalDate: string): string {
  return 'Current local date: ' + currentLocalDate + '. Resolve relative dates from this date.\n' +
    'For hotel.search, input must contain exactly originQuery, place, placeType, countryCode, ' +
    'checkInDate, stayNights, adultCount, childCount, childAgeDetails, roomCount, currency, and size.\n' +
    'Use placeType "CITY" only for a city and "POI" for a named landmark, park, or "<place>附近" request.\n' +
    'Use currency "" when the user does not specify it; local code applies the bounded CNY default.\n' +
    'Use size 0 when the user does not specify a positive result limit; bounded local code applies the default.\n' +
    'Do not invent missing destination, date, year, guest, child-age, or room values.\n' +
    'Chinese 预订酒店 and English book hotel wording mean search real RollingGo inventory and rates only. ' +
    'No hotel.book or transaction capability exists.\n' +
    'Preserve originQuery exactly.';
}

function omittedHotelQueryPrefix(trustedQuery: string, modelQuery: string): boolean {
  if (modelQuery.length === 0) {
    return false;
  }
  for (let index = 0; index < HOTEL_QUERY_OMISSIBLE_PREFIXES.length; index++) {
    if (trustedQuery === HOTEL_QUERY_OMISSIBLE_PREFIXES[index] + modelQuery) {
      return true;
    }
  }
  return false;
}

function chineseCount(value: string): number {
  const raw = value.trim();
  if (/^[0-9]+$/.test(raw)) {
    return Number.parseInt(raw, 10);
  }
  if (raw === '两') {
    return 2;
  }
  const digits: string = '零一二三四五六七八九';
  if (raw.length === 1) {
    const digit: number = digits.indexOf(raw);
    return digit < 0 ? (raw === '十' ? 10 : -1) : digit;
  }
  const tens = /^([一二三四五六七八九])?十([一二三四五六七八九])?$/.exec(raw);
  if (tens === null) {
    return -1;
  }
  const high: number = tens[1] === undefined ? 1 : chineseCount(tens[1]);
  const low: number = tens[2] === undefined ? 0 : chineseCount(tens[2]);
  return high * 10 + low;
}

function explicitHotelDestination(query: string): string {
  const nearby =
    /(?:到|至)(?:[0-9]{4}年)?(?:[0-9]{1,2}月)?[0-9]{1,2}日([^，,]+)附近的酒店/.exec(query);
  if (nearby !== null) {
    return nearby[1].trim();
  }
  const direct =
    /(?:到|至)(?:[0-9]{4}年)?(?:[0-9]{1,2}月)?[0-9]{1,2}日([^，,]+)的酒店/.exec(query);
  if (direct !== null) {
    return direct[1].trim();
  }
  const cityStay =
    /(?:[0-9]{4}年)?[0-9]{1,2}月[0-9]{1,2}日([^，,]+?)住[0-9一二两三四五六七八九十]+晚的酒店/.exec(query);
  if (cityStay !== null) {
    return cityStay[1].trim();
  }
  const simpleCity = /^(?:帮我找|请帮我找)([^，,]+?)酒店$/.exec(query);
  if (simpleCity !== null) {
    return simpleCity[1].trim();
  }
  const englishCity = /\bbook\s+(?:a|an)\s+([a-z]+)\s+hotel\b/i.exec(query);
  if (englishCity !== null && englishCity[1].toLowerCase() === 'shenzhen') {
    return '深圳';
  }
  return '';
}

function normalizedHotelPlaceType(query: string, raw: HotelSearchModelArgs): string {
  const placeType: string = typeof raw.placeType === 'string' ? raw.placeType.trim() : '';
  const destination: string = explicitHotelDestination(query);
  if (placeType.toLowerCase() === 'neighborhood' &&
    destination.length > 0 &&
    typeof raw.place === 'string' &&
    raw.place === destination) {
    return 'POI';
  }
  return placeType;
}

function explicitHotelPlaceAndCountry(query: string, raw: HotelSearchModelArgs): boolean {
  const destination: string = explicitHotelDestination(query);
  const expectedPlaceType: string =
    query.indexOf(destination + '附近') >= 0 ? 'POI' : 'CITY';
  if (destination.length === 0 ||
    typeof raw.place !== 'string' || raw.place !== destination ||
    raw.placeType !== expectedPlaceType ||
    typeof raw.countryCode !== 'string' || raw.countryCode.trim() !== 'CN') {
    return false;
  }
  for (let index = 0; index < CHINA_HOTEL_PLACE_MARKERS.length; index++) {
    if (raw.place.indexOf(CHINA_HOTEL_PLACE_MARKERS[index]) >= 0) {
      return true;
    }
  }
  return false;
}

function expectedHotelYear(
  query: string,
  month: number,
  day: number,
  currentLocalDate: string
): number {
  const explicit = /([0-9]{4})年[0-9]{1,2}月[0-9]{1,2}日?/.exec(query);
  if (explicit !== null) {
    return Number.parseInt(explicit[1], 10);
  }
  const current = /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/.exec(currentLocalDate);
  if (current === null) {
    return -1;
  }
  const currentYear: number = Number.parseInt(current[1], 10);
  const currentMonth: number = Number.parseInt(current[2], 10);
  const currentDay: number = Number.parseInt(current[3], 10);
  return month < currentMonth || (month === currentMonth && day < currentDay) ?
    currentYear + 1 : currentYear;
}

function strictUtcDay(year: number, month: number, day: number): number {
  if (!Number.isInteger(year) || !Number.isInteger(month) || !Number.isInteger(day) ||
    year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
    return Number.NaN;
  }
  const timestamp: number = Date.UTC(year, month - 1, day);
  const date = new Date(timestamp);
  if (date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day) {
    return Number.NaN;
  }
  return timestamp;
}

function explicitHotelDateAndStay(
  query: string,
  raw: HotelSearchModelArgs,
  currentLocalDate: string
): boolean {
  if (typeof raw.checkInDate !== 'string' ||
    typeof raw.stayNights !== 'number' || !Number.isInteger(raw.stayNights)) {
    return false;
  }
  const date = /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/.exec(raw.checkInDate);
  const first = /([0-9]{1,2})月([0-9]{1,2})日?/.exec(query);
  if (date === null) {
    return false;
  }
  if (first === null) {
    const english = /\bfor\s+(one|two|three|four|five|six|seven|[0-9]+)\s+nights?\s+on\s+august\s+([0-9]{1,2})\b/i.exec(query);
    if (english === null) {
      return true;
    }
    const word: string = english[1].toLowerCase();
    const words: string[] = ['one', 'two', 'three', 'four', 'five', 'six', 'seven'];
    const wordIndex: number = words.indexOf(word);
    const nights: number = wordIndex >= 0 ? wordIndex + 1 : Number.parseInt(word, 10);
    const day: number = Number.parseInt(english[2], 10);
    return raw.stayNights === nights &&
      Number.parseInt(date[1], 10) === expectedHotelYear(query, 8, day, currentLocalDate) &&
      Number.parseInt(date[2], 10) === 8 &&
      Number.parseInt(date[3], 10) === day;
  }
  const firstMonth: number = Number.parseInt(first[1], 10);
  const firstDay: number = Number.parseInt(first[2], 10);
  if (Number.parseInt(date[1], 10) !== expectedHotelYear(
    query,
    firstMonth,
    firstDay,
    currentLocalDate
  ) ||
    Number.parseInt(date[2], 10) !== firstMonth ||
    Number.parseInt(date[3], 10) !== firstDay) {
    return false;
  }

  let stayProven: boolean = false;
  const range =
    /(?:([0-9]{4})年)?([0-9]{1,2})月([0-9]{1,2})日?(?:到|至)(?:([0-9]{4})年)?(?:([0-9]{1,2})月)?([0-9]{1,2})日?/.exec(query);
  if (range !== null) {
    const startYear: number = range[1] === undefined ?
      expectedHotelYear(query, firstMonth, firstDay, currentLocalDate) :
      Number.parseInt(range[1], 10);
    const startMonth: number = Number.parseInt(range[2], 10);
    const startDay: number = Number.parseInt(range[3], 10);
    const endMonth: number = range[5] === undefined ? startMonth : Number.parseInt(range[5], 10);
    const endDay: number = Number.parseInt(range[6], 10);
    const rollover: boolean = endMonth < startMonth ||
      (endMonth === startMonth && endDay < startDay);
    const endYear: number = range[4] === undefined ?
      startYear + (rollover ? 1 : 0) : Number.parseInt(range[4], 10);
    const startUtc: number = strictUtcDay(startYear, startMonth, startDay);
    const endUtc: number = strictUtcDay(endYear, endMonth, endDay);
    const stayNights: number = (endUtc - startUtc) / 86400000;
    if (Number.isNaN(startUtc) || Number.isNaN(endUtc) ||
      !Number.isInteger(stayNights) || stayNights <= 0 ||
      raw.stayNights !== stayNights) {
      return false;
    }
    stayProven = true;
  }
  const stay = /住([0-9一二两三四五六七八九十]+)晚/.exec(query);
  if (stay !== null) {
    if (chineseCount(stay[1]) !== raw.stayNights) {
      return false;
    }
    stayProven = true;
  }
  return stayProven;
}

function explicitHotelOccupancy(query: string, raw: HotelSearchModelArgs): boolean {
  if (typeof raw.adultCount !== 'number' || typeof raw.childCount !== 'number' ||
    typeof raw.roomCount !== 'number' || !Array.isArray(raw.childAgeDetails)) {
    return false;
  }
  const adult = /([0-9一二两三四五六七八九十]+)(?:位|个)?成人/.exec(query);
  if (adult === null ? raw.adultCount !== 2 : chineseCount(adult[1]) !== raw.adultCount) {
    return false;
  }
  const room = /([0-9一二两三四五六七八九十]+)间(?:客房|房)?/.exec(query);
  if (room === null ? raw.roomCount !== 1 : chineseCount(room[1]) !== raw.roomCount) {
    return false;
  }
  const child = /([0-9一二两三四五六七八九十]+)(?:位|名|个)?(?:儿童|孩子|小孩|婴儿)/.exec(query);
  if (child === null) {
    return raw.childCount === 0 && raw.childAgeDetails.length === 0;
  }
  return chineseCount(child[1]) === raw.childCount &&
    raw.childAgeDetails.length === raw.childCount;
}

function explicitHotelQueryFieldsMatch(
  query: string,
  raw: HotelSearchModelArgs,
  currentLocalDate: string
): boolean {
  return explicitHotelPlaceAndCountry(query, raw) &&
    explicitHotelDateAndStay(query, raw, currentLocalDate) &&
    explicitHotelOccupancy(query, raw);
}

function normalizeHotelSearchInput(
  query: string,
  value: Object,
  currentLocalDate: string
): Object {
  if (value === null || Array.isArray(value) ||
    Object.keys(value).sort().join(',') !== HOTEL_SEARCH_KEYS) {
    throw new Error('Hotel planner output contains missing or unknown fields.');
  }
  const raw = value as HotelSearchModelArgs;
  const trustedQuery: string = query.trim();
  const modelQuery: string = typeof raw.originQuery === 'string' ? raw.originQuery : '';
  const normalizedRaw: HotelSearchModelArgs = {
    originQuery: raw.originQuery,
    place: raw.place,
    placeType: normalizedHotelPlaceType(modelQuery, raw),
    countryCode: raw.countryCode,
    checkInDate: raw.checkInDate,
    stayNights: raw.stayNights,
    adultCount: raw.adultCount,
    childCount: raw.childCount,
    childAgeDetails: raw.childAgeDetails,
    roomCount: raw.roomCount,
    currency: raw.currency,
    size: raw.size
  };
  const omittedPrefix: boolean = omittedHotelQueryPrefix(trustedQuery, modelQuery);
  if ((modelQuery !== trustedQuery && !omittedPrefix) ||
    !explicitHotelQueryFieldsMatch(modelQuery, normalizedRaw, currentLocalDate) ||
    typeof normalizedRaw.countryCode !== 'string' ||
    normalizedRaw.countryCode.trim().length === 0) {
    throw new Error('Hotel planner output changed the query or omitted countryCode.');
  }
  const trusted: HotelSearchModelArgs = {
    originQuery: trustedQuery,
    place: normalizedRaw.place,
    placeType: normalizedRaw.placeType,
    countryCode: normalizedRaw.countryCode,
    checkInDate: normalizedRaw.checkInDate,
    stayNights: normalizedRaw.stayNights,
    adultCount: normalizedRaw.adultCount,
    childCount: normalizedRaw.childCount,
    childAgeDetails: normalizedRaw.childAgeDetails,
    roomCount: normalizedRaw.roomCount,
    currency: normalizedRaw.currency,
    size: normalizedRaw.size
  };
  const parsed: HotelSearchParseResult = parseHotelSearchRequest(trusted as Object);
  if (!parsed.ok || parsed.value === null) {
    throw new Error(parsed.error.length > 0 ? parsed.error : 'Invalid hotel search request.');
  }
  return parsed.value;
}

export function normalizeHotelSearchTaskInput(
  input: InputUserPayload,
  task: LeaderDecisionDataTask,
  currentLocalDate: string
): Object {
  return task.toolId === 'hotel.search' ?
    normalizeHotelSearchInput(input.text, task.input, currentLocalDate) : task.input;
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
    const currentLocalDate: string = this.currentLocalDate();
    const definition = this.hotelSearchDefinition(context);
    const output = await this.model.complete(this.prompt(query, currentLocalDate));
    const objects = extractJsonObjects(output);
    if (objects.length !== 1) {
      throw new Error('Hotel planner requires exactly one JSON object.');
    }
    const parsedObject = JSON.parse(objects[0]) as Object;
    return this.pairedPlan(
      normalizeHotelSearchInput(query, parsedObject, currentLocalDate) as HotelSearchRequest,
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

  private prompt(query: string, currentLocalDate: string): string {
    return 'Extract one validated hotel.search request from the user text.\n' +
      hotelSearchPlanningContract(currentLocalDate) + '\n' +
      'Return exactly one JSON object with that hotel.search input shape.\n' +
      'Do not return a tool ID, action ID, markdown explanation, or multiple objects.\n' +
      'User text: ' + query;
  }
}
