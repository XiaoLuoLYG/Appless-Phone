# PocketAgent

PocketAgent is a publishable HarmonyOS demo of an agentic phone interface: a natural-language request becomes a native A2UI task surface, then supported live-data actions run through real, query-only adapters.

The default runtime is device-local: the app points at an OpenAI-compatible model endpoint, defaults to `http://127.0.0.1:11434`, and keeps registered tool calls on `local://aiphone-tools`. The Node.js gateway in this repo is a compatibility and smoke-test helper, not a required Mac-side runtime service.

![PocketAgent running on HarmonyOS](docs/assets/pocketagent-current.jpeg)

## Try The Demo

Start with the step-by-step [quickstart guide](docs/quickstart.md). The shortest demo path is:

1. Open the project in DevEco Studio and run the `entry` module.
2. In the app settings page, test the default local model endpoint or configure your own OpenAI-compatible endpoint.
3. Ask `你好` to verify the A2UI response loop.
4. Ask `我明天从北京去上海，帮我搜索出行方案` to verify `travel.search` routing.
5. Ask `帮我搜索深圳坂田华为基地附近的咖啡` to verify `food.search` routing.

Without provider keys, live searches should show explicit missing-config/provider status rows. With provider keys synced into the HAP, those same prompts render real provider rows.

## Current Capabilities

| Area | What is implemented | Boundary |
| --- | --- | --- |
| A2UI surface runtime | Streams A2UI v0.9.1 JSONL into a native ArkUI renderer with catalog validation, data-model updates, local action handling, debug panels, and unit tests. | Unknown components, malformed JSON, legacy payloads, model-generated HTML, and JavaScript are rejected. |
| Travel search | `travel.search` aggregates train and flight rows; `train.search` queries 12306 availability; `flight.search` uses VariFlight or a compatible configured provider. | It summarizes choices only. It does not book tickets, issue tickets, pay, or grab seats. |
| Food search | `food.search` aggregates configured Amap, Tencent Maps, Baidu Maps, Meituan Union, Taobao Flash/Ele.me Union, McDonald's China MCP, and Luckin Coffee MCP query adapters. | It does not create carts, place orders, pay, auto-bind coupons, redeem points, cancel orders, or invent cross-platform prices. |
| Social inbox and reply | The WeChat-first surface can ingest real captured messages through notification/accessibility paths, show permission diagnostics, and route exact user-text replies through a device-side executor when available. | It does not fabricate contacts/messages. Reply success is only shown after a real executor confirms the send. |
| Verification | ArkTS unit tests cover parsing, rendering data, tool routing, provider mapping, social store behavior, and UI state helpers. Node scripts cover gateway and device smoke paths. | Device and provider smokes may fail when SDK/signing state, provider keys, or system permissions are missing; those failures should stay visible. |

## Architecture

```text
User command
  -> HarmonyOS ArkTS app
  -> OpenAI-compatible local or cloud model endpoint
  -> A2UI JSONL stream
  -> Native ArkUI task surface
  -> local://aiphone-tools
  -> Query-only provider adapter or local social action
```

The model is only allowed to request registered tools through `/toolRequest`. Real train, flight, food, and social rows are produced by the app/provider layer, not invented by the model prompt.

## Repository Map

- `entry/`: HarmonyOS ArkTS app, A2UI renderer, model client, device-side tool adapters, social bridge, and unit tests.
- `tool-gateway/`: Optional Node.js compatibility gateway plus provider smoke harness.
- `scripts/sync-provider-config.mjs`: Copies ignored local provider keys into an ignored HAP rawfile before installation.
- `scripts/aiphone-device-smoke.mjs`: HDC-driven device smoke checks for model routing and tool execution.
- `docs/quickstart.md`: Step-by-step public demo tutorial.
- `docs/a2ui.md`: Public notes for the A2UI message protocol.
- `docs/social-notification-permission.md`: Checklist for the WeChat notification-center path.
- `local-model-whitelist/`: Model whitelist snapshots used while testing local model integrations.

## Requirements

- DevEco Studio with HarmonyOS SDK 6.1.0 or compatible.
- A HarmonyOS device or simulator configured for your signing profile.
- An OpenAI-compatible chat-completions model endpoint. The default local path is `http://127.0.0.1:11434` with model `Qwen3-8B`.
- Node.js 18 or newer for config sync, gateway smoke tests, and device smoke scripts.
- Optional provider keys for flight and food search.
- Optional notification/accessibility permissions for the WeChat social path.

## Quick Start

1. Open this repository in DevEco Studio.
2. Let DevEco restore OHPM dependencies.
3. Configure your own signing profile if DevEco does not create one automatically.
4. Run the `entry` module on a HarmonyOS device or simulator.
5. In the app settings page, test the model connection. The default is the local Qwen path; the cloud Qwen preset can be used with an API key and compatible request parameters.

The installed app does not need `tool-gateway` running for the default route. It uses `local://aiphone-tools` for `flight.search`, `train.search`, `travel.search`, `food.search`, and `social.reply.send`.

For a fuller walkthrough, see [docs/quickstart.md](docs/quickstart.md).

## Provider Configuration

Copy the ignored local env file when you want real provider-backed search:

```bash
cd tool-gateway
cp .env.example .env.local
```

Fill only the providers you want to enable, then package those values into the ignored rawfile before building or installing the HAP:

```bash
cd ..
node scripts/sync-provider-config.mjs
```

The script writes `entry/src/main/resources/rawfile/aiphone_provider_config.json`. That generated file is ignored by git and should not be committed.

Common provider keys:

```bash
FLIGHT_MCP_KEY=
VARIFLIGHT_API_KEY=
AMAP_KEY=
AMAP_DEFAULT_LOCATION=116.397428,39.90923
AMAP_RADIUS=3000
TENCENT_MAP_KEY=
BAIDU_MAP_AK=
MEITUAN_UNION_APP_KEY=
MEITUAN_UNION_APP_SECRET=
TAOBAO_APP_KEY=
TAOBAO_APP_SECRET=
TAOBAO_FLASH_PID=
MCD_MCP_TOKEN=
LUCKIN_MCP_TOKEN=
```

Provider behavior:

- `train.search` uses 12306 query-only availability and does not need an account for the default path.
- `flight.search` uses VariFlight / 飞常准 or a compatible configured flight provider.
- `travel.search` runs train and flight queries, then sorts returned rows by departure time.
- `food.search` runs enabled food providers, deduplicates normalized store names, merges visible source tags, and turns missing keys or provider failures into status rows.
- Brand MCP adapters for McDonald's and Luckin are only used for relevant prompts and only call read/query allowlisted tools.

## Social Permissions

The first social channel is WeChat. The app can show a real short-term inbox only after a notification or accessibility capture path is available on the device.

For the notification-center path, apply for `ohos.permission.SUBSCRIBE_NOTIFICATION` and update the HAP Profile before testing. Some devices or profiles may not expose that permission; in that case the app should show diagnostics instead of pretending to capture messages. See [docs/social-notification-permission.md](docs/social-notification-permission.md).

Reply dispatch is deliberately failure-closed: `social.reply.send` only reports `sent` after a real device-side WeChat executor confirms the action.

## Optional HTTP Tool Gateway

The Node gateway is useful for development smoke tests and for explicit HTTP gateway experiments:

```bash
cd tool-gateway
npm start
```

It listens on `http://127.0.0.1:8787` by default and exposes:

- `GET /health`
- `GET /mcp/tools`
- `POST /api/aiphone/tool`
- `POST /mcp/call`

Only use HDC reverse porting if you intentionally switch the app from `local://aiphone-tools` back to the HTTP gateway for development:

```bash
hdc rport tcp:8787 tcp:8787
```

## Test And Smoke

- Run ArkTS unit tests from DevEco Studio for `entry/src/test`.
- Run gateway smoke tests:

```bash
cd tool-gateway
npm run smoke
```

- Run device smoke tests when HDC can see the target device and the app is installed:

```bash
node scripts/aiphone-device-smoke.mjs
```

Provider or device smokes should surface the real failure: missing SDK components, signing issues, missing provider keys, provider authorization errors, unavailable model services, or missing system permissions.

## Security And Truthfulness

- Tool calls are limited to registered provider adapters and explicit local social actions.
- Missing provider keys, provider HTTP failures, empty results, and permission gaps are rendered as A2UI status/error surfaces.
- The social inbox never creates test contacts or synthetic messages.
- Booking, payment, ticket grabbing, delivery ordering, cart creation, and commerce account automation are outside the current product boundary.
- `.env.local`, generated provider rawfiles, signing files, and local model credentials must stay out of git.

## License

No open-source license has been selected yet. All rights are reserved unless a license is added later.
