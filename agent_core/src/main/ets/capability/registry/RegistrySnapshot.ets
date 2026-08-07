import { CapabilityManifest, cloneCapabilityManifest } from '../contracts/CapabilityManifest';
import { ToolSpec, cloneToolSpec } from '../contracts/ToolSpec';

export interface RegistrySnapshot {
  capabilities: CapabilityManifest[];
  tools: ToolSpec[];
}

export function cloneRegistrySnapshot(snapshot: RegistrySnapshot): RegistrySnapshot {
  return {
    capabilities: snapshot.capabilities.map(
      (manifest: CapabilityManifest): CapabilityManifest => cloneCapabilityManifest(manifest)
    ),
    tools: snapshot.tools.map((spec: ToolSpec): ToolSpec => cloneToolSpec(spec))
  };
}
