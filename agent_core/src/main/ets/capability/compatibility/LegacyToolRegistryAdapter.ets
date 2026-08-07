import { ToolDefinition } from '../../aiphone/runtime/ToolDefinitionTypes';
import { ToolHandlerBinding } from '../contracts/BackendTypes';
import { CapabilityManifest } from '../contracts/CapabilityManifest';
import { ActionLink, CapabilityModule, ToolPlanningProfile } from '../contracts/CapabilityModule';
import { ToolEffectRule } from '../contracts/ToolEffect';
import { ToolPresenterBinding } from '../contracts/PresenterTypes';
import { ToolSchemaBinding } from '../contracts/SchemaTypes';
import { ToolSpec } from '../contracts/ToolSpec';
import { A2uiLegacyAdapter } from '../presentation/a2ui/A2uiLegacyAdapter';
import { LegacySchemaAdapter } from './LegacySchemaAdapter';
import {
  legacyActionLinks,
  legacyCapabilityManifest,
  legacyPlanningProfile,
  legacyToolDefinitionToSpec
} from './LegacyToolDefinitionAdapter';

export interface LegacyHandlerBindingFactory {
  bindings(definition: ToolDefinition, spec: ToolSpec): ToolHandlerBinding[];
}

export class LegacyToolRegistryAdapter implements CapabilityModule {
  private readonly definitions: ToolDefinition[];
  private readonly capabilityId: string;
  private readonly handlers: LegacyHandlerBindingFactory;

  constructor(capabilityId: string, definitions: ToolDefinition[], handlers: LegacyHandlerBindingFactory) {
    this.capabilityId = capabilityId;
    this.definitions = definitions.slice();
    this.handlers = handlers;
  }

  manifest(): CapabilityManifest {
    return legacyCapabilityManifest(this.capabilityId, this.definitions);
  }

  toolSpecs(): ToolSpec[] {
    return this.definitions.map((definition: ToolDefinition): ToolSpec => legacyToolDefinitionToSpec(definition));
  }

  schemaBindings(): ToolSchemaBinding[] {
    const result: ToolSchemaBinding[] = [];
    const keys: Set<string> = new Set<string>();
    this.definitions.forEach((definition: ToolDefinition) => {
      const inputKey = definition.inputSchema + '@1.0.0';
      if (!keys.has(inputKey)) {
        keys.add(inputKey);
        result.push({
          ref: { id: definition.inputSchema, version: '1.0.0' },
          validator: new LegacySchemaAdapter()
        });
      }
      const outputKey = definition.outputSchema + '@1.0.0';
      if (!keys.has(outputKey)) {
        keys.add(outputKey);
        result.push({
          ref: { id: definition.outputSchema, version: '1.0.0' },
          validator: new LegacySchemaAdapter()
        });
      }
    });
    return result;
  }

  handlerBindings(): ToolHandlerBinding[] {
    const result: ToolHandlerBinding[] = [];
    this.definitions.forEach((definition: ToolDefinition) => {
      const bindings = this.handlers.bindings(definition, legacyToolDefinitionToSpec(definition));
      bindings.forEach((binding: ToolHandlerBinding) => result.push(binding));
    });
    return result;
  }

  presenterBindings(): ToolPresenterBinding[] {
    const result: ToolPresenterBinding[] = [];
    const keys: Set<string> = new Set<string>();
    this.definitions.forEach((definition: ToolDefinition) => {
      const key = definition.outputSchema + '@*';
      if (keys.has(key)) return;
      keys.add(key);
      result.push({
        presenterId: 'legacy:' + definition.a2uiComponent,
        outputSchemaRef: definition.outputSchema,
        surfaceKind: '*',
        presenter: new A2uiLegacyAdapter('legacy:' + definition.a2uiComponent, definition.a2uiComponent)
      });
    });
    return result;
  }

  actionLinks(): ActionLink[] {
    const result: ActionLink[] = [];
    this.definitions.forEach((definition: ToolDefinition) => {
      legacyActionLinks(definition).forEach((link: ActionLink) => result.push(link));
    });
    return result;
  }

  planningProfiles(): ToolPlanningProfile[] {
    return this.definitions.map((definition: ToolDefinition): ToolPlanningProfile => legacyPlanningProfile(definition));
  }

  effectRules(): ToolEffectRule[] {
    return [];
  }
}
