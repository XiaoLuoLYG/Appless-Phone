function parsedLayout(layout) {
  if (typeof layout !== 'string') return layout && typeof layout === 'object' ? layout : {};
  try {
    return JSON.parse(layout);
  } catch (_error) {
    return {};
  }
}

function layoutText(layout) {
  const values = [];
  const visit = (node) => {
    if (node === null || typeof node !== 'object') return;
    for (const key of ['text', 'content', 'description', 'hint', 'accessibilityText']) {
      if (typeof node[key] === 'string' && node[key].trim().length > 0) values.push(node[key].trim());
    }
    visit(node.attributes);
    for (const child of node.children || node.nodes || []) visit(child);
  };
  visit(parsedLayout(layout));
  return values;
}

export function heartCountFromLayout(layout) {
  for (const value of layoutText(layout)) {
    const count = /打开心上事\s*[，,]?\s*共\s*(\d+)\s*件/.exec(value);
    if (count !== null) return Number.parseInt(count[1], 10);
    if (value === '打开心上事') return 0;
  }
  return null;
}

export function hasRememberSuggestion(layout) {
  const text = layoutText(layout);
  return text.some((value) => /记在心上/.test(value) && !/已记在心上/.test(value));
}

export function hasBimDirectory(layout) {
  const text = layoutText(layout);
  return text.includes('心上事') &&
    ['进行中', '沉静', '已收起', '还没有心上事', '正在发生', '最近沉静']
      .some((marker) => text.includes(marker));
}

export function hasBimHome(layout) {
  const text = layoutText(layout);
  return text.includes('Appless') &&
    text.some((value) => /^打开心上事(?:\s*[，,]\s*共\s*\d+\s*件)?$/.test(value)) &&
    !hasBimDirectory(layout);
}

export function hasConversationTranscript(layout) {
  const text = layoutText(layout);
  return text.includes('生成轨迹') || text.includes('暂无对话轨迹') || text.some((value) =>
    /^(?:用户|我|你|助手|用户消息|助手消息|聊天记录|对话记录|user|assistant)\s*(?:[:：]|消息|记录)/i.test(value));
}

export function hasBimExecutionBar(layout) {
  const text = layoutText(layout);
  return text.includes('正在处理') && text.includes('停止') &&
    text.some((value) => value.includes('正在更新心上事'));
}

export function hasZeroCandidateBimRoute(logText) {
  return /\[AIPhone\]\[BimRoute\][^\n]*\bcandidates=0\b[^\n]*\bsemantic=false\b/.test(String(logText || ''));
}

export function hasMainAgentResult(logText) {
  return String(logText || '').split('\n').some((line) =>
    /\[AIPhone\]\[MultiAgentTurnResult\][^\n]*\bstatus=(?:success|partial|empty)\b/.test(line) &&
    /\bmessageChars=[1-9]\d*\b/.test(line));
}

export function bimSmokeStatus(statuses) {
  if (statuses.includes('FAIL')) return 'FAIL';
  return statuses.includes('BLOCKED') ? 'BLOCKED' : 'PASS';
}

export function bimScenarioStatus(ok, blockedReason) {
  if (String(blockedReason || '').length > 0) return 'BLOCKED';
  return ok ? 'PASS' : 'FAIL';
}

export function bimCleanSessionBlocker(cleanRequested, cleanSucceeded) {
  if (!cleanRequested) return 'BIM smoke requires explicit --clean-data or AIPHONE_SMOKE_CLEAN_DATA=1.';
  return cleanSucceeded ? '' : 'BIM app data could not be cleaned; count evidence is not isolated.';
}

export function sanitizeBimFailureReason(error) {
  const raw = error instanceof Error ? error.message : String(error || '');
  return raw
    .replace(/([?&](?:api[_-]?key|access[_-]?token|token|secret|password)=)[^&\s]*/gi, '$1<redacted>')
    .replace(/\b(Bearer|Basic)\s+\S+/gi, '$1 <redacted>')
    .replace(/\bsk-[A-Za-z0-9_-]{8,}\b/g, '<redacted>')
    .slice(0, 500);
}

const BIM_SCENARIO_IDS = ['suggestion', 'remember', 'directory', 'detail', 'update', 'main-agent'];

export function completeBimScenarios(scenarios, failureReason, failedId = '') {
  const completed = scenarios.slice();
  const reason = sanitizeBimFailureReason(failureReason);
  if (failedId.length > 0 && !completed.some((scenario) => scenario.id === failedId)) {
    completed.push({ id: failedId, status: 'FAIL', ok: false, reason });
  }
  for (const id of BIM_SCENARIO_IDS) {
    if (!completed.some((scenario) => scenario.id === id)) {
      completed.push({ id, status: 'BLOCKED', ok: false, reason: `Blocked by prerequisite: ${reason}` });
    }
  }
  return completed;
}
