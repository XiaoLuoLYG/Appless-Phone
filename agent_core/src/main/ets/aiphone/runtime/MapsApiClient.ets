import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { A2uiFoodData, A2uiLabelValueData } from './A2uiTypes';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import { aiLogError, aiLogInfo } from './AiphoneLogger';

const PLACES_SEARCH_URL: string = 'https://places.googleapis.com/v1/places:searchText';
const PLACES_BASE_URL: string = 'https://places.googleapis.com/v1/places/';
const PLACES_FIELD_MASK: string = 'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.googleMapsUri,places.currentOpeningHours.openNow';
const PLACE_DETAIL_FIELD_MASK: string = 'id,displayName,formattedAddress,location,rating,googleMapsUri,currentOpeningHours.openNow';

interface MapsTextSearchPayload {
  places?: MapsPlacePayload[];
}

interface MapsTextSearchRequest {
  textQuery: string;
  languageCode: string;
  maxResultCount: number;
}

interface MapsPlacePayload {
  id?: string;
  formattedAddress?: string;
  rating?: number;
  googleMapsUri?: string;
  currentOpeningHours?: MapsOpeningHours;
  displayName?: MapsDisplayName;
  location?: MapsLocation;
}

interface MapsDisplayName {
  text?: string;
}

interface MapsLocation {
  latitude?: number;
  longitude?: number;
}

interface MapsOpeningHours {
  openNow?: boolean;
}

export type MapsPlaceProviderStatus = 'success' | 'empty' | 'error';

export interface MapsPlaceRecord {
  placeId: string;
  title: string;
  address: string;
  rating: string;
  mapLocation: string;
  openNow: string;
  mapsUrl: string;
}

export interface MapsPlaceProviderResult {
  toolId: string;
  status: MapsPlaceProviderStatus;
  places: MapsPlaceRecord[];
  query: string;
  message: string;
  attempted: boolean;
}

export interface MapsStructuredData {
  places: MapsPlaceRecord[];
  query: string;
}

export interface MapsRouteArgs {
  origin?: string;
  destination?: string;
  travelMode?: string;
  navigate?: boolean;
}

interface GoogleApiError {
  message?: string;
  status?: string;
}

interface GoogleApiErrorPayload {
  error?: GoogleApiError;
}

function textOf(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

function responseText(result: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(result));
  }
  return textOf(result);
}

function encodeParam(value: string): string {
  return encodeURIComponent(value);
}

function routeArgs(value: Object | null): MapsRouteArgs {
  return value === null ? JSON.parse('{}') as MapsRouteArgs : value as MapsRouteArgs;
}

function routeTravelMode(value: string | undefined): string {
  const mode = textOf(value).trim().toLowerCase();
  return ['driving', 'walking', 'bicycling', 'transit', 'two-wheeler'].indexOf(mode) >= 0 ? mode : 'driving';
}

export function normalizeMapsRouteInput(value: Object | null): MapsRouteArgs | null {
  const args = routeArgs(value);
  const origin = textOf(args.origin).trim();
  const destination = textOf(args.destination).trim();
  if (origin.length === 0 || destination.length === 0) {
    return null;
  }
  return {
    origin,
    destination,
    travelMode: routeTravelMode(args.travelMode),
    navigate: args.navigate === true
  };
}

function trimRoutePrefix(value: string): string {
  const prefixes: string[] = [
    '请帮我打开',
    '帮我打开',
    '请打开',
    '打开',
    '请帮我查看',
    '帮我查看',
    '请查看',
    '查看'
  ];
  let current = value.trim();
  for (let index = 0; index < prefixes.length; index++) {
    if (current.startsWith(prefixes[index])) {
      current = current.substring(prefixes[index].length).trim();
      break;
    }
  }
  if (current.startsWith('从')) {
    current = current.substring(1).trim();
  }
  return current;
}

function trimRouteSuffix(value: string): string {
  const suffixes: string[] = [
    '并发起导航',
    '并开始导航',
    '的驾车路线',
    '的步行路线',
    '的骑行路线',
    '的公交路线',
    '的路线',
    '路线',
    '并导航',
    '导航'
  ];
  let current = value.trim();
  for (let index = 0; index < suffixes.length; index++) {
    if (current.endsWith(suffixes[index])) {
      current = current.substring(0, current.length - suffixes[index].length).trim();
      break;
    }
  }
  return current;
}

export function mapsRouteInputFromPrompt(prompt: string): MapsRouteArgs | null {
  const source = trimRoutePrefix(prompt);
  const separator = source.indexOf('到');
  if (separator <= 0 || separator !== source.lastIndexOf('到')) {
    return null;
  }
  const origin = source.substring(0, separator).trim();
  const destination = trimRouteSuffix(source.substring(separator + 1));
  if (origin.length < 2 || destination.length < 2 ||
    origin.indexOf('路线') >= 0 || destination.indexOf('路线') >= 0) {
    return null;
  }
  let travelMode = 'driving';
  if (prompt.indexOf('步行') >= 0) {
    travelMode = 'walking';
  } else if (prompt.indexOf('骑行') >= 0 || prompt.indexOf('骑车') >= 0) {
    travelMode = 'bicycling';
  } else if (prompt.indexOf('公交') >= 0 || prompt.indexOf('公共交通') >= 0) {
    travelMode = 'transit';
  }
  const candidate: MapsRouteArgs = {
    origin,
    destination,
    travelMode,
    navigate: prompt.indexOf('导航') >= 0
  };
  return normalizeMapsRouteInput(candidate as Object);
}

export function googleMapsDirectionsUrl(value: Object | null): string {
  const args = normalizeMapsRouteInput(value);
  if (args === null) {
    return '';
  }
  const origin = args.origin as string;
  const destination = args.destination as string;
  let url = 'https://www.google.com/maps/dir/?api=1&origin=' + encodeParam(origin) +
    '&destination=' + encodeParam(destination) + '&travelmode=' + routeTravelMode(args.travelMode);
  if (args.navigate === true) {
    url += '&dir_action=navigate';
  }
  return url;
}

export function mapsRouteResult(value: Object | null): DynamicGenericToolResult {
  const args = routeArgs(value);
  const origin = textOf(args.origin).trim();
  const destination = textOf(args.destination).trim();
  const url = googleMapsDirectionsUrl(value);
  if (url.length === 0) {
    const missing: A2uiLabelValueData[] = [];
    if (origin.length === 0) {
      missing.push({ label: 'Missing', value: 'origin' });
    }
    if (destination.length === 0) {
      missing.push({ label: 'Missing', value: 'destination' });
    }
    return {
      sourceTag: 'Google Maps URL',
      toolName: 'maps.route.open',
      title: '需要路线起终点',
      status: 'needs_input',
      summary: '请提供起点和终点后再查询路线。',
      rows: missing,
      rawPreview: 'missing route endpoints'
    };
  }
  return {
    sourceTag: 'Google Maps',
    toolName: 'maps.route.open',
    title: origin + ' → ' + destination,
    status: 'success',
    summary: '路线已准备好。',
    rows: [
      { label: 'Origin', value: origin },
      { label: 'Destination', value: destination },
      { label: 'Travel Mode', value: routeTravelMode(args.travelMode) },
      { label: 'Maps URL', value: url }
    ],
    rawPreview: url,
    actions: [{ id: 'maps.open.web', label: '查看路线', prompt: url, variant: 'primary', kind: 'client' }]
  };
}

export function mapsTextSearchBody(query: string): MapsTextSearchRequest {
  return {
    textQuery: query,
    languageCode: 'zh-CN',
    maxResultCount: 10
  };
}

function placeTitle(place: MapsPlacePayload): string {
  const title = place.displayName === undefined ? '' : textOf(place.displayName.text);
  return title.length > 0 ? title : textOf(place.id);
}

function placeMapLocation(place: MapsPlacePayload): string {
  if (place.location === undefined) {
    return '';
  }
  const latitude = place.location.latitude;
  const longitude = place.location.longitude;
  if (latitude === undefined || longitude === undefined || !Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return '';
  }
  return latitude.toString() + ',' + longitude.toString();
}

function mapsPlaceRecord(place: MapsPlacePayload): MapsPlaceRecord {
  return {
    placeId: textOf(place.id),
    title: placeTitle(place),
    address: textOf(place.formattedAddress),
    rating: textOf(place.rating),
    mapLocation: placeMapLocation(place),
    openNow: place.currentOpeningHours === undefined ? '' : textOf(place.currentOpeningHours.openNow),
    mapsUrl: textOf(place.googleMapsUri)
  };
}

function mapsPlaceRecordHasData(place: MapsPlaceRecord): boolean {
  return place.placeId.length > 0 || place.title.length > 0 || place.address.length > 0;
}

function mapsPlaceProviderResult(
  toolId: string,
  places: MapsPlaceRecord[],
  query: string,
  message: string,
  attempted: boolean = true
): MapsPlaceProviderResult {
  return {
    toolId: toolId,
    status: places.length > 0 ? 'success' : 'empty',
    places: places,
    query: query,
    message: message,
    attempted: attempted
  };
}

export function mapsPlaceProviderFailure(
  toolId: string,
  message: string,
  attempted: boolean = true,
  query: string = ''
): MapsPlaceProviderResult {
  return {
    toolId: toolId,
    status: 'error',
    places: [],
    query: query,
    message: message,
    attempted: attempted
  };
}

export function mapsPlaceSearchProviderResultFromPayload(rawJson: string, query: string): MapsPlaceProviderResult {
  const payload = JSON.parse(rawJson) as MapsTextSearchPayload;
  const places: MapsPlaceRecord[] = [];
  const rawPlaces = Array.isArray(payload.places) ? payload.places : [];
  rawPlaces.forEach((place: MapsPlacePayload) => {
    const record = mapsPlaceRecord(place);
    if (mapsPlaceRecordHasData(record)) {
      places.push(record);
    }
  });
  return mapsPlaceProviderResult(
    'maps.place.search',
    places,
    query,
    places.length > 0 ? 'Google Places result for: ' + query : 'Google Places API 查询成功，但没有返回可展示地点。'
  );
}

export function mapsPlaceDetailsProviderResultFromPayload(rawJson: string): MapsPlaceProviderResult {
  const record = mapsPlaceRecord(JSON.parse(rawJson) as MapsPlacePayload);
  return mapsPlaceProviderResult(
    'maps.place.details',
    mapsPlaceRecordHasData(record) ? [record] : [],
    '',
    mapsPlaceRecordHasData(record) ? 'Google Places details returned by the real API.' : 'Google Places API 查询成功，但没有返回可展示地点详情。'
  );
}

function placeRowsFromRecord(place: MapsPlaceRecord): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [
    { label: 'Place ID', value: place.placeId },
    { label: 'Address', value: place.address },
    { label: 'Rating', value: place.rating }
  ];
  if (place.mapLocation.length > 0) {
    rows.push({ label: 'Map Location', value: place.mapLocation });
  }
  if (place.openNow.length > 0) {
    rows.push({ label: 'Open now', value: place.openNow });
  }
  if (place.mapsUrl.length > 0) {
    rows.push({ label: 'Maps URL', value: place.mapsUrl });
  }
  return rows;
}

function placeResultFromRecord(toolId: string, place: MapsPlaceRecord, summary: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Google Places API',
    toolName: toolId,
    title: place.title,
    status: 'success',
    summary: summary,
    rows: placeRowsFromRecord(place),
    rawPreview: 'placeId=' + place.placeId
  };
}

export function mapsPlaceProviderResultsForA2ui(result: MapsPlaceProviderResult): DynamicGenericToolResult[] {
  if (result.status === 'error') {
    const title = result.message.indexOf('GOOGLE_MAPS_API_KEY') >= 0 ? '未配置 Google Maps API' :
      (result.message.indexOf('placeId') >= 0 ? '缺少 Place ID' : 'Google Places API 调用失败');
    return [errorResult(result.toolId, title, result.message)];
  }
  if (result.places.length === 0) {
    const emptyResult: DynamicGenericToolResult = {
      sourceTag: 'Google Places API',
      toolName: result.toolId,
      title: result.toolId === 'maps.place.details' ? '没有找到地点详情' : '没有找到地点',
      status: 'success',
      summary: result.message,
      rows: [],
      rawPreview: 'empty places'
    };
    if (result.toolId === 'maps.place.search' && result.query.length > 0) {
      emptyResult.rows.push({ label: 'Query', value: result.query });
    }
    return [emptyResult];
  }
  return result.places.map((place: MapsPlaceRecord): DynamicGenericToolResult =>
    placeResultFromRecord(result.toolId, place, result.message));
}

function resultRowValue(result: DynamicGenericToolResult, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value;
    }
  }
  return '';
}

function foodLocationFromMapLocation(location: string): string {
  const parts = location.split(',');
  if (parts.length !== 2) {
    return '';
  }
  const latitude = Number(parts[0].trim());
  const longitude = Number(parts[1].trim());
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return '';
  }
  return longitude.toString() + ',' + latitude.toString();
}

export function mapsFoodRecordFromResult(result: DynamicGenericToolResult): A2uiFoodData {
  const rating = resultRowValue(result, 'Rating');
  return {
    name: result.title,
    category: rating.length > 0 ? 'Google Places · 评分 ' + rating : 'Google Places',
    address: resultRowValue(result, 'Address'),
    distance: '',
    location: foodLocationFromMapLocation(resultRowValue(result, 'Map Location')),
    sourceTags: ['Google Maps']
  };
}

function errorResult(toolId: string, title: string, message: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Google Places API',
    toolName: toolId,
    title: title,
    status: 'error',
    summary: message.substring(0, 240),
    rows: [{ label: 'Error', value: message.substring(0, 160) }],
    rawPreview: 'error=' + message.substring(0, 320)
  };
}

export function mapsMissingApiKeyResult(toolId: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Google Places API',
    toolName: toolId,
    title: '缺少 Google Maps API Key',
    status: 'error',
    summary: '缺少 GOOGLE_MAPS_API_KEY；不会改用 food.search 或模拟地点。',
    rows: [{ label: 'Missing', value: 'GOOGLE_MAPS_API_KEY' }],
    rawPreview: 'missing=GOOGLE_MAPS_API_KEY'
  };
}

export function mapsMissingPlaceIdResult(): DynamicGenericToolResult {
  return {
    sourceTag: 'Google Places API',
    toolName: 'maps.place.details',
    title: '缺少 Google Maps Place ID',
    status: 'error',
    summary: '缺少字段：placeId',
    rows: [{ label: 'Missing', value: 'placeId' }],
    rawPreview: 'missing=placeId'
  };
}

export function mapsTextSearchResultsFromPayload(rawJson: string, query: string): DynamicGenericToolResult[] {
  return mapsPlaceProviderResultsForA2ui(mapsPlaceSearchProviderResultFromPayload(rawJson, query));
}

async function requestJson(
  method: http.RequestMethod,
  url: string,
  apiKey: string,
  fieldMask: string,
  body: Object | null
): Promise<Object> {
  const request = http.createHttp();
  try {
    const headers: Record<string, string> = {
      'Accept': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': fieldMask
    };
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 20000
    };
    if (body !== null) {
      headers['Content-Type'] = 'application/json';
      options.extraData = JSON.stringify(body);
    }
    aiLogInfo('[AIPhone][MapsApiHttpStart] url=' + url.substring(0, 180));
    const response = await request.request(url, options);
    const text = responseText(response.result);
    const payload = text.length > 0 ? JSON.parse(text) as Object : new Object();
    if (response.responseCode < 200 || response.responseCode >= 300) {
      const errorPayload = payload as GoogleApiErrorPayload;
      const message = errorPayload.error === undefined ? '' : textOf(errorPayload.error.message);
      const status = errorPayload.error === undefined ? '' : textOf(errorPayload.error.status);
      throw new Error(message.length > 0 ? message : (status.length > 0 ? status : 'HTTP ' + response.responseCode.toString()));
    }
    return payload;
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    aiLogError('[AIPhone][MapsApiHttpError] error=' + message.substring(0, 220));
    throw new Error(message);
  } finally {
    request.destroy();
  }
}

export async function callMapsPlaceSearch(query: string, apiKey: string): Promise<DynamicGenericToolResult[]> {
  return mapsPlaceProviderResultsForA2ui(await callMapsPlaceSearchProvider(query, apiKey));
}

export async function callMapsPlaceSearchProvider(query: string, apiKey: string): Promise<MapsPlaceProviderResult> {
  if (apiKey.trim().length === 0) {
    return mapsPlaceProviderFailure('maps.place.search', mapsMissingApiKeyResult('maps.place.search').summary, false, query);
  }
  try {
    const payload = await requestJson(http.RequestMethod.POST, PLACES_SEARCH_URL, apiKey.trim(), PLACES_FIELD_MASK, mapsTextSearchBody(query));
    return mapsPlaceSearchProviderResultFromPayload(JSON.stringify(payload), query);
  } catch (error) {
    return mapsPlaceProviderFailure(
      'maps.place.search', error instanceof Error ? error.message : JSON.stringify(error), true, query
    );
  }
}

export async function callMapsPlaceDetails(placeId: string, apiKey: string): Promise<DynamicGenericToolResult[]> {
  return mapsPlaceProviderResultsForA2ui(await callMapsPlaceDetailsProvider(placeId, apiKey));
}

export async function callMapsPlaceDetailsProvider(placeId: string, apiKey: string): Promise<MapsPlaceProviderResult> {
  if (apiKey.trim().length === 0) {
    return mapsPlaceProviderFailure('maps.place.details', mapsMissingApiKeyResult('maps.place.details').summary, false);
  }
  if (placeId.trim().length === 0) {
    return mapsPlaceProviderFailure('maps.place.details', mapsMissingPlaceIdResult().summary, false);
  }
  try {
    const payload = await requestJson(http.RequestMethod.GET, PLACES_BASE_URL + encodeParam(placeId.trim()), apiKey.trim(), PLACE_DETAIL_FIELD_MASK, null) as MapsPlacePayload;
    return mapsPlaceDetailsProviderResultFromPayload(JSON.stringify(payload));
  } catch (error) {
    return mapsPlaceProviderFailure('maps.place.details', error instanceof Error ? error.message : JSON.stringify(error));
  }
}
