import { HtmlHomeDocument } from './HtmlHomeTypes';

type HtmlHotelTextValue = Object | string | number | boolean | null | undefined;

interface HtmlHotelHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
}

const HOTEL_HOME_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f4f0e8;
  --panel: #fffdf8;
  --ink: #1e2825;
  --muted: #69736f;
  --line: rgba(30, 40, 37, 0.13);
  --accent: #176c60;
  --accent-soft: rgba(23, 108, 96, 0.1);
  --warning: #8a5d24;
  --warning-soft: rgba(138, 93, 36, 0.1);
  --shadow: 0 16px 38px rgba(37, 43, 39, 0.08);
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100vh;
  background: var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
}
button { font: inherit; cursor: pointer; }
button:disabled { cursor: default; opacity: 0.5; }
.hotel-shell {
  width: min(100%, 780px);
  margin: 0 auto;
  padding: 18px 14px calc(96px + env(safe-area-inset-bottom, 0px));
}
.hotel-hero {
  border-bottom: 1px solid var(--line);
  padding: 8px 2px 18px;
}
.hotel-kicker {
  color: var(--accent);
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.08em;
}
.hotel-hero h1 {
  margin: 10px 0 0;
  max-width: 18em;
  font-family: Georgia, "Songti SC", serif;
  font-size: 31px;
  line-height: 1.06;
  font-weight: 720;
}
.hotel-hero-subtitle {
  margin: 9px 0 0;
  color: var(--muted);
  font-size: 14px;
  line-height: 1.55;
}
.hotel-scene-note {
  margin-top: 14px;
  border-left: 3px solid var(--warning);
  padding: 9px 11px;
  background: var(--warning-soft);
  color: #69471e;
  font-size: 12px;
  line-height: 1.55;
}
.hotel-board-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  margin: 20px 2px 10px;
}
.hotel-board-head h2 {
  margin: 0;
  font-size: 16px;
  line-height: 1.2;
}
.hotel-count {
  color: var(--muted);
  font-size: 12px;
}
.hotel-board {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 12px;
}
.hotel-rate-card {
  overflow: hidden;
  border: 1px solid var(--line);
  border-radius: 18px;
  background: var(--panel);
  box-shadow: var(--shadow);
}
.hotel-card-media {
  width: 100%;
  height: 180px;
  object-fit: cover;
  background: var(--accent-soft);
}
.hotel-card-body { padding: 14px; }
.hotel-card-top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}
.hotel-card-copy { min-width: 0; }
.hotel-provider {
  color: var(--accent);
  font-size: 11px;
  font-weight: 800;
}
.hotel-card-title {
  margin: 6px 0 0;
  overflow-wrap: anywhere;
  font-size: 18px;
  line-height: 1.24;
}
.hotel-card-summary {
  margin: 7px 0 0;
  color: var(--muted);
  font-size: 13px;
  line-height: 1.45;
}
.hotel-price {
  flex: 0 0 auto;
  color: var(--accent);
  font-size: 18px;
  font-weight: 820;
  white-space: nowrap;
}
.hotel-identifiers {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
  margin-top: 12px;
}
.hotel-id {
  max-width: 100%;
  border: 1px solid rgba(23, 108, 96, 0.18);
  border-radius: 8px;
  padding: 6px 8px;
  background: var(--accent-soft);
  color: #22564f;
  overflow-wrap: anywhere;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 11px;
}
.hotel-facts {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0 12px;
  margin-top: 13px;
  border-top: 1px solid var(--line);
}
.hotel-fact {
  min-width: 0;
  padding: 10px 0;
  border-bottom: 1px solid var(--line);
}
.hotel-fact-label {
  color: var(--muted);
  font-size: 10px;
  line-height: 1.2;
}
.hotel-fact-value {
  margin-top: 4px;
  overflow-wrap: anywhere;
  font-size: 13px;
  font-weight: 650;
  line-height: 1.45;
}
.hotel-policy {
  margin-top: 12px;
  border-left: 3px solid var(--accent);
  padding: 9px 11px;
  background: var(--accent-soft);
}
.hotel-policy-label {
  color: var(--accent);
  font-size: 10px;
  font-weight: 800;
}
.hotel-policy-value {
  margin-top: 5px;
  font-size: 12px;
  line-height: 1.55;
}
.hotel-external {
  margin-top: 10px;
  color: var(--warning);
  overflow-wrap: anywhere;
  font-size: 11px;
  line-height: 1.5;
}
.hotel-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 13px;
}
.hotel-action {
  min-height: 40px;
  border: 1px solid var(--accent);
  border-radius: 10px;
  padding: 9px 13px;
  background: var(--accent);
  color: white;
  font-size: 13px;
  font-weight: 760;
}
.hotel-empty {
  border: 1px solid var(--line);
  border-radius: 18px;
  padding: 20px;
  background: var(--panel);
  color: var(--muted);
  text-align: center;
}
@media (min-width: 680px) {
  .hotel-board { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (prefers-reduced-motion: reduce) {
  * { scroll-behavior: auto !important; }
}
`;

const HOTEL_HOME_JS: string = `
(function () {
  var raw = document.getElementById('home-data');
  var data = raw ? JSON.parse(raw.textContent || '{}') : {};
  var app = document.getElementById('app');
  var isBusy = data.isBusy === true;
  function text(value) {
    if (value === null || value === undefined) { return ''; }
    if (typeof value === 'object') {
      try { return JSON.stringify(value); } catch (error) { return ''; }
    }
    return String(value);
  }
  function list(value) { return Array.isArray(value) ? value : []; }
  function add(parent, tag, className, content) {
    var node = document.createElement(tag);
    if (className) { node.className = className; }
    if (content !== undefined && content !== null) { node.textContent = text(content); }
    parent.appendChild(node);
    return node;
  }
  function rowValue(block, labels) {
    var rows = list(block && block.rows);
    for (var index = 0; index < rows.length; index += 1) {
      if (labels.indexOf(text(rows[index] && rows[index].label)) >= 0) {
        return text(rows[index] && rows[index].value);
      }
    }
    return '';
  }
  function metricValue(block, labels) {
    var metrics = list(block && block.metrics);
    for (var index = 0; index < metrics.length; index += 1) {
      if (labels.indexOf(text(metrics[index] && metrics[index].label)) >= 0) {
        return text(metrics[index] && metrics[index].value);
      }
    }
    return '';
  }
  function postAction(action) {
    if (isBusy) { return; }
    try {
      if (window.AIPhoneHome && typeof window.AIPhoneHome.postAction === 'function') {
        window.AIPhoneHome.postAction(JSON.stringify({
          id: text(action.id),
          label: text(action.label || action.id),
          prompt: text(action.prompt),
          variant: text(action.variant),
          kind: text(action.kind),
          args: action.args && typeof action.args === 'object' ? action.args : null
        }));
      }
    } catch (error) {}
  }
  function addActions(parent, actions) {
    var items = list(actions);
    if (items.length === 0) { return; }
    var host = add(parent, 'div', 'hotel-actions');
    items.forEach(function (action) {
      var button = add(host, 'button', 'hotel-action', action.label || action.id);
      button.type = 'button';
      button.disabled = isBusy;
      button.addEventListener('click', function () { postAction(action); });
    });
  }
  function addFact(parent, label, value) {
    if (text(value).length === 0) { return; }
    var item = add(parent, 'div', 'hotel-fact');
    add(item, 'div', 'hotel-fact-label', label);
    add(item, 'div', 'hotel-fact-value', value);
  }
  function safeImageUrl(value) {
    var url = text(value).trim();
    return url.indexOf('https://') === 0 ? url : '';
  }
  function renderCard(parent, block) {
    var card = add(parent, 'article', 'hotel-rate-card');
    var imageUrl = safeImageUrl(rowValue(block, ['酒店图片']));
    if (imageUrl.length > 0) {
      var image = add(card, 'img', 'hotel-card-media');
      image.src = imageUrl;
      image.alt = text(block && block.title) || '酒店图片';
      image.loading = 'lazy';
    }
    var body = add(card, 'div', 'hotel-card-body');
    var top = add(body, 'div', 'hotel-card-top');
    var copy = add(top, 'div', 'hotel-card-copy');
    add(copy, 'div', 'hotel-provider', text(block && block.source) || 'RollingGo');
    add(copy, 'h3', 'hotel-card-title', text(block && block.title) || '酒店结果');
    add(copy, 'p', 'hotel-card-summary', text(block && block.subtitle));
    var price = rowValue(block, ['参考价', '平均价']);
    if (price.length > 0) { add(top, 'div', 'hotel-price', price); }

    var identifiers = add(body, 'div', 'hotel-identifiers');
    var hotelId = rowValue(block, ['酒店 ID']);
    var destinationId = rowValue(block, ['Destination ID']);
    var rateId = rowValue(block, ['Rate plan ID']);
    if (hotelId.length > 0) { add(identifiers, 'span', 'hotel-id', 'hotel ' + hotelId); }
    if (destinationId.length > 0) { add(identifiers, 'span', 'hotel-id', 'destination ' + destinationId); }
    if (rateId.length > 0) { add(identifiers, 'span', 'hotel-id', 'rate ' + rateId); }
    if (identifiers.childNodes.length === 0) { identifiers.remove(); }

    var facts = add(body, 'div', 'hotel-facts');
    addFact(facts, '入住', rowValue(block, ['入住']));
    addFact(facts, '客人', rowValue(block, ['客人']));
    addFact(facts, '地址', rowValue(block, ['地址']));
    addFact(facts, '星级', rowValue(block, ['星级']));
    addFact(facts, '床型', rowValue(block, ['床型']));
    addFact(facts, '餐食', rowValue(block, ['餐食']));
    addFact(facts, '房态', rowValue(block, ['供应商确认']));
    addFact(facts, '价格说明', rowValue(block, ['价格说明']));
    addFact(facts, '设施', rowValue(block, ['设施']));
    addFact(facts, '标签', rowValue(block, ['标签']));
    if (facts.childNodes.length === 0) { facts.remove(); }

    var cancellation = rowValue(block, ['取消政策']);
    if (cancellation.length > 0) {
      var policy = add(body, 'div', 'hotel-policy');
      add(policy, 'div', 'hotel-policy-label', '取消政策');
      add(policy, 'div', 'hotel-policy-value', cancellation);
    }
    var taxNotice = rowValue(block, ['税费与有效期']);
    if (taxNotice.length > 0) {
      var notice = add(body, 'div', 'hotel-policy');
      add(notice, 'div', 'hotel-policy-label', '报价口径');
      add(notice, 'div', 'hotel-policy-value', taxNotice);
    }
    var external = rowValue(block, ['第三方预订（离开 Appless）']);
    if (external.length > 0) {
      add(body, 'div', 'hotel-external', '第三方预订（离开 Appless）：' + external);
    }
    addActions(body, block && block.actions);
  }

  var shell = add(app, 'main', 'hotel-shell');
  var hero = add(shell, 'header', 'hotel-hero');
  add(hero, 'div', 'hotel-kicker', 'LIVE HOTEL DATA · ROLLINGGO');
  add(hero, 'h1', '', text(data.title) || '酒店搜索');
  add(hero, 'p', 'hotel-hero-subtitle', text(data.subtitle));
  add(hero, 'div', 'hotel-scene-note',
    '当前仅支持真实酒店搜索与实时房型/报价查询。Appless 暂不支持创建或跟踪酒店订单；税费拆分与报价有效期以供应商最终页面为准。');

  var blocks = list(data.blocks);
  var boardHead = add(shell, 'div', 'hotel-board-head');
  var firstTool = blocks.length > 0 ? metricValue(blocks[0], ['toolName']) : '';
  add(boardHead, 'h2', '', firstTool === 'hotel.detail' ? '实时房型与取消政策' : '酒店结果');
  add(boardHead, 'div', 'hotel-count', String(blocks.length) + ' 条');
  if (blocks.length === 0) {
    add(shell, 'div', 'hotel-empty', isBusy ? '正在等待 RollingGo 返回真实数据。' : '没有可展示的酒店结果。');
    return;
  }
  var board = add(shell, 'section', 'hotel-board');
  blocks.forEach(function (block) { renderCard(board, block); });
})();
`;

export function shouldRenderHotelHomeDocument(document: HtmlHomeDocument): boolean {
  return document.kind === 'hotel';
}

export function renderHotelHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  const renderDocument: HtmlHotelHomeDocumentWithBusy = {
    version: document.version,
    source: document.source,
    kind: document.kind,
    title: document.title,
    subtitle: document.subtitle,
    chips: document.chips,
    metrics: document.metrics,
    timeline: document.timeline,
    blocks: document.blocks,
    actions: document.actions,
    history: [],
    persona: document.persona,
    personaMemory: document.personaMemory,
    rawSurfaceRoot: null,
    generatedAt: '',
    isBusy: isBusy || (document as HtmlHotelHomeDocumentWithBusy).isBusy === true
  };
  const json = escapeScriptJson(JSON.stringify(renderDocument));
  const title = escapeHtmlText(document.title.length > 0 ? document.title : '酒店搜索');
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<style>${HOTEL_HOME_CSS}</style>
</head>
<body data-scene="hotel">
<div id="app"></div>
<script id="home-data" type="application/json">${json}</script>
<script>${HOTEL_HOME_JS}</script>
</body>
</html>`;
}

function escapeScriptJson(json: string): string {
  return json
    .split('&').join('\\u0026')
    .split('<').join('\\u003c')
    .split('>').join('\\u003e')
    .split('\u2028').join('\\u2028')
    .split('\u2029').join('\\u2029');
}

function escapeHtmlText(value: HtmlHotelTextValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.toString()
    .split('&').join('&amp;')
    .split('<').join('&lt;')
    .split('>').join('&gt;')
    .split('"').join('&quot;');
}
