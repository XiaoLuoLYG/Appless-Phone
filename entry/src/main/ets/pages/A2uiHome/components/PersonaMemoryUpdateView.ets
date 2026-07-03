import {
  A2uiAction,
  A2uiComponent,
  A2uiLabelValue,
  A2uiPersonaData,
  A2uiPersonaMemoryData,
  A2uiSurfaceState,
  emptyA2uiSurface
} from '@loop/agent-core';
import { actionsOf, labelValues, personaMemoryData, personaRuntimeData } from '@loop/agent-core';
import {
  COLOR_ACCENT_DEEP,
  COLOR_ACCENT_SOFT,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_CARD_RAISED,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { componentStatusOf, componentTitleOf } from '../render/A2uiRenderData';
import { a2uiEnterTransition } from '../style/A2uiHomeMotion';
import { A2UI_PANEL_BACKGROUND_COLOR, A2UI_PANEL_BORDER_COLOR, A2UI_PANEL_CORNER_RADIUS } from '../style/A2uiPanelFrameStyle';
import { ActionBarView } from './ActionBarView';
import { StatusBadgeView } from './StatusBadgeView';
import { A2uiPanelAccentView } from './common/A2uiPanelAccentView';
import { personaAvatarResource } from './PersonaAvatar';

const MEMORY_PANEL_TITLE_COLOR: string = '#FAF7F2';
const MEMORY_PANEL_SUBTITLE_COLOR: string = '#CFC7BE';
const MEMORY_PANEL_SOFT_LINE: string = '#FFFFFF1F';
const MEMORY_HIGHLIGHT_BACKGROUND: string = '#F7ECE6';

@Component
export struct PersonaMemoryUpdateView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'InfoRows' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private rows(): A2uiLabelValue[] {
    return labelValues(this.surface, this.component);
  }

  private rowValue(label: string): string {
    const rows = this.rows();
    for (let index = 0; index < rows.length; index++) {
      if (rows[index].label === label) {
        return rows[index].value.trim();
      }
    }
    return '';
  }

  private persona(): A2uiPersonaData {
    return personaRuntimeData(this.surface);
  }

  private personaMemory(): A2uiPersonaMemoryData {
    return personaMemoryData(this.surface);
  }

  private personaName(): string {
    return this.persona().name.length > 0 ? this.persona().name : '数字分身';
  }

  private cardTitle(): string {
    return componentTitleOf(this.component, this.personaName() + '已更新记忆');
  }

  private recordedPreference(): string {
    const recorded = this.rowValue('已记录');
    if (recorded.length > 0) {
      return recorded;
    }
    return this.personaMemory().summary.length > 0 ? this.personaMemory().summary : '已写入新的长期偏好';
  }

  private reasonText(): string {
    const reason = this.rowValue('原因');
    return reason.length > 0 ? reason : this.persona().reason;
  }

  private memoryText(): string {
    const memory = this.rowValue('Memory 摘要');
    return memory.length > 0 ? memory : this.personaMemory().summary;
  }

  private soulText(): string {
    const soul = this.rowValue('Soul 摘要');
    return soul.length > 0 ? soul : '当前分身会按自己的角色设定理解和回应用户请求。';
  }

  private cleanLine(line: string): string {
    let value = line.trim();
    while (value.indexOf('#') === 0) {
      value = value.substring(1).trim();
    }
    if (value.indexOf('- [ ]') === 0 || value.indexOf('- [x]') === 0 || value.indexOf('- [X]') === 0) {
      value = value.substring(5).trim();
    }
    if (value.indexOf('- ') === 0 || value.indexOf('* ') === 0) {
      value = value.substring(2).trim();
    }
    return value;
  }

  private displayLines(text: string): string[] {
    const rawLines = text.split('\r').join('\n').split('\n');
    const lines: string[] = [];
    for (let index = 0; index < rawLines.length; index++) {
      const line = this.cleanLine(rawLines[index]);
      if (line.length > 0) {
        lines.push(line);
      }
    }
    if (lines.length === 0) {
      lines.push('暂无摘要');
    }
    return lines;
  }

  @Builder
  private DetailBlock(title: string, value: string) {
    Column() {
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_ACCENT_DEEP)
      ForEach(this.displayLines(value), (line: string, index: number) => {
        Text(line)
          .fontSize(13)
          .fontColor(COLOR_TEXT)
          .lineHeight(19)
          .width('100%')
          .padding({ top: index === 0 ? 8 : 6 })
      }, (line: string, index: number) => title + '-' + index.toString() + '-' + line)
    }
    .width('100%')
    .padding({ left: 13, right: 13, top: 12, bottom: 12 })
    .backgroundColor(COLOR_CARD_RAISED)
    .borderRadius(13)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  build() {
    Column() {
      A2uiPanelAccentView()

      Column() {
        Row() {
          Image(personaAvatarResource(this.persona().avatarKey))
            .width(42)
            .height(42)
            .objectFit(ImageFit.Contain)
            .backgroundColor(COLOR_ACCENT_SOFT)
            .borderRadius(15)
            .padding(6)
          Column() {
            Row() {
              Text(this.cardTitle())
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(MEMORY_PANEL_TITLE_COLOR)
                .layoutWeight(1)
              StatusBadgeView({
                status: componentStatusOf(this.component, this.surface.status),
                label: ''
              })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Text(this.reasonText())
              .fontSize(12)
              .fontColor(MEMORY_PANEL_SUBTITLE_COLOR)
              .lineHeight(18)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 5 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 11 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Column() {
          Text('已记录偏好')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_ACCENT_DEEP)
          Text(this.recordedPreference())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#251A16')
            .lineHeight(27)
            .width('100%')
            .margin({ top: 8 })
          Text('后续同类请求会优先按这条偏好重新筛选结果。')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .lineHeight(18)
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 14, right: 14, top: 14, bottom: 14 })
        .backgroundColor(MEMORY_HIGHLIGHT_BACKGROUND)
        .borderRadius(14)
        .border({ width: 1, color: '#E7CFC4' })
        .margin({ top: 14 })

        Column() {
          this.DetailBlock('Memory 摘要', this.memoryText())
          Blank().height(10)
          this.DetailBlock('Soul 摘要', this.soulText())
        }
        .width('100%')
        .padding({ top: 12 })

        Row()
          .width('100%')
          .height(1)
          .backgroundColor(MEMORY_PANEL_SOFT_LINE)
          .margin({ top: 12 })

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
