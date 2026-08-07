import { LegacyToolGatewayAdapter } from '../compatibility/LegacyToolGatewayAdapter';
import { CapabilityModule } from '../contracts/CapabilityModule';
import { CapabilityRegistry } from '../registry/CapabilityRegistry';
import { ApplessCapabilityModules } from './ApplessCapabilityModules';

export class ApplessCapabilityRegistryFactory {
  static create(handlers: LegacyToolGatewayAdapter): CapabilityRegistry {
    const registry = new CapabilityRegistry();
    const modules = ApplessCapabilityModules.create(handlers);
    for (let index = 0; index < modules.length; index++) {
      const module: CapabilityModule = modules[index];
      const validation = registry.registerCapability(module);
      if (!validation.ok) throw new Error(validation.code + ': ' + validation.message);
    }
    const integrity = registry.validateIntegrity();
    if (!integrity.ok) throw new Error(integrity.code + ': ' + integrity.message);
    return registry;
  }
}
