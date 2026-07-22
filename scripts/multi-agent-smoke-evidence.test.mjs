import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import {
  multiAgentActionEvidence,
  multiAgentTurnEvidence
} from './multi-agent-smoke-evidence.mjs';

function listedCases(args = [], env = {}) {
  const result = spawnSync(process.execPath, [
    'scripts/aiphone-device-smoke.mjs',
    ...args,
    '--list-cases'
  ], {
    cwd: process.cwd(),
    encoding: 'utf8',
    env: { ...process.env, ...env }
  });
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout);
}

const successTurn = `
[AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1
[AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=data-1 round=1 tool=travel.search predecessor=none path=none target=none binding=false
[AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=ui-1 dataTasks=data-1
[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=travel.search status=success sources=1 error=false
[AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=surface-1 state=skeleton
[AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=surface-1 state=result
[AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=success surface=surface-1 roundCount=1 messageChars=12
`;

test('requires one strictly correlated successful multi-agent turn', () => {
  const evidence = multiAgentTurnEvidence(successTurn, {
    expectedToolIds: ['travel.search']
  });
  assert.equal(evidence.complete, true);
  assert.equal(evidence.ok, true);
  assert.equal(evidence.status, 'success');
  assert.deepEqual(evidence.toolIds, ['travel.search']);
});

test('keeps partial, empty, error, and canceled terminal truth', () => {
  for (const [status, uiState, expectedOk] of [
    ['partial', 'result', true],
    ['empty', 'result', true],
    ['error', 'error', false],
    ['canceled', 'error', false]
  ]) {
    const result = multiAgentTurnEvidence(successTurn
      .replace('status=success sources=1 error=false',
        `status=${status === 'canceled' ? 'error' : status} sources=1 error=${status === 'error' || status === 'canceled' ? 'true' : 'false'}`)
      .replace('state=result', `state=${uiState}`)
      .replace('status=success surface=surface-1', `status=${status} surface=surface-1`));
    assert.equal(result.complete, true, status);
    assert.equal(result.ok, expectedOk, status);
    assert.equal(result.status, status, status);
  }
});

test('accepts truthful UI rendering failures without relabeling Data success', () => {
  const uiError = successTurn
    .replace('state=result', 'state=error')
    .replace('status=success surface=surface-1', 'status=error surface=surface-1');
  const result = multiAgentTurnEvidence(uiError, { expectedToolIds: ['travel.search'] });
  assert.equal(result.complete, true);
  assert.equal(result.ok, false);
  assert.equal(result.status, 'error');

  const uiTaskError = uiError.replace(
    /^.*MultiAgentUiResult.*state=(?:skeleton|error).*\n/gm,
    ''
  ).replace(
    '[AIPhone][MultiAgentTurnResult]',
    '[AIPhone][MultiAgentTaskError] conversation=c1 turn=t1 task=ui-1 code=UI_RENDER_FAILED\n[AIPhone][MultiAgentTurnResult]'
  ).replace('status=error surface=surface-1', 'status=error surface=none');
  assert.equal(multiAgentTurnEvidence(uiTaskError, {
    expectedToolIds: ['travel.search']
  }).complete, true);
});

test('rejects wrong conversation, turn, or task correlation', () => {
  const mutations = [
    successTurn.replace('conversation=c1 turn=t1 task=data-1 tool=', 'conversation=other turn=t1 task=data-1 tool='),
    successTurn.replace('conversation=c1 turn=t1 task=data-1 tool=', 'conversation=c1 turn=other task=data-1 tool='),
    successTurn.replace('task=data-1 tool=travel.search status=', 'task=other tool=travel.search status=')
  ];
  for (const logs of mutations) {
    assert.equal(multiAgentTurnEvidence(logs, { expectedToolIds: ['travel.search'] }).complete, false);
  }
});

test('rejects a missing DataResult and a UI-ready-only trace', () => {
  assert.equal(multiAgentTurnEvidence(
    successTurn.replace(/^.*MultiAgentDataResult.*\n/m, ''),
    { expectedToolIds: ['travel.search'] }
  ).complete, false);
  assert.equal(multiAgentTurnEvidence(`
    [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1
    [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=surface-1 state=result
  `, { expectedToolIds: ['travel.search'] }).complete, false);
});

test('rejects legacy LoopBackend-only markers and a mismatched tool ID', () => {
  assert.equal(multiAgentTurnEvidence(`
    [AIPhone][A2uiHomeToolRequest] toolId=travel.search
    [AIPhone][LocalToolResult] ok=true toolId=travel.search
    [AIPhone][A2uiHomeSurfaceUpdate] surfaceId=s1 status=ready
  `, { expectedToolIds: ['travel.search'] }).complete, false);
  assert.equal(multiAgentTurnEvidence(
    successTurn.replaceAll('travel.search', 'flight.search'),
    { expectedToolIds: ['travel.search'] }
  ).complete, false);
});

test('rejects a late stale turn after a newer input', () => {
  const logs = successTurn.replace(
    '[AIPhone][MultiAgentTurnResult]',
    '[AIPhone][MultiAgentInput] conversation=c1 turn=t2 task=input-2\n[AIPhone][MultiAgentTurnResult]'
  );
  assert.equal(multiAgentTurnEvidence(logs, {
    conversationId: 'c1',
    turnId: 't1',
    expectedToolIds: ['travel.search']
  }).complete, false);
});

test('rejects external errors mislabeled success and synthetic data', () => {
  const providerError = successTurn.replace(
    '[AIPhone][MultiAgentUiResult]',
    '[AIPhone][ProviderExternalError] conversation=c1 turn=t1 task=data-1 code=AUTH_REQUIRED\n[AIPhone][MultiAgentUiResult]'
  );
  assert.equal(multiAgentTurnEvidence(providerError, {
    expectedToolIds: ['travel.search']
  }).complete, false);
  assert.equal(multiAgentTurnEvidence(
    successTurn.replace('sources=1 error=false', 'sources=1 error=false synthetic=true'),
    { expectedToolIds: ['travel.search'] }
  ).complete, false);
});

test('requires every parallel tool task to reach a terminal', () => {
  const parallel = `
    [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=flight round=1 tool=flight.search predecessor=none path=none target=none binding=false
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=train round=1 tool=train.search predecessor=none path=none target=none binding=false
    [AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=ui dataTasks=flight,train
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=train tool=train.search status=success sources=1 error=false
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=flight tool=flight.search status=success sources=1 error=false
    [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui surface=s1 state=result
    [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=success surface=s1 roundCount=1 messageChars=8
  `;
  assert.equal(multiAgentTurnEvidence(parallel, {
    expectedToolIds: ['flight.search', 'train.search']
  }).complete, true);
  assert.equal(multiAgentTurnEvidence(
    parallel.replace(/^.*task=flight tool=flight.search status=.*\n/m, ''),
    { expectedToolIds: ['flight.search', 'train.search'] }
  ).complete, false);
});

test('accepts dependent tools only with increasing round evidence', () => {
  const dependent = `
    [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=search round=1 tool=maps.place.search predecessor=none path=none target=none binding=false
    [AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=ui-1 dataTasks=search
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=search tool=maps.place.search status=success sources=1 error=false
    [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=s1 state=result
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=details round=2 tool=maps.place.details predecessor=search path=/places/0/placeId target=/placeId binding=true
    [AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=ui-2 dataTasks=details
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=details tool=maps.place.details status=success sources=1 error=false
    [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-2 surface=s2 state=result
    [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=success surface=s2 roundCount=2 messageChars=8
  `;
  assert.equal(multiAgentTurnEvidence(dependent, {
    expectedToolIds: ['maps.place.search', 'maps.place.details'],
    minimumDataRounds: 2
  }).complete, true);
  assert.equal(multiAgentTurnEvidence(
    dependent.replace('round=2 tool=maps.place.details',
      'round=1 tool=maps.place.details'),
    { expectedToolIds: ['maps.place.search', 'maps.place.details'], minimumDataRounds: 2 }
  ).complete, false);
});

test('ends evidence at the first TurnResult and reports contradictory late markers', () => {
  const terminalBeforeData = successTurn.replace(
    /^.*MultiAgentDataResult.*\n/m,
    ''
  ).replace(
    /(^.*MultiAgentTurnResult.*$)/m,
    '$1\n[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=travel.search status=success sources=1 error=false'
  );
  const result = multiAgentTurnEvidence(terminalBeforeData, {
    expectedToolIds: ['travel.search']
  });
  assert.equal(result.complete, false);
  assert.ok(result.failures.includes('late_same_turn_marker'));
  assert.ok(result.failures.includes('missing_or_duplicate_data_terminal'));
});

test('requires ordered known task terminals and preserves duplicate tool multiplicity', () => {
  const resultBeforeCreate = successTurn.replace(
    /(^.*MultiAgentDataTask.*$)/m,
    '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=travel.search status=success sources=1 error=false\n$1'
  ).replace(/(^.*MultiAgentDataResult.*\n)(?=.*MultiAgentUiResult)/m, '');
  assert.equal(multiAgentTurnEvidence(resultBeforeCreate, {
    expectedToolIds: ['travel.search']
  }).complete, false);

  const duplicateTools = `
    [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=data-1 round=1 tool=travel.search predecessor=none path=none target=none binding=false
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=data-2 round=1 tool=travel.search predecessor=none path=none target=none binding=false
    [AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=ui-1 dataTasks=data-1,data-2
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=travel.search status=success sources=1 error=false
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-2 tool=travel.search status=success sources=1 error=false
    [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=s1 state=result
    [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=success surface=s1 roundCount=1 messageChars=8
  `;
  const duplicateResult = multiAgentTurnEvidence(duplicateTools, {
    expectedToolIds: ['travel.search', 'travel.search']
  });
  assert.equal(duplicateResult.complete, true);
  assert.deepEqual(duplicateResult.toolIds, ['travel.search', 'travel.search']);
});

test('rejects unknown or input TaskError and round overlap before predecessor settlement', () => {
  const unknownError = successTurn.replace(
    '[AIPhone][MultiAgentTurnResult]',
    '[AIPhone][MultiAgentTaskError] conversation=c1 turn=t1 task=unknown code=UNEXPECTED\n[AIPhone][MultiAgentTurnResult]'
  );
  assert.equal(multiAgentTurnEvidence(unknownError, {
    expectedToolIds: ['travel.search']
  }).complete, false);
  const inputError = successTurn.replace(
    '[AIPhone][MultiAgentTurnResult]',
    '[AIPhone][MultiAgentTaskError] conversation=c1 turn=t1 task=input-1 code=INPUT_FAILED\n[AIPhone][MultiAgentTurnResult]'
  );
  assert.equal(multiAgentTurnEvidence(inputError, {
    expectedToolIds: ['travel.search']
  }).complete, false);

  const overlappedRounds = `
    [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=search round=1 tool=maps.place.search predecessor=none path=none target=none binding=false
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=details round=2 tool=maps.place.details predecessor=search path=/places/0/placeId target=/placeId binding=true
    [AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=ui dataTasks=search,details
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=search tool=maps.place.search status=success sources=1 error=false
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=details tool=maps.place.details status=success sources=1 error=false
    [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui surface=s1 state=result
    [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=success surface=s1 roundCount=2 messageChars=8
  `;
  assert.equal(multiAgentTurnEvidence(overlappedRounds, {
    expectedToolIds: ['maps.place.search', 'maps.place.details'],
    minimumDataRounds: 2,
    expectedDependencies: [{
      toolId: 'maps.place.details',
      predecessorToolId: 'maps.place.search',
      path: '/places/0/placeId',
      target: '/placeId'
    }]
  }).complete, false);
});

test('requires explicit dependency metadata and the final UI surface on the TurnResult', () => {
  const dependent = `
    [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=search round=1 tool=maps.place.search predecessor=none path=none target=none binding=false
    [AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=ui-1 dataTasks=search
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=search tool=maps.place.search status=success sources=1 error=false
    [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=s1 state=result
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=details round=2 tool=maps.place.details predecessor=search path=/places/0/placeId target=/placeId binding=true
    [AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=ui-2 dataTasks=details
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=details tool=maps.place.details status=success sources=1 error=false
    [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-2 surface=s2 state=result
    [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=success surface=s2 roundCount=2 messageChars=8
  `;
  const options = {
    expectedToolIds: ['maps.place.search', 'maps.place.details'],
    minimumDataRounds: 2,
    expectedDependencies: [{
      toolId: 'maps.place.details',
      predecessorToolId: 'maps.place.search',
      path: '/places/0/placeId',
      target: '/placeId'
    }]
  };
  assert.equal(multiAgentTurnEvidence(dependent, options).complete, true);
  assert.equal(multiAgentTurnEvidence(
    dependent.replace(' predecessor=search path=/places/0/placeId target=/placeId binding=true', ''),
    options
  ).complete, false);
  assert.equal(multiAgentTurnEvidence(
    dependent.replace('status=success surface=s2 roundCount=', 'status=success surface=stale roundCount='),
    options
  ).complete, false);
});

test('accepts C01 as an input and terminal text result without a fake DataTask', () => {
  const result = multiAgentTurnEvidence(`
    [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1
    [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=success surface=none roundCount=1 messageChars=2
  `, { expectedToolIds: [] });
  assert.equal(result.complete, true);
  assert.equal(result.ok, true);
  assert.equal(result.textResult, true);
  assert.deepEqual(result.dataTasks, []);
});

test('correlates an exact current-surface action plan, run, and result', () => {
  const logs = `
    [AIPhone][MultiAgentActionRun] conversation=c1 turn=t1 task=a1 surface=s1 plan=p1 run=r1 action=hotel.navigate source=hotel.search
    [AIPhone][MultiAgentActionResult] conversation=c1 turn=t1 task=a1 surface=s1 plan=p1 run=r1 status=success
  `;
  const result = multiAgentActionEvidence(logs, {
    expectedActionId: 'hotel.navigate',
    surfaceId: 's1'
  });
  assert.equal(result.complete, true);
  assert.equal(result.ok, true);

  assert.equal(multiAgentActionEvidence(
    logs.replace('surface=s1 plan=p1 run=r1 status=success',
      'surface=stale plan=p1 run=r1 status=success'),
    { expectedActionId: 'hotel.navigate', surfaceId: 's1' }
  ).complete, false);
  assert.equal(multiAgentActionEvidence(
    '[AIPhone][A2uiHomeModelResult] ok=true action=hotel.navigate',
    { expectedActionId: 'hotel.navigate', surfaceId: 's1' }
  ).complete, false);
  assert.equal(multiAgentActionEvidence(
    logs.replace(
      '[AIPhone][MultiAgentActionResult]',
      '[AIPhone][ProviderExternalError] code=AUTH_REQUIRED\n[AIPhone][MultiAgentActionResult]'
    ),
    { expectedActionId: 'hotel.navigate', surfaceId: 's1' }
  ).complete, false);
});

test('keeps a terminal action error from becoming success', () => {
  const result = multiAgentActionEvidence(`
    [AIPhone][MultiAgentActionRun] conversation=c1 turn=t1 task=a1 surface=s1 plan=p1 run=r1 action=gmail.message.send source=gmail.thread.read
    [AIPhone][MultiAgentActionResult] conversation=c1 turn=t1 task=a1 surface=s1 plan=p1 run=r1 status=error
  `, { expectedActionId: 'gmail.message.send', surfaceId: 's1' });
  assert.equal(result.complete, true);
  assert.equal(result.ok, false);
  assert.equal(result.status, 'error');
});

test('correlates a virtual action request with its exact terminal result', () => {
  const result = multiAgentActionEvidence(`
    [AIPhone][MultiAgentActionPlan] conversation=c1 turn=t1 task=a1 uiTask=a1 dataTasks=none actions=payment.send virtual=true
    [AIPhone][MultiAgentActionResult] conversation=c1 turn=t1 task=a1 surface=s1 plan=p1 run=r1 status=success
  `, { expectedActionId: 'payment.send', expectedVirtual: true });
  assert.equal(result.complete, true);
  assert.equal(result.ok, true);
  assert.equal(result.surfaceId, 's1');
});

test('requires direct action ordering and the expected visible surface source and turn', () => {
  const reversed = `
    [AIPhone][MultiAgentActionResult] conversation=c1 turn=t1 task=a1 surface=s1 plan=p1 run=r1 status=success
    [AIPhone][MultiAgentActionRun] conversation=c1 turn=t1 task=a1 surface=s1 plan=p1 run=r1 action=hotel.navigate source=hotel.search
  `;
  assert.equal(multiAgentActionEvidence(reversed, {
    expectedActionId: 'hotel.navigate',
    currentSurfaceId: 's1',
    expectedSourceToolId: 'hotel.search',
    expectedConversationId: 'c1',
    expectedTurnId: 't1'
  }).complete, false);

  const stale = `
    [AIPhone][MultiAgentActionRun] conversation=c1 turn=old task=a0 surface=old-surface plan=p0 run=r0 action=hotel.navigate source=hotel.search
    [AIPhone][MultiAgentActionResult] conversation=c1 turn=old task=a0 surface=old-surface plan=p0 run=r0 status=success
  `;
  assert.equal(multiAgentActionEvidence(stale, {
    expectedActionId: 'hotel.navigate',
    currentSurfaceId: 's1',
    expectedSourceToolId: 'hotel.search',
    expectedConversationId: 'c1',
    expectedTurnId: 't1'
  }).complete, false);
});

test('requires a virtual action request before its exact result', () => {
  const reversed = `
    [AIPhone][MultiAgentActionResult] conversation=c1 turn=t1 task=a1 surface=s1 plan=p1 run=r1 status=success
    [AIPhone][MultiAgentActionPlan] conversation=c1 turn=t1 task=a1 uiTask=a1 dataTasks=none actions=payment.send virtual=true
  `;
  assert.equal(multiAgentActionEvidence(reversed, {
    expectedActionId: 'payment.send',
    expectedConversationId: 'c1',
    expectedTurnId: 't1',
    expectedVirtual: true
  }).complete, false);
  const fabricatedRun = `
    [AIPhone][MultiAgentActionPlan] conversation=c1 turn=t1 task=a1 uiTask=a1 dataTasks=none actions=payment.send virtual=true
    [AIPhone][MultiAgentActionRun] conversation=c1 turn=t1 task=a1 surface=s1 plan=p1 run=r1 action=payment.send source=payment.send
    [AIPhone][MultiAgentActionResult] conversation=c1 turn=t1 task=a1 surface=s1 plan=p1 run=r1 status=success
  `;
  assert.equal(multiAgentActionEvidence(fabricatedRun, {
    expectedActionId: 'payment.send',
    expectedConversationId: 'c1',
    expectedTurnId: 't1',
    expectedVirtual: true
  }).complete, false);
});

test('lists exactly C01-C20 and F01-F16 without excluded sends', () => {
  const core = listedCases();
  assert.deepEqual(core.map((item) => item.id),
    Array.from({ length: 20 }, (_value, index) => `C${String(index + 1).padStart(2, '0')}`));
  const full = listedCases(['--full-regression']);
  assert.deepEqual(full.map((item) => item.id), [
    ...core.map((item) => item.id),
    ...Array.from({ length: 16 }, (_value, index) => `F${String(index + 1).padStart(2, '0')}`)
  ]);
  const serialized = JSON.stringify(full);
  assert.doesNotMatch(serialized, /不确认直接发送|gmail\.message\.send/);
});

test('lists Gmail reply send only behind explicit safe manual configuration', () => {
  const manual = listedCases(['--gmail-send-manual'], {
    AIPHONE_GMAIL_SAFE_THREAD_ID: 'safe-test-thread',
    AIPHONE_GMAIL_SAFE_RECIPIENT: 'safe-test@example.com'
  });
  assert.deepEqual(manual.map((item) => item.id), ['M01']);
  assert.equal(manual[0].automated, false);
  assert.deepEqual(manual[0].expectedToolIds, ['gmail.message.send']);
});
