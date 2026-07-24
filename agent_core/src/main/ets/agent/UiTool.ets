import { AgentTool } from './AgentTool';
import { AgentToolRunOptions } from './AgentToolRunOptions';

/** Registered for prompts; actual rendering is handled by ReActAgentRunner. */
export class UiTool implements AgentTool {
  name(): string {
    return 'ui';
  }

  description(): string {
    return 'Renders an on-screen UI card for the user. Input: short description of what to show ' +
      '(e.g. welcome card, weather summary, profile). Use when the user asks to show, display, ' +
      'visualize, or build a card, form, or dashboard — not for plain text answers.';
  }

  async run(_input: string, _options?: AgentToolRunOptions): Promise<string> {
    return 'UI rendering is handled by the agent runtime.';
  }
}
