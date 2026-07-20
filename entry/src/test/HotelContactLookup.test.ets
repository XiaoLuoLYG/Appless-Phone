import { describe, it, expect } from '@ohos/hypium';
import {
  HotelContactCandidate,
  HotelContactDetails,
  HotelSearchItem,
  callHotelContactLookup,
  hotelContactCandidatesFromPayload,
  hotelContactDetailsFromPayload,
  hotelContactFromDetails,
  selectHotelContactCandidate
} from '@loop/agent-core';
import { unsafeHotelPhoneValues } from './HotelPhoneSafetyVectors';

function hotel(): HotelSearchItem {
  return JSON.parse(
    '{"hotelId":47675,"bookingUrl":"https://hotel.example/47675","name":"深圳 测试·酒店",' +
    '"nameEn":"Shenzhen Test Hotel","brand":"Test","address":"广东省深圳市南山区科技南路 88 号",' +
    '"destinationId":"6046792","latitude":22.5,"longitude":114.0,"distanceInMeters":880,' +
    '"starRating":5,"price":{"message":"2 晚参考价","hasPrice":true,"currency":"CNY","lowestPrice":1100},' +
    '"areaCode":"NANSHAN","description":"provider description","imageUrl":"","hotelAmenities":[],"tags":[]}'
  ) as HotelSearchItem;
}

function candidates(rawJson: string): HotelContactCandidate[] {
  return hotelContactCandidatesFromPayload(rawJson);
}

export default function hotelContactLookupTest() {
  describe('hotelContactLookup', () => {
    it('accepts one exact normalized Chinese name with a nontrivial contained address', 0, () => {
      const match = selectHotelContactCandidate(hotel(), candidates(
        '{"places":[{"id":"place-cn","displayName":{"text":"深圳测试酒店"},' +
        '"formattedAddress":"深圳市南山区科技南路88号"}]}'
      ));

      expect(match.candidate?.providerPlaceId).assertEqual('place-cn');
      expect(match.warning).assertEqual('');
    });

    it('accepts one exact normalized English name within 300 meters', 0, () => {
      const match = selectHotelContactCandidate(hotel(), candidates(
        '{"places":[{"id":"place-en","displayName":{"text":"SHENZHEN TEST-HOTEL"},' +
        '"formattedAddress":"unrelated","location":{"latitude":22.501,"longitude":114.0}}]}'
      ));

      expect(match.candidate?.providerPlaceId).assertEqual('place-en');
      expect(match.warning).assertEqual('');
    });

    it('rejects a name-only candidate', 0, () => {
      const match = selectHotelContactCandidate(hotel(), candidates(
        '{"places":[{"id":"place-name-only","displayName":{"text":"深圳测试酒店"}}]}'
      ));

      expect(match.candidate === null).assertTrue();
      expect(match.warning.length).assertLarger(0);
    });

    it('rejects ambiguous qualifying candidates', 0, () => {
      const match = selectHotelContactCandidate(hotel(), candidates(
        '{"places":[' +
        '{"id":"place-a","displayName":{"text":"深圳测试酒店"},"formattedAddress":"深圳市南山区科技南路88号"},' +
        '{"id":"place-b","displayName":{"text":"Shenzhen Test Hotel"},' +
        '"location":{"latitude":22.501,"longitude":114.0}}]}'
      ));

      expect(match.candidate === null).assertTrue();
      expect(match.warning.indexOf('multiple')).assertLarger(-1);
    });

    it('rejects exact names with a wrong address and distant coordinates', 0, () => {
      const match = selectHotelContactCandidate(hotel(), candidates(
        '{"places":[{"id":"place-distant","displayName":{"text":"深圳测试酒店"},' +
        '"formattedAddress":"北京市朝阳区测试路100号",' +
        '"location":{"latitude":39.9042,"longitude":116.4074}}]}'
      ));

      expect(match.candidate === null).assertTrue();
    });

    it('rejects a candidate without a real Place ID', 0, () => {
      const match = selectHotelContactCandidate(hotel(), candidates(
        '{"places":[{"displayName":{"text":"深圳测试酒店"},' +
        '"formattedAddress":"深圳市南山区科技南路88号"}]}'
      ));

      expect(match.candidate === null).assertTrue();
    });

    it('prefers a valid international phone and keeps truthful display text', 0, () => {
      const details = hotelContactDetailsFromPayload(
        '{"id":"place-phone","displayName":{"text":"深圳测试酒店"},' +
        '"formattedAddress":"深圳市南山区科技南路88号",' +
        '"internationalPhoneNumber":" +86 755-1234 5678 ","nationalPhoneNumber":"0755 1234 5678"}'
      );
      const contact = hotelContactFromDetails(details, 'place-phone');

      expect(contact?.displayPhone).assertEqual('+86 755-1234 5678');
      expect(contact?.dialPhone).assertEqual('+8675512345678');
      expect(contact?.provider).assertEqual('Google Places');
      expect(contact?.providerPlaceId).assertEqual('place-phone');
    });

    it('retains a valid national phone without inventing a country code', 0, () => {
      const details = hotelContactDetailsFromPayload(
        '{"id":"place-national","nationalPhoneNumber":"(0755) 1234-5678"}'
      );
      const contact = hotelContactFromDetails(details, 'place-national');

      expect(contact?.displayPhone).assertEqual('(0755) 1234-5678');
      expect(contact?.dialPhone).assertEqual('075512345678');
    });

    it('returns no contact when Place Details has no valid phone', 0, () => {
      const missing = hotelContactFromDetails(
        hotelContactDetailsFromPayload('{"id":"place-missing"}'),
        'place-missing'
      );
      const invalid = hotelContactFromDetails(
        hotelContactDetailsFromPayload('{"id":"place-invalid","internationalPhoneNumber":"+86 ext 123"}'),
        'place-invalid'
      );

      expect(missing === null).assertTrue();
      expect(invalid === null).assertTrue();
    });

    it('rejects every shared unsafe phone character without normalizing it away', 0, () => {
      const rejected = unsafeHotelPhoneValues();
      for (let index = 0; index < rejected.length; index++) {
        const details: HotelContactDetails = {
          providerPlaceId: 'place-unsafe',
          displayName: '深圳测试酒店',
          formattedAddress: '深圳市南山区科技南路88号',
          latitude: null,
          longitude: null,
          nationalPhoneNumber: '',
          internationalPhoneNumber: rejected[index]
        };

        expect(hotelContactFromDetails(details, 'place-unsafe') === null).assertTrue();
      }
    });

    it('skips missing Google configuration with a bounded warning and no source claim', 0, async () => {
      const result = await callHotelContactLookup(hotel(), '');

      expect(result.contact === null).assertTrue();
      expect(result.warning.length).assertLarger(0);
      expect(result.warning.length <= 240).assertTrue();
      expect(result.sourceReceived).assertFalse();
    });
  });
}
