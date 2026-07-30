import { ActionOffer } from '../ActionOfferTypes';
import {
  ActionPlanCompiler,
  ActionPlanDraft
} from '../ActionPlanTypes';
import {
  SchemaAwareActionDefinition,
  SchemaAwareActionDefinitionLookup,
  SchemaAwareActionDefinitionResult
} from '../schema/SchemaAwareActionDefinition';
import {
  ActionPlanDraftBuilder,
  ActionPlanIdentityFactory,
  DefaultActionPlanIdentityFactory
} from './ActionPlanDraftBuilder';
import { ActionPlanProposalParser } from './ActionPlanProposalParser';
import { ActionPlanningContextBuilder } from './ActionPlanningContextBuilder';
import { ActionPlanningPromptBuilder } from './ActionPlanningPromptBuilder';
import { ActionPlanSubmissionToolBuilder } from './ActionPlanSubmissionToolBuilder';
import {
  ActionPlanningModel,
  ActionPlanningModelRequest
} from './model/ActionPlanningModel';

export interface ActionDefinitionResolutionResult {
  ok: boolean;
  definitions: SchemaAwareActionDefinition[];
  code: string;
  message: string;
}

function resolutionFailure(
  code: string,
  message: string
): ActionDefinitionResolutionResult {
  return {
    ok: false,
    definitions: [],
    code,
    message
  };
}

/**
 * Minimal concrete compiler boundary.
 *
 * This first increment owns only schema-aware Action definition resolution.
 * Planning/model resources will be added as separate constructor dependencies.
 */
export class SchemaAwareActionPlanCompiler implements ActionPlanCompiler {
  private readonly definitions: SchemaAwareActionDefinitionLookup;
  private readonly model: ActionPlanningModel | null;
  private readonly identities: ActionPlanIdentityFactory;

  constructor(
    definitions: SchemaAwareActionDefinitionLookup,
    model: ActionPlanningModel | null = null,
    identities: ActionPlanIdentityFactory =
      new DefaultActionPlanIdentityFactory()
  ) {
    this.definitions = definitions;
    this.model = model;
    this.identities = identities;
  }

  resolveAllowedActions(
    allowedActionIds: string[]
  ): ActionDefinitionResolutionResult {
    const resolved = this.definitions.describe(allowedActionIds);
    const definitions: SchemaAwareActionDefinition[] = [];
    for (let index = 0; index < resolved.length; index++) {
      const current: SchemaAwareActionDefinitionResult = resolved[index];
      if (!current.ok || current.definition === null) {
        return resolutionFailure(
          current.code.length > 0 ?
            current.code : 'ACTION_DEFINITION_RESOLUTION_FAILED',
          current.message.length > 0 ?
            current.message : 'Action definition resolution failed.'
        );
      }
      definitions.push(current.definition);
    }
    return {
      ok: true,
      definitions,
      code: '',
      message: ''
    };
  }

  compile(
    goal: string,
    offers: ActionOffer[],
    allowedActionIds: string[]
  ): Promise<ActionPlanDraft> {
    if (this.model === null) {
      return Promise.reject(new Error(
        'ACTION_PLAN_PLANNER_UNAVAILABLE: ' +
        'Action plan model resources are not configured.'
      ));
    }
    const context = new ActionPlanningContextBuilder(this.definitions).build(
      offers,
      allowedActionIds
    );
    if (!context.ok) {
      return Promise.reject(new Error(`${context.code}: ${context.message}`));
    }
    const prompt = new ActionPlanningPromptBuilder().build(
      goal,
      context.actions
    );
    if (!prompt.ok || prompt.prompt === null) {
      return Promise.reject(new Error(`${prompt.code}: ${prompt.message}`));
    }
    const submission = new ActionPlanSubmissionToolBuilder().build(
      context.actions
    );
    if (!submission.ok || submission.tool === null) {
      return Promise.reject(
        new Error(`${submission.code}: ${submission.message}`)
      );
    }
    const request: ActionPlanningModelRequest = {
      systemPrompt: prompt.prompt.systemPrompt,
      userPrompt: prompt.prompt.userPrompt,
      submitTool: submission.tool
    };
    return this.model.submit(request).then((result) => {
      if (!result.ok) {
        throw new Error(
          `${result.errorCode.length > 0 ?
            result.errorCode : 'ACTION_PLAN_MODEL_FAILED'}: ${result.message}`
        );
      }
      const parsed = new ActionPlanProposalParser().parse(
        result.argumentsJson
      );
      if (!parsed.ok || parsed.proposal === null) {
        throw new Error(`${parsed.code}: ${parsed.message}`);
      }
      const built = new ActionPlanDraftBuilder(this.identities).build(
        parsed.proposal,
        context.actions
      );
      if (!built.ok || built.draft === null) {
        throw new Error(`${built.code}: ${built.message}`);
      }
      return built.draft;
    });
  }
}
