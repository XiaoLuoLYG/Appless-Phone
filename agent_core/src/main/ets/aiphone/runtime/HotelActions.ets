import { ActionValidationResult } from '../../agent/action/ActionCatalogTypes';
import { A2uiAction } from './A2uiTypes';
import {
  HotelDetailRequest,
  HotelDetailResult,
  HotelSearchItem,
  HotelSearchRequest,
  parseHotelDetailRequest
} from './HotelToolTypes';

export interface HotelNavigateArgs {
  hotelId: number;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
}

export interface HotelBookingOpenArgs {
  hotelId: number;
  bookingUrl: string;
}

function valid(): ActionValidationResult {
  return { ok: true, code: '', message: '' };
}

function invalid(message: string): ActionValidationResult {
  return { ok: false, code: 'HOTEL_ACTION_ARGS_INVALID', message: message };
}

function displayName(hotel: HotelSearchItem): string {
  return hotel.name.length > 0 ? hotel.name : hotel.nameEn;
}

function validCoordinate(value: number, minimum: number, maximum: number): boolean {
  return Number.isFinite(value) && value >= minimum && value <= maximum;
}

export function hasValidHotelCoordinates(hotel: HotelSearchItem): boolean {
  return hotel.latitude !== null && hotel.longitude !== null &&
    validCoordinate(hotel.latitude, -90, 90) && validCoordinate(hotel.longitude, -180, 180);
}

export function hotelNavigateArgs(hotel: HotelSearchItem): HotelNavigateArgs {
  return {
    hotelId: hotel.hotelId,
    name: displayName(hotel),
    address: hotel.address,
    latitude: hotel.latitude as number,
    longitude: hotel.longitude as number
  };
}

export function validHotelNavigateArgs(args: HotelNavigateArgs): ActionValidationResult {
  if (!Number.isInteger(args.hotelId) || args.hotelId <= 0) {
    return invalid('Hotel navigation requires a positive hotelId.');
  }
  if (!validCoordinate(args.latitude, -90, 90) || !validCoordinate(args.longitude, -180, 180)) {
    return invalid('Hotel navigation requires finite bounded coordinates.');
  }
  return valid();
}

export function hotelDetailAction(hotel: HotelSearchItem, request: HotelSearchRequest): A2uiAction {
  const args: HotelDetailRequest = {
    hotelId: hotel.hotelId,
    checkInDate: request.checkInDate,
    checkOutDate: request.checkOutDate,
    countryCode: request.countryCode,
    currency: request.currency,
    adultCount: request.adultCount,
    childCount: request.childCount,
    childAgeDetails: request.childAgeDetails.slice(),
    roomCount: request.roomCount
  };
  return {
    id: 'hotel.detail',
    label: '查看实时房型',
    prompt: '查看 ' + displayName(hotel) + ' 的实时房型与取消政策',
    kind: 'prompt',
    variant: 'primary',
    args: args
  };
}

export function hotelNavigateAction(hotel: HotelSearchItem): A2uiAction {
  return {
    id: 'hotel.navigate',
    label: '导航到酒店',
    prompt: '导航到 ' + displayName(hotel),
    kind: 'prompt',
    variant: 'secondary',
    args: hotelNavigateArgs(hotel)
  };
}

export function hotelBookingOpenAction(result: HotelDetailResult): A2uiAction {
  return {
    id: 'hotel.booking.open',
    label: '在 App 内继续预订',
    prompt: '在 Appless 内打开 RollingGo 酒店预订',
    kind: 'prompt',
    variant: 'primary',
    args: {
      hotelId: result.hotelId,
      bookingUrl: result.bookingUrl
    } as HotelBookingOpenArgs
  };
}

interface ParsedHotelUrl {
  authority: string;
  path: string;
  query: Record<string, string>;
  duplicateKeys: string[];
}

function parsedHttpsHotelUrl(value: string): ParsedHotelUrl | null {
  if (typeof value !== 'string') {
    return null;
  }
  const match = /^https:\/\/([^\/?#]+)(\/[^?#]*)?(?:\?([^#]*))?(?:#.*)?$/.exec(value.trim());
  if (match === null || match[1].indexOf('@') >= 0) {
    return null;
  }
  const query: Record<string, string> = {};
  const duplicateKeys: string[] = [];
  const rawQuery = match[3] === undefined ? '' : match[3];
  if (rawQuery.length > 0) {
    const pairs = rawQuery.split('&');
    for (let index = 0; index < pairs.length; index += 1) {
      const equals = pairs[index].indexOf('=');
      if (equals <= 0) {
        return null;
      }
      let key = '';
      let decoded = '';
      try {
        key = decodeURIComponent(pairs[index].substring(0, equals));
        decoded = decodeURIComponent(pairs[index].substring(equals + 1));
      } catch (_error) {
        return null;
      }
      if (Object.keys(query).indexOf(key) >= 0) {
        duplicateKeys.push(key);
      } else {
        query[key] = decoded;
      }
    }
  }
  return {
    authority: match[1].toLowerCase(),
    path: match[2] === undefined || match[2].length === 0 ? '/' : match[2],
    query: query,
    duplicateKeys: duplicateKeys
  };
}

function validIsoDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const time = Date.parse(value + 'T00:00:00Z');
  return Number.isFinite(time) && new Date(time).toISOString().substring(0, 10) === value;
}

function validCount(value: string, allowZero: boolean): boolean {
  if (!/^\d+$/.test(value)) {
    return false;
  }
  const count = Number.parseInt(value, 10);
  return Number.isInteger(count) && (allowZero ? count >= 0 : count > 0);
}

export function isAllowedHotelBookingNavigationUrl(value: string): boolean {
  const parsed = parsedHttpsHotelUrl(value);
  return parsed !== null && parsed.authority === 'rollinggo.cn';
}

export function isRollingGoHotelBookingUrl(value: string): boolean {
  const parsed = parsedHttpsHotelUrl(value);
  if (parsed === null || parsed.authority !== 'rollinggo.cn' ||
    parsed.path !== '/pages/hotel/detail/index' || parsed.duplicateKeys.length > 0) {
    return false;
  }
  const query = parsed.query;
  return /^[1-9]\d*$/.test(query['id'] || '') &&
    validIsoDate(query['checkInDate'] || '') &&
    validIsoDate(query['checkOutDate'] || '') &&
    query['checkOutDate'] > query['checkInDate'] &&
    validCount(query['roomCount'] || '', false) &&
    validCount(query['adultCount'] || '', false) &&
    validCount(query['childCount'] || '', true);
}

export function validHotelBookingOpenArgs(args: HotelBookingOpenArgs): ActionValidationResult {
  if (args === null || typeof args !== 'object' ||
    !Number.isInteger(args.hotelId) || args.hotelId <= 0 ||
    typeof args.bookingUrl !== 'string' || !isRollingGoHotelBookingUrl(args.bookingUrl)) {
    return invalid('Hotel booking requires a valid RollingGo hotel URL.');
  }
  const parsed = parsedHttpsHotelUrl(args.bookingUrl) as ParsedHotelUrl;
  return parsed.query['id'] === args.hotelId.toString() ? valid() :
    invalid('Hotel booking URL id must match hotelId.');
}

export function validateHotelActionArgs(actionId: string, args: Object): ActionValidationResult {
  if (actionId === 'hotel.detail') {
    const parsed = parseHotelDetailRequest(args);
    return parsed.ok && parsed.value !== null ? valid() : invalid(parsed.error);
  }
  if (actionId === 'hotel.navigate') {
    return validHotelNavigateArgs(args as HotelNavigateArgs);
  }
  if (actionId === 'hotel.booking.open') {
    return validHotelBookingOpenArgs(args as HotelBookingOpenArgs);
  }
  return invalid('Unsupported hotel action: ' + actionId + '.');
}

export function hotelActionsFor(
  hotel: HotelSearchItem,
  request: HotelSearchRequest,
  canPlace: (action: A2uiAction) => boolean
): A2uiAction[] {
  if (!Number.isInteger(hotel.hotelId) || hotel.hotelId <= 0) {
    return [];
  }
  const actions: A2uiAction[] = [];
  const detail = hotelDetailAction(hotel, request);
  if (canPlace(detail)) {
    actions.push(detail);
  }
  if (hasValidHotelCoordinates(hotel)) {
    const navigate = hotelNavigateAction(hotel);
    if (validHotelNavigateArgs(navigate.args as HotelNavigateArgs).ok && canPlace(navigate)) {
      actions.push(navigate);
    }
  }
  return actions;
}
