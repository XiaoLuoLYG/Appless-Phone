# Domain Task 04 Report: Account and Remaining Read Data

## Scope

- Base commit: `7a076147620e27fd9ea37603567004cd54283d29`.
- Implementation commit: `7810e8d094f2af7da81f0bbe42fdd77132c80c51` (`feat: structure account and remaining read data`).
- Migrated `mail.search`, `mail.thread.read`, `gmail.mail.search`, `gmail.thread.read`, `youtube.mine.playlists`, `youtube.mine.subscriptions`, `calendar.events.search`, `luckin.order.status`, `ride.estimate`, `ride.app.link`, and `ride.driver.location` to structured `DataResult` dispatch.
- Preserved current renderers, reply/draft actions, ride deep links and status actions, Luckin payment/status actions, and provider-facing errors.
- Did not change the 44 fixed tool definitions, action ownership, provider configuration, signing, device state, branch, or worktree layout.

## TDD Evidence

### RED

Tests were added before production changes. The authoritative full Hypium command failed in `UnitTestArkTS` because the Task 4 contracts did not exist:

- `gmailSearchStructuredDataFromResults` and `gmailSearchStructuredDataA2ui`;
- `mailThreadSummary` and `mailSearchStructuredDataA2ui`;
- `remainingReadStructuredDataResult`;
- all 11 structured dispatcher branches still returned `STRUCTURED_ADAPTER_MISSING`.

The RED log is `/tmp/domain-task-04-red.log`. Production files were unchanged when that failure was captured.

### GREEN

Command:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Fresh authoritative `entry/.test/default/intermediates/test/coverage_data/test_result.txt` at `2026-07-22T03:01:55+0800`:

```text
Tests run: 966, Failure: 0, Error: 0, Pass: 966, Ignore: 0
```

## Implementation

### Mail and Gmail identity contracts

- Search results use typed thread summaries with exact provider, `requestKey`, thread/message IDs, sender, recipients, subject, snippet, and timestamp. Gmail request keys are `gmail:<threadId>`; QQ keys use the message ID.
- Search normalization deliberately omits provider message bodies. Full `body`/`bodyHtml` appear only in `mail.thread.read` or `gmail.thread.read` after exact request-key and provider identity validation.
- Missing, mismatched, or stale detail identities fail before provider execution. A valid Gmail detail fixture proves one provider call, exact identity preservation, and decoded full-body delivery.
- Existing Gmail and aggregate-mail renderers consume the normalized summaries directly, preserving reply identities and existing auth/error cards.

### Remaining read source truth

- `remainingReadStructuredDataResult` keeps normalized provider results and actions while distinguishing `success`, `partial`, `empty`, auth errors, input errors, and attempted provider errors.
- Missing credentials/configuration produce no source. Successful empty results and attempted transport/inner-provider failures carry their actual source. Retryability is limited to transport, network, timeout, DNS, and 5xx evidence.
- YouTube account reads remain authenticated-account routes and are not substituted with public video search. Calendar preserves exact event IDs from the existing normalizer.
- Ride read providers now return normalized result arrays once; the legacy renderer consumes the same arrays. Full estimate trace IDs, Didi/Amap deep links, order IDs, driver IDs, and current refresh/cancel actions are retained.
- Luckin status now returns a normalized provider result once; exact order/trace IDs and current payment/status actions survive structured serialization. Provider payload errors do not become success.

### One provider call, two consumers

- Gmail search/detail tests record exactly one fallback client call per structured request and zero calls for invalid detail identity.
- Calendar, YouTube, ride reads, and Luckin status each expose a provider/normalizer helper that is consumed by both `DataResult` and the existing renderer.
- No Task 4 adapter parses A2UI or JSONL back into domain data, and no renderer calls a provider.

### Ponytail full

- Reused the existing `DynamicGenericToolResult`, `DataResult` factories, provider normalizers, and renderers.
- Added no dependency, registry, parallel transport, compatibility agent, or speculative abstraction.

## Verification

- Full Hypium: **966/966 passed**, zero failures and zero errors.
- `node scripts/verify-loopy-backend.mjs`: **236 checks passed**, including the `agent_core` HAR build.
- `git diff --check`: passed.
- Fixed registry remains **44 definitions with 44 unique IDs**; Task 4 added no definition.
- All 11 Task 4 dispatch results are asserted not to return `STRUCTURED_ADAPTER_MISSING` and not to serialize `createSurface`, `updateComponents`, `updateDataModel`, or `jsonl` keys.
- Provider-shaped tests cover Gmail summary/body separation, exact request identities, provider-once execution, YouTube/Calendar success-empty-error truth, and exact Luckin/ride IDs, deep links, and actions.

## Files Changed

- `agent_core/src/main/ets/aiphone/runtime/GmailToolA2ui.ets`
- `agent_core/src/main/ets/aiphone/runtime/MailToolA2ui.ets`
- `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`
- `entry/src/test/CalendarApiClient.test.ets`
- `entry/src/test/GmailToolA2ui.test.ets`
- `entry/src/test/GmailToolNormalizer.test.ets`
- `entry/src/test/MailToolA2ui.test.ets`
- `entry/src/test/RideToolResultsState.test.ets`
- `entry/src/test/ToolGatewayClient.test.ets`
- `entry/src/test/YouTubeApiClient.test.ets`
- `.superpowers/sdd/tasks/domain-task-04-report.md`

## Concerns and Evidence Boundary

- Hvigor still emits the pre-existing coverage reporter error `00507008` after test execution while exiting successfully. The freshly written authoritative result file is complete and reports 966/966.
- Verification used deterministic provider-shaped fixtures and fail-closed missing-configuration paths. This task does not claim live-provider, signed-package, or device evidence.
