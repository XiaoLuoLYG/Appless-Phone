# C02 bounded multi-agent turn deadline report

Date: 2026-07-23

Status: PASS for source, lifecycle, Hypium, HAR/verifier, evidence parsers, capability audit, and diff hygiene. No new live-device/provider run is claimed.

## Scope and decision

- Base HEAD: `b4181f0ebc7afb3b7b65863f6be0a0af05dfebb6` on `codex/full-multi-agent-migration`.
- The production `MultiAgentCanaryOptions` object in `Index.ets` now sets `submitTimeoutMs: 45000` exactly once.
- `MultiAgentCanaryRuntime` already forwards that one option unchanged to `MultiAgentRuntime`; `MultiAgentRuntime` already uses it for both the Host timer and the `LeaderAgent` deadline.
- The generic `MultiAgentRuntime` default remains `30000`, the Action deadline remains `15000`, the UI layout fallback remains `6000`, and the existing cap remains `120000`.
- The production entry is authoritative because this is a measured C02 product-runtime allowance, while library/default consumers and existing explicit test timeouts must retain their current contracts. No duplicate timeout constant or new API was introduced.

## TDD evidence

### RED

The final narrow source verifier was installed before the production line, then run against `Index.ets` without `submitTimeoutMs: 45000`:

```text
FAIL production multi-agent turn deadline is 45000 ms
1 verification check(s) failed.
```

All other verifier/HAR checks passed. An earlier draft used the verifier's generic comment-stripping declaration parser; self-review found that `petalmaps://` truncated its function body, so that draft was discarded. The production line was removed and the TDD cycle was restarted with the final options-object seam above, proving the RED was caused by the absent production contract rather than a typo or parser defect.

Two Hypium regressions were also added before the final production GREEN:

- A real `LeaderAgent -> DataAgent -> UiAgent` flow blocks its final writer until 85 ms, crossing the old proportional 80 ms boundary while completing before the configured 120 ms fixed deadline. It asserts one Data task, one UI task, no cancel, one `TURN.RESULT`, and the accepted final surface.
- A final UI writer held beyond a 30 ms fixed deadline is released only after timeout. It asserts one cancel, one error `TURN.RESULT`, no final UI result, and no accepted writer surface.

### GREEN

The minimal production change was one property in the existing options object:

```text
submitTimeoutMs: 45000,
```

The corrected source verifier then reported:

```text
PASS production multi-agent turn deadline is 45000 ms
AIPhone Loopy backend smoke passed (246 checks).
```

The final authoritative Hypium result file was written at `2026-07-23T00:16:20+0800`, SHA-256 `035928181295b1760d3e6352fdc62888317167a1d198b83c743f0a1c8ce25299`:

```text
Tests run: 1140, Failure: 0, Error: 0, Pass: 1140, Ignore: 0
```

Both new lifecycle test names are present with `result=Success`. Hvigor emitted the known post-test coverage reporter error `00507008`; the fresh complete `test_result.txt` above is authoritative.

## Final gates

- Full Hypium: 1140/1140 passed, zero failures/errors.
- `node scripts/verify-loopy-backend.mjs`: 246 checks passed, including the `agent_core` HAR build and the exact production timeout contract.
- `node scripts/multi-agent-smoke-evidence.test.mjs`: 37/37 passed.
- `node scripts/hotel-smoke-evidence.test.mjs`: 16/16 passed.
- Capability audit: 44 registry tools, 2 runtime virtual tools, 37 actions, 69 capabilities; `missingMatrix`, `missingDocs`, `registryOnlyTools`, `modelOnlyTools`, and `excludedQueriesInSmoke` are empty. The existing ten review-required capabilities are unchanged.
- `node scripts/aiphone-device-smoke.mjs --list-cases`: listed exactly C01-C20 without executing device/provider actions.
- `git diff --check`: PASS.

## Files changed

- `entry/src/main/ets/pages/A2uiHome/Index.ets`
- `entry/src/test/MultiAgentRuntime.test.ets`
- `scripts/verify-loopy-backend.mjs`
- `.superpowers/sdd/c02-turn-timeout-report.md`

## Self-review

- The 45000 value exists only in the production options wiring; no generic default or smoke environment was changed.
- Host and Leader continue to share one fixed whole-turn deadline through the existing `MultiAgentRuntime` constructor path; no sliding refresh or competing policy was added.
- Existing explicit test timeouts remain effective and the 120000 cap remains in force.
- The 15000 Action deadline and 6000 UI fallback are unchanged.
- Timeout cancellation, late writer lease rejection, and one unique terminal are explicitly covered.
- No UI, copy, tool, provider, retry, persona, skill, action, parser, legacy route, or capability changed.
- The pre-existing untracked `tool-gateway/.smoke-focused-6b50c81d-f12-evidence-parser-fail/` directory was not read, modified, staged, moved, or deleted.

## Concerns

- This patch is source/build/test evidence only. The C02 live-device query should be rerun by the parent full-migration acceptance flow to establish that the observed approximately 31.1-second provider/model/UI chain now completes under the 45-second production deadline.

## Reviewer Important follow-up

The reviewer identified that the first production-options verifier used a raw slice plus regex. That predicate could accept `submitTimeoutMs: 45000` from a line comment, a string, or a nested object instead of requiring the live direct property.

### Follow-up RED

Mutation fixtures were added first for one valid direct property and the three specified decoys. Before the scanner fix, the actual verifier reported:

```text
PASS verifier accepts a live direct production timeout
FAIL verifier rejects a commented production timeout decoy
FAIL verifier rejects a string production timeout decoy
FAIL verifier rejects a nested production timeout decoy
PASS production multi-agent turn deadline is 45000 ms
3 verification check(s) failed.
```

### Follow-up GREEN

`scripts/verify-loopy-backend.mjs` now masks strings before comments while preserving source positions and newlines, so URL text containing `//` is not parsed as a comment. A minimal brace-depth scan then accepts exactly one direct depth-1 `submitTimeoutMs: 45000` property in the live `MultiAgentCanaryOptions` object. It rejects comment, string, nested-object, missing, duplicate, and non-45000 direct-property shapes without adding a dependency.

Final verifier output:

```text
PASS verifier accepts a live direct production timeout
PASS verifier rejects a commented production timeout decoy
PASS verifier rejects a string production timeout decoy
PASS verifier rejects a nested production timeout decoy
PASS production multi-agent turn deadline is 45000 ms
AIPhone Loopy backend smoke passed (250 checks).
```

The follow-up changes only the static verifier and this report; production source and runtime behavior are unchanged.

### Follow-up gates

- `node --check scripts/verify-loopy-backend.mjs`: PASS.
- Full Hypium rerun: `Tests run: 1140, Failure: 0, Error: 0, Pass: 1140, Ignore: 0`.
- Fresh `test_result.txt`: `2026-07-23T00:24:58+0800`, SHA-256 `ab32aa0a23b5eb76917544c624700690977c9932725e037f4ef5785af828bcef`.
- Multi-agent evidence: 37/37 passed.
- Hotel evidence: 16/16 passed.
- Capability audit: 44 registry tools, 2 runtime virtual tools, 37 actions, 69 capabilities; all drift/missing arrays empty and the same ten review-required entries retained.
- C01-C20 list-only catalog: PASS.
- `git diff --check`: PASS.
- Known non-authoritative Hvigor coverage reporter error `00507008` remains; the complete fresh Hypium result above is green.
