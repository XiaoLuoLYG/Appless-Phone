import { CapabilityManifest } from '../contracts/CapabilityManifest';
import { CapabilityModule } from '../contracts/CapabilityModule';
import { ToolSpec } from '../contracts/ToolSpec';

export interface RegistryValidationResult {
  ok: boolean;
  code: string;
  message: string;
}

function invalid(code: string, message: string): RegistryValidationResult {
  return { ok: false, code, message };
}

export class RegistryValidator {
  validateModule(module: CapabilityModule, existingToolIds: Set<string>): RegistryValidationResult {
    const manifest = module.manifest();
    const specs = module.toolSpecs();
    if (manifest.id.trim().length === 0 || manifest.version.trim().length === 0) {
      return invalid('CAPABILITY_MANIFEST_INVALID', 'Capability id and version are required.');
    }
    const manifestIds = new Set<string>();
    for (let index = 0; index < manifest.toolIds.length; index++) {
      const toolId = manifest.toolIds[index];
      if (toolId.trim().length === 0 || manifestIds.has(toolId)) {
        return invalid('CAPABILITY_TOOL_ID_INVALID', 'Capability tool ids must be unique and non-empty.');
      }
      manifestIds.add(toolId);
    }
    if (manifestIds.size !== specs.length) {
      return invalid('CAPABILITY_TOOL_SET_MISMATCH', 'Manifest and ToolSpec counts do not match.');
    }
    for (let index = 0; index < specs.length; index++) {
      const result = this.validateSpec(manifest, specs[index], manifestIds, existingToolIds);
      if (!result.ok) {
        return result;
      }
    }
    return { ok: true, code: '', message: '' };
  }

  private validateSpec(
    manifest: CapabilityManifest,
    spec: ToolSpec,
    manifestIds: Set<string>,
    existingToolIds: Set<string>
  ): RegistryValidationResult {
    if (!manifestIds.has(spec.id) || spec.capabilityId !== manifest.id) {
      return invalid('CAPABILITY_TOOL_OWNERSHIP_INVALID', 'Tool ownership does not match its manifest.');
    }
    if (existingToolIds.has(spec.id)) {
      return invalid('CAPABILITY_TOOL_DUPLICATE', 'Tool is already registered: ' + spec.id);
    }
    if (spec.version.trim().length === 0 || spec.inputSchemaRef.id.trim().length === 0 ||
      spec.outputSchemaRef.id.trim().length === 0) {
      return invalid('CAPABILITY_TOOL_SPEC_INVALID', 'Tool version and schemas are required: ' + spec.id);
    }
    if (spec.backendCandidates.length === 0 || spec.declaredEffects.length === 0) {
      return invalid('CAPABILITY_TOOL_EXECUTION_INVALID', 'Tool effects and backends are required: ' + spec.id);
    }
    for (let effectIndex = 0; effectIndex < spec.declaredEffects.length; effectIndex++) {
      const permission = spec.declaredEffects[effectIndex].kind;
      if (manifest.requiredPermissions.indexOf(permission) < 0) {
        return invalid('CAPABILITY_PERMISSION_MISSING', 'Manifest does not declare effect permission ' + permission + '.');
      }
    }
    return { ok: true, code: '', message: '' };
  }
}
