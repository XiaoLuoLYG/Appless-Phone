import { describe, it, expect } from '@ohos/hypium';
import {
  ActionArgsValidator,
  ActionCatalog,
  ActionCatalogResult,
  ActionValidationResult,
  ClientActionAuthorizer,
  SurfaceActionAuthorizer,
  ToolDefinitionLookup
} from '@loop/agent-core';
import { ToolBackendType, ToolDefinition, ToolRiskLevel } from '@loop/agent-core';

function args(raw: string): Object {
  return JSON.parse(raw) as Object;
}

function definition(
  toolId: string,
  riskLevel: ToolRiskLevel,
  backend: ToolBackendType,
  actions: string[]
): ToolDefinition {
  return {
    toolId: toolId,
    domain: 'hotel',
    intent: toolId,
    riskLevel: riskLevel,
    backendPriority: backend.length === 0 ? [] : [backend],
    authModes: ['provider_key'],
    inputSchema: toolId + 'Request',
    outputSchema: toolId + 'Result',
    a2uiComponent: 'GenericToolResults',
    actions: actions.slice()
  };
}

class FakeToolDefinitionLookup implements ToolDefinitionLookup {
  sourceActions: string[];
  targetRisk: ToolRiskLevel = 'read';
  targetBackend: ToolBackendType = 'local_adapter';
  targetHasBackend: boolean = true;

  constructor(sourceActions: string[]) {
    this.sourceActions = sourceActions;
  }

  find(toolId: string): ToolDefinition | null {
    if (toolId === 'hotel.search') {
      return definition('hotel.search', 'read', 'local_adapter', this.sourceActions);
    }
    if (toolId === 'hotel.detail' || toolId === 'hotel.navigate' || toolId === 'hotel.call') {
      const target = definition(toolId, this.targetRisk, this.targetBackend, []);
      if (!this.targetHasBackend) {
        target.backendPriority = [];
      }
      return target;
    }
    return null;
  }
}

class ExactSurfaceAuthorizer implements SurfaceActionAuthorizer {
  conversationId: string;
  turnId: string;
  surfaceId: string;
  actionId: string;
  serializedArgs: string;
  calls: number = 0;

  constructor(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    actionId: string,
    expectedArgs: Object
  ) {
    this.conversationId = conversationId;
    this.turnId = turnId;
    this.surfaceId = surfaceId;
    this.actionId = actionId;
    this.serializedArgs = JSON.stringify(expectedArgs);
  }

  allows(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    actionId: string,
    actualArgs: Object
  ): boolean {
    this.calls += 1;
    return conversationId === this.conversationId &&
      turnId === this.turnId &&
      surfaceId === this.surfaceId &&
      actionId === this.actionId &&
      JSON.stringify(actualArgs) === this.serializedArgs;
  }
}

class ExactClientAuthorizer implements ClientActionAuthorizer {
  actionId: string;
  serializedArgs: string;

  constructor(actionId: string, expectedArgs: Object) {
    this.actionId = actionId;
    this.serializedArgs = JSON.stringify(expectedArgs);
  }

  allows(actionId: string, actualArgs: Object): boolean {
    return actionId === this.actionId && JSON.stringify(actualArgs) === this.serializedArgs;
  }
}

class RejectClientAuthorizer implements ClientActionAuthorizer {
  allows(_actionId: string, _args: Object): boolean {
    return false;
  }
}

class ControlledArgsValidator implements ActionArgsValidator {
  allowed: boolean = true;
  calls: number = 0;

  validate(_actionId: string, _args: Object): ActionValidationResult {
    this.calls += 1;
    if (this.allowed) {
      return {
        ok: true,
        code: '',
        message: ''
      };
    }
    return {
      ok: false,
      code: 'ARGS_INVALID',
      message: 'Target args are invalid.'
    };
  }
}

function catalog(
  lookup: ToolDefinitionLookup,
  surface: SurfaceActionAuthorizer,
  client: ClientActionAuthorizer,
  validator: ActionArgsValidator
): ActionCatalog {
  return new ActionCatalog(lookup, surface, client, validator);
}

export default function actionCatalogTest() {
  describe('actionCatalog', () => {
    it('allows a declared registered hotel detail and returns fresh metadata', 0, () => {
      const detailArgs = args('{"hotelId":47675}');
      const lookup = new FakeToolDefinitionLookup(['hotel.detail']);
      const surface = new ExactSurfaceAuthorizer('conversation-1', 'turn-1', 'surface-1', 'hotel.detail', detailArgs);
      const validator = new ControlledArgsValidator();
      const actionCatalog = catalog(lookup, surface, new RejectClientAuthorizer(), validator);

      const placement: ActionCatalogResult =
        actionCatalog.validatePlacement('hotel.search', 'hotel.detail', detailArgs);
      expect(placement.ok).assertTrue();
      expect((placement.definition as ToolDefinition).riskLevel).assertEqual('read');
      expect((placement.definition as ToolDefinition).backendPriority[0]).assertEqual('local_adapter');

      lookup.targetRisk = 'draft';
      lookup.targetBackend = 'system_intent';
      const execution: ActionCatalogResult = actionCatalog.validateSurfaceExecution(
        'conversation-1',
        'turn-1',
        'surface-1',
        'hotel.search',
        'hotel.detail',
        detailArgs
      );
      expect(execution.ok).assertTrue();
      expect((execution.definition as ToolDefinition).riskLevel).assertEqual('draft');
      expect((execution.definition as ToolDefinition).backendPriority[0]).assertEqual('system_intent');
    });

    it('rejects invented hotel book even when declared and allowed by the surface', 0, () => {
      const bookArgs = args('{"hotelId":47675,"ratePlanId":"provider-rate-1"}');
      const lookup = new FakeToolDefinitionLookup(['hotel.book']);
      const surface = new ExactSurfaceAuthorizer('conversation-1', 'turn-1', 'surface-1', 'hotel.book', bookArgs);
      const actionCatalog = catalog(
        lookup,
        surface,
        new RejectClientAuthorizer(),
        new ControlledArgsValidator()
      );

      expect(actionCatalog.validatePlacement('hotel.search', 'hotel.book', bookArgs).ok).assertFalse();
      expect(actionCatalog.validateSurfaceExecution(
        'conversation-1',
        'turn-1',
        'surface-1',
        'hotel.search',
        'hotel.book',
        bookArgs
      ).ok).assertFalse();
      expect(surface.calls).assertEqual(0);
    });

    it('rejects placement not declared by the source without consulting surface policy', 0, () => {
      const detailArgs = args('{"hotelId":47675}');
      const lookup = new FakeToolDefinitionLookup([]);
      const surface = new ExactSurfaceAuthorizer('conversation-1', 'turn-1', 'surface-1', 'hotel.detail', detailArgs);
      const actionCatalog = catalog(
        lookup,
        surface,
        new RejectClientAuthorizer(),
        new ControlledArgsValidator()
      );

      const result: ActionCatalogResult =
        actionCatalog.validatePlacement('hotel.search', 'hotel.detail', detailArgs);
      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('ACTION_NOT_DECLARED');
      expect(surface.calls).assertEqual(0);
    });

    it('recognizes only workflow run as the fixed workflow entry', 0, () => {
      const workflowArgs = args('{"planId":"plan-1"}');
      const lookup = new FakeToolDefinitionLookup(['workflow.run', 'workflow.start']);
      const surface = new ExactSurfaceAuthorizer(
        'conversation-1',
        'turn-1',
        'surface-1',
        'workflow.run',
        workflowArgs
      );
      const actionCatalog = catalog(
        lookup,
        surface,
        new RejectClientAuthorizer(),
        new ControlledArgsValidator()
      );

      expect(actionCatalog.validatePlacement('hotel.search', 'workflow.run', workflowArgs).ok).assertTrue();
      expect(actionCatalog.validateSurfaceExecution(
        'conversation-1',
        'turn-1',
        'surface-1',
        'hotel.search',
        'workflow.run',
        workflowArgs
      ).ok).assertTrue();
      expect(actionCatalog.validateRegisteredStep('workflow.run', workflowArgs).ok).assertFalse();
      expect(actionCatalog.validatePlacement('hotel.search', 'workflow.start', workflowArgs).ok).assertFalse();
    });

    it('rejects exact surface tampering of phone hotel identity coordinates and turn', 0, () => {
      const exactArgs = args(
        '{"hotelId":47675,"phone":"+8675588888888","latitude":22.5,"longitude":114}'
      );
      const lookup = new FakeToolDefinitionLookup(['hotel.navigate']);
      const surface = new ExactSurfaceAuthorizer(
        'conversation-1',
        'turn-1',
        'surface-1',
        'hotel.navigate',
        exactArgs
      );
      const actionCatalog = catalog(
        lookup,
        surface,
        new RejectClientAuthorizer(),
        new ControlledArgsValidator()
      );

      expect(actionCatalog.validateSurfaceExecution(
        'conversation-1',
        'turn-1',
        'surface-1',
        'hotel.search',
        'hotel.navigate',
        exactArgs
      ).ok).assertTrue();
      expect(actionCatalog.validateSurfaceExecution(
        'conversation-1',
        'turn-2',
        'surface-1',
        'hotel.search',
        'hotel.navigate',
        exactArgs
      ).ok).assertFalse();
      expect(actionCatalog.validateSurfaceExecution(
        'conversation-1',
        'turn-1',
        'surface-1',
        'hotel.search',
        'hotel.navigate',
        args('{"hotelId":9,"phone":"+8675588888888","latitude":22.5,"longitude":114}')
      ).ok).assertFalse();
      expect(actionCatalog.validateSurfaceExecution(
        'conversation-1',
        'turn-1',
        'surface-1',
        'hotel.search',
        'hotel.navigate',
        args('{"hotelId":47675,"phone":"+8675511111111","latitude":22.5,"longitude":114}')
      ).ok).assertFalse();
      expect(actionCatalog.validateSurfaceExecution(
        'conversation-1',
        'turn-1',
        'surface-1',
        'hotel.search',
        'hotel.navigate',
        args('{"hotelId":47675,"phone":"+8675588888888","latitude":22.6,"longitude":114}')
      ).ok).assertFalse();
      expect(actionCatalog.validateSurfaceExecution(
        'conversation-1',
        'turn-1',
        'surface-1',
        'hotel.search',
        'hotel.navigate',
        args('{"hotelId":47675,"phone":"+8675588888888","latitude":22.5,"longitude":113.9}')
      ).ok).assertFalse();
    });

    it('accepts a client action only through the exact injected client policy', 0, () => {
      const restoreArgs = args('{"surfaceId":"hotel-search-1"}');
      const lookup = new FakeToolDefinitionLookup(['hotel.search.restore']);
      const surface = new ExactSurfaceAuthorizer(
        'conversation-1',
        'turn-1',
        'surface-1',
        'hotel.search.restore',
        restoreArgs
      );
      const actionCatalog = catalog(
        lookup,
        surface,
        new ExactClientAuthorizer('hotel.search.restore', restoreArgs),
        new ControlledArgsValidator()
      );

      expect(actionCatalog.validatePlacement('hotel.search', 'hotel.search.restore', restoreArgs).ok).assertTrue();
      expect(actionCatalog.validatePlacement(
        'hotel.search',
        'hotel.search.restore',
        args('{"surfaceId":"other-surface"}')
      ).ok).assertFalse();
      expect(actionCatalog.validateRegisteredStep('hotel.search.restore', restoreArgs).ok).assertFalse();
    });

    it('revalidates target input at execution time', 0, () => {
      const detailArgs = args('{"hotelId":47675}');
      const lookup = new FakeToolDefinitionLookup(['hotel.detail']);
      const surface = new ExactSurfaceAuthorizer('conversation-1', 'turn-1', 'surface-1', 'hotel.detail', detailArgs);
      const validator = new ControlledArgsValidator();
      const actionCatalog = catalog(lookup, surface, new RejectClientAuthorizer(), validator);

      expect(actionCatalog.validatePlacement('hotel.search', 'hotel.detail', detailArgs).ok).assertTrue();
      validator.allowed = false;
      const execution: ActionCatalogResult = actionCatalog.validateSurfaceExecution(
        'conversation-1',
        'turn-1',
        'surface-1',
        'hotel.search',
        'hotel.detail',
        detailArgs
      );

      expect(execution.ok).assertFalse();
      expect(execution.code).assertEqual('ARGS_INVALID');
      expect(validator.calls).assertEqual(2);
      expect(surface.calls).assertEqual(0);
    });

    it('validates registered later steps against current risk and backend metadata', 0, () => {
      const detailArgs = args('{"hotelId":47675}');
      const lookup = new FakeToolDefinitionLookup([]);
      const actionCatalog = catalog(
        lookup,
        new ExactSurfaceAuthorizer('conversation-1', 'turn-1', 'surface-1', 'hotel.detail', detailArgs),
        new RejectClientAuthorizer(),
        new ControlledArgsValidator()
      );

      expect(actionCatalog.validateRegisteredStep('hotel.detail', detailArgs).ok).assertTrue();
      lookup.targetRisk = 'blocked';
      expect(actionCatalog.validateRegisteredStep('hotel.detail', detailArgs).code).assertEqual('ACTION_BLOCKED');
      lookup.targetRisk = 'read';
      lookup.targetHasBackend = false;
      expect(actionCatalog.validateRegisteredStep('hotel.detail', detailArgs).code).assertEqual('ACTION_BACKEND_MISSING');
    });
  });
}
