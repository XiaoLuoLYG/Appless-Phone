import { ToolArtifactRef } from './ToolArtifact';
import { ToolEffect, cloneToolEffects } from './ToolEffect';
import { ToolError } from './ToolError';

export type ToolResultStatus = 'success' | 'partial' | 'empty' | 'error' | 'canceled';

export interface ToolResultSource {
  provider: string;
  backendId: string;
  operation: string;
  fetchedAt: string;
  accountHint?: string;
  receipt?: string;
}

export interface ToolResultMetadata {
  backendId: string;
  startedAtMs: number;
  completedAtMs: number;
  retryCount: number;
}

export interface ToolResult {
  toolId: string;
  toolVersion: string;
  outputSchemaRef: string;
  status: ToolResultStatus;
  data: Object;
  sources: ToolResultSource[];
  warnings: string[];
  observedEffects: ToolEffect[];
  artifacts: ToolArtifactRef[];
  metadata: ToolResultMetadata;
  error?: ToolError;
}

export function cloneToolResult(result: ToolResult): ToolResult {
  const copy: ToolResult = {
    toolId: result.toolId,
    toolVersion: result.toolVersion,
    outputSchemaRef: result.outputSchemaRef,
    status: result.status,
    data: JSON.parse(JSON.stringify(result.data)) as Object,
    sources: JSON.parse(JSON.stringify(result.sources)) as ToolResultSource[],
    warnings: result.warnings.slice(),
    observedEffects: cloneToolEffects(result.observedEffects),
    artifacts: JSON.parse(JSON.stringify(result.artifacts)) as ToolArtifactRef[],
    metadata: {
      backendId: result.metadata.backendId,
      startedAtMs: result.metadata.startedAtMs,
      completedAtMs: result.metadata.completedAtMs,
      retryCount: result.metadata.retryCount
    }
  };
  if (result.error !== undefined) {
    copy.error = {
      code: result.error.code,
      message: result.error.message,
      retryable: result.error.retryable
    };
  }
  return copy;
}
