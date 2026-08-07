import { ExecutionEvent } from '../contracts/ExecutionEvent';

export class DebugEventFormatter {
  format(event: ExecutionEvent): string {
    return '[' + event.traceId + '] ' + event.kind + ' ' + event.toolId +
      (event.backendId.length > 0 ? ' via ' + event.backendId : '') + ': ' + event.message;
  }
}
