import { ToolRiskLevel } from '../../../aiphone/runtime/ToolDefinitionTypes';
import { ActionOffer } from '../ActionOfferTypes';
import { ActionJsonSchema } from '../schema/ActionJsonSchema';
import { AvailableAction } from './ActionPlanningContextBuilder';

export interface ActionPlanningPromptOffer {
  offerId: string;
  actionId: string;
  label: string;
  variant: string;
  args: Object;
}

export interface ActionPlanningPromptAction {
  actionId: string;
  domain: string;
  intent: string;
  riskLevel: ToolRiskLevel;
  inputSchema: ActionJsonSchema;
  outputSchema: ActionJsonSchema;
  offers: ActionPlanningPromptOffer[];
}

export interface ActionPlanningPreboundEntry {
  stepId: string;
  actionId: string;
  outputSchema: ActionJsonSchema;
}

export interface ActionPlanningPromptPayload {
  goal: string;
  availableActions: ActionPlanningPromptAction[];
  preboundEntryStep?: ActionPlanningPreboundEntry;
  requiredRemainingActionOrder?: string[];
}

export interface ActionPlanningPrompt {
  systemPrompt: string;
  userPrompt: string;
}

export interface ActionPlanningPromptBuildResult {
  ok: boolean;
  prompt: ActionPlanningPrompt | null;
  code: string;
  message: string;
}

const CANDIDATE_ENTRY_SYSTEM_PROMPT: string =
  'Submit exactly one complete finite serial Action plan through the provided function tool. ' +
  'The first step must select one ready Offer and must use args={} and inputFrom=[]; ' +
  'the runtime preserves that Offer args unchanged. Treat the first step as a special ' +
  'case: its offerId must be a non-null Offer id copied exactly from the offers array of ' +
  'the same available Action. If at least one ready Offer is provided, offerId=null is ' +
  'always invalid for step 1. A valid first step selects the matching Action and exact ' +
  'ready offerId while using args={} and inputFrom=[]. An invalid first step uses ' +
  'offerId=null, supplies its own args, or selects an Offer belonging to another Action. ' +
  'Only step 2 and later may use offerId=null. ';

const PREBOUND_ENTRY_SYSTEM_PROMPT: string =
  'Submit exactly one finite serial tail plan through the provided function tool. ' +
  'The runtime has already selected, authorized, and fully parameterized the immutable ' +
  'preboundEntryStep. Do not select an Offer for it, do not generate or modify its args, ' +
  'and do not include the prebound entry in the submitted steps. Submit every Action in ' +
  'requiredRemainingActionOrder exactly once and in that exact order. Every submitted ' +
  'tail step must use offerId=null. You may reference the prebound entry output only by ' +
  'its declared stepId and outputSchema when a real business dependency requires it. ';

const COMMON_ACTION_PLANNING_SYSTEM_PROMPT: string =
  'Derived steps may use constant args and inputFrom bindings from earlier step outputs. ' +
  'Before creating any binding, decide whether the later Action truly requires a ' +
  'business value that will only become known from an earlier Action output. Execution ' +
  'order alone does not imply a data dependency. Actions being adjacent, belonging to ' +
  'the same user request, or exposing fields with the same JSON type also do not imply ' +
  'a data dependency. When a later Action can be fully configured from constants stated ' +
  'in the goal, put those constants in args and set inputFrom=[]; do not create a binding ' +
  'merely to connect the steps. Create inputFrom only for a value that is dynamically ' +
  'produced by an earlier step and is semantically required by a later step. Every ' +
  'binding path must be a JSON Pointer explicitly declared by the source Action output ' +
  'schema, every binding target must be a JSON Pointer explicitly declared by the target ' +
  'Action input schema, and their schemas must be type-compatible. Never invent a source ' +
  'or target path. Never bind a value only because both fields are strings or otherwise ' +
  'type-compatible. Runtime envelope metadata such as actionId, pageActionId, ' +
  'conversationId, turnId, surfaceId, and status is not business data and must not be ' +
  'bound into another Action input. Never copy, predict, or invent a runtime output as ' +
  'a constant. Example with no dependency: a coffee order preview followed by a payment ' +
  'uses inputFrom=[] for the payment when its recipient, amount, currency, and provider ' +
  'all come from the user goal; the fact that payment executes second does not make the ' +
  'coffee result its input. Example with a real dependency: after social.post.preview, ' +
  'gmail.draft.create may bind source path /data/socialHub/publication/text to target ' +
  '/body when the goal explicitly asks to save the generated preview text as the draft ' +
  'body; recipient and subject remain constant args from the goal. Invalid examples: do ' +
  'not bind /conversationId to /conversationId, do not bind /status to /body, and do not ' +
  'name any target field absent from the target input schema. For an ' +
  'explicit ordered workflow, preserve the requested Action order and include every ' +
  'requested Action exactly once. Do not add branches, loops, retries, conditions, ' +
  'replanning, undeclared fields, or unavailable Actions.';

function failure(
  code: string,
  message: string
): ActionPlanningPromptBuildResult {
  return {
    ok: false,
    prompt: null,
    code,
    message
  };
}

function promptOffer(offer: ActionOffer): ActionPlanningPromptOffer {
  return {
    offerId: offer.offerId,
    actionId: offer.actionId,
    label: offer.label,
    variant: offer.variant,
    args: offer.args
  };
}

function promptAction(action: AvailableAction): ActionPlanningPromptAction {
  const offers: ActionPlanningPromptOffer[] = [];
  for (let index = 0; index < action.offers.length; index++) {
    offers.push(promptOffer(action.offers[index]));
  }
  return {
    actionId: action.definition.actionId,
    domain: action.definition.domain,
    intent: action.definition.intent,
    riskLevel: action.definition.riskLevel,
    inputSchema: action.definition.inputSchema,
    outputSchema: action.definition.outputSchema,
    offers
  };
}

/**
 * Converts deterministic planning context into model-facing strings.
 *
 * Runtime fingerprints, schema ids, backend metadata and auth metadata are
 * omitted from the model payload by an explicit projection.
 */
export class ActionPlanningPromptBuilder {
  build(
    goal: string,
    actions: AvailableAction[],
    preboundEntry: ActionPlanningPreboundEntry | null = null
  ): ActionPlanningPromptBuildResult {
    if (typeof goal !== 'string' || goal.trim().length === 0) {
      return failure(
        'ACTION_PLAN_GOAL_EMPTY',
        'Action planning goal must not be empty.'
      );
    }
    if (!Array.isArray(actions) || actions.length === 0) {
      return failure(
        'ACTION_PLAN_AVAILABLE_ACTIONS_EMPTY',
        'Action planning requires at least one available Action.'
      );
    }
    const availableActions: ActionPlanningPromptAction[] = [];
    for (let index = 0; index < actions.length; index++) {
      const action = actions[index];
      if (action === null || typeof action !== 'object' ||
        action.definition === null ||
        typeof action.definition !== 'object' ||
        action.definition.actionId.trim().length === 0 ||
        !Array.isArray(action.offers)) {
        return failure(
          'ACTION_PLAN_AVAILABLE_ACTION_INVALID',
          `Available Action at index ${index} is malformed.`
        );
      }
      for (let offerIndex = 0;
        offerIndex < action.offers.length;
        offerIndex++) {
        if (action.offers[offerIndex].actionId !==
          action.definition.actionId) {
          return failure(
            'ACTION_PLAN_OFFER_ACTION_MISMATCH',
            `Action Offer does not match its definition at index ${index}.`
          );
        }
      }
      availableActions.push(promptAction(action));
    }
    let payload: ActionPlanningPromptPayload;
    let systemPrompt: string;
    if (preboundEntry === null) {
      payload = {
        goal,
        availableActions
      };
      systemPrompt =
        CANDIDATE_ENTRY_SYSTEM_PROMPT +
        COMMON_ACTION_PLANNING_SYSTEM_PROMPT;
    } else {
      if (preboundEntry.stepId.trim().length === 0 ||
        preboundEntry.actionId.trim().length === 0) {
        return failure(
          'ACTION_PLAN_PREBOUND_ENTRY_INVALID',
          'Prebound Action entry identity must not be empty.'
        );
      }
      const requiredRemainingActionOrder: string[] = [];
      for (let index = 0; index < availableActions.length; index++) {
        requiredRemainingActionOrder.push(availableActions[index].actionId);
      }
      payload = {
        goal,
        availableActions,
        preboundEntryStep: preboundEntry,
        requiredRemainingActionOrder
      };
      systemPrompt =
        PREBOUND_ENTRY_SYSTEM_PROMPT +
        COMMON_ACTION_PLANNING_SYSTEM_PROMPT;
    }
    try {
      const userPrompt = JSON.stringify(payload);
      if (userPrompt.length === 0) {
        return failure(
          'ACTION_PLAN_PROMPT_SERIALIZATION_FAILED',
          'Action planning prompt serialization returned an empty value.'
        );
      }
      return {
        ok: true,
        prompt: {
          systemPrompt,
          userPrompt
        },
        code: '',
        message: ''
      };
    } catch (_error) {
      return failure(
        'ACTION_PLAN_PROMPT_SERIALIZATION_FAILED',
        'Action planning prompt serialization failed.'
      );
    }
  }
}
