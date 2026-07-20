export interface AgentMessage {
  readonly type: string;
  readonly content: string;
}

export interface BusReader {
  receive(): Promise<AgentMessage | null>;

  close(): void;
}

export interface MessageBus {
  getReader(): BusReader;

  write(message: AgentMessage): void;
}

interface LinkResult {
  readonly message: AgentMessage;
  readonly next: MessageLink;
}

class MessageLink {
  private nextPromise: Promise<LinkResult>;
  private resolveNext: ((result: LinkResult) => void) | null = null;
  private linked: boolean = false;

  constructor() {
    this.nextPromise = new Promise<LinkResult>((resolve: (result: LinkResult) => void) => {
      this.resolveNext = resolve;
    });
  }

  waitNext(): Promise<LinkResult> {
    return this.nextPromise;
  }

  link(result: LinkResult): void {
    if (this.linked || this.resolveNext === null) {
      throw new Error('Message link has already been completed.');
    }

    this.linked = true;
    const resolve = this.resolveNext;
    this.resolveNext = null;
    resolve(result);
  }
}

class ReceiveResult {
  readonly packet: LinkResult | null;
  readonly closed: boolean;

  constructor(packet: LinkResult | null, closed: boolean) {
    this.packet = packet;
    this.closed = closed;
  }
}

class LinkedBusReader implements BusReader {
  private cursor: MessageLink | null;
  private closed: boolean = false;
  private receiving: boolean = false;
  private closePromise: Promise<void>;
  private resolveClose: (() => void) | null = null;

  constructor(cursor: MessageLink) {
    this.cursor = cursor;
    this.closePromise = new Promise<void>((resolve: () => void) => {
      this.resolveClose = resolve;
    });
  }

  async receive(): Promise<AgentMessage | null> {
    if (this.closed) {
      return null;
    }
    if (this.receiving) {
      throw new Error('Concurrent receive calls on the same BusReader are not allowed.');
    }

    const cursor = this.cursor;
    if (cursor === null) {
      return null;
    }

    this.receiving = true;
    try {
      const messageResult = cursor.waitNext().then((packet: LinkResult): ReceiveResult => {
        return new ReceiveResult(packet, false);
      });
      const closeResult = this.closePromise.then((): ReceiveResult => {
        return new ReceiveResult(null, true);
      });
      const result = await Promise.race<ReceiveResult>([messageResult, closeResult]);

      if (result.closed || this.closed || result.packet === null) {
        return null;
      }

      this.cursor = result.packet.next;
      return result.packet.message;
    } finally {
      this.receiving = false;
    }
  }

  close(): void {
    if (this.closed) {
      return;
    }

    this.closed = true;
    this.cursor = null;
    const resolve = this.resolveClose;
    this.resolveClose = null;
    if (resolve !== null) {
      resolve();
    }
  }
}

export class LinkedMessageBus implements MessageBus {
  private tail: MessageLink = new MessageLink();

  getReader(): BusReader {
    return new LinkedBusReader(this.tail);
  }

  write(message: AgentMessage): void {
    if (message.type.trim().length === 0) {
      throw new Error('Message type must not be empty.');
    }

    const nextTail = new MessageLink();
    const currentTail = this.tail;
    const storedMessage: AgentMessage = {
      type: message.type,
      content: message.content
    };
    this.tail = nextTail;
    currentTail.link({
      message: storedMessage,
      next: nextTail
    });
  }
}
