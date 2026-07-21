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
- Travel errors are retryable only when at least one child error explicitly reports `retryable === true`; source evidence alone never changes retryability.
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

## Independent Review Fix

The first implementation commit `4257d72c17e699039aa9d9a35e6ba0cd4ab32be4` was not approved because it inferred aggregate retryability from provenance, flattened provider operations, conflated successful empty responses with errors, and collapsed code-specific legacy error surfaces.

Fix commit: `a3d224f5695e28a819489ef49d492b6a8e5986b9` (`fix: preserve travel provider semantics`).

### Review RED

Five focused tests were added before the fix. The authoritative Hypium command failed at `UnitTestArkTS` with the expected missing contracts:

- `combineTravelStructuredResults`
- `flightDataResultFromProviderResponse`
- `foodStructuredDataResultFromProviders`
- `flightDataResultA2ui`
- `trainDataResultA2ui`
- `FoodProviderResult.succeeded`
- `FoodProviderResult.operation`

This was a compile RED caused by the reviewed behaviors being absent, not by a test typo.

### Review Fixes

- Aggregate `travel.search` retryability is now the logical OR of only explicit child `error.retryable === true` values. Source-bearing authentication, 4xx, and other nonretryable failures stay nonretryable.
- Food results carry only two additional optional facts: `operation` and `succeeded`. No new provider hierarchy or transport abstraction was added.
- Actual Amap location resolution is recorded as `operation=geocode`; restaurant/provider retrieval is `operation=search`.
- Food sources are deduplicated by provider, backend, and operation. Actual responses and thrown calls create sources; config, missing-location, and other preflight omissions do not.
- Successful zero-result food searches produce `empty`, including when other sources fail. Results plus failures produce `partial`; `error` is reserved for the case where no search provider successfully responded.
- A VariFlight HTTP 2xx response with an empty flight list now produces typed `status=empty` with the real `flights` source.
- Flight and train structured errors retain response/request diagnostics in `warnings`; the legacy A2UI adapter restores code-specific examples and actions such as `补充日期`, `补充城市`, `补充车站名`, `检查 Key`, and `检查供应商返回` without another provider call.

### Review GREEN

Authoritative result:

```text
Tests run: 930, Failure: 0, Error: 0, Pass: 930, Ignore: 0
```

The result file contains successful entries for all five focused review tests:

- aggregate travel retryability from child error flags
- successful VariFlight empty list
- food provenance dedupe and empty/partial/error states
- code-specific flight error A2UI
- code-specific train error A2UI

Additional gates:

- `node scripts/verify-loopy-backend.mjs`: **236 checks passed**, including `agent_core` HAR build.
- `git diff --check`: passed.
- A2UI snapshot roundtrip search: zero matches.
- The known post-test coverage reporter `00507008` noise remains separate from the authoritative zero-failure result.

## Second Independent Review Fix

The same reviewer found two remaining compatibility gaps after the first fix: a failed attempted geocode was still classified as missing configuration, and exceptions that historically reached the outer legacy error surface had acquired new error cards during structured migration.

Fix commit: `3e1ef63b` (`fix: preserve travel exception surfaces`).

### Second Review RED

Four focused behavioral tests were added before production changes. The full Hypium run compiled and failed only on the expected assertions:

- an attempted Amap geocode-only failure returned `FOOD_CONFIG_MISSING` instead of `FOOD_PROVIDER_ERROR`;
- a thrown VariFlight transport failure omitted the legacy title and diagnostics;
- a thrown 12306 station-data load failure omitted the legacy title and diagnostics;
- a 12306 JSON parse failure rendered the newer provider-format card instead of the legacy outer exception surface.

This was a behavioral RED. No unrelated test or ArkTS compilation failure was introduced.

### Second Review Fixes

- Food failure classification now asks whether any real provider operation was attempted, rather than considering only `operation=search`. A failed geocode therefore retains its real `geocode` source, is `FOOD_PROVIDER_ERROR`, and is retryable. `FOOD_CONFIG_MISSING` remains reserved for runs where no provider operation was attempted.
- The existing outer exception A2UI was extracted into one local helper and reused by both the outer legacy catch and the structured adapters. No new error hierarchy or provider call was added.
- `FLIGHT_TRANSPORT_EXCEPTION`, `TRAIN_STATION_LOAD_ERROR`, `TRAIN_TRANSPORT_EXCEPTION`, and the historically thrown 12306 `TRAIN_INVALID_RESPONSE` now render:
  - title `工具供应商调用异常`;
  - the two established network/provider diagnostic rows;
  - exactly one `重新查询` action.
- Structured `DataResult` codes, retryability, warnings, sources, and one-call provider semantics remain intact for Agent consumers.

### Second Review GREEN

Authoritative result:

```text
Tests run: 934, Failure: 0, Error: 0, Pass: 934, Ignore: 0
```

Additional gates:

- `node scripts/verify-loopy-backend.mjs`: **236 checks passed**, including `agent_core` HAR build.
- `git diff --check`: passed.
- The known post-test coverage reporter `00507008` noise remains separate from the authoritative zero-failure result.
