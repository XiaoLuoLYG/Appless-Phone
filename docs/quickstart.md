# PocketAgent Quickstart

This guide walks through a simple public-demo setup for PocketAgent.

PocketAgent is designed to be truthful by default: if a local model, provider key, device permission, or WeChat executor is missing, the app should show that real failure instead of returning fake tickets, restaurants, or messages.

## 1. Open The Project

1. Install DevEco Studio with HarmonyOS SDK 6.1.0 or a compatible SDK.
2. Clone the repository and open the project root in DevEco Studio.
3. Let DevEco Studio restore OHPM dependencies.
4. Configure a signing profile for your device or simulator.
5. Run the `entry` module.

## 2. Connect A Model

The default model setting is:

```text
Base URL: http://127.0.0.1:11434
Model: Qwen3-8B
```

Open the app settings page and tap the connection test. If you use a cloud OpenAI-compatible endpoint, set the model, base URL, API key, and any required custom JSON parameters in the same settings page.

For DashScope-compatible Qwen testing, the app includes a cloud preset. You still need your own API key.

## 3. Try The No-Key Demo Path

Without provider keys, you can still verify the main UI loop:

1. Ask: `你好`
2. Ask: `我明天从北京去上海，帮我搜索出行方案`
3. Ask: `帮我搜索深圳坂田华为基地附近的咖啡`

Expected behavior:

- The model should produce A2UI surfaces, not Markdown.
- Real-time queries should request `travel.search` or `food.search`.
- Missing provider configuration should appear as a visible status or error row.
- The app should not invent train numbers, flight numbers, prices, restaurants, or social messages.

## 4. Enable Real Provider Search

Copy the local provider template:

```bash
cd tool-gateway
cp .env.example .env.local
```

Fill only the providers you want to test:

```bash
FLIGHT_MCP_KEY=
VARIFLIGHT_API_KEY=
AMAP_KEY=
AMAP_DEFAULT_LOCATION=116.397428,39.90923
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

Sync those ignored local values into the ignored HAP rawfile before building:

```bash
cd ..
node scripts/sync-provider-config.mjs
```

Then reinstall or rerun the app from DevEco Studio.

## 5. Demo Prompts

Travel:

```text
我明天从北京去上海，帮我搜索出行方案
帮我查后天深圳到杭州的高铁票
帮我查明天广州飞上海的航班
```

Food:

```text
帮我搜索深圳坂田华为基地附近的咖啡
附近有什么麦当劳
帮我看看附近瑞幸有什么可选
```

Social:

```text
打开微信消息
```

The social demo needs real device permissions and a real capture/send path. Empty inboxes and missing permissions should show diagnostics, not sample contacts.

## 6. Optional Gateway Smoke

The default HAP uses `local://aiphone-tools`. The Node gateway is only for development smoke tests or explicit HTTP gateway experiments.

```bash
cd tool-gateway
npm run smoke
```

## 7. Device Smoke

When HDC can see the target device and the app is installed:

```bash
node scripts/aiphone-device-smoke.mjs
```

Device smoke checks the model route, expected tool selection, local tool execution, and whether failures are real missing-config or provider/runtime failures.

## What The Demo Does Not Do

- It does not book tickets, pay, grab seats, or issue tickets.
- It does not place food orders, create carts, redeem points, or auto-bind coupons.
- It does not fabricate WeChat messages or send replies without a real device-side executor.
- It does not require the optional Node gateway for the default installed-app path.
