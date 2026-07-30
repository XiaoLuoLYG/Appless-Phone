import {
  ActionInputBinding,
  ActionPlanDraft,
  ActionPlanStep,
  JsonValue
} from '../ActionPlanTypes';
import { cloneJsonValue, resolveJsonPointer } from '../JsonPointer';
import {
  ActionJsonSchema,
  cloneActionSchema,
  validateActionValue
} from '../schema/ActionJsonSchema';
import {
  actionSchemaPointersOverlap,
  actionSchemasAssignable,
  resolveActionSchemaPath
} from '../schema/ActionSchemaCompatibility';
import { AvailableAction } from './ActionPlanningContextBuilder';
import { ProposedActionPlan } from './ActionPlanProposalTypes';

export interface ActionPlanIdentity {
  planId: string;
  runId: string;
}

export interface ActionPlanIdentityFactory {
  create(): ActionPlanIdentity;
}

export interface ActionPlanDraftBuildResult {
  ok: boolean;
  draft: ActionPlanDraft | null;
  code: string;
  message: string;
}

function failure(code: string, message: string): ActionPlanDraftBuildResult {
  return {
    ok: false,
    draft: null,
    code,
    message
  };
}

function partialSchema(schema: ActionJsonSchema): ActionJsonSchema {
  const clone = cloneActionSchema(schema);
  if (clone.type === 'object') {
    clone.required = [];
    if (clone.properties !== undefined) {
      const keys = Object.keys(clone.properties);
      for (let index = 0; index < keys.length; index++) {
        clone.properties[keys[index]] =
          partialSchema(clone.properties[keys[index]]);
      }
    }
  } else if (clone.type === 'array' && clone.items !== undefined) {
    clone.items = partialSchema(clone.items);
  }
  return clone;
}

function escapeToken(token: string): string {
  return token.replace(/~/g, '~0').replace(/\//g, '~1');
}

function requiredLeafPaths(
  schema: ActionJsonSchema,
  parent: string
): string[] {
  if (schema.type !== 'object' || schema.properties === undefined) {
    return [parent];
  }
  const required = schema.required === undefined ? [] : schema.required;
  const result: string[] = [];
  for (let index = 0; index < required.length; index++) {
    const key = required[index];
    const path = `${parent}/${escapeToken(key)}`;
    const child = schema.properties[key];
    const nested = requiredLeafPaths(child, path);
    if (nested.length === 0) {
      result.push(path);
    } else {
      for (let nestedIndex = 0; nestedIndex < nested.length; nestedIndex++) {
        result.push(nested[nestedIndex]);
      }
    }
  }
  return result;
}

function bindingCovers(path: string, bindings: ActionInputBinding[]): boolean {
  for (let index = 0; index < bindings.length; index++) {
    const target = bindings[index].target;
    if (target === '' || target === path || path.startsWith(`${target}/`)) {
      return true;
    }
  }
  return false;
}

function actionById(
  actions: AvailableAction[],
  actionId: string
): AvailableAction | null {
  for (let index = 0; index < actions.length; index++) {
    if (actions[index].definition.actionId === actionId) {
      return actions[index];
    }
  }
  return null;
}

function stepById(steps: ActionPlanStep[], stepId: string): ActionPlanStep | null {
  for (let index = 0; index < steps.length; index++) {
    if (steps[index].stepId === stepId) {
      return steps[index];
    }
  }
  return null;
}

function cloneObject(value: Object): Object | null {
  const cloned = cloneJsonValue(value as JsonValue);
  if (!cloned.ok || cloned.value === null ||
    typeof cloned.value !== 'object' || Array.isArray(cloned.value)) {
    return null;
  }
  return cloned.value as Object;
}

export class DefaultActionPlanIdentityFactory
  implements ActionPlanIdentityFactory {
  private sequence: number = 0;

  create(): ActionPlanIdentity {
    this.sequence++;
    const suffix = `${Date.now().toString()}-${this.sequence.toString()}`;
    return {
      planId: `action-plan:${suffix}`,
      runId: `action-run:${suffix}`
    };
  }
}

export class ActionPlanDraftBuilder {
  private readonly identities: ActionPlanIdentityFactory;

  constructor(identities: ActionPlanIdentityFactory) {
    this.identities = identities;
  }

  build(
    proposal: ProposedActionPlan,
    actions: AvailableAction[]
  ): ActionPlanDraftBuildResult {
    try {
      const normalized: ActionPlanStep[] = [];
      const seenStepIds: Set<string> = new Set<string>();
      for (let index = 0; index < proposal.steps.length; index++) {
        const proposed = proposal.steps[index];
        if (seenStepIds.has(proposed.stepId)) {
          return failure(
            'ACTION_PLAN_STEP_ID_DUPLICATE',
            `Action plan step id is duplicated: ${proposed.stepId}.`
          );
        }
        seenStepIds.add(proposed.stepId);
        const action = actionById(actions, proposed.actionId);
        if (action === null) {
          return failure(
            'ACTION_PLAN_ACTION_UNAUTHORIZED',
            `Action is not available to this plan: ${proposed.actionId}.`
          );
        }
        if (index === 0 && proposed.offerId === null) {
          return failure(
            'ACTION_PLAN_ENTRY_OFFER_REQUIRED',
            'An Action plan must start from a ready Offer.'
          );
        }
        if (proposed.offerId !== null) {
          if (Object.keys(proposed.args).length !== 0 ||
            proposed.inputFrom.length !== 0) {
            return failure(
              'ACTION_PLAN_OFFER_STEP_OVERRIDE',
              'Offer steps cannot override args or bind prior outputs.'
            );
          }
          let offerArgs: Object | null = null;
          for (let offerIndex = 0;
            offerIndex < action.offers.length;
            offerIndex++) {
            if (action.offers[offerIndex].offerId === proposed.offerId &&
              action.offers[offerIndex].actionId === proposed.actionId) {
              offerArgs = cloneObject(action.offers[offerIndex].args);
              break;
            }
          }
          if (offerArgs === null) {
            return failure(
              'ACTION_PLAN_OFFER_MISMATCH',
              `Action Offer is unavailable or belongs to another Action: ${proposed.offerId}.`
            );
          }
          const offerValidation = validateActionValue(
            action.definition.inputSchema,
            offerArgs as JsonValue
          );
          if (!offerValidation.ok) {
            return failure(
              offerValidation.code,
              `Action Offer args are invalid: ${offerValidation.message}`
            );
          }
          normalized.push({
            stepId: proposed.stepId,
            actionId: proposed.actionId,
            offerId: proposed.offerId,
            args: offerArgs,
            inputFrom: []
          });
          continue;
        }

        const args = cloneObject(proposed.args);
        if (args === null) {
          return failure(
            'ACTION_ARGS_MALFORMED',
            `Derived Action args are malformed: ${proposed.stepId}.`
          );
        }
        const partial = validateActionValue(
          partialSchema(action.definition.inputSchema),
          args as JsonValue
        );
        if (!partial.ok) {
          return failure(partial.code, partial.message);
        }
        const bindings: ActionInputBinding[] = [];
        for (let bindingIndex = 0;
          bindingIndex < proposed.inputFrom.length;
          bindingIndex++) {
          const binding = proposed.inputFrom[bindingIndex];
          for (let priorIndex = 0; priorIndex < bindings.length; priorIndex++) {
            if (actionSchemaPointersOverlap(
              bindings[priorIndex].target,
              binding.target
            )) {
              return failure(
                'ACTION_PLAN_BINDING_TARGET_CONFLICT',
                `Action input bindings overlap: ${proposed.stepId}.`
              );
            }
          }
          if (resolveJsonPointer(args as JsonValue, binding.target).ok &&
            !(binding.target === '' && Object.keys(args).length === 0)) {
            return failure(
              'ACTION_PLAN_BINDING_ARG_CONFLICT',
              `Action input binding overwrites a constant arg: ${binding.target}.`
            );
          }
          const sourceStep = stepById(normalized, binding.stepId);
          if (sourceStep === null) {
            return failure(
              'ACTION_PLAN_BINDING_SOURCE',
              'Action bindings can reference only earlier steps.'
            );
          }
          const sourceAction = actionById(actions, sourceStep.actionId);
          const sourceSchema = sourceAction === null ? null :
            resolveActionSchemaPath(
              sourceAction.definition.outputSchema,
              binding.path
            );
          const targetSchema = resolveActionSchemaPath(
            action.definition.inputSchema,
            binding.target
          );
          if (sourceSchema === null || !sourceSchema.ok ||
            sourceSchema.schema === null) {
            return failure(
              'ACTION_PLAN_BINDING_SOURCE_SCHEMA',
              `Binding source path is not declared: ${binding.path}.`
            );
          }
          if (!targetSchema.ok || targetSchema.schema === null) {
            return failure(
              'ACTION_PLAN_BINDING_TARGET_SCHEMA',
              `Binding target path is not declared: ${binding.target}.`
            );
          }
          if (!actionSchemasAssignable(
            sourceSchema.schema,
            targetSchema.schema
          )) {
            return failure(
              'ACTION_PLAN_BINDING_SCHEMA_MISMATCH',
              `Binding schemas are incompatible for ${proposed.stepId}.`
            );
          }
          bindings.push({
            target: binding.target,
            stepId: binding.stepId,
            path: binding.path
          });
        }
        const required = requiredLeafPaths(action.definition.inputSchema, '');
        for (let requiredIndex = 0;
          requiredIndex < required.length;
          requiredIndex++) {
          if (!resolveJsonPointer(args as JsonValue, required[requiredIndex]).ok &&
            !bindingCovers(required[requiredIndex], bindings)) {
            return failure(
              'ACTION_PLAN_REQUIRED_INPUT_MISSING',
              `Derived Action input is not covered: ${required[requiredIndex]}.`
            );
          }
        }
        normalized.push({
          stepId: proposed.stepId,
          actionId: proposed.actionId,
          offerId: null,
          args,
          inputFrom: bindings
        });
      }
      const identity = this.identities.create();
      if (identity.planId.trim().length === 0 ||
        identity.runId.trim().length === 0) {
        return failure(
          'ACTION_PLAN_IDENTITY_INVALID',
          'Action plan identity factory returned invalid ids.'
        );
      }
      return {
        ok: true,
        draft: {
          planId: identity.planId,
          runId: identity.runId,
          label: proposal.label,
          steps: normalized
        },
        code: '',
        message: ''
      };
    } catch (_error) {
      return failure(
        'ACTION_PLAN_PROPOSAL_VALIDATION_FAILED',
        'Action plan proposal validation failed closed.'
      );
    }
  }
}
