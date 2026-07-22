const TURN_STATUSES = new Set(['success', 'partial', 'empty', 'error', 'canceled']);
const DATA_STATUSES = new Set(['success', 'partial', 'empty', 'error']);
const ACTION_STATUSES = new Set(['success', 'error', 'canceled']);

function records(logText) {
  return String(logText || '').split('\n').flatMap((line, index) => {
    const marker = /\[AIPhone\]\[([^\]]+)\]/.exec(line);
    if (marker === null) return [];
    const fields = {};
    for (const match of line.matchAll(/\b([A-Za-z][A-Za-z0-9]*)=([^\s]+)/g)) {
      fields[match[1]] = match[2];
    }
    return [{ marker: marker[1], fields, index, line }];
  });
}

function list(value) {
  return !value || value === 'none' ? [] : value.split(',').filter(Boolean);
}

function sameIds(actual, expected) {
  return actual.length === expected.length &&
    actual.every((value) => expected.includes(value));
}

function nonnegativeInteger(value) {
  return /^\d+$/.test(value || '') && Number(value) >= 0;
}

function targetRecords(all, options) {
  const inputs = all.filter((item) => item.marker === 'MultiAgentInput');
  const selected = [...inputs].reverse().find((item) =>
    (!options.conversationId || item.fields.conversation === options.conversationId) &&
    (!options.turnId || item.fields.turn === options.turnId));
  if (selected === undefined) return { selected: null, events: [], stale: false };
  const conversation = selected.fields.conversation || '';
  const turn = selected.fields.turn || '';
  const terminal = all.find((item) => item.index > selected.index &&
    item.marker === 'MultiAgentTurnResult' && item.fields.conversation === conversation &&
    item.fields.turn === turn && item.fields.task === selected.fields.task);
  const stale = inputs.some((item) => item.index > selected.index &&
    (terminal === undefined || item.index < terminal.index) &&
    item.fields.conversation === conversation && item.fields.turn !== turn);
  return {
    selected,
    stale,
    events: all.filter((item) => item.index >= selected.index &&
      item.fields.conversation === conversation && item.fields.turn === turn),
    window: all.filter((item) => item.index >= selected.index &&
      (terminal === undefined || item.index <= terminal.index))
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

export function multiAgentTurnEvidence(logText, options = {}) {
  const all = records(logText);
  const { selected, events, stale, window = [] } = targetRecords(all, options);
  const failures = [];
  if (selected === null || !selected.fields.conversation || !selected.fields.turn ||
    !selected.fields.task) failures.push('missing_input');
  if (stale) failures.push('stale_turn');

  const dataTasks = events.filter((item) => item.marker === 'MultiAgentDataTask');
  const taskIds = new Set();
  const rounds = [];
  for (const task of dataTasks) {
    const roundSuffix = /:round-(\d+)$/.exec(task.fields.round || '');
    const roundNumber = roundSuffix === null ? 0 : Number(roundSuffix[1]);
    if (!task.fields.task || taskIds.has(task.fields.task) || !task.fields.tool ||
      roundSuffix === null || roundNumber < 1 ||
      !(task.fields.round || '').startsWith(`${selected?.fields.turn}:round-`)) {
      failures.push('invalid_data_task');
    }
    taskIds.add(task.fields.task);
    rounds.push(roundNumber);
  }
  const uniqueRounds = [...new Set(rounds)].sort((left, right) => left - right);
  if (uniqueRounds.some((round, index) => round !== index + 1) ||
    uniqueRounds.length < Number(options.minimumDataRounds || 0)) {
    failures.push('invalid_data_rounds');
  }

  const virtualPlans = events.filter((item) => item.marker === 'MultiAgentActionPlan' &&
    item.fields.virtual === 'true' && list(item.fields.dataTasks).length === 0);
  const toolIds = [...new Set([
    ...dataTasks.map((item) => item.fields.tool),
    ...virtualPlans.flatMap((item) => list(item.fields.actions))
  ])].filter(Boolean);
  if (Object.hasOwn(options, 'expectedToolIds') &&
    !sameIds(toolIds, options.expectedToolIds || [])) failures.push('planned_tools_mismatch');

  const terminals = [];
  for (const task of dataTasks) {
    const matches = events.filter((item) =>
      item.fields.task === task.fields.task &&
      (item.marker === 'MultiAgentDataResult' || item.marker === 'MultiAgentTaskError'));
    if (matches.length !== 1) {
      failures.push('missing_or_duplicate_data_terminal');
      continue;
    }
    const terminal = matches[0];
    if (terminal.marker === 'MultiAgentTaskError') {
      terminals.push({ taskId: task.fields.task, toolId: task.fields.tool, status: 'error' });
      continue;
    }
    const status = terminal.fields.status || '';
    const errorPresent = terminal.fields.error === 'true';
    if (terminal.fields.tool !== task.fields.tool || !DATA_STATUSES.has(status) ||
      (status === 'error') !== errorPresent) failures.push('invalid_data_terminal');
    terminals.push({ taskId: task.fields.task, toolId: task.fields.tool, status });
  }

  const uiTasks = events.filter((item) => item.marker === 'MultiAgentUiTask');
  let uiFailed = false;
  for (const uiTask of uiTasks) {
    const dependencies = list(uiTask.fields.dataTasks);
    const results = events.filter((item) => item.marker === 'MultiAgentUiResult' &&
      item.fields.task === uiTask.fields.task);
    const terminalsForUi = results.filter((item) => ['result', 'error'].includes(item.fields.state));
    const taskErrors = events.filter((item) => item.marker === 'MultiAgentTaskError' &&
      item.fields.task === uiTask.fields.task);
    const surfaces = new Set(results.map((item) => item.fields.surface));
    if (!uiTask.fields.task || dependencies.length === 0 ||
      dependencies.some((taskId) => !taskIds.has(taskId)) ||
      terminalsForUi.length + taskErrors.length !== 1 ||
      results.some((item) => !['skeleton', 'result', 'error', 'action'].includes(item.fields.state)) ||
      (taskErrors.length === 0 && (surfaces.size !== 1 || !terminalsForUi[0].fields.surface ||
        terminalsForUi[0].fields.surface === 'none'))) failures.push('invalid_ui_terminal');
    if (taskErrors.length === 1 || terminalsForUi[0]?.fields.state === 'error') {
      uiFailed = true;
    }
  }
  const uiDependencies = new Set(uiTasks.flatMap((item) => list(item.fields.dataTasks)));
  if (dataTasks.length > 0 && (uiTasks.length === 0 ||
    [...taskIds].some((taskId) => !uiDependencies.has(taskId)))) failures.push('missing_ui_task');

  const turnResults = events.filter((item) => item.marker === 'MultiAgentTurnResult' &&
    selected !== null && item.fields.task === selected.fields.task);
  if (turnResults.length !== 1) failures.push('missing_or_duplicate_turn_result');
  const turn = turnResults[0];
  const status = turn?.fields.status || '';
  if (!TURN_STATUSES.has(status) || !nonnegativeInteger(turn?.fields.roundCount) ||
    !nonnegativeInteger(turn?.fields.messageChars) || Number(turn?.fields.messageChars) === 0) {
    failures.push('invalid_turn_result');
  }
  if (uniqueRounds.length > 0 && Number(turn?.fields.roundCount || 0) < uniqueRounds.at(-1)) {
    failures.push('invalid_turn_round_count');
  }

  const action = multiAgentActionEvidence(events.map((item) => item.line).join('\n'));
  const dataStatus = aggregateStatus(terminals);
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
    Number(turn?.fields.messageChars || 0) > 0;
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
      roundNumber: Number(/:round-(\d+)$/.exec(item.fields.round || '')?.[1] || 0)
    })),
    textResult,
    surfaceIds: events.filter((item) => item.marker === 'MultiAgentUiResult')
      .map((item) => item.fields.surface),
    failures
  };
}

export function multiAgentActionEvidence(logText, options = {}) {
  const all = records(logText);
  const runs = all.filter((item) => item.marker === 'MultiAgentActionRun' &&
    (!options.expectedActionId || item.fields.action === options.expectedActionId) &&
    (!options.surfaceId || item.fields.surface === options.surfaceId));
  for (let index = runs.length - 1; index >= 0; index--) {
    const run = runs[index];
    const planId = `direct:${run.fields.run || ''}`;
    const results = all.filter((item) => item.marker === 'MultiAgentActionResult' &&
      item.fields.conversation === run.fields.conversation &&
      item.fields.turn === run.fields.turn && item.fields.task === run.fields.task &&
      item.fields.surface === run.fields.surface && item.fields.plan === planId &&
      item.fields.run === run.fields.run);
    if (!run.fields.conversation || !run.fields.turn || !run.fields.task ||
      !run.fields.surface || run.fields.surface === 'none' || !run.fields.run ||
      !run.fields.action || !run.fields.source || results.length !== 1 ||
      !ACTION_STATUSES.has(results[0].fields.status)) continue;
    const status = results[0].fields.status;
    const actionWindow = all.filter((item) =>
      item.index >= run.index && item.index <= results[0].index);
    const truthful = !externalOrSyntheticError(actionWindow) || status !== 'success';
    return {
      complete: truthful,
      ok: truthful && status === 'success',
      status,
      actionId: run.fields.action,
      surfaceId: run.fields.surface,
      conversationId: run.fields.conversation,
      turnId: run.fields.turn,
      taskId: run.fields.task,
      planId,
      runId: run.fields.run
    };
  }
  const virtualPlans = all.filter((item) => item.marker === 'MultiAgentActionPlan' &&
    item.fields.virtual === 'true' && list(item.fields.dataTasks).length === 0 &&
    (!options.expectedActionId || list(item.fields.actions).includes(options.expectedActionId)));
  for (let index = virtualPlans.length - 1; index >= 0; index--) {
    const plan = virtualPlans[index];
    const actions = list(plan.fields.actions);
    const surfaceId = `virtual:${plan.fields.task || ''}`;
    const planId = `direct:${surfaceId}`;
    const results = all.filter((item) => item.marker === 'MultiAgentActionResult' &&
      item.fields.conversation === plan.fields.conversation &&
      item.fields.turn === plan.fields.turn && item.fields.task === plan.fields.task &&
      item.fields.surface === surfaceId && item.fields.plan === planId &&
      item.fields.run === surfaceId);
    if (!plan.fields.conversation || !plan.fields.turn || !plan.fields.task ||
      plan.fields.uiTask !== plan.fields.task || actions.length !== 1 ||
      (options.surfaceId && options.surfaceId !== surfaceId) || results.length !== 1 ||
      !ACTION_STATUSES.has(results[0].fields.status)) continue;
    const status = results[0].fields.status;
    const actionWindow = all.filter((item) =>
      item.index >= plan.index && item.index <= results[0].index);
    const truthful = !externalOrSyntheticError(actionWindow) || status !== 'success';
    return {
      complete: truthful,
      ok: truthful && status === 'success',
      status,
      actionId: actions[0],
      surfaceId,
      conversationId: plan.fields.conversation,
      turnId: plan.fields.turn,
      taskId: plan.fields.task,
      planId,
      runId: surfaceId
    };
  }
  return { complete: false, ok: false, status: '', actionId: '', surfaceId: '' };
}
