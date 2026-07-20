import { CreateDataTaskPayload } from '../data/DataAgentTypes';
import { CreateUiTaskPayload } from '../ui/UiAgentTypes';
import {
  ActionExecutionContext,
  ActionPlan,
  ActionPlanRunContext,
  ActionPlanStepOutput,
  JsonValue
} from './ActionPlanTypes';

export interface WorkflowRunArgs {
  planId: string;
  runId: string;
}

export interface ActionPlanCreatePayload {
  runId: string;
  sourceToolId: string;
  plan: ActionPlan;
}

export interface ActionPlanReadyPayload {
  surfaceId: string;
  planId: string;
  runId: string;
  label: string;
  actionId: 'workflow.run';
  args: WorkflowRunArgs;
}

export interface ActionRunPayload {
  surfaceId: string;
  runId: string;
  sourceToolId?: string;
  actionId: string;
  args: Object;
  confirmedStepId?: string;
}

export type ActionProgressStatus = 'running' | 'success';

export interface ActionProgressPayload {
  surfaceId: string;
  planId: string;
  runId: string;
  stepId: string;
  actionId: string;
  status: ActionProgressStatus;
}

export type ActionResultStatus = 'success' | 'paused' | 'canceled' | 'error';

export interface ActionResultPayload {
  surfaceId: string;
  planId: string;
  runId: string;
  status: ActionResultStatus;
  completedStepIds: string[];
  outputs?: ActionPlanStepOutput[];
  stepId?: string;
  errorCode?: string;
  message?: string;
}

export interface ActionFollowUp {
  uiTask: CreateUiTaskPayload;
  dataTask: CreateDataTaskPayload;
}

export interface ActionExecutionSuccessResult {
  status: 'success';
  output: JsonValue;
  followUp?: ActionFollowUp;
}

export interface ActionExecutionCanceledResult {
  status: 'canceled';
  errorCode: string;
  message: string;
}

export interface ActionExecutionErrorResult {
  status: 'error';
  errorCode: string;
  message: string;
}

export type ActionExecutionResult =
  ActionExecutionSuccessResult |
  ActionExecutionCanceledResult |
  ActionExecutionErrorResult;

export interface RegisteredActionExecutor {
  execute(
    actionId: string,
    args: Object,
    context: ActionExecutionContext
  ): Promise<ActionExecutionResult>;
}

export interface PausedActionRun {
  planId: string;
  runId: string;
  stepId: string;
  nextStepIndex: number;
  outputs: ActionPlanStepOutput[];
  plan: ActionPlan;
  context: ActionPlanRunContext;
  followUpPublished: boolean;
}
