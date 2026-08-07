# 心上事 / Bear in Mind 验证报告

日期：2026-08-04

分支：`codex/bear-in-mind`

基线：`origin/multiagent-backend` (`92648f9b0f474e0d05bda4f55497bcca51ad94ab`)

设备：`6WS0226304000257`

## 结论

心上事基于现有 multiagent backend 实现，没有新增第二套 agent loop。主查询仍进入
`MultiAgentCanaryRuntime`；BIM 仅在现有 `MultiAgentLeaderPlanner` 外增加一个并行查询门，
路由在主规划器准备执行工具前决策。无候选时直接放行；命中时取消主分支并用同一个
multi-agent runtime 加载对应 BIM 上下文重新执行。

已验证完整的核心链路：模型判断是否出现“记在心上”按钮、用户授权保存、独立心上事
列表、统一状态详情页、详情页直接继续事项、跨轮更新保存、轻量索引路由、命中接管、
Memory 与 BIM 分离、自然淡出与每周检查。

## 主要改动

- 首页使用爱心与数字作为系统级入口；心上事为独立的左侧空间，支持横向返回。
- 心上事列表只展示持续事项；详情页展示聚合后的当前状态，不展示对话流水。
- 详情页输入默认进入该 BIM，并在执行后用结构化 `bimContextUpdate` 覆盖当前状态。
- 查询与 BIM 路由并行；多事项歧义时暂停选择，冲突需要确认，不能自行否决。
- BIM 上下文与 Persona Memory 严格分离，BIM 执行不得用 `memory.update` 代替事项更新。
- 空的模型索引数组不会意外清掉既有检索信号；需要显式删除语义时再引入删除标记。
- 未更新事项每周做一次轻量生命周期判断；用户结束或长期不活跃后自然淡出。
- 真机 smoke 增加 BIM 六场景入口，并要求显式授权才允许清理应用数据。

## 最终代码门禁

| 检查 | 结果 |
| --- | --- |
| ArkTS/Hypium | `1683 / 1683` 通过，`Failure: 0, Error: 0` |
| Node smoke evidence | `125 / 125` 通过 |
| multiagent backend verifier | `326 / 326` 通过 |
| Signed HAP build | `BUILD SUCCESSFUL` |
| Signed HAP SHA-256 | `c7de8230c5f7a4abe75c620fa1665ca43101e8324357565736e8122fe4fc6d59` |
| 真机安装 | `install bundle successfully`，保留既有应用数据 |

DevEco 的覆盖率 HTML 生成器仍打印既有的 coverage JSON 解析错误；权威测试结果文件
`entry/.test/default/intermediates/test/coverage_data/test_result.txt` 明确记录
`Tests run: 1683, Failure: 0, Error: 0, Pass: 1683, Ignore: 0`。

## BIM 真机结果

验证期间设备 VPN 已开启，模型为真实 `qwen-max`，未伪造 provider 或任务结果。

| 场景 | 结果 | 证据 |
| --- | --- | --- |
| 记在心上 | PASS | 用户点击后生成“东京旅行准备”，爱心计数变为 1 |
| 独立列表 | PASS | 列表展示聚合摘要、更新时间与“进行中”，无对话流水 |
| 统一详情 | PASS | 当前状态展示“不要红眼航班”“尽量中午前到” |
| 跨轮更新 | PASS | 约束与摘要写入设备本地 BIM store |
| 轻量索引 | PASS | 持久化关键词为“东京 / 旅行 / 机票”，完整 BIM 内容未进入路由提示 |
| BIM 命中 | PASS | `candidates=1 semantic=true status=matched` |
| 工具门等待 | PASS | `toolGateWaitMs=0` |
| 上下文回答 | PASS | 回答“您对东京旅行的航班偏好是不要红眼航班。” |
| Memory 边界 | PASS | BIM 终态必须携带 `bimContextUpdate`，`memory.update` 会被拒绝并修复 |

## 东京旅行补充回归

针对“人数增加到四个人、酒店改为两间双床房”未更新，以及详情页显示“心上事更新失败”
的问题，补充完成以下真机回归：

| 场景 | 结果 | 证据 |
| --- | --- | --- |
| 主对话更新人数与房型 | PASS | BIM 命中并接管，状态保存为“旅行人数为四人”“酒店要求是两间双床房” |
| 详情页更新同一需求 | PASS | 输入正常完成，无“心上事更新失败”，状态保持一致 |
| 东京酒店搜索 | PASS | RollingGo 返回东京有明丰泉大酒店，4 成人、2 间、2026-08-15 至 2026-08-17 |
| 酒店结果积累 | PASS | provider A2UI Surface 保存到同一事项，重新进入后仍显示酒店卡 |
| Dashboard 主题 | PASS | Heartboard、酒店卡和固定输入栏使用统一暖色浅主题，文字对比度正常 |

根因与修复：

- BIM 执行提示包裹了原查询，严格业务输入校验误读了包装后的 `input.text`。执行器现在仅
  在 BIM 上下文存在时提取原始查询，普通主对话输入路径不变。
- 路由提示错误地要求事项中预先存在酒店详情，导致“为既有旅行找酒店”被判为无关。
  现在将能推进事项的酒店、航班、餐厅、票务和日程动作纳入相关性判断。
- 状态更新被模型误规划成 `hotel.search` 时，原修复只能改参数，无法回到状态更新。
  BIM 专用修复现在允许降级为带 `bimContextUpdate` 的终态回答。
- 酒店严格校验原来只允许中国目的地。保留原有边界，仅增加明确东京标记到 `JP` 的映射。
- provider 成功返回 A2UI 但模型遗漏 `bimContextUpdate` 时，原保存路径会拒绝结果。现在仅
  对“成功、ready、且确实变化”的 Surface 复用既有 BIM 上下文并保存；状态更新仍必须
  显式提供结构化上下文，错误 Surface 不会入库。
- Dashboard 复用现有 A2UI renderer，并按信息域积累最多 8 个最新 Surface；同域结果更新
  替换，异域酒店、航班、行程可以并存。旧的深色 A2UI panel token 已与现有浅色主题统一。

东京酒店 provider 在验证期间出现过 10–20 秒的间歇性超时；同一 provider 的深圳对照
请求也出现超时。最终东京请求真实成功并持久化，未伪造 provider 结果。

本次真实命中路由耗时 `4888 ms`。主规划器与 BIM 路由并行，路由完成时主规划器尚未到
工具门，因此没有额外等待；无本地候选的先前真机记录为 `routeMs=0 candidates=0`
且 `toolGateWaitMs=0`。

语义模型在首次命中验证中返回了现有模型常见的 `Thought … Action: {JSON}` 包装；
路由协议原先只接受裸 JSON，因而降级成 `unknown`。最终代码复用了仓内已有
`extractJsonObjects`，并增加回归测试；修复后同一真实查询稳定得到 `matched`。

## 全量真机回归

全量矩阵共 46 条记录（45 个场景步骤与 1 个最终日历清理）：

- PASS：36
- BLOCKED：4
- FAIL：6

该轮全量回归运行在同一功能分支、BIM 测试数据创建之前。随后仅对 BIM 的模型输出解析、
索引保留和 BIM/Memory 终态约束做了根因修复；最终代码另行通过上面的 1676 条 Hypium、
125 条 Node、326 条 backend verifier、Signed HAP build 与真实 BIM 命中验证。

非 PASS 项：

- `C05` FAIL：QQ 邮件读取成功，但聚合邮件界面出现 `Composio 调用失败`。
- `C06` BLOCKED：Gmail provider 在 3 次尝试后仍失败。
- `C10` BLOCKED：X 公开内容查询的 provider/model 在 3 次尝试后仍失败。
- `C11a` / `C11c` FAIL：Leader 返回 `unexpected_task_error` 与
  `planned_tools_mismatch`，咖啡基线和 Persona 跟进未完成。
- `C18` BLOCKED：缺少 `AIPHONE_WHATSAPP_TEST_TO`；未猜测号码，未打开发送动作。
- `C19b` FAIL：真实 Calendar 创建成功并返回 Event ID，但最终可见 UI 证据规则未满足。
  后续更新、删除与最终不存在检查完成，测试日程已清理。
- `C22` FAIL：三动作组合出现 `invalid_data_rounds`、`missing_expected_data_round`、
  `planned_tools_mismatch`；未声称叫车、下单或支付成功。
- `F12` BLOCKED：Google Places 返回内部错误 `2300999`，并缺少依赖绑定证据。
- `F16` FAIL：授权设置页可用，QQ 授权打开外部页后未自动返回应用。

回归收尾结果：

- Persona memory 恢复：PASS。
- 测试日历最终清理：PASS，确认测试事件不存在。
- HiLog 进程清理：PASS。
- 最终 UI 无 synthetic / forbidden / blocking 命中：PASS。
- `hdc fport ls`：空。
- Firecrawl：按要求未验证。

## 截图与原始证据

关键截图：

- `tool-gateway/.smoke/bim-directory-final.png`
- `tool-gateway/.smoke/bim-detail-final.png`
- `tool-gateway/.smoke/bim-route-matched-final.png`
- `tool-gateway/.smoke/bim-plan2-manual.png`
- `tool-gateway/.smoke/bim-saved-manual.png`
- `tool-gateway/.smoke/bim-dashboard-final.jpeg`
- `tool-gateway/.smoke/bim-dashboard-hotel-contrast-final.jpeg`
- `tool-gateway/.smoke/bim-tokyo-hotel-saved-final.log`

全量回归：

- `tool-gateway/.smoke/full-20260804-0209/summary.json`
- `tool-gateway/.smoke/full-20260804-0209/screenshots-index.md`

这些 `.smoke` 原始证据保留在本地且不会提交 provider 配置或密钥。关键截图与本报告将
作为邮件附件发送。
