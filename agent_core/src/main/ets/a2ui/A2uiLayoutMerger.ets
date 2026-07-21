import { ActionOffer } from '../agent/action/ActionOfferTypes';
import { AIPHONE_COMPONENT_CATALOG_JSON } from '../aiphone/runtime/A2uiComponentCatalogConst';
import { A2uiAction, A2uiComponent, A2uiEnvelope } from '../aiphone/runtime/A2uiTypes';

type JsonValue = Object | string | number | boolean | null | undefined;
type JsonRecord = Record<string, JsonValue>;

const MAX_LAYOUT_COMPONENTS: number = 24;
const COMPONENT_KEYS: string[] = [
  'actions', 'body', 'child', 'children', 'component', 'dataPath', 'id',
  'path', 'status', 'text', 'title', 'tone', 'variant'
];

interface LayoutBaseline {
  componentLineIndex: number;
  componentEnvelope: A2uiEnvelope;
  rootId: string;
  dataPaths: string[];
}

function objectRecord(value: JsonValue): JsonRecord | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as JsonRecord;
}

function exactKeys(record: JsonRecord, allowed: string[]): boolean {
  const keys = Object.keys(record).sort();
  const expected = allowed.slice().sort();
  return keys.join(',') === expected.join(',');
}

function allowedKeys(record: JsonRecord, allowed: string[]): boolean {
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    if (allowed.indexOf(keys[index]) < 0) {
      return false;
    }
  }
  return true;
}

function parseRecord(line: string): JsonRecord | null {
  try {
    return objectRecord(JSON.parse(line) as Object);
  } catch (_error) {
    return null;
  }
}

function baselineOf(lines: string[], surfaceId: string): LayoutBaseline | null {
  let componentLineIndex: number = -1;
  let componentEnvelope: A2uiEnvelope | null = null;
  let rootId: string = '';
  const dataPaths: string[] = [];
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index].trim();
    if (line.length === 0) {
      continue;
    }
    const record = parseRecord(line);
    if (record === null) {
      return null;
    }
    const create = objectRecord(record['createSurface']);
    if (create !== null) {
      if (create['surfaceId'] !== surfaceId || typeof create['root'] !== 'string') {
        return null;
      }
      rootId = create['root'] as string;
    }
    const update = objectRecord(record['updateComponents']);
    if (update !== null) {
      if (componentLineIndex >= 0 || update['surfaceId'] !== surfaceId || !Array.isArray(update['components'])) {
        return null;
      }
      componentLineIndex = index;
      componentEnvelope = record as A2uiEnvelope;
    }
    const data = objectRecord(record['updateDataModel']);
    if (data !== null) {
      if (data['surfaceId'] !== surfaceId || typeof data['path'] !== 'string') {
        return null;
      }
      const path = data['path'] as string;
      if (path.length === 0 || dataPaths.indexOf(path) >= 0) {
        return null;
      }
      dataPaths.push(path);
    }
  }
  if (componentLineIndex < 0 || componentEnvelope === null || rootId.length === 0 || dataPaths.length === 0) {
    return null;
  }
  return {
    componentLineIndex: componentLineIndex,
    componentEnvelope: componentEnvelope,
    rootId: rootId,
    dataPaths: dataPaths
  };
}

function catalogNames(): Set<string> {
  const names: Set<string> = new Set<string>();
  try {
    const items = JSON.parse(AIPHONE_COMPONENT_CATALOG_JSON) as Object[];
    for (let index = 0; index < items.length; index++) {
      const record = objectRecord(items[index]);
      if (record !== null && typeof record['name'] === 'string') {
        names.add(record['name'] as string);
      }
    }
  } catch (_error) {
  }
  return names;
}

function validDataPath(path: string, baselinePaths: string[]): boolean {
  for (let index = 0; index < baselinePaths.length; index++) {
    if (path === baselinePaths[index] || path.startsWith(baselinePaths[index] + '/')) {
      return true;
    }
  }
  return false;
}

function childIds(record: JsonRecord): string[] | null {
  if (record['child'] !== undefined && record['children'] !== undefined) {
    return null;
  }
  const ids: string[] = [];
  if (record['child'] !== undefined) {
    if (typeof record['child'] !== 'string' || (record['child'] as string).length === 0) {
      return null;
    }
    ids.push(record['child'] as string);
  }
  if (record['children'] !== undefined) {
    if (!Array.isArray(record['children'])) {
      return null;
    }
    const children = record['children'] as Object[];
    for (let index = 0; index < children.length; index++) {
      if (typeof children[index] !== 'string' || (children[index] as string).length === 0 ||
        ids.indexOf(children[index] as string) >= 0) {
        return null;
      }
      ids.push(children[index] as string);
    }
  }
  return ids;
}

function validComponentFields(record: JsonRecord): boolean {
  const stringKeys: string[] = [
    'body', 'component', 'dataPath', 'id', 'path', 'status',
    'text', 'title', 'tone', 'variant'
  ];
  for (let index = 0; index < stringKeys.length; index++) {
    const value = record[stringKeys[index]];
    if (value !== undefined && typeof value !== 'string') {
      return false;
    }
  }
  return true;
}

function offerMap(offers: ActionOffer[]): Map<string, ActionOffer> | null {
  const mapped: Map<string, ActionOffer> = new Map<string, ActionOffer>();
  for (let index = 0; index < offers.length; index++) {
    const offer = offers[index];
    if (offer.offerId.length === 0 || offer.actionId.length === 0 || offer.label.length === 0 ||
      mapped.has(offer.offerId)) {
      return null;
    }
    mapped.set(offer.offerId, offer);
  }
  return mapped;
}

function actionFor(offer: ActionOffer): A2uiAction | null {
  try {
    return {
      id: offer.actionId,
      label: offer.label,
      prompt: offer.label,
      variant: offer.variant,
      kind: 'prompt',
      args: JSON.parse(JSON.stringify(offer.args)) as Object
    };
  } catch (_error) {
    return null;
  }
}

function resolvedActions(
  value: JsonValue,
  offers: Map<string, ActionOffer>,
  usedOffers: Set<string>
): A2uiAction[] | null {
  if (!Array.isArray(value)) {
    return null;
  }
  const references = value as Object[];
  const actions: A2uiAction[] = [];
  for (let index = 0; index < references.length; index++) {
    const reference = objectRecord(references[index]);
    if (reference === null || !exactKeys(reference, ['offerId']) || typeof reference['offerId'] !== 'string') {
      return null;
    }
    const offerId = reference['offerId'] as string;
    const offer = offers.get(offerId);
    if (offer === undefined || usedOffers.has(offerId)) {
      return null;
    }
    const action = actionFor(offer);
    if (action === null) {
      return null;
    }
    usedOffers.add(offerId);
    actions.push(action);
  }
  return actions;
}

function candidateComponents(
  value: JsonValue,
  rootId: string,
  baselinePaths: string[],
  offers: ActionOffer[]
): A2uiComponent[] | null {
  if (!Array.isArray(value)) {
    return null;
  }
  const rawComponents = value as Object[];
  if (rawComponents.length === 0 || rawComponents.length > MAX_LAYOUT_COMPONENTS) {
    return null;
  }
  const catalog = catalogNames();
  const availableOffers = offerMap(offers);
  if (catalog.size === 0 || availableOffers === null) {
    return null;
  }
  const byId: Map<string, JsonRecord> = new Map<string, JsonRecord>();
  const childrenById: Map<string, string[]> = new Map<string, string[]>();
  const parentCount: Map<string, number> = new Map<string, number>();
  const output: A2uiComponent[] = [];
  const usedOffers: Set<string> = new Set<string>();
  for (let index = 0; index < rawComponents.length; index++) {
    const record = objectRecord(rawComponents[index]);
    if (record === null || !allowedKeys(record, COMPONENT_KEYS) || !validComponentFields(record) ||
      typeof record['id'] !== 'string' || (record['id'] as string).length === 0 ||
      typeof record['component'] !== 'string' || !catalog.has(record['component'] as string)) {
      return null;
    }
    const id = record['id'] as string;
    if (byId.has(id)) {
      return null;
    }
    if (record['dataPath'] !== undefined &&
      (typeof record['dataPath'] !== 'string' || !validDataPath(record['dataPath'] as string, baselinePaths))) {
      return null;
    }
    const childList = childIds(record);
    if (childList === null) {
      return null;
    }
    let clone: A2uiComponent;
    try {
      clone = JSON.parse(JSON.stringify(record)) as A2uiComponent;
    } catch (_error) {
      return null;
    }
    if (record['actions'] !== undefined) {
      const actions = resolvedActions(record['actions'], availableOffers, usedOffers);
      if (actions === null) {
        return null;
      }
      clone.actions = actions;
    }
    byId.set(id, record);
    childrenById.set(id, childList);
    parentCount.set(id, 0);
    output.push(clone);
  }
  if (!byId.has(rootId)) {
    return null;
  }
  const ids = Array.from(byId.keys());
  for (let index = 0; index < ids.length; index++) {
    const children = childrenById.get(ids[index]);
    if (children === undefined) {
      return null;
    }
    for (let childIndex = 0; childIndex < children.length; childIndex++) {
      const child = children[childIndex];
      if (!byId.has(child)) {
        return null;
      }
      parentCount.set(child, (parentCount.get(child) ?? 0) + 1);
    }
  }
  for (let index = 0; index < ids.length; index++) {
    const expectedParents = ids[index] === rootId ? 0 : 1;
    if (parentCount.get(ids[index]) !== expectedParents) {
      return null;
    }
  }
  const visited: Set<string> = new Set<string>();
  const queue: string[] = [rootId];
  while (queue.length > 0) {
    const id = queue.shift();
    if (id === undefined || visited.has(id)) {
      return null;
    }
    visited.add(id);
    const children = childrenById.get(id);
    if (children === undefined) {
      return null;
    }
    for (let index = 0; index < children.length; index++) {
      queue.push(children[index]);
    }
  }
  return visited.size === output.length ? output : null;
}

function candidateEnvelope(
  candidateJsonl: string,
  surfaceId: string,
  baseline: LayoutBaseline,
  offers: ActionOffer[]
): A2uiEnvelope | null {
  const lines = candidateJsonl.trim().split(/\r?\n/);
  if (lines.length !== 1) {
    return null;
  }
  const record = parseRecord(lines[0]);
  if (record === null || !exactKeys(record, ['version', 'updateComponents'])) {
    return null;
  }
  const update = objectRecord(record['updateComponents']);
  if (update === null || !exactKeys(update, ['components', 'surfaceId']) || update['surfaceId'] !== surfaceId) {
    return null;
  }
  const components = candidateComponents(update['components'], baseline.rootId, baseline.dataPaths, offers);
  if (components === null) {
    return null;
  }
  return {
    version: baseline.componentEnvelope.version,
    updateComponents: {
      surfaceId: surfaceId,
      components: components
    }
  };
}

export function mergeA2uiLayout(
  baselineJsonl: string,
  candidateJsonl: string,
  surfaceId: string,
  offers: ActionOffer[]
): string {
  if (baselineJsonl.length === 0 || candidateJsonl.length === 0 || surfaceId.length === 0) {
    return baselineJsonl;
  }
  const lines = baselineJsonl.split('\n');
  const baseline = baselineOf(lines, surfaceId);
  if (baseline === null) {
    return baselineJsonl;
  }
  const candidate = candidateEnvelope(candidateJsonl, surfaceId, baseline, offers);
  if (candidate === null) {
    return baselineJsonl;
  }
  lines[baseline.componentLineIndex] = JSON.stringify(candidate);
  return lines.join('\n');
}
