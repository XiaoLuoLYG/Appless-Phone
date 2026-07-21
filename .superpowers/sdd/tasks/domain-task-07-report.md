# Domain Task 07 Report: Confirmed Gmail Reply Send

## Scope

- Base commit: `f6a0eb69`.
- Product commit: `3cf12d05` (`feat: migrate confirmed gmail reply send`).
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

## Final Verification

Authoritative command:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Fresh authoritative `entry/.test/default/intermediates/test/coverage_data/test_result.txt` at `2026-07-22T06:45:19+0800`:

```text
Tests run: 1034, Failure: 0, Error: 0, Pass: 1034, Ignore: 0
```

- Full Hypium: **1034/1034 passed**, zero failures and zero errors.
- `node scripts/verify-loopy-backend.mjs`: **237 checks passed**, including a successful `agent_core` HAR build.
- Repository-native registry/docs/matrix/smoke audit: **44 unique fixed tools = 24 Data + 20 Action**, **0 blocked**, **36 unique action offers**, **69 total fixed/action/virtual capabilities**; no registry/model, ownership-matrix, fixed-doc, or smoke-ID drift.
- `git diff --check`: passed.
- Hvigor still emits the known coverage reporter `00507008` JSON parse noise after Hypium completes; the authoritative result file is complete and green.
- The requested filenames `scripts/verify-agent-backend.mjs` and `scripts/audit-capability-coverage.mjs` do not exist in this branch, any repository ref, or the main checkout. They were not invented or reported as passing; the existing authoritative verifier and an inline repository-native audit were used.

## Regression Coverage

- Registry contract and zero blocked tools.
- Model registry hides `gmail.message.send`; Gmail compose/send language remains draft-first.
- Exact current Gmail click executes once with no paused/second-confirmation result.
- Thread, message, request key, provider, recipient, empty body, stale surface, replay, and provider failure reject without a second side effect.
- QQ `html_mail_reply_send` stays on its existing client route.
- Provider failure reaches the action result and current reply UI without fake success or legacy retry.

## Evidence Boundary

- This report claims deterministic unit/integration routing, exact-action authority, lifecycle, structural verifier, capability-audit, and HAR-build evidence only.
- It does not claim a live Gmail send, live QQ send, connected-account success, signed HAP, device run, or end-to-end provider receipt.
- Automatic regression must continue to avoid sending to real contacts; a later dedicated safe-target manual/device gate is still required for live Gmail reply-send evidence.
