import { ToolDefinition } from '../../aiphone/runtime/ToolDefinitionTypes';
import { CapabilityRegistry } from '../registry/CapabilityRegistry';

export class LegacyToolRegistryFacade {
  private readonly registry: CapabilityRegistry;

  constructor(registry: CapabilityRegistry) {
    this.registry = registry;
  }

  contains(toolId: string): boolean {
    return this.registry.findTool(toolId) !== null;
  }

  filterDefinitions(definitions: ToolDefinition[], riskLevel: string): ToolDefinition[] {
    return definitions.filter((definition: ToolDefinition): boolean => {
      const spec = this.registry.findTool(definition.toolId);
      return spec !== null && spec.riskLevel === riskLevel;
    });
  }
}
