import { allToolDefinitions } from '../../aiphone/runtime/ToolDefinitionRegistry';
import { ToolDefinition } from '../../aiphone/runtime/ToolDefinitionTypes';
import { LegacyToolGatewayAdapter } from '../compatibility/LegacyToolGatewayAdapter';
import { capabilityIdForLegacyDomain } from '../compatibility/LegacyToolDefinitionAdapter';
import { LegacyToolRegistryAdapter } from '../compatibility/LegacyToolRegistryAdapter';
import { CapabilityModule } from '../contracts/CapabilityModule';
import { DynamicSearchCapabilityModule } from '../discovery/DynamicSearchCapabilityModule';
import { CalendarCapabilityModule } from '../domains/productivity/calendar/CalendarCapabilityModule';
import { HotelCapabilityModule } from '../domains/travel/hotel/HotelCapabilityModule';

export class ApplessCapabilityModules {
  static create(handlers: LegacyToolGatewayAdapter): CapabilityModule[] {
    const grouped: Map<string, ToolDefinition[]> = new Map<string, ToolDefinition[]>();
    allToolDefinitions().forEach((definition: ToolDefinition) => {
      const capabilityId = capabilityIdForLegacyDomain(definition.domain);
      const definitions = grouped.get(capabilityId) ?? [];
      definitions.push(definition);
      grouped.set(capabilityId, definitions);
    });
    const modules: CapabilityModule[] = [];
    grouped.forEach((definitions: ToolDefinition[], capabilityId: string) => {
      if (capabilityId === 'travel.hotel') {
        modules.push(new HotelCapabilityModule(definitions, handlers));
      } else if (capabilityId === 'productivity.calendar') {
        modules.push(new CalendarCapabilityModule(definitions, handlers));
      } else {
        modules.push(new LegacyToolRegistryAdapter(capabilityId, definitions, handlers));
      }
    });
    modules.push(new DynamicSearchCapabilityModule(handlers));
    return modules;
  }
}
