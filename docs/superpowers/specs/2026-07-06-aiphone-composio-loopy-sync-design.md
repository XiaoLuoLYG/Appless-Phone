# AIPhone Composio Loopy Sync Design

## Decision

Use the local AIPhoneDemo repo as the day-to-day development source for now. Bring Loopy `hos` Composio support into local `agent_core` as a dynamic backend capability, then push the updated AIPhone runtime back to Loopy without overwriting Loopy's Composio work.

This follows option A from the discussion: keep local development fast, keep the diff small, and use PRs plus smoke checks to keep Loopy aligned.

## Current State

- Local branch base is `origin/main` commit `2578b60d`, plus user-local uncommitted changes. The design treats the current working tree as the latest local code, but the implementation must not overwrite or discard those changes.
- Local `agent_core` is the runtime used by AIPhoneDemo through `@loop/agent-core`.
- Local latest runtime already includes SocialHub, X OAuth, persona `memory.update`, payment tools, dynamic search, and updated ReAct parsing behavior.
- Loopy `hos` latest remote is `bd5f873`. It adds Composio to the generic Loop `ToolRegistry`, not to AIPhoneDemo's `LoopBackend` path.
- Loopy still needs the latest AIPhone runtime changes in the reverse sync, including the post-PR #37 payment/runtime updates.

## Scope

In scope:

- Add Loopy's Composio source files to local `agent_core`.
- Expose Composio as one backend for AIPhone `dynamic.search`.
- Preserve existing fixed AIPhone tools. Existing supported domains keep their current route.
- Add minimal config example/schema for Composio without committing secrets.
- Update local verification so Composio contracts are covered.
- Update or replace the Loopy PR so Loopy gets current AIPhone runtime changes while keeping its Composio code.

Out of scope:

- Switching AIPhoneDemo to consume Loopy as the sole external HAR/package.
- Replacing existing ModelScope-derived dynamic catalog.
- Adding a new visible `composio.search` or `composio.execute` fixed tool unless `dynamic.search` proves insufficient.
- Auto-executing high-risk Composio side-effect tools without a confirmation boundary.

## Architecture

Keep `LoopBackend` as the AIPhone tool owner. Do not wire AIPhoneDemo through Loopy's generic `createConfiguredLoopToolRegistry()` path, because the app currently depends on `LoopBackend` for fixed tool descriptions, `memory.update`, JSONL emission, and product safety rules.

Add the Loopy Composio classes under `agent_core/src/main/ets/composio/`:

- `ComposioConfig`
- `ComposioSessionClient`
- `ComposioTool`, only if still useful as a thin adapter or contract reference

Add only the small `Index.ets` exports needed by tests or future consumers. Avoid importing Composio from `ToolRegistry.ets` unless the generic Loop chat path actually needs it locally.

The AIPhone path should call Composio from `ToolGatewayClient` when handling `dynamic.search`. The smallest useful flow is:

1. If the existing fixed tool or local dynamic catalog handles the query, keep that result.
2. If not, and Composio config is present, call Composio search with the user task.
3. Return a dynamic result showing candidate Composio tools and whether execution is available.
4. Execute read-only or clearly safe tools only after the model selects a returned schema.
5. For likely side-effect tools, return a confirm/block result instead of executing immediately.

Reuse the existing dynamic-tool safety shape where possible, especially the current unsafe-tool detection in `DynamicToolRegistry`.

## Data Flow

Configuration comes from a rawfile named `composio_config.json`, matching Loopy. The repo should only track an example file or documented schema:

```json
{
  "apiKey": "",
  "baseUrl": "https://backend.composio.dev/api/v3.1",
  "userId": ""
}
```

Runtime flow:

```text
user query
  -> LoopBackend
  -> dynamic.search
  -> existing local dynamic catalog
  -> Composio search fallback when local catalog has no useful result
  -> A2UI dynamic result / confirmation / error
```

Composio failures must be truthful: missing config, no active connected account, HTTP error, no matching tool, and unsafe action blocked should each render as a real status, not a fabricated provider result.

## Safety

Loopy's Composio README warns that discovered tools execute immediately, including side effects. AIPhoneDemo should not copy that behavior blindly.

Initial policy:

- Read/search/list/get tools may execute if config and connected account are present.
- Create/send/update/delete/pay/transfer/post/invite/share style tools are blocked or surfaced as confirmation-needed.
- Payment-related queries should stay on AIPhoneDemo's existing `payment.send` and `payment.account.setup` tools, not Composio.
- Gmail/Calendar/Social/Maps/Food/Travel queries should keep current fixed routes unless the user explicitly asks for an unsupported app/toolkit.

This keeps Composio as a backend extension, not a bypass around current product boundaries.

## Reverse Sync To Loopy

The Loopy update should preserve Composio from PR #4 and bring AIPhone runtime forward from local latest code.

Candidate Loopy changes:

- Replace old SocialBridge files with SocialHub runtime.
- Add X OAuth and SocialHub provider config.
- Add persona `memory.update` runtime support.
- Add payment tool definitions/runtime from the latest local branch.
- Add current ReAct parsing fixes and tests.
- Update `harmony/scripts/verify-aiphone-backend.mjs` to match current local `scripts/verify-loopy-backend.mjs` contracts.
- Keep `harmony/agent_core/src/main/ets/composio/*` and generic Loop Composio registry exports.

Do not copy local `agent_core` over Loopy wholesale. Merge by path and preserve Loopy-only Composio files.

## Verification Queries

Core regression queries should still cover existing supported tools:

- `帮我查一下最近重要邮件`
- `帮我创建一封回复邮件草稿`
- `帮我查今天 X 和 Slack 上的消息`
- `帮我搜索 OpenAI 在 X 上的公开 post`
- `把饮食搭子的 memory 改成：用户咖啡偏好：只喝瑞幸咖啡。`
- `用 PayPal 给罗一格转 5 美元`

Composio-focused queries should cover frequent unsupported domains. These should only pass when the matching Composio connected account exists; otherwise the expected result is a truthful missing-config or no-connected-account state.

- Notion: `帮我在 Notion 里找一下 7 月旅行计划相关页面`
- Google Drive: `帮我在 Google Drive 里找签证材料`
- Linear: `帮我查 Linear 里分配给我的高优先级 bug`
- GitHub: `帮我查 AIPhoneDemo 最近失败的 workflow run`
- Asana/Trello: `帮我给本周发布创建一个 checklist`
- HubSpot/Salesforce: `帮我查 Alex 的客户记录`

Side-effect verification should not silently perform writes. For create/update/send cases, expected behavior is either a confirmation-needed A2UI result or an explicit blocked unsafe-action result until a confirmation flow exists.

## Checks

Before claiming the local branch works:

- `node scripts/verify-loopy-backend.mjs`
- focused unit tests for `ComposioConfig`, Composio dynamic result mapping, and unsafe Composio blocking
- targeted device smoke for existing high-risk routes and the new Composio queries when config is available

Before opening/updating the Loopy PR:

- Loopy `harmony/scripts/verify-aiphone-backend.mjs`
- a temporary AIPhoneDemo worktree smoke if Loopy runtime files changed beyond exports/config

## Branch And PR Hygiene

- Work on `aiphone-composio-loopy-sync`.
- Stage only intentional files. Existing user-local modified files must be reviewed before staging.
- Keep secrets and local debug folders out of commits.
- If a product PR is created from this branch, call out any included `docs/superpowers` design commit so it is not mistaken for runtime code.
