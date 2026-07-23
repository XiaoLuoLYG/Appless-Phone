import assert from 'node:assert/strict';
import test from 'node:test';
import {
  evaluateHotelSystemActionEvidence,
  foregroundBundleFromAbilityDump,
  hasPopulatedHotelActionEvidence,
  hotelActionEvidenceFromLogs,
  hotelDetailClickLocator,
  hotelMultiAgentDetailEvidence,
  hotelDetailLifecycleFromLogs,
  hotelMultiAgentSearchEvidence,
  hotelSearchActionEvidence,
  hotelToolLifecycleFromLogs,
  hasSafeHotelSystemIntentOpen,
  isExpectedHotelSystemBundle,
  matchesHotelDetailAccessibleLabel,
  restoredHotelSearchSurface,
  shouldRetryHotelReturnToApp,
  validateHotelDetailBookingEvidence,
  validateHotelSearchActionEvidence,
  validateHotelSurfaceIdentity
} from './hotel-smoke-evidence.mjs';

const realC20DetailLog = `
  [AIPhone][MultiAgentActionRun] conversation=c20 turn=action-1 task=action-1 surface=search-1 plan=plan-1 run=run-1 action=hotel.detail source=hotel.search
  [AIPhone][MultiAgentUiTask] conversation=c20 turn=detail-1 task=ui-detail dataTasks=data-detail
  [AIPhone][MultiAgentDataTask] conversation=c20 turn=detail-1 task=data-detail round=1 tool=hotel.detail predecessor=none path=none target=none binding=false
  [AIPhone][RollingGoHotelRequest] operation=getHotelDetail
  [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=detail-1 status=calling_tool components=2
  [AIPhone][RollingGoHotelResponse] operation=getHotelDetail provider=RollingGo status=success sources=1
  [AIPhone][MultiAgentDataResult] conversation=c20 turn=detail-1 task=data-detail tool=hotel.detail status=success sources=1 error=false
  [AIPhone][HtmlHomeDocument] source=tool kind=hotel chars=94242 blocks=64
  [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=detail-1 status=ready components=3
  [AIPhone][MultiAgentUiResult] conversation=c20 turn=detail-1 task=ui-detail surface=detail-1 state=result
  [AIPhone][MultiAgentActionResult] conversation=c20 turn=action-1 task=action-1 surface=search-1 plan=plan-1 run=run-1 status=success
`;

test('accepts the preserved C20 detail order with a provider request before the skeleton', () => {
  const evidence = hotelMultiAgentDetailEvidence(realC20DetailLog, {
    expectedConversationId: 'c20',
    currentSurfaceId: 'search-1'
  });
  assert.equal(evidence.ok, true);
  assert.equal(evidence.surfaceId, 'detail-1');
  assert.equal(evidence.operation, 'getHotelDetail');
});

test('rejects C20 detail evidence with a wrong task, surface, operation, response, or terminal order', () => {
  const options = { expectedConversationId: 'c20', currentSurfaceId: 'search-1' };
  [
    realC20DetailLog.replace('task=data-detail round=1 tool=hotel.detail', 'task=wrong-data round=1 tool=hotel.detail'),
    realC20DetailLog.replaceAll('surface=detail-1', 'surface=wrong-surface'),
    realC20DetailLog.replaceAll('operation=getHotelDetail', 'operation=searchHotels'),
    realC20DetailLog.replace('[AIPhone][RollingGoHotelResponse] operation=getHotelDetail provider=RollingGo status=success sources=1\n', ''),
    realC20DetailLog.replace(
      '[AIPhone][MultiAgentDataResult] conversation=c20 turn=detail-1 task=data-detail tool=hotel.detail status=success sources=1 error=false\n  [AIPhone][HtmlHomeDocument]',
      '[AIPhone][HtmlHomeDocument]'
    )
  ].forEach((logs) => assert.equal(hotelMultiAgentDetailEvidence(logs, options).ok, false));
});

const validBooking = {
  id: 'hotel.booking.open',
  label: '在 App 内继续预订',
  args: {
    hotelId: 47675,
    bookingUrl: 'https://rollinggo.cn/pages/hotel/detail/index?' +
      'id=47675&checkInDate=2026-08-08&checkOutDate=2026-08-10&' +
      'roomCount=1&adultCount=2&childCount=0'
  }
};

const validActions = [{
  id: 'hotel.detail',
  label: 'arbitrary detail label',
  args: { hotelId: 47675 }
}, {
  id: 'hotel.navigate',
  label: '任意导航文案',
  args: {
    hotelId: 47675,
    latitude: 22.5431,
    longitude: 114.0579
  }
}, validBooking];

test('collects detail, navigation and booking actions without retaining URL secrets', () => {
  const evidence = hotelSearchActionEvidence('hotel-detail-2', validActions);
  const serialized = JSON.stringify(evidence);
  assert.deepEqual(evidence.actions.map((action) => action.actionId), [
    'hotel.detail', 'hotel.navigate', 'hotel.booking.open'
  ]);
  assert.equal(evidence.actions[1].coordinatesValid, true);
  assert.equal(evidence.actions[2].argsValid, true);
  assert.equal(evidence.actions[2].hostValid, true);
  assert.equal(evidence.actions[2].pathValid, true);
  assert.equal(serialized.includes('rollinggo.cn'), false);
  assert.equal(serialized.includes('2026-08-08'), false);
  assert.equal(evidence.actions[0].clickLabel, 'arbitrary detail label');
  assert.equal(Object.hasOwn(evidence.actions[1], 'clickLabel'), false);
});

test('rejects booking actions leaked onto the search surface', () => {
  const leaked = validateHotelSearchActionEvidence(
    hotelSearchActionEvidence('hotel-search-1', validActions)
  );
  assert.equal(leaked.ok, false);
  assert.equal(leaked.booking.status, 'visible');
});

test('ignores removed dial and legacy booking actions', () => {
  const removedDialActionId = 'hotel.' + 'call';
  const evidence = hotelSearchActionEvidence('hotel-search-1', [
    { id: removedDialActionId, args: { hotelId: 47675, dialPhone: '+8675512348000' } },
    { id: 'hotel.book', args: { hotelId: 47675 } },
    validActions[0]
  ]);
  assert.deepEqual(evidence.actions.map((action) => action.actionId), ['hotel.detail']);
  assert.equal(JSON.stringify(evidence).includes('8675512348000'), false);
});

test('does not treat empty welcome evidence as completed hotel action evidence', () => {
  const welcome = hotelActionEvidenceFromLogs('[AIPhone][HotelHomeActionEvidence] evidence=""');
  assert.equal(welcome.surfaceId, '');
  assert.deepEqual(welcome.actions, []);
  assert.equal(hasPopulatedHotelActionEvidence(welcome), false);
  const complete = hotelActionEvidenceFromLogs(
    '[AIPhone][HotelHomeActionEvidence] evidence=' +
      JSON.stringify(JSON.stringify({ surfaceId: 'hotel-search-1', actions: [validActions[0]] }))
  );
  assert.equal(hasPopulatedHotelActionEvidence(complete), true);
});

test('requires one hotel surface to progress from calling_tool through real blocks to ready', () => {
  const complete = hotelDetailLifecycleFromLogs(`
    [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=hotel-detail-2 status=calling_tool components=2
    [AIPhone][RollingGoHotelRequest] operation=getHotelDetail
    [AIPhone][RollingGoHotelResponse] operation=getHotelDetail provider=RollingGo status=success sources=1
    [AIPhone][HtmlHomeDocument] source=tool kind=hotel chars=94242 blocks=64
    [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=hotel-detail-2 status=ready components=3
  `);
  assert.equal(complete.ok, true);
  assert.equal(complete.blocks, 64);
  assert.equal(hotelDetailLifecycleFromLogs(`
    [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=hotel-detail-2 status=calling_tool components=2
    com.example.aiphonedemo/NETSTACK RespCode:200 method:POST
    [AIPhone][HtmlHomeDocument] source=tool kind=hotel chars=94242 blocks=64
    [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=hotel-detail-2 status=ready components=3
  `).ok, false);
  assert.equal(hotelToolLifecycleFromLogs(
    '[AIPhone][A2uiHomeSurfaceUpdate] surfaceId=hotel-detail-2 status=ready'
  ).requested, false);
});

test('combines generic turn correlation with specialized hotel provider evidence', () => {
  const complete = hotelMultiAgentSearchEvidence(`
    [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=data-1 round=1 tool=hotel.search predecessor=none path=none target=none binding=false
    [AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=ui-1 dataTasks=data-1
    [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=loop_surface_1784700000000 status=calling_tool components=2
    [AIPhone][RollingGoHotelRequest] operation=searchHotels
    [AIPhone][RollingGoHotelResponse] operation=searchHotels provider=RollingGo status=success sources=1
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=hotel.search status=success sources=1 error=false
    [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=loop_surface_1784700000000 state=skeleton
    [AIPhone][HtmlHomeDocument] source=tool kind=hotel chars=94242 blocks=64
    [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=loop_surface_1784700000000 state=result
    [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=loop_surface_1784700000000 status=ready components=3
    [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=success surface=loop_surface_1784700000000 roundCount=1 messageChars=12
  `);
  assert.equal(complete.ok, true);
  assert.equal(complete.lifecycle.toolIds[0], 'hotel.search');
  assert.equal(complete.provider.blocks, 64);
  assert.equal(complete.provider.surfaceId, complete.lifecycle.surfaceId);
  assert.equal(hotelMultiAgentSearchEvidence(`
    [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=data-1 round=1 tool=hotel.search predecessor=none path=none target=none binding=false
    [AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=ui-1 dataTasks=data-1
    [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=loop_surface_1784700000001 status=calling_tool components=2
    [AIPhone][RollingGoHotelRequest] operation=searchHotels
    [AIPhone][RollingGoHotelResponse] operation=searchHotels provider=RollingGo status=success sources=1
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=hotel.search status=success sources=1 error=false
    [AIPhone][HtmlHomeDocument] source=tool kind=hotel chars=94242 blocks=64
    [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=loop_surface_1784700000002 state=result
    [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=loop_surface_1784700000001 status=ready components=3
    [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=success surface=loop_surface_1784700000002 roundCount=1 messageChars=12
  `).ok, false);
  assert.equal(hotelMultiAgentSearchEvidence(`
    [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=data-1 round=1 tool=hotel.search predecessor=none path=none target=none binding=false
    [AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=ui-1 dataTasks=data-1
    [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=hotel-search-1 status=calling_tool components=2
    com.example.aiphonedemo/NETSTACK RespCode:200 method:POST
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=hotel.search status=success sources=1 error=false
    [AIPhone][HtmlHomeDocument] source=tool kind=hotel chars=94242 blocks=64
    [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=hotel-search-1 state=result
    [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=hotel-search-1 status=ready components=3
    [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=success surface=hotel-search-1 roundCount=1 messageChars=12
  `).ok, false);
  assert.equal(hotelMultiAgentSearchEvidence(`
    [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=data-1 round=1 tool=hotel.search predecessor=none path=none target=none binding=false
    [AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=ui-1 dataTasks=data-1
    [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=hotel-search-1 status=calling_tool components=2
    [AIPhone][RollingGoHotelResponse] operation=searchHotels provider=RollingGo status=success sources=1
    [AIPhone][RollingGoHotelRequest] operation=searchHotels
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=hotel.search status=success sources=1 error=false
    [AIPhone][HtmlHomeDocument] source=tool kind=hotel chars=94242 blocks=64
    [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=hotel-search-1 state=result
    [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=hotel-search-1 status=ready components=3
    [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=success surface=hotel-search-1 roundCount=1 messageChars=12
  `).ok, false);
  assert.equal(hotelMultiAgentSearchEvidence(
    complete.raw || '[AIPhone][A2uiHomeSurfaceUpdate] surfaceId=hotel-search-1 status=ready'
  ).ok, false);
});

test('validates exactly one booking action on a detail surface', () => {
  const detail = validateHotelDetailBookingEvidence(hotelSearchActionEvidence('hotel-detail-2', [validBooking]));
  assert.equal(detail.ok, true);
  assert.deepEqual(detail.booking, { status: 'visible', count: 1 });

  const duplicate = validateHotelDetailBookingEvidence(
    hotelSearchActionEvidence('hotel-detail-2', [validBooking, validBooking])
  );
  assert.equal(duplicate.ok, false);
  assert.equal(duplicate.booking.status, 'visible');
  assert.equal(duplicate.booking.count, 2);

  const missing = validateHotelDetailBookingEvidence({ surfaceId: 'hotel-detail-2', actions: [] });
  assert.equal(missing.ok, false);
});

test('rejects booking URL host, path, hotel ID, date and occupancy tampering', () => {
  const invalid = structuredClone(validBooking);
  const cases = [
    ['https://evil.example/pages/hotel/detail/index?id=47675&checkInDate=2026-08-08&checkOutDate=2026-08-10&roomCount=1&adultCount=2&childCount=0', 'hostValid'],
    ['https://rollinggo.cn/other?id=47675&checkInDate=2026-08-08&checkOutDate=2026-08-10&roomCount=1&adultCount=2&childCount=0', 'pathValid'],
    ['https://rollinggo.cn/pages/hotel/detail/index?id=9&checkInDate=2026-08-08&checkOutDate=2026-08-10&roomCount=1&adultCount=2&childCount=0', 'hotelIdMatches'],
    ['https://rollinggo.cn/pages/hotel/detail/index?id=47675&checkInDate=2026-08-10&checkOutDate=2026-08-08&roomCount=1&adultCount=2&childCount=0', 'datesValid'],
    ['https://rollinggo.cn/pages/hotel/detail/index?id=47675&checkInDate=2026-08-08&checkOutDate=2026-08-10&roomCount=0&adultCount=2&childCount=0', 'occupancyValid']
  ];
  for (const [bookingUrl, field] of cases) {
    invalid.args.bookingUrl = bookingUrl;
    const action = hotelSearchActionEvidence('hotel-detail-2', [invalid]).actions[0];
    assert.equal(action[field], false, field);
    assert.equal(action.argsValid, false, field);
  }
});

test('treats missing optional actions as hidden and invalid present actions as failures', () => {
  const hidden = validateHotelSearchActionEvidence(hotelSearchActionEvidence(
    'hotel-search-1', [validActions[0]]
  ));
  assert.equal(hidden.ok, true);
  assert.equal(hidden.navigation.status, 'hidden');
  assert.equal(hidden.booking.status, 'hidden');

  const invalidNavigate = structuredClone(validActions);
  invalidNavigate[1].args.latitude = 91;
  const badNavigate = validateHotelSearchActionEvidence(hotelSearchActionEvidence(
    'hotel-search-1', invalidNavigate
  ));
  assert.equal(badNavigate.ok, false);
  assert.equal(badNavigate.navigation.status, 'invalid');

  const invalidBooking = structuredClone(validActions);
  invalidBooking[2].args.bookingUrl = 'javascript:alert(1)';
  const badBooking = validateHotelSearchActionEvidence(hotelSearchActionEvidence(
    'hotel-search-1', invalidBooking
  ));
  assert.equal(badBooking.ok, false);
  assert.equal(badBooking.booking.status, 'invalid');
});

test('recognizes only the redacted successful Petal Maps intent', () => {
  assert.equal(hasSafeHotelSystemIntentOpen(
    '[AIPhone][A2uiHomeOpenUrl] ok=true scheme=petalmaps chars=92', 'petalmaps'
  ), true);
  assert.equal(hasSafeHotelSystemIntentOpen(
    '[AIPhone][A2uiHomeOpenUrl] ok=false scheme=petalmaps chars=92 code=1', 'petalmaps'
  ), false);
  assert.equal(hasSafeHotelSystemIntentOpen(
    '[AIPhone][A2uiHomeOpenUrl] ok=true scheme=tel chars=92', 'tel'
  ), false);
});

test('requires exact search detail and restored surface identity', () => {
  assert.deepEqual(
    validateHotelSurfaceIdentity('hotel-search-1', 'hotel-detail-2', 'hotel-search-1'),
    { ok: true, searchSurfaceId: 'hotel-search-1', detailSurfaceId: 'hotel-detail-2', restoredSurfaceId: 'hotel-search-1' }
  );
  assert.equal(validateHotelSurfaceIdentity('', 'hotel-detail-2', '').ok, false);
  assert.equal(validateHotelSurfaceIdentity('same', 'same', 'same').ok, false);
  assert.equal(validateHotelSurfaceIdentity('hotel-search-1', 'hotel-detail-2', 'other').ok, false);
});

test('uses validated restored action evidence with the original search conversation', () => {
  const context = { conversationId: 'c20', surfaceId: 'hotel-search-1' };
  const restored = {
    surfaceId: 'hotel-search-1',
    actions: hotelSearchActionEvidence('hotel-search-1', validActions.slice(0, 2)).actions
  };
  assert.deepEqual(restoredHotelSearchSurface(context, restored), context);
  assert.equal(restoredHotelSearchSurface(context, { ...restored, surfaceId: 'other' }), null);
  assert.equal(restoredHotelSearchSurface({ ...context, conversationId: '' }, restored), null);
});

test('derives the live detail click locator only from an exact valid action', () => {
  assert.deepEqual(hotelDetailClickLocator(
    hotelSearchActionEvidence('hotel-search-1', [validActions[0]])
  ), { ok: true, labels: ['arbitrary detail label'] });
  const invalid = structuredClone(validActions[0]);
  invalid.args.hotelId = 0;
  assert.equal(hotelDetailClickLocator(hotelSearchActionEvidence('hotel-search-1', [invalid])).ok, false);
});

test('matches only the exact detail action label or contextual accessible name', () => {
  assert.equal(matchesHotelDetailAccessibleLabel('查看实时房型', '查看实时房型'), true);
  assert.equal(matchesHotelDetailAccessibleLabel('查看实时房型：麗枫酒店', '查看实时房型'), true);
  assert.equal(matchesHotelDetailAccessibleLabel('查看实时房型：', '查看实时房型'), false);
  assert.equal(matchesHotelDetailAccessibleLabel('查看实时房型: forged', '查看实时房型'), false);
});

test('requires captured map surface and verified return, with no dialer state', () => {
  const evidence = hotelSearchActionEvidence('hotel-search-1', validActions.slice(0, 2));
  const missingRuntime = evaluateHotelSystemActionEvidence(evidence, {});
  assert.equal(missingRuntime.ok, false);
  assert.equal(missingRuntime.navigation.e2e.status, 'BLOCKED');
  assert.deepEqual(missingRuntime.booking, { status: 'hidden', count: 0 });

  const complete = evaluateHotelSystemActionEvidence(evidence, {
    navigation: { systemSurfaceOpened: true, evidenceCaptured: true, returnedToApp: true }
  });
  assert.equal(complete.ok, true);
  assert.equal(complete.navigation.e2e.status, 'PASS');
  assert.equal(Object.hasOwn(complete, 'call'), false);
  assert.equal(JSON.stringify(complete).includes('finalDialTriggered'), false);
});

test('recognizes only the foreground system map bundle', () => {
  const dump = `
    Mission ID #1
      bundle name [com.example.aiphonedemo]
      state #BACKGROUND
    Mission ID #2
      bundle name [com.huawei.hmos.maps.app]
      state #FOREGROUND
  `;
  assert.equal(foregroundBundleFromAbilityDump(dump), 'com.huawei.hmos.maps.app');
  assert.equal(isExpectedHotelSystemBundle('hotel.navigate', 'com.huawei.hmos.maps.app'), true);
  assert.equal(isExpectedHotelSystemBundle('hotel.' + 'call', 'com.ohos.contacts'), false);
});

test('retries only bounded Back navigation until AIPhone is foreground', () => {
  assert.equal(shouldRetryHotelReturnToApp('com.huawei.hmos.maps.app', 1), true);
  assert.equal(shouldRetryHotelReturnToApp('com.huawei.hmos.maps.app', 3), false);
  assert.equal(shouldRetryHotelReturnToApp('com.example.aiphonedemo', 1), false);
  assert.equal(shouldRetryHotelReturnToApp('', 1), true);
});
