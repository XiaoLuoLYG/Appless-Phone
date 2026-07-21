import { DataResult } from '../message/DataResult';
import { ObservationDigest } from '../message/AgentMessage';

export interface CreateDataTaskPayload {
  taskId: string;
  roundId: string;
  skillId: string;
  goal: string;
  allowedToolIds: string[];
  toolId: string;
  outputSchema: string;
  args: Object;
  required: boolean;
}

export interface DataTaskAuthorizationResult {
  ok: boolean;
  code: string;
  message: string;
}

export type DataTaskAuthorizer = (
  task: CreateDataTaskPayload
) => DataTaskAuthorizationResult;

export interface DataTaskExecutor {
  execute(task: CreateDataTaskPayload): Promise<DataResult>;
}

export type DataStepKind = 'call' | 'finish';

export interface DataStepDecision {
  kind: DataStepKind;
  toolId: string;
  args: Object;
  summary: string;
}

export interface DataTaskPlanner {
  next(
    task: CreateDataTaskPayload,
    observations: ObservationDigest[],
    step: number
  ): Promise<DataStepDecision>;
}
