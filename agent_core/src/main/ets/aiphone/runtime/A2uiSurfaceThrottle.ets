import { A2uiSurfaceState } from './A2uiTypes';

export type A2uiThrottledSurfaceCallback = (surface: A2uiSurfaceState, raw: string) => void;

export class A2uiSurfaceThrottle {
  private intervalMs: number;
  private callback: A2uiThrottledSurfaceCallback;
  private timerId: number = -1;
  private pendingSurface: A2uiSurfaceState | null = null;
  private pendingRaw: string = '';

  constructor(intervalMs: number, callback: A2uiThrottledSurfaceCallback) {
    this.intervalMs = intervalMs > 0 ? intervalMs : 0;
    this.callback = callback;
  }

  enqueue(surface: A2uiSurfaceState, raw: string): void {
    if (this.intervalMs === 0) {
      this.callback(surface, raw);
      return;
    }
    this.pendingSurface = surface;
    this.pendingRaw = raw;
    if (this.timerId >= 0) {
      return;
    }
    this.timerId = setTimeout(() => {
      this.timerId = -1;
      this.emitPending();
    }, this.intervalMs);
  }

  flush(): void {
    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    this.emitPending();
  }

  cancel(): void {
    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    this.pendingSurface = null;
    this.pendingRaw = '';
  }

  private emitPending(): void {
    if (this.pendingSurface === null) {
      return;
    }
    const surface = this.pendingSurface;
    const raw = this.pendingRaw;
    this.pendingSurface = null;
    this.pendingRaw = '';
    this.callback(surface, raw);
  }
}
