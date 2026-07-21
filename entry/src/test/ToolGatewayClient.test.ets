import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiCallResult,
  A2uiFlightData,
  A2uiFoodData,
  A2uiLabelValueData,
  A2uiSurfaceState,
  A2uiTrainData,
  A2uiTravelOptionData,
  DataResult,
  DataSource,
  FlightStructuredData,
  FoodStructuredData,
  HotelSearchResult,
  TrainStructuredData,
  TravelStructuredData
} from '@loop/agent-core';
import { genericToolResults, dynamicToolConnect } from '@loop/agent-core';
import { planA2uiPartialUpdate, A2uiPartialUpdateResult } from '@loop/agent-core';
import { buildSystemFoodNavigationUri, foodMapsLatLng } from '@loop/agent-core';
import { build12306BookingUrl, trainLowestAvailablePriceForTest } from '@loop/agent-core';
import { DynamicGenericToolResult } from '@loop/agent-core';
import { DynamicToolRegistration, GenericMcpClient, McpToolCallResult, MemoryCredentialStore } from '@loop/agent-core';
import { GMAIL_ACCESS_TOKEN_REF } from '@loop/agent-core';
import { MailDraftArgs, MailReplyCommand, MailSearchArgs } from '@loop/agent-core';
import {
  aggregateFoodProviderResults,
  buildToolGatewayUrl,
  combineTravelStructuredResults,
  callStructuredTool,
  callToolGateway,
  callStructuredHotelTool,
  configureComposioConfigFromRawJson,
  configureDidiMcpSandboxForRuntime,
  configureGmailCredentialStoreForTests,
  configureGmailMcpClientForTests,
  configureHotelMcpClientForTests,
  configureHotelTimestampProviderForTests,
  configureLocalPaymentAccountBookJson,
  configureLocalProviderConfigFromRawJson,
  defaultToolGatewayUrl,
  emptyDataResult,
  errorDataResult,
  flightDataResultA2ui,
  flightDataResultFromProviderResponse,
  flightStructuredDataA2ui,
  flightStructuredDataResult,
  foodA2uiRenderState,
  foodStructuredDataA2ui,
  foodStructuredDataResult,
  foodStructuredDataResultFromProviders,
  foodDistanceMeters,
  foodProviderProgressRows,
  foodRecordFromBaiduPlace,
  foodRecordsFromLuckinMcpTool,
  foodRecordsFromMcDonaldsMcpTool,
  foodRecordFromMeituanUnion,
  foodRecordFromTencentMapPlace,
  foodRecordFromTaobaoFlashStore,
  flightRecordForA2ui,
  isReadonlyBrandMcpTool,
  isLocalToolGatewayUrl,
  isRegisteredToolId,
  isTransientPayPalRequestErrorForTest,
  localProviderConfigDebugSummary,
  mailSearchArgs,
  payPalApiFallbackUrlForTest,
  paypalGooglePayNetworkHelpForTest,
  providerIssueRows,
  partialDataResult,
  rideAmapGeocodePointForTest,
  rideAmapGeocodeKeyForTest,
  rideAmapRequestArgsForTest,
  rideDidiCityFromAmapGeocodeForTest,
  rideDidiCancelOrderArgsForTest,
  rideDidiCreateOrderArgsForTest,
  rideDidiDriverLocationArgsForTest,
  rideDidiMcpSandboxEnabledForRuntime,
  rideDidiOrderMcpUrlForTest,
  rideDidiQueryMcpUrlForTest,
  rideOrderCreateDedupBlockedForTest,
  rideOrderCreateErrorTitleForTest,
  rideCancelOrderResultForTest,
  rideDriverLocationResultForTest,
  rideLinkFromMcpResponseTextForTest,
  rideOrderConfirmedForTest,
  rideResultsFromMcpPayloadsForTest,
  rideShouldSurfaceAppLinkErrorForTest,
  calendarDeleteConfirmedForTest,
  calendarDeleteTargetFromResultsForTest,
  whatsAppSendConfirmedForTest,
  whatsAppProviderFailureSummaryForTest,
  resolveLuckinLocationForTest,
  saveConfiguredMailDraft,
  sortTravelOptionsByDeparture,
  streamFoodProviderResultsWithPartials,
  successfulDataResult,
  trainStructuredDataA2ui,
  trainDataResultA2ui,
  trainStructuredDataResult,
  travelStructuredDataA2ui,
  travelStructuredDataResult,
  FoodProviderPartialSnapshot,
  FoodProviderResult
} from '@loop/agent-core';

class SuccessfulGmailMcpClient extends GenericMcpClient {
  async callTool(_registration: DynamicToolRegistration, _credentialValue: string, _args: Object): Promise<DynamicGenericToolResult> {
    return {
      sourceTag: 'Gmail OAuth',
      toolName: 'search_threads',
      title: 'Gmail message',
      status: 'success',
      summary: 'Real Gmail OAuth result',
      rows: [{ label: 'Subject', value: 'Latest important mail' }],
      rawPreview: 'gmail-oauth-result'
    };
  }
}

class ScriptedHotelMcpClient extends GenericMcpClient {
  private readonly response: McpToolCallResult;
  callCount: number = 0;
  lastOperation: string = '';

  constructor(response: McpToolCallResult) {
    super();
    this.response = response;
  }

  async callToolPayload(registration: DynamicToolRegistration, _credentialValue: string, _args: Object): Promise<McpToolCallResult> {
    this.callCount += 1;
    this.lastOperation = registration.mcpToolName;
    return this.response;
  }
}

let hotelClockValue: string = '2026-07-20T02:00:00.000Z';

class ClockedHotelMcpClient extends ScriptedHotelMcpClient {
  async callToolPayload(registration: DynamicToolRegistration, credentialValue: string, args: Object): Promise<McpToolCallResult> {
    const response = await super.callToolPayload(registration, credentialValue, args);
    hotelClockValue = '2026-07-20T02:00:01.000Z';
    return response;
  }
}

class ThrowingHotelMcpClient extends GenericMcpClient {
  async callToolPayload(_registration: DynamicToolRegistration, _credentialValue: string, _args: Object): Promise<McpToolCallResult> {
    throw new Error('Failed to resolve hotel.example for hotel-test-secret');
  }
}

interface YouTubeSearchArgsFixture {
  query: string;
}

interface MediaVideoSearchArgsFixture {
  query: string;
  sources: string[];
}

interface PaymentTestArgs {
  provider?: string;
  recipient?: string;
  phase?: string;
  originalQuery?: string;
}

function looseObject(raw: string): Object {
  return JSON.parse(raw) as Object;
}

function searchArgsForGateway(): Object {
  return looseObject(
    '{"originQuery":"深圳 8 月 15 日住两晚，2 位成人","place":"深圳","placeType":"CITY","countryCode":"CN",' +
    '"checkInDate":"2026-08-15","stayNights":2,"adultCount":2,"childCount":0,' +
    '"childAgeDetails":[],"roomCount":1,"currency":"CNY","size":10}'
  );
}

function detailArgsForGateway(): Object {
  return looseObject(
    '{"hotelId":47675,"checkInDate":"2026-08-15","checkOutDate":"2026-08-17","countryCode":"CN",' +
    '"currency":"CNY","adultCount":2,"childCount":0,"childAgeDetails":[],"roomCount":1}'
  );
}

function hotelSearchResponse(count: number, firstWithoutName: boolean = false): McpToolCallResult {
  const hotels: string[] = [];
  for (let index = 0; index < count; index++) {
    const hotelId = 47001 + index;
    const name = firstWithoutName && index === 0 ? '' : '深圳测试酒店' + hotelId.toString();
    const nameEn = firstWithoutName && index === 0 ? '' : 'Shenzhen Test Hotel ' + hotelId.toString();
    hotels.push(
      '{"hotelId":' + hotelId.toString() + ',"name":' + JSON.stringify(name) +
      ',"nameEn":' + JSON.stringify(nameEn) + ',' +
      '"bookingUrl":"https://rollinggo.cn/pages/hotel/detail/index?id=' + hotelId.toString() +
      '&checkInDate=2026-08-15&checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0",' +
      '"address":"深圳市南山区科技南路' + hotelId.toString() + '号",' +
      '"latitude":22.5,"longitude":114.0}'
    );
  }
  return {
    ok: true,
    httpStatus: 200,
    errorMessage: '',
    result: {
      isError: false,
      structuredContent: looseObject(
        '{"success":true,"message":"酒店搜索成功","hotelInformationList":[' + hotels.join(',') + ']}'
      )
    },
    rawPreview: ''
  };
}

interface McDonaldsStoreFixture {
  storeName: string;
  address: string;
  distance: string;
  businessStatus: boolean;
  businessStartTime: string;
  businessEndTime: string;
}

interface McDonaldsStoresPayloadFixture {
  data: McDonaldsStoreFixture[];
}

interface McDonaldsMealRefFixture {
  code: string;
  tags: string[];
}

interface McDonaldsCategoryFixture {
  name: string;
  meals: McDonaldsMealRefFixture[];
}

interface McDonaldsMealFixture {
  name: string;
  currentPrice: string;
}

interface McDonaldsMealsByCodeFixture {
  '920215': McDonaldsMealFixture;
}

interface McDonaldsMealsDataFixture {
  categories: McDonaldsCategoryFixture[];
  meals: McDonaldsMealsByCodeFixture;
}

interface McDonaldsMealsPayloadFixture {
  data: McDonaldsMealsDataFixture;
}

interface LuckinShopFixture {
  deptName: string;
  address: string;
  distance: number;
  deptTags: string[];
  longitude: number;
  latitude: number;
}

interface LuckinShopsPayloadFixture {
  data: LuckinShopFixture[];
}

interface LuckinProductSubAttributeFixture {
  attributeName: string;
  selected: boolean;
}

interface LuckinProductAttributeFixture {
  attributeName: string;
  productSubAttrs: LuckinProductSubAttributeFixture[];
}

interface LuckinProductFixture {
  productName: string;
  price: number;
  skuCode: string;
  pictureUrl: string;
  productAttrs: LuckinProductAttributeFixture[];
  tags: string[];
}

interface LuckinProductsPayloadFixture {
  data: LuckinProductFixture[];
}

function trainRowForPrice(
  ypInfoNew: string,
  business: string,
  first: string,
  second: string,
  noSeat: string = '',
  hardSeat: string = '',
  softSleeper: string = ''
): string {
  const fields: string[] = [];
  for (let index = 0; index < 40; index++) {
    fields.push('');
  }
  fields[23] = softSleeper;
  fields[26] = noSeat;
  fields[29] = hardSeat;
  fields[30] = second;
  fields[31] = first;
  fields[32] = business;
  fields[39] = ypInfoNew;
  return fields.join('|');
}

export default function toolGatewayClientTest() {
  describe('toolGatewayClient', () => {
    it('uses the lowest priced seat that is currently available', 0, () => {
      const row = trainRowForPrice(
        '9174800000M093300000O055300000',
        '有',
        '2',
        '有'
      );
      expect(trainLowestAvailablePriceForTest(row)).assertEqual('553');
    });

    it('uses no-seat availability for 12306 inventory price chunks', 0, () => {
      const row = trainRowForPrice(
        '9235000002M107500000O067200000O067203065',
        '2',
        '无',
        '无',
        '有'
      );
      expect(trainLowestAvailablePriceForTest(row)).assertEqual('672');
    });

    it('ignores unavailable no-seat inventory price chunks', 0, () => {
      const row = trainRowForPrice(
        '9235000002M107500000O067200000O067203065',
        '2',
        '无',
        '无',
        '无'
      );
      expect(trainLowestAvailablePriceForTest(row)).assertEqual('2350');
    });

    it('formats no-seat prices with non-zero jiao', 0, () => {
      const row = trainRowForPrice(
        '9235000002M107500000O067200000O067253065',
        '2',
        '无',
        '无',
        '有'
      );
      expect(trainLowestAvailablePriceForTest(row)).assertEqual('672.5');
    });

    it('ignores cheaper unavailable, waitlist, and malformed train prices', 0, () => {
      expect(trainLowestAvailablePriceForTest(
        trainRowForPrice('O040000000M055300000', '', '3', '无')
      )).assertEqual('553');
      expect(trainLowestAvailablePriceForTest(
        trainRowForPrice('O040000000', '', '', '候补')
      )).assertEqual('');
      expect(trainLowestAvailablePriceForTest(
        trainRowForPrice('O0553', '', '', '有')
      )).assertEqual('');
      expect(trainLowestAvailablePriceForTest(
        trainRowForPrice('OABCDE0000', '', '', '有')
      )).assertEqual('');
      expect(trainLowestAvailablePriceForTest(
        trainRowForPrice('', '', '', '有')
      )).assertEqual('');
    });

    it('builds the official route-level 12306 booking URL', 0, () => {
      const url = build12306BookingUrl(
        '2026-07-22',
        '深圳北',
        'IOQ',
        '香港西九龙',
        'XJA'
      );
      expect(url).assertEqual(
        'https://kyfw.12306.cn/otn/leftTicket/init?linktypeid=dc' +
        '&fs=%E6%B7%B1%E5%9C%B3%E5%8C%97,IOQ' +
        '&ts=%E9%A6%99%E6%B8%AF%E8%A5%BF%E4%B9%9D%E9%BE%99,XJA' +
        '&date=2026-07-22&flag=N,N,Y'
      );
    });

    it('falls back to the configured location for Luckin preview', 0, () => {
      expect(resolveLuckinLocationForTest('', '点一杯咖啡', '114.029506,22.609878'))
        .assertEqual('114.029506,22.609878');
    });

    it('defaults to the in-app local tool route', 0, () => {
      expect(defaultToolGatewayUrl()).assertEqual('local://aiphone-tools');
      expect(isLocalToolGatewayUrl(defaultToolGatewayUrl())).assertTrue();
      expect(buildToolGatewayUrl(defaultToolGatewayUrl())).assertEqual('local://aiphone-tools');
    });

    it('still supports explicit HTTP tool gateways', 0, () => {
      expect(isLocalToolGatewayUrl('http://127.0.0.1:8787')).assertFalse();
      expect(buildToolGatewayUrl('http://127.0.0.1:8787')).assertEqual('http://127.0.0.1:8787/api/aiphone/tool');
    });

    it('does not create a tool-specific override for provider tools', 0, () => {
      const endpoint = buildToolGatewayUrl(defaultToolGatewayUrl());
      expect(endpoint).assertEqual('local://aiphone-tools');
      expect(isLocalToolGatewayUrl(endpoint)).assertTrue();
    });

    it('registers unified travel search as a real query tool', 0, () => {
      expect(isRegisteredToolId('travel.search')).assertTrue();
      expect(isRegisteredToolId('train.search')).assertTrue();
      expect(isRegisteredToolId('flight.search')).assertTrue();
      expect(isRegisteredToolId('food.search')).assertTrue();
      expect(isRegisteredToolId('social.reply.send')).assertFalse();
    });

    it('allows only explicit dynamic catalog aliases to enter the local tool host', 0, () => {
      expect(isRegisteredToolId('travel.search')).assertTrue();
      expect(isRegisteredToolId('dynamic.search')).assertTrue();
      expect(isRegisteredToolId('weather.query')).assertTrue();
      expect(isRegisteredToolId('maps.weather')).assertTrue();
      expect(isRegisteredToolId('statistics.search')).assertTrue();
      expect(isRegisteredToolId('ppt.generate')).assertTrue();
      expect(isRegisteredToolId('weather.search')).assertFalse();
      expect(isRegisteredToolId('ferry.ticket.search')).assertFalse();
    });

    it('uses Composio missing-config result for unsupported app dynamic queries', 0, async () => {
      configureComposioConfigFromRawJson('{}');
      const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};

      const result: A2uiCallResult = await callToolGateway(
        defaultToolGatewayUrl(),
        'dynamic.search',
        '帮我在 Notion 里找一下 7 月旅行计划相关页面',
        'surface_composio',
        '',
        noop
      );

      const rendered = genericToolResults(result.surface);
      expect(result.ok).assertTrue();
      expect(rendered.length).assertLarger(0);
      expect(rendered[0].sourceTag).assertEqual('Composio');
      expect(rendered[0].status).assertEqual('needs_auth');
      expect(rendered[0].rawPreview.indexOf('Notion')).assertLarger(-1);
    });

    it('registers Gmail tools on the same local tool framework without enabling silent send', 0, () => {
      expect(isRegisteredToolId('gmail.mail.search')).assertTrue();
      expect(isRegisteredToolId('gmail.thread.read')).assertTrue();
      expect(isRegisteredToolId('gmail.draft.create')).assertTrue();
      expect(isRegisteredToolId('gmail.draft.apply')).assertTrue();
      expect(isRegisteredToolId('gmail.open.web')).assertTrue();
      expect(isRegisteredToolId('gmail.message.send')).assertTrue();
      expect(isRegisteredToolId('gmail.unknown')).assertFalse();
    });

    it('loads QQ Mail config from local provider raw JSON without exposing the auth code', 0, () => {
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          QQ_MAIL_ADDRESS: 'me@qq.com',
          QQ_MAIL_AUTH_CODE: 'sixteencharscode',
          QQ_MAIL_IMAP_HOST: 'imap.qq.com',
          QQ_MAIL_IMAP_PORT: '993',
          QQ_MAIL_DRAFTS_MAILBOX: 'Drafts'
        }));

        const summary = localProviderConfigDebugSummary();
        expect(summary.indexOf('qqMailAddress=present')).assertLarger(-1);
        expect(summary.indexOf('qqMailAuthCode=present(16)')).assertLarger(-1);
        expect(summary.indexOf('sixteencharscode')).assertEqual(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('loads payment config from local provider raw JSON without exposing secrets', 0, () => {
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          PAYPAL_CLIENT_ID: 'paypal-client',
          PAYPAL_CLIENT_SECRET: 'paypal-secret',
          PAYPAL_ENVIRONMENT: 'sandbox',
          PAYPAL_CHECKOUT_GATEWAY_URL: 'http://127.0.0.1:8787/api/payment/paypal/checkout',
          STRIPE_SECRET_KEY: 'sk_test_secret',
          STRIPE_PUBLISHABLE_KEY: 'pk_test_public',
          STRIPE_CHECKOUT_GATEWAY_URL: 'http://127.0.0.1:8787/api/payment/stripe/checkout',
          PAYMENT_ACCOUNT_BOOK_JSON: '[{"id":"alex"}]',
          PAYMENT_LIVE_ALLOWED_STRIPE_ACCOUNT_IDS: 'acct_live_ok',
          PAYMENT_LIVE_MAX_AMOUNT_MINOR: '100'
        }));

        const summary = localProviderConfigDebugSummary();
        expect(summary.indexOf('paypalClientId=present(13)')).assertLarger(-1);
        expect(summary.indexOf('paypalClientSecret=present(13)')).assertLarger(-1);
        expect(summary.indexOf('paypalCheckoutGatewayUrl=present')).assertLarger(-1);
        expect(summary.indexOf('stripeSecretKey=present(14)')).assertLarger(-1);
        expect(summary.indexOf('stripeCheckoutGatewayUrl=present')).assertLarger(-1);
        expect(summary.indexOf('paymentAccountBookJson=present')).assertLarger(-1);
        expect(summary.indexOf('paypal-secret')).assertEqual(-1);
        expect(summary.indexOf('sk_test_secret')).assertEqual(-1);
        expect(summary.indexOf('127.0.0.1')).assertEqual(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('loads ride MCP config from local provider raw JSON without exposing secrets', 0, () => {
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          DIDI_MCP_KEY: 'didi-secret-key',
          DIDI_MCP_URL: 'https://mcp.didichuxing.com/mcp-servers-sandbox',
          DIDI_MCP_SANDBOX: 'true',
          AMAP_MCP_KEY: 'amap-mcp-secret',
          AMAP_MCP_URL: 'https://mcp.amap.com/mcp',
          RIDE_MOCK_ENABLED: 'true',
          AMAP_KEY: 'amap-web-key'
        }));

        const summary = localProviderConfigDebugSummary();
        expect(summary.indexOf('didiMcpKey=present(15)')).assertLarger(-1);
        expect(summary.indexOf('didiMcpSandbox=true')).assertLarger(-1);
        expect(summary.indexOf('amapMcpKey=present(15)')).assertLarger(-1);
        expect(summary.indexOf('rideMockEnabled=true')).assertLarger(-1);
        expect(summary.indexOf('didi-secret-key')).assertEqual(-1);
        expect(summary.indexOf('amap-mcp-secret')).assertEqual(-1);
        expect(summary.indexOf('mcp.didichuxing.com')).assertEqual(-1);
        expect(summary.indexOf('mcp.amap.com')).assertEqual(-1);
      } finally {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          RIDE_MOCK_ENABLED: 'false'
        }));
      }
    });

    it('loads RollingGo hotel config without exposing the credential', 0, () => {
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          ROLLINGGO_HOTEL_MCP_KEY: 'hotel-test-secret',
          ROLLINGGO_HOTEL_MCP_URL: 'https://hotel.example/mcp'
        }));

        const summary = localProviderConfigDebugSummary();
        expect(summary.indexOf('hotelKey=present(17)')).assertLarger(-1);
        expect(summary.indexOf('hotelUrl=present')).assertLarger(-1);
        expect(summary.indexOf('hotel-test-secret')).assertEqual(-1);
        expect(isRegisteredToolId('hotel.search')).assertTrue();
        expect(isRegisteredToolId('hotel.detail')).assertTrue();
        expect(isRegisteredToolId('hotel.navigate')).assertTrue();
        expect(isRegisteredToolId('hotel.booking.open')).assertTrue();
        expect(isRegisteredToolId('hotel.' + 'call')).assertFalse();
        expect(isRegisteredToolId('hotel.book')).assertFalse();
        expect(isRegisteredToolId('hotel.create')).assertFalse();
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('builds exact immutable structured data envelopes', 0, () => {
      const source: DataSource = {
        provider: 'Provider A',
        backend: 'local_adapter',
        operation: 'search',
        fetchedAt: '2026-07-21T00:00:00.000Z'
      };
      const sources: DataSource[] = [source];
      const successData = looseObject('{"items":[{"id":"real-1"}]}');
      const success = successfulDataResult('travel.search', 'travelOptions', successData, sources);
      const partial = partialDataResult(
        'media.aggregate.search',
        'genericToolResults',
        looseObject('{"items":[{"id":"real-2"}]}'),
        sources,
        ['One provider failed.']
      );
      const empty = emptyDataResult('food.search', 'foodChoices', [], 'No stores returned.');
      const error = errorDataResult(
        'maps.place.search',
        'genericToolResults',
        'PROVIDER_TIMEOUT',
        'Provider timed out.',
        true,
        sources
      );
      sources.push({
        provider: 'Provider B',
        backend: 'mcp_remote',
        operation: 'search',
        fetchedAt: '2026-07-21T00:00:01.000Z'
      });

      expect(JSON.stringify(success)).assertEqual(
        '{"toolId":"travel.search","outputSchema":"travelOptions","status":"success",' +
        '"sources":[{"provider":"Provider A","backend":"local_adapter","operation":"search",' +
        '"fetchedAt":"2026-07-21T00:00:00.000Z"}],"data":{"items":[{"id":"real-1"}]},"warnings":[]}'
      );
      expect(JSON.stringify(partial)).assertEqual(
        '{"toolId":"media.aggregate.search","outputSchema":"genericToolResults","status":"partial",' +
        '"sources":[{"provider":"Provider A","backend":"local_adapter","operation":"search",' +
        '"fetchedAt":"2026-07-21T00:00:00.000Z"}],"data":{"items":[{"id":"real-2"}]},' +
        '"warnings":["One provider failed."]}'
      );
      expect(JSON.stringify(empty)).assertEqual(
        '{"toolId":"food.search","outputSchema":"foodChoices","status":"empty","sources":[],' +
        '"data":{},"warnings":["No stores returned."]}'
      );
      expect(JSON.stringify(error)).assertEqual(
        '{"toolId":"maps.place.search","outputSchema":"genericToolResults","status":"error",' +
        '"sources":[{"provider":"Provider A","backend":"local_adapter","operation":"search",' +
        '"fetchedAt":"2026-07-21T00:00:00.000Z"}],"data":{},"warnings":[],' +
        '"error":{"code":"PROVIDER_TIMEOUT","message":"Provider timed out.","retryable":true}}'
      );
    });

    it('fails closed for action-owned unknown and unmigrated structured tools', 0, async () => {
      const client = new ScriptedHotelMcpClient(hotelSearchResponse(1));
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          ROLLINGGO_HOTEL_MCP_KEY: 'hotel-test-secret',
          ROLLINGGO_HOTEL_MCP_URL: 'https://hotel.example/mcp'
        }));
        configureHotelMcpClientForTests(client);

        const actionOwned = await callStructuredTool('hotel.navigate', '', detailArgsForGateway());
        const unknown = await callStructuredTool('unknown.tool', '', new Object());

        expect(actionOwned.status).assertEqual('error');
        expect(actionOwned.outputSchema).assertEqual('systemIntentResult');
        expect(actionOwned.error?.code).assertEqual('TOOL_NOT_ALLOWED');
        expect(unknown.status).assertEqual('error');
        expect(unknown.outputSchema).assertEqual('');
        expect(unknown.error?.code).assertEqual('TOOL_NOT_ALLOWED');
        expect(client.callCount).assertEqual(0);
      } finally {
        configureHotelMcpClientForTests(null);
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('dispatches travel train flight and food to structured adapters without A2UI payloads', 0, async () => {
      try {
        configureLocalProviderConfigFromRawJson('{}');
        const results = await Promise.all([
          callStructuredTool('travel.search', '', new Object()),
          callStructuredTool('train.search', '', new Object()),
          callStructuredTool('flight.search', '', new Object()),
          callStructuredTool('food.search', '', new Object())
        ]);

        expect(results.length).assertEqual(4);
        results.forEach((result) => {
          expect(result.error?.code === 'STRUCTURED_ADAPTER_MISSING').assertFalse();
          expect(JSON.stringify(result.data).indexOf('updateComponents')).assertEqual(-1);
          expect(JSON.stringify(result.data).indexOf('createSurface')).assertEqual(-1);
        });
        expect(results[0].outputSchema).assertEqual('travelOptions');
        expect(results[1].outputSchema).assertEqual('trains');
        expect(results[2].outputSchema).assertEqual('flights');
        expect(results[3].outputSchema).assertEqual('foodChoices');
        expect(results[0].error?.code).assertEqual('TRAVEL_PROVIDERS_UNAVAILABLE');
        expect(results[1].error?.code).assertEqual('TRAIN_INVALID_ARGUMENTS');
        expect(results[2].error?.code).assertEqual('FLIGHT_CONFIG_MISSING');
        expect(results[3].error?.code).assertEqual('FOOD_CONFIG_MISSING');
        expect(results[3].error?.retryable).assertFalse();
        expect(results[3].warnings.length).assertLarger(0);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('keeps normalized travel and food records intact in structured DataResults', 0, () => {
      const sources: DataSource[] = [{
        provider: 'fixture',
        backend: 'local_adapter',
        operation: 'search',
        fetchedAt: '2026-07-22T00:00:00.000Z'
      }];
      const train: A2uiTrainData = {
        trainCode: 'G5612', from: '深圳北', to: '香港西九龙', depart: '18:05', arrive: '18:23',
        duration: '18分', seats: '二等座有票', status: '可预订', business: '--', first: '--',
        second: '有', noSeat: '--', hardSeat: '--', sleeperSoft: '--', price: '¥75',
        bookingUrl: 'https://kyfw.12306.cn/otn/leftTicket/init?real=1'
      };
      const flight: A2uiFlightData = {
        flightNo: 'CZ355', airline: '南方航空', dep: 'SZX', arr: 'SHA', depTime: '2026-07-23 08:00',
        arrTime: '2026-07-23 10:20', status: '计划', price: '¥680'
      };
      const option: A2uiTravelOptionData = {
        id: 'train-G5612-18:05', source: 'train', sourceTag: '高铁 · 12306', title: 'G5612',
        from: '深圳北', to: '香港西九龙', depart: '18:05', arrive: '18:23', duration: '18分',
        price: '¥75', availability: '二等座有票', status: '可预订', detail: ''
      };
      const food: A2uiFoodData = {
        name: '瑞幸咖啡 科技园店', category: '咖啡', address: '深圳科技园', distance: '320米',
        location: '113.9500,22.5400', sourceTags: ['高德', '瑞幸']
      };
      const travelData: TravelStructuredData = {
        title: '出行方案查询', body: '用户请求', summary: '1 个方案', options: [option], rows: []
      };
      const trainData: TrainStructuredData = {
        title: '12306 余票查询', body: '实时结果', summary: '1 趟车次', trains: [train]
      };
      const flightData: FlightStructuredData = {
        title: '飞常准航班查询', body: '实时结果', summary: '1 个航班', flights: [flight]
      };
      const foodData: FoodStructuredData = {
        title: '外卖聚合搜索', body: '真实来源', summary: '1 个结果', foods: [food], rows: []
      };
      const results: DataResult[] = [
        travelStructuredDataResult(travelData, sources),
        trainStructuredDataResult(trainData, sources),
        flightStructuredDataResult(flightData, sources),
        foodStructuredDataResult(foodData, sources)
      ];

      expect(JSON.stringify(results[0].data)).assertEqual(JSON.stringify(travelData));
      expect(JSON.stringify(results[1].data)).assertEqual(JSON.stringify(trainData));
      expect(JSON.stringify(results[2].data)).assertEqual(JSON.stringify(flightData));
      expect(JSON.stringify(results[3].data)).assertEqual(JSON.stringify(foodData));
      results.forEach((result: DataResult) => {
        expect(result.status).assertEqual('success');
        expect(result.sources[0].provider).assertEqual('fixture');
        expect(JSON.stringify(result.data).indexOf('updateComponents')).assertEqual(-1);
      });
      const legacyJsonl: string[] = [
        travelStructuredDataA2ui('travel_fixture', travelData),
        trainStructuredDataA2ui('train_fixture', trainData),
        flightStructuredDataA2ui('flight_fixture', flightData),
        foodStructuredDataA2ui('food_fixture', foodData)
      ];
      expect(legacyJsonl[0].indexOf('"id":"train-G5612-18:05"')).assertLarger(-1);
      expect(legacyJsonl[1].indexOf('"trainCode":"G5612"')).assertLarger(-1);
      expect(legacyJsonl[2].indexOf('"flightNo":"CZ355"')).assertLarger(-1);
      expect(legacyJsonl[3].indexOf('"name":"瑞幸咖啡 科技园店"')).assertLarger(-1);
      legacyJsonl.forEach((jsonl: string) => {
        expect(jsonl.indexOf('updateComponents')).assertLarger(-1);
      });
      expect(foodStructuredDataResult(foodData, sources, ['百度地图超时']).status).assertEqual('partial');
      const emptyTrain: TrainStructuredData = {
        title: '12306 查询结果为空', body: '没有车次', summary: '暂无车次', trains: []
      };
      expect(trainStructuredDataResult(emptyTrain, sources, ['暂无车次']).status).assertEqual('empty');
    });

    it('derives aggregate travel retryability only from child error flags', 0, () => {
      const trainSource: DataSource = {
        provider: '12306', backend: 'local_adapter', operation: 'leftTicket',
        fetchedAt: '2026-07-22T00:00:00.000Z'
      };
      const flightSource: DataSource = {
        provider: '飞常准', backend: 'local_adapter', operation: 'flights',
        fetchedAt: '2026-07-22T00:00:01.000Z'
      };
      const trainData: TrainStructuredData = {
        title: '12306 查询失败', body: 'HTTP 401', summary: 'HTTP 401', trains: []
      };
      const flightData: FlightStructuredData = {
        title: '飞常准查询失败', body: '参数错误', summary: '参数错误', flights: []
      };
      const trainNonRetryable = errorDataResult(
        'train.search', 'trains', 'TRAIN_PROVIDER_HTTP_ERROR', 'HTTP 401', false, [trainSource]
      );
      trainNonRetryable.data = trainData;
      const flightNonRetryable = errorDataResult(
        'flight.search', 'flights', 'FLIGHT_PROVIDER_ERROR', '参数错误', false, [flightSource]
      );
      flightNonRetryable.data = flightData;

      const nonRetryable = combineTravelStructuredResults(
        '北京到上海', trainNonRetryable, flightNonRetryable
      );
      expect(nonRetryable.status).assertEqual('error');
      expect(nonRetryable.sources.length).assertEqual(2);
      expect(nonRetryable.error?.retryable).assertFalse();

      const flightRetryable = errorDataResult(
        'flight.search', 'flights', 'FLIGHT_TRANSPORT_EXCEPTION', 'timeout', true, [flightSource]
      );
      flightRetryable.data = flightData;
      const retryable = combineTravelStructuredResults('北京到上海', trainNonRetryable, flightRetryable);
      expect(retryable.error?.retryable).assertTrue();
    });

    it('treats a successful VariFlight empty list as typed empty data', 0, () => {
      const source: DataSource = {
        provider: '飞常准', backend: 'local_adapter', operation: 'flights',
        fetchedAt: '2026-07-22T00:00:00.000Z'
      };
      const result = flightDataResultFromProviderResponse(
        200,
        '{"success":true,"data":{"flights":[]}}',
        source,
        false,
        '深圳到上海 2026-07-23'
      );

      expect(result.status).assertEqual('empty');
      expect(result.error).assertUndefined();
      expect(result.sources.length).assertEqual(1);
      expect(result.sources[0].operation).assertEqual('flights');
      expect((result.data as FlightStructuredData).flights.length).assertEqual(0);
      expect(JSON.stringify(result.data).indexOf('updateComponents')).assertEqual(-1);
    });

    it('dedupes food operation provenance and preserves empty partial and error states', 0, () => {
      const emptyData: FoodStructuredData = {
        title: '外卖聚合搜索', body: '真实来源', summary: '没有可展示结果', foods: [], rows: []
      };
      const successfulEmpty: FoodProviderResult = {
        provider: '高德', foods: [], error: '高德没有返回可展示餐饮 POI。',
        attempted: true, succeeded: true, operation: 'search'
      };
      const duplicateSuccessfulEmpty: FoodProviderResult = {
        provider: '高德', foods: [], error: '', attempted: true, succeeded: true, operation: 'search'
      };
      const geocodeFailure: FoodProviderResult = {
        provider: '高德', foods: [], error: '地点解析超时', attempted: true, succeeded: false, operation: 'geocode'
      };
      const configOmission: FoodProviderResult = {
        provider: '腾讯地图', foods: [], error: '未配置 TENCENT_MAP_KEY',
        attempted: false, succeeded: false, operation: 'search'
      };

      const empty = foodStructuredDataResultFromProviders(
        emptyData,
        [geocodeFailure, successfulEmpty, duplicateSuccessfulEmpty, configOmission]
      );
      expect(empty.status).assertEqual('empty');
      expect(empty.error).assertUndefined();
      expect(empty.sources.length).assertEqual(2);
      expect(empty.sources[0].operation).assertEqual('geocode');
      expect(empty.sources[1].operation).assertEqual('search');
      expect(empty.sources[0].provider).assertEqual('高德');
      expect(empty.sources[1].provider).assertEqual('高德');
      expect(empty.warnings.length).assertLarger(0);

      const food: A2uiFoodData = {
        name: '真实餐厅', category: '餐饮', address: '深圳', distance: '100米', sourceTags: ['高德']
      };
      const partialData: FoodStructuredData = {
        title: '外卖聚合搜索', body: '真实来源', summary: '1 个结果', foods: [food], rows: []
      };
      const successWithData: FoodProviderResult = {
        provider: '高德', foods: [food], error: '', attempted: true, succeeded: true, operation: 'search'
      };
      expect(foodStructuredDataResultFromProviders(
        partialData, [successWithData, geocodeFailure]
      ).status).assertEqual('partial');

      const providerFailure: FoodProviderResult = {
        provider: '百度地图', foods: [], error: 'HTTP 500', attempted: true, succeeded: false, operation: 'search'
      };
      const error = foodStructuredDataResultFromProviders(emptyData, [providerFailure, configOmission]);
      expect(error.status).assertEqual('error');
      expect(error.error?.code).assertEqual('FOOD_PROVIDER_ERROR');
      expect(error.sources.length).assertEqual(1);
    });

    it('preserves code-specific flight error details and actions in legacy A2UI', 0, () => {
      const invalid = errorDataResult(
        'flight.search', 'flights', 'FLIGHT_INVALID_ARGUMENTS', '参数不足'
      );
      invalid.data = {
        title: '飞常准查询参数不足', body: '参数不足', summary: '参数不足', flights: []
      } as FlightStructuredData;
      const invalidJsonl = flightDataResultA2ui('flight_invalid', invalid);
      expect(invalidJsonl.indexOf('示例：明天北京到上海航班')).assertLarger(-1);
      expect(invalidJsonl.indexOf('补充日期')).assertLarger(-1);
      expect(invalidJsonl.indexOf('补充城市')).assertLarger(-1);

      const malformed = errorDataResult(
        'flight.search', 'flights', 'FLIGHT_INVALID_RESPONSE', '返回内容不是 JSON'
      );
      malformed.data = {
        title: '飞常准返回格式异常', body: '返回内容不是 JSON', summary: '返回内容不是 JSON', flights: []
      } as FlightStructuredData;
      malformed.warnings = ['not-json-provider-body'];
      const malformedJsonl = flightDataResultA2ui('flight_malformed', malformed);
      expect(malformedJsonl.indexOf('not-json-provider-body')).assertLarger(-1);
      expect(malformedJsonl.indexOf('检查供应商返回')).assertLarger(-1);

      const providerError = errorDataResult(
        'flight.search', 'flights', 'FLIGHT_PROVIDER_ERROR', 'invalid key'
      );
      providerError.data = {
        title: '飞常准 Key 或参数需要检查', body: 'invalid key', summary: 'invalid key', flights: []
      } as FlightStructuredData;
      providerError.warnings = ['{"endpoint":"flights"}'];
      const providerJsonl = flightDataResultA2ui('flight_provider', providerError);
      expect(providerJsonl.indexOf('endpoint')).assertLarger(-1);
      expect(providerJsonl.indexOf('检查 Key')).assertLarger(-1);
      expect(providerJsonl.indexOf('换日期或城市')).assertLarger(-1);
    });

    it('preserves code-specific train error details and actions in legacy A2UI', 0, () => {
      const invalid = errorDataResult(
        'train.search', 'trains', 'TRAIN_INVALID_ARGUMENTS', '参数不足'
      );
      invalid.data = {
        title: '12306 查询参数不足', body: '参数不足', summary: '参数不足', trains: []
      } as TrainStructuredData;
      const invalidJsonl = trainDataResultA2ui('train_invalid', invalid);
      expect(invalidJsonl.indexOf('示例：明天北京到上海高铁票')).assertLarger(-1);
      expect(invalidJsonl.indexOf('补充日期')).assertLarger(-1);
      expect(invalidJsonl.indexOf('补充城市')).assertLarger(-1);

      const station = errorDataResult(
        'train.search', 'trains', 'TRAIN_STATION_NOT_FOUND', '车站识别失败'
      );
      station.data = {
        title: '车站识别失败', body: '车站识别失败', summary: '车站识别失败', trains: []
      } as TrainStructuredData;
      station.warnings = ['深圳科技园', '香港'];
      const stationJsonl = trainDataResultA2ui('train_station', station);
      expect(stationJsonl.indexOf('深圳科技园')).assertLarger(-1);
      expect(stationJsonl.indexOf('香港')).assertLarger(-1);
      expect(stationJsonl.indexOf('补充车站名')).assertLarger(-1);
    });

    it('delegates structured hotel reads without rewriting sources or errors', 0, async () => {
      const client = new ScriptedHotelMcpClient(hotelSearchResponse(1));
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          ROLLINGGO_HOTEL_MCP_KEY: 'hotel-test-secret',
          ROLLINGGO_HOTEL_MCP_URL: 'https://hotel.example/mcp'
        }));
        configureHotelMcpClientForTests(client);

        const success = await callStructuredTool('hotel.search', 'ignored prompt', searchArgsForGateway());

        expect(success.status).assertEqual('success');
        expect(success.outputSchema).assertEqual('hotelSearchResults');
        expect(success.sources.length).assertEqual(1);
        expect(success.sources[0].provider).assertEqual('RollingGo');
        expect(success.sources[0].operation).assertEqual('searchHotels');
        expect(client.callCount).assertEqual(1);
      } finally {
        configureHotelMcpClientForTests(null);
        configureLocalProviderConfigFromRawJson('{}');
      }

      const error = await callStructuredTool('hotel.detail', '', detailArgsForGateway());
      expect(error.status).assertEqual('error');
      expect(error.error?.code).assertEqual('HOTEL_CONFIG_MISSING');
      expect(error.sources.length).assertEqual(0);
    });

    it('returns a structured missing-config hotel error', 0, async () => {
      configureLocalProviderConfigFromRawJson('{}');

      const result = await callStructuredHotelTool('hotel.search', new Object());

      expect(result.status).assertEqual('error');
      expect(result.error?.code).assertEqual('HOTEL_CONFIG_MISSING');
      expect(result.sources.length).assertEqual(0);
    });

    it('keeps hotel search RollingGo-only even when generic Maps is configured', 0, async () => {
      const client = new ScriptedHotelMcpClient(hotelSearchResponse(2));
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          ROLLINGGO_HOTEL_MCP_KEY: 'hotel-test-secret',
          ROLLINGGO_HOTEL_MCP_URL: 'https://hotel.example/mcp',
          GOOGLE_MAPS_API_KEY: 'generic-maps-test-key'
        }));
        configureHotelMcpClientForTests(client);
        const result = await callStructuredHotelTool('hotel.search', searchArgsForGateway());
        const data = result.data as HotelSearchResult;
        expect(result.status).assertEqual('success');
        expect(result.sources.length).assertEqual(1);
        expect(result.sources[0].provider).assertEqual('RollingGo');
        expect(result.warnings.join(' ').indexOf('Google Places')).assertEqual(-1);
        expect(data.hotels.length).assertEqual(2);
        expect(JSON.stringify(data.hotels[0]).indexOf('contact')).assertEqual(-1);
      } finally {
        configureHotelMcpClientForTests(null);
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('timestamps a returned transport error after the exact provider operation completes', 0, async () => {
      const client = new ClockedHotelMcpClient({
        ok: false,
        httpStatus: 503,
        errorMessage: 'provider unavailable',
        result: null,
        rawPreview: ''
      });
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          ROLLINGGO_HOTEL_MCP_KEY: 'hotel-test-secret',
          ROLLINGGO_HOTEL_MCP_URL: 'https://hotel.example/mcp'
        }));
        configureHotelMcpClientForTests(client);
        hotelClockValue = '2026-07-20T02:00:00.000Z';
        configureHotelTimestampProviderForTests((): string => hotelClockValue);

        const result = await callStructuredHotelTool('hotel.search', searchArgsForGateway());

        expect(result.status).assertEqual('error');
        expect(result.error?.code).assertEqual('HOTEL_PROVIDER_TRANSPORT_ERROR');
        expect(result.error?.message).assertEqual('provider unavailable');
        expect(result.sources[0].operation).assertEqual('searchHotels');
        expect(result.sources[0].fetchedAt).assertEqual('2026-07-20T02:00:01.000Z');
        expect(client.lastOperation).assertEqual('searchHotels');
      } finally {
        configureHotelTimestampProviderForTests(null);
        configureHotelMcpClientForTests(null);
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('keeps thrown transport exceptions structured while preserving the legacy outer error surface', 0, async () => {
      const client = new ThrowingHotelMcpClient();
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          ROLLINGGO_HOTEL_MCP_KEY: 'hotel-test-secret',
          ROLLINGGO_HOTEL_MCP_URL: 'https://hotel.example/mcp'
        }));
        configureHotelMcpClientForTests(client);

        const structuredResult = await callStructuredHotelTool('hotel.search', searchArgsForGateway());

        expect(structuredResult.status).assertEqual('error');
        expect(structuredResult.error?.code).assertEqual('HOTEL_TRANSPORT_EXCEPTION');
        expect(structuredResult.error?.retryable).assertTrue();
        expect(structuredResult.error?.message).assertEqual('Failed to resolve hotel.example for [REDACTED]');
        expect(structuredResult.sources.length).assertEqual(0);

        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const legacyResult = await callToolGateway(
          defaultToolGatewayUrl(),
          'hotel.search',
          '深圳酒店',
          'surface_hotel_transport_exception',
          'model_tool_request',
          noop,
          null,
          searchArgsForGateway()
        );

        expect(legacyResult.raw.indexOf('工具供应商调用异常')).assertLarger(-1);
        expect(legacyResult.raw.indexOf('Failed to resolve hotel.example for [REDACTED]')).assertLarger(-1);
        expect(legacyResult.raw.indexOf('本机工具已运行，但真实供应商调用失败。')).assertLarger(-1);
        expect(legacyResult.raw.indexOf('请检查设备网络、供应商 TLS/接口状态，或稍后重试。')).assertLarger(-1);
        expect(legacyResult.raw.indexOf('重新查询')).assertLarger(-1);
      } finally {
        configureHotelMcpClientForTests(null);
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('returns a structured hotel inner provider error', 0, async () => {
      const client = new ScriptedHotelMcpClient({
        ok: true,
        httpStatus: 200,
        errorMessage: '',
        result: {
          isError: false,
          structuredContent: looseObject('{"success":false,"message":"provider rejected search","hotelInformationList":[]}')
        },
        rawPreview: ''
      });
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          ROLLINGGO_HOTEL_MCP_KEY: 'hotel-test-secret',
          ROLLINGGO_HOTEL_MCP_URL: 'https://hotel.example/mcp'
        }));
        configureHotelMcpClientForTests(client);

        const result = await callStructuredHotelTool('hotel.search', searchArgsForGateway());

        expect(result.status).assertEqual('error');
        expect(result.error?.code).assertEqual('HOTEL_PROVIDER_ERROR');
        expect(result.error?.message).assertEqual('provider rejected search');

        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const legacyResult = await callToolGateway(
          defaultToolGatewayUrl(),
          'hotel.search',
          '深圳酒店',
          'surface_hotel_inner_error',
          'model_tool_request',
          noop,
          null,
          searchArgsForGateway()
        );
        expect(legacyResult.raw.indexOf('酒店供应商调用失败')).assertLarger(-1);
        expect(legacyResult.raw.indexOf('工具供应商调用异常')).assertEqual(-1);
      } finally {
        configureHotelMcpClientForTests(null);
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('rejects surface-derived and unknown hotel tools without provider calls', 0, async () => {
      const client = new ScriptedHotelMcpClient({
        ok: true,
        httpStatus: 200,
        errorMessage: '',
        result: { isError: false, structuredContent: new Object() },
        rawPreview: ''
      });
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          ROLLINGGO_HOTEL_MCP_KEY: 'hotel-test-secret',
          ROLLINGGO_HOTEL_MCP_URL: 'https://hotel.example/mcp'
        }));
        configureHotelMcpClientForTests(client);

        const navigate = await callStructuredHotelTool('hotel.navigate', detailArgsForGateway());
        const call = await callStructuredHotelTool('hotel.cancel', detailArgsForGateway());
        const unknown = await callStructuredHotelTool('hotel.cancel', detailArgsForGateway());

        expect(navigate.status).assertEqual('error');
        expect(navigate.error?.code).assertEqual('HOTEL_TOOL_UNSUPPORTED');
        expect(call.status).assertEqual('error');
        expect(call.error?.code).assertEqual('HOTEL_TOOL_UNSUPPORTED');
        expect(unknown.status).assertEqual('error');
        expect(unknown.error?.code).assertEqual('HOTEL_TOOL_UNSUPPORTED');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const legacyNavigate = await callToolGateway(
          defaultToolGatewayUrl(), 'hotel.navigate', '', 'hotel_nav_bypass', '', noop, null, detailArgsForGateway()
        );
        const legacyCall = await callToolGateway(
          defaultToolGatewayUrl(), 'hotel.cancel', '', 'hotel_cancel_bypass', '', noop, null, detailArgsForGateway()
        );
        const legacyUnknown = await callToolGateway(
          defaultToolGatewayUrl(), 'hotel.cancel', '', 'hotel_unknown_bypass', '', noop, null, detailArgsForGateway()
        );
        expect(legacyNavigate.raw.indexOf('Unsupported hotel tool: hotel.navigate.')).assertLarger(-1);
        expect(legacyCall.raw.indexOf('Unsupported hotel tool: hotel.cancel.')).assertLarger(-1);
        expect(legacyUnknown.raw.indexOf('Unsupported hotel tool: hotel.cancel.')).assertLarger(-1);
        expect(client.callCount).assertEqual(0);
      } finally {
        configureHotelMcpClientForTests(null);
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('defaults ride tools to real provider mode unless mock is explicitly enabled', 0, () => {
      try {
        configureLocalProviderConfigFromRawJson('{}');
        let summary = localProviderConfigDebugSummary();
        expect(summary.indexOf('rideMockEnabled=false')).assertLarger(-1);

        configureLocalProviderConfigFromRawJson(JSON.stringify({
          RIDE_MOCK_ENABLED: 'true'
        }));
        summary = localProviderConfigDebugSummary();
        expect(summary.indexOf('rideMockEnabled=true')).assertLarger(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('uses production Didi MCP endpoint for all Didi calls when sandbox is disabled', 0, () => {
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          DIDI_MCP_KEY: 'didi-secret-key',
          DIDI_MCP_SANDBOX: 'false',
          RIDE_MOCK_ENABLED: 'false'
        }));

        const summary = localProviderConfigDebugSummary();
        expect(summary.indexOf('didiMcpSandbox=false')).assertLarger(-1);
        expect(rideDidiQueryMcpUrlForTest()).assertEqual('https://mcp.didichuxing.com/mcp-servers?key=didi-secret-key');
        expect(rideDidiOrderMcpUrlForTest()).assertEqual('https://mcp.didichuxing.com/mcp-servers?key=didi-secret-key');
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('toggles Didi MCP sandbox mode at runtime for all Didi routing', 0, () => {
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          DIDI_MCP_KEY: 'didi-secret-key',
          DIDI_MCP_SANDBOX: 'true',
          RIDE_MOCK_ENABLED: 'false'
        }));
        expect(rideDidiMcpSandboxEnabledForRuntime()).assertTrue();
        expect(rideDidiQueryMcpUrlForTest()).assertEqual('https://mcp.didichuxing.com/mcp-servers-sandbox?key=didi-secret-key');
        expect(rideDidiOrderMcpUrlForTest()).assertEqual('https://mcp.didichuxing.com/mcp-servers-sandbox?key=didi-secret-key');

        configureDidiMcpSandboxForRuntime(false);
        expect(rideDidiMcpSandboxEnabledForRuntime()).assertFalse();
        expect(localProviderConfigDebugSummary().indexOf('didiMcpSandbox=false')).assertLarger(-1);
        expect(rideDidiQueryMcpUrlForTest()).assertEqual('https://mcp.didichuxing.com/mcp-servers?key=didi-secret-key');
        expect(rideDidiOrderMcpUrlForTest()).assertEqual('https://mcp.didichuxing.com/mcp-servers?key=didi-secret-key');

        configureDidiMcpSandboxForRuntime(true);
        expect(rideDidiMcpSandboxEnabledForRuntime()).assertTrue();
        expect(localProviderConfigDebugSummary().indexOf('didiMcpSandbox=true')).assertLarger(-1);
        expect(rideDidiQueryMcpUrlForTest()).assertEqual('https://mcp.didichuxing.com/mcp-servers-sandbox?key=didi-secret-key');
        expect(rideDidiOrderMcpUrlForTest()).assertEqual('https://mcp.didichuxing.com/mcp-servers-sandbox?key=didi-secret-key');
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('lets disabled Didi sandbox override ride mock config', 0, async () => {
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          DIDI_MCP_KEY: 'didi-secret-key',
          DIDI_MCP_URL: 'http://127.0.0.1:1/mcp',
          DIDI_MCP_SANDBOX: 'false',
          RIDE_MOCK_ENABLED: 'true'
        }));
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'ride.estimate',
          '帮我看从深圳湾万象城到深圳北站打车多少钱',
          'surface_ride_mock_override',
          'model_tool_request',
          noop,
          null,
          looseObject('{"origin":"深圳湾万象城","destination":"深圳北站","city":"深圳"}')
        );

        const rendered = genericToolResults(result.surface);
        expect(result.ok).assertTrue();
        expect(rendered.length).assertLarger(0);
        expect(rendered[0].sourceTag).assertEqual('滴滴');
        expect(rendered[0].status).assertEqual('error');
        expect(rendered[0].summary.indexOf('模拟')).assertEqual(-1);
        expect(rideDidiQueryMcpUrlForTest()).assertEqual('http://127.0.0.1:1/mcp?key=didi-secret-key');
        expect(rideDidiOrderMcpUrlForTest()).assertEqual('http://127.0.0.1:1/mcp?key=didi-secret-key');
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('registers fixed ride tools while keeping raw MCP order and driver tools hidden', 0, () => {
      expect(isRegisteredToolId('ride.estimate')).assertTrue();
      expect(isRegisteredToolId('ride.app.link')).assertTrue();
      expect(isRegisteredToolId('ride.order.create')).assertTrue();
      expect(isRegisteredToolId('ride.order.cancel')).assertTrue();
      expect(isRegisteredToolId('ride.driver.location')).assertTrue();
      expect(isRegisteredToolId('taxi_create_order')).assertFalse();
      expect(isRegisteredToolId('taxi_cancel_order')).assertFalse();
      expect(isRegisteredToolId('taxi_query_order')).assertFalse();
      expect(isRegisteredToolId('taxi_get_driver_location')).assertFalse();
    });

    it('renders ride estimate missing Didi config as a real provider error', 0, async () => {
      try {
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};

        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'ride.estimate',
          '帮我看从深圳湾万象城到深圳北站打车多少钱',
          'surface_ride_missing_didi',
          'model_tool_request',
          noop,
          null,
          looseObject('{"origin":"深圳湾万象城","destination":"深圳北站","city":"深圳"}')
        );

        const rendered = genericToolResults(result.surface);
        expect(result.ok).assertTrue();
        expect(rendered.length).assertLarger(0);
        expect(rendered[0].sourceTag).assertEqual('滴滴');
        expect(rendered[0].status).assertEqual('needs_input');
        expect(rendered[0].summary.indexOf('DIDI_MCP_KEY')).assertLarger(-1);
        expect(result.raw.indexOf('taxi_create_order')).assertEqual(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('blocks non-RFC3339 Calendar times before Composio', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'calendar.event.create',
          '给我明天下午3点创建一个标题为 CalendarCRUDQA-C-20260716 的30分钟日程',
          'surface_calendar_create_invalid_time',
          'model_tool_request',
          noop,
          null,
          looseObject('{"title":"CalendarCRUDQA-C-20260716","start":"明天 15:00","end":"明天 15:30","timezone":"Asia/Shanghai"}')
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered[0].status).assertEqual('needs_input');
        expect(rendered[0].summary.indexOf('开始时间')).assertLarger(-1);
        expect(rendered[0].summary.indexOf('结束时间')).assertLarger(-1);
        expect(result.raw.indexOf('Composio 未配置')).assertEqual(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('normalizes Didi estimate and ride app links without creating orders', 0, () => {
      const estimatePayload = JSON.parse('{"structuredContent":{"items":[{"productName":"快车","productCategory":"express","priceText":"约 48 元"},{"productName":"专车","productCategory":"premium","priceText":"约 88 元"}],"traceId":"trace-123"}}') as Object;
      const didiLinkPayload = JSON.parse('{"structuredContent":{"url":"diditaxi://ride?traceId=trace-123"}}') as Object;
      const amapLinkPayload = JSON.parse('{"structuredContent":{"url":"amapuri://drive/takeTaxi?sourceApplication=aiphone"}}') as Object;

      const results = rideResultsFromMcpPayloadsForTest(
        '深圳湾万象城',
        '深圳北站',
        estimatePayload,
        didiLinkPayload,
        amapLinkPayload
      );

      expect(results.length).assertEqual(2);
      expect(results[0].sourceTag).assertEqual('滴滴');
      expect(results[0].toolName).assertEqual('ride.estimate');
      expect(results[0].summary.indexOf('快车')).assertLarger(-1);
      expect(results[0].summary.indexOf('48')).assertLarger(-1);
      expect(results[0].rawPreview.indexOf('taxi_create_order')).assertEqual(-1);
      expect(results[0].actions === undefined ? 0 : results[0].actions.length).assertEqual(2);
      if (results[0].actions !== undefined) {
        expect(results[0].actions[0].id).assertEqual('ride.order.confirm');
        expect(results[0].actions[0].label).assertEqual('确认叫快车');
      }
      expect(results[1].toolName).assertEqual('ride.app.link');
      expect(results[1].rows[1].label).assertEqual('滴滴链接');
      expect(results[1].rows[2].label).assertEqual('高德链接');
    });

    it('keeps ride estimate usable when optional app link generation is rate limited', 0, () => {
      expect(rideShouldSurfaceAppLinkErrorForTest('ride.estimate')).assertFalse();
      expect(rideShouldSurfaceAppLinkErrorForTest('ride.app.link')).assertTrue();
    });

    it('carries ride route coordinates from estimate action into later order flow', 0, () => {
      const estimatePayload = JSON.parse('{"structuredContent":{"items":[{"productName":"快车","productCategory":"express","priceText":"约 48 元"}],"traceId":"trace-123"}}') as Object;
      const emptyLinkPayload = JSON.parse('{}') as Object;
      const results = rideResultsFromMcpPayloadsForTest(
        '华为坂田基地',
        '秋港花园',
        estimatePayload,
        emptyLinkPayload,
        emptyLinkPayload,
        '114.066231,22.657805',
        '114.060432,22.548829'
      );

      const actionArgs = JSON.stringify(results[0].actions === undefined ? {} : results[0].actions[0].args);
      expect(actionArgs.indexOf('"routeText":"华为坂田基地 → 秋港花园"')).assertLarger(-1);
      expect(actionArgs.indexOf('"pickupLocation":"114.066231,22.657805"')).assertLarger(-1);
      expect(actionArgs.indexOf('"destinationLocation":"114.060432,22.548829"')).assertLarger(-1);
      expect(actionArgs.indexOf('"estimateCacheJson"')).assertLarger(-1);
      expect(actionArgs.indexOf('约 48 元')).assertLarger(-1);
    });

    it('normalizes ride order create and cancel args behind explicit confirmation', 0, () => {
      expect(rideOrderConfirmedForTest(looseObject('{"confirmed":true}'))).assertTrue();
      expect(rideOrderConfirmedForTest(looseObject('{"confirmation":"确认下单"}'))).assertTrue();
      expect(rideOrderConfirmedForTest(looseObject('{"confirmation":"帮我叫车"}'))).assertFalse();

      const createArgs = JSON.stringify(rideDidiCreateOrderArgsForTest(
        looseObject('{"productCategory":"express","estimateTraceId":"trace-123","confirmed":true}')
      ));
      expect(createArgs.indexOf('"product_category":"express"')).assertLarger(-1);
      expect(createArgs.indexOf('"estimate_trace_id":"trace-123"')).assertLarger(-1);

      const cancelArgs = JSON.stringify(rideDidiCancelOrderArgsForTest(
        looseObject('{"orderId":"order-123","reason":"用户取消"}')
      ));
      expect(cancelArgs.indexOf('"order_id":"order-123"')).assertLarger(-1);
      expect(cancelArgs.indexOf('"reason":"用户取消"')).assertLarger(-1);

      const driverLocationArgs = JSON.stringify(rideDidiDriverLocationArgsForTest(
        looseObject('{"orderId":"order-123"}')
      ));
      expect(driverLocationArgs.indexOf('"order_id":"order-123"')).assertLarger(-1);
    });

    it('deduplicates repeated ride order create requests for the same vehicle selection', 0, () => {
      expect(rideOrderCreateDedupBlockedForTest('express|trace-123', 'express|trace-123', 1000)).assertTrue();
      expect(rideOrderCreateDedupBlockedForTest('express|trace-123', 'premium|trace-123', 1000)).assertFalse();
      expect(rideOrderCreateDedupBlockedForTest('express|trace-123', 'express|trace-123', 130000)).assertFalse();
    });

    it('renders ride order create quota failures as a quota-specific error', 0, () => {
      expect(rideOrderCreateErrorTitleForTest('rate limit exceeded: user_taxi_create_order quota exceeded')).assertEqual('下单额度已耗尽');
      expect(rideOrderCreateErrorTitleForTest('network timeout')).assertEqual('滴滴下单失败');
    });

    it('treats successful driver location response without coordinates as pending data', 0, () => {
      const result = rideDriverLocationResultForTest(looseObject('{"data":{}}'), 'order-123');

      expect(result.toolName).assertEqual('ride.driver.location');
      expect(result.status).assertEqual('success');
      expect(result.summary.indexOf('没有可展示的位置')).assertLarger(-1);
      expect(result.rows[0].label).assertEqual('订单号');
      expect(result.rows[0].value).assertEqual('order-123');
      expect(result.rows.length).assertEqual(2);
    });

    it('extracts Didi sandbox driver coordinates from text payload', 0, () => {
      const result = rideDriverLocationResultForTest(
        looseObject('{"text":"【司机位置】\\n纬度：39.882325\\n经度：116.297345\\n","eta":360}'),
        'order-123',
        '116.300000,39.880000',
        '116.310000,39.890000'
      );

      expect(result.status).assertEqual('success');
      expect(result.summary).assertEqual('已返回司机当前位置。');
      expect(result.rows[1].label).assertEqual('路线');
      expect(result.rows[2].label).assertEqual('起点坐标');
      expect(result.rows[2].value).assertEqual('116.300000,39.880000');
      expect(result.rows[4].label).assertEqual('司机位置');
      expect(result.rows[4].value).assertEqual('116.297345,39.882325');
      expect(result.rows[5].label).assertEqual('预计接驾时间');
      expect(result.rows[5].value).assertEqual('预计 6 分钟接驾');
      if (result.actions !== undefined) {
        expect(result.actions[0].label).assertEqual('刷新司机位置');
        expect(JSON.stringify(result.actions[0].args).indexOf('"pickupLocation":"116.300000,39.880000"')).assertLarger(-1);
      }
    });

    it('offers retry and vehicle change actions after cancelling ride order', 0, () => {
      const result = rideCancelOrderResultForTest(looseObject('{"status":"cancelled"}'), 'order-123');

      expect(result.toolName).assertEqual('ride.order.cancel');
      if (result.actions !== undefined) {
        expect(result.actions.length).assertEqual(2);
        expect(result.actions[0].label).assertEqual('重新查询');
        expect(result.actions[0].variant).assertEqual('primary');
        expect(result.actions[1].label).assertEqual('换车型');
        expect(result.actions[1].variant).assertEqual('secondary');
        expect(result.actions[1].kind).assertEqual('client');
      }
    });

    it('routes ride order create to the configured Didi MCP when sandbox is disabled', 0, () => {
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          DIDI_MCP_KEY: 'didi-secret-key',
          DIDI_MCP_URL: 'http://127.0.0.1:1/mcp',
          RIDE_MOCK_ENABLED: 'false',
          DIDI_MCP_SANDBOX: 'false'
        }));

        expect(rideDidiQueryMcpUrlForTest()).assertEqual('http://127.0.0.1:1/mcp?key=didi-secret-key');
        expect(rideDidiOrderMcpUrlForTest()).assertEqual('http://127.0.0.1:1/mcp?key=didi-secret-key');
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('routes ride driver location to the configured Didi MCP when sandbox is disabled', 0, () => {
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          DIDI_MCP_KEY: 'didi-secret-key',
          DIDI_MCP_URL: 'http://127.0.0.1:1/mcp',
          RIDE_MOCK_ENABLED: 'false',
          DIDI_MCP_SANDBOX: 'false'
        }));

        expect(rideDidiQueryMcpUrlForTest()).assertEqual('http://127.0.0.1:1/mcp?key=didi-secret-key');
        expect(rideDidiOrderMcpUrlForTest()).assertEqual('http://127.0.0.1:1/mcp?key=didi-secret-key');
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('builds Amap taxi MCP args with the tools/list schema fields', 0, () => {
      const args = rideAmapRequestArgsForTest('114.060000,22.540000', '114.070000,22.550000');
      const json = JSON.stringify(args);

      expect(json.indexOf('"slon":"114.060000"')).assertLarger(-1);
      expect(json.indexOf('"slat":"22.540000"')).assertLarger(-1);
      expect(json.indexOf('"sname":"起点"')).assertLarger(-1);
      expect(json.indexOf('"dlon":"114.070000"')).assertLarger(-1);
      expect(json.indexOf('"dlat":"22.550000"')).assertLarger(-1);
      expect(json.indexOf('"dname":"终点"')).assertLarger(-1);
      expect(json.indexOf('"slon"')).assertLarger(-1);
      expect(json.indexOf('"slat"')).assertLarger(-1);
      expect(json.indexOf('"sname"')).assertLarger(-1);
      expect(json.indexOf('"dlon"')).assertLarger(-1);
      expect(json.indexOf('"dlat"')).assertLarger(-1);
      expect(json.indexOf('"dname"')).assertLarger(-1);
      expect(json.indexOf('"origin"')).assertEqual(-1);
      expect(json.indexOf('"destination"')).assertEqual(-1);
      expect(json.indexOf('"from"')).assertEqual(-1);
      expect(json.indexOf('"to"')).assertEqual(-1);
      expect(json.indexOf('"city"')).assertEqual(-1);
    });

    it('derives ride coordinates and Didi city from Amap geocode payloads', 0, () => {
      const payload = JSON.parse('{"status":"1","geocodes":[{"formatted_address":"广东省深圳市龙岗区华为坂田基地","province":"广东省","city":"深圳市","district":"龙岗区","location":"114.066231,22.657805","level":"兴趣点"}]}') as Object;
      const point = JSON.stringify(rideAmapGeocodePointForTest('深圳华为坂田基地', payload));

      expect(point.indexOf('"name":"深圳华为坂田基地"')).assertLarger(-1);
      expect(point.indexOf('"lng":"114.066231"')).assertLarger(-1);
      expect(point.indexOf('"lat":"22.657805"')).assertLarger(-1);
      expect(point.indexOf('"location":"114.066231,22.657805"')).assertLarger(-1);
      expect(rideDidiCityFromAmapGeocodeForTest(payload)).assertEqual('深圳');
    });

    it('uses Amap Web key rather than MCP key for ride geocoding', 0, () => {
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          AMAP_KEY: 'amap-web-geocode-key',
          AMAP_MCP_KEY: 'amap-mcp-link-key'
        }));

        expect(rideAmapGeocodeKeyForTest()).assertEqual('amap-web-geocode-key');
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('extracts Amap ride links from plain MCP text content', 0, () => {
      const response = '{"jsonrpc":"2.0","id":2,"result":{"content":[{"type":"text","text":"高德打车唤端链接：https://uri.amap.com/taxi?sourceApplication=aiphone"}]}}';

      expect(rideLinkFromMcpResponseTextForTest(response)).assertEqual('https://uri.amap.com/taxi?sourceApplication=aiphone');
    });

    it('surfaces MCP tool error text for ride providers', 0, () => {
      let message = '';
      try {
        rideLinkFromMcpResponseTextForTest('{"jsonrpc":"2.0","id":2,"result":{"isError":true,"content":[{"type":"text","text":"参数校验失败：origin 必填"}]}}');
      } catch (error) {
        message = error instanceof Error ? error.message : JSON.stringify(error);
      }

      expect(message.indexOf('origin 必填')).assertLarger(-1);
    });

    it('classifies transient PayPal DNS and timeout errors for retry', 0, () => {
      expect(isTransientPayPalRequestErrorForTest('Failed to resolve the host name')).assertTrue();
      expect(isTransientPayPalRequestErrorForTest('Operation timeout')).assertTrue();
      expect(isTransientPayPalRequestErrorForTest('HTTP 422 payer action required')).assertFalse();
      expect(payPalApiFallbackUrlForTest('https://api-m.paypal.com/v1/oauth2/token')).assertEqual('https://api.paypal.com/v1/oauth2/token');
      expect(payPalApiFallbackUrlForTest('https://api-m.sandbox.paypal.com/v2/checkout/orders')).assertEqual('https://api.sandbox.paypal.com/v2/checkout/orders');
      const help = paypalGooglePayNetworkHelpForTest('paypal', 'google_pay', 'Failed to resolve the host name');
      expect(help.indexOf('先关闭 VPN')).assertLarger(-1);
      expect(help.indexOf('Pay with G Pay')).assertLarger(-1);
      expect(paypalGooglePayNetworkHelpForTest('paypal', 'google_pay', 'HTTP 422 payer action required')).assertEqual('HTTP 422 payer action required');
    });

    it('renders aggregate mail missing QQ config as real provider status', 0, async () => {
      try {
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const args: MailSearchArgs = {
          query: 'newer_than:30d',
          pageSize: 10,
          providers: ['qq'],
          intentSummary: ''
        };
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'mail.search',
          '帮我看邮箱里最新的重要邮件',
          'surface_mail_missing_qq',
          'model_tool_request',
          noop,
          null,
          args
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered.length).assertLarger(0);
        expect(rendered[0].sourceTag).assertEqual('QQ Mail');
        expect(rendered[0].status).assertEqual('error');
        expect(rendered[0].summary.indexOf('QQ_MAIL_ADDRESS')).assertLarger(-1);
        expect(result.raw.indexOf('auth code')).assertEqual(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('continues aggregate mail when Gmail is routed through Composio auth state', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const args: MailSearchArgs = {
          query: 'newer_than:30d',
          pageSize: 10,
          providers: ['gmail', 'qq'],
          intentSummary: ''
        };
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'mail.search',
          '帮我查看邮箱里的最新的重要邮件',
          'surface_mail_gmail_auth',
          'model_tool_request',
          noop,
          null,
          args
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered.length).assertEqual(3);
        expect(rendered[0].sourceTag).assertEqual('Gmail');
        expect(rendered[0].toolName).assertEqual('mail.provider.status');
        expect(rendered[0].status).assertEqual('needs_auth');
        expect(rendered[0].summary.indexOf('Composio 未配置')).assertLarger(-1);
        expect(rendered[1].sourceTag).assertEqual('QQ Mail');
        expect(rendered[1].toolName).assertEqual('mail.provider.status');
        expect(rendered[2].sourceTag).assertEqual('Composio Gmail');
        expect(rendered[2].toolName).assertEqual('gmail.mail.search');
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('extracts aggregate mail keyword when model timeout falls back without args', 0, () => {
      const parsed = mailSearchArgs('聚合搜索 Gmail 和 QQ 邮箱里关键词 loopy 的邮件', null);

      expect(parsed.query).assertEqual('newer_than:30d loopy');
      expect(parsed.providers.length).assertEqual(3);
      expect(parsed.providers[0]).assertEqual('gmail');
      expect(parsed.providers[1]).assertEqual('qq');
      expect(parsed.providers[2]).assertEqual('outlook');
    });

    it('does not treat latest important as aggregate mail keyword text', 0, () => {
      const args = JSON.parse('{"query":"最新 重要","providers":["gmail","qq","outlook"]}') as Object;
      const parsed = mailSearchArgs('帮我查看邮箱里最新的重要邮件', args);
      const englishArgs = JSON.parse('{"query":"latest important","providers":["gmail","qq","outlook"]}') as Object;
      const englishParsed = mailSearchArgs('帮我查看邮箱里最新的重要邮件', englishArgs);

      expect(parsed.query).assertEqual('newer_than:30d');
      expect(englishParsed.query).assertEqual('newer_than:30d');
      expect(parsed.providers.length).assertEqual(3);
      expect(parsed.providers[1]).assertEqual('qq');
    });

    it('does not claim QQ draft success when config is missing', 0, async () => {
      try {
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const args: MailDraftArgs = {
          provider: 'qq',
          accountLabel: '',
          threadId: '',
          messageId: 'qq-1',
          to: ['sender@qq.com'],
          subject: 'Re: QQ latest',
          body: 'Thanks.',
          replyMode: 'reply',
          contextSummary: ''
        };
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'mail.draft.create',
          'Create QQ reply draft',
          'surface_mail_draft_missing_qq',
          'model_tool_request',
          noop,
          null,
          args
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered[0].sourceTag).assertEqual('QQ Mail');
        expect(rendered[0].status).assertEqual('error');
        expect(rendered[0].summary.indexOf('missing')).assertLarger(-1);
        expect(rendered[0].summary.indexOf('已保存')).assertEqual(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('registers YouTube tools on the same local tool framework', 0, () => {
      expect(isRegisteredToolId('youtube.video.search')).assertTrue();
      expect(isRegisteredToolId('youtube.mine.playlists')).assertTrue();
      expect(isRegisteredToolId('youtube.mine.subscriptions')).assertTrue();
      expect(isRegisteredToolId('media.video.search')).assertTrue();
      expect(isRegisteredToolId('youtube.unknown')).assertFalse();
    });

    it('registers WhatsApp Business send, Calendar delete, and Maps routes', 0, () => {
      expect(isRegisteredToolId('calendar.events.search')).assertTrue();
      expect(isRegisteredToolId('calendar.event.create')).assertTrue();
      expect(isRegisteredToolId('calendar.event.update')).assertTrue();
      expect(isRegisteredToolId('maps.place.search')).assertTrue();
      expect(isRegisteredToolId('maps.place.details')).assertTrue();
      expect(isRegisteredToolId('calendar.event.delete')).assertTrue();
      expect(isRegisteredToolId('maps.route.open')).assertTrue();
      expect(isRegisteredToolId('whatsapp.message.send')).assertTrue();
    });

    it('requires the exact client confirmation action for WhatsApp and Calendar delete', 0, () => {
      expect(whatsAppSendConfirmedForTest('', looseObject('{"confirmed":true}'))).assertFalse();
      expect(whatsAppSendConfirmedForTest('wrong.action', looseObject('{"confirmed":true}'))).assertFalse();
      expect(whatsAppSendConfirmedForTest('whatsapp.message.send.confirm', looseObject('{"confirmed":false}'))).assertFalse();
      expect(whatsAppSendConfirmedForTest('whatsapp.message.send.confirm', looseObject('{"confirmed":true}'))).assertTrue();
      expect(calendarDeleteConfirmedForTest('', looseObject('{"confirmed":true}'))).assertFalse();
      expect(calendarDeleteConfirmedForTest('wrong.action', looseObject('{"confirmed":true}'))).assertFalse();
      expect(calendarDeleteConfirmedForTest('calendar.event.delete.confirm', looseObject('{"confirmed":false}'))).assertFalse();
      expect(calendarDeleteConfirmedForTest('calendar.event.delete.confirm', looseObject('{"confirmed":true}'))).assertTrue();
    });

    it('keeps WhatsApp provider errors concise and actionable', 0, () => {
      expect(whatsAppProviderFailureSummaryForTest(
        'HTTP 400: no active connection found for toolkit whatsapp'
      )).assertEqual('WhatsApp 授权刚完成，请返回 App 后重试一次。');
      expect(whatsAppProviderFailureSummaryForTest(
        'Graph API code 100 error_subcode 33 object does not exist or lacks permissions'
      )).assertEqual('当前 Business 账户的 WABA 配置无效或缺少管理权限，请重新授权。');
      expect(whatsAppProviderFailureSummaryForTest(
        'WhatsApp API error (HTTP 400): (#133010) Account not registered'
      )).assertEqual('当前 Business 发送号码尚未注册到 WhatsApp Cloud API，请先在 Meta 后台完成号码验证与 API 注册。');
    });

    it('preserves the configured WhatsApp Business sender through confirmation', 0, async () => {
      const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
      const result = await callToolGateway(
        defaultToolGatewayUrl(),
        'whatsapp.message.send',
        '用 WhatsApp 发送消息',
        'surface_whatsapp_confirmation',
        '',
        noop,
        null,
        looseObject('{"toNumber":"+8613800138000","text":"十分钟后到","phoneNumberId":"712594308615206","wabaId":"123456789"}')
      );
      const rendered = genericToolResults(result.surface);
      const actionJson = JSON.stringify(rendered[0].actions);
      expect(rendered[0].status).assertEqual('confirm_required');
      expect(actionJson.indexOf('"kind":"prompt"')).assertLarger(-1);
      expect(actionJson.indexOf('712594308615206')).assertLarger(-1);
      expect(actionJson.indexOf('123456789')).assertLarger(-1);
    });

    it('dispatches Calendar delete confirmation back through the fixed tool path', 0, async () => {
      const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
      const result = await callToolGateway(
        defaultToolGatewayUrl(),
        'calendar.event.delete',
        '删除日程',
        'surface_calendar_delete_confirmation',
        '',
        noop,
        null,
        looseObject('{"eventId":"event-1","calendarId":"primary"}')
      );
      const rendered = genericToolResults(result.surface);
      const actionJson = JSON.stringify(rendered[0].actions);
      expect(rendered[0].status).assertEqual('confirm_required');
      expect(actionJson.indexOf('calendar.event.delete.confirm')).assertLarger(-1);
      expect(actionJson.indexOf('"kind":"prompt"')).assertLarger(-1);
    });

    it('resolves a natural-language Calendar delete only when the Provider search has one event', 0, () => {
      const event: DynamicGenericToolResult = {
        sourceTag: 'Composio Google Calendar',
        toolName: 'calendar.events.search',
        title: '明天下午的测试日程',
        status: 'success',
        summary: 'real event',
        rows: [
          { label: 'Event ID', value: 'event-real-123' },
          { label: 'Start', value: '2026-07-17T15:00:00+08:00' },
          { label: 'End', value: '2026-07-17T15:30:00+08:00' }
        ],
        rawPreview: ''
      };

      const target: Object | null = calendarDeleteTargetFromResultsForTest([event]);
      expect(JSON.stringify(target).indexOf('event-real-123')).assertLarger(-1);
      expect(calendarDeleteTargetFromResultsForTest([event, event]) === null).assertTrue();
    });

    it('loads Google app API keys and OAuth config from local provider raw JSON', 0, () => {
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          GOOGLE_MAPS_API_KEY: 'maps-key',
          YOUTUBE_API_KEY: 'youtube-key',
          GOOGLE_OAUTH_CLIENT_ID: 'client-123.apps.googleusercontent.com',
          GOOGLE_OAUTH_CLIENT_SECRET: 'secret-456',
          GOOGLE_OAUTH_REDIRECT_URI: 'com.example.aiphonedemo:/oauth/google',
          GOOGLE_CLOUD_PROJECT: 'aiphone-cloud'
        }));

        const summary = localProviderConfigDebugSummary();
        expect(summary.indexOf('googleMapsApiKey=present(8)')).assertLarger(-1);
        expect(summary.indexOf('youtubeApiKey=present(11)')).assertLarger(-1);
        expect(summary.indexOf('googleOauthClientId=present(37)')).assertLarger(-1);
        expect(summary.indexOf('gmailMcpUserProject=present')).assertLarger(-1);
        expect(summary.indexOf('youtube-key')).assertEqual(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('loads Zhihu aggregate search key from local provider raw JSON without exposing secrets', 0, () => {
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          ZHIHU_API_KEY: 'zhihu-api-key'
        }));

        const summary = localProviderConfigDebugSummary();
        expect(summary.indexOf('zhihuApiKey=present(13)')).assertLarger(-1);
        expect(summary.indexOf('zhihu-api-key')).assertEqual(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('renders Maps missing-key errors without falling back to food search', 0, async () => {
      try {
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'maps.place.search',
          '帮我用 Google Maps 搜索深圳坂田华为基地附近的咖啡店',
          'surface_maps_missing_key',
          'model_tool_request',
          noop
        );
        expect(result.ok).assertTrue();
        expect(genericToolResults(result.surface)[0].status).assertEqual('error');
        expect(genericToolResults(result.surface)[0].toolName).assertEqual('maps.place.search');
        expect(genericToolResults(result.surface)[0].sourceTag).assertEqual('Google Places API');
        expect(result.raw.indexOf('GOOGLE_MAPS_API_KEY')).assertLarger(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('uses Composio auth state for Calendar fixed tools without fake events', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'calendar.events.search',
          '帮我看今天的 Google Calendar 日程',
          'surface_calendar_auth',
          'model_tool_request',
          noop
        );
        expect(result.ok).assertTrue();
        expect(genericToolResults(result.surface)[0].toolName).assertEqual('calendar.events.search');
        expect(genericToolResults(result.surface)[0].sourceTag).assertEqual('Composio Google Calendar');
        expect(genericToolResults(result.surface)[0].status).assertEqual('needs_auth');
        expect(result.raw.indexOf('Composio 未配置')).assertLarger(-1);
        expect(result.raw.indexOf('AIPhoneDemo smoke')).assertEqual(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('keeps Gmail blocked-send and open-web A2UI on the local gateway', 0, async () => {
      const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
      const blockedResult: A2uiCallResult = await callToolGateway(
        defaultToolGatewayUrl(),
        'gmail.message.send',
        '帮我 Gmail 直接发送这封邮件',
        'surface_gmail_blocked',
        'client_intent_fallback',
        noop
      );
      const webResult: A2uiCallResult = await callToolGateway(
        defaultToolGatewayUrl(),
        'gmail.open.web',
        '打开 Gmail 网页版',
        'surface_gmail_web',
        'client_intent_fallback',
        noop
      );

      expect(blockedResult.ok).assertTrue();
      expect(genericToolResults(blockedResult.surface)[0].status).assertEqual('blocked');
      expect(genericToolResults(blockedResult.surface)[0].summary.indexOf('不会自动发送 Gmail')).assertLarger(-1);

      expect(webResult.ok).assertTrue();
      expect(genericToolResults(webResult.surface)[0].toolName).assertEqual('gmail.open.web');
      expect(genericToolResults(webResult.surface)[0].status).assertEqual('needs_user');
      expect(webResult.raw.indexOf('https://mail.google.com/mail/u/0/#inbox')).assertLarger(-1);
    });

    it('uses Composio auth state for Gmail fixed tools when no Composio config exists', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'gmail.mail.search',
          '帮我看 Gmail 重要邮件',
          'surface_gmail_composio_missing',
          'model_tool_request',
          noop
        );

        expect(result.ok).assertTrue();
        expect(result.raw.indexOf('Composio 未配置')).assertLarger(-1);
        expect(result.raw.indexOf('gmail.mail.search')).assertLarger(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('falls back to existing device Gmail OAuth when Composio is unavailable', 0, async () => {
      const store = new MemoryCredentialStore();
      await store.put(GMAIL_ACCESS_TOKEN_REF, 'gmail-access-token');
      configureGmailCredentialStoreForTests(store);
      configureGmailMcpClientForTests(new SuccessfulGmailMcpClient());
      try {
        configureComposioConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'gmail.mail.search',
          '查看gmail里最新的重要邮件',
          'surface_gmail_oauth_fallback',
          'model_tool_request',
          noop
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered[0].status).assertEqual('success');
        expect(rendered[0].sourceTag).assertEqual('Gmail OAuth');
        expect(rendered[0].title).assertEqual('Gmail message');
      } finally {
        configureGmailMcpClientForTests(null);
        configureGmailCredentialStoreForTests(null);
        configureComposioConfigFromRawJson('{}');
      }
    });

    it('uses the same Gmail OAuth fallback when saving a reply draft', 0, async () => {
      const store = new MemoryCredentialStore();
      await store.put(GMAIL_ACCESS_TOKEN_REF, 'gmail-access-token');
      configureGmailCredentialStoreForTests(store);
      configureGmailMcpClientForTests(new SuccessfulGmailMcpClient());
      try {
        configureComposioConfigFromRawJson('{}');
        const command: MailReplyCommand = {
          requestKey: 'gmail-thread-1',
          provider: 'gmail',
          accountLabel: 'Gmail',
          threadId: 'thread-1',
          messageId: 'message-1',
          internetMessageId: '',
          to: ['author@example.com'],
          subject: 'Re: ECCV',
          body: 'Thanks for the update.',
          replyMode: 'reply',
          contextSummary: 'ECCV decision update'
        };

        const result = await saveConfiguredMailDraft(command);
        expect(result.status).assertEqual('success');
        expect(result.operation).assertEqual('draft');
      } finally {
        configureGmailMcpClientForTests(null);
        configureGmailCredentialStoreForTests(null);
        configureComposioConfigFromRawJson('{}');
      }
    });

    it('keeps Gmail thread-read args visible on the fixed Composio path', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'gmail.thread.read',
          '打开这封 Gmail 线程',
          'surface_gmail_thread_read_missing',
          'model_tool_request',
          noop,
          null,
          looseObject('{"threadId":"thread-123"}')
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered[0].toolName).assertEqual('gmail.thread.read');
        expect(rendered[0].status).assertEqual('needs_auth');
        expect(JSON.stringify(rendered[0].rows).indexOf('thread-123')).assertLarger(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('keeps Gmail draft-create args visible on the fixed Composio path', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'gmail.draft.create',
          '帮我写 Gmail 草稿',
          'surface_gmail_draft_create_missing',
          'model_tool_request',
          noop,
          null,
          looseObject('{"to":["alice@example.com"],"subject":"AIPhoneDemo","body":"Got it.","threadId":"thread-234","replyMode":"reply"}')
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered[0].toolName).assertEqual('gmail.draft.create');
        expect(rendered[0].status).assertEqual('needs_auth');
        expect(JSON.stringify(rendered[0].rows).indexOf('alice@example.com')).assertLarger(-1);
        expect(JSON.stringify(rendered[0].rows).indexOf('thread-234')).assertLarger(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('keeps Gmail draft-apply args visible on the fixed Composio path', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'gmail.draft.apply',
          '确认应用刚才的 Gmail 草稿',
          'surface_gmail_draft_apply_missing',
          'model_tool_request',
          noop,
          null,
          looseObject('{"to":["alice@example.com"],"subject":"AIPhoneDemo","body":"Please send later.","threadId":"thread-345","replyMode":"reply"}')
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered[0].toolName).assertEqual('gmail.draft.apply');
        expect(rendered[0].status).assertEqual('needs_auth');
        expect(JSON.stringify(rendered[0].rows).indexOf('thread-345')).assertLarger(-1);
        expect(JSON.stringify(rendered[0].rows).indexOf('Please send later.')).assertLarger(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('blocks Gmail draft-create when fixed body args are missing', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'gmail.draft.create',
          '帮我用 Gmail 写一封邮件给 alice@example.com 说我收到了',
          'surface_gmail_draft_create_missing_body',
          'model_tool_request',
          noop,
          null,
          looseObject('{"to":["alice@example.com"],"subject":"AIPhoneDemo"}')
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered[0].toolName).assertEqual('gmail.draft.create');
        expect(rendered[0].status).assertEqual('error');
        expect(rendered[0].summary.indexOf('body')).assertLarger(-1);
        expect(JSON.stringify(rendered[0].rows).indexOf('alice@example.com')).assertLarger(-1);
        expect(result.raw.indexOf('Composio 未配置')).assertEqual(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('blocks Gmail draft-create when fixed to args are missing even if body is present', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'gmail.draft.create',
          '帮我用 Gmail 写一封邮件给 alice@example.com 说我收到了',
          'surface_gmail_draft_create_missing_to',
          'model_tool_request',
          noop,
          null,
          looseObject('{"body":"Got it."}')
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered[0].toolName).assertEqual('gmail.draft.create');
        expect(rendered[0].status).assertEqual('error');
        expect(rendered[0].summary.indexOf('to')).assertLarger(-1);
        expect(rendered[0].summary.indexOf('Composio 未配置')).assertEqual(-1);
        expect(JSON.stringify(rendered[0].rows).indexOf('gmail.draft.create')).assertLarger(-1);
        expect(result.raw.indexOf('Composio 未配置')).assertEqual(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('blocks Gmail draft-apply when fixed body args are missing', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'gmail.draft.apply',
          '确认应用刚才的 Gmail 草稿',
          'surface_gmail_draft_apply_missing_body',
          'model_tool_request',
          noop,
          null,
          looseObject('{"threadId":"thread-345"}')
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered[0].toolName).assertEqual('gmail.draft.apply');
        expect(rendered[0].status).assertEqual('error');
        expect(rendered[0].summary.indexOf('body')).assertLarger(-1);
        expect(JSON.stringify(rendered[0].rows).indexOf('thread-345')).assertLarger(-1);
        expect(result.raw.indexOf('Composio 未配置')).assertEqual(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('blocks Gmail draft-apply when reply context is missing even if body is present', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'gmail.draft.apply',
          '确认应用刚才的 Gmail 草稿',
          'surface_gmail_draft_apply_missing_reply_context',
          'model_tool_request',
          noop,
          null,
          looseObject('{"threadId":"thread-345","to":["alice@example.com"],"subject":"AIPhoneDemo","body":"Please send later."}')
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered[0].toolName).assertEqual('gmail.draft.apply');
        expect(rendered[0].status).assertEqual('error');
        expect(rendered[0].summary.indexOf('replyMode')).assertLarger(-1);
        expect(rendered[0].summary.indexOf('Composio 未配置')).assertEqual(-1);
        expect(JSON.stringify(rendered[0].rows).indexOf('thread-345')).assertLarger(-1);
        expect(result.raw.indexOf('Composio 未配置')).assertEqual(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('uses Composio auth state for X public post search when no Composio config exists', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'x.post.search',
          '帮我查看 X 上 openai 最近的公开 post',
          'surface_x_composio_missing',
          'model_tool_request',
          noop
        );

        expect(result.ok).assertTrue();
        expect(result.raw.indexOf('Composio 未配置')).assertLarger(-1);
        expect(result.raw.indexOf('SocialHub')).assertEqual(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('keeps Calendar create args visible on the fixed Composio path', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'calendar.event.create',
          '帮我创建一个日程',
          'surface_calendar_create_missing',
          'model_tool_request',
          noop,
          null,
          looseObject('{"title":"AIPhoneDemo sync","start":"2026-07-30T15:00:00+08:00","end":"2026-07-30T15:30:00+08:00","timezone":"Asia/Shanghai"}')
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered[0].toolName).assertEqual('calendar.event.create');
        expect(rendered[0].status).assertEqual('needs_auth');
        expect(JSON.stringify(rendered[0].rows).indexOf('AIPhoneDemo sync')).assertLarger(-1);
        expect(JSON.stringify(rendered[0].rows).indexOf('2026-07-30T15:00:00')).assertLarger(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('keeps Calendar update args visible on the fixed Composio path', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'calendar.event.update',
          '帮我更新这个日程',
          'surface_calendar_update_missing',
          'model_tool_request',
          noop,
          null,
          looseObject('{"eventId":"evt-456","title":"AIPhoneDemo moved","start":"2026-07-30T16:00:00+08:00","end":"2026-07-30T16:30:00+08:00","timezone":"Asia/Shanghai"}')
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered[0].toolName).assertEqual('calendar.event.update');
        expect(rendered[0].status).assertEqual('needs_auth');
        expect(JSON.stringify(rendered[0].rows).indexOf('evt-456')).assertLarger(-1);
        expect(JSON.stringify(rendered[0].rows).indexOf('AIPhoneDemo moved')).assertLarger(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('blocks Calendar create when required fixed args are missing', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'calendar.event.create',
          '帮我在 2026年7月30日下午3点创建一个标题为 AIPhoneDemo 的30分钟日程',
          'surface_calendar_create_missing_required',
          'model_tool_request',
          noop,
          null,
          looseObject('{"end":"2026-07-30T15:30:00+08:00"}')
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered[0].toolName).assertEqual('calendar.event.create');
        expect(rendered[0].status).assertEqual('needs_input');
        expect(rendered[0].summary.indexOf('标题')).assertLarger(-1);
        expect(rendered[0].summary.indexOf('开始时间')).assertLarger(-1);
        expect(result.raw.indexOf('Composio 未配置')).assertEqual(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('blocks Calendar update when fixed eventId or update payload is missing', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'calendar.event.update',
          '把刚才的日程改到下午4点',
          'surface_calendar_update_missing_required',
          'model_tool_request',
          noop,
          null,
          looseObject('{"timezone":"Asia/Shanghai"}')
        );

        const rendered = genericToolResults(result.surface);
        expect(rendered[0].toolName).assertEqual('calendar.event.update');
        expect(rendered[0].status).assertEqual('needs_input');
        expect(rendered[0].summary.indexOf('先查询')).assertLarger(-1);
        expect(rendered[0].summary.indexOf('标题')).assertLarger(-1);
        expect(result.raw.indexOf('Composio 未配置')).assertEqual(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('renders YouTube API key errors without fake videos', 0, async () => {
      try {
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const args: YouTubeSearchArgsFixture = {
          query: 'qwen max 官方介绍视频'
        };
        const result: A2uiCallResult = await callToolGateway(
          defaultToolGatewayUrl(),
          'youtube.video.search',
          '帮我在 YouTube 搜索 qwen max 官方介绍视频',
          'surface_youtube_missing_key',
          'model_tool_request',
          noop,
          null,
          args
        );

        expect(result.ok).assertTrue();
        expect(genericToolResults(result.surface)[0].status).assertEqual('error');
        expect(result.raw.indexOf('YOUTUBE_API_KEY')).assertLarger(-1);
        expect(result.raw.indexOf('fake')).assertEqual(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('dispatches media video search locally without network when YouTube key is missing', 0, async () => {
      try {
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const args: MediaVideoSearchArgsFixture = {
          query: 'qwen max',
          sources: ['youtube']
        };
        const result: A2uiCallResult = await callToolGateway(
          defaultToolGatewayUrl(),
          'media.video.search',
          '帮我搜 qwen max 视频',
          'surface_media_youtube_missing_key',
          'model_tool_request',
          noop,
          null,
          args
        );

        const rendered = genericToolResults(result.surface);
        expect(result.ok).assertTrue();
        expect(rendered.length).assertLarger(0);
        expect(rendered[0].toolName).assertEqual('media.video.search');
        expect(rendered[0].status).assertEqual('error');
        expect(rendered[0].sourceTag).assertEqual('YouTube Data API');
        expect(rendered[0].rows.length).assertLarger(0);
        expect(rendered[0].summary.indexOf('YOUTUBE_API_KEY')).assertLarger(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('uses Composio auth state for YouTube account tools without fake playlists', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result: A2uiCallResult = await callToolGateway(
          defaultToolGatewayUrl(),
          'youtube.mine.playlists',
          '帮我看我的 YouTube 播放列表',
          'surface_youtube_auth',
          'model_tool_request',
          noop
        );

        expect(result.ok).assertTrue();
        expect(genericToolResults(result.surface)[0].toolName).assertEqual('youtube.mine.playlists');
        expect(genericToolResults(result.surface)[0].sourceTag).assertEqual('Composio YouTube');
        expect(genericToolResults(result.surface)[0].status).assertEqual('needs_auth');
        expect(result.raw.indexOf('Composio 未配置')).assertLarger(-1);
        expect(result.raw.indexOf('fake')).assertEqual(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
      }
    });

    it('keeps brand MCP adapters allowlisted', 0, () => {
      expect(isReadonlyBrandMcpTool('麦当劳', 'query-nearby-stores')).assertTrue();
      expect(isReadonlyBrandMcpTool('麦当劳', 'query-meals')).assertTrue();
      expect(isReadonlyBrandMcpTool('麦当劳', 'create-order')).assertFalse();
      expect(isReadonlyBrandMcpTool('麦当劳', 'auto-bind-coupons')).assertFalse();
      expect(isReadonlyBrandMcpTool('瑞幸', 'queryShopList')).assertTrue();
      expect(isReadonlyBrandMcpTool('瑞幸', 'searchProductForMcp')).assertTrue();
      expect(isReadonlyBrandMcpTool('瑞幸', 'previewOrder')).assertTrue();
      expect(isReadonlyBrandMcpTool('瑞幸', 'createOrder')).assertTrue();
      expect(isReadonlyBrandMcpTool('瑞幸', 'cancelOrder')).assertFalse();
    });

    it('maps McDonalds MCP store and menu query payloads to food records', 0, () => {
      const storesPayload: McDonaldsStoresPayloadFixture = {
        data: [
          {
            storeName: '麦当劳深圳科技园餐厅',
            address: '深圳市南山区科苑路',
            distance: '320米',
            businessStatus: true,
            businessStartTime: '07:00',
            businessEndTime: '22:00'
          }
        ]
      };
      const mealsPayload: McDonaldsMealsPayloadFixture = {
        data: {
          categories: [
            {
              name: '人气热卖',
              meals: [
                { code: '920215', tags: ['第二份半价'] }
              ]
            }
          ],
          meals: {
            '920215': {
              name: '培根安格斯厚牛堡大套餐',
              currentPrice: '55.5'
            }
          }
        }
      };
      const stores = foodRecordsFromMcDonaldsMcpTool('query-nearby-stores', storesPayload);
      const meals = foodRecordsFromMcDonaldsMcpTool('query-meals', mealsPayload);

      expect(stores[0].name).assertEqual('麦当劳深圳科技园餐厅');
      expect(stores[0].category.indexOf('营业中')).assertLarger(-1);
      expect(stores[0].distance).assertEqual('320米');
      expect((stores[0].sourceTags === undefined ? [] : stores[0].sourceTags)[0]).assertEqual('麦当劳');
      expect(meals[0].name).assertEqual('麦当劳 · 培根安格斯厚牛堡大套餐');
      expect(meals[0].category.indexOf('¥55.5')).assertLarger(-1);
      expect(meals[0].address.indexOf('第二份半价')).assertLarger(-1);
    });

    it('maps Luckin MCP shop and product query payloads to food records', 0, () => {
      const shopsPayload: LuckinShopsPayloadFixture = {
        data: [
          {
            deptName: '瑞幸咖啡 深圳科技园店',
            address: '深圳市南山区科技园',
            distance: 0.42,
            deptTags: ['可自提'],
            longitude: 114.0579,
            latitude: 22.5431
          }
        ]
      };
      const productsPayload: LuckinProductsPayloadFixture = {
        data: [
          {
            productName: '生椰拿铁',
            price: 19,
            skuCode: 'SKU001',
            pictureUrl: 'https://img.luckincoffeecdn.com/example/latte.png',
            productAttrs: [
              { attributeName: '温度', productSubAttrs: [{ attributeName: '冰', selected: true }, { attributeName: '热', selected: false }] }
            ],
            tags: ['人气']
          }
        ]
      };
      const shops = foodRecordsFromLuckinMcpTool('queryShopList', shopsPayload);
      const products = foodRecordsFromLuckinMcpTool('searchProductForMcp', productsPayload);

      expect(shops[0].name).assertEqual('瑞幸咖啡 深圳科技园店');
      expect(shops[0].category.indexOf('可自提')).assertLarger(-1);
      expect(shops[0].distance).assertEqual('420米');
      expect(shops[0].location).assertEqual('114.0579,22.5431');
      expect((shops[0].sourceTags === undefined ? [] : shops[0].sourceTags)[0]).assertEqual('瑞幸');
      expect(products[0].name).assertEqual('瑞幸 · 生椰拿铁');
      expect(products[0].category.indexOf('SKU001')).assertLarger(-1);
      expect(products[0].address.indexOf('温度:冰')).assertLarger(-1);
    });

    it('builds system map food destination search', 0, () => {
      expect(foodMapsLatLng('116.397470,39.908823')).assertEqual('39.908823,116.397470');
      expect(buildSystemFoodNavigationUri('116.397470,39.908823', '')).assertEqual('petalmaps://poidetail?center=39.908823,116.397470&z=16&marker=39.908823,116.397470&name=%E7%9B%AE%E7%9A%84%E5%9C%B0&utm_source=com.example.aiphonedemo');
      expect(buildSystemFoodNavigationUri('116.397470,39.908823', '116.398470,39.909823', '喜茶(深圳坂田华创里店)')).assertEqual('petalmaps://poidetail?center=39.908823,116.397470&z=16&marker=39.908823,116.397470&name=%E5%96%9C%E8%8C%B6%28%E6%B7%B1%E5%9C%B3%E5%9D%82%E7%94%B0%E5%8D%8E%E5%88%9B%E9%87%8C%E5%BA%97%29&utm_source=com.example.aiphonedemo');
    });

    it('sorts unified travel options by departure time', 0, () => {
      const rows: A2uiTravelOptionData[] = [
        {
          id: 'flight-empty',
          source: 'flight',
          sourceTag: '飞机 · 飞常准',
          title: '',
          from: 'BJS',
          to: 'SHA',
          depart: '',
          arrive: '',
          duration: '',
          price: '',
          availability: '',
          status: '计划',
          detail: '缺少时间'
        },
        {
          id: 'train-early',
          source: 'train',
          sourceTag: '高铁 · 12306',
          title: 'G5',
          from: '北京南',
          to: '上海虹桥',
          depart: '06:30',
          arrive: '12:00',
          duration: '5小时30分',
          price: '',
          availability: '二等座有票',
          status: '可查',
          detail: '真实高铁'
        },
        {
          id: 'train-fast',
          source: 'train',
          sourceTag: '高铁 · 12306',
          title: 'G1',
          from: '北京南',
          to: '上海虹桥',
          depart: '09:00',
          arrive: '13:28',
          duration: '4小时28分',
          price: '',
          availability: '二等座有票',
          status: '可查',
          detail: '真实高铁'
        },
        {
          id: 'flight-priced',
          source: 'flight',
          sourceTag: '飞机 · 飞常准',
          title: 'MU5101',
          from: 'BJS',
          to: 'SHA',
          depart: '07:00',
          arrive: '09:15',
          duration: '2小时15分',
          price: '¥680',
          availability: '',
          status: '计划',
          detail: '真实航班'
        }
      ];

      const sorted = sortTravelOptionsByDeparture(rows);
      expect(sorted[0].id).assertEqual('train-early');
      expect(sorted[1].id).assertEqual('flight-priced');
      expect(sorted[3].id).assertEqual('flight-empty');
    });

    it('prefers real flight airport names over provider city codes', 0, () => {
      const record = flightRecordForA2ui({
        FlightNo: 'ZH9951',
        FlightCompany: '深圳航空',
        FlightDepcode: 'SZX',
        FlightDepAirport: '深圳宝安国际机场',
        FlightArrcode: 'SHA',
        FlightArrAirport: '上海虹桥机场',
        FlightDeptimePlanDate: '2026-06-24 18:40',
        FlightArrtimePlanDate: '2026-06-24 20:55',
        FlightState: '计划'
      });

      expect(record.dep).assertEqual('深圳宝安国际机场');
      expect(record.arr).assertEqual('上海虹桥机场');
    });

    it('maps Meituan union delivery coupon results to food records', 0, () => {
      const record = foodRecordFromMeituanUnion({
        brandInfo: {
          brandName: '茶百道',
          brandLogoUrl: 'https://example.test/logo.png'
        },
        couponPackDetail: {
          name: '双杯奶茶套餐兑换券',
          sellPrice: '19.90',
          saleVolume: '10000+'
        },
        deliverablePoiInfo: {
          poiName: '茶百道 深圳科技园店',
          deliveryDistance: '1.2',
          distributionCost: '3.0',
          deliveryDuration: '30',
          lastDeliveryFee: '20'
        }
      });

      expect(record.name).assertEqual('茶百道 深圳科技园店');
      expect(record.category.indexOf('双杯奶茶套餐兑换券')).assertLarger(-1);
      expect(record.address.indexOf('配送费3.0元')).assertLarger(-1);
      expect(record.distance).assertEqual('1.2千米');
      const tags = record.sourceTags === undefined ? [] : record.sourceTags;
      expect(tags[0]).assertEqual('美团');
    });

    it('maps Taobao flash store promotion results to food records', 0, () => {
      const record = foodRecordFromTaobaoFlashStore({
        title: '肯德基 科技园店',
        category_1_name: '全球美食',
        delivery_distance: 820,
        delivery_time: 34,
        delivery_price: '4.0',
        service_rating: '4.6',
        items: [
          {
            title: '香辣鸡腿堡套餐',
            price: '29.9'
          }
        ]
      });

      expect(record.name).assertEqual('肯德基 科技园店');
      expect(record.category.indexOf('香辣鸡腿堡套餐')).assertLarger(-1);
      expect(record.address.indexOf('评分4.6')).assertLarger(-1);
      expect(record.distance).assertEqual('820米');
      const tags = record.sourceTags === undefined ? [] : record.sourceTags;
      expect(tags[0]).assertEqual('淘宝闪购');
    });

    it('maps Tencent map nearby POI results to food records', 0, () => {
      const record = foodRecordFromTencentMapPlace({
        title: '瑞幸咖啡 深圳科技园店',
        category: '美食:咖啡厅',
        address: '深圳市南山区科技园',
        _distance: 230,
        location: {
          lat: 22.5431,
          lng: 114.0579
        }
      });

      expect(record.name).assertEqual('瑞幸咖啡 深圳科技园店');
      expect(record.category).assertEqual('美食:咖啡厅');
      expect(record.address).assertEqual('深圳市南山区科技园');
      expect(record.distance).assertEqual('230米');
      expect(record.location).assertEqual('114.0579,22.5431');
      const tags = record.sourceTags === undefined ? [] : record.sourceTags;
      expect(tags[0]).assertEqual('腾讯地图');
    });

    it('maps Baidu place nearby POI results to food records', 0, () => {
      const record = foodRecordFromBaiduPlace({
        name: '星巴克 深圳科技园店',
        address: '深圳市南山区科苑路',
        location: {
          lat: 22.544,
          lng: 114.058
        },
        detail_info: {
          tag: '美食;咖啡厅',
          distance: 410,
          overall_rating: '4.5'
        }
      });

      expect(record.name).assertEqual('星巴克 深圳科技园店');
      expect(record.category.indexOf('美食;咖啡厅')).assertLarger(-1);
      expect(record.address.indexOf('评分4.5')).assertLarger(-1);
      expect(record.distance).assertEqual('410米');
      expect(record.location).assertEqual('114.058,22.544');
      const tags = record.sourceTags === undefined ? [] : record.sourceTags;
      expect(tags[0]).assertEqual('百度地图');
    });

    it('parses food distance text for local range filters', 0, () => {
      expect(foodDistanceMeters('832米')).assertEqual(832);
      expect(foodDistanceMeters('1.2千米')).assertEqual(1200);
      expect(foodDistanceMeters('0.85公里')).assertEqual(850);
    });

    it('deduplicates food results and merges source tags without fake rows', 0, () => {
      const amap: A2uiFoodData = {
        name: '喜茶 深圳科技园店',
        category: '餐饮服务',
        address: '南山科技园',
        distance: '120米',
        sourceTags: ['高德']
      };
      const meituan: A2uiFoodData = {
        name: '喜茶深圳科技园店',
        category: '芝芝莓莓',
        address: '配送费3元 · 预计28分钟',
        distance: '0.1千米',
        sourceTags: ['美团']
      };
      const google: A2uiFoodData = {
        name: '喜茶 深圳科技园店',
        category: 'Google Places',
        address: '南山科技园',
        distance: '',
        location: '113.943,22.541',
        sourceTags: ['Google Maps']
      };

      const merged = aggregateFoodProviderResults([
        { provider: '高德', foods: [amap], error: '' },
        { provider: '美团', foods: [meituan], error: '' },
        { provider: '腾讯地图', foods: [{ name: '喜茶-深圳科技园店', category: '美食', address: '科技园', distance: '100米', sourceTags: ['腾讯地图'] }], error: '' },
        { provider: 'Google Maps', foods: [google], error: '' },
        { provider: '淘宝闪购', foods: [], error: '未配置 TAOBAO_APP_KEY' }
      ]);

      expect(merged.foods.length).assertEqual(1);
      const tags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;
      expect(tags.length).assertEqual(4);
      expect(tags[0]).assertEqual('高德');
      expect(tags[1]).assertEqual('美团');
      expect(tags[2]).assertEqual('腾讯地图');
      expect(tags[3]).assertEqual('Google Maps');
      expect(providerIssueRows(merged.issues)[0].label).assertEqual('淘宝闪购');
    });

    it('builds food provider progress rows for waiting, completed, and errored sources', 0, () => {
      const rice: A2uiFoodData = {
        name: '米粉店',
        category: '餐饮',
        address: '科技园',
        distance: '100米',
        sourceTags: ['高德']
      };
      const providerNames: string[] = ['高德', '腾讯地图', '美团'];
      const completedResults: FoodProviderResult[] = [
        { provider: '高德', foods: [rice], error: '' },
        { provider: '美团', foods: [], error: '未配置 MEITUAN_UNION_APP_KEY。' }
      ];
      const rows: A2uiLabelValueData[] = foodProviderProgressRows(providerNames, completedResults);

      expect(rows.length).assertEqual(3);
      expect(rows[0].label).assertEqual('高德');
      expect(rows[0].value).assertEqual('已返回 1 条');
      expect(rows[1].label).assertEqual('腾讯地图');
      expect(rows[1].value).assertEqual('等待中');
      expect(rows[2].label).assertEqual('美团');
      expect(rows[2].value.indexOf('未配置')).assertLarger(-1);
    });

    it('keeps food partial component signatures stable when only provider data changes', 0, () => {
      const firstRows: A2uiLabelValueData[] = [
        { label: '高德', value: '等待中' }
      ];
      const secondRows: A2uiLabelValueData[] = [
        { label: '高德', value: '已返回 1 条' }
      ];
      const noodles: A2uiFoodData = {
        name: '牛肉面',
        category: '餐饮',
        address: '深圳北站',
        distance: '300米',
        sourceTags: ['高德']
      };
      const first: A2uiPartialUpdateResult = planA2uiPartialUpdate(null, foodA2uiRenderState(
        'surface_food',
        '外卖聚合搜索',
        '真实 provider 返回',
        '已返回 0/5 个餐饮来源',
        [],
        firstRows,
        'calling_tool'
      ));
      const second: A2uiPartialUpdateResult = planA2uiPartialUpdate(first.cache, foodA2uiRenderState(
        'surface_food',
        '外卖聚合搜索',
        '真实 provider 返回',
        '已返回 1/5 个餐饮来源',
        [noodles],
        secondRows,
        'calling_tool'
      ));

      expect(first.componentsUpdated).assertTrue();
      expect(second.componentsUpdated).assertFalse();
      expect(second.updatedDataPaths.indexOf('/foods')).assertLarger(-1);
      expect(second.updatedDataPaths.indexOf('/rows')).assertLarger(-1);
    });

    it('merges the same store when map providers include different city prefixes', 0, () => {
      const merged = aggregateFoodProviderResults([
        {
          provider: '高德',
          foods: [{
            name: '茶百道(北京东城故宫东华门店)',
            category: '餐饮服务;冷饮店;冷饮店',
            address: '北京城区东华门大街83号2幢',
            distance: '832米',
            sourceTags: ['高德']
          }],
          error: ''
        },
        {
          provider: '腾讯地图',
          foods: [{
            name: '茶百道(东城故宫东华门店)',
            category: '美食:冷饮店',
            address: '北京市东城区东华门大街83号2幢',
            distance: '835.32米',
            sourceTags: ['腾讯地图']
          }],
          error: ''
        }
      ]);

      expect(merged.foods.length).assertEqual(1);
      expect(merged.foods[0].distance).assertEqual('832米');
      const tags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;
      expect(tags.length).assertEqual(2);
      expect(tags[0]).assertEqual('高德');
      expect(tags[1]).assertEqual('腾讯地图');
    });

    it('merges the same store when one map address includes street direction words', 0, () => {
      const merged = aggregateFoodProviderResults([
        {
          provider: '高德',
          foods: [{
            name: '蜜雪冰城(东华门大街店)',
            category: '餐饮服务;冷饮店;冷饮店',
            address: '东华门大街56号',
            distance: '863米',
            sourceTags: ['高德']
          }],
          error: ''
        },
        {
          provider: '腾讯地图',
          foods: [{
            name: '蜜雪冰城(故宫东门店)',
            category: '美食:冷饮店',
            address: '北京市东城区东华门街道东华门大街路南56号',
            distance: '860.31米',
            sourceTags: ['腾讯地图']
          }],
          error: ''
        }
      ]);

      expect(merged.foods.length).assertEqual(1);
      expect(merged.foods[0].distance).assertEqual('860.31米');
      const tags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;
      expect(tags.indexOf('高德')).assertLarger(-1);
      expect(tags.indexOf('腾讯地图')).assertLarger(-1);
    });

    it('orders merged-source food results first and then by distance', 0, () => {
      const merged = aggregateFoodProviderResults([
        {
          provider: '高德',
          foods: [
            {
              name: '近距离单源店',
              category: '餐饮服务',
              address: '近距离地址',
              distance: '50米',
              sourceTags: ['高德']
            },
            {
              name: '远距离多源店',
              category: '餐饮服务',
              address: '远距离地址',
              distance: '500米',
              sourceTags: ['高德']
            },
            {
              name: '近距离多源店',
              category: '餐饮服务',
              address: '近多源地址',
              distance: '200米',
              sourceTags: ['高德']
            }
          ],
          error: ''
        },
        {
          provider: '百度地图',
          foods: [
            {
              name: '远距离多源店',
              category: '美食',
              address: '远距离地址',
              distance: '480米',
              sourceTags: ['百度地图']
            },
            {
              name: '近距离多源店',
              category: '美食',
              address: '近多源地址',
              distance: '210米',
              sourceTags: ['百度地图']
            }
          ],
          error: ''
        }
      ]);

      expect(merged.foods[0].name).assertEqual('近距离多源店');
      expect(merged.foods[1].name).assertEqual('远距离多源店');
      expect(merged.foods[2].name).assertEqual('近距离单源店');
    });

    it('prioritizes preferred Luckin food results without fabricating rows', 0, () => {
      const merged = aggregateFoodProviderResults([
        {
          provider: '高德',
          foods: [{
            name: '普通咖啡店',
            category: '咖啡',
            address: 'A',
            distance: '100米',
            sourceTags: ['高德']
          }],
          error: ''
        },
        {
          provider: '瑞幸',
          foods: [{
            name: '瑞幸咖啡 深圳店',
            category: '瑞幸门店',
            address: 'B',
            distance: '900米',
            sourceTags: ['瑞幸']
          }],
          error: ''
        }
      ], {
        brandPreference: '瑞幸',
        sweetness: '半糖'
      });

      expect(merged.foods.length).assertEqual(2);
      expect(merged.foods[0].name.indexOf('瑞幸')).assertLarger(-1);
      expect(merged.foods[0].sourceTags === undefined ? '' : merged.foods[0].sourceTags![0]).assertEqual('瑞幸');
    });

    it('filters to Luckin rows for strict Luckin-only preference', 0, () => {
      const merged = aggregateFoodProviderResults([
        {
          provider: '高德',
          foods: [{
            name: '普通咖啡店',
            category: '咖啡',
            address: 'A',
            distance: '100米',
            sourceTags: ['高德']
          }],
          error: ''
        },
        {
          provider: '瑞幸',
          foods: [{
            name: '瑞幸咖啡 深圳店',
            category: '瑞幸门店',
            address: 'B',
            distance: '900米',
            sourceTags: ['瑞幸']
          }],
          error: ''
        }
      ], {
        brandPreference: '瑞幸',
        brandStrict: true
      });

      expect(merged.foods.length).assertEqual(1);
      expect(merged.foods[0].name.indexOf('瑞幸')).assertLarger(-1);
    });

    it('keeps later map provider tags visible when Amap fills the limit first', 0, () => {
      const amapFoods: A2uiFoodData[] = [];
      for (let index = 0; index < 8; index++) {
        amapFoods.push({
          name: index === 0 ? '茶百道(北京东城故宫东华门店)' : '高德餐饮 ' + index.toString(),
          category: '餐饮服务',
          address: index === 0 ? '北京城区东华门大街83号2幢' : '高德地址 ' + index.toString(),
          distance: (100 + index).toString() + '米',
          sourceTags: ['高德']
        });
      }

      const merged = aggregateFoodProviderResults([
        { provider: '高德', foods: amapFoods, error: '' },
        {
          provider: '腾讯地图',
          foods: [{
            name: '茶百道(东城故宫东华门店)',
            category: '美食:冷饮店',
            address: '北京市东城区东华门大街83号2幢',
            distance: '110米',
            sourceTags: ['腾讯地图']
          }],
          error: ''
        },
        {
          provider: '百度地图',
          foods: [{
            name: '茶百道(东城故宫东华门店)',
            category: '美食;冷饮店',
            address: '北京市东城区东华门大街83号2幢',
            distance: '120米',
            sourceTags: ['百度地图']
          }],
          error: ''
        }
      ]);

      expect(merged.foods.length).assertEqual(8);
      const firstTags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;
      expect(firstTags.indexOf('高德')).assertLarger(-1);
      expect(firstTags.indexOf('腾讯地图')).assertLarger(-1);
      expect(firstTags.indexOf('百度地图')).assertLarger(-1);
    });

    it('keeps one Google Maps row visible when earlier providers fill the food limit', 0, () => {
      const amapFoods: A2uiFoodData[] = [];
      for (let index = 0; index < 30; index++) {
        amapFoods.push({
          name: '高德餐饮 ' + index.toString(),
          category: '餐饮服务',
          address: '高德地址 ' + index.toString(),
          distance: (100 + index).toString() + '米',
          sourceTags: ['高德']
        });
      }
      const merged = aggregateFoodProviderResults([
        { provider: '高德', foods: amapFoods, error: '' },
        { provider: 'Google Maps', foods: [{ name: 'NCafe', category: 'Google Places', address: '坂田', distance: '', location: '114.1,22.6', sourceTags: ['Google Maps'] }], error: '' }
      ]);
      let hasGoogle = false;
      for (let index = 0; index < merged.foods.length; index++) {
        const tags = merged.foods[index].sourceTags;
        if (tags !== undefined) {
          hasGoogle = hasGoogle || tags.indexOf('Google Maps') >= 0;
        }
      }

      expect(merged.foods.length).assertEqual(24);
      expect(hasGoogle).assertTrue();
    });

    it('keeps more than the default visible food rows for client show more', 0, () => {
      const amapFoods: A2uiFoodData[] = [];
      const tencentFoods: A2uiFoodData[] = [];
      for (let index = 0; index < 10; index++) {
        amapFoods.push({
          name: '高德餐饮 ' + index.toString(),
          category: '餐饮服务',
          address: '高德地址 ' + index.toString(),
          distance: (100 + index).toString() + '米',
          sourceTags: ['高德']
        });
        tencentFoods.push({
          name: '腾讯餐饮 ' + index.toString(),
          category: '美食',
          address: '腾讯地址 ' + index.toString(),
          distance: (300 + index).toString() + '米',
          sourceTags: ['腾讯地图']
        });
      }

      const merged = aggregateFoodProviderResults([
        { provider: '高德', foods: amapFoods, error: '' },
        { provider: '腾讯地图', foods: tencentFoods, error: '' }
      ]);

      expect(merged.foods.length).assertLarger(8);
    });

    it('keeps legacy food records without source tags renderable', 0, () => {
      const legacy: A2uiFoodData = {
        name: '老乡鸡 科技园店',
        category: '中式快餐',
        address: '科技园',
        distance: '300米'
      };
      const merged = aggregateFoodProviderResults([
        { provider: '高德', foods: [legacy], error: '' }
      ]);
      const tags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;

      expect(merged.foods.length).assertEqual(1);
      expect(tags[0]).assertEqual('高德');
    });

    it('emits food partial snapshots as provider promises complete', 0, async () => {
      const snapshots: string[] = [];
      const fastResult: FoodProviderResult = {
        provider: '快来源',
        foods: [{
          name: '快来源餐厅',
          category: '餐饮',
          address: '快来源地址',
          distance: '100米',
          sourceTags: ['快来源']
        }],
        error: ''
      };
      const fast: Promise<FoodProviderResult> = Promise.resolve(fastResult);
      const slow: Promise<FoodProviderResult> = new Promise<FoodProviderResult>((resolve: (value: FoodProviderResult) => void) => {
        setTimeout(() => {
          const slowResult: FoodProviderResult = {
            provider: '慢来源',
            foods: [{
              name: '慢来源餐厅',
              category: '餐饮',
              address: '慢来源地址',
              distance: '200米',
              sourceTags: ['慢来源']
            }],
            error: ''
          };
          resolve(slowResult);
        }, 10);
      });
      const tasks: Promise<FoodProviderResult>[] = [slow, fast];

      const finalResult = await streamFoodProviderResultsWithPartials(tasks, [], (snapshot: FoodProviderPartialSnapshot) => {
        snapshots.push(snapshot.provider + ':' + snapshot.foods.length.toString());
      });

      expect(snapshots.length).assertEqual(2);
      expect(snapshots[0].indexOf('快来源')).assertEqual(0);
      expect(snapshots[1].indexOf('慢来源')).assertEqual(0);
      expect(finalResult.aggregation.foods.length).assertEqual(2);
      expect(finalResult.results.length).assertEqual(2);
    });

    it('spaces food partial snapshots by configured delay after each provider result', 0, async () => {
      const emittedAt: number[] = [];
      const firstResult: FoodProviderResult = {
        provider: '一号来源',
        foods: [{ name: '一号店', category: '餐饮', address: '一号地址', distance: '100米', sourceTags: ['一号来源'] }],
        error: ''
      };
      const secondResult: FoodProviderResult = {
        provider: '二号来源',
        foods: [{ name: '二号店', category: '餐饮', address: '二号地址', distance: '200米', sourceTags: ['二号来源'] }],
        error: ''
      };
      const thirdResult: FoodProviderResult = {
        provider: '三号来源',
        foods: [{ name: '三号店', category: '餐饮', address: '三号地址', distance: '300米', sourceTags: ['三号来源'] }],
        error: ''
      };
      const tasks: Promise<FoodProviderResult>[] = [
        Promise.resolve(firstResult),
        Promise.resolve(secondResult),
        Promise.resolve(thirdResult)
      ];

      await streamFoodProviderResultsWithPartials(tasks, [], (_snapshot: FoodProviderPartialSnapshot) => {
        emittedAt.push(Date.now());
      }, 20);

      expect(emittedAt.length).assertEqual(3);
      expect(emittedAt[1] - emittedAt[0]).assertLarger(10);
      expect(emittedAt[2] - emittedAt[1]).assertLarger(10);
    });

    it('renders payment amount completion before provider checkout', 0, async () => {
      try {
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const args: PaymentTestArgs = { provider: 'paypal', originalQuery: '用 PayPal 给罗一格转账' };
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'payment.send',
          '用 PayPal 给罗一格转账',
          'surface_payment_amount',
          'model_tool_request',
          noop,
          null,
          args
        );
        const rendered = genericToolResults(result.surface)[0];

        expect(rendered.toolName).assertEqual('payment.send');
        expect(rendered.title).assertEqual('补充金额');
        expect(result.raw.indexOf('payment.amount.select')).assertLarger(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('uses locally saved payment accounts in payment.send', 0, async () => {
      try {
        configureLocalProviderConfigFromRawJson('{}');
        configureLocalPaymentAccountBookJson(JSON.stringify([{
          id: 'dana_saved',
          displayName: 'Dana Saved',
          aliases: ['Dana Saved', '小丹'],
          email: '',
          paypalEmail: 'dana@example.com',
          paypalMerchantId: '',
          stripeAccountId: '',
          stripePaymentLinkUrl: '',
          enabled: true
        }]));
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const args: PaymentTestArgs = { provider: 'paypal', originalQuery: '用 PayPal 给 Dana Saved 转账' };
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'payment.send',
          '用 PayPal 给 Dana Saved 转账',
          'surface_payment_saved_account',
          'model_tool_request',
          noop,
          null,
          args
        );
        const rendered = genericToolResults(result.surface)[0];

        expect(rendered.title).assertEqual('补充金额');
        expect(rendered.summary.indexOf('Dana Saved')).assertLarger(-1);
        expect(JSON.stringify(rendered.rows).indexOf('dana@example.com')).assertLarger(-1);
        expect(result.raw.indexOf('payment.amount.select')).assertLarger(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('renders payment confirmation without creating provider session first', 0, async () => {
      try {
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const query = '用 PayPal 给罗一格转 5 美元';
        const args: PaymentTestArgs = { provider: 'paypal', originalQuery: query };
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'payment.send',
          query,
          'surface_payment_confirm',
          'model_tool_request',
          noop,
          null,
          args
        );
        const rendered = genericToolResults(result.surface)[0];

        expect(rendered.title).assertEqual('确认支付');
        expect(rendered.summary.indexOf('罗一格')).assertLarger(-1);
        expect(result.raw.indexOf('payment.confirm')).assertLarger(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('turns Stripe Payment Link confirmation into app checkout action', 0, async () => {
      try {
        configureLocalProviderConfigFromRawJson('{}');
        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const args: PaymentTestArgs = { provider: 'stripe', recipient: 'External Cafe', phase: 'confirm' };
        const result = await callToolGateway(
          defaultToolGatewayUrl(),
          'payment.send',
          '打开 External Cafe 的 Stripe 付款页',
          'surface_payment_checkout',
          'payment.confirm',
          noop,
          null,
          args
        );
        const rendered = genericToolResults(result.surface)[0];

        expect(rendered.title).assertEqual('打开支付确认页');
        expect(JSON.stringify(rendered.rows).indexOf('https://buy.stripe.com/')).assertLarger(-1);
        expect(result.raw.indexOf('payment.checkout.open')).assertLarger(-1);
        expect(result.raw.indexOf('client')).assertLarger(-1);
      } finally {
        configureLocalProviderConfigFromRawJson('{}');
      }
    });
  });
}
