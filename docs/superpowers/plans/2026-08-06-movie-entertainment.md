# Movie Entertainment Scene Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a real-material, naturally routed movie entertainment scene without changing or removing the World Cup scene.

**Architecture:** Register `movie.open` beside `worldcup.open`, validate it as a read-only page action, and route it to a separate `MovieDemo` ArkWeb page. Keep all curated movie data and interactive presentation in one raw HTML document so the native shell stays small and the World Cup renderer remains untouched.

**Tech Stack:** HarmonyOS ArkTS, ArkUI Router, ArkWeb, static HTML/CSS/JavaScript, Hypium, existing device smoke harness.

## Global Constraints

- Base branch is `multiagent-backend`; implementation branch is `codex/movie-entertainment-multiagent`.
- Every movie, person, image, poster, still, trailer, and short video must be a real published asset with a visible source.
- No placeholder or generated media, invented movie names, fake box-office numbers, hidden playback errors, new dependency, or live-provider claim.
- Page theme is locked to Projector Black `#101113` with Cinema Coral `#E85D4A` as the only accent.
- `movie.open` is read-only; YouTube-only and Bilibili-only searches keep using existing media tools.
- `AnythingDemo`, `anything_worldcup_feed.json`, and `worldcup.open` remain present and behaviorally unchanged.

---

### Task 1: Register and validate `movie.open`

**Files:**
- Modify: `agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets`
- Modify: `agent_core/src/main/ets/agent/action/ActionCatalog.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/RegisteredPageActionRoute.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/RegisteredPageActionHandler.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor.ets`
- Modify: `entry/src/test/ToolDefinitionRegistry.test.ets`
- Modify: `entry/src/test/ActionCatalog.test.ets`
- Modify: `entry/src/test/AiphoneRegisteredActionExecutor.test.ets`

**Interfaces:**
- Consumes: existing `ToolDefinition`, registered page action, and action validation contracts.
- Produces: `movie.open` with exact route `pages/A2uiHome/MovieDemo`.

- [ ] **Step 1: Write failing registry and action tests**

```ts
const movie = toolDefinitionForToolId('movie.open');
expect(movie === null ? '' : movie.backendPriority[0]).assertEqual('system_intent');
expect(movie === null ? '' : movie.a2uiComponent).assertEqual('MovieDemo');

const validation = validateActionIntentExecution(
  'movie.open',
  JSON.parse('{"route":"pages/A2uiHome/MovieDemo"}') as Object
);
expect(validation.ok).assertTrue();
```

- [ ] **Step 2: Run Hypium and confirm RED**

Run the repository Hypium command and inspect `entry/.test/default/intermediates/test/coverage_data/test_result.txt`.
Expected: the new assertions fail because `movie.open` is not registered.

- [ ] **Step 3: Add the minimal page-intent definition and validation**

```ts
{
  toolId: 'movie.open',
  domain: 'media',
  intent: 'movie.open',
  riskLevel: 'read',
  backendPriority: ['system_intent'],
  authModes: ['system'],
  inputSchema: 'movieExperienceRequest',
  outputSchema: 'movieExperience',
  a2uiComponent: 'MovieDemo',
  actions: []
}
```

Use the exact route constant `pages/A2uiHome/MovieDemo` in the existing virtual-action, handler, and executor validation branches.

- [ ] **Step 4: Run Hypium and confirm GREEN**

Expected: `Failure: 0, Error: 0`.

- [ ] **Step 5: Commit**

```bash
git add agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets \
  agent_core/src/main/ets/agent/action/ActionCatalog.ets \
  entry/src/main/ets/pages/A2uiHome/agent \
  entry/src/test/ToolDefinitionRegistry.test.ets \
  entry/src/test/ActionCatalog.test.ets \
  entry/src/test/AiphoneRegisteredActionExecutor.test.ets
git commit -m "feat: register movie page intent"
```

### Task 2: Route natural language to `MovieDemo`

**Files:**
- Modify: `entry/src/main/ets/model/PersonaStore.ets`
- Modify: `entry/src/main/resources/rawfile/personas/entertainment_companion/skills.md`
- Modify: `entry/src/main/resources/rawfile/personas/entertainment_companion/skills/media-search/SKILL.md`
- Modify: `entry/src/main/ets/pages/A2uiHome/Index.ets`
- Modify: `entry/src/main/resources/base/profile/main_pages.json`
- Modify: `entry/src/test/PersonaStore.test.ets`
- Modify: `entry/src/test/RegisteredPageActionMigration.test.ets`

**Interfaces:**
- Consumes: `movie.open` and route `pages/A2uiHome/MovieDemo`.
- Produces: model-selected client intent and `[AIPhone][MovieDemoRouteByTool]`.

- [ ] **Step 1: Write failing route and persona tests**

```ts
expect(personaSource('entertainment_companion/skills.md').includes('movie.open')).assertTrue();
expect(resolveVirtualRegisteredPageAction('movie.open', '想看看最近有什么电影') !== null).assertTrue();
```

- [ ] **Step 2: Run Hypium and confirm RED**

Expected: the movie persona and virtual route assertions fail.

- [ ] **Step 3: Add the minimal prompt and Index route**

Describe `movie.open` as the first-party movie page for now-showing, box office,
trailers, and star updates. Add one `Index.ets` branch parallel to
`worldcup.open`, calling:

```ts
router.pushUrl({ url: 'pages/A2uiHome/MovieDemo' })
```

Log `[AIPhone][MovieDemoRouteByTool]` before navigation and keep the World Cup
branch unchanged.

- [ ] **Step 4: Run Hypium and confirm GREEN**

Expected: `Failure: 0, Error: 0`.

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/model/PersonaStore.ets \
  entry/src/main/resources/rawfile/personas \
  entry/src/main/ets/pages/A2uiHome/Index.ets \
  entry/src/main/resources/base/profile/main_pages.json \
  entry/src/test/PersonaStore.test.ets \
  entry/src/test/RegisteredPageActionMigration.test.ets
git commit -m "feat: route movie entertainment requests"
```

### Task 3: Build the real-material movie experience

**Files:**
- Create: `entry/src/main/ets/pages/A2uiHome/MovieDemo.ets`
- Create: `entry/src/main/resources/rawfile/movie_entertainment.html`
- Create: `entry/src/test/MovieDemo.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Interfaces:**
- Consumes: route `pages/A2uiHome/MovieDemo`, native `AIPhoneMovie.postAction`.
- Produces: visible marker `电影 Anything OS`, real media elements, filtered sections, detail disclosures, and source-link actions.

- [ ] **Step 1: Verify and record the material set**

For each asset, capture the publisher page, direct image or video URL, content
type, HTTP status, and snapshot date. Reject redirects to login pages, HTML
responses masquerading as media, generated assets, and inaccessible URLs.

- [ ] **Step 2: Write the failing page-content test**

```ts
expect(movieHtml.includes('电影 Anything OS')).assertTrue();
expect(movieHtml.includes('data-source-url="https://')).assertTrue();
expect(movieHtml.includes('<video')).assertTrue();
expect(movieHtml.includes('prefers-reduced-motion')).assertTrue();
expect(movieHtml.includes('picsum.photos')).assertFalse();
expect(movieHtml.includes('placeholder')).assertFalse();
```

Register `movieDemoTest()` in `List.test.ets`.

- [ ] **Step 3: Run Hypium and confirm RED**

Expected: compile failure because the movie test and page artifact do not exist.

- [ ] **Step 4: Add the minimal native shell**

`MovieDemo.ets` reads `movie_entertainment.html`, loads it into ArkWeb, exposes
one `AIPhoneMovie.postAction` bridge, accepts only `https://` external URLs, logs
`[AIPhone][MovieDemoLoad]`, and shows a real load error on failure.

- [ ] **Step 5: Add the curated HTML experience**

The raw document must include:

```html
<main class="movie-shell" data-snapshot-date="2026-08-06">
  <section class="movie-hero"></section>
  <nav class="category-rail" aria-label="电影内容分类"></nav>
  <section class="video-stage"></section>
  <section class="now-showing"></section>
  <section class="box-office"></section>
  <section class="star-updates"></section>
  <section class="editorial-feed"></section>
</main>
```

Use native `<video controls playsinline preload="metadata">`, buttons, details,
scroll snap, CSS transitions, and one event-delegated click handler. Include
explicit loading and error copy. Under `prefers-reduced-motion: reduce`, remove
transform movement and retain a short opacity transition.

- [ ] **Step 6: Run Hypium and confirm GREEN**

Expected: `Failure: 0, Error: 0`.

- [ ] **Step 7: Commit**

```bash
git add entry/src/main/ets/pages/A2uiHome/MovieDemo.ets \
  entry/src/main/resources/rawfile/movie_entertainment.html \
  entry/src/test/MovieDemo.test.ets \
  entry/src/test/List.test.ets
git commit -m "feat: add movie entertainment experience"
```

### Task 4: Extend smoke coverage and verify on device

**Files:**
- Modify: `scripts/aiphone-device-smoke.mjs`
- Modify: `docs/current-capabilities.md`

**Interfaces:**
- Consumes: `movie.open`, `[AIPhone][MovieDemoRouteByTool]`, `[AIPhone][MovieDemoLoad]`, `电影 Anything OS`.
- Produces: a changed-regression case for `想看看最近有什么电影`.

- [ ] **Step 1: Add the movie smoke case before product verification**

```js
{
  id: 'C14',
  query: '想看看最近有什么电影',
  expectsTool: true,
  expectedToolId: 'movie.open'
}
```

Recognize the movie route and visible marker without loosening World Cup checks.

- [ ] **Step 2: Run static smoke listing and audit**

```bash
node scripts/aiphone-device-smoke.mjs --list-cases
node ~/.codex/skills/appless-device-regression/scripts/audit-coverage.mjs --repo "$PWD"
```

Expected: C14 appears once and the audit reports no unclassified page intent.

- [ ] **Step 3: Run fresh full tests and build**

Run Hypium, verify `Failure: 0, Error: 0`, then assemble the signed HAP with the
repository command. Record the HAP SHA-256.

- [ ] **Step 4: Install without clearing data**

Use the single target from `hdc list targets`, inspect `hdc fport ls`, and
install the signed HAP with `hdc install -r`.

- [ ] **Step 5: Run the fixed query and inspect visible evidence**

Run:

```bash
AIPHONE_QUERY_TIMEOUT_MS=90000 \
AIPHONE_QUERY_RETRY_LIMIT=2 \
node scripts/aiphone-device-smoke.mjs '想看看最近有什么电影'
```

Require `movie.open`, `MovieDemoRouteByTool`, `MovieDemoLoad`, the visible page
marker, a screenshot, layout without raw JSON or clipping, a successful real
media load or an honest media error, and working source-link interaction.

- [ ] **Step 6: Run changed regression**

Run core regression plus the movie query and the existing World Cup query.
Report each case as PASS, FAIL, BLOCKED, or NOT_RUN.

- [ ] **Step 7: Commit**

```bash
git add scripts/aiphone-device-smoke.mjs docs/current-capabilities.md
git commit -m "test: cover movie entertainment scene"
```
