# Cutover Task 03 Report

Date: 2026-07-22

Status: host implementation and gates PASS; stable same-reviewer re-review APPROVED with zero Critical, Important, or Minor findings. No device or provider PASS is claimed.

Implementation commits:

- `4f8007aab3a78d4f8ac6f5ca42282701605e4b40` — initial lifecycle coverage
- `f9c994ea` — reviewer-requested correlation hardening
- `4770ec1af8c8e8f2d6daa068a79829f2ab099424` — second-review false-positive closure
- `cffb4953bbbd990e92988793ccf5a9473f0c068f` — generated-surface evidence correlation
- `56320c9d6ab4331dff1843ae733f00f27acee3f0` — generated follow-up surface parsing

## Corrective scope

The first independent review rejected the initial report with four Important findings. `f9c994ea` closes those findings:

- Multi-Agent evidence maps conversation, turn, task, plan, and run IDs to opaque per-runtime tokens. Generated UI surfaces are the sole exception: only `loop_surface_<digits>` with an optional numeric collision suffix is preserved so lifecycle and A2UI logs can be compared exactly; every other surface shape becomes `invalid`. The formatter uses one bounded FIFO map and one sequence; it logs no prompt, local ID, entity value, action args, provider message, URL, receipt, recipient, email, phone, order ID, or event ID.
- F12 provenance is not inferred from tool names or round numbers. A successful Data result records bounded `entityRefs` or the real Maps `places[i].placeId` only in memory; a later `args.placeId` must exactly match before the logger emits an opaque predecessor task token, a JSON Pointer path, and `binding=true`. The raw entity is never logged.
- Lifecycle parsing stops at the first matching `TurnResult`, reports same-turn late markers, requires create-before-terminal ordering, exact tool multiplicity, known task terminals, prior-round settlement, explicit dependent-task metadata, one UI dependency owner, and equality between the final UI and terminal surface. Unknown/input `TaskError` is terminally invalid.
- Direct actions require the exact ordered current conversation/turn/surface/source/action run-result chain. Calendar source is derived from the final visible UI's unique Data dependency rather than hard-coded. Hotel detail, booking, and navigation use their exact search/detail visible-surface contexts. Virtual actions require plan-request before result and reject a fabricated `ActionRun`.
- C20 no longer accepts a generic NETSTACK HTTP 200. It requires ordered RollingGo request and real response/source markers before the hotel document, ready state, final UI result, and `TurnResult`. The provider chain is correlated to the lifecycle's final surface, and the actual smoke verdict consumes the combined result.

The second independent review found four remaining executable false positives. `4770ec1a` closes only those parser/caller/test gaps, without adding product state:

- F12 now supplies its exact Maps search-to-detail predecessor, `/places/0/placeId` source path, and `/placeId` target to both capture and analysis. The safe `--full-regression --list-cases` manifest exposes the same dependency contract for a no-device regression assertion.
- A terminal UI `state=result` must occur after every declared Data dependency terminal; an early UI result can no longer pass because its Data result appears later in the turn.
- A virtual action plan is validated in virtual mode against its own conversation, turn, action ID, request, and result. An unrelated direct action run/result in the same turn cannot substitute for a missing virtual result.
- C20 compares the raw provider surface directly with the lifecycle surface. The helper no longer rewrites a mismatched provider surface into the lifecycle value.

The same-reviewer check then found that exact C20 comparison would reject the live runtime because lifecycle surfaces were still opaque while `A2uiHomeSurfaceUpdate` logged the generated surface. `cffb4953` closes that false negative without a second alias map or any new state. The generation audit found one Multi-Agent UI source: `UiAgent.uniqueSurfaceId()` uses `newSurfaceId()` and can only append a numeric collision suffix. The evidence formatter therefore preserves exactly `^loop_surface_[0-9]+(?:_[0-9]+)?$` and fails every other surface shape closed.

The reviewer subsequently withdrew approval because C20's detail and restore caller still parsed only the obsolete `sN` lifecycle surface. `56320c9d` moves that parser into the import-safe evidence module, makes the real device-smoke caller consume it, accepts only the exact generated-surface grammar, and keeps `sN` rejected. Conversation, turn, terminal-result state, and after-index filters remain mandatory where supplied. No device CLI import or device action is needed to test this path.

## Production boundary

The allowlist, formatter, and emitter occupy 149 physical lines in `MultiAgentRuntime.ets`. The file's corrective diff is `+138/-71`. Production state added by the logger is limited to one 128-entry bounded map, its FIFO keys, and one scalar sequence; `dispose()` clears all three. Provider instrumentation adds only privacy-safe RollingGo operation/status/source-count markers, including truthful error terminals for provider and exception paths. Parser complexity remains in the Mac smoke scripts.

## TDD and adversarial coverage

Reviewer-derived RED cases covered:

- post-terminal Data/UI events, result-before-create, duplicate tool multiplicity, unknown/input task errors, overlapping rounds, missing/exact dependency metadata, and final-surface mismatch;
- direct result-before-run, stale turn/surface/source, virtual result-before-plan, and fabricated virtual `ActionRun`;
- generic NETSTACK-only hotel evidence, reversed RollingGo response/request order, and mismatched/uncombined provider chains;
- raw email/phone/newline/long IDs, unsafe registry IDs, raw prompt/provider/entity values, true Maps entity provenance, and no-provenance fail-closed behavior.

Second-review RED cases additionally cover missing F12 dependency options in the executable case manifest, UI result before its Data dependency terminal, a virtual plan without a result plus an unrelated direct action result, a stale raw C20 provider surface, the real generated surface shape shared by lifecycle and A2UI logs, and C20 follow-up extraction of that generated surface. The logger expectation was observed RED at 1088/1089; the extracted caller/parser test was separately observed RED before its export existed. Malformed/user-shaped surfaces and obsolete `sN` remain rejected.

## Final host gates

- Focused Node lifecycle/hotel suites: PASS, 39/39 in 0.4 seconds.
- Changed-script syntax checks: PASS.
- Case lists: PASS, exactly C01-C20 and C01-C20 plus F01-F16; M01 remains list-only behind both safe variables and X02 remains excluded.
- Backend verifier: PASS, 245 checks including HAR build.
- Coverage audit: PASS; 44 registry tools, 2 runtime tools, 37 actions, 69 capabilities; all missing/docs/registry/model/excluded arrays are empty. The ten `reviewRequired` entries remain the intentional R-scope list.
- Authoritative Hypium: `Tests run: 1089, Failure: 0, Error: 0, Pass: 1089, Ignore: 0`.
- `git diff --check`: PASS.
- Generated `agent_core/BuildProfile.ets`: restored to `debug` and absent from the final diff.
- Same-reviewer verdict: stable APPROVE, 0 Critical / 0 Important / 0 Minor, after closing the withdrawn-approval caller mismatch.

Hvigor still emits the known coverage-report JSON parsing warning (`00507008`) after tests; the fresh authoritative `test_result.txt` at `2026-07-22T15:54:39+0800` has zero failures and errors.

## Matrix and scope

The external scenario matrix remains at `/Users/luoyige/.codex/skills/appless-device-regression/references/scenario-matrix.md`; the coverage audit confirms no missing product/matrix/docs entries. It is intentionally outside this repository.

While adding the F12 caller assertion, an initial test import accidentally executed the smoke CLI's top-level main path. The exact Node PID was terminated, its partial output was discarded, and the test was changed to use the existing list-only subprocess; the same suite then completed in 0.3 seconds. This accidental invocation is not device or provider acceptance evidence. No Gmail send, installation, push, merge, branch cleanup, or worktree cleanup was performed. Device/provider execution remains a separate cutover acceptance gate.
