import { describe, it, expect } from '@ohos/hypium';
import {
  buildSystemFoodNavigationUri,
  HotelCallArgs,
  HotelNavigateArgs,
  hotelDialUri,
  hotelNavigationUri,
  validHotelCallArgs
} from '@loop/agent-core';
import { unsafeHotelPhoneValues } from './HotelPhoneSafetyVectors';

function navigateArgs(): HotelNavigateArgs {
  return {
    hotelId: 47675,
    name: '深圳测试酒店',
    address: '深圳市南山区科技南路 88 号',
    latitude: 22.5431,
    longitude: 114.0579
  };
}

function callArgs(dialPhone: string): HotelCallArgs {
  return {
    hotelId: 47675,
    name: '深圳测试酒店',
    displayPhone: '+86 138 0013 8000',
    dialPhone: dialPhone,
    provider: 'Google Places',
    providerPlaceId: 'place-real-47675'
  };
}

export default function hotelSystemIntentTest() {
  describe('hotelSystemIntent', () => {
    it('builds navigation with the existing exact longitude latitude and name path', 0, () => {
      const args = navigateArgs();

      expect(hotelNavigationUri(args)).assertEqual(
        buildSystemFoodNavigationUri('114.0579,22.5431', '', '深圳测试酒店')
      );
    });

    it('returns no navigation URI for missing null or invalid coordinates', 0, () => {
      const missing = JSON.parse(
        '{"hotelId":47675,"name":"Missing","address":"address"}'
      ) as HotelNavigateArgs;
      const nulled = JSON.parse(
        '{"hotelId":47675,"name":"Null","address":"address","latitude":null,"longitude":114.0579}'
      ) as HotelNavigateArgs;
      const invalid = navigateArgs();
      invalid.longitude = 181;

      expect(hotelNavigationUri(missing)).assertEqual('');
      expect(hotelNavigationUri(nulled)).assertEqual('');
      expect(hotelNavigationUri(invalid)).assertEqual('');
    });

    it('normalizes only safe dial separators and an optional single leading plus', 0, () => {
      expect(hotelDialUri(' +86 (138)-0013 8000 ')).assertEqual('tel:+8613800138000');
      expect(hotelDialUri('(0755) 1234-5678')).assertEqual('tel:075512345678');
      expect(hotelDialUri('12345')).assertEqual('tel:12345');
    });

    it('rejects unsafe dial lengths characters text and control input', 0, () => {
      const rejected: string[] = [
        '1234',
        '123456789012345678901',
        '*12345',
        '12345#',
        '12345,678',
        '12345;678',
        '12345 ext 6',
        '12345?query=6',
        '12345\n678',
        '++8613800138000',
        '+86+13800138000'
      ];
      const shared = unsafeHotelPhoneValues();
      for (let index = 0; index < shared.length; index++) {
        rejected.push(shared[index]);
      }

      for (let index = 0; index < rejected.length; index++) {
        expect(hotelDialUri(rejected[index])).assertEqual('');
        expect(validHotelCallArgs(callArgs(rejected[index])).ok).assertFalse();
      }
    });

    it('is deterministic and does not require a system ability', 0, () => {
      const args = navigateArgs();
      const first = hotelNavigationUri(args);

      expect(hotelNavigationUri(args)).assertEqual(first);
      expect(hotelDialUri('+8613800138000')).assertEqual('tel:+8613800138000');
    });
  });
}
