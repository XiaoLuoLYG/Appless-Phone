# Domain Task 03 Report: Maps, Media, Social, and Dynamic Structured Reads

## Scope

- Base commit: `51fc93691c46d123a07d59e5b7f919d3c610c940`.
- Implementation commit: `aa19032dc1b475e818d23024eb488312e9106a67` (`feat: structure maps media and social data`).
- Review-fix commit: `b3fc8e96` (`fix: enforce dynamic read and source truth`).
- Migrated `maps.place.search`, `maps.place.details`, `media.video.search`, `media.aggregate.search`, `youtube.video.search`, `x.post.search`, `social.feed.search`, and the virtual safe-read `dynamic.search` path to structured `DataResult` payloads.
- Preserved the current renderers, media playback actions, SocialHub item/thread IDs, Maps place IDs and empty-query context, and provider-facing errors.
- Did not change the fixed tool registry, action execution, provider configuration, host page, signing, device state, or worktree layout.

## TDD Evidence

### RED

The domain contract tests were added before production implementation. The authoritative Hypium command failed in `UnitTestArkTS` because the required structured contracts and adapters did not exist, including:

- `MapsStructuredData`, typed Maps provider results, and `mapsStructuredDataResult`;
- `GenericStructuredData`, `genericStructuredDataResult`, and media structured rendering;
- `SocialHubStructuredData`, `socialHubStructuredDataResult`, and structured SocialHub rendering;
- `DynamicReadExecution`, `DynamicStructuredData`, and the injected dynamic-read executor seam.

The dynamic safety tests also required writes to fail as `DYNAMIC_WRITE_NOT_ALLOWED` before the executor was called.

During self-review, a focused source-truth assertion was added before its fix. The full suite failed with:

```text
expect local_adapter equals oauth_api
```

This proved that a fixed `Composio X` result was being classified by an overly exact provider-name comparison. The production fix changed only that classification predicate.

The requested review fixes received a second RED cycle before production changes. The authoritative suite first failed behaviorally because limited-only SocialHub input returned `empty` with invented sources, mixed real plus limited input returned `success`, and supported-empty plus limited input exposed the limited platform as a provider source. After the complete adversarial tests were added, `UnitTestArkTS` failed because the selected-slug executor seam, distinct input/output registration schemas, genuine receipt extractor, provider phase, and X post adapter did not yet exist. The test seam records every executor invocation, so rejected selected slugs prove zero calls rather than only checking a helper predicate.

### GREEN

Command:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Fresh authoritative `entry/.test/default/intermediates/test/coverage_data/test_result.txt` at `2026-07-22 02:15:49`:

```text
Tests run: 954, Failure: 0, Error: 0, Pass: 954, Ignore: 0
```

The suite covers all four allowed dynamic verbs (`read`, `search`, `list`, and `get`), rejects write/create/update/delete/send/execute/append/upload/publish plus unknown and ambiguous selected operations, and proves unsafe requests make zero executor calls. Selected-slug cases cover uppercase, punctuation, camel case, compact names, provider prefixes, safe-looking substrings in unknown words, and a caller-claimed fixed-tool ID.

## Implementation

### Structured payloads and source truth

- Maps now keeps typed place records with the real `placeId`, address, rating, coordinates, opening status, Maps URL, and search query. Successful zero-row responses are `empty`; missing input/config and attempted provider failures remain distinct errors.
- Media and YouTube reuse the existing `DynamicGenericToolResult[]` family through `GenericStructuredData`. Real rows plus source failure are `partial`, all-successful zero rows are `empty`, and failure without data is `error`.
- Aggregate search keeps its existing typed videos, posts, and per-source statuses. It never returns `partial` without real videos or posts.
- SocialHub keeps native typed items and connections, including message, channel, account, and thread identifiers. Items plus a connection failure are `partial`; connected zero rows are `empty`; all-provider failure is `error`.
- Fixed X data identifies `Composio X` as `oauth_api`, rather than a local adapter.

### One provider call, two consumers

Each migrated legacy path invokes its structured provider helper once and renders the returned typed data directly:

- Maps -> `mapsDataResultA2ui`;
- video/YouTube -> `mediaVideoStructuredDataA2ui`;
- aggregate -> the existing aggregate renderer;
- SocialHub -> `socialHubStructuredDataA2ui`;
- X and dynamic generic reads -> the existing generic-result renderer.

No adapter parses A2UI or JSONL back into domain data, and no renderer invokes a provider.

### Turn-scoped dynamic safety

- `dynamic.search` remains virtual and is handled before fixed-registry lookup; it was not added to the 44 fixed definitions and no second registry was created.
- Only normalized `read`, `search`, `list`, and `get` selected Composio operations are admitted immediately before each executor invocation. Write-like, ambiguous, or unknown selected slugs return `unsafe_action_blocked` without an executor call. Explicit fixed registry routes use a separate internal trusted entrypoint, so a dynamic caller cannot authorize a write merely by claiming a fixed-tool ID.
- A discovered execution carries provider, qualified name, actual provider `inputSchema`, actual provider `outputSchema`, and a bounded receipt in the current `DynamicStructuredData` and `DataSource`. Receipts are accepted only from explicit request, execution, trace, or tool-call ID fields; raw payloads, previews, row IDs, bodies, and secrets are never promoted. Empty receipts are omitted from `DataSource`. The next execution gets a fresh object; tests prove earlier receipt metadata does not leak.
- ModelScope registrations are ephemeral execution records. The existing dynamic registry remains only for the pre-existing non-virtual dynamic aliases.

### X and SocialHub source truth

- Composio results now carry an explicit discovery/execution phase. `x.post.search` accepts only an executed X post read whose provider payload contains a real post ID plus content or URL. A discovery mismatch or fallback is an error, and an executed zero-post payload is `empty`; discovery rows are never relabeled as post data.
- WhatsApp, Discord, and LinkedIn `limited` SocialHub paths remain local capability notices and do not invoke a provider. Limited or disabled connections are warnings, not sources. Limited-only input returns `SOCIAL_SOURCES_UNSUPPORTED` with no sources; real data plus limited input is `partial`; supported-empty plus limited input is `empty` with only the attempted supported source.

## Verification

- Full Hypium: **954/954 passed**, zero failures and zero errors.
- `node scripts/verify-loopy-backend.mjs`: **236 checks passed**, including the `agent_core` HAR build.
- `git diff --check`: passed.
- Fixed-registry scan: **44 definitions, 44 unique IDs**, and `dynamic.search` is absent from the fixed array.
- Structured-interface scan: no `createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`, or `jsonl` fields in `MapsStructuredData`, `GenericStructuredData`, `DynamicStructuredData`, or `SocialHubStructuredData`.
- Hypium serialization assertions independently scan every Task 3 dispatcher result for A2UI envelope keys.

## Files Changed

- `agent_core/src/main/ets/agent/message/DataResult.ets`
- `agent_core/src/main/ets/agent/message/DataResultFactory.ets`
- `agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets`
- `agent_core/src/main/ets/aiphone/runtime/DynamicToolTypes.ets`
- `agent_core/src/main/ets/aiphone/runtime/MapsApiClient.ets`
- `agent_core/src/main/ets/aiphone/runtime/MediaVideoToolA2ui.ets`
- `agent_core/src/main/ets/aiphone/runtime/SocialHubA2ui.ets`
- `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`
- `agent_core/src/main/ets/composio/ComposioSessionClient.ets`
- `entry/src/test/AggregateSearchA2ui.test.ets`
- `entry/src/test/DynamicToolDiscovery.test.ets`
- `entry/src/test/MapsApiClient.test.ets`
- `entry/src/test/MediaVideoToolA2ui.test.ets`
- `entry/src/test/SocialHubA2ui.test.ets`
- `entry/src/test/ToolGatewayClient.test.ets`
- `.superpowers/sdd/tasks/domain-task-03-report.md`

## Deliberate Plan Deviations

- `MapsApiClient.ets` owns the real Places payload boundary, so the typed place/provider result was added there instead of reconstructing native place records inside the gateway.
- `ComposioDynamicBackend.ets` is the last point that still has the discovered tool schema; it attaches temporary registration metadata for the dynamic structured adapter, which removes the per-row copy after promoting it to the turn-scoped result.
- Fixed Composio routes now enter through an internal fixed-contract function rather than caller-supplied dynamic arguments. This preserves confirmed fixed actions while making the public dynamic search/execute seam fail closed on the actual selected slug.
- `DataResult` gained one optional `DataSource.receipt` field so the required dynamic receipt is preserved alongside provider and operation without a parallel metadata store. Undefined receipts are omitted from existing JSON output.
- `ToolGatewayClient.test.ets` adds fixed-dispatch coverage because the task requires every listed fixed tool to avoid `STRUCTURED_ADAPTER_MISSING` and rendered payloads.

## Concerns and Evidence Boundary

- Hvigor continues to emit the pre-existing coverage reporter error `00507008` (`getInitCoverageData failed`) after test execution, while exiting successfully. The freshly written authoritative result file is complete and reports 954/954.
- This task used deterministic provider-shaped fixtures and fail-closed configuration paths. It does not claim live-provider, signed-package, or device evidence.
