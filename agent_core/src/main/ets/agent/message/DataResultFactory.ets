import { DataResult, DataSource } from './DataResult';

function cloneSource(source: DataSource): DataSource {
  return {
    provider: source.provider,
    backend: source.backend,
    operation: source.operation,
    fetchedAt: source.fetchedAt,
    accountHint: source.accountHint
  };
}

function cloneSources(sources: DataSource[]): DataSource[] {
  return sources.map((source: DataSource): DataSource => cloneSource(source));
}

export function successfulDataResult(
  toolId: string,
  outputSchema: string,
  data: Object,
  sources: DataSource[]
): DataResult {
  return {
    toolId: toolId,
    outputSchema: outputSchema,
    status: 'success',
    sources: cloneSources(sources),
    data: data,
    warnings: []
  };
}

export function partialDataResult(
  toolId: string,
  outputSchema: string,
  data: Object,
  sources: DataSource[],
  warnings: string[]
): DataResult {
  return {
    toolId: toolId,
    outputSchema: outputSchema,
    status: 'partial',
    sources: cloneSources(sources),
    data: data,
    warnings: warnings.slice()
  };
}

export function emptyDataResult(
  toolId: string,
  outputSchema: string,
  sources: DataSource[],
  warning: string
): DataResult {
  return {
    toolId: toolId,
    outputSchema: outputSchema,
    status: 'empty',
    sources: cloneSources(sources),
    data: new Object(),
    warnings: warning.length > 0 ? [warning] : []
  };
}

export function errorDataResult(
  toolId: string,
  outputSchema: string,
  code: string,
  message: string,
  retryable: boolean = false,
  sources: DataSource[] = []
): DataResult {
  return {
    toolId: toolId,
    outputSchema: outputSchema,
    status: 'error',
    sources: cloneSources(sources),
    data: new Object(),
    warnings: [],
    error: {
      code: code,
      message: message,
      retryable: retryable
    }
  };
}
