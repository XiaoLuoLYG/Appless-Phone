import assert from 'node:assert/strict';
import test from 'node:test';
import {
  evaluateHotelSystemActionEvidence,
  foregroundBundleFromAbilityDump,
  hotelDetailClickLocator,
  hotelSearchActionEvidence,
  isExpectedHotelSystemBundle,
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

test('requires captured system surfaces and a verified return for visible hotel actions', () => {
  const evidence = hotelSearchActionEvidence('hotel-search-1', validActions);
  const missingRuntime = evaluateHotelSystemActionEvidence(evidence, {});

  assert.equal(missingRuntime.ok, false);
  assert.equal(missingRuntime.navigation.e2e.status, 'BLOCKED');
  assert.equal(missingRuntime.call.button.status, 'PASS');
  assert.equal(missingRuntime.call.e2e.status, 'BLOCKED');

  const complete = evaluateHotelSystemActionEvidence(evidence, {
    navigation: {
      systemSurfaceOpened: true,
      evidenceCaptured: true,
      returnedToApp: true
    },
    call: {
      buttonVisible: true,
      systemSurfaceOpened: true,
      evidenceCaptured: true,
      returnedToApp: true,
      finalDialTriggered: false
    }
  });
  assert.equal(complete.ok, true);
  assert.equal(complete.navigation.e2e.status, 'PASS');
  assert.equal(complete.call.e2e.status, 'PASS');
});

test('passes a hidden missing-phone button but leaves dialer E2E explicitly not run', () => {
  const evidence = hotelSearchActionEvidence('hotel-search-1', validActions.slice(0, 2));
  const result = evaluateHotelSystemActionEvidence(evidence, {
    navigation: {
      systemSurfaceOpened: true,
      evidenceCaptured: true,
      returnedToApp: true
    },
    call: {
      buttonVisible: false
    }
  });

  assert.equal(result.ok, true);
  assert.equal(result.call.button.status, 'PASS');
  assert.equal(result.call.button.reason, 'verified phone unavailable; call action correctly hidden');
  assert.equal(result.call.e2e.status, 'NOT_RUN');
  assert.notEqual(result.call.e2e.status, result.call.button.status);

  const unverifiedHidden = evaluateHotelSystemActionEvidence(evidence, {
    navigation: {
      systemSurfaceOpened: true,
      evidenceCaptured: true,
      returnedToApp: true
    }
  });
  assert.equal(unverifiedHidden.ok, false);
  assert.equal(unverifiedHidden.call.button.status, 'BLOCKED');
});

test('fails closed when a call action is invalid or any final dial is triggered', () => {
  const invalidCall = structuredClone(validActions);
  invalidCall[2].args.providerPlaceId = '';
  const invalid = evaluateHotelSystemActionEvidence(
    hotelSearchActionEvidence('hotel-search-1', invalidCall),
    {}
  );
  assert.equal(invalid.ok, false);
  assert.equal(invalid.call.button.status, 'FAIL');
  assert.equal(invalid.call.e2e.status, 'BLOCKED');

  const dialed = evaluateHotelSystemActionEvidence(
    hotelSearchActionEvidence('hotel-search-1', validActions),
    {
      navigation: {
        systemSurfaceOpened: true,
        evidenceCaptured: true,
        returnedToApp: true
      },
      call: {
        buttonVisible: true,
        systemSurfaceOpened: true,
        evidenceCaptured: true,
        returnedToApp: true,
        finalDialTriggered: true
      }
    }
  );
  assert.equal(dialed.ok, false);
  assert.equal(dialed.call.e2e.status, 'FAIL');
  assert.match(dialed.call.e2e.reason, /final dial/i);
});

test('recognizes only the foreground system map or dialer bundle', () => {
  const dump = `
    Mission ID #1
      bundle name [com.example.aiphonedemo]
      state #BACKGROUND
    Mission ID #2
      bundle name [com.huawei.hmos.maps.app]
      state #FOREGROUND
      app state #FOREGROUND
  `;
  assert.equal(foregroundBundleFromAbilityDump(dump), 'com.huawei.hmos.maps.app');
  assert.equal(
    isExpectedHotelSystemBundle('hotel.navigate', 'com.huawei.hmos.maps.app'),
    true
  );
  assert.equal(
    isExpectedHotelSystemBundle('hotel.call', 'com.ohos.contacts'),
    true
  );
  assert.equal(
    isExpectedHotelSystemBundle('hotel.call', 'com.ohos.telephony'),
    false
  );
  assert.equal(
    isExpectedHotelSystemBundle('hotel.call', 'com.example.aiphonedemo'),
    false
  );
});
