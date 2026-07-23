import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import {
  A2UI_VERSION,
  A2uiAction,
  A2uiCallResult,
  A2uiComponent,
  A2uiEnvelope,
  A2uiFlightData,
  A2uiFoodData,
  A2uiGenericToolResultData,
  A2uiLabelValueData,
  A2uiSummaryData,
  A2uiSurfaceState,
  A2uiTravelOptionData,
  A2uiTrainData,
  FlightStructuredData,
  FoodStructuredData,
  StripeReceivingAccountCardData,
  TrainStructuredData,
  TravelStructuredData,
  defaultA2uiCapabilities,
  emptyA2uiSurface
} from './A2uiTypes';
import { parseA2uiJsonl, parseA2uiJsonlChunk } from './A2uiParser';
import { A2uiSurfaceStore } from './A2uiSurfaceStore';
import { A2uiSurfaceThrottle } from './A2uiSurfaceThrottle';
import { aiLogError, aiLogInfo } from './AiphoneLogger';
import { connectCardA2ui, genericToolResultsA2ui, unsupportedTransportA2ui } from './DynamicToolA2ui';
import { AssetCredentialStore, CredentialStore, credentialRefFor } from './DynamicCredentialStore';
import {
  GMAIL_MCP_AUTH_SETUP_URL,
  GMAIL_MCP_SERVER_URL,
  GOOGLE_OAUTH_SETUP_URL,
  calendarAuthRequiredA2ui,
  gmailAuthRequiredA2ui,
  gmailDraftPreviewA2ui,
  gmailOpenWebA2ui,
  gmailSearchStructuredDataA2ui,
  gmailThreadResultsA2ui
} from './GmailToolA2ui';
import {
  gmailSearchStructuredDataFromResults,
  GmailSearchStructuredData,
  GmailThreadSummary
} from './GmailToolNormalizer';
import {
  mailDraftPreviewA2ui,
  mailResultsFromDynamicA2ui,
  mailSearchStructuredDataA2ui,
  mailThreadSummary,
  MailSearchStructuredData,
  MailThreadSummary
} from './MailToolA2ui';
import {
  MailDetail,
  MailDetailRequest,
  MailDraftArgs,
  MailProviderStatus,
  MailReplyCommand,
  MailReplyOperationResult,
  MailSearchArgs,
  MailThreadResult
} from './MailToolTypes';
import {
  GMAIL_ACCESS_TOKEN_REF,
  GMAIL_DEFAULT_REDIRECT_URI,
  GMAIL_MCP_RESOURCE,
  GOOGLE_CLOUD_OAUTH_SCOPES,
  GmailOAuthConfig,
  buildGmailOAuthAuthorizationUrl,
  createGmailOAuthPending,
  gmailMcpArgsForPrompt,
  gmailMcpToolNameForToolId,
  gmailPkceChallengeS256,
  isGmailAccessTokenFresh,
  loadGmailOAuthTokenSet,
  refreshGmailOAuthAccessToken,
  saveGmailOAuthPending,
  saveGmailOAuthTokenSet
} from './GmailOAuthClient';
import { buildInitializeRequest, buildToolsCallRequest, GenericMcpClient, McpToolCallResult } from './GenericMcpClient';
import { DataResult, DataSource } from '../../agent/message/DataResult';
import {
  errorDataResult,
  partialDataResult,
  successfulDataResult
} from '../../agent/message/DataResultFactory';
import { ActionCatalog } from '../../agent/action/ActionCatalog';
import {
  ActionArgsValidator,
  ActionValidationResult,
  ClientActionAuthorizer,
  SurfaceActionAuthorizer,
  ToolDefinitionLookup
} from '../../agent/action/ActionCatalogTypes';
import { hotelDetailDataResult, hotelSearchDataResult } from './HotelDataResult';
import { validateHotelActionArgs } from './HotelActions';
import { hotelDetailA2ui, hotelFailureA2ui, hotelSearchA2ui } from './HotelToolA2ui';
import {
  HotelDetailResult,
  HotelDetailParseResult,
  HotelSearchResult,
  HotelSearchParseResult,
  hotelDetailProviderArgs,
  hotelSearchProviderArgs,
  normalizeHotelDetailResult,
  normalizeHotelSearchResult,
  parseHotelDetailRequest,
  parseHotelSearchRequest
} from './HotelToolTypes';
import { callGmailApiTool, gmailMailDetailFromPayload, readGmailMailDetail } from './GmailApiClient';
import { callYouTubeVideoSearch, defaultYouTubeSearchOptions, YouTubeSearchOptions } from './YouTubeApiClient';
import { callMediaVideoSearch, mediaVideoQueryFromArgs } from './MediaVideoClient';
import { mediaVideoPlaybackUrl, mediaVideoStructuredDataA2ui } from './MediaVideoToolA2ui';
import {
  CalendarEventArgs,
  calendarDateFromPrompt,
  calendarEventRequiredFields,
  calendarMissingArgsResult,
  calendarProviderDateTime,
  calendarResultsFromComposioObservation,
  calendarTimeFromPrompt,
  normalizedCalendarArgsForPrompt
} from './CalendarApiClient';
import {
  callMapsPlaceDetailsProvider,
  callMapsPlaceSearch,
  callMapsPlaceSearchProvider,
  mapsFoodRecordFromResult,
  mapsPlaceProviderResultsForA2ui,
  mapsRouteResult,
  MapsPlaceProviderResult,
  MapsStructuredData
} from './MapsApiClient';
import { QqMailConfig, QqMailImapClient } from './QqMailImapClient';
import {
  socialHubCommunityA2ui,
  socialHubDraftA2ui,
  socialHubFeedA2ui,
  socialHubPublicationA2ui,
  socialHubStructuredDataA2ui,
  SocialHubStructuredData
} from './SocialHubA2ui';
import {
  createSocialHubPublicationPreview,
  parseComposioCommunityFeed,
  parseComposioSocialFeed,
  SocialHubClient,
  SocialHubFeedResult,
  SocialHubPublicationPreviewInput
} from './SocialHubClient';
import {
  SocialHubConnectionData,
  SocialHubDraftData,
  SocialHubItemData,
  SocialHubPlatform,
  SocialHubPublicationData
} from './SocialHubTypes';
import {
  callComposioDynamic,
  callComposioFixedDynamic,
  callComposioFixedRaw,
  composioDynamicResultFromObservation,
  composioPhoneNumberIdsFromObservation,
  ComposioRawExecution,
  isComposioConfigured,
  refreshComposioConnections
} from './ComposioDynamicBackend';
import { aggregateSearchA2ui } from './AggregateSearchA2ui';
import { callAggregateSearch } from './AggregateSearchClient';
import { AggregateSearchResult, AggregateSearchSourceStatus } from './AggregateSearchTypes';
import { discoverDynamicToolForPrompt, DynamicToolDiscoveryResult } from './DynamicToolDiscovery';
import { DynamicToolRegistry, isBuiltInToolId, isUnsafeMcpTool, selectBestRemoteTransport } from './DynamicToolRegistry';
import { sampleManifestForToolId } from './DynamicToolSamples';
import { dataAgentToolDefinitions, isCalendarToolId, isGmailToolId, isHotelToolId, isKnownDomainToolId, isLuckinToolId, isMailToolId, isMapsToolId, isMediaToolId, isPaymentToolId, isRideToolId, isYouTubeToolId, toolDefinitionForToolId } from './ToolDefinitionRegistry';
import { ToolBackendType, ToolDefinition } from './ToolDefinitionTypes';
import {
  PaymentAccount,
  PaymentMode,
  PaymentPolicy,
  PaymentFundingSource,
  PaymentProvider,
  PaymentRequestDraft,
  PaymentValidationResult,
  PaymentValidationStatus,
  defaultPaymentAccountBook,
  isStripePaymentLinkUrl,
  paymentIdempotencyKey,
  validatePaymentRequest
} from '../payment/PaymentCore';
import { paymentCancelledA2ui, paymentValidationA2ui } from '../payment/PaymentA2ui';
import {
  PayPalEnvironment,
  buildPayPalCaptureRequest,
  buildPayPalOrderRequest,
  buildPayPalTokenRequest,
  paypalApprovalUrlFromOrder
} from '../payment/PayPalPaymentClient';
import {
  buildStripeCheckoutSessionRequest,
  stripeCheckoutUrlFromResponse
} from '../payment/StripePaymentClient';
import { stripeReceivingAccountA2ui } from '../payment/StripeReceivingAccountA2ui';
import {
  blankStripeReceivingProfile,
  mapStripeReceivingStatus,
  StripeReceivingAccountStatus,
  StripeReceivingAccountStatusPayload,
  StripeReceivingProfile,
  validateStripeReceivingProfile
} from '../payment/StripeReceivingAccountCore';
import {
  createStripeConnectAccount,
  createStripeConnectOnboardingLink,
  fetchStripeConnectStatus,
  StripeConnectAccountResult,
  StripeConnectOnboardingLinkResult,
  StripeConnectStatusResult
} from '../payment/StripeConnectClient';
import {
  DynamicCredentialSpec,
  DynamicGenericToolResult,
  DynamicMcpTool,
  DynamicReadExecution,
  DynamicReadExecutor,
  DynamicRegistrationMetadata,
  DynamicStructuredData,
  DynamicToolManifest,
  DynamicToolRegistration,
  DynamicToolTransport,
  GenericStructuredData,
  dynamicReceiptFromProviderPayload
} from './DynamicToolTypes';
import {
  A2uiPartialDataPatch,
  A2uiPartialRenderState,
  A2uiPartialUpdateCache,
  A2uiPartialUpdateResult,
  planA2uiPartialUpdate
} from './A2uiPartialUpdatePlanner';

type A2uiSurfaceCallback = (surface: A2uiSurfaceState, raw: string) => void;

interface ToolGatewayRequestBody {
  toolId: string;
  prompt: string;
  surfaceId: string;
  actionId: string;
  args?: Object;
  stream: boolean;
  a2uiClientCapabilities: Object;
}

interface ToolGatewayHeaders {
  'Content-Type': string;
  'Accept': string;
}

interface HttpTextResponse {
  code: number;
  text: string;
  cookies: string;
  headers: string;
}

interface SlackComposioReplyArgs {
  channel: string;
  text: string;
  threadTs: string;
}

interface HttpRequestHeaders {
  'User-Agent'?: string;
  'Accept'?: string;
  'Accept-Encoding'?: string;
  'Referer'?: string;
  'Cookie'?: string;
  'Content-Type'?: string;
  'Authorization'?: string;
  'Idempotency-Key'?: string;
  'MCP-Protocol-Version'?: string;
  'Mcp-Session-Id'?: string;
  'X-VARIFLIGHT-KEY'?: string;
  'Content-MD5'?: string;
  'S-Ca-App'?: string;
  'S-Ca-Signature'?: string;
  'S-Ca-Timestamp'?: string;
  'S-Ca-Signature-Headers'?: string;
}

interface ToolRequestDebug {
  endpoint: string;
  body: ToolGatewayRequestBody;
}

interface LeftTicketData {
  result?: string[];
}

interface LeftTicketPayload {
  data?: LeftTicketData;
}

interface StationEntry {
  name: string;
  code: string;
}

interface StationCache {
  entries: StationEntry[];
  names: string[];
}

interface StationDefault {
  city: string;
  station: string;
}

interface LocalProviderConfig {
  toolGatewayApiKey: string;
  flightMcpKey: string;
  variflightApiUrl: string;
  hotelMcpKey: string;
  hotelMcpUrl: string;
  amapKey: string;
  amapDefaultLocation: string;
  amapRadius: string;
  tencentMapKey: string;
  tencentMapApiUrl: string;
  baiduMapAk: string;
  baiduMapApiUrl: string;
  meituanUnionAppKey: string;
  meituanUnionAppSecret: string;
  meituanUnionApiUrl: string;
  taobaoAppKey: string;
  taobaoAppSecret: string;
  taobaoFlashPid: string;
  taobaoApiUrl: string;
  mcdMcpToken: string;
  mcdMcpUrl: string;
  luckinMcpToken: string;
  luckinMcpUrl: string;
  didiMcpKey: string;
  didiMcpUrl: string;
  didiMcpSandbox: string;
  amapMcpKey: string;
  amapMcpUrl: string;
  rideMockEnabled: string;
  whatsappTestTo: string;
  googleMapsApiKey: string;
  googleOauthClientId: string;
  googleOauthClientSecret: string;
  googleOauthRedirectUri: string;
  gmailAuthUrl: string;
  gmailOauthClientId: string;
  gmailOauthClientSecret: string;
  gmailOauthRedirectUri: string;
  gmailMcpUserProject: string;
  youtubeApiKey: string;
  zhihuApiKey: string;
  qqMailAddress: string;
  qqMailAuthCode: string;
  qqMailImapHost: string;
  qqMailImapPort: string;
  qqMailDraftsMailbox: string;
  paypalClientId: string;
  paypalClientSecret: string;
  paypalEnvironment: string;
  paypalReturnUrl: string;
  paypalCancelUrl: string;
  paypalCheckoutGatewayUrl: string;
  stripeSecretKey: string;
  stripePublishableKey: string;
  stripeSuccessUrl: string;
  stripeCancelUrl: string;
  stripeCheckoutGatewayUrl: string;
  stripeConnectReturnUrl: string;
  stripeConnectRefreshUrl: string;
  stripeReceivingAgentJson: string;
  paymentAccountBookJson: string;
  paymentDefaultCurrency: string;
  paymentMode: string;
  paymentLiveAllowedStripeAccountIds: string;
  paymentLiveMaxAmountMinor: string;
}

interface LocalProviderRawConfig {
  TOOL_GATEWAY_API_KEY?: string;
  FLIGHT_MCP_KEY?: string;
  VARIFLIGHT_API_KEY?: string;
  X_VARIFLIGHT_KEY?: string;
  FLIGHT_API_KEY?: string;
  VARIFLIGHT_API_URL?: string;
  FLIGHT_VARIFLIGHT_URL?: string;
  ROLLINGGO_HOTEL_MCP_KEY?: string;
  ROLLINGGO_HOTEL_MCP_URL?: string;
  AMAP_KEY?: string;
  AMAP_DEFAULT_LOCATION?: string;
  FOOD_DEFAULT_LOCATION?: string;
  AMAP_RADIUS?: string;
  TENCENT_MAP_KEY?: string;
  TENCENT_MAP_API_URL?: string;
  BAIDU_MAP_AK?: string;
  BAIDU_MAP_API_URL?: string;
  MEITUAN_UNION_APP_KEY?: string;
  MEITUAN_UNION_APP_SECRET?: string;
  MEITUAN_UNION_API_URL?: string;
  TAOBAO_APP_KEY?: string;
  TAOBAO_APP_SECRET?: string;
  TAOBAO_FLASH_PID?: string;
  TAOBAO_API_URL?: string;
  MCD_MCP_TOKEN?: string;
  MCD_MCP_URL?: string;
  LUCKIN_MCP_TOKEN?: string;
  LUCKIN_MCP_URL?: string;
  DIDI_MCP_KEY?: string;
  DIDI_MCP_URL?: string;
  DIDI_MCP_SANDBOX?: string;
  AMAP_MCP_KEY?: string;
  AMAP_MCP_URL?: string;
  RIDE_MOCK_ENABLED?: string;
  AIPHONE_WHATSAPP_TEST_TO?: string;
  GOOGLE_MAPS_API_KEY?: string;
  GMAIL_AUTH_URL?: string;
  GMAIL_OAUTH_CLIENT_ID?: string;
  GOOGLE_OAUTH_CLIENT_ID?: string;
  GMAIL_OAUTH_CLIENT_SECRET?: string;
  GOOGLE_OAUTH_CLIENT_SECRET?: string;
  GMAIL_OAUTH_REDIRECT_URI?: string;
  GOOGLE_OAUTH_REDIRECT_URI?: string;
  GMAIL_MCP_USER_PROJECT?: string;
  GOOGLE_CLOUD_PROJECT?: string;
  YOUTUBE_API_KEY?: string;
  ZHIHU_API_KEY?: string;
  QQ_MAIL_ADDRESS?: string;
  QQ_MAIL_AUTH_CODE?: string;
  QQ_MAIL_IMAP_HOST?: string;
  QQ_MAIL_IMAP_PORT?: string;
  QQ_MAIL_DRAFTS_MAILBOX?: string;
  PAYPAL_CLIENT_ID?: string;
  PAYPAL_CLIENT_SECRET?: string;
  PAYPAL_ENVIRONMENT?: string;
  PAYPAL_RETURN_URL?: string;
  PAYPAL_CANCEL_URL?: string;
  PAYPAL_CHECKOUT_GATEWAY_URL?: string;
  STRIPE_SECRET_KEY?: string;
  STRIPE_PUBLISHABLE_KEY?: string;
  STRIPE_SUCCESS_URL?: string;
  STRIPE_CANCEL_URL?: string;
  STRIPE_CHECKOUT_GATEWAY_URL?: string;
  STRIPE_TEST_SECRET_KEY?: string;
  STRIPE_LIVE_SECRET_KEY?: string;
  STRIPE_CONNECT_RETURN_URL?: string;
  STRIPE_CONNECT_REFRESH_URL?: string;
  STRIPE_RECEIVING_AGENT_JSON?: string;
  PAYMENT_ACCOUNT_BOOK_JSON?: string;
  PAYMENT_DEFAULT_CURRENCY?: string;
  PAYMENT_MODE?: string;
  PAYMENT_LIVE_ALLOWED_STRIPE_ACCOUNT_IDS?: string;
  PAYMENT_LIVE_MAX_AMOUNT_MINOR?: string;
  flightMcpKey?: string;
  variflightApiUrl?: string;
  hotelMcpKey?: string;
  hotelMcpUrl?: string;
  amapKey?: string;
  amapDefaultLocation?: string;
  amapRadius?: string;
  tencentMapKey?: string;
  tencentMapApiUrl?: string;
  baiduMapAk?: string;
  baiduMapApiUrl?: string;
  meituanUnionAppKey?: string;
  meituanUnionAppSecret?: string;
  meituanUnionApiUrl?: string;
  taobaoAppKey?: string;
  taobaoAppSecret?: string;
  taobaoFlashPid?: string;
  taobaoApiUrl?: string;
  mcdMcpToken?: string;
  mcdMcpUrl?: string;
  luckinMcpToken?: string;
  luckinMcpUrl?: string;
  didiMcpKey?: string;
  didiMcpUrl?: string;
  didiMcpSandbox?: string;
  amapMcpKey?: string;
  amapMcpUrl?: string;
  rideMockEnabled?: string;
  whatsappTestTo?: string;
  googleMapsApiKey?: string;
  googleOauthClientId?: string;
  googleOauthClientSecret?: string;
  googleOauthRedirectUri?: string;
  gmailAuthUrl?: string;
  gmailOauthClientId?: string;
  gmailOauthClientSecret?: string;
  gmailOauthRedirectUri?: string;
  gmailMcpUserProject?: string;
  youtubeApiKey?: string;
  zhihuApiKey?: string;
  qqMailAddress?: string;
  qqMailAuthCode?: string;
  qqMailImapHost?: string;
  qqMailImapPort?: string;
  qqMailDraftsMailbox?: string;
  paypalClientId?: string;
  paypalClientSecret?: string;
  paypalEnvironment?: string;
  paypalReturnUrl?: string;
  paypalCancelUrl?: string;
  paypalCheckoutGatewayUrl?: string;
  stripeSecretKey?: string;
  stripePublishableKey?: string;
  stripeSuccessUrl?: string;
  stripeCancelUrl?: string;
  stripeCheckoutGatewayUrl?: string;
  stripeConnectReturnUrl?: string;
  stripeConnectRefreshUrl?: string;
  stripeReceivingAgentJson?: string;
  paymentAccountBookJson?: string;
  paymentDefaultCurrency?: string;
  paymentMode?: string;
  paymentLiveAllowedStripeAccountIds?: string;
  paymentLiveMaxAmountMinor?: string;
  toolGatewayApiKey?: string;
}

interface VariFlightRequestParams {
  fnum?: string;
  date?: string;
  depcity?: string;
  arrcity?: string;
  dep_city?: string;
  arr_city?: string;
  dep_date?: string;
  price_mode?: string;
}

interface VariFlightRequestPayload {
  endpoint: string;
  params: VariFlightRequestParams;
}

type FlightProviderItem = FlightProviderRecord | string;

export interface FlightProviderRecord {
  FlightNo?: string;
  flightNo?: string;
  flight_no?: string;
  fnum?: string;
  Fnum?: string;
  flightNumber?: string;
  flight_number?: string;
  flight?: string;
  FlightCompany?: string;
  airline?: string;
  airlineName?: string;
  AirlineName?: string;
  carrier?: string;
  carrierName?: string;
  FlightDepcode?: string;
  FlightDepAirport?: string;
  dep?: string;
  depAirport?: string;
  depAirportName?: string;
  dep_city?: string;
  departure?: string;
  departureAirport?: string;
  FlightArrcode?: string;
  FlightArrAirport?: string;
  arr?: string;
  arrAirport?: string;
  arrAirportName?: string;
  arr_city?: string;
  arrival?: string;
  arrivalAirport?: string;
  FlightDeptimePlanDate?: string;
  FlightDeptimeReadyDate?: string;
  FlightDeptimeDate?: string;
  FlightDepTime?: string;
  depTime?: string;
  dep_time?: string;
  departureTime?: string;
  std?: string;
  scheduleDepTime?: string;
  FlightArrtimePlanDate?: string;
  FlightArrtimeReadyDate?: string;
  FlightArrtimeDate?: string;
  FlightArrTime?: string;
  arrTime?: string;
  arr_time?: string;
  arrivalTime?: string;
  sta?: string;
  scheduleArrTime?: string;
  FlightState?: string;
  FlightStatus?: string;
  status?: string;
  flightStatus?: string;
  state?: string;
  price?: string;
  Price?: string;
  lowestPrice?: string;
  LowestPrice?: string;
  fare?: string;
  amount?: string;
}

interface FlightProviderData {
  flights?: FlightProviderItem[];
  flightList?: FlightProviderItem[];
  list?: FlightProviderItem[];
  items?: FlightProviderItem[];
  records?: FlightProviderItem[];
  result?: FlightProviderItem[];
  results?: FlightProviderItem[];
}

interface FlightProviderPayload extends FlightProviderData {
  data?: FlightProviderData | FlightProviderItem[];
  error?: string;
  message?: string;
  msg?: string;
  info?: string;
  errmsg?: string;
  success?: boolean | string;
  status?: string | number;
}

interface AmapPoi {
  name?: string;
  type?: string;
  address?: string;
  distance?: string;
  location?: string;
  pname?: string;
  cityname?: string;
  adname?: string;
}

interface AmapGeocode {
  location?: string;
  formatted_address?: string;
  level?: string;
  province?: Object | string;
  city?: Object | string;
  district?: Object | string;
  citycode?: Object | string;
  adcode?: Object | string;
}

interface AmapPayload {
  status?: string;
  info?: string;
  infocode?: string;
  message?: string;
  pois?: AmapPoi[];
  geocodes?: AmapGeocode[];
}

interface AmapWeatherLive {
  province?: string;
  city?: string;
  adcode?: string;
  weather?: string;
  temperature?: string;
  winddirection?: string;
  windpower?: string;
  humidity?: string;
  reporttime?: string;
}

interface AmapWeatherCast {
  date?: string;
  week?: string;
  dayweather?: string;
  nightweather?: string;
  daytemp?: string;
  nighttemp?: string;
  daywind?: string;
  nightwind?: string;
  daypower?: string;
  nightpower?: string;
}

interface AmapWeatherForecast {
  province?: string;
  city?: string;
  adcode?: string;
  reporttime?: string;
  casts?: AmapWeatherCast[];
}

interface AmapWeatherPayload {
  status?: string;
  info?: string;
  infocode?: string;
  lives?: AmapWeatherLive[];
  forecasts?: AmapWeatherForecast[];
}

export interface TencentMapPlace {
  title?: string;
  address?: string;
  category?: string;
  _distance?: string | number;
  distance?: string | number;
  location?: FoodMapPoint;
}

interface TencentMapPayload {
  status?: string | number;
  message?: string;
  data?: TencentMapPlace[];
}

export interface BaiduPlaceDetailInfo {
  tag?: string;
  distance?: string | number;
  overall_rating?: string | number;
  price?: string | number;
}

export interface BaiduPlace {
  name?: string;
  address?: string;
  location?: FoodMapPoint;
  detail_info?: BaiduPlaceDetailInfo;
}

interface BaiduPlacePayload {
  status?: string | number;
  message?: string;
  results?: BaiduPlace[];
}

export interface FoodProviderResult {
  provider: string;
  foods: A2uiFoodData[];
  error: string;
  attempted?: boolean;
  succeeded?: boolean;
  operation?: string;
}

export interface FoodAggregationResult {
  foods: A2uiFoodData[];
  issues: FoodProviderResult[];
}

export interface FoodProviderStreamResult {
  aggregation: FoodAggregationResult;
  results: FoodProviderResult[];
}

export interface FoodProviderPartialSnapshot {
  provider: string;
  completed: number;
  total: number;
  foods: A2uiFoodData[];
  issues: FoodProviderResult[];
  results: FoodProviderResult[];
}

interface FoodProviderAdapter {
  name: string;
  search(prompt: string, query: FoodQuery, keyword: string, location: string, locationSource: string): Promise<FoodProviderResult>;
}

export interface MeituanUnionBrandInfo {
  brandName?: string;
  brandLogoUrl?: string;
}

export interface MeituanUnionCouponPackDetail {
  name?: string;
  sellPrice?: string;
  saleVolume?: string;
  productName?: string;
}

export interface MeituanUnionDeliverablePoiInfo {
  poiName?: string;
  deliveryDistance?: string;
  distributionCost?: string;
  deliveryDuration?: string;
  lastDeliveryFee?: string;
}

export interface MeituanUnionRecord {
  brandInfo?: MeituanUnionBrandInfo;
  couponPackDetail?: MeituanUnionCouponPackDetail;
  deliverablePoiInfo?: MeituanUnionDeliverablePoiInfo;
  brandName?: string;
  name?: string;
  title?: string;
  categoryName?: string;
  deliveryDistance?: string;
  distributionCost?: string;
  deliveryDuration?: string;
  lastDeliveryFee?: string;
}

interface MeituanUnionPayload {
  code?: string | number;
  status?: string | number;
  message?: string;
  msg?: string;
  error?: string;
  data?: MeituanUnionRecord[] | MeituanUnionRecordContainer;
  result?: MeituanUnionRecord[] | MeituanUnionRecordContainer;
}

interface MeituanUnionRecordContainer {
  list?: MeituanUnionRecord[];
  records?: MeituanUnionRecord[];
  items?: MeituanUnionRecord[];
  products?: MeituanUnionRecord[];
}

export interface TaobaoFlashItemRecord {
  title?: string;
  price?: string;
}

export interface TaobaoFlashStoreRecord {
  title?: string;
  shop_name?: string;
  name?: string;
  category_1_name?: string;
  category_name?: string;
  delivery_distance?: string | number;
  distance?: string | number;
  delivery_time?: string | number;
  delivery_price?: string | number;
  service_rating?: string | number;
  rating?: string | number;
  items?: TaobaoFlashItemRecord[];
  item_list?: TaobaoFlashItemRecord[];
}

interface TaobaoFlashPayload {
  error_response?: TaobaoErrorResponse;
  alibaba_alsc_union_eleme_promotion_storepromotion_query_response?: TaobaoFlashResponse;
}

interface TaobaoErrorResponse {
  code?: string | number;
  sub_code?: string;
  msg?: string;
  sub_msg?: string;
}

interface TaobaoFlashResponse {
  result?: TaobaoFlashResult;
  data?: TaobaoFlashResult | TaobaoFlashStoreRecord[];
}

interface TaobaoFlashResult {
  success?: boolean | string;
  msg_info?: string;
  msg_code?: string;
  result_list?: TaobaoFlashStoreRecord[];
  records?: TaobaoFlashStoreRecord[];
  data?: TaobaoFlashStoreRecord[];
}

interface McpJsonRpcResponse {
  result?: McpToolResult;
  error?: McpJsonRpcError;
}

interface McpJsonRpcError {
  code?: string | number;
  message?: string;
  data?: Object | string | number | boolean;
}

interface McpToolResult {
  content?: McpContentItem[];
  structuredContent?: Object;
  isError?: boolean;
}

interface McpContentItem {
  type?: string;
  text?: string;
  data?: Object | string | number | boolean;
}

interface McpInitializedNotification {
  jsonrpc: string;
  method: string;
}

interface McDonaldsNearbyStoresArgs {
  searchType: number;
  beType: number;
  city: string;
  keyword: string;
}

interface McDonaldsMealsArgs {
  storeCode: string;
  beCode: string;
  orderType: number;
  beType: number;
}

interface LuckinShopListArgs {
  deptName: string;
  longitude: number;
  latitude: number;
}

interface LuckinProductSearchArgs {
  deptId: number;
  query: string;
}

interface LuckinProductDetailArgs {
  deptId: number;
  productId: number;
}

interface LuckinSwitchProductArgs {
  deptId: number;
  productId: number;
  skuCode: string;
  attrOperationParam: LuckinAttrOperationParam;
  amount: number;
}

interface LuckinAttrOperationParam {
  attributeId: number;
  subAttr: LuckinSubAttrOperation;
}

interface LuckinSubAttrOperation {
  attributeId: number;
  operation: number;
}

interface LuckinOrderProductArgs {
  productId: number;
  skuCode: string;
  amount: number;
}

interface LuckinOrderRequestArgs {
  deptId: number;
  productList: LuckinOrderProductArgs[];
  longitude: number;
  latitude: number;
  couponCodeList?: string[];
  remark?: string;
}

type McDonaldsMcpData =
  McDonaldsStoreRecord[] |
  McDonaldsStoreContainer |
  McDonaldsMealsData |
  McDonaldsMealRecord |
  McDonaldsCouponRecord[] |
  McDonaldsCouponContainer |
  McDonaldsPriceData;

interface McDonaldsPayload {
  success?: boolean | string;
  code?: string | number;
  message?: string;
  data?: McDonaldsMcpData;
  result?: McDonaldsMcpData;
}

interface McDonaldsStoreRecord {
  storeName?: string;
  name?: string;
  address?: string;
  distance?: string | number;
  storeCode?: string;
  beCode?: string;
  businessStatus?: boolean | string | number;
  businessStartTime?: string;
  businessEndTime?: string;
}

interface McDonaldsStoreContainer {
  list?: McDonaldsStoreRecord[];
  records?: McDonaldsStoreRecord[];
  items?: McDonaldsStoreRecord[];
  products?: McDonaldsStoreRecord[];
  data?: McDonaldsStoreRecord[];
  result?: McDonaldsStoreRecord[];
}

interface McDonaldsCategoryRecord {
  name?: string;
  meals?: McDonaldsCategoryMeal[];
}

interface McDonaldsCategoryMeal {
  code?: string;
  tags?: string[];
}

interface McDonaldsMealRecord {
  name?: string;
  currentPrice?: string | number;
  price?: string | number;
  tags?: string[];
}

interface McDonaldsMealsData {
  categories?: McDonaldsCategoryRecord[];
  meals?: McDonaldsMealsMap | McDonaldsMealRecord[];
}

interface McDonaldsMealsMap {
}

interface McDonaldsMealEntry {
  code: string;
  meal: McDonaldsMealRecord;
}

interface McDonaldsCouponRecord {
  title?: string;
  name?: string;
  couponCode?: string;
  couponId?: string;
  tradeDateTime?: string;
  products?: McDonaldsCouponProduct[];
}

interface McDonaldsCouponProduct {
  productName?: string;
  productCode?: string;
}

interface McDonaldsCouponContainer {
  list?: McDonaldsCouponRecord[];
  records?: McDonaldsCouponRecord[];
  items?: McDonaldsCouponRecord[];
  products?: McDonaldsCouponRecord[];
  data?: McDonaldsCouponRecord[];
  result?: McDonaldsCouponRecord[];
}

interface McDonaldsPriceData {
  productList?: McDonaldsPriceProduct[];
  price?: string | number;
  discount?: string | number;
  deliveryPrice?: string | number;
}

interface McDonaldsPriceProduct {
  productName?: string;
  productCode?: string;
  quantity?: string | number;
  subtotal?: string | number;
  originalSubtotal?: string | number;
}

type LuckinMcpData =
  LuckinShopRecord[] |
  LuckinShopContainer |
  LuckinProductRecord[] |
  LuckinProductContainer |
  LuckinProductRecord |
  LuckinOrderRecord;

interface LuckinPayload {
  data?: LuckinMcpData;
  result?: LuckinMcpData;
  message?: string;
  msg?: string;
  code?: string | number;
  success?: boolean | string;
}

interface LuckinShopRecord {
  deptId?: string | number;
  deptName?: string;
  shopName?: string;
  storeName?: string;
  name?: string;
  title?: string;
  address?: string;
  deptAddress?: string;
  shopAddress?: string;
  deptTags?: string[];
  tags?: string[];
  longitude?: string | number;
  latitude?: string | number;
  lng?: string | number;
  lat?: string | number;
  distanceDesc?: string | number;
  workTimeStart?: string;
  workTimeEnd?: string;
  workTime?: string;
  businessTime?: string;
  distance?: string | number;
  number?: string;
}

interface LuckinShopContainer {
  list?: LuckinShopRecord[];
  records?: LuckinShopRecord[];
  items?: LuckinShopRecord[];
  products?: LuckinShopRecord[];
  data?: LuckinShopRecord[];
  result?: LuckinShopRecord[];
}

interface LuckinProductRecord {
  productId?: string | number;
  productName?: string;
  name?: string;
  skuCode?: string;
  pictureUrl?: string;
  price?: string | number;
  discountPrice?: string | number;
  initPrice?: string | number;
  productAttrs?: LuckinProductAttr[];
  tags?: string[];
}

interface LuckinProductContainer {
  list?: LuckinProductRecord[];
  records?: LuckinProductRecord[];
  items?: LuckinProductRecord[];
  products?: LuckinProductRecord[];
  data?: LuckinProductRecord[];
  result?: LuckinProductRecord[];
}

interface LuckinProductAttr {
  attributeId?: number;
  attributeName?: string;
  productSubAttrs?: LuckinProductSubAttr[];
}

interface LuckinProductSubAttr {
  attributeId?: number;
  attributeName?: string;
  selected?: boolean | null;
  canSelected?: number | null;
  price?: number | null;
}

interface LuckinOrderRecord {
  orderId?: string | number;
  orderIdStr?: string;
  orderStatusName?: string;
  orderStatus?: string | number;
  aboutTime?: string | number;
  takeMealTime?: string;
  shopInfo?: LuckinShopRecord;
  productInfoList?: LuckinProductRecord[];
  productList?: LuckinProductRecord[];
  orderCommodityList?: LuckinProductRecord[];
  orderPayAmount?: string | number;
  totalInitialPrice?: string | number;
  privilegeMoney?: string | number;
  discountPrice?: string | number;
  couponCodeList?: string[];
  payOrderUrl?: string;
  payOrderQrCodeUrl?: string;
  needPay?: boolean | string;
  tradeNo?: string | number;
}

interface LuckinOrderRecordAliases extends LuckinOrderRecord {
  order_id?: string | number;
  order_id_str?: string;
  order_no?: string | number;
  orderNo?: string | number;
  pay_order_url?: string;
  payUrl?: string;
  pay_url?: string;
  wechatPayUrl?: string;
  wechat_pay_url?: string;
  pay_order_qr_code_url?: string;
  qrCodeUrl?: string;
  qr_code_url?: string;
  trade_no?: string | number;
}

interface LuckinPayloadBag extends LuckinPayload {
  orderInfo?: LuckinOrderRecord;
  order?: LuckinOrderRecord;
  orderDetail?: LuckinOrderRecord;
  orderData?: LuckinOrderRecord;
  content?: LuckinOrderRecord;
}

interface FoodParamPair {
  key: string;
  value: string;
}

interface FoodMapPoint {
  lat?: string | number;
  lng?: string | number;
}

interface FlightCityCode {
  city: string;
  code: string;
}

interface FlightRoute {
  routeNames: string[];
  depCode: string;
  arrCode: string;
}

interface AmapLocationResolution {
  location: string;
  locationSource: string;
  locationLabel: string;
  city: string;
}

interface FoodQuery {
  place: string;
  keyword: string;
}

const LOCAL_TOOL_GATEWAY_URL: string = 'local://aiphone-tools';
const LOCAL_PROVIDER_CONFIG_RAWFILE: string = 'aiphone_provider_config.json';
const DEFAULT_VARIFLIGHT_API_URL: string = 'https://mcp.variflight.com/api/v1/mcp/data';
const DEFAULT_AMAP_RADIUS: string = '3000';
const DEFAULT_TENCENT_MAP_API_URL: string = 'https://apis.map.qq.com/ws/place/v1/search';
const DEFAULT_BAIDU_MAP_API_URL: string = 'https://api.map.baidu.com/place/v2/search';
const DEFAULT_MEITUAN_UNION_API_URL: string = 'https://media.meituan.com/cps_open/common/api/v1/query_coupon';
const DEFAULT_TAOBAO_API_URL: string = 'https://eco.taobao.com/router/rest';
const DEFAULT_MCD_MCP_URL: string = 'https://mcp.mcd.cn';
const DEFAULT_LUCKIN_MCP_URL: string = 'https://gwmcp.lkcoffee.com/order/user/mcp';
const DEFAULT_DIDI_MCP_URL: string = 'https://mcp.didichuxing.com/mcp-servers';
const DEFAULT_DIDI_MCP_SANDBOX_URL: string = 'https://mcp.didichuxing.com/mcp-servers-sandbox';
const DEFAULT_AMAP_MCP_URL: string = 'https://mcp.amap.com/mcp';
const MCP_PROTOCOL_VERSION: string = '2025-06-18';
const FOOD_PROVIDER_RESULT_LIMIT: number = 10;
const FOOD_AGGREGATED_RESULT_LIMIT: number = 24;
const TRAIN_RESULT_LIMIT: number = 30;
const TRAIN_INITIAL_VISIBLE: number = 6;
const TRAIN_CLIENT_ACTIONS: A2uiAction[] = [
  { id: 'client_show_more', label: '多展示一些', prompt: 'client_show_more', kind: 'client', variant: 'primary' },
  { id: 'client_sort_fastest', label: '选最快的', prompt: 'client_sort_fastest', kind: 'client', variant: 'secondary' },
  { id: 'client_filter_available', label: '只看有票', prompt: 'client_filter_available', kind: 'client', variant: 'secondary' },
  { id: 'client_edit_query', label: '修改查询', prompt: 'client_edit_query', kind: 'input', variant: 'secondary' }
];
const TRAVEL_CLIENT_ACTIONS: A2uiAction[] = [
  { id: 'travel_show_all', label: '全部', prompt: 'travel_show_all', kind: 'client', variant: 'secondary' },
  { id: 'travel_filter_train', label: '只看高铁', prompt: 'travel_filter_train', kind: 'client', variant: 'secondary' },
  { id: 'travel_filter_flight', label: '只看飞机', prompt: 'travel_filter_flight', kind: 'client', variant: 'secondary' },
  { id: 'travel_change_date', label: '换日期', prompt: '换日期重新查询出行方案', kind: 'input', variant: 'secondary' },
  { id: 'travel_retry', label: '重新查询', prompt: '重新查询出行方案', kind: 'prompt', variant: 'primary' }
];
const HIGH_SPEED_DEFAULT_STATIONS: StationDefault[] = [
  { city: '北京', station: '北京南' },
  { city: '上海', station: '上海虹桥' },
  { city: '天津', station: '天津西' },
  { city: '南京', station: '南京南' },
  { city: '杭州', station: '杭州东' },
  { city: '广州', station: '广州南' },
  { city: '深圳', station: '深圳北' },
  { city: '武汉', station: '武汉' },
  { city: '成都', station: '成都东' },
  { city: '重庆', station: '重庆北' }
];
const CHINA_FLIGHT_CITY_CODES: FlightCityCode[] = [
  { city: '北京', code: 'BJS' },
  { city: '上海', code: 'SHA' },
  { city: '广州', code: 'CAN' },
  { city: '深圳', code: 'SZX' },
  { city: '杭州', code: 'HGH' },
  { city: '成都', code: 'CTU' },
  { city: '重庆', code: 'CKG' },
  { city: '西安', code: 'SIA' },
  { city: '南京', code: 'NKG' },
  { city: '武汉', code: 'WUH' },
  { city: '厦门', code: 'XMN' },
  { city: '青岛', code: 'TAO' },
  { city: '长沙', code: 'CSX' },
  { city: '昆明', code: 'KMG' },
  { city: '海口', code: 'HAK' },
  { city: '三亚', code: 'SYX' }
];

let stationCache: StationCache | null = null;
let localProviderConfig: LocalProviderConfig = {
  toolGatewayApiKey: '',
  flightMcpKey: '',
  variflightApiUrl: DEFAULT_VARIFLIGHT_API_URL,
  hotelMcpKey: '',
  hotelMcpUrl: '',
  amapKey: '',
  amapDefaultLocation: '',
  amapRadius: DEFAULT_AMAP_RADIUS,
  tencentMapKey: '',
  tencentMapApiUrl: DEFAULT_TENCENT_MAP_API_URL,
  baiduMapAk: '',
  baiduMapApiUrl: DEFAULT_BAIDU_MAP_API_URL,
  meituanUnionAppKey: '',
  meituanUnionAppSecret: '',
  meituanUnionApiUrl: DEFAULT_MEITUAN_UNION_API_URL,
  taobaoAppKey: '',
  taobaoAppSecret: '',
  taobaoFlashPid: '',
  taobaoApiUrl: DEFAULT_TAOBAO_API_URL,
  mcdMcpToken: '',
  mcdMcpUrl: DEFAULT_MCD_MCP_URL,
  luckinMcpToken: '',
  luckinMcpUrl: DEFAULT_LUCKIN_MCP_URL,
  didiMcpKey: '',
  didiMcpUrl: DEFAULT_DIDI_MCP_SANDBOX_URL,
  didiMcpSandbox: 'true',
  amapMcpKey: '',
  amapMcpUrl: DEFAULT_AMAP_MCP_URL,
  rideMockEnabled: 'false',
  whatsappTestTo: '',
  googleMapsApiKey: '',
  googleOauthClientId: '',
  googleOauthClientSecret: '',
  googleOauthRedirectUri: '',
  gmailAuthUrl: '',
  gmailOauthClientId: '',
  gmailOauthClientSecret: '',
  gmailOauthRedirectUri: '',
  gmailMcpUserProject: '',
  youtubeApiKey: '',
  zhihuApiKey: '',
  qqMailAddress: '',
  qqMailAuthCode: '',
  qqMailImapHost: 'imap.qq.com',
  qqMailImapPort: '993',
  qqMailDraftsMailbox: '',
  paypalClientId: '',
  paypalClientSecret: '',
  paypalEnvironment: 'sandbox',
  paypalReturnUrl: 'aiphone://payment/paypal/success',
  paypalCancelUrl: 'aiphone://payment/paypal/cancel',
  paypalCheckoutGatewayUrl: '',
  stripeSecretKey: '',
  stripePublishableKey: '',
  stripeSuccessUrl: 'aiphone://payment/stripe/success',
  stripeCancelUrl: 'aiphone://payment/stripe/cancel',
  stripeCheckoutGatewayUrl: '',
  stripeConnectReturnUrl: 'https://example.com/aiphone/stripe_connect_return',
  stripeConnectRefreshUrl: 'https://example.com/aiphone/stripe_connect_refresh',
  stripeReceivingAgentJson: '',
  paymentAccountBookJson: '',
  paymentDefaultCurrency: 'USD',
  paymentMode: 'test',
  paymentLiveAllowedStripeAccountIds: '',
  paymentLiveMaxAmountMinor: '100'
};

export interface LocalToolDebugConfig {
  foodProviderDelayEnabled: boolean;
  foodProviderDelayMs: number;
  foodPartialThrottleMs: number;
}

let localToolDebugConfig: LocalToolDebugConfig = {
  foodProviderDelayEnabled: false,
  foodProviderDelayMs: 0,
  foodPartialThrottleMs: 500
};

type LocalA2uiEmitter = (jsonl: string) => void;

interface MapsToolArgs {
  query?: string;
  textQuery?: string;
  keyword?: string;
  placeId?: string;
  id?: string;
}

interface WhatsAppSendArgs {
  toNumber?: ToolArgValue;
  text?: ToolArgValue;
  phoneNumberId?: ToolArgValue;
  wabaId?: ToolArgValue;
  previewUrl?: ToolArgValue;
}

interface WhatsAppProviderArgs {
  toNumber: string;
  text: string;
  phoneNumberId: string;
  previewUrl: boolean;
}

interface WhatsAppConfirmArgs {
  toNumber: string;
  text: string;
  phoneNumberId: string;
  wabaId: string;
  previewUrl: boolean;
}

interface WhatsAppPhoneNumbersArgs {
  wabaId?: string;
}

interface CalendarComposioArgs extends CalendarEventArgs {
  sendUpdates?: string;
}

type ToolArgValue = Object | string | number | boolean | null | undefined;
type ToolArgRecord = Record<string, ToolArgValue>;
type PaymentToolArgValue = ToolArgValue;
type PaymentToolArgRecord = ToolArgRecord;

interface RideRouteArgs {
  origin?: ToolArgValue;
  from?: ToolArgValue;
  start?: ToolArgValue;
  destination?: ToolArgValue;
  to?: ToolArgValue;
  end?: ToolArgValue;
  city?: ToolArgValue;
}

interface RideOrderArgs {
  productCategory?: ToolArgValue;
  product_category?: ToolArgValue;
  estimateTraceId?: ToolArgValue;
  estimate_trace_id?: ToolArgValue;
  traceId?: ToolArgValue;
  orderId?: ToolArgValue;
  order_id?: ToolArgValue;
  reason?: ToolArgValue;
}

interface RideDidiRequestArgs {
  from_lng: string;
  from_lat: string;
  to_lng: string;
  to_lat: string;
  from_name?: string;
  to_name?: string;
}

interface RideDidiTextSearchArgs {
  keywords: string;
  city: string;
}

interface RideDidiCreateOrderArgs {
  product_category: string;
  estimate_trace_id: string;
}

interface RideDidiCancelOrderArgs {
  order_id: string;
  reason?: string;
}

interface RideDidiDriverLocationArgs {
  order_id: string;
}

interface RideAmapAppLinkArgs {
  slon: string;
  slat: string;
  sname: string;
  dlon: string;
  dlat: string;
  dname: string;
}

interface RideLinkPreview {
  didiLink: number;
  amapLink: number;
}

interface RideOrderActionArgs {
  productCategory?: string;
  product_category?: string;
  productName?: string;
  priceText?: string;
  routeText?: string;
  origin?: string;
  destination?: string;
  pickupLocation?: string;
  originLocation?: string;
  destinationLocation?: string;
  estimateCacheJson?: string;
  estimateTraceId?: string;
  estimate_trace_id?: string;
  traceId?: string;
  orderId?: string;
  order_id?: string;
  reason?: string;
}

interface RideOrderRouteContext {
  routeText: string;
  pickupLocation: string;
  destinationLocation: string;
  selectedVehicleText: string;
  estimateCacheJson: string;
}

interface RideEstimateCacheProductRecord {
  productName: string;
  productCategory: string;
  priceText: string;
}

interface RideEstimateCachePayload {
  traceId: string;
  products: RideEstimateCacheProductRecord[];
}

interface RideMockEstimateContent {
  items: RideEstimateCacheProductRecord[];
  traceId: string;
}

interface RideMockEstimatePayload {
  structuredContent: RideMockEstimateContent;
}

interface RideMockOrderPayload {
  orderId: string;
  status: string;
}

interface RideMockDriverPayload {
  location: string;
  driverName: string;
  eta: string;
  status: string;
}

interface RideMockCancelPayload {
  status: string;
}

const RIDE_ORDER_CREATE_DEDUP_MS: number = 120000;
let lastRideOrderCreateKey: string = '';
let lastRideOrderCreateAtMs: number = 0;

interface PaymentToolActionArgs {
  recipient?: PaymentToolArgValue;
  provider?: PaymentToolArgValue;
  fundingSource?: PaymentToolArgValue;
  amountText?: PaymentToolArgValue;
  currency?: PaymentToolArgValue;
  note?: PaymentToolArgValue;
  phase?: PaymentToolArgValue;
  accountId?: PaymentToolArgValue;
  targetType?: PaymentToolArgValue;
  checkoutUrl?: PaymentToolArgValue;
  providerSessionId?: PaymentToolArgValue;
  originalQuery?: PaymentToolArgValue;
}

interface PaymentAccountRaw {
  id?: PaymentToolArgValue;
  displayName?: PaymentToolArgValue;
  aliases?: string[];
  email?: PaymentToolArgValue;
  paypalEmail?: PaymentToolArgValue;
  paypalMerchantId?: PaymentToolArgValue;
  stripeAccountId?: PaymentToolArgValue;
  stripePaymentLinkUrl?: PaymentToolArgValue;
  enabled?: PaymentToolArgValue;
}

interface PayPalTokenResponsePayload {
  access_token?: string;
}

interface PayPalAccessTokenResult {
  accessToken: string;
  error: string;
}

interface StripeCheckoutGatewayPayload {
  ok?: boolean;
  checkoutUrl?: string;
  providerSessionId?: string;
  error?: string;
}

function userAgentHeaders(): HttpRequestHeaders {
  return {
    'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1'
  };
}

function leftTicketHeaders(cookieHeader: string): HttpRequestHeaders {
  const headers: HttpRequestHeaders = {
    'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1',
    'Referer': 'https://kyfw.12306.cn/otn/leftTicket/init'
  };
  if (cookieHeader.length > 0) {
    headers.Cookie = cookieHeader;
  }
  return headers;
}

function createHeaders(): ToolGatewayHeaders {
  return {
    'Content-Type': 'application/json',
    'Accept': 'application/a2ui+json'
  };
}

function applyEnvelopes(store: A2uiSurfaceStore, envelopes: A2uiEnvelope[]): string {
  let error = '';
  envelopes.forEach((envelope: A2uiEnvelope) => {
    const result = store.apply(envelope);
    if (!result.ok && error.length === 0) {
      error = result.error;
    }
  });
  return error;
}

export function defaultToolGatewayUrl(): string {
  return LOCAL_TOOL_GATEWAY_URL;
}

export function currentToolGatewayApiKey(): string {
  return localProviderConfig.toolGatewayApiKey;
}

export function isLocalToolGatewayUrl(baseUrl: string): boolean {
  return baseUrl.trim().toLowerCase() === LOCAL_TOOL_GATEWAY_URL;
}

export function buildToolGatewayUrl(baseUrl: string): string {
  if (isLocalToolGatewayUrl(baseUrl)) {
    return LOCAL_TOOL_GATEWAY_URL;
  }
  let cleaned = baseUrl.trim();
  while (cleaned.endsWith('/')) {
    cleaned = cleaned.substring(0, cleaned.length - 1);
  }
  if (cleaned.endsWith('/api/aiphone/tool')) {
    return cleaned;
  }
  return cleaned + '/api/aiphone/tool';
}

export function isRegisteredToolId(toolId: string): boolean {
  if (isKnownDomainToolId(toolId)) {
    return true;
  }
  if (isBuiltInToolId(toolId)) {
    return true;
  }
  if (toolId === 'dynamic.search') {
    return true;
  }
  return sampleManifestForToolId(toolId) !== null;
}

export function configureLocalToolDebugConfig(config: LocalToolDebugConfig): void {
  const delayMs = config.foodProviderDelayMs < 0 ? 0 : config.foodProviderDelayMs;
  const throttleMs = config.foodPartialThrottleMs < 0 ? 0 : config.foodPartialThrottleMs;
  localToolDebugConfig = {
    foodProviderDelayEnabled: config.foodProviderDelayEnabled,
    foodProviderDelayMs: delayMs,
    foodPartialThrottleMs: throttleMs
  };
  aiLogInfo('[AIPhone][LocalToolDebugConfig] foodProviderDelayEnabled=' +
    (config.foodProviderDelayEnabled ? 'true' : 'false') +
    ' foodProviderDelayMs=' + delayMs.toString() +
    ' foodPartialThrottleMs=' + throttleMs.toString());
}

function firstText(values: Array<Object | string | number | boolean | null | undefined>): string {
  for (let index = 0; index < values.length; index++) {
    const text = textOf(values[index]).trim();
    if (text.length > 0) {
      return text;
    }
  }
  return '';
}

export function configureLocalProviderConfig(config: LocalProviderConfig): void {
  localProviderConfig = {
    toolGatewayApiKey: config.toolGatewayApiKey.trim(),
    flightMcpKey: config.flightMcpKey.trim(),
    variflightApiUrl: config.variflightApiUrl.trim().length > 0 ? config.variflightApiUrl.trim() : DEFAULT_VARIFLIGHT_API_URL,
    hotelMcpKey: config.hotelMcpKey.trim(),
    hotelMcpUrl: config.hotelMcpUrl.trim(),
    amapKey: config.amapKey.trim(),
    amapDefaultLocation: config.amapDefaultLocation.trim(),
    amapRadius: config.amapRadius.trim().length > 0 ? config.amapRadius.trim() : DEFAULT_AMAP_RADIUS,
    tencentMapKey: config.tencentMapKey.trim(),
    tencentMapApiUrl: config.tencentMapApiUrl.trim().length > 0 ? config.tencentMapApiUrl.trim() : DEFAULT_TENCENT_MAP_API_URL,
    baiduMapAk: config.baiduMapAk.trim(),
    baiduMapApiUrl: config.baiduMapApiUrl.trim().length > 0 ? config.baiduMapApiUrl.trim() : DEFAULT_BAIDU_MAP_API_URL,
    meituanUnionAppKey: config.meituanUnionAppKey.trim(),
    meituanUnionAppSecret: config.meituanUnionAppSecret.trim(),
    meituanUnionApiUrl: config.meituanUnionApiUrl.trim().length > 0 ? config.meituanUnionApiUrl.trim() : DEFAULT_MEITUAN_UNION_API_URL,
    taobaoAppKey: config.taobaoAppKey.trim(),
    taobaoAppSecret: config.taobaoAppSecret.trim(),
    taobaoFlashPid: config.taobaoFlashPid.trim(),
    taobaoApiUrl: config.taobaoApiUrl.trim().length > 0 ? config.taobaoApiUrl.trim() : DEFAULT_TAOBAO_API_URL,
    mcdMcpToken: config.mcdMcpToken.trim(),
    mcdMcpUrl: config.mcdMcpUrl.trim().length > 0 ? config.mcdMcpUrl.trim() : DEFAULT_MCD_MCP_URL,
    luckinMcpToken: config.luckinMcpToken.trim(),
    luckinMcpUrl: config.luckinMcpUrl.trim().length > 0 ? config.luckinMcpUrl.trim() : DEFAULT_LUCKIN_MCP_URL,
    didiMcpKey: config.didiMcpKey.trim(),
    didiMcpUrl: config.didiMcpUrl.trim().length > 0 ? config.didiMcpUrl.trim() :
      (config.didiMcpSandbox.trim().toLowerCase() === 'false' ? DEFAULT_DIDI_MCP_URL : DEFAULT_DIDI_MCP_SANDBOX_URL),
    didiMcpSandbox: config.didiMcpSandbox.trim().toLowerCase() === 'false' ? 'false' : 'true',
    amapMcpKey: config.amapMcpKey.trim().length > 0 ? config.amapMcpKey.trim() : config.amapKey.trim(),
    amapMcpUrl: config.amapMcpUrl.trim().length > 0 ? config.amapMcpUrl.trim() : DEFAULT_AMAP_MCP_URL,
    rideMockEnabled: config.rideMockEnabled.trim().toLowerCase() === 'true' ? 'true' : 'false',
    whatsappTestTo: config.whatsappTestTo.trim(),
    googleMapsApiKey: config.googleMapsApiKey.trim(),
    googleOauthClientId: config.googleOauthClientId.trim(),
    googleOauthClientSecret: config.googleOauthClientSecret.trim(),
    googleOauthRedirectUri: config.googleOauthRedirectUri.trim().length > 0 ? config.googleOauthRedirectUri.trim() : GMAIL_DEFAULT_REDIRECT_URI,
    gmailAuthUrl: config.gmailAuthUrl.trim(),
    gmailOauthClientId: config.gmailOauthClientId.trim(),
    gmailOauthClientSecret: config.gmailOauthClientSecret.trim(),
    gmailOauthRedirectUri: config.gmailOauthRedirectUri.trim().length > 0 ? config.gmailOauthRedirectUri.trim() : GMAIL_DEFAULT_REDIRECT_URI,
    gmailMcpUserProject: config.gmailMcpUserProject.trim(),
    youtubeApiKey: config.youtubeApiKey.trim(),
    zhihuApiKey: config.zhihuApiKey.trim(),
    qqMailAddress: config.qqMailAddress.trim(),
    qqMailAuthCode: config.qqMailAuthCode.trim(),
    qqMailImapHost: config.qqMailImapHost.trim().length > 0 ? config.qqMailImapHost.trim() : 'imap.qq.com',
    qqMailImapPort: config.qqMailImapPort.trim().length > 0 ? config.qqMailImapPort.trim() : '993',
    qqMailDraftsMailbox: config.qqMailDraftsMailbox.trim(),
    paypalClientId: config.paypalClientId.trim(),
    paypalClientSecret: config.paypalClientSecret.trim(),
    paypalEnvironment: config.paypalEnvironment.trim().toLowerCase() === 'live' ? 'live' : 'sandbox',
    paypalReturnUrl: config.paypalReturnUrl.trim().length > 0 ? config.paypalReturnUrl.trim() : 'aiphone://payment/paypal/success',
    paypalCancelUrl: config.paypalCancelUrl.trim().length > 0 ? config.paypalCancelUrl.trim() : 'aiphone://payment/paypal/cancel',
    paypalCheckoutGatewayUrl: config.paypalCheckoutGatewayUrl.trim(),
    stripeSecretKey: config.stripeSecretKey.trim(),
    stripePublishableKey: config.stripePublishableKey.trim(),
    stripeSuccessUrl: config.stripeSuccessUrl.trim().length > 0 ? config.stripeSuccessUrl.trim() : 'aiphone://payment/stripe/success',
    stripeCancelUrl: config.stripeCancelUrl.trim().length > 0 ? config.stripeCancelUrl.trim() : 'aiphone://payment/stripe/cancel',
    stripeCheckoutGatewayUrl: config.stripeCheckoutGatewayUrl.trim(),
    stripeConnectReturnUrl: config.stripeConnectReturnUrl.trim().length > 0 ? config.stripeConnectReturnUrl.trim() : 'https://example.com/aiphone/stripe_connect_return',
    stripeConnectRefreshUrl: config.stripeConnectRefreshUrl.trim().length > 0 ? config.stripeConnectRefreshUrl.trim() : 'https://example.com/aiphone/stripe_connect_refresh',
    stripeReceivingAgentJson: config.stripeReceivingAgentJson.trim(),
    paymentAccountBookJson: config.paymentAccountBookJson.trim(),
    paymentDefaultCurrency: config.paymentDefaultCurrency.trim().length > 0 ? config.paymentDefaultCurrency.trim().toUpperCase() : 'USD',
    paymentMode: config.paymentMode.trim().toLowerCase() === 'live' ? 'live' : 'test',
    paymentLiveAllowedStripeAccountIds: config.paymentLiveAllowedStripeAccountIds.trim(),
    paymentLiveMaxAmountMinor: config.paymentLiveMaxAmountMinor.trim().length > 0 ? config.paymentLiveMaxAmountMinor.trim() : '100'
  };
  aiLogInfo('[AIPhone][LocalProviderConfig] rawfile=' + LOCAL_PROVIDER_CONFIG_RAWFILE +
    ' toolGatewayApiKeyChars=' + localProviderConfig.toolGatewayApiKey.length.toString() +
    ' flightKeyChars=' + localProviderConfig.flightMcpKey.length.toString() +
    ' hotelKeyChars=' + localProviderConfig.hotelMcpKey.length.toString() +
    ' hotelUrlPresent=' + (localProviderConfig.hotelMcpUrl.length > 0 ? 'true' : 'false') +
    ' amapKeyChars=' + localProviderConfig.amapKey.length.toString() +
    ' tencentMapKeyChars=' + localProviderConfig.tencentMapKey.length.toString() +
    ' baiduMapAkChars=' + localProviderConfig.baiduMapAk.length.toString() +
    ' meituanKeyChars=' + localProviderConfig.meituanUnionAppKey.length.toString() +
    ' taobaoKeyChars=' + localProviderConfig.taobaoAppKey.length.toString() +
    ' taobaoPidChars=' + localProviderConfig.taobaoFlashPid.length.toString() +
    ' mcdMcpTokenChars=' + localProviderConfig.mcdMcpToken.length.toString() +
    ' luckinMcpTokenChars=' + localProviderConfig.luckinMcpToken.length.toString() +
    ' didiMcpKeyChars=' + localProviderConfig.didiMcpKey.length.toString() +
    ' didiMcpSandbox=' + localProviderConfig.didiMcpSandbox +
    ' amapMcpKeyChars=' + localProviderConfig.amapMcpKey.length.toString() +
    ' rideMockEnabled=' + localProviderConfig.rideMockEnabled +
    ' whatsappTestToPresent=' + (localProviderConfig.whatsappTestTo.length > 0 ? 'true' : 'false') +
    ' googleMapsApiKeyChars=' + localProviderConfig.googleMapsApiKey.length.toString() +
    ' googleOauthClientIdChars=' + localProviderConfig.googleOauthClientId.length.toString() +
    ' gmailOauthClientIdChars=' + localProviderConfig.gmailOauthClientId.length.toString() +
    ' gmailOauthClientSecretChars=' + localProviderConfig.gmailOauthClientSecret.length.toString() +
    ' youtubeApiKeyChars=' + localProviderConfig.youtubeApiKey.length.toString() +
    ' zhihuApiKeyChars=' + localProviderConfig.zhihuApiKey.length.toString() +
    ' gmailMcpUserProjectPresent=' + (localProviderConfig.gmailMcpUserProject.length > 0 ? 'true' : 'false') +
    ' qqMailAddressPresent=' + (localProviderConfig.qqMailAddress.length > 0 ? 'true' : 'false') +
    ' qqMailAuthCodeChars=' + localProviderConfig.qqMailAuthCode.length.toString() +
    ' paypalClientIdChars=' + localProviderConfig.paypalClientId.length.toString() +
    ' paypalClientSecretChars=' + localProviderConfig.paypalClientSecret.length.toString() +
    ' stripeSecretKeyChars=' + localProviderConfig.stripeSecretKey.length.toString() +
    ' stripePublishableKeyChars=' + localProviderConfig.stripePublishableKey.length.toString() +
    ' stripeConnectReturnUrlPresent=' + (localProviderConfig.stripeConnectReturnUrl.length > 0 ? 'true' : 'false') +
    ' stripeReceivingAgentJsonChars=' + localProviderConfig.stripeReceivingAgentJson.length.toString() +
    ' paymentAccountBookJsonChars=' + localProviderConfig.paymentAccountBookJson.length.toString() +
    ' defaultLocationPresent=' + (localProviderConfig.amapDefaultLocation.length > 0 ? 'true' : 'false'));
}

export function configureDidiMcpSandboxForRuntime(enabled: boolean): void {
  localProviderConfig.didiMcpSandbox = enabled ? 'true' : 'false';
  const currentUrl = localProviderConfig.didiMcpUrl.trim();
  if (currentUrl.length === 0 ||
    currentUrl === DEFAULT_DIDI_MCP_URL ||
    currentUrl === DEFAULT_DIDI_MCP_SANDBOX_URL) {
    localProviderConfig.didiMcpUrl = enabled ? DEFAULT_DIDI_MCP_SANDBOX_URL : DEFAULT_DIDI_MCP_URL;
  }
  aiLogInfo('[AIPhone][DidiMcpSandboxRuntime] didiMcpSandbox=' + localProviderConfig.didiMcpSandbox +
    ' didiMcpUrl=' + (localProviderConfig.didiMcpUrl === DEFAULT_DIDI_MCP_SANDBOX_URL ? 'sandbox' :
      (localProviderConfig.didiMcpUrl === DEFAULT_DIDI_MCP_URL ? 'production' : 'custom')));
}

export function rideDidiMcpSandboxEnabledForRuntime(): boolean {
  return localProviderConfig.didiMcpSandbox === 'true';
}

export function configureLocalProviderConfigFromRawJson(rawJson: string): void {
  const parsed = JSON.parse(rawJson) as LocalProviderRawConfig;
  const paymentMode = firstText([parsed.PAYMENT_MODE, parsed.paymentMode]).trim().toLowerCase() === 'live' ? 'live' : 'test';
  const stripeSecretKey = paymentMode === 'live' ?
    firstText([parsed.STRIPE_SECRET_KEY, parsed.STRIPE_LIVE_SECRET_KEY, parsed.stripeSecretKey]) :
    firstText([parsed.STRIPE_SECRET_KEY, parsed.STRIPE_TEST_SECRET_KEY, parsed.stripeSecretKey]);
  configureLocalProviderConfig({
    toolGatewayApiKey: firstText([parsed.TOOL_GATEWAY_API_KEY, parsed.toolGatewayApiKey]),
    flightMcpKey: firstText([parsed.FLIGHT_MCP_KEY, parsed.VARIFLIGHT_API_KEY, parsed.X_VARIFLIGHT_KEY, parsed.FLIGHT_API_KEY, parsed.flightMcpKey]),
    variflightApiUrl: firstText([parsed.VARIFLIGHT_API_URL, parsed.FLIGHT_VARIFLIGHT_URL, parsed.variflightApiUrl]),
    hotelMcpKey: firstText([parsed.ROLLINGGO_HOTEL_MCP_KEY, parsed.hotelMcpKey]),
    hotelMcpUrl: firstText([parsed.ROLLINGGO_HOTEL_MCP_URL, parsed.hotelMcpUrl]),
    amapKey: firstText([parsed.AMAP_KEY, parsed.amapKey]),
    amapDefaultLocation: firstText([parsed.AMAP_DEFAULT_LOCATION, parsed.FOOD_DEFAULT_LOCATION, parsed.amapDefaultLocation]),
    amapRadius: firstText([parsed.AMAP_RADIUS, parsed.amapRadius]),
    tencentMapKey: firstText([parsed.TENCENT_MAP_KEY, parsed.tencentMapKey]),
    tencentMapApiUrl: firstText([parsed.TENCENT_MAP_API_URL, parsed.tencentMapApiUrl]),
    baiduMapAk: firstText([parsed.BAIDU_MAP_AK, parsed.baiduMapAk]),
    baiduMapApiUrl: firstText([parsed.BAIDU_MAP_API_URL, parsed.baiduMapApiUrl]),
    meituanUnionAppKey: firstText([parsed.MEITUAN_UNION_APP_KEY, parsed.meituanUnionAppKey]),
    meituanUnionAppSecret: firstText([parsed.MEITUAN_UNION_APP_SECRET, parsed.meituanUnionAppSecret]),
    meituanUnionApiUrl: firstText([parsed.MEITUAN_UNION_API_URL, parsed.meituanUnionApiUrl]),
    taobaoAppKey: firstText([parsed.TAOBAO_APP_KEY, parsed.taobaoAppKey]),
    taobaoAppSecret: firstText([parsed.TAOBAO_APP_SECRET, parsed.taobaoAppSecret]),
    taobaoFlashPid: firstText([parsed.TAOBAO_FLASH_PID, parsed.taobaoFlashPid]),
    taobaoApiUrl: firstText([parsed.TAOBAO_API_URL, parsed.taobaoApiUrl]),
    mcdMcpToken: firstText([parsed.MCD_MCP_TOKEN, parsed.mcdMcpToken]),
    mcdMcpUrl: firstText([parsed.MCD_MCP_URL, parsed.mcdMcpUrl]),
    luckinMcpToken: firstText([parsed.LUCKIN_MCP_TOKEN, parsed.luckinMcpToken]),
    luckinMcpUrl: firstText([parsed.LUCKIN_MCP_URL, parsed.luckinMcpUrl]),
    didiMcpKey: firstText([parsed.DIDI_MCP_KEY, parsed.didiMcpKey]),
    didiMcpUrl: firstText([parsed.DIDI_MCP_URL, parsed.didiMcpUrl]),
    didiMcpSandbox: firstText([parsed.DIDI_MCP_SANDBOX, parsed.didiMcpSandbox]),
    amapMcpKey: firstText([parsed.AMAP_MCP_KEY, parsed.amapMcpKey]),
    amapMcpUrl: firstText([parsed.AMAP_MCP_URL, parsed.amapMcpUrl]),
    rideMockEnabled: firstText([parsed.RIDE_MOCK_ENABLED, parsed.rideMockEnabled]),
    whatsappTestTo: firstText([parsed.AIPHONE_WHATSAPP_TEST_TO, parsed.whatsappTestTo]),
    googleMapsApiKey: firstText([parsed.GOOGLE_MAPS_API_KEY, parsed.googleMapsApiKey]),
    googleOauthClientId: firstText([parsed.GOOGLE_OAUTH_CLIENT_ID, parsed.GMAIL_OAUTH_CLIENT_ID, parsed.googleOauthClientId]),
    googleOauthClientSecret: firstText([parsed.GOOGLE_OAUTH_CLIENT_SECRET, parsed.GMAIL_OAUTH_CLIENT_SECRET, parsed.googleOauthClientSecret]),
    googleOauthRedirectUri: firstText([parsed.GOOGLE_OAUTH_REDIRECT_URI, parsed.GMAIL_OAUTH_REDIRECT_URI, parsed.googleOauthRedirectUri]),
    gmailAuthUrl: firstText([parsed.GMAIL_AUTH_URL, parsed.gmailAuthUrl]),
    gmailOauthClientId: firstText([parsed.GMAIL_OAUTH_CLIENT_ID, parsed.GOOGLE_OAUTH_CLIENT_ID, parsed.gmailOauthClientId]),
    gmailOauthClientSecret: firstText([parsed.GMAIL_OAUTH_CLIENT_SECRET, parsed.GOOGLE_OAUTH_CLIENT_SECRET, parsed.gmailOauthClientSecret]),
    gmailOauthRedirectUri: firstText([parsed.GMAIL_OAUTH_REDIRECT_URI, parsed.GOOGLE_OAUTH_REDIRECT_URI, parsed.gmailOauthRedirectUri]),
    gmailMcpUserProject: firstText([parsed.GMAIL_MCP_USER_PROJECT, parsed.GOOGLE_CLOUD_PROJECT, parsed.gmailMcpUserProject]),
    youtubeApiKey: firstText([parsed.YOUTUBE_API_KEY, parsed.youtubeApiKey]),
    zhihuApiKey: firstText([parsed.ZHIHU_API_KEY, parsed.zhihuApiKey]),
    qqMailAddress: firstText([parsed.QQ_MAIL_ADDRESS, parsed.qqMailAddress]),
    qqMailAuthCode: firstText([parsed.QQ_MAIL_AUTH_CODE, parsed.qqMailAuthCode]),
    qqMailImapHost: firstText([parsed.QQ_MAIL_IMAP_HOST, parsed.qqMailImapHost]),
    qqMailImapPort: firstText([parsed.QQ_MAIL_IMAP_PORT, parsed.qqMailImapPort]),
    qqMailDraftsMailbox: firstText([parsed.QQ_MAIL_DRAFTS_MAILBOX, parsed.qqMailDraftsMailbox]),
    paypalClientId: firstText([parsed.PAYPAL_CLIENT_ID, parsed.paypalClientId]),
    paypalClientSecret: firstText([parsed.PAYPAL_CLIENT_SECRET, parsed.paypalClientSecret]),
    paypalEnvironment: firstText([parsed.PAYPAL_ENVIRONMENT, parsed.paypalEnvironment]),
    paypalReturnUrl: firstText([parsed.PAYPAL_RETURN_URL, parsed.paypalReturnUrl]),
    paypalCancelUrl: firstText([parsed.PAYPAL_CANCEL_URL, parsed.paypalCancelUrl]),
    paypalCheckoutGatewayUrl: firstText([parsed.PAYPAL_CHECKOUT_GATEWAY_URL, parsed.paypalCheckoutGatewayUrl]),
    stripeSecretKey: stripeSecretKey,
    stripePublishableKey: firstText([parsed.STRIPE_PUBLISHABLE_KEY, parsed.stripePublishableKey]),
    stripeSuccessUrl: firstText([parsed.STRIPE_SUCCESS_URL, parsed.stripeSuccessUrl]),
    stripeCancelUrl: firstText([parsed.STRIPE_CANCEL_URL, parsed.stripeCancelUrl]),
    stripeCheckoutGatewayUrl: firstText([parsed.STRIPE_CHECKOUT_GATEWAY_URL, parsed.stripeCheckoutGatewayUrl]),
    stripeConnectReturnUrl: firstText([parsed.STRIPE_CONNECT_RETURN_URL, parsed.stripeConnectReturnUrl]),
    stripeConnectRefreshUrl: firstText([parsed.STRIPE_CONNECT_REFRESH_URL, parsed.stripeConnectRefreshUrl]),
    stripeReceivingAgentJson: firstText([parsed.STRIPE_RECEIVING_AGENT_JSON, parsed.stripeReceivingAgentJson]),
    paymentAccountBookJson: firstText([parsed.PAYMENT_ACCOUNT_BOOK_JSON, parsed.paymentAccountBookJson]),
    paymentDefaultCurrency: firstText([parsed.PAYMENT_DEFAULT_CURRENCY, parsed.paymentDefaultCurrency]),
    paymentMode: paymentMode,
    paymentLiveAllowedStripeAccountIds: firstText([parsed.PAYMENT_LIVE_ALLOWED_STRIPE_ACCOUNT_IDS, parsed.paymentLiveAllowedStripeAccountIds]),
    paymentLiveMaxAmountMinor: firstText([parsed.PAYMENT_LIVE_MAX_AMOUNT_MINOR, parsed.paymentLiveMaxAmountMinor])
  });
}

export function localProviderConfigDebugSummary(): string {
  return 'rawfile=' + LOCAL_PROVIDER_CONFIG_RAWFILE +
    ', toolGatewayApiKey=' + (localProviderConfig.toolGatewayApiKey.length > 0 ? 'present(' + localProviderConfig.toolGatewayApiKey.length.toString() + ')' : 'missing') +
    ', flightKey=' + (localProviderConfig.flightMcpKey.length > 0 ? 'present(' + localProviderConfig.flightMcpKey.length.toString() + ')' : 'missing') +
    ', hotelKey=' + (localProviderConfig.hotelMcpKey.length > 0 ? 'present(' + localProviderConfig.hotelMcpKey.length.toString() + ')' : 'missing') +
    ', hotelUrl=' + (localProviderConfig.hotelMcpUrl.length > 0 ? 'present' : 'missing') +
    ', amapKey=' + (localProviderConfig.amapKey.length > 0 ? 'present(' + localProviderConfig.amapKey.length.toString() + ')' : 'missing') +
    ', tencentMapKey=' + (localProviderConfig.tencentMapKey.length > 0 ? 'present(' + localProviderConfig.tencentMapKey.length.toString() + ')' : 'missing') +
    ', baiduMapAk=' + (localProviderConfig.baiduMapAk.length > 0 ? 'present(' + localProviderConfig.baiduMapAk.length.toString() + ')' : 'missing') +
    ', meituanKey=' + (localProviderConfig.meituanUnionAppKey.length > 0 ? 'present(' + localProviderConfig.meituanUnionAppKey.length.toString() + ')' : 'missing') +
    ', taobaoKey=' + (localProviderConfig.taobaoAppKey.length > 0 ? 'present(' + localProviderConfig.taobaoAppKey.length.toString() + ')' : 'missing') +
    ', taobaoPid=' + (localProviderConfig.taobaoFlashPid.length > 0 ? 'present(' + localProviderConfig.taobaoFlashPid.length.toString() + ')' : 'missing') +
    ', mcdMcpToken=' + (localProviderConfig.mcdMcpToken.length > 0 ? 'present(' + localProviderConfig.mcdMcpToken.length.toString() + ')' : 'missing') +
    ', luckinMcpToken=' + (localProviderConfig.luckinMcpToken.length > 0 ? 'present(' + localProviderConfig.luckinMcpToken.length.toString() + ')' : 'missing') +
    ', didiMcpKey=' + (localProviderConfig.didiMcpKey.length > 0 ? 'present(' + localProviderConfig.didiMcpKey.length.toString() + ')' : 'missing') +
    ', didiMcpUrl=' + (localProviderConfig.didiMcpUrl.length > 0 ? 'present' : 'missing') +
    ', didiMcpSandbox=' + localProviderConfig.didiMcpSandbox +
    ', amapMcpKey=' + (localProviderConfig.amapMcpKey.length > 0 ? 'present(' + localProviderConfig.amapMcpKey.length.toString() + ')' : 'missing') +
    ', amapMcpUrl=' + (localProviderConfig.amapMcpUrl.length > 0 ? 'present' : 'missing') +
    ', rideMockEnabled=' + localProviderConfig.rideMockEnabled +
    ', whatsappTestTo=' + (localProviderConfig.whatsappTestTo.length > 0 ? 'present' : 'missing') +
    ', googleMapsApiKey=' + (localProviderConfig.googleMapsApiKey.length > 0 ? 'present(' + localProviderConfig.googleMapsApiKey.length.toString() + ')' : 'missing') +
    ', googleOauthClientId=' + (localProviderConfig.googleOauthClientId.length > 0 ? 'present(' + localProviderConfig.googleOauthClientId.length.toString() + ')' : 'missing') +
    ', gmailOauthClientId=' + (localProviderConfig.gmailOauthClientId.length > 0 ? 'present(' + localProviderConfig.gmailOauthClientId.length.toString() + ')' : 'missing') +
    ', gmailOauthClientSecret=' + (localProviderConfig.gmailOauthClientSecret.length > 0 ? 'present(' + localProviderConfig.gmailOauthClientSecret.length.toString() + ')' : 'missing') +
    ', youtubeApiKey=' + (localProviderConfig.youtubeApiKey.length > 0 ? 'present(' + localProviderConfig.youtubeApiKey.length.toString() + ')' : 'missing') +
    ', zhihuApiKey=' + (localProviderConfig.zhihuApiKey.length > 0 ? 'present(' + localProviderConfig.zhihuApiKey.length.toString() + ')' : 'missing') +
    ', gmailMcpUserProject=' + (localProviderConfig.gmailMcpUserProject.length > 0 ? 'present' : 'missing') +
    ', qqMailAddress=' + (localProviderConfig.qqMailAddress.length > 0 ? 'present' : 'missing') +
    ', qqMailAuthCode=' + (localProviderConfig.qqMailAuthCode.length > 0 ? 'present(' + localProviderConfig.qqMailAuthCode.length.toString() + ')' : 'missing') +
    ', qqMailImapHost=' + (localProviderConfig.qqMailImapHost.length > 0 ? 'present' : 'missing') +
    ', qqMailDraftsMailbox=' + (localProviderConfig.qqMailDraftsMailbox.length > 0 ? 'present' : 'missing') +
    ', paypalClientId=' + (localProviderConfig.paypalClientId.length > 0 ? 'present(' + localProviderConfig.paypalClientId.length.toString() + ')' : 'missing') +
    ', paypalClientSecret=' + (localProviderConfig.paypalClientSecret.length > 0 ? 'present(' + localProviderConfig.paypalClientSecret.length.toString() + ')' : 'missing') +
    ', paypalEnvironment=' + localProviderConfig.paypalEnvironment +
    ', paypalCheckoutGatewayUrl=' + (localProviderConfig.paypalCheckoutGatewayUrl.length > 0 ? 'present' : 'missing') +
    ', stripeSecretKey=' + (localProviderConfig.stripeSecretKey.length > 0 ? 'present(' + localProviderConfig.stripeSecretKey.length.toString() + ')' : 'missing') +
    ', stripePublishableKey=' + (localProviderConfig.stripePublishableKey.length > 0 ? 'present(' + localProviderConfig.stripePublishableKey.length.toString() + ')' : 'missing') +
    ', stripeCheckoutGatewayUrl=' + (localProviderConfig.stripeCheckoutGatewayUrl.length > 0 ? 'present' : 'missing') +
    ', stripeConnectReturnUrl=' + (localProviderConfig.stripeConnectReturnUrl.length > 0 ? 'present' : 'missing') +
    ', stripeReceivingAgentJson=' + (localProviderConfig.stripeReceivingAgentJson.length > 0 ? 'present(' + localProviderConfig.stripeReceivingAgentJson.length.toString() + ')' : 'missing') +
    ', paymentAccountBookJson=' + (localProviderConfig.paymentAccountBookJson.length > 0 ? 'present' : 'missing') +
    ', paymentMode=' + localProviderConfig.paymentMode +
    ', paymentLiveAllowedStripeAccountIds=' + (localProviderConfig.paymentLiveAllowedStripeAccountIds.length > 0 ? 'present' : 'missing') +
    ', paymentLiveMaxAmountMinor=' + localProviderConfig.paymentLiveMaxAmountMinor +
    ', defaultLocation=' + (localProviderConfig.amapDefaultLocation.length > 0 ? 'present' : 'missing');
}

interface StripeConnectAccountIdRequest {
  stripeAccountId: string;
}

type StripeConnectAccountCreator = (secretKey: string, body: Object) => Promise<StripeConnectAccountResult>;
type StripeConnectOnboardingLinkCreator = (secretKey: string, body: Object, returnUrl: string, refreshUrl: string) => Promise<StripeConnectOnboardingLinkResult>;
type StripeConnectStatusFetcher = (secretKey: string, body: Object) => Promise<StripeConnectStatusResult>;

let stripeConnectAccountCreator: StripeConnectAccountCreator = createStripeConnectAccount;
let stripeConnectOnboardingLinkCreator: StripeConnectOnboardingLinkCreator = createStripeConnectOnboardingLink;
let stripeConnectStatusFetcher: StripeConnectStatusFetcher = fetchStripeConnectStatus;

export function configureStripeConnectClientForTests(
  accountCreator: StripeConnectAccountCreator | null,
  onboardingLinkCreator: StripeConnectOnboardingLinkCreator | null,
  statusFetcher: StripeConnectStatusFetcher | null
): void {
  stripeConnectAccountCreator = accountCreator === null ? createStripeConnectAccount : accountCreator;
  stripeConnectOnboardingLinkCreator = onboardingLinkCreator === null ? createStripeConnectOnboardingLink : onboardingLinkCreator;
  stripeConnectStatusFetcher = statusFetcher === null ? fetchStripeConnectStatus : statusFetcher;
}

function textOf(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

function pad2(value: number): string {
  if (value < 10) {
    return '0' + value.toString();
  }
  return value.toString();
}

function normalizeTrainStationName(name: string, source: string): string {
  if (!/高铁|动车|\bG\d+|\bD\d+/i.test(source)) {
    return name;
  }
  for (let index = 0; index < HIGH_SPEED_DEFAULT_STATIONS.length; index++) {
    const item = HIGH_SPEED_DEFAULT_STATIONS[index];
    if (item.city === name) {
      return item.station;
    }
  }
  return name;
}

function stationCodeFor(name: string, stations: StationCache): string {
  for (let index = 0; index < stations.entries.length; index++) {
    const item = stations.entries[index];
    if (item.name === name) {
      return item.code;
    }
  }
  return '';
}

function stationNameForCode(code: string, stations: StationCache): string {
  for (let index = 0; index < stations.entries.length; index++) {
    const item = stations.entries[index];
    if (item.code === code) {
      return item.name;
    }
  }
  return code;
}

function findCandidateInRoutePart(part: string, candidates: string[], preferLast: boolean): string {
  let selected = '';
  let selectedIndex = preferLast ? -1 : 999999;
  for (let index = 0; index < candidates.length; index++) {
    const candidate = candidates[index];
    const foundAt = part.indexOf(candidate);
    if (foundAt < 0) {
      continue;
    }
    if (selected.length === 0) {
      selected = candidate;
      selectedIndex = foundAt;
      continue;
    }
    if (preferLast && foundAt > selectedIndex) {
      selected = candidate;
      selectedIndex = foundAt;
      continue;
    }
    if (!preferLast && foundAt < selectedIndex) {
      selected = candidate;
      selectedIndex = foundAt;
      continue;
    }
    if (foundAt === selectedIndex && candidate.length > selected.length) {
      selected = candidate;
    }
  }
  return selected;
}

function extractRouteNames(source: string, candidates: string[]): string[] {
  const departRoute = /(?:从)?([\u4e00-\u9fa5]{2,12})\s*出发\s*(?:到|去|至)\s*([\u4e00-\u9fa5]{2,12})/.exec(source);
  if (departRoute !== null) {
    const fromCandidate = findCandidateInRoutePart(departRoute[1], candidates, true);
    const toCandidate = findCandidateInRoutePart(departRoute[2], candidates, false);
    if (fromCandidate.length > 0 && toCandidate.length > 0) {
      return [fromCandidate, toCandidate];
    }
  }

  const stationRoute = /([\u4e00-\u9fa5]{2,12})站\s*(?:到|去|至)\s*([\u4e00-\u9fa5]{2,12})站/.exec(source);
  if (stationRoute !== null) {
    const fromCandidate = findCandidateInRoutePart(stationRoute[1], candidates, true);
    const toCandidate = findCandidateInRoutePart(stationRoute[2], candidates, false);
    if (fromCandidate.length > 0 && toCandidate.length > 0) {
      return [fromCandidate, toCandidate];
    }
  }

  const direct = /([\u4e00-\u9fa5]{2,12})\s*(?:到|去|至|飞)\s*([\u4e00-\u9fa5]{2,12})/.exec(source);
  if (direct !== null) {
    const fromCandidate = findCandidateInRoutePart(direct[1], candidates, true);
    const toCandidate = findCandidateInRoutePart(direct[2], candidates, false);
    if (fromCandidate.length > 0 && toCandidate.length > 0) {
      return [fromCandidate, toCandidate];
    }
  }

  const matched: string[] = [];
  for (let index = 0; index < candidates.length; index++) {
    const name = candidates[index];
    if (source.includes(name) && matched.indexOf(name) < 0) {
      matched.push(name);
    }
    if (matched.length >= 2) {
      break;
    }
  }
  return matched;
}

function describeThrown(error: Error | Object | string | number | boolean | null | undefined): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string') {
    return error;
  }
  return JSON.stringify(error);
}

async function requestText(url: string, headers: HttpRequestHeaders): Promise<HttpTextResponse> {
  const request = http.createHttp();
  const decoder = util.TextDecoder.create('utf-8');
  try {
    const response = await request.request(url, {
      method: http.RequestMethod.GET,
      header: headers,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 30000
    });
    let text = '';
    if (typeof response.result === 'string') {
      text = response.result;
    } else {
      text = decoder.decodeToString(new Uint8Array(response.result as ArrayBuffer));
    }
    return {
      code: response.responseCode,
      text: text,
      cookies: response.cookies === undefined ? '' : response.cookies,
      headers: JSON.stringify(response.header)
    };
  } catch (error) {
    throw new Error('GET ' + url + ' failed: ' + describeThrown(error));
  } finally {
    request.destroy();
  }
}

async function postJsonText(url: string, headers: HttpRequestHeaders, body: string): Promise<HttpTextResponse> {
  const request = http.createHttp();
  const decoder = util.TextDecoder.create('utf-8');
  try {
    const response = await request.request(url, {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: body,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 30000
    });
    let text = '';
    if (typeof response.result === 'string') {
      text = response.result;
    } else {
      text = decoder.decodeToString(new Uint8Array(response.result as ArrayBuffer));
    }
    return {
      code: response.responseCode,
      text: text,
      cookies: response.cookies === undefined ? '' : response.cookies,
      headers: JSON.stringify(response.header)
    };
  } catch (error) {
    throw new Error('POST ' + url + ' failed: ' + describeThrown(error));
  } finally {
    request.destroy();
  }
}

function buildQueryUrl(baseUrl: string, keys: string[], values: string[]): string {
  let query = '';
  for (let index = 0; index < keys.length && index < values.length; index++) {
    const value = values[index];
    if (value.length === 0) {
      continue;
    }
    query += (query.length === 0 ? '?' : '&') + encodeURIComponent(keys[index]) + '=' + encodeURIComponent(value);
  }
  return baseUrl + query;
}

function utf8Bytes(value: string): number[] {
  const bytes: number[] = [];
  for (let index = 0; index < value.length; index++) {
    let code = value.charCodeAt(index);
    if (code >= 0xd800 && code <= 0xdbff && index + 1 < value.length) {
      const next = value.charCodeAt(index + 1);
      if (next >= 0xdc00 && next <= 0xdfff) {
        code = 0x10000 + ((code - 0xd800) << 10) + (next - 0xdc00);
        index++;
      }
    }
    if (code < 0x80) {
      bytes.push(code);
    } else if (code < 0x800) {
      bytes.push(0xc0 | (code >> 6));
      bytes.push(0x80 | (code & 0x3f));
    } else if (code < 0x10000) {
      bytes.push(0xe0 | (code >> 12));
      bytes.push(0x80 | ((code >> 6) & 0x3f));
      bytes.push(0x80 | (code & 0x3f));
    } else {
      bytes.push(0xf0 | (code >> 18));
      bytes.push(0x80 | ((code >> 12) & 0x3f));
      bytes.push(0x80 | ((code >> 6) & 0x3f));
      bytes.push(0x80 | (code & 0x3f));
    }
  }
  return bytes;
}

function add32(left: number, right: number): number {
  return (left + right) | 0;
}

function rotateLeft(value: number, bits: number): number {
  return (value << bits) | (value >>> (32 - bits));
}

function md5DigestBytes(value: string): number[] {
  const message = utf8Bytes(value);
  const originalLength = message.length;
  message.push(0x80);
  while ((message.length % 64) !== 56) {
    message.push(0);
  }
  const bitLow = (originalLength * 8) >>> 0;
  const bitHigh = Math.floor(originalLength / 0x20000000) >>> 0;
  for (let index = 0; index < 4; index++) {
    message.push((bitLow >>> (index * 8)) & 0xff);
  }
  for (let index = 0; index < 4; index++) {
    message.push((bitHigh >>> (index * 8)) & 0xff);
  }

  const shifts: number[] = [
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
  ];
  const constants: number[] = [];
  for (let index = 0; index < 64; index++) {
    constants.push(Math.floor(Math.abs(Math.sin(index + 1)) * 4294967296) | 0);
  }

  let a0 = 0x67452301;
  let b0 = 0xefcdab89 | 0;
  let c0 = 0x98badcfe | 0;
  let d0 = 0x10325476;

  for (let offset = 0; offset < message.length; offset += 64) {
    const words: number[] = [];
    for (let wordIndex = 0; wordIndex < 16; wordIndex++) {
      const base = offset + wordIndex * 4;
      words.push((message[base] | (message[base + 1] << 8) | (message[base + 2] << 16) | (message[base + 3] << 24)) | 0);
    }

    let a = a0;
    let b = b0;
    let c = c0;
    let d = d0;

    for (let index = 0; index < 64; index++) {
      let f = 0;
      let g = 0;
      if (index < 16) {
        f = (b & c) | ((~b) & d);
        g = index;
      } else if (index < 32) {
        f = (d & b) | ((~d) & c);
        g = (5 * index + 1) % 16;
      } else if (index < 48) {
        f = b ^ c ^ d;
        g = (3 * index + 5) % 16;
      } else {
        f = c ^ (b | (~d));
        g = (7 * index) % 16;
      }
      const previousD = d;
      d = c;
      c = b;
      const rotated = rotateLeft(add32(add32(a, f), add32(constants[index], words[g])), shifts[index]);
      b = add32(b, rotated);
      a = previousD;
    }

    a0 = add32(a0, a);
    b0 = add32(b0, b);
    c0 = add32(c0, c);
    d0 = add32(d0, d);
  }

  const digest: number[] = [];
  const words = [a0, b0, c0, d0];
  for (let wordIndex = 0; wordIndex < words.length; wordIndex++) {
    for (let byteIndex = 0; byteIndex < 4; byteIndex++) {
      digest.push((words[wordIndex] >>> (byteIndex * 8)) & 0xff);
    }
  }
  return digest;
}

function byteHex(value: number): string {
  const digits = '0123456789abcdef';
  return digits.charAt((value >>> 4) & 0x0f) + digits.charAt(value & 0x0f);
}

function md5Hex(value: string): string {
  const digest = md5DigestBytes(value);
  let result = '';
  for (let index = 0; index < digest.length; index++) {
    result += byteHex(digest[index]);
  }
  return result;
}

function bytesToBase64(bytes: number[]): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let result = '';
  for (let index = 0; index < bytes.length; index += 3) {
    const first = bytes[index];
    const second = index + 1 < bytes.length ? bytes[index + 1] : 0;
    const third = index + 2 < bytes.length ? bytes[index + 2] : 0;
    const triple = (first << 16) | (second << 8) | third;
    result += alphabet.charAt((triple >> 18) & 0x3f);
    result += alphabet.charAt((triple >> 12) & 0x3f);
    result += index + 1 < bytes.length ? alphabet.charAt((triple >> 6) & 0x3f) : '=';
    result += index + 2 < bytes.length ? alphabet.charAt(triple & 0x3f) : '=';
  }
  return result;
}

function md5Base64(value: string): string {
  return bytesToBase64(md5DigestBytes(value));
}

function sortedParamPairs(pairs: FoodParamPair[]): FoodParamPair[] {
  const next: FoodParamPair[] = [];
  for (let index = 0; index < pairs.length; index++) {
    next.push({ key: pairs[index].key, value: pairs[index].value });
  }
  next.sort((left: FoodParamPair, right: FoodParamPair): number => {
    if (left.key < right.key) {
      return -1;
    }
    if (left.key > right.key) {
      return 1;
    }
    return 0;
  });
  return next;
}

function topMd5Sign(pairs: FoodParamPair[], appSecret: string): string {
  const sorted = sortedParamPairs(pairs);
  let source = appSecret;
  for (let index = 0; index < sorted.length; index++) {
    if (sorted[index].key === 'sign' || sorted[index].value.length === 0) {
      continue;
    }
    source += sorted[index].key + sorted[index].value;
  }
  source += appSecret;
  return md5Hex(source).toUpperCase();
}

function encodeForm(pairs: FoodParamPair[]): string {
  let body = '';
  for (let index = 0; index < pairs.length; index++) {
    if (body.length > 0) {
      body += '&';
    }
    body += encodeURIComponent(pairs[index].key) + '=' + encodeURIComponent(pairs[index].value);
  }
  return body;
}

function formatTopTimestamp(date: Date): string {
  return date.getFullYear().toString() + '-' + pad2(date.getMonth() + 1) + '-' + pad2(date.getDate()) + ' ' +
    pad2(date.getHours()) + ':' + pad2(date.getMinutes()) + ':' + pad2(date.getSeconds());
}

function locationLongitude(location: string): string {
  const parts = location.split(',');
  return parts.length > 0 ? parts[0].trim() : '';
}

function locationLatitude(location: string): string {
  const parts = location.split(',');
  return parts.length > 1 ? parts[1].trim() : '';
}

function coordinateToMicros(value: string): string {
  const numeric = Number(value);
  if (isNaN(numeric)) {
    return '';
  }
  return Math.round(numeric * 1000000).toString();
}

function meituanUnionSignature(appSecret: string, appKey: string, timestamp: string, contentMd5: string, body: string): string {
  const source = appSecret +
    'Content-MD5' + contentMd5 +
    'S-Ca-App' + appKey +
    'S-Ca-Timestamp' + timestamp +
    body +
    appSecret;
  return md5Hex(source).toUpperCase();
}

function postFormText(url: string, headers: HttpRequestHeaders, body: string): Promise<HttpTextResponse> {
  return postJsonText(url, headers, body);
}

export function isTransientPayPalRequestErrorForTest(message: string): boolean {
  const lower = message.toLowerCase();
  return lower.indexOf('failed to resolve') >= 0 ||
    lower.indexOf('resolve the host name') >= 0 ||
    lower.indexOf('operation timeout') >= 0 ||
    lower.indexOf('timed out') >= 0 ||
    lower.indexOf('internal error') >= 0 ||
    lower.indexOf('2300028') >= 0 ||
    lower.indexOf('2300999') >= 0;
}

export function payPalApiFallbackUrlForTest(url: string): string {
  if (url.startsWith('https://api-m.paypal.com/')) {
    return 'https://api.paypal.com/' + url.substring('https://api-m.paypal.com/'.length);
  }
  if (url.startsWith('https://api-m.sandbox.paypal.com/')) {
    return 'https://api.sandbox.paypal.com/' + url.substring('https://api-m.sandbox.paypal.com/'.length);
  }
  return '';
}

async function postPayPalTextWithRetry(action: string, url: string, headers: HttpRequestHeaders, body: string): Promise<HttpTextResponse> {
  let lastError = '';
  const fallbackUrl = payPalApiFallbackUrlForTest(url);
  for (let attempt = 0; attempt < 3; attempt++) {
    const requestUrl = attempt > 0 && fallbackUrl.length > 0 ? fallbackUrl : url;
    try {
      return await postJsonText(requestUrl, headers, body);
    } catch (error) {
      lastError = describeThrown(error);
      if (!isTransientPayPalRequestErrorForTest(lastError) || attempt >= 2) {
        const suffix = attempt >= 2 ? ' failed after 3 attempts: ' : ' failed: ';
        throw new Error(action + suffix + lastError);
      }
      aiLogInfo('[AIPhone][PayPalHttpRetry] action=' + action +
        ' attempt=' + (attempt + 2).toString() +
        ' fallback=' + (requestUrl !== url ? 'true' : 'false') +
        ' reason=' + lastError.substring(0, 160));
      await waitForDebugDelay(500 * (attempt + 1));
    }
  }
  throw new Error(action + ' failed after 3 attempts: ' + lastError);
}

function mcpHeaders(token: string, sessionId: string = ''): HttpRequestHeaders {
  if (sessionId.length > 0) {
    return {
      'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1',
      'Accept': 'application/json, text/event-stream',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + token,
      'MCP-Protocol-Version': MCP_PROTOCOL_VERSION,
      'Mcp-Session-Id': sessionId
    };
  }
  return {
    'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1',
    'Accept': 'application/json, text/event-stream',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ' + token,
    'MCP-Protocol-Version': MCP_PROTOCOL_VERSION
  };
}

function escapeRegexLiteral(value: string): string {
  const specials = '\\^$.*+?()[]{}|';
  let escaped = '';
  for (let index = 0; index < value.length; index++) {
    const char = value.charAt(index);
    if (specials.indexOf(char) >= 0) {
      escaped += '\\';
    }
    escaped += char;
  }
  return escaped;
}

function jsonTextUnescape(value: string): string {
  return value.replace(/\\"/g, '"').replace(/\\\\/g, '\\');
}

function headerValueFromJson(headersJson: string, wantedKey: string): string {
  const key = escapeRegexLiteral(wantedKey);
  const arrayPattern = new RegExp('"' + key + '"\\s*:\\s*\\[\\s*"([^"]*)"', 'i');
  const arrayMatch = arrayPattern.exec(headersJson);
  if (arrayMatch !== null && arrayMatch.length > 1) {
    return jsonTextUnescape(arrayMatch[1]);
  }
  const stringPattern = new RegExp('"' + key + '"\\s*:\\s*"([^"]*)"', 'i');
  const stringMatch = stringPattern.exec(headersJson);
  if (stringMatch !== null && stringMatch.length > 1) {
    return jsonTextUnescape(stringMatch[1]);
  }
  const primitivePattern = new RegExp('"' + key + '"\\s*:\\s*([^,}\\]]+)', 'i');
  const primitiveMatch = primitivePattern.exec(headersJson);
  if (primitiveMatch !== null && primitiveMatch.length > 1) {
    return primitiveMatch[1].trim();
  }
  return '';
}

function parseMcpJsonRpcText(text: string): McpJsonRpcResponse {
  const trimmed = text.trim();
  if (trimmed.length === 0) {
    return {};
  }
  if (trimmed.startsWith('{')) {
    return JSON.parse(trimmed) as McpJsonRpcResponse;
  }
  if (trimmed.startsWith('[')) {
    const responses = JSON.parse(trimmed) as McpJsonRpcResponse[];
    return responses.length > 0 ? responses[responses.length - 1] : {};
  }
  const lines = trimmed.split(/\r?\n/);
  for (let index = lines.length - 1; index >= 0; index--) {
    const line = lines[index].trim();
    if (!line.startsWith('data:')) {
      continue;
    }
    const data = line.substring('data:'.length).trim();
    if (data.length === 0 || data === '[DONE]') {
      continue;
    }
    return JSON.parse(data) as McpJsonRpcResponse;
  }
  return {};
}

function firstJsonSlice(text: string): string {
  const trimmed = text.trim();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return trimmed;
  }
  const objectStart = trimmed.indexOf('{');
  const objectEnd = trimmed.lastIndexOf('}');
  if (objectStart >= 0 && objectEnd > objectStart) {
    return trimmed.substring(objectStart, objectEnd + 1);
  }
  const arrayStart = trimmed.indexOf('[');
  const arrayEnd = trimmed.lastIndexOf(']');
  if (arrayStart >= 0 && arrayEnd > arrayStart) {
    return trimmed.substring(arrayStart, arrayEnd + 1);
  }
  return '';
}

function mcpToolPayloadFromText(text: string): Object {
  const response = parseMcpJsonRpcText(text);
  if (response.error !== undefined) {
    throw new Error(firstText([response.error.message, response.error.code, response.error.data, 'MCP JSON-RPC error']));
  }
  const result = response.result;
  if (result === undefined || result === null) {
    throw new Error('MCP 返回中没有 result。');
  }
  if (result.isError === true) {
    const errorParts: string[] = [];
    const errorContent = result.content === undefined ? [] : result.content;
    for (let index = 0; index < errorContent.length; index++) {
      const item = errorContent[index];
      const itemText = firstText([item.text, item.data]).trim();
      if (itemText.length > 0) {
        errorParts.push(itemText);
      }
    }
    throw new Error(errorParts.length > 0 ? errorParts.join('；').substring(0, 300) : 'MCP 工具返回错误状态。');
  }
  if (result.structuredContent !== undefined && result.structuredContent !== null) {
    return result.structuredContent;
  }
  const content = result.content === undefined ? [] : result.content;
  for (let index = 0; index < content.length; index++) {
    const item = content[index];
    if (item.data !== undefined && item.data !== null && typeof item.data === 'object') {
      return item.data as Object;
    }
    const textValue = textOf(item.text).trim();
    const jsonSlice = firstJsonSlice(textValue);
    if (jsonSlice.length > 0) {
      return JSON.parse(jsonSlice) as Object;
    }
    if (textValue.length > 0) {
      return JSON.parse('{"text":' + JSON.stringify(textValue) + '}') as Object;
    }
  }
  throw new Error('MCP 工具没有返回可解析的结构化 JSON。');
}

export function isReadonlyBrandMcpTool(provider: string, toolName: string): boolean {
  if (provider === '麦当劳') {
    return [
      'list-nutrition-foods',
      'delivery-query-addresses',
      'delivery-query-stores',
      'query-meal-assistance',
      'query-nearby-stores',
      'query-store-coupons',
      'query-meals',
      'query-meal-detail',
      'calculate-price',
      'query-order',
      'campaign-calendar',
      'available-coupons',
      'query-my-coupons',
      'query-my-account',
      'mall-points-products',
      'mall-product-detail',
      'mall-order-list',
      'mall-order-detail',
      'now-time-info'
    ].indexOf(toolName) >= 0;
  }
  if (provider === '瑞幸') {
    return [
      'queryShopList',
      'searchProductForMcp',
      'queryProductDetailInfo',
      'switchProduct',
      'previewOrder',
      'createOrder',
      'queryOrderDetailInfo'
    ].indexOf(toolName) >= 0;
  }
  return false;
}

function brandMcpHttpError(provider: string, phase: string, code: number, text: string): string {
  const detail = text.substring(0, 300);
  if (provider === '瑞幸' && detail.toLowerCase().indexOf('missing csrf token') >= 0) {
    return provider + ' MCP ' + phase + ' HTTP ' + code.toString() + '：服务端要求 CSRF/session 授权；请确认 LUCKIN_MCP_URL 指向 https://gwmcp.lkcoffee.com/order/user/mcp，而不是开放平台官网页面：' + detail;
  }
  return provider + ' MCP ' + phase + ' HTTP ' + code.toString() + '：' + detail;
}

async function callReadonlyBrandMcpTool(provider: string, url: string, token: string, toolName: string, args: Object): Promise<Object> {
  if (!isReadonlyBrandMcpTool(provider, toolName)) {
    throw new Error(provider + ' MCP 工具 ' + toolName + ' 不在只读查询白名单内。');
  }
  const initRequest = buildInitializeRequest(1);
  const initBody = JSON.stringify(initRequest);
  const init = await postJsonText(url, mcpHeaders(token), initBody);
  if (init.code < 200 || init.code >= 300) {
    throw new Error(brandMcpHttpError(provider, 'initialize', init.code, init.text));
  }
  let initParsed: McpJsonRpcResponse = {};
  try {
    initParsed = parseMcpJsonRpcText(init.text);
  } catch (error) {
    throw new Error(provider + ' MCP initialize 返回格式异常：' + describeThrown(error));
  }
  if (initParsed.error !== undefined) {
    throw new Error(provider + ' MCP initialize 返回错误：' + firstText([initParsed.error.message, initParsed.error.code, initParsed.error.data, 'MCP initialize error']));
  }
  const sessionId = headerValueFromJson(init.headers, 'mcp-session-id');
  if (sessionId.length > 0) {
    try {
      const initializedNotification: McpInitializedNotification = {
        jsonrpc: '2.0',
        method: 'notifications/initialized'
      };
      await postJsonText(url, mcpHeaders(token, sessionId), JSON.stringify(initializedNotification));
    } catch (error) {
      aiLogInfo('[AIPhone][BrandMcpInitializedIgnored] provider=' + provider + ' error=' + describeThrown(error));
    }
  }
  const callRequest = buildToolsCallRequest(2, toolName, args);
  const callBody = JSON.stringify(callRequest);
  aiLogInfo('[AIPhone][BrandMcpRequest] provider=' + provider + ' tool=' + toolName + ' url=' + url + ' bodyChars=' + callBody.length.toString());
  const response = await postJsonText(url, mcpHeaders(token, sessionId), callBody);
  if (response.code < 200 || response.code >= 300) {
    throw new Error(brandMcpHttpError(provider, toolName, response.code, response.text));
  }
  return mcpToolPayloadFromText(response.text);
}

function rideMcpHeaders(sessionId: string = ''): HttpRequestHeaders {
  if (sessionId.length > 0) {
    return {
      'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1',
      'Accept': 'application/json, text/event-stream',
      'Content-Type': 'application/json',
      'MCP-Protocol-Version': MCP_PROTOCOL_VERSION,
      'Mcp-Session-Id': sessionId
    };
  }
  const headers: HttpRequestHeaders = {
    'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1',
    'Accept': 'application/json, text/event-stream',
    'Content-Type': 'application/json',
    'MCP-Protocol-Version': MCP_PROTOCOL_VERSION
  };
  return headers;
}

function rideMcpUrlWithKey(baseUrl: string, key: string): string {
  const trimmed = baseUrl.trim();
  if (trimmed.indexOf('{key}') >= 0) {
    return trimmed.replace('{key}', encodeURIComponent(key));
  }
  if (trimmed.indexOf('YOUR_MCP_KEY') >= 0) {
    return trimmed.replace('YOUR_MCP_KEY', encodeURIComponent(key));
  }
  if (trimmed.indexOf('key=') >= 0) {
    return trimmed;
  }
  return trimmed + (trimmed.indexOf('?') >= 0 ? '&' : '?') + 'key=' + encodeURIComponent(key);
}

function isAllowedRideMcpTool(provider: string, toolName: string): boolean {
  if (provider === '滴滴') {
    return ['maps_textsearch', 'taxi_estimate', 'taxi_generate_ride_app_link', 'taxi_create_order', 'taxi_cancel_order', 'taxi_get_driver_location'].indexOf(toolName) >= 0;
  }
  if (provider === '高德') {
    const lower = toolName.toLowerCase();
    return lower.indexOf('taxi') >= 0 || lower.indexOf('ride') >= 0 || toolName.indexOf('打车') >= 0;
  }
  return false;
}

async function rideMcpToolNames(url: string): Promise<DynamicMcpTool[]> {
  const registration = rideMcpRegistration('ride.tools.list', '打车 MCP', url, 'tools/list');
  const preflight = await new GenericMcpClient().preflight(registration, '');
  return preflight.ok ? preflight.tools : [];
}

async function selectRideMcpToolName(provider: string, url: string, fallbackNames: string[], needles: string[]): Promise<string> {
  let tools: DynamicMcpTool[] = [];
  try {
    tools = await rideMcpToolNames(url);
  } catch (error) {
    aiLogInfo('[AIPhone][RideMcpToolsListIgnored] provider=' + provider + ' error=' + describeThrown(error));
  }
  for (let fallbackIndex = 0; fallbackIndex < fallbackNames.length; fallbackIndex++) {
    for (let toolIndex = 0; toolIndex < tools.length; toolIndex++) {
      if (tools[toolIndex].name === fallbackNames[fallbackIndex]) {
        return fallbackNames[fallbackIndex];
      }
    }
  }
  for (let toolIndex = 0; toolIndex < tools.length; toolIndex++) {
    const haystack = (tools[toolIndex].name + ' ' + tools[toolIndex].description).toLowerCase();
    for (let needleIndex = 0; needleIndex < needles.length; needleIndex++) {
      if (haystack.indexOf(needles[needleIndex].toLowerCase()) >= 0) {
        return tools[toolIndex].name;
      }
    }
  }
  return fallbackNames.length > 0 ? fallbackNames[0] : '';
}

function rideMcpRegistration(toolId: string, displayName: string, url: string, toolName: string): DynamicToolRegistration {
  return {
    toolId: toolId,
    manifestId: 'ride.mcp',
    displayName: displayName,
    status: 'enabled',
    transport: {
      type: 'streamable_http',
      url: url,
      command: '',
      args: [],
      headers: {},
      env: {}
    },
    mcpToolName: toolName,
    credentialRef: '',
    sourceUrl: url,
    lastError: ''
  };
}

async function callRideMcpTool(provider: string, url: string, toolName: string, args: Object): Promise<Object> {
  if (!isAllowedRideMcpTool(provider, toolName)) {
    throw new Error(provider + ' MCP 工具 ' + toolName + ' 不在打车只读/唤端白名单内。');
  }
  const initRequest = buildInitializeRequest(1);
  const init = await postJsonText(url, rideMcpHeaders(), JSON.stringify(initRequest));
  if (init.code < 200 || init.code >= 300) {
    throw new Error(provider + ' MCP initialize HTTP ' + init.code.toString() + '：' + init.text.substring(0, 300));
  }
  const initParsed = parseMcpJsonRpcText(init.text);
  if (initParsed.error !== undefined) {
    throw new Error(provider + ' MCP initialize 返回错误：' + firstText([initParsed.error.message, initParsed.error.code, initParsed.error.data, 'MCP initialize error']));
  }
  const sessionId = headerValueFromJson(init.headers, 'mcp-session-id');
  if (sessionId.length > 0) {
    try {
      const initializedNotification: McpInitializedNotification = {
        jsonrpc: '2.0',
        method: 'notifications/initialized'
      };
      await postJsonText(url, rideMcpHeaders(sessionId), JSON.stringify(initializedNotification));
    } catch (error) {
      aiLogInfo('[AIPhone][RideMcpInitializedIgnored] provider=' + provider + ' error=' + describeThrown(error));
    }
  }
  const callRequest = buildToolsCallRequest(2, toolName, args);
  const callBody = JSON.stringify(callRequest);
  aiLogInfo('[AIPhone][RideMcpRequest] provider=' + provider + ' tool=' + toolName + ' urlChars=' + url.length.toString() + ' bodyChars=' + callBody.length.toString());
  const response = await postJsonText(url, rideMcpHeaders(sessionId), callBody);
  if (response.code < 200 || response.code >= 300) {
    throw new Error(provider + ' MCP ' + toolName + ' HTTP ' + response.code.toString() + '：' + response.text.substring(0, 300));
  }
  return mcpToolPayloadFromText(response.text);
}

interface RideRoute {
  origin: string;
  destination: string;
  city: string;
}

interface RidePoint {
  name: string;
  lng: string;
  lat: string;
  location: string;
  city: string;
}

interface RideProduct {
  productName: string;
  productCategory: string;
  priceText: string;
}

function rideArgs(args: Object | null): RideRouteArgs {
  if (args === null) {
    return JSON.parse('{}') as RideRouteArgs;
  }
  return args as RideRouteArgs;
}

function rideArgText(args: RideRouteArgs, keys: string[]): string {
  const record = args as PaymentToolArgRecord;
  for (let index = 0; index < keys.length; index++) {
    const value = textOf(record[keys[index]]).trim();
    if (value.length > 0) {
      return value;
    }
  }
  return '';
}

function rideRouteFromArgs(args: Object | null): RideRoute {
  const parsed = rideArgs(args);
  const origin = rideArgText(parsed, ['origin', 'from', 'start']);
  const destination = rideArgText(parsed, ['destination', 'to', 'end']);
  const city = rideArgText(parsed, ['city']);
  return {
    origin: origin,
    destination: destination,
    city: city
  };
}

function rideOrderArgs(args: Object | null): RideOrderArgs {
  if (args === null) {
    return JSON.parse('{}') as RideOrderArgs;
  }
  return args as RideOrderArgs;
}

function rideOrderArgText(args: RideOrderArgs, keys: string[]): string {
  const record = args as ToolArgRecord;
  for (let index = 0; index < keys.length; index++) {
    const value = textOf(record[keys[index]]).trim();
    if (value.length > 0) {
      return value;
    }
  }
  return '';
}

function rideDidiCreateOrderArgs(args: Object | null): RideDidiCreateOrderArgs {
  const parsed = rideOrderArgs(args);
  return {
    product_category: rideOrderArgText(parsed, ['product_category', 'productCategory']),
    estimate_trace_id: rideOrderArgText(parsed, ['estimate_trace_id', 'estimateTraceId', 'traceId'])
  };
}

function rideOrderRouteContext(args: Object | null): RideOrderRouteContext {
  const parsed = rideOrderArgs(args);
  return {
    routeText: rideOrderArgText(parsed, ['routeText', 'route']),
    pickupLocation: rideOrderArgText(parsed, ['pickupLocation', 'originLocation', 'fromLocation']),
    destinationLocation: rideOrderArgText(parsed, ['destinationLocation', 'toLocation']),
    selectedVehicleText: rideOrderArgText(parsed, ['productName', 'vehicle', 'productCategory', 'product_category']),
    estimateCacheJson: rideOrderArgText(parsed, ['estimateCacheJson'])
  };
}

function hasRideRowLabel(rows: A2uiLabelValueData[], label: string): boolean {
  for (let index = 0; index < rows.length; index++) {
    if (rows[index].label === label) {
      return true;
    }
  }
  return false;
}

function appendRideRouteContextRows(rows: A2uiLabelValueData[], context: RideOrderRouteContext): void {
  if (context.routeText.length > 0) {
    rows.push({ label: '路线', value: context.routeText });
  }
  if (context.pickupLocation.length > 0) {
    rows.push({ label: '起点坐标', value: context.pickupLocation });
  }
  if (context.destinationLocation.length > 0) {
    rows.push({ label: '终点坐标', value: context.destinationLocation });
  }
  if (context.selectedVehicleText.length > 0 && !hasRideRowLabel(rows, '车型')) {
    rows.push({ label: '车型', value: context.selectedVehicleText });
  }
}

function rideEstimateCacheJson(products: RideProduct[], traceId: string): string {
  const records: RideEstimateCacheProductRecord[] = [];
  products.forEach((product: RideProduct) => {
    const record: RideEstimateCacheProductRecord = {
      productName: product.productName,
      productCategory: product.productCategory,
      priceText: product.priceText
    };
    records.push(record);
  });
  const payload: RideEstimateCachePayload = {
    traceId: traceId,
    products: records
  };
  return JSON.stringify(payload);
}

function rideDidiCancelOrderArgs(args: Object | null): RideDidiCancelOrderArgs {
  const parsed = rideOrderArgs(args);
  const orderArgs: RideDidiCancelOrderArgs = {
    order_id: rideOrderArgText(parsed, ['order_id', 'orderId'])
  };
  const reason = rideOrderArgText(parsed, ['reason']);
  if (reason.length > 0) {
    orderArgs.reason = reason;
  }
  return orderArgs;
}

function rideDidiDriverLocationArgs(args: Object | null): RideDidiDriverLocationArgs {
  const parsed = rideOrderArgs(args);
  return {
    order_id: rideOrderArgText(parsed, ['order_id', 'orderId'])
  };
}

export function rideDidiCreateOrderArgsForTest(args: Object | null): Object {
  return rideDidiCreateOrderArgs(args);
}

export function rideDidiCancelOrderArgsForTest(args: Object | null): Object {
  return rideDidiCancelOrderArgs(args);
}

export function rideDidiDriverLocationArgsForTest(args: Object | null): Object {
  return rideDidiDriverLocationArgs(args);
}

export function rideOrderConfirmedForTest(actionId: string): boolean {
  return actionId === 'ride.order.confirm';
}

function rideErrorResult(
  sourceTag: string,
  toolName: string,
  title: string,
  summary: string,
  status: string = 'error'
): DynamicGenericToolResult {
  return {
    sourceTag: sourceTag,
    toolName: toolName,
    title: title,
    status: status,
    summary: summary,
    rows: [
      { label: '状态', value: summary }
    ],
    rawPreview: summary
  };
}

function rideObjectValue(value: Object, key: string): Object | string | number | boolean | null | undefined {
  const record = value as Record<string, Object | string | number | boolean | null | undefined>;
  return record[key];
}

function rideNestedObject(payload: Object, key: string): Object | null {
  const value = rideObjectValue(payload, key);
  if (value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value)) {
    return value as Object;
  }
  return null;
}

function ridePayloadRoot(payload: Object): Object {
  const structured = rideNestedObject(payload, 'structuredContent');
  return structured === null ? payload : structured;
}

function ridePayloadItems(payload: Object): Object[] {
  const root = ridePayloadRoot(payload);
  if (Array.isArray(root)) {
    return root as Object[];
  }
  const rootRecord = root as Record<string, Object | Object[] | string | number | boolean | null | undefined>;
  if (Array.isArray(rootRecord.items)) {
    return rootRecord.items as Object[];
  }
  if (Array.isArray(rootRecord.data)) {
    return rootRecord.data as Object[];
  }
  const data = rideNestedObject(root, 'data');
  if (data !== null) {
    const dataRecord = data as Record<string, Object | Object[] | string | number | boolean | null | undefined>;
    if (Array.isArray(dataRecord.items)) {
      return dataRecord.items as Object[];
    }
    if (Array.isArray(dataRecord.list)) {
      return dataRecord.list as Object[];
    }
  }
  return [];
}

function rideTraceId(payload: Object): string {
  const root = ridePayloadRoot(payload);
  return firstText([
    rideObjectValue(root, 'traceId'),
    rideObjectValue(root, 'trace_id'),
    rideObjectValue(root, 'estimate_trace_id')
  ]);
}

function rideProductsFromPayload(payload: Object): RideProduct[] {
  const items = ridePayloadItems(payload);
  const products: RideProduct[] = [];
  items.forEach((item: Object) => {
    const record = item as Record<string, Object | string | number | boolean | null | undefined>;
    const productName = firstText([record.productName, record.name, record.title]);
    const productCategory = firstText([record.productCategory, record.category, record.product_category]);
    const priceText = firstText([record.priceText, record.price, record.estimatePrice, record.amount]);
    if (productName.length > 0 || priceText.length > 0) {
      products.push({
        productName: productName.length > 0 ? productName : '车型',
        productCategory: productCategory,
        priceText: priceText.length > 0 ? priceText : '价格未返回'
      });
    }
  });
  return products;
}

function rideLinkFromPayload(payload: Object): string {
  const json = JSON.stringify(payload);
  const linkMatch = /((?:diditaxi|amapuri):\/\/[^"\s\\]+|https?:\/\/[^"\s\\]+)/.exec(json);
  return linkMatch !== null && linkMatch.length > 1 ? jsonTextUnescape(linkMatch[1]) : '';
}

function rideCoordinateString(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    const text = value.trim();
    if (/^-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?$/.test(text)) {
      return text.replace(/\s+/g, '');
    }
    const lngMatch = /(经度|lng|lon|longitude)\s*[:：]\s*(-?\d+(?:\.\d+)?)/i.exec(text);
    const latMatch = /(纬度|lat|latitude)\s*[:：]\s*(-?\d+(?:\.\d+)?)/i.exec(text);
    if (lngMatch !== null && lngMatch.length > 2 && latMatch !== null && latMatch.length > 2) {
      return lngMatch[2] + ',' + latMatch[2];
    }
    return '';
  }
  if (typeof value !== 'object' || Array.isArray(value)) {
    return '';
  }
  const record = value as Record<string, Object | string | number | boolean | null | undefined>;
  const lng = firstText([record.lng, record.lon, record.longitude]);
  const lat = firstText([record.lat, record.latitude]);
  return lng.length > 0 && lat.length > 0 ? lng + ',' + lat : '';
}

function rideCoordinateFromPayload(payload: Object): string {
  const root = ridePayloadRoot(payload);
  const candidates: Array<Object | string | number | boolean | null | undefined> = [
    rideObjectValue(root, 'location'),
    rideObjectValue(root, 'coordinate'),
    rideObjectValue(root, 'point')
  ];
  const items = ridePayloadItems(payload);
  if (items.length > 0) {
    const first = items[0];
    candidates.push(first);
    candidates.push(rideObjectValue(first, 'location'));
  }
  for (let index = 0; index < candidates.length; index++) {
    const coordinate = rideCoordinateString(candidates[index]);
    if (coordinate.length > 0) {
      return coordinate;
    }
  }
  return '';
}

function ridePointFromSearchPayload(name: string, payload: Object): RidePoint {
  const location = rideCoordinateFromPayload(payload);
  const parts = location.split(',');
  return {
    name: name,
    lng: parts.length > 1 ? parts[0] : '',
    lat: parts.length > 1 ? parts[1] : '',
    location: location,
    city: ''
  };
}

function ridePointFromAmapResolution(name: string, resolution: AmapLocationResolution): RidePoint {
  const parts = resolution.location.split(',');
  return {
    name: name,
    lng: parts.length > 1 ? parts[0] : '',
    lat: parts.length > 1 ? parts[1] : '',
    location: resolution.location,
    city: rideDidiCityText(resolution.city)
  };
}

function rideDidiCityFromRouteOrAmap(routeCity: string, origin: RidePoint | null, destination: RidePoint | null): string {
  const direct = rideDidiCityText(routeCity);
  if (direct.length > 0) {
    return direct;
  }
  return rideDidiCityText(firstText([
    origin === null ? '' : origin.city,
    destination === null ? '' : destination.city
  ]));
}

function rideKnownMockLocation(name: string, fallback: string): string {
  const normalized = name.replace(/\s+/g, '');
  if (normalized.indexOf('华为坂田基地') >= 0 || normalized.indexOf('坂田') >= 0) {
    return '114.066231,22.657805';
  }
  if (normalized.indexOf('秋港花园') >= 0) {
    return '114.060432,22.548829';
  }
  if (normalized.indexOf('深圳北') >= 0) {
    return '114.029415,22.609722';
  }
  if (normalized.indexOf('深圳湾万象城') >= 0) {
    return '113.943021,22.523382';
  }
  return fallback;
}

function rideMockPoint(name: string, fallbackLocation: string): RidePoint {
  const location = rideKnownMockLocation(name, fallbackLocation);
  const parts = location.split(',');
  return {
    name: name,
    lng: parts.length > 1 ? parts[0] : '',
    lat: parts.length > 1 ? parts[1] : '',
    location: location,
    city: '深圳'
  };
}

function rideMockTraceId(origin: RidePoint, destination: RidePoint): string {
  return 'mock-' + origin.location.replace(',', '') + '-' + destination.location.replace(',', '');
}

function rideMockEstimatePayload(traceId: string): RideMockEstimatePayload {
  const items: RideEstimateCacheProductRecord[] = [
    { productName: '特惠快车', productCategory: 'discount_express', priceText: '10' },
    { productName: '快车', productCategory: 'express', priceText: '15' },
    { productName: '专车', productCategory: 'premium', priceText: '30' },
    { productName: '豪华车', productCategory: 'luxury', priceText: '100' }
  ];
  return {
    structuredContent: {
      items: items,
      traceId: traceId
    }
  };
}

function rideMockOrderId(requestArgs: RideDidiCreateOrderArgs): string {
  const category = requestArgs.product_category.length > 0 ? requestArgs.product_category : 'ride';
  return 'MOCK-' + category.toUpperCase().replace(/[^A-Z0-9_]/g, '') + '-001';
}

function rideMockOrderPayload(requestArgs: RideDidiCreateOrderArgs): RideMockOrderPayload {
  return {
    orderId: rideMockOrderId(requestArgs),
    status: 'mock_order_created'
  };
}

function rideMockDriverPayload(_requestArgs: RideDidiDriverLocationArgs): RideMockDriverPayload {
  return {
    location: '114.063920,22.637910',
    driverName: '陈师傅',
    eta: '预计 6 分钟接驾',
    status: 'mock_driver_en_route'
  };
}

function rideMockCancelPayload(): RideMockCancelPayload {
  return {
    status: 'mock_cancelled'
  };
}

function rideRouteOriginText(routeText: string): string {
  const parts = routeText.split('→');
  return parts.length > 0 ? parts[0].trim() : '';
}

function rideRouteDestinationText(routeText: string): string {
  const parts = routeText.split('→');
  return parts.length > 1 ? parts[1].trim() : '';
}

function rideOrderConfirmAction(product: RideProduct, traceId: string, origin: RidePoint, destination: RidePoint, estimateCacheJson: string, isPrimary: boolean): A2uiAction {
  const args: RideOrderActionArgs = {
    productCategory: product.productCategory,
    product_category: product.productCategory,
    productName: product.productName,
    priceText: product.priceText,
    routeText: origin.name + ' → ' + destination.name,
    origin: origin.name,
    destination: destination.name,
    pickupLocation: origin.location,
    originLocation: origin.location,
    destinationLocation: destination.location,
    estimateCacheJson: estimateCacheJson,
    estimateTraceId: traceId,
    estimate_trace_id: traceId,
    traceId: traceId
  };
  return {
    id: 'ride.order.confirm',
    label: '确认叫' + product.productName,
    prompt: '确认下单：' + product.productName + ' ' + product.priceText,
    kind: 'prompt',
    variant: isPrimary ? 'primary' : 'secondary',
    args: args
  };
}

function rideOrderConfirmActions(products: RideProduct[], traceId: string, origin: RidePoint, destination: RidePoint): A2uiAction[] {
  const actions: A2uiAction[] = [];
  if (traceId.length === 0) {
    return actions;
  }
  const estimateCache = rideEstimateCacheJson(products, traceId);
  products.forEach((product: RideProduct) => {
    if (product.productCategory.length > 0) {
      actions.push(rideOrderConfirmAction(product, traceId, origin, destination, estimateCache, actions.length === 0));
    }
  });
  return actions;
}

function rideEstimateResult(origin: RidePoint, destination: RidePoint, estimatePayload: Object): DynamicGenericToolResult {
  const products = rideProductsFromPayload(estimatePayload);
  const traceId = rideTraceId(estimatePayload);
  if (products.length === 0) {
    return rideErrorResult('滴滴', 'ride.estimate', '滴滴价格预估未返回车型', '滴滴 MCP 没有返回可展示的车型和价格。');
  }
  const rows: A2uiLabelValueData[] = [
    { label: '路线', value: origin.name + ' → ' + destination.name },
    { label: '起点坐标', value: origin.location },
    { label: '终点坐标', value: destination.location }
  ];
  products.forEach((product: RideProduct) => {
    const category = product.productCategory.length > 0 ? '（' + product.productCategory + '）' : '';
    rows.push({
      label: product.productName + category,
      value: product.priceText
    });
  });
  if (traceId.length > 0) {
    rows.push({
      label: 'traceId',
      value: traceId
    });
  }
  rows.push({ label: '来源', value: '滴滴 taxi_estimate' });
  const summaryParts: string[] = [];
  products.forEach((product: RideProduct) => summaryParts.push(product.productName + ' ' + product.priceText));
  return {
    sourceTag: '滴滴',
    toolName: 'ride.estimate',
    title: '滴滴价格预估',
    status: 'success',
    summary: summaryParts.join('；') + '。',
    rows: rows,
    rawPreview: JSON.stringify(estimatePayload).substring(0, 1200),
    actions: rideOrderConfirmActions(products, traceId, origin, destination)
  };
}

function rideLinkActions(didiLink: string, amapLink: string): A2uiAction[] {
  const actions: A2uiAction[] = [];
  if (didiLink.length > 0) {
    actions.push({
      id: 'ride.open.didi',
      label: '打开滴滴',
      prompt: didiLink,
      kind: 'client',
      variant: 'primary'
    });
  }
  if (amapLink.length > 0) {
    actions.push({
      id: 'ride.open.amap',
      label: '打开高德',
      prompt: amapLink,
      kind: 'client',
      variant: didiLink.length > 0 ? 'secondary' : 'primary'
    });
  }
  return actions;
}

function rideShouldSurfaceAppLinkError(toolId: string): boolean {
  return toolId === 'ride.app.link';
}

export function rideShouldSurfaceAppLinkErrorForTest(toolId: string): boolean {
  return rideShouldSurfaceAppLinkError(toolId);
}

function rideLinkResult(origin: string, destination: string, didiLink: string, amapLink: string, originLocation: string = '', destinationLocation: string = ''): DynamicGenericToolResult {
  const rows: A2uiLabelValueData[] = [
    { label: '路线', value: origin + ' → ' + destination }
  ];
  if (originLocation.length > 0) {
    rows.push({ label: '起点坐标', value: originLocation });
  }
  if (destinationLocation.length > 0) {
    rows.push({ label: '终点坐标', value: destinationLocation });
  }
  if (didiLink.length > 0) {
    rows.push({ label: '滴滴链接', value: didiLink });
  }
  if (amapLink.length > 0) {
    rows.push({ label: '高德链接', value: amapLink });
  }
  rows.push({ label: '来源', value: '滴滴 App 链接 / 高德打车唤端链接' });
  const rawPreview: RideLinkPreview = {
    didiLink: didiLink.length,
    amapLink: amapLink.length
  };
  return {
    sourceTag: '滴滴 / 高德',
    toolName: 'ride.app.link',
    title: 'App 打车链接',
    status: didiLink.length > 0 || amapLink.length > 0 ? 'success' : 'error',
    summary: didiLink.length > 0 || amapLink.length > 0 ? '已生成可手动打开的 App 打车链接；不会自动叫车。' : '没有可打开的 App 打车链接。',
    rows: rows,
    rawPreview: JSON.stringify(rawPreview),
    actions: rideLinkActions(didiLink, amapLink)
  };
}

function rideOrderPayloadText(payload: Object, keys: string[]): string {
  const root = ridePayloadRoot(payload);
  const items = ridePayloadItems(payload);
  for (let keyIndex = 0; keyIndex < keys.length; keyIndex++) {
    const value = firstText([rideObjectValue(root, keys[keyIndex])]);
    if (value.length > 0) {
      return value;
    }
  }
  if (items.length > 0) {
    const first = items[0];
    for (let keyIndex = 0; keyIndex < keys.length; keyIndex++) {
      const value = firstText([rideObjectValue(first, keys[keyIndex])]);
      if (value.length > 0) {
        return value;
      }
    }
  }
  const data = rideNestedObject(root, 'data');
  if (data !== null) {
    for (let keyIndex = 0; keyIndex < keys.length; keyIndex++) {
      const value = firstText([rideObjectValue(data, keys[keyIndex])]);
      if (value.length > 0) {
        return value;
      }
    }
  }
  return '';
}

function rideWriteFailure(payload: Object): string {
  const root = ridePayloadRoot(payload);
  const records: Object[] = [root];
  const data = rideNestedObject(root, 'data');
  if (data !== null) {
    records.push(data);
  }
  const items = ridePayloadItems(payload);
  if (items.length > 0) {
    records.push(items[0]);
  }
  for (let index = 0; index < records.length; index++) {
    const success = rideObjectValue(records[index], 'success');
    const successful = rideObjectValue(records[index], 'successful');
    if (success === false || success === 'false' ||
      successful === false || successful === 'false') {
      return firstText([
        rideObjectValue(records[index], 'message'),
        rideObjectValue(records[index], 'error'),
        'Provider explicitly reported failure.'
      ]);
    }
    const status = firstText([
      rideObjectValue(records[index], 'status'),
      rideObjectValue(records[index], 'orderStatus'),
      rideObjectValue(records[index], 'order_status'),
      rideObjectValue(records[index], 'cancelStatus'),
      rideObjectValue(records[index], 'cancel_status')
    ]).trim();
    const lower = status.toLowerCase();
    if (lower.indexOf('fail') >= 0 || lower.indexOf('error') >= 0 ||
      lower.indexOf('reject') >= 0 || lower.indexOf('denied') >= 0) {
      return 'Provider returned failure status: ' + status;
    }
  }
  return '';
}

function rideCancelAction(orderId: string, context: RideOrderRouteContext | null = null): A2uiAction {
  const args: RideOrderActionArgs = {
    orderId: orderId,
    order_id: orderId,
    reason: '用户取消'
  };
  if (context !== null) {
    args.routeText = context.routeText;
    args.pickupLocation = context.pickupLocation;
    args.originLocation = context.pickupLocation;
    args.destinationLocation = context.destinationLocation;
    args.productName = context.selectedVehicleText;
    args.estimateCacheJson = context.estimateCacheJson;
  }
  return {
    id: 'ride.order.cancel',
    label: '取消订单',
    prompt: '取消滴滴打车订单',
    kind: 'prompt',
    variant: 'secondary',
    args: args
  };
}

function rideDriverLocationAction(orderId: string, isPrimary: boolean, context: RideOrderRouteContext | null = null): A2uiAction {
  const args: RideOrderActionArgs = {
    orderId: orderId,
    order_id: orderId
  };
  if (context !== null) {
    args.routeText = context.routeText;
    args.pickupLocation = context.pickupLocation;
    args.originLocation = context.pickupLocation;
    args.destinationLocation = context.destinationLocation;
    args.productName = context.selectedVehicleText;
    args.estimateCacheJson = context.estimateCacheJson;
  }
  return {
    id: 'ride.driver.location.refresh',
    label: '刷新司机位置',
    prompt: '刷新滴滴司机位置',
    kind: 'prompt',
    variant: isPrimary ? 'primary' : 'secondary',
    args: args
  };
}

function rideRetryQueryAction(context: RideOrderRouteContext | null = null): A2uiAction {
  const args: RideOrderActionArgs = {};
  if (context !== null) {
    const origin = rideRouteOriginText(context.routeText);
    const destination = rideRouteDestinationText(context.routeText);
    args.routeText = context.routeText;
    args.origin = origin;
    args.destination = destination;
    args.pickupLocation = context.pickupLocation;
    args.originLocation = context.pickupLocation;
    args.destinationLocation = context.destinationLocation;
    args.productName = context.selectedVehicleText;
    args.estimateCacheJson = context.estimateCacheJson;
  }
  return {
    id: 'ride.query.retry',
    label: '重新查询',
    prompt: context !== null && context.routeText.length > 0 ? '重新查询打车方案：' + context.routeText : '重新查询打车方案',
    kind: 'prompt',
    variant: 'primary',
    args: args
  };
}

function rideChangeVehicleAction(context: RideOrderRouteContext | null = null): A2uiAction {
  const args: RideOrderActionArgs = {};
  if (context !== null) {
    args.routeText = context.routeText;
    args.pickupLocation = context.pickupLocation;
    args.originLocation = context.pickupLocation;
    args.destinationLocation = context.destinationLocation;
    args.productName = context.selectedVehicleText;
    args.estimateCacheJson = context.estimateCacheJson;
  }
  return {
    id: 'ride.vehicle.change',
    label: '换车型',
    prompt: '恢复车型选择',
    kind: 'client',
    variant: 'secondary',
    args: args
  };
}

function rideCreateOrderResult(payload: Object, requestArgs: RideDidiCreateOrderArgs, context: RideOrderRouteContext): DynamicGenericToolResult {
  const orderId = rideOrderPayloadText(payload, ['orderId', 'order_id', 'oid']);
  const status = rideOrderPayloadText(payload, ['status', 'orderStatus', 'order_status']);
  const lowerStatus = status.toLowerCase();
  const providerFailure = rideWriteFailure(payload);
  if (orderId.length === 0 || providerFailure.length > 0 || lowerStatus.indexOf('fail') >= 0 ||
    lowerStatus.indexOf('error') >= 0 || lowerStatus.indexOf('reject') >= 0 ||
    lowerStatus.indexOf('denied') >= 0) {
    return rideErrorResult(
      '滴滴', 'ride.order.create', '滴滴下单未确认完成',
      orderId.length === 0 ? 'Provider 未返回订单号，本次不能视为下单成功。' :
        (providerFailure.length > 0 ? providerFailure : 'Provider 返回失败状态：' + status)
    );
  }
  const rows: A2uiLabelValueData[] = [
    { label: '车型', value: context.selectedVehicleText.length > 0 ? context.selectedVehicleText : requestArgs.product_category },
    { label: 'traceId', value: requestArgs.estimate_trace_id.length > 16 ? requestArgs.estimate_trace_id.substring(0, 8) + '...' + requestArgs.estimate_trace_id.substring(requestArgs.estimate_trace_id.length - 6) : requestArgs.estimate_trace_id }
  ];
  appendRideRouteContextRows(rows, context);
  if (orderId.length > 0) {
    rows.push({ label: '订单号', value: orderId });
  }
  if (status.length > 0) {
    rows.push({ label: '状态', value: status });
  }
  rows.push({ label: '来源', value: '滴滴 taxi_create_order（' + rideDidiMcpModeLabel() + '）' });
  return {
    sourceTag: '滴滴',
    toolName: 'ride.order.create',
    title: '滴滴订单已提交',
    status: 'success',
    summary: '已在滴滴 ' + rideDidiMcpModeLabel() + ' 提交订单，可在本应用内取消。',
    rows: rows,
    rawPreview: JSON.stringify(payload).substring(0, 1200),
    actions: [rideDriverLocationAction(orderId, true, context), rideCancelAction(orderId, context)]
  };
}

export function rideCreateOrderResultForTest(
  payload: Object,
  productCategory: string,
  estimateTraceId: string
): DynamicGenericToolResult {
  return rideCreateOrderResult(payload, {
    product_category: productCategory,
    estimate_trace_id: estimateTraceId
  }, {
    routeText: '测试起点 → 测试终点',
    pickupLocation: '114.0,22.5',
    destinationLocation: '114.1,22.6',
    selectedVehicleText: productCategory,
    estimateCacheJson: ''
  });
}

function rideCancelOrderResult(payload: Object, requestArgs: RideDidiCancelOrderArgs, context: RideOrderRouteContext | null = null): DynamicGenericToolResult {
  const status = rideOrderPayloadText(payload, ['status', 'orderStatus', 'order_status', 'cancelStatus', 'cancel_status']);
  const lowerStatus = status.toLowerCase();
  const providerFailure = rideWriteFailure(payload);
  const confirmed = providerFailure.length === 0 &&
    (lowerStatus === 'cancel' || lowerStatus === 'canceled' || lowerStatus === 'cancelled' ||
      lowerStatus === 'success' || lowerStatus === 'succeeded' ||
      lowerStatus === 'completed' || lowerStatus === 'ok');
  if (!confirmed) {
    return rideErrorResult(
      '滴滴', 'ride.order.cancel', '滴滴取消未确认完成',
      status.length === 0 ? 'Provider 未返回取消状态，本次不能视为取消成功。' : 'Provider 返回未确认状态：' + status
    );
  }
  const rows: A2uiLabelValueData[] = [
    { label: '订单号', value: requestArgs.order_id }
  ];
  if (requestArgs.reason !== undefined && requestArgs.reason.length > 0) {
    rows.push({ label: '原因', value: requestArgs.reason });
  }
  if (status.length > 0) {
    rows.push({ label: '状态', value: status });
  }
  rows.push({ label: '来源', value: '滴滴 taxi_cancel_order（' + rideDidiMcpModeLabel() + '）' });
  return {
    sourceTag: '滴滴',
    toolName: 'ride.order.cancel',
    title: '滴滴订单已取消',
    status: 'success',
    summary: '已调用滴滴 ' + rideDidiMcpModeLabel() + ' 取消订单接口。',
    rows: rows,
    rawPreview: JSON.stringify(payload).substring(0, 1200),
    actions: [rideRetryQueryAction(context), rideChangeVehicleAction(context)]
  };
}

function rideDriverCoordinate(payload: Object, lngKeys: string[], latKeys: string[]): string {
  const root = ridePayloadRoot(payload);
  const location = firstText([
    rideObjectValue(root, 'location'),
    rideObjectValue(root, 'driver_location'),
    rideObjectValue(root, 'driverLocation'),
    rideObjectValue(root, 'text')
  ]).trim();
  const locationCoordinate = rideCoordinateString(location);
  if (locationCoordinate.length > 0) {
    return locationCoordinate;
  }
  const data = rideNestedObject(root, 'data');
  const candidates: Object[] = data === null ? [root] : [root, data];
  for (let candidateIndex = 0; candidateIndex < candidates.length; candidateIndex++) {
    const candidate = candidates[candidateIndex];
    let lng = '';
    let lat = '';
    for (let index = 0; index < lngKeys.length; index++) {
      lng = firstText([rideObjectValue(candidate, lngKeys[index])]).trim();
      if (lng.length > 0) {
        break;
      }
    }
    for (let index = 0; index < latKeys.length; index++) {
      lat = firstText([rideObjectValue(candidate, latKeys[index])]).trim();
      if (lat.length > 0) {
        break;
      }
    }
    if (lng.length > 0 && lat.length > 0) {
      return lng + ',' + lat;
    }
  }
  return '';
}

function rideDriverEtaText(payload: Object): string {
  const raw = rideOrderPayloadText(payload, [
    'eta',
    'ETA',
    'driverEta',
    'driver_eta',
    'driverArrivalEta',
    'driver_arrival_eta',
    'estimatedArrivalTime',
    'estimated_arrival_time',
    'estimatedTime',
    'estimated_time',
    'arrivalTime',
    'arrival_time'
  ]).trim();
  if (raw.length === 0) {
    return '';
  }
  if (raw.indexOf('预计') >= 0 || raw.indexOf('分钟') >= 0 || raw.indexOf('接驾') >= 0) {
    return raw;
  }
  const numeric = Number(raw);
  if (!isNaN(numeric)) {
    const minutes = numeric > 30 ? Math.max(1, Math.round(numeric / 60)) : Math.max(1, Math.round(numeric));
    return '预计 ' + minutes.toString() + ' 分钟接驾';
  }
  return raw;
}

function rideDriverLocationResult(payload: Object, requestArgs: RideDidiDriverLocationArgs, context: RideOrderRouteContext | null = null): DynamicGenericToolResult {
  const location = rideDriverCoordinate(payload, ['lng', 'lon', 'longitude', 'driver_lng', 'driverLng'], ['lat', 'latitude', 'driver_lat', 'driverLat']);
  const status = rideOrderPayloadText(payload, ['status', 'orderStatus', 'order_status', 'driverStatus', 'driver_status']);
  const driverId = rideOrderPayloadText(payload, ['driverId', 'driver_id']);
  const driverName = rideOrderPayloadText(payload, ['driverName', 'driver_name', 'name']);
  const etaText = rideDriverEtaText(payload);
  const rows: A2uiLabelValueData[] = [
    { label: '订单号', value: requestArgs.order_id }
  ];
  if (context !== null) {
    appendRideRouteContextRows(rows, context);
  }
  if (location.length > 0) {
    rows.push({ label: '司机位置', value: location });
  }
  if (driverId.length > 0) {
    rows.push({ label: '司机 ID', value: driverId });
  }
  if (driverName.length > 0) {
    rows.push({ label: '司机', value: driverName });
  }
  if (etaText.length > 0) {
    rows.push({ label: '预计接驾时间', value: etaText });
  }
  if (status.length > 0) {
    rows.push({ label: '状态', value: status });
  }
  rows.push({ label: '来源', value: '滴滴 taxi_get_driver_location（' + rideDidiMcpModeLabel() + '）' });
  return {
    sourceTag: '滴滴',
    toolName: 'ride.driver.location',
    title: '滴滴司机位置',
    status: 'success',
    summary: location.length > 0 ? '已返回司机当前位置。' : '已调用滴滴 ' + rideDidiMcpModeLabel() + ' 刷新司机位置接口，但响应里没有可展示的位置。',
    rows: rows,
    rawPreview: JSON.stringify(payload).substring(0, 1200),
    actions: [rideDriverLocationAction(requestArgs.order_id, true, context), rideCancelAction(requestArgs.order_id, context)]
  };
}

export function rideDriverLocationResultForTest(payload: Object, orderId: string, pickupLocation: string = '', destinationLocation: string = ''): DynamicGenericToolResult {
  const context: RideOrderRouteContext | null = pickupLocation.length > 0 || destinationLocation.length > 0 ? {
    routeText: '测试起点 → 测试终点',
    pickupLocation: pickupLocation,
    destinationLocation: destinationLocation,
    selectedVehicleText: '',
    estimateCacheJson: ''
  } : null;
  return rideDriverLocationResult(payload, { order_id: orderId }, context);
}

export function rideCancelOrderResultForTest(payload: Object, orderId: string): DynamicGenericToolResult {
  return rideCancelOrderResult(payload, { order_id: orderId, reason: '用户取消' });
}

export function rideResultsFromMcpPayloadsForTest(origin: string, destination: string, estimatePayload: Object, didiLinkPayload: Object, amapLinkPayload: Object, originLocation: string = '', destinationLocation: string = ''): DynamicGenericToolResult[] {
  return [
    rideEstimateResult(ridePointForTest(origin, originLocation), ridePointForTest(destination, destinationLocation), estimatePayload),
    rideLinkResult(origin, destination, rideLinkFromPayload(didiLinkPayload), rideLinkFromPayload(amapLinkPayload), originLocation, destinationLocation)
  ];
}

function rideDidiRequestArgs(origin: RidePoint, destination: RidePoint, includeNames: boolean): RideDidiRequestArgs {
  const args: RideDidiRequestArgs = {
    from_lng: origin.lng,
    from_lat: origin.lat,
    to_lng: destination.lng,
    to_lat: destination.lat
  };
  if (includeNames) {
    args.from_name = origin.name;
    args.to_name = destination.name;
  }
  return args;
}

function rideAmapRequestArgs(origin: RidePoint, destination: RidePoint): RideAmapAppLinkArgs {
  return {
    slon: origin.lng,
    slat: origin.lat,
    sname: origin.name,
    dlon: destination.lng,
    dlat: destination.lat,
    dname: destination.name
  };
}

function ridePointForTest(name: string, location: string): RidePoint {
  const parts = location.split(',');
  return {
    name: name,
    lng: parts.length > 1 ? parts[0] : '',
    lat: parts.length > 1 ? parts[1] : '',
    location: location,
    city: ''
  };
}

export function rideAmapRequestArgsForTest(origin: string, destination: string): Object {
  return rideAmapRequestArgs(
    ridePointForTest('起点', origin),
    ridePointForTest('终点', destination)
  );
}

export function rideAmapGeocodePointForTest(name: string, payload: Object): Object {
  return ridePointFromAmapResolution(name, amapResolutionFromGeocodePayload(payload as AmapPayload));
}

export function rideDidiCityFromAmapGeocodeForTest(payload: Object): string {
  return rideDidiCityText(amapResolutionFromGeocodePayload(payload as AmapPayload).city);
}

function rideAmapGeocodeKey(): string {
  const webKey = localProviderConfig.amapKey.trim();
  return webKey.length > 0 ? webKey : localProviderConfig.amapMcpKey.trim();
}

export function rideAmapGeocodeKeyForTest(): string {
  return rideAmapGeocodeKey();
}

export function rideAmapWebKeyForUi(): string {
  return localProviderConfig.amapKey.trim();
}

export function rideLinkFromMcpResponseTextForTest(text: string): string {
  return rideLinkFromPayload(mcpToolPayloadFromText(text));
}

async function resolveDidiRidePoint(url: string, name: string, city: string): Promise<RidePoint> {
  const args: RideDidiTextSearchArgs = {
    keywords: name,
    city: city
  };
  const payload = await callRideMcpTool('滴滴', url, 'maps_textsearch', args);
  const point = ridePointFromSearchPayload(name, payload);
  if (point.location.length === 0) {
    throw new Error('滴滴 maps_textsearch 未返回 ' + name + ' 的经纬度。');
  }
  return point;
}

async function resolveAmapRidePoint(name: string, cityHint: string, key: string): Promise<RidePoint> {
  const city = rideDidiCityText(cityHint);
  if (isLandmarkPlace(name)) {
    const poi = await searchAmapPoiLocation(name, city.length > 0 ? city : inferAmapCityFromPlace(name), key);
    if (poi.location.length > 0) {
      return ridePointFromAmapResolution(name, poi);
    }
  }
  const geo = await geocodeAmapAddress(name, key, city);
  if (geo.location.length > 0) {
    return ridePointFromAmapResolution(name, geo);
  }
  const poi = await searchAmapPoiLocation(name, city.length > 0 ? city : inferAmapCityFromPlace(name), key);
  if (poi.location.length > 0) {
    return ridePointFromAmapResolution(name, poi);
  }
  throw new Error('高德地理编码未返回 ' + name + ' 的经纬度。');
}

function rideDidiQueryMcpUrl(): string {
  return rideMcpUrlWithKey(localProviderConfig.didiMcpUrl, localProviderConfig.didiMcpKey.trim());
}

export function rideDidiQueryMcpUrlForTest(): string {
  return rideDidiQueryMcpUrl();
}

function rideDidiOrderMcpUrl(): string {
  return rideMcpUrlWithKey(localProviderConfig.didiMcpUrl, localProviderConfig.didiMcpKey.trim());
}

export function rideDidiOrderMcpUrlForTest(): string {
  return rideDidiOrderMcpUrl();
}

function rideMockEnabled(): boolean {
  if (localProviderConfig.didiMcpSandbox === 'false') {
    return false;
  }
  return localProviderConfig.rideMockEnabled.trim().toLowerCase() === 'true';
}

function rideDidiMcpModeLabel(): string {
  return localProviderConfig.didiMcpSandbox === 'false' ? 'production' : 'sandbox';
}

function rideOrderCreateDedupKey(args: RideDidiCreateOrderArgs): string {
  if (args.product_category.length === 0 || args.estimate_trace_id.length === 0) {
    return '';
  }
  return args.product_category + '|' + args.estimate_trace_id;
}

function rideOrderCreateDedupBlocked(previousKey: string, currentKey: string, elapsedMs: number): boolean {
  return previousKey.length > 0 &&
    currentKey.length > 0 &&
    previousKey === currentKey &&
    elapsedMs >= 0 &&
    elapsedMs < RIDE_ORDER_CREATE_DEDUP_MS;
}

export function rideOrderCreateDedupBlockedForTest(previousKey: string, currentKey: string, elapsedMs: number): boolean {
  return rideOrderCreateDedupBlocked(previousKey, currentKey, elapsedMs);
}

function rideOrderCreateErrorTitle(message: string): string {
  const lower = message.toLowerCase();
  if (lower.indexOf('user_taxi_create_order') >= 0 &&
    (lower.indexOf('quota') >= 0 || lower.indexOf('rate limit') >= 0)) {
    return '下单额度已耗尽';
  }
  return '滴滴下单失败';
}

export function rideOrderCreateErrorTitleForTest(message: string): string {
  return rideOrderCreateErrorTitle(message);
}

function rideOrderCreateErrorSummary(message: string): string {
  if (rideOrderCreateErrorTitle(message) === '下单额度已耗尽') {
    return '滴滴 MCP 的 user_taxi_create_order 下单额度已耗尽。请稍后再试，或先使用打开滴滴/高德入口继续人工叫车。';
  }
  return message;
}

async function callLocalDidiRideCreateOrder(surfaceId: string, args: Object | null): Promise<string> {
  const results: DynamicGenericToolResult[] = [];
  const didiKey = localProviderConfig.didiMcpKey.trim();
  const requestArgs = rideDidiCreateOrderArgs(args);
  const routeContext = rideOrderRouteContext(args);
  if (didiKey.length === 0) {
    results.push(rideErrorResult('滴滴', 'ride.order.create', '缺少滴滴 MCP Key', '缺少 DIDI_MCP_KEY，无法调用滴滴 MCP 下单接口。'));
    return genericToolResultsA2ui(surfaceId, 'ride.order.create', results);
  }
  if (requestArgs.product_category.length === 0 || requestArgs.estimate_trace_id.length === 0) {
    results.push(rideErrorResult('滴滴', 'ride.order.create', '缺少下单参数', '滴滴下单需要 product_category 和 estimate_trace_id；请从价格预估卡片选择车型。'));
    return genericToolResultsA2ui(surfaceId, 'ride.order.create', results);
  }
  const dedupKey = rideOrderCreateDedupKey(requestArgs);
  const nowMs = new Date().getTime();
  if (rideOrderCreateDedupBlocked(lastRideOrderCreateKey, dedupKey, nowMs - lastRideOrderCreateAtMs)) {
    results.push(rideErrorResult('滴滴', 'ride.order.create', '下单请求已提交', '短时间内已经提交过同一车型的下单请求，为避免重复消耗 provider quota，本次没有再次调用 taxi_create_order。'));
    return genericToolResultsA2ui(surfaceId, 'ride.order.create', results);
  }
  lastRideOrderCreateKey = dedupKey;
  lastRideOrderCreateAtMs = nowMs;
  try {
    const payload = await callRideMcpTool('滴滴', rideDidiOrderMcpUrl(), 'taxi_create_order', requestArgs);
    const createResult = rideCreateOrderResult(payload, requestArgs, routeContext);
    results.push(createResult);
    const orderId = rideOrderPayloadText(payload, ['orderId', 'order_id', 'oid']);
    if (orderId.length > 0) {
      const driverLocationArgs: RideDidiDriverLocationArgs = { order_id: orderId };
      try {
        const driverPayload = await callRideMcpTool('滴滴', rideDidiOrderMcpUrl(), 'taxi_get_driver_location', driverLocationArgs);
        results.push(rideDriverLocationResult(driverPayload, driverLocationArgs, routeContext));
      } catch (locationError) {
        results.push(rideErrorResult('滴滴', 'ride.driver.location', '滴滴刷新司机位置失败', describeThrown(locationError)));
      }
    }
  } catch (error) {
    const message = describeThrown(error);
    results.push(rideErrorResult('滴滴', 'ride.order.create', rideOrderCreateErrorTitle(message), rideOrderCreateErrorSummary(message)));
  }
  return genericToolResultsA2ui(surfaceId, 'ride.order.create', results);
}

async function callLocalDidiRideCancelOrder(surfaceId: string, args: Object | null): Promise<string> {
  const results: DynamicGenericToolResult[] = [];
  const didiKey = localProviderConfig.didiMcpKey.trim();
  const requestArgs = rideDidiCancelOrderArgs(args);
  const routeContext = rideOrderRouteContext(args);
  if (didiKey.length === 0) {
    results.push(rideErrorResult('滴滴', 'ride.order.cancel', '缺少滴滴 MCP Key', '缺少 DIDI_MCP_KEY，无法调用滴滴 MCP 取消订单接口。'));
    return genericToolResultsA2ui(surfaceId, 'ride.order.cancel', results);
  }
  if (requestArgs.order_id.length === 0) {
    results.push(rideErrorResult('滴滴', 'ride.order.cancel', '缺少订单号', '取消滴滴订单需要 order_id；请从已提交订单卡片点击取消。'));
    return genericToolResultsA2ui(surfaceId, 'ride.order.cancel', results);
  }
  try {
    const payload = await callRideMcpTool('滴滴', rideDidiOrderMcpUrl(), 'taxi_cancel_order', requestArgs);
    results.push(rideCancelOrderResult(payload, requestArgs, routeContext));
  } catch (error) {
    results.push(rideErrorResult('滴滴', 'ride.order.cancel', '滴滴取消订单失败', describeThrown(error)));
  }
  return genericToolResultsA2ui(surfaceId, 'ride.order.cancel', results);
}

async function callDidiRideDriverLocationResults(args: Object | null): Promise<DynamicGenericToolResult[]> {
  const results: DynamicGenericToolResult[] = [];
  const didiKey = localProviderConfig.didiMcpKey.trim();
  const requestArgs = rideDidiDriverLocationArgs(args);
  const routeContext = rideOrderRouteContext(args);
  if (didiKey.length === 0) {
    results.push(rideErrorResult('滴滴', 'ride.driver.location', '缺少滴滴 MCP Key', '缺少 DIDI_MCP_KEY，无法调用滴滴 MCP 司机位置接口。'));
    return results;
  }
  if (requestArgs.order_id.length === 0) {
    results.push(rideErrorResult('滴滴', 'ride.driver.location', '缺少订单号', '刷新滴滴司机位置需要 order_id；请从订单卡片点击刷新。'));
    return results;
  }
  try {
    const payload = await callRideMcpTool('滴滴', rideDidiOrderMcpUrl(), 'taxi_get_driver_location', requestArgs);
    results.push(rideDriverLocationResult(payload, requestArgs, routeContext));
  } catch (error) {
    results.push(rideErrorResult('滴滴', 'ride.driver.location', '滴滴刷新司机位置失败', describeThrown(error)));
  }
  return results;
}

async function callMockRideEstimateResults(toolId: string, args: Object | null): Promise<DynamicGenericToolResult[]> {
  const route = rideRouteFromArgs(args);
  if (route.origin.length === 0 || route.destination.length === 0) {
    return [
      rideErrorResult('模拟打车', toolId, '需要补充起点和终点', '请同时提供打车起点和终点；模拟数据也需要明确路线。')
    ];
  }
  const originPoint = rideMockPoint(route.origin, '114.066231,22.657805');
  const destinationPoint = rideMockPoint(route.destination, '114.060432,22.548829');
  const traceId = rideMockTraceId(originPoint, destinationPoint);
  const estimatePayload = rideMockEstimatePayload(traceId);
  const results: DynamicGenericToolResult[] = [
    rideEstimateResult(originPoint, destinationPoint, estimatePayload)
  ];
  if (toolId === 'ride.app.link' || toolId === 'ride.estimate') {
    results.push(rideLinkResult(
      route.origin,
      route.destination,
      'diditaxi://mock/ride?traceId=' + encodeURIComponent(traceId),
      'amapuri://mock/taxi?sourceApplication=aiphone',
      originPoint.location,
      destinationPoint.location
    ));
  }
  return results;
}

async function callLocalMockRideCreateOrder(surfaceId: string, args: Object | null): Promise<string> {
  const results: DynamicGenericToolResult[] = [];
  const requestArgs = rideDidiCreateOrderArgs(args);
  const routeContext = rideOrderRouteContext(args);
  if (requestArgs.product_category.length === 0 || requestArgs.estimate_trace_id.length === 0) {
    results.push(rideErrorResult('模拟滴滴', 'ride.order.create', '缺少下单参数', '模拟下单需要 product_category 和 estimate_trace_id；请从价格预估卡片选择车型。'));
    return genericToolResultsA2ui(surfaceId, 'ride.order.create', results);
  }
  const payload = rideMockOrderPayload(requestArgs);
  const createResult = rideCreateOrderResult(payload, requestArgs, routeContext);
  results.push(createResult);
  const orderId = rideOrderPayloadText(payload, ['orderId', 'order_id', 'oid']);
  if (orderId.length > 0) {
    const driverLocationArgs: RideDidiDriverLocationArgs = { order_id: orderId };
    results.push(rideDriverLocationResult(rideMockDriverPayload(driverLocationArgs), driverLocationArgs, routeContext));
  }
  return genericToolResultsA2ui(surfaceId, 'ride.order.create', results);
}

async function callLocalMockRideCancelOrder(surfaceId: string, args: Object | null): Promise<string> {
  const requestArgs = rideDidiCancelOrderArgs(args);
  const routeContext = rideOrderRouteContext(args);
  if (requestArgs.order_id.length === 0) {
    return genericToolResultsA2ui(surfaceId, 'ride.order.cancel', [
      rideErrorResult('模拟滴滴', 'ride.order.cancel', '缺少订单号', '取消模拟订单需要 order_id；请从订单卡片点击取消。')
    ]);
  }
  return genericToolResultsA2ui(surfaceId, 'ride.order.cancel', [
    rideCancelOrderResult(rideMockCancelPayload(), requestArgs, routeContext)
  ]);
}

async function callMockRideDriverLocationResults(args: Object | null): Promise<DynamicGenericToolResult[]> {
  const requestArgs = rideDidiDriverLocationArgs(args);
  const routeContext = rideOrderRouteContext(args);
  if (requestArgs.order_id.length === 0) {
    return [
      rideErrorResult('模拟滴滴', 'ride.driver.location', '缺少订单号', '刷新模拟司机位置需要 order_id；请从订单卡片点击刷新。')
    ];
  }
  return [
    rideDriverLocationResult(rideMockDriverPayload(requestArgs), requestArgs, routeContext)
  ];
}

async function callStructuredRideReadResults(toolId: string, args: Object | null): Promise<DynamicGenericToolResult[]> {
  if (toolId === 'ride.driver.location') {
    return rideMockEnabled() ? callMockRideDriverLocationResults(args) : callDidiRideDriverLocationResults(args);
  }
  if (rideMockEnabled() && (toolId === 'ride.estimate' || toolId === 'ride.app.link')) {
    return callMockRideEstimateResults(toolId, args);
  }
  const route = rideRouteFromArgs(args);
  if (route.origin.length === 0 || route.destination.length === 0) {
    return [
      rideErrorResult('打车', toolId, '需要补充起点和终点', '请同时提供打车起点和终点；AIPhone 不会使用记忆坐标或猜测坐标。')
    ];
  }
  const results: DynamicGenericToolResult[] = [];
  const didiKey = localProviderConfig.didiMcpKey.trim();
  const amapMcpKey = localProviderConfig.amapMcpKey.trim();
  const amapGeocodeKey = rideAmapGeocodeKey();
  let originPoint: RidePoint | null = null;
  let destinationPoint: RidePoint | null = null;
  let amapOriginPoint: RidePoint | null = null;
  let amapDestinationPoint: RidePoint | null = null;
  let didiLink = '';
  let amapLink = '';
  let didiUrl = '';
  let amapResolveError = '';
  if (amapGeocodeKey.length > 0) {
    try {
      amapOriginPoint = await resolveAmapRidePoint(route.origin, route.city, amapGeocodeKey);
      amapDestinationPoint = await resolveAmapRidePoint(route.destination, route.city, amapGeocodeKey);
    } catch (error) {
      amapResolveError = describeThrown(error);
    }
  }
  const didiCity = rideDidiCityFromRouteOrAmap(route.city, amapOriginPoint, amapDestinationPoint);
  if (didiKey.length === 0) {
    results.push(rideErrorResult(
      '滴滴',
      toolId,
      '缺少滴滴 MCP Key',
      '缺少 DIDI_MCP_KEY，无法获取滴滴价格预估或滴滴 App 打车链接。',
      'needs_input'
    ));
  } else if (didiCity.length === 0) {
    results.push(rideErrorResult('滴滴', toolId, '需要补充城市', '请提供起终点所在城市，或确保高德地理编码可返回城市；滴滴 maps_textsearch 要求 city 参数，AIPhone 不会猜测城市或坐标。'));
  } else {
    try {
      didiUrl = rideDidiQueryMcpUrl();
      originPoint = await resolveDidiRidePoint(didiUrl, route.origin, didiCity);
      destinationPoint = await resolveDidiRidePoint(didiUrl, route.destination, didiCity);
    } catch (error) {
      results.push(rideErrorResult('滴滴', toolId, '滴滴 MCP 调用失败', describeThrown(error)));
    }
    if (originPoint !== null && destinationPoint !== null) {
      if (toolId === 'ride.estimate') {
        try {
          const estimatePayload = await callRideMcpTool('滴滴', didiUrl, 'taxi_estimate', rideDidiRequestArgs(originPoint, destinationPoint, true));
          results.push(rideEstimateResult(originPoint, destinationPoint, estimatePayload));
        } catch (error) {
          results.push(rideErrorResult('滴滴', toolId, '滴滴价格预估失败', describeThrown(error)));
        }
      }
      try {
        const didiPayload = await callRideMcpTool('滴滴', didiUrl, 'taxi_generate_ride_app_link', rideDidiRequestArgs(originPoint, destinationPoint, false));
        didiLink = rideLinkFromPayload(didiPayload);
      } catch (error) {
        if (rideShouldSurfaceAppLinkError(toolId)) {
          results.push(rideErrorResult('滴滴', 'ride.app.link', '滴滴唤端链接生成失败', describeThrown(error)));
        } else {
          aiLogInfo('[AIPhone][RideOptionalAppLinkIgnored] provider=滴滴 tool=taxi_generate_ride_app_link error=' + describeThrown(error));
        }
      }
    }
  }
  if (amapMcpKey.length > 0) {
    try {
      if (amapResolveError.length > 0) {
        throw new Error(amapResolveError);
      }
      if (amapOriginPoint === null || amapDestinationPoint === null) {
        throw new Error('高德 maps_schema_take_taxi 需要起终点经纬度；高德地理编码未返回完整坐标。');
      }
      const amapUrl = rideMcpUrlWithKey(localProviderConfig.amapMcpUrl, amapMcpKey);
      const amapTool = await selectRideMcpToolName('高德', amapUrl, ['maps_schema_take_taxi', 'maps_taxi', 'taxi', 'ride_hailing', 'amap_taxi'], ['打车', 'taxi', 'ride']);
      const amapArgs = rideAmapRequestArgs(amapOriginPoint, amapDestinationPoint);
      const amapPayload = await callRideMcpTool('高德', amapUrl, amapTool, amapArgs);
      amapLink = rideLinkFromPayload(amapPayload);
    } catch (error) {
      if (rideShouldSurfaceAppLinkError(toolId)) {
        results.push(rideErrorResult('高德', 'ride.app.link', '高德打车唤端链接生成失败', describeThrown(error)));
      } else {
        aiLogInfo('[AIPhone][RideOptionalAppLinkIgnored] provider=高德 tool=maps_schema_take_taxi error=' + describeThrown(error));
      }
    }
  }
  if (didiLink.length > 0 || amapLink.length > 0 || toolId === 'ride.app.link') {
    const originLocation = originPoint !== null ? originPoint.location : (amapOriginPoint !== null ? amapOriginPoint.location : '');
    const destinationLocation = destinationPoint !== null ? destinationPoint.location : (amapDestinationPoint !== null ? amapDestinationPoint.location : '');
    results.push(rideLinkResult(route.origin, route.destination, didiLink, amapLink, originLocation, destinationLocation));
  }
  return results;
}

async function callLocalRideTool(
  toolId: string,
  _prompt: string,
  surfaceId: string,
  actionId: string,
  args: Object | null = null
): Promise<string> {
  if (toolId === 'ride.order.create') {
    if (!rideOrderConfirmedForTest(actionId)) {
      return genericToolResultsA2ui(surfaceId, toolId, [
        rideErrorResult('滴滴', toolId, '需要明确确认车型', '请从当前价格预估卡片点击确认叫车。')
      ]);
    }
    return rideMockEnabled() ? callLocalMockRideCreateOrder(surfaceId, args) : callLocalDidiRideCreateOrder(surfaceId, args);
  }
  if (toolId === 'ride.order.cancel') {
    if (actionId !== 'ride.order.cancel') {
      return genericToolResultsA2ui(surfaceId, toolId, [
        rideErrorResult('滴滴', toolId, '需要当前订单取消操作', '请从当前订单卡片点击取消。')
      ]);
    }
    return rideMockEnabled() ? callLocalMockRideCancelOrder(surfaceId, args) : callLocalDidiRideCancelOrder(surfaceId, args);
  }
  return genericToolResultsA2ui(surfaceId, toolId, await callStructuredRideReadResults(toolId, args));
}

function build12306LeftTicketUrl(path: string, date: string, fromCode: string, toCode: string): string {
  return 'https://kyfw.12306.cn/otn/leftTicket/' + path +
    '?leftTicketDTO.train_date=' + encodeURIComponent(date) +
    '&leftTicketDTO.from_station=' + encodeURIComponent(fromCode) +
    '&leftTicketDTO.to_station=' + encodeURIComponent(toCode) +
    '&purpose_codes=ADULT';
}

export function build12306BookingUrl(
  date: string,
  fromName: string,
  fromCode: string,
  toName: string,
  toCode: string
): string {
  return 'https://kyfw.12306.cn/otn/leftTicket/init?linktypeid=dc' +
    '&fs=' + encodeURIComponent(fromName) + ',' + encodeURIComponent(fromCode) +
    '&ts=' + encodeURIComponent(toName) + ',' + encodeURIComponent(toCode) +
    '&date=' + encodeURIComponent(date) +
    '&flag=N,N,Y';
}

function redirected12306Url(text: string, date: string, fromCode: string, toCode: string): string {
  const match = /"c_url"\s*:\s*"([^"]+)"/.exec(text);
  if (match === null || match[1].length === 0) {
    return '';
  }
  const path = match[1].startsWith('leftTicket/') ? match[1].substring('leftTicket/'.length) : match[1];
  return build12306LeftTicketUrl(path, date, fromCode, toCode);
}

function isCookieAttribute(name: string): boolean {
  const value = name.trim().toLowerCase();
  return value === 'path' ||
    value === 'domain' ||
    value === 'expires' ||
    value === 'max-age' ||
    value === 'samesite' ||
    value === 'httponly' ||
    value === 'secure';
}

function is12306CookieName(name: string): boolean {
  return name === 'route' ||
    name === 'JSESSIONID' ||
    name === 'BIGipServerotn' ||
    name.startsWith('BIGipServer') ||
    name.startsWith('RAIL_') ||
    name.startsWith('_jc_save_') ||
    name === 'guidesStatus' ||
    name === 'highContrastMode' ||
    name === 'cursorStatus';
}

function upsertCookiePair(pairs: string[], names: string[], name: string, value: string): void {
  for (let index = 0; index < names.length; index++) {
    if (names[index] === name) {
      pairs[index] = name + '=' + value;
      return;
    }
  }
  names.push(name);
  pairs.push(name + '=' + value);
}

function cookieHeaderFromRaw(rawCookies: string): string {
  const normalized = rawCookies
    .replace(/\\r/g, '\n')
    .replace(/\\n/g, '\n')
    .replace(/\r/g, '\n');
  const result: string[] = [];
  const names: string[] = [];
  const matcher = /([A-Za-z_][A-Za-z0-9_]*|BIGipServer[A-Za-z0-9_]+)=([^;\s,"\\]+)/g;
  let match: RegExpExecArray | null = matcher.exec(normalized);
  while (match !== null) {
    const name = match[1].trim();
    const value = match[2].trim();
    if (name.length > 0 && value.length > 0 && !isCookieAttribute(name) && is12306CookieName(name)) {
      upsertCookiePair(result, names, name, value);
    }
    match = matcher.exec(normalized);
  }
  return result.join('; ');
}

async function request12306LeftTicket(date: string, fromCode: string, toCode: string, headers: HttpRequestHeaders): Promise<HttpTextResponse> {
  const paths: string[] = ['queryI', 'queryG', 'queryZ'];
  let lastResponse: HttpTextResponse = {
    code: 0,
    text: '',
    cookies: '',
    headers: ''
  };
  for (let index = 0; index < paths.length; index++) {
    const path = paths[index];
    const response = await requestText(build12306LeftTicketUrl(path, date, fromCode, toCode), headers);
    lastResponse = response;
    aiLogInfo('[AIPhone][LocalTool12306Endpoint] path=' + path + ' code=' + response.code.toString() + ' chars=' + response.text.length.toString());
    if (response.code >= 200 && response.code < 300 && response.text.indexOf('"result"') >= 0) {
      return response;
    }
    const redirected = redirected12306Url(response.text, date, fromCode, toCode);
    if (redirected.length > 0) {
      const redirectedResponse = await requestText(redirected, headers);
      lastResponse = redirectedResponse;
      aiLogInfo('[AIPhone][LocalTool12306Endpoint] path=redirect code=' + redirectedResponse.code.toString() + ' chars=' + redirectedResponse.text.length.toString());
      if (redirectedResponse.code >= 200 && redirectedResponse.code < 300 && redirectedResponse.text.indexOf('"result"') >= 0) {
        return redirectedResponse;
      }
    }
  }
  return lastResponse;
}

async function load12306Stations(): Promise<StationCache> {
  if (stationCache !== null) {
    return stationCache;
  }
  const response = await requestText('https://kyfw.12306.cn/otn/resources/js/framework/station_name.js', userAgentHeaders());
  if (response.code < 200 || response.code >= 300) {
    throw new Error('12306 station_name HTTP ' + response.code.toString());
  }

  const entries: StationEntry[] = [];
  const names: string[] = [];
  response.text.split('@').forEach((part: string) => {
    const fields = part.split('|');
    if (fields.length >= 3 && fields[1].length > 0 && fields[2].length > 0) {
      entries.push({
        name: fields[1],
        code: fields[2]
      });
      names.push(fields[1]);
    }
  });
  names.sort((left: string, right: string) => right.length - left.length);
  stationCache = {
    entries: entries,
    names: names
  };
  aiLogInfo('[AIPhone][LocalToolStations] count=' + entries.length.toString());
  return stationCache;
}

function trainField(fields: string[], index: number): string {
  return fields.length > index ? fields[index].trim() : '';
}

function isAvailableTrainSeat(value: string): boolean {
  const text = value.trim();
  return text === '有' || /^[1-9]\d*$/.test(text);
}

function trainSeatAvailabilityForPriceCode(code: string, fields: string[]): string {
  if (code === '9') {
    return trainField(fields, 32);
  }
  if (code === 'P') {
    return trainField(fields, 25);
  }
  if (code === 'M') {
    return trainField(fields, 31);
  }
  if (code === 'O' || code === 'S') {
    return trainField(fields, 30);
  }
  if (code === '6' || code === 'A') {
    return trainField(fields, 21);
  }
  if (code === '4' || code === 'I') {
    return trainField(fields, 23);
  }
  if (code === 'F') {
    return trainField(fields, 33);
  }
  if (code === '3' || code === 'J') {
    return trainField(fields, 28);
  }
  if (code === '2') {
    return trainField(fields, 24);
  }
  if (code === '1') {
    return trainField(fields, 29);
  }
  if (code === 'W') {
    return trainField(fields, 26);
  }
  return '';
}

function lowestAvailable12306Price(fields: string[]): string {
  const ypInfoNew = trainField(fields, 39);
  if (ypInfoNew.length === 0 || ypInfoNew.length % 10 !== 0) {
    return '';
  }
  let minimumJiao = -1;
  for (let offset = 0; offset < ypInfoNew.length; offset += 10) {
    const chunk = ypInfoNew.substring(offset, offset + 10);
    const inventoryText = chunk.substring(6, 10);
    const availability = /^\d{4}$/.test(inventoryText) && Number.parseInt(inventoryText, 10) >= 3000 ?
      trainField(fields, 26) : trainSeatAvailabilityForPriceCode(chunk.substring(0, 1), fields);
    const priceText = chunk.substring(1, 6);
    if (!isAvailableTrainSeat(availability) || !/^\d{5}$/.test(priceText)) {
      continue;
    }
    const priceJiao = Number.parseInt(priceText, 10);
    if (priceJiao <= 0) {
      continue;
    }
    if (minimumJiao < 0 || priceJiao < minimumJiao) {
      minimumJiao = priceJiao;
    }
  }
  if (minimumJiao < 0) {
    return '';
  }
  const yuan = Math.floor(minimumJiao / 10);
  const jiao = minimumJiao % 10;
  return jiao === 0 ? yuan.toString() : yuan.toString() + '.' + jiao.toString();
}

export function trainLowestAvailablePriceForTest(row: string): string {
  return lowestAvailable12306Price(row.split('|'));
}

function parse12306Row(row: string, stations: StationCache): A2uiTrainData {
  const fields = row.split('|');
  const trainCode = fields.length > 3 ? fields[3] : '';
  return {
    trainCode: trainCode,
    from: fields.length > 6 ? stationNameForCode(fields[6], stations) : '',
    to: fields.length > 7 ? stationNameForCode(fields[7], stations) : '',
    depart: fields.length > 8 ? fields[8] : '',
    arrive: fields.length > 9 ? fields[9] : '',
    duration: fields.length > 10 ? fields[10] : '',
    seats: '',
    status: fields.length > 1 && fields[1].length > 0 ? fields[1] : (fields.length > 11 ? fields[11] : ''),
    business: fields.length > 32 ? fields[32] : '',
    first: fields.length > 31 ? fields[31] : '',
    second: fields.length > 30 ? fields[30] : '',
    noSeat: fields.length > 26 ? fields[26] : '',
    hardSeat: fields.length > 29 ? fields[29] : '',
    sleeperSoft: fields.length > 23 && fields[23].length > 0 ? fields[23] : (fields.length > 28 ? fields[28] : ''),
    price: lowestAvailable12306Price(fields)
  };
}

function formatTrainSeatsSummary(item: A2uiTrainData): string {
  const seats: string[] = [];
  if (item.business.length > 0) {
    seats.push('商务 ' + item.business);
  }
  if (item.first.length > 0) {
    seats.push('一等 ' + item.first);
  }
  if (item.second.length > 0) {
    seats.push('二等 ' + item.second);
  }
  if (item.sleeperSoft.length > 0) {
    seats.push('卧铺 ' + item.sleeperSoft);
  }
  if (item.hardSeat.length > 0) {
    seats.push('硬座 ' + item.hardSeat);
  }
  if (item.noSeat.length > 0) {
    seats.push('无座 ' + item.noSeat);
  }
  return seats.join(' / ');
}

function normalizeTrainRecord(item: A2uiTrainData, bookingUrl: string = ''): A2uiTrainData {
  return {
    trainCode: item.trainCode,
    from: item.from,
    to: item.to,
    fromLocation: item.fromLocation,
    depart: item.depart,
    arrive: item.arrive,
    duration: item.duration,
    seats: item.seats.length > 0 ? item.seats : formatTrainSeatsSummary(item),
    status: item.status.length > 0 ? item.status : '计划',
    business: item.business,
    first: item.first,
    second: item.second,
    noSeat: item.noSeat,
    hardSeat: item.hardSeat,
    sleeperSoft: item.sleeperSoft,
    price: item.price === undefined ? '' : item.price,
    bookingUrl: bookingUrl
  };
}

function filterTrainsByDepartAfter(trains: A2uiTrainData[], afterTime: string): A2uiTrainData[] {
  if (afterTime.length === 0) {
    return trains;
  }
  const result: A2uiTrainData[] = [];
  trains.forEach((item: A2uiTrainData) => {
    if (item.depart.length < 4) {
      result.push(item);
      return;
    }
    const hhmm = item.depart.length >= 5 ? item.depart.substring(0, 5) : item.depart;
    if (hhmm >= afterTime) {
      result.push(item);
    }
  });
  return result;
}

function filterHighSpeed(source: string, trains: A2uiTrainData[]): A2uiTrainData[] {
  if (!/高铁|动车|\bG\d+|\bD\d+/i.test(source)) {
    return trains;
  }
  const result: A2uiTrainData[] = [];
  trains.forEach((item: A2uiTrainData) => {
    if (item.trainCode.startsWith('G') || item.trainCode.startsWith('D')) {
      result.push(item);
    }
  });
  return result;
}

function intentForTool(toolId: string): string {
  if (toolId === 'food.search') {
    return 'food';
  }
  if (toolId === 'hotel.search' || toolId === 'hotel.detail') {
    return 'hotel';
  }
  if (toolId === 'travel.search' || toolId === 'train.search' || toolId === 'flight.search') {
    return 'travel';
  }
  return 'general';
}

function componentForTool(toolId: string): string {
  if (toolId === 'travel.search') {
    return 'TravelOptions';
  }
  if (toolId === 'train.search') {
    return 'TrainOptions';
  }
  if (toolId === 'flight.search') {
    return 'FlightBoard';
  }
  if (toolId === 'food.search') {
    return 'FoodChoices';
  }
  return 'InfoRows';
}

function dataPathForTool(toolId: string): string {
  if (toolId === 'travel.search') {
    return '/travelOptions';
  }
  if (toolId === 'train.search') {
    return '/trains';
  }
  if (toolId === 'flight.search') {
    return '/flights';
  }
  if (toolId === 'food.search') {
    return '/foods';
  }
  return '/rows';
}

function dataLabelForTool(toolId: string): string {
  if (toolId === 'travel.search') {
    return 'travelOptions';
  }
  if (toolId === 'train.search') {
    return 'trains';
  }
  if (toolId === 'flight.search') {
    return 'flights';
  }
  if (toolId === 'food.search') {
    return 'foods';
  }
  return 'rows';
}

function structuredCollectionResult(
  toolId: string,
  outputSchema: string,
  data: Object,
  itemCount: number,
  sources: DataSource[],
  warnings: string[]
): DataResult {
  if (itemCount > 0) {
    return warnings.length > 0 ?
      partialDataResult(toolId, outputSchema, data, sources, warnings) :
      successfulDataResult(toolId, outputSchema, data, sources);
  }
  const result = successfulDataResult(toolId, outputSchema, data, sources);
  result.status = 'empty';
  result.warnings = warnings.slice();
  return result;
}

export function travelStructuredDataResult(
  data: TravelStructuredData,
  sources: DataSource[],
  warnings: string[] = []
): DataResult {
  return structuredCollectionResult('travel.search', 'travelOptions', data, data.options.length, sources, warnings);
}

export function trainStructuredDataResult(
  data: TrainStructuredData,
  sources: DataSource[],
  warnings: string[] = []
): DataResult {
  return structuredCollectionResult('train.search', 'trains', data, data.trains.length, sources, warnings);
}

export function flightStructuredDataResult(
  data: FlightStructuredData,
  sources: DataSource[],
  warnings: string[] = []
): DataResult {
  return structuredCollectionResult('flight.search', 'flights', data, data.flights.length, sources, warnings);
}

export function foodStructuredDataResult(
  data: FoodStructuredData,
  sources: DataSource[],
  warnings: string[] = []
): DataResult {
  return structuredCollectionResult('food.search', 'foodChoices', data, data.foods.length, sources, warnings);
}

function titleForTool(toolId: string): string {
  if (toolId === 'travel.search') {
    return '出行方案查询';
  }
  if (toolId === 'train.search') {
    return '火车票查询';
  }
  if (toolId === 'flight.search') {
    return '国内航班查询';
  }
  if (toolId === 'food.search') {
    return '附近餐饮查询';
  }
  if (toolId === 'hotel.search') {
    return '酒店搜索';
  }
  if (toolId === 'hotel.detail') {
    return '实时房型与报价';
  }
  return '工具调用';
}

function a2uiLine(envelope: A2uiEnvelope): string {
  const line: A2uiEnvelope = {
    version: A2UI_VERSION
  };
  if (envelope.createSurface !== undefined && envelope.createSurface !== null) {
    line.createSurface = envelope.createSurface;
  }
  if (envelope.updateComponents !== undefined && envelope.updateComponents !== null) {
    line.updateComponents = envelope.updateComponents;
  }
  if (envelope.updateDataModel !== undefined && envelope.updateDataModel !== null) {
    line.updateDataModel = envelope.updateDataModel;
  }
  if (envelope.deleteSurface !== undefined && envelope.deleteSurface !== null) {
    line.deleteSurface = envelope.deleteSurface;
  }
  return JSON.stringify(line) + '\n';
}

function a2uiJsonl(envelopes: A2uiEnvelope[]): string {
  let jsonl = '';
  envelopes.forEach((envelope: A2uiEnvelope) => {
    jsonl += a2uiLine(envelope);
  });
  return jsonl;
}

function pendingA2ui(toolId: string, prompt: string, surfaceId: string): string {
  const title = titleForTool(toolId);
  const message = toolId === 'travel.search'
    ? '正在同时等待 12306 和飞常准返回'
    : (toolId === 'train.search'
    ? '正在等待 12306 返回'
    : (toolId === 'flight.search' ? '正在等待飞常准返回' : (toolId === 'food.search' ? '正在等待外卖聚合来源返回' :
      (toolId === 'hotel.search' || toolId === 'hotel.detail' ? '正在等待 RollingGo 返回真实酒店数据' : '正在调用工具'))));
  const components: A2uiComponent[] = [
    {
      id: 'root',
      component: 'SurfaceRoot',
      child: 'thinking',
      title: title,
      body: prompt.substring(0, 120),
      status: 'calling_tool'
    },
    {
      id: 'thinking',
      component: 'ThinkingStream',
      title: 'AIPhone 正在处理',
      body: message,
      status: 'calling_tool',
      dataPath: '/thoughts',
      actions: []
    }
  ];
  return a2uiJsonl([
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: title,
        intent: intentForTool(toolId),
        status: 'calling_tool',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
        components: components
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/thoughts',
        value: [
          '正在识别请求约束',
          message,
          '正在校验返回结构'
        ]
      }
    }
  ]);
}

function errorA2ui(surfaceId: string, toolId: string, title: string, body: string, rows: string[], actions: string[]): string {
  const actionModels: A2uiAction[] = [];
  actions.forEach((action: string, index: number) => {
    actionModels.push({
      id: 'tool_action_' + index.toString(),
      label: action,
      prompt: action,
      kind: 'prompt',
      variant: index === 0 ? 'primary' : 'secondary'
    });
  });
  const rowModels: A2uiLabelValueData[] = [];
  rows.forEach((row: string, index: number) => {
    rowModels.push({
      label: index === 0 ? '状态' : '信息 ' + (index + 1).toString(),
      value: row
    });
  });
  return a2uiJsonl([
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: title,
        intent: intentForTool(toolId),
        status: 'needs_input',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'notice',
            title: title,
            body: body,
            status: 'needs_input'
          },
          {
            id: 'notice',
            component: 'ErrorNotice',
            title: title,
            body: body,
            status: 'needs_input',
            tone: 'warning',
            dataPath: '/rows',
            actions: actionModels
          }
        ]
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/rows',
        value: rowModels
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/summary',
        value: {
          text: body,
          toolName: toolId,
          dataLabel: 'rows',
          count: rowModels.length
        }
      }
    }
  ]);
}

function legacyToolExceptionA2ui(surfaceId: string, toolId: string, message: string): string {
  return errorA2ui(
    surfaceId,
    toolId,
    '工具供应商调用异常',
    message,
    ['本机工具已运行，但真实供应商调用失败。', '请检查设备网络、供应商 TLS/接口状态，或稍后重试。'],
    ['重新查询']
  );
}

function trainResultA2ui(surfaceId: string, title: string, body: string, summaryText: string, trains: A2uiTrainData[]): string {
  return a2uiJsonl([
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: title,
        intent: 'travel',
        status: 'ready',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'results',
            title: title,
            body: summaryText,
            status: 'ready'
          },
          {
            id: 'results',
            component: componentForTool('train.search'),
            title: title,
            body: body,
            status: 'ready',
            dataPath: dataPathForTool('train.search'),
            actions: TRAIN_CLIENT_ACTIONS
          }
        ]
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/trains',
        value: trains
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/summary',
        value: {
          text: summaryText,
          toolName: 'train.search',
          dataLabel: dataLabelForTool('train.search'),
          count: trains.length
        }
      }
    }
  ]);
}

function flightResultA2ui(surfaceId: string, title: string, body: string, summaryText: string, flights: A2uiFlightData[]): string {
  return a2uiJsonl([
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: title,
        intent: 'travel',
        status: 'ready',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'results',
            title: title,
            body: summaryText,
            status: 'ready'
          },
          {
            id: 'results',
            component: componentForTool('flight.search'),
            title: title,
            body: body,
            status: 'ready',
            dataPath: dataPathForTool('flight.search'),
            actions: [
              { id: 'flight_change_date', label: '换个日期', prompt: '换个日期查询航班', kind: 'prompt', variant: 'secondary' }
              // 换城市需要城市选择控件，先不暴露半成品入口。
              // { id: 'flight_change_city', label: '换个城市', prompt: '换个城市查询航班', kind: 'prompt', variant: 'secondary' }
            ]
          }
        ]
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/flights',
        value: flights
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/summary',
        value: {
          text: summaryText,
          toolName: 'flight.search',
          dataLabel: dataLabelForTool('flight.search'),
          count: flights.length
        }
      }
    }
  ]);
}

function travelResultA2ui(surfaceId: string, title: string, body: string, summaryText: string, options: A2uiTravelOptionData[], rows: A2uiLabelValueData[]): string {
  const components: A2uiComponent[] = [];
  components.push({
    id: 'root',
    component: 'SurfaceRoot',
    child: rows.length > 0 ? 'layout' : 'results',
    title: title,
    body: summaryText,
    status: 'ready'
  });
  if (rows.length > 0) {
    components.push({
      id: 'layout',
      component: 'Column',
      children: ['summary', 'results'],
      status: 'ready'
    });
    components.push({
      id: 'summary',
      component: 'InfoRows',
      title: '来源状态',
      body: '以下只展示真实工具返回；失败来源不会生成占位结果。',
      status: 'ready',
      dataPath: '/rows',
      actions: []
    });
  }
  components.push({
    id: 'results',
    component: componentForTool('travel.search'),
    title: title,
    body: body,
    status: 'ready',
    dataPath: dataPathForTool('travel.search'),
    actions: TRAVEL_CLIENT_ACTIONS
  });

  return a2uiJsonl([
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: title,
        intent: 'travel',
        status: 'ready',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
        components: components
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/travelOptions',
        value: options
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/rows',
        value: rows
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/summary',
        value: {
          text: summaryText,
          toolName: 'travel.search',
          dataLabel: dataLabelForTool('travel.search'),
          count: options.length
        }
      }
    }
  ]);
}

export function travelStructuredDataA2ui(surfaceId: string, data: TravelStructuredData): string {
  return travelResultA2ui(surfaceId, data.title, data.body, data.summary, data.options, data.rows);
}

export function trainStructuredDataA2ui(surfaceId: string, data: TrainStructuredData): string {
  return trainResultA2ui(surfaceId, data.title, data.body, data.summary, data.trains);
}

export function flightStructuredDataA2ui(surfaceId: string, data: FlightStructuredData): string {
  return flightResultA2ui(surfaceId, data.title, data.body, data.summary, data.flights);
}

function compactTime(value: string): string {
  const text = value.trim();
  const match = /(\d{1,2}):(\d{2})/.exec(text);
  if (match !== null) {
    return pad2(Number(match[1])) + ':' + match[2];
  }
  return text;
}

function parseTravelDurationMinutes(duration: string): number {
  const text = duration.trim();
  const colon = /^(\d{1,2}):(\d{2})$/.exec(text);
  if (colon !== null) {
    return Number.parseInt(colon[1], 10) * 60 + Number.parseInt(colon[2], 10);
  }
  let hours = 0;
  let minutes = 0;
  const hourMatch = /(\d+)\s*小时/.exec(text);
  const minuteMatch = /(\d+)\s*分/.exec(text);
  if (hourMatch !== null) {
    hours = Number.parseInt(hourMatch[1], 10);
  }
  if (minuteMatch !== null) {
    minutes = Number.parseInt(minuteMatch[1], 10);
  }
  if (hours > 0 || minutes > 0) {
    return hours * 60 + minutes;
  }
  return 99999;
}

function durationFromTimes(depart: string, arrive: string): string {
  const start = Date.parse(depart);
  const end = Date.parse(arrive);
  if (isNaN(start) || isNaN(end) || end <= start) {
    return '';
  }
  const minutes = Math.floor((end - start) / 60000);
  if (minutes <= 0 || minutes > 48 * 60) {
    return '';
  }
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (hours > 0) {
    return hours.toString() + '小时' + rest.toString() + '分';
  }
  return rest.toString() + '分';
}

function clockScore(value: string): number {
  const match = /(\d{1,2}):(\d{2})/.exec(value);
  if (match === null) {
    return 9999;
  }
  return Number.parseInt(match[1], 10) * 60 + Number.parseInt(match[2], 10);
}

function travelSourceSortOrder(source: string): number {
  if (source === 'train') {
    return 0;
  }
  if (source === 'flight') {
    return 1;
  }
  return 2;
}

export function sortTravelOptionsByDeparture(options: A2uiTravelOptionData[]): A2uiTravelOptionData[] {
  const copy = options.slice();
  copy.sort((left: A2uiTravelOptionData, right: A2uiTravelOptionData) => {
    const departDelta = clockScore(left.depart) - clockScore(right.depart);
    if (departDelta !== 0) {
      return departDelta;
    }
    const arriveDelta = clockScore(left.arrive) - clockScore(right.arrive);
    if (arriveDelta !== 0) {
      return arriveDelta;
    }
    return travelSourceSortOrder(left.source) - travelSourceSortOrder(right.source);
  });
  return copy;
}

function trainToTravelOption(item: A2uiTrainData, index: number): A2uiTravelOptionData {
  return {
    id: 'train-' + (item.trainCode.length > 0 ? item.trainCode : index.toString()) + '-' + item.depart,
    source: 'train',
    sourceTag: '高铁 · 12306',
    title: item.trainCode,
    from: item.from,
    to: item.to,
    fromLocation: item.fromLocation,
    depart: compactTime(item.depart),
    arrive: compactTime(item.arrive),
    duration: item.duration,
    price: item.price === undefined ? '' : item.price,
    availability: item.seats,
    status: item.status.length > 0 ? item.status : '可查',
    detail: ''
  };
}

function flightToTravelOption(item: A2uiFlightData, index: number): A2uiTravelOptionData {
  const duration = durationFromTimes(item.depTime, item.arrTime);
  return {
    id: 'flight-' + (item.flightNo.length > 0 ? item.flightNo : index.toString()) + '-' + compactTime(item.depTime),
    source: 'flight',
    sourceTag: '飞机 · 飞常准',
    title: item.flightNo.length > 0 ? item.flightNo : item.airline,
    from: item.dep,
    to: item.arr,
    fromLocation: item.depLocation,
    depart: compactTime(item.depTime),
    arrive: compactTime(item.arrTime),
    duration: duration,
    price: item.price,
    availability: '',
    status: item.status.length > 0 ? item.status : '计划',
    detail: item.airline
  };
}

function travelIssueRow(label: string, result: DataResult, emptyText: string): A2uiLabelValueData {
  if (result.error !== undefined && result.error.message.length > 0) {
    return { label: label, value: result.error.message };
  }
  if (result.toolId === 'train.search') {
    const data = result.data as TrainStructuredData;
    return { label: label, value: data.summary.length > 0 ? data.summary : emptyText };
  }
  const data = result.data as FlightStructuredData;
  return { label: label, value: data.summary.length > 0 ? data.summary : emptyText };
}

export function combineTravelStructuredResults(
  prompt: string,
  trainResult: DataResult,
  flightResult: DataResult
): DataResult {
  const trainData = trainResult.data as TrainStructuredData;
  const flightData = flightResult.data as FlightStructuredData;
  let options: A2uiTravelOptionData[] = [];
  trainData.trains.forEach((item: A2uiTrainData, index: number) => {
    options.push(trainToTravelOption(item, index));
  });
  flightData.flights.forEach((item: A2uiFlightData, index: number) => {
    options.push(flightToTravelOption(item, index));
  });
  options = sortTravelOptionsByDeparture(options);

  const rows: A2uiLabelValueData[] = [];
  if (trainResult.status === 'error' || trainData.trains.length === 0) {
    rows.push(travelIssueRow('高铁 · 12306', trainResult, '12306 没有返回可展示车次。'));
  }
  if (flightResult.status === 'error' || flightData.flights.length === 0) {
    rows.push(travelIssueRow('飞机 · 飞常准', flightResult, '飞常准没有返回可展示航班。'));
  }

  aiLogInfo('[AIPhone][LocalToolTravelResult] trains=' + trainData.trains.length.toString() +
    ' flights=' + flightData.flights.length.toString() +
    ' options=' + options.length.toString() +
    ' issues=' + rows.length.toString());

  const data: TravelStructuredData = {
    title: options.length > 0 ? '出行方案查询' : '出行方案查询失败',
    body: options.length > 0 ? '用户请求：' + prompt :
      '高铁和航班工具都没有返回可展示结果。为避免编造行程，当前只展示真实错误或空结果说明。',
    summary: options.length > 0 ? '已查询高铁和航班，共 ' + options.length.toString() + ' 个可展示方案。' :
      '12306 和飞常准都没有返回可展示结果。',
    options: options,
    rows: rows
  };
  const sources = trainResult.sources.concat(flightResult.sources);
  const warnings: string[] = [];
  rows.forEach((row: A2uiLabelValueData) => warnings.push(row.label + '：' + row.value));
  if (options.length === 0) {
    const retryable = trainResult.error?.retryable === true || flightResult.error?.retryable === true;
    const result = structuredErrorWithData(
      'travel.search', 'travelOptions', data, 'TRAVEL_PROVIDERS_UNAVAILABLE', data.body, retryable, sources
    );
    result.warnings = warnings;
    return result;
  }
  return travelStructuredDataResult(data, sources, warnings);
}

async function callStructuredTravelTool(prompt: string): Promise<DataResult> {
  const trainPrompt = /高铁|动车|\bG\d+|\bD\d+/i.test(prompt) ? prompt : prompt + ' 高铁';
  const flightPrompt = /航班|机票|飞机/.test(prompt) ? prompt : prompt + ' 航班';
  const results = await Promise.all([
    callStructuredTrainTool(trainPrompt),
    callStructuredFlightTool(flightPrompt)
  ]);
  return combineTravelStructuredResults(prompt, results[0], results[1]);
}

function travelDataResultA2ui(surfaceId: string, result: DataResult): string {
  const data = result.data as TravelStructuredData;
  if (result.status === 'error') {
    return errorA2ui(
      surfaceId, 'travel.search', data.title, data.body,
      result.warnings.length > 0 ? result.warnings : [data.summary],
      ['换日期或城市', '只查高铁', '只查飞机']
    );
  }
  return travelStructuredDataA2ui(surfaceId, data);
}

async function callLocalTravelSearch(prompt: string, surfaceId: string): Promise<string> {
  return travelDataResultA2ui(surfaceId, await callStructuredTravelTool(prompt));
}

function foodDataSignature(foods: A2uiFoodData[]): string {
  return JSON.stringify(foods);
}

function foodRowsSignature(rows: A2uiLabelValueData[]): string {
  return JSON.stringify(rows);
}

function foodSummaryData(summaryText: string, foods: A2uiFoodData[]): A2uiSummaryData {
  return {
    text: summaryText,
    toolName: 'food.search',
    dataLabel: dataLabelForTool('food.search'),
    count: foods.length
  };
}

function foodSummarySignature(summary: A2uiSummaryData): string {
  return summary.text + '|' + summary.toolName + '|' + summary.dataLabel + '|' + summary.count.toString();
}

export function foodA2uiRenderState(surfaceId: string, title: string, body: string, summaryText: string, foods: A2uiFoodData[], rows: A2uiLabelValueData[] = [], status: string = 'ready'): A2uiPartialRenderState {
  const components: A2uiComponent[] = [];
  components.push({
    id: 'root',
    component: 'SurfaceRoot',
    child: rows.length > 0 ? 'layout' : 'results',
    title: title,
    body: body,
    status: status
  });
  if (rows.length > 0) {
    components.push({
      id: 'layout',
      component: 'Column',
      children: ['summary', 'results'],
      status: status
    });
    components.push({
      id: 'summary',
      component: 'InfoRows',
      title: '来源状态',
      body: '以下只展示真实 provider 返回；失败来源不会生成占位店铺。',
      status: status,
      dataPath: '/rows',
      actions: []
    });
  }
  components.push({
    id: 'results',
    component: componentForTool('food.search'),
    title: title,
    body: body,
    status: status,
    dataPath: dataPathForTool('food.search'),
    actions: [
      { id: 'food_show_all', label: '全部范围', prompt: '显示全部附近餐饮', kind: 'client', variant: 'secondary' },
      { id: 'food_filter_1km', label: '1公里内', prompt: '只看一公里内餐饮', kind: 'client', variant: 'secondary' },
      { id: 'food_show_more', label: '展示更多', prompt: '展示更多附近餐饮', kind: 'client', variant: 'primary' },
      { id: 'food_change_keyword', label: '换关键词', prompt: '换关键词查询附近餐饮', kind: 'prompt', variant: 'secondary' },
      { id: 'food_change_location', label: '换位置', prompt: '换位置查询附近餐饮', kind: 'prompt', variant: 'secondary' }
    ]
  });
  const summary = foodSummaryData(summaryText, foods);
  const dataPatches: A2uiPartialDataPatch[] = [
    {
      path: '/foods',
      value: foods,
      signature: foodDataSignature(foods)
    },
    {
      path: '/rows',
      value: rows,
      signature: foodRowsSignature(rows)
    },
    {
      path: '/summary',
      value: summary,
      signature: foodSummarySignature(summary)
    }
  ];
  return {
    surfaceId: surfaceId,
    root: 'root',
    title: title,
    intent: 'food',
    status: status,
    sendDataModel: true,
    components: components,
    componentsSignature: 'food-result-v1|rows=' + (rows.length > 0 ? '1' : '0') + '|status=' + status,
    dataPatches: dataPatches
  };
}

export function foodStructuredDataA2ui(surfaceId: string, data: FoodStructuredData): string {
  return planA2uiPartialUpdate(null, foodA2uiRenderState(
    surfaceId, data.title, data.body, data.summary, data.foods, data.rows, 'ready'
  )).jsonl;
}

function missingConfigA2ui(surfaceId: string, toolId: string): string {
  aiLogInfo('[AIPhone][LocalToolMissingConfig] toolId=' + toolId);
  if (toolId === 'flight.search') {
    return errorA2ui(
      surfaceId,
      toolId,
      '国内航班查询需要供应商配置',
      '本机工具已收到航班查询请求。为了避免编造实时航班、票价或库存，需要在 App 本地接入飞常准或兼容航班 API Key 后才能查询。',
      ['需要配置：FLIGHT_MCP_KEY 或 VARIFLIGHT_API_KEY', '供应商方向：飞常准 VariFlight MCP/API', '建议参数：出发城市、到达城市、日期或航班号'],
      ['配置飞常准 Key', '只查询不预订']
    );
  }
  if (toolId === 'food.search') {
    return errorA2ui(
      surfaceId,
      toolId,
      '附近餐饮查询需要供应商配置',
      '本机工具已收到餐饮查询请求。为了避免编造店铺、距离或营业状态，需要在 App 本地接入高德 Web 服务 Key 和位置后才能查询。',
      ['需要配置：AMAP_KEY', '需要位置：经纬度、地点文本，或默认坐标', '供应商方向：高德 Web 服务 POI'],
      ['配置高德 Key', '换查询位置']
    );
  }
  return errorA2ui(
    surfaceId,
    toolId,
    '未知工具',
    '当前本机工具只支持航班查询、火车票查询和附近餐饮查询。',
    [],
    []
  );
}

function flightCityNames(): string[] {
  const names: string[] = [];
  for (let index = 0; index < CHINA_FLIGHT_CITY_CODES.length; index++) {
    names.push(CHINA_FLIGHT_CITY_CODES[index].city);
  }
  names.sort((left: string, right: string) => right.length - left.length);
  return names;
}

function flightCodeForCity(city: string): string {
  for (let index = 0; index < CHINA_FLIGHT_CITY_CODES.length; index++) {
    const item = CHINA_FLIGHT_CITY_CODES[index];
    if (item.city === city) {
      return item.code;
    }
  }
  return '';
}

function extractFlightCityCodes(source: string): FlightRoute {
  const routeNames = extractRouteNames(source, flightCityNames());
  if (routeNames.length < 2) {
    return {
      routeNames: routeNames,
      depCode: '',
      arrCode: ''
    };
  }
  return {
    routeNames: routeNames,
    depCode: flightCodeForCity(routeNames[0]),
    arrCode: flightCodeForCity(routeNames[1])
  };
}

function extractFlightNumber(source: string): string {
  const match = /\b[A-Z0-9]{2,3}\d{1,4}\b/.exec(source.toUpperCase());
  return match === null ? '' : match[0];
}

function firstFlightArrayFromData(data: FlightProviderData | FlightProviderItem[] | undefined): FlightProviderItem[] {
  if (data === undefined || data === null) {
    return [];
  }
  if (Array.isArray(data)) {
    return data;
  }
  return firstFlightArray([
    data.flights,
    data.flightList,
    data.list,
    data.items,
    data.records,
    data.result,
    data.results
  ]);
}

function firstFlightArray(arrays: Array<FlightProviderItem[] | undefined>): FlightProviderItem[] {
  for (let index = 0; index < arrays.length; index++) {
    const value = arrays[index];
    if (value !== undefined && value.length > 0) {
      return value;
    }
  }
  return [];
}

function flightResultsFromPayload(payload: FlightProviderPayload): FlightProviderItem[] {
  const dataResults = firstFlightArrayFromData(payload.data);
  if (dataResults.length > 0) {
    return dataResults;
  }
  return firstFlightArray([
    payload.flights,
    payload.flightList,
    payload.list,
    payload.items,
    payload.records,
    payload.result,
    payload.results
  ]);
}

function extractProviderError(payload: FlightProviderPayload): string {
  const message = firstText([payload.error, payload.message, payload.msg, payload.info, payload.errmsg]);
  const success = textOf(payload.success);
  const status = textOf(payload.status);
  if (success === 'false' || status === '0') {
    return message.length > 0 ? message : JSON.stringify(payload).substring(0, 500);
  }
  return '';
}

function parseFlightTextToA2ui(text: string): A2uiFlightData {
  const routeMatch = /\b([A-Z]{2,4})\s*->\s*([A-Z]{2,4})\b/.exec(text);
  const flightMatch = /\b[A-Z0-9]{2,3}\d{1,4}\b/.exec(text);
  const statusMatch = /状态\s+([^\s]+)/.exec(text);
  const timeMatch = /(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?)\s+-\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?)/.exec(text);
  const flightNo = flightMatch === null ? '' : flightMatch[0];
  const airline = flightNo.length > 0 ? text.substring(0, text.indexOf(flightNo)).trim() : '';
  return {
    flightNo: flightNo,
    airline: airline,
    dep: routeMatch === null ? '' : routeMatch[1],
    arr: routeMatch === null ? '' : routeMatch[2],
    depTime: timeMatch === null ? '' : timeMatch[1],
    arrTime: timeMatch === null ? '' : timeMatch[2],
    status: statusMatch === null ? '计划' : statusMatch[1],
    price: ''
  };
}

export function flightRecordForA2ui(item: FlightProviderRecord | string): A2uiFlightData {
  if (typeof item === 'string') {
    const trimmed = item.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return flightRecordForA2ui(JSON.parse(trimmed) as FlightProviderRecord);
      } catch (_error) {
        return parseFlightTextToA2ui(trimmed);
      }
    }
    return parseFlightTextToA2ui(trimmed);
  }
  const flightNo = firstText([item.FlightNo, item.flightNo, item.flight_no, item.fnum, item.Fnum, item.flightNumber, item.flight_number, item.flight]);
  return {
    flightNo: flightNo,
    airline: firstText([item.FlightCompany, item.airline, item.airlineName, item.AirlineName, item.carrier, item.carrierName]),
    dep: firstText([item.FlightDepAirport, item.depAirportName, item.depAirport, item.departureAirport, item.departure, item.dep, item.dep_city, item.FlightDepcode]),
    arr: firstText([item.FlightArrAirport, item.arrAirportName, item.arrAirport, item.arrivalAirport, item.arrival, item.arr, item.arr_city, item.FlightArrcode]),
    depTime: firstText([item.FlightDeptimePlanDate, item.FlightDeptimeReadyDate, item.FlightDeptimeDate, item.FlightDepTime, item.depTime, item.dep_time, item.departureTime, item.std, item.scheduleDepTime]),
    arrTime: firstText([item.FlightArrtimePlanDate, item.FlightArrtimeReadyDate, item.FlightArrtimeDate, item.FlightArrTime, item.arrTime, item.arr_time, item.arrivalTime, item.sta, item.scheduleArrTime]),
    status: firstText([item.FlightState, item.FlightStatus, item.status, item.flightStatus, item.state]),
    price: firstText([item.price, item.Price, item.lowestPrice, item.LowestPrice, item.fare, item.amount])
  };
}

function flightRecordHasData(item: A2uiFlightData): boolean {
  return item.flightNo.length > 0 ||
    item.airline.length > 0 ||
    item.dep.length > 0 ||
    item.arr.length > 0 ||
    item.depTime.length > 0 ||
    item.arrTime.length > 0;
}

function localAdapterSource(provider: string, operation: string): DataSource {
  return {
    provider: provider,
    backend: 'local_adapter',
    operation: operation,
    fetchedAt: new Date().toISOString()
  };
}

function structuredErrorWithData(
  toolId: string,
  outputSchema: string,
  data: Object,
  code: string,
  message: string,
  retryable: boolean = false,
  sources: DataSource[] = [],
  warnings: string[] = []
): DataResult {
  const result = errorDataResult(toolId, outputSchema, code, message, retryable, sources);
  result.data = data;
  result.warnings = warnings.slice();
  return result;
}

function sourceAlreadyIncluded(sources: DataSource[], provider: string, operation: string): boolean {
  return sources.some((source: DataSource): boolean =>
    source.provider === provider && source.operation === operation);
}

function genericResultSource(result: DynamicGenericToolResult): DataSource {
  return {
    provider: result.sourceTag,
    backend: result.sourceTag.startsWith('Composio') ? 'oauth_api' : 'local_adapter',
    operation: result.toolName,
    fetchedAt: new Date().toISOString()
  };
}

function genericResultHasData(result: DynamicGenericToolResult): boolean {
  if (result.status !== 'success') {
    return false;
  }
  if (mediaVideoPlaybackUrl(result as A2uiGenericToolResultData).length > 0) {
    return true;
  }
  if (result.title.indexOf('没有找到') >= 0 || result.rawPreview === 'empty places') {
    return false;
  }
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === '结果数量' && result.rows[index].value.trim() === '0') {
      return false;
    }
  }
  return result.rows.length > 0 || result.rawPreview.trim().length > 0;
}

function genericResultIsFailure(result: DynamicGenericToolResult): boolean {
  return result.status !== 'success' && result.status !== 'empty';
}

function firstGenericFailure(results: DynamicGenericToolResult[]): string {
  for (let index = 0; index < results.length; index++) {
    if (genericResultIsFailure(results[index])) {
      return results[index].summary.length > 0 ? results[index].summary : results[index].title;
    }
  }
  return 'Provider returned no successful result.';
}

export function genericStructuredDataResult(
  toolId: string,
  outputSchema: string,
  results: DynamicGenericToolResult[]
): DataResult {
  const data: GenericStructuredData = { results: results };
  const sources: DataSource[] = [];
  const warnings: string[] = [];
  let dataCount = 0;
  let failureCount = 0;
  results.forEach((result: DynamicGenericToolResult) => {
    if (genericResultHasData(result)) {
      dataCount += 1;
    }
    if (genericResultIsFailure(result)) {
      failureCount += 1;
      warnings.push(result.sourceTag + '：' + (result.summary.length > 0 ? result.summary : result.title));
    }
    if (!sourceAlreadyIncluded(sources, result.sourceTag, result.toolName)) {
      sources.push(genericResultSource(result));
    }
  });
  if (dataCount > 0) {
    return failureCount > 0 ?
      partialDataResult(toolId, outputSchema, data, sources, warnings) :
      successfulDataResult(toolId, outputSchema, data, sources);
  }
  if (failureCount > 0) {
    return structuredErrorWithData(
      toolId, outputSchema, data, 'PROVIDER_ERROR', firstGenericFailure(results), false, sources, warnings
    );
  }
  const empty = successfulDataResult(toolId, outputSchema, data, sources);
  empty.status = 'empty';
  return empty;
}

function remainingReadText(result: DynamicGenericToolResult): string {
  return (result.title + ' ' + result.summary).toLowerCase();
}

function remainingReadAuthFailure(result: DynamicGenericToolResult): boolean {
  const text = remainingReadText(result).replace(/\s+/g, ' ').trim();
  return result.status === 'needs_auth' ||
    text.indexOf('oauth') >= 0 || text.indexOf('未授权') >= 0 || text.indexOf('未配置') >= 0 ||
    text.indexOf('disconnected') >= 0 || text.indexOf('access token') >= 0 ||
    text.indexOf('mcp key') >= 0 || text.indexOf('_token') >= 0 ||
    text.indexOf('没有 active connected account') >= 0 || text.indexOf('no active connection found') >= 0;
}

function remainingReadInputFailure(result: DynamicGenericToolResult): boolean {
  const text = remainingReadText(result);
  return result.status === 'needs_input' || text.indexOf('缺少订单号') >= 0 || text.indexOf('order_id') >= 0 ||
    text.indexOf('需要补充起点') >= 0 || text.indexOf('需要补充城市') >= 0 ||
    text.indexOf('requestkey') >= 0 || text.indexOf('threadid') >= 0 ||
    text.indexOf('required input') >= 0;
}

function remainingReadRetryable(result: DynamicGenericToolResult): boolean {
  const text = remainingReadText(result);
  return text.indexOf('timeout') >= 0 || text.indexOf('timed out') >= 0 ||
    text.indexOf('transport') >= 0 || text.indexOf('http 5') >= 0 ||
    text.indexOf('failed to resolve') >= 0 || text.indexOf('network') >= 0;
}

function remainingReadSource(result: DynamicGenericToolResult): DataSource {
  const lower = result.sourceTag.toLowerCase();
  let backend: ToolBackendType = 'local_adapter';
  if (lower.indexOf('gmail') >= 0 || lower.indexOf('calendar') >= 0 ||
    lower.indexOf('youtube') >= 0 || lower.indexOf('composio') >= 0) {
    backend = 'oauth_api';
  } else if (lower.indexOf('qq') >= 0) {
    backend = 'imap';
  }
  return {
    provider: result.sourceTag,
    backend: backend,
    operation: result.toolName,
    fetchedAt: new Date().toISOString()
  };
}

export function remainingReadStructuredDataResult(
  toolId: string,
  outputSchema: string,
  results: DynamicGenericToolResult[]
): DataResult {
  const data: GenericStructuredData = { results: results };
  const sources: DataSource[] = [];
  const warnings: string[] = [];
  let dataCount = 0;
  let failureCount = 0;
  let authCount = 0;
  let inputCount = 0;
  let retryable = false;
  results.forEach((result: DynamicGenericToolResult) => {
    if (genericResultHasData(result)) {
      dataCount += 1;
    }
    if (genericResultIsFailure(result)) {
      failureCount += 1;
      if (remainingReadAuthFailure(result)) {
        authCount += 1;
      } else if (remainingReadInputFailure(result)) {
        inputCount += 1;
      }
      if (remainingReadRetryable(result)) {
        retryable = true;
      }
      warnings.push(result.sourceTag + '：' + (result.summary.length > 0 ? result.summary : result.title));
    }
    if (result.providerPhase === 'execution' &&
      !sourceAlreadyIncluded(sources, result.sourceTag, result.toolName)) {
      sources.push(remainingReadSource(result));
    }
  });
  if (dataCount > 0) {
    return failureCount > 0 ?
      partialDataResult(toolId, outputSchema, data, sources, warnings) :
      successfulDataResult(toolId, outputSchema, data, sources);
  }
  if (failureCount > 0) {
    let code = 'PROVIDER_ERROR';
    if (authCount === failureCount) {
      code = 'AUTH_REQUIRED';
    } else if (inputCount === failureCount) {
      code = 'INPUT_REQUIRED';
    }
    return structuredErrorWithData(
      toolId, outputSchema, data, code, firstGenericFailure(results), retryable, sources, warnings
    );
  }
  const empty = successfulDataResult(toolId, outputSchema, data, sources);
  empty.status = 'empty';
  return empty;
}

export function mapsStructuredDataResult(toolId: string, provider: MapsPlaceProviderResult): DataResult {
  const outputSchema = toolId === 'maps.place.details' ? 'place' : 'places';
  const entityRefs: string[] = [];
  if (provider.status === 'success') {
    for (let index = 0; index < provider.places.length && entityRefs.length < 16; index++) {
      const placeId: string = provider.places[index].placeId;
      if (placeId.trim().length > 0 && entityRefs.indexOf(placeId) < 0) {
        entityRefs.push(placeId);
      }
    }
  }
  const data: MapsStructuredData = {
    places: provider.places,
    query: provider.query,
    entityRefs
  };
  const sources: DataSource[] = provider.attempted ? [localAdapterSource('Google Places API',
    toolId === 'maps.place.details' ? 'details' : 'search')] : [];
  if (provider.status === 'error') {
    return structuredErrorWithData(
      toolId,
      outputSchema,
      data,
      provider.attempted ? 'MAPS_PROVIDER_ERROR' : 'MAPS_INPUT_OR_CONFIG_ERROR',
      provider.message,
      provider.attempted,
      sources
    );
  }
  const result = successfulDataResult(toolId, outputSchema, data, sources);
  if (provider.status === 'empty') {
    result.status = 'empty';
    result.warnings = provider.message.length > 0 ? [provider.message] : [];
  }
  return result;
}

export function mapsDataResultA2ui(surfaceId: string, result: DataResult): string {
  const data = result.data as MapsStructuredData;
  const provider: MapsPlaceProviderResult = {
    toolId: result.toolId,
    status: result.status === 'error' ? 'error' : (data.places.length > 0 ? 'success' : 'empty'),
    places: data.places,
    query: data.query,
    message: result.error?.message === undefined ?
      (result.warnings.length > 0 ? result.warnings[0] : '') : result.error.message,
    attempted: result.sources.length > 0
  };
  return genericToolResultsA2ui(surfaceId, result.toolId, mapsPlaceProviderResultsForA2ui(provider));
}

function aggregateStatusFailed(status: AggregateSearchSourceStatus): boolean {
  return status.status === 'error' || status.status === 'needs_auth' || status.status === 'unsupported';
}

export function aggregateStructuredDataResult(data: AggregateSearchResult): DataResult {
  const sources: DataSource[] = data.sourceStatuses.map((status: AggregateSearchSourceStatus): DataSource => ({
    provider: status.label,
    backend: status.source === 'x' || status.source === 'hackernews' || status.source === 'reddit' ?
      'oauth_api' : 'local_adapter',
    operation: 'search',
    fetchedAt: new Date().toISOString()
  }));
  const warnings = data.sourceStatuses
    .filter((status: AggregateSearchSourceStatus): boolean => aggregateStatusFailed(status))
    .map((status: AggregateSearchSourceStatus): string => status.label + '：' + status.message);
  const itemCount = data.videos.length + data.posts.length;
  if (itemCount > 0) {
    return warnings.length > 0 ?
      partialDataResult('media.aggregate.search', 'aggregateSearch', data, sources, warnings) :
      successfulDataResult('media.aggregate.search', 'aggregateSearch', data, sources);
  }
  if (warnings.length > 0) {
    return structuredErrorWithData(
      'media.aggregate.search', 'aggregateSearch', data, 'AGGREGATE_PROVIDERS_FAILED',
      warnings.join('；'), false, sources, warnings
    );
  }
  const empty = successfulDataResult('media.aggregate.search', 'aggregateSearch', data, sources);
  empty.status = 'empty';
  return empty;
}

function socialConnectionFailed(connection: SocialHubConnectionData): boolean {
  return connection.status !== 'connected';
}

function socialConnectionAttempted(connection: SocialHubConnectionData): boolean {
  return connection.status === 'connected' || connection.status === 'error';
}

function socialConnectionUnsupported(connection: SocialHubConnectionData): boolean {
  return connection.status === 'limited' || connection.status === 'disabled';
}

export function socialHubStructuredDataResult(
  feed: SocialHubFeedResult,
  toolId: string = 'social.feed.search'
): DataResult {
  const data: SocialHubStructuredData = { items: feed.items, connections: feed.connections };
  const sources: DataSource[] = feed.connections
    .filter((connection: SocialHubConnectionData): boolean => socialConnectionAttempted(connection))
    .map((connection: SocialHubConnectionData): DataSource => ({
      provider: connection.displayName.length > 0 ? connection.displayName : connection.platform,
      backend: 'oauth_api',
      operation: 'feed',
      fetchedAt: new Date().toISOString(),
      accountHint: connection.accountId
    }));
  const warnings = feed.connections
    .filter((connection: SocialHubConnectionData): boolean => socialConnectionFailed(connection))
    .map((connection: SocialHubConnectionData): string =>
      (connection.displayName.length > 0 ? connection.displayName : connection.platform) + '：' + connection.message);
  if (feed.items.length > 0) {
    return warnings.length > 0 ?
      partialDataResult(toolId, 'socialHubFeed', data, sources, warnings) :
      successfulDataResult(toolId, 'socialHubFeed', data, sources);
  }
  const attemptedFailure = feed.connections.some((connection: SocialHubConnectionData): boolean =>
    connection.status === 'error');
  if (attemptedFailure) {
    return structuredErrorWithData(
      toolId, 'socialHubFeed', data, 'SOCIAL_PROVIDERS_FAILED', warnings.join('；'), false, sources, warnings
    );
  }
  if (sources.length === 0 && feed.connections.length > 0 &&
    feed.connections.every((connection: SocialHubConnectionData): boolean => socialConnectionUnsupported(connection))) {
    return structuredErrorWithData(
      toolId, 'socialHubFeed', data, 'SOCIAL_SOURCES_UNSUPPORTED', warnings.join('；'), false, [], warnings
    );
  }
  const empty = successfulDataResult(toolId, 'socialHubFeed', data, sources);
  empty.status = 'empty';
  empty.warnings = warnings;
  return empty;
}

function flightErrorData(title: string, body: string): FlightStructuredData {
  return { title: title, body: body, summary: body, flights: [] };
}

export function flightDataResultFromProviderResponse(
  responseCode: number,
  responseText: string,
  source: DataSource,
  wantsPrice: boolean,
  routeText: string,
  requestDiagnostic: string = ''
): DataResult {
  const sources: DataSource[] = [source];
  let payload: FlightProviderPayload = {};
  try {
    payload = JSON.parse(responseText) as FlightProviderPayload;
  } catch (_error) {
    const message = '飞常准返回的内容不是 JSON。为避免编造航班信息，当前只展示原始返回摘要。';
    return structuredErrorWithData(
      'flight.search', 'flights', flightErrorData('飞常准返回格式异常', message),
      'FLIGHT_INVALID_RESPONSE', message, false, sources, [responseText.substring(0, 700)]
    );
  }

  if (responseCode < 200 || responseCode >= 300) {
    const message = '飞常准返回 HTTP ' + responseCode.toString() + '。当前只展示供应商返回的真实错误。';
    return structuredErrorWithData(
      'flight.search', 'flights', flightErrorData('飞常准航班查询失败', message),
      'FLIGHT_PROVIDER_HTTP_ERROR', message, responseCode >= 500, sources, [responseText.substring(0, 700)]
    );
  }

  const providerError = extractProviderError(payload);
  if (providerError.length > 0) {
    return structuredErrorWithData(
      'flight.search', 'flights', flightErrorData('飞常准 Key 或参数需要检查', providerError),
      'FLIGHT_PROVIDER_ERROR', providerError, false, sources,
      requestDiagnostic.length > 0 ? [requestDiagnostic.substring(0, 240)] : []
    );
  }

  const results = flightResultsFromPayload(payload);
  const flights: A2uiFlightData[] = [];
  const count = results.length > 8 ? 8 : results.length;
  for (let index = 0; index < count; index++) {
    const record = flightRecordForA2ui(results[index]);
    if (record.status.length === 0) {
      record.status = '计划';
    }
    if (flightRecordHasData(record)) {
      flights.push(record);
    }
  }

  aiLogInfo('[AIPhone][LocalToolFlightResult] providerCode=' + responseCode.toString() +
    ' rows=' + results.length.toString() + ' returned=' + flights.length.toString());
  if (flights.length === 0) {
    const message = '供应商请求成功，但没有返回可展示的航班列表。';
    return flightStructuredDataResult({
      title: '飞常准未返回航班列表',
      body: message,
      summary: message,
      flights: []
    }, sources, [message]);
  }

  return flightStructuredDataResult({
    title: wantsPrice ? '飞常准航班价格查询' : '飞常准航班查询',
    body: '以下为飞常准返回的查询结果。',
    summary: '已通过飞常准查询到 ' + routeText + ' 的航班信息。',
    flights: flights
  }, sources);
}

async function callStructuredFlightTool(prompt: string): Promise<DataResult> {
  const apiKey = localProviderConfig.flightMcpKey;
  if (apiKey.length === 0) {
    return structuredErrorWithData(
      'flight.search',
      'flights',
      flightErrorData('飞常准未配置', '缺少 FLIGHT_MCP_KEY。'),
      'FLIGHT_CONFIG_MISSING',
      '缺少 FLIGHT_MCP_KEY。'
    );
  }

  const source = prompt;
  const date = calendarDateFromPrompt(source);
  const flightNumber = extractFlightNumber(source);
  const flightRoute = extractFlightCityCodes(source);
  const wantsPrice = /票价|价格|多少钱|最低价|机票/.test(source);
  if (date.length === 0 || (flightNumber.length === 0 && (flightRoute.depCode.length === 0 || flightRoute.arrCode.length === 0))) {
    const message = '飞常准查询需要明确的日期，并提供航班号，或提供出发城市和到达城市。';
    return structuredErrorWithData(
      'flight.search', 'flights', flightErrorData('飞常准查询参数不足', message),
      'FLIGHT_INVALID_ARGUMENTS',
      '飞常准查询需要明确的日期，并提供航班号，或提供出发城市和到达城市。',
      false
    );
  }

  let requestBody = '';
  let routeText = '';
  let operation = '';
  if (flightNumber.length > 0) {
    operation = 'flight';
    requestBody = '{"endpoint":"flight","params":{"fnum":' + JSON.stringify(flightNumber) +
      ',"date":' + JSON.stringify(date) + '}}';
    routeText = flightNumber + ' ' + date;
  } else if (wantsPrice) {
    operation = 'getFlightPriceByCities';
    requestBody = '{"endpoint":"getFlightPriceByCities","params":{"dep_city":' + JSON.stringify(flightRoute.depCode) +
      ',"arr_city":' + JSON.stringify(flightRoute.arrCode) +
      ',"dep_date":' + JSON.stringify(date) +
      ',"price_mode":"lowest"}}';
    routeText = flightRoute.routeNames[0] + ' 到 ' + flightRoute.routeNames[1] + ' ' + date;
  } else {
    operation = 'flights';
    requestBody = '{"endpoint":"flights","params":{"depcity":' + JSON.stringify(flightRoute.depCode) +
      ',"arrcity":' + JSON.stringify(flightRoute.arrCode) +
      ',"date":' + JSON.stringify(date) + '}}';
    routeText = flightRoute.routeNames[0] + ' 到 ' + flightRoute.routeNames[1] + ' ' + date;
  }

  const endpoint = localProviderConfig.variflightApiUrl.length > 0 ? localProviderConfig.variflightApiUrl : DEFAULT_VARIFLIGHT_API_URL;
  aiLogInfo('[AIPhone][LocalToolFlightRequest] endpoint=' + endpoint + ' keyChars=' + apiKey.length.toString() + ' bodyChars=' + requestBody.length.toString());
  let response: HttpTextResponse;
  try {
    response = await postJsonText(endpoint, {
      'Content-Type': 'application/json',
      'X-VARIFLIGHT-KEY': apiKey
    }, requestBody);
  } catch (error) {
    const message = describeThrown(error);
    return structuredErrorWithData(
      'flight.search', 'flights', flightErrorData('飞常准航班查询失败', message),
      'FLIGHT_TRANSPORT_EXCEPTION', message, true
    );
  }
  return flightDataResultFromProviderResponse(
    response.code,
    response.text,
    localAdapterSource('飞常准', operation),
    wantsPrice,
    routeText,
    requestBody
  );
}

export function flightDataResultA2ui(surfaceId: string, result: DataResult): string {
  const data = result.data as FlightStructuredData;
  if (result.status === 'error') {
    const code = result.error?.code === undefined ? '' : result.error?.code;
    if (code === 'FLIGHT_CONFIG_MISSING') {
      return missingConfigA2ui(surfaceId, 'flight.search');
    }
    if (code === 'FLIGHT_INVALID_ARGUMENTS') {
      return errorA2ui(
        surfaceId, 'flight.search', data.title, data.body,
        ['示例：明天北京到上海航班', '示例：2026-06-10 深圳到杭州机票价格', '示例：明天 MU2157 航班'],
        ['补充日期', '补充城市']
      );
    }
    if (code === 'FLIGHT_TRANSPORT_EXCEPTION') {
      return legacyToolExceptionA2ui(surfaceId, 'flight.search', data.body);
    }
    const details = result.warnings.length > 0 ? result.warnings : [data.summary];
    if (code === 'FLIGHT_INVALID_RESPONSE') {
      return errorA2ui(
        surfaceId, 'flight.search', data.title, data.body, details, ['重新查询', '检查供应商返回']
      );
    }
    if (code === 'FLIGHT_PROVIDER_HTTP_ERROR') {
      return errorA2ui(
        surfaceId, 'flight.search', data.title, data.body, details, ['重新查询', '检查飞常准 Key']
      );
    }
    if (code === 'FLIGHT_PROVIDER_ERROR') {
      return errorA2ui(
        surfaceId, 'flight.search', data.title, data.body, details, ['检查 Key', '换日期或城市']
      );
    }
    return errorA2ui(
      surfaceId, 'flight.search', data.title, data.body, details, ['重新查询', '换日期或城市']
    );
  }
  return flightStructuredDataA2ui(surfaceId, data);
}

async function callLocalFlightSearch(prompt: string, surfaceId: string): Promise<string> {
  return flightDataResultA2ui(surfaceId, await callStructuredFlightTool(prompt));
}

function parseCoordinatePair(text: string): string {
  const match = /(-?\d{2,3}\.\d+)\s*,\s*(-?\d{1,2}\.\d+)/.exec(text);
  if (match === null) {
    return '';
  }
  return match[1] + ',' + match[2];
}

function defaultConfiguredLocation(): string {
  return parseCoordinatePair(localProviderConfig.amapDefaultLocation);
}

function extractFoodQuery(source: string): FoodQuery {
  const cleaned = source.trim().replace(/^帮我(?:搜索|查|找|搜)?/u, '').trim();
  const nearPatterns: RegExp[] = [
    /^(.+?)附近(?:的)?(.+)$/u,
    /^(.+?)周边(?:的)?(.+)$/u,
    /^(.+?)周围(?:的)?(.+)$/u
  ];
  for (let index = 0; index < nearPatterns.length; index++) {
    const match = nearPatterns[index].exec(cleaned);
    if (match !== null && match[1].trim().length > 0 && match[2].trim().length > 0) {
      return {
        place: match[1].trim(),
        keyword: match[2].trim()
      };
    }
  }
  return {
    place: '',
    keyword: ''
  };
}

function extractFoodKeyword(source: string): string {
  const query = extractFoodQuery(source);
  if (query.keyword.length > 0) {
    return query.keyword;
  }
  const preset = /椰子鸡|椰子|火锅|烧烤|咖啡|奶茶|晚餐|午餐|早餐|快餐|餐厅|饭店|美食/u.exec(source);
  if (preset !== null) {
    return preset[0];
  }
  return '餐饮';
}

function normalizeFoodSearchKeyword(value: string): string {
  return value.trim()
    .replace(/^附近(?:的)?/u, '')
    .replace(/^周边(?:的)?/u, '')
    .replace(/(?:门店|餐厅|店)$/u, '')
    .trim();
}

function splitFoodSearchKeywords(keyword: string): string[] {
  const cleaned = normalizeFoodSearchKeyword(keyword);
  const keywords: string[] = [];
  if (cleaned.length === 0) {
    keywords.push('餐饮');
    return keywords;
  }
  const parts = cleaned.split(/和|及|与|、|，|,|\/|或/u);
  for (let index = 0; index < parts.length; index++) {
    const part = normalizeFoodSearchKeyword(parts[index]);
    if (part.length > 0) {
      appendUniqueText(keywords, part);
    }
  }
  if (keywords.length === 0) {
    keywords.push(cleaned);
  }
  return keywords;
}

function inferAmapCityFromPlace(place: string): string {
  const match = /^(北京|上海|天津|重庆|深圳|广州|杭州|成都|武汉|南京|西安|东莞|佛山)/u.exec(place);
  return match === null ? '' : match[1];
}

function emptyAmapLocationResolution(source: string = 'none'): AmapLocationResolution {
  return { location: '', locationSource: source, locationLabel: '', city: '' };
}

function rideDidiCityText(city: string): string {
  const trimmed = city.trim();
  if (trimmed === '[]') {
    return '';
  }
  if (trimmed.length > 1 && trimmed.endsWith('市')) {
    return trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

function amapScalarText(value: Object | string | number | boolean | null | undefined): string {
  if (Array.isArray(value)) {
    return '';
  }
  return textOf(value).trim();
}

function amapResolutionCityFromGeocode(first: AmapGeocode): string {
  const city = amapScalarText(first.city);
  return city.length > 0 ? city : amapScalarText(first.province);
}

function amapResolutionCityFromPoi(first: AmapPoi): string {
  return firstText([first.cityname, first.pname]).trim();
}

function amapResolutionFromGeocodePayload(payload: AmapPayload): AmapLocationResolution {
  if (textOf(payload.status) !== '1') {
    return emptyAmapLocationResolution();
  }
  const geocodes = payload.geocodes === undefined ? [] : payload.geocodes;
  if (geocodes.length === 0) {
    return emptyAmapLocationResolution();
  }
  const first = geocodes[0];
  return {
    location: textOf(first.location),
    locationSource: 'geocode',
    locationLabel: firstText([first.formatted_address, first.level]),
    city: amapResolutionCityFromGeocode(first)
  };
}

function isLandmarkPlace(place: string): boolean {
  return /华为|基地|园区|总部|云谷|大学|医院|站|广场|大厦|小区/u.test(place);
}

async function amapJsonGet(url: string): Promise<AmapPayload> {
  const response = await requestText(url, userAgentHeaders());
  if (response.code < 200 || response.code >= 300) {
    throw new Error('Amap HTTP ' + response.code.toString());
  }
  return JSON.parse(response.text) as AmapPayload;
}

async function geocodeAmapAddress(address: string, key: string, cityHint: string = ''): Promise<AmapLocationResolution> {
  const trimmed = address.trim();
  if (trimmed.length === 0 || key.length === 0) {
    return emptyAmapLocationResolution();
  }
  const city = cityHint.trim().length > 0 ? cityHint.trim() : inferAmapCityFromPlace(trimmed);
  const payload = await amapJsonGet(buildQueryUrl(
    'https://restapi.amap.com/v3/geocode/geo',
    ['key', 'address', 'city'],
    [key, trimmed, city]
  ));
  return amapResolutionFromGeocodePayload(payload);
}

async function searchAmapPoiLocation(keywords: string, city: string, key: string): Promise<AmapLocationResolution> {
  const trimmed = keywords.trim();
  if (trimmed.length === 0 || key.length === 0) {
    return emptyAmapLocationResolution();
  }
  const payload = await amapJsonGet(buildQueryUrl(
    'https://restapi.amap.com/v3/place/text',
    ['key', 'keywords', 'city', 'offset', 'page'],
    [key, trimmed, city, '5', '1']
  ));
  if (textOf(payload.status) !== '1') {
    return emptyAmapLocationResolution();
  }
  const pois = payload.pois === undefined ? [] : payload.pois;
  if (pois.length === 0) {
    return emptyAmapLocationResolution();
  }
  const first = pois[0];
  return {
    location: textOf(first.location),
    locationSource: 'poi_text',
    locationLabel: firstText([first.name, first.address]),
    city: amapResolutionCityFromPoi(first)
  };
}

async function resolveFoodSearchLocation(place: string, key: string): Promise<AmapLocationResolution> {
  const city = inferAmapCityFromPlace(place).length > 0 ? inferAmapCityFromPlace(place) : '深圳';
  if (isLandmarkPlace(place)) {
    const poi = await searchAmapPoiLocation(place, city, key);
    if (poi.location.length > 0) {
      return poi;
    }
  }
  const geo = await geocodeAmapAddress(place, key);
  if (geo.location.length > 0) {
    return geo;
  }
  const poi = await searchAmapPoiLocation(place, city, key);
  if (poi.location.length > 0) {
    return poi;
  }
  return emptyAmapLocationResolution();
}

function foodRecordForA2ui(item: AmapPoi): A2uiFoodData {
  const distance = textOf(item.distance);
  return {
    name: textOf(item.name),
    category: textOf(item.type),
    address: textOf(item.address),
    distance: distance.length > 0 ? distance + '米' : '',
    location: textOf(item.location),
    sourceTags: ['高德']
  };
}

function mapPointLocation(point: FoodMapPoint | undefined): string {
  if (point === undefined || point === null) {
    return '';
  }
  const longitude = textOf(point.lng);
  const latitude = textOf(point.lat);
  if (longitude.length === 0 || latitude.length === 0) {
    return '';
  }
  return longitude + ',' + latitude;
}

export function foodRecordFromTencentMapPlace(item: TencentMapPlace): A2uiFoodData {
  return {
    name: textOf(item.title),
    category: textOf(item.category),
    address: textOf(item.address),
    distance: meterDistanceText(firstText([item._distance, item.distance])),
    location: mapPointLocation(item.location),
    sourceTags: ['腾讯地图']
  };
}

export function foodRecordFromBaiduPlace(item: BaiduPlace): A2uiFoodData {
  const detail = item.detail_info === undefined ? null : item.detail_info;
  const rating = detail === null ? '' : textOf(detail.overall_rating);
  const price = detail === null ? '' : textOf(detail.price);
  return {
    name: textOf(item.name),
    category: detail === null ? '' : textOf(detail.tag),
    address: joinFoodParts([
      textOf(item.address),
      rating.length > 0 ? '评分' + rating : '',
      price.length > 0 ? '人均¥' + price : ''
    ]),
    distance: meterDistanceText(detail === null ? '' : detail.distance),
    location: mapPointLocation(item.location),
    sourceTags: ['百度地图']
  };
}

function joinFoodParts(parts: string[]): string {
  let value = '';
  for (let index = 0; index < parts.length; index++) {
    const part = parts[index].trim();
    if (part.length === 0) {
      continue;
    }
    value = value.length > 0 ? value + ' · ' + part : part;
  }
  return value;
}

function meituanDistanceText(value: Object | string | number | boolean | null | undefined): string {
  const text = textOf(value).trim();
  if (text.length === 0) {
    return '';
  }
  if (/米|千米|公里|km/i.test(text)) {
    return text.replace(/km/ig, '千米').replace(/公里/g, '千米');
  }
  return text + '千米';
}

function meterDistanceText(value: Object | string | number | boolean | null | undefined): string {
  const text = textOf(value).trim();
  if (text.length === 0) {
    return '';
  }
  if (/米|千米|公里|km/i.test(text)) {
    return text.replace(/km/ig, '千米').replace(/公里/g, '千米');
  }
  return text + '米';
}

function deliveryFeeText(label: string, value: Object | string | number | boolean | null | undefined): string {
  const text = textOf(value).trim();
  if (text.length === 0) {
    return '';
  }
  if (/元$/.test(text)) {
    return label + text;
  }
  return label + text + '元';
}

function minutesText(label: string, value: Object | string | number | boolean | null | undefined): string {
  const text = textOf(value).trim();
  if (text.length === 0) {
    return '';
  }
  if (/分钟|小时/.test(text)) {
    return label + text;
  }
  return label + text + '分钟';
}

export function foodRecordFromMeituanUnion(item: MeituanUnionRecord): A2uiFoodData {
  const brand = item.brandInfo === undefined ? '' : textOf(item.brandInfo.brandName);
  const coupon = item.couponPackDetail === undefined ? '' : firstText([item.couponPackDetail.name, item.couponPackDetail.productName]);
  const poi = item.deliverablePoiInfo === undefined ? null : item.deliverablePoiInfo;
  const name = firstText([
    poi === null ? '' : poi.poiName,
    item.name,
    item.title,
    brand
  ]);
  const salePrice = item.couponPackDetail === undefined ? '' : textOf(item.couponPackDetail.sellPrice);
  const saleVolume = item.couponPackDetail === undefined ? '' : textOf(item.couponPackDetail.saleVolume);
  const category = joinFoodParts([
    coupon,
    firstText([item.categoryName, brand]),
    salePrice.length > 0 ? '券价¥' + salePrice : '',
    saleVolume.length > 0 ? '销量' + saleVolume : ''
  ]);
  const distributionCost = firstText([
    poi === null ? '' : poi.distributionCost,
    item.distributionCost
  ]);
  const deliveryDuration = firstText([
    poi === null ? '' : poi.deliveryDuration,
    item.deliveryDuration
  ]);
  const lastDeliveryFee = firstText([
    poi === null ? '' : poi.lastDeliveryFee,
    item.lastDeliveryFee
  ]);
  const distance = firstText([
    poi === null ? '' : poi.deliveryDistance,
    item.deliveryDistance
  ]);
  return {
    name: name,
    category: category,
    address: joinFoodParts([
      deliveryFeeText('配送费', distributionCost),
      minutesText('预计', deliveryDuration),
      deliveryFeeText('起送', lastDeliveryFee)
    ]),
    distance: meituanDistanceText(distance),
    sourceTags: ['美团']
  };
}

export function foodRecordFromTaobaoFlashStore(item: TaobaoFlashStoreRecord): A2uiFoodData {
  const items: TaobaoFlashItemRecord[] = item.items !== undefined && item.items.length > 0 ? item.items :
    (item.item_list !== undefined ? item.item_list : []);
  const firstItem: TaobaoFlashItemRecord | null = items.length > 0 ? items[0] : null;
  const itemTitle = firstItem === null ? '' : textOf(firstItem.title);
  const itemPrice = firstItem === null ? '' : textOf(firstItem.price);
  return {
    name: firstText([item.title, item.shop_name, item.name]),
    category: joinFoodParts([
      firstText([item.category_1_name, item.category_name]),
      itemTitle,
      itemPrice.length > 0 ? '¥' + itemPrice : ''
    ]),
    address: joinFoodParts([
      textOf(item.service_rating).length > 0 ? '评分' + textOf(item.service_rating) : (textOf(item.rating).length > 0 ? '评分' + textOf(item.rating) : ''),
      deliveryFeeText('配送费', item.delivery_price),
      minutesText('预计', item.delivery_time)
    ]),
    distance: meterDistanceText(firstText([item.delivery_distance, item.distance])),
    sourceTags: ['淘宝闪购']
  };
}

function mcDonaldsStoresFromData(value: McDonaldsStoreRecord[] | McDonaldsStoreContainer | undefined): McDonaldsStoreRecord[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  const container = value as McDonaldsStoreContainer;
  const arrays: Array<McDonaldsStoreRecord[] | undefined> = [
    container.list,
    container.records,
    container.items,
    container.products,
    container.data,
    container.result
  ];
  for (let index = 0; index < arrays.length; index++) {
    const raw = arrays[index];
    if (raw !== undefined && raw.length > 0) {
      return raw;
    }
  }
  return [];
}

function mcDonaldsCouponsFromData(value: McDonaldsCouponRecord[] | McDonaldsCouponContainer | undefined): McDonaldsCouponRecord[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  const container = value as McDonaldsCouponContainer;
  const arrays: Array<McDonaldsCouponRecord[] | undefined> = [
    container.list,
    container.records,
    container.items,
    container.products,
    container.data,
    container.result
  ];
  for (let index = 0; index < arrays.length; index++) {
    const raw = arrays[index];
    if (raw !== undefined && raw.length > 0) {
      return raw;
    }
  }
  return [];
}

function luckinShopsFromData(value: LuckinShopRecord[] | LuckinShopContainer | undefined): LuckinShopRecord[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  const container = value as LuckinShopContainer;
  const arrays: Array<LuckinShopRecord[] | undefined> = [
    container.list,
    container.records,
    container.items,
    container.products,
    container.data,
    container.result
  ];
  for (let index = 0; index < arrays.length; index++) {
    const raw = arrays[index];
    if (raw !== undefined && raw.length > 0) {
      return raw;
    }
  }
  return [];
}

function luckinProductsFromData(value: LuckinProductRecord[] | LuckinProductContainer | undefined): LuckinProductRecord[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  const container = value as LuckinProductContainer;
  const arrays: Array<LuckinProductRecord[] | undefined> = [
    container.list,
    container.records,
    container.items,
    container.products,
    container.data,
    container.result
  ];
  for (let index = 0; index < arrays.length; index++) {
    const raw = arrays[index];
    if (raw !== undefined && raw.length > 0) {
      return raw;
    }
  }
  return [];
}

function mcpPayloadData(payload: McDonaldsPayload | LuckinPayload): McDonaldsMcpData | LuckinMcpData | undefined {
  if (payload.data !== undefined && payload.data !== null) {
    return payload.data;
  }
  return payload.result;
}

function kmNumberDistanceText(value: Object | string | number | boolean | null | undefined): string {
  const text = textOf(value).trim();
  if (text.length === 0) {
    return '';
  }
  if (/米|千米|公里|km/i.test(text)) {
    return text.replace(/km/ig, '千米').replace(/公里/g, '千米');
  }
  const amount = Number(text);
  if (isNaN(amount)) {
    return text;
  }
  if (amount < 10) {
    return Math.round(amount * 1000).toString() + '米';
  }
  return Math.round(amount).toString() + '米';
}

function pricePart(label: string, value: Object | string | number | boolean | null | undefined): string {
  const text = textOf(value).trim();
  if (text.length === 0) {
    return '';
  }
  if (/^¥/.test(text)) {
    return label + text;
  }
  return label + '¥' + text;
}

function boolStatusText(value: Object | string | number | boolean | null | undefined, trueText: string, falseText: string): string {
  if (typeof value === 'boolean') {
    return value ? trueText : falseText;
  }
  const text = textOf(value).trim().toLowerCase();
  if (text.length === 0) {
    return '';
  }
  if (text === 'true' || text === '1' || text === 'yes') {
    return trueText;
  }
  if (text === 'false' || text === '0' || text === 'no') {
    return falseText;
  }
  return textOf(value);
}

function firstMcDonaldsStore(payload: Object): McDonaldsStoreRecord | null {
  const stores = mcDonaldsStoresFromData(mcpPayloadData(payload as McDonaldsPayload) as McDonaldsStoreRecord[] | McDonaldsStoreContainer | undefined);
  return stores.length > 0 ? stores[0] : null;
}

function firstLuckinShop(payload: Object): LuckinShopRecord | null {
  const shops = luckinShopsFromData(mcpPayloadData(payload as LuckinPayload) as LuckinShopRecord[] | LuckinShopContainer | undefined);
  return shops.length > 0 ? shops[0] : null;
}

function mcdStoreToFood(item: McDonaldsStoreRecord): A2uiFoodData {
  const status = boolStatusText(item.businessStatus, '营业中', '休息中');
  const hours = item.businessStartTime !== undefined && item.businessEndTime !== undefined ?
    item.businessStartTime + '-' + item.businessEndTime : '';
  return {
    name: firstText([item.storeName, item.name]),
    category: joinFoodParts(['麦当劳门店', status, hours]),
    address: textOf(item.address),
    distance: meterDistanceText(item.distance),
    sourceTags: ['麦当劳']
  };
}

function mcdMealTags(code: string, categories: McDonaldsCategoryRecord[]): string[] {
  const tags: string[] = [];
  for (let categoryIndex = 0; categoryIndex < categories.length; categoryIndex++) {
    const category = categories[categoryIndex];
    const meals = category.meals === undefined ? [] : category.meals;
    for (let mealIndex = 0; mealIndex < meals.length; mealIndex++) {
      if (textOf(meals[mealIndex].code) !== code) {
        continue;
      }
      appendUniqueText(tags, textOf(category.name));
      const mealTags: string[] = meals[mealIndex].tags === undefined ? [] : (meals[mealIndex].tags as string[]);
      for (let tagIndex = 0; tagIndex < mealTags.length; tagIndex++) {
        appendUniqueText(tags, textOf(mealTags[tagIndex]));
      }
    }
  }
  return tags;
}

function jsonObjectSlice(source: string, objectStart: number): string {
  if (objectStart < 0 || objectStart >= source.length || source.charAt(objectStart) !== '{') {
    return '';
  }
  let depth = 0;
  let inString = false;
  let escaping = false;
  for (let index = objectStart; index < source.length; index++) {
    const char = source.charAt(index);
    if (escaping) {
      escaping = false;
      continue;
    }
    if (char === '\\') {
      escaping = true;
      continue;
    }
    if (char === '"') {
      inString = !inString;
      continue;
    }
    if (inString) {
      continue;
    }
    if (char === '{') {
      depth++;
    } else if (char === '}') {
      depth--;
      if (depth === 0) {
        return source.substring(objectStart, index + 1);
      }
    }
  }
  return '';
}

function mcdMealRecordFromMap(mealObject: McDonaldsMealsMap, code: string): McDonaldsMealRecord | null {
  const source = JSON.stringify(mealObject);
  const keyToken = JSON.stringify(code);
  const keyIndex = source.indexOf(keyToken);
  if (keyIndex < 0) {
    return null;
  }
  const colonIndex = source.indexOf(':', keyIndex + keyToken.length);
  if (colonIndex < 0) {
    return null;
  }
  const objectStart = source.indexOf('{', colonIndex + 1);
  const slice = jsonObjectSlice(source, objectStart);
  if (slice.length === 0) {
    return null;
  }
  try {
    return JSON.parse(slice) as McDonaldsMealRecord;
  } catch (_error) {
    return null;
  }
}

function mcdMealEntries(meals: McDonaldsMealsMap | McDonaldsMealRecord[] | undefined): McDonaldsMealEntry[] {
  const entries: McDonaldsMealEntry[] = [];
  if (meals === undefined || meals === null) {
    return entries;
  }
  if (Array.isArray(meals)) {
    const mealRows = meals as McDonaldsMealRecord[];
    for (let index = 0; index < mealRows.length; index++) {
      const row = mealRows[index];
      const code = textOf((row as McDonaldsCategoryMeal).code);
      entries.push({ code: code.length > 0 ? code : index.toString(), meal: row });
    }
    return entries;
  }
  const mealObject = meals as McDonaldsMealsMap;
  const codes = Object.keys(mealObject);
  for (let index = 0; index < codes.length; index++) {
    const code = codes[index];
    const meal = mcdMealRecordFromMap(mealObject, code);
    if (meal === null) {
      continue;
    }
    entries.push({ code: code, meal: meal });
  }
  return entries;
}

function mcdMealsToFood(data: McDonaldsMealsData): A2uiFoodData[] {
  const categories = data.categories === undefined ? [] : data.categories;
  const foods: A2uiFoodData[] = [];
  const entries = mcdMealEntries(data.meals);
  for (let index = 0; index < entries.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
    const code = entries[index].code;
    const meal = entries[index].meal;
    const name = textOf(meal.name);
    if (name.length === 0) {
      continue;
    }
    const tags = mcdMealTags(code, categories);
    foods.push({
      name: '麦当劳 · ' + name,
      category: joinFoodParts([pricePart('', firstText([meal.currentPrice, meal.price])), code]),
      address: tags.join(' · '),
      distance: '',
      sourceTags: ['麦当劳']
    });
  }
  return foods;
}

function mcdCouponsToFood(coupons: McDonaldsCouponRecord[]): A2uiFoodData[] {
  const foods: A2uiFoodData[] = [];
  for (let index = 0; index < coupons.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
    const coupon = coupons[index];
    const products = coupon.products === undefined ? [] : coupon.products;
    const productNames: string[] = [];
    for (let productIndex = 0; productIndex < products.length; productIndex++) {
      appendUniqueText(productNames, textOf(products[productIndex].productName));
    }
    const title = firstText([coupon.title, coupon.name, coupon.couponCode, coupon.couponId]);
    if (title.length === 0) {
      continue;
    }
    foods.push({
      name: '麦当劳优惠 · ' + title,
      category: productNames.join(' · '),
      address: textOf(coupon.tradeDateTime),
      distance: '',
      sourceTags: ['麦当劳']
    });
  }
  return foods;
}

function mcdPriceToFood(data: McDonaldsPriceData): A2uiFoodData[] {
  const products = data.productList === undefined ? [] : data.productList;
  const foods: A2uiFoodData[] = [];
  for (let index = 0; index < products.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
    const product = products[index];
    const name = firstText([product.productName, product.productCode]);
    if (name.length === 0) {
      continue;
    }
    foods.push({
      name: '麦当劳 · ' + name,
      category: joinFoodParts([
        textOf(product.quantity).length > 0 ? '数量' + textOf(product.quantity) : '',
        pricePart('小计', firstText([product.subtotal, product.originalSubtotal]))
      ]),
      address: joinFoodParts([
        pricePart('应付', data.price),
        pricePart('优惠', data.discount),
        pricePart('配送费', data.deliveryPrice)
      ]),
      distance: '',
      sourceTags: ['麦当劳']
    });
  }
  return foods;
}

export function foodRecordsFromMcDonaldsMcpTool(toolName: string, value: Object): A2uiFoodData[] {
  const payload = value as McDonaldsPayload;
  const data = mcpPayloadData(payload);
  if (toolName === 'query-nearby-stores' || toolName === 'delivery-query-stores') {
    const stores = mcDonaldsStoresFromData(data as McDonaldsStoreRecord[] | McDonaldsStoreContainer | undefined);
    const foods: A2uiFoodData[] = [];
    for (let index = 0; index < stores.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const food = mcdStoreToFood(stores[index]);
      if (food.name.length > 0) {
        foods.push(food);
      }
    }
    return foods;
  }
  if (toolName === 'query-meals') {
    return mcdMealsToFood(data as McDonaldsMealsData);
  }
  if (toolName === 'query-meal-detail') {
    const detail = data as McDonaldsMealRecord;
    const name = textOf(detail.name);
    if (name.length === 0) {
      return [];
    }
    return [{
      name: '麦当劳 · ' + name,
      category: pricePart('', firstText([detail.currentPrice, detail.price])),
      address: '',
      distance: '',
      sourceTags: ['麦当劳']
    }];
  }
  if (toolName === 'calculate-price') {
    return mcdPriceToFood(data as McDonaldsPriceData);
  }
  if (toolName === 'query-store-coupons' || toolName === 'available-coupons' || toolName === 'query-my-coupons') {
    return mcdCouponsToFood(mcDonaldsCouponsFromData(data as McDonaldsCouponRecord[] | McDonaldsCouponContainer | undefined));
  }
  return [];
}

function luckinShopToFood(item: LuckinShopRecord): A2uiFoodData {
  const tags = item.deptTags !== undefined ? item.deptTags : (item.tags !== undefined ? item.tags : []);
  return {
    name: firstText([item.deptName, item.name]),
    category: joinFoodParts(['瑞幸门店', tags.join(' · '), item.workTimeStart !== undefined && item.workTimeEnd !== undefined ? item.workTimeStart + '-' + item.workTimeEnd : '']),
    address: textOf(item.address),
    distance: kmNumberDistanceText(item.distance),
    location: mapPointLocation({ lng: item.longitude, lat: item.latitude }),
    sourceTags: ['瑞幸']
  };
}

function selectedLuckinAttrs(attrs: LuckinProductAttr[] | undefined): string {
  if (attrs === undefined) {
    return '';
  }
  const parts: string[] = [];
  for (let index = 0; index < attrs.length; index++) {
    const attr = attrs[index];
    const children = attr.productSubAttrs === undefined ? [] : attr.productSubAttrs;
    for (let childIndex = 0; childIndex < children.length; childIndex++) {
      const child = children[childIndex];
      if (child.selected === true) {
        appendUniqueText(parts, textOf(attr.attributeName) + ':' + textOf(child.attributeName));
      }
    }
  }
  return parts.join(' · ');
}

function luckinAttrSelectionsMapFromProduct(product: LuckinProductRecord): Record<string, string> {
  const result: Record<string, string> = {};
  const attrs = product.productAttrs === undefined ? [] : product.productAttrs;
  for (let index = 0; index < attrs.length; index += 1) {
    const attr = attrs[index];
    const groupName = textOf(attr.attributeName).trim();
    if (groupName.length === 0) {
      continue;
    }
    const children = attr.productSubAttrs === undefined ? [] : attr.productSubAttrs;
    for (let childIndex = 0; childIndex < children.length; childIndex += 1) {
      const child = children[childIndex];
      if (child.selected === true) {
        const choiceName = textOf(child.attributeName).trim();
        if (choiceName.length > 0) {
          result[groupName] = choiceName;
        }
      }
    }
  }
  return result;
}

function luckinAttrOptionRowsFromSelections(selections: string[][]): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  for (let index = 0; index < selections.length; index += 1) {
    const groupName = selections[index][0];
    const choiceName = selections[index][1];
    if (groupName.length > 0 && choiceName.length > 0) {
      rows.push({ label: '选项·' + groupName, value: choiceName + ':1' });
    }
  }
  return rows;
}

function luckinAttrOptionRows(product: LuckinProductRecord): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  const attrs = product.productAttrs === undefined ? [] : product.productAttrs;
  for (let index = 0; index < attrs.length; index++) {
    const attr = attrs[index];
    const groupName = textOf(attr.attributeName);
    if (groupName.length === 0) {
      continue;
    }
    const parts: string[] = [];
    const children = attr.productSubAttrs === undefined ? [] : attr.productSubAttrs;
    for (let childIndex = 0; childIndex < children.length; childIndex++) {
      const child = children[childIndex];
      const choiceName = textOf(child.attributeName);
      if (choiceName.length === 0) {
        continue;
      }
      const canSelected = child.canSelected;
      if (canSelected !== undefined && canSelected !== null && Number(canSelected) === 0) {
        continue;
      }
      parts.push(choiceName + ':' + (child.selected === true ? '1' : '0'));
    }
    if (parts.length > 0) {
      rows.push({ label: '选项·' + groupName, value: parts.join('|') });
    }
  }
  return rows;
}

function luckinApplySelectedChoices(
  detailAttrs: LuckinProductAttr[] | undefined,
  searchAttrs: LuckinProductAttr[] | undefined
): LuckinProductAttr[] | undefined {
  if (detailAttrs === undefined || detailAttrs.length === 0) {
    return searchAttrs;
  }
  const selectedByGroup: string[] = [];
  if (searchAttrs !== undefined) {
    for (let searchIndex = 0; searchIndex < searchAttrs.length; searchIndex++) {
      const searchAttr = searchAttrs[searchIndex];
      const groupName = textOf(searchAttr.attributeName);
      const children = searchAttr.productSubAttrs === undefined ? [] : searchAttr.productSubAttrs;
      for (let childIndex = 0; childIndex < children.length; childIndex++) {
        const child = children[childIndex];
        if (child.selected === true) {
          selectedByGroup.push(groupName + '|' + textOf(child.attributeName));
        }
      }
    }
  }
  const merged: LuckinProductAttr[] = [];
  for (let detailIndex = 0; detailIndex < detailAttrs.length; detailIndex++) {
    const detailAttr = detailAttrs[detailIndex];
    const groupName = textOf(detailAttr.attributeName);
    const children = detailAttr.productSubAttrs === undefined ? [] : detailAttr.productSubAttrs;
    let selectedChoice = '';
    for (let mapIndex = 0; mapIndex < selectedByGroup.length; mapIndex++) {
      const parts = selectedByGroup[mapIndex].split('|');
      if (parts.length === 2 && parts[0] === groupName) {
        selectedChoice = parts[1];
      }
    }
    const mergedChildren: LuckinProductSubAttr[] = [];
    for (let childIndex = 0; childIndex < children.length; childIndex++) {
      const child = children[childIndex];
      const choiceName = textOf(child.attributeName);
      const selected = selectedChoice.length > 0 ?
        choiceName === selectedChoice :
        child.selected === true;
      mergedChildren.push({
        attributeName: child.attributeName,
        selected: selected,
        canSelected: child.canSelected
      });
    }
    merged.push({
      attributeName: detailAttr.attributeName,
      productSubAttrs: mergedChildren
    });
  }
  return merged;
}

function luckinProductForPreview(searchProduct: LuckinProductRecord, detailProduct: LuckinProductRecord | null): LuckinProductRecord {
  if (detailProduct === null) {
    return searchProduct;
  }
  return {
    productId: firstText([searchProduct.productId, detailProduct.productId]),
    productName: firstText([searchProduct.productName, detailProduct.productName]),
    name: firstText([searchProduct.name, detailProduct.name]),
    skuCode: firstText([searchProduct.skuCode, detailProduct.skuCode]),
    pictureUrl: firstText([searchProduct.pictureUrl, detailProduct.pictureUrl]),
    price: firstText([detailProduct.price, searchProduct.price]),
    discountPrice: firstText([detailProduct.discountPrice, searchProduct.discountPrice]),
    initPrice: firstText([detailProduct.initPrice, searchProduct.initPrice]),
    productAttrs: luckinApplySelectedChoices(detailProduct.productAttrs, searchProduct.productAttrs),
    tags: detailProduct.tags !== undefined ? detailProduct.tags : searchProduct.tags
  };
}

function luckinProductSearchQuery(prompt: string, request: LuckinOrderActionArgs): string {
  const previewPrompt = textOf(request.previewPrompt).trim();
  if (previewPrompt.length > 0) {
    return previewPrompt;
  }
  return luckinPromptKeyword(prompt);
}

function luckinApplyAttrChoice(
  product: LuckinProductRecord,
  groupName: string,
  choiceName: string
): LuckinProductRecord {
  const attrs = product.productAttrs === undefined ? [] : product.productAttrs;
  const merged: LuckinProductAttr[] = [];
  for (let index = 0; index < attrs.length; index += 1) {
    const attr = attrs[index];
    const name = textOf(attr.attributeName);
    const children = attr.productSubAttrs === undefined ? [] : attr.productSubAttrs;
    const mergedChildren: LuckinProductSubAttr[] = [];
    for (let childIndex = 0; childIndex < children.length; childIndex += 1) {
      const child = children[childIndex];
      const childName = textOf(child.attributeName);
      const selected = name === groupName ? childName === choiceName : child.selected === true;
      mergedChildren.push({
        attributeId: child.attributeId,
        attributeName: child.attributeName,
        selected: selected,
        canSelected: child.canSelected,
        price: child.price
      });
    }
    merged.push({
      attributeId: attr.attributeId,
      attributeName: attr.attributeName,
      productSubAttrs: mergedChildren
    });
  }
  return {
    productId: product.productId,
    productName: product.productName,
    name: product.name,
    skuCode: product.skuCode,
    pictureUrl: product.pictureUrl,
    price: product.price,
    discountPrice: product.discountPrice,
    initPrice: product.initPrice,
    productAttrs: merged,
    tags: product.tags
  };
}

function luckinAttrSelectionsFromRequest(request: LuckinOrderActionArgs): string[][] {
  const raw = request.attrSelections;
  if (raw === undefined || raw === null || typeof raw !== 'object') {
    return [];
  }
  const pairs: string[][] = [];
  const keys = Object.keys(raw as Record<string, Object | string | number | boolean | null | undefined>);
  for (let index = 0; index < keys.length; index += 1) {
    const groupName = textOf(keys[index]).trim();
    const choiceName = textOf((raw as Record<string, Object | string | number | boolean | null | undefined>)[keys[index]]).trim();
    if (groupName.length > 0 && choiceName.length > 0) {
      pairs.push([groupName, choiceName]);
    }
  }
  return pairs;
}

function luckinApplyAttrSelections(
  product: LuckinProductRecord,
  selections: string[][],
  skipGroup: string = ''
): LuckinProductRecord {
  let result = product;
  for (let index = 0; index < selections.length; index += 1) {
    const groupName = selections[index][0];
    const choiceName = selections[index][1];
    if (groupName === skipGroup) {
      continue;
    }
    result = luckinApplyAttrChoice(result, groupName, choiceName);
  }
  return result;
}

function luckinPinnedProductPicture(
  request: LuckinOrderActionArgs,
  product: LuckinProductRecord,
  detailProduct?: LuckinProductRecord
): string {
  const fromRequest = textOf(request.pictureUrl);
  if (fromRequest.length > 0) {
    return fromRequest;
  }
  const fromDetail = detailProduct !== undefined ? luckinProductPictureUrl(detailProduct) : '';
  if (fromDetail.length > 0) {
    return fromDetail;
  }
  return luckinProductPictureUrl(product);
}

function luckinProductWithPicture(product: LuckinProductRecord, pictureUrl: string): LuckinProductRecord {
  if (pictureUrl.length === 0) {
    return product;
  }
  return {
    productId: product.productId,
    productName: product.productName,
    name: product.name,
    skuCode: product.skuCode,
    pictureUrl: pictureUrl,
    price: product.price,
    discountPrice: product.discountPrice,
    initPrice: product.initPrice,
    productAttrs: product.productAttrs,
    tags: product.tags
  };
}

function luckinProductWithSku(product: LuckinProductRecord, skuCode: string): LuckinProductRecord {
  if (skuCode.length === 0) {
    return product;
  }
  return {
    productId: product.productId,
    productName: product.productName,
    name: product.name,
    skuCode: skuCode,
    pictureUrl: product.pictureUrl,
    price: product.price,
    discountPrice: product.discountPrice,
    initPrice: product.initPrice,
    productAttrs: product.productAttrs,
    tags: product.tags
  };
}

function luckinRestoreProductSelectionsFast(
  request: LuckinOrderActionArgs,
  detailProduct: LuckinProductRecord
): LuckinProductRecord {
  const selections = luckinAttrSelectionsFromRequest(request);
  const skipGroup = textOf(request.attrGroup);
  let product = luckinApplyAttrSelections(detailProduct, selections, skipGroup);
  return luckinProductWithSku(product, textOf(request.skuCode));
}

function luckinFinalizeSwitchedProduct(
  detailProduct: LuckinProductRecord,
  switched: LuckinProductRecord,
  selections: string[][],
  groupName: string,
  choiceName: string
): LuckinProductRecord {
  const attrSource = switched.productAttrs !== undefined && switched.productAttrs.length > 0 ?
    switched.productAttrs :
    detailProduct.productAttrs;
  let product: LuckinProductRecord = {
    productId: firstText([switched.productId, detailProduct.productId]),
    productName: firstText([switched.productName, detailProduct.productName]),
    name: firstText([switched.name, detailProduct.name]),
    skuCode: firstText([switched.skuCode, detailProduct.skuCode]),
    pictureUrl: firstText([detailProduct.pictureUrl, switched.pictureUrl]),
    price: firstText([switched.price, detailProduct.price]),
    discountPrice: firstText([switched.discountPrice, detailProduct.discountPrice]),
    initPrice: firstText([switched.initPrice, detailProduct.initPrice]),
    productAttrs: attrSource,
    tags: switched.tags !== undefined ? switched.tags : detailProduct.tags
  };
  product = luckinApplyAttrSelections(product, selections, '');
  if (groupName.length > 0 && choiceName.length > 0) {
    product = luckinApplyAttrChoice(product, groupName, choiceName);
    product = luckinProductWithSku(product, firstText([switched.skuCode, product.skuCode]));
  }
  return product;
}

const luckinProductDetailCache: Map<string, LuckinProductRecord> = new Map();

function luckinDetailCacheKey(deptId: string, productId: number): string {
  return deptId + '|' + productId.toString();
}

async function luckinLoadProductDetailCached(
  shop: LuckinShopRecord,
  productId: number,
  token: string
): Promise<LuckinProductRecord | null> {
  const deptId = textOf(shop.deptId);
  const cacheKey = luckinDetailCacheKey(deptId, productId);
  const cached = luckinProductDetailCache.get(cacheKey);
  if (cached !== undefined) {
    return cached;
  }
  const detailProduct = await luckinLoadProductDetail(shop, productId, token);
  if (detailProduct !== null) {
    luckinProductDetailCache.set(cacheKey, detailProduct);
  }
  return detailProduct;
}

function luckinFindAttrIds(
  product: LuckinProductRecord,
  groupName: string,
  choiceName: string
): LuckinAttrOperationParam | null {
  const attrs = product.productAttrs === undefined ? [] : product.productAttrs;
  for (let index = 0; index < attrs.length; index += 1) {
    const attr = attrs[index];
    if (textOf(attr.attributeName) !== groupName) {
      continue;
    }
    const groupAttrId = Number(attr.attributeId);
    if (groupAttrId <= 0) {
      continue;
    }
    const children = attr.productSubAttrs === undefined ? [] : attr.productSubAttrs;
    for (let childIndex = 0; childIndex < children.length; childIndex += 1) {
      const child = children[childIndex];
      if (textOf(child.attributeName) !== choiceName) {
        continue;
      }
      const choiceAttrId = Number(child.attributeId);
      if (choiceAttrId <= 0) {
        continue;
      }
      return {
        attributeId: groupAttrId,
        subAttr: {
          attributeId: choiceAttrId,
          operation: 3
        }
      };
    }
  }
  return null;
}

async function luckinTrySwitchProduct(
  shop: LuckinShopRecord,
  product: LuckinProductRecord,
  groupName: string,
  choiceName: string,
  quantity: number,
  token: string
): Promise<LuckinProductRecord | null> {
  const attrOperationParam = luckinFindAttrIds(product, groupName, choiceName);
  if (attrOperationParam === null) {
    return null;
  }
  const deptId = Number(textOf(shop.deptId));
  const productId = Number(textOf(product.productId));
  const skuCode = luckinProductSku(product);
  if (deptId <= 0 || productId <= 0 || skuCode.length === 0) {
    return null;
  }
  try {
    const switchArgs: LuckinSwitchProductArgs = {
      deptId: deptId,
      productId: productId,
      skuCode: skuCode,
      attrOperationParam: attrOperationParam,
      amount: quantity
    };
    const switchPayload = await callReadonlyBrandMcpTool(
      '瑞幸',
      localProviderConfig.luckinMcpUrl,
      token,
      'switchProduct',
      switchArgs
    );
    const switchedProducts = luckinProductsFromPayload(switchPayload);
    if (switchedProducts.length === 0) {
      return null;
    }
    return switchedProducts[0];
  } catch (error) {
    aiLogInfo('[AIPhone][LuckinSwitchProduct] fallback=' + describeThrown(error));
    return null;
  }
}

async function luckinLoadProductDetail(
  shop: LuckinShopRecord,
  productId: number,
  token: string
): Promise<LuckinProductRecord | null> {
  const deptId = Number(textOf(shop.deptId));
  if (deptId <= 0 || productId <= 0) {
    return null;
  }
  try {
    const detailArgs: LuckinProductDetailArgs = {
      deptId: deptId,
      productId: productId
    };
    const detailPayload = await callReadonlyBrandMcpTool(
      '瑞幸',
      localProviderConfig.luckinMcpUrl,
      token,
      'queryProductDetailInfo',
      detailArgs
    );
    const detailProducts = luckinProductsFromPayload(detailPayload);
    return detailProducts.length > 0 ? detailProducts[0] : null;
  } catch (error) {
    aiLogInfo('[AIPhone][LuckinProductDetail] fallback=' + describeThrown(error));
    return null;
  }
}

async function luckinLoadProductForOptionSwitch(
  shop: LuckinShopRecord,
  request: LuckinOrderActionArgs,
  prompt: string,
  token: string
): Promise<LuckinProductRecord | null> {
  const productId = Number(textOf(request.productId));
  const quantity = luckinQuantityFromPrompt(prompt);
  const groupName = textOf(request.attrGroup);
  const choiceName = textOf(request.attrChoice);
  const selections = luckinAttrSelectionsFromRequest(request);
  const detailProduct = await luckinLoadProductDetailCached(shop, productId, token);
  if (detailProduct === null) {
    return null;
  }
  let product = luckinRestoreProductSelectionsFast(request, detailProduct);
  if (groupName.length > 0 && choiceName.length > 0) {
    const switched = await luckinTrySwitchProduct(shop, product, groupName, choiceName, quantity, token);
    if (switched !== null) {
      product = luckinFinalizeSwitchedProduct(detailProduct, switched, selections, groupName, choiceName);
    } else {
      product = luckinApplyAttrSelections(product, selections, '');
    }
  }
  const pinnedPicture = luckinPinnedProductPicture(request, product, detailProduct);
  return luckinProductWithPicture(product, pinnedPicture);
}

async function luckinLoadProductForPreview(
  shop: LuckinShopRecord,
  searchProduct: LuckinProductRecord,
  token: string
): Promise<LuckinProductRecord> {
  const deptId = Number(textOf(shop.deptId));
  const productId = Number(textOf(searchProduct.productId));
  if (deptId <= 0 || productId <= 0) {
    return searchProduct;
  }
  try {
    const detailArgs: LuckinProductDetailArgs = {
      deptId: deptId,
      productId: productId
    };
    const detailPayload = await callReadonlyBrandMcpTool(
      '瑞幸',
      localProviderConfig.luckinMcpUrl,
      token,
      'queryProductDetailInfo',
      detailArgs
    );
    const detailProducts = luckinProductsFromPayload(detailPayload);
    const detailProduct = detailProducts.length > 0 ? detailProducts[0] : null;
    return luckinProductForPreview(searchProduct, detailProduct);
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    aiLogInfo('[AIPhone][LuckinProductDetail] fallback=search reason=' + message);
    return searchProduct;
  }
}

function luckinPreviewPromptFromProduct(prompt: string, product: LuckinProductRecord, quantity: number): string {
  const parts: string[] = [];
  const productName = luckinProductName(product);
  if (productName.length > 0) {
    parts.push(productName + (quantity > 1 ? ' x' + quantity.toString() : ''));
  }
  const attrs = product.productAttrs === undefined ? [] : product.productAttrs;
  for (let index = 0; index < attrs.length; index++) {
    const attr = attrs[index];
    const children = attr.productSubAttrs === undefined ? [] : attr.productSubAttrs;
    for (let childIndex = 0; childIndex < children.length; childIndex++) {
      const child = children[childIndex];
      if (child.selected === true) {
        const choiceName = textOf(child.attributeName);
        if (choiceName.length > 0) {
          parts.push(choiceName);
        }
      }
    }
  }
  const remark = luckinRemarkFromPrompt(prompt);
  if (remark.length > 0) {
    parts.push(remark);
  }
  if (parts.length > 0) {
    return parts.join('，');
  }
  return prompt;
}

function luckinProductToFood(item: LuckinProductRecord): A2uiFoodData {
  return {
    name: '瑞幸 · ' + firstText([item.productName, item.name]),
    category: joinFoodParts([
      firstText([item.skuCode, item.productId]),
      pricePart('', firstText([item.discountPrice, item.price, item.initPrice])),
      item.tags === undefined ? '' : item.tags.join(' · ')
    ]),
    address: selectedLuckinAttrs(item.productAttrs),
    distance: '',
    sourceTags: ['瑞幸']
  };
}

function luckinOrderToFood(item: LuckinOrderRecord): A2uiFoodData[] {
  const foods: A2uiFoodData[] = [];
  const products = item.productInfoList === undefined ? [] : item.productInfoList;
  for (let index = 0; index < products.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
    const product = luckinProductToFood(products[index]);
    product.address = joinFoodParts([
      textOf(item.orderStatusName),
      pricePart('订单金额', item.orderPayAmount),
      product.address
    ]);
    foods.push(product);
  }
  if (foods.length === 0 && firstText([item.orderId, item.orderStatusName]).length > 0) {
    foods.push({
      name: '瑞幸订单 · ' + textOf(item.orderId),
      category: textOf(item.orderStatusName),
      address: pricePart('订单金额', item.orderPayAmount),
      distance: '',
      sourceTags: ['瑞幸']
    });
  }
  return foods;
}

export function foodRecordsFromLuckinMcpTool(toolName: string, value: Object): A2uiFoodData[] {
  const payload = value as LuckinPayload;
  const data = mcpPayloadData(payload);
  if (toolName === 'queryShopList') {
    const shops = luckinShopsFromData(data as LuckinShopRecord[] | LuckinShopContainer | undefined);
    const foods: A2uiFoodData[] = [];
    for (let index = 0; index < shops.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const food = luckinShopToFood(shops[index]);
      if (food.name.length > 0) {
        foods.push(food);
      }
    }
    return foods;
  }
  if (toolName === 'searchProductForMcp' || toolName === 'queryProductDetailInfo') {
    if (data === undefined) {
      return [];
    }
    const productRows = luckinProductsFromData(data as LuckinProductRecord[] | LuckinProductContainer | undefined);
    const products = productRows.length > 0 ? productRows : [data as LuckinProductRecord];
    const foods: A2uiFoodData[] = [];
    for (let index = 0; index < products.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const food = luckinProductToFood(products[index]);
      if (food.name !== '瑞幸 · ') {
        foods.push(food);
      }
    }
    return foods;
  }
  if (toolName === 'queryOrderDetailInfo') {
    return luckinOrderToFood(data as LuckinOrderRecord);
  }
  return [];
}

interface LuckinOrderActionArgs {
  deptId?: string | number;
  deptName?: string;
  address?: string;
  distance?: string;
  location?: string;
  status?: string;
  productId?: string | number;
  productName?: string;
  skuCode?: string;
  pictureUrl?: string;
  previewPrompt?: string;
  attrGroup?: string;
  attrChoice?: string;
  attrSelections?: Record<string, string | number | boolean | Object>;
  quantity?: string | number;
  price?: string | number;
  couponCodeList?: string[];
  remark?: string;
  orderId?: string | number;
  payOrderUrl?: string;
  payOrderQrCodeUrl?: string;
}

function luckinActionArgs(args: Object | null): LuckinOrderActionArgs {
  return args === null ? {} : args as LuckinOrderActionArgs;
}

function luckinMoney(value: Object | string | number | boolean | null | undefined): string {
  const raw = textOf(value).trim();
  if (raw.length === 0) {
    return '';
  }
  return raw.charAt(0) === '¥' ? raw : '¥' + raw;
}

function luckinPromptKeyword(prompt: string): string {
  const preset = /(生椰拿铁|冰美式|拿铁|美式|葡萄冰萃|澳瑞白|厚乳拿铁|橙C美式|椰云拿铁|丝绒拿铁)/u.exec(prompt);
  if (preset !== null) {
    return preset[0];
  }
  const cleaned = prompt
    .replace(/瑞幸|luckin|ruixing/ig, '')
    .replace(/帮我|请|来|点|下一杯|下单|咖啡|饮品|一杯|两杯|2杯|杯|自取|外送|配送|附近|门店|使用优惠券|用优惠券/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return cleaned.length > 0 ? cleaned : '生椰拿铁';
}

function luckinQuantityFromPrompt(prompt: string): number {
  if (/两杯|2杯|两份|2份/.test(prompt)) {
    return 2;
  }
  const match = /(\d+)\s*(杯|份)/.exec(prompt);
  if (match !== null) {
    const count = Number(match[1]);
    return count > 0 && count < 10 ? count : 1;
  }
  return 1;
}

function luckinRemarkFromPrompt(prompt: string): string {
  const remarks: string[] = [];
  ['无糖', '少少甜', '少甜', '半糖', '标准甜', '热饮', '热', '少冰', '去冰', '正常冰', '多冰', '少奶', '加奶'].forEach((word: string) => {
    if (prompt.indexOf(word) >= 0 && remarks.indexOf(word) < 0) {
      remarks.push(word);
    }
  });
  return remarks.join('，');
}

function luckinProductName(item: LuckinProductRecord): string {
  return firstText([item.productName, item.name]);
}

function luckinProductSku(item: LuckinProductRecord): string {
  return firstText([item.skuCode]);
}

function luckinProductPictureUrl(item: LuckinProductRecord): string {
  return firstText([item.pictureUrl]);
}

function luckinProductsFromPayload(payload: Object): LuckinProductRecord[] {
  const data = mcpPayloadData(payload as LuckinPayload);
  if (data === undefined) {
    return [];
  }
  const products = luckinProductsFromData(data as LuckinProductRecord[] | LuckinProductContainer | undefined);
  if (products.length > 0) {
    return products;
  }
  const item = data as LuckinProductRecord;
  return luckinProductName(item).length > 0 ? [item] : [];
}

function luckinOrderRecordFromPayload(payload: Object): LuckinOrderRecord {
  const candidates = luckinOrderPayloadCandidates(payload);
  const merged: LuckinOrderRecord = {};
  let orderId = '';
  let payOrderUrl = '';
  let payOrderQrCodeUrl = '';
  for (let index = 0; index < candidates.length; index += 1) {
    const record = luckinOrderFieldsFromRecord(candidates[index]);
    orderId = firstText([record.orderIdStr, record.orderId, orderId]);
    payOrderUrl = firstText([record.payOrderUrl, payOrderUrl]);
    payOrderQrCodeUrl = firstText([record.payOrderQrCodeUrl, payOrderQrCodeUrl]);
    if (record.discountPrice !== undefined) {
      merged.discountPrice = record.discountPrice;
    }
    if (record.totalInitialPrice !== undefined) {
      merged.totalInitialPrice = record.totalInitialPrice;
    }
    if (record.privilegeMoney !== undefined) {
      merged.privilegeMoney = record.privilegeMoney;
    }
    if (record.couponCodeList !== undefined) {
      merged.couponCodeList = record.couponCodeList;
    }
    if (record.orderStatusName !== undefined) {
      merged.orderStatusName = record.orderStatusName;
    }
    if (record.orderStatus !== undefined) {
      merged.orderStatus = record.orderStatus;
    }
    if (record.takeMealTime !== undefined) {
      merged.takeMealTime = record.takeMealTime;
    }
    if (record.aboutTime !== undefined) {
      merged.aboutTime = record.aboutTime;
    }
  }
  const deep = luckinDeepScanPayFields(payload);
  orderId = firstText([orderId, deep.orderId]);
  payOrderUrl = firstText([payOrderUrl, deep.payOrderUrl]);
  payOrderQrCodeUrl = firstText([payOrderQrCodeUrl, deep.payOrderQrCodeUrl]);
  if (orderId.length > 0) {
    merged.orderIdStr = orderId;
  }
  if (payOrderUrl.length > 0) {
    merged.payOrderUrl = payOrderUrl;
  }
  if (payOrderQrCodeUrl.length > 0) {
    merged.payOrderQrCodeUrl = payOrderQrCodeUrl;
  }
  return merged;
}

function luckinOrderFieldsFromRecord(record: LuckinOrderRecord): LuckinOrderRecord {
  const bag = record as LuckinOrderRecordAliases;
  const normalized: LuckinOrderRecord = {
    orderIdStr: firstText([record.orderIdStr, bag.order_id_str]),
    orderId: firstText([record.orderId, bag.order_id, bag.order_no, bag.orderNo, record.tradeNo, bag.trade_no]),
    payOrderUrl: firstText([record.payOrderUrl, bag.pay_order_url, bag.payUrl, bag.pay_url, bag.wechatPayUrl, bag.wechat_pay_url]),
    payOrderQrCodeUrl: firstText([record.payOrderQrCodeUrl, bag.pay_order_qr_code_url, bag.qrCodeUrl, bag.qr_code_url]),
    discountPrice: record.discountPrice,
    totalInitialPrice: record.totalInitialPrice,
    privilegeMoney: record.privilegeMoney,
    couponCodeList: record.couponCodeList,
    orderStatusName: record.orderStatusName,
    orderStatus: record.orderStatus,
    takeMealTime: record.takeMealTime,
    aboutTime: record.aboutTime
  };
  return normalized;
}

function luckinDeepScanPayFields(root: Object): LuckinOrderActionArgs {
  const found: LuckinOrderActionArgs = {};
  const absorb = (record: LuckinOrderRecord | undefined): void => {
    if (record === undefined) {
      return;
    }
    const normalized = luckinOrderFieldsFromRecord(record);
    if (textOf(found.orderId).length === 0) {
      found.orderId = firstText([normalized.orderIdStr, normalized.orderId]);
    }
    if (textOf(found.payOrderUrl).length === 0) {
      found.payOrderUrl = textOf(normalized.payOrderUrl);
    }
    if (textOf(found.payOrderQrCodeUrl).length === 0) {
      found.payOrderQrCodeUrl = textOf(normalized.payOrderQrCodeUrl);
    }
  };
  const bag = root as LuckinPayloadBag;
  absorb(bag as LuckinOrderRecord);
  absorb(bag.orderInfo);
  absorb(bag.order);
  absorb(bag.orderDetail);
  absorb(bag.orderData);
  absorb(bag.content);
  const data = mcpPayloadData(bag);
  if (data !== undefined && !Array.isArray(data)) {
    absorb(data as LuckinOrderRecord);
  }
  if (textOf(found.payOrderUrl).length === 0) {
    const preview = JSON.stringify(root);
    const weixinMatch = /weixin:\/\/[^\s"']+/i.exec(preview);
    if (weixinMatch !== null) {
      found.payOrderUrl = weixinMatch[0];
    }
  }
  return found;
}

function luckinPayloadErrorMessage(payload: Object): string {
  const wrapped = payload as LuckinPayload;
  const record = payload as ToolArgRecord;
  const explicitError = textOf(record['error']).trim();
  if (explicitError.length > 0) {
    return explicitError;
  }
  const code = textOf(wrapped.code).trim();
  if (code.length > 0 && code !== '0' && code !== '200' && code !== '0000') {
    return firstText([wrapped.message, wrapped.msg, '瑞幸返回错误码 ' + code]);
  }
  if (wrapped.success === false || wrapped.success === 'false') {
    return firstText([wrapped.message, wrapped.msg, '瑞幸创建订单失败']);
  }
  const records: Object[] = [payload];
  const nested = mcpPayloadData(wrapped);
  if (nested !== undefined && nested !== null && typeof nested === 'object' && !Array.isArray(nested)) {
    records.push(nested as Object);
  }
  for (let index = 0; index < records.length; index++) {
    const current = records[index] as ToolArgRecord;
    if (current['success'] === false || current['success'] === 'false' ||
      current['successful'] === false || current['successful'] === 'false') {
      return firstText([current['message'], current['msg'], current['error'], '瑞幸创建订单失败']);
    }
    const status = textOf(current['status']).trim();
    const lower = status.toLowerCase();
    if (lower.indexOf('fail') >= 0 || lower.indexOf('error') >= 0 ||
      lower.indexOf('reject') >= 0 || lower.indexOf('denied') >= 0) {
      return firstText([current['message'], current['msg'], current['error'], '瑞幸返回失败状态：' + status]);
    }
  }
  return '';
}

export function luckinOrderCreateSucceededForTest(payload: Object): boolean {
  if (luckinPayloadErrorMessage(payload).length > 0) {
    return false;
  }
  const created = luckinOrderRecordFromPayload(payload);
  return firstText([created.orderIdStr, created.orderId]).length > 0;
}

function luckinOrderPayloadCandidates(payload: Object): LuckinOrderRecord[] {
  const wrapped = payload as LuckinPayloadBag;
  const candidates: LuckinOrderRecord[] = [];
  const push = (value: Object | undefined | null): void => {
    if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
      return;
    }
    candidates.push(value as LuckinOrderRecord);
  };
  const data = mcpPayloadData(wrapped);
  push(data as Object);
  push(payload);
  push(wrapped.orderInfo as Object);
  push(wrapped.order as Object);
  push(wrapped.orderDetail as Object);
  push(wrapped.orderData as Object);
  push(wrapped.content as Object);
  return candidates;
}

function luckinPayDiagnosticsLog(tag: string, orderId: string, payOrderUrl: string, payOrderQrCodeUrl: string, actionCount: number): void {
  const hasPayOrderUrl = payOrderUrl.length > 0;
  const hasPayOrderQrCodeUrl = payOrderQrCodeUrl.length > 0;
  const hasPay = hasPayOrderUrl || hasPayOrderQrCodeUrl;
  aiLogInfo('[AIPhone][' + tag + '] orderId=' + orderId +
    ' hasPayOrderUrl=' + (hasPayOrderUrl ? 'true' : 'false') +
    ' payOrderUrlChars=' + payOrderUrl.length.toString() +
    ' hasPayOrderQrCodeUrl=' + (hasPayOrderQrCodeUrl ? 'true' : 'false') +
    ' payOrderQrCodeUrlChars=' + payOrderQrCodeUrl.length.toString() +
    ' hasPay=' + (hasPay ? 'true' : 'false') +
    ' actionCount=' + actionCount.toString());
}

function luckinMcpPayFieldKeys(payload: Object): string {
  const wrapped = payload as LuckinPayloadBag;
  const data = mcpPayloadData(wrapped);
  if (data !== undefined && !Array.isArray(data) && typeof data === 'object') {
    const record = data as LuckinOrderRecord;
    const keys: string[] = [];
    if (record.orderId !== undefined) { keys.push('orderId'); }
    if (record.orderIdStr !== undefined) { keys.push('orderIdStr'); }
    if (record.payOrderUrl !== undefined) { keys.push('payOrderUrl'); }
    if (record.payOrderQrCodeUrl !== undefined) { keys.push('payOrderQrCodeUrl'); }
    if (record.discountPrice !== undefined) { keys.push('discountPrice'); }
    if (record.orderStatusName !== undefined) { keys.push('orderStatusName'); }
    return keys.join(',');
  }
  const keys: string[] = [];
  if (wrapped.data !== undefined) { keys.push('data'); }
  if (wrapped.result !== undefined) { keys.push('result'); }
  if (wrapped.orderInfo !== undefined) { keys.push('orderInfo'); }
  if (wrapped.order !== undefined) { keys.push('order'); }
  if (wrapped.orderDetail !== undefined) { keys.push('orderDetail'); }
  if (wrapped.orderData !== undefined) { keys.push('orderData'); }
  if (wrapped.content !== undefined) { keys.push('content'); }
  if (wrapped.code !== undefined) { keys.push('code'); }
  if (wrapped.message !== undefined) { keys.push('message'); }
  if (wrapped.msg !== undefined) { keys.push('msg'); }
  if (wrapped.success !== undefined) { keys.push('success'); }
  return keys.join(',');
}

function luckinShopName(shop: LuckinShopRecord): string {
  return firstText([shop.deptName, shop.shopName, shop.storeName, shop.name, shop.title, shop.number]);
}

function luckinShopAddress(shop: LuckinShopRecord): string {
  return firstText([shop.address, shop.deptAddress, shop.shopAddress]);
}

function luckinShopLocation(shop: LuckinShopRecord, fallback: string): string {
  const longitude = firstText([shop.longitude, shop.lng]);
  const latitude = firstText([shop.latitude, shop.lat]);
  return longitude.length > 0 && latitude.length > 0 ? longitude + ',' + latitude : fallback;
}

function luckinShopStatus(shop: LuckinShopRecord): string {
  const tags = shop.deptTags !== undefined ? shop.deptTags : (shop.tags !== undefined ? shop.tags : []);
  for (let index = 0; index < tags.length; index++) {
    const tag = textOf(tags[index]);
    if (tag.indexOf('营业') >= 0 || tag.indexOf('自提') >= 0 || tag.indexOf('外送') >= 0) {
      return tag;
    }
  }
  if (textOf(shop.workTimeStart).length > 0 && textOf(shop.workTimeEnd).length > 0) {
    return '营业中';
  }
  return '营业中';
}

export function resolveLuckinLocationForTest(requestLocation: string, prompt: string, defaultLocation: string): string {
  const fromArgs = parseCoordinatePair(requestLocation);
  if (fromArgs.length > 0) {
    return fromArgs;
  }
  const fromPrompt = parseCoordinatePair(prompt);
  if (fromPrompt.length > 0) {
    return fromPrompt;
  }
  return parseCoordinatePair(defaultLocation);
}

function resolveLuckinLocation(request: LuckinOrderActionArgs, prompt: string): string {
  return resolveLuckinLocationForTest(textOf(request.location), prompt, localProviderConfig.amapDefaultLocation);
}

function luckinShopSelectActions(shops: LuckinShopRecord[], location: string, prompt: string): A2uiAction[] {
  const actions: A2uiAction[] = [];
  const count = shops.length > 5 ? 5 : shops.length;
  for (let index = 0; index < count; index++) {
    const shop = shops[index];
    const shopArgs: LuckinOrderActionArgs = {
      deptId: textOf(shop.deptId),
      deptName: luckinShopName(shop),
      address: luckinShopAddress(shop),
      distance: kmNumberDistanceText(firstText([shop.distanceDesc, shop.distance])),
      location: luckinShopLocation(shop, location),
      status: luckinShopStatus(shop)
    };
    actions.push({
      id: 'luckin.order.preview',
      label: '选择：' + luckinShopName(shop),
      prompt: prompt,
      variant: 'secondary',
      kind: 'prompt',
      args: shopArgs
    });
  }
  return actions;
}

function luckinSelectedShop(shops: LuckinShopRecord[], deptId: string): LuckinShopRecord | null {
  for (let index = 0; index < shops.length; index++) {
    if (textOf(shops[index].deptId) === deptId) {
      return shops[index];
    }
  }
  return shops.length > 0 ? shops[0] : null;
}

function luckinFirstShop(payload: Object): LuckinShopRecord | null {
  const data = mcpPayloadData(payload as LuckinPayload);
  const shops = luckinShopsFromData(data as LuckinShopRecord[] | LuckinShopContainer | undefined);
  return shops.length > 0 ? shops[0] : null;
}

function luckinOrderProduct(item: LuckinProductRecord, quantity: number): LuckinOrderProductArgs {
  return {
    productId: Number(textOf(item.productId)),
    skuCode: luckinProductSku(item),
    amount: quantity
  };
}

function luckinGenericResultA2ui(surfaceId: string, toolId: string, title: string, summary: string, rows: A2uiLabelValueData[], rawPreview: string, actions: A2uiAction[]): string {
  return luckinDynamicResultA2ui(surfaceId, {
    sourceTag: '瑞幸',
    toolName: toolId,
    title: title,
    status: 'success',
    summary: summary,
    rows: rows,
    rawPreview: rawPreview,
    actions: actions
  });
}

function luckinDynamicResultA2ui(surfaceId: string, result: DynamicGenericToolResult): string {
  const actions = result.actions === undefined ? [] : result.actions;
  const results: A2uiGenericToolResultData[] = [{
    sourceTag: result.sourceTag,
    toolName: result.toolName,
    title: result.title,
    status: result.status,
    summary: result.summary,
    rows: result.rows,
    rawPreview: result.rawPreview
  }];
  const components: A2uiComponent[] = [
    {
      id: 'root',
      component: 'SurfaceRoot',
      child: 'results',
      title: result.title,
      status: 'ready'
    },
    {
      id: 'results',
      component: 'GenericToolResults',
      title: result.title,
      body: '以下展示瑞幸 MCP 的真实返回字段。',
      status: 'ready',
      dataPath: '/genericToolResults',
      actions: actions
    }
  ];
  const summaryData: A2uiSummaryData = {
    text: result.summary,
    toolName: result.toolName,
    dataLabel: 'genericToolResults',
    count: 1
  };
  const envelopes: A2uiEnvelope[] = [
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: result.title,
        intent: 'luckin',
        status: 'ready',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
        components: components
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/genericToolResults',
        value: results
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/summary',
        value: summaryData
      }
    }
  ];
  return a2uiJsonl(envelopes);
}

function luckinErrorA2ui(surfaceId: string, toolId: string, title: string, message: string): string {
  return luckinDynamicResultA2ui(surfaceId, {
    sourceTag: '瑞幸',
    toolName: toolId,
    title: title,
    status: 'error',
    summary: message,
    rows: [{ label: '错误', value: message }],
    rawPreview: ''
  });
}

async function callLocalLuckinPreview(prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  const token = localProviderConfig.luckinMcpToken;
  const request = luckinActionArgs(args);
  if (token.length === 0) {
    return luckinErrorA2ui(surfaceId, 'luckin.order.preview', '瑞幸点单需要登录', '未配置 LUCKIN_MCP_TOKEN。请在瑞幸 AI 开放平台登录复制 Token 后同步到 HAP rawfile。');
  }
  const location = resolveLuckinLocation(request, prompt);
  if (location.length === 0) {
    return luckinErrorA2ui(surfaceId, 'luckin.order.preview', '瑞幸点单缺少位置', '瑞幸下单需要当前经纬度。请允许定位权限后重试。');
  }
  const shopArgs: LuckinShopListArgs = {
    deptName: '',
    longitude: Number(locationLongitude(location)),
    latitude: Number(locationLatitude(location))
  };
  const shopPayload = await callReadonlyBrandMcpTool('瑞幸', localProviderConfig.luckinMcpUrl, token, 'queryShopList', shopArgs);
  const shops = luckinShopsFromData(mcpPayloadData(shopPayload as LuckinPayload) as LuckinShopRecord[] | LuckinShopContainer | undefined);
  if (shops.length === 0) {
    return luckinErrorA2ui(surfaceId, 'luckin.order.preview', '没有找到可下单门店', '瑞幸 MCP 没有返回可用门店。请换一个地点或门店名称。');
  }
  if (textOf(request.deptId).length === 0) {
    const shopRows: A2uiLabelValueData[] = [];
    const previewCount = shops.length > 5 ? 5 : shops.length;
    for (let index = 0; index < previewCount; index++) {
      const candidate = shops[index];
      shopRows.push({
        label: luckinShopName(candidate),
        value: luckinShopAddress(candidate)
      });
    }
    return luckinGenericResultA2ui(surfaceId, 'luckin.order.preview', '选择瑞幸门店', '请选择要在哪家门店自取，选定后会继续查询商品并核价。', shopRows, '', luckinShopSelectActions(shops, location, prompt));
  }
  const shop = luckinSelectedShop(shops, textOf(request.deptId));
  if (shop === null || textOf(shop.deptId).length === 0) {
    return luckinErrorA2ui(surfaceId, 'luckin.order.preview', '没有找到可下单门店', '瑞幸 MCP 没有返回可用门店。请换一个地点或门店名称。');
  }
  const quantity = luckinQuantityFromPrompt(prompt);
  const groupName = textOf(request.attrGroup);
  const choiceName = textOf(request.attrChoice);
  const isOptionSwitch = groupName.length > 0 && choiceName.length > 0 && textOf(request.productId).length > 0;
  let product: LuckinProductRecord;
  if (isOptionSwitch) {
    const switchedProduct = await luckinLoadProductForOptionSwitch(shop, request, prompt, token);
    if (switchedProduct === null) {
      return luckinErrorA2ui(surfaceId, 'luckin.order.preview', '规格切换失败', '暂时无法切换「' + groupName + '」到「' + choiceName + '」。请稍后重试。');
    }
    product = switchedProduct;
  } else {
    const keyword = luckinProductSearchQuery(prompt, request);
    const productSearchArgs: LuckinProductSearchArgs = {
      deptId: Number(textOf(shop.deptId)),
      query: keyword
    };
    const productPayload = await callReadonlyBrandMcpTool('瑞幸', localProviderConfig.luckinMcpUrl, token, 'searchProductForMcp', productSearchArgs);
    const products = luckinProductsFromPayload(productPayload);
    if (products.length === 0 || textOf(products[0].productId).length === 0 || luckinProductSku(products[0]).length === 0) {
      return luckinErrorA2ui(surfaceId, 'luckin.order.preview', '没有找到可下单商品', '瑞幸 MCP 没有返回可创建订单的商品或 skuCode。关键词：' + keyword);
    }
    const searchProduct = products[0];
    product = await luckinLoadProductForPreview(shop, searchProduct, token);
  }
  const previewArgs: LuckinOrderRequestArgs = {
    deptId: Number(textOf(shop.deptId)),
    productList: [luckinOrderProduct(product, quantity)],
    longitude: Number(locationLongitude(location)),
    latitude: Number(locationLatitude(location)),
    remark: luckinRemarkFromPrompt(prompt)
  };
  const previewPayload = await callReadonlyBrandMcpTool('瑞幸', localProviderConfig.luckinMcpUrl, token, 'previewOrder', previewArgs);
  const preview = luckinOrderRecordFromPayload(previewPayload);
  const productPictureUrl = isOptionSwitch ?
    luckinPinnedProductPicture(request, product) :
    luckinProductPictureUrl(product);
  const createArgs: LuckinOrderActionArgs = {
    deptId: textOf(shop.deptId),
    deptName: luckinShopName(shop),
    address: luckinShopAddress(shop),
    distance: kmNumberDistanceText(firstText([shop.distanceDesc, shop.distance])),
    location: location,
    productId: textOf(product.productId),
    productName: luckinProductName(product),
    skuCode: luckinProductSku(product),
    pictureUrl: productPictureUrl,
    previewPrompt: luckinPreviewPromptFromProduct(prompt, product, quantity),
    quantity: quantity,
    price: firstText([preview.discountPrice, product.discountPrice, product.price, product.initPrice]),
    couponCodeList: preview.couponCodeList === undefined ? [] : preview.couponCodeList,
    remark: previewArgs.remark,
    attrSelections: luckinAttrSelectionsMapFromProduct(product)
  };
  const rows: A2uiLabelValueData[] = [
    { label: '门店', value: luckinShopName(shop) },
    { label: '地址', value: luckinShopAddress(shop) },
    { label: '商品', value: luckinProductName(product) + ' x' + quantity.toString() },
    { label: 'SKU', value: luckinProductSku(product) },
    { label: '商品图', value: productPictureUrl }
  ];
  luckinAttrOptionRows(product).forEach((row: A2uiLabelValueData) => {
    rows.push(row);
  });
  rows.push({ label: '原价', value: luckinMoney(preview.totalInitialPrice) });
  rows.push({ label: '优惠', value: luckinMoney(preview.privilegeMoney) });
  rows.push({ label: '应付', value: luckinMoney(firstText([preview.discountPrice, createArgs.price])) });
  rows.push({ label: '备注', value: textOf(createArgs.remark) });
  const action: A2uiAction = {
    id: 'luckin.order.create',
    label: '确认下单',
    prompt: '确认创建瑞幸订单',
    variant: 'primary',
    kind: 'prompt',
    args: createArgs as Object
  };
  return luckinGenericResultA2ui(surfaceId, 'luckin.order.preview', '确认瑞幸订单', '请确认后再创建真实瑞幸订单。', rows, JSON.stringify(previewPayload).substring(0, 1200), [action]);
}

function luckinPaymentContextArgs(request: LuckinOrderActionArgs, orderId: string, payOrderUrl: string, payOrderQrCodeUrl: string): LuckinOrderActionArgs {
  return {
    deptId: request.deptId,
    deptName: request.deptName,
    address: request.address,
    distance: request.distance,
    location: request.location,
    productId: request.productId,
    productName: request.productName,
    skuCode: request.skuCode,
    pictureUrl: request.pictureUrl,
    previewPrompt: request.previewPrompt,
    attrSelections: request.attrSelections,
    quantity: request.quantity,
    price: request.price,
    couponCodeList: request.couponCodeList,
    remark: request.remark,
    orderId: orderId,
    payOrderUrl: payOrderUrl,
    payOrderQrCodeUrl: payOrderQrCodeUrl
  };
}

function luckinDemoAlipayAction(orderId: string): A2uiAction {
  const args: LuckinOrderActionArgs = {
    orderId: orderId
  };
  return {
    id: 'luckin.demo.alipay.open',
    label: '支付宝支付（Demo）',
    prompt: 'alipays://',
    variant: 'secondary',
    kind: 'client',
    args: args
  };
}

function luckinDemoGooglePayAction(orderId: string): A2uiAction {
  const args: LuckinOrderActionArgs = {
    orderId: orderId
  };
  return {
    id: 'luckin.demo.googlepay.open',
    label: 'Google Pay 转 5 美金（Demo）',
    prompt: '用 Google Pay 给罗一格转 5 美金',
    variant: 'secondary',
    kind: 'client',
    args: args
  };
}

async function callLocalLuckinCreate(surfaceId: string, args: Object | null): Promise<string> {
  const token = localProviderConfig.luckinMcpToken;
  const request = luckinActionArgs(args);
  const location = resolveLuckinLocation(request, '');
  if (token.length === 0 || textOf(request.deptId).length === 0 || textOf(request.productId).length === 0 || textOf(request.skuCode).length === 0) {
    return luckinErrorA2ui(surfaceId, 'luckin.order.create', '瑞幸订单参数不足', '创建订单需要登录 Token、门店、商品和 skuCode。请先重新预览订单。');
  }
  const createArgs: LuckinOrderRequestArgs = {
    deptId: Number(textOf(request.deptId)),
    productList: [{
      productId: Number(textOf(request.productId)),
      skuCode: textOf(request.skuCode),
      amount: Number(textOf(request.quantity).length > 0 ? textOf(request.quantity) : '1')
    }],
    longitude: Number(locationLongitude(location)),
    latitude: Number(locationLatitude(location)),
    remark: textOf(request.remark)
  };
  const coupons = request.couponCodeList === undefined ? [] : request.couponCodeList;
  if (coupons.length > 0) {
    createArgs.couponCodeList = coupons;
  }
  const createPayload = await callReadonlyBrandMcpTool('瑞幸', localProviderConfig.luckinMcpUrl, token, 'createOrder', createArgs);
  const createError = luckinPayloadErrorMessage(createPayload);
  if (!luckinOrderCreateSucceededForTest(createPayload)) {
    const failure = createError.length > 0 ? createError : 'Provider 未返回订单号，本次不能视为创建成功。';
    return luckinErrorA2ui(surfaceId, 'luckin.order.create', '瑞幸订单创建失败', failure);
  }
  let created = luckinOrderRecordFromPayload(createPayload);
  let orderId = firstText([created.orderIdStr, created.orderId]);
  let payOrderUrl = textOf(created.payOrderUrl);
  let payOrderQrCodeUrl = textOf(created.payOrderQrCodeUrl);
  if (orderId.length > 0 && payOrderUrl.length === 0 && payOrderQrCodeUrl.length === 0) {
    try {
      const detailArgs: LuckinOrderActionArgs = {
        orderId: orderId
      };
      const detailPayload = await callReadonlyBrandMcpTool('瑞幸', localProviderConfig.luckinMcpUrl, token, 'queryOrderDetailInfo', detailArgs as Object);
      const detail = luckinOrderRecordFromPayload(detailPayload);
      orderId = firstText([detail.orderIdStr, detail.orderId, orderId]);
      payOrderUrl = firstText([detail.payOrderUrl, payOrderUrl]);
      payOrderQrCodeUrl = firstText([detail.payOrderQrCodeUrl, payOrderQrCodeUrl]);
      created = {
        discountPrice: firstText([detail.discountPrice, created.discountPrice]),
        totalInitialPrice: firstText([detail.totalInitialPrice, created.totalInitialPrice]),
        privilegeMoney: firstText([detail.privilegeMoney, created.privilegeMoney]),
        orderIdStr: orderId,
        payOrderUrl: payOrderUrl,
        payOrderQrCodeUrl: payOrderQrCodeUrl
      };
      aiLogInfo('[AIPhone][LuckinOrderCreateDetailFallback] orderId=' + orderId +
        ' payOrderUrlChars=' + payOrderUrl.length.toString() +
        ' payOrderQrCodeUrlChars=' + payOrderQrCodeUrl.length.toString());
    } catch (error) {
      aiLogInfo('[AIPhone][LuckinOrderCreateDetailFallbackError] ' + textOf(error));
    }
  }
  const rows: A2uiLabelValueData[] = [
    { label: '订单号', value: orderId },
    { label: '门店', value: textOf(request.deptName) },
    { label: '商品', value: textOf(request.productName) + ' x' + textOf(request.quantity) },
    { label: '商品图', value: textOf(request.pictureUrl) },
    { label: '原价', value: luckinMoney(firstText([created.totalInitialPrice])) },
    { label: '优惠', value: luckinMoney(firstText([created.privilegeMoney])) },
    { label: '应付', value: luckinMoney(firstText([created.discountPrice, request.price])) }
  ];
  luckinAttrOptionRowsFromSelections(luckinAttrSelectionsFromRequest(request)).forEach((row: A2uiLabelValueData) => {
    rows.push(row);
  });
  if (payOrderUrl.length > 0) {
    rows.push({ label: '支付链接', value: payOrderUrl });
  }
  if (payOrderQrCodeUrl.length > 0) {
    rows.push({ label: '支付二维码', value: payOrderQrCodeUrl });
  }
  const paymentContextArgs = luckinPaymentContextArgs(request, orderId, payOrderUrl, payOrderQrCodeUrl);
  const statusAction: A2uiAction = {
    id: 'luckin.order.status',
    label: '刷新订单状态',
    prompt: '查询瑞幸订单状态',
    variant: 'secondary',
    kind: 'prompt',
    args: paymentContextArgs as Object
  };
  const payAction: A2uiAction = {
    id: 'luckin.pay.open',
    label: payOrderUrl.length > 0 ? '打开微信支付' : '打开微信支付',
    prompt: payOrderUrl.length > 0 ? payOrderUrl : payOrderQrCodeUrl,
    variant: 'primary',
    kind: 'client',
    args: paymentContextArgs as Object
  };
  const createActions: A2uiAction[] = [payAction, luckinDemoAlipayAction(orderId), luckinDemoGooglePayAction(orderId), statusAction];
  luckinPayDiagnosticsLog('LuckinOrderCreate', orderId, payOrderUrl, payOrderQrCodeUrl, createActions.length);
  if (payOrderUrl.length === 0 && payOrderQrCodeUrl.length === 0) {
    aiLogInfo('[AIPhone][LuckinOrderCreateMissingPay] mcpDataKeys=' + luckinMcpPayFieldKeys(createPayload) +
      ' payloadPreview=' + JSON.stringify(createPayload).substring(0, 400));
  }
  return luckinGenericResultA2ui(
    surfaceId, 'luckin.order.create', '瑞幸订单已创建',
    'Provider 已返回真实订单号。', rows,
    JSON.stringify(createPayload).substring(0, 1200), createActions
  );
}

async function callStructuredLuckinStatusResult(args: Object | null): Promise<DynamicGenericToolResult> {
  const token = localProviderConfig.luckinMcpToken;
  const request = luckinActionArgs(args);
  const orderId = textOf(request.orderId);
  if (token.length === 0 || orderId.length === 0) {
    const message = token.length === 0 ? '未配置 LUCKIN_MCP_TOKEN。' : '缺少订单号。';
    return {
      sourceTag: '瑞幸',
      toolName: 'luckin.order.status',
      title: '无法查询瑞幸订单',
      status: token.length === 0 ? 'needs_auth' : 'error',
      summary: message,
      rows: [{ label: '错误', value: message }],
      rawPreview: ''
    };
  }
  const detailArgs: LuckinOrderActionArgs = {
    orderId: orderId
  };
  let payload: Object;
  try {
    payload = await callReadonlyBrandMcpTool('瑞幸', localProviderConfig.luckinMcpUrl, token, 'queryOrderDetailInfo', detailArgs);
  } catch (error) {
    return {
      sourceTag: '瑞幸',
      toolName: 'luckin.order.status',
      title: '瑞幸订单状态查询失败',
      status: 'error',
      summary: describeThrown(error),
      rows: [{ label: '错误', value: describeThrown(error) }],
      rawPreview: '',
      providerPhase: 'execution'
    };
  }
  const detail = luckinOrderRecordFromPayload(payload);
  const traceId = rideOrderPayloadText(payload, ['traceId', 'trace_id', 'requestId', 'request_id']);
  const rows: A2uiLabelValueData[] = [
    { label: '订单号', value: firstText([detail.orderIdStr, detail.orderId, orderId]) },
    { label: '订单状态', value: firstText([detail.orderStatusName, detail.orderStatus]) },
    { label: '取餐时间', value: firstText([detail.takeMealTime, detail.aboutTime]) },
    { label: '订单金额', value: luckinMoney(firstText([detail.discountPrice, detail.orderPayAmount])) },
    { label: '支付链接', value: firstText([detail.payOrderUrl, request.payOrderUrl]) },
    { label: '支付二维码', value: firstText([detail.payOrderQrCodeUrl, request.payOrderQrCodeUrl]) }
  ];
  if (traceId.length > 0) {
    rows.push({ label: 'Trace ID', value: traceId });
  }
  const payOrderUrl = firstText([detail.payOrderUrl, request.payOrderUrl]);
  const payOrderQrCodeUrl = firstText([detail.payOrderQrCodeUrl, request.payOrderQrCodeUrl]);
  const statusArgs: LuckinOrderActionArgs = {
    orderId: firstText([detail.orderIdStr, detail.orderId, orderId]),
    payOrderUrl: payOrderUrl,
    payOrderQrCodeUrl: payOrderQrCodeUrl
  };
  const statusAction: A2uiAction = {
    id: 'luckin.order.status',
    label: '刷新订单状态',
    prompt: '查询瑞幸订单状态',
    variant: 'secondary',
    kind: 'prompt',
    args: statusArgs
  };
  const payAction: A2uiAction = {
    id: 'luckin.pay.open',
    label: payOrderUrl.length > 0 ? '打开微信支付' : '打开支付二维码',
    prompt: payOrderUrl.length > 0 ? payOrderUrl : payOrderQrCodeUrl,
    variant: 'primary',
    kind: 'client',
    args: statusArgs
  };
  const resolvedOrderId = firstText([detail.orderIdStr, detail.orderId, orderId]);
  const statusActions: A2uiAction[] = [];
  if (payOrderUrl.length > 0 || payOrderQrCodeUrl.length > 0) {
    statusActions.push(payAction);
  } else if (resolvedOrderId.length > 0) {
    statusActions.push({
      id: 'luckin.pay.open',
      label: '打开微信支付',
      prompt: '',
      variant: 'primary',
      kind: 'client',
      args: statusArgs
    });
  }
  statusActions.push(luckinDemoAlipayAction(resolvedOrderId), luckinDemoGooglePayAction(resolvedOrderId), statusAction);
  luckinPayDiagnosticsLog('LuckinOrderStatus', resolvedOrderId, payOrderUrl, payOrderQrCodeUrl, statusActions.length);
  if (payOrderUrl.length === 0 && payOrderQrCodeUrl.length === 0) {
    aiLogInfo('[AIPhone][LuckinOrderStatusMissingPay] mcpDataKeys=' + luckinMcpPayFieldKeys(payload));
  }
  const providerError = luckinPayloadErrorMessage(payload);
  return {
    sourceTag: '瑞幸',
    toolName: 'luckin.order.status',
    title: providerError.length > 0 ? '瑞幸订单状态查询失败' : '瑞幸订单状态',
    status: providerError.length > 0 ? 'error' :
      (firstText([detail.orderStatusName, detail.orderStatus]).length > 0 ? 'success' : 'empty'),
    summary: providerError.length > 0 ? providerError :
      firstText([detail.orderStatusName, detail.orderStatus, '瑞幸查询成功，但没有返回订单状态。']),
    rows: rows,
    rawPreview: JSON.stringify(payload).substring(0, 1200),
    actions: statusActions,
    providerPhase: 'execution'
  };
}

async function callLocalLuckinStatus(surfaceId: string, args: Object | null): Promise<string> {
  return luckinDynamicResultA2ui(surfaceId, await callStructuredLuckinStatusResult(args));
}

async function callLocalLuckinTool(
  toolId: string,
  prompt: string,
  surfaceId: string,
  actionId: string,
  args: Object | null = null
): Promise<string> {
  if (toolId === 'luckin.order.create') {
    if (actionId !== 'luckin.order.create') {
      return luckinErrorA2ui(
        surfaceId, toolId, '需要当前瑞幸订单确认', '请从当前订单预览点击确认下单。'
      );
    }
    return callLocalLuckinCreate(surfaceId, args);
  }
  if (toolId === 'luckin.order.status') {
    return callLocalLuckinStatus(surfaceId, args);
  }
  return callLocalLuckinPreview(prompt, surfaceId, args);
}

function normalizeFoodName(value: string): string {
  return value.toLowerCase()
    .replace(/\s+/g, '')
    .replace(/[·•\-_/|｜,，.。:：;；（）()【】\[\]{}]/g, '')
    .replace(/（.*?）/g, '')
    .replace(/\(.*?\)/g, '');
}

function normalizeFoodComparable(value: string): string {
  return normalizeFoodName(value)
    .replace(/北京市|北京城区|北京|上海市|上海城区|上海|深圳市|深圳|广州市|广州|杭州市|杭州|成都市|成都|重庆市|重庆|天津市|天津|南京市|南京|武汉市|武汉|西安市|西安|苏州市|苏州/g, '');
}

function foodMergeKey(item: A2uiFoodData): string {
  const name = normalizeFoodName(item.name);
  if (name.length > 0) {
    return 'name:' + name;
  }
  const address = normalizeFoodName(item.address);
  if (address.length > 0) {
    return 'address:' + address;
  }
  return 'distance:' + item.distance;
}

function foodBrandKey(item: A2uiFoodData): string {
  const name = item.name;
  const leftCn = name.indexOf('（');
  const leftAscii = name.indexOf('(');
  let cutIndex = -1;
  if (leftCn >= 0 && leftAscii >= 0) {
    cutIndex = Math.min(leftCn, leftAscii);
  } else if (leftCn >= 0) {
    cutIndex = leftCn;
  } else if (leftAscii >= 0) {
    cutIndex = leftAscii;
  }
  if (cutIndex > 0) {
    return normalizeFoodComparable(name.substring(0, cutIndex));
  }
  return '';
}

function normalizedFoodAddress(value: string): string {
  return normalizeFoodComparable(value)
    .replace(/街道|路南|路北|路东|路西|路中|门口|附近/g, '');
}

export function foodDistanceMeters(value: string): number {
  const compact = value.replace(/\s+/g, '');
  const match = /(\d+(?:\.\d+)?)/.exec(compact);
  if (match === null) {
    return 999999999;
  }
  const amount = Number(match[1]);
  if (isNaN(amount)) {
    return 999999999;
  }
  if (/千米|公里|km/i.test(compact)) {
    return amount * 1000;
  }
  return amount;
}

function foodDistanceClose(left: A2uiFoodData, right: A2uiFoodData): boolean {
  const leftMeters = foodDistanceMeters(left.distance);
  const rightMeters = foodDistanceMeters(right.distance);
  if (leftMeters >= 999999999 || rightMeters >= 999999999) {
    return false;
  }
  return Math.abs(leftMeters - rightMeters) <= 150;
}

function textContainsWithSignal(left: string, right: string, minLength: number): boolean {
  if (left.length < minLength || right.length < minLength) {
    return false;
  }
  return left.indexOf(right) >= 0 || right.indexOf(left) >= 0;
}

function foodAddressLikelySame(left: A2uiFoodData, right: A2uiFoodData): boolean {
  const leftAddress = normalizedFoodAddress(left.address);
  const rightAddress = normalizedFoodAddress(right.address);
  return textContainsWithSignal(leftAddress, rightAddress, 8);
}

function foodNamesLikelySame(left: A2uiFoodData, right: A2uiFoodData): boolean {
  const leftName = normalizeFoodComparable(left.name);
  const rightName = normalizeFoodComparable(right.name);
  if (leftName.length === 0 || rightName.length === 0) {
    return false;
  }
  if (leftName === rightName) {
    return true;
  }
  const leftBrand = foodBrandKey(left);
  const rightBrand = foodBrandKey(right);
  const sameBrand = leftBrand.length > 0 && leftBrand === rightBrand;
  if (sameBrand && textContainsWithSignal(leftName, rightName, 6)) {
    return true;
  }
  return textContainsWithSignal(leftName, rightName, 10) && foodDistanceClose(left, right);
}

function foodRecordsLikelySameStore(left: A2uiFoodData, right: A2uiFoodData): boolean {
  if (foodMergeKey(left) === foodMergeKey(right)) {
    return true;
  }
  if (foodNamesLikelySame(left, right)) {
    return true;
  }
  const leftBrand = foodBrandKey(left);
  const rightBrand = foodBrandKey(right);
  return leftBrand.length > 0 && leftBrand === rightBrand && foodAddressLikelySame(left, right) && foodDistanceClose(left, right);
}

function foodTags(item: A2uiFoodData, fallbackProvider: string): string[] {
  const tags: string[] = [];
  const rawTags: string[] = item.sourceTags === undefined || item.sourceTags === null ? [] : item.sourceTags;
  for (let index = 0; index < rawTags.length; index++) {
    const tag = textOf(rawTags[index]).trim();
    if (tag.length > 0 && tags.indexOf(tag) < 0) {
      tags.push(tag);
    }
  }
  if (tags.length === 0 && fallbackProvider.length > 0) {
    tags.push(fallbackProvider);
  }
  return tags;
}

function cloneFood(item: A2uiFoodData, fallbackProvider: string): A2uiFoodData {
  return {
    name: item.name,
    category: item.category,
    address: item.address,
    distance: item.distance,
    location: item.location,
    sourceTags: foodTags(item, fallbackProvider)
  };
}

function mergeFoodInto(target: A2uiFoodData, item: A2uiFoodData, fallbackProvider: string): void {
  const tags = foodTags(item, fallbackProvider);
  const targetTags: string[] = target.sourceTags === undefined || target.sourceTags === null ? [] : target.sourceTags;
  for (let index = 0; index < tags.length; index++) {
    if (targetTags.indexOf(tags[index]) < 0) {
      targetTags.push(tags[index]);
    }
  }
  target.sourceTags = targetTags;
  if (target.category.length === 0 && item.category.length > 0) {
    target.category = item.category;
  }
  if (target.address.length === 0 && item.address.length > 0) {
    target.address = item.address;
  }
  if (target.distance.length === 0 && item.distance.length > 0) {
    target.distance = item.distance;
    if (target.location === undefined || target.location.length === 0) {
      target.location = item.location;
    }
  } else if (item.distance.length > 0 && foodDistanceMeters(item.distance) < foodDistanceMeters(target.distance)) {
    target.distance = item.distance;
    if (item.location !== undefined && item.location.length > 0) {
      target.location = item.location;
    }
  } else if ((target.location === undefined || target.location.length === 0) && item.location !== undefined && item.location.length > 0) {
    target.location = item.location;
  }
}

function appendUniqueText(values: string[], value: string): void {
  if (value.length > 0 && values.indexOf(value) < 0) {
    values.push(value);
  }
}

function foodHasSourceTag(item: A2uiFoodData, source: string): boolean {
  const tags: string[] = foodTags(item, '');
  return tags.indexOf(source) >= 0;
}

function addCoveredFoodSources(coveredSources: string[], item: A2uiFoodData): void {
  const tags: string[] = foodTags(item, '');
  for (let index = 0; index < tags.length; index++) {
    appendUniqueText(coveredSources, tags[index]);
  }
}

function visibleFoodSourceOrder(sourceOrder: string[]): string[] {
  const ordered: string[] = [];
  for (let index = 0; index < sourceOrder.length; index++) {
    if (sourceOrder[index] !== '高德') {
      appendUniqueText(ordered, sourceOrder[index]);
    }
  }
  for (let index = 0; index < sourceOrder.length; index++) {
    if (sourceOrder[index] === '高德') {
      appendUniqueText(ordered, sourceOrder[index]);
    }
  }
  return ordered;
}

function foodSourceCount(item: A2uiFoodData): number {
  return foodTags(item, '').length;
}

export interface FoodPreferenceArgs {
  brandPreference?: string;
  brandStrict?: boolean;
  sweetness?: string;
}

function foodPreferenceArgs(args: Object | null): FoodPreferenceArgs {
  if (args === null) {
    return {};
  }
  const raw = args as Record<string, Object | string | number | boolean | null | undefined>;
  const brand = textOf(raw.brandPreference).trim();
  const brandStrict = textOf(raw.brandStrict).trim();
  const sweetness = textOf(raw.sweetness).trim();
  const preferences: FoodPreferenceArgs = {};
  if (brand.length > 0) {
    preferences.brandPreference = brand;
  }
  if (brandStrict === 'true') {
    preferences.brandStrict = true;
  }
  if (sweetness.length > 0) {
    preferences.sweetness = sweetness;
  }
  return preferences;
}

function foodMatchesBrand(item: A2uiFoodData, brand: string): boolean {
  return brand.length > 0 && (item.name.indexOf(brand) >= 0 || foodHasSourceTag(item, brand));
}

function preferredFoodScore(item: A2uiFoodData, preferences: FoodPreferenceArgs): number {
  const brand = preferences.brandPreference === undefined ? '' : preferences.brandPreference;
  if (foodMatchesBrand(item, brand)) {
    return -1000;
  }
  return 0;
}

function compareVisibleFood(left: A2uiFoodData, right: A2uiFoodData, preferences: FoodPreferenceArgs = {}): number {
  const preferenceDiff = preferredFoodScore(left, preferences) - preferredFoodScore(right, preferences);
  if (preferenceDiff !== 0) {
    return preferenceDiff;
  }
  const leftMerged = foodSourceCount(left) > 1 ? 0 : 1;
  const rightMerged = foodSourceCount(right) > 1 ? 0 : 1;
  if (leftMerged !== rightMerged) {
    return leftMerged - rightMerged;
  }
  const distanceDiff = foodDistanceMeters(left.distance) - foodDistanceMeters(right.distance);
  if (distanceDiff !== 0) {
    return distanceDiff;
  }
  return left.name.localeCompare(right.name);
}

function selectVisibleFoodResults(foods: A2uiFoodData[], preferences: FoodPreferenceArgs = {}): A2uiFoodData[] {
  const brand = preferences.brandPreference === undefined ? '' : preferences.brandPreference;
  const strictFoods = preferences.brandStrict === true ? foods.filter((item: A2uiFoodData): boolean => foodMatchesBrand(item, brand)) : [];
  const candidates = preferences.brandStrict === true ? strictFoods : foods;
  const sorted = candidates.slice();
  sorted.sort((left: A2uiFoodData, right: A2uiFoodData): number => compareVisibleFood(left, right, preferences));
  const sourceOrder: string[] = [];
  for (let index = 0; index < sorted.length; index++) {
    addCoveredFoodSources(sourceOrder, sorted[index]);
  }
  const selected: A2uiFoodData[] = [];
  const orderedSources = visibleFoodSourceOrder(sourceOrder);
  for (let sourceIndex = 0; sourceIndex < orderedSources.length && selected.length < FOOD_AGGREGATED_RESULT_LIMIT; sourceIndex++) {
    for (let foodIndex = 0; foodIndex < sorted.length; foodIndex++) {
      if (selected.indexOf(sorted[foodIndex]) < 0 && foodHasSourceTag(sorted[foodIndex], orderedSources[sourceIndex])) {
        selected.push(sorted[foodIndex]);
        break;
      }
    }
  }
  for (let index = 0; index < sorted.length && selected.length < FOOD_AGGREGATED_RESULT_LIMIT; index++) {
    if (selected.indexOf(sorted[index]) < 0) {
      selected.push(sorted[index]);
    }
  }
  selected.sort((left: A2uiFoodData, right: A2uiFoodData): number => compareVisibleFood(left, right, preferences));
  return selected;
}

function findExistingFoodIndex(foods: A2uiFoodData[], item: A2uiFoodData): number {
  for (let index = 0; index < foods.length; index++) {
    if (foodRecordsLikelySameStore(foods[index], item)) {
      return index;
    }
  }
  return -1;
}

export function aggregateFoodProviderResults(results: FoodProviderResult[], preferences: FoodPreferenceArgs = {}): FoodAggregationResult {
  const foods: A2uiFoodData[] = [];
  const issues: FoodProviderResult[] = [];
  for (let resultIndex = 0; resultIndex < results.length; resultIndex++) {
    const result = results[resultIndex];
    if (result.error.length > 0 || result.foods.length === 0) {
      issues.push({
        provider: result.provider,
        foods: [],
        error: result.error.length > 0 ? result.error : result.provider + '没有返回可展示结果。'
      });
    }
    for (let foodIndex = 0; foodIndex < result.foods.length; foodIndex++) {
      const food = result.foods[foodIndex];
      if (food.name.length === 0) {
        continue;
      }
      const existingIndex = findExistingFoodIndex(foods, food);
      if (existingIndex >= 0) {
        mergeFoodInto(foods[existingIndex], food, result.provider);
      } else {
        foods.push(cloneFood(food, result.provider));
      }
    }
  }
  return {
    foods: selectVisibleFoodResults(foods, preferences),
    issues: issues
  };
}

export function providerIssueRows(issues: FoodProviderResult[]): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  for (let index = 0; index < issues.length; index++) {
    const issue = issues[index];
    rows.push({
      label: issue.provider,
      value: issue.error.length > 0 ? issue.error : issue.provider + '没有返回可展示结果。'
    });
  }
  return rows;
}

export function foodProviderProgressRows(providerNames: string[], completedResults: FoodProviderResult[]): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  for (let providerIndex = 0; providerIndex < providerNames.length; providerIndex++) {
    const providerName = providerNames[providerIndex];
    let completedResult: FoodProviderResult | null = null;
    for (let resultIndex = 0; resultIndex < completedResults.length; resultIndex++) {
      const candidate = completedResults[resultIndex];
      if (candidate.provider === providerName) {
        completedResult = candidate;
      }
    }
    if (completedResult === null) {
      rows.push({
        label: providerName,
        value: '等待中'
      });
    } else if (completedResult.error.length > 0) {
      rows.push({
        label: providerName,
        value: completedResult.error
      });
    } else {
      rows.push({
        label: providerName,
        value: '已返回 ' + completedResult.foods.length.toString() + ' 条'
      });
    }
  }
  return rows;
}

export async function streamFoodProviderResultsWithPartials(tasks: Promise<FoodProviderResult>[], initialResults: FoodProviderResult[], onPartial: (snapshot: FoodProviderPartialSnapshot) => void, partialDelayMs: number = 0, preferences: FoodPreferenceArgs = {}): Promise<FoodProviderStreamResult> {
  const providerResults: FoodProviderResult[] = initialResults.slice();
  let completed = 0;
  const delayMs = partialDelayMs > 0 ? partialDelayMs : 0;
  let partialChain: Promise<void> = Promise.resolve();
  const wrappedTasks: Promise<void>[] = [];
  for (let index = 0; index < tasks.length; index++) {
    wrappedTasks.push(tasks[index].then((result: FoodProviderResult) => {
      partialChain = partialChain.then(async () => {
        if (completed > 0 && delayMs > 0) {
          aiLogInfo('[AIPhone][LocalToolFoodPartialDelay] provider=' + result.provider +
            ' delayMs=' + delayMs.toString());
          await waitForDebugDelay(delayMs);
        }
        providerResults.push(result);
        completed += 1;
        const aggregated = aggregateFoodProviderResults(providerResults, preferences);
        onPartial({
          provider: result.provider,
          completed: completed,
          total: tasks.length,
          foods: aggregated.foods,
          issues: aggregated.issues,
          results: providerResults.slice()
        });
      });
      return partialChain;
    }));
  }
  await Promise.all(wrappedTasks);
  await partialChain;
  return {
    aggregation: aggregateFoodProviderResults(providerResults, preferences),
    results: providerResults
  };
}

function emptyProviderResult(
  provider: string,
  error: string,
  attempted: boolean = false,
  operation: string = 'search'
): FoodProviderResult {
  return {
    provider: provider,
    foods: [],
    error: error,
    attempted: attempted,
    succeeded: false,
    operation: operation
  };
}

function meituanRecordsFromContainer(value: MeituanUnionRecord[] | MeituanUnionRecordContainer | undefined): MeituanUnionRecord[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  const container = value as MeituanUnionRecordContainer;
  if (container.list !== undefined && container.list.length > 0) {
    return container.list;
  }
  if (container.records !== undefined && container.records.length > 0) {
    return container.records;
  }
  if (container.items !== undefined && container.items.length > 0) {
    return container.items;
  }
  if (container.products !== undefined && container.products.length > 0) {
    return container.products;
  }
  return [];
}

function meituanProviderError(payload: MeituanUnionPayload): string {
  const message = firstText([payload.error, payload.message, payload.msg]);
  const code = textOf(payload.code);
  const status = textOf(payload.status);
  if (code.length > 0 && code !== '0' && code !== '200') {
    return message.length > 0 ? message + '（code=' + code + '）' : '美团联盟返回 code=' + code;
  }
  if (status === '0' || status.toLowerCase() === 'false') {
    return message.length > 0 ? message : '美团联盟返回失败状态。';
  }
  return '';
}

function taobaoResponseResult(payload: TaobaoFlashPayload): TaobaoFlashResult {
  const response = payload.alibaba_alsc_union_eleme_promotion_storepromotion_query_response;
  if (response !== undefined) {
    if (response.result !== undefined) {
      return response.result;
    }
    if (response.data !== undefined) {
      if (Array.isArray(response.data)) {
        return { result_list: response.data };
      }
      return response.data as TaobaoFlashResult;
    }
  }
  const direct = payload as TaobaoFlashResponse;
  if (direct.result !== undefined) {
    return direct.result;
  }
  if (direct.data !== undefined) {
    if (Array.isArray(direct.data)) {
      return { result_list: direct.data };
    }
    return direct.data as TaobaoFlashResult;
  }
  return {};
}

function taobaoProviderError(payload: TaobaoFlashPayload): string {
  if (payload.error_response !== undefined) {
    return firstText([
      payload.error_response.sub_msg,
      payload.error_response.msg,
      payload.error_response.sub_code,
      payload.error_response.code
    ]);
  }
  const result = taobaoResponseResult(payload);
  if (textOf(result.success).toLowerCase() === 'false') {
    return firstText([result.msg_info, result.msg_code, '淘宝闪购返回失败状态。']);
  }
  return '';
}

function taobaoRecordsFromResult(result: TaobaoFlashResult): TaobaoFlashStoreRecord[] {
  if (result.result_list !== undefined && result.result_list.length > 0) {
    return result.result_list;
  }
  if (result.records !== undefined && result.records.length > 0) {
    return result.records;
  }
  if (result.data !== undefined && result.data.length > 0) {
    return result.data;
  }
  return [];
}

async function safeFoodProviderSearch(adapter: FoodProviderAdapter, prompt: string, query: FoodQuery, keyword: string, location: string, locationSource: string): Promise<FoodProviderResult> {
  try {
    return await adapter.search(prompt, query, keyword, location, locationSource);
  } catch (error) {
    return emptyProviderResult(adapter.name, describeThrown(error), true);
  }
}

function waitForDebugDelay(delayMs: number): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(resolve, delayMs);
  });
}

class AmapFoodProvider implements FoodProviderAdapter {
  name: string = '高德';

  async search(_prompt: string, _query: FoodQuery, keyword: string, location: string, locationSource: string): Promise<FoodProviderResult> {
    const key = localProviderConfig.amapKey;
    if (key.length === 0) {
      return emptyProviderResult(this.name, '未配置 AMAP_KEY');
    }
    if (location.length === 0) {
      return emptyProviderResult(this.name, '缺少经纬度，无法调用高德周边 POI。');
    }
    const foods: A2uiFoodData[] = [];
    const names: string[] = [];
    let totalPois = 0;
    let providerError = '';
    let providerSucceeded = false;
    const keywords = splitFoodSearchKeywords(keyword);
    for (let keywordIndex = 0; keywordIndex < keywords.length && keywordIndex < 4 && foods.length < FOOD_PROVIDER_RESULT_LIMIT; keywordIndex++) {
      const currentKeyword = keywords[keywordIndex];
      aiLogInfo('[AIPhone][LocalToolAmapRequest] keyChars=' + key.length.toString() +
        ' locationSource=' + locationSource + ' locationPresent=true keyword=' + currentKeyword);
      const payload = await amapJsonGet(buildQueryUrl(
        'https://restapi.amap.com/v3/place/around',
        ['key', 'location', 'types', 'keywords', 'radius', 'offset', 'page', 'extensions'],
        [key, location, '050000', currentKeyword, localProviderConfig.amapRadius, '10', '1', 'all']
      ));
      if (textOf(payload.status) !== '1') {
        const providerMessage = firstText([payload.info, payload.infocode, payload.message]);
        if (providerError.length === 0) {
          providerError = providerMessage.length > 0 ? providerMessage : JSON.stringify(payload).substring(0, 500);
        }
        continue;
      }
      providerSucceeded = true;
      const pois = payload.pois === undefined ? [] : payload.pois;
      totalPois += pois.length;
      for (let index = 0; index < pois.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
        const food = foodRecordForA2ui(pois[index]);
        const normalized = normalizeFoodName(food.name);
        if (food.name.length === 0 || names.indexOf(normalized) >= 0) {
          continue;
        }
        names.push(normalized);
        foods.push(food);
      }
    }
    aiLogInfo('[AIPhone][LocalToolAmapResult] pois=' + totalPois.toString() + ' returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : (providerError.length > 0 ? providerError : '高德没有返回可展示餐饮 POI。'),
      attempted: true,
      succeeded: providerSucceeded,
      operation: 'search'
    };
  }
}

class TencentMapFoodProvider implements FoodProviderAdapter {
  name: string = '腾讯地图';

  async search(_prompt: string, _query: FoodQuery, keyword: string, location: string, locationSource: string): Promise<FoodProviderResult> {
    const key = localProviderConfig.tencentMapKey;
    if (key.length === 0) {
      return emptyProviderResult(this.name, '未配置 TENCENT_MAP_KEY');
    }
    if (location.length === 0) {
      return emptyProviderResult(this.name, '缺少经纬度，无法调用腾讯地图周边搜索。');
    }
    const longitude = locationLongitude(location);
    const latitude = locationLatitude(location);
    if (longitude.length === 0 || latitude.length === 0) {
      return emptyProviderResult(this.name, '经纬度格式无效：' + location);
    }
    const boundary = 'nearby(' + latitude + ',' + longitude + ',' + localProviderConfig.amapRadius + ',1)';
    aiLogInfo('[AIPhone][LocalToolTencentMapRequest] endpoint=' + localProviderConfig.tencentMapApiUrl +
      ' keyChars=' + key.length.toString() + ' locationSource=' + locationSource + ' keyword=' + keyword);
    const response = await requestText(buildQueryUrl(
      localProviderConfig.tencentMapApiUrl,
      ['key', 'keyword', 'boundary', 'page_size', 'page_index', 'orderby'],
      [key, keyword, boundary, '10', '1', '_distance']
    ), userAgentHeaders());
    if (response.code < 200 || response.code >= 300) {
      return emptyProviderResult(this.name, 'HTTP ' + response.code.toString() + '：' + response.text.substring(0, 300), true);
    }
    const payload = JSON.parse(response.text) as TencentMapPayload;
    if (textOf(payload.status) !== '0') {
      const message = firstText([payload.message, payload.status]);
      return emptyProviderResult(this.name, message.length > 0 ? message : response.text.substring(0, 300), true);
    }
    const places = payload.data === undefined ? [] : payload.data;
    const foods: A2uiFoodData[] = [];
    for (let index = 0; index < places.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const food = foodRecordFromTencentMapPlace(places[index]);
      if (food.name.length > 0) {
        foods.push(food);
      }
    }
    aiLogInfo('[AIPhone][LocalToolTencentMapResult] rows=' + places.length.toString() + ' returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : '腾讯地图没有返回可展示餐饮 POI。',
      attempted: true,
      succeeded: true,
      operation: 'search'
    };
  }
}

class BaiduMapFoodProvider implements FoodProviderAdapter {
  name: string = '百度地图';

  async search(_prompt: string, _query: FoodQuery, keyword: string, location: string, locationSource: string): Promise<FoodProviderResult> {
    const ak = localProviderConfig.baiduMapAk;
    if (ak.length === 0) {
      return emptyProviderResult(this.name, '未配置 BAIDU_MAP_AK');
    }
    if (location.length === 0) {
      return emptyProviderResult(this.name, '缺少经纬度，无法调用百度地图地点检索。');
    }
    const longitude = locationLongitude(location);
    const latitude = locationLatitude(location);
    if (longitude.length === 0 || latitude.length === 0) {
      return emptyProviderResult(this.name, '经纬度格式无效：' + location);
    }
    aiLogInfo('[AIPhone][LocalToolBaiduMapRequest] endpoint=' + localProviderConfig.baiduMapApiUrl +
      ' akChars=' + ak.length.toString() + ' locationSource=' + locationSource + ' keyword=' + keyword);
    const response = await requestText(buildQueryUrl(
      localProviderConfig.baiduMapApiUrl,
      ['ak', 'query', 'location', 'radius', 'output', 'scope', 'coord_type', 'ret_coordtype', 'page_size', 'page_num'],
      [ak, keyword, latitude + ',' + longitude, localProviderConfig.amapRadius, 'json', '2', '2', 'gcj02ll', '10', '0']
    ), userAgentHeaders());
    if (response.code < 200 || response.code >= 300) {
      return emptyProviderResult(this.name, 'HTTP ' + response.code.toString() + '：' + response.text.substring(0, 300), true);
    }
    const payload = JSON.parse(response.text) as BaiduPlacePayload;
    if (textOf(payload.status) !== '0') {
      const message = firstText([payload.message, payload.status]);
      return emptyProviderResult(this.name, message.length > 0 ? message : response.text.substring(0, 300), true);
    }
    const places = payload.results === undefined ? [] : payload.results;
    const foods: A2uiFoodData[] = [];
    for (let index = 0; index < places.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const food = foodRecordFromBaiduPlace(places[index]);
      if (food.name.length > 0) {
        foods.push(food);
      }
    }
    aiLogInfo('[AIPhone][LocalToolBaiduMapResult] rows=' + places.length.toString() + ' returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : '百度地图没有返回可展示餐饮 POI。',
      attempted: true,
      succeeded: true,
      operation: 'search'
    };
  }
}

class GoogleMapsFoodProvider implements FoodProviderAdapter {
  name: string = 'Google Maps';

  async search(prompt: string, query: FoodQuery, keyword: string, _location: string, _locationSource: string): Promise<FoodProviderResult> {
    const searchQuery = query.place.length > 0 ? query.place + '附近的' + keyword : prompt;
    const results = await callMapsPlaceSearch(searchQuery, localProviderConfig.googleMapsApiKey);
    const foods: A2uiFoodData[] = [];
    let providerError = '';
    let providerSucceeded = results.length === 0;
    for (let index = 0; index < results.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const result = results[index];
      if (result.status !== 'success') {
        if (providerError.length === 0) {
          providerError = result.summary;
        }
        continue;
      }
      providerSucceeded = true;
      const food = mapsFoodRecordFromResult(result);
      if (food.name.length > 0 && food.location !== undefined && food.location.length > 0) {
        foods.push(food);
      }
    }
    aiLogInfo('[AIPhone][LocalToolGoogleMapsResult] rows=' + results.length.toString() + ' returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : (providerError.length > 0 ? providerError : 'Google Maps 没有返回可展示餐饮 POI。'),
      attempted: true,
      succeeded: providerSucceeded,
      operation: 'search'
    };
  }
}

class MeituanUnionFoodProvider implements FoodProviderAdapter {
  name: string = '美团';

  async search(_prompt: string, _query: FoodQuery, keyword: string, location: string, _locationSource: string): Promise<FoodProviderResult> {
    const appKey = localProviderConfig.meituanUnionAppKey;
    const appSecret = localProviderConfig.meituanUnionAppSecret;
    if (appKey.length === 0 || appSecret.length === 0) {
      return emptyProviderResult(this.name, '未配置 MEITUAN_UNION_APP_KEY 或 MEITUAN_UNION_APP_SECRET');
    }
    if (location.length === 0) {
      return emptyProviderResult(this.name, '缺少经纬度，无法按附近外卖商品查询。');
    }
    const longitude = coordinateToMicros(locationLongitude(location));
    const latitude = coordinateToMicros(locationLatitude(location));
    if (longitude.length === 0 || latitude.length === 0) {
      return emptyProviderResult(this.name, '经纬度格式无效：' + location);
    }
    const body = '{"platform":1,"bizLine":1,"searchText":' + JSON.stringify(keyword) +
      ',"longitude":' + longitude +
      ',"latitude":' + latitude +
      ',"pageSize":10,"pageNo":1}';
    const timestamp = new Date().getTime().toString();
    const contentMd5 = md5Base64(body);
    const signature = meituanUnionSignature(appSecret, appKey, timestamp, contentMd5, body);
    aiLogInfo('[AIPhone][LocalToolMeituanRequest] endpoint=' + localProviderConfig.meituanUnionApiUrl +
      ' keyChars=' + appKey.length.toString() + ' keyword=' + keyword + ' bodyChars=' + body.length.toString());
    const response = await postJsonText(localProviderConfig.meituanUnionApiUrl, {
      'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Content-MD5': contentMd5,
      'S-Ca-App': appKey,
      'S-Ca-Timestamp': timestamp,
      'S-Ca-Signature-Headers': 'S-Ca-Timestamp,S-Ca-App',
      'S-Ca-Signature': signature
    }, body);
    if (response.code < 200 || response.code >= 300) {
      return emptyProviderResult(this.name, 'HTTP ' + response.code.toString() + '：' + response.text.substring(0, 300), true);
    }
    const payload = JSON.parse(response.text) as MeituanUnionPayload;
    const providerError = meituanProviderError(payload);
    if (providerError.length > 0) {
      return emptyProviderResult(this.name, providerError, true);
    }
    const records = meituanRecordsFromContainer(payload.data).length > 0 ?
      meituanRecordsFromContainer(payload.data) :
      meituanRecordsFromContainer(payload.result);
    const foods: A2uiFoodData[] = [];
    for (let index = 0; index < records.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const food = foodRecordFromMeituanUnion(records[index]);
      if (food.name.length > 0) {
        foods.push(food);
      }
    }
    aiLogInfo('[AIPhone][LocalToolMeituanResult] rows=' + records.length.toString() + ' returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : '美团联盟没有返回可展示外卖商品券。',
      attempted: true,
      succeeded: true,
      operation: 'search'
    };
  }
}

class TaobaoFlashFoodProvider implements FoodProviderAdapter {
  name: string = '淘宝闪购';

  async search(_prompt: string, _query: FoodQuery, keyword: string, location: string, _locationSource: string): Promise<FoodProviderResult> {
    const appKey = localProviderConfig.taobaoAppKey;
    const appSecret = localProviderConfig.taobaoAppSecret;
    const pid = localProviderConfig.taobaoFlashPid;
    if (appKey.length === 0 || appSecret.length === 0 || pid.length === 0) {
      return emptyProviderResult(this.name, '未配置 TAOBAO_APP_KEY、TAOBAO_APP_SECRET 或 TAOBAO_FLASH_PID');
    }
    if (location.length === 0) {
      return emptyProviderResult(this.name, '缺少经纬度，无法调用淘宝闪购店铺推广查询。');
    }
    const longitude = locationLongitude(location);
    const latitude = locationLatitude(location);
    if (longitude.length === 0 || latitude.length === 0) {
      return emptyProviderResult(this.name, '经纬度格式无效：' + location);
    }
    const queryRequest = '{"pid":' + JSON.stringify(pid) +
      ',"longitude":' + JSON.stringify(longitude) +
      ',"latitude":' + JSON.stringify(latitude) +
      ',"search_content":' + JSON.stringify(keyword) +
      ',"page_size":10,"include_dynamic":true}';
    const params: FoodParamPair[] = [
      { key: 'method', value: 'alibaba.alsc.union.eleme.promotion.storepromotion.query' },
      { key: 'app_key', value: appKey },
      { key: 'timestamp', value: formatTopTimestamp(new Date()) },
      { key: 'format', value: 'json' },
      { key: 'v', value: '2.0' },
      { key: 'sign_method', value: 'md5' },
      { key: 'simplify', value: 'true' },
      { key: 'query_request', value: queryRequest }
    ];
    params.push({ key: 'sign', value: topMd5Sign(params, appSecret) });
    const body = encodeForm(params);
    aiLogInfo('[AIPhone][LocalToolTaobaoFlashRequest] endpoint=' + localProviderConfig.taobaoApiUrl +
      ' keyChars=' + appKey.length.toString() + ' pidChars=' + pid.length.toString() +
      ' keyword=' + keyword + ' bodyChars=' + body.length.toString());
    const response = await postFormText(localProviderConfig.taobaoApiUrl, {
      'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1',
      'Accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8'
    }, body);
    if (response.code < 200 || response.code >= 300) {
      return emptyProviderResult(this.name, 'HTTP ' + response.code.toString() + '：' + response.text.substring(0, 300), true);
    }
    const payload = JSON.parse(response.text) as TaobaoFlashPayload;
    const providerError = taobaoProviderError(payload);
    if (providerError.length > 0) {
      return emptyProviderResult(this.name, providerError, true);
    }
    const result = taobaoResponseResult(payload);
    const records = taobaoRecordsFromResult(result);
    const foods: A2uiFoodData[] = [];
    for (let index = 0; index < records.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const food = foodRecordFromTaobaoFlashStore(records[index]);
      if (food.name.length > 0) {
        foods.push(food);
      }
    }
    aiLogInfo('[AIPhone][LocalToolTaobaoFlashResult] rows=' + records.length.toString() + ' returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : '淘宝闪购没有返回可展示店铺推广结果。',
      attempted: true,
      succeeded: true,
      operation: 'search'
    };
  }
}

function foodPartialA2ui(surfaceId: string, prompt: string, providerNames: string[], snapshot: FoodProviderPartialSnapshot, previous: A2uiPartialUpdateCache | null): A2uiPartialUpdateResult {
  const rows = foodProviderProgressRows(providerNames, snapshot.results);
  return planA2uiPartialUpdate(previous, foodA2uiRenderState(
    surfaceId,
    '外卖聚合搜索',
    '以下结果来自高德、腾讯地图、百度地图、Google Maps、美团联盟、淘宝闪购联盟，以及已配置的麦当劳/瑞幸官方 MCP；仅展示真实返回字段，不下单、不支付、不创建购物车。',
    '已返回 ' + snapshot.completed.toString() + '/' + snapshot.total.toString() +
      ' 个餐饮来源；当前可展示 ' + snapshot.foods.length.toString() + ' 个结果。用户请求：' + prompt,
    snapshot.foods,
    rows,
    'calling_tool'
  ));
}

function shouldQueryMcDonalds(prompt: string, keyword: string): boolean {
  return /麦当劳|mcdonald|mcd|巨无霸|麦乐鸡|麦辣|薯条|汉堡|板烧|麦乐送/i.test(prompt + ' ' + keyword);
}

function shouldQueryLuckin(prompt: string, keyword: string): boolean {
  return /瑞幸|luckin|咖啡|拿铁|美式|生椰|冰萃|澳瑞白|厚乳|饮品/i.test(prompt + ' ' + keyword);
}

function inferFoodCityFromText(text: string): string {
  const direct = inferAmapCityFromPlace(text);
  if (direct.length > 0) {
    return direct;
  }
  const cityMatch = /(北京|上海|天津|重庆|深圳|广州|杭州|成都|武汉|南京|西安|苏州|厦门|青岛|长沙|昆明|海口|三亚|东莞|佛山|郑州|宁波|无锡|合肥|福州|济南|沈阳|大连)/u.exec(text);
  return cityMatch === null ? '深圳' : cityMatch[1];
}

function brandSearchKeyword(prompt: string, query: FoodQuery, fallback: string): string {
  if (query.place.length > 0) {
    return query.place;
  }
  const cleaned = prompt
    .replace(/麦当劳|瑞幸|luckin|mcdonald|mcd/ig, '')
    .replace(/附近|周边|查询|查|搜索|帮我|门店|菜单|有什么|外卖|点餐/g, '')
    .trim();
  return cleaned.length > 0 ? cleaned : fallback;
}

function wantsBrandMenu(prompt: string, keyword: string): boolean {
  return /菜单|餐品|商品|价格|多少钱|套餐|汉堡|薯条|麦乐鸡|咖啡|拿铁|美式|生椰|冰萃|饮品/u.test(prompt + ' ' + keyword);
}

class McDonaldsMcpFoodProvider implements FoodProviderAdapter {
  name: string = '麦当劳';

  async search(prompt: string, query: FoodQuery, keyword: string, _location: string, _locationSource: string): Promise<FoodProviderResult> {
    const token = localProviderConfig.mcdMcpToken;
    if (token.length === 0) {
      return emptyProviderResult(this.name, '未配置 MCD_MCP_TOKEN');
    }
    const city = inferFoodCityFromText(query.place.length > 0 ? query.place : prompt);
    const searchKeyword = brandSearchKeyword(prompt, query, keyword);
    const storeArgs: McDonaldsNearbyStoresArgs = {
      searchType: 2,
      beType: 1,
      city: city,
      keyword: searchKeyword
    };
    const storePayload = await callReadonlyBrandMcpTool(this.name, localProviderConfig.mcdMcpUrl, token, 'query-nearby-stores', storeArgs);
    let foods = foodRecordsFromMcDonaldsMcpTool('query-nearby-stores', storePayload);
    const firstStore = firstMcDonaldsStore(storePayload);
    if (wantsBrandMenu(prompt, keyword) && firstStore !== null && textOf(firstStore.storeCode).length > 0) {
      const menuArgs: McDonaldsMealsArgs = {
        storeCode: textOf(firstStore.storeCode),
        beCode: textOf(firstStore.beCode),
        orderType: 1,
        beType: 1
      };
      const menuPayload = await callReadonlyBrandMcpTool(this.name, localProviderConfig.mcdMcpUrl, token, 'query-meals', menuArgs);
      foods = foods.concat(foodRecordsFromMcDonaldsMcpTool('query-meals', menuPayload));
    }
    aiLogInfo('[AIPhone][LocalToolMcDonaldsMcpResult] returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : '麦当劳 MCP 没有返回可展示的门店或菜单结果。',
      attempted: true,
      succeeded: true,
      operation: 'search'
    };
  }
}

class LuckinMcpFoodProvider implements FoodProviderAdapter {
  name: string = '瑞幸';

  async search(prompt: string, _query: FoodQuery, keyword: string, location: string, _locationSource: string): Promise<FoodProviderResult> {
    const token = localProviderConfig.luckinMcpToken;
    if (token.length === 0) {
      return emptyProviderResult(this.name, '未配置 LUCKIN_MCP_TOKEN');
    }
    if (location.length === 0) {
      return emptyProviderResult(this.name, '缺少经纬度，无法调用瑞幸门店查询。');
    }
    const longitude = locationLongitude(location);
    const latitude = locationLatitude(location);
    if (longitude.length === 0 || latitude.length === 0) {
      return emptyProviderResult(this.name, '经纬度格式无效：' + location);
    }
    const emptyQuery: FoodQuery = { place: '', keyword: keyword };
    const shopArgs: LuckinShopListArgs = {
      deptName: /瑞幸|luckin/i.test(prompt) ? brandSearchKeyword(prompt, emptyQuery, '') : '',
      longitude: Number(longitude),
      latitude: Number(latitude)
    };
    const shopPayload = await callReadonlyBrandMcpTool(this.name, localProviderConfig.luckinMcpUrl, token, 'queryShopList', shopArgs);
    let foods = foodRecordsFromLuckinMcpTool('queryShopList', shopPayload);
    const firstShop = firstLuckinShop(shopPayload);
    if (wantsBrandMenu(prompt, keyword) && firstShop !== null && textOf(firstShop.deptId).length > 0) {
      const productArgs: LuckinProductSearchArgs = {
        deptId: Number(textOf(firstShop.deptId)),
        query: keyword
      };
      const productPayload = await callReadonlyBrandMcpTool(this.name, localProviderConfig.luckinMcpUrl, token, 'searchProductForMcp', productArgs);
      foods = foods.concat(foodRecordsFromLuckinMcpTool('searchProductForMcp', productPayload));
    }
    aiLogInfo('[AIPhone][LocalToolLuckinMcpResult] returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : '瑞幸 MCP 没有返回可展示的门店或商品结果。',
      attempted: true,
      succeeded: true,
      operation: 'search'
    };
  }
}

type FoodStructuredPartialObserver = (
  providerNames: string[], snapshot: FoodProviderPartialSnapshot
) => void;

export function foodStructuredDataResultFromProviders(
  data: FoodStructuredData,
  providerResults: FoodProviderResult[]
): DataResult {
  const sources: DataSource[] = [];
  const sourceKeys: string[] = [];
  const warnings: string[] = [];
  let searchSucceeded = false;
  let operationAttempted = false;
  providerResults.forEach((providerResult: FoodProviderResult) => {
    const operation = providerResult.operation === undefined || providerResult.operation.length === 0 ?
      'search' : providerResult.operation;
    if (providerResult.attempted === true) {
      operationAttempted = true;
      const key = providerResult.provider + '\nlocal_adapter\n' + operation;
      if (sourceKeys.indexOf(key) < 0) {
        sourceKeys.push(key);
        sources.push(localAdapterSource(providerResult.provider, operation));
      }
    }
    if (operation === 'search' && (providerResult.succeeded === true || providerResult.foods.length > 0)) {
      searchSucceeded = true;
    }
    if (providerResult.error.length > 0) {
      warnings.push(providerResult.provider + '：' + providerResult.error);
    }
  });

  if (data.foods.length > 0 || searchSucceeded) {
    return foodStructuredDataResult(data, sources, warnings);
  }
  const error = structuredErrorWithData(
    'food.search',
    'foodChoices',
    data,
    operationAttempted ? 'FOOD_PROVIDER_ERROR' : 'FOOD_CONFIG_MISSING',
    data.summary,
    operationAttempted,
    sources,
    warnings
  );
  return error;
}

async function callStructuredFoodTool(
  prompt: string,
  args: Object | null,
  onPartial: FoodStructuredPartialObserver | null = null
): Promise<DataResult> {
  const key = localProviderConfig.amapKey;
  const preferences = foodPreferenceArgs(args);

  const query = extractFoodQuery(prompt);
  const preflightResults: FoodProviderResult[] = [];
  const provenanceResults: FoodProviderResult[] = [];
  let locationSource = 'none';
  let location = parseCoordinatePair(prompt);
  if (location.length > 0) {
    locationSource = 'prompt_coords';
  } else if (query.place.length > 0 && key.length > 0) {
    try {
      const resolved = await resolveFoodSearchLocation(query.place, key);
      location = resolved.location;
      locationSource = resolved.locationSource;
      provenanceResults.push({
        provider: '高德', foods: [], error: '', attempted: true, succeeded: true, operation: 'geocode'
      });
    } catch (error) {
      preflightResults.push(emptyProviderResult('高德', '地点解析失败：' + describeThrown(error), true, 'geocode'));
      locationSource = 'geocode_error';
    }
  }
  if (location.length === 0) {
    location = defaultConfiguredLocation();
    if (location.length > 0) {
      locationSource = 'rawfile_default';
    }
  }
  const keyword = extractFoodKeyword(prompt);

  const adapters: FoodProviderAdapter[] = [
    new AmapFoodProvider(),
    new TencentMapFoodProvider(),
    new BaiduMapFoodProvider(),
    new MeituanUnionFoodProvider(),
    new TaobaoFlashFoodProvider()
  ];
  if (localProviderConfig.googleMapsApiKey.length > 0) {
    adapters.push(new GoogleMapsFoodProvider());
  }
  if (shouldQueryMcDonalds(prompt, keyword)) {
    adapters.push(new McDonaldsMcpFoodProvider());
  }
  if (shouldQueryLuckin(prompt, keyword)) {
    adapters.push(new LuckinMcpFoodProvider());
  }
  const providerNames: string[] = [];
  for (let preflightIndex = 0; preflightIndex < preflightResults.length; preflightIndex++) {
    const providerName = preflightResults[preflightIndex].provider;
    if (providerNames.indexOf(providerName) < 0) {
      providerNames.push(providerName);
    }
  }
  for (let adapterIndex = 0; adapterIndex < adapters.length; adapterIndex++) {
    if (providerNames.indexOf(adapters[adapterIndex].name) < 0) {
      providerNames.push(adapters[adapterIndex].name);
    }
  }
  const providerResults: FoodProviderResult[] = preflightResults.slice();
  if (location.length === 0) {
    providerResults.push(emptyProviderResult('位置', '缺少经纬度。请在 prompt 写明地点，或把 AMAP_DEFAULT_LOCATION/FOOD_DEFAULT_LOCATION=经度,纬度 同步到 HAP rawfile。'));
    if (providerNames.indexOf('位置') < 0) {
      providerNames.push('位置');
    }
  }
  const tasks: Promise<FoodProviderResult>[] = [];
  for (let index = 0; index < adapters.length; index++) {
    tasks.push(safeFoodProviderSearch(adapters[index], prompt, query, keyword, location, locationSource));
  }
  const streamed = await streamFoodProviderResultsWithPartials(tasks, providerResults, (snapshot: FoodProviderPartialSnapshot) => {
    aiLogInfo('[AIPhone][LocalToolFoodPartial] provider=' + snapshot.provider +
      ' completed=' + snapshot.completed.toString() + '/' + snapshot.total.toString() +
      ' foods=' + snapshot.foods.length.toString() +
      ' issues=' + snapshot.issues.length.toString());
    if (onPartial !== null) {
      onPartial(providerNames, snapshot);
    }
  }, localToolDebugConfig.foodProviderDelayEnabled ? localToolDebugConfig.foodProviderDelayMs : 0, preferences);
  const aggregated = streamed.aggregation;
  const rows = foodProviderProgressRows(providerNames, streamed.results);
  const preferenceNote = preferences.brandPreference !== undefined && preferences.brandPreference.length > 0 ?
    (preferences.brandStrict === true ? '已按偏好只展示' : '已按偏好优先展示') + preferences.brandPreference + '相关真实结果。' : '';
  aiLogInfo('[AIPhone][LocalToolFoodAggregate] keyword=' + keyword +
    ' locationSource=' + locationSource +
    ' locationPresent=' + (location.length > 0 ? 'true' : 'false') +
    ' foods=' + aggregated.foods.length.toString() +
    ' issues=' + rows.length.toString());

  const data: FoodStructuredData = {
    title: '外卖聚合搜索',
    body: '以下结果来自高德、腾讯地图、百度地图、Google Maps、美团联盟、淘宝闪购联盟，以及已配置的麦当劳/瑞幸官方 MCP；仅展示真实返回字段，不下单、不支付、不创建购物车。' + preferenceNote,
    summary: aggregated.foods.length > 0 ?
      '已聚合 ' + aggregated.foods.length.toString() + ' 个可展示结果；' + rows.length.toString() + ' 个来源状态见下方。' :
      '所有来源都没有可展示外卖结果；下面只列出真实 provider 状态。',
    foods: aggregated.foods,
    rows: rows
  };
  return foodStructuredDataResultFromProviders(data, provenanceResults.concat(streamed.results));
}

async function callLocalFoodSearch(prompt: string, surfaceId: string, emitJsonl: LocalA2uiEmitter | null = null, args: Object | null = null): Promise<string> {
  let foodPartialCache: A2uiPartialUpdateCache | null = null;
  const result = await callStructuredFoodTool(prompt, args, (providerNames: string[], snapshot: FoodProviderPartialSnapshot) => {
    if (emitJsonl === null) {
      return;
    }
    const planned = foodPartialA2ui(surfaceId, prompt, providerNames, snapshot, foodPartialCache);
    foodPartialCache = planned.cache;
    aiLogInfo('[AIPhone][LocalToolFoodPartialEmit] envelopes=' + planned.emittedEnvelopeCount.toString() +
      ' components=' + (planned.componentsUpdated ? 'true' : 'false') +
      ' dataPaths=' + planned.updatedDataPaths.join(','));
    emitJsonl(planned.jsonl);
  });
  const data = result.data as FoodStructuredData;
  if (emitJsonl === null) {
    return foodStructuredDataA2ui(surfaceId, data);
  }
  const finalState = foodA2uiRenderState(
    surfaceId, data.title, data.body, data.summary, data.foods, data.rows, 'ready'
  );
  const planned = planA2uiPartialUpdate(foodPartialCache, finalState);
  aiLogInfo('[AIPhone][LocalToolFoodFinalEmit] envelopes=' + planned.emittedEnvelopeCount.toString() +
    ' components=' + (planned.componentsUpdated ? 'true' : 'false') +
    ' dataPaths=' + planned.updatedDataPaths.join(','));
  return planned.jsonl;
}

function trainErrorData(title: string, body: string): TrainStructuredData {
  return { title: title, body: body, summary: body, trains: [] };
}

async function callStructuredTrainTool(prompt: string): Promise<DataResult> {
  const source = prompt;
  const date = calendarDateFromPrompt(source);
  if (date.length === 0) {
    const message = '查询 12306 余票需要明确的出发地、目的地和日期。';
    return structuredErrorWithData(
      'train.search', 'trains', trainErrorData('12306 查询参数不足', message),
      'TRAIN_INVALID_ARGUMENTS', message
    );
  }
  let stations: StationCache;
  try {
    stations = await load12306Stations();
  } catch (error) {
    const message = describeThrown(error);
    return structuredErrorWithData(
      'train.search', 'trains', trainErrorData('12306 车站数据加载失败', message),
      'TRAIN_STATION_LOAD_ERROR', message, true, [], [message]
    );
  }
  const routeNames = extractRouteNames(source, stations.names);
  const departAfter = calendarTimeFromPrompt(source);
  if (routeNames.length < 2) {
    const message = '查询 12306 余票需要明确的出发地、目的地和日期。';
    return structuredErrorWithData(
      'train.search', 'trains', trainErrorData('12306 查询参数不足', message),
      'TRAIN_INVALID_ARGUMENTS', message
    );
  }

  const fromName = normalizeTrainStationName(routeNames[0], source);
  const toName = normalizeTrainStationName(routeNames[1], source);
  const fromCode = stationCodeFor(fromName, stations).length > 0 ? stationCodeFor(fromName, stations) : stationCodeFor(routeNames[0], stations);
  const toCode = stationCodeFor(toName, stations).length > 0 ? stationCodeFor(toName, stations) : stationCodeFor(routeNames[1], stations);
  if (fromCode.length === 0 || toCode.length === 0) {
    const message = '请使用更完整的车站名，例如北京南、上海虹桥、广州南、深圳北。';
    return structuredErrorWithData(
      'train.search', 'trains', trainErrorData('车站识别失败', message),
      'TRAIN_STATION_NOT_FOUND', message, false, [], routeNames
    );
  }

  const bookingUrl = build12306BookingUrl(date, fromName, fromCode, toName, toCode);

  let init: HttpTextResponse;
  let response: HttpTextResponse;
  try {
    init = await requestText('https://kyfw.12306.cn/otn/leftTicket/init', userAgentHeaders());
    const cookieHeader = cookieHeaderFromRaw(init.cookies + '\n' + init.headers);
    aiLogInfo('[AIPhone][LocalTool12306Request] from=' + fromName + '(' + fromCode + ') to=' + toName + '(' + toCode + ') date=' + date + ' initCode=' + init.code.toString() + ' cookieChars=' + cookieHeader.length.toString() + ' headerChars=' + init.headers.length.toString());
    response = await request12306LeftTicket(date, fromCode, toCode, leftTicketHeaders(cookieHeader));
  } catch (error) {
    const message = describeThrown(error);
    return structuredErrorWithData(
      'train.search', 'trains', trainErrorData('12306 查询失败', message),
      'TRAIN_TRANSPORT_EXCEPTION', message, true, [], [message]
    );
  }
  const sources: DataSource[] = [localAdapterSource('12306', 'leftTicket')];
  if (response.code < 200 || response.code >= 300) {
    const message = '12306 返回 HTTP ' + response.code.toString() + '。这是供应商或网络返回，不是 Mac gateway 连接失败。';
    return structuredErrorWithData(
      'train.search', 'trains', trainErrorData('12306 查询失败', message),
      'TRAIN_PROVIDER_HTTP_ERROR', message, response.code >= 500, sources, [response.text.substring(0, 500)]
    );
  }

  let payload: LeftTicketPayload;
  try {
    payload = JSON.parse(response.text) as LeftTicketPayload;
  } catch (_error) {
    const message = '12306 返回的内容不是有效 JSON。';
    return structuredErrorWithData(
      'train.search', 'trains', trainErrorData('12306 返回格式异常', message),
      'TRAIN_INVALID_RESPONSE', message, false, sources, [response.text.substring(0, 500)]
    );
  }
  const result = payload.data === undefined ? [] : payload.data.result;
  const rows = Array.isArray(result) ? result : [];
  let parsed: A2uiTrainData[] = [];
  rows.forEach((row: string) => {
    parsed.push(parse12306Row(row, stations));
  });
  parsed = filterHighSpeed(source, parsed);
  parsed = filterTrainsByDepartAfter(parsed, departAfter);

  const top: A2uiTrainData[] = [];
  const count = parsed.length > TRAIN_RESULT_LIMIT ? TRAIN_RESULT_LIMIT : parsed.length;
  for (let index = 0; index < count; index++) {
    top.push(normalizeTrainRecord(parsed[index], bookingUrl));
  }

  const timeSummary = departAfter.length > 0 ? departAfter + ' 后' : '';
  if (top.length === 0) {
    const emptyBody = timeSummary.length > 0
      ? date + ' ' + fromName + ' 到 ' + toName + ' ' + timeSummary + '暂时没有查询到可展示车次，可尝试调整时段或日期。'
      : date + ' ' + fromName + ' 到 ' + toName + ' 暂时没有查询到可展示车次，可能是日期未开售、线路调整或接口限制。';
    return trainStructuredDataResult({
      title: '12306 查询结果为空', body: emptyBody, summary: '12306 暂无可展示车次。', trains: []
    }, sources, ['12306 暂无可展示车次。']);
  }

  const summaryText = timeSummary.length > 0
    ? '已从 12306 查询到 ' + date + ' ' + fromName + ' 到 ' + toName + ' ' + timeSummary + '的车次。'
    : '已从 12306 查询到 ' + date + ' ' + fromName + ' 到 ' + toName + ' 的车次。';
  const body = timeSummary.length > 0
    ? '以下为 ' + timeSummary + '出发的 12306 实时查询结果，默认先展示 ' + TRAIN_INITIAL_VISIBLE.toString() + ' 趟。'
    : '以下为 12306 实时查询结果摘要，默认先展示 ' + TRAIN_INITIAL_VISIBLE.toString() + ' 趟。';
  aiLogInfo('[AIPhone][LocalTool12306Result] rows=' + rows.length.toString() + ' filtered=' + parsed.length.toString() + ' returned=' + top.length.toString());
  return trainStructuredDataResult({
    title: '12306 余票查询', body: body, summary: summaryText, trains: top
  }, sources);
}

export function trainDataResultA2ui(surfaceId: string, result: DataResult): string {
  const data = result.data as TrainStructuredData;
  if (result.status === 'error') {
    const code = result.error?.code === undefined ? '' : result.error?.code;
    if (code === 'TRAIN_INVALID_ARGUMENTS') {
      return errorA2ui(
        surfaceId, 'train.search', data.title, data.body,
        ['示例：明天北京到上海高铁票', '示例：2026-06-10 北京南到上海虹桥'],
        ['补充日期', '补充城市']
      );
    }
    if (code === 'TRAIN_STATION_LOAD_ERROR' ||
      code === 'TRAIN_TRANSPORT_EXCEPTION' ||
      code === 'TRAIN_INVALID_RESPONSE') {
      return legacyToolExceptionA2ui(surfaceId, 'train.search', data.body);
    }
    const details = result.warnings.length > 0 ? result.warnings : [data.summary];
    if (code === 'TRAIN_STATION_NOT_FOUND') {
      return errorA2ui(
        surfaceId, 'train.search', data.title, data.body, details, ['补充车站名']
      );
    }
    if (code === 'TRAIN_PROVIDER_HTTP_ERROR') {
      return errorA2ui(
        surfaceId, 'train.search', data.title, data.body, details, ['重新查询', '换日期或车站']
      );
    }
    return errorA2ui(
      surfaceId, 'train.search', data.title, data.body, details, ['重新查询', '换日期或车站']
    );
  }
  return trainStructuredDataA2ui(surfaceId, data);
}

async function callLocalTrainSearch(prompt: string, surfaceId: string): Promise<string> {
  return trainDataResultA2ui(surfaceId, await callStructuredTrainTool(prompt));
}

interface DynamicPromptArgs {
  query: string;
  prompt: string;
  city: string;
  weatherTargetOffset: number;
  weatherTargetDate: string;
  weatherTargetLabel: string;
  weatherForecast: boolean;
}

const dynamicToolRegistry: DynamicToolRegistry = new DynamicToolRegistry();
const genericMcpClient: GenericMcpClient = new GenericMcpClient();
const dynamicCredentialStore: AssetCredentialStore = new AssetCredentialStore();
const socialHubClient: SocialHubClient = new SocialHubClient();
let dynamicReadExecutor: DynamicReadExecutor = defaultDynamicReadExecutor;
let gmailMcpClient: GenericMcpClient = genericMcpClient;
let gmailComposioResultForTests: DynamicGenericToolResult | null = null;
let hotelMcpClient: GenericMcpClient = genericMcpClient;
let gmailCredentialStore: CredentialStore = dynamicCredentialStore;
export type HotelTimestampProvider = () => string;
const defaultHotelTimestampProvider: HotelTimestampProvider = (): string => new Date().toISOString();
let hotelTimestampProvider: HotelTimestampProvider = defaultHotelTimestampProvider;

export function configureGmailMcpClientForTests(client: GenericMcpClient | null): void {
  gmailMcpClient = client === null ? genericMcpClient : client;
}

export function configureGmailComposioResultForTests(result: DynamicGenericToolResult | null): void {
  gmailComposioResultForTests = result;
}

export function configureDynamicReadExecutorForTests(executor: DynamicReadExecutor | null): void {
  dynamicReadExecutor = executor === null ? defaultDynamicReadExecutor : executor;
}

export function configureHotelMcpClientForTests(client: GenericMcpClient | null): void {
  hotelMcpClient = client === null ? genericMcpClient : client;
}

export function configureHotelTimestampProviderForTests(provider: HotelTimestampProvider | null): void {
  hotelTimestampProvider = provider === null ? defaultHotelTimestampProvider : provider;
}

export function configureGmailCredentialStoreForTests(store: CredentialStore | null): void {
  gmailCredentialStore = store === null ? dynamicCredentialStore : store;
}

function dynamicCityFromPrompt(prompt: string): string {
  if (prompt.indexOf('深圳') >= 0) {
    return '深圳';
  }
  if (prompt.indexOf('北京') >= 0) {
    return '北京';
  }
  if (prompt.indexOf('上海') >= 0) {
    return '上海';
  }
  if (prompt.indexOf('广州') >= 0) {
    return '广州';
  }
  return prompt;
}

function twoDigit(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

function localDateAfter(offset: number): string {
  const today = new Date();
  const target = new Date(today.getFullYear(), today.getMonth(), today.getDate() + offset);
  return target.getFullYear().toString() + '-' + twoDigit(target.getMonth() + 1) + '-' + twoDigit(target.getDate());
}

function dynamicWeatherTargetOffset(prompt: string): number {
  if (prompt.indexOf('大后天') >= 0) {
    return 3;
  }
  if (prompt.indexOf('后天') >= 0) {
    return 2;
  }
  if (prompt.indexOf('明天') >= 0 || prompt.indexOf('明日') >= 0) {
    return 1;
  }
  return 0;
}

function dynamicWeatherTargetLabel(offset: number): string {
  if (offset === 1) {
    return '明天';
  }
  if (offset === 2) {
    return '后天';
  }
  if (offset === 3) {
    return '大后天';
  }
  return '当前';
}

function dynamicArgsFromPrompt(prompt: string): DynamicPromptArgs {
  const weatherTargetOffset = dynamicWeatherTargetOffset(prompt);
  return {
    query: prompt,
    prompt: prompt,
    city: dynamicCityFromPrompt(prompt),
    weatherTargetOffset: weatherTargetOffset,
    weatherTargetDate: localDateAfter(weatherTargetOffset),
    weatherTargetLabel: dynamicWeatherTargetLabel(weatherTargetOffset),
    weatherForecast: weatherTargetOffset > 0
  };
}

interface DynamicReadRequestArgs {
  operation?: Object | string | number | boolean | null;
  qualifiedName?: Object | string | number | boolean | null;
  toolSlug?: Object | string | number | boolean | null;
}

function dynamicReadRequestArgs(args: Object | null): DynamicReadRequestArgs {
  return args === null ? JSON.parse('{}') as DynamicReadRequestArgs : args as DynamicReadRequestArgs;
}

function dynamicQualifiedName(args: DynamicReadRequestArgs): string {
  const qualified = textOf(args.qualifiedName).trim();
  return qualified.length > 0 ? qualified : textOf(args.toolSlug).trim();
}

function dynamicVerbTokens(value: string): string[] {
  return value.toLowerCase().split(/[^a-z0-9]+/).filter((token: string): boolean => token.length > 0);
}

function containsDynamicVerb(tokens: string[], verbs: string[]): boolean {
  return tokens.some((token: string): boolean => verbs.indexOf(token) >= 0);
}

function dynamicReadAuthorizationMessage(args: Object | null): string {
  const request = dynamicReadRequestArgs(args);
  const operation = textOf(request.operation).trim().toLowerCase();
  const qualifiedName = dynamicQualifiedName(request);
  const operationTokens = dynamicVerbTokens(operation.length > 0 ? operation : 'search');
  const qualifiedTokens = dynamicVerbTokens(qualifiedName);
  const writeVerbs = ['delete', 'create', 'update', 'send', 'write', 'execute', 'append', 'upload', 'publish'];
  const readVerbs = ['read', 'search', 'list', 'get', 'find', 'query', 'fetch', 'lookup'];
  if (containsDynamicVerb(operationTokens, writeVerbs) || containsDynamicVerb(qualifiedTokens, writeVerbs)) {
    return 'dynamic.search only allows read/search/list/get operations.';
  }
  if (!containsDynamicVerb(operationTokens, readVerbs)) {
    return 'Unknown dynamic operation: ' + (operation.length > 0 ? operation : 'unknown') + '.';
  }
  if (qualifiedName.length > 0 && !containsDynamicVerb(qualifiedTokens, readVerbs)) {
    return 'Unknown dynamic tool verb: ' + qualifiedName + '.';
  }
  return '';
}

function dynamicRegistration(
  provider: string,
  qualifiedName: string,
  inputSchema: Object,
  outputSchema: Object,
  receipt: string
): DynamicRegistrationMetadata {
  return {
    provider: provider,
    qualifiedName: qualifiedName,
    inputSchema: inputSchema,
    outputSchema: outputSchema,
    receipt: receipt
  };
}

function dynamicExecutionResult(
  result: DynamicGenericToolResult,
  registration: DynamicRegistrationMetadata
): DynamicReadExecution {
  return { results: [result], registration: registration };
}

function dynamicReadFailure(
  provider: string,
  qualifiedName: string,
  inputSchema: Object,
  message: string,
  status: string = 'error'
): DynamicReadExecution {
  const result = dynamicErrorResult(provider, qualifiedName, '动态读取失败', message);
  result.status = status;
  const registration = dynamicRegistration(provider, qualifiedName, inputSchema, new Object(), '');
  return dynamicExecutionResult(result, registration);
}

export function dynamicManifestRegistrationMetadata(
  provider: string,
  tool: DynamicMcpTool,
  result: DynamicGenericToolResult
): DynamicRegistrationMetadata {
  return dynamicRegistration(
    provider,
    tool.name,
    tool.inputSchema,
    tool.outputSchema ?? new Object(),
    dynamicReceiptFromProviderPayload(result.rawPreview)
  );
}

function dynamicManifestTool(manifest: DynamicToolManifest, name: string): DynamicMcpTool | null {
  for (let index = 0; index < manifest.tools.length; index++) {
    if (manifest.tools[index].name === name) {
      return manifest.tools[index];
    }
  }
  return null;
}

function dynamicManifestReadAllowed(tool: DynamicMcpTool, transport: DynamicToolTransport): boolean {
  if (tool.annotations?.readOnlyHint === true || transport.type === 'http_api' &&
    transportOption(transport, 'method', 'GET').toUpperCase() === 'GET') {
    return true;
  }
  const request: DynamicReadRequestArgs = {
    operation: 'read',
    qualifiedName: tool.name
  };
  return dynamicReadAuthorizationMessage(request as Object).length === 0;
}

async function dynamicManifestReadExecution(discovery: DynamicToolDiscoveryResult, prompt: string): Promise<DynamicReadExecution> {
  const manifest = discovery.manifest;
  const transport = selectBestRemoteTransport(manifest);
  const toolName = firstSafeToolName(manifest);
  const tool = dynamicManifestTool(manifest, toolName);
  if (transport === null || tool === null) {
    return dynamicReadFailure(manifest.displayName, toolName, new Object(),
      'No safe HAP-runnable dynamic read tool is available.');
  }
  if (!dynamicManifestReadAllowed(tool, transport)) {
    return dynamicReadFailure(manifest.displayName, tool.name, tool.inputSchema,
      'Dynamic tool is not a recognized read/search/list/get operation.', 'unsafe_action_blocked');
  }
  let credentialRef = '';
  let credentialValue = '';
  const requiredCredential = firstRequiredCredential(manifest);
  if (requiredCredential !== null) {
    credentialRef = credentialRefFor(manifest.id, requiredCredential.name);
    credentialValue = await dynamicCredentialStore.get(credentialRef);
    if (credentialValue.length === 0) {
      return dynamicReadFailure(manifest.displayName, tool.name, tool.inputSchema,
        'Dynamic read requires configured credentials.', 'needs_auth');
    }
  }
  const registration: DynamicToolRegistration = {
    toolId: discovery.toolId,
    manifestId: manifest.id,
    displayName: manifest.displayName,
    status: 'candidate',
    transport: transport,
    mcpToolName: tool.name,
    credentialRef: credentialRef,
    sourceUrl: manifest.sourceUrl,
    lastError: ''
  };
  let result: DynamicGenericToolResult;
  if (transport.type === 'http_api') {
    result = await callDynamicHttpApiTool(registration, credentialValue, prompt);
  } else {
    const preflight = await genericMcpClient.preflight(registration, credentialValue);
    if (!preflight.ok) {
      return dynamicReadFailure(manifest.displayName, tool.name, tool.inputSchema,
        preflight.message.length > 0 ? preflight.message : 'Dynamic MCP preflight failed.');
    }
    result = await genericMcpClient.callTool(registration, credentialValue, dynamicArgsFromPrompt(prompt));
  }
  const metadata = dynamicManifestRegistrationMetadata(manifest.displayName, tool, result);
  return dynamicExecutionResult(result, metadata);
}

async function defaultDynamicReadExecutor(prompt: string, args: Object | null): Promise<DynamicReadExecution> {
  const discovery = discoverDynamicToolForPrompt(prompt);
  if (discovery !== null) {
    return dynamicManifestReadExecution(discovery, prompt);
  }
  const result = await callComposioDynamic(prompt, args);
  if (result === null) {
    return dynamicReadFailure('dynamic.search', dynamicQualifiedName(dynamicReadRequestArgs(args)),
      new Object(), 'No matching dynamic read provider was found.');
  }
  const providedRegistration = result.registration;
  const qualifiedName = providedRegistration?.qualifiedName ??
    (dynamicQualifiedName(dynamicReadRequestArgs(args)).length > 0 ?
      dynamicQualifiedName(dynamicReadRequestArgs(args)) : result.toolName);
  const metadata = providedRegistration ?? dynamicRegistration(
    result.sourceTag,
    qualifiedName,
    new Object(),
    new Object(),
    dynamicReceiptFromProviderPayload(result.rawPreview)
  );
  result.registration = undefined;
  return dynamicExecutionResult(result, metadata);
}

function dynamicStructuredDataResult(execution: DynamicReadExecution): DataResult {
  const base = genericStructuredDataResult('dynamic.search', 'dynamicToolConnect', execution.results);
  const data: DynamicStructuredData = {
    results: execution.results,
    registration: execution.registration
  };
  base.data = data;
  const source: DataSource = {
    provider: execution.registration.provider,
    backend: execution.registration.provider === 'Composio' ? 'oauth_api' : 'mcp_remote',
    operation: execution.registration.qualifiedName,
    fetchedAt: new Date().toISOString()
  };
  if (execution.registration.receipt.length > 0) {
    source.receipt = execution.registration.receipt;
  }
  base.sources = [source];
  return base;
}

async function callStructuredDynamicTool(prompt: string, args: Object | null): Promise<DataResult> {
  const authorizationMessage = dynamicReadAuthorizationMessage(args);
  if (authorizationMessage.length > 0) {
    return errorDataResult(
      'dynamic.search', 'dynamicToolConnect', 'DYNAMIC_WRITE_NOT_ALLOWED', authorizationMessage
    );
  }
  try {
    return dynamicStructuredDataResult(await dynamicReadExecutor(prompt, args));
  } catch (error) {
    return errorDataResult(
      'dynamic.search', 'dynamicToolConnect', 'DYNAMIC_PROVIDER_ERROR', describeThrown(error), true
    );
  }
}

function transportOption(transport: DynamicToolTransport, key: string, fallback: string = ''): string {
  const fromProperty = (transport as Object as Record<string, string>)[key];
  if (typeof fromProperty === 'string' && fromProperty.trim().length > 0) {
    return fromProperty.trim();
  }
  const fromEnv = transport.env[key];
  return fromEnv === undefined || fromEnv === null || fromEnv.trim().length === 0 ? fallback : fromEnv.trim();
}

function appendQueryParam(url: string, key: string, value: string): string {
  if (key.length === 0 || value.length === 0) {
    return url;
  }
  const separator = url.indexOf('?') >= 0 ? '&' : '?';
  return url + separator + encodeURIComponent(key) + '=' + encodeURIComponent(value);
}

function appendFixedQuery(url: string, fixedQuery: string): string {
  const trimmed = fixedQuery.trim();
  if (trimmed.length === 0) {
    return url;
  }
  const separator = url.indexOf('?') >= 0 ? '&' : '?';
  return url + separator + trimmed;
}

function dynamicArgumentValue(args: DynamicPromptArgs, key: string): string {
  if (key === 'city') {
    return args.city;
  }
  if (key === 'prompt') {
    return args.prompt;
  }
  return args.query;
}

function dynamicHttpApiHeaders(transport: DynamicToolTransport, credentialValue: string): Record<string, string> {
  const headers: Record<string, string> = {};
  const keys = Object.keys(transport.headers);
  for (let index = 0; index < keys.length; index++) {
    const key = keys[index];
    headers[key] = transport.headers[key];
  }
  const placement = transportOption(transport, 'credentialPlacement', '');
  if (credentialValue.length > 0 && placement === 'header') {
    const headerName = transportOption(transport, 'credentialParam', 'Authorization');
    headers[headerName] = headerName.toLowerCase() === 'authorization' ? 'Bearer ' + credentialValue : credentialValue;
  }
  return headers;
}

function dynamicHttpApiFixedQuery(transport: DynamicToolTransport, args: DynamicPromptArgs): string {
  if (args.weatherForecast) {
    return transportOption(transport, 'forecastQuery', transportOption(transport, 'fixedQuery', ''));
  }
  return transportOption(transport, 'fixedQuery', '');
}

function dynamicHttpApiUrl(transport: DynamicToolTransport, credentialValue: string, args: DynamicPromptArgs): string {
  let url = appendFixedQuery(transport.url, dynamicHttpApiFixedQuery(transport, args));
  const queryParam = transportOption(transport, 'queryParam', 'query');
  url = appendQueryParam(url, queryParam, dynamicArgumentValue(args, queryParam));
  if (credentialValue.length > 0 && transportOption(transport, 'credentialPlacement', '') === 'query') {
    url = appendQueryParam(url, transportOption(transport, 'credentialParam', 'key'), credentialValue);
  }
  return url;
}

async function requestDynamicHttpApiGet(url: string, headers: Record<string, string>): Promise<HttpTextResponse> {
  const request = http.createHttp();
  const decoder = util.TextDecoder.create('utf-8');
  try {
    const response = await request.request(url, {
      method: http.RequestMethod.GET,
      header: headers,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 30000
    });
    let text = '';
    if (typeof response.result === 'string') {
      text = response.result;
    } else {
      text = decoder.decodeToString(new Uint8Array(response.result as ArrayBuffer));
    }
    return {
      code: response.responseCode,
      text: text,
      cookies: response.cookies === undefined ? '' : response.cookies,
      headers: JSON.stringify(response.header)
    };
  } catch (error) {
    throw new Error('Dynamic HTTP API GET failed: ' + describeThrown(error));
  } finally {
    request.destroy();
  }
}

function rowsFromAmapWeather(live: AmapWeatherLive): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  const pairs: A2uiLabelValueData[] = [
    { label: '城市', value: textOf(live.city) },
    { label: '天气', value: textOf(live.weather) },
    { label: '温度', value: textOf(live.temperature).length > 0 ? textOf(live.temperature) + '°C' : '' },
    { label: '风向', value: textOf(live.winddirection) },
    { label: '风力', value: textOf(live.windpower) },
    { label: '湿度', value: textOf(live.humidity).length > 0 ? textOf(live.humidity) + '%' : '' },
    { label: '发布时间', value: textOf(live.reporttime) }
  ];
  for (let index = 0; index < pairs.length; index++) {
    if (pairs[index].value.length > 0) {
      rows.push(pairs[index]);
    }
  }
  return rows;
}

function rowsFromAmapWeatherForecast(forecast: AmapWeatherForecast, cast: AmapWeatherCast): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  const pairs: A2uiLabelValueData[] = [
    { label: '城市', value: textOf(forecast.city) },
    { label: '预报日期', value: textOf(cast.date) },
    { label: '白天天气', value: textOf(cast.dayweather) },
    { label: '夜间天气', value: textOf(cast.nightweather) },
    { label: '白天温度', value: textOf(cast.daytemp).length > 0 ? textOf(cast.daytemp) + '°C' : '' },
    { label: '夜间温度', value: textOf(cast.nighttemp).length > 0 ? textOf(cast.nighttemp) + '°C' : '' },
    { label: '白天风向', value: textOf(cast.daywind) },
    { label: '白天风力', value: textOf(cast.daypower) },
    { label: '夜间风向', value: textOf(cast.nightwind) },
    { label: '夜间风力', value: textOf(cast.nightpower) },
    { label: '预报发布时间', value: textOf(forecast.reporttime) }
  ];
  for (let index = 0; index < pairs.length; index++) {
    if (pairs[index].value.length > 0) {
      rows.push(pairs[index]);
    }
  }
  return rows;
}

function selectAmapWeatherCast(forecast: AmapWeatherForecast, args: DynamicPromptArgs): AmapWeatherCast | null {
  if (forecast.casts === undefined || forecast.casts.length === 0) {
    return null;
  }
  for (let index = 0; index < forecast.casts.length; index++) {
    if (textOf(forecast.casts[index].date) === args.weatherTargetDate) {
      return forecast.casts[index];
    }
  }
  if (args.weatherTargetOffset >= 0 && args.weatherTargetOffset < forecast.casts.length) {
    return forecast.casts[args.weatherTargetOffset];
  }
  return forecast.casts[0];
}

function amapForecastSummary(forecast: AmapWeatherForecast, cast: AmapWeatherCast, args: DynamicPromptArgs): string {
  const city = textOf(forecast.city).length > 0 ? textOf(forecast.city) : args.city;
  const date = textOf(cast.date).length > 0 ? textOf(cast.date) : args.weatherTargetDate;
  const dayWeather = textOf(cast.dayweather);
  const nightWeather = textOf(cast.nightweather);
  const dayTemp = textOf(cast.daytemp);
  const nightTemp = textOf(cast.nighttemp);
  let summary = city + args.weatherTargetLabel + '（' + date + '）';
  if (dayWeather.length > 0) {
    summary += '白天' + dayWeather;
  }
  if (dayTemp.length > 0) {
    summary += '，' + dayTemp + '°C';
  }
  if (nightWeather.length > 0) {
    summary += '；夜间' + nightWeather;
  }
  if (nightTemp.length > 0) {
    summary += '，' + nightTemp + '°C';
  }
  return summary + '。';
}

function dynamicHttpApiResultFromJson(registration: DynamicToolRegistration, response: HttpTextResponse, args: DynamicPromptArgs): DynamicGenericToolResult {
  if (registration.mcpToolName === 'maps_weather') {
    const payload = JSON.parse(response.text) as AmapWeatherPayload;
    if (args.weatherForecast) {
      const forecast = payload.forecasts !== undefined && payload.forecasts.length > 0 ? payload.forecasts[0] : null;
      const cast = forecast === null ? null : selectAmapWeatherCast(forecast, args);
      if (response.code >= 200 && response.code < 300 && payload.status === '1' && forecast !== null && cast !== null) {
        return {
          sourceTag: registration.displayName,
          toolName: registration.mcpToolName,
          title: '高德天气预报',
          status: 'success',
          summary: amapForecastSummary(forecast, cast, args),
          rows: rowsFromAmapWeatherForecast(forecast, cast),
          rawPreview: response.text.substring(0, 1200)
        };
      }
    }
    const live = payload.lives !== undefined && payload.lives.length > 0 ? payload.lives[0] : null;
    if (response.code >= 200 && response.code < 300 && payload.status === '1' && live !== null) {
      return {
        sourceTag: registration.displayName,
        toolName: registration.mcpToolName,
        title: '高德天气查询',
        status: 'success',
        summary: textOf(live.city) + '当前天气：' + textOf(live.weather) + '，' + textOf(live.temperature) + '°C。',
        rows: rowsFromAmapWeather(live),
        rawPreview: response.text.substring(0, 1200)
      };
    }
    return {
      sourceTag: registration.displayName,
      toolName: registration.mcpToolName,
      title: '高德天气查询失败',
      status: 'error',
      summary: textOf(payload.info).length > 0 ? textOf(payload.info) : '高德天气 API 返回异常。',
      rows: [
        { label: 'HTTP', value: response.code.toString() },
        { label: 'infocode', value: textOf(payload.infocode) }
      ],
      rawPreview: response.text.substring(0, 1200)
    };
  }

  return {
    sourceTag: registration.displayName,
    toolName: registration.mcpToolName,
    title: '动态 HTTP API 返回',
    status: response.code >= 200 && response.code < 300 ? 'success' : 'error',
    summary: response.code >= 200 && response.code < 300 ? '已收到远程 HTTP API 返回。' : '远程 HTTP API 返回 HTTP ' + response.code.toString(),
    rows: [{ label: 'HTTP', value: response.code.toString() }],
    rawPreview: response.text.substring(0, 1200)
  };
}

async function callDynamicHttpApiTool(registration: DynamicToolRegistration, credentialValue: string, prompt: string): Promise<DynamicGenericToolResult> {
  const method = transportOption(registration.transport, 'method', 'GET').toUpperCase();
  if (method !== 'GET') {
    return dynamicErrorResult(registration.displayName, registration.mcpToolName, 'HTTP API 暂不支持', '当前 HAP 动态 HTTP API 只支持 GET。');
  }
  try {
    const args = dynamicArgsFromPrompt(prompt);
    const url = dynamicHttpApiUrl(registration.transport, credentialValue, args);
    const response = await requestDynamicHttpApiGet(url, dynamicHttpApiHeaders(registration.transport, credentialValue));
    return dynamicHttpApiResultFromJson(registration, response, args);
  } catch (error) {
    return dynamicErrorResult(registration.displayName, registration.mcpToolName, 'HTTP API 调用失败', describeThrown(error));
  }
}

function firstSafeToolName(manifest: DynamicToolManifest): string {
  for (let index = 0; index < manifest.tools.length; index++) {
    if (!isUnsafeMcpTool(manifest.tools[index].name, manifest.tools[index].description)) {
      return manifest.tools[index].name;
    }
  }
  return '';
}

function firstRequiredCredential(manifest: DynamicToolManifest): DynamicCredentialSpec | null {
  for (let index = 0; index < manifest.requiredCredentials.length; index++) {
    if (manifest.requiredCredentials[index].required) {
      return manifest.requiredCredentials[index];
    }
  }
  return null;
}

function credentialNameFromRef(credentialRef: string): string {
  const index = credentialRef.lastIndexOf(':');
  if (index < 0 || index >= credentialRef.length - 1) {
    return '';
  }
  return credentialRef.substring(index + 1);
}

function missingDynamicManifest(toolId: string): DynamicToolManifest {
  return {
    id: 'dynamic.missing.' + toolId,
    displayName: toolId,
    sourceUrl: '',
    hosted: false,
    fromSiteUrl: '',
    capabilities: [],
    requiredCredentials: [],
    transports: [],
    tools: []
  };
}

function manifestForRegistration(registration: DynamicToolRegistration): DynamicToolManifest {
  const sample = sampleManifestForToolId(registration.toolId);
  if (sample !== null) {
    return sample;
  }
  const credentials: DynamicCredentialSpec[] = [];
  const credentialName = credentialNameFromRef(registration.credentialRef);
  if (credentialName.length > 0) {
    credentials.push({
      name: credentialName,
      description: 'Credential required by remote MCP server',
      required: true,
      placement: 'header',
      scheme: 'Bearer',
      testValue: ''
    });
  }
  return {
    id: registration.manifestId,
    displayName: registration.displayName,
    sourceUrl: registration.sourceUrl,
    hosted: true,
    fromSiteUrl: registration.sourceUrl,
    capabilities: [],
    requiredCredentials: credentials,
    transports: [registration.transport],
    tools: [{
      name: registration.mcpToolName,
      description: '',
      inputSchema: new Object()
    }]
  };
}

function manifestWithInferredCredential(manifest: DynamicToolManifest, credential: DynamicCredentialSpec): DynamicToolManifest {
  const credentials: DynamicCredentialSpec[] = [credential];
  for (let index = 0; index < manifest.requiredCredentials.length; index++) {
    if (manifest.requiredCredentials[index].name !== credential.name) {
      credentials.push(manifest.requiredCredentials[index]);
    }
  }
  return {
    id: manifest.id,
    displayName: manifest.displayName,
    sourceUrl: manifest.sourceUrl,
    hosted: manifest.hosted,
    fromSiteUrl: manifest.fromSiteUrl,
    capabilities: manifest.capabilities.slice(),
    requiredCredentials: credentials,
    transports: manifest.transports,
    tools: manifest.tools
  };
}

function dynamicErrorResult(displayName: string, toolName: string, title: string, message: string): DynamicGenericToolResult {
  return {
    sourceTag: displayName,
    toolName: toolName,
    title: title,
    status: 'error',
    summary: message,
    rows: [{ label: '状态', value: 'error' }],
    rawPreview: message
  };
}

function enabledRegistration(registration: DynamicToolRegistration): DynamicToolRegistration {
  return {
    toolId: registration.toolId,
    manifestId: registration.manifestId,
    displayName: registration.displayName,
    status: 'enabled',
    transport: registration.transport,
    mcpToolName: registration.mcpToolName,
    credentialRef: registration.credentialRef,
    sourceUrl: registration.sourceUrl,
    lastError: ''
  };
}

function failedRegistration(registration: DynamicToolRegistration, message: string): DynamicToolRegistration {
  return {
    toolId: registration.toolId,
    manifestId: registration.manifestId,
    displayName: registration.displayName,
    status: 'preflight_failed',
    transport: registration.transport,
    mcpToolName: registration.mcpToolName,
    credentialRef: registration.credentialRef,
    sourceUrl: registration.sourceUrl,
    lastError: message
  };
}

async function callEnabledDynamicTool(registration: DynamicToolRegistration, credentialValue: string, prompt: string, surfaceId: string): Promise<string> {
  try {
    if (registration.transport.type === 'http_api') {
      const result = await callDynamicHttpApiTool(registration, credentialValue, prompt);
      return genericToolResultsA2ui(surfaceId, registration.toolId, [result]);
    }
    const result = await genericMcpClient.callTool(registration, credentialValue, dynamicArgsFromPrompt(prompt));
    return genericToolResultsA2ui(surfaceId, registration.toolId, [result]);
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    const result = dynamicErrorResult(registration.displayName, registration.mcpToolName, 'MCP 工具调用失败', message);
    return genericToolResultsA2ui(surfaceId, registration.toolId, [result]);
  }
}

async function preflightAndCallDynamicTool(
  registration: DynamicToolRegistration,
  manifest: DynamicToolManifest,
  credentialValue: string,
  prompt: string,
  surfaceId: string
): Promise<string> {
  try {
    if (registration.transport.type === 'http_api') {
      const next = enabledRegistration(registration);
      dynamicToolRegistry.setRegistration(next);
      return callEnabledDynamicTool(next, credentialValue, prompt, surfaceId);
    }
    const preflight = await genericMcpClient.preflight(registration, credentialValue);
    if (!preflight.ok) {
      const message = preflight.message.length > 0 ? preflight.message : '远程 MCP 预检失败。';
      if (preflight.inferredCredential !== null) {
        const inferredManifest = manifestWithInferredCredential(manifest, preflight.inferredCredential);
        const inferredRef = credentialRefFor(manifest.id, preflight.inferredCredential.name);
        dynamicToolRegistry.enableAlias(registration.toolId, inferredManifest, registration.mcpToolName, inferredRef);
        return connectCardA2ui(surfaceId, registration.toolId, inferredManifest, 'needs_auth', message, prompt);
      }
      dynamicToolRegistry.setRegistration(failedRegistration(registration, message));
      return connectCardA2ui(surfaceId, registration.toolId, manifest, 'preflight_failed', message, prompt);
    }
    const next = enabledRegistration(registration);
    dynamicToolRegistry.setRegistration(next);
    return callEnabledDynamicTool(next, credentialValue, prompt, surfaceId);
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    dynamicToolRegistry.setRegistration(failedRegistration(registration, message));
    return connectCardA2ui(surfaceId, registration.toolId, manifest, 'preflight_failed', message, prompt);
  }
}

async function buildRegisteredDynamicToolJsonl(registration: DynamicToolRegistration, prompt: string, surfaceId: string): Promise<string> {
  const manifest = manifestForRegistration(registration);
  const credentialValue = registration.credentialRef.length > 0 ? await dynamicCredentialStore.get(registration.credentialRef) : '';
  if (registration.credentialRef.length > 0 && credentialValue.length === 0 && registration.status !== 'enabled') {
    return connectCardA2ui(surfaceId, registration.toolId, manifest, 'needs_auth', '该工具需要凭据后才能测试连接。', prompt);
  }
  if (registration.status === 'enabled') {
    return callEnabledDynamicTool(registration, credentialValue, prompt, surfaceId);
  }
  return preflightAndCallDynamicTool(registration, manifest, credentialValue, prompt, surfaceId);
}

async function buildDynamicToolJsonlWithManifest(toolId: string, prompt: string, surfaceId: string, manifest: DynamicToolManifest): Promise<string> {
  const transport = selectBestRemoteTransport(manifest);
  if (transport === null) {
    return unsupportedTransportA2ui(surfaceId, toolId, manifest, prompt);
  }

  const mcpToolName = firstSafeToolName(manifest);
  if (mcpToolName.length === 0) {
    return connectCardA2ui(surfaceId, toolId, manifest, 'unsafe_action_blocked', '该 MCP 只暴露交易或高风险动作，当前版本不会自动调用。', prompt);
  }

  let credentialRef = '';
  let credentialValue = '';
  const requiredCredential = firstRequiredCredential(manifest);
  if (requiredCredential !== null) {
    credentialRef = credentialRefFor(manifest.id, requiredCredential.name);
    credentialValue = await dynamicCredentialStore.get(credentialRef);
    if (credentialValue.length === 0) {
      return connectCardA2ui(surfaceId, toolId, manifest, 'needs_auth', '该工具需要凭据后才能测试连接。', prompt);
    }
  }

  const candidate = dynamicToolRegistry.enableAlias(toolId, manifest, mcpToolName, credentialRef);
  if (candidate.status === 'unsupported_transport') {
    return unsupportedTransportA2ui(surfaceId, toolId, manifest, prompt);
  }
  if (candidate.status === 'unsafe_action_blocked') {
    return connectCardA2ui(surfaceId, toolId, manifest, 'unsafe_action_blocked', '该 MCP 只暴露交易或高风险动作，当前版本不会自动调用。', prompt);
  }
  return preflightAndCallDynamicTool(candidate, manifest, credentialValue, prompt, surfaceId);
}

async function buildDiscoveredDynamicToolJsonl(prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  const result = await callStructuredDynamicTool(prompt, args);
  const data = result.data as DynamicStructuredData;
  if (Array.isArray(data.results)) {
    return genericToolResultsA2ui(surfaceId, 'dynamic.search', data.results);
  }
  return genericToolResultsA2ui(surfaceId, 'dynamic.search', [dynamicErrorResult(
    'dynamic.search',
    'dynamic.search',
    '动态读取失败',
    result.error?.message === undefined ? 'Dynamic read failed.' : result.error.message
  )]);
}

async function buildDynamicToolJsonl(toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  if (toolId === 'dynamic.search') {
    return buildDiscoveredDynamicToolJsonl(prompt, surfaceId, args);
  }

  const registration = dynamicToolRegistry.registrationForToolId(toolId);
  if (registration !== null) {
    return buildRegisteredDynamicToolJsonl(registration, prompt, surfaceId);
  }

  const manifest = sampleManifestForToolId(toolId);
  if (manifest === null) {
    return connectCardA2ui(surfaceId, toolId, missingDynamicManifest(toolId), 'no_tool_found', '没有找到可在鸿蒙设备直接运行的远程 MCP/API。', prompt);
  }

  return buildDynamicToolJsonlWithManifest(toolId, prompt, surfaceId, manifest);
}

function gmailAuthUnavailableMessage(toolId: string, prompt: string): string {
  return 'Gmail 工具 ' + toolId + ' 已在统一工具框架注册，但当前设备没有可用的 Google Workspace MCP OAuth 授权；Gmail Web 仅作为人工处理兜底。AIPhone 不会模拟 Gmail 邮件、草稿或发送结果。请求：' + prompt.substring(0, 160);
}

export function gmailOAuthConfigFromProvider(): GmailOAuthConfig {
  return {
    clientId: localProviderConfig.gmailOauthClientId,
    clientSecret: localProviderConfig.gmailOauthClientSecret,
    redirectUri: localProviderConfig.gmailOauthRedirectUri.length > 0 ? localProviderConfig.gmailOauthRedirectUri : GMAIL_DEFAULT_REDIRECT_URI,
    resource: GMAIL_MCP_RESOURCE,
    scopes: GOOGLE_CLOUD_OAUTH_SCOPES
  };
}

export async function prepareGoogleOAuthAuthorizationUrl(setupUrl: string = GMAIL_MCP_AUTH_SETUP_URL): Promise<string> {
  if (localProviderConfig.gmailAuthUrl.length > 0) {
    aiLogInfo('[AIPhone][GmailOAuthAuthorizeUrl] source=configured-url');
    return localProviderConfig.gmailAuthUrl;
  }
  const config = gmailOAuthConfigFromProvider();
  if (config.clientId.length === 0 || config.redirectUri.length === 0) {
    aiLogInfo('[AIPhone][GmailOAuthAuthorizeUrl] source=setup-docs clientConfigured=' +
      (config.clientId.length > 0 ? 'true' : 'false') +
      ' redirectConfigured=' + (config.redirectUri.length > 0 ? 'true' : 'false'));
    return setupUrl;
  }
  const pending = createGmailOAuthPending();
  await saveGmailOAuthPending(gmailCredentialStore, pending);
  aiLogInfo('[AIPhone][GmailOAuthPendingSaved] stateChars=' + pending.state.length.toString() +
    ' verifierChars=' + pending.codeVerifier.length.toString() +
    ' redirectChars=' + config.redirectUri.length.toString() +
    ' clientChars=' + config.clientId.length.toString());
  return buildGmailOAuthAuthorizationUrl({
    clientId: config.clientId,
    redirectUri: config.redirectUri,
    state: pending.state,
    codeChallenge: gmailPkceChallengeS256(pending.codeVerifier),
    resource: config.resource,
    scopes: config.scopes
  });
}

export async function prepareGmailOAuthAuthorizationUrl(): Promise<string> {
  return prepareGoogleOAuthAuthorizationUrl(GMAIL_MCP_AUTH_SETUP_URL);
}

async function gmailAccessTokenForMcp(): Promise<string> {
  aiLogInfo('[AIPhone][GmailAccessLoad] start');
  const token = await loadGmailOAuthTokenSet(gmailCredentialStore);
  if (token !== null) {
    aiLogInfo('[AIPhone][GmailAccessLoad] tokenSet=true accessChars=' + token.accessToken.length.toString() +
      ' refreshChars=' + token.refreshToken.length.toString() +
      ' fresh=' + (isGmailAccessTokenFresh(token) ? 'true' : 'false'));
    if (isGmailAccessTokenFresh(token)) {
      return token.accessToken;
    }
    if (token.refreshToken.length > 0) {
      const config = gmailOAuthConfigFromProvider();
      if (config.clientId.length === 0) {
        throw new Error('Gmail OAuth access token expired and OAuth client config is missing.');
      }
      const refreshed = await refreshGmailOAuthAccessToken(config, token.refreshToken);
      const saved = await saveGmailOAuthTokenSet(gmailCredentialStore, refreshed);
      aiLogInfo('[AIPhone][GmailAccessRefreshOk] accessChars=' + saved.accessToken.length.toString() +
        ' refreshChars=' + saved.refreshToken.length.toString());
      return saved.accessToken;
    }
    aiLogInfo('[AIPhone][GmailAccessLoad] expiredNoRefresh=true returningAccessChars=' + token.accessToken.length.toString());
    return token.accessToken;
  }
  const fallback = await gmailCredentialStore.get(GMAIL_ACCESS_TOKEN_REF);
  aiLogInfo('[AIPhone][GmailAccessLoad] tokenSet=false fallbackAccessChars=' + fallback.length.toString());
  return fallback;
}

function gmailMcpRegistration(toolId: string, mcpToolName: string): DynamicToolRegistration {
  const headers: Record<string, string> = {};
  if (localProviderConfig.gmailMcpUserProject.length > 0) {
    headers['x-goog-user-project'] = localProviderConfig.gmailMcpUserProject;
  }
  return {
    toolId: toolId,
    manifestId: 'google.gmail',
    displayName: 'Gmail',
    status: 'enabled',
    transport: {
      type: 'streamable_http',
      url: GMAIL_MCP_SERVER_URL,
      command: '',
      args: [],
      headers: headers,
      env: {}
    },
    mcpToolName: mcpToolName,
    credentialRef: GMAIL_ACCESS_TOKEN_REF,
    sourceUrl: GMAIL_MCP_SERVER_URL,
    lastError: ''
  };
}

async function gmailUnavailableA2ui(surfaceId: string, toolId: string, prompt: string, reason: string): Promise<string> {
  aiLogError('[AIPhone][GmailUnavailable] toolId=' + toolId + ' reason=' + reason.substring(0, 220));
  return gmailAuthRequiredA2ui(surfaceId, toolId, gmailAuthUnavailableMessage(toolId, prompt), await prepareGmailOAuthAuthorizationUrl());
}

function gmailErrorResult(toolName: string, message: string): DynamicGenericToolResult {
  return dynamicErrorResult('Gmail', toolName, 'Gmail MCP 调用失败', message);
}

function dynamicRowValue(result: DynamicGenericToolResult, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value;
    }
  }
  return '';
}

function mailArgs(args: Object | null): Record<string, Object | string | number | boolean | null | undefined> {
  if (args === null) {
    return JSON.parse('{}') as Record<string, Object | string | number | boolean | null | undefined>;
  }
  return args as Record<string, Object | string | number | boolean | null | undefined>;
}

function stringListArg(value: Object | string | number | boolean | null | undefined): string[] {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed.length > 0 ? [trimmed] : [];
  }
  if (!Array.isArray(value)) {
    return [];
  }
  const result: string[] = [];
  const values = value as string[];
  for (let index = 0; index < values.length; index++) {
    const text = textOf(values[index]).trim();
    if (text.length > 0) {
      result.push(text);
    }
  }
  return result;
}

function hasMailTimeOperator(query: string): boolean {
  return query.indexOf('newer_than:') >= 0 || query.indexOf('older_than:') >= 0 ||
    query.indexOf('after:') >= 0 || query.indexOf('before:') >= 0;
}

function trimMailKeywordTail(value: string): string {
  let text = value.trim();
  const leading = ['"', "'", '“', '”', '‘', '’', ':', '：', ',', '，'];
  while (text.length > 0 && leading.indexOf(text.charAt(0)) >= 0) {
    text = text.substring(1).trim();
  }
  const stops = [' 的邮件', '的邮件', ' 邮件', '邮件', ' 相关邮件', '相关邮件', ' 相关', '相关'];
  let end = text.length;
  for (let index = 0; index < stops.length; index++) {
    const hit = text.indexOf(stops[index]);
    if (hit > 0 && hit < end) {
      end = hit;
    }
  }
  return text.substring(0, end).trim();
}

function isMailAsciiKeywordChar(char: string): boolean {
  if (char.length === 0) {
    return false;
  }
  const code = char.charCodeAt(0);
  return (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122) ||
    char === '_' || char === '-' || char === '.';
}

function fallbackMailSearchQuery(prompt: string): string {
  const text = prompt.trim();
  const markers = ['关键词', '关键字', 'keyword', '包含', '含有'];
  for (let index = 0; index < markers.length; index++) {
    const marker = markers[index];
    const hit = text.toLowerCase().indexOf(marker.toLowerCase());
    if (hit >= 0) {
      const candidate = trimMailKeywordTail(text.substring(hit + marker.length));
      if (candidate.length > 0) {
        return candidate;
      }
    }
  }

  let current = '';
  let last = '';
  for (let index = 0; index < text.length; index++) {
    const char = text.charAt(index);
    if (isMailAsciiKeywordChar(char)) {
      current += char;
    } else if (current.length > 0) {
      const lower = current.toLowerCase();
      if (lower !== 'gmail' && lower !== 'qq' && lower !== 'mail' && lower !== 'email') {
        last = current;
      }
      current = '';
    }
  }
  if (current.length > 0) {
    const lower = current.toLowerCase();
    if (lower !== 'gmail' && lower !== 'qq' && lower !== 'mail' && lower !== 'email') {
      last = current;
    }
  }
  return last.length > 0 ? last : text;
}

function stripGenericMailQueryTerms(query: string): string {
  const stops = [
    '帮我', '请', '一下', '查看', '看看', '看', '搜索', '查询', '查找', '查',
    'Gmail', '谷歌邮箱', '谷歌邮件', 'QQ邮箱', 'QQ 邮箱', 'QQ邮件', 'QQ 邮件',
    '邮箱', '邮件', '收件箱', '里面', '里', '中', '关于', '有关', '相关',
    '最新', '最近', '重要', '和我', '我的', '我', '的'
  ];
  let text = query.trim();
  stops.forEach((stop: string) => {
    text = text.split(stop).join(' ');
  });
  return text.split(/\s+/).filter((term: string) => {
    const trimmed = term.trim();
    const lower = trimmed.toLowerCase();
    return trimmed.length > 0 && lower !== 'latest' && lower !== 'recent' && lower !== 'important';
  }).join(' ').trim();
}

function defaultMailSearchWindow(query: string): string {
  const trimmed = query.trim();
  if (trimmed.length === 0 || hasMailTimeOperator(trimmed)) {
    return trimmed;
  }
  return 'newer_than:30d ' + trimmed;
}

function isGmailSearchSummaryRow(row: DynamicGenericToolResult): boolean {
  return row.title.trim() === 'Gmail 搜索条件' ||
    (row.toolName === 'users.threads.list' && row.rawPreview.indexOf(' returned=') >= 0);
}

export function mailSearchArgs(prompt: string, args: Object | null): MailSearchArgs {
  const record = mailArgs(args);
  const providers: string[] = [];
  stringListArg(record.providers).forEach((provider: string) => providers.push(provider.toLowerCase()));
  const hasExplicitQuery = record.query !== undefined;
  const explicitQuery = textOf(record.query).trim();
  const query = stripGenericMailQueryTerms(hasExplicitQuery ? explicitQuery : fallbackMailSearchQuery(prompt));
  const normalizedQuery = defaultMailSearchWindow(query);
  return {
    query: normalizedQuery.length > 0 ? normalizedQuery : 'newer_than:30d',
    pageSize: typeof record.pageSize === 'number' && record.pageSize > 0 ? Math.min(record.pageSize, 10) : 10,
    providers: providers.length > 0 ? providers : ['gmail', 'qq', 'outlook'],
    intentSummary: textOf(record.intentSummary)
  };
}

function mailDraftArgs(args: Object | null): MailDraftArgs {
  const record = mailArgs(args);
  return {
    provider: textOf(record.provider),
    accountLabel: textOf(record.accountLabel),
    threadId: textOf(record.threadId),
    messageId: textOf(record.messageId),
    internetMessageId: textOf(record.internetMessageId),
    to: stringListArg(record.to),
    subject: textOf(record.subject),
    body: textOf(record.body),
    replyMode: textOf(record.replyMode),
    contextSummary: textOf(record.contextSummary)
  };
}

interface GmailDraftComposioArgs {
  to: string[];
  recipientEmail: string;
  subject: string;
  body: string;
  threadId: string;
  replyMode: string;
}

interface GmailReplyComposioArgs {
  recipientEmail: string;
  body: string;
  threadId: string;
}

function firstMailRecipient(value: string[]): string {
  if (value.length === 0) {
    return '';
  }
  const trimmed = value[0].trim();
  const left = trimmed.lastIndexOf('<');
  const right = trimmed.lastIndexOf('>');
  return left >= 0 && right > left ? trimmed.substring(left + 1, right).trim() : trimmed;
}

function mailReplyOperationResult(
  command: MailReplyCommand,
  operation: string,
  message: string
): MailReplyOperationResult {
  const result: MailReplyOperationResult = {
    requestKey: command.requestKey,
    operation: operation,
    provider: command.provider,
    status: 'success',
    message: message
  };
  return result;
}

export async function saveConfiguredMailDraft(command: MailReplyCommand): Promise<MailReplyOperationResult> {
  if (command.body.trim().length === 0 || command.to.length === 0) {
    throw new Error('Mail draft requires a recipient and body.');
  }
  const provider = command.provider.trim().toLowerCase();
  if (provider === 'qq') {
    const result = await new QqMailImapClient(qqMailConfig()).createDraft(command);
    if (result.status !== 'success') {
      throw new Error(result.summary);
    }
    return mailReplyOperationResult(command, 'draft', '已保存到 QQ 邮箱草稿箱。');
  }
  if (provider === 'gmail') {
    const args: GmailDraftComposioArgs = {
      to: command.to,
      recipientEmail: firstMailRecipient(command.to),
      subject: command.subject,
      body: command.body,
      threadId: command.threadId,
      replyMode: command.replyMode
    };
    const results = await configuredGmailResults(
      'gmail.draft.create',
      '保存 Gmail 回复草稿',
      args as Object
    );
    const result = results[0];
    if (result.status !== 'success') {
      throw new Error(result.summary);
    }
    return mailReplyOperationResult(command, 'draft', '已保存到 Gmail 草稿箱。');
  }
  throw new Error('Mail draft provider is not supported: ' + provider);
}

export async function sendConfiguredMailReply(command: MailReplyCommand): Promise<MailReplyOperationResult> {
  if (command.body.trim().length === 0 || command.to.length === 0) {
    throw new Error('Mail reply requires a recipient and body.');
  }
  const provider = command.provider.trim().toLowerCase();
  if (provider === 'qq') {
    const result = await new QqMailImapClient(qqMailConfig()).sendReply(command);
    if (result.status !== 'success') {
      throw new Error(result.summary);
    }
    return mailReplyOperationResult(command, 'send', 'QQ 邮箱回复已发送。');
  }
  if (provider === 'gmail') {
    const args: GmailReplyComposioArgs = {
      recipientEmail: firstMailRecipient(command.to),
      body: command.body,
      threadId: command.threadId
    };
    const result = await composioFixedAppResult(
      'gmail.reply.send',
      'Gmail',
      '回复 Gmail 线程',
      '邮件回复',
      args as Object
    );
    if (result.status !== 'success') {
      throw new Error(result.summary);
    }
    return mailReplyOperationResult(command, 'send', 'Gmail 回复已发送。');
  }
  throw new Error('Mail reply provider is not supported: ' + provider);
}

function qqMailConfig(): QqMailConfig {
  return {
    address: localProviderConfig.qqMailAddress,
    authCode: localProviderConfig.qqMailAuthCode,
    imapHost: localProviderConfig.qqMailImapHost,
    imapPort: Number.parseInt(localProviderConfig.qqMailImapPort, 10) || 993,
    draftsMailbox: localProviderConfig.qqMailDraftsMailbox
  };
}

export type MailDetailReader = (request: MailDetailRequest) => Promise<MailDetail>;

let mailDetailReaderForTests: MailDetailReader | null = null;

export function configureMailDetailReaderForTests(reader: MailDetailReader | null): void {
  mailDetailReaderForTests = reader;
}

interface ConfiguredMailDetailResult {
  detail: MailDetail;
  sources: DataSource[];
}

function mailDetailSource(
  provider: string,
  backend: 'oauth_api' | 'imap',
  operation: string
): DataSource {
  return {
    provider,
    backend,
    operation,
    fetchedAt: new Date().toISOString()
  };
}

async function readConfiguredGmailDetailWithSource(
  args: MailDetailRequest
): Promise<ConfiguredMailDetailResult> {
  if (gmailMcpClient !== genericMcpClient) {
    const results = await gmailOAuthFallbackResults('gmail.thread.read', '', args as Object);
    if (results.length === 0 || results[0].status !== 'success') {
      const message = results.length === 0 ? 'Gmail OAuth detail is unavailable.' : results[0].summary;
      throw new Error(message);
    }
    return {
      detail: gmailMailDetailFromPayload(JSON.parse(results[0].rawPreview) as Object, args),
      sources: [mailDetailSource('Gmail OAuth', 'oauth_api', 'gmail.thread.read')]
    };
  }
  try {
    const execution: ComposioRawExecution = await callComposioFixedRaw(
      'Gmail read full thread ' + args.threadId,
      'gmail.thread.read',
      args as Object
    );
    aiLogInfo('[AIPhone][GmailDetailComposio] tool=' + execution.toolSlug +
      ' responseChars=' + execution.observation.length.toString());
    const payload = JSON.parse(execution.observation) as Object;
    const payloadKeys = typeof payload === 'object' && !Array.isArray(payload) ?
      Object.keys(payload).slice(0, 12).join(',') : '';
    aiLogInfo('[AIPhone][GmailDetailComposioShape] topKeys=' + payloadKeys);
    return {
      detail: gmailMailDetailFromPayload(payload, args),
      sources: [mailDetailSource('Composio Gmail', 'oauth_api', 'gmail.thread.read')]
    };
  } catch (composioError) {
    const message = describeThrown(composioError);
    aiLogError('[AIPhone][GmailDetailComposioFailed] ' + message.substring(0, 240));
    const accessToken = await gmailAccessTokenForMcp();
    if (accessToken.length === 0) {
      throw new Error(message);
    }
    aiLogInfo('[AIPhone][GmailDetailLocalOAuthFallback] accessChars=' + accessToken.length.toString());
    return {
      detail: await readGmailMailDetail(accessToken, args),
      sources: [mailDetailSource('Gmail OAuth', 'oauth_api', 'gmail.thread.read')]
    };
  }
}

async function readConfiguredMailDetailWithSource(
  args: MailDetailRequest
): Promise<ConfiguredMailDetailResult> {
  if (mailDetailReaderForTests !== null) {
    return {
      detail: await mailDetailReaderForTests(args),
      sources: []
    };
  }
  const provider = args.provider.trim().toLowerCase();
  if (provider === 'qq') {
    return {
      detail: await new QqMailImapClient(qqMailConfig()).readDetail(args),
      sources: [mailDetailSource('QQ Mail', 'imap', 'thread.read')]
    };
  }
  if (provider === 'gmail') {
    return readConfiguredGmailDetailWithSource(args);
  }
  throw new Error('Mail detail provider is not supported: ' + provider);
}

export async function readConfiguredMailDetail(args: MailDetailRequest): Promise<MailDetail> {
  const provider = args.provider.trim().toLowerCase();
  aiLogInfo('[AIPhone][MailDetailReadStart] provider=' + provider +
    ' requestKeyChars=' + args.requestKey.length.toString() +
    ' threadIdChars=' + args.threadId.length.toString() +
    ' messageIdChars=' + args.messageId.length.toString());
  const detail = (await readConfiguredMailDetailWithSource(args)).detail;
  aiLogInfo('[AIPhone][MailDetailReadDone] provider=' + provider +
    ' bodyChars=' + detail.bodyText.length.toString() +
    ' to=' + detail.to.length.toString() +
    ' cc=' + detail.cc.length.toString());
  return detail;
}

function mailProviderError(provider: string, message: string): MailProviderStatus {
  return {
    provider: provider,
    status: 'error',
    title: provider === 'qq' ? 'QQ 邮箱调用失败' : (provider === 'outlook' ? 'Outlook 调用失败' : 'Gmail 调用失败'),
    message: message
  };
}

type MailEntityJsonValue = Object | string | number | boolean | null | undefined;

function mailEntityRecord(record: Record<string, MailEntityJsonValue>): boolean {
  const threadId = textOf(record['threadId']).trim();
  const messageId = textOf(record['messageId']).trim();
  const internetMessageId = textOf(record['internetMessageId']).trim();
  if (threadId.length > 0 || messageId.length > 0 || internetMessageId.length > 0) {
    return true;
  }
  const id = textOf(record['id']).trim();
  const subject = textOf(record['subject']).trim();
  const sender = textOf(record['from']).trim() + textOf(record['sender']).trim() + textOf(record['to']).trim();
  return id.length > 0 && (subject.length > 0 || sender.length > 0);
}

function mailRawHasEntity(value: MailEntityJsonValue, depth: number = 0): boolean {
  if (depth > 6 || value === undefined || value === null || typeof value !== 'object') {
    return false;
  }
  if (Array.isArray(value)) {
    for (let index = 0; index < value.length; index++) {
      const item = value[index] as MailEntityJsonValue;
      if (item !== undefined && item !== null && typeof item === 'object' &&
        (mailEntityRecord(item as Record<string, MailEntityJsonValue>) || mailRawHasEntity(item, depth + 1))) {
        return true;
      }
    }
    return false;
  }
  const record = value as Record<string, MailEntityJsonValue>;
  if (mailEntityRecord(record)) {
    return true;
  }
  const nested = ['threads', 'messages', 'emails', 'mails', 'items', 'results', 'data', 'result', 'response'];
  for (let index = 0; index < nested.length; index++) {
    if (mailRawHasEntity(record[nested[index]], depth + 1)) {
      return true;
    }
  }
  return false;
}

function mailExtraHasEntity(result: DynamicGenericToolResult): boolean {
  if (result.status !== 'success') {
    return false;
  }
  for (let index = 0; index < result.rows.length; index++) {
    const label = result.rows[index].label.trim().toLowerCase();
    const value = result.rows[index].value.trim();
    if (value.length > 0 &&
      (label === 'message id' || label === 'messageid' || label === 'thread id' || label === 'threadid' ||
        label === 'internet message id' || label === 'internetmessageid' || label.indexOf('结果 ') === 0)) {
      return true;
    }
  }
  if (result.rawPreview.trim().length === 0) {
    return false;
  }
  try {
    return mailRawHasEntity(JSON.parse(result.rawPreview) as MailEntityJsonValue);
  } catch (_error) {
    return false;
  }
}

function mailSearchDataResult(
  data: MailSearchStructuredData,
  sources: DataSource[]
): DataResult {
  data.entityRefs = [];
  const actualSources = sources.slice();
  const warnings: string[] = [];
  let failureCount = 0;
  let authFailureCount = 0;
  let retryable = false;
  let successfulResponse = data.threads.length > 0;
  let entityCount = data.threads.length;
  let failureMessage = '';
  data.statuses.forEach((status: MailProviderStatus) => {
    if (status.status === 'success' || status.status === 'empty') {
      successfulResponse = true;
      return;
    }
    const evidence: DynamicGenericToolResult = {
      sourceTag: status.provider,
      toolName: 'mail.search',
      title: status.title,
      status: status.status,
      summary: status.message,
      rows: [],
      rawPreview: ''
    };
    failureCount += 1;
    if (remainingReadAuthFailure(evidence)) {
      authFailureCount += 1;
    }
    if (remainingReadRetryable(evidence)) {
      retryable = true;
    }
    const warning = status.title + '：' + status.message;
    if (warnings.indexOf(warning) < 0) {
      warnings.push(warning);
    }
    if (failureMessage.length === 0) {
      failureMessage = status.message.length > 0 ? status.message : status.title;
    }
  });
  data.extras.forEach((result: DynamicGenericToolResult) => {
    if (mailExtraHasEntity(result)) {
      entityCount += 1;
    }
    if (result.status === 'success' || result.status === 'empty') {
      successfulResponse = true;
    }
    if (genericResultIsFailure(result)) {
      failureCount += 1;
      if (remainingReadAuthFailure(result)) {
        authFailureCount += 1;
      }
      if (remainingReadRetryable(result)) {
        retryable = true;
      }
      const warning = result.title + '：' + result.summary;
      if (warnings.indexOf(warning) < 0) {
        warnings.push(warning);
      }
      if (result.providerPhase === 'execution' || failureMessage.length === 0) {
        failureMessage = result.summary.length > 0 ? result.summary : result.title;
      }
    }
    if (result.providerPhase === 'execution' &&
      !sourceAlreadyIncluded(actualSources, result.sourceTag, result.toolName)) {
      actualSources.push(remainingReadSource(result));
    }
  });
  if (entityCount > 0) {
    data.entityRefs = mailSearchEntityRefs(data.threads);
    return failureCount > 0 ?
      partialDataResult('mail.search', 'mailThreads', data, actualSources, warnings) :
      successfulDataResult('mail.search', 'mailThreads', data, actualSources);
  }
  if (successfulResponse) {
    const empty = successfulDataResult('mail.search', 'mailThreads', data, actualSources);
    empty.status = 'empty';
    empty.warnings = warnings;
    return empty;
  }
  if (failureCount > 0) {
    return structuredErrorWithData(
      'mail.search', 'mailThreads', data, authFailureCount === failureCount ? 'AUTH_REQUIRED' : 'PROVIDER_ERROR',
      failureMessage.length > 0 ? failureMessage : warnings.join('；'), retryable, actualSources, warnings
    );
  }
  const empty = successfulDataResult('mail.search', 'mailThreads', data, actualSources);
  empty.status = 'empty';
  return empty;
}

function mailSearchEntityRefs(threads: MailThreadSummary[]): string[] {
  const refs: string[] = [];
  for (let index = 0; index < threads.length && refs.length < 16; index++) {
    const candidates: string[] = [
      threads[index].requestKey,
      threads[index].threadId,
      threads[index].messageId
    ];
    for (let candidateIndex = 0; candidateIndex < candidates.length && refs.length < 16; candidateIndex++) {
      const candidate: string = candidates[candidateIndex];
      if (candidate.trim().length > 0 && refs.indexOf(candidate) < 0) {
        refs.push(candidate);
      }
    }
  }
  return refs;
}

export function mailSearchDataResultForTest(data: MailSearchStructuredData, sources: DataSource[]): DataResult {
  return mailSearchDataResult(data, sources);
}

async function callStructuredMailSearch(prompt: string, args: Object | null): Promise<DataResult> {
  const parsed = mailSearchArgs(prompt, args);
  const data: MailSearchStructuredData = { threads: [], statuses: [], extras: [] };
  const sources: DataSource[] = [];
  if (parsed.providers.indexOf('gmail') >= 0) {
    try {
      const gmailResult = await callStructuredGmailReadTool('gmail.mail.search', parsed.query, parsed as Object);
      const gmailData = gmailResult.data as GmailSearchStructuredData;
      gmailData.threads.forEach((thread: GmailThreadSummary) => data.threads.push(mailThreadSummary(thread)));
      gmailData.statuses.forEach((status: MailProviderStatus) => data.statuses.push(status));
      gmailData.extras.forEach((extra: DynamicGenericToolResult) => data.extras.push(extra));
      gmailResult.sources.forEach((source: DataSource) => sources.push(source));
    } catch (error) {
      data.statuses.push(mailProviderError('gmail', describeThrown(error)));
    }
  }
  if (parsed.providers.indexOf('qq') >= 0) {
    const configured = localProviderConfig.qqMailAddress.length > 0 && localProviderConfig.qqMailAuthCode.length > 0;
    try {
      const rows = await new QqMailImapClient(qqMailConfig()).search(parsed);
      rows.forEach((thread: MailThreadResult) => data.threads.push(mailThreadSummary(thread)));
      if (configured) {
        sources.push({
          provider: 'QQ Mail', backend: 'imap', operation: 'search', fetchedAt: new Date().toISOString()
        });
      }
      if (rows.length === 0) {
        data.statuses.push({
          provider: 'qq', status: 'success', title: 'QQ Mail 没有找到匹配邮件',
          message: 'QQ Mail 查询成功，但当前账号没有匹配邮件。'
        });
      }
    } catch (error) {
      data.statuses.push(mailProviderError('qq', describeThrown(error)));
      if (configured) {
        sources.push({
          provider: 'QQ Mail', backend: 'imap', operation: 'search', fetchedAt: new Date().toISOString()
        });
      }
    }
  }
  if (parsed.providers.indexOf('outlook') >= 0) {
    const outlook = await composioAppResult('Outlook', parsed.query, '的邮件');
    data.extras.push(outlook);
  }
  return mailSearchDataResult(data, sources);
}

async function callStructuredMailThreadRead(toolId: string, args: Object | null): Promise<DataResult> {
  const request = mailDetailRequestFromArgs(args);
  const identityError = mailDetailIdentityError(toolId, 'mailThread', request);
  if (identityError !== null) {
    return identityError;
  }
  const configured = request.provider === 'qq' ?
    localProviderConfig.qqMailAddress.length > 0 && localProviderConfig.qqMailAuthCode.length > 0 :
    isComposioConfigured() || localProviderConfig.gmailOauthClientId.length > 0;
  let sources: DataSource[] = [];
  try {
    const configuredDetail = await readConfiguredMailDetailWithSource(request);
    const detail = configuredDetail.detail;
    sources = configuredDetail.sources;
    if (!mailDetailMatchesRequest(detail, request)) {
      return structuredErrorWithData(
        toolId, 'mailThread', new Object(), 'PROVIDER_IDENTITY_MISMATCH',
        'Mail provider returned a stale identity or no full message body.', false, sources
      );
    }
    return successfulDataResult(toolId, 'mailThread', mailThreadStructuredData(detail), sources);
  } catch (error) {
    return structuredErrorWithData(
      toolId, 'mailThread', new Object(), configured ? 'PROVIDER_ERROR' : 'AUTH_REQUIRED',
      describeThrown(error), configured, sources
    );
  }
}

function composioResultTitle(appName: string): string {
  return 'Composio ' + appName + ' 结果';
}

function composioProviderPrompt(appName: string, query: string, kind: string): string {
  return '帮我用 Composio ' + appName + ' 查 ' + query + kind;
}

async function composioAppResult(appName: string, query: string, kind: string): Promise<DynamicGenericToolResult> {
  const prompt = composioProviderPrompt(appName, query, kind);
  try {
    const result = await callComposioDynamic(prompt, null);
    if (result !== null) {
      result.sourceTag = 'Composio ' + appName;
      result.rows.push({ label: 'provider', value: appName });
      return result;
    }
    return {
      sourceTag: 'Composio',
      toolName: 'dynamic.search',
      title: composioResultTitle(appName),
      status: 'error',
      summary: 'Composio 没有处理该请求。',
      rows: [{ label: '查询', value: query }],
      rawPreview: prompt
    };
  } catch (error) {
    return {
      sourceTag: 'Composio',
      toolName: 'dynamic.search',
      title: composioResultTitle(appName),
      status: 'error',
      summary: describeThrown(error),
      rows: [{ label: '查询', value: query }],
      rawPreview: prompt
    };
  }
}

function composioPayloadRows(args: Object | null): A2uiLabelValueData[] {
  if (args === null || Array.isArray(args) || typeof args !== 'object') {
    return [];
  }
  const rows: A2uiLabelValueData[] = [];
  const record = args as Record<string, Object | string | number | boolean | null | undefined>;
  Object.keys(record).forEach((key: string) => {
    const value = record[key];
    const text = textOf(value).trim();
    if (text.length > 0) {
      rows.push({ label: key, value: text.substring(0, 360) });
    }
  });
  return rows;
}

function composioFixedResult(toolId: string, appName: string, result: DynamicGenericToolResult, args: Object | null = null): DynamicGenericToolResult {
  result.toolName = toolId;
  result.sourceTag = 'Composio ' + appName;
  result.registration = undefined;
  if (result.rows.find((row: A2uiLabelValueData) => row.label === 'Tool ID') === undefined) {
    result.rows.push({ label: 'Tool ID', value: toolId });
  }
  composioPayloadRows(args).forEach((row: A2uiLabelValueData) => {
    if (result.rows.find((existing: A2uiLabelValueData) => existing.label === row.label) === undefined) {
      result.rows.push(row);
    }
  });
  return result;
}

async function composioFixedAppResult(
  toolId: string,
  appName: string,
  query: string,
  kind: string,
  args: Object | null = null
): Promise<DynamicGenericToolResult> {
  const prompt = composioProviderPrompt(appName, query, kind);
  try {
    const result = await callComposioFixedDynamic(prompt, toolId, args);
    if (result !== null) {
      result.rows.push({ label: 'provider', value: appName });
      return composioFixedResult(toolId, appName, result, args);
    }
    return composioFixedResult(toolId, appName, {
      sourceTag: 'Composio',
      toolName: 'dynamic.search',
      title: composioResultTitle(appName),
      status: 'error',
      summary: 'Composio 没有处理该请求。',
      rows: [{ label: '查询', value: query }],
      rawPreview: prompt
    }, args);
  } catch (error) {
    return composioFixedResult(toolId, appName, {
      sourceTag: 'Composio',
      toolName: 'dynamic.search',
      title: composioResultTitle(appName),
      status: 'error',
      summary: describeThrown(error),
      rows: [{ label: '查询', value: query }],
      rawPreview: prompt
    }, args);
  }
}

async function gmailOAuthFallbackResults(
  toolId: string,
  prompt: string,
  args: Object | null
): Promise<DynamicGenericToolResult[]> {
  const mcpToolName = gmailMcpToolNameForToolId(toolId);
  if (mcpToolName.length === 0) {
    return [];
  }
  try {
    const accessToken = await gmailAccessTokenForMcp();
    if (accessToken.length === 0) {
      return [];
    }
    aiLogInfo('[AIPhone][GmailLocalOAuthFallback] toolId=' + toolId +
      ' accessChars=' + accessToken.length.toString());
    if (gmailMcpClient === genericMcpClient) {
      return await callGmailApiTool(toolId, prompt, accessToken, args);
    }
    return [await gmailMcpClient.callTool(
      gmailMcpRegistration(toolId, mcpToolName),
      accessToken,
      gmailMcpArgsForPrompt(toolId, prompt, args)
    )];
  } catch (error) {
    const message = describeThrown(error);
    aiLogError('[AIPhone][GmailLocalOAuthFallbackFailed] toolId=' + toolId +
      ' reason=' + message.substring(0, 200));
    return [{
      sourceTag: 'Gmail OAuth',
      toolName: toolId,
      title: 'Gmail OAuth 调用失败',
      status: 'error',
      summary: message,
      rows: [{ label: 'Error', value: message.substring(0, 240) }],
      rawPreview: '',
      providerPhase: 'execution'
    }];
  }
}

function clonedGmailResult(result: DynamicGenericToolResult): DynamicGenericToolResult {
  return {
    sourceTag: result.sourceTag,
    toolName: result.toolName,
    title: result.title,
    status: result.status,
    summary: result.summary,
    rows: result.rows.map((row: A2uiLabelValueData): A2uiLabelValueData => ({ label: row.label, value: row.value })),
    rawPreview: result.rawPreview,
    actions: result.actions,
    registration: result.registration,
    providerPhase: result.providerPhase
  };
}

async function configuredGmailResults(
  toolId: string,
  prompt: string,
  args: Object | null
): Promise<DynamicGenericToolResult[]> {
  let pinnedProvider = '';
  if (toolId === 'gmail.draft.apply' && args !== null && !Array.isArray(args) && typeof args === 'object') {
    const values = args as ToolArgRecord;
    pinnedProvider = textOf(values.provider).trim().toLowerCase();
    if (pinnedProvider !== 'gmail_oauth' && pinnedProvider !== 'composio') {
      return [gmailErrorResult(toolId, 'Gmail draft provider is missing or invalid.')];
    }
  }
  if (pinnedProvider === 'gmail_oauth') {
    const pinnedFallback = await gmailOAuthFallbackResults(toolId, prompt, args);
    pinnedFallback.forEach((result: DynamicGenericToolResult) => {
      result.providerPhase = 'execution';
    });
    return pinnedFallback.length > 0 ?
      pinnedFallback : [gmailErrorResult(toolId, 'Gmail OAuth draft provider is unavailable.')];
  }
  const composioResult = gmailComposioResultForTests === null ?
    await composioFixedAppResult(
      toolId,
      'Gmail',
      prompt,
      toolId === 'gmail.draft.create' || toolId === 'gmail.draft.apply' ? '草稿' : '邮件',
      args
    ) : clonedGmailResult(gmailComposioResultForTests);
  if (pinnedProvider === 'composio') {
    return [composioResult];
  }
  if (composioResult.status === 'success' && composioResult.providerPhase === 'execution') {
    return [composioResult];
  }
  const fallbackResults = await gmailOAuthFallbackResults(toolId, prompt, args);
  fallbackResults.forEach((result: DynamicGenericToolResult) => {
    result.providerPhase = 'execution';
  });
  if (fallbackResults.length > 0) {
    const fallbackSucceeded = fallbackResults.some((result: DynamicGenericToolResult): boolean =>
      result.status === 'success' || result.status === 'empty');
    if (fallbackSucceeded) {
      return fallbackResults;
    }
    fallbackResults.push(composioResult);
    return fallbackResults;
  }
  return [composioResult];
}

export interface MailThreadStructuredData {
  requestKey: string;
  provider: string;
  threadId: string;
  messageId: string;
  internetMessageId: string;
  subject: string;
  from: string;
  replyTo: string;
  to: string[];
  cc: string[];
  body: string;
  bodyHtml: string;
}

function mailDetailRequestFromArgs(args: Object | null): MailDetailRequest {
  const request = args === null ? {} as MailDetailRequest : args as MailDetailRequest;
  return {
    requestKey: textOf(request.requestKey).trim(),
    provider: textOf(request.provider).trim().toLowerCase(),
    threadId: textOf(request.threadId).trim(),
    messageId: textOf(request.messageId).trim(),
    subject: textOf(request.subject).trim()
  };
}

function mailDetailIdentityError(toolId: string, outputSchema: string, request: MailDetailRequest): DataResult | null {
  const identity = request.provider === 'gmail' ? request.threadId : request.messageId;
  const providerIdentityValid = request.provider === 'gmail' ?
    request.threadId.length > 0 && request.messageId.length > 0 :
    request.provider === 'qq' && /^\d+$/.test(request.messageId);
  if ((request.provider !== 'gmail' && request.provider !== 'qq') || identity.length === 0 ||
    !providerIdentityValid ||
    request.requestKey !== request.provider + ':' + identity) {
    return errorDataResult(
      toolId,
      outputSchema,
      'INPUT_REQUIRED',
      'mail thread read requires a matching provider, requestKey, and provider thread/message identity.'
    );
  }
  return null;
}

function mailThreadStructuredData(detail: MailDetail): MailThreadStructuredData {
  return {
    requestKey: detail.requestKey,
    provider: detail.provider,
    threadId: detail.threadId,
    messageId: detail.messageId,
    internetMessageId: detail.internetMessageId === undefined ? '' : detail.internetMessageId,
    subject: detail.subject,
    from: detail.from,
    replyTo: detail.replyTo,
    to: detail.to.slice(),
    cc: detail.cc.slice(),
    body: detail.bodyText,
    bodyHtml: detail.bodyHtml
  };
}

function mailDetailMatchesRequest(detail: MailDetail, request: MailDetailRequest): boolean {
  return detail.provider === request.provider && detail.requestKey === request.requestKey &&
    (request.threadId.length === 0 || detail.threadId === request.threadId) &&
    (request.messageId.length === 0 || detail.messageId === request.messageId) &&
    (detail.bodyText.trim().length > 0 || detail.bodyHtml.trim().length > 0);
}

async function callStructuredGmailReadTool(
  toolId: string,
  prompt: string,
  args: Object | null,
  providerToolId: string = toolId
): Promise<DataResult> {
  if (toolId === 'gmail.thread.read') {
    return callStructuredMailThreadRead(toolId, args);
  }
  if (toolId === 'gmail.mail.search') {
    const results = await configuredGmailResults(providerToolId, prompt, args);
    const data: GmailSearchStructuredData = gmailSearchStructuredDataFromResults(results);
    const base = remainingReadStructuredDataResult(toolId, 'mailThreads', results);
    data.entityRefs = base.status === 'success' || base.status === 'partial' ?
      mailSearchEntityRefs(data.threads as MailThreadSummary[]) : [];
    base.data = data;
    return base;
  }
  const request = mailDetailRequestFromArgs(args);
  if (request.provider.length === 0) {
    request.provider = 'gmail';
  }
  const identityError = mailDetailIdentityError(toolId, 'mailThread', request);
  if (identityError !== null) {
    return identityError;
  }
  const results = await configuredGmailResults(providerToolId, prompt, request as Object);
  const base = remainingReadStructuredDataResult(toolId, 'mailThread', results);
  if (base.status !== 'success' || results.length === 0) {
    return base;
  }
  try {
    const detail = gmailMailDetailFromPayload(JSON.parse(results[0].rawPreview) as Object, request);
    if (!mailDetailMatchesRequest(detail, request)) {
      return structuredErrorWithData(
        toolId, 'mailThread', new Object(), 'PROVIDER_IDENTITY_MISMATCH',
        'Gmail returned a stale identity or no full message body.', false, base.sources
      );
    }
    base.data = mailThreadStructuredData(detail);
    return base;
  } catch (error) {
    return structuredErrorWithData(
      toolId, 'mailThread', new Object(), 'PROVIDER_INVALID_RESPONSE',
      describeThrown(error), false, base.sources
    );
  }
}

function youtubeQueryFromArgs(prompt: string, args: Object | null): string {
  return mediaVideoQueryFromArgs(prompt, args);
}

function youtubeSearchOptionsFromArgs(args: Object | null): YouTubeSearchOptions {
  if (args === null) {
    return defaultYouTubeSearchOptions();
  }
  const record = args as Record<string, Object | string | number | boolean | null | undefined>;
  const order = textOf(record.order).trim();
  const rawMaxResults = record.maxResults;
  return {
    order: order.length > 0 ? order : 'relevance',
    maxResults: typeof rawMaxResults === 'number' ? rawMaxResults : 10
  };
}

interface SocialHubDraftRequestArgs {
  itemId?: Object | string | number | boolean | null;
  platform?: Object | string | number | boolean | null;
  instruction?: Object | string | number | boolean | null;
}

interface SocialHubFeedRequestArgs {
  platforms?: Object[];
}

interface SocialCommunityRequestArgs {
  platform?: Object | string | number | boolean | null;
  query?: Object | string | number | boolean | null;
  resourceId?: Object | string | number | boolean | null;
  limit?: number;
}

interface SocialPublicationPreviewRequestArgs {
  platform?: Object | string | number | boolean | null;
  operation?: Object | string | number | boolean | null;
  text?: Object | string | number | boolean | null;
}

interface SocialXCommunityArgs {
  query: string;
  maxResults: number;
}

interface EmptySocialProviderArgs {
}

interface SocialLinkedInPostArgs {
  postId: string;
}

interface SocialInstagramMediaArgs {
  igUserId: string;
  limit: number;
}

interface SocialRedditProfileArgs {
  username: string;
}

interface SocialRedditCommunityArgs {
  searchQuery: string;
  limit: number;
}

interface SocialXListArgs {
  maxResults: number;
  expansions: string[];
  eventTypes: string[];
  userFields: string[];
  dmEventFields: string[];
}

interface SocialXProfileArgs {
  userFields: string[];
}

interface SocialSlackSearchArgs {
  query: string;
  sort: string;
  count: number;
}

interface SocialInstagramConversationArgs {
  limit: number;
}

interface SocialInstagramProfileArgs {
  igUserId: string;
}

interface SocialInstagramMessageArgs {
  conversationId: string;
  limit: number;
}

interface InstagramConversationPayload {
  id?: Object | string | number | boolean | null;
}

interface InstagramConversationPage {
  data?: Object[];
}

interface InstagramConversationEnvelope {
  data?: InstagramConversationPage | null;
}

interface SocialProfilePayload {
  id?: Object | string | number | boolean | null;
  data?: Object | null;
}

interface SocialProfileEnvelope {
  data?: Object | null;
}

function emptySocialHubDraftRequestArgs(): SocialHubDraftRequestArgs {
  return {
    itemId: '',
    platform: '',
    instruction: ''
  };
}

function socialHubPlatformFromText(value: string): SocialHubPlatform {
  const text = value.trim().toLowerCase();
  if (text === 'x' || text === 'twitter') {
    return 'x';
  }
  if (text === 'slack') {
    return 'slack';
  }
  if (text === 'wecom' || text === 'wework' || text === '企业微信') {
    return 'wecom';
  }
  if (text === 'discord' || text === 'linkedin' || text === 'whatsapp' ||
    text === 'instagram' || text === 'reddit') {
    return text as SocialHubPlatform;
  }
  return 'unknown';
}

function isSocialHubToolId(toolId: string): boolean {
  return toolId === 'social.feed.search' || toolId === 'social.reply.draft' ||
    toolId === 'social.community.search' || toolId === 'social.post.preview';
}

function socialHubDefaultPlatforms(): SocialHubPlatform[] {
  return ['x', 'slack', 'wecom', 'discord', 'linkedin', 'whatsapp', 'instagram'];
}

function socialHubRequestedPlatforms(args: Object | null): SocialHubPlatform[] {
  if (args === null) {
    return socialHubDefaultPlatforms();
  }
  const request = args as SocialHubFeedRequestArgs;
  if (!Array.isArray(request.platforms) || request.platforms.length === 0) {
    return socialHubDefaultPlatforms();
  }
  const platforms: SocialHubPlatform[] = [];
  request.platforms.forEach((value: Object) => {
    const text = textOf(value).trim().toLowerCase();
    if (text === 'all') {
      return;
    }
    const platform = socialHubPlatformFromText(text);
    if (platform !== 'unknown' && platforms.indexOf(platform) < 0) {
      platforms.push(platform);
    }
  });
  return platforms.length > 0 ? platforms : socialHubDefaultPlatforms();
}

function socialHubConnectionResult(
  platform: SocialHubPlatform,
  displayName: string,
  status: string,
  message: string
): SocialHubFeedResult {
  return {
    items: [],
    connections: [{
      platform: platform,
      status: status,
      displayName: displayName,
      accountId: '',
      message: message
    } as SocialHubConnectionData]
  };
}

function socialHubAfterDate(): string {
  return new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().substring(0, 10);
}

async function composioXSocialFeed(): Promise<SocialHubFeedResult> {
  try {
    const profileArgs: SocialXProfileArgs = { userFields: ['id', 'name', 'username'] };
    const args: SocialXListArgs = {
      maxResults: 25,
      expansions: ['sender_id'],
      eventTypes: ['MessageCreate'],
      userFields: ['id', 'name', 'username'],
      dmEventFields: ['id', 'event_type', 'text', 'sender_id', 'dm_conversation_id', 'created_at']
    };
    const executions = await Promise.all([
      callComposioFixedRaw('Authenticated Twitter X profile', 'social.x.profile', profileArgs),
      callComposioFixedRaw('Twitter X recent direct messages', 'social.x.dm.list', args)
    ]);
    return parseComposioSocialFeed('x', executions[1].observation, '', socialProfileId(executions[0].observation));
  } catch (error) {
    return socialHubConnectionResult('x', 'X', 'error', describeThrown(error));
  }
}

async function composioSlackSocialFeed(): Promise<SocialHubFeedResult> {
  try {
    const args: SocialSlackSearchArgs = {
      query: 'after:' + socialHubAfterDate(),
      sort: 'timestamp',
      count: 25
    };
    const execution = await callComposioFixedRaw(
      'Slack recent direct messages',
      'social.slack.message.search',
      args
    );
    return parseComposioSocialFeed('slack', execution.observation);
  } catch (error) {
    return socialHubConnectionResult('slack', 'Slack', 'error', describeThrown(error));
  }
}

function instagramConversationIds(raw: string): string[] {
  try {
    const payload = JSON.parse(raw) as InstagramConversationEnvelope;
    if (payload.data === undefined || payload.data === null || !Array.isArray(payload.data.data)) {
      return [];
    }
    const ids: string[] = [];
    payload.data.data.forEach((value: Object) => {
      const conversation = value as InstagramConversationPayload;
      const id = textOf(conversation.id).trim();
      if (id.length > 0 && ids.indexOf(id) < 0) {
        ids.push(id);
      }
    });
    return ids.slice(0, 5);
  } catch (_error) {
    return [];
  }
}

function socialProfileId(raw: string): string {
  try {
    const envelope = JSON.parse(raw) as SocialProfileEnvelope;
    if (envelope.data === undefined || envelope.data === null) {
      return '';
    }
    const profile = envelope.data as SocialProfilePayload;
    const direct = textOf(profile.id).trim();
    if (direct.length > 0) {
      return direct;
    }
    if (profile.data === undefined || profile.data === null) {
      return '';
    }
    return textOf((profile.data as SocialProfilePayload).id).trim();
  } catch (_error) {
    return '';
  }
}

interface SocialProfileIdentity {
  id: string;
  name: string;
}

function socialProfileIdentityRecord(value: Object | null | undefined): SocialProfileIdentity {
  if (value === undefined || value === null) {
    return { id: '', name: '' };
  }
  const record = value as Record<string, Object | string | number | boolean | null | undefined>;
  const nested = record.data;
  if (nested !== undefined && nested !== null && typeof nested === 'object' && !Array.isArray(nested)) {
    const identity = socialProfileIdentityRecord(nested as Object);
    if (identity.id.length > 0 || identity.name.length > 0) {
      return identity;
    }
  }
  const id = textOf(record.id).trim();
  const username = textOf(record.username).trim();
  const name = textOf(record.name).trim();
  return {
    id: id.length > 0 ? id : (username.length > 0 ? username : name),
    name: username.length > 0 ? username : name
  };
}

function socialProfileIdentityFromObservation(raw: string): SocialProfileIdentity {
  try {
    return socialProfileIdentityRecord(JSON.parse(raw) as Object);
  } catch (_error) {
    return { id: '', name: '' };
  }
}

async function socialProfileForPreview(platform: SocialHubPlatform): Promise<SocialProfileIdentity> {
  if (platform === 'x') {
    const args: SocialXProfileArgs = { userFields: ['id', 'name', 'username'] };
    return socialProfileIdentityFromObservation(
      (await callComposioFixedRaw('Authenticated Twitter X profile', 'social.x.profile', args)).observation
    );
  }
  if (platform === 'linkedin') {
    const args: EmptySocialProviderArgs = {};
    return socialProfileIdentityFromObservation(
      (await callComposioFixedRaw(
        'Authenticated LinkedIn profile', 'social.linkedin.profile', args
      )).observation
    );
  }
  if (platform === 'instagram') {
    const args: SocialInstagramProfileArgs = { igUserId: 'me' };
    return socialProfileIdentityFromObservation(
      (await callComposioFixedRaw(
        'Authenticated Instagram profile', 'social.instagram.profile', args
      )).observation
    );
  }
  if (platform === 'reddit') {
    const args: SocialRedditProfileArgs = { username: 'me' };
    return socialProfileIdentityFromObservation(
      (await callComposioFixedRaw(
        'Authenticated Reddit profile', 'social.reddit.profile', args
      )).observation
    );
  }
  return { id: '', name: '' };
}

async function composioSocialCommunity(args: Object | null): Promise<SocialHubFeedResult> {
  const request = args === null ? {} as SocialCommunityRequestArgs :
    args as SocialCommunityRequestArgs;
  const platform = socialHubPlatformFromText(textOf(request.platform));
  const query = textOf(request.query).trim();
  const resourceId = textOf(request.resourceId).trim();
  const limit = typeof request.limit === 'number' ?
    Math.max(1, Math.min(25, request.limit)) : 10;
  try {
    if (platform === 'x') {
      const fixedArgs: SocialXCommunityArgs = {
        query,
        maxResults: Math.max(10, limit)
      };
      const execution = await callComposioFixedRaw(
        'Search recent public X posts', 'social.x.community.search', fixedArgs
      );
      return parseComposioCommunityFeed('x', execution.observation);
    }
    if (platform === 'reddit') {
      const fixedArgs: SocialRedditCommunityArgs = { searchQuery: query, limit };
      const execution = await callComposioFixedRaw(
        'Search public Reddit posts', 'social.reddit.search', fixedArgs
      );
      return parseComposioCommunityFeed('reddit', execution.observation);
    }
    if (platform === 'instagram') {
      const profile = await socialProfileForPreview('instagram');
      if (profile.id.length === 0) {
        return socialHubConnectionResult(
          'instagram', 'Instagram', 'error', 'Provider profile 没有返回真实账号 ID。'
        );
      }
      const fixedArgs: SocialInstagramMediaArgs = { igUserId: profile.id, limit };
      const execution = await callComposioFixedRaw(
        'List authenticated Instagram media', 'social.instagram.media.list', fixedArgs
      );
      return parseComposioCommunityFeed('instagram', execution.observation);
    }
    if (platform === 'linkedin') {
      if (resourceId.length === 0) {
        const profile = await socialProfileForPreview('linkedin');
        const result = socialHubConnectionResult(
          'linkedin',
          'LinkedIn',
          'limited',
          '当前账号没有公开社区列表读取权限；请提供可读 resource ID 或补充读 scope。'
        );
        result.connections[0].accountId = profile.id;
        return result;
      }
      const fixedArgs: SocialLinkedInPostArgs = { postId: resourceId };
      const execution = await callComposioFixedRaw(
        'Read one LinkedIn post', 'social.linkedin.post.read', fixedArgs
      );
      return parseComposioCommunityFeed('linkedin', execution.observation);
    }
    return socialHubConnectionResult(
      platform, 'SocialHub', 'error', '请选择 X、LinkedIn、Instagram 或 Reddit。'
    );
  } catch (error) {
    return socialHubConnectionResult(platform, 'SocialHub', 'error', describeThrown(error));
  }
}

async function socialPublicationPreview(args: Object | null): Promise<SocialHubPublicationData> {
  const request = args === null ? {} as SocialPublicationPreviewRequestArgs :
    args as SocialPublicationPreviewRequestArgs;
  const platform = socialHubPlatformFromText(textOf(request.platform));
  const text = textOf(request.text).trim();
  const base: SocialHubPublicationPreviewInput = {
    platform,
    operation: textOf(request.operation).trim().toLowerCase(),
    text
  };
  if (base.operation !== 'publish' || text.length === 0 || text.length > 3000 ||
    (platform !== 'x' && platform !== 'linkedin' &&
      platform !== 'instagram' && platform !== 'reddit')) {
    return createSocialHubPublicationPreview(base);
  }
  try {
    const identity = await socialProfileForPreview(platform);
    base.accountId = identity.id;
    base.accountName = identity.name;
    return createSocialHubPublicationPreview(base);
  } catch (error) {
    const failed = createSocialHubPublicationPreview(base);
    failed.error = '读取真实 provider 账号失败：' + describeThrown(error);
    return failed;
  }
}

async function composioInstagramSocialFeed(): Promise<SocialHubFeedResult> {
  try {
    const profileArgs: SocialInstagramProfileArgs = { igUserId: 'me' };
    const conversationArgs: SocialInstagramConversationArgs = { limit: 5 };
    const initial = await Promise.all([
      callComposioFixedRaw('Authenticated Instagram profile', 'social.instagram.profile', profileArgs),
      callComposioFixedRaw('Instagram messaging conversations', 'social.instagram.conversations.list', conversationArgs)
    ]);
    const ownAccountId = socialProfileId(initial[0].observation);
    const conversations = initial[1];
    const conversationState = parseComposioSocialFeed('instagram', conversations.observation);
    if (conversationState.connections[0].status === 'error') {
      return conversationState;
    }
    const ids = instagramConversationIds(conversations.observation);
    if (ids.length === 0) {
      return conversationState;
    }
    const executions: ComposioRawExecution[] = await Promise.all(ids.map((id: string) =>
      {
        const messageArgs: SocialInstagramMessageArgs = { conversationId: id, limit: 25 };
        return callComposioFixedRaw(
          'Instagram messages in conversation',
          'social.instagram.messages.list',
          messageArgs
        );
      }
    ));
    const items: SocialHubItemData[] = [];
    let connection = conversationState.connections[0];
    executions.forEach((execution: ComposioRawExecution, index: number) => {
      const parsed = parseComposioSocialFeed('instagram', execution.observation, ids[index], ownAccountId);
      parsed.items.forEach((item: SocialHubItemData) => items.push(item));
      if (parsed.connections[0].status === 'error') {
        connection = parsed.connections[0];
      }
    });
    return { items: items, connections: [connection] };
  } catch (error) {
    return socialHubConnectionResult('instagram', 'Instagram', 'error', describeThrown(error));
  }
}

async function socialHubPlatformFeed(platform: SocialHubPlatform): Promise<SocialHubFeedResult> {
  if (platform === 'x') {
    return composioXSocialFeed();
  }
  if (platform === 'slack') {
    return composioSlackSocialFeed();
  }
  if (platform === 'instagram') {
    return composioInstagramSocialFeed();
  }
  if (platform === 'whatsapp') {
    return socialHubConnectionResult(
      'whatsapp',
      'WhatsApp',
      'limited',
      '当前 WhatsApp 工具只提供 Business 发送记录，不提供收件箱消息正文。'
    );
  }
  if (platform === 'discord') {
    return socialHubConnectionResult('discord', 'Discord', 'limited', '当前授权未提供 Discord 消息读取工具。');
  }
  if (platform === 'linkedin') {
    return socialHubConnectionResult('linkedin', 'LinkedIn', 'limited', '当前授权未提供 LinkedIn 私信读取工具。');
  }
  if (platform === 'wecom') {
    return socialHubConnectionResult('wecom', '企业微信', 'needs_auth', '企业微信尚未配置消息接口。');
  }
  return socialHubConnectionResult(platform, 'SocialHub', 'disabled', '当前来源不受支持。');
}

async function composioSocialAggregate(args: Object | null): Promise<SocialHubFeedResult> {
  const items: SocialHubItemData[] = [];
  const connections: SocialHubConnectionData[] = [];
  const results = await Promise.all(socialHubRequestedPlatforms(args).map((platform: SocialHubPlatform) =>
    socialHubPlatformFeed(platform)
  ));
  results.forEach((result: SocialHubFeedResult) => {
    result.items.forEach((item: SocialHubItemData) => items.push(item));
    result.connections.forEach((connection: SocialHubConnectionData) => connections.push(connection));
  });
  return { items: items, connections: connections };
}

export async function sendLocalSocialHubReply(item: SocialHubItemData, text: string): Promise<SocialHubDraftData> {
  if (item.platform === 'slack') {
    const message = text.trim();
    if (message.length === 0) {
      return {
        itemId: item.id,
        platform: item.platform,
        text: '',
        status: 'error',
        error: '请输入要发送的 Slack 回复。',
        localOnly: true,
        sent: false
      };
    }
    const channelId = item.channelId.trim().length > 0 ? item.channelId.trim() : item.channel.trim();
    if (channelId.length === 0) {
      return {
        itemId: item.id,
        platform: item.platform,
        text: '',
        status: 'error',
        error: 'Slack 搜索结果缺少 channel id，不能发送回复。',
        localOnly: true,
        sent: false
      };
    }
    const args: SlackComposioReplyArgs = {
      channel: channelId,
      text: message,
      threadTs: item.threadId.trim().length > 0 ? item.threadId.trim() : item.timestamp.trim()
    };
    const result = await composioFixedAppResult(
      'social.slack.message.send',
      'Slack',
      '回复 Slack 消息',
      '消息回复',
      args as Object
    );
    if (result.status !== 'success') {
      return {
        itemId: item.id,
        platform: item.platform,
        text: '',
        status: 'error',
        error: result.summary.trim().length > 0 ? result.summary : result.title,
        localOnly: true,
        sent: false
      };
    }
    return {
      itemId: item.id,
      platform: item.platform,
      text: '已通过 Composio 发送到 Slack：' + message,
      status: 'draft',
      error: '',
      localOnly: false,
      sent: true
    };
  }
  return socialHubClient.sendReply(item, text);
}

async function callLocalSocialHubTool(toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  if (toolId === 'social.reply.draft') {
    const request: SocialHubDraftRequestArgs = args === null ? emptySocialHubDraftRequestArgs() : args as SocialHubDraftRequestArgs;
    const itemId = textOf(request.itemId).trim();
    const platform = socialHubPlatformFromText(textOf(request.platform));
    const instruction = textOf(request.instruction).trim();
    if (itemId.length === 0 || platform === 'unknown' || instruction.length === 0) {
      const failed: SocialHubDraftData = {
        itemId,
        platform,
        text: '',
        status: 'error',
        error: 'Social reply draft requires a selected real item ID, platform, and instruction.',
        localOnly: true,
        sent: false
      };
      return socialHubDraftA2ui(surfaceId, failed);
    }
    const draft = await socialHubClient.draft(itemId, platform, instruction);
    return socialHubDraftA2ui(surfaceId, draft);
  }
  if (toolId === 'social.feed.search') {
    const result = await callStructuredSocialHubTool(args);
    return socialHubStructuredDataA2ui(surfaceId, result.data as SocialHubStructuredData);
  }
  if (toolId === 'social.community.search') {
    const result = await composioSocialCommunity(args);
    return socialHubCommunityA2ui(surfaceId, result.items, result.connections);
  }
  if (toolId === 'social.post.preview') {
    return socialHubPublicationA2ui(surfaceId, await socialPublicationPreview(args));
  }
  return socialHubFeedA2ui(surfaceId, [], []);
}

async function callStructuredSocialHubTool(args: Object | null): Promise<DataResult> {
  return socialHubStructuredDataResult(await composioSocialAggregate(args));
}

async function callStructuredSocialCommunityTool(args: Object | null): Promise<DataResult> {
  return socialHubStructuredDataResult(
    await composioSocialCommunity(args),
    'social.community.search'
  );
}

interface XPostPreviewEnvelope {
  posts?: Object[];
  tweets?: Object[];
  statuses?: Object[];
  items?: Object[];
  data?: Object | Object[] | null;
}

function xPostPreviewItems(value: Object | Object[] | null | undefined): Object[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  const envelope = value as XPostPreviewEnvelope;
  const candidates = [envelope.posts, envelope.tweets, envelope.statuses, envelope.items];
  for (let index = 0; index < candidates.length; index++) {
    if (Array.isArray(candidates[index])) {
      return candidates[index] as Object[];
    }
  }
  if (envelope.data !== value) {
    return xPostPreviewItems(envelope.data);
  }
  return [];
}

function xPostPreviewHasRealPost(rawPreview: string): boolean {
  try {
    const items = xPostPreviewItems(JSON.parse(rawPreview) as Object);
    for (let index = 0; index < items.length; index++) {
      const record = items[index] as Record<string, Object | string | number | boolean | null | undefined>;
      const id = textOf(record.id ?? record.tweet_id ?? record.post_id).trim();
      const content = textOf(record.text ?? record.messageText ?? record.content ?? record.url).trim();
      if (id.length > 0 && content.length > 0) {
        return true;
      }
    }
  } catch (_error) {
  }
  return false;
}

export function xPostStructuredDataResult(result: DynamicGenericToolResult): DataResult {
  const data: GenericStructuredData = { results: [result] };
  if (result.providerPhase !== 'execution') {
    const message = result.summary.trim().length > 0 ? result.summary :
      'Composio discovery did not execute an X post read tool.';
    return structuredErrorWithData(
      'x.post.search', 'genericToolResults', data, 'X_POST_TOOL_NOT_EXECUTED', message, false, [], [message]
    );
  }
  if (result.status !== 'success') {
    return genericStructuredDataResult('x.post.search', 'genericToolResults', [result]);
  }
  if (!xPostPreviewHasRealPost(result.rawPreview)) {
    const empty = successfulDataResult(
      'x.post.search', 'genericToolResults', data, [genericResultSource(result)]
    );
    empty.status = 'empty';
    return empty;
  }
  return genericStructuredDataResult('x.post.search', 'genericToolResults', [result]);
}

async function callStructuredXTool(toolId: string, prompt: string, args: Object | null): Promise<DataResult> {
  return xPostStructuredDataResult(
    await composioFixedAppResult(toolId, 'Twitter', prompt, '公开 posts', args)
  );
}

async function callLocalXTool(toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  const result = await callStructuredXTool(toolId, prompt, args);
  return genericToolResultsA2ui(surfaceId, toolId, (result.data as GenericStructuredData).results);
}

async function callStructuredYouTubeVideoTool(prompt: string, args: Object | null): Promise<DataResult> {
  return genericStructuredDataResult(
    'youtube.video.search',
    'youtubeVideos',
    await callYouTubeVideoSearch(
      youtubeQueryFromArgs(prompt, args),
      localProviderConfig.youtubeApiKey,
      youtubeSearchOptionsFromArgs(args)
    )
  );
}

async function callStructuredYouTubeAccountTool(
  toolId: string,
  prompt: string,
  args: Object | null
): Promise<DataResult> {
  const configured = isComposioConfigured();
  const result = await composioFixedAppResult(
    toolId,
    'YouTube',
    prompt,
    toolId === 'youtube.mine.subscriptions' ? '订阅' : '播放列表',
    args
  );
  if (configured || result.status === 'success') {
    result.providerPhase = 'execution';
  }
  return remainingReadStructuredDataResult(
    toolId,
    toolId === 'youtube.mine.subscriptions' ? 'youtubeSubscriptions' : 'youtubePlaylists',
    [result]
  );
}

async function callLocalYouTubeTool(toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  if (toolId === 'youtube.video.search') {
    const result = await callStructuredYouTubeVideoTool(prompt, args);
    return mediaVideoStructuredDataA2ui(surfaceId, toolId, result.data as GenericStructuredData);
  }
  const result = await callStructuredYouTubeAccountTool(toolId, prompt, args);
  return genericToolResultsA2ui(surfaceId, toolId, (result.data as GenericStructuredData).results);
}

async function callStructuredMediaTool(toolId: string, prompt: string, args: Object | null): Promise<DataResult> {
  if (toolId === 'media.video.search') {
    return genericStructuredDataResult(
      toolId,
      'mediaVideos',
      await callMediaVideoSearch(prompt, args, localProviderConfig.youtubeApiKey)
    );
  }
  if (toolId === 'media.aggregate.search') {
    return aggregateStructuredDataResult(await callAggregateSearch(
      prompt,
      args,
      localProviderConfig.youtubeApiKey,
      { apiKey: localProviderConfig.zhihuApiKey }
    ));
  }
  return errorDataResult(toolId, '', 'MEDIA_TOOL_UNSUPPORTED', 'Unsupported media tool: ' + toolId + '.');
}

async function callLocalMediaTool(toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  if (toolId === 'media.video.search') {
    const result = await callStructuredMediaTool(toolId, prompt, args);
    return mediaVideoStructuredDataA2ui(surfaceId, toolId, result.data as GenericStructuredData);
  }
  if (toolId === 'media.aggregate.search') {
    const result = await callStructuredMediaTool(toolId, prompt, args);
    return aggregateSearchA2ui(surfaceId, result.data as AggregateSearchResult);
  }
  return genericToolResultsA2ui(surfaceId, toolId, [{
    sourceTag: '媒体聚合',
    toolName: toolId,
    title: '未知媒体工具',
    status: 'error',
    summary: '当前媒体聚合只支持 media.video.search 和 media.aggregate.search。',
    rows: [{ label: 'Tool ID', value: toolId }],
    rawPreview: 'unknown media tool'
  }]);
}

function mailDetailDynamicResult(toolId: string, data: MailThreadStructuredData): DynamicGenericToolResult {
  return {
    sourceTag: data.provider === 'gmail' ? 'Gmail API' : 'QQ Mail',
    toolName: data.provider === 'gmail' ? 'users.threads.get' : toolId,
    title: data.subject.length > 0 ? data.subject : '(no subject)',
    status: 'success',
    summary: data.body.length > 0 ? data.body : data.bodyHtml,
    rows: [
      { label: 'Provider', value: data.provider },
      { label: 'Request Key', value: data.requestKey },
      { label: 'Thread ID', value: data.threadId },
      { label: 'Message ID', value: data.messageId },
      { label: 'From', value: data.from },
      { label: 'To', value: data.to.join(', ') }
    ],
    rawPreview: JSON.stringify({
      provider: data.provider, requestKey: data.requestKey,
      threadId: data.threadId, messageId: data.messageId
    })
  };
}

async function callLocalGmailTool(
  toolId: string,
  prompt: string,
  surfaceId: string,
  args: Object | null = null
): Promise<string> {
  if (toolId === 'gmail.message.send') {
    return genericToolResultsA2ui(surfaceId, toolId, [{
      sourceTag: 'Gmail', toolName: toolId, title: 'Gmail 回复未发送', status: 'error',
      summary: 'Gmail replies require the registered current Gmail surface action.',
      rows: [{ label: 'Error', value: 'GMAIL_REPLY_REGISTERED_ACTION_REQUIRED' }], rawPreview: ''
    }]);
  }
  if (toolId === 'gmail.open.web') {
    return gmailOpenWebA2ui(surfaceId, 'https://mail.google.com/mail/u/0/#inbox');
  }
  try {
    if (toolId === 'gmail.mail.search') {
      const result = await callStructuredGmailReadTool(toolId, prompt, args);
      return gmailSearchStructuredDataA2ui(surfaceId, toolId, result.data as GmailSearchStructuredData);
    }
    if (toolId === 'gmail.thread.read') {
      const result = await callStructuredGmailReadTool(toolId, prompt, args);
      if (result.status === 'success') {
        return gmailThreadResultsA2ui(surfaceId, toolId, [
          mailDetailDynamicResult(toolId, result.data as MailThreadStructuredData)
        ]);
      }
      const message = result.error?.message === undefined ? 'Gmail thread read failed.' : result.error.message;
      return gmailThreadResultsA2ui(surfaceId, toolId, [{
        sourceTag: 'Gmail', toolName: toolId, title: 'Gmail 正文读取失败', status: 'error',
        summary: message, rows: [{ label: '错误', value: message }], rawPreview: ''
      }]);
    }
    const results = await configuredGmailResults(toolId, prompt, args);
    if (toolId === 'gmail.draft.create' || toolId === 'gmail.draft.apply') {
      return gmailDraftPreviewA2ui(
        surfaceId,
        results[0],
        toolId === 'gmail.draft.create' ? args : null,
        toolId
      );
    }
    return gmailThreadResultsA2ui(surfaceId, toolId, results);
  } catch (error) {
    return gmailThreadResultsA2ui(surfaceId, toolId, [gmailErrorResult(toolId, describeThrown(error))]);
  }
}

async function callLocalMailTool(toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  if (toolId === 'mail.search') {
    const result = await callStructuredMailSearch(prompt, args);
    return mailSearchStructuredDataA2ui(surfaceId, toolId, result.data as MailSearchStructuredData);
  }

  if (toolId === 'mail.thread.read') {
    const result = await callStructuredMailThreadRead(toolId, args);
    if (result.status === 'success') {
      return mailResultsFromDynamicA2ui(surfaceId, toolId, [
        mailDetailDynamicResult(toolId, result.data as MailThreadStructuredData)
      ]);
    }
    const message = result.error?.message === undefined ? 'Mail thread read failed.' : result.error.message;
    return mailResultsFromDynamicA2ui(surfaceId, toolId, [{
      sourceTag: 'Mail', toolName: toolId, title: '邮件正文读取失败', status: 'error',
      summary: message, rows: [{ label: '错误', value: message }], rawPreview: ''
    }]);
  }

  if (toolId === 'mail.draft.create') {
    const parsed = mailDraftArgs(args);
    if (parsed.provider === 'gmail') {
      return callLocalGmailTool('gmail.draft.create', prompt, surfaceId, args);
    }
    if (parsed.provider === 'qq') {
      try {
        const qq = new QqMailImapClient(qqMailConfig());
        return mailDraftPreviewA2ui(surfaceId, await qq.createDraft(parsed));
      } catch (error) {
        const rows: A2uiLabelValueData[] = [
          { label: 'Source', value: 'QQ Mail' },
          { label: 'Status', value: 'Draft not saved' }
        ];
        const result: DynamicGenericToolResult = {
          sourceTag: 'QQ Mail',
          toolName: 'mail.draft.create',
          title: 'QQ 邮箱草稿保存失败',
          status: 'error',
          summary: describeThrown(error),
          rows: rows,
          rawPreview: 'qq draft failed'
        };
        return mailResultsFromDynamicA2ui(surfaceId, toolId, [result], 'Mail Draft Preview');
      }
    }
    const rows: A2uiLabelValueData[] = [{ label: 'Missing', value: 'provider' }];
    const result: DynamicGenericToolResult = {
      sourceTag: 'Mail',
      toolName: 'mail.draft.create',
      title: '邮箱草稿缺少 provider',
      status: 'error',
      summary: 'mail.draft.create requires args.provider to be gmail or qq.',
      rows: rows,
      rawPreview: 'missing provider'
    };
    return mailResultsFromDynamicA2ui(surfaceId, toolId, [result]);
  }

  const rows: A2uiLabelValueData[] = [{ label: 'Tool', value: toolId }];
  const result: DynamicGenericToolResult = {
    sourceTag: 'Mail',
    toolName: toolId,
    title: '未知邮箱工具',
    status: 'error',
    summary: 'Unsupported mail tool: ' + toolId,
    rows: rows,
    rawPreview: 'unsupported mail tool'
  };
  return mailResultsFromDynamicA2ui(surfaceId, toolId, [result]);
}

function hasCalendarScope(scope: string): boolean {
  return scope.indexOf('https://www.googleapis.com/auth/calendar') >= 0 ||
    scope.indexOf('https://www.googleapis.com/auth/calendar.events') >= 0 ||
    scope.indexOf('https://www.googleapis.com/auth/calendar.readonly') >= 0;
}

async function googleAccessTokenForCalendar(): Promise<string> {
  const token = await loadGmailOAuthTokenSet(gmailCredentialStore);
  if (token !== null && hasCalendarScope(token.scope)) {
    if (isGmailAccessTokenFresh(token)) {
      return token.accessToken;
    }
    if (token.refreshToken.length > 0) {
      const config = gmailOAuthConfigFromProvider();
      if (config.clientId.length > 0) {
        const refreshed = await refreshGmailOAuthAccessToken(config, token.refreshToken);
        const saved = await saveGmailOAuthTokenSet(gmailCredentialStore, refreshed);
        return hasCalendarScope(saved.scope) ? saved.accessToken : '';
      }
    }
  }
  return '';
}

function calendarAuthUnavailableMessage(toolId: string, prompt: string): string {
  return 'Google Calendar OAuth 未授权：工具 ' + toolId + ' 已注册，但当前设备没有可用的 Calendar scope；请先授权 Calendar。AIPhone 不会模拟日程或 eventId。请求：' + prompt.substring(0, 160);
}

function calendarComposioArgs(toolId: string, prompt: string, args: Object | null): CalendarComposioArgs {
  const source = args === null ? JSON.parse('{}') as CalendarComposioArgs : args as CalendarComposioArgs;
  const normalized = normalizedCalendarArgsForPrompt(toolId, prompt, source) as CalendarComposioArgs;
  normalized.calendarId = textOf(normalized.calendarId).trim().length > 0 ? textOf(normalized.calendarId).trim() : 'primary';
  if (toolId === 'calendar.event.create' || toolId === 'calendar.event.update') {
    normalized.start = calendarProviderDateTime(textOf(normalized.start));
    normalized.end = calendarProviderDateTime(textOf(normalized.end));
  }
  if (toolId === 'calendar.event.delete') {
    normalized.sendUpdates = 'none';
  }
  return normalized;
}

export function calendarDeleteConfirmedForTest(actionId: string): boolean {
  return actionId === 'calendar.event.delete.confirm';
}

function calendarWriteActionAllowed(toolId: string, actionId: string): boolean {
  if (toolId === 'calendar.event.delete') {
    return actionId === 'calendar.event.delete.confirm';
  }
  return (toolId === 'calendar.event.create' || toolId === 'calendar.event.update') &&
    actionId === toolId;
}

function isCalendarWriteTool(toolId: string): boolean {
  return toolId === 'calendar.event.create' || toolId === 'calendar.event.update' ||
    toolId === 'calendar.event.delete';
}

function calendarRegisteredActionRequired(toolId: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Composio Google Calendar',
    toolName: toolId,
    title: '需要当前日程操作确认',
    status: 'blocked',
    summary: 'Calendar 写操作只能由当前已注册的精确页面操作执行。',
    rows: [],
    rawPreview: 'registered Calendar action required'
  };
}

async function callStructuredCalendarRead(prompt: string, args: Object | null): Promise<DataResult> {
  const toolId = 'calendar.events.search';
  const normalized = calendarComposioArgs(toolId, prompt, args);
  const missing = calendarEventRequiredFields(toolId, normalized);
  if (missing.length > 0) {
    return remainingReadStructuredDataResult(
      toolId, 'calendarEvents', [calendarMissingArgsResult(toolId, missing)]
    );
  }
  try {
    const execution = await callComposioFixedRaw(
      composioProviderPrompt('Google Calendar', prompt, '日程'),
      toolId,
      normalized as Object
    );
    const generic = composioDynamicResultFromObservation('execute', execution.observation, execution.toolSlug, prompt);
    let results: DynamicGenericToolResult[];
    if (generic.status === 'error') {
      results = [composioFixedResult(toolId, 'Google Calendar', generic, normalized as Object)];
    } else {
      results = calendarResultsFromComposioObservation(toolId, execution.observation, normalized);
    }
    results.forEach((result: DynamicGenericToolResult) => {
      result.providerPhase = 'execution';
    });
    return remainingReadStructuredDataResult(toolId, 'calendarEvents', results);
  } catch (error) {
    const result: DynamicGenericToolResult = {
      sourceTag: 'Composio Google Calendar',
      toolName: toolId,
      title: isComposioConfigured() ? 'Google Calendar 调用失败' : 'Composio 未配置',
      status: isComposioConfigured() ? 'error' : 'needs_auth',
      summary: describeThrown(error),
      rows: [],
      rawPreview: ''
    };
    if (isComposioConfigured()) {
      result.providerPhase = 'execution';
    }
    return remainingReadStructuredDataResult(toolId, 'calendarEvents', [result]);
  }
}

async function callLocalCalendarTool(
  toolId: string,
  prompt: string,
  surfaceId: string,
  actionId: string,
  args: Object | null = null
): Promise<string> {
  if (toolId === 'calendar.events.search') {
    const result = await callStructuredCalendarRead(prompt, args);
    return genericToolResultsA2ui(surfaceId, toolId, (result.data as GenericStructuredData).results);
  }
  if (!calendarWriteActionAllowed(toolId, actionId)) {
    return genericToolResultsA2ui(surfaceId, toolId, [calendarRegisteredActionRequired(toolId)]);
  }
  const normalized = calendarComposioArgs(toolId, prompt, args);
  const missing = calendarEventRequiredFields(toolId, normalized);
  if (missing.length > 0) {
    return genericToolResultsA2ui(surfaceId, toolId, [calendarMissingArgsResult(toolId, missing)]);
  }
  try {
    const execution = await callComposioFixedRaw(
      composioProviderPrompt('Google Calendar', prompt, toolId === 'calendar.events.search' ? '日程' : '日程变更'),
      toolId,
      normalized as Object
    );
    const generic = composioDynamicResultFromObservation('execute', execution.observation, execution.toolSlug, prompt);
    if (generic.status === 'error') {
      return genericToolResultsA2ui(surfaceId, toolId, [composioFixedResult(toolId, 'Google Calendar', generic, normalized as Object)]);
    }
    return genericToolResultsA2ui(surfaceId, toolId,
      calendarResultsFromComposioObservation(toolId, execution.observation, normalized));
  } catch (error) {
    return genericToolResultsA2ui(surfaceId, toolId, [
      await composioFixedAppResult(toolId, 'Google Calendar', prompt,
        toolId === 'calendar.events.search' ? '日程' : '日程变更', normalized as Object)
    ]);
  }
}

function whatsAppArgs(args: Object | null): WhatsAppSendArgs {
  return args === null ? JSON.parse('{}') as WhatsAppSendArgs : args as WhatsAppSendArgs;
}

type WhatsAppObservationValue = Object | string | number | boolean | null | undefined;
type WhatsAppObservationRecord = Record<string, WhatsAppObservationValue>;

interface WhatsAppObservationTruth {
  messageId: string;
  failed: boolean;
}

function whatsAppErrorValue(value: WhatsAppObservationValue): boolean {
  if (value === null || value === undefined) {
    return false;
  }
  if (typeof value === 'string') {
    return value.trim().length > 0 && value.trim().toLowerCase() !== 'null';
  }
  return true;
}

function inspectWhatsAppObservation(
  value: WhatsAppObservationValue,
  depth: number,
  messageIds: string[]
): boolean {
  if (depth > 10) {
    return true;
  }
  if (value === null || value === undefined || typeof value !== 'object') {
    return false;
  }
  if (Array.isArray(value)) {
    const items = value as WhatsAppObservationValue[];
    for (let index = 0; index < items.length; index++) {
      if (inspectWhatsAppObservation(items[index], depth + 1, messageIds)) {
        return true;
      }
    }
    return false;
  }
  const record = value as WhatsAppObservationRecord;
  if (record['success'] === false || record['success'] === 'false' ||
    record['successful'] === false || record['successful'] === 'false') {
    return true;
  }
  const keys = Object.keys(record);
  if (keys.indexOf('error') >= 0 && whatsAppErrorValue(record['error'])) {
    return true;
  }
  const status = typeof record['status'] === 'string' ? record['status'].trim().toLowerCase() : '';
  if (status.indexOf('fail') >= 0 || status.indexOf('error') >= 0 ||
    status.indexOf('reject') >= 0 || status.indexOf('denied') >= 0 ||
    status.indexOf('invalid') >= 0) {
    return true;
  }
  for (let index = 0; index < keys.length; index++) {
    const key = keys[index];
    if (key === 'messages') {
      const messages = record[key];
      if (!Array.isArray(messages) || messages.length !== 1) {
        return true;
      }
      const item = (messages as WhatsAppObservationValue[])[0];
      if (item === null || typeof item !== 'object' || Array.isArray(item)) {
        return true;
      }
      const id = (item as WhatsAppObservationRecord)['id'];
      if (typeof id !== 'string' || !id.trim().startsWith('wamid.')) {
        return true;
      }
      messageIds.push(id.trim());
    }
    if (inspectWhatsAppObservation(record[key], depth + 1, messageIds)) {
      return true;
    }
  }
  return false;
}

function parseWhatsAppObservation(raw: string): WhatsAppObservationTruth {
  try {
    const messageIds: string[] = [];
    const failed = inspectWhatsAppObservation(JSON.parse(raw) as Object, 0, messageIds);
    return {
      messageId: !failed && messageIds.length === 1 ? messageIds[0] : '',
      failed: failed || messageIds.length !== 1
    };
  } catch (_error) {
    return { messageId: '', failed: true };
  }
}

function normalizedWhatsAppProviderResult(result: DynamicGenericToolResult): DynamicGenericToolResult {
  const truth = parseWhatsAppObservation(result.rawPreview);
  if (truth.failed) {
    return {
      sourceTag: 'Composio WhatsApp Business',
      toolName: 'whatsapp.message.send',
      title: 'WhatsApp Business 返回无效',
      status: 'error',
      summary: 'Provider 未返回唯一有效的 WhatsApp Message ID。',
      rows: [],
      rawPreview: result.rawPreview
    };
  }
  result.status = 'success';
  result.sourceTag = 'Composio WhatsApp Business';
  result.toolName = 'whatsapp.message.send';
  result.rows = result.rows.filter(
    (row: A2uiLabelValueData): boolean => row.label.trim().toLowerCase() !== 'message id'
  );
  result.rows.push({ label: 'Message ID', value: truth.messageId });
  result.actions = undefined;
  return result;
}

export function whatsAppProviderResultFromObservationForTest(
  observation: string
): DynamicGenericToolResult {
  const parsed = composioDynamicResultFromObservation(
    'execute', observation, 'WHATSAPP_SEND_MESSAGE', 'WhatsApp Business send'
  );
  parsed.rawPreview = observation.substring(0, 16000);
  return normalizedWhatsAppProviderResult(composioFixedResult(
    'whatsapp.message.send',
    'WhatsApp Business',
    parsed
  ));
}

function whatsAppRecipientDigits(value: string): string {
  const input = value.trim();
  if (input.length === 0 || input.charAt(0) !== '+') {
    return '';
  }
  let digits = '';
  for (let index = 1; index < input.length; index++) {
    const char = input.charAt(index);
    if (char >= '0' && char <= '9') {
      digits += char;
    } else if (char !== ' ' && char !== '-' && char !== '(' && char !== ')') {
      return '';
    }
  }
  return digits.length >= 8 && digits.length <= 15 ? digits : '';
}

export function whatsAppSendConfirmedForTest(actionId: string): boolean {
  return actionId === 'whatsapp.message.send.confirm';
}

export function whatsAppSafeTargetAllowedForTest(toNumber: string): boolean {
  const configured = whatsAppRecipientDigits(localProviderConfig.whatsappTestTo);
  const requested = whatsAppRecipientDigits(toNumber);
  return configured.length > 0 && requested === configured;
}

export function whatsAppProviderFailureSummaryForTest(raw: string): string {
  const lower = raw.toLowerCase();
  if (lower.indexOf('no active connection found') >= 0 || lower.indexOf('没有 active connected account') >= 0) {
    return 'WhatsApp 授权刚完成，请返回 App 后重试一次。';
  }
  if ((lower.indexOf('code 100') >= 0 && lower.indexOf('error_subcode 33') >= 0) ||
    lower.indexOf('object does not exist') >= 0 || lower.indexOf('unsupported get request') >= 0) {
    return '当前 Business 账户的 WABA 配置无效或缺少管理权限，请重新授权。';
  }
  if (lower.indexOf('133010') >= 0 || lower.indexOf('account not registered') >= 0) {
    return '当前 Business 发送号码尚未注册到 WhatsApp Cloud API，请先在 Meta 后台完成号码验证与 API 注册。';
  }
  if (lower.indexOf('not_verified') >= 0 || lower.indexOf('not verified') >= 0) {
    return '当前 Business 发送号码尚未完成验证，请先在 Meta 后台完成验证。';
  }
  return 'WhatsApp Business 暂时无法发送，请刷新授权后重试。';
}

function whatsAppProviderFailureResult(raw: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Composio WhatsApp Business',
    toolName: 'whatsapp.message.send',
    title: 'WhatsApp Business 发送失败',
    status: 'error',
    summary: whatsAppProviderFailureSummaryForTest(raw),
    rows: [],
    rawPreview: raw
  };
}

function whatsAppInputResult(toNumber: string, text: string): DynamicGenericToolResult | null {
  const missing: A2uiLabelValueData[] = [];
  if (whatsAppRecipientDigits(toNumber).length === 0) {
    missing.push({ label: 'Missing', value: 'toNumber (+country code)' });
  }
  if (text.trim().length === 0 || text.trim().length > 4096) {
    missing.push({ label: 'Missing', value: 'text (1-4096 chars)' });
  }
  if (missing.length === 0) {
    return null;
  }
  return {
    sourceTag: 'Composio WhatsApp Business',
    toolName: 'whatsapp.message.send',
    title: '需要 WhatsApp Business 发送信息',
    status: 'needs_input',
    summary: '请提供带国家码的手机号和 1-4096 字符消息。',
    rows: missing,
    rawPreview: 'invalid whatsapp send input'
  };
}

function whatsAppUnsafeTargetResult(): DynamicGenericToolResult {
  const configured = localProviderConfig.whatsappTestTo.trim().length > 0;
  return {
    sourceTag: 'Composio WhatsApp Business',
    toolName: 'whatsapp.message.send',
    title: 'WhatsApp 测试目标未授权',
    status: 'blocked',
    summary: configured ?
      '当前收件人与 AIPHONE_WHATSAPP_TEST_TO 不匹配，已阻止发送。' :
      '未配置 AIPHONE_WHATSAPP_TEST_TO，已阻止发送且不会猜测号码。',
    rows: [],
    rawPreview: configured ? 'safe target mismatch' : 'safe target missing'
  };
}

function whatsAppConfirmationResult(
  toNumber: string,
  text: string,
  phoneNumberId: string,
  wabaId: string,
  previewUrl: boolean
): DynamicGenericToolResult {
  const confirmArgs: WhatsAppConfirmArgs = {
    toNumber: toNumber,
    text: text,
    phoneNumberId: phoneNumberId,
    wabaId: wabaId,
    previewUrl: previewUrl
  };
  return {
    sourceTag: 'Composio WhatsApp Business',
    toolName: 'whatsapp.message.send',
    title: '确认发送 WhatsApp 消息',
    status: 'confirm_required',
    summary: '将通过已授权的 WhatsApp Business 账号发送。',
    rows: [
      { label: '收件人', value: toNumber },
      { label: '消息', value: text }
    ],
    rawPreview: 'confirm whatsapp send to=' + toNumber,
    actions: [{
      id: 'whatsapp.message.send.confirm',
      label: '确认发送',
      prompt: '确认通过 WhatsApp Business 发送消息',
      variant: 'danger',
      kind: 'prompt',
      args: confirmArgs as Object
    }]
  };
}

function whatsAppPhoneSelectionResult(count: number): DynamicGenericToolResult {
  return {
    sourceTag: 'Composio WhatsApp Business',
    toolName: 'whatsapp.message.send',
    title: '需要选择 WhatsApp Business 发送号码',
    status: 'needs_input',
    summary: count === 0 ? '当前账号没有可用的 Business 发送号码。' : '当前账号有多个 Business 发送号码，请指定 phoneNumberId。',
    rows: [{ label: 'Phone Number IDs', value: count.toString() }],
    rawPreview: 'phoneNumberId count=' + count.toString()
  };
}

async function callLocalWhatsAppTool(
  prompt: string,
  surfaceId: string,
  actionId: string,
  args: Object | null
): Promise<string> {
  const parsed = whatsAppArgs(args);
  const toNumber = textOf(parsed.toNumber).trim();
  const message = textOf(parsed.text).trim();
  const inputError = whatsAppInputResult(toNumber, message);
  if (inputError !== null) {
    return genericToolResultsA2ui(surfaceId, 'whatsapp.message.send', [inputError]);
  }
  if (!whatsAppSafeTargetAllowedForTest(toNumber)) {
    return genericToolResultsA2ui(surfaceId, 'whatsapp.message.send', [whatsAppUnsafeTargetResult()]);
  }
  if (!whatsAppSendConfirmedForTest(actionId)) {
    return genericToolResultsA2ui(surfaceId, 'whatsapp.message.send', [
      whatsAppConfirmationResult(
        toNumber,
        message,
        textOf(parsed.phoneNumberId).trim(),
        textOf(parsed.wabaId).trim(),
        parsed.previewUrl === true
      )
    ]);
  }
  // A user may finish Composio authorization while this app process is still alive.
  // Drop the stale Tool Router session before the confirmed send discovers its account.
  refreshComposioConnections();
  let phoneNumberId = textOf(parsed.phoneNumberId).trim();
  if (phoneNumberId.length === 0) {
    try {
      const lookupArgs: WhatsAppPhoneNumbersArgs = {};
      const wabaId = textOf(parsed.wabaId).trim();
      if (wabaId.length > 0) {
        lookupArgs.wabaId = wabaId;
      }
      const lookup = await callComposioFixedRaw(
        'WhatsApp Business phone numbers',
        'whatsapp.phone_numbers.list',
        lookupArgs as Object
      );
      const lookupResult = composioDynamicResultFromObservation('execute', lookup.observation, lookup.toolSlug, 'WhatsApp Business phone numbers');
      if (lookupResult.status === 'error') {
        return genericToolResultsA2ui(surfaceId, 'whatsapp.message.send', [
          whatsAppProviderFailureResult(lookupResult.summary + ' ' + lookupResult.rawPreview)
        ]);
      }
      const ids = composioPhoneNumberIdsFromObservation(lookup.observation);
      if (ids.length !== 1) {
        return genericToolResultsA2ui(surfaceId, 'whatsapp.message.send', [whatsAppPhoneSelectionResult(ids.length)]);
      }
      phoneNumberId = ids[0];
    } catch (error) {
      return genericToolResultsA2ui(surfaceId, 'whatsapp.message.send', [
        whatsAppProviderFailureResult(describeThrown(error))
      ]);
    }
  }
  const providerArgs: WhatsAppProviderArgs = {
    toNumber: whatsAppRecipientDigits(toNumber),
    text: message,
    phoneNumberId: phoneNumberId,
    previewUrl: parsed.previewUrl === true
  };
  let result: DynamicGenericToolResult;
  try {
    const execution = await callComposioFixedRaw(
      composioProviderPrompt('WhatsApp Business', prompt, '消息'),
      'whatsapp.message.send',
      providerArgs as Object
    );
    const generic = composioDynamicResultFromObservation(
      'execute', execution.observation, execution.toolSlug, prompt
    );
    generic.rawPreview = execution.observation.substring(0, 16000);
    result = normalizedWhatsAppProviderResult(composioFixedResult(
      'whatsapp.message.send', 'WhatsApp Business', generic, providerArgs as Object
    ));
  } catch (error) {
    result = whatsAppProviderFailureResult(describeThrown(error));
  }
  if (result.status === 'success') {
    result.title = 'WhatsApp Business 消息已发送';
    result.summary = 'Provider 已确认发送成功。';
  } else {
    return genericToolResultsA2ui(surfaceId, 'whatsapp.message.send', [
      whatsAppProviderFailureResult(result.summary + ' ' + result.rawPreview)
    ]);
  }
  return genericToolResultsA2ui(surfaceId, 'whatsapp.message.send', [result]);
}

function mapsArgs(args: Object | null): MapsToolArgs {
  if (args === null) {
    return JSON.parse('{}') as MapsToolArgs;
  }
  return args as MapsToolArgs;
}

function mapsSearchQuery(args: MapsToolArgs): string {
  const query = textOf(args.query).trim();
  if (query.length > 0) {
    return query;
  }
  const textQuery = textOf(args.textQuery).trim();
  if (textQuery.length > 0) {
    return textQuery;
  }
  return textOf(args.keyword).trim();
}

function mapsPlaceId(args: MapsToolArgs): string {
  const placeId = textOf(args.placeId).trim();
  return placeId.length > 0 ? placeId : textOf(args.id).trim();
}

async function callLocalMapsTool(toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  if (toolId === 'maps.route.open') {
    return genericToolResultsA2ui(surfaceId, toolId, [mapsRouteResult(args)]);
  }
  const parsed = mapsArgs(args);
  return mapsDataResultA2ui(surfaceId, await callStructuredMapsTool(toolId, prompt, parsed));
}

async function callStructuredMapsTool(toolId: string, prompt: string, args: MapsToolArgs): Promise<DataResult> {
  if (toolId === 'maps.place.details') {
    return mapsStructuredDataResult(
      toolId,
      await callMapsPlaceDetailsProvider(mapsPlaceId(args), localProviderConfig.googleMapsApiKey)
    );
  }
  const query = mapsSearchQuery(args);
  return mapsStructuredDataResult(
    toolId,
    await callMapsPlaceSearchProvider(query.length > 0 ? query : prompt, localProviderConfig.googleMapsApiKey)
  );
}

function paymentArgs(args: Object | null): PaymentToolActionArgs {
  if (args === null) {
    return JSON.parse('{}') as PaymentToolActionArgs;
  }
  return args as PaymentToolActionArgs;
}

function paymentArgText(args: PaymentToolActionArgs, key: string): string {
  const record = args as PaymentToolArgRecord;
  return textOf(record[key]).trim();
}

function paymentProviderFromText(value: string): PaymentProvider {
  const lower = value.trim().toLowerCase();
  if (lower === 'paypal' || lower.indexOf('paypal') >= 0 || lower.indexOf('贝宝') >= 0) {
    return 'paypal';
  }
  if (lower === 'stripe' || lower.indexOf('stripe') >= 0) {
    return 'stripe';
  }
  return '';
}

function paymentCurrencyFromPrompt(source: string, fallback: string): string {
  const lower = source.toLowerCase();
  if (lower.indexOf('usd') >= 0 || source.indexOf('$') >= 0 || source.indexOf('美元') >= 0 || source.indexOf('美金') >= 0) {
    return 'USD';
  }
  if (lower.indexOf('cny') >= 0 || lower.indexOf('rmb') >= 0 || source.indexOf('人民币') >= 0 || source.indexOf('元') >= 0) {
    return 'CNY';
  }
  if (lower.indexOf('hkd') >= 0 || source.indexOf('港币') >= 0 || source.indexOf('港元') >= 0) {
    return 'HKD';
  }
  if (lower.indexOf('jpy') >= 0 || source.indexOf('日元') >= 0) {
    return 'JPY';
  }
  const cleaned = fallback.trim().toUpperCase();
  return cleaned.length > 0 ? cleaned : 'USD';
}

function isAmountChar(char: string): boolean {
  if (char === '.' || char === ',') {
    return true;
  }
  const code = char.charCodeAt(0);
  return code >= 48 && code <= 57;
}

function paymentAmountFromPrompt(source: string): string {
  let started = false;
  let amount = '';
  for (let index = 0; index < source.length; index++) {
    const char = source.charAt(index);
    const code = char.charCodeAt(0);
    if (!started) {
      if (code >= 48 && code <= 57) {
        started = true;
        amount += char;
      }
      continue;
    }
    if (!isAmountChar(char)) {
      break;
    }
    amount += char;
  }
  return amount;
}

function paymentAliasesForAccount(account: PaymentAccount): string[] {
  const aliases: string[] = [account.id, account.displayName, account.email, account.paypalEmail, account.paypalMerchantId];
  for (let index = 0; index < account.aliases.length; index++) {
    aliases.push(account.aliases[index]);
  }
  return aliases;
}

function paymentRecipientFromPrompt(source: string, book: PaymentAccount[]): string {
  const lower = source.toLowerCase();
  const matches: PaymentAccount[] = [];
  for (let accountIndex = 0; accountIndex < book.length; accountIndex++) {
    const account = book[accountIndex];
    if (!account.enabled) {
      continue;
    }
    const aliases = paymentAliasesForAccount(account);
    for (let aliasIndex = 0; aliasIndex < aliases.length; aliasIndex++) {
      const alias = aliases[aliasIndex].trim();
      if (alias.length < 2) {
        continue;
      }
      if (lower.indexOf(alias.toLowerCase()) >= 0) {
        matches.push(account);
        break;
      }
    }
  }
  return matches.length === 1 ? matches[0].displayName : '';
}

function paymentAccountForId(id: string, book: PaymentAccount[]): PaymentAccount | null {
  const normalized = id.trim().toLowerCase();
  if (normalized.length === 0) {
    return null;
  }
  for (let index = 0; index < book.length; index++) {
    if (book[index].id.trim().toLowerCase() === normalized) {
      return book[index];
    }
  }
  return null;
}

function paymentProviderFromPrompt(source: string): PaymentProvider {
  return paymentProviderFromText(source);
}

function paymentFundingSourceFromText(value: string): PaymentFundingSource {
  const lower = value.trim().toLowerCase();
  if (lower === 'google_pay' || lower.indexOf('google pay') >= 0 || lower.indexOf('googlepay') >= 0 ||
    lower.indexOf('google wallet') >= 0 || value.indexOf('谷歌支付') >= 0) {
    return 'google_pay';
  }
  return '';
}

function stringArray(value: string[] | undefined): string[] {
  if (value === undefined || !Array.isArray(value)) {
    return [];
  }
  const result: string[] = [];
  for (let index = 0; index < value.length; index++) {
    const item = textOf(value[index]).trim();
    if (item.length > 0) {
      result.push(item);
    }
  }
  return result;
}

function normalizePaymentAccount(raw: PaymentAccountRaw): PaymentAccount | null {
  const id = textOf(raw.id).trim();
  const displayName = textOf(raw.displayName).trim();
  const name = displayName.length > 0 ? displayName : id;
  if (id.length === 0 || name.length === 0) {
    return null;
  }
  const enabledText = textOf(raw.enabled).trim().toLowerCase();
  return {
    id: id,
    displayName: name,
    aliases: stringArray(raw.aliases),
    email: textOf(raw.email).trim(),
    paypalEmail: textOf(raw.paypalEmail).trim(),
    paypalMerchantId: textOf(raw.paypalMerchantId).trim(),
    stripeAccountId: textOf(raw.stripeAccountId).trim(),
    stripePaymentLinkUrl: textOf(raw.stripePaymentLinkUrl).trim(),
    enabled: enabledText.length === 0 || enabledText === 'true' || enabledText === '1'
  };
}

function upsertPaymentAccount(accounts: PaymentAccount[], account: PaymentAccount): void {
  for (let index = 0; index < accounts.length; index++) {
    if (accounts[index].id === account.id) {
      accounts[index] = account;
      return;
    }
  }
  accounts.push(account);
}

function paymentAccountBookFromConfig(): PaymentAccount[] {
  const accounts = defaultPaymentAccountBook();
  const customAccounts = paymentAccountsFromJson(localProviderConfig.paymentAccountBookJson);
  for (let index = 0; index < customAccounts.length; index++) {
    upsertPaymentAccount(accounts, customAccounts[index]);
  }
  return accounts;
}

function paymentAccountsFromJson(rawJson: string): PaymentAccount[] {
  const accounts: PaymentAccount[] = [];
  const raw = rawJson.trim();
  if (raw.length === 0) {
    return accounts;
  }
  try {
    const parsed = JSON.parse(raw) as Object;
    if (!Array.isArray(parsed)) {
      return accounts;
    }
    const customAccounts = parsed as PaymentAccountRaw[];
    for (let index = 0; index < customAccounts.length; index++) {
      const account = normalizePaymentAccount(customAccounts[index]);
      if (account !== null) {
        upsertPaymentAccount(accounts, account);
      }
    }
  } catch (error) {
    aiLogError('[AIPhone][PaymentConfig] accountBook parse failed: ' + describeThrown(error));
  }
  return accounts;
}

export function configureLocalPaymentAccountBookJson(rawJson: string): void {
  const accounts = paymentAccountsFromJson(localProviderConfig.paymentAccountBookJson);
  const savedAccounts = paymentAccountsFromJson(rawJson);
  for (let index = 0; index < savedAccounts.length; index++) {
    upsertPaymentAccount(accounts, savedAccounts[index]);
  }
  localProviderConfig.paymentAccountBookJson = JSON.stringify(accounts);
}

function paymentModeFromConfig(): PaymentMode {
  return localProviderConfig.paymentMode.trim().toLowerCase() === 'live' ? 'live' : 'test';
}

function paymentAllowedStripeAccounts(): string[] {
  const parts = localProviderConfig.paymentLiveAllowedStripeAccountIds.split(',');
  const result: string[] = [];
  for (let index = 0; index < parts.length; index++) {
    const value = parts[index].trim();
    if (value.length > 0) {
      result.push(value);
    }
  }
  return result;
}

function paymentLiveMaxAmountMinor(): number {
  const value = Number(localProviderConfig.paymentLiveMaxAmountMinor.trim());
  if (isNaN(value) || value <= 0) {
    return 100;
  }
  return Math.floor(value);
}

function paymentPolicyFromConfig(): PaymentPolicy {
  return {
    mode: paymentModeFromConfig(),
    defaultCurrency: localProviderConfig.paymentDefaultCurrency.trim().length > 0 ? localProviderConfig.paymentDefaultCurrency.trim().toUpperCase() : 'USD',
    liveMaxAmountMinor: paymentLiveMaxAmountMinor(),
    liveAllowedStripeAccountIds: paymentAllowedStripeAccounts()
  };
}

function paymentDraftFromArgs(prompt: string, args: Object | null, book: PaymentAccount[]): PaymentRequestDraft {
  const parsed = paymentArgs(args);
  const originalQuery = paymentArgText(parsed, 'originalQuery');
  const source = originalQuery.length > 0 ? originalQuery : prompt;
  const account = paymentAccountForId(paymentArgText(parsed, 'accountId'), book);
  let recipient = paymentArgText(parsed, 'recipient');
  if (recipient.length === 0 && account !== null) {
    recipient = account.displayName;
  }
  if (recipient.length === 0) {
    recipient = paymentRecipientFromPrompt(source, book);
  }
  let amountText = paymentArgText(parsed, 'amountText');
  if (amountText.length === 0) {
    amountText = paymentAmountFromPrompt(source);
  }
  let currency = paymentArgText(parsed, 'currency').toUpperCase();
  if (currency.length === 0) {
    currency = paymentCurrencyFromPrompt(source, localProviderConfig.paymentDefaultCurrency);
  }
  let provider = paymentProviderFromText(paymentArgText(parsed, 'provider'));
  if (provider.length === 0) {
    provider = paymentProviderFromPrompt(source);
  }
  let fundingSource = paymentFundingSourceFromText(paymentArgText(parsed, 'fundingSource'));
  if (fundingSource.length === 0) {
    fundingSource = paymentFundingSourceFromText(source);
  }
  return {
    recipient: recipient,
    provider: provider,
    fundingSource: fundingSource,
    amountText: amountText,
    currency: currency,
    note: paymentArgText(parsed, 'note'),
    phase: paymentArgText(parsed, 'phase')
  };
}

function paymentAmountForProvider(result: PaymentValidationResult): string {
  if (result.currency === 'JPY' || result.currency === 'KRW' || result.currency === 'VND') {
    return result.amountMinor.toString();
  }
  const whole = Math.floor(result.amountMinor / 100);
  const cents = result.amountMinor % 100;
  return whole.toString() + '.' + (cents < 10 ? '0' : '') + cents.toString();
}

function paymentResultWithState(
  result: PaymentValidationResult,
  status: PaymentValidationStatus,
  reason: string,
  checkoutUrl: string,
  providerSessionId: string
): PaymentValidationResult {
  return {
    status: status,
    targetType: result.targetType,
    reason: reason,
    recipient: result.recipient,
    accountId: result.accountId,
    displayName: result.displayName,
    provider: result.provider,
    fundingSource: result.fundingSource,
    amountMinor: result.amountMinor,
    amountText: result.amountText,
    currency: result.currency,
    note: result.note,
    mode: result.mode,
    paypalEmail: result.paypalEmail,
    paypalMerchantId: result.paypalMerchantId,
    stripeAccountId: result.stripeAccountId,
    stripePaymentLinkUrl: result.stripePaymentLinkUrl,
    checkoutUrl: checkoutUrl,
    providerSessionId: providerSessionId,
    paypalClientId: result.paypalClientId,
    paypalEnvironment: result.paypalEnvironment
  } as PaymentValidationResult;
}

export function paypalGooglePayNetworkHelpForTest(provider: string, fundingSource: string, reason: string): string {
  if (provider !== 'paypal' || fundingSource !== 'google_pay') {
    return reason;
  }
  if (!isTransientPayPalRequestErrorForTest(reason)) {
    return reason;
  }
  return reason + ' 手机当前网络/VPN 无法连接 PayPal API。请先关闭 VPN 点“确认支付”创建 PayPal 订单；看到 Pay with G Pay 后，再打开 VPN 并点击 Google Pay。';
}

function paymentBlocked(result: PaymentValidationResult, reason: string): PaymentValidationResult {
  return paymentResultWithState(result, 'blocked', paypalGooglePayNetworkHelpForTest(result.provider, result.fundingSource, reason), '', '');
}

function paymentCheckout(result: PaymentValidationResult, checkoutUrl: string, providerSessionId: string): PaymentValidationResult {
  return paymentResultWithState(result, 'checkout', 'Provider checkout page is ready.', checkoutUrl, providerSessionId);
}

function paypalGooglePayCheckout(result: PaymentValidationResult, checkoutUrl: string, providerSessionId: string): PaymentValidationResult {
  const checkout = paymentCheckout(result, checkoutUrl, providerSessionId);
  if (result.fundingSource === 'google_pay') {
    checkout.paypalClientId = localProviderConfig.paypalClientId;
    checkout.paypalEnvironment = paypalEnvironmentFromConfig();
  }
  return checkout;
}

function isHttpSuccess(response: HttpTextResponse): boolean {
  return response.code >= 200 && response.code < 300;
}

function providerFailure(provider: string, action: string, response: HttpTextResponse): string {
  const snippet = response.text.length > 280 ? response.text.substring(0, 280) + '...' : response.text;
  return provider + ' ' + action + ' failed with HTTP ' + response.code.toString() + ': ' + snippet;
}

function jsonStringField(rawJson: string, key: string): string {
  try {
    const parsed = JSON.parse(rawJson) as PaymentToolArgRecord;
    return textOf(parsed[key]).trim();
  } catch (_error) {
    return '';
  }
}

function paypalEnvironmentFromConfig(): PayPalEnvironment {
  return localProviderConfig.paypalEnvironment === 'live' ? 'live' : 'sandbox';
}

function paypalGatewayBaseEndpoint(): string {
  let endpoint = localProviderConfig.paypalCheckoutGatewayUrl.trim();
  if (endpoint.length === 0) {
    return '';
  }
  while (endpoint.endsWith('/')) {
    endpoint = endpoint.substring(0, endpoint.length - 1);
  }
  if (endpoint.endsWith('/api/payment/paypal/checkout')) {
    return endpoint.substring(0, endpoint.length - '/api/payment/paypal/checkout'.length);
  }
  if (endpoint.endsWith('/api/payment/paypal/capture')) {
    return endpoint.substring(0, endpoint.length - '/api/payment/paypal/capture'.length);
  }
  return endpoint;
}

async function createPayPalGatewayCheckout(result: PaymentValidationResult, baseEndpoint: string): Promise<PaymentValidationResult> {
  const response = await postJsonText(baseEndpoint + '/api/payment/paypal/checkout', stripeGatewayHeaders(), JSON.stringify({
    payeeEmail: result.paypalEmail,
    payeeMerchantId: result.paypalMerchantId,
    amountMinor: result.amountMinor,
    currency: result.currency,
    returnUrl: localProviderConfig.paypalReturnUrl,
    cancelUrl: localProviderConfig.paypalCancelUrl,
    note: result.note
  }));
  let payload: StripeCheckoutGatewayPayload;
  try {
    payload = JSON.parse(response.text) as StripeCheckoutGatewayPayload;
  } catch (_error) {
    return paymentBlocked(result, 'PayPal checkout gateway response was not valid JSON.');
  }
  if (!isHttpSuccess(response) || payload.ok !== true) {
    return paymentBlocked(result, payload.error === undefined ? ('PayPal checkout gateway failed with HTTP ' + response.code.toString() + '.') : payload.error);
  }
  const checkoutUrl = payload.checkoutUrl === undefined ? '' : payload.checkoutUrl.trim();
  if (!checkoutUrl.startsWith('https://www.paypal.com/') && !checkoutUrl.startsWith('https://www.sandbox.paypal.com/')) {
    return paymentBlocked(result, 'PayPal checkout gateway did not return an approval URL.');
  }
  const providerSessionId = payload.providerSessionId === undefined ? '' : payload.providerSessionId.trim();
  return paypalGooglePayCheckout(result, checkoutUrl, providerSessionId);
}

async function capturePayPalGatewayPayment(result: PaymentValidationResult, orderId: string, baseEndpoint: string): Promise<PaymentValidationResult> {
  const response = await postJsonText(baseEndpoint + '/api/payment/paypal/capture', stripeGatewayHeaders(), JSON.stringify({
    providerSessionId: orderId
  }));
  let payload: StripeCheckoutGatewayPayload;
  try {
    payload = JSON.parse(response.text) as StripeCheckoutGatewayPayload;
  } catch (_error) {
    return paymentBlocked(result, 'PayPal capture gateway response was not valid JSON.');
  }
  if (!isHttpSuccess(response) || payload.ok !== true) {
    return paymentBlocked(result, payload.error === undefined ? ('PayPal capture gateway failed with HTTP ' + response.code.toString() + '.') : payload.error);
  }
  return paymentResultWithState(result, 'completed', 'PayPal capture completed.', '', orderId);
}

async function createPayPalAccessToken(): Promise<PayPalAccessTokenResult> {
  if (localProviderConfig.paypalClientId.length === 0 || localProviderConfig.paypalClientSecret.length === 0) {
    return {
      accessToken: '',
      error: 'Missing PayPal credentials. Set PAYPAL_CLIENT_ID and PAYPAL_CLIENT_SECRET in the provider config.'
    };
  }
  const environment = paypalEnvironmentFromConfig();
  const tokenRequest = buildPayPalTokenRequest({
    environment: environment,
    clientId: localProviderConfig.paypalClientId,
    clientSecret: localProviderConfig.paypalClientSecret
  });
  const tokenHeaders: HttpRequestHeaders = {
    'Authorization': tokenRequest.headers.Authorization,
    'Content-Type': 'application/x-www-form-urlencoded',
    'Accept': tokenRequest.headers.Accept
  };
  let tokenResponse: HttpTextResponse;
  try {
    tokenResponse = await postPayPalTextWithRetry('token request', tokenRequest.url, tokenHeaders, tokenRequest.body);
  } catch (error) {
    return { accessToken: '', error: 'PayPal token request failed: ' + describeThrown(error) };
  }
  if (!isHttpSuccess(tokenResponse)) {
    return { accessToken: '', error: providerFailure('PayPal', 'token request', tokenResponse) };
  }
  let tokenPayload: PayPalTokenResponsePayload;
  try {
    tokenPayload = JSON.parse(tokenResponse.text) as PayPalTokenResponsePayload;
  } catch (_error) {
    return { accessToken: '', error: 'PayPal token response was not valid JSON.' };
  }
  const accessToken = tokenPayload.access_token === undefined ? '' : tokenPayload.access_token.trim();
  if (accessToken.length === 0) {
    return { accessToken: '', error: 'PayPal token response did not include access_token.' };
  }
  return { accessToken: accessToken, error: '' };
}

async function createPayPalCheckout(result: PaymentValidationResult): Promise<PaymentValidationResult> {
  const gatewayEndpoint = paypalGatewayBaseEndpoint();
  if (gatewayEndpoint.length > 0) {
    return createPayPalGatewayCheckout(result, gatewayEndpoint);
  }
  const token = await createPayPalAccessToken();
  if (token.error.length > 0) {
    return paymentBlocked(result, token.error);
  }
  const environment = paypalEnvironmentFromConfig();
  const orderRequest = buildPayPalOrderRequest({
    environment: environment,
    accessToken: token.accessToken,
    amountText: paymentAmountForProvider(result),
    currency: result.currency,
    payeeEmail: result.paypalEmail,
    payeeMerchantId: result.paypalMerchantId,
    returnUrl: localProviderConfig.paypalReturnUrl,
    cancelUrl: localProviderConfig.paypalCancelUrl,
    note: result.note
  });
  const orderHeaders: HttpRequestHeaders = {
    'Authorization': orderRequest.headers.Authorization,
    'Content-Type': 'application/json',
    'Accept': orderRequest.headers.Accept
  };
  let orderResponse: HttpTextResponse;
  try {
    orderResponse = await postPayPalTextWithRetry('order create', orderRequest.url, orderHeaders, orderRequest.body);
  } catch (error) {
    return paymentBlocked(result, 'PayPal order create failed: ' + describeThrown(error));
  }
  if (!isHttpSuccess(orderResponse)) {
    return paymentBlocked(result, providerFailure('PayPal', 'order create', orderResponse));
  }
  const approvalUrl = paypalApprovalUrlFromOrder(orderResponse.text);
  if (approvalUrl.length === 0) {
    return paymentBlocked(result, 'PayPal order response did not include an approve URL.');
  }
  return paypalGooglePayCheckout(result, approvalUrl, jsonStringField(orderResponse.text, 'id'));
}

async function capturePayPalPayment(result: PaymentValidationResult, orderId: string): Promise<PaymentValidationResult> {
  const cleanedOrderId = orderId.trim();
  if (cleanedOrderId.length === 0) {
    return paymentBlocked(result, 'Missing PayPal order id for capture.');
  }
  const gatewayEndpoint = paypalGatewayBaseEndpoint();
  if (gatewayEndpoint.length > 0) {
    return capturePayPalGatewayPayment(result, cleanedOrderId, gatewayEndpoint);
  }
  const token = await createPayPalAccessToken();
  if (token.error.length > 0) {
    return paymentBlocked(result, token.error);
  }
  const captureRequest = buildPayPalCaptureRequest({
    environment: paypalEnvironmentFromConfig(),
    accessToken: token.accessToken,
    orderId: cleanedOrderId
  });
  const captureHeaders: HttpRequestHeaders = {
    'Authorization': captureRequest.headers.Authorization,
    'Content-Type': 'application/json',
    'Accept': captureRequest.headers.Accept
  };
  let captureResponse: HttpTextResponse;
  try {
    captureResponse = await postPayPalTextWithRetry('order capture', captureRequest.url, captureHeaders, captureRequest.body);
  } catch (error) {
    return paymentBlocked(result, 'PayPal order capture failed: ' + describeThrown(error));
  }
  if (!isHttpSuccess(captureResponse)) {
    return paymentBlocked(result, providerFailure('PayPal', 'order capture', captureResponse));
  }
  return paymentResultWithState(result, 'completed', 'PayPal capture completed.', '', cleanedOrderId);
}

function stripeCheckoutGatewayEndpoint(): string {
  let endpoint = localProviderConfig.stripeCheckoutGatewayUrl.trim();
  if (endpoint.length === 0) {
    return '';
  }
  while (endpoint.endsWith('/')) {
    endpoint = endpoint.substring(0, endpoint.length - 1);
  }
  if (endpoint.endsWith('/api/payment/stripe/checkout')) {
    return endpoint;
  }
  return endpoint + '/api/payment/stripe/checkout';
}

function stripeGatewayHeaders(): HttpRequestHeaders {
  const headers: HttpRequestHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  };
  if (localProviderConfig.toolGatewayApiKey.length > 0) {
    headers.Authorization = 'Bearer ' + localProviderConfig.toolGatewayApiKey;
  }
  return headers;
}

async function createStripeGatewayCheckout(result: PaymentValidationResult, endpoint: string): Promise<PaymentValidationResult> {
  const response = await postJsonText(endpoint, stripeGatewayHeaders(), JSON.stringify({
    connectedAccountId: result.stripeAccountId,
    amountMinor: result.amountMinor,
    currency: result.currency,
    merchantName: result.displayName,
    successUrl: localProviderConfig.stripeSuccessUrl,
    cancelUrl: localProviderConfig.stripeCancelUrl,
    idempotencyKey: paymentIdempotencyKey(result),
    note: result.note,
    fundingSource: result.fundingSource
  }));
  let payload: StripeCheckoutGatewayPayload;
  try {
    payload = JSON.parse(response.text) as StripeCheckoutGatewayPayload;
  } catch (_error) {
    return paymentBlocked(result, 'Stripe checkout gateway response was not valid JSON.');
  }
  if (!isHttpSuccess(response) || payload.ok !== true) {
    return paymentBlocked(result, payload.error === undefined ? ('Stripe checkout gateway failed with HTTP ' + response.code.toString() + '.') : payload.error);
  }
  const checkoutUrl = payload.checkoutUrl === undefined ? '' : payload.checkoutUrl.trim();
  if (!checkoutUrl.startsWith('https://checkout.stripe.com/')) {
    return paymentBlocked(result, 'Stripe checkout gateway did not return a hosted Checkout URL.');
  }
  const providerSessionId = payload.providerSessionId === undefined ? '' : payload.providerSessionId.trim();
  return paymentCheckout(result, checkoutUrl, providerSessionId);
}

async function createStripeCheckout(result: PaymentValidationResult): Promise<PaymentValidationResult> {
  if (result.targetType === 'stripe_payment_link') {
    if (!isStripePaymentLinkUrl(result.stripePaymentLinkUrl)) {
      return paymentBlocked(result, 'Stripe Payment Link URL is not valid.');
    }
    return paymentCheckout(result, result.stripePaymentLinkUrl, '');
  }
  const gatewayEndpoint = stripeCheckoutGatewayEndpoint();
  if (gatewayEndpoint.length > 0) {
    return createStripeGatewayCheckout(result, gatewayEndpoint);
  }
  if (localProviderConfig.stripeSecretKey.length === 0) {
    return paymentBlocked(result, 'Missing Stripe secret key. Set STRIPE_SECRET_KEY in the provider config.');
  }
  const checkoutRequest = buildStripeCheckoutSessionRequest({
    secretKey: localProviderConfig.stripeSecretKey,
    connectedAccountId: result.stripeAccountId,
    amountMinor: result.amountMinor,
    currency: result.currency,
    merchantName: result.displayName,
    successUrl: localProviderConfig.stripeSuccessUrl,
    cancelUrl: localProviderConfig.stripeCancelUrl,
    idempotencyKey: paymentIdempotencyKey(result),
    note: result.note,
    fundingSource: result.fundingSource
  });
  const response = await postFormText(checkoutRequest.url, {
    'Authorization': checkoutRequest.headers.Authorization,
    'Content-Type': checkoutRequest.headers.ContentType,
    'Idempotency-Key': checkoutRequest.headers.IdempotencyKey
  }, checkoutRequest.body);
  if (!isHttpSuccess(response)) {
    return paymentBlocked(result, providerFailure('Stripe', 'Checkout Session create', response));
  }
  const checkoutUrl = stripeCheckoutUrlFromResponse(response.text);
  if (checkoutUrl.length === 0) {
    return paymentBlocked(result, 'Stripe Checkout Session response did not include a checkout URL.');
  }
  return paymentCheckout(result, checkoutUrl, jsonStringField(response.text, 'id'));
}

function stripeReceivingProfileRecordFromValue(value: Object | string | number | boolean | null | undefined): Record<string, Object | string | number | boolean | null | undefined> {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return JSON.parse('{}') as Record<string, Object | string | number | boolean | null | undefined>;
  }
  return value as Record<string, Object | string | number | boolean | null | undefined>;
}

function stripeReceivingStatusFromText(value: string, fallback: StripeReceivingAccountStatus): StripeReceivingAccountStatus {
  if (value === 'not_created' || value === 'onboarding_required' || value === 'pending_review' ||
    value === 'receivable' || value === 'blocked' || value === 'config_missing') {
    return value;
  }
  return fallback;
}

function applyStripeReceivingProfileRecord(profile: StripeReceivingProfile, record: Record<string, Object | string | number | boolean | null | undefined>): void {
  const agentId = textOf(record.agentId).trim();
  const deviceId = textOf(record.deviceId).trim();
  const displayName = textOf(record.displayName).trim();
  const email = textOf(record.email).trim();
  const country = textOf(record.country).trim().toUpperCase();
  const businessType = textOf(record.businessType).trim();
  const stripeAccountId = textOf(record.stripeAccountId).trim();
  const status = textOf(record.status).trim();
  profile.agentId = agentId.length > 0 ? agentId : profile.agentId;
  profile.deviceId = deviceId.length > 0 ? deviceId : profile.deviceId;
  profile.displayName = displayName.length > 0 ? displayName : profile.displayName;
  profile.email = email.length > 0 ? email : profile.email;
  profile.country = country.length > 0 ? country : profile.country;
  profile.businessType = businessType.length > 0 ? businessType : profile.businessType;
  profile.stripeAccountId = stripeAccountId.length > 0 ? stripeAccountId : profile.stripeAccountId;
  profile.status = stripeReceivingStatusFromText(status, profile.status);
}

function stripeReceivingProfileFromConfig(args: Object | null): StripeReceivingProfile {
  const profile = blankStripeReceivingProfile();
  profile.agentId = 'agent_phone_owner';
  profile.deviceId = 'phone_local_device';
  profile.displayName = 'My Agent';
  profile.country = 'US';
  if (localProviderConfig.stripeReceivingAgentJson.length > 0) {
    try {
      applyStripeReceivingProfileRecord(profile, stripeReceivingProfileRecordFromValue(JSON.parse(localProviderConfig.stripeReceivingAgentJson) as Object));
    } catch (error) {
      aiLogError('[AIPhone][StripeReceivingProfile] ' + describeThrown(error));
    }
  }
  if (args !== null) {
    applyStripeReceivingProfileRecord(profile, stripeReceivingProfileRecordFromValue(args));
  }
  return profile;
}

function stripeReceivingProfileJson(profile: StripeReceivingProfile): string {
  return JSON.stringify({
    agentId: profile.agentId,
    deviceId: profile.deviceId,
    displayName: profile.displayName,
    email: profile.email,
    country: profile.country,
    businessType: profile.businessType,
    stripeAccountId: profile.stripeAccountId,
    status: profile.status
  });
}

export function configureLocalStripeReceivingAgentJson(rawJson: string): void {
  const profile = stripeReceivingProfileFromConfig(null);
  const raw = rawJson.trim();
  if (raw.length > 0) {
    try {
      applyStripeReceivingProfileRecord(profile, stripeReceivingProfileRecordFromValue(JSON.parse(raw) as Object));
    } catch (error) {
      aiLogError('[AIPhone][StripeReceivingProfile] saved profile parse failed: ' + describeThrown(error));
    }
  }
  localProviderConfig.stripeReceivingAgentJson = stripeReceivingProfileJson(profile);
}

function stripeReceivingCard(profile: StripeReceivingProfile, status: string, message: string, onboardingUrl: string = '', currentlyDue: string[] = []): StripeReceivingAccountCardData {
  return {
    status: status,
    title: 'Stripe 收款账户',
    message: message,
    agentId: profile.agentId,
    deviceId: profile.deviceId,
    displayName: profile.displayName,
    email: profile.email,
    country: profile.country,
    businessType: profile.businessType,
    stripeAccountId: profile.stripeAccountId,
    onboardingUrl: onboardingUrl,
    currentlyDue: currentlyDue.slice(),
    actions: []
  };
}

function stripeReceivingSetupCard(profile: StripeReceivingProfile): StripeReceivingAccountCardData {
  const validation = validateStripeReceivingProfile(profile);
  const message = validation.ok ?
    '为 ' + profile.displayName + ' 创建 Stripe Connect 收款账户。Stripe 会负责实名、税务和银行卡信息收集。' :
    '请先配置 agent 收款资料：' + validation.reason;
  return stripeReceivingCard(profile, profile.stripeAccountId.length > 0 ? profile.status : 'not_created', message);
}

function stripeReceivingConfigMissingCard(profile: StripeReceivingProfile, message: string): StripeReceivingAccountCardData {
  return stripeReceivingCard(profile, 'config_missing', message);
}

function stripeReceivingBlockedCard(profile: StripeReceivingProfile, message: string): StripeReceivingAccountCardData {
  return stripeReceivingCard(profile, 'blocked', message);
}

function stripeReceivingOnboardingCard(profile: StripeReceivingProfile, onboardingUrl: string): StripeReceivingAccountCardData {
  return stripeReceivingCard(profile, 'onboarding_required', 'Stripe 收款账户已创建。请继续 Stripe 托管认证，完成实名、税务和银行卡资料。', onboardingUrl);
}

function stripeReceivingStatusCard(profile: StripeReceivingProfile, payload: StripeReceivingAccountStatusPayload): StripeReceivingAccountCardData {
  const summary = mapStripeReceivingStatus(payload);
  profile.stripeAccountId = payload.stripeAccountId.length > 0 ? payload.stripeAccountId : profile.stripeAccountId;
  profile.status = summary.status;
  return stripeReceivingCard(profile, summary.status, summary.message, '', payload.currentlyDue);
}

async function callLocalStripeReceivingTool(_prompt: string, surfaceId: string, actionId: string, args: Object | null = null): Promise<string> {
  const profile = stripeReceivingProfileFromConfig(args);
  if (localProviderConfig.stripeSecretKey.length === 0) {
    return stripeReceivingAccountA2ui(surfaceId, stripeReceivingConfigMissingCard(profile, '缺少 Stripe secret key。请先把 STRIPE_TEST_SECRET_KEY 或 STRIPE_LIVE_SECRET_KEY 同步进 HAP；AIPhone 不会模拟收款账户创建成功。'));
  }
  if (actionId === 'stripe.account.create') {
    const validation = validateStripeReceivingProfile(profile);
    if (!validation.ok) {
      return stripeReceivingAccountA2ui(surfaceId, stripeReceivingBlockedCard(profile, validation.reason));
    }
    const created = await stripeConnectAccountCreator(localProviderConfig.stripeSecretKey, profile);
    if (!created.ok) {
      return stripeReceivingAccountA2ui(surfaceId, stripeReceivingBlockedCard(profile, created.error));
    }
    profile.stripeAccountId = created.stripeAccountId;
    profile.status = 'onboarding_required';
  }
  if (actionId === 'stripe.account.create' || actionId === 'stripe.account.onboard') {
    if (profile.stripeAccountId.length === 0) {
      return stripeReceivingAccountA2ui(surfaceId, stripeReceivingBlockedCard(profile, '缺少 Stripe connected account id。'));
    }
    const linkRequest: StripeConnectAccountIdRequest = { stripeAccountId: profile.stripeAccountId };
    const link = await stripeConnectOnboardingLinkCreator(localProviderConfig.stripeSecretKey, linkRequest, localProviderConfig.stripeConnectReturnUrl, localProviderConfig.stripeConnectRefreshUrl);
    if (!link.ok) {
      return stripeReceivingAccountA2ui(surfaceId, stripeReceivingBlockedCard(profile, link.error));
    }
    return stripeReceivingAccountA2ui(surfaceId, stripeReceivingOnboardingCard(profile, link.url));
  }
  if (profile.stripeAccountId.length > 0 && actionId === 'stripe.account.refresh') {
    const statusRequest: StripeConnectAccountIdRequest = { stripeAccountId: profile.stripeAccountId };
    const status = await stripeConnectStatusFetcher(localProviderConfig.stripeSecretKey, statusRequest);
    if (!status.ok) {
      return stripeReceivingAccountA2ui(surfaceId, stripeReceivingBlockedCard(profile, status.error));
    }
    return stripeReceivingAccountA2ui(surfaceId, stripeReceivingStatusCard(profile, status.payload));
  }
  return stripeReceivingAccountA2ui(surfaceId, stripeReceivingSetupCard(profile));
}

async function callLocalPaymentTool(_toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  const book = paymentAccountBookFromConfig();
  const policy = paymentPolicyFromConfig();
  const draft = paymentDraftFromArgs(prompt, args, book);
  const validation = validatePaymentRequest(draft, book, policy);
  const phase = draft.phase === undefined ? '' : draft.phase;
  if (phase === 'cancel') {
    return paymentCancelledA2ui(surfaceId, validation);
  }
  if (phase === 'capture') {
    const parsed = paymentArgs(args);
    if (validation.status !== 'confirm' || validation.targetType !== 'paypal') {
      return paymentValidationA2ui(surfaceId, paymentBlocked(validation, 'PayPal capture requires a confirmed PayPal payment target.'));
    }
    return paymentValidationA2ui(surfaceId, await capturePayPalPayment(validation, paymentArgText(parsed, 'providerSessionId')));
  }
  if (phase !== 'confirm') {
    return paymentValidationA2ui(surfaceId, validation);
  }
  if (validation.status !== 'confirm') {
    return paymentValidationA2ui(surfaceId, validation);
  }
  let checkout: PaymentValidationResult;
  if (validation.targetType === 'paypal') {
    checkout = await createPayPalCheckout(validation);
  } else if (validation.targetType === 'stripe_connected' || validation.targetType === 'stripe_payment_link') {
    checkout = await createStripeCheckout(validation);
  } else {
    checkout = paymentBlocked(validation, 'Payment target is not executable.');
  }
  return paymentValidationA2ui(surfaceId, checkout);
}

function hotelMcpRegistration(toolId: string, mcpToolName: string): DynamicToolRegistration {
  return {
    toolId: toolId,
    manifestId: 'rollinggo-hotel',
    displayName: 'RollingGo',
    status: 'enabled',
    transport: {
      type: 'streamable_http',
      url: localProviderConfig.hotelMcpUrl,
      command: '',
      args: [],
      headers: {},
      env: {}
    },
    mcpToolName: mcpToolName,
    credentialRef: 'provider:rollinggo-hotel',
    sourceUrl: '',
    lastError: ''
  };
}

function hotelDataError(
  toolId: string,
  outputSchema: string,
  code: string,
  message: string,
  sources: DataSource[] = [],
  retryable: boolean = false
): DataResult {
  return errorDataResult(toolId, outputSchema, code, message, retryable, sources);
}

function hotelDataSource(operation: string): DataSource {
  return {
    provider: 'RollingGo',
    backend: 'local_adapter',
    operation: operation,
    fetchedAt: hotelTimestampProvider()
  };
}

function sanitizedHotelTransportMessage(message: string): string {
  let sanitized = message.length > 0 ? message : 'RollingGo transport exception.';
  if (localProviderConfig.hotelMcpKey.length > 0) {
    sanitized = sanitized.split(localProviderConfig.hotelMcpKey).join('[REDACTED]');
  }
  if (localProviderConfig.hotelMcpUrl.length > 0) {
    sanitized = sanitized.split(localProviderConfig.hotelMcpUrl).join('[REDACTED]');
  }
  return sanitized.substring(0, 1200);
}

function logRollingGoHotelResponse(operation: string, result: DataResult): void {
  aiLogInfo('[AIPhone][RollingGoHotelResponse] operation=' + operation +
    ' provider=RollingGo status=' + result.status +
    ' sources=' + result.sources.length.toString());
}

export async function callStructuredHotelTool(toolId: string, args: Object | null): Promise<DataResult> {
  if (toolId !== 'hotel.search' && toolId !== 'hotel.detail') {
    return hotelDataError(toolId, '', 'HOTEL_TOOL_UNSUPPORTED', 'Unsupported hotel tool: ' + toolId + '.');
  }
  if (localProviderConfig.hotelMcpKey.length === 0 || localProviderConfig.hotelMcpUrl.length === 0) {
    return hotelDataError(
      toolId,
      toolId === 'hotel.search' ? 'hotelSearchResults' : 'hotelRatePlans',
      'HOTEL_CONFIG_MISSING',
      '缺少本机 ignored 配置 ROLLINGGO_HOTEL_MCP_KEY 或 ROLLINGGO_HOTEL_MCP_URL。'
    );
  }
  const rawArgs = args === null ? new Object() : args;
  if (toolId === 'hotel.search') {
    const parsed: HotelSearchParseResult = parseHotelSearchRequest(rawArgs);
    if (!parsed.ok || parsed.value === null) {
      return hotelDataError(toolId, 'hotelSearchResults', 'HOTEL_INVALID_ARGUMENTS', parsed.error);
    }
    const operation = 'searchHotels';
    try {
      aiLogInfo('[AIPhone][RollingGoHotelRequest] operation=' + operation);
      const response: McpToolCallResult = await hotelMcpClient.callToolPayload(
        hotelMcpRegistration(toolId, operation),
        localProviderConfig.hotelMcpKey,
        hotelSearchProviderArgs(parsed.value)
      );
      const source = hotelDataSource(operation);
      if (!response.ok || response.result === null) {
        const failure = hotelDataError(toolId, 'hotelSearchResults', 'HOTEL_PROVIDER_TRANSPORT_ERROR', response.errorMessage, [source], true);
        logRollingGoHotelResponse(operation, failure);
        return failure;
      }
      const result = normalizeHotelSearchResult(response.result, parsed.value);
      const dataResult = hotelSearchDataResult(result, [source]);
      logRollingGoHotelResponse(operation, dataResult);
      return dataResult;
    } catch (error) {
      const message = sanitizedHotelTransportMessage(error instanceof Error ? error.message : JSON.stringify(error));
      const failure = hotelDataError(toolId, 'hotelSearchResults', 'HOTEL_TRANSPORT_EXCEPTION', message, [], true);
      logRollingGoHotelResponse(operation, failure);
      return failure;
    }
  }
  const parsed: HotelDetailParseResult = parseHotelDetailRequest(rawArgs);
  if (!parsed.ok || parsed.value === null) {
    return hotelDataError(toolId, 'hotelRatePlans', 'HOTEL_INVALID_ARGUMENTS', parsed.error);
  }
  const operation = 'getHotelDetail';
  try {
    aiLogInfo('[AIPhone][RollingGoHotelRequest] operation=' + operation);
    const response: McpToolCallResult = await hotelMcpClient.callToolPayload(
      hotelMcpRegistration(toolId, operation),
      localProviderConfig.hotelMcpKey,
      hotelDetailProviderArgs(parsed.value)
    );
    const source = hotelDataSource(operation);
    if (!response.ok || response.result === null) {
      const failure = hotelDataError(toolId, 'hotelRatePlans', 'HOTEL_PROVIDER_TRANSPORT_ERROR', response.errorMessage, [source], true);
      logRollingGoHotelResponse(operation, failure);
      return failure;
    }
    const dataResult = hotelDetailDataResult(normalizeHotelDetailResult(response.result, parsed.value), [source]);
    logRollingGoHotelResponse(operation, dataResult);
    return dataResult;
  } catch (error) {
    const message = sanitizedHotelTransportMessage(error instanceof Error ? error.message : JSON.stringify(error));
    const failure = hotelDataError(toolId, 'hotelRatePlans', 'HOTEL_TRANSPORT_EXCEPTION', message, [], true);
    logRollingGoHotelResponse(operation, failure);
    return failure;
  }
}

async function callStructuredRideReadTool(toolId: string, args: Object | null): Promise<DataResult> {
  const results = await callStructuredRideReadResults(toolId, args);
  results.forEach((result: DynamicGenericToolResult) => {
    if (result.status === 'success' || result.status === 'empty') {
      result.providerPhase = 'execution';
      return;
    }
    const lower = result.sourceTag.toLowerCase();
    if ((lower.indexOf('滴滴') >= 0 && localProviderConfig.didiMcpKey.trim().length > 0) ||
      (lower.indexOf('高德') >= 0 && localProviderConfig.amapMcpKey.trim().length > 0)) {
      result.providerPhase = 'execution';
    }
  });
  return remainingReadStructuredDataResult(toolId, 'genericToolResults', results);
}

async function callStructuredLuckinStatus(args: Object | null): Promise<DataResult> {
  return remainingReadStructuredDataResult(
    'luckin.order.status',
    'genericToolResults',
    [await callStructuredLuckinStatusResult(args)]
  );
}

export async function callStructuredTool(
  toolId: string,
  prompt: string,
  args: Object | null
): Promise<DataResult> {
  if (toolId === 'dynamic.search') {
    return callStructuredDynamicTool(prompt, args);
  }
  const definition = toolDefinitionForToolId(toolId);
  const allowed = definition !== null && dataAgentToolDefinitions().some(
    (candidate: ToolDefinition): boolean => candidate.toolId === toolId
  );
  if (definition === null || !allowed) {
    return errorDataResult(
      toolId,
      definition === null ? '' : definition.outputSchema,
      'TOOL_NOT_ALLOWED',
      'DataAgent cannot execute ' + toolId + '.'
    );
  }
  if (toolId === 'hotel.search' || toolId === 'hotel.detail') {
    return callStructuredHotelTool(toolId, args);
  }
  if (toolId === 'travel.search') {
    return callStructuredTravelTool(prompt);
  }
  if (toolId === 'train.search') {
    return callStructuredTrainTool(prompt);
  }
  if (toolId === 'flight.search') {
    return callStructuredFlightTool(prompt);
  }
  if (toolId === 'food.search') {
    return callStructuredFoodTool(prompt, args);
  }
  if (toolId === 'maps.place.search' || toolId === 'maps.place.details') {
    return callStructuredMapsTool(toolId, prompt, mapsArgs(args));
  }
  if (toolId === 'media.video.search' || toolId === 'media.aggregate.search') {
    return callStructuredMediaTool(toolId, prompt, args);
  }
  if (toolId === 'youtube.video.search') {
    return callStructuredYouTubeVideoTool(prompt, args);
  }
  if (toolId === 'x.post.search') {
    return callStructuredXTool(toolId, prompt, args);
  }
  if (toolId === 'social.feed.search') {
    return callStructuredSocialHubTool(args);
  }
  if (toolId === 'social.community.search') {
    return callStructuredSocialCommunityTool(args);
  }
  if (toolId === 'mail.search') {
    return callStructuredMailSearch(prompt, args);
  }
  if (toolId === 'mail.thread.read') {
    return callStructuredMailThreadRead(toolId, args);
  }
  if (toolId === 'gmail.mail.search' || toolId === 'gmail.thread.read') {
    return callStructuredGmailReadTool(toolId, prompt, args);
  }
  if (toolId === 'youtube.mine.playlists' || toolId === 'youtube.mine.subscriptions') {
    return callStructuredYouTubeAccountTool(toolId, prompt, args);
  }
  if (toolId === 'calendar.events.search') {
    return callStructuredCalendarRead(prompt, args);
  }
  if (toolId === 'luckin.order.status') {
    return callStructuredLuckinStatus(args);
  }
  if (toolId === 'ride.estimate' || toolId === 'ride.app.link' || toolId === 'ride.driver.location') {
    return callStructuredRideReadTool(toolId, args);
  }
  return errorDataResult(
    toolId,
    definition.outputSchema,
    'STRUCTURED_ADAPTER_MISSING',
    'Structured adapter is not migrated for ' + toolId + '.'
  );
}

class CurrentHotelToolLookup implements ToolDefinitionLookup {
  find(toolId: string): ToolDefinition | null {
    return toolDefinitionForToolId(toolId);
  }
}

class RejectHotelSurfaceAction implements SurfaceActionAuthorizer {
  allows(
    _conversationId: string,
    _turnId: string,
    _surfaceId: string,
    _actionId: string,
    _args: Object
  ): boolean {
    return false;
  }
}

class RejectHotelClientAction implements ClientActionAuthorizer {
  allows(_actionId: string, _args: Object): boolean {
    return false;
  }
}

class CurrentHotelArgsValidator implements ActionArgsValidator {
  validate(actionId: string, args: Object): ActionValidationResult {
    return validateHotelActionArgs(actionId, args);
  }
}

const LEGACY_HOTEL_ACTION_CATALOG: ActionCatalog = new ActionCatalog(
  new CurrentHotelToolLookup(),
  new RejectHotelSurfaceAction(),
  new RejectHotelClientAction(),
  new CurrentHotelArgsValidator()
);

function canPlaceLegacyHotelAction(sourceToolId: string, action: A2uiAction): boolean {
  return action.args !== undefined &&
    LEGACY_HOTEL_ACTION_CATALOG.validatePlacement(sourceToolId, action.id, action.args).ok;
}

async function callLocalHotelTool(toolId: string, surfaceId: string, args: Object | null): Promise<string> {
  if (toolId !== 'hotel.search' && toolId !== 'hotel.detail') {
    return hotelFailureA2ui(surfaceId, toolId, 'Unsupported hotel tool: ' + toolId + '.');
  }
  const result = await callStructuredHotelTool(toolId, args);
  if (result.error?.code === 'HOTEL_TRANSPORT_EXCEPTION') {
    throw new Error(result.error.message);
  }
  if (toolId === 'hotel.search' && result.status !== 'error') {
    return hotelSearchA2ui(
      surfaceId,
      result.data as HotelSearchResult,
      (action: A2uiAction): boolean => canPlaceLegacyHotelAction('hotel.search', action)
    );
  }
  if (toolId === 'hotel.detail' && result.status !== 'error') {
    return hotelDetailA2ui(
      surfaceId,
      result.data as HotelDetailResult,
      (action: A2uiAction): boolean => canPlaceLegacyHotelAction('hotel.detail', action)
    );
  }
  return hotelFailureA2ui(surfaceId, toolId, result.error?.message === undefined ? '酒店供应商调用失败。' : result.error.message);
}

async function buildLocalToolJsonl(toolId: string, prompt: string, surfaceId: string, actionId: string, emitJsonl: LocalA2uiEmitter | null = null, args: Object | null = null): Promise<string> {
  if (toolId === 'whatsapp.message.send') {
    return callLocalWhatsAppTool(prompt, surfaceId, actionId, args);
  }
  if (isCalendarToolId(toolId)) {
    return callLocalCalendarTool(toolId, prompt, surfaceId, actionId, args);
  }
  if (isMapsToolId(toolId)) {
    return callLocalMapsTool(toolId, prompt, surfaceId, args);
  }
  if (isMailToolId(toolId)) {
    return callLocalMailTool(toolId, prompt, surfaceId, args);
  }
  if (isGmailToolId(toolId)) {
    return callLocalGmailTool(toolId, prompt, surfaceId, args);
  }
  if (isMediaToolId(toolId)) {
    return callLocalMediaTool(toolId, prompt, surfaceId, args);
  }
  if (isYouTubeToolId(toolId)) {
    return callLocalYouTubeTool(toolId, prompt, surfaceId, args);
  }
  if (isSocialHubToolId(toolId)) {
    return callLocalSocialHubTool(toolId, prompt, surfaceId, args);
  }
  if (toolId === 'x.post.search') {
    return callLocalXTool(toolId, prompt, surfaceId, args);
  }
  if (toolId === 'payment.account.setup') {
    return callLocalStripeReceivingTool(prompt, surfaceId, actionId, args);
  }
  if (isPaymentToolId(toolId)) {
    return callLocalPaymentTool(toolId, prompt, surfaceId, args);
  }
  if (isRideToolId(toolId)) {
    return callLocalRideTool(toolId, prompt, surfaceId, actionId, args);
  }
  if (isLuckinToolId(toolId)) {
    return callLocalLuckinTool(toolId, prompt, surfaceId, actionId, args);
  }
  if (isHotelToolId(toolId) || toolId.startsWith('hotel.')) {
    return callLocalHotelTool(toolId, surfaceId, args);
  }
  if (toolId === 'travel.search') {
    return callLocalTravelSearch(prompt, surfaceId);
  }
  if (toolId === 'flight.search') {
    return callLocalFlightSearch(prompt, surfaceId);
  }
  if (toolId === 'train.search') {
    return callLocalTrainSearch(prompt, surfaceId);
  }
  if (toolId === 'food.search') {
    return callLocalFoodSearch(prompt, surfaceId, emitJsonl, args);
  }
  return buildDynamicToolJsonl(toolId, prompt, surfaceId, args);
}

async function callLocalTool(toolId: string, prompt: string, surfaceId: string, actionId: string, onSurface: A2uiSurfaceCallback, initialSurface: A2uiSurfaceState | null = null, args: Object | null = null): Promise<A2uiCallResult> {
  const store = new A2uiSurfaceStore();
  if (initialSurface !== null) {
    store.seed(initialSurface);
  }
  let rawResponse = '';
  const throttleMs = toolId === 'food.search' ? localToolDebugConfig.foodPartialThrottleMs : 0;
  const surfaceThrottle = new A2uiSurfaceThrottle(throttleMs, (surface: A2uiSurfaceState, raw: string) => {
    aiLogInfo('[AIPhone][LocalToolSurfaceThrottleEmit] intervalMs=' + throttleMs.toString() +
      ' sequence=' + surface.sequence.toString() + ' status=' + surface.status);
    onSurface(surface, raw);
  });
  const emitJsonl = (jsonl: string, immediate: boolean = false): void => {
    if (jsonl.length === 0 || streamError.length > 0) {
      return;
    }
    rawResponse += jsonl;
    const emitted = parseA2uiJsonl(jsonl);
    if (emitted.error.length > 0) {
      streamError = emitted.error;
      aiLogError('[AIPhone][LocalToolEmitParseError] ' + emitted.error);
      return;
    }
    const applyError = applyEnvelopes(store, emitted.envelopes);
    if (applyError.length > 0) {
      streamError = applyError;
      aiLogError('[AIPhone][LocalToolEmitApplyError] ' + applyError);
      return;
    }
    const surface = store.getSurface();
    if (immediate) {
      onSurface(surface, rawResponse);
    } else {
      surfaceThrottle.enqueue(surface, rawResponse);
    }
  };
  const localDebugBody: ToolGatewayRequestBody = {
    toolId: toolId,
    prompt: prompt,
    surfaceId: surfaceId,
    actionId: actionId,
    stream: false,
    a2uiClientCapabilities: defaultA2uiCapabilities()
  };
  if (args !== null) {
    localDebugBody.args = args;
  }
  const localDebugPayload: ToolRequestDebug = {
    endpoint: LOCAL_TOOL_GATEWAY_URL,
    body: localDebugBody
  };
  const requestDebug = JSON.stringify(localDebugPayload);
  aiLogInfo('[AIPhone][LocalToolRequest] endpoint=' + LOCAL_TOOL_GATEWAY_URL + ' toolId=' + toolId + ' surfaceId=' + surfaceId + ' promptChars=' + prompt.length.toString());
  const pending = pendingA2ui(toolId, prompt, surfaceId);
  let parsed = parseA2uiJsonl(pending);
  let streamError = parsed.error;
  if (streamError.length === 0) {
    emitJsonl(pending, true);
  }

  try {
    const resultJsonl = await buildLocalToolJsonl(toolId, prompt, surfaceId, actionId, emitJsonl, args);
    emitJsonl(resultJsonl);
    surfaceThrottle.flush();
    aiLogInfo('[AIPhone][LocalToolResult] ok=' + (streamError.length === 0 ? 'true' : 'false') + ' rawChars=' + rawResponse.length.toString());
    return {
      ok: streamError.length === 0,
      raw: rawResponse,
      error: streamError,
      requestDebug: requestDebug,
      assistantDebug: '',
      surface: store.getSurface()
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    aiLogError('[AIPhone][LocalToolException] ' + message);
    const exceptionJsonl = legacyToolExceptionA2ui(surfaceId, toolId, message);
    rawResponse += exceptionJsonl;
    parsed = parseA2uiJsonl(exceptionJsonl);
    streamError = parsed.error.length > 0 ? parsed.error : applyEnvelopes(store, parsed.envelopes);
    surfaceThrottle.cancel();
    onSurface(store.getSurface(), rawResponse);
    return {
      ok: streamError.length === 0,
      raw: rawResponse,
      error: streamError,
      requestDebug: requestDebug,
      assistantDebug: '',
      surface: store.getSurface()
    };
  }
}

export async function callToolGateway(baseUrl: string, toolId: string, prompt: string, surfaceId: string, actionId: string, onSurface: A2uiSurfaceCallback, initialSurface: A2uiSurfaceState | null = null, args: Object | null = null): Promise<A2uiCallResult> {
  const endpoint = buildToolGatewayUrl(baseUrl);
  if (isLocalToolGatewayUrl(endpoint) ||
    (isCalendarWriteTool(toolId) && !calendarWriteActionAllowed(toolId, actionId))) {
    return callLocalTool(toolId, prompt, surfaceId, actionId, onSurface, initialSurface, args);
  }

  const request = http.createHttp();
  const store = new A2uiSurfaceStore();
  if (initialSurface !== null) {
    store.seed(initialSurface);
  }
  const decoder = util.TextDecoder.create('utf-8');
  let rawResponse = '';
  let remainder = '';
  let streamError = '';
  let envelopeCount = 0;
  let streamEndResolve: () => void = () => {};
  let streamEnded = false;
  const finishStream = (): void => {
    if (!streamEnded) {
      streamEnded = true;
      streamEndResolve();
    }
  };
  const streamEnd = new Promise<void>((resolve: () => void) => {
    streamEndResolve = resolve;
  });
  const body: ToolGatewayRequestBody = {
    toolId: toolId,
    prompt: prompt,
    surfaceId: surfaceId,
    actionId: actionId,
    stream: true,
    a2uiClientCapabilities: defaultA2uiCapabilities()
  };
  if (args !== null) {
    body.args = args;
  }
  const debugPayload: ToolRequestDebug = {
    endpoint: endpoint,
    body: body
  };
  const requestDebug = JSON.stringify(debugPayload);
  aiLogInfo('[AIPhone][ToolGatewayRequest] endpoint=' + endpoint + ' toolId=' + toolId + ' surfaceId=' + surfaceId + ' promptChars=' + prompt.length.toString());

  request.on('dataReceive', (data: ArrayBuffer) => {
    const chunk = decoder.decodeToString(new Uint8Array(data), { stream: true });
    rawResponse += chunk;
    aiLogInfo('[AIPhone][ToolGatewayChunk] chars=' + chunk.length.toString() + ' rawChars=' + rawResponse.length.toString());
    const parsed = parseA2uiJsonlChunk(chunk, remainder);
    remainder = parsed.remainder;
    if (parsed.error.length > 0) {
      streamError = parsed.error;
      aiLogError('[AIPhone][ToolGatewayParseError] ' + parsed.error);
    } else {
      envelopeCount += parsed.envelopes.length;
      const applyError = applyEnvelopes(store, parsed.envelopes);
      if (applyError.length > 0) {
        streamError = applyError;
        aiLogError('[AIPhone][ToolGatewayApplyError] ' + applyError);
      }
      if (parsed.envelopes.length > 0) {
        aiLogInfo('[AIPhone][ToolGatewayEnvelopes] count=' + parsed.envelopes.length.toString());
      }
      onSurface(store.getSurface(), rawResponse);
    }
  });
  request.on('dataEnd', () => {
    finishStream();
  });

  try {
    const responseCode = await request.requestInStream(endpoint, {
      method: http.RequestMethod.POST,
      header: createHeaders(),
      extraData: JSON.stringify(body),
      connectTimeout: 8000,
      readTimeout: 30000
    });
    aiLogInfo('[AIPhone][ToolGatewayResponse] code=' + responseCode.toString());
    finishStream();
    await streamEnd;
    aiLogInfo('[AIPhone][ToolGatewayEnd] rawChars=' + rawResponse.length.toString());

    if (responseCode < 200 || responseCode >= 300) {
      const error = 'HTTP ' + responseCode.toString() + ': ' + rawResponse;
      store.applyError('工具调用失败', error);
      return {
        ok: false,
        raw: rawResponse,
        error: error,
        requestDebug: requestDebug,
        assistantDebug: '',
        surface: store.getSurface()
      };
    }

    if (remainder.trim().length > 0 && streamError.length === 0) {
      const parsed = parseA2uiJsonlChunk('\n', remainder);
      remainder = parsed.remainder;
      if (parsed.error.length > 0) {
        streamError = parsed.error;
      } else {
        const applyError = applyEnvelopes(store, parsed.envelopes);
        if (applyError.length > 0) {
          streamError = applyError;
        }
      }
    }

    if (store.getSurface().components.length === 0 && rawResponse.length > 0 && streamError.length === 0) {
      const parsed = parseA2uiJsonl(rawResponse);
      if (parsed.error.length > 0) {
        streamError = parsed.error;
      } else {
        const applyError = applyEnvelopes(store, parsed.envelopes);
        if (applyError.length > 0) {
          streamError = applyError;
        }
      }
    }

    if (streamError.length > 0) {
      if (envelopeCount === 0) {
        store.applyError('工具返回格式异常', streamError);
      }
    }
    return {
      ok: streamError.length === 0,
      raw: rawResponse,
      error: streamError,
      requestDebug: requestDebug,
      assistantDebug: '',
      surface: store.getSurface()
    };
  } catch (error) {
    const message = JSON.stringify(error);
    aiLogError('[AIPhone][ToolGatewayException] endpoint=' + endpoint + ' error=' + message);
    store.applyError('工具调用异常', message);
    return {
      ok: false,
      raw: rawResponse,
      error: message,
      requestDebug: requestDebug,
      assistantDebug: '',
      surface: store.getSurface()
    };
  } finally {
    request.destroy();
  }
}

export function emptyToolGatewayResult(error: string): A2uiCallResult {
  return {
    ok: false,
    raw: '',
    error: error,
    requestDebug: '',
    assistantDebug: '',
    surface: emptyA2uiSurface()
  };
}
