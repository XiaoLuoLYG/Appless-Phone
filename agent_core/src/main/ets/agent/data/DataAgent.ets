import { MessageDrivenAgent } from '../MessageDrivenAgent';
import {
  AgentMessage,
  AgentMessageType,
  TaskErrorPayload
} from '../message/AgentMessage';
import { DataResult } from '../message/DataResult';
import { LinkedMessageBus } from '../message/LinkedMessageBus';
import {
  CreateDataTaskPayload,
  DataTaskAuthorizationResult,
  DataTaskAuthorizer,
  DataTaskExecutor
} from './DataAgentTypes';

export class DataAgent extends MessageDrivenAgent {
  private readonly bus: LinkedMessageBus;
  private readonly authorizer: DataTaskAuthorizer;
  private readonly executor: DataTaskExecutor;
  private readonly canceled: Set<string> = new Set<string>();
  private active: boolean = false;
  private generation: number = 0;

  constructor(
    bus: LinkedMessageBus,
    authorizer: DataTaskAuthorizer,
    executor: DataTaskExecutor
  ) {
    super(bus);
    this.bus = bus;
    this.authorizer = authorizer;
    this.executor = executor;
  }

  start(): void {
    if (this.active) {
      return;
    }
    this.active = true;
    this.generation++;
    super.start();
  }

  stop(): void {
    this.active = false;
    this.generation++;
    super.stop();
    this.canceled.clear();
  }

  protected accepts(message: AgentMessage): boolean {
    return message.type === AgentMessageType.TASK_CREATE_DATA ||
      message.type === AgentMessageType.TURN_CANCEL;
  }

  protected async process(message: AgentMessage): Promise<void> {
    const key: string = this.turnKey(message);
    if (message.type === AgentMessageType.TURN_CANCEL) {
      this.canceled.add(key);
      return;
    }
    if (this.canceled.has(key)) {
      return;
    }
    const task: CreateDataTaskPayload | null = this.dataTask(message.payload, message.taskId);
    if (task === null) {
      this.publishInputError(message, 'DATA_TASK_INVALID', 'Data task payload is malformed');
      return;
    }
    let authorization: DataTaskAuthorizationResult;
    try {
      authorization = this.authorizer(task);
    } catch (_error) {
      this.publishInputError(message, 'DATA_TASK_UNAUTHORIZED', 'Data task authorization failed');
      return;
    }
    if (!authorization.ok) {
      this.publishInputError(
        message,
        authorization.code.length === 0 ? 'DATA_TASK_UNAUTHORIZED' : authorization.code,
        authorization.message.length === 0 ? 'Data task is not authorized' : authorization.message
      );
      return;
    }
    this.execute(message, task, key);
  }

  private execute(message: AgentMessage, task: CreateDataTaskPayload, key: string): void {
    const generation: number = this.generation;
    try {
      this.executor.execute(task)
        .then((result: DataResult) => {
          if (this.canPublish(key, generation)) {
            if (this.validResult(task, result)) {
              this.publishResult(message, result);
            } else {
              this.publishInputError(
                message,
                'DATA_TASK_OUTPUT_INVALID',
                'Data task output does not match the authorized task'
              );
            }
          }
        })
        .catch((error: Object) => {
          if (this.canPublish(key, generation)) {
            this.publishError(message, error);
          }
        });
    } catch (error) {
      if (this.canPublish(key, generation)) {
        this.publishError(message, error as Object);
      }
    }
  }

  private canPublish(key: string, generation: number): boolean {
    return this.active && this.generation === generation && !this.canceled.has(key);
  }

  private publishResult(message: AgentMessage, result: DataResult): void {
    this.bus.publish({
      type: AgentMessageType.TASK_RESULT_DATA,
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: message.taskId,
      payload: result
    });
  }

  private publishError(message: AgentMessage, error: Object): void {
    const payload: TaskErrorPayload = {
      code: 'DATA_TASK_FAILED',
      message: error instanceof Error ? error.message : `${error}`
    };
    this.publishTaskError(message, payload);
  }

  private publishInputError(message: AgentMessage, code: string, detail: string): void {
    const payload: TaskErrorPayload = {
      code,
      message: detail
    };
    this.publishTaskError(message, payload);
  }

  private publishTaskError(message: AgentMessage, payload: TaskErrorPayload): void {
    this.bus.publish({
      type: AgentMessageType.TASK_ERROR,
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: message.taskId,
      payload
    });
  }

  private dataTask(payload: Object, taskId: string): CreateDataTaskPayload | null {
    if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
      return null;
    }
    const values = payload as Record<string, Object | string | number | boolean | null | undefined>;
    const payloadTaskId = values['taskId'];
    const skillId = values['skillId'];
    const toolId = values['toolId'];
    const outputSchema = values['outputSchema'];
    const args = values['args'];
    if (typeof payloadTaskId !== 'string' || payloadTaskId !== taskId ||
      typeof skillId !== 'string' ||
      typeof toolId !== 'string' || toolId.trim().length === 0 ||
      typeof outputSchema !== 'string' || outputSchema.trim().length === 0 ||
      args === null || typeof args !== 'object' || Array.isArray(args)) {
      return null;
    }
    return payload as CreateDataTaskPayload;
  }

  private validResult(task: CreateDataTaskPayload, result: DataResult): boolean {
    return result !== null && typeof result === 'object' &&
      result.toolId === task.toolId && result.outputSchema === task.outputSchema &&
      Array.isArray(result.sources) && Array.isArray(result.warnings) &&
      (result.status === 'success' || result.status === 'partial' ||
        result.status === 'empty' || result.status === 'error');
  }

  private turnKey(message: AgentMessage): string {
    return `${message.conversationId.length}:${message.conversationId}${message.turnId}`;
  }

}
