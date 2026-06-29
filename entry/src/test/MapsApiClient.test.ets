import { describe, it, expect } from '@ohos/hypium';
import { mapsTextSearchBody, mapsTextSearchResultsFromPayload } from '../main/ets/model/MapsApiClient';

export default function mapsApiClientTest() {
  describe('mapsApiClient', () => {
    it('builds text search body for POI search', 0, () => {
      const body = mapsTextSearchBody('深圳坂田华为基地附近的咖啡店');
      expect(JSON.stringify(body)).assertEqual('{"textQuery":"深圳坂田华为基地附近的咖啡店","languageCode":"zh-CN"}');
    });

    it('maps Places payload into generic results', 0, () => {
      const payload = '{"places":[{"id":"place-123","displayName":{"text":"Coffee Lab"},"formattedAddress":"深圳市龙岗区坂田","rating":4.6,"googleMapsUri":"https://maps.google.com/?cid=123"}]}';
      const results = mapsTextSearchResultsFromPayload(payload, '深圳咖啡');
      expect(results.length).assertEqual(1);
      expect(results[0].sourceTag).assertEqual('Google Places API');
      expect(results[0].toolName).assertEqual('maps.place.search');
      expect(results[0].title).assertEqual('Coffee Lab');
      expect(results[0].rows[0].value).assertEqual('place-123');
    });
  });
}
