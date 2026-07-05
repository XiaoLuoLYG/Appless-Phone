import {
  A2uiAction,
  A2uiComponent,
  A2uiSurfaceState,
  emptyA2uiSurface,
  stripeReceivingAccount
} from '@loop/agent-core';
import { actionsOf } from '@loop/agent-core';
import {
  COLOR_ACCENT,
  COLOR_ERROR,
  COLOR_ERROR_SOFT,
  COLOR_FIELD,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { A2UI_PANEL_BACKGROUND_COLOR, A2UI_PANEL_BORDER_COLOR } from '../style/A2uiPanelFrameStyle';
import { a2uiEnterTransition } from '../style/A2uiHomeMotion';
import { StatusBadgeView } from './StatusBadgeView';

@Component
export struct StripeReceivingAccountView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'StripeReceivingAccountCard' };
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private actions(): A2uiAction[] {
    const fromComponent = actionsOf(this.component);
    return fromComponent.length > 0 ? fromComponent : stripeReceivingAccount(this.surface).actions;
  }

  private badgeStatus(): string {
    const status = stripeReceivingAccount(this.surface).status;
    if (status === 'blocked' || status === 'config_missing') {
      return 'error';
    }
    if (status === 'receivable') {
      return 'ready';
    }
    return 'thinking';
  }

  @Builder
  private DetailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .width(92)
      Text(value.length > 0 ? value : '-')
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ bottom: 8 })
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(stripeReceivingAccount(this.surface).title.length > 0 ? stripeReceivingAccount(this.surface).title : 'Stripe 收款账户')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text(stripeReceivingAccount(this.surface).message)
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .lineHeight(20)
            .margin({ top: 8 })
        }
        .layoutWeight(1)

        StatusBadgeView({
          status: this.badgeStatus(),
          label: stripeReceivingAccount(this.surface).status.length > 0 ? stripeReceivingAccount(this.surface).status : 'setup'
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Column() {
        this.DetailRow('Agent', stripeReceivingAccount(this.surface).displayName)
        this.DetailRow('Email', stripeReceivingAccount(this.surface).email)
        this.DetailRow('Country', stripeReceivingAccount(this.surface).country)
        this.DetailRow('Stripe', stripeReceivingAccount(this.surface).stripeAccountId.length > 0 ? stripeReceivingAccount(this.surface).stripeAccountId : '尚未创建')
      }
      .width('100%')
      .padding(12)
      .backgroundColor(COLOR_FIELD)
      .borderRadius(8)
      .margin({ top: 14 })

      if (stripeReceivingAccount(this.surface).currentlyDue.length > 0) {
        Text('Stripe 仍需资料：' + stripeReceivingAccount(this.surface).currentlyDue.join(', '))
          .fontSize(12)
          .fontColor(COLOR_ERROR)
          .lineHeight(18)
          .margin({ top: 10 })
          .padding(10)
          .backgroundColor(COLOR_ERROR_SOFT)
          .borderRadius(8)
      }

      ForEach(this.actions(), (action: A2uiAction) => {
        Button(action.label)
          .width('100%')
          .height(42)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(this.isBusy ? COLOR_MUTED : COLOR_ACCENT)
          .enabled(!this.isBusy)
          .borderRadius(8)
          .margin({ top: 12 })
          .onClick(() => {
            this.onAction(action);
          })
      }, (action: A2uiAction) => action.id)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(A2UI_PANEL_BACKGROUND_COLOR)
    .border({ width: 1, color: A2UI_PANEL_BORDER_COLOR })
    .borderRadius(10)
    .margin({ bottom: 10 })
    .transition(a2uiEnterTransition())
  }
}
