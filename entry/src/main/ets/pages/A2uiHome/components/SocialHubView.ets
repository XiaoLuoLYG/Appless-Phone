import {
  A2uiAction,
  A2uiComponent,
  A2uiSurfaceState,
  emptyA2uiSurface,
  socialHubConnections,
  socialHubItems,
  socialHubPublication,
  socialHubSelected,
  SocialHubConnectionData,
  SocialHubItemData,
  SocialHubPlatform,
  SocialHubPublicationData
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
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { A2UI_PANEL_CORNER_RADIUS } from '../style/A2uiPanelFrameStyle';
import { A2uiPanelAccentView } from './common/A2uiPanelAccentView';
import { A2uiButtonView } from './common/A2uiButtonView';
import {
  socialHubConnectionStatusLabel,
  socialHubAuthorText,
  socialHubPlatformLabel,
  socialHubPrimaryText,
  socialHubRecentMessageGroups,
  SocialHubMessageGroup
} from './SocialHubViewData';

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

  private messageGroups(): SocialHubMessageGroup[] {
    return socialHubRecentMessageGroups(this.items(), new Date().toISOString(), 5);
  }

  private communityItems(): SocialHubItemData[] {
    const items: SocialHubItemData[] = [];
    this.items().forEach((item: SocialHubItemData) => {
      if (item.kind === 'post' || item.kind === 'mention') {
        items.push(item);
      }
    });
    return items;
  }

  private isActive(item: SocialHubItemData): boolean {
    if (this.activeItemId.length > 0) {
      return item.id === this.activeItemId;
    }
    return item.id.length > 0 && item.id === socialHubSelected(this.surface).id;
  }

  private openReply(item: SocialHubItemData): void {
    if (this.isBusy) {
      return;
    }
    if (this.activeItemId !== item.id) {
      this.replyText = '';
    }
    this.activeItemId = item.id;
  }

  private sendReplyAction(item: SocialHubItemData): A2uiAction {
    const args: SocialHubSendReplyArgs = { text: this.replyText };
    return {
      id: 'social_hub_send_reply',
      label: '回复',
      prompt: item.id,
      variant: 'primary',
      kind: 'client',
      args: args
    };
  }

  private emptyStateText(): string {
    const connections = socialHubConnections(this.surface);
    for (let index = 0; index < connections.length; index++) {
      const current = connections[index];
      if (current.status === 'limited') {
        return current.message;
      }
    }
    for (let index = 0; index < connections.length; index++) {
      const current = connections[index];
      if (current.status === 'error') {
        return socialHubPlatformLabel(current.platform) + ' 读取失败，请稍后重试。';
      }
    }
    for (let index = 0; index < connections.length; index++) {
      const current = connections[index];
      if (current.status === 'needs_auth') {
        return socialHubPlatformLabel(current.platform) + ' 尚未连接。';
      }
    }
    return connections.length > 0 ? '已连接来源当前没有可读消息。' : '暂无可读消息。';
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
    } else if (platform === 'reddit') {
      Image($r('app.media.logo_reddit'))
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
  private AuthorizationStatus() {
    Column() {
      Text('授权状态')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .width('100%')

      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
        ForEach(socialHubConnections(this.surface), (connection: SocialHubConnectionData) => {
          Row() {
            this.PlatformLogo(connection.platform, 18)
            Text(socialHubPlatformLabel(connection.platform))
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_INK)
              .margin({ left: 6 })
            Text(socialHubConnectionStatusLabel(connection.status))
              .fontSize(11)
              .fontColor(COLOR_MUTED)
              .margin({ left: 5 })
          }
          .height(32)
          .padding({ left: 9, right: 9 })
          .margin({ right: 6, top: 6 })
          .backgroundColor(COLOR_CARD_RAISED)
          .borderRadius(12)
          .border({ width: 1, color: COLOR_LINE })
        }, (connection: SocialHubConnectionData) => connection.platform)
      }
      .width('100%')
    }
    .width('100%')
    .margin({ top: 6 })
  }

  @Builder
  private ReplyComposer(item: SocialHubItemData) {
    Row() {
      TextInput({ text: this.replyText, placeholder: '输入回复' })
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
        label: '回复',
        shape: 'pill',
        tone: 'primary',
        isEnabled: !this.isBusy && this.replyText.trim().length > 0
      })
        .width(78)
        .onClick(() => {
          if (!this.isBusy && this.replyText.trim().length > 0) {
            this.onAction(this.sendReplyAction(item));
          }
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: 12 })
  }

  @Builder
  private MessageRow(item: SocialHubItemData) {
    Column() {
      Row() {
        this.PlatformLogo(item.platform, 24)
        Text('来源 · ' + socialHubPlatformLabel(item.platform))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_MUTED)
          .margin({ left: 8 })
          .layoutWeight(1)
        if (!this.isActive(item)) {
          A2uiButtonView({
            label: '回复',
            shape: 'pill',
            tone: 'secondary',
            isEnabled: !this.isBusy
          })
            .width(72)
            .onClick(() => {
              this.openReply(item);
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text('发信人 · ' + socialHubAuthorText(item))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 12 })

      Text(socialHubPrimaryText(item))
        .fontSize(15)
        .fontColor(COLOR_TEXT)
        .lineHeight(22)
        .width('100%')
        .margin({ top: 8 })

      if (this.isActive(item)) {
        this.ReplyComposer(item)
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .margin({ top: 10 })
    .backgroundColor(this.isActive(item) ? COLOR_SOCIAL_CARD : COLOR_CARD_RAISED)
    .borderRadius(18)
    .border({ width: 1, color: this.isActive(item) ? COLOR_SOCIAL_LINE : COLOR_LINE })
    .onClick(() => {
      this.openReply(item);
    })
  }

  @Builder
  private PublicationPreview(publication: SocialHubPublicationData) {
    if (publication.status !== 'empty') {
      Column() {
        Text('公开帖子预览')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_MUTED)
          .width('100%')
        Text(socialHubPlatformLabel(publication.platform) +
          (publication.accountName.length > 0 ? ' · ' + publication.accountName : ''))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .width('100%')
          .margin({ top: 8 })
        Text(publication.error.length > 0 ? publication.error : publication.text)
          .fontSize(15)
          .fontColor(publication.status === 'error' ? COLOR_MUTED : COLOR_TEXT)
          .lineHeight(22)
          .width('100%')
          .margin({ top: 8 })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .margin({ top: 10 })
      .backgroundColor(COLOR_SOCIAL_CARD)
      .borderRadius(18)
      .border({ width: 1, color: COLOR_SOCIAL_LINE })
    }
  }

  private communityOpenAction(item: SocialHubItemData): A2uiAction {
    return {
      id: 'social_hub_open_source',
      label: '打开原文',
      prompt: item.url,
      variant: 'secondary',
      kind: 'client'
    };
  }

  @Builder
  private CommunityList(items: SocialHubItemData[]) {
    if (items.length > 0) {
      Column() {
        Text('社区内容')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .width('100%')
          .margin({ top: 12 })
        ForEach(items, (item: SocialHubItemData) => {
          Column() {
            Row() {
              this.PlatformLogo(item.platform, 22)
              Text('来源 · ' + socialHubPlatformLabel(item.platform))
                .fontSize(12)
                .fontColor(COLOR_MUTED)
                .margin({ left: 8 })
                .layoutWeight(1)
            }
            Text(socialHubPrimaryText(item))
              .fontSize(14)
              .fontColor(COLOR_TEXT)
              .lineHeight(21)
              .width('100%')
              .margin({ top: 8 })
            if (item.url.length > 0) {
              A2uiButtonView({
                label: '打开原文',
                shape: 'pill',
                tone: 'secondary',
                isEnabled: !this.isBusy
              })
                .width(96)
                .margin({ top: 10 })
                .onClick(() => {
                  if (!this.isBusy) {
                    this.onAction(this.communityOpenAction(item));
                  }
                })
            }
          }
          .width('100%')
          .padding(14)
          .margin({ top: 8 })
          .backgroundColor(COLOR_CARD_RAISED)
          .borderRadius(16)
          .border({ width: 1, color: COLOR_LINE })
        }, (item: SocialHubItemData) => item.platform + ':' + item.id)
      }
      .width('100%')
    }
  }

  @Builder
  private MessageList(groups: SocialHubMessageGroup[]) {
    if (groups.length === 0) {
      Column() {
        Text('暂无可读消息')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
        Text(this.emptyStateText())
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .lineHeight(20)
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })
      }
      .width('100%')
      .height(148)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 20, right: 20 })
    } else {
      Scroll() {
        Column() {
          ForEach(groups, (group: SocialHubMessageGroup) => {
            ForEach(group.visibleItems, (item: SocialHubItemData) => {
              this.MessageRow(item)
            }, (item: SocialHubItemData) => item.id)
          }, (group: SocialHubMessageGroup) => group.platform)
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: 560 })
      .scrollBar(BarState.Auto)
    }
  }

  build() {
    Column() {
      A2uiPanelAccentView({
        accentColor: COLOR_SOCIAL,
        accentShadowColor: COLOR_SOCIAL_GLOW,
        showAccent: true
      })

      Column() {
        Text('SocialHub')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .width('100%')

        this.AuthorizationStatus()

        this.PublicationPreview(socialHubPublication(this.surface))

        this.CommunityList(this.communityItems())

        this.MessageList(this.messageGroups())
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
