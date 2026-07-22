import { describe, it, expect } from '@ohos/hypium';
import {
  googleMapsDirectionsUrl,
  mapsDataResultA2ui,
  mapsFoodRecordFromResult,
  mapsPlaceDetailsProviderResultFromPayload,
  mapsPlaceProviderFailure,
  mapsPlaceSearchProviderResultFromPayload,
  mapsRouteResult,
  mapsStructuredDataResult,
  mapsTextSearchBody,
  mapsTextSearchResultsFromPayload,
  MapsStructuredData
} from '@loop/agent-core';

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

    it('keeps real place IDs and sources in structured search and detail results', 0, () => {
      const searchPayload = '{"places":[{"id":"place-123","displayName":{"text":"Coffee Lab"},"formattedAddress":"深圳市龙岗区坂田","rating":4.6,"googleMapsUri":"https://maps.google.com/?cid=123","location":{"latitude":22.609878,"longitude":114.029506}}]}';
      const detailPayload = '{"id":"place-123","displayName":{"text":"Coffee Lab"},"formattedAddress":"深圳市龙岗区坂田","rating":4.6,"googleMapsUri":"https://maps.google.com/?cid=123","location":{"latitude":22.609878,"longitude":114.029506}}';
      const search = mapsStructuredDataResult(
        'maps.place.search',
        mapsPlaceSearchProviderResultFromPayload(searchPayload, '深圳咖啡')
      );
      const details = mapsStructuredDataResult(
        'maps.place.details',
        mapsPlaceDetailsProviderResultFromPayload(detailPayload)
      );
      const searchData = search.data as MapsStructuredData;
      const detailData = details.data as MapsStructuredData;

      expect(search.status).assertEqual('success');
      expect(search.outputSchema).assertEqual('places');
      expect(searchData.places[0].placeId).assertEqual('place-123');
      expect(searchData.entityRefs.join(',')).assertEqual('place-123');
      expect(details.status).assertEqual('success');
      expect(details.outputSchema).assertEqual('place');
      expect(detailData.places[0].placeId).assertEqual('place-123');
      expect(detailData.entityRefs.join(',')).assertEqual('place-123');
      expect(search.sources[0].provider).assertEqual('Google Places API');
      expect(details.sources[0].operation).assertEqual('details');
      expect(JSON.stringify(search.data).indexOf('updateComponents')).assertEqual(-1);
      expect(JSON.stringify(search.data).indexOf('createSurface')).assertEqual(-1);
    });

    it('distinguishes successful empty Maps results from provider errors', 0, () => {
      const empty = mapsStructuredDataResult(
        'maps.place.search',
        mapsPlaceSearchProviderResultFromPayload('{"places":[]}', '没有这个地点')
      );
      const failed = mapsStructuredDataResult(
        'maps.place.details',
        mapsPlaceProviderFailure('maps.place.details', 'Google Places denied the request.')
      );

      expect(empty.status).assertEqual('empty');
      expect((empty.data as MapsStructuredData).places.length).assertEqual(0);
      expect((empty.data as MapsStructuredData).entityRefs.length).assertEqual(0);
      expect(mapsDataResultA2ui('surface_maps_empty', empty).indexOf('没有这个地点')).assertLarger(-1);
      expect(failed.status).assertEqual('error');
      expect((failed.data as MapsStructuredData).entityRefs.length).assertEqual(0);
      expect(failed.error?.code).assertEqual('MAPS_PROVIDER_ERROR');
      expect(failed.error?.message).assertEqual('Google Places denied the request.');
    });

    it('renders the same structured Maps records without provider work or changed IDs', 0, () => {
      const payload = '{"places":[{"id":"place-render-1","displayName":{"text":"Renderer Cafe"},"formattedAddress":"King Cross","googleMapsUri":"https://maps.google.com/?cid=render"}]}';
      const result = mapsStructuredDataResult(
        'maps.place.search',
        mapsPlaceSearchProviderResultFromPayload(payload, 'King Cross Chinese food')
      );
      const jsonl = mapsDataResultA2ui('surface_maps_structured', result);

      expect(jsonl.indexOf('place-render-1')).assertLarger(-1);
      expect(jsonl.indexOf('Renderer Cafe')).assertLarger(-1);
      expect(JSON.stringify(result.data).indexOf('updateComponents')).assertEqual(-1);
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
