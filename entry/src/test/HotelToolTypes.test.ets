import { describe, it, expect } from '@ohos/hypium';
import {
  hotelDetailProviderArgs,
  hotelSearchProviderArgs,
  normalizeHotelDetailResult,
  normalizeHotelSearchResult,
  parseHotelDetailRequest,
  parseHotelSearchRequest
} from '@loop/agent-core';
import { McpToolResultPayload } from '@loop/agent-core';

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

function structured(json: string): Object {
  return JSON.parse(json) as Object;
}

export default function hotelToolTypesTest() {
  describe('hotelToolTypes', () => {
    it('rejects missing search fields instead of triggering provider defaults', 0, () => {
      const parsed = parseHotelSearchRequest(new Object());

      expect(parsed.ok).assertFalse();
      expect(parsed.value === null).assertTrue();
      expect(parsed.error.indexOf('place')).assertLarger(-1);
    });

    it('rejects invalid absolute dates and non-positive occupancy', 0, () => {
      const invalid = searchArgs();
      invalid.checkInDate = '08/15/2026';
      invalid.stayNights = 0;
      invalid.adultCount = 0;
      invalid.roomCount = 0;

      const parsed = parseHotelSearchRequest(invalid);

      expect(parsed.ok).assertFalse();
      expect(parsed.error.indexOf('YYYY-MM-DD')).assertLarger(-1);
    });

    it('rejects malformed child age arrays at the request boundary', 0, () => {
      const parsed = parseHotelSearchRequest(structured(
        '{"originQuery":"深圳亲子酒店","place":"深圳","placeType":"CITY","countryCode":"CN",' +
        '"checkInDate":"2026-08-15","stayNights":2,"adultCount":2,"childCount":1,' +
        '"childAgeDetails":["8"],"roomCount":1,"currency":"CNY","size":10}'
      ));

      expect(parsed.ok).assertFalse();
      expect(parsed.value === null).assertTrue();
      expect(parsed.error.indexOf('childAgeDetails')).assertLarger(-1);
    });

    it('maps search input one-to-one to searchHotels', 0, () => {
      const parsed = parseHotelSearchRequest(searchArgs());
      expect(parsed.ok).assertTrue();
      if (parsed.value === null) {
        return;
      }

      const provider = JSON.stringify(hotelSearchProviderArgs(parsed.value));
      expect(provider.indexOf('"originQuery":"深圳 8 月 15 日住两晚，2 位成人"')).assertLarger(-1);
      expect(provider.indexOf('"place":"深圳"')).assertLarger(-1);
      expect(provider.indexOf('"placeType":"CITY"')).assertLarger(-1);
      expect(provider.indexOf('"checkInDate":"2026-08-15"')).assertLarger(-1);
      expect(provider.indexOf('"stayNights":2')).assertLarger(-1);
      expect(provider.indexOf('"adultCount":2')).assertLarger(-1);
    });

    it('treats provider inner success false as an error', 0, () => {
      const parsed = parseHotelSearchRequest(searchArgs());
      if (parsed.value === null) {
        return;
      }
      const payload: McpToolResultPayload = {
        isError: false,
        structuredContent: structured('{"success":false,"message":"酒店搜索失败，请稍后重试","hotelInformationList":[]}')
      };

      const result = normalizeHotelSearchResult(payload, parsed.value);

      expect(result.ok).assertFalse();
      expect(result.error).assertEqual('酒店搜索失败，请稍后重试');
      expect(result.hotels.length).assertEqual(0);
    });

    it('preserves provider hotel IDs, dates, occupancy, and quoted currency', 0, () => {
      const parsed = parseHotelSearchRequest(searchArgs());
      if (parsed.value === null) {
        return;
      }
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

      const result = normalizeHotelSearchResult(payload, parsed.value);
      const serialized = JSON.stringify(result);

      expect(result.ok).assertTrue();
      expect(result.hotels[0].hotelId).assertEqual(47675);
      expect(result.hotels[0].destinationId).assertEqual('6046792');
      expect(result.hotels[0].price.lowestPrice).assertEqual(1100);
      expect(result.hotels[0].price.currency).assertEqual('CNY');
      expect(result.query.checkInDate).assertEqual('2026-08-15');
      expect(result.query.checkOutDate).assertEqual('2026-08-17');
      expect(result.query.adultCount).assertEqual(2);
      expect(result.query.roomCount).assertEqual(1);
      expect(serialized.indexOf('orderId')).assertEqual(-1);
      expect(serialized.indexOf('taxes')).assertEqual(-1);
    });

    it('returns a controlled error for malformed provider result arrays', 0, () => {
      const searchRequest = parseHotelSearchRequest(searchArgs());
      if (searchRequest.value === null) {
        return;
      }
      const searchPayload: McpToolResultPayload = {
        isError: false,
        structuredContent: structured(
          '{"success":true,"message":"酒店搜索成功","hotelInformationList":{"hotelId":47675}}'
        )
      };

      const searchResult = normalizeHotelSearchResult(searchPayload, searchRequest.value);

      expect(searchResult.ok).assertFalse();
      expect(searchResult.error.indexOf('hotelInformationList')).assertLarger(-1);

      const detailRequest = parseHotelDetailRequest(detailArgs());
      if (detailRequest.value === null) {
        return;
      }
      const detailPayload: McpToolResultPayload = {
        isError: false,
        structuredContent: structured(
          '{"success":true,"hotelId":47675,"roomRatePlans":[null]}'
        )
      };

      const detailResult = normalizeHotelDetailResult(detailPayload, detailRequest.value);

      expect(detailResult.ok).assertFalse();
      expect(detailResult.error.indexOf('roomRatePlans')).assertLarger(-1);
    });

    it('maps hotel detail input and preserves exact live rate fields', 0, () => {
      const parsed = parseHotelDetailRequest(detailArgs());
      expect(parsed.ok).assertTrue();
      if (parsed.value === null) {
        return;
      }
      const provider = JSON.stringify(hotelDetailProviderArgs(parsed.value));
      expect(provider.indexOf('"hotelId":47675')).assertLarger(-1);
      expect(provider.indexOf('"checkOutDate":"2026-08-17"')).assertLarger(-1);
      expect(provider.indexOf('"roomCount":1')).assertLarger(-1);

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

      const result = normalizeHotelDetailResult(payload, parsed.value);
      const serialized = JSON.stringify(result);

      expect(result.ok).assertTrue();
      expect(result.hotelId).assertEqual(47675);
      expect(result.rates[0].ratePlanId).assertEqual('5nAv6vObodN-6idXNkFPe3z');
      expect(result.rates[0].averagePrice).assertEqual(550);
      expect(result.rates[0].currency).assertEqual('CNY');
      expect(result.rates[0].cancelPolicy.indexOf('免费取消')).assertLarger(-1);
      expect(serialized.indexOf('orderId')).assertEqual(-1);
      expect(serialized.indexOf('quoteExpiry')).assertEqual(-1);
    });

    it('preserves unknown malformed rate facts instead of inventing zero or availability', 0, () => {
      const parsed = parseHotelDetailRequest(detailArgs());
      if (parsed.value === null) {
        return;
      }
      const payload: McpToolResultPayload = {
        isError: false,
        structuredContent: structured(
          '{"success":true,"hotelId":47675,"roomRatePlans":[{"ratePlanId":"provider-rate-unknown",' +
          '"averagePrice":"550","currency":123,"isOnRequest":"false"}]}'
        )
      };

      const result = normalizeHotelDetailResult(payload, parsed.value);

      expect(result.ok).assertTrue();
      expect(result.rates[0].averagePrice === null).assertTrue();
      expect(result.rates[0].currency).assertEqual('');
      expect(result.rates[0].isOnRequest === null).assertTrue();
    });
  });
}
