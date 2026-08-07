import { ToolDefinition } from '../../../../aiphone/runtime/ToolDefinitionTypes';
import {
  LegacyHandlerBindingFactory,
  LegacyToolRegistryAdapter
} from '../../../compatibility/LegacyToolRegistryAdapter';

export class HotelCapabilityModule extends LegacyToolRegistryAdapter {
  constructor(definitions: ToolDefinition[], handlers: LegacyHandlerBindingFactory) {
    super('travel.hotel', definitions, handlers);
  }
}
