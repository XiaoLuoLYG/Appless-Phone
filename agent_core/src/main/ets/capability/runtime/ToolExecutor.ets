import { ExecutionEventSink } from '../contracts/ExecutionEvent';
import { ToolBackend } from '../contracts/BackendTypes';
import { ToolCall } from '../contracts/ToolCall';
import { ToolResult } from '../contracts/ToolResult';
import { ToolSpec } from '../contracts/ToolSpec';
import { ToolRetryController } from './ToolRetryController';

export class ToolExecutor {
  private readonly retry: ToolRetryController = new ToolRetryController();

  async execute(spec: ToolSpec, call: ToolCall, backend: ToolBackend, sink: ExecutionEventSink | null): Promise<ToolResult> {
    let attempt = 0;
    let result = await backend.execute(call, sink);
    while (this.retry.canRetry(spec, result, attempt)) {
      attempt++;
      result = await backend.execute(call, sink);
      result.metadata.retryCount = attempt;
    }
    return result;
  }
}
