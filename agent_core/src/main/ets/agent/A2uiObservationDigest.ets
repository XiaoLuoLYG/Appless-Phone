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
}

const STOP_STATUSES: string[] = ['blocked', 'confirm_required', 'needs_input', 'needs_user', 'auth_required'];
const FAILURE_STATUSES: string[] = ['error', 'blocked', 'auth_required'];
const USEFUL_ROW_LABELS: string[] = [
  'Watch URL',
  'Video ID',
  'To',
  'Subject',
  'Draft ID',
  'Message ID',
  'Thread ID',
  'Error',
  'Credential',
  'Query'
];

function emptyDigest(observation: string): A2uiObservationDigest {
  return {
    isA2ui: false,
    text: observation,
    shouldStop: false,
    failureKey: ''
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

function statusMatches(status: string, statuses: string[]): boolean {
  return statuses.indexOf(status.trim()) >= 0;
}

function shouldStopForStatus(status: string): boolean {
  return statusMatches(status, STOP_STATUSES);
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
    const value = rows[index].value.trim();
    if (label.length > 0 && value.length > 0 && usefulRow(label)) {
      lines.push(label + ': ' + value);
    }
  }
}

function appendConnectCredential(lines: string[], connect: A2uiDynamicToolConnectData): void {
  const credential = firstText([connect.credentialName, connect.credentialRef]);
  if (credential.length > 0) {
    lines.push('Credential: ' + credential);
  }
}

function terminalComponentStatus(surface: A2uiSurfaceState): boolean {
  for (let index = 0; index < surface.components.length; index++) {
    const component: A2uiComponent = surface.components[index];
    if (component.status !== undefined && shouldStopForStatus(component.status)) {
      return true;
    }
  }
  return false;
}

function terminalResultStatus(results: A2uiGenericToolResultData[]): boolean {
  for (let index = 0; index < results.length; index++) {
    if (shouldStopForStatus(results[index].status)) {
      return true;
    }
  }
  return false;
}

function failureKeyFor(toolId: string, surface: A2uiSurfaceState, connect: A2uiDynamicToolConnectData, results: A2uiGenericToolResultData[]): string {
  if (failureForStatus(surface.status)) {
    return firstText([toolId, surface.surfaceId, 'a2ui']) + ':' + surface.status;
  }
  if (failureForStatus(connect.status)) {
    return firstText([toolId, connect.toolId, surface.surfaceId, 'a2ui']) + ':' + connect.status;
  }
  for (let index = 0; index < results.length; index++) {
    if (failureForStatus(results[index].status)) {
      return firstText([toolId, results[index].toolName, surface.surfaceId, 'a2ui']) + ':' + results[index].status;
    }
  }
  return '';
}

function appendResults(lines: string[], results: A2uiGenericToolResultData[]): void {
  for (let index = 0; index < results.length; index++) {
    const result = results[index];
    lines.push('result ' + (index + 1).toString() + ': ' + result.title + ' | status=' + result.status + ' | source=' + result.sourceTag + ' | summary=' + result.summary);
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
        shouldStop: false,
        failureKey: 'a2ui:error'
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
    'surface status: ' + surface.status,
    'result count: ' + results.length.toString()
  ];

  if (connect.status.length > 0) {
    lines.push('connect status: ' + connect.status);
    appendConnectCredential(lines, connect);
  }
  appendResults(lines, results);

  return {
    isA2ui: true,
    text: lines.join('\n'),
    shouldStop: shouldStopForStatus(surface.status) || shouldStopForStatus(connect.status) || terminalComponentStatus(surface) || terminalResultStatus(results),
    failureKey: failureKeyFor(toolId, surface, connect, results)
  };
}
