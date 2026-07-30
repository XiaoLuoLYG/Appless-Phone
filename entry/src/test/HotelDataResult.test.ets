import { describe, it, expect } from '@ohos/hypium';
import {
  DataResult,
  DataSource,
  HotelDetailResult,
  HotelSearchResult,
  McpToolResultPayload,
  hotelDetailDataResult,
  hotelSearchDataResult,
  normalizeHotelDetailResult,
  normalizeHotelSearchResult,
  parseHotelDetailRequest,
  parseHotelSearchRequest
} from '@loop/agent-core';

interface HotelSearchArgsFixture {
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

interface HotelDetailArgsFixture {
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

function searchArgs(): HotelSearchArgsFixture {
  return {
    originQuery: '深圳 8 月 15 日住两晚，2 位成人',
    place: '深圳',
    placeType: 'CITY',
    countryCode: 'CN',
    checkInDate: '2026-08-15',
    stayNights: 2,
    adultCount: 2,
    childCount: 0,
    childAgeDetails: [],
    roomCount: 1,
    currency: 'CNY',
    size: 10
  };
}

function detailArgs(): HotelDetailArgsFixture {
  return {
    hotelId: 47675,
    checkInDate: '2026-08-15',
    checkOutDate: '2026-08-17',
    countryCode: 'CN',
    currency: 'CNY',
    adultCount: 2,
    childCount: 0,
    childAgeDetails: [],
    roomCount: 1
  };
}

function source(operation: string): DataSource {
  return {
    provider: 'RollingGo',
    backend: 'local_adapter',
    operation: operation,
    fetchedAt: '2026-07-20T02:00:00.000Z'
  };
}

function structured(json: string): Object {
  return JSON.parse(json) as Object;
}

function searchResult(payload: McpToolResultPayload): HotelSearchResult {
  const parsed = parseHotelSearchRequest(searchArgs());
  if (parsed.value === null) {
    throw new Error(parsed.error);
  }
  return normalizeHotelSearchResult(payload, parsed.value);
}

function detailResult(payload: McpToolResultPayload): HotelDetailResult {
  const parsed = parseHotelDetailRequest(detailArgs());
  if (parsed.value === null) {
    throw new Error(parsed.error);
  }
  return normalizeHotelDetailResult(payload, parsed.value);
}

export default function hotelDataResultTest() {
  describe('hotelDataResult', () => {
    it('preserves the unflattened RollingGo search result and source', 0, () => {
      const payload: McpToolResultPayload = {
        isError: false,
        structuredContent: structured(
          '{"success":true,"message":"酒店搜索成功","hotelInformationList":[{"hotelId":47675,' +
          '"bookingUrl":"https://hotel.example/47675","name":"深圳测试酒店","nameEn":"Shenzhen Test Hotel",' +
          '"brand":"Test","address":"深圳市南山区","destinationId":"6046792","latitude":22.5,"longitude":114.0,' +
          '"distanceInMeters":880,"starRating":5,"price":{"message":"2 晚参考价","hasPrice":true,' +
          '"currency":"CNY","lowestPrice":1100},"areaCode":"NANSHAN","description":"provider description",' +
          '"imageUrl":"https://img.example/hotel.jpg","hotelAmenities":["Wi-Fi"],"tags":["商务"]}]}'
        )
      };
      const result: DataResult = hotelSearchDataResult(searchResult(payload), [source('searchHotels')]);
      const data = result.data as HotelSearchResult;

      expect(result.toolId).assertEqual('hotel.search');
      expect(result.outputSchema).assertEqual('hotelSearchResults');
      expect(result.status).assertEqual('success');
      expect(result.sources[0].provider).assertEqual('RollingGo');
      expect(result.sources[0].operation).assertEqual('searchHotels');
      expect(data.hotels[0].hotelId).assertEqual(47675);
      expect(data.hotels[0].destinationId).assertEqual('6046792');
      expect(data.hotels[0].price.lowestPrice).assertEqual(1100);
      expect(JSON.stringify(result).indexOf('sourceTag')).assertEqual(-1);
    });

    it('maps a successful zero-hotel response to empty', 0, () => {
      const payload: McpToolResultPayload = {
        isError: false,
        structuredContent: structured('{"success":true,"message":"酒店搜索成功","hotelInformationList":[]}')
      };

      const result = hotelSearchDataResult(searchResult(payload), [source('searchHotels')]);

      expect(result.status).assertEqual('empty');
      expect((result.data as HotelSearchResult).hotels.length).assertEqual(0);
      expect(result.error === undefined).assertTrue();
    });

    it('preserves the real provider hotelId and ratePlanId in detail data', 0, () => {
      const payload: McpToolResultPayload = {
        isError: false,
        structuredContent: structured(
          '{"success":true,"hotelId":47675,"bookingUrl":"https://hotel.example/47675","name":"深圳测试酒店",' +
          '"nameEn":"Shenzhen Test Hotel","checkIn":"2026-08-15","checkOut":"2026-08-17","message":"搜索成功",' +
          '"roomRatePlans":[{"roomName":"豪华大床房","roomNameCn":"豪华大床房",' +
          '"ratePlanId":"5nAv6vObodN-6idXNkFPe3z","ratePlanName":"不含早餐","averagePrice":550,' +
          '"bedTypeDescription":"1 大床","currency":"CNY","mealAmount":0,"mealTypeStr":"不含早餐",' +
          '"isOnRequest":false,"cancelPolicy":"免费取消截止至酒店当地时间 2026-08-12 08:00:00"}]}'
        )
      };
      const result = hotelDetailDataResult(detailResult(payload), [source('getHotelDetail')], ['quote expiry unavailable']);
      const data = result.data as HotelDetailResult;

      expect(result.toolId).assertEqual('hotel.detail');
      expect(result.outputSchema).assertEqual('hotelRatePlans');
      expect(result.status).assertEqual('partial');
      expect(result.warnings[0]).assertEqual('quote expiry unavailable');
      expect(data.hotelId).assertEqual(47675);
      expect(data.rates[0].ratePlanId).assertEqual('5nAv6vObodN-6idXNkFPe3z');
      expect(data.rates[0].averagePrice).assertEqual(550);
    });

    it('maps inner provider failure to a structured error', 0, () => {
      const payload: McpToolResultPayload = {
        isError: false,
        structuredContent: structured('{"success":false,"message":"酒店搜索失败，请稍后重试","hotelInformationList":[]}')
      };

      const result = hotelSearchDataResult(searchResult(payload), [source('searchHotels')]);

      expect(result.status).assertEqual('error');
      expect(result.error === undefined).assertFalse();
      expect(result.error?.code).assertEqual('HOTEL_PROVIDER_ERROR');
      expect(result.error?.message).assertEqual('酒店搜索失败，请稍后重试');
    });
  });
}
