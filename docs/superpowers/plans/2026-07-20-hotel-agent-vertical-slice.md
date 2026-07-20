# Hotel Multi-Agent Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route hotel search and hotel result actions through the new Leader/Data/UI/Action runtime, using real RollingGo search/rates, optional uniquely matched Google Places phone data, conditional call/navigation buttons, and registered system-intent execution.

**Architecture:** A model-backed Hotel Leader planner extracts and validates one real `hotel.search` request, then the generic Leader publishes UI and Data tasks through the shared bus. The Data adapter returns a structured `DataResult` from RollingGo and performs best-effort Google Places contact enrichment without flattening data into A2UI. Hotel UI rendering remains deterministic and is performed only by UI Agent. Every hotel button is registered in the existing tool registry, authorized against the exact current surface, and executed by Action Agent; detail starts a new paired UI/Data turn, navigation opens a Petal Maps URI, and call opens a validated `tel:` URI without dialing automatically.

**Tech Stack:** ArkTS, HarmonyOS A2UI v0.9.1, `@ohos/hypium`, existing `ToolGatewayClient`, `GenericMcpClient`, RollingGo MCP, Google Places API, Petal Maps URI, `ohos.want.action.viewData`, existing HTML home renderer/action policy, DevEco `hvigor`, HDC device smoke tooling.

## Global Constraints

- Complete `2026-07-20-multi-agent-runtime-action-plan.md` first. This plan consumes its bus, agents, `DataResult`, ActionCatalog, and Action Agent contracts.
- Preserve unrelated working-tree edits. Stage only files named in each task.
- RollingGo currently proves only `searchHotels`, `getHotelDetail`, and `getHotelSearchTags`. Do not add `hotel.book`, booking create/status/cancel, order IDs, confirmation cards, or success language.
- Preserve real `hotelId`, `destinationId`, `ratePlanId`, place ID, provider identity, query dates, occupancy, and currency through every later action.
- `bookingUrl` remains a third-party source fact, not an Appless transaction capability or action.
- Phone data comes only from the configured real place provider. No fixture, guessed number, hotel-name lookup table, generated phone, or same-name merge is allowed in product runtime.
- A call button exists only when one candidate passes strict identity matching and Place Details returns a valid phone. Missing configuration, zero matches, ambiguous matches, missing phone, or lookup error means no call button.
- A navigation button exists only for finite coordinates inside latitude/longitude bounds. Do not interpret normalized missing values as `(0, 0)`.
- `hotel.call` opens the system dialer with a prefilled number. It must not request direct-call permission or claim the call was placed.
- `hotel.navigate` reuses `buildSystemFoodNavigationUri`; do not add another map URI library.
- UI Agent is the only surface writer. Provider and action adapters return structured values/messages.
- Action Agent executes only the registered `hotel.detail`, `hotel.navigate`, and `hotel.call` actions. It does not generate code.
- Keep the migration branch hotel-only. Non-hotel requests continue through the existing `submitPrompt` path until separately migrated.
- Do not add a permanent feature-flag framework. Use one explicit hotel routing predicate that can be deleted after all scenes migrate.
- Never log API keys or complete private payloads. Log correlation IDs, provider/tool IDs, status, and bounded error summaries.
- Add all new Hypium suites to `entry/src/test/List.test.ets`.
- For strict test claims, inspect `entry/.test/default/intermediates/test/coverage_data/test_result.txt`.
- Product commits must exclude `docs/superpowers/**`, `.superpowers/**`, `tool-gateway/.env.local`, provider config, smoke artifacts, and generated HAP/HAR files.
- `scripts/aiphone-device-smoke.mjs` already had unrelated uncommitted edits when this plan was written. Before Task 6, inspect that pre-existing diff, merge around it, and use `git add -p scripts/aiphone-device-smoke.mjs` so the hotel commit does not absorb unrelated hunks.

---

## Task 1: Separate Structured Hotel Data from A2UI Rendering

**Files:**

- Create: `agent_core/src/main/ets/aiphone/runtime/HotelDataResult.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`
- Modify: `agent_core/Index.ets`
- Create: `entry/src/test/HotelDataResult.test.ets`
- Modify: `entry/src/test/ToolGatewayClient.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: Write failing structured-result tests**

Create fixtures from the existing real-shape RollingGo search/detail payloads. Assert:

- successful search returns `toolId='hotel.search'`, `outputSchema='hotelSearchResults'`, a RollingGo `DataSource`, and an unflattened `HotelSearchResult` in `data`;
- zero hotels returns `empty`, not error;
- successful detail returns `hotelRatePlans`, real `hotelId` and `ratePlanId`;
- missing provider config and transport/inner provider errors return `error`;
- no function in `HotelDataResult.ets` returns A2UI JSONL or `DynamicGenericToolResult`.

Add a gateway test that an unknown hotel-prefixed tool is rejected rather than falling through to the detail path.

- [ ] **Step 2: Run tests to verify failure**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Expected: compile/test failure because structured hotel conversion and gateway entry do not exist.

- [ ] **Step 3: Implement pure `DataResult` conversion**

```ts
export function hotelSearchDataResult(
  result: HotelSearchResult,
  sources: DataSource[],
  warnings: string[] = []
): DataResult {
  return {
    toolId: 'hotel.search',
    outputSchema: 'hotelSearchResults',
    status: result.ok ? (result.hotels.length > 0 ?
      (warnings.length > 0 ? 'partial' : 'success') : 'empty') : 'error',
    sources: sources,
    data: result,
    warnings: warnings,
    error: result.ok ? undefined : {
      code: 'HOTEL_PROVIDER_ERROR',
      message: result.error,
      retryable: true
    }
  };
}
```

Add the equivalent detail converter. The source timestamp is created at the provider boundary, not guessed in tests. Keep provider data as the existing domain type.

- [ ] **Step 4: Add a structured provider entry in `ToolGatewayClient`**

Export:

```ts
export async function callStructuredHotelTool(
  toolId: string,
  args: Object | null
): Promise<DataResult>
```

Implementation rules:

1. accept only exact `hotel.search` or `hotel.detail`;
2. use the current ignored local RollingGo URL/key configuration;
3. use the existing `hotelMcpRegistration`, `GenericMcpClient`, request parsers, provider arg builders, and normalizers;
4. return structured errors instead of A2UI;
5. report provider operation as `searchHotels` or `getHotelDetail`;
6. apply the existing provider timeout; do not add retry logic.

Refactor `callLocalHotelTool()` to call this function and then invoke existing `hotelSearchA2ui`, `hotelDetailA2ui`, or `hotelFailureA2ui`. This preserves the old route while making the Data Agent seam real.

- [ ] **Step 5: Run tests and inspect `test_result.txt`**

Expected: structured and legacy A2UI paths both pass; existing hotel rendering output is unchanged.

- [ ] **Step 6: Commit only this task**

```bash
git add \
  agent_core/src/main/ets/aiphone/runtime/HotelDataResult.ets \
  agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets \
  agent_core/Index.ets \
  entry/src/test/HotelDataResult.test.ets \
  entry/src/test/ToolGatewayClient.test.ets \
  entry/src/test/List.test.ets
git commit -m "refactor: expose structured hotel provider data"
```

---

## Task 2: Add Strict Real Hotel Contact Enrichment

**Files:**

- Create: `agent_core/src/main/ets/aiphone/runtime/HotelContactLookup.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/HotelToolTypes.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/MapsApiClient.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`
- Modify: `agent_core/Index.ets`
- Create: `entry/src/test/HotelContactLookup.test.ets`
- Modify: `entry/src/test/HotelToolTypes.test.ets`
- Modify: `entry/src/test/MapsApiClient.test.ets`
- Modify: `entry/src/test/HotelDataResult.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: Write failing normalization/matching tests**

Use provider-shaped JSON fixtures and cover:

- exact normalized Chinese or English hotel name plus matching address accepts one candidate;
- exact name plus coordinates within 300 meters accepts one candidate;
- name-only match is rejected;
- two accepted candidates are ambiguous and rejected;
- wrong address and distant coordinates are rejected;
- missing place ID is rejected;
- details with `internationalPhoneNumber` produce preferred dial/display fields;
- details with only `nationalPhoneNumber` are retained;
- details with neither phone field return no contact;
- place provider errors produce a warning without changing `HotelSearchResult.ok`;
- missing Google Maps key produces no contact and a bounded warning;
- the RollingGo hotel ID is unchanged after enrichment.

- [ ] **Step 2: Run tests to verify failure**

Expected: missing contact types and lookup functions.

- [ ] **Step 3: Make missing coordinates explicit**

Change `HotelSearchItem.latitude` and `.longitude` from fabricated numeric zero defaults to `number | null`, using the existing `optionalNumberOf()` normalization. Update existing tests to assert missing coordinates remain `null`.

Add:

```ts
export interface HotelContact {
  displayPhone: string;
  dialPhone: string;
  provider: string;
  providerPlaceId: string;
}

export interface HotelSearchItem {
  hotelId: number;
  name: string;
  nameEn: string;
  address: string;
  latitude: number | null;
  longitude: number | null;
  contact?: HotelContact;
}
```

Do not add a placeholder contact object.

- [ ] **Step 4: Implement strict pure matching**

`HotelContactLookup.ets` receives normalized Places search candidates and the RollingGo hotel. A candidate qualifies only if:

1. normalized display name exactly equals normalized `name` or `nameEn`; and
2. either both valid coordinates are within 300 meters, or normalized non-trivial addresses contain one another; and
3. it has a non-empty real Place ID.

Return a match only when exactly one candidate qualifies. Use a small local Haversine function; do not introduce a geo package. Treat punctuation/whitespace/case normalization as identity normalization, not fuzzy similarity.

- [ ] **Step 5: Add structured Google Places calls**

Keep existing map search/detail UI functions intact. Add structured functions for hotel contact lookup:

```ts
export async function callHotelContactLookup(
  hotel: HotelSearchItem,
  apiKey: string
): Promise<HotelContactLookupResult>
```

Use Text Search fields only for candidate identity:

```text
places.id
places.displayName
places.formattedAddress
places.location
```

After one unique match, call Place Details with:

```text
id
displayName
formattedAddress
location
nationalPhoneNumber
internationalPhoneNumber
```

Use the existing `requestJson()` transport. Do not request phone fields for every raw candidate and do not accept a phone before unique identity matching.

- [ ] **Step 6: Enrich successful hotel search in the structured gateway**

After RollingGo search succeeds, call contact lookup for the returned hotel records. Preserve all RollingGo records even if any lookup fails. Add contacts only to matching records and collapse repeated lookup problems into bounded warnings.

Status rules:

- RollingGo success + all requested contact lookups complete without warnings → `success` or `empty`;
- RollingGo success + any missing config/provider/ambiguity/error warning → `partial`;
- RollingGo failure → `error`, with no Places call masking it.

Include Google Places in `sources` only when a real Places response was received; never claim it as a source from a missing key.

- [ ] **Step 7: Run tests and inspect the real result file**

Expected: all strict-match and partial-degradation cases pass. Confirm no test fixture phone can enter product runtime.

- [ ] **Step 8: Commit only this task**

```bash
git add \
  agent_core/src/main/ets/aiphone/runtime/HotelContactLookup.ets \
  agent_core/src/main/ets/aiphone/runtime/HotelToolTypes.ets \
  agent_core/src/main/ets/aiphone/runtime/MapsApiClient.ets \
  agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets \
  agent_core/Index.ets \
  entry/src/test/HotelContactLookup.test.ets \
  entry/src/test/HotelToolTypes.test.ets \
  entry/src/test/MapsApiClient.test.ets \
  entry/src/test/HotelDataResult.test.ets \
  entry/src/test/List.test.ets
git commit -m "feat: enrich hotels with verified contact data"
```

---

## Task 3: Register and Render Only Truthful Hotel Actions

**Files:**

- Create: `agent_core/src/main/ets/aiphone/runtime/HotelActions.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/HotelToolA2ui.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets`
- Modify: `agent_core/src/main/ets/aiphone/AiphoneToolDefinitions.ets`
- Modify: `agent_core/src/main/ets/aiphone/LoopBackend.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`
- Modify: `agent_core/Index.ets`
- Modify: `entry/src/test/HotelToolA2ui.test.ets`
- Modify: `entry/src/test/ToolDefinitionRegistry.test.ets`
- Modify: `entry/src/test/ToolGatewayClient.test.ets`

- [ ] **Step 1: Write failing action-registry tests**

Update the hotel registry expectations:

```ts
expect(search.actions.join(',')).assertEqual(
  'hotel.detail,hotel.navigate,hotel.call'
);
expect(toolDefinitionForToolId('hotel.navigate')?.backendPriority[0])
  .assertEqual('system_intent');
expect(toolDefinitionForToolId('hotel.call')?.riskLevel)
  .assertEqual('draft');
expect(toolDefinitionForToolId('hotel.book')).assertEqual(null);
```

Also assert public/runtime registries stay aligned and `hotel.create/status/cancel` remain absent.

- [ ] **Step 2: Write failing conditional A2UI tests**

For one hotel fixture with real ID, coordinates, and verified contact, assert exact actions/args:

- `hotel.detail` preserves the original query;
- `hotel.navigate` carries the real hotel ID/name/address/coordinates;
- `hotel.call` carries the real hotel ID, dial/display phone, provider, and place ID.

Add separate fixtures proving:

- no coordinates → no navigate action;
- no contact → no call action;
- no valid hotel ID → no hotel actions;
- ActionCatalog placement denial → the denied candidate is absent even when its data fields exist;
- no output contains `hotel.book`, booking success, or order ID.

- [ ] **Step 3: Run tests to verify failure**

Expected: missing definitions/action builders and old action list mismatch.

- [ ] **Step 4: Add pure action args and validation**

In `HotelActions.ets`, define `HotelNavigateArgs`, `HotelCallArgs`, and validators. Coordinate validation requires finite latitude `[-90, 90]` and longitude `[-180, 180]`. Dial args require a positive `hotelId`, non-empty provider Place ID, and a safe provider-returned phone string.

Build actions only from `HotelSearchItem`:

```ts
export function hotelActionsFor(
  hotel: HotelSearchItem,
  request: HotelSearchRequest,
  canPlace: (action: A2uiAction) => boolean
): A2uiAction[] {
  const actions: A2uiAction[] = [];
  if (hotel.hotelId > 0) {
    const detail = hotelDetailAction(hotel, request);
    if (canPlace(detail)) {
      actions.push(detail);
    }
  }
  if (hasValidHotelCoordinates(hotel)) {
    const navigate = hotelNavigateAction(hotel);
    if (canPlace(navigate)) {
      actions.push(navigate);
    }
  }
  if (hotel.contact !== undefined && validHotelCallArgs(hotelCallArgs(hotel)).ok) {
    const call = hotelCallAction(hotel);
    if (canPlace(call)) {
      actions.push(call);
    }
  }
  return actions;
}
```

`HotelToolA2ui` uses only this function and requires a placement callback. The new UI Agent adapter supplies `ActionCatalog` placement validation; the preserved legacy gateway supplies an adapter over the same current registry and hotel arg validators. Include the contact provider/place ID in action args, not a guessed UI row.

- [ ] **Step 5: Add the two current registry definitions**

Register:

```text
hotel.navigate
  riskLevel=read
  backendPriority=[system_intent]
  authModes=[system]
  inputSchema=hotelNavigateRequest
  outputSchema=systemIntentResult

hotel.call
  riskLevel=draft
  backendPriority=[system_intent]
  authModes=[system]
  inputSchema=hotelCallRequest
  outputSchema=systemIntentResult
```

Set `hotel.search.actions` to the three verified actions. Both system-intent definitions have no follow-up actions.

Prevent the legacy model tool loop from exposing `hotel.navigate` or `hotel.call` as free-form initial tools; they are surface-derived actions only. Make `callLocalHotelTool()` explicitly reject those IDs so a bypass cannot accidentally execute the detail branch.

- [ ] **Step 6: Run tests and inspect `test_result.txt`**

Expected: registry alignment and all conditional-action cases pass.

- [ ] **Step 7: Commit only this task**

```bash
git add \
  agent_core/src/main/ets/aiphone/runtime/HotelActions.ets \
  agent_core/src/main/ets/aiphone/runtime/HotelToolA2ui.ets \
  agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets \
  agent_core/src/main/ets/aiphone/AiphoneToolDefinitions.ets \
  agent_core/src/main/ets/aiphone/LoopBackend.ets \
  agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets \
  agent_core/Index.ets \
  entry/src/test/HotelToolA2ui.test.ets \
  entry/src/test/ToolDefinitionRegistry.test.ets \
  entry/src/test/ToolGatewayClient.test.ets
git commit -m "feat: register truthful hotel actions"
```

---

## Task 4: Implement Registered Detail, Navigation, and Dialer Execution

**Files:**

- Create: `agent_core/src/main/ets/aiphone/runtime/HotelSystemIntent.ets`
- Create: `entry/src/main/ets/pages/A2uiHome/agent/HotelRegisteredActionExecutor.ets`
- Modify: `agent_core/Index.ets`
- Create: `entry/src/test/HotelSystemIntent.test.ets`
- Create: `entry/src/test/HotelRegisteredActionExecutor.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: Write failing URI safety tests**

Assert:

- navigation converts real longitude/latitude through `buildSystemFoodNavigationUri`;
- invalid/missing coordinates return an empty URI;
- phone normalization accepts digits with an optional leading `+` and strips only spaces, hyphens, and parentheses;
- fewer than 5 or more than 20 digits are rejected;
- `*`, `#`, comma, semicolon, extension markers, query text, newline, and a second `+` are rejected;
- valid international input produces `tel:+8613800138000`;
- no helper invokes a system ability.

- [ ] **Step 2: Write failing registered-executor tests**

Use a fake URI opener and deterministic ID factory. Test:

- `hotel.navigate` validates through ActionCatalog, opens the exact Petal Maps URI once, and returns success only when the opener succeeds;
- `hotel.call` opens the exact `tel:` URI once and reports “dialer opened”, never “call placed”;
- tampered phone/coordinates/hotel ID/place ID are rejected before the opener;
- `hotel.detail` does not call a provider; it returns one typed follow-up with a new turn and paired UI/Data tasks preserving exact real query args;
- `hotel.book` is rejected and never reaches the opener;
- opener failure produces an error result for UI Agent.

- [ ] **Step 3: Run tests to verify failure**

Expected: missing URI and action executor modules.

- [ ] **Step 4: Implement pure system-intent builders**

```ts
export function hotelDialUri(dialPhone: string): string {
  const compact = dialPhone.trim().replace(/[ ()-]/g, '');
  if (!/^\+?[0-9]{5,20}$/.test(compact)) {
    return '';
  }
  return 'tel:' + compact;
}

export function hotelNavigationUri(args: HotelNavigateArgs): string {
  if (!validHotelNavigateArgs(args).ok) {
    return '';
  }
  return buildSystemFoodNavigationUri(
    args.longitude.toString() + ',' + args.latitude.toString(),
    '',
    args.name
  );
}
```

Do not add `telprompt:`, direct-call permissions, or automatic dialing.

- [ ] **Step 5: Implement the Action Agent executor adapter**

`HotelRegisteredActionExecutor` receives:

- the read-only ActionCatalog;
- `SystemUriOpener`;
- correlation/ID factory;
- no DataAgent or UIAgent instance.

Execution behavior:

- detail → return typed follow-up task descriptors;
- navigate/call → open the validated URI and return structured intent status;
- all other action IDs → error.

The generic Action Agent publishes follow-up UI/Data messages to the bus.

- [ ] **Step 6: Run tests and inspect the result file**

Expected: safe URI and executor tests pass; no test performs a real system action.

- [ ] **Step 7: Commit only this task**

```bash
git add \
  agent_core/src/main/ets/aiphone/runtime/HotelSystemIntent.ets \
  entry/src/main/ets/pages/A2uiHome/agent/HotelRegisteredActionExecutor.ets \
  agent_core/Index.ets \
  entry/src/test/HotelSystemIntent.test.ets \
  entry/src/test/HotelRegisteredActionExecutor.test.ets \
  entry/src/test/List.test.ets
git commit -m "feat: execute registered hotel system actions"
```

---

## Task 5: Wire the Model-Backed Hotel Leader and Four-Agent Runtime

**Files:**

- Create: `entry/src/main/ets/pages/A2uiHome/agent/HotelLeaderPlanner.ets`
- Create: `entry/src/main/ets/pages/A2uiHome/agent/HotelAgentRuntime.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/HotelToolA2ui.ets`
- Modify: `agent_core/Index.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/Index.ets`
- Create: `entry/src/test/HotelLeaderPlanner.test.ets`
- Create: `entry/src/test/HotelAgentRuntime.test.ets`
- Modify: `entry/src/test/List.test.ets`

- [ ] **Step 1: Write failing Leader planner tests**

Inject `ScriptedLocalModel` or a small fake `LocalModel`. Test:

- Chinese “预订酒店” and English hotel requests produce a `hotel.search` data task, not `hotel.book`;
- current local date is supplied to the model for relative-date resolution;
- one valid JSON object is extracted from fenced or ReAct-like model text with existing `extractJsonObjects`;
- args must pass `parseHotelSearchRequest`;
- missing place/dates/occupancy, malformed JSON, unknown tool, or booking action fails rather than defaulting provider inventory;
- query text and all structured fields are preserved in the paired UI/Data plan.

The model output fixture should contain only the search args:

```json
{
  "originQuery": "8月15日深圳住两晚的酒店",
  "place": "深圳",
  "placeType": "CITY",
  "countryCode": "CN",
  "checkInDate": "2026-08-15",
  "stayNights": 2,
  "adultCount": 2,
  "childCount": 0,
  "childAgeDetails": [],
  "roomCount": 1,
  "currency": "CNY",
  "size": 10
}
```

- [ ] **Step 2: Write failing runtime integration tests**

With fake model/provider/writer/opener, assert:

1. `submit()` publishes one `INPUT.USER`;
2. all four agents have opened readers on the same bus before the input publish;
3. Leader produces paired UI/Data tasks;
4. skeleton is written before a delayed Data result;
5. the final hotel surface uses the same `surfaceId` as its skeleton;
6. Data-before-UI still renders correctly;
7. only the injected UI writer receives JSONL;
8. clicking detail creates a new correlated turn and paired tasks;
9. clicking call/navigation goes through Action Agent;
10. a replay from an old turn or modified action args is rejected;
11. non-hotel prompt routing predicate returns false.

- [ ] **Step 3: Run tests to verify failure**

Expected: missing planner/runtime and pending renderer.

- [ ] **Step 4: Add deterministic hotel skeleton rendering**

Export `hotelPendingA2ui(surfaceId, prompt)` from `HotelToolA2ui.ets`. It may reuse the current A2UI component types and wording, but must:

- create A2UI v0.9.1;
- use intent `hotel`;
- use the supplied surface ID;
- state that RollingGo data is pending;
- contain no result cards or actions.

- [ ] **Step 5: Implement the model-backed planner**

Construct the current model from the page's `LocalModelSettings`:

```ts
const provider = new LlmProvider(
  settings.provider,
  settings.apiKey,
  settings.baseUrl,
  settings.model,
  settings.customParametersJson
);
const model = new OpenAiCompatibleModel(provider);
```

Prompt rules:

- Leader extracts only a `hotel.search` request;
- relative dates resolve from an explicit current local date;
- it must return one JSON object and no action ID;
- it may not invent missing destination/date/guest values;
- “预订” means search and real rates because no transaction tool is registered.

Parse existing JSON-object output and then call `parseHotelSearchRequest`. Build deterministic paired UI/Data task descriptors from the validated request; the model does not choose arbitrary tools or buttons.

- [ ] **Step 6: Implement `HotelAgentRuntime`**

On construction:

1. create one `LinkedMessageBus`;
2. construct Leader, Data, UI, and Action agents with that bus;
3. create their readers before accepting input;
4. start each role;
5. retain only a stable page-session `conversationId`, monotonic turn/task/run ID factory, active surface authorization context, and search return surface reference.

Adapters:

- Data executor → `callStructuredHotelTool`;
- UI renderer → `hotelPendingA2ui`, `hotelSearchA2ui`, `hotelDetailA2ui`, and small action-status updates;
- UI writer → parse JSONL with existing A2UI parser/store and invoke the page surface callback;
- ActionCatalog → current `toolDefinitionForToolId`, exact current HTML/A2UI document policy, hotel args validators;
- system URI opener → page callback that uses `ohos.want.action.viewData`.

No adapter may receive another role object.

Before `hotelSearchA2ui` serializes actions, the UI renderer passes every candidate through `ActionCatalog` placement validation. Thus real coordinates/phone are necessary but not sufficient: an action also has to be currently registered and declared by `hotel.search`.

- [ ] **Step 7: Add the hotel-only migration seam to `Index.ets`**

Add a pure, tested `shouldRouteToHotelAgent(prompt)` predicate for explicit hotel/住宿 requests, including “预订酒店”. In `submitPrompt()`:

- retain current input/history/busy/error behavior;
- lazily initialize one runtime for the page session;
- send explicit hotel requests to `HotelAgentRuntime.submit`;
- leave all non-hotel requests on the current model/tool flow.

Do not add a settings toggle or generic feature-flag service.

Change `openExternalUrl()` to return `Promise<boolean>` so Action Agent reports actual ability-open success. Existing callers may ignore the boolean.

- [ ] **Step 8: Run tests and inspect `test_result.txt`**

Expected: the four-role hotel path passes with fake dependencies, and non-hotel path tests remain unchanged.

- [ ] **Step 9: Commit only this task**

```bash
git add \
  entry/src/main/ets/pages/A2uiHome/agent/HotelLeaderPlanner.ets \
  entry/src/main/ets/pages/A2uiHome/agent/HotelAgentRuntime.ets \
  agent_core/src/main/ets/aiphone/runtime/HotelToolA2ui.ets \
  agent_core/Index.ets \
  entry/src/main/ets/pages/A2uiHome/Index.ets \
  entry/src/test/HotelLeaderPlanner.test.ets \
  entry/src/test/HotelAgentRuntime.test.ets \
  entry/src/test/List.test.ets
git commit -m "feat: route hotels through four agents"
```

---

## Task 6: Render and Authorize Call/Navigation in the HTML Home

**Files:**

- Modify: `entry/src/main/ets/pages/A2uiHome/html/HtmlHotelHomeRenderer.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/html/HtmlHomeActionPolicy.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/Index.ets`
- Modify: `entry/src/test/HtmlHomeRenderer.test.ets`
- Modify: `entry/src/test/HtmlHomeActionPolicy.test.ets`
- Modify: `scripts/aiphone-device-smoke.mjs`

- [ ] **Step 1: Write failing HTML renderer tests**

Create documents with exact A2UI actions and assert:

- detail is primary;
- navigate and call appear as separate secondary buttons when present;
- no call action means no call text/button;
- no navigation action means no navigation text/button;
- no `hotel.book` control appears;
- button clicks post the exact source action object without reconstructing args from visible labels.

- [ ] **Step 2: Write failing action-policy tests**

Assert exact-action authorization:

- unchanged hotel detail/navigation/call actions are allowed;
- changed phone, provider Place ID, hotel ID, latitude, longitude, turn, or surface is denied;
- an action copied from an old hotel document is denied against the current document;
- absent button action is denied even if its ID is registered;
- `hotel.book` is denied.

- [ ] **Step 3: Run tests to verify failure**

Expected: renderer lacks the two controls and runtime routing does not yet consume them.

- [ ] **Step 4: Render the controls from existing actions only**

In `renderSearchCard`, retrieve:

```js
var detailAction = actionFor(block, 'hotel.detail');
var navigateAction = actionFor(block, 'hotel.navigate');
var callAction = actionFor(block, 'hotel.call');
```

Render a compact action row. Do not synthesize an action from rows. The presence of a button is exactly the presence of the corresponding A2UI action.

- [ ] **Step 5: Route hotel actions to the runtime**

In `sendAction()`:

- keep `hotel.search.restore` as the current pure client restore;
- route `hotel.detail`, `hotel.navigate`, and `hotel.call` to `HotelAgentRuntime.runAction`;
- pass the exact action, active conversation/turn/surface, and current document to the runtime;
- remove the old direct `hotel.detail` `callToolById()` branch only after the new integration tests pass.

The ActionCatalog entry adapter must call the existing `isHtmlHomeActionAllowed()` and then compare args against retained structured DataResult identity.

- [ ] **Step 6: Extend device smoke discovery without fabricating success**

Update the hotel smoke helpers to detect the new button labels and surface action IDs. The smoke logic must:

- require navigation only when current provider data contains valid coordinates;
- require call only when current provider data contains verified contact;
- treat missing contact as a verified hidden-button case, not invent a number;
- never log the full number; a masked suffix is sufficient;
- keep the existing hotel search/detail checks.

- [ ] **Step 7: Run renderer/policy tests and inspect results**

Expected: conditional buttons and exact action authorization pass.

- [ ] **Step 8: Commit only this task**

```bash
git add \
  entry/src/main/ets/pages/A2uiHome/html/HtmlHotelHomeRenderer.ets \
  entry/src/main/ets/pages/A2uiHome/html/HtmlHomeActionPolicy.ets \
  entry/src/main/ets/pages/A2uiHome/Index.ets \
  entry/src/test/HtmlHomeRenderer.test.ets \
  entry/src/test/HtmlHomeActionPolicy.test.ets \
  scripts/aiphone-device-smoke.mjs
git commit -m "feat: show conditional hotel call and navigation"
```

---

## Task 7: Run Static, Unit, and Build Regression Gates

**Files:**

- Modify: `scripts/verify-loopy-backend.mjs`
- Verify all files changed in Tasks 1–6.

- [ ] **Step 1: Add hotel architecture checks**

Extend the existing verifier narrowly to assert:

- structured hotel gateway export exists;
- hotel search declares detail/navigation/call;
- navigate/call use `system_intent`;
- `hotel.book/create/status/cancel` are absent;
- `HotelAgentRuntime` constructs the four roles on one bus;
- `HotelToolA2ui` conditionally derives actions from real fields;
- phone fields appear only in the Places detail mask;
- legacy hotel gateway rejects unknown hotel actions;
- non-hotel routing remains present.

- [ ] **Step 2: Run all Hypium tests**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

- [ ] **Step 3: Read the authoritative result**

```bash
sed -n '1,240p' entry/.test/default/intermediates/test/coverage_data/test_result.txt
```

Record tests/failures/errors. Separate a pre-existing failure from a regression with evidence.

- [ ] **Step 4: Run the source/HAR verifier**

```bash
node scripts/verify-loopy-backend.mjs
```

Expected: all static assertions pass and `agent_core.har` builds.

- [ ] **Step 5: Run capability coverage audit**

```bash
node /Users/luoyige/.codex/skills/appless-device-regression/scripts/audit-coverage.mjs \
  --repo "$PWD"
```

Expected: the live registry/docs/smoke inventory is aligned. If hotel system intents need capability documentation, update the existing current-capability document only; do not claim reservation transactions.

- [ ] **Step 6: Scan for placeholders and forbidden claims**

```bash
rg -n "TODO|FIXME|placeholder|hotel\\.book|hotel\\.create|hotel\\.status|hotel\\.cancel|订单创建成功|预订成功|自动拨打|mock phone|fake phone" \
  agent_core/src/main/ets/aiphone/runtime/Hotel* \
  entry/src/main/ets/pages/A2uiHome/agent \
  entry/src/main/ets/pages/A2uiHome/html/HtmlHotelHomeRenderer.ets \
  scripts/aiphone-device-smoke.mjs
```

Review every hit. Registry-negative tests and truthful limitation copy are allowed; product capability claims and placeholders are not.

- [ ] **Step 7: Check scope**

```bash
git diff --check
git status --short
```

Verify local provider config, artifacts, plan docs, and unrelated user edits are not staged.

- [ ] **Step 8: Commit the verifier update**

```bash
git add scripts/verify-loopy-backend.mjs
git commit -m "test: verify hotel agent architecture"
```

If a regression correction was needed, stage only that correction with the verifier and describe it in the commit body.

---

## Task 8: Prove the Real Provider and Phone-Standalone Device Path

**Files:**

- Verification evidence only. Do not commit provider configuration, screenshots/log dumps, HAPs, or smoke artifacts.

- [ ] **Step 1: Load the required device-regression procedure**

Before executing this task, read and follow:

```text
/Users/luoyige/.codex/skills/appless-device-regression/SKILL.md
```

Use its current install, launch, evidence, and cleanup commands. Do not substitute a Mac gateway success for phone evidence.

- [ ] **Step 2: Confirm current capability and smoke inventory**

```bash
node scripts/aiphone-device-smoke.mjs --list-cases
node /Users/luoyige/.codex/skills/appless-device-regression/scripts/audit-coverage.mjs \
  --repo "$PWD"
```

- [ ] **Step 3: Sync ignored provider configuration without printing secrets**

```bash
node scripts/sync-provider-config.mjs
```

Verify configuration presence through the existing redacted debug summary. Never print raw RollingGo or Google keys.

- [ ] **Step 4: Prove RollingGo structured data**

Run the hotel smoke/query with a natural request containing an explicit city, future check-in, nights, adults, children, rooms, and currency. Capture:

- transport and inner provider success separately;
- real positive `hotelId`;
- requested dates/occupancy/currency;
- real search result count;
- one selected hotel's real `ratePlanId`, price/currency, bed/meal, availability, and cancellation policy.

If only a `bookingUrl` appears, record it as a third-party URL, not an order capability.

- [ ] **Step 5: Prove contact enrichment truthfully**

For the selected result:

- if one Google Place is uniquely matched and has a real phone, record provider and masked Place ID/phone suffix, then expect the call button;
- if key/tier/scope, matching, or phone is unavailable, record the exact warning and prove the call button is absent;
- never switch to fixture data to turn this step green.

This step may be `PASS` for verified presence or `PASS` for truthful absence policy, while end-to-end dialer opening remains `BLOCKED` if no real provider phone is returned.

- [ ] **Step 6: Build and install the current checkout**

Use the device-regression skill's signed-HAP workflow. Confirm the installed package came from this checkout and commit, not a stale artifact.

- [ ] **Step 7: Prove phone-standalone routing**

```bash
hdc list targets
hdc fport ls
```

Acceptance requires a real device target and empty `hdc fport ls`. Device logs must show `local://aiphone-tools`; Mac gateway/services may be used only for separate development diagnostics.

- [ ] **Step 8: Run hotel search/detail device smoke**

Set `AIPHONE_HDC_TARGET` to the real target and run the current core regression plus the hotel exact/natural case from `scripts/aiphone-device-smoke.mjs`.

Verify on the device:

- skeleton and results use the same `surfaceId`;
- real hotel cards appear;
- “查看实时房型” opens real rates and cancellation policy;
- no booking/order success is shown.

- [ ] **Step 9: Verify navigation**

For a result with valid real coordinates, tap “一键导航”. Prove Petal Maps opens to the same coordinates/name. If no result contains valid coordinates, report `BLOCKED` with the provider evidence; do not synthesize coordinates.

- [ ] **Step 10: Verify dialer behavior when real phone exists**

If a real verified contact exists, tap “拨打酒店电话” and prove:

- the system dialer opens;
- the prefilled number matches the provider value;
- no automatic outgoing call occurs;
- returning to Appless preserves the hotel surface.

If no real contact exists, prove the button is absent and report dialer E2E as `BLOCKED`, while keeping the truthful hidden-button policy as `PASS`.

- [ ] **Step 11: Capture final test/runtime evidence**

Report separately:

- unit/static/build;
- RollingGo search/detail;
- Places contact enrichment;
- A2UI surface behavior;
- Petal Maps;
- dialer;
- phone-standalone routing.

Use `PASS`, `PARTIAL`, or `BLOCKED` per item. A Provider HTTP 200, ACTIVE registration, rendered card, opened intent, or `bookingUrl` alone does not prove a transaction, phone call, or hotel booking.

---

## Completion Evidence

Before declaring this plan complete, report:

- implementation commit IDs;
- Hypium totals from `test_result.txt`;
- static/HAR and capability-audit results;
- a real RollingGo hotel ID and real selected rate plan evidence, with secrets/private data redacted;
- whether Places returned a unique match and phone, plus truthful absent-button behavior;
- exact evidence that navigation uses provider coordinates;
- exact evidence that dialer opening does not auto-call;
- `hdc fport ls` output showing no forwarding during phone acceptance;
- confirmation that hotel search is the only newly migrated scene;
- confirmation that `hotel.book/create/status/cancel` and runtime code generation remain absent;
- any unavailable provider/device proof reported as `PARTIAL` or `BLOCKED`, not inferred as success.
