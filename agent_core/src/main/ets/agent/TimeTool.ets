import { AgentTool } from './AgentTool';

export class TimeTool implements AgentTool {
  name(): string {
    return 'time';
  }

  description(): string {
    return 'Returns the device local date and time. Use only when the current date or time is required.';
  }

  async run(_input: string): Promise<string> {
    return new Date().toLocaleString();
  }
}
