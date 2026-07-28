export class TrainPresaleResumeDrain {
  private readonly readPendingTaskId: () => string;
  private readonly readActiveCheckoutTaskId: () => string;
  private readonly resumeTask: (taskId: string) => Promise<void>;
  private queued: boolean = false;
  private running: boolean = false;

  constructor(
    readPendingTaskId: () => string,
    readActiveCheckoutTaskId: () => string,
    resumeTask: (taskId: string) => Promise<void>
  ) {
    this.readPendingTaskId = readPendingTaskId;
    this.readActiveCheckoutTaskId = readActiveCheckoutTaskId;
    this.resumeTask = resumeTask;
  }

  request(): Promise<void> {
    this.queued = true;
    if (this.running) {
      return Promise.resolve();
    }
    this.running = true;
    return this.drain();
  }

  private async drain(): Promise<void> {
    try {
      while (this.queued) {
        this.queued = false;
        const taskId = this.readPendingTaskId().trim();
        if (taskId.length === 0 || taskId === this.readActiveCheckoutTaskId().trim()) {
          continue;
        }
        await this.resumeTask(taskId);
      }
    } finally {
      this.running = false;
    }
  }
}
