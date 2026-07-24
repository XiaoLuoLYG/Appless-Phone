import { ConversationContext } from '../agent/ConversationContext';
import { LocalModel, ModelContentListener } from './LocalModel';

export class ScriptedLocalModel implements LocalModel {
  async complete(
    prompt: string,
    _conversation?: ConversationContext,
    onContent?: ModelContentListener
  ): Promise<string> {
    if (!prompt.toLowerCase().includes('observation:')) {
      const task = this.extractTask(prompt);
      const lower = task.toLowerCase();
      if (lower.includes('time') || lower.includes('date')) {
        return this.emit('Thought: I should inspect the device clock.\n<appless_tool>time[]</appless_tool>', onContent);
      }
      if (this.wantsUi(lower)) {
        return this.emit(`Thought: The user wants a visual UI on screen.\n<appless_tool>ui[${task}]</appless_tool>`, onContent);
      }
      return this.emit(`Thought: I should preserve the user's request as local context.\n<appless_tool>note[${task}]</appless_tool>`, onContent);
    }

    if (prompt.toLowerCase().includes('rendered on-screen ui')) {
      return this.emit(
        'Thought: The UI is on screen; I can summarize.\nFinal: I rendered an on-screen card for your request. Check the panel above the chat.',
        onContent
      );
    }

    return this.emit(
      'Thought: I have enough local context to answer.\nFinal: I ran the local ReAct loop and used the available device tool result.',
      onContent
    );
  }

  private emit(value: string, onContent?: ModelContentListener): string {
    onContent?.(value);
    return value;
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

    let task = prompt.substring(start + marker.length).trim();
    const nextSection = task.indexOf('\n\n');
    if (nextSection >= 0) {
      task = task.substring(0, nextSection).trim();
    }
    return task.replace(/\[/g, '(').replace(/\]/g, ')');
  }
}
