import { ActionInputBinding } from '../ActionPlanTypes';

export const ACTION_PLAN_PROPOSAL_VERSION: string =
  'action.plan.proposal.v1';

export interface ProposedActionStep {
  stepId: string;
  actionId: string;
  offerId: string | null;
  args: Object;
  inputFrom: ActionInputBinding[];
}

/**
 * Model-authored candidate only.
 *
 * Action ids and args are resolved from immutable Offers after parsing.
 * Runtime ids and definition fingerprints are added after validation.
 */
export interface ProposedActionPlan {
  protocolVersion: string;
  label: string;
  steps: ProposedActionStep[];
}
