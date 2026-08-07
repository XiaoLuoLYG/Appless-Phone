import { ToolPlanningProfile } from '../contracts/CapabilityModule';
import { ToolSpec } from '../contracts/ToolSpec';

export interface LegacyAgentToolView {
  name: string;
  description: string;
  inputSchema: string;
}

export function legacyAgentToolView(spec: ToolSpec, profile: ToolPlanningProfile | null): LegacyAgentToolView {
  return {
    name: spec.id,
    description: profile === null ? spec.id : profile.summary + ' ' + profile.useWhen,
    inputSchema: spec.inputSchemaRef.id
  };
}
