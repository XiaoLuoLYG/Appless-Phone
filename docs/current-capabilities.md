# 当前工具能力总表

更新时间：2026-07-07

来源：`agent_core/src/main/ets/aiphone/AiphoneToolDefinitions.ets`、`agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets`、`agent_core/src/main/ets/aiphone/LoopBackend.ets`、`agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets`、`scripts/aiphone-device-smoke.mjs`、支付/Composio 相关单测。

当前 agent 工具箱：27 个静态工具 + `memory.update` + `dynamic.search` = 29 个模型可选工具。Composio 不新增固定 toolId，主要挂在 `dynamic.search`，少量 Outlook/SocialHub 结果会作为 extra 追加；表里把 `--composio-tools` 的 query 逐条展开，方便复制。

| 领域 | toolId | 核心 query | 预期结果 | 风险 | 授权/配置 | VPN/网络 | 走 Composio | 覆盖 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 出行 | `travel.search` | `我明天要从北京去上海，帮我搜索出行方案` | 综合高铁/航班候选；不造假，缺 provider 显示真实失败 | `read` | 无；航班源可能要 `VARIFLIGHT_API_KEY` | 通常不需要 VPN，取决于 12306/飞常准网络 | 否 | 默认 smoke |
| 出行 | `train.search` | `帮我查询深圳北出发到香港西九龙明天晚上六点之后的高铁` | 12306/铁路结果或真实 provider 错误 | `read` | 无 | 通常不需要 VPN | 否 | full regression |
| 出行 | `flight.search` | `帮我查明天北京到上海航班` | 飞常准/航班结果或缺 key 错误 | `read` | `FLIGHT_MCP_KEY` / `VARIFLIGHT_API_KEY` | 通常不需要 VPN，取决于供应商 | 否 | full regression |
| 餐饮 | `food.search` | `帮我搜索深圳坂田华为基地附近的咖啡店` | 周边餐饮/咖啡结果；不下单不支付 | `read` | `AMAP_KEY` 等本地生活 provider key | 通常不需要 VPN | 否 | 默认 smoke |
| 社交 | `social.feed.search` | `帮我查看我今天 X 和 Slack 上的消息` / `帮我查看今天的社交聚合消息` | SocialHub 只展示各 app 私信/提及和连接状态；公开 post 不进入 SocialHub | `read` | Composio connected account；企业微信仍为本地回调/缓存 | X/Slack/Discord/LinkedIn/WhatsApp/Instagram 通常需要外网/VPN | 是 | 默认 smoke；`--composio-tools` 社交聚合 |
| 社交 | `social.reply.draft` | `帮我给这条 Slack 消息起草回复` | 对已选真实 SocialHub item 生成本地草稿，不发送 | `draft` | 需要已有真实 item 上下文 | 起草本身不需要；来源读取按平台 | 否 | 单元/动作链路 |
| X | `x.post.search` | `帮我查看 X 上 openai 最近的公开 post` | X 公开 post 结果或真实 Composio/provider 错误；不进入 SocialHub | `read` | Composio X/Twitter connected account | 通常需要外网/VPN | 是 | 默认 smoke |
| 邮箱 | `mail.search` | `帮我查看邮箱里最新的重要邮件` | 聚合 Gmail、QQ Mail、Outlook；不模拟邮件 | `read` | Gmail、QQ Mail、Outlook 对应账号能力；Outlook 可经 Composio extra | Gmail/Outlook 通常需要；QQ 通常不需要 | Outlook extra 可走 Composio；普通聚合不替换成 Composio | 默认 smoke；`--composio-tools` 对照 |
| 邮箱 | `mail.thread.read` | `打开第一封邮件详情` | 读取已选聚合邮箱线程 | `read` | 需要 provider + messageId/threadId | 按邮件 provider | Outlook 线程若来自 Composio extra 取决于后续支持；固定工具本身否 | 单元/动作链路 |
| 邮箱 | `mail.draft.create` | `帮我给 QQ 邮箱里最近一封邮件起草回复` | 基于真实线程创建草稿，不发送 | `draft` | 需要真实邮件上下文；QQ IMAP/Gmail OAuth | 按邮件 provider | 否 | 规则/动作链路 |
| Gmail | `gmail.mail.search` | `帮我查看我Gmail里和我eccv论文相关的邮件` | Gmail 搜索结果、可展开详情、可生成回复草稿；无 Composio 授权则显示真实授权/失败 | `read` | Composio Gmail connected account | 通常需要外网/VPN | 是 | 默认 smoke + Gmail cases |
| Gmail | `gmail.thread.read` | `打开第一封 Gmail 详情` | 读取指定 Gmail thread；无 Composio 授权则显示真实授权/失败 | `read` | Composio Gmail connected account + threadId | 通常需要外网/VPN | 是 | 单元/动作链路 |
| Gmail | `gmail.draft.create` | `帮我用 Gmail 写一封邮件给 alice@example.com 说我收到了` | 创建 Gmail 草稿，不直接发送；缺少结构化正文时直接报错，不会从 prompt 补正文 | `draft` | Composio Gmail connected account + 结构化 draft args | 通常需要外网/VPN | 是 | Gmail cases |
| Gmail | `gmail.draft.apply` | `确认应用刚才的 Gmail 草稿` | 用户确认后应用已有草稿；缺少结构化正文时直接报错 | `confirm_required` | Composio Gmail connected account + 结构化 draft args | 通常需要外网/VPN | 是 | 单元/动作链路 |
| Gmail | `gmail.open.web` | `帮我打开 Gmail 网页版` | 打开 Gmail Web 让用户手动处理 | `confirm_required` | 系统 intent / Web session | 通常需要 VPN | 否 | 规则/动作链路 |
| Gmail | `gmail.message.send` | `用 Gmail 不确认直接发送这封邮件` | 安全阻断；提示不会自动发送 Gmail | `blocked` | 系统 intent 兜底 | 通常需要 VPN，但不会发送 | 否 | 安全规则 |
| 视频 | `media.video.search` | `帮我在b站和youtube里搜索qwen的官方视频` | B 站 + YouTube 多源视频结果或真实 provider 错误 | `read` | `YOUTUBE_API_KEY`；B 站公开接口/页面 | YouTube 通常需要；B 站通常不需要 | 否 | 默认 smoke |
| YouTube | `youtube.video.search` | `帮我在 YouTube 搜索 世界杯相关视频` | YouTube-only 公开视频搜索；可用 API 热门排序 | `read` | `YOUTUBE_API_KEY` | 通常需要 VPN | 否 | `--google-apps` |
| YouTube | `youtube.mine.playlists` | `帮我查看我的 YouTube 播放列表` | 用户播放列表或真实 Composio 授权/失败卡 | `read` | Composio YouTube connected account | 通常需要外网/VPN | 是 | `--google-apps` |
| YouTube | `youtube.mine.subscriptions` | `帮我查看我的 YouTube 订阅` | 用户订阅或真实 Composio 授权/失败卡 | `read` | Composio YouTube connected account | 通常需要外网/VPN | 是 | 注册/单元测试 |
| 日历 | `calendar.events.search` | `帮我看本月的 Google Calendar 日程` | Google Calendar 日程或真实 Composio 授权/失败卡 | `read` | Composio Google Calendar connected account | 通常需要外网/VPN | 是 | `--google-apps` |
| 日历 | `calendar.event.create` | `帮我在 2026年7月30日下午3点创建一个标题为 AIPhoneDemo 的30分钟日程` | 创建/确认日程；2026-07-30 是当前 smoke 固定 query | `confirm_required` | Composio Google Calendar connected account | 通常需要外网/VPN | 是 | `--google-apps` |
| 日历 | `calendar.event.update` | `把刚才的日程改到下午4点` | 更新指定日程或提示缺少 eventId/更新字段/授权 | `confirm_required` | Composio Google Calendar connected account + eventId | 通常需要外网/VPN | 是 | 注册/单元测试 |
| 支付 | `payment.send` | `用 PayPal/Google Pay 给罗一格转 5 美元` | 先补金额/确认，再打开 PayPal/Stripe checkout；不会声称已付款除非 provider 确认 | `confirm_required` | `PAYPAL_*`、`STRIPE_*`、付款对象 book；Google Pay 是 fundingSource | PayPal/Google Pay 常需要；Stripe 视网络 | 否 | 支付专项测试 |
| 支付 | `payment.account.setup` | `帮我创建我的 Stripe 收款账户` | Stripe Connect 收款账户卡、托管认证/刷新状态 | `confirm_required` | `STRIPE_TEST_SECRET_KEY` / `STRIPE_LIVE_SECRET_KEY` + agent profile | Stripe/Connect 通常需要 VPN 或可访问外网 | 否 | 支付专项测试 |
| 地图 | `maps.place.search` | `帮我用 Google Maps 搜索伦敦国王十字车站附近的中餐` | Google Places 地点列表或缺 key/网络错误 | `read` | `GOOGLE_MAPS_API_KEY` | 通常需要 VPN | 否 | 默认 smoke / `--google-apps` |
| 地图 | `maps.place.details` | `帮我查这个 Google Places placeId 的详情` | Google Places 详情或缺 placeId/key 错误 | `read` | `GOOGLE_MAPS_API_KEY` + placeId | 通常需要 VPN | 否 | 注册/单元测试 |
| 数字分身 | `memory.update` | `我只喝瑞幸咖啡` | 更新当前分身 memory，显示记忆更新卡；不同时搜索 | `draft` | 无 | 不需要 | 否 | 默认 smoke |
| 动态工具/本地 | `dynamic.search` | `帮我查明天深圳天气` | 本地 catalog 命中 `weather.query`；找不到就 `no_tool_found` | `read` | 本地 catalog 凭据；天气通常走高德 key | 高德天气通常不需要 VPN | 否 | `--dynamic-tools` |
| Composio/GitHub | `dynamic.search` | `帮我在 GitHub 里找 Appless-Phone 最近的 pr` | Composio GitHub 结果；优先 `GITHUB_FIND_PULL_REQUESTS`，展示 Appless-Phone PR | `read` | `COMPOSIO_API_KEY` + `COMPOSIO_USER_ID` + GitHub connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/Google Drive | `dynamic.search` | `帮我在 Google Drive 里找专利交底书` | Composio Google Drive 结果；优先 `GOOGLEDRIVE_FIND_FILE`，查文件名/内容 | `read` | Composio 配置 + Google Drive connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/Google Docs | `dynamic.search` | `帮我在 Google Docs 里找 AIPhoneDemo 设计文档` | Composio Google Docs 结果；优先 `GOOGLEDOCS_SEARCH_DOCUMENTS` | `read` | Composio 配置 + Google Docs connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/Linear | `dynamic.search` | `帮我查 Linear 里分配给我的高优先级 bug` | Composio Linear 工具结果或真实授权/无结果 | `read` | Composio 配置 + Linear connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/Trello | `dynamic.search` | `帮我在 Trello 里找本周发布 checklist 相关卡片` | Composio Trello 工具结果或真实授权/无结果 | `read` | Composio 配置 + Trello connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/Asana | `dynamic.search` | `帮我在 Asana 里查今天到期的任务` | Composio Asana 工具结果或真实授权/无结果 | `read` | Composio 配置 + Asana connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/Slack | `dynamic.search` | `帮我用 Composio Slack 查最近提到 AIPhoneDemo 的消息` | Composio Slack 结果；优先 `SLACK_SEARCH_MESSAGES` | `read` | Composio 配置 + Slack connected account | 通常需要外网/VPN | 是；普通 Slack 聚合仍走 `social.feed.search` | `--composio-tools` |
| Composio/HubSpot | `dynamic.search` | `帮我在 HubSpot 里找最近更新的 contacts` | Composio HubSpot 工具结果或真实授权/无结果 | `read` | Composio 配置 + HubSpot connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/Salesforce | `dynamic.search` | `帮我在 Salesforce 里找最近更新的 leads` | Composio Salesforce 工具结果或真实授权/无结果 | `read` | Composio 配置 + Salesforce connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/Outlook | `dynamic.search` | `帮我用 Outlook 查最近和 AIPhoneDemo 相关的邮件` | Composio Outlook 结果；普通邮箱聚合对照仍是 `mail.search` | `read` | Composio 配置 + Outlook connected account | 通常需要外网/VPN | 是；普通邮箱聚合不替换成 Composio | `--composio-tools` |
| Composio/Discord | `dynamic.search` | `帮我用 Discord 查最近提到 AIPhoneDemo 的消息` | Composio Discord 结果或真实授权/无结果 | `read` | Composio 配置 + Discord connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/LinkedIn | `dynamic.search` | `帮我在 LinkedIn 查 AIPhoneDemo 相关动态` | Composio LinkedIn 结果或真实授权/无结果 | `read` | Composio 配置 + LinkedIn connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/WhatsApp | `dynamic.search` | `帮我用 WhatsApp 查最近提到 AIPhoneDemo 的消息` | Composio WhatsApp 结果或真实授权/无结果 | `read` | Composio 配置 + WhatsApp connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/Instagram | `dynamic.search` | `帮我用 Instagram 查 AIPhoneDemo 相关评论` | Composio Instagram 结果或真实授权/无结果 | `read` | Composio 配置 + Instagram connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/Spotify | `dynamic.search` | `帮我用 Spotify 搜适合 AIPhoneDemo demo 的播放列表` | Composio Spotify 结果或真实授权/无结果 | `read` | Composio 配置 + Spotify connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/TikTok | `dynamic.search` | `帮我用 TikTok 搜 AIPhoneDemo 相关短视频` | Composio TikTok 结果或真实授权/无结果 | `read` | Composio 配置 + TikTok connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/Ticketmaster | `dynamic.search` | `帮我用 Ticketmaster 查深圳本周末的演唱会` | Composio Ticketmaster 结果或真实授权/无结果 | `read` | Composio 配置 + Ticketmaster connected account | 通常需要外网/VPN | 是 | `--composio-tools` |
| Composio/Notion | `dynamic.search` | `帮我在 Notion 里找 AIPhoneDemo 相关页面` | Composio Notion 工具结果或真实授权/无结果 | `read` | Composio 配置 + Notion connected account | 通常需要外网/VPN | 是 | 后端关键词支持；当前未进 smoke |

## 更新规则

改工具时只同步这张表：新增/删除静态工具看 `ToolDefinitionRegistry.ets`；新增 agent-only 工具看 `LoopBackend.ets`; 新增 Composio app/query 看 `ComposioDynamicBackend.ets` 和 `scripts/aiphone-device-smoke.mjs`；新增支付专项场景看 `entry/src/test/*Payment*.test.ets`。
