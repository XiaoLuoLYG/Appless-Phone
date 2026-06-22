import {
  A2UI_PANEL_ACCENT_COLOR,
  A2UI_PANEL_ACCENT_HEIGHT,
  A2UI_PANEL_ACCENT_INSET_Y,
  A2UI_PANEL_ACCENT_SHADOW_COLOR
} from '../../style/A2uiPanelFrameStyle';

@Component
export struct A2uiPanelAccentView {
  @Prop accentColor: string = A2UI_PANEL_ACCENT_COLOR;
  @Prop accentShadowColor: string = A2UI_PANEL_ACCENT_SHADOW_COLOR;
  @Prop showAccent: boolean = true;

  build() {
    Row() {
      Row()
        .width('72%')
        .height(this.showAccent ? A2UI_PANEL_ACCENT_HEIGHT : 0)
        .linearGradient({
          angle: 90,
          colors: [['#00000000', 0], [this.accentColor, 0.5], ['#00000000', 1]]
        })
        .shadow({ radius: 6, color: this.accentShadowColor, offsetX: 0, offsetY: 0 })
        .translate({ y: A2UI_PANEL_ACCENT_INSET_Y })
        .opacity(this.showAccent ? 1 : 0)
    }
    .width('100%')
    .height(this.showAccent ? A2UI_PANEL_ACCENT_HEIGHT : 0)
    .justifyContent(FlexAlign.Center)
  }
}
