import { HtmlHomeBlock, HtmlHomeDocument } from './HtmlHomeTypes';
import { escapeScriptJson, renderHtmlHomeDocument } from './HtmlHomeRenderer';

interface MultiTaskEmbedPayload {
  sectionId: string;
  html: string;
}

interface MultiTaskSectionBlockPayload {
  id: string;
  kind: string;
  title: string;
  sectionId?: string;
  status?: string;
  subtitle?: string;
  rawPreview?: string;
}

export interface MultiTaskHomePayload {
  title: string;
  subtitle: string;
  activeSectionId: string;
  blocks: MultiTaskSectionBlockPayload[];
  embeds: MultiTaskEmbedPayload[];
  isBusy: boolean;
}

const EMBEDDED_ACTION_BRIDGE: string =
  '<script>(function(){window.AIPhoneHome=window.AIPhoneHome||{};' +
  'window.AIPhoneHome.postAction=function(raw){' +
  'try{if(window.parent&&window.parent!==window&&window.parent.AIPhoneHome&&' +
  'typeof window.parent.AIPhoneHome.postAction===\'function\'){' +
  'window.parent.AIPhoneHome.postAction(raw);return;}}catch(e){}' +
  'try{window.parent.postMessage({type:\'aiphone-action\',raw:raw},\'*\');}catch(e2){}};' +
  '})();</script>';

const MULTI_TASK_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f4f1ec;
  --ink: #211b17;
  --muted: #75695f;
  --line: rgba(33, 27, 23, 0.12);
  --accent: #8b5a45;
  --accent-soft: rgba(139, 90, 69, 0.12);
  --panel: rgba(255, 255, 255, 0.92);
}
* { box-sizing: border-box; }
button { font: inherit; }
html, body {
  height: 100%;
  min-height: 100%;
}
body {
  margin: 0;
  overflow: hidden;
  background: var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", Arial, sans-serif;
}
#app {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 100%;
}
.multi-shell {
  display: flex;
  flex-direction: column;
  flex: 1;
  height: 100%;
  min-height: 100%;
  padding: 0;
}
.multi-tabs {
  display: block;
  flex-shrink: 0;
  margin: 0;
  padding: 0 10px 6px;
  background: transparent;
  border-bottom: 0;
}
.multi-tabs-track {
  display: flex;
  gap: 5px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
  padding: 3px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.72);
  border: 1px solid rgba(33, 27, 23, 0.08);
  box-shadow: inset 0 1px 2px rgba(33, 27, 23, 0.04);
}
.multi-tabs-track::-webkit-scrollbar { display: none; }
.multi-tab {
  position: relative;
  flex: 1 0 auto;
  min-width: 0;
  border: 0;
  background: transparent;
  color: var(--muted);
  border-radius: 14px;
  padding: 7px 12px;
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.01em;
  line-height: 1.2;
  white-space: nowrap;
  cursor: pointer;
  transition: background 0.18s ease, color 0.18s ease, box-shadow 0.18s ease, transform 0.18s ease;
}
.multi-tab:active { transform: scale(0.98); }
.multi-tab.active {
  background: #fffaf4;
  color: var(--accent);
  box-shadow: 0 2px 10px rgba(139, 90, 69, 0.14);
}
.multi-tab.loading::after {
  content: '';
  display: inline-block;
  width: 6px;
  height: 6px;
  margin-left: 6px;
  border-radius: 50%;
  background: currentColor;
  opacity: 0.72;
  vertical-align: 1px;
  animation: multi-tab-pulse 1s ease-in-out infinite;
}
@keyframes multi-tab-pulse {
  0%, 100% { opacity: 0.34; transform: scale(0.88); }
  50% { opacity: 1; transform: scale(1); }
}
.multi-panels {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-height: 0;
  gap: 0;
}
.multi-panel {
  display: none;
  flex: 1;
  min-height: 0;
  border: 0;
  border-radius: 0;
  background: transparent;
  overflow: hidden;
}
.multi-panel.active {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-height: 0;
}
.multi-embed-frame {
  display: block;
  width: 100%;
  height: 100%;
  flex: 1;
  min-height: 0;
  border: 0;
  background: #f5f2ee;
}
.multi-fallback {
  padding: 14px;
  color: var(--muted);
  white-space: pre-wrap;
}
`;

const MULTI_TASK_SCRIPT: string = `
(function () {
  function text(value) { return value === undefined || value === null ? '' : String(value); }
  function list(value) { return Array.isArray(value) ? value : []; }
  function add(parent, tag, className, content) {
    var node = document.createElement(tag);
    if (className) { node.className = className; }
    if (content !== undefined) { node.textContent = content; }
    parent.appendChild(node);
    return node;
  }
  function parsePayload(raw) {
    if (raw === undefined || raw === null) { return {}; }
    if (typeof raw === 'object') { return raw; }
    try { return JSON.parse(text(raw)) || {}; } catch (error) { return {}; }
  }
  function embedMap(data) {
    var embeds = {};
    list(data && data.embeds).forEach(function (entry) {
      if (entry && text(entry.sectionId).length > 0) {
        embeds[text(entry.sectionId)] = text(entry.html);
      }
    });
    return embeds;
  }
  function sectionBlocks(data) {
    return list(data && data.blocks).filter(function (block) {
      return text(block && block.kind) === 'multi-task-section';
    });
  }
  function resolveActiveId(data, blocks) {
    var activeId = text(data && data.activeSectionId);
    if (activeId.length > 0) { return activeId; }
    for (var index = 0; index < blocks.length; index++) {
      var candidate = blocks[index];
      var status = text(candidate && candidate.status);
      if (status === 'ready' || status === 'error') {
        return text(candidate.sectionId) || text(candidate.id);
      }
    }
    if (blocks.length > 0) {
      return text(blocks[0].sectionId) || text(blocks[0].id);
    }
    return '';
  }
  function embedKey(html) {
    return text(html).length.toString() + ':' + text(html).slice(0, 96);
  }
  function isLoadingStatus(status) {
    var value = text(status);
    return value === 'running' || value === 'queued' || value === 'loading';
  }
  var ui = {
    shell: null,
    tabs: null,
    tabsTrack: null,
    panels: null,
    activeId: '',
    userPinned: false
  };
  function ensureShell(data) {
    var app = document.getElementById('app');
    if (!app) { return false; }
    if (ui.shell !== null && ui.tabs !== null && ui.tabsTrack !== null && ui.panels !== null) {
      return true;
    }
    app.textContent = '';
    ui.shell = add(app, 'main', 'multi-shell');
    ui.tabs = add(ui.shell, 'nav', 'multi-tabs');
    ui.tabsTrack = add(ui.tabs, 'div', 'multi-tabs-track');
    ui.panels = add(ui.shell, 'div', 'multi-panels');
    return true;
  }
  function showSection(sectionId) {
    ui.activeId = sectionId;
    Array.prototype.slice.call(document.querySelectorAll('.multi-tab')).forEach(function (button) {
      button.classList.toggle('active', text(button.getAttribute('data-section-id')) === sectionId);
    });
    Array.prototype.slice.call(document.querySelectorAll('.multi-panel')).forEach(function (panel) {
      panel.classList.toggle('active', text(panel.getAttribute('data-section-id')) === sectionId);
    });
  }
  function postSectionActivate(block, sectionId) {
    try {
      if (window.AIPhoneHome && typeof window.AIPhoneHome.postAction === 'function') {
        window.AIPhoneHome.postAction(JSON.stringify({
          id: 'multi_task.section.activate',
          label: text(block && block.title) || sectionId,
          prompt: sectionId,
          variant: 'secondary',
          kind: 'client'
        }));
      }
    } catch (error) {}
  }
  function bindTab(button, block, sectionId) {
    if (button.getAttribute('data-bound') === 'true') { return; }
    button.setAttribute('data-bound', 'true');
    button.addEventListener('click', function () {
      if (ui.activeId === sectionId) { return; }
      ui.userPinned = true;
      showSection(sectionId);
      postSectionActivate(block, sectionId);
    });
  }
  function upsertTab(block, sectionId) {
    var button = ui.tabsTrack.querySelector('.multi-tab[data-section-id="' + sectionId + '"]');
    if (button === null) {
      button = add(ui.tabsTrack, 'button', 'multi-tab', text(block.title) || sectionId);
      button.type = 'button';
      button.setAttribute('data-section-id', sectionId);
      bindTab(button, block, sectionId);
    } else {
      button.textContent = text(block.title) || sectionId;
      bindTab(button, block, sectionId);
    }
    button.classList.toggle('loading', isLoadingStatus(block.status));
    return button;
  }
  function upsertPanelBody(panel, block, sectionId, embedHtml) {
    var iframe = panel.querySelector('.multi-embed-frame');
    var fallback = panel.querySelector('.multi-fallback');
    if (embedHtml.length > 0) {
      if (fallback !== null) { panel.removeChild(fallback); }
      if (iframe === null) {
        iframe = add(panel, 'iframe', 'multi-embed-frame');
        iframe.setAttribute('title', text(block.title) || sectionId);
      }
      var nextKey = embedKey(embedHtml);
      if (text(iframe.getAttribute('data-embed-key')) !== nextKey) {
        iframe.srcdoc = embedHtml;
        iframe.setAttribute('data-embed-key', nextKey);
      }
      return;
    }
    if (iframe !== null && text(iframe.getAttribute('data-embed-key')).length > 0) {
      if (fallback !== null) { panel.removeChild(fallback); }
      return;
    }
    if (iframe !== null) { panel.removeChild(iframe); }
    var message = text(block.subtitle) || text(block.rawPreview) || '等待结果...';
    if (fallback === null) {
      add(panel, 'div', 'multi-fallback', message);
    } else {
      fallback.textContent = message;
    }
  }
  function upsertPanel(block, sectionId, embeds) {
    var panel = ui.panels.querySelector('.multi-panel[data-section-id="' + sectionId + '"]');
    if (panel === null) {
      panel = add(ui.panels, 'section', 'multi-panel');
      panel.setAttribute('data-section-id', sectionId);
    }
    upsertPanelBody(panel, block, sectionId, text(embeds[sectionId]));
    return panel;
  }
  function reorderChildren(parent, selector, orderedIds) {
    orderedIds.forEach(function (sectionId) {
      var node = parent.querySelector(selector + '[data-section-id="' + sectionId + '"]');
      if (node !== null) { parent.appendChild(node); }
    });
  }
  function renderMultiTaskHome(data) {
    if (!ensureShell(data)) { return; }
    var embeds = embedMap(data);
    var blocks = sectionBlocks(data);
    var payloadActiveId = resolveActiveId(data, blocks);
    var targetActiveId = ui.userPinned && ui.activeId.length > 0 ? ui.activeId : payloadActiveId;
    var orderedIds = [];
    blocks.forEach(function (block) {
      var sectionId = text(block.sectionId) || text(block.id);
      if (sectionId.length === 0) { return; }
      orderedIds.push(sectionId);
      upsertTab(block, sectionId);
      upsertPanel(block, sectionId, embeds);
    });
    reorderChildren(ui.tabsTrack, '.multi-tab', orderedIds);
    reorderChildren(ui.panels, '.multi-panel', orderedIds);
    if (targetActiveId.length > 0 && targetActiveId !== ui.activeId) {
      showSection(targetActiveId);
    } else if (blocks.length === 0) {
      ui.tabsTrack.textContent = '';
      ui.panels.textContent = '';
      add(ui.panels, 'p', 'multi-fallback', '正在等待并行任务结果...');
    }
  }
  window.addEventListener('message', function (event) {
    var payload = event && event.data;
    if (!payload || text(payload.type) !== 'aiphone-action') { return; }
    if (window.AIPhoneHome && typeof window.AIPhoneHome.postAction === 'function') {
      window.AIPhoneHome.postAction(text(payload.raw));
    }
  });
  window.__aiphoneApplyMultiTaskUpdate = function (raw) {
    renderMultiTaskHome(parsePayload(raw));
  };
  window.__aiphonePatchEmbeddedLuckinPaymentStatus = function (patchJson) {
    try {
      var patch = JSON.parse(text(patchJson));
      var sectionId = text(patch && patch.sectionId);
      var selector = sectionId.length > 0 ?
        '.multi-panel[data-section-id="' + sectionId + '"] .multi-embed-frame' :
        '.multi-panel.active .multi-embed-frame';
      var frame = document.querySelector(selector);
      if (!frame || !frame.contentWindow || !frame.contentWindow.AIPhoneHome ||
        typeof frame.contentWindow.AIPhoneHome.patchLuckinPaymentStatus !== 'function') {
        return false;
      }
      return frame.contentWindow.AIPhoneHome.patchLuckinPaymentStatus(patchJson);
    } catch (error) {
      return false;
    }
  };
  var dataNode = document.getElementById('multi-task-data');
  var initial = {};
  try {
    initial = JSON.parse(dataNode && dataNode.textContent ? dataNode.textContent : '{}') || {};
  } catch (error) {
    initial = {};
  }
  renderMultiTaskHome(initial);
})();
`;

function injectEmbeddedActionBridge(html: string): string {
  const headIndex = html.indexOf('<head>');
  if (headIndex >= 0) {
    return html.substring(0, headIndex + 6) + EMBEDDED_ACTION_BRIDGE + html.substring(headIndex + 6);
  }
  return EMBEDDED_ACTION_BRIDGE + html;
}

function embeddedSectionHtml(block: HtmlHomeBlock, _isBusy: boolean): string {
  if (block.embeddedDocument === undefined || block.embeddedDocument.blocks.length === 0) {
    return '';
  }
  const html = renderHtmlHomeDocument(block.embeddedDocument, false);
  return injectEmbeddedActionBridge(html);
}

function multiTaskPayloadBlocks(blocks: HtmlHomeBlock[]): MultiTaskSectionBlockPayload[] {
  const next: MultiTaskSectionBlockPayload[] = [];
  blocks.forEach((block: HtmlHomeBlock) => {
    if (block.kind !== 'multi-task-section') {
      return;
    }
    const item: MultiTaskSectionBlockPayload = {
      id: block.id,
      kind: block.kind,
      title: block.title,
      sectionId: block.sectionId,
      status: block.status,
      subtitle: block.subtitle,
      rawPreview: block.rawPreview
    };
    next.push(item);
  });
  return next;
}

export function buildMultiTaskHomePayload(document: HtmlHomeDocument, isBusy: boolean = false): MultiTaskHomePayload {
  const embeds: MultiTaskEmbedPayload[] = [];
  document.blocks.forEach((block: HtmlHomeBlock) => {
    if (block.kind !== 'multi-task-section') {
      return;
    }
    const sectionId = block.sectionId ?? block.id;
    const html = embeddedSectionHtml(block, isBusy);
    if (html.length === 0) {
      return;
    }
    embeds.push({
      sectionId: sectionId,
      html: html
    });
  });
  return {
    title: document.title,
    subtitle: document.subtitle,
    activeSectionId: document.activeSectionId ?? '',
    blocks: multiTaskPayloadBlocks(document.blocks),
    embeds: embeds,
    isBusy: isBusy
  };
}

export function multiTaskHomePayloadJson(document: HtmlHomeDocument, isBusy: boolean = false): string {
  return JSON.stringify(buildMultiTaskHomePayload(document, isBusy));
}

export function shouldRenderMultiTaskHomeDocument(document: HtmlHomeDocument): boolean {
  return document.kind === 'multi-task';
}

export function renderMultiTaskHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  const payloadData = buildMultiTaskHomePayload(document, isBusy);
  const payloadJson = escapeScriptJson(JSON.stringify(payloadData));
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<style>${MULTI_TASK_CSS}</style>
</head>
<body data-scene="multi-task">
<div id="app"></div>
<script id="multi-task-data" type="application/json">${payloadJson}</script>
<script>${MULTI_TASK_SCRIPT}</script>
</body>
</html>`;
}
