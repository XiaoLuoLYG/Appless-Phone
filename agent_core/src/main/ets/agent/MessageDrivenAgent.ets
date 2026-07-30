import { AgentMessage } from './message/AgentMessage';
import { AgentMessageReader, LinkedMessageBus } from './message/LinkedMessageBus';

export abstract class MessageDrivenAgent {
  private readonly messageBus: LinkedMessageBus;
  private messageReader: AgentMessageReader | null;
  private messagePumpRunning: boolean = false;
  private messagePumpGeneration: number = 0;
  private messagePumpTail: Promise<void> = Promise.resolve();

  constructor(bus: LinkedMessageBus) {
    this.messageBus = bus;
    this.messageReader = bus.openReader();
  }

  start(): void {
    if (this.messagePumpRunning) {
      return;
    }
    this.messagePumpRunning = true;
    this.messagePumpGeneration++;
    const generation = this.messagePumpGeneration;
    const reader = this.messageReader === null ?
      this.messageBus.openReader() : this.messageReader;
    this.messageReader = reader;
    this.messagePumpTail = this.launchAfter(
      this.messagePumpTail,
      reader,
      generation
    );
  }

  stop(): void {
    this.messagePumpRunning = false;
    this.messagePumpGeneration++;
    const reader = this.messageReader;
    this.messageReader = null;
    if (reader !== null) {
      reader.close();
    }
  }

  protected abstract accepts(message: AgentMessage): boolean;

  protected abstract process(message: AgentMessage): Promise<void>;

  private async launchAfter(
    previous: Promise<void>,
    reader: AgentMessageReader,
    generation: number
  ): Promise<void> {
    try {
      await previous;
    } catch (_error) {
    }
    await this.pump(reader, generation);
  }

  private async pump(reader: AgentMessageReader, generation: number): Promise<void> {
    while (this.messagePumpRunning &&
      this.messagePumpGeneration === generation &&
      this.messageReader === reader) {
      const message: AgentMessage | null = await reader.receive();
      if (message === null) {
        return;
      }
      if (!this.messagePumpRunning ||
        this.messagePumpGeneration !== generation ||
        this.messageReader !== reader) {
        return;
      }
      if (this.accepts(message)) {
        await this.process(message);
      }
    }
  }
}
