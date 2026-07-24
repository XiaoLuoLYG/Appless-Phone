import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiAction,
  A2uiSurfaceStore,
  HotelSearchResult,
  hotelSearchA2ui,
  parseA2uiJsonl,
  parseHotelSearchRequest
} from '@loop/agent-core';
import { renderHtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeRenderer';
import { createHtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeSnapshot';
import { HtmlHomeAction, HtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeTypes';
import { renderRideDriverMapHtml } from '../main/ets/pages/A2uiHome/html/RideDriverMapHtmlRenderer';

interface GooglePayCheckoutArgsFixture {
  provider: string;
  fundingSource: string;
  amountText: string;
  currency: string;
  providerSessionId: string;
  paypalClientId: string;
  paypalEnvironment: string;
  paypalEmail: string;
  paypalMerchantId: string;
}

interface BookingUrlArgsFixture {
  bookingUrl: string;
}

function documentFixture(): HtmlHomeDocument {
  return {
    version: 1,
    source: 'tool',
    kind: 'generic',
    title: 'Project Brief',
    subtitle: 'Today',
    chips: [{ label: 'status', value: 'ready' }],
    metrics: [{ label: 'blocks', value: '1' }],
    timeline: [{ title: 'Draft', subtitle: 'Collected notes', status: 'ready' }],
    blocks: [{
      id: 'block-1',
      kind: 'note',
      title: 'Known Block',
      subtitle: 'Rendered from document data',
      status: 'ready',
      metrics: [{ label: 'owner', value: 'local' }],
      rows: [{ label: 'next', value: 'review' }],
      actions: [{ id: 'block-action', label: 'Review Block', prompt: 'review it', variant: 'primary', kind: 'prompt' }]
    }],
    actions: [{ id: 'doc-action', label: 'Run Action', prompt: 'run it', variant: 'primary', kind: 'prompt' }],
    history: [{ id: 'm1', role: 'user', content: 'make a brief' }],
    persona: { id: '', name: '', avatarKey: '', status: '', reason: '' },
    personaMemory: { summary: '', preferences: [] },
    rawSurfaceRoot: null,
    generatedAt: '2026-06-25T00:00:00.000Z'
  };
}

function dynamicCredentialDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'dynamic-tools';
  doc.title = '动态工具连接';
  doc.subtitle = '工具需要授权后才能继续';
  doc.blocks = [{
    id: 'connect',
    kind: 'dynamic-tool-connect',
    title: 'Amap Maps',
    subtitle: 'API key required',
    status: 'needs_auth',
    credentialName: 'API Key',
    credentialRef: 'dynamic:maps:API Key',
    toolId: 'maps.weather',
    prompt: 'weather now',
    metrics: [],
    rows: [],
    actions: []
  }];
  return doc;
}

function hotelDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'hotel';
  doc.title = '深圳酒店';
  doc.subtitle = '2026-08-15 → 2026-08-17 · 2 成人 · 1 间';
  doc.blocks = [{
    id: 'hotel-rate-1',
    kind: 'generic-tool-result',
    title: '豪华大床房',
    subtitle: '550 CNY · 不含早餐',
    status: 'success',
    source: 'RollingGo',
    metrics: [
      { label: 'source', value: 'RollingGo' },
      { label: 'toolName', value: 'hotel.detail' }
    ],
    rows: [
      { label: '酒店图片', value: 'https://images.example.com/hotel.jpg' },
      { label: '酒店 ID', value: '47675' },
      { label: 'Rate plan ID', value: '5nAv6vObodN-6idXNkFPe3z' },
      { label: '入住', value: '2026-08-15 → 2026-08-17' },
      { label: '客人', value: '2 成人 · 1 间' },
      { label: '平均价', value: '550 CNY' },
      { label: '床型', value: '1 大床' },
      { label: '餐食', value: '不含早餐' },
      { label: '取消政策', value: '免费取消截止至酒店当地时间 2026-08-12 08:00:00' },
      { label: '税费与有效期', value: '税费拆分与报价有效期：供应商未返回' },
      { label: '能力边界', value: 'Appless 支持打开 App 内 RollingGo Web 预订；原生订单创建、状态和取消不可用' }
    ],
    actions: [{
      id: 'hotel.search.restore',
      label: '返回酒店结果',
      prompt: '返回酒店搜索结果',
      variant: 'secondary',
      kind: 'client'
    }]
  }];
  doc.actions = [];
  return doc;
}

function allowHotelAction(_action: A2uiAction): boolean {
  return true;
}

function hotelSearchDocumentFixture(withCoordinates: boolean = true): HtmlHomeDocument {
  const parsed = parseHotelSearchRequest(JSON.parse('{' +
    '"originQuery":"深圳酒店","place":"深圳","placeType":"CITY","countryCode":"CN",' +
    '"checkInDate":"2026-08-15","stayNights":2,"adultCount":2,"childCount":0,' +
    '"childAgeDetails":[],"roomCount":1,"currency":"CNY","size":10}') as Object);
  if (parsed.value === null) {
    throw new Error('hotel search renderer fixture is invalid');
  }
  const result: HotelSearchResult = {
    ok: true,
    error: '',
    message: '酒店搜索成功',
    query: parsed.value,
    hotels: [{
      hotelId: 47675,
      bookingUrl: '',
      name: '深圳测试酒店',
      nameEn: 'Shenzhen Test Hotel',
      brand: '',
      address: '深圳市南山区科技南路 88 号',
      destinationId: '6046792',
      latitude: withCoordinates ? 22.5431 : null,
      longitude: withCoordinates ? 114.0579 : null,
      distanceInMeters: 0,
      starRating: 5,
      price: {
        message: '2 晚参考价',
        hasPrice: true,
        currency: 'CNY',
        lowestPrice: 1100
      },
      areaCode: 'NANSHAN',
      description: '',
      imageUrl: '',
      hotelAmenities: ['Wi-Fi'],
      tags: ['商务']
    }]
  };
  const parsedJsonl = parseA2uiJsonl(hotelSearchA2ui('hotel-search-task-6', result, allowHotelAction));
  if (parsedJsonl.error.length > 0) {
    throw new Error(parsedJsonl.error);
  }
  const store = new A2uiSurfaceStore();
  parsedJsonl.envelopes.forEach((envelope) => {
    store.apply(envelope);
  });
  return createHtmlHomeDocument({
    surface: store.getSurface(),
    messages: [],
    isBusy: false,
    isAwaitingFirstSurface: false
  });
}

function rideDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'dynamic-tools';
  doc.title = '打车';
  doc.subtitle = '华为坂田基地 → 秋港花园';
  doc.blocks = [{
    id: 'ride-results-ride',
    kind: 'ride-tool-panel',
    title: '去秋港花园',
    subtitle: '华为坂田基地 → 秋港花园',
    status: 'estimate',
    source: '滴滴',
    metrics: [
      { label: 'stage', value: 'estimate' },
      { label: 'routeText', value: '华为坂田基地 → 秋港花园' },
      { label: 'visualLabel', value: '极速叫车' },
      { label: 'showDriverMarker', value: 'false' }
    ],
    rows: [
      { label: 'estimate|express|快车', value: '15' },
      { label: 'estimate|1|特惠快车', value: '10' },
      { label: 'estimate|8|专车', value: '30' },
      { label: 'estimate|17|豪华车', value: '100' }
    ],
    actions: [
      { id: 'ride.order.confirm', label: '确认叫特惠快车', prompt: '确认下单：特惠快车 10', variant: 'primary', kind: 'prompt' },
      { id: 'ride.order.confirm', label: '确认叫快车', prompt: '确认下单：快车 15', variant: 'primary', kind: 'prompt' },
      { id: 'ride.order.confirm', label: '确认叫专车', prompt: '确认下单：专车 30', variant: 'primary', kind: 'prompt' },
      { id: 'ride.order.confirm', label: '确认叫豪华车', prompt: '确认下单：豪华车 100', variant: 'primary', kind: 'prompt' },
      { id: 'ride.open.didi', label: '打开滴滴', prompt: 'diditaxi://ride', variant: 'primary', kind: 'client' }
    ]
  }];
  doc.actions = [];
  return doc;
}

function rideDriverDocumentFixture(): HtmlHomeDocument {
  const doc = rideDocumentFixture();
  doc.blocks[0].status = 'driver_location';
  doc.blocks[0].metrics = [
    { label: 'stage', value: 'driver_location' },
    { label: 'routeText', value: '华为坂田基地 → 秋港花园' },
    { label: 'pickupLocation', value: '114.066231,22.657805' },
    { label: 'destinationLocation', value: '114.060432,22.548829' },
    { label: 'visualLabel', value: '司机正在前往' },
    { label: 'showDriverMarker', value: 'true' },
    { label: 'orderId', value: 'order-123' },
    { label: 'driverLocation', value: '114.060000,22.650000' },
    { label: 'driverName', value: '李师傅' },
    { label: 'driverEtaText', value: '预计 6 分钟接驾' },
    { label: 'selectedVehicleText', value: '专车' }
  ];
  doc.blocks[0].rows = [];
  doc.blocks[0].actions = [
    { id: 'ride.driver.location.refresh', label: '刷新司机位置', prompt: '刷新滴滴司机位置', variant: 'primary', kind: 'prompt' },
    { id: 'ride.order.cancel', label: '取消订单', prompt: '取消滴滴打车订单', variant: 'danger', kind: 'prompt' }
  ];
  return doc;
}

function aggregateSearchDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'aggregate-search';
  doc.title = '聚合搜索';
  doc.subtitle = 'openai codex';
  doc.blocks = [{
    id: 'video-1',
    kind: 'aggregate-video',
    title: 'Codex demo',
    subtitle: 'Video row',
    status: 'success',
    source: 'youtube',
    metrics: [{ label: 'provider', value: 'YouTube' }],
    rows: [{ label: 'url', value: 'https://www.youtube.com/watch?v=abc123' }],
    actions: [],
    mediaEmbed: {
      provider: 'YouTube',
      title: 'Codex demo',
      embedUrl: 'https://www.youtube.com/embed/abc123',
      pageUrl: 'https://www.youtube.com/watch?v=abc123',
      thumbnail: ''
    }
  }, {
    id: 'post-1',
    kind: 'aggregate-post',
    title: 'OpenAI Codex discussion',
    subtitle: 'Discussion row',
    status: 'success',
    source: 'hackernews',
    metrics: [{ label: 'provider', value: 'Hacker News' }],
    rows: [{ label: 'url', value: 'https://news.ycombinator.com/item?id=123' }],
    actions: []
  }, {
    id: 'status-youtube',
    kind: 'aggregate-source-status',
    title: 'YouTube',
    subtitle: 'YouTube returned 1 row.',
    status: 'success',
    source: 'youtube',
    metrics: [{ label: 'count', value: '1' }],
    rows: [],
    actions: []
  }, {
    id: 'status-zhihu',
    kind: 'aggregate-source-status',
    title: '知乎',
    subtitle: '未配置 ZHIHU_API_KEY（知乎 Access Secret）。',
    status: 'needs_auth',
    source: 'zhihu',
    metrics: [],
    rows: [],
    actions: []
  }];
  doc.actions = [];
  doc.history = [];
  return doc;
}

function travelFoodCardsDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  const bookingArgs: BookingUrlArgsFixture = {
    bookingUrl: 'https://kyfw.12306.cn/otn/leftTicket/init?linktypeid=dc&fs=test&ts=test&date=2026-07-22&flag=N,N,Y'
  };
  doc.kind = 'travel';
  doc.title = '深圳北到上海虹桥';
  doc.subtitle = 'Travel and food results';
  doc.blocks = [{
    id: 'train-g123',
    kind: 'train-option',
    title: 'G123',
    subtitle: '深圳北 -> 上海虹桥',
    status: 'available',
    source: '12306',
    metrics: [
      { label: 'duration', value: '6h30m' },
      { label: 'price', value: '553' },
      { label: 'source', value: 'train' }
    ],
    rows: [
      { label: 'depart', value: '09:00' },
      { label: 'arrive', value: '15:30' },
      { label: 'seats', value: '二等座有票' }
    ],
    actions: [{
      id: 'train.booking.open',
      label: '去购票',
      prompt: '',
      variant: 'primary',
      kind: 'client',
      args: bookingArgs
    }, {
      id: 'html_pin_travel',
      label: '收藏行程',
      prompt: 'pin train',
      variant: 'secondary',
      kind: 'client'
    }]
  }, {
    id: 'food-amap-1',
    kind: 'food-result',
    title: '麦当劳 科技园店',
    subtitle: '步行可达',
    status: 'ready',
    source: 'amap',
    metrics: [
      { label: 'distance', value: '450m' },
      { label: 'source', value: 'amap' }
    ],
    rows: [
      { label: 'address', value: '科技园路 1 号' },
      { label: 'rating', value: '4.6' }
    ],
    actions: [{ id: 'html_open_food_map', label: '打开地图', prompt: 'open food map', variant: 'primary', kind: 'client' }]
  }];
  doc.actions = [];
  return doc;
}

function foodDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'food';
  doc.title = '外卖聚合搜索';
  doc.subtitle = '以下结果来自高德、腾讯地图、百度地图；仅展示真实返回字段。';
  doc.chips = [];
  doc.metrics = [];
  doc.timeline = [];
  doc.actions = [
    { id: 'food_show_all', label: '全部', prompt: 'food_show_all', variant: 'activated', kind: 'client' },
    { id: 'food_filter_1km', label: '1公里内', prompt: 'food_filter_1km', variant: 'secondary', kind: 'client' },
    { id: 'food_show_more', label: '展示更多', prompt: 'food_show_more', variant: 'secondary', kind: 'client' }
  ];
  doc.blocks = [{
    id: 'food-0',
    kind: 'food-result',
    title: '三津汤包 (深圳北站店)',
    subtitle: '餐饮服务; 餐饮相关场所; 餐饮相关',
    status: 'ready',
    source: '高德 / 腾讯地图',
    metrics: [
      { label: 'category', value: '餐饮服务; 餐饮相关场所; 餐饮相关' },
      { label: 'address', value: '民治街道深圳北站（深圳北站地铁D口旁）' },
      { label: 'distance', value: '21米' },
      { label: 'location', value: '114.029506,22.609878' },
      { label: 'source', value: '高德 / 腾讯地图' }
    ],
    rows: [],
    actions: [
      { id: 'html_pin_food', label: '固定到桌面', prompt: '{"index":0,"name":"三津汤包 (深圳北站店)","address":"民治街道深圳北站（深圳北站地铁D口旁）","location":"114.029506,22.609878","distance":"21米"}', variant: 'secondary', kind: 'client' },
      { id: 'html_open_food_map', label: '导航去', prompt: '{"index":0,"name":"三津汤包 (深圳北站店)","address":"民治街道深圳北站（深圳北站地铁D口旁）","location":"114.029506,22.609878","distance":"21米"}', variant: 'secondary', kind: 'client' }
    ]
  }, {
    id: 'food-1',
    kind: 'food-result',
    title: 'N多寿司 (深圳北站店)',
    subtitle: '餐饮服务; 快餐厅; 快餐厅',
    status: 'ready',
    source: '高德',
    metrics: [
      { label: 'category', value: '餐饮服务; 快餐厅; 快餐厅' },
      { label: 'address', value: '民治街道北站社区深圳北站综合交通枢纽东广场C1栋102号' },
      { label: 'distance', value: '0米' },
      { label: 'location', value: '114.029506,22.609878' },
      { label: 'source', value: '高德' }
    ],
    rows: [],
    actions: [
      { id: 'html_pin_food', label: '固定到桌面', prompt: '{"index":1,"name":"N多寿司 (深圳北站店)","address":"民治街道北站社区深圳北站综合交通枢纽东广场C1栋102号","location":"114.029506,22.609878","distance":"0米"}', variant: 'secondary', kind: 'client' },
      { id: 'html_open_food_map', label: '导航去', prompt: '{"index":1,"name":"N多寿司 (深圳北站店)","address":"民治街道北站社区深圳北站综合交通枢纽东广场C1栋102号","location":"114.029506,22.609878","distance":"0米"}', variant: 'secondary', kind: 'client' }
    ]
  }, {
    id: 'food-2',
    kind: 'food-result',
    title: '麦当劳 (深圳北站店)',
    subtitle: '麦当劳门店',
    status: 'ready',
    source: '麦当劳',
    metrics: [
      { label: 'category', value: '麦当劳门店' },
      { label: 'address', value: '深圳北站商业区' },
      { label: 'distance', value: '180米' },
      { label: 'location', value: '114.030000,22.610000' },
      { label: 'source', value: '麦当劳' }
    ],
    rows: [],
    actions: [
      { id: 'html_pin_food', label: '固定到桌面', prompt: '{"index":2,"name":"麦当劳 (深圳北站店)","address":"深圳北站商业区","location":"114.030000,22.610000","distance":"180米"}', variant: 'secondary', kind: 'client' },
      { id: 'html_open_food_map', label: '导航去', prompt: '{"index":2,"name":"麦当劳 (深圳北站店)","address":"深圳北站商业区","location":"114.030000,22.610000","distance":"180米"}', variant: 'secondary', kind: 'client' }
    ]
  }, {
    id: 'food-3',
    kind: 'food-result',
    title: '未知坐标小吃档',
    subtitle: 'provider 未返回坐标',
    status: 'ready',
    source: '美团',
    metrics: [
      { label: 'category', value: '小吃' },
      { label: 'address', value: '坂田街道附近' },
      { label: 'distance', value: '900米' },
      { label: 'location', value: '' },
      { label: 'source', value: '美团' }
    ],
    rows: [],
    actions: [
      { id: 'html_pin_food', label: '固定到桌面', prompt: '{"index":3,"name":"未知坐标小吃档","address":"坂田街道附近","location":"","distance":"900米"}', variant: 'secondary', kind: 'client' },
      { id: 'html_open_food_map', label: '导航去', prompt: '{"index":3,"name":"未知坐标小吃档","address":"坂田街道附近","location":"","distance":"900米"}', variant: 'secondary', kind: 'client' }
    ]
  }];
  doc.history = [];
  return doc;
}

function googleMapsDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'generic';
  doc.title = 'Google Maps 搜索结果';
  doc.subtitle = 'Google Places API 返回的真实地点';
  doc.blocks = [{
    id: 'maps-0',
    kind: 'generic-tool-result',
    title: 'Coffee Lab',
    subtitle: 'Google Places result for: 深圳咖啡',
    status: 'success',
    source: 'Google Places API',
    metrics: [
      { label: 'source', value: 'Google Places API' },
      { label: 'toolName', value: 'maps.place.search' }
    ],
    rows: [
      { label: 'Place ID', value: 'place-123' },
      { label: 'Address', value: '深圳市龙岗区坂田' },
      { label: 'Map Location', value: '22.609878,114.029506' },
      { label: 'Maps URL', value: 'https://maps.google.com/?cid=123' }
    ],
    actions: [
      { id: 'maps.open.web', label: '打开 Google Maps', prompt: 'https://maps.google.com/?cid=123', variant: 'secondary', kind: 'client' }
    ]
  }];
  doc.actions = [];
  return doc;
}

function googleMapsRouteDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'generic';
  doc.title = 'Google Maps 路线';
  doc.subtitle = '深圳北站到深圳湾口岸';
  doc.blocks = [{
    id: 'maps-route-0',
    kind: 'generic-tool-result',
    title: '深圳北站 → 深圳湾口岸',
    subtitle: '路线已准备好。',
    status: 'success',
    source: 'Google Maps',
    metrics: [
      { label: 'source', value: 'Google Maps' },
      { label: 'toolName', value: 'maps.route.open' }
    ],
    rows: [
      { label: 'Origin', value: '深圳北站' },
      { label: 'Destination', value: '深圳湾口岸' },
      { label: 'Maps URL', value: 'https://www.google.com/maps/dir/?api=1&origin=a&destination=b' }
    ],
    actions: [
      { id: 'maps.open.web', label: '查看路线', prompt: 'https://www.google.com/maps/dir/?api=1&origin=a&destination=b', variant: 'primary', kind: 'client' }
    ]
  }];
  doc.actions = [];
  return doc;
}

function composioResultsDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'dynamic-tools';
  doc.title = 'Composio 工具结果';
  doc.subtitle = 'GitHub, Drive, Docs, Slack, Outlook, Discord, LinkedIn, WhatsApp, Instagram, Spotify, TikTok, Ticketmaster';
  doc.blocks = [{
    id: 'composio-github-0',
    kind: 'generic-tool-result',
    title: 'Composio GitHub 结果',
    subtitle: 'Composio 已执行 GITHUB_LIST_PULL_REQUESTS，返回 1 条可展示结果。',
    status: 'success',
    source: 'Composio',
    metrics: [{ label: 'toolName', value: 'GITHUB_LIST_PULL_REQUESTS' }],
    rows: [
      { label: '执行工具', value: 'GITHUB_LIST_PULL_REQUESTS' },
      { label: '查询', value: 'Appless-Phone 最近的 pr' },
      { label: '结果数量', value: '1' },
      { label: 'Add Composio result cards', value: '#40 | open | https://github.com/XiaoLuoLYG/Appless-Phone/pull/40' }
    ],
    actions: []
  }, {
    id: 'composio-drive-0',
    kind: 'generic-tool-result',
    title: 'Composio Google Drive 结果',
    subtitle: 'Composio 已执行 GOOGLEDRIVE_SEARCH_FILES，返回 1 条可展示结果。',
    status: 'success',
    source: 'Composio',
    metrics: [{ label: 'toolName', value: 'GOOGLEDRIVE_SEARCH_FILES' }],
    rows: [
      { label: '执行工具', value: 'GOOGLEDRIVE_SEARCH_FILES' },
      { label: '查询', value: '签证材料' },
      { label: '结果数量', value: '1' },
      { label: '签证材料.pdf', value: 'application/pdf | https://drive.google.com/file/d/file_1/view' }
    ],
    actions: []
  }, {
    id: 'composio-docs-0',
    kind: 'generic-tool-result',
    title: 'Composio Google Docs 结果',
    subtitle: 'Composio 已执行 GOOGLEDOCS_SEARCH_DOCUMENTS，返回 1 条可展示结果。',
    status: 'success',
    source: 'Composio',
    metrics: [{ label: 'toolName', value: 'GOOGLEDOCS_SEARCH_DOCUMENTS' }],
    rows: [
      { label: '执行工具', value: 'GOOGLEDOCS_SEARCH_DOCUMENTS' },
      { label: '查询', value: 'AIPhoneDemo 设计文档' },
      { label: '结果数量', value: '1' },
      { label: 'AIPhoneDemo 设计文档', value: '2026-07-06T12:41:26.011Z | https://docs.google.com/document/d/doc_1/edit' }
    ],
    actions: []
  }, {
    id: 'composio-slack-0',
    kind: 'generic-tool-result',
    title: 'Composio Slack 结果',
    subtitle: 'Composio 已执行 SLACK_SEARCH_MESSAGES，返回 1 条可展示结果。',
    status: 'success',
    source: 'Composio',
    metrics: [{ label: 'toolName', value: 'SLACK_SEARCH_MESSAGES' }],
    rows: [
      { label: '执行工具', value: 'SLACK_SEARCH_MESSAGES' },
      { label: '查询', value: 'AIPhoneDemo' },
      { label: '结果数量', value: '1' },
      { label: 'AIPhoneDemo demo ready', value: '#aiphone-demo | https://example.slack.com/archives/C1/p1' }
    ],
    actions: []
  }, {
    id: 'composio-outlook-0',
    kind: 'generic-tool-result',
    title: 'Composio Outlook 结果',
    subtitle: 'Composio 已执行 OUTLOOK_SEARCH_MESSAGES，返回 1 条可展示结果。',
    status: 'success',
    source: 'Composio',
    metrics: [{ label: 'toolName', value: 'OUTLOOK_SEARCH_MESSAGES' }],
    rows: [
      { label: '执行工具', value: 'OUTLOOK_SEARCH_MESSAGES' },
      { label: '查询', value: 'AIPhoneDemo' },
      { label: '结果数量', value: '1' },
      { label: 'AIPhoneDemo follow-up', value: 'Product Team | 2026-07-07T08:30:00Z | https://outlook.office.com/mail/id/1' }
    ],
    actions: []
  }, {
    id: 'composio-discord-0',
    kind: 'generic-tool-result',
    title: 'Composio Discord 结果',
    subtitle: 'Composio 已执行 DISCORD_SEARCH_MESSAGES，返回 1 条可展示结果。',
    status: 'success',
    source: 'Composio',
    metrics: [{ label: 'toolName', value: 'DISCORD_SEARCH_MESSAGES' }],
    rows: [
      { label: '执行工具', value: 'DISCORD_SEARCH_MESSAGES' },
      { label: '查询', value: 'AIPhoneDemo' },
      { label: '结果数量', value: '1' },
      { label: 'Discord AIPhoneDemo thread', value: '#demo-lab | https://discord.com/channels/1/2/3' }
    ],
    actions: []
  }, {
    id: 'composio-linkedin-0',
    kind: 'generic-tool-result',
    title: 'Composio LinkedIn 结果',
    subtitle: 'Composio 已执行 LINKEDIN_SEARCH_POSTS，返回 1 条可展示结果。',
    status: 'success',
    source: 'Composio',
    metrics: [{ label: 'toolName', value: 'LINKEDIN_SEARCH_POSTS' }],
    rows: [
      { label: '执行工具', value: 'LINKEDIN_SEARCH_POSTS' },
      { label: '查询', value: 'AIPhoneDemo' },
      { label: '结果数量', value: '1' },
      { label: 'AIPhoneDemo launch note', value: 'Yige | https://www.linkedin.com/feed/update/1' }
    ],
    actions: []
  }, {
    id: 'composio-whatsapp-0',
    kind: 'generic-tool-result',
    title: 'Composio WhatsApp 结果',
    subtitle: 'Composio 已执行 WHATSAPP_SEARCH_MESSAGES，返回 1 条可展示结果。',
    status: 'success',
    source: 'Composio',
    metrics: [{ label: 'toolName', value: 'WHATSAPP_SEARCH_MESSAGES' }],
    rows: [
      { label: '执行工具', value: 'WHATSAPP_SEARCH_MESSAGES' },
      { label: '查询', value: 'AIPhoneDemo' },
      { label: '结果数量', value: '1' },
      { label: 'AIPhoneDemo WhatsApp note', value: 'Demo Group | 2026-07-07 09:00' }
    ],
    actions: []
  }, {
    id: 'composio-instagram-0',
    kind: 'generic-tool-result',
    title: 'Composio Instagram 结果',
    subtitle: 'Composio 已执行 INSTAGRAM_SEARCH_COMMENTS，返回 1 条可展示结果。',
    status: 'success',
    source: 'Composio',
    metrics: [{ label: 'toolName', value: 'INSTAGRAM_SEARCH_COMMENTS' }],
    rows: [
      { label: '执行工具', value: 'INSTAGRAM_SEARCH_COMMENTS' },
      { label: '查询', value: 'AIPhoneDemo' },
      { label: '结果数量', value: '1' },
      { label: 'AIPhoneDemo reel comment', value: '@demo_user | https://www.instagram.com/p/demo/' }
    ],
    actions: []
  }, {
    id: 'composio-spotify-0',
    kind: 'generic-tool-result',
    title: 'Composio Spotify 结果',
    subtitle: 'Composio 已执行 SPOTIFY_SEARCH_PLAYLISTS，返回 1 条可展示结果。',
    status: 'success',
    source: 'Composio',
    metrics: [{ label: 'toolName', value: 'SPOTIFY_SEARCH_PLAYLISTS' }],
    rows: [
      { label: '执行工具', value: 'SPOTIFY_SEARCH_PLAYLISTS' },
      { label: '查询', value: 'AIPhoneDemo demo playlist' },
      { label: '结果数量', value: '1' },
      { label: 'AIPhoneDemo Demo Flow', value: '48 tracks | https://open.spotify.com/playlist/demo' }
    ],
    actions: []
  }, {
    id: 'composio-tiktok-0',
    kind: 'generic-tool-result',
    title: 'Composio TikTok 结果',
    subtitle: 'Composio 已执行 TIKTOK_SEARCH_VIDEOS，返回 1 条可展示结果。',
    status: 'success',
    source: 'Composio',
    metrics: [{ label: 'toolName', value: 'TIKTOK_SEARCH_VIDEOS' }],
    rows: [
      { label: '执行工具', value: 'TIKTOK_SEARCH_VIDEOS' },
      { label: '查询', value: 'AIPhoneDemo' },
      { label: '结果数量', value: '1' },
      { label: 'AIPhoneDemo short demo', value: '@demo_creator | https://www.tiktok.com/@demo/video/1' }
    ],
    actions: []
  }, {
    id: 'composio-ticketmaster-0',
    kind: 'generic-tool-result',
    title: 'Composio Ticketmaster 结果',
    subtitle: 'Composio 已执行 TICKETMASTER_SEARCH_EVENTS，返回 1 条可展示结果。',
    status: 'success',
    source: 'Composio',
    metrics: [{ label: 'toolName', value: 'TICKETMASTER_SEARCH_EVENTS' }],
    rows: [
      { label: '执行工具', value: 'TICKETMASTER_SEARCH_EVENTS' },
      { label: '查询', value: '深圳本周末演唱会' },
      { label: '结果数量', value: '1' },
      { label: 'Shenzhen Live', value: 'Shenzhen Bay Sports Center | https://www.ticketmaster.com/event/1' }
    ],
    actions: []
  }];
  doc.actions = [];
  doc.history = [];
  return doc;
}

function calendarSearchDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'dynamic-tools';
  doc.title = '明日 Google Calendar';
  doc.subtitle = 'Google Calendar API 查询成功。';
  doc.blocks = [{
    id: 'calendar-search-0',
    kind: 'generic-tool-result',
    title: '产品同步',
    subtitle: 'Google Calendar API 查询成功。',
    status: 'success',
    source: 'Google Calendar API',
    metrics: [
      { label: 'source', value: 'Google Calendar API' },
      { label: 'toolName', value: 'calendar.events.search' }
    ],
    rows: [
      { label: 'Event ID', value: 'event-1' },
      { label: 'Start', value: '2026-07-02T10:00:00+08:00' },
      { label: 'End', value: '2026-07-02T10:30:00+08:00' },
      { label: 'Link', value: 'https://calendar.google.com/calendar/event?eid=event-1' }
    ],
    actions: []
  }];
  doc.actions = [];
  doc.history = [];
  return doc;
}

function calendarEmptySearchDocumentFixture(): HtmlHomeDocument {
  const doc = calendarSearchDocumentFixture();
  doc.title = '明日 Google Calendar';
  doc.subtitle = 'Google Calendar API 查询成功，但没有可展示事件。';
  doc.blocks[0].title = '没有找到日程';
  doc.blocks[0].subtitle = 'Google Calendar API 查询成功，但没有可展示事件。';
  doc.blocks[0].rows = [
    { label: 'Window Start', value: '2026-07-02T00:00:00+08:00' },
    { label: 'Window End', value: '2026-07-03T00:00:00+08:00' }
  ];
  return doc;
}

function calendarCreateDocumentFixture(): HtmlHomeDocument {
  const doc = calendarSearchDocumentFixture();
  doc.title = '已创建一对一会议';
  doc.subtitle = '已直接写入真实 Google Calendar。';
  doc.blocks[0].title = '一对一会议';
  doc.blocks[0].subtitle = '已直接写入真实 Google Calendar。';
  doc.blocks[0].metrics = [
    { label: 'source', value: 'Google Calendar API' },
    { label: 'toolName', value: 'calendar.event.create' }
  ];
  doc.blocks[0].rows = [
    { label: 'Event ID', value: 'event-create-1' },
    { label: 'Start', value: '2026-07-02T16:30:00+08:00' },
    { label: 'End', value: '2026-07-02T17:00:00+08:00' },
    { label: 'Link', value: 'https://calendar.google.com/calendar/event?eid=event-create-1' }
  ];
  return doc;
}

function calendarDeleteConfirmationDocumentFixture(): HtmlHomeDocument {
  const doc = calendarSearchDocumentFixture();
  doc.title = '确认删除日程';
  doc.subtitle = '删除后无法在本 App 内撤销，请确认。';
  doc.blocks[0].title = '确认删除日程';
  doc.blocks[0].subtitle = '删除后无法在本 App 内撤销，请确认。';
  doc.blocks[0].status = 'confirm_required';
  doc.blocks[0].metrics = [
    { label: 'source', value: 'Composio Google Calendar' },
    { label: 'toolName', value: 'calendar.event.delete' }
  ];
  doc.blocks[0].rows = [{ label: 'Event ID', value: 'event-delete-1' }];
  const confirmAction: HtmlHomeAction = {
    id: 'calendar.event.delete.confirm',
    label: '确认删除',
    prompt: '确认删除 Google Calendar 日程',
    variant: 'danger',
    kind: 'prompt',
    args: JSON.parse('{"eventId":"event-delete-1","calendarId":"primary"}') as Object
  };
  doc.blocks[0].actions = [confirmAction];
  return doc;
}

function calendarDeleteSuccessDocumentFixture(): HtmlHomeDocument {
  const doc = calendarDeleteConfirmationDocumentFixture();
  doc.title = 'Google Calendar';
  doc.subtitle = '把上一条日程改到明天下午4点30分';
  doc.blocks[0].title = '日程已删除';
  doc.blocks[0].subtitle = '已从真实 Google Calendar 删除日程。';
  doc.blocks[0].status = 'success';
  doc.blocks[0].actions = [];
  return doc;
}

function mailAggregateDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'gmail';
  doc.title = '邮箱';
  doc.subtitle = '聚合展示 Gmail、QQ Mail 和 Outlook 邮箱';
  doc.blocks = [{
    id: 'gmail-1',
    kind: 'generic-tool-result',
    title: 'Gmail message',
    subtitle: 'Gmail thread retrieved.',
    status: 'success',
    source: 'Gmail',
    metrics: [
      { label: 'source', value: 'Gmail' },
      { label: 'toolName', value: 'mail.thread' }
    ],
    rows: [
      { label: 'Provider', value: 'gmail' },
      { label: 'Thread ID', value: 'gmail-thread' }
    ],
    actions: []
  }, {
    id: 'qq-1',
    kind: 'generic-tool-result',
    title: 'QQ message',
    subtitle: 'QQ Mail thread retrieved.',
    status: 'success',
    source: 'QQ Mail',
    metrics: [
      { label: 'source', value: 'QQ Mail' },
      { label: 'toolName', value: 'mail.thread' }
    ],
    rows: [
      { label: 'Provider', value: 'qq' },
      { label: 'Thread ID', value: 'qq-thread' }
    ],
    actions: []
  }, {
    id: 'outlook-1',
    kind: 'generic-tool-result',
    title: 'Composio 调用失败',
    subtitle: 'Composio 执行 OUTLOOK_SEARCH_MESSAGES 失败。',
    status: 'error',
    source: 'Composio Outlook',
    metrics: [
      { label: 'source', value: 'Composio Outlook' },
      { label: 'toolName', value: 'OUTLOOK_SEARCH_MESSAGES' }
    ],
    rows: [
      { label: 'provider', value: 'Outlook' },
      { label: '结果摘要', value: 'Composio 执行 OUTLOOK_SEARCH_MESSAGES 失败。' }
    ],
    actions: []
  }];
  doc.actions = [];
  return doc;
}

function socialDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'social';
  doc.title = '微信消息';
  doc.subtitle = '来自通知捕获的真实消息';
  doc.blocks = [{
    id: 'wechat-1',
    kind: 'social-message',
    title: 'Alice',
    subtitle: '晚上一起吃饭吗',
    status: 'unread',
    source: 'notification',
    metrics: [
      { label: 'platform', value: 'wechat' },
      { label: 'sender', value: 'Alice' }
    ],
    rows: [
      { label: 'receivedAt', value: '2026-06-11T08:30:00.000Z' }
    ],
    actions: [
      { id: 'social_select_message', label: '选择消息', prompt: 'wechat-1', variant: 'secondary', kind: 'client' }
    ]
  }];
  doc.actions = [];
  doc.history = [];
  return doc;
}

function mediaAggregateDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'media';
  doc.title = 'Qwen Max 官方视频';
  doc.subtitle = '聚合展示 YouTube 和 Bilibili';
  doc.persona = {
    id: 'entertainment_companion',
    name: '娱乐搭子',
    avatarKey: 'entertainment',
    status: 'online',
    reason: '用户请求属于娱乐或媒体内容场景。'
  };
  doc.blocks = [{
    id: 'youtube-1',
    kind: 'generic-tool-result',
    title: 'YouTube video',
    subtitle: 'YouTube result.',
    status: 'success',
    source: 'YouTube Data API',
    metrics: [
      { label: 'source', value: 'YouTube Data API' },
      { label: 'toolName', value: 'media.video.search' }
    ],
    rows: [
      { label: 'Video ID', value: 'abc123' },
      { label: 'Watch URL', value: 'https://www.youtube.com/watch?v=abc123' }
    ],
    actions: [{
      id: 'media.open.web',
      label: '打开网页',
      prompt: 'https://www.youtube.com/watch?v=abc123',
      variant: 'primary',
      kind: 'client'
    }],
    mediaEmbed: {
      provider: 'YouTube',
      title: 'YouTube video',
      embedUrl: 'https://www.youtube.com/embed/abc123?playsinline=1&rel=0&enablejsapi=1&origin=https%3A%2F%2Faiphone.local',
      pageUrl: 'https://www.youtube.com/watch?v=abc123',
      thumbnail: 'https://i.ytimg.com/vi/abc123/mqdefault.jpg'
    }
  }, {
    id: 'bilibili-1',
    kind: 'generic-tool-result',
    title: 'Bilibili video',
    subtitle: 'Bilibili result.',
    status: 'success',
    source: '哔哩哔哩',
    metrics: [
      { label: 'source', value: '哔哩哔哩' },
      { label: 'toolName', value: 'media.video.search' }
    ],
    rows: [
      { label: 'BVID', value: 'BV1h57y6pE5o' },
      { label: 'Playback URL', value: 'https://www.bilibili.com/video/BV1h57y6pE5o' }
    ],
    actions: [{
      id: 'media.open.web',
      label: '打开网页',
      prompt: 'https://www.bilibili.com/video/BV1h57y6pE5o',
      variant: 'primary',
      kind: 'client'
    }],
    mediaEmbed: {
      provider: 'Bilibili',
      title: 'Bilibili video',
      embedUrl: 'https://player.bilibili.com/player.html?bvid=BV1h57y6pE5o&p=1&autoplay=0&poster=true&danmaku=0&isOutside=true',
      pageUrl: 'https://www.bilibili.com/video/BV1h57y6pE5o',
      thumbnail: 'https://i1.hdslb.com/bfs/archive/cover.jpg'
    }
  }];
  doc.actions = [];
  return doc;
}

function paymentDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'payment';
  doc.title = '确认支付';
  doc.subtitle = '支付前确认收款方和金额。';
  doc.blocks = [{
    id: 'payment-1',
    kind: 'generic-tool-result',
    title: '确认支付',
    subtitle: 'PayPal 将在用户确认后创建 checkout。',
    status: 'ready',
    source: 'PayPal',
    metrics: [
      { label: 'source', value: 'PayPal' },
      { label: 'toolName', value: 'payment.send' }
    ],
    rows: [
      { label: '收款方', value: 'Alex' },
      { label: '支付方式', value: 'paypal' },
      { label: '金额', value: '5 USD' },
      { label: '模式', value: 'test' }
    ],
    actions: [
      { id: 'payment.confirm', label: '确认支付', prompt: 'confirm', variant: 'primary', kind: 'prompt' },
      { id: 'payment.cancel', label: '取消', prompt: 'cancel', variant: 'secondary', kind: 'prompt' }
    ]
  }];
  doc.actions = [];
  doc.history = [];
  return doc;
}

function luckinPaymentDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'luckin';
  doc.title = '瑞幸订单';
  doc.subtitle = '';
  doc.chips = [];
  doc.metrics = [];
  doc.timeline = [];
  doc.blocks = [{
    id: 'luckin-payment-1',
    kind: 'generic-tool-result',
    title: '瑞幸订单已创建',
    subtitle: '',
    status: 'success',
    source: '瑞幸',
    metrics: [
      { label: 'source', value: '瑞幸' },
      { label: 'toolName', value: 'luckin.order.create' }
    ],
    rows: [
      { label: '订单号', value: 'LK20260711001' },
      { label: '门店', value: '瑞幸咖啡 深圳科技园店' },
      { label: '商品', value: '生椰拿铁 x1' },
      { label: '商品图', value: 'resource://rawfile/luckin_coconut.jpeg' },
      { label: '选项·糖度', value: '半糖:1|全糖:0' },
      { label: '选项·温度', value: '少冰:1|正常冰:0' },
      { label: '原价', value: '¥24' },
      { label: '优惠', value: '¥6' },
      { label: '应付', value: '¥18' }
    ],
    actions: [
      { id: 'luckin.pay.open', label: '打开微信支付', prompt: 'weixin://wxpay/bizpayurl?pr=abc', variant: 'primary', kind: 'client' },
      { id: 'luckin.demo.alipay.open', label: '支付宝支付（Demo）', prompt: 'alipays://', variant: 'secondary', kind: 'client' },
      { id: 'luckin.demo.googlepay.open', label: 'Google Pay 转 5 美金（Demo）', prompt: 'google pay', variant: 'secondary', kind: 'client' },
      { id: 'luckin.order.status', label: '刷新订单状态', prompt: '查询瑞幸订单状态', variant: 'secondary', kind: 'prompt' }
    ]
  }];
  doc.actions = [];
  doc.history = [];
  return doc;
}

function googlePayCheckoutDocumentFixture(): HtmlHomeDocument {
  const doc = paymentDocumentFixture();
  doc.title = '打开支付确认页';
  doc.blocks[0].title = '打开支付确认页';
  doc.blocks[0].subtitle = '将在 app 内打开 PayPal 确认页面，优先使用 Google Pay。';
  doc.blocks[0].status = 'needs_user';
  doc.blocks[0].rows = [
    { label: '收款方', value: 'Alex' },
    { label: '支付方式', value: 'PayPal' },
    { label: '金额', value: '5 USD' },
    { label: '模式', value: 'Test' },
    { label: '账号', value: 'alex@example.com' },
    { label: '付款方式偏好', value: 'Google Pay' },
    { label: '确认页', value: 'https://www.sandbox.paypal.com/checkoutnow?token=ORDER-1' }
  ];
  const checkoutArgs: GooglePayCheckoutArgsFixture = {
    provider: 'paypal',
    fundingSource: 'google_pay',
    amountText: '5.00',
    currency: 'USD',
    providerSessionId: 'ORDER-1',
    paypalClientId: 'paypal-client',
    paypalEnvironment: 'sandbox',
    paypalEmail: 'alex@example.com',
    paypalMerchantId: ''
  };
  const checkoutAction: HtmlHomeAction = {
    id: 'payment.checkout.open',
    label: '打开确认页',
    prompt: 'https://www.sandbox.paypal.com/checkoutnow?token=ORDER-1',
    variant: 'primary',
    kind: 'client',
    args: checkoutArgs
  };
  doc.blocks[0].actions = [checkoutAction];
  return doc;
}

function stripeReceivingDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'generic';
  doc.title = 'Stripe 收款账户';
  doc.subtitle = '继续 Stripe 托管认证。';
  doc.blocks = [{
    id: 'stripe-receiving',
    kind: 'StripeReceivingAccountCard',
    title: 'Stripe 收款账户',
    subtitle: 'Stripe 收款账户已创建。请继续 Stripe 托管认证。',
    status: 'onboarding_required',
    source: 'individual',
    metrics: [],
    rows: [
      { label: 'Agent', value: 'My Agent' },
      { label: 'Email', value: 'owner@example.com' },
      { label: 'Country', value: 'US' },
      { label: 'Stripe', value: 'acct_123' }
    ],
    actions: [{
      id: 'stripe.account.onboard',
      label: '继续认证',
      prompt: '打开 Stripe 认证',
      variant: 'primary',
      kind: 'client'
    }],
    stripeReceiving: {
      status: 'onboarding_required',
      message: '请继续 Stripe 托管认证。',
      stripeAccountId: 'acct_123',
      onboardingUrl: 'https://connect.stripe.com/setup/s/acct_123',
      currentlyDue: []
    }
  }];
  doc.actions = [];
  doc.history = [];
  return doc;
}

function socialHubDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'social';
  doc.title = '社交工作台';
  doc.subtitle = 'X, Slack, WeCom';
  doc.blocks = [{
    id: 'social_hub-item-0',
    kind: 'social-hub-item',
    title: '@openai',
    subtitle: 'Hello from X',
    status: 'unread',
    source: 'x',
    metrics: [
      { label: 'platform', value: 'x' },
      { label: 'kind', value: 'post' },
      { label: 'time', value: '2026-07-01T01:00:00.000Z' }
    ],
    rows: [
      { label: 'text', value: 'Hello from X' },
      { label: 'url', value: 'https://x.com/openai/status/1' }
    ],
    actions: [
      { id: 'social_hub_select_item', label: '查看', prompt: 'x-1', variant: 'secondary', kind: 'client' },
      { id: 'social_hub_draft_reply', label: '生成草稿', prompt: 'x-1', variant: 'secondary', kind: 'client' },
      { id: 'social_hub_open_source', label: '打开原文', prompt: 'https://x.com/openai/status/1', variant: 'secondary', kind: 'client' }
    ]
  }, {
    id: 'social_hub-connection-0',
    kind: 'social-hub-connection',
    title: 'Slack',
    subtitle: 'Slack token required',
    status: 'needs_auth',
    source: 'slack',
    metrics: [{ label: 'platform', value: 'slack' }],
    rows: [{ label: 'message', value: 'Slack token required' }],
    actions: []
  }, {
    id: 'social_hub-connection-1',
    kind: 'social-hub-connection',
    title: 'Discord',
    subtitle: 'Composio Discord auth required',
    status: 'needs_auth',
    source: 'discord',
    metrics: [{ label: 'platform', value: 'discord' }],
    rows: [{ label: 'message', value: 'Composio Discord auth required' }],
    actions: []
  }, {
    id: 'social_hub-connection-2',
    kind: 'social-hub-connection',
    title: 'LinkedIn',
    subtitle: 'Composio LinkedIn connected',
    status: 'connected',
    source: 'linkedin',
    metrics: [{ label: 'platform', value: 'linkedin' }],
    rows: [{ label: 'message', value: 'Composio LinkedIn connected' }],
    actions: []
  }, {
    id: 'social_hub-connection-3',
    kind: 'social-hub-connection',
    title: 'WhatsApp',
    subtitle: 'Composio WhatsApp auth required',
    status: 'needs_auth',
    source: 'whatsapp',
    metrics: [{ label: 'platform', value: 'whatsapp' }],
    rows: [{ label: 'message', value: 'Composio WhatsApp auth required' }],
    actions: []
  }, {
    id: 'social_hub-connection-4',
    kind: 'social-hub-connection',
    title: 'Instagram',
    subtitle: 'Composio Instagram connected',
    status: 'connected',
    source: 'instagram',
    metrics: [{ label: 'platform', value: 'instagram' }],
    rows: [{ label: 'message', value: 'Composio Instagram connected' }],
    actions: []
  }, {
    id: 'social_hub-draft',
    kind: 'social-hub-draft',
    title: '回复草稿',
    subtitle: 'local draft only; not sent',
    status: 'error',
    source: 'x',
    metrics: [{ label: 'platform', value: 'x' }],
    rows: [
      { label: 'text', value: 'Thanks for the update' },
      { label: 'error', value: 'local draft only; not sent' },
      { label: 'localOnly', value: 'true' },
      { label: 'sent', value: 'false' }
    ],
    actions: []
  }];
  doc.actions = [];
  return doc;
}

function expectCalmUtilityPalette(document: HtmlHomeDocument): void {
  const html = renderHtmlHomeDocument(document);
  expect(html.indexOf('--paper: #f5f2ee;')).assertLarger(-1);
  expect(html.indexOf('--ink: #211b17;')).assertLarger(-1);
  expect(html.indexOf('--accent: #995f4c;')).assertLarger(-1);
}

export default function htmlHomeRendererTest() {
  describe('htmlHomeRenderer', () => {
    it('uses the calm utility palette across result templates', 0, () => {
      expectCalmUtilityPalette(documentFixture());
      expectCalmUtilityPalette(calendarSearchDocumentFixture());
      expectCalmUtilityPalette(aggregateSearchDocumentFixture());
      expectCalmUtilityPalette(travelFoodCardsDocumentFixture());
      expectCalmUtilityPalette(foodDocumentFixture());
      expectCalmUtilityPalette(mediaAggregateDocumentFixture());
      expectCalmUtilityPalette(rideDocumentFixture());
      expectCalmUtilityPalette(paymentDocumentFixture());
    });

    it('returns a full HTML document with document content', 0, () => {
      const html = renderHtmlHomeDocument(documentFixture());

      expect(html.indexOf('<!DOCTYPE html>')).assertEqual(0);
      expect(html.indexOf('<html')).assertLarger(-1);
      expect(html.indexOf('Project Brief')).assertLarger(-1);
      expect(html.indexOf('Known Block')).assertLarger(-1);
      expect(html.indexOf('Run Action')).assertLarger(-1);
    });

    it('escapes dangerous script text in embedded JSON', 0, () => {
      const doc = documentFixture();
      doc.title = '</script><img src=x onerror=alert(1)>';

      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('</script><img')).assertEqual(-1);
      expect(html.indexOf('\\u003c/script\\u003e\\u003cimg')).assertLarger(-1);
    });

    it('includes the ArkWeb action bridge call', 0, () => {
      const html = renderHtmlHomeDocument(documentFixture());

      expect(html.indexOf('AIPhoneHome.postAction')).assertLarger(-1);
    });

    it('renders ride tool panel with no fake map before driver coordinates', 0, () => {
      const html = renderHtmlHomeDocument(rideDocumentFixture());

      expect(html.indexOf('data-ride-home')).assertLarger(-1);
      expect(html.indexOf("add(blocksHead, 'h2', '', isEnhancedScene() ? sceneSectionTitle() : '任务结果')")).assertEqual(-1);
      expect(html.indexOf('上下文')).assertEqual(-1);
      expect(html.indexOf('打车方案 · 实时叫车')).assertLarger(-1);
      expect(html.indexOf('去秋港花园')).assertLarger(-1);
      expect(html.indexOf('华为坂田基地 → 秋港花园')).assertLarger(-1);
      expect(html.indexOf('极速叫车')).assertLarger(-1);
      expect(html.indexOf('选择车型，确认叫车')).assertLarger(-1);
      expect(html.indexOf('未查询到司机坐标前不展示地图或真实路线')).assertEqual(-1);
      expect(html.indexOf('打开滴滴/高德不会自动下单')).assertEqual(-1);
      expect(html.indexOf('images.unsplash.com')).assertEqual(-1);
      expect(html.indexOf("rideAssetUrl('ride_cover_taxi_v2.png')")).assertLarger(-1);
      expect(html.indexOf('ride-cover-image')).assertLarger(-1);
      expect(html.indexOf('ride-cover-title')).assertLarger(-1);
      expect(html.indexOf('ride-hero-route')).assertEqual(-1);
      expect(html.indexOf('--ride-cover-image')).assertEqual(-1);
      expect(html.indexOf('ride_logo_didi.svg')).assertLarger(-1);
      expect(html.indexOf('ride_logo_amap.jpg')).assertLarger(-1);
      expect(html.indexOf('ride-cover-media')).assertLarger(-1);
      expect(html.indexOf('ride-route-map')).assertLarger(-1);
      expect(html.indexOf('ride-route-cities')).assertLarger(-1);
      expect(html.indexOf('ride-route-mid')).assertLarger(-1);
      expect(html.indexOf('ride-route-arrow-flow')).assertEqual(-1);
      expect(html.indexOf('M5%2016H4.5')).assertLarger(-1);
      expect(html.indexOf('MTUuODEyNSAxOS4zOTU0')).assertEqual(-1);
      expect(html.indexOf('travelPulse')).assertLarger(-1);
      expect(html.indexOf('ride-board')).assertLarger(-1);
      expect(html.indexOf('ride-panel-card')).assertLarger(-1);
      expect(html.indexOf('ride-user-prompt')).assertEqual(-1);
      expect(html.indexOf('ride-glass-extension')).assertEqual(-1);
      expect(html.indexOf('ride-card-cluster')).assertEqual(-1);
      expect(html.indexOf('ride-task-card::before')).assertEqual(-1);
      expect(html.indexOf('rideVehicleImage')).assertLarger(-1);
      expect(html.indexOf('ride_vehicle_discount.svg')).assertLarger(-1);
      expect(html.indexOf('ride_vehicle_express.svg')).assertLarger(-1);
      expect(html.indexOf('ride_vehicle_premium.svg')).assertLarger(-1);
      expect(html.indexOf('ride_vehicle_luxury.svg')).assertLarger(-1);
      expect(html.indexOf('ride-estimate-art')).assertLarger(-1);
      expect(html.indexOf('ride-estimate-price-decimal')).assertLarger(-1);
      expect(html.indexOf("formatRidePriceParts")).assertLarger(-1);
      expect(html.indexOf('ride-estimate-enter')).assertLarger(-1);
      expect(html.indexOf('ride-estimate-action')).assertLarger(-1);
      expect(html.indexOf('ride-estimate-source')).assertLarger(-1);
      expect(html.indexOf('ride-action-logo')).assertLarger(-1);
      expect(html.indexOf('setSelectedEstimate')).assertLarger(-1);
      expect(html.indexOf('rideActionForEstimate')).assertLarger(-1);
      expect(html.indexOf('ride-confirm-label')).assertLarger(-1);
      expect(html.indexOf('data-selected')).assertLarger(-1);
      expect(html.indexOf('打开滴滴')).assertLarger(-1);
      expect(html.indexOf('ride-status-strip')).assertLarger(-1);
      expect(html.indexOf('ride-action-primary')).assertLarger(-1);
      expect(html.indexOf('ride-action-link')).assertLarger(-1);
      expect(html.indexOf('rideEstimateBadge')).assertEqual(-1);
      expect(html.indexOf('ride-estimate-badge')).assertEqual(-1);
      expect(html.indexOf("item.category || '可选'")).assertEqual(-1);
    });

    it('renders ride driver map html with Amap script, markers, and fallback eta', 0, () => {
      const html = renderRideDriverMapHtml({
        routeText: '华为坂田基地 → 秋港花园',
        pickupLocation: '114.066231,22.657805',
        driverLocation: '114.060000,22.650000',
        driverName: '李师傅',
        etaText: '预计 6 分钟接驾',
        amapKey: 'amap-web-key',
        amapSecurityJsCode: ''
      });

      expect(html.indexOf('webapi.amap.com/maps')).assertLarger(-1);
      expect(html.indexOf('amap-web-key')).assertLarger(-1);
      expect(html.indexOf('114.066231')).assertLarger(-1);
      expect(html.indexOf('114.060000')).assertLarger(-1);
      expect(html.indexOf('AMap.Marker')).assertLarger(-1);
      expect(html.indexOf('AMap.Driving')).assertEqual(-1);
      expect(html.indexOf('new AMap.Driving({ map: map')).assertEqual(-1);
      expect(html.indexOf('restapi.amap.com/v5/direction/driving')).assertLarger(-1);
      expect(html.indexOf('rideMapRouteCallback')).assertLarger(-1);
      expect(html.indexOf('show_fields=cost,polyline')).assertLarger(-1);
      expect(html.indexOf('routeCostDuration')).assertLarger(-1);
      expect(html.indexOf('pathPolyline')).assertLarger(-1);
      expect(html.indexOf('AMap.Polyline')).assertLarger(-1);
      expect(html.indexOf('plannedPathFromRoute')).assertLarger(-1);
      expect(html.indexOf('routePathFromStep')).assertLarger(-1);
      expect(html.indexOf('emitRouteLog')).assertLarger(-1);
      expect(html.indexOf('rideMapRouteLog')).assertLarger(-1);
      expect(html.indexOf('search_start')).assertLarger(-1);
      expect(html.indexOf('search_complete')).assertLarger(-1);
      expect(html.indexOf('search_fallback')).assertLarger(-1);
      expect(html.indexOf('search_error')).assertLarger(-1);
      expect(html.indexOf('routeTimeSeconds')).assertLarger(-1);
      expect(html.indexOf('routeDistanceMeters')).assertLarger(-1);
      expect(html.indexOf('plannedPathPoints')).assertLarger(-1);
      expect(html.indexOf('function requestExitFullscreen')).assertEqual(-1);
      expect(html.indexOf('ride-map-exit')).assertEqual(-1);
      expect(html.indexOf("addEventListener('touchstart', handleExit")).assertEqual(-1);
      expect(html.indexOf("addEventListener('pointerup', handleExit")).assertEqual(-1);
      expect(html.indexOf('path: plannedPath')).assertLarger(-1);
      expect(html.indexOf('path: [driverLngLat, pickupLngLat]')).assertEqual(-1);
      expect(html.indexOf('rideMapEta')).assertLarger(-1);
      expect(html.indexOf('class="eta"')).assertEqual(-1);
      expect(html.indexOf('预计 6 分钟接驾')).assertLarger(-1);
    });

    it('renders ride driver map with fullscreen control and eta detail row', 0, () => {
      const html = renderHtmlHomeDocument(rideDriverDocumentFixture());

      expect(html.indexOf('ride-map-panel')).assertLarger(-1);
      expect(html.indexOf('ride-map-control')).assertLarger(-1);
      expect(html.indexOf('ride-map-head')).assertLarger(-1);
      expect(html.indexOf('ride-map-eta')).assertLarger(-1);
      expect(html.indexOf('data-ride-map-eta-value')).assertLarger(-1);
      expect(html.indexOf('全屏地图')).assertLarger(-1);
      expect(html.indexOf('退出全屏')).assertLarger(-1);
      expect(html.indexOf('ride-map-meta')).assertEqual(-1);
      expect(html.indexOf('ride-map-summary')).assertEqual(-1);
      expect(html.indexOf('ride-map-summary-badge')).assertEqual(-1);
      expect(html.indexOf('body.ride-map-fullscreen .ride-panel-card > :not(.ride-status-strip)')).assertLarger(-1);
      expect(html.indexOf('body.ride-map-fullscreen .ride-map-panel[data-fullscreen="true"] > .ride-map-head')).assertLarger(-1);
      expect(html.indexOf('touch-action: manipulation')).assertLarger(-1);
      expect(html.indexOf('function handleMapControlActivate')).assertLarger(-1);
      expect(html.indexOf("button.addEventListener('pointerup', handleMapControlActivate")).assertLarger(-1);
      expect(html.indexOf("button.addEventListener('touchend', handleMapControlActivate")).assertLarger(-1);
      expect(html.indexOf('lastMapControlActivateAt')).assertLarger(-1);
      expect(html.indexOf('window.__rideMapSetFullscreen')).assertLarger(-1);
      expect(html.indexOf("frame.contentWindow.postMessage({ type: 'rideMapFullscreen'")).assertEqual(-1);
      expect(html.indexOf("frame.setAttribute('sandbox'")).assertEqual(-1);
      expect(html.indexOf("frame.setAttribute('referrerpolicy', 'origin-when-cross-origin')")).assertLarger(-1);
      expect(html.indexOf('rideMapFullscreen')).assertEqual(-1);
      expect(html.indexOf('ride-map-exit')).assertEqual(-1);
      expect(html.indexOf('司机点位来自 provider 返回坐标')).assertEqual(-1);
      expect(html.indexOf('预计接驾时间')).assertLarger(-1);
      expect(html.indexOf('预计 6 分钟接驾')).assertLarger(-1);
      expect(html.indexOf("metricValue(block, ['selectedVehicleText', '车型', 'vehicle', 'productName', 'productCategory'])")).assertLarger(-1);
      expect(html.indexOf("addRideRouteStat(stats, '车型', rideVehicleStatText(block, estimates))")).assertLarger(-1);
      expect(html.indexOf('>车型</span><b>待查询</b>')).assertEqual(-1);
      expect(html.indexOf('data-ride-eta-value')).assertLarger(-1);
      expect(html.indexOf("updateRideEtaText(etaText)")).assertLarger(-1);
      expect(html.indexOf('function logRideMapRoute')).assertLarger(-1);
      expect(html.indexOf('ride.map.route.log')).assertLarger(-1);
      expect(html.indexOf('[AIPhone][RideMapRoute]')).assertLarger(-1);
      expect(html.indexOf('setRideMapFullscreen')).assertLarger(-1);
      expect(html.indexOf('ride-map-fullscreen')).assertLarger(-1);
      expect(html.indexOf('rideMapEta')).assertLarger(-1);
      expect(html.indexOf('rideMapRouteLog')).assertLarger(-1);
    });

    it('includes dynamic credential save and local action interception', 0, () => {
      const html = renderHtmlHomeDocument(dynamicCredentialDocumentFixture());

      expect(html.indexOf('data-scene="dynamic-tools"')).assertEqual(-1);
      expect(html.indexOf('Tool Console')).assertEqual(-1);
      expect(html.indexOf('tool-hero')).assertEqual(-1);
      expect(html.indexOf('tool-console')).assertEqual(-1);
      expect(html.indexOf('media-shell')).assertEqual(-1);
      expect(html.indexOf('任务结果')).assertLarger(-1);
      expect(html.indexOf('保存并测试')).assertLarger(-1);
      expect(html.indexOf('html_dynamic_save_and_test')).assertLarger(-1);
      expect(html.indexOf('handleLocalAction')).assertLarger(-1);
      expect(html.indexOf('travel_filter_train')).assertLarger(-1);
      expect(html.indexOf('food_filter_1km')).assertLarger(-1);
      expect(html.indexOf('client_sort_fastest')).assertLarger(-1);
      expect(html.indexOf('trainShowMore: false')).assertLarger(-1);
      expect(html.indexOf('localState.trainShowMore = !localState.trainShowMore')).assertLarger(-1);
      expect(html.indexOf('data-train-index')).assertLarger(-1);
      expect(html.indexOf('trainVisibleCount > 6')).assertLarger(-1);
    });

    it('disables HTML actions and credential save while busy', 0, () => {
      const html = renderHtmlHomeDocument(dynamicCredentialDocumentFixture(), true);

      expect(html.indexOf('"isBusy":true')).assertLarger(-1);
      expect(html.indexOf('if (isBusy) { return; }')).assertLarger(-1);
      expect(html.indexOf('button.disabled = isBusy')).assertLarger(-1);
    });

    it('keeps local empty-filter feedback without row-level flight retry', 0, () => {
      const html = renderHtmlHomeDocument(documentFixture());

      expect(html.indexOf("input.type = 'date'")).assertEqual(-1);
      expect(html.indexOf('flight_retry_date')).assertEqual(-1);
      expect(html.indexOf('updateVisibleCount')).assertLarger(-1);
      expect(html.indexOf('filter-empty')).assertLarger(-1);
    });

    it('keeps mobile text from overflowing and avoids fake remote base urls', 0, () => {
      const html = renderHtmlHomeDocument(documentFixture());

      expect(html.indexOf('overflow-wrap: anywhere')).assertLarger(-1);
      expect(html.indexOf('max-width: min(42%, 180px)')).assertLarger(-1);
      expect(html.indexOf('flex: 0 0 auto')).assertLarger(-1);
      expect(html.indexOf('https://aiphone.local')).assertEqual(-1);
    });

    it('renders aggregate search videos separately from posts and source issues', 0, () => {
      const html = renderHtmlHomeDocument(aggregateSearchDocumentFixture(), false);

      expect(html.indexOf('aggregate-shell')).assertLarger(-1);
      expect(html.indexOf('视频')).assertLarger(-1);
      expect(html.indexOf('讨论')).assertLarger(-1);
      expect(html.indexOf('Codex demo')).assertLarger(-1);
      expect(html.indexOf('OpenAI Codex discussion')).assertLarger(-1);
      expect(html.indexOf('data-filter="reddit"')).assertLarger(-1);
      expect(html.indexOf('aggregate-source-overview')).assertLarger(-1);
      expect(html.indexOf('YouTube returned 1 row')).assertLarger(-1);
      expect(html.indexOf('状态摘要')).assertLarger(-1);
      expect(html.indexOf('ZHIHU_API_KEY')).assertLarger(-1);
      expect(html.indexOf('异常或提示')).assertEqual(-1);
    });

    it('keeps travel and food card details collapsed behind source aware expansion hooks', 0, () => {
      const doc = travelFoodCardsDocumentFixture();
      doc.persona = {
        id: 'travel_companion',
        name: '旅行搭子',
        avatarKey: 'travel',
        status: 'online',
        reason: '用户请求属于旅行或出行规划场景。'
      };
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('itinerary-shell')).assertLarger(-1);
      expect(html.indexOf('route-hero')).assertLarger(-1);
      expect(html.indexOf('route-map')).assertLarger(-1);
      expect(html.indexOf('font-family: Georgia')).assertLarger(-1);
      expect(html.indexOf('route-kicker::before')).assertLarger(-1);
      expect(html.indexOf('journey-tag.train::before')).assertLarger(-1);
      expect(html.indexOf("journey-tag ' + source")).assertLarger(-1);
      expect(html.indexOf('travel-controls')).assertLarger(-1);
      expect(html.indexOf('journey-board')).assertLarger(-1);
      expect(html.indexOf('journey-card')).assertLarger(-1);
      expect(html.indexOf('出行方案 · 实时候选')).assertLarger(-1);
      expect(html.indexOf('"name":"旅行搭子"')).assertLarger(-1);
      expect(html.indexOf('用户请求属于旅行或出行规划场景。')).assertLarger(-1);
      expect(html.indexOf('renderPersonaBanner(hero)')).assertLarger(-1);
      expect(html.indexOf('G123')).assertLarger(-1);
      expect(html.indexOf('麦当劳 科技园店')).assertLarger(-1);
      expect(html.indexOf("var price = metric(block, ['price']);")).assertLarger(-1);
      expect(html.indexOf("'¥' + price + '起'")).assertLarger(-1);
      expect(html.indexOf("add(mainline, 'div', 'journey-price')")).assertLarger(-1);
      expect(html.indexOf("summaryMetrics.push(['', '¥' + price + '起'])")).assertEqual(-1);
      expect(html.indexOf('grid-column: 4')).assertLarger(-1);
      expect(html.indexOf('去购票')).assertLarger(-1);
      expect(html.indexOf('二等座起')).assertEqual(-1);
      expect(html.indexOf('train.booking.open')).assertLess(html.indexOf('html_pin_travel'));
      expect(html.indexOf('html_pin_travel')).assertLarger(-1);
      expect(html.indexOf('html_open_food_map')).assertLarger(-1);
      expect(html.indexOf('AIPhoneHome.postAction')).assertLarger(-1);
      expect(html.indexOf('travel_filter_train')).assertLarger(-1);
      expect(html.indexOf('travel_filter_flight')).assertLarger(-1);
      expect(html.indexOf('client_sort_fastest')).assertLarger(-1);
      expect(html.indexOf('client_filter_available')).assertLarger(-1);
      expect(html.indexOf('client_show_more')).assertLarger(-1);
      expect(html.indexOf("state.trainShowMore = !state.trainShowMore")).assertLarger(-1);
      expect(html.indexOf('function displayTime(value)')).assertLarger(-1);
      expect(html.indexOf("displayTime(metric(block, ['depart', 'depTime']))")).assertLarger(-1);
      expect(html.indexOf('white-space: nowrap')).assertLarger(-1);
      expect(html.indexOf('data-source="train"')).assertLarger(-1);
      expect(html.indexOf('data-source="food"')).assertLarger(-1);
      expect(html.indexOf('data-duration')).assertLarger(-1);
      expect(html.indexOf('data-availability')).assertLarger(-1);
      expect(html.indexOf('classList.toggle')).assertLarger(-1);
      expect(html.indexOf('expandedKey')).assertLarger(-1);
      expect(html.indexOf('querySelectorAll')).assertLarger(-1);
      expect(html.indexOf('.journey-card:not(.expanded) .journey-detail')).assertLarger(-1);
      expect(html.indexOf("button.textContent = expanded ? '收起' : '展开'")).assertLarger(-1);
      expect(html.indexOf("add(top, 'button', 'journey-expand', '展开')")).assertLarger(-1);
      expect(html.indexOf("add(statusWrap, 'button', 'expand-button', '详情')")).assertEqual(-1);
      expect(html.indexOf('detailRow(grid')).assertLarger(-1);
      expect(html.indexOf('function labelText(label)')).assertLarger(-1);
      expect(html.indexOf("if (raw === 'source') { return '来源'; }")).assertLarger(-1);
      expect(html.indexOf('event.stopPropagation()')).assertLarger(-1);
      expect(html.indexOf('sourceKind')).assertLarger(-1);
      expect(html.indexOf('Food Field')).assertEqual(-1);
      expect(html.indexOf('附近餐饮探索')).assertEqual(-1);
      expect(html.indexOf('ReactDOM')).assertEqual(-1);
    });

    it('renders food documents with the food scene template and preserves actions', 0, () => {
      const html = renderHtmlHomeDocument(foodDocumentFixture());

      expect(html.indexOf('editorial-food-shell')).assertLarger(-1);
      expect(html.indexOf('editorial-cover')).assertLarger(-1);
      expect(html.indexOf('editorial-tabs')).assertLarger(-1);
      expect(html.indexOf('editorial-feature')).assertLarger(-1);
      expect(html.indexOf('photo-1552566626-52f8b828add9')).assertLarger(-1);
      expect(html.indexOf('editorial-list')).assertLarger(-1);
      expect(html.indexOf('merchant-avatar')).assertLarger(-1);
      expect(html.indexOf('merchant-avatar-fallback')).assertLarger(-1);
      expect(html.indexOf('AVATAR_MCDONALDS')).assertLarger(-1);
      expect(html.indexOf('AVATAR_KFC')).assertLarger(-1);
      expect(html.indexOf('AVATAR_TAOBAO')).assertLarger(-1);
      expect(html.indexOf('AVATAR_AMAP')).assertLarger(-1);
      expect(html.indexOf('AVATAR_TENCENT')).assertLarger(-1);
      expect(html.indexOf('AVATAR_BAIDU')).assertLarger(-1);
      expect(html.indexOf('AVATAR_MEITUAN')).assertLarger(-1);
      expect(html.indexOf('AVATAR_LUCKIN')).assertLarger(-1);
      expect(html.indexOf('AVATAR_GOOGLE_MAPS')).assertLarger(-1);
      expect(html.indexOf("var AVATAR_LOCAL = '';")).assertLarger(-1);
      expect(html.indexOf('function addAvatar(parent, block)')).assertLarger(-1);
      expect(html.indexOf('addAvatar(head, block)')).assertLarger(-1);
      expect(html.indexOf('border-radius: 999px')).assertLarger(-1);
      expect(html.indexOf('今日附近值得吃')).assertLarger(-1);
      expect(html.indexOf('附近餐饮 · 今日编辑')).assertLarger(-1);
      expect(html.indexOf('今日编辑')).assertLarger(-1);
      expect(html.indexOf('高德 / 腾讯地图')).assertLarger(-1);
      expect(html.indexOf('三津汤包 (深圳北站店)')).assertLarger(-1);
      expect(html.indexOf('N多寿司 (深圳北站店)')).assertLarger(-1);
      expect(html.indexOf('麦当劳 (深圳北站店)')).assertLarger(-1);
      expect(html.indexOf('未知坐标小吃档')).assertLarger(-1);
      expect(html.indexOf('data-source-key="food-amap"')).assertLarger(-1);
      expect(html.indexOf('data-source-key="food-local"')).assertLarger(-1);
      expect(html.indexOf('data-source-key="food-meituan"')).assertLarger(-1);
      expect(html.indexOf('data-source-key="food-taobao"')).assertLarger(-1);
      expect(html.indexOf('data-source-key="food-mcd"')).assertLarger(-1);
      expect(html.indexOf('data-source-key="food-luckin"')).assertLarger(-1);
      expect(html.indexOf('food-google-maps')).assertLarger(-1);
      expect(html.indexOf('html_open_food_map')).assertLarger(-1);
      expect(html.indexOf('html_pin_food')).assertLarger(-1);
      expect(html.indexOf('导航去')).assertLarger(-1);
      expect(html.indexOf('固定到桌面')).assertLarger(-1);
      expect(html.indexOf('AIPhoneHome.postAction')).assertLarger(-1);
      expect(html.indexOf('food_filter_1km')).assertLarger(-1);
      expect(html.indexOf("if (id === 'food_filter_1km')")).assertLarger(-1);
      expect(html.indexOf("state.filter = 'within_1km'")).assertLarger(-1);
      expect(html.indexOf("if (id === 'food_filter_1km') { state.filter = 'within_1km'; applyFilter(); return true; }")).assertLarger(-1);
      expect(html.indexOf("if (feature) { feature.style.display = matchesFilter(feature) ? '' : 'none'; }")).assertLarger(-1);
      expect(html.indexOf("feature.setAttribute('data-search'")).assertLarger(-1);
      expect(html.indexOf("['food_show_more', '展示更多'")).assertEqual(-1);
      expect(html.indexOf("id === 'food_show_more'")).assertEqual(-1);
      expect(html.indexOf('state.showMore')).assertEqual(-1);
      expect(html.indexOf('visible >= 6')).assertEqual(-1);
      expect(html.indexOf('function sourceParts(block)')).assertLarger(-1);
      expect(html.indexOf("card.setAttribute('data-source-key', sourceKey(block))")).assertLarger(-1);
      expect(html.indexOf("raw.indexOf('美团')")).assertLarger(-1);
      expect(html.indexOf("raw.indexOf('麦当劳')")).assertLarger(-1);
      expect(html.indexOf("id === 'html_open_food_map' ? '导航去' : '固定到桌面'")).assertLarger(-1);
      expect(html.indexOf('var canNavigate = hasLocation(block)')).assertLarger(-1);
      expect(html.indexOf('if (!canNavigate) { return false; }')).assertLarger(-1);
      expect(html.indexOf('setExpanded(key)')).assertLarger(-1);
      expect(html.indexOf('Food Field')).assertEqual(-1);
      expect(html.indexOf('附近餐饮探索')).assertEqual(-1);
      expect(html.indexOf('window.AMap')).assertEqual(-1);
      expect(html.indexOf('webapi.amap.com')).assertEqual(-1);
      expect(html.indexOf('ReactDOM')).assertEqual(-1);
    });

    it('renders payment documents with the app payment workspace and saved payee form', 0, () => {
      const html = renderHtmlHomeDocument(paymentDocumentFixture());

      expect(html.indexOf('payment-shell')).assertLarger(-1);
      expect(html.indexOf('pay-hero')).assertLarger(-1);
      expect(html.indexOf('payment-card')).assertLarger(-1);
      expect(html.indexOf('payee-card')).assertLarger(-1);
      expect(html.indexOf('provider-logo')).assertLarger(-1);
      expect(html.indexOf('addProviderMark')).assertLarger(-1);
      expect(html.indexOf('GOOGLE_PAY_ICON')).assertLarger(-1);
      expect(html.indexOf('data:image/svg+xml;base64')).assertLarger(-1);
      expect(html.indexOf('data:image/svg+xml;charset=UTF-8')).assertEqual(-1);
      expect(html.indexOf('form-actions')).assertLarger(-1);
      expect(html.indexOf("add(shell, 'details', 'payee-card')")).assertLarger(-1);
      expect(html.indexOf('form.open = !block')).assertLarger(-1);
      expect(html.indexOf("add(parent, 'details', 'detail-more')")).assertLarger(-1);
      expect(html.indexOf('visibleCount >= 4')).assertLarger(-1);
      expect(html.indexOf('.detail-more[open] .detail-more-grid')).assertLarger(-1);
      expect(html.indexOf('AIPhone Pay')).assertLarger(-1);
      expect(html.indexOf('添加付款对象')).assertLarger(-1);
      expect(html.indexOf('保存对象')).assertLarger(-1);
      expect(html.indexOf('payment.account.save')).assertLarger(-1);
      expect(html.indexOf('payee-paypal')).assertLarger(-1);
      expect(html.indexOf('payee-stripe-link')).assertLarger(-1);
      expect(html.indexOf('AIPhoneHome.postAction')).assertLarger(-1);
      expect(html.indexOf('任务结果')).assertEqual(-1);
      expect(html.indexOf('保存后可以直接说')).assertEqual(-1);
    });

    it('renders PayPal Google Pay checkout inline with the payment actions', 0, () => {
      const doc = googlePayCheckoutDocumentFixture();
      doc.blocks.unshift(paymentDocumentFixture().blocks[0]);
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('google-pay-action')).assertLarger(-1);
      expect(html.indexOf('google-pay-placeholder')).assertLarger(-1);
      expect(html.indexOf('Pay with G Pay')).assertLarger(-1);
      expect(html.indexOf('paypal.Googlepay')).assertLarger(-1);
      expect(html.indexOf('https://pay.google.com/gp/p/js/pay.js')).assertLarger(-1);
      expect(html.indexOf('components=googlepay')).assertLarger(-1);
      expect(html.indexOf('payment.capture')).assertLarger(-1);
      expect(html.indexOf('检测并显示')).assertEqual(-1);
      expect(html.indexOf('google-pay-panel')).assertEqual(-1);
      expect(html.indexOf('mountGooglePayButton(slot, status, config);')).assertLarger(-1);
      expect(html.indexOf('openAfterReady')).assertEqual(-1);
      expect(html.indexOf('Google Pay 已准备好，请点上方按钮打开确认面板。')).assertLarger(-1);
      expect(html.indexOf('window.setTimeout(function () {')).assertLarger(-1);
      expect(html.indexOf("if (state === 'loading' || state === 'ready') { return; }")).assertLarger(-1);
      expect(html.indexOf("kept.filter(function (action) { return text(action.variant) === 'primary'; }).forEach(addActionButton);")).assertLarger(-1);
      expect(html.indexOf("kept.filter(function (action) { return text(action.variant) !== 'primary'; }).forEach(addActionButton);")).assertLarger(-1);
      expect(html.indexOf('.google-pay-action { grid-column: 1 / -1; width: 100%; max-width: none; }')).assertLarger(-1);
      expect(html.indexOf('document.head.appendChild(script);')).assertLarger(-1);
      expect(html.indexOf('if (!existing) {\\n        document.head.appendChild(script);')).assertEqual(-1);
      expect(html.indexOf('手机 WebView 当前访问不了 Google Pay SDK')).assertLarger(-1);
      expect(html.indexOf('Google Pay 确认面板')).assertLarger(-1);
      expect(html.indexOf('PAYER_ACTION_REQUIRED')).assertLarger(-1);
      expect(html.indexOf('initiatePayerAction')).assertLarger(-1);
    });

    it('auto-opens Stripe onboarding links after account setup', 0, () => {
      const html = renderHtmlHomeDocument(stripeReceivingDocumentFixture());

      expect(html.indexOf('autoOpenStripeReceivingOnboarding')).assertLarger(-1);
      expect(html.indexOf('stripe.account.open')).assertLarger(-1);
      expect(html.indexOf('AIPhoneHome.postAction')).assertLarger(-1);
      expect(html.indexOf('https://connect.stripe.com/setup/s/acct_123')).assertLarger(-1);
      expect(html.indexOf('window.location.href = url')).assertEqual(-1);
    });

    it('uses Stripe receiving action URL in the payment scene', 0, () => {
      const doc = stripeReceivingDocumentFixture();
      const staleAction: HtmlHomeAction = {
        id: 'stripe.account.open',
        label: '打开 Stripe 托管认证',
        prompt: '打开 Stripe 托管认证',
        variant: 'primary',
        kind: 'client'
      };
      doc.kind = 'payment';
      doc.actions = [staleAction];
      doc.blocks.unshift({
        id: 'payment-summary',
        kind: 'generic-tool-result',
        title: 'Stripe 收款',
        subtitle: 'summary',
        status: 'needs_user',
        source: 'payment',
        metrics: [],
        rows: [{ label: 'toolName', value: 'payment.send' }],
        actions: [staleAction]
      });
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf("blocks[index].kind === 'StripeReceivingAccountCard'")).assertLarger(-1);
      expect(html.indexOf('actionForBlock(action, block)')).assertLarger(-1);
      expect(html.indexOf('https://connect.stripe.com/setup/s/acct_123')).assertLarger(-1);
    });

    it('keeps non-food documents on the generic renderer', 0, () => {
      const html = renderHtmlHomeDocument(documentFixture());

      expect(html.indexOf('food-scene-shell')).assertEqual(-1);
      expect(html.indexOf('data-scene="generic"')).assertEqual(-1);
      expect(html.indexOf('result-hero')).assertEqual(-1);
      expect(html.indexOf('result-canvas')).assertEqual(-1);
      expect(html.indexOf('calendar-shell')).assertEqual(-1);
      expect(html.indexOf('任务结果')).assertLarger(-1);
      expect(html.indexOf('Project Brief')).assertLarger(-1);
    });

    it('renders Google Maps result blocks with an in-app map preview', 0, () => {
      const html = renderHtmlHomeDocument(googleMapsDocumentFixture());

      expect(html.indexOf('google-map-preview')).assertLarger(-1);
      expect(html.indexOf("text(block && block.kind) === 'generic-tool-result' && text(block && block.source).length > 0")).assertLarger(-1);
      expect(html.indexOf("url + (url.indexOf('?') >= 0 ? '&' : '?') + 'output=embed'")).assertLarger(-1);
      expect(html.indexOf('22.609878,114.029506')).assertLarger(-1);
      expect(html.indexOf('maps.open.web')).assertLarger(-1);
      expect(html.indexOf('打开 Google Maps')).assertLarger(-1);
      expect(html.indexOf("window.open(text(action && action.prompt), '_blank')")).assertLarger(-1);
      expect(html.indexOf('opacity: 0.18')).assertEqual(-1);
      expect(html.indexOf('content: "Maps"')).assertEqual(-1);
      expect(html.indexOf('calendar-shell')).assertEqual(-1);
    });

    it('renders WhatsApp send confirmation as one clean card', 0, () => {
      const doc = documentFixture();
      doc.kind = 'dynamic-tools';
      doc.blocks = [{
        id: 'whatsapp-send-confirm',
        kind: 'generic-tool-result',
        title: '确认发送 WhatsApp 消息',
        subtitle: '将通过已授权的 WhatsApp Business 账号发送。',
        status: 'confirm_required',
        source: 'Composio WhatsApp Business',
        metrics: [
          { label: 'source', value: 'Composio WhatsApp Business' },
          { label: 'toolName', value: 'whatsapp.message.send' }
        ],
        rows: [
          { label: '收件人', value: '+8613800138000' },
          { label: '消息', value: 'test' }
        ],
        rawPreview: 'confirm whatsapp send to=+8613800138000',
        actions: [{
          id: 'whatsapp.message.send.confirm',
          label: '确认发送',
          prompt: '确认通过 WhatsApp Business 发送消息',
          variant: 'danger',
          kind: 'prompt'
        }]
      }];
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('whatsapp-send-card')).assertLarger(-1);
      expect(html.indexOf('.whatsapp-send-card::before')).assertLarger(-1);
      expect(html.indexOf('.whatsapp-send-card .actions')).assertLarger(-1);
      expect(html.indexOf('.whatsapp-send-card .action')).assertLarger(-1);
      expect(html.indexOf('function whatsAppSendActions(block)')).assertLarger(-1);
      expect(html.indexOf("key === 'composio-whatsapp' && isWhatsAppSendBlock(block)")).assertLarger(-1);
    });

    it('renders Composio results with app logos and visible preview cards', 0, () => {
      const html = renderHtmlHomeDocument(composioResultsDocumentFixture());

      expect(html.indexOf('composio-preview')).assertLarger(-1);
      expect(html.indexOf('composio-app-logo')).assertLarger(-1);
      expect(html.indexOf('cdn.simpleicons.org')).assertEqual(-1);
      expect(html.indexOf('logos.composio.dev')).assertEqual(-1);
      expect(html.indexOf('composio-github')).assertLarger(-1);
      expect(html.indexOf('composio-drive')).assertLarger(-1);
      expect(html.indexOf('composio-docs')).assertLarger(-1);
      expect(html.indexOf('composio-slack')).assertLarger(-1);
      expect(html.indexOf('composio-notion')).assertLarger(-1);
      expect(html.indexOf('composio-linear')).assertLarger(-1);
      expect(html.indexOf('composio-asana')).assertLarger(-1);
      expect(html.indexOf('composio-trello')).assertLarger(-1);
      expect(html.indexOf('composio-outlook')).assertLarger(-1);
      expect(html.indexOf('composio-discord')).assertLarger(-1);
      expect(html.indexOf('composio-linkedin')).assertLarger(-1);
      expect(html.indexOf('composio-whatsapp')).assertLarger(-1);
      expect(html.indexOf('composio-instagram')).assertLarger(-1);
      expect(html.indexOf('composio-spotify')).assertLarger(-1);
      expect(html.indexOf('composio-tiktok')).assertLarger(-1);
      expect(html.indexOf('composio-ticketmaster')).assertLarger(-1);
      expect(html.indexOf('composio-hubspot')).assertLarger(-1);
      expect(html.indexOf('composio-salesforce')).assertLarger(-1);
      expect(html.indexOf('Add Composio result cards')).assertLarger(-1);
      expect(html.indexOf('签证材料.pdf')).assertLarger(-1);
      expect(html.indexOf('AIPhoneDemo 设计文档')).assertLarger(-1);
      expect(html.indexOf('AIPhoneDemo demo ready')).assertLarger(-1);
      expect(html.indexOf('AIPhoneDemo follow-up')).assertLarger(-1);
      expect(html.indexOf('Discord AIPhoneDemo thread')).assertLarger(-1);
      expect(html.indexOf('AIPhoneDemo launch note')).assertLarger(-1);
      expect(html.indexOf('AIPhoneDemo WhatsApp note')).assertLarger(-1);
      expect(html.indexOf('AIPhoneDemo reel comment')).assertLarger(-1);
      expect(html.indexOf('AIPhoneDemo Demo Flow')).assertLarger(-1);
      expect(html.indexOf('AIPhoneDemo short demo')).assertLarger(-1);
      expect(html.indexOf('Shenzhen Live')).assertLarger(-1);
      expect(html.indexOf('打开结果')).assertLarger(-1);
    });

    it('renders Google Calendar search results as a day week month workspace', 0, () => {
      const html = renderHtmlHomeDocument(calendarSearchDocumentFixture());

      expect(html.indexOf('calendar-shell')).assertLarger(-1);
      expect(html.indexOf('<div class="calendar-status-bar')).assertEqual(-1);
      expect(html.indexOf('Google Calendar API 查询成功。')).assertEqual(
        html.lastIndexOf('Google Calendar API 查询成功。')
      );
      expect(html.indexOf('calendar-view-day')).assertLarger(-1);
      expect(html.indexOf('calendar-view-week')).assertLarger(-1);
      expect(html.indexOf('calendar-view-month')).assertLarger(-1);
      expect(html.indexOf('data-calendar-view="day"')).assertLarger(-1);
      expect(html.indexOf('calendar-delete-button')).assertLarger(-1);
      expect(html.indexOf('<button type="button" class="calendar-delete-button" style="display:none"'))
        .assertLarger(-1);
      expect(html.indexOf(
        "deleteButton.style.display = selectedDeleteActionId === 'calendar.event.delete.confirm' ? " +
        "'inline-flex' : 'none';"
      )).assertLarger(-1);
      expect(html.indexOf('calendar-confirm-delete')).assertLarger(-1);
      expect(html.indexOf('calendar.event.delete.confirm')).assertLarger(-1);
      expect(html.indexOf("var selectedDeleteAction = '';")).assertLarger(-1);
      expect(html.indexOf('var action = JSON.parse(selectedDeleteAction);')).assertLarger(-1);
      expect(html.indexOf("label: '确认删除日程'")).assertEqual(-1);
      expect(html.indexOf('confirmed: true')).assertEqual(-1);
      expect(html.indexOf('AIPhoneHome.postAction')).assertLarger(-1);
      expect(html.indexOf('Google Calendar API')).assertLarger(-1);
      expect(html.indexOf('产品同步')).assertLarger(-1);
      expect(html.indexOf('10:00')).assertLarger(-1);
      expect(html.indexOf('images.unsplash.com/photo-1506784983877-45594efa4cbe')).assertLarger(-1);
      expect(html.indexOf('min-height: 302px')).assertLarger(-1);
      expect(html.indexOf('calendar-detail-grid')).assertEqual(-1);
      expect(html.indexOf('data-detail-source')).assertEqual(-1);
      expect(html.indexOf('data-detail-id')).assertEqual(-1);
      expect(html.indexOf('任务结果')).assertEqual(-1);
    });

    it('keeps other monthly events out of the selected day timeline', 0, () => {
      const doc = calendarSearchDocumentFixture();
      doc.blocks.push({
        id: 'calendar-search-21',
        kind: 'generic-tool-result',
        title: '月中复盘',
        subtitle: 'Google Calendar API 查询成功。',
        status: 'success',
        source: 'Google Calendar API',
        metrics: [
          { label: 'source', value: 'Google Calendar API' },
          { label: 'toolName', value: 'calendar.events.search' }
        ],
        rows: [
          { label: 'Event ID', value: 'event-21' },
          { label: 'Start', value: '2026-07-21T11:00:00+08:00' },
          { label: 'End', value: '2026-07-21T11:30:00+08:00' }
        ],
        actions: []
      });
      doc.blocks.push({
        id: 'calendar-search-30',
        kind: 'generic-tool-result',
        title: '月底发布',
        subtitle: 'Google Calendar API 查询成功。',
        status: 'success',
        source: 'Google Calendar API',
        metrics: [
          { label: 'source', value: 'Google Calendar API' },
          { label: 'toolName', value: 'calendar.events.search' }
        ],
        rows: [
          { label: 'Event ID', value: 'event-30' },
          { label: 'Start', value: '2026-07-30T15:00:00+08:00' },
          { label: 'End', value: '2026-07-30T15:30:00+08:00' }
        ],
        actions: []
      });

      const html = renderHtmlHomeDocument(doc);
      const dayStart = html.indexOf('<section class="calendar-view calendar-view-day active"');
      const weekStart = html.indexOf('<section class="calendar-view calendar-view-week"');
      const dayHtml = html.substring(dayStart, weekStart);

      expect(dayHtml.indexOf('产品同步')).assertLarger(-1);
      expect(dayHtml.indexOf('月中复盘')).assertEqual(-1);
      expect(dayHtml.indexOf('月底发布')).assertEqual(-1);
      expect(html.indexOf('月中复盘')).assertLarger(-1);
      expect(html.indexOf('月底发布')).assertLarger(-1);
    });

    it('submits a Calendar delete confirmation card without another drawer or modal', 0, () => {
      const html = renderHtmlHomeDocument(calendarDeleteConfirmationDocumentFixture());

      expect(html.indexOf('data-delete-confirm="true"')).assertLarger(-1);
      expect(html.indexOf('function postCalendarWrite(card)')).assertLarger(-1);
      expect(html.indexOf('calendar.event.delete.confirm')).assertLarger(-1);
      expect(html.indexOf('<aside class="calendar-detail-drawer">')).assertEqual(-1);
    });

    it('renders a completed Calendar delete as only a success result', 0, () => {
      const html = renderHtmlHomeDocument(calendarDeleteSuccessDocumentFixture());

      expect(html.indexOf('日程已删除')).assertLarger(-1);
      expect(html.indexOf('calendar-delete-success-card')).assertLarger(-1);
      expect(html.indexOf('<main class="calendar-shell">')).assertEqual(-1);
      expect(html.indexOf('<nav class="calendar-view-switch"')).assertEqual(-1);
      expect(html.indexOf('<button class="calendar-delete-button"')).assertEqual(-1);
      expect(html.indexOf('Composio')).assertEqual(-1);
      expect(html.indexOf('Event ID')).assertEqual(-1);
      expect(html.indexOf('把上一条日程改到明天下午4点30分')).assertEqual(-1);
    });

    it('renders Maps routes without debug rows or an eager map iframe', 0, () => {
      const html = renderHtmlHomeDocument(googleMapsRouteDocumentFixture());

      expect(html.indexOf("function isGoogleMapsRouteBlock(block)")).assertLarger(-1);
      expect(html.indexOf("if (!isGoogleMapsBlock(block) || isGoogleMapsRouteBlock(block)) { return; }")).assertLarger(-1);
      expect(html.indexOf("addActions(detailHost, mapsRouteActions(block))")).assertLarger(-1);
      expect(html.indexOf('在 App 内查看路线')).assertEqual(-1);
    });

    it('uses the requested Google Calendar search window for empty results', 0, () => {
      const html = renderHtmlHomeDocument(calendarEmptySearchDocumentFixture());

      expect(html.indexOf('7月2日 周四')).assertLarger(-1);
      expect(html.indexOf('无定时日程')).assertLarger(-1);
      expect(html.indexOf('这个时间窗没有可放入时间轴的日程')).assertLarger(-1);
      expect(html.indexOf('6月25日')).assertEqual(-1);
    });

    it('does not mark Google Calendar as synced when Composio auth is missing', 0, () => {
      const doc = calendarEmptySearchDocumentFixture();
      doc.subtitle = 'Composio 用户 aiphone-luoyige 没有 ACTIVE connected account';
      doc.blocks[0].subtitle = doc.subtitle;
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('Google Calendar API · 待授权')).assertLarger(-1);
      expect(html.indexOf('Google Calendar API · 已同步')).assertEqual(-1);
    });

    it('shows the complete Google Calendar provider error without a false synced state', 0, () => {
      const doc = calendarEmptySearchDocumentFixture();
      doc.subtitle = 'invalid request data provided: start_datetime is required';
      doc.blocks[0].status = 'error';
      doc.blocks[0].subtitle = doc.subtitle;
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('Google Calendar API · 同步失败')).assertLarger(-1);
      expect(html.indexOf('calendar-status-bar')).assertEqual(-1);
      expect(html.indexOf('invalid request data provided: start_datetime is required')).assertLarger(-1);
      expect(html.indexOf('overflow-wrap: anywhere')).assertLarger(-1);
      expect(html.indexOf('.calendar-undated-card h3,\n.calendar-undated-card p {\n  overflow-wrap: anywhere;\n  white-space: normal;')).assertLarger(-1);
      expect(html.indexOf('Google Calendar API · 已同步')).assertEqual(-1);
    });

    it('renders Google Calendar create results as a write confirmation', 0, () => {
      const html = renderHtmlHomeDocument(calendarCreateDocumentFixture());

      expect(html.indexOf('calendar-confirmation')).assertLarger(-1);
      expect(html.indexOf('一对一会议')).assertLarger(-1);
      expect(html.indexOf('16:30')).assertLarger(-1);
      expect(html.indexOf('17:00')).assertLarger(-1);
      expect(html.indexOf('已写入')).assertLarger(-1);
    });

    it('labels a successful Google Calendar update as updated rather than written', 0, () => {
      const update = calendarCreateDocumentFixture();
      update.blocks[0].metrics[1].value = 'calendar.event.update';
      const html = renderHtmlHomeDocument(update);

      expect(html.indexOf('已更新 Google Calendar')).assertLarger(-1);
      expect(html.indexOf('Google Calendar API · 已更新')).assertLarger(-1);
      expect(html.indexOf('已写入 Google Calendar')).assertEqual(-1);
    });

    it('keeps Calendar create and update reviews visibly pending until provider success', 0, () => {
      const create = calendarCreateDocumentFixture();
      create.subtitle = '请核对当前日程参数；只有点击此卡片上的精确操作才会调用 Provider。';
      create.blocks[0].status = 'confirm_required';
      create.blocks[0].subtitle = create.subtitle;
      const update = calendarCreateDocumentFixture();
      update.subtitle = create.subtitle;
      update.blocks[0].status = 'confirm_required';
      update.blocks[0].subtitle = update.subtitle;
      update.blocks[0].metrics[1].value = 'calendar.event.update';
      create.blocks[0].actions = [{
        id: 'calendar.event.create',
        label: '确认创建',
        prompt: 'calendar.event.create',
        variant: 'primary',
        kind: 'prompt',
        args: JSON.parse('{"title":"一对一会议","start":"2026-07-02T16:30:00+08:00","end":"2026-07-02T17:00:00+08:00"}') as Object
      }];
      update.blocks[0].actions = [{
        id: 'calendar.event.update',
        label: '确认更新',
        prompt: 'calendar.event.update',
        variant: 'primary',
        kind: 'prompt',
        args: JSON.parse('{"eventId":"event-create-1","start":"2026-07-02T16:30:00+08:00","end":"2026-07-02T17:00:00+08:00"}') as Object
      }];

      [create, update].forEach((doc: HtmlHomeDocument): void => {
        const html = renderHtmlHomeDocument(doc);
        expect(html.indexOf('等待确认')).assertLarger(-1);
        expect(html.indexOf('data-calendar-action=')).assertLarger(-1);
        expect(html.indexOf('function postCalendarWrite(card)')).assertLarger(-1);
        expect(html.indexOf(doc.blocks[0].actions[0].id)).assertLarger(-1);
        expect(html.indexOf('已写入 Google Calendar')).assertEqual(-1);
        expect(html.indexOf('已更新 Google Calendar')).assertEqual(-1);
      });
    });

    it('renders the provider-bound Calendar update offer as the existing confirmation control', 0, () => {
      const update = calendarSearchDocumentFixture();
      update.blocks[0].actions = [{
        id: 'calendar.event.update',
        label: '确认更新日程',
        prompt: 'calendar.event.update',
        variant: 'primary',
        kind: 'prompt',
        args: JSON.parse('{"eventId":"event-1","title":"产品同步",' +
          '"start":"2026-07-02T16:00:00+08:00","end":"2026-07-02T16:30:00+08:00"}') as Object
      }];

      const html = renderHtmlHomeDocument(update);

      expect(html.indexOf('calendar-write-confirm')).assertLarger(-1);
      expect(html.indexOf('确认更新日程')).assertLarger(-1);
      expect(html.indexOf('postCalendarWrite')).assertLarger(-1);
    });

    it('does not show a write confirmation for a failed Calendar create', 0, () => {
      const doc = calendarCreateDocumentFixture();
      doc.subtitle = '缺少字段：title, start, end。固定写工具不会从 prompt 补全这些参数。';
      doc.blocks[0].status = 'error';
      doc.blocks[0].subtitle = doc.subtitle;
      doc.blocks[0].rows = [];
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('Google Calendar API · 同步失败')).assertLarger(-1);
      expect(html.indexOf('<aside class="calendar-confirmation">')).assertEqual(-1);
      expect(html.indexOf('已写入 Google Calendar')).assertEqual(-1);
    });

    it('shows Calendar create missing input without a false write state', 0, () => {
      const doc = calendarCreateDocumentFixture();
      doc.subtitle = '请补充明确的开始时间；请补充明确的结束时间或时长。';
      doc.blocks[0].status = 'needs_input';
      doc.blocks[0].title = '还需要补充日程信息';
      doc.blocks[0].subtitle = doc.subtitle;
      doc.blocks[0].rows = [];
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('Google Calendar API · 待补充')).assertLarger(-1);
      expect(html.indexOf('<aside class="calendar-confirmation">')).assertEqual(-1);
      expect(html.indexOf('已写入 Google Calendar')).assertEqual(-1);
    });

    it('renders Gmail, QQ, and Outlook mail sources with app icons and separate card frames', 0, () => {
      const html = renderHtmlHomeDocument(mailAggregateDocumentFixture());

      expect(html.indexOf('data-scene="gmail"')).assertLarger(-1);
      expect(html.indexOf('收件预览舱')).assertLarger(-1);
      expect(html.indexOf('gmail-hero')).assertLarger(-1);
      expect(html.indexOf('mail-hero-icon')).assertLarger(-1);
      expect(html.indexOf('mail-rail')).assertLarger(-1);
      expect(html.indexOf('mail_filter_gmail')).assertLarger(-1);
      expect(html.indexOf('mail_filter_qq')).assertLarger(-1);
      expect(html.indexOf('mail_filter_outlook')).assertLarger(-1);
      expect(html.indexOf('data-mail-filter')).assertLarger(-1);
      expect(html.indexOf('grid-template-columns: repeat(4, minmax(0, 1fr))')).assertLarger(-1);
      expect(html.indexOf('mail-rail[data-mail-filter="composio-outlook"]::before')).assertLarger(-1);
      expect(html.indexOf('星标')).assertEqual(-1);
      expect(html.indexOf('草稿</button>')).assertEqual(-1);
      expect(html.indexOf('Gmail message')).assertLarger(-1);
      expect(html.indexOf('QQ message')).assertLarger(-1);
      expect(html.indexOf('Composio 调用失败')).assertLarger(-1);
      expect(html.indexOf('OUTLOOK_SEARCH_MESSAGES')).assertLarger(-1);
      expect(html.indexOf('MAIL_ICON_GMAIL')).assertLarger(-1);
      expect(html.indexOf('MAIL_ICON_QQ')).assertLarger(-1);
      expect(html.indexOf('data:image/png;base64')).assertLarger(-1);
      expect(html.indexOf('COMPOSIO_ICON_OUTLOOK')).assertLarger(-1);
      expect(html.indexOf('mail-source-icon')).assertLarger(-1);
      expect(html.indexOf("if (key === 'mail-gmail')")).assertLarger(-1);
      expect(html.indexOf("if (key === 'mail-qq')")).assertLarger(-1);
      expect(html.indexOf("key === 'composio-outlook'")).assertLarger(-1);
      expect(html.indexOf(".block[data-source-key=\"mail-gmail\"]")).assertLarger(-1);
      expect(html.indexOf(".block[data-source-key=\"mail-qq\"]")).assertLarger(-1);
      expect(html.indexOf(".block[data-source-key=\"composio-outlook\"]")).assertLarger(-1);
      expect(html.indexOf('border-color: rgba(194, 70, 54, 0.45)')).assertLarger(-1);
      expect(html.indexOf('border-color: rgba(45, 120, 196, 0.45)')).assertLarger(-1);
      expect(html.indexOf('body[data-scene="gmail"] .block[data-source-key="mail-gmail"]')).assertLarger(-1);
      expect(html.indexOf('body[data-scene="gmail"] .block[data-source-key="mail-qq"]')).assertLarger(-1);
      expect(html.indexOf('body[data-scene="gmail"] .block[data-source-key="composio-outlook"]')).assertLarger(-1);
      expect(html.indexOf('background: var(--kind-soft)')).assertLarger(-1);
      expect(html.indexOf('mail-reply-overlay')).assertLarger(-1);
      expect(html.indexOf("'编辑回复'")).assertLarger(-1);
      expect(html.indexOf("'AI回复'")).assertLarger(-1);
      expect(html.indexOf('html_mail_reply_ai_generate')).assertLarger(-1);
      expect(html.indexOf("activeMailReply.aiButton.textContent = '...'")).assertLarger(-1);
      expect(html.indexOf('html_mail_reply_save')).assertLarger(-1);
      expect(html.indexOf('html_mail_reply_send')).assertLarger(-1);
      expect(html.indexOf('window.scrollBy(0, afterTop - beforeTop)')).assertLarger(-1);
      expect(html.indexOf("kind === 'generic-tool-result' && isMailBlock(block)")).assertLarger(-1);
    });

    it('filters Gmail hero preview counts to mail blocks', 0, () => {
      const doc = mailAggregateDocumentFixture();
      doc.blocks.unshift({
        id: 'youtube-1',
        kind: 'generic-tool-result',
        title: 'World Cup video',
        subtitle: 'YouTube result',
        status: 'success',
        source: 'YouTube Data API',
        metrics: [
          { label: 'source', value: 'YouTube Data API' },
          { label: 'toolName', value: 'youtube.video.search' }
        ],
        rows: [],
        actions: []
      });
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf("function isMailBlock(block)")).assertLarger(-1);
      expect(html.indexOf("var blocks = scene === 'gmail' ? list(data.blocks).filter(isMailBlock) : list(data.blocks);")).assertLarger(-1);
      expect(html.indexOf("var mailCount = list(data.blocks).filter(isMailBlock).length;")).assertLarger(-1);
      expect(html.indexOf("String(mailCount) + ' 封'")).assertLarger(-1);
    });

    it('keeps social document actions intact in the enhanced social frame', 0, () => {
      const html = renderHtmlHomeDocument(socialDocumentFixture());

      expect(html.indexOf('data-scene="social"')).assertLarger(-1);
      expect(html.indexOf('social-hero')).assertEqual(-1);
      expect(html.indexOf('chat-bubble')).assertEqual(-1);
      expect(html.indexOf('消息卡片')).assertLarger(-1);
      expect(html.indexOf('social_select_message')).assertLarger(-1);
    });

    it('renders media sources with app icons and unified playable card frames', 0, () => {
      const html = renderHtmlHomeDocument(mediaAggregateDocumentFixture());

      expect(html.indexOf('media-shell')).assertLarger(-1);
      expect(html.indexOf('media-hero')).assertLarger(-1);
      expect(html.indexOf('media-source-rail')).assertLarger(-1);
      expect(html.indexOf('media-stage')).assertEqual(-1);
      expect(html.indexOf('media-provider-grid')).assertLarger(-1);
      expect(html.indexOf('media-inspector')).assertEqual(-1);
      expect(html.indexOf('media-source-summary')).assertEqual(-1);
      expect(html.indexOf('media-source-facts')).assertEqual(-1);
      expect(html.indexOf('media-theater')).assertEqual(-1);
      expect(html.indexOf('media-cover-wall')).assertEqual(-1);
      expect(html.indexOf('media-hero-frame')).assertEqual(-1);
      expect(html.indexOf('media-hero-art')).assertEqual(-1);
      expect(html.indexOf('media-hero-stats')).assertLarger(-1);
      expect(html.indexOf('media-card-player')).assertLarger(-1);
      expect(html.indexOf('media-card-title-row')).assertLarger(-1);
      expect(html.indexOf('media-card-detail')).assertLarger(-1);
      expect(html.indexOf('media-thumb-shell')).assertEqual(-1);
      expect(html.indexOf('media-inline-player')).assertEqual(-1);
      expect(html.indexOf('media-inline-mount')).assertEqual(-1);
      expect(html.indexOf('media-logo-mark')).assertLarger(-1);
      expect(html.indexOf('Qwen Max 官方视频')).assertLarger(-1);
      expect(html.indexOf('"name":"娱乐搭子"')).assertLarger(-1);
      expect(html.indexOf('用户请求属于娱乐或媒体内容场景。')).assertLarger(-1);
      expect(html.indexOf('renderPersonaBanner(heroCopy)')).assertLarger(-1);
      expect(html.indexOf('YouTube video')).assertLarger(-1);
      expect(html.indexOf('Bilibili video')).assertLarger(-1);
      expect(html.indexOf('data-source-key="media-youtube"')).assertLarger(-1);
      expect(html.indexOf('data-source-key="media-bilibili"')).assertLarger(-1);
      expect(html.indexOf("if (key === 'media-youtube') { return 'data:image/svg+xml;base64")).assertLarger(-1);
      expect(html.indexOf("if (key === 'media-bilibili') { return 'data:image/svg+xml;base64")).assertLarger(-1);
      expect(html.indexOf('data:image/svg+xml;base64')).assertLarger(-1);
      expect(html.indexOf('https://upload.wikimedia.org/wikipedia/commons/e/ef/Youtube_logo.png')).assertEqual(-1);
      expect(html.indexOf('data:image/svg+xml;charset=utf-8,%3Csvg')).assertEqual(-1);
      expect(html.indexOf('%3Ebilibili%3C/text%3E')).assertEqual(-1);
      expect(html.indexOf('data-filter="youtube"')).assertLarger(-1);
      expect(html.indexOf('data-filter="bilibili"')).assertLarger(-1);
      expect(html.indexOf('data-filter="playable"')).assertEqual(-1);
      expect(html.indexOf('data-mode')).assertEqual(-1);
      expect(html.indexOf('data-filter="error"')).assertEqual(-1);
      expect(html.indexOf("['error', '错误']")).assertEqual(-1);
      expect(html.indexOf('B 站')).assertLarger(-1);
      expect(html.indexOf('media.open.web')).assertLarger(-1);
      expect(html.indexOf("var play = add(actions")).assertEqual(-1);
      expect(html.indexOf("var detail = add(actions")).assertEqual(-1);
      expect(html.indexOf("add(heroCaption, 'span'")).assertEqual(-1);
      expect(html.indexOf('aria-expanded')).assertLarger(-1);
      expect(html.indexOf('data-broken')).assertLarger(-1);
      expect(html.indexOf('剧场')).assertEqual(-1);
      expect(html.indexOf('封面墙')).assertEqual(-1);
      expect(html.indexOf('置顶舞台')).assertEqual(-1);
      expect(html.indexOf('来源概览')).assertEqual(-1);
      expect(html.indexOf("iframe.setAttribute('referrerpolicy', 'origin-when-cross-origin')")).assertLarger(-1);
      expect(html.indexOf('https://i.ytimg.com/vi/abc123/mqdefault.jpg')).assertLarger(-1);
      expect(html.indexOf('https://i1.hdslb.com/bfs/archive/cover.jpg')).assertLarger(-1);
    });

    it('normalizes generic dynamic media titles in the H5 document', 0, () => {
      const doc = mediaAggregateDocumentFixture();
      doc.title = '动态工具结果';
      doc.subtitle = '帮我在b站和youtube里搜索qwen max 的官方视频';
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('<title>媒体搜索结果</title>')).assertLarger(-1);
      expect(html.indexOf('"title":"媒体搜索结果"')).assertLarger(-1);
      expect(html.indexOf('帮我在b站和youtube里搜索qwen max 的官方视频')).assertLarger(-1);
      expect(html.indexOf('"title":"动态工具结果"')).assertEqual(-1);
    });

    it('does not render mixed generic blocks as media cards', 0, () => {
      const doc = mediaAggregateDocumentFixture();
      doc.blocks.push({
        id: 'plain-generic',
        kind: 'generic-tool-result',
        title: 'Plain tool result',
        subtitle: 'Not a video result',
        status: 'success',
        source: 'Generic API',
        metrics: [
          { label: 'source', value: 'Generic API' },
          { label: 'toolName', value: 'generic.search' }
        ],
        rows: [
          { label: 'URL', value: 'https://example.com/plain' }
        ],
        actions: [{
          id: 'generic.open',
          label: '打开',
          prompt: 'https://example.com/plain',
          variant: 'secondary',
          kind: 'client'
        }]
      });
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('media-shell')).assertLarger(-1);
      expect(html.indexOf('Plain tool result')).assertEqual(-1);
      expect(html.indexOf('generic.open')).assertEqual(-1);
    });

    it('renders SocialHub blocks with actions and platform styles', 0, () => {
      const html = renderHtmlHomeDocument(socialHubDocumentFixture());

      expect(html.indexOf('data-scene="social"')).assertLarger(-1);
      expect(html.indexOf('Hello from X')).assertLarger(-1);
      expect(html.indexOf('Slack token required')).assertLarger(-1);
      expect(html.indexOf('Thanks for the update')).assertLarger(-1);
      expect(html.indexOf('social_hub_draft_reply')).assertLarger(-1);
      expect(html.indexOf('social_hub_open_source')).assertLarger(-1);
      expect(html.indexOf('data-kind="social-hub-item"')).assertLarger(-1);
      expect(html.indexOf('social-x')).assertLarger(-1);
      expect(html.indexOf('social-slack')).assertLarger(-1);
      expect(html.indexOf('social-discord')).assertLarger(-1);
      expect(html.indexOf('social-linkedin')).assertLarger(-1);
      expect(html.indexOf('social-whatsapp')).assertLarger(-1);
      expect(html.indexOf('social-instagram')).assertLarger(-1);
      expect(html.indexOf('social_select_message')).assertEqual(-1);
    });

    it('renders Luckin payment checkout with countdown and method grid', 0, () => {
      const html = renderHtmlHomeDocument(luckinPaymentDocumentFixture());

      expect(html.indexOf('blocks-luckin-payment')).assertLarger(-1);
      expect(html.indexOf('luckin-payment-card')).assertLarger(-1);
      expect(html.indexOf('订单支付')).assertLarger(-1);
      expect(html.indexOf('luckin-payment-countdown')).assertLarger(-1);
      expect(html.indexOf('生椰拿铁')).assertLarger(-1);
      expect(html.indexOf('luckin-payment-option-summary')).assertLarger(-1);
      expect(html.indexOf('选项·糖度')).assertLarger(-1);
      expect(html.indexOf('半糖:1')).assertLarger(-1);
      expect(html.indexOf('应付金额')).assertLarger(-1);
      expect(html.indexOf("return normalized.length > 0 ? '¥ ' + normalized")).assertLarger(-1);
      expect(html.indexOf("return normalized.length > 0 ? '已优惠 ¥' + normalized")).assertLarger(-1);
      expect(html.indexOf('选择支付方式')).assertLarger(-1);
      expect(html.indexOf('luckin-payment-methods-grid')).assertLarger(-1);
      expect(html.indexOf('luckin-payment-method-text')).assertLarger(-1);
      expect(html.indexOf('luckin-payment-option-chip')).assertLarger(-1);
      expect(html.indexOf('瑞幸咖啡 深圳科技园店')).assertLarger(-1);
      expect(html.indexOf('resource://rawfile/wechat_pay.jpeg')).assertLarger(-1);
      expect(html.indexOf('resource://rawfile/alipay.jpeg')).assertLarger(-1);
      expect(html.indexOf('resource://rawfile/google_pay.jpeg')).assertLarger(-1);
    });

    it('renders a dedicated hotel rate scene with provider-truth fields', 0, () => {
      const html = renderHtmlHomeDocument(hotelDocumentFixture());

      expect(html.indexOf('data-scene="hotel"')).assertLarger(-1);
      expect(html.indexOf('hotel-hero-media')).assertLarger(-1);
      expect(html.indexOf('.hotel-hero.is-detail h1')).assertLarger(-1);
      expect(html.indexOf('photo-1742844551986-de16fd4682c3')).assertLarger(-1);
      expect(html.indexOf('酒店 · 实时房型')).assertLarger(-1);
      expect(html.indexOf('hotel-search-card')).assertLarger(-1);
      expect(html.indexOf('hotel-room-card')).assertLarger(-1);
      expect(html.indexOf('hotel-room-toggle')).assertLarger(-1);
      expect(html.indexOf('hotel-room-details')).assertLarger(-1);
      expect(html.indexOf('var allBlocks = list(data.blocks);')).assertLarger(-1);
      expect(html.indexOf("metricValue(block, ['toolName']) === 'hotel.detail'")).assertLarger(-1);
      expect(html.indexOf("metricValue(block, ['toolName']) === 'hotel.search'")).assertLarger(-1);
      expect(html.indexOf('var isDetail = detailBlocks.length > 0;')).assertLarger(-1);
      expect(html.indexOf('var blocks = isDetail ? detailBlocks : searchBlocks;')).assertLarger(-1);
      expect(html.indexOf("metricValue(blocks[0], ['toolName'])")).assertEqual(-1);
      expect(html.indexOf('detailAction.label')).assertLarger(-1);
      expect(html.indexOf("button.setAttribute('aria-label', text(detailAction.label)")).assertLarger(-1);
      expect(html.indexOf('价格与取消规则')).assertLarger(-1);
      expect(html.indexOf('返回酒店结果')).assertLarger(-1);
      expect(html.indexOf('查看详情')).assertEqual(-1);
      expect(html.indexOf('aria-expanded')).assertLarger(-1);
      expect(html.indexOf('function setExpanded')).assertLarger(-1);
      expect(html.indexOf('image.onerror')).assertLarger(-1);
      expect(html.indexOf('47675')).assertLarger(-1);
      expect(html.indexOf('5nAv6vObodN-6idXNkFPe3z')).assertLarger(-1);
      expect(html.indexOf('550 CNY')).assertLarger(-1);
      expect(html.indexOf('免费取消截止至酒店当地时间')).assertLarger(-1);
      expect(html.indexOf('税费拆分与报价有效期：供应商未返回')).assertLarger(-1);
      expect(html.indexOf('Appless 支持打开 App 内 RollingGo Web 预订；原生订单创建、状态和取消不可用')).assertLarger(-1);
      expect(html.indexOf('min-height: 44px')).assertLarger(-1);
      expect(html.indexOf('@media (prefers-reduced-motion: reduce)')).assertLarger(-1);
      expect(html.indexOf('LIVE HOTEL DATA')).assertEqual(-1);
      expect(html.indexOf('hotel-scene-note')).assertEqual(-1);
      expect(html.indexOf('add(identifiers')).assertEqual(-1);
      expect(html.indexOf('第三方预订（离开 Appless）：')).assertEqual(-1);
      expect(html.indexOf('下单成功')).assertEqual(-1);
      expect(html.indexOf('订单编号')).assertEqual(-1);
    });

    it('drops a retained hotel pending block once real search results exist', 0, () => {
      const doc = hotelSearchDocumentFixture();
      doc.blocks.unshift({
        id: 'pending',
        kind: 'text',
        title: '正在查询 RollingGo',
        subtitle: '正在等待真实酒店结果',
        status: 'calling_tool',
        source: '',
        metrics: [],
        rows: [],
        actions: []
      });

      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('正在查询 RollingGo')).assertEqual(-1);
      expect(html.indexOf('深圳测试酒店')).assertLarger(-1);
      expect(html.indexOf('"toolName","value":"hotel.search"')).assertLarger(-1);
    });

    it('renders exact conditional hotel actions from the A2UI snapshot', 0, () => {
      const doc = hotelSearchDocumentFixture();
      const actions = doc.blocks[0].actions;
      actions.forEach((item: HtmlHomeAction) => {
        if (item.id === 'hotel.detail') {
          item.label = '房型详情';
        } else if (item.id === 'hotel.navigate') {
          item.label = '去这里';
        } else if (item.id === 'hotel.booking.open') {
          item.label = '继续预订';
        }
      });
      const html = renderHtmlHomeDocument(doc);

      expect(doc.rawSurfaceRoot === null).assertFalse();
      expect(doc.surfaceId).assertEqual('hotel-search-task-6');
      expect(JSON.stringify(actions).indexOf('"id":"hotel.detail"')).assertLarger(-1);
      expect(JSON.stringify(actions).indexOf('"id":"hotel.navigate"')).assertLarger(-1);
      expect(JSON.stringify(actions).indexOf('"id":"hotel.booking.open"')).assertEqual(-1);
      expect(html.indexOf('房型详情')).assertLarger(-1);
      expect(html.indexOf('去这里')).assertLarger(-1);
      expect(html.indexOf('继续预订')).assertEqual(-1);
      expect(html.indexOf('hotel-action-row')).assertLarger(-1);
      expect(html.indexOf('hotel-card-cta-primary')).assertLarger(-1);
      expect(html.indexOf('hotel-card-cta-secondary')).assertLarger(-1);
      expect(html.indexOf("actionFor(block, 'hotel.navigate')")).assertLarger(-1);
      expect(html.indexOf("actionFor(block, 'hotel.booking.open')")).assertEqual(-1);
      expect(html.indexOf('postAction(JSON.stringify(action))')).assertLarger(-1);
      expect(html.indexOf('collectHotelSmokeEvidence')).assertLarger(-1);
      expect(html.indexOf('clickLabel')).assertLarger(-1);
      expect(html.indexOf('bookingEvidence')).assertLarger(-1);
      expect(html.indexOf('coordinatesValid')).assertLarger(-1);
      expect(html.indexOf('var byActionId = {};')).assertLarger(-1);
      expect(html.indexOf('current.argsValid && !sanitized.argsValid')).assertLarger(-1);
      expect(html.indexOf("['hotel.detail', 'hotel.navigate', 'hotel.booking.open']")).assertLarger(-1);
      expect(html.indexOf('evidence.push(sanitizeHotelAction(action))')).assertEqual(-1);
      expect(html.indexOf('"surfaceId":"hotel-search-task-6"')).assertLarger(-1);
      expect(html.indexOf('id: text(action.id)')).assertEqual(-1);
      expect(html.indexOf("actionFor(block, 'hotel.book')")).assertEqual(-1);
    });

    it('keeps unavailable hotel navigation and call controls hidden', 0, () => {
      const doc = hotelSearchDocumentFixture(false);
      const html = renderHtmlHomeDocument(doc);
      const actions = JSON.stringify(doc.blocks[0].actions);

      expect(actions.indexOf('"id":"hotel.detail"')).assertLarger(-1);
      expect(actions.indexOf('"id":"hotel.navigate"')).assertEqual(-1);
      expect(actions.indexOf('"id":"hotel.booking.open"')).assertEqual(-1);
      expect(actions.indexOf('"id":"hotel.book"')).assertEqual(-1);
      expect(html.indexOf('导航到酒店')).assertEqual(-1);
      expect(html.indexOf('联系酒店')).assertEqual(-1);
    });

    it('does not auto-render welcome scene and source chips', 0, () => {
      const doc = documentFixture();
      doc.source = 'welcome';
      doc.kind = 'welcome';
      doc.title = 'Appless';
      doc.subtitle = '';
      doc.chips = [];
      doc.metrics = [];
      doc.timeline = [];
      doc.blocks = [];
      doc.actions = [];
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('data-scene="welcome"')).assertEqual(-1);
      expect(html.indexOf('status-hero')).assertEqual(-1);
      expect(html.indexOf('场景')).assertEqual(-1);
      expect(html.indexOf('待命')).assertEqual(-1);
    });
  });
}
