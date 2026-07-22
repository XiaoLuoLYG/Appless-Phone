# Domain Task 08 Report: Complete Multi-Agent Action Ownership

## Scope

- Base commit: `c52e718d0783f399ea748f32fcc99dbc1a80004e`.
- Product commit: `70882b7d` (`feat: complete multi-agent action ownership`).
- All **20 fixed Action Agent definitions** now have an explicit registered owner route; the Task 8 deferred allowlist and `ACTION_ROUTE_DEFERRED` result are removed.
- Migrated the seven remaining external writes: `luckin.order.create`, `calendar.event.create`, `calendar.event.update`, `calendar.event.delete`, `whatsapp.message.send`, `ride.order.create`, and `ride.order.cancel`.
- Preserved the existing rendered UI IDs, labels, card lifecycle, provider adapters, and public optional `calendar.event.update` input schema.
- Kept work-item and knowledge writes on their existing review-required preview/prepare client actions. They were not promoted into fixed executable ToolDefinitions.
- Kept `dynamic.search` read-only; this task did not authorize dynamic writes.

## Exact Surface and Confirmation Boundaries

- Registered page ownership is derived from the canonical 20 Action definitions instead of a second hand-maintained subset.
- Exact rendered aliases map to their fixed owners: Calendar delete confirm, WhatsApp send confirm, Ride estimate confirm, Ride order cancel, and Luckin create.
- Migrated candidates are terminal. Authority, snapshot, policy, handler, or provider failure cannot fall through to a legacy tool call or natural-language submission.
- Existing generation/fingerprint, current-surface argument authorization, and bounded replay identity checks remain in force.
- Natural language cannot synthesize any of the seven writes directly. Only the existing exact World Cup and structured Maps virtual routes remain.

## Domain Safety

- **Calendar:** create/update require a real provider Event ID; selector lookup is fail-closed when incomplete or ambiguous. Delete uses the exact visible Event ID and rendered confirm action. Payload `confirmed` flags were removed without making the public update fields required.
- **Luckin:** create requires the exact current preview button and exact current SKU/options. Stale or mutated create arguments are rejected. Provider success requires a returned order ID with no inner error; the request order ID is never reused as a success receipt.
- **WhatsApp:** only the normalized E.164 target configured as `AIPHONE_WHATSAPP_TEST_TO` can reach confirmation/provider execution. Missing or mismatched configuration is blocked without guessing a number. The exact current confirm action is required and no payload confirmation flag remains.
- **Ride:** create requires the exact current estimate action, trace, route, and vehicle; cancel requires the exact current order action and order ID. A Ride app link cannot resolve into an order action. Create needs a provider order ID and cancel needs an explicitly positive cancel status.
- **Provider truth:** every migrated external write must finish with a matching success result plus positive receipt/status evidence. Missing, paused, malformed, explicit inner failure, auth/config error, cancellation, or provider error is terminal and cannot be reported as success.

## TDD Evidence

### Initial RED

Tests were added before the Task 8 seams and failed ArkTS compilation on the intentionally absent APIs/routes, including `rideCreateOrderResultForTest`, `luckinOrderCreateSucceededForTest`, `whatsAppSafeTargetAllowedForTest`, and the flag-free confirmation signatures. The minimum implementation then made the full suite green.

### Provider-evidence RED -> GREEN

Self-review found that the page completion gate accepted the mere presence of raw `status` or `id` fields as positive evidence. A regression with `{"status":"failed","id":"message-fake"}` was added first. The authoritative run at `2026-07-22T08:13:43+0800` reported:

```text
Tests run: 1053, Failure: 1, Error: 0, Pass: 1052, Ignore: 0
```

The gate now accepts only explicit `success:true` / `successful:true`, the trusted Calendar delete marker, or a non-empty receipt/status/Event ID/Message ID/Order ID result row on a matching successful tool result. The next run passed 1053/1053.

Additional passing regressions prove that Ride app-link results cannot become orders and that stale Ride traces or wrong cancel order IDs are rejected.

## Final Verification

Authoritative command:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Fresh authoritative `entry/.test/default/intermediates/test/coverage_data/test_result.txt` at `2026-07-22T08:17:07+0800`, for the exact product tree committed as `70882b7d`:

```text
Tests run: 1054, Failure: 0, Error: 0, Pass: 1054, Ignore: 0
```

- Full Hypium: **1054/1054 passed**, zero failures and zero errors.
- `node scripts/verify-loopy-backend.mjs`: **245 checks passed**, including public/runtime semantic equality, optional Calendar update fields, and successful `agent_core` HAR builds.
- Appless repository audit: **44 fixed tools**, **2 runtime virtual tools**, **36 actions**, and **69 capabilities**. `missingMatrix`, `missingDocs`, `registryOnlyTools`, `modelOnlyTools`, and `excludedQueriesInSmoke` are all empty; only the expected review-required social/work/knowledge entries remain.
- `node scripts/aiphone-device-smoke.mjs --list-cases`: passed and listed the repository smoke cases without running a device or provider action.
- Stale-pattern scans found no `ACTION_ROUTE_DEFERRED` and no Calendar/WhatsApp/Ride payload confirmation flags. `git diff --check` passed.
- Hvigor still emits the known coverage reporter `00507008` JSON parse noise after Hypium completes. It is separate from the fresh, complete, green authoritative result file.

## Regression Coverage

- Exact count and explicit registered ownership for all 20 Action definitions.
- Exact aliases and terminal no-legacy-fallthrough behavior for all migrated rendered candidates.
- Fake Calendar create Event ID propagation through update/delete, plus incomplete and ambiguous selector rejection.
- Exact Luckin current SKU/button authorization, stale mutation rejection, replay protection, and provider order receipt requirement.
- WhatsApp missing/mismatched safe-target rejection, exact confirmation identity, provider/auth failure handling, and removal of payload confirmation flags.
- Ride exact current trace/order authorization, app-link separation, provider order receipt, and positive cancel status.
- Seven-write provider completion evidence, including malformed and explicit inner-failure rejection.
- Public/runtime registry semantic equality, 44/24/20 counts, optional Calendar update contract, dynamic-write rejection, and unchanged work/knowledge review boundaries.

## Evidence Boundary

- This report claims deterministic unit/integration routing, current-surface authority, lifecycle, structural verifier, capability-audit, and HAR-build evidence only.
- It does not claim a live Calendar mutation, Luckin order, WhatsApp send, Ride order/cancel, connected-account success, signed HAP, device run, or end-to-end provider receipt.
- No automated test used a live WhatsApp target or invoked a provider write.
