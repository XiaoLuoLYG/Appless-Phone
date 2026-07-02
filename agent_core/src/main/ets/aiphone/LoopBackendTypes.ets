import { AgentEvent } from '../agent/AgentEvent';

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
  maxSteps: number;
}

export interface LoopBackendCallbacks {
  onEvent?: (event: AgentEvent) => void;
  onA2uiJsonl?: (line: string) => void;
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
