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

export interface ActionPlanningPromptPayload {
  goal: string;
  availableActions: ActionPlanningPromptAction[];
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

const ACTION_PLANNING_SYSTEM_PROMPT: string =
  'Submit exactly one finite serial Action plan through the provided function tool. ' +
  'The first step must select one ready Offer and must use args={} and inputFrom=[]; ' +
  'the runtime preserves that Offer args unchanged. Later steps may use offerId=null, ' +
  'constant args, and inputFrom bindings from earlier step outputs. When the goal says ' +
  'a later input comes from an earlier output, use inputFrom with declared JSON Pointer ' +
  'paths; never copy, predict, or invent that runtime output as a constant. For an ' +
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
    actions: AvailableAction[]
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
    const payload: ActionPlanningPromptPayload = {
      goal,
      availableActions
    };
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
          systemPrompt: ACTION_PLANNING_SYSTEM_PROMPT,
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
