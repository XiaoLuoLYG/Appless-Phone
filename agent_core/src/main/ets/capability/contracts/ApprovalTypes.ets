export interface ApprovalIdentity {
  conversationId: string;
  turnId: string;
  taskId: string;
  surfaceId: string;
  stepId: string;
}

export interface ApprovalRequest {
  requestId: string;
  callId: string;
  toolId: string;
  toolVersion: string;
  argsDigest: string;
  identity: ApprovalIdentity;
  effects: string[];
  createdAtMs: number;
  expiresAtMs: number;
}

export interface ApprovalGrant {
  requestId: string;
  callId: string;
  toolId: string;
  toolVersion: string;
  argsDigest: string;
  identity: ApprovalIdentity;
  approvedAtMs: number;
}
