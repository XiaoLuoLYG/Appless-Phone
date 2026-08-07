import { ApprovalGrant, ApprovalIdentity, ApprovalRequest } from '../contracts/ApprovalTypes';
import { ToolCall, cloneToolCall } from '../contracts/ToolCall';
import { ToolSpec } from '../contracts/ToolSpec';
import { ApprovalGrantStore } from './ApprovalGrantStore';
import { ReplayProtector } from './ReplayProtector';
import { sha256Digest } from './ApprovalDigest';

const DEFAULT_APPROVAL_TTL_MS: number = 5 * 60 * 1000;

export function approvalArgsDigest(args: Object): string {
  return sha256Digest(JSON.stringify(args));
}

function identityFor(call: ToolCall): ApprovalIdentity {
  return {
    conversationId: call.context.conversationId,
    turnId: call.context.turnId,
    taskId: call.context.taskId,
    surfaceId: call.context.surfaceId,
    stepId: call.context.stepId
  };
}

function sameIdentity(left: ApprovalIdentity, right: ApprovalIdentity): boolean {
  return left.conversationId === right.conversationId &&
    left.turnId === right.turnId &&
    left.taskId === right.taskId &&
    left.surfaceId === right.surfaceId &&
    left.stepId === right.stepId;
}

export interface ApprovalValidationResult {
  ok: boolean;
  code: string;
  message: string;
}

export class ApprovalBroker {
  private readonly requests: Map<string, ApprovalRequest> = new Map<string, ApprovalRequest>();
  private readonly pendingCalls: Map<string, ToolCall> = new Map<string, ToolCall>();
  private readonly grants: ApprovalGrantStore = new ApprovalGrantStore();
  private readonly replay: ReplayProtector = new ReplayProtector();
  private sequence: number = 0;

  request(call: ToolCall, spec: ToolSpec, nowMs: number = Date.now()): ApprovalRequest {
    this.sequence++;
    const requestId = 'approval-' + nowMs.toString() + '-' + this.sequence.toString();
    const request: ApprovalRequest = {
      requestId,
      callId: call.callId,
      toolId: spec.id,
      toolVersion: spec.version,
      argsDigest: approvalArgsDigest(call.args),
      identity: identityFor(call),
      effects: spec.declaredEffects.map((effect): string => effect.kind),
      createdAtMs: nowMs,
      expiresAtMs: nowMs + DEFAULT_APPROVAL_TTL_MS
    };
    this.requests.set(requestId, JSON.parse(JSON.stringify(request)) as ApprovalRequest);
    this.pendingCalls.set(requestId, cloneToolCall(call));
    return JSON.parse(JSON.stringify(request)) as ApprovalRequest;
  }

  issueGrant(requestId: string, nowMs: number = Date.now()): ApprovalGrant | null {
    const request = this.requests.get(requestId);
    if (request === undefined || nowMs > request.expiresAtMs) {
      return null;
    }
    const grant: ApprovalGrant = {
      requestId: request.requestId,
      callId: request.callId,
      toolId: request.toolId,
      toolVersion: request.toolVersion,
      argsDigest: request.argsDigest,
      identity: JSON.parse(JSON.stringify(request.identity)) as ApprovalIdentity,
      approvedAtMs: nowMs
    };
    this.grants.put(grant);
    return JSON.parse(JSON.stringify(grant)) as ApprovalGrant;
  }

  pendingCall(requestId: string): ToolCall | null {
    const call = this.pendingCalls.get(requestId);
    return call === undefined ? null : cloneToolCall(call);
  }

  validateAndConsume(call: ToolCall, grant: ApprovalGrant, nowMs: number = Date.now()): ApprovalValidationResult {
    const request = this.requests.get(grant.requestId);
    const storedGrant = this.grants.find(grant.requestId);
    if (request === undefined || storedGrant === null) {
      return { ok: false, code: 'APPROVAL_UNKNOWN', message: 'Approval request is not current.' };
    }
    if (nowMs > request.expiresAtMs) {
      return { ok: false, code: 'APPROVAL_EXPIRED', message: 'Approval request has expired.' };
    }
    const matches = grant.callId === call.callId && grant.callId === request.callId &&
      grant.toolId === call.toolId && grant.toolId === request.toolId &&
      grant.toolVersion === call.toolVersion && grant.toolVersion === request.toolVersion &&
      grant.argsDigest === approvalArgsDigest(call.args) && grant.argsDigest === request.argsDigest &&
      sameIdentity(grant.identity, identityFor(call)) && sameIdentity(grant.identity, request.identity);
    if (!matches) {
      return { ok: false, code: 'APPROVAL_MISMATCH', message: 'Approval does not match the exact tool call.' };
    }
    const replayIdentity = grant.requestId + ':' + grant.callId + ':' + grant.argsDigest;
    if (!this.replay.claim(replayIdentity) || !this.grants.consume(grant.requestId)) {
      return { ok: false, code: 'APPROVAL_REPLAYED', message: 'Approval was already consumed.' };
    }
    this.pendingCalls.delete(grant.requestId);
    return { ok: true, code: '', message: '' };
  }
}
