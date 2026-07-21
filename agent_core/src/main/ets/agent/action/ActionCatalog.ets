import { ToolDefinition } from '../../aiphone/runtime/ToolDefinitionTypes';
import {
  ActionArgsValidator,
  ActionCatalogResult,
  ClientActionAuthorizer,
  SurfaceActionAuthorizer,
  ToolDefinitionLookup
} from './ActionCatalogTypes';

const WORKFLOW_ENTRY_ACTION_ID = 'workflow.run';

function denied(code: string, message: string): ActionCatalogResult {
  return {
    ok: false,
    code: code,
    message: message,
    definition: null
  };
}

function allowed(definition: ToolDefinition | null): ActionCatalogResult {
  return {
    ok: true,
    code: '',
    message: '',
    definition: definition
  };
}

function hasObjectArgs(args: Object): boolean {
  return args !== null && typeof args === 'object' && !Array.isArray(args);
}

function malformedArgs(): ActionCatalogResult {
  return denied('ACTION_ARGS_MALFORMED', 'Action args must be a non-array object.');
}

function authorityFailed(): ActionCatalogResult {
  return denied('ACTION_AUTHORITY_FAILED', 'Action authority failed.');
}

export class ActionCatalog {
  private lookup: ToolDefinitionLookup;
  private surfaceAuthorizer: SurfaceActionAuthorizer;
  private clientAuthorizer: ClientActionAuthorizer;
  private argsValidator: ActionArgsValidator;

  constructor(
    lookup: ToolDefinitionLookup,
    surfaceAuthorizer: SurfaceActionAuthorizer,
    clientAuthorizer: ClientActionAuthorizer,
    argsValidator: ActionArgsValidator
  ) {
    this.lookup = lookup;
    this.surfaceAuthorizer = surfaceAuthorizer;
    this.clientAuthorizer = clientAuthorizer;
    this.argsValidator = argsValidator;
  }

  validatePlacement(sourceToolId: string, actionId: string, args: Object): ActionCatalogResult {
    if (!hasObjectArgs(args)) {
      return malformedArgs();
    }
    try {
      const source = this.lookup.find(sourceToolId);
      if (source === null) {
        return denied('ACTION_SOURCE_NOT_REGISTERED', 'Source tool is not registered.');
      }
      if (source.actions.indexOf(actionId) < 0 && sourceToolId !== actionId) {
        return denied('ACTION_NOT_DECLARED', 'Action is not declared by the source tool.');
      }
      return this.validateEntryTarget(actionId, args);
    } catch (_error) {
      return authorityFailed();
    }
  }

  validateSurfaceExecution(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    sourceToolId: string,
    actionId: string,
    args: Object
  ): ActionCatalogResult {
    if (!hasObjectArgs(args)) {
      return malformedArgs();
    }
    try {
      const placement = sourceToolId === actionId ?
        this.validateRegisteredStep(actionId, args) :
        this.validatePlacement(sourceToolId, actionId, args);
      if (!placement.ok) {
        return placement;
      }
      if (!this.surfaceAuthorizer.allows(conversationId, turnId, surfaceId, actionId, args)) {
        return denied('ACTION_SURFACE_DENIED', 'Action does not match the current surface.');
      }
      return placement;
    } catch (_error) {
      return authorityFailed();
    }
  }

  validateRegisteredStep(actionId: string, args: Object): ActionCatalogResult {
    if (!hasObjectArgs(args)) {
      return malformedArgs();
    }
    try {
      const current = this.validateRegisteredAction(actionId);
      if (!current.ok) {
        return current;
      }
      const validation = this.argsValidator.validate(actionId, args);
      if (!validation.ok) {
        return denied(validation.code, validation.message);
      }
      return current;
    } catch (_error) {
      return authorityFailed();
    }
  }

  validateRegisteredAction(actionId: string): ActionCatalogResult {
    try {
      if (actionId === WORKFLOW_ENTRY_ACTION_ID) {
        return denied('ACTION_WORKFLOW_ENTRY_ONLY', 'workflow.run is only a surface workflow entry.');
      }
      const definition = this.lookup.find(actionId);
      if (definition === null) {
        return denied('ACTION_NOT_REGISTERED', 'Action is not a registered executable step.');
      }
      return this.validateRegisteredAvailability(definition);
    } catch (_error) {
      return authorityFailed();
    }
  }

  private validateEntryTarget(actionId: string, args: Object): ActionCatalogResult {
    const definition = this.lookup.find(actionId);
    if (definition !== null) {
      return this.validateRegisteredDefinition(definition, args);
    }
    if (actionId === WORKFLOW_ENTRY_ACTION_ID) {
      return this.validateUnregisteredEntry(actionId, args);
    }
    if (this.clientAuthorizer.allows(actionId, args)) {
      return this.validateUnregisteredEntry(actionId, args);
    }
    return denied('ACTION_NOT_REGISTERED', 'Action is not registered by any current authority.');
  }

  private validateRegisteredDefinition(definition: ToolDefinition, args: Object): ActionCatalogResult {
    const current = this.validateRegisteredAvailability(definition);
    if (!current.ok) {
      return current;
    }
    const validation = this.argsValidator.validate(definition.toolId, args);
    if (!validation.ok) {
      return denied(validation.code, validation.message);
    }
    return current;
  }

  private validateRegisteredAvailability(definition: ToolDefinition): ActionCatalogResult {
    if (definition.riskLevel === 'blocked') {
      return denied('ACTION_BLOCKED', 'Action is blocked by its current risk metadata.');
    }
    if (definition.backendPriority.length === 0) {
      return denied('ACTION_BACKEND_MISSING', 'Action has no current execution backend.');
    }
    return allowed(definition);
  }

  private validateUnregisteredEntry(actionId: string, args: Object): ActionCatalogResult {
    const validation = this.argsValidator.validate(actionId, args);
    if (!validation.ok) {
      return denied(validation.code, validation.message);
    }
    return allowed(null);
  }
}
