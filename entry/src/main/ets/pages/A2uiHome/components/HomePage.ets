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
} from '../A2uiHomeTheme';
import { A2uiAction, A2uiSurfaceState, emptyA2uiSurface } from '../../../model/A2uiTypes';
import { A2uiSurfaceView } from './A2uiSurfaceView';
import { StatusBadgeView } from './StatusBadgeView';

@Component
export struct HomePage {
  @Link inputText: string;
  @Prop connectionStatus: string = 'idle';
  @Prop connectionMessage: string = '';
  @Prop selectedModel: string = '';
  @Prop baseUrl: string = '';
  @Prop isBusy: boolean = false;
  @Prop refreshTick: number = 0;
  @Prop currentSurface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop surfaceRenderTick: number = 0;
  onOpenConfig: () => void = () => {};
  onSendPrompt: () => void = () => {};
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  build() {
    Column() {
      Row() {
        Column() {
          Text('PocketAgent')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text('A2UI Home 最小刷新实验')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .margin({ top: 5 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        StatusBadgeView({
          status: this.connectionStatus,
          label: ''
        })

        Button('配置')
          .height(40)
          .width(78)
          .fontSize(13)
          .fontColor(COLOR_INK)
          .backgroundColor(COLOR_CARD_RAISED)
          .borderRadius(10)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .margin({ left: 10 })
          .onClick(() => {
            this.onOpenConfig();
          })
      }
      .width('100%')
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
          TextInput({
            placeholder: '告诉 PocketAgent 你想完成什么',
            text: this.inputText
          })
            .height(52)
            .layoutWeight(1)
            .fontSize(15)
            .fontColor(COLOR_TEXT)
            .placeholderColor(COLOR_MUTED)
            .backgroundColor('#091017')
            .borderRadius(15)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .padding({ left: 14, right: 14 })
            .enterKeyType(EnterKeyType.Send)
            .onChange((value: string) => {
              this.inputText = value;
            })
            .onSubmit(() => {
              if (!this.isBusy) {
                this.onSendPrompt();
              }
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
        .alignItems(VerticalAlign.Center)

        Row() {
          Text(this.connectionMessage)
            .fontSize(11)
            .fontColor(COLOR_MUTED)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('panel=' + this.refreshTick.toString() + ' surface=' + this.surfaceRenderTick.toString())
            .fontSize(11)
            .fontColor(COLOR_ACCENT)
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
