import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_BUTTON_TEXT,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_CARD_RAISED,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_PAGE,
  COLOR_PANEL,
  COLOR_PANEL_SHADOW,
  COLOR_TEXT,
} from '../style/A2uiHomeTheme';
import { A2uiAction, A2uiSurfaceState, emptyA2uiSurface } from '../../../model/A2uiTypes';
import { A2uiSurfaceView } from './A2uiSurfaceView';

@Component
export struct HomePage {
  @Link inputText: string;
  @Prop isBusy: boolean = false;
  @Prop currentSurface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop surfaceRenderTick: number = 0;
  onOpenConfig: () => void = () => {};
  onOpenStyleLab: () => void = () => {};
  onSendPrompt: () => void = () => {};
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  build() {
    Column() {
      Row() {
        Row() {
          Text('PocketAgent')
            .minFontSize(20)
            .maxFontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('A2UI Home 最小刷新实验')
            .minFontSize(10)
            .maxFontSize(13)
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: 8 })
            .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Center)
        .layoutWeight(1)
        .constraintSize({ maxWidth: 220 })

        Button('配置')
          .height(40)
          .width(58)
          .fontSize(12)
          .fontColor(COLOR_INK)
          .backgroundColor(COLOR_CARD_RAISED)
          .borderRadius(10)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .margin({ left: 10 })
          .onClick(() => {
            this.onOpenConfig();
          })

        Button('Lab')
          .height(40)
          .width(54)
          .fontSize(12)
          .fontColor(COLOR_BUTTON_TEXT)
          .backgroundColor(COLOR_ACCENT_DEEP)
          .borderRadius(10)
          .border({ width: 1, color: COLOR_ACCENT })
          .margin({ left: 8 })
          .onClick(() => {
            this.onOpenStyleLab();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 18, right: 18, top: 16, bottom: 14 })
      .backgroundColor(COLOR_PANEL)
      .borderRadius(20)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .shadow({ radius: 24, color: COLOR_PANEL_SHADOW, offsetX: 0, offsetY: 12 })

      A2uiSurfaceView({
        surface: this.currentSurface,
        renderTick: this.surfaceRenderTick,
        isBusy: this.isBusy,
        onAction: this.onAction
      })
      .layoutWeight(1)
      .margin({ top: 14 })

      Column() {
        Row() {
          TextArea({
            placeholder: '告诉 PocketAgent 你想完成什么',
            text: this.inputText
          })
            .constraintSize({ minHeight: 52 })
            .layoutWeight(1)
            .fontSize(15)
            .fontColor(COLOR_TEXT)
            .lineHeight(21)
            .placeholderColor(COLOR_MUTED)
            .backgroundColor('#091017')
            .borderRadius(15)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .padding({ left: 14, right: 14, top: 13, bottom: 13 })
            .onChange((value: string) => {
              this.inputText = value;
            })

          Button(this.isBusy ? '生成中' : '生成')
            .enabled(!this.isBusy)
            .height(52)
            .width(98)
            .fontSize(15)
            .fontColor(COLOR_BUTTON_TEXT)
            .backgroundColor(COLOR_ACCENT_DEEP)
            .borderRadius(15)
            .border({ width: 1, color: COLOR_ACCENT })
            .shadow({ radius: 14, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 7 })
            .margin({ left: 10 })
            .onClick(() => {
              this.onSendPrompt();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)

        Row() {
          Text('surface=' + this.surfaceRenderTick.toString())
            .fontSize(11)
            .fontColor(COLOR_ACCENT)
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 12, left: 4, right: 4 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(COLOR_PAGE)
  }
}
