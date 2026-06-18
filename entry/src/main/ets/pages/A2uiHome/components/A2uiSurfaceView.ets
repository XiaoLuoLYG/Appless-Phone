import { A2uiAction, A2uiSurfaceState, emptyA2uiSurface } from '../../../model/A2uiTypes';
import { rootComponentIdOf } from '../render/A2uiRenderData';
import { A2uiNodeView } from './A2uiNodeView';

@Component
export struct A2uiSurfaceView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private hasRenderableSurface(): boolean {
    return this.surface.components.length > 0;
  }

  build() {
    Scroll() {
      if (this.hasRenderableSurface()) {
        A2uiNodeView({
          surface: this.surface,
          componentId: rootComponentIdOf(this.surface),
          renderTick: this.renderTick,
          isBusy: this.isBusy,
          onAction: this.onAction
        })
      }
    }
    .width('100%')
    .scrollBar(BarState.Off)
  }
}
