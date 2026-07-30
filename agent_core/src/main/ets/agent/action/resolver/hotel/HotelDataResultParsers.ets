import {
  HotelDetailResult,
  HotelSearchItem,
  HotelSearchResult
} from '../../../../aiphone/runtime/HotelToolTypes';
import { DataResult } from '../../../message/DataResult';

type HotelValue = Object | string | number | boolean | null | undefined;

export interface HotelSearchProjection {
  result: HotelSearchResult;
}

export interface HotelDetailProjection {
  result: HotelDetailResult;
}

function isRecord(value: HotelValue): boolean {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function recordOf(value: HotelValue): Record<string, HotelValue> | null {
  return isRecord(value) ? value as Record<string, HotelValue> : null;
}

function validSearchQuery(value: HotelValue): boolean {
  const query = recordOf(value);
  return query !== null &&
    typeof query['checkInDate'] === 'string' &&
    typeof query['checkOutDate'] === 'string' &&
    typeof query['countryCode'] === 'string' &&
    typeof query['currency'] === 'string' &&
    typeof query['adultCount'] === 'number' &&
    typeof query['childCount'] === 'number' &&
    Array.isArray(query['childAgeDetails']) &&
    typeof query['roomCount'] === 'number';
}

export function hotelSearchItem(value: HotelValue): HotelSearchItem | null {
  const hotel = recordOf(value);
  if (hotel === null ||
    typeof hotel['hotelId'] !== 'number' ||
    typeof hotel['name'] !== 'string' ||
    typeof hotel['nameEn'] !== 'string' ||
    typeof hotel['address'] !== 'string' ||
    (hotel['latitude'] !== null && typeof hotel['latitude'] !== 'number') ||
    (hotel['longitude'] !== null && typeof hotel['longitude'] !== 'number')) {
    return null;
  }
  return value as HotelSearchItem;
}

export function parseHotelSearchProjection(
  data: DataResult
): HotelSearchProjection | null {
  const result = recordOf(data.data);
  if (result === null || result['ok'] !== true ||
    !validSearchQuery(result['query']) || !Array.isArray(result['hotels'])) {
    return null;
  }
  return {
    result: data.data as HotelSearchResult
  };
}

export function parseHotelDetailProjection(
  data: DataResult
): HotelDetailProjection | null {
  const result = recordOf(data.data);
  if (result === null || result['ok'] !== true ||
    typeof result['hotelId'] !== 'number' ||
    typeof result['bookingUrl'] !== 'string' ||
    !Array.isArray(result['rates']) ||
    (result['rates'] as Object[]).length === 0) {
    return null;
  }
  return {
    result: data.data as HotelDetailResult
  };
}
