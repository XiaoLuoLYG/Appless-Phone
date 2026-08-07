import { ApprovalRequest } from './ApprovalTypes';
import { PolicyDecisionKind } from './PolicyTypes';
import { ToolResult } from './ToolResult';

export type ExecutionEventKind =
  'queued' |
  'validated' |
  'resolved' |
  'policy_checked' |
  'approval_required' |
  'started' |
  'progress' |
  'completed' |
  'failed' |
  'canceled';

export interface ExecutionEvent {
  kind: ExecutionEventKind;
  traceId: string;
  callId: string;
  capabilityId: string;
  toolId: string;
  toolVersion: string;
  backendId: string;
  timestampMs: number;
  message: string;
  policyDecision?: PolicyDecisionKind;
  approvalRequest?: ApprovalRequest;
  result?: ToolResult;
}

export interface ExecutionEventSink {
  emit(event: ExecutionEvent): void;
}
