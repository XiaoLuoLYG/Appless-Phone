import {
  A2uiAction,
  A2uiApplyResult,
  A2uiEnvelope,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  A2uiSurfaceStore,
  CreateDataTaskPayload,
  DataTaskAuthorizationResult,
  SurfaceActionAuthorizer,
  UiSurfaceWriteLease,
  UiSurfaceWriter,
  parseA2uiJsonl,
  parseHotelDetailRequest,
  parseHotelSearchRequest,
  toolDefinitionForToolId
} from '@loop/agent-core';
import { createHtmlHomeDocument } from '../html/HtmlHomeSnapshot';
import { isHtmlHomeActionAllowed } from '../html/HtmlHomeActionPolicy';
import { HtmlHomeAction, HtmlHomeDocument } from '../html/HtmlHomeTypes';
import { HotelActionIdFactory } from './AiphoneRegisteredActionExecutor';
import { HotelPlannerIdFactory } from './HotelLeaderPlanner';
import {
  registeredPageSourceToolId,
  resolveRegisteredPageAction
} from './RegisteredPageActionRoute';

const SURFACE_HISTORY_LIMIT: number = 20;

export type HotelTurnStatus = 'success' | 'partial' | 'empty' | 'error' | 'canceled' | 'timeout';

export type HotelSurfaceApplyCallback = (
  surface: A2uiSurfaceState,
  generation: number,
  turnId: string
) => boolean;

export interface HotelActionContext {
  conversationId: string;
  turnId: string;
  surfaceId: string;
  sourceToolId: string;
}

interface PreparedFollowUpIds {
  dataTaskId: string;
  uiTaskId: string;
}

interface HotelSurfaceRecord {
  turnId: string;
  surfaceId: string;
  store: A2uiSurfaceStore;
  sourceToolId: string;
  surface?: A2uiSurfaceState;
  document?: HtmlHomeDocument;
  lease?: UiSurfaceWriteLease;
  generation: number;
  revision: number;
  downstreamRevision: number;
  deliveredRevision: number;
}

interface HotelSearchSurfaceSnapshot {
  turnId: string;
  surfaceId: string;
  sourceToolId: string;
  surface: A2uiSurfaceState;
  lease: UiSurfaceWriteLease;
}

export class MonotonicHotelIds implements HotelPlannerIdFactory, HotelActionIdFactory {
  private next: number = 0;

  nextId(prefix: string): string {
    this.next += 1;
    return prefix + '-' + this.next.toString();
  }
}

export class PreparedHotelFollowUpIds implements HotelActionIdFactory {
  private readonly ids: MonotonicHotelIds;
  private preparedDataTaskId: string = '';
  private preparedUiTaskId: string = '';

  constructor(ids: MonotonicHotelIds) {
    this.ids = ids;
  }

  prepare(): PreparedFollowUpIds {
    this.clear();
    this.preparedDataTaskId = this.ids.nextId('hotel-detail-data');
    this.preparedUiTaskId = this.ids.nextId('hotel-detail-ui');
    return {
      dataTaskId: this.preparedDataTaskId,
      uiTaskId: this.preparedUiTaskId
    };
  }

  nextId(prefix: string): string {
    if (prefix === 'hotel-detail-data' && this.preparedDataTaskId.length > 0) {
      const value = this.preparedDataTaskId;
      this.preparedDataTaskId = '';
      return value;
    }
    if (prefix === 'hotel-detail-ui' && this.preparedUiTaskId.length > 0) {
      const value = this.preparedUiTaskId;
      this.preparedUiTaskId = '';
      return value;
    }
    return this.ids.nextId(prefix);
  }

  clear(): void {
    this.preparedDataTaskId = '';
    this.preparedUiTaskId = '';
  }
}

export function authorizeHotelDataTask(task: CreateDataTaskPayload): DataTaskAuthorizationResult {
  const definition = toolDefinitionForToolId(task.toolId);
  if (definition === null || definition.riskLevel !== 'read' ||
    definition.outputSchema !== task.outputSchema) {
    return {
      ok: false,
      code: 'DATA_TASK_UNAUTHORIZED',
      message: 'Hotel data task is not a registered read capability.'
    };
  }
  const dataBackends: Set<string> = new Set<string>([
    'local_adapter',
    'oauth_api',
    'imap',
    'workspace_mcp',
    'web_session',
    'mcp_remote'
  ]);
  for (let index = 0; index < definition.backendPriority.length; index++) {
    if (!dataBackends.has(definition.backendPriority[index])) {
      return {
        ok: false,
        code: 'DATA_TASK_BACKEND_FORBIDDEN',
        message: 'Hotel data task cannot execute a system action backend.'
      };
    }
  }
  const parsed = task.toolId === 'hotel.search' ?
    parseHotelSearchRequest(task.args) :
    task.toolId === 'hotel.detail' ? parseHotelDetailRequest(task.args) : null;
  if (parsed === null || !parsed.ok || parsed.value === null) {
    return {
      ok: false,
      code: 'DATA_TASK_ARGS_INVALID',
      message: 'Hotel data task arguments are invalid.'
    };
  }
  return { ok: true, code: '', message: '' };
}

export class IgnoreHotelSurfaceWriter implements UiSurfaceWriter {
  async write(
    _turnId: string,
    _surfaceId: string,
    _jsonl: string,
    _lease: UiSurfaceWriteLease
  ): Promise<void> {
  }
}

export class HotelSurfaceAuthority implements SurfaceActionAuthorizer {
  private conversationId: string = '';
  private turnId: string = '';
  private surfaceId: string = '';
  private sourceToolId: string = '';
  private readonly allowed: Set<string> = new Set<string>();

  activate(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    sourceToolId: string,
    document: HtmlHomeDocument,
    exactPageAction?: A2uiAction
  ): void {
    this.clear();
    this.conversationId = conversationId;
    this.turnId = turnId;
    this.surfaceId = surfaceId;
    this.sourceToolId = sourceToolId;
    this.collect(document, document.actions);
    document.blocks.forEach((block) => {
      this.collect(document, block.actions);
    });
    if (exactPageAction !== undefined && exactPageAction.args !== undefined) {
      this.allowed.add(this.actionKey(exactPageAction.id, exactPageAction.args));
    }
  }

  clear(): void {
    this.conversationId = '';
    this.turnId = '';
    this.surfaceId = '';
    this.sourceToolId = '';
    this.allowed.clear();
  }

  allows(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    actionId: string,
    args: Object
  ): boolean {
    return conversationId === this.conversationId &&
      turnId === this.turnId &&
      surfaceId === this.surfaceId &&
      this.allowed.has(this.actionKey(actionId, args));
  }

  context(): HotelActionContext | null {
    if (this.conversationId.length === 0 || this.turnId.length === 0 ||
      this.surfaceId.length === 0 || this.sourceToolId.length === 0) {
      return null;
    }
    return {
      conversationId: this.conversationId,
      turnId: this.turnId,
      surfaceId: this.surfaceId,
      sourceToolId: this.sourceToolId
    };
  }

  private collect(document: HtmlHomeDocument, actions: HtmlHomeAction[]): void {
    actions.forEach((candidate: HtmlHomeAction) => {
      const clicked: A2uiAction = {
        id: candidate.id,
        label: candidate.label,
        prompt: candidate.prompt,
        variant: candidate.variant,
        kind: candidate.kind
      };
      if (candidate.args !== undefined) {
        clicked.args = candidate.args;
      }
      if (clicked.args === undefined || !isHtmlHomeActionAllowed(document, clicked)) {
        return;
      }
      let execution: A2uiAction | null = null;
      if ((clicked.id === 'hotel.detail' || clicked.id === 'hotel.navigate') &&
        this.sourceToolId === 'hotel.search') {
        execution = clicked;
      } else if (clicked.id === 'hotel.booking.open' && this.sourceToolId === 'hotel.detail') {
        execution = clicked;
      } else {
        const route = resolveRegisteredPageAction(this.sourceToolId, clicked);
        execution = route === null ? null : route.action;
      }
      if (execution !== null && execution.args !== undefined) {
        this.allowed.add(this.actionKey(execution.id, execution.args));
      }
    });
  }

  private actionKey(actionId: string, args: Object): string {
    return actionId + '\n' + JSON.stringify(args);
  }
}

export class HotelVisibility {
  private turnId: string = '';
  private generation: number = 0;
  private surfaceId: string = '';

  expect(turnId: string, generation: number): void {
    this.turnId = turnId;
    this.generation = generation;
    this.surfaceId = '';
  }

  activate(turnId: string, generation: number): boolean {
    if (this.turnId !== turnId || this.generation !== generation) {
      return false;
    }
    return true;
  }

  restore(turnId: string, generation: number, surfaceId: string): void {
    this.turnId = turnId;
    this.generation = generation;
    this.surfaceId = surfaceId;
  }

  setSurface(turnId: string, generation: number, surfaceId: string): boolean {
    if (this.turnId !== turnId || this.generation !== generation) {
      return false;
    }
    this.surfaceId = surfaceId;
    return true;
  }

  matches(turnId: string, generation: number): boolean {
    return this.turnId === turnId && this.generation === generation;
  }

  currentSurfaceId(): string {
    return this.surfaceId;
  }

  currentTurnId(): string {
    return this.turnId;
  }

  generationFor(turnId: string): number {
    return this.turnId === turnId ? this.generation : 0;
  }

  clear(): void {
    this.turnId = '';
    this.generation = 0;
    this.surfaceId = '';
  }
}

export class HotelRuntimeSurfaceWriter implements UiSurfaceWriter {
  private readonly conversationId: string;
  private readonly downstream: UiSurfaceWriter;
  private readonly callback: HotelSurfaceApplyCallback | null;
  private readonly authority: HotelSurfaceAuthority;
  private readonly visibility: HotelVisibility;
  private readonly records: Map<string, HotelSurfaceRecord> =
    new Map<string, HotelSurfaceRecord>();
  private readonly recordOrder: string[] = [];
  private searchRecord: HotelSearchSurfaceSnapshot | null = null;
  private disposed: boolean = false;
  private readonly autoActivate: boolean;
  private automaticGeneration: number = 0;
  private pinnedAutomaticTurnId: string = '';

  constructor(
    conversationId: string,
    downstream: UiSurfaceWriter,
    callback: HotelSurfaceApplyCallback | null,
    authority: HotelSurfaceAuthority,
    visibility: HotelVisibility,
    autoActivate: boolean = false
  ) {
    this.conversationId = conversationId;
    this.downstream = downstream;
    this.callback = callback;
    this.authority = authority;
    this.visibility = visibility;
    this.autoActivate = autoActivate;
  }

  async write(
    turnId: string,
    surfaceId: string,
    jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void> {
    if (this.disposed) {
      return;
    }
    if (this.autoActivate && this.visibility.generationFor(turnId) === 0 &&
      (this.pinnedAutomaticTurnId.length === 0 || this.pinnedAutomaticTurnId === turnId)) {
      this.automaticGeneration++;
      this.visibility.expect(turnId, this.automaticGeneration);
    }
    const parsed = parseA2uiJsonl(jsonl);
    if (parsed.error.length > 0) {
      throw new Error(parsed.error);
    }
    let record = this.records.get(surfaceId);
    if (record === undefined) {
      record = {
        turnId,
        surfaceId,
        store: new A2uiSurfaceStore(),
        sourceToolId: '',
        generation: this.visibility.generationFor(turnId),
        revision: 0,
        downstreamRevision: 0,
        deliveredRevision: 0
      };
      this.records.set(surfaceId, record);
      this.recordOrder.push(surfaceId);
      this.prune();
    } else if (record.turnId !== turnId) {
      throw new Error('Hotel surface identity changed turns.');
    }
    if (record.generation === 0) {
      record.generation = this.visibility.generationFor(turnId);
    }
    let replacesSurfaceSnapshot: boolean = false;
    for (let index = 0; index < parsed.envelopes.length; index++) {
      const createSurface = parsed.envelopes[index].createSurface;
      if (createSurface !== undefined && createSurface !== null &&
        createSurface.surfaceId === surfaceId) {
        replacesSurfaceSnapshot = true;
        break;
      }
    }
    if (record.revision > 0 && replacesSurfaceSnapshot) {
      const retainedState: A2uiSurfaceState = record.store.getSurface();
      retainedState.components = [];
      record.store.seed(retainedState);
    }
    parsed.envelopes.forEach((envelope: A2uiEnvelope) => {
      const applied: A2uiApplyResult = (record as HotelSurfaceRecord).store.apply(envelope);
      if (!applied.ok) {
        throw new Error(applied.error);
      }
    });
    record.revision += 1;
    record.surface = record.store.getSurface();
    record.document = createHtmlHomeDocument({
      surface: record.surface,
      messages: [],
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    const detected = this.sourceToolId(record.surface);
    if (detected.length > 0) {
      record.sourceToolId = detected;
    }
    const revision = record.revision;
    await this.downstream.write(turnId, surfaceId, jsonl, lease);
    if (this.disposed || !lease.isActive()) {
      return;
    }
    record.lease = lease;
    record.downstreamRevision = Math.max(record.downstreamRevision, revision);
    if (this.visibility.matches(turnId, record.generation)) {
      this.deliver(record);
    }
    this.prune();
  }

  activateTurn(turnId: string, generation: number): boolean {
    if (this.disposed || !this.visibility.activate(turnId, generation)) {
      return false;
    }
    let delivered = true;
    this.records.forEach((record: HotelSurfaceRecord) => {
      if (record.turnId !== turnId) {
        return;
      }
      record.generation = generation;
      if (record.downstreamRevision > record.deliveredRevision) {
        try {
          this.deliver(record);
        } catch (_error) {
          delivered = false;
        }
      }
    });
    return delivered;
  }

  markSearchReference(turnId: string): void {
    const surfaceId = this.visibility.currentSurfaceId();
    const record = this.records.get(surfaceId);
    if (record !== undefined && record.turnId === turnId &&
      record.sourceToolId === 'hotel.search' &&
      record.surface !== undefined &&
      record.document !== undefined &&
      record.lease !== undefined &&
      record.lease.isActive()) {
      const snapshotStore = new A2uiSurfaceStore();
      this.searchRecord = {
        turnId: record.turnId,
        surfaceId: record.surfaceId,
        sourceToolId: record.sourceToolId,
        surface: snapshotStore.seed(record.surface),
        lease: record.lease
      };
    }
    this.prune();
  }

  restoreSearchSurface(turnId: string, generation: number): boolean {
    const record = this.searchRecord;
    if (this.disposed || record === null || record.turnId !== turnId ||
      !record.lease.isActive()) {
      return false;
    }
    const snapshotStore = new A2uiSurfaceStore();
    const surface = snapshotStore.seed(record.surface);
    const document = createHtmlHomeDocument({
      surface,
      messages: [],
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    try {
      if (this.callback !== null && !this.callback(surface, generation, record.turnId)) {
        return false;
      }
      this.visibility.restore(record.turnId, generation, record.surfaceId);
      this.authority.activate(
        this.conversationId,
        record.turnId,
        record.surfaceId,
        record.sourceToolId,
        document
      );
      return true;
    } catch (_error) {
      return false;
    }
  }

  restoreLatestSearchSurface(): boolean {
    const record = this.searchRecord;
    if (record === null) {
      return false;
    }
    this.pinnedAutomaticTurnId = record.turnId;
    this.automaticGeneration++;
    return this.restoreSearchSurface(record.turnId, this.automaticGeneration);
  }

  activateAutomaticTurn(turnId: string): number {
    if (this.disposed || !this.autoActivate || turnId.trim().length === 0) {
      return 0;
    }
    this.pinnedAutomaticTurnId = turnId;
    this.automaticGeneration++;
    this.visibility.expect(turnId, this.automaticGeneration);
    this.activateTurn(turnId, this.automaticGeneration);
    return this.automaticGeneration;
  }

  activeSurfaceId(): string {
    return this.visibility.currentSurfaceId();
  }

  searchReturnSurface(): A2uiSurfaceState | null {
    if (this.searchRecord === null) {
      return null;
    }
    const snapshotStore = new A2uiSurfaceStore();
    return snapshotStore.seed(this.searchRecord.surface);
  }

  retainedSurfaceCount(): number {
    return this.records.size;
  }

  clearSearchReference(): void {
    this.searchRecord = null;
    this.pinnedAutomaticTurnId = '';
    this.prune();
  }

  pruneRetained(): void {
    this.prune();
  }

  dispose(): void {
    this.disposed = true;
    this.records.clear();
    this.recordOrder.splice(0, this.recordOrder.length);
    this.searchRecord = null;
  }

  private deliver(record: HotelSurfaceRecord): void {
    if (this.disposed ||
      record.surface === undefined ||
      record.document === undefined ||
      record.lease === undefined ||
      !record.lease.isActive() ||
      !this.visibility.matches(record.turnId, record.generation) ||
      record.downstreamRevision <= record.deliveredRevision) {
      return;
    }
    if (this.callback !== null &&
      !this.callback(record.surface, record.generation, record.turnId)) {
      return;
    }
    if (!this.visibility.setSurface(record.turnId, record.generation, record.surfaceId)) {
      return;
    }
    this.authority.activate(
      this.conversationId,
      record.turnId,
      record.surfaceId,
      record.sourceToolId,
      record.document
    );
    if (this.autoActivate && this.sourceToolId(record.surface) === 'hotel.search' &&
      record.lease.isActive()) {
      const snapshotStore = new A2uiSurfaceStore();
      this.searchRecord = {
        turnId: record.turnId,
        surfaceId: record.surfaceId,
        sourceToolId: record.sourceToolId,
        surface: snapshotStore.seed(record.surface),
        lease: record.lease
      };
    }
    record.deliveredRevision = record.downstreamRevision;
  }

  private prune(): void {
    while (this.recordOrder.length > SURFACE_HISTORY_LIMIT) {
      let removed = false;
      for (let index = 0; index < this.recordOrder.length; index++) {
        const surfaceId = this.recordOrder[index];
        const record = this.records.get(surfaceId);
        if (record === undefined) {
          this.recordOrder.splice(index, 1);
          removed = true;
          break;
        }
        const protectedActive = surfaceId === this.visibility.currentSurfaceId();
        if (!protectedActive) {
          this.records.delete(surfaceId);
          this.recordOrder.splice(index, 1);
          removed = true;
          break;
        }
      }
      if (!removed) {
        return;
      }
    }
  }

  private sourceToolId(surface: A2uiSurfaceState): string {
    try {
      const model = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
      if (model.summary.dataLabel === 'actionStatus') {
        return '';
      }
      return registeredPageSourceToolId(surface);
    } catch (_error) {
      return '';
    }
  }
}
