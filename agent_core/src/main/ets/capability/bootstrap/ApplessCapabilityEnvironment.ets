import { ApprovalBroker } from '../policy/ApprovalBroker';
import { CapabilityRegistry } from '../registry/CapabilityRegistry';
import { CapabilityRuntime } from '../runtime/CapabilityRuntime';
import { CapabilityPolicyEngine } from '../policy/CapabilityPolicyEngine';
import { ExecutionEventBus } from '../observability/ExecutionEventBus';
import { ToolAuditRecorder } from '../observability/ToolAuditRecorder';
import { ToolMetrics } from '../observability/ToolMetrics';

export class ApplessCapabilityEnvironment {
  readonly registry: CapabilityRegistry;
  readonly runtime: CapabilityRuntime;
  readonly approvals: ApprovalBroker;
  readonly policy: CapabilityPolicyEngine;
  readonly events: ExecutionEventBus;
  readonly audit: ToolAuditRecorder;
  readonly metrics: ToolMetrics;

  constructor(
    registry: CapabilityRegistry,
    runtime: CapabilityRuntime,
    approvals: ApprovalBroker,
    policy: CapabilityPolicyEngine,
    events: ExecutionEventBus,
    audit: ToolAuditRecorder,
    metrics: ToolMetrics
  ) {
    this.registry = registry;
    this.runtime = runtime;
    this.approvals = approvals;
    this.policy = policy;
    this.events = events;
    this.audit = audit;
    this.metrics = metrics;
  }
}
