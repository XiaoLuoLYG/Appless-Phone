import { ExecutionEvent } from '../contracts/ExecutionEvent';
import { ExecutionEventListener } from './ExecutionEventBus';

export interface ToolMetricSnapshot {
  started: number;
  completed: number;
  failed: number;
  canceled: number;
}

export class ToolMetrics implements ExecutionEventListener {
  private started: number = 0;
  private completed: number = 0;
  private failed: number = 0;
  private canceled: number = 0;

  onEvent(event: ExecutionEvent): void {
    if (event.kind === 'started') this.started++;
    if (event.kind === 'completed') this.completed++;
    if (event.kind === 'failed') this.failed++;
    if (event.kind === 'canceled') this.canceled++;
  }

  snapshot(): ToolMetricSnapshot {
    return { started: this.started, completed: this.completed, failed: this.failed, canceled: this.canceled };
  }
}
