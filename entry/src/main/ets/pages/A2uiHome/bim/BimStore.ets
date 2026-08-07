import { preferences } from '@kit.ArkData';
import {
  A2uiAction,
  A2uiComponent,
  A2uiGenericToolResultData,
  A2uiSurfaceState,
  LeaderBimDashboardItem,
  genericToolResults,
  validLeaderBimDashboardItems
} from '@loop/agent-core';

export const BIM_STORE_NAME: string = 'aiphone_bim_store';
const RECORDS_KEY: string = 'records.v1';
const LAST_SWEEP_KEY: string = 'last_lifecycle_sweep_at.v1';
const DEMO_SEED_STATE_KEY: string = 'demo_seed_state.v1';
const MAX_RECORDS: number = 100;
const MAX_CONTEXT_CHARS: number = 16000;
const MAX_SURFACE_CHARS: number = 96000;
const MAX_DASHBOARD_SURFACES: number = 8;
const MAX_CONTEXT_ITEMS: number = 32;
const MAX_CONTEXT_ITEM_CHARS: number = 240;
const CONFIRMED_DASHBOARD_TOOL_IDS: string[] = [
  'calendar.event.create',
  'calendar.event.update',
  'calendar.event.delete',
  'gmail.message.send',
  'luckin.order.create',
  'ride.order.create',
  'ride.order.cancel',
  'web.monitor.create',
  'whatsapp.message.send'
];
const PERSISTENCE_VALIDATION_ERROR: string = '心上事本地存储验证失败';
const PERSISTENCE_WRITE_ERROR: string = '心上事本地存储写入失败';
const SENSITIVE_FIELD_NAMES: string[] = [
  'apikey', 'accesstoken', 'refreshtoken', 'authorization', 'cookie', 'password', 'secret', 'token',
  'credentialvalue', 'clientsecret'
];
const DEMO_RECORD_IDS: string[] = ['demo-bim-exam', 'demo-bim-wedding', 'demo-bim-travel'];

interface DemoSeedState {
  initialized: boolean;
  deletedIds: string[];
}

function emptyDemoSeedState(): DemoSeedState {
  return { initialized: false, deletedIds: [] };
}

function parseDemoSeedState(raw: string): DemoSeedState {
  if (raw.trim().length === 0) return emptyDemoSeedState();
  try {
    const value = JSON.parse(raw) as Record<string, Object | string | boolean | null | undefined>;
    if (value === null || value['initialized'] !== true && value['initialized'] !== false ||
      !Array.isArray(value['deletedIds'])) {
      return emptyDemoSeedState();
    }
    const deletedIds: string[] = [];
    const rawIds = value['deletedIds'] as Object[];
    for (let index = 0; index < rawIds.length; index++) {
      const id = rawIds[index];
      if (typeof id !== 'string' || DEMO_RECORD_IDS.indexOf(id) < 0 || deletedIds.indexOf(id) >= 0) {
        return emptyDemoSeedState();
      }
      deletedIds.push(id);
    }
    return { initialized: value['initialized'] as boolean, deletedIds };
  } catch (_error) {
    return emptyDemoSeedState();
  }
}

function serializeDemoSeedState(state: DemoSeedState): string {
  return JSON.stringify({ initialized: state.initialized, deletedIds: state.deletedIds.slice() });
}

export type BimLifecycleState = 'active' | 'quiet' | 'tucked' | 'ended';

export interface BimRetrievalIndex {
  summary: string;
  entities: string[];
  timeAnchors: string[];
  locations: string[];
  commitments: string[];
  keywords: string[];
}

export interface BimContextSnapshot {
  summary: string;
  facts: string[];
  constraints: string[];
  decisions: string[];
  dashboardItems?: LeaderBimDashboardItem[];
}

export interface BimLifecycleUpdate {
  id: string;
  lifecycle: 'active' | 'quiet' | 'tucked';
}

export interface BimRecord {
  id: string;
  title: string;
  lifecycle: BimLifecycleState;
  createdAt: string;
  updatedAt: string;
  lastInteractionAt: string;
  lastLifecycleCheckAt: string;
  endedAt?: string;
  relatedBimIds: string[];
  contextJson: string;
  retrievalIndex: BimRetrievalIndex;
  surfaceJson: string;
  dashboardSurfaceJsons?: string[];
}

function text(value: string | number | boolean | preferences.ValueType | undefined): string {
  return typeof value === 'string' ? value : '';
}

function validTimestamp(value: string): boolean {
  if (typeof value !== 'string') return false;
  const parts = /^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(\.[0-9]{1,3})?(Z|[+-]([0-9]{2}):([0-9]{2}))$/.exec(value);
  if (parts === null) return false;
  const year = Number(parts[1]);
  const month = Number(parts[2]);
  const day = Number(parts[3]);
  const hour = Number(parts[4]);
  const minute = Number(parts[5]);
  const second = Number(parts[6]);
  const offsetHour = parts[8] === 'Z' ? 0 : Number(parts[9]);
  const offsetMinute = parts[8] === 'Z' ? 0 : Number(parts[10]);
  const leapYear = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const days = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return month >= 1 && month <= 12 && day >= 1 && day <= days[month - 1] &&
    hour <= 23 && minute <= 59 && second <= 59 && offsetHour <= 23 && offsetMinute <= 59 &&
    !isNaN(new Date(value).getTime());
}

type InspectableJson = Object | Object[] | string | number | boolean | null;

function isSensitiveKey(key: string): boolean {
  const normalized = key.toLowerCase().replace(/[_-]/g, '');
  for (let index = 0; index < SENSITIVE_FIELD_NAMES.length; index++) {
    if (normalized.indexOf(SENSITIVE_FIELD_NAMES[index]) >= 0) return true;
  }
  return false;
}

function containsSensitiveKey(value: InspectableJson): boolean {
  if (value === null || typeof value !== 'object') return false;
  if (Array.isArray(value)) {
    for (let index = 0; index < value.length; index++) {
      if (containsSensitiveKey(value[index])) return true;
    }
    return false;
  }
  const fields = value as Record<string, InspectableJson>;
  const keys = Object.keys(fields);
  for (let index = 0; index < keys.length; index++) {
    if (isSensitiveKey(keys[index]) || containsSensitiveKey(fields[keys[index]])) return true;
  }
  return false;
}

function dataModelContainsSensitiveKey(dataModelJson: string): boolean {
  try {
    return containsSensitiveKey(JSON.parse(dataModelJson) as InspectableJson);
  } catch (_error) {
    return false;
  }
}

function surfaceContainsSensitiveKey(surfaceJson: string): boolean {
  try {
    const surface = JSON.parse(surfaceJson) as A2uiSurfaceState;
    if (dataModelContainsSensitiveKey(surface.dataModelJson)) return true;
    for (let index = 0; index < surface.components.length; index++) {
      const actions = surface.components[index].actions;
      if (actions === undefined) continue;
      for (let actionIndex = 0; actionIndex < actions.length; actionIndex++) {
        const args = actions[actionIndex].args;
        if (args !== undefined && containsSensitiveKey(args)) return true;
      }
    }
    return false;
  } catch (_error) {
    return false;
  }
}

function validLifecycle(value: string): boolean {
  return value === 'active' || value === 'quiet' || value === 'tucked' || value === 'ended';
}

function validActiveLifecycle(value: string): boolean {
  return value === 'active' || value === 'quiet' || value === 'tucked';
}

function validString(value: string, maximum: number, requireText: boolean = false): boolean {
  return typeof value === 'string' && value.length <= maximum && (!requireText || value.trim().length > 0);
}

function validStringList(values: string[], maximumItems: number, maximumChars: number): boolean {
  if (!Array.isArray(values) || values.length > maximumItems) return false;
  const seen: string[] = [];
  for (let index = 0; index < values.length; index++) {
    const value = values[index];
    if (typeof value !== 'string' || value.trim().length === 0 || value.trim().length > maximumChars ||
      seen.indexOf(value.trim()) >= 0) return false;
    seen.push(value.trim());
  }
  return true;
}

function validContext(context: BimContextSnapshot): boolean {
  const keys = Object.keys(context).sort().join(',');
  return context !== null && context !== undefined &&
    (keys === 'constraints,decisions,facts,summary' ||
      keys === 'constraints,dashboardItems,decisions,facts,summary') &&
    validString(context.summary, 2000, true) &&
    validStringList(context.facts, MAX_CONTEXT_ITEMS, MAX_CONTEXT_ITEM_CHARS) &&
    validStringList(context.constraints, MAX_CONTEXT_ITEMS, MAX_CONTEXT_ITEM_CHARS) &&
    validStringList(context.decisions, MAX_CONTEXT_ITEMS, MAX_CONTEXT_ITEM_CHARS) &&
    validLeaderBimDashboardItems(context.dashboardItems);
}

function validIndex(index: BimRetrievalIndex): boolean {
  return index !== null && index !== undefined &&
    Object.keys(index).sort().join(',') === 'commitments,entities,keywords,locations,summary,timeAnchors' &&
    validString(index.summary, 500, true) &&
    validStringList(index.entities, 16, 80) &&
    validStringList(index.timeAnchors, 16, 80) &&
    validStringList(index.locations, 16, 80) &&
    validStringList(index.commitments, 16, 80) &&
    validStringList(index.keywords, 16, 40);
}

function onlyKeys(value: Object, allowed: string[]): boolean {
  const keys = Object.keys(value);
  for (let index = 0; index < keys.length; index++) {
    if (allowed.indexOf(keys[index]) < 0) return false;
  }
  return true;
}

function validAction(action: A2uiAction): boolean {
  return action !== null && action !== undefined &&
    onlyKeys(action, ['id', 'label', 'prompt', 'variant', 'kind', 'args', 'sourceSectionId']) &&
    validString(action.id, MAX_SURFACE_CHARS, true) &&
    validString(action.label, MAX_SURFACE_CHARS) &&
    validString(action.prompt, MAX_SURFACE_CHARS) &&
    validString(action.variant, MAX_SURFACE_CHARS) &&
    validString(action.kind, MAX_SURFACE_CHARS, true) &&
    (action.args === undefined || (action.args !== null && typeof action.args === 'object')) &&
    (action.sourceSectionId === undefined || validString(action.sourceSectionId, MAX_SURFACE_CHARS));
}

function validComponent(component: A2uiComponent): boolean {
  if (component === null || component === undefined ||
    !onlyKeys(component, ['id', 'component', 'child', 'children', 'title', 'text', 'body', 'status',
      'tone', 'variant', 'path', 'dataPath', 'actions']) ||
    !validString(component.id, MAX_SURFACE_CHARS, true) ||
    !validString(component.component, MAX_SURFACE_CHARS, true) ||
    (component.child !== undefined && !validString(component.child, MAX_SURFACE_CHARS)) ||
    (component.children !== undefined && !validStringList(component.children, MAX_RECORDS, MAX_SURFACE_CHARS)) ||
    (component.title !== undefined && !validString(component.title, MAX_SURFACE_CHARS)) ||
    (component.text !== undefined && !validString(component.text, MAX_SURFACE_CHARS)) ||
    (component.body !== undefined && !validString(component.body, MAX_SURFACE_CHARS)) ||
    (component.status !== undefined && !validString(component.status, MAX_SURFACE_CHARS)) ||
    (component.tone !== undefined && !validString(component.tone, MAX_SURFACE_CHARS)) ||
    (component.variant !== undefined && !validString(component.variant, MAX_SURFACE_CHARS)) ||
    (component.path !== undefined && !validString(component.path, MAX_SURFACE_CHARS)) ||
    (component.dataPath !== undefined && !validString(component.dataPath, MAX_SURFACE_CHARS)) ||
    (component.actions !== undefined && !Array.isArray(component.actions))) return false;
  if (component.actions !== undefined) {
    for (let index = 0; index < component.actions.length; index++) {
      if (!validAction(component.actions[index])) return false;
    }
  }
  return true;
}

export function isValidBimSurfaceJson(surfaceJson: string): boolean {
  if (typeof surfaceJson !== 'string' || surfaceJson.length === 0 || surfaceJson.length > MAX_SURFACE_CHARS) return false;
  try {
    const surface = JSON.parse(surfaceJson) as A2uiSurfaceState;
    if (surface === null ||
      !onlyKeys(surface, ['surfaceId', 'rootId', 'title', 'intent', 'status', 'components', 'dataModelJson',
        'error', 'sequence', 'runtimeOwner', 'runtimeGeneration']) ||
      !validString(surface.surfaceId, MAX_SURFACE_CHARS, true) ||
      !validString(surface.rootId, MAX_SURFACE_CHARS, true) ||
      !validString(surface.title, MAX_SURFACE_CHARS) ||
      !validString(surface.intent, MAX_SURFACE_CHARS) ||
      !validString(surface.status, MAX_SURFACE_CHARS) ||
      !Array.isArray(surface.components) ||
      !validString(surface.dataModelJson, MAX_SURFACE_CHARS) ||
      !validString(surface.error, MAX_SURFACE_CHARS) ||
      typeof surface.sequence !== 'number' || !isFinite(surface.sequence)) return false;
    for (let index = 0; index < surface.components.length; index++) {
      if (!validComponent(surface.components[index])) return false;
    }
    return (surface.runtimeOwner === undefined || surface.runtimeOwner === 'multi_agent' || surface.runtimeOwner === 'legacy') &&
      (surface.runtimeGeneration === undefined ||
        (typeof surface.runtimeGeneration === 'number' && isFinite(surface.runtimeGeneration)));
  } catch (_error) {
    return false;
  }
}

function validContextJson(value: string): boolean {
  if (typeof value !== 'string' || value.length === 0 || value.length > MAX_CONTEXT_CHARS) return false;
  try {
    return validContext(JSON.parse(value) as BimContextSnapshot);
  } catch (_error) {
    return false;
  }
}

function validRelatedIds(value: string[], id: string, ids: string[]): boolean {
  if (!validStringList(value, MAX_RECORDS - 1, 256)) return false;
  for (let index = 0; index < value.length; index++) {
    if (value[index].trim() === id || ids.indexOf(value[index].trim()) < 0) return false;
  }
  return true;
}

function validRecordFields(record: BimRecord): boolean {
  return record !== null && record !== undefined &&
    onlyKeys(record, ['id', 'title', 'lifecycle', 'createdAt', 'updatedAt', 'lastInteractionAt',
      'lastLifecycleCheckAt', 'endedAt', 'relatedBimIds', 'contextJson', 'retrievalIndex', 'surfaceJson',
      'dashboardSurfaceJsons']) &&
    validString(record.id, 256, true) &&
    validString(record.title, 500, true) &&
    validLifecycle(record.lifecycle) &&
    validTimestamp(record.createdAt) &&
    validTimestamp(record.updatedAt) &&
    validTimestamp(record.lastInteractionAt) &&
    validTimestamp(record.lastLifecycleCheckAt) &&
    validContextJson(record.contextJson) &&
    validIndex(record.retrievalIndex) &&
    isValidBimSurfaceJson(record.surfaceJson) &&
    validDashboardSurfaceJsons(record.dashboardSurfaceJsons) &&
    Array.isArray(record.relatedBimIds) &&
    !surfaceContainsSensitiveKey(record.surfaceJson) &&
    ((record.lifecycle === 'ended' && record.endedAt !== undefined && validTimestamp(record.endedAt)) ||
      (record.lifecycle !== 'ended' && record.endedAt === undefined));
}

function validDashboardSurfaceJsons(surfaceJsons: string[] | undefined): boolean {
  if (surfaceJsons === undefined) return true;
  if (!Array.isArray(surfaceJsons) || surfaceJsons.length > MAX_DASHBOARD_SURFACES) return false;
  for (let index = 0; index < surfaceJsons.length; index++) {
    if (!isValidBimSurfaceJson(surfaceJsons[index]) ||
      surfaceContainsSensitiveKey(surfaceJsons[index])) return false;
  }
  return true;
}

function validRecords(records: BimRecord[]): boolean {
  if (!Array.isArray(records) || records.length > MAX_RECORDS) return false;
  const ids: string[] = [];
  for (let index = 0; index < records.length; index++) {
    const record = records[index];
    if (!validRecordFields(record) || ids.indexOf(record.id.trim()) >= 0) return false;
    ids.push(record.id.trim());
  }
  for (let index = 0; index < records.length; index++) {
    if (!validRelatedIds(records[index].relatedBimIds, records[index].id.trim(), ids)) return false;
  }
  return true;
}

function copyList(values: string[]): string[] {
  return values.map((value: string): string => value.trim());
}

function copyContext(context: BimContextSnapshot): BimContextSnapshot {
  const copy: BimContextSnapshot = {
    summary: context.summary,
    facts: copyList(context.facts),
    constraints: copyList(context.constraints),
    decisions: copyList(context.decisions)
  };
  if (context.dashboardItems !== undefined) {
    copy.dashboardItems = context.dashboardItems.map(
      (item: LeaderBimDashboardItem): LeaderBimDashboardItem => ({
        kind: item.kind,
        title: item.title,
        value: item.value,
        detail: item.detail,
        status: item.status
      })
    );
  }
  return copy;
}

function copyIndex(index: BimRetrievalIndex): BimRetrievalIndex {
  return {
    summary: index.summary,
    entities: copyList(index.entities),
    timeAnchors: copyList(index.timeAnchors),
    locations: copyList(index.locations),
    commitments: copyList(index.commitments),
    keywords: copyList(index.keywords)
  };
}

function copyRecord(record: BimRecord): BimRecord {
  const dashboard = record.dashboardSurfaceJsons === undefined ?
    [record.surfaceJson] : record.dashboardSurfaceJsons;
  return {
    id: record.id.trim(),
    title: record.title.trim(),
    lifecycle: record.lifecycle,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
    lastInteractionAt: record.lastInteractionAt,
    lastLifecycleCheckAt: record.lastLifecycleCheckAt,
    endedAt: record.endedAt,
    relatedBimIds: copyList(record.relatedBimIds),
    contextJson: JSON.stringify(copyContext(JSON.parse(record.contextJson) as BimContextSnapshot)),
    retrievalIndex: copyIndex(record.retrievalIndex),
    surfaceJson: record.surfaceJson,
    dashboardSurfaceJsons: confirmedDashboardSurfaces(dashboard)
  };
}

function isConfirmedDashboardSurface(surfaceJson: string): boolean {
  if (!isValidBimSurfaceJson(surfaceJson)) return false;
  try {
    const surface = JSON.parse(surfaceJson) as A2uiSurfaceState;
    if (surface.status !== 'ready' || surface.error.trim().length > 0) return false;
    const results = genericToolResults(surface);
    for (let index = 0; index < results.length; index++) {
      const result: A2uiGenericToolResultData = results[index];
      if (result.status === 'success' &&
        CONFIRMED_DASHBOARD_TOOL_IDS.indexOf(result.toolName) >= 0) return true;
    }
    return false;
  } catch (_error) {
    return false;
  }
}

function confirmedDashboardSurfaces(surfaceJsons: string[]): string[] {
  return surfaceJsons.filter((surfaceJson: string): boolean =>
    isConfirmedDashboardSurface(surfaceJson)
  );
}

function surfaceSectionKey(surfaceJson: string): string {
  try {
    const surface = JSON.parse(surfaceJson) as A2uiSurfaceState;
    const model = JSON.parse(surface.dataModelJson) as
      Record<string, Object | string | number | boolean | null | undefined>;
    const rawSummary = model['summary'];
    let toolName = '';
    if (rawSummary !== null && rawSummary !== undefined &&
      typeof rawSummary === 'object' && !Array.isArray(rawSummary)) {
      const summary = rawSummary as
        Record<string, Object | string | number | boolean | null | undefined>;
      toolName = typeof summary['toolName'] === 'string' ? summary['toolName'] as string : '';
    }
    const value = toolName.length > 0 ? toolName : surface.intent;
    const separator = value.indexOf('.');
    return separator > 0 ? value.substring(0, separator) : value;
  } catch (_error) {
    return '';
  }
}

export function bimDashboardSurfaceJsons(record: BimRecord, liveSurfaceJson: string = ''): string[] {
  const dashboard = confirmedDashboardSurfaces(
    record.dashboardSurfaceJsons === undefined ? [record.surfaceJson] : record.dashboardSurfaceJsons
  );
  if (!isConfirmedDashboardSurface(liveSurfaceJson)) return dashboard;
  const sectionKey = surfaceSectionKey(liveSurfaceJson);
  for (let index = 0; index < dashboard.length; index++) {
    if (surfaceSectionKey(dashboard[index]) === sectionKey) {
      dashboard[index] = liveSurfaceJson;
      return dashboard;
    }
  }
  dashboard.push(liveSurfaceJson);
  if (dashboard.length > MAX_DASHBOARD_SURFACES) dashboard.splice(0, 1);
  return dashboard;
}

function updatedDashboardSurfaceJsons(record: BimRecord, surfaceJson: string): string[] {
  // ponytail: retain eight current sections; add user-driven pinning only when real dashboards exceed this.
  return bimDashboardSurfaceJsons(record, surfaceJson);
}

export function parseBimRecords(raw: string): BimRecord[] {
  try {
    const records = JSON.parse(raw) as BimRecord[];
    if (!validRecords(records)) return [];
    return records.map((record: BimRecord): BimRecord => copyRecord(record));
  } catch (_error) {
    return [];
  }
}

export function serializeBimRecords(records: BimRecord[]): string {
  if (!validRecords(records)) return '[]';
  return JSON.stringify(records.map((record: BimRecord): BimRecord => copyRecord(record)));
}

export function createBimRecord(
  id: string,
  title: string,
  context: BimContextSnapshot,
  retrievalIndex: BimRetrievalIndex,
  surfaceJson: string,
  nowIso: string
): BimRecord {
  return {
    id: id,
    title: title,
    lifecycle: 'active',
    createdAt: nowIso,
    updatedAt: nowIso,
    lastInteractionAt: nowIso,
    lastLifecycleCheckAt: nowIso,
    relatedBimIds: [],
    contextJson: JSON.stringify(context),
    retrievalIndex: copyIndex(retrievalIndex),
    surfaceJson: surfaceJson,
    dashboardSurfaceJsons: isConfirmedDashboardSurface(surfaceJson) ? [surfaceJson] : []
  };
}

function demoSurfaceJson(surfaceId: string): string {
  const surface: A2uiSurfaceState = {
    surfaceId,
    rootId: 'root',
    title: '演示事项状态',
    intent: 'bim',
    status: 'ready',
    components: [{ id: 'root', component: 'SurfaceRoot' }],
    dataModelJson: '{}',
    error: '',
    sequence: 1
  };
  return JSON.stringify(surface);
}

function demoRecord(
  id: string,
  title: string,
  context: BimContextSnapshot,
  index: BimRetrievalIndex,
  nowIso: string
): BimRecord {
  return createBimRecord(id, title, context, index, demoSurfaceJson(id + '-surface'), nowIso);
}

function demoBimRecords(nowIso: string): BimRecord[] {
  return [
    demoRecord(
      'demo-bim-exam',
      '科目一',
      {
        summary: '科目一已通过，当前总进度 1/4，后续继续跟进。',
        facts: ['科目一已通过'],
        constraints: ['总进度 1/4'],
        decisions: [],
        dashboardItems: [
          { kind: 'progress', title: '考试进度', value: '1/4', detail: '科目一已通过', status: '已通过' },
          { kind: 'task', title: '下一步', value: '继续准备后续科目', detail: '', status: '进行中' }
        ]
      },
      {
        summary: '科目一考试进度 1/4',
        entities: ['科目一'],
        timeAnchors: [],
        locations: [],
        commitments: ['继续准备后续科目'],
        keywords: ['科目一', '考试', '进度', '通过']
      },
      nowIso
    ),
    demoRecord(
      'demo-bim-wedding',
      '南京婚宴',
      {
        summary: '2027年2月14日在南京举办婚宴，持续跟进宾客确认。',
        facts: ['总人数 50 人', '每桌 10 人', '小王和李阿姨待确认'],
        constraints: ['婚宴日期：2027年2月14日', '地点：南京'],
        decisions: [],
        dashboardItems: [
          { kind: 'metric', title: '宾客总数', value: '50', detail: '位宾客', status: '进行中' },
          { kind: 'metric', title: '每桌人数', value: '10', detail: '人/桌', status: '已确定' },
          { kind: 'person', title: '小王', value: '待确认', detail: '宾客', status: '待回复' },
          { kind: 'person', title: '李阿姨', value: '待确认', detail: '宾客', status: '待回复' },
          { kind: 'task', title: '下一步', value: '持续确认宾客', detail: '', status: '进行中' }
        ]
      },
      {
        summary: '南京婚宴宾客安排',
        entities: ['南京婚宴', '小王', '李阿姨'],
        timeAnchors: ['2027年2月14日'],
        locations: ['南京'],
        commitments: ['持续确认宾客'],
        keywords: ['婚宴', '宾客', '人数', '每桌', '南京']
      },
      nowIso
    ),
    demoRecord(
      'demo-bim-travel',
      '旅行筹备',
      {
        summary: '2027年5月和三位同事分阶段筹备东京旅行，每周跟进准备状态。',
        facts: ['同行 4 人', '与三位同事同行'],
        constraints: ['出发时间：2027年5月', '住宿与交通尚未确认'],
        decisions: [],
        dashboardItems: [
          { kind: 'timeline', title: '出发时间', value: '2027年5月', detail: '东京旅行计划', status: '待准备' },
          { kind: 'metric', title: '同行人数', value: '4', detail: '人', status: '已确定' },
          { kind: 'task', title: '下一步', value: '确认行程与住宿方案', detail: '仅为计划，不代表已预订', status: '待准备' }
        ]
      },
      {
        summary: '东京旅行筹备计划',
        entities: ['东京旅行', '同事'],
        timeAnchors: ['2027年5月'],
        locations: ['东京'],
        commitments: ['每周跟进准备状态'],
        keywords: ['旅行', '东京', '同事', '规划', '准备']
      },
      nowIso
    )
  ];
}

export class BimStore {
  private store: preferences.Preferences;
  private recordsSnapshot: string | undefined = undefined;
  private sweepSnapshot: string | undefined = undefined;
  private demoSeedStateSnapshot: string | undefined = undefined;
  private lastPersistenceFailure: string = '';

  constructor(store: preferences.Preferences) {
    this.store = store;
  }

  private records(): BimRecord[] {
    return parseBimRecords(this.recordsRaw());
  }

  private recordsRaw(): string {
    return this.recordsSnapshot === undefined ? text(this.store.getSync(RECORDS_KEY, '')) : this.recordsSnapshot;
  }

  private sweepRaw(): string {
    return this.sweepSnapshot === undefined ? text(this.store.getSync(LAST_SWEEP_KEY, '')) : this.sweepSnapshot;
  }

  private demoSeedStateRaw(): string {
    return this.demoSeedStateSnapshot === undefined ?
      text(this.store.getSync(DEMO_SEED_STATE_KEY, '')) : this.demoSeedStateSnapshot;
  }

  private save(
    records: BimRecord[],
    priorRaw: string,
    sweepAt?: string,
    priorSweepRaw?: string,
    demoSeedStateRaw?: string,
    priorDemoSeedStateRaw?: string
  ): boolean {
    if (!validRecords(records) || (sweepAt !== undefined && !validTimestamp(sweepAt))) {
      this.lastPersistenceFailure = PERSISTENCE_VALIDATION_ERROR;
      return false;
    }
    const priorDemoState = priorDemoSeedStateRaw === undefined ? this.demoSeedStateRaw() : priorDemoSeedStateRaw;
    const nextDemoState = demoSeedStateRaw === undefined ? priorDemoState : demoSeedStateRaw;
    try {
      if (this.recordsSnapshot !== undefined) this.store.putSync(RECORDS_KEY, this.recordsSnapshot);
      if (this.sweepSnapshot !== undefined) this.store.putSync(LAST_SWEEP_KEY, this.sweepSnapshot);
      if (this.demoSeedStateSnapshot !== undefined) {
        this.store.putSync(DEMO_SEED_STATE_KEY, this.demoSeedStateSnapshot);
      }
      this.store.putSync(RECORDS_KEY, serializeBimRecords(records));
      if (sweepAt !== undefined) this.store.putSync(LAST_SWEEP_KEY, sweepAt);
      this.store.putSync(DEMO_SEED_STATE_KEY, nextDemoState);
      this.store.flushSync();
      this.recordsSnapshot = undefined;
      this.sweepSnapshot = undefined;
      this.demoSeedStateSnapshot = undefined;
      this.lastPersistenceFailure = '';
      return true;
    } catch (_error) {
      this.lastPersistenceFailure = PERSISTENCE_WRITE_ERROR;
      let restored = true;
      try {
        this.store.putSync(RECORDS_KEY, priorRaw);
        if (priorSweepRaw !== undefined) this.store.putSync(LAST_SWEEP_KEY, priorSweepRaw);
        this.store.putSync(DEMO_SEED_STATE_KEY, priorDemoState);
      } catch (_restoreError) {
        restored = false;
      }
      if (!restored) {
        this.recordsSnapshot = priorRaw;
        if (priorSweepRaw !== undefined) this.sweepSnapshot = priorSweepRaw;
        this.demoSeedStateSnapshot = priorDemoState;
      }
      return false;
    }
  }

  lastPersistenceError(): string {
    return this.lastPersistenceFailure;
  }

  seedDemoRecordsIfMissing(nowIso: string): boolean {
    if (!validTimestamp(nowIso)) {
      this.lastPersistenceFailure = PERSISTENCE_VALIDATION_ERROR;
      return false;
    }
    const priorRaw = this.recordsRaw();
    const priorDemoStateRaw = this.demoSeedStateRaw();
    const demoState = parseDemoSeedState(priorDemoStateRaw);
    if (demoState.initialized) return false;
    const records = this.records();
    const existingIds: string[] = records.map((record: BimRecord): string => record.id);
    const seeds = demoBimRecords(nowIso).filter((record: BimRecord): boolean =>
      existingIds.indexOf(record.id) < 0 && demoState.deletedIds.indexOf(record.id) < 0
    );
    if (records.length + seeds.length > MAX_RECORDS) {
      return false;
    }
    const nextDemoState: DemoSeedState = { initialized: true, deletedIds: demoState.deletedIds };
    return this.save(
      records.concat(seeds), priorRaw, undefined, undefined,
      serializeDemoSeedState(nextDemoState), priorDemoStateRaw
    );
  }

  create(record: BimRecord): boolean {
    if (!validRecordFields(record)) {
      this.lastPersistenceFailure = PERSISTENCE_VALIDATION_ERROR;
      return false;
    }
    const priorRaw = this.recordsRaw();
    const records = this.records();
    for (let index = 0; index < records.length; index++) {
      if (records[index].id === record.id.trim()) {
        this.lastPersistenceFailure = PERSISTENCE_VALIDATION_ERROR;
        return false;
      }
    }
    records.push(copyRecord(record));
    return this.save(records, priorRaw);
  }

  get(id: string): BimRecord | undefined {
    const records = this.records();
    for (let index = 0; index < records.length; index++) {
      if (records[index].id === id) return copyRecord(records[index]);
    }
    return undefined;
  }

  list(): BimRecord[] {
    return this.records().map((record: BimRecord): BimRecord => copyRecord(record));
  }

  replaceCurrentState(
    id: string,
    context: BimContextSnapshot,
    index: BimRetrievalIndex,
    surfaceJson: string,
    relatedBimIds: string[],
    nowIso: string
  ): boolean {
    if (!validTimestamp(nowIso) || !validContext(context) || !validIndex(index) ||
      !isValidBimSurfaceJson(surfaceJson) || !validStringList(relatedBimIds, MAX_RECORDS - 1, 256)) {
      this.lastPersistenceFailure = PERSISTENCE_VALIDATION_ERROR;
      return false;
    }
    const priorRaw = this.recordsRaw();
    const records = this.records();
    for (let position = 0; position < records.length; position++) {
      if (records[position].id !== id) continue;
      const next = copyRecord(records[position]);
      next.contextJson = JSON.stringify(context);
      const previousIndex = next.retrievalIndex;
      // ponytail: empty arrays mean no new routing signal; add explicit deletion markers if index removal is needed.
      next.retrievalIndex = {
        summary: index.summary,
        entities: copyList(index.entities.length > 0 ? index.entities : previousIndex.entities),
        timeAnchors: copyList(index.timeAnchors.length > 0 ? index.timeAnchors : previousIndex.timeAnchors),
        locations: copyList(index.locations.length > 0 ? index.locations : previousIndex.locations),
        commitments: copyList(index.commitments.length > 0 ? index.commitments : previousIndex.commitments),
        keywords: copyList(index.keywords.length > 0 ? index.keywords : previousIndex.keywords)
      };
      next.dashboardSurfaceJsons = updatedDashboardSurfaceJsons(next, surfaceJson);
      next.surfaceJson = surfaceJson;
      next.relatedBimIds = copyList(relatedBimIds);
      next.updatedAt = nowIso;
      next.lastInteractionAt = nowIso;
      if (next.lifecycle !== 'ended') {
        next.lifecycle = 'active';
        next.endedAt = undefined;
      }
      records[position] = next;
      return this.save(records, priorRaw);
    }
    return false;
  }

  markEnded(id: string, endedAt: string): boolean {
    if (!validTimestamp(endedAt)) return false;
    const priorRaw = this.recordsRaw();
    const records = this.records();
    for (let index = 0; index < records.length; index++) {
      if (records[index].id !== id) continue;
      const next = copyRecord(records[index]);
      next.lifecycle = 'ended';
      next.endedAt = endedAt;
      next.updatedAt = endedAt;
      records[index] = next;
      return this.save(records, priorRaw);
    }
    return false;
  }

  reactivate(id: string, nowIso: string): boolean {
    if (!validTimestamp(nowIso)) return false;
    const priorRaw = this.recordsRaw();
    const records = this.records();
    for (let index = 0; index < records.length; index++) {
      if (records[index].id !== id || records[index].lifecycle !== 'ended') continue;
      const next = copyRecord(records[index]);
      next.lifecycle = 'active';
      next.endedAt = undefined;
      next.updatedAt = nowIso;
      next.lastInteractionAt = nowIso;
      records[index] = next;
      return this.save(records, priorRaw);
    }
    return false;
  }

  deleteEnded(id: string): boolean {
    const priorRaw = this.recordsRaw();
    const priorDemoStateRaw = this.demoSeedStateRaw();
    const demoState = parseDemoSeedState(priorDemoStateRaw);
    const records = this.records();
    let removed = false;
    const nextRecords: BimRecord[] = [];
    for (let index = 0; index < records.length; index++) {
      if (records[index].id === id && records[index].lifecycle === 'ended') {
        removed = true;
        continue;
      }
      const next = copyRecord(records[index]);
      const related: string[] = [];
      for (let relatedIndex = 0; relatedIndex < next.relatedBimIds.length; relatedIndex++) {
        if (next.relatedBimIds[relatedIndex] !== id) {
          related.push(next.relatedBimIds[relatedIndex]);
        }
      }
      next.relatedBimIds = related;
      nextRecords.push(next);
    }
    if (!removed) return false;
    const deletedIds = demoState.deletedIds.slice();
    if (DEMO_RECORD_IDS.indexOf(id) >= 0 && deletedIds.indexOf(id) < 0) {
      deletedIds.push(id);
    }
    return this.save(
      nextRecords,
      priorRaw,
      undefined,
      undefined,
      serializeDemoSeedState({ initialized: demoState.initialized, deletedIds }),
      priorDemoStateRaw
    );
  }

  lastLifecycleSweepAt(): string {
    const value = this.sweepRaw();
    return validTimestamp(value) ? value : '';
  }

  applyLifecycleSweep(updates: BimLifecycleUpdate[], checkedAt: string): boolean {
    if (!validTimestamp(checkedAt) || !Array.isArray(updates)) return false;
    const priorRaw = this.recordsRaw();
    const priorSweepRaw = this.sweepRaw();
    const records = this.records();
    const seen: string[] = [];
    for (let index = 0; index < updates.length; index++) {
      const update = updates[index];
      if (update === null || typeof update.id !== 'string' || !validActiveLifecycle(update.lifecycle) ||
        seen.indexOf(update.id) >= 0) return false;
      seen.push(update.id);
      let found = false;
      for (let position = 0; position < records.length; position++) {
        if (records[position].id !== update.id || records[position].lifecycle === 'ended') continue;
        const next = copyRecord(records[position]);
        next.lifecycle = update.lifecycle;
        next.lastLifecycleCheckAt = checkedAt;
        next.updatedAt = checkedAt;
        records[position] = next;
        found = true;
        break;
      }
      if (!found) return false;
    }
    return this.save(records, priorRaw, checkedAt, priorSweepRaw);
  }
}
