import { LegacyStructuredToolCaller, LegacyToolGatewayAdapter } from '../compatibility/LegacyToolGatewayAdapter';
import { ExecutionEventBus } from '../observability/ExecutionEventBus';
import { ToolAuditRecorder } from '../observability/ToolAuditRecorder';
import { ToolMetrics } from '../observability/ToolMetrics';
import { ApprovalBroker } from '../policy/ApprovalBroker';
import { CapabilityPolicyEngine } from '../policy/CapabilityPolicyEngine';
import { CapabilityRuntime } from '../runtime/CapabilityRuntime';
import { ApplessBackendFactory } from './ApplessBackendFactory';
import { ApplessCapabilityEnvironment } from './ApplessCapabilityEnvironment';
import { ApplessCapabilityRegistryFactory } from './ApplessCapabilityRegistryFactory';

export class ApplessCapabilityRuntimeFactory {
  static create(legacyCaller: LegacyStructuredToolCaller): ApplessCapabilityEnvironment {
    const handlerAdapter = new LegacyToolGatewayAdapter(legacyCaller);
    const registry = ApplessCapabilityRegistryFactory.create(handlerAdapter);
    const approvals = new ApprovalBroker();
    const events = new ExecutionEventBus();
    const audit = new ToolAuditRecorder();
    const metrics = new ToolMetrics();
    events.subscribe(audit);
    events.subscribe(metrics);
    const policy = new CapabilityPolicyEngine(approvals);
    const resolver = ApplessBackendFactory.create(registry);
    const runtime = new CapabilityRuntime(registry, resolver, policy, approvals, events);
    return new ApplessCapabilityEnvironment(registry, runtime, approvals, policy, events, audit, metrics);
  }
}
