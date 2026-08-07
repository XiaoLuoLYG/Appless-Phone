import { ToolDefinition } from '../../../../aiphone/runtime/ToolDefinitionTypes';
import {
  LegacyHandlerBindingFactory,
  LegacyToolRegistryAdapter
} from '../../../compatibility/LegacyToolRegistryAdapter';

export class CalendarCapabilityModule extends LegacyToolRegistryAdapter {
  constructor(definitions: ToolDefinition[], handlers: LegacyHandlerBindingFactory) {
    super('productivity.calendar', definitions, handlers);
  }
}
