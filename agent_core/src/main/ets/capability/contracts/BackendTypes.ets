import { ExecutionEventSink } from './ExecutionEvent';
import { ToolCall } from './ToolCall';
import { ToolResult } from './ToolResult';
import { ToolSpec } from './ToolSpec';

export interface ToolHandler {
  execute(call: ToolCall): Promise<ToolResult>;
}

export interface ToolHandlerBinding {
  toolId: string;
  backendId: string;
  handler: ToolHandler;
}

export interface ToolBackend {
  id(): string;
  canExecute(spec: ToolSpec): boolean;
  execute(call: ToolCall, sink: ExecutionEventSink | null): Promise<ToolResult>;
}

export interface BackendResolution {
  ok: boolean;
  backendId: string;
  reason: string;
  backend: ToolBackend | null;
}
