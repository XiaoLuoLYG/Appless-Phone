# 当前工具能力总表

更新时间：2026-07-20

来源：`agent_core/src/main/ets/aiphone/AiphoneToolDefinitions.ets`、`agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets`、`agent_core/src/main/ets/aiphone/LoopBackend.ets`、`agent_core/src/main/ets/aiphone/runtime/AggregateSearchClient.ets`、`agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets`、`scripts/aiphone-device-smoke.mjs`、支付/Composio 相关单测。

当前 agent 工具箱：42 个静态注册工具 + `memory.update` + `dynamic.search`，运行时最多 44 个模型可选工具。Composio 不新增固定 toolId，主要挂在 `dynamic.search`；自动回归以 core/full/excluded 标记为准。

授权页统一显示 app 名称。Slack、X 的读取和授权统一走当前用户的 Composio connected account；用户确认发送 Slack 回复时固定执行 `SLACK_CHAT_POST_MESSAGE`，X 回复仍不支持。QQ 邮箱、瑞幸、滴滴继续使用当前默认凭证和原有 provider 逻辑，授权页只新增各自官方授权/开发者页面入口，不会把网页登录结果自动写回 App。

| 领域 | toolId | 核心 query | 预期结果 | 风险 | 授权/配置 | VPN/网络 | 走 Composio | 覆盖 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 出行 | `travel.search` | `我明天要从北京去上海，帮我搜索出行方案` | 综合高铁/航班候选；不造假，缺 provider 显示真实失败 | `read` | 无；航班源可能要 `VARIFLIGHT_API_KEY` | 通常不需要 VPN，取决于 12306/飞常准网络 | 否 | 默认 smoke |
| 出行 | `train.search` | `帮我查询深圳北出发到香港西九龙明天晚上六点之后的高铁` | 12306/铁路结果或真实 provider 错误 | `read` | 无 | 通常不需要 VPN | 否 | full regression |
| 出行 | `flight.search` | `帮我查明天北京到上海航班` | 飞常准/航班结果或缺 key 错误 | `read` | `FLIGHT_MCP_KEY` / `VARIFLIGHT_API_KEY` | 通常不需要 VPN，取决于供应商 | 否 | full regression |
| 餐饮 | `food.search` | `帮我搜索深圳坂田华为基地附近的咖啡店` | 周边餐饮/咖啡结果；不下单不支付 | `read` | `AMAP_KEY` 等本地生活 provider key | 通常不需要 VPN | 否 | 默认 smoke |
| 酒店 | `hotel.search` | `帮我找8月8日到10日深圳科技园附近的酒店，2位成人1间房` | RollingGo 真实酒店结果、地址、语义标签和带口径的参考价；不伪造库存 | `read` | `ROLLINGGO_HOTEL_MCP_KEY` / `ROLLINGGO_HOTEL_MCP_URL` | 取决于 RollingGo 网络 | 否 | core C20 |
| 酒店 | `hotel.detail` | 从 C20 的真实酒店卡点击“查看房型” | 使用上一步真实 hotelId 查询房型、价格和取消政策，可返回原搜索结果；不预订 | `read` | 同 `hotel.search`，且必须保留真实 hotelId | 取决于 RollingGo 网络 | 否 | core C20 衍生交互 |
| 酒店 | `hotel.navigate` | 从 C20 的真实酒店卡点击“导航到酒店” | 仅使用该酒店返回的有效坐标打开系统地图；真机 smoke 截图后返回 App，不创建预订；无有效坐标时 E2E 为 `NOT_RUN` | `read` | 无 | 取决于系统地图 | 否 | core C20 衍生交互 |
| 酒店 | `hotel.call` | 从 C20 的真实酒店卡点击“联系酒店” | 仅在 Google Places 验证电话和 place ID 后打开系统拨号盘；真机 smoke 只验证预填、截图并返回，绝不点击最终拨号；无验证电话时按钮隐藏为 PASS、拨号 E2E 为 `NOT_RUN` | `draft` | Google Places key 和已验证联系人 | 取决于 Google Places 与系统拨号 | 否 | core C20 衍生交互 |
| 瑞幸 | `luckin.order.preview` | `帮我点一杯瑞幸生椰拿铁，半糖少冰` | 真实门店/菜单匹配与订单确认页；不创建订单 | `confirm_required` | `LUCKIN_MCP_TOKEN` | 取决于瑞幸 MCP 网络 | 否 | core C15 |
| 瑞幸 | `luckin.order.create` | 从 C15 确认页执行确认动作 | 仅显式确认后创建真实订单；自动回归不点击 | `write` | `LUCKIN_MCP_TOKEN` + 完整门店/商品/规格 ID | 取决于瑞幸 MCP 网络 | 否 | manual-only |
| 瑞幸 | `luckin.order.status` | 使用真实订单号查询 | 仅查询真实已创建订单；无订单时不执行 | `read` | `LUCKIN_MCP_TOKEN` + 真实订单号 | 取决于瑞幸 MCP 网络 | 否 | manual-only |
| 社交 | `social.feed.search` | `帮我查看我今天 X 和 Slack 上的消息` / `帮我查看今天的社交聚合消息` | SocialHub 只展示各 app 私信/提及和连接状态；公开 post 不进入 SocialHub | `read` | Composio connected account；企业微信仍为本地回调/缓存 | X/Slack/Discord/LinkedIn/WhatsApp/Instagram 通常需要外网/VPN | 是 | 默认 smoke；`--composio-tools` 社交聚合 |
| 社交 | `social.reply.draft` | `帮我给这条 Slack 消息起草回复` | 对已选真实 SocialHub item 生成本地草稿，不发送 | `draft` | 需要已有真实 item 上下文 | 起草本身不需要；来源读取按平台 | 否 | 单元/动作链路 |
| 社交 | SocialHub Slack 回复动作 | 在真实 Slack 消息草稿上点击发送 | 使用原消息的 channel/thread ID，经当前用户 Composio 执行 `SLACK_CHAT_POST_MESSAGE`；provider 未确认时不显示成功 | `write` | Composio Slack connected account + 可写 scope | 通常需要外网/VPN | 是 | 参数映射单测；真实发送 manual-only |
| X | `x.post.search` | `帮我查看 X 上 openai 最近的公开 post` | X 公开 post 结果或真实 Composio/provider 错误；不进入 SocialHub | `read` | Composio X/Twitter connected account | 通常需要外网/VPN | 是 | 默认 smoke |
| 邮箱 | `mail.search` | `帮我查看邮箱里最新的重要邮件` | 聚合 Gmail、QQ Mail、Outlook；不模拟邮件 | `read` | Gmail、QQ Mail、Outlook 对应账号能力；Outlook 可经 Composio extra | Gmail/Outlook 通常需要；QQ 通常不需要 | Outlook extra 可走 Composio；普通聚合不替换成 Composio | 默认 smoke；`--composio-tools` 对照 |
| 邮箱 | `mail.thread.read` | `打开第一封邮件详情` | 读取已选聚合邮箱线程 | `read` | 需要 provider + messageId/threadId | 按邮件 provider | Outlook 线程若来自 Composio extra 取决于后续支持；固定工具本身否 | 单元/动作链路 |
| 邮箱 | `mail.draft.create` | `帮我给 QQ 邮箱里最近一封邮件起草回复` | 基于真实线程创建草稿，不发送 | `draft` | 需要真实邮件上下文；QQ IMAP/Gmail OAuth | 按邮件 provider | 否 | 规则/动作链路 |
| Gmail | `gmail.mail.search` | `帮我查看我Gmail里和我eccv论文相关的邮件` | Gmail 搜索结果、可展开详情、可生成回复草稿；无 Composio 授权则显示真实授权/失败 | `read` | Composio Gmail connected account | 通常需要外网/VPN | 是 | 默认 smoke + Gmail cases |
| Gmail | `gmail.thread.read` | `打开第一封 Gmail 详情` | 读取指定 Gmail thread；无 Composio 授权则显示真实授权/失败 | `read` | Composio Gmail connected account + threadId | 通常需要外网/VPN | 是 | 单元/动作链路 |
| Gmail | `gmail.draft.create` | `帮我用 Gmail 写一封邮件给 alice@example.com 说我收到了` | 创建 Gmail 草稿，不直接发送；缺少结构化 `to`/`body` 时直接报错，不会从 prompt 补正文 | `draft` | Composio Gmail connected account + 结构化 draft args | 通常需要外网/VPN | 是 | Gmail cases |
| Gmail | `gmail.draft.apply` | `确认应用刚才的 Gmail 草稿` | 用户确认后应用已有草稿；缺少结构化 `threadId`/`to`/`subject`/`replyMode`/`body` 时直接报错 | `confirm_required` | Composio Gmail connected account + 结构化 draft args | 通常需要外网/VPN | 是 | 单元/动作链路 |
| Gmail | `gmail.open.web` | `帮我打开 Gmail 网页版` | 打开 Gmail Web 让用户手动处理 | `confirm_required` | 系统 intent / Web session | 通常需要 VPN | 否 | 规则/动作链路 |
| Gmail | `gmail.message.send` | `用 Gmail 不确认直接发送这封邮件` | 安全阻断；提示不会自动发送 Gmail | `blocked` | 系统 intent 兜底 | 通常需要 VPN，但不会发送 | 否 | 安全规则 |
| 视频 | `media.video.search` | `帮我在b站和youtube里搜索qwen的官方视频` | B 站 + YouTube 多源视频结果或真实 provider 错误 | `read` | `YOUTUBE_API_KEY`；B 站公开接口/页面 | YouTube 通常需要；B 站通常不需要 | 否 | 默认 smoke |
| 聚合搜索 | `media.aggregate.search` | `我想看看有关 openai codex 的相关新闻和讨论` | YouTube/B 站视频 + X/HN 讨论聚合；微博/知乎显示真实未接入原因 | `read` | `YOUTUBE_API_KEY`、`COMPOSIO_API_KEY` / `COMPOSIO_USER_ID` + X/HN connected account；B 站公开访问 | YouTube/X/HN 通常需要；B 站通常不需要 | X/HN 走 Composio；微博/知乎首版只显示真实状态 | 默认 smoke |
| 世界杯 | `worldcup.open` | `我想看世界杯下一场比赛和赛程` | 打开 App 内世界杯专页；不把静态页冒充实时比赛结果 | `read` | 无 | 页面本身不需要 | 否 | core C12 |
| YouTube | `youtube.video.search` | `帮我在 YouTube 搜索 世界杯相关视频` | YouTube-only 公开视频搜索；可用 API 热门排序 | `read` | `YOUTUBE_API_KEY` | 通常需要 VPN | 否 | `--google-apps` |
| YouTube | `youtube.mine.playlists` | `帮我查看我的 YouTube 播放列表` | 用户播放列表或真实 Composio 授权/失败卡 | `read` | Composio YouTube connected account | 通常需要外网/VPN | 是 | `--google-apps` |
| YouTube | `youtube.mine.subscriptions` | `帮我查看我的 YouTube 订阅` | 用户订阅或真实 Composio 授权/失败卡 | `read` | Composio YouTube connected account | 通常需要外网/VPN | 是 | 注册/单元测试 |
| 日历 | `calendar.events.search` | `帮我看本月的 Google Calendar 日程` | Google Calendar 日程或真实 Composio 授权/失败卡 | `read` | Composio Google Calendar connected account | 通常需要外网/VPN | 是 | `--google-apps` |
| 日历 | `calendar.event.create` | `帮我在 {QA_DATE} 下午3点创建标题为 Appless QA {RUN_ID} 的30分钟日程` | 创建本轮唯一 QA 日程，随后必须更新并删除 | `write` | Composio Google Calendar connected account | 通常需要外网/VPN | 是 | core C19 可逆生命周期 |
| 日历 | `calendar.event.update` | `把 {QA_DATE} 的 Appless QA {RUN_ID} 日程改到下午4点` | 只更新本轮真实 eventId，不按标题猜 ID | `write` | Composio Google Calendar connected account + 真实 eventId | 通常需要外网/VPN | 是 | core C19 可逆生命周期 |
| 日历 | `calendar.event.delete` | `删除 {QA_DATE} 标题为 Appless QA {RUN_ID} 的 Google Calendar 日程` | 先展示确认，确认后删除本轮 QA 日程并再次查询不存在 | `write` | Composio Google Calendar connected account + 真实 eventId | 通常需要外网/VPN | 是 | core C19 可逆清理 |
| 支付 | `payment.send` | `用 PayPal/Google Pay 给罗一格转 5 美元` | 先补金额/确认，再打开 PayPal/Stripe checkout；不会声称已付款除非 provider 确认 | `confirm_required` | `PAYPAL_*`、`STRIPE_*`、付款对象 book；Google Pay 是 fundingSource | PayPal/Google Pay 常需要；Stripe 视网络 | 否 | 支付专项测试 |
| 支付 | `payment.account.setup` | `帮我创建我的 Stripe 收款账户` | Stripe Connect 收款账户卡、托管认证/刷新状态 | `confirm_required` | `STRIPE_TEST_SECRET_KEY` / `STRIPE_LIVE_SECRET_KEY` + agent profile | Stripe/Connect 通常需要 VPN 或可访问外网 | 否 | 支付专项测试 |
| 地图 | `maps.place.search` | `帮我用 Google Maps 搜索伦敦国王十字车站附近的中餐` | Google Places 地点列表或缺 key/网络错误 | `read` | `GOOGLE_MAPS_API_KEY` | 通常需要 VPN | 否 | 默认 smoke / `--google-apps` |
| 地图 | `maps.place.details` | `帮我查这个 Google Places placeId 的详情` | Google Places 详情或缺 placeId/key 错误 | `read` | `GOOGLE_MAPS_API_KEY` + placeId | 通常需要 VPN | 否 | 注册/单元测试 |
| 地图 | `maps.route.open` | `帮我用 Google Maps 查询从深圳北站到深圳湾口岸的驾车路线并发起导航` | 展示真实路线参数与导航入口；不声称已经导航 | `confirm_required` | `GOOGLE_MAPS_API_KEY` | 通常需要 VPN | 否 | core C16 |
| 消息 | `whatsapp.message.send` | `帮我给 WhatsApp 测试联系人发送消息：Appless QA {RUN_ID}` | 仅使用 `AIPHONE_WHATSAPP_TEST_TO` 展示发送确认；自动回归不确认发送 | `confirm_required` | Composio/WhatsApp 连接 + QA 号码 | 通常需要外网/VPN | 是 | core C18；缺 QA 号码为 BLOCKED |
| 打车 | `ride.estimate` | `帮我看从深圳湾万象城到深圳北站打车多少钱` | 展示真实路线与可用 provider 估价；缺 key 显示真实配置状态 | `read` | 地图 key；滴滴估价需 `DIDI_MCP_KEY` | 取决于地图/滴滴网络 | 否 | core C14 |
| 打车 | `ride.app.link` | `不要估价，打开从深圳湾万象城到深圳北站的打车入口` | 生成 provider App 入口，不自动叫车 | `confirm_required` | 对应地图/滴滴配置 | 取决于 provider | 否 | excluded X03 |
| 打车 | `ride.order.create` | 从真实估价卡确认叫车 | 只在显式确认后创建真实订单；自动回归不执行 | `write` | `DIDI_MCP_KEY` + 真实路线/车型/乘客上下文 | 取决于滴滴网络 | 否 | manual-only |
| 打车 | `ride.order.cancel` | 取消已创建的真实订单 | 必须保留真实 orderId；无测试订单不执行 | `write` | `DIDI_MCP_KEY` + 真实 orderId | 取决于滴滴网络 | 否 | manual-only |
| 打车 | `ride.driver.location` | 查询已创建订单的司机位置 | 必须保留真实 orderId；无测试订单不执行 | `read` | `DIDI_MCP_KEY` + 真实 orderId | 取决于滴滴网络 | 否 | manual-only |
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

改工具时只同步这张表：新增/删除静态工具看 `ToolDefinitionRegistry.ets`；新增 agent-only 工具看 `LoopBackend.ets`; 新增聚合搜索来源看 `AggregateSearchClient.ets`；新增 Composio app/query 看 `ComposioDynamicBackend.ets` 和 `scripts/aiphone-device-smoke.mjs`；新增支付专项场景看 `entry/src/test/*Payment*.test.ets`。
