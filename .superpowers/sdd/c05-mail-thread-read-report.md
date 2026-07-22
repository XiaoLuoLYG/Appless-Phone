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

## Follow-up RED / GREEN after independent review

The independent review did not approve the first implementation. The follow-up kept the approved UI and feature behavior unchanged and corrected six runtime/evidence boundaries:

1. QQ Mail now accepts its real IMAP identity contract: an empty `threadId`, a numeric `messageId`, and `requestKey=qq:<messageId>`. Gmail still requires both IDs and `requestKey=gmail:<threadId>`.
2. The migrated Gmail detail route no longer consumes the truncated Dynamic `rawPreview`. Production uses the full Composio observation and preserves the existing direct Gmail OAuth fallback; QQ remains on the real IMAP client.
3. The in-place bridge has one hard eight-entry bound across prepared, canceled, and surface state. Cancel, timeout, failed action settlement, dispose, and late writer completion invalidate the write lease and cannot revive a stale body.
4. The page callback rechecks the same lease and host generation before suggestion work, after its await, and immediately before applying the existing mail-detail event.
5. Device smoke rejects the loading skeleton and truthful provider-error text as a body, polls bounded UI state instead of sleeping for a fixed 500 ms, and still preserves the existing visible mail layout and controls.
6. C05 evidence is tied to the exact anonymized `ACTION.RUN -> DataTask -> Data terminal -> in-place event -> UI terminal` identity. Logs contain only the provider and a bounded digest, not the raw request, thread, or message ID.

The follow-up RED was produced by the missing QQ identity rule, full-detail reader seam, write lease, bounded cancellation state, visible-body predicate, and exact mail identity evidence. Production changes were added only after those focused failures.

Fresh follow-up GREEN evidence:

- Authoritative Hypium: `Tests run: 1148, Failure: 0, Error: 0, Pass: 1148, Ignore: 0`.
- `test_result.txt` timestamp: `2026-07-23T01:52:07+0800`.
- `test_result.txt` SHA-256: `f82f270855a482bd9008f25e18cf392ebbb9928c859dd50ac8eb17c5ec64b473`.
- Multi-agent and mail evidence tests: `39/39` pass.
- Hotel evidence regression: `16/16` pass.
- Backend verifier/HAR: `255` checks pass; HAR build succeeds.
- Capability audit: 44 registry tools, 2 runtime tools, 37 actions, and 69 capabilities; `missingMatrix`, `missingDocs`, `registryOnlyTools`, `modelOnlyTools`, and `excludedQueriesInSmoke` are empty.
- Smoke syntax and `git diff --check` pass.

The existing coverage reporter still emits `00507008 getInitCoverageData failed`; the authoritative result above is the fresh `test_result.txt`. A failed-run coverage log and both pre-existing untracked `.smoke` directories were preserved in place and were not staged, deleted, or moved. Fresh final-device C05 verification remains owned by the parent migration task and must use the combined final HAP.

## Third RED / GREEN after second independent review

The second independent review found two remaining acceptance gaps. The correction remains limited to the existing C05 body event and smoke evidence; it does not change the UI, copy, action deadline, tools, confirmation policy, or provider behavior.

RED evidence:

- A deferred calendar-suggestion promise reproduced the body being held behind optional model work. The new test requires the registered mail action to settle successfully while that promise is still unresolved.
- A forged trace with the exact Action/Data task identity but a `gmail/wrong` DataResult followed by a plausible `qq/good` in-place event was accepted by the old evidence parser.
- Missing DataResult identity and interleaved unrelated mail task/result traces were added as explicit negative/positive correlation fixtures.

GREEN implementation:

1. The existing `MailDetailUiEvent` is emitted with the real body while the original write lease is active. Optional calendar extraction is then detached from the action lifecycle and cannot consume the unchanged 15-second action deadline.
2. A completed suggestion is written through the same existing `mailDetailEventJson` UI event with the same detail. It does not call the mail provider again and does not publish another action.
3. Async enrichment is authorized by the exact mail request epoch, captured surface ID, runtime owner, and runtime generation. A newer mail request, a new surface, a new runtime turn, or runtime disposal invalidates it before any late suggestion/cache write.
4. Suggestion rejection leaves the already-visible body intact and does not turn the registered action into an error.
5. `mailThreadReadEvidence` now requires the exact `MultiAgentDataResult` provider and identity digest to match the ActionRun, DataTask, and in-place terminal; missing or mismatched identity fails closed.

Fresh third-round evidence:

- Authoritative Hypium: `Tests run: 1150, Failure: 0, Error: 0, Pass: 1150, Ignore: 0`.
- `test_result.txt` timestamp: `2026-07-23T02:08:04+0800`.
- `test_result.txt` SHA-256: `7df8cd497d697e7e7d265577951cf7222dcba8b9f623ffec008ac9a010c1d53d`.
- Multi-agent and mail evidence tests: `39/39` pass.
- Backend verifier/HAR: `255` checks pass; HAR build succeeds.
- Hotel evidence regression: `16/16` pass.
- Capability audit remains 44 registry tools, 2 runtime tools, 37 actions, and 69 capabilities with all missing/registry-only/model-only/excluded arrays empty.
- Smoke syntax and `git diff --check` pass.

The coverage reporter's existing `00507008` JSON parsing noise remains separate from the authoritative `test_result.txt`. The two pre-existing untracked `.smoke` directories remain untouched and unstaged.
