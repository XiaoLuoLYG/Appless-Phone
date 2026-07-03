# AIPhoneDemo Agent Payment Design

Date: 2026-07-03
Status: approved design, implementation not started

## Goal

Add a demo-first payment capability to AIPhoneDemo so the user can say things like "给 Alex 转 5 美元" and complete a real Stripe payment inside the app. The recipient can be a normal saved account, not necessarily an agent.

This is a real-payment demo path, not a full wallet product. It must never create a Stripe payment session without explicit user confirmation.

## Approved Decisions

- Funding flow: user pays a saved recipient account.
- Recipient identity: local account book maps names, aliases, or emails to Stripe connected account IDs.
- Account creation in MVP: manual local entry only, with a few preseeded demo accounts.
- Payment UI: fully inside the app, using Stripe Embedded Checkout in ArkWeb.
- Stripe integration shape: HAP direct Stripe, demo-first.
- Mode: test/live switch, default test.
- Amount behavior: if the query includes an amount, show preview; if amount is missing, show quick amount buttons and custom input.
- First implementation option: one fixed `payment.send` tool, not generic Stripe MCP.

## Product Scope

In scope:

- `payment.send` tool with `recipient`, `amount`, `currency`, and optional `note`.
- Local `PaymentAccountBook` with preseeded accounts and manual add/edit.
- Payment amount validation, currency normalization, and live-mode amount cap.
- A2UI payment cards for missing account, missing amount, confirmation, receipt, cancel, and error states.
- Stripe Embedded Checkout rendered in app WebView.
- Stripe test/live configuration stored like the existing local provider credentials.
- Idempotency key per confirmed payment attempt.

Out of scope:

- Wallet balance, stored value, or internal ledger.
- Refunds, disputes, payouts, subscriptions, invoices, or recurring payments.
- Stripe Connect onboarding for new recipients.
- Unlisted recipient payments.
- Model-initiated payment without a visible confirmation tap.
- Generic Stripe MCP execution for money movement.
- Automatic retry after failure.

## Architecture

The smallest stable path is:

1. The model selects `payment.send` and emits structured args.
2. The payment tool normalizes and validates recipient, amount, currency, mode, and note.
3. If recipient is unknown, the tool returns an account selection/add card.
4. If amount is missing, the tool returns an amount completion card.
5. If all inputs are valid, the tool returns a payment confirmation card.
6. User taps "继续支付".
7. The app creates a Stripe Embedded Checkout Session using the configured Stripe mode and the recipient connected account ID.
8. The app opens a Stripe checkout WebView using only the publishable key and Checkout Session client secret.
9. On completion, cancel, or failure, the app renders an A2UI receipt or error card.

This follows AIPhoneDemo's existing pattern: fixed ArkUI/A2UI components plus runtime data binding. The payment-specific logic belongs under `agent_core/src/main/ets/aiphone/payment`; ArkUI rendering and WebView handling stay under `entry`.

## Components

### Tool definition

Add a registered tool:

- `toolId`: `payment.send`
- `domain`: `payment`
- `intent`: `payment.send`
- `riskLevel`: `confirm_required`
- `backendPriority`: `local_adapter`
- `authModes`: `provider_key`
- `inputSchema`: `paymentSendRequest`
- `outputSchema`: `paymentSession`
- `a2uiComponent`: `PaymentIntentCard`
- `actions`: `payment.confirm`, `payment.cancel`, `payment.account.add`

The model prompt should describe it as: use for explicit payment or transfer requests to saved accounts; never infer an amount; never use for unknown recipients; expect a confirmation card before Stripe session creation.

### Account book

`PaymentAccountBook` stores local records:

```json
{
  "id": "alex",
  "displayName": "Alex Chen",
  "aliases": ["Alex", "alex@example.com"],
  "email": "alex@example.com",
  "stripeAccountId": "acct_...",
  "enabled": true
}
```

The MVP can persist this in the same local configuration style used by existing provider setup. Do not track local secrets or real account IDs in git.

### Payment validation

Validation rules:

- Recipient must resolve to exactly one enabled account.
- `stripeAccountId` must start with `acct_`.
- Amount must be positive and converted to minor units.
- Currency defaults to `USD` only when the user did not specify a currency and the UI explicitly shows that default.
- Live mode requires recipient allowlist and `STRIPE_LIVE_MAX_AMOUNT_MINOR`.
- The confirmation card must show recipient, account hint, amount, currency, mode, and note before creating the Stripe session.

### Stripe client

`StripePaymentClient` is a tiny wrapper around Stripe HTTP APIs:

- Create Embedded Checkout Session.
- Retrieve Checkout Session for receipt status.
- Use idempotency key on session creation.
- Pass `payment_intent_data[transfer_data][destination] = acct_...`.
- Use latest Stripe API version from the Stripe skill baseline: `2026-02-25.clover`, unless Stripe account compatibility forces a pinned version.

No Stripe secret or restricted key is injected into HTML. The key is only used by native app-side HTTP code.

### WebView checkout

Use a dedicated payment WebView or reuse the existing ArkWeb loading pattern from `HtmlHomeSurfaceView`.

The HTML loads Stripe.js, initializes Embedded Checkout with the publishable key and `client_secret`, then posts completion/cancel events back through an app bridge. The WebView does not receive the restricted key.

## UI States

### Missing recipient

Shown when the query recipient is unknown or ambiguous. The user can select a saved account or add a local account with `displayName`, optional `email`, aliases, and `stripeAccountId`.

### Missing amount

Shown when the query names a valid recipient but not an amount. It offers quick amounts and a custom input. Selecting an amount returns to the confirmation card.

### Confirmation

Shown for every valid payment request before any Stripe session is created. Primary action is "继续支付"; secondary action is "取消".

### Embedded checkout

Shows Stripe Embedded Checkout inside the app. The app does not collect raw card data.

### Receipt or error

Success shows the Checkout Session ID, PaymentIntent ID if available, recipient, amount, currency, mode, and timestamp. Cancel and failure states show plain recovery actions. The app does not auto-retry.

## Error Handling

- Missing Stripe config: show a setup card with exact missing keys.
- Unknown recipient: show account card.
- Missing amount: show amount card.
- Live amount above cap: block before Stripe session creation.
- Stripe API error: show error card with sanitized Stripe error type/message, no secret values.
- WebView load failure: show retry action that reuses the same pending payment attempt where possible.
- Duplicate confirm tap: disable the confirm button while a session is being created.
- Repeated request: idempotency key prevents duplicate Checkout Session creation for the same confirmed attempt.

## Stripe Setup Steps

1. Create or open a Stripe account.
2. In the Stripe Dashboard, keep **Test mode** on for the first demo.
3. Open **Developers > API keys**.
4. Copy the test publishable key `pk_test_...`.
5. Create a restricted test key, or use `sk_test_...` only for local demo if restricted permissions block Checkout Session creation.
6. For a restricted key, start with the minimum useful permissions:
   - Checkout Sessions: write and read.
   - PaymentIntents: write and read.
   - Connect Accounts: read.
7. Open **Connect > Accounts** in test mode.
8. Create or select test connected accounts and copy their IDs, each beginning with `acct_`.
9. Add local config:

```env
STRIPE_MODE=test
STRIPE_TEST_PUBLISHABLE_KEY=pk_test_...
STRIPE_TEST_RESTRICTED_KEY=rk_test_...
STRIPE_LIVE_PUBLISHABLE_KEY=
STRIPE_LIVE_RESTRICTED_KEY=
STRIPE_DEFAULT_CURRENCY=USD
STRIPE_LIVE_MAX_AMOUNT_MINOR=500
```

10. Add local account records mapping display names or emails to `acct_...`.
11. Run test mode with Stripe test cards.
12. Only after test mode works, add live publishable and restricted keys, keep the live amount cap low, and test with a tiny amount.

## Testing

Add one small runnable check for non-UI logic:

- account alias resolution.
- unknown recipient blocked.
- missing amount returns needs-amount state.
- live mode above cap blocked.
- amount converts to minor units correctly.

Manual smoke:

- "给 Alex 转 5 美元" shows confirmation before Stripe.
- "给 Alex 转账" shows amount completion.
- "给 unknown@example.com 转 5 美元" shows account add/select.
- In test mode, completing Embedded Checkout returns a receipt.
- In live mode, amount above cap is blocked before Stripe.

## Implementation Notes

- Prefer deletion and reuse: use existing A2UI action handling and ArkWeb bridge patterns.
- Keep payment code out of dynamic MCP discovery for MVP.
- Do not add a wallet abstraction.
- Do not add a backend abstraction until the demo-first HAP path is verified.
- Keep all real keys and real connected account IDs out of tracked source.

## References

- Stripe Embedded Checkout: https://docs.stripe.com/checkout/embedded/quickstart
- Stripe Connect Accounts v2: https://docs.stripe.com/connect/accounts-v2
- Stripe restricted API keys: https://docs.stripe.com/keys/restricted-api-keys
- Stripe MCP: https://docs.stripe.com/mcp
