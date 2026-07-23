# Multi-Agent Cutover and Regression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut all product turns over to the four-Agent runtime, prove every scenario and safety state, remove the legacy production runtime, and synchronize the verified shared core to Loopy.

**Architecture:** During migration, the Host performs a single pre-execution ownership decision: all planned tools are migrated or the entire turn uses legacy. After all capability/scenario gates pass, remove the allowlist and legacy runtime so every turn has one owner. Keep deterministic domain renderers as A2UI fallback; they are not legacy orchestration.

**Tech Stack:** HarmonyOS ArkTS/Hypium, existing A2UI home, `MultiAgentRuntime`, `appless-device-regression`, Hvigor/DevEco, HDC, Node static verifiers, Git-controlled Appless/Loopy `agent_core` trees.

## Global Constraints

- Execute only after both runtime-foundation and domain-migration completion gates pass.
- No same-turn mixing: whole-turn new runtime or typed pre-execution `LegacyHandoff` only.
- No fallback to legacy after any provider, system intent, Web session, or external write starts.
- Existing scene renderers remain deterministic UI fallback; only old orchestration is deleted.
- Do not weaken assertions to turn external failures green; report PASS/PARTIAL/BLOCKED honestly.
- Do not uninstall the app, clear device data, bypass signing trust, run a Mac gateway as product runtime, or guess test contacts/resources.
- Do not clean or remove worktrees, branches, local-only files, or unrelated changes.

---

### Task 1: Add whole-turn migration ownership and runtime-stamped surfaces

**Files:**
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntimeTypes.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntime.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/Index.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/A2uiTypes.ets`
- Test: `entry/src/test/MultiAgentRuntime.test.ets`
- Test: `entry/src/test/A2uiHomeState.test.ets`

**Interfaces:**
- Produces: `RuntimeOwner`, typed `LegacyHandoff`, `MIGRATED_TOOL_IDS`, and surface/action owner enforcement.
- Consumes: validated `LeaderDecision.dataTasks`, current surface snapshot, and existing `submitPrompt` legacy path.

- [ ] **Step 1: Write failing ownership tests**

```ts
const migrated = ownershipForPlan(['travel.search', 'train.search'],
  new Set<string>(['travel.search', 'train.search']));
expect(migrated.owner).assertEqual('multi_agent');

const handoff = ownershipForPlan(['travel.search', 'gmail.mail.search'],
  new Set<string>(['travel.search']));
expect(handoff.owner).assertEqual('legacy');
expect(handoff.unmigratedToolIds[0]).assertEqual('gmail.mail.search');
```

Assert no DataTask is published before ownership is decided. Stamp a new-runtime surface, then assert an old-runtime action cannot execute on it and vice versa. After a provider-start marker, assert handoff is rejected.

- [ ] **Step 2: Run Hypium and verify RED**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Expected: ownership types and checks do not exist.

- [ ] **Step 3: Implement one pre-execution decision**

```ts
export type RuntimeOwner = 'multi_agent' | 'legacy';

export interface LegacyHandoff {
  owner: 'legacy';
  unmigratedToolIds: string[];
  reason: 'unmigrated_tool';
}

export function ownershipForPlan(
  toolIds: string[], migrated: Set<string>
): { owner: RuntimeOwner; unmigratedToolIds: string[] } {
  const missing = toolIds.filter((toolId: string): boolean => !migrated.has(toolId));
  return { owner: missing.length === 0 ? 'multi_agent' : 'legacy', unmigratedToolIds: missing };
}
```

Start `MIGRATED_TOOL_IDS` with only the already verified canaries, then add IDs only in the wave commits below. Add `runtimeOwner` to the page's retained surface metadata, not to provider data. `sendAction` must dispatch to the stamped owner.

- [ ] **Step 4: Run Hypium and verify handoff races**

Expected: no mixed DataTasks, wrong-owner action, post-provider handoff, or stale surface activation; `Failure: 0, Error: 0`.

- [ ] **Step 5: Commit ownership routing**

```bash
git add entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntimeTypes.ets \
  entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntime.ets \
  entry/src/main/ets/pages/A2uiHome/Index.ets \
  agent_core/src/main/ets/aiphone/runtime/A2uiTypes.ets \
  entry/src/test/MultiAgentRuntime.test.ets entry/src/test/A2uiHomeState.test.ets
git commit -m "feat: enforce whole-turn runtime ownership"
```

### Task 2: Enable migration waves only after their contract gates

**Files:**
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntime.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/Index.ets`
- Modify: `entry/src/test/MultiAgentRuntime.test.ets`
- Modify: `entry/src/test/A2uiHomeToolRequest.test.ets`

**Interfaces:**
- Produces: complete 46-tool `MIGRATED_TOOL_IDS` after four independently testable additions.
- Consumes: completion evidence from both preceding plans.

- [ ] **Step 1: Add failing wave-ownership tests**

Use explicit expected sets in tests only:

```ts
expect(migratedToolIdsForWave(1).has('travel.search')).assertTrue();
expect(migratedToolIdsForWave(1).has('gmail.mail.search')).assertFalse();
expect(migratedToolIdsForWave(2).has('gmail.mail.search')).assertTrue();
expect(migratedToolIdsForWave(3).has('payment.send')).assertTrue();
expect(migratedToolIdsForWave(4).has('calendar.event.delete')).assertTrue();
expect(migratedToolIdsForWave(4).size).assertEqual(46);
```

Assert an input planning two tools is legacy until both are in the active wave.

- [ ] **Step 2: Run Hypium and verify RED**

Expected: only canary IDs are migrated.

- [ ] **Step 3: Add one wave at a time and run the relevant fixtures before the next**

Use the exact registry split already verified; the production set is derived from verified wave predicates, not copied prompt JSON. After each addition, run Hypium and inspect the result file before continuing:

```ts
const MIGRATED_WAVE: number = 4;

function migratedToolIds(): Set<string> {
  return new Set<string>(allToolDefinitions()
    .filter((definition: ToolDefinition): boolean =>
      verifiedMigrationWave(definition.toolId) <= MIGRATED_WAVE)
    .map((definition: ToolDefinition): string => definition.toolId));
}
```

`verifiedMigrationWave` is a temporary switch with the exact wave assignment from the approved design. It is deleted in Task 5 after full cutover.

- [ ] **Step 4: Run all Hypium tests and verifier**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
tail -5 entry/.test/default/intermediates/test/coverage_data/test_result.txt
node scripts/verify-loopy-backend.mjs
```

Expected: 46 migrated IDs, zero fixed blocked tools, Hypium zero failure/error, verifier PASS.

- [ ] **Step 5: Commit full wave enablement**

```bash
git add entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntime.ets \
  entry/src/main/ets/pages/A2uiHome/Index.ets \
  entry/src/test/MultiAgentRuntime.test.ets entry/src/test/A2uiHomeToolRequest.test.ets
git commit -m "feat: enable all multi-agent capability waves"
```

### Task 3: Update capability coverage and smoke evidence for the new lifecycle

**Files:**
- Modify: `scripts/aiphone-device-smoke.mjs`
- Modify: `scripts/hotel-smoke-evidence.mjs`
- Modify: `scripts/hotel-smoke-evidence.test.mjs`
- Modify: `docs/current-capabilities.md`
- Modify: `/Users/luoyige/.codex/skills/appless-device-regression/references/scenario-matrix.md`

**Interfaces:**
- Produces: smoke parsing for `TURN.RESULT`, multi-Agent tool lifecycle, UI offers, and updated Gmail send coverage status.
- Consumes: current PID-filtered HiLog markers, C/F/R matrix, and existing scene-specific evidence helpers.

- [ ] **Step 1: Add failing Node evidence tests**

```js
test('requires one correlated multi-agent turn result', () => {
  const evidence = multiAgentTurnEvidence(`
    [AIPhone][MultiAgentInput] conversation=c1 turn=t1
    [AIPhone][DataTaskResult] conversation=c1 turn=t1 task=d1 tool=travel.search status=success
    [AIPhone][TurnResult] conversation=c1 turn=t1 status=success surface=s1 rounds=1
  `);
  assert.equal(evidence.ok, true);
});
```

Add negative tests for wrong turn/task, missing DataResult, UI-ready without TURN.RESULT, old `LoopBackend` markers, and external error mislabeled success. Keep hotel-specific evidence intact.

- [ ] **Step 2: Run Node tests and verify RED**

```bash
node --test scripts/hotel-smoke-evidence.test.mjs
```

Expected: missing generic multi-Agent evidence helper and lifecycle recognition.

- [ ] **Step 3: Parse strict new markers and update the matrix**

Add a generic parser that requires the same conversation/turn and accepts `success/partial/empty/error/canceled` without rewriting status. Core/full cases must expect their exact tool IDs under the new lifecycle.

Update the coverage ledger:

```text
gmail.message.send | manual-only | current visible reply-send button; safe configured thread only
```

Keep X02 “不确认直接发送” excluded. Do not add default automated sends. Add a dedicated optional smoke case only when a safe Gmail thread/recipient environment variable is configured.

- [ ] **Step 4: Run coverage audit and case listing**

```bash
node ~/.codex/skills/appless-device-regression/scripts/audit-coverage.mjs \
  --repo /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo
node scripts/aiphone-device-smoke.mjs --list-cases
node scripts/aiphone-device-smoke.mjs --full-regression --list-cases
```

Expected: no missing matrix/docs/registry-only/model-only items; lists contain exactly C01-C20 and F01-F16 without excluded queries.

- [ ] **Step 5: Commit coverage and evidence updates**

```bash
git add scripts/aiphone-device-smoke.mjs scripts/hotel-smoke-evidence.mjs \
  scripts/hotel-smoke-evidence.test.mjs docs/current-capabilities.md
git commit -m "test: cover multi-agent scenario lifecycle"
```

The skill matrix lives outside the repository. Keep its reviewed edit in place as local skill configuration and report it separately; do not copy it into the product repository or attempt to stage it from this repository.

### Task 4: Run and review Core, Full, review-required, and manual safety gates

**Files:**
- Evidence output: `tool-gateway/.smoke/**` (never commit)

**Interfaces:**
- Produces: one reviewed status row for C01-C20, F01-F16, R01-R04, and manual-only capability classes.
- Consumes: exact current HAP, provider configuration, scenario matrix, and device runtime.

- [ ] **Step 1: Run authoritative host gates before device work**

```bash
node scripts/sync-provider-config.mjs
node scripts/verify-loopy-backend.mjs
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
tail -5 entry/.test/default/intermediates/test/coverage_data/test_result.txt
```

Expected: verifier PASS and `Failure: 0, Error: 0`. Record coverage reporter noise separately.

- [ ] **Step 2: Build and install one exact-HEAD signed HAP**

Use the repository's current trusted Debug signing configuration. Verify bundle/profile/certificate/target UDID, compute SHA-256, and install without data clearing. If signing or trust fails, record BLOCKED and do not use an older HAP.

Evidence commands:

```bash
git rev-parse HEAD
shasum -a 256 entry/build/default/outputs/default/entry-default-signed.hap
hdc list targets
hdc fport ls
```

Expected: one target, correct signed HAP installed, empty `hdc fport ls`.

- [ ] **Step 3: Run Core and Full suites**

```bash
AIPHONE_HDC_TARGET=6WS0226304000257 \
AIPHONE_QUERY_TIMEOUT_MS=90000 \
AIPHONE_QUERY_RETRY_LIMIT=2 \
node scripts/aiphone-device-smoke.mjs --core-regression

AIPHONE_HDC_TARGET=6WS0226304000257 \
AIPHONE_QUERY_TIMEOUT_MS=90000 \
AIPHONE_QUERY_RETRY_LIMIT=2 \
node scripts/aiphone-device-smoke.mjs --full-regression
```

Expected: one summary per C/F ID. External provider/auth/network failures remain BLOCKED; product assertion failures remain FAIL.

- [ ] **Step 4: Run R01-R04 and manual safety checks without side effects**

Run R queries individually as positional arguments. Verify read/preview/prepare only. For Gmail send, use a configured safe thread and explicit current-surface button; for Luckin/Payment/Ride/WhatsApp/work/knowledge writes, verify confirmation/fail-closed unless the user separately authorizes a safe target. Do not execute final payment/order/publish by default.

```bash
AIPHONE_HDC_TARGET=6WS0226304000257 node scripts/aiphone-device-smoke.mjs \
  '帮我搜索 Reddit 上最近关于 Qwen 的社区讨论' \
  '帮我为 X 起草一条介绍 Appless 新版本的帖子' \
  '帮我在 Google Drive 和 Google Docs 里找 Appless 设计文档' \
  '帮我查看 GitHub、Linear、Asana 和 Trello 里的项目与任务'
```

- [ ] **Step 5: Stop on reproducible defects and open a focused TDD fix task**

For every defect, stop this cutover task and create a focused TDD task that names the failing scene, exact evidence, shared root cause, test file, production file, and rerun command. Do not weaken the scenario or parser. Resume Task 4 only after that task is reviewed and committed.

```bash
git status --short
git diff --check
```

### Task 5: Remove legacy orchestration and keyword persona routing

**Files:**
- Delete after caller proof: `agent_core/src/main/ets/aiphone/LoopBackend.ets`
- Delete after caller proof: `agent_core/src/main/ets/agent/ReActAgentRunner.ets`
- Delete after caller proof: `entry/src/main/ets/model/PersonaRouter.ets`
- Modify: `entry/src/main/ets/model/LocalModelClient.ets`
- Modify: `entry/src/main/ets/model/PersonaPrompt.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/Index.ets`
- Modify: `agent_core/Index.ets`
- Modify: `scripts/verify-loopy-backend.mjs`
- Delete/modify tests: `entry/src/test/ReActAgentRunner.test.ets`, `entry/src/test/PersonaRouter.test.ets`, `entry/src/test/List.test.ets`

**Interfaces:**
- Produces: one production runtime with renderer fallback only.
- Consumes: completed 46-tool ownership and scenario gates.

- [ ] **Step 1: Add failing static exit assertions**

Extend `verify-loopy-backend.mjs` with comment-stripped checks:

```js
assert(!productionSource.includes('new LoopBackend('), 'no production LoopBackend caller');
assert(!productionSource.includes('new ReActAgentRunner('), 'no production ReAct runner caller');
assert(!productionSource.includes('routePersonaForPrompt('), 'no keyword persona router caller');
assert(!productionSource.includes('MIGRATED_TOOL_IDS'), 'temporary migration set removed');
assert(!productionSource.includes('LegacyHandoff'), 'temporary handoff removed');
```

Add mutation fixtures proving comments cannot satisfy or defeat each assertion.

- [ ] **Step 2: Run verifier and verify RED**

```bash
node scripts/verify-loopy-backend.mjs
```

Expected: live old callers and temporary migration symbols fail the new checks.

- [ ] **Step 3: Delete only proven-dead orchestration**

First run:

```bash
rg -n 'LoopBackend|ReActAgentRunner|routePersonaForPrompt|MIGRATED_TOOL_IDS|LegacyHandoff' \
  agent_core entry/src/main/ets scripts
```

Replace `LocalModelClient.callLocalModel` with the `MultiAgentRuntime` call already used by the page; retain only shared settings/model utilities that have live callers. Remove keyword persona routing; Leader output supplies persona runtime data. Remove allowlist/handoff and send every input through the new runtime. Delete old tests with the dead classes; keep ConversationContext, LocalModel, provider adapters, renderers, ActionCatalog, and all current UI components.

- [ ] **Step 4: Run complete static and Hypium gates**

```bash
node scripts/verify-loopy-backend.mjs
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
tail -5 entry/.test/default/intermediates/test/coverage_data/test_result.txt
rg -n 'LoopBackend|ReActAgentRunner|routePersonaForPrompt|MIGRATED_TOOL_IDS|LegacyHandoff' \
  agent_core entry/src/main/ets scripts
```

Expected: verifier PASS, Hypium zero failure/error, final `rg` has no production matches.

- [ ] **Step 5: Commit legacy removal**

```bash
git add agent_core/Index.ets \
  entry/src/main/ets/model/LocalModelClient.ets \
  entry/src/main/ets/model/PersonaPrompt.ets \
  entry/src/main/ets/pages/A2uiHome/Index.ets \
  entry/src/test/List.test.ets scripts/verify-loopy-backend.mjs
git rm agent_core/src/main/ets/aiphone/LoopBackend.ets \
  agent_core/src/main/ets/agent/ReActAgentRunner.ets \
  entry/src/main/ets/model/PersonaRouter.ets \
  entry/src/test/ReActAgentRunner.test.ets entry/src/test/PersonaRouter.test.ets
git commit -m "refactor: remove legacy agent runtime"
```

Before committing, inspect `git diff --cached --name-status` and unstage any unrelated working-tree file.

### Task 6: Synchronize verified agent_core to Loopy without cleaning either repository

**Files:**
- Modify: `/Users/luoyige/DevEcoStudioProjects/loopy/harmony/agent_core/**` to match Appless tracked `agent_core/**`
- Modify only required Loopy consumers: `/Users/luoyige/DevEcoStudioProjects/loopy/harmony/entry/src/main/ets/**`
- Modify: `/Users/luoyige/DevEcoStudioProjects/loopy/harmony/scripts/verify-aiphone-backend.mjs`

**Interfaces:**
- Produces: path- and SHA-256-identical tracked `agent_core` trees and a compiling Loopy consumer.
- Consumes: exact verified Appless commit from Task 5.

- [ ] **Step 1: Record both repository states without cleanup**

```bash
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo status --short --branch
git -C /Users/luoyige/DevEcoStudioProjects/loopy status --short --branch
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo worktree list
git -C /Users/luoyige/DevEcoStudioProjects/loopy worktree list
```

Expected: note every pre-existing change. Do not remove or reorganize any worktree.

- [ ] **Step 2: Copy only tracked agent_core files from the verified commit**

Use the committed tree, not build output or the dirty working tree:

```bash
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo archive HEAD agent_core | \
  tar -x -C /Users/luoyige/DevEcoStudioProjects/loopy/harmony
```

For files intentionally deleted from Appless but still tracked in Loopy, remove those exact reviewed paths with patches. Do not use `rsync --delete` or broad cleanup.

- [ ] **Step 3: Update only real Loopy compile callers**

```bash
rg -n 'LoopBackend|ReActAgentRunner|routePersonaForPrompt|LeaderAgent|DataAgent|UiAgent|ActionAgent' \
  /Users/luoyige/DevEcoStudioProjects/loopy/harmony/entry \
  /Users/luoyige/DevEcoStudioProjects/loopy/harmony/agent_core/Index.ets
```

Change imports/signatures only where the new public API requires it. Do not add a compatibility runtime or fake provider demo.

- [ ] **Step 4: Verify both consumers and SHA parity**

```bash
node /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo/scripts/verify-loopy-backend.mjs
node /Users/luoyige/DevEcoStudioProjects/loopy/harmony/scripts/verify-aiphone-backend.mjs
(cd /Users/luoyige/DevEcoStudioProjects/loopy/harmony && \
  DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
    --mode module -p module=entry@default -p product=default assembleHap --no-daemon)
```

Run a Node SHA-256 comparison over tracked `agent_core` paths from both repositories, excluding `build`, `.test`, `oh_modules`, and generated outputs. Expected: missing paths `[]`, extra paths `[]`, mismatches `[]`.

- [ ] **Step 5: Commit Loopy synchronization separately**

```bash
git -C /Users/luoyige/DevEcoStudioProjects/loopy add \
  harmony/agent_core harmony/entry/src/main/ets harmony/scripts
git -C /Users/luoyige/DevEcoStudioProjects/loopy commit -m "feat: converge on full multi-agent runtime"
```

Do not push, merge, retarget PRs, or delete branches unless the user separately requests those state changes.

### Task 7: Final exact-HEAD verification and handoff

**Files:**
- No product edits unless a new failing test proves a defect.
- Evidence: local smoke output only; do not commit.

**Interfaces:**
- Produces: final implementation report with architecture, commits, scenario statuses, HAP identity, device evidence, Loopy parity, and unresolved blockers.

- [ ] **Step 1: Run fresh host verification on final HEAD**

```bash
git status --short --branch
git rev-parse HEAD
node scripts/verify-loopy-backend.mjs
node ~/.codex/skills/appless-device-regression/scripts/audit-coverage.mjs \
  --repo /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
tail -5 entry/.test/default/intermediates/test/coverage_data/test_result.txt
```

- [ ] **Step 2: Rebuild/reinstall final HAP and rerun changed scenarios**

Use the same trusted signing process and target. Rerun at minimum C01, C04, C06, C11, C13, C19, C20, one independent two-tool request, and one dependent two-round request. Re-run the full suite if any production file changed after Task 4.

- [ ] **Step 3: Verify phone independence and no unsafe residue**

```bash
hdc fport ls
hdc shell bm dump -n com.example.aiphonedemo
```

Expected: no port forwards; correct installed bundle/profile/version; no QA Calendar item, unsent draft side effect, order, payment, ride, or test message residue.

- [ ] **Step 4: Verify repository state and shared-core parity**

```bash
git status --short --branch
git -C /Users/luoyige/DevEcoStudioProjects/loopy status --short --branch
git worktree list
git -C /Users/luoyige/DevEcoStudioProjects/loopy worktree list
```

Expected: only known pre-existing local changes remain; no worktree was cleaned or removed; controlled `agent_core` hash comparison is still zero-difference.

- [ ] **Step 5: Produce the final report**

Report:

```text
Architecture: Leader/Data/UI/Action ownership and prompt boundaries
Registry: fixed=46, Data=25, Action=21, virtual=2, blocked=0
Tests: authoritative Hypium totals and verifier totals
Scenes: C01-C20, F01-F16, R01-R04 one row each
Manual safety: Gmail send and all other side-effect states
Device: target, exact HEAD, HAP SHA-256, fport state
Parity: Appless/Loopy paths and SHA mismatch count
Remaining: explicit FAIL/PARTIAL/BLOCKED with evidence
```

Do not claim full migration complete while any capability lacks a new owner, any production legacy caller remains, or final device evidence is blocked.

## Cutover Completion Gate

- Every user input and business action has exactly one runtime owner.
- All fixed/virtual capabilities are owned and covered; C/F/R/manual results are recorded honestly.
- Old `LoopBackend`, `ReActAgentRunner`, keyword `PersonaRouter`, migration allowlist, and handoff code have no production callers and are removed.
- Deterministic domain renderers remain only as A2UI fallback.
- Appless and Loopy controlled `agent_core` trees are byte-identical.
- Exact final HEAD has authoritative Hypium and device evidence, or the release is explicitly BLOCKED rather than falsely complete.
