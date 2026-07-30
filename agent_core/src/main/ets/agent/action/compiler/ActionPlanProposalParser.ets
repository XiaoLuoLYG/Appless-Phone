import { ActionInputBinding, JsonValue } from '../ActionPlanTypes';
import { cloneJsonValue, inspectJsonValue, validateJsonPointer } from '../JsonPointer';
import {
  ACTION_PLAN_PROPOSAL_VERSION,
  ProposedActionPlan,
  ProposedActionStep
} from './ActionPlanProposalTypes';

export interface ActionPlanProposalParseResult {
  ok: boolean;
  proposal: ProposedActionPlan | null;
  code: string;
  message: string;
}

function failure(code: string, message: string): ActionPlanProposalParseResult {
  return {
    ok: false,
    proposal: null,
    code,
    message
  };
}

function nonempty(value: JsonValue | undefined): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function exactKeys(value: Object, expected: string): boolean {
  return Object.keys(value).sort().join(',') === expected;
}

function parseBinding(
  value: JsonValue,
  stepIndex: number,
  bindingIndex: number
): ActionInputBinding | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value) ||
    !exactKeys(value, 'path,stepId,target')) {
    return null;
  }
  const record = value as Record<string, JsonValue | undefined>;
  if (typeof record['target'] !== 'string' ||
    !nonempty(record['stepId']) ||
    typeof record['path'] !== 'string' ||
    !validateJsonPointer(record['target'] as string).ok ||
    !validateJsonPointer(record['path'] as string).ok) {
    return null;
  }
  return {
    target: record['target'] as string,
    stepId: record['stepId'] as string,
    path: record['path'] as string
  };
}

function parseStep(value: JsonValue, index: number): ProposedActionStep | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value) ||
    !exactKeys(value, 'actionId,args,inputFrom,offerId,stepId')) {
    return null;
  }
  const record = value as Record<string, JsonValue | undefined>;
  const offerId = record['offerId'];
  const args = record['args'];
  const inputFrom = record['inputFrom'];
  if (!nonempty(record['stepId']) || !nonempty(record['actionId']) ||
    (offerId !== null && !nonempty(offerId)) ||
    args === null || typeof args !== 'object' || Array.isArray(args) ||
    !Array.isArray(inputFrom) || inputFrom.length > 64) {
    return null;
  }
  const argsClone = cloneJsonValue(args as JsonValue);
  if (!argsClone.ok || argsClone.value === null ||
    typeof argsClone.value !== 'object' || Array.isArray(argsClone.value)) {
    return null;
  }
  const bindings: ActionInputBinding[] = [];
  for (let bindingIndex = 0; bindingIndex < inputFrom.length; bindingIndex++) {
    const binding = parseBinding(
      inputFrom[bindingIndex] as JsonValue,
      index,
      bindingIndex
    );
    if (binding === null) {
      return null;
    }
    bindings.push(binding);
  }
  return {
    stepId: record['stepId'] as string,
    actionId: record['actionId'] as string,
    offerId: offerId === null ? null : offerId as string,
    args: argsClone.value as Object,
    inputFrom: bindings
  };
}

export class ActionPlanProposalParser {
  parse(argumentsJson: string): ActionPlanProposalParseResult {
    try {
      if (typeof argumentsJson !== 'string' || argumentsJson.length === 0) {
        return failure(
          'ACTION_PLAN_PROPOSAL_JSON_INVALID',
          'Action plan proposal JSON is empty.'
        );
      }
      const parsed = JSON.parse(argumentsJson) as JsonValue;
      const inspection = inspectJsonValue(parsed);
      if (!inspection.ok || parsed === null ||
        typeof parsed !== 'object' || Array.isArray(parsed) ||
        !exactKeys(parsed, 'label,protocolVersion,steps')) {
        return failure(
          'ACTION_PLAN_PROPOSAL_MALFORMED',
          'Action plan proposal has an invalid top-level shape.'
        );
      }
      const record = parsed as Record<string, JsonValue | undefined>;
      const stepsValue = record['steps'];
      if (record['protocolVersion'] !== ACTION_PLAN_PROPOSAL_VERSION ||
        !nonempty(record['label']) ||
        !Array.isArray(stepsValue) ||
        stepsValue.length < 1 || stepsValue.length > 5) {
        return failure(
          'ACTION_PLAN_PROPOSAL_MALFORMED',
          'Action plan proposal metadata or step count is invalid.'
        );
      }
      const steps: ProposedActionStep[] = [];
      for (let index = 0; index < stepsValue.length; index++) {
        const step = parseStep(stepsValue[index] as JsonValue, index);
        if (step === null) {
          return failure(
            'ACTION_PLAN_PROPOSAL_STEP_MALFORMED',
            `Action plan proposal step ${index} is malformed.`
          );
        }
        steps.push(step);
      }
      return {
        ok: true,
        proposal: {
          protocolVersion: ACTION_PLAN_PROPOSAL_VERSION,
          label: record['label'] as string,
          steps
        },
        code: '',
        message: ''
      };
    } catch (_error) {
      return failure(
        'ACTION_PLAN_PROPOSAL_JSON_INVALID',
        'Action plan proposal is not valid JSON.'
      );
    }
  }
}
