import { TimeTool } from './TimeTool';
import { ToolRegistry } from './ToolRegistry';
import { UiTool } from './UiTool';

export function createUIMakerToolRegistry(): ToolRegistry {
  const registry = new ToolRegistry();
  registry.register(new TimeTool());
  registry.register(new UiTool());
  return registry;
}
