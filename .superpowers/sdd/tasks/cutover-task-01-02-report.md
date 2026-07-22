# Cutover Tasks 01-02 Report: Full Turn Ownership and Legacy Handoff

## Scope

- Cutover base: `51c38a6839a7ed6b14f0c04449f63b8ccfbcd55e`.
- Product baseline: `93a3bcb834f7b22d5228333557864dac56823385`.
- Product commit: `1c9353957560808e36bfa9add08228600278a554` (`feat: enforce full multi-agent turn ownership`).
- Review-fix commit: `94a8363d599e0a6687d1e4976e4a13d40eca94bb` (`fix: close runtime ownership races`).
- All 44 fixed ToolDefinition IDs are multi-agent owned from the canonical registry. There is no migration-wave allowlist or `verifiedMigrationWave` / `MIGRATED_WAVE` state.
- `dynamic.search` is a bounded read-only virtual MultiAgent Data capability in addition to the 44 fixed definitions. `memory.update` remains the existing runtime-local virtual capability. Tests use an unknown ID only when exercising the legacy handoff boundary.
- Existing UI components, renderers, provider adapters, ActionCatalog, and four-role framework were preserved. No coordinator, second framework, or second registry was added.

## Ownership Contract

- `RuntimeOwner` is exactly `multi_agent | legacy`.
- `ownershipForPlan` computes ownership from the complete requested capability set and returns a typed legacy result only when at least one requested ID is not in the registry-derived migrated set.
- The Leader evaluates ownership before normalizing inputs or publishing Data, UI, Action-plan, or Action-run work. A mixed plan therefore hands the whole turn to legacy before its otherwise-owned tasks can start.
- A valid handoff is exactly `owner=legacy`, `reason=unmigrated_tool`, and the pending Leader decision's exact ordered set of requested IDs that are absent from that turn's captured runtime-owned set. The runtime rejects malformed, missing, extra, known-owned, reordered, or case-mutated claims.
- A model/provider/planner failure, an owned capability direct-answer shortcut without observations, or an owned `legacy_handoff` decision settles as a multi-agent error. It cannot invoke legacy.
- Once Data/provider/action execution has started, a later unmigrated decision fails with `LEADER_RUNTIME_OWNERSHIP_VIOLATION`; it cannot switch runtimes mid-turn.
- Ownership is conversation-local at execution time. Concurrent runtimes independently settle one owned turn and one typed legacy handoff without sharing mutable turn state.

## Fixed Capability Execution

- `MIGRATED_TOOL_IDS` is derived from `allToolDefinitions()` plus the virtual `dynamic.search` ID and is asserted to contain 45 unique runtime-owned IDs; the fixed registry itself remains exactly 44 IDs.
- The canary planning context exposes all 44 fixed IDs and `dynamic.search` as runtime owned rather than naming a wave subset.
- The Data authorizer accepts any registered read definition with an exact output schema and exact read-only allowlist, while retaining the stricter hotel argument parser. The existing structured adapters remain the executor boundary.
- `dynamic.search` requires `required=true`, output schema `dynamicToolConnect`, and the exact singleton allowlist `[dynamic.search]`; the gateway retains the selected read slug and rejects unsafe execute operations.
- A two-tool `travel.search` plus `train.search` turn publishes two Data tasks, settles inside the multi-agent runtime, and publishes no handoff.

## Host Surface and Action Boundary

- `runtimeOwner` and `runtimeGeneration` are optional host fields on `A2uiSurfaceState`; they are not inserted into provider `dataModelJson`.
- Surface snapshots and the surface store preserve those host fields. The page rejects older generations and same-generation owner mutations.
- `Index` assigns one owner and generation to each turn, captures that generation in multi-agent, legacy-model, legacy-tool, memory, panel, and busy-state callbacks, and drops late updates from another owner or generation. Reentrant virtual callbacks resolve their generation from the originating runtime turn rather than mutable current state.
- Typed handoff switches the host owner to legacy without starting a second generation. A settled multi-agent error never enters the legacy model path.
- Registered page actions require exact equality across the current host surface and retained snapshot for `surfaceId`, owner, and runtime generation. Gmail, payment, ride, and hotel provider writes therefore reject stale or owner-mutated snapshots. Hotel navigate and booking-open actions are terminal registered candidates; hotel detail remains the only legacy-special hotel action.
- Legacy provider callbacks are generation fenced, so a late result cannot replace the current runtime surface or complete a newer turn.

## TDD Evidence

### Untouched baseline

Before production edits, the authoritative suite passed **1072/1072** on the cutover base.

### Initial RED

Tests were added first. The authoritative command failed ArkTS compilation on the intentionally absent contracts:

- `runtimeOwnerAllowsSurfaceAction`;
- `A2uiSurfaceState.runtimeOwner` and `runtimeGeneration`;
- registry-derived `MIGRATED_TOOL_IDS` and `ownershipForPlan`;
- typed handoff `owner`, `reason`, and `unmigratedToolIds` fields.

### Integrated GREEN

The first compiled integrated run registered 1079 tests and reported nine behavioral failures. They identified stale pre-cutover expectations: unowned page-action fixtures, known fixed-capability handoff assumptions, and one post-execution fixture that now used an owned mail tool. Fixtures were given the exact multi-agent owner, known-capability expectations were changed to settled errors, and the post-execution test was changed to the explicit unmigrated `dynamic.search` capability. No production ownership check was relaxed.

The initial product suite added seven regressions over the 1072-test baseline covering registry equality, exact typed handoff, mixed-plan atomicity, generic-handoff rejection, concurrent isolation, a real two-tool turn, and surface owner/generation fencing.

### Review-fix RED/GREEN

The review-fix tests first failed compilation on the absent exact host/snapshot helpers and generation-aware canary options. The first behavioral run then reported three failures covering both dynamic virtual allowlists and the stricter handoff expectation. A final reentrancy regression deliberately started host generation `202` from inside an old generation `101` memory callback; before the fix it failed with `expect 202 equals 101`. The runtime now captures host generation by originating turn, and the same complete suite passes without relaxing any ownership gate.

## Final Verification

Authoritative command:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Fresh exact-tree artifact: `entry/.test/default/intermediates/test/coverage_data/test_result.txt`, timestamp `2026-07-22T12:55:49+0800`, SHA-256 `7aa6dfa9a210f39184cb6a6c47e9bc18f3b409bf5238a112df3004fe05f0efb4`.

```text
Tests run: 1086, Failure: 0, Error: 0, Pass: 1086, Ignore: 0
```

- Full Hypium: **1086/1086 passed**, zero failures and zero errors.
- `node scripts/verify-loopy-backend.mjs`: **245 checks passed**, including a successful `agent_core` HAR build.
- `node scripts/hotel-smoke-evidence.test.mjs`: **15/15 passed**.
- Appless repository audit on this exact worktree: **44 registry tools**, **2 runtime tools**, **37 actions**, and **69 capabilities**. `missingMatrix`, `missingDocs`, `registryOnlyTools`, `modelOnlyTools`, and `excludedQueriesInSmoke` are empty; only the existing ten review-required social/work/knowledge entries remain.
- `node scripts/aiphone-device-smoke.mjs --list-cases`: passed and enumerated the deterministic cases only.
- `git diff --check` passed. Stale scans found no `verifiedMigrationWave` or `MIGRATED_WAVE`.
- Hvigor emitted the known coverage reporter `00507008` JSON parse message after Hypium completed; the fresh complete result file above is authoritative.

## Evidence Boundary

- This report claims deterministic unit/integration ownership, handoff, surface/action fencing, structural verification, capability-audit, hotel-evidence, and HAR-build evidence only.
- It does not claim a device run, installed-HAP result, connected-account success, live provider read/write, real order, real message, real calendar mutation, signed package, push, merge, or pull request.
- No device or live provider command was run. The named isolated worktree and branch were preserved without cleanup or reorganization.
