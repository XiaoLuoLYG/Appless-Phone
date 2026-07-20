import { HtmlHomeDocument } from './HtmlHomeTypes';
import { APP_LOGO_AMAP, APP_LOGO_BAIDU_MAPS, APP_LOGO_GOOGLE_MAPS, APP_LOGO_KFC, APP_LOGO_LUCKIN, APP_LOGO_MCDONALDS, APP_LOGO_MEITUAN, APP_LOGO_TAOBAO, APP_LOGO_TENCENT_MAPS } from './AppLogoDataUri';
import { personaAvatarDataUri } from './PersonaAvatarDataUri';

type HtmlFoodTextValue = Object | string | number | boolean | null | undefined;

interface HtmlFoodHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
  personaAvatarDataUri?: string;
}

const FOOD_HOME_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f5f2ee;
  --panel: rgba(255, 255, 255, 0.88);
  --panel-strong: #ffffff;
  --ink: #211b17;
  --ink-soft: #493f38;
  --muted: #7a6e64;
  --line: rgba(33, 27, 23, 0.12);
  --accent: #995f4c;
  --accent-soft: rgba(153, 95, 76, 0.13);
  --cream: #ffffff;
  --tomato: #d8492f;
  --gold: #d8a63f;
  --food-amap: #16875b;
  --food-tencent: #1f79a9;
  --food-baidu: #b94b65;
  --food-meituan: #c27a10;
  --food-taobao: #d95d1b;
  --food-mcd: #b97908;
  --food-kfc: #c8102e;
  --food-luckin: #356fc0;
  --food-google-maps: #4285f4;
  --food-local: #815f3e;
  --shadow: 0 10px 28px rgba(44, 34, 26, 0.08);
  --radius-xl: 20px;
  --radius-lg: 16px;
  --radius-md: 12px;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100vh;
  background: var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  letter-spacing: 0;
  -webkit-font-smoothing: antialiased;
}
button { font: inherit; cursor: pointer; }
button:disabled { cursor: default; opacity: 0.5; }
.editorial-food-shell {
  width: min(100%, 760px);
  min-height: 100vh;
  margin: 0 auto;
  padding-bottom: calc(84px + env(safe-area-inset-bottom, 0px));
  background: var(--paper);
}
.editorial-cover {
  position: relative;
  min-height: 360px;
  padding: 22px 18px 22px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  background: linear-gradient(145deg, #2f1b10 0%, #9d673e 48%, #f0bc58 100%);
  color: #fff;
}
.editorial-cover-media {
  position: absolute;
  inset: 0;
  background:
    linear-gradient(180deg, rgba(24, 13, 8, 0.18) 0%, rgba(24, 13, 8, 0.2) 38%, rgba(24, 13, 8, 0.76) 100%),
    url("https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80"),
    linear-gradient(145deg, #2f1b10 0%, #9d673e 48%, #f0bc58 100%);
  background-size: cover;
  background-position: center;
  transform: scale(1.02);
}
.editorial-cover::after {
  content: "";
  position: absolute;
  inset: auto 0 0;
  height: 58px;
  background: linear-gradient(180deg, rgba(248, 242, 232, 0), var(--paper));
}
.editorial-cover-content {
  position: relative;
  z-index: 1;
}
.persona-banner {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 14px;
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: 18px;
  padding: 10px 12px;
  background: rgba(23, 18, 13, 0.38);
  color: #fffaf1;
  backdrop-filter: blur(16px);
}
.persona-avatar {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 14px;
  background: rgba(255, 250, 241, 0.9);
  color: var(--food-luckin);
  font-size: 15px;
  font-weight: 840;
}
.persona-avatar img {
  width: 30px;
  height: 30px;
  object-fit: contain;
}
.persona-copy {
  min-width: 0;
  flex: 1 1 auto;
}
.persona-title {
  font-size: 14px;
  font-weight: 840;
  line-height: 1.25;
}
.persona-subtitle {
  margin-top: 4px;
  color: rgba(255, 250, 241, 0.78);
  font-size: 12px;
  line-height: 1.4;
}
.editorial-kicker {
  display: inline-flex;
  align-items: center;
  min-height: 28px;
  padding: 7px 10px;
  border: 1px solid rgba(255, 255, 255, 0.34);
  border-radius: 999px;
  background: rgba(23, 18, 13, 0.28);
  color: #fff7e9;
  font-size: 12px;
  font-weight: 800;
  line-height: 1;
  backdrop-filter: blur(14px);
}
.editorial-cover h1 {
  margin: 18px 0 10px;
  max-width: 7.4em;
  overflow-wrap: anywhere;
  font-family: Georgia, "Times New Roman", "Songti SC", serif;
  font-size: 48px;
  line-height: 0.96;
  font-weight: 760;
}
.editorial-cover p {
  margin: 0;
  max-width: 27em;
  overflow-wrap: anywhere;
  color: rgba(255, 250, 241, 0.86);
  font-size: 14px;
  line-height: 1.55;
}
.source-cloud {
  position: relative;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 18px;
}
.source-pill {
  --source-accent: var(--food-local);
  border: 1px solid rgba(255, 255, 255, 0.26);
  border-radius: 999px;
  padding: 8px 10px;
  max-width: 100%;
  background: rgba(23, 18, 13, 0.44);
  color: #fffaf1;
  font-size: 11px;
  font-weight: 820;
  line-height: 1;
  overflow-wrap: anywhere;
  box-shadow: inset 0 -2px 0 var(--source-accent);
  backdrop-filter: blur(16px);
}
.source-pill[data-source-key="food-amap"], .editorial-card[data-source-key="food-amap"], .editorial-feature[data-source-key="food-amap"] { --source-accent: var(--food-amap); }
.source-pill[data-source-key="food-tencent"], .editorial-card[data-source-key="food-tencent"], .editorial-feature[data-source-key="food-tencent"] { --source-accent: var(--food-tencent); }
.source-pill[data-source-key="food-baidu"], .editorial-card[data-source-key="food-baidu"], .editorial-feature[data-source-key="food-baidu"] { --source-accent: var(--food-baidu); }
.source-pill[data-source-key="food-meituan"], .editorial-card[data-source-key="food-meituan"], .editorial-feature[data-source-key="food-meituan"] { --source-accent: var(--food-meituan); }
.source-pill[data-source-key="food-taobao"], .editorial-card[data-source-key="food-taobao"], .editorial-feature[data-source-key="food-taobao"] { --source-accent: var(--food-taobao); }
.source-pill[data-source-key="food-mcd"], .editorial-card[data-source-key="food-mcd"], .editorial-feature[data-source-key="food-mcd"] { --source-accent: var(--food-mcd); }
.source-pill[data-source-key="food-kfc"], .editorial-card[data-source-key="food-kfc"], .editorial-feature[data-source-key="food-kfc"] { --source-accent: var(--food-kfc); }
.source-pill[data-source-key="food-luckin"], .editorial-card[data-source-key="food-luckin"], .editorial-feature[data-source-key="food-luckin"] { --source-accent: var(--food-luckin); }
.source-pill[data-source-key="food-google-maps"], .editorial-card[data-source-key="food-google-maps"], .editorial-feature[data-source-key="food-google-maps"] { --source-accent: var(--food-google-maps); }
.source-pill[data-source-key="food-local"], .editorial-card[data-source-key="food-local"], .editorial-feature[data-source-key="food-local"] { --source-accent: var(--food-local); }
.cover-stats {
  position: relative;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 9px;
  margin-top: 14px;
}
.cover-stat {
  border-radius: 999px;
  padding: 8px 10px;
  background: rgba(255, 250, 241, 0.9);
  color: var(--ink);
  font-size: 11px;
  font-weight: 840;
  line-height: 1;
}
.editorial-tabs {
  position: sticky;
  top: 0;
  z-index: 6;
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 12px 14px;
  background: rgba(248, 242, 232, 0.9);
  backdrop-filter: blur(16px);
  border-bottom: 1px solid rgba(23, 18, 13, 0.06);
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}
.editorial-tabs::-webkit-scrollbar { display: none; }
.editorial-tab {
  flex: 0 0 auto;
  border: 1px solid var(--line);
  border-radius: 999px;
  min-height: 38px;
  padding: 10px 14px;
  background: rgba(255, 250, 241, 0.92);
  color: var(--ink);
  font-size: 12px;
  font-weight: 780;
  line-height: 1;
  box-shadow: 0 8px 18px rgba(37, 24, 13, 0.06);
  transition: transform 140ms ease, box-shadow 140ms ease, background 140ms ease;
}
.editorial-tab.active {
  border-color: var(--ink);
  background: var(--ink);
  color: var(--cream);
  box-shadow: 0 12px 24px rgba(37, 24, 13, 0.18);
}
.editorial-tab:active { transform: translateY(1px); }
.editorial-feature {
  --source-accent: var(--food-local);
  margin: 10px 14px 18px;
  overflow: hidden;
  border-radius: var(--radius-xl);
  background: #17120d;
  color: #fffaf1;
  box-shadow: var(--shadow);
}
.editorial-feature-media {
  min-height: 160px;
  background:
    linear-gradient(180deg, rgba(23, 18, 13, 0.02) 0%, rgba(23, 18, 13, 0.08) 48%, rgba(23, 18, 13, 0.36) 100%),
    url("https://images.unsplash.com/photo-1552566626-52f8b828add9?auto=format&fit=crop&w=900&q=80"),
    linear-gradient(135deg, #17120d 0%, var(--source-accent) 72%, #e8b451 100%);
  background-size: cover;
  background-position: center;
}
.editorial-feature-copy {
  padding: 14px;
}
.editorial-feature-label {
  color: var(--gold);
  font-size: 11px;
  font-weight: 860;
  line-height: 1;
}
.editorial-feature h2 {
  margin: 9px 0 8px;
  overflow-wrap: anywhere;
  font-family: Georgia, "Times New Roman", "Songti SC", serif;
  font-size: 29px;
  line-height: 1.02;
  font-weight: 760;
}
.editorial-feature p {
  margin: 0;
  color: rgba(255, 250, 241, 0.78);
  font-size: 13px;
  line-height: 1.55;
  overflow-wrap: anywhere;
}
.editorial-list {
  display: grid;
  gap: 10px;
  padding: 0 14px 18px;
}
.editorial-card {
  --source-accent: var(--food-local);
  position: relative;
  overflow: hidden;
  border: 1px solid var(--line);
  border-radius: var(--radius-lg);
  padding: 12px;
  background:
    linear-gradient(135deg, rgba(255, 250, 241, 0.98), rgba(255, 247, 231, 0.92)),
    rgba(255, 250, 241, 0.94);
  box-shadow: 0 14px 34px rgba(37, 24, 13, 0.1);
}
.editorial-card::before {
  content: "";
  position: absolute;
  inset: 0 auto 0 0;
  width: 6px;
  background: linear-gradient(180deg, var(--source-accent), rgba(216, 166, 63, 0.36));
}
.editorial-card-head {
  display: grid;
  grid-template-columns: 46px minmax(0, 1fr) auto;
  gap: 10px;
  align-items: start;
}
.merchant-avatar {
  position: relative;
  display: grid;
  place-items: center;
  width: 46px;
  height: 46px;
  overflow: hidden;
  border: 1px solid rgba(23, 18, 13, 0.08);
  border-radius: 16px;
  background: var(--cream);
  box-shadow: 0 10px 22px rgba(37, 24, 13, 0.12);
}
.merchant-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.merchant-avatar.multi {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0;
  padding: 5px;
}
.merchant-avatar.multi img {
  width: 25px;
  height: 25px;
  flex: 0 0 auto;
  margin-left: -8px;
  border: 1px solid var(--cream);
  border-radius: 9px;
}
.merchant-avatar.multi img:first-child {
  margin-left: 0;
}
.merchant-avatar-fallback {
  color: #fffaf1;
  font-size: 18px;
  font-weight: 900;
  line-height: 1;
}
.editorial-title { min-width: 0; }
.editorial-title h2 {
  margin: 0;
  overflow-wrap: anywhere;
  font-size: 19px;
  line-height: 1.12;
  font-weight: 860;
}
.editorial-meta {
  margin-top: 7px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.editorial-source-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 9px;
}
.editorial-source {
  border-radius: 999px;
  padding: 6px 8px;
  background: rgba(23, 18, 13, 0.06);
  color: var(--source-accent);
  font-size: 10px;
  font-weight: 820;
  line-height: 1;
  overflow-wrap: anywhere;
}
.editorial-expand {
  flex: 0 0 auto;
  appearance: none;
  -webkit-appearance: none;
  border: 0;
  border-radius: 0;
  min-width: 0;
  min-height: 0;
  padding: 2px 0 4px;
  background: transparent;
  color: var(--muted);
  font: inherit;
  font-size: 11px;
  font-weight: 760;
  line-height: 1.2;
  white-space: nowrap;
  box-shadow: none;
  border-bottom: 1px solid rgba(122, 103, 79, 0.34);
}
.editorial-card.expanded .editorial-expand {
  color: var(--source-accent);
  border-bottom-color: currentColor;
}
.editorial-card:not(.expanded) .editorial-detail {
  display: none;
}
.editorial-detail {
  margin-top: 10px;
  border-top: 1px solid var(--line);
  padding-top: 10px;
}
.editorial-detail-grid {
  display: grid;
  gap: 7px;
}
.editorial-detail-row {
  display: grid;
  grid-template-columns: 72px minmax(0, 1fr);
  gap: 10px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.editorial-detail-row b {
  color: var(--ink);
  font-weight: 760;
}
.editorial-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 10px;
}
.editorial-action {
  border: 0;
  border-radius: 999px;
  min-height: 42px;
  padding: 10px 16px;
  background: linear-gradient(135deg, var(--tomato), #a82f1e);
  color: var(--cream);
  font-size: 13px;
  font-weight: 820;
  box-shadow: 0 12px 22px rgba(216, 73, 47, 0.22);
}
.editorial-action.secondary {
  background: linear-gradient(135deg, var(--ink), #3c2b1d);
  color: var(--cream);
  box-shadow: 0 12px 22px rgba(37, 24, 13, 0.2);
}
.editorial-empty {
  border: 1px dashed rgba(23, 18, 13, 0.18);
  border-radius: var(--radius-md);
  padding: 18px;
  background: rgba(255, 250, 241, 0.7);
  color: var(--muted);
  line-height: 1.55;
  overflow-wrap: anywhere;
}
@media (min-width: 620px) {
  .editorial-cover { min-height: 430px; padding: 36px 28px 30px; }
  .editorial-cover h1 { font-size: 58px; }
  .editorial-feature { margin-left: 22px; margin-right: 22px; }
  .editorial-list { padding-left: 22px; padding-right: 22px; grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (max-width: 360px) {
  .editorial-cover h1 { font-size: 40px; }
  .editorial-feature h2 { font-size: 29px; }
  .merchant-avatar { width: 42px; height: 42px; border-radius: 15px; }
  .merchant-avatar img { width: 100%; height: 100%; }
}
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-duration: 0.001ms !important;
  }
}
.editorial-cover {
  min-height: 280px;
}
.editorial-cover h1 {
  font-family: inherit;
  font-size: 34px;
  line-height: 1.04;
}
.editorial-feature h2 {
  font-family: inherit;
  font-size: 24px;
}
.editorial-card {
  box-shadow: none;
}
.merchant-avatar {
  border-radius: 12px;
  box-shadow: none;
}
.editorial-tab,
.editorial-expand,
.editorial-action {
  transition: transform 140ms ease, background-color 140ms ease, border-color 140ms ease;
}
.editorial-tab:active,
.editorial-expand:active,
.editorial-action:active {
  transform: scale(0.98);
}
`;

const FOOD_HOME_JS: string = `
(function () {
  var node = document.getElementById('home-data');
  var data = {};
  try { data = JSON.parse(node && node.textContent ? node.textContent : '{}') || {}; } catch (error) { data = {}; }
  var app = document.getElementById('app');
  if (!app) { return; }
  var state = { filter: 'all', expandedKey: '' };
  var AVATAR_MCDONALDS = '${APP_LOGO_MCDONALDS}';
  var AVATAR_KFC = '${APP_LOGO_KFC}';
  var AVATAR_TAOBAO = '${APP_LOGO_TAOBAO}';
  var AVATAR_AMAP = '${APP_LOGO_AMAP}';
  var AVATAR_TENCENT = '${APP_LOGO_TENCENT_MAPS}';
  var AVATAR_BAIDU = '${APP_LOGO_BAIDU_MAPS}';
  var AVATAR_MEITUAN = '${APP_LOGO_MEITUAN}';
  var AVATAR_LUCKIN = '${APP_LOGO_LUCKIN}';
  var AVATAR_GOOGLE_MAPS = '${APP_LOGO_GOOGLE_MAPS}';
  var AVATAR_LOCAL = '';
  function text(value) { return value === undefined || value === null ? '' : String(value); }
  function list(value) { return Array.isArray(value) ? value : []; }
  var isBusy = text(data.isBusy).toLowerCase() === 'true';
  function add(parent, tag, className, value) {
    var el = document.createElement(tag);
    if (className) { el.className = className; }
    if (value !== undefined && value !== null && text(value).length > 0) { el.textContent = text(value); }
    parent.appendChild(el);
    return el;
  }
  function metric(block, labels) {
    var items = list(block && block.metrics).concat(list(block && block.rows));
    for (var i = 0; i < items.length; i += 1) {
      var label = text(items[i] && items[i].label);
      if (labels.indexOf(label) >= 0) { return text(items[i] && items[i].value); }
    }
    return '';
  }
  function numberIn(value) {
    var match = text(value).replace(/,/g, '').match(/[0-9]+(?:\\.[0-9]+)?/);
    return match ? Number(match[0]) : Number.NaN;
  }
  function distanceMeters(value) {
    var raw = text(value).toLowerCase();
    var n = numberIn(raw);
    if (!(n >= 0)) { return Number.POSITIVE_INFINITY; }
    return raw.indexOf('km') >= 0 || raw.indexOf('公里') >= 0 ? n * 1000 : n;
  }
  function sourceParts(block) {
    var raw = text(block && block.source) || metric(block, ['source', 'provider', 'sourceTag']);
    return raw.split(/[\\/|,，、]+/).map(function (part) { return part.trim(); }).filter(Boolean);
  }
  function sourceKey(block) {
    var parts = sourceParts(block);
    if (parts.length > 1) { return 'food-local'; }
    var raw = [parts.join(' '), text(block && block.title), text(block && block.subtitle)].join(' ').toLowerCase();
    if (raw.indexOf('amap') >= 0 || raw.indexOf('gaode') >= 0 || raw.indexOf('高德') >= 0) { return 'food-amap'; }
    if (raw.indexOf('tencent') >= 0 || raw.indexOf('腾讯') >= 0) { return 'food-tencent'; }
    if (raw.indexOf('baidu') >= 0 || raw.indexOf('百度') >= 0) { return 'food-baidu'; }
    if (raw.indexOf('meituan') >= 0 || raw.indexOf('美团') >= 0) { return 'food-meituan'; }
    if (raw.indexOf('taobao') >= 0 || raw.indexOf('淘宝') >= 0 || raw.indexOf('闪购') >= 0) { return 'food-taobao'; }
    if (raw.indexOf('mcd') >= 0 || raw.indexOf('mcdonald') >= 0 || raw.indexOf('麦当劳') >= 0) { return 'food-mcd'; }
    if (raw.indexOf('kfc') >= 0 || raw.indexOf('肯德基') >= 0) { return 'food-kfc'; }
    if (raw.indexOf('luckin') >= 0 || raw.indexOf('瑞幸') >= 0) { return 'food-luckin'; }
    if (raw.indexOf('google maps') >= 0 || raw.indexOf('google places') >= 0) { return 'food-google-maps'; }
    return 'food-local';
  }
  function avatarData(block) {
    var parts = sourceParts(block);
    if (parts.length > 1) { return AVATAR_LOCAL; }
    var raw = [parts.join(' '), text(block && block.title), text(block && block.subtitle)].join(' ').toLowerCase();
    if (raw.indexOf('mcd') >= 0 || raw.indexOf('mcdonald') >= 0 || raw.indexOf('麦当劳') >= 0) { return AVATAR_MCDONALDS; }
    if (raw.indexOf('kfc') >= 0 || raw.indexOf('肯德基') >= 0) { return AVATAR_KFC; }
    if (raw.indexOf('taobao') >= 0 || raw.indexOf('淘宝') >= 0 || raw.indexOf('闪购') >= 0) { return AVATAR_TAOBAO; }
    if (raw.indexOf('amap') >= 0 || raw.indexOf('gaode') >= 0 || raw.indexOf('高德') >= 0) { return AVATAR_AMAP; }
    if (raw.indexOf('tencent') >= 0 || raw.indexOf('腾讯') >= 0) { return AVATAR_TENCENT; }
    if (raw.indexOf('baidu') >= 0 || raw.indexOf('百度') >= 0) { return AVATAR_BAIDU; }
    if (raw.indexOf('meituan') >= 0 || raw.indexOf('美团') >= 0) { return AVATAR_MEITUAN; }
    if (raw.indexOf('luckin') >= 0 || raw.indexOf('瑞幸') >= 0) { return AVATAR_LUCKIN; }
    if (raw.indexOf('google maps') >= 0 || raw.indexOf('google places') >= 0) { return AVATAR_GOOGLE_MAPS; }
    return AVATAR_LOCAL;
  }
  function avatarInitial(block) {
    var raw = text(block && block.title).trim() || sourceParts(block).join('').trim() || '食';
    return raw.slice(0, 1);
  }
  function addAvatar(parent, block) {
    var wrap = add(parent, 'div', 'merchant-avatar');
    var sources = sourceParts(block);
    if (sources.length > 1) {
      wrap.className += ' multi';
      sources.slice(0, 3).forEach(function (source) {
        var sourceAvatar = avatarData({ source: source });
        if (sourceAvatar === AVATAR_LOCAL) { return; }
        var sourceImg = add(wrap, 'img');
        sourceImg.src = sourceAvatar;
        sourceImg.alt = '';
        sourceImg.setAttribute('aria-hidden', 'true');
      });
      if (wrap.children.length > 0) { return; }
    }
    var src = avatarData(block);
    if (src.length > 0) {
      var img = add(wrap, 'img');
      img.src = src;
      img.alt = '';
      img.setAttribute('aria-hidden', 'true');
      return;
    }
    add(wrap, 'span', 'merchant-avatar-fallback', avatarInitial(block));
  }
  function hasLocation(block) {
    return text(metric(block, ['location'])).length > 0;
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
  function setExpanded(key) {
    state.expandedKey = state.expandedKey === key ? '' : key;
    Array.prototype.slice.call(document.querySelectorAll('.editorial-card')).forEach(function (card) {
      var expanded = card.getAttribute('data-card-key') === state.expandedKey;
      card.classList.toggle('expanded', expanded);
      card.setAttribute('aria-expanded', expanded ? 'true' : 'false');
      var button = card.querySelector('.editorial-expand');
      if (button) { button.textContent = expanded ? '收起' : '展开'; }
    });
  }
  function matchesFilter(node) {
    var haystack = text(node.getAttribute('data-search')).toLowerCase();
    if (state.filter === 'featured') { return node.getAttribute('data-featured') === 'true'; }
    if (state.filter === 'within_1km') { return distanceMeters(node.getAttribute('data-distance')) <= 1000; }
    if (state.filter === 'source') { return text(node.getAttribute('data-sources')).length > 0; }
    if (state.filter === 'coffee') { return haystack.indexOf('咖啡') >= 0 || haystack.indexOf('coffee') >= 0 || haystack.indexOf('瑞幸') >= 0 || haystack.indexOf('luckin') >= 0; }
    if (state.filter === 'late') { return haystack.indexOf('深夜') >= 0 || haystack.indexOf('夜') >= 0 || haystack.indexOf('宵夜') >= 0; }
    if (state.filter === 'group') { return haystack.indexOf('聚餐') >= 0 || haystack.indexOf('火锅') >= 0 || haystack.indexOf('烧烤') >= 0; }
    if (state.filter === 'light') { return haystack.indexOf('轻食') >= 0 || haystack.indexOf('沙拉') >= 0 || haystack.indexOf('简餐') >= 0; }
    return true;
  }
  function applyFilter() {
    var cards = Array.prototype.slice.call(document.querySelectorAll('.editorial-card'));
    var feature = document.querySelector('.editorial-feature');
    if (feature) { feature.style.display = matchesFilter(feature) ? '' : 'none'; }
    var visible = 0;
    cards.forEach(function (card) {
      var keep = matchesFilter(card);
      if (keep) { visible += 1; }
      card.style.display = keep ? '' : 'none';
    });
    var count = document.getElementById('editorial-count');
    if (count) { count.textContent = String(visible) + ' / ' + String(cards.length) + ' 条'; }
    var empty = document.getElementById('editorial-filter-empty');
    if (empty) { empty.style.display = cards.length > 0 && visible === 0 ? '' : 'none'; }
    Array.prototype.slice.call(document.querySelectorAll('.editorial-tab')).forEach(function (button) {
      var active = button.getAttribute('data-filter') === state.filter;
      button.classList.toggle('active', active);
    });
  }
  function handleFilter(action) {
    var id = text(action && action.id);
    if (id === 'food_filter_featured') { state.filter = 'featured'; applyFilter(); return true; }
    if (id === 'food_filter_1km') { state.filter = 'within_1km'; applyFilter(); return true; }
    if (id === 'food_filter_source') { state.filter = 'source'; applyFilter(); return true; }
    if (id === 'food_filter_coffee') { state.filter = 'coffee'; applyFilter(); return true; }
    if (id === 'food_filter_late') { state.filter = 'late'; applyFilter(); return true; }
    if (id === 'food_filter_group') { state.filter = 'group'; applyFilter(); return true; }
    if (id === 'food_filter_light') { state.filter = 'light'; applyFilter(); return true; }
    if (id === 'food_show_all') { state.filter = 'all'; applyFilter(); return true; }
    return false;
  }
  function detailRow(parent, label, value) {
    if (text(value).length === 0) { return; }
    var row = add(parent, 'div', 'editorial-detail-row');
    add(row, 'b', '', label);
    add(row, 'span', '', value);
  }
  function renderPersonaBanner(parent) {
    var persona = data.persona || {};
    var memory = data.personaMemory || {};
    var name = text(persona.name);
    if (text(persona.id).length === 0 || name.length === 0) {
      return;
    }
    var banner = add(parent, 'section', 'persona-banner');
    var avatar = add(banner, 'div', 'persona-avatar');
    var avatarSrc = text(data.personaAvatarDataUri);
    if (avatarSrc.length > 0) {
      var img = add(avatar, 'img');
      img.src = avatarSrc;
      img.alt = '';
      img.setAttribute('aria-hidden', 'true');
    } else {
      avatar.textContent = name.slice(0, 1);
    }
    var copy = add(banner, 'div', 'persona-copy');
    add(copy, 'div', 'persona-title', name + '上线');
    add(copy, 'div', 'persona-subtitle', text(memory.summary) || text(persona.reason));
  }
  app.textContent = '';
  var shell = add(app, 'main', 'editorial-food-shell');
  var blocks = list(data.blocks).filter(function (block) { return text(block && block.kind) === 'food-result'; });
  var hero = add(shell, 'header', 'editorial-cover');
  add(hero, 'div', 'editorial-cover-media');
  var heroContent = add(hero, 'div', 'editorial-cover-content');
  add(heroContent, 'div', 'editorial-kicker', '附近餐饮 · 今日编辑');
  add(heroContent, 'h1', '', '今日附近值得吃');
  add(heroContent, 'p', '', text(data.subtitle) || text(data.title) || '从真实餐饮结果里挑出今天可以出发的一餐。');
  renderPersonaBanner(heroContent);
  var sourceCloud = add(hero, 'div', 'source-cloud');
  var seenSources = {};
  blocks.forEach(function (block) {
    sourceParts(block).forEach(function (source) {
      if (seenSources[source]) { return; }
      seenSources[source] = true;
      var pill = add(sourceCloud, 'span', 'source-pill', source);
      pill.setAttribute('data-source-key', sourceKey({ source: source }));
    });
  });
  if (Object.keys(seenSources).length === 0) { sourceCloud.style.display = 'none'; }
  var stats = add(hero, 'div', 'cover-stats');
  var count = add(stats, 'span', 'cover-stat', String(blocks.length) + ' 条');
  count.id = 'editorial-count';
  add(stats, 'span', 'cover-stat', String(blocks.filter(hasLocation).length) + ' 家可导航');
  var tabs = add(shell, 'nav', 'editorial-tabs');
  [
    ['food_show_all', '全部', 'all'],
    ['food_filter_featured', '精选', 'featured'],
    ['food_filter_1km', '1公里内', 'within_1km'],
    ['food_filter_source', '来源', 'source'],
    ['food_filter_coffee', '咖啡', 'coffee'],
    ['food_filter_late', '深夜', 'late'],
    ['food_filter_group', '聚餐', 'group'],
    ['food_filter_light', '轻食', 'light']
  ].forEach(function (item) {
    var button = add(tabs, 'button', 'editorial-tab', item[1]);
    button.type = 'button';
    button.disabled = isBusy;
    button.setAttribute('data-action', item[0]);
    button.setAttribute('data-filter', item[2]);
    button.addEventListener('click', function () { handleFilter({ id: item[0], label: item[1] }); });
  });
  if (blocks.length > 0) {
    var featureBlock = blocks[0];
    var feature = add(shell, 'section', 'editorial-feature');
    feature.setAttribute('data-card-key', text(featureBlock.id) || '0');
    feature.setAttribute('data-source-key', sourceKey(featureBlock));
    feature.setAttribute('data-distance', metric(featureBlock, ['distance']));
    feature.setAttribute('data-featured', 'true');
    feature.setAttribute('data-sources', sourceParts(featureBlock).join(' / '));
    feature.setAttribute('data-search', [text(featureBlock.title), text(featureBlock.subtitle), metric(featureBlock, ['category']), metric(featureBlock, ['address']), sourceParts(featureBlock).join(' ')].join(' '));
    add(feature, 'div', 'editorial-feature-media');
    var featureCopy = add(feature, 'div', 'editorial-feature-copy');
    add(featureCopy, 'div', 'editorial-feature-label', '今日编辑');
    add(featureCopy, 'h2', '', text(featureBlock.title) || '餐饮结果');
    add(featureCopy, 'p', '', [metric(featureBlock, ['distance']), metric(featureBlock, ['address']), sourceParts(featureBlock).join(' / ')].filter(Boolean).join(' · '));
  }
  var listNode = add(shell, 'section', 'editorial-list');
  var empty = add(listNode, 'div', 'editorial-empty', '当前筛选下暂无匹配餐饮。');
  empty.id = 'editorial-filter-empty';
  empty.style.display = 'none';
  blocks.forEach(function (block, index) {
    var key = text(block.id) || String(index);
    var card = add(listNode, 'article', 'editorial-card');
    card.setAttribute('data-card-key', key);
    card.setAttribute('data-source-key', sourceKey(block));
    card.setAttribute('data-distance', metric(block, ['distance']));
    card.setAttribute('data-featured', index === 0 ? 'true' : 'false');
    card.setAttribute('data-sources', sourceParts(block).join(' / '));
    card.setAttribute('data-search', [text(block.title), text(block.subtitle), metric(block, ['category']), metric(block, ['address']), sourceParts(block).join(' ')].join(' '));
    card.setAttribute('aria-expanded', 'false');
    var head = add(card, 'div', 'editorial-card-head');
    addAvatar(head, block);
    var title = add(head, 'div', 'editorial-title');
    add(title, 'h2', '', text(block.title) || '餐饮结果');
    add(title, 'div', 'editorial-meta', [metric(block, ['distance']), metric(block, ['address'])].filter(Boolean).join(' · '));
    var expand = add(head, 'button', 'editorial-expand', '展开');
    expand.type = 'button';
    expand.addEventListener('click', function (event) { event.stopPropagation(); setExpanded(key); });
    card.addEventListener('click', function () { setExpanded(key); });
    var sources = sourceParts(block);
    if (sources.length > 0) {
      var sourceRow = add(card, 'div', 'editorial-source-row');
      sources.forEach(function (source) { add(sourceRow, 'span', 'editorial-source', source); });
    }
    var detail = add(card, 'div', 'editorial-detail');
    var grid = add(detail, 'div', 'editorial-detail-grid');
    detailRow(grid, '地址', metric(block, ['address']));
    detailRow(grid, '分类', metric(block, ['category']) || text(block.subtitle));
    detailRow(grid, '距离', metric(block, ['distance']));
    detailRow(grid, '坐标', metric(block, ['location']));
    detailRow(grid, '来源', sourceParts(block).join(' / '));
    var canNavigate = hasLocation(block);
    var availableActions = list(block.actions).filter(function (action) {
      var id = text(action && action.id);
      if (id !== 'html_open_food_map' && id !== 'html_pin_food') { return false; }
      if (!canNavigate) { return false; }
      return true;
    });
    if (availableActions.length > 0) {
      var row = add(detail, 'div', 'editorial-actions');
      availableActions.forEach(function (action) {
        var id = text(action && action.id);
        var button = add(row, 'button', id === 'html_open_food_map' ? 'editorial-action' : 'editorial-action secondary',
          id === 'html_open_food_map' ? '导航去' : '固定到桌面');
        button.type = 'button';
        button.disabled = isBusy;
        button.addEventListener('click', function (event) { event.stopPropagation(); postAction(action); });
      });
    }
  });
  applyFilter();
})();
`;

export function shouldRenderFoodHomeDocument(document: HtmlHomeDocument): boolean {
  if (document.kind !== 'food') {
    return false;
  }
  const blocks = document.blocks;
  for (let index = 0; index < blocks.length; index++) {
    if (blocks[index].kind === 'food-result') {
      return true;
    }
  }
  return false;
}

export function renderFoodHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  const renderDocument: HtmlFoodHomeDocumentWithBusy = {
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
    personaAvatarDataUri: personaAvatarDataUri(document.persona.avatarKey),
    rawSurfaceRoot: null,
    generatedAt: '',
    isBusy: isBusy || (document as HtmlFoodHomeDocumentWithBusy).isBusy === true
  };
  const json = escapeScriptJson(JSON.stringify(renderDocument));
  const title = escapeHtmlText(document.title.length > 0 ? document.title : '今日附近值得吃');
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<style>${FOOD_HOME_CSS}</style>
</head>
<body>
<div id="app"></div>
<script id="home-data" type="application/json">${json}</script>
<script>${FOOD_HOME_JS}</script>
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

function escapeHtmlText(value: HtmlFoodTextValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.toString()
    .split('&').join('&amp;')
    .split('<').join('&lt;')
    .split('>').join('&gt;')
    .split('"').join('&quot;');
}
