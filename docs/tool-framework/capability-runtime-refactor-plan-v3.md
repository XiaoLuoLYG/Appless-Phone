# Appless Phone Capability Runtime 重构计划（V3）

> 文档状态：执行中
>
> 当前版本：V3.2
>
> 最后更新：2026-08-07
>
> 代码根目录：`agent_core/src/main/ets/capability/`

本文档是 Appless Phone Capability Runtime 重构的长期跟踪基线。所有阶段状态必须以仓库中的可验证代码和测试为依据；仅创建类、目录或兼容包装器，不等同于完成业务迁移。

## 1. 状态规则

| 标记 | 含义 |
|---|---|
| ✅ 完成 | 本阶段退出条件全部满足，并有自动化或设备证据 |
| 🟡 进行中 | 已有实现，但仍依赖旧架构或缺少验收证据 |
| ⬜ 未开始 | 尚无有效实现，或只有不会进入生产路径的占位代码 |
| 🚫 本期不做 | 已明确排除在 V3 本期范围之外 |

维护规则：

1. 每次合并相关改动时，更新“最后更新”、阶段状态、检查项和变更记录。
2. 不得因为文件已经创建就勾选迁移完成。
3. Domain 完成的最低标准是：Spec、Schema、Handler、Provider、Validator、Presenter 和 Policy 均不再依赖旧业务实现。
4. 阶段只有在“退出条件”全部满足后才能标记为 ✅。
5. 兼容层允许在迁移期存在，但新模块不得反向依赖 `compatibility/`。

## 2. 当前总览

| 工作流 | 当前状态 | 当前结论 |
|---|---|---|
| Phase 0：冻结现有行为 | 🟡 进行中 | 已固定 53 个 Tool ID 并通过现有 326 项检查，但缺完整行为快照和设备验收 |
| Phase 1：Capability 基础设施 | 🟡 进行中 | 主干和兼容适配器已建立，但已与生产入口隔离，尚未接入现有业务 |
| Phase 2：Hotel / Calendar 垂直迁移 | 🟡 进行中 | 只有 Module 外壳和隔离 Registry 归属，生产业务仍完整走旧实现 |
| Phase 3：剩余固定 Capability | ⬜ 未开始 | 其他领域仅通过 Legacy Adapter 注册 |
| Phase 4：动态 Capability | 🟡 进行中 | Discovery、Registry、Classifier 骨架已建立，动态 Provider 尚未接入 |
| Phase 5：移除旧架构 | ⬜ 未开始 | 旧 Gateway、Registry、Executor 和 Renderer 尚未删除 |
| Gateway `/v1/tool/call` | 🟡 进行中 | 服务端协议已建立，HarmonyOS RemoteGatewayBackend 尚无真实 HTTP/NDJSON 实现 |

当前准确描述：

> V3 基础设施已经可以编译，并能在测试或显式创建的隔离环境中注册 53 个固定 Tool；当前没有接入 DataAgent、ActionAgent、MultiAgentRuntime、HotelAgentRuntime 或现有 `callStructuredTool()` 生产路径，原业务继续使用旧 ToolGatewayClient 和旧 Action Executor。

### 当前提交安全边界

- [x] 现有 `callStructuredTool()` 保持原实现，不创建 CapabilityRuntime。
- [x] ActionAgent 保持原确认、暂停和恢复状态机。
- [x] MultiAgentRuntime 和 HotelAgentRuntime 不创建或注入 Capability 环境。
- [x] Capability Runtime 只通过测试、显式 Factory 调用或新增独立 Gateway 协议使用。
- [x] 旧 `/api/aiphone/tool` 和 `/mcp/call` 路由保持原执行方式。
- [ ] 在接入任何生产入口前，必须增加 feature flag、等价回归和快速回退路径。

## 3. 已确定的架构取舍

- [x] 所有新 Capability 模块位于 `agent_core/src/main/ets/capability/`。
- [x] Tool 是唯一原子执行单元。
- [x] Capability 是组织、注册、治理和未来分发单元。
- [x] 使用 `CapabilityRegistry`。
- [x] HarmonyOS 端是 Registry、Policy 和 Executor 主控制面。
- [x] 采用兼容式、按 Capability 迁移。
- [x] 首批选择 Hotel 与 Calendar。
- [x] Multi-Agent Planner 本期继续直接选择 Tool ID。
- [x] Node Gateway 是远端 Backend，不是第二套主控 Runtime。
- [ ] 所有 ToolCall 最终统一通过 `CapabilityRuntime.invoke()` 执行。
- [ ] 页面只挂载 Surface，不再按 Tool ID 选择业务 Renderer。
- [ ] Provider 不再生成 A2UI。
- [ ] Domain Policy 只能收紧全局 Policy，不能绕过全局规则。
- [x] 🚫 本期不实现 Capability Router。
- [x] 🚫 本期不实现 Plugin System，只保留 `CapabilityModule`/Manifest 接口。
- [x] 🚫 本期不重写完整 Skill Runtime、Session、Memory、Artifact Store 或 Subagent。

## 4. 目标目录

```text
agent_core/src/main/ets/capability/
├── contracts/
├── registry/
├── runtime/
├── policy/
├── backends/
├── discovery/
├── presentation/
├── observability/
├── domains/
├── compatibility/
└── bootstrap/
```

目前已经存在上述一级目录及 87 个 Capability 源文件。以下细分目录仍需要随着真实迁移建立：

```text
discovery/{mcp,composio,modelscope,remote}/
domains/{core,travel,local_life,communication,productivity,media,commerce,research,connectors}/
<domain>/{manifest,specs,schemas,handlers,providers,validators,presenters,planning,policies}/
presentation/artifacts/
```

## 5. 目标执行链路

```text
Multi-Agent Runtime
        │
        │ 选择具体 Tool ID
        ▼
CapabilityRegistry
        ▼
CapabilityRuntime.invoke(ToolCall)
        ├── Argument Normalization
        ├── Schema Validation
        ├── Backend Resolution
        ├── Effect Analysis
        ├── Policy / Approval
        ├── Execution
        ├── Result Validation
        └── Execution Events
        ▼
ToolResult
        ▼
PresenterRegistry
        ▼
A2UI / URL / Provider Receipt
```

当前生产 Data 路径保持不变：

```text
DataAgent
  → callStructuredTool()
  → 旧 Provider / Tool ID 分支
```

当前生产 Action 路径保持不变：

```text
ActionAgent
  → ActionPlanRunner 原确认/暂停/恢复
  → RegisteredActionExecutor
  → 旧 Action / Provider 实现
```

Capability 隔离验证路径：

```text
测试或显式 Factory 调用
  → ApplessCapabilityRuntimeFactory
  → CapabilityRegistry / CapabilityRuntime
  → LegacyToolGatewayAdapter 或测试 Handler
```

生产接入将在 Phase 1 安全硬化和行为等价测试完成后另行进行。

## 6. 模块依赖规则

允许的依赖方向：

```text
contracts
   ↑
registry / policy / backends / presentation / observability
   ↑
domains / discovery
   ↑
runtime
   ↑
bootstrap
   ↑
entry / Multi-Agent Runtime
```

长期约束：

- [ ] 增加自动化 import-boundary 测试，禁止反向依赖。
- [ ] `contracts` 不依赖 Provider、A2UI、页面或 Agent。
- [ ] `registry` 不调用 Handler。
- [ ] `domains` 不依赖 Runtime 实现。
- [ ] `backends` 不依赖 Agent、页面或 A2UI。
- [ ] `presentation` 不依赖 Provider。
- [ ] `entry` 页面不直接依赖领域 Provider。
- [ ] 除 `compatibility` 外，新框架不得导入旧类型。

## 7. Phase 0：冻结现有行为

状态：🟡 进行中

### 已完成

- [x] 通过测试固定现有 53 个固定 Tool ID。
- [x] 保持旧 `ToolDefinitionRegistry` 字面定义不变。
- [x] 新 Registry 与旧 53 Tool ID 做精确集合对比。
- [x] 现有 HAR 构建成功。
- [x] 现有 `verify-loopy-backend` 326 项检查通过。
- [x] Gateway `/v1/tool/call` 无 A2UI 响应的 smoke case 已加入测试脚本。

### 待完成

- [ ] 将 53 个 ToolSpec 基线导出为可审查的版本化 fixture。
- [ ] 固化所有 ActionLink 基线。
- [ ] 固化各 Tool 的 DataResult 成功、空结果、部分结果和错误基线。
- [ ] 固化现有 A2UI 输出快照。
- [ ] 固化 confirmation、暂停、恢复、错 Turn、错 Surface 和 replay 行为。
- [ ] 增加新旧模块 import-boundary 测试。
- [ ] 在可用设备或模拟器上完成 Hypium 执行。
- [ ] 完成 C01–C22、F01–F16 验收。
- [ ] 验证自动测试不会产生支付、发送、下单或删除副作用。

### Phase 0 退出条件

- [ ] 所有固定定义、ActionLink、DataResult 和 A2UI 都有版本化 fixture。
- [ ] 审批与 replay 行为有自动化覆盖。
- [ ] 设备测试证据可复现。

## 8. Phase 1：建立 Capability 基础设施

状态：🟡 进行中

### 已完成：Contracts

- [x] `CapabilityManifest`
- [x] `CapabilityModule`
- [x] `ToolSpec`
- [x] `ToolCall`
- [x] `ToolResult` / `ToolError`
- [x] `ToolEffect` / `ToolArtifact`
- [x] Approval、Policy、Event、Backend、Presenter、Schema 公共类型

### 已完成：Registry 与 Bootstrap

- [x] Capability、Tool、Schema、Handler、Presenter Registry。
- [x] PlanningProfile、ActionLink Registry。
- [x] Capability → Tool 与 Tool → Capability 索引。
- [x] 重复 ID、缺失引用和 Manifest 权限覆盖校验。
- [x] 53 个固定 Tool 通过兼容 Adapter 注册。
- [x] `dynamic.search` 作为独立兼容 Capability 注册。
- [x] 唯一组合根创建 Registry、Runtime、Policy、Backend 和 Event Sink。
- [x] 对外公共导出加入 `agent_core/Index.ets`。

### 已完成：Runtime 第一版

- [x] ToolCall 基础规范化。
- [x] Tool/version/deadline 检查。
- [x] 输入和输出 Schema 调用链。
- [x] Effect Analysis 和 Policy Decision。
- [x] Backend Resolution。
- [x] 进程内并发控制。
- [x] 执行事件。
- [x] 通用 Result Validation。
- [x] Runtime `resumeWithApproval()` 和 `cancel()` 接口。

### 已完成：Policy 第一版

- [x] `ALLOW`、`DENY`、`APPROVAL_REQUIRED`。
- [x] DataAgent 禁止执行非 read Tool。
- [x] 未知动态写工具默认隔离。
- [x] Approval 绑定 call、tool/version、参数摘要、conversation、turn、task、surface 和 step。
- [x] Approval TTL 和单次消费。
- [x] Gmail send 保持 manual-only。

### 已完成：隔离兼容能力

- [x] 已实现旧 ToolDefinition、DataResult、ToolGateway 和 ActionCatalog 适配器。
- [x] Capability Runtime 可由测试或显式 Factory 创建。
- [x] 旧 `DataResult` 与新 `ToolResult` 的边界适配代码已实现。
- [x] 新框架从 `agent_core/Index.ets` 导出，但不会由现有生产入口自动实例化。
- [x] 现有业务入口保持旧实现。

### 暂缓：生产接入

- [ ] `callStructuredTool()` 进入 CapabilityRuntime。
- [ ] ActionAgent 在执行前调用统一 Policy，并且保持原确认/恢复语义。
- [ ] ActionAgent 最终通过 CapabilityRuntime 执行 ToolCall。
- [ ] MultiAgentRuntime 和 HotelAgentRuntime 注入统一 Runtime/Policy/Registry。
- [ ] 通过 feature flag 灰度启用，并提供一键回退到旧链路。
- [ ] 旧公开接口在接入后继续保持兼容。

### 待完成：Phase 1 硬化

- [ ] 参数摘要改为 canonical JSON，而非直接 `JSON.stringify()`。
- [ ] SurfaceAuthority 校验真实的当前 Turn/Surface，而非只检查非空字符串。
- [ ] CredentialPolicy 接入真实 CredentialResolver、scope 和网络权限。
- [ ] 生产接入时让 Action UI 使用 ApprovalRequest/ApprovalGrant 和 `resumeWithApproval()`，不得使用布尔确认桥接。
- [ ] Cancel 通过 AbortSignal 传播到运行中的 Backend/Provider。
- [ ] 并发控制支持账户、资源和 Provider 维度。
- [ ] 明确部分副作用后的 failover 禁止规则。
- [ ] Retry 策略支持幂等 Tool，非幂等 Tool 保持禁止自动重试。
- [ ] Audit/Metrics 持久化并补齐 latency、retry、provider、conversation/turn/task/surface 字段。
- [ ] 日志脱敏增加值模式检测，而不只按字段名过滤。
- [ ] 增加上述能力的自动化测试。

### Phase 1 退出条件

- [ ] 所有生产 Tool 入口至少经过统一 Policy。
- [ ] 生产审批链使用不可伪造、不可重放的 ApprovalGrant。
- [ ] Credential、Surface、Cancel、Retry 和 Audit 满足安全契约。
- [ ] 兼容接入不改变 53 个 Tool 的外部行为。

## 9. Phase 2：迁移 Hotel 与 Calendar 垂直切片

状态：🟡 进行中

### 9.1 Travel / Hotel

范围：

- `hotel.search`
- `hotel.detail`
- `hotel.navigate`
- `hotel.booking.open`

已完成：

- [x] 创建 `HotelCapabilityModule`。
- [x] Registry 中归属 `travel.hotel`。
- [x] 现有 Tool ID、ActionLink 和 Planner 可见性保持兼容。
- [ ] Hotel Action 进入统一 Capability Policy 检查；当前为避免影响原业务，尚未接入。

待完成：

- [ ] `HotelCapabilityModule` 不再继承 `LegacyToolRegistryAdapter`。
- [ ] 建立 `manifest/` 和独立 Manifest。
- [ ] 建立 `specs/` 和四个独立 ToolSpec。
- [ ] 建立 `schemas/` 和真实输入/输出 Validator。
- [ ] 建立 `handlers/` 并迁移工具业务流程。
- [ ] 将 RollingGo 适配移入 `providers/RollingGoHotelProvider.ets`。
- [ ] 建立领域 Result Validator，验证 hotel ID、booking URL 和 Provider 证据。
- [ ] 建立 Hotel Presenter，不再使用 `A2uiLegacyAdapter`。
- [ ] 建立 Planning Profile。
- [ ] 建立 Hotel Effect/Policy 收紧规则。
- [ ] 从 `ToolGatewayClient` 删除 Hotel Tool ID 分支。
- [ ] Hotel Action 通过 `CapabilityRuntime.invoke()` 执行。
- [ ] Hotel 页面不直接依赖 Provider 或业务 Renderer。

### 9.2 Productivity / Calendar

范围：

- `calendar.events.search`
- `calendar.event.create`
- `calendar.event.update`
- `calendar.event.delete`

已完成：

- [x] 创建 `CalendarCapabilityModule`。
- [x] Registry 中归属 `productivity.calendar`。
- [x] 现有 Tool ID 和 Planner 可见性保持兼容。
- [ ] Calendar Action 进入统一 Capability Policy 检查；当前为避免影响原业务，尚未接入。

待完成：

- [ ] `CalendarCapabilityModule` 不再继承 `LegacyToolRegistryAdapter`。
- [ ] 建立独立 Manifest、Spec、Schema 和 Validator。
- [ ] 迁移 Calendar search/create/update/delete Handler。
- [ ] 将 OAuth/Composio Calendar Provider 移入 Domain。
- [ ] create/update/delete 使用真实 ApprovalGrant 恢复执行。
- [ ] Validator 验证 event ID、requested ID、时间和状态 receipt。
- [ ] Calendar Presenter 不再使用旧 Renderer。
- [ ] 从 `ToolGatewayClient` 和旧 Action Executor 删除 Calendar 分支。
- [ ] Calendar 四个 Tool 全部通过 `CapabilityRuntime.invoke()`。

### Phase 2 退出条件

- [ ] Hotel 和 Calendar 不依赖 `LegacyToolRegistryAdapter`。
- [ ] 八个 Tool 不经过 `callStructuredToolLegacy()` 或旧 Action Executor。
- [ ] Provider、Validator、Presenter 均位于对应 Domain。
- [ ] 八个 Tool 的 Registry、Runtime、Policy、Approval、Backend、Validator、Presenter 测试通过。
- [ ] 真机/模拟器回归与现有 A2UI 行为兼容。

## 10. Phase 3：迁移剩余固定 Capability

状态：⬜ 未开始

迁移顺序：

1. 只读工具。
2. MCP/远程读取。
3. draft 和 system intent。
4. external write、send、payment、order、delete。

领域跟踪：

- [ ] `travel/transport`
- [ ] `local_life/food`
- [ ] `local_life/maps`
- [ ] `local_life/ride`
- [ ] `local_life/luckin`
- [ ] `communication/mail`
- [ ] `communication/gmail`
- [ ] `communication/social`
- [ ] `communication/whatsapp`
- [ ] `media/youtube`
- [ ] `media/aggregate`
- [ ] `media/worldcup`
- [ ] `commerce/payment`
- [ ] `commerce/shopping`
- [ ] `research/web`
- [ ] `research/monitor`
- [ ] `core`
- [ ] `connectors`

每个子域完成标准：

- [ ] 独立 Manifest、Spec、Schema、Handler、Provider、Validator、Presenter、Planning 和 Policy。
- [ ] 不依赖 Compatibility 或旧业务实现。
- [ ] 不在 CapabilityRuntime 中增加业务 Tool ID 分支。
- [ ] 从旧 ToolGatewayClient 删除对应分支。
- [ ] 只读和写入安全测试通过。

### Phase 3 退出条件

- [ ] 53 个固定 Tool 均由真实 Capability Domain 拥有。
- [ ] 固定 Tool 不再通过 LegacyToolGatewayAdapter 执行。
- [ ] 所有固定 ToolCall 通过同一个 Runtime 和 Policy。

## 11. Phase 4：迁移动态 Capability

状态：🟡 进行中

已完成：

- [x] `DynamicCapabilityDiscovery` 接口。
- [x] `DynamicCapabilityRegistry`。
- [x] `DynamicToolSafetyClassifier`。
- [x] Ephemeral Manifest 必须标记 dynamic。
- [x] 未知动态写/破坏性 Tool 默认不可执行。
- [x] `dynamic.search` 兼容 Module。

待完成：

- [ ] MCP Adapter 将 metadata 转成 `mcp:<server>/<tool>` ToolSpec。
- [ ] Composio Adapter 将工具转成 `connector:<provider>/<slug>`。
- [ ] ModelScope Adapter。
- [ ] Remote discovery Adapter。
- [ ] `dynamic.search` 改为 discover → register → select → Runtime.invoke。
- [ ] Ephemeral Capability TTL、刷新和卸载。
- [ ] 固定 Tool 与动态 Tool ID 冲突检查。
- [ ] MCP annotation 映射为 Effect 和安全等级。
- [ ] 删除动态工具名称启发式授权。
- [ ] Dynamic、MCP、Composio、ModelScope 安全旁路测试。

### Phase 4 退出条件

- [ ] 所有动态 Tool 都以命名空间 ID 注册后执行。
- [ ] 动态 Provider 不可绕过 Registry、Schema、Policy 和 Audit。
- [ ] 未知写工具默认隔离，只有明确授权后才能执行。

## 12. Phase 5：移除旧架构

状态：⬜ 未开始

- [ ] `ToolGatewayClient` 只保留临时 facade 和必要 transport。
- [ ] `StructuredToolUiRenderer` 只保留通用 Surface host。
- [ ] Action-specific executor 改成 Runtime adapter 后移除。
- [ ] 删除重复固定 Registry。
- [ ] 删除旧 Dynamic Registry。
- [ ] 删除 Tool ID 业务调度分支。
- [ ] 删除 Provider → A2UI 路径。
- [ ] 旧公开接口经过一个稳定发布周期后删除。
- [ ] 清理 Compatibility Module。

### Phase 5 退出条件

- [ ] 生产代码不存在 Legacy Tool Gateway 业务执行路径。
- [ ] 页面、Agent、Backend、Provider 和 Presenter 依赖边界测试通过。
- [ ] 完整回归、设备测试、Gateway smoke 和安全测试通过。

## 13. Gateway 重构跟踪

状态：🟡 进行中

已完成：

- [x] 新增 `POST /v1/tool/call`。
- [x] 接受版本化 ToolCall wire object。
- [x] 返回 NDJSON queued/started/completed/failed 事件。
- [x] 终态事件包含 ToolResult。
- [x] 响应不包含 A2UI 指令。
- [x] 保留 `/api/aiphone/tool` 和 `/mcp/call`。
- [x] 增加协议 smoke case。

待完成：

- [ ] Gateway Provider 直接返回领域数据，不再先生成旧 A2UI JSONL。
- [ ] HarmonyOS `RemoteGatewayBackend` 实现 HTTP 请求和 NDJSON 解析。
- [ ] 支持 Abort、timeout、typed network error 和版本协商。
- [ ] 明确远端只执行已由 HarmonyOS Policy 授权的调用。
- [ ] 扩展或动态同步 Gateway Tool Catalog，避免独立的四工具静态表成为第二套 Registry。
- [ ] Gateway ExecutionEvent 与本地 Trace/Audit 关联。

## 14. 安全契约跟踪

- [x] Tool ID 和 version 进入审批身份。
- [x] call ID 进入审批身份。
- [x] conversation、turn、task、surface、step 进入审批身份。
- [x] Approval 有过期时间。
- [x] Approval 单次消费和 replay 防护。
- [x] 非幂等成功要求存在非空 receipt。
- [x] DataAgent 禁止调用非 read Tool。
- [x] Gmail send 保持 manual-only。
- [ ] 参数使用 canonical JSON 摘要。
- [ ] 生产 UI 使用 ApprovalGrant，而不是布尔确认桥。
- [ ] SurfaceAuthority 验证真实当前 Surface/Turn 生命周期。
- [ ] Domain Validator 验证真实 receipt/event ID/message ID/order ID。
- [ ] 部分副作用发生后禁止切换备用 Backend。
- [ ] 支付、发送、下单、删除明确禁止自动重试。
- [ ] 自动测试证明不会触发真实写副作用。
- [ ] 日志和事件完成明文凭证扫描。

## 15. 测试与验收矩阵

| 验收项 | 状态 | 当前证据/缺口 |
|---|---|---|
| 53 固定 Tool ID 兼容 | ✅ | `CapabilityRuntime.test.ets` 集合对比 |
| Registry 引用完整性 | ✅ | Registry integrity 测试 |
| Approval Turn/Surface/Args/Replay | 🟡 | Runtime 单测已写并编译；设备 Hypium 未运行 |
| Gmail send manual-only | 🟡 | Runtime 单测已写并编译；设备 Hypium 未运行 |
| HAR 构建 | ✅ | DevEco HAR build successful |
| 现有静态/架构检查 | ✅ | 326 checks passed |
| Gateway wire smoke | ✅ | 本地 NDJSON unknown-tool case 通过 |
| Hypium 设备执行 | ⬜ | 当前没有可用设备/模拟器 |
| C01–C22 | ⬜ | 待执行并保存证据 |
| F01–F16 | ⬜ | 待执行并保存证据 |
| Hotel 真实 Provider 回归 | ⬜ | Provider 尚未迁移 |
| Calendar 写操作回执 | ⬜ | Provider/Validator 尚未迁移 |
| Dynamic 安全旁路 | ⬜ | 动态 Adapter 尚未接通 |
| 支付/发送/下单/删除无副作用 | ⬜ | 待建立隔离测试 |
| 日志凭证扫描 | ⬜ | Redactor 只有第一版 |

## 16. 当前代码证据

- Runtime 主入口：[`CapabilityRuntime.ets`](../../agent_core/src/main/ets/capability/runtime/CapabilityRuntime.ets)
- Registry：[`CapabilityRegistry.ets`](../../agent_core/src/main/ets/capability/registry/CapabilityRegistry.ets)
- 组合根：[`ApplessCapabilityRuntimeFactory.ets`](../../agent_core/src/main/ets/capability/bootstrap/ApplessCapabilityRuntimeFactory.ets)
- 53 Tool 兼容注册：[`ApplessCapabilityModules.ets`](../../agent_core/src/main/ets/capability/bootstrap/ApplessCapabilityModules.ets)
- 现有生产 Gateway（保持原路径）：[`ToolGatewayClient.ets`](../../agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets)
- 现有 Action 状态机（保持原路径）：[`ActionAgent.ets`](../../agent_core/src/main/ets/agent/action/ActionAgent.ets)
- Hotel Module 外壳：[`HotelCapabilityModule.ets`](../../agent_core/src/main/ets/capability/domains/travel/hotel/HotelCapabilityModule.ets)
- Calendar Module 外壳：[`CalendarCapabilityModule.ets`](../../agent_core/src/main/ets/capability/domains/productivity/calendar/CalendarCapabilityModule.ets)
- Gateway 协议：[`server.mjs`](../../tool-gateway/server.mjs)
- 回归测试：[`CapabilityRuntime.test.ets`](../../entry/src/test/CapabilityRuntime.test.ets)

## 17. 下一批执行顺序

1. 补齐 Phase 0 的 fixture 和模块边界测试。
2. 完成 canonical arguments digest、真实 SurfaceAuthority 和生产 ApprovalGrant 接入。
3. 将 Hotel 做成第一个不依赖 Legacy Adapter 的完整垂直切片。
4. 将 Calendar 做成第二个完整垂直切片，重点验证 create/update/delete receipt。
5. 迁移剩余只读 Capability。
6. 迁移 MCP/远端读取。
7. 迁移 draft、system intent 和所有写 Tool。
8. 接通 Dynamic Capability 生命周期。
9. 迁移 Presenter，清理页面 Tool ID 分支。
10. 删除旧 Registry、Gateway 分支、Action Executor 和 Compatibility。

## 18. 变更记录

### 2026-08-07 — V3.2 生产接入暂缓

- 撤回 `callStructuredTool()` 对 CapabilityRuntime 的生产接入，恢复旧 Data Tool 执行链。
- 撤回 ActionAgent、ActionPlanRunner、MultiAgentRuntime 和 HotelAgentRuntime 的 Capability Policy/Registry 注入。
- 保留 Capability Contracts、Registry、Runtime、Policy、Adapter、Factory、测试和独立 Gateway 协议。
- 明确当前提交只包含隔离基础设施，不改变现有业务执行、确认、暂停和恢复路径。
- 将 Data/Action 生产接入重新标记为待完成，并要求 feature flag、等价回归和快速回退。

### 2026-08-07 — V3.1 跟踪基线

- 建立可持续维护的阶段状态和退出条件。
- 明确当时只完成兼容式基础设施，Hotel/Calendar 尚未完成垂直迁移。
- 记录当时 53 Tool Registry、Data Runtime 接入尝试、Action Policy 接入尝试和 Gateway wire protocol 状态。
- 将未完成的安全、Backend、Discovery、Presenter、Observability 和设备验收工作显式列出。
