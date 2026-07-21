# Agent Core Single-Runtime Convergence Design

Date: 2026-07-21

Status: Approved for planning

Repositories:

- `/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo`
- `/Users/luoyige/DevEcoStudioProjects/loopy`

Pull requests:

- Appless `XiaoLuoLYG/Appless-Phone#67`
- Loopy `Raym0ndKwan/loopy#11`

## 1. Problem

The two feature branches currently contain byte-identical `agent_core` source trees, but the shared tree exposes two competing orchestration families:

- the structured `LeaderAgent / DataAgent / UiAgent / ActionAgent / LinkedMessageBus` runtime;
- Loopy's older `ReactLeaderAgent / UIMakerAgent / ReactLinkedMessageBus` runtime.

The product wiring is also split. Appless sends hotel queries through the structured four-agent runtime while other scenes still call `LoopBackend/ReActAgentRunner` directly. Loopy still starts the older Leader/UIMaker pair. The hotel `UiAgent` coordinates surface state correctly but delegates to a deterministic `HotelUiRenderer`, so it does not yet perform constrained layout planning.

The first phase must establish one public agent architecture before more Appless scenes migrate.

## 2. Goals

1. Make the structured four-agent runtime the only public agent orchestration in both shared-core copies.
2. Remove the older Loopy Leader/UIMaker/message-bus implementation instead of preserving compatibility wrappers.
3. Give tools, skills, UI placement, and action execution one explicit owner.
4. Upgrade the structured runtime contracts so Loopy does not converge on known-incomplete boundaries.
5. Preserve `HotelUiRenderer` as the canonical hotel data-model renderer, default layout, and deterministic fallback.
6. Keep `ReActAgentRunner` only for real, not-yet-migrated Appless callers.
7. Keep the two controlled `agent_core` trees path- and byte-identical.
8. Update the existing Draft PRs; do not create duplicate PRs.
9. Create `Raym0ndKwan/loopy:agent-core-convergence` from the latest `hos` and retarget Loopy PR #11 to it.

## 3. Non-goals

- Migrating every non-hotel Appless scene in this phase.
- Removing `LoopBackend/ReActAgentRunner` while current product callers still depend on it.
- Preserving the old Loopy generic assistant demo.
- Adding compatibility aliases for the removed runtime.
- Generating ArkTS, JavaScript, HTML, arbitrary components, or arbitrary action arguments.
- Adding fake MCP/API data or a fake Loopy provider demo.
- Implementing hotel booking, order creation, order status, cancellation, or payment.

## 4. Canonical Ownership

### 4.1 Capability authority

`ToolDefinitionRegistry` remains the single authority for tool identity, schemas, risk, backend, and registered actions. `ToolRegistry` may remain as an ephemeral execution map used by the legacy `ReActAgentRunner`, but it is not a second capability authority.

### 4.2 Leader Agent

Inputs:

- correlated user input;
- read-only `ToolDefinition` metadata;
- the runtime `SkillCatalog`;
- conversation context.

Outputs:

- selected `skillId` when a skill applies;
- one correlated `DataTask` and `UiTask` for the current vertical slice;
- an optional declarative action-plan draft when a real workflow is required.

The Leader never invokes Provider tools or system actions. Capability and skill inputs are held by the injected `LeaderPlanner`; the message-driven `LeaderAgent` remains responsible for correlation, fan-out, cancellation, timeout, and terminal bookkeeping.

`LeaderPlan.skillId` is an explicit audit field. The Leader copies it into the correlated Data/UI task payloads, but downstream agents do not reload or independently select a skill. An empty value means no skill was selected.

An action-plan draft contains only identity, label, registered steps, arguments, and prior-output bindings. It does not contain a surface ID. The Action Agent binds it to the correlated UI surface after receiving the matching UI result.

The Leader publishes the draft with the current turn and UI task identity. The Action Agent stores it without executing it, observes the matching `TASK_RESULT_UI`, binds the returned `surfaceId`, validates all steps, and only then publishes `ACTION_PLAN_READY`. A draft with a wrong task, canceled turn, invalid step, or missing surface never becomes a button.

### 4.3 Data Agent

Inputs:

- exact registered `toolId`;
- validated structured arguments;
- expected output schema.

Execution:

- only read/data MCP, API, and deterministic local retrieval executors;
- no write action, client action, or system intent;
- fail closed when the capability, risk/backend class, arguments, or output schema is invalid.

Output:

- one structured `DataResult` preserving provider sources, warnings, status, and real IDs.

The hotel implementation continues to call the existing structured hotel provider path. `ReActAgentRunner` is not injected into `DataAgent` during this phase.

### 4.4 Action subsystem and ActionOffer

The Action subsystem owns executable affordances. After the matching `DataResult`, it resolves immutable `ActionOffer` objects through registered action definitions and current data:

```text
ActionOffer {
  offerId
  actionId
  label
  variant
  args
}
```

The exact `actionId` and `args` are cloned and protected before UI planning. The UI can reference an `offerId` and choose placement/order/primary-secondary presentation, but cannot create or mutate executable identity or arguments.

The Action Agent publishes a correlated `ACTION_OFFERS_READY` message, including an empty list when no action is valid. It may listen to `TASK_RESULT_DATA` only to resolve offers; it still executes actions solely from `ACTION_RUN` or validated action plans.

For hotel data:

- detail is offered only with a real positive `hotelId` and valid search context;
- navigation is offered only with bounded real coordinates;
- call is offered only with verified phone/provider/place ID;
- no hotel booking offer exists.

### 4.5 UI Agent

The existing UI Agent keeps its valuable runtime responsibilities:

- direct bus subscription;
- exact conversation/turn/task correlation;
- data-first and UI-first ordering;
- surface identity;
- per-surface serialized writes;
- cancellation, generation fencing, and write leases;
- skeleton/result/error/action state transitions.

For a final result, it waits for both the matching `DataResult` and `ACTION_OFFERS_READY`. An offer-resolution failure degrades to an empty offer list and still renders factual data.

The renderer input becomes:

- `CreateUiTaskPayload`;
- `DataResult`;
- immutable `ActionOffer[]`;
- `surfaceId`.

The renderer output contains A2UI JSONL only. Action plans no longer originate from renderer proposals.

### 4.6 Action Agent

The existing `ActionCatalog`, `ActionPlanRunner`, JSON Pointer binding, confirmation gate, idempotency, and `RegisteredActionExecutor` remain the execution authority.

The Action Agent:

- validates offers before publication;
- validates direct actions again immediately before execution;
- validates every action-plan step after bindings are resolved;
- binds Leader action-plan drafts only to the matching surface;
- executes no generated code;
- stops a serial plan on missing binding, rejection, cancellation, error, or timeout.

## 5. Skills

Skills are loaded once into an immutable runtime snapshot. They are not independently registered on four agents.

- Leader scans the `SkillCatalog` and selects at most one applicable skill for the turn.
- The selected skill instructions constrain the Leader plan.
- Data receives only the exact validated task produced by that plan.
- UI receives only UI intent, real data, and immutable offers.
- Action receives only registered actions or plans.

Existing Appless persona skill text remains supported during phase one. Consolidating persona skills with `SkillSnapshot` for all non-hotel scenes belongs to phase two.

## 6. ReActAgentRunner Policy

`ReActAgentRunner` is not shared among the four agents and is not another public runtime.

It remains because current non-hotel Appless callers still instantiate it through `LoopBackend`. The following remain while those callers exist:

- `ReActAgentRunner`;
- `ToolRegistry`;
- required `AgentEvent`, `TimeTool`, `UiTool`, and skill-support classes.

Every migrated scene must remove a real caller. When no production caller remains, the runner and its private execution support can be reconsidered or deleted. No adapter will wrap it to make legacy execution look like four-agent execution.

## 7. Constrained Hotel UI Composition

`HotelUiRenderer` is retained and always runs first.

It remains responsible for:

- canonical hotel/rate/price/cancellation data mapping;
- stable data paths and labels;
- skeleton, empty, error, and action-status surfaces;
- a complete default component tree;
- deterministic fallback output.

The constrained UI planner receives the baseline A2UI, UI intent, component catalog, factual `DataResult`, and immutable `ActionOffer` references. It may produce only a replacement `updateComponents` layout.

The shared runtime receives a `UiLayoutPlanner` dependency; it does not construct model configuration itself. Appless supplies the existing `A2uiAgentRunner` through the same configured A2UI model path already used by the product. Missing configuration supplies no planner and therefore uses the deterministic baseline without an extra model call.

The merge keeps:

- `createSurface` from `HotelUiRenderer`;
- factual `updateDataModel` from `HotelUiRenderer`;
- the generated `updateComponents` only when every component, data reference, and offer reference validates.

The planner may choose cards/lists, reorder visible fields, group or collapse sections, and place offers. It cannot alter provider facts, raw action arguments, offer identity, data paths, or component definitions.

On missing model configuration, timeout, malformed JSONL, unknown components, invalid data references, invalid offers, or policy rejection, the existing HotelUiRenderer output is used unchanged.

## 8. Loopy Application Scope

Loopy becomes a shared-core repository in this phase, not a second product demo.

Remove the old `ChatInteractor` and Leader/UIMaker assistant wiring. Replace the app page with a small non-interactive library-status page that does not claim Provider results or generic assistant behavior.

The four-agent message flow is verified by shared automated tests, not by adding fake production tools to the Loopy app. Loopy acceptance is HAR plus entry compilation and the source verifier.

## 9. Files Removed From Shared Core

Delete the old orchestration files and their public exports/callers:

- `AgentMessageTypes.ets`
- root `MessageBus.ets`
- root `MessageDrivenAgent.ets`
- root `LeaderAgent.ets`
- `LeaderAgentPrompt.ets`
- `LeaderToolRegistry.ets`
- `CreateUiTaskTool.ets`
- `UIMakerAgent.ets`
- `UIMakerAgentPrompt.ets`
- `UIMakerToolRegistry.ets`
- `ReActAgent.ets`
- old-only identity prompts and aliases after a caller scan proves they are unused

Retained files are determined by real callers, not by original ownership. In particular, `ReActAgentRunner`, `ToolRegistry`, skill classes, `TimeTool`, and `UiTool` remain if the Appless build still imports them.

## 10. Error and Concurrency Rules

- Every bus message keeps `conversationId`, `turnId`, and `taskId` correlation.
- UI renders final data only after matching data and offer messages.
- Wrong-task, wrong-surface, late, canceled, or duplicate messages are ignored.
- Offer resolution errors remove actions but do not hide factual data.
- UI planner failures return the deterministic baseline.
- Data errors create a factual error surface and no offers.
- Action validation is repeated immediately before invocation.
- No action or workflow is retried after a terminal identity.

## 11. Validation

### Shared runtime

- Leader receives capability/skill context but cannot execute tools.
- Data rejects unregistered/write/system capabilities.
- ActionOffer identity and args cannot be modified by UI output.
- UI handles data/offer arrival in either order.
- UI planner valid layout is merged with baseline facts.
- malformed, unauthorized, timed-out, or unavailable planner falls back exactly to baseline.
- action plans bind to only the matching surface and preserve serial JSON Pointer behavior.
- old Loopy runtime files, imports, names, and aliases are absent.

### Appless

- authoritative Hypium result has zero failures and errors;
- hotel search/detail real-data contracts remain intact;
- navigation/call conditional placement remains fail closed;
- existing non-hotel baseline tests remain green;
- backend verifier and capability audit pass.

### Loopy

- backend verifier asserts the single structured runtime;
- `agent_core.har` builds;
- entry ArkTS compilation succeeds;
- no old generic assistant claims or old Runtime imports remain.

### Cross-repository

- controlled tracked path sets match;
- SHA-256 content differences are zero;
- no secrets, signing material, generated build output, smoke artifacts, or process documents remain in the final product diff.

## 12. Git and Pull Request Delivery

1. Re-fetch both repositories before implementation and before publishing.
2. Protect any unrelated local changes; do not stage them.
3. Implement on the existing Appless and Loopy PR branches.
4. Keep shared core synchronized by controlled file copy/patch and hash verification, not blind directory replacement.
5. Create upstream `Raym0ndKwan/loopy:agent-core-convergence` from the then-current `origin/hos` only after verification.
6. Push the existing fork head branch and retarget Draft PR #11 from `hos` to `agent-core-convergence`.
7. Update the PR title/body to describe the single-runtime library convergence and validation.
8. Push the corresponding Appless PR #67 head; its base remains `main`.
9. Do not create duplicate PRs.
10. Remove this Superpowers design/plan material from the final product PR diff after implementation evidence is complete.

## 13. Phase-Two Boundary

Phase two migrates Appless scene families from host routing and `LoopBackend` into the canonical four-agent path. It will move tool execution to Data/Action, UI composition to UiAgent, and skill selection to Leader. Only after the last real caller is gone may the direct LoopBackend route and ReAct runner be removed.
