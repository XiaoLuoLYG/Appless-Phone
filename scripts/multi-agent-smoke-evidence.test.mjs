import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import * as smokeLifecycle from './multi-agent-smoke-evidence.mjs';
import {
  composioAuthEvidence,
  calendarProviderActionEvidence,
  calendarProviderAbsenceEvidence,
  calendarEvidenceIdentityToken,
  normalizeCalendarQaDate,
  directTextVisibleEvidence,
  latestMultiAgentUiSurface,
  mailThreadReadEvidence,
  visibleMailBodyText,
  modelTransportEvidence,
  multiAgentActionEvidence,
  multiAgentTurnEvidence,
  socialDraftUiEvidence,
  socialReplyButtonCenter,
  toolExecutionEvidence
} from './multi-agent-smoke-evidence.mjs';

const f16ExternalReturns = ['QQ 邮箱', '瑞幸咖啡', '滴滴出行'].map((app) => ({
  app,
  opened: true,
  returned: true
}));

test('keeps F16 provider timeout as truthful usable UI evidence but BLOCKED overall', () => {
  const evidence = composioAuthEvidence({
    textValues: ['应用授权', '当前用户', '刷新', '2300028', 'Operation timeout'],
    externalAuthJumps: f16ExternalReturns
  });
  assert.equal(evidence.uiOk, true);
  assert.equal(evidence.providerOk, false);
  assert.equal(evidence.status, 'BLOCKED');
});

test('requires strict F16 provider cards and rejects ambiguous, leaked, and incomplete evidence', () => {
  const connected = {
    textValues: ['应用授权', '当前用户', '刷新', 'GitHub', '已连接', 'Composio · GitHub', '授权'],
    externalAuthJumps: f16ExternalReturns
  };
  assert.deepEqual(composioAuthEvidence(connected), {
    uiOk: true,
    providerOk: true,
    status: 'PASS'
  });
  [
    { ...connected, textValues: ['应用授权', '当前用户', '刷新'] },
    { ...connected, textValues: [...connected.textValues, 'auth_config'] },
    { ...connected, textValues: [...connected.textValues, 'provider rejected auth_config'] },
    { ...connected, textValues: [...connected.textValues, 'auth_config_github'] },
    { ...connected, textValues: [...connected.textValues, 'provider rejected auth_config_github'] },
    { ...connected, externalAuthJumps: f16ExternalReturns.map((jump, index) =>
      index === 0 ? { ...jump, returned: false } : jump) }
  ].forEach((input) => assert.equal(composioAuthEvidence(input).status, 'FAIL'));
});

test('returns from each F16 external authorization page with bounded Back navigation', () => {
  const source = readFileSync('scripts/aiphone-device-smoke.mjs', 'utf8');
  const authSmoke = source.slice(source.indexOf('async function runComposioAuthSmoke'), source.indexOf('console.log(`cleanData:'));
  const externalCollection = authSmoke.slice(authSmoke.indexOf('await collectExternalAuthJumps'), authSmoke.indexOf("const screenPath = captureScreen"));
  assert.match(externalCollection, /keyEvent', 'Back'/);
  assert.match(externalCollection, /shouldRetryHotelReturnToApp\(restoredForeground\.bundleName, backPressCount\)/);
  assert.doesNotMatch(externalCollection, /force-stop', 'com\.huawei\.hmos\.browser/);
  assert.doesNotMatch(externalCollection, /aa', 'start', '-a', 'EntryAbility', '-b', 'com\.example\.aiphonedemo/);
});

test('holds ordinary C20 multi-agent capture until its bounded settlement window', () => {
  assert.equal(typeof smokeLifecycle.multiAgentPostCompletionWaitMs, 'function');
  assert.equal(typeof smokeLifecycle.captureCompletionSettled, 'function');
  const waitMs = smokeLifecycle.multiAgentPostCompletionWaitMs('C20');
  assert.equal(waitMs, 3000);
  assert.equal(smokeLifecycle.multiAgentPostCompletionWaitMs('C19'), 0);
  assert.equal(smokeLifecycle.captureCompletionSettled({
    done: true,
    doneAt: 100,
    now: 100 + waitMs - 1,
    lifecycleOptions: { postCompletionWaitMs: waitMs },
    customCompletion: null
  }), false);
  assert.equal(smokeLifecycle.captureCompletionSettled({
    done: true,
    doneAt: 100,
    now: 100 + waitMs,
    lifecycleOptions: { postCompletionWaitMs: waitMs },
    customCompletion: null
  }), true);
});

test('requires correlated provider-backed dynamic discovery and keeps local manifest evidence', () => {
  assert.equal(typeof smokeLifecycle.dynamicToolDiscoveryEvidence, 'function');
  const remote = [
    '[AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input1',
    '[AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=d1 round=1 tool=dynamic.search predecessor=none path=none target=none binding=false',
    '[AIPhone][DynamicToolDiscovery] conversation=c1 turn=t1 task=d1 selectedToolId=dynamic.search provider=composio qualifiedName=googledocs_search_documents status=empty source=true auth=false receipt=absent',
    '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=d1 tool=dynamic.search status=empty sources=1 error=false',
    '[AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=u1 dataTasks=d1',
    '[AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=u1 surface=loop_surface_1 state=result',
    '[AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input1 status=empty surface=loop_surface_1 roundCount=1 messageChars=4'
  ].join('\n');
  const remoteEvidence = smokeLifecycle.dynamicToolDiscoveryEvidence(remote, {
    expectedSelectedToolId: 'dynamic.search',
    expectedProvider: 'composio',
    expectedQualifiedName: 'googledocs_search_documents'
  });
  assert.equal(remoteEvidence.ok, true);
  assert.equal(remoteEvidence.qualifiedName, 'googledocs_search_documents');
  assert.equal(remoteEvidence.status, 'empty');

  const local = remote
    .replace('selectedToolId=dynamic.search provider=composio qualifiedName=googledocs_search_documents',
      'selectedToolId=weather.query provider=amap qualifiedName=weather.query')
    .replace('status=empty source=true auth=false receipt=absent',
      'status=success source=true auth=false receipt=matched')
    .replaceAll('status=empty', 'status=success');
  assert.equal(smokeLifecycle.dynamicToolDiscoveryEvidence(local, {
    expectedSelectedToolId: 'weather.query',
    expectedQualifiedName: 'weather.query'
  }).ok, true);
});

test('requires case-specific qualified names and rejects prompt UI stale source-less and receipt mismatch evidence', () => {
  assert.equal(typeof smokeLifecycle.dynamicToolDiscoveryEvidence, 'function');
  const exact = [
    '[AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input1',
    '[AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=d1 round=1 tool=dynamic.search predecessor=none path=none target=none binding=false',
    '[AIPhone][DynamicToolDiscovery] conversation=c1 turn=t1 task=d1 selectedToolId=dynamic.search provider=composio qualifiedName=googledocs_search_documents status=empty source=true auth=false receipt=absent',
    '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=d1 tool=dynamic.search status=empty sources=1 error=false',
    '[AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=u1 dataTasks=d1',
    '[AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=u1 surface=loop_surface_1 state=result',
    '[AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input1 status=empty surface=loop_surface_1 roundCount=1 messageChars=4'
  ].join('\n');
  const options = {
    expectedSelectedToolId: 'dynamic.search',
    expectedProvider: 'composio',
    expectedQualifiedName: 'googledocs_search_documents'
  };
  [
    exact.replace('[AIPhone][DynamicToolDiscovery]', '[AIPhone][PromptCopy]'),
    exact.replace('conversation=c1 turn=t1 task=d1 selectedToolId=', 'conversation=c1 turn=old task=d1 selectedToolId='),
    exact.replace('provider=composio', 'provider=github'),
    exact.replace('qualifiedName=googledocs_search_documents', 'qualifiedName=invalid'),
    exact.replace('source=true', 'source=false'),
    exact.replace('receipt=absent', 'receipt=mismatch'),
    exact.replace('status=empty source=true', 'status=success source=true')
  ].forEach((logs) => {
    assert.equal(smokeLifecycle.dynamicToolDiscoveryEvidence(logs, options).ok, false);
  });
  assert.equal(smokeLifecycle.dynamicToolDiscoveryEvidence(
    '[AIPhone][HtmlHomeDocument] text=dynamic.search provider=composio qualifiedName=googledocs_search_documents',
    options
  ).ok, false);
});

test('accepts only the exact F13 F14 F15 provider tool or a correlated auth state', () => {
  const lifecycle = (qualifiedName, status = 'empty', auth = false) => [
    '[AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input1',
    '[AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=d1 round=1 tool=dynamic.search predecessor=none path=none target=none binding=false',
    `[AIPhone][DynamicToolDiscovery] conversation=c1 turn=t1 task=d1 selectedToolId=dynamic.search provider=composio qualifiedName=${qualifiedName} status=${status} source=true auth=${auth} receipt=absent`,
    `[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=d1 tool=dynamic.search status=${status} sources=1 error=${status === 'error'}`,
    '[AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=u1 dataTasks=d1',
    '[AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=u1 surface=loop_surface_1 state=result',
    `[AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input1 status=${status} surface=loop_surface_1 roundCount=1 messageChars=4`
  ].join('\n');
  const cases = [
    ['github_find_pull_requests', 'github_find_pull_requests'],
    ['googledrive_find_file', 'googledrive_find_file'],
    ['googledocs_search_documents', 'googledocs_search_documents']
  ];
  for (const [qualifiedName, expectedQualifiedName] of cases) {
    const evidence = smokeLifecycle.dynamicToolDiscoveryEvidence(lifecycle(qualifiedName), {
      expectedSelectedToolId: 'dynamic.search',
      expectedProvider: 'composio',
      expectedQualifiedName
    });
    assert.equal(evidence.ok, true);
    assert.equal(smokeLifecycle.dynamicToolDiscoveryEvidence(lifecycle('dynamic.search'), {
      expectedSelectedToolId: 'dynamic.search',
      expectedProvider: 'composio',
      expectedQualifiedName
    }).ok, false);
  }
  const authEvidence = smokeLifecycle.dynamicToolDiscoveryEvidence(
    lifecycle('dynamic.search', 'error', true),
    {
      expectedSelectedToolId: 'dynamic.search',
      expectedProvider: 'composio',
      expectedQualifiedName: 'googledocs_search_documents'
    }
  );
  assert.equal(authEvidence.ok, true);
  assert.equal(authEvidence.auth, true);
  assert.equal(smokeLifecycle.dynamicToolDiscoveryEvidence(
    lifecycle('dynamic.search', 'empty', false),
    {
      expectedSelectedToolId: 'dynamic.search',
      expectedProvider: 'composio',
      expectedQualifiedName: 'googledocs_search_documents'
    }
  ).ok, false);
});

test('deduplicates a real dual-channel DynamicToolDiscovery marker pair', () => {
  const paired = [
    '07-24 09:41:13.001 4821 4821 I A00000/AIPhone: [AIPhone][DynamicToolDiscovery] conversation=c1 turn=t1 task=d1 selectedToolId=dynamic.search provider=composio qualifiedName=googledocs_search_documents status=success source=true auth=false receipt=matched',
    '07-24 09:41:13.001 4821 4821 I A03D00/JSAPP: [AIPhone][DynamicToolDiscovery] conversation=c1 turn=t1 task=d1 selectedToolId=dynamic.search provider=composio qualifiedName=googledocs_search_documents status=success source=true auth=false receipt=matched'
  ].join('\n');
  const records = smokeLifecycle.multiAgentEvidenceRecords(paired)
    .filter((record) => record.marker === 'DynamicToolDiscovery');
  assert.equal(records.length, 1);
});

test('accepts C19 writes only from a correlated provider result and rejects invalid surfaces or forged IDs', () => {
  const action = {
    ok: true, actionId: 'calendar.event.update', conversationId: 'c19', turnId: 'page-turn-7',
    surfaceId: 'calendar-review:1', resultIndex: 8
  };
  const good = [
    '[AIPhone][MultiAgentActionRun] conversation=c19 turn=page-turn-7 task=a surface=calendar-review:1 plan=p1 run=r1 action=calendar.event.update source=calendar.events.search',
    '[AIPhone][MultiAgentActionResult] conversation=c19 turn=page-turn-7 task=a surface=calendar-review:1 plan=p1 run=r1 status=success',
    '[AIPhone][CalendarProviderAction] conversation=c19 turn=page-turn-7 surface=calendar-review:1 action=calendar.event.update event=provider-1 requested=provider-1 status=updated start=2026-07-30T16%3A00%3A00%2B08%3A00'
  ].join('\n');
  assert.equal(calendarProviderActionEvidence(good, action, { expectedTime: '16:00' }).ok, true);
  assert.equal(calendarProviderActionEvidence(good.replace('surface=calendar-review:1 action=calendar.event.update event=provider-1 requested=provider-1 status=updated start=', 'surface=invalid action=calendar.event.update event=provider-1 requested=provider-1 status=updated start='), action, { expectedTime: '16:00' }).ok, false);
  assert.equal(calendarProviderActionEvidence(good.replace('requested=provider-1', 'requested=model-forged'), action, { expectedTime: '16:00' }).ok, false);
  assert.equal(calendarProviderActionEvidence(good.replace('status=updated', 'status=error'), action, { expectedTime: '16:00' }).ok, false);
  assert.equal(calendarProviderActionEvidence(
    '[AIPhone][CalendarProviderAction] conversation=c19 turn=page-turn-7 surface=calendar-review:1 action=calendar.event.delete event=provider-1 requested=model-forged status=deleted start=none',
    { ...action, actionId: 'calendar.event.delete' }
  ).ok, false);
});

test('requires an exact provider-correlated empty C19f search, not generic absent UI text', () => {
  const context = { conversationId: 'c19', turnId: 't-final' };
  const good = [
    '[AIPhone][MultiAgentDataTask] conversation=c19 turn=t-final task=d1 round=1 tool=calendar.events.search predecessor=none path=none target=none binding=false calendarScope=6b6f311e calendarDate=2026-07-30',
    '[AIPhone][MultiAgentDataResult] conversation=c19 turn=t-final task=d1 tool=calendar.events.search status=empty sources=1 error=false'
  ].join('\n');
  assert.equal(calendarProviderAbsenceEvidence(good, context, {
    title: 'Appless QA run-1', date: '2026-07-30'
  }).ok, true);
  assert.equal(calendarProviderAbsenceEvidence('没有找到日程', context, {
    title: 'Appless QA run-1', date: '2026-07-30'
  }).ok, false);
  assert.equal(calendarProviderAbsenceEvidence(good.replace('calendarScope=6b6f311e', 'calendarScope=other'), context, {
    title: 'Appless QA run-1', date: '2026-07-30'
  }).ok, false);
});

test('normalizes the production Chinese C19 QA date before exact provider absence correlation', () => {
  assert.equal(normalizeCalendarQaDate('2026年7月30日'), '2026-07-30');
  assert.equal(normalizeCalendarQaDate('2026-7-3'), '2026-07-03');
  assert.equal(normalizeCalendarQaDate('2026-13-30'), '');
});

test('correlates provider receipts with the formatter privacy tokens, never raw click identities', () => {
  const conversation = 'conversation-raw-1';
  const turn = 'page-turn-raw-7';
  const c = calendarEvidenceIdentityToken('c', conversation);
  const t = calendarEvidenceIdentityToken('t', turn);
  const actionLogs = [
    `[AIPhone][MultiAgentActionRun] conversation=${c} turn=${t} task=k1 surface=calendar-review:1 plan=p1 run=r1 action=calendar.event.create source=calendar.events.search`,
    `[AIPhone][MultiAgentActionResult] conversation=${c} turn=${t} task=k1 surface=calendar-review:1 plan=p1 run=r1 status=success`
  ].join('\n');
  const action = multiAgentActionEvidence(actionLogs, { expectedActionId: 'calendar.event.create', expectedVirtual: false });
  const rawProvider = actionLogs + `\n[AIPhone][CalendarProviderAction] conversation=${conversation} turn=${turn} surface=calendar-review:1 action=calendar.event.create event=provider-1 requested=none status=success start=none`;
  const tokenProvider = actionLogs + `\n[AIPhone][CalendarProviderAction] conversation=${c} turn=${t} surface=calendar-review:1 action=calendar.event.create event=provider-1 requested=none status=success start=none`;
  assert.equal(calendarProviderActionEvidence(rawProvider, action).ok, false);
  assert.equal(calendarProviderActionEvidence(tokenProvider, action).ok, true);
});

test('runs provider-backed C19 cleanup and final correlated absence after failed update or an exception', async () => {
  const calls = [];
  const run = async (kind) => {
    calls.push(kind);
    if (kind === 'delete') return { calendarDeleteAction: { ok: true }, ok: true };
    return { absenceEvidence: { ok: true }, ok: true };
  };
  const afterFailedUpdate = await smokeLifecycle.runC19CleanupFinalizer({
    cleanupRequired: true, runDelete: () => run('delete'), runAbsence: () => run('absence')
  });
  assert.deepEqual(calls, ['delete', 'absence']);
  assert.equal(afterFailedUpdate.cleanup.ok, true);
  assert.equal(afterFailedUpdate.absence.ok, true);
  calls.splice(0);
  const afterException = await smokeLifecycle.runC19CleanupFinalizer({
    cleanupRequired: true,
    runDelete: async () => { calls.push('delete'); throw new Error('update-post-create exception'); },
    runAbsence: () => run('absence')
  });
  assert.deepEqual(calls, ['delete', 'absence']);
  assert.equal(afterException.cleanup.ok, false);
  assert.equal(afterException.absence.ok, true);
});

test('stops F16 external collection after a failed return and retains failure evidence', async () => {
  assert.equal(typeof smokeLifecycle.collectExternalAuthJumps, 'function');
  const calls = [];
  const jumps = await smokeLifecycle.collectExternalAuthJumps(['QQ 邮箱', '瑞幸咖啡', '滴滴出行'], async (app) => {
    calls.push(`${app}:lookup`);
    if (app !== 'QQ 邮箱') {
      calls.push(`${app}:action`);
    }
    return {
      app,
      opened: true,
      returned: false,
      backPressCount: 3,
      returnAbilityPath: 'external-auth-1-return-ability-3.txt'
    };
  });
  assert.deepEqual(calls, ['QQ 邮箱:lookup']);
  assert.deepEqual(jumps, [{
    app: 'QQ 邮箱',
    opened: true,
    returned: false,
    backPressCount: 3,
    returnAbilityPath: 'external-auth-1-return-ability-3.txt'
  }]);
  assert.equal(composioAuthEvidence({
    textValues: ['应用授权', '当前用户', '刷新', '2300028', 'Operation timeout'],
    externalAuthJumps: jumps
  }).status, 'FAIL');
});

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

test('accepts a complete exact multi-agent tool lifecycle as execution evidence', () => {
  const evidence = toolExecutionEvidence(successTurn, {
    expectedToolIds: ['travel.search']
  });
  assert.equal(evidence.observed, true);
  assert.equal(evidence.exactMultiAgentLifecycle, true);
  assert.equal(evidence.legacyLocalToolRequest, false);
});

test('rejects incomplete failed canceled and wrong multi-agent tool lifecycles', () => {
  const invalid = [
    successTurn.replace(
      '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=travel.search status=success sources=1 error=false\n',
      ''
    ),
    successTurn.replace(
      '[AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=surface-1 state=result\n',
      ''
    ),
    successTurn.replace(
      '[AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=success surface=surface-1 roundCount=1 messageChars=12\n',
      ''
    ),
    successTurn.replace(
      'status=success surface=surface-1 roundCount=1',
      'status=error surface=surface-1 roundCount=1'
    ),
    successTurn.replace(
      'status=success surface=surface-1 roundCount=1',
      'status=canceled surface=surface-1 roundCount=1'
    )
  ];
  invalid.forEach((logs) => {
    assert.equal(toolExecutionEvidence(logs, {
      expectedToolIds: ['travel.search']
    }).observed, false);
  });
  assert.equal(toolExecutionEvidence(successTurn, {
    expectedToolIds: ['food.search']
  }).observed, false);
  assert.equal(toolExecutionEvidence(successTurn, {
    expectedToolIds: []
  }).observed, false);
});

test('uses legacy local tool evidence only when no multi-agent input exists', () => {
  const legacy =
    '[AIPhone][LocalToolRequest] endpoint=local://aiphone-tools toolId=travel.search\n';
  const evidence = toolExecutionEvidence(legacy, {
    expectedToolIds: ['travel.search']
  });
  assert.equal(evidence.observed, true);
  assert.equal(evidence.exactMultiAgentLifecycle, false);
  assert.equal(evidence.legacyLocalToolRequest, true);

  const wrongMultiAgentWithForgedLegacy = successTurn.replaceAll(
    'travel.search',
    'food.search'
  ) + legacy;
  assert.equal(toolExecutionEvidence(wrongMultiAgentWithForgedLegacy, {
    expectedToolIds: ['travel.search']
  }).observed, false);
});

function socialCard({
  source = 'Slack',
  author = 'Alice',
  composer = false,
  inputHint = '输入回复',
  reply = '回复',
  replyCount = 1,
  body = '真实消息正文',
  bounds = '[900,400][1100,500]'
} = {}) {
  const children = [
    textNode('Text', source === null ? '' : `来源 · ${source}`),
    textNode('Text', author === null ? '' : `发信人 · ${author}`),
    textNode('Text', body)
  ];
  if (composer) children.push({ attributes: { type: 'TextInput', hint: inputHint }, children: [] });
  for (let index = 0; index < replyCount; index += 1) {
    children.push({
      attributes: { type: '__Common__', clickable: 'true' },
      children: [{
        attributes: { type: 'Text', text: reply, bounds },
        children: []
      }]
    });
  }
  return {
    attributes: { type: 'Column', clickable: 'true' },
    children
  };
}

function socialLayout(cards, extra = []) {
  return {
    attributes: { type: 'root' },
    children: [textNode('Text', 'SocialHub'), ...cards, ...extra]
  };
}

test('accepts only one real-card reply composer, never matching provider body text', () => {
  assert.equal(socialDraftUiEvidence(socialLayout([
    socialCard({ composer: true })
  ])).ok, true);

  [
    '回复',
    '本地草稿预览（未发送）：\n\n我会基于这条真实消息回复：你好',
    '本地草稿预览（未发送）：无法生成草稿',
    '本地草稿预览（未发送）：加载失败',
    '本地草稿预览（未发送）：当前不可用',
    '本地草稿预览（未发送）：你好\n发送成功'
  ].forEach((text) => {
    assert.equal(socialDraftUiEvidence(text).ok, false);
  });
  assert.equal(socialDraftUiEvidence(socialLayout([
    socialCard({
      body: '本地草稿预览（未发送）：\n\n我会基于这条真实消息回复：伪造正文'
    })
  ])).ok, false);
  assert.equal(socialDraftUiEvidence(socialLayout([
    socialCard({ body: '输入回复\n回复' })
  ])).ok, false);
  assert.equal(socialDraftUiEvidence(socialLayout([
    socialCard({ composer: true, replyCount: 2 })
  ])).ok, false);
});

test('rejects unknown and cross-card SocialHub reply evidence', () => {
  [
    socialLayout([socialCard({ source: '' })]),
    socialLayout([socialCard({ source: '未知来源' })]),
    socialLayout([socialCard({ author: '' })]),
    socialLayout([socialCard({ author: 'unknown sender' })]),
    socialLayout([socialCard({ source: 'Slack', author: 'Slack', composer: true })]),
    socialLayout([socialCard({ source: 'X', author: 'X', composer: true })]),
    socialLayout([socialCard({ composer: true, inputHint: '输入内容' })]),
    socialLayout([
      socialCard(),
      socialCard({ source: null, author: null, composer: true })
    ]),
    socialLayout([
      socialCard(),
      socialCard({
        source: 'Slack',
        author: '真实成员',
        composer: true,
        reply: '回复全部'
      })
    ]),
    socialLayout([
      socialCard({ author: null, composer: true }),
      socialCard({ source: null })
    ]),
    socialLayout([{
      attributes: { type: 'Column', clickable: 'true' },
      children: [
        socialCard({ author: null, composer: true }),
        socialCard({ source: null })
      ]
    }]),
    socialLayout([socialCard({ composer: true, reply: '回复全部' })]),
    socialLayout([socialCard({ composer: true })], [textNode('Text', '已发送')])
  ].forEach((layout) => {
    assert.equal(socialDraftUiEvidence(layout).ok, false);
  });
});

test('locates only an unopened real-message reply and never the composer send control', () => {
  assert.deepEqual(socialReplyButtonCenter(socialLayout([
    socialCard({ bounds: '[900,400][1100,500]' })
  ])), { x: 1000, y: 450 });
  assert.equal(socialReplyButtonCenter(socialLayout([
    socialCard({ composer: true })
  ])), null);
  assert.equal(socialReplyButtonCenter(socialLayout([
    socialCard({ source: '未知', composer: false })
  ])), null);
  assert.equal(socialReplyButtonCenter(socialLayout([
    socialCard({ source: 'Slack', author: 'Slack' })
  ])), null);
  assert.equal(socialReplyButtonCenter(socialLayout([
    socialCard({ replyCount: 2 })
  ])), null);
  assert.equal(socialReplyButtonCenter(socialLayout([
    socialCard({ author: null }),
    socialCard({ source: null })
  ])), null);
});

const dualChannelTurn = `
07-22 09:41:13.001  4821  4821 I A00000/AIPhone: [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1
07-22 09:41:13.001  4821  4821 I A03D00/JSAPP: [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1
07-22 09:41:13.003  4821  4821 I A00000/AIPhone: [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=data-1 round=1 tool=travel.search predecessor=none path=none target=none binding=false
07-22 09:41:13.003  4821  4821 I A03D00/JSAPP: [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=data-1 round=1 tool=travel.search predecessor=none path=none target=none binding=false
07-22 09:41:13.005  4821  4821 I A00000/AIPhone: [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=data-2 round=1 tool=travel.search predecessor=none path=none target=none binding=false
07-22 09:41:13.005  4821  4821 I A03D00/JSAPP: [AIPhone][MultiAgentDataTask] conversation=c1 turn=t1 task=data-2 round=1 tool=travel.search predecessor=none path=none target=none binding=false
07-22 09:41:13.007  4821  4821 I A00000/AIPhone: [AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=ui-1 dataTasks=data-1,data-2
07-22 09:41:13.007  4821  4821 I A03D00/JSAPP: [AIPhone][MultiAgentUiTask] conversation=c1 turn=t1 task=ui-1 dataTasks=data-1,data-2
07-22 09:41:13.009  4821  4821 I A00000/AIPhone: [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=travel.search status=success sources=1 error=false
07-22 09:41:13.009  4821  4821 I A03D00/JSAPP: [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=travel.search status=success sources=1 error=false
07-22 09:41:13.011  4821  4821 I A00000/AIPhone: [AIPhone][MultiAgentTaskError] conversation=c1 turn=t1 task=data-2 code=PROVIDER_FAILED
07-22 09:41:13.011  4821  4821 I A03D00/JSAPP: [AIPhone][MultiAgentTaskError] conversation=c1 turn=t1 task=data-2 code=PROVIDER_FAILED
07-22 09:41:13.013  4821  4821 I A00000/AIPhone: [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=surface-1 state=result
07-22 09:41:13.013  4821  4821 I A03D00/JSAPP: [AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=surface-1 state=result
07-22 09:41:13.015  4821  4821 I A00000/AIPhone: [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=partial surface=surface-1 roundCount=1 messageChars=12
07-22 09:41:13.015  4821  4821 I A03D00/JSAPP: [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=partial surface=surface-1 roundCount=1 messageChars=12
`;

const cloudStreamTurn = `
07-22 18:00:05.198 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentInput] conversation=c1 turn=t2 task=k3
07-22 18:00:05.199 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][ModelRequestStart] model=qwen-max endpoint=https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions stream=true
07-22 18:00:12.700 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][ModelResponseChunk] seq=1 chars=12
07-22 18:00:12.798 44325 45467 I C015B0/com.example.aiphonedemo/NETSTACK: LogHttpInfo: {HTTP_INFO:{"response_code":200,"content_type":"text/event-stream;charset=utf-8"},TCP_INFO:{"dst_port":443}}
07-22 18:00:12.801 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t2 task=k3 status=success surface=none roundCount=1 messageChars=14
`;

function textNode(type, text) {
  return { attributes: { type, text }, children: [] };
}

function messageArticle(role, text) {
  return {
    attributes: { type: 'article', text: '' },
    children: [textNode('genericContainer', role), textNode('paragraph', text)]
  };
}

function directTextLayout(messages) {
  return {
    attributes: { type: 'root', text: '' },
    children: messages.map((message) => messageArticle(message.role, message.text))
  };
}

test('requires the current direct reply as the final semantic user-assistant pair', () => {
  const baseline = directTextLayout([]);
  const layout = directTextLayout([
    { role: 'user', text: '你好' },
    { role: 'assistant', text: '你好！有什么可以帮助你的吗？' }
  ]);
  const evidence = directTextVisibleEvidence(cloudStreamTurn, baseline, layout, '你好');
  assert.equal(evidence.ok, true);
  assert.equal(evidence.replyText, '你好！有什么可以帮助你的吗？');

  const invalidLayouts = [
    directTextLayout([
      { role: 'user', text: '旧问题' },
      { role: 'assistant', text: '你好！有什么可以帮助你的吗？' }
    ]),
    directTextLayout([
      { role: 'assistant', text: '你好！有什么可以帮助你的吗？' },
      { role: 'user', text: '你好' }
    ]),
    directTextLayout([
      { role: 'user', text: '你好' },
      { role: 'assistant', text: '旧回答' },
      { role: 'user', text: '你好' }
    ]),
    directTextLayout([{ role: 'user', text: '你好' }]),
    directTextLayout([
      { role: 'user', text: '你好' },
      { role: 'assistant', text: '长度错误' }
    ]),
    { attributes: { type: 'root', text: '你好！有什么可以帮助你的吗？' }, children: [] },
    { attributes: { type: 'root', text: '' }, children: [] }
  ];
  invalidLayouts.forEach((candidate) => {
    assert.equal(directTextVisibleEvidence(cloudStreamTurn, baseline, candidate, '你好').ok, false);
  });
});

test('requires the final semantic messages to be the exact baseline plus one new pair', () => {
  const oldPair = [
    { role: 'user', text: '你好' },
    { role: 'assistant', text: '你好！有什么可以帮助你的吗？' }
  ];
  const baseline = directTextLayout(oldPair);
  const final = directTextLayout([...oldPair, ...oldPair]);
  assert.equal(directTextVisibleEvidence(cloudStreamTurn, baseline, final, '你好').ok, true);

  assert.equal(directTextVisibleEvidence(
    cloudStreamTurn,
    baseline,
    directTextLayout(oldPair),
    '你好'
  ).ok, false);
  assert.equal(directTextVisibleEvidence(
    cloudStreamTurn,
    directTextLayout([]),
    directTextLayout([...oldPair, ...oldPair]),
    '你好'
  ).ok, false);
  assert.equal(directTextVisibleEvidence(
    cloudStreamTurn,
    baseline,
    directTextLayout([
      { role: 'user', text: '被篡改的旧问题' },
      oldPair[1],
      ...oldPair
    ]),
    '你好'
  ).ok, false);
  assert.equal(directTextVisibleEvidence(
    cloudStreamTurn,
    directTextLayout([{ role: 'user', text: '未完成的旧问题' }]),
    directTextLayout([
      { role: 'user', text: '未完成的旧问题' },
      ...oldPair
    ]),
    '你好'
  ).ok, false);
});

test('rejects non-direct, failed, synthetic, and transport-free visible replies', () => {
  const layout = directTextLayout([
    { role: 'user', text: '你好' },
    { role: 'assistant', text: '你好！有什么可以帮助你的吗？' }
  ]);
  const beforeTerminal = (line) => cloudStreamTurn.replace(
    '07-22 18:00:12.801 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentTurnResult]',
    `${line}\n07-22 18:00:12.801 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentTurnResult]`
  );
  const invalidLogs = [
    cloudStreamTurn.replace('status=success', 'status=error'),
    cloudStreamTurn.replace('surface=none', 'surface=surface-1'),
    cloudStreamTurn.replace(/[^\n]*\[AIPhone\]\[MultiAgentTurnResult\][^\n]*\n/, ''),
    cloudStreamTurn.replace(/[^\n]*\/NETSTACK:[^\n]*\n/, ''),
    beforeTerminal('07-22 18:00:12.750 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentDataTask] conversation=c1 turn=t2 task=data-1 round=1 tool=travel.search predecessor=none path=none target=none binding=false'),
    beforeTerminal('07-22 18:00:12.750 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentUiResult] conversation=c1 turn=t2 task=ui-1 surface=surface-1 state=result'),
    beforeTerminal('07-22 18:00:12.750 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentActionRun] conversation=c1 turn=t2 task=a1 surface=s1 plan=p1 run=r1 action=payment.send source=payment.send'),
    beforeTerminal('07-22 18:00:12.750 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][ToolRequestByIntent] toolId=travel.search'),
    beforeTerminal('07-22 18:00:12.750 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][SyntheticFallback] source=synthetic')
  ];
  invalidLogs.forEach((logs) => {
    assert.equal(directTextVisibleEvidence(logs, directTextLayout([]), layout, '你好').ok, false);
  });
});

test('rejects forbidden work after terminal until the next distinct input', () => {
  const baseline = directTextLayout([]);
  const layout = directTextLayout([
    { role: 'user', text: '你好' },
    { role: 'assistant', text: '你好！有什么可以帮助你的吗？' }
  ]);
  const postTerminal = [
    '[AIPhone][ToolRequestByIntent] toolId=travel.search',
    '[AIPhone][LocalToolRequest] endpoint=local://aiphone-tools toolId=travel.search',
    '[AIPhone][MultiAgentActionRun] conversation=c1 turn=t2 task=a1 surface=s1 plan=p1 run=r1 action=payment.send source=payment.send',
    '[AIPhone][SyntheticFallback] source=synthetic',
    '[AIPhone][ProviderExternalError] code=AUTH_REQUIRED',
    '[AIPhone][A2uiHomeModelException] message=failed'
  ];
  postTerminal.forEach((marker, index) => {
    const logs = cloudStreamTurn +
      `07-22 18:00:13.00${index} 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: ${marker}\n`;
    assert.equal(directTextVisibleEvidence(logs, baseline, layout, '你好').ok, false);
  });

  const nextInputThenWork = cloudStreamTurn +
    '07-22 18:00:13.010 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentInput] conversation=c1 turn=t3 task=k4\n' +
    '07-22 18:00:13.020 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][ToolRequestByIntent] toolId=travel.search\n';
  assert.equal(directTextVisibleEvidence(nextInputThenWork, baseline, layout, '你好', {
    conversationId: 'c1', turnId: 't2', expectedToolIds: []
  }).ok, true);

  const dualChannelInput = cloudStreamTurn.replace(
    '07-22 18:00:05.198 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentInput] conversation=c1 turn=t2 task=k3\n',
    '07-22 18:00:05.198 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentInput] conversation=c1 turn=t2 task=k3\n' +
    '07-22 18:00:05.198 44325 44325 I A03D00/com.example.aiphonedemo/JSAPP: [AIPhone][MultiAgentInput] conversation=c1 turn=t2 task=k3\n'
  );
  assert.equal(directTextVisibleEvidence(dualChannelInput, baseline, layout, '你好').ok, true);
});

test('accepts only a correlated app-owned cloud streaming model lifecycle', () => {
  assert.equal(modelTransportEvidence(cloudStreamTurn), true);

  const mutations = [
    cloudStreamTurn.replace('[AIPhone][ModelResponseChunk] seq=1 chars=12\n', ''),
    cloudStreamTurn.replace('[AIPhone][ModelRequestStart] model=qwen-max endpoint=https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions stream=true\n', ''),
    cloudStreamTurn.replace(
      '[AIPhone][ModelRequestStart] model=qwen-max endpoint=https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions stream=true\n' +
        '07-22 18:00:12.700 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][ModelResponseChunk] seq=1 chars=12',
      '[AIPhone][ModelResponseChunk] seq=1 chars=12\n' +
        '07-22 18:00:12.700 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][ModelRequestStart] model=qwen-max endpoint=https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions stream=true'
    ),
    cloudStreamTurn.replace(
      '07-22 18:00:12.798 44325 45467 I C015B0/com.example.aiphonedemo/NETSTACK: LogHttpInfo: {HTTP_INFO:{"response_code":200,"content_type":"text/event-stream;charset=utf-8"},TCP_INFO:{"dst_port":443}}\n',
      ''
    ) +
      '07-22 18:00:12.900 44325 45467 I C015B0/com.example.aiphonedemo/NETSTACK: LogHttpInfo: {HTTP_INFO:{"response_code":200,"content_type":"text/event-stream;charset=utf-8"},TCP_INFO:{"dst_port":443}}\n',
    cloudStreamTurn.replace(
      '44325 45467 I C015B0/com.example.aiphonedemo/NETSTACK',
      '99999 45467 I C015B0/com.example.aiphonedemo/NETSTACK'
    ),
    cloudStreamTurn.replace(
      'C015B0/com.example.aiphonedemo/NETSTACK',
      'C015B0/com.example.other/NETSTACK'
    ),
    cloudStreamTurn.replace(
      '"content_type":"text/event-stream;charset=utf-8"',
      '"content_type":"application/json"'
    ),
    cloudStreamTurn.replace('status=success', 'status=error')
  ];
  mutations.forEach((logs) => assert.equal(modelTransportEvidence(logs), false));
});

test('does not treat an arbitrary app 443 response as streamed model evidence', () => {
  const providerResponse = cloudStreamTurn.replace(
    'LogHttpInfo: {HTTP_INFO:{"response_code":200,"content_type":"text/event-stream;charset=utf-8"},TCP_INFO:{"dst_port":443}}',
    'LogHttpInfo: {HTTP_INFO:{"response_code":200,"content_type":"application/json"},TCP_INFO:{"dst_port":443}}'
  );
  assert.equal(modelTransportEvidence(providerResponse), false);
});

test('does not reuse a provider streaming response after tool planning', () => {
  const providerStream = `
07-22 18:00:05.198 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentInput] conversation=c1 turn=t2 task=k3
07-22 18:00:05.199 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][ModelRequestStart] model=qwen-max endpoint=https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions stream=true
07-22 18:00:06.000 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][ModelResponseChunk] seq=1 chars=12
07-22 18:00:06.100 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentDataTask] conversation=c1 turn=t2 task=data-1 round=1 tool=travel.search predecessor=none path=none target=none binding=false
07-22 18:00:06.101 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentUiTask] conversation=c1 turn=t2 task=ui-1 dataTasks=data-1
07-22 18:00:07.000 44325 45467 I C015B0/com.example.aiphonedemo/NETSTACK: LogHttpInfo: {HTTP_INFO:{"response_code":200,"content_type":"text/event-stream;charset=utf-8"},TCP_INFO:{"dst_port":443}}
07-22 18:00:07.100 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentDataResult] conversation=c1 turn=t2 task=data-1 tool=travel.search status=success sources=1 error=false
07-22 18:00:07.200 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentUiResult] conversation=c1 turn=t2 task=ui-1 surface=surface-1 state=result
07-22 18:00:07.300 44325 44325 I A00000/com.example.aiphonedemo/AIPhone: [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t2 task=k3 status=success surface=surface-1 roundCount=1 messageChars=14
`;
  assert.equal(modelTransportEvidence(providerStream), false);
});

test('preserves explicit model responses and local 11434 transport evidence', () => {
  assert.equal(modelTransportEvidence('[AIPhone][ModelStreamResponse] code=200'), true);
  assert.equal(modelTransportEvidence('[AIPhone][ModelRawResponse] code=200'), true);
  assert.equal(modelTransportEvidence(
    'NETSTACK {"response_code":200,"dst_port":11434}'
  ), true);
});

test('requires one strictly correlated successful multi-agent turn', () => {
  const evidence = multiAgentTurnEvidence(successTurn, {
    expectedToolIds: ['travel.search']
  });
  assert.equal(evidence.complete, true);
  assert.equal(evidence.ok, true);
  assert.equal(evidence.status, 'success');
  assert.deepEqual(evidence.toolIds, ['travel.search']);
  const earlyUi = successTurn
    .replace('[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=travel.search status=success sources=1 error=false\n', '')
    .replace('[AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=surface-1 state=result',
      '[AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=ui-1 surface=surface-1 state=result\n' +
      '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=travel.search status=success sources=1 error=false');
  assert.equal(multiAgentTurnEvidence(earlyUi, {
    expectedToolIds: ['travel.search']
  }).complete, false);
});

test('collapses adjacent identical lifecycle copies from the two HiLog channels', () => {
  const evidence = multiAgentTurnEvidence(dualChannelTurn, {
    expectedToolIds: ['travel.search', 'travel.search']
  });
  assert.equal(evidence.complete, true);
  assert.equal(evidence.status, 'partial');
  assert.deepEqual(evidence.toolIds, ['travel.search', 'travel.search']);
  assert.deepEqual(evidence.failures, []);
});

test('collapses adjacent identical lifecycle copies one millisecond apart across HiLog channels', () => {
  const oneMillisecondApart = dualChannelTurn.replace(
    '07-22 09:41:13.009  4821  4821 I A03D00/JSAPP:',
    '07-22 09:41:13.010  4821  4821 I A03D00/JSAPP:'
  );
  const evidence = multiAgentTurnEvidence(oneMillisecondApart, {
    expectedToolIds: ['travel.search', 'travel.search']
  });
  assert.equal(evidence.complete, true);
  assert.equal(evidence.status, 'partial');
  assert.deepEqual(evidence.toolIds, ['travel.search', 'travel.search']);
});

test('collapses a dual-channel lifecycle pair across intervening NETSTACK noise', () => {
  const withNetstackBetweenChannels = dualChannelTurn.replace(
    '07-22 09:41:13.009  4821  4821 I A03D00/JSAPP: [AIPhone][MultiAgentDataResult]',
    '07-22 09:41:13.009  4821  4899 I C015B0/com.example.aiphonedemo/NETSTACK: ' +
      'taskid=7 RespCode:200\n' +
      '07-22 09:41:13.010  4821  4821 I A03D00/JSAPP: [AIPhone][MultiAgentDataResult]'
  );
  const evidence = multiAgentTurnEvidence(withNetstackBetweenChannels, {
    expectedToolIds: ['travel.search', 'travel.search']
  });

  assert.equal(evidence.complete, true);
  assert.equal(evidence.status, 'partial');
  assert.deepEqual(evidence.toolIds, ['travel.search', 'travel.search']);
});

test('preserves a second real emission after each dual-channel pair is collapsed once', () => {
  const originalPair =
    '07-22 09:41:13.009  4821  4821 I A00000/AIPhone: ' +
      '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 ' +
      'tool=travel.search status=success sources=1 error=false\n' +
    '07-22 09:41:13.009  4821  4821 I A03D00/JSAPP: ' +
      '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 ' +
      'tool=travel.search status=success sources=1 error=false';
  const secondRealPair =
    '07-22 09:41:13.010  4821  4821 I A00000/AIPhone: ' +
      '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 ' +
      'tool=travel.search status=success sources=1 error=false\n' +
    '07-22 09:41:13.010  4821  4821 I A03D00/JSAPP: ' +
      '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 ' +
      'tool=travel.search status=success sources=1 error=false';
  const evidence = multiAgentTurnEvidence(
    dualChannelTurn.replace(originalPair, originalPair + '\n' + secondRealPair),
    { expectedToolIds: ['travel.search', 'travel.search'] }
  );

  assert.equal(evidence.complete, false);
  assert.ok(evidence.failures.includes('missing_or_duplicate_data_terminal'));
});

test('consumes an A00000 lifecycle record only once for an A00000 A03D00 A03D00 triplet', () => {
  const original =
    '07-22 09:41:13.009  4821  4821 I A00000/AIPhone: ' +
      '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 ' +
      'tool=travel.search status=success sources=1 error=false\n' +
    '07-22 09:41:13.009  4821  4821 I A03D00/JSAPP: ' +
      '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 ' +
      'tool=travel.search status=success sources=1 error=false';
  const third =
    '07-22 09:41:13.010  4821  4821 I A03D00/JSAPP: ' +
      '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 ' +
      'tool=travel.search status=success sources=1 error=false';
  const evidence = multiAgentTurnEvidence(
    dualChannelTurn.replace(original, original + '\n' + third),
    { expectedToolIds: ['travel.search', 'travel.search'] }
  );

  assert.equal(evidence.complete, false);
  assert.ok(evidence.failures.includes('missing_or_duplicate_data_terminal'));
});

test('consumes an A03D00 lifecycle record only once for an A03D00 A00000 A00000 triplet', () => {
  const original =
    '07-22 09:41:13.009  4821  4821 I A00000/AIPhone: ' +
      '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 ' +
      'tool=travel.search status=success sources=1 error=false\n' +
    '07-22 09:41:13.009  4821  4821 I A03D00/JSAPP: ' +
      '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 ' +
      'tool=travel.search status=success sources=1 error=false';
  const reverseTriplet =
    '07-22 09:41:13.009  4821  4821 I A03D00/JSAPP: ' +
      '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 ' +
      'tool=travel.search status=success sources=1 error=false\n' +
    '07-22 09:41:13.009  4821  4821 I A00000/AIPhone: ' +
      '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 ' +
      'tool=travel.search status=success sources=1 error=false\n' +
    '07-22 09:41:13.010  4821  4821 I A00000/AIPhone: ' +
      '[AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 ' +
      'tool=travel.search status=success sources=1 error=false';
  const evidence = multiAgentTurnEvidence(
    dualChannelTurn.replace(original, reverseTriplet),
    { expectedToolIds: ['travel.search', 'travel.search'] }
  );

  assert.equal(evidence.complete, false);
  assert.ok(evidence.failures.includes('missing_or_duplicate_data_terminal'));
});

test('preserves opposite-channel lifecycle events separated by more than one millisecond', () => {
  const laterTimestamp = dualChannelTurn.replace(
    '07-22 09:41:13.009  4821  4821 I A03D00/JSAPP:',
    '07-22 09:41:13.020  4821  4821 I A03D00/JSAPP:'
  );
  const evidence = multiAgentTurnEvidence(laterTimestamp, {
    expectedToolIds: ['travel.search', 'travel.search']
  });
  assert.equal(evidence.complete, false);
  assert.ok(evidence.failures.includes('missing_or_duplicate_data_terminal'));
});

test('preserves adjacent opposite-channel lifecycle events with different normalized content', () => {
  const differentContent = dualChannelTurn.replace(
    'A03D00/JSAPP: [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=travel.search status=success sources=1 error=false',
    'A03D00/JSAPP: [AIPhone][MultiAgentDataResult] conversation=c1 turn=t1 task=data-1 tool=travel.search status=success sources=2 error=false'
  );
  const evidence = multiAgentTurnEvidence(differentContent, {
    expectedToolIds: ['travel.search', 'travel.search']
  });
  assert.equal(evidence.complete, false);
  assert.ok(evidence.failures.includes('missing_or_duplicate_data_terminal'));
});

test('preserves same-channel and later repeated lifecycle events', () => {
  const sameChannel = dualChannelTurn.replaceAll('A03D00/JSAPP', 'A00000/AIPhone');
  const sameChannelEvidence = multiAgentTurnEvidence(sameChannel, {
    expectedToolIds: ['travel.search', 'travel.search']
  });
  assert.equal(sameChannelEvidence.complete, false);
  assert.ok(sameChannelEvidence.failures.includes('late_same_turn_marker'));
  assert.deepEqual(sameChannelEvidence.toolIds, [
    'travel.search', 'travel.search', 'travel.search', 'travel.search'
  ]);

  const laterCopy = dualChannelTurn.replace(
    '07-22 09:41:13.011  4821  4821 I A03D00/JSAPP:',
    '07-22 09:41:13.011  4821  4821 I A00000/AIPhone: [AIPhone][ModelStreamResponse] code=200\n' +
      '07-22 09:41:13.011  4821  4821 I A03D00/JSAPP:'
  );
  const laterCopyEvidence = multiAgentTurnEvidence(laterCopy, {
    expectedToolIds: ['travel.search', 'travel.search']
  });
  assert.equal(laterCopyEvidence.complete, false);
  assert.ok(laterCopyEvidence.failures.includes('missing_or_duplicate_data_terminal'));
});

test('extracts only the latest exact generated UI result surface', () => {
  const logs = [
    '[AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=k1 surface=s6 state=result',
    '[AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=k2 surface=loop_surface_1784700000000 state=result',
    '[AIPhone][MultiAgentUiResult] conversation=c1 turn=t2 task=k3 surface=loop_surface_1784700000001 state=result',
    '[AIPhone][MultiAgentUiResult] conversation=c1 turn=t1 task=k4 surface=loop_surface_1784700000002_3 state=result'
  ].join('\n');
  assert.deepEqual(latestMultiAgentUiSurface(logs, {
    expectedConversationId: 'c1',
    expectedTurnId: 't1'
  }), {
    conversationId: 'c1',
    turnId: 't1',
    taskId: 'k4',
    surfaceId: 'loop_surface_1784700000002_3'
  });
  assert.equal(latestMultiAgentUiSurface(logs, {
    expectedConversationId: 'c1',
    expectedTurnId: 't1',
    afterIndex: 3
  }), null);
  assert.equal(latestMultiAgentUiSurface(logs.split('\n')[0]), null);
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

test('correlates an exact mail read action through one Data and in-place Ui terminal', () => {
  const logs = `
    [AIPhone][MultiAgentActionRun] conversation=c1 turn=page-turn-1 task=a1 surface=s1 plan=p1 run=r1 action=mail.thread.read source=mail.search provider=qq identity=qq-identity-1
    [AIPhone][MultiAgentUiTask] conversation=c1 turn=read-turn task=ui1 dataTasks=data1
    [AIPhone][MultiAgentDataTask] conversation=c1 turn=read-turn task=data1 round=1 tool=mail.thread.read predecessor=none path=none target=none binding=false provider=qq identity=qq-identity-1
    [AIPhone][MultiAgentActionResult] conversation=c1 turn=page-turn-1 task=a1 surface=s1 plan=p1 run=r1 status=success
    [AIPhone][MultiAgentDataResult] conversation=c1 turn=read-turn task=data1 tool=mail.thread.read status=success sources=1 error=false provider=qq identity=qq-identity-1
    [AIPhone][MailDetailInPlace] requestKeyChars=20 provider=qq identity=qq-identity-1 status=success bodyChars=8
    [AIPhone][MultiAgentUiResult] conversation=c1 turn=read-turn task=ui1 surface=loop_surface_1 state=result
  `;
  const exact = mailThreadReadEvidence(logs, {
    expectedActionId: 'mail.thread.read',
    expectedSourceToolId: 'mail.search',
    currentSurfaceId: 's1',
    expectedConversationId: 'c1',
    expectedTurnId: 'page-turn-1'
  });
  assert.equal(exact.complete, true);
  assert.equal(exact.ok, true);
  assert.equal(exact.dataToolId, 'mail.thread.read');
  assert.equal(exact.provider, 'qq');
  assert.equal(exact.bodyVisible, true);
  const providerErrorFirst = ['', logs].map((attempt) => mailThreadReadEvidence(attempt, {
    expectedActionId: 'mail.thread.read', expectedSourceToolId: 'mail.search',
    currentSurfaceId: 's1', expectedConversationId: 'c1', expectedTurnId: 'page-turn-1'
  }));
  assert.equal(providerErrorFirst[0].complete, false);
  assert.equal(providerErrorFirst.find((attempt) => attempt.ok)?.dataToolId, 'mail.thread.read');

  assert.equal(mailThreadReadEvidence(
    logs.replace('task=data1 tool=mail.thread.read status=success',
      'task=data1 tool=mail.thread.read status=success\n    [AIPhone][MultiAgentDataResult] conversation=c1 turn=read-turn task=data1 tool=mail.thread.read status=success sources=1 error=false'),
    {
      expectedActionId: 'mail.thread.read', expectedSourceToolId: 'mail.search',
      currentSurfaceId: 's1', expectedConversationId: 'c1', expectedTurnId: 'page-turn-1'
    }
  ).complete, false);

  assert.equal(mailThreadReadEvidence(
    logs.replace(
      'status=success sources=1 error=false provider=qq identity=qq-identity-1',
      'status=success sources=1 error=false provider=gmail identity=wrong-identity'
    ),
    {
      expectedActionId: 'mail.thread.read', expectedSourceToolId: 'mail.search',
      currentSurfaceId: 's1', expectedConversationId: 'c1', expectedTurnId: 'page-turn-1'
    }
  ).complete, false);
  assert.equal(mailThreadReadEvidence(
    logs.replace(' provider=qq identity=qq-identity-1\n    [AIPhone][MailDetailInPlace]',
      '\n    [AIPhone][MailDetailInPlace]'),
    {
      expectedActionId: 'mail.thread.read', expectedSourceToolId: 'mail.search',
      currentSurfaceId: 's1', expectedConversationId: 'c1', expectedTurnId: 'page-turn-1'
    }
  ).complete, false);
  assert.equal(mailThreadReadEvidence(
    logs.replace('surface=s1 plan=p1', 'surface=stale plan=p1'),
    {
      expectedActionId: 'mail.thread.read', expectedSourceToolId: 'mail.search',
      currentSurfaceId: 's1', expectedConversationId: 'c1', expectedTurnId: 'page-turn-1'
    }
  ).complete, false);

  const interleaved = logs.replace(
    '[AIPhone][MultiAgentUiTask] conversation=c1 turn=read-turn task=ui1 dataTasks=data1',
    '[AIPhone][MultiAgentUiTask] conversation=c1 turn=noise-turn task=noise-ui dataTasks=noise-data\n' +
      '    [AIPhone][MultiAgentDataTask] conversation=c1 turn=noise-turn task=noise-data round=1 tool=mail.thread.read predecessor=none path=none target=none binding=false provider=gmail identity=noise-identity\n' +
      '    [AIPhone][MultiAgentDataResult] conversation=c1 turn=noise-turn task=noise-data tool=mail.thread.read status=success sources=1 error=false provider=gmail identity=noise-identity\n' +
      '    [AIPhone][MultiAgentUiTask] conversation=c1 turn=read-turn task=ui1 dataTasks=data1'
  );
  assert.equal(mailThreadReadEvidence(interleaved, {
    expectedActionId: 'mail.thread.read', expectedSourceToolId: 'mail.search',
    currentSurfaceId: 's1', expectedConversationId: 'c1', expectedTurnId: 'page-turn-1'
  }).complete, true);
  assert.equal(mailThreadReadEvidence(
    logs.replace('provider=qq identity=qq-identity-1 status=success',
      'provider=qq identity=forged-identity status=success'),
    {
      expectedActionId: 'mail.thread.read', expectedSourceToolId: 'mail.search',
      currentSurfaceId: 's1', expectedConversationId: 'c1', expectedTurnId: 'page-turn-1'
    }
  ).complete, false);
});

test('does not treat the mail loading skeleton as a visible body', () => {
  assert.equal(visibleMailBodyText('发件人\n主题\n正在加载邮件正文\n回复'), false);
  assert.equal(visibleMailBodyText('Alice\nalice@example.com 发给 我\n这是供应商返回的真实完整正文\n回复'), true);
  assert.equal(visibleMailBodyText('邮件正文加载失败。\n重试'), false);
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

test('keeps filtered nonadjacent virtual ActionResult copies duplicated', () => {
  const logs = `
    07-22 09:42:00.001  4821  4821 I A00000/AIPhone: [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=a1
    07-22 09:42:00.002  4821  4821 I A00000/AIPhone: [AIPhone][MultiAgentActionPlan] conversation=c1 turn=t1 task=a1 uiTask=a1 dataTasks=none actions=payment.send virtual=true
    07-22 09:42:00.003  4821  4821 I A00000/AIPhone: [AIPhone][MultiAgentActionResult] conversation=c1 turn=t1 task=a1 surface=s1 plan=p1 run=r1 status=success
    07-22 09:42:00.003  4821  4821 I A00000/AIPhone: [AIPhone][ModelStreamResponse] code=200
    07-22 09:42:00.003  4821  4821 I A03D00/JSAPP: [AIPhone][MultiAgentActionResult] conversation=c1 turn=t1 task=a1 surface=s1 plan=p1 run=r1 status=success
    07-22 09:42:00.004  4821  4821 I A00000/AIPhone: [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=a1 status=success surface=s1 roundCount=1 messageChars=4
  `;
  const direct = multiAgentActionEvidence(logs, {
    expectedActionId: 'payment.send',
    expectedConversationId: 'c1',
    expectedTurnId: 't1',
    expectedVirtual: true
  });
  assert.equal(direct.complete, false);
  assert.deepEqual(direct.failures, ['missing_action_chain']);

  const nested = multiAgentTurnEvidence(logs, { expectedToolIds: ['payment.send'] });
  assert.equal(nested.complete, false);
  assert.ok(nested.failures.includes('missing_action_terminal'));
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

test('accepts a current-surface action run created in a new action turn', () => {
  const result = multiAgentActionEvidence(`
    [AIPhone][MultiAgentActionRun] conversation=c1 turn=t16 task=a16 surface=s1 plan=p16 run=r16 action=hotel.navigate source=hotel.search
    [AIPhone][MultiAgentActionResult] conversation=c1 turn=t16 task=a16 surface=s1 plan=p16 run=r16 status=success
  `, {
    expectedActionId: 'hotel.navigate',
    expectedSourceToolId: 'hotel.search',
    currentSurfaceId: 's1',
    expectedConversationId: 'c1'
  });
  assert.equal(result.complete, true);
  assert.equal(result.ok, true);
  assert.equal(result.turnId, 't16');
});

test('accepts the newest exact action run when stale same-action records coexist', () => {
  const result = multiAgentActionEvidence(`
    [AIPhone][MultiAgentActionRun] conversation=c1 turn=old task=a0 surface=old-surface plan=p0 run=r0 action=hotel.navigate source=hotel.search
    [AIPhone][MultiAgentActionResult] conversation=c1 turn=old task=a0 surface=old-surface plan=p0 run=r0 status=success
    [AIPhone][MultiAgentActionRun] conversation=c1 turn=t16 task=a16 surface=s1 plan=p16 run=r16 action=hotel.navigate source=hotel.search
    [AIPhone][MultiAgentActionResult] conversation=c1 turn=t16 task=a16 surface=s1 plan=p16 run=r16 status=success
  `, {
    expectedActionId: 'hotel.navigate',
    expectedSourceToolId: 'hotel.search',
    currentSurfaceId: 's1',
    expectedConversationId: 'c1'
  });
  assert.equal(result.complete, true);
  assert.equal(result.runId, 'r16');
});

test('captures hotel booking action logs around the click with the app PID', () => {
  const source = readFileSync('scripts/aiphone-device-smoke.mjs', 'utf8');
  const exactOptions = source.slice(
    source.indexOf('function exactActionOptions'),
    source.indexOf('function visibleSourceToolId')
  );
  const booking = source.slice(
    source.indexOf('async function verifyHotelBookingAction'),
    source.indexOf('async function verifyHotelDetailAction')
  );
  assert.doesNotMatch(exactOptions, /expectedTurnId/);
  assert.match(booking, /captureAppLogsFor\(appPid, async \(\) =>/);
  assert.doesNotMatch(booking, /hdc\(\['shell', 'hilog', '-x'\]\)/);
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
  const unrelatedDirect = `
    [AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=k1
    [AIPhone][MultiAgentActionPlan] conversation=c1 turn=t1 task=k1 uiTask=k1 dataTasks=none actions=payment.send virtual=true
    [AIPhone][MultiAgentActionRun] conversation=c1 turn=t1 task=k2 surface=s1 plan=p1 run=r1 action=hotel.navigate source=hotel.search
    [AIPhone][MultiAgentActionResult] conversation=c1 turn=t1 task=k2 surface=s1 plan=p1 run=r1 status=success
    [AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=k1 status=success surface=s1 roundCount=1 messageChars=4
  `;
  assert.equal(multiAgentTurnEvidence(unrelatedDirect, {
    expectedToolIds: ['payment.send']
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
  assert.deepEqual(full.find((item) => item.id === 'F12')?.expectedDependencies, [{
    toolId: 'maps.place.details',
    predecessorToolId: 'maps.place.search',
    path: '/places/0/placeId',
    target: '/placeId'
  }]);
  assert.equal(full.find((item) => item.id === 'F13')?.expectedDynamicQualifiedName,
    'github_find_pull_requests');
  assert.equal(full.find((item) => item.id === 'F14')?.expectedDynamicQualifiedName,
    'googledrive_find_file');
  assert.equal(full.find((item) => item.id === 'F15')?.expectedDynamicQualifiedName,
    'googledocs_search_documents');
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
