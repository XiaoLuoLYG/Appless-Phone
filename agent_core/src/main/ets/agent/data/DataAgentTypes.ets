import { DataResult } from '../message/DataResult';

export interface CreateDataTaskPayload {
  taskId: string;
  toolId: string;
  outputSchema: string;
  args: Object;
}

export interface DataTaskExecutor {
  execute(task: CreateDataTaskPayload): Promise<DataResult>;
}
