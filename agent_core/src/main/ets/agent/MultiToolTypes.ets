import { A2uiSurfaceState } from '../aiphone/runtime/A2uiTypes';

export type MultiToolSlotStatus = 'queued' | 'running' | 'ready' | 'error';

export interface MultiToolSectionMeta {
  slotId: string;
  toolId: string;
  title: string;
  status: MultiToolSlotStatus;
  summary: string;
}

export interface MultiTaskBoardData {
  batchId: string;
  activeSectionId: string;
  sections: MultiToolSectionMeta[];
}

export interface MultiToolSectionContent {
  slotId: string;
  toolId: string;
  title: string;
  status: MultiToolSlotStatus;
  summary: string;
  observationDigest: string;
  failureKey: string;
  embeddedSurface: A2uiSurfaceState | null;
}

export interface MultiToolSlotCall {
  name: string;
  input: string;
}

export interface MultiToolSectionValue {
  slotId: string;
  toolId: string;
  title: string;
  status: MultiToolSlotStatus;
  summary: string;
  observationDigest: string;
  failureKey: string;
  embeddedSurface: A2uiSurfaceState | null;
}

export interface LoopBatchExecution {
  activeSlotId: string;
  compositeSurfaceId: string;
}
