import {
  SurfacePresentationContext,
  ToolPresentation,
  ToolPresenter
} from '../../contracts/PresenterTypes';
import { ToolResult } from '../../contracts/ToolResult';

interface LegacyA2uiArtifact {
  surfaceId: string;
  component: string;
  toolId: string;
  data: Object;
  status: string;
  warnings: string[];
}

export class A2uiLegacyAdapter implements ToolPresenter {
  private readonly presenterId: string;
  private readonly component: string;

  constructor(presenterId: string, component: string) {
    this.presenterId = presenterId;
    this.component = component;
  }

  async present(result: ToolResult, context: SurfacePresentationContext): Promise<ToolPresentation> {
    const artifact: LegacyA2uiArtifact = {
      surfaceId: context.surfaceId,
      component: this.component,
      toolId: result.toolId,
      data: result.data,
      status: result.status,
      warnings: result.warnings
    };
    const presentation: ToolPresentation = {
      presenterId: this.presenterId,
      artifact
    };
    return presentation;
  }
}
