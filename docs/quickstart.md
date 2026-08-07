# Appless 快速开始

这份教程帮你跑起一个真实边界的 HarmonyOS agent phone demo。

Appless 的默认原则很简单：缺少本地模型、provider key、设备权限或真实执行器时，界面显示真实失败，不返回假车次、假航班、假餐厅、假邮件或假消息。

## 1. 打开工程

1. 安装 DevEco Studio，并准备 HarmonyOS SDK 6.1.0 或兼容 SDK。
2. 克隆仓库，用 DevEco Studio 打开项目根目录。
3. 等待 DevEco Studio 恢复 OHPM 依赖。
4. 配置设备或模拟器签名。
5. 运行 `entry` 模块。

## 2. 连接模型

默认模型设置：

```text
Base URL: http://113.46.219.251:8080/v1/chat/completions
Model: Deepseek-V4-Flash-0731
```

进入 app 设置页，点击连接测试。如果使用 OpenAI-compatible 云端端点，在同一页填写模型、Base URL、API key 和必要的自定义 JSON 参数。

CSI.AI Deepseek V4 Flash preset 已内置；原有 DashScope Qwen preset 也保留在设置页，你仍然需要各自的 API key。

## 3. 不配置 key 也能试

没有 provider key 时，仍然可以验证主链路：

```text
你好
我明天从北京去上海，帮我搜索出行方案
帮我搜索深圳坂田华为基地附近的咖啡
```

预期行为：

- 模型返回 A2UI surface，而不是 Markdown。
- 实时查询会请求 `travel.search` 或 `food.search`。
- 缺失 provider 配置会显示为状态行或错误行。
- app 不会编造车次、航班、价格、餐厅或社交消息。

## 4. 开启真实 provider 查询

复制本地 provider 模板：

```bash
cd tool-gateway
cp .env.example .env.local
```

按需填写 key：

```bash
DEEPSEEK_API_KEY=
DASHSCOPE_API_KEY=
FLIGHT_MCP_KEY=
VARIFLIGHT_API_KEY=
ROLLINGGO_HOTEL_MCP_KEY=
ROLLINGGO_HOTEL_MCP_URL=
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
QQ_MAIL_ADDRESS=
QQ_MAIL_AUTH_CODE=
QQ_MAIL_IMAP_HOST=imap.qq.com
QQ_MAIL_IMAP_PORT=993
QQ_MAIL_DRAFTS_MAILBOX=
FIRECRAWL_API_KEY=
FIRECRAWL_MCP_URL=https://mcp.firecrawl.dev/v2/mcp
```

构建或安装 HAP 前，把本地值同步到被忽略的 rawfile：

```bash
cd ..
node scripts/sync-provider-config.mjs
```

然后重新安装或从 DevEco Studio 重新运行 app。

## 5. Demo Prompt

出行：

```text
我明天从北京去上海，帮我搜索出行方案
帮我查后天深圳到杭州的高铁票
帮我查明天广州飞上海的航班
```

餐饮：

```text
帮我搜索深圳坂田华为基地附近的咖啡
附近有什么麦当劳
帮我看看附近瑞幸有什么可选
```

Gmail：

```text
帮我查看 Gmail 最近邮件
帮我给 Gmail 里最近一封邮件起草回复
```

邮箱聚合：

```text
帮我看邮箱里最新的重要邮件
帮我给 QQ 邮箱里最近一封邮件起草回复
```

动态工具：

```text
帮我查深圳明天天气
```

社交：

```text
打开社交消息聚合，看看 Slack、X、企业微信
搜索 X 上关于 AIPhone 的公开帖子
```

SocialHub 通过当前用户的 Composio connected account 读取 X/Slack，企业微信仍使用本地回调缓存。它先生成本地草稿；只有用户点击发送时才会通过 Composio 提交 Slack 回复。缺少授权、工具、scope 或回调缓存时应显示真实连接/错误状态。

Firecrawl 开放网页：

```text
研究 Firecrawl Monitor 的工作方式、限制和适用场景，给出多个公开来源
读取 https://www.firecrawl.dev/monitor 并总结它如何监控网页变化
搜索小红书上关于鸿蒙应用开发的公开讨论，只展示公开可验证内容
```

Firecrawl 固定工具由 HAP 携带 key 直连 Hosted MCP，不依赖 Mac gateway。Credit 和 Monitor 检查由 Firecrawl 账号/套餐提供和计费，可在 [Firecrawl pricing](https://www.firecrawl.dev/pricing) 与账号后台查看；部分外网页面需要可用的国际网络或 VPN。小红书仅作为公开索引网页补充，不绕过登录/CAPTCHA，也不读取私密内容，结果可以如实显示 `PARTIAL`。

## 6. Provider 配置同步

默认 HAP 使用 `local://aiphone-tools` 和设备直连 provider。构建或设备测试前同步本地 provider 与 Composio 配置：

```bash
node scripts/sync-provider-config.mjs
```

## 7. 设备 smoke

HDC 能看到目标设备且 app 已安装时：

```bash
node scripts/aiphone-device-smoke.mjs
```

设备 smoke 会检查模型路由、预期工具选择、本地工具执行，以及失败是否来自真实缺失配置或 provider/runtime 问题。

## 当前不会做什么

- 不订票、不支付、不抢票、不出票。
- 不下餐饮订单、不创建购物车、不兑换积分、不自动领券。
- 不伪造 SocialHub、X、Slack 或企业微信消息/帖子/联系人，也不会伪造发送成功。
- SocialHub 不会自动发送；Slack 仅在用户确认后走 Composio，X 和企业微信草稿不发送。
- Firecrawl 不登录站点、不处理 CAPTCHA、不抓私密账号，不把 Monitor 云状态冒充 HarmonyOS 原生推送。
