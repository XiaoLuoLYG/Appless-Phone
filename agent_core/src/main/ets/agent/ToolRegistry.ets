import { AgentTool } from './AgentTool';
import { UiTool } from './UiTool';

class NoteTool implements AgentTool {
  name(): string {
    return 'note';
  }

  description(): string {
    return 'Echoes a note back into the loop.';
  }

  async run(input: string): Promise<string> {
    const trimmed = input.trim();
    return trimmed.length === 0 ? 'No note provided.' : `Noted: ${trimmed}`;
  }
}

class TimeTool implements AgentTool {
  name(): string {
    return 'time';
  }

  description(): string {
    return 'Returns the device\'s local date and time.';
  }

  async run(_input: string): Promise<string> {
    return new Date().toLocaleString();
  }
}

export class ToolRegistry {
  private tools: Map<string, AgentTool> = new Map();

  constructor() {
    this.register(new NoteTool());
    this.register(new TimeTool());
  }

  register(tool: AgentTool): void {
    this.tools.set(tool.name(), tool);
  }

  describeTools(): string {
    let description = '';
    this.tools.forEach((tool: AgentTool) => {
      description += `- ${tool.name()}: ${tool.description()}\n`;
    });
    return description;
  }

  async run(name: string, input: string): Promise<string> {
    const tool = this.tools.get(name);
    if (tool === undefined) {
      return `Unknown tool: ${name}`;
    }
    return await tool.run(input ?? '');
  }
}

export function createLoopToolRegistry(): ToolRegistry {
  const registry = new ToolRegistry();
  registry.register(new UiTool());
  return registry;
}
