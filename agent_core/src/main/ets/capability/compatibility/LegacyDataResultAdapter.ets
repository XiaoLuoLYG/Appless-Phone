import { DataResult, DataSource } from '../../agent/message/DataResult';
import { ToolBackendType } from '../../aiphone/runtime/ToolDefinitionTypes';
import { ToolResult, ToolResultSource, ToolResultStatus } from '../contracts/ToolResult';
import { ToolSpec } from '../contracts/ToolSpec';

export class LegacyDataResultAdapter {
  toCapability(result: DataResult, spec: ToolSpec, startedAtMs: number): ToolResult {
    const sources = result.sources.map((source: DataSource): ToolResultSource => ({
      provider: source.provider,
      backendId: source.backend,
      operation: source.operation,
      fetchedAt: source.fetchedAt,
      accountHint: source.accountHint,
      receipt: source.receipt
    }));
    const adapted: ToolResult = {
      toolId: result.toolId,
      toolVersion: spec.version,
      outputSchemaRef: spec.outputSchemaRef.id,
      status: result.status as ToolResultStatus,
      data: result.data,
      sources,
      warnings: result.warnings.slice(),
      // Legacy DataResult has no effect evidence. Do not promote declared
      // effects to observed effects: a failed or partial call must not be
      // reported as a completed external write or financial transaction.
      // Backends that can prove a side effect must populate ToolResult
      // directly with the corresponding observed effect.
      observedEffects: [],
      artifacts: [],
      metadata: {
        backendId: sources.length > 0 ? sources[0].backendId : spec.backendCandidates[0].backendId,
        startedAtMs,
        completedAtMs: Date.now(),
        retryCount: 0
      }
    };
    if (result.error !== undefined) {
      adapted.error = {
        code: result.error.code,
        message: result.error.message,
        retryable: result.error.retryable === true
      };
    }
    return adapted;
  }

  toLegacy(result: ToolResult): DataResult {
    const sources: DataSource[] = result.sources.map((source: ToolResultSource): DataSource => ({
      provider: source.provider,
      backend: source.backendId as ToolBackendType,
      operation: source.operation,
      fetchedAt: source.fetchedAt,
      accountHint: source.accountHint,
      receipt: source.receipt
    }));
    const adapted: DataResult = {
      toolId: result.toolId,
      outputSchema: result.outputSchemaRef,
      status: result.status === 'canceled' ? 'error' : result.status,
      sources,
      data: result.data,
      warnings: result.warnings.slice()
    };
    if (result.error !== undefined) {
      adapted.error = {
        code: result.error.code,
        message: result.error.message,
        retryable: result.error.retryable
      };
    }
    return adapted;
  }
}
