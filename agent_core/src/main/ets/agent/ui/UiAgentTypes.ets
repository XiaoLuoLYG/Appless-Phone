import { DataResult } from '../message/DataResult';
import { ActionPlan } from '../action/ActionPlanTypes';

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

export interface UiRenderResult {
  jsonl: string;
  proposals: ActionPlan[];
}

export interface UiTaskRenderer {
  skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult>;
  result(task: CreateUiTaskPayload, data: DataResult, surfaceId: string): Promise<UiRenderResult>;
  error(task: CreateUiTaskPayload, message: string, surfaceId: string): Promise<UiRenderResult>;
  actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult>;
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
