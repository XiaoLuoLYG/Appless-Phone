import { DataResult } from '../message/DataResult';

export interface CreateDataTaskPayload {
  taskId: string;
  skillId: string;
  toolId: string;
  outputSchema: string;
  args: Object;
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
