import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  LinkedMessageBus,
  MessageDrivenAgent
} from '@loop/agent-core';

function message(taskId: string, type: AgentMessageType = AgentMessageType.TASK_CREATE_DATA): AgentMessage {
  return {
    type,
    conversationId: 'conversation-a',
    turnId: 'turn-a',
    taskId,
    payload: new Object()
  };
}

function taskIdOf(received: AgentMessage | null): string {
  return received === null ? '' : received.taskId;
}

class TestGate {
  readonly promise: Promise<void>;
  private resolvePromise: (() => void) | null = null;

  constructor() {
    this.promise = new Promise<void>((resolve: () => void) => {
      this.resolvePromise = resolve;
    });
  }

  open(): void {
    if (this.resolvePromise !== null) {
      this.resolvePromise();
      this.resolvePromise = null;
    }
  }
}

class SerialTestAgent extends MessageDrivenAgent {
  readonly startedTaskIds: string[] = [];
  readonly firstStarted: TestGate = new TestGate();
  readonly secondStarted: TestGate = new TestGate();
  private readonly releaseFirst: TestGate = new TestGate();

  constructor(bus: LinkedMessageBus) {
    super(bus);
  }

  releaseFirstHandler(): void {
    this.releaseFirst.open();
  }

  protected accepts(received: AgentMessage): boolean {
    return received.type === AgentMessageType.TASK_CREATE_DATA;
  }

  protected async process(received: AgentMessage): Promise<void> {
    this.startedTaskIds.push(received.taskId);
    if (received.taskId === 'accepted-1') {
      this.firstStarted.open();
      await this.releaseFirst.promise;
    } else if (received.taskId === 'accepted-2') {
      this.secondStarted.open();
    }
  }
}

export default function linkedMessageBusTest() {
  describe('linkedMessageBus', () => {
    it('broadcasts one published message to every existing reader', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const readerA: AgentMessageReader = bus.openReader();
      const readerB: AgentMessageReader = bus.openReader();
      const receivedA: Promise<AgentMessage | null> = readerA.receive();
      const receivedB: Promise<AgentMessage | null> = readerB.receive();
      const published: AgentMessage = message('message-1');

      bus.publish(published);

      const valueA: AgentMessage | null = await receivedA;
      const valueB: AgentMessage | null = await receivedB;
      expect(taskIdOf(valueA)).assertEqual('message-1');
      expect(taskIdOf(valueB)).assertEqual('message-1');
      expect(valueA === published).assertFalse();
      expect(valueB === published).assertFalse();
      expect(valueA === valueB).assertFalse();
      readerA.close();
      readerB.close();
    });

    it('advances readers independently', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const readerA: AgentMessageReader = bus.openReader();
      const readerB: AgentMessageReader = bus.openReader();
      bus.publish(message('message-1'));
      bus.publish(message('message-2'));

      expect(taskIdOf(await readerA.receive())).assertEqual('message-1');
      expect(taskIdOf(await readerA.receive())).assertEqual('message-2');
      expect(taskIdOf(await readerB.receive())).assertEqual('message-1');
      readerA.close();
      readerB.close();
    });

    it('starts new readers at the current tail', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      bus.publish(message('message-1'));
      const reader: AgentMessageReader = bus.openReader();
      bus.publish(message('message-2'));

      expect(taskIdOf(await reader.receive())).assertEqual('message-2');
      reader.close();
    });

    it('closes only the selected pending reader', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const readerA: AgentMessageReader = bus.openReader();
      const readerB: AgentMessageReader = bus.openReader();
      const receivedA: Promise<AgentMessage | null> = readerA.receive();
      const receivedB: Promise<AgentMessage | null> = readerB.receive();

      readerA.close();
      expect(await receivedA).assertNull();
      bus.publish(message('message-1'));
      expect(taskIdOf(await receivedB)).assertEqual('message-1');
      readerB.close();
    });

    it('filters unrelated messages and processes accepted messages serially', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const agent: SerialTestAgent = new SerialTestAgent(bus);
      agent.start();
      bus.publish(message('unrelated', AgentMessageType.TASK_CREATE_UI));
      bus.publish(message('accepted-1'));
      await agent.firstStarted.promise;

      bus.publish(message('accepted-2'));
      await Promise.resolve();
      expect(agent.startedTaskIds.join(',')).assertEqual('accepted-1');

      agent.releaseFirstHandler();
      await agent.secondStarted.promise;
      expect(agent.startedTaskIds.join(',')).assertEqual('accepted-1,accepted-2');
      agent.stop();
    });
  });
}
