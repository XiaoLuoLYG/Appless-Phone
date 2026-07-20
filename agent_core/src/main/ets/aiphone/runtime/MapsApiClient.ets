import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { A2uiFoodData, A2uiLabelValueData } from './A2uiTypes';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import { aiLogError, aiLogInfo } from './AiphoneLogger';
import {
  HotelContactCandidate,
  HotelContactDetails,
  HotelContactLookupResult,
  hotelContactFromDetails,
  selectHotelContactCandidate
} from './HotelContactLookup';
import { HotelSearchItem } from './HotelToolTypes';

const PLACES_SEARCH_URL: string = 'https://places.googleapis.com/v1/places:searchText';
const PLACES_BASE_URL: string = 'https://places.googleapis.com/v1/places/';
const PLACES_FIELD_MASK: string = 'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.googleMapsUri,places.currentOpeningHours.openNow';
const PLACE_DETAIL_FIELD_MASK: string = 'id,displayName,formattedAddress,location,rating,googleMapsUri,currentOpeningHours.openNow';
export const HOTEL_CONTACT_SEARCH_FIELD_MASK: string =
  'places.id,places.displayName,places.formattedAddress,places.location';
export const HOTEL_CONTACT_DETAIL_FIELD_MASK: string =
  'id,displayName,formattedAddress,location,nationalPhoneNumber,internationalPhoneNumber';

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
  nationalPhoneNumber?: string;
  internationalPhoneNumber?: string;
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

interface PlacesResponseMarker {
  received: boolean;
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

export function googleMapsDirectionsUrl(value: Object | null): string {
  const args = routeArgs(value);
  const origin = textOf(args.origin).trim();
  const destination = textOf(args.destination).trim();
  if (origin.length === 0 || destination.length === 0) {
    return '';
  }
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

function placeRows(place: MapsPlacePayload): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [
    { label: 'Place ID', value: textOf(place.id) },
    { label: 'Address', value: textOf(place.formattedAddress) },
    { label: 'Rating', value: textOf(place.rating) }
  ];
  const mapLocation = placeMapLocation(place);
  if (mapLocation.length > 0) {
    rows.push({ label: 'Map Location', value: mapLocation });
  }
  if (place.currentOpeningHours !== undefined) {
    rows.push({ label: 'Open now', value: textOf(place.currentOpeningHours.openNow) });
  }
  if (textOf(place.googleMapsUri).length > 0) {
    rows.push({ label: 'Maps URL', value: textOf(place.googleMapsUri) });
  }
  return rows;
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

function placeResult(toolId: string, place: MapsPlacePayload, summary: string): DynamicGenericToolResult {
  const id = textOf(place.id);
  return {
    sourceTag: 'Google Places API',
    toolName: toolId,
    title: placeTitle(place),
    status: 'success',
    summary: summary,
    rows: placeRows(place),
    rawPreview: 'placeId=' + id
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
  const payload = JSON.parse(rawJson) as MapsTextSearchPayload;
  const places = Array.isArray(payload.places) ? payload.places : [];
  const results: DynamicGenericToolResult[] = [];
  for (let index = 0; index < places.length; index++) {
    results.push(placeResult('maps.place.search', places[index], 'Google Places result for: ' + query));
  }
  if (results.length === 0) {
    return [{
      sourceTag: 'Google Places API',
      toolName: 'maps.place.search',
      title: '没有找到地点',
      status: 'success',
      summary: 'Google Places API 查询成功，但没有返回可展示地点。',
      rows: [{ label: 'Query', value: query }],
      rawPreview: 'empty places'
    }];
  }
  return results;
}

function optionalCoordinate(value: number | undefined): number | null {
  return value === undefined || !Number.isFinite(value) ? null : value;
}

function hotelContactCandidate(place: MapsPlacePayload): HotelContactCandidate {
  const location = place.location;
  return {
    providerPlaceId: textOf(place.id).trim(),
    displayName: place.displayName === undefined ? '' : textOf(place.displayName.text).trim(),
    formattedAddress: textOf(place.formattedAddress).trim(),
    latitude: location === undefined ? null : optionalCoordinate(location.latitude),
    longitude: location === undefined ? null : optionalCoordinate(location.longitude)
  };
}

export function hotelContactCandidatesFromPayload(rawJson: string): HotelContactCandidate[] {
  const payload = JSON.parse(rawJson) as MapsTextSearchPayload;
  const places = Array.isArray(payload.places) ? payload.places : [];
  const candidates: HotelContactCandidate[] = [];
  for (let index = 0; index < places.length; index++) {
    candidates.push(hotelContactCandidate(places[index]));
  }
  return candidates;
}

export function hotelContactDetailsFromPayload(rawJson: string): HotelContactDetails {
  const place = JSON.parse(rawJson) as MapsPlacePayload;
  const candidate = hotelContactCandidate(place);
  return {
    providerPlaceId: candidate.providerPlaceId,
    displayName: candidate.displayName,
    formattedAddress: candidate.formattedAddress,
    latitude: candidate.latitude,
    longitude: candidate.longitude,
    nationalPhoneNumber: textOf(place.nationalPhoneNumber).trim(),
    internationalPhoneNumber: textOf(place.internationalPhoneNumber).trim()
  };
}

function boundedHotelContactWarning(message: string): string {
  return message.substring(0, 240);
}

function hotelContactSearchQuery(hotel: HotelSearchItem): string {
  const name = hotel.name.trim().length > 0 ? hotel.name.trim() : hotel.nameEn.trim();
  return hotel.address.trim().length > 0 ? name + ' ' + hotel.address.trim() : name;
}

async function requestJson(
  method: http.RequestMethod,
  url: string,
  apiKey: string,
  fieldMask: string,
  body: Object | null,
  responseMarker?: PlacesResponseMarker
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
    if (responseMarker !== undefined) {
      responseMarker.received = true;
    }
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

export async function callHotelContactLookup(
  hotel: HotelSearchItem,
  apiKey: string
): Promise<HotelContactLookupResult> {
  const key = apiKey.trim();
  if (key.length === 0) {
    return {
      contact: null,
      warning: 'Google Places contact lookup skipped: GOOGLE_MAPS_API_KEY is missing.',
      sourceReceived: false
    };
  }
  const responseMarker: PlacesResponseMarker = { received: false };
  try {
    const searchPayload = await requestJson(
      http.RequestMethod.POST,
      PLACES_SEARCH_URL,
      key,
      HOTEL_CONTACT_SEARCH_FIELD_MASK,
      mapsTextSearchBody(hotelContactSearchQuery(hotel)),
      responseMarker
    );
    const match = selectHotelContactCandidate(
      hotel,
      hotelContactCandidatesFromPayload(JSON.stringify(searchPayload))
    );
    if (match.candidate === null) {
      return { contact: null, warning: boundedHotelContactWarning(match.warning), sourceReceived: true };
    }
    const detailPayload = await requestJson(
      http.RequestMethod.GET,
      PLACES_BASE_URL + encodeParam(match.candidate.providerPlaceId),
      key,
      HOTEL_CONTACT_DETAIL_FIELD_MASK,
      null,
      responseMarker
    );
    const contact = hotelContactFromDetails(
      hotelContactDetailsFromPayload(JSON.stringify(detailPayload)),
      match.candidate.providerPlaceId
    );
    if (contact === null) {
      return {
        contact: null,
        warning: 'Google Places returned no verified hotel phone.',
        sourceReceived: true
      };
    }
    return { contact: contact, warning: '', sourceReceived: true };
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    return {
      contact: null,
      warning: boundedHotelContactWarning('Google Places contact lookup failed: ' + message),
      sourceReceived: responseMarker.received
    };
  }
}

export async function callMapsPlaceSearch(query: string, apiKey: string): Promise<DynamicGenericToolResult[]> {
  if (apiKey.trim().length === 0) {
    return [mapsMissingApiKeyResult('maps.place.search')];
  }
  try {
    const payload = await requestJson(http.RequestMethod.POST, PLACES_SEARCH_URL, apiKey.trim(), PLACES_FIELD_MASK, mapsTextSearchBody(query));
    return mapsTextSearchResultsFromPayload(JSON.stringify(payload), query);
  } catch (error) {
    return [errorResult('maps.place.search', 'Google Places API 调用失败', error instanceof Error ? error.message : JSON.stringify(error))];
  }
}

export async function callMapsPlaceDetails(placeId: string, apiKey: string): Promise<DynamicGenericToolResult[]> {
  if (apiKey.trim().length === 0) {
    return [mapsMissingApiKeyResult('maps.place.details')];
  }
  if (placeId.trim().length === 0) {
    return [mapsMissingPlaceIdResult()];
  }
  try {
    const payload = await requestJson(http.RequestMethod.GET, PLACES_BASE_URL + encodeParam(placeId.trim()), apiKey.trim(), PLACE_DETAIL_FIELD_MASK, null) as MapsPlacePayload;
    return [placeResult('maps.place.details', payload, 'Google Places details returned by the real API.')];
  } catch (error) {
    return [errorResult('maps.place.details', 'Google Places API 调用失败', error instanceof Error ? error.message : JSON.stringify(error))];
  }
}
