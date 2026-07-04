# AIPhoneDemo Agent Payment Design

Date: 2026-07-04
Status: approved design, implementation pending

## Goal

Add two clearly separated payment scenarios to AIPhoneDemo:

1. **PayPal account payment**: for requests like `用 PayPal 给 Alex 转 5 美元`.
2. **Stripe merchant payment**: for requests like `用 Stripe 给 Demo Vendor 付 5 美元`, and later `用 Stripe 给 <真实商户名> 支付 1 美元`.

This is a real-payment demo path, not a wallet product. The app must never create an external payment session or capture a payment without a visible user confirmation tap.

## Product Boundary

### PayPal account payment

PayPal is the default path for "account-to-account" language in this demo.

The precise model is: the payer uses their personal PayPal account, card, or bank option in PayPal approval UI, and the PayPal Order specifies a different `payee` by `email_address` or `merchant_id`.

This is **not** a PayPal Friends & Family private P2P API. PayPal does not expose a generic third-party API that silently transfers from a user's personal PayPal account to any other personal account. The payer must approve through PayPal-controlled UI.

For live API credentials, PayPal may still require a merchant or verified API caller account. That is a credential/setup constraint, not the payer identity. If the user cannot obtain the required live credentials, live PayPal payment is blocked; sandbox testing can still use PayPal developer sandbox accounts.

### Stripe merchant payment

Stripe remains the merchant/platform payment path. It uses Stripe Checkout/Connect semantics and is appropriate for paying a merchant, seller, or connected account.

Stripe should not be described as personal-account P2P.

Stripe real-merchant payment is feasible only when the merchant is represented by a real live connected account that has completed the required onboarding/capabilities. The app cannot pay an arbitrary external merchant by email or name unless that merchant is first added as a Stripe connected account or otherwise exposes a compatible Stripe payment path.

## Approved Decisions

- One user-facing tool remains enough: `payment.send`.
- Add an explicit provider dimension: `paypal` or `stripe`.
- A saved account can contain PayPal fields, Stripe fields, or both.
- Provider selection rules:
  - PayPal-only target defaults to PayPal account payment.
  - Stripe-only target defaults to Stripe merchant payment.
  - Targets with both providers show a provider choice before checkout.
  - Explicit prompts like `用 PayPal...` or `用 Stripe...` override the default when the target supports that provider.
- Amount behavior stays unchanged: if amount is present, show preview; if missing, show amount completion.
- Payment UI stays in app as much as the provider permits:
  - Stripe uses Embedded Checkout in ArkWeb.
  - PayPal uses PayPal approval/Checkout inside ArkWeb if allowed; if PayPal blocks WebView approval on device, report the exact blocker instead of claiming full in-app completion.
- Stripe must support both sandbox demo merchants and real live connected merchants, guarded by a low live amount cap and connected-account allowlist.
- Credentials and real account IDs remain local-only and untracked.

## Product Scope

In scope:

- `payment.send` tool with `recipient`, optional `provider`, `amount`, `currency`, and optional `note`.
- Local account book with preseeded demo accounts and manual add/edit.
- PayPal account fields: `paypalEmail`, `paypalMerchantId`.
- Stripe account field: `stripeAccountId`.
- Provider-aware validation, amount normalization, and live-mode caps.
- Confirmation cards that show provider, recipient, account hint, amount, currency, mode, and note.
- PayPal Order creation, approval, capture, status/receipt rendering.
- Stripe Embedded Checkout session creation, status/receipt rendering.
- Stripe live merchant payment for allowlisted connected accounts after setup.
- One runnable unit check for provider selection and validation.
- Device smoke for one PayPal query and one Stripe query.

Out of scope:

- Wallet balance, stored value, internal ledger, or app-side custody.
- PayPal Friends & Family automation.
- PayPal Payouts.
- Refunds, disputes, subscriptions, invoices, or recurring payments.
- Automatic onboarding for PayPal sellers or Stripe connected accounts.
- Unlisted recipient payments.
- Generic payment provider framework.
- Generic Stripe or PayPal MCP execution for money movement.
- Automatic retry after failure.

## Architecture

The smallest stable path is:

1. The model selects `payment.send` and emits structured args.
2. The local payment tool normalizes recipient, provider, amount, currency, mode, and note.
3. If recipient is unknown, return an account selection/add card.
4. If provider is missing and the account supports both providers, return a provider choice card.
5. If amount is missing, return an amount completion card.
6. If all inputs are valid, return a provider-aware confirmation card.
7. User taps `继续支付`.
8. The app creates exactly one provider session/order:
   - PayPal: create Order with `purchase_units[].payee`.
   - Stripe: create Embedded Checkout Session for the connected account.
9. The app opens the provider checkout UI.
10. On completion, cancel, or failure, render an A2UI receipt or error card.

Payment-specific core logic belongs under `agent_core/src/main/ets/aiphone/payment`. ArkUI rendering and ArkWeb handling stay under `entry`.

## Tool Definition

Use the existing local tool shape:

- `toolId`: `payment.send`
- `domain`: `payment`
- `intent`: `payment.send`
- `riskLevel`: `confirm_required`
- `backendPriority`: `local_adapter`
- `authModes`: `provider_key`
- `inputSchema`: `paymentSendRequest`
- `outputSchema`: `paymentSession`
- `a2uiComponent`: `PaymentIntentCard`
- `actions`: `payment.confirm`, `payment.cancel`, `payment.amount.select`, `payment.provider.select`, `payment.account.add`

Prompt guidance:

- Use this only for explicit payment/transfer requests to saved accounts.
- Never infer an amount.
- Never claim payment succeeded before provider confirmation/capture.
- PayPal wording means account payment; Stripe wording means merchant payment.

## Account Book

The account book stays local and simple:

```json
{
  "id": "alex",
  "displayName": "Alex Chen",
  "aliases": ["Alex", "alex@example.com"],
  "email": "alex@example.com",
  "paypalEmail": "alex-paypal@example.com",
  "paypalMerchantId": "",
  "stripeAccountId": "",
  "enabled": true
}
```

Stripe merchant example:

```json
{
  "id": "demo-vendor",
  "displayName": "Demo Vendor",
  "aliases": ["商户", "vendor"],
  "email": "vendor@example.com",
  "paypalEmail": "",
  "paypalMerchantId": "",
  "stripeAccountId": "acct_...",
  "enabled": true
}
```

Do not track local secrets, real PayPal emails, real merchant IDs, or real Stripe account IDs in git.

## Validation

Common rules:

- Recipient must resolve to exactly one enabled account.
- Amount must be positive and converted to minor units.
- Currency defaults to `USD` only when the UI explicitly shows that default.
- Live mode requires a provider-specific low amount cap.
- Confirmation must happen before any external session/order creation.

PayPal rules:

- Account must have `paypalEmail` or `paypalMerchantId`.
- `payee.email_address` uses the mapped PayPal email when present.
- `payee.merchant_id` uses the mapped merchant ID when present.
- If both are present, prefer `merchant_id`.
- Capture only after PayPal approval returns.

Stripe rules:

- Account must have `stripeAccountId`.
- `stripeAccountId` must start with `acct_`.
- Sandbox mode can use test connected accounts.
- Live mode can only use allowlisted live connected accounts.
- Live merchant accounts must have completed Stripe onboarding and be able to accept charges/payouts according to Stripe account status.
- Use the existing connected-account allowlist and live cap.

## Provider Clients

### PayPal client

`PayPalPaymentClient` is a tiny wrapper around PayPal REST APIs:

- Create access token from local `PAYPAL_CLIENT_ID` and `PAYPAL_CLIENT_SECRET`.
- Create Order with `intent: CAPTURE`.
- Set `purchase_units[].amount`.
- Set `purchase_units[].payee.email_address` or `purchase_units[].payee.merchant_id`.
- Return approval URL or SDK client token data needed by ArkWeb.
- Capture approved Order.
- Retrieve Order for receipt/status.

No PayPal secret is injected into HTML.

### Stripe client

Keep the existing Stripe shape:

- Create Embedded Checkout Session.
- Retrieve Checkout Session for receipt status.
- Use idempotency key on session creation.
- Pass destination connected account using the current working Stripe path.

No Stripe secret or restricted key is injected into HTML.

## UI States

### Missing recipient

Shown when the query recipient is unknown or ambiguous. The user can select a saved account or add one with display name, aliases, and at least one provider account field.

### Provider choice

Shown when a saved target supports both PayPal and Stripe and the prompt did not name the provider.

Buttons:

- `PayPal 账号支付`
- `Stripe 商户支付`

### Missing amount

Shown when the query names a valid recipient/provider but no amount. It offers quick amounts and a custom input.

### Confirmation

Shown for every valid payment request before any provider session/order is created.

Provider labels:

- PayPal: `PayPal 账号支付`
- Stripe: `Stripe 商户支付`

### Checkout

PayPal shows approval/Checkout inside ArkWeb if PayPal allows it on the device. Stripe shows Embedded Checkout inside ArkWeb.

### Receipt or error

Success shows provider, provider session/order ID, recipient, amount, currency, mode, and timestamp. Cancel and failure states show plain recovery actions. The app does not auto-retry.

## Error Handling

- Missing provider config: show setup card with exact missing keys.
- Unknown recipient: show account card.
- Unsupported provider for target: show provider/account edit card.
- Ambiguous provider: show provider choice card.
- Missing amount: show amount card.
- Live amount above cap: block before provider session/order creation.
- PayPal API error: show sanitized PayPal error name/message/debug ID, no secrets.
- Stripe API error: show sanitized Stripe error type/message, no secrets.
- WebView load or provider approval blocked: show the exact blocker and do not mark payment complete.
- Duplicate confirm tap: disable confirm while a provider session/order is being created.
- Repeated request: idempotency key prevents duplicate provider session/order creation for the same confirmed attempt.

## Testing

Unit checks:

- PayPal-only account defaults to PayPal.
- Stripe-only account defaults to Stripe.
- Account with both providers returns provider choice when provider is missing.
- Explicit `paypal` or `stripe` provider validates only if the account supports it.
- Unknown recipient is blocked.
- Missing amount returns needs-amount state.
- Live mode above cap is blocked before provider session/order creation.
- Amount converts to minor units correctly.

Manual/device smoke queries:

1. PayPal account payment:
   - Query: `用 PayPal 给 Alex 转 5 美元`
   - Expected: `payment.send` with provider `paypal`.
   - Expected card: `PayPal 账号支付`, Alex, PayPal email or merchant ID hint, `USD 5.00`, confirm required.
   - Expected after confirm: PayPal approval/Checkout opens in app if allowed.
   - Expected completion: sandbox capture returns receipt. If PayPal blocks ArkWeb approval, record that exact provider/WebView blocker.

2. Stripe merchant payment:
   - Query: `用 Stripe 给 Demo Vendor 付 5 美元`
   - Expected: `payment.send` with provider `stripe`.
   - Expected card: `Stripe 商户支付`, Demo Vendor, `acct_...` hint, `USD 5.00`, confirm required.
   - Expected after confirm: Stripe Embedded Checkout opens in app.
   - Expected completion: sandbox test payment returns receipt, or the visible Stripe Checkout/test-mode page is captured if card completion is not available in the smoke harness.

3. Stripe real merchant readiness, only after live credentials and a real connected merchant are configured:
   - Query: `用 Stripe 给 <真实商户名> 支付 1 美元`
   - Expected: `payment.send` with provider `stripe`.
   - Expected card: `Stripe 商户支付`, real merchant name, live mode, connected account hint, `USD 1.00`, confirm required.
   - Expected safety: if the merchant is not allowlisted, onboarding is incomplete, or the amount exceeds the live cap, block before Checkout.
   - Expected after confirm: live Stripe Checkout opens in app and charges the payer only after explicit provider confirmation.

Regression queries:

- `给 Alex 转账` shows amount completion.
- `给 Alex 转 5 美元` shows provider choice if Alex supports both providers.
- `给 unknown@example.com 转 5 美元` shows account add/select.

## Credential Guidance Timing

Detailed credential walkthrough comes after implementation shape is finalized. At that point guide the user through:

- PayPal sandbox app credentials.
- PayPal sandbox personal payer account.
- PayPal sandbox payee account email or merchant ID.
- Stripe test keys and connected account IDs.
- Stripe live keys and real connected merchant account ID, only when the user is ready for tiny live merchant payment.
- Local ignored config sync into HAP rawfile.

If PayPal live credentials require a merchant, verified, or approved-partner account that the user cannot obtain, state live PayPal is blocked and keep only sandbox/device demo.

## Implementation Notes

- Reuse the existing `payment.send`, A2UI action handling, account book, and ArkWeb bridge patterns.
- Add `provider` and PayPal account fields before adding any new abstraction.
- Do not add a provider framework until a third provider exists.
- Do not add PayPal Payouts for this request.
- Do not place payment inside dynamic MCP discovery for MVP.
- Keep all real keys and real account identifiers out of tracked source.

## References

- PayPal Pay another account: https://developer.paypal.com/docs/checkout/standard/customize/pay-another-account/
- PayPal Orders API: https://developer.paypal.com/docs/api/orders/v2/
- PayPal seller onboarding: https://developer.paypal.com/docs/multiparty/seller-onboarding/
- PayPal production credentials: https://developer.paypal.com/reference/production/
- Stripe Embedded Checkout: https://docs.stripe.com/checkout/embedded/quickstart
- Stripe Connect Accounts: https://docs.stripe.com/connect/accounts
- Stripe restricted API keys: https://docs.stripe.com/keys/restricted-api-keys
