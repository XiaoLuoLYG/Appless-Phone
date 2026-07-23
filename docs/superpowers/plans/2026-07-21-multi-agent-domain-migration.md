# Multi-Agent Domain Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move every fixed and virtual product capability onto structured DataAgent or registered ActionAgent execution while preserving current renderers, interaction steps, provider truth, and safety states.

**Architecture:** Reuse each existing provider parser and A2UI renderer. For every read family, split the current combined function at its natural boundary: provider response becomes a domain object and `DataResult`, then the existing renderer consumes that same object. For actions, expand the existing registered executor boundary and call the current page/provider implementation with exact ActionOffer arguments.

**Tech Stack:** HarmonyOS ArkTS, Hypium, current `ToolGatewayClient`, existing domain A2UI renderers, `MultiAgentRuntime` from the foundation plan, Composio/MCP/API adapters, ActionCatalog/ActionPlanRunner.

## Global Constraints

- Execute this plan only after `2026-07-21-multi-agent-runtime-foundation.md` passes its completion gate.
- Keep `ToolDefinitionRegistry` as the only fixed capability authority: 46 fixed tools = 25 Data + 21 Action.
- No provider rewrite, new dependency, fake data, old-A2UI-inside-DataResult bridge, or cross-domain workflow product.
- An idempotent read may use its existing backend fallback; a write must never auto-retry or fall back to legacy.
- Exact UI button clicks keep original arguments and skip LLM planning.
- `gmail.message.send` becomes `confirm_required`, but the current mail reply UI and `sendConfiguredMailReply` path remain unchanged.
- Preserve existing manual-only, excluded-query, review-required, and safe-test-target boundaries.
- Do not touch unrelated working-tree changes or clean any worktree.

---

### Task 1: Add common DataResult constructors and structured gateway dispatch

**Files:**
- Create: `agent_core/src/main/ets/agent/message/DataResultFactory.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`
- Modify: `agent_core/Index.ets`
- Test: `entry/src/test/ToolGatewayClient.test.ets`
- Test: `entry/src/test/List.test.ets`

**Interfaces:**
- Produces: `successfulDataResult`, `partialDataResult`, `emptyDataResult`, `errorDataResult`, and `callStructuredTool(toolId, prompt, args)`.
- Consumes: existing `DataResult`, `DataSource`, tool definitions, and `callStructuredHotelTool`.

- [ ] **Step 1: Write failing envelope and dispatch tests**

```ts
const success = successfulDataResult('travel.search', 'travelOptions', { items: [] }, []);
expect(success.status).assertEqual('success');
expect(success.warnings.length).assertEqual(0);

const empty = emptyDataResult('food.search', 'foodChoices', [], 'No stores returned.');
expect(empty.status).assertEqual('empty');
expect(empty.warnings[0]).assertEqual('No stores returned.');

const rejected = await callStructuredTool('hotel.navigate', '', {});
expect(rejected.status).assertEqual('error');
expect(rejected.error?.code).assertEqual('TOOL_NOT_ALLOWED');
```

Also assert `hotel.search` still delegates to `callStructuredHotelTool` and preserves its source.

- [ ] **Step 2: Run Hypium and verify RED**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Expected: missing factory and structured gateway exports.

- [ ] **Step 3: Implement the shared constructors and fail-closed dispatcher**

```ts
export function successfulDataResult(
  toolId: string, outputSchema: string, data: Object, sources: DataSource[]
): DataResult {
  return { toolId, outputSchema, status: 'success', sources, data, warnings: [] };
}

export function errorDataResult(
  toolId: string, outputSchema: string, code: string, message: string,
  retryable: boolean = false, sources: DataSource[] = []
): DataResult {
  return {
    toolId, outputSchema, status: 'error', sources, data: {}, warnings: [],
    error: { code, message, retryable }
  };
}
```

Implement partial/empty with the same fixed fields. Add the initial dispatcher:

```ts
export async function callStructuredTool(
  toolId: string, prompt: string, args: Object | null
): Promise<DataResult> {
  const definition = toolDefinitionForToolId(toolId);
  if (definition === null || dataAgentToolDefinitions().every(
    (item: ToolDefinition): boolean => item.toolId !== toolId)) {
    return errorDataResult(toolId, definition === null ? '' : definition.outputSchema,
      'TOOL_NOT_ALLOWED', 'DataAgent cannot execute ' + toolId + '.');
  }
  if (toolId === 'hotel.search' || toolId === 'hotel.detail') {
    return callStructuredHotelTool(toolId, args);
  }
  return errorDataResult(toolId, definition.outputSchema,
    'STRUCTURED_ADAPTER_MISSING', 'Structured adapter is not migrated for ' + toolId + '.');
}
```

Do not call the legacy A2UI gateway for missing adapters.

- [ ] **Step 4: Run Hypium and verify the hotel adapter plus fail-closed path**

Expected: factory tests and current hotel tests pass; unsupported Data tools return `STRUCTURED_ADAPTER_MISSING` without provider execution.

- [ ] **Step 5: Commit the structured gateway base**

```bash
git add agent_core/src/main/ets/agent/message/DataResultFactory.ets \
  agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets agent_core/Index.ets \
  entry/src/test/ToolGatewayClient.test.ets entry/src/test/List.test.ets
git commit -m "feat: add structured tool gateway"
```

### Task 2: Migrate travel and food reads (Wave 1)

**Files:**
- Modify: `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/A2uiTypes.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/A2uiData.ets`
- Test: `entry/src/test/ToolGatewayClient.test.ets`
- Test: `entry/src/test/A2uiBusinessData.test.ets`
- Test: `entry/src/test/A2uiTrainOptionsState.test.ets`

**Interfaces:**
- Produces structured adapters for `travel.search`, `train.search`, `flight.search`, and `food.search`.
- Consumes current provider parsers, `A2uiTravelOptionData`, `A2uiTrainData`, `A2uiFlightData`, `A2uiFoodData`, and existing render functions.

- [ ] **Step 1: Write failing domain-result tests**

Use existing provider fixtures and assert:

```ts
const train = await callStructuredTool('train.search', '明晚六点后深圳北到香港西九龙', null);
expect(train.toolId).assertEqual('train.search');
expect(train.outputSchema).assertEqual('trains');
expect(JSON.stringify(train.data).indexOf('trainCode')).assertLarger(-1);
expect(train.sources.length > 0 || train.status === 'error').assertTrue();
expect(JSON.stringify(train.data).indexOf('updateComponents')).assertEqual(-1);
```

Add the same contract for travel, flight, and food. Provider-error fixtures must remain error/partial instead of synthetic empty success.

- [ ] **Step 2: Run Hypium and verify RED**

Expected: all four return `STRUCTURED_ADAPTER_MISSING`.

- [ ] **Step 3: Split provider result from rendering in the four existing functions**

Introduce domain payloads using existing data types:

```ts
export interface TravelStructuredData {
  title: string;
  summary: string;
  options: A2uiTravelOptionData[];
  rows: A2uiLabelValueData[];
}

export interface FoodStructuredData {
  title: string;
  summary: string;
  foods: A2uiFoodData[];
  rows: A2uiLabelValueData[];
}
```

Refactor `callLocalTravelSearch`, `callLocalTrainSearch`, `callLocalFlightSearch`, and `callLocalFoodSearch` so their provider work is performed by `callStructuredTravelTool`/`callStructuredFoodTool`; the legacy functions then pass `result.data` into the current `travelResultA2ui`, `trainResultA2ui`, `flightResultA2ui`, or `foodA2uiRenderState`. Do not parse rendered JSONL back into data.

Add exact dispatcher branches for the four tool IDs.

- [ ] **Step 4: Run Hypium and compare old/new renderer snapshots**

Expected: structured contracts pass; existing travel/train/flight/food snapshots and partial-provider tests remain unchanged.

- [ ] **Step 5: Commit Wave 1 travel/food adapters**

```bash
git add agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets \
  agent_core/src/main/ets/aiphone/runtime/A2uiTypes.ets \
  agent_core/src/main/ets/aiphone/runtime/A2uiData.ets \
  entry/src/test/ToolGatewayClient.test.ets \
  entry/src/test/A2uiBusinessData.test.ets entry/src/test/A2uiTrainOptionsState.test.ets
git commit -m "feat: structure travel and food data"
```

### Task 3: Migrate maps, media, social, and dynamic reads (Wave 1/2)

**Files:**
- Modify: `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/DynamicToolTypes.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/MediaVideoToolA2ui.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/SocialHubA2ui.ets`
- Test: `entry/src/test/MapsApiClient.test.ets`
- Test: `entry/src/test/MediaVideoToolA2ui.test.ets`
- Test: `entry/src/test/AggregateSearchA2ui.test.ets`
- Test: `entry/src/test/SocialHubA2ui.test.ets`
- Test: `entry/src/test/DynamicToolDiscovery.test.ets`

**Interfaces:**
- Produces structured adapters for `maps.place.search/details`, `media.video.search`, `media.aggregate.search`, `youtube.video.search`, `x.post.search`, `social.feed.search`, and safe `dynamic.search` reads.
- Consumes existing `DynamicGenericToolResult`, SocialHub items/connections, map place records, and media result arrays.

- [ ] **Step 1: Write failing source/ID/dynamic-safety tests**

```ts
const places = await callStructuredTool('maps.place.search', 'King Cross Chinese food', args);
expect(JSON.stringify(places.data).indexOf('placeId')).assertLarger(-1);

const aggregate = await callStructuredTool('media.aggregate.search', 'Codex', args);
expect(aggregate.status === 'success' || aggregate.status === 'partial' || aggregate.status === 'error').assertTrue();

const unsafe = await callStructuredTool('dynamic.search', 'delete a page', {
  operation: 'execute', toolSlug: 'notion_delete_page', arguments: {}
});
expect(unsafe.error?.code).assertEqual('DYNAMIC_WRITE_NOT_ALLOWED');
```

Assert a dynamic discovered registration is scoped to the current turn and preserves provider/qualifiedName/schema/receipt metadata.

- [ ] **Step 2: Run Hypium and verify RED**

Expected: structured branches are missing; unsafe dynamic execution is not yet enforced at the DataAgent boundary.

- [ ] **Step 3: Return current normalized objects before A2UI conversion**

Use one shared data shape already present in this family:

```ts
export interface GenericStructuredData {
  results: DynamicGenericToolResult[];
}
```

For SocialHub use its existing typed item/connection object, not generic rows. For Maps preserve the native place records and real `placeId`. Convert provider failures to partial only when at least one source succeeded. Add `dynamic.search` authorization that accepts only operations whose normalized verb is `read/search/list/get`; return `DYNAMIC_WRITE_NOT_ALLOWED` before provider execution for all others.

Legacy A2UI functions must consume the same structured object; no JSONL round-trip.

- [ ] **Step 4: Run Hypium and verify current multi-source and action snapshots**

Expected: C04/C07/C08/C09/C10/C13 family fixtures pass, real IDs remain in data, dynamic writes fail closed, existing open/reply actions remain unchanged.

- [ ] **Step 5: Commit maps/media/social/dynamic adapters**

```bash
git add agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets \
  agent_core/src/main/ets/aiphone/runtime/DynamicToolTypes.ets \
  agent_core/src/main/ets/aiphone/runtime/MediaVideoToolA2ui.ets \
  agent_core/src/main/ets/aiphone/runtime/SocialHubA2ui.ets \
  entry/src/test/MapsApiClient.test.ets \
  entry/src/test/MediaVideoToolA2ui.test.ets entry/src/test/AggregateSearchA2ui.test.ets \
  entry/src/test/SocialHubA2ui.test.ets entry/src/test/DynamicToolDiscovery.test.ets
git commit -m "feat: structure maps media and social data"
```

### Task 4: Migrate mail, Gmail, YouTube account, Calendar read, Luckin status, and ride reads (Wave 2)

**Files:**
- Modify: `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/GmailToolA2ui.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/MailToolA2ui.ets`
- Test: `entry/src/test/GmailToolNormalizer.test.ets`
- Test: `entry/src/test/GmailToolA2ui.test.ets`
- Test: `entry/src/test/MailToolA2ui.test.ets`
- Test: `entry/src/test/YouTubeApiClient.test.ets`
- Test: `entry/src/test/CalendarApiClient.test.ets`
- Test: `entry/src/test/RideToolResultsState.test.ets`

**Interfaces:**
- Produces remaining DataAgent adapters: `mail.search`, `mail.thread.read`, `gmail.mail.search`, `gmail.thread.read`, `youtube.mine.playlists`, `youtube.mine.subscriptions`, `calendar.events.search`, `luckin.order.status`, `ride.estimate`, `ride.app.link`, and `ride.driver.location`.
- Consumes current normalized mail threads, Gmail results, account results, calendar events, Luckin orders, and ride data.

- [ ] **Step 1: Write failing real-entity and auth-state tests**

```ts
const thread = await callStructuredTool('gmail.thread.read', '', { threadId: 'thread-real-1' });
expect(JSON.stringify(thread.data).indexOf('thread-real-1')).assertLarger(-1);

const auth = await callStructuredTool('youtube.mine.playlists', '', {});
expect(auth.status === 'success' || auth.error?.code === 'AUTH_REQUIRED').assertTrue();

const calendar = await callStructuredTool('calendar.events.search', '', { query: 'QA' });
expect(JSON.stringify(calendar.data).indexOf('updateComponents')).assertEqual(-1);
```

Mail summary-only fixtures must not satisfy a thread-body read.

- [ ] **Step 2: Run Hypium and verify RED**

Expected: remaining tools return `STRUCTURED_ADAPTER_MISSING`.

- [ ] **Step 3: Expose the existing normalized provider outputs**

Use `DynamicGenericToolResult[]` only where it is already the current canonical result. Gmail and aggregate mail must keep provider/messageId/threadId/requestKey/to/subject/body fields. Calendar must keep eventId. Ride and Luckin must keep orderId/traceId/provider IDs.

Map missing credentials and Composio disconnected state to:

```ts
errorDataResult(toolId, outputSchema, 'AUTH_REQUIRED', providerMessage, false, sources)
```

Map real no-results to `emptyDataResult`, not auth or success with invented rows. Add the exact dispatcher branches for every tool named in this task.

- [ ] **Step 4: Run Hypium and verify C05/C06/C09/F10/F11 contracts**

Expected: real entity IDs survive; body reads remain distinct from summaries; auth/no-config/error/empty are distinguishable; legacy renderers still pass snapshots.

- [ ] **Step 5: Commit account and remaining read adapters**

```bash
git add agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets \
  agent_core/src/main/ets/aiphone/runtime/GmailToolA2ui.ets \
  agent_core/src/main/ets/aiphone/runtime/MailToolA2ui.ets \
  entry/src/test/GmailToolNormalizer.test.ets entry/src/test/GmailToolA2ui.test.ets \
  entry/src/test/MailToolA2ui.test.ets entry/src/test/YouTubeApiClient.test.ets \
  entry/src/test/CalendarApiClient.test.ets entry/src/test/RideToolResultsState.test.ets
git commit -m "feat: structure account and remaining read data"
```

### Task 5: Add the generic structured renderer and action-offer resolver

**Files:**
- Create: `entry/src/main/ets/pages/A2uiHome/agent/StructuredToolUiRenderer.ets`
- Create: `entry/src/main/ets/pages/A2uiHome/agent/RegisteredActionOfferResolver.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntime.ets`
- Test: `entry/src/test/UiAgent.test.ets`
- Create: `entry/src/test/StructuredToolUiRenderer.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Interfaces:**
- Produces: one `UiTaskRenderer` for all structured tool families and one registry-backed `ActionOfferResolver`.
- Consumes: existing domain A2UI functions, `DataResult[]`, component catalog, `ActionCatalog`, and `A2uiAgentRunner`.

- [ ] **Step 1: Write failing render/offer compatibility tests**

For one fixture from every family, compare the current canonical rows/actions with the new renderer. At minimum assert:

```ts
const rendered = await renderer.result(task, [travelResult, trainResult], offers, 'surface-1');
expect(rendered.jsonl.indexOf('travelOptions')).assertLarger(-1);
expect(rendered.jsonl.indexOf('trainOptions')).assertLarger(-1);

const forged = await resolver.resolve(result, context);
expect(forged.every((offer: ActionOffer): boolean =>
  catalog.validatePlacement(result.toolId, offer.actionId, offer.args).ok)).assertTrue();
```

Assert the LLM layout path and deterministic fallback both retain the same action arguments.

- [ ] **Step 2: Run Hypium and verify RED**

Expected: no generic renderer/resolver exists.

- [ ] **Step 3: Dispatch to existing renderers by outputSchema**

Use a single `switch (data.outputSchema)` in `StructuredToolUiRenderer`; do not add one class per domain. Each branch calls the existing renderer with `data.data` and the immutable offers. Unknown schemas return an error surface instead of generic JSON dumping.

The resolver iterates `toolDefinitionForToolId(data.toolId)?.actions`, builds candidates only from real data fields, and calls `ActionCatalog.validatePlacement` before returning them. The UI receives only offer IDs/labels/variants in its prompt; merger binds the protected args.

- [ ] **Step 4: Run Hypium and verify all existing renderer snapshots**

Expected: current C/F cards and buttons match; LLM invalid output uses the baseline; wrong offers are absent; data-first/UI-first and reverse-arrival tests pass.

- [ ] **Step 5: Commit renderer and offer integration**

```bash
git add entry/src/main/ets/pages/A2uiHome/agent/StructuredToolUiRenderer.ets \
  entry/src/main/ets/pages/A2uiHome/agent/RegisteredActionOfferResolver.ets \
  entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntime.ets \
  entry/src/test/UiAgent.test.ets entry/src/test/StructuredToolUiRenderer.test.ets \
  entry/src/test/List.test.ets
git commit -m "feat: render structured multi-agent results"
```

### Task 6: Expand registered execution for drafts, previews, system intents, and Web sessions (Wave 3)

**Files:**
- Rename: `entry/src/main/ets/pages/A2uiHome/agent/HotelRegisteredActionExecutor.ets` to `entry/src/main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntime.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/Index.ets`
- Rename: `entry/src/test/HotelRegisteredActionExecutor.test.ets` to `entry/src/test/AiphoneRegisteredActionExecutor.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Interfaces:**
- Produces: one `RegisteredActionExecutor` for all 21 fixed Action tools plus current registered client-facing offers.
- Consumes: existing page callbacks, `callToolGateway`, hotel URI opener, payment/ride/luckin handlers, and current system/Web overlay code.

- [ ] **Step 1: Write failing exact-action tests**

Cover one exact action in each class:

```ts
await executor.execute('hotel.navigate', navigateArgs, context);
await executor.execute('hotel.booking.open', bookingArgs, context);
await executor.execute('gmail.draft.create', draftArgs, context);
await executor.execute('payment.send', paymentArgs, context);
await executor.execute('maps.route.open', routeArgs, context);
```

Assert each calls only its existing handler, preserves args, and returns an `ActionExecutionResult`. Assert unknown actions and source-surface mismatches fail before callback invocation.

- [ ] **Step 2: Run Hypium and verify RED**

Expected: current executor handles hotel actions only.

- [ ] **Step 3: Rename and extend the current executor rather than creating a parallel executor**

Inject the existing page behavior through one narrow callback:

```ts
export type RegisteredPageAction = (
  actionId: string, args: Object, context: ActionExecutionContext
) => Promise<ActionExecutionResult>;
```

Keep hotel navigation/booking code intact. For the other fixed Action tools, validate with ActionCatalog then call the existing `Index.ets` behavior through `RegisteredPageAction`. Client-only sort/filter/expand/back actions remain in `handleClientAction` and do not enter this executor.

- [ ] **Step 4: Run Hypium and verify current confirmation/UI behavior**

Expected: C12/C15-C18/C20 and F05-F08 fixtures preserve current action args and visible interaction; no action is executed twice or auto-confirmed.

- [ ] **Step 5: Commit the registered action expansion**

```bash
git add entry/src/main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor.ets \
  entry/src/main/ets/pages/A2uiHome/agent/MultiAgentRuntime.ets \
  entry/src/main/ets/pages/A2uiHome/Index.ets \
  entry/src/test/AiphoneRegisteredActionExecutor.test.ets entry/src/test/List.test.ets
git rm entry/src/main/ets/pages/A2uiHome/agent/HotelRegisteredActionExecutor.ets \
  entry/src/test/HotelRegisteredActionExecutor.test.ets
git commit -m "feat: register product action execution"
```

### Task 7: Migrate Gmail reply sending without changing the mail UI

**Files:**
- Modify: `agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets`
- Modify: `agent_core/src/main/ets/aiphone/LoopBackend.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/Index.ets`
- Modify: `entry/src/test/ToolDefinitionRegistry.test.ets`
- Modify: `entry/src/test/HtmlHomeActionPolicy.test.ets`
- Modify: `entry/src/test/MailToolA2ui.test.ets`
- Modify: `entry/src/test/AiphoneRegisteredActionExecutor.test.ets`

**Interfaces:**
- Produces: `gmail.message.send` as a confirm-required registered Action backed by existing `sendConfiguredMailReply`.
- Consumes: current `html_mail_reply_send`, `mailReplySubmissionAllowed`, `MailReplyCommand`, and `MailReplyUiEvent`.

- [ ] **Step 1: Write failing current-surface send tests**

```ts
expect(toolDefinitionForToolId('gmail.message.send')?.riskLevel)
  .assertEqual('confirm_required');

const action = visibleMailReplySendAction('thread-1', 'message-1', 'alice@example.com', 'Reply');
expect(mailReplySubmissionAllowed(block, action)).assertTrue();
const result = await executor.execute('gmail.message.send', action.args as Object, context);
expect(result.status).assertEqual('success');
expect(sendCalls).assertEqual(1);
```

Assert changed thread/message/requestKey/to/body, stale surface, non-button natural-language send, and replayed runId are rejected. Assert no second confirmation overlay appears.

- [ ] **Step 2: Run Hypium and verify RED**

Expected: registry risk is `blocked` and the registered executor lacks send.

- [ ] **Step 3: Reuse the existing reply path exactly**

Change only the fixed definition:

```ts
{
  toolId: 'gmail.message.send',
  domain: 'gmail',
  intent: 'gmail.message.send',
  riskLevel: 'confirm_required',
  backendPriority: ['oauth_api'],
  authModes: ['oauth'],
  inputSchema: 'mailReplyCommand',
  outputSchema: 'mailReplyOperationResult',
  a2uiComponent: 'GenericToolResults',
  actions: []
}
```

Keep the visible `html_mail_reply_send` offer ID, label, composer, AI-reply, and exact-args policy unchanged. The registered executor calls `sendConfiguredMailReply`; Gmail-provider commands are audited as the canonical `gmail.message.send` capability, while the existing QQ/IMAP branch remains the same client action instead of being mislabeled as Gmail. Translate the real result into ActionExecutionResult plus the existing `MailReplyUiEvent`. Remove the legacy “blocked safety fallback” description for the Gmail tool; keep draft-first instructions for new unbound compose requests.

- [ ] **Step 4: Run Hypium and verify send compatibility**

Expected: the current search→body→reply→AI reply→send state machine is unchanged; exact button sends once; unsafe direct text does not send; fixed blocked count is zero.

- [ ] **Step 5: Commit Gmail send migration**

```bash
git add agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets \
  agent_core/src/main/ets/aiphone/LoopBackend.ets \
  entry/src/main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor.ets \
  entry/src/main/ets/pages/A2uiHome/Index.ets \
  entry/src/test/ToolDefinitionRegistry.test.ets \
  entry/src/test/HtmlHomeActionPolicy.test.ets entry/src/test/MailToolA2ui.test.ets \
  entry/src/test/AiphoneRegisteredActionExecutor.test.ets
git commit -m "feat: migrate confirmed gmail reply send"
```

### Task 8: Migrate reversible and manual-only writes (Wave 4)

**Files:**
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/RegisteredActionOfferResolver.ets`
- Modify: `entry/src/test/AiphoneRegisteredActionExecutor.test.ets`
- Modify: `entry/src/test/ActionAgent.test.ets`
- Modify: `entry/src/test/CalendarApiClient.test.ets`
- Modify: `docs/current-capabilities.md`

**Interfaces:**
- Produces: complete fixed Action coverage and explicit manual-only fail-closed behavior.
- Consumes: current Calendar, Luckin, Payment, WhatsApp, Ride, work-item, and knowledge prepare/confirm handlers.

- [ ] **Step 1: Write failing action-coverage and reversible-write tests**

Assert every `actionAgentToolDefinitions()` ID has an executor route. Add Calendar QA flow with a real fixture event ID:

```ts
const created = await executor.execute('calendar.event.create', createArgs, context);
const eventId = outputString(created, 'eventId');
expect(eventId.length > 0).assertTrue();
await executor.execute('calendar.event.update', { eventId, start: '16:00' }, context);
await executor.execute('calendar.event.delete', { eventId }, context);
```

Use fake provider adapters in Hypium. Assert Luckin create, payment confirm, WhatsApp confirm, ride create/cancel, and work/knowledge writes reject when safe target or confirmation is absent.

- [ ] **Step 2: Run Hypium and verify RED**

Expected: uncovered fixed Action IDs and inconsistent manual-only failures are reported.

- [ ] **Step 3: Complete explicit routes without generic write discovery**

Add exact executor branches only for the 20 fixed definitions. Review-required work/knowledge actions remain their current preview/prepare client actions until promoted to fixed ToolDefinitions; do not execute discovered writes through `dynamic.search`.

Every external write branch must return a real receipt/status or an error. Preserve Calendar eventId across update/delete and stop the plan on error/cancel. Update `docs/current-capabilities.md` with `migrated owner`, `automation state`, and `confirmation` for each capability.

- [ ] **Step 4: Run the complete domain gate**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
tail -5 entry/.test/default/intermediates/test/coverage_data/test_result.txt
node scripts/verify-loopy-backend.mjs
node ~/.codex/skills/appless-device-regression/scripts/audit-coverage.mjs \
  --repo /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo
```

Expected: Hypium zero failure/error; verifier PASS; capability audit has no missing registry/matrix/docs entries.

- [ ] **Step 5: Commit complete domain ownership**

```bash
git add entry/src/main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor.ets \
  entry/src/main/ets/pages/A2uiHome/agent/RegisteredActionOfferResolver.ets \
  entry/src/test/AiphoneRegisteredActionExecutor.test.ets \
  entry/src/test/ActionAgent.test.ets entry/src/test/CalendarApiClient.test.ets \
  docs/current-capabilities.md
git commit -m "feat: complete multi-agent action ownership"
```

## Domain Migration Completion Gate

- Every one of the 25 Data tools returns a real structured `DataResult`; no adapter returns A2UI as data.
- Every one of the 20 fixed Action tools has one registered executor route and exact confirmation behavior.
- `dynamic.search` executes only turn-scoped safe reads; `memory.update` is Action-owned.
- Existing renderer snapshots and interaction sequences pass for all C/F/R families.
- `gmail.message.send` is confirm-required and reuses the current exact reply UI/executor.
- Manual-only/review-required writes fail closed without safe targets and explicit confirmation.
- Legacy remains available only for whole-turn handoff; final deletion belongs to the cutover plan.
