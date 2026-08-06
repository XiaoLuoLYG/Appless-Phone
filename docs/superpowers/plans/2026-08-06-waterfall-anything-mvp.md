# Waterfall Anything MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 `media.aggregate.search` 聚合页内加入一个确定性、随到随排、有限续流的 Waterfall Anything 媒体发现 Demo；首个可展示来源即可起流，后到内容不改动已展示内容与紧邻两条，并保留真实来源状态和有限候选边界。

**Architecture:** 只新增一个纯 ArkTS 候选编排模块；媒体适配和来源批次仍留在现有 `AggregateSearchClient.ets`；发现流继续由 `HtmlAggregateSearchHomeRenderer.ets` 在同一 HTML 文档内渲染。聚合来源通过现有 local-tool partial A2UI 通道增量更新同一 surface；HTML 用现有 `runJavaScript` 原地更新模式接收后到批次，页面内存只保存当前发现流交互状态。

**Tech Stack:** ArkTS、Hypium、现有 A2UI JSONL/`A2uiPartialUpdatePlanner`、ArkWeb `runJavaScript`、原生 HTML/CSS/JavaScript、现有 HarmonyOS hvigor 构建与 `scripts/aiphone-device-smoke.mjs`。

## Global Constraints

- 以当前 working tree 为实现起点，保留并不提交用户已有的聚合搜索修复：X `messageText` 正文映射、隐藏 `result N` 占位标题，以及其相关测试。
- 当前另有用户改动位于 `AggregateSearchClient.ets`、`ComposioDynamicBackend.ets`、`HtmlAggregateSearchHomeRenderer.ets` 和对应测试。不得 `stash`、`reset --hard`、`reset --mixed`、`checkout --`、覆盖或删除这些改动；每次提交只用 `git add -p` 选择本任务新增 hunks。`git reset -p` 仅可用于取消误暂存，不得改写 working tree。
- 不触碰 `entry/src/main/ets/pages/A2uiHome/AnythingDemo.ets`、`entry/src/main/resources/base/profile/main_pages.json`、主 Agent、工具注册、业务页面、App 路由或导航。Waterfall 只扩展现有 `aggregate-search` HTML。
- 只新增一个生产文件：`agent_core/src/main/ets/aiphone/runtime/WaterfallAnythingCore.ets`。不新增测试文件；纯逻辑测试写入现有 `AggregateSearchClient.test.ets`，HTML 测试写入现有 renderer/snapshot 测试。
- 不新增依赖、数据库、缓存服务、行为持久化、模型调用、异步 Agent、自然语言输入、接口/工厂/插件框架或配置系统。
- 固定 Demo 参数直接定义在纯模块：低水位 `3`、目标库存 `8`、来源单批上限 `5`、稳定窗口 `2`。时间排序必须显式接收 `nowMs`，测试不得依赖真实当前时间。
- 当前来源未在 `AggregateSearchResult` 暴露经过验证的分页、游标或偏移令牌。初版全部适配器必须返回 `continuation: null`，不得猜页码、复用第一页或伪造无限流。纯水位规划器仍覆盖有真实 continuation 时的通用行为。
- `preferenceDescription` 保留为纯字符串输入并固定传空字符串；不解析、不展示输入框、不调用主 Agent。“对话式推荐共创 / 随聊随变”留到第二阶段。
- 任何 provider 慢、失败、空结果或需授权都只更新自身状态，不阻塞其他来源，不转写为成功。
- TDD 顺序不可交换：每个行为先写会因缺少能力而失败的 Hypium 断言，确认 RED，再写最少 GREEN 代码，再运行完整 Hypium 结果文件校验。
- 只有纯逻辑、渐进 A2UI 和现有测试全部通过后，才修改 HTML 发现流。
- 共享设备在另一工作树使用。实现阶段允许不占设备的单测和 debug HAP 构建；在协调线程明确授予真机时隙前，禁止运行 `hdc`、安装 HAP、启动应用或执行真机 smoke。
- 不把 hvigor 进程退出码、HAP 构建成功、`--list-cases` 输出或 provider 缺配置状态描述成真机功能通过。

---

## 当前代码 seam 与最小文件范围

### 只新增

- `agent_core/src/main/ets/aiphone/runtime/WaterfallAnythingCore.ets`
  - 统一候选、排序信号、推荐理由、稳定队列和水位规划的无副作用函数。

### 修改现有生产文件

- `agent_core/Index.ets`
  - 只导出 `WaterfallAnythingCore.ets` 的公开纯类型和函数，供 entry 测试与 HTML snapshot 使用。
- `agent_core/src/main/ets/aiphone/runtime/AggregateSearchTypes.ets`
  - 在 `AggregateSearchResult` 增加可选 `waterfall` 快照；不改变原 `videos/posts/sourceStatuses/summary` 合约。
- `agent_core/src/main/ets/aiphone/runtime/AggregateSearchClient.ets`
  - 将当前顺序等待改为来源级小批 Promise；复用现有 provider 调用和字段映射，产生统一候选并通过可选 observer 发出累计快照。
- `agent_core/src/main/ets/aiphone/runtime/AggregateSearchA2ui.ets`
  - 抽出 `aggregateSearchA2uiRenderState()`，用既有 `A2uiPartialUpdatePlanner` 生成首次 surface 和后续 `/aggregateSearch` patch。
- `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`
  - 让 `callLocalMediaTool()` 接收现有 `emitJsonl`，把聚合 partial 送入现有 local-tool surface store；最终结果仍走原返回值。
- `entry/src/main/ets/pages/A2uiHome/html/HtmlHomeTypes.ets`
  - 给 `HtmlHomeDocument` 增加可选 `waterfall` 快照字段。
- `entry/src/main/ets/pages/A2uiHome/html/HtmlHomeSnapshot.ets`
  - 从 `/aggregateSearch.waterfall` 复制快照；原视频、帖子、状态 block 映射保持不变。
- `entry/src/main/ets/pages/A2uiHome/html/HtmlAggregateSearchHomeRenderer.ets`
  - 保留现有聚合列表与筛选，增加入口按钮、发现流 DOM/CSS、payload 构造和页面内状态更新。
- `entry/src/main/ets/pages/A2uiHome/Index.ets`
  - 仿照现有 `multiTaskPayloadJson/tick` 保存稳定聚合 HTML shell，并发布 Waterfall payload；不增加 action 路由。
- `entry/src/main/ets/pages/A2uiHome/components/HomePage.ets`
  - 透传 `waterfallPayloadJson/tick`。
- `entry/src/main/ets/pages/A2uiHome/components/HtmlHomeSurfaceView.ets`
  - 用既有 ArkWeb `runJavaScript` 模式调用 `window.__aiphoneApplyWaterfallUpdate(payload)`，避免后到批次重载 HTML。

### 修改现有测试文件

- `entry/src/test/AggregateSearchClient.test.ets`
  - 承载候选编排、媒体映射、队列、水位及来源批次测试；无需改 `List.test.ets`。
- `entry/src/test/AggregateSearchA2ui.test.ets`
  - 验证首次 envelope 与后续仅更新 `/aggregateSearch`。
- `entry/src/test/HtmlHomeSnapshot.test.ets`
  - 验证 Waterfall 快照传入 `aggregate-search` 文档且原 blocks 不变。
- `entry/src/test/HtmlHomeRenderer.test.ets`
  - 验证入口、全屏状态、三项轻操作、媒体类型、空态和稳定原地更新文案。

---

## Task 0: 固定当前 dirty working-tree baseline

**Files:**

- No file changes.

### Verification

- [ ] 记录但不改变当前状态：

```bash
git status --short --branch
git diff --name-only
git diff --stat
```

- [ ] 确认设计提交 `e800795b` 可见，且现有用户修改仍未暂存：

```bash
git log --oneline -3
git diff --cached --name-only
```

- [ ] 在写第一个 Waterfall 测试前运行完整 Hypium baseline：

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test \
  -p product=default \
  -p module=entry@default \
  -p testType=unit \
  --no-daemon
```

- [ ] 读取 canonical result；若 baseline 已有 failure/error，先向协调线程报告具体测试名和结果文件，不修改无关代码来掩盖它：

```bash
test -f entry/.test/default/intermediates/test/coverage_data/test_result.txt
tail -5 entry/.test/default/intermediates/test/coverage_data/test_result.txt
grep -Eq '^Tests run: [1-9][0-9]*, Failure: 0, Error: 0, Pass: [0-9]+, Ignore: [0-9]+$' \
  entry/.test/default/intermediates/test/coverage_data/test_result.txt
```

- [ ] 本任务不提交。

---

## Task 1: 纯候选编排与媒体字段映射

**Files:**

- Create: `agent_core/src/main/ets/aiphone/runtime/WaterfallAnythingCore.ets`
- Modify: `agent_core/Index.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/AggregateSearchClient.ets`
- Test: `entry/src/test/AggregateSearchClient.test.ets`

### Interfaces

在唯一新增模块中使用普通数据类型和纯函数，不建立 adapter interface：

```ts
export type WaterfallMediaType = 'video' | 'image_text' | 'post';
export type WaterfallContinuationKind = 'cursor' | 'page' | 'offset';

export interface WaterfallCandidate {
  id: string;
  source: string;
  mediaType: WaterfallMediaType;
  title: string;
  summary: string;
  url: string;
  coverUrl: string;
  publishedAt: string;
  originalIndex: number;
}

export interface WaterfallRankSignals {
  relevanceTier: number;
  titleHits: number;
  summaryHits: number;
  freshnessTier: number;
}

export interface WaterfallRankedCandidate extends WaterfallCandidate {
  normalizedUrl: string;
  signals: WaterfallRankSignals;
  reason: string;
}

export interface WaterfallOrderInput {
  query: string;
  candidates: WaterfallCandidate[];
  enabledSources: string[];
  shownIds: string[];
  stableIds: string[];
  preferenceDescription: string;
}

export function rankWaterfallCandidates(
  input: WaterfallOrderInput,
  nowMs: number
): WaterfallRankedCandidate[];
```

媒体映射留在 `AggregateSearchClient.ets`：

```ts
export function aggregateMediaCandidates(
  videos: AggregateSearchVideo[],
  posts: AggregateSearchPost[],
  batchIndex: number
): WaterfallCandidate[];
```

`originalIndex` 使用 `batchIndex * 1000 + itemIndex`；首批每来源最多 5 条，因此不会与批内位置冲突，也不新增全局 ID 服务。

### RED

- [ ] 在 `AggregateSearchClient.test.ets` 先加入一个固定 `nowMs = Date.parse('2026-08-06T12:00:00.000Z')` 的测试组，测试名称必须直接表达行为：
  - `ranks exact and token query matches before weak matches`
  - `uses freshness then original order without random output`
  - `balances sources inside the same relevance tier`
  - `deduplicates normalized links across video and post`
  - `keeps only enabled sources and truthful reason signals`
  - `maps video image-text and post fields without inventing data`
- [ ] 用字面量断言完整候选 ID 顺序和理由，例如：

```ts
expect(ranked.map((item) => item.id).join(','))
  .assertEqual('yt-exact,hn-exact,reddit-token,old-weak');
expect(ranked[0].reason).assertEqual('标题命中查询 · 24 小时内发布');
expect(ranked.some((item) => item.id === 'duplicate-post')).assertFalse();
```

- [ ] URL fixture 覆盖协议/主机大小写和 fragment：

```ts
const duplicateA = 'HTTPS://Example.com/watch?id=7#comments';
const duplicateB = 'https://example.com/watch?id=7#top';
```

保留查询参数，确认 `?id=7` 与 `?id=8` 不会误去重。

- [ ] 执行当前仓库实际 Hypium 入口：

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test \
  -p product=default \
  -p module=entry@default \
  -p testType=unit \
  --no-daemon
```

- [ ] 检查 `entry/.test/default/intermediates/test/coverage_data/test_result.txt`，确认新增测试因导出/函数尚不存在或断言不满足而 RED。不要把 hvigor 的退出码当作 RED/GREEN 结论。

### GREEN

- [ ] 在 `WaterfallAnythingCore.ets` 实现最小确定性流程：
  1. 来源开关过滤；
  2. 只接受 `http://` 或 `https://`；
  3. 查询按空白和常见中英文标点切词；
  4. 计算完整短语、全部 token、部分 token、弱相关四档；
  5. 计算 `24h / 7d / 30d / 更早或无效` 四档；
  6. URL 去 fragment，协议和主机小写，保留 path/query；
  7. 对同一 normalized URL 保留信号更强、更新、`originalIndex` 更小的一条；
  8. 同相关性档按已选来源次数少者优先，来源计数以 `shownIds + stableIds` 对应候选为种子，再比较新鲜度、命中数和原顺序；
  9. 推荐理由最多两项，只引用真实命中、新鲜度或来源补充信号。
- [ ] `preferenceDescription` 只进入输入类型，不参与计算；不要加 parser。
- [ ] 在 `aggregateMediaCandidates()` 复用现有视频/帖子字段：
  - video → `video`
  - 帖子 `rows` 中第一条有效图片 URL → `image_text`
  - 无图片帖子 → `post`
  - 占位 `result N` 标题映射为空，但原聚合卡片的现有隐藏修复保持原样。
- [ ] 从 `agent_core/Index.ets` 导出纯类型和函数。

### Verification

- [ ] 重新运行完整 Hypium 命令。
- [ ] 严格检查结果：

```bash
test -f entry/.test/default/intermediates/test/coverage_data/test_result.txt
tail -5 entry/.test/default/intermediates/test/coverage_data/test_result.txt
grep -Eq '^Tests run: [1-9][0-9]*, Failure: 0, Error: 0, Pass: [0-9]+, Ignore: [0-9]+$' \
  entry/.test/default/intermediates/test/coverage_data/test_result.txt
```

- [ ] 确认现有 `dedupeVideos()` / `dedupePosts()` 对原聚合列表的行为未被替换；跨类型 normalized URL 去重只作用于 Waterfall 候选。
- [ ] 用 `git add -p` 只暂存本任务 hunks，检查 `git diff --cached` 不包含此前 `messageText` / `result N` 修复，再提交：

```bash
git commit -m "feat: add deterministic Waterfall candidate ordering"
```

---

## Task 2: 稳定队列与内容水位线

**Files:**

- Modify: `agent_core/src/main/ets/aiphone/runtime/WaterfallAnythingCore.ets`
- Test: `entry/src/test/AggregateSearchClient.test.ets`

### Interfaces

```ts
export interface WaterfallContinuation {
  kind: WaterfallContinuationKind;
  value: string;
}

export type WaterfallSourcePhase =
  'loading' | 'success' | 'empty' | 'needs_auth' | 'error' | 'exhausted';

export interface WaterfallSourceState {
  source: string;
  phase: WaterfallSourcePhase;
  continuation: WaterfallContinuation | null;
  inFlight: boolean;
  reservedCount: number;
  message: string;
}

export interface WaterfallFeedState {
  query: string;
  enabledSources: string[];
  preferenceDescription: string;
  shown: WaterfallRankedCandidate[];
  current: WaterfallRankedCandidate | null;
  stable: WaterfallRankedCandidate[];
  tail: WaterfallRankedCandidate[];
  sources: WaterfallSourceState[];
}

export interface WaterfallLoadRequest {
  source: string;
  continuation: WaterfallContinuation;
  limit: number;
}

export interface WaterfallFeedUpdate {
  state: WaterfallFeedState;
  loadRequests: WaterfallLoadRequest[];
}

export function mergeWaterfallBatch(
  state: WaterfallFeedState,
  incoming: WaterfallCandidate[],
  sourceState: WaterfallSourceState,
  nowMs: number
): WaterfallFeedUpdate;

export function advanceWaterfallFeed(
  state: WaterfallFeedState,
  nowMs: number
): WaterfallFeedUpdate;

export function applyWaterfallSourceSelection(
  state: WaterfallFeedState,
  enabledSources: string[],
  nowMs: number
): WaterfallFeedUpdate;
```

### RED

- [ ] 先在 `AggregateSearchClient.test.ets` 增加最少状态测试：
  - `starts the feed from the first displayable source batch`
  - `does not rerank shown items or the next two items`
  - `moves the two-item stable window after advancing`
  - `reorders all unshown items after an explicit source toggle`
  - `requests at most five items when inventory reaches three`
  - `counts in-flight reservations toward the target of eight`
  - `allows only one in-flight request per source`
  - `marks a source exhausted when it has no continuation`
  - `ends the round when every enabled source is exhausted`
- [ ] 使用完整顺序断言证明迟到的高相关候选只进入尾部：

```ts
expect(update.state.shown.map((item) => item.id).join(',')).assertEqual('shown-1');
expect(update.state.current?.id).assertEqual('current-1');
expect(update.state.stable.map((item) => item.id).join(',')).assertEqual('next-1,next-2');
expect(update.state.tail.map((item) => item.id).join(','))
  .assertEqual('late-exact,tail-old');
```

- [ ] 水位 fixture 使用库存恰好 `3`、一个 continuation 和 `reservedCount = 0`，断言单次 `limit === 5`；将同源 `inFlight` 改为 `true` 后断言请求数为 `0`。
- [ ] 无分页 fixture 的所有来源使用 `continuation: null`，断言 `phase === 'exhausted'` 且 `loadRequests.length === 0`。
- [ ] 运行完整 Hypium 并从 `test_result.txt` 确认 RED。

### GREEN

- [ ] 在纯模块中直接使用显示历史、当前、稳定窗口和尾部四段数据，不增加队列类：
  - `shown` 永不被被动批次改写；
  - `current` 是当前屏；首个有效批次把排序第一条提升为 `current`，因此可立即起流；
  - `stable` 最多两条；
  - 后到批次只与 `tail` 合并、去重和重排；
  - 尾部来源均衡以 `shown + current + stable` 的来源次数为种子；
  - `advance` 把旧 `current` 移入 `shown`、把稳定首条提升为新 `current`，再从 `tail` 补足两条；
  - 用户来源切换可过滤并重排全部未展示内容；若 `current` 来自关闭来源，先把它记入 `shown`，再从新队列第一条继续。
- [ ] 每次 merge/advance 后调用一个私有 `planLoads()`：
  - 未展示库存为 `stable.length + tail.length`；
  - 库存 `<= 3` 才考虑续拉；
  - 缺口为 `8 - inventory - sum(reservedCount)`；
  - 每个请求 `limit = min(5, remainingGap)`；
  - 仅选择 `continuation !== null && !inFlight` 的来源；
  - 选中后在返回 state 中立即置 `inFlight = true` 并增加预留；
  - `continuation === null` 且不在 loading 的来源转为 `exhausted`。
- [ ] 失败、需授权、空结果来源不产生 load request，也不改变其他来源候选。
- [ ] 全部 enabled source 为终态、库存为零且 `current === null` 时，在快照上给出 `exhausted: true`；不循环旧条目。

### Verification

- [ ] 运行完整 Hypium 并严格 grep `Failure: 0, Error: 0`。
- [ ] 重复运行一次队列测试所在的完整 suite，确认固定 `nowMs` 下顺序不漂移。
- [ ] 检查纯模块没有网络、存储、随机数、计时器、模型或 provider import。
- [ ] 只暂存本任务新增 hunks并提交：

```bash
git commit -m "feat: add stable Waterfall feed state"
```

---

## Task 3: 来源随到随排与同一 A2UI surface 渐进更新

**Files:**

- Modify: `agent_core/src/main/ets/aiphone/runtime/AggregateSearchTypes.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/AggregateSearchClient.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/AggregateSearchA2ui.ets`
- Modify: `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets`
- Test: `entry/src/test/AggregateSearchClient.test.ets`
- Test: `entry/src/test/AggregateSearchA2ui.test.ets`

### Interfaces

`AggregateSearchResult` 只增加可选字段，旧调用方不需要构造：

```ts
export interface AggregateSearchResult {
  query: string;
  videos: AggregateSearchVideo[];
  posts: AggregateSearchPost[];
  sourceStatuses: AggregateSearchSourceStatus[];
  summary: string;
  waterfall?: WaterfallFeedState;
}
```

`AggregateSearchClient.ets` 内使用一个普通来源批次，不新建适配器文件：

```ts
export interface AggregateSearchSourceBatch {
  source: AggregateSearchSource;
  videos: AggregateSearchVideo[];
  posts: AggregateSearchPost[];
  status: AggregateSearchSourceStatus;
  continuation: WaterfallContinuation | null;
}

export type AggregateSearchPartialObserver =
  (result: AggregateSearchResult) => void;

export async function streamAggregateSearchSourceBatches(
  query: string,
  requestedSources: AggregateSearchSource[],
  tasks: Promise<AggregateSearchSourceBatch>[],
  onPartial: AggregateSearchPartialObserver,
  nowMs: number
): Promise<AggregateSearchResult>;
```

`callAggregateSearch()` 只追加两个可选参数，现有调用保持兼容：

```ts
export async function callAggregateSearch(
  prompt: string,
  args: Object | null,
  youtubeApiKey: string,
  zhihuConfig: AggregateZhihuConfig = emptyZhihuConfig(),
  onPartial: AggregateSearchPartialObserver | null = null,
  nowMs: number = Date.now()
): Promise<AggregateSearchResult>;
```

### RED

- [ ] 在 `AggregateSearchClient.test.ets` 用手动可解析 Promise 构造 YouTube 慢、B 站先返回的两个批次，不访问网络。
- [ ] 先 resolve B 站，等待 microtask，断言：
  - observer 已调用一次；
  - 首个快照已有 B 站候选；
  - YouTube source phase 仍为 `loading`；
  - Promise 总结果尚未完成。
- [ ] 再 resolve YouTube，断言第二个快照累计两来源，首批已进入的稳定两条 ID 和理由不变。
- [ ] 增加一个 error/needs_auth 批次，断言成功来源快照仍被发出，失败来源只出现在状态。
- [ ] 断言当前六个实际来源构造的批次全部 `continuation === null`；不得用 fixture 暗示 provider 已支持翻页。
- [ ] 在 `AggregateSearchA2ui.test.ets` 先写：
  - 首次 `planA2uiPartialUpdate(null, aggregateSearchA2uiRenderState('surface-1', firstResult, 'streaming'))` 包含 `createSurface`、components 和 `/aggregateSearch`；
  - 第二批复用 cache 后只更新 `/aggregateSearch`，不创建第二个 surface。
- [ ] 运行完整 Hypium，从 `test_result.txt` 确认 RED。

### GREEN

- [ ] 将每个请求来源包装为一个 `Promise<AggregateSearchSourceBatch>`：
  - YouTube 与 B 站分别调用现有 `callMediaVideoSearch()`，每次只传一个 source，避免等待另一视频来源；
  - X、Hacker News、Reddit、知乎复用现有调用和映射函数，但每个任务写入自己的局部数组，不并发修改共享数组；
  - 媒体适配器对每来源映射结果取前 5 条；X 继续传现有 `pageSize: 5`，其他来源不扩大当前 provider 请求量。
- [ ] 仿照现有 `streamFoodProviderResultsWithPartials()`：
  - 所有来源 Promise 并行启动；
  - 每个完成回调通过一个 `partialChain` 串行合并；
  - 合并后立即调用 `onPartial`；
  - `Promise.all` 后等待 `partialChain`，返回最后一个累计结果；
  - 单来源 reject 转换为该来源 error batch，不让整个聚合 reject。
- [ ] 每次累计结果：
  - 原 `videos/posts/sourceStatuses/summary` 仍由 `aggregateSearchResultFromParts()` 生成；
  - 媒体适配器把刚到批次送入 `mergeWaterfallBatch()`；
  - `waterfall` 快照包含 loading/终态来源和排好序的候选；
  - 仅在至少一条有效候选时，HTML 入口才会出现。
- [ ] 在 `AggregateSearchA2ui.ets` 抽出 `aggregateSearchA2uiRenderState()`，数据 patch 只使用 `/aggregateSearch`；复用既有 `planA2uiPartialUpdate()`，不写第二套 envelope diff。
- [ ] 给 `callStructuredMediaTool()` 增加默认值为 `null` 的 optional observer；Data Agent 的现有调用不传 observer，仍只得到最终 `DataResult`。
- [ ] `callLocalMediaTool()` 增加 `emitJsonl` 参数，`buildLocalToolJsonl()` 透传已有 emitter。partial 时调用 planner，最终结果只返回相对最后 cache 仍有变化的 JSONL。
- [ ] `callStructuredMediaTool()` 继续返回最终 `DataResult`，不改变 Data Agent 或主 Agent 行为。
- [ ] 不为 continuation 新增 provider executor：当前来源没有已验证令牌，waterline 会诚实进入来源结束状态。

### Verification

- [ ] 完整 Hypium 通过，严格读取 `test_result.txt`。
- [ ] 检查首批测试在第二来源未 resolve 时已收到快照，证明不是 `Promise.all` 后统一回调。
- [ ] 检查最终累计结果与旧 `aggregateSearchResultFromParts()` 的视频、帖子、status 内容一致。
- [ ] 检查 `agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets`、主 Agent 和 Data Agent 没有 diff。
- [ ] 只暂存本任务 hunks并提交：

```bash
git commit -m "feat: stream aggregate media source batches"
```

---

## Task 4: 同页全屏发现流与原地 payload 更新

**Files:**

- Modify: `entry/src/main/ets/pages/A2uiHome/html/HtmlHomeTypes.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/html/HtmlHomeSnapshot.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/html/HtmlAggregateSearchHomeRenderer.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/Index.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/components/HomePage.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/components/HtmlHomeSurfaceView.ets`
- Test: `entry/src/test/HtmlHomeSnapshot.test.ets`
- Test: `entry/src/test/HtmlHomeRenderer.test.ets`

### Payload seam

```ts
export interface WaterfallHomePayload {
  surfaceId: string;
  query: string;
  candidates: WaterfallRankedCandidate[];
  sources: WaterfallSourceState[];
  replenishing: boolean;
  exhausted: boolean;
}

export function buildWaterfallHomePayload(
  document: HtmlHomeDocument,
  isBusy: boolean
): WaterfallHomePayload | null;
```

`Index.ets` 新增状态命名与现有 multi-task seam 对齐：

```ts
@State waterfallPayloadJson: string = '';
@State waterfallPayloadTick: number = 0;
private waterfallShellHtml: string = '';
```

### RED

- [ ] 在 `HtmlHomeSnapshot.test.ets` 构造含 `waterfall` 的 `/aggregateSearch` dataModel，先断言：
  - `document.kind === 'aggregate-search'`
  - `document.waterfall` 保留候选顺序、理由、source phase；
  - 原 `aggregate-video`、`aggregate-post`、`aggregate-source-status` block 数量不变。
- [ ] 在 `HtmlHomeRenderer.test.ets` 为有有效候选的聚合文档断言精确标记：

```ts
expect(html.indexOf('进入发现流')).assertLarger(-1);
expect(html.indexOf('来源偏好')).assertLarger(-1);
expect(html.indexOf('推荐理由')).assertLarger(-1);
expect(html.indexOf('window.__aiphoneApplyWaterfallUpdate')).assertLarger(-1);
expect(html.indexOf('scroll-snap-type: y mandatory')).assertLarger(-1);
```

- [ ] 同一测试继续断言原聚合页标题、筛选 rail、视频 rail、讨论列表和真实原文链接仍存在，避免用全屏流替换原结果列表。
- [ ] 增加 payload fixture 覆盖：
  - video 有封面与原链接；
  - image_text 有图片、标题与摘要；
  - post 无封面；
  - 缺失时间不包含新鲜度理由；
  - 无有效候选时没有“进入发现流”；
  - 全部来源关闭显示“至少开启一个来源”；
  - `replenishing` 显示“正在补充内容”；
  - `exhausted` 显示“本轮内容已结束”；
  - `result 3` 占位标题不在 HTML 中。
- [ ] 对 renderer 导出的 payload builder 断言候选全局顺序，不按 video/post 再分组。
- [ ] 运行完整 Hypium，从结果文件确认 RED。

### GREEN

- [ ] `HtmlHomeDocument` 添加可选 `waterfall`；`HtmlHomeSnapshot.ets` 只复制 `/aggregateSearch.waterfall`，不改现有 block 构造。
- [ ] 在现有聚合 HTML shell 中保留全部入口内容，候选非空时在筛选 rail 前加入“进入发现流”按钮。
- [ ] 同一 HTML 添加一个默认隐藏的 `position: fixed; inset: 0` 发现流容器：
  - 列表使用 `overflow-y: auto` 和 `scroll-snap-type: y mandatory`；
  - 每条使用 `min-height: 100dvh` 和 `scroll-snap-align: start`；
  - video 复用现有 thumbnail/embed/original URL；
  - image_text 使用真实 cover，失败时退回文字布局；
  - post 使用标题/摘要/source/publishedAt；
  - 固定控件只有返回、来源偏好、推荐理由。
- [ ] 页面 JavaScript 只保留当前 HTML 内存：
  - `mode` 只取 `entry / discovering / source_preferences / reason_open`；`replenishing` 和 `exhausted` 由 payload flags 呈现，不增加路由状态；
  - 进入前保存入口滚动位置和当前 aggregate filter；
  - 返回时恢复；
  - `shownIds` 和当前之后两条 stable IDs 永不被后到 payload 替换；
  - 新 payload 只合并并重排 tail，使用 payload 内 `signals`，不调用网络；
  - 来源开关使用同一确定性 signals 立即重排所有未展示项；
  - 关闭全部来源停在偏好空态；
  - 离开页面或新 surface 时状态随 HTML 销毁。
- [ ] 暴露唯一增量入口：

```js
window.__aiphoneApplyWaterfallUpdate = function (payload) {
  mergeUnseenTail(payload);
  renderWaterfallState();
};
```

- [ ] 在 `Index.ets` 仿照 multi-task：
  - 首次 `aggregate-search` 文档生成 `waterfallShellHtml`；
  - 后到同一 aggregate surface 只更新 `waterfallPayloadJson/tick`；
  - 切离 aggregate surface 时清空 shell 和 payload；
  - 原 `currentHtmlHomeHtml()` 和非 aggregate 分支不变。
- [ ] `HomePage.ets` 只透传两个 prop。
- [ ] `HtmlHomeSurfaceView.ets` 增加 watcher 和去重字段，页面 ready 后执行：

```ts
this.controller.runJavaScript(
  'if (window.__aiphoneApplyWaterfallUpdate) {' +
  'window.__aiphoneApplyWaterfallUpdate(' + this.waterfallPayloadJson + ');}'
);
```

- [ ] 不新增 Waterfall action ID：返回、筛选、来源开关、理由展开和纵滑都在页面本地完成；原链接继续使用当前安全 link/rendering seam。
- [ ] 不修改 `AnythingDemo.ets` 或新增页面。

### Verification

- [ ] 运行完整 Hypium 并严格检查结果文件。
- [ ] 重点确认 `HtmlHomeSnapshot.test`、`HtmlHomeRenderer.test` 和 `AggregateSearchA2ui.test` 都在完整测试入口中执行且没有失败。
- [ ] `git diff --check` 无空白错误。
- [ ] 搜索实现 diff，确认没有第二导航、依赖、数据库、模型、持久化或自然语言输入：

```bash
git diff -- agent_core entry | rg -n \
  "AnythingDemo|router\\.|database|sqlite|npm|ohpm|model|preferenceDescription.*parse|自然语言"
```

允许 `preferenceDescription` 的类型声明和固定空字符串传值；其他命中逐条解释或删除。
- [ ] 只暂存本任务新增 hunks并提交：

```bash
git commit -m "feat: add Waterfall discovery mode to aggregate HTML"
```

---

## Task 5: 严格回归、设备空闲构建与真机时隙门禁

**Files:**

- No production or test file changes.

### 不占设备的完整验证

- [ ] 确认工作树仍包含用户原有未提交修复，且没有被 Waterfall commits 吞入：

```bash
git status --short
git log --oneline -6
git show --stat --oneline HEAD~3..HEAD
```

- [ ] 运行 `.github/workflows/hypium.yml` 使用的完整 Hypium 命令：

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test \
  -p product=default \
  -p module=entry@default \
  -p testType=unit \
  --no-daemon
```

- [ ] 无论进程退出码为何，都检查 canonical result：

```bash
test -f entry/.test/default/intermediates/test/coverage_data/test_result.txt
tail -5 entry/.test/default/intermediates/test/coverage_data/test_result.txt
grep -Eq '^Tests run: [1-9][0-9]*, Failure: 0, Error: 0, Pass: [0-9]+, Ignore: [0-9]+$' \
  entry/.test/default/intermediates/test/coverage_data/test_result.txt
```

- [ ] 执行不占设备的 debug HAP 构建：

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap \
  --mode module \
  -p product=default \
  -p buildMode=debug \
  --no-daemon
```

- [ ] 仅列出现有 smoke 清单，确认 C08 仍映射 `media.aggregate.search`；此命令不接触设备或 provider：

```bash
node scripts/aiphone-device-smoke.mjs --list-cases
```

- [ ] 检查最终 diff：

```bash
git diff --check
git status --short
```

当前未跟踪的 `docs/research/`、`outputs/`、`tmp/` 保持原状，不清理、不暂存。

### 到达设备门禁时的报告

- [ ] 单测和 HAP 构建通过后停止，不运行任何 `hdc`、安装、启动或 smoke。
- [ ] 向协调线程报告固定状态：

```text
已准备好等待真机时隙。
设备外验证：Hypium 结果文件 Failure=0/Error=0；debug HAP 构建完成。
待真机最小清单：C08 真实来源状态；首源起流；同页进入/返回；后到批次稳定窗口；来源开关与理由；无分页来源本轮结束；原聚合列表和原始链接回归。
```

### 仅在协调线程明确授予真机时隙后

- [ ] 使用协调线程指定的 target 和当前 worktree 生成的 HAP；安装前再次确认设备时隙仍属于本任务。
- [ ] 运行 C08 对应查询：

```bash
node scripts/aiphone-device-smoke.mjs "我想看看有关 OpenAI Codex 的相关新闻和讨论"
```

- [ ] 只报告真实可见事实：
  - 至少一个真实来源有有效候选时，入口无需等待其他来源；
  - provider 缺配置、需授权、失败或空结果按实际状态显示；
  - 进入/返回留在同一聚合 HTML，无新路由；
  - 后到来源不改变已展示内容与紧邻两条；
  - 来源开关、推荐理由和有限结束态可见；
  - 原聚合列表、筛选和原始链接仍可用。
- [ ] 当前来源没有 verified continuation 时，验收“本轮内容已结束”，不要求伪造低水位网络续拉。只有设备证据中实际出现 provider continuation，才验证小批续拉和同源单飞。
- [ ] 保存现有 smoke 脚本产生的日志/截图/摘要；构建、安装、provider、可见 UI 证据分开陈述。
- [ ] 验证完成或阻塞后立即向协调线程报告并释放设备，不继续占用时隙。

---

## 分步提交范围

实现阶段预期四个代码提交，验证阶段不制造空提交：

1. `feat: add deterministic Waterfall candidate ordering`
   - 纯排序、媒体映射、对应 Hypium hunks。
2. `feat: add stable Waterfall feed state`
   - 稳定窗口、水位、单飞、结束状态、对应 Hypium hunks。
3. `feat: stream aggregate media source batches`
   - 来源并行、partial A2UI、ToolGateway emitter、对应测试 hunks。
4. `feat: add Waterfall discovery mode to aggregate HTML`
   - snapshot、同页 HTML、原地 payload bridge、renderer 测试 hunks。

每次提交前必须执行：

```bash
git diff --cached --check
git diff --cached --name-only
git diff --cached
```

若 staged diff 含有任务开始前已经存在的 `messageText`、`result N` 或其他用户修改，立即用 `git reset -p` 只取消这些 hunks 的暂存；不得回滚工作树内容。

---

## 完成定义

- 纯排序与队列测试覆盖：查询相关性、新鲜度、来源均衡、跨类型链接去重、首源起流、已展示与紧邻两条稳定、低水位、在途预留、同源单飞、无分页结束。
- 现有聚合页仍为入口，发现流只在同一 HTML 中切换；主 Agent、导航、原聚合列表和 provider 授权语义不变。
- 完整 Hypium canonical 结果为 `Failure: 0, Error: 0`，debug HAP 构建成功。
- 没有新增依赖、数据库、持久化、模型、异步 Agent、自然语言通道或未验证分页。
- 用户原有 working-tree 改动仍保留且未进入 Waterfall commits。
- 在真机时隙获批前，最终状态必须是“已准备好等待真机时隙”，不能声称真机或 provider 验证完成。
