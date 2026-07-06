# Generic Multi-Tool Observation Digest Design

Date: 2026-07-06
Repo: `/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo`
Status: approved design

## Goal

Support real multi-step agent tasks such as:

> 从 YouTube 上搜索五个最火的世界杯视频，并发送到邮箱 xxx。

The agent should behave like a bounded ReAct loop:

1. Think about the task.
2. Call a tool.
3. Show the real tool result in A2UI.
4. Convert the tool result into a compact observation digest.
5. Continue reasoning, call another tool if needed, correct mistakes if possible, or return final.

This must reuse the current tool system. Do not create a special YouTube-to-email workflow tool.

## Current State

The current checkout already has the required individual capabilities:

- `youtube.video.search`: public YouTube search through `YouTubeApiClient.ets`.
- `media.video.search`: multi-source video search through `MediaVideoClient.ets`.
- `gmail.draft.create`: creates a real Gmail draft through Gmail API or MCP path.
- `gmail.message.send`: blocked safety fallback. It must not silently send mail.
- `ReActAgentRunner`: already supports multiple loop steps, but currently stops after an A2UI observation.

The blocker is this rule in `ReActAgentRunner`: after a domain tool returns A2UI JSONL, the runner emits `FINAL` immediately. That is good for single-tool surfaces, but it prevents tasks like YouTube search followed by Gmail draft creation.

## Design

Replace the hard stop after A2UI observations with a digest-backed bounded loop.

The loop becomes:

```text
Thought -> Action -> Tool -> A2UI update -> ObservationDigest -> Thought -> Action ... -> Final
```

Tool output still updates the frontend immediately. The model does not get raw A2UI JSONL back. It gets a compact digest that says what happened and what reliable data is available.

## Observation Digest

Add a small formatter that converts A2UI JSONL into text suitable for the ReAct scratchpad.

The digest should include only:

- `toolId`
- surface title and status
- component status when available
- result count
- each result's title, status, source tag, summary
- selected rows with useful labels, such as `Watch URL`, `Video ID`, `To`, `Subject`, `Draft ID`, `Error`
- action labels and ids when available

The digest should not include:

- full JSONL
- full thumbnails or large raw previews
- arbitrary nested data models
- previous unrelated surfaces

For YouTube, this lets the model see the returned video URLs and choose five. For Gmail draft creation, it lets the model see that a draft exists and that it has not been sent.

## Loop Rules

Keep the existing `maxSteps`, defaulting to 6.

Allowed to continue automatically:

- `read` tools, such as YouTube search, mail search, calendar search.
- `draft` tools, such as Gmail draft creation.
- recovery after a real tool error, if the model can correct missing args or choose a better tool.

Must stop for user confirmation:

- `confirm_required` tools.
- any direct send, payment, calendar create/update, or irreversible action.
- any action currently modeled as `blocked`.

Repeated failure rule:

- If the same tool fails twice with the same normalized error, stop and show the real error.
- Do not fabricate fallback results.

## Gmail Send Boundary

The approved behavior is:

1. The agent may automatically create a Gmail draft when the user asks to send an email.
2. The app must show the draft preview and make clear it has not been sent.
3. The actual send requires an explicit user confirmation action.
4. `gmail.message.send` remains blocked unless a future explicit confirm path is implemented.

MVP can stop after draft creation and provide an action to open Gmail. A later implementation can add a confirmed `gmail.draft.send` style action if the repo has a safe provider path for it.

## Frontend Behavior

MVP should reuse existing A2UI surfaces:

- YouTube results render as `GenericToolResults`.
- Gmail draft renders as `Gmail Draft Preview`.
- The latest tool surface remains visible.
- The assistant transcript should not claim the full task is complete until the final tool state proves it.

Optional later UI:

- A small task progress strip showing steps like `YouTube search`, `Gmail draft`, `Awaiting send confirmation`.

Do not build a workflow timeline component in the first implementation.

## YouTube Hotness Gap

Current YouTube search uses the Search API with snippets. It does not prove "most popular" by views.

For the World Cup scenario, the correct minimal improvement is:

- pass search args that request YouTube-only results,
- support an `order` value such as `viewCount` where the YouTube Search API allows it,
- optionally follow with `videos.list` statistics only if view counts must be displayed or sorted locally.

Do not fake popularity labels. If the API lacks a key or returns an error, show the real error.

## Implementation Scope

Likely files:

- `agent_core/src/main/ets/agent/ReActAgentRunner.ets`
- a new small digest helper near A2UI parsing/runtime code, or inside the runner if the smallest clean diff is there
- `entry/src/test/ReActAgentRunner.test.ets`
- targeted tests for YouTube URL/order behavior only if the YouTube search args are changed

Avoid touching:

- payment provider logic
- Gmail OAuth setup
- persona memory
- dynamic MCP registration
- broad frontend redesign

## Testing

Add the smallest tests that fail if the loop regresses:

1. Runner continues after an A2UI observation when the task is incomplete.
2. Runner can perform two tools before final: a read tool followed by a draft tool.
3. Runner stops on `confirm_required` or `blocked` observation.
4. Repeated same-tool error stops instead of looping.
5. Digest omits raw JSONL but preserves useful rows such as `Watch URL` and `Draft ID`.

Existing wider smoke can later add:

```text
帮我在 YouTube 上搜索五个最火的世界杯视频，并给 xxx@example.com 创建一封 Gmail 草稿
```

Expected visible path:

- `youtube.video.search`
- YouTube Data API results or real credential/API error
- `gmail.draft.create` only when video results are available
- Gmail draft preview
- no automatic send claim

## Non-Goals

- No workflow DSL.
- No per-domain hardcoded YouTube-to-Gmail tool.
- No hidden fallback video or email data.
- No automatic direct email send.
- No broad A2UI visual redesign.

## Self-Review

- No placeholders remain.
- Scope is one implementation plan: bounded ReAct continuation through observation digests.
- Safety boundary is explicit: draft is allowed, send requires user confirmation.
- The "most popular" requirement is not overclaimed; API-backed sorting is required before displaying popularity.
