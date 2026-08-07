export class ToolCancellationManager {
  private readonly canceled: Set<string> = new Set<string>();

  cancel(callId: string): void {
    this.canceled.add(callId);
  }

  isCanceled(callId: string): boolean {
    return this.canceled.has(callId);
  }

  clear(callId: string): void {
    this.canceled.delete(callId);
  }
}
