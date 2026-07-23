import { DataResult } from '../message/DataResult';
import { ActionOffer } from '../action/ActionOfferTypes';

export interface CreateUiTaskPayload {
  taskId: string;
  dataTaskIds: string[];
  personaId?: string;
  skillId: string;
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
}

export interface UiTaskRenderer {
  skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult>;
  result(
    task: CreateUiTaskPayload,
    data: DataResult[],
    offers: ActionOffer[],
    surfaceId: string
  ): Promise<UiRenderResult>;
  error(task: CreateUiTaskPayload, message: string, surfaceId: string): Promise<UiRenderResult>;
  actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult>;
}

export interface SingleDataUiTaskRenderer {
  skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult>;
  result(
    task: CreateUiTaskPayload,
    data: DataResult,
    offers: ActionOffer[],
    surfaceId: string
  ): Promise<UiRenderResult>;
  error(task: CreateUiTaskPayload, message: string, surfaceId: string): Promise<UiRenderResult>;
  actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult>;
}

export class SingleDataUiTaskRendererAdapter implements UiTaskRenderer {
  private readonly renderer: SingleDataUiTaskRenderer;

  constructor(renderer: SingleDataUiTaskRenderer) {
    this.renderer = renderer;
  }

  skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult> {
    return this.renderer.skeleton(task, surfaceId);
  }

  result(
    task: CreateUiTaskPayload,
    data: DataResult[],
    offers: ActionOffer[],
    surfaceId: string
  ): Promise<UiRenderResult> {
    if (data.length !== 1) {
      return Promise.reject(new Error('Single-data renderer requires exactly one result'));
    }
    return this.renderer.result(task, data[0], offers, surfaceId);
  }

  error(task: CreateUiTaskPayload, message: string, surfaceId: string): Promise<UiRenderResult> {
    return this.renderer.error(task, message, surfaceId);
  }

  actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult> {
    return this.renderer.actionStatus(payload, surfaceId);
  }
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
