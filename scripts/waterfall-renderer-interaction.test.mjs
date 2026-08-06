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
const reasonPanel = element();
reasonPanel.hidden = true;
reasonPanel.textContent = '';
const reasonButton = element();
const documentListeners = {};
const actions = [];
const document = {
  getElementById: (id) => ({
    'waterfall-discovery': overlay,
    'waterfall-track': track,
    'waterfall-preferences': preferences,
    'waterfall-reason-panel': reasonPanel
  })[id] ?? null,
  querySelector: () => null,
  querySelectorAll: (selector) => selector === '[data-waterfall-reason]' ? [reasonButton] : [],
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
  coverUrl: '',
  publishedAt: '',
  reason: '标题命中查询'
});
const window = {
  __aiphoneWaterfallInitial: {
    surfaceId: 'surface-1',
    enabledSources: ['youtube'],
    aggregateHtml: '',
    candidates: [candidate('current'), candidate('next')],
    sources: []
  },
  AIPhoneHome: {
    postAction: (value) => actions.push(JSON.parse(value))
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
reasonButton.emit('click');
assert.equal(reasonPanel.hidden, false);
assert.equal(reasonPanel.textContent, '推荐理由：标题命中查询');
assert.equal(reasonPanel.classList.contains('active'), true);
reasonButton.emit('click');
assert.equal(reasonPanel.hidden, true);
assert.equal(reasonPanel.classList.contains('active'), false);
reasonButton.emit('click');
assert.equal(reasonPanel.hidden, false);
assert.equal(reasonPanel.classList.contains('active'), true);

track.scrollTop = 600;
track.emit('scroll');
await new Promise((resolve) => setTimeout(resolve, 120));
assert.equal(actions.at(-1)?.id, 'waterfall.feed.advance');
