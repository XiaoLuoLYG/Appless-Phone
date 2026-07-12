import { A2uiAction, A2uiGenericToolResultData, aiLogInfo, rideAmapWebKeyForUi } from '@loop/agent-core';
import { renderRideDriverMapHtml } from '../html/RideDriverMapHtmlRenderer';
import {
  RideEstimateCard,
  RideToolPanelState,
  buildRideToolPanelState
} from '../state/RideToolResultsState';
import {
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_FIELD,
  COLOR_INK,
  COLOR_LINE,
  COLOR_MUTED,
  COLOR_TEXT,
  COLOR_WARNING_SOFT
} from '../style/A2uiHomeTheme';
import { a2uiEnterTransition } from '../style/A2uiHomeMotion';
import { ActionBarView } from './ActionBarView';
import { A2uiWebSurfaceView } from './common/A2uiWebSurfaceView';
import { A2uiWebMessage, A2uiWebMessageValue } from './common/A2uiWebBridge';

const RIDE_GREEN: string = '#1F7A61';
const RIDE_GREEN_DARK: string = '#155C49';
const RIDE_GREEN_SOFT: string = '#E5F2EC';
const RIDE_GREEN_LINE: string = '#B9D9CB';
const RIDE_BLUE: string = '#356FA3';
const RIDE_BLUE_SOFT: string = '#E7F0F7';
const RIDE_DANGER: string = '#A43B46';
const RIDE_DANGER_SOFT: string = '#F8E3E6';
const RIDE_SURFACE: string = '#F4F8F5';
const RIDE_ROUTE: string = '#D8E8DE';

@Component
export struct RideToolResultsView {
  @Prop results: A2uiGenericToolResultData[] = [];
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};
  @State private rideMapEtaText: string = '';
  @State private rideMapEtaOrderId: string = '';

  private panel(): RideToolPanelState {
    return buildRideToolPanelState(this.results);
  }

  private stageLabel(panel: RideToolPanelState): string {
    if (panel.stage === 'estimate') {
      return '待确认';
    }
    if (panel.stage === 'order_submitted') {
      return '等司机';
    }
    if (panel.stage === 'driver_location') {
      return panel.showDriverMarker ? '司机已定位' : '待定位';
    }
    if (panel.stage === 'cancelled') {
      return '已取消';
    }
    return '需处理';
  }

  private stageTone(panel: RideToolPanelState): string {
    if (panel.stage === 'cancelled' || panel.stage === 'error') {
      return RIDE_DANGER;
    }
    if (panel.stage === 'driver_location') {
      return RIDE_BLUE;
    }
    return RIDE_GREEN_DARK;
  }

  private stageBackground(panel: RideToolPanelState): string {
    if (panel.stage === 'cancelled' || panel.stage === 'error') {
      return RIDE_DANGER_SOFT;
    }
    if (panel.stage === 'driver_location') {
      return RIDE_BLUE_SOFT;
    }
    return RIDE_GREEN_SOFT;
  }

  private hasDetails(panel: RideToolPanelState): boolean {
    return panel.orderId.length > 0 ||
      panel.statusText.length > 0 ||
      panel.driverName.length > 0 ||
      panel.driverEtaText.length > 0 ||
      panel.sourceText.length > 0;
  }

  private dangerActions(panel: RideToolPanelState): A2uiAction[] {
    const actions: A2uiAction[] = [];
    panel.destructiveActions.forEach((action: A2uiAction) => {
      actions.push({
        id: action.id,
        label: action.label,
        prompt: action.prompt,
        kind: action.kind,
        variant: 'danger',
        args: action.args
      });
    });
    return actions;
  }

  private canShowMap(panel: RideToolPanelState): boolean {
    return panel.stage === 'driver_location' &&
      panel.showDriverMarker &&
      panel.pickupLocation.length > 0 &&
      panel.driverLocation.length > 0;
  }

  private rideMapHtml(panel: RideToolPanelState): string {
    return renderRideDriverMapHtml({
      routeText: panel.routeText,
      pickupLocation: panel.pickupLocation,
      driverLocation: panel.driverLocation,
      driverName: panel.driverName,
      etaText: panel.driverEtaText.length > 0 ? panel.driverEtaText : panel.visualLabel,
      amapKey: rideAmapWebKeyForUi(),
      amapSecurityJsCode: ''
    });
  }

  private messageText(value: A2uiWebMessageValue): string {
    if (value === null || value === undefined) {
      return '';
    }
    return String(value).trim();
  }

  private onRideMapMessage(panel: RideToolPanelState, message: A2uiWebMessage): void {
    const messageType = this.messageText(message['type']);
    if (messageType === 'rideMapRouteLog') {
      aiLogInfo('[AIPhone][RideMapRoute] ' + JSON.stringify({
        orderId: panel.orderId,
        stage: this.messageText(message['stage']),
        detail: message['detail']
      }));
      return;
    }
    if (messageType !== 'rideMapEta') {
      return;
    }
    const etaText = this.messageText(message['etaText']);
    if (etaText.length === 0) {
      return;
    }
    this.rideMapEtaText = etaText;
    this.rideMapEtaOrderId = panel.orderId;
  }

  private driverEtaText(panel: RideToolPanelState): string {
    if (this.rideMapEtaText.length > 0 && this.rideMapEtaOrderId === panel.orderId) {
      return this.rideMapEtaText;
    }
    if (panel.driverEtaText.length > 0) {
      return panel.driverEtaText;
    }
    return panel.showDriverMarker ? '正在估算' : '';
  }

  @Builder
  private RouteDot(label: string, color: string) {
    Text(label)
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .textAlign(TextAlign.Center)
      .height(28)
      .padding({ left: 10, right: 10 })
      .backgroundColor(color)
      .borderRadius(14)
  }

  @Builder
  private RouteVisual(panel: RideToolPanelState) {
    if (this.canShowMap(panel)) {
      A2uiWebSurfaceView({
        mode: 'html',
        html: this.rideMapHtml(panel),
        baseUrl: 'https://aiphone.local/ride-map/',
        bridgeName: 'AIPhoneRideMap',
        allowPopup: false,
        onMessage: (message: A2uiWebMessage): void => {
          this.onRideMapMessage(panel, message);
        }
      })
        .width('100%')
        .height(220)
        .borderRadius(18)
        .clip(true)
        .border({ width: 1, color: RIDE_GREEN_LINE })
    } else {
      Column() {
      if (panel.showDriverMarker) {
        Row() {
          this.RouteDot('乘客', RIDE_GREEN)

          Stack() {
            Text('')
              .width('100%')
              .height(3)
              .backgroundColor('#A7CDBC')
              .borderRadius(2)

            Column() {
              Text('司机')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .textAlign(TextAlign.Center)
                .width(36)
                .height(24)
                .backgroundColor(RIDE_BLUE)
                .borderRadius(12)
            }
            .width(36)
            .height(24)
            .margin({ right: 78 })
          }
          .layoutWeight(1)
          .height(36)
          .margin({ left: 12, right: 12 })

          this.RouteDot('目的地', COLOR_INK)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      } else {
        Column() {
          Text(panel.stage === 'estimate' ? '路线摘要' : '位置待查询')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(RIDE_GREEN_DARK)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#FFFFFFD9')
            .borderRadius(12)

          Text(panel.routeText.length > 0 ? panel.routeText : panel.visualLabel)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 14 })

          Text('未查询到司机坐标前不展示地图或真实路线')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }

      Text(panel.visualLabel)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(panel.showDriverMarker ? RIDE_BLUE : COLOR_MUTED)
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .margin({ top: panel.showDriverMarker ? 26 : 16 })
        .backgroundColor('#FFFFFFD9')
        .borderRadius(13)
    }
    .width('100%')
    .height(152)
    .padding({ left: 20, right: 20, top: 28, bottom: 16 })
    .backgroundColor(RIDE_ROUTE)
    .borderRadius(18)
    .border({ width: 1, color: RIDE_GREEN_LINE })
    }
  }

  @Builder
  private EstimateCard(card: RideEstimateCard, index: number) {
    Column() {
      Row() {
        Text(index === 0 ? '推荐' : (card.category.length > 0 ? card.category : '可选'))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(index === 0 ? RIDE_GREEN_DARK : COLOR_MUTED)
          .padding({ left: 7, right: 7, top: 4, bottom: 4 })
          .backgroundColor(index === 0 ? RIDE_GREEN_SOFT : COLOR_FIELD)
          .borderRadius(7)
        Blank()
      }
      .width('100%')

      Text(card.name)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 10 })

      Text(card.priceText)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(index === 0 ? RIDE_GREEN_DARK : COLOR_TEXT)
        .width('100%')
        .margin({ top: 5 })
    }
    .width('100%')
    .height(118)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(index === 0 ? COLOR_CARD : '#FFFFFFCC')
    .borderRadius(14)
    .border({ width: 1, color: index === 0 ? RIDE_GREEN_LINE : COLOR_CARD_EDGE })
  }

  @Builder
  private DetailRow(label: string, value: string) {
    if (value.length > 0) {
      Row() {
        Text(label)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .width(76)
        Text(value)
          .fontSize(13)
          .fontColor(COLOR_TEXT)
          .lineHeight(19)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ top: 8, bottom: 8 })
      .border({ width: { bottom: 1 }, color: COLOR_LINE })
    }
  }

  @Builder
  private Details(panel: RideToolPanelState) {
    if (this.hasDetails(panel)) {
      Column() {
        this.DetailRow('订单号', panel.orderId)
        this.DetailRow('状态', panel.statusText)
        this.DetailRow('司机', panel.driverName)
        this.DetailRow('预计接驾时间', this.driverEtaText(panel))
        this.DetailRow('来源', panel.sourceText)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })
      .margin({ top: 14 })
      .backgroundColor(COLOR_CARD)
      .borderRadius(14)
      .border({ width: 1, color: COLOR_CARD_EDGE })
    }
  }

  @Builder
  private ProviderMessages(panel: RideToolPanelState) {
    if (panel.hasProviderError && panel.providerMessages.length > 0) {
      Column() {
        ForEach(panel.providerMessages, (message: string, index: number) => {
          Text(message)
            .fontSize(12)
            .fontColor(RIDE_DANGER)
            .lineHeight(18)
            .width('100%')
            .margin({ top: index === 0 ? 0 : 6 })
        }, (message: string, index: number) => message + index.toString())
      }
      .width('100%')
      .padding(12)
      .margin({ top: 12 })
      .backgroundColor(RIDE_DANGER_SOFT)
      .borderRadius(12)
    }
  }

  @Builder
  private SafetyNote(panel: RideToolPanelState) {
    if (panel.safetyText.length > 0) {
      Text(panel.safetyText)
        .fontSize(12)
        .fontColor(panel.stage === 'estimate' ? '#7A4A00' : COLOR_MUTED)
        .lineHeight(18)
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .margin({ top: 12 })
        .backgroundColor(panel.stage === 'estimate' ? COLOR_WARNING_SOFT : COLOR_FIELD)
        .borderRadius(12)
        .border({ width: 1, color: panel.stage === 'estimate' ? '#E6CF92' : COLOR_LINE })
    }
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('Appless Ride')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_MUTED)
          Text(this.panel().title)
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.stageLabel(this.panel()))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.stageTone(this.panel()))
          .padding({ left: 9, right: 9, top: 6, bottom: 6 })
          .backgroundColor(this.stageBackground(this.panel()))
          .borderRadius(10)
          .border({ width: 1, color: this.stageTone(this.panel()) })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.panel().routeText.length > 0) {
        Text(this.panel().routeText)
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 8 })
      }

      Column() {
        this.RouteVisual(this.panel())
      }
        .width('100%')
        .margin({ top: 14 })

      if (this.panel().estimateCards.length > 0) {
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
          ForEach(this.panel().estimateCards, (card: RideEstimateCard, index: number) => {
            Column() {
              this.EstimateCard(card, index)
            }
              .width('48%')
              .margin({ right: index % 2 === 0 ? 10 : 0, bottom: 10 })
              .onClick(() => {
                if (this.isBusy || card.action === null) {
                  return;
                }
                this.onAction(card.action);
              })
          }, (card: RideEstimateCard, index: number) => card.name + card.priceText + index.toString())
        }
        .width('100%')
        .margin({ top: 14 })
      }

      this.Details(this.panel())
      this.ProviderMessages(this.panel())
      this.SafetyNote(this.panel())

      if (this.panel().primaryActions.length > 0) {
        ActionBarView({
          actions: this.panel().primaryActions,
          isBusy: this.isBusy,
          onAction: this.onAction
        })
          .margin({ top: 12 })
      }

      if (this.panel().handoffActions.length > 0) {
        ActionBarView({
          actions: this.panel().handoffActions,
          isBusy: this.isBusy,
          onAction: this.onAction
        })
          .margin({ top: 6 })
      }

      if (this.panel().destructiveActions.length > 0) {
        ActionBarView({
          actions: this.dangerActions(this.panel()),
          isBusy: this.isBusy,
          onAction: this.onAction
        })
          .margin({ top: 6 })
      }

      if (this.panel().secondaryActions.length > 0) {
        ActionBarView({
          actions: this.panel().secondaryActions,
          isBusy: this.isBusy,
          onAction: this.onAction
        })
          .margin({ top: 6 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 2, right: 2, top: 14, bottom: 2 })
    .transition(a2uiEnterTransition())
  }
}
