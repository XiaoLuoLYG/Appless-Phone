# 普通对话首页展示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将无工具的 assistant 回复展示为紧凑的阅读式答复页，并把上下文改成默认折叠的时间轴，同时保持工具任务卡不变。

**Architecture:** 复用现有 `HtmlHomeDocument.history` 数据，不增加字段和后端协议。仅在 `HtmlHomeRenderer.ets` 的 generic model、无 blocks、无 timeline 且存在可见 assistant history 时切换到 plain-chat 分支；主展示渲染最新 assistant，剩余消息进入原生 `details/summary` 时间轴。非 plain-chat 场景继续走现有分支。

**Tech Stack:** HarmonyOS ArkWeb HTML renderer, native HTML/CSS/JavaScript, Hypium unit tests.

## Global Constraints

- 不修改 `HtmlHomeTypes.ets`、`HtmlHomeSnapshot.ets`、multiagent runtime、工具页面或后端协议。
- 不新增依赖、不新增页面、不改变现有工具卡交互。
- 普通回复去掉“Appless 的回复”“你的请求”等解释性标题。
- 主回复保留可读性，其他标题、说明、统计和 metadata 缩小或移除。
- 上下文默认折叠，展开后按时间顺序显示 `你` / `Appless` 时间轴。
- 遵守 `prefers-reduced-motion`，只使用短时可中断 transition。
- 保留用户当前工作树中与本任务无关的未提交改动。

---

### Task 1: Add the failing renderer assertions

**Files:**
- Modify: `entry/src/test/HtmlHomeRenderer.test.ets`

**Interfaces:**
- Consumes: existing `HtmlHomeDocument` fixture and `renderHtmlHomeDocument`.
- Produces: regression assertions for the plain-chat render contract.

- [ ] **Step 1: Add a plain-chat fixture**

Add a helper beside `documentFixture()`:

```ts
function plainChatDocumentFixture(): HtmlHomeDocument {
  const document = documentFixture();
  document.source = 'model';
  document.kind = 'generic';
  document.title = 'A2UI';
  document.subtitle = '';
  document.blocks = [];
  document.timeline = [];
  document.history = [
    { id: 'm1', role: 'user', content: '解释普通回复的展示方式' },
    { id: 'm2', role: 'assistant', content: '普通回复应该直接出现在首页主区域。' }
  ];
  return document;
}
```

- [ ] **Step 2: Add the expected plain-chat test**

Add one Hypium test near the generic renderer tests:

```ts
it('renders a plain model reply as a reading page with collapsed timeline context', 0, () => {
  const html = renderHtmlHomeDocument(plainChatDocumentFixture());

  expect(html.indexOf('plain-chat')).assertLarger(-1);
  expect(html.indexOf('plain-chat-response')).assertLarger(-1);
  expect(html.indexOf('plain-chat-context')).assertLarger(-1);
  expect(html.indexOf('plain-chat-timeline')).assertLarger(-1);
  expect(html.indexOf('details')).assertLarger(-1);
  expect(html.indexOf('plain-chat-role-user')).assertLarger(-1);
  expect(html.indexOf('plain-chat-role-assistant')).assertLarger(-1);
});
```

- [ ] **Step 3: Add the non-regression test**

Ensure a tool document still contains the existing task result renderer:

```ts
it('keeps task result wording for a generic tool document', 0, () => {
  const html = renderHtmlHomeDocument(documentFixture());
  expect(html.indexOf('任务结果')).assertLarger(-1);
  expect(html.indexOf('plain-chat-response')).assertEqual(-1);
});
```

- [ ] **Step 4: Run the focused test command**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test   -p product=default -p module=entry@default -p testType=unit --no-daemon
```

Expected: the new plain-chat test fails because `plain-chat-response` and its branch do not exist yet. Existing tests may continue to pass.

---

### Task 2: Implement the plain-chat reading page and timeline context

**Files:**
- Modify: `entry/src/main/ets/pages/A2uiHome/html/HtmlHomeRenderer.ets`

**Interfaces:**
- Consumes: `data.source`, `data.kind`, `data.blocks`, `data.timeline`, and `data.history` already embedded in the renderer.
- Produces: static plain-chat DOM through existing `add()` helpers, native `details/summary` context disclosure, and role-specific timeline classes.

- [ ] **Step 1: Add plain-chat CSS**

Add styles next to the existing generic history/timeline rules:

```css
.plain-chat-response {
  margin-top: 8px;
  padding: 2px 0 8px 14px;
  border-left: 2px solid var(--accent);
}
.plain-chat-response-copy {
  color: var(--ink);
  font-size: 17px;
  line-height: 1.7;
  white-space: pre-wrap;
}
.plain-chat-context {
  margin-top: 16px;
  border-top: 1px solid var(--line);
}
.plain-chat-context > summary {
  display: flex;
  justify-content: space-between;
  padding: 10px 0;
  color: var(--ink-soft);
  cursor: pointer;
  list-style: none;
}
.plain-chat-context > summary::-webkit-details-marker { display: none; }
.plain-chat-context > summary::after { content: '+'; color: var(--accent); }
.plain-chat-context[open] > summary::after { content: '−'; }
.plain-chat-timeline {
  position: relative;
  margin-left: 5px;
  padding: 2px 0 2px 18px;
  border-left: 1px solid var(--line);
}
.plain-chat-turn {
  position: relative;
  margin: 0 0 12px;
  padding: 0 0 2px;
}
.plain-chat-turn::before {
  content: '';
  position: absolute;
  left: -23px;
  top: 4px;
  width: 7px;
  height: 7px;
  border: 2px solid var(--muted);
  border-radius: 50%;
  background: var(--paper);
}
.plain-chat-role-assistant::before { border-color: var(--accent); }
.plain-chat-role {
  color: var(--muted);
  font-size: 11px;
}
.plain-chat-role-assistant .plain-chat-role { color: var(--accent); }
.plain-chat-turn-copy {
  margin-top: 3px;
  color: var(--ink-soft);
  font-size: 13px;
  line-height: 1.5;
  white-space: pre-wrap;
}
```

Use existing tokens and reduced-motion rules. Do not add chat bubble backgrounds.

- [ ] **Step 2: Add plain-chat predicates and helpers**

Add helpers in the renderer script before the main render branch:

```js
function latestAssistant(history) {
  for (var index = history.length - 1; index >= 0; index -= 1) {
    if (text(history[index] && history[index].role) === 'assistant' &&
        text(history[index] && history[index].content).trim().length > 0) {
      return history[index];
    }
  }
  return null;
}
function isPlainChatScene(blocks, timeline, history) {
  return scene === 'generic' &&
    text(data.source) === 'model' &&
    blocks.length === 0 &&
    timeline.length === 0 &&
    latestAssistant(history) !== null;
}
```

- [ ] **Step 3: Render the plain-chat branch**

Before the existing `blocks.length > 0` branch, collect `blocks`, `timeline`, and `history` once. When `isPlainChatScene` is true:

1. Render a `section plain-chat`.
2. Render only the latest assistant content as `article plain-chat-response`.
3. If earlier or user messages remain, render a closed `details plain-chat-context` with a `summary` containing only “上下文” and the count.
4. Render remaining messages in original array order under `div plain-chat-timeline`.
5. Map roles to `你` and `Appless` only in the timeline, with classes `plain-chat-role-user` and `plain-chat-role-assistant`.
6. Do not render “你的请求” or “Appless 的回复” labels in the main response.

Keep the old result, empty, timeline, and history branches for every other scene.

- [ ] **Step 4: Reduce generic hero noise for plain chat**

In the existing generic hero helper, use the plain-chat title `和 Appless 聊聊` and a smaller subtitle only for the plain-chat predicate. Do not alter hero text for tool scenes or pending states.

- [ ] **Step 5: Run the focused test command**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test \
  -p product=default -p module=entry@default -p testType=unit --no-daemon
```

Expected: the new plain-chat assertions pass and existing generic/tool renderer tests remain green.

---

### Task 3: Verify the diff and renderer boundary

**Files:**
- Inspect: `entry/src/main/ets/pages/A2uiHome/html/HtmlHomeRenderer.ets`
- Inspect: `entry/src/test/HtmlHomeRenderer.test.ets`

**Interfaces:**
- Consumes: completed plain-chat renderer and focused Hypium result.
- Produces: final diff and test evidence without touching unrelated working-tree files.

- [ ] **Step 1: Check the diff**

Run:

```bash
git diff --check
git diff --stat -- entry/src/main/ets/pages/A2uiHome/html/HtmlHomeRenderer.ets entry/src/test/HtmlHomeRenderer.test.ets
```

Expected: no whitespace errors and only the two requested files are changed after the spec commit.

- [ ] **Step 2: Verify the test result file**

Run:

```bash
tail -5 entry/.test/default/intermediates/test/coverage_data/test_result.txt
grep -Eq '^Tests run: [1-9][0-9]*, Failure: 0, Error: 0, Pass: [0-9]+, Ignore: [0-9]+$'   entry/.test/default/intermediates/test/coverage_data/test_result.txt
```

Expected: explicit non-zero test count and zero failures/errors.

- [ ] **Step 3: Confirm unrelated changes remain untouched**

Run:

```bash
git status --short
git diff --name-only
```

Expected: pre-existing user changes remain present; no unrelated files are staged or modified by this task.
