import { A2uiAction } from '../../../model/A2uiTypes';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_BUTTON_TEXT,
  COLOR_CARD_EDGE,
  COLOR_CARD_RAISED,
  COLOR_ERROR,
  COLOR_ERROR_SOFT,
  COLOR_INK
} from '../A2uiHomeTheme';

@Component
export struct ActionBarView {
  @Prop actions: A2uiAction[] = [];
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private actionBackground(variant: string): string {
    if (variant === 'primary') {
      return COLOR_ACCENT_DEEP;
    }
    if (variant === 'danger') {
      return COLOR_ERROR_SOFT;
    }
    return COLOR_CARD_RAISED;
  }

  private actionBorder(variant: string): string {
    if (variant === 'primary') {
      return COLOR_ACCENT;
    }
    if (variant === 'danger') {
      return COLOR_ERROR;
    }
    return COLOR_CARD_EDGE;
  }

  private actionTextColor(variant: string): string {
    if (variant === 'primary') {
      return COLOR_BUTTON_TEXT;
    }
    if (variant === 'danger') {
      return COLOR_ERROR;
    }
    return COLOR_INK;
  }

  build() {
    if (this.actions.length > 0) {
      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
        ForEach(this.actions, (action: A2uiAction) => {
          Button(action.label)
            .enabled(!this.isBusy)
            .height(38)
            .fontSize(13)
            .fontColor(this.actionTextColor(action.variant))
            .backgroundColor(this.actionBackground(action.variant))
            .borderRadius(11)
            .border({ width: 1, color: this.actionBorder(action.variant) })
            .padding({ left: 14, right: 14 })
            .margin({ right: 8, top: 10 })
            .onClick(() => {
              this.onAction(action);
            })
        }, (action: A2uiAction) => action.id + action.label)
      }
      .width('100%')
      .margin({ top: 4 })
    }
  }
}
