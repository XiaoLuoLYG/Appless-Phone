import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import {
  bimCleanSessionBlocker,
  bimScenarioStatus,
  hasBimDirectory,
  hasBimExecutionBar,
  hasBimHome,
  hasConversationTranscript,
  hasMainAgentResult,
  hasRememberSuggestion,
  bimSmokeStatus,
  completeBimScenarios,
  hasZeroCandidateBimRoute,
  heartCountFromLayout,
  sanitizeBimFailureReason
} from './bim-smoke-evidence.mjs';

function fixture(nodes) {
  return JSON.stringify({ nodes });
}

test('finds heart count and rejects transcript residue', () => {
  const layout = fixture([
    { text: 'Appless' },
    { accessibilityText: '打开心上事，共 1 件', text: '1' },
    { text: '心上事' },
    { text: '进行中' },
    { text: '东京旅行' },
    { text: '当前安排' }
  ]);
  assert.equal(heartCountFromLayout(layout), 1);
  assert.equal(hasBimDirectory(layout), true);
  assert.equal(hasConversationTranscript(layout), false);
});

test('requires an exact directory surface and an exact Home surface', () => {
  const home = fixture([
    { text: 'Appless' },
    { accessibilityText: '打开心上事，共 1 件' }
  ]);
  const directory = fixture([{ text: '心上事' }, { text: '进行中' }]);
  assert.equal(hasBimDirectory(home), false);
  assert.equal(hasBimDirectory(fixture([{ text: '返回心上事列表' }, { text: '当前状态' }])), false);
  assert.equal(hasBimDirectory(directory), true);
  assert.equal(hasBimHome(home), true);
  assert.equal(hasBimHome(directory), false);
});

test('detects the real HistoryPanel transcript without mistaking the app header', () => {
  assert.equal(hasConversationTranscript(fixture([{ text: 'Appless' }])), false);
  assert.equal(hasConversationTranscript(fixture([
    { text: '生成轨迹' },
    { text: '2' },
    { text: '你' },
    { text: '帮我规划东京旅行' },
    { text: 'Appless' },
    { text: '这是当前安排' }
  ])), true);
  assert.equal(hasConversationTranscript(fixture([
    { text: '生成轨迹' },
    { text: '暂无对话轨迹' }
  ])), true);
});

test('distinguishes an available remember suggestion from its saved state', () => {
  assert.equal(hasRememberSuggestion(fixture([{ text: '♡ 记在心上' }])), true);
  assert.equal(hasRememberSuggestion(fixture([{ text: '♡ 已记在心上' }])), false);
});

test('requires the detail execution bar rather than only a generic working word', () => {
  assert.equal(hasBimExecutionBar(fixture([
    { text: '正在处理' },
    { text: '正在更新心上事' },
    { text: '停止' }
  ])), true);
  assert.equal(hasBimExecutionBar(fixture([{ text: '正在处理其他请求' }])), false);
});

test('recognizes a zero-candidate BIM bypass and a real main-agent terminal result', () => {
  const logs = [
    '[AIPhone][BimRoute] routeMs=2 candidates=0 semantic=false status=none',
    '[AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=success surface=none roundCount=0 messageChars=12'
  ].join('\n');
  assert.equal(hasZeroCandidateBimRoute(logs), true);
  assert.equal(hasMainAgentResult(logs), true);
  assert.equal(hasMainAgentResult(logs.replace('messageChars=12', 'messageChars=0')), false);
});

test('keeps an earlier smoke assertion failure as FAIL when later steps are blocked', () => {
  assert.equal(bimSmokeStatus(['FAIL', 'BLOCKED']), 'FAIL');
  assert.equal(bimSmokeStatus(['BLOCKED']), 'BLOCKED');
  assert.equal(bimSmokeStatus(['PASS', 'PASS']), 'PASS');
});

test('lets a same-scenario provider blocker override stale passing UI', () => {
  assert.equal(bimScenarioStatus(true, 'model unavailable'), 'BLOCKED');
  assert.equal(bimScenarioStatus(false, 'model unavailable'), 'BLOCKED');
  assert.equal(bimScenarioStatus(false, ''), 'FAIL');
});

test('requires an explicit successful clean session before BIM smoke', () => {
  assert.match(bimCleanSessionBlocker(false, false), /explicit --clean-data/);
  assert.match(bimCleanSessionBlocker(true, false), /could not be cleaned/);
  assert.equal(bimCleanSessionBlocker(true, true), '');
});

test('sanitizes an orchestration exception and completes all six scenarios', () => {
  const raw = 'hdc failed https://example.test?a=1&api_key=secret Authorization: Bearer token123';
  const reason = sanitizeBimFailureReason(new Error(raw));
  const scenarios = completeBimScenarios([
    { id: 'suggestion', status: 'PASS', ok: true }
  ], reason, 'remember');
  assert.equal(reason.includes('secret'), false);
  assert.equal(reason.includes('token123'), false);
  assert.equal(sanitizeBimFailureReason(''), '');
  assert.equal(scenarios.length, 6);
  assert.equal(scenarios.find((scenario) => scenario.id === 'remember')?.status, 'FAIL');
  assert.equal(scenarios.find((scenario) => scenario.id === 'directory')?.status, 'BLOCKED');
});

test('lists the standalone BIM smoke case without requiring a device', () => {
  const result = spawnSync(process.execPath, [
    'scripts/aiphone-device-smoke.mjs', '--bim', '--list-cases'
  ], { cwd: process.cwd(), encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), [{
    id: 'BIM',
    mode: 'device-smoke',
    automated: true,
    requires: ['local-model', 'heart-things']
  }]);
});

test('blocks BIM smoke without explicit clean data and still writes complete evidence', () => {
  const outDir = mkdtempSync(join(tmpdir(), 'aiphone-bim-smoke-'));
  try {
    const result = spawnSync(process.execPath, [
      'scripts/aiphone-device-smoke.mjs', '--bim'
    ], {
      cwd: process.cwd(),
      encoding: 'utf8',
      env: {
        ...process.env,
        AIPHONE_SMOKE_CLEAN_DATA: '0',
        AIPHONE_SMOKE_OUT_DIR: outDir,
        AIPHONE_HDC_TARGET: ''
      }
    });
    assert.equal(result.status, 1, result.stderr);
    const summary = JSON.parse(readFileSync(join(outDir, 'bim-summary.json'), 'utf8'));
    assert.equal(summary.status, 'BLOCKED');
    assert.equal(summary.scenarios.length, 6);
    assert.match(summary.reason, /explicit --clean-data/);
    assert.match(readFileSync(join(outDir, 'screenshots-index.md'), 'utf8'), /真机场景截图索引/);
  } finally {
    rmSync(outDir, { recursive: true, force: true });
  }
});

test('captures target-discovery failure inside the six-scenario evidence envelope', () => {
  const outDir = mkdtempSync(join(tmpdir(), 'aiphone-bim-smoke-target-'));
  try {
    const result = spawnSync(process.execPath, [
      'scripts/aiphone-device-smoke.mjs', '--bim', '--clean-data'
    ], {
      cwd: process.cwd(),
      encoding: 'utf8',
      env: {
        ...process.env,
        PATH: '',
        AIPHONE_SMOKE_CLEAN_DATA: '0',
        AIPHONE_SMOKE_OUT_DIR: outDir,
        AIPHONE_HDC_TARGET: ''
      }
    });
    assert.equal(result.status, 1, result.stderr);
    const summary = JSON.parse(readFileSync(join(outDir, 'bim-summary.json'), 'utf8'));
    assert.equal(summary.status, 'FAIL');
    assert.equal(summary.scenarios.length, 6);
    assert.match(summary.reason, /hdc list targets failed/);
    assert.match(readFileSync(join(outDir, 'screenshots-index.md'), 'utf8'), /真机场景截图索引/);
  } finally {
    rmSync(outDir, { recursive: true, force: true });
  }
});
