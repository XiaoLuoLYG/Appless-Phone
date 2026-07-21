# Domain Task 02 Report: Travel and Food Structured Reads

## Scope

- Base commit: `dc9c8b985b33bbda1c4552198a3b4fd961bbcb6f`
- Migrated Data Agent reads: `travel.search`, `train.search`, `flight.search`, and `food.search`.
- Kept the existing provider parsers, normalized A2UI data types, renderers, client actions, partial food updates, and provider-facing error messages.
- Did not change the host page, tool registration, action execution, signing, provider configuration, Loopy checkout, or any worktree layout.

## TDD Evidence

### RED

The new contract tests were registered before production implementation. The full Hypium command failed in `UnitTestArkTS` because these required exports did not exist:

- `TravelStructuredData`
- `TrainStructuredData`
- `FlightStructuredData`
- `FoodStructuredData`
- `travelStructuredDataResult`
- `trainStructuredDataResult`
- `flightStructuredDataResult`
- `foodStructuredDataResult`

The pre-existing structured dispatcher also returned `STRUCTURED_ADAPTER_MISSING` for all four tool IDs.

A later fail-closed refinement was also demonstrated RED: the no-provider food test expected `FOOD_CONFIG_MISSING`, while the implementation still returned `FOOD_PROVIDERS_UNAVAILABLE`.

### GREEN

Command:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Authoritative `entry/.test/default/intermediates/test/coverage_data/test_result.txt`:

```text
Tests run: 925, Failure: 0, Error: 0, Pass: 925, Ignore: 0
```

Hvigor still emits the pre-existing coverage reporter error `00507008` after Hypium completes. The authoritative result file is complete and green.

## Implementation

### Structured payloads

`A2uiTypes.ets` now exposes four payload contracts composed only from the existing normalized domain records:

- `TravelStructuredData` with `A2uiTravelOptionData[]` and source-status rows.
- `TrainStructuredData` with `A2uiTrainData[]`.
- `FlightStructuredData` with `A2uiFlightData[]`.
- `FoodStructuredData` with `A2uiFoodData[]` and provider-status rows.

No payload contains A2UI envelopes, JSONL, `createSurface`, or `updateComponents`.

### One provider call, two consumers

Each legacy entry point now calls its structured provider function exactly once and renders that typed `result.data` with the current renderer:

- `callLocalTravelSearch` -> `callStructuredTravelTool` -> `travelStructuredDataA2ui`
- `callLocalTrainSearch` -> `callStructuredTrainTool` -> `trainStructuredDataA2ui`
- `callLocalFlightSearch` -> `callStructuredFlightTool` -> `flightStructuredDataA2ui`
- `callLocalFoodSearch` -> `callStructuredFoodTool` -> current food partial/final renderer

The former A2UI-snapshot extraction path is absent. The final gate explicitly confirmed that neither `ToolA2uiSnapshot` nor `snapshotFromToolA2ui` exists.

`travel.search` composes the typed train and flight results in parallel. It does not parse either child's A2UI output.

### Provider truth and status mapping

- `DataSource` entries are added only after a real provider call/response is attempted.
- Flight sources identify the actual operation: `flight`, `flights`, or `getFlightPriceByCities`.
- Food providers distinguish preflight/config failures from attempted provider failures.
- Missing food configuration is `FOOD_CONFIG_MISSING` and is not retryable.
- Attempted food provider failures are `FOOD_PROVIDER_ERROR`, retain warnings and source identities, and are retryable.
- Travel errors are retryable only when at least one child provider produced real source evidence.
- Non-empty results with source warnings are `partial`; empty train results remain `empty`; provider/config failures remain `error`.

### Legacy UI compatibility

The typed fixture test proves that current identifiers and normalized fields survive the split unchanged, including:

- travel option ID `train-G5612-18:05`
- train code and real 12306 booking URL
- flight number `CZ355`
- food name, location, and source tags

The same fixture is rendered through the current A2UI helpers and still emits the existing component/data paths. Existing travel, train, flight, food, and partial-provider tests all passed in the 925-test suite.

## Additional Verification

- `node scripts/verify-loopy-backend.mjs`: **236 checks passed**, including `agent_core` HAR build.
- `git diff --check`: passed.
- A2UI snapshot roundtrip search: passed with zero matches.

## Files Changed

- `agent_core/src/main/ets/aiphone/runtime/A2uiTypes.ets`
- `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`
- `entry/src/test/ToolGatewayClient.test.ets`
- `.superpowers/sdd/tasks/domain-task-02-report.md`

## Deliberate Plan Deviations

- `A2uiData.ets` was not changed because the required normalized records already existed there; duplicating or wrapping them would create a second domain model.
- `A2uiBusinessData.test.ets` and `A2uiTrainOptionsState.test.ets` were not changed because their existing tests passed unchanged and the new contract/renderer assertions fit the existing `ToolGatewayClient.test.ets` seam.
- No global HTTP transport seam was added. Deterministic success coverage uses the existing normalized provider-shaped fixtures and pure structured-result builders; real dispatcher coverage uses fail-closed config/argument paths without live network. This task therefore does not claim live provider or device success.
