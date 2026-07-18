import { McpToolResultPayload } from './GenericMcpClient';

type HotelValue = Object | string | number | boolean | null | undefined;

interface HotelSearchRawArgs {
  originQuery?: string;
  place?: string;
  placeType?: string;
  countryCode?: string;
  checkInDate?: string;
  stayNights?: number;
  adultCount?: number;
  childCount?: number;
  childAgeDetails?: HotelValue;
  roomCount?: number;
  currency?: string;
  size?: number;
}

interface HotelDetailRawArgs {
  hotelId?: number;
  checkInDate?: string;
  checkOutDate?: string;
  countryCode?: string;
  currency?: string;
  adultCount?: number;
  childCount?: number;
  childAgeDetails?: HotelValue;
  roomCount?: number;
}

export interface HotelSearchRequest {
  originQuery: string;
  place: string;
  placeType: string;
  countryCode: string;
  checkInDate: string;
  checkOutDate: string;
  stayNights: number;
  adultCount: number;
  childCount: number;
  childAgeDetails: number[];
  roomCount: number;
  currency: string;
  size: number;
}

export interface HotelDetailRequest {
  hotelId: number;
  checkInDate: string;
  checkOutDate: string;
  countryCode: string;
  currency: string;
  adultCount: number;
  childCount: number;
  childAgeDetails: number[];
  roomCount: number;
}

export interface HotelSearchParseResult {
  ok: boolean;
  error: string;
  value: HotelSearchRequest | null;
}

export interface HotelDetailParseResult {
  ok: boolean;
  error: string;
  value: HotelDetailRequest | null;
}

export interface RollingGoHotelSearchCheckInParam {
  checkInDate: string;
  stayNights: number;
  adultCount: number;
}

export interface RollingGoHotelSearchArgs {
  originQuery: string;
  place: string;
  placeType: string;
  countryCode: string;
  size: number;
  checkInParam: RollingGoHotelSearchCheckInParam;
}

export interface RollingGoHotelDetailDateParam {
  checkInDate: string;
  checkOutDate: string;
}

export interface RollingGoHotelDetailLocaleParam {
  countryCode: string;
  currency: string;
}

export interface RollingGoHotelDetailOccupancyParam {
  adultCount: number;
  childCount: number;
  childAgeDetails: number[];
  roomCount: number;
}

export interface RollingGoHotelDetailArgs {
  hotelId: number;
  dateParam: RollingGoHotelDetailDateParam;
  localeParam: RollingGoHotelDetailLocaleParam;
  occupancyParam: RollingGoHotelDetailOccupancyParam;
}

interface RollingGoHotelPriceRecord {
  message?: string;
  hasPrice?: boolean;
  currency?: string;
  lowestPrice?: number;
}

interface RollingGoHotelSearchItemRecord {
  hotelId?: number;
  bookingUrl?: string;
  name?: string;
  nameEn?: string;
  brand?: string | null;
  address?: string;
  destinationId?: string;
  latitude?: number;
  longitude?: number;
  distanceInMeters?: number | null;
  starRating?: number;
  price?: HotelValue;
  areaCode?: string;
  description?: string;
  imageUrl?: string;
  hotelAmenities?: HotelValue;
  tags?: HotelValue;
}

interface RollingGoHotelSearchResponse {
  success?: boolean;
  message?: string;
  hotelInformationList?: HotelValue;
}

interface RollingGoHotelRateRecord {
  roomName?: string | null;
  roomNameCn?: string | null;
  ratePlanId?: string;
  ratePlanName?: string;
  averagePrice?: HotelValue;
  bedTypeDescription?: string;
  currency?: HotelValue;
  mealAmount?: number;
  mealTypeStr?: string;
  isOnRequest?: HotelValue;
  cancelPolicy?: string;
}

interface RollingGoHotelDetailResponse {
  success?: boolean;
  hotelId?: number;
  bookingUrl?: string;
  name?: string;
  nameEn?: string;
  checkIn?: string;
  checkOut?: string;
  roomRatePlans?: HotelValue;
  message?: string;
}

export interface HotelPrice {
  message: string;
  hasPrice: boolean;
  currency: string;
  lowestPrice: number;
}

export interface HotelSearchItem {
  hotelId: number;
  bookingUrl: string;
  name: string;
  nameEn: string;
  brand: string;
  address: string;
  destinationId: string;
  latitude: number;
  longitude: number;
  distanceInMeters: number;
  starRating: number;
  price: HotelPrice;
  areaCode: string;
  description: string;
  imageUrl: string;
  hotelAmenities: string[];
  tags: string[];
}

export interface HotelSearchResult {
  ok: boolean;
  error: string;
  message: string;
  query: HotelSearchRequest;
  hotels: HotelSearchItem[];
}

export interface HotelRatePlan {
  roomName: string;
  roomNameCn: string;
  ratePlanId: string;
  ratePlanName: string;
  averagePrice: number | null;
  bedTypeDescription: string;
  currency: string;
  mealAmount: number;
  mealTypeStr: string;
  isOnRequest: boolean | null;
  cancelPolicy: string;
}

export interface HotelDetailResult {
  ok: boolean;
  error: string;
  message: string;
  query: HotelDetailRequest;
  hotelId: number;
  bookingUrl: string;
  name: string;
  nameEn: string;
  checkIn: string;
  checkOut: string;
  rates: HotelRatePlan[];
}

function textOf(value: HotelValue): string {
  if (value === null || value === undefined) {
    return '';
  }
  if (typeof value === 'string') {
    return value.trim();
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function positiveInteger(value: HotelValue): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value <= 0) {
    return 0;
  }
  return value;
}

function nonNegativeInteger(value: HotelValue): number {
  if (value === undefined) {
    return 0;
  }
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) {
    return -1;
  }
  return value;
}

function numberOf(value: HotelValue): number {
  return typeof value !== 'number' || !Number.isFinite(value) ? 0 : value;
}

function optionalNumberOf(value: HotelValue): number | null {
  return typeof value !== 'number' || !Number.isFinite(value) ? null : value;
}

function currencyOf(value: HotelValue): string {
  if (typeof value !== 'string') {
    return '';
  }
  const currency = value.trim().toUpperCase();
  return /^[A-Z]{3}$/.test(currency) ? currency : '';
}

function stringArrayOf(value: HotelValue): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const source = value as HotelValue[];
  const result: string[] = [];
  source.forEach((item: HotelValue) => {
    if (typeof item === 'string' && item.trim().length > 0) {
      result.push(item.trim());
    }
  });
  return result;
}

function integerArrayOf(value: HotelValue): number[] | null {
  if (value === undefined) {
    return [];
  }
  if (!Array.isArray(value)) {
    return null;
  }
  const source = value as HotelValue[];
  const result: number[] = [];
  for (let index = 0; index < source.length; index++) {
    const item = source[index];
    if (typeof item !== 'number' || !Number.isInteger(item) || item < 0) {
      return null;
    }
    result.push(item);
  }
  return result;
}

function isRecordValue(value: HotelValue): boolean {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isAbsoluteDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const parsed = new Date(value + 'T00:00:00.000Z');
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().substring(0, 10) === value;
}

function addDays(value: string, days: number): string {
  const parsed = new Date(value + 'T00:00:00.000Z');
  parsed.setUTCDate(parsed.getUTCDate() + days);
  return parsed.toISOString().substring(0, 10);
}

function daysBetween(start: string, end: string): number {
  const startDate = new Date(start + 'T00:00:00.000Z');
  const endDate = new Date(end + 'T00:00:00.000Z');
  return Math.round((endDate.getTime() - startDate.getTime()) / 86400000);
}

function searchParseFailure(message: string): HotelSearchParseResult {
  return {
    ok: false,
    error: message,
    value: null
  };
}

function detailParseFailure(message: string): HotelDetailParseResult {
  return {
    ok: false,
    error: message,
    value: null
  };
}

export function parseHotelSearchRequest(args: Object): HotelSearchParseResult {
  const raw = args as HotelSearchRawArgs;
  const originQuery = textOf(raw.originQuery);
  const place = textOf(raw.place);
  const placeType = textOf(raw.placeType);
  const checkInDate = textOf(raw.checkInDate);
  const stayNights = positiveInteger(raw.stayNights);
  const adultCount = positiveInteger(raw.adultCount);
  const roomCount = positiveInteger(raw.roomCount);
  const childCount = nonNegativeInteger(raw.childCount);
  if (place.length === 0 || placeType.length === 0 || originQuery.length === 0) {
    return searchParseFailure('hotel.search requires originQuery, place, and placeType.');
  }
  if (!isAbsoluteDate(checkInDate)) {
    return searchParseFailure('checkInDate must be a valid YYYY-MM-DD date.');
  }
  if (stayNights === 0 || adultCount === 0 || roomCount === 0 || childCount < 0) {
    return searchParseFailure('stayNights, adultCount, and roomCount must be positive integers; childCount cannot be negative.');
  }
  const childAgeDetails = integerArrayOf(raw.childAgeDetails);
  if (childAgeDetails === null) {
    return searchParseFailure('childAgeDetails must be an array of non-negative integer ages.');
  }
  if (childAgeDetails.length !== childCount) {
    return searchParseFailure('childAgeDetails must contain one age for each child.');
  }
  const value: HotelSearchRequest = {
    originQuery: originQuery,
    place: place,
    placeType: placeType,
    countryCode: textOf(raw.countryCode).length > 0 ? textOf(raw.countryCode).toUpperCase() : 'CN',
    checkInDate: checkInDate,
    checkOutDate: addDays(checkInDate, stayNights),
    stayNights: stayNights,
    adultCount: adultCount,
    childCount: childCount,
    childAgeDetails: childAgeDetails,
    roomCount: roomCount,
    currency: textOf(raw.currency).length > 0 ? textOf(raw.currency).toUpperCase() : 'CNY',
    size: positiveInteger(raw.size) > 0 ? positiveInteger(raw.size) : 10
  };
  return {
    ok: true,
    error: '',
    value: value
  };
}

export function parseHotelDetailRequest(args: Object): HotelDetailParseResult {
  const raw = args as HotelDetailRawArgs;
  const hotelId = positiveInteger(raw.hotelId);
  const checkInDate = textOf(raw.checkInDate);
  const checkOutDate = textOf(raw.checkOutDate);
  const adultCount = positiveInteger(raw.adultCount);
  const roomCount = positiveInteger(raw.roomCount);
  const childCount = nonNegativeInteger(raw.childCount);
  if (hotelId === 0) {
    return detailParseFailure('hotel.detail requires a positive provider hotelId.');
  }
  if (!isAbsoluteDate(checkInDate) || !isAbsoluteDate(checkOutDate)) {
    return detailParseFailure('checkInDate and checkOutDate must be valid YYYY-MM-DD dates.');
  }
  if (daysBetween(checkInDate, checkOutDate) <= 0) {
    return detailParseFailure('checkOutDate must be after checkInDate.');
  }
  if (adultCount === 0 || roomCount === 0 || childCount < 0) {
    return detailParseFailure('adultCount and roomCount must be positive integers; childCount cannot be negative.');
  }
  const childAgeDetails = integerArrayOf(raw.childAgeDetails);
  if (childAgeDetails === null) {
    return detailParseFailure('childAgeDetails must be an array of non-negative integer ages.');
  }
  if (childAgeDetails.length !== childCount) {
    return detailParseFailure('childAgeDetails must contain one age for each child.');
  }
  const value: HotelDetailRequest = {
    hotelId: hotelId,
    checkInDate: checkInDate,
    checkOutDate: checkOutDate,
    countryCode: textOf(raw.countryCode).length > 0 ? textOf(raw.countryCode).toUpperCase() : 'CN',
    currency: textOf(raw.currency).length > 0 ? textOf(raw.currency).toUpperCase() : 'CNY',
    adultCount: adultCount,
    childCount: childCount,
    childAgeDetails: childAgeDetails,
    roomCount: roomCount
  };
  return {
    ok: true,
    error: '',
    value: value
  };
}

export function hotelSearchProviderArgs(request: HotelSearchRequest): RollingGoHotelSearchArgs {
  const checkInParam: RollingGoHotelSearchCheckInParam = {
    checkInDate: request.checkInDate,
    stayNights: request.stayNights,
    adultCount: request.adultCount
  };
  return {
    originQuery: request.originQuery,
    place: request.place,
    placeType: request.placeType,
    countryCode: request.countryCode,
    size: request.size,
    checkInParam: checkInParam
  };
}

export function hotelDetailProviderArgs(request: HotelDetailRequest): RollingGoHotelDetailArgs {
  const dateParam: RollingGoHotelDetailDateParam = {
    checkInDate: request.checkInDate,
    checkOutDate: request.checkOutDate
  };
  const localeParam: RollingGoHotelDetailLocaleParam = {
    countryCode: request.countryCode,
    currency: request.currency
  };
  const occupancyParam: RollingGoHotelDetailOccupancyParam = {
    adultCount: request.adultCount,
    childCount: request.childCount,
    childAgeDetails: request.childAgeDetails.slice(),
    roomCount: request.roomCount
  };
  return {
    hotelId: request.hotelId,
    dateParam: dateParam,
    localeParam: localeParam,
    occupancyParam: occupancyParam
  };
}

function emptySearchResult(request: HotelSearchRequest, error: string): HotelSearchResult {
  return {
    ok: false,
    error: error,
    message: '',
    query: request,
    hotels: []
  };
}

function emptyDetailResult(request: HotelDetailRequest, error: string): HotelDetailResult {
  return {
    ok: false,
    error: error,
    message: '',
    query: request,
    hotelId: request.hotelId,
    bookingUrl: '',
    name: '',
    nameEn: '',
    checkIn: request.checkInDate,
    checkOut: request.checkOutDate,
    rates: []
  };
}

function normalizeHotelPrice(price: RollingGoHotelPriceRecord | undefined): HotelPrice {
  const source: RollingGoHotelPriceRecord = price === undefined ? {} : price;
  const amount = optionalNumberOf(source.lowestPrice);
  const currency = currencyOf(source.currency);
  return {
    message: textOf(source.message),
    hasPrice: source.hasPrice === true && amount !== null && currency.length > 0,
    currency: currency,
    lowestPrice: amount === null ? 0 : amount
  };
}

function normalizeHotelItem(item: RollingGoHotelSearchItemRecord): HotelSearchItem {
  return {
    hotelId: numberOf(item.hotelId),
    bookingUrl: textOf(item.bookingUrl),
    name: textOf(item.name),
    nameEn: textOf(item.nameEn),
    brand: textOf(item.brand),
    address: textOf(item.address),
    destinationId: textOf(item.destinationId),
    latitude: numberOf(item.latitude),
    longitude: numberOf(item.longitude),
    distanceInMeters: numberOf(item.distanceInMeters),
    starRating: numberOf(item.starRating),
    price: isRecordValue(item.price) ? normalizeHotelPrice(item.price as RollingGoHotelPriceRecord) :
      normalizeHotelPrice(undefined),
    areaCode: textOf(item.areaCode),
    description: textOf(item.description),
    imageUrl: textOf(item.imageUrl),
    hotelAmenities: stringArrayOf(item.hotelAmenities),
    tags: stringArrayOf(item.tags)
  };
}

function normalizeRatePlan(item: RollingGoHotelRateRecord): HotelRatePlan {
  return {
    roomName: textOf(item.roomName),
    roomNameCn: textOf(item.roomNameCn),
    ratePlanId: textOf(item.ratePlanId),
    ratePlanName: textOf(item.ratePlanName),
    averagePrice: optionalNumberOf(item.averagePrice),
    bedTypeDescription: textOf(item.bedTypeDescription),
    currency: currencyOf(item.currency),
    mealAmount: numberOf(item.mealAmount),
    mealTypeStr: textOf(item.mealTypeStr),
    isOnRequest: typeof item.isOnRequest === 'boolean' ? item.isOnRequest : null,
    cancelPolicy: textOf(item.cancelPolicy)
  };
}

export function normalizeHotelSearchResult(payload: McpToolResultPayload, request: HotelSearchRequest): HotelSearchResult {
  if (payload.isError === true) {
    return emptySearchResult(request, 'RollingGo MCP returned isError=true.');
  }
  if (payload.structuredContent === undefined || payload.structuredContent === null) {
    return emptySearchResult(request, 'RollingGo searchHotels returned no structuredContent.');
  }
  const response = payload.structuredContent as RollingGoHotelSearchResponse;
  if (response.success !== true) {
    const message = textOf(response.message);
    return emptySearchResult(request, message.length > 0 ? message : 'RollingGo searchHotels failed.');
  }
  if (response.hotelInformationList !== undefined && !Array.isArray(response.hotelInformationList)) {
    return emptySearchResult(request, 'RollingGo searchHotels returned an invalid hotelInformationList.');
  }
  const hotels: HotelSearchItem[] = [];
  const source: HotelValue[] = response.hotelInformationList === undefined ? [] :
    response.hotelInformationList as HotelValue[];
  for (let index = 0; index < source.length; index++) {
    const item = source[index];
    if (!isRecordValue(item)) {
      return emptySearchResult(request, 'RollingGo searchHotels returned an invalid hotelInformationList item.');
    }
    const normalized = normalizeHotelItem(item as RollingGoHotelSearchItemRecord);
    if (normalized.hotelId > 0) {
      hotels.push(normalized);
    }
  }
  return {
    ok: true,
    error: '',
    message: textOf(response.message),
    query: request,
    hotels: hotels
  };
}

export function normalizeHotelDetailResult(payload: McpToolResultPayload, request: HotelDetailRequest): HotelDetailResult {
  if (payload.isError === true) {
    return emptyDetailResult(request, 'RollingGo MCP returned isError=true.');
  }
  if (payload.structuredContent === undefined || payload.structuredContent === null) {
    return emptyDetailResult(request, 'RollingGo getHotelDetail returned no structuredContent.');
  }
  const response = payload.structuredContent as RollingGoHotelDetailResponse;
  if (response.success !== true) {
    const message = textOf(response.message);
    return emptyDetailResult(request, message.length > 0 ? message : 'RollingGo getHotelDetail failed.');
  }
  const providerHotelId = numberOf(response.hotelId);
  if (providerHotelId <= 0 || providerHotelId !== request.hotelId) {
    return emptyDetailResult(request, 'RollingGo getHotelDetail returned a mismatched hotelId.');
  }
  if (response.roomRatePlans !== undefined && !Array.isArray(response.roomRatePlans)) {
    return emptyDetailResult(request, 'RollingGo getHotelDetail returned invalid roomRatePlans.');
  }
  const rates: HotelRatePlan[] = [];
  const source: HotelValue[] = response.roomRatePlans === undefined ? [] :
    response.roomRatePlans as HotelValue[];
  for (let index = 0; index < source.length; index++) {
    const item = source[index];
    if (!isRecordValue(item)) {
      return emptyDetailResult(request, 'RollingGo getHotelDetail returned an invalid roomRatePlans item.');
    }
    const normalized = normalizeRatePlan(item as RollingGoHotelRateRecord);
    if (normalized.ratePlanId.length > 0) {
      rates.push(normalized);
    }
  }
  return {
    ok: true,
    error: '',
    message: textOf(response.message),
    query: request,
    hotelId: providerHotelId,
    bookingUrl: textOf(response.bookingUrl),
    name: textOf(response.name),
    nameEn: textOf(response.nameEn),
    checkIn: textOf(response.checkIn).length > 0 ? textOf(response.checkIn) : request.checkInDate,
    checkOut: textOf(response.checkOut).length > 0 ? textOf(response.checkOut) : request.checkOutDate,
    rates: rates
  };
}
