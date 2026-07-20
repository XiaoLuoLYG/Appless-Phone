import { describe, it, expect } from '@ohos/hypium';
import {
  HOTEL_CONTACT_DETAIL_FIELD_MASK,
  HOTEL_CONTACT_SEARCH_FIELD_MASK,
  googleMapsDirectionsUrl,
  hotelContactCandidatesFromPayload,
  hotelContactDetailsFromPayload,
  hotelContactFromDetails,
  mapsFoodRecordFromResult,
  mapsRouteResult,
  mapsTextSearchBody,
  mapsTextSearchResultsFromPayload
} from '@loop/agent-core';
import { unsafeHotelPhoneValues } from './HotelPhoneSafetyVectors';

interface HotelPhonePayload {
  id: string;
  nationalPhoneNumber: string;
  internationalPhoneNumber: string;
}

export default function mapsApiClientTest() {
  describe('mapsApiClient', () => {
    it('builds text search body for POI search', 0, () => {
      const body = mapsTextSearchBody('深圳坂田华为基地附近的咖啡店');
      expect(JSON.stringify(body)).assertEqual('{"textQuery":"深圳坂田华为基地附近的咖啡店","languageCode":"zh-CN","maxResultCount":10}');
    });

    it('maps Places payload into generic results', 0, () => {
      const payload = '{"places":[{"id":"place-123","displayName":{"text":"Coffee Lab"},"formattedAddress":"深圳市龙岗区坂田","rating":4.6,"googleMapsUri":"https://maps.google.com/?cid=123","location":{"latitude":22.609878,"longitude":114.029506}}]}';
      const results = mapsTextSearchResultsFromPayload(payload, '深圳咖啡');
      expect(results.length).assertEqual(1);
      expect(results[0].sourceTag).assertEqual('Google Places API');
      expect(results[0].toolName).assertEqual('maps.place.search');
      expect(results[0].title).assertEqual('Coffee Lab');
      expect(results[0].rows[0].value).assertEqual('place-123');
      expect(JSON.stringify(results[0].rows).indexOf('"label":"Map Location","value":"22.609878,114.029506"')).assertLarger(-1);
    });

    it('uses identity-only search fields and requests phone only after a unique match', 0, () => {
      expect(HOTEL_CONTACT_SEARCH_FIELD_MASK)
        .assertEqual('places.id,places.displayName,places.formattedAddress,places.location');
      expect(HOTEL_CONTACT_SEARCH_FIELD_MASK.indexOf('Phone')).assertEqual(-1);
      expect(HOTEL_CONTACT_DETAIL_FIELD_MASK)
        .assertEqual('id,displayName,formattedAddress,location,nationalPhoneNumber,internationalPhoneNumber');
    });

    it('normalizes provider-shaped contact payloads without fabricating coordinates or phones', 0, () => {
      const candidates = hotelContactCandidatesFromPayload(
        '{"places":[{"id":"place-123","displayName":{"text":"Hotel One"},"formattedAddress":"Address One"}]}'
      );
      const details = hotelContactDetailsFromPayload(
        '{"id":"place-123","displayName":{"text":"Hotel One"},"nationalPhoneNumber":"010-12345678"}'
      );

      expect(candidates[0].latitude === null).assertTrue();
      expect(candidates[0].longitude === null).assertTrue();
      expect(details.internationalPhoneNumber).assertEqual('');
      expect(details.nationalPhoneNumber).assertEqual('010-12345678');
      expect(hotelContactFromDetails(details, 'place-123')?.displayPhone)
        .assertEqual('010-12345678');
      expect(hotelContactFromDetails(details, 'place-123')?.dialPhone)
        .assertEqual('01012345678');
    });

    it('preserves unsafe provider phone characters through parsing for rejection', 0, () => {
      const rejected = unsafeHotelPhoneValues();
      for (let index = 0; index < rejected.length; index++) {
        const internationalPayload: HotelPhonePayload = {
          id: 'place-unsafe',
          nationalPhoneNumber: '',
          internationalPhoneNumber: rejected[index]
        };
        const nationalPayload: HotelPhonePayload = {
          id: 'place-unsafe',
          nationalPhoneNumber: rejected[index],
          internationalPhoneNumber: ''
        };
        const internationalDetails =
          hotelContactDetailsFromPayload(JSON.stringify(internationalPayload));
        const nationalDetails =
          hotelContactDetailsFromPayload(JSON.stringify(nationalPayload));

        expect(internationalDetails.internationalPhoneNumber).assertEqual(rejected[index]);
        expect(nationalDetails.nationalPhoneNumber).assertEqual(rejected[index]);
        expect(hotelContactFromDetails(internationalDetails, 'place-unsafe') === null).assertTrue();
        expect(hotelContactFromDetails(nationalDetails, 'place-unsafe') === null).assertTrue();
      }
    });

    it('maps Google Places results into food records with food coordinate order', 0, () => {
      const payload = '{"places":[{"id":"place-123","displayName":{"text":"Coffee Lab"},"formattedAddress":"深圳市龙岗区坂田","rating":4.6,"location":{"latitude":22.609878,"longitude":114.029506}}]}';
      const food = mapsFoodRecordFromResult(mapsTextSearchResultsFromPayload(payload, '深圳咖啡')[0]);
      const tags = food.sourceTags === undefined ? [] : food.sourceTags;

      expect(food.name).assertEqual('Coffee Lab');
      expect(food.location).assertEqual('114.029506,22.609878');
      expect(tags[0]).assertEqual('Google Maps');
    });

    it('builds an in-app Google Maps directions URL from structured route args', 0, () => {
      const url = googleMapsDirectionsUrl(JSON.parse('{"origin":"深圳北站","destination":"深圳湾口岸","travelMode":"driving","navigate":true}') as Object);
      expect(url.indexOf('https://www.google.com/maps/dir/?api=1')).assertEqual(0);
      expect(url.indexOf('origin=' + encodeURIComponent('深圳北站'))).assertLarger(-1);
      expect(url.indexOf('destination=' + encodeURIComponent('深圳湾口岸'))).assertLarger(-1);
      expect(url.indexOf('travelmode=driving')).assertLarger(-1);
      expect(url.indexOf('dir_action=navigate')).assertLarger(-1);
      expect(googleMapsDirectionsUrl(JSON.parse('{"origin":"深圳北站"}') as Object)).assertEqual('');
    });

    it('returns a real Maps URL action without falling back to Places', 0, () => {
      const result = mapsRouteResult(JSON.parse('{"origin":"深圳北站","destination":"深圳湾口岸","travelMode":"teleport"}') as Object);
      expect(result.toolName).assertEqual('maps.route.open');
      expect(result.status).assertEqual('success');
      expect(JSON.stringify(result.rows).indexOf('travelmode=driving')).assertLarger(-1);
      expect(result.actions === undefined ? 0 : result.actions.length).assertEqual(1);
      if (result.actions !== undefined) {
        expect(result.actions[0].id).assertEqual('maps.open.web');
        expect(result.actions[0].label).assertEqual('查看路线');
      }
    });
  });
}
