import { AgentEvent, AgentEventKind } from './AgentEvent';
import {
  MESSAGE_TAG_LEADER,
  MESSAGE_TYPE_CONTROL_CLEAR,
  MESSAGE_TYPE_INPUT,
  MESSAGE_TYPE_OTHERS,
  MESSAGE_TYPE_OUTPUT,
  MESSAGE_TYPE_TASK_RESULT_UI
} from './AgentMessageTypes';
import { AgentMessage } from './MessageBus';
import { MessageBus } from './MessageBus';
import { MessageDrivenAgent, MessageProcessingMode } from './MessageDrivenAgent';
import { LEADER_AGENT_IDENTITY_PROMPT } from './LeaderAgentPrompt';
import { createLeaderToolRegistry } from './LeaderToolRegistry';
import { LocalModel } from '../model/LocalModel';

export class LeaderAgent extends MessageDrivenAgent {
  constructor(
    model: LocalModel,
    maxSteps: number,
    bus: MessageBus
  ) {
    super(
      'Leader',
      LEADER_AGENT_IDENTITY_PROMPT,
      model,
      maxSteps,
      bus,
      MessageProcessingMode.BATCH_PENDING,
      createLeaderToolRegistry(bus)
    );
  }

  protected handle(message: AgentMessage): void {
    if (message.type === MESSAGE_TYPE_CONTROL_CLEAR) {
      this.clearContext();
      return;
    }
    if (message.type !== MESSAGE_TYPE_INPUT && message.type !== MESSAGE_TYPE_TASK_RESULT_UI) {
      return;
    }
    this.enqueueMessage(message);
  }

  protected onAgentEvent(event: AgentEvent): void {
    if (event.kind === AgentEventKind.FINAL) {
      this.bus.write({
        type: MESSAGE_TYPE_OUTPUT,
        content: event.text
      });
      return;
    }

    this.bus.write({
      type: `${MESSAGE_TYPE_OTHERS}.${MESSAGE_TAG_LEADER}.${event.kind}`,
      content: event.text
    });
  }

  protected onRunError(error: Error): void {
    this.bus.write({
      type: `${MESSAGE_TYPE_OTHERS}.${MESSAGE_TAG_LEADER}.${AgentEventKind.ERROR}`,
      content: error.message
    });
  }
}
