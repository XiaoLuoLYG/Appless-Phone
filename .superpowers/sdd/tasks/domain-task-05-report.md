# Domain Task 05 Report: Structured Multi-Agent Results

## Scope

- Base commit: `be3bcad6173974bc478b3300b14796bbdc2c20c1`.
- Target commit message: `feat: render structured multi-agent results`.
- Independent-review fix commit: `6a06e551` (`fix: harden structured result rendering`).
- Added one generic `UiTaskRenderer` and one registry-backed `ActionOfferResolver` for the existing structured Data families.
- Wired both as `MultiAgentRuntime` defaults while preserving injected renderer/resolver compatibility.
- Did not migrate action execution or sends, change the 44 fixed tool definitions, modify providers, or change branch/worktree layout.

## TDD Evidence

### Initial RED

`StructuredToolUiRenderer.test.ets` and its `List.test.ets` registration were added before production code. The authoritative Hypium command failed in `UnitTestArkTS` because `StructuredToolUiRenderer.ets` and `RegisteredActionOfferResolver.ets` did not exist.

### Adversarial RED and GREEN loops

- Independent review added tests before production edits. The authoritative run at `2026-07-22T04:24:34+0800` failed on eight named assertions covering same-schema aggregation, client-action promotion, logical duplicate detection, opaque IDs, layout content/type mutation, YouTube auth routing, and valid hotel provider errors.
- The next loop reached 994/996; the two remaining failures isolated parser-normalized empty child/data-path sentinels. Serialized references now ignore empty sentinels, and projected layout components omit empty optional defaults before the shared merger.
- A same-hotel aggregate test failed because flattened search/detail offers were rendered twice (`expect 2 equals 1`). The renderer now filters immutable offers through the current tool definition before invoking a canonical renderer.
- A domain-neutral skeleton test failed because the generic renderer reused the hotel/RollingGo pending surface. It now emits a bounded neutral structured-results surface.
- The prompt-redaction test failed when a secret was placed in `CreateUiTaskPayload.intent`. Raw intent is no longer sent to the layout model.
- The accepted-layout test failed because an offer ID embedded correlation and registered-action identity. Offer IDs are now render-local opaque ordinals (`o0`, `o1`, ...); the prompt contains only bounded schema/status summaries, data paths, and offer ID/label/variant.
- Oversized layout output, forged/unknown/duplicate/mutated offers, cross-item identity mismatches, cross-tool aggregate layout, catalog denial, timeout, throw, and malformed output all use the exact deterministic baseline.

### Final GREEN

Command:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Fresh authoritative `entry/.test/default/intermediates/test/coverage_data/test_result.txt` at `2026-07-22T04:32:26+0800`:

```text
Tests run: 996, Failure: 0, Error: 0, Pass: 996, Ignore: 0
```

## Implementation

### Generic structured renderer

- Uses one `switch (data.outputSchema)` and reuses the canonical travel, train, flight, food, hotel, maps, media, aggregate-search, social, mail/Gmail, calendar, YouTube, and generic result renderers.
- Unknown schemas, malformed data, renderer exceptions, and empty input produce an honest bounded error surface; provider payloads are never dumped as generic JSON.
- Multiple results are cloned, rendered independently, then deterministically combined in declared `UiTask.dataTaskIds` order into one surface. Every component ID, child reference, component data path, array update, and scalar update is namespaced by result ordinal, so identical schemas and local IDs cannot deduplicate or overwrite each other.
- Offers are filtered by `toolDefinitionForToolId(data.toolId)?.actions` before each canonical renderer, preventing same-ID cross-tool leakage after `UiAgent` aggregation.
- Multi-tool or ambiguous multi-item offer layouts fail closed to canonical placement. For a single target, the model can author only the component tree/layout plus immutable offer references. Data-bound component types must match the canonical component for that exact path; titles, bodies, text, status, semantic properties, canonical actions, action IDs, and args are projected back from the deterministic baseline or offer map. Unknown/free-text components, type substitution, authored content properties, duplicate paths, or malformed graphs return the exact baseline.
- Layout input is limited to 24 schema/status entries, 24 data paths, and 24 offer ID/label/variant records; prompt length is 4 KiB, model output is 32 KiB, and timeout is capped at 12 seconds.
- YouTube account `AUTH_REQUIRED` now renders a YouTube-specific `ToolConnectCard` (`composio.youtube`) with the YouTube/Composio URLs and `youtube.authorize` / `youtube.open.web` actions; Gmail metadata is absent.
- Normalized hotel search/detail results with `ok:false` stay on the canonical hotel error renderer, while structurally malformed hotel payloads continue to fail closed.

### Registered action offers

- Hotel search/detail offers reuse the existing exact action constructors; mail/Gmail read and SocialHub draft offers are built only from normalized real-item fields; generic embedded prompt actions must match real semantic row identities. Embedded client actions remain only in the canonical UI data and are never promoted into model-visible offers.
- Every candidate must be listed in the source tool definition and pass `ActionCatalog.validatePlacement` with cloned exact args.
- Forged IDs, mutated identities, catalog-denied args, and duplicate logical action/arg pairs fail closed. A bounded recursive canonicalizer sorts object keys, preserves array order, rejects sparse/non-JSON values and dangerous prototype member names, and caps depth, nodes, and serialized size.
- Offer IDs contain no conversation, turn, data-task, local-item, action-ID, or action-arg substring; only the resolver output mapping binds an opaque ordinal to immutable action data.
- Candidate processing is capped at 256, emitted offers at 64, serialized args at 8 KiB, labels at 80 characters, and variants at 24 characters.
- Gmail/QQ request keys, thread/message IDs, subjects, hotel query/occupancy fields, coordinates, and RollingGo booking URLs remain exact.

### Runtime and writer contract

- `MultiAgentRuntimeOptions` keeps injected `uiRenderer` and `actionOfferResolver` support, while making the structured renderer/resolver the defaults and accepting the existing `UiLayoutPlanner` seam.
- `UiAgent.test.ets` strengthens the reverse-arrival aggregate contract: declared result order, exactly one terminal render, one writer, and the same surface for skeleton and result.
- Action execution/send behavior is unchanged and remains owned by the existing Action Agent/executors.

## Simplicity Review

- The renderer remains one class with the required single output-schema switch; the resolver remains one class with one candidate/validation pipeline.
- No extra registry, domain renderer class, transport, dependency, or compatibility layer was added.
- Layout projection stays local to the renderer because it protects that renderer's canonical component/data contract; extracting a second layout abstraction would add an unnecessary compatibility layer.
- YouTube auth rendering is a small local canonical surface and does not change provider or action execution.

## Verification

- Full authoritative Hypium: **996/996 passed**, zero failures and zero errors.
- `node scripts/verify-loopy-backend.mjs`: **237 checks passed**, including a successful `agent_core` HAR build.
- `git diff --check`: passed.
- Fixed registry remains **44 definitions with 44 unique IDs**; Task 5 adds no definition.
- `DataResult` remains domain-only (`toolId`, schema, status, sources, data, warnings, optional error) with no `jsonl`, surface, component, HTML, or rendered-payload field.
- Scoped prompt tests confirm the layout prompt includes no intent, action ID, args, client action, item identity, sources, warnings, provider body, receipt, raw preview, or `data.data`.
- Agent graph scan still shows `UiSurfaceWriter` ownership only in `UiAgent`; runtime wiring remains one Leader, Data, UI, and Action agent on the existing bus.
- Review-fix diff from `d7b1df11` touches only the structured renderer, registered-offer resolver, their test, and this report; no provider/action executor or Task 6+ file changed.
- No device or live-provider run was required for this renderer/resolver task.

## Files Changed

- `entry/src/main/ets/pages/A2uiHome/agent/StructuredToolUiRenderer.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/RegisteredActionOfferResolver.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntime.ets`
- `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntimeTypes.ets`
- `entry/src/test/StructuredToolUiRenderer.test.ets`
- `entry/src/test/UiAgent.test.ets`
- `entry/src/test/List.test.ets`
- `.superpowers/sdd/tasks/domain-task-05-report.md`

## Evidence Boundary

- Hvigor still prints the pre-existing coverage reporter error `00507008` after test execution while exiting successfully. The freshly written authoritative result file is complete and reports 990/990.
- Evidence is deterministic unit/integration, structural verifier, and HAR-build evidence. This task does not claim live-provider, signed-package, or device evidence.
