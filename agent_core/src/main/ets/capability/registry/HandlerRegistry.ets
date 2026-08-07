import { ToolHandler, ToolHandlerBinding } from '../contracts/BackendTypes';

function handlerKey(toolId: string, backendId: string): string {
  return toolId + '@' + backendId;
}

export class HandlerRegistry {
  private readonly handlers: Map<string, ToolHandler> = new Map<string, ToolHandler>();

  register(binding: ToolHandlerBinding): void {
    const key = handlerKey(binding.toolId, binding.backendId);
    if (this.handlers.has(key)) {
      throw new Error('Duplicate capability handler: ' + key);
    }
    this.handlers.set(key, binding.handler);
  }

  find(toolId: string, backendId: string): ToolHandler | null {
    return this.handlers.get(handlerKey(toolId, backendId)) ?? null;
  }

  has(toolId: string, backendId: string): boolean {
    return this.handlers.has(handlerKey(toolId, backendId));
  }
}
