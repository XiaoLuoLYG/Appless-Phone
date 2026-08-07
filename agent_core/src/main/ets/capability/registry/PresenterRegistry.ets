import {
  SurfacePresentationContext,
  ToolPresentation,
  ToolPresenter,
  ToolPresenterBinding
} from '../contracts/PresenterTypes';
import { ToolResult } from '../contracts/ToolResult';

function presenterKey(outputSchemaRef: string, surfaceKind: string): string {
  return outputSchemaRef + '@' + surfaceKind;
}

export class PresenterRegistry {
  private readonly bindings: Map<string, ToolPresenterBinding> = new Map<string, ToolPresenterBinding>();

  register(binding: ToolPresenterBinding): void {
    const key = presenterKey(binding.outputSchemaRef, binding.surfaceKind);
    const existing = this.bindings.get(key);
    if (existing !== undefined && existing.presenterId === binding.presenterId) {
      return;
    }
    if (existing !== undefined) {
      throw new Error('Duplicate capability presenter: ' + key);
    }
    this.bindings.set(key, binding);
  }

  has(outputSchemaRef: string, surfaceKind: string = '*'): boolean {
    return this.bindings.has(presenterKey(outputSchemaRef, surfaceKind));
  }

  find(outputSchemaRef: string, surfaceKind: string): ToolPresenter | null {
    const exact = this.bindings.get(presenterKey(outputSchemaRef, surfaceKind));
    const fallback = this.bindings.get(presenterKey(outputSchemaRef, '*'));
    const binding = exact ?? fallback;
    return binding === undefined ? null : binding.presenter;
  }

  async present(
    result: ToolResult,
    context: SurfacePresentationContext
  ): Promise<ToolPresentation | null> {
    const exact = this.bindings.get(presenterKey(result.outputSchemaRef, context.surfaceKind));
    const fallback = this.bindings.get(presenterKey(result.outputSchemaRef, '*'));
    const binding = exact ?? fallback;
    return binding === undefined ? null : binding.presenter.present(result, context);
  }
}
