import { CapabilityModule } from '../contracts/CapabilityModule';
import { CapabilityRegistry } from '../registry/CapabilityRegistry';
import { RegistryValidationResult } from '../registry/RegistryValidator';

export class DynamicCapabilityRegistry {
  private readonly registry: CapabilityRegistry;

  constructor(registry: CapabilityRegistry) {
    this.registry = registry;
  }

  registerEphemeral(module: CapabilityModule): RegistryValidationResult {
    const manifest = module.manifest();
    if (!manifest.dynamic) {
      return { ok: false, code: 'DYNAMIC_MANIFEST_REQUIRED', message: 'Ephemeral capabilities must be marked dynamic.' };
    }
    return this.registry.registerCapability(module);
  }
}
