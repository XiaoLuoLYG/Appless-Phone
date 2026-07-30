import { JsonValue } from '../ActionPlanTypes';
import { AvailableAction } from './ActionPlanningContextBuilder';
import { ACTION_PLAN_PROPOSAL_VERSION } from './ActionPlanProposalTypes';
import {
  ActionPlanningFunctionTool
} from './model/ActionPlanningModel';

export const ACTION_PLAN_SUBMIT_TOOL_NAME: string = 'submit_action_plan';

export interface ActionPlanningJsonSchema {
  type?: string;
  description?: string;
  properties?: Record<string, ActionPlanningJsonSchema>;
  required?: string[];
  additionalProperties?: boolean;
  items?: ActionPlanningJsonSchema;
  enum?: JsonValue[];
  const?: JsonValue;
  minLength?: number;
  minItems?: number;
  maxItems?: number;
  pattern?: string;
  anyOf?: ActionPlanningJsonSchema[];
}

export interface ActionPlanSubmissionToolBuildResult {
  ok: boolean;
  tool: ActionPlanningFunctionTool | null;
  code: string;
  message: string;
}

function failure(
  code: string,
  message: string
): ActionPlanSubmissionToolBuildResult {
  return {
    ok: false,
    tool: null,
    code,
    message
  };
}

function stringSchema(
  description: string
): ActionPlanningJsonSchema {
  return {
    type: 'string',
    description,
    minLength: 1
  };
}

function pointerSchema(description: string): ActionPlanningJsonSchema {
  return {
    type: 'string',
    description,
    pattern: '^(|/.*)$'
  };
}

function bindingSchema(): ActionPlanningJsonSchema {
  const properties: Record<string, ActionPlanningJsonSchema> = {};
  properties['target'] = pointerSchema(
    'A JSON Pointer into the selected target Action input.'
  );
  properties['stepId'] = stringSchema(
    'The id of an earlier source step.'
  );
  properties['path'] = pointerSchema(
    'A JSON Pointer into the source step output.'
  );
  return {
    type: 'object',
    properties,
    required: ['target', 'stepId', 'path'],
    additionalProperties: false
  };
}

function nullableOfferIdSchema(
  offerIds: JsonValue[],
  tailOnly: boolean
): ActionPlanningJsonSchema {
  const nullSchema: ActionPlanningJsonSchema = {
    type: 'null',
    description: tailOnly ?
      'Every submitted tail step after the prebound entry must use null.' :
      'Use null only for step 2 or later when deriving inputs without an Offer.'
  };
  if (offerIds.length === 0) {
    return nullSchema;
  }
  const readyOfferSchema: ActionPlanningJsonSchema = {
    type: 'string',
    description: 'The exact id of one currently available Action Offer.',
    enum: offerIds
  };
  return {
    description:
      'A ready Offer id, or null when args and inputFrom build the inputs.',
    anyOf: [readyOfferSchema, nullSchema]
  };
}

function stepSchema(
  actionIds: JsonValue[],
  offerIds: JsonValue[],
  tailOnly: boolean
): ActionPlanningJsonSchema {
  const actionIdSchema: ActionPlanningJsonSchema = {
    type: 'string',
    description: 'The exact id of one Leader-allowed Action.',
    enum: actionIds
  };
  const argsSchema: ActionPlanningJsonSchema = {
    type: 'object',
    description:
      'Constants for a derived step; use {} when offerId selects an Offer.',
    additionalProperties: true
  };
  const inputFromSchema: ActionPlanningJsonSchema = {
    type: 'array',
    description: 'Bindings from earlier step outputs; use [] when none.',
    items: bindingSchema(),
    minItems: 0,
    maxItems: 64
  };
  const properties: Record<string, ActionPlanningJsonSchema> = {};
  properties['stepId'] = stringSchema(
    'A unique local id for this serial Action step.'
  );
  properties['actionId'] = actionIdSchema;
  properties['offerId'] = nullableOfferIdSchema(offerIds, tailOnly);
  properties['args'] = argsSchema;
  properties['inputFrom'] = inputFromSchema;
  return {
    type: 'object',
    properties,
    required: ['stepId', 'actionId', 'offerId', 'args', 'inputFrom'],
    additionalProperties: false
  };
}

function parametersSchema(
  actionIds: JsonValue[],
  offerIds: JsonValue[],
  tailOnly: boolean,
  exactStepCount: number = 0
): ActionPlanningJsonSchema {
  const versionSchema: ActionPlanningJsonSchema = {
    type: 'string',
    const: ACTION_PLAN_PROPOSAL_VERSION
  };
  const stepsSchema: ActionPlanningJsonSchema = {
    type: 'array',
    items: stepSchema(actionIds, offerIds, tailOnly),
    minItems: exactStepCount > 0 ? exactStepCount : 1,
    maxItems: exactStepCount > 0 ? exactStepCount : 5
  };
  const properties: Record<string, ActionPlanningJsonSchema> = {};
  properties['protocolVersion'] = versionSchema;
  properties['label'] = stringSchema(
    'A short user-facing label for the complete plan.'
  );
  properties['steps'] = stepsSchema;
  return {
    type: 'object',
    properties,
    required: ['protocolVersion', 'label', 'steps'],
    additionalProperties: false
  };
}

/**
 * Builds the strict Function Tool used to submit one Action Plan proposal.
 *
 * The schema constrains structure, allowed Action selection and optional
 * ready Offer selection. Cross-step references and input/output schema
 * compatibility remain deterministic validator work.
 */
export class ActionPlanSubmissionToolBuilder {
  build(
    actions: AvailableAction[],
    tailOnly: boolean = false
  ): ActionPlanSubmissionToolBuildResult {
    if (!Array.isArray(actions) || actions.length === 0) {
      return failure(
        'ACTION_PLAN_AVAILABLE_ACTIONS_EMPTY',
        'Action plan submission requires at least one available Action.'
      );
    }
    const actionIds: JsonValue[] = [];
    const offerIds: JsonValue[] = [];
    const seenActions: Set<string> = new Set<string>();
    const seenOffers: Set<string> = new Set<string>();
    for (let actionIndex = 0;
      actionIndex < actions.length;
      actionIndex++) {
      const action = actions[actionIndex];
      if (action === null || typeof action !== 'object' ||
        action.definition === null ||
        typeof action.definition !== 'object' ||
        action.definition.actionId.trim().length === 0 ||
        !Array.isArray(action.offers)) {
        return failure(
          'ACTION_PLAN_AVAILABLE_ACTION_INVALID',
          `Available Action at index ${actionIndex} is malformed.`
        );
      }
      if (seenActions.has(action.definition.actionId)) {
        return failure(
          'ACTION_PLAN_AVAILABLE_ACTION_DUPLICATE',
          `Available Action id is duplicated: ${action.definition.actionId}.`
        );
      }
      seenActions.add(action.definition.actionId);
      actionIds.push(action.definition.actionId);
      for (let offerIndex = 0;
        offerIndex < action.offers.length;
        offerIndex++) {
        const offer = action.offers[offerIndex];
        if (offer === null || typeof offer !== 'object' ||
          offer.offerId.trim().length === 0 ||
          offer.actionId !== action.definition.actionId) {
          return failure(
            'ACTION_PLAN_OFFER_INVALID',
            `Action Offer at index ${actionIndex}/${offerIndex} is invalid.`
          );
        }
        if (seenOffers.has(offer.offerId)) {
          return failure(
            'ACTION_PLAN_OFFER_DUPLICATE',
            `Action Offer id is duplicated: ${offer.offerId}.`
          );
        }
        seenOffers.add(offer.offerId);
        if (!tailOnly) {
          offerIds.push(offer.offerId);
        }
      }
    }
    const tool: ActionPlanningFunctionTool = {
      type: 'function',
      function: {
        name: ACTION_PLAN_SUBMIT_TOOL_NAME,
        description: tailOnly ?
          'Submit only the serial tail steps after the runtime-owned prebound entry.' :
          'Submit exactly one complete serial Action Plan using available Offer ids.',
        strict: true,
        parameters: parametersSchema(
          actionIds,
          offerIds,
          tailOnly,
          tailOnly ? actionIds.length : 0
        )
      }
    };
    return {
      ok: true,
      tool,
      code: '',
      message: ''
    };
  }
}
