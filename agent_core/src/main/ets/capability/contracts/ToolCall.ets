import { ApprovalGrant } from './ApprovalTypes';

export interface ToolContext {
  conversationId: string;
  turnId: string;
  taskId: string;
  agentId: string;
  surfaceId: string;
  stepId: string;
  inputText: string;
  deadlineAtMs: number;
}

export interface ToolCall {
  traceId: string;
  callId: string;
  toolId: string;
  toolVersion: string;
  args: Object;
  context: ToolContext;
  approvalGrant?: ApprovalGrant;
}

export function cloneToolCall(call: ToolCall): ToolCall {
  const copy: ToolCall = {
    traceId: call.traceId,
    callId: call.callId,
    toolId: call.toolId,
    toolVersion: call.toolVersion,
    args: JSON.parse(JSON.stringify(call.args)) as Object,
    context: {
      conversationId: call.context.conversationId,
      turnId: call.context.turnId,
      taskId: call.context.taskId,
      agentId: call.context.agentId,
      surfaceId: call.context.surfaceId,
      stepId: call.context.stepId,
      inputText: call.context.inputText,
      deadlineAtMs: call.context.deadlineAtMs
    }
  };
  if (call.approvalGrant !== undefined) {
    copy.approvalGrant = JSON.parse(JSON.stringify(call.approvalGrant)) as ApprovalGrant;
  }
  return copy;
}
