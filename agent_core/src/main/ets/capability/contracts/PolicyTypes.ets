import { ApprovalRequest } from './ApprovalTypes';

export type PolicyDecisionKind = 'allow' | 'deny' | 'approval_required';

export interface PolicyDecision {
  kind: PolicyDecisionKind;
  code: string;
  message: string;
  approvalRequest?: ApprovalRequest;
}
