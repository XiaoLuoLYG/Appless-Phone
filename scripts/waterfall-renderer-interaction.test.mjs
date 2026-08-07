import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const renderer = readFileSync(
  new URL('../entry/src/main/ets/pages/A2uiHome/html/HtmlAggregateSearchHomeRenderer.ets', import.meta.url),
  'utf8'
);

function template(name) {
  const marker = `const ${name}: string = \``;
  const start = renderer.indexOf(marker);
  assert.notEqual(start, -1, `${name} template is missing`);
  const contentStart = start + marker.length;
  const end = renderer.indexOf('\n`;', contentStart);
  assert.notEqual(end, -1, `${name} template is unterminated`);
  return renderer.slice(contentStart, end);
}

const aggregateCss = template('AGGREGATE_CSS');
const aggregateJs = template('AGGREGATE_JS');
const waterfallCss = template('WATERFALL_CSS');
assert.match(aggregateCss, /\.aggregate-status-sheet-summary/);
assert.match(aggregateCss, /\.aggregate-status-sheet/);
assert.match(aggregateJs, /data-status-close/);
assert.match(waterfallCss, /\.waterfall-entry-floating/);
assert.match(waterfallCss, /\.waterfall-cinema-card/);
assert.match(waterfallCss, /\.waterfall-toolbar-primary/);
assert.match(waterfallCss, /\.waterfall-toolbar-tools/);
assert.match(waterfallCss, /\.waterfall-source-logo/);
assert.match(waterfallCss, /\.waterfall-media-cover/);
assert.doesNotMatch(waterfallCss, /\.waterfall-cinema-stage img\s*\{/);

function element() {
  const classes = new Set();
  const listeners = {};
  return {
    scrollTop: 0,
    clientHeight: 1000,
    innerHTML: '',
    classList: {
      add: (name) => classes.add(name),
      remove: (name) => classes.delete(name),
      toggle: (name) => classes.has(name) ? classes.delete(name) : classes.add(name),
      contains: (name) => classes.has(name)
    },
    addEventListener: (type, listener) => {
      listeners[type] = listener;
    },
    emit: (type, event = {}) => {
      listeners[type]?.(event);
    },
    querySelectorAll: () => []
  };
}

const overlay = element();
const track = element();
const preferences = element();
const backButton = element();
const preferencesButton = element();
const documentListeners = {};
const actions = [];
const fullscreenStates = [];
const document = {
  getElementById: (id) => ({
    'waterfall-discovery': overlay,
    'waterfall-track': track,
    'waterfall-preferences': preferences
  })[id] ?? null,
  querySelector: () => null,
  querySelectorAll: (selector) => ({
    '[data-waterfall-back]': [backButton],
    '[data-waterfall-preferences]': [preferencesButton]
  })[selector] ?? [],
  addEventListener: (type, listener) => {
    documentListeners[type] = listener;
  }
};
const candidate = (id) => ({
  id,
  source: 'youtube',
  mediaType: 'video',
  title: id,
  summary: id,
  url: `https://example.test/${id}`,
  coverUrl: id === 'current' ? 'https://example.test/broken-cover.jpg' : '',
  publishedAt: '',
  reason: '标题命中查询'
});
const window = {
  __aiphoneWaterfallInitial: {
    surfaceId: 'surface-1',
    enabledSources: ['youtube'],
    aggregateHtml: '',
    candidates: [candidate('current'), candidate('next')],
    sources: [{ source: 'youtube', phase: 'success' }]
  },
  __aiphoneWaterfallSourceLogos: { youtube: 'data:image/png;base64,logo' },
  AIPhoneHome: {
    postAction: (value) => actions.push(JSON.parse(value)),
    setWaterfallFullscreen: (value) => fullscreenStates.push(value)
  }
};

vm.runInNewContext(template('WATERFALL_JS'), {
  window,
  document,
  setTimeout,
  clearTimeout
});
documentListeners.click({
  target: {
    closest: (selector) => selector === '[data-waterfall-enter]' ? {} : null
  }
});
assert.deepEqual(fullscreenStates, ['true']);
assert.match(track.innerHTML, /waterfall-recommendation/);
assert.doesNotMatch(track.innerHTML, /data-waterfall-reason/);
assert.match(track.innerHTML, /data-waterfall-media-fallback/);

track.scrollTop = 600;
track.emit('scroll');
await new Promise((resolve) => setTimeout(resolve, 120));
assert.equal(actions.at(-1)?.id, 'waterfall.feed.advance');
preferencesButton.emit('click');
assert.equal(preferences.classList.contains('active'), true);
backButton.emit('click');
assert.deepEqual(fullscreenStates, ['true', 'false']);
assert.equal(preferences.classList.contains('active'), false);

window.__aiphoneApplyWaterfallUpdate({
  surfaceId: 'surface-1',
  enabledSources: [],
  aggregateHtml: '',
  candidates: [candidate('current'), candidate('next')],
  sources: [{ source: 'youtube', phase: 'success' }],
  replenishing: false,
  exhausted: true
});
assert.match(track.innerHTML, /data-waterfall-empty-sources/);
assert.doesNotMatch(track.innerHTML, /\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f/);

const statusDetails = { open: true };
const statusListeners = {};
const statusDocument = {
  querySelectorAll: () => [],
  getElementById: () => null,
  addEventListener: (type, listener) => { statusListeners[type] = listener; }
};
vm.runInNewContext(aggregateJs, {
  document: statusDocument,
  window: {}
});
statusListeners.click({
  target: {
    closest: (selector) => selector === '[data-status-close]' ? {
      closest: () => statusDetails
    } : null
  }
});
assert.equal(statusDetails.open, false);
track.emit('click', {
  target: {
    closest: (selector) => selector === '[data-waterfall-empty-sources]' ? {} : null
  }
});
assert.equal(preferences.classList.contains('active'), true);
assert.match(preferences.innerHTML, /class="waterfall-source-logo"/);
assert.match(preferences.innerHTML, /data:image\/png;base64,logo/);
assert.match(preferences.innerHTML, /data-waterfall-source="youtube"/);

window.__aiphoneApplyWaterfallUpdate({
  surfaceId: 'surface-1',
  enabledSources: ['youtube'],
  aggregateHtml: '',
  candidates: [],
  sources: [],
  replenishing: false,
  exhausted: true
});
assert.match(track.innerHTML, /\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f/);
assert.doesNotMatch(track.innerHTML, /至少开启一个来源/);
assert.doesNotMatch(track.innerHTML, /data-waterfall-empty-sources/);

window.__aiphoneApplyWaterfallUpdate({
  surfaceId: 'surface-1',
  enabledSources: ['youtube'],
  aggregateHtml: '',
  candidates: [],
  sources: [],
  replenishing: true,
  exhausted: false
});
assert.match(track.innerHTML, /\\u6b63\\u5728\\u8865\\u5145\\u5185\\u5bb9/);
assert.doesNotMatch(track.innerHTML, /至少开启一个来源/);
assert.doesNotMatch(track.innerHTML, /\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f/);

window.__aiphoneApplyWaterfallUpdate({
  surfaceId: 'surface-1',
  enabledSources: ['youtube'],
  aggregateHtml: '',
  candidates: [],
  sources: [{
    source: 'youtube',
    phase: 'error',
    continuation: { kind: 'cursor', value: 'next' },
    inFlight: false
  }],
  replenishing: false,
  exhausted: false
});
assert.match(track.innerHTML, /\\u6b63\\u5728\\u6c47\\u96c6\\u5185\\u5bb9\\u2026/);
assert.doesNotMatch(track.innerHTML, /至少开启一个来源/);
assert.doesNotMatch(track.innerHTML, /\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f/);

const disabledCandidate = candidate('disabled-x');
disabledCandidate.source = 'x';
window.__aiphoneApplyWaterfallUpdate({
  surfaceId: 'surface-1',
  enabledSources: ['youtube'],
  aggregateHtml: '',
  candidates: [disabledCandidate],
  sources: [
    { source: 'youtube', phase: 'exhausted', continuation: null, inFlight: false },
    { source: 'x', phase: 'loading', continuation: null, inFlight: true }
  ],
  replenishing: false,
  exhausted: true
});
assert.match(track.innerHTML, /\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f/);
assert.doesNotMatch(track.innerHTML, /disabled-x/);

window.__aiphoneApplyWaterfallUpdate({
  surfaceId: 'surface-1',
  enabledSources: ['x'],
  aggregateHtml: '',
  candidates: [disabledCandidate],
  sources: [
    { source: 'youtube', phase: 'exhausted', continuation: null, inFlight: false },
    { source: 'x', phase: 'success', continuation: null, inFlight: false }
  ],
  replenishing: false,
  exhausted: false
});
assert.match(track.innerHTML, /disabled-x/);
assert.doesNotMatch(track.innerHTML, /\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f/);
