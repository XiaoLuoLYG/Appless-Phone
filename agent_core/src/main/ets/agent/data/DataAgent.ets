import { MessageDrivenAgent } from '../MessageDrivenAgent';
import {
  AgentMessage,
  AgentMessageType,
  TaskErrorPayload
} from '../message/AgentMessage';
import { DataResult } from '../message/DataResult';
import { LinkedMessageBus } from '../message/LinkedMessageBus';
import { CreateDataTaskPayload, DataTaskExecutor } from './DataAgentTypes';

export class DataAgent extends MessageDrivenAgent {
  private readonly bus: LinkedMessageBus;
  private readonly executor: DataTaskExecutor;
  private readonly canceled: Set<string> = new Set<string>();

  constructor(bus: LinkedMessageBus, executor: DataTaskExecutor) {
    super(bus);
    this.bus = bus;
    this.executor = executor;
  }

  stop(): void {
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
    this.execute(message, key);
  }

  private execute(message: AgentMessage, key: string): void {
    try {
      this.executor.execute(message.payload as CreateDataTaskPayload)
        .then((result: DataResult) => {
          if (!this.canceled.has(key)) {
            this.publishResult(message, result);
          }
        })
        .catch((error: Object) => {
          if (!this.canceled.has(key)) {
            this.publishError(message, error);
          }
        });
    } catch (error) {
      if (!this.canceled.has(key)) {
        this.publishError(message, error as Object);
      }
    }
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
    this.bus.publish({
      type: AgentMessageType.TASK_ERROR,
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: message.taskId,
      payload
    });
  }

  private turnKey(message: AgentMessage): string {
    return `${message.conversationId.length}:${message.conversationId}${message.turnId}`;
  }
}
