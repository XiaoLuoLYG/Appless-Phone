import { describe, it, expect } from '@ohos/hypium';
import {
  hotelDetailA2ui,
  hotelSearchA2ui,
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

function structured(json: string): Object {
  return JSON.parse(json) as Object;
}

export default function hotelToolA2uiTest() {
  describe('hotelToolA2ui', () => {
    it('creates a hotel search surface with exact detail action args', 0, () => {
      const args: HotelSearchArgsFixture = {
        originQuery: '深圳酒店',
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
      const request = parseHotelSearchRequest(args);
      if (request.value === null) {
        return;
      }
      const payload: McpToolResultPayload = {
        isError: false,
        structuredContent: structured(
          '{"success":true,"message":"酒店搜索成功","hotelInformationList":[{"hotelId":47675,' +
          '"bookingUrl":"https://hotel.example/47675","name":"深圳测试酒店","nameEn":"Shenzhen Test Hotel",' +
          '"brand":null,"address":"深圳市南山区","destinationId":"6046792","latitude":22.5,"longitude":114.0,' +
          '"distanceInMeters":null,"starRating":5,"price":{"message":"2 晚参考价","hasPrice":true,' +
          '"currency":"CNY","lowestPrice":1100},"areaCode":"NANSHAN","description":"provider description",' +
          '"imageUrl":"https://img.example/hotel.jpg","hotelAmenities":["Wi-Fi"],"tags":["商务"]}]}'
        )
      };
      const jsonl = hotelSearchA2ui('hotel_search', normalizeHotelSearchResult(payload, request.value));

      expect(jsonl.indexOf('"intent":"hotel"')).assertLarger(-1);
      expect(jsonl.indexOf('"toolName":"hotel.search"')).assertLarger(-1);
      expect(jsonl.indexOf('"id":"hotel.detail"')).assertLarger(-1);
      expect(jsonl.indexOf('"hotelId":47675')).assertLarger(-1);
      expect(jsonl.indexOf('"checkInDate":"2026-08-15"')).assertLarger(-1);
      expect(jsonl.indexOf('"checkOutDate":"2026-08-17"')).assertLarger(-1);
      expect(jsonl.indexOf('"adultCount":2')).assertLarger(-1);
      expect(jsonl.indexOf('"roomCount":1')).assertLarger(-1);
      expect(jsonl.indexOf('Appless 暂不支持创建或跟踪酒店订单')).assertLarger(-1);
      expect(jsonl.indexOf('orderId')).assertEqual(-1);
    });

    it('renders exact provider rate and cancellation fields without order success', 0, () => {
      const args: HotelDetailArgsFixture = {
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
      const request = parseHotelDetailRequest(args);
      if (request.value === null) {
        return;
      }
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
      const jsonl = hotelDetailA2ui('hotel_detail', normalizeHotelDetailResult(payload, request.value));

      expect(jsonl.indexOf('"intent":"hotel"')).assertLarger(-1);
      expect(jsonl.indexOf('"toolName":"hotel.detail"')).assertLarger(-1);
      expect(jsonl.indexOf('5nAv6vObodN-6idXNkFPe3z')).assertLarger(-1);
      expect(jsonl.indexOf('550 CNY')).assertLarger(-1);
      expect(jsonl.indexOf('免费取消截止至酒店当地时间')).assertLarger(-1);
      expect(jsonl.indexOf('税费拆分与报价有效期：供应商未返回')).assertLarger(-1);
      expect(jsonl.indexOf('下单成功')).assertEqual(-1);
      expect(jsonl.indexOf('订单编号')).assertEqual(-1);
    });
  });
}
