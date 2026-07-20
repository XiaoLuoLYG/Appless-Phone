import {
  ActionAgent,
  ActionArgsValidator,
  ActionCatalog,
  ActionRunPayload,
  ActionValidationResult,
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  A2uiAction,
  A2uiApplyResult,
  A2uiEnvelope,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  A2uiSurfaceStore,
  ClientActionAuthorizer,
  CreateDataTaskPayload,
  CreateUiTaskPayload,
  DataAgent,
  DataResult,
  DataTaskExecutor,
  HotelDetailResult,
  HotelSearchResult,
  LeaderAgent,
  LinkedMessageBus,
  LocalModel,
  SurfaceActionAuthorizer,
  ToolDefinition,
  ToolDefinitionLookup,
  UiAgent,
  UiRenderResult,
  UiRenderResultPayload,
  UiSurfaceWriteLease,
  UiSurfaceWriter,
  UiTaskRenderer,
  UserInputPayload,
  callStructuredHotelTool,
  hotelDetailA2ui,
  hotelFailureA2ui,
  hotelPendingA2ui,
  hotelSearchA2ui,
  parseA2uiJsonl,
  toolDefinitionForToolId,
  validateHotelActionArgs
} from '@loop/agent-core';
import { createHtmlHomeDocument } from '../html/HtmlHomeSnapshot';
import { isHtmlHomeActionAllowed } from '../html/HtmlHomeActionPolicy';
import { HtmlHomeAction, HtmlHomeDocument } from '../html/HtmlHomeTypes';
import {
  HotelActionIdFactory,
  HotelRegisteredActionExecutor,
  SystemUriOpener
} from './HotelRegisteredActionExecutor';
import {
  HotelLeaderPlanner,
  HotelLocalDateProvider,
  HotelPlannerIdFactory
} from './HotelLeaderPlanner';

export type HotelSurfaceCallback = (surface: A2uiSurfaceState) => void;

export interface HotelAgentRuntimeOptions {
  model: LocalModel;
  currentLocalDate: HotelLocalDateProvider;
  opener: SystemUriOpener;
  dataExecutor?: DataTaskExecutor;
  writer?: UiSurfaceWriter;
  onSurface?: HotelSurfaceCallback;
  bus?: LinkedMessageBus;
  conversationId?: string;
}

export interface HotelActionContext {
  conversationId: string;
  turnId: string;
  surfaceId: string;
  sourceToolId: string;
}

interface PendingTurn {
  inputTaskId: string;
  resolve: (ok: boolean) => void;
}

interface PendingAction {
  resolve: (ok: boolean) => void;
}

interface HotelActionStatusRecord {
  actionId?: string;
  status?: string;
  message?: string;
  errorCode?: string;
}

interface HotelStatusSummary {
  text: string;
  toolName: string;
  dataLabel: string;
  count: number;
}

class MonotonicHotelIds implements HotelPlannerIdFactory, HotelActionIdFactory {
  private next: number = 0;

  nextId(prefix: string): string {
    this.next += 1;
    return prefix + '-' + this.next.toString();
  }
}

class CurrentHotelToolLookup implements ToolDefinitionLookup {
  find(toolId: string): ToolDefinition | null {
    return toolDefinitionForToolId(toolId);
  }
}

class RejectHotelClientAction implements ClientActionAuthorizer {
  allows(_actionId: string, _args: Object): boolean {
    return false;
  }
}

class CurrentHotelArgsValidator implements ActionArgsValidator {
  validate(actionId: string, args: Object): ActionValidationResult {
    return validateHotelActionArgs(actionId, args);
  }
}

class StructuredHotelDataExecutor implements DataTaskExecutor {
  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    return callStructuredHotelTool(task.toolId, task.args);
  }
}

class IgnoreHotelSurfaceWriter implements UiSurfaceWriter {
  async write(
    _turnId: string,
    _surfaceId: string,
    _jsonl: string,
    _lease: UiSurfaceWriteLease
  ): Promise<void> {
  }
}

class HotelSurfaceAuthority implements SurfaceActionAuthorizer {
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
    document: HtmlHomeDocument
  ): void {
    this.conversationId = conversationId;
    this.turnId = turnId;
    this.surfaceId = surfaceId;
    this.sourceToolId = sourceToolId;
    this.allowed.clear();
    this.collect(document, document.actions);
    document.blocks.forEach((block) => {
      this.collect(document, block.actions);
    });
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
      if (candidate.id !== 'hotel.detail' &&
        candidate.id !== 'hotel.navigate' &&
        candidate.id !== 'hotel.call') {
        return;
      }
      const action: A2uiAction = {
        id: candidate.id,
        label: candidate.label,
        prompt: candidate.prompt,
        variant: candidate.variant,
        kind: candidate.kind
      };
      if (candidate.args !== undefined) {
        action.args = candidate.args;
      }
      if (action.args !== undefined && isHtmlHomeActionAllowed(document, action)) {
        this.allowed.add(this.actionKey(action.id, action.args));
      }
    });
  }

  private actionKey(actionId: string, args: Object): string {
    return actionId + '\n' + JSON.stringify(args);
  }
}

class HotelUiRenderer implements UiTaskRenderer {
  private readonly catalog: ActionCatalog;

  constructor(catalog: ActionCatalog) {
    this.catalog = catalog;
  }

  async skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult> {
    const prompt = task.intent === 'hotel.detail' ?
      '正在等待 RollingGo 返回实时房型、价格与取消政策。' :
      '正在等待 RollingGo 返回真实酒店与报价。';
    return this.rendered(hotelPendingA2ui(surfaceId, prompt));
  }

  async result(
    _task: CreateUiTaskPayload,
    data: DataResult,
    surfaceId: string
  ): Promise<UiRenderResult> {
    if (data.toolId === 'hotel.search') {
      const canPlace = (action: A2uiAction): boolean => {
        return action.args !== undefined &&
          this.catalog.validatePlacement('hotel.search', action.id, action.args).ok;
      };
      return this.rendered(
        hotelSearchA2ui(surfaceId, data.data as HotelSearchResult, canPlace)
      );
    }
    if (data.toolId === 'hotel.detail') {
      return this.rendered(hotelDetailA2ui(surfaceId, data.data as HotelDetailResult));
    }
    return this.rendered(hotelFailureA2ui(surfaceId, data.toolId, 'Unsupported hotel data result.'));
  }

  async error(
    task: CreateUiTaskPayload,
    message: string,
    surfaceId: string
  ): Promise<UiRenderResult> {
    return this.rendered(hotelFailureA2ui(surfaceId, task.intent, message));
  }

  async actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult> {
    const status = payload as HotelActionStatusRecord;
    let text = '酒店操作状态已更新。';
    if (status.status === 'running') {
      text = '正在打开系统酒店操作。';
    } else if (status.status === 'success') {
      text = '系统酒店操作已打开。';
    } else if (status.status === 'error') {
      text = status.message === undefined || status.message.length === 0 ?
        '系统酒店操作失败。' : status.message;
    }
    const summary: HotelStatusSummary = {
      text: text,
      toolName: status.actionId === undefined ? 'hotel.action' : status.actionId,
      dataLabel: 'actionStatus',
      count: 0
    };
    const envelope: A2uiEnvelope = {
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/summary',
        value: summary
      }
    };
    return this.rendered(JSON.stringify(envelope));
  }

  private rendered(jsonl: string): UiRenderResult {
    return { jsonl: jsonl, proposals: [] };
  }
}

class HotelRuntimeSurfaceWriter implements UiSurfaceWriter {
  private readonly conversationId: string;
  private readonly downstream: UiSurfaceWriter;
  private readonly callback: HotelSurfaceCallback | null;
  private readonly authority: HotelSurfaceAuthority;
  private readonly stores: Map<string, A2uiSurfaceStore> = new Map<string, A2uiSurfaceStore>();
  private readonly sourceTools: Map<string, string> = new Map<string, string>();
  private activeSurfaceId: string = '';
  private searchSurface: A2uiSurfaceState | null = null;

  constructor(
    conversationId: string,
    downstream: UiSurfaceWriter,
    callback: HotelSurfaceCallback | null,
    authority: HotelSurfaceAuthority
  ) {
    this.conversationId = conversationId;
    this.downstream = downstream;
    this.callback = callback;
    this.authority = authority;
  }

  async write(
    turnId: string,
    surfaceId: string,
    jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void> {
    const parsed = parseA2uiJsonl(jsonl);
    if (parsed.error.length > 0) {
      throw new Error(parsed.error);
    }
    let store = this.stores.get(surfaceId);
    if (store === undefined) {
      store = new A2uiSurfaceStore();
      this.stores.set(surfaceId, store);
    }
    let created = false;
    parsed.envelopes.forEach((envelope: A2uiEnvelope) => {
      created = created || envelope.createSurface !== undefined;
      const applied: A2uiApplyResult = (store as A2uiSurfaceStore).apply(envelope);
      if (!applied.ok) {
        throw new Error(applied.error);
      }
    });
    await this.downstream.write(turnId, surfaceId, jsonl, lease);
    if (!lease.isActive()) {
      return;
    }
    if (created) {
      this.activeSurfaceId = surfaceId;
    }
    if (this.activeSurfaceId !== surfaceId) {
      return;
    }
    const surface = (store as A2uiSurfaceStore).getSurface();
    const document = createHtmlHomeDocument({
      surface: surface,
      messages: [],
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    const detectedSourceToolId = this.sourceToolId(surface);
    if (detectedSourceToolId === 'hotel.search' || detectedSourceToolId === 'hotel.detail') {
      this.sourceTools.set(surfaceId, detectedSourceToolId);
    }
    const storedSourceToolId = this.sourceTools.get(surfaceId);
    const sourceToolId = storedSourceToolId === undefined ? '' : storedSourceToolId;
    this.authority.activate(
      this.conversationId,
      turnId,
      surfaceId,
      sourceToolId,
      document
    );
    if (sourceToolId === 'hotel.search' && surface.status === 'ready') {
      this.searchSurface = surface;
    }
    if (this.callback !== null) {
      this.callback(surface);
    }
  }

  searchReturnSurface(): A2uiSurfaceState | null {
    return this.searchSurface;
  }

  private sourceToolId(surface: A2uiSurfaceState): string {
    try {
      const model = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
      return model.summary.toolName.indexOf('hotel.') === 0 ? model.summary.toolName : '';
    } catch (_error) {
      return '';
    }
  }
}

export class HotelAgentRuntime {
  private readonly bus: LinkedMessageBus;
  private readonly reader: AgentMessageReader;
  private readonly conversationId: string;
  private readonly ids: MonotonicHotelIds;
  private readonly leader: LeaderAgent;
  private readonly data: DataAgent;
  private readonly ui: UiAgent;
  private readonly action: ActionAgent;
  private readonly catalog: ActionCatalog;
  private readonly authority: HotelSurfaceAuthority;
  private readonly surfaceWriter: HotelRuntimeSurfaceWriter;
  private readonly pendingTurns: Map<string, PendingTurn> = new Map<string, PendingTurn>();
  private readonly pendingActions: Map<string, PendingAction> = new Map<string, PendingAction>();
  private active: boolean = true;

  constructor(options: HotelAgentRuntimeOptions) {
    this.bus = options.bus === undefined ? new LinkedMessageBus() : options.bus;
    this.ids = new MonotonicHotelIds();
    this.conversationId = options.conversationId === undefined || options.conversationId.length === 0 ?
      'hotel-page-' + Date.now().toString() : options.conversationId;
    this.authority = new HotelSurfaceAuthority();
    this.catalog = new ActionCatalog(
      new CurrentHotelToolLookup(),
      this.authority,
      new RejectHotelClientAction(),
      new CurrentHotelArgsValidator()
    );
    const downstream = options.writer === undefined ?
      new IgnoreHotelSurfaceWriter() : options.writer;
    this.surfaceWriter = new HotelRuntimeSurfaceWriter(
      this.conversationId,
      downstream,
      options.onSurface === undefined ? null : options.onSurface,
      this.authority
    );
    const planner = new HotelLeaderPlanner(options.model, options.currentLocalDate, this.ids);
    const executor = options.dataExecutor === undefined ?
      new StructuredHotelDataExecutor() : options.dataExecutor;
    const renderer = new HotelUiRenderer(this.catalog);
    const registered = new HotelRegisteredActionExecutor(this.catalog, options.opener, this.ids);
    this.leader = new LeaderAgent(this.bus, planner);
    this.data = new DataAgent(this.bus, executor);
    this.ui = new UiAgent(this.bus, renderer, this.surfaceWriter);
    this.action = new ActionAgent(this.bus, this.catalog, registered);
    this.reader = this.bus.openReader();
    this.leader.start();
    this.data.start();
    this.ui.start();
    this.action.start();
    this.observe();
  }

  submit(prompt: string): Promise<boolean> {
    const text = prompt.trim();
    if (!this.active || text.length === 0) {
      return Promise.resolve(false);
    }
    const turnId = this.ids.nextId('hotel-turn');
    const taskId = this.ids.nextId('hotel-input');
    return new Promise<boolean>((resolve: (ok: boolean) => void) => {
      const pending: PendingTurn = { inputTaskId: taskId, resolve: resolve };
      const payload: UserInputPayload = { text: text };
      const message: AgentMessage = {
        type: AgentMessageType.INPUT_USER,
        conversationId: this.conversationId,
        turnId: turnId,
        taskId: taskId,
        payload: payload
      };
      this.pendingTurns.set(turnId, pending);
      this.bus.publish(message);
    });
  }

  currentActionContext(): HotelActionContext | null {
    return this.authority.context();
  }

  runAction(action: A2uiAction, suppliedContext?: HotelActionContext): Promise<boolean> {
    if (!this.active || action.args === undefined) {
      return Promise.resolve(false);
    }
    const context = suppliedContext === undefined ? this.authority.context() : suppliedContext;
    if (context === null || context.conversationId !== this.conversationId) {
      return Promise.resolve(false);
    }
    const current = this.catalog.validateSurfaceExecution(
      context.conversationId,
      context.turnId,
      context.surfaceId,
      context.sourceToolId,
      action.id,
      action.args
    );
    if (!current.ok) {
      return Promise.resolve(false);
    }
    const runId = this.ids.nextId('hotel-action-run');
    const taskId = this.ids.nextId('hotel-action-task');
    const payload: ActionRunPayload = {
      surfaceId: context.surfaceId,
      runId: runId,
      sourceToolId: context.sourceToolId,
      actionId: action.id,
      args: action.args
    };
    return new Promise<boolean>((resolve: (ok: boolean) => void) => {
      this.pendingActions.set(taskId, { resolve: resolve });
      this.bus.publish({
        type: AgentMessageType.ACTION_RUN,
        conversationId: context.conversationId,
        turnId: context.turnId,
        taskId: taskId,
        payload: payload
      });
    });
  }

  searchReturnSurface(): A2uiSurfaceState | null {
    return this.surfaceWriter.searchReturnSurface();
  }

  stop(): void {
    if (!this.active) {
      return;
    }
    this.active = false;
    this.reader.close();
    this.leader.stop();
    this.data.stop();
    this.ui.stop();
    this.action.stop();
    this.pendingTurns.forEach((pending: PendingTurn) => pending.resolve(false));
    this.pendingActions.forEach((pending: PendingAction) => pending.resolve(false));
    this.pendingTurns.clear();
    this.pendingActions.clear();
  }

  private async observe(): Promise<void> {
    while (this.active) {
      const message = await this.reader.receive();
      if (message === null || !this.active) {
        return;
      }
      this.observeMessage(message);
    }
  }

  private observeMessage(message: AgentMessage): void {
    if (message.type === AgentMessageType.TASK_RESULT_UI) {
      const pending = this.pendingTurns.get(message.turnId);
      const result = message.payload as UiRenderResultPayload;
      if (pending !== undefined && (result.state === 'result' || result.state === 'error')) {
        this.pendingTurns.delete(message.turnId);
        pending.resolve(true);
      }
      return;
    }
    if (message.type === AgentMessageType.TASK_ERROR) {
      const pending = this.pendingTurns.get(message.turnId);
      if (pending !== undefined && message.taskId === pending.inputTaskId) {
        this.pendingTurns.delete(message.turnId);
        pending.resolve(false);
      }
      return;
    }
    if (message.type === AgentMessageType.ACTION_RESULT) {
      const pending = this.pendingActions.get(message.taskId);
      if (pending === undefined) {
        return;
      }
      const result = message.payload as HotelActionStatusRecord;
      this.pendingActions.delete(message.taskId);
      pending.resolve(result.status === 'success');
    }
  }
}
