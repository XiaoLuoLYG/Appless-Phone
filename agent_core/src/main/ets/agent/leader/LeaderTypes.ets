import { AgentMessage, UserInputPayload } from '../message/AgentMessage';
import { ActionPlanDraft } from '../action/ActionPlanTypes';
import { ToolRiskLevel } from '../../aiphone/runtime/ToolDefinitionTypes';

export type InputUserPayload = UserInputPayload;

export interface LeaderUiTask {
  taskId: string;
  intent: string;
  expectedOutputSchema: string;
}

export interface LeaderDataTask {
  taskId: string;
  toolId: string;
  outputSchema: string;
  args: Object;
}

export interface LeaderPlan {
  skillId: string;
  ui: LeaderUiTask;
  data: LeaderDataTask;
  actionPlan?: ActionPlanDraft;
}

export interface LeaderToolMetadata {
  toolId: string;
  intent: string;
  riskLevel: ToolRiskLevel;
  inputSchema: string;
  outputSchema: string;
  actions: string[];
}

export interface LeaderSkillMetadata {
  skillId: string;
  description: string;
  instructions: string;
}

export interface LeaderPlanningContext {
  tools: LeaderToolMetadata[];
  skills: LeaderSkillMetadata[];
}

export interface LeaderPlanner {
  plan(
    message: AgentMessage,
    input: InputUserPayload,
    context: LeaderPlanningContext
  ): Promise<LeaderPlan>;
}
