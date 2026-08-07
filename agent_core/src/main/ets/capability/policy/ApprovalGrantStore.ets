import { ApprovalGrant } from '../contracts/ApprovalTypes';

export class ApprovalGrantStore {
  private readonly grants: Map<string, ApprovalGrant> = new Map<string, ApprovalGrant>();
  private readonly consumed: Set<string> = new Set<string>();

  put(grant: ApprovalGrant): void {
    this.grants.set(grant.requestId, JSON.parse(JSON.stringify(grant)) as ApprovalGrant);
  }

  find(requestId: string): ApprovalGrant | null {
    const grant = this.grants.get(requestId);
    return grant === undefined ? null : JSON.parse(JSON.stringify(grant)) as ApprovalGrant;
  }

  consume(requestId: string): boolean {
    if (!this.grants.has(requestId) || this.consumed.has(requestId)) {
      return false;
    }
    this.consumed.add(requestId);
    return true;
  }

  isConsumed(requestId: string): boolean {
    return this.consumed.has(requestId);
  }
}
