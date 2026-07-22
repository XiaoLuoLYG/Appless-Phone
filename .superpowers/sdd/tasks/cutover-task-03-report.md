# Cutover Task 03 Report

Date: 2026-07-22

Status: host implementation and gates PASS; independent re-review of the corrective commit is pending. No device or provider PASS is claimed.

Implementation commits:

- `4f8007aab3a78d4f8ac6f5ca42282701605e4b40` — initial lifecycle coverage
- `f9c994ea` — reviewer-requested correlation hardening

## Corrective scope

The first independent review rejected the initial report with four Important findings. `f9c994ea` closes those findings:

- Multi-Agent evidence now maps conversation, turn, task, surface, plan, and run IDs to opaque per-runtime tokens. The formatter uses one bounded FIFO map and one sequence; it logs no prompt, local ID, entity value, action args, provider message, URL, receipt, recipient, email, phone, order ID, or event ID.
- F12 provenance is not inferred from tool names or round numbers. A successful Data result records bounded `entityRefs` or the real Maps `places[i].placeId` only in memory; a later `args.placeId` must exactly match before the logger emits an opaque predecessor task token, a JSON Pointer path, and `binding=true`. The raw entity is never logged.
- Lifecycle parsing stops at the first matching `TurnResult`, reports same-turn late markers, requires create-before-terminal ordering, exact tool multiplicity, known task terminals, prior-round settlement, explicit dependent-task metadata, one UI dependency owner, and equality between the final UI and terminal surface. Unknown/input `TaskError` is terminally invalid.
- Direct actions require the exact ordered current conversation/turn/surface/source/action run-result chain. Calendar source is derived from the final visible UI's unique Data dependency rather than hard-coded. Hotel detail, booking, and navigation use their exact search/detail visible-surface contexts. Virtual actions require plan-request before result and reject a fabricated `ActionRun`.
- C20 no longer accepts a generic NETSTACK HTTP 200. It requires ordered RollingGo request and real response/source markers before the hotel document, ready state, final UI result, and `TurnResult`. The provider chain is correlated to the lifecycle's final surface, and the actual smoke verdict consumes the combined result.

## Production boundary

The allowlist, formatter, and emitter occupy 149 physical lines in `MultiAgentRuntime.ets`. The file's corrective diff is `+138/-71`. Production state added by the logger is limited to one 128-entry bounded map, its FIFO keys, and one scalar sequence; `dispose()` clears all three. Provider instrumentation adds only privacy-safe RollingGo operation/status/source-count markers, including truthful error terminals for provider and exception paths. Parser complexity remains in the Mac smoke scripts.

## TDD and adversarial coverage

Reviewer-derived RED cases covered:

- post-terminal Data/UI events, result-before-create, duplicate tool multiplicity, unknown/input task errors, overlapping rounds, missing/exact dependency metadata, and final-surface mismatch;
- direct result-before-run, stale turn/surface/source, virtual result-before-plan, and fabricated virtual `ActionRun`;
- generic NETSTACK-only hotel evidence, reversed RollingGo response/request order, and mismatched/uncombined provider chains;
- raw email/phone/newline/long IDs, unsafe registry IDs, raw prompt/provider/entity values, true Maps entity provenance, and no-provenance fail-closed behavior.

## Final host gates

- Focused Node lifecycle/hotel suites: PASS, 38/38.
- Changed-script syntax checks: PASS.
- Case lists: PASS, exactly C01-C20 and C01-C20 plus F01-F16; M01 remains list-only behind both safe variables and X02 remains excluded.
- Backend verifier: PASS, 245 checks including HAR build.
- Coverage audit: PASS; 44 registry tools, 2 runtime tools, 37 actions, 69 capabilities; all missing/docs/registry/model/excluded arrays are empty. The ten `reviewRequired` entries remain the intentional R-scope list.
- Authoritative Hypium: `Tests run: 1089, Failure: 0, Error: 0, Pass: 1089, Ignore: 0`.
- `git diff --check`: PASS.
- Generated `agent_core/BuildProfile.ets`: restored to `debug` and absent from the final diff.

Hvigor still emits the known coverage-report JSON parsing warning (`00507008`) after tests; acceptance uses the authoritative `test_result.txt`, which has zero failures and errors.

## Matrix and scope

The external scenario matrix remains at `/Users/luoyige/.codex/skills/appless-device-regression/references/scenario-matrix.md`; the coverage audit confirms no missing product/matrix/docs entries. It is intentionally outside this repository.

No device command, HDC interaction, provider call, Gmail send, installation, push, merge, branch cleanup, or worktree cleanup was performed. Device/provider execution remains a separate cutover acceptance gate.
