import { A2uiAction, A2uiGenericToolResultData, A2uiGenericToolResultRowData } from '@loop/agent-core';

export type RideToolStage = 'estimate' | 'order_submitted' | 'driver_location' | 'cancelled' | 'error';

export interface RideEstimateCard {
  name: string;
  category: string;
  priceText: string;
  action: A2uiAction | null;
}

export interface RideToolPanelState {
  stage: RideToolStage;
  title: string;
  subtitle: string;
  routeText: string;
  pickupLocation: string;
  destinationLocation: string;
  selectedVehicleText: string;
  visualLabel: string;
  estimateCards: RideEstimateCard[];
  primaryActions: A2uiAction[];
  handoffActions: A2uiAction[];
  destructiveActions: A2uiAction[];
  secondaryActions: A2uiAction[];
  orderId: string;
  statusText: string;
  driverLocation: string;
  driverName: string;
  driverEtaText: string;
  sourceText: string;
  safetyText: string;
  showDriverMarker: boolean;
  hasProviderError: boolean;
  providerMessages: string[];
}

interface RideEstimateLabelParts {
  name: string;
  category: string;
}

function emptyPanel(): RideToolPanelState {
  return {
    stage: 'estimate',
    title: '打车',
    subtitle: '',
    routeText: '',
    pickupLocation: '',
    destinationLocation: '',
    selectedVehicleText: '',
    visualLabel: '路线摘要，不画真实路线',
    estimateCards: [],
    primaryActions: [],
    handoffActions: [],
    destructiveActions: [],
    secondaryActions: [],
    orderId: '',
    statusText: '',
    driverLocation: '',
    driverName: '',
    driverEtaText: '',
    sourceText: '',
    safetyText: '打开滴滴/高德不会自动下单。',
    showDriverMarker: false,
    hasProviderError: false,
    providerMessages: []
  };
}

export function isRideToolResult(item: A2uiGenericToolResultData): boolean {
  return item.toolName.indexOf('ride.') === 0;
}

function rowValue(item: A2uiGenericToolResultData, label: string): string {
  for (let index = 0; index < item.rows.length; index++) {
    if (item.rows[index].label === label) {
      return item.rows[index].value.trim();
    }
  }
  return '';
}

function firstRowValue(item: A2uiGenericToolResultData, labels: string[]): string {
  for (let index = 0; index < labels.length; index++) {
    const value = rowValue(item, labels[index]);
    if (value.length > 0) {
      return value;
    }
  }
  return '';
}

function destinationFromRoute(routeText: string): string {
  const arrow = routeText.indexOf('→');
  if (arrow < 0) {
    return '';
  }
  const destination = routeText.substring(arrow + 1).trim();
  return destination.length > 0 ? destination : '';
}

function titleFromRoute(routeText: string): string {
  const destination = destinationFromRoute(routeText);
  return destination.length > 0 ? '去' + destination : '打车';
}

function splitEstimateLabel(label: string): RideEstimateLabelParts {
  const trimmed = label.trim();
  const open = trimmed.indexOf('（');
  const close = trimmed.indexOf('）');
  if (open > 0 && close > open) {
    return {
      name: trimmed.substring(0, open).trim(),
      category: trimmed.substring(open + 1, close).trim()
    };
  }
  return {
    name: trimmed,
    category: ''
  };
}

function actionForProduct(actions: A2uiAction[], productName: string): A2uiAction | null {
  for (let index = 0; index < actions.length; index++) {
    const action = actions[index];
    if (action.id === 'ride.order.confirm' &&
      (action.label.indexOf(productName) >= 0 || action.prompt.indexOf(productName) >= 0)) {
      return action;
    }
  }
  return null;
}

function estimateCards(item: A2uiGenericToolResultData): RideEstimateCard[] {
  const cards: RideEstimateCard[] = [];
  const actions = item.actions === undefined ? [] : item.actions;
  item.rows.forEach((row: A2uiGenericToolResultRowData) => {
    const label = row.label.trim();
    const value = row.value.trim();
    if (label === '路线' || label === '起点坐标' || label === '终点坐标' ||
      label === 'traceId' || label === '来源' || value.length === 0) {
      return;
    }
    const parts = splitEstimateLabel(label);
    cards.push({
      name: parts.name,
      category: parts.category,
      priceText: value,
      action: actionForProduct(actions, parts.name)
    });
  });
  return cards;
}

function isHandoffAction(action: A2uiAction): boolean {
  return action.id === 'ride.open.didi' ||
    action.id === 'ride.open.amap' ||
    (action.kind === 'client' && action.id.indexOf('open') >= 0);
}

function isDestructiveAction(action: A2uiAction): boolean {
  return action.id === 'ride.order.cancel' ||
    action.variant === 'destructive' ||
    action.variant === 'danger';
}

function isPrimaryAction(action: A2uiAction): boolean {
  return action.variant === 'primary' ||
    action.id === 'ride.order.confirm' ||
    action.id === 'ride.driver.location.refresh';
}

function appendAction(groups: RideToolPanelState, action: A2uiAction): void {
  if (isHandoffAction(action)) {
    groups.handoffActions.push(action);
    return;
  }
  if (isDestructiveAction(action)) {
    groups.destructiveActions.push(action);
    return;
  }
  if (isPrimaryAction(action)) {
    groups.primaryActions.push(action);
    return;
  }
  groups.secondaryActions.push(action);
}

function mergeActions(panel: RideToolPanelState, item: A2uiGenericToolResultData): void {
  if (item.actions === undefined) {
    return;
  }
  item.actions.forEach((action: A2uiAction) => appendAction(panel, action));
}

function clearActions(panel: RideToolPanelState): void {
  panel.primaryActions = [];
  panel.handoffActions = [];
  panel.destructiveActions = [];
  panel.secondaryActions = [];
}

function hasCoordinate(text: string): boolean {
  return /^-?\d+(?:\.\d+)?,\s*-?\d+(?:\.\d+)?$/.test(text.trim());
}

function rememberSource(panel: RideToolPanelState, item: A2uiGenericToolResultData): void {
  if (panel.sourceText.length === 0 && item.sourceTag.trim().length > 0) {
    panel.sourceText = item.sourceTag.trim();
  }
}

function rememberError(panel: RideToolPanelState, item: A2uiGenericToolResultData): void {
  if (item.status === 'success') {
    return;
  }
  panel.hasProviderError = true;
  const message = item.summary.trim().length > 0 ? item.summary.trim() : item.title.trim();
  if (message.length > 0) {
    panel.providerMessages.push(message);
  }
}

function applyEstimateResult(panel: RideToolPanelState, item: A2uiGenericToolResultData): void {
  panel.stage = panel.hasProviderError ? 'error' : 'estimate';
  panel.routeText = firstRowValue(item, ['路线']);
  panel.pickupLocation = firstRowValue(item, ['起点坐标', 'pickupLocation', 'originLocation']);
  panel.destinationLocation = firstRowValue(item, ['终点坐标', 'destinationLocation']);
  panel.title = titleFromRoute(panel.routeText);
  panel.subtitle = panel.routeText;
  panel.estimateCards = estimateCards(item);
  panel.showDriverMarker = false;
  panel.visualLabel = '路线摘要，不画真实路线';
}

function applyAppLinkResult(panel: RideToolPanelState, item: A2uiGenericToolResultData): void {
  const route = firstRowValue(item, ['路线']);
  const pickupLocation = firstRowValue(item, ['起点坐标', 'pickupLocation', 'originLocation']);
  const destinationLocation = firstRowValue(item, ['终点坐标', 'destinationLocation']);
  if (panel.routeText.length === 0 && route.length > 0) {
    panel.routeText = route;
    panel.title = titleFromRoute(route);
    panel.subtitle = route;
  }
  if (panel.pickupLocation.length === 0 && pickupLocation.length > 0) {
    panel.pickupLocation = pickupLocation;
  }
  if (panel.destinationLocation.length === 0 && destinationLocation.length > 0) {
    panel.destinationLocation = destinationLocation;
  }
}

function applyOrderCreateResult(panel: RideToolPanelState, item: A2uiGenericToolResultData): void {
  const route = firstRowValue(item, ['路线']);
  const pickupLocation = firstRowValue(item, ['起点坐标', 'pickupLocation', 'originLocation']);
  const destinationLocation = firstRowValue(item, ['终点坐标', 'destinationLocation']);
  const selectedVehicleText = firstRowValue(item, ['车型', 'vehicle', 'productName', 'productCategory']);
  panel.stage = item.status === 'success' ? 'order_submitted' : 'error';
  if (route.length > 0) {
    panel.routeText = route;
    panel.title = titleFromRoute(route);
    panel.subtitle = route;
  }
  if (pickupLocation.length > 0) {
    panel.pickupLocation = pickupLocation;
  }
  if (destinationLocation.length > 0) {
    panel.destinationLocation = destinationLocation;
  }
  if (selectedVehicleText.length > 0) {
    panel.selectedVehicleText = selectedVehicleText;
  }
  panel.orderId = firstRowValue(item, ['订单号', 'orderId', 'order_id']);
  panel.statusText = firstRowValue(item, ['状态', 'status']);
  panel.driverLocation = '';
  panel.showDriverMarker = false;
  panel.visualLabel = '司机位置未查询';
  panel.safetyText = '订单已提交后，会自动刷新司机位置。';
}

function applyDriverLocationResult(panel: RideToolPanelState, item: A2uiGenericToolResultData): void {
  const route = firstRowValue(item, ['路线']);
  const pickupLocation = firstRowValue(item, ['起点坐标', 'pickupLocation', 'originLocation']);
  const destinationLocation = firstRowValue(item, ['终点坐标', 'destinationLocation']);
  const selectedVehicleText = firstRowValue(item, ['车型', 'vehicle', 'productName', 'productCategory']);
  panel.stage = item.status === 'success' ? 'driver_location' : 'error';
  if (route.length > 0) {
    panel.routeText = route;
    panel.title = titleFromRoute(route);
    panel.subtitle = route;
  }
  if (pickupLocation.length > 0) {
    panel.pickupLocation = pickupLocation;
  }
  if (destinationLocation.length > 0) {
    panel.destinationLocation = destinationLocation;
  }
  if (selectedVehicleText.length > 0) {
    panel.selectedVehicleText = selectedVehicleText;
  }
  panel.orderId = firstRowValue(item, ['订单号', 'orderId', 'order_id']);
  panel.driverLocation = firstRowValue(item, ['司机位置']);
  panel.driverName = firstRowValue(item, ['司机']);
  panel.driverEtaText = firstRowValue(item, ['预计接驾时间', '接驾时间', 'ETA', 'eta', 'driverEta', 'driver_eta', 'estimatedArrivalTime', 'estimated_arrival_time']);
  panel.statusText = firstRowValue(item, ['状态', 'status']);
  panel.showDriverMarker = hasCoordinate(panel.driverLocation);
  panel.visualLabel = panel.showDriverMarker ? '司机正在前往' : '司机位置未返回';
  panel.safetyText = '';
}

function applyCancelResult(panel: RideToolPanelState, item: A2uiGenericToolResultData): void {
  clearActions(panel);
  mergeActions(panel, item);
  panel.stage = item.status === 'success' ? 'cancelled' : 'error';
  panel.orderId = firstRowValue(item, ['订单号', 'orderId', 'order_id']);
  panel.statusText = firstRowValue(item, ['状态', 'status']);
  panel.driverLocation = '';
  panel.showDriverMarker = false;
  panel.visualLabel = '订单已取消';
  panel.safetyText = '';
}

function applyResult(panel: RideToolPanelState, item: A2uiGenericToolResultData): void {
  rememberError(panel, item);
  mergeActions(panel, item);
  rememberSource(panel, item);
  if (item.toolName === 'ride.estimate') {
    applyEstimateResult(panel, item);
    return;
  }
  if (item.toolName === 'ride.app.link') {
    applyAppLinkResult(panel, item);
    return;
  }
  if (item.toolName === 'ride.order.create') {
    applyOrderCreateResult(panel, item);
    return;
  }
  if (item.toolName === 'ride.driver.location') {
    applyDriverLocationResult(panel, item);
    return;
  }
  if (item.toolName === 'ride.order.cancel') {
    applyCancelResult(panel, item);
  }
}

function dedupeActions(actions: A2uiAction[]): A2uiAction[] {
  const seen: Record<string, boolean> = {};
  const result: A2uiAction[] = [];
  actions.forEach((action: A2uiAction) => {
    const key = action.id + '|' + action.prompt;
    if (seen[key] === true) {
      return;
    }
    seen[key] = true;
    result.push(action);
  });
  return result;
}

export function buildRideToolPanelState(results: A2uiGenericToolResultData[]): RideToolPanelState {
  const panel = emptyPanel();
  results.forEach((item: A2uiGenericToolResultData) => {
    if (isRideToolResult(item)) {
      applyResult(panel, item);
    }
  });
  panel.primaryActions = dedupeActions(panel.primaryActions);
  panel.handoffActions = dedupeActions(panel.handoffActions);
  panel.destructiveActions = dedupeActions(panel.destructiveActions);
  panel.secondaryActions = dedupeActions(panel.secondaryActions);
  if (panel.routeText.length === 0 && panel.orderId.length > 0) {
    panel.title = panel.stage === 'cancelled' ? '订单已取消' : '打车订单';
  }
  return panel;
}
