import { AgentMessage } from './message/AgentMessage';
import { AgentMessageReader, LinkedMessageBus } from './message/LinkedMessageBus';

export abstract class MessageDrivenAgent {
  private reader: AgentMessageReader;
  private running: boolean = false;

  constructor(bus: LinkedMessageBus) {
    this.reader = bus.openReader();
  }

  start(): void {
    if (this.running) {
      return;
    }
    this.running = true;
    this.pump();
  }

  stop(): void {
    this.running = false;
    this.reader.close();
  }

  protected abstract accepts(message: AgentMessage): boolean;

  protected abstract process(message: AgentMessage): Promise<void>;

  private async pump(): Promise<void> {
    while (this.running) {
      const message: AgentMessage | null = await this.reader.receive();
      if (message === null) {
        return;
      }
      if (this.accepts(message)) {
        await this.process(message);
      }
    }
  }
}
