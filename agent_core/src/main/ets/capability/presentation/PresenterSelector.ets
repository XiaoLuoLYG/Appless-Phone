import { ToolPresenter } from '../contracts/PresenterTypes';
import { PresenterRegistry } from '../registry/PresenterRegistry';

export class PresenterSelector {
  private readonly registry: PresenterRegistry;

  constructor(registry: PresenterRegistry) {
    this.registry = registry;
  }

  select(outputSchemaRef: string, surfaceKind: string): ToolPresenter | null {
    return this.registry.find(outputSchemaRef, surfaceKind);
  }
}
