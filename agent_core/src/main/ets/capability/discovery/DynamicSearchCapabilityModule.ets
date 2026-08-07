import { ToolDefinition } from '../../aiphone/runtime/ToolDefinitionTypes';
import { CapabilityManifest } from '../contracts/CapabilityManifest';
import { LegacyHandlerBindingFactory, LegacyToolRegistryAdapter } from '../compatibility/LegacyToolRegistryAdapter';

const DYNAMIC_SEARCH_DEFINITION: ToolDefinition = {
  toolId: 'dynamic.search',
  domain: 'connectors',
  intent: 'dynamic.search',
  riskLevel: 'read',
  backendPriority: ['local_adapter'],
  authModes: ['none'],
  inputSchema: 'dynamicSearchQuery',
  outputSchema: 'genericToolResults',
  a2uiComponent: 'GenericToolResults',
  actions: []
};

export class DynamicSearchCapabilityModule extends LegacyToolRegistryAdapter {
  constructor(handlers: LegacyHandlerBindingFactory) {
    super('dynamic_connectors', [DYNAMIC_SEARCH_DEFINITION], handlers);
  }

  manifest(): CapabilityManifest {
    const manifest = super.manifest();
    manifest.dynamic = true;
    return manifest;
  }
}
