import { CapabilityManifest } from './CapabilityManifest';
import { ToolHandlerBinding } from './BackendTypes';
import { ToolEffectRule } from './ToolEffect';
import { ToolPresenterBinding } from './PresenterTypes';
import { ToolSchemaBinding } from './SchemaTypes';
import { ToolSpec } from './ToolSpec';

export interface ActionLink {
  sourceToolId: string;
  targetToolId: string;
}

export interface ToolPlanningProfile {
  toolId: string;
  summary: string;
  useWhen: string;
  avoidWhen: string;
}

export interface CapabilityModule {
  manifest(): CapabilityManifest;
  toolSpecs(): ToolSpec[];
  schemaBindings(): ToolSchemaBinding[];
  handlerBindings(): ToolHandlerBinding[];
  presenterBindings(): ToolPresenterBinding[];
  actionLinks(): ActionLink[];
  planningProfiles(): ToolPlanningProfile[];
  effectRules(): ToolEffectRule[];
}
