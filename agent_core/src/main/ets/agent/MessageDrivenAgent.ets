import { AgentMessage, BusReader, MessageBus } from './MessageBus';
import { AgentEvent, AgentEventKind } from './AgentEvent';
import { ConversationContext } from './ConversationContext';
import { ReActAgent } from './ReActAgent';
import { UiRenderHandler } from './ReActAgentRunner';
import { ToolRegistry } from './ToolRegistry';
import { LocalModel } from '../model/LocalModel';

export enum MessageProcessingMode {
  ONE_BY_ONE = 'ONE_BY_ONE',
  BATCH_PENDING = 'BATCH_PENDING'
}

export enum AgentRunOutcomeKind {
  FINAL = 'final',
  ERROR = 'error'
}

export interface AgentRunOutcome {
  readonly kind: AgentRunOutcomeKind;
  readonly text: string;
}

export abstract class MessageDrivenAgent extends ReActAgent {
  protected readonly bus: MessageBus;

  private readonly reader: BusReader;
  private readonly processingMode: MessageProcessingMode;
  private listening: boolean = false;
  private stopped: boolean = false;
  private listenPromise: Promise<void> | null = null;
  private pendingMessages: AgentMessage[] = [];
  private currentRun: Promise<void> | null = null;

  constructor(
    name: string,
    identityPrompt: string,
    model: LocalModel,
    maxSteps: number,
    bus: MessageBus,
    processingMode: MessageProcessingMode,
    tools: ToolRegistry,
    uiHandler?: UiRenderHandler,
    initialContext?: ConversationContext
  ) {
    super(name, identityPrompt, model, maxSteps, tools, uiHandler, initialContext);
    this.bus = bus;
    this.processingMode = processingMode;
    this.reader = bus.getReader();
  }

  startListening(): void {
    if (this.listening) {
      return;
    }
    if (this.stopped) {
      throw new Error('A stopped MessageDrivenAgent cannot restart listening.');
    }

    this.listening = true;
    const listening = this.listenLoop();
    this.listenPromise = listening;
    listening.catch((error: Error | Object | string | number | boolean | null | undefined): void => {
      this.listening = false;
      this.stopped = true;
      this.listenPromise = null;
      this.reader.close();
      const normalized = error instanceof Error ? error : new Error(`${error}`);
      this.onListeningError(normalized);
    });
  }

  async stopListening(): Promise<void> {
    if (this.stopped) {
      return;
    }

    this.stopped = true;
    this.listening = false;
    this.reader.close();
    const listening = this.listenPromise;
    this.listenPromise = null;
    if (listening !== null) {
      try {
        await listening;
      } catch (_error) {
      }
    }
  }

  async close(): Promise<void> {
    await this.stopListening();
    const running = this.currentRun;
    if (running !== null) {
      try {
        await running;
      } catch (_error) {
      }
    }
    await super.close();
  }

  protected abstract handle(message: AgentMessage): void;

  protected enqueueMessage(message: AgentMessage): void {
    if (this.stopped) {
      return;
    }
    this.pendingMessages.push({
      type: message.type,
      content: message.content
    });
    this.tryStartNextRun();
  }

  protected isRunning(): boolean {
    return this.currentRun !== null;
  }

  protected onAgentEvent(_event: AgentEvent): void {
  }

  protected onRunError(_error: Error): void {
  }

  protected onMessageError(_message: AgentMessage, _error: Error): void {
  }

  protected onListeningError(_error: Error): void {
  }

  protected onRunFinished(_messages: AgentMessage[], _outcome: AgentRunOutcome): void {
  }

  private tryStartNextRun(): void {
    if (this.stopped || this.currentRun !== null || this.pendingMessages.length === 0) {
      return;
    }

    const messages = this.takePendingMessages();
    this.currentRun = this.executeRun(messages);
  }

  private takePendingMessages(): AgentMessage[] {
    if (this.processingMode === MessageProcessingMode.ONE_BY_ONE) {
      const message = this.pendingMessages.shift();
      return message === undefined ? [] : [message];
    }

    const messages = this.pendingMessages.slice();
    this.pendingMessages = [];
    return messages;
  }

  private buildTask(messages: AgentMessage[]): string {
    let task = 'Process the following messages in arrival order:\n\n';
    for (const message of messages) {
      task += `[${message.type}]\n`;
      task += message.content;
      task += '\n\n';
    }
    return task.trim();
  }

  private async executeRun(messages: AgentMessage[]): Promise<void> {
    let outcome: AgentRunOutcome | null = null;
    try {
      await this.executeTask(this.buildTask(messages), (event: AgentEvent): void => {
        if (outcome === null && event.kind === AgentEventKind.FINAL) {
          outcome = {
            kind: AgentRunOutcomeKind.FINAL,
            text: event.text
          };
        } else if (outcome === null && event.kind === AgentEventKind.ERROR) {
          outcome = {
            kind: AgentRunOutcomeKind.ERROR,
            text: event.text
          };
        }
        try {
          this.onAgentEvent(event);
        } catch (error) {
          const normalized = error instanceof Error ? error : new Error(`${error}`);
          try {
            this.onRunError(normalized);
          } catch (_hookError) {
          }
        }
      });
    } catch (error) {
      const normalized = error instanceof Error ? error : new Error(`${error}`);
      outcome = {
        kind: AgentRunOutcomeKind.ERROR,
        text: normalized.message
      };
      try {
        this.onRunError(normalized);
      } catch (_hookError) {
      }
    } finally {
      if (outcome === null) {
        outcome = {
          kind: AgentRunOutcomeKind.ERROR,
          text: 'Agent loop ended without a Final or Error result.'
        };
      }
      try {
        this.onRunFinished(messages, outcome);
      } catch (error) {
        const normalized = error instanceof Error ? error : new Error(`${error}`);
        try {
          this.onRunError(normalized);
        } catch (_hookError) {
        }
      }
      this.currentRun = null;
      this.tryStartNextRun();
    }
  }

  private async listenLoop(): Promise<void> {
    while (this.listening) {
      const message = await this.reader.receive();
      if (message === null) {
        return;
      }

      try {
        this.handle(message);
      } catch (error) {
        const normalized = error instanceof Error ? error : new Error(`${error}`);
        this.onMessageError(message, normalized);
      }
    }
  }
}
