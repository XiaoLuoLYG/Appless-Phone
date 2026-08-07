export type ToolArtifactKind = 'a2ui_surface' | 'url' | 'provider_receipt';

export interface ToolArtifactRef {
  artifactId: string;
  kind: ToolArtifactKind;
  label: string;
  reference: string;
}
