# Hotel Results Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a calmer hotel Hero and expandable result/rate cards, add the real hotel journey to core regression, validate it on the HarmonyOS phone, and merge PR #64 into one aligned main checkout.

**Architecture:** Keep the existing `HtmlHotelHomeRenderer.ets` delegation, A2UI provider data, and ArkWeb action bridge unchanged. Implement presentation and expansion in that one renderer, extend the existing smoke runner and maintained capability/matrix files, then use the signed HAP and phone-local runtime for acceptance.

**Tech Stack:** HarmonyOS ArkTS, inline HTML/CSS/vanilla JavaScript, existing Hypium renderer tests, Node.js ESM smoke runner, HDC/uitest/hilog, GitHub CLI.

## Global Constraints

- Do not add hotel booking/order placeholders; RollingGo remains read-only search and rate detail.
- Do not add dependencies, shared abstractions, or fabricated hotel images/data.
- Preserve real `hotel.detail` action args even when internal IDs are no longer visible.
- Use native buttons, visible focus, reduced-motion/transparency/contrast support, and at least 44px tap targets.
- Hypium `Failure` must be 0 and selected core regression must have no `BLOCKED` or `NOT_RUN` before merge.
- Final repository state is one main worktree on local `main == origin/main`; obsolete scene branches and the merged feature branch are removed.

---

### Task 1: Hotel Hero and expandable cards

**Files:**
- Modify: `entry/src/test/HtmlHomeRenderer.test.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/html/HtmlHotelHomeRenderer.ets`

**Interfaces:**
- Consumes: existing `HtmlHomeDocument`, block rows, `window.AIPhoneHome.postAction`
- Produces: `.hotel-hero-media`, `.hotel-card-toggle`, `.hotel-card-details`, single-card expansion via `aria-expanded`

- [ ] **Step 1: Write the failing renderer assertions**

Replace the hotel renderer assertions with:

```typescript
expect(html.indexOf('hotel-hero-media')).assertLarger(-1);
expect(html.indexOf('酒店 · 实时房价')).assertLarger(-1);
expect(html.indexOf('hotel-card-toggle')).assertLarger(-1);
expect(html.indexOf('hotel-card-details')).assertLarger(-1);
expect(html.indexOf('aria-expanded')).assertLarger(-1);
expect(html.indexOf('setExpanded')).assertLarger(-1);
expect(html.indexOf('LIVE HOTEL DATA')).assertEqual(-1);
expect(html.indexOf('hotel-scene-note')).assertEqual(-1);
expect(html.indexOf("add(identifiers")).assertEqual(-1);
expect(html.indexOf('第三方预订（离开 Appless）：')).assertEqual(-1);
expect(html.indexOf('下单成功')).assertEqual(-1);
expect(html.indexOf('订单编号')).assertEqual(-1);
```

- [ ] **Step 2: Run RED**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test --no-daemon
```

Expected: hotel renderer assertions fail because the new Hero/expand classes do not exist.

- [ ] **Step 3: Implement the minimal renderer change**

In `HOTEL_HOME_JS`, add one state and the existing single-expand pattern:

```javascript
var state = { expandedKey: '' };
function setExpanded(key) {
  state.expandedKey = state.expandedKey === key ? '' : key;
  Array.prototype.slice.call(document.querySelectorAll('.hotel-rate-card')).forEach(function (card) {
    var expanded = card.getAttribute('data-card-key') === state.expandedKey;
    card.classList.toggle('expanded', expanded);
    card.setAttribute('aria-expanded', expanded ? 'true' : 'false');
    var button = card.querySelector('.hotel-card-toggle');
    if (button) { button.textContent = expanded ? '收起' : '展开'; }
  });
}
```

Build each card with its existing block ID, summary, price, and a collapsed details host:

```javascript
var key = text(block && block.id) || 'hotel-' + index;
card.setAttribute('data-card-key', key);
card.setAttribute('aria-expanded', 'false');
var toggle = add(top, 'button', 'hotel-card-toggle', '展开');
toggle.type = 'button';
toggle.setAttribute('aria-expanded', 'false');
toggle.addEventListener('click', function (event) {
  event.stopPropagation();
  setExpanded(key);
});
var details = add(body, 'div', 'hotel-card-details');
```

Render only user facts into `details`. Do not create visible ID/raw-URL nodes. Keep price truth concise:

```javascript
addFact(details, '入住', rowValue(block, ['入住']));
addFact(details, '客人', rowValue(block, ['客人']));
addFact(details, '地址', rowValue(block, ['地址']));
addFact(details, '星级', rowValue(block, ['星级']));
addFact(details, '床型', rowValue(block, ['床型']));
addFact(details, '餐食', rowValue(block, ['餐食']));
addFact(details, '房态', rowValue(block, ['供应商确认']));
addFact(details, '设施', rowValue(block, ['设施']));
addFact(details, '标签', rowValue(block, ['标签']));
```

Create the Hero from the first valid provider image with CSS fallback:

```javascript
var firstImage = blocks.length > 0 ? safeImageUrl(rowValue(blocks[0], ['酒店图片'])) : '';
var hero = add(shell, 'header', 'hotel-hero');
var heroMedia = add(hero, 'div', 'hotel-hero-media');
if (firstImage.length > 0) { heroMedia.style.backgroundImage = 'url("' + firstImage.replace(/"/g, '') + '")'; }
var heroCopy = add(hero, 'div', 'hotel-hero-copy');
add(heroCopy, 'div', 'hotel-kicker', '酒店 · 实时房价');
add(heroCopy, 'h1', '', text(data.title) || '酒店搜索');
add(heroCopy, 'p', 'hotel-hero-subtitle', text(data.subtitle));
add(heroCopy, 'p', 'hotel-hero-note', '房价实时更新，以供应商确认页为准。');
```

CSS must keep the current variables and use only native layout/transitions:

```css
.hotel-hero { position: relative; min-height: 260px; overflow: hidden; border-radius: 24px; }
.hotel-hero-media { position: absolute; inset: 0; background: linear-gradient(135deg, #42665f, #192824); background-position: center; background-size: cover; }
.hotel-hero::after { content: ""; position: absolute; inset: 0; background: linear-gradient(180deg, rgba(10,20,18,.08), rgba(10,20,18,.78)); }
.hotel-hero-copy { position: relative; z-index: 1; display: flex; min-height: 260px; flex-direction: column; justify-content: flex-end; padding: 22px; color: white; }
.hotel-card-toggle, .hotel-action { min-height: 44px; }
.hotel-rate-card:not(.expanded) .hotel-card-details { display: none; }
.hotel-rate-card { transition: transform 160ms ease, box-shadow 160ms ease; }
.hotel-rate-card:active { transform: scale(.992); }
@media (prefers-reduced-motion: reduce) { * { animation: none !important; transition: none !important; scroll-behavior: auto !important; } }
@media (prefers-reduced-transparency: reduce) { .hotel-hero::after { background: rgba(18,31,27,.86); } }
@media (prefers-contrast: more) { .hotel-rate-card, .hotel-card-toggle { border-color: currentColor; } }
```

- [ ] **Step 4: Run GREEN**

Run the same Hypium command. Expected: the new hotel assertions pass and report `Failure 0`.

- [ ] **Step 5: Commit**

```bash
git add entry/src/test/HtmlHomeRenderer.test.ets \
  entry/src/main/ets/pages/A2uiHome/html/HtmlHotelHomeRenderer.ets
git commit -m "style: simplify expandable hotel cards"
```

---

### Task 2: Add the hotel journey to core regression

**Files:**
- Modify: `scripts/aiphone-device-smoke.mjs`
- Modify: `docs/current-capabilities.md`
- Modify: `/Users/luoyige/.codex/skills/appless-device-regression/references/scenario-matrix.md`

**Interfaces:**
- Consumes: `--list-cases`, `--core-regression`, existing HDC helpers and block action labels
- Produces: C20 list entry and hotel search → expand → detail → expand evidence

- [ ] **Step 1: Run the existing RED list check**

```bash
AIPHONE_HDC_TARGET=__no_device__ \
node scripts/aiphone-device-smoke.mjs --list-cases --core-regression
```

Expected: non-zero because these flags currently fall through to HDC.

- [ ] **Step 2: Add core selection and C20**

Define the complete approved core list:

```javascript
const smokeRunId = process.env.AIPHONE_SMOKE_RUN_ID ||
  new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 14);
const whatsappTestTo = (process.env.AIPHONE_WHATSAPP_TEST_TO || '').trim();
const qaDateValue = new Date();
qaDateValue.setDate(qaDateValue.getDate() + 7);
const qaDate = `${qaDateValue.getFullYear()}年${String(qaDateValue.getMonth() + 1).padStart(2, '0')}月${String(qaDateValue.getDate()).padStart(2, '0')}日`;
const qaTitle = `Appless QA ${smokeRunId}`;

const coreRegressionCases = [
  { id: 'C01', query: '你好', expectsTool: false, expectedToolId: '' },
  { id: 'C02', query: '我明天要从北京去上海，帮我搜索出行方案', expectsTool: true, expectedToolId: 'travel.search' },
  { id: 'C03', query: '帮我搜索深圳坂田华为基地附近的咖啡店', expectsTool: true, expectedToolId: 'food.search' },
  { id: 'C04', query: '帮我用 Google Maps 搜索伦敦国王十字车站附近的中餐', expectsTool: true, expectedToolId: 'maps.place.search' },
  { id: 'C05', query: '帮我查看邮箱里最新的重要邮件', expectsTool: true, expectedToolId: 'mail.search' },
  { id: 'C06', query: '帮我查看我 Gmail 里和 ECCV 论文相关的邮件', expectsTool: true, expectedToolId: 'gmail.mail.search' },
  { id: 'C07', query: '帮我在 B 站和 YouTube 里搜索 Qwen 的官方视频', expectsTool: true, expectedToolId: 'media.video.search' },
  { id: 'C08', query: '我想看看有关 OpenAI Codex 的相关新闻和讨论', expectsTool: true, expectedToolId: 'media.aggregate.search' },
  { id: 'C09', query: '帮我查看我今天 X 和 Slack 上的消息', expectsTool: true, expectedToolId: 'social.feed.search' },
  { id: 'C10', query: '帮我查看 X 上 OpenAI 最近的公开 post', expectsTool: true, expectedToolId: 'x.post.search' },
  { id: 'C11a', query: '点一杯咖啡', expectsTool: true, expectedToolId: 'food.search' },
  { id: 'C11b', query: '我只喝瑞幸咖啡', expectsTool: false, expectedToolId: '' },
  { id: 'C11c', query: '点一杯咖啡', expectsTool: true, expectedToolId: 'food.search', expectedPersonaMemory: 'luckin_only' },
  { id: 'C12', query: '我想看世界杯下一场比赛和赛程', expectsTool: true, expectedToolId: 'worldcup.open' },
  { id: 'C13', query: '帮我查明天深圳天气', expectsTool: true, expectedToolId: 'dynamic.search', expectedDiscoveredToolId: 'weather.query' },
  { id: 'C14', query: '帮我看从深圳湾万象城到深圳北站打车多少钱', expectsTool: true, expectedToolId: 'ride.estimate' },
  { id: 'C15', query: '帮我点一杯瑞幸生椰拿铁，半糖少冰', expectsTool: true, expectedToolId: 'luckin.order.preview' },
  { id: 'C16', query: '帮我用 Google Maps 查询从深圳北站到深圳湾口岸的驾车路线并发起导航', expectsTool: true, expectedToolId: 'maps.route.open' },
  { id: 'C17', query: '用 PayPal 给罗一格转 1 美元', expectsTool: true, expectedToolId: 'payment.send' },
  {
    id: 'C18',
    query: `帮我给 WhatsApp 测试联系人 ${whatsappTestTo} 发送消息：Appless QA ${smokeRunId}`,
    expectsTool: true,
    expectedToolId: 'whatsapp.message.send',
    blockedWithoutWhatsAppTestTo: true
  },
  { id: 'C19a', query: `帮我查询 ${qaDate} 的 Google Calendar 日程`, expectsTool: true, expectedToolId: 'calendar.events.search' },
  { id: 'C19b', query: `帮我在 ${qaDate} 下午3点创建标题为 ${qaTitle} 的30分钟日程`, expectsTool: true, expectedToolId: 'calendar.event.create' },
  { id: 'C19c', query: `把 ${qaDate} 的 ${qaTitle} 日程改到下午4点，保持30分钟`, expectsTool: true, expectedToolId: 'calendar.event.update' },
  { id: 'C19d', query: `帮我查询 ${qaDate} 标题为 ${qaTitle} 的 Google Calendar 日程`, expectsTool: true, expectedToolId: 'calendar.events.search' },
  { id: 'C19e', query: `删除 ${qaDate} 标题为 ${qaTitle} 的 Google Calendar 日程`, expectsTool: true, expectedToolId: 'calendar.event.delete' },
  { id: 'C19f', query: `再次查询 ${qaDate} 标题为 ${qaTitle} 的 Google Calendar 日程，确认它不存在`, expectsTool: true, expectedToolId: 'calendar.events.search' },
  {
    id: 'C20',
    query: '帮我搜索2026年8月8日至10日深圳南山区科技园附近的酒店，2位成人1间房',
    expectsTool: true,
    expectedToolId: 'hotel.search',
    verifyHotelDetail: true
  }
];
```

Filter both flags from `queryArgs`, select `coreRegressionCases`, and exit before HDC in list mode:

```javascript
const runCoreRegression = argv.includes('--core-regression');
const listCases = argv.includes('--list-cases');
if (listCases) {
  console.log(JSON.stringify(selectedDefaultCases, null, 2));
  process.exit(0);
}
```

If `blockedWithoutWhatsAppTestTo` is true and `AIPHONE_WHATSAPP_TEST_TO` is empty, emit `BLOCKED` for C18 without typing the query or inventing a recipient. Core cannot pass until the variable is available.

- [ ] **Step 3: Add the hotel derivative interaction**

Reuse `findTextCenter`, `dumpLayout`, `captureScreen`, `collectLayoutText`, and `hdc`:

```javascript
async function verifyHotelDetailAction(layout, index) {
  var expand = findTextCenter(layout, '展开');
  if (expand === null) { return { ok: false, reason: 'hotel expand button not found' }; }
  hdc(['shell', 'uitest', 'uiInput', 'click', String(expand.x), String(expand.y)]);
  await sleep(700);
  var expanded = dumpLayout(`query-${index + 1}-hotel-expanded-layout.json`);
  var detail = findTextCenter(expanded, '查看实时房型');
  if (detail === null) { return { ok: false, reason: 'hotel detail button not found' }; }
  clearHilog();
  hdc(['shell', 'uitest', 'uiInput', 'click', String(detail.x), String(detail.y)]);
  await sleep(2500);
  var rates = dumpLayout(`query-${index + 1}-hotel-rates-layout.json`);
  var rateExpand = findTextCenter(rates, '展开');
  if (rateExpand !== null) {
    hdc(['shell', 'uitest', 'uiInput', 'click', String(rateExpand.x), String(rateExpand.y)]);
    await sleep(700);
    rates = dumpLayout(`query-${index + 1}-hotel-rate-expanded-layout.json`);
  }
  var text = collectLayoutText(rates).join('\n');
  return {
    ok: /实时房型/.test(text) && /床型|餐食|取消政策/.test(text),
    screenPath: captureScreen(`query-${index + 1}-hotel-rate-expanded-screen.png`)
  };
}
```

Call it only for `verifyHotelDetail: true` and include the returned `ok` in the case summary.

- [ ] **Step 4: Update the matrix, capability table, and excluded suites**

Add C20 and the two coverage rows:

```markdown
| C20 | `帮我搜索2026年8月8日至10日深圳南山区科技园附近的酒店，2位成人1间房` | `hotel.search` → `hotel.detail` | 展开真实酒店卡、查看实时房型并展开一条房型；不预订 |
| `hotel.search` | core | C20 |
| `hotel.detail` | core | C20 衍生交互 |
```

Add corresponding `hotel.search` and `hotel.detail` rows to `docs/current-capabilities.md`, update its date to `2026-07-19`, and record `42` registry tools plus the two runtime tools (`memory.update`, `dynamic.search`) for a maximum of `44`.

The current coverage audit also reports these existing documentation gaps; add factual rows from the current registry without changing product code:

```text
luckin.order.preview
luckin.order.create
luckin.order.status
worldcup.open
calendar.event.delete
maps.route.open
whatsapp.message.send
ride.estimate
ride.app.link
ride.order.create
ride.order.cancel
ride.driver.location
```

Remove these excluded queries from automatic `dynamicCases`/`composioCases` arrays while leaving explicit one-query debugging and product routing untouched:

```text
帮我查明天深圳到珠海的船票
帮我查 Linear 里分配给我的高优先级 bug
帮我在 Trello 里找本周发布 checklist 相关卡片
帮我在 Asana 里查今天到期的任务
帮我在 HubSpot 里找最近更新的 contacts
帮我在 Salesforce 里找最近更新的 leads
帮我用 Outlook 查最近和 AIPhoneDemo 相关的邮件
帮我用 Ticketmaster 查深圳本周末的演唱会
```

- [ ] **Step 5: Run GREEN list and coverage checks**

```bash
node --check scripts/aiphone-device-smoke.mjs
node scripts/aiphone-device-smoke.mjs --list-cases --core-regression > /tmp/appless-core-cases.json
node -e "const c=require('/tmp/appless-core-cases.json'); if(!c.some(x=>x.id==='C20'&&x.expectedToolId==='hotel.search')) process.exit(1)"
node /Users/luoyige/.codex/skills/appless-device-regression/scripts/audit-coverage.mjs \
  --repo /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo
```

Expected: syntax/list checks exit 0, C20 is present, and coverage audit reports no hotel gap.

- [ ] **Step 6: Commit**

```bash
git add scripts/aiphone-device-smoke.mjs docs/current-capabilities.md
git commit -m "test: add hotel journey to core regression"
```

The external skill matrix is not part of the repository commit; verify its diff separately.

---

### Task 3: Build and run core device regression

**Files:**
- Evidence: `entry/build/default/outputs/default/entry-default-signed.hap`
- Evidence: `tool-gateway/.smoke/`

**Interfaces:**
- Consumes: current provider config, connected HarmonyOS phone, C01–C20 runner
- Produces: zero-failure Hypium report, signed HAP, per-case screenshots/layout/hilog, zero-forwarding proof

- [ ] **Step 1: Verify phone-local boundary and configuration**

```bash
TARGET="$(hdc list targets | awk 'NF && $0 !~ /List of targets/ {print; exit}')"
test -n "$TARGET"
hdc -t "$TARGET" fport ls
node scripts/sync-provider-config.mjs
node scripts/verify-loopy-backend.mjs
```

Expected: one target; `fport ls` is `[Empty]`; config scripts exit 0 without printing secrets.

- [ ] **Step 2: Run full Hypium**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test --no-daemon
```

Expected: report contains `Failure 0`. Stop before merge otherwise.

- [ ] **Step 3: Build and install the same signed HAP**

```bash
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp --no-daemon
test -f entry/build/default/outputs/default/entry-default-signed.hap
hdc -t "$TARGET" install -r entry/build/default/outputs/default/entry-default-signed.hap
```

Expected: `BUILD SUCCESSFUL`, HAP exists, install succeeds without cleaning app data.

- [ ] **Step 4: Run core C01–C20**

```bash
AIPHONE_HDC_TARGET="$TARGET" \
AIPHONE_QUERY_TIMEOUT_MS=90000 \
AIPHONE_QUERY_RETRY_LIMIT=2 \
node scripts/aiphone-device-smoke.mjs --core-regression
```

Expected: exit 0; summary contains no failed, `BLOCKED`, or `NOT_RUN` cases.

- [ ] **Step 5: Verify evidence and independence**

```bash
hdc -t "$TARGET" fport ls
node /Users/luoyige/.codex/skills/appless-device-regression/scripts/audit-coverage.mjs \
  --repo /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo
```

Expected: `[Empty]`, audit exit 0, and hotel expanded/rate screenshots plus `hotel.search`/`hotel.detail` hilog are present.

---

### Task 4: Merge PR and converge Git state

**Files:**
- No product files

**Interfaces:**
- Consumes: passing Task 3 evidence and open PR #64
- Produces: merged PR, local/remote main alignment, one worktree and one local branch

- [ ] **Step 1: Remove process-only spec/plan files from the final PR diff**

```bash
git rm docs/superpowers/specs/2026-07-19-hotel-results-frontend-design.md \
  docs/superpowers/plans/2026-07-19-hotel-results-frontend.md
git commit -m "chore: keep process notes out of release"
```

- [ ] **Step 2: Align the feature branch with current remote main**

```bash
git fetch --prune origin
git merge --no-edit origin/main
```

Expected: clean merge and no unrelated scene files in `git diff origin/main...HEAD`.

- [ ] **Step 3: Re-run Hypium after integration**

Run Task 3 Step 2 again. Expected: `Failure 0`.

- [ ] **Step 4: Push and merge the already-authorized PR**

```bash
git push origin agent/hotel-search-calm-ui
gh pr merge 64 --squash --delete-branch
```

Expected: PR #64 state is `MERGED`.

- [ ] **Step 5: Align the only checkout and remove obsolete refs**

```bash
git checkout main
git pull --ff-only origin main
git worktree prune
```

Delete local branches already named as obsolete scene/recovery branches plus the merged feature branch using `git branch -d`; then:

```bash
git fetch --prune origin
git status --short --branch
git worktree list --porcelain
git branch --format='%(refname:short)'
git ls-remote --heads origin
```

Expected: one worktree, local `main` only, `main == origin/main`, and the merged feature remote is absent.
