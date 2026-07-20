import { ToolBackendType } from '../../aiphone/runtime/ToolDefinitionTypes';

export type DataResultStatus = 'success' | 'partial' | 'empty' | 'error';

export interface DataSource {
  provider: string;
  backend: ToolBackendType;
  operation: string;
  fetchedAt: string;
  accountHint?: string;
}

export interface DataResultError {
  code: string;
  message: string;
  retryable?: boolean;
}

export interface DataResult {
  toolId: string;
  outputSchema: string;
  status: DataResultStatus;
  sources: DataSource[];
  data: Object;
  warnings: string[];
  error?: DataResultError;
}
