# Structured Four-Agent Contract and Hotel UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Every task follows superpowers:test-driven-development and every completion claim follows superpowers:verification-before-completion.

**Goal:** Make Leader, Data, UI, and Action the single coherent structured runtime contract, move executable affordance ownership out of the UI renderer, and add constrained model-assisted hotel layout while preserving the current deterministic `HotelUiRenderer` as the factual baseline and fallback.

**Architecture:** The Leader receives immutable tool/skill metadata and emits correlated Data/UI tasks plus an optional surface-free action-plan draft. Data authorizes and executes only registered read capabilities. Action derives immutable offers from real data, binds workflow drafts to the matching final UI surface, and remains the only execution authority. UI joins the exact DataResult with the exact offer message, then renders baseline A2UI; an optional A2UI planner may replace only a validated `updateComponents` envelope.

The runtime roles are explicitly Leader Agent, Data Agent, UI Agent, and Action Agent; none delegates its ownership boundary to `ReActAgentRunner`.

**Tech Stack:** HarmonyOS ArkTS, Hypium, existing `LinkedMessageBus`, `ToolDefinitionRegistry`, `SkillSnapshot`, `ActionCatalog`, `ActionPlanRunner`, `A2uiAgentRunner`, A2UI JSONL, RollingGo and Google Places provider adapters.

## Global Constraints

- Keep `ReActAgentRunner` and `ToolRegistry` only for real non-hotel `LoopBackend` callers; do not inject either into the four agents.
- Do not add a second tool registry, action registry, skill registry, coordinator, workflow language, code generation path, or compatibility wrapper.
- `ToolDefinitionRegistry` is the capability authority. The hotel-specific authorizer may only project and validate its definitions.
- Do not fabricate provider data, hotel phone numbers, coordinates, booking actions, order state, or transaction results.
- Planner failure must return the byte-for-byte deterministic baseline JSONL.
- Use `apply_patch` for edits. Do not stage unrelated concurrent changes.
- Run Hypium through the existing project command and read `entry/.test/default/intermediates/test/coverage_data/test_result.txt`; a successful process exit alone is not evidence.

---

## Task 1: Define the canonical planning, offer, and message contracts

**Files:**

- Create: `agent_core/src/main/ets/agent/action/ActionOfferTypes.ets`
- Modify: `agent_core/src/main/ets/agent/action/ActionPlanTypes.ets`
- Modify: `agent_core/src/main/ets/agent/leader/LeaderTypes.ets`
- Modify: `agent_core/src/main/ets/agent/data/DataAgentTypes.ets`
- Modify: `agent_core/src/main/ets/agent/ui/UiAgentTypes.ets`
- Modify: `agent_core/src/main/ets/agent/action/ActionAgentTypes.ets`
- Modify: `agent_core/src/main/ets/agent/message/AgentMessage.ets`
- Modify: `agent_core/Index.ets`
- Test: `entry/src/test/AgentMessage.test.ets`
- Test: `entry/src/test/LeaderAgent.test.ets`
- Test: `entry/src/test/DataAgent.test.ets`
- Test: `entry/src/test/UiAgent.test.ets`

- [ ] **Step 1: Write failing contract tests**

Add tests that require the following exact shapes and message values:

```ts
export interface LeaderToolMetadata {
  toolId: string;
  intent: string;
  riskLevel: ToolRiskLevel;
  inputSchema: string;
  outputSchema: string;
  actions: string[];
}

export interface LeaderSkillMetadata {
  skillId: string;
  description: string;
  instructions: string;
}

export interface LeaderPlanningContext {
  tools: LeaderToolMetadata[];
  skills: LeaderSkillMetadata[];
}

export interface ActionPlanDraft {
  planId: string;
  runId: string;
  label: string;
  steps: ActionPlanStep[];
}

export interface LeaderPlan {
  skillId: string;
  ui: LeaderUiTask;
  data: LeaderDataTask;
  actionPlan?: ActionPlanDraft;
}
```

Require `CreateDataTaskPayload` and `CreateUiTaskPayload` to contain the copied `skillId`. Require renderer results to contain only JSONL:

```ts
export interface UiRenderResult {
  jsonl: string;
}

export interface UiTaskRenderer {
  skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult>;
  result(
    task: CreateUiTaskPayload,
    data: DataResult,
    offers: ActionOffer[],
    surfaceId: string
  ): Promise<UiRenderResult>;
  error(task: CreateUiTaskPayload, message: string, surfaceId: string): Promise<UiRenderResult>;
  actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult>;
}
```

Require these new message values and remove test expectations for `ACTION.PLAN.CREATE`:

```ts
ACTION_PLAN_DRAFT = 'ACTION.PLAN.DRAFT'
ACTION_OFFERS_READY = 'ACTION.OFFERS.READY'
```

- [ ] **Step 2: Run the focused tests and confirm RED**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default -p buildMode=test test --no-daemon
```

Expected: ArkTS compilation fails on the missing types, enum members, `skillId`, and new renderer signature. Record only those expected failures.

- [ ] **Step 3: Add the minimal immutable offer types**

Implement `ActionOfferTypes.ets`:

```ts
export interface ActionOffer {
  offerId: string;
  actionId: string;
  label: string;
  variant: string;
  args: Object;
}

export interface ActionOfferContext {
  conversationId: string;
  turnId: string;
  dataTaskId: string;
}

export interface ActionOfferResolver {
  resolve(data: DataResult, context: ActionOfferContext): Promise<ActionOffer[]>;
}

export interface ActionOffersReadyPayload {
  dataTaskId: string;
  sourceToolId: string;
  offers: ActionOffer[];
}
```

Add `ActionPlanDraftPayload` to `ActionAgentTypes.ets`:

```ts
export interface ActionPlanDraftPayload {
  uiTaskId: string;
  dataTaskId: string;
  sourceToolId: string;
  draft: ActionPlanDraft;
}
```

Define `ActionPlanDraft` beside `ActionPlan` in `ActionPlanTypes.ets`; `LeaderTypes` imports it. This avoids a Leader-to-Action-to-Leader type cycle.

Do not put `surfaceId` in the draft.

- [ ] **Step 4: Update the public exports and compile the contract**

Export the new types from `agent_core/Index.ets`. Do not add aliases. Update test fakes so every plan and task explicitly carries `skillId: ''` when no skill applies.

- [ ] **Step 5: Run the focused suite and confirm GREEN**

Run the same Hypium command. Then read:

```bash
sed -n '1,120p' entry/.test/default/intermediates/test/coverage_data/test_result.txt
```

Expected: the suite compiles and current behavior tests pass after mechanical fixture updates.

- [ ] **Step 6: Commit the contract**

```bash
git add agent_core/Index.ets \
  agent_core/src/main/ets/agent/action/ActionOfferTypes.ets \
  agent_core/src/main/ets/agent/action/ActionAgentTypes.ets \
  agent_core/src/main/ets/agent/action/ActionPlanTypes.ets \
  agent_core/src/main/ets/agent/data/DataAgentTypes.ets \
  agent_core/src/main/ets/agent/leader/LeaderTypes.ets \
  agent_core/src/main/ets/agent/message/AgentMessage.ets \
  agent_core/src/main/ets/agent/ui/UiAgentTypes.ets \
  entry/src/test/AgentMessage.test.ets \
  entry/src/test/LeaderAgent.test.ets \
  entry/src/test/DataAgent.test.ets \
  entry/src/test/UiAgent.test.ets
git commit -m "refactor: define structured agent ownership contracts"
```

---

## Task 2: Give Leader immutable capability and skill context

**Files:**

- Modify: `agent_core/src/main/ets/agent/leader/LeaderTypes.ets`
- Modify: `agent_core/src/main/ets/agent/leader/LeaderAgent.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/HotelLeaderPlanner.ets`
- Test: `entry/src/test/LeaderAgent.test.ets`
- Test: `entry/src/test/HotelLeaderPlanner.test.ets`

- [ ] **Step 1: Write failing Leader ownership tests**

Add tests proving:

1. `LeaderPlanner.plan` receives a defensive copy of `LeaderPlanningContext`.
2. A selected non-empty `skillId` must exist in the supplied skills.
3. `plan.data.toolId`, input/output schemas, and risk metadata must match an available tool definition.
4. Leader publishes UI and Data tasks with the same selected `skillId`.
5. Leader publishes `ACTION_PLAN_DRAFT` only after publishing the paired UI/Data tasks.
6. The draft payload contains the paired `uiTaskId` and `dataTaskId`, but no surface ID.
7. Leader never receives an executor dependency and never emits `ACTION_RUN`.

Use a planning context with one real read capability and one skill:

```ts
const context: LeaderPlanningContext = {
  tools: [{
    toolId: 'hotel.search',
    intent: 'hotel.search',
    riskLevel: 'read',
    inputSchema: 'hotelSearchRequest',
    outputSchema: 'hotelSearchResults',
    actions: ['hotel.detail', 'hotel.navigate', 'hotel.call']
  }],
  skills: [{
    skillId: 'hotel-search',
    description: 'Search real hotel inventory.',
    instructions: 'Use hotel.search and do not claim booking.'
  }]
};
```

- [ ] **Step 2: Run Hypium and confirm RED**

Expected: failures show `LeaderAgent` does not pass planning context, does not validate skill/tool selection, and does not publish drafts.

- [ ] **Step 3: Change the planner and agent signatures**

Use this contract:

```ts
export interface LeaderPlanner {
  plan(
    message: AgentMessage,
    input: InputUserPayload,
    context: LeaderPlanningContext
  ): Promise<LeaderPlan>;
}
```

Construct `LeaderAgent` with a static context snapshot:

```ts
constructor(
  bus: LinkedMessageBus,
  planner: LeaderPlanner,
  planningContext: LeaderPlanningContext,
  timeoutMs: number = 30000
)
```

Clone the whitelisted tool and skill fields in the constructor and again before passing them to the planner. Do not pass `ToolDefinitionRegistry`, `SkillSnapshot`, executors, provider clients, or mutable source objects into the planner.

- [ ] **Step 4: Validate and fan out the plan**

Extend `validPlan` so it fails closed when:

- `skillId` is non-empty and absent from context;
- the Data tool is absent;
- the selected tool is not `read`;
- task schemas do not match the selected definition;
- action-plan identity/label/steps are malformed;
- task IDs or draft IDs collide.

Publish a sanitized draft with the current correlation:

```ts
this.bus.publish({
  type: AgentMessageType.ACTION_PLAN_DRAFT,
  conversationId: input.conversationId,
  turnId: input.turnId,
  taskId: `action-draft:${plan.actionPlan.runId}`,
  payload: {
    uiTaskId: plan.ui.taskId,
    dataTaskId: plan.data.taskId,
    sourceToolId: plan.data.toolId,
    draft: cloneLeaderActionPlanDraft(plan.actionPlan)
  }
});
```

- [ ] **Step 5: Update `HotelLeaderPlanner`**

Make the hotel planner accept the context, select `skillId: ''` for phase one, and verify `hotel.search` is present before calling the model. Its returned plan remains search-only and contains no booking workflow:

```ts
return {
  skillId: '',
  ui: {
    taskId: uiTaskId,
    intent: 'hotel.search',
    expectedOutputSchema: definition.outputSchema
  },
  data: {
    taskId: dataTaskId,
    toolId: definition.toolId,
    outputSchema: definition.outputSchema,
    args: request
  }
};
```

- [ ] **Step 6: Run focused and full tests, then commit**

Read the authoritative result file and require zero failures/errors.

```bash
git add agent_core/src/main/ets/agent/leader/LeaderTypes.ets \
  agent_core/src/main/ets/agent/leader/LeaderAgent.ets \
  entry/src/main/ets/pages/A2uiHome/agent/HotelLeaderPlanner.ets \
  entry/src/test/LeaderAgent.test.ets \
  entry/src/test/HotelLeaderPlanner.test.ets
git commit -m "refactor: make leader plan from capability context"
```

---

## Task 3: Make Data Agent fail closed on non-read capabilities

**Files:**

- Modify: `agent_core/src/main/ets/agent/data/DataAgentTypes.ets`
- Modify: `agent_core/src/main/ets/agent/data/DataAgent.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/HotelAgentRuntime.ets`
- Test: `entry/src/test/DataAgent.test.ets`
- Test: `entry/src/test/HotelAgentRuntime.test.ets`

- [ ] **Step 1: Write failing authorization tests**

Cover the following before any executor call:

- unregistered `toolId` is rejected;
- `draft`, `confirm_required`, `blocked`, and `system_intent` capabilities are rejected;
- mismatched input/output schema is rejected;
- invalid hotel search/detail args are rejected;
- valid `hotel.search` and `hotel.detail` execute exactly once;
- executor output with a different `toolId` or `outputSchema` is rejected;
- cancel-before-execute calls neither authorizer nor executor;
- cancel-during-execute suppresses late result publication.

- [ ] **Step 2: Run Hypium and confirm RED**

Expected: current `DataAgent` calls any injected executor for any syntactically shaped task.

- [ ] **Step 3: Add an explicit authorizer contract**

```ts
export interface DataTaskAuthorizationResult {
  ok: boolean;
  code: string;
  message: string;
}

export interface DataTaskAuthorizer {
  authorize(task: CreateDataTaskPayload): DataTaskAuthorizationResult;
}
```

Change the constructor to require it:

```ts
constructor(
  bus: LinkedMessageBus,
  authorizer: DataTaskAuthorizer,
  executor: DataTaskExecutor
)
```

There is no allow-all default.

- [ ] **Step 4: Implement the hotel projection from the real registry**

In `HotelAgentRuntime.ets`, add `RegisteredHotelDataAuthorizer`. It must call `toolDefinitionForToolId(task.toolId)`, require `riskLevel === 'read'`, require every selected backend to belong to the explicit data-backend set (`local_adapter`, `oauth_api`, `imap`, `workspace_mcp`, `web_session`, `mcp_remote`), reject `system_intent`, compare schemas, and validate args with `parseHotelSearchRequest` or `parseHotelDetailRequest`.

Do not copy tool definitions into a second array.

- [ ] **Step 5: Validate the returned `DataResult` in Data Agent**

Before publication require:

```ts
result.toolId === task.toolId &&
result.outputSchema === task.outputSchema &&
Array.isArray(result.sources) &&
Array.isArray(result.warnings)
```

Publish `DATA_TASK_OUTPUT_INVALID` on failure and never pass malformed output to UI or Action.

- [ ] **Step 6: Run tests and commit**

```bash
git add agent_core/src/main/ets/agent/data/DataAgentTypes.ets \
  agent_core/src/main/ets/agent/data/DataAgent.ets \
  entry/src/main/ets/pages/A2uiHome/agent/HotelAgentRuntime.ets \
  entry/src/test/DataAgent.test.ets \
  entry/src/test/HotelAgentRuntime.test.ets
git commit -m "refactor: restrict data agent to registered reads"
```

---

## Task 4: Move ActionOffer and workflow-draft ownership into Action Agent

**Files:**

- Modify: `agent_core/src/main/ets/agent/action/ActionAgentTypes.ets`
- Modify: `agent_core/src/main/ets/agent/action/ActionAgent.ets`
- Modify: `agent_core/src/main/ets/agent/message/AgentMessage.ets`
- Modify: `agent_core/src/main/ets/agent/action/ActionCatalog.ets`
- Modify: `entry/src/test/ActionAgent.test.ets`
- Modify: `entry/src/test/ActionCatalog.test.ets`

- [ ] **Step 1: Write failing offer tests**

Add tests proving that after a matching `TASK_RESULT_DATA`:

- Action Agent first observed the exact `TASK_CREATE_DATA` from Leader and stored only its whitelisted identity/schema;
- Action Agent calls the resolver once and publishes one `ACTION_OFFERS_READY`;
- every offer is deep-cloned before publication;
- duplicate `offerId` or invalid/undeclared `actionId` is removed;
- a resolver exception publishes an empty offer list rather than a task failure;
- a data error publishes an empty offer list;
- wrong, canceled, duplicate, or late data does not publish or revive offers;
- offer resolution never calls `RegisteredActionExecutor`.

- [ ] **Step 2: Write failing draft-binding tests**

Replace UI-created-plan tests with Leader-draft tests:

- draft arrives before UI result and remains pending;
- only `TASK_RESULT_UI` with exact conversation, turn, `uiTaskId`, and `state: 'result'` binds it;
- the bound plan receives the returned `surfaceId` and current `turnId`;
- a wrong task, skeleton-only result, canceled turn, invalid step, or duplicate identity never publishes READY;
- READY includes `uiTaskId` so UI can correlate it;
- existing five-step limit, JSON Pointer bindings, confirmations, idempotency, and direct action execution tests remain.

- [ ] **Step 3: Run Hypium and confirm RED**

Expected: current Action Agent ignores Data/UI results and accepts a surface-bearing plan from UI.

- [ ] **Step 4: Add offer resolution to Action Agent**

Inject the resolver:

```ts
constructor(
  bus: LinkedMessageBus,
  catalog: ActionCatalog,
  offerResolver: ActionOfferResolver,
  executor: RegisteredActionExecutor
)
```

Accept only:

```ts
ACTION_PLAN_DRAFT
TASK_CREATE_DATA
TASK_RESULT_UI
TASK_RESULT_DATA
TASK_ERROR
ACTION_RUN
TURN_CANCEL
```

Validate each resolved offer using `catalog.validatePlacement(data.toolId, offer.actionId, offer.args)`. Reconstruct the published object from whitelisted fields and clone `args`; never publish resolver-owned objects.

Track a bounded set of exact Leader-created Data task identities. A `TASK_RESULT_DATA` or `TASK_ERROR` that does not match a previously observed task must not resolve or publish offers. Clear tracked identities on completion, cancellation, stop, and terminal errors.

- [ ] **Step 5: Store and bind surface-free drafts**

Store pending drafts under the complete correlation key. On a matching final UI result, build the existing runner input:

```ts
const plan: ActionPlan = {
  planId: draft.planId,
  turnId: message.turnId,
  surfaceId: uiResult.surfaceId,
  label: draft.label,
  steps: cloneSteps(draft.steps)
};
```

Run the current `ActionPlanRunner.validate`, store the run, and publish the existing workflow action only after validation. Delete the old `ACTION_PLAN_CREATE` parser and state path rather than supporting both.

- [ ] **Step 6: Keep execution-time validation unchanged and explicit**

Direct execution still uses `validateSurfaceExecution`. Each workflow step still uses `validateRegisteredStep` after JSON Pointer binding. Do not weaken the confirmation, idempotency, capacity, cancel, or follow-up rules.

- [ ] **Step 7: Run tests and commit**

```bash
git add agent_core/src/main/ets/agent/action/ActionAgentTypes.ets \
  agent_core/src/main/ets/agent/action/ActionAgent.ets \
  agent_core/src/main/ets/agent/action/ActionCatalog.ets \
  agent_core/src/main/ets/agent/message/AgentMessage.ets \
  entry/src/test/ActionAgent.test.ets \
  entry/src/test/ActionCatalog.test.ets
git commit -m "refactor: make action agent own offers and workflows"
```

---

## Task 5: Make UI join DataResult and immutable offers

**Files:**

- Modify: `agent_core/src/main/ets/agent/ui/UiAgentTypes.ets`
- Modify: `agent_core/src/main/ets/agent/ui/UiAgent.ets`
- Modify: `entry/src/test/UiAgent.test.ets`

- [ ] **Step 1: Replace proposal tests with offer-join tests**

Delete test fixtures that let a renderer return `proposals`. Add tests for:

- data then offers;
- offers then data;
- UI task last after both are pending;
- exact `dataTaskId` ownership;
- duplicate and wrong-task messages;
- offer-resolution error represented as an empty list;
- final result not rendered until both messages exist;
- cancellation or surface replacement suppresses a deferred renderer/write;
- renderer mutations to its received offer array do not alter stored authority;
- renderer JSONL containing an action not exactly present in offers is rejected.

- [ ] **Step 2: Run Hypium and confirm RED**

Expected: current UI renders immediately after DataResult and publishes renderer proposals.

- [ ] **Step 3: Replace pending plan state with pending offer state**

Add one bounded pending entry keyed by exact Data task ownership:

```ts
interface PendingOfferEntry {
  sourceToolId: string;
  offers: ActionOffer[];
}
```

Remove `PENDING_PLAN_LIMIT`, `pendingPlans`, `actionRunSuffix`, `publishActionPlans`, and every `ACTION_PLAN_CREATE` publication.

- [ ] **Step 4: Join and render once**

Only call:

```ts
renderer.result(task, cloneDataResult(data), cloneActionOffers(offers), surfaceId)
```

after skeleton, matching data, and matching offers exist. Clear all pending Data/offer payloads after the terminal render. Treat a malformed offer payload as empty offers and publish a bounded UI diagnostic without discarding valid data.

- [ ] **Step 5: Keep workflow READY as an Action-originated status**

Require `ActionPlanReadyPayload.uiTaskId === context.uiTaskId` and exact surface correlation before calling `renderer.actionStatus`. UI does not reconstruct plan steps or args.

- [ ] **Step 6: Run tests and commit**

```bash
git add agent_core/src/main/ets/agent/ui/UiAgentTypes.ets \
  agent_core/src/main/ets/agent/ui/UiAgent.ets \
  entry/src/test/UiAgent.test.ets
git commit -m "refactor: join UI data with action offers"
```

---

## Task 6: Derive hotel offers from real data and remove UI argument construction

**Files:**

- Modify: `agent_core/src/main/ets/aiphone/runtime/HotelActions.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/HotelToolA2ui.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/HotelAgentRuntime.ets`
- Test: `entry/src/test/HotelToolA2ui.test.ets`
- Test: `entry/src/test/HotelAgentRuntime.test.ets`
- Test: `entry/src/test/HotelRegisteredActionExecutor.test.ets`

- [ ] **Step 1: Write failing hotel offer tests**

Require the Action-side resolver to produce:

- detail only for a positive real `hotelId` and valid search query;
- navigation only for bounded real coordinates;
- call only for verified `displayPhone`, `dialPhone`, provider, and place ID;
- no `hotel.book`, `hotel.create`, `hotel.status`, or `hotel.cancel` offer;
- stable unique `offerId` values per hotel/action;
- exact original hotel/provider IDs and arguments;
- empty offers for error/empty detail data.

Require `hotelSearchA2ui` to accept `ActionOffer[]` instead of a placement callback, and prove it never calls `hotelDetailAction`, `hotelNavigateAction`, or `hotelCallAction` to reconstruct args.

- [ ] **Step 2: Run Hypium and confirm RED**

Expected: current `HotelUiRenderer` creates actions through `hotelActionsFor` and returns no Action Agent offers.

- [ ] **Step 3: Implement `HotelActionOfferResolver` in the hotel runtime**

Use existing `hotelActionsFor` and current `ActionCatalog` only inside the Action subsystem adapter. Convert approved `A2uiAction` values to offers by whitelisting fields and cloning args:

```ts
return {
  offerId: `hotel:${hotel.hotelId}:${action.id}`,
  actionId: action.id,
  label: action.label,
  variant: action.variant,
  args: cloneActionArgs(action.args as Object)
};
```

The resolver must not call provider APIs or the registered executor.

- [ ] **Step 4: Make hotel A2UI consume offers**

Change the public function to:

```ts
export function hotelSearchA2ui(
  surfaceId: string,
  result: HotelSearchResult,
  offers: ActionOffer[],
  warnings: string[] = []
): string
```

For each hotel, select offers whose immutable `args.hotelId` exactly equals the result hotel ID. Materialize the A2UI action by copying `actionId`, label, variant, and the already-authorized args. Do not infer, normalize, or repair args in UI code.

- [ ] **Step 5: Wire all four agents with explicit dependencies**

Build one immutable `LeaderPlanningContext` from `toolDefinitionForToolId('hotel.search')` and an empty phase-one skill list. Construct:

```ts
this.leader = new LeaderAgent(this.bus, planner, planningContext);
this.data = new DataAgent(this.bus, dataAuthorizer, executor);
this.ui = new UiAgent(this.bus, renderer, this.surfaceWriter);
this.action = new ActionAgent(this.bus, this.catalog, offerResolver, registered);
```

- [ ] **Step 6: Run tests and commit**

```bash
git add agent_core/src/main/ets/aiphone/runtime/HotelActions.ets \
  agent_core/src/main/ets/aiphone/runtime/HotelToolA2ui.ets \
  entry/src/main/ets/pages/A2uiHome/agent/HotelAgentRuntime.ets \
  entry/src/test/HotelToolA2ui.test.ets \
  entry/src/test/HotelAgentRuntime.test.ets \
  entry/src/test/HotelRegisteredActionExecutor.test.ets
git commit -m "refactor: derive hotel actions as immutable offers"
```

---

## Task 7: Add constrained model-assisted hotel layout with exact fallback

**Files:**

- Create: `agent_core/src/main/ets/a2ui/A2uiLayoutMerger.ets`
- Modify: `agent_core/src/main/ets/a2ui/A2uiAgentRunner.ets`
- Modify: `agent_core/src/main/ets/a2ui/OpenAiA2uiModel.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/A2uiComponentCatalogConst.ets`
- Modify: `agent_core/Index.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/HotelAgentRuntime.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/Index.ets`
- Create: `entry/src/test/A2uiLayoutMerger.test.ets`
- Modify: `entry/src/test/HotelAgentRuntime.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: Write failing merge-policy tests**

Build a deterministic baseline containing `createSurface`, `updateComponents`, and factual `updateDataModel`. Test:

- a valid candidate replaces only `updateComponents`;
- baseline `createSurface` and all `updateDataModel` lines are unchanged and preserve order;
- candidate surface ID must match;
- component names must exist in `AIPHONE_COMPONENT_CATALOG_JSON`;
- child IDs must exist, form one connected tree, and contain no cycle;
- `dataPath` must be the exact baseline data path or a descendant;
- candidate action slots may contain only `{ "offerId": "..." }`;
- offer references are replaced with exact immutable A2UI actions;
- unknown/duplicate offers, unknown fields, literal action args, malformed JSONL, extra create/data/delete envelopes, or more than the bounded component count return the exact baseline string.

- [ ] **Step 2: Run Hypium and confirm RED**

Expected: `A2uiLayoutMerger` and fixed-surface runner entry do not exist.

- [ ] **Step 3: Add a minimal fixed-surface planner interface**

Extend `A2uiAgentRunner` without changing its existing `run` callers:

```ts
export interface UiLayoutPlanner {
  plan(task: string, surfaceId: string): Promise<string | null>;
}

async plan(task: string, surfaceId: string): Promise<string | null> {
  try {
    return await this.model.generate(task, surfaceId);
  } catch (_error) {
    return null;
  }
}
```

Have `run` call the same internal generation path. This is reuse of the existing runner, not a second UI agent.

- [ ] **Step 4: Implement the merger as a pure function**

Export:

```ts
export function mergeA2uiLayout(
  baselineJsonl: string,
  candidateJsonl: string,
  surfaceId: string,
  offers: ActionOffer[]
): string
```

Return `baselineJsonl` on every rejection. Do not log raw provider data, phone numbers, coordinates, or action args.

- [ ] **Step 5: Make the A2UI model prompt match the real catalog**

Replace the obsolete `Card/Button` prompt with the product catalog and the planner-only offer-reference rule. The model must output exactly one `updateComponents` envelope; it must not output `createSurface`, `updateDataModel`, literal action IDs, or args.

Export `OpenAiA2uiModel` and `UiLayoutPlanner` through `agent_core/Index.ets`; do not add an alternate model factory or a second runner.

- [ ] **Step 6: Keep `HotelUiRenderer` first and always available**

Add an optional `UiLayoutPlanner` to the renderer. Its result flow is:

```ts
const baseline = hotelSearchA2ui(surfaceId, result, offers, warnings);
if (this.layoutPlanner === null) {
  return { jsonl: baseline };
}
const candidate = await this.layoutPlanner.plan(
  hotelLayoutPrompt(task.intent, baseline, data, offers),
  surfaceId
);
return {
  jsonl: candidate === null ? baseline :
    mergeA2uiLayout(baseline, candidate, surfaceId, offers)
};
```

Apply a bounded timeout around the planner call. Skeleton, error, empty, and action status use the renderer directly without model planning.

- [ ] **Step 7: Inject the configured A2UI runner only when an LLM is configured**

In `A2uiHome/Index.ets`, construct `A2uiAgentRunner(new OpenAiA2uiModel(provider))` only when `provider.isConfigured()` is true and pass it through `HotelAgentRuntimeOptions.uiLayoutPlanner`. Do not use `ScriptedA2uiModel` as production hotel planning evidence; missing config passes no planner and uses baseline.

- [ ] **Step 8: Add runtime fallback tests**

Test valid layout, planner throw, timeout, malformed candidate, unknown component, mutated offer, mutated data path, and missing planner. For every failure case assert exact equality with the current deterministic `hotelSearchA2ui` baseline.

- [ ] **Step 9: Run tests and commit**

```bash
git add agent_core/Index.ets \
  agent_core/src/main/ets/a2ui/A2uiAgentRunner.ets \
  agent_core/src/main/ets/a2ui/A2uiLayoutMerger.ets \
  agent_core/src/main/ets/a2ui/OpenAiA2uiModel.ets \
  agent_core/src/main/ets/aiphone/runtime/A2uiComponentCatalogConst.ets \
  entry/src/main/ets/pages/A2uiHome/Index.ets \
  entry/src/main/ets/pages/A2uiHome/agent/HotelAgentRuntime.ets \
  entry/src/test/A2uiLayoutMerger.test.ets \
  entry/src/test/HotelAgentRuntime.test.ets \
  entry/src/test/List.test.ets
git commit -m "feat: add constrained hotel UI layout planning"
```

---

## Task 8: Close the shared-runtime and Appless regression gates

**Files:**

- Modify: `scripts/verify-loopy-backend.mjs`
- Modify: `docs/current-capabilities.md` only if the live architecture statement is stale
- Test: `scripts/hotel-smoke-evidence.test.mjs`

- [ ] **Step 1: Write failing verifier assertions**

Update the verifier to prove from comment-stripped source:

- Leader plan contains `skillId`, paired Data/UI tasks, and optional draft;
- Data Agent requires `DataTaskAuthorizer` and checks result identity/schema;
- Action Agent owns `ACTION_OFFERS_READY`, draft binding, catalog validation, and executor invocation;
- UI renderer signature contains offers and no `proposals` field;
- UI waits for data plus offers;
- hotel renderer calls baseline first and the layout merger only afterward;
- `ReActAgentRunner` still has a real `LoopBackend` caller but is not imported by Leader/Data/UI/Action;
- no hotel booking lifecycle exists.

Add mutation fixtures that place forbidden strings in comments and ensure they do not satisfy the checks.

- [ ] **Step 2: Run the verifier and confirm RED**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
node scripts/verify-loopy-backend.mjs
```

- [ ] **Step 3: Implement only the required verifier/doc updates**

Do not add product code to satisfy a weak string check. Bind assertions to actual enum bodies, constructor signatures, calls, and exports.

- [ ] **Step 4: Run all local gates**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
node scripts/verify-loopy-backend.mjs

node --test scripts/hotel-smoke-evidence.test.mjs

DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default -p buildMode=test test --no-daemon

sed -n '1,160p' entry/.test/default/intermediates/test/coverage_data/test_result.txt
```

Expected: verifier PASS, hotel evidence tests PASS, and authoritative Hypium `Failure: 0` and `Error: 0`. Record coverage reporter noise separately.

- [ ] **Step 5: Run the capability audit**

```bash
node /Users/luoyige/.codex/skills/appless-device-regression/scripts/audit-coverage.mjs \
  --repo /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo \
  --skill-root /Users/luoyige/.codex/skills/appless-device-regression
```

Expected: no missing matrix, docs, registry-only, or model-only entries.

- [ ] **Step 6: Inspect the exact product diff and commit**

```bash
git diff --check
git status --short
git add scripts/verify-loopy-backend.mjs docs/current-capabilities.md scripts/hotel-smoke-evidence.test.mjs
git diff --cached --stat
git commit -m "test: enforce structured agent ownership"
```

If `docs/current-capabilities.md` or the hotel evidence test did not need changes, do not stage them.
