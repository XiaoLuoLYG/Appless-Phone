export interface ActionPlanningFunctionDefinition {
  name: string;
  description: string;
  strict: boolean;
  parameters: Object;
}

export interface ActionPlanningFunctionTool {
  type: 'function';
  function: ActionPlanningFunctionDefinition;
}

export interface ActionPlanningModelRequest {
  systemPrompt: string;
  userPrompt: string;
  submitTool: ActionPlanningFunctionTool;
}

export interface ActionPlanningModelResult {
  ok: boolean;
  argumentsJson: string;
  errorCode: string;
  message: string;
}

/**
 * Model-facing boundary for Action Plan compilation.
 *
 * This port deliberately knows nothing about the current proposal protocol.
 * Prompt and Tool Call schema builders provide that protocol through the
 * request, while the model adapter only returns the submitted arguments JSON.
 */
export interface ActionPlanningModel {
  submit(
    request: ActionPlanningModelRequest
  ): Promise<ActionPlanningModelResult>;
}
