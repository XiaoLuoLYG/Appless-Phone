import { ComposioAuthConfigItem } from '@loop/agent-core';
import {
  COLOR_ACCENT,
  COLOR_CARD_EDGE,
  COLOR_CARD_RAISED,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_PANEL,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { composioAuthActionLabel, composioAuthStatusLabel, sortedComposioAuthConfigs } from './ComposioAuthViewData';
import { composioToolkitLogoResource } from './ComposioLogoResource';
import { StatusBadgeView } from './StatusBadgeView';

@Component
export struct ComposioAuthPage {
  @Prop userShortId: string = '';
  @Prop items: ComposioAuthConfigItem[] = [];
  @Prop message: string = '';
  @Prop isBusy: boolean = false;
  onBack: () => void = () => {};
  onRefresh: () => void = () => {};
  onAuthorize: (item: ComposioAuthConfigItem) => void = (_item: ComposioAuthConfigItem) => {};

  private visibleItems(): ComposioAuthConfigItem[] {
    return sortedComposioAuthConfigs(this.items);
  }

  private displayToolkitName(item: ComposioAuthConfigItem): string {
    return item.toolkitName.length > 0 ? item.toolkitName : item.toolkitSlug;
  }

  private subtitle(item: ComposioAuthConfigItem): string {
    if (item.connectedAccountLabel.length > 0) {
      return item.connectedAccountLabel;
    }
    if (item.authScheme.length > 0) {
      return item.authScheme;
    }
    return 'Composio';
  }

  @Builder
  ToolkitBadge(item: ComposioAuthConfigItem) {
    Image(composioToolkitLogoResource(item.toolkitSlug))
      .width(36)
      .height(36)
      .objectFit(ImageFit.Contain)
      .borderRadius(10)
  }

  @Builder
  AuthCard(item: ComposioAuthConfigItem) {
    Column() {
      Row() {
        this.ToolkitBadge(item)

        Column() {
          Text(this.displayToolkitName(item))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.subtitle(item))
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 10, right: 10 })

        StatusBadgeView({ status: item.status, label: composioAuthStatusLabel(item.status) })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text('Composio' + (item.authScheme.length > 0 ? ' · ' + item.authScheme : ''))
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Button(composioAuthActionLabel(item))
          .height(34)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor(COLOR_ACCENT)
          .borderRadius(9)
          .enabled(!this.isBusy && item.authConfigId.length > 0)
          .onClick(() => {
            this.onAuthorize(item);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor(COLOR_CARD_RAISED)
    .borderRadius(12)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ bottom: 10 })
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Button('返回')
            .height(40)
            .width(76)
            .fontSize(13)
            .fontColor(COLOR_INK)
            .backgroundColor(COLOR_CARD_RAISED)
            .borderRadius(10)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .onClick(() => {
              this.onBack();
            })

          Column() {
            Text('Composio 授权')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
            Text('当前用户 ' + (this.userShortId.length > 0 ? this.userShortId : '未初始化'))
              .fontSize(13)
              .fontColor(COLOR_MUTED)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 16 })

        Column() {
          Button('刷新')
            .height(36)
            .width('100%')
            .fontSize(12)
            .fontColor(COLOR_INK)
            .backgroundColor(COLOR_CARD_RAISED)
            .borderRadius(9)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .enabled(!this.isBusy)
            .onClick(() => {
              this.onRefresh();
            })

          if (this.message.length > 0) {
            Text(this.message)
              .fontSize(12)
              .fontColor(COLOR_TEXT)
              .lineHeight(18)
              .margin({ top: 12, bottom: 12 })
          }

          if (this.visibleItems().length === 0) {
            Text('当前没有可授权的 Composio Auth Config。')
              .fontSize(14)
              .fontColor(COLOR_TEXT)
              .lineHeight(20)
              .padding(18)
              .backgroundColor(COLOR_CARD_RAISED)
              .borderRadius(12)
              .border({ width: 1, color: COLOR_CARD_EDGE })
          } else {
            ForEach(this.visibleItems(), (item: ComposioAuthConfigItem) => {
              this.AuthCard(item)
            }, (item: ComposioAuthConfigItem) => item.authConfigId + '_' + item.toolkitSlug)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(18)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(16)
        .border({ width: 1, color: COLOR_CARD_EDGE })
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PANEL)
  }
}
