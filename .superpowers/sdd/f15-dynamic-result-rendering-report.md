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
  - 64 passed, 0 failed.
- DevEco `hvigorw --mode module -p module=entry@default -p product=default test --no-daemon`
  - authoritative
    `entry/.test/default/intermediates/test/coverage_data/test_result.txt`:
    `Tests run: 1268, Failure: 0, Error: 0, Pass: 1268, Ignore: 0`.
  - Hvigor still prints the existing coverage JSON reporter error
    `00507008`; the authoritative test result is green.
- `node scripts/verify_multi_agent_backend.mjs`
  - 305 checks passed and `agent_core` HAR built.
- `git diff --check`
  - passed.

## Truth boundary

This task provides source, unit, static, and smoke-parser evidence only. It does
not claim device or live-provider PASS. The controller must rebuild the exact
final HAP and rerun F15 on the real device. Existing untracked `.smoke*`
evidence directories were preserved unchanged.
