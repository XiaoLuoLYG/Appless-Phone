import { ToolResult } from './ToolResult';

export interface SurfacePresentationContext {
  surfaceId: string;
  surfaceKind: string;
}

export interface ToolPresentation {
  presenterId: string;
  artifact: Object;
}

export interface ToolPresenter {
  present(result: ToolResult, context: SurfacePresentationContext): Promise<ToolPresentation>;
}

export interface ToolPresenterBinding {
  presenterId: string;
  outputSchemaRef: string;
  surfaceKind: string;
  presenter: ToolPresenter;
}
