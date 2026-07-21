import { describe, it, expect } from '@ohos/hypium';
import {
  buildSystemFoodNavigationUri,
  HotelBookingOpenArgs,
  HotelNavigateArgs,
  hotelNavigationUri,
  isAllowedHotelBookingNavigationUrl,
  isRollingGoHotelBookingUrl,
  validHotelBookingOpenArgs
} from '@loop/agent-core';

const BOOKING_URL: string = 'https://rollinggo.cn/pages/hotel/detail/index?' +
  'id=47675&checkInDate=2026-08-15&checkOutDate=2026-08-17&' +
  'roomCount=1&adultCount=2&childCount=0&utm_source=appless';

function navigateArgs(): HotelNavigateArgs {
  return {
    hotelId: 47675,
    name: '深圳测试酒店',
    address: '深圳市南山区科技南路 88 号',
    latitude: 22.5431,
    longitude: 114.0579
  };
}

function bookingArgs(): HotelBookingOpenArgs {
  return { hotelId: 47675, bookingUrl: BOOKING_URL };
}

export default function hotelSystemIntentTest() {
  describe('hotelSystemIntent', () => {
    it('builds navigation with the existing exact longitude latitude and name path', 0, () => {
      expect(hotelNavigationUri(navigateArgs())).assertEqual(
        buildSystemFoodNavigationUri('114.0579,22.5431', '', '深圳测试酒店')
      );
    });

    it('returns no navigation URI for invalid coordinates', 0, () => {
      const invalid = navigateArgs();
      invalid.longitude = 181;
      expect(hotelNavigationUri(invalid)).assertEqual('');
    });

    it('accepts only a matching valid RollingGo detail URL', 0, () => {
      expect(isRollingGoHotelBookingUrl(BOOKING_URL)).assertTrue();
      expect(validHotelBookingOpenArgs(bookingArgs()).ok).assertTrue();
      expect(validHotelBookingOpenArgs({ hotelId: 999, bookingUrl: BOOKING_URL }).ok).assertFalse();
      expect(validHotelBookingOpenArgs({
        hotelId: 47675,
        bookingUrl: BOOKING_URL.replace('https://rollinggo.cn/', 'http://rollinggo.cn/')
      }).ok).assertFalse();
      expect(validHotelBookingOpenArgs({
        hotelId: 47675,
        bookingUrl: BOOKING_URL.replace('rollinggo.cn', 'evil.example')
      }).ok).assertFalse();
      expect(validHotelBookingOpenArgs({
        hotelId: 47675,
        bookingUrl: BOOKING_URL.replace('/pages/hotel/detail/index', '/pc/')
      }).ok).assertFalse();
      expect(validHotelBookingOpenArgs({
        hotelId: 47675,
        bookingUrl: BOOKING_URL.replace('checkOutDate=2026-08-17', 'checkOutDate=bad')
      }).ok).assertFalse();
    });

    it('allows only RollingGo HTTPS navigation URLs', 0, () => {
      expect(isAllowedHotelBookingNavigationUrl('https://rollinggo.cn/pc/#/hotel/single')).assertTrue();
      expect(isAllowedHotelBookingNavigationUrl('https://pay.example/checkout')).assertFalse();
      expect(isAllowedHotelBookingNavigationUrl('https://user:pass@rollinggo.cn/pc/')).assertFalse();
    });
  });
}
