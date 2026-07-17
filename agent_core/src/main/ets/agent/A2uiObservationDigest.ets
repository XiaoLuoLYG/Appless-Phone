import {
  dynamicToolConnect,
  genericToolResults,
  summaryData
} from '../aiphone/runtime/A2uiData';
import { parseA2uiJsonl } from '../aiphone/runtime/A2uiParser';
import { A2uiSurfaceStore } from '../aiphone/runtime/A2uiSurfaceStore';
import {
  A2uiApplyResult,
  A2uiComponent,
  A2uiDynamicToolConnectData,
  A2uiEnvelope,
  A2uiGenericToolResultData,
  A2uiGenericToolResultRowData,
  A2uiSummaryData,
  A2uiSurfaceState
} from '../aiphone/runtime/A2uiTypes';

export interface A2uiObservationDigest {
  isA2ui: boolean;
  text: string;
  shouldStop: boolean;
  failureKey: string;
  finalText: string;
}

const FAILURE_STATUSES: string[] = ['error', 'blocked', 'auth_required', 'needs_auth', 'unsafe_action_blocked'];
const MAX_DETAILED_RESULTS: number = 5;
const MAX_TEXT_LENGTH: number = 180;
const USEFUL_ROW_LABELS: string[] = [
  'Watch URL',
  'Video ID',
  'To',
  'Subject',
  'Draft ID',
  'Message ID',
  'Thread ID',
  'Event ID',
  'Start',
  'End',
  'Error',
  'Credential',
  'Query'
];

function emptyDigest(observation: string): A2uiObservationDigest {
  return {
    isA2ui: false,
    text: observation,
    shouldStop: false,
    failureKey: '',
    finalText: ''
  };
}

function firstText(values: string[]): string {
  for (let index = 0; index < values.length; index++) {
    if (values[index].trim().length > 0) {
      return values[index].trim();
    }
  }
  return '';
}

function firstResultToolName(results: A2uiGenericToolResultData[]): string {
  for (let index = 0; index < results.length; index++) {
    if (results[index].toolName.trim().length > 0) {
      return results[index].toolName.trim();
    }
  }
  return '';
}

function compact(value: string, limit: number = MAX_TEXT_LENGTH): string {
  const normalized = value.split('\n').join(' ').split('\r').join(' ').trim();
  if (normalized.length <= limit) {
    return normalized;
  }
  return normalized.substring(0, limit);
}

function statusMatches(status: string, statuses: string[]): boolean {
  return statuses.indexOf(status.trim()) >= 0;
}

function failureForStatus(status: string): boolean {
  return statusMatches(status, FAILURE_STATUSES);
}

function usefulRow(label: string): boolean {
  return USEFUL_ROW_LABELS.indexOf(label.trim()) >= 0;
}

function appendUsefulRows(lines: string[], rows: A2uiGenericToolResultRowData[]): void {
  for (let index = 0; index < rows.length; index++) {
    const label = rows[index].label.trim();
    const value = compact(rows[index].value);
    if (label.length > 0 && value.length > 0 && usefulRow(label)) {
      lines.push(label + ': ' + value);
    }
  }
}

function appendConnectCredential(lines: string[], connect: A2uiDynamicToolConnectData): void {
  const credential = firstText([connect.credentialName, connect.credentialRef]);
  if (credential.length > 0) {
    lines.push('Credential: ' + compact(credential));
  }
}

function componentFailureKey(toolId: string, surface: A2uiSurfaceState): string {
  for (let index = 0; index < surface.components.length; index++) {
    const component: A2uiComponent = surface.components[index];
    if (component.status !== undefined && failureForStatus(component.status)) {
      return firstText([toolId, component.id, 'a2ui']) + ':' + component.status;
    }
  }
  return '';
}

function failureKeyFor(toolId: string, surface: A2uiSurfaceState, connect: A2uiDynamicToolConnectData, results: A2uiGenericToolResultData[]): string {
  if (failureForStatus(surface.status)) {
    return firstText([toolId, 'a2ui']) + ':' + surface.status;
  }
  if (failureForStatus(connect.status)) {
    return firstText([toolId, connect.toolId, 'dynamic_connect']) + ':' + connect.status;
  }
  const componentKey = componentFailureKey(toolId, surface);
  if (componentKey.length > 0) {
    return componentKey;
  }
  for (let index = 0; index < results.length; index++) {
    if (failureForStatus(results[index].status)) {
      return firstText([toolId, results[index].toolName, 'generic_result']) + ':' + results[index].status;
    }
  }
  return '';
}

function appendResults(lines: string[], results: A2uiGenericToolResultData[]): void {
  const count = results.length > MAX_DETAILED_RESULTS ? MAX_DETAILED_RESULTS : results.length;
  for (let index = 0; index < count; index++) {
    const result = results[index];
    lines.push('result ' + (index + 1).toString() + ': ' + compact(result.title) + ' | status=' + compact(result.status) + ' | source=' + compact(result.sourceTag) + ' | summary=' + compact(result.summary));
    appendUsefulRows(lines, result.rows);
  }
}

export function summarizeA2uiObservation(observation: string): A2uiObservationDigest {
  const parsed = parseA2uiJsonl(observation);
  if (parsed.error.length > 0 || parsed.envelopes.length === 0) {
    return emptyDigest(observation);
  }

  const store = new A2uiSurfaceStore();
  for (let index = 0; index < parsed.envelopes.length; index++) {
    const envelope: A2uiEnvelope = parsed.envelopes[index];
    const applied: A2uiApplyResult = store.apply(envelope);
    if (!applied.ok) {
      return {
        isA2ui: true,
        text: 'ObservationDigest\nerror: ' + applied.error,
        shouldStop: true,
        failureKey: 'a2ui:error',
        finalText: ''
      };
    }
  }

  const surface = store.getSurface();
  const results = genericToolResults(surface);
  const summary: A2uiSummaryData = summaryData(surface);
  const connect = dynamicToolConnect(surface);
  const toolId = firstText([summary.toolName, connect.toolId, firstResultToolName(results)]);
  const lines: string[] = [
    'ObservationDigest',
    'toolId: ' + toolId,
    'surface status: ' + compact(surface.status),
    'result count: ' + results.length.toString()
  ];

  if (connect.status.length > 0) {
    lines.push('connect status: ' + compact(connect.status));
    appendConnectCredential(lines, connect);
  }
  appendResults(lines, results);

  let finalText = '';
  if (toolId === 'calendar.events.search') {
    const eventSummaries: string[] = [];
    for (let index = 0; index < results.length; index++) {
      let eventId = '';
      let start = '';
      for (let rowIndex = 0; rowIndex < results[index].rows.length; rowIndex++) {
        const row = results[index].rows[rowIndex];
        if (row.label.trim() === 'Event ID') {
          eventId = compact(row.value);
        } else if (row.label.trim() === 'Start') {
          start = compact(row.value);
        }
      }
      if (eventId.length > 0) {
        eventSummaries.push(compact(results[index].title) + '；Event ID：' + eventId +
          (start.length > 0 ? '；开始：' + start : ''));
      }
    }
    finalText = eventSummaries.length > 0 ?
      'Google Calendar 查询完成。已找到：' + eventSummaries.join('。') + '。系统会在后续修改或删除时使用上面的真实 Event ID，用户无需输入 Event ID。' :
      'Google Calendar 查询完成，没有找到可修改或删除的日程。';
  }

  return {
    isA2ui: true,
    text: lines.join('\n'),
    shouldStop: true,
    failureKey: failureKeyFor(toolId, surface, connect, results),
    finalText: finalText
  };
}
