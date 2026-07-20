import { newSurfaceId } from '../../a2ui/A2uiProtocol';
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
  UiRenderResultPayload,
  UiRenderState,
  UiSurfaceWriter,
  UiTaskRenderer
} from './UiAgentTypes';

interface UiTurnContext {
  conversationId: string;
  turnId: string;
  surfaceId: string;
  uiTaskId: string;
  uiTask?: CreateUiTaskPayload;
  pendingData?: DataResult;
  pendingDataTaskId: string;
  canceled: boolean;
  skeletonWritten: boolean;
  resultWritten: boolean;
}

export class UiAgent extends MessageDrivenAgent {
  private readonly bus: LinkedMessageBus;
  private readonly renderer: UiTaskRenderer;
  private readonly writer: UiSurfaceWriter;
  private readonly contexts: Map<string, UiTurnContext> = new Map<string, UiTurnContext>();
  private readonly terminated: Set<string> = new Set<string>();
  private surfaceSuffix: number = 0;

  constructor(bus: LinkedMessageBus, renderer: UiTaskRenderer, writer: UiSurfaceWriter) {
    super(bus);
    this.bus = bus;
    this.renderer = renderer;
    this.writer = writer;
  }

  surfaceReplaced(conversationId: string, turnId: string, surfaceId: string): void {
    const key: string = this.turnKey(conversationId, turnId);
    const context: UiTurnContext | undefined = this.contexts.get(key);
    if (context === undefined || context.surfaceId !== surfaceId) {
      return;
    }
    this.terminated.add(key);
    this.contexts.delete(key);
  }

  protected accepts(message: AgentMessage): boolean {
    return message.type === AgentMessageType.TASK_CREATE_UI ||
      message.type === AgentMessageType.TASK_RESULT_DATA ||
      message.type === AgentMessageType.TASK_ERROR ||
      message.type === AgentMessageType.ACTION_PROGRESS ||
      message.type === AgentMessageType.ACTION_RESULT ||
      message.type === AgentMessageType.TURN_CANCEL;
  }

  protected async process(message: AgentMessage): Promise<void> {
    const key: string = this.turnKey(message.conversationId, message.turnId);
    if (message.type === AgentMessageType.TURN_CANCEL) {
      const context: UiTurnContext | undefined = this.contexts.get(key);
      if (context !== undefined) {
        context.canceled = true;
      }
      this.terminated.add(key);
      this.contexts.delete(key);
      return;
    }
    if (this.terminated.has(key)) {
      return;
    }
    try {
      if (message.type === AgentMessageType.TASK_CREATE_UI) {
        await this.handleUiTask(message, key);
      } else if (message.type === AgentMessageType.TASK_RESULT_DATA) {
        await this.handleDataResult(message, key);
      } else if (message.type === AgentMessageType.TASK_ERROR) {
        await this.handleTaskError(message, key);
      } else {
        await this.handleActionStatus(message, key);
      }
    } catch (error) {
      this.failRender(message, key, error as Object);
    }
  }

  private async handleUiTask(message: AgentMessage, key: string): Promise<void> {
    const context: UiTurnContext = this.contextFor(message, key);
    if (context.canceled || context.skeletonWritten || context.uiTask !== undefined) {
      return;
    }
    const task: CreateUiTaskPayload = message.payload as CreateUiTaskPayload;
    context.uiTask = task;
    context.uiTaskId = message.taskId;
    const jsonl: string = await this.renderer.skeleton(task, context.surfaceId);
    await this.writer.write(context.turnId, context.surfaceId, jsonl);
    context.skeletonWritten = true;
    this.publishUiResult(context, 'skeleton');
    await this.renderPendingData(context);
  }

  private async handleDataResult(message: AgentMessage, key: string): Promise<void> {
    const context: UiTurnContext = this.contextFor(message, key);
    if (context.canceled || context.resultWritten || context.pendingDataTaskId === message.taskId) {
      return;
    }
    context.pendingData = message.payload as DataResult;
    context.pendingDataTaskId = message.taskId;
    await this.renderPendingData(context);
  }

  private async renderPendingData(context: UiTurnContext): Promise<void> {
    const task: CreateUiTaskPayload | undefined = context.uiTask;
    const data: DataResult | undefined = context.pendingData;
    if (task === undefined || data === undefined || !context.skeletonWritten || context.resultWritten) {
      return;
    }
    const jsonl: string = await this.renderer.result(task, data, context.surfaceId);
    await this.writer.write(context.turnId, context.surfaceId, jsonl);
    context.resultWritten = true;
    this.publishUiResult(context, 'result');
    context.uiTask = undefined;
    context.pendingData = undefined;
  }

  private async handleTaskError(message: AgentMessage, key: string): Promise<void> {
    const context: UiTurnContext | undefined = this.contexts.get(key);
    if (context === undefined || context.canceled || context.resultWritten || context.uiTask === undefined) {
      return;
    }
    const error: TaskErrorPayload = message.payload as TaskErrorPayload;
    const jsonl: string = await this.renderer.error(context.uiTask, error.message, context.surfaceId);
    await this.writer.write(context.turnId, context.surfaceId, jsonl);
    context.resultWritten = true;
    this.publishUiResult(context, 'error');
    context.uiTask = undefined;
    context.pendingData = undefined;
  }

  private async handleActionStatus(message: AgentMessage, key: string): Promise<void> {
    const context: UiTurnContext | undefined = this.contexts.get(key);
    if (context === undefined || context.canceled || this.payloadSurfaceId(message.payload) !== context.surfaceId) {
      return;
    }
    const jsonl: string = await this.renderer.actionStatus(message.payload, context.surfaceId);
    await this.writer.write(context.turnId, context.surfaceId, jsonl);
    this.publishUiResult(context, 'action');
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
      pendingDataTaskId: '',
      canceled: false,
      skeletonWritten: false,
      resultWritten: false
    };
    this.contexts.set(key, created);
    return created;
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

  private payloadSurfaceId(payload: Object): string {
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

  private failRender(message: AgentMessage, key: string, error: Object): void {
    const context: UiTurnContext | undefined = this.contexts.get(key);
    this.terminated.add(key);
    this.contexts.delete(key);
    const payload: TaskErrorPayload = {
      code: 'UI_RENDER_FAILED',
      message: error instanceof Error ? error.message : `${error}`
    };
    this.bus.publish({
      type: AgentMessageType.TASK_ERROR,
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: context === undefined || context.uiTaskId.length === 0 ? message.taskId : context.uiTaskId,
      payload
    });
  }

  private turnKey(conversationId: string, turnId: string): string {
    return `${conversationId.length}:${conversationId}${turnId}`;
  }
}
