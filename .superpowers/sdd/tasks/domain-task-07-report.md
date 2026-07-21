# Domain Task 07 Report: Confirmed Gmail Reply Send

## Scope

- Base commit: `f6a0eb69`.
- Product commit: `3cf12d05` (`feat: migrate confirmed gmail reply send`).
- Review-fix product commit: `47691b8e` (`fix: close gmail reply provider gaps`).
- Second-review product commit: `a3452602` (`fix: enforce exact gmail tool selection`).
- Independent review found **0 critical and 3 important** gaps; all three are covered by the review-fix commit and regression tests below.
- Second review found **0 critical and 2 important** gaps; both are covered by the second-review product commit and regression tests below.
- Changed the canonical `gmail.message.send` definition from `blocked` to `confirm_required` with the specified OAuth/mail-reply schemas.
- Kept the visible `html_mail_reply_send` ID, `发送回复` label, composer, AI reply, draft save, and existing `MailReplyUiEvent` UI lifecycle.
- Routed only an exact current Gmail reply button click through the registered Action Agent and the existing `sendConfiguredMailReply` provider path.
- Kept QQ mail reply send on the existing legacy client action and did not relabel it as Gmail.
- Kept unbound natural-language Gmail send draft-first, including a fail-closed reroute if model output invents `gmail.message.send`.

## Exact Surface and Confirmation Boundary

- `RegisteredPageActionRoute` maps `html_mail_reply_send` to canonical `gmail.message.send` only for a Gmail provider command on a current mail/Gmail search or thread surface.
- `HtmlHomeActionPolicy` requires the current card's typed detail identity and binds provider, thread, message, request key, recipient, and the non-empty reply body before routing.
- The already-authorized clicked action is added to the current surface authority only after rendered-snapshot policy, source, generation, and fingerprint validation succeeds.
- `ActionAgent` treats that exact visible button click as the one confirmation, consumes the internal authorization once, and revalidates the full arguments immediately before execution. It does not show or require a second confirmation overlay.
- The registered executor validates the Gmail reply schema and preserves its bounded replay protection before invoking the product callback.
- Stale or same-generation-mutated snapshots, provider mismatch, malformed identity, replay, handler failure, and real provider failure all terminate without legacy fallthrough.

## Provider and UI Truth

- `Index.ets` calls `sendConfiguredMailReply` exactly once for the canonical Gmail action.
- Real success is returned as `ActionExecutionResult` and the existing success `MailReplyUiEvent`.
- Thrown provider/auth/config/network errors become a real error result and error `MailReplyUiEvent`; no receipt or success is fabricated.
- The shared event helper preserves the existing QQ/IMAP draft/send UI behavior.
- This task did not add a provider wrapper, transport, dependency, confirmation UI, coordinator, or alternate mail composer.

## Independent Review Fixes

1. **Exact Gmail write pinning.** `gmail.reply.send` now requires discovery of the exact `GMAIL_REPLY_TO_THREAD` Composio tool. The first review fix protected scored selection but missed the generic singleton fallback. The second-review fix rejects a missing configured exact slug before any singleton fallback, so one read candidate or several non-exact candidates cannot execute. When the exact slug is present among read candidates, only the exact slug executes.
2. **Provider-result truth.** Explicit `successful:false` / `success:false`, nested provider errors, missing result evidence, and malformed non-JSON write responses now fail closed. A write succeeds only with explicit positive provider evidence; read payload behavior and the existing Gmail draft-ID success exception remain intact.
3. **Single-contract and fallback alignment.** The public and runtime registries are compared across every semantic field, `gmail.message.send` is `confirm_required` in both, and the obsolete blocked-send A2UI path is removed. Direct `ToolGatewayClient` Gmail reply execution is now terminally rejected and cannot invoke the provider; the authorized registered current-surface action in `Index.ets` owns the single provider invocation and preserves the real provider/config error without fabricated success.

The generic semantic-registry check also exposed a pre-existing `calendar.event.update` public/runtime `inputSchema` mismatch. The first review fix made the two registries equal by copying the runtime's required-field schema, but that contradicted the model and downstream lookup-first flow: callers may omit unresolved fields, while provider writes remain blocked until `eventId`, `title`, `start`, and `end` are complete. The second-review fix makes every public/runtime update field optional while preserving that downstream write validation.

The pre-existing legacy reply branch in `Index.ets` remains because it is shared with QQ compatibility. Gmail exact current-surface clicks are intercepted by the registered dispatcher, and the no-fallthrough regressions prove the legacy branch does not become a second Gmail provider path.

## TDD Evidence

### Initial RED

Tests were added before the registered Gmail validation seam. The authoritative Hypium command failed ArkTS compilation because `validateGmailReplyActionArgs` did not exist.

### Natural-language safety RED

After the initial implementation, a production-shaped English prompt with model-selected `gmail.message.send` failed:

```text
forces unbound direct Gmail send prompts into a reviewable draft
expect gmail.message.send equals gmail.draft.create
```

Root cause: the safety reroute recognized existing Chinese direct-send phrases but trusted an out-of-contract model-selected send for other prompt wording. The minimal fix unconditionally reroutes any non-button model `gmail.message.send` request to `gmail.draft.create`.

### Mail identity RED

A production-shaped Gmail card, whose AI draft offer omits provider/message identity while its `html_mail_detail_read` action carries them, produced:

```text
allows mail reply submissions only for the matching visible mail card
expect false, actualValue is true
```

Root cause: optional matching treated missing draft-offer identity as a wildcard. The policy now uses the same card's detail action as the required provider/thread/message authority and the draft offer for recipient/reply context.

An intermediate ArkTS fixture literal failed type checking before the behavioral RED; that fixture-only typing error was corrected and was not counted as product behavior evidence.

### Independent review RED -> GREEN

- **Exact write tool:** the first authoritative RED stopped at ArkTS compilation because the new fixed-backend seam did not exist; the exact Gmail mapping assertion was also absent. The minimal implementation added `gmail.reply.send -> GMAIL_REPLY_TO_THREAD` and an injected-client test seam. Regression coverage proves exact-tool absence executes zero providers and exact-tool presence executes that slug once.
- **Provider truth:** the next authoritative RED had three behavioral failures: explicit false, malformed write output, and the fixed Gmail reply path were still reported as success. The parser now requires positive write evidence and propagates false/error/malformed results as terminal errors.
- **Registry/fallback drift:** the next authoritative RED had two behavioral failures: full public/runtime semantic equality failed, and the local Gmail send fallback still returned the obsolete blocked card. After alignment, a further RED proved incomplete reply identity could still reach provider configuration; the gateway now rejects it before provider access.

Each RED was observed before its corresponding production change. The final full-suite GREEN is recorded below.

### Second review RED -> GREEN

- **Exact absence before singleton fallback and Calendar optional contract:** at `2026-07-22T07:35:04+0800`, the authoritative run reported `Tests run: 1042, Failure: 2, Error: 0, Pass: 1040, Ignore: 0`. With exactly one discovered read candidate, the fixed Gmail reply incorrectly returned success instead of a terminal error. The public/runtime Calendar schemas also failed the expected all-optional contract, and the standalone verifier independently failed `Calendar update schema keeps lookup and destination fields optional`. The minimal product change moved exact-slug absence rejection before singleton fallback and changed both registry schemas to the all-optional contract. The next authoritative run passed 1042/1042.
- **One authorized provider executor:** a focused test then required direct gateway Gmail reply execution to terminate without provider access. Its RED had exactly one Hypium failure because the gateway still returned its provider-path result, and the verifier failed `runtime Gmail fallback cannot invoke the reply provider`. The minimal change deleted the duplicate gateway parser, validator, provider/auth branch, and redundant identity test. The registered current-surface action in `Index.ets` remains the authorized provider executor.

The second-review product diff is 65 insertions and 117 deletions across eight files (net -52 lines). This reduction is deliberate: it removes a second provider executor instead of adding another abstraction.

## Final Verification

Authoritative command:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Fresh authoritative `entry/.test/default/intermediates/test/coverage_data/test_result.txt` at `2026-07-22T07:38:31+0800`:

```text
Tests run: 1041, Failure: 0, Error: 0, Pass: 1041, Ignore: 0
```

- Full Hypium: **1041/1041 passed**, zero failures and zero errors. The count decreased by one because the redundant gateway identity test was removed with the deleted gateway provider executor.
- `node scripts/verify-loopy-backend.mjs`: **245 checks passed**, including semantic registry equality, the Calendar all-optional invariant, gateway no-provider ownership, exact Composio slug pinning, and a successful `agent_core` HAR build.
- Repository-native registry/docs/matrix/smoke audit: **44 unique fixed tools = 24 Data + 20 Action**, **0 blocked**, **36 unique action offers**, **69 total fixed/action/virtual capabilities**; no registry/model, ownership-matrix, fixed-doc, or smoke-ID drift.
- `node --check scripts/aiphone-device-smoke.mjs`, `node --check scripts/verify-loopy-backend.mjs`, stale-pattern scan, and `git diff --check`: passed.
- Hvigor still emits the known coverage reporter `00507008` JSON parse noise after Hypium completes; the authoritative result file is complete and green.
- The requested filenames `scripts/verify-agent-backend.mjs` and `scripts/audit-capability-coverage.mjs` do not exist in this branch, any repository ref, or the main checkout. They were not invented or reported as passing; the existing authoritative verifier and an inline repository-native audit were used.

## Regression Coverage

- Registry contract and zero blocked tools.
- Full semantic equality for all public/runtime tool-definition fields, including risk, backend, auth, schemas, A2UI component, and actions.
- Model registry hides `gmail.message.send`; Gmail compose/send language remains draft-first.
- Fixed Gmail execution requires `GMAIL_REPLY_TO_THREAD`; read-only discovery results cannot execute in its place.
- Explicit false, missing-evidence, nested-error, and malformed write responses cannot produce a sent result.
- Exact current Gmail click executes once with no paused/second-confirmation result.
- Thread, message, request key, provider, recipient, empty body, stale surface, replay, and provider failure reject without a second side effect.
- Direct gateway Gmail reply execution terminates before provider access; only the registered exact current-surface action owns Gmail reply provider execution.
- QQ `html_mail_reply_send` stays on its existing client route.
- Provider failure reaches the action result and current reply UI without fake success or legacy retry.

## Evidence Boundary

- This report claims deterministic unit/integration routing, exact-action authority, lifecycle, structural verifier, capability-audit, and HAR-build evidence only.
- It does not claim a live Gmail send, live QQ send, connected-account success, signed HAP, device run, or end-to-end provider receipt.
- Automatic regression must continue to avoid sending to real contacts; a later dedicated safe-target manual/device gate is still required for live Gmail reply-send evidence.
