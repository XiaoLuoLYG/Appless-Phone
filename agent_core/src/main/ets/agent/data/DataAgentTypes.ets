import { DataResult } from '../message/DataResult';

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
