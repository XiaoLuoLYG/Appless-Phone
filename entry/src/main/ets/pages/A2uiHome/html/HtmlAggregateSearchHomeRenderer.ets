import {
  A2uiAction,
  WaterfallFeedState,
  WaterfallRankedCandidate,
  WaterfallSourceState
} from '@loop/agent-core';
import { HtmlHomeBlock, HtmlHomeDocument, HtmlHomeMetric, WaterfallHomePayload } from './HtmlHomeTypes';
import {
  APP_LOGO_BILIBILI,
  APP_LOGO_HACKERNEWS,
  APP_LOGO_REDDIT,
  APP_LOGO_X,
  APP_LOGO_YOUTUBE,
  APP_LOGO_ZHIHU
} from './AppLogoDataUri';

const AGGREGATE_CSS: string = `
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
  --line-strong: rgba(24, 32, 27, 0.22);
  --video: #1d6a96;
  --video-soft: rgba(29, 106, 150, 0.12);
  --post: #9b5333;
  --post-soft: rgba(155, 83, 51, 0.12);
  --status: #526c45;
  --status-soft: rgba(82, 108, 69, 0.13);
  --notice: #8d3d3d;
  --notice-soft: rgba(141, 61, 61, 0.12);
  --shadow: 0 10px 28px rgba(44, 34, 26, 0.08);
}
* { box-sizing: border-box; }
button { font: inherit; }
body {
  margin: 0;
  min-height: 100vh;
  background: linear-gradient(180deg, rgba(255,255,255,0.72) 0%, rgba(255,255,255,0) 28%), var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", Arial, sans-serif;
  letter-spacing: 0;
}
h1, h2, h3, p { margin: 0; }
.aggregate-shell {
  width: min(100%, 980px);
  margin: 0 auto;
  padding: 20px 16px 40px;
}
.aggregate-hero {
  position: relative;
  display: flex;
  min-height: 170px;
  flex-direction: column;
  justify-content: flex-end;
  overflow: hidden;
  border-radius: 18px;
  padding: 18px;
  color: #fff;
  background:
    linear-gradient(90deg, rgba(17, 24, 20, 0.82), rgba(17, 24, 20, 0.34)),
    url("https://images.unsplash.com/photo-1495020689067-958852a7765e?auto=format&fit=crop&w=1400&q=80") center / cover;
  box-shadow: var(--shadow);
}
.aggregate-kicker {
  color: rgba(255, 255, 255, 0.78);
  font-size: 12px;
  line-height: 1.3;
}
.aggregate-hero h1 {
  margin-top: 8px;
  font-size: 34px;
  line-height: 1.04;
  font-weight: 830;
  overflow-wrap: anywhere;
  text-wrap: balance;
}
.aggregate-hero p {
  margin-top: 8px;
  max-width: 42rem;
  color: rgba(255, 255, 255, 0.78);
  font-size: 14px;
  line-height: 1.35;
  overflow-wrap: anywhere;
}
.aggregate-keyword {
  display: inline-flex;
  width: fit-content;
  max-width: 100%;
  align-items: center;
  gap: 8px;
  margin-top: 12px;
  border: 1px solid rgba(255, 255, 255, 0.28);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.16);
  padding: 7px 10px;
  backdrop-filter: blur(14px);
}
.aggregate-keyword span {
  color: rgba(255, 255, 255, 0.72);
  font-size: 11px;
  line-height: 1;
}
.aggregate-keyword b {
  min-width: 0;
  color: #fff;
  font-size: 13px;
  line-height: 1.2;
  font-weight: 760;
  overflow-wrap: anywhere;
}
.aggregate-grid {
  display: grid;
  gap: 18px;
}
.aggregate-section {
  min-width: 0;
}
.aggregate-source-overview {
  margin: 16px 0 18px;
}
.aggregate-source-overview .aggregate-status-list {
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 8px;
}
.aggregate-source-overview .aggregate-card {
  border: 0;
  background: transparent;
  padding: 0;
  box-shadow: none;
}
.aggregate-status-card summary {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-height: 34px;
  list-style: none;
  cursor: pointer;
}
.aggregate-status-card summary::-webkit-details-marker {
  display: none;
}
.aggregate-status-dot {
  width: 9px;
  height: 9px;
  border-radius: 999px;
  background: var(--status);
  box-shadow: 0 0 0 3px rgba(82, 108, 69, 0.14);
}
.aggregate-status-card[data-status="error"] .aggregate-status-dot,
.aggregate-status-card[data-status="unsupported"] .aggregate-status-dot,
.aggregate-status-card[data-status="needs_auth"] .aggregate-status-dot {
  background: var(--notice);
  box-shadow: 0 0 0 3px rgba(141, 61, 61, 0.14);
}
.aggregate-status-card p {
  margin-top: 6px;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.72);
  padding: 7px;
  font-size: 11px;
  line-height: 1.35;
}
.aggregate-section-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 10px;
}
.aggregate-section-head h2 {
  font-size: 18px;
  line-height: 1.2;
  font-weight: 780;
}
.aggregate-meta {
  color: var(--muted);
  font-size: 12px;
  line-height: 1.35;
}
.aggregate-filter-rail {
  display: flex;
  gap: 8px;
  margin: -2px 0 18px;
  overflow-x: auto;
  padding: 4px 2px 10px;
  scrollbar-width: none;
}
.aggregate-filter-rail::-webkit-scrollbar {
  display: none;
}
.aggregate-filter {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 6px;
  border: 1px solid var(--line);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.74);
  color: var(--muted);
  min-height: 36px;
  padding: 9px 12px;
  font-size: 12px;
  font-weight: 720;
  line-height: 1;
  cursor: pointer;
}
.aggregate-filter.active {
  border-color: var(--line-strong);
  background: #18201b;
  color: #fff;
}
.aggregate-filter .aggregate-app-icon {
  width: 18px;
  height: 18px;
  flex-basis: 18px;
  border-radius: 6px;
  font-size: 8px;
}
.aggregate-video-rail {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 12px;
}
.aggregate-post-list,
.aggregate-status-list,
.aggregate-notice-list {
  display: grid;
  gap: 10px;
}
.aggregate-card {
  --source-accent: var(--post);
  --source-soft: var(--post-soft);
  --source-surface: var(--panel);
  min-width: 0;
  border: 1px solid var(--line);
  border-radius: 16px;
  padding: 12px;
  background: var(--source-surface);
  box-shadow: var(--shadow);
}
.aggregate-result-card {
  border-color: var(--source-soft);
  background:
    linear-gradient(145deg, rgba(255,255,255,0.78), rgba(255,255,255,0.3)),
    radial-gradient(circle at top left, var(--source-soft), transparent 58%),
    var(--source-surface);
}
.aggregate-card[data-kind="aggregate-video"] {
  border-color: rgba(29, 106, 150, 0.24);
}
.aggregate-card[data-kind="aggregate-post"] {
  border-color: rgba(155, 83, 51, 0.24);
}
.aggregate-card[data-kind="aggregate-source-status"] {
  border-color: rgba(82, 108, 69, 0.24);
}
.aggregate-card[data-kind="aggregate-source-status"][data-status="error"],
.aggregate-card[data-kind="aggregate-source-status"][data-status="unsupported"],
.aggregate-card[data-kind="aggregate-source-status"][data-status="needs_auth"] {
  border-color: rgba(141, 61, 61, 0.24);
}
.aggregate-card[data-source="youtube"],
.aggregate-filter[data-filter="youtube"] {
  --source-accent: #b34038;
  --source-soft: rgba(179, 64, 56, 0.14);
  --source-surface: #fff1ed;
}
.aggregate-card[data-source="bilibili"],
.aggregate-filter[data-filter="bilibili"] {
  --source-accent: #2f85a7;
  --source-soft: rgba(47, 133, 167, 0.16);
  --source-surface: #edf8fb;
}
.aggregate-card[data-source="x"],
.aggregate-filter[data-filter="x"] {
  --source-accent: #22272b;
  --source-soft: rgba(34, 39, 43, 0.12);
  --source-surface: #f4f4f1;
}
.aggregate-card[data-source="hackernews"],
.aggregate-filter[data-filter="hackernews"] {
  --source-accent: #b9682f;
  --source-soft: rgba(185, 104, 47, 0.15);
  --source-surface: #fff4e7;
}
.aggregate-card[data-source="reddit"],
.aggregate-filter[data-filter="reddit"] {
  --source-accent: #d44f24;
  --source-soft: rgba(212, 79, 36, 0.15);
  --source-surface: #fff3ed;
}
.aggregate-card[data-source="zhihu"],
.aggregate-filter[data-filter="zhihu"] {
  --source-accent: #2e68ad;
  --source-soft: rgba(46, 104, 173, 0.14);
  --source-surface: #eef5ff;
}
.aggregate-card-top {
  display: flex;
  align-items: center;
  gap: 8px;
}
.aggregate-app-icon {
  position: relative;
  display: inline-flex;
  width: 26px;
  height: 26px;
  flex: 0 0 26px;
  align-items: center;
  justify-content: center;
  border-radius: 0;
  background: transparent;
  overflow: hidden;
}
.aggregate-app-icon img {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: contain;
}
.aggregate-status-card .aggregate-app-icon {
  width: 24px;
  height: 24px;
  flex-basis: 24px;
}
.aggregate-source-overview .aggregate-status-dot {
  position: absolute;
  right: calc(50% - 18px);
  bottom: 4px;
  width: 7px;
  height: 7px;
  box-shadow: 0 0 0 2px var(--paper);
}
.aggregate-tag {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  border-radius: 999px;
  padding: 5px 8px;
  font-size: 11px;
  line-height: 1;
  font-weight: 760;
}
.aggregate-card[data-kind="aggregate-video"] .aggregate-tag {
  background: var(--video-soft);
  color: var(--video);
}
.aggregate-card[data-kind="aggregate-post"] .aggregate-tag {
  background: var(--post-soft);
  color: var(--post);
}
.aggregate-card[data-kind="aggregate-source-status"] .aggregate-tag {
  background: var(--status-soft);
  color: var(--status);
}
.aggregate-card[data-kind="aggregate-source-status"][data-status="error"] .aggregate-tag,
.aggregate-card[data-kind="aggregate-source-status"][data-status="unsupported"] .aggregate-tag,
.aggregate-card[data-kind="aggregate-source-status"][data-status="needs_auth"] .aggregate-tag {
  background: var(--notice-soft);
  color: var(--notice);
}
.aggregate-card h3 {
  margin-top: 9px;
  font-size: 16px;
  line-height: 1.3;
  font-weight: 780;
  overflow-wrap: anywhere;
}
.aggregate-card p {
  margin-top: 8px;
  color: var(--muted);
  font-size: 13px;
  line-height: 1.5;
  overflow-wrap: anywhere;
}
.aggregate-post-card {
  padding: 0;
  cursor: pointer;
  overflow: hidden;
}
.aggregate-post-card summary {
  padding: 12px;
  list-style: none;
}
.aggregate-post-card summary::-webkit-details-marker {
  display: none;
}
.aggregate-post-title-row {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  margin-top: 10px;
}
.aggregate-post-title-row h3 {
  flex: 1;
  margin-top: 0;
}
.aggregate-expand-cue {
  flex: 0 0 auto;
  border: 1px solid var(--source-soft);
  border-radius: 999px;
  background: rgba(255,255,255,0.62);
  color: var(--source-accent);
  padding: 5px 8px;
  font-size: 11px;
  line-height: 1;
  font-weight: 760;
}
.aggregate-expand-cue::after {
  content: '展开';
}
.aggregate-post-card[open] .aggregate-expand-cue::after {
  content: '收起';
}
.aggregate-summary-snippet {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  border-left: 3px solid var(--source-accent);
  padding-left: 10px;
  color: var(--ink);
  white-space: pre-wrap;
}
.aggregate-post-card[open] .aggregate-summary-snippet {
  display: none;
}
.aggregate-post-expanded {
  display: grid;
  gap: 12px;
  border-top: 1px solid var(--line);
  padding: 12px;
}
.aggregate-expanded-text {
  color: var(--ink);
  margin-top: 0;
  font-size: 14px;
  line-height: 1.65;
  white-space: pre-wrap;
}
.aggregate-post-media-grid {
  display: grid;
  gap: 8px;
}
.aggregate-post-media {
  width: 100%;
  max-height: 360px;
  border: 1px solid var(--line);
  border-radius: 12px;
  background: #e8ebe7;
  object-fit: cover;
}
.aggregate-link-preview {
  display: grid;
  gap: 4px;
  border: 1px solid var(--source-soft);
  border-radius: 12px;
  background: rgba(255,255,255,0.58);
  padding: 10px;
  color: var(--ink);
  text-decoration: none;
}
.aggregate-link-preview b {
  font-size: 13px;
  line-height: 1.25;
}
.aggregate-link-host {
  color: var(--muted);
  font-size: 11px;
  line-height: 1.2;
  overflow-wrap: anywhere;
}
.aggregate-post-metadata {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.aggregate-post-metadata span {
  display: inline-flex;
  align-items: baseline;
  gap: 4px;
  border-radius: 999px;
  background: rgba(255,255,255,0.58);
  color: var(--muted);
  padding: 5px 8px;
  font-size: 11px;
  line-height: 1;
}
.aggregate-post-metadata b {
  color: var(--source-accent);
  font-weight: 760;
}
.aggregate-embed {
  width: 100%;
  aspect-ratio: 16 / 9;
  margin-top: 12px;
  border: 0;
  border-radius: 12px;
  background: #d7dde1;
}
.aggregate-rows {
  display: grid;
  gap: 7px;
  margin-top: 12px;
}
.aggregate-row {
  min-width: 0;
  border-top: 1px solid var(--line);
  padding-top: 7px;
}
.aggregate-row b {
  display: block;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.25;
  font-weight: 700;
}
.aggregate-row span {
  display: block;
  margin-top: 4px;
  font-size: 13px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.aggregate-card[hidden],
.aggregate-section[hidden],
#aggregate-filter-empty[hidden] {
  display: none;
}
#aggregate-filter-empty {
  border: 1px dashed var(--line-strong);
  border-radius: 14px;
  color: var(--muted);
  padding: 14px;
  font-size: 13px;
}
@media (min-width: 900px) {
  .aggregate-grid {
    grid-template-columns: minmax(0, 1.05fr) minmax(300px, 0.8fr);
    align-items: start;
  }
}
.aggregate-shell {
  width: min(100%, 840px);
  padding: 14px 14px 40px;
}
.aggregate-hero {
  min-height: 180px;
  border-radius: 20px;
}
.aggregate-hero h1 {
  font-size: 32px;
}
.aggregate-card {
  border-radius: 16px;
  box-shadow: none;
}
.aggregate-filter,
.aggregate-post-card summary,
.aggregate-link-preview {
  transition: transform 140ms ease, background-color 140ms ease, border-color 140ms ease;
}
.aggregate-filter:active,
.aggregate-post-card summary:active,
.aggregate-link-preview:active {
  transform: scale(0.98);
}
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-duration: 0.001ms !important;
  }
}
`;

const AGGREGATE_JS: string = `
(function () {
  var activeFilter = 'all';
  function applyFilter(value) {
    var buttons = document.querySelectorAll('.aggregate-filter');
    var cards = document.querySelectorAll('.aggregate-result-card');
    var sections = document.querySelectorAll('[data-filter-section]');
    var empty = document.getElementById('aggregate-filter-empty');
    var visible = 0;
    cards.forEach(function (card) {
      var kind = card.getAttribute('data-kind') || '';
      var source = card.getAttribute('data-source') || '';
      var keep = value === 'all' ||
        (value === 'video' && kind === 'aggregate-video') ||
        (value === 'article' && kind === 'aggregate-post') ||
        source === value;
      card.hidden = !keep;
      if (keep) {
        visible += 1;
      }
    });
    buttons.forEach(function (button) {
      button.classList.toggle('active', button.getAttribute('data-filter') === value);
    });
    sections.forEach(function (section) {
      var sectionVisible = false;
      section.querySelectorAll('.aggregate-result-card').forEach(function (card) {
        if (!card.hidden) {
          sectionVisible = true;
        }
      });
      section.hidden = value !== 'all' && !sectionVisible;
    });
    if (empty !== null) {
      empty.hidden = visible > 0;
    }
  }
  document.addEventListener('click', function (event) {
    var target = event.target;
    if (!target || typeof target.closest !== 'function') return;
    var button = target.closest('.aggregate-filter');
    if (!button) return;
    activeFilter = button.getAttribute('data-filter') || 'all';
    applyFilter(activeFilter);
  });
  window.__aiphoneRefreshAggregateSearch = function () { applyFilter(activeFilter); };
  applyFilter(activeFilter);
})();
`;

const WATERFALL_CSS: string = `
.waterfall-entry { display: flex; margin: 18px 0 10px; }
.waterfall-entry button {
  display: flex; width: 100%; min-height: 52px; align-items: center; justify-content: space-between;
  border: 1px solid var(--line-strong); border-radius: 16px; background: var(--panel);
  color: var(--ink); padding: 0 16px; font-size: 15px; font-weight: 760; cursor: pointer;
  transition: transform 140ms ease-out, opacity 140ms ease-out;
}
.waterfall-overlay { position: fixed; inset: 0; z-index: 20; display: none; overflow: hidden; background: var(--paper); }
.waterfall-overlay.active { display: block; }
.waterfall-track { height: 100%; overflow-y: auto; overscroll-behavior-y: contain; scroll-snap-type: y mandatory; }
.waterfall-card {
  width: min(100%, 760px); min-height: 100dvh; margin: 0 auto; scroll-snap-align: start;
  display: flex; flex-direction: column; justify-content: flex-start; gap: 12px;
  padding: calc(76px + env(safe-area-inset-top)) 20px calc(112px + env(safe-area-inset-bottom));
}
.waterfall-card img {
  display: block; width: 100%; max-height: 42dvh; min-height: 160px; object-fit: cover;
  border-radius: 20px; box-shadow: var(--shadow);
}
.waterfall-card--text { justify-content: center; }
.waterfall-card h2 {
  max-width: 22ch; font-size: clamp(28px, 7vw, 40px); line-height: 1.08; letter-spacing: -0.025em;
  font-weight: 820; overflow-wrap: anywhere;
}
.waterfall-card--text h2 { max-width: 18ch; font-size: clamp(32px, 9vw, 48px); }
.waterfall-card p { max-width: 62ch; color: var(--ink-soft); font-size: 16px; line-height: 1.55; overflow-wrap: anywhere; }
.waterfall-card a {
  display: inline-flex; min-height: 44px; align-items: center; width: fit-content; color: var(--accent);
  font-size: 14px; font-weight: 760; text-decoration: none;
}
.waterfall-meta { color: var(--muted); font-size: 13px; line-height: 1.35; }
.waterfall-reason {
  border-left: 2px solid var(--accent); color: var(--accent); font-size: 13px; line-height: 1.4;
  padding-left: 10px;
}
.waterfall-toolbar {
  position: fixed; z-index: 2; top: env(safe-area-inset-top); left: 14px; right: 14px;
  display: flex; align-items: center; justify-content: space-between; gap: 8px;
  padding-top: 10px;
}
.waterfall-toolbar button, .waterfall-preferences button {
  display: inline-flex; min-height: 44px; align-items: center; justify-content: center;
  border: 1px solid var(--line); border-radius: 14px; background: var(--panel);
  color: var(--ink); padding: 0 12px; font-size: 14px; font-weight: 720; cursor: pointer;
  transition: transform 140ms ease-out, opacity 140ms ease-out;
}
.waterfall-toolbar button:active, .waterfall-entry button:active, .waterfall-preferences button:active {
  transform: scale(0.98); opacity: 0.9;
}
.waterfall-toolbar button:focus-visible, .waterfall-entry button:focus-visible,
.waterfall-preferences button:focus-visible, .waterfall-preferences input:focus-visible,
.waterfall-empty button:focus-visible {
  outline: 2px solid var(--accent); outline-offset: 3px;
}
.waterfall-reason-panel {
  position: fixed; z-index: 2; top: calc(66px + env(safe-area-inset-top)); left: 16px; right: 16px;
  display: block; padding: 13px 14px; border: 1px solid var(--line); border-radius: 16px;
  background: var(--panel-strong); box-shadow: var(--shadow); color: var(--accent); font-size: 14px;
  line-height: 1.45; opacity: 0; pointer-events: none; transform: translateY(-8px);
  transform-origin: top right; transition: transform 180ms ease-out, opacity 180ms ease-out;
}
.waterfall-reason-panel.active { opacity: 1; pointer-events: auto; transform: translateY(0); }
.waterfall-preferences {
  position: fixed; z-index: 3; inset: auto 14px calc(14px + env(safe-area-inset-bottom)) 14px;
  display: block; max-height: min(72dvh, 560px); overflow-y: auto; padding: 18px 18px 20px;
  border: 1px solid var(--line); border-radius: 22px; background: var(--panel-strong);
  box-shadow: var(--shadow); opacity: 0; pointer-events: none; transform: translateY(12px);
  visibility: hidden; transition: transform 180ms ease-out, opacity 180ms ease-out;
}
.waterfall-preferences.active { opacity: 1; pointer-events: auto; transform: translateY(0); visibility: visible; }
.waterfall-preferences .waterfall-toolbar {
  position: static; inset: auto; display: grid; grid-template-columns: auto 1fr auto; gap: 8px;
  align-items: center; padding: 0; margin: 0 0 14px;
}
.waterfall-preferences .waterfall-toolbar b { font-size: 17px; text-align: center; }
.waterfall-preferences label {
  display: flex; min-height: 48px; align-items: center; gap: 12px; border-bottom: 1px solid var(--line);
  color: var(--ink); padding: 0; font-size: 16px;
}
.waterfall-preferences input { width: 20px; height: 20px; accent-color: var(--accent); }
.waterfall-preferences > div:last-child > button {
  width: 100%; min-height: 48px; margin-top: 16px; border-color: var(--line-strong); background: var(--ink);
  color: var(--paper);
}
.waterfall-empty {
  min-height: calc(100dvh - 150px); display: grid; place-items: center; align-content: center; gap: 14px;
  color: var(--muted); font-size: 16px; line-height: 1.5; padding: 20px; text-align: center;
}
.waterfall-empty button {
  min-height: 48px; border: 1px solid var(--line-strong); border-radius: 14px; background: var(--panel);
  color: var(--ink); padding: 0 16px; font-size: 14px; font-weight: 720; cursor: pointer;
  transition: transform 140ms ease-out, opacity 140ms ease-out;
}
.waterfall-empty button:active { transform: scale(0.98); opacity: 0.9; }
.waterfall-status { color: var(--muted); font-size: 14px; line-height: 1.5; padding: 18px 20px 0; text-align: center; }
@media (prefers-reduced-motion: reduce) {
  .waterfall-entry button, .waterfall-toolbar button, .waterfall-preferences button,
  .waterfall-preferences, .waterfall-reason-panel, .waterfall-empty button { transition: none; }
}
`;

const WATERFALL_JS: string = `
(function () {
  var overlay = document.getElementById('waterfall-discovery');
  var track = document.getElementById('waterfall-track');
  var preferences = document.getElementById('waterfall-preferences');
  var reasonPanel = document.getElementById('waterfall-reason-panel');
  var state = window.__aiphoneWaterfallInitial || null;
  var mode = 'entry';
  var enabledSources = state && state.enabledSources ? state.enabledSources.slice() : [];
  var aggregateHtml = state && state.aggregateHtml ? state.aggregateHtml : '';
  var advancePending = false;
  var scrollTimer = 0;
  function text(value) { return value === null || value === undefined ? '' : String(value); }
  function escapeHtml(value) { return text(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;'); }
  function sourceLabel(source) {
    var labels = { youtube: 'YouTube', bilibili: 'B 站', x: 'X', hackernews: 'HN', reddit: 'Reddit', zhihu: '知乎' };
    return labels[source] || source;
  }
  function candidates(payload) {
    if (!payload) return [];
    var values = payload.candidates || [];
    var seen = {};
    return values.filter(function (item) {
      var key = text(item.id) || text(item.normalizedUrl);
      if (!key || seen[key]) return false;
      seen[key] = true;
      return true;
    });
  }
  function mergePayload(payload) {
    if (!payload) return;
    var oldCurrent = candidates(state)[0];
    if (typeof payload.aggregateHtml === 'string' && payload.aggregateHtml !== aggregateHtml) {
      var shell = document.querySelector('.aggregate-shell');
      if (shell) shell.innerHTML = payload.aggregateHtml;
      aggregateHtml = payload.aggregateHtml;
      if (window.__aiphoneRefreshAggregateSearch) window.__aiphoneRefreshAggregateSearch();
    }
    state = payload;
    enabledSources = payload.enabledSources ? payload.enabledSources.slice() : [];
    var nextCurrent = candidates(state)[0];
    if (!oldCurrent || !nextCurrent || oldCurrent.id !== nextCurrent.id) advancePending = false;
  }
  function postSourceSelection() {
    if (!state || !window.AIPhoneHome || typeof window.AIPhoneHome.postAction !== 'function') return;
    window.AIPhoneHome.postAction(JSON.stringify({
      id: 'waterfall.sources.select', label: '来源偏好', prompt: '', variant: 'secondary', kind: 'client',
      args: { surfaceId: state.surfaceId || '', enabledSources: enabledSources }
    }));
  }
  function postAdvanceIfNeeded() {
    var items = candidates(state);
    if (mode !== 'discovering' || advancePending || !track || items.length < 2 ||
      track.scrollTop < Math.max(1, track.clientHeight) / 2 ||
      !window.AIPhoneHome || typeof window.AIPhoneHome.postAction !== 'function') return;
    advancePending = true;
    window.AIPhoneHome.postAction(JSON.stringify({
      id: 'waterfall.feed.advance', label: '下一条', prompt: '', variant: 'secondary', kind: 'client',
      args: { surfaceId: state.surfaceId || '', currentId: items[0].id }
    }));
  }
  function renderCandidate(item) {
    var cover = item.coverUrl ? '<img src="' + escapeHtml(item.coverUrl) + '" alt="' + escapeHtml(item.title) + '" loading="lazy" />' : '';
    var link = item.url ? '<a href="' + escapeHtml(item.url) + '" target="_blank" rel="noopener noreferrer">打开原文</a>' : '';
    var cardClass = item.coverUrl ? 'waterfall-card' : 'waterfall-card waterfall-card--text';
    return '<article class="' + cardClass + '" data-waterfall-id="' + escapeHtml(item.id) + '"><div class="waterfall-meta">' + escapeHtml(sourceLabel(item.source)) + ' · ' + escapeHtml(item.mediaType) + '</div>' +
      cover + '<h2>' + escapeHtml(item.title) + '</h2><p>' + escapeHtml(item.summary) + '</p>' +
      '<div class="waterfall-reason">推荐理由：' + escapeHtml(item.reason) + '</div>' +
      (item.publishedAt ? '<div class="waterfall-meta">' + escapeHtml(item.publishedAt) + '</div>' : '') + link + '</article>';
  }
  function renderPreferences() {
    if (!preferences || !state) return;
    var sources = state.sources || [];
    preferences.innerHTML = '<div class="waterfall-toolbar"><button type="button" data-waterfall-close-preferences>返回</button><b>来源偏好</b><span></span></div>' +
      '<div>' + sources.map(function (source) {
        var checked = enabledSources.indexOf(source.source) >= 0 ? ' checked' : '';
        return '<label><input type="checkbox" data-waterfall-source="' + escapeHtml(source.source) + '"' + checked + ' /> ' + escapeHtml(sourceLabel(source.source)) + '</label>';
      }).join('') + '<button type="button" data-waterfall-close-preferences>完成</button></div>';
    preferences.classList.add('active');
    preferences.querySelectorAll('[data-waterfall-source]').forEach(function (input) {
      input.addEventListener('change', function () {
        enabledSources = Array.prototype.slice.call(preferences.querySelectorAll('[data-waterfall-source]:checked')).map(function (node) { return node.getAttribute('data-waterfall-source'); });
        postSourceSelection();
        render();
      });
    });
    preferences.querySelectorAll('[data-waterfall-close-preferences]').forEach(function (button) {
      button.addEventListener('click', function () { preferences.classList.remove('active'); mode = 'discovering'; });
    });
    mode = 'source_preferences';
  }
  function render() {
    if (!track || !state) return;
    var items = candidates(state).filter(function (item) { return enabledSources.indexOf(item.source) >= 0; });
    var empty = enabledSources.length === 0 ? '<div class="waterfall-empty"><span>至少开启一个来源</span><button type="button" data-waterfall-empty-sources>打开来源偏好</button></div>' : '';
    var status = '';
    if (enabledSources.length > 0 && items.length === 0) {
      status = state.exhausted ? '<div class="waterfall-status">\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f</div>' :
        (state.replenishing ? '<div class="waterfall-status">\\u6b63\\u5728\\u8865\\u5145\\u5185\\u5bb9</div>' :
          '<div class="waterfall-status">\\u6b63\\u5728\\u6c47\\u96c6\\u5185\\u5bb9\\u2026</div>');
    } else if (items.length > 0 && state.replenishing) {
      status = '<div class="waterfall-status">\\u6b63\\u5728\\u8865\\u5145\\u5185\\u5bb9</div>';
    }
    track.innerHTML = status + empty + items.map(renderCandidate).join('');
    track.scrollTop = 0;
    if (reasonPanel) {
      reasonPanel.textContent = items.length === 0 ? '' : '推荐理由：' + text(items[0].reason);
      if (items.length === 0) {
        reasonPanel.hidden = true;
        reasonPanel.classList.remove('active');
      }
    }
  }
  track.addEventListener('scroll', function () {
    clearTimeout(scrollTimer);
    scrollTimer = setTimeout(postAdvanceIfNeeded, 80);
  });
  track.addEventListener('click', function (event) {
    var target = event.target;
    if (!target || typeof target.closest !== 'function') return;
    if (target.closest('[data-waterfall-empty-sources]')) renderPreferences();
  });
  document.addEventListener('click', function (event) {
    var target = event.target;
    if (!target || typeof target.closest !== 'function' || !target.closest('[data-waterfall-enter]')) return;
    mode = 'discovering';
    overlay.classList.add('active');
    render();
  });
  document.querySelectorAll('[data-waterfall-back]').forEach(function (button) {
    button.addEventListener('click', function () {
      mode = 'entry';
      overlay.classList.remove('active');
      if (reasonPanel) {
        reasonPanel.hidden = true;
        reasonPanel.classList.remove('active');
      }
    });
  });
  document.querySelectorAll('[data-waterfall-preferences]').forEach(function (button) {
    button.addEventListener('click', renderPreferences);
  });
  document.querySelectorAll('[data-waterfall-reason]').forEach(function (button) {
    button.addEventListener('click', function () {
      if (reasonPanel && reasonPanel.textContent) {
        reasonPanel.hidden = !reasonPanel.hidden;
        reasonPanel.classList.toggle('active', !reasonPanel.hidden);
      }
    });
  });
  window.__aiphoneApplyWaterfallUpdate = function (payload) {
    mergePayload(payload);
    render();
  };
  if (state) mergePayload(state);
})();
`;

export function shouldRenderAggregateSearchHomeDocument(document: HtmlHomeDocument): boolean {
  return document.kind === 'aggregate-search';
}

type WaterfallActionValue = Object | string | number | boolean | null | undefined;

function waterfallArgsFromAction(
  action: A2uiAction,
  actionId: string,
  surfaceId: string
): Record<string, WaterfallActionValue> | null {
  if (action.id !== actionId || action.kind !== 'client' || action.args === undefined) {
    return null;
  }
  const args = action.args as Record<string, WaterfallActionValue>;
  if (typeof args['surfaceId'] !== 'string' || args['surfaceId'] !== surfaceId) {
    return null;
  }
  return args;
}

export function waterfallEnabledSourcesFromAction(action: A2uiAction, surfaceId: string): string[] | null {
  const args = waterfallArgsFromAction(action, 'waterfall.sources.select', surfaceId);
  if (args === null || !Array.isArray(args['enabledSources'])) {
    return null;
  }
  const rawSources = args['enabledSources'] as WaterfallActionValue[];
  const enabledSources: string[] = [];
  for (let index = 0; index < rawSources.length; index += 1) {
    if (typeof rawSources[index] !== 'string') {
      return null;
    }
    const source = (rawSources[index] as string).trim();
    if (source.length === 0) {
      return null;
    }
    if (enabledSources.indexOf(source) < 0) {
      enabledSources.push(source);
    }
  }
  return enabledSources;
}

export function waterfallAdvanceCurrentFromAction(action: A2uiAction, surfaceId: string): string | null {
  const args = waterfallArgsFromAction(action, 'waterfall.feed.advance', surfaceId);
  if (args === null || typeof args['currentId'] !== 'string') {
    return null;
  }
  const currentId = (args['currentId'] as string).trim();
  return currentId.length > 0 ? currentId : null;
}

export function buildWaterfallHomePayload(
  document: HtmlHomeDocument,
  isBusy: boolean,
  waterfallState: WaterfallFeedState | null = null
): WaterfallHomePayload | null {
  const state = waterfallState ?? document.waterfall;
  if (state === undefined) {
    return null;
  }
  const candidates: WaterfallRankedCandidate[] = [];
  const seen: string[] = [];
  const append = (candidate: WaterfallRankedCandidate | null): void => {
    if (candidate === null || seen.indexOf(candidate.id) >= 0 || seen.indexOf(candidate.normalizedUrl) >= 0) {
      return;
    }
    seen.push(candidate.id);
    if (candidate.normalizedUrl.length > 0) {
      seen.push(candidate.normalizedUrl);
    }
    candidates.push(candidate);
  };
  append(state.current);
  state.stable.forEach(append);
  state.tail.forEach(append);
  const activeCandidates = candidates.filter((candidate: WaterfallRankedCandidate): boolean =>
    state.enabledSources.indexOf(candidate.source) >= 0);
  const relevantSources = state.sources.filter((source: WaterfallSourceState): boolean =>
    state.enabledSources.indexOf(source.source) >= 0);
  const replenishing = relevantSources.some((source: WaterfallSourceState): boolean =>
    source.inFlight || source.phase === 'loading');
  const exhausted = activeCandidates.length === 0 && state.enabledSources.length > 0 &&
    relevantSources.length === state.enabledSources.length && relevantSources.every((source: WaterfallSourceState): boolean =>
    source.continuation === null && (source.phase === 'empty' || source.phase === 'needs_auth' ||
    source.phase === 'error' || source.phase === 'exhausted' || source.phase === 'success'));
  return {
    surfaceId: document.surfaceId ?? '',
    query: state.query,
    aggregateHtml: renderAggregateMainContent(document, isBusy, candidates.length > 0),
    candidates: candidates,
    enabledSources: state.enabledSources.slice(),
    sources: state.sources,
    replenishing: replenishing,
    exhausted: exhausted
  };
}

function renderAggregateMainContent(
  document: HtmlHomeDocument,
  isBusy: boolean,
  entryAvailable: boolean
): string {
  const videos = document.blocks.filter((block: HtmlHomeBlock) => block.kind === 'aggregate-video');
  const posts = document.blocks.filter((block: HtmlHomeBlock) => block.kind === 'aggregate-post');
  const statuses = document.blocks.filter((block: HtmlHomeBlock) => block.kind === 'aggregate-source-status');
  return [
    '<header class="aggregate-hero">',
    '<div class="aggregate-kicker">多源搜索</div>',
    '<h1>', escapeHtml(document.title), '</h1>',
    renderKeywordBadge(document.subtitle),
    '<p>视频和讨论一起看', isBusy ? ' · 正在更新' : '', '</p>',
    '</header>',
    statuses.length > 0 ? '<section class="aggregate-section aggregate-source-overview"><div class="aggregate-section-head"><h2>来源</h2><div class="aggregate-meta">状态摘要</div></div><div class="aggregate-status-list">' + statuses.map(renderAggregateBlock).join('') + '</div></section>' : '',
    '<div class="waterfall-entry">', entryAvailable ? '<button type="button" data-waterfall-enter>进入发现流</button>' : '', '</div>',
    renderFilterRail(),
    '<div id="aggregate-filter-empty" hidden>没有匹配结果</div>',
    '<div class="aggregate-grid">',
    '<section class="aggregate-section" data-filter-section="video">',
    '<div class="aggregate-section-head"><h2>视频</h2><div class="aggregate-meta">', escapeHtml(videos.length.toString()), ' 条</div></div>',
    '<div class="aggregate-video-rail">', videos.map(renderAggregateBlock).join(''), '</div>',
    '</section>',
    '<section class="aggregate-section" data-filter-section="article">',
    '<div class="aggregate-section-head"><h2>讨论</h2><div class="aggregate-meta">', escapeHtml(posts.length.toString()), ' 条</div></div>',
    '<div class="aggregate-post-list">', posts.map(renderAggregateBlock).join(''), '</div>',
    '</section>',
    '</div>'
  ].join('');
}

export function renderAggregateSearchHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  const waterfall = buildWaterfallHomePayload(document, isBusy);
  const waterfallJson = waterfall === null ? 'null' : JSON.stringify(waterfall).replace(/</g, '\\u003c');
  const waterfallStatus = waterfall !== null && waterfall.replenishing ? '<div class="waterfall-status">正在补充内容</div>' :
    (waterfall !== null && waterfall.exhausted ? '<div class="waterfall-status">本轮内容已结束</div>' : '');
  return [
    '<!doctype html>',
    '<html lang="zh-CN"><head><meta charset="utf-8" />',
    '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />',
    '<title>', escapeHtml(document.title), '</title>',
    '<style>', AGGREGATE_CSS, WATERFALL_CSS, '</style></head><body>',
    '<main class="aggregate-shell">',
    waterfall === null ? renderAggregateMainContent(document, isBusy, false) : waterfall.aggregateHtml,
    '</main>', waterfall !== null ? '<section id="waterfall-discovery" class="waterfall-overlay"><div class="waterfall-toolbar"><button type="button" data-waterfall-back>返回</button><button type="button" data-waterfall-preferences>来源偏好</button><button type="button" data-waterfall-reason>推荐理由</button></div><div id="waterfall-reason-panel" class="waterfall-reason-panel" hidden></div><div id="waterfall-track" class="waterfall-track">' + waterfallStatus + '</div><div id="waterfall-preferences" class="waterfall-preferences"></div></section>' : '',
    '<script>', AGGREGATE_JS, waterfall !== null ? 'window.__aiphoneWaterfallInitial=' + waterfallJson + ';' + WATERFALL_JS : '', '</script></body></html>'
  ].join('');
}

function renderKeywordBadge(value: string): string {
  const keyword = compactSubtitle(value);
  if (keyword.length === 0) {
    return '';
  }
  return '<div class="aggregate-keyword"><span>关键词</span><b>' + escapeHtml(keyword) + '</b></div>';
}

function renderAggregateBlock(block: HtmlHomeBlock): string {
  if (block.kind === 'aggregate-source-status') {
    return renderStatusBlock(block);
  }
  if (block.kind === 'aggregate-post') {
    return renderPostBlock(block);
  }
  return [
    '<article class="aggregate-card aggregate-result-card" data-kind="', escapeHtml(block.kind), '" data-source="', escapeAttribute(sourceCssValue(text(block.source))), '" data-status="', escapeAttribute(text(block.status)), '">',
    renderCardTop(block),
    '<h3>', escapeHtml(block.title), '</h3>',
    text(block.subtitle).length > 0 ? '<p>' + escapeHtml(text(block.subtitle)) + '</p>' : '',
    renderEmbed(block),
    renderRows(block),
    '</article>'
  ].join('');
}

function renderPostBlock(block: HtmlHomeBlock): string {
  const body = postBodyText(block);
  const media = renderPostMedia(block);
  const link = renderPostLink(block);
  const meta = renderPostMeta(block);
  return [
    '<details class="aggregate-card aggregate-result-card aggregate-post-card" data-kind="', escapeHtml(block.kind), '" data-source="', escapeAttribute(sourceCssValue(text(block.source))), '" data-status="', escapeAttribute(text(block.status)), '">',
    '<summary>',
    renderCardTop(block),
    '<div class="aggregate-post-title-row"><h3>', escapeHtml(block.title), '</h3><span class="aggregate-expand-cue"></span></div>',
    body.length > 0 ? '<p class="aggregate-summary-snippet">' + escapeHtml(body) + '</p>' : '',
    '</summary>',
    '<div class="aggregate-post-expanded">',
    media,
    body.length > 0 ? '<p class="aggregate-expanded-text">' + escapeHtml(body) + '</p>' : '',
    link,
    meta,
    '</div>',
    '</details>'
  ].join('');
}

function renderStatusBlock(block: HtmlHomeBlock): string {
  return [
    '<details class="aggregate-card aggregate-status-card" data-kind="', escapeHtml(block.kind), '" data-source="', escapeAttribute(sourceCssValue(text(block.source))), '" data-status="', escapeAttribute(text(block.status)), '">',
    '<summary aria-label="', escapeAttribute(block.title), '">', sourceIconMarkup(text(block.source)), '<span class="aggregate-status-dot"></span></summary>',
    text(block.subtitle).length > 0 ? '<p>' + escapeHtml(text(block.subtitle)) + '</p>' : '',
    renderRows(block),
    '</details>'
  ].join('');
}

function renderCardTop(block: HtmlHomeBlock): string {
  return '<div class="aggregate-card-top">' + sourceIconMarkup(text(block.source)) +
    '<div class="aggregate-tag">' + escapeHtml(blockTitle(block)) + '</div></div>';
}

function renderFilterRail(): string {
  return '<nav class="aggregate-filter-rail" aria-label="聚合筛选">' + [
    renderFilterButton('all', '全部', '', true),
    renderFilterButton('video', '视频', '', false),
    renderFilterButton('article', '文章', '', false),
    renderFilterButton('youtube', 'YouTube', 'youtube', false),
    renderFilterButton('bilibili', 'B 站', 'bilibili', false),
    renderFilterButton('x', 'X', 'x', false),
    renderFilterButton('hackernews', 'HN', 'hackernews', false),
    renderFilterButton('reddit', 'Reddit', 'reddit', false),
    renderFilterButton('zhihu', '知乎', 'zhihu', false)
  ].join('') + '</nav>';
}

function renderFilterButton(value: string, label: string, source: string, active: boolean): string {
  return '<button type="button" class="aggregate-filter' + (active ? ' active' : '') +
    '" data-filter="' + escapeAttribute(value) + '">' +
    (source.length > 0 ? sourceIconMarkup(source) : '') +
    '<span>' + escapeHtml(label) + '</span></button>';
}

function renderEmbed(block: HtmlHomeBlock): string {
  if (block.mediaEmbed === undefined || block.mediaEmbed === null || text(block.mediaEmbed.embedUrl).length === 0) {
    return '';
  }
  return '<iframe class="aggregate-embed" src="' + escapeAttribute(block.mediaEmbed.embedUrl) +
    '" title="' + escapeAttribute(block.mediaEmbed.title) +
    '" loading="lazy" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>';
}

function postBodyText(block: HtmlHomeBlock): string {
  const subtitle = text(block.subtitle);
  if (subtitle.length > 0) {
    return subtitle;
  }
  return rowValue(block, ['text', 'content', 'body']);
}

function renderPostMedia(block: HtmlHomeBlock): string {
  const urls = postMediaUrls(block);
  if (urls.length === 0) {
    return '';
  }
  return '<div class="aggregate-post-media-grid">' + urls.map((url: string) => {
    return '<img class="aggregate-post-media" src="' + escapeAttribute(url) + '" alt="帖子图片" loading="lazy" />';
  }).join('') + '</div>';
}

function renderPostLink(block: HtmlHomeBlock): string {
  const url = postLinkUrl(block);
  if (url.length === 0) {
    return '';
  }
  return '<a class="aggregate-link-preview" href="' + escapeAttribute(url) +
    '" target="_blank" rel="noopener noreferrer"><span class="aggregate-link-host">' +
    escapeHtml(hostLabel(url)) + '</span><b>打开原文</b></a>';
}

function renderPostMeta(block: HtmlHomeBlock): string {
  const chips: string[] = [];
  appendPostMeta(chips, '作者', rowValue(block, ['author']));
  appendPostMeta(chips, '账号', rowValue(block, ['handle']));
  appendPostMeta(chips, '时间', rowValue(block, ['publishedAt', 'time']));
  appendPostMeta(chips, '热度', rowValue(block, ['score']));
  appendPostMeta(chips, '评论', rowValue(block, ['commentCount', 'comments']));
  if (chips.length === 0) {
    return '';
  }
  return '<div class="aggregate-post-metadata">' + chips.join('') + '</div>';
}

function appendPostMeta(chips: string[], label: string, value: string): void {
  if (value.length === 0) {
    return;
  }
  chips.push('<span><b>' + escapeHtml(label) + '</b>' + escapeHtml(value) + '</span>');
}

function renderRows(block: HtmlHomeBlock): string {
  const rows = block.metrics.concat(block.rows).slice(0, 6);
  if (rows.length === 0) {
    return '';
  }
  return '<div class="aggregate-rows">' + rows.map(renderRow).join('') + '</div>';
}

function renderRow(row: HtmlHomeMetric): string {
  return '<div class="aggregate-row"><b>' + escapeHtml(row.label) + '</b><span>' + escapeHtml(row.value) + '</span></div>';
}

function blockTitle(block: HtmlHomeBlock): string {
  if (block.kind === 'aggregate-video') {
    return '视频';
  }
  if (block.kind === 'aggregate-post') {
    return aggregateSourceLabel(text(block.source), '讨论');
  }
  return '来源状态';
}

function sourceIconMarkup(source: string): string {
  const clean = sourceCssValue(source);
  const logo = sourceLogoUrl(clean);
  if (logo.length === 0) {
    return '';
  }
  return '<span class="aggregate-app-icon" data-source="' + escapeAttribute(clean) + '" aria-label="' +
    escapeAttribute(aggregateSourceLabel(clean, '来源')) + '"><img src="' + escapeAttribute(logo) +
    '" alt="" loading="lazy" /></span>';
}

function sourceLogoUrl(source: string): string {
  if (source === 'youtube') {
    return APP_LOGO_YOUTUBE;
  }
  if (source === 'bilibili') {
    return APP_LOGO_BILIBILI;
  }
  if (source === 'x') {
    return APP_LOGO_X;
  }
  if (source === 'hackernews') {
    return APP_LOGO_HACKERNEWS;
  }
  if (source === 'reddit') {
    return APP_LOGO_REDDIT;
  }
  if (source === 'zhihu') {
    return APP_LOGO_ZHIHU;
  }
  return '';
}

function sourceCssValue(source: string): string {
  const clean = source.trim().toLowerCase();
  if (clean === 'youtube' || clean === 'bilibili' || clean === 'x' || clean === 'hackernews' ||
    clean === 'reddit' ||
    clean === 'zhihu') {
    return clean;
  }
  return 'unknown';
}

function aggregateSourceLabel(source: string, fallback: string): string {
  if (source === 'youtube') {
    return 'YouTube';
  }
  if (source === 'bilibili') {
    return 'B 站';
  }
  if (source === 'x') {
    return 'X';
  }
  if (source === 'hackernews') {
    return 'HN';
  }
  if (source === 'reddit') {
    return 'Reddit';
  }
  if (source === 'zhihu') {
    return '知乎';
  }
  return fallback;
}

function rowValue(block: HtmlHomeBlock, labels: string[]): string {
  const rows = block.metrics.concat(block.rows);
  for (let index = 0; index < rows.length; index++) {
    const row = rows[index];
    const label = row.label.trim().toLowerCase();
    for (let labelIndex = 0; labelIndex < labels.length; labelIndex++) {
      if (label === labels[labelIndex].trim().toLowerCase()) {
        return text(row.value);
      }
    }
  }
  return '';
}

function postMediaUrls(block: HtmlHomeBlock): string[] {
  const urls: string[] = [];
  block.rows.forEach((row: HtmlHomeMetric) => {
    const label = row.label.trim().toLowerCase();
    if (label !== 'mediaurl' && label !== 'image' && label !== 'images' && label !== 'thumbnail' &&
      label !== 'cover' && label !== 'pic' && label !== 'picture') {
      return;
    }
    extractUrls(row.value).forEach((url: string) => {
      if (urls.indexOf(url) < 0) {
        urls.push(url);
      }
    });
  });
  block.rows.forEach((row: HtmlHomeMetric) => {
    extractUrls(row.value).forEach((url: string) => {
      if (isImageUrl(url) && urls.indexOf(url) < 0) {
        urls.push(url);
      }
    });
  });
  return urls;
}

function postLinkUrl(block: HtmlHomeBlock): string {
  const explicitUrl = rowValue(block, ['url', 'link']);
  if (explicitUrl.length > 0) {
    return explicitUrl;
  }
  const urls = extractUrls(postBodyText(block));
  return urls.length > 0 ? urls[0] : '';
}

function extractUrls(value: string): string[] {
  const matches = text(value).match(/https?:\/\/[^\s,，]+/g);
  if (matches === null) {
    return [];
  }
  return matches.map((url: string) => trimUrl(url));
}

function trimUrl(url: string): string {
  let clean = url;
  while (clean.length > 0) {
    const last = clean.charAt(clean.length - 1);
    if (last !== ')' && last !== ']' && last !== '}' && last !== '"' && last !== '\'' &&
      last !== '。' && last !== '，' && last !== ',' && last !== '.') {
      break;
    }
    clean = clean.substring(0, clean.length - 1);
  }
  return clean;
}

function isImageUrl(url: string): boolean {
  const lower = url.toLowerCase();
  return lower.indexOf('.jpg') >= 0 ||
    lower.indexOf('.jpeg') >= 0 ||
    lower.indexOf('.png') >= 0 ||
    lower.indexOf('.webp') >= 0 ||
    lower.indexOf('.gif') >= 0 ||
    lower.indexOf('image') >= 0 ||
    lower.indexOf('pic') >= 0;
}

function hostLabel(url: string): string {
  let clean = url;
  const scheme = clean.indexOf('://');
  if (scheme >= 0) {
    clean = clean.substring(scheme + 3);
  }
  const slash = clean.indexOf('/');
  if (slash >= 0) {
    clean = clean.substring(0, slash);
  }
  return clean.length > 0 ? clean : url;
}

function text(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function compactSubtitle(value: string): string {
  const clean = value.trim();
  if (clean.length <= 36) {
    return clean;
  }
  const comma = clean.indexOf('，');
  if (comma > 0 && comma <= 36) {
    return clean.substring(0, comma);
  }
  return clean.substring(0, 36) + '...';
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function escapeAttribute(value: string): string {
  return escapeHtml(value);
}
