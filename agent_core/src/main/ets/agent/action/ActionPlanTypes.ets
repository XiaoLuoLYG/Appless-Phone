export type JsonValue = Object | string | number | boolean | null;

export interface ActionInputBinding {
  target: string;
  stepId: string;
  path: string;
}

export interface ActionPlanStep {
  stepId: string;
  actionId: string;
  args?: Object;
  inputFrom?: ActionInputBinding[];
}

export interface ActionPlan {
  planId: string;
  turnId: string;
  surfaceId: string;
  label: string;
  steps: ActionPlanStep[];
}

export interface ActionPlanRunContext {
  conversationId: string;
  turnId: string;
  surfaceId: string;
  sourceToolId: string;
  planId: string;
  runId: string;
}

export interface ActionExecutionContext {
  conversationId: string;
  turnId: string;
  surfaceId: string;
  sourceToolId: string;
  planId: string;
  runId: string;
  stepId: string;
  /** True when this is the first action placed directly on the current surface. */
  isSurfaceEntry?: boolean;
}

export interface ActionStepSuccessResult {
  status: 'success';
  output: JsonValue;
}

export interface ActionStepPausedResult {
  status: 'paused';
  errorCode: string;
  message: string;
}

export interface ActionStepCanceledResult {
  status: 'canceled';
  errorCode: string;
  message: string;
}

export interface ActionStepErrorResult {
  status: 'error';
  errorCode: string;
  message: string;
}

export type ActionStepExecutionResult =
  ActionStepSuccessResult |
  ActionStepPausedResult |
  ActionStepCanceledResult |
  ActionStepErrorResult;

export interface ActionStepExecutor {
  execute(
    actionId: string,
    args: Object,
    context: ActionExecutionContext
  ): Promise<ActionStepExecutionResult>;
}

export interface ActionPlanStepOutput {
  stepId: string;
  output: JsonValue;
}

interface ActionPlanOutcomeBase {
  completedStepIds: string[];
  failedStepId?: string;
  errorCode?: string;
  message?: string;
}

export interface ActionPlanSuccessOutcome extends ActionPlanOutcomeBase {
  status: 'success';
  outputs: ActionPlanStepOutput[];
}

export interface ActionPlanPausedOutcome extends ActionPlanOutcomeBase {
  status: 'paused';
  failedStepId: string;
  errorCode: string;
  message: string;
  nextStepIndex: number;
  outputs: ActionPlanStepOutput[];
}

export interface ActionPlanCanceledOutcome extends ActionPlanOutcomeBase {
  status: 'canceled';
  failedStepId: string;
  errorCode: string;
  message: string;
}

export interface ActionPlanErrorOutcome extends ActionPlanOutcomeBase {
  status: 'error';
  failedStepId: string;
  errorCode: string;
  message: string;
}

export type ActionPlanOutcome =
  ActionPlanSuccessOutcome |
  ActionPlanPausedOutcome |
  ActionPlanCanceledOutcome |
  ActionPlanErrorOutcome;

export interface ActionPlanValidationResult {
  ok: boolean;
  failedStepId: string;
  errorCode: string;
  message: string;
}
