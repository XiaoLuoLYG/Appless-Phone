import { A2uiAction } from '../../../model/A2uiTypes';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_ACTION_ACTIVATED,
  COLOR_ACTION_ACTIVATED_EDGE,
  COLOR_ACTION_ACTIVATED_TEXT,
  COLOR_ACTION_DEACTIVATED,
  COLOR_ACTION_DEACTIVATED_EDGE,
  COLOR_ACTION_DEACTIVATED_TEXT,
  COLOR_BUTTON_TEXT,
  COLOR_CARD_EDGE,
  COLOR_CARD_RAISED,
  COLOR_ERROR,
  COLOR_ERROR_SOFT,
  COLOR_INK
} from '../style/A2uiHomeTheme';
import {
  A2UI_DIALOG_ACTION_GAP,
  A2UI_DIALOG_ACTION_SIDE_PADDING,
  usesDialogActionLayout
} from '../style/A2uiActionBarLayout';
import { a2uiEnterTransition } from '../style/A2uiHomeMotion';

@Component
export struct ActionBarView {
  @Prop actions: A2uiAction[] = [];
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private actionBackground(variant: string): string {
    if (variant === 'activated') {
      return COLOR_ACTION_ACTIVATED;
    }
    if (variant === 'deactivated') {
      return COLOR_ACTION_DEACTIVATED;
    }
    if (variant === 'primary') {
      return COLOR_ACCENT_DEEP;
    }
    if (variant === 'danger') {
      return COLOR_ERROR_SOFT;
    }
    return COLOR_CARD_RAISED;
  }

  private actionBorder(variant: string): string {
    if (variant === 'activated') {
      return COLOR_ACTION_ACTIVATED_EDGE;
    }
    if (variant === 'deactivated') {
      return COLOR_ACTION_DEACTIVATED_EDGE;
    }
    if (variant === 'primary') {
      return COLOR_ACCENT;
    }
    if (variant === 'danger') {
      return COLOR_ERROR;
    }
    return COLOR_CARD_EDGE;
  }

  private actionTextColor(variant: string): string {
    if (variant === 'activated') {
      return COLOR_ACTION_ACTIVATED_TEXT;
    }
    if (variant === 'deactivated') {
      return COLOR_ACTION_DEACTIVATED_TEXT;
    }
    if (variant === 'primary') {
      return COLOR_BUTTON_TEXT;
    }
    if (variant === 'danger') {
      return COLOR_ERROR;
    }
    return COLOR_INK;
  }

  private useDialogLayout(): boolean {
    return usesDialogActionLayout(this.actions.length);
  }

  build() {
    if (this.actions.length > 0) {
      if (this.useDialogLayout()) {
        Row() {
          ForEach(this.actions, (action: A2uiAction, index: number) => {
            Button(action.label)
              .enabled(!this.isBusy)
              .height(40)
              .layoutWeight(1)
              .fontSize(13)
              .fontColor(this.actionTextColor(action.variant))
              .backgroundColor(this.actionBackground(action.variant))
              .borderRadius(12)
              .border({ width: 1, color: this.actionBorder(action.variant) })
              .margin({ right: index === 0 ? A2UI_DIALOG_ACTION_GAP : 0 })
              .animation({ duration: 120, curve: Curve.EaseOut })
              .onClick(() => {
                this.onAction(action);
              })
          }, (action: A2uiAction) => action.id + action.label)
        }
        .width('100%')
        .padding({ left: A2UI_DIALOG_ACTION_SIDE_PADDING, right: A2UI_DIALOG_ACTION_SIDE_PADDING })
        .margin({ top: 12 })
        .transition(a2uiEnterTransition())
      } else {
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
              .animation({ duration: 120, curve: Curve.EaseOut })
              .onClick(() => {
                this.onAction(action);
              })
          }, (action: A2uiAction) => action.id + action.label)
        }
        .width('100%')
        .margin({ top: 4 })
        .transition(a2uiEnterTransition())
      }
    }
  }
}
