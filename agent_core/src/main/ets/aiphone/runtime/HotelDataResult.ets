import { DataResult, DataSource } from '../../agent/message/DataResult';
import { HotelDetailResult, HotelSearchResult } from './HotelToolTypes';

export function hotelSearchDataResult(
  result: HotelSearchResult,
  sources: DataSource[],
  warnings: string[] = []
): DataResult {
  return {
    toolId: 'hotel.search',
    outputSchema: 'hotelSearchResults',
    status: result.ok ? (result.hotels.length > 0 ? (warnings.length > 0 ? 'partial' : 'success') : 'empty') : 'error',
    sources: sources.slice(),
    data: result,
    warnings: warnings.slice(),
    error: result.ok ? undefined : {
      code: 'HOTEL_PROVIDER_ERROR',
      message: result.error,
      retryable: true
    }
  };
}

export function hotelDetailDataResult(
  result: HotelDetailResult,
  sources: DataSource[],
  warnings: string[] = []
): DataResult {
  return {
    toolId: 'hotel.detail',
    outputSchema: 'hotelRatePlans',
    status: result.ok ? (result.rates.length > 0 ? (warnings.length > 0 ? 'partial' : 'success') : 'empty') : 'error',
    sources: sources.slice(),
    data: result,
    warnings: warnings.slice(),
    error: result.ok ? undefined : {
      code: 'HOTEL_PROVIDER_ERROR',
      message: result.error,
      retryable: true
    }
  };
}
