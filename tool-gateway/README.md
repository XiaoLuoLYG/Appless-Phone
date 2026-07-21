# AIPhone Tool Gateway

This optional local gateway gives the HarmonyOS demo a stable HTTP endpoint for development-time tool-call smoke tests.

Current HAP builds keep provider-backed fixed tools on `local://aiphone-tools`. X/Twitter and Slack authorization, reads, and supported Slack writes use the current user's Composio connected accounts; this optional gateway is not an alternate X/Slack token path. Use `scripts/sync-provider-config.mjs` before installation to package provider keys into the ignored HAP rawfile.

## Start

```bash
cd tool-gateway
TOOL_GATEWAY_PORT=8787 npm start
```

Stable macOS launchd start:

```bash
launchctl remove com.aiphone.toolgateway 2>/dev/null || true
launchctl submit -l com.aiphone.toolgateway \
  -o /tmp/aiphone-tool-gateway.log \
  -e /tmp/aiphone-tool-gateway.err \
  -- /opt/homebrew/bin/node /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo/tool-gateway/server.mjs
```

The travel, flight, train, and food tools use the HAP's `local://aiphone-tools` path by default. Phone-standalone verification should keep `hdc fport ls` empty.

Stop the launchd job:

```bash
launchctl remove com.aiphone.toolgateway
```

## Endpoints

- `GET /health`
- `GET /mcp/tools`
- `POST /mcp/call`
- `POST /api/aiphone/tool`
- `POST /api/payment/stripe/checkout`
- `POST /api/payment/paypal/checkout`
- `POST /api/payment/paypal/capture`
- `GET /api/social/feed?q=<query>`
- `POST /api/social/draft`

## Live Payment Checkout

Use the gateway for live payment provider calls so Stripe/PayPal secrets stay out of the HAP:

```bash
cd tool-gateway
TOOL_GATEWAY_PORT=8787 npm start
hdc -t <target> rport tcp:8787 tcp:8787
```

Set these in `tool-gateway/.env.local`:

```env
PAYMENT_MODE=live
PAYPAL_CLIENT_ID=live_client_id
PAYPAL_CLIENT_SECRET=live_secret
PAYPAL_ENVIRONMENT=live
PAYPAL_CHECKOUT_GATEWAY_URL=http://127.0.0.1:8787
STRIPE_SECRET_KEY=sk_live_or_rk_live_here
STRIPE_PUBLISHABLE_KEY=pk_live_here
STRIPE_CHECKOUT_GATEWAY_URL=http://127.0.0.1:8787
PAYMENT_LIVE_MAX_AMOUNT_MINOR=500
PAYMENT_LIVE_ALLOWED_STRIPE_ACCOUNT_IDS=acct_...
```

Then run `node scripts/sync-provider-config.mjs` and rebuild the HAP. The sync script intentionally skips live Stripe and PayPal secret keys when writing `aiphone_provider_config.json`.
- `POST /api/social/wecom/callback`

## Legacy Social Bridge endpoints

`GET /api/social/feed` and `POST /api/social/draft` remain only for enterprise-WeChat callback-cache compatibility. They do not read X/Slack tokens or call X/Slack APIs; those platforms return a visible message directing the caller to the phone product's Composio path.

Enterprise WeChat can use `WECOM_CORP_ID`, `WECOM_AGENT_ID`, `WECOM_SECRET`, `WECOM_CALLBACK_TOKEN`, and `WECOM_ENCODING_AES_KEY`.

`POST /api/social/draft` never sends messages. It only returns a local unsent draft payload.
Draft success requires an existing cached SocialHub item; unknown `itemId` values return a local error draft instead of inventing a target.

When `TOOL_GATEWAY_API_KEY` is set, `GET /api/social/feed`, `POST /api/social/draft`, and `POST /api/social/wecom/callback` require the same `Authorization: Bearer <key>` or `X-API-Key` header as the other gateway routes. If `WECOM_CALLBACK_TOKEN` is set, the WeCom callback also requires either `?token=<value>` or `X-WeCom-Token: <value>`.
No fixture or social mock content is returned by default. Without enterprise-WeChat callback input, `GET /api/social/feed` returns `items: []` plus truthful connection setup messages.

## Provider Configuration

Without provider configuration, the gateway returns an A2UI error surface instead of fake live data.
`travel.search` is the aggregate travel query. It calls the train and flight providers, sorts the mixed rows by departure time, merges only real returned rows into `TravelOptions`, and writes partial provider failures into source-status rows.

`POST /api/aiphone/tool` accepts:

```json
{
  "toolId": "train.search",
  "prompt": "帮我查询明天北京到上海的高铁票",
  "rows": [{ "label": "出发地", "value": "北京" }],
  "bullets": ["明天出发"]
}
```

Unified travel search uses the same endpoint with `toolId: "travel.search"`:

```json
{
  "toolId": "travel.search",
  "prompt": "我明天要从北京去上海，帮我搜索出行方案"
}
```

Responses use `application/a2ui+json` JSONL:

```jsonl
{"version":"v0.9.1","createSurface":{"surfaceId":"surface_train_search","root":"root","title":"12306 余票查询","intent":"travel.train","status":"ready","sendDataModel":true}}
{"version":"v0.9.1","updateComponents":{"surfaceId":"surface_train_search","components":[{"id":"root","component":"SurfaceRoot","child":"layout","title":"12306 余票查询","status":"ready"},{"id":"layout","component":"Column","children":["summary","results","confirm"]},{"id":"summary","component":"InfoRows","title":"查询摘要","dataPath":"/rows"},{"id":"results","component":"TrainOptions","title":"可选车次","dataPath":"/trains","actions":[{"id":"change_train_date","label":"换时间","prompt":"换个时间查询高铁","variant":"secondary"}]},{"id":"confirm","component":"ConfirmPanel","title":"确认边界","body":"我可以继续帮你整理方案，但不会自动订票、支付或抢票。","actions":[{"id":"explain_boundary","label":"说明边界","prompt":"说明订票和支付边界","variant":"secondary"}]}]}}
{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface_train_search","path":"/trains","value":[{"trainCode":"G1","from":"北京南","to":"上海虹桥","depart":"09:00","arrive":"13:28","duration":"4小时28分","seats":"二等座有票","status":"success"}]}}
```

For `travel.search`, successful mixed rows are written to `/travelOptions` in departure-time order. Each row includes a visible source tag such as `高铁 · 12306` or `飞机 · 飞常准`.

Copy `tool-gateway/.env.example` to `tool-gateway/.env.local`, then fill the keys you have. `.env.local` is ignored by git. For the app runtime path, run this from the repo root before building:

```bash
node scripts/sync-provider-config.mjs
```

## Recommended Real Providers

### Train

The gateway can query the public 12306 ticket search endpoint directly for availability summaries.

- No account is required for query-only mode.
- Booking, passenger selection, payment, or ticket grabbing are not automated.
- If you prefer MCP, configure `TRAIN_MCP_URL`.

### Flights

Use VariFlight / 飞常准 MCP for China-focused flight query.

Register at:

```text
https://mcp.variflight.com/register
```

Registration fields:

- 用户名
- 电子邮箱
- 密码
- 电话号码（可选）
- 公司名称（可选）

After login, open API Keys and create an API Key. Configure one of these:

```bash
FLIGHT_MCP_KEY="..."
# or
VARIFLIGHT_API_KEY="..."
```

Optional override:

```bash
VARIFLIGHT_API_URL="https://mcp.variflight.com/api/v1/mcp/data"
```

The gateway calls VariFlight's query endpoint only. Booking, ticket issuing, passenger forms, and payment are out of scope.

### Food / Delivery

V1 is query-only. It does not call Meituan, Ele.me, Taobao Flash, or Amap ordering APIs.

The default HAP route is `local://aiphone-tools`, where `food.search` aggregates configured Amap, Tencent Maps, Baidu Maps, Meituan Union, Taobao Flash/Ele.me Union, McDonald's China MCP, and Luckin Coffee MCP adapters. The compatibility Node gateway can still return Amap POI data, but the in-app provider path is the primary implementation.

Query nearby restaurants with Amap Web Service POI:

```text
https://lbs.amap.com/api/webservice/create-project-and-key
```

Steps:

- 登录高德开放平台控制台；没有账号先注册成为开发者。
- 进入应用管理，点击创建新应用。
- 在应用下添加 Key，服务平台选择 Web 服务。
- Copy the created Key into `AMAP_KEY`.
- Set a default search center with `AMAP_DEFAULT_LOCATION` if the app has no live location yet.

```bash
AMAP_KEY="..."
AMAP_DEFAULT_LOCATION="116.397428,39.90923"
```

Enable Meituan Union product query and Taobao Flash/Ele.me Union store promotion query in the HAP rawfile sync input:

```bash
MEITUAN_UNION_APP_KEY="..."
MEITUAN_UNION_APP_SECRET="..."
TAOBAO_APP_KEY="..."
TAOBAO_APP_SECRET="..."
TAOBAO_FLASH_PID="..."
MCD_MCP_TOKEN="..."
LUCKIN_MCP_TOKEN="..."
```

McDonald's and Luckin use their official Streamable HTTP MCP endpoints by default (`https://mcp.mcd.cn` and `https://gwmcp.lkcoffee.com/order/user/mcp`). The app only calls read/query allowlisted tools for store, menu, product, coupon, price calculation, and order-status lookup. Ordering, cart creation, payment, automatic coupon binding, point redemption, and cancellation are out of scope. Missing keys and provider errors are displayed as source status rows instead of mock stores.

Generic HTTP API adapters:

```bash
FLIGHT_API_URL="https://provider.example/flight/search"
FLIGHT_API_KEY="..."
TRAIN_API_URL="https://provider.example/train/search"
TRAIN_API_KEY="..."
FOOD_API_URL="https://provider.example/food/search"
FOOD_API_KEY="..."
```

Experimental HTTP MCP adapters:

```bash
FLIGHT_MCP_URL="https://mcp.example/mcp"
TRAIN_MCP_URL="http://127.0.0.1:8788/mcp"
FOOD_MCP_URL="https://mcp.example/mcp"
```

If a provider needs custom signing, add a provider-specific adapter in `server.mjs`.
