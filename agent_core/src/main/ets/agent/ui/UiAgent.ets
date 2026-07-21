import { newSurfaceId } from '../../a2ui/A2uiProtocol';
import {
  ActionPlanReadyPayload,
  WorkflowRunArgs
} from '../action/ActionAgentTypes';
import { ActionOffer, ActionOffersReadyPayload } from '../action/ActionOfferTypes';
import { JsonValue } from '../action/ActionPlanTypes';
import { cloneJsonValue } from '../action/JsonPointer';
import { MessageDrivenAgent } from '../MessageDrivenAgent';
import {
  AgentMessage,
  AgentMessageType,
  TaskErrorPayload
} from '../message/AgentMessage';
import { DataResult } from '../message/DataResult';
import { LinkedMessageBus } from '../message/LinkedMessageBus';
import {
  CreateUiTaskPayload,
  UiRenderResult,
  UiRenderResultPayload,
  UiRenderState,
  UiSurfaceWriteLease,
  UiSurfaceWriter,
  UiTaskRenderer
} from './UiAgentTypes';

// Retain only recent terminal turn identities; older provider payloads are never retained.
const TERMINATED_TURN_LIMIT: number = 128;
// Retain only a tiny pre-UI window, keyed by exact Data task ownership.
const PENDING_DATA_LIMIT: number = 5;
const WORKFLOW_RUN_ACTION_ID: string = 'workflow.run';

function containsWorkflowRun(value: JsonValue): boolean {
  if (typeof value === 'string') {
    return value === WORKFLOW_RUN_ACTION_ID;
  }
  if (value === null || typeof value !== 'object') {
    return false;
  }
  if (Array.isArray(value)) {
    const items = value as JsonValue[];
    for (let index = 0; index < items.length; index++) {
      if (containsWorkflowRun(items[index])) {
        return true;
      }
    }
    return false;
  }
  const record = value as Record<string, JsonValue | undefined>;
  const keys = Object.keys(value);
  for (let index = 0; index < keys.length; index++) {
    const nested = record[keys[index]];
    if (nested !== undefined && containsWorkflowRun(nested)) {
      return true;
    }
  }
  return false;
}

interface PendingDataEntry {
  data?: DataResult;
  offers?: ActionOffer[];
  offerSourceToolId?: string;
  invalidCode: string;
  invalidMessage: string;
}

interface UiTurnContext {
  conversationId: string;
  turnId: string;
  surfaceId: string;
  uiTaskId: string;
  uiTask?: CreateUiTaskPayload;
  pendingDataByTaskId: Map<string, PendingDataEntry>;
  pendingDataOrder: string[];
  dataErrorPending: boolean;
  canceled: boolean;
  generation: number;
  skeletonWritten: boolean;
  resultWritten: boolean;
  terminalRenderStarted: boolean;
  operationChain: Promise<void>;
  queuedMessages: Map<number, AgentMessage>;
  nextOperationId: number;
}

class ContextSurfaceWriteLease implements UiSurfaceWriteLease {
  private readonly context: UiTurnContext;
  private readonly generation: number;

  constructor(context: UiTurnContext) {
    this.context = context;
    this.generation = context.generation;
  }

  isActive(): boolean {
    return !this.context.canceled && this.context.generation === this.generation;
  }
}

export class UiAgent extends MessageDrivenAgent {
  private readonly bus: LinkedMessageBus;
  private readonly renderer: UiTaskRenderer;
  private readonly writer: UiSurfaceWriter;
  private readonly contexts: Map<string, UiTurnContext> = new Map<string, UiTurnContext>();
  private readonly terminated: Set<string> = new Set<string>();
  private readonly terminatedOrder: string[] = [];
  private surfaceSuffix: number = 0;

  constructor(bus: LinkedMessageBus, renderer: UiTaskRenderer, writer: UiSurfaceWriter) {
    super(bus);
    this.bus = bus;
    this.renderer = renderer;
    this.writer = writer;
  }

  stop(): void {
    super.stop();
    this.contexts.forEach((context: UiTurnContext) => {
      this.invalidateContext(context);
    });
    this.contexts.clear();
    this.terminated.clear();
    this.terminatedOrder.splice(0, this.terminatedOrder.length);
  }

  surfaceReplaced(conversationId: string, turnId: string, surfaceId: string): void {
    const key: string = this.turnKey(conversationId, turnId);
    const context: UiTurnContext | undefined = this.contexts.get(key);
    if (context === undefined || context.surfaceId !== surfaceId) {
      return;
    }
    this.invalidateContext(context);
    this.terminate(key);
    this.contexts.delete(key);
  }

  protected accepts(message: AgentMessage): boolean {
    return message.type === AgentMessageType.TASK_CREATE_UI ||
      message.type === AgentMessageType.TASK_RESULT_DATA ||
      message.type === AgentMessageType.ACTION_OFFERS_READY ||
      message.type === AgentMessageType.TASK_ERROR ||
      message.type === AgentMessageType.ACTION_PLAN_READY ||
      message.type === AgentMessageType.ACTION_PROGRESS ||
      message.type === AgentMessageType.ACTION_RESULT ||
      message.type === AgentMessageType.TURN_CANCEL;
  }

  protected async process(message: AgentMessage): Promise<void> {
    const key: string = this.turnKey(message.conversationId, message.turnId);
    if (message.type === AgentMessageType.TURN_CANCEL) {
      const context: UiTurnContext | undefined = this.contexts.get(key);
      if (context !== undefined) {
        this.invalidateContext(context);
      }
      this.terminate(key);
      this.contexts.delete(key);
      return;
    }
    if (this.terminated.has(key)) {
      return;
    }
    if (message.type === AgentMessageType.TASK_CREATE_UI) {
      const task: CreateUiTaskPayload | null = this.uiTask(message.payload, message.taskId);
      if (task === null) {
        this.publishInputError(message, 'UI_TASK_INVALID', 'UI task payload is malformed');
        return;
      }
      const context: UiTurnContext = this.contextFor(message, key);
      this.enqueue(message, key, context);
      return;
    }
    if (message.type === AgentMessageType.TASK_RESULT_DATA ||
      message.type === AgentMessageType.ACTION_OFFERS_READY) {
      const current: UiTurnContext | undefined = this.contexts.get(key);
      const context: UiTurnContext = current === undefined ? this.contextFor(message, key) : current;
      this.enqueue(message, key, context);
      return;
    }
    if (message.type === AgentMessageType.TASK_ERROR) {
      const context: UiTurnContext | undefined = this.contexts.get(key);
      if (context !== undefined) {
        this.enqueue(message, key, context);
      }
      return;
    }
    const context: UiTurnContext | undefined = this.contexts.get(key);
    if (context !== undefined) {
      this.enqueue(message, key, context);
    }
  }

  private enqueue(message: AgentMessage, key: string, context: UiTurnContext): void {
    const operationId: number = context.nextOperationId;
    context.nextOperationId++;
    context.queuedMessages.set(operationId, message);
    context.operationChain = context.operationChain.then(async () => {
      const queued: AgentMessage | undefined = context.queuedMessages.get(operationId);
      context.queuedMessages.delete(operationId);
      if (queued === undefined || !this.isActive(key, context)) {
        return;
      }
      try {
        await this.runOperation(queued, key, context);
      } catch (error) {
        this.failRender(queued, key, context, error as Object);
      }
    });
  }

  private async runOperation(
    message: AgentMessage,
    key: string,
    context: UiTurnContext
  ): Promise<void> {
    if (message.type === AgentMessageType.TASK_CREATE_UI) {
      const task: CreateUiTaskPayload | null = this.uiTask(message.payload, message.taskId);
      if (task !== null) {
        await this.handleUiTask(message, task, key, context);
      }
      return;
    }
    if (message.type === AgentMessageType.TASK_RESULT_DATA) {
      await this.handleDataResult(message, key, context);
      return;
    }
    if (message.type === AgentMessageType.ACTION_OFFERS_READY) {
      await this.handleOffersReady(message, key, context);
      return;
    }
    if (message.type === AgentMessageType.TASK_ERROR) {
      await this.handleTaskError(message, key, context);
      return;
    }
    await this.handleActionStatus(message, key, context);
  }

  private async handleUiTask(
    message: AgentMessage,
    task: CreateUiTaskPayload,
    key: string,
    context: UiTurnContext
  ): Promise<void> {
    if (context.canceled || context.skeletonWritten || context.uiTask !== undefined) {
      return;
    }
    context.uiTask = task;
    context.uiTaskId = message.taskId;
    const rendered: UiRenderResult = await this.renderer.skeleton(task, context.surfaceId);
    if (!this.isActive(key, context)) {
      return;
    }
    this.validateRenderedJsonl(rendered, false);
    await this.writer.write(
      context.turnId,
      context.surfaceId,
      rendered.jsonl,
      new ContextSurfaceWriteLease(context)
    );
    if (!this.isActive(key, context)) {
      return;
    }
    context.skeletonWritten = true;
    this.publishUiResult(context, 'skeleton');
    const pending: PendingDataEntry | undefined = context.pendingDataByTaskId.get(task.dataTaskIds[0]);
    if (pending !== undefined && pending.invalidCode.length > 0) {
      this.publishOwnedDataError(context, pending.invalidCode, pending.invalidMessage);
      return;
    }
    await this.maybeRenderData(context, key);
  }

  private async handleDataResult(message: AgentMessage, key: string, context: UiTurnContext): Promise<void> {
    if (context.uiTask !== undefined && message.taskId !== context.uiTask.dataTaskIds[0]) {
      return;
    }
    if (context.canceled || context.resultWritten || context.terminalRenderStarted ||
      context.dataErrorPending) {
      return;
    }
    const data: DataResult | null = this.dataResult(message.payload);
    if (data === null) {
      this.rememberPendingInvalidData(
        context,
        message.taskId,
        'UI_DATA_INVALID',
        'Data result payload is malformed'
      );
      if (context.uiTask !== undefined) {
        this.publishOwnedDataError(context, 'UI_DATA_INVALID', 'Data result payload is malformed');
      }
      return;
    }
    if (context.uiTask !== undefined && data.outputSchema !== context.uiTask.expectedOutputSchema) {
      this.publishOwnedDataError(context, 'UI_DATA_SCHEMA_MISMATCH', 'Data result schema does not match UI task');
      return;
    }
    this.rememberPendingData(context, message.taskId, data);
    await this.maybeRenderData(context, key);
  }

  private async handleOffersReady(
    message: AgentMessage,
    key: string,
    context: UiTurnContext
  ): Promise<void> {
    if (context.uiTask !== undefined && message.taskId !== context.uiTask.dataTaskIds[0]) {
      return;
    }
    const ready = this.offersReady(message.payload, message.taskId);
    if (ready === null) {
      return;
    }
    this.rememberPendingOffers(
      context,
      message.taskId,
      ready.sourceToolId,
      ready.offers
    );
    await this.maybeRenderData(context, key);
  }

  private async maybeRenderData(context: UiTurnContext, key: string): Promise<void> {
    const task = context.uiTask;
    if (task === undefined || !context.skeletonWritten) {
      return;
    }
    const pending = context.pendingDataByTaskId.get(task.dataTaskIds[0]);
    if (pending === undefined || pending.data === undefined || pending.offers === undefined ||
      pending.offerSourceToolId !== pending.data.toolId) {
      return;
    }
    await this.renderData(context, key, pending.data, pending.offers);
  }

  private async renderData(
    context: UiTurnContext,
    key: string,
    data: DataResult,
    offers: ActionOffer[]
  ): Promise<void> {
    const task: CreateUiTaskPayload | undefined = context.uiTask;
    if (task === undefined || !context.skeletonWritten || context.resultWritten ||
      context.terminalRenderStarted) {
      return;
    }
    if (data.outputSchema !== task.expectedOutputSchema) {
      this.publishOwnedDataError(context, 'UI_DATA_SCHEMA_MISMATCH', 'Data result schema does not match UI task');
      return;
    }
    context.terminalRenderStarted = true;
    const rendered: UiRenderResult =
      await this.renderer.result(task, data, offers, context.surfaceId);
    if (!this.isActive(key, context)) {
      return;
    }
    this.validateRenderedJsonl(rendered, false);
    await this.writer.write(
      context.turnId,
      context.surfaceId,
      rendered.jsonl,
      new ContextSurfaceWriteLease(context)
    );
    if (!this.isActive(key, context)) {
      return;
    }
    context.resultWritten = true;
    this.publishUiResult(context, 'result');
    this.clearPendingPayloads(context);
  }

  private async handleTaskError(message: AgentMessage, key: string, context: UiTurnContext): Promise<void> {
    if (context.canceled || context.resultWritten ||
      context.terminalRenderStarted || context.uiTask === undefined ||
      message.taskId !== context.uiTask.dataTaskIds[0]) {
      return;
    }
    const errorMessage: string | null = this.taskErrorMessage(message.payload);
    if (errorMessage === null) {
      this.publishOwnedDataError(context, 'UI_DATA_ERROR_INVALID', 'Data error payload is malformed');
      return;
    }
    context.dataErrorPending = false;
    await this.renderDataError(context, key, errorMessage);
  }

  private async renderDataError(context: UiTurnContext, key: string, message: string): Promise<void> {
    if (context.uiTask === undefined || context.resultWritten || context.terminalRenderStarted) {
      return;
    }
    context.terminalRenderStarted = true;
    const rendered: UiRenderResult =
      await this.renderer.error(context.uiTask, message, context.surfaceId);
    if (!this.isActive(key, context)) {
      return;
    }
    this.validateRenderedJsonl(rendered, false);
    await this.writer.write(
      context.turnId,
      context.surfaceId,
      rendered.jsonl,
      new ContextSurfaceWriteLease(context)
    );
    if (!this.isActive(key, context)) {
      return;
    }
    context.resultWritten = true;
    this.publishUiResult(context, 'error');
    this.clearPendingPayloads(context);
  }

  private async handleActionStatus(message: AgentMessage, key: string, context: UiTurnContext): Promise<void> {
    if (context.canceled || !context.skeletonWritten ||
      this.payloadSurfaceId(message.payload) !== context.surfaceId) {
      return;
    }
    let ready: ActionPlanReadyPayload | null = null;
    if (message.type === AgentMessageType.ACTION_PLAN_READY) {
      ready = this.actionPlanReady(message, context);
      if (ready === null) {
        return;
      }
    }
    const statusPayload: Object = ready === null ? message.payload : ready;
    const rendered: UiRenderResult =
      await this.renderer.actionStatus(statusPayload, context.surfaceId);
    if (!this.isActive(key, context)) {
      return;
    }
    this.validateRenderedJsonl(rendered, ready !== null);
    await this.writer.write(
      context.turnId,
      context.surfaceId,
      rendered.jsonl,
      new ContextSurfaceWriteLease(context)
    );
    if (!this.isActive(key, context)) {
      return;
    }
    this.publishUiResult(context, 'action');
  }

  private rememberPendingData(context: UiTurnContext, taskId: string, data: DataResult): void {
    const current: PendingDataEntry | undefined = context.pendingDataByTaskId.get(taskId);
    const entry: PendingDataEntry = {
      data,
      offers: current === undefined ? undefined : current.offers,
      offerSourceToolId: current === undefined ? undefined : current.offerSourceToolId,
      invalidCode: '',
      invalidMessage: ''
    };
    this.rememberPendingEntry(context, taskId, entry);
  }

  private rememberPendingInvalidData(
    context: UiTurnContext,
    taskId: string,
    code: string,
    message: string
  ): void {
    const current: PendingDataEntry | undefined = context.pendingDataByTaskId.get(taskId);
    if (current !== undefined && current.data !== undefined) {
      return;
    }
    const entry: PendingDataEntry = {
      offers: current === undefined ? undefined : current.offers,
      offerSourceToolId: current === undefined ? undefined : current.offerSourceToolId,
      invalidCode: code,
      invalidMessage: message
    };
    this.rememberPendingEntry(context, taskId, entry);
  }

  private rememberPendingOffers(
    context: UiTurnContext,
    taskId: string,
    sourceToolId: string,
    offers: ActionOffer[]
  ): void {
    const current: PendingDataEntry | undefined = context.pendingDataByTaskId.get(taskId);
    const entry: PendingDataEntry = {
      data: current === undefined ? undefined : current.data,
      offers: offers.slice(),
      offerSourceToolId: sourceToolId,
      invalidCode: current === undefined ? '' : current.invalidCode,
      invalidMessage: current === undefined ? '' : current.invalidMessage
    };
    this.rememberPendingEntry(context, taskId, entry);
  }

  private rememberPendingEntry(context: UiTurnContext, taskId: string, entry: PendingDataEntry): void {
    if (!context.pendingDataByTaskId.has(taskId)) {
      context.pendingDataOrder.push(taskId);
    }
    context.pendingDataByTaskId.set(taskId, entry);
    while (context.pendingDataOrder.length > PENDING_DATA_LIMIT) {
      const oldest: string | undefined = context.pendingDataOrder.shift();
      if (oldest !== undefined) {
        context.pendingDataByTaskId.delete(oldest);
      }
    }
  }

  private publishOwnedDataError(context: UiTurnContext, code: string, message: string): void {
    const task: CreateUiTaskPayload | undefined = context.uiTask;
    if (task === undefined || context.dataErrorPending) {
      return;
    }
    context.dataErrorPending = true;
    const payload: TaskErrorPayload = { code, message };
    this.bus.publish({
      type: AgentMessageType.TASK_ERROR,
      conversationId: context.conversationId,
      turnId: context.turnId,
      taskId: task.dataTaskIds[0],
      payload
    });
  }

  private contextFor(message: AgentMessage, key: string): UiTurnContext {
    const current: UiTurnContext | undefined = this.contexts.get(key);
    if (current !== undefined) {
      return current;
    }
    const created: UiTurnContext = {
      conversationId: message.conversationId,
      turnId: message.turnId,
      surfaceId: this.uniqueSurfaceId(),
      uiTaskId: '',
      pendingDataByTaskId: new Map<string, PendingDataEntry>(),
      pendingDataOrder: [],
      dataErrorPending: false,
      canceled: false,
      generation: 0,
      skeletonWritten: false,
      resultWritten: false,
      terminalRenderStarted: false,
      operationChain: Promise.resolve(),
      queuedMessages: new Map<number, AgentMessage>(),
      nextOperationId: 0
    };
    this.contexts.set(key, created);
    return created;
  }

  private isActive(key: string, context: UiTurnContext): boolean {
    return !context.canceled && !this.terminated.has(key) && this.contexts.get(key) === context;
  }

  private terminate(key: string): void {
    if (this.terminated.has(key)) {
      return;
    }
    this.terminated.add(key);
    this.terminatedOrder.push(key);
    if (this.terminatedOrder.length > TERMINATED_TURN_LIMIT) {
      const oldest: string | undefined = this.terminatedOrder.shift();
      if (oldest !== undefined) {
        this.terminated.delete(oldest);
      }
    }
  }

  private uniqueSurfaceId(): string {
    const base: string = newSurfaceId();
    let candidate: string = base;
    while (this.surfaceInUse(candidate)) {
      this.surfaceSuffix++;
      candidate = `${base}_${this.surfaceSuffix}`;
    }
    return candidate;
  }

  private surfaceInUse(surfaceId: string): boolean {
    let found: boolean = false;
    this.contexts.forEach((context: UiTurnContext) => {
      if (context.surfaceId === surfaceId) {
        found = true;
      }
    });
    return found;
  }

  private uiTask(payload: Object, taskId: string): CreateUiTaskPayload | null {
    if (payload === null || typeof payload !== 'object') {
      return null;
    }
    const values = payload as Record<string, Object | string | number | boolean | null | undefined>;
    const payloadTaskId = values['taskId'];
    const dataTaskIds = values['dataTaskIds'];
    const skillId = values['skillId'];
    const intent = values['intent'];
    const expectedOutputSchema = values['expectedOutputSchema'];
    if (typeof payloadTaskId !== 'string' || payloadTaskId !== taskId ||
      !Array.isArray(dataTaskIds) || dataTaskIds.length !== 1 ||
      typeof dataTaskIds[0] !== 'string' || dataTaskIds[0].trim().length === 0 || dataTaskIds[0] === taskId ||
      typeof skillId !== 'string' ||
      typeof intent !== 'string' || intent.trim().length === 0 ||
      typeof expectedOutputSchema !== 'string' || expectedOutputSchema.trim().length === 0) {
      return null;
    }
    return payload as CreateUiTaskPayload;
  }

  private offersReady(payload: Object, taskId: string): ActionOffersReadyPayload | null {
    if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
      return null;
    }
    const ready = payload as ActionOffersReadyPayload;
    if (Object.keys(payload).sort().join(',') !== 'dataTaskId,offers,sourceToolId' ||
      ready.dataTaskId !== taskId || typeof ready.sourceToolId !== 'string' ||
      ready.sourceToolId.trim().length === 0 || !Array.isArray(ready.offers)) {
      return null;
    }
    const cloned = cloneJsonValue(ready.offers as Object);
    if (!cloned.ok || !Array.isArray(cloned.value)) {
      return null;
    }
    const offers = cloned.value as ActionOffer[];
    for (let index = 0; index < offers.length; index++) {
      const offer = offers[index];
      if (offer === null || typeof offer !== 'object' ||
        Object.keys(offer).sort().join(',') !== 'actionId,args,label,offerId,variant' ||
        typeof offer.offerId !== 'string' || offer.offerId.trim().length === 0 ||
        typeof offer.actionId !== 'string' || offer.actionId.trim().length === 0 ||
        typeof offer.label !== 'string' || offer.label.trim().length === 0 ||
        typeof offer.variant !== 'string' || offer.variant.trim().length === 0 ||
        offer.args === null || typeof offer.args !== 'object' || Array.isArray(offer.args)) {
        return null;
      }
    }
    return {
      dataTaskId: ready.dataTaskId,
      sourceToolId: ready.sourceToolId,
      offers
    };
  }

  private dataResult(payload: Object): DataResult | null {
    if (payload === null || typeof payload !== 'object') {
      return null;
    }
    const values = payload as Record<string, Object | string | number | boolean | null | undefined>;
    const toolId = values['toolId'];
    const outputSchema = values['outputSchema'];
    const status = values['status'];
    const sources = values['sources'];
    const data = values['data'];
    const warnings = values['warnings'];
    const validStatus: boolean = status === 'success' || status === 'partial' ||
      status === 'empty' || status === 'error';
    if (typeof toolId !== 'string' || toolId.trim().length === 0 ||
      typeof outputSchema !== 'string' || outputSchema.trim().length === 0 ||
      !validStatus || !Array.isArray(sources) || data === null || typeof data !== 'object' ||
      !Array.isArray(warnings)) {
      return null;
    }
    return payload as DataResult;
  }

  private taskErrorMessage(payload: Object): string | null {
    if (payload === null || typeof payload !== 'object') {
      return null;
    }
    const values = payload as Record<string, Object | string | number | boolean | null | undefined>;
    const message = values['message'];
    return typeof message === 'string' && message.trim().length > 0 ? message : null;
  }

  private payloadSurfaceId(payload: Object): string {
    if (payload === null || typeof payload !== 'object') {
      return '';
    }
    const values = payload as Record<string, Object | string | number | boolean | null | undefined>;
    const surfaceId: Object | string | number | boolean | null | undefined = values['surfaceId'];
    return typeof surfaceId === 'string' ? surfaceId : '';
  }

  private publishUiResult(context: UiTurnContext, state: UiRenderState): void {
    const payload: UiRenderResultPayload = {
      surfaceId: context.surfaceId,
      state
    };
    this.bus.publish({
      type: AgentMessageType.TASK_RESULT_UI,
      conversationId: context.conversationId,
      turnId: context.turnId,
      taskId: context.uiTaskId,
      payload
    });
  }

  private publishInputError(message: AgentMessage, code: string, detail: string): void {
    const payload: TaskErrorPayload = {
      code,
      message: detail
    };
    this.bus.publish({
      type: AgentMessageType.TASK_ERROR,
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: message.taskId,
      payload
    });
  }

  private failRender(message: AgentMessage, key: string, context: UiTurnContext, error: Object): void {
    if (!this.isActive(key, context)) {
      return;
    }
    this.invalidateContext(context);
    this.terminate(key);
    this.contexts.delete(key);
    this.publishInputError(
      {
        type: message.type,
        conversationId: message.conversationId,
        turnId: message.turnId,
        taskId: context.uiTaskId.length === 0 ? message.taskId : context.uiTaskId,
        payload: message.payload
      },
      'UI_RENDER_FAILED',
      error instanceof Error ? error.message : `${error}`
    );
  }

  private clearPendingPayloads(context: UiTurnContext): void {
    context.uiTask = undefined;
    this.clearPendingData(context);
  }

  private clearPendingData(context: UiTurnContext): void {
    context.pendingDataByTaskId.clear();
    context.pendingDataOrder.splice(0, context.pendingDataOrder.length);
  }

  private invalidateContext(context: UiTurnContext): void {
    context.canceled = true;
    context.generation++;
    context.uiTask = undefined;
    this.clearPendingData(context);
    context.queuedMessages.clear();
  }

  private turnKey(conversationId: string, turnId: string): string {
    return `${conversationId.length}:${conversationId}${turnId}`;
  }

  private actionPlanReady(
    message: AgentMessage,
    context: UiTurnContext
  ): ActionPlanReadyPayload | null {
    if (message.payload === null || typeof message.payload !== 'object') {
      return null;
    }
    const ready = message.payload as ActionPlanReadyPayload;
    if (Object.keys(message.payload).sort().join(',') !==
      'actionId,args,label,planId,runId,surfaceId,uiTaskId') {
      return null;
    }
    if (ready.uiTaskId !== context.uiTaskId ||
      ready.planId.trim().length === 0 || ready.runId.trim().length === 0 ||
      ready.surfaceId !== context.surfaceId ||
      ready.actionId !== 'workflow.run' ||
      ready.label.trim().length === 0) {
      return null;
    }
    const args = ready.args as WorkflowRunArgs;
    if (args === null ||
      typeof args !== 'object' ||
      Array.isArray(args) ||
      Object.keys(args).sort().join(',') !== 'planId,runId' ||
      args.planId !== ready.planId ||
      args.runId !== ready.runId) {
      return null;
    }
    const safeArgs: WorkflowRunArgs = {
      planId: args.planId,
      runId: args.runId
    };
    return {
      uiTaskId: ready.uiTaskId,
      surfaceId: ready.surfaceId,
      planId: ready.planId,
      runId: ready.runId,
      label: ready.label,
      actionId: 'workflow.run',
      args: safeArgs
    };
  }

  private validateRenderedJsonl(
    rendered: UiRenderResult,
    allowWorkflowRun: boolean
  ): void {
    if (typeof rendered.jsonl !== 'string') {
      throw new Error('UI renderer JSONL is malformed');
    }
    const lines = rendered.jsonl.split('\n');
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index].trim();
      if (line.length === 0) {
        continue;
      }
      let parsed: JsonValue;
      try {
        parsed = JSON.parse(line) as JsonValue;
      } catch (_error) {
        throw new Error('UI renderer JSONL contains a malformed line');
      }
      if (!allowWorkflowRun && containsWorkflowRun(parsed)) {
        throw new Error('UI renderer exposed workflow.run before Action Plan READY');
      }
    }
  }

}
