import {
  A2uiAction,
  A2uiComponent,
  A2uiDynamicToolConnectData,
  A2uiSurfaceState,
  emptyA2uiSurface
} from '@loop/agent-core';
import { actionsOf, dynamicToolConnect } from '@loop/agent-core';
import { AssetCredentialStore } from '@loop/agent-core';
import {
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_FIELD,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { A2UI_PANEL_BACKGROUND_COLOR, A2UI_PANEL_BORDER_COLOR, A2UI_PANEL_CORNER_RADIUS } from '../style/A2uiPanelFrameStyle';
import { a2uiEnterTransition } from '../style/A2uiHomeMotion';
import { ActionBarView } from './ActionBarView';
import { StatusBadgeView } from './StatusBadgeView';
import { A2uiPanelAccentView } from './common/A2uiPanelAccentView';

@Component
export struct ToolConnectCardView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'ToolConnectCard' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  @State credentialDraft: string = '';
  @State credentialMessage: string = '';
  private credentialStore: AssetCredentialStore = new AssetCredentialStore();
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private data(): A2uiDynamicToolConnectData {
    return dynamicToolConnect(this.surface);
  }

  private actions(): A2uiAction[] {
    const fromComponent = actionsOf(this.component);
    return fromComponent.length > 0 ? fromComponent : this.data().actions;
  }

  private async saveCredentialAndTest(): Promise<void> {
    const data = this.data();
    const value = this.credentialDraft.trim();
    if (data.credentialRef.length === 0 || value.length === 0) {
      this.credentialMessage = '请先粘贴凭据。';
      return;
    }
    try {
      await this.credentialStore.put(data.credentialRef, value);
      this.credentialMessage = '已保存到本机，正在测试连接。';
      const action: A2uiAction = {
        id: 'dynamic_test_connection',
        label: '测试连接',
        prompt: data.prompt.length > 0 ? data.prompt : data.toolId,
        kind: 'client',
        variant: 'primary'
      };
      this.onAction(action);
    } catch (_error) {
      this.credentialMessage = '凭据保存失败，请检查本机安全存储状态。';
    }
  }

  build() {
    Column() {
      A2uiPanelAccentView()
      Column() {
        Row() {
          Column() {
            Text(this.data().displayName.length > 0 ? '接入工具：' + this.data().displayName : '接入动态工具')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
            Text(this.data().message)
              .fontSize(13)
              .fontColor(COLOR_MUTED)
              .lineHeight(20)
              .margin({ top: 7 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          StatusBadgeView({ status: this.data().status, label: '' })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Column() {
          Row() {
            Text('工具 ID')
              .fontSize(12)
              .fontColor(COLOR_MUTED)
              .width(86)
            Text(this.data().toolId)
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ bottom: 8 })

          Row() {
            Text('凭据')
              .fontSize(12)
              .fontColor(COLOR_MUTED)
              .width(86)
            Text(this.data().credentialName.length > 0 ? this.data().credentialName : '无需凭据或等待预检')
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ bottom: 8 })

          Row() {
            Text('来源')
              .fontSize(12)
              .fontColor(COLOR_MUTED)
              .width(86)
            Text(this.data().sourceUrl.length > 0 ? this.data().sourceUrl : '本机 manifest')
              .fontSize(12)
              .fontColor(COLOR_TEXT)
              .lineHeight(18)
              .layoutWeight(1)
          }
          .width('100%')
        }
        .width('100%')
        .padding(12)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .borderRadius(10)
        .margin({ top: 12 })

        if (this.data().credentialName.length > 0 && this.data().credentialRef.length > 0) {
          Column() {
            TextInput({ text: this.credentialDraft, placeholder: '粘贴 ' + this.data().credentialName })
              .type(InputType.Password)
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .placeholderColor(COLOR_MUTED)
              .backgroundColor(COLOR_FIELD)
              .borderRadius(10)
              .border({ width: 1, color: COLOR_CARD_EDGE })
              .height(42)
              .onChange((value: string) => {
                this.credentialDraft = value;
              })
            Button('保存并测试')
              .height(40)
              .width('100%')
              .margin({ top: 10 })
              .enabled(!this.isBusy && this.credentialDraft.trim().length > 0)
              .onClick(() => {
                this.saveCredentialAndTest();
              })
            if (this.credentialMessage.length > 0) {
              Text(this.credentialMessage)
                .fontSize(12)
                .fontColor(COLOR_MUTED)
                .margin({ top: 8 })
            }
          }
          .width('100%')
          .margin({ top: 12 })
        }

        ActionBarView({
          actions: this.actions(),
          isBusy: this.isBusy,
          onAction: this.onAction
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
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
