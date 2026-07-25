import { MultiToolSurfaceComposer } from './MultiToolSurfaceComposer';

export interface AgentToolRunOptions {
  batchSlotId?: string;
  batchComposer?: MultiToolSurfaceComposer | null;
  compositeSurfaceId?: string;
}
