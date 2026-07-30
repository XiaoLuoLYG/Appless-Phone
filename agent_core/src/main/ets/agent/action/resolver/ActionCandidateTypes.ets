export interface ActionCandidate {
  identity: string;
  actionId: string;
  label: string;
  variant: string;
  args: Object;
}

export interface ActionCandidateProjector<T> {
  actionId(): string;

  project(source: T): ActionCandidate[];
}
