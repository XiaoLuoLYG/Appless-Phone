import { CreateUiTaskTool } from './CreateUiTaskTool';
import { MessageBus } from './MessageBus';
import { TimeTool } from './TimeTool';
import { ToolRegistry } from './ToolRegistry';

export function createLeaderToolRegistry(bus: MessageBus): ToolRegistry {
  const registry = new ToolRegistry();
  registry.register(new CreateUiTaskTool(bus));
  registry.register(new TimeTool());
  return registry;
}
