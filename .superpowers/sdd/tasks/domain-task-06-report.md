# Domain Task 06 Report: Registered Product Action Execution

## Scope

- Base commit: `15c49cd7215de2f03e267d2f073fd9d557b41436`.
- Target commit message: `feat: register product action execution`.
- Renamed the hotel-only registered executor and test to the product-level `AiphoneRegisteredActionExecutor` names.
- Added one narrow `RegisteredPageAction(actionId, args, context)` callback seam and wired it through `MultiAgentRuntime`, the existing canary wrapper, and `Index.ets`.
- Preserved the existing Petal Maps hotel-navigation and RollingGo in-app booking paths.
- Added explicit Wave 3 routes for `luckin.order.preview`, `social.reply.draft`, `mail.draft.create`, `gmail.draft.create`, `gmail.draft.apply`, `gmail.open.web`, `worldcup.open`, `payment.send`, `payment.account.setup`, and `maps.route.open`.
- Kept `gmail.message.send` for Task 7 and the remaining create/update/delete/send/ride writes for Task 8 fail-closed with no callback invocation.

## TDD Evidence

### Initial RED

The executor test was renamed, registered in `List.test.ets`, and expanded before the production rename. The authoritative Hypium command failed in `:entry:default@UnitTestArkTS` because `AiphoneRegisteredActionExecutor.ets` did not exist. The other reported test type errors were compiler cascades from that missing import.

The first GREEN implementation reached a complete authoritative result of 1014/1014.

### Replay-correlation RED

Self-review added `keeps distinct plan steps executable under one action run` before changing the replay key. The authoritative result then reported **1015 tests, 1 failure, 0 errors**: the second valid step returned `error` because replay protection keyed the whole run instead of the exact step.

The key now includes the complete correlation tuple: conversation, turn, surface, source tool, plan, run, and step. An exact replay is rejected before a second callback, while a different step in the same run remains executable.

### Final GREEN

Command:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Fresh authoritative `entry/.test/default/intermediates/test/coverage_data/test_result.txt` at `2026-07-22T05:11:30+0800`:

```text
Tests run: 1015, Failure: 0, Error: 0, Pass: 1015, Ignore: 0
```

The named Task 6 cases in that file pass for exact Gmail draft, payment, Maps, all current Wave 3 routes, unknown/deferred routes, stale correlation/args, replay, distinct plan steps, and thrown/malformed/real-error callback results.

## Implementation

### One registered executor

- `AiphoneRegisteredActionExecutor` derives registered Action membership from `actionAgentToolDefinitions()` and retains the existing registered `hotel.detail` follow-up bridge.
- Every call validates non-empty correlation identity, current `ActionCatalog` placement or registered-step authority, and exact arguments before any URI opener or page callback runs.
- Unknown, Data-owned, client-only, stale, mutated, deferred, and replayed executions return typed errors without invoking product behavior.
- Replay reservation occurs before the asynchronous side effect. Rejected openers, thrown callback promises, non-boolean opener values, malformed callback results, cancellations, and real provider errors cannot become success or a fabricated receipt.
- Hotel detail still produces the same paired Data/UI follow-up. Hotel navigation still builds the canonical Petal Maps URI. Hotel booking still accepts only the registered RollingGo URL through the existing opener.

### Runtime and page callback

- `MultiAgentRuntime` now defaults to the product registered executor while preserving explicit executor injection. Missing system/page adapters reject safely.
- The existing canary memory wrapper delegates every non-memory action to that same product executor; the standalone hotel runtime injects a rejecting non-hotel callback.
- `Index.ets` injects one callback into the canary. It has an explicit allowlist for only the current Wave 3 page routes and reuses `callToolById`, the existing Gmail Web opener, and the existing World Cup router.
- Gateway output is observed and returned as the real parsed data model with the current correlation and surface status. Transport failures, error surfaces, error/blocked provider results, SocialHub draft errors, Stripe setup errors, malformed data, and rejected navigation return typed errors.
- Gmail Web and World Cup navigation now return success only after their existing platform navigation calls succeed. No new transport, provider, registry, or receipt model was added.

## Confirmation and Lifecycle Boundary

- `ActionAgent` remains the owner of confirm-required pause/resume, immediately-before-invoke catalog reauthorization, cancel/timeout/stop suppression, plan progression, and terminal result publication.
- The executor does not auto-confirm, create a second action lifecycle, or call a page handler twice.
- `payment.send` retains its current preview/confirmation UI behavior. Task 8 owns payment confirmation and the remaining external-write routes.

## Verification

- Full authoritative Hypium: **1015/1015 passed**, zero failures and zero errors.
- `node scripts/verify-loopy-backend.mjs`: **237 checks passed**, including a successful `agent_core` HAR build.
- The passing registry ownership test proves **44 fixed definitions**, **44 unique IDs**, **24 Data tools**, and **20 Action tools**.
- Capability audit: 44 registry tools; no missing matrix entries, missing docs, registry-only tools, model-only tools, or excluded smoke queries. The ten existing `reviewRequired` future capabilities remain unchanged.
- `git diff --check`: passed.
- Production/test scan: no `HotelRegisteredActionExecutor` reference remains; exactly one `AiphoneRegisteredActionExecutor` class exists.
- Deferred Task 7/8 action IDs do not occur in the production executor, and no fake/mock/simulated/receipt success text was added to the executor or page adapter.
- Runtime graph scan still shows one `LeaderAgent`, one `DataAgent`, one `UiAgent`, and one `ActionAgent`; `UiSurfaceWriter` remains owned by `UiAgent`.

## Simplicity Review

- The implementation is one executor, one injected callback type, one explicit page-route predicate, and one page adapter. It does not add a coordinator, registry, workflow engine, provider wrapper, dependency, or generic dynamic-write discovery.
- Existing injected executor seams remain available for tests and specialized runtimes.
- Client-only sort/filter/expand/back actions remain in `handleClientAction` and do not enter registered execution.

## Files Changed

- `entry/src/main/ets/pages/A2uiHome/Index.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor.ets` (renamed)
- `entry/src/main/ets/pages/A2uiHome/agent/HotelAgentRuntime.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentCanaryRuntime.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntime.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntimeTypes.ets`
- `entry/src/test/AiphoneRegisteredActionExecutor.test.ets` (renamed)
- `entry/src/test/HotelAgentRuntime.test.ets`
- `entry/src/test/MultiAgentCanaryRuntime.test.ets`
- `entry/src/test/List.test.ets`
- `.superpowers/sdd/tasks/domain-task-06-report.md`

## Evidence Boundary

Hvigor still emits the pre-existing coverage reporter `00507008` JSON parse error after Hypium completes. The fresh authoritative result file is complete and green. This task has deterministic unit/integration, structural verifier, capability-audit, and HAR-build evidence; it does not claim a live-provider, signed-package, or device run.
