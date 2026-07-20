import { newSurfaceId } from '../../a2ui/A2uiProtocol';
import {
  ActionPlanCreatePayload,
  ActionPlanReadyPayload,
  WorkflowRunArgs
} from '../action/ActionAgentTypes';
import { ActionPlan, JsonValue } from '../action/ActionPlanTypes';
import { StructuredMessageDrivenAgent } from '../StructuredMessageDrivenAgent';
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
const PENDING_PLAN_LIMIT: number = 5;
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
  invalidCode: string;
  invalidMessage: string;
}

interface PendingPlanCorrelation {
  planId: string;
  runId: string;
  surfaceId: string;
  taskId: string;
  label: string;
}

interface UiTurnContext {
  conversationId: string;
  turnId: string;
  surfaceId: string;
  uiTaskId: string;
  uiTask?: CreateUiTaskPayload;
  pendingDataByTaskId: Map<string, PendingDataEntry>;
  pendingDataOrder: string[];
  pendingPlans: Map<string, PendingPlanCorrelation>;
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

export class UiAgent extends StructuredMessageDrivenAgent {
  private readonly bus: LinkedMessageBus;
  private readonly renderer: UiTaskRenderer;
  private readonly writer: UiSurfaceWriter;
  private readonly contexts: Map<string, UiTurnContext> = new Map<string, UiTurnContext>();
  private readonly terminated: Set<string> = new Set<string>();
  private readonly terminatedOrder: string[] = [];
  private surfaceSuffix: number = 0;
  private actionRunSuffix: number = 0;

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
    if (message.type === AgentMessageType.TASK_RESULT_DATA) {
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
    const pending: PendingDataEntry | undefined = context.pendingDataByTaskId.get(task.dataTaskId);
    this.clearPendingData(context);
    if (pending !== undefined && pending.invalidCode.length > 0) {
      this.publishOwnedDataError(context, pending.invalidCode, pending.invalidMessage);
      return;
    }
    if (pending !== undefined && pending.data !== undefined) {
      await this.renderData(context, key, pending.data);
    }
  }

  private async handleDataResult(message: AgentMessage, key: string, context: UiTurnContext): Promise<void> {
    if (context.uiTask !== undefined && message.taskId !== context.uiTask.dataTaskId) {
      return;
    }
    if (context.canceled || context.resultWritten || context.terminalRenderStarted ||
      context.dataErrorPending) {
      return;
    }
    const data: DataResult | null = this.dataResult(message.payload);
    if (context.uiTask === undefined) {
      if (data === null) {
        this.rememberPendingInvalidData(
          context,
          message.taskId,
          'UI_DATA_INVALID',
          'Data result payload is malformed'
        );
      } else {
        this.rememberPendingData(context, message.taskId, data);
      }
      return;
    }
    if (data === null) {
      this.publishOwnedDataError(context, 'UI_DATA_INVALID', 'Data result payload is malformed');
      return;
    }
    if (data.outputSchema !== context.uiTask.expectedOutputSchema) {
      this.publishOwnedDataError(context, 'UI_DATA_SCHEMA_MISMATCH', 'Data result schema does not match UI task');
      return;
    }
    await this.renderData(context, key, data);
  }

  private async renderData(context: UiTurnContext, key: string, data: DataResult): Promise<void> {
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
      await this.renderer.result(task, data, context.surfaceId);
    if (!this.isActive(key, context)) {
      return;
    }
    this.validateRenderedJsonl(rendered, false);
    this.validateProposalCapacity(context, rendered.proposals);
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
    this.publishActionPlans(context, data.toolId, rendered.proposals);
    this.publishUiResult(context, 'result');
    this.clearPendingPayloads(context);
  }

  private async handleTaskError(message: AgentMessage, key: string, context: UiTurnContext): Promise<void> {
    if (context.canceled || context.resultWritten ||
      context.terminalRenderStarted || context.uiTask === undefined ||
      message.taskId !== context.uiTask.dataTaskId) {
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
    } else if (message.type === AgentMessageType.ACTION_RESULT) {
      this.clearTerminalPlanCorrelation(message, context);
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
    if (ready !== null) {
      context.pendingPlans.delete(ready.runId);
    }
    this.publishUiResult(context, 'action');
  }

  private rememberPendingData(context: UiTurnContext, taskId: string, data: DataResult): void {
    const entry: PendingDataEntry = {
      data,
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
      invalidCode: code,
      invalidMessage: message
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
      taskId: task.dataTaskId,
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
      pendingPlans: new Map<string, PendingPlanCorrelation>(),
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
    const dataTaskId = values['dataTaskId'];
    const intent = values['intent'];
    const expectedOutputSchema = values['expectedOutputSchema'];
    if (typeof payloadTaskId !== 'string' || payloadTaskId !== taskId ||
      typeof dataTaskId !== 'string' || dataTaskId.trim().length === 0 || dataTaskId === taskId ||
      typeof intent !== 'string' || intent.trim().length === 0 ||
      typeof expectedOutputSchema !== 'string' || expectedOutputSchema.trim().length === 0) {
      return null;
    }
    return payload as CreateUiTaskPayload;
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
    context.pendingPlans.clear();
  }

  private turnKey(conversationId: string, turnId: string): string {
    return `${conversationId.length}:${conversationId}${turnId}`;
  }

  private publishActionPlans(
    context: UiTurnContext,
    sourceToolId: string,
    proposals: ActionPlan[]
  ): void {
    this.validateProposalCapacity(context, proposals);
    for (let index = 0; index < proposals.length; index++) {
      const plan = proposals[index];
      this.actionRunSuffix++;
      const runId = `${plan.planId}:${this.actionRunSuffix}`;
      const taskId = `action-plan:${runId}`;
      const correlation: PendingPlanCorrelation = {
        planId: plan.planId,
        runId,
        surfaceId: context.surfaceId,
        taskId,
        label: plan.label
      };
      context.pendingPlans.set(runId, correlation);
      const payload: ActionPlanCreatePayload = {
        runId,
        sourceToolId,
        plan
      };
      this.bus.publish({
        type: AgentMessageType.ACTION_PLAN_CREATE,
        conversationId: context.conversationId,
        turnId: context.turnId,
        taskId,
        payload
      });
    }
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
      'actionId,args,label,planId,runId,surfaceId') {
      return null;
    }
    const correlation = context.pendingPlans.get(ready.runId);
    if (correlation === undefined ||
      message.taskId !== correlation.taskId ||
      ready.planId !== correlation.planId ||
      ready.surfaceId !== correlation.surfaceId ||
      ready.actionId !== 'workflow.run' ||
      ready.label !== correlation.label) {
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
    if (!Array.isArray(rendered.proposals)) {
      throw new Error('UI renderer action proposals are malformed');
    }
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

  private validateProposalCapacity(
    context: UiTurnContext,
    proposals: ActionPlan[]
  ): void {
    if (!Array.isArray(proposals)) {
      throw new Error('UI renderer action proposals are malformed');
    }
    if (proposals.length > PENDING_PLAN_LIMIT ||
      context.pendingPlans.size + proposals.length > PENDING_PLAN_LIMIT) {
      throw new Error('UI renderer action proposal capacity is exhausted');
    }
  }

  private clearTerminalPlanCorrelation(
    message: AgentMessage,
    context: UiTurnContext
  ): void {
    if (message.payload === null ||
      typeof message.payload !== 'object' ||
      Array.isArray(message.payload)) {
      return;
    }
    const values =
      message.payload as Record<string, Object | string | number | boolean | null | undefined>;
    const runId = values['runId'];
    const planId = values['planId'];
    const surfaceId = values['surfaceId'];
    const status = values['status'];
    if (typeof runId !== 'string' ||
      typeof planId !== 'string' ||
      surfaceId !== context.surfaceId ||
      (status !== 'success' && status !== 'canceled' && status !== 'error')) {
      return;
    }
    const correlation = context.pendingPlans.get(runId);
    if (correlation !== undefined &&
      correlation.planId === planId &&
      correlation.surfaceId === surfaceId &&
      correlation.taskId === message.taskId) {
      context.pendingPlans.delete(runId);
    }
  }
}
