import { DataResult } from '../../agent/message/DataResult';
import { ToolDefinition } from '../../aiphone/runtime/ToolDefinitionTypes';
import { ToolHandler, ToolHandlerBinding } from '../contracts/BackendTypes';
import { ToolCall } from '../contracts/ToolCall';
import { ToolResult } from '../contracts/ToolResult';
import { ToolSpec } from '../contracts/ToolSpec';
import { LegacyDataResultAdapter } from './LegacyDataResultAdapter';
import { LegacyHandlerBindingFactory } from './LegacyToolRegistryAdapter';

export type LegacyStructuredToolCaller = (
  toolId: string,
  prompt: string,
  args: Object | null
) => Promise<DataResult>;

class LegacyStructuredToolHandler implements ToolHandler {
  private readonly spec: ToolSpec;
  private readonly caller: LegacyStructuredToolCaller;
  private readonly adapter: LegacyDataResultAdapter = new LegacyDataResultAdapter();

  constructor(spec: ToolSpec, caller: LegacyStructuredToolCaller) {
    this.spec = spec;
    this.caller = caller;
  }

  async execute(call: ToolCall): Promise<ToolResult> {
    const startedAtMs = Date.now();
    const result = await this.caller(call.toolId, call.context.inputText, call.args);
    return this.adapter.toCapability(result, this.spec, startedAtMs);
  }
}

export class LegacyToolGatewayAdapter implements LegacyHandlerBindingFactory {
  private readonly caller: LegacyStructuredToolCaller;

  constructor(caller: LegacyStructuredToolCaller) {
    this.caller = caller;
  }

  bindings(definition: ToolDefinition, spec: ToolSpec): ToolHandlerBinding[] {
    const handler = new LegacyStructuredToolHandler(spec, this.caller);
    return definition.backendPriority.map((backendId: string): ToolHandlerBinding => ({
      toolId: definition.toolId,
      backendId,
      handler
    }));
  }
}
