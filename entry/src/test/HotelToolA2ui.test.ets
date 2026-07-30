import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiAction,
  HotelSearchResult,
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

function hotelSearchResultFixture(): HotelSearchResult {
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
    throw new Error('hotel search fixture is invalid');
  }
  const payload: McpToolResultPayload = {
    isError: false,
    structuredContent: structured(
      '{"success":true,"message":"酒店搜索成功","hotelInformationList":[{"hotelId":47675,' +
      '"bookingUrl":"https://rollinggo.cn/pages/hotel/detail/index?id=47675&checkInDate=2026-08-15&checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0","name":"深圳测试酒店","nameEn":"Shenzhen Test Hotel",' +
      '"brand":null,"address":"深圳市南山区","destinationId":"6046792","latitude":22.5,"longitude":114.0,' +
      '"distanceInMeters":null,"starRating":5,"price":{"message":"2 晚参考价","hasPrice":true,' +
      '"currency":"USD","lowestPrice":1100},"areaCode":"NANSHAN","description":"provider description",' +
      '"imageUrl":"https://img.example/hotel.jpg","hotelAmenities":["Wi-Fi"],"tags":["商务"]}]}'
    )
  };
  const result = normalizeHotelSearchResult(payload, request.value);
  return result;
}

function allowAll(_action: A2uiAction): boolean {
  return true;
}

export default function hotelToolA2uiTest() {
  describe('hotelToolA2ui', () => {
    it('creates a hotel search surface with exact truthful action args', 0, () => {
      const jsonl = hotelSearchA2ui('hotel_search', hotelSearchResultFixture(), allowAll);

      expect(jsonl.indexOf('"intent":"hotel"')).assertLarger(-1);
      expect(jsonl.indexOf('"toolName":"hotel.search"')).assertLarger(-1);
      expect(jsonl.indexOf('"id":"hotel.detail"')).assertLarger(-1);
      expect(jsonl.indexOf('"id":"hotel.navigate"')).assertLarger(-1);
      expect(jsonl.indexOf('"args":{"hotelId":47675,"checkInDate":"2026-08-15",' +
        '"checkOutDate":"2026-08-17","countryCode":"CN","currency":"CNY","adultCount":2,' +
        '"childCount":0,"childAgeDetails":[],"roomCount":1}')).assertLarger(-1);
      expect(jsonl.indexOf('"args":{"hotelId":47675,"name":"深圳测试酒店",' +
        '"address":"深圳市南山区","latitude":22.5,"longitude":114}')).assertLarger(-1);
      expect(jsonl.indexOf('搜索阶段仅传成人数')).assertLarger(-1);
      expect(jsonl.indexOf('Appless 支持打开 App 内 RollingGo Web 预订')).assertLarger(-1);
      expect(jsonl.indexOf('hotel.book')).assertEqual(-1);
      expect(jsonl.indexOf('预订成功')).assertEqual(-1);
      expect(jsonl.indexOf('orderId')).assertEqual(-1);
    });

    it('omits actions whose real fields are absent or invalid', 0, () => {
      const missingCoordinates = hotelSearchResultFixture();
      missingCoordinates.hotels[0].latitude = null;
      missingCoordinates.hotels[0].longitude = null;
      const noNavigate = hotelSearchA2ui('hotel_no_nav', missingCoordinates, allowAll);
      expect(noNavigate.indexOf('"id":"hotel.detail"')).assertLarger(-1);
      expect(noNavigate.indexOf('"id":"hotel.navigate"')).assertEqual(-1);

      const invalidCoordinates = hotelSearchResultFixture();
      invalidCoordinates.hotels[0].latitude = 91;
      const noInvalidNavigate = hotelSearchA2ui('hotel_invalid_nav', invalidCoordinates, allowAll);
      expect(noInvalidNavigate.indexOf('"id":"hotel.navigate"')).assertEqual(-1);

      const zeroCoordinates = hotelSearchResultFixture();
      zeroCoordinates.hotels[0].latitude = 0;
      zeroCoordinates.hotels[0].longitude = 0;
      const zeroNavigate = hotelSearchA2ui('hotel_zero_nav', zeroCoordinates, allowAll);
      expect(zeroNavigate.indexOf('"id":"hotel.navigate"')).assertLarger(-1);

      const invalidId = hotelSearchResultFixture();
      invalidId.hotels[0].hotelId = 0;
      const noActions = hotelSearchA2ui('hotel_no_actions', invalidId, allowAll);
      expect(noActions.indexOf('"id":"hotel.detail"')).assertEqual(-1);
      expect(noActions.indexOf('"id":"hotel.navigate"')).assertEqual(-1);
      expect(noActions.indexOf('"label":"酒店 ID"')).assertEqual(-1);
    });

    it('omits a valid candidate when placement authority denies it', 0, () => {
      const jsonl = hotelSearchA2ui(
        'hotel_catalog_denial',
        hotelSearchResultFixture(),
        (action: A2uiAction): boolean => action.id !== 'hotel.navigate'
      );

      expect(jsonl.indexOf('"id":"hotel.detail"')).assertLarger(-1);
      expect(jsonl.indexOf('"id":"hotel.navigate"')).assertEqual(-1);
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
          '{"success":true,"hotelId":47675,"bookingUrl":"https://rollinggo.cn/pages/hotel/detail/index?id=47675&checkInDate=2026-08-15&checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0","name":"深圳测试酒店",' +
          '"nameEn":"Shenzhen Test Hotel","checkIn":"2026-08-15","checkOut":"2026-08-17","message":"搜索成功",' +
          '"roomRatePlans":[{"roomName":"豪华大床房","roomNameCn":"豪华大床房",' +
          '"ratePlanId":"5nAv6vObodN-6idXNkFPe3z","ratePlanName":"不含早餐","averagePrice":550,' +
          '"bedTypeDescription":"1 大床","currency":"CNY","mealAmount":0,"mealTypeStr":"不含早餐",' +
          '"isOnRequest":false,"cancelPolicy":"免费取消截止至酒店当地时间 2026-08-12 08:00:00"}]}'
        )
      };
      const jsonl = hotelDetailA2ui('hotel_detail', normalizeHotelDetailResult(payload, request.value), allowAll);

      expect(jsonl.indexOf('"intent":"hotel"')).assertLarger(-1);
      expect(jsonl.indexOf('"toolName":"hotel.detail"')).assertLarger(-1);
      expect(jsonl.indexOf('"id":"hotel.search.restore"')).assertLarger(-1);
      expect(jsonl.indexOf('"label":"返回酒店结果"')).assertLarger(-1);
      expect(jsonl.split('"id":"hotel.booking.open"').length - 1).assertEqual(1);
      expect(jsonl.indexOf('"label":"在 App 内继续预订"')).assertLarger(-1);
      expect(jsonl.indexOf('第三方预订（离开 Appless）')).assertEqual(-1);
      expect(jsonl.indexOf('5nAv6vObodN-6idXNkFPe3z')).assertLarger(-1);
      expect(jsonl.indexOf('550 CNY')).assertLarger(-1);
      expect(jsonl.indexOf('免费取消截止至酒店当地时间')).assertLarger(-1);
      expect(jsonl.indexOf('税费拆分与报价有效期：供应商未返回')).assertLarger(-1);
      expect(jsonl.indexOf('下单成功')).assertEqual(-1);
      expect(jsonl.indexOf('订单编号')).assertEqual(-1);
    });

    it('renders unknown provider price and availability as unknown', 0, () => {
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
          '{"success":true,"hotelId":47675,"bookingUrl":"https://rollinggo.cn/pages/hotel/detail/index?id=47675&checkInDate=2026-08-15&checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0","name":"深圳测试酒店","roomRatePlans":[' +
          '{"ratePlanId":"provider-rate-unknown","averagePrice":"550","currency":123,"isOnRequest":"false"}]}'
        )
      };
      const jsonl = hotelDetailA2ui('hotel_detail', normalizeHotelDetailResult(payload, request.value));

      expect(jsonl.indexOf('"label":"平均价","value":"供应商未返回"')).assertLarger(-1);
      expect(jsonl.indexOf('"label":"供应商确认","value":"供应商未返回"')).assertLarger(-1);
      expect(jsonl.indexOf('当前可订')).assertEqual(-1);
      expect(jsonl.indexOf('0 123')).assertEqual(-1);
    });
  });
}
