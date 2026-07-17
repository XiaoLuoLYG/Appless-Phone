import { common } from '@kit.AbilityKit';
import { ComposioConfig } from '../composio/ComposioConfig';
import { ComposioSessionClient } from '../composio/ComposioSessionClient';
import { ComposioTool } from '../composio/ComposioTool';
import { SandboxFileWriteTool } from '../file/SandboxFileWriteTool';
import { SkillReadTool } from '../skill/SkillReadTool';
import { SkillSnapshot } from '../skill/SkillSnapshot';
import { AgentTool } from './AgentTool';
import { UiTool } from './UiTool';

export type ToolRegistryCloseHandler = () => Promise<void>;

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
  private closeHandlers: ToolRegistryCloseHandler[] = [];

  constructor() {
    this.register(new NoteTool());
    this.register(new TimeTool());
  }

  register(tool: AgentTool): void {
    this.tools.set(tool.name(), tool);
  }

  has(name: string): boolean {
    return this.tools.has(name);
  }

  registerCloseHandler(handler: ToolRegistryCloseHandler): void {
    this.closeHandlers.push(handler);
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

  async close(): Promise<void> {
    for (let index = 0; index < this.closeHandlers.length; index++) {
      try {
        await this.closeHandlers[index]();
      } catch (_error) {
      }
    }
  }
}

export async function createConfiguredLoopToolRegistry(
  context: common.UIAbilityContext,
  skillSnapshot?: SkillSnapshot | null
): Promise<ToolRegistry> {
  const registry = createLoopToolRegistry(skillSnapshot);
  if (skillSnapshot !== undefined && skillSnapshot !== null && !skillSnapshot.isEmpty()) {
    registry.register(new SandboxFileWriteTool(context));
  }
  const client = new ComposioSessionClient(await ComposioConfig.fromContext(context));
  await client.initialize();
  registry.register(new ComposioTool(client));
  registry.registerCloseHandler(async (): Promise<void> => client.close());
  return registry;
}

export function createLoopToolRegistry(skillSnapshot?: SkillSnapshot | null): ToolRegistry {
  const registry = new ToolRegistry();
  registry.register(new UiTool());
  if (skillSnapshot !== undefined && skillSnapshot !== null && !skillSnapshot.isEmpty()) {
    registry.register(new SkillReadTool(skillSnapshot));
  }
  return registry;
}
