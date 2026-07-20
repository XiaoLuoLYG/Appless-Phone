import { DataResult } from '../message/DataResult';

export interface CreateUiTaskPayload {
  taskId: string;
  intent: string;
  expectedOutputSchema: string;
}

export type UiRenderState = 'skeleton' | 'result' | 'error' | 'action';

export interface UiRenderResultPayload {
  surfaceId: string;
  state: UiRenderState;
}

export interface UiTaskRenderer {
  skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<string>;
  result(task: CreateUiTaskPayload, data: DataResult, surfaceId: string): Promise<string>;
  error(task: CreateUiTaskPayload, message: string, surfaceId: string): Promise<string>;
  actionStatus(payload: Object, surfaceId: string): Promise<string>;
}

export interface UiSurfaceWriter {
  write(turnId: string, surfaceId: string, jsonl: string): Promise<void>;
}
