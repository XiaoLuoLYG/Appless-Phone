import { AgentMessage, UserInputPayload } from '../message/AgentMessage';

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
  ui: LeaderUiTask;
  data: LeaderDataTask;
}

export interface LeaderPlanner {
  plan(message: AgentMessage, input: InputUserPayload): Promise<LeaderPlan>;
}
