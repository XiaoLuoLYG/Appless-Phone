# Composio App User Auth Design

日期：2026-07-07

## 目标

在 AIPhoneDemo 内提供一个面向终端用户的 Composio 授权流程。用户可以在 App 内看到当前项目启用的全部 Composio Auth Config，并逐个授权自己的第三方账号。授权完成后，现有 Composio dynamic query 使用该用户自己的 connected accounts。

## 范围

- 新增独立 Composio 授权页。
- 每个 App 用户有独立 `composioUserId`。
- 授权页支持 Composio 项目内当前启用的全部 Auth Config，不维护固定工具名单。
- 新增工具后，只要后端能从 Composio 读到 Auth Config，App 授权页自动显示。
- Composio dynamic search/execute 继续作为 Composio 能力入口。
- 发送、创建、更新类 Composio 工具可以自动执行，但必须来自当前 session search 返回的 tool slug，并且只能使用当前用户已授权账号。

## 不做

- 不替换现有 Gmail、SocialHub Slack、X、Google Calendar、Google Maps、Stripe、YouTube 等本地工具的数据来源。
- 不改变现有静态 `toolId` 的路由和 UI。
- 不把 Composio API key 打进 HAP。
- 不实现多账号选择。每个 toolkit 先使用最近授权的一个 active connected account。

## 当前状态

`agent_core/src/main/ets/composio/ComposioConfig.ets` 目前从 rawfile 读取 `apiKey/baseUrl/userId`。这是内测形态，不适合正式用户授权。

`agent_core/src/main/ets/composio/ComposioSessionClient.ets` 已经会按 `userId` 查询 active connected accounts，并用这些账号创建 tool router session。

`agent_core/src/main/ets/aiphone/runtime/ComposioDynamicBackend.ets` 已经有 Composio dynamic search/execute、toolkit scope、以及若干 Composio 结果卡片适配。下一步应把 toolkit 名单和 auth 状态改成由后端 Auth Config 清单驱动。

## 用户身份

App 启动时读取本地 `composioUserId`：

- 如果未来有正式登录系统，使用登录用户 ID 派生稳定 ID。
- 当前 MVP 没有登录时，首次启动生成安装级 UUID，并保存到 Preferences。
- 开发设置里允许重置该 UUID，用于测试新用户隔离。

这个 ID 只用于 Composio 账号隔离，不等于用户真实邮箱或手机号。

## 后端代理

新增一个轻量后端代理，所有 Composio API key 只放后端。

### GET /v1/composio/auth-configs

返回当前项目启用的 Auth Config，加上当前用户连接状态。

返回字段：

- `authConfigId`
- `toolkitSlug`
- `toolkitName`
- `logoUrl`
- `authScheme`
- `management`
- `status`
- `connectedAccountId`
- `connectedAccountLabel`
- `lastConnectedAt`
- `canExecute`

后端从 Composio Auth Configs 和 Connected Accounts 聚合该列表。App 不写死 GitHub、Drive、Docs、Slack 等名单。

### POST /v1/composio/link

入参：

```json
{
  "authConfigId": "ac_xxx",
  "toolkitSlug": "github",
  "composioUserId": "app-user-uuid"
}
```

后端调用 Composio `POST /api/v3.1/connected_accounts/link`，传 `auth_config_id`、`user_id`、`callback_url` 和可读 alias，返回 OAuth URL。

### GET /v1/composio/accounts

刷新当前用户所有 connected accounts 状态。授权页返回前台或用户点刷新时调用。

### POST /v1/composio/disconnect

可选。MVP 可以先只做重新授权。需要断开时再接 Composio 删除或禁用 connected account 的接口。

## 授权页

会有一个单独页面，建议命名为 `ComposioAuthPage`，入口放两个地方：

- 设置页里的“Composio 授权”按钮。
- Composio dynamic query 返回 `needs_auth` 时的“去授权”按钮。

页面结构：

- 顶部显示当前 App 用户 ID 的短码和刷新按钮。
- 主列表展示全部 Auth Config 卡片。
- 卡片显示 app logo、toolkit 名、授权状态、账号标签、最近更新时间。
- 主按钮按状态变化：`授权`、`重新授权`、`刷新`。
- 失败状态直接显示 Composio 或后端返回的真实错误。

视觉上复用现有 A2UI 卡片风格，不做营销页。卡片半径、字体、按钮状态和现有 `ToolConnectCardView` 保持一致。

## Dynamic 执行策略

Composio query 不替换现有静态工具。触发条件仍然是：

- 用户明确说“Composio”。
- 用户提到的 toolkit 只存在于 Composio Auth Config 清单中，且没有对应静态工具要优先处理。

执行流程：

1. 根据 prompt 选择 toolkit scope。能识别 toolkit 时，只启用该 toolkit。
2. 用当前 `composioUserId` 查询 active connected accounts。
3. 创建 Composio tool router session。
4. 调 search。
5. 选中最匹配的 tool slug。
6. 生成 arguments。
7. 自动 execute。
8. 返回真实结果卡片。

发送、创建、更新类工具不再用本地 `unsafe_action_blocked` 阻断，但仍要满足三个条件：

- 该 toolkit 已由当前用户授权。
- tool slug 来自当前 session search 结果。
- arguments 来自当前用户 prompt 和 Composio schema，不使用隐藏默认收件人、频道或金额。

## 安全与透明度

- Composio API key 只在后端。
- App 不复用开发者自己的 connected accounts。
- 授权页明确显示每个工具连接的是当前用户账号。
- 每次 execute 结果卡片显示 provider、tool slug、状态和关键返回摘要。
- 失败时显示真实错误，不模拟外部数据。
- 支付类和现有本地工具保持原逻辑，不因为 Composio 授权页而改变。

## 验证

代码级验证：

- `ComposioAuthConfigClient` 能解析多个 Auth Config，包括新增 toolkit。
- `ComposioUserStore` 首次生成 UUID，之后稳定读取。
- auth config 列表为空时显示空状态。
- link 请求不会把 API key 放进 App 请求体。
- dynamic execute 只允许执行当前 search 返回的 tool slug。

设备验证：

- 新安装用户打开授权页，看到当前 Composio 项目全部启用 Auth Config。
- 新增一个 Auth Config 后刷新页面，新卡片出现。
- 授权 GitHub、Docs、Drive、Slack 后，四个既有 Composio query 继续通过。
- 对一个测试用 toolkit 执行创建或发送类 query，确认不会再被 `unsafe_action_blocked` 拦截，并且真实 Composio 返回成功或真实错误。
- 重置 `composioUserId` 后，授权页不再显示旧用户 connected accounts。

## 交付顺序

1. 后端代理接口和本地 mock 响应。
2. App 用户 ID 存储。
3. 独立授权页和设置入口。
4. OAuth link 打开与返回后刷新状态。
5. ComposioDynamicBackend 改为使用当前用户和动态 toolkit 清单。
6. 放开 Composio create/send/update execute 阻断。
7. 设备 smoke 增加授权页和新工具验证。
