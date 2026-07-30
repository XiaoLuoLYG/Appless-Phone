import { ActionOffer } from '../ActionOfferTypes';
import {
  ActionPlanCompileOptions,
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
import {
  ProposedActionPlan,
  ProposedActionStep
} from './ActionPlanProposalTypes';
import { ActionPlanningContextBuilder } from './ActionPlanningContextBuilder';
import {
  ActionPlanningPreboundEntry,
  ActionPlanningPromptBuilder
} from './ActionPlanningPromptBuilder';
import { ActionPlanSubmissionToolBuilder } from './ActionPlanSubmissionToolBuilder';
import {
  ActionPlanningModel,
  ActionPlanningModelRequest
} from './model/ActionPlanningModel';
import { aiLogError, aiLogInfo } from '../../../aiphone/runtime/AiphoneLogger';

const PREBOUND_ENTRY_STEP_ID: string = 'entry';

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
    allowedActionIds: string[],
    options?: ActionPlanCompileOptions
  ): Promise<ActionPlanDraft> {
    aiLogInfo(
      '[AIPhone][ActionPlanCompilerStart] actions=' +
      allowedActionIds.join(',') + ' offers=' + offers.length.toString() +
      ' mode=' + (options !== undefined &&
        options.preboundEntryOfferId !== undefined ?
        'prebound_tail' : 'complete')
    );
    if (this.model === null) {
      aiLogError(
        '[AIPhone][ActionPlanCompilerFailed] stage=model_setup ' +
        'code=ACTION_PLAN_PLANNER_UNAVAILABLE'
      );
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
      aiLogError(
        '[AIPhone][ActionPlanCompilerFailed] stage=context code=' +
        context.code
      );
      return Promise.reject(new Error(`${context.code}: ${context.message}`));
    }
    let modelActions = context.actions;
    let preboundOffer: ActionOffer | null = null;
    let preboundEntry: ActionPlanningPreboundEntry | null = null;
    if (options !== undefined &&
      options.preboundEntryOfferId !== undefined) {
      const requiredOfferId = options.preboundEntryOfferId.trim();
      if (requiredOfferId.length === 0 || allowedActionIds.length < 2) {
        aiLogError(
          '[AIPhone][ActionPlanCompilerFailed] stage=prebound_entry ' +
          'code=ACTION_PLAN_PREBOUND_ENTRY_INVALID'
        );
        return Promise.reject(new Error(
          'ACTION_PLAN_PREBOUND_ENTRY_INVALID: ' +
          'Prebound entry requires a non-empty Offer and at least one tail Action.'
        ));
      }
      for (let actionIndex = 0;
        actionIndex < context.actions.length;
        actionIndex++) {
        const action = context.actions[actionIndex];
        for (let offerIndex = 0;
          offerIndex < action.offers.length;
          offerIndex++) {
          if (action.offers[offerIndex].offerId === requiredOfferId) {
            preboundOffer = action.offers[offerIndex];
            preboundEntry = {
              stepId: PREBOUND_ENTRY_STEP_ID,
              actionId: action.definition.actionId,
              outputSchema: action.definition.outputSchema
            };
            break;
          }
        }
        if (preboundOffer !== null) {
          break;
        }
      }
      if (preboundOffer === null || preboundEntry === null ||
        preboundOffer.actionId !== allowedActionIds[0] ||
        preboundEntry.actionId !== allowedActionIds[0]) {
        aiLogError(
          '[AIPhone][ActionPlanCompilerFailed] stage=prebound_entry ' +
          'code=ACTION_PLAN_PREBOUND_ENTRY_MISMATCH'
        );
        return Promise.reject(new Error(
          'ACTION_PLAN_PREBOUND_ENTRY_MISMATCH: ' +
          'Prebound entry Offer must belong to the first allowed Action.'
        ));
      }
      modelActions = context.actions.slice(1);
    }
    const prompt = new ActionPlanningPromptBuilder().build(
      goal,
      modelActions,
      preboundEntry
    );
    if (!prompt.ok || prompt.prompt === null) {
      aiLogError(
        '[AIPhone][ActionPlanCompilerFailed] stage=prompt code=' +
        prompt.code
      );
      return Promise.reject(new Error(`${prompt.code}: ${prompt.message}`));
    }
    const submission = new ActionPlanSubmissionToolBuilder().build(
      modelActions,
      preboundOffer !== null
    );
    if (!submission.ok || submission.tool === null) {
      aiLogError(
        '[AIPhone][ActionPlanCompilerFailed] stage=submission code=' +
        submission.code
      );
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
      aiLogInfo(
        '[AIPhone][ActionPlanCompilerModelResult] ok=' +
        (result.ok ? 'true' : 'false') + ' code=' +
        (result.errorCode.length > 0 ? result.errorCode : 'none') +
        ' argumentsChars=' + result.argumentsJson.length.toString()
      );
      if (!result.ok) {
        aiLogError(
          '[AIPhone][ActionPlanCompilerFailed] stage=model code=' +
          (result.errorCode.length > 0 ?
            result.errorCode : 'ACTION_PLAN_MODEL_FAILED')
        );
        throw new Error(
          `${result.errorCode.length > 0 ?
            result.errorCode : 'ACTION_PLAN_MODEL_FAILED'}: ${result.message}`
        );
      }
      const parsed = new ActionPlanProposalParser().parse(
        result.argumentsJson
      );
      if (!parsed.ok || parsed.proposal === null) {
        aiLogError(
          '[AIPhone][ActionPlanCompilerFailed] stage=proposal_parse code=' +
          parsed.code
        );
        throw new Error(`${parsed.code}: ${parsed.message}`);
      }
      let proposal: ProposedActionPlan = parsed.proposal;
      if (preboundOffer !== null) {
        const entryStep: ProposedActionStep = {
          stepId: PREBOUND_ENTRY_STEP_ID,
          actionId: preboundOffer.actionId,
          offerId: preboundOffer.offerId,
          args: new Object(),
          inputFrom: []
        };
        const combinedSteps: ProposedActionStep[] = [entryStep];
        for (let index = 0; index < parsed.proposal.steps.length; index++) {
          combinedSteps.push(parsed.proposal.steps[index]);
        }
        proposal = {
          protocolVersion: parsed.proposal.protocolVersion,
          label: parsed.proposal.label,
          steps: combinedSteps
        };
      }
      const built = new ActionPlanDraftBuilder(this.identities).build(
        proposal,
        context.actions
      );
      if (!built.ok || built.draft === null) {
        aiLogError(
          '[AIPhone][ActionPlanCompilerFailed] stage=draft_build code=' +
          built.code
        );
        throw new Error(`${built.code}: ${built.message}`);
      }
      aiLogInfo(
        '[AIPhone][ActionPlanCompilerSuccess] steps=' +
        built.draft.steps.length.toString()
      );
      return built.draft;
    });
  }
}
