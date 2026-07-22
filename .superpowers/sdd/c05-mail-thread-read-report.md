# C05 mail thread read migration report

## Scope and authority

- Implemented only `.superpowers/sdd/c05-mail-thread-read-brief.md` from source/device HEAD `30baab99209731840c7233bc0bc45f3846ffd8f9`.
- Preserved the existing mail cards, provider status rows, `展开/收起`, `详情 +`, reply controls, labels, ordering, and in-place body event.
- Did not change Gmail reply, draft, send, confirmation, persona, skill, prompt, or legacy fallback behavior.
- Did not touch, stage, delete, or move `.smoke` evidence, worktrees, branches, or user files.

## Root cause

The current mail search already used the four-Agent runtime, but the existing `html_mail_detail_read` client action was absent from the registered page-action route. `Index.handleClientAction` therefore called `readConfiguredMailDetail` directly. The device smoke also clicked the first visible `展开`, which could be the truthful Gmail provider-error card, and stopped after a fixed 900 ms instead of continuing to a real QQ message.

## RED evidence

Tests were added before production code for:

- exact current-surface QQ and Gmail action mapping;
- one Data task and one provider call per click;
- zero new Leader input/model turn;
- stale surface and mutated identity rejection before the provider;
- provider-error settlement through the existing in-place UI event;
- exact Action/Data/UI/in-place smoke correlation;
- provider-error candidate first, real QQ candidate second.

The initial focused runs failed for the missing contracts:

- Node evidence test: `mailThreadReadEvidence` was not exported.
- Hypium/ArkTS: `MailDetailInPlaceEvent` and `MultiAgentCanaryOptions.onMailDetail` did not exist.

## GREEN implementation

1. `RegisteredPageActionRoute` recognizes the existing `html_mail_detail_read` only from current mail surfaces, preserves the immutable action args, and maps `gmail` to `gmail.thread.read` and `qq` to `mail.thread.read`.
2. `AiphoneRegisteredActionExecutor` revalidates provider, `requestKey`, `threadId`, and `messageId`, then creates exactly one correlated Data task and one UI task without publishing a new Leader input.
3. Data Agent remains the only provider execution path. The exact tool input and `mailThread` output schema are used.
4. `MailDetailInPlaceBridge` is a bounded compatibility adapter around the existing UiAgent renderer/writer. It validates the returned provider identity and real body, suppresses replacement of the visible mail surface, and invokes the existing host mail-detail event.
5. `Index` no longer imports or calls `readConfiguredMailDetail`; it only consumes the correlated in-place event and retains the existing calendar-suggestion and mail-detail state update.
6. The device smoke now iterates candidate mail cards, collapses a local/provider-error candidate when appropriate, and requires the exact Action → Data → UI → in-place lifecycle for the real card. It does not loosen the visible-body regex or replace the wait with a longer fixed sleep.

## Files changed

- `entry/src/main/ets/pages/A2uiHome/Index.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentCanaryRuntime.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/RegisteredPageActionRoute.ets`
- `entry/src/test/RegisteredPageActionMigration.test.ets`
- `scripts/aiphone-device-smoke.mjs`
- `scripts/multi-agent-smoke-evidence.mjs`
- `scripts/multi-agent-smoke-evidence.test.mjs`
- `.superpowers/sdd/c05-mail-thread-read-report.md`

## Final verification

- Authoritative Hypium: `Tests run: 1143, Failure: 0, Error: 0, Pass: 1143, Ignore: 0`.
- `test_result.txt` timestamp: `2026-07-23T01:12:52+0800`.
- `test_result.txt` SHA-256: `78ea637cf8559f00d6cf37abd5db346d59df324b52e5522cee9386d9c55d6700`.
- Known baseline coverage reporter noise remains: `00507008 getInitCoverageData failed`; it did not change the authoritative test result.
- Multi-agent evidence tests: `38/38` pass.
- Hotel evidence regression: `16/16` pass.
- Backend verifier/HAR: `255` checks pass; HAR build succeeds.
- Capability audit: 44 registry tools, 2 runtime tools, 37 actions, 69 capabilities; `missingMatrix`, `missingDocs`, `registryOnlyTools`, `modelOnlyTools`, and `excludedQueriesInSmoke` are empty.
- Smoke syntax: `node --check scripts/aiphone-device-smoke.mjs` passes.
- Smoke case listing remains exactly C01-C20 and F01-F16, with Gmail send still behind its existing explicit safe-manual configuration.
- `git diff --check` passes.

## Self-review

- No direct `readConfiguredMailDetail` call remains in `Index`.
- Current surface authorization occurs before Data Agent execution; stale/mutated args do not reach the provider.
- One click creates one exact provider Data task and one correlated UI terminal.
- In-place evidence must occur after the exact Data terminal and before the exact UI terminal; terminal-adjacent unrelated logs are rejected.
- The adapter has bounded pending state and is disposed with the runtime.
- No mail UI rendering, reply/draft/send action, or capability registry entry was added, removed, or renamed.

## Concern and remaining acceptance

This focused task did not install a HAP or claim fresh C05 device PASS. The parent migration task must build the final combined HEAD and rerun C05 on the real device, requiring a real QQ/Gmail body lifecycle or a truthful provider terminal under the final application package. The pre-existing device evidence directories remain unmodified and untracked.
