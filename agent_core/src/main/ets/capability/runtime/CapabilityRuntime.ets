import { ApprovalBroker } from '../policy/ApprovalBroker';
import { ApprovalGrant, ApprovalRequest } from '../contracts/ApprovalTypes';
import { BackendResolution } from '../contracts/BackendTypes';
import { ExecutionEvent, ExecutionEventKind, ExecutionEventSink } from '../contracts/ExecutionEvent';
import { PolicyDecisionKind } from '../contracts/PolicyTypes';
import { ToolCall } from '../contracts/ToolCall';
import { toolError, ToolError } from '../contracts/ToolError';
import { ToolResult } from '../contracts/ToolResult';
import { ToolSpec } from '../contracts/ToolSpec';
import { CapabilityPolicyEngine } from '../policy/CapabilityPolicyEngine';
import { EffectAnalyzer } from '../policy/EffectAnalyzer';
import { CapabilityRegistry } from '../registry/CapabilityRegistry';
import { ToolCallNormalizer } from './ToolCallNormalizer';
import { ToolCancellationManager } from './ToolCancellationManager';
import { ToolConcurrencyController } from './ToolConcurrencyController';
import { ToolExecutor } from './ToolExecutor';
import { ToolInvocationOutcome } from './ToolInvocationOutcome';
import { ToolResolver } from './ToolResolver';
import { ToolResultValidator } from './ToolResultValidator';

class CompositeExecutionEventSink implements ExecutionEventSink {
  private readonly first: ExecutionEventSink;
  private readonly second: ExecutionEventSink;

  constructor(first: ExecutionEventSink, second: ExecutionEventSink) {
    this.first = first;
    this.second = second;
  }

  emit(event: ExecutionEvent): void {
    this.first.emit(event);
    this.second.emit(event);
  }
}

export class CapabilityRuntime {
  private readonly registry: CapabilityRegistry;
  private readonly resolver: ToolResolver;
  private readonly policy: CapabilityPolicyEngine;
  private readonly approvals: ApprovalBroker;
  private readonly defaultSink: ExecutionEventSink | null;
  private readonly normalizer: ToolCallNormalizer = new ToolCallNormalizer();
  private readonly analyzer: EffectAnalyzer = new EffectAnalyzer();
  private readonly executor: ToolExecutor = new ToolExecutor();
  private readonly cancellation: ToolCancellationManager = new ToolCancellationManager();
  private readonly concurrency: ToolConcurrencyController = new ToolConcurrencyController();
  private readonly resultValidator: ToolResultValidator;

  constructor(
    registry: CapabilityRegistry,
    resolver: ToolResolver,
    policy: CapabilityPolicyEngine,
    approvals: ApprovalBroker,
    defaultSink: ExecutionEventSink | null = null
  ) {
    this.registry = registry;
    this.resolver = resolver;
    this.policy = policy;
    this.approvals = approvals;
    this.defaultSink = defaultSink;
    this.resultValidator = new ToolResultValidator(registry.schemas);
  }

  async invoke(call: ToolCall, sink: ExecutionEventSink | null = null): Promise<ToolInvocationOutcome> {
    const normalized = this.normalizer.normalize(call);
    const spec = this.registry.findTool(normalized.toolId);
    if (spec === null) {
      return this.deny(toolError('TOOL_NOT_REGISTERED', 'Tool is not registered: ' + normalized.toolId), normalized, null, sink);
    }
    this.emit('queued', normalized, spec, '', 'Tool invocation queued.', sink);
    if (normalized.toolVersion !== spec.version) {
      return this.deny(toolError('TOOL_VERSION_MISMATCH', 'Requested tool version is not registered.'), normalized, spec, sink);
    }
    if (normalized.context.deadlineAtMs > 0 && Date.now() > normalized.context.deadlineAtMs) {
      return this.deny(toolError('TOOL_DEADLINE_EXCEEDED', 'Tool call deadline has expired.'), normalized, spec, sink);
    }
    const input = this.registry.schemas.validate(spec.inputSchemaRef, normalized.args);
    if (!input.ok) {
      return this.deny(toolError(input.code, input.message), normalized, spec, sink);
    }
    this.emit('validated', normalized, spec, '', 'Tool call validated.', sink);

    if (normalized.approvalGrant !== undefined) {
      const approval = this.approvals.validateAndConsume(normalized, normalized.approvalGrant);
      if (!approval.ok) {
        return this.deny(toolError(approval.code, approval.message), normalized, spec, sink);
      }
    }
    const effects = this.analyzer.analyze(normalized, spec);
    const decision = this.policy.evaluate(normalized, spec, effects);
    this.emit('policy_checked', normalized, spec, '', decision.message, sink, decision.kind);
    if (decision.kind === 'deny') {
      return this.deny(toolError(decision.code, decision.message), normalized, spec, sink);
    }
    if (decision.kind === 'approval_required' && decision.approvalRequest !== undefined) {
      this.emit('approval_required', normalized, spec, '', decision.message, sink,
        decision.kind, decision.approvalRequest);
      return { kind: 'approval_required', approvalRequest: decision.approvalRequest };
    }

    const resolution = this.resolver.resolve(spec);
    if (!resolution.ok || resolution.backend === null) {
      return this.deny(toolError('BACKEND_UNAVAILABLE', resolution.reason, true), normalized, spec, sink);
    }
    this.emit('resolved', normalized, spec, resolution.backendId, 'Backend resolved.', sink);
    if (this.cancellation.isCanceled(normalized.callId)) {
      this.cancellation.clear(normalized.callId);
      return this.deny(toolError('TOOL_CANCELED', 'Tool call was canceled.'), normalized, spec, sink, 'canceled');
    }
    if (!this.concurrency.acquire(spec.id, spec.parallelPolicy)) {
      return this.deny(toolError('TOOL_BUSY', 'Tool concurrency policy rejected this call.', true), normalized, spec, sink);
    }

    this.emit('started', normalized, spec, resolution.backendId, 'Tool execution started.', sink);
    try {
      const result = await this.executor.execute(spec, normalized, resolution.backend, this.sink(sink));
      const validation = this.resultValidator.validate(spec, result);
      if (!validation.ok) {
        return this.deny(toolError(validation.code, validation.message), normalized, spec, sink);
      }
      const terminalKind = result.status === 'error' ? 'failed' :
        (result.status === 'canceled' ? 'canceled' : 'completed');
      this.emit(terminalKind, normalized, spec, resolution.backendId, 'Tool execution finished.', sink,
        undefined, undefined, result);
      return { kind: 'result', result };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return this.deny(toolError('BACKEND_EXECUTION_FAILED', message, true), normalized, spec, sink);
    } finally {
      this.concurrency.release(spec.id, spec.parallelPolicy);
      this.cancellation.clear(normalized.callId);
    }
  }

  async resumeWithApproval(grant: ApprovalGrant, sink: ExecutionEventSink | null = null): Promise<ToolInvocationOutcome> {
    const call = this.approvals.pendingCall(grant.requestId);
    if (call === null) {
      return { kind: 'denied', error: toolError('APPROVAL_UNKNOWN', 'Approval request is not current.') };
    }
    call.approvalGrant = grant;
    return this.invoke(call, sink);
  }

  issueApprovalGrant(requestId: string): ApprovalGrant | null {
    return this.approvals.issueGrant(requestId);
  }

  cancel(callId: string): void {
    this.cancellation.cancel(callId);
  }

  private deny(
    error: ToolError,
    call: ToolCall,
    spec: ToolSpec | null,
    sink: ExecutionEventSink | null,
    kind: 'failed' | 'canceled' = 'failed'
  ): ToolInvocationOutcome {
    if (spec !== null) this.emit(kind, call, spec, '', error.message, sink);
    return { kind: 'denied', error };
  }

  private emit(
    kind: ExecutionEventKind,
    call: ToolCall,
    spec: ToolSpec,
    backendId: string,
    message: string,
    sink: ExecutionEventSink | null,
    policyDecision?: PolicyDecisionKind,
    approvalRequest?: ApprovalRequest,
    result?: ToolResult
  ): void {
    const event: ExecutionEvent = {
      kind,
      traceId: call.traceId,
      callId: call.callId,
      capabilityId: spec.capabilityId,
      toolId: spec.id,
      toolVersion: spec.version,
      backendId,
      timestampMs: Date.now(),
      message
    };
    if (policyDecision !== undefined) event.policyDecision = policyDecision;
    if (approvalRequest !== undefined) event.approvalRequest = approvalRequest;
    if (result !== undefined) event.result = result;
    const target = this.sink(sink);
    if (target !== null) target.emit(event);
  }

  private sink(sink: ExecutionEventSink | null): ExecutionEventSink | null {
    if (sink === null) return this.defaultSink;
    if (this.defaultSink === null || sink === this.defaultSink) return sink;
    return new CompositeExecutionEventSink(this.defaultSink, sink);
  }
}
