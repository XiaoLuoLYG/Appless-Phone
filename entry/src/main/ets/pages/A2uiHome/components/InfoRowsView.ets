import { A2uiAction, A2uiComponent, A2uiSurfaceState, emptyA2uiSurface } from '@loop/agent-core';
import { actionsOf, labelValues, A2uiLabelValue } from '@loop/agent-core';
import {
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { componentBodyOf, componentStatusOf, componentTitleOf } from '../render/A2uiRenderData';
import { a2uiEnterTransition } from '../style/A2uiHomeMotion';
import { A2UI_PANEL_BACKGROUND_COLOR, A2UI_PANEL_BORDER_COLOR, A2UI_PANEL_CORNER_RADIUS } from '../style/A2uiPanelFrameStyle';
import { ActionBarView } from './ActionBarView';
import { StatusBadgeView } from './StatusBadgeView';
import { A2uiPanelAccentView } from './common/A2uiPanelAccentView';

@Component
export struct InfoRowsView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'InfoRows' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private rows(): A2uiLabelValue[] {
    return labelValues(this.surface, this.component);
  }

  build() {
    Column() {
      A2uiPanelAccentView()

      Column() {
      Row() {
        Column() {
          Text(componentTitleOf(this.component, '信息'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          if (componentBodyOf(this.component).length > 0) {
            Text(componentBodyOf(this.component))
              .fontSize(13)
              .fontColor(COLOR_MUTED)
              .lineHeight(20)
              .margin({ top: 7 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        StatusBadgeView({
          status: componentStatusOf(this.component, this.surface.status),
          label: ''
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.rows().length === 0) {
        Text('暂无可展示数据')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .padding({ top: 14, bottom: 4 })
      } else {
        ForEach(this.rows(), (row: A2uiLabelValue, index: number) => {
          Row() {
            Text(row.label)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_MUTED)
              .width(96)
            Text(row.value)
              .fontSize(14)
              .fontColor(COLOR_TEXT)
              .lineHeight(20)
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding({ top: index === 0 ? 14 : 10, bottom: 4 })
          .border({ width: { bottom: 1 }, color: COLOR_CARD_EDGE })
          .transition(a2uiEnterTransition())
        }, (row: A2uiLabelValue, index: number) => row.label + row.value + index.toString() + '-' + this.renderTick.toString())
      }

      ActionBarView({
        actions: actionsOf(this.component),
        isBusy: this.isBusy,
        onAction: this.onAction
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 18, bottom: 16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(A2UI_PANEL_BACKGROUND_COLOR)
    .borderRadius(A2UI_PANEL_CORNER_RADIUS)
    .border({ width: 1, color: A2UI_PANEL_BORDER_COLOR })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 12 })
    .transition(a2uiEnterTransition())
  }
}
