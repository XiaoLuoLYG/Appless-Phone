import { BackendResolution, ToolBackend } from '../contracts/BackendTypes';
import { BackendCandidate, ToolSpec } from '../contracts/ToolSpec';

export class ToolResolver {
  private readonly backends: Map<string, ToolBackend> = new Map<string, ToolBackend>();

  register(backend: ToolBackend): void {
    const backendId = backend.id();
    if (this.backends.has(backendId)) throw new Error('Duplicate capability backend: ' + backendId);
    this.backends.set(backendId, backend);
  }

  resolve(spec: ToolSpec): BackendResolution {
    const candidates = spec.backendCandidates.slice().sort((left: BackendCandidate, right: BackendCandidate): number =>
      left.priority - right.priority);
    for (let index = 0; index < candidates.length; index++) {
      const backend = this.backends.get(candidates[index].backendId);
      if (backend !== undefined && backend.canExecute(spec)) {
        return { ok: true, backendId: candidates[index].backendId, reason: '', backend };
      }
    }
    return { ok: false, backendId: '', reason: 'No registered backend can execute ' + spec.id + '.', backend: null };
  }
}
