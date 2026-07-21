import {
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_TEXT,
  A2UI_VERSION,
  A2uiAction,
  A2uiComponent,
  A2uiEnvelope,
  A2uiLabelValueData
} from './A2uiTypes';
import { genericToolResultsA2ui } from './DynamicToolA2ui';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import {
  hotelActionsFor,
  hotelBookingOpenAction,
  validHotelBookingOpenArgs,
  HotelBookingOpenArgs
} from './HotelActions';
import {
  HotelDetailResult,
  HotelRatePlan,
  HotelSearchItem,
  HotelSearchRequest,
  HotelSearchResult
} from './HotelToolTypes';

const HOTEL_SOURCE: string = 'RollingGo';
const HOTEL_LIMITATION: string = 'Appless 支持打开 App 内 RollingGo Web 预订；原生订单创建、状态和取消不可用';
const HOTEL_BOOKING_NOTE: string = '房型与价格由 RollingGo 实时提供，最终房型与价格以预订页为准。';
const HOTEL_PRICE_LIMITATION: string = '税费拆分与报价有效期：供应商未返回';
const HOTEL_SEARCH_PRICE_SCOPE: string = '搜索阶段仅传成人数；完整客人与房间数在实时房型中查询';

export function hotelPendingA2ui(surfaceId: string, prompt: string): string {
  const root: A2uiComponent = {
    id: 'root',
    component: A2UI_COMPONENT_SURFACE_ROOT,
    child: 'pending',
    title: '酒店搜索',
    status: 'calling_tool',
    actions: []
  };
  const pending: A2uiComponent = {
    id: 'pending',
    component: A2UI_COMPONENT_TEXT,
    title: '正在查询 RollingGo',
    text: prompt.length > 0 ? prompt : '正在等待 RollingGo 返回真实酒店与报价。',
    status: 'calling_tool',
    actions: []
  };
  const create: A2uiEnvelope = {
    version: A2UI_VERSION,
    createSurface: {
      surfaceId: surfaceId,
      root: 'root',
      title: '酒店搜索',
      intent: 'hotel',
      status: 'calling_tool',
      sendDataModel: true
    }
  };
  const update: A2uiEnvelope = {
    version: A2UI_VERSION,
    updateComponents: {
      surfaceId: surfaceId,
      components: [root, pending]
    }
  };
  return JSON.stringify(create) + '\n' + JSON.stringify(update);
}

function row(label: string, value: string): A2uiLabelValueData {
  return {
    label: label,
    value: value
  };
}

function numberText(value: number): string {
  return Number.isFinite(value) ? value.toString() : '';
}

function occupancyText(adults: number, children: number, rooms: number): string {
  let value = adults.toString() + ' 成人';
  if (children > 0) {
    value += ' · ' + children.toString() + ' 儿童';
  }
  return value + ' · ' + rooms.toString() + ' 间';
}

function ratePriceText(rate: HotelRatePlan): string {
  if (rate.averagePrice === null || rate.currency.length === 0) {
    return '供应商未返回';
  }
  return numberText(rate.averagePrice) + ' ' + rate.currency;
}

function rateAvailabilityText(rate: HotelRatePlan): string {
  if (rate.isOnRequest === null) {
    return '供应商未返回';
  }
  return rate.isOnRequest ? '需二次确认' : '当前可订';
}

function searchErrorResult(result: HotelSearchResult): DynamicGenericToolResult {
  return {
    sourceTag: HOTEL_SOURCE,
    toolName: 'hotel.search',
    title: '酒店搜索失败',
    status: 'error',
    summary: result.error,
    rows: [
      row('入住', result.query.checkInDate + ' → ' + result.query.checkOutDate),
      row('客人', occupancyText(result.query.adultCount, result.query.childCount, result.query.roomCount)),
      row('能力边界', HOTEL_LIMITATION)
    ],
    rawPreview: ''
  };
}

function detailErrorResult(result: HotelDetailResult): DynamicGenericToolResult {
  return {
    sourceTag: HOTEL_SOURCE,
    toolName: 'hotel.detail',
    title: '房型与报价查询失败',
    status: 'error',
    summary: result.error,
    rows: [
      row('酒店 ID', result.query.hotelId.toString()),
      row('入住', result.query.checkInDate + ' → ' + result.query.checkOutDate),
      row('客人', occupancyText(result.query.adultCount, result.query.childCount, result.query.roomCount)),
      row('能力边界', HOTEL_LIMITATION)
    ],
    rawPreview: ''
  };
}

function restoreSearchAction(): A2uiAction {
  return {
    id: 'hotel.search.restore',
    label: '返回酒店结果',
    prompt: '返回酒店搜索结果',
    kind: 'client',
    variant: 'secondary'
  };
}

function searchRows(hotel: HotelSearchItem, request: HotelSearchRequest): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  if (Number.isInteger(hotel.hotelId) && hotel.hotelId > 0) {
    rows.push(row('酒店 ID', hotel.hotelId.toString()));
  }
  rows.push(
    row('Destination ID', hotel.destinationId),
    row('入住', request.checkInDate + ' → ' + request.checkOutDate),
    row('客人', occupancyText(request.adultCount, request.childCount, request.roomCount)),
    row('地址', hotel.address),
    row('星级', hotel.starRating > 0 ? hotel.starRating.toString() : '供应商未返回'),
    row('参考价', hotel.price.hasPrice ? numberText(hotel.price.lowestPrice) + ' ' + hotel.price.currency : '供应商未返回'),
    row('参考价口径', HOTEL_SEARCH_PRICE_SCOPE),
    row('价格说明', hotel.price.message),
    row('设施', hotel.hotelAmenities.join(' · ')),
    row('标签', hotel.tags.join(' · ')),
    row('能力边界', HOTEL_LIMITATION)
  );
  if (hotel.imageUrl.length > 0) {
    rows.push(row('酒店图片', hotel.imageUrl));
  }
  return rows;
}

function searchResultFor(
  hotel: HotelSearchItem,
  request: HotelSearchRequest,
  canPlace: (action: A2uiAction) => boolean
): DynamicGenericToolResult {
  const price = hotel.price.hasPrice ? numberText(hotel.price.lowestPrice) + ' ' + hotel.price.currency : '暂无价格';
  const summaryParts: string[] = [price];
  if (hotel.address.length > 0) {
    summaryParts.push(hotel.address);
  }
  return {
    sourceTag: HOTEL_SOURCE,
    toolName: 'hotel.search',
    title: hotel.name.length > 0 ? hotel.name : hotel.nameEn,
    status: 'success',
    summary: summaryParts.join(' · '),
    rows: searchRows(hotel, request),
    rawPreview: '',
    actions: hotelActionsFor(hotel, request, canPlace)
  };
}

function rateRows(result: HotelDetailResult, rate: HotelRatePlan): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [
    row('酒店 ID', result.hotelId.toString()),
    row('Rate plan ID', rate.ratePlanId),
    row('入住', result.checkIn + ' → ' + result.checkOut),
    row('客人', occupancyText(result.query.adultCount, result.query.childCount, result.query.roomCount)),
    row('平均价', ratePriceText(rate)),
    row('床型', rate.bedTypeDescription),
    row('餐食', rate.mealTypeStr),
    row('供应商确认', rateAvailabilityText(rate)),
    row('取消政策', rate.cancelPolicy),
    row('税费与有效期', HOTEL_PRICE_LIMITATION),
    row('能力边界', HOTEL_LIMITATION)
  ];
  return rows;
}

function rateResultFor(result: HotelDetailResult, rate: HotelRatePlan): DynamicGenericToolResult {
  const roomName = rate.roomNameCn.length > 0 ? rate.roomNameCn :
    (rate.roomName.length > 0 ? rate.roomName : rate.ratePlanName);
  const summaryParts: string[] = [ratePriceText(rate)];
  if (rate.mealTypeStr.length > 0) {
    summaryParts.push(rate.mealTypeStr);
  }
  return {
    sourceTag: HOTEL_SOURCE,
    toolName: 'hotel.detail',
    title: roomName,
    status: 'success',
    summary: summaryParts.join(' · '),
    rows: rateRows(result, rate),
    rawPreview: ''
  };
}

function appendWarnings(items: DynamicGenericToolResult[], warnings: string[]): void {
  if (items.length === 0 || warnings.length === 0) {
    return;
  }
  const visible: string[] = [];
  warnings.forEach((warning: string) => {
    const value = warning.trim();
    if (value.length > 0 && visible.indexOf(value) < 0) {
      visible.push(value);
    }
  });
  if (visible.length > 0) {
    items[0].rows.push(row('部分结果提醒', visible.join(' · ')));
  }
}

export function hotelSearchA2ui(
  surfaceId: string,
  result: HotelSearchResult,
  canPlace: (action: A2uiAction) => boolean,
  warnings: string[] = []
): string {
  const items: DynamicGenericToolResult[] = [];
  if (!result.ok) {
    items.push(searchErrorResult(result));
  } else {
    result.hotels.forEach((hotel: HotelSearchItem) => items.push(searchResultFor(hotel, result.query, canPlace)));
    if (items.length === 0) {
      items.push({
        sourceTag: HOTEL_SOURCE,
        toolName: 'hotel.search',
        title: '没有找到符合条件的酒店',
        status: 'empty',
        summary: result.message,
        rows: [
          row('目的地', result.query.place),
          row('入住', result.query.checkInDate + ' → ' + result.query.checkOutDate),
          row('客人', occupancyText(result.query.adultCount, result.query.childCount, result.query.roomCount)),
          row('能力边界', HOTEL_LIMITATION)
        ],
        rawPreview: ''
      });
    }
  }
  appendWarnings(items, warnings);
  return genericToolResultsA2ui(surfaceId, 'hotel.search', items, 'hotel', '酒店搜索');
}

export function hotelDetailA2ui(
  surfaceId: string,
  result: HotelDetailResult,
  canPlace: (action: A2uiAction) => boolean = (_action: A2uiAction): boolean => true,
  warnings: string[] = []
): string {
  const items: DynamicGenericToolResult[] = [];
  if (!result.ok) {
    items.push(detailErrorResult(result));
  } else {
    result.rates.forEach((rate: HotelRatePlan) => items.push(rateResultFor(result, rate)));
    if (items.length === 0) {
      items.push({
        sourceTag: HOTEL_SOURCE,
        toolName: 'hotel.detail',
        title: result.name,
        status: 'empty',
        summary: '供应商没有返回可展示的实时房型。',
        rows: [
          row('酒店 ID', result.hotelId.toString()),
          row('入住', result.checkIn + ' → ' + result.checkOut),
          row('客人', occupancyText(result.query.adultCount, result.query.childCount, result.query.roomCount)),
          row('能力边界', HOTEL_LIMITATION)
        ],
        rawPreview: ''
      });
    }
  }
  if (items.length > 0) {
    const actions: A2uiAction[] = [restoreSearchAction()];
    if (result.ok && result.rates.length > 0) {
      const booking = hotelBookingOpenAction(result);
      if (validHotelBookingOpenArgs(booking.args as HotelBookingOpenArgs).ok && canPlace(booking)) {
        actions.push(booking);
        items[0].rows.push(row('预订说明', HOTEL_BOOKING_NOTE));
      }
    }
    items[0].actions = actions;
  }
  appendWarnings(items, warnings);
  return genericToolResultsA2ui(surfaceId, 'hotel.detail', items, 'hotel', result.name.length > 0 ? result.name : '实时房型与报价');
}

export function hotelFailureA2ui(surfaceId: string, toolId: string, message: string): string {
  const result: DynamicGenericToolResult = {
    sourceTag: HOTEL_SOURCE,
    toolName: toolId,
    title: '酒店供应商调用失败',
    status: 'error',
    summary: message,
    rows: [row('能力边界', HOTEL_LIMITATION)],
    rawPreview: ''
  };
  return genericToolResultsA2ui(surfaceId, toolId, [result], 'hotel', '酒店查询');
}
