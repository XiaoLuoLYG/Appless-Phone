import { DataResult } from '../message/DataResult';

export interface CreateUiTaskPayload {
  taskId: string;
  dataTaskId: string;
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

export interface UiSurfaceWriteLease {
  isActive(): boolean;
}

export interface UiSurfaceWriter {
  // Implementations must check the lease immediately before mutating the surface,
  // after completing any internal asynchronous work.
  write(
    turnId: string,
    surfaceId: string,
    jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void>;
}
