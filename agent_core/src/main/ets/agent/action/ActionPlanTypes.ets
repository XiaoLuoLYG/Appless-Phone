import { ActionOffer } from './ActionOfferTypes';
import { ActionJsonSchema } from './schema/ActionJsonSchema';

export type JsonValue = Object | string | number | boolean | null;

export interface ActionInputBinding {
  target: string;
  stepId: string;
  path: string;
}

export interface ActionPlanStep {
  stepId: string;
  actionId: string;
  offerId: string | null;
  args: Object;
  inputFrom: ActionInputBinding[];
}

export interface FrozenActionSchemaSnapshot {
  schemaId: string;
  revision: string;
  fingerprint: string;
  schema: ActionJsonSchema;
}

export interface FrozenActionDefinitionSnapshot {
  definitionFingerprint: string;
  input: FrozenActionSchemaSnapshot;
  output: FrozenActionSchemaSnapshot;
}

export interface FrozenOfferAuthority {
  kind: 'offer';
  offerId: string;
  dataTaskId: string;
  sourceToolId: string;
}

export interface FrozenDerivedAuthority {
  kind: 'derived';
  actionTaskId: string;
  allowedActionId: string;
}

export interface FrozenVirtualIntentAuthority {
  kind: 'virtual_intent';
  actionTaskId: string;
  /** Exact resolver-owned Offer used by the first frozen virtual step. */
  offerId?: string;
}

export interface FrozenSurfaceAuthority {
  kind: 'surface';
  surfaceId: string;
  pageActionId: string;
}

export type FrozenActionAuthority =
  FrozenOfferAuthority |
  FrozenDerivedAuthority |
  FrozenVirtualIntentAuthority |
  FrozenSurfaceAuthority;

export interface FrozenActionPlanStep extends ActionPlanStep {
  /** Legacy catalog fingerprint retained for PR #15 compatibility. */
  definitionFingerprint: string;
  /** Present when the schema-aware registry is connected at freeze time. */
  definition?: FrozenActionDefinitionSnapshot;
  /** Deterministic record of why this step was authorized. */
  authority?: FrozenActionAuthority;
}

export interface ActionPlanDraft {
  planId: string;
  runId: string;
  label: string;
  steps: ActionPlanStep[];
}

export interface ActionPlanCompileOptions {
  /**
   * Resolver-owned entry Offer. When present, the model compiles only the
   * remaining steps and the compiler prepends this immutable entry.
   */
  preboundEntryOfferId?: string;
}

export interface ActionPlanCompiler {
  compile(
    goal: string,
    offers: ActionOffer[],
    allowedActionIds: string[],
    options?: ActionPlanCompileOptions
  ): Promise<ActionPlanDraft>;
}

export interface ActionPlan {
  conversationId: string;
  taskId: string;
  planId: string;
  turnId: string;
  surfaceId: string;
  label: string;
  steps: FrozenActionPlanStep[];
}

export interface ActionPlanRunContext {
  conversationId: string;
  turnId: string;
  taskId: string;
  surfaceId: string;
  sourceToolId: string;
  planId: string;
  runId: string;
  /** Internal authority for a page action resolved from the rendered snapshot. */
  pageActionId?: string;
  /** Internal authority for a zero-Data actionIntent resolved by the runtime. */
  virtualAction?: boolean;
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
  /** Original immutable page operation, distinct from an adapted registered target. */
  pageActionId?: string;
  /** True only for an internally resolved zero-Data actionIntent. */
  virtualAction?: boolean;
}

export interface ActionStepSuccessResult {
  status: 'success';
  output: JsonValue;
  /** Kept internal until the validated success is committed. */
  followUp?: Object;
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

export interface ActionStepCommitResult {
  ok: boolean;
  errorCode: string;
  message: string;
}

export interface ActionStepExecutionObserver {
  commitValidatedSuccess(
    actionId: string,
    output: JsonValue,
    context: ActionExecutionContext,
    followUp?: Object
  ): ActionStepCommitResult;
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
