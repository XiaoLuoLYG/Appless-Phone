import { ToolDefinition } from '../../aiphone/runtime/ToolDefinitionTypes';

export interface ToolDefinitionLookup {
  find(toolId: string): ToolDefinition | null;
}

export interface SurfaceActionAuthorizer {
  allows(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    actionId: string,
    args: Object
  ): boolean;
}

export interface ClientActionAuthorizer {
  allows(actionId: string, args: Object): boolean;
}

export interface ActionValidationResult {
  ok: boolean;
  code: string;
  message: string;
}

export interface ActionArgsValidator {
  validate(actionId: string, args: Object): ActionValidationResult;
}

export interface ActionCatalogResult {
  ok: boolean;
  code: string;
  message: string;
  definition: ToolDefinition | null;
}
