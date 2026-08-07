import { ExecutionEvent } from '../contracts/ExecutionEvent';
import { ExecutionEventListener } from './ExecutionEventBus';
import { SensitiveDataRedactor } from './SensitiveDataRedactor';

export class ToolAuditRecorder implements ExecutionEventListener {
  private readonly events: ExecutionEvent[] = [];
  private readonly redactor: SensitiveDataRedactor = new SensitiveDataRedactor();

  onEvent(event: ExecutionEvent): void {
    this.events.push(this.redactor.redact(event as Object) as ExecutionEvent);
  }

  snapshot(): ExecutionEvent[] {
    return JSON.parse(JSON.stringify(this.events)) as ExecutionEvent[];
  }
}
