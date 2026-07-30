import { ConversationContext } from '../agent/ConversationContext';
import { LocalModel } from './LocalModel';

export class ScriptedLocalModel implements LocalModel {
  async complete(prompt: string, _conversation?: ConversationContext, _systemPrompt?: string): Promise<string> {
    if (!prompt.toLowerCase().includes('observation:')) {
      const task = this.extractTask(prompt);
      const lower = task.toLowerCase();
      if (lower.includes('(task.result.ui)')) {
        return 'Thought: I received a UI task result and should report it accurately to the user.\n' +
          `Final: I received the following UImaker result:\n${task}`;
      }
      if (lower.includes('(task.create.ui)') && prompt.includes('- ui:')) {
        return `Thought: I should create the requested UI for this single task.\nAction: ui[${task}]`;
      }
      if ((lower.includes('time') || lower.includes('date')) && prompt.includes('- time:')) {
        return 'Thought: The current device time is required for this task.\nAction: time[]';
      }
      if (this.wantsUi(lower) && prompt.includes('create_ui_task')) {
        return `Thought: The request needs UI work, so I should dispatch one self-contained UI task.\nAction: create_ui_task[${task}]`;
      }
      return `Thought: No available tool is needed for this request.\nFinal: ${task}`;
    }

    if (prompt.toLowerCase().includes('ui task published to the message bus')) {
      return 'Thought: The UI task was dispatched but has not completed yet.\n' +
        'Final: I have dispatched the UI-making task and will evaluate its result when UImaker reports back.';
    }

    if (prompt.toLowerCase().includes('rendered on-screen ui')) {
      return 'Thought: The requested UI was created and I should report the current task outcome.\n' +
        'Final: Task: Create the requested UI.\\nStatus: Completed.\\nResult: Created the requested UI structure using the ui tool.';
    }

    return 'Thought: I have enough information to respond accurately.\nFinal: I processed the available result.';
  }

  private wantsUi(task: string): boolean {
    return task.includes('card')
      || task.includes(' ui')
      || task.startsWith('ui ')
      || task.includes('show ')
      || task.includes('display')
      || task.includes('visual')
      || task.includes('welcome')
      || task.includes('dashboard')
      || task.includes('form');
  }

  private extractTask(prompt: string): string {
    const marker = 'User task:';
    const start = prompt.indexOf(marker);
    if (start === -1) {
      return 'No task found';
    }

    const task = prompt.substring(start + marker.length).trim();
    return task.replace(/\[/g, '(').replace(/\]/g, ')');
  }
}
