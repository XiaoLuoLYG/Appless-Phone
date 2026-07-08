import {
  A2uiAction,
  A2uiComponent,
  A2uiSurfaceState,
  emptyA2uiSurface
} from '@loop/agent-core';
import {
  socialHubConnections,
  socialHubDraft,
  socialHubItems,
  socialHubSelected
} from '@loop/agent-core';
import {
  SocialHubConnectionData,
  SocialHubItemData,
  SocialHubPlatform
} from '@loop/agent-core';
import {
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_CARD_RAISED,
  COLOR_INK,
  COLOR_LINE,
  COLOR_MUTED,
  COLOR_SOCIAL,
  COLOR_SOCIAL_CARD,
  COLOR_SOCIAL_GLOW,
  COLOR_SOCIAL_LINE,
  COLOR_SOCIAL_SOFT,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import {
  A2UI_PANEL_CORNER_RADIUS
} from '../style/A2uiPanelFrameStyle';
import { A2uiPanelAccentView } from './common/A2uiPanelAccentView';
import { A2uiButtonView } from './common/A2uiButtonView';
import {
  socialHubAuthorText,
  socialHubCanAuthorize,
  socialHubComposioToolkitCandidates,
  socialHubDraftDisplayText,
  socialHubItemMetaText,
  socialHubKindLabel,
  SocialHubMessageGroup,
  socialHubPlatformLabel,
  socialHubPrimaryText,
  socialHubRecentMessageGroups
} from './SocialHubViewData';

const SOCIAL_HUB_CONNECTION_HEIGHT: number = 82;
const SOCIAL_HUB_CONNECTION_CARD_WIDTH: string = '30%';

interface SocialHubSendReplyArgs {
  text: string;
}

@Component
export struct SocialHubView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = {
    id: 'socialHub',
    component: 'SocialHub',
    dataPath: '/socialHub/items'
  };
  @Prop isBusy: boolean = false;
  @State replyText: string = '';
  @State activeItemId: string = '';
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private items(): SocialHubItemData[] {
    return socialHubItems(this.surface);
  }

  private selected(): SocialHubItemData {
    return socialHubSelected(this.surface);
  }

  private isSelected(item: SocialHubItemData): boolean {
    return item.id.length > 0 && item.id === this.selected().id;
  }

  private isActive(item: SocialHubItemData): boolean {
    return this.isSelected(item) || (item.id.length > 0 && item.id === this.activeItemId);
  }

  private isPostExpanded(item: SocialHubItemData): boolean {
    return item.kind === 'post' && this.isActive(item);
  }

  private connection(platform: SocialHubPlatform): SocialHubConnectionData {
    const connections = socialHubConnections(this.surface);
    for (let index = 0; index < connections.length; index++) {
      if (connections[index].platform === platform) {
        return connections[index];
      }
    }
    return {
      platform: platform,
      status: 'disabled',
      displayName: '',
      accountId: '',
      message: '未配置'
    };
  }

  private draftAction(item: SocialHubItemData): A2uiAction {
    return {
      id: 'social_hub_draft_reply',
      label: '生成草稿',
      prompt: item.id,
      variant: 'primary',
      kind: 'client'
    };
  }

  private sendReplyAction(item: SocialHubItemData): A2uiAction {
    const args: SocialHubSendReplyArgs = {
      text: this.replyText
    };
    return {
      id: 'social_hub_send_reply',
      label: '发送',
      prompt: item.id,
      variant: 'primary',
      kind: 'client',
      args: args
    };
  }

  private openSourceAction(item: SocialHubItemData): A2uiAction {
    return {
      id: 'social_hub_open_source',
      label: '打开来源',
      prompt: item.url,
      variant: 'secondary',
      kind: 'client'
    };
  }

  private authorizeAction(platform: SocialHubPlatform): A2uiAction {
    return {
      id: 'social_hub_authorize',
      label: '授权',
      prompt: platform,
      variant: 'primary',
      kind: 'client'
    };
  }

  private canAuthorize(connection: SocialHubConnectionData): boolean {
    return socialHubComposioToolkitCandidates(connection.platform).length > 0 &&
      socialHubCanAuthorize(connection.status);
  }

  private openInlineReply(item: SocialHubItemData): void {
    if (!this.isBusy) {
      if (this.activeItemId !== item.id) {
        this.replyText = '';
      }
      this.activeItemId = item.id;
    }
  }

  private connectionStatusText(connection: SocialHubConnectionData): string {
    if (connection.status === 'connected') {
      return '在线';
    }
    if (connection.status === 'limited') {
      return '只读';
    }
    if (connection.status === 'needs_auth') {
      return '授权';
    }
    if (connection.status === 'error') {
      return '异常';
    }
    return '待配置';
  }

  private connectionStatusColor(connection: SocialHubConnectionData): string {
    if (connection.status === 'connected') {
      return '#2F7754';
    }
    if (connection.status === 'limited') {
      return '#8A5A16';
    }
    if (connection.status === 'needs_auth') {
      return '#476F9F';
    }
    if (connection.status === 'error') {
      return '#B04A42';
    }
    return COLOR_MUTED;
  }

  private connectionStatusBackground(connection: SocialHubConnectionData): string {
    if (connection.status === 'connected') {
      return '#E7F3E8';
    }
    if (connection.status === 'limited') {
      return '#F3E6D4';
    }
    if (connection.status === 'needs_auth') {
      return '#E8EDF8';
    }
    if (connection.status === 'error') {
      return '#F6E2DF';
    }
    return '#F5F1EB';
  }

  private isDraftForItem(item: SocialHubItemData): boolean {
    const draft = socialHubDraft(this.surface);
    return draft.itemId === item.id && draft.status !== 'empty';
  }

  @Builder
  private PlatformLogo(platform: SocialHubPlatform, size: number) {
    if (platform === 'x') {
      Image($r('app.media.logo_x'))
        .width(size)
        .height(size)
        .objectFit(ImageFit.Contain)
    } else if (platform === 'slack') {
      Image($r('app.media.logo_slack'))
        .width(size)
        .height(size)
        .objectFit(ImageFit.Contain)
    } else if (platform === 'wecom') {
      Image($r('app.media.logo_wecom'))
        .width(size)
        .height(size)
        .objectFit(ImageFit.Contain)
    } else if (platform === 'discord') {
      Image($r('app.media.logo_discord'))
        .width(size)
        .height(size)
        .objectFit(ImageFit.Contain)
    } else if (platform === 'linkedin') {
      Image($r('app.media.logo_linkedin'))
        .width(size)
        .height(size)
        .objectFit(ImageFit.Contain)
    } else if (platform === 'whatsapp') {
      Image($r('app.media.logo_whatsapp'))
        .width(size)
        .height(size)
        .objectFit(ImageFit.Contain)
    } else if (platform === 'instagram') {
      Image($r('app.media.logo_instagram'))
        .width(size)
        .height(size)
        .objectFit(ImageFit.Contain)
    } else {
      Image($r('app.media.icon_social'))
        .width(size)
        .height(size)
        .objectFit(ImageFit.Contain)
    }
  }

  @Builder
  private ConnectionCell(platform: SocialHubPlatform) {
    Column() {
      this.PlatformLogo(platform, 24)
      Text(socialHubPlatformLabel(platform))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_INK)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 7 })

      Text(this.connectionStatusText(this.connection(platform)))
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.connectionStatusColor(this.connection(platform)))
        .textAlign(TextAlign.Center)
        .padding({ left: 7, right: 7, top: 3, bottom: 3 })
        .backgroundColor(this.connectionStatusBackground(this.connection(platform)))
        .borderRadius(7)
        .border({ width: 1, color: this.connectionStatusColor(this.connection(platform)) })
        .margin({ top: 6 })
    }
    .width(SOCIAL_HUB_CONNECTION_CARD_WIDTH)
    .height(SOCIAL_HUB_CONNECTION_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 6, right: 6 })
    .backgroundColor(COLOR_CARD_RAISED)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_LINE })
    .margin({ right: 6, top: 8 })
    .onClick(() => {
      if (this.canAuthorize(this.connection(platform))) {
        this.onAction(this.authorizeAction(platform));
      }
    })
  }

  @Builder
  private InlinePostActions(item: SocialHubItemData) {
    Row() {
      A2uiButtonView({
        label: '生成草稿',
        shape: 'pill',
        tone: 'primary',
        isEnabled: !this.isBusy
      })
        .width(108)
        .onClick(() => {
          if (!this.isBusy) {
            this.onAction(this.draftAction(item));
          }
        })
      if (item.url.length > 0) {
        Blank()
          .width(8)
        A2uiButtonView({
          label: '打开来源',
          shape: 'pill',
          tone: 'secondary',
          isEnabled: !this.isBusy
        })
          .width(108)
          .onClick(() => {
            if (!this.isBusy) {
              this.onAction(this.openSourceAction(item));
            }
          })
      }
    }
    .width('100%')
    .margin({ top: 12 })
  }

  @Builder
  private InlineReply(item: SocialHubItemData) {
    Column() {
      if (item.platform === 'slack') {
        Row() {
          TextInput({ text: this.replyText, placeholder: '回复 Slack' })
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontColor(COLOR_TEXT)
            .placeholderColor(COLOR_MUTED)
            .backgroundColor(COLOR_CARD_RAISED)
            .borderRadius(14)
            .border({ width: 1, color: COLOR_LINE })
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.replyText = value;
            })
          Blank()
            .width(8)
          A2uiButtonView({
            label: '发送',
            shape: 'pill',
            tone: 'primary',
            isEnabled: !this.isBusy
          })
            .width(84)
            .onClick(() => {
              if (!this.isBusy) {
                this.onAction(this.sendReplyAction(item));
              }
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      } else {
        TextArea({ text: this.replyText, placeholder: '回复 ' + socialHubPlatformLabel(item.platform) })
          .width('100%')
          .height(82)
          .fontSize(14)
          .fontColor(COLOR_TEXT)
          .placeholderColor(COLOR_MUTED)
          .backgroundColor(COLOR_CARD_RAISED)
          .borderRadius(14)
          .border({ width: 1, color: COLOR_LINE })
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .onChange((value: string) => {
            this.replyText = value;
          })

        Row() {
          A2uiButtonView({
            label: '生成草稿',
            shape: 'pill',
            tone: 'primary',
            isEnabled: !this.isBusy
          })
            .width(108)
            .onClick(() => {
              if (!this.isBusy) {
                this.onAction(this.draftAction(item));
              }
            })
          if (item.url.length > 0) {
            Blank()
              .width(8)
            A2uiButtonView({
              label: '打开来源',
              shape: 'pill',
              tone: 'secondary',
              isEnabled: !this.isBusy
            })
              .width(108)
              .onClick(() => {
                if (!this.isBusy) {
                  this.onAction(this.openSourceAction(item));
                }
              })
          }
        }
        .width('100%')
        .margin({ top: 10 })
      }

      if (this.isDraftForItem(item)) {
        Text(socialHubDraftDisplayText(socialHubDraft(this.surface)))
          .fontSize(13)
          .fontColor(socialHubDraft(this.surface).status === 'error' ? '#B04A42' : COLOR_TEXT)
          .lineHeight(20)
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor(COLOR_SOCIAL_SOFT)
          .borderRadius(12)
          .border({ width: 1, color: COLOR_SOCIAL_LINE })
          .margin({ top: 10 })
      }
    }
    .width('100%')
    .margin({ top: 12 })
  }

  @Builder
  private MessageRow(item: SocialHubItemData) {
    Column() {
      Column() {
        Row() {
          this.PlatformLogo(item.platform, 30)
          Blank()
            .width(10)
          Column() {
            Text(socialHubAuthorText(item))
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(socialHubItemMetaText(item))
              .fontSize(12)
              .fontColor(COLOR_MUTED)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(socialHubKindLabel(item.kind))
            .fontSize(11)
            .fontColor(COLOR_MUTED)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(COLOR_CARD_RAISED)
            .borderRadius(9)
            .border({ width: 1, color: COLOR_LINE })

          if (!this.isActive(item) && item.kind !== 'post') {
            Blank()
              .width(8)
            A2uiButtonView({
              label: '回复',
              shape: 'pill',
              tone: 'secondary',
              isEnabled: !this.isBusy
            })
              .onClick(() => {
                this.openInlineReply(item);
              })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.openInlineReply(item);
        })

        if (this.isActive(item)) {
          Text(socialHubPrimaryText(item))
            .fontSize(item.kind === 'post' ? 15 : 16)
            .fontWeight(item.kind === 'post' ? FontWeight.Regular : FontWeight.Medium)
            .fontColor(COLOR_TEXT)
            .lineHeight(item.kind === 'post' ? 22 : 24)
            .width('100%')
            .margin({ top: 12 })
            .onClick(() => {
              this.openInlineReply(item);
            })
        } else {
          Text(socialHubPrimaryText(item))
            .fontSize(16)
            .fontWeight(item.kind === 'post' ? FontWeight.Regular : FontWeight.Medium)
            .fontColor(COLOR_TEXT)
            .lineHeight(24)
            .maxLines(item.kind === 'post' ? 4 : 2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 12 })
            .onClick(() => {
              this.openInlineReply(item);
            })
        }

        if (item.kind === 'post' && item.mediaUrl.length > 0) {
          Image(item.mediaUrl)
            .width('100%')
            .height(this.isPostExpanded(item) ? 218 : 132)
            .objectFit(ImageFit.Cover)
            .borderRadius(14)
            .backgroundColor(COLOR_CARD_RAISED)
            .margin({ top: 10 })
            .onClick(() => {
              this.openInlineReply(item);
            })
        }

        if (item.unread) {
          Text('未读')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_SOCIAL)
            .padding({ left: 7, right: 7, top: 3, bottom: 3 })
            .backgroundColor(COLOR_SOCIAL_SOFT)
            .borderRadius(7)
            .margin({ top: 10 })
        }

        if (item.kind === 'post' && this.isPostExpanded(item)) {
          this.InlinePostActions(item)
        } else if (this.isActive(item)) {
          this.InlineReply(item)
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .margin({ top: 10 })
    .backgroundColor(this.isActive(item) ? COLOR_SOCIAL_CARD : COLOR_CARD_RAISED)
    .borderRadius(18)
    .border({ width: 1, color: this.isActive(item) ? COLOR_SOCIAL_LINE : COLOR_LINE })
    .onClick(() => {
      this.openInlineReply(item);
    })
  }

  @Builder
  private MessageList() {
    Column() {
      Row() {
        Text('消息')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .layoutWeight(1)
        Text(this.items().length.toString())
          .fontSize(12)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')
      .height(30)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 12, right: 12 })

      if (this.items().length === 0) {
        Column() {
          Text('还没有真实消息')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_INK)
          Text('真实数据接入前，这里只显示连接状态。')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 6 })
        }
        .width('100%')
        .height(168)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .border({ width: { top: 1 }, color: COLOR_LINE })
      } else {
        Scroll() {
          Column() {
            ForEach(socialHubRecentMessageGroups(this.items(), new Date().toISOString(), 5), (group: SocialHubMessageGroup) => {
              Text(socialHubPlatformLabel(group.platform))
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_MUTED)
                .margin({ top: 12 })
              ForEach(group.visibleItems, (item: SocialHubItemData) => {
                this.MessageRow(item)
              }, (item: SocialHubItemData) => item.id)
              if (group.hiddenCount > 0) {
                Text('已折叠 ' + group.hiddenCount.toString() + ' 条更早消息')
                  .fontSize(12)
                  .fontColor(COLOR_MUTED)
                  .margin({ top: 8 })
              }
            }, (group: SocialHubMessageGroup) => group.platform)
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: 520 })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .clip(true)
  }

  build() {
    Column() {
      A2uiPanelAccentView({
        accentColor: COLOR_SOCIAL,
        accentShadowColor: COLOR_SOCIAL_GLOW,
        showAccent: true
      })

      Column() {
        Row() {
          Text('SocialHub')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
            .layoutWeight(1)
          Text('社交工作台')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
        }
        .width('100%')
        .height(34)
        .alignItems(VerticalAlign.Center)

        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
          this.ConnectionCell('x')
          this.ConnectionCell('slack')
          this.ConnectionCell('wecom')
          this.ConnectionCell('discord')
          this.ConnectionCell('linkedin')
          this.ConnectionCell('whatsapp')
          this.ConnectionCell('instagram')
        }
        .width('100%')
        .margin({ top: 8 })

        Column() {
          this.MessageList()
        }
        .width('100%')
        .margin({ top: 12 })

      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    }
    .width('100%')
    .backgroundColor(COLOR_CARD)
    .borderRadius(A2UI_PANEL_CORNER_RADIUS)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 24, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 8 })
    .clip(true)
  }
}
