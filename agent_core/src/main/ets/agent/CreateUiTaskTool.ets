import { AgentTool } from './AgentTool';
import { MESSAGE_TYPE_TASK_CREATE_UI } from './AgentMessageTypes';
import { MessageBus } from './MessageBus';

export class CreateUiTaskTool implements AgentTool {
  private readonly bus: MessageBus;

  constructor(bus: MessageBus) {
    this.bus = bus;
  }

  name(): string {
    return 'create_ui_task';
  }

  description(): string {
    return 'Creates exactly one asynchronous UI-making task by publishing TASK.CREATE.UI to the message bus. ' +
      'Input must be a self-contained natural-language task for UImaker, including the UI goal, content/data ' +
      'that must appear, important layout or interaction requirements, and the expected completion result. ' +
      'Call this tool once for each independently executable UI task. The tool only dispatches work; a successful ' +
      'observation means the task was published, not that its UI has been completed.';
  }

  async run(input: string): Promise<string> {
    const task = input.trim();
    if (task.length === 0) {
      throw new Error('UI task description must not be empty.');
    }

    this.bus.write({
      type: MESSAGE_TYPE_TASK_CREATE_UI,
      content: task
    });
    return 'UI task published to the message bus. This confirms dispatch only; wait for TASK.RESULT.UI before treating the task as completed.';
  }
}
