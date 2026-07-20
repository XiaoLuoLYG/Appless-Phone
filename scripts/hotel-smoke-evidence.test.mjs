import assert from 'node:assert/strict';
import test from 'node:test';
import {
  hotelDetailClickLocator,
  hotelSearchActionEvidence,
  validateHotelSearchActionEvidence,
  validateHotelSurfaceIdentity
} from './hotel-smoke-evidence.mjs';

const validActions = [{
  id: 'hotel.detail',
  label: 'arbitrary detail label',
  args: { hotelId: 47675 }
}, {
  id: 'hotel.navigate',
  label: '任意导航文案',
  args: {
    hotelId: 47675,
    name: '深圳测试酒店',
    address: '深圳市南山区',
    latitude: 22.5431,
    longitude: 114.0579
  }
}, {
  id: 'hotel.call',
  label: '任意联系文案',
  args: {
    hotelId: 47675,
    name: '深圳测试酒店',
    displayPhone: '+86 755 1234 8000',
    dialPhone: '+8675512348000',
    provider: 'Google Places',
    providerPlaceId: 'places/ChIJ-real-hotel'
  }
}];

test('sanitizes exact action IDs independently of supplied labels', () => {
  const evidence = hotelSearchActionEvidence('hotel-search-1', validActions);
  const serialized = JSON.stringify(evidence);

  assert.deepEqual(evidence.actions.map((action) => action.actionId), [
    'hotel.detail',
    'hotel.navigate',
    'hotel.call'
  ]);
  assert.equal(evidence.actions[1].coordinatesValid, true);
  assert.equal(evidence.actions[2].argsValid, true);
  assert.equal(evidence.actions[2].maskedSuffix, '***8000');
  assert.equal(serialized.includes('+8675512348000'), false);
  assert.equal(serialized.includes('+86 755 1234 8000'), false);
  assert.equal(evidence.actions[0].clickLabel, 'arbitrary detail label');
  assert.equal(Object.hasOwn(evidence.actions[1], 'clickLabel'), false);
  assert.equal(Object.hasOwn(evidence.actions[2], 'clickLabel'), false);
});

test('treats missing optional actions as hidden and invalid present actions as failures', () => {
  const hidden = validateHotelSearchActionEvidence(hotelSearchActionEvidence(
    'hotel-search-1',
    [validActions[0]]
  ));
  assert.equal(hidden.ok, true);
  assert.equal(hidden.navigation.status, 'hidden');
  assert.equal(hidden.call.status, 'hidden');

  const invalidNavigate = structuredClone(validActions);
  invalidNavigate[1].args.latitude = 91;
  const badNavigate = validateHotelSearchActionEvidence(hotelSearchActionEvidence(
    'hotel-search-1',
    invalidNavigate
  ));
  assert.equal(badNavigate.ok, false);
  assert.equal(badNavigate.navigation.status, 'invalid');

  const invalidCall = structuredClone(validActions);
  invalidCall[2].args.dialPhone = '+8675512348000x';
  const badCall = validateHotelSearchActionEvidence(hotelSearchActionEvidence(
    'hotel-search-1',
    invalidCall
  ));
  assert.equal(badCall.ok, false);
  assert.equal(badCall.call.status, 'invalid');
  assert.equal(JSON.stringify(badCall).includes('+8675512348000'), false);

  const forgedRawField = validateHotelSearchActionEvidence({
    surfaceId: 'hotel-search-1',
    actions: [{
      actionId: 'hotel.call',
      argsValid: true,
      rawPhone: '+8675512348000',
      maskedSuffix: '***8000'
    }, {
      actionId: 'hotel.detail',
      argsValid: true,
      rawArgs: { dialPhone: '+8675512348000' }
    }]
  });
  assert.equal(JSON.stringify(forgedRawField).includes('+8675512348000'), false);
});

test('requires exact search detail and restored surface identity', () => {
  assert.deepEqual(
    validateHotelSurfaceIdentity('hotel-search-1', 'hotel-detail-2', 'hotel-search-1'),
    { ok: true, searchSurfaceId: 'hotel-search-1', detailSurfaceId: 'hotel-detail-2', restoredSurfaceId: 'hotel-search-1' }
  );
  assert.equal(validateHotelSurfaceIdentity('', 'hotel-detail-2', '').ok, false);
  assert.equal(validateHotelSurfaceIdentity('   ', 'hotel-detail-2', '   ').ok, false);
  assert.equal(validateHotelSurfaceIdentity('same', 'same', 'same').ok, false);
  assert.equal(validateHotelSurfaceIdentity('hotel-search-1', 'hotel-detail-2', 'other').ok, false);
});

test('derives the live detail click locator only from an exact valid action', () => {
  const arbitraryLabelEvidence = hotelSearchActionEvidence('hotel-search-1', validActions);
  assert.deepEqual(hotelDetailClickLocator(arbitraryLabelEvidence), {
    ok: true,
    labels: ['arbitrary detail label']
  });

  const wrongActionId = structuredClone(validActions);
  wrongActionId[0].id = 'hotel.details';
  assert.equal(
    hotelDetailClickLocator(hotelSearchActionEvidence('hotel-search-1', wrongActionId)).ok,
    false
  );

  const invalidArgs = structuredClone(validActions);
  invalidArgs[0].args.hotelId = 0;
  assert.equal(
    hotelDetailClickLocator(hotelSearchActionEvidence('hotel-search-1', invalidArgs)).ok,
    false
  );
});
