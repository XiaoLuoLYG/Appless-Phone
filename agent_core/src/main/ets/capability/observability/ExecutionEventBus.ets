import { ExecutionEvent, ExecutionEventSink } from '../contracts/ExecutionEvent';

export interface ExecutionEventListener {
  onEvent(event: ExecutionEvent): void;
}

export class ExecutionEventBus implements ExecutionEventSink {
  private readonly listeners: ExecutionEventListener[] = [];

  subscribe(listener: ExecutionEventListener): void {
    this.listeners.push(listener);
  }

  emit(event: ExecutionEvent): void {
    for (let index = 0; index < this.listeners.length; index++) {
      this.listeners[index].onEvent(event);
    }
  }
}
