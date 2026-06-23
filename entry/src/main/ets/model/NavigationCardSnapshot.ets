import { A2uiAction, A2uiFoodData } from './A2uiTypes';
import { buildSystemFoodNavigationUri } from './FoodNavigation';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION: string = 'navigation.destination';
export const NAVIGATION_CARD_ACTION_OPEN_MAP: string = 'open_map';
export const NAVIGATION_CARD_ACTION_OPEN_AGENT: string = 'open_agent';
export const NAVIGATION_CARD_ACTION_REFRESH: string = 'refresh';
export const NAVIGATION_CARD_PIN_ACTION_ID: string = 'navigation_card_pin_destination';

export type NavigationCardSnapshotStatus = 'ready' | 'empty' | 'expired' | 'error';
export type NavigationCardFormEvent = 'open_map' | 'open_agent' | 'refresh' | '';

export interface NavigationCardSnapshot {
  kind: string;
  status: NavigationCardSnapshotStatus;
  title: string;
  subtitle: string;
  address: string;
  location: string;
  sourceTags: string[];
  mapUri: string;
  surfaceId: string;
  toolId: string;
  updatedAt: number;
  expiresAt: number;
  error: string;
}

export interface NavigationCardSnapshotContext {
  surfaceId: string;
  toolId: string;
  updatedAt: number;
  expiresAt: number;
}

export interface NavigationCardSnapshotBuildResult {
  ok: boolean;
  error: string;
  snapshot?: NavigationCardSnapshot;
}

export interface NavigationCardBindingData {
  kind: string;
  status: string;
  cardStatus: string;
  title: string;
  subtitle: string;
  address: string;
  location: string;
  sourceText: string;
  mapUri: string;
  destinationUri: string;
  message: string;
  updatedText: string;
  primaryAction: string;
  secondaryAction: string;
}

export interface NavigationCardSnapshotStore {
  saveSnapshot(snapshot: NavigationCardSnapshot): Promise<void>;
  getSnapshot(): Promise<NavigationCardSnapshot | null>;
  clearSnapshot(): Promise<void>;
  addFormId(formId: string): Promise<void>;
  removeFormId(formId: string): Promise<void>;
  getFormIds(): Promise<string[]>;
}

interface LooseNavigationCardEvent {
  action?: string;
  type?: string;
  event?: string;
}

const NAVIGATION_CARD_SOURCE_TAG_LIMIT: number = 4;
const NAVIGATION_CARD_MISSING_COORDINATE: string = '缺少真实坐标，不能生成导航卡片';
const NAVIGATION_CARD_STORE: string = 'navigation_card_snapshot_store';
const NAVIGATION_CARD_SNAPSHOT_KEY: string = 'current_snapshot';
const NAVIGATION_CARD_FORM_IDS_KEY: string = 'form_ids';

function cleanText(value: string | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.trim();
}

function cleanNumber(value: number): number {
  if (Number.isFinite(value)) {
    return value;
  }
  return 0;
}

function flushPreferences(store: preferences.Preferences): void {
  store.flush().catch((_error: Error) => {});
}

function navigationCardStoreError(): Error {
  return new Error('导航卡片存储暂时不可用');
}

function textFromValue(value: preferences.ValueType | string | number | boolean | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function snapshotSubtitle(item: A2uiFoodData): string {
  const distance = cleanText(item.distance);
  if (distance.length > 0) {
    return distance;
  }
  const address = cleanText(item.address);
  if (address.length > 0) {
    return address;
  }
  return '真实地点结果';
}

export function sanitizeNavigationCardSourceTags(values: string[] | undefined): string[] {
  if (values === undefined || values === null || !Array.isArray(values)) {
    return [];
  }
  const tags: string[] = [];
  values.forEach((value: string) => {
    const tag = cleanText(value);
    if (tag.length > 0 && tags.indexOf(tag) < 0 && tags.length < NAVIGATION_CARD_SOURCE_TAG_LIMIT) {
      tags.push(tag);
    }
  });
  return tags;
}

export function navigationCardSnapshotExpired(snapshot: NavigationCardSnapshot, nowMs: number): boolean {
  return snapshot.expiresAt > 0 && nowMs >= snapshot.expiresAt;
}

export function navigationCardSnapshotFromFoodOption(
  item: A2uiFoodData,
  context: NavigationCardSnapshotContext
): NavigationCardSnapshotBuildResult {
  const location = cleanText(item.location);
  const title = cleanText(item.name).length > 0 ? cleanText(item.name) : '目的地';
  const mapUri = buildSystemFoodNavigationUri(location, '', title);
  if (mapUri.length === 0) {
    return {
      ok: false,
      error: NAVIGATION_CARD_MISSING_COORDINATE
    };
  }
  const snapshot: NavigationCardSnapshot = {
    kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
    status: 'ready',
    title: title,
    subtitle: snapshotSubtitle(item),
    address: cleanText(item.address),
    location: location,
    sourceTags: sanitizeNavigationCardSourceTags(item.sourceTags),
    mapUri: mapUri,
    surfaceId: cleanText(context.surfaceId),
    toolId: cleanText(context.toolId),
    updatedAt: cleanNumber(context.updatedAt),
    expiresAt: cleanNumber(context.expiresAt),
    error: ''
  };
  return {
    ok: true,
    error: '',
    snapshot: snapshot
  };
}

export function canCreateNavigationCardFromFoodOption(item: A2uiFoodData): boolean {
  const location = cleanText(item.location);
  const title = cleanText(item.name).length > 0 ? cleanText(item.name) : '目的地';
  return buildSystemFoodNavigationUri(location, '', title).length > 0;
}

export function navigationCardPinActionFromFoodOption(item: A2uiFoodData): A2uiAction {
  if (!canCreateNavigationCardFromFoodOption(item)) {
    return {
      id: '',
      label: '',
      prompt: '',
      variant: '',
      kind: ''
    };
  }
  return {
    id: NAVIGATION_CARD_PIN_ACTION_ID,
    label: '固定为导航卡片',
    prompt: '',
    variant: 'secondary',
    kind: 'client'
  };
}

function formatUpdatedText(updatedAt: number): string {
  if (updatedAt <= 0) {
    return '';
  }
  const date = new Date(updatedAt);
  const hours = twoDigits(date.getHours());
  const minutes = twoDigits(date.getMinutes());
  return hours + ':' + minutes + ' 更新';
}

function twoDigits(value: number): string {
  if (value < 10) {
    return '0' + value.toString();
  }
  return value.toString();
}

export function buildEmptyNavigationCardBindingData(): NavigationCardBindingData {
  return {
    kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
    status: 'empty',
    cardStatus: 'empty',
    title: 'PocketAgent 导航',
    subtitle: '',
    address: '',
    location: '',
    sourceText: '',
    mapUri: '',
    destinationUri: '',
    message: '从 PocketAgent 对话生成导航卡片',
    updatedText: '',
    primaryAction: NAVIGATION_CARD_ACTION_OPEN_AGENT,
    secondaryAction: NAVIGATION_CARD_ACTION_REFRESH
  };
}

export function buildNavigationCardBindingData(snapshot: NavigationCardSnapshot | null,
  nowMs: number = Date.now()): NavigationCardBindingData {
  if (snapshot === null || snapshot === undefined || snapshot.status === 'empty') {
    return buildEmptyNavigationCardBindingData();
  }
  if (snapshot.status === 'error') {
    return {
      kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
      status: 'error',
      cardStatus: 'error',
      title: snapshot.title.length > 0 ? snapshot.title : '导航卡片不可用',
      subtitle: snapshot.subtitle,
      address: snapshot.address,
      location: snapshot.location,
      sourceText: snapshot.sourceTags.join(' / '),
      mapUri: '',
      destinationUri: '',
      message: snapshot.error.length > 0 ? snapshot.error : '导航卡片生成失败',
      updatedText: formatUpdatedText(snapshot.updatedAt),
      primaryAction: NAVIGATION_CARD_ACTION_OPEN_AGENT,
      secondaryAction: NAVIGATION_CARD_ACTION_REFRESH
    };
  }
  if (navigationCardSnapshotExpired(snapshot, nowMs)) {
    return {
      kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
      status: 'expired',
      cardStatus: 'expired',
      title: snapshot.title,
      subtitle: snapshot.subtitle,
      address: snapshot.address,
      location: snapshot.location,
      sourceText: snapshot.sourceTags.join(' / '),
      mapUri: '',
      destinationUri: '',
      message: '导航卡片已过期，请回到 PocketAgent 刷新真实结果',
      updatedText: formatUpdatedText(snapshot.updatedAt),
      primaryAction: NAVIGATION_CARD_ACTION_OPEN_AGENT,
      secondaryAction: NAVIGATION_CARD_ACTION_REFRESH
    };
  }
  return {
    kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
    status: 'ready',
    cardStatus: 'ready',
    title: snapshot.title,
    subtitle: snapshot.subtitle,
    address: snapshot.address,
    location: snapshot.location,
    sourceText: snapshot.sourceTags.join(' / '),
    mapUri: snapshot.mapUri,
    destinationUri: snapshot.mapUri,
    message: snapshot.address.length > 0 ? snapshot.address : '真实 provider 坐标',
    updatedText: formatUpdatedText(snapshot.updatedAt),
    primaryAction: NAVIGATION_CARD_ACTION_OPEN_MAP,
    secondaryAction: NAVIGATION_CARD_ACTION_OPEN_AGENT
  };
}

export function navigationCardFormEventFromMessage(message: string): NavigationCardFormEvent {
  const trimmed = cleanText(message);
  if (trimmed === NAVIGATION_CARD_ACTION_OPEN_MAP ||
    trimmed === NAVIGATION_CARD_ACTION_OPEN_AGENT ||
    trimmed === NAVIGATION_CARD_ACTION_REFRESH) {
    return trimmed as NavigationCardFormEvent;
  }
  try {
    const parsed = JSON.parse(trimmed) as LooseNavigationCardEvent;
    const candidate = cleanText(parsed.action).length > 0 ? cleanText(parsed.action) :
      (cleanText(parsed.type).length > 0 ? cleanText(parsed.type) : cleanText(parsed.event));
    if (candidate === NAVIGATION_CARD_ACTION_OPEN_MAP ||
      candidate === NAVIGATION_CARD_ACTION_OPEN_AGENT ||
      candidate === NAVIGATION_CARD_ACTION_REFRESH) {
      return candidate as NavigationCardFormEvent;
    }
  } catch (_error) {
  }
  return '';
}

export class MemoryNavigationCardSnapshotStore implements NavigationCardSnapshotStore {
  private snapshot: NavigationCardSnapshot | null = null;
  private formIds: string[] = [];

  async saveSnapshot(snapshot: NavigationCardSnapshot): Promise<void> {
    this.snapshot = snapshot;
  }

  async getSnapshot(): Promise<NavigationCardSnapshot | null> {
    return this.snapshot;
  }

  async clearSnapshot(): Promise<void> {
    this.snapshot = null;
  }

  async addFormId(formId: string): Promise<void> {
    const id = cleanText(formId);
    if (id.length > 0 && this.formIds.indexOf(id) < 0) {
      this.formIds.push(id);
    }
  }

  async removeFormId(formId: string): Promise<void> {
    const id = cleanText(formId);
    this.formIds = this.formIds.filter((value: string) => value !== id);
  }

  async getFormIds(): Promise<string[]> {
    return this.formIds.slice();
  }
}

function stringArrayFromRaw(raw: string): string[] {
  try {
    const parsed = JSON.parse(raw) as string[];
    if (!Array.isArray(parsed)) {
      return [];
    }
    const values: string[] = [];
    parsed.forEach((item: string) => {
      const value = cleanText(item);
      if (value.length > 0 && values.indexOf(value) < 0) {
        values.push(value);
      }
    });
    return values;
  } catch (_error) {
    return [];
  }
}

function snapshotFromRaw(raw: string): NavigationCardSnapshot | null {
  if (raw.length === 0) {
    return null;
  }
  try {
    const parsed = JSON.parse(raw) as NavigationCardSnapshot;
    if (parsed === undefined || parsed === null || parsed.kind !== CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION) {
      return null;
    }
    return {
      kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
      status: parsed.status === 'ready' || parsed.status === 'error' || parsed.status === 'expired' || parsed.status === 'empty' ? parsed.status : 'error',
      title: cleanText(parsed.title),
      subtitle: cleanText(parsed.subtitle),
      address: cleanText(parsed.address),
      location: cleanText(parsed.location),
      sourceTags: sanitizeNavigationCardSourceTags(parsed.sourceTags),
      mapUri: cleanText(parsed.mapUri),
      surfaceId: cleanText(parsed.surfaceId),
      toolId: cleanText(parsed.toolId),
      updatedAt: cleanNumber(parsed.updatedAt),
      expiresAt: cleanNumber(parsed.expiresAt),
      error: cleanText(parsed.error)
    };
  } catch (_error) {
    return null;
  }
}

export class PreferencesNavigationCardSnapshotStore implements NavigationCardSnapshotStore {
  private context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  private preferences(): preferences.Preferences | null {
    try {
      return preferences.getPreferencesSync(this.context, { name: NAVIGATION_CARD_STORE });
    } catch (_error) {
      return null;
    }
  }

  saveSnapshotSync(snapshot: NavigationCardSnapshot): void {
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      store.putSync(NAVIGATION_CARD_SNAPSHOT_KEY, JSON.stringify(snapshot));
      flushPreferences(store);
    } catch (_error) {
    }
  }

  async saveSnapshot(snapshot: NavigationCardSnapshot): Promise<void> {
    const store = this.preferences();
    if (store === null) {
      throw navigationCardStoreError();
    }
    try {
      store.putSync(NAVIGATION_CARD_SNAPSHOT_KEY, JSON.stringify(snapshot));
      await store.flush();
    } catch (_error) {
      throw navigationCardStoreError();
    }
  }

  getSnapshotSync(): NavigationCardSnapshot | null {
    const store = this.preferences();
    if (store === null) {
      return null;
    }
    try {
      const raw = textFromValue(store.getSync(NAVIGATION_CARD_SNAPSHOT_KEY, ''));
      return snapshotFromRaw(raw);
    } catch (_error) {
      return null;
    }
  }

  async getSnapshot(): Promise<NavigationCardSnapshot | null> {
    return this.getSnapshotSync();
  }

  clearSnapshotSync(): void {
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      store.deleteSync(NAVIGATION_CARD_SNAPSHOT_KEY);
      flushPreferences(store);
    } catch (_error) {
    }
  }

  async clearSnapshot(): Promise<void> {
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      store.deleteSync(NAVIGATION_CARD_SNAPSHOT_KEY);
      await store.flush();
    } catch (_error) {
    }
  }

  addFormIdSync(formId: string): void {
    const id = cleanText(formId);
    if (id.length === 0) {
      return;
    }
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      const ids = stringArrayFromRaw(textFromValue(store.getSync(NAVIGATION_CARD_FORM_IDS_KEY, '')));
      if (ids.indexOf(id) < 0) {
        ids.push(id);
      }
      store.putSync(NAVIGATION_CARD_FORM_IDS_KEY, JSON.stringify(ids));
      flushPreferences(store);
    } catch (_error) {
    }
  }

  async addFormId(formId: string): Promise<void> {
    const id = cleanText(formId);
    if (id.length === 0) {
      return;
    }
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      const ids = stringArrayFromRaw(textFromValue(store.getSync(NAVIGATION_CARD_FORM_IDS_KEY, '')));
      if (ids.indexOf(id) < 0) {
        ids.push(id);
      }
      store.putSync(NAVIGATION_CARD_FORM_IDS_KEY, JSON.stringify(ids));
      await store.flush();
    } catch (_error) {
    }
  }

  removeFormIdSync(formId: string): void {
    const id = cleanText(formId);
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      const ids = stringArrayFromRaw(textFromValue(store.getSync(NAVIGATION_CARD_FORM_IDS_KEY, '')))
        .filter((value: string) => value !== id);
      store.putSync(NAVIGATION_CARD_FORM_IDS_KEY, JSON.stringify(ids));
      flushPreferences(store);
    } catch (_error) {
    }
  }

  async removeFormId(formId: string): Promise<void> {
    const id = cleanText(formId);
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      const ids = stringArrayFromRaw(textFromValue(store.getSync(NAVIGATION_CARD_FORM_IDS_KEY, '')))
        .filter((value: string) => value !== id);
      store.putSync(NAVIGATION_CARD_FORM_IDS_KEY, JSON.stringify(ids));
      await store.flush();
    } catch (_error) {
    }
  }

  getFormIdsSync(): string[] {
    const store = this.preferences();
    if (store === null) {
      return [];
    }
    try {
      return stringArrayFromRaw(textFromValue(store.getSync(NAVIGATION_CARD_FORM_IDS_KEY, '')));
    } catch (_error) {
      return [];
    }
  }

  async getFormIds(): Promise<string[]> {
    return this.getFormIdsSync();
  }
}
