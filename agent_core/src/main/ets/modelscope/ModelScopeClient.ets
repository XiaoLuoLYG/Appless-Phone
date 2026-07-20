export interface ModelScopeClient {
  initialize(): Promise<void>;
  toolDescription(): string;
  search(useCase: string): Promise<string>;
  execute(qualifiedName: string, args: Object): Promise<string>;
}
