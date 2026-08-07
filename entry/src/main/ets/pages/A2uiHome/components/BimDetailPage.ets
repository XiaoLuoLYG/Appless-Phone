import {
  A2uiAction,
  A2uiSurfaceState,
  LeaderBimDashboardItem
} from '@loop/agent-core';
import {
  BimContextSnapshot,
  BimRecord,
  bimDashboardSurfaceJsons,
  isValidBimSurfaceJson
} from '../bim/BimStore';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_ACCENT_SOFT,
  COLOR_BUTTON_TEXT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_ERROR,
  COLOR_ERROR_SOFT,
  COLOR_INK,
  COLOR_LINE,
  COLOR_MUTED,
  COLOR_PAGE,
  COLOR_PANEL,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import {
  A2UI_HOME_FLOATING_RADIUS,
  A2UI_HOME_MAX_WIDTH,
  A2UI_HOME_PAGE_PADDING_BOTTOM,
  A2UI_HOME_PAGE_PADDING_TOP,
  A2UI_HOME_PAGE_PADDING_X,
  A2UI_HOME_SECTION_GAP
} from '../style/A2uiHomeLayout';
import {
  A2UI_MOTION_MOVE_CURVE,
  A2UI_MOTION_NORMAL_MS
} from '../style/A2uiHomeMotion';
import { rootComponentIdOf } from '../render/A2uiRenderData';
import { bimDetailRenderKey } from '../bim/BimRuntime';
import { A2uiNodeView } from './A2uiNodeView';
import { BimDashboardView, BIM_DASHBOARD_SECTION_GAP } from './BimDashboardView';

@Component
export struct BimDetailPage {
  @Prop record: BimRecord;
  @Prop renderTick: number = 0;
  @Prop liveSurfaceJson: string = '';
  @Prop isBusy: boolean = false;
  @Prop isInputEnabled: boolean = true;
  @Prop isLoading: boolean = false;
  @Prop workingText: string = '';
  @Prop errorMessage: string = '';
  @Prop reduceMotion: boolean = false;
  @Link inputText: string;
  @State backPressed: boolean = false;
  onBack: () => void = () => {};
  onSubmit: (bimId: string, text: string) => void =
    (_bimId: string, _text: string): void => {};
  onStop: (bimId: string) => void = (_bimId: string): void => {};
  onAction: (action: A2uiAction) => void = (_action: A2uiAction): void => {};
  onMarkEnded: (bimId: string) => void = (_bimId: string): void => {};
  onReactivate: (bimId: string) => void = (_bimId: string): void => {};
  onDelete: (bimId: string) => void = (_bimId: string): void => {};

  private surfaces(): A2uiSurfaceState[] {
    const surfaces: A2uiSurfaceState[] = [];
    const values = bimDashboardSurfaceJsons(this.record, this.liveSurfaceJson);
    for (let index = 0; index < values.length; index++) {
      if (!isValidBimSurfaceJson(values[index])) continue;
      try {
        const surface = JSON.parse(values[index]) as A2uiSurfaceState;
        if (surface.intent !== 'bim') surfaces.push(surface);
      } catch (_error) {
      }
    }
    return surfaces;
  }

  private context(): BimContextSnapshot | null {
    try {
      const context = JSON.parse(this.record.contextJson) as BimContextSnapshot;
      if (typeof context.summary !== 'string' ||
        !Array.isArray(context.constraints) ||
        !Array.isArray(context.facts) ||
        !Array.isArray(context.decisions)) {
        return null;
      }
      return context;
    } catch (_error) {
      return null;
    }
  }

  private summary(): string {
    const context = this.context();
    return context === null ? this.record.retrievalIndex.summary : context.summary;
  }

  private constraints(): string[] {
    const context = this.context();
    return context === null ? [] : context.constraints;
  }

  private facts(): string[] {
    const context = this.context();
    return context === null ? [] : context.facts;
  }

  private decisions(): string[] {
    const context = this.context();
    return context === null ? [] : context.decisions;
  }

  private dashboardItems(): LeaderBimDashboardItem[] {
    const context = this.context();
    return context === null || context.dashboardItems === undefined ? [] : context.dashboardItems;
  }

  private surfaceLabel(surface: A2uiSurfaceState): string {
    const intent = surface.intent.toLowerCase();
    if (intent.indexOf('hotel') >= 0) return '酒店';
    if (intent.indexOf('flight') >= 0) return '航班';
    if (intent.indexOf('train') >= 0) return '高铁';
    if (intent.indexOf('travel') >= 0) return '行程';
    if (intent.indexOf('calendar') >= 0) return '日程';
    if (intent.indexOf('food') >= 0) return '餐饮';
    if (intent.indexOf('ride') >= 0 || intent.indexOf('maps') >= 0) return '当地出行';
    if (intent.indexOf('mail') >= 0) return '邮件';
    return surface.title.trim().length > 0 ? surface.title : '最新进展';
  }

  private isEnded(): boolean {
    return this.record.lifecycle === 'ended';
  }

  private lifecycleLabel(): string {
    if (this.record.lifecycle === 'active') {
      return '进行中';
    }
    if (this.record.lifecycle === 'quiet') {
      return '沉静';
    }
    if (this.record.lifecycle === 'tucked') {
      return '已收起';
    }
    return '已结束';
  }

  private canSubmit(): boolean {
    return this.isInputEnabled && !this.isBusy && !this.isEnded() && this.inputText.trim().length > 0;
  }

  private workingLabel(): string {
    const value = this.workingText.trim();
    return value.length > 0 ? value : '正在更新心上事';
  }

  private handleBackTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.backPressed = true;
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.backPressed = false;
    }
  }

  @Builder
  private Header() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Image($r('app.media.icon_back'))
          .width(20)
          .height(20)
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor(this.backPressed ? COLOR_ACCENT_SOFT : '#00000000')
      .scale({
        x: !this.reduceMotion && this.backPressed ? 0.97 : 1,
        y: !this.reduceMotion && this.backPressed ? 0.97 : 1
      })
      .animation({ duration: this.reduceMotion ? 0 : 120, curve: Curve.EaseOut })
      .accessibilityText('返回心上事列表')
      .onTouch((event: TouchEvent) => {
        this.handleBackTouch(event);
      })
      .onClick(() => {
        this.onBack();
      })

      Column() {
        Text(this.record.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.lifecycleLabel())
          .fontSize(11)
          .fontColor(this.isEnded() ? COLOR_MUTED : COLOR_ACCENT)
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 4, right: 8 })

      if (this.isEnded()) {
        Button('重新放回心上')
          .height(44)
          .width(104)
          .fontSize(12)
          .fontColor(COLOR_BUTTON_TEXT)
          .backgroundColor(COLOR_ACCENT_DEEP)
          .borderRadius(12)
          .enabled(!this.isBusy && this.isInputEnabled)
          .onClick(() => {
            if (!this.isBusy && this.isInputEnabled) {
              this.onReactivate(this.record.id);
            }
          })
        Button('删除')
          .width(58)
          .height(44)
          .fontSize(12)
          .fontColor('#9B3F3B')
          .backgroundColor(COLOR_CARD)
          .borderRadius(12)
          .border({ width: 1, color: '#E6B7B3' })
          .margin({ left: 6 })
          .enabled(!this.isBusy && this.isInputEnabled)
          .onClick(() => {
            if (!this.isBusy && this.isInputEnabled) {
              this.onDelete(this.record.id);
            }
          })
      } else {
        Button('结束')
          .width(58)
          .height(44)
          .fontSize(12)
          .fontColor(COLOR_TEXT)
          .backgroundColor(COLOR_CARD)
          .borderRadius(12)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .enabled(!this.isBusy && this.isInputEnabled)
          .onClick(() => {
            if (!this.isBusy && this.isInputEnabled) {
              this.onMarkEnded(this.record.id);
            }
          })
      }
    }
    .width('100%')
    .height(52)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private CurrentStateHeader() {
    Column() {
      Row() {
        Text('事情概览')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_MUTED)
        Blank()
        Text(
          this.facts().length.toString() + ' 条信息  ' +
          this.constraints().length.toString() + ' 项要求'
        )
          .fontSize(11)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')

      Text(this.summary())
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
        .lineHeight(26)
        .margin({ top: 11 })

      if (this.record.retrievalIndex.locations.length > 0 ||
        this.record.retrievalIndex.timeAnchors.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(
            this.record.retrievalIndex.locations.concat(this.record.retrievalIndex.timeAnchors),
            (item: string) => {
              Text(item)
                .fontSize(11)
                .fontColor(COLOR_TEXT)
                .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                .backgroundColor(COLOR_CARD)
                .borderRadius(9)
                .border({ width: 1, color: COLOR_CARD_EDGE })
                .margin({ right: 6, top: 7 })
            },
            (item: string) => item
          )
        }
        .width('100%')
        .margin({ top: 5 })
      }

      this.StateGroup('基本信息', this.facts())
      this.StateGroup('要求与边界', this.constraints())
      this.StateGroup('已经决定', this.decisions())
      this.StateGroup('接下来', this.record.retrievalIndex.commitments)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 15, bottom: 15 })
    .backgroundColor(COLOR_PANEL)
    .border({ width: { left: 3 }, color: COLOR_ACCENT })
    .borderRadius(16)
    .margin({ top: BIM_DASHBOARD_SECTION_GAP })
  }

  @Builder
  private StateGroup(title: string, items: string[]) {
    if (items.length > 0) {
      Column() {
        Text(title)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_MUTED)
          .margin({ bottom: 3 })
        ForEach(items, (item: string) => {
          Row() {
            Text('·')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_ACCENT)
              .width(14)
            Text(item)
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .lineHeight(20)
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .margin({ top: 4 })
        }, (item: string) => title + '-' + item)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 12 })
      .margin({ top: 12 })
      .border({ width: { top: 1 }, color: COLOR_LINE })
    }
  }

  @Builder
  private LoadingState() {
    Column() {
      Text('')
        .width('58%')
        .height(16)
        .backgroundColor(COLOR_CARD_EDGE)
        .borderRadius(5)
      Text('')
        .width('88%')
        .height(12)
        .backgroundColor(COLOR_LINE)
        .borderRadius(4)
        .margin({ top: 12 })
      Text('')
        .width('76%')
        .height(12)
        .backgroundColor(COLOR_LINE)
        .borderRadius(4)
        .margin({ top: 9 })
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 28 })
    .accessibilityText('正在载入当前状态')
  }

  @Builder
  private SurfaceContent() {
    if (this.isLoading) {
      this.LoadingState()
    } else if (this.surfaces().length === 0) {
      if (this.dashboardItems().length === 0) {
        Text('后续确认的进度、人物、酒店、航班和行程会统一显示在这里。')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .lineHeight(20)
        .width('100%')
        .padding({ top: 16 })
      }
    } else {
      Column() {
        ForEach(this.surfaces(), (surface: A2uiSurfaceState, index: number) => {
          if (surface.components.length > 0) {
            Column() {
              Row() {
                Text('已确认')
                  .fontSize(10)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(COLOR_ACCENT_DEEP)
                  .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                  .backgroundColor(COLOR_ACCENT_SOFT)
                  .borderRadius(6)
                Text(this.surfaceLabel(surface))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(COLOR_MUTED)
                  .margin({ left: 8 })
              }
              .width('100%')
              .margin({ bottom: 9 })

              A2uiNodeView({
                surface,
                componentId: rootComponentIdOf(surface),
                renderTick: surface.sequence,
                isBusy: this.isBusy || this.isEnded() || !this.isInputEnabled,
                onAction: (action: A2uiAction): void => {
                  if (this.isInputEnabled && !this.isBusy && !this.isEnded()) {
                    this.onAction(action);
                  }
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ top: 15 })
            .margin({ top: 12 })
            .border({ width: { top: 1 }, color: COLOR_LINE })
          }
        }, (surface: A2uiSurfaceState) =>
          surface.surfaceId + '-' + surface.sequence.toString()
        )
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private ErrorMessage() {
    if (this.errorMessage.length > 0) {
      Text(this.errorMessage)
        .width('100%')
        .fontSize(13)
        .fontColor(COLOR_ERROR)
        .lineHeight(20)
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .backgroundColor(COLOR_ERROR_SOFT)
        .borderRadius(10)
        .margin({ top: 8 })
    }
  }

  @Builder
  private Composer() {
    if (this.isEnded()) {
      Row() {
        Text('这件心上事已结束，重新放回心上后才可继续。')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .lineHeight(20)
          .layoutWeight(1)
      }
      .width('100%')
      .constraintSize({ minHeight: 56 })
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 9, bottom: 9 })
      .backgroundColor(COLOR_PANEL)
      .borderRadius(A2UI_HOME_FLOATING_RADIUS)
      .border({ width: 1, color: COLOR_CARD_EDGE })
    } else if (this.isBusy) {
      Row() {
        Column() {
          Text('正在处理')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_ACCENT)
          Text(this.workingLabel())
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ right: 12 })

        Button('停止')
          .width(58)
          .height(44)
          .fontSize(13)
          .fontColor(COLOR_BUTTON_TEXT)
          .backgroundColor(COLOR_ACCENT_DEEP)
          .borderRadius(12)
          .onClick(() => {
            this.onStop(this.record.id);
          })
      }
      .width('100%')
      .constraintSize({ minHeight: 64 })
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 8, top: 8, bottom: 8 })
      .backgroundColor(COLOR_CARD)
      .borderRadius(A2UI_HOME_FLOATING_RADIUS)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .shadow({ radius: 16, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 6 })
    } else if (!this.isInputEnabled) {
      Row() {
        Text('Appless 正在处理其他请求，完成后可继续。')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .lineHeight(20)
          .layoutWeight(1)
      }
      .width('100%')
      .constraintSize({ minHeight: 56 })
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 9, bottom: 9 })
      .backgroundColor(COLOR_PANEL)
      .borderRadius(A2UI_HOME_FLOATING_RADIUS)
      .border({ width: 1, color: COLOR_CARD_EDGE })
    } else {
      Row() {
        TextArea({
          placeholder: '继续问这件事',
          text: this.inputText
        })
          .constraintSize({ minHeight: 38, maxHeight: 80 })
          .layoutWeight(1)
          .fontSize(15)
          .fontColor(COLOR_TEXT)
          .placeholderColor(COLOR_MUTED)
          .lineHeight(22)
          .enterKeyType(EnterKeyType.Send)
          .backgroundColor('#00000000')
          .borderRadius(0)
          .border({ width: 0 })
          .padding({ left: 0, right: 0, top: 7, bottom: 7 })
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            if (this.canSubmit()) {
              this.onSubmit(this.record.id, this.inputText);
            }
          })

        Button('发送')
          .width(58)
          .height(44)
          .fontSize(13)
          .fontColor(COLOR_BUTTON_TEXT)
          .backgroundColor(COLOR_ACCENT_DEEP)
          .borderRadius(12)
          .enabled(this.canSubmit())
          .onClick(() => {
            if (this.canSubmit()) {
              this.onSubmit(this.record.id, this.inputText);
            }
          })
      }
      .width('100%')
      .constraintSize({ minHeight: 58 })
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 8, top: 7, bottom: 7 })
      .backgroundColor(COLOR_CARD)
      .borderRadius(A2UI_HOME_FLOATING_RADIUS)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .shadow({ radius: 16, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 6 })
    }
  }

  build() {
    Column() {
      this.Header()
      Scroll() {
        Column() {
          this.CurrentStateHeader()
          BimDashboardView({ items: this.dashboardItems(), renderTick: this.renderTick })
          this.SurfaceContent()
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .alignItems(HorizontalAlign.Start)
        .padding({ bottom: A2UI_HOME_SECTION_GAP })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      this.ErrorMessage()
      Column() {
        this.Composer()
      }
      .width('100%')
      .padding({ top: A2UI_HOME_SECTION_GAP })
    }
    .width('100%')
    .constraintSize({ maxWidth: A2UI_HOME_MAX_WIDTH })
    .height('100%')
    .padding({
      left: A2UI_HOME_PAGE_PADDING_X,
      right: A2UI_HOME_PAGE_PADDING_X,
      top: A2UI_HOME_PAGE_PADDING_TOP,
      bottom: A2UI_HOME_PAGE_PADDING_BOTTOM
    })
    .backgroundColor(COLOR_PAGE)
    .key(bimDetailRenderKey(this.record.id, this.renderTick))
    .transition(
      TransitionEffect
        .opacity(0)
        .combine(TransitionEffect.translate({ x: 16, y: 0, z: 0 }))
        .animation({
          duration: this.reduceMotion ? 0 : A2UI_MOTION_NORMAL_MS,
          curve: A2UI_MOTION_MOVE_CURVE
        })
    )
  }
}
