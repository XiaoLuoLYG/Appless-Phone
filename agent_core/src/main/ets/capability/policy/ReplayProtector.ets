export class ReplayProtector {
  private readonly identities: Set<string> = new Set<string>();

  claim(identity: string): boolean {
    if (identity.trim().length === 0 || this.identities.has(identity)) {
      return false;
    }
    this.identities.add(identity);
    return true;
  }

  clear(): void {
    this.identities.clear();
  }
}
