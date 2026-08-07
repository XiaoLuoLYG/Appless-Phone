import { CapabilityManifest, cloneCapabilityManifest } from '../contracts/CapabilityManifest';
import { CapabilityModule } from '../contracts/CapabilityModule';
import { ToolEffectRule } from '../contracts/ToolEffect';
import { ToolSpec, cloneToolSpec } from '../contracts/ToolSpec';
import { ActionLinkRegistry } from './ActionLinkRegistry';
import { HandlerRegistry } from './HandlerRegistry';
import { PlanningProfileRegistry } from './PlanningProfileRegistry';
import { PresenterRegistry } from './PresenterRegistry';
import { RegistrySnapshot } from './RegistrySnapshot';
import { RegistryValidationResult, RegistryValidator } from './RegistryValidator';
import { SchemaRegistry } from './SchemaRegistry';

export class CapabilityRegistry {
  readonly schemas: SchemaRegistry = new SchemaRegistry();
  readonly handlers: HandlerRegistry = new HandlerRegistry();
  readonly presenters: PresenterRegistry = new PresenterRegistry();
  readonly planningProfiles: PlanningProfileRegistry = new PlanningProfileRegistry();
  readonly actionLinks: ActionLinkRegistry = new ActionLinkRegistry();
  private readonly manifests: Map<string, CapabilityManifest> = new Map<string, CapabilityManifest>();
  private readonly tools: Map<string, ToolSpec> = new Map<string, ToolSpec>();
  private readonly effectRules: Map<string, ToolEffectRule> = new Map<string, ToolEffectRule>();
  private readonly validator: RegistryValidator = new RegistryValidator();

  registerCapability(module: CapabilityModule): RegistryValidationResult {
    const existingToolIds = new Set<string>();
    this.tools.forEach((_spec: ToolSpec, toolId: string) => existingToolIds.add(toolId));
    const validation = this.validator.validateModule(module, existingToolIds);
    if (!validation.ok) {
      return validation;
    }
    const manifest = module.manifest();
    if (this.manifests.has(manifest.id)) {
      return {
        ok: false,
        code: 'CAPABILITY_DUPLICATE',
        message: 'Capability is already registered: ' + manifest.id
      };
    }
    const specs = module.toolSpecs();
    this.manifests.set(manifest.id, cloneCapabilityManifest(manifest));
    for (let index = 0; index < specs.length; index++) {
      this.tools.set(specs[index].id, cloneToolSpec(specs[index]));
    }
    module.schemaBindings().forEach((binding) => this.schemas.register(binding));
    module.handlerBindings().forEach((binding) => this.handlers.register(binding));
    module.presenterBindings().forEach((binding) => this.presenters.register(binding));
    module.actionLinks().forEach((link) => this.actionLinks.register(link));
    module.planningProfiles().forEach((profile) => this.planningProfiles.register(profile));
    module.effectRules().forEach((rule: ToolEffectRule) => {
      this.effectRules.set(rule.toolId, {
        toolId: rule.toolId,
        effects: rule.effects.slice()
      });
    });
    return { ok: true, code: '', message: '' };
  }

  findCapability(id: string): CapabilityManifest | null {
    const manifest = this.manifests.get(id);
    return manifest === undefined ? null : cloneCapabilityManifest(manifest);
  }

  findTool(toolId: string): ToolSpec | null {
    const spec = this.tools.get(toolId);
    return spec === undefined ? null : cloneToolSpec(spec);
  }

  capabilityForTool(toolId: string): CapabilityManifest | null {
    const spec = this.tools.get(toolId);
    return spec === undefined ? null : this.findCapability(spec.capabilityId);
  }

  listCapabilities(): CapabilityManifest[] {
    const result: CapabilityManifest[] = [];
    this.manifests.forEach((manifest: CapabilityManifest) => result.push(cloneCapabilityManifest(manifest)));
    return result;
  }

  listTools(): ToolSpec[] {
    const result: ToolSpec[] = [];
    this.tools.forEach((spec: ToolSpec) => result.push(cloneToolSpec(spec)));
    return result;
  }

  snapshot(): RegistrySnapshot {
    return { capabilities: this.listCapabilities(), tools: this.listTools() };
  }

  validateIntegrity(): RegistryValidationResult {
    const specs = this.listTools();
    for (let index = 0; index < specs.length; index++) {
      const spec = specs[index];
      if (!this.schemas.has(spec.inputSchemaRef) || !this.schemas.has(spec.outputSchemaRef)) {
        return { ok: false, code: 'SCHEMA_BINDING_MISSING', message: 'Schema binding is missing for ' + spec.id + '.' };
      }
      let hasHandler = false;
      for (let backendIndex = 0; backendIndex < spec.backendCandidates.length; backendIndex++) {
        if (this.handlers.has(spec.id, spec.backendCandidates[backendIndex].backendId)) hasHandler = true;
      }
      if (!hasHandler) {
        return { ok: false, code: 'HANDLER_BINDING_MISSING', message: 'Handler binding is missing for ' + spec.id + '.' };
      }
      if (!this.presenters.has(spec.outputSchemaRef.id)) {
        return { ok: false, code: 'PRESENTER_BINDING_MISSING', message: 'Presenter binding is missing for ' + spec.id + '.' };
      }
      if (this.planningProfiles.find(spec.id) === null) {
        return { ok: false, code: 'PLANNING_PROFILE_MISSING', message: 'Planning profile is missing for ' + spec.id + '.' };
      }
    }
    const links = this.actionLinks.all();
    for (let linkIndex = 0; linkIndex < links.length; linkIndex++) {
      if (!this.tools.has(links[linkIndex].sourceToolId) || links[linkIndex].targetToolId.trim().length === 0) {
        return { ok: false, code: 'ACTION_LINK_INVALID', message: 'ActionLink has an invalid source or target ID.' };
      }
    }
    return { ok: true, code: '', message: '' };
  }
}
