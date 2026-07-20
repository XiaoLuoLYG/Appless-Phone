import { ActionValidationResult } from '../../agent/action/ActionCatalogTypes';
import { A2uiAction } from './A2uiTypes';
import {
  HotelDetailRequest,
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

export interface HotelCallArgs {
  hotelId: number;
  name: string;
  displayPhone: string;
  dialPhone: string;
  provider: string;
  providerPlaceId: string;
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

export function compactHotelDialPhone(value: string): string {
  if (typeof value !== 'string') {
    return '';
  }
  const compact = value.replace(/[ ()-]/g, '');
  return /^\+?[0-9]{5,20}$/.test(compact) ? compact : '';
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

export function hotelCallArgs(hotel: HotelSearchItem): HotelCallArgs {
  return {
    hotelId: hotel.hotelId,
    name: displayName(hotel),
    displayPhone: hotel.contact === undefined ? '' : hotel.contact.displayPhone,
    dialPhone: hotel.contact === undefined ? '' : hotel.contact.dialPhone,
    provider: hotel.contact === undefined ? '' : hotel.contact.provider,
    providerPlaceId: hotel.contact === undefined ? '' : hotel.contact.providerPlaceId
  };
}

export function validHotelCallArgs(args: HotelCallArgs): ActionValidationResult {
  if (!Number.isInteger(args.hotelId) || args.hotelId <= 0) {
    return invalid('Hotel call requires a positive hotelId.');
  }
  const displayCompact = typeof args.displayPhone === 'string' ?
    compactHotelDialPhone(args.displayPhone) : '';
  const dialCompact = typeof args.dialPhone === 'string' ?
    compactHotelDialPhone(args.dialPhone) : '';
  if (typeof args.displayPhone !== 'string' || typeof args.dialPhone !== 'string' ||
    typeof args.provider !== 'string' || typeof args.providerPlaceId !== 'string' ||
    displayCompact.length === 0 || dialCompact.length === 0 || displayCompact !== dialCompact ||
    args.provider.trim().length === 0 || args.providerPlaceId.trim().length === 0) {
    return invalid('Hotel call requires a verified provider phone and place ID.');
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

export function hotelCallAction(hotel: HotelSearchItem): A2uiAction {
  return {
    id: 'hotel.call',
    label: '联系酒店',
    prompt: '打开 ' + displayName(hotel) + ' 的系统拨号盘',
    kind: 'prompt',
    variant: 'secondary',
    args: hotelCallArgs(hotel)
  };
}

export function validateHotelActionArgs(actionId: string, args: Object): ActionValidationResult {
  if (actionId === 'hotel.detail') {
    const parsed = parseHotelDetailRequest(args);
    return parsed.ok && parsed.value !== null ? valid() : invalid(parsed.error);
  }
  if (actionId === 'hotel.navigate') {
    return validHotelNavigateArgs(args as HotelNavigateArgs);
  }
  if (actionId === 'hotel.call') {
    return validHotelCallArgs(args as HotelCallArgs);
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
  if (hotel.contact !== undefined) {
    const call = hotelCallAction(hotel);
    if (validHotelCallArgs(call.args as HotelCallArgs).ok && canPlace(call)) {
      actions.push(call);
    }
  }
  return actions;
}
