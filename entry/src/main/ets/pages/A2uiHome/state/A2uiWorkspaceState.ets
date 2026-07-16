import { A2uiSurfaceState } from '@loop/agent-core';

@Observed
export class A2uiWorkspaceScene {
  sceneId: string;
  title: string;
  surface: A2uiSurfaceState;
  html: string;
  renderTick: number;
  isActive: boolean;

  constructor(
    sceneId: string,
    title: string,
    surface: A2uiSurfaceState,
    html: string,
    renderTick: number,
    isActive: boolean
  ) {
    this.sceneId = sceneId;
    this.title = title;
    this.surface = surface;
    this.html = html;
    this.renderTick = renderTick;
    this.isActive = isActive;
  }
}

export function isWorkspaceSceneBusy(scene: A2uiWorkspaceScene): boolean {
  return scene.surface.status === 'thinking' || scene.surface.status === 'calling_tool';
}
