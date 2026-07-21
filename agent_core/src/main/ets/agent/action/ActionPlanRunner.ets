import { ActionCatalog } from './ActionCatalog';
import { ActionCatalogResult } from './ActionCatalogTypes';
import {
  ActionExecutionContext,
  ActionInputBinding,
  ActionPlan,
  ActionPlanDraft,
  ActionPlanErrorOutcome,
  ActionPlanOutcome,
  ActionPlanPausedOutcome,
  ActionPlanRunContext,
  ActionPlanStep,
  ActionPlanStepOutput,
  ActionPlanValidationResult,
  ActionStepExecutionResult,
  ActionStepExecutor,
  JsonValue
} from './ActionPlanTypes';
import {
  JsonPointerResult,
  JsonPointerSetResult,
  cloneJsonValue,
  inspectJsonValue,
  resolveJsonPointer,
  setJsonPointer,
  validateJsonPointer
} from './JsonPointer';

interface CompletedStep {
  stepId: string;
  output: JsonValue;
}

interface ForbiddenFieldResult {
  ok: boolean;
  field: string;
}

interface ContextSnapshotResult {
  ok: boolean;
  value: ActionPlanRunContext | null;
  errorCode: string;
  message: string;
}

interface CompletedSnapshotResult {
  ok: boolean;
  completed: CompletedStep[];
  errorCode: string;
  message: string;
}

const FORBIDDEN_FIELDS: string[] = [
  'script',
  'expression',
  'loop',
  'branches',
  'parallel',
  'retry',
  'persistence',
  'eval',
  'function'
];
const MAX_ACTION_PLAN_STEPS: number = 5;

function validationFailure(
  failedStepId: string,
  errorCode: string,
  message: string
): ActionPlanValidationResult {
  return {
    ok: false,
    failedStepId: failedStepId,
    errorCode: errorCode,
    message: message
  };
}

function validPlan(): ActionPlanValidationResult {
  return {
    ok: true,
    failedStepId: '',
    errorCode: '',
    message: ''
  };
}

function errorOutcome(
  failedStepId: string,
  errorCode: string,
  message: string,
  completedStepIds: string[]
): ActionPlanErrorOutcome {
  return {
    status: 'error',
    failedStepId: failedStepId,
    errorCode: errorCode,
    message: message,
    completedStepIds: completedStepIds.slice()
  };
}

function pausedOutcome(
  stepId: string,
  errorCode: string,
  message: string,
  nextStepIndex: number,
  completed: CompletedStep[]
): ActionPlanPausedOutcome {
  const outputs: ActionPlanStepOutput[] = [];
  for (let index = 0; index < completed.length; index++) {
    outputs.push({
      stepId: completed[index].stepId,
      output: completed[index].output
    });
  }
  return {
    status: 'paused',
    failedStepId: stepId,
    errorCode,
    message,
    nextStepIndex,
    completedStepIds: completed.map((current: CompletedStep): string => current.stepId),
    outputs
  };
}

function stepArgs(step: ActionPlanStep): Object {
  if (step.args === undefined) {
    const empty: Record<string, JsonValue | undefined> = {};
    return empty;
  }
  return step.args;
}

function isArgsObject(value: JsonValue | undefined): boolean {
  return value !== null &&
    value !== undefined &&
    typeof value === 'object' &&
    !Array.isArray(value);
}

function isNonemptyString(value: JsonValue | undefined): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function snapshotContext(context: ActionPlanRunContext): ContextSnapshotResult {
  if (context === null || typeof context !== 'object') {
    return {
      ok: false,
      value: null,
      errorCode: 'ACTION_PLAN_CONTEXT_INVALID',
      message: 'Action plan execution identity is malformed.'
    };
  }
  const keys = Object.keys(context);
  const required = ['conversationId', 'turnId', 'surfaceId', 'sourceToolId', 'planId', 'runId'];
  for (let index = 0; index < required.length; index++) {
    if (keys.indexOf(required[index]) < 0) {
      return {
        ok: false,
        value: null,
        errorCode: 'ACTION_PLAN_CONTEXT_INVALID',
        message: 'Action plan execution identity is malformed.'
      };
    }
  }
  const record =
    context as Object as Record<string, JsonValue | undefined>;
  if (!isNonemptyString(record['conversationId']) ||
    !isNonemptyString(record['turnId']) ||
    !isNonemptyString(record['surfaceId']) ||
    !isNonemptyString(record['sourceToolId']) ||
    !isNonemptyString(record['planId']) ||
    !isNonemptyString(record['runId'])) {
    return {
      ok: false,
      value: null,
      errorCode: 'ACTION_PLAN_CONTEXT_INVALID',
      message: 'Action plan execution identity is malformed.'
    };
  }
  return {
    ok: true,
    value: {
      conversationId: record['conversationId'] as string,
      turnId: record['turnId'] as string,
      surfaceId: record['surfaceId'] as string,
      sourceToolId: record['sourceToolId'] as string,
      planId: record['planId'] as string,
      runId: record['runId'] as string
    },
    errorCode: '',
    message: ''
  };
}

function inspectForbiddenFields(
  value: JsonValue | undefined,
  active: Set<Object>
): ForbiddenFieldResult {
  if (value === null || value === undefined || typeof value !== 'object') {
    return {
      ok: true,
      field: ''
    };
  }
  const objectValue = value as Object;
  if (active.has(objectValue)) {
    return {
      ok: false,
      field: 'cycle'
    };
  }
  active.add(objectValue);
  const keys = Object.keys(objectValue);
  const record = objectValue as Record<string, JsonValue | undefined>;
  for (let index = 0; index < keys.length; index++) {
    const key = keys[index];
    if (FORBIDDEN_FIELDS.indexOf(key) >= 0) {
      active.delete(objectValue);
      return {
        ok: false,
        field: key
      };
    }
    const nested = inspectForbiddenFields(record[key], active);
    if (!nested.ok) {
      active.delete(objectValue);
      return nested;
    }
  }
  active.delete(objectValue);
  return {
    ok: true,
    field: ''
  };
}

function bindingSourceIsEarlier(
  steps: ActionPlanStep[],
  currentIndex: number,
  sourceStepId: string
): boolean {
  for (let index = 0; index < currentIndex; index++) {
    if (steps[index].stepId === sourceStepId) {
      return true;
    }
  }
  return false;
}

function completedOutput(completed: CompletedStep[], stepId: string): JsonValue | undefined {
  for (let index = 0; index < completed.length; index++) {
    if (completed[index].stepId === stepId) {
      return completed[index].output;
    }
  }
  return undefined;
}

function executionContext(
  context: ActionPlanRunContext,
  stepId: string,
  stepIndex: number
): ActionExecutionContext {
  return {
    conversationId: context.conversationId,
    turnId: context.turnId,
    surfaceId: context.surfaceId,
    sourceToolId: context.sourceToolId,
    planId: context.planId,
    runId: context.runId,
    stepId: stepId,
    isSurfaceEntry: stepIndex === 0
  };
}

export class ActionPlanRunner {
  private catalog: ActionCatalog;
  private executor: ActionStepExecutor;

  constructor(catalog: ActionCatalog, executor: ActionStepExecutor) {
    this.catalog = catalog;
    this.executor = executor;
  }

  validate(plan: ActionPlan, context: ActionPlanRunContext): ActionPlanValidationResult {
    const contextResult = snapshotContext(context);
    if (!contextResult.ok || contextResult.value === null) {
      return validationFailure('', contextResult.errorCode, contextResult.message);
    }
    return this.validateSnapshot(plan, contextResult.value, true);
  }

  validateDraft(draft: ActionPlanDraft, sourceToolId: string): ActionPlanValidationResult {
    const plan: ActionPlan = {
      planId: draft.planId,
      turnId: 'draft',
      surfaceId: 'draft',
      label: draft.label,
      steps: draft.steps
    };
    const context: ActionPlanRunContext = {
      conversationId: 'draft',
      turnId: plan.turnId,
      surfaceId: plan.surfaceId,
      sourceToolId,
      planId: plan.planId,
      runId: draft.runId
    };
    return this.validateSnapshot(plan, context, false);
  }

  private validateSnapshot(
    plan: ActionPlan,
    context: ActionPlanRunContext,
    requireSurface: boolean
  ): ActionPlanValidationResult {
    try {
      const inspection = inspectJsonValue(plan as Object);
      if (!inspection.ok) {
        return validationFailure('', inspection.errorCode, inspection.message);
      }
      const forbidden = inspectForbiddenFields(plan as Object, new Set<Object>());
      if (!forbidden.ok) {
        return validationFailure(
          '',
          'ACTION_PLAN_FORBIDDEN_FIELD',
          'Action plans cannot contain executable control fields.'
        );
      }
      if (plan === null ||
        typeof plan !== 'object' ||
        !isNonemptyString(plan.planId) ||
        !isNonemptyString(plan.turnId) ||
        !isNonemptyString(plan.surfaceId) ||
        !isNonemptyString(plan.label) ||
        plan.planId !== context.planId ||
        plan.turnId !== context.turnId ||
        plan.surfaceId !== context.surfaceId) {
        return validationFailure('', 'ACTION_PLAN_MALFORMED', 'Action plan metadata is malformed.');
      }
      if (!Array.isArray(plan.steps) || plan.steps.length < 1 || plan.steps.length > MAX_ACTION_PLAN_STEPS) {
        return validationFailure(
          '',
          'ACTION_PLAN_STEP_COUNT',
          'Action plans require one to five serial steps.'
        );
      }
      const stepIds: string[] = [];
      for (let index = 0; index < plan.steps.length; index++) {
        const step = plan.steps[index];
        if (step === null || typeof step !== 'object') {
          return validationFailure('', 'ACTION_PLAN_STEP_MALFORMED', 'Action plan step is malformed.');
        }
        if (!isNonemptyString(step.stepId)) {
          return validationFailure('', 'ACTION_PLAN_STEP_ID', 'Action plan stepId must be nonempty.');
        }
        if (stepIds.indexOf(step.stepId) >= 0) {
          return validationFailure(
            step.stepId,
            'ACTION_PLAN_STEP_ID_DUPLICATE',
            'Action plan stepIds must be unique.'
          );
        }
        stepIds.push(step.stepId);
        if (!isNonemptyString(step.actionId)) {
          return validationFailure(
            step.stepId,
            'ACTION_PLAN_ACTION_ID',
            'Action plan actionId must be nonempty.'
          );
        }
        const args = stepArgs(step);
        if (!isArgsObject(args)) {
          return validationFailure(
            step.stepId,
            'ACTION_ARGS_MALFORMED',
            'Action args must be a non-array object.'
          );
        }
        if (step.inputFrom !== undefined && !Array.isArray(step.inputFrom)) {
          return validationFailure(
            step.stepId,
            'ACTION_PLAN_BINDING_MALFORMED',
            'Action inputFrom must be an array.'
          );
        }
        const bindings: ActionInputBinding[] = step.inputFrom === undefined ? [] : step.inputFrom;
        for (let bindingIndex = 0; bindingIndex < bindings.length; bindingIndex++) {
          const binding = bindings[bindingIndex];
          if (binding === null ||
            typeof binding !== 'object' ||
            typeof binding.target !== 'string' ||
            !isNonemptyString(binding.stepId) ||
            typeof binding.path !== 'string') {
            return validationFailure(
              step.stepId,
              'ACTION_PLAN_BINDING_MALFORMED',
              'Action input binding is malformed.'
            );
          }
          if (!bindingSourceIsEarlier(plan.steps, index, binding.stepId)) {
            return validationFailure(
              step.stepId,
              'ACTION_PLAN_BINDING_SOURCE',
              'Action bindings can reference only existing earlier steps.'
            );
          }
          const sourcePointer = validateJsonPointer(binding.path);
          const targetPointer = validateJsonPointer(binding.target);
          if (!sourcePointer.ok || !targetPointer.ok) {
            return validationFailure(
              step.stepId,
              'JSON_POINTER_INVALID',
              'Action binding contains an invalid JSON Pointer.'
            );
          }
        }
        const catalogResult = this.validatePreflightAction(
          plan,
          context,
          index,
          args,
          requireSurface
        );
        if (!catalogResult.ok) {
          return validationFailure(step.stepId, catalogResult.code, catalogResult.message);
        }
      }
      return validPlan();
    } catch (_error) {
      return validationFailure(
        '',
        'ACTION_PLAN_VALIDATION_FAILED',
        'Action plan validation failed closed.'
      );
    }
  }

  async run(plan: ActionPlan, context: ActionPlanRunContext): Promise<ActionPlanOutcome> {
    return this.runFrom(plan, context, 0, [], '');
  }

  async resume(
    plan: ActionPlan,
    context: ActionPlanRunContext,
    nextStepIndex: number,
    priorOutputs: ActionPlanStepOutput[],
    confirmedStepId: string
  ): Promise<ActionPlanOutcome> {
    return this.runFrom(
      plan,
      context,
      nextStepIndex,
      priorOutputs,
      confirmedStepId
    );
  }

  private async runFrom(
    plan: ActionPlan,
    context: ActionPlanRunContext,
    nextStepIndex: number,
    priorOutputs: ActionPlanStepOutput[],
    confirmedStepId: string
  ): Promise<ActionPlanOutcome> {
    let completed: CompletedStep[] = [];
    try {
      const contextResult = snapshotContext(context);
      if (!contextResult.ok || contextResult.value === null) {
        return errorOutcome('', contextResult.errorCode, contextResult.message, []);
      }
      const contextSnapshot = contextResult.value;
      const snapshotResult = cloneJsonValue(plan as Object);
      if (!snapshotResult.ok || !isArgsObject(snapshotResult.value)) {
        return errorOutcome(
          '',
          snapshotResult.errorCode.length > 0 ?
            snapshotResult.errorCode : 'ACTION_PLAN_MALFORMED',
          snapshotResult.message.length > 0 ?
            snapshotResult.message : 'Action plan is malformed.',
          []
        );
      }
      const snapshot = snapshotResult.value as ActionPlan;
      const preflight = this.validateSnapshot(snapshot, contextSnapshot, true);
      if (!preflight.ok) {
        return errorOutcome(
          preflight.failedStepId,
          preflight.errorCode,
          preflight.message,
          []
        );
      }
      const prior = this.snapshotCompleted(snapshot, nextStepIndex, priorOutputs);
      if (!prior.ok) {
        return errorOutcome(
          '',
          prior.errorCode,
          prior.message,
          []
        );
      }
      completed = prior.completed;
      if (confirmedStepId.length > 0 &&
        (nextStepIndex >= snapshot.steps.length ||
          snapshot.steps[nextStepIndex].stepId !== confirmedStepId)) {
        return errorOutcome(
          nextStepIndex < snapshot.steps.length ?
            snapshot.steps[nextStepIndex].stepId : '',
          'ACTION_CONFIRMATION_MISMATCH',
          'Action confirmation does not match the next step.',
          this.completedStepIds(completed)
        );
      }
      let availableConfirmation = confirmedStepId;
      for (let index = nextStepIndex; index < snapshot.steps.length; index++) {
        const step = snapshot.steps[index];
        const bound = this.bindInputs(step, completed);
        if (!bound.ok || !isArgsObject(bound.value)) {
          return errorOutcome(
            step.stepId,
            bound.errorCode.length > 0 ? bound.errorCode : 'ACTION_ARGS_MALFORMED',
            bound.message.length > 0 ? bound.message : 'Bound action args must be an object.',
            this.completedStepIds(completed)
          );
        }
        const boundArgs = bound.value as Object;
        const currentValidation = this.validateExecutionAction(
          snapshot,
          contextSnapshot,
          index,
          boundArgs
        );
        if (!currentValidation.ok) {
          return errorOutcome(
            step.stepId,
            currentValidation.code,
            currentValidation.message,
            this.completedStepIds(completed)
          );
        }
        if (currentValidation.definition !== null &&
          currentValidation.definition.riskLevel === 'confirm_required' &&
          availableConfirmation !== step.stepId) {
          return pausedOutcome(
            step.stepId,
            'ACTION_CONFIRMATION_REQUIRED',
            'Action requires confirmation before execution.',
            index,
            completed
          );
        }
        if (availableConfirmation === step.stepId) {
          availableConfirmation = '';
        }
        let rawResult: ActionStepExecutionResult;
        try {
          rawResult = await this.executor.execute(
            step.actionId,
            boundArgs,
            executionContext(contextSnapshot, step.stepId, index)
          );
        } catch (_error) {
          return errorOutcome(
            step.stepId,
            'ACTION_EXECUTOR_FAILED',
            'Action executor failed.',
            this.completedStepIds(completed)
          );
        }
        const resultClone = cloneJsonValue(rawResult as Object);
        if (!resultClone.ok || !isArgsObject(resultClone.value)) {
          return errorOutcome(
            step.stepId,
            'ACTION_EXECUTOR_RESULT_INVALID',
            'Action executor returned an invalid result.',
            this.completedStepIds(completed)
          );
        }
        const result = resultClone.value as ActionStepExecutionResult;
        if (result.status !== 'success') {
          if (result.status !== 'paused' &&
            result.status !== 'canceled' &&
            result.status !== 'error') {
            return errorOutcome(
              step.stepId,
              'ACTION_EXECUTOR_RESULT_INVALID',
              'Action executor returned an unknown status.',
              this.completedStepIds(completed)
            );
          }
          if (typeof result.errorCode !== 'string' || typeof result.message !== 'string') {
            return errorOutcome(
              step.stepId,
              'ACTION_EXECUTOR_RESULT_INVALID',
              'Action executor failure details are malformed.',
              this.completedStepIds(completed)
            );
          }
          if (result.status === 'paused') {
            return pausedOutcome(
              step.stepId,
              result.errorCode,
              result.message,
              index,
              completed
            );
          }
          return {
            status: result.status,
            failedStepId: step.stepId,
            errorCode: result.errorCode,
            message: result.message,
            completedStepIds: this.completedStepIds(completed)
          };
        }
        const outputInspection = inspectJsonValue(result.output);
        if (!outputInspection.ok || result.output === undefined) {
          return errorOutcome(
            step.stepId,
            'ACTION_OUTPUT_INVALID',
            'Action executor success output is not JSON-compatible.',
            this.completedStepIds(completed)
          );
        }
        completed.push({
          stepId: step.stepId,
          output: result.output
        });
      }
      const outputs: ActionPlanStepOutput[] = [];
      for (let index = 0; index < completed.length; index++) {
        outputs.push({
          stepId: completed[index].stepId,
          output: completed[index].output
        });
      }
      return {
        status: 'success',
        completedStepIds: this.completedStepIds(completed),
        outputs: outputs
      };
    } catch (_error) {
      return errorOutcome(
        '',
        'ACTION_PLAN_RUNNER_FAILED',
        'Action plan runner failed closed.',
        this.completedStepIds(completed)
      );
    }
  }

  private snapshotCompleted(
    plan: ActionPlan,
    nextStepIndex: number,
    priorOutputs: ActionPlanStepOutput[]
  ): CompletedSnapshotResult {
    if (nextStepIndex < 0 ||
      nextStepIndex > plan.steps.length ||
      nextStepIndex !== Math.floor(nextStepIndex) ||
      !Array.isArray(priorOutputs) ||
      priorOutputs.length !== nextStepIndex) {
      return {
        ok: false,
        completed: [],
        errorCode: 'ACTION_RESUME_STATE_INVALID',
        message: 'Action resume state is malformed.'
      };
    }
    const completed: CompletedStep[] = [];
    for (let index = 0; index < priorOutputs.length; index++) {
      const prior = priorOutputs[index];
      if (prior === null ||
        typeof prior !== 'object' ||
        prior.stepId !== plan.steps[index].stepId) {
        return {
          ok: false,
          completed: [],
          errorCode: 'ACTION_RESUME_STATE_INVALID',
          message: 'Action resume outputs do not match the validated plan.'
        };
      }
      const output = cloneJsonValue(prior.output);
      if (!output.ok || output.value === undefined) {
        return {
          ok: false,
          completed: [],
          errorCode: 'ACTION_RESUME_STATE_INVALID',
          message: 'Action resume output is invalid.'
        };
      }
      completed.push({
        stepId: prior.stepId,
        output: output.value as JsonValue
      });
    }
    return {
      ok: true,
      completed,
      errorCode: '',
      message: ''
    };
  }

  private validatePreflightAction(
    plan: ActionPlan,
    context: ActionPlanRunContext,
    index: number,
    args: Object,
    requireSurface: boolean
  ): ActionCatalogResult {
    const step = plan.steps[index];
    if (index === 0) {
      if (!requireSurface) {
        return this.catalog.validatePlacement(
          context.sourceToolId,
          step.actionId,
          args
        );
      }
      return this.catalog.validateSurfaceExecution(
        context.conversationId,
        context.turnId,
        context.surfaceId,
        context.sourceToolId,
        step.actionId,
        args
      );
    }
    return this.catalog.validateRegisteredAction(step.actionId);
  }

  private validateExecutionAction(
    plan: ActionPlan,
    context: ActionPlanRunContext,
    index: number,
    args: Object
  ): ActionCatalogResult {
    const step = plan.steps[index];
    if (index === 0) {
      return this.catalog.validateSurfaceExecution(
        context.conversationId,
        context.turnId,
        context.surfaceId,
        context.sourceToolId,
        step.actionId,
        args
      );
    }
    return this.catalog.validateRegisteredStep(step.actionId, args);
  }

  private bindInputs(step: ActionPlanStep, completed: CompletedStep[]): JsonPointerSetResult {
    const argsClone = cloneJsonValue(stepArgs(step));
    if (!argsClone.ok) {
      return {
        ok: false,
        value: undefined,
        errorCode: argsClone.errorCode,
        message: argsClone.message
      };
    }
    let bound: JsonValue = argsClone.value as JsonValue;
    const bindings: ActionInputBinding[] = step.inputFrom === undefined ? [] : step.inputFrom;
    for (let index = 0; index < bindings.length; index++) {
      const source = completedOutput(completed, bindings[index].stepId);
      if (source === undefined) {
        return {
          ok: false,
          value: undefined,
          errorCode: 'ACTION_PLAN_BINDING_SOURCE',
          message: 'Action binding source output is unavailable.'
        };
      }
      const selected: JsonPointerResult =
        resolveJsonPointer(source, bindings[index].path);
      if (!selected.ok) {
        return {
          ok: false,
          value: undefined,
          errorCode: selected.errorCode,
          message: selected.message
        };
      }
      const assigned = setJsonPointer(
        bound,
        bindings[index].target,
        selected.value as JsonValue
      );
      if (!assigned.ok) {
        return assigned;
      }
      bound = assigned.value as JsonValue;
    }
    return {
      ok: true,
      value: bound,
      errorCode: '',
      message: ''
    };
  }

  private completedStepIds(completed: CompletedStep[]): string[] {
    const ids: string[] = [];
    for (let index = 0; index < completed.length; index++) {
      ids.push(completed[index].stepId);
    }
    return ids;
  }
}
