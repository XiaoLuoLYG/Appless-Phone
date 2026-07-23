# Multi-Agent Runtime Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the generic four-Agent runtime, bounded multi-turn/multi-tool contracts, model-selected persona/skill, and C01/C11/C20 canaries without changing the primary product UI.

**Architecture:** Extend the existing hotel four-Agent implementation instead of adding another orchestration layer. `ToolDefinitionRegistry`, `LinkedMessageBus`, `A2uiAgentRunner`, `ActionCatalog`, the current domain renderers, and registered executors remain the authorities; this plan only generalizes their contracts and host lifecycle.

**Tech Stack:** HarmonyOS ArkTS, Hypium, existing OpenAI-compatible `LocalModel`, A2UI JSONL, `LinkedMessageBus`, existing Hvigor/DevEco toolchain.

## Global Constraints

- Do not add a Coordinator, fifth Agent, second tool registry, generic DAG engine, or new dependency.
- Leader has at most 3 Plan-Observe rounds; each DataTask has at most 3 read steps; ActionPlan has at most 5 serial steps; UI has at most 1 layout model call per result.
- UI model may output only validated `updateComponents`; provider facts and immutable ActionOffer arguments remain deterministic.
- Preserve current C01, C11, and C20 UI/action behavior, including App-internal RollingGo booking.
- Preserve all unrelated working-tree changes; do not clean or reorganize worktrees.
- Read `entry/.test/default/intermediates/test/coverage_data/test_result.txt`; Hvigor exit code alone is not acceptance.

---

### Task 1: Extend the message and context contracts

**Files:**
- Modify: `agent_core/src/main/ets/agent/message/AgentMessage.ets`
- Modify: `agent_core/src/main/ets/agent/leader/LeaderTypes.ets`
- Modify: `agent_core/src/main/ets/agent/data/DataAgentTypes.ets`
- Modify: `agent_core/src/main/ets/agent/ui/UiAgentTypes.ets`
- Modify: `agent_core/Index.ets`
- Test: `entry/src/test/AgentMessage.test.ets`
- Test: `entry/src/test/List.test.ets`

**Interfaces:**
- Produces: `ConversationTurnMessage`, `CurrentSurfaceSummary`, `ObservationDigest`, `TurnResultPayload`, multi-task `LeaderPlan`, `CreateDataTaskPayload`, and `CreateUiTaskPayload`.
- Consumes: existing `AgentMessage`, `DataResult`, and `ActionPlanDraft`.

- [ ] **Step 1: Write failing contract tests**

Add these assertions to `AgentMessage.test.ets` and register no new test file:

```ts
const input: UserInputPayload = {
  text: '查询天气',
  recentMessages: [{ role: 'user', content: '我在北京' }],
  previousPersonaId: 'travel_companion',
  currentSurfaceSummary: {
    surfaceId: 'surface-1',
    kind: 'travel',
    status: 'ready',
    entityRefs: [],
    actionOfferIds: []
  },
  recentObservations: []
};
const turn: TurnResultPayload = {
  status: 'partial',
  surfaceId: 'surface-1',
  roundCount: 2,
  message: 'one source unavailable'
};
expect(AgentMessageType.TURN_RESULT).assertEqual('TURN.RESULT');
expect(AgentMessageType.ACTION_PLAN_REQUEST).assertEqual('ACTION.PLAN.REQUEST');
expect(input.recentMessages.length).assertEqual(1);
expect(turn.roundCount).assertEqual(2);
```

Also construct a `LeaderPlan` with two `dataTasks` and a `CreateUiTaskPayload` with both task IDs.

- [ ] **Step 2: Run Hypium and verify RED**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Expected: ArkTS compile fails because `TURN_RESULT`, context fields, `dataTasks`, and `dataTaskIds` do not exist.

- [ ] **Step 3: Add the minimal protocol fields**

Use these exact target shapes:

```ts
export type ConversationRole = 'user' | 'assistant';

export interface ConversationTurnMessage {
  role: ConversationRole;
  content: string;
}

export interface CurrentSurfaceSummary {
  surfaceId: string;
  kind: string;
  status: string;
  entityRefs: string[];
  actionOfferIds: string[];
}

export interface ObservationDigest {
  taskId: string;
  toolId: string;
  status: string;
  summary: string;
  entityRefs: string[];
}

export interface UserInputPayload {
  text: string;
  recentMessages?: ConversationTurnMessage[];
  previousPersonaId?: string;
  currentSurfaceSummary?: CurrentSurfaceSummary;
  recentObservations?: ObservationDigest[];
}

export type TurnResultStatus = 'success' | 'partial' | 'empty' | 'error' | 'canceled';

export interface TurnResultPayload {
  status: TurnResultStatus;
  surfaceId?: string;
  roundCount: number;
  message: string;
}
```

Add `ACTION_PLAN_REQUEST = 'ACTION.PLAN.REQUEST'` and `TURN_RESULT = 'TURN.RESULT'` to `AgentMessageType`. Replace singular `LeaderPlan.data` with `dataTasks: LeaderDataTask[]`, and replace `CreateUiTaskPayload.dataTaskId` with `dataTaskIds: string[]`. Extend Data payload exactly as follows:

```ts
export type LeaderRoundAction = 'execute' | 'answer' | 'clarify' | 'legacy_handoff';

export interface LeaderActionIntent {
  goal: string;
  allowedActionIds: string[];
}

export interface LeaderPlan {
  personaId: string;
  skillId: string;
  roundAction: LeaderRoundAction;
  ui: LeaderUiTask;
  dataTasks: LeaderDataTask[];
  actionIntent?: LeaderActionIntent;
  answer?: string;
  reasonCode: string;
}
```

```ts
export interface CreateDataTaskPayload {
  taskId: string;
  roundId: string;
  skillId: string;
  goal: string;
  allowedToolIds: string[];
  toolId: string;
  outputSchema: string;
  args: Object;
  required: boolean;
}
```

Export the new types from `agent_core/Index.ets` through the existing wildcard exports; do not add aliases.
Leader normalizes omitted optional context fields to empty arrays/strings. The new Host always supplies them; optional fields keep existing callers and fixtures source-compatible during the staged migration.

- [ ] **Step 4: Run Hypium and read the result file**

Run the command from Step 2, then:

```bash
tail -5 entry/.test/default/intermediates/test/coverage_data/test_result.txt
```

Expected after updating current test fixtures for plural arrays: `Failure: 0, Error: 0`.

- [ ] **Step 5: Commit the protocol contract**

```bash
git add agent_core/src/main/ets/agent/message/AgentMessage.ets \
  agent_core/src/main/ets/agent/leader/LeaderTypes.ets \
  agent_core/src/main/ets/agent/data/DataAgentTypes.ets \
  agent_core/src/main/ets/agent/ui/UiAgentTypes.ets \
  agent_core/Index.ets entry/src/test/AgentMessage.test.ets entry/src/test/List.test.ets
git commit -m "feat: extend multi-agent turn contracts"
```

### Task 2: Derive Agent capability views from the single registry

**Files:**
- Modify: `agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets`
- Modify: `agent_core/Index.ets`
- Test: `entry/src/test/ToolDefinitionRegistry.test.ets`

**Interfaces:**
- Produces: `dataAgentToolDefinitions(): ToolDefinition[]` and `actionAgentToolDefinitions(): ToolDefinition[]`.
- Consumes: `allToolDefinitions()` and existing cloned `ToolDefinition` values.

- [ ] **Step 1: Write the ownership test**

```ts
const all = allToolDefinitions();
const data = dataAgentToolDefinitions();
const action = actionAgentToolDefinitions();
const ids = data.concat(action).map((item: ToolDefinition): string => item.toolId);
expect(all.length).assertEqual(46);
expect(data.length).assertEqual(25);
expect(action.length).assertEqual(21);
expect(new Set<string>(ids).size).assertEqual(46);
expect(ids.indexOf('hotel.navigate') >= 0).assertTrue();
expect(data.map((item: ToolDefinition): string => item.toolId).indexOf('hotel.navigate')).assertEqual(-1);
expect(data.map((item: ToolDefinition): string => item.toolId).indexOf('social.community.search') >= 0).assertTrue();
expect(action.map((item: ToolDefinition): string => item.toolId).indexOf('social.post.preview') >= 0).assertTrue();
```

Assert that mutating a returned definition does not mutate a later view.

- [ ] **Step 2: Run Hypium and verify RED**

Run the Task 1 test command. Expected: missing exported view functions.

- [ ] **Step 3: Implement derived views without ID lists**

```ts
function isExternalActionBackend(definition: ToolDefinition): boolean {
  return definition.backendPriority.indexOf('system_intent') >= 0 ||
    definition.backendPriority.indexOf('web_session') >= 0;
}

function isDataAgentDefinition(definition: ToolDefinition): boolean {
  return definition.riskLevel === 'read' && !isExternalActionBackend(definition);
}

export function dataAgentToolDefinitions(): ToolDefinition[] {
  return allToolDefinitions().filter(isDataAgentDefinition);
}

export function actionAgentToolDefinitions(): ToolDefinition[] {
  return allToolDefinitions().filter((definition: ToolDefinition): boolean =>
    !isDataAgentDefinition(definition));
}
```

Keep `dynamic.search` and `memory.update` out of this fixed list; their owners are runtime virtual capabilities.

- [ ] **Step 4: Run Hypium and verify ownership counts**

Run the Task 1 command and read `test_result.txt`. Expected: 46 unique fixed tools, split 25/21, zero failures.

- [ ] **Step 5: Commit the registry views**

```bash
git add agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets \
  agent_core/Index.ets entry/src/test/ToolDefinitionRegistry.test.ets
git commit -m "feat: derive agent capability views"
```

### Task 3: Build bounded persona and skill planning context

**Files:**
- Create: `entry/src/main/ets/model/LeaderPersonaContext.ets`
- Modify: `agent_core/src/main/ets/agent/leader/LeaderTypes.ets`
- Modify: `entry/src/test/PersonaPrompt.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Interfaces:**
- Produces: `leaderPersonaContext(previousPersonaId: string): LeaderPersonaMetadata[]`.
- Consumes: `personaPackForId`, the existing persona manifests, soul/memory, and parsed skill lists.

- [ ] **Step 1: Add tests for explicit persona, previous hint, and one active skill**

```ts
const catalog = leaderPersonaContext('food_companion');
const food = catalog.filter((item: LeaderPersonaMetadata): boolean =>
  item.personaId === 'food_companion')[0];
expect(food.previous).assertTrue();
expect(food.activeSkills.length).assertEqual(1);
expect(food.activeSkills[0].status).assertEqual('active');
expect(food.soul.length > 0).assertTrue();
expect(food.memory.length > 0).assertTrue();
expect(JSON.stringify(catalog).indexOf('placeholder')).assertEqual(-1);
```

Add a Leader fixture proving exact user text `用工作分身` constrains the selected persona, while `previousPersonaId` remains only a hint.

- [ ] **Step 2: Run Hypium and verify RED**

Expected: missing `LeaderPersonaMetadata` and `leaderPersonaContext`.

- [ ] **Step 3: Add the compact context builder**

Add the core type:

```ts
export interface LeaderPersonaMetadata {
  personaId: string;
  name: string;
  soul: string;
  memory: string;
  previous: boolean;
  activeSkills: LeaderSkillMetadata[];
}

export interface LeaderPlanningContext {
  tools: LeaderToolMetadata[];
  personas: LeaderPersonaMetadata[];
}
```

Create one pure entry-side builder. Include only skills whose parsed status is `active`, and cap the array to the existing active skill:

```ts
export function leaderPersonaContext(previousPersonaId: string): LeaderPersonaMetadata[] {
  return allPersonaPacks().map((pack: PersonaPack): LeaderPersonaMetadata => {
    const active = pack.skillList.filter((skill: PersonaSkillMarkdown): boolean =>
      skill.status === 'active').slice(0, 1);
    return {
      personaId: pack.manifest.id,
      name: pack.manifest.name,
      soul: pack.soul,
      memory: pack.memory,
      previous: pack.manifest.id === previousPersonaId,
      activeSkills: active.map((skill: PersonaSkillMarkdown): LeaderSkillMetadata => ({
        skillId: skill.id,
        description: skill.description,
        instructions: skill.body
      }))
    };
  });
}
```

Import the existing `allPersonaPacks()` export from `PersonaStore.ets`; do not copy persona IDs.

- [ ] **Step 4: Run Hypium and confirm persona tests pass**

Expected: no placeholder skill, one active skill maximum, and `Failure: 0, Error: 0`.

- [ ] **Step 5: Commit persona planning context**

```bash
git add entry/src/main/ets/model/LeaderPersonaContext.ets \
  agent_core/src/main/ets/agent/leader/LeaderTypes.ets \
  entry/src/test/PersonaPrompt.test.ets entry/src/test/List.test.ets
git commit -m "feat: expose persona context to leader"
```

### Task 4: Implement the model-driven Leader planner and bounded observations

**Files:**
- Create: `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentLeaderPlanner.ets`
- Modify: `agent_core/src/main/ets/agent/leader/LeaderAgent.ets`
- Modify: `agent_core/src/main/ets/agent/leader/LeaderTypes.ets`
- Test: `entry/src/test/LeaderAgent.test.ets`
- Create: `entry/src/test/MultiAgentLeaderPlanner.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Interfaces:**
- Produces: strict `LeaderDecision`, parallel `dataTasks`, maximum-three-round Plan-Observe behavior, and bounded observation digests.
- Consumes: `LocalModel.complete`, registry-derived tool metadata, `LeaderPersonaMetadata[]`, and the Task 1 context envelope.

- [ ] **Step 1: Write failing planner and round-limit tests**

Use `ScriptedLocalModel` with exact decisions:

```ts
const decision = '{"personaId":"travel_companion","skillId":"","roundAction":"execute",' +
  '"dataTasks":[' +
  '{"localId":"flight","goal":"查航班","allowedToolIds":["flight.search"],"toolId":"flight.search","input":{},"required":false},' +
  '{"localId":"train","goal":"查高铁","allowedToolIds":["train.search"],"toolId":"train.search","input":{},"required":false}' +
  '],"uiIntent":{"purpose":"比较出行方案","preferredDensity":"comfortable","requiredSections":["flight","train"]},' +
  '"reasonCode":"parallel_reads"}';
```

Assert two TASK.CREATE.DATA messages are published without waiting on each other. Feed observations that request a second round, then assert a fourth round is rejected with `LEADER_ROUND_LIMIT` and no new tasks.

- [ ] **Step 2: Run Hypium and verify RED**

Expected: no generic planner and current Leader only supports one DataTask.

- [ ] **Step 3: Implement strict JSON parsing and the three-round state**

The planner prompt must be assembled from existing metadata, not a handwritten tool list:

```ts
private prompt(input: InputUserPayload, context: LeaderPlanningContext, round: number): string {
  return [
    'You are the Appless Leader Agent.',
    'Return exactly one LeaderDecision JSON object.',
    'Select one persona and at most one active skill.',
    'Tasks in this round must be independent. Put dependent work in a later round.',
    'Never emit provider facts, action args, A2UI, credentials, or unregistered tool IDs.',
    'Maximum planning rounds: 3.',
    'Round: ' + round.toString(),
    'Context: ' + JSON.stringify(input),
    'Capabilities: ' + JSON.stringify(context.tools),
    'Personas: ' + JSON.stringify(context.personas)
  ].join('\n');
}
```

Validate exactly one JSON object, exact keys, registered tool IDs, unique task IDs, allowed-tool containment, one persona, one skill, and read-only DataTask tools before publishing. Store only bounded `ObservationDigest[]`, never full DataResult, in the next model prompt.

- [ ] **Step 4: Run Hypium and verify parallel, dependent, cancel, and round-limit cases**

Expected: existing Leader cancellation/timeout tests plus new round tests pass; `test_result.txt` reports zero failure/error.

- [ ] **Step 5: Commit the generic Leader**

```bash
git add entry/src/main/ets/pages/A2uiHome/agent/MultiAgentLeaderPlanner.ets \
  agent_core/src/main/ets/agent/leader/LeaderAgent.ets \
  agent_core/src/main/ets/agent/leader/LeaderTypes.ets \
  entry/src/test/LeaderAgent.test.ets \
  entry/src/test/MultiAgentLeaderPlanner.test.ets entry/src/test/List.test.ets
git commit -m "feat: add bounded multi-round leader"
```

### Task 5: Add bounded read-only ReAct to DataAgent

**Files:**
- Modify: `agent_core/src/main/ets/agent/data/DataAgentTypes.ets`
- Modify: `agent_core/src/main/ets/agent/data/DataAgent.ets`
- Create: `entry/src/main/ets/pages/A2uiHome/agent/ReadOnlyDataPlanner.ets`
- Test: `entry/src/test/DataAgent.test.ets`
- Create: `entry/src/test/ReadOnlyDataPlanner.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Interfaces:**
- Produces: `DataStepDecision`, `DataTaskPlanner`, and a maximum-three-step DataTask loop.
- Consumes: existing `DataTaskAuthorizer`, `DataTaskExecutor`, registry-derived allowed tools, and `LocalModel`.

- [ ] **Step 1: Write failing read-only and step-limit tests**

```ts
const task: CreateDataTaskPayload = {
  taskId: 'data-1', roundId: 'round-1', skillId: '', goal: '查天气',
  allowedToolIds: ['dynamic.search'], toolId: 'dynamic.search',
  outputSchema: 'dynamicToolConnect', args: {}, required: true
};
```

Script `call → observe → finish` and assert one DataResult. Script a fourth call and assert `DATA_STEP_LIMIT`. Script `hotel.booking.open` and assert `TOOL_NOT_ALLOWED` before executor invocation.

- [ ] **Step 2: Run Hypium and verify RED**

Expected: current DataAgent invokes its executor once and has no planner/step contract.

- [ ] **Step 3: Implement the bounded planner seam**

```ts
export type DataStepKind = 'call' | 'finish';

export interface DataStepDecision {
  kind: DataStepKind;
  toolId: string;
  args: Object;
  summary: string;
}

export interface DataTaskPlanner {
  next(task: CreateDataTaskPayload, observations: ObservationDigest[], step: number): Promise<DataStepDecision>;
}
```

DataAgent must authorize every `call`, verify `allowedToolIds`, execute only registry-derived Data tools or turn-scoped safe dynamic reads, convert each result to a bounded digest, and publish only the final DataResult. Stop at three steps. Do not retry write/system/web definitions.

Use this prompt in `ReadOnlyDataPlanner`:

```ts
return 'You are the Appless Data Agent. Return one DataStepDecision JSON.\n' +
  'Use only allowed read tools. Maximum 3 steps. Preserve real IDs and sources.\n' +
  'Do not execute writes, system intents, web sessions, client actions, or code.\n' +
  'Task: ' + JSON.stringify(task) + '\nObservations: ' + JSON.stringify(observations);
```

- [ ] **Step 4: Run Hypium and verify DataAgent fail-closed behavior**

Expected: call/observe/finish works; unregistered/write/fourth-step cases publish `TASK.ERROR`; no executor call occurs for rejected tasks.

- [ ] **Step 5: Commit bounded DataAgent planning**

```bash
git add agent_core/src/main/ets/agent/data/DataAgentTypes.ets \
  agent_core/src/main/ets/agent/data/DataAgent.ets \
  entry/src/main/ets/pages/A2uiHome/agent/ReadOnlyDataPlanner.ets \
  entry/src/test/DataAgent.test.ets entry/src/test/ReadOnlyDataPlanner.test.ets \
  entry/src/test/List.test.ets
git commit -m "feat: bound data agent read planning"
```

### Task 6: Generalize UI aggregation and Action planning

**Files:**
- Modify: `agent_core/src/main/ets/agent/ui/UiAgent.ets`
- Modify: `agent_core/src/main/ets/agent/ui/UiAgentTypes.ets`
- Modify: `agent_core/src/main/ets/agent/action/ActionAgent.ets`
- Modify: `agent_core/src/main/ets/agent/action/ActionAgentTypes.ets`
- Modify: `agent_core/src/main/ets/agent/action/ActionPlanTypes.ets`
- Test: `entry/src/test/UiAgent.test.ets`
- Test: `entry/src/test/ActionAgent.test.ets`

**Interfaces:**
- Produces: multi-DataResult UI aggregation, one-call A2UI layout, and model-compiled ActionPlan for composed actions.
- Consumes: `CreateUiTaskPayload.dataTaskIds`, `ActionOffer[]`, existing `UiLayoutPlanner`, `ActionCatalog`, and `ActionPlanRunner`.

- [ ] **Step 1: Write failing UI aggregation and Action compiler tests**

Create a UI task with `dataTaskIds: ['flight-data', 'train-data']`; publish results in reverse order; assert one surface, one final render, and both data sets. Publish one error and one success; assert partial render.

For ActionAgent, provide an intent “生成回复后保存草稿” and a scripted compiler output:

```ts
const plan: ActionPlanDraft = {
  planId: 'plan-1', runId: 'run-1', label: '生成并保存',
  steps: [{ stepId: 'generate', actionId: 'social.reply.draft', args: {} }, {
    stepId: 'save', actionId: 'gmail.draft.create', args: {},
    inputFrom: [{ target: '/body', stepId: 'generate', path: '/body' }]
  }]
};
```

Assert exact direct ActionOffer clicks never invoke the compiler.

- [ ] **Step 2: Run Hypium and verify RED**

Expected: UiAgent accepts one data task only; ActionAgent has no intent compiler seam.

- [ ] **Step 3: Implement the smallest aggregation/compiler changes**

Change `UiTaskRenderer.result` to consume an ordered array while retaining existing renderer implementations through a one-item adapter during Wave 0:

```ts
result(
  task: CreateUiTaskPayload,
  data: DataResult[],
  offers: ActionOffer[],
  surfaceId: string
): Promise<UiRenderResult>;
```

UiAgent waits until every required task is terminal, preserves `dataTaskIds` order, and renders success/partial/empty/error once. `UiLayoutPlanner` remains one call; skeleton and error remain deterministic.

Add one optional compiler dependency to ActionAgent:

```ts
export interface ActionPlanCompiler {
  compile(goal: string, offers: ActionOffer[], allowedActionIds: string[]): Promise<ActionPlanDraft>;
}
```

Leader publishes `ACTION.PLAN.REQUEST` with this exact payload:

```ts
export interface ActionPlanRequestPayload {
  uiTaskId: string;
  dataTaskIds: string[];
  goal: string;
  allowedActionIds: string[];
}
```

ActionAgent invokes the compiler, validates the returned draft, publishes `ACTION.PLAN.DRAFT`, binds the matching surface, then publishes `ACTION.PLAN.READY`. Direct `ACTION.RUN` remains compiler-free.

- [ ] **Step 4: Run Hypium and verify ordering, partial, exact-click, and five-step limits**

Expected: reverse arrival yields deterministic order; invalid offers never render; direct actions do not call the model; compiled plans still use existing JSON Pointer and confirmation tests.

- [ ] **Step 5: Commit UI and Action generalization**

```bash
git add agent_core/src/main/ets/agent/ui/UiAgent.ets \
  agent_core/src/main/ets/agent/ui/UiAgentTypes.ets \
  agent_core/src/main/ets/agent/action/ActionAgent.ets \
  agent_core/src/main/ets/agent/action/ActionAgentTypes.ets \
  agent_core/src/main/ets/agent/action/ActionPlanTypes.ets \
  entry/src/test/UiAgent.test.ets entry/src/test/ActionAgent.test.ets
git commit -m "feat: aggregate ui data and compile action plans"
```

### Task 7: Extract MultiAgentRuntime and cut over C01/C11/C20 canaries

**Files:**
- Create: `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntime.ets`
- Create: `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntimeTypes.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/HotelAgentRuntime.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/Index.ets`
- Create: `entry/src/test/MultiAgentRuntime.test.ets`
- Modify: `entry/src/test/HotelAgentRuntime.test.ets`
- Modify: `entry/src/test/PersonaMemoryUpdate.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Interfaces:**
- Produces: one host-owned runtime lifecycle, `submit`, `runAction`, `cancelActiveTurn`, `dispose`, and `TurnResultPayload` settlement.
- Consumes: existing bus, four Agents, planners, adapters, surface writer, A2UI planner, and current page settings.

- [ ] **Step 1: Write failing canary lifecycle tests**

Assert all five readers (four Agents plus observer) are started before INPUT.USER. Cover:

```ts
expect(await runtime.submit('你好')).assertEqual('success');
expect(await runtime.submit('我只喝瑞幸咖啡')).assertEqual('success');
expect(await runtime.submit('帮我找深圳酒店')).assertEqual('success');
```

Add exact correlation, timeout, dispose, settings-fingerprint refresh, and `TURN.RESULT` settlement tests. Assert no canary calls `LoopBackend`.

- [ ] **Step 2: Run Hypium and verify RED**

Expected: generic runtime does not exist and hotel lifecycle is embedded in `HotelAgentRuntime`.

- [ ] **Step 3: Move only generic lifecycle code**

The public runtime surface must stay small:

```ts
export interface MultiAgentTurnOutcome {
  ok: boolean;
  status: TurnResultStatus;
  surfaceId: string;
  message: string;
}

export class MultiAgentRuntime {
  submit(text: string, context: UserInputPayload): Promise<MultiAgentTurnOutcome>;
  runAction(action: A2uiAction, context: ActionExecutionContext): Promise<boolean>;
  cancelActiveTurn(reason: string): void;
  dispose(): void;
}
```

Move bus ownership, IDs, observer, deadlines, generation-fenced writer, pending turn/action state, settings fingerprint, and settlement out of `HotelAgentRuntime`. Keep hotel parsing, hotel provider adapter, hotel renderer, and hotel executor in their existing files. Replace hotel keyword routing with canary tool ownership after Leader planning; C01 direct answer and C11 memory update also use the new runtime.

When building `UserInputPayload`, reuse `recentMessages()` and pass at most the last 8 user/assistant messages, the previous persona ID, current surface summary, and bounded observation digests.

- [ ] **Step 4: Run the full foundation gate**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
tail -5 entry/.test/default/intermediates/test/coverage_data/test_result.txt
node scripts/verify-loopy-backend.mjs
node scripts/hotel-smoke-evidence.test.mjs
```

Expected: Hypium `Failure: 0, Error: 0`; verifier and hotel evidence tests PASS; existing 3 unrelated working-tree changes remain unstaged.

- [ ] **Step 5: Commit the runtime canary**

```bash
git add entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntime.ets \
  entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntimeTypes.ets \
  entry/src/main/ets/pages/A2uiHome/agent/HotelAgentRuntime.ets \
  entry/src/main/ets/pages/A2uiHome/Index.ets \
  entry/src/test/MultiAgentRuntime.test.ets \
  entry/src/test/HotelAgentRuntime.test.ets \
  entry/src/test/PersonaMemoryUpdate.test.ets entry/src/test/List.test.ets
git commit -m "feat: introduce multi-agent runtime canary"
```

## Foundation Completion Gate

- C01, C11, C20 are owned by `MultiAgentRuntime` with no keyword routing.
- “我在北京” then “查询天气” passes the bounded-context contract test.
- Two independent DataTasks run concurrently; dependent tasks wait for the next Leader round.
- Four independent prompts exist and obey the 3/3/1/5 limits.
- Existing hotel UI, navigation, in-App booking, persona memory, and deterministic fallback remain intact.
- No non-canary capability is marked migrated yet.
