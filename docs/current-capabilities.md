# 当前工具和测试 query 清单

更新时间：2026-07-06

来源：

- 静态工具：`agent_core/src/main/ets/aiphone/AiphoneToolDefinitions.ets` 和 `agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets`
- Agent 额外工具：`agent_core/src/main/ets/aiphone/LoopBackend.ets`
- 动态工具样例：`agent_core/src/main/ets/aiphone/runtime/DynamicToolSamples.ets`
- 设备测试 query：`scripts/aiphone-device-smoke.mjs`
- 支付专项测试：`entry/src/test/ToolGatewayClient.test.ets`、`entry/src/test/PaymentCore.test.ets`、`entry/src/test/PaymentA2ui.test.ets`、`entry/src/test/StripeReceivingAccountA2ui.test.ets`

## 工具总览

当前 app 的 agent 工具箱里有 29 个可被模型选择的工具：27 个静态工具，加上 `memory.update` 和 `dynamic.search`。

| 领域 | toolId | 能力 | 风险 | 后端/授权 | UI/动作 |
| --- | --- | --- | --- | --- | --- |
| 出行 | `travel.search` | 综合出行方案，混排高铁/航班候选 | `read` | `local_adapter` / 无 | `TravelOptions` |
| 出行 | `train.search` | 高铁、火车、12306 相关查询 | `read` | `local_adapter` / 无 | `TrainOptions` |
| 出行 | `flight.search` | 航班、机票、机场相关查询 | `read` | `local_adapter` / provider key | `FlightBoard` |
| 餐饮 | `food.search` | 附近咖啡、奶茶、餐厅、麦当劳、瑞幸、菜单/优惠/外卖查询 | `read` | `local_adapter` / provider key | `FoodChoices` |
| 社交 | `social.feed.search` | 聚合读取 X、Slack、企业微信 feed 或连接状态 | `read` | `local_adapter` / OAuth 或 provider key | `SocialHub`; 可起草回复 |
| 社交 | `social.reply.draft` | 对已选真实社交消息生成回复草稿 | `draft` | `local_adapter` / OAuth 或 provider key | `SocialHub` |
| X | `x.post.search` | 搜索 X/Twitter/x.com 公开 post | `read` | `local_adapter` / OAuth 或 provider key | `SocialHub`; 可起草回复 |
| 邮箱 | `mail.search` | 通用邮箱聚合搜索，当前覆盖 Gmail + QQ Mail | `read` | OAuth API, IMAP, Workspace MCP / 对应授权 | `GenericToolResults`; 可读线程/写草稿 |
| 邮箱 | `mail.thread.read` | 读取已选通用邮箱线程 | `read` | OAuth API, IMAP / 对应授权 | `GenericToolResults`; 可写草稿 |
| 邮箱 | `mail.draft.create` | 基于真实邮件创建通用邮箱回复草稿 | `draft` | OAuth API, IMAP / 对应授权 | `GenericToolResults` |
| Gmail | `gmail.mail.search` | 搜索/查看 Gmail 邮件列表或关键词邮件 | `read` | OAuth API, Workspace MCP, Web session / 对应授权 | `GenericToolResults`; 授权、读线程、写草稿、打开 Web |
| Gmail | `gmail.thread.read` | 读取指定 Gmail thread | `read` | OAuth API, Workspace MCP, Web session / 对应授权 | `GenericToolResults`; 写草稿、打开 Web |
| Gmail | `gmail.draft.create` | 创建 Gmail 邮件/回复草稿 | `draft` | OAuth API, Workspace MCP, Web session / 对应授权 | `GenericToolResults`; 可 apply 或打开 Web |
| Gmail | `gmail.draft.apply` | 用户确认后应用已有 Gmail 草稿 | `confirm_required` | OAuth API, Workspace MCP, Web session, system intent / 对应授权 | `GenericToolResults` |
| Gmail | `gmail.open.web` | 打开 Gmail Web 给用户继续处理 | `confirm_required` | system intent / 系统 | `GenericToolResults` |
| Gmail | `gmail.message.send` | 直接发送 Gmail 的安全阻断兜底 | `blocked` | system intent / 系统 | `GenericToolResults`; 不会自动发送 |
| 视频 | `media.video.search` | 多源视频搜索，尤其 B 站 + YouTube 聚合 | `read` | `local_adapter` / provider key | `GenericToolResults`; 打开媒体页 |
| YouTube | `youtube.video.search` | YouTube-only 公开视频搜索 | `read` | `local_adapter` / provider key | `GenericToolResults`; 打开 YouTube |
| YouTube | `youtube.mine.playlists` | 查看用户 YouTube 播放列表 | `read` | OAuth API, Web session / 对应授权 | `GenericToolResults`; 授权、打开 Web |
| YouTube | `youtube.mine.subscriptions` | 查看用户 YouTube 订阅 | `read` | OAuth API, Web session / 对应授权 | `GenericToolResults`; 授权、打开 Web |
| 日历 | `calendar.events.search` | 查询 Google Calendar 日程 | `read` | OAuth API / OAuth | `GenericToolResults`; 授权 |
| 日历 | `calendar.event.create` | 创建 Google Calendar 日程 | `confirm_required` | OAuth API / OAuth | `GenericToolResults`; 授权 |
| 日历 | `calendar.event.update` | 更新 Google Calendar 日程 | `confirm_required` | OAuth API / OAuth | `GenericToolResults`; 授权 |
| 支付 | `payment.send` | PayPal/Stripe 付款确认流；Google Pay 只是 funding source，不是独立 provider | `confirm_required` | `local_adapter` / provider key 或 web session | `GenericToolResults`; 补金额、选 provider、确认、取消、打开 checkout |
| 支付 | `payment.account.setup` | 创建/打开/刷新当前 agent 的 Stripe 收款账户 | `confirm_required` | `local_adapter` / provider key | `StripeReceivingAccountCard`; Stripe Connect 托管认证 |
| 地图 | `maps.place.search` | 显式 Google Maps/Google Places 地点搜索 | `read` | `local_adapter` / provider key | `GenericToolResults` |
| 地图 | `maps.place.details` | Google Places 地点详情 | `read` | `local_adapter` / provider key | `GenericToolResults` |
| 数字分身 | `memory.update` | 记录当前分身的长期偏好、身份事实或稳定约束 | `draft` | agent runtime / 无 | 记忆更新卡；可重新执行建议 query |
| 动态工具 | `dynamic.search` | 在本机 ModelScope-derived catalog 里搜索可接入 MCP/API | `read` | dynamic catalog / 视工具而定 | `ToolConnectCard` 或动态工具结果 |

## 动态工具入口

这些不是主工具箱里的固定业务工具，但 `dynamic.search` 或本地工具宿主可以发现/接受它们。

| toolId | 来源/用途 | 当前状态 |
| --- | --- | --- |
| `weather.query` | 高德天气查询 alias | 可由天气 query 通过 `dynamic.search` 发现 |
| `maps.weather` | 高德天气兼容 alias | 可注册；测试里要求为真 |
| `statistics.search` | 中国国家统计局数据查询 | 可由 GDP/CPI/人口/经济数据 query 发现 |
| `ppt.generate` | 歌者 PPT MCP | 可由 PPT/幻灯片 query 发现，需要凭据或受 transport 限制 |
| `fixture.echo` | Fixture Echo MCP | 开发/测试 fixture，不算用户侧正式能力 |
| `ferry.ticket.search` | 船票示例 | 当前不注册；船票 query 会走 `dynamic.search` 并真实返回 `no_tool_found` |

## 设备 smoke query

运行：

```bash
node scripts/aiphone-device-smoke.mjs
```

| query | 预期 toolId | 覆盖点 |
| --- | --- | --- |
| `我明天要从北京去上海，帮我搜索出行方案` | `travel.search` | 综合出行 |
| `帮我搜索深圳坂田华为基地附近的咖啡店` | `food.search` | 餐饮/附近 POI 默认走 food，不走 Maps |
| `帮我用 Google Maps 搜索伦敦国王十字车站附近的中餐` | `maps.place.search` | 显式 Google Maps 才走 Maps |
| `帮我查看邮箱里最新的重要邮件` | `mail.search` | Gmail + QQ Mail 聚合邮箱 |
| `帮我查看我Gmail里和我eccv论文相关的邮件` | `gmail.mail.search` | Gmail ECCV 关键词搜索和可见证据链 |
| `帮我在b站和youtube里搜索qwen max 的官方视频` | `media.video.search` | B 站 + YouTube 多源视频 |
| `帮我查看我今天 X 和 Slack 上的消息` | `social.feed.search` | SocialHub 聚合 feed/连接状态 |
| `帮我查看 X 上 openai 最近的公开 post` | `x.post.search` | X 公开 post 搜索 |
| `点一杯咖啡` | `food.search` | 分身默认饮食查询 |
| `把饮食搭子的 memory 改成：用户咖啡偏好：只喝瑞幸咖啡。` | 无业务搜索工具 | `memory.update`/分身记忆更新链路 |
| `点一杯咖啡` | `food.search` | 记忆更新后再次查询，预期体现瑞幸偏好 |

### 可选 smoke 组

| 命令 | query | 预期 toolId | 预期发现 |
| --- | --- | --- | --- |
| `--dynamic-tools` | `帮我查明天深圳到珠海的船票` | `dynamic.search` | `none` |
| `--dynamic-tools` | `帮我查明天深圳天气` | `dynamic.search` | `weather.query` |
| full regression | `你好` | 无工具 | - |
| full regression | `帮我查明天北京到上海航班` | `flight.search` | - |
| full regression | `帮我查询深圳北出发到香港西九龙明天晚上六点之后的高铁` | `train.search` | - |
| full regression | `帮我查附近咖啡` | `food.search` | - |
| full regression | `帮我查深圳坂田附近麦当劳门店和菜单` | `food.search` | - |
| Gmail/full regression | `帮我看 Gmail 里最新的重要邮件` | `gmail.mail.search` | - |
| Gmail/full regression | `帮我用 Gmail 写一封邮件给 alice@example.com 说我收到了` | `gmail.draft.create` | - |
| Gmail/full regression | `帮我查看我Gmail里和我eccv论文相关的邮件` | `gmail.mail.search` | - |
| mail/full regression | `帮我看邮箱里最新的重要邮件` | `mail.search` | - |
| mail/full regression | `帮我看 QQ 邮箱里最新邮件` | `mail.search` | - |
| `--google-apps`/full regression | `帮我在 YouTube 搜索 qwen max 官方介绍视频` | `youtube.video.search` | - |
| `--google-apps`/full regression | `帮我查看我的 YouTube 播放列表` | `youtube.mine.playlists` | - |
| `--google-apps`/full regression | `帮我看今天的 Google Calendar 日程` | `calendar.events.search` | - |
| `--google-apps`/full regression | `帮我在 2026年6月30日下午3点创建一个标题为 AIPhoneDemo smoke 的30分钟日程` | `calendar.event.create` | - |
| `--google-apps`/full regression | `帮我用 Google Maps 搜索深圳坂田华为基地附近的咖啡店` | `maps.place.search` | - |

支付工具当前没有加入设备 smoke 默认或 full regression。

## 支付专项测试 prompt

这些是代码级测试 prompt，不是 `scripts/aiphone-device-smoke.mjs` 的默认设备 query。

| 测试文件 | prompt / 场景 | 预期 |
| --- | --- | --- |
| `ToolGatewayClient.test.ets` | `用 PayPal 给罗一格转账` | `payment.send` 返回“补充金额” |
| `ToolGatewayClient.test.ets` | `用 PayPal 给 Dana Saved 转账` | 使用本地保存付款对象，仍先补金额 |
| `ToolGatewayClient.test.ets` | `用 PayPal 给罗一格转 5 美元` | `payment.send` 返回确认支付卡，不先创建 provider session |
| `ToolGatewayClient.test.ets` | `打开 External Cafe 的 Stripe 付款页` | Stripe Payment Link 转成 app checkout action |
| `PaymentCore.test.ets` | Google Pay funding source | Google Pay 走 PayPal target，不作为独立 provider |
| `PaymentA2ui.test.ets` | confirm / needs amount / checkout / Google Pay rendering | 支付卡动作和展示正确 |
| `StripeReceivingAccountA2ui.test.ets` | Stripe 收款账户 setup / onboard / refresh | `payment.account.setup` 卡动作正确 |

## 更新规则

改工具时同步改这份表：

1. 新增/删除静态工具：先改 `AiphoneToolDefinitions.ets` 和 runtime `ToolDefinitionRegistry.ets`，再更新“工具总览”。
2. 新增 agent-only 工具：改 `LoopBackend.ets` 后更新“工具总览”。
3. 新增动态 catalog alias：改 `DynamicToolSamples.ets` 后更新“动态工具入口”。
4. 新增设备 smoke query：改 `scripts/aiphone-device-smoke.mjs` 后更新“设备 smoke query”。
5. 新增支付/专项 prompt：改对应 `entry/src/test/*` 后更新“支付专项测试 prompt”或新增专项表。
