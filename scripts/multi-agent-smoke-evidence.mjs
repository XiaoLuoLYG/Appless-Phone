const TURN_STATUSES = new Set(['success', 'partial', 'empty', 'error', 'canceled']);
const DATA_STATUSES = new Set(['success', 'partial', 'empty', 'error']);
const ACTION_STATUSES = new Set(['success', 'error', 'canceled']);
const GENERATED_SURFACE = /^loop_surface_[0-9]+(?:_[0-9]+)?$/;
const LIFECYCLE_MARKERS = new Set([
  'MultiAgentInput', 'MultiAgentDataTask', 'MultiAgentDataResult',
  'MultiAgentUiTask', 'MultiAgentUiResult', 'MultiAgentTaskError',
  'MultiAgentActionPlan', 'MultiAgentActionRun', 'MultiAgentActionResult',
  'MultiAgentTurnResult'
]);
const DUPLICATE_HILOG_MAX_SKEW_MS = 1;

function duplicateHilogChannelPair(left, right) {
  return (left === 'A00000/AIPHONE' && right === 'A03D00/JSAPP') ||
    (left === 'A03D00/JSAPP' && right === 'A00000/AIPHONE');
}

function duplicateHilogTimestamp(left, right) {
  if (left === right) return true;
  const milliseconds = (value) => Date.parse(`2000-${value.replace(/\s+/, 'T')}Z`);
  const leftMs = milliseconds(left);
  const rightMs = milliseconds(right);
  return Number.isFinite(leftMs) && Number.isFinite(rightMs) &&
    Math.abs(leftMs - rightMs) <= DUPLICATE_HILOG_MAX_SKEW_MS;
}

function records(logText) {
  const result = [];
  for (const [index, line] of String(logText || '').split('\n').entries()) {
    const marker = /\[AIPhone\]\[([^\]]+)\]/.exec(line);
    if (marker === null) continue;
    const fields = {};
    for (const match of line.matchAll(/\b([A-Za-z][A-Za-z0-9]*)=([^\s]+)/g)) {
      fields[match[1]] = match[2];
    }
    const channelMatch = /\b(A00000|A03D00)\/(?:[^/\s:]+\/)*(AIPhone|JSAPP):\s*$/i
      .exec(line.slice(0, marker.index));
    const channel = channelMatch === null ? '' :
      `${channelMatch[1].toUpperCase()}/${channelMatch[2].toUpperCase()}`;
    const timestamp = /^\s*(\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3})\b/.exec(line)?.[1] || '';
    const normalized = line.slice(marker.index).trim();
    const previous = result.at(-1);
    if (LIFECYCLE_MARKERS.has(marker[1]) && previous !== undefined &&
      previous.duplicatePaired !== true &&
      timestamp.length > 0 && previous.timestamp.length > 0 &&
      duplicateHilogTimestamp(previous.timestamp, timestamp) &&
      previous.normalized === normalized &&
      duplicateHilogChannelPair(previous.channel, channel)) {
      previous.duplicatePaired = true;
      continue;
    }
    result.push({
      marker: marker[1],
      fields,
      index,
      line,
      channel,
      timestamp,
      normalized,
      duplicatePaired: false
    });
  }
  return result;
}

export function latestMultiAgentUiSurface(logText, options = {}) {
  let latest = null;
  for (const item of records(logText)) {
    if (item.marker === 'MultiAgentUiResult' && item.fields.state === 'result' &&
      GENERATED_SURFACE.test(item.fields.surface || '') && item.index > (options.afterIndex ?? -1) &&
      (!options.expectedConversationId || item.fields.conversation === options.expectedConversationId) &&
      (!options.expectedTurnId || item.fields.turn === options.expectedTurnId)) {
      latest = {
        conversationId: item.fields.conversation,
        turnId: item.fields.turn,
        taskId: item.fields.task,
        surfaceId: item.fields.surface
      };
    }
  }
  return latest;
}

function list(value) {
  return !value || value === 'none' ? [] : value.split(',').filter(Boolean);
}

function sameMultiset(actual, expected) {
  return [...actual].sort().join('\n') === [...expected].sort().join('\n');
}

function nonnegativeInteger(value) {
  return /^\d+$/.test(value || '') && Number(value) >= 0;
}

function targetRecords(all, options) {
  const inputs = all.filter((item) => item.marker === 'MultiAgentInput');
  const selected = [...inputs].reverse().find((item) =>
    (!options.conversationId || item.fields.conversation === options.conversationId) &&
    (!options.turnId || item.fields.turn === options.turnId));
  if (selected === undefined) {
    return { selected: null, events: [], window: [], stale: false, late: [] };
  }
  const conversation = selected.fields.conversation || '';
  const turn = selected.fields.turn || '';
  const terminal = all.find((item) => item.index > selected.index &&
    item.marker === 'MultiAgentTurnResult' && item.fields.conversation === conversation &&
    item.fields.turn === turn && item.fields.task === selected.fields.task);
  const newerInput = inputs.find((item) => item.index > selected.index &&
    (terminal === undefined || item.index < terminal.index) &&
    item.fields.conversation === conversation && item.fields.turn !== turn);
  const endIndex = terminal?.index ?? Number.MAX_SAFE_INTEGER;
  const events = all.filter((item) => item.index >= selected.index && item.index <= endIndex &&
    item.fields.conversation === conversation && item.fields.turn === turn);
  const late = terminal === undefined ? [] : all.filter((item) =>
    item.index > terminal.index && item.fields.conversation === conversation &&
    item.fields.turn === turn && LIFECYCLE_MARKERS.has(item.marker));
  return {
    selected,
    events,
    stale: newerInput !== undefined,
    late,
    window: all.filter((item) => item.index >= selected.index && item.index <= endIndex)
  };
}

function externalOrSyntheticError(events) {
  return events.some((item) =>
    /(?:ProviderExternalError|LocalToolException|SyntheticFallback)/.test(item.marker) ||
    /(?:^|\s)synthetic=true(?:\s|$)/.test(item.line) ||
    /(?:^|\s)(?:source|provider)=(?:mock|fixture|demo|synthetic)(?:\s|$)/i.test(item.line) ||
    /"(?:status|success)"\s*:\s*(?:"error"|false)/i.test(item.line));
}

function aggregateStatus(terminals) {
  if (terminals.length === 0) return '';
  const statuses = terminals.map((item) => item.status);
  if (statuses.includes('partial')) return 'partial';
  const success = statuses.includes('success');
  const error = statuses.includes('error');
  if (success) return statuses.every((status) => status === 'success') ? 'success' : 'partial';
  if (error) return 'error';
  return 'empty';
}

function dependencyMatches(task, dependency, dataById) {
  if (task.fields.tool !== dependency.toolId || task.fields.binding !== 'true' ||
    task.fields.path !== dependency.path || task.fields.target !== dependency.target) {
    return false;
  }
  const predecessor = dataById.get(task.fields.predecessor);
  return predecessor !== undefined && predecessor.fields.tool === dependency.predecessorToolId &&
    Number(predecessor.fields.round) === Number(task.fields.round) - 1 &&
    predecessor.terminalIndex < task.index;
}

export function multiAgentTurnEvidence(logText, options = {}) {
  const all = records(logText);
  const { selected, events, stale, late, window } = targetRecords(all, options);
  const failures = [];
  if (selected === null || !selected.fields.conversation || !selected.fields.turn ||
    !selected.fields.task) failures.push('missing_input');
  if (stale) failures.push('stale_turn');
  if (late.length > 0) failures.push('late_same_turn_marker');

  const dataTasks = events.filter((item) => item.marker === 'MultiAgentDataTask');
  const dataById = new Map();
  for (const task of dataTasks) {
    const round = Number(task.fields.round || 0);
    if (!task.fields.task || dataById.has(task.fields.task) || !task.fields.tool ||
      !/^[1-9]\d*$/.test(task.fields.round || '') ||
      !['true', 'false'].includes(task.fields.binding || 'false')) {
      failures.push('invalid_data_task');
      continue;
    }
    task.round = round;
    task.terminalIndex = Number.MAX_SAFE_INTEGER;
    dataById.set(task.fields.task, task);
  }
  const rounds = [...new Set([...dataById.values()].map((item) => item.round))]
    .sort((left, right) => left - right);
  if (rounds.some((round, index) => round !== index + 1) ||
    rounds.length < Number(options.minimumDataRounds || 0)) {
    failures.push('invalid_data_rounds');
  }

  const terminalResults = [];
  for (const task of dataById.values()) {
    const matches = events.filter((item) => item.fields.task === task.fields.task &&
      (item.marker === 'MultiAgentDataResult' || item.marker === 'MultiAgentTaskError'));
    if (matches.length !== 1 || matches[0].index <= task.index) {
      failures.push('missing_or_duplicate_data_terminal');
      continue;
    }
    const terminal = matches[0];
    task.terminalIndex = terminal.index;
    if (terminal.marker === 'MultiAgentTaskError') {
      terminalResults.push({ taskId: task.fields.task, toolId: task.fields.tool, status: 'error' });
      continue;
    }
    const status = terminal.fields.status || '';
    const errorPresent = terminal.fields.error === 'true';
    if (terminal.fields.tool !== task.fields.tool || !DATA_STATUSES.has(status) ||
      (status === 'error') !== errorPresent) failures.push('invalid_data_terminal');
    terminalResults.push({ taskId: task.fields.task, toolId: task.fields.tool, status });
  }
  for (const result of events.filter((item) => item.marker === 'MultiAgentDataResult')) {
    if (!dataById.has(result.fields.task)) failures.push('unknown_data_terminal');
  }

  for (const task of dataById.values()) {
    if (task.round <= 1) continue;
    const predecessors = [...dataById.values()].filter((item) => item.round === task.round - 1);
    if (predecessors.length === 0 ||
      predecessors.some((item) => item.terminalIndex >= task.index)) {
      failures.push('overlapping_data_rounds');
    }
  }
  for (const dependency of options.expectedDependencies || []) {
    const candidates = [...dataById.values()].filter((task) =>
      dependencyMatches(task, dependency, dataById));
    if (candidates.length !== 1) failures.push('missing_dependency_binding');
  }

  const uiTasks = events.filter((item) => item.marker === 'MultiAgentUiTask');
  const uiById = new Map();
  const dependencyCounts = new Map();
  for (const task of uiTasks) {
    const dependencies = list(task.fields.dataTasks);
    if (!task.fields.task || uiById.has(task.fields.task) || dependencies.length === 0 ||
      new Set(dependencies).size !== dependencies.length) {
      failures.push('invalid_ui_task');
      continue;
    }
    task.dependencies = dependencies;
    uiById.set(task.fields.task, task);
    for (const taskId of dependencies) {
      dependencyCounts.set(taskId, (dependencyCounts.get(taskId) || 0) + 1);
    }
  }
  const uiTerminals = [];
  let uiFailed = false;
  for (const task of uiById.values()) {
    if (task.dependencies.some((taskId) => !dataById.has(taskId))) {
      failures.push('unknown_ui_dependency');
    }
    const results = events.filter((item) => item.marker === 'MultiAgentUiResult' &&
      item.fields.task === task.fields.task);
    const taskErrors = events.filter((item) => item.marker === 'MultiAgentTaskError' &&
      item.fields.task === task.fields.task);
    const terminals = results.filter((item) => ['result', 'error'].includes(item.fields.state));
    const terminal = terminals[0] || taskErrors[0];
    if (terminals.length + taskErrors.length !== 1 || terminal === undefined ||
      terminal.index <= task.index ||
      task.dependencies.some((taskId) => (dataById.get(taskId)?.terminalIndex ??
        Number.MAX_SAFE_INTEGER) >= terminal.index) ||
      results.some((item) => item.index <= task.index ||
        !['skeleton', 'result', 'error', 'action'].includes(item.fields.state))) {
      failures.push('invalid_ui_terminal');
      continue;
    }
    if (taskErrors.length === 1) {
      uiFailed = true;
      continue;
    }
    const surfaces = new Set(results.map((item) => item.fields.surface));
    if (surfaces.size !== 1 || !terminal.fields.surface || terminal.fields.surface === 'none') {
      failures.push('invalid_ui_surface');
    }
    terminal.uiState = terminal.fields.state;
    uiTerminals.push(terminal);
    if (terminal.fields.state === 'error') uiFailed = true;
  }
  for (const result of events.filter((item) => item.marker === 'MultiAgentUiResult')) {
    if (!uiById.has(result.fields.task)) failures.push('unknown_ui_terminal');
  }
  for (const taskId of dataById.keys()) {
    if (dependencyCounts.get(taskId) !== 1) failures.push('missing_ui_task');
  }

  const knownTasks = new Set([
    selected?.fields.task || '', ...dataById.keys(), ...uiById.keys()
  ]);
  for (const error of events.filter((item) => item.marker === 'MultiAgentTaskError')) {
    if (!knownTasks.has(error.fields.task) || error.fields.task === selected?.fields.task) {
      failures.push('unexpected_task_error');
    }
  }

  const virtualPlans = events.filter((item) => item.marker === 'MultiAgentActionPlan' &&
    item.fields.virtual === 'true' && list(item.fields.dataTasks).length === 0);
  const toolIds = [
    ...dataTasks.map((item) => item.fields.tool),
    ...virtualPlans.flatMap((item) => list(item.fields.actions))
  ].filter(Boolean);
  if (Object.hasOwn(options, 'expectedToolIds') &&
    !sameMultiset(toolIds, options.expectedToolIds || [])) failures.push('planned_tools_mismatch');

  const turnResults = events.filter((item) => item.marker === 'MultiAgentTurnResult' &&
    selected !== null && item.fields.task === selected.fields.task);
  if (turnResults.length !== 1) failures.push('missing_or_duplicate_turn_result');
  const turn = turnResults[0];
  const status = turn?.fields.status || '';
  if (!TURN_STATUSES.has(status) || !nonnegativeInteger(turn?.fields.roundCount) ||
    !nonnegativeInteger(turn?.fields.messageChars) || Number(turn?.fields.messageChars) === 0) {
    failures.push('invalid_turn_result');
  }
  if (rounds.length > 0 && Number(turn?.fields.roundCount || 0) < rounds.at(-1)) {
    failures.push('invalid_turn_round_count');
  }
  const finalUi = [...uiTerminals].sort((left, right) => left.index - right.index).at(-1);
  const finalUiSurface = finalUi?.fields.surface || '';
  const finalUiTools = list(uiById.get(finalUi?.fields.task || '')?.fields.dataTasks)
    .map((taskId) => dataById.get(taskId)?.fields.tool || '')
    .filter(Boolean);
  if (uiTasks.length > 0) {
    if ((finalUiSurface.length > 0 && turn?.fields.surface !== finalUiSurface) ||
      (finalUiSurface.length === 0 && turn?.fields.surface !== 'none')) {
      failures.push('turn_surface_mismatch');
    }
  }

  const virtualActions = virtualPlans.flatMap((item) => list(item.fields.actions));
  const action = multiAgentActionEvidence(events.map((item) => item.normalized).join('\n'),
    virtualPlans.length > 0 ? {
      expectedActionId: virtualActions.length === 1 ? virtualActions[0] : 'invalid',
      expectedConversationId: selected?.fields.conversation || 'invalid',
      expectedTurnId: selected?.fields.turn || 'invalid',
      expectedVirtual: true
    } : {});
  const dataStatus = aggregateStatus(terminalResults);
  const expectedTurnStatus = uiFailed ? 'error' : dataStatus;
  if (dataTasks.length > 0 && status !== 'canceled' && expectedTurnStatus !== status) {
    failures.push('terminal_status_mismatch');
  }
  if (dataTasks.length === 0 && toolIds.length > 0 && !action.complete) {
    failures.push('missing_action_terminal');
  }
  if (dataTasks.length === 0 && action.complete && status !== action.status) {
    failures.push('action_turn_status_mismatch');
  }
  const textResult = dataTasks.length === 0 && toolIds.length === 0 &&
    Number(turn?.fields.messageChars || 0) > 0 && turn?.fields.surface === 'none';
  if (dataTasks.length === 0 && toolIds.length === 0 && !textResult) failures.push('missing_text_result');
  if (externalOrSyntheticError(window) &&
    (status === 'success' || status === 'partial' || status === 'empty')) {
    failures.push('external_or_synthetic_success');
  }

  const complete = failures.length === 0;
  return {
    complete,
    ok: complete && (status === 'success' || status === 'partial' || status === 'empty'),
    status,
    conversationId: selected?.fields.conversation || '',
    turnId: selected?.fields.turn || '',
    toolIds,
    dataTasks: dataTasks.map((item) => ({
      taskId: item.fields.task,
      toolId: item.fields.tool,
      roundNumber: Number(item.fields.round || 0),
      predecessorTaskId: item.fields.predecessor || ''
    })),
    textResult,
    surfaceId: turn?.fields.surface || '',
    finalUiSurfaceId: finalUiSurface,
    finalUiToolIds: finalUiTools,
    surfaceIds: events.filter((item) => item.marker === 'MultiAgentUiResult')
      .map((item) => item.fields.surface),
    terminalIndex: turn?.index ?? -1,
    failures
  };
}

function appLogIdentity(line) {
  const match = /^\s*\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3}\s+(\d+)\s+\d+\s+\S+\s+[^/\s]+\/([^/\s:]+)(?:\/[^:\s]+)*:/.exec(line);
  return match === null ? null : { pid: match[1], process: match[2] };
}

function sameAppIdentity(line, expected) {
  const actual = appLogIdentity(line);
  return actual !== null && expected !== null &&
    actual.pid === expected.pid && actual.process === expected.process;
}

function streamingCloudResponse(line) {
  if (!/\/NETSTACK:/.test(line)) return false;
  const httpInfo = /"response_code"\s*:\s*200/.test(line) &&
    /"dst_port"\s*:\s*443/.test(line) &&
    /"content_type"\s*:\s*"text\/event-stream(?:;[^"\s]*)?"/i.test(line);
  const streamInfo = /\bRespCode\s*:\s*200\b/.test(line) &&
    /\bdport\s*:\s*443\b/.test(line) &&
    /\bisStream\s*:\s*true\b/i.test(line);
  return httpInfo || streamInfo;
}

export function modelTransportEvidence(logText, options = {}) {
  const text = String(logText || '');
  if (/\[AIPhone\]\[(?:ModelStreamResponse|ModelRawResponse)\] code=200\b/.test(text)) {
    return true;
  }
  if (/"response_code"\s*:\s*200[^\n]*"dst_port"\s*:\s*11434\b/.test(text)) {
    return true;
  }

  const lifecycle = multiAgentTurnEvidence(text, options);
  if (!lifecycle.complete || !lifecycle.ok) return false;
  const all = records(text);
  const { selected } = targetRecords(all, options);
  if (selected === null || selected.fields.conversation !== lifecycle.conversationId ||
    selected.fields.turn !== lifecycle.turnId) return false;
  const identity = appLogIdentity(selected.line);
  if (identity === null) return false;
  const terminal = all.find((item) => item.index > selected.index &&
    item.marker === 'MultiAgentTurnResult' &&
    item.fields.conversation === selected.fields.conversation &&
    item.fields.turn === selected.fields.turn &&
    item.fields.task === selected.fields.task);
  if (terminal === undefined || terminal.index !== lifecycle.terminalIndex ||
    !sameAppIdentity(terminal.line, identity)) return false;
  const plannedWork = all.find((item) => item.index > selected.index &&
    item.index < terminal.index && LIFECYCLE_MARKERS.has(item.marker));
  const modelEndIndex = plannedWork?.index ?? terminal.index;

  const request = all.find((item) => item.index > selected.index && item.index < modelEndIndex &&
    item.marker === 'ModelRequestStart' && item.fields.stream === 'true' &&
    /^https:\/\//.test(item.fields.endpoint || '') && sameAppIdentity(item.line, identity));
  if (request === undefined) return false;
  const chunk = all.find((item) => item.index > request.index && item.index < modelEndIndex &&
    item.marker === 'ModelResponseChunk' && /^[1-9]\d*$/.test(item.fields.seq || '') &&
    sameAppIdentity(item.line, identity));
  if (chunk === undefined) return false;

  const lines = text.split('\n');
  return lines.some((line, index) => index > chunk.index && index < modelEndIndex &&
    sameAppIdentity(line, identity) && streamingCloudResponse(line));
}

const DIRECT_TEXT_FORBIDDEN_MARKERS = new Set([
  'MultiAgentDataTask', 'MultiAgentDataResult', 'MultiAgentUiTask', 'MultiAgentUiResult',
  'MultiAgentTaskError', 'MultiAgentActionPlan', 'MultiAgentActionRun', 'MultiAgentActionResult',
  'ToolRequestByIntent', 'A2uiHomeToolRequestByIntent', 'ToolRequest', 'A2uiHomeToolRequest',
  'A2uiHomeToolRequestFromModel', 'LocalToolRequest', 'ToolResult', 'A2uiHomeToolResult'
]);

function nodeTextValues(node, values) {
  if (node === null || typeof node !== 'object') return;
  const attributes = node.attributes !== null && typeof node.attributes === 'object' ?
    node.attributes : {};
  for (const key of ['text', 'content', 'description', 'hint']) {
    const value = attributes[key];
    if (typeof value === 'string' && value.trim().length > 0) values.push(value.trim());
  }
  for (const child of Array.isArray(node.children) ? node.children : []) {
    nodeTextValues(child, values);
  }
}

function semanticMessages(layout) {
  const messages = [];
  let articleCount = 0;
  const visit = (node) => {
    if (node === null || typeof node !== 'object') return;
    if (node.attributes?.type === 'article') {
      articleCount += 1;
      const values = [];
      nodeTextValues(node, values);
      const roleIndexes = values
        .map((value, index) => value === 'user' || value === 'assistant' ? index : -1)
        .filter((index) => index >= 0);
      if (roleIndexes.length === 1) {
        const roleIndex = roleIndexes[0];
        messages.push({
          role: values[roleIndex],
          text: values.slice(roleIndex + 1)
            .filter((value) => value !== 'user' && value !== 'assistant')
            .join('')
        });
      }
      return;
    }
    for (const child of Array.isArray(node.children) ? node.children : []) visit(child);
  };
  visit(layout);
  const validPairs = articleCount === messages.length && messages.length % 2 === 0 &&
    messages.every((message, index) => message.text.length > 0 &&
      message.role === (index % 2 === 0 ? 'user' : 'assistant'));
  return { articleCount, messages, validPairs };
}

export function directTextVisibleEvidence(logText, baselineLayout, finalLayout, query, options = {}) {
  const text = String(logText || '');
  const failures = [];
  const capturedRecords = records(text);
  const capturedTarget = targetRecords(capturedRecords, options).selected;
  const nextInput = capturedTarget === null ? undefined : capturedRecords.find((item) =>
    item.index > capturedTarget.index && item.marker === 'MultiAgentInput' &&
    (item.fields.conversation !== capturedTarget.fields.conversation ||
      item.fields.turn !== capturedTarget.fields.turn ||
      item.fields.task !== capturedTarget.fields.task));
  const capturedLines = text.split('\n');
  const scopeText = capturedTarget === null ? '' : capturedLines
    .slice(capturedTarget.index, nextInput?.index ?? capturedLines.length)
    .join('\n');
  const lifecycle = multiAgentTurnEvidence(scopeText, options);
  if (!lifecycle.complete || !lifecycle.ok || lifecycle.status !== 'success' ||
    !lifecycle.textResult || lifecycle.surfaceId !== 'none' ||
    lifecycle.finalUiSurfaceId !== '' || lifecycle.toolIds.length !== 0 ||
    lifecycle.dataTasks.length !== 0 || lifecycle.surfaceIds.length !== 0) {
    failures.push('invalid_direct_lifecycle');
  }

  const all = records(scopeText);
  const { selected } = targetRecords(all, options);
  const terminal = selected === null ? undefined : all.find((item) =>
    item.index > selected.index && item.marker === 'MultiAgentTurnResult' &&
    item.fields.conversation === selected.fields.conversation &&
    item.fields.turn === selected.fields.turn && item.fields.task === selected.fields.task);
  if (selected === null || terminal === undefined || terminal.index !== lifecycle.terminalIndex) {
    failures.push('missing_current_terminal');
  } else {
    const currentText = scopeText.split('\n').slice(selected.index, terminal.index + 1).join('\n');
    if (!modelTransportEvidence(currentText, options)) failures.push('missing_current_transport');
  }
  if (all.some((item) => DIRECT_TEXT_FORBIDDEN_MARKERS.has(item.marker))) {
    failures.push('non_direct_work');
  }
  if (externalOrSyntheticError(all) || all.some((item) =>
    /(?:Error|Exception|Failed)$/.test(item.marker) || item.fields.ok === 'false' ||
    item.fields.success === 'false' || item.fields.status === 'error')) {
    failures.push('error_or_synthetic');
  }

  const baseline = semanticMessages(baselineLayout);
  const final = semanticMessages(finalLayout);
  const messages = final.messages;
  const expectedQuery = String(query || '').trim();
  const historyMatches = baseline.validPairs && final.validPairs &&
    messages.length === baseline.messages.length + 2 &&
    baseline.messages.every((message, index) =>
      messages[index]?.role === message.role && messages[index]?.text === message.text);
  const userIndex = baseline.messages.length;
  const user = historyMatches ? messages[userIndex] : undefined;
  const assistant = historyMatches ? messages[userIndex + 1] : undefined;
  const expectedChars = Number(terminal?.fields.messageChars || 0);
  if (!historyMatches || expectedQuery.length === 0 || user?.role !== 'user' ||
    user.text !== expectedQuery ||
    assistant?.role !== 'assistant' || assistant.text.length === 0 ||
    assistant.text === expectedQuery || assistant.text.length !== expectedChars) {
    failures.push('missing_current_visible_reply');
  }

  return {
    ok: failures.length === 0,
    replyText: assistant?.text || '',
    replyChars: assistant?.text.length || 0,
    baselineMessageCount: baseline.messages.length,
    finalMessageCount: final.messages.length,
    failures
  };
}

function optionMismatch(item, options, expectedSurface) {
  return Boolean(
    (options.expectedActionId && item.fields.action !== options.expectedActionId) ||
    (expectedSurface && item.fields.surface !== expectedSurface) ||
    (options.expectedSourceToolId && item.fields.source !== options.expectedSourceToolId) ||
    (options.expectedConversationId && item.fields.conversation !== options.expectedConversationId) ||
    (options.expectedTurnId && item.fields.turn !== options.expectedTurnId)
  );
}

export function multiAgentActionEvidence(logText, options = {}) {
  const all = records(logText);
  const expectedSurface = options.currentSurfaceId || options.surfaceId || '';
  const actionRuns = options.expectedVirtual === true ? [] : all.filter((item) => item.marker === 'MultiAgentActionRun' &&
    (!options.expectedActionId || item.fields.action === options.expectedActionId));
  if (actionRuns.some((item) => optionMismatch(item, options, expectedSurface))) {
    return { complete: false, ok: false, status: '', actionId: '', surfaceId: '', failures: ['stale_action_run'] };
  }
  for (let index = actionRuns.length - 1; index >= 0; index--) {
    const run = actionRuns[index];
    const matchingResults = all.filter((item) => item.marker === 'MultiAgentActionResult' &&
      item.fields.conversation === run.fields.conversation && item.fields.turn === run.fields.turn &&
      item.fields.task === run.fields.task && item.fields.surface === run.fields.surface &&
      item.fields.plan === run.fields.plan && item.fields.run === run.fields.run);
    const result = matchingResults[0];
    if (!run.fields.conversation || !run.fields.turn || !run.fields.task ||
      !run.fields.surface || run.fields.surface === 'none' || !run.fields.plan ||
      !run.fields.run || !run.fields.action || !run.fields.source ||
      matchingResults.length !== 1 || result.index <= run.index ||
      !ACTION_STATUSES.has(result.fields.status)) continue;
    const chain = all.filter((item) => item.index >= run.index && item.index <= result.index);
    const truthful = !externalOrSyntheticError(chain) || result.fields.status !== 'success';
    return {
      complete: truthful,
      ok: truthful && result.fields.status === 'success',
      status: result.fields.status,
      actionId: run.fields.action,
      sourceToolId: run.fields.source,
      surfaceId: run.fields.surface,
      conversationId: run.fields.conversation,
      turnId: run.fields.turn,
      taskId: run.fields.task,
      planId: run.fields.plan,
      runId: run.fields.run,
      resultIndex: result.index,
      failures: truthful ? [] : ['external_or_synthetic_success']
    };
  }

  const plans = options.expectedVirtual === false ? [] : all.filter((item) => item.marker === 'MultiAgentActionPlan' &&
    item.fields.virtual === 'true' && list(item.fields.dataTasks).length === 0 &&
    (!options.expectedActionId || list(item.fields.actions).includes(options.expectedActionId)));
  for (let index = plans.length - 1; index >= 0; index--) {
    const plan = plans[index];
    const actions = list(plan.fields.actions);
    if ((options.expectedConversationId && plan.fields.conversation !== options.expectedConversationId) ||
      (options.expectedTurnId && plan.fields.turn !== options.expectedTurnId)) continue;
    const matchingResults = all.filter((item) => item.marker === 'MultiAgentActionResult' &&
      item.fields.conversation === plan.fields.conversation && item.fields.turn === plan.fields.turn &&
      item.fields.task === plan.fields.task);
    const fabricatedRun = all.some((item) => item.marker === 'MultiAgentActionRun' &&
      item.fields.conversation === plan.fields.conversation && item.fields.turn === plan.fields.turn &&
      item.fields.task === plan.fields.task);
    const result = matchingResults[0];
    if (!plan.fields.conversation || !plan.fields.turn || !plan.fields.task ||
      plan.fields.uiTask !== plan.fields.task || actions.length !== 1 ||
      fabricatedRun || matchingResults.length !== 1 || result.index <= plan.index ||
      !result.fields.surface || result.fields.surface === 'none' || !result.fields.plan ||
      !result.fields.run || !ACTION_STATUSES.has(result.fields.status)) continue;
    const chain = all.filter((item) => item.index >= plan.index && item.index <= result.index);
    const truthful = !externalOrSyntheticError(chain) || result.fields.status !== 'success';
    return {
      complete: truthful,
      ok: truthful && result.fields.status === 'success',
      status: result.fields.status,
      actionId: actions[0],
      surfaceId: result.fields.surface,
      conversationId: plan.fields.conversation,
      turnId: plan.fields.turn,
      taskId: plan.fields.task,
      planId: result.fields.plan,
      runId: result.fields.run,
      resultIndex: result.index,
      failures: truthful ? [] : ['external_or_synthetic_success']
    };
  }
  return { complete: false, ok: false, status: '', actionId: '', surfaceId: '', failures: ['missing_action_chain'] };
}

export function mailThreadReadEvidence(logText, options = {}) {
  const all = records(logText);
  const action = multiAgentActionEvidence(logText, {
    expectedActionId: options.expectedActionId,
    expectedSourceToolId: options.expectedSourceToolId,
    currentSurfaceId: options.currentSurfaceId,
    expectedConversationId: options.expectedConversationId,
    expectedTurnId: options.expectedTurnId,
    expectedVirtual: false
  });
  const failed = (reason) => ({
    complete: false,
    ok: false,
    status: '',
    dataToolId: '',
    provider: '',
    bodyVisible: false,
    failures: [reason]
  });
  if (!action.complete || !action.ok) return failed('missing_action_chain');
  const run = all.find((item) => item.marker === 'MultiAgentActionRun' &&
    item.fields.conversation === action.conversationId && item.fields.turn === action.turnId &&
    item.fields.task === action.taskId && item.fields.run === action.runId);
  if (run === undefined) return failed('missing_action_run');

  const expectedProvider = options.expectedActionId === 'gmail.thread.read' ? 'gmail' : 'qq';
  if (run.fields.provider !== expectedProvider || !run.fields.identity ||
    run.fields.identity === 'invalid') return failed('missing_action_identity');

  const dataTasks = all.filter((item) => item.index > run.index &&
    item.marker === 'MultiAgentDataTask' && item.fields.conversation === action.conversationId &&
    item.index < action.resultIndex && item.fields.tool === options.expectedActionId &&
    item.fields.provider === run.fields.provider && item.fields.identity === run.fields.identity);
  if (dataTasks.length !== 1) return failed('missing_or_duplicate_data_task');
  const dataTask = dataTasks[0];
  const uiTasks = all.filter((item) => item.index > run.index &&
    item.marker === 'MultiAgentUiTask' && item.fields.conversation === action.conversationId &&
    item.fields.turn === dataTask.fields.turn &&
    list(item.fields.dataTasks).length === 1 && list(item.fields.dataTasks)[0] === dataTask.fields.task);
  if (uiTasks.length !== 1) return failed('missing_or_duplicate_ui_task');
  const uiTask = uiTasks[0];
  const dataTerminals = all.filter((item) => item.index > dataTask.index &&
    item.fields.conversation === action.conversationId && item.fields.turn === dataTask.fields.turn &&
    item.fields.task === dataTask.fields.task &&
    (item.marker === 'MultiAgentDataResult' || item.marker === 'MultiAgentTaskError'));
  if (dataTerminals.length !== 1) return failed('missing_or_duplicate_data_terminal');
  const dataTerminal = dataTerminals[0];
  if (dataTerminal.marker === 'MultiAgentDataResult' &&
    (dataTerminal.fields.tool !== dataTask.fields.tool ||
      dataTerminal.fields.provider !== run.fields.provider ||
      dataTerminal.fields.identity !== run.fields.identity)) return failed('mismatched_data_terminal');
  const uiTerminals = all.filter((item) => item.index > uiTask.index &&
    item.fields.conversation === action.conversationId && item.fields.turn === uiTask.fields.turn &&
    item.fields.task === uiTask.fields.task &&
    ((item.marker === 'MultiAgentUiResult' && ['result', 'error'].includes(item.fields.state)) ||
      item.marker === 'MultiAgentTaskError'));
  if (uiTerminals.length !== 1) return failed('missing_or_duplicate_ui_terminal');
  const terminal = uiTerminals[0];
  const inPlace = all.filter((item) => item.index > dataTerminal.index &&
    item.marker === 'MailDetailInPlace' && item.index < terminal.index &&
    item.fields.provider === run.fields.provider &&
    item.fields.identity === run.fields.identity);
  if (inPlace.length !== 1) return failed('missing_or_duplicate_in_place_terminal');
  const provider = inPlace[0].fields.provider || '';
  const status = inPlace[0].fields.status || '';
  const bodyVisible = /^[1-9]\d*$/.test(inPlace[0].fields.bodyChars || '');
  const dataStatus = dataTerminal.marker === 'MultiAgentDataResult' ?
    dataTerminal.fields.status : 'error';
  const uiSucceeded = terminal.marker === 'MultiAgentUiResult' && terminal.fields.state === 'result';
  const ok = action.ok && dataStatus === 'success' && uiSucceeded &&
    status === 'success' && provider === expectedProvider && bodyVisible;
  const errorComplete = dataStatus === 'error' && !uiSucceeded && status === 'error' &&
    provider === expectedProvider && !bodyVisible;
  return {
    complete: ok || errorComplete,
    ok,
    status,
    dataToolId: dataTask.fields.tool,
    provider,
    bodyVisible,
    conversationId: action.conversationId,
    actionTurnId: action.turnId,
    followUpTurnId: dataTask.fields.turn,
    dataTaskId: dataTask.fields.task,
    uiTaskId: uiTask.fields.task,
    failures: ok || errorComplete ? [] : ['invalid_mail_read_terminal']
  };
}

export function visibleMailBodyText(value) {
  if (typeof value !== 'string') return false;
  const text = value.replace(/\s+/g, ' ').trim();
  if (text.length === 0 || /正在加载邮件正文|邮件正文加载失败|正文读取失败|PROVIDER_|AUTH_REQUIRED/.test(text)) {
    return false;
  }
  const content = text
    .replace(/发件人|收件人|抄送|主题|回复|收起|展开|详情\s*\+|生成回复|保存草稿|发送/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return content.length >= 8;
}
