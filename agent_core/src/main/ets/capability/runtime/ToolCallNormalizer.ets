import { ToolCall, cloneToolCall } from '../contracts/ToolCall';

export class ToolCallNormalizer {
  normalize(call: ToolCall): ToolCall {
    const normalized = cloneToolCall(call);
    normalized.toolId = normalized.toolId.trim();
    normalized.toolVersion = normalized.toolVersion.trim().length > 0 ? normalized.toolVersion.trim() : '1.0.0';
    normalized.callId = normalized.callId.trim().length > 0 ? normalized.callId.trim() : this.id('call');
    normalized.traceId = normalized.traceId.trim().length > 0 ? normalized.traceId.trim() : this.id('trace');
    return normalized;
  }

  private id(prefix: string): string {
    return prefix + '-' + Date.now().toString() + '-' + Math.floor(Math.random() * 1000000).toString();
  }
}
