## 2026-07-08 Codex final review fix

- Fixed the shared Composio fixed-write path in `agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets` so `gmail.draft.create`, `gmail.draft.apply`, `calendar.event.create`, and `calendar.event.update` reject missing canonical `fixedArgs` before any Composio execute/auth flow. The result now keeps the fixed tool id, lists missing fields, and does not synthesize write payload fields from prompt text.
- Added regressions in `entry/src/test/ComposioDynamicBackend.test.ets` and `entry/src/test/ToolGatewayClient.test.ets` for the missing-body / missing-calendar-fields cases, plus direct checks that fixed write args no longer get prompt-filled in Composio schemas.
- Updated stale wording in `docs/current-capabilities.md` and the Gmail draft smoke markers in `scripts/aiphone-device-smoke.mjs` to reflect the Composio-backed fixed Gmail/Calendar paths.

### Verification

- `node /Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js --mode module -p module=agent_core@default -p product=default assembleHar --analyze=normal --parallel --incremental --daemon` -> exit 0
- `node /Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js --mode module -p module=entry@default -p product=default assembleHap --analyze=normal --parallel --incremental --daemon` -> exit 0
- `node /Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js --mode module -p module=entry@default -p product=default test --parallel --incremental --daemon` -> exit 0 (hvigor stayed silent aside from daemon start)
- `node scripts/verify-loopy-backend.mjs` -> expected baseline failures only:
  - `missing isA2uiObservation(observation)`
  - `missing unsafe_action_blocked`
- `git diff --check -- agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets entry/src/test/ComposioDynamicBackend.test.ets entry/src/test/ToolGatewayClient.test.ets scripts/aiphone-device-smoke.mjs docs/current-capabilities.md` -> clean

## 2026-07-08 Codex final re-review critical fix

- Tightened `agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets` so `gmail.draft.create` now requires preserved `to` and `body`, and `gmail.draft.apply` requires preserved `threadId`, `to`, `subject`, `replyMode`, and `body` before any Composio config/auth/execute flow. Empty string and empty array values still count as missing through the shared meaningful-value guard.
- Added backend regressions in `entry/src/test/ComposioDynamicBackend.test.ets` for `body` present but `to` missing on `gmail.draft.create`, plus missing reply context on `gmail.draft.apply`, both asserting the fixed tool id stays visible and the result does not fall through to `Composio 未配置`.
- Added gateway regressions in `entry/src/test/ToolGatewayClient.test.ets` for the same two cases so the user-visible fixed-tool path rejects incomplete structured args before any Composio auth/config fallback.

### Verification

- `node /Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js --mode module -p module=entry@default -p product=default test` -> exit 0, output only `hvigor client: Starting hvigor daemon.`
- `node scripts/verify-loopy-backend.mjs` -> exit 1 with accepted baseline failures only:
  - `missing isA2uiObservation(observation)`
  - `missing unsafe_action_blocked`
- `git diff --check -- agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets entry/src/test/ComposioDynamicBackend.test.ets entry/src/test/ToolGatewayClient.test.ets` -> clean
