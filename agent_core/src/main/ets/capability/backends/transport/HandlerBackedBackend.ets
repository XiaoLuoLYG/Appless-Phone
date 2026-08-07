import { ExecutionEventSink } from '../../contracts/ExecutionEvent';
import { ToolBackend, ToolHandler } from '../../contracts/BackendTypes';
import { ToolCall } from '../../contracts/ToolCall';
import { ToolResult } from '../../contracts/ToolResult';
import { ToolSpec } from '../../contracts/ToolSpec';
import { HandlerRegistry } from '../../registry/HandlerRegistry';

export class HandlerBackedBackend implements ToolBackend {
  private readonly backendId: string;
  private readonly handlers: HandlerRegistry;

  constructor(backendId: string, handlers: HandlerRegistry) {
    this.backendId = backendId;
    this.handlers = handlers;
  }

  id(): string {
    return this.backendId;
  }

  canExecute(spec: ToolSpec): boolean {
    return this.handlers.has(spec.id, this.backendId);
  }

  async execute(call: ToolCall, _sink: ExecutionEventSink | null): Promise<ToolResult> {
    const handler: ToolHandler | null = this.handlers.find(call.toolId, this.backendId);
    if (handler === null) throw new Error('No handler binding for ' + call.toolId + '@' + this.backendId + '.');
    return handler.execute(call);
  }
}
