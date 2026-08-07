import { LeaderBimSuggestion } from '@loop/agent-core';
import { BimRecord } from '../bim/BimStore';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_SOFT,
  COLOR_CARD_EDGE,
  COLOR_INK,
  COLOR_LINE,
  COLOR_MUTED,
  COLOR_PAGE,
  COLOR_PANEL,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import {
  A2UI_HOME_MAX_WIDTH,
  A2UI_HOME_PAGE_PADDING_BOTTOM,
  A2UI_HOME_PAGE_PADDING_TOP,
  A2UI_HOME_PAGE_PADDING_X
} from '../style/A2uiHomeLayout';
import {
  A2UI_MOTION_MOVE_CURVE,
  A2UI_MOTION_NORMAL_MS
} from '../style/A2uiHomeMotion';

export interface BimRecordGroups {
  active: BimRecord[];
  quiet: BimRecord[];
  tucked: BimRecord[];
  ended: BimRecord[];
}

function validBimSuggestion(suggestion: LeaderBimSuggestion | undefined): boolean {
  if (suggestion === undefined || suggestion.title.trim().length === 0 || suggestion.title.length > 80 ||
    suggestion.summary.trim().length === 0 || suggestion.summary.length > 500 || suggestion.reason.length > 500 ||
    suggestion.keywords.length > 16) {
    return false;
  }
  const keywords: string[] = [];
  for (let index = 0; index < suggestion.keywords.length; index++) {
    const keyword = suggestion.keywords[index].trim();
    if (keyword.length === 0 || keyword.length > 40 || keywords.indexOf(keyword) >= 0) {
      return false;
    }
    keywords.push(keyword);
  }
  return true;
}

export function shouldShowBimSuggestion(
  suggestion: LeaderBimSuggestion | undefined,
  activeBimId: string,
  busy: boolean
): boolean {
  return !busy && activeBimId.length === 0 && validBimSuggestion(suggestion);
}

function newestFirst(records: BimRecord[]): BimRecord[] {
  const sorted = records.slice();
  sorted.sort((left: BimRecord, right: BimRecord): number =>
    new Date(right.updatedAt).getTime() - new Date(left.updatedAt).getTime());
  return sorted;
}

export function groupVisibleBims(records: BimRecord[]): BimRecordGroups {
  const grouped: BimRecordGroups = { active: [], quiet: [], tucked: [], ended: [] };
  records.forEach((record: BimRecord): void => {
    if (record.lifecycle === 'active') {
      grouped.active.push(record);
    } else if (record.lifecycle === 'quiet') {
      grouped.quiet.push(record);
    } else if (record.lifecycle === 'tucked') {
      grouped.tucked.push(record);
    } else {
      grouped.ended.push(record);
    }
  });
  grouped.active = newestFirst(grouped.active);
  grouped.quiet = newestFirst(grouped.quiet);
  grouped.tucked = newestFirst(grouped.tucked);
  grouped.ended = newestFirst(grouped.ended);
  return grouped;
}

export function formatBimCount(count: number): string {
  if (count <= 0) {
    return '';
  }
  return count > 9 ? '9+' : count.toString();
}

export function combineBimErrorMessages(storeError: string, transientError: string): string {
  const storeMessage = storeError.trim();
  const transientMessage = transientError.trim();
  if (storeMessage.length === 0 || storeMessage === transientMessage) {
    return transientMessage.length > 0 ? transientMessage : storeMessage;
  }
  if (transientMessage.length === 0) {
    return storeMessage;
  }
  return storeMessage + '\n' + transientMessage;
}

function pad2(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

function updatedTimeLabel(updatedAt: string): string {
  const date = new Date(updatedAt);
  if (isNaN(date.getTime())) {
    return '';
  }
  return pad2(date.getMonth() + 1) + '月' + pad2(date.getDate()) + '日 ' +
    pad2(date.getHours()) + ':' + pad2(date.getMinutes());
}

function lifecycleLabel(record: BimRecord): string {
  if (record.lifecycle === 'active') {
    return '进行中';
  }
  if (record.lifecycle === 'quiet') {
    return '沉静';
  }
  if (record.lifecycle === 'tucked') {
    return '已收起';
  }
  return '已结束';
}

@Component
export struct BimHomePage {
  @Prop records: BimRecord[] = [];
  @Prop isLoading: boolean = false;
  @Prop errorMessage: string = '';
  @Prop reduceMotion: boolean = false;
  @State showTucked: boolean = false;
  @State showEnded: boolean = false;
  @State pressedRecordId: string = '';
  onOpenRecord: (bimId: string) => void = (_bimId: string): void => {};

  private grouped(): BimRecordGroups {
    return groupVisibleBims(this.records);
  }

  private rowScale(recordId: string): number {
    return !this.reduceMotion && this.pressedRecordId === recordId ? 0.98 : 1;
  }

  private handleRecordTouch(recordId: string, event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.pressedRecordId = recordId;
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pressedRecordId = '';
    }
  }

  @Builder
  private SectionHeading(title: string, count: number) {
    Row() {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_INK)
        .layoutWeight(1)
      Text(count.toString())
        .fontSize(11)
        .fontColor(COLOR_MUTED)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: 24, bottom: 6 })
  }

  @Builder
  private RecordRow(record: BimRecord, number: number) {
    Row() {
      Text(pad2(number))
        .width(34)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_ACCENT)
        .textAlign(TextAlign.Start)

      Column() {
        Text(record.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_INK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(record.retrievalIndex.summary)
          .fontSize(13)
          .fontColor(COLOR_TEXT)
          .lineHeight(19)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
        Row() {
          Text(updatedTimeLabel(record.updatedAt))
            .fontSize(11)
            .fontColor(COLOR_MUTED)
            .layoutWeight(1)
          Text(lifecycleLabel(record))
            .fontSize(11)
            .fontColor(record.lifecycle === 'active' ? COLOR_ACCENT : COLOR_MUTED)
        }
        .width('100%')
        .margin({ top: 7 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ right: 12 })

      Image($r('app.media.icon_back'))
        .width(16)
        .height(16)
        .rotate({ angle: 180 })
        .opacity(0.5)
    }
    .width('100%')
    .constraintSize({ minHeight: 82 })
    .alignItems(VerticalAlign.Center)
    .padding({ left: 4, right: 4, top: 12, bottom: 12 })
    .backgroundColor(this.pressedRecordId === record.id ? COLOR_ACCENT_SOFT : '#00000000')
    .border({ width: { bottom: 1 }, color: COLOR_LINE })
    .scale({ x: this.rowScale(record.id), y: this.rowScale(record.id) })
    .animation({
      duration: this.reduceMotion ? 0 : 120,
      curve: Curve.EaseOut
    })
    .accessibilityText(
      record.title + '，' + record.retrievalIndex.summary + '，' +
        lifecycleLabel(record) + '，更新于' + updatedTimeLabel(record.updatedAt)
    )
    .onTouch((event: TouchEvent) => {
      this.handleRecordTouch(record.id, event);
    })
    .onClick(() => {
      this.onOpenRecord(record.id);
    })
  }

  @Builder
  private DisclosureRow(label: string, count: number, expanded: boolean, onToggle: () => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
        .layoutWeight(1)
      Text(count.toString() + ' 件')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .margin({ right: 12 })
      Text(expanded ? '收起' : '查看')
        .fontSize(12)
        .fontColor(COLOR_ACCENT)
    }
    .width('100%')
    .height(48)
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: 1 }, color: COLOR_LINE })
    .accessibilityText(label + '，共 ' + count.toString() + ' 件，' + (expanded ? '收起' : '展开'))
    .onClick(onToggle)
  }

  @Builder
  private LoadingState() {
    Column() {
      ForEach([0, 1, 2], (index: number) => {
        Row() {
          Text('')
            .width(28)
            .height(10)
            .backgroundColor(COLOR_CARD_EDGE)
            .borderRadius(4)
          Column() {
            Text('')
              .width(index === 1 ? '62%' : '48%')
              .height(15)
              .backgroundColor(COLOR_CARD_EDGE)
              .borderRadius(5)
            Text('')
              .width('84%')
              .height(11)
              .backgroundColor(COLOR_LINE)
              .borderRadius(4)
              .margin({ top: 9 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
        }
        .width('100%')
        .height(72)
        .alignItems(VerticalAlign.Center)
        .border({ width: { bottom: 1 }, color: COLOR_LINE })
      }, (index: number) => index.toString())
    }
    .width('100%')
    .margin({ top: 18 })
    .accessibilityText('正在载入心上事')
  }

  @Builder
  private EmptyState() {
    Column() {
      Text('还没有心上事')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_INK)
      Text('当一件事值得持续推进时，可以把它记在这里。')
        .fontSize(14)
        .fontColor(COLOR_MUTED)
        .lineHeight(21)
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 48, bottom: 48 })
    .margin({ top: 26 })
    .backgroundColor(COLOR_PANEL)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  build() {
    Scroll() {
      Column() {
        Text('心上事')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
        Text('那些值得持续记得、慢慢推进的事。')
          .fontSize(14)
          .fontColor(COLOR_MUTED)
          .lineHeight(21)
          .margin({ top: 6 })

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .width('100%')
            .fontSize(13)
            .fontColor(COLOR_ACCENT)
            .lineHeight(20)
            .padding(12)
            .backgroundColor(COLOR_ACCENT_SOFT)
            .borderRadius(12)
            .margin({ top: 18 })
        }

        if (this.isLoading) {
          this.LoadingState()
        } else if (this.records.length === 0 && this.errorMessage.length === 0) {
          this.EmptyState()
        } else {
          if (this.grouped().active.length > 0) {
            this.SectionHeading('正在发生', this.grouped().active.length)
            ForEach(this.grouped().active, (record: BimRecord, index: number) => {
              this.RecordRow(record, index + 1)
            }, (record: BimRecord) => record.id)
          }

          if (this.grouped().quiet.length > 0) {
            this.SectionHeading('最近沉静', this.grouped().quiet.length)
            ForEach(this.grouped().quiet, (record: BimRecord, index: number) => {
              this.RecordRow(record, this.grouped().active.length + index + 1)
            }, (record: BimRecord) => record.id)
          }

          if (this.grouped().tucked.length > 0) {
            Column() {
              this.DisclosureRow(
                '已收起',
                this.grouped().tucked.length,
                this.showTucked,
                (): void => {
                  this.showTucked = !this.showTucked;
                }
              )
              if (this.showTucked) {
                ForEach(this.grouped().tucked, (record: BimRecord, index: number) => {
                  this.RecordRow(
                    record,
                    this.grouped().active.length + this.grouped().quiet.length + index + 1
                  )
                }, (record: BimRecord) => record.id)
              }
            }
            .width('100%')
            .margin({ top: 24 })
          }

          if (this.grouped().ended.length > 0) {
            Column() {
              this.DisclosureRow(
                '查看已结束',
                this.grouped().ended.length,
                this.showEnded,
                (): void => {
                  this.showEnded = !this.showEnded;
                }
              )
              if (this.showEnded) {
                ForEach(this.grouped().ended, (record: BimRecord, index: number) => {
                  this.RecordRow(record, index + 1)
                }, (record: BimRecord) => record.id)
              }
            }
            .width('100%')
            .opacity(0.82)
            .margin({ top: 12 })
          }
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: A2UI_HOME_MAX_WIDTH })
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: A2UI_HOME_PAGE_PADDING_X,
        right: A2UI_HOME_PAGE_PADDING_X,
        top: A2UI_HOME_PAGE_PADDING_TOP + 8,
        bottom: A2UI_HOME_PAGE_PADDING_BOTTOM + 12
      })
      .transition(
        TransitionEffect
          .opacity(0)
          .combine(TransitionEffect.translate({ x: -16, y: 0, z: 0 }))
          .animation({
            duration: this.reduceMotion ? 0 : A2UI_MOTION_NORMAL_MS,
            curve: A2UI_MOTION_MOVE_CURVE
          })
      )
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(COLOR_PAGE)
  }
}
