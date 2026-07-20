import { HtmlHomeDocument } from './HtmlHomeTypes';

type HtmlHotelTextValue = Object | string | number | boolean | null | undefined;

interface HtmlHotelHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
}

const HOTEL_HOME_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f5f2ee;
  --panel: rgba(255, 252, 247, 0.94);
  --panel-strong: #fffdf9;
  --ink: #211b17;
  --ink-soft: #4d423a;
  --muted: #7a6e64;
  --line: rgba(33, 27, 23, 0.11);
  --accent: #995f4c;
  --accent-soft: rgba(153, 95, 76, 0.11);
  --shadow: 0 12px 30px rgba(63, 44, 32, 0.08);
  --ease-out: cubic-bezier(0.23, 1, 0.32, 1);
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
button { font: inherit; cursor: pointer; -webkit-tap-highlight-color: transparent; }
button:disabled { cursor: default; opacity: 0.5; }
button:focus-visible {
  outline: 3px solid rgba(153, 95, 76, 0.28);
  outline-offset: 2px;
}
button:active { transform: scale(0.98); }
.hotel-shell {
  width: min(100%, 760px);
  min-height: 100vh;
  margin: 0 auto;
  padding-bottom: calc(92px + env(safe-area-inset-bottom, 0px));
  overflow: hidden;
}
.hotel-hero {
  position: relative;
  min-height: 360px;
  display: flex;
  align-items: flex-end;
  overflow: hidden;
  isolation: isolate;
}
.hotel-hero-media {
  position: absolute;
  inset: 0;
  z-index: -2;
  background:
    linear-gradient(180deg, rgba(33, 24, 18, 0.08) 0%, rgba(33, 24, 18, 0.18) 44%, rgba(245, 242, 238, 0.98) 100%),
    url("https://images.unsplash.com/photo-1742844551986-de16fd4682c3?auto=format&fit=crop&w=1200&q=82"),
    linear-gradient(145deg, #d8c1aa, #f1e6da);
  background-position: center;
  background-size: cover;
  transform: scale(1.02);
}
.hotel-hero-media::after {
  position: absolute;
  inset: 0;
  background:
    linear-gradient(90deg, rgba(255, 250, 244, 0.76) 0%, rgba(255, 250, 244, 0.28) 58%, rgba(255, 250, 244, 0.08) 100%);
  content: "";
}
.hotel-hero-content {
  width: 100%;
  padding: 68px 18px 24px;
}
.hotel-back {
  position: absolute;
  top: 18px;
  left: 18px;
  min-height: 44px;
  border: 1px solid rgba(33, 27, 23, 0.14);
  border-radius: 14px;
  padding: 10px 13px;
  background: rgba(255, 250, 244, 0.86);
  color: var(--ink);
  font-size: 12px;
  font-weight: 760;
  box-shadow: 0 8px 20px rgba(63, 44, 32, 0.08);
  backdrop-filter: blur(16px);
  transition: transform 140ms var(--ease-out), background-color 180ms ease;
}
.hotel-kicker {
  display: inline-flex;
  min-height: 28px;
  align-items: center;
  border: 1px solid rgba(33, 27, 23, 0.13);
  border-radius: 999px;
  padding: 7px 10px;
  background: rgba(255, 250, 244, 0.82);
  color: var(--ink-soft);
  font-size: 12px;
  font-weight: 780;
  line-height: 1;
  backdrop-filter: blur(14px);
}
.hotel-hero h1 {
  margin: 14px 0 0;
  max-width: 10em;
  overflow-wrap: anywhere;
  font-family: Georgia, "Times New Roman", "Songti SC", serif;
  font-size: clamp(38px, 11vw, 50px);
  line-height: 0.98;
  font-weight: 760;
  letter-spacing: -0.035em;
}
.hotel-hero.is-detail h1 {
  max-width: 14em;
  font-size: clamp(32px, 9vw, 42px);
  line-height: 1.02;
}
.hotel-hero-subtitle {
  width: fit-content;
  max-width: 31em;
  margin: 11px 0 0;
  border: 1px solid rgba(33, 27, 23, 0.1);
  border-radius: 16px;
  padding: 8px 10px;
  background: rgba(255, 250, 244, 0.76);
  color: var(--ink-soft);
  font-size: 13px;
  font-weight: 620;
  line-height: 1.5;
  backdrop-filter: blur(14px);
}
.hotel-context {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
  margin-top: 12px;
}
.hotel-context-item {
  border-radius: 11px;
  padding: 8px 10px;
  background: rgba(255, 250, 244, 0.84);
  color: var(--ink-soft);
  font-size: 11px;
  font-weight: 720;
  line-height: 1.2;
  backdrop-filter: blur(14px);
}
.hotel-provider-line {
  margin-top: 10px;
  color: rgba(33, 27, 23, 0.72);
  font-size: 11px;
  font-weight: 760;
}
.hotel-board-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  margin: 22px 18px 11px;
}
.hotel-board-head h2 {
  margin: 0;
  font-size: 19px;
  line-height: 1.2;
  letter-spacing: -0.015em;
}
.hotel-count {
  color: var(--muted);
  font-size: 12px;
  font-variant-numeric: tabular-nums;
}
.hotel-board {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 10px;
  padding: 0 14px;
}
.hotel-search-card,
.hotel-room-card {
  overflow: hidden;
  border: 1px solid var(--line);
  background: var(--panel);
  box-shadow: 0 6px 20px rgba(63, 44, 32, 0.045);
}
.hotel-search-card {
  display: grid;
  grid-template-columns: 112px minmax(0, 1fr);
  border-radius: 18px;
}
.hotel-search-card.no-media { grid-template-columns: minmax(0, 1fr); }
.hotel-search-media {
  min-height: 158px;
  overflow: hidden;
  background: #e9e1d9;
}
.hotel-search-image {
  display: block;
  width: 100%;
  height: 100%;
  min-height: 158px;
  object-fit: cover;
}
.hotel-search-body {
  min-width: 0;
  display: flex;
  flex-direction: column;
  padding: 13px 13px 12px;
}
.hotel-provider {
  color: var(--accent);
  font-size: 10px;
  font-weight: 780;
}
.hotel-card-title {
  margin: 5px 0 0;
  overflow-wrap: anywhere;
  font-size: 17px;
  line-height: 1.25;
  letter-spacing: -0.012em;
}
.hotel-location {
  margin: 6px 0 0;
  overflow: hidden;
  color: var(--muted);
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 11px;
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
  border-radius: 8px;
  padding: 5px 7px;
  background: rgba(33, 27, 23, 0.055);
  color: var(--ink-soft);
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 10px;
  font-weight: 650;
}
.hotel-search-footer {
  display: flex;
  align-items: flex-end;
  justify-content: flex-start;
  gap: 8px;
  margin-top: auto;
  padding-top: 12px;
}
.hotel-action-row {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
  margin-top: 10px;
}
.hotel-price { min-width: 0; }
.hotel-price-value {
  color: var(--ink);
  font-size: 17px;
  font-weight: 830;
  line-height: 1.05;
  font-variant-numeric: tabular-nums;
}
.hotel-price-note {
  margin-top: 4px;
  overflow: hidden;
  color: var(--muted);
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 9px;
}
.hotel-card-cta {
  flex: 0 0 auto;
  min-height: 40px;
  border: 0;
  border-radius: 12px;
  padding: 9px 11px;
  background: var(--ink);
  color: #fffaf4;
  font-size: 11px;
  font-weight: 760;
  transition: transform 140ms var(--ease-out), background-color 180ms ease;
}
.hotel-card-cta-secondary {
  border: 1px solid var(--line);
  background: var(--panel-strong);
  color: var(--ink);
}
.hotel-room-card {
  border-radius: 17px;
}
.hotel-room-main {
  padding: 15px 15px 5px;
}
.hotel-room-top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 14px;
}
.hotel-room-copy { min-width: 0; }
.hotel-room-title {
  margin: 5px 0 0;
  overflow-wrap: anywhere;
  font-size: 18px;
  line-height: 1.24;
  letter-spacing: -0.015em;
}
.hotel-room-price {
  flex: 0 0 auto;
  text-align: right;
}
.hotel-room-toggle {
  display: flex;
  width: 100%;
  min-height: 48px;
  align-items: center;
  justify-content: space-between;
  border: 0;
  border-top: 1px solid var(--line);
  padding: 12px 15px;
  background: transparent;
  color: var(--accent);
  font-size: 12px;
  font-weight: 760;
  transition: transform 140ms var(--ease-out), background-color 180ms ease;
}
.hotel-toggle-icon {
  display: inline-block;
  font-size: 15px;
  transition: transform 180ms var(--ease-out);
}
.hotel-room-toggle[aria-expanded="true"] .hotel-toggle-icon {
  transform: rotate(180deg);
}
.hotel-room-details {
  border-top: 1px solid var(--line);
  padding: 4px 15px 15px;
  background: var(--panel-strong);
}
.hotel-room-details[hidden] { display: none; }
.hotel-facts {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0 14px;
}
.hotel-fact {
  min-width: 0;
  padding: 11px 0;
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
  margin-top: 11px;
  border-radius: 12px;
  padding: 11px 12px;
  background: var(--accent-soft);
}
.hotel-policy-label {
  color: var(--accent);
  font-size: 10px;
  font-weight: 800;
}
.hotel-policy-value {
  margin-top: 5px;
  color: var(--ink-soft);
  font-size: 12px;
  line-height: 1.55;
}
.hotel-empty {
  margin: 0 14px;
  border: 1px solid var(--line);
  border-radius: 18px;
  padding: 22px;
  background: var(--panel);
  color: var(--muted);
  text-align: center;
}
@media (min-width: 680px) {
  .hotel-hero { min-height: 420px; }
  .hotel-hero-content { padding: 80px 28px 30px; }
  .hotel-back { left: 28px; }
  .hotel-board { padding: 0 20px; }
  .hotel-board-head { margin-right: 24px; margin-left: 24px; }
  .hotel-search-card { grid-template-columns: 150px minmax(0, 1fr); }
}
@media (hover: hover) and (pointer: fine) {
  .hotel-back:hover { background: rgba(255, 250, 244, 0.98); }
  .hotel-card-cta:hover { background: var(--accent); }
  .hotel-room-toggle:hover { background: rgba(153, 95, 76, 0.05); }
}
@media (prefers-reduced-transparency: reduce) {
  .hotel-back,
  .hotel-kicker,
  .hotel-hero-subtitle,
  .hotel-context-item { background: #fffaf4; backdrop-filter: none; }
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
  function safeImageUrl(value) {
    var url = text(value).trim();
    return url.indexOf('https://') === 0 ? url : '';
  }
  function splitValues(value) {
    return text(value).split(/\\s*[·、,，;；]\\s*/).filter(function (item) {
      return item.trim().length > 0;
    });
  }
  function moneyText(value) {
    var rawValue = text(value).trim();
    var match = rawValue.match(/^([0-9]+(?:\\.[0-9]+)?)\\s+([A-Z]{3})$/);
    if (!match) { return rawValue; }
    var symbols = { CNY: '¥', USD: '$', GBP: '£', EUR: '€' };
    var amount = Number(match[1]);
    var formatted = Number.isFinite(amount) ? amount.toLocaleString('zh-CN', { maximumFractionDigits: 2 }) : match[1];
    return (symbols[match[2]] || match[2] + ' ') + formatted;
  }
  function postAction(action) {
    if (isBusy || !action) { return; }
    try {
      if (window.AIPhoneHome && typeof window.AIPhoneHome.postAction === 'function') {
        window.AIPhoneHome.postAction(JSON.stringify(action));
      }
    } catch (error) {}
  }
  function actionFor(block, id) {
    var actions = list(block && block.actions);
    for (var index = 0; index < actions.length; index += 1) {
      if (text(actions[index] && actions[index].id) === id) { return actions[index]; }
    }
    return null;
  }
  function objectArgs(value) {
    return value !== null && typeof value === 'object' && !Array.isArray(value);
  }
  function positiveHotelId(args) {
    return Number.isInteger(args.hotelId) && args.hotelId > 0;
  }
  function compactPhone(value) {
    if (typeof value !== 'string') { return ''; }
    var compact = value.replace(/[ ()-]/g, '');
    return /^\\+?[0-9]{5,20}$/.test(compact) ? compact : '';
  }
  function sanitizeHotelAction(action) {
    var actionId = text(action && action.id);
    var argsObject = objectArgs(action && action.args);
    var args = argsObject ? action.args : {};
    var hotelIdPositive = argsObject && positiveHotelId(args);
    var evidence = {
      actionId: actionId,
      argsObject: argsObject,
      hotelIdPositive: hotelIdPositive,
      argsValid: false
    };
    if (actionId === 'hotel.navigate') {
      evidence.latitudeValid = Number.isFinite(args.latitude) && args.latitude >= -90 && args.latitude <= 90;
      evidence.longitudeValid = Number.isFinite(args.longitude) && args.longitude >= -180 && args.longitude <= 180;
      evidence.coordinatesValid = evidence.latitudeValid && evidence.longitudeValid;
      evidence.argsValid = hotelIdPositive && evidence.coordinatesValid;
    } else if (actionId === 'hotel.call') {
      evidence.providerPresent = typeof args.provider === 'string' && args.provider.trim().length > 0;
      evidence.providerPlaceIdPresent =
        typeof args.providerPlaceId === 'string' && args.providerPlaceId.trim().length > 0;
      var displayCompact = compactPhone(args.displayPhone);
      var dialCompact = compactPhone(args.dialPhone);
      evidence.phoneShapeValid = dialCompact.length > 0;
      evidence.phoneMatchesDisplay = displayCompact.length > 0 && displayCompact === dialCompact;
      evidence.maskedSuffix = evidence.phoneShapeValid ? '***' + dialCompact.slice(-4) : '';
      evidence.argsValid = hotelIdPositive &&
        evidence.providerPresent &&
        evidence.providerPlaceIdPresent &&
        evidence.phoneShapeValid &&
        evidence.phoneMatchesDisplay;
      displayCompact = '';
      dialCompact = '';
      args = {};
      action = null;
    } else if (actionId === 'hotel.detail') {
      evidence.clickLabel = typeof action.label === 'string' ? action.label.trim() : '';
      evidence.argsValid = hotelIdPositive;
    }
    return evidence;
  }
  window.collectHotelSmokeEvidence = function () {
    var byActionId = {};
    list(data.blocks).forEach(function (block) {
      list(block && block.actions).forEach(function (action) {
        var actionId = text(action && action.id);
        if (/^hotel\\.(detail|navigate|call|book)$/.test(actionId)) {
          var sanitized = sanitizeHotelAction(action);
          var current = byActionId[actionId];
          if (!current || (current.argsValid && !sanitized.argsValid)) {
            byActionId[actionId] = sanitized;
          }
        }
      });
    });
    var evidence = ['hotel.detail', 'hotel.navigate', 'hotel.call', 'hotel.book']
      .map(function (actionId) { return byActionId[actionId]; })
      .filter(function (action) { return !!action; });
    return JSON.stringify({
      surfaceId: text(data.surfaceId),
      actions: evidence
    });
  };
  function addTag(parent, value) {
    var label = text(value).trim();
    if (label.length > 0) { add(parent, 'span', 'hotel-tag', label); }
  }
  function searchTags(block) {
    var tags = [];
    var star = rowValue(block, ['星级']).trim();
    if (/^[1-5](?:\\.0)?$/.test(star)) { tags.push(star.charAt(0) + ' 星酒店'); }
    splitValues(rowValue(block, ['设施'])).slice(0, 1).forEach(function (value) { tags.push(value); });
    splitValues(rowValue(block, ['标签'])).slice(0, 1).forEach(function (value) { tags.push(value); });
    return tags.slice(0, 3);
  }
  function roomTags(block) {
    var tags = [];
    [rowValue(block, ['床型']), rowValue(block, ['餐食']), rowValue(block, ['供应商确认'])].forEach(function (value) {
      if (text(value).trim().length > 0 && text(value).trim() !== '供应商未返回') { tags.push(value); }
    });
    return tags.slice(0, 3);
  }
  function addPrice(parent, value, note) {
    var host = add(parent, 'div', 'hotel-price');
    add(host, 'div', 'hotel-price-value', moneyText(value));
    if (text(note).length > 0) { add(host, 'div', 'hotel-price-note', note); }
    return host;
  }
  function renderSearchCard(parent, block) {
    var detailAction = actionFor(block, 'hotel.detail');
    var navigateAction = actionFor(block, 'hotel.navigate');
    var callAction = actionFor(block, 'hotel.call');
    var card = add(parent, 'article', 'hotel-search-card');
    var imageUrl = safeImageUrl(rowValue(block, ['酒店图片']));
    if (imageUrl.length > 0) {
      var media = add(card, 'div', 'hotel-search-media');
      var image = add(media, 'img', 'hotel-search-image');
      image.src = imageUrl;
      image.alt = text(block && block.title) + ' 酒店照片';
      image.loading = 'lazy';
      image.onerror = function () {
        media.remove();
        card.classList.add('no-media');
      };
    } else {
      card.classList.add('no-media');
    }
    var body = add(card, 'div', 'hotel-search-body');
    add(body, 'div', 'hotel-provider', (text(block && block.source) || 'RollingGo') + ' 实时');
    add(body, 'h3', 'hotel-card-title', text(block && block.title) || '酒店结果');
    var location = rowValue(block, ['地址']);
    if (location.length > 0) { add(body, 'p', 'hotel-location', location); }
    var tags = add(body, 'div', 'hotel-tags');
    searchTags(block).forEach(function (value) { addTag(tags, value); });
    if (tags.childNodes.length === 0) { tags.remove(); }
    var footer = add(body, 'div', 'hotel-search-footer');
    addPrice(footer, rowValue(block, ['参考价']), rowValue(block, ['价格说明']) || '参考价');
    var actionRow = add(body, 'div', 'hotel-action-row');
    if (detailAction) {
      var button = add(actionRow, 'button', 'hotel-card-cta hotel-card-cta-primary', detailAction.label);
      button.type = 'button';
      button.disabled = isBusy;
      button.setAttribute('aria-label', text(detailAction.label) + '：' + text(block && block.title));
      button.addEventListener('click', function () { postAction(detailAction); });
    }
    if (navigateAction) {
      var navigateButton = add(actionRow, 'button', 'hotel-card-cta hotel-card-cta-secondary', navigateAction.label);
      navigateButton.type = 'button';
      navigateButton.disabled = isBusy;
      navigateButton.addEventListener('click', function () { postAction(navigateAction); });
    }
    if (callAction) {
      var callButton = add(actionRow, 'button', 'hotel-card-cta hotel-card-cta-secondary', callAction.label);
      callButton.type = 'button';
      callButton.disabled = isBusy;
      callButton.addEventListener('click', function () { postAction(callAction); });
    }
    if (actionRow.childNodes.length === 0) { actionRow.remove(); }
  }
  function addFact(parent, label, value) {
    if (text(value).length === 0) { return; }
    var item = add(parent, 'div', 'hotel-fact');
    add(item, 'div', 'hotel-fact-label', label);
    add(item, 'div', 'hotel-fact-value', value);
  }
  function setExpanded(card, details, button, expanded) {
    card.classList.toggle('is-expanded', expanded);
    details.hidden = !expanded;
    button.setAttribute('aria-expanded', expanded ? 'true' : 'false');
    var label = button.querySelector('.hotel-toggle-label');
    if (label) { label.textContent = expanded ? '收起价格规则' : '价格与取消规则'; }
  }
  function addPolicy(parent, label, value) {
    if (text(value).length === 0) { return; }
    var policy = add(parent, 'div', 'hotel-policy');
    add(policy, 'div', 'hotel-policy-label', label);
    add(policy, 'div', 'hotel-policy-value', value);
  }
  function renderRoomCard(parent, block, cardIndex) {
    var card = add(parent, 'article', 'hotel-room-card');
    var main = add(card, 'div', 'hotel-room-main');
    var top = add(main, 'div', 'hotel-room-top');
    var copy = add(top, 'div', 'hotel-room-copy');
    add(copy, 'div', 'hotel-provider', (text(block && block.source) || 'RollingGo') + ' 房型');
    add(copy, 'h3', 'hotel-room-title', text(block && block.title) || '房型报价');
    var roomPrice = add(top, 'div', 'hotel-room-price');
    addPrice(roomPrice, rowValue(block, ['平均价']), '晚均参考');
    var tags = add(main, 'div', 'hotel-tags');
    roomTags(block).forEach(function (value) { addTag(tags, value); });
    if (tags.childNodes.length === 0) { tags.remove(); }

    var detailsId = 'hotel-room-details-' + String(cardIndex);
    var toggle = add(card, 'button', 'hotel-room-toggle');
    toggle.type = 'button';
    toggle.setAttribute('aria-controls', detailsId);
    add(toggle, 'span', 'hotel-toggle-label', '价格与取消规则');
    add(toggle, 'span', 'hotel-toggle-icon', '⌄');

    var details = add(card, 'div', 'hotel-room-details');
    details.id = detailsId;
    var facts = add(details, 'div', 'hotel-facts');
    addFact(facts, '入住', rowValue(block, ['入住']));
    addFact(facts, '客人', rowValue(block, ['客人']));
    addFact(facts, '房态', rowValue(block, ['供应商确认']));
    if (facts.childNodes.length === 0) { facts.remove(); }
    addPolicy(details, '取消政策', rowValue(block, ['取消政策']));
    addPolicy(details, '报价说明', rowValue(block, ['税费与有效期']));
    toggle.addEventListener('click', function () {
      setExpanded(card, details, toggle, toggle.getAttribute('aria-expanded') !== 'true');
    });
    setExpanded(card, details, toggle, false);
  }

  var allBlocks = list(data.blocks);
  var detailBlocks = allBlocks.filter(function (block) {
    return metricValue(block, ['toolName']) === 'hotel.detail';
  });
  var isDetail = detailBlocks.length > 0;
  var blocks = isDetail ? detailBlocks : allBlocks;
  var shell = add(app, 'main', 'hotel-shell');
  var hero = add(shell, 'header', isDetail ? 'hotel-hero is-detail' : 'hotel-hero');
  add(hero, 'div', 'hotel-hero-media');
  var heroContent = add(hero, 'div', 'hotel-hero-content');
  if (isDetail && blocks.length > 0) {
    var restoreAction = actionFor(blocks[0], 'hotel.search.restore');
    if (restoreAction) {
      var back = add(heroContent, 'button', 'hotel-back', '← 返回酒店结果');
      back.type = 'button';
      back.disabled = isBusy;
      back.addEventListener('click', function () { postAction(restoreAction); });
    }
  }
  add(heroContent, 'div', 'hotel-kicker', isDetail ? '酒店 · 实时房型' : '酒店 · 实时搜索');
  add(heroContent, 'h1', '', text(data.title) || (isDetail ? '实时房型' : '酒店搜索'));
  add(heroContent, 'p', 'hotel-hero-subtitle', text(data.subtitle));
  if (blocks.length > 0) {
    var context = add(heroContent, 'div', 'hotel-context');
    var stay = rowValue(blocks[0], ['入住']);
    var guests = rowValue(blocks[0], ['客人']);
    if (stay.length > 0) { add(context, 'span', 'hotel-context-item', stay); }
    if (guests.length > 0) { add(context, 'span', 'hotel-context-item', guests); }
    if (context.childNodes.length === 0) { context.remove(); }
  }
  add(heroContent, 'div', 'hotel-provider-line', 'RollingGo 实时查询');

  var boardHead = add(shell, 'div', 'hotel-board-head');
  add(boardHead, 'h2', '', isDetail ? '房型与价格规则' : '酒店结果');
  add(boardHead, 'div', 'hotel-count', String(blocks.length) + (isDetail ? ' 个报价' : ' 家酒店'));
  if (blocks.length === 0) {
    add(shell, 'div', 'hotel-empty', isBusy ? '正在查询酒店数据。' : '没有符合条件的酒店结果。');
    return;
  }
  var board = add(shell, 'section', 'hotel-board');
  blocks.forEach(function (block, index) {
    if (isDetail) { renderRoomCard(board, block, index); } else { renderSearchCard(board, block); }
  });
})();
`;

export function shouldRenderHotelHomeDocument(document: HtmlHomeDocument): boolean {
  return document.kind === 'hotel';
}

export function renderHotelHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  const renderDocument: HtmlHotelHomeDocumentWithBusy = {
    version: document.version,
    surfaceId: document.surfaceId === undefined ? '' : document.surfaceId,
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
