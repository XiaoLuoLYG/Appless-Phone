import { ToolParallelPolicy } from '../contracts/ToolSpec';

export class ToolConcurrencyController {
  private readonly active: Set<string> = new Set<string>();

  acquire(toolId: string, policy: ToolParallelPolicy): boolean {
    if (policy === 'parallel') return true;
    if (this.active.has(toolId)) return false;
    this.active.add(toolId);
    return true;
  }

  release(toolId: string, policy: ToolParallelPolicy): void {
    if (policy !== 'parallel') this.active.delete(toolId);
  }
}
