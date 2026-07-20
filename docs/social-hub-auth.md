# SocialHub 授权与接入指南

SocialHub 的 X/Twitter、Slack 授权与读取统一使用当前用户的 Composio connected account；企业微信仍使用本地回调/缓存。它可以生成本地回复草稿，但只有用户点击发送后才会尝试提交 Slack 回复。

## 功能边界

- 支持：通过 Composio 聚合读取已授权 X/Slack 来源、读取企业微信回调缓存、查看公开 X 帖子、基于真实条目生成本地回复草稿，以及在用户确认后通过 Composio 发送 Slack 线程回复。
- 不支持：自动发送、批量群发、代用户发布 X 帖子、发送 X 私信回复或发送企业微信消息。
- 草稿要求已有 SocialHub 条目被选中或已缓存；草稿字段会标记 `localOnly`，未发送时 `sent` 为 `false`。
- 缺少授权、scope 不足、触发限流或供应商报错时，界面必须显示可见的连接或错误状态，不能编造消息、帖子、联系人、频道或发送成功。

## X/Twitter

1. 在 App 的“应用授权”页选择 X，并完成 Composio 授权。
2. SocialHub 通过 Composio 读取 X 私信和公开 post；旧的 App 内 X OAuth 入口与 token 直连已移除。
3. 当前不发送 X 私信、回复或公开 post；缺少工具、scope 或额度时显示真实限制。

## Slack

1. 在 App 的“应用授权”页选择 Slack，并完成 Composio 授权。
2. SocialHub 读取固定使用 Composio `SLACK_SEARCH_MESSAGES`。
3. 用户确认发送回复时，固定使用 Composio `SLACK_CHAT_POST_MESSAGE`，并保留真实 channel ID 和 thread timestamp。
4. 没有可执行工具、写 scope 或 provider 成功回执时，界面显示真实错误，不会声称已发送。

## 企业微信

1. 在企业微信管理后台创建自建应用，记录 CorpID、AgentID 和 Secret。
2. 配置回调 URL，并设置回调 Token 和 EncodingAESKey。
3. Social Bridge 需要用回调 token gate 校验企业微信回调来源。
4. 第一版企业微信读取来自 Social Bridge 的 callback cache；群机器人 webhook 只能用于单向推送，不能作为 SocialHub 的读取来源。

## 授权与本地配置

- X/Twitter、Slack：`COMPOSIO_API_KEY`、`COMPOSIO_USER_ID` 和各自 connected account
- 企业微信：`WECOM_CORP_ID`、`WECOM_AGENT_ID`、`WECOM_SECRET`
- 企业微信回调：`WECOM_CALLBACK_TOKEN`、`WECOM_ENCODING_AES_KEY`

安装 HAP 前运行 `node scripts/sync-provider-config.mjs`，同步被 git 忽略的本地配置。企业微信 callback 仍按其 callback token 校验。

## 草稿规则

`social.reply.draft` 只能基于已有的真实 SocialHub item 生成本地草稿。草稿不会自动发送；Slack 只有在用户点击发送后才经 Composio 提交，X 和企业微信仍只保留草稿。
