import {
  LeaderBimDashboardItem,
  LeaderBimDashboardItemKind
} from '@loop/agent-core';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_SHADOW,
  COLOR_ERROR,
  COLOR_ERROR_SOFT,
  COLOR_INK,
  COLOR_LINE,
  COLOR_MUTED,
  COLOR_SUCCESS,
  COLOR_SUCCESS_SOFT,
  COLOR_TEXT,
  COLOR_TRAVEL_FLIGHT,
  COLOR_TRAVEL_FLIGHT_CARD,
  COLOR_TRAVEL_TRAIN,
  COLOR_TRAVEL_TRAIN_CARD,
  COLOR_WARNING,
  COLOR_WARNING_SOFT
} from '../style/A2uiHomeTheme';

function resultKind(kind: LeaderBimDashboardItemKind): boolean {
  return kind === 'hotel' || kind === 'flight' || kind === 'transport' || kind === 'event';
}

function confirmedStatus(status: string): boolean {
  const label = bimDashboardStatusLabel(status);
  return label.indexOf('已确认') >= 0 || label.indexOf('已预订') >= 0 ||
    label.indexOf('已出票') >= 0 || label.indexOf('已完成') >= 0 ||
    label.indexOf('已锁定') >= 0 || label.indexOf('已安排') >= 0 ||
    label.indexOf('已通过') >= 0;
}

export const BIM_DASHBOARD_CARD_GAP: number = 14;
export const BIM_DASHBOARD_SECTION_GAP: number = 20;

export function bimDashboardStatusLabel(status: string): string {
  if (status === 'pending') return '待补充';
  if (status === 'in_progress') return '进行中';
  if (status === 'completed') return '已完成';
  if (status === 'confirmed') return '已确认';
  if (status === 'cancelled') return '已取消';
  return status;
}

export function bimDashboardStatusTone(status: string): string {
  const label = bimDashboardStatusLabel(status);
  if (label.indexOf('不参加') >= 0 || label.indexOf('取消') >= 0 ||
    label.indexOf('失败') >= 0) return 'error';
  if (confirmedStatus(label) || label.indexOf('参加') >= 0) return 'success';
  if (label.indexOf('待') >= 0 || label.indexOf('未') >= 0) return 'warning';
  return 'accent';
}

export function bimDashboardItemsForDisplay(
  items: LeaderBimDashboardItem[]
): LeaderBimDashboardItem[] {
  return items.filter((item: LeaderBimDashboardItem): boolean =>
    !resultKind(item.kind) || confirmedStatus(item.status)
  );
}

@Component
export struct BimDashboardView {
  @Prop items: LeaderBimDashboardItem[] = [];
  @Prop renderTick: number = 0;

  private visibleItems(): LeaderBimDashboardItem[] {
    return bimDashboardItemsForDisplay(this.items);
  }

  private itemsOf(kind: LeaderBimDashboardItemKind): LeaderBimDashboardItem[] {
    return this.visibleItems().filter((item: LeaderBimDashboardItem): boolean => item.kind === kind);
  }

  private resultItems(): LeaderBimDashboardItem[] {
    return this.visibleItems().filter((item: LeaderBimDashboardItem): boolean => resultKind(item.kind));
  }

  private hasItems(): boolean {
    return this.visibleItems().length > 0;
  }

  private progressPercent(value: string): number {
    const fraction = /^([0-9]+)\s*\/\s*([0-9]+)$/.exec(value);
    if (fraction !== null) {
      const current = Number(fraction[1]);
      const total = Number(fraction[2]);
      return total > 0 ? Math.max(0, Math.min(100, current * 100 / total)) : 0;
    }
    const percent = /^([0-9]+(?:\.[0-9]+)?)%$/.exec(value);
    return percent === null ? 0 : Math.max(0, Math.min(100, Number(percent[1])));
  }

  private statusForeground(status: string): string {
    const tone = bimDashboardStatusTone(status);
    if (tone === 'success') return COLOR_SUCCESS;
    if (tone === 'error') return COLOR_ERROR;
    if (tone === 'warning') return COLOR_WARNING;
    return COLOR_ACCENT_DEEP;
  }

  private statusBackground(status: string): string {
    const color = this.statusForeground(status);
    if (color === COLOR_SUCCESS) return COLOR_SUCCESS_SOFT;
    if (color === COLOR_ERROR) return COLOR_ERROR_SOFT;
    if (color === COLOR_WARNING) return COLOR_WARNING_SOFT;
    return COLOR_ACCENT_SOFT;
  }

  private resultAccent(kind: LeaderBimDashboardItemKind): string {
    if (kind === 'flight') return COLOR_TRAVEL_FLIGHT;
    if (kind === 'transport') return COLOR_TRAVEL_TRAIN;
    return COLOR_ACCENT_DEEP;
  }

  private resultBackground(kind: LeaderBimDashboardItemKind): string {
    if (kind === 'flight') return COLOR_TRAVEL_FLIGHT_CARD;
    if (kind === 'transport') return COLOR_TRAVEL_TRAIN_CARD;
    return kind === 'hotel' ? '#FBF5F0' : '#F7F2F8';
  }

  private resultMark(kind: LeaderBimDashboardItemKind): string {
    if (kind === 'hotel') return '宿';
    if (kind === 'flight') return '航';
    if (kind === 'transport') return '行';
    return '事';
  }

  @Builder
  private SectionTitle(title: string, count: number) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
      Blank()
      Text(count.toString())
        .fontSize(11)
        .fontColor(COLOR_MUTED)
    }
    .width('100%')
    .margin({ top: BIM_DASHBOARD_SECTION_GAP, bottom: 10 })
  }

  @Builder
  private StatusPill(status: string) {
    if (status.length > 0) {
      Text(bimDashboardStatusLabel(status))
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.statusForeground(status))
        .padding({ left: 7, right: 7, top: 3, bottom: 3 })
        .backgroundColor(this.statusBackground(status))
        .borderRadius(7)
    }
  }

  @Builder
  private ProgressCards() {
    ForEach(this.itemsOf('progress'), (item: LeaderBimDashboardItem) => {
      Column() {
        Row() {
          Column() {
            Text(item.title)
              .fontSize(12)
              .fontColor(COLOR_MUTED)
            Text(item.value)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
              .margin({ top: 5 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          this.StatusPill(item.status)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Row() {
          Row()
            .height(6)
            .width(this.progressPercent(item.value).toString() + '%')
            .backgroundColor(COLOR_ACCENT)
            .borderRadius(3)
        }
        .width('100%')
        .height(6)
        .backgroundColor(COLOR_CARD_EDGE)
        .borderRadius(3)
        .margin({ top: 13 })

        if (item.detail.length > 0) {
          Text(item.detail)
            .fontSize(12)
            .fontColor(COLOR_TEXT)
            .lineHeight(18)
            .margin({ top: 10 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor(COLOR_CARD)
      .borderRadius(16)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .shadow({ radius: 12, color: COLOR_CARD_SHADOW, offsetX: 0, offsetY: 4 })
      .margin({ top: BIM_DASHBOARD_CARD_GAP })
    }, (item: LeaderBimDashboardItem) => item.kind + '-' + item.title)
  }

  @Builder
  private Metrics() {
    if (this.itemsOf('metric').length > 0) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(this.itemsOf('metric'), (item: LeaderBimDashboardItem) => {
          Column() {
            Text(item.title)
              .fontSize(11)
              .fontColor(COLOR_MUTED)
            Text(item.value)
              .fontSize(23)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
              .margin({ top: 5 })
            if (item.detail.length > 0) {
              Text(item.detail)
                .fontSize(10)
                .fontColor(COLOR_MUTED)
                .margin({ top: 2 })
            }
          }
          .width('48.5%')
          .constraintSize({ minHeight: 88 })
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 14, right: 12, top: 10, bottom: 10 })
          .backgroundColor(COLOR_CARD)
          .borderRadius(14)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .shadow({ radius: 9, color: COLOR_CARD_SHADOW, offsetX: 0, offsetY: 3 })
          .margin({ top: BIM_DASHBOARD_CARD_GAP - 4 })
        }, (item: LeaderBimDashboardItem) => item.kind + '-' + item.title)
      }
      .width('100%')
    }
  }

  @Builder
  private People() {
    if (this.itemsOf('person').length > 0) {
      this.SectionTitle('关键人物', this.itemsOf('person').length)
      Column() {
        ForEach(this.itemsOf('person'), (item: LeaderBimDashboardItem, index: number) => {
          Row() {
            Stack({ alignContent: Alignment.Center }) {
              Text(item.title.substring(0, 1))
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_ACCENT_DEEP)
            }
            .width(34)
            .height(34)
            .borderRadius(17)
            .backgroundColor(COLOR_ACCENT_SOFT)

            Column() {
              Text(item.title)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLOR_INK)
              if (item.value.length > 0 || item.detail.length > 0) {
                Text(item.value + (item.value.length > 0 && item.detail.length > 0 ? ' · ' : '') + item.detail)
                  .fontSize(11)
                  .fontColor(COLOR_MUTED)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 3 })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 10, right: 8 })
            this.StatusPill(item.status)
          }
          .width('100%')
          .constraintSize({ minHeight: 58 })
          .padding({ top: 10, bottom: 10 })
          .border({
            width: { bottom: index === this.itemsOf('person').length - 1 ? 0 : 1 },
            color: COLOR_LINE
          })
        }, (item: LeaderBimDashboardItem) => item.kind + '-' + item.title)
      }
      .width('100%')
      .padding({ left: 14, right: 14 })
      .backgroundColor(COLOR_CARD)
      .borderRadius(16)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .shadow({ radius: 9, color: COLOR_CARD_SHADOW, offsetX: 0, offsetY: 3 })
      .margin({ top: BIM_DASHBOARD_CARD_GAP - 4 })
    }
  }

  @Builder
  private Timeline() {
    if (this.itemsOf('timeline').length > 0) {
      this.SectionTitle('时间线', this.itemsOf('timeline').length)
      Column() {
        ForEach(this.itemsOf('timeline'), (item: LeaderBimDashboardItem, index: number) => {
          Row() {
            Column() {
              Row()
                .width(9)
                .height(9)
                .borderRadius(5)
                .backgroundColor(index === 0 ? COLOR_ACCENT : COLOR_CARD_EDGE)
              if (index < this.itemsOf('timeline').length - 1) {
                Row()
                  .width(2)
                  .height(48)
                  .backgroundColor(COLOR_LINE)
              }
            }
            .width(18)
            .alignItems(HorizontalAlign.Center)

            Column() {
              Row() {
                Text(item.title)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(COLOR_INK)
                  .layoutWeight(1)
                this.StatusPill(item.status)
              }
              .width('100%')
              if (item.value.length > 0) {
                Text(item.value)
                  .fontSize(12)
                  .fontColor(COLOR_ACCENT_DEEP)
                  .margin({ top: 4 })
              }
              if (item.detail.length > 0) {
                Text(item.detail)
                  .fontSize(11)
                  .fontColor(COLOR_MUTED)
                  .lineHeight(17)
                  .margin({ top: 3 })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .padding({ bottom: index < this.itemsOf('timeline').length - 1 ? 14 : 2 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (item: LeaderBimDashboardItem) => item.kind + '-' + item.title)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .backgroundColor(COLOR_CARD)
      .borderRadius(16)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .shadow({ radius: 9, color: COLOR_CARD_SHADOW, offsetX: 0, offsetY: 3 })
      .margin({ top: BIM_DASHBOARD_CARD_GAP - 4 })
    }
  }

  @Builder
  private Tasks() {
    if (this.itemsOf('task').length > 0) {
      this.SectionTitle('接下来', this.itemsOf('task').length)
      Column() {
        ForEach(this.itemsOf('task'), (item: LeaderBimDashboardItem, index: number) => {
          Row() {
            Stack({ alignContent: Alignment.Center }) {
              if (confirmedStatus(item.status)) {
                Text('✓')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
              }
            }
            .width(20)
            .height(20)
            .borderRadius(6)
            .backgroundColor(confirmedStatus(item.status) ? COLOR_SUCCESS : COLOR_CARD)
            .border({ width: 1, color: confirmedStatus(item.status) ? COLOR_SUCCESS : COLOR_CARD_EDGE })

            Column() {
              Text(item.title)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLOR_INK)
              if (item.value.length > 0 || item.detail.length > 0) {
                Text(item.value + (item.value.length > 0 && item.detail.length > 0 ? ' · ' : '') + item.detail)
                  .fontSize(11)
                  .fontColor(COLOR_MUTED)
                  .margin({ top: 3 })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 10, right: 8 })
            this.StatusPill(item.status)
          }
          .width('100%')
          .constraintSize({ minHeight: 52 })
          .padding({ top: 9, bottom: 9 })
          .border({
            width: { bottom: index === this.itemsOf('task').length - 1 ? 0 : 1 },
            color: COLOR_LINE
          })
        }, (item: LeaderBimDashboardItem) => item.kind + '-' + item.title)
      }
      .width('100%')
      .padding({ left: 14, right: 14 })
      .backgroundColor(COLOR_CARD)
      .borderRadius(16)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .shadow({ radius: 9, color: COLOR_CARD_SHADOW, offsetX: 0, offsetY: 3 })
      .margin({ top: BIM_DASHBOARD_CARD_GAP - 4 })
    }
  }

  @Builder
  private ConfirmedResults() {
    if (this.resultItems().length > 0) {
      this.SectionTitle('已确认的安排', this.resultItems().length)
      ForEach(this.resultItems(), (item: LeaderBimDashboardItem) => {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            Text(this.resultMark(item.kind))
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .width(42)
          .height(42)
          .borderRadius(13)
          .backgroundColor(this.resultAccent(item.kind))

          Column() {
            Row() {
              Text(item.title)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_INK)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              this.StatusPill(item.status)
            }
            .width('100%')
            if (item.value.length > 0) {
              Text(item.value)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.resultAccent(item.kind))
                .margin({ top: 6 })
            }
            if (item.detail.length > 0) {
              Text(item.detail)
                .fontSize(11)
                .fontColor(COLOR_MUTED)
                .lineHeight(17)
                .margin({ top: 3 })
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding(15)
        .backgroundColor(this.resultBackground(item.kind))
        .borderRadius(16)
        .border({ width: 1, color: this.resultAccent(item.kind) + '44' })
        .shadow({ radius: 9, color: COLOR_CARD_SHADOW, offsetX: 0, offsetY: 3 })
        .margin({ bottom: BIM_DASHBOARD_CARD_GAP })
      }, (item: LeaderBimDashboardItem) => item.kind + '-' + item.title)
    }
  }

  build() {
    if (this.hasItems()) {
      Column() {
        this.ProgressCards()
        this.Metrics()
        this.People()
        this.Timeline()
        this.ConfirmedResults()
        this.Tasks()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 2 })
      .key('bim-dashboard-' + this.renderTick.toString())
    }
  }
}
