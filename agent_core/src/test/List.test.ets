import { describe, expect, it } from '@ohos/hypium';
import hotelActionOfferResolverTests from './HotelActionOfferResolver.test';
import {
  ToolDefinition,
  ToolRiskLevel
} from '../main/ets/aiphone/runtime/ToolDefinitionTypes';
import {
  ActionArgsValidator,
  ActionValidationResult,
  ClientActionAuthorizer,
  SurfaceActionAuthorizer,
  ToolDefinitionLookup
} from '../main/ets/agent/action/ActionCatalogTypes';
import { ActionCatalog } from '../main/ets/agent/action/ActionCatalog';
import { ActionPlanRunner } from '../main/ets/agent/action/ActionPlanRunner';
import {
  ActionExecutionContext,
  ActionPlan,
  ActionPlanRunContext,
  ActionStepCommitResult,
  ActionStepExecutionObserver,
  ActionStepExecutionResult,
  ActionStepExecutor,
  FrozenActionDefinitionSnapshot,
  JsonValue
} from '../main/ets/agent/action/ActionPlanTypes';
import {
  SchemaAwareActionPlanCompiler
} from '../main/ets/agent/action/compiler/SchemaAwareActionPlanCompiler';
import {
  ActionPlanIdentity,
  ActionPlanIdentityFactory
} from '../main/ets/agent/action/compiler/ActionPlanDraftBuilder';
import {
  ActionPlanningModel,
  ActionPlanningModelRequest,
  ActionPlanningModelResult
} from '../main/ets/agent/action/compiler/model/ActionPlanningModel';
import {
  ActionPlanningContextBuilder
} from '../main/ets/agent/action/compiler/ActionPlanningContextBuilder';
import {
  ActionPlanningPromptBuilder,
  ActionPlanningPromptPayload
} from '../main/ets/agent/action/compiler/ActionPlanningPromptBuilder';
import {
  ACTION_PLAN_PROPOSAL_VERSION
} from '../main/ets/agent/action/compiler/ActionPlanProposalTypes';
import {
  ActionPlanningJsonSchema,
  ActionPlanSubmissionToolBuilder
} from '../main/ets/agent/action/compiler/ActionPlanSubmissionToolBuilder';
import { ActionOffer } from '../main/ets/agent/action/ActionOfferTypes';
import {
  ActionSchemaCatalog
} from '../main/ets/agent/action/schema/ActionSchemaCatalog';
import {
  ActionJsonSchema,
  validateActionValue
} from '../main/ets/agent/action/schema/ActionJsonSchema';
import {
  SchemaAwareActionDefinitionLookup
} from '../main/ets/agent/action/schema/SchemaAwareActionDefinition';
import {
  createRegisteredActionDefinitionLookup,
  createRegisteredActionSchemaCatalog
} from '../main/ets/agent/action/schema/RegisteredActionSchemas';
import {
  toolDefinitionForToolId
} from '../main/ets/aiphone/runtime/ToolDefinitionRegistry';
import {
  actionSchemasAssignable,
  resolveActionSchemaPath
} from '../main/ets/agent/action/schema/ActionSchemaCompatibility';

const FIXTURE_ACTION_ID: string = 'fixture.contact.lookup';
const FIXTURE_INPUT_SCHEMA_ID: string = 'fixture.contact.input';
const FIXTURE_OUTPUT_SCHEMA_ID: string = 'fixture.contact.output';
const FIXTURE_DERIVED_ACTION_ID: string = 'fixture.contact.open';
const FIXTURE_DERIVED_INPUT_SCHEMA_ID: string = 'fixture.contact.open.input';
const FIXTURE_DERIVED_OUTPUT_SCHEMA_ID: string = 'fixture.contact.open.output';

class FixtureToolDefinitionLookup implements ToolDefinitionLookup {
  riskLevel: ToolRiskLevel = 'read';

  find(toolId: string): ToolDefinition | null {
    if (toolId === FIXTURE_ACTION_ID) {
      return {
        toolId: FIXTURE_ACTION_ID,
        domain: 'fixture',
        intent: 'contact.lookup',
        riskLevel: this.riskLevel,
        backendPriority: ['local_adapter'],
        authModes: ['none'],
        inputSchema: FIXTURE_INPUT_SCHEMA_ID,
        outputSchema: FIXTURE_OUTPUT_SCHEMA_ID,
        a2uiComponent: 'fixture',
        actions: [FIXTURE_ACTION_ID]
      };
    }
    if (toolId === FIXTURE_DERIVED_ACTION_ID) {
      return {
        toolId: FIXTURE_DERIVED_ACTION_ID,
        domain: 'fixture',
        intent: 'contact.open',
        riskLevel: 'read',
        backendPriority: ['local_adapter'],
        authModes: ['none'],
        inputSchema: FIXTURE_DERIVED_INPUT_SCHEMA_ID,
        outputSchema: FIXTURE_DERIVED_OUTPUT_SCHEMA_ID,
        a2uiComponent: 'fixture',
        actions: []
      };
    }
    return null;
  }
}

class RegisteredToolDefinitionLookup implements ToolDefinitionLookup {
  find(toolId: string): ToolDefinition | null {
    return toolDefinitionForToolId(toolId);
  }
}

class FixtureSurfaceAuthorizer implements SurfaceActionAuthorizer {
  allows(
    _conversationId: string,
    _turnId: string,
    _surfaceId: string,
    _actionId: string,
    _args: Object
  ): boolean {
    return true;
  }
}

class FixtureClientAuthorizer implements ClientActionAuthorizer {
  allows(_actionId: string, _args: Object): boolean {
    return true;
  }
}

class FixtureArgsValidator implements ActionArgsValidator {
  private readonly definitions: SchemaAwareActionDefinitionLookup;

  constructor(definitions: SchemaAwareActionDefinitionLookup) {
    this.definitions = definitions;
  }

  validate(actionId: string, args: Object): ActionValidationResult {
    const found = this.definitions.find(actionId);
    if (!found.ok || found.definition === null) {
      return {
        ok: false,
        code: found.code,
        message: found.message
      };
    }
    const validation = validateActionValue(
      found.definition.inputSchema,
      args as JsonValue
    );
    return {
      ok: validation.ok,
      code: validation.code,
      message: validation.message
    };
  }
}

class FixtureSerialExecutor implements ActionStepExecutor {
  calls: string[] = [];
  invalidFirstOutput: boolean = false;

  execute(
    actionId: string,
    args: Object,
    _context: ActionExecutionContext
  ): Promise<ActionStepExecutionResult> {
    this.calls.push(actionId);
    if (actionId === FIXTURE_ACTION_ID) {
      return Promise.resolve({
        status: 'success',
        output: this.invalidFirstOutput ? {
          wrong: 'bob@example.com'
        } : {
          email: 'bob@example.com'
        }
      });
    }
    const values = args as Record<string, JsonValue>;
    return Promise.resolve({
      status: 'success',
      output: {
        opened: values['address'] === 'bob@example.com'
      }
    });
  }
}

class FixtureExecutionObserver implements ActionStepExecutionObserver {
  committedStepIds: string[] = [];

  commitValidatedSuccess(
    _actionId: string,
    _output: JsonValue,
    context: ActionExecutionContext,
    _followUp?: Object
  ): ActionStepCommitResult {
    this.committedStepIds.push(context.stepId);
    return {
      ok: true,
      errorCode: '',
      message: ''
    };
  }
}

class FixturePlanningModel implements ActionPlanningModel {
  private readonly argumentsJson: string;
  request: ActionPlanningModelRequest | null = null;

  constructor(argumentsJson: string) {
    this.argumentsJson = argumentsJson;
  }

  submit(
    request: ActionPlanningModelRequest
  ): Promise<ActionPlanningModelResult> {
    this.request = request;
    return Promise.resolve({
      ok: true,
      argumentsJson: this.argumentsJson,
      errorCode: '',
      message: ''
    });
  }
}

class FixturePlanIdentityFactory implements ActionPlanIdentityFactory {
  create(): ActionPlanIdentity {
    return {
      planId: 'fixture-plan',
      runId: 'fixture-run'
    };
  }
}

function objectSchema(
  propertyName: string,
  propertySchema: ActionJsonSchema
): ActionJsonSchema {
  const properties: Record<string, ActionJsonSchema> = {};
  properties[propertyName] = propertySchema;
  return {
    type: 'object',
    properties,
    required: [propertyName],
    additionalProperties: false
  };
}

function fixtureCompiler(
  includeOutputSchema: boolean
): SchemaAwareActionPlanCompiler {
  return new SchemaAwareActionPlanCompiler(
    fixtureDefinitionLookup(includeOutputSchema)
  );
}

function fixtureDefinitionLookup(
  includeOutputSchema: boolean,
  tools: ToolDefinitionLookup = new FixtureToolDefinitionLookup()
): SchemaAwareActionDefinitionLookup {
  const schemas = new ActionSchemaCatalog();
  schemas.register({
    schemaId: FIXTURE_INPUT_SCHEMA_ID,
    revision: '1',
    schema: objectSchema('name', {
      type: 'string',
      minLength: 1
    })
  });
  if (includeOutputSchema) {
    schemas.register({
      schemaId: FIXTURE_OUTPUT_SCHEMA_ID,
      revision: '1',
      schema: objectSchema('email', {
        type: 'string',
        minLength: 1
      })
    });
  }
  schemas.register({
    schemaId: FIXTURE_DERIVED_INPUT_SCHEMA_ID,
    revision: '1',
    schema: objectSchema('address', {
      type: 'string',
      minLength: 1
    })
  });
  schemas.register({
    schemaId: FIXTURE_DERIVED_OUTPUT_SCHEMA_ID,
    revision: '1',
    schema: objectSchema('opened', {
      type: 'boolean'
    })
  });
  return new SchemaAwareActionDefinitionLookup(
    tools,
    schemas
  );
}

function fixtureOffer(
  offerId: string,
  actionId: string = FIXTURE_ACTION_ID
): ActionOffer {
  return {
    offerId,
    actionId,
    label: `Find ${offerId}`,
    variant: 'default',
    args: {
      name: offerId
    }
  };
}

function frozenDefinition(
  definitions: SchemaAwareActionDefinitionLookup,
  actionId: string
): FrozenActionDefinitionSnapshot {
  const found = definitions.find(actionId);
  if (!found.ok || found.definition === null) {
    throw new Error(`Fixture Action definition is unavailable: ${actionId}.`);
  }
  return {
    definitionFingerprint: found.definition.definitionFingerprint,
    input: {
      schemaId: found.definition.inputSchemaId,
      revision: found.definition.inputSchemaRevision,
      fingerprint: found.definition.inputSchemaFingerprint,
      schema: found.definition.inputSchema
    },
    output: {
      schemaId: found.definition.outputSchemaId,
      revision: found.definition.outputSchemaRevision,
      fingerprint: found.definition.outputSchemaFingerprint,
      schema: found.definition.outputSchema
    }
  };
}

function fixtureRunnerPlan(
  catalog: ActionCatalog,
  definitions: SchemaAwareActionDefinitionLookup
): ActionPlan {
  return {
    conversationId: 'conversation',
    turnId: 'turn',
    taskId: 'task',
    surfaceId: 'surface',
    planId: 'plan',
    label: 'Open the selected contact',
    steps: [{
      stepId: 'lookup',
      actionId: FIXTURE_ACTION_ID,
      offerId: 'offer-bob',
      args: {
        name: 'bob'
      },
      inputFrom: [],
      definitionFingerprint: catalog.definitionFingerprint(FIXTURE_ACTION_ID),
      definition: frozenDefinition(definitions, FIXTURE_ACTION_ID),
      authority: {
        kind: 'offer',
        offerId: 'offer-bob',
        dataTaskId: 'data-task',
        sourceToolId: FIXTURE_ACTION_ID
      }
    }, {
      stepId: 'open',
      actionId: FIXTURE_DERIVED_ACTION_ID,
      offerId: null,
      args: {},
      inputFrom: [{
        target: '/address',
        stepId: 'lookup',
        path: '/email'
      }],
      definitionFingerprint:
        catalog.definitionFingerprint(FIXTURE_DERIVED_ACTION_ID),
      definition: frozenDefinition(definitions, FIXTURE_DERIVED_ACTION_ID),
      authority: {
        kind: 'derived',
        actionTaskId: 'task',
        allowedActionId: FIXTURE_DERIVED_ACTION_ID
      }
    }]
  };
}

function fixtureRunContext(): ActionPlanRunContext {
  return {
    conversationId: 'conversation',
    turnId: 'turn',
    taskId: 'task',
    surfaceId: 'surface',
    sourceToolId: FIXTURE_ACTION_ID,
    planId: 'plan',
    runId: 'run'
  };
}

interface FixtureRunnerDependencies {
  catalog: ActionCatalog;
  definitions: SchemaAwareActionDefinitionLookup;
  tools: FixtureToolDefinitionLookup;
}

function fixtureRunnerDependencies(): FixtureRunnerDependencies {
  const tools = new FixtureToolDefinitionLookup();
  const definitions = fixtureDefinitionLookup(true, tools);
  return {
    catalog: new ActionCatalog(
      tools,
      new FixtureSurfaceAuthorizer(),
      new FixtureClientAuthorizer(),
      new FixtureArgsValidator(definitions)
    ),
    definitions,
    tools
  };
}

export default function testsuite(): void {
  describe('SchemaAwareActionPlanCompiler', (): void => {
    it('resolves complete schemas by Action id', 0, (): void => {
      const result = fixtureCompiler(true).resolveAllowedActions([
        FIXTURE_ACTION_ID
      ]);
      expect(result.ok).assertTrue();
      expect(result.definitions.length).assertEqual(1);
      expect(result.definitions[0].actionId).assertEqual(FIXTURE_ACTION_ID);
      expect(result.definitions[0].inputSchemaId).assertEqual(
        FIXTURE_INPUT_SCHEMA_ID
      );
      expect(result.definitions[0].inputSchema.properties?.['name'].type)
        .assertEqual('string');
      expect(result.definitions[0].outputSchema.properties?.['email'].type)
        .assertEqual('string');
    });

    it('fails closed when an Action output schema is missing', 0, (): void => {
      const result = fixtureCompiler(false).resolveAllowedActions([
        FIXTURE_ACTION_ID
      ]);
      expect(result.ok).assertFalse();
      expect(result.definitions.length).assertEqual(0);
      expect(result.code).assertEqual('ACTION_OUTPUT_SCHEMA_NOT_FOUND');
    });

    it('converts one Offer step and one derived step into a Draft', 0,
      async (): Promise<void> => {
        const proposal = JSON.stringify({
          protocolVersion: ACTION_PLAN_PROPOSAL_VERSION,
          label: 'Open Bob contact',
          steps: [{
            stepId: 'lookup',
            actionId: FIXTURE_ACTION_ID,
            offerId: 'bob',
            args: {},
            inputFrom: []
          }, {
            stepId: 'open',
            actionId: FIXTURE_DERIVED_ACTION_ID,
            offerId: null,
            args: {},
            inputFrom: [{
              target: '/address',
              stepId: 'lookup',
              path: '/email'
            }]
          }]
        });
        const compiler = new SchemaAwareActionPlanCompiler(
          fixtureDefinitionLookup(true),
          new FixturePlanningModel(proposal),
          new FixturePlanIdentityFactory()
        );
        const draft = await compiler.compile(
          'Find Bob and open the contact',
          [fixtureOffer('bob')],
          [FIXTURE_ACTION_ID, FIXTURE_DERIVED_ACTION_ID]
        );
        expect(draft.planId).assertEqual('fixture-plan');
        expect(draft.runId).assertEqual('fixture-run');
        expect(draft.steps.length).assertEqual(2);
        expect(draft.steps[0].offerId).assertEqual('bob');
        expect((draft.steps[0].args as Record<string, string>)['name'])
          .assertEqual('bob');
        expect(draft.steps[1].offerId === null).assertTrue();
        expect(draft.steps[1].inputFrom[0].stepId).assertEqual('lookup');
        expect(draft.steps[1].inputFrom[0].path).assertEqual('/email');
        expect(draft.steps[1].inputFrom[0].target).assertEqual('/address');
      });

    it('rejects a model-authored override on an Offer step', 0,
      async (): Promise<void> => {
        const proposal = JSON.stringify({
          protocolVersion: ACTION_PLAN_PROPOSAL_VERSION,
          label: 'Override Bob',
          steps: [{
            stepId: 'lookup',
            actionId: FIXTURE_ACTION_ID,
            offerId: 'bob',
            args: {
              name: 'mallory'
            },
            inputFrom: []
          }]
        });
        const compiler = new SchemaAwareActionPlanCompiler(
          fixtureDefinitionLookup(true),
          new FixturePlanningModel(proposal),
          new FixturePlanIdentityFactory()
        );
        let rejected = false;
        try {
          await compiler.compile(
            'Override Bob',
            [fixtureOffer('bob')],
            [FIXTURE_ACTION_ID]
          );
        } catch (error) {
          rejected = `${error}`.includes('ACTION_PLAN_OFFER_STEP_OVERRIDE');
        }
        expect(rejected).assertTrue();
      });

    it('prepends a resolver-owned entry and asks the model only for tail steps', 0,
      async (): Promise<void> => {
        const proposal = JSON.stringify({
          protocolVersion: ACTION_PLAN_PROPOSAL_VERSION,
          label: 'Open Bob contact',
          steps: [{
            stepId: 'open',
            actionId: FIXTURE_DERIVED_ACTION_ID,
            offerId: null,
            args: {},
            inputFrom: [{
              target: '/address',
              stepId: 'entry',
              path: '/email'
            }]
          }]
        });
        const model = new FixturePlanningModel(proposal);
        const compiler = new SchemaAwareActionPlanCompiler(
          fixtureDefinitionLookup(true),
          model,
          new FixturePlanIdentityFactory()
        );
        const draft = await compiler.compile(
          'Find Bob and open the contact',
          [fixtureOffer('bob')],
          [FIXTURE_ACTION_ID, FIXTURE_DERIVED_ACTION_ID],
          { preboundEntryOfferId: 'bob' }
        );
        expect(draft.steps.length).assertEqual(2);
        expect(draft.steps[0].stepId).assertEqual('entry');
        expect(draft.steps[0].actionId).assertEqual(FIXTURE_ACTION_ID);
        expect(draft.steps[0].offerId).assertEqual('bob');
        expect((draft.steps[0].args as Record<string, string>)['name'])
          .assertEqual('bob');
        expect(draft.steps[1].actionId).assertEqual(
          FIXTURE_DERIVED_ACTION_ID
        );
        expect(draft.steps[1].inputFrom[0].stepId).assertEqual('entry');
        expect(model.request?.systemPrompt.includes(
          'runtime has already selected'
        )).assertTrue();
        expect(model.request?.systemPrompt.includes(
          'first step must select one ready Offer'
        )).assertFalse();
        const payload = JSON.parse(
          model.request?.userPrompt as string
        ) as ActionPlanningPromptPayload;
        expect(payload.preboundEntryStep?.stepId).assertEqual('entry');
        expect(payload.preboundEntryStep?.actionId).assertEqual(
          FIXTURE_ACTION_ID
        );
        expect(payload.requiredRemainingActionOrder?.length).assertEqual(1);
        expect(payload.requiredRemainingActionOrder?.[0]).assertEqual(
          FIXTURE_DERIVED_ACTION_ID
        );
        expect(payload.availableActions.length).assertEqual(1);
        expect(payload.availableActions[0].actionId).assertEqual(
          FIXTURE_DERIVED_ACTION_ID
        );
      });
  });

  describe('ActionPlanningContextBuilder', (): void => {
    it('groups Offers under their allowed Action definitions', 0, (): void => {
      const builder = new ActionPlanningContextBuilder(
        fixtureDefinitionLookup(true)
      );
      const result = builder.build([
        fixtureOffer('bob'),
        fixtureOffer('alice')
      ], [
        FIXTURE_ACTION_ID
      ]);
      expect(result.ok).assertTrue();
      expect(result.actions.length).assertEqual(1);
      expect(result.actions[0].definition.actionId).assertEqual(
        FIXTURE_ACTION_ID
      );
      expect(result.actions[0].offers.length).assertEqual(2);
      expect(result.actions[0].offers[0].offerId).assertEqual('bob');
      expect(result.actions[0].definition.outputSchema.properties?.['email'].type)
        .assertEqual('string');
    });

    it('includes an allowed Action without a ready Offer', 0, (): void => {
      const builder = new ActionPlanningContextBuilder(
        fixtureDefinitionLookup(true)
      );
      const result = builder.build([], [
        FIXTURE_ACTION_ID
      ]);
      expect(result.ok).assertTrue();
      expect(result.actions.length).assertEqual(1);
      expect(result.actions[0].definition.actionId).assertEqual(
        FIXTURE_ACTION_ID
      );
      expect(result.actions[0].offers.length).assertEqual(0);
    });

    it('fails closed for an unauthorized Offer', 0, (): void => {
      const builder = new ActionPlanningContextBuilder(
        fixtureDefinitionLookup(true)
      );
      const result = builder.build([
        fixtureOffer('bob', 'fixture.unauthorized')
      ], [
        FIXTURE_ACTION_ID
      ]);
      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('ACTION_PLAN_OFFER_UNAUTHORIZED');
    });

    it('fails closed for duplicate Offer ids', 0, (): void => {
      const builder = new ActionPlanningContextBuilder(
        fixtureDefinitionLookup(true)
      );
      const result = builder.build([
        fixtureOffer('bob'),
        fixtureOffer('bob')
      ], [
        FIXTURE_ACTION_ID
      ]);
      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('ACTION_PLAN_OFFER_DUPLICATE');
    });
  });

  describe('ActionPlanningPromptBuilder', (): void => {
    it('serializes goal, schemas and Offer data for the model', 0, (): void => {
      const context = new ActionPlanningContextBuilder(
        fixtureDefinitionLookup(true)
      ).build([
        fixtureOffer('bob'),
        fixtureOffer('alice')
      ], [
        FIXTURE_ACTION_ID
      ]);
      expect(context.ok).assertTrue();
      const result = new ActionPlanningPromptBuilder().build(
        'Find one contact',
        context.actions
      );
      expect(result.ok).assertTrue();
      expect(result.prompt?.systemPrompt.includes(
        'The first step must select one ready Offer'
      )).assertTrue();
      expect(result.prompt?.systemPrompt.includes(
        'offerId=null is always invalid for step 1'
      )).assertTrue();
      expect(result.prompt?.systemPrompt.includes(
        'Only step 2 and later may use offerId=null'
      )).assertTrue();
      expect(result.prompt?.systemPrompt.includes(
        'binding path must be a JSON Pointer explicitly declared'
      )).assertTrue();
      expect(result.prompt?.systemPrompt.includes(
        'Execution order alone does not imply a data dependency'
      )).assertTrue();
      expect(result.prompt?.systemPrompt.includes(
        'put those constants in args and set inputFrom=[]'
      )).assertTrue();
      expect(result.prompt?.systemPrompt.includes(
        '/data/socialHub/publication/text to target /body'
      )).assertTrue();
      expect(result.prompt?.systemPrompt.includes(
        'do not bind /conversationId to /conversationId'
      )).assertTrue();
      expect(result.prompt?.systemPrompt.includes(
        'preboundEntryStep'
      )).assertFalse();
      const payload = JSON.parse(
        result.prompt?.userPrompt as string
      ) as ActionPlanningPromptPayload;
      expect(payload.goal).assertEqual('Find one contact');
      expect(payload.availableActions.length).assertEqual(1);
      expect(payload.availableActions[0].actionId).assertEqual(
        FIXTURE_ACTION_ID
      );
      expect(payload.availableActions[0].inputSchema.properties?.['name'].type)
        .assertEqual('string');
      expect(payload.availableActions[0].outputSchema.properties?.['email'].type)
        .assertEqual('string');
      expect(payload.availableActions[0].offers.length).assertEqual(2);
      expect(payload.availableActions[0].offers[0].offerId).assertEqual('bob');
    });

    it('keeps prebound tail instructions isolated from candidate Offer rules', 0,
      (): void => {
        const context = new ActionPlanningContextBuilder(
          fixtureDefinitionLookup(true)
        ).build([
          fixtureOffer('bob')
        ], [
          FIXTURE_ACTION_ID,
          FIXTURE_DERIVED_ACTION_ID
        ]);
        expect(context.ok).assertTrue();
        const result = new ActionPlanningPromptBuilder().build(
          'Find Bob and open the contact',
          context.actions.slice(1),
          {
            stepId: 'entry',
            actionId: FIXTURE_ACTION_ID,
            outputSchema: context.actions[0].definition.outputSchema
          }
        );
        expect(result.ok).assertTrue();
        expect(result.prompt?.systemPrompt.includes(
          'runtime has already selected'
        )).assertTrue();
        expect(result.prompt?.systemPrompt.includes(
          'do not include the prebound entry'
        )).assertTrue();
        expect(result.prompt?.systemPrompt.includes(
          'first step must select one ready Offer'
        )).assertFalse();
        expect(result.prompt?.systemPrompt.includes(
          'offerId=null is always invalid for step 1'
        )).assertFalse();
        const payload = JSON.parse(
          result.prompt?.userPrompt as string
        ) as ActionPlanningPromptPayload;
        expect(payload.preboundEntryStep?.stepId).assertEqual('entry');
        expect(payload.requiredRemainingActionOrder?.length).assertEqual(1);
        expect(payload.availableActions.length).assertEqual(1);
        expect(payload.availableActions[0].actionId).assertEqual(
          FIXTURE_DERIVED_ACTION_ID
        );
      });

    it('omits runtime fingerprints from the model payload', 0, (): void => {
      const context = new ActionPlanningContextBuilder(
        fixtureDefinitionLookup(true)
      ).build([
        fixtureOffer('bob')
      ], [
        FIXTURE_ACTION_ID
      ]);
      const result = new ActionPlanningPromptBuilder().build(
        'Find Bob',
        context.actions
      );
      expect(result.ok).assertTrue();
      expect(result.prompt?.userPrompt.includes('definitionFingerprint'))
        .assertFalse();
      expect(result.prompt?.userPrompt.includes('inputSchemaFingerprint'))
        .assertFalse();
      expect(result.prompt?.userPrompt.includes('outputSchemaFingerprint'))
        .assertFalse();
    });

    it('serializes an allowed Action with an empty Offer list', 0, (): void => {
      const context = new ActionPlanningContextBuilder(
        fixtureDefinitionLookup(true)
      ).build([], [
        FIXTURE_ACTION_ID
      ]);
      const result = new ActionPlanningPromptBuilder().build(
        'Use a derived Action',
        context.actions
      );
      expect(result.ok).assertTrue();
      const payload = JSON.parse(
        result.prompt?.userPrompt as string
      ) as ActionPlanningPromptPayload;
      expect(payload.availableActions.length).assertEqual(1);
      expect(payload.availableActions[0].actionId).assertEqual(
        FIXTURE_ACTION_ID
      );
      expect(payload.availableActions[0].offers.length).assertEqual(0);
    });

    it('fails closed for an empty goal', 0, (): void => {
      const context = new ActionPlanningContextBuilder(
        fixtureDefinitionLookup(true)
      ).build([
        fixtureOffer('bob')
      ], [
        FIXTURE_ACTION_ID
      ]);
      const result = new ActionPlanningPromptBuilder().build(
        ' ',
        context.actions
      );
      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('ACTION_PLAN_GOAL_EMPTY');
    });
  });

  describe('ActionPlanSubmissionToolBuilder', (): void => {
    it('constrains plan submission to current Offer ids', 0, (): void => {
      const context = new ActionPlanningContextBuilder(
        fixtureDefinitionLookup(true)
      ).build([
        fixtureOffer('bob'),
        fixtureOffer('alice')
      ], [
        FIXTURE_ACTION_ID
      ]);
      const result = new ActionPlanSubmissionToolBuilder().build(
        context.actions
      );
      expect(result.ok).assertTrue();
      expect(result.tool?.function.name).assertEqual('submit_action_plan');
      expect(result.tool?.function.strict).assertTrue();
      expect(result.tool?.function.description.includes(
        'prebound'
      )).assertFalse();
      const parameters = result.tool?.function.parameters as
        ActionPlanningJsonSchema;
      expect(parameters.properties?.['protocolVersion'].const)
        .assertEqual(ACTION_PLAN_PROPOSAL_VERSION);
      expect(parameters.properties?.['steps'].minItems).assertEqual(1);
      expect(parameters.properties?.['steps'].maxItems).assertEqual(5);
      const step = parameters.properties?.['steps'].items;
      const actionIds = step?.properties?.['actionId'].enum;
      const offerIds = step?.properties?.['offerId'].anyOf?.[0].enum;
      expect(actionIds?.length).assertEqual(1);
      expect(actionIds?.[0]).assertEqual(FIXTURE_ACTION_ID);
      expect(offerIds?.length).assertEqual(2);
      expect(offerIds?.[0]).assertEqual('bob');
      expect(offerIds?.[1]).assertEqual('alice');
      expect(step?.properties?.['offerId'].anyOf?.[1].description.includes(
        'prebound'
      )).assertFalse();
      expect(step?.required?.join(','))
        .assertEqual('stepId,actionId,offerId,args,inputFrom');
      expect(step?.additionalProperties).assertFalse();
    });

    it('allows a derived Action when no ready Offer exists', 0, (): void => {
      const context = new ActionPlanningContextBuilder(
        fixtureDefinitionLookup(true)
      ).build([], [
        FIXTURE_ACTION_ID
      ]);
      const result = new ActionPlanSubmissionToolBuilder().build(
        context.actions
      );
      expect(result.ok).assertTrue();
      const parameters = result.tool?.function.parameters as
        ActionPlanningJsonSchema;
      const step = parameters.properties?.['steps'].items;
      expect(step?.properties?.['actionId'].enum?.[0])
        .assertEqual(FIXTURE_ACTION_ID);
      expect(step?.properties?.['offerId'].type).assertEqual('null');
      expect(step?.properties?.['args'].type).assertEqual('object');
    });

    it('forces null Offer ids when submitting a prebound plan tail', 0,
      (): void => {
        const context = new ActionPlanningContextBuilder(
          fixtureDefinitionLookup(true)
        ).build([], [
          FIXTURE_DERIVED_ACTION_ID
        ]);
        const result = new ActionPlanSubmissionToolBuilder().build(
          context.actions,
          true
        );
        expect(result.ok).assertTrue();
        expect(result.tool?.function.description.includes(
          'runtime-owned prebound entry'
        )).assertTrue();
        const parameters = result.tool?.function.parameters as
          ActionPlanningJsonSchema;
        expect(parameters.properties?.['steps'].minItems).assertEqual(1);
        expect(parameters.properties?.['steps'].maxItems).assertEqual(1);
        const step = parameters.properties?.['steps'].items;
        expect(step?.properties?.['actionId'].enum?.length).assertEqual(1);
        expect(step?.properties?.['actionId'].enum?.[0])
          .assertEqual(FIXTURE_DERIVED_ACTION_ID);
        expect(step?.properties?.['offerId'].type).assertEqual('null');
        expect(step?.properties?.['offerId'].anyOf === undefined).assertTrue();
        expect(step?.properties?.['offerId'].description.includes(
          'prebound entry'
        )).assertTrue();
      });

    it('fails closed without available Actions', 0, (): void => {
      const result = new ActionPlanSubmissionToolBuilder().build([]);
      expect(result.ok).assertFalse();
      expect(result.tool === null).assertTrue();
      expect(result.code).assertEqual('ACTION_PLAN_AVAILABLE_ACTIONS_EMPTY');
    });
  });

  describe('Registered Action schemas', (): void => {
    it('resolves the Luckin preview and payment Actions used by C22', 0, (): void => {
      const definitions = createRegisteredActionDefinitionLookup(
        new RegisteredToolDefinitionLookup()
      );
      const luckin = definitions.find('luckin.order.preview');
      const payment = definitions.find('payment.send');
      expect(luckin.ok).assertTrue();
      expect(payment.ok).assertTrue();
      expect(luckin.definition?.inputSchemaId)
        .assertEqual('luckinOrderPreviewRequest');
      expect(luckin.definition?.outputSchemaId)
        .assertEqual('genericToolResults');
      expect(payment.definition?.inputSchemaId)
        .assertEqual('paymentSendRequest');
      expect(payment.definition?.outputSchemaId)
        .assertEqual('paymentCheckout');
    });

    it('accepts both prompt-derived and exact page Action inputs for C22', 0, (): void => {
      const schemas = createRegisteredActionSchemaCatalog();
      const luckin = schemas.find('luckinOrderPreviewRequest');
      const payment = schemas.find('paymentSendRequest');
      expect(luckin !== null).assertTrue();
      expect(payment !== null).assertTrue();
      if (luckin === null || payment === null) {
        return;
      }
      expect(validateActionValue(luckin.schema, {
        originalQuery: '点一杯生椰拿铁，半糖少冰'
      }).ok).assertTrue();
      expect(validateActionValue(luckin.schema, {
        deptId: 'shop-1',
        location: '114.0,22.5'
      }).ok).assertTrue();
      expect(validateActionValue(payment.schema, {
        originalQuery: '转账给罗一格 5 美金'
      }).ok).assertTrue();
      expect(validateActionValue(payment.schema, {
        recipient: '罗一格',
        provider: 'paypal',
        fundingSource: '',
        amountText: '5',
        currency: 'USD',
        note: '',
        phase: 'confirm',
        accountId: 'luoyige',
        targetType: 'paypal',
        checkoutUrl: '',
        providerSessionId: '',
        paypalClientId: '',
        paypalEnvironment: '',
        paypalEmail: 'alice@example.com',
        paypalMerchantId: ''
      }).ok).assertTrue();
    });

    it('validates the registered page output envelope for C22 Actions', 0, (): void => {
      const schemas = createRegisteredActionSchemaCatalog();
      const generic = schemas.find('genericToolResults');
      const payment = schemas.find('paymentCheckout');
      expect(generic !== null).assertTrue();
      expect(payment !== null).assertTrue();
      if (generic === null || payment === null) {
        return;
      }
      const output = {
        actionId: 'luckin.order.preview',
        pageActionId: 'luckin.order.preview',
        conversationId: 'conversation-1',
        turnId: 'turn-1',
        surfaceId: 'surface-1',
        status: 'ready',
        data: {
          genericToolResults: [{
            sourceTag: 'Luckin',
            toolName: 'luckin.order.preview',
            title: 'Order preview',
            status: 'success',
            summary: 'Ready for confirmation.',
            rows: [],
            rawPreview: ''
          }]
        }
      };
      expect(validateActionValue(generic.schema, output).ok).assertTrue();
      output.actionId = 'payment.send';
      output.pageActionId = 'payment.send';
      output.data.genericToolResults[0].toolName = 'payment.send';
      expect(validateActionValue(payment.schema, output).ok).assertTrue();
    });

    it('declares the Social preview text as assignable to the Gmail body', 0, (): void => {
      const schemas = createRegisteredActionSchemaCatalog();
      const social = schemas.find('socialHubPublication');
      const gmail = schemas.find('draftCreateRequest');
      expect(social !== null).assertTrue();
      expect(gmail !== null).assertTrue();
      if (social === null || gmail === null) {
        return;
      }
      const source = resolveActionSchemaPath(
        social.schema,
        '/data/socialHub/publication/text'
      );
      const target = resolveActionSchemaPath(
        gmail.schema,
        '/body'
      );
      expect(source.ok).assertTrue();
      expect(target.ok).assertTrue();
      expect(actionSchemasAssignable(
        source.schema as ActionJsonSchema,
        target.schema as ActionJsonSchema
      )).assertTrue();
    });

    it('declares the Maps URL as assignable to the Gmail body', 0, (): void => {
      const schemas = createRegisteredActionSchemaCatalog();
      const mapsInput = schemas.find('mapsRouteOpenRequest');
      const mapsOutput = schemas.find('mapsRouteOpenResult');
      const gmail = schemas.find('draftCreateRequest');
      expect(mapsInput !== null).assertTrue();
      expect(mapsOutput !== null).assertTrue();
      expect(gmail !== null).assertTrue();
      if (mapsInput === null || mapsOutput === null || gmail === null) {
        return;
      }
      const inputValidation = validateActionValue(
        mapsInput.schema,
        {
          origin: '深圳坂田华为基地',
          destination: '深圳北站',
          travelMode: 'driving',
          navigate: false
        }
      );
      expect(inputValidation.ok).assertTrue();
      const source = resolveActionSchemaPath(
        mapsOutput.schema,
        '/data/genericToolResults/0/rawPreview'
      );
      const target = resolveActionSchemaPath(
        gmail.schema,
        '/body'
      );
      expect(source.ok).assertTrue();
      expect(target.ok).assertTrue();
      expect(actionSchemasAssignable(
        source.schema as ActionJsonSchema,
        target.schema as ActionJsonSchema
      )).assertTrue();
    });
  });

  describe('Schema-aware ActionPlanRunner', (): void => {
    it('binds only schema-validated output into the next Action', 0,
      async (): Promise<void> => {
        const dependencies = fixtureRunnerDependencies();
        const executor = new FixtureSerialExecutor();
        const observer = new FixtureExecutionObserver();
        const runner = new ActionPlanRunner(
          dependencies.catalog,
          executor,
          dependencies.definitions,
          observer
        );
        const outcome = await runner.run(
          fixtureRunnerPlan(dependencies.catalog, dependencies.definitions),
          fixtureRunContext()
        );
        expect(outcome.status).assertEqual('success');
        expect(executor.calls.join(',')).assertEqual(
          `${FIXTURE_ACTION_ID},${FIXTURE_DERIVED_ACTION_ID}`
        );
        expect(observer.committedStepIds.join(',')).assertEqual('lookup,open');
      });

    it('blocks dependent Actions when an Executor output violates schema', 0,
      async (): Promise<void> => {
        const dependencies = fixtureRunnerDependencies();
        const executor = new FixtureSerialExecutor();
        executor.invalidFirstOutput = true;
        const observer = new FixtureExecutionObserver();
        const runner = new ActionPlanRunner(
          dependencies.catalog,
          executor,
          dependencies.definitions,
          observer
        );
        const outcome = await runner.run(
          fixtureRunnerPlan(dependencies.catalog, dependencies.definitions),
          fixtureRunContext()
        );
        expect(outcome.status).assertEqual('error');
        expect(outcome.errorCode).assertEqual('ACTION_OUTPUT_SCHEMA_INVALID');
        expect(executor.calls.join(',')).assertEqual(FIXTURE_ACTION_ID);
        expect(observer.committedStepIds.length).assertEqual(0);
      });

    it('rejects a tampered frozen schema snapshot before execution', 0,
      async (): Promise<void> => {
        const dependencies = fixtureRunnerDependencies();
        const executor = new FixtureSerialExecutor();
        const runner = new ActionPlanRunner(
          dependencies.catalog,
          executor,
          dependencies.definitions
        );
        const plan = fixtureRunnerPlan(
          dependencies.catalog,
          dependencies.definitions
        );
        const definition = plan.steps[0].definition as
          FrozenActionDefinitionSnapshot;
        definition.output.schema = objectSchema('uri', {
          type: 'string'
        });
        const outcome = await runner.run(plan, fixtureRunContext());
        expect(outcome.status).assertEqual('error');
        expect(outcome.errorCode)
          .assertEqual('ACTION_PLAN_SCHEMA_SNAPSHOT_INVALID');
        expect(executor.calls.length).assertEqual(0);
      });

    it('rejects a plan when the current Action definition changed', 0,
      async (): Promise<void> => {
        const dependencies = fixtureRunnerDependencies();
        const executor = new FixtureSerialExecutor();
        const runner = new ActionPlanRunner(
          dependencies.catalog,
          executor,
          dependencies.definitions
        );
        const plan = fixtureRunnerPlan(
          dependencies.catalog,
          dependencies.definitions
        );
        dependencies.tools.riskLevel = 'draft';
        const outcome = await runner.run(plan, fixtureRunContext());
        expect(outcome.status).assertEqual('error');
        expect(outcome.errorCode).assertEqual('PLAN_STALE');
        expect(executor.calls.length).assertEqual(0);
      });
  });
  hotelActionOfferResolverTests();
}
