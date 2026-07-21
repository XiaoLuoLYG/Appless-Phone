# Domain Task 06 Report: Registered Product Action Execution

## Scope

- Base commit: `15c49cd7215de2f03e267d2f073fd9d557b41436`.
- Initial implementation: `ad17f649735c698127f104ed29a0ff8f2607d805` (`feat: register product action execution`).
- Review fix: `78211438` (`fix: enforce registered action authority`).
- Renamed the hotel-only registered executor to the product-level `AiphoneRegisteredActionExecutor` and kept one narrow `RegisteredPageAction(actionId, args, context)` product callback seam.
- Added executor support for the ten Wave 3 routes: `luckin.order.preview`, `social.reply.draft`, `mail.draft.create`, `gmail.draft.create`, `gmail.draft.apply`, `gmail.open.web`, `worldcup.open`, `payment.send`, `payment.account.setup`, and `maps.route.open`.
- Kept Task 7 `gmail.message.send` and the remaining Task 8 external writes fail-closed.

## Review Fix Outcome

### Real reachability authority

- `RegisteredPageActionRoute.ets` resolves page actions only from the current surface's real registered `summary.toolName`, exact surface document action, and exact action arguments.
- A direct same-ID Action definition may authorize its own fixed action. Otherwise the source definition must declare the action. The only cross-ID adapters are the two existing explicit UI relationships: `payment.confirm` to `payment.send`, and Stripe account actions to `payment.account.setup`.
- `Index.ets` now routes a valid registered click through `MultiAgentCanaryRuntime.runPageAction` and the normal Action Agent lifecycle exactly once. Client-only, deferred, unknown, mutated, and stale-generation actions reject before the product callback.
- The canary's initial Leader `actionIntent` path is limited to fixed, non-confirm-required Actions. Confirm-required routes remain exact-button flows, so an initial prompt cannot wait for a confirmation UI that does not exist.
- The reachability tests cover all ten fixed executor routes: eight through actual current-button surface paths and two (`worldcup.open`, `maps.route.open`) through a real Leader `actionIntent` / `ACTION.PLAN.REQUEST` / Action Agent path. Test callbacks are controlled seams; this is routing evidence, not live-provider or device evidence.

### Exact confirmation

- A confirm-required direct click is authorized only after current `ActionCatalog.validateSurfaceExecution` succeeds for the exact conversation, turn, task, surface, source tool, run, action, arguments, and surface generation.
- The proof is stored internally by `ActionAgent`, consumed once, and resumed through `ActionPlanRunner` so immediately-before-invoke catalog validation still runs.
- Forged args, wrong correlation identity, a second use, cancel, and stop cannot execute. An unconfirmed bus message still pauses/rejects rather than inheriting a page click's authority.
- No timeout, overlay, bus protocol field, second lifecycle, or automatic confirmation path was added.

### Bounded replay state

- Replay identity includes conversation, turn, surface, source tool, plan, run, and step, so distinct steps in one run remain executable while an exact replay rejects before a second side effect.
- Each verified surface scope accepts at most 128 replay identities. The executor does not evict live entries; the 129th unique identity fails closed with `ACTION_REPLAY_CAPACITY`.
- Replay state resets only after a verified authority-scope transition or explicit runtime disposal. A forged scope cannot reset it.
- `MultiAgentRuntime`, `MultiAgentCanaryRuntime`, and `HotelAgentRuntime` now dispose the executor instances they own.

## TDD Evidence

### Initial implementation RED/GREEN

The renamed executor test was registered before the production rename. The authoritative Hypium compile failed because `AiphoneRegisteredActionExecutor.ets` did not exist. The first implementation reached 1014/1014.

A later replay-correlation RED reported 1015 tests with one failure: a valid second plan step was rejected because replay protection keyed the whole run. Adding the exact step identity made 1015/1015 green.

### Review RED/GREEN

- Replay/lifecycle tests were written before the new API and failed compilation because executor `dispose()` did not exist. The implementation added the 128-entry fail-closed cap, verified-scope transition, forged-scope rejection, and disposal behavior.
- Exact-button confirmation tests were written before the new API and failed compilation because `ActionAgent.authorizeDirectSurfaceRun()` did not exist. The implementation added internal one-shot authorization and resume-through-runner behavior.
- Reachability tests exercise the real canary/Leader boundaries. They cover all ten supported routes and prove client/deferred/mutated/stale actions cannot invoke the callback.

## Final Verification

Authoritative command:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Fresh authoritative `entry/.test/default/intermediates/test/coverage_data/test_result.txt` at `2026-07-22T05:46:36+0800`:

```text
Tests run: 1022, Failure: 0, Error: 0, Pass: 1022, Ignore: 0
```

- Full Hypium: **1022/1022 passed**, zero failures and zero errors.
- `node scripts/verify-loopy-backend.mjs`: **237 checks passed**, including a successful `agent_core` HAR build, on the exact committed implementation tree.
- Capability audit: 44 registry tools, 36 actions, 69 capabilities; no missing matrix entries, missing docs, registry-only tools, model-only tools, or excluded smoke queries. The ten existing `reviewRequired` future capabilities remain unchanged.
- `git diff --check`: passed.

## Product and Evidence Boundary

- Product callbacks still return real parsed provider data or the real provider/config/navigation error. No fake receipt, order, provider success, registry mutation, or test-only source relationship was added.
- Hotel detail, Petal Maps navigation, and RollingGo in-app booking keep their existing behavior.
- The implementation remains one registered executor, one callback type, one route resolver, and the existing Action Agent lifecycle. It adds no coordinator, workflow engine, transport, provider wrapper, dependency, or generic dynamic-write discovery.
- Hvigor still emits the pre-existing coverage reporter `00507008` JSON parse noise after Hypium completes. The fresh authoritative result file is complete and green.
- This report claims deterministic unit/integration routing, action-lifecycle, structural-verifier, capability-audit, and HAR-build evidence only. It does not claim a live-provider success, signed package, or device run.

## Review-Fix Files

- `agent_core/src/main/ets/agent/action/ActionAgent.ets`
- `agent_core/src/main/ets/agent/action/ActionCatalog.ets`
- `entry/src/main/ets/pages/A2uiHome/Index.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/HotelAgentRuntime.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentCanaryRuntime.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntime.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/RegisteredPageActionRoute.ets`
- `entry/src/test/ActionAgent.test.ets`
- `entry/src/test/AiphoneRegisteredActionExecutor.test.ets`
- `entry/src/test/MultiAgentCanaryRuntime.test.ets`
