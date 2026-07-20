# Multi-Agent Runtime and ActionPlan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the shared in-process message bus, Leader/Data/UI/Action agent roles, correlated typed messages, a read-only ActionCatalog view, and a safe sequential ActionPlan runner with previous-step JSON Pointer output binding.

**Architecture:** All four agents open independent readers on one `LinkedMessageBus`; no agent holds or invokes another agent. Each agent processes its own accepted messages serially, while different agents run concurrently. Role behavior is injected behind small ArkTS interfaces so the runtime can be unit-tested without providers or UI, and the hotel vertical slice can reuse the existing model, provider adapters, A2UI store, tool registry, and client action policy. ActionPlan is declarative data only, is capped at five serial steps, and is validated both before execution and after every binding.

**Tech Stack:** ArkTS, HarmonyOS `@ohos/hypium`, existing `agent_core` HAR, existing `ToolDefinitionRegistry`, existing A2UI v0.9.1 types, Node.js static verifier, DevEco `hvigor`.

## Global Constraints

- Preserve the user's unrelated working-tree changes. Stage only files named by the current task.
- Adapt the useful shape of Loopy PR #8; do not cherry-pick or overwrite the current `ReActAgentRunner`, A2UI runtime, provider clients, or registries.
- The bus is an in-process broadcast transport only. Do not add persistence, distributed queues, retries, locks, priorities, or exactly-once semantics.
- `AgentMessage` has only `type`, `conversationId`, `turnId`, `taskId`, and `payload`. Keep `planId`, `runId`, and `stepId` inside action payloads.
- Do not use PR #8's `BATCH_PENDING`; every role processes accepted messages one at a time so messages from different turns cannot be batched together.
- UI Agent is the only writer of A2UI surfaces. Leader, Data, and Action publish typed messages.
- ActionCatalog must remain a read-only view over `ToolDefinitionRegistry` plus injected client/surface policy. Do not create a copied action registry.
- Action Agent executes registered actions through an injected executor. It must not generate, compile, persist, or evaluate code.
- ActionPlan v1 supports at most five serial steps and standard JSON Pointer references to earlier completed steps. No loop, branch, parallel block, expression language, template interpolation, script, or dynamic import.
- Keep this plan's implementation generic. Hotel-specific provider, UI, and system-intent wiring belongs in `2026-07-20-hotel-agent-vertical-slice.md`.
- Add every new Hypium suite to `entry/src/test/List.test.ets`; a test file that is not imported and invoked there is not an executed test.
- Do not trust `hvigor` exit code alone. Read `entry/.test/default/intermediates/test/coverage_data/test_result.txt`.
- Use one focused commit per task. Do not stage `.superpowers/**`, local provider configuration, generated HAP/HAR outputs, or unrelated changes.

---

## Task 1: Define Correlated Messages and Structured Data Results

**Files:**

- Create: `agent_core/src/main/ets/agent/message/AgentMessage.ets`
- Create: `agent_core/src/main/ets/agent/message/DataResult.ets`
- Create: `entry/src/test/AgentMessage.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: Write the failing message-contract test**

Add a Hypium suite that constructs an `INPUT.USER` message and a `TASK.RESULT.DATA` message, then asserts that correlation fields are retained and `DataResult` distinguishes `success`, `partial`, `empty`, and `error`.

```ts
it('keeps conversation turn and task correlation on every message', 0, () => {
  const message: AgentMessage = {
    type: AgentMessageType.INPUT_USER,
    conversationId: 'conversation-a',
    turnId: 'turn-2',
    taskId: 'input-2',
    payload: { text: '深圳酒店' }
  };

  expect(message.conversationId).assertEqual('conversation-a');
  expect(message.turnId).assertEqual('turn-2');
  expect(message.taskId).assertEqual('input-2');
});
```

Also test that the message type list contains exactly the approved public messages:

```text
INPUT.USER
TASK.CREATE.UI
TASK.CREATE.DATA
TASK.RESULT.UI
TASK.RESULT.DATA
TASK.ERROR
ACTION.PLAN.CREATE
ACTION.PLAN.READY
ACTION.RUN
ACTION.PROGRESS
ACTION.RESULT
TURN.CANCEL
```

- [ ] **Step 2: Register the suite and run it to verify failure**

Add the import and invocation in `entry/src/test/List.test.ets`, then run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Expected: compile failure because `AgentMessage`, `AgentMessageType`, and `DataResult` do not exist yet.

- [ ] **Step 3: Add the minimal public contracts**

Use string-valued enum members so logs and static checks preserve the wire names:

```ts
export enum AgentMessageType {
  INPUT_USER = 'INPUT.USER',
  TASK_CREATE_UI = 'TASK.CREATE.UI',
  TASK_CREATE_DATA = 'TASK.CREATE.DATA',
  TASK_RESULT_UI = 'TASK.RESULT.UI',
  TASK_RESULT_DATA = 'TASK.RESULT.DATA',
  TASK_ERROR = 'TASK.ERROR',
  ACTION_PLAN_CREATE = 'ACTION.PLAN.CREATE',
  ACTION_PLAN_READY = 'ACTION.PLAN.READY',
  ACTION_RUN = 'ACTION.RUN',
  ACTION_PROGRESS = 'ACTION.PROGRESS',
  ACTION_RESULT = 'ACTION.RESULT',
  TURN_CANCEL = 'TURN.CANCEL'
}

export interface AgentMessage {
  type: AgentMessageType;
  conversationId: string;
  turnId: string;
  taskId: string;
  payload: Object;
}
```

Define typed payload interfaces in the same file for user input, UI task, data task, UI result, and task error. Keep their common correlation in the envelope instead of duplicating it in every payload.

In `DataResult.ets`, implement:

```ts
export type DataResultStatus = 'success' | 'partial' | 'empty' | 'error';

export interface DataSource {
  provider: string;
  backend: ToolBackendType;
  operation: string;
  fetchedAt: string;
  accountHint?: string;
}

export interface DataResult {
  toolId: string;
  outputSchema: string;
  status: DataResultStatus;
  sources: DataSource[];
  data: Object;
  warnings: string[];
  error?: DataResultError;
}
```

Do not use `A2uiGenericToolResultData` here.

- [ ] **Step 4: Run the suite and inspect the real result file**

Run the same Hypium command. Then inspect:

```bash
rg -n "Tests|Failures|Errors|Passed|Failed" \
  entry/.test/default/intermediates/test/coverage_data/test_result.txt
```

Expected: the new contract suite passes; any unrelated baseline failure is recorded separately.

- [ ] **Step 5: Commit only this task**

```bash
git add \
  agent_core/src/main/ets/agent/message/AgentMessage.ets \
  agent_core/src/main/ets/agent/message/DataResult.ets \
  entry/src/test/AgentMessage.test.ets \
  entry/src/test/List.test.ets
git commit -m "feat: define correlated agent messages"
```

---

## Task 2: Implement the Broadcast Bus and Serial Message-Driven Base

**Files:**

- Create: `agent_core/src/main/ets/agent/message/LinkedMessageBus.ets`
- Create: `agent_core/src/main/ets/agent/MessageDrivenAgent.ets`
- Create: `entry/src/test/LinkedMessageBus.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: Write failing bus tests**

Cover these cases:

1. Two readers opened before a publish each receive the same message.
2. Advancing reader A does not advance reader B.
3. A reader opened after message 1 receives only later messages.
4. Closing one reader unblocks its pending `receive()` without affecting other readers.
5. A `MessageDrivenAgent` rejects unrelated message types and handles accepted messages strictly in arrival order.

The serial-processing test must make the first handler wait on a controlled promise, publish a second accepted message, and assert the second handler has not started until the first resolves.

- [ ] **Step 2: Run the suite to verify failure**

Run the strict Hypium command from Task 1.

Expected: compile failure because the bus and base agent do not exist.

- [ ] **Step 3: Implement a minimal linked broadcast log**

Port only the linked-reader idea from Loopy PR #8:

```ts
export class LinkedMessageBus {
  private head: MessageNode = MessageNode.sentinel();
  private tail: MessageNode = this.head;

  openReader(): AgentMessageReader {
    return new AgentMessageReader(this.tail);
  }

  publish(message: AgentMessage): void {
    const next = new MessageNode(copyAgentMessage(message));
    this.tail.append(next);
    this.tail = next;
  }
}
```

Each node owns the waiters for its `next` link. `AgentMessageReader.receive()` waits for `cursor.next`, advances only its own cursor, and returns a copied envelope. `AgentMessageReader.close()` resolves its own pending wait as `null`; it does not publish a business message.

Do not add queue modes, batch reads, history replay, persistence, or a singleton global bus.

- [ ] **Step 4: Implement the serial base class**

```ts
export abstract class MessageDrivenAgent {
  private reader: AgentMessageReader;
  private running: boolean = false;

  constructor(bus: LinkedMessageBus) {
    this.reader = bus.openReader();
  }

  start(): void {
    if (this.running) {
      return;
    }
    this.running = true;
    this.pump();
  }

  stop(): void {
    this.running = false;
    this.reader.close();
  }

  protected abstract accepts(message: AgentMessage): boolean;
  protected abstract process(message: AgentMessage): Promise<void>;
}
```

The private pump must await one `process()` call before receiving the next accepted message. Catch handler exceptions inside the role agent that can publish a correlated `TASK.ERROR`; do not silently convert every base-class exception into an uncorrelated error.

- [ ] **Step 5: Run tests and inspect `test_result.txt`**

Expected: all new bus tests pass, including independent readers and strict per-agent ordering.

- [ ] **Step 6: Commit only this task**

```bash
git add \
  agent_core/src/main/ets/agent/message/LinkedMessageBus.ets \
  agent_core/src/main/ets/agent/MessageDrivenAgent.ets \
  entry/src/test/LinkedMessageBus.test.ets \
  entry/src/test/List.test.ets
git commit -m "feat: add broadcast agent message bus"
```

---

## Task 3: Add the Leader Agent and Explicit UI/Data Fan-Out

**Files:**

- Create: `agent_core/src/main/ets/agent/leader/LeaderAgent.ets`
- Create: `agent_core/src/main/ets/agent/leader/LeaderTypes.ets`
- Create: `entry/src/test/LeaderAgent.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: Write a failing fan-out test**

Use a scripted planner that returns one UI task and one data task for a hotel input. Start Leader plus an observer reader, publish `INPUT.USER`, and assert:

- both `TASK.CREATE.UI` and `TASK.CREATE.DATA` are published;
- both reuse the input `conversationId` and `turnId`;
- each has a different positive/non-empty `taskId`;
- the UI task does not contain provider output;
- the data task declares `hotel.search`, `hotelSearchResults`, and structured args;
- Leader does not publish A2UI JSONL.

Add a second test where the planner throws and assert one correlated `TASK.ERROR`.
Add a short-timeout test showing an unfinished turn becomes terminal once and a later Data/UI result cannot revive or overwrite it.

- [ ] **Step 2: Run to verify failure**

Expected: compile failure because Leader contracts are absent.

- [ ] **Step 3: Add the minimal planner contract**

```ts
export interface LeaderUiTask {
  taskId: string;
  intent: string;
  expectedOutputSchema: string;
}

export interface LeaderDataTask {
  taskId: string;
  toolId: string;
  outputSchema: string;
  args: Object;
}

export interface LeaderPlan {
  ui: LeaderUiTask;
  data: LeaderDataTask;
}

export interface LeaderPlanner {
  plan(message: AgentMessage, input: InputUserPayload): Promise<LeaderPlan>;
}
```

The later hotel slice supplies the model-backed planner. The core runtime must not import entry UI code or provider clients.

- [ ] **Step 4: Implement Leader as a direct subscriber**

`LeaderAgent.accepts()` accepts `INPUT.USER`, the UI/Data/Action terminal result messages, `TASK.ERROR`, and `TURN.CANCEL`. On user input:

1. validate non-empty correlation fields and text;
2. await the planner;
3. publish `TASK.CREATE.UI`;
4. publish `TASK.CREATE.DATA` immediately afterward without awaiting either downstream task;
5. start one bounded whole-turn timer and store only the small per-turn UI/Data/Action terminal-state record needed for cancellation, timeout, error reporting, and late-result filtering.

Publishing both messages is synchronous and downstream readers run independently, so UI and Data can proceed concurrently. Leader must not call either role instance.

On terminal results, update only the matching conversation/turn/task record and clear the timer when the turn reaches its terminal state. On whole-turn timeout, publish one correlated `TASK.ERROR`, mark the turn timed out, and ignore late results. On `TURN.CANCEL`, mark the turn canceled and ignore subsequent completion bookkeeping for that turn. Add a test showing that a result carrying the wrong `taskId` cannot complete another task.

- [ ] **Step 5: Run the tests**

Expected: fan-out and correlated-error tests pass. Confirm no test relies on message arrival timing beyond the controlled observer reader.

- [ ] **Step 6: Commit only this task**

```bash
git add \
  agent_core/src/main/ets/agent/leader/LeaderAgent.ets \
  agent_core/src/main/ets/agent/leader/LeaderTypes.ets \
  entry/src/test/LeaderAgent.test.ets \
  entry/src/test/List.test.ets
git commit -m "feat: add leader task fan-out"
```

---

## Task 4: Add Data Agent and the Only-Writer UI Agent

**Files:**

- Create: `agent_core/src/main/ets/agent/data/DataAgent.ets`
- Create: `agent_core/src/main/ets/agent/data/DataAgentTypes.ets`
- Create: `agent_core/src/main/ets/agent/ui/UiAgent.ets`
- Create: `agent_core/src/main/ets/agent/ui/UiAgentTypes.ets`
- Create: `entry/src/test/DataAgent.test.ets`
- Create: `entry/src/test/UiAgent.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: Write failing Data Agent tests**

Use an injected fake executor:

```ts
export interface DataTaskExecutor {
  execute(task: CreateDataTaskPayload): Promise<DataResult>;
}
```

Assert that Data Agent:

- accepts only `TASK.CREATE.DATA` and matching cancellation;
- publishes `TASK.RESULT.DATA` with the original conversation/turn/task correlation;
- preserves `partial`, `sources`, warnings, real IDs, and domain data without flattening to UI rows;
- publishes `TASK.ERROR` when the executor throws;
- suppresses a result that finishes after `TURN.CANCEL`.

- [ ] **Step 2: Write failing UI Agent ordering tests**

Use injected renderer and writer interfaces:

```ts
export interface UiTaskRenderer {
  skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<string>;
  result(task: CreateUiTaskPayload, data: DataResult, surfaceId: string): Promise<string>;
  error(task: CreateUiTaskPayload, message: string, surfaceId: string): Promise<string>;
  actionStatus(payload: Object, surfaceId: string): Promise<string>;
}

export interface UiSurfaceWriter {
  write(turnId: string, surfaceId: string, jsonl: string): Promise<void>;
}
```

Cover:

- UI task first: skeleton is written, then the data patch writes the same `surfaceId`.
- Data first: data is cached; when UI task arrives it writes skeleton and then result to the same `surfaceId`.
- Two turns in one conversation do not share data.
- Two conversations with the same `turnId` do not share surfaces; context key is `conversationId + turnId`.
- A late result for an old/canceled turn never updates the current surface.
- Action progress/result updates only its exact conversation/turn/surface.
- No other test fake writes a surface directly.

- [ ] **Step 3: Run to verify failure**

Expected: compile failures for the missing role classes and interfaces.

- [ ] **Step 4: Implement Data Agent**

Data Agent has a bus, executor, and a set of canceled correlation keys. It does not import A2UI:

```ts
protected async process(message: AgentMessage): Promise<void> {
  if (message.type === AgentMessageType.TURN_CANCEL) {
    this.canceled.add(turnKey(message));
    return;
  }
  try {
    const result = await this.executor.execute(message.payload as CreateDataTaskPayload);
    if (!this.canceled.has(turnKey(message))) {
      this.bus.publish(dataResultMessage(message, result));
    }
  } catch (error) {
    if (!this.canceled.has(turnKey(message))) {
      this.bus.publish(taskErrorMessage(message, errorMessage(error)));
    }
  }
}
```

Keep timeout ownership in the injected provider executor. Do not add a generic retry wrapper.

- [ ] **Step 5: Implement UI Agent with per-turn context**

Use one `Map<string, UiTurnContext>` keyed by encoded conversation and turn. Context holds:

- `surfaceId`;
- optional UI task;
- optional pending DataResult;
- `canceled`;
- whether skeleton/result was written.

Generate `surfaceId` with the existing A2UI `newSurfaceId()` helper. Only call the injected `UiSurfaceWriter` from this class. After a successful write, publish `TASK.RESULT.UI` with `surfaceId` and render state.

When both task and data are present, render exactly once for that data task. After the final write, discard pending payloads but retain the small active-surface authorization context required by button actions. Delete that context on cancellation or when the host declares the surface replaced; retain no provider keys or large history.

- [ ] **Step 6: Run tests and inspect the result file**

Expected: Data and UI role tests pass, especially the data-before-UI and cross-conversation cases.

- [ ] **Step 7: Commit only this task**

```bash
git add \
  agent_core/src/main/ets/agent/data/DataAgent.ets \
  agent_core/src/main/ets/agent/data/DataAgentTypes.ets \
  agent_core/src/main/ets/agent/ui/UiAgent.ets \
  agent_core/src/main/ets/agent/ui/UiAgentTypes.ets \
  entry/src/test/DataAgent.test.ets \
  entry/src/test/UiAgent.test.ets \
  entry/src/test/List.test.ets
git commit -m "feat: add data and ui message agents"
```

---

## Task 5: Build the Read-Only ActionCatalog View

**Files:**

- Create: `agent_core/src/main/ets/agent/action/ActionCatalog.ets`
- Create: `agent_core/src/main/ets/agent/action/ActionCatalogTypes.ets`
- Create: `entry/src/test/ActionCatalog.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: Write failing catalog tests**

Create fake lookup/policy adapters, not a second array of action definitions. Test:

- `hotel.detail` is allowed when the source definition's `actions` contains it.
- an invented `hotel.book` is rejected even if the UI event asks for it;
- UI placement rejects an otherwise well-formed candidate that is not declared by the source definition;
- `workflow.run` is recognized only as the fixed workflow entry;
- exact surface action mismatch rejects changed phone, hotel ID, coordinates, or turn;
- a client action is accepted only when the injected client policy recognizes the exact action;
- target input validation is invoked at execution time.

- [ ] **Step 2: Run to verify failure**

Expected: missing catalog types/classes.

- [ ] **Step 3: Define adapters over existing authorities**

```ts
export interface ToolDefinitionLookup {
  find(toolId: string): ToolDefinition | null;
}

export interface SurfaceActionAuthorizer {
  allows(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    actionId: string,
    args: Object
  ): boolean;
}

export interface ClientActionAuthorizer {
  allows(actionId: string, args: Object): boolean;
}

export interface ActionArgsValidator {
  validate(actionId: string, args: Object): ActionValidationResult;
}
```

At the entry layer, these adapters call the current `toolDefinitionForToolId` and HTML/A2UI action policy. Do not move or duplicate the source registries into this file.

- [ ] **Step 4: Implement the view**

`ActionCatalog` performs:

1. target action has a current tool definition, or is the fixed `workflow.run` entry, or is an injected client action;
2. for a direct/single action and the first ActionPlan step, the source tool definition declares the action ID;
3. the exact surface/turn action is authorized;
4. target args pass the injected validator;
5. returns the current definition's risk/backend metadata without caching a copy.

Later ActionPlan steps do not need to be separate visible surface buttons, but each must still have a current registered definition, pass its input/risk/backend validation, and consume data only through declared prior-step bindings. Add separate catalog methods for surface entry validation and registered step execution so this distinction is explicit rather than bypassed with a boolean flag.

Expose a placement check used by UI renderers before they serialize a button. It checks the current source definition, candidate action definition, and candidate args, but not a surface policy that cannot exist until after rendering. Execution still uses the stricter exact-surface check.

The catalog must re-run these checks for execution. A UI-time check alone is not sufficient.

- [ ] **Step 5: Run tests and inspect `test_result.txt`**

Expected: all catalog allow/deny cases pass.

- [ ] **Step 6: Commit only this task**

```bash
git add \
  agent_core/src/main/ets/agent/action/ActionCatalog.ets \
  agent_core/src/main/ets/agent/action/ActionCatalogTypes.ets \
  entry/src/test/ActionCatalog.test.ets \
  entry/src/test/List.test.ets
git commit -m "feat: add read only action catalog"
```

---

## Task 6: Implement Safe ActionPlan Validation and JSON Pointer Binding

**Files:**

- Create: `agent_core/src/main/ets/agent/action/ActionPlanTypes.ets`
- Create: `agent_core/src/main/ets/agent/action/JsonPointer.ets`
- Create: `agent_core/src/main/ets/agent/action/ActionPlanRunner.ets`
- Create: `entry/src/test/ActionPlanRunner.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: Write failing plan-structure tests**

Test rejection of:

- zero steps and more than five steps;
- empty or duplicate `stepId`;
- unknown action ID;
- a binding to the same/later/nonexistent step;
- pointer text that does not start with `/` (except an explicitly allowed empty pointer for the whole result);
- invalid JSON Pointer escape;
- any payload fields named `script`, `expression`, `loop`, `branches`, or `parallel`;
- first action not allowed by the current surface/source tool.

Use this valid fixture:

```ts
const plan: ActionPlan = {
  planId: 'plan-1',
  turnId: 'turn-1',
  surfaceId: 'surface-1',
  label: 'AI 回复并保存草稿',
  steps: [
    {
      stepId: 'draft',
      actionId: 'gmail.ai.reply.draft',
      args: { threadId: 'thread-real-1' }
    },
    {
      stepId: 'save',
      actionId: 'gmail.draft.create',
      args: {},
      inputFrom: [
        { target: '/to', stepId: 'draft', path: '/to' },
        { target: '/subject', stepId: 'draft', path: '/subject' },
        { target: '/body', stepId: 'draft', path: '/body' },
        { target: '/threadId', stepId: 'draft', path: '/threadId' }
      ]
    }
  ]
};
```

This fixture is a unit-level capability proof only. It must not send email.

- [ ] **Step 2: Write failing binding/execution tests**

Test:

- `~0`, `~1`, object keys, and array indexes follow RFC 6901 behavior;
- prior output fields bind into a cloned next-step args object;
- a missing path fails before the next action executes;
- a target overwrite works only at an explicit pointer;
- the complete bound args are revalidated before execution;
- wrong target type fails validation;
- executor failure or timeout result stops all later steps;
- successful steps are not rolled back.

- [ ] **Step 3: Run to verify failure**

Expected: missing plan runner and pointer resolver.

- [ ] **Step 4: Add declarative plan types**

```ts
export interface ActionInputBinding {
  target: string;
  stepId: string;
  path: string;
}

export interface ActionPlanStep {
  stepId: string;
  actionId: string;
  args?: Object;
  inputFrom?: ActionInputBinding[];
}

export interface ActionPlan {
  planId: string;
  turnId: string;
  surfaceId: string;
  label: string;
  steps: ActionPlanStep[];
}
```

Define explicit outcome types for `success`, `paused`, `canceled`, and `error`, including `failedStepId`, `errorCode`, and `message`. Do not represent outcomes as arbitrary strings.

- [ ] **Step 5: Implement a small RFC 6901 resolver/setter**

The resolver:

- accepts `''` as the whole document and `/...` as member traversal;
- decodes `~1` to `/` and `~0` to `~`;
- rejects other `~` escapes;
- supports non-negative canonical array indexes;
- never reads prototypes or executes getters supplied by text;
- returns a typed `{ ok, value, error }` result instead of throwing across Agent boundaries.

The setter writes into a deep JSON clone made with `JSON.parse(JSON.stringify(args))`; plans are already restricted to JSON-compatible data.

- [ ] **Step 6: Implement preflight and serial execution**

Preflight validates the whole structure, validates the first step against the exact source surface action, and validates every later step as a registered executable action through `ActionCatalog`. Runtime then executes in array order:

```ts
for (let index = 0; index < plan.steps.length; index++) {
  const step = plan.steps[index];
  const boundArgs = bindInputs(step, completedOutputs);
  const validation = catalog.validateExecution(context, step.actionId, boundArgs);
  if (!validation.ok) {
    return failedRun(step.stepId, validation.code, validation.message);
  }
  const result = await executor.execute(step.actionId, boundArgs, context);
  if (result.status !== 'success') {
    return stopFromResult(step.stepId, result);
  }
  completedOutputs.set(step.stepId, result.output);
}
```

The executor owns per-action timeout reporting. The runner fail-fasts on the first non-success result and does not add compensation behavior.

- [ ] **Step 7: Run tests and inspect the result file**

Expected: every malicious/invalid binding fails before executing its target step; valid output binding succeeds.

- [ ] **Step 8: Commit only this task**

```bash
git add \
  agent_core/src/main/ets/agent/action/ActionPlanTypes.ets \
  agent_core/src/main/ets/agent/action/JsonPointer.ets \
  agent_core/src/main/ets/agent/action/ActionPlanRunner.ets \
  entry/src/test/ActionPlanRunner.test.ets \
  entry/src/test/List.test.ets
git commit -m "feat: execute safe serial action plans"
```

---

## Task 7: Add Confirmation/Resume and the Action Agent Bus Role

**Files:**

- Create: `agent_core/src/main/ets/agent/action/ActionAgent.ets`
- Create: `agent_core/src/main/ets/agent/action/ActionAgentTypes.ets`
- Modify: `agent_core/src/main/ets/agent/action/ActionPlanRunner.ets`
- Modify: `agent_core/src/main/ets/agent/ui/UiAgent.ets`
- Modify: `agent_core/src/main/ets/agent/ui/UiAgentTypes.ets`
- Create: `entry/src/test/ActionAgent.test.ets`
- Modify: `entry/src/test/ActionPlanRunner.test.ets`
- Modify: `entry/src/test/UiAgent.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: Write failing confirmation-state tests**

Cover:

- `confirm_required` returns `paused` before the executor performs the risky action;
- paused state stores only plan/run IDs, next step index, prior structured outputs, and validated plan data;
- `ACTION.RUN` with matching `runId` and confirmed `stepId` resumes from that step;
- mismatched turn, surface, run, or step cannot resume;
- cancellation deletes paused state and emits canceled result;
- a resumed completed step is not executed twice.

- [ ] **Step 2: Write failing Action Agent bus tests**

Assert:

- `ACTION.PLAN.CREATE` returns `ACTION.PLAN.READY` only after preflight validation;
- invalid plans return a correlated action error;
- when a UI renderer proposes a composite affordance, UI Agent publishes `ACTION.PLAN.CREATE` and does not render that composite button until `ACTION.PLAN.READY`;
- `ACTION.PLAN.READY` for another conversation/turn/surface cannot authorize a button;
- the rendered `workflow.run` button carries only the ready `planId/runId` identity needed to select the already validated plan; modified inline steps are ignored/rejected;
- `ACTION.RUN` publishes progress for each step and one terminal `ACTION.RESULT`;
- normal read actions can return one typed follow-up containing a new `turnId`, `TASK.CREATE.UI`, and `TASK.CREATE.DATA`; Action Agent publishes both without calling either role;
- system intents run through the injected registered executor;
- UI Agent applies `ACTION.PROGRESS`/`ACTION.RESULT` only to the matching source turn and surface;
- no payload field is treated as code.

- [ ] **Step 3: Run to verify failure**

Expected: confirmation/resume and bus-role tests fail.

- [ ] **Step 4: Implement pause/resume in the runner**

Before executing a `confirm_required` action, return a paused state. On resume, Action Agent revalidates:

1. conversation, turn, surface, plan, run, and step identity;
2. the exact surface action is still authorized;
3. current args still pass validation;
4. confirmation has not been consumed already.

Then execute that step once and continue. A cancellation removes the paused run and emits no later progress.

- [ ] **Step 5: Implement Action Agent**

Action Agent subscribes directly to `ACTION.PLAN.CREATE`, `ACTION.RUN`, and `TURN.CANCEL`. It owns `Map<runId, PausedActionRun>` and publishes only typed action/UI/data messages to the bus.

Use an injected `RegisteredActionExecutor`:

```ts
export interface RegisteredActionExecutor {
  execute(
    actionId: string,
    args: Object,
    context: ActionExecutionContext
  ): Promise<ActionExecutionResult>;
}
```

`ActionExecutionResult` may contain one typed `followUp` with a newly allocated turn and paired UI/Data task descriptors. The Action Agent publishes those two messages back-to-back. It never receives a role instance or invokes UI/Data directly.

The entry adapter resolves action IDs through ActionCatalog immediately before invocation. There is no `eval`, shell, ArkTS generation, JS snippet, dynamic import, or file write path.

Update the UI renderer contract to return a typed `UiRenderResult` containing `jsonl` plus zero or more `ActionPlan` proposals. UI Agent publishes each proposal as `ACTION.PLAN.CREATE`, stores only its correlation, and renders the composite affordance only after consuming the exact `ACTION.PLAN.READY`. This keeps plan validation in Action Agent and button placement in UI Agent.

Action Agent stores the validated plan under its `planId`. A later `workflow.run` event selects that stored plan by the exact ready identity and surface correlation; it must not accept a replacement `steps` array from the click payload.

- [ ] **Step 6: Run tests and inspect the result file**

Expected: pause/resume/cancel and action bus integration tests pass.

- [ ] **Step 7: Commit only this task**

```bash
git add \
  agent_core/src/main/ets/agent/action/ActionAgent.ets \
  agent_core/src/main/ets/agent/action/ActionAgentTypes.ets \
  agent_core/src/main/ets/agent/action/ActionPlanRunner.ets \
  agent_core/src/main/ets/agent/ui/UiAgent.ets \
  agent_core/src/main/ets/agent/ui/UiAgentTypes.ets \
  entry/src/test/ActionAgent.test.ets \
  entry/src/test/ActionPlanRunner.test.ets \
  entry/src/test/UiAgent.test.ets \
  entry/src/test/List.test.ets
git commit -m "feat: add action agent confirmation flow"
```

---

## Task 8: Export the Runtime and Extend Static Architecture Verification

**Files:**

- Modify: `agent_core/Index.ets`
- Modify: `scripts/verify-loopy-backend.mjs`

- [ ] **Step 1: Add failing static assertions**

Extend `verifySourceContracts()` to read the new files and assert:

- all four role class names exist;
- all approved message strings exist;
- the envelope contains `conversationId`, `turnId`, and `taskId`;
- ActionPlan runner contains `MAX_ACTION_PLAN_STEPS = 5`;
- JSON Pointer resolver exists;
- Action Agent depends on `RegisteredActionExecutor`;
- no `BATCH_PENDING` exists in the new runtime;
- no new `Coordinator` class exists;
- public and runtime tool registries remain aligned.

Run:

```bash
node scripts/verify-loopy-backend.mjs
```

Expected: failure because exports/static checks have not yet been completed.

- [ ] **Step 2: Export the new public API**

Export message/data contracts, bus/reader, role interfaces/classes, ActionCatalog, ActionPlan types/runner, and Action Agent from `agent_core/Index.ets`. Do not export internal linked-list nodes or mutable role context classes.

- [ ] **Step 3: Complete the verifier assertions**

Keep assertions structural and narrow. Do not make the script compare large source snapshots or enforce formatting.

- [ ] **Step 4: Run the static verifier**

```bash
node scripts/verify-loopy-backend.mjs
```

Expected: all source checks pass and `agent_core.har` builds successfully.

- [ ] **Step 5: Commit only this task**

```bash
git add agent_core/Index.ets scripts/verify-loopy-backend.mjs
git commit -m "test: verify four agent runtime contracts"
```

---

## Task 9: Run the Strict Core Regression Gate

**Files:**

- Verify only; do not edit unless a new failure is caused by Tasks 1–8.

- [ ] **Step 1: Run all entry Hypium tests**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

- [ ] **Step 2: Read the authoritative test result**

```bash
sed -n '1,220p' entry/.test/default/intermediates/test/coverage_data/test_result.txt
```

Record total tests, failures, errors, and the names of any failures. If an unrelated baseline failure exists, prove it is unrelated; do not call the run PASS solely because the shell exited zero.

- [ ] **Step 3: Re-run architecture/HAR verification**

```bash
node scripts/verify-loopy-backend.mjs
```

- [ ] **Step 4: Scan for forbidden or incomplete implementation**

```bash
rg -n "TODO|FIXME|placeholder|BATCH_PENDING|class .*Coordinator|eval\\(|new Function|dynamic import" \
  agent_core/src/main/ets/agent \
  entry/src/test/AgentMessage.test.ets \
  entry/src/test/LinkedMessageBus.test.ets \
  entry/src/test/LeaderAgent.test.ets \
  entry/src/test/DataAgent.test.ets \
  entry/src/test/UiAgent.test.ets \
  entry/src/test/ActionCatalog.test.ets \
  entry/src/test/ActionPlanRunner.test.ets \
  entry/src/test/ActionAgent.test.ets
```

Expected: no implementation placeholder, batching mode, Coordinator, or code-evaluation path. A legitimate test description containing one of these words must be reviewed rather than blindly removed.

- [ ] **Step 5: Review scope and status**

```bash
git status --short
git diff --stat HEAD~8..HEAD
git diff --check HEAD~8..HEAD
```

Verify that unrelated user changes remain unstaged and untouched.

- [ ] **Step 6: Create a verification commit only if the gate required a scoped correction**

If no code changed, do not create an empty commit. If a regression fix was required, stage only its files and use:

```bash
git commit -m "fix: satisfy multi agent runtime regression gate"
```

---

## Completion Evidence

Before declaring this plan complete, report:

- the commit IDs for Tasks 1–8;
- Hypium totals from `test_result.txt`, not only the command exit status;
- `node scripts/verify-loopy-backend.mjs` result;
- tests proving cross-turn/cross-conversation isolation and data-before-UI behavior;
- tests proving unknown actions, later-step references, missing paths, wrong types, timeout, failure, confirmation mismatch, and cancellation all fail safely;
- confirmation that no product role directly holds another Agent instance;
- confirmation that no second action/tool registry or runtime code-generation path was introduced;
- any baseline failure as `PARTIAL` or `BLOCKED`, never silently as `PASS`.
