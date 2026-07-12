import { describe, it, expect } from '@ohos/hypium';
import { A2uiAction, A2uiGenericToolResultData } from '@loop/agent-core';
import {
  RideToolPanelState,
  buildRideToolPanelState,
  isRideToolResult
} from '../main/ets/pages/A2uiHome/state/RideToolResultsState';

function row(label: string, value: string): { label: string; value: string } {
  return { label: label, value: value };
}

function action(id: string, label: string, prompt: string = id, variant: string = 'secondary'): A2uiAction {
  return {
    id: id,
    label: label,
    prompt: prompt,
    kind: id.indexOf('open') >= 0 ? 'client' : 'prompt',
    variant: variant
  };
}

function result(
  toolName: string,
  title: string,
  rows: Array<{ label: string; value: string }>,
  actions: A2uiAction[] = [],
  status: string = 'success',
  summary: string = 'summary'
): A2uiGenericToolResultData {
  return {
    sourceTag: toolName.indexOf('amap') >= 0 ? '高德' : '滴滴',
    toolName: toolName,
    title: title,
    status: status,
    summary: summary,
    rows: rows,
    rawPreview: '',
    actions: actions
  };
}

export default function rideToolResultsStateTest() {
  describe('rideToolResultsState', () => {
    it('recognizes only ride tool results', 0, () => {
      expect(isRideToolResult(result('ride.estimate', '滴滴价格预估', []))).assertTrue();
      expect(isRideToolResult(result('ride.app.link', 'App 打车链接', []))).assertTrue();
      expect(isRideToolResult(result('maps.place.search', 'Google Maps', []))).assertFalse();
    });

    it('builds query state with route summary, estimates, and app handoff without driver map', 0, () => {
      const panel: RideToolPanelState = buildRideToolPanelState([
        result('ride.estimate', '滴滴价格预估', [
          row('路线', '深圳湾万象城 → 深圳北站'),
          row('起点坐标', '113.942111,22.528222'),
          row('终点坐标', '114.029506,22.609878'),
          row('快车（express）', '约 48 元'),
          row('专车（premium）', '约 88 元')
        ], [
          action('ride.order.confirm', '确认叫快车', '确认下单：快车 约 48 元', 'primary')
        ]),
        result('ride.app.link', 'App 打车链接', [
          row('路线', '深圳湾万象城 → 深圳北站'),
          row('滴滴链接', 'diditaxi://ride?traceId=trace-123'),
          row('高德链接', 'amapuri://drive/takeTaxi?sourceApplication=aiphone')
        ], [
          action('ride.open.didi', '打开滴滴', 'diditaxi://ride?traceId=trace-123', 'primary'),
          action('ride.open.amap', '打开高德', 'amapuri://drive/takeTaxi?sourceApplication=aiphone')
        ])
      ]);

      expect(panel.stage).assertEqual('estimate');
      expect(panel.title).assertEqual('去深圳北站');
      expect(panel.routeText).assertEqual('深圳湾万象城 → 深圳北站');
      expect(panel.pickupLocation).assertEqual('113.942111,22.528222');
      expect(panel.destinationLocation).assertEqual('114.029506,22.609878');
      expect(panel.estimateCards.length).assertEqual(2);
      expect(panel.estimateCards[0].name).assertEqual('快车');
      expect(panel.estimateCards[0].priceText).assertEqual('约 48 元');
      expect(panel.primaryActions.length).assertEqual(1);
      expect(panel.primaryActions[0].id).assertEqual('ride.order.confirm');
      expect(panel.handoffActions.length).assertEqual(2);
      expect(panel.handoffActions[0].id).assertEqual('ride.open.didi');
      expect(panel.handoffActions[1].id).assertEqual('ride.open.amap');
      expect(panel.showDriverMarker).assertFalse();
      expect(panel.visualLabel).assertEqual('路线摘要，不画真实路线');
    });

    it('keeps submitted order in waiting state before driver location is refreshed', 0, () => {
      const panel: RideToolPanelState = buildRideToolPanelState([
        result('ride.order.create', '滴滴订单已提交', [
          row('车型', 'express'),
          row('订单号', 'order-123'),
          row('状态', 'submitted')
        ], [
          action('ride.driver.location.refresh', '刷新司机位置', '刷新滴滴司机位置', 'primary'),
          action('ride.order.cancel', '取消订单', '取消滴滴打车订单')
        ])
      ]);

      expect(panel.stage).assertEqual('order_submitted');
      expect(panel.orderId).assertEqual('order-123');
      expect(panel.statusText).assertEqual('submitted');
      expect(panel.selectedVehicleText).assertEqual('express');
      expect(panel.primaryActions[0].id).assertEqual('ride.driver.location.refresh');
      expect(panel.destructiveActions[0].id).assertEqual('ride.order.cancel');
      expect(panel.showDriverMarker).assertFalse();
      expect(panel.visualLabel).assertEqual('司机位置未查询');
    });

    it('keeps selected vehicle after driver location is returned', 0, () => {
      const panel: RideToolPanelState = buildRideToolPanelState([
        result('ride.order.create', '滴滴订单已提交', [
          row('车型', '专车'),
          row('订单号', 'order-123'),
          row('状态', 'submitted')
        ], []),
        result('ride.driver.location', '滴滴司机位置', [
          row('订单号', 'order-123'),
          row('司机位置', '114.060000,22.540000'),
          row('状态', 'driver_arriving')
        ], [])
      ]);

      expect(panel.stage).assertEqual('driver_location');
      expect(panel.selectedVehicleText).assertEqual('专车');
      expect(panel.showDriverMarker).assertTrue();
    });

    it('shows driver marker only after driver coordinates are returned', 0, () => {
      const panel: RideToolPanelState = buildRideToolPanelState([
        result('ride.driver.location', '滴滴司机位置', [
          row('订单号', 'order-123'),
          row('司机位置', '114.060000,22.540000'),
          row('司机', '李师傅'),
          row('预计接驾时间', '预计 5 分钟接驾'),
          row('状态', 'driver_arriving')
        ], [
          action('ride.driver.location.refresh', '刷新司机位置', '刷新滴滴司机位置', 'primary'),
          action('ride.order.cancel', '取消订单', '取消滴滴打车订单')
        ])
      ]);

      expect(panel.stage).assertEqual('driver_location');
      expect(panel.orderId).assertEqual('order-123');
      expect(panel.driverLocation).assertEqual('114.060000,22.540000');
      expect(panel.driverName).assertEqual('李师傅');
      expect(panel.driverEtaText).assertEqual('预计 5 分钟接驾');
      expect(panel.showDriverMarker).assertTrue();
      expect(panel.visualLabel).assertEqual('司机正在前往');
      expect(panel.safetyText).assertEqual('');
    });

    it('restores route and pickup coordinate from driver location result for map rendering', 0, () => {
      const panel: RideToolPanelState = buildRideToolPanelState([
        result('ride.driver.location', '滴滴司机位置', [
          row('订单号', 'order-123'),
          row('路线', '华为坂田基地 → 秋港花园'),
          row('起点坐标', '114.066231,22.657805'),
          row('终点坐标', '114.060432,22.548829'),
          row('司机位置', '114.060000,22.650000')
        ], [
          action('ride.driver.location.refresh', '刷新司机位置', '刷新滴滴司机位置', 'primary')
        ])
      ]);

      expect(panel.stage).assertEqual('driver_location');
      expect(panel.routeText).assertEqual('华为坂田基地 → 秋港花园');
      expect(panel.pickupLocation).assertEqual('114.066231,22.657805');
      expect(panel.destinationLocation).assertEqual('114.060432,22.548829');
      expect(panel.driverLocation).assertEqual('114.060000,22.650000');
      expect(panel.showDriverMarker).assertTrue();
    });

    it('shows driver marker for Didi sandbox text coordinates after gateway parsing', 0, () => {
      const panel: RideToolPanelState = buildRideToolPanelState([
        result('ride.driver.location', '滴滴司机位置', [
          row('订单号', 'order-123'),
          row('司机位置', '116.297345,39.882325'),
          row('来源', '滴滴 taxi_get_driver_location（sandbox mock）')
        ], [
          action('ride.driver.location.refresh', '刷新司机位置', '刷新滴滴司机位置', 'primary'),
          action('ride.order.cancel', '取消订单', '取消滴滴打车订单')
        ], 'success', '已返回司机当前位置。')
      ]);

      expect(panel.stage).assertEqual('driver_location');
      expect(panel.driverLocation).assertEqual('116.297345,39.882325');
      expect(panel.showDriverMarker).assertTrue();
      expect(panel.visualLabel).assertEqual('司机正在前往');
    });

    it('does not show driver marker when location result contains only status', 0, () => {
      const panel: RideToolPanelState = buildRideToolPanelState([
        result('ride.driver.location', '滴滴司机位置', [
          row('订单号', 'order-123'),
          row('状态', 'driver_arriving')
        ], [
          action('ride.driver.location.refresh', '刷新司机位置', '刷新滴滴司机位置', 'primary')
        ])
      ]);

      expect(panel.stage).assertEqual('driver_location');
      expect(panel.showDriverMarker).assertFalse();
      expect(panel.statusText).assertEqual('driver_arriving');
      expect(panel.visualLabel).assertEqual('司机位置未返回');
    });

    it('keeps driver location stage when provider returns no coordinate fields', 0, () => {
      const panel: RideToolPanelState = buildRideToolPanelState([
        result('ride.driver.location', '滴滴司机位置', [
          row('订单号', 'order-123'),
          row('来源', '滴滴 taxi_get_driver_location（sandbox mock）')
        ], [
          action('ride.driver.location.refresh', '刷新司机位置', '刷新滴滴司机位置', 'primary')
        ], 'success', '已调用滴滴 sandbox mock 刷新司机位置接口，但响应里没有可展示的位置。')
      ]);

      expect(panel.stage).assertEqual('driver_location');
      expect(panel.orderId).assertEqual('order-123');
      expect(panel.showDriverMarker).assertFalse();
      expect(panel.visualLabel).assertEqual('司机位置未返回');
    });

    it('keeps cancellation final and avoids invented fees', 0, () => {
      const panel: RideToolPanelState = buildRideToolPanelState([
        result('ride.driver.location', '滴滴司机位置', [
          row('订单号', 'order-123'),
          row('司机位置', '116.297345,39.882325')
        ], [
          action('ride.driver.location.refresh', '刷新司机位置', '刷新滴滴司机位置', 'primary'),
          action('ride.order.cancel', '取消订单', '取消滴滴打车订单')
        ]),
        result('ride.order.cancel', '滴滴订单已取消', [
          row('订单号', 'order-123'),
          row('原因', '用户取消'),
          row('状态', 'cancelled')
        ], [
          action('ride.query.retry', '重新查询', '重新查询打车方案', 'primary'),
          action('ride.vehicle.change', '换车型', '换车型重新叫车')
        ], 'success', '已调用滴滴 sandbox mock 取消订单接口。')
      ]);

      expect(panel.stage).assertEqual('cancelled');
      expect(panel.orderId).assertEqual('order-123');
      expect(panel.statusText).assertEqual('cancelled');
      expect(panel.safetyText.indexOf('费用')).assertEqual(-1);
      expect(panel.destructiveActions.length).assertEqual(0);
      expect(panel.primaryActions.length).assertEqual(1);
      expect(panel.primaryActions[0].label).assertEqual('重新查询');
      expect(panel.secondaryActions.length).assertEqual(1);
      expect(panel.secondaryActions[0].label).assertEqual('换车型');
    });
  });
}
