import { ToolCall } from '../contracts/ToolCall';

export interface ToolTrace {
  traceId: string;
  callId: string;
  toolId: string;
  toolVersion: string;
  capabilityId: string;
  conversationId: string;
  turnId: string;
  taskId: string;
  surfaceId: string;
  startedAtMs: number;
}

export function createToolTrace(call: ToolCall, capabilityId: string): ToolTrace {
  return {
    traceId: call.traceId,
    callId: call.callId,
    toolId: call.toolId,
    toolVersion: call.toolVersion,
    capabilityId,
    conversationId: call.context.conversationId,
    turnId: call.context.turnId,
    taskId: call.context.taskId,
    surfaceId: call.context.surfaceId,
    startedAtMs: Date.now()
  };
}
