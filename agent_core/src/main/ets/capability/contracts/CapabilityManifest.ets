export interface CapabilityManifest {
  id: string;
  version: string;
  displayName: string;
  domains: string[];
  toolIds: string[];
  presenterIds: string[];
  skillRefs: string[];
  requiredPermissions: string[];
  supportedSurfaces: string[];
  dynamic: boolean;
}

export function cloneCapabilityManifest(manifest: CapabilityManifest): CapabilityManifest {
  return {
    id: manifest.id,
    version: manifest.version,
    displayName: manifest.displayName,
    domains: manifest.domains.slice(),
    toolIds: manifest.toolIds.slice(),
    presenterIds: manifest.presenterIds.slice(),
    skillRefs: manifest.skillRefs.slice(),
    requiredPermissions: manifest.requiredPermissions.slice(),
    supportedSurfaces: manifest.supportedSurfaces.slice(),
    dynamic: manifest.dynamic
  };
}
