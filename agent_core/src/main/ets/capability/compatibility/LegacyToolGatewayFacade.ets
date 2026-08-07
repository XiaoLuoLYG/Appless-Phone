import { DataResult, DataResultError } from '../../agent/message/DataResult';
import { ToolCall } from '../contracts/ToolCall';
import { CapabilityRuntime } from '../runtime/CapabilityRuntime';
import { CapabilityRegistry } from '../registry/CapabilityRegistry';
import { LegacyDataResultAdapter } from './LegacyDataResultAdapter';

class EmptyLegacyToolData {
}

export class LegacyToolGatewayFacade {
  private readonly runtime: CapabilityRuntime;
  private readonly registry: CapabilityRegistry;
  private readonly adapter: LegacyDataResultAdapter = new LegacyDataResultAdapter();

  constructor(runtime: CapabilityRuntime, registry: CapabilityRegistry) {
    this.runtime = runtime;
    this.registry = registry;
  }

  async call(call: ToolCall): Promise<DataResult> {
    const outcome = await this.runtime.invoke(call);
    if (outcome.kind === 'result' && outcome.result !== undefined) return this.adapter.toLegacy(outcome.result);
    const code = outcome.kind === 'approval_required' ? 'APPROVAL_REQUIRED' :
      (outcome.error?.code === 'TOOL_NOT_REGISTERED' ? 'TOOL_NOT_ALLOWED' : outcome.error?.code ?? 'TOOL_FAILED');
    const message = outcome.kind === 'approval_required' ? 'Tool requires approval before execution.' :
      outcome.error?.message ?? 'Tool invocation failed.';
    const spec = this.registry.findTool(call.toolId);
    const error: DataResultError = { code, message, retryable: outcome.error?.retryable === true };
    const result: DataResult = {
      toolId: call.toolId,
      outputSchema: spec === null ? '' : spec.outputSchemaRef.id,
      status: 'error',
      sources: [],
      data: new EmptyLegacyToolData(),
      warnings: [],
      error
    };
    return result;
  }
}
