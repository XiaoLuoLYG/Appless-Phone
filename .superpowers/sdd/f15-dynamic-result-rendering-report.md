# F15 dynamic result rendering repair report

## Outcome

F15 now renders a provider-backed `dynamicToolConnect` result through the
existing `GenericToolResults` A2UI path. Empty, authorization-required, and
provider-error results retain their original status and message. Malformed or
uncorrelated provider data still fails closed.

The device evidence parser now accepts the remote Composio discovery path only
when one sanitized `DynamicToolDiscovery` marker is correlated with the exact
`dynamic.search` Data task and terminal result. The existing local-manifest
`weather.query` discovery contract remains supported.

No renderer, component, visual style, heuristic route, dynamic write, or Gmail
behavior was added or changed.

## Implementation

- `StructuredToolUiRenderer` recognizes `outputSchema=dynamicToolConnect`,
  checks registration and source identity, and reuses
  `genericToolResultsA2ui`.
- Dynamic registration metadata records the selected public tool ID. Remote
  Composio uses `dynamic.search`; local manifest discovery retains the selected
  manifest ID such as `weather.query`.
- The multi-agent runtime emits a sanitized discovery line before the matching
  terminal Data-result line. It includes only opaque correlation tokens,
  selected tool ID, provider, qualified name, status, source match, and receipt
  presence/match.
- The smoke parser requires the exact current conversation, turn, task,
  provider registration, source, and terminal status. Prompt text, UI copy,
  stale turns, mismatched providers, and source-less markers are rejected.
- F13, F14, and F15 additionally require their reviewed provider operations:
  `GITHUB_FIND_PULL_REQUESTS`, `GOOGLEDRIVE_FIND_FILE`, and
  `GOOGLEDOCS_SEARCH_DOCUMENTS`. A generic empty result cannot satisfy them.
- A truthful authorization state may omit the selected provider operation only
  when the same correlated Composio result explicitly reports `needs_auth`.
- The top-level F13/F14/F15 assessment combines that correlated trace with the
  rendered provider-specific authorization card. Only this exact state may
  bypass success-lifecycle and success-card requirements, and its scenario
  verdict is always `BLOCKED` with `ok=false`, never feature `PASS`.
- Stale or wrong correlation, provider, qualified name, source, or receipt;
  ordinary empty output; and success-copy-only UI remain rejected.
- Receipt evidence is `absent`, `matched`, or `mismatch`; mismatch fails.
  `DynamicToolDiscovery` participates in the existing dual-channel HiLog
  de-duplication.
- A thrown provider call remains a renderable error `dynamicToolConnect` result
  with an `unavailable` source and the exact sanitized error message. It does
  not claim provider success.

## TDD evidence

Executable RED was captured before production edits:

- Node: 64 tests, 62 passed, with the two new discovery-evidence tests failing
  because `dynamicToolDiscoveryEvidence` did not exist.
- Hypium behavior RED: 1267 tests, 1265 passed, 2 failed. The two new canonical
  rendering tests failed because `dynamicToolConnect` produced the unsupported
  schema card.
- Hypium compile RED: the new formatter test failed because
  `MultiAgentEvidenceFormatter.dynamicDiscoveryLine` did not exist.

Final GREEN evidence:

- `node --test scripts/multi-agent-smoke-evidence.test.mjs`
  - 69 passed, 0 failed.
- DevEco `hvigorw --mode module -p module=entry@default -p product=default test --no-daemon`
  - authoritative
    `entry/.test/default/intermediates/test/coverage_data/test_result.txt`:
    `Tests run: 1269, Failure: 0, Error: 0, Pass: 1269, Ignore: 0`.
  - Hvigor still prints the existing coverage JSON reporter error
    `00507008`; the authoritative test result is green.
- `node scripts/verify-loopy-backend.mjs`
  - 305 checks passed and `agent_core` HAR built.
- `git diff --check`
  - passed.

Review repair RED was also captured before its production changes:

- Node: 66 tests, 62 passed, 4 failed. These covered case-specific qualified
  names/manifests, auth-only relaxation, receipt tri-state, and discovery-marker
  dual-channel de-duplication.
- Hypium:
  `Tests run: 1269, Failure: 1, Error: 1, Pass: 1267, Ignore: 0`.
  The failure covered formatter auth/receipt fields; the error proved a thrown
  provider call still lacked a renderable dynamic result.

Final assessment repair RED was captured before its production changes:

- Node: 69 tests, 66 passed, 3 failed. The failures were exactly the missing
  pure dynamic-auth assessment, hostile/empty/success-copy rejection, and
  top-level smoke wiring.
- The final GREEN keeps a strict correlated authorization outcome internally
  consistent: real authorization UI is usable evidence, the provider outcome
  is `BLOCKED`, `summary.ok` remains false, and the full regression remains
  non-zero until the provider is actually authorized.

## Truth boundary

This task provides source, unit, static, and smoke-parser evidence only. It does
not claim device or live-provider PASS. The controller must rebuild the exact
final HAP and rerun F15 on the real device. Existing untracked `.smoke*`
evidence directories were preserved unchanged.
