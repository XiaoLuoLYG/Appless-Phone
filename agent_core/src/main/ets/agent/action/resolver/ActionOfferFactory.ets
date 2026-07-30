import { ActionArgsValidator } from '../ActionCatalogTypes';
import {
  ActionOffer,
  ActionOfferContext
} from '../ActionOfferTypes';
import { cloneJsonValue } from '../JsonPointer';
import { ActionCandidate } from './ActionCandidateTypes';

function nonempty(value: string): boolean {
  return value.trim().length > 0;
}

function objectArgs(value: Object): boolean {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function offerId(
  context: ActionOfferContext,
  actionId: string,
  identity: string
): string {
  return context.dataTaskId + ':' + actionId + ':' + identity;
}

export class ActionOfferFactory {
  private readonly validator: ActionArgsValidator;

  constructor(validator: ActionArgsValidator) {
    this.validator = validator;
  }

  create(
    candidate: ActionCandidate,
    context: ActionOfferContext
  ): ActionOffer | null {
    if (candidate === null || typeof candidate !== 'object' ||
      !nonempty(candidate.identity) || !nonempty(candidate.actionId) ||
      !nonempty(candidate.label) || !nonempty(candidate.variant) ||
      !objectArgs(candidate.args)) {
      return null;
    }
    try {
      if (!this.validator.validate(candidate.actionId, candidate.args).ok) {
        return null;
      }
      const cloned = cloneJsonValue(candidate.args);
      if (!cloned.ok || cloned.value === undefined || cloned.value === null ||
        typeof cloned.value !== 'object' || Array.isArray(cloned.value)) {
        return null;
      }
      return {
        offerId: offerId(context, candidate.actionId, candidate.identity),
        actionId: candidate.actionId,
        label: candidate.label,
        variant: candidate.variant,
        args: cloned.value as Object
      };
    } catch (_error) {
      return null;
    }
  }

  createAll(
    candidates: ActionCandidate[],
    context: ActionOfferContext
  ): ActionOffer[] {
    const offers: ActionOffer[] = [];
    const ids: Set<string> = new Set<string>();
    for (let index = 0; index < candidates.length; index++) {
      const offer = this.create(candidates[index], context);
      if (offer === null || ids.has(offer.offerId)) {
        continue;
      }
      ids.add(offer.offerId);
      offers.push(offer);
    }
    return offers;
  }
}
