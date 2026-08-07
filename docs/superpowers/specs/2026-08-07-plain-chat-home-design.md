# 普通对话首页展示设计

## 目标

修复 multiagent-backend 当前普通无工具回复被误显示为“暂无任务结果”的问题，让 assistant 回复成为 generic model 状态的主展示，并保留现有工具任务卡和后端数据流。

## 设计

普通对话沿用现有 HtmlHomeRenderer 页面，不新增路由或页面：

- 主区域使用阅读式答复页：保留轻量标题和说明，但缩小层级；最新 assistant 文本直接作为主要阅读内容。
- 删除“Appless 的回复”“你的请求”等解释性标题。用户请求不重复放在主区域，只作为上下文内容保留。
- 上下文默认折叠，使用原生 `details/summary`，展开后按时间轴展示最近消息。
- 时间轴用细竖线、节点、`你` / `Appless` 标签和字体颜色区分角色，不使用传统左右聊天气泡。
- 普通回复仅在 generic model 且没有工具 blocks、没有执行 timeline、存在可见 assistant history 时启用；其他 generic 空状态仍保留原空态文案。
- 工具场景、multi-task、邮件、社交、支付和原有可展开结果卡不改变。

## 动效与可访问性

- 复用当前 HTML renderer 的暖中性色和单一 accent。
- 使用现有短时 transition，避免新增循环动效。
- 上下文依赖原生折叠语义，支持键盘和无障碍树。
- 遵守 `prefers-reduced-motion`。

## 文件范围

- 修改：`entry/src/main/ets/pages/A2uiHome/html/HtmlHomeRenderer.ets`
  - 增加 plain-chat 判定、答复主区域、折叠时间轴和紧凑样式。
- 修改：`entry/src/test/HtmlHomeRenderer.test.ets`
  - 覆盖普通回复主展示、去除任务结果空态、上下文折叠和角色时间轴。
- 不修改：`HtmlHomeTypes.ets`、`HtmlHomeSnapshot.ets`、multiagent runtime、工具页面和后端协议。

## 验收标准

1. 普通 assistant 回复不再出现“暂无任务结果”或“任务结果”空态。
2. assistant 正文出现在首页主阅读区域。
3. “上下文”默认收起，展开后按时间顺序显示消息。
4. 用户和 assistant 可通过时间轴标签、节点和颜色区分。
5. 工具回复仍保持现有任务卡行为。
6. 相关 Hypium renderer 测试通过，且 diff 不包含用户已有改动。

