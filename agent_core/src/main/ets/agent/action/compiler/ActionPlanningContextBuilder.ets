import { ActionOffer } from '../ActionOfferTypes';
import { JsonValue } from '../ActionPlanTypes';
import { cloneJsonValue, JsonPointerResult } from '../JsonPointer';
import {
  SchemaAwareActionDefinition,
  SchemaAwareActionDefinitionLookup,
  SchemaAwareActionDefinitionResult
} from '../schema/SchemaAwareActionDefinition';

export interface AvailableAction {
  definition: SchemaAwareActionDefinition;
  offers: ActionOffer[];
}

export interface ActionPlanningContextBuildResult {
  ok: boolean;
  actions: AvailableAction[];
  code: string;
  message: string;
}

function failure(
  code: string,
  message: string
): ActionPlanningContextBuildResult {
  return {
    ok: false,
    actions: [],
    code,
    message
  };
}

function nonempty(value: string): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function cloneOffer(offer: ActionOffer): ActionOffer | null {
  if (offer === null || typeof offer !== 'object' ||
    !nonempty(offer.offerId) || !nonempty(offer.actionId) ||
    !nonempty(offer.label) || !nonempty(offer.variant) ||
    offer.args === null || typeof offer.args !== 'object' ||
    Array.isArray(offer.args)) {
    return null;
  }
  const cloned: JsonPointerResult = cloneJsonValue(
    offer.args as JsonValue
  );
  if (!cloned.ok || cloned.value === null ||
    typeof cloned.value !== 'object' || Array.isArray(cloned.value)) {
    return null;
  }
  return {
    offerId: offer.offerId,
    actionId: offer.actionId,
    label: offer.label,
    variant: offer.variant,
    args: cloned.value as Object
  };
}

/**
 * Builds the deterministic, model-independent Action planning context.
 *
 * Every allowed Action is resolved, including Actions without a ready Offer.
 * Ready Offers are attached when present. Prompt formatting and model
 * invocation deliberately remain outside this boundary.
 */
export class ActionPlanningContextBuilder {
  private readonly definitions: SchemaAwareActionDefinitionLookup;

  constructor(definitions: SchemaAwareActionDefinitionLookup) {
    this.definitions = definitions;
  }

  build(
    offers: ActionOffer[],
    allowedActionIds: string[]
  ): ActionPlanningContextBuildResult {
    try {
      if (!Array.isArray(offers)) {
        return failure(
          'ACTION_PLAN_OFFERS_INVALID',
          'Action planning Offers must be an array.'
        );
      }
      const allowed: Set<string> = new Set<string>();
      for (let index = 0; index < allowedActionIds.length; index++) {
        const actionId = allowedActionIds[index];
        if (!nonempty(actionId)) {
          return failure(
            'ACTION_PLAN_ALLOWED_ACTION_INVALID',
            'Allowed Action ids must not be empty.'
          );
        }
        if (allowed.has(actionId)) {
          return failure(
            'ACTION_PLAN_ALLOWED_ACTION_DUPLICATE',
            `Allowed Action id is duplicated: ${actionId}.`
          );
        }
        allowed.add(actionId);
      }
      if (allowed.size === 0) {
        return failure(
          'ACTION_PLAN_ALLOWED_ACTIONS_EMPTY',
          'Action planning requires at least one allowed Action.'
        );
      }

      const grouped: Map<string, ActionOffer[]> =
        new Map<string, ActionOffer[]>();
      const offerIds: Set<string> = new Set<string>();
      for (let index = 0; index < offers.length; index++) {
        const offer = cloneOffer(offers[index]);
        if (offer === null) {
          return failure(
            'ACTION_PLAN_OFFER_INVALID',
            `Action Offer at index ${index} is malformed.`
          );
        }
        if (!allowed.has(offer.actionId)) {
          return failure(
            'ACTION_PLAN_OFFER_UNAUTHORIZED',
            `Action Offer is not authorized: ${offer.offerId}.`
          );
        }
        if (offerIds.has(offer.offerId)) {
          return failure(
            'ACTION_PLAN_OFFER_DUPLICATE',
            `Action Offer id is duplicated: ${offer.offerId}.`
          );
        }
        offerIds.add(offer.offerId);
        const current = grouped.get(offer.actionId);
        if (current === undefined) {
          grouped.set(offer.actionId, [offer]);
        } else {
          current.push(offer);
        }
      }

      const actions: AvailableAction[] = [];
      for (let index = 0; index < allowedActionIds.length; index++) {
        const actionId = allowedActionIds[index];
        const actionOffers = grouped.get(actionId);
        const resolved: SchemaAwareActionDefinitionResult =
          this.definitions.find(actionId);
        if (!resolved.ok || resolved.definition === null) {
          return failure(
            resolved.code.length > 0 ?
              resolved.code : 'ACTION_DEFINITION_RESOLUTION_FAILED',
            resolved.message.length > 0 ?
              resolved.message : 'Action definition resolution failed.'
          );
        }
        actions.push({
          definition: resolved.definition,
          offers: actionOffers === undefined ? [] : actionOffers
        });
      }
      return {
        ok: true,
        actions,
        code: '',
        message: ''
      };
    } catch (_error) {
      return failure(
        'ACTION_PLAN_CONTEXT_BUILD_FAILED',
        'Action planning context construction failed.'
      );
    }
  }
}
