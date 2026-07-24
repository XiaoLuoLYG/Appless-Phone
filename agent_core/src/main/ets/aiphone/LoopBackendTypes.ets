import { AgentEvent } from '../agent/AgentEvent';
import { MultiToolSurfaceComposer } from '../agent/MultiToolSurfaceComposer';
import { LoopBatchExecution } from '../agent/MultiToolTypes';
import { A2uiSurfaceState } from './runtime/A2uiTypes';

export interface LoopModelSettings {
  provider: string;
  baseUrl: string;
  apiKey: string;
  model: string;
  customParametersJson: string;
}

export interface LoopMessage {
  role: 'user' | 'assistant';
  content: string;
}

export interface LoopBackendRequest {
  prompt: string;
  userPrompt?: string;
  history: LoopMessage[];
  modelSettings: LoopModelSettings;
  surfaceId: string;
  actionId: string;
  args?: Object;
  persona?: Object;
  ignoreToolSurfaceUpdates?: boolean;
  maxSteps: number;
  batchExecution?: LoopBatchExecution | null;
  batchComposer?: MultiToolSurfaceComposer | null;
}

export interface LoopBackendCallbacks {
  onEvent?: (event: AgentEvent) => void;
  onA2uiJsonl?: (line: string) => void;
  onA2uiSurface?: (surface: A2uiSurfaceState, raw: string) => void;
}

export interface LoopToolTrace {
  toolId: string;
  input: string;
  observation: string;
}

export interface LoopRunResult {
  ok: boolean;
  finalAnswer: string;
  error: string;
  toolCalls: LoopToolTrace[];
  raw: string;
}
