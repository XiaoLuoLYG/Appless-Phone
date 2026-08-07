import { ToolResult } from '../contracts/ToolResult';
import { ToolSpec } from '../contracts/ToolSpec';

export class ToolRetryController {
  private readonly maxRetries: number;

  constructor(maxRetries: number = 0) {
    this.maxRetries = Math.max(0, maxRetries);
  }

  canRetry(spec: ToolSpec, result: ToolResult, attempt: number): boolean {
    if (attempt >= this.maxRetries || spec.idempotency === 'non_idempotent') return false;
    return result.status === 'error' && result.error !== undefined && result.error.retryable;
  }
}
