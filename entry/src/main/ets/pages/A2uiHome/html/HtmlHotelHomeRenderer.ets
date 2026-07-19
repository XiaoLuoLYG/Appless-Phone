import { HtmlHomeDocument } from './HtmlHomeTypes';

type HtmlHotelTextValue = Object | string | number | boolean | null | undefined;

interface HtmlHotelHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
}

const HOTEL_HOME_CSS: string = `
:root {
  color-scheme: light;
  --canvas: #f5f6f8;
  --surface: #ffffff;
  --surface-muted: #f1f3f5;
  --ink: #17191c;
  --muted: #6e737a;
  --line: rgba(23, 25, 28, 0.1);
  --accent: #17685d;
  --accent-soft: rgba(23, 104, 93, 0.09);
  --shadow: 0 12px 34px rgba(20, 24, 28, 0.08);
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100vh;
  background: var(--canvas);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
}
button { font: inherit; cursor: pointer; -webkit-tap-highlight-color: transparent; }
button:disabled { cursor: default; opacity: 0.5; }
button:focus-visible {
  outline: 3px solid rgba(23, 104, 93, 0.28);
  outline-offset: 2px;
}
.hotel-shell {
  width: min(100%, 760px);
  margin: 0 auto;
  padding: 12px 12px calc(92px + env(safe-area-inset-bottom, 0px));
}
.hotel-hero {
  position: relative;
  min-height: 264px;
  overflow: hidden;
  border-radius: 26px;
  background: #273c38;
  box-shadow: var(--shadow);
}
.hotel-hero-media {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(circle at 78% 22%, rgba(117, 160, 149, 0.48), transparent 38%),
    linear-gradient(145deg, #314c46, #17231f);
}
.hotel-hero-media::after {
  position: absolute;
  inset: 0;
  background: linear-gradient(180deg, rgba(9, 15, 13, 0.05) 18%, rgba(9, 15, 13, 0.82) 100%);
  content: "";
}
.hotel-hero-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.hotel-hero-content {
  position: relative;
  z-index: 1;
  display: flex;
  min-height: 264px;
  flex-direction: column;
  justify-content: flex-end;
  padding: 24px 20px 20px;
  color: #ffffff;
}
.hotel-kicker {
  color: rgba(255, 255, 255, 0.82);
  font-size: 11px;
  font-weight: 720;
  letter-spacing: 0.04em;
}
.hotel-hero h1 {
  margin: 8px 0 0;
  max-width: 16em;
  overflow-wrap: anywhere;
  font-size: clamp(26px, 8vw, 36px);
  line-height: 1.08;
  font-weight: 760;
  letter-spacing: -0.025em;
}
.hotel-hero-subtitle {
  margin: 8px 0 0;
  color: rgba(255, 255, 255, 0.82);
  font-size: 14px;
  line-height: 1.45;
}
.hotel-truth {
  display: inline-flex;
  width: fit-content;
  align-items: center;
  gap: 7px;
  margin-top: 13px;
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 999px;
  padding: 6px 9px;
  background: rgba(12, 20, 18, 0.34);
  color: rgba(255, 255, 255, 0.9);
  font-size: 11px;
  line-height: 1.2;
  -webkit-backdrop-filter: blur(12px);
  backdrop-filter: blur(12px);
}
.hotel-truth-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #8ce0c8;
  box-shadow: 0 0 0 3px rgba(140, 224, 200, 0.15);
}
.hotel-board-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  margin: 22px 4px 10px;
}
.hotel-board-head h2 {
  margin: 0;
  font-size: 17px;
  line-height: 1.2;
}
.hotel-count {
  color: var(--muted);
  font-size: 12px;
}
.hotel-board {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 10px;
}
.hotel-rate-card {
  overflow: hidden;
  border: 1px solid var(--line);
  border-radius: 20px;
  background: var(--surface);
  box-shadow: 0 6px 22px rgba(20, 24, 28, 0.05);
  transition: border-color 180ms ease, box-shadow 180ms ease;
}
.hotel-rate-card.is-expanded {
  border-color: rgba(23, 104, 93, 0.22);
  box-shadow: var(--shadow);
}
.hotel-card-main {
  display: grid;
  grid-template-columns: 108px minmax(0, 1fr);
  gap: 12px;
  padding: 12px;
}
.hotel-card-main.no-media {
  grid-template-columns: minmax(0, 1fr);
}
.hotel-card-media-wrap {
  min-height: 112px;
  overflow: hidden;
  border-radius: 14px;
  background: var(--surface-muted);
}
.hotel-card-media {
  width: 100%;
  height: 100%;
  min-height: 112px;
  object-fit: cover;
}
.hotel-card-body { min-width: 0; }
.hotel-card-top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}
.hotel-card-copy { min-width: 0; }
.hotel-provider {
  color: var(--muted);
  font-size: 10px;
  font-weight: 680;
}
.hotel-card-title {
  margin: 4px 0 0;
  overflow-wrap: anywhere;
  font-size: 17px;
  line-height: 1.25;
}
.hotel-card-summary {
  margin: 5px 0 0;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.4;
}
.hotel-card-location {
  margin: 5px 0 0;
  overflow: hidden;
  color: var(--muted);
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 11px;
}
.hotel-price {
  flex: 0 0 auto;
  color: var(--ink);
  font-size: 16px;
  font-weight: 820;
  white-space: nowrap;
}
.hotel-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
  margin-top: 9px;
}
.hotel-tag {
  max-width: 12em;
  overflow: hidden;
  border-radius: 999px;
  padding: 4px 7px;
  background: var(--surface-muted);
  color: #555b61;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 10px;
}
.hotel-card-toggle {
  display: inline-flex;
  min-height: 44px;
  align-items: center;
  gap: 6px;
  margin-top: 6px;
  border: 0;
  padding: 9px 2px;
  background: transparent;
  color: var(--accent);
  font-size: 11px;
  font-weight: 720;
}
.hotel-toggle-icon {
  display: inline-block;
  font-size: 15px;
  transition: transform 180ms ease;
}
.hotel-card-toggle[aria-expanded="true"] .hotel-toggle-icon {
  transform: rotate(180deg);
}
.hotel-card-details {
  border-top: 1px solid var(--line);
  padding: 4px 14px 14px;
}
.hotel-card-details[hidden] {
  display: none;
}
.hotel-facts {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0 12px;
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
  margin-top: 10px;
  border-radius: 12px;
  padding: 10px 11px;
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
.hotel-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 13px;
}
.hotel-action {
  min-height: 44px;
  border: 1px solid var(--accent);
  border-radius: 12px;
  padding: 10px 14px;
  background: var(--accent);
  color: white;
  font-size: 13px;
  font-weight: 760;
}
.hotel-empty {
  border: 1px solid var(--line);
  border-radius: 18px;
  padding: 20px;
  background: var(--surface);
  color: var(--muted);
  text-align: center;
}
@media (max-width: 420px) {
  .hotel-card-main { grid-template-columns: 92px minmax(0, 1fr); gap: 10px; }
  .hotel-card-media-wrap,
  .hotel-card-media { min-height: 104px; }
  .hotel-price { font-size: 15px; }
}
@media (min-width: 680px) {
  .hotel-shell { padding-top: 18px; }
  .hotel-hero,
  .hotel-hero-content { min-height: 322px; }
  .hotel-hero-content { padding: 30px 28px 26px; }
  .hotel-card-main { grid-template-columns: 136px minmax(0, 1fr); }
}
@media (prefers-contrast: more) {
  :root { --line: rgba(23, 25, 28, 0.3); }
  .hotel-truth { border-color: rgba(255, 255, 255, 0.55); background: rgba(0, 0, 0, 0.64); }
}
@media (prefers-reduced-transparency: reduce) {
  .hotel-truth {
    background: rgba(12, 20, 18, 0.86);
    -webkit-backdrop-filter: none;
    backdrop-filter: none;
  }
}
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    scroll-behavior: auto !important;
    transition-duration: 0.01ms !important;
  }
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
  function addTag(parent, value) {
    var label = text(value).trim();
    if (label.length === 0) { return; }
    add(parent, 'span', 'hotel-tag', label);
  }
  function setExpanded(card, details, button, expanded) {
    card.classList.toggle('is-expanded', expanded);
    details.hidden = !expanded;
    button.setAttribute('aria-expanded', expanded ? 'true' : 'false');
    var label = button.querySelector('.hotel-toggle-label');
    if (label) { label.textContent = expanded ? '收起详情' : '查看详情'; }
  }
  function renderCard(parent, block, cardIndex) {
    var card = add(parent, 'article', 'hotel-rate-card');
    var main = add(card, 'div', 'hotel-card-main');
    var imageUrl = safeImageUrl(rowValue(block, ['酒店图片']));
    if (imageUrl.length > 0) {
      var media = add(main, 'div', 'hotel-card-media-wrap');
      var image = add(media, 'img', 'hotel-card-media');
      image.src = imageUrl;
      image.alt = text(block && block.title) || '酒店图片';
      image.loading = 'lazy';
      image.onerror = function () {
        media.remove();
        main.classList.add('no-media');
      };
    } else {
      main.classList.add('no-media');
    }
    var body = add(main, 'div', 'hotel-card-body');
    var top = add(body, 'div', 'hotel-card-top');
    var copy = add(top, 'div', 'hotel-card-copy');
    add(copy, 'div', 'hotel-provider', (text(block && block.source) || 'RollingGo') + ' 实时');
    add(copy, 'h3', 'hotel-card-title', text(block && block.title) || '酒店结果');
    add(copy, 'p', 'hotel-card-summary', text(block && block.subtitle));
    var location = rowValue(block, ['地址']);
    if (location.length > 0) { add(copy, 'p', 'hotel-card-location', location); }
    var price = rowValue(block, ['参考价', '平均价']);
    if (price.length > 0) { add(top, 'div', 'hotel-price', price); }

    var tags = add(body, 'div', 'hotel-tags');
    addTag(tags, rowValue(block, ['星级']));
    addTag(tags, rowValue(block, ['床型']));
    addTag(tags, rowValue(block, ['餐食']));
    addTag(tags, rowValue(block, ['标签']));
    if (tags.childNodes.length === 0) { tags.remove(); }

    var detailsId = 'hotel-card-details-' + String(cardIndex);
    var toggle = add(body, 'button', 'hotel-card-toggle');
    toggle.type = 'button';
    toggle.setAttribute('aria-controls', detailsId);
    add(toggle, 'span', 'hotel-toggle-label', '查看详情');
    add(toggle, 'span', 'hotel-toggle-icon', '⌄');

    var details = add(card, 'div', 'hotel-card-details');
    details.id = detailsId;
    var facts = add(details, 'div', 'hotel-facts');
    addFact(facts, '入住', rowValue(block, ['入住']));
    addFact(facts, '客人', rowValue(block, ['客人']));
    addFact(facts, '地址', rowValue(block, ['地址']));
    addFact(facts, '星级', rowValue(block, ['星级']));
    addFact(facts, '床型', rowValue(block, ['床型']));
    addFact(facts, '餐食', rowValue(block, ['餐食']));
    addFact(facts, '房态', rowValue(block, ['供应商确认']));
    addFact(facts, '参考价口径', rowValue(block, ['参考价口径']));
    addFact(facts, '价格说明', rowValue(block, ['价格说明']));
    addFact(facts, '设施', rowValue(block, ['设施']));
    addFact(facts, '标签', rowValue(block, ['标签']));
    if (facts.childNodes.length === 0) { facts.remove(); }

    var cancellation = rowValue(block, ['取消政策']);
    if (cancellation.length > 0) {
      var policy = add(details, 'div', 'hotel-policy');
      add(policy, 'div', 'hotel-policy-label', '取消政策');
      add(policy, 'div', 'hotel-policy-value', cancellation);
    }
    var taxNotice = rowValue(block, ['税费与有效期']);
    if (taxNotice.length > 0) {
      var notice = add(details, 'div', 'hotel-policy');
      add(notice, 'div', 'hotel-policy-label', '报价口径');
      add(notice, 'div', 'hotel-policy-value', taxNotice);
    }
    addActions(details, block && block.actions);
    toggle.addEventListener('click', function () {
      setExpanded(card, details, toggle, toggle.getAttribute('aria-expanded') !== 'true');
    });
    setExpanded(card, details, toggle, false);
  }

  var blocks = list(data.blocks);
  var shell = add(app, 'main', 'hotel-shell');
  var hero = add(shell, 'header', 'hotel-hero');
  var heroMedia = add(hero, 'div', 'hotel-hero-media');
  var heroImageUrl = blocks.length > 0 ? safeImageUrl(rowValue(blocks[0], ['酒店图片'])) : '';
  if (heroImageUrl.length > 0) {
    var heroImage = add(heroMedia, 'img', 'hotel-hero-image');
    heroImage.src = heroImageUrl;
    heroImage.alt = '';
    heroImage.setAttribute('aria-hidden', 'true');
    heroImage.onerror = function () { heroImage.remove(); };
  }
  var heroContent = add(hero, 'div', 'hotel-hero-content');
  add(heroContent, 'div', 'hotel-kicker', '酒店 · 实时房价');
  add(heroContent, 'h1', '', text(data.title) || '酒店搜索');
  add(heroContent, 'p', 'hotel-hero-subtitle', text(data.subtitle));
  var truth = add(heroContent, 'div', 'hotel-truth');
  add(truth, 'span', 'hotel-truth-dot');
  add(truth, 'span', '', 'RollingGo 实时数据 · 当前仅支持查询');

  var boardHead = add(shell, 'div', 'hotel-board-head');
  var firstTool = blocks.length > 0 ? metricValue(blocks[0], ['toolName']) : '';
  add(boardHead, 'h2', '', firstTool === 'hotel.detail' ? '实时房型与取消政策' : '酒店结果');
  add(boardHead, 'div', 'hotel-count', String(blocks.length) + ' 条');
  if (blocks.length === 0) {
    add(shell, 'div', 'hotel-empty', isBusy ? '正在等待 RollingGo 返回真实数据。' : '没有可展示的酒店结果。');
    return;
  }
  var board = add(shell, 'section', 'hotel-board');
  blocks.forEach(function (block, index) { renderCard(board, block, index); });
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
