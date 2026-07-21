import { AgentMessage, UserInputPayload } from '../message/AgentMessage';
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

export type LeaderRoundAction = 'execute' | 'answer' | 'clarify' | 'legacy_handoff';

export interface LeaderActionIntent {
  goal: string;
  allowedActionIds: string[];
}

export interface LeaderDecisionDataTask {
  localId: string;
  goal: string;
  allowedToolIds: string[];
  toolId: string;
  input: Object;
  required: boolean;
}

export interface LeaderUiIntent {
  purpose: string;
  preferredDensity: string;
  requiredSections: string[];
}

export interface LeaderDecision {
  personaId: string;
  skillId: string;
  requestedCapabilityIds: string[];
  roundAction: LeaderRoundAction;
  dataTasks: LeaderDecisionDataTask[];
  uiIntent: LeaderUiIntent;
  actionIntent?: LeaderActionIntent;
  answer?: string;
  reasonCode: string;
}

export interface LeaderPlan {
  personaId: string;
  skillId: string;
  roundAction: LeaderRoundAction;
  ui: LeaderUiTask;
  dataTasks: LeaderDataTask[];
  actionIntent?: LeaderActionIntent;
  answer?: string;
  reasonCode: string;
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
  status: string;
}

export interface LeaderPersonaMetadata {
  personaId: string;
  name: string;
  soul: string;
  memory: string;
  previous: boolean;
  activeSkills: LeaderSkillMetadata[];
}

export interface LeaderPlanningContext {
  tools: LeaderToolMetadata[];
  personas: LeaderPersonaMetadata[];
  runtimeOwnedToolIds?: string[];
}

export type LeaderDataTaskInputNormalizer = (
  input: InputUserPayload,
  task: LeaderDecisionDataTask
) => Object;

export type LeaderPlannerResult = LeaderPlan | LeaderDecision;

export interface LeaderPlanner {
  plan(
    message: AgentMessage,
    input: InputUserPayload,
    context: LeaderPlanningContext,
    round?: number
  ): Promise<LeaderPlannerResult>;
}
