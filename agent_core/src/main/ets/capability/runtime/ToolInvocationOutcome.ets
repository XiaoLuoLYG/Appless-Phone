import { ApprovalRequest } from '../contracts/ApprovalTypes';
import { ToolError } from '../contracts/ToolError';
import { ToolResult } from '../contracts/ToolResult';

export type ToolInvocationOutcomeKind = 'result' | 'approval_required' | 'denied';

export interface ToolInvocationOutcome {
  kind: ToolInvocationOutcomeKind;
  result?: ToolResult;
  approvalRequest?: ApprovalRequest;
  error?: ToolError;
}
