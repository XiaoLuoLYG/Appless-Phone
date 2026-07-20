import { AgentMessage } from './AgentMessage';

type MessageNodeWaiter = (next: MessageNode | null) => void;

function copyAgentMessage(message: AgentMessage): AgentMessage {
  return {
    type: message.type,
    conversationId: message.conversationId,
    turnId: message.turnId,
    taskId: message.taskId,
    payload: message.payload
  };
}

class MessageNode {
  private readonly message: AgentMessage | null;
  private next: MessageNode | null = null;
  private waiters: MessageNodeWaiter[] = [];

  constructor(message: AgentMessage | null) {
    this.message = message;
  }

  static sentinel(): MessageNode {
    return new MessageNode(null);
  }

  append(next: MessageNode): void {
    this.next = next;
    const waiters: MessageNodeWaiter[] = this.waiters;
    this.waiters = [];
    for (let index = 0; index < waiters.length; index++) {
      waiters[index](next);
    }
  }

  waitForNext(waiter: MessageNodeWaiter): void {
    if (this.next !== null) {
      waiter(this.next);
      return;
    }
    this.waiters.push(waiter);
  }

  removeWaiter(waiter: MessageNodeWaiter): void {
    const index: number = this.waiters.indexOf(waiter);
    if (index >= 0) {
      this.waiters.splice(index, 1);
    }
  }

  copyMessage(): AgentMessage | null {
    return this.message === null ? null : copyAgentMessage(this.message);
  }
}

export class AgentMessageReader {
  private cursor: MessageNode;
  private closed: boolean = false;
  private pendingNode: MessageNode | null = null;
  private pendingWaiter: MessageNodeWaiter | null = null;

  constructor(cursor: MessageNode) {
    this.cursor = cursor;
  }

  receive(): Promise<AgentMessage | null> {
    if (this.closed) {
      return Promise.resolve(null);
    }
    return new Promise<AgentMessage | null>((resolve: (message: AgentMessage | null) => void) => {
      const source: MessageNode = this.cursor;
      const waiter: MessageNodeWaiter = (next: MessageNode | null): void => {
        if (this.pendingWaiter !== waiter) {
          return;
        }
        this.pendingNode = null;
        this.pendingWaiter = null;
        if (next === null) {
          resolve(null);
          return;
        }
        this.cursor = next;
        resolve(next.copyMessage());
      };
      this.pendingNode = source;
      this.pendingWaiter = waiter;
      source.waitForNext(waiter);
    });
  }

  close(): void {
    if (this.closed) {
      return;
    }
    this.closed = true;
    const node: MessageNode | null = this.pendingNode;
    const waiter: MessageNodeWaiter | null = this.pendingWaiter;
    if (node !== null && waiter !== null) {
      node.removeWaiter(waiter);
      waiter(null);
    }
  }
}

export class LinkedMessageBus {
  private head: MessageNode = MessageNode.sentinel();
  private tail: MessageNode = this.head;

  openReader(): AgentMessageReader {
    return new AgentMessageReader(this.tail);
  }

  publish(message: AgentMessage): void {
    const next: MessageNode = new MessageNode(copyAgentMessage(message));
    this.tail.append(next);
    this.tail = next;
  }
}
