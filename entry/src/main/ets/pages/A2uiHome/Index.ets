import {
  A2uiAgentRunner,
  ActionExecutionResult,
  ConversationTurnMessage,
  CurrentSurfaceSummary,
  LlmProvider,
  LocalModelSettings,
  OpenAiA2uiModel,
  OpenAiCompatibleModel,
  PaymentAccount,
  RuntimeOwner,
  StripeReceivingAccountCardData,
  UserInputPayload,
  defaultLocalModelSettings
} from '@loop/agent-core';
import { isRollingGoHotelBookingUrl } from '@loop/agent-core';
import router from '@ohos.router';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import fs from '@ohos.file.fs';
import { geoLocationManager } from '@kit.LocationKit';
import util from '@ohos.util';
import {
  A2UI_COMPONENT_SOCIAL_HUB,
  A2UI_COMPONENT_STRIPE_RECEIVING_ACCOUNT_CARD,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2uiAction,
  A2uiCallResult,
  A2uiComponent,
  A2uiDataValue,
  A2uiDynamicToolConnectData,
  A2uiFlightData,
  A2uiFoodData,
  A2uiGenericToolResultData,
  A2uiLabelValueData,
  A2uiMessage,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  A2uiTrainData,
  A2uiTravelOptionData
} from '@loop/agent-core';
import { stripeReceivingAccount } from '@loop/agent-core';
import {
  callDirectModel,
  DirectModelCallResult
} from '../../model/LocalModelClient';
import { GMAIL_MCP_AUTH_SETUP_URL, GMAIL_WEB_URL, GOOGLE_CALENDAR_WEB_URL, GOOGLE_OAUTH_SETUP_URL } from '@loop/agent-core';
import { A2uiSurfaceStore, createSeedA2uiSurface } from '@loop/agent-core';
import {
  emptySocialHubDraft,
  SocialHubConnectionData,
  SocialHubConnectionStatus,
  SocialHubDraftData,
  SocialHubItemData,
  SocialHubPlatform
} from '@loop/agent-core';
import { aiLogError, aiLogInfo } from '@loop/agent-core';
import {
  callToolGateway,
  COMPOSIO_USER_ID_PREFIX,
  ComposioAuthConfigItem,
  ComposioAuthProxyClient,
  configureDidiMcpSandboxForRuntime,
  configureComposioUserId,
  configureLocalPaymentAccountBookJson,
  configureLocalStripeReceivingAgentJson,
  configureLocalToolDebugConfig,
  currentComposioConfig,
  currentComposioUserId,
  defaultToolGatewayUrl,
  isRegisteredToolId,
  normalizeComposioUserId,
  prepareGmailOAuthAuthorizationUrl,
  prepareGoogleOAuthAuthorizationUrl,
  sendLocalSocialHubReply,
  shortComposioUserId
} from '@loop/agent-core';
import {
  NavigationCardSnapshot,
  NavigationCardSnapshotBuildResult,
  PreferencesNavigationCardSnapshotStore,
  buildNavigationCardBindingData,
  navigationCardSnapshotFromFlightOption,
  navigationCardSnapshotFromFoodOption,
  navigationCardSnapshotFromTrainOption,
  navigationCardSnapshotFromTravelOption
} from '@loop/agent-core';
import { AssetCredentialStore } from '@loop/agent-core';
import { buildSystemFoodNavigationUri } from '@loop/agent-core';
import { officialMediaVideoPlaybackUrl } from '@loop/agent-core';
import {
  MailDetail,
  MailCalendarSuggestion,
  MailReplyCommand,
  MailReplyOperationResult,
  addHuaweiCalendarEvent,
  saveConfiguredMailDraft,
  sendConfiguredMailReply
} from '@loop/agent-core';
import {
  copyPersonaData,
  leaderPersonaSurfaceUpdate
} from '../../model/PersonaA2ui';
import {
  mergePersonaStablePreference,
  PersonaMemoryUpdateRequest
} from '../../model/PersonaMemoryUpdate';
import { PreferencesPersonaPackStore } from '../../model/PersonaPreferencesStore';
import { allPersonaPacks, personaPackForId, resetPersonaPackText, updatePersonaPackText } from '../../model/PersonaStore';
import { PersonaPack } from '../../model/PersonaTypes';
import { startVoiceInputSession, VoiceInputResult, VoiceInputSession } from '../../model/VoiceInputBridge';
import { ComposioAuthPage } from './components/ComposioAuthPage';
import { HomePage } from './components/HomePage';
import {
  CheckoutWebKind,
  isAllowed12306BookingUrl
} from './components/CheckoutWebOverlay';
import { ConfigPage } from './components/ConfigPage';
import {
  HotelTurnStatus
} from './agent/HotelAgentRuntime';
import {
  MailDetailInPlaceEvent,
  MailDetailWriteLease,
  MultiAgentCanaryOptions,
  MultiAgentCanaryRuntime
} from './agent/MultiAgentCanaryRuntime';
import {
  MailDetailSuggestionGuard,
  MailDetailUiEvent,
  publishMailDetailThenSuggest
} from './agent/MailDetailInPlaceUpdater';
import {
  MultiAgentSettledOutcome,
  MultiAgentTurnOutcome
} from './agent/MultiAgentRuntimeTypes';
import { SystemUriOpener } from './agent/AiphoneRegisteredActionExecutor';
import {
  RegisteredPageSnapshot,
  RegisteredPageSnapshotStore,
  dispatchRegisteredPageActionCandidate
} from './agent/RegisteredPageActionRoute';
import {
  RegisteredPageActionHandler,
  RegisteredPageToolInvocation,
  RegisteredPageToolInvoker
} from './agent/RegisteredPageActionHandler';
import { RegisteredPageActionContext } from './agent/AiphoneRegisteredActionExecutor';
import { socialHubComposioToolkitCandidates } from './components/SocialHubViewData';
import { createHtmlHomeDocument } from './html/HtmlHomeSnapshot';
import { renderHtmlHomeDocument } from './html/HtmlHomeRenderer';
import { isHtmlHomeActionAllowed } from './html/HtmlHomeActionPolicy';
import { HtmlHomeAction, HtmlHomeBlock, HtmlHomeDocument } from './html/HtmlHomeTypes';
import {
  A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS,
  HTML_HOME_DEBUG_EXPORT_FILE_NAME,
  htmlHomeDebugExportJson,
  normalizeFoodPartialThrottleMs,
  normalizeFoodProviderDelayMs
} from './state/A2uiHomeDebugSettings';
import {
  ConnectionPanelState,
  createInitialConnectionPanelState,
  inputTextAfterPromptSubmit,
  runtimeCallbackIsCurrent,
  runtimeOwnerAllowsSurfaceAction,
  runtimeSurfaceIdentityMatches,
  shouldApplySurfaceUpdate,
  shouldShowQueryPendingSurface,
  shouldShowWelcome,
  updateConnectionPanelState,
  voiceInputTextAfterRecognition
} from './state/A2uiHomeState';
import {
  directPaymentToolIdForActionId,
  directRideToolIdForActionId
} from './render/A2uiHomeToolRequest';

const CONNECTION_TEST_PROMPT: string = '连接检查：请返回 A2UI v0.9.1 setup surface，说明 Local API 已可用。';
const TOOL_GATEWAY_URL: string = defaultToolGatewayUrl();
const initialConnectionState: ConnectionPanelState = createInitialConnectionPanelState();
const initialSurface: A2uiSurfaceState = createSeedA2uiSurface();
const LOG_SNIPPET_LIMIT: number = 1200;
const DEFAULT_INPUT_PLACEHOLDER: string = '告诉 Appless 你想完成什么';
const TRAIN_EDIT_QUERY_PLACEHOLDER: string = '请输入具体车站和时间，如：深圳北 18:00 后 到香港西九龙';
const NAVIGATION_CARD_TTL_MS: number = 60 * 60 * 1000;
const PAYMENT_ACCOUNT_STORE_NAME: string = 'aiphone_payment_account_store';
const PAYMENT_ACCOUNT_BOOK_KEY: string = 'payment_account_book';
const STRIPE_RECEIVING_PROFILE_KEY: string = 'stripe_receiving_profile';
const COMPOSIO_AUTH_STORE_NAME: string = 'aiphone_composio_auth_store';
const COMPOSIO_USER_ID_KEY: string = 'composio_user_id';
const ANYTHING_DEMO_ROUTE_URL: string = 'pages/A2uiHome/AnythingDemo';
const READ_CALENDAR_PERMISSION: Permissions = 'ohos.permission.READ_CALENDAR';
const WRITE_CALENDAR_PERMISSION: Permissions = 'ohos.permission.WRITE_CALENDAR';
const APPROX_LOCATION_PERMISSION: Permissions = 'ohos.permission.APPROXIMATELY_LOCATION';
const PRECISE_LOCATION_PERMISSION: Permissions = 'ohos.permission.LOCATION';

interface RegisteredPageToolObservation {
  result: A2uiCallResult | null;
}

function fingerprintPart(value: string): string {
  return value.length.toString() + ':' + value;
}

function opaqueSettingsDigest(value: string): string {
  let first = 0x811c9dc5;
  let second = 0x9e3779b9;
  for (let index = 0; index < value.length; index++) {
    const code = value.charCodeAt(index);
    first = Math.imul(first ^ code, 0x01000193);
    second = Math.imul(second ^ (code + index), 0x5bd1e995);
  }
  return (first >>> 0).toString(16) + '-' + (second >>> 0).toString(16);
}

export function hotelModelSettingsFingerprint(settings: LocalModelSettings): string {
  const material = fingerprintPart(settings.provider) + '|' +
    fingerprintPart(settings.baseUrl) + '|' +
    fingerprintPart(settings.apiKey) + '|' +
    fingerprintPart(settings.model) + '|' +
    fingerprintPart(settings.customParametersJson);
  return 'hotel-settings-v1:' + opaqueSettingsDigest(material);
}

export function hotelTurnReadyMessage(status: HotelTurnStatus, title: string): string {
  if (status === 'success') {
    return title + ' 已返回真实酒店结果。';
  }
  if (status === 'partial') {
    return title + ' 已返回部分酒店结果，请查看提示。';
  }
  if (status === 'empty') {
    return title + ' 查询完成，未找到符合条件的酒店。';
  }
  return '';
}

class PageHotelUriOpener implements SystemUriOpener {
  private readonly callback: (uri: string) => Promise<boolean>;

  constructor(callback: (uri: string) => Promise<boolean>) {
    this.callback = callback;
  }

  open(uri: string): Promise<boolean> {
    return this.callback(uri);
  }
}

class PageRegisteredToolInvoker implements RegisteredPageToolInvoker {
  private readonly callback: (
    toolId: string,
    prompt: string,
    pageActionId: string,
    args: Object
  ) => Promise<RegisteredPageToolInvocation>;

  constructor(callback: (
    toolId: string,
    prompt: string,
    pageActionId: string,
    args: Object
  ) => Promise<RegisteredPageToolInvocation>) {
    this.callback = callback;
  }

  invoke(
    toolId: string,
    prompt: string,
    pageActionId: string,
    args: Object
  ): Promise<RegisteredPageToolInvocation> {
    return this.callback(toolId, prompt, pageActionId, args);
  }
}

type RideActionArgValue = Object | string | number | boolean | null | undefined;

interface RideCachedProduct {
  productName: string;
  productCategory: string;
  priceText: string;
}

interface RideLocalOrderActionArgs {
  productCategory?: RideActionArgValue;
  product_category?: RideActionArgValue;
  productName?: RideActionArgValue;
  priceText?: RideActionArgValue;
  routeText?: RideActionArgValue;
  pickupLocation?: RideActionArgValue;
  originLocation?: RideActionArgValue;
  destinationLocation?: RideActionArgValue;
  estimateCacheJson?: RideActionArgValue;
  estimateTraceId?: RideActionArgValue;
  estimate_trace_id?: RideActionArgValue;
  traceId?: RideActionArgValue;
}

type HtmlActionValue = Object | string | number | boolean | null | undefined;

interface HtmlDynamicCredentialPayload {
  credentialRef?: HtmlActionValue;
  credentialValue?: HtmlActionValue;
  toolId?: HtmlActionValue;
  prompt?: HtmlActionValue;
}

interface MailCalendarUiEvent {
  sequence: number;
  requestKey: string;
  status: string;
  message: string;
  eventId: string;
  error: string;
}

interface MailCalendarActionArgs {
  requestKey?: HtmlActionValue;
  provider?: HtmlActionValue;
  threadId?: HtmlActionValue;
  messageId?: HtmlActionValue;
}

interface MailCalendarSuggestionSchemaText {
  isWorkRelated: string;
  hasMeeting: string;
  title: string;
  start: string;
  end: string;
  displayTime: string;
  timezone: string;
  location: string;
  description: string;
  confidence: string;
  reason: string;
}

interface MailReplyUiEvent {
  sequence: number;
  requestKey: string;
  operation: string;
  status: string;
  message: string;
  error: string;
}

interface MailReplyAiArgs {
  requestKey?: HtmlActionValue;
  provider?: HtmlActionValue;
  accountLabel?: HtmlActionValue;
  threadId?: HtmlActionValue;
  messageId?: HtmlActionValue;
  to?: HtmlActionValue;
  subject?: HtmlActionValue;
  replyMode?: HtmlActionValue;
  contextSummary?: HtmlActionValue;
}

interface HtmlPinPayload {
  index?: HtmlActionValue;
  id?: HtmlActionValue;
  source?: HtmlActionValue;
  trainCode?: HtmlActionValue;
  flightNo?: HtmlActionValue;
  name?: HtmlActionValue;
  address?: HtmlActionValue;
  location?: HtmlActionValue;
  distance?: HtmlActionValue;
  depart?: HtmlActionValue;
  depTime?: HtmlActionValue;
  from?: HtmlActionValue;
  to?: HtmlActionValue;
  dep?: HtmlActionValue;
  arr?: HtmlActionValue;
}

interface SocialHubReplyPayload {
  text?: HtmlActionValue;
}

interface PaymentCheckoutActionPayload {
  provider?: HtmlActionValue;
  recipient?: HtmlActionValue;
  amountText?: HtmlActionValue;
  currency?: HtmlActionValue;
  note?: HtmlActionValue;
  checkoutUrl?: HtmlActionValue;
  providerSessionId?: HtmlActionValue;
}

interface TrainBookingActionPayload {
  bookingUrl?: HtmlActionValue;
}

interface StripeOnboardingActionPayload {
  onboardingUrl?: HtmlActionValue;
}

interface StripeReceivingSavedProfile {
  agentId: string;
  deviceId: string;
  displayName: string;
  email: string;
  country: string;
  businessType: string;
  stripeAccountId: string;
  status: string;
}

interface HtmlPaymentAccountPayload {
  displayName?: HtmlActionValue;
  aliases?: HtmlActionValue;
  paypalEmail?: HtmlActionValue;
  paypalMerchantId?: HtmlActionValue;
  stripeAccountId?: HtmlActionValue;
  stripePaymentLinkUrl?: HtmlActionValue;
}

interface PaymentCaptureArgs {
  provider: string;
  recipient: string;
  amountText: string;
  currency: string;
  note: string;
  phase: string;
  providerSessionId: string;
}

interface PaymentSavedPreviewArgs {
  accountId: string;
  recipient: string;
  provider: string;
  originalQuery: string;
}

interface PaymentFallbackArgs {
  provider: string;
  fundingSource: string;
  recipient: string;
  amountText: string;
  currency: string;
  note: string;
  originalQuery: string;
}

interface LuckinOrderStatusArgs {
  orderId: string;
}

interface LocationPermissionResult {
  permissions: string[];
  authResults: number[];
}

function logSnippet(text: string): string {
  if (text.length <= LOG_SNIPPET_LIMIT) {
    return text;
  }
  return text.substring(0, LOG_SNIPPET_LIMIT) + '...<truncated>';
}

function modelPromptWithActionContext(prompt: string, actionId: string, args: Object | null): string {
  if (actionId.length === 0 && args === null) {
    return prompt;
  }
  return prompt + '\n\nAction ID: ' + actionId + '\nStructured action args JSON: ' +
    (args === null ? '{}' : JSON.stringify(args));
}

function stripMailReplyAiText(text: string): string {
  let value = text.trim();
  const finalAnswerIndex = value.lastIndexOf('final_answer:');
  if (finalAnswerIndex >= 0) {
    value = value.substring(finalAnswerIndex + 'final_answer:'.length).trim();
  }
  const finalIndex = value.lastIndexOf('Final:');
  if (finalIndex >= 0) {
    value = value.substring(finalIndex + 'Final:'.length).trim();
  }
  const modelIndex = value.lastIndexOf('MODEL:');
  if (modelIndex >= 0) {
    value = value.substring(modelIndex + 'MODEL:'.length).trim();
  }
  const errorIndex = value.indexOf('\nERROR:');
  if (errorIndex >= 0) {
    value = value.substring(0, errorIndex).trim();
  }
  if (value.startsWith('```')) {
    const firstBreak = value.indexOf('\n');
    const lastFence = value.lastIndexOf('```');
    if (firstBreak >= 0 && lastFence > firstBreak) {
      value = value.substring(firstBreak + 1, lastFence).trim();
    }
  }
  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith('“') && value.endsWith('”'))) {
    value = value.substring(1, value.length - 1).trim();
  }
  return value;
}

function jsonObjectTextFromModel(text: string): string {
  let value = text.trim();
  const finalAnswerIndex = value.lastIndexOf('final_answer:');
  if (finalAnswerIndex >= 0) {
    value = value.substring(finalAnswerIndex + 'final_answer:'.length).trim();
  }
  const finalIndex = value.lastIndexOf('Final:');
  if (finalIndex >= 0) {
    value = value.substring(finalIndex + 'Final:'.length).trim();
  }
  if (value.startsWith('```')) {
    const firstBreak = value.indexOf('\n');
    const lastFence = value.lastIndexOf('```');
    if (firstBreak >= 0 && lastFence > firstBreak) {
      value = value.substring(firstBreak + 1, lastFence).trim();
    }
  }
  const left = value.indexOf('{');
  const right = value.lastIndexOf('}');
  if (left >= 0 && right > left) {
    return value.substring(left, right + 1);
  }
  return value;
}

function calendarPermissionGranted(permissions: string[], authResults: number[]): boolean {
  if (authResults.length === 0) {
    return false;
  }
  const readIndex = permissions.indexOf(READ_CALENDAR_PERMISSION);
  const writeIndex = permissions.indexOf(WRITE_CALENDAR_PERMISSION);
  if (permissions.length === 0) {
    return authResults.length >= 2 && authResults[0] === 0 && authResults[1] === 0;
  }
  return readIndex >= 0 && writeIndex >= 0 &&
    authResults.length > readIndex && authResults.length > writeIndex &&
    authResults[readIndex] === 0 && authResults[writeIndex] === 0;
}

@Entry
@Component
struct Index {
  @State showConfigPage: boolean = false;
  @State showComposioAuthPage: boolean = false;
  @State showAdvancedSettings: boolean = false;
  @State showHistory: boolean = false;
  @State baseUrl: string = defaultLocalModelSettings().baseUrl;
  @State apiKey: string = defaultLocalModelSettings().apiKey;
  @State selectedModel: string = defaultLocalModelSettings().model;
  @State customParametersJson: string = defaultLocalModelSettings().customParametersJson;
  @State foodProviderDelayEnabled: boolean = false;
  @State foodProviderDelayMs: string = '0';
  @State foodPartialThrottleMs: string = A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS.toString();
  @State ignoreToolSurfaceUpdates: boolean = false;
  @State htmlHomeDebugExportEnabled: boolean = false;
  @State htmlHomeDebugExportPath: string = '';
  @State didiMcpSandboxEnabled: boolean = true;
  @State isBusy: boolean = false;
  @State connectionStatus: string = initialConnectionState.connectionStatus;
  @State connectionMessage: string = initialConnectionState.connectionMessage;
  @State lastModelRequest: string = initialConnectionState.lastModelRequest;
  @State lastModelOutput: string = initialConnectionState.lastModelOutput;
  @State lastError: string = initialConnectionState.lastError;
  @State refreshTick: number = initialConnectionState.refreshTick;
  @State currentSurface: A2uiSurfaceState = initialSurface;
  @State surfaceRenderTick: number = 0;
  @State isAwaitingFirstSurface: boolean = false;
  @State inputText: string = '';
  @State isVoiceListening: boolean = false;
  @State voiceInputMessage: string = '';
  @State showCheckoutWeb: boolean = false;
  @State checkoutWebKind: CheckoutWebKind = 'payment';
  @State checkoutWebUrl: string = '';
  @State paymentCheckoutProvider: string = '';
  @State paymentCheckoutProviderSessionId: string = '';
  @State paymentCheckoutRecipient: string = '';
  @State paymentCheckoutAmountText: string = '';
  @State paymentCheckoutCurrency: string = '';
  @State paymentCheckoutNote: string = '';
  @State inputPlaceholder: string = DEFAULT_INPUT_PLACEHOLDER;
  @State messages: A2uiMessage[] = [];
  @State personaPacks: PersonaPack[] = allPersonaPacks();
  @State selectedPersonaId: string = 'food_companion';
  @State personaSoulDraft: string = personaPackForId('food_companion').soul;
  @State personaMemoryDraft: string = personaPackForId('food_companion').memory;
  @State personaSaveMessage: string = '';
  @State composioUserId: string = '';
  @State composioAuthItems: ComposioAuthConfigItem[] = [];
  @State composioAuthMessage: string = '';
  @State composioAuthBusy: boolean = false;
  @State mailDetailEventJson: string = '';
  @State mailReplyEventJson: string = '';
  @State mailCalendarEventJson: string = '';
  private mailCalendarSuggestions: Record<string, MailCalendarSuggestion> = {};
  private htmlHomeCacheKey: string = '';
  private htmlHomeCacheHtml: string = '';
  private readonly registeredPageSnapshotStore: RegisteredPageSnapshotStore =
    new RegisteredPageSnapshotStore();
  private registeredPageRenderGeneration: number = 0;
  @State htmlHomeStableHtml: string = '';
  private voiceSession: VoiceInputSession | null = null;
  private voiceSessionSeq: number = 0;
  private voiceBaseInputText: string = '';
  private voiceStopRequested: boolean = false;
  private voiceCompletionHandled: boolean = false;
  private luckinReturnSurface: A2uiSurfaceState | null = null;
  private hotelReturnSurface: A2uiSurfaceState | null = null;
  private multiAgentRuntime: MultiAgentCanaryRuntime | null = null;
  private hotelAgentRuntimeFingerprint: string = '';
  private runtimeGeneration: number = 0;
  private readonly mailDetailSuggestionGuard: MailDetailSuggestionGuard =
    new MailDetailSuggestionGuard();
  private activeRuntimeOwner: RuntimeOwner = 'legacy';
  @State luckinInlinePatchJson: string = '';
  @State luckinInlinePatchTick: number = 0;
  private luckinOptionSwitchInFlight: boolean = false;

  private isLuckinOptionSwitchArgs(args: Object | null): boolean {
    if (args === null) {
      return false;
    }
    const raw = args as Record<string, Object | string | number | boolean | null | undefined>;
    return this.actionText(raw.attrGroup).length > 0 && this.actionText(raw.attrChoice).length > 0;
  }

  private luckinConfirmBlockJson(document: HtmlHomeDocument): string {
    for (let index = 0; index < document.blocks.length; index++) {
      if (document.blocks[index].title.indexOf('确认瑞幸订单') >= 0) {
        return JSON.stringify(document.blocks[index]);
      }
    }
    return '';
  }

  private applyLuckinInlineConfirmPatch(surface: A2uiSurfaceState): boolean {
    const document = createHtmlHomeDocument({
      surface: surface,
      messages: this.messages,
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    const patchJson = this.luckinConfirmBlockJson(document);
    if (patchJson.length === 0) {
      return false;
    }
    this.storeSurfaceSilently(surface);
    this.htmlHomeCacheKey = this.currentHtmlHomeCacheKey();
    this.htmlHomeCacheHtml = renderHtmlHomeDocument(document, false);
    this.luckinInlinePatchJson = patchJson;
    this.luckinInlinePatchTick = this.luckinInlinePatchTick + 1;
    this.recordRenderedPageSnapshot(surface, document);
    return true;
  }

  private finishLuckinOptionSwitch(inFlight: boolean = false): void {
    this.luckinOptionSwitchInFlight = inFlight;
  }

  private storeSurfaceSilently(surface: A2uiSurfaceState): void {
    this.currentSurface = this.surfaceSnapshot(surface);
    aiLogInfo('[AIPhone][A2uiHomeSurfaceSilentUpdate] surfaceId=' + surface.surfaceId +
      ' sequence=' + surface.sequence.toString());
  }

  private syncHtmlHomeStableHtml(): void {
    this.htmlHomeStableHtml = this.currentHtmlHomeHtml();
  }

  private hasLuckinConfirmBlockInSurface(surface: A2uiSurfaceState = this.currentSurface): boolean {
    const document = createHtmlHomeDocument({
      surface: surface,
      messages: this.messages,
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    return this.luckinConfirmBlockJson(document).length > 0;
  }

  private shouldKeepLuckinConfirmWebHtmlStable(): boolean {
    return this.hasLuckinConfirmBlockInSurface();
  }

  private htmlHomeHtmlForView(): string {
    if (this.currentSurface.intent === 'social') {
      return '';
    }
    if (this.shouldKeepLuckinConfirmWebHtmlStable()) {
      return this.htmlHomeStableHtml.length > 0 ? this.htmlHomeStableHtml : this.currentHtmlHomeHtml();
    }
    return this.currentHtmlHomeHtml();
  }

  private clearLuckinInlinePatchState(): void {
    this.luckinInlinePatchJson = '';
    this.finishLuckinOptionSwitch(false);
  }

  aboutToAppear(): void {
    this.configureDidiMcpSandboxRuntime(true);
    this.configureComposioRuntimeForCurrentUser();
    this.loadPersonaOverrides();
    this.loadPaymentAccounts();
    this.loadStripeReceivingProfile();
    void this.requestLocationPermissionOnLaunch();
  }

  aboutToDisappear(): void {
    this.disposeHotelRuntime();
  }

  private personaPackStore(): PreferencesPersonaPackStore | null {
    const context = this.getUIContext().getHostContext() as common.Context;
    return context === null ? null : new PreferencesPersonaPackStore(context);
  }

  private refreshPersonaEditor(personaId: string = this.selectedPersonaId): void {
    this.personaPacks = allPersonaPacks();
    const pack = personaPackForId(personaId);
    this.selectedPersonaId = pack.manifest.id;
    this.personaSoulDraft = pack.soul;
    this.personaMemoryDraft = pack.memory;
  }

  private loadPersonaOverrides(): void {
    const store = this.personaPackStore();
    if (store !== null) {
      store.loadSync();
    }
    this.refreshPersonaEditor(this.selectedPersonaId);
  }

  private paymentAccountPreferences(): preferences.Preferences | null {
    const context = this.getUIContext().getHostContext() as common.Context;
    if (context === null) {
      return null;
    }
    try {
      return preferences.getPreferencesSync(context, { name: PAYMENT_ACCOUNT_STORE_NAME });
    } catch (_error) {
      return null;
    }
  }

  private composioAuthPreferences(): preferences.Preferences | null {
    const context = this.getUIContext().getHostContext() as common.Context;
    if (context === null) {
      return null;
    }
    try {
      return preferences.getPreferencesSync(context, { name: COMPOSIO_AUTH_STORE_NAME });
    } catch (_error) {
      return null;
    }
  }

  private preferenceText(value: preferences.ValueType | string | number | boolean | null | undefined): string {
    if (value === undefined || value === null) {
      return '';
    }
    if (typeof value === 'string') {
      return value;
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return value.toString();
    }
    return '';
  }

  private savedPaymentAccountsJson(): string {
    const store = this.paymentAccountPreferences();
    if (store === null) {
      return '';
    }
    try {
      return this.preferenceText(store.getSync(PAYMENT_ACCOUNT_BOOK_KEY, ''));
    } catch (_error) {
      return '';
    }
  }

  private savedPaymentAccounts(): PaymentAccount[] {
    const raw = this.savedPaymentAccountsJson().trim();
    if (raw.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as PaymentAccount[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (_error) {
      return [];
    }
  }

  private savedComposioUserId(): string {
    const store = this.composioAuthPreferences();
    if (store === null) {
      return '';
    }
    try {
      const saved = this.preferenceText(store.getSync(COMPOSIO_USER_ID_KEY, '')).trim();
      return saved.length > 0 ? normalizeComposioUserId(saved) : '';
    } catch (_error) {
      return '';
    }
  }

  private async persistComposioUserId(userId: string): Promise<void> {
    const store = this.composioAuthPreferences();
    if (store === null) {
      return;
    }
    store.putSync(COMPOSIO_USER_ID_KEY, userId);
    await store.flush();
  }

  private createComposioUserId(): string {
    return normalizeComposioUserId(COMPOSIO_USER_ID_PREFIX + util.generateRandomUUID(false));
  }

  private ensureComposioUserId(): string {
    if (this.composioUserId.length > 0) {
      return this.composioUserId;
    }
    const configuredRaw = currentComposioUserId().trim();
    if (configuredRaw.length > 0) {
      const configured = normalizeComposioUserId(configuredRaw);
      this.composioUserId = configured;
      configureComposioUserId(configured);
      return configured;
    }
    const saved = this.savedComposioUserId();
    if (saved.length > 0) {
      this.composioUserId = saved;
      configureComposioUserId(saved);
      return saved;
    }
    const generated = this.createComposioUserId();
    this.composioUserId = generated;
    configureComposioUserId(generated);
    this.persistComposioUserId(generated).catch((_error: Error | Object | string | number | boolean | null | undefined) => {});
    return generated;
  }

  private composioAuthClient(): ComposioAuthProxyClient {
    const config = currentComposioConfig();
    if (config.proxyBaseUrl.length > 0) {
      return new ComposioAuthProxyClient(config.proxyBaseUrl, config.proxyApiKey);
    }
    return new ComposioAuthProxyClient(config.baseUrl, config.apiKey, true);
  }

  private configureComposioRuntimeForCurrentUser(): string {
    const userId = this.ensureComposioUserId();
    configureComposioUserId(userId);
    return userId;
  }

  private async refreshComposioAuth(): Promise<void> {
    this.composioAuthBusy = true;
    try {
      const userId = this.configureComposioRuntimeForCurrentUser();
      const result = await this.composioAuthClient().listAuthConfigs(userId);
      this.composioAuthItems = result.items;
      this.composioAuthMessage = result.ok ? '已刷新 Composio 授权状态。' : (result.error.length > 0 ? result.error : 'Composio 授权状态刷新失败。');
    } catch (error) {
      this.composioAuthMessage = error instanceof Error ? error.message : JSON.stringify(error);
    } finally {
      this.composioAuthBusy = false;
    }
  }

  private async openComposioAuthLink(item: ComposioAuthConfigItem): Promise<void> {
    this.composioAuthBusy = true;
    try {
      const link = await this.composioAuthClient().createLink(this.configureComposioRuntimeForCurrentUser(), item.authConfigId, item.toolkitSlug);
      if (!link.ok) {
        this.composioAuthMessage = link.error.length > 0 ? link.error : 'Composio 授权链接创建失败。';
        return;
      }
      this.composioAuthMessage = '正在打开授权页。';
      await this.openExternalUrl(link.redirectUrl);
    } catch (error) {
      this.composioAuthMessage = error instanceof Error ? error.message : JSON.stringify(error);
    } finally {
      this.composioAuthBusy = false;
    }
  }

  private composioAuthItemForToolkit(slug: string): ComposioAuthConfigItem | null {
    const normalized = this.normalizedComposioToolkitSlug(slug);
    for (let index = 0; index < this.composioAuthItems.length; index++) {
      if (this.normalizedComposioToolkitSlug(this.composioAuthItems[index].toolkitSlug) === normalized) {
        return this.composioAuthItems[index];
      }
    }
    return null;
  }

  private normalizedComposioToolkitSlug(slug: string): string {
    const normalized = slug.trim().toLowerCase();
    if (normalized === 'twitter') {
      return 'x';
    }
    if (normalized === 'calendar') {
      return 'googlecalendar';
    }
    if (normalized === 'microsoftoutlook') {
      return 'outlook';
    }
    if (normalized === 'youtubev3' || normalized === 'youtubedata') {
      return 'youtube';
    }
    return normalized;
  }

  private showComposioAuthList(message: string = ''): void {
    this.showConfigPage = false;
    this.showComposioAuthPage = true;
    if (message.length > 0) {
      this.composioAuthMessage = message;
    }
  }

  private async openSocialHubComposioAuth(platform: string): Promise<void> {
    if (this.composioAuthItems.length === 0) {
      await this.refreshComposioAuth();
    }
    const candidates = socialHubComposioToolkitCandidates(platform);
    for (let index = 0; index < candidates.length; index++) {
      const item = this.composioAuthItemForToolkit(candidates[index]);
      if (item !== null) {
        this.showComposioAuthList('正在打开 ' + platform + ' 授权页。');
        await this.openComposioAuthLink(item);
        return;
      }
    }
    this.showComposioAuthList('Composio 没有返回 ' + platform + ' 的授权配置。');
  }

  private loadPaymentAccounts(): void {
    const raw = this.savedPaymentAccountsJson();
    if (raw.trim().length > 0) {
      configureLocalPaymentAccountBookJson(raw);
    }
  }

  private savedStripeReceivingProfileJson(): string {
    const store = this.paymentAccountPreferences();
    if (store === null) {
      return '';
    }
    try {
      return this.preferenceText(store.getSync(STRIPE_RECEIVING_PROFILE_KEY, ''));
    } catch (_error) {
      return '';
    }
  }

  private loadStripeReceivingProfile(): void {
    const raw = this.savedStripeReceivingProfileJson();
    if (raw.trim().length > 0) {
      configureLocalStripeReceivingAgentJson(raw);
    }
  }

  private splitPaymentAliases(rawAliases: string): string[] {
    const normalized = rawAliases.split('，').join(',');
    const parts = normalized.split(',');
    const aliases: string[] = [];
    for (let index = 0; index < parts.length; index++) {
      const alias = parts[index].trim();
      if (alias.length > 0) {
        aliases.push(alias);
      }
    }
    return aliases;
  }

  private paymentAccountId(displayName: string): string {
    const value = displayName.trim().toLowerCase();
    let result = '';
    let previousSeparator = false;
    for (let index = 0; index < value.length; index++) {
      const char = value.charAt(index);
      const code = value.charCodeAt(index);
      const isAsciiLetter = (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
      if (isAsciiLetter) {
        result += char;
        previousSeparator = false;
      } else if (code > 127) {
        result += char;
        previousSeparator = false;
      } else if (!previousSeparator && result.length > 0) {
        result += '_';
        previousSeparator = true;
      }
    }
    while (result.endsWith('_')) {
      result = result.substring(0, result.length - 1);
    }
    return result.length > 0 ? result : 'local_payee';
  }

  private paymentAccountFromAction(action: A2uiAction): PaymentAccount | null {
    let payload: HtmlPaymentAccountPayload;
    try {
      payload = JSON.parse(action.prompt) as HtmlPaymentAccountPayload;
    } catch (_error) {
      return null;
    }
    const displayName = this.actionText(payload.displayName).trim();
    const paypalEmail = this.actionText(payload.paypalEmail).trim();
    const paypalMerchantId = this.actionText(payload.paypalMerchantId).trim();
    const stripeAccountId = this.actionText(payload.stripeAccountId).trim();
    const stripePaymentLinkUrl = this.actionText(payload.stripePaymentLinkUrl).trim();
    if (displayName.length === 0 ||
      (paypalEmail.length === 0 && paypalMerchantId.length === 0 && stripeAccountId.length === 0 && stripePaymentLinkUrl.length === 0)) {
      return null;
    }
    return {
      id: this.paymentAccountId(displayName),
      displayName: displayName,
      aliases: this.splitPaymentAliases(this.actionText(payload.aliases)),
      email: '',
      paypalEmail: paypalEmail,
      paypalMerchantId: paypalMerchantId,
      stripeAccountId: stripeAccountId,
      stripePaymentLinkUrl: stripePaymentLinkUrl,
      enabled: true
    };
  }

  private upsertSavedPaymentAccount(accounts: PaymentAccount[], account: PaymentAccount): PaymentAccount[] {
    const next: PaymentAccount[] = [];
    let replaced = false;
    for (let index = 0; index < accounts.length; index++) {
      if (accounts[index].id === account.id) {
        next.push(account);
        replaced = true;
      } else {
        next.push(accounts[index]);
      }
    }
    if (!replaced) {
      next.push(account);
    }
    return next;
  }

  private paymentPreferredProvider(account: PaymentAccount): string {
    const hasPayPal = account.paypalEmail.length > 0 || account.paypalMerchantId.length > 0;
    const hasStripe = account.stripeAccountId.length > 0 || account.stripePaymentLinkUrl.length > 0;
    if (hasPayPal && !hasStripe) {
      return 'paypal';
    }
    if (hasStripe && !hasPayPal) {
      return 'stripe';
    }
    return '';
  }

  private async savePaymentAccount(action: A2uiAction): Promise<void> {
    const account = this.paymentAccountFromAction(action);
    const store = this.paymentAccountPreferences();
    if (account === null || store === null) {
      this.logHtmlHomeActionError(action, 'invalid_payment_account_payload');
      return;
    }
    try {
      const accounts = this.upsertSavedPaymentAccount(this.savedPaymentAccounts(), account);
      const raw = JSON.stringify(accounts);
      store.putSync(PAYMENT_ACCOUNT_BOOK_KEY, raw);
      await store.flush();
      configureLocalPaymentAccountBookJson(raw);
      aiLogInfo('[AIPhone][PaymentAccountSave] ok=true displayName=' + account.displayName);
      const previewArgs: PaymentSavedPreviewArgs = {
        accountId: account.id,
        recipient: account.displayName,
        provider: this.paymentPreferredProvider(account),
        originalQuery: '给 ' + account.displayName + ' 转账'
      };
      await this.callToolById('payment.send', '给 ' + account.displayName + ' 转账', 'payment.account.saved', previewArgs);
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '付款对象保存失败',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      aiLogError('[AIPhone][PaymentAccountSave] ok=false reason=' + message);
    }
  }

  private hasStripeReceivingAccountComponent(surface: A2uiSurfaceState): boolean {
    for (let index = 0; index < surface.components.length; index++) {
      if (surface.components[index].component === A2UI_COMPONENT_STRIPE_RECEIVING_ACCOUNT_CARD) {
        return true;
      }
    }
    return false;
  }

  private stripeReceivingProfileFromSurface(surface: A2uiSurfaceState): StripeReceivingSavedProfile | null {
    if (!this.hasStripeReceivingAccountComponent(surface)) {
      return null;
    }
    const account: StripeReceivingAccountCardData = stripeReceivingAccount(surface);
    if (account.stripeAccountId.trim().length === 0) {
      return null;
    }
    return {
      agentId: account.agentId,
      deviceId: account.deviceId,
      displayName: account.displayName,
      email: account.email,
      country: account.country,
      businessType: account.businessType,
      stripeAccountId: account.stripeAccountId,
      status: account.status
    };
  }

  private async saveStripeReceivingProfile(surface: A2uiSurfaceState): Promise<void> {
    const profile = this.stripeReceivingProfileFromSurface(surface);
    const store = this.paymentAccountPreferences();
    if (profile === null || store === null) {
      return;
    }
    try {
      const raw = JSON.stringify(profile);
      store.putSync(STRIPE_RECEIVING_PROFILE_KEY, raw);
      await store.flush();
      configureLocalStripeReceivingAgentJson(raw);
      aiLogInfo('[AIPhone][StripeReceivingProfileSave] ok=true accountIdPresent=true status=' + profile.status);
    } catch (error) {
      aiLogError('[AIPhone][StripeReceivingProfileSave] ok=false reason=' + (error instanceof Error ? error.message : JSON.stringify(error)));
    }
  }

  private savePersonaOverrides(): void {
    const store = this.personaPackStore();
    if (store !== null) {
      store.saveSync();
    }
  }

  private selectPersonaForEdit(personaId: string): void {
    this.refreshPersonaEditor(personaId);
    this.personaSaveMessage = '';
  }

  private savePersonaDraft(): void {
    updatePersonaPackText(this.selectedPersonaId, this.personaSoulDraft, this.personaMemoryDraft);
    this.savePersonaOverrides();
    this.refreshPersonaEditor(this.selectedPersonaId);
    this.personaSaveMessage = '已保存';
  }

  private resetPersonaDraft(): void {
    resetPersonaPackText(this.selectedPersonaId);
    this.savePersonaOverrides();
    this.refreshPersonaEditor(this.selectedPersonaId);
    this.personaSaveMessage = '已恢复默认';
  }

  private applyPersonaMemoryUpdate(update: PersonaMemoryUpdateRequest): void {
    const pack = personaPackForId(update.personaId);
    if (pack.manifest.id !== update.personaId) {
      aiLogError('[AIPhone][PersonaMemoryUpdate] ok=false reason=unknown_persona personaId=' + update.personaId);
      return;
    }
    updatePersonaPackText(
      update.personaId,
      pack.soul,
      mergePersonaStablePreference(pack.memory, update.memoryText)
    );
    this.savePersonaOverrides();
    this.refreshPersonaEditor(update.personaId);
    this.personaSaveMessage = '已保存：' + update.summary;
    aiLogInfo('[AIPhone][PersonaMemoryUpdate] ok=true personaId=' + update.personaId + ' summary=' + update.summary);
  }

  private isPersonaEditorAction(action: A2uiAction): boolean {
    return action.id === 'persona_memory_edit' || action.id === 'persona_soul_edit';
  }

  private isStripeReceivingActionId(action: A2uiAction): boolean {
    return action.kind === 'client' &&
      (action.id === 'stripe.account.create' ||
        action.id === 'stripe.account.onboard' ||
        action.id === 'stripe.account.refresh');
  }

  private openPersonaEditor(personaId: string, target: string): void {
    this.selectPersonaForEdit(personaId);
    this.showConfigPage = true;
    this.personaSaveMessage = target === 'soul' ? '正在编辑 soul.md' : '正在编辑 memory.md';
  }

  private getSettings(): LocalModelSettings {
    return {
      provider: defaultLocalModelSettings().provider,
      baseUrl: this.baseUrl,
      model: this.selectedModel,
      apiKey: this.apiKey,
      customParametersJson: this.customParametersJson,
      ignoreToolSurfaceUpdates: this.ignoreToolSurfaceUpdates
    };
  }

  private currentLocalDate(): string {
    const now = new Date();
    const month = (now.getMonth() + 1).toString().padStart(2, '0');
    const day = now.getDate().toString().padStart(2, '0');
    return now.getFullYear().toString() + '-' + month + '-' + day;
  }

  private canaryRuntime(): MultiAgentCanaryRuntime {
    const settings = this.getSettings();
    const fingerprint = hotelModelSettingsFingerprint(settings);
    if (this.multiAgentRuntime !== null &&
      this.hotelAgentRuntimeFingerprint === fingerprint) {
      return this.multiAgentRuntime;
    }
    this.disposeHotelRuntime();
    const provider = new LlmProvider(
      settings.provider,
      settings.apiKey,
      settings.baseUrl,
      settings.model,
      settings.customParametersJson
    );
    const model = new OpenAiCompatibleModel(provider);
    const opener = new PageHotelUriOpener((uri: string): Promise<boolean> => {
      if (uri.startsWith('petalmaps://')) {
        return this.openExternalUrl(uri, ['petalmaps']);
      }
      if (!isRollingGoHotelBookingUrl(uri)) {
        return Promise.resolve(false);
      }
      this.checkoutWebKind = 'hotel';
      this.checkoutWebUrl = uri;
      this.showCheckoutWeb = true;
      aiLogInfo('[AIPhone][HotelBookingOpen] host=rollinggo.cn');
      return Promise.resolve(true);
    });
    const pageHandler = new RegisteredPageActionHandler(
      new PageRegisteredToolInvoker((
        toolId: string,
        prompt: string,
        pageActionId: string,
        args: Object
      ): Promise<RegisteredPageToolInvocation> =>
        this.invokeRegisteredPageTool(toolId, prompt, pageActionId, args))
    );
    const options: MultiAgentCanaryOptions = {
      model: model,
      opener: opener,
      onSurface: (surface: A2uiSurfaceState, generation: number): boolean => {
        const accepted = this.applyRuntimeSurface(surface, 'multi_agent', generation);
        if (accepted) {
          this.isAwaitingFirstSurface = false;
        }
        return accepted;
      },
      onMemoryUpdate: (update: PersonaMemoryUpdateRequest, generation: number): void => {
        if (runtimeCallbackIsCurrent(
          this.activeRuntimeOwner, this.runtimeGeneration, 'multi_agent', generation
        )) {
          this.applyPersonaMemoryUpdate(update);
        }
      },
      onMailDetail: async (
        result: MailDetailInPlaceEvent,
        generation: number,
        lease: MailDetailWriteLease
      ): Promise<void> => {
        const suggestionToken = this.mailDetailSuggestionGuard.beginDetail();
        const surfaceId = this.currentSurface.surfaceId;
        const enrichmentIsCurrent = (): boolean =>
          this.mailDetailSuggestionGuard.isCurrent(suggestionToken) &&
            this.currentSurface.surfaceId === surfaceId &&
            runtimeCallbackIsCurrent(
              this.activeRuntimeOwner, this.runtimeGeneration, 'multi_agent', generation
            );
        await publishMailDetailThenSuggest(result, {
          initialIsCurrent: (): boolean => lease.isActive() && enrichmentIsCurrent(),
          enrichmentIsCurrent,
          writeEvent: (event: MailDetailUiEvent): void => {
            this.mailDetailEventJson = JSON.stringify(event);
          },
          saveSuggestion: (requestKey: string, suggestion: MailCalendarSuggestion): void => {
            this.mailCalendarSuggestions[requestKey] = suggestion;
          },
          suggest: (detail: MailDetail): Promise<MailCalendarSuggestion> =>
            this.extractMailCalendarSuggestion(detail),
          onSuggestionError: (message: string): void => {
            aiLogError('[AIPhone][MailCalendarSuggestionFailed] ' + message.substring(0, 240));
          }
        });
        const bodyChars = result.detail === undefined ? 0 :
          (result.detail.bodyText.length > 0 ? result.detail.bodyText.length : result.detail.bodyHtml.length);
        aiLogInfo('[AIPhone][MailDetailInPlace] requestKeyChars=' + result.requestKey.length.toString() +
          ' provider=' + result.provider +
          ' identity=' + result.identityDigest +
          ' status=' + result.status + ' bodyChars=' + bodyChars.toString());
      },
      pageAction: (
        actionId: string,
        args: Object,
        context: RegisteredPageActionContext
      ): Promise<ActionExecutionResult> => actionId === 'gmail.message.send' ?
        this.executeRegisteredGmailReply(args) : pageHandler.execute(actionId, args, context),
      currentPageSnapshot: (): RegisteredPageSnapshot | null =>
        this.registeredPageSnapshotStore.current(),
      currentHostSurface: (): A2uiSurfaceState | null => this.surfaceSnapshot(this.currentSurface),
      currentHostGeneration: (): number => this.runtimeGeneration,
      currentLocalDate: (): string => this.currentLocalDate(),
      submitTimeoutMs: 45000,
      settingsFingerprint: fingerprint
    };
    if (provider.isConfigured()) {
      options.uiLayoutPlanner = new A2uiAgentRunner(new OpenAiA2uiModel(provider));
    }
    this.multiAgentRuntime = new MultiAgentCanaryRuntime(options);
    this.hotelAgentRuntimeFingerprint = fingerprint;
    return this.multiAgentRuntime;
  }

  private disposeHotelRuntime(): void {
    this.mailDetailSuggestionGuard.invalidate();
    if (this.multiAgentRuntime !== null) {
      this.multiAgentRuntime.dispose();
      this.multiAgentRuntime = null;
    }
    this.hotelAgentRuntimeFingerprint = '';
  }

  private currentPanelState(): ConnectionPanelState {
    return {
      connectionStatus: this.connectionStatus,
      connectionMessage: this.connectionMessage,
      lastModelRequest: this.lastModelRequest,
      lastModelOutput: this.lastModelOutput,
      lastError: this.lastError,
      refreshTick: this.refreshTick
    };
  }

  private applyPanelState(next: ConnectionPanelState): void {
    this.connectionStatus = next.connectionStatus;
    this.connectionMessage = next.connectionMessage;
    this.lastModelRequest = next.lastModelRequest;
    this.lastModelOutput = next.lastModelOutput;
    this.lastError = next.lastError;
    this.refreshTick = next.refreshTick;
  }

  private resetPanelState(): void {
    const next = createInitialConnectionPanelState();
    this.connectionStatus = next.connectionStatus;
    this.connectionMessage = next.connectionMessage;
    this.lastModelRequest = next.lastModelRequest;
    this.lastModelOutput = next.lastModelOutput;
    this.lastError = next.lastError;
    this.refreshTick = next.refreshTick;
  }

  private cloneSurfaceComponents(components: A2uiComponent[]): A2uiComponent[] {
    const next: A2uiComponent[] = [];
    components.forEach((component: A2uiComponent) => {
      next.push({
        id: component.id,
        component: component.component,
        child: component.child,
        children: component.children === undefined ? [] : component.children.slice(),
        title: component.title,
        text: component.text,
        body: component.body,
        status: component.status,
        tone: component.tone,
        variant: component.variant,
        path: component.path,
        dataPath: component.dataPath,
        actions: component.actions === undefined ? [] : component.actions.slice()
      });
    });
    return next;
  }

  private surfaceSnapshot(surface: A2uiSurfaceState): A2uiSurfaceState {
    return {
      surfaceId: surface.surfaceId,
      rootId: surface.rootId,
      title: surface.title,
      intent: surface.intent,
      status: surface.status,
      components: this.cloneSurfaceComponents(surface.components),
      dataModelJson: surface.dataModelJson,
      error: surface.error,
      sequence: surface.sequence,
      runtimeOwner: surface.runtimeOwner,
      runtimeGeneration: surface.runtimeGeneration
    };
  }

  private beginRuntimeTurn(owner: RuntimeOwner): number {
    this.mailDetailSuggestionGuard.invalidate();
    this.runtimeGeneration++;
    this.activeRuntimeOwner = owner;
    return this.runtimeGeneration;
  }

  private ownedSurface(
    surface: A2uiSurfaceState,
    owner: RuntimeOwner,
    generation: number
  ): A2uiSurfaceState {
    const next = this.surfaceSnapshot(surface);
    next.runtimeOwner = owner;
    next.runtimeGeneration = generation;
    return next;
  }

  private applyRuntimeSurface(
    surface: A2uiSurfaceState,
    owner: RuntimeOwner,
    generation: number
  ): boolean {
    if (!runtimeCallbackIsCurrent(
      this.activeRuntimeOwner,
      this.runtimeGeneration,
      owner,
      generation
    )) {
      return false;
    }
    this.applySurface(this.ownedSurface(surface, owner, generation));
    return true;
  }

  private parsedDataModel(): A2uiRuntimeDataModel | null {
    try {
      return JSON.parse(this.currentSurface.dataModelJson) as A2uiRuntimeDataModel;
    } catch (_error) {
      return null;
    }
  }

  private currentHtmlHomeDocument(): HtmlHomeDocument {
    if (shouldShowWelcome(this.isBusy, this.messages.length, this.currentSurface) ||
      shouldShowQueryPendingSurface(this.isBusy, this.isAwaitingFirstSurface)) {
      return createHtmlHomeDocument({
        messages: this.messages,
        isBusy: this.isBusy,
        isAwaitingFirstSurface: this.isAwaitingFirstSurface,
        inputText: this.inputText
      });
    }
    return createHtmlHomeDocument({
      surface: this.currentSurface,
      messages: this.messages,
      isBusy: this.isBusy,
      isAwaitingFirstSurface: this.isAwaitingFirstSurface
    });
  }

  private currentHtmlHomeCacheKey(): string {
    const needsInputText = shouldShowQueryPendingSurface(this.isBusy, this.isAwaitingFirstSurface);
    return [
      this.currentSurface.surfaceId,
      this.currentSurface.sequence.toString(),
      this.currentSurface.runtimeOwner === undefined ? '' : this.currentSurface.runtimeOwner,
      this.currentSurface.runtimeGeneration === undefined ? '' :
        this.currentSurface.runtimeGeneration.toString(),
      this.surfaceRenderTick.toString(),
      this.currentSurface.status,
      this.isBusy ? 'busy' : 'idle',
      this.isAwaitingFirstSurface ? 'awaiting' : 'ready',
      this.messages.length.toString(),
      needsInputText ? this.inputText : ''
    ].join('|');
  }

  private currentHtmlHomeHtml(): string {
    const key = this.currentHtmlHomeCacheKey();
    if (key === this.htmlHomeCacheKey && this.htmlHomeCacheHtml.length > 0) {
      return this.htmlHomeCacheHtml;
    }
    const document = this.currentHtmlHomeDocument();
    const html = renderHtmlHomeDocument(document, this.isBusy);
    this.recordRenderedPageSnapshot(this.currentSurface, document);
    if (this.htmlHomeDebugExportEnabled) {
      this.writeHtmlHomeDebugExport(document, 'auto');
    }
    this.htmlHomeCacheKey = key;
    this.htmlHomeCacheHtml = html;
    aiLogInfo('[AIPhone][HtmlHomeDocument] source=' + document.source +
      ' kind=' + document.kind +
      ' chars=' + html.length.toString() +
      ' blocks=' + document.blocks.length.toString() +
      ' renderTick=' + this.surfaceRenderTick.toString());
    return html;
  }

  private recordRenderedPageSnapshot(
    surface: A2uiSurfaceState,
    document: HtmlHomeDocument
  ): void {
    if (document.surfaceId === undefined || document.surfaceId !== surface.surfaceId) {
      return;
    }
    this.registeredPageRenderGeneration++;
    this.registeredPageSnapshotStore.record(
      this.surfaceSnapshot(surface),
      document,
      this.registeredPageRenderGeneration
    );
  }

  private writeHtmlHomeDebugExport(document: HtmlHomeDocument, reason: string): void {
    const context = this.getUIContext().getHostContext() as common.Context;
    if (context === null) {
      this.htmlHomeDebugExportPath = '导出失败：缺少应用上下文';
      aiLogInfo('[AIPhone][HtmlHomeDebugExport] ok=false reason=missing_context');
      return;
    }
    const path = context.filesDir + '/' + HTML_HOME_DEBUG_EXPORT_FILE_NAME;
    let file: fs.File | null = null;
    try {
      file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, htmlHomeDebugExportJson(document, this.isBusy));
      fs.closeSync(file);
      file = null;
      this.htmlHomeDebugExportPath = path;
      aiLogInfo('[AIPhone][HtmlHomeDebugExport] ok=true reason=' + reason +
        ' path=' + path +
        ' kind=' + document.kind +
        ' blocks=' + document.blocks.length.toString());
    } catch (error) {
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (_closeError) {
        }
      }
      this.htmlHomeDebugExportPath = '导出失败：' + JSON.stringify(error);
      aiLogInfo('[AIPhone][HtmlHomeDebugExport] ok=false reason=' + reason +
        ' error=' + JSON.stringify(error));
    }
  }

  private exportCurrentHtmlHomeDocument(): void {
    this.writeHtmlHomeDebugExport(this.currentHtmlHomeDocument(), 'manual');
  }

  private applySurface(surface: A2uiSurfaceState): boolean {
    const next = this.surfaceSnapshot(surface);
    if (next.runtimeOwner === undefined) {
      next.runtimeOwner = this.activeRuntimeOwner;
    }
    if (next.runtimeGeneration === undefined) {
      next.runtimeGeneration = this.runtimeGeneration;
    }
    if (next.runtimeOwner !== this.activeRuntimeOwner ||
      next.runtimeGeneration !== this.runtimeGeneration ||
      !shouldApplySurfaceUpdate(this.currentSurface, next)) {
      return false;
    }
    this.currentSurface = next;
    this.surfaceRenderTick = this.surfaceRenderTick + 1;
    this.clearLuckinInlinePatchState();
    this.syncHtmlHomeStableHtml();
    aiLogInfo('[AIPhone][A2uiHomeSurfaceUpdate] surfaceId=' + surface.surfaceId +
      ' status=' + surface.status +
      ' components=' + surface.components.length.toString() +
      ' dataChars=' + surface.dataModelJson.length.toString() +
      ' sequence=' + surface.sequence.toString() +
      ' renderTick=' + this.surfaceRenderTick.toString());
    return true;
  }

  private forceApplySurface(surface: A2uiSurfaceState, reason: string): void {
    const next = this.surfaceSnapshot(surface);
    if (next.runtimeOwner === undefined) {
      next.runtimeOwner = this.activeRuntimeOwner;
    }
    if (next.runtimeGeneration === undefined) {
      next.runtimeGeneration = this.runtimeGeneration;
    }
    if (next.runtimeOwner !== this.activeRuntimeOwner ||
      next.runtimeGeneration !== this.runtimeGeneration) {
      return;
    }
    this.currentSurface = next;
    this.surfaceRenderTick = this.surfaceRenderTick + 1;
    this.clearLuckinInlinePatchState();
    this.syncHtmlHomeStableHtml();
    this.htmlHomeCacheKey = '';
    this.htmlHomeCacheHtml = '';
    aiLogInfo('[AIPhone][A2uiHomeSurfaceForceUpdate] reason=' + reason +
      ' surfaceId=' + surface.surfaceId +
      ' status=' + surface.status +
      ' components=' + surface.components.length.toString() +
      ' dataChars=' + surface.dataModelJson.length.toString() +
      ' sequence=' + surface.sequence.toString() +
      ' renderTick=' + this.surfaceRenderTick.toString());
  }

  private rememberLuckinReturnSurface(reason: string): void {
    if (this.currentSurface.intent !== 'luckin') {
      return;
    }
    this.luckinReturnSurface = this.surfaceSnapshot(this.currentSurface);
    aiLogInfo('[AIPhone][LuckinReturnSurfaceRemember] reason=' + reason +
      ' title=' + this.currentSurface.title +
      ' dataChars=' + this.currentSurface.dataModelJson.length.toString());
  }

  private restoreLuckinReturnSurface(reason: string): void {
    if (this.luckinReturnSurface === null) {
      aiLogInfo('[AIPhone][LuckinReturnSurfaceRestore] reason=' + reason + ' ok=false');
      return;
    }
    const surface = this.surfaceSnapshot(this.luckinReturnSurface);
    this.luckinReturnSurface = null;
    this.showCheckoutWeb = false;
    this.forceApplySurface(surface, reason);
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'ready',
      message: '已返回瑞幸下单页面。',
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
    aiLogInfo('[AIPhone][LuckinReturnSurfaceRestore] reason=' + reason + ' ok=true');
  }

  private rememberHotelReturnSurface(): void {
    if (this.currentSurface.intent === 'hotel') {
      this.hotelReturnSurface = this.surfaceSnapshot(this.currentSurface);
    }
  }

  private restoreHotelReturnSurface(reason: string): void {
    if (this.hotelReturnSurface === null) {
      aiLogInfo('[AIPhone][HotelReturnSurfaceRestore] reason=' + reason + ' ok=false');
      return;
    }
    const surface = this.surfaceSnapshot(this.hotelReturnSurface);
    this.hotelReturnSurface = null;
    this.forceApplySurface(surface, reason);
    aiLogInfo('[AIPhone][HotelReturnSurfaceRestore] reason=' + reason + ' ok=true');
  }

  private socialHubComposioAuthItem(platform: SocialHubPlatform): ComposioAuthConfigItem | null {
    const candidates = socialHubComposioToolkitCandidates(platform);
    for (let index = 0; index < candidates.length; index++) {
      const item = this.composioAuthItemForToolkit(candidates[index]);
      if (item !== null) {
        return item;
      }
    }
    return null;
  }

  private composioSocialHubConnection(platform: SocialHubPlatform, displayName: string): SocialHubConnectionData {
    const item = this.socialHubComposioAuthItem(platform);
    if (item === null) {
      return {
        platform: platform,
        status: 'needs_auth',
        displayName: displayName,
        accountId: '',
        message: platform === 'wecom' ? '等待企业微信接入' : '等待 Composio 授权接入'
      };
    }
    const status: SocialHubConnectionStatus = (item.status === 'connected' || item.connectedAccountId.length > 0 || item.canExecute) ?
      'connected' : 'needs_auth';
    return {
      platform: platform,
      status: status,
      displayName: displayName,
      accountId: item.connectedAccountId,
      message: status === 'connected' ?
        ('Composio 已授权' + (item.connectedAccountLabel.length > 0 ? '：' + item.connectedAccountLabel : '')) :
        '等待 Composio 授权接入'
    };
  }

  private defaultSocialHubConnections(): SocialHubConnectionData[] {
    return [
      this.composioSocialHubConnection('x', 'X'),
      this.composioSocialHubConnection('slack', 'Slack'),
      {
        platform: 'wecom',
        status: 'needs_auth',
        displayName: '企业微信',
        accountId: '',
        message: '等待授权接入'
      },
      this.composioSocialHubConnection('discord', 'Discord'),
      this.composioSocialHubConnection('linkedin', 'LinkedIn'),
      this.composioSocialHubConnection('whatsapp', 'WhatsApp'),
      this.composioSocialHubConnection('instagram', 'Instagram'),
      this.composioSocialHubConnection('reddit', 'Reddit')
    ];
  }

  private createSocialHubSurface(): A2uiSurfaceState {
    const store = new A2uiSurfaceStore();
    store.apply({
      version: 'v0.9.1',
      createSurface: {
        surfaceId: 'surface_social_hub',
        root: 'root',
        title: 'SocialHub',
        intent: 'social',
        status: 'ready',
        sendDataModel: true
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateComponents: {
        surfaceId: 'surface_social_hub',
        components: [
          {
            id: 'root',
            component: A2UI_COMPONENT_SURFACE_ROOT,
            child: 'socialHub',
            title: 'SocialHub',
            status: 'ready'
          },
          {
            id: 'socialHub',
            component: A2UI_COMPONENT_SOCIAL_HUB,
            title: 'SocialHub',
            status: 'ready',
            dataPath: '/socialHub/items'
          }
        ]
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_social_hub',
        path: '/socialHub/connections',
        value: this.defaultSocialHubConnections()
      }
    });
    return store.getSurface();
  }

  private async openSocialHub(): Promise<void> {
    this.showHistory = false;
    this.isBusy = false;
    this.isAwaitingFirstSurface = false;
    this.inputPlaceholder = DEFAULT_INPUT_PLACEHOLDER;
    await this.refreshComposioAuth();
    this.applySurface(this.createSocialHubSurface());
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'ready',
      message: 'SocialHub 已打开；正在加载近 30 天私信。',
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
    await this.callToolById('social.feed.search', '帮我查看最近30天所有已授权应用收到的私信消息', 'social_hub_default');
  }

  private applySocialHubData(path: string, value: A2uiDataValue): void {
    const store = new A2uiSurfaceStore();
    store.seed(this.currentSurface);
    const result = store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: this.currentSurface.surfaceId,
        path: path,
        value: value
      }
    });
    if (!result.ok) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: 'SocialHub 本地状态更新失败。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: result.error
      }));
      return;
    }
    this.applySurface(store.getSurface());
  }

  private currentSocialHubItems(): SocialHubItemData[] {
    const model = this.parsedDataModel();
    if (model === null || model.socialHub === undefined || model.socialHub === null) {
      return [];
    }
    return Array.isArray(model.socialHub.items) ? model.socialHub.items : [];
  }

  private currentSocialHubSelected(): SocialHubItemData | null {
    const model = this.parsedDataModel();
    if (model === null || model.socialHub === undefined || model.socialHub === null ||
      model.socialHub.selected === undefined || model.socialHub.selected === null ||
      model.socialHub.selected.id.length === 0) {
      return null;
    }
    return model.socialHub.selected;
  }

  private findSocialHubItem(itemId: string): SocialHubItemData | null {
    const items = this.currentSocialHubItems();
    for (let index = 0; index < items.length; index++) {
      if (items[index].id === itemId) {
        return items[index];
      }
    }
    return null;
  }

  private findSocialHubItemByUrl(url: string): SocialHubItemData | null {
    if (url.length === 0) {
      return null;
    }
    const items = this.currentSocialHubItems();
    for (let index = 0; index < items.length; index++) {
      if (items[index].url === url) {
        return items[index];
      }
    }
    return null;
  }

  private hasSocialHubComponent(): boolean {
    for (let index = 0; index < this.currentSurface.components.length; index++) {
      if (this.currentSurface.components[index].component === A2UI_COMPONENT_SOCIAL_HUB) {
        return true;
      }
    }
    return false;
  }

  private isCurrentSocialHubSurface(): boolean {
    const model = this.parsedDataModel();
    return this.currentSurface.intent === 'social' &&
      this.hasSocialHubComponent() &&
      model !== null &&
      model.socialHub !== undefined &&
      model.socialHub !== null &&
      Array.isArray(model.socialHub.items);
  }

  private socialHubDraftError(itemId: string, message: string): SocialHubDraftData {
    const selected = this.currentSocialHubSelected();
    return {
      itemId: itemId,
      platform: selected === null ? 'unknown' : selected.platform,
      text: '',
      status: 'error',
      error: message,
      localOnly: true,
      sent: false
    };
  }

  private socialHubDraftSnippet(text: string): string {
    const trimmed = text.trim();
    if (trimmed.length <= 80) {
      return trimmed;
    }
    return trimmed.substring(0, 80) + '...';
  }

  private selectSocialHubItem(action: A2uiAction): void {
    const item = this.findSocialHubItem(action.prompt);
    if (item === null) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(action.prompt, '未找到这条真实消息，无法选择。'));
      return;
    }
    this.applySocialHubData('/socialHub/selected', item);
  }

  private draftSocialHubReply(action: A2uiAction): void {
    const selected = this.currentSocialHubSelected();
    const itemId = action.prompt.length > 0 ? action.prompt : (selected === null ? '' : selected.id);
    if (itemId.length === 0) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError('', '请先选择一条真实消息，再生成草稿。'));
      return;
    }
    const item = this.findSocialHubItem(itemId);
    if (item === null) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(itemId, '未找到这条真实消息，不能生成草稿。'));
      return;
    }
    const sourceText = item.text.trim();
    if (sourceText.length === 0) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(itemId, '选中消息没有正文，不能生成本地草稿预览。'));
      return;
    }
    this.applySocialHubData('/socialHub/selected', item);
    const draft: SocialHubDraftData = emptySocialHubDraft();
    draft.itemId = item.id;
    draft.platform = item.platform;
    draft.status = 'draft';
    draft.text = '本地草稿预览（未发送）：\n\n我会基于这条真实消息回复：' + this.socialHubDraftSnippet(sourceText);
    this.applySocialHubData('/socialHub/draft', draft);
  }

  private socialHubReplyText(action: A2uiAction): string {
    if (action.args === undefined || action.args === null) {
      return '';
    }
    const payload = action.args as SocialHubReplyPayload;
    return this.actionText(payload.text).trim();
  }

  private async sendSocialHubReply(action: A2uiAction): Promise<void> {
    const selected = this.currentSocialHubSelected();
    const itemId = action.prompt.length > 0 ? action.prompt : (selected === null ? '' : selected.id);
    const item = this.findSocialHubItem(itemId);
    if (item === null) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(itemId, '未找到这条真实消息，不能发送回复。'));
      return;
    }
    const text = this.socialHubReplyText(action);
    if (text.length === 0) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(item.id, '请输入要发送的回复内容。'));
      return;
    }
    this.applySocialHubData('/socialHub/selected', item);
    const pending: SocialHubDraftData = emptySocialHubDraft();
    pending.itemId = item.id;
    pending.platform = item.platform;
    pending.status = 'draft';
    pending.text = '正在发送到 ' + (item.platform === 'slack' ? 'Slack' : '社交平台') + '...';
    pending.localOnly = false;
    this.applySocialHubData('/socialHub/draft', pending);
    try {
      this.applySocialHubData('/socialHub/draft', await sendLocalSocialHubReply(item, text));
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(item.id, message));
    }
  }

  private async openSocialHubSource(action: A2uiAction): Promise<void> {
    const item = this.findSocialHubItemByUrl(action.prompt);
    if (item === null) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError('', '这条消息没有匹配的来源 URL。'));
      return;
    }
    await this.openExternalUrl(item.url);
  }

  private isSocialHubActionId(action: A2uiAction): boolean {
    return action.kind === 'client' &&
      (action.id === 'social_hub_select_item' ||
        action.id === 'social_hub_draft_reply' ||
        action.id === 'social_hub_send_reply' ||
        action.id === 'social_hub_open_source' ||
        action.id === 'social_hub_authorize');
  }

  private isSocialHubClientAction(action: A2uiAction): boolean {
    return this.isSocialHubActionId(action) && this.isCurrentSocialHubSurface();
  }

  private resetCurrentSession(): void {
    this.disposeHotelRuntime();
    this.showHistory = false;
    this.isBusy = false;
    this.isAwaitingFirstSurface = false;
    this.messages = [];
    this.registeredPageSnapshotStore.clear();
    this.registeredPageRenderGeneration = 0;
    this.currentSurface = this.surfaceSnapshot(createSeedA2uiSurface());
    this.surfaceRenderTick = this.surfaceRenderTick + 1;
    this.clearLuckinInlinePatchState();
    this.syncHtmlHomeStableHtml();
    this.inputText = '';
    this.inputPlaceholder = DEFAULT_INPUT_PLACEHOLDER;
    this.resetPanelState();
  }

  private markChecking(message: string): void {
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'checking',
      message: message,
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
  }

  private recentMessages(): A2uiMessage[] {
    if (this.messages.length <= 8) {
      return this.messages;
    }
    return this.messages.slice(this.messages.length - 8);
  }

  private multiAgentInput(text: string): UserInputPayload {
    const recentMessages: ConversationTurnMessage[] = [];
    const pageMessages = this.recentMessages();
    for (let index = 0; index < pageMessages.length; index++) {
      const role = pageMessages[index].role;
      if (role === 'user' || role === 'assistant') {
        recentMessages.push({
          role: role === 'user' ? 'user' : 'assistant',
          content: pageMessages[index].content
        });
      }
    }
    const surface: CurrentSurfaceSummary = {
      surfaceId: this.currentSurface.surfaceId,
      kind: this.currentSurface.intent,
      status: this.currentSurface.status,
      entityRefs: [],
      actionOfferIds: []
    };
    return {
      text,
      recentMessages,
      previousPersonaId: '',
      currentSurfaceSummary: surface,
      recentObservations: []
    };
  }

  private appendMessage(role: string, content: string): void {
    const next = this.messages.slice();
    next.push({
      id: Date.now().toString() + '-' + next.length.toString(),
      role: role,
      content: content
    });
    this.messages = next;
  }

  private currentDynamicToolConnect(): A2uiDynamicToolConnectData | null {
    const model = this.parsedDataModel();
    if (model === null || model.dynamicToolConnect === undefined || model.dynamicToolConnect === null) {
      return null;
    }
    return model.dynamicToolConnect;
  }

  private async openExternalUrl(
    url: string,
    allowedSchemes: string[] = ['https']
  ): Promise<boolean> {
    if (url.length === 0) {
      return false;
    }
    const schemeMatch = /^([A-Za-z][A-Za-z0-9+.-]*):/.exec(url);
    const scheme = schemeMatch === null ? 'unknown' : schemeMatch[1].toLowerCase();
    const urlMeta = ' scheme=' + scheme + ' chars=' + url.length.toString();
    if (allowedSchemes.indexOf(scheme) < 0) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '无法打开不受信任的外部页面。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: 'external URL scheme is not allowed'
      }));
      aiLogError('[AIPhone][A2uiHomeOpenUrl] ok=false' + urlMeta +
        ' code=SCHEME_NOT_ALLOWED');
      return false;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: url
      });
      aiLogInfo('[AIPhone][A2uiHomeOpenUrl] ok=true' + urlMeta);
      return true;
    } catch (error) {
      const businessError = error as BusinessError;
      const message = '外部页面打开失败：' + businessError.message;
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '无法打开外部页面。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      aiLogError('[AIPhone][A2uiHomeOpenUrl] ok=false' + urlMeta + ' code=' + businessError.code.toString());
      return false;
    }
  }

  private openAnythingDemo(): Promise<boolean> {
    return new Promise<boolean>((resolve: (value: boolean) => void): void => {
      router.pushUrl({ url: ANYTHING_DEMO_ROUTE_URL }, (error) => {
        if (error) {
          aiLogError('[AIPhone][AnythingDemoRouteFailed] ' + JSON.stringify(error));
          resolve(false);
          return;
        }
        resolve(true);
      });
    });
  }

  private async submitPrompt(prompt: string, visibleText: string, actionId: string = '', actionArgs: Object | null = null): Promise<void> {
    const trimmed = prompt.trim();
    if (trimmed.length === 0 || this.isBusy) {
      return;
    }
    const modelPrompt = modelPromptWithActionContext(trimmed, actionId, actionArgs);
    if (this.baseUrl.trim().length === 0) {
      aiLogError('[AIPhone][A2uiHomeSubmitBlocked] missingBaseUrl');
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '请先填写 Base URL。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: 'Base URL 为空'
      }));
      return;
    }
    const turnGeneration: number = this.beginRuntimeTurn('multi_agent');
    this.inputPlaceholder = DEFAULT_INPUT_PLACEHOLDER;
    this.appendMessage('user', visibleText);
    aiLogInfo('[AIPhone][A2uiHomeSubmitPrompt] chars=' + modelPrompt.length.toString() +
      ' model=' + this.selectedModel +
      ' baseUrl=' + this.baseUrl);
    this.inputText = inputTextAfterPromptSubmit(this.inputText);
    this.isBusy = true;
    this.isAwaitingFirstSurface = true;
    this.markChecking('正在生成 A2UI...');
    try {
      configureLocalToolDebugConfig({
        foodProviderDelayEnabled: this.foodProviderDelayEnabled,
        foodProviderDelayMs: normalizeFoodProviderDelayMs(this.foodProviderDelayMs),
        foodPartialThrottleMs: normalizeFoodPartialThrottleMs(this.foodPartialThrottleMs)
      });
      this.markChecking('正在生成 A2UI...');
      const outcome: MultiAgentTurnOutcome = await this.canaryRuntime().submit(
        modelPrompt,
        this.multiAgentInput(modelPrompt),
        turnGeneration
      );
      if (!runtimeCallbackIsCurrent(
        this.activeRuntimeOwner, this.runtimeGeneration, 'multi_agent', turnGeneration
      )) {
        return;
      }
      const result: MultiAgentSettledOutcome = outcome as MultiAgentSettledOutcome;
      if (!result.ok) {
        throw new Error(result.message.length > 0 ?
          result.message : 'Multi-agent runtime failed to complete the turn.');
      }
      this.isAwaitingFirstSurface = false;
      if (result.surfaceId.length > 0 &&
        result.surfaceId === this.currentSurface.surfaceId &&
        result.personaId.length > 0) {
        this.applyRuntimeSurface(
          leaderPersonaSurfaceUpdate(
            this.currentSurface,
            result.personaId,
            result.skillId
          ),
          'multi_agent',
          turnGeneration
        );
      }
      const readyMessage: string = result.message.length > 0 ?
        result.message : this.currentSurface.title;
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: readyMessage,
        requestDebug: 'multi-agent-runtime',
        assistantDebug: readyMessage,
        error: ''
      }));
      this.appendMessage('assistant', readyMessage);
    } catch (error) {
      if (this.runtimeGeneration !== turnGeneration) {
        return;
      }
      this.isAwaitingFirstSurface = false;
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][A2uiHomeModelException] ' + logSnippet(message));
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: 'A2UI 生成异常，请到配置页查看详情。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
    } finally {
      if (this.runtimeGeneration === turnGeneration) {
        this.isAwaitingFirstSurface = false;
        this.isBusy = false;
      }
    }
  }

  private async sendPrompt(): Promise<void> {
    await this.submitPrompt(this.inputText, this.inputText);
  }

  private currentVoiceSession(seq: number): boolean {
    return this.isVoiceListening && this.voiceSessionSeq === seq && !this.voiceCompletionHandled;
  }

  private voiceLiveLabel(text: string): string {
    const next = text.trim();
    return next.length > 0 ? next : '语音识别中';
  }

  private finishVoiceInputWithResult(seq: number, result: VoiceInputResult): void {
    if (!this.currentVoiceSession(seq)) {
      return;
    }
    this.voiceCompletionHandled = true;
    const next = voiceInputTextAfterRecognition(this.voiceBaseInputText, result.text);
    if (next === this.voiceBaseInputText) {
      this.voiceInputMessage = '没有识别到语音内容';
    } else {
      this.inputText = next;
      this.voiceInputMessage = '已加入输入框';
    }
    this.voiceSession = null;
    this.isVoiceListening = false;
  }

  private finishVoiceInputWithError(seq: number, error: Error | Object | string | number | boolean | null | undefined): void {
    if (!this.currentVoiceSession(seq)) {
      return;
    }
    this.voiceCompletionHandled = true;
    const serialized = error === null || error === undefined ? '' : JSON.stringify(error);
    const message = error instanceof Error ? error.message : (serialized === undefined ? '' : serialized);
    this.voiceInputMessage = message.length > 0 ? '语音输入失败：' + message : '语音输入失败';
    this.voiceSession = null;
    this.isVoiceListening = false;
  }

  private async startVoiceInput(): Promise<void> {
    if (this.isBusy || this.isVoiceListening) {
      return;
    }
    const seq = this.voiceSessionSeq + 1;
    this.voiceSessionSeq = seq;
    this.voiceSession = null;
    this.voiceBaseInputText = this.inputText;
    this.voiceStopRequested = false;
    this.voiceCompletionHandled = false;
    this.isVoiceListening = true;
    this.voiceInputMessage = '语音识别中';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const session = await startVoiceInputSession(context, (text: string) => {
        if (this.currentVoiceSession(seq)) {
          this.voiceInputMessage = this.voiceLiveLabel(text);
        }
      });
      if (!this.currentVoiceSession(seq)) {
        session.stop().catch((_error: Error) => {});
        return;
      }
      this.voiceSession = session;
      session.result
        .then((result: VoiceInputResult) => {
          this.finishVoiceInputWithResult(seq, result);
        })
        .catch((error: Error) => {
          this.finishVoiceInputWithError(seq, error);
        });
      if (this.voiceStopRequested) {
        session.stop().catch((_error: Error) => {});
      }
    } catch (error) {
      this.finishVoiceInputWithError(seq, error as Error | Object | string | number | boolean | null | undefined);
    }
  }

  private stopVoiceInput(): void {
    if (!this.isVoiceListening) {
      return;
    }
    this.voiceStopRequested = true;
    if (this.voiceSession === null) {
      this.voiceInputMessage = '识别整理中';
      return;
    }
    if (this.voiceInputMessage === '语音识别中') {
      this.voiceInputMessage = '识别整理中';
    }
    this.voiceSession.stop().catch((_error: Error) => {});
  }

  private htmlPinPayload(action: A2uiAction): HtmlPinPayload {
    if (action.prompt.trim().charAt(0) !== '{') {
      return { index: action.prompt };
    }
    try {
      const payload = JSON.parse(action.prompt) as HtmlPinPayload;
      return payload === null ? { index: action.prompt } : payload;
    } catch (_error) {
      return { index: action.prompt };
    }
  }

  private htmlActionIndex(action: A2uiAction, payload: HtmlPinPayload): number {
    const payloadValue = Number.parseInt(this.actionText(payload.index), 10);
    if (payloadValue === payloadValue && payloadValue >= 0) {
      return payloadValue;
    }
    const value = Number.parseInt(action.prompt, 10);
    return value === value && value >= 0 ? value : -1;
  }

  private htmlPinTravelMatches(item: A2uiTravelOptionData, payload: HtmlPinPayload): boolean {
    if (!this.htmlPinTravelPayloadHasIdentity(payload)) {
      return false;
    }
    const id = this.actionText(payload.id);
    const source = this.actionText(payload.source);
    const depart = this.actionText(payload.depart);
    const from = this.actionText(payload.from);
    const to = this.actionText(payload.to);
    return id === this.actionText(item.id) &&
      source === this.actionText(item.source) &&
      depart === this.actionText(item.depart) &&
      from === this.actionText(item.from) &&
      to === this.actionText(item.to);
  }

  private htmlPinTrainMatches(item: A2uiTrainData, payload: HtmlPinPayload): boolean {
    if (!this.htmlPinTrainPayloadHasIdentity(payload)) {
      return false;
    }
    const trainCode = this.actionText(payload.trainCode);
    const depart = this.actionText(payload.depart);
    const from = this.actionText(payload.from);
    const to = this.actionText(payload.to);
    return trainCode === this.actionText(item.trainCode) &&
      depart === this.actionText(item.depart) &&
      from === this.actionText(item.from) &&
      to === this.actionText(item.to);
  }

  private htmlPinFlightMatches(item: A2uiFlightData, payload: HtmlPinPayload): boolean {
    if (!this.htmlPinFlightPayloadHasIdentity(payload)) {
      return false;
    }
    const flightNo = this.actionText(payload.flightNo);
    const depTime = this.actionText(payload.depTime);
    const dep = this.actionText(payload.dep);
    const arr = this.actionText(payload.arr);
    return flightNo === this.actionText(item.flightNo) &&
      depTime === this.actionText(item.depTime) &&
      dep === this.actionText(item.dep) &&
      arr === this.actionText(item.arr);
  }

  private htmlPinFoodMatches(item: A2uiFoodData, payload: HtmlPinPayload): boolean {
    if (!this.htmlPinFoodPayloadHasIdentity(payload)) {
      return false;
    }
    const name = this.actionText(payload.name);
    const address = this.actionText(payload.address);
    const location = this.actionText(payload.location);
    const distance = this.actionText(payload.distance);
    return name === this.actionText(item.name) &&
      address === this.actionText(item.address) &&
      location === this.actionText(item.location) &&
      distance === this.actionText(item.distance);
  }

  private htmlPinTravelPayloadHasIdentity(payload: HtmlPinPayload): boolean {
    return this.actionText(payload.id).length + this.actionText(payload.source).length +
      this.actionText(payload.depart).length + this.actionText(payload.from).length +
      this.actionText(payload.to).length > 0;
  }

  private htmlPinTrainPayloadHasIdentity(payload: HtmlPinPayload): boolean {
    return this.actionText(payload.trainCode).length + this.actionText(payload.depart).length +
      this.actionText(payload.from).length + this.actionText(payload.to).length > 0;
  }

  private htmlPinFlightPayloadHasIdentity(payload: HtmlPinPayload): boolean {
    return this.actionText(payload.flightNo).length + this.actionText(payload.depTime).length +
      this.actionText(payload.dep).length + this.actionText(payload.arr).length > 0;
  }

  private htmlPinFoodPayloadHasIdentity(payload: HtmlPinPayload): boolean {
    return this.actionText(payload.name).length + this.actionText(payload.address).length +
      this.actionText(payload.location).length + this.actionText(payload.distance).length > 0;
  }

  private htmlPinTravelRow(model: A2uiRuntimeDataModel, payload: HtmlPinPayload, index: number): A2uiTravelOptionData | null {
    if (!Array.isArray(model.travelOptions)) {
      return null;
    }
    for (let rowIndex = 0; rowIndex < model.travelOptions.length; rowIndex++) {
      if (this.htmlPinTravelMatches(model.travelOptions[rowIndex], payload)) {
        return model.travelOptions[rowIndex];
      }
    }
    if (this.htmlPinTravelPayloadHasIdentity(payload)) {
      return null;
    }
    return index >= 0 && index < model.travelOptions.length ? model.travelOptions[index] : null;
  }

  private htmlPinTrainRow(model: A2uiRuntimeDataModel, payload: HtmlPinPayload, index: number): A2uiTrainData | null {
    if (!Array.isArray(model.trains)) {
      return null;
    }
    for (let rowIndex = 0; rowIndex < model.trains.length; rowIndex++) {
      if (this.htmlPinTrainMatches(model.trains[rowIndex], payload)) {
        return model.trains[rowIndex];
      }
    }
    if (this.htmlPinTrainPayloadHasIdentity(payload)) {
      return null;
    }
    return index >= 0 && index < model.trains.length ? model.trains[index] : null;
  }

  private htmlPinFlightRow(model: A2uiRuntimeDataModel, payload: HtmlPinPayload, index: number): A2uiFlightData | null {
    if (!Array.isArray(model.flights)) {
      return null;
    }
    for (let rowIndex = 0; rowIndex < model.flights.length; rowIndex++) {
      if (this.htmlPinFlightMatches(model.flights[rowIndex], payload)) {
        return model.flights[rowIndex];
      }
    }
    if (this.htmlPinFlightPayloadHasIdentity(payload)) {
      return null;
    }
    return index >= 0 && index < model.flights.length ? model.flights[index] : null;
  }

  private htmlPinFoodRow(model: A2uiRuntimeDataModel, payload: HtmlPinPayload, index: number): A2uiFoodData | null {
    if (!Array.isArray(model.foods)) {
      return null;
    }
    for (let rowIndex = 0; rowIndex < model.foods.length; rowIndex++) {
      if (this.htmlPinFoodMatches(model.foods[rowIndex], payload)) {
        return model.foods[rowIndex];
      }
    }
    if (this.htmlPinFoodPayloadHasIdentity(payload)) {
      return null;
    }
    return index >= 0 && index < model.foods.length ? model.foods[index] : null;
  }

  private logHtmlHomeActionError(action: A2uiAction, reason: string): void {
    const argsChars = action.args === undefined ? 0 : JSON.stringify(action.args).length;
    aiLogError('[AIPhone][HtmlHomeAction] id=' + action.id +
      ' ok=false reason=' + reason +
      ' kind=' + action.kind +
      ' promptChars=' + action.prompt.length.toString() +
      ' argsChars=' + argsChars.toString());
    if (action.id === 'html_mail_reply_ai_generate' && action.args !== undefined) {
      const args = action.args as MailReplyAiArgs;
      aiLogError('[AIPhone][HtmlHomeMailReplyAiBlocked] prompt=' + action.prompt +
        ' requestKey=' + this.actionText(args.requestKey) +
        ' provider=' + this.actionText(args.provider) +
        ' threadId=' + this.actionText(args.threadId) +
        ' messageId=' + this.actionText(args.messageId) +
        ' subjectChars=' + this.actionText(args.subject).length.toString() +
        ' contextChars=' + this.actionText(args.contextSummary).length.toString());
    }
  }

  private async handleHtmlPinAction(action: A2uiAction): Promise<boolean> {
    if (action.id !== 'html_pin_travel' && action.id !== 'html_pin_train' &&
      action.id !== 'html_pin_flight' && action.id !== 'html_pin_food') {
      return false;
    }
    const model = this.parsedDataModel();
    const payload = this.htmlPinPayload(action);
    const index = this.htmlActionIndex(action, payload);
    if (model === null) {
      this.logHtmlHomeActionError(action, 'invalid_model');
      return true;
    }
    if (action.id === 'html_pin_travel') {
      const row = this.htmlPinTravelRow(model, payload, index);
      if (row === null) {
        this.logHtmlHomeActionError(action, 'missing_travel_row');
        return true;
      }
      await this.pinTravelNavigationCard(row);
      return true;
    }
    if (action.id === 'html_pin_train') {
      const row = this.htmlPinTrainRow(model, payload, index);
      if (row === null) {
        this.logHtmlHomeActionError(action, 'missing_train_row');
        return true;
      }
      await this.pinTrainNavigationCard(row);
      return true;
    }
    if (action.id === 'html_pin_flight') {
      const row = this.htmlPinFlightRow(model, payload, index);
      if (row === null) {
        this.logHtmlHomeActionError(action, 'missing_flight_row');
        return true;
      }
      await this.pinFlightNavigationCard(row);
      return true;
    }
    const row = this.htmlPinFoodRow(model, payload, index);
    if (row === null) {
      this.logHtmlHomeActionError(action, 'missing_food_row');
      return true;
    }
    await this.pinNavigationCard(row);
    return true;
  }

  private async handleHtmlFoodMapAction(action: A2uiAction): Promise<boolean> {
    if (action.id !== 'html_open_food_map') {
      return false;
    }
    const model = this.parsedDataModel();
    const payload = this.htmlPinPayload(action);
    const index = this.htmlActionIndex(action, payload);
    if (model === null) {
      this.logHtmlHomeActionError(action, 'invalid_model');
      return true;
    }
    const row = this.htmlPinFoodRow(model, payload, index);
    if (row === null) {
      this.logHtmlHomeActionError(action, 'missing_food_row');
      return true;
    }
    const uri = buildSystemFoodNavigationUri(this.actionText(row.location), '', row.name);
    if (uri.length === 0) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '缺少真实坐标，不能打开地图。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      this.logHtmlHomeActionError(action, 'missing_food_coordinate');
      return true;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      try {
        await context.openLink(uri);
      } catch (_linkError) {
        await context.startAbility({
          action: 'ohos.want.action.viewData',
          entities: ['entity.system.browsable'],
          uri: uri
        });
      }
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '已打开系统地图：' + row.name,
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      aiLogInfo('[AIPhone][HtmlHomeFoodMap] ok=true uriChars=' + uri.length.toString() + ' name=' + row.name);
    } catch (error) {
      const businessError = error as BusinessError;
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '地图打开失败。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: businessError.message
      }));
      aiLogError('[AIPhone][HtmlHomeFoodMap] ok=false message=' + businessError.message);
    }
    return true;
  }

  private actionText(value: HtmlActionValue): string {
    if (value === undefined || value === null) {
      return '';
    }
    if (typeof value === 'string') {
      return value;
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return value.toString();
    }
    return '';
  }

  private emptyMailCalendarSuggestion(detail: MailDetail, reason: string): MailCalendarSuggestion {
    return {
      requestKey: detail.requestKey,
      provider: detail.provider,
      threadId: detail.threadId,
      messageId: detail.messageId,
      isWorkRelated: false,
      hasMeeting: false,
      title: '',
      start: '',
      end: '',
      displayTime: '',
      timezone: 'Asia/Shanghai',
      location: '',
      description: '',
      confidence: 'low',
      reason: reason
    };
  }

  private payloadBool(payload: Record<string, HtmlActionValue>, key: string): boolean {
    const value = payload[key];
    if (typeof value === 'boolean') {
      return value;
    }
    return this.actionText(value).trim().toLowerCase() === 'true';
  }

  private payloadText(payload: Record<string, HtmlActionValue>, key: string): string {
    return this.actionText(payload[key]).trim();
  }

  private cleanMailCalendarDescription(value: string): string {
    const lines: string[] = value.split('\n');
    const kept: string[] = [];
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index].trim();
      if (line.length === 0) {
        continue;
      }
      if (/^(来源|邮件来源|Source|发件人|From)\s*[:：]/i.test(line)) {
        continue;
      }
      kept.push(line);
    }
    return kept.join('\n')
      .replace(/[；;，,。\s]*(来源|邮件来源|Source|发件人|From)\s*[:：][^\n]*$/i, '')
      .trim();
  }

  private mailCalendarSuggestionPrompt(detail: MailDetail): string {
    const schema: MailCalendarSuggestionSchemaText = {
      isWorkRelated: 'boolean，邮件是否与工作/学习/会议协作相关',
      hasMeeting: 'boolean，正文是否明确包含可加入日历的会议/活动/面试/评审等日程',
      title: 'string，适合放入日历的短标题',
      start: 'string，ISO 8601 日期时间，必须含时区，例如 2026-07-10T15:00:00+08:00；无法确定则空字符串',
      end: 'string，ISO 8601 日期时间，必须含时区；无法确定结束时间则按开始后30分钟估计',
      displayTime: 'string，面向界面展示的中文时间，例如 7月10日 15:00-15:30；无法确定则空字符串',
      timezone: 'string，默认 Asia/Shanghai',
      location: 'string，会议地点、线上会议链接或空字符串',
      description: 'string，100字以内会议内容摘要，只写会议/活动本身；不得包含来源、邮件来源、发件人、邮箱等信息',
      confidence: 'string，只能是 high/medium/low',
      reason: 'string，简短说明判断依据'
    };
    return '请分析下面邮件是否为工作相关会议，并抽取可写入手机日历的结构化信息。' +
      '不要调用工具，不要写邮件，不要解释。必须只输出一个 JSON 对象，且完全符合这个 schema：' +
      JSON.stringify(schema) +
      '\n规则：' +
      '\n1. 只有明确有会议、面试、评审、同步会、deadline 日程等时间安排时 hasMeeting=true。' +
      '\n2. 时间必须基于邮件标题和正文，不要编造日期；只有相对日期但无法确定基准日期时 start 置空。' +
      '\n3. 如果有开始时间但没有结束时间，end 使用开始时间后 30 分钟。' +
      '\n4. displayTime 是 start/end 的中文可读表达，不要输出 ISO 原文。' +
      '\n5. description 不要写“来源：...”“邮件来源：...”“From：...”或发件人邮箱，来源由界面单独展示。' +
      '\n6. 如果不是工作相关或没有明确时间，仍输出完整 JSON，但按钮字段应为 false/空字符串。' +
      '\n当前设备时间: ' + new Date().toISOString() +
      '\n邮件主题: ' + detail.subject +
      '\nFrom: ' + detail.from +
      '\nTo: ' + JSON.stringify(detail.to) +
      '\n正文:\n' + detail.bodyText;
  }

  private parseMailCalendarSuggestion(detail: MailDetail, raw: string): MailCalendarSuggestion {
    try {
      const jsonText = jsonObjectTextFromModel(raw);
      const payload = JSON.parse(jsonText) as Record<string, HtmlActionValue>;
      const start = this.payloadText(payload, 'start');
      const end = this.payloadText(payload, 'end');
      const isWorkRelated = this.payloadBool(payload, 'isWorkRelated');
      const hasMeeting = this.payloadBool(payload, 'hasMeeting') && start.length > 0;
      return {
        requestKey: detail.requestKey,
        provider: detail.provider,
        threadId: detail.threadId,
        messageId: detail.messageId,
        isWorkRelated: isWorkRelated,
        hasMeeting: hasMeeting,
        title: this.payloadText(payload, 'title'),
        start: start,
        end: end,
        displayTime: this.payloadText(payload, 'displayTime'),
        timezone: this.payloadText(payload, 'timezone').length > 0 ? this.payloadText(payload, 'timezone') : 'Asia/Shanghai',
        location: this.payloadText(payload, 'location'),
        description: this.cleanMailCalendarDescription(this.payloadText(payload, 'description')),
        confidence: this.payloadText(payload, 'confidence').length > 0 ? this.payloadText(payload, 'confidence') : 'low',
        reason: this.payloadText(payload, 'reason')
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][MailCalendarSuggestionParseFailed] ' + message.substring(0, 240));
      return this.emptyMailCalendarSuggestion(detail, '日程解析失败：' + message.substring(0, 120));
    }
  }

  private async extractMailCalendarSuggestion(detail: MailDetail): Promise<MailCalendarSuggestion> {
    if (this.baseUrl.trim().length === 0 || detail.bodyText.trim().length === 0) {
      return this.emptyMailCalendarSuggestion(detail, '模型未配置或正文为空。');
    }
    const prompt = this.mailCalendarSuggestionPrompt(detail);
    aiLogInfo('[AIPhone][MailCalendarSuggestionRequest] requestKey=' + detail.requestKey +
      ' subjectChars=' + detail.subject.length.toString() +
      ' bodyChars=' + detail.bodyText.length.toString() +
      ' promptChars=' + prompt.length.toString());
    try {
      const result: DirectModelCallResult = await callDirectModel(
        this.getSettings(),
        prompt,
        this.recentMessages()
      );
      const raw = result.assistantDebug.length > 0 ? result.assistantDebug : result.raw;
      if (!result.ok || raw.trim().length === 0) {
        return this.emptyMailCalendarSuggestion(detail, result.error.length > 0 ? result.error : '模型没有返回日程结构。');
      }
      const suggestion = this.parseMailCalendarSuggestion(detail, raw);
      aiLogInfo('[AIPhone][MailCalendarSuggestionDone] requestKey=' + detail.requestKey +
        ' work=' + (suggestion.isWorkRelated ? 'true' : 'false') +
        ' meeting=' + (suggestion.hasMeeting ? 'true' : 'false') +
        ' start=' + suggestion.start);
      return suggestion;
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][MailCalendarSuggestionFailed] ' + message.substring(0, 240));
      return this.emptyMailCalendarSuggestion(detail, message);
    }
  }

  private mailReplyAiPrompt(args: MailReplyAiArgs): string {
    const recipients = args.to === undefined ? '' : JSON.stringify(args.to);
    return '请为下面这封邮件生成一段简短、礼貌、工作风格的回复正文。' +
      '不要调用工具，不要保存草稿，不要发送邮件。最后必须只用一行输出，格式为 Final: <回复正文>。' +
      '不要输出 JSON，不要输出 Action。' +
      '\n收件人: ' + recipients +
      '\n主题: ' + this.actionText(args.subject) +
      '\n邮件上下文:\n' + this.actionText(args.contextSummary);
  }

  private mailReplyAiEvent(requestKey: string, status: string, message: string, error: string): void {
    const event: MailReplyUiEvent = {
      sequence: Date.now(),
      requestKey: requestKey,
      operation: 'ai',
      status: status,
      message: message,
      error: error
    };
    this.mailReplyEventJson = JSON.stringify(event);
  }

  private mailReplyOperationEvent(
    requestKey: string,
    operation: string,
    status: string,
    message: string,
    error: string
  ): void {
    const event: MailReplyUiEvent = {
      sequence: Date.now(),
      requestKey,
      operation,
      status,
      message,
      error
    };
    this.mailReplyEventJson = JSON.stringify(event);
  }

  private async executeRegisteredGmailReply(args: Object): Promise<ActionExecutionResult> {
    const command = args as MailReplyCommand;
    const requestKey = this.actionText(command.requestKey).trim();
    if (this.actionText(command.provider).trim().toLowerCase() !== 'gmail') {
      const message = 'Gmail reply provider does not match the current mail surface.';
      this.mailReplyOperationEvent(requestKey, 'send', 'error', '', message);
      return {
        status: 'error',
        errorCode: 'GMAIL_REPLY_PROVIDER_MISMATCH',
        message
      };
    }
    try {
      const result = await sendConfiguredMailReply(command);
      if (result.status !== 'success') {
        this.mailReplyOperationEvent(requestKey, 'send', result.status, '', result.message);
        return {
          status: 'error',
          errorCode: 'GMAIL_REPLY_PROVIDER_ERROR',
          message: result.message
        };
      }
      this.mailReplyOperationEvent(
        result.requestKey,
        result.operation,
        result.status,
        result.message,
        ''
      );
      return { status: 'success', output: result as Object };
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.mailReplyOperationEvent(requestKey, 'send', 'error', '', message);
      aiLogError('[AIPhone][MailReplyOperationFailed] provider=gmail operation=send error=' +
        message.substring(0, 240));
      return {
        status: 'error',
        errorCode: 'GMAIL_REPLY_PROVIDER_ERROR',
        message
      };
    }
  }

  private async generateMailReplyDraft(action: A2uiAction): Promise<void> {
    if (action.args === undefined) {
      this.logHtmlHomeActionError(action, 'missing_mail_reply_ai_args');
      return;
    }
    const requestKey = action.prompt.trim();
    if (requestKey.length === 0) {
      this.logHtmlHomeActionError(action, 'invalid_mail_reply_ai_request_key');
      return;
    }
    if (this.baseUrl.trim().length === 0) {
      this.mailReplyAiEvent(requestKey, 'error', '', '请先填写 Base URL。');
      return;
    }
    const args = action.args as MailReplyAiArgs;
    const prompt = this.mailReplyAiPrompt(args);
    aiLogInfo('[AIPhone][MailReplyAiDraftRequest] requestKey=' + requestKey +
      ' provider=' + this.actionText(args.provider) +
      ' threadId=' + this.actionText(args.threadId) +
      ' messageId=' + this.actionText(args.messageId) +
      ' toCount=' + (Array.isArray(args.to) ? args.to.length : 0).toString() +
      ' subjectChars=' + this.actionText(args.subject).length.toString() +
      ' contextChars=' + this.actionText(args.contextSummary).length.toString() +
      ' promptChars=' + prompt.length.toString());
    try {
      const result: DirectModelCallResult = await callDirectModel(
        this.getSettings(),
        prompt,
        this.recentMessages()
      );
      aiLogInfo('[AIPhone][MailReplyAiDraft] ok=' + (result.ok ? 'true' : 'false') +
        ' errorChars=' + result.error.length.toString() +
        ' rawChars=' + result.raw.length.toString() +
        ' assistantChars=' + result.assistantDebug.length.toString());
      aiLogInfo('[AIPhone][MailReplyAiDraftRaw] ' + logSnippet(result.raw));
      if (result.error.length > 0) {
        aiLogError('[AIPhone][MailReplyAiDraftError] ' + logSnippet(result.error));
      }
      if (result.assistantDebug.length > 0) {
        aiLogInfo('[AIPhone][MailReplyAiDraftAssistant] ' + logSnippet(result.assistantDebug));
      }
      const text = stripMailReplyAiText(result.assistantDebug.length > 0 ? result.assistantDebug : result.raw);
      if (!result.ok || text.length === 0) {
        const message = result.error.length > 0 ? result.error : 'AI 回复生成失败。';
        this.mailReplyAiEvent(requestKey, 'error', '', message);
        return;
      }
      this.mailReplyAiEvent(requestKey, 'success', text, '');
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][MailReplyAiDraftFailed] error=' + message.substring(0, 240));
      this.mailReplyAiEvent(requestKey, 'error', '', message);
    }
  }

  private mailCalendarEvent(requestKey: string, status: string, message: string, eventId: string, error: string): void {
    const event: MailCalendarUiEvent = {
      sequence: Date.now(),
      requestKey: requestKey,
      status: status,
      message: message,
      eventId: eventId,
      error: error
    };
    this.mailCalendarEventJson = JSON.stringify(event);
  }

  private async ensureCalendarPermissions(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const permission = await abilityAccessCtrl.createAtManager()
      .requestPermissionsFromUser(context, [READ_CALENDAR_PERMISSION, WRITE_CALENDAR_PERMISSION]);
    if (!calendarPermissionGranted(permission.permissions, permission.authResults)) {
      throw new Error('日历权限未授权');
    }
  }

  private async addSuggestedMailCalendarEvent(action: A2uiAction): Promise<void> {
    if (action.args === undefined) {
      this.logHtmlHomeActionError(action, 'missing_mail_calendar_args');
      return;
    }
    const args = action.args as MailCalendarActionArgs;
    const requestKey = this.actionText(args.requestKey).trim();
    if (requestKey.length === 0 || action.prompt.trim() !== requestKey) {
      this.logHtmlHomeActionError(action, 'invalid_mail_calendar_request_key');
      return;
    }
    const suggestion = this.mailCalendarSuggestions[requestKey];
    if (suggestion === undefined) {
      this.mailCalendarEvent(requestKey, 'error', '', '', '没有找到已解析的日程信息。');
      return;
    }
    if (!suggestion.isWorkRelated || !suggestion.hasMeeting || suggestion.start.trim().length === 0) {
      this.mailCalendarEvent(requestKey, 'error', '', '', '这封邮件没有可添加的会议日程。');
      return;
    }
    if (this.actionText(args.provider).trim() !== suggestion.provider ||
      this.actionText(args.threadId).trim() !== suggestion.threadId ||
      this.actionText(args.messageId).trim() !== suggestion.messageId) {
      this.mailCalendarEvent(requestKey, 'error', '', '', '邮件身份校验失败。');
      return;
    }
    try {
      await this.ensureCalendarPermissions();
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const result = await addHuaweiCalendarEvent(context, suggestion);
      this.mailCalendarEvent(requestKey, result.status, result.message, result.eventId, '');
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.mailCalendarEvent(requestKey, 'error', '', '', message);
    }
  }

  private locationPermissionGranted(result: LocationPermissionResult): boolean {
    for (let index = 0; index < result.permissions.length; index++) {
      const permission = result.permissions[index];
      const granted = result.authResults.length > index && result.authResults[index] === 0;
      if ((permission === PRECISE_LOCATION_PERMISSION || permission === APPROX_LOCATION_PERMISSION) && granted) {
        return true;
      }
    }
    return false;
  }

  private async ensureLocationPermission(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const permission = await abilityAccessCtrl.createAtManager()
      .requestPermissionsFromUser(context, [APPROX_LOCATION_PERMISSION, PRECISE_LOCATION_PERMISSION]);
    if (!this.locationPermissionGranted({
      permissions: permission.permissions,
      authResults: permission.authResults
    })) {
      throw new Error('定位权限未授权');
    }
  }

  private async requestLocationPermissionOnLaunch(): Promise<void> {
    try {
      await this.ensureLocationPermission();
      aiLogInfo('[AIPhone][LocationPermissionLaunch] ok=true');
    } catch (error) {
      aiLogError('[AIPhone][LocationPermissionLaunch] ok=false reason=' +
        (error instanceof Error ? error.message : JSON.stringify(error)));
    }
  }

  private async currentDeviceLocation(): Promise<string> {
    await this.ensureLocationPermission();
    const current = await geoLocationManager.getCurrentLocation();
    const longitude = current.longitude;
    const latitude = current.latitude;
    if (longitude === undefined || latitude === undefined) {
      throw new Error('系统未返回当前位置');
    }
    return longitude.toString() + ',' + latitude.toString();
  }

  private mergeLuckinLocationArgs(args: Object | null, location: string): Object {
    const merged: Record<string, Object | string | number | boolean | null | undefined> = {};
    if (args !== null) {
      const raw = args as Record<string, Object | string | number | boolean | null | undefined>;
      Object.keys(raw).forEach((key: string) => {
        merged[key] = raw[key];
      });
    }
    merged.location = location;
    merged.locationSource = 'device_current';
    return merged;
  }

  private async argsWithCurrentLocationForTool(toolId: string, args: Object | null): Promise<Object | null> {
    if (toolId !== 'luckin.order.preview') {
      return args;
    }
    if (args !== null) {
      const raw = args as Record<string, Object | string | number | boolean | null | undefined>;
      const selectedDeptId = raw.deptId;
      if (this.actionText(selectedDeptId).length > 0) {
        return args;
      }
      const forceRefresh = this.actionText(raw.locationSource) === 'refresh';
      const existingLocation = this.actionText(raw.location);
      if (existingLocation.length > 0 && !forceRefresh) {
        return args;
      }
    }
    try {
      const location = await this.currentDeviceLocation();
      aiLogInfo('[AIPhone][LuckinCurrentLocation] source=device chars=' + location.length.toString());
      return this.mergeLuckinLocationArgs(args, location);
    } catch (error) {
      aiLogError('[AIPhone][LuckinCurrentLocation] ok=false reason=' + (error instanceof Error ? error.message : JSON.stringify(error)));
      return args;
    }
  }

  private isPaymentCheckoutUrl(url: string): boolean {
    const lower = url.trim().toLowerCase();
    return lower.startsWith('https://checkout.stripe.com/') ||
      lower.startsWith('https://buy.stripe.com/') ||
      lower.startsWith('https://www.paypal.com/') ||
      lower.startsWith('https://www.sandbox.paypal.com/');
  }

  private isStripeOnboardingUrl(url: string): boolean {
    return url.trim().toLowerCase().startsWith('https://connect.stripe.com/');
  }

  private stripeOnboardingUrlForAction(action: A2uiAction): string {
    let fromArgs = '';
    if (action.args !== undefined) {
      const payload = action.args as StripeOnboardingActionPayload;
      fromArgs = this.actionText(payload.onboardingUrl).trim();
    }
    if (fromArgs.length > 0) {
      return fromArgs;
    }
    return action.prompt.trim();
  }

  private paymentCheckoutUrlForAction(action: A2uiAction): string {
    let fromArgs = '';
    if (action.args !== undefined) {
      const payload = action.args as PaymentCheckoutActionPayload;
      fromArgs = this.actionText(payload.checkoutUrl).trim();
    }
    if (fromArgs.length > 0) {
      return fromArgs;
    }
    return action.prompt.trim();
  }

  private trainBookingUrlForAction(action: A2uiAction): string {
    if (action.args === undefined) {
      return '';
    }
    const payload = action.args as TrainBookingActionPayload;
    return this.actionText(payload.bookingUrl).trim();
  }

  private luckinPayUrlForAction(action: A2uiAction): string {
    if (action.args !== undefined) {
      const payload = action.args as Record<string, Object | string | number | boolean | null | undefined>;
      const payOrderUrl = payload.payOrderUrl;
      const qrCodeUrl = payload.payOrderQrCodeUrl;
      if (typeof payOrderUrl === 'string' && payOrderUrl.trim().length > 0) {
        return payOrderUrl.trim();
      }
      if (typeof qrCodeUrl === 'string' && qrCodeUrl.trim().length > 0) {
        return qrCodeUrl.trim();
      }
    }
    return action.prompt.trim();
  }

  private isLuckinPayUrl(url: string): boolean {
    const lower = url.trim().toLowerCase();
    return lower.startsWith('https://') ||
      lower.startsWith('http://') ||
      lower.startsWith('weixin://') ||
      lower.startsWith('weixin');
  }

  private isLuckinPaymentActionId(actionId: string): boolean {
    return actionId === 'luckin.pay.open' ||
      actionId === 'luckin.demo.alipay.open' ||
      actionId === 'luckin.demo.googlepay.open' ||
      actionId === 'luckin.order.status';
  }

  private luckinPaymentOrderIdFromAction(action: A2uiAction): string {
    if (action.args === undefined) {
      return '';
    }
    const payload = action.args as Record<string, Object | string | number | boolean | null | undefined>;
    return this.actionText(payload.orderId).trim();
  }

  private luckinPayUrlFromDocument(document: HtmlHomeDocument): string {
    const pools: A2uiAction[] = [];
    document.actions.forEach((action: HtmlHomeAction) => {
      pools.push(action as A2uiAction);
    });
    document.blocks.forEach((block: HtmlHomeBlock) => {
      block.actions.forEach((action: HtmlHomeAction) => {
        pools.push(action as A2uiAction);
      });
    });
    for (let index = 0; index < pools.length; index += 1) {
      const action = pools[index];
      if (action.id === 'luckin.pay.open') {
        const payUrl = this.luckinPayUrlForAction(action);
        if (this.isLuckinPayUrl(payUrl)) {
          return payUrl;
        }
      }
    }
    for (let blockIndex = 0; blockIndex < document.blocks.length; blockIndex += 1) {
      const block = document.blocks[blockIndex];
      for (let rowIndex = 0; rowIndex < block.rows.length; rowIndex += 1) {
        const row = block.rows[rowIndex];
        if ((row.label === '支付链接' || row.label === '支付二维码') && this.isLuckinPayUrl(row.value)) {
          return row.value.trim();
        }
      }
    }
    return '';
  }

  private luckinCreateArgsFromAction(action: A2uiAction): Object | null {
    if (action.args === undefined) {
      return null;
    }
    const payload = action.args as Record<string, Object | string | number | boolean | null | undefined>;
    const deptId = this.actionText(payload.deptId).trim();
    const productId = this.actionText(payload.productId).trim();
    const skuCode = this.actionText(payload.skuCode).trim();
    if (deptId.length === 0 || productId.length === 0 || skuCode.length === 0) {
      return null;
    }
    return action.args;
  }

  private async resolveLuckinPayUrlForAction(action: A2uiAction): Promise<string> {
    let payUrl = this.luckinPayUrlForAction(action);
    if (this.isLuckinPayUrl(payUrl)) {
      return payUrl;
    }
    const orderId = this.luckinPaymentOrderIdFromAction(action);
    if (orderId.length > 0) {
      this.logLuckinPaymentAction(action, 'refresh_pay_url_start');
      payUrl = await this.refreshLuckinPayUrlForAction(action);
      if (this.isLuckinPayUrl(payUrl)) {
        return payUrl;
      }
    }
    const createArgs = this.luckinCreateArgsFromAction(action);
    if (createArgs !== null) {
      this.logLuckinPaymentAction(action, 'retry_create_start');
      const ok = await this.callToolById('luckin.order.create', '确认创建瑞幸订单', 'luckin.pay.open', createArgs);
      if (ok) {
        payUrl = this.luckinPayUrlFromDocument(this.currentHtmlHomeDocument());
        if (this.isLuckinPayUrl(payUrl)) {
          return payUrl;
        }
      }
    }
    return '';
  }

  private async refreshLuckinPayUrlForAction(action: A2uiAction): Promise<string> {
    const orderId = this.luckinPaymentOrderIdFromAction(action);
    if (orderId.length === 0) {
      return '';
    }
    let args: Object;
    if (action.args === undefined) {
      const statusArgs: LuckinOrderStatusArgs = {
        orderId: orderId
      };
      args = statusArgs as Object;
    } else {
      args = action.args;
    }
    const ok = await this.callToolById('luckin.order.status', '查询瑞幸订单状态', 'luckin.pay.open', args);
    if (!ok) {
      return '';
    }
    return this.luckinPayUrlFromDocument(this.currentHtmlHomeDocument());
  }

  private logLuckinPaymentAction(action: A2uiAction, stage: string, extra: string = ''): void {
    const document = this.currentHtmlHomeDocument();
    const allowed = isHtmlHomeActionAllowed(document, action);
    const suffix = extra.length > 0 ? ' ' + extra : '';
    aiLogInfo('[AIPhone][LuckinPaymentAction] stage=' + stage +
      ' id=' + action.id +
      ' kind=' + action.kind +
      ' busy=' + (this.isBusy ? 'true' : 'false') +
      ' allowed=' + (allowed ? 'true' : 'false') +
      ' surfaceKind=' + document.kind +
      ' orderId=' + this.luckinPaymentOrderIdFromAction(action) +
      ' promptChars=' + action.prompt.length.toString() +
      ' payUrlChars=' + this.luckinPayUrlForAction(action).length.toString() + suffix);
  }

  private paymentCheckoutPayload(action: A2uiAction): PaymentCheckoutActionPayload {
    if (action.args === undefined) {
      return JSON.parse('{}') as PaymentCheckoutActionPayload;
    }
    return action.args as PaymentCheckoutActionPayload;
  }

  private rememberPaymentCheckout(action: A2uiAction, checkoutUrl: string): void {
    const payload = this.paymentCheckoutPayload(action);
    this.checkoutWebUrl = checkoutUrl;
    this.checkoutWebKind = 'payment';
    this.paymentCheckoutProvider = this.actionText(payload.provider).trim().toLowerCase();
    this.paymentCheckoutProviderSessionId = this.actionText(payload.providerSessionId).trim();
    this.paymentCheckoutRecipient = this.actionText(payload.recipient).trim();
    this.paymentCheckoutAmountText = this.actionText(payload.amountText).trim();
    this.paymentCheckoutCurrency = this.actionText(payload.currency).trim();
    this.paymentCheckoutNote = this.actionText(payload.note).trim();
  }

  private queryValue(url: string, key: string): string {
    const marker = key + '=';
    const queryIndex = url.indexOf('?');
    if (queryIndex < 0) {
      return '';
    }
    const query = url.substring(queryIndex + 1);
    const parts = query.split('&');
    for (let index = 0; index < parts.length; index++) {
      if (parts[index].startsWith(marker)) {
        return decodeURIComponent(parts[index].substring(marker.length));
      }
    }
    return '';
  }

  private async handlePaymentCheckoutReturn(url: string): Promise<void> {
    this.showCheckoutWeb = false;
    const lower = url.toLowerCase();
    if (lower.indexOf('/cancel') >= 0) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '支付页面已取消，没有完成扣款。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      return;
    }
    if (this.paymentCheckoutProvider !== 'paypal') {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '支付页面已返回 app，请在供应商页面确认支付状态。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      return;
    }
    const orderId = this.paymentCheckoutProviderSessionId.length > 0 ?
      this.paymentCheckoutProviderSessionId : this.queryValue(url, 'token');
    if (orderId.length === 0) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: 'PayPal 已返回 app，但缺少 order id，不能 capture。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: url
      }));
      return;
    }
    const args: PaymentCaptureArgs = {
      provider: 'paypal',
      recipient: this.paymentCheckoutRecipient,
      amountText: this.paymentCheckoutAmountText,
      currency: this.paymentCheckoutCurrency,
      note: this.paymentCheckoutNote,
      phase: 'capture',
      providerSessionId: orderId
    };
    await this.callToolById('payment.send', 'PayPal payment approved, capture order ' + orderId, 'payment.capture', args);
  }

  private async saveDynamicCredentialAndTest(action: A2uiAction): Promise<void> {
    let payload: HtmlDynamicCredentialPayload;
    try {
      payload = JSON.parse(action.prompt) as HtmlDynamicCredentialPayload;
    } catch (_error) {
      this.logHtmlHomeActionError(action, 'invalid_dynamic_payload');
      return;
    }
    const credentialRef = this.actionText(payload.credentialRef);
    const credentialValue = this.actionText(payload.credentialValue).trim();
    const data = this.currentDynamicToolConnect();
    let toolId = this.actionText(payload.toolId);
    let testPrompt = this.actionText(payload.prompt);
    if (toolId.length === 0 && data !== null) {
      toolId = data.toolId;
    }
    if (testPrompt.length === 0 && data !== null) {
      testPrompt = data.prompt;
    }
    if (testPrompt.length === 0) {
      testPrompt = toolId;
    }
    if (data === null || credentialRef !== data.credentialRef || toolId !== data.toolId) {
      this.logHtmlHomeActionError(action, 'dynamic_credential_not_allowed');
      return;
    }
    if (credentialRef.length === 0 || credentialValue.length === 0 || toolId.length === 0) {
      this.logHtmlHomeActionError(action, 'missing_dynamic_credential');
      return;
    }
    try {
      await new AssetCredentialStore().put(credentialRef, credentialValue);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'checking',
        message: '已保存到本机，正在测试连接。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      await this.callToolById(toolId, testPrompt, 'dynamic_test_connection');
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '凭据保存失败，请检查本机安全存储状态。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      aiLogError('[AIPhone][HtmlHomeAction] id=' + action.id + ' ok=false reason=credential_save_failed message=' + message);
    }
  }

  private rideActionArgText(action: A2uiAction, keys: string[]): string {
    const args = action.args as Record<string, RideActionArgValue> | undefined;
    if (args === undefined || args === null) {
      return '';
    }
    for (let index = 0; index < keys.length; index++) {
      const value = args[keys[index]];
      if (value !== undefined && value !== null) {
        const text = String(value).trim();
        if (text.length > 0) {
          return text;
        }
      }
    }
    return '';
  }

  private rideCachedProducts(cacheJson: string): RideCachedProduct[] {
    if (cacheJson.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(cacheJson) as Record<string, Object | string | number | boolean | null | undefined>;
      const productsValue = parsed.products;
      if (!Array.isArray(productsValue)) {
        return [];
      }
      const products: RideCachedProduct[] = [];
      productsValue.forEach((item: Object | string | number | boolean | null | undefined) => {
        if (item === null || item === undefined || typeof item !== 'object' || Array.isArray(item)) {
          return;
        }
        const record = item as Record<string, RideActionArgValue>;
        const productName = String(record.productName === undefined || record.productName === null ? '' : record.productName).trim();
        const productCategory = String(record.productCategory === undefined || record.productCategory === null ? '' : record.productCategory).trim();
        const priceText = String(record.priceText === undefined || record.priceText === null ? '' : record.priceText).trim();
        if (productName.length > 0 || priceText.length > 0) {
          products.push({
            productName: productName.length > 0 ? productName : '车型',
            productCategory: productCategory,
            priceText: priceText
          });
        }
      });
      return products;
    } catch (_error) {
      return [];
    }
  }

  private rideTraceIdFromCache(cacheJson: string): string {
    try {
      const parsed = JSON.parse(cacheJson) as Record<string, RideActionArgValue>;
      const traceId = parsed.traceId;
      return traceId === undefined || traceId === null ? '' : String(traceId).trim();
    } catch (_error) {
      return '';
    }
  }

  private rideConfirmActionFromCache(
    product: RideCachedProduct,
    traceId: string,
    routeText: string,
    pickupLocation: string,
    destinationLocation: string,
    estimateCacheJson: string,
    isPrimary: boolean
  ): A2uiAction {
    const args: RideLocalOrderActionArgs = {
      productCategory: product.productCategory,
      product_category: product.productCategory,
      productName: product.productName,
      priceText: product.priceText,
      routeText: routeText,
      pickupLocation: pickupLocation,
      originLocation: pickupLocation,
      destinationLocation: destinationLocation,
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

  private restoreRideVehicleSelection(action: A2uiAction): void {
    const estimateCacheJson = this.rideActionArgText(action, ['estimateCacheJson']);
    const products = this.rideCachedProducts(estimateCacheJson);
    const traceId = this.rideTraceIdFromCache(estimateCacheJson);
    if (products.length === 0 || traceId.length === 0) {
      this.logHtmlHomeActionError(action, 'missing_ride_estimate_cache');
      return;
    }
    const model = this.parsedDataModel();
    if (model === null) {
      this.logHtmlHomeActionError(action, 'invalid_ride_surface_model');
      return;
    }
    const routeText = this.rideActionArgText(action, ['routeText', 'route']);
    const pickupLocation = this.rideActionArgText(action, ['pickupLocation', 'originLocation']);
    const destinationLocation = this.rideActionArgText(action, ['destinationLocation']);
    const rows: A2uiLabelValueData[] = [];
    if (routeText.length > 0) {
      rows.push({ label: '路线', value: routeText });
    }
    if (pickupLocation.length > 0) {
      rows.push({ label: '起点坐标', value: pickupLocation });
    }
    if (destinationLocation.length > 0) {
      rows.push({ label: '终点坐标', value: destinationLocation });
    }
    products.forEach((product: RideCachedProduct) => {
      const category = product.productCategory.length > 0 ? '（' + product.productCategory + '）' : '';
      rows.push({ label: product.productName + category, value: product.priceText });
    });
    rows.push({ label: 'traceId', value: traceId.length > 16 ? traceId.substring(0, 8) + '...' + traceId.substring(traceId.length - 6) : traceId });
    rows.push({ label: '来源', value: '滴滴 taxi_estimate（已恢复）' });
    const actions: A2uiAction[] = [];
    products.forEach((product: RideCachedProduct) => {
      if (product.productCategory.length > 0) {
        actions.push(this.rideConfirmActionFromCache(
          product,
          traceId,
          routeText,
          pickupLocation,
          destinationLocation,
          estimateCacheJson,
          actions.length === 0
        ));
      }
    });
    const result: A2uiGenericToolResultData = {
      sourceTag: '滴滴',
      toolName: 'ride.estimate',
      title: '滴滴价格预估',
      status: 'success',
      summary: '已恢复之前查询到的车型选择。',
      rows: rows,
      rawPreview: '{"restored":true}',
      actions: actions
    };
    model.genericToolResults = [result];
    model.summary = {
      text: result.summary,
      toolName: 'ride.estimate',
      dataLabel: 'genericToolResults',
      count: 1
    };
    const nextSurface = this.surfaceSnapshot(this.currentSurface);
    nextSurface.title = '滴滴价格预估';
    nextSurface.status = 'ready';
    nextSurface.dataModelJson = JSON.stringify(model);
    nextSurface.sequence = this.currentSurface.sequence + 1;
    this.applySurface(nextSurface);
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'ready',
      message: '已恢复车型选择页。',
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
  }

  private async handleClientAction(action: A2uiAction): Promise<void> {
    aiLogInfo('[AIPhone][A2uiHomeClientAction] id=' + action.id);
    if (action.id === 'html_mail_calendar_add') {
      await this.addSuggestedMailCalendarEvent(action);
      return;
    }
    if (action.id === 'html_mail_reply_save' || action.id === 'html_mail_reply_send') {
      if (action.args === undefined) {
        this.logHtmlHomeActionError(action, 'missing_mail_reply_args');
        return;
      }
      const command = action.args as MailReplyCommand;
      const requestKey = this.actionText(command.requestKey).trim();
      const operation = action.id === 'html_mail_reply_save' ? 'draft' : 'send';
      if (requestKey.length === 0 || this.actionText(command.provider).trim().length === 0 ||
        this.actionText(command.body).trim().length === 0) {
        this.logHtmlHomeActionError(action, 'invalid_mail_reply_args');
        return;
      }
      try {
        let result: MailReplyOperationResult;
        if (operation === 'draft') {
          result = await saveConfiguredMailDraft(command);
        } else {
          result = await sendConfiguredMailReply(command);
        }
        this.mailReplyOperationEvent(requestKey, operation, result.status, result.message, '');
      } catch (error) {
        const message = error instanceof Error ? error.message : JSON.stringify(error);
        this.mailReplyOperationEvent(requestKey, operation, 'error', '', message);
        aiLogError('[AIPhone][MailReplyOperationFailed] provider=' + this.actionText(command.provider) +
          ' operation=' + operation + ' error=' + message.substring(0, 240));
      }
      return;
    }
    if (action.id === 'html_mail_reply_ai_generate') {
      await this.generateMailReplyDraft(action);
      return;
    }
    if (this.isPersonaEditorAction(action)) {
      this.openPersonaEditor(action.prompt, action.id === 'persona_soul_edit' ? 'soul' : 'memory');
      return;
    }
    if (action.id === 'stripe.account.open') {
      const onboardingUrl = this.stripeOnboardingUrlForAction(action);
      if (!this.isStripeOnboardingUrl(onboardingUrl)) {
        this.logHtmlHomeActionError(action, 'invalid_stripe_onboarding_url');
        return;
      }
      await this.openExternalUrl(onboardingUrl);
      return;
    }
    if (action.id === 'luckin.demo.googlepay.return') {
      this.restoreLuckinReturnSurface(action.prompt.length > 0 ? action.prompt : action.id);
      return;
    }
    if (action.id === 'hotel.search.restore') {
      if (this.multiAgentRuntime !== null) {
        const restored = this.multiAgentRuntime.restoreSearchSurface();
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: restored,
          status: restored ? 'ready' : 'error',
          message: restored ? '已返回酒店搜索结果。' : '酒店搜索结果已失效。',
          requestDebug: this.lastModelRequest,
          assistantDebug: this.lastModelOutput,
          error: restored ? '' : 'hotel search surface restore rejected'
        }));
        if (restored) {
          this.hotelReturnSurface = null;
        }
        return;
      }
      this.restoreHotelReturnSurface(action.prompt.length > 0 ? action.prompt : action.id);
      return;
    }
    if (this.isStripeReceivingActionId(action)) {
      await this.callToolById(
        'payment.account.setup',
        action.prompt.length > 0 ? action.prompt : action.label,
        action.id,
        action.args === undefined ? null : action.args
      );
      return;
    }
    if (this.isSocialHubActionId(action) && !this.isCurrentSocialHubSurface()) {
      this.logHtmlHomeActionError(action, 'social_hub_surface_required');
      return;
    }
    if (action.id === 'social_hub_select_item') {
      this.selectSocialHubItem(action);
      return;
    }
    if (action.id === 'social_hub_draft_reply') {
      this.draftSocialHubReply(action);
      return;
    }
    if (action.id === 'social_hub_send_reply') {
      await this.sendSocialHubReply(action);
      return;
    }
    if (action.id === 'social_hub_authorize') {
      await this.openSocialHubComposioAuth(action.prompt);
      return;
    }
    if (action.id === 'social_hub_open_source') {
      await this.openSocialHubSource(action);
      return;
    }
    if (await this.handleHtmlFoodMapAction(action)) {
      return;
    }
    if (await this.handleHtmlPinAction(action)) {
      return;
    }
    if (action.id === 'html_dynamic_save_and_test') {
      await this.saveDynamicCredentialAndTest(action);
      return;
    }
    if (action.id === 'payment.account.save') {
      await this.savePaymentAccount(action);
      return;
    }
    if (action.id === 'payment.checkout.open') {
      const checkoutUrl = this.paymentCheckoutUrlForAction(action);
      if (!this.isPaymentCheckoutUrl(checkoutUrl)) {
        this.logHtmlHomeActionError(action, 'invalid_payment_checkout_url');
        return;
      }
      this.rememberPaymentCheckout(action, checkoutUrl);
      this.checkoutWebKind = 'payment';
      this.showCheckoutWeb = true;
      aiLogInfo('[AIPhone][PaymentCheckoutOpen] urlChars=' + checkoutUrl.length.toString());
      return;
    }
    if (action.id === 'train.booking.open') {
      const bookingUrl = this.trainBookingUrlForAction(action);
      if (!isAllowed12306BookingUrl(bookingUrl)) {
        this.logHtmlHomeActionError(action, 'invalid_12306_booking_url');
        return;
      }
      this.checkoutWebKind = 'train';
      this.checkoutWebUrl = bookingUrl;
      this.showCheckoutWeb = true;
      aiLogInfo('[AIPhone][TrainBookingOpen] urlChars=' + bookingUrl.length.toString());
      return;
    }
    if (action.id === 'luckin.pay.open') {
      const payUrl = await this.resolveLuckinPayUrlForAction(action);
      if (!this.isLuckinPayUrl(payUrl)) {
        this.logLuckinPaymentAction(action, 'invalid_pay_url');
        this.logHtmlHomeActionError(action, 'invalid_luckin_pay_url');
        return;
      }
      aiLogInfo('[AIPhone][LuckinWechatPayOpen] chars=' + payUrl.length.toString());
      await this.openExternalUrl(payUrl, ['https', 'weixin']);
      return;
    }
    if (action.id === 'luckin.demo.alipay.open') {
      const url = action.prompt.trim().length > 0 ? action.prompt.trim() : 'alipays://';
      aiLogInfo('[AIPhone][LuckinDemoAlipayOpen] chars=' + url.length.toString());
      await this.openExternalUrl(url, ['alipays']);
      return;
    }
    if (action.id === 'luckin.demo.googlepay.open') {
      this.rememberLuckinReturnSurface(action.id);
      const args: PaymentFallbackArgs = {
        provider: 'paypal',
        fundingSource: 'google_pay',
        recipient: '罗一格',
        amountText: '5',
        currency: 'USD',
        note: 'Luckin Google Pay demo only; does not pay the Luckin order.',
        originalQuery: '用 Google Pay 给罗一格转 5 美金'
      };
      aiLogInfo('[AIPhone][LuckinDemoGooglePayPayment] recipient=' + args.recipient +
        ' amount=' + args.amountText + ' currency=' + args.currency);
      await this.callToolById(
        'payment.send',
        '用 Google Pay 给罗一格转 5 美金',
        action.id,
        args
      );
      return;
    }
    if (action.id === 'gmail.authorize') {
      const authorizeUrl = await prepareGmailOAuthAuthorizationUrl();
      await this.openExternalUrl(authorizeUrl.length > 0 ? authorizeUrl : GMAIL_MCP_AUTH_SETUP_URL);
      return;
    }
    if (action.id === 'calendar.authorize') {
      const authorizeUrl = await prepareGoogleOAuthAuthorizationUrl(GOOGLE_OAUTH_SETUP_URL);
      await this.openExternalUrl(authorizeUrl.length > 0 ? authorizeUrl : GOOGLE_OAUTH_SETUP_URL);
      return;
    }
    if (action.id === 'calendar.open.web') {
      await this.openExternalUrl(action.prompt.length > 0 ? action.prompt : GOOGLE_CALENDAR_WEB_URL);
      return;
    }
    if (action.id === 'gmail.open.web') {
      await this.openExternalUrl(action.prompt.length > 0 ? action.prompt : GMAIL_WEB_URL);
      return;
    }
    if (action.id === 'maps.open.web') {
      await this.openExternalUrl(action.prompt);
      return;
    }
    if (action.id === 'ride.vehicle.change') {
      this.restoreRideVehicleSelection(action);
      return;
    }
    if (action.id === 'ride.open.didi' || action.id === 'ride.open.amap') {
      if (action.prompt.length === 0) {
        this.logHtmlHomeActionError(action, 'missing_ride_app_link');
        return;
      }
      await this.openExternalUrl(
        action.prompt,
        action.id === 'ride.open.didi' ? ['diditaxi'] : ['amapuri']
      );
      return;
    }
    if (action.id === 'media.open.web') {
      const mediaUrl = officialMediaVideoPlaybackUrl(action.prompt);
      if (mediaUrl.length === 0) {
        this.logHtmlHomeActionError(action, 'invalid_media_url');
        return;
      }
      await this.openExternalUrl(mediaUrl);
      return;
    }
    if (action.id === 'dynamic_open_registration') {
      await this.openExternalUrl(action.prompt);
      return;
    }
    if (action.id === 'dynamic_test_connection') {
      const data = this.currentDynamicToolConnect();
      if (data === null || data.toolId.length === 0) {
        return;
      }
      const testPrompt = action.prompt.length > 0 ? action.prompt : (data.prompt.length > 0 ? data.prompt : data.toolId);
      await this.callToolById(data.toolId, testPrompt, action.id);
      return;
    }
  }

  private navigationCardStore(): PreferencesNavigationCardSnapshotStore {
    const context = this.getUIContext().getHostContext() as common.Context;
    return new PreferencesNavigationCardSnapshotStore(context);
  }

  private async refreshNavigationCardForms(snapshot: NavigationCardSnapshot): Promise<void> {
    const store = this.navigationCardStore();
    const formIds = await store.getFormIds();
    if (formIds.length === 0) {
      aiLogInfo('[AIPhone][NavigationCardRefresh] noForms title=' + snapshot.title);
      return;
    }
    const binding = formBindingData.createFormBindingData(buildNavigationCardBindingData(snapshot, Date.now()));
    for (let index = 0; index < formIds.length; index++) {
      const formId = formIds[index];
      try {
        await formProvider.updateForm(formId, binding);
        aiLogInfo('[AIPhone][NavigationCardRefresh] formId=' + formId + ' ok=true');
      } catch (error) {
        const businessError = error as BusinessError;
        aiLogError('[AIPhone][NavigationCardRefresh] formId=' + formId +
          ' ok=false code=' + (businessError.code === undefined || businessError.code === null ? 'unknown' : businessError.code.toString()) +
          ' message=' + businessError.message);
      }
    }
  }

  private async saveNavigationCardResult(result: NavigationCardSnapshotBuildResult, label: string): Promise<void> {
    if (!result.ok || result.snapshot === undefined) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: result.error,
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: result.error
      }));
      aiLogError('[AIPhone][NavigationCardPin] ok=false label=' + label + ' reason=' + result.error);
      return;
    }
    try {
      const store = this.navigationCardStore();
      await store.saveSnapshot(result.snapshot);
      await this.refreshNavigationCardForms(result.snapshot);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '已固定为桌面导航卡片：' + (result.snapshot.cardStyle === 'travel' ? result.snapshot.routeText : result.snapshot.title),
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      aiLogInfo('[AIPhone][NavigationCardPin] ok=true title=' + result.snapshot.title +
        ' cardStyle=' + result.snapshot.cardStyle +
        ' transport=' + result.snapshot.transport +
        ' sourceTags=' + result.snapshot.sourceTags.join('/') +
        ' mapUriChars=' + result.snapshot.mapUri.length.toString());
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '导航卡片保存失败',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      aiLogError('[AIPhone][NavigationCardPin] ok=false saveError=' + message);
    }
  }

  private async pinNavigationCard(item: A2uiFoodData): Promise<void> {
    const now = Date.now();
    await this.saveNavigationCardResult(navigationCardSnapshotFromFoodOption(item, {
      surfaceId: this.currentSurface.surfaceId,
      toolId: 'food.search',
      updatedAt: now,
      expiresAt: now + NAVIGATION_CARD_TTL_MS
    }), 'food');
  }

  private async pinTravelNavigationCard(item: A2uiTravelOptionData): Promise<void> {
    const now = Date.now();
    await this.saveNavigationCardResult(navigationCardSnapshotFromTravelOption(item, {
      surfaceId: this.currentSurface.surfaceId,
      toolId: 'travel.search',
      updatedAt: now,
      expiresAt: now + NAVIGATION_CARD_TTL_MS
    }), item.source === 'flight' ? 'travel-flight' : 'travel-train');
  }

  private async pinTrainNavigationCard(item: A2uiTrainData): Promise<void> {
    const now = Date.now();
    await this.saveNavigationCardResult(navigationCardSnapshotFromTrainOption(item, {
      surfaceId: this.currentSurface.surfaceId,
      toolId: 'train.search',
      updatedAt: now,
      expiresAt: now + NAVIGATION_CARD_TTL_MS
    }), 'train');
  }

  private async pinFlightNavigationCard(item: A2uiFlightData): Promise<void> {
    const now = Date.now();
    await this.saveNavigationCardResult(navigationCardSnapshotFromFlightOption(item, {
      surfaceId: this.currentSurface.surfaceId,
      toolId: 'flight.search',
      updatedAt: now,
      expiresAt: now + NAVIGATION_CARD_TTL_MS
    }), 'flight');
  }

  private focusEditQuery(actionId: string = ''): void {
    if (actionId === 'travel_change_date') {
      this.inputPlaceholder = '请输入新的日期或路线，如：后天北京到上海出行方案';
      this.inputText = '';
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '请在输入框补充新的日期或路线。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      return;
    }
    this.inputPlaceholder = TRAIN_EDIT_QUERY_PLACEHOLDER;
    this.inputText = '';
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'ready',
      message: '请在输入框补充具体查询条件。',
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
  }

  private async sendAction(action: A2uiAction): Promise<void> {
    this.mailDetailSuggestionGuard.invalidateForPageAction(action.id);
    if (this.isLuckinPaymentActionId(action.id)) {
      this.logLuckinPaymentAction(action, 'received');
    }
    if (this.isBusy) {
      if (this.isLuckinPaymentActionId(action.id)) {
        this.logLuckinPaymentAction(action, 'ignored_busy');
      }
      aiLogInfo('[AIPhone][A2uiHomeActionIgnored] id=' + action.id + ' reason=busy');
      return;
    }
    if (this.isSocialHubActionId(action) && !this.isCurrentSocialHubSurface()) {
      this.logHtmlHomeActionError(action, 'social_hub_surface_required');
      return;
    }
    if (this.isSocialHubClientAction(action)) {
      await this.handleClientAction(action);
      return;
    }
    if (this.isPersonaEditorAction(action)) {
      await this.handleClientAction(action);
      return;
    }
    const renderedSnapshot = this.registeredPageSnapshotStore.current();
    const document = renderedSnapshot === null ?
      this.currentHtmlHomeDocument() : renderedSnapshot.document;
    if (!isHtmlHomeActionAllowed(document, action)) {
      if (this.isLuckinPaymentActionId(action.id)) {
        this.logLuckinPaymentAction(action, 'blocked_not_allowed');
      }
      this.logHtmlHomeActionError(action, 'not_allowed');
      return;
    }
    if (this.isLuckinPaymentActionId(action.id)) {
      this.logLuckinPaymentAction(action, 'dispatch');
    }
    await dispatchRegisteredPageActionCandidate(
      action,
      (clicked: A2uiAction): Promise<boolean> => this.runRegisteredPageAction(clicked),
      (legacy: A2uiAction): Promise<void> => this.sendLegacyAction(legacy, document)
    );
  }

  private async runRegisteredPageAction(action: A2uiAction): Promise<boolean> {
    const snapshot = this.registeredPageSnapshotStore.current();
    const actionGeneration = this.runtimeGeneration;
    if (snapshot === null || !runtimeSurfaceIdentityMatches(
      this.currentSurface,
      snapshot.surface,
      this.activeRuntimeOwner,
      actionGeneration
    )) {
      return false;
    }
    const runtime = this.canaryRuntime();
    this.isBusy = true;
    try {
      const ok = await runtime.runPageAction(action);
      if (!runtimeCallbackIsCurrent(
        this.activeRuntimeOwner, this.runtimeGeneration, 'multi_agent', actionGeneration
      )) {
        return false;
      }
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok,
        status: ok ? 'ready' : 'error',
        message: ok ? '操作已处理。' : '操作已被当前页面权限拒绝。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ok ? '' : 'registered action 与当前已渲染页面快照不匹配'
      }));
      return ok;
    } finally {
      if (runtimeCallbackIsCurrent(
        this.activeRuntimeOwner, this.runtimeGeneration, 'multi_agent', actionGeneration
      )) {
        this.isBusy = false;
      }
    }
  }

  private async sendLegacyAction(
    action: A2uiAction,
    document: HtmlHomeDocument
  ): Promise<void> {
    if (this.multiAgentRuntime !== null && this.activeRuntimeOwner === 'multi_agent' &&
      action.id === 'hotel.detail') {
      const runtime = this.multiAgentRuntime;
      const actionGeneration = this.runtimeGeneration;
      const snapshot = this.registeredPageSnapshotStore.current();
      const context = runtime.currentActionContext();
      if (snapshot === null || context === null ||
        !runtimeSurfaceIdentityMatches(
          this.currentSurface,
          snapshot.surface,
          this.activeRuntimeOwner,
          actionGeneration
        ) ||
        context.surfaceId !== snapshot.surface.surfaceId ||
        context.sourceToolId !== 'hotel.search' ||
        document.surfaceId !== snapshot.document.surfaceId ||
        document.generatedAt !== snapshot.document.generatedAt ||
        !isHtmlHomeActionAllowed(document, action)) {
        this.logHtmlHomeActionError(action, 'hotel_context_not_current');
        return;
      }
      this.isBusy = true;
      try {
        const ok = await runtime.runAction(action, context);
        if (!runtimeCallbackIsCurrent(
          this.activeRuntimeOwner, this.runtimeGeneration, 'multi_agent', actionGeneration
        )) {
          return;
        }
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: ok,
          status: ok ? 'ready' : 'error',
          message: ok ? '酒店操作已处理。' : '酒店操作已被当前页面权限拒绝。',
          requestDebug: this.lastModelRequest,
          assistantDebug: this.lastModelOutput,
          error: ok ? '' : '酒店 action 与当前 surface/document 不匹配'
        }));
      } finally {
        if (runtimeCallbackIsCurrent(
          this.activeRuntimeOwner, this.runtimeGeneration, 'multi_agent', actionGeneration
        )) {
          this.isBusy = false;
        }
      }
      return;
    }
    const kind = action.kind.length > 0 ? action.kind : 'prompt';
    if (this.activeRuntimeOwner === 'multi_agent' ||
      runtimeOwnerAllowsSurfaceAction(this.currentSurface, 'multi_agent')) {
      if (kind === 'client') {
        await this.handleClientAction(action);
      } else if (kind === 'input') {
        this.focusEditQuery(action.id);
      } else {
        this.logHtmlHomeActionError(action, 'runtime_owner_mismatch');
      }
      return;
    }
    const directPaymentToolId = directPaymentToolIdForActionId(action.id);
    if (directPaymentToolId.length > 0) {
      await this.callToolById(
        directPaymentToolId,
        action.prompt.length > 0 ? action.prompt : action.label,
        action.id,
        action.args === undefined ? null : action.args
      );
      return;
    }
    const directRideToolId = directRideToolIdForActionId(action.id);
    if (directRideToolId.length > 0) {
      await this.callToolById(
        directRideToolId,
        action.prompt.length > 0 ? action.prompt : action.label,
        action.id,
        action.args === undefined ? null : action.args
      );
      return;
    }
    if (action.id === 'luckin.order.preview' || action.id === 'luckin.order.create' || action.id === 'luckin.order.status') {
      await this.callToolById(
        action.id,
        action.prompt.length > 0 ? action.prompt : action.label,
        action.id,
        action.args === undefined ? null : action.args
      );
      return;
    }
    if (kind === 'client') {
      await this.handleClientAction(action);
      return;
    }
    if (kind === 'input') {
      this.focusEditQuery(action.id);
      return;
    }
    await this.submitPrompt(action.prompt, action.label, action.id, action.args === undefined ? null : action.args);
  }

  private toolSurfaceId(): string {
    if (this.currentSurface.surfaceId.length === 0 || this.currentSurface.status === 'error') {
      return 'surface_model';
    }
    return this.currentSurface.surfaceId;
  }

  private configureDidiMcpSandboxRuntime(isSandbox: boolean): void {
    this.didiMcpSandboxEnabled = isSandbox;
    configureDidiMcpSandboxForRuntime(isSandbox);
    aiLogInfo('[AIPhone][A2uiHomeDidiMcpSandboxToggle] enabled=' + (isSandbox ? 'true' : 'false'));
  }

  private async invokeRegisteredPageTool(
    toolId: string,
    prompt: string,
    pageActionId: string,
    args: Object,
  ): Promise<RegisteredPageToolInvocation> {
    const observation: RegisteredPageToolObservation = { result: null };
    const ok = await this.callToolById(
      toolId,
      prompt,
      pageActionId,
      args,
      (result: A2uiCallResult): void => {
        observation.result = result;
      },
      'multi_agent'
    );
    const observed = observation.result;
    return {
      ok,
      result: observed,
      error: observed === null ?
        (ok ? '' : 'Registered page tool did not complete.') : observed.error
    };
  }

  private async callToolById(
    toolId: string,
    prompt: string,
    actionId: string,
    args: Object | null = null,
    resultObserver?: (result: A2uiCallResult) => void,
    runtimeOwner: RuntimeOwner = 'legacy'
  ): Promise<boolean> {
    const toolGeneration: number = runtimeOwner === 'legacy' ?
      (this.activeRuntimeOwner === 'legacy' && this.isBusy ?
        this.runtimeGeneration : this.beginRuntimeTurn('legacy')) : this.runtimeGeneration;
    if (runtimeOwner !== this.activeRuntimeOwner) {
      return false;
    }
    if (!isRegisteredToolId(toolId)) {
      const message = '模型请求了未注册工具：' + toolId;
      aiLogError('[AIPhone][A2uiHomeToolRequestInvalid] toolId=' + toolId);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: message,
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      return false;
    }

    aiLogInfo('[AIPhone][A2uiHomeToolRequest] toolId=' + toolId +
      ' promptChars=' + prompt.length.toString() +
      ' actionId=' + actionId +
      ' gateway=' + TOOL_GATEWAY_URL);
    if (toolId === 'worldcup.open') {
      aiLogInfo('[AIPhone][AnythingDemoRouteByTool] actionId=' + actionId +
        ' promptChars=' + prompt.length.toString());
      this.markChecking('正在打开世界杯界面...');
      const opened = await this.openAnythingDemo();
      if (!runtimeCallbackIsCurrent(
        this.activeRuntimeOwner, this.runtimeGeneration, runtimeOwner, toolGeneration
      )) {
        return false;
      }
      if (!opened) {
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: false,
          status: 'error',
          message: '无法打开世界杯界面。',
          requestDebug: this.lastModelRequest,
          assistantDebug: this.lastModelOutput,
          error: 'Anything demo route could not be opened.'
        }));
        return false;
      }
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '已打开世界杯界面。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      this.appendMessage('assistant', '已打开世界杯界面。');
      return true;
    }
    configureDidiMcpSandboxForRuntime(this.didiMcpSandboxEnabled);
    configureLocalToolDebugConfig({
      foodProviderDelayEnabled: this.foodProviderDelayEnabled,
      foodProviderDelayMs: normalizeFoodProviderDelayMs(this.foodProviderDelayMs),
      foodPartialThrottleMs: normalizeFoodPartialThrottleMs(this.foodPartialThrottleMs)
    });
    const personaSourceSurface = this.currentSurface;
    const inlineLuckinSwitch = toolId === 'luckin.order.preview' && this.isLuckinOptionSwitchArgs(args);
    if (inlineLuckinSwitch) {
      if (this.luckinOptionSwitchInFlight) {
        aiLogInfo('[AIPhone][A2uiHomeLuckinSwitchIgnored] reason=in_flight');
        return false;
      }
      this.finishLuckinOptionSwitch(true);
    }
    if (!inlineLuckinSwitch) {
      this.markChecking('正在调用工具：' + toolId);
    }
    const callArgs = await this.argsWithCurrentLocationForTool(toolId, args);
    if (!runtimeCallbackIsCurrent(
      this.activeRuntimeOwner, this.runtimeGeneration, runtimeOwner, toolGeneration
    )) {
      return false;
    }
    const result: A2uiCallResult = await callToolGateway(
      TOOL_GATEWAY_URL,
      toolId,
      prompt,
      this.toolSurfaceId(),
      actionId,
      (surface: A2uiSurfaceState, raw: string) => {
        if (inlineLuckinSwitch) {
          return;
        }
        const nextSurface = copyPersonaData(personaSourceSurface, surface);
        if (!this.applyRuntimeSurface(nextSurface, runtimeOwner, toolGeneration)) {
          return;
        }
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: true,
          status: 'checking',
          message: '工具流式更新：' + nextSurface.title,
          requestDebug: this.lastModelRequest,
          assistantDebug: raw,
          error: ''
        }));
      },
      null,
      callArgs
    );
    if (runtimeOwner !== this.activeRuntimeOwner || toolGeneration !== this.runtimeGeneration) {
      if (inlineLuckinSwitch) {
        this.finishLuckinOptionSwitch(false);
      }
      return false;
    }

    aiLogInfo('[AIPhone][A2uiHomeToolResult] ok=' + (result.ok ? 'true' : 'false') +
      ' errorChars=' + result.error.length.toString() +
      ' rawChars=' + result.raw.length.toString());
    aiLogInfo('[AIPhone][A2uiHomeToolOutput] ' + logSnippet(result.raw));
    if (resultObserver !== undefined) {
      resultObserver(result);
    }
    const resultSurface = this.ownedSurface(
      copyPersonaData(personaSourceSurface, result.surface),
      runtimeOwner,
      toolGeneration
    );
    if (inlineLuckinSwitch) {
      if (result.ok && this.applyLuckinInlineConfirmPatch(resultSurface)) {
        this.finishLuckinOptionSwitch(false);
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: true,
          status: 'ready',
          message: '规格已更新。',
          requestDebug: result.requestDebug,
          assistantDebug: result.raw.length > 0 ? result.raw : this.lastModelOutput,
          error: ''
        }));
        return true;
      }
      this.finishLuckinOptionSwitch(false);
      aiLogInfo('[AIPhone][A2uiHomeLuckinSwitchFallback] ok=' + (result.ok ? 'true' : 'false'));
    }
    if (!this.applyRuntimeSurface(resultSurface, runtimeOwner, toolGeneration)) {
      return false;
    }
    if (toolId === 'payment.account.setup') {
      await this.saveStripeReceivingProfile(resultSurface);
      if (!runtimeCallbackIsCurrent(
        this.activeRuntimeOwner, this.runtimeGeneration, runtimeOwner, toolGeneration
      )) {
        return false;
      }
    }
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: result.ok,
      status: result.ok ? 'ready' : 'error',
      message: result.ok ? resultSurface.title + ' 已返回工具结果。' : '工具返回异常，请到配置页查看详情。',
      requestDebug: result.requestDebug,
      assistantDebug: result.raw.length > 0 ? result.raw : this.lastModelOutput,
      error: result.error
    }));
    if (!result.ok) {
      this.appendMessage('assistant', '工具返回异常：' + result.error);
      return false;
    }
    if (!inlineLuckinSwitch) {
      this.appendMessage('assistant', resultSurface.title + ' 已返回 A2UI 结果。');
    }
    if (toolId === 'gmail.open.web') {
      return this.openExternalUrl(GMAIL_WEB_URL);
    }
    return true;
  }

  private async testConnection(): Promise<void> {
    if (this.isBusy) {
      return;
    }
    const trimmedBaseUrl = this.baseUrl.trim();
    if (trimmedBaseUrl.length === 0) {
      aiLogError('[AIPhone][A2uiHomeConnectionBlocked] missingBaseUrl');
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '请先填写 Base URL。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: 'Base URL 为空'
      }));
      return;
    }

    this.isBusy = true;
    aiLogInfo('[AIPhone][A2uiHomeConnectionTest] model=' + this.selectedModel + ' baseUrl=' + this.baseUrl);
    this.markChecking('正在向模型发起连接检查...');
    try {
      const result: DirectModelCallResult = await callDirectModel(
        this.getSettings(),
        CONNECTION_TEST_PROMPT,
        this.recentMessages()
      );
      aiLogInfo('[AIPhone][A2uiHomeConnectionResult] ok=' + (result.ok ? 'true' : 'false') +
        ' errorChars=' + result.error.length.toString() +
        ' rawChars=' + result.raw.length.toString() +
        ' assistantChars=' + result.assistantDebug.length.toString());
      aiLogInfo('[AIPhone][A2uiHomeConnectionOutput] ' + logSnippet(result.assistantDebug.length > 0 ? result.assistantDebug : result.raw));
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: result.ok,
        status: result.ok ? 'ready' : 'error',
        message: result.ok ? '模型连接正常，测试返回已更新到当前页面。' : '模型连接异常，请查看最近异常。',
        requestDebug: result.requestDebug,
        assistantDebug: result.assistantDebug.length > 0 ? result.assistantDebug : result.raw,
        error: result.error
      }));
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][A2uiHomeConnectionException] ' + logSnippet(message));
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '模型连接异常，请查看最近异常。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
    } finally {
      this.isBusy = false;
    }
  }

  build() {
    if (this.showComposioAuthPage) {
      ComposioAuthPage({
        userShortId: this.composioUserId,
        items: this.composioAuthItems,
        message: this.composioAuthMessage,
        isBusy: this.composioAuthBusy,
        onBack: () => {
          this.showComposioAuthPage = false;
        },
        onRefresh: () => {
          this.refreshComposioAuth();
        },
        onAuthorize: (item: ComposioAuthConfigItem) => {
          this.openComposioAuthLink(item);
        },
        onOpenExternalAuth: (url: string) => {
          this.openExternalUrl(url);
        }
      })
    } else if (this.showConfigPage) {
      ConfigPage({
        baseUrl: $baseUrl,
        apiKey: $apiKey,
        selectedModel: $selectedModel,
        customParametersJson: $customParametersJson,
        foodProviderDelayEnabled: $foodProviderDelayEnabled,
        foodProviderDelayMs: $foodProviderDelayMs,
        foodPartialThrottleMs: $foodPartialThrottleMs,
        ignoreToolSurfaceUpdates: $ignoreToolSurfaceUpdates,
        htmlHomeDebugExportEnabled: $htmlHomeDebugExportEnabled,
        htmlHomeDebugExportPath: this.htmlHomeDebugExportPath,
        didiMcpSandboxEnabled: $didiMcpSandboxEnabled,
        showAdvancedSettings: $showAdvancedSettings,
        connectionStatus: this.connectionStatus,
        connectionMessage: this.connectionMessage,
        isBusy: this.isBusy,
        lastModelRequest: this.lastModelRequest,
        lastModelOutput: this.lastModelOutput,
        lastError: this.lastError,
        refreshTick: this.refreshTick,
        personaPacks: this.personaPacks,
        selectedPersonaId: $selectedPersonaId,
        personaSoulDraft: $personaSoulDraft,
        personaMemoryDraft: $personaMemoryDraft,
        personaSaveMessage: this.personaSaveMessage,
        composioUserId: this.composioUserId,
        composioAuthItems: this.composioAuthItems,
        composioAuthMessage: this.composioAuthMessage,
        composioAuthBusy: this.composioAuthBusy,
        onBack: () => {
          this.showConfigPage = false;
        },
        onTestConnection: () => {
          this.testConnection();
        },
        onOpenComposioAuth: () => {
          this.configureComposioRuntimeForCurrentUser();
          this.showComposioAuthPage = true;
          this.refreshComposioAuth();
        },
        onRefreshComposioAuth: () => {
          this.refreshComposioAuth();
        },
        onSelectPersona: (personaId: string) => {
          this.selectPersonaForEdit(personaId);
        },
        onSavePersona: () => {
          this.savePersonaDraft();
        },
        onResetPersona: () => {
          this.resetPersonaDraft();
        },
        onExportHtmlHomeDocument: () => {
          this.exportCurrentHtmlHomeDocument();
        },
        onToggleDidiMcpSandbox: (isOn: boolean) => {
          this.configureDidiMcpSandboxRuntime(isOn);
        }
      })
    } else {
      HomePage({
        inputText: $inputText,
        isBusy: this.isBusy,
        showHistory: this.showHistory,
        messages: this.messages,
        currentSurface: this.currentSurface,
        htmlHomeHtml: this.htmlHomeHtmlForView(),
        mailDetailEventJson: this.mailDetailEventJson,
        mailReplyEventJson: this.mailReplyEventJson,
        mailCalendarEventJson: this.mailCalendarEventJson,
        surfaceRenderTick: this.surfaceRenderTick,
        luckinInlinePatchJson: this.luckinInlinePatchJson,
        luckinInlinePatchTick: this.luckinInlinePatchTick,
        isAwaitingFirstSurface: this.isAwaitingFirstSurface,
        inputPlaceholder: this.inputPlaceholder,
        isVoiceListening: this.isVoiceListening,
        voiceInputMessage: this.voiceInputMessage,
        showWelcome: shouldShowWelcome(this.isBusy, this.messages.length, this.currentSurface),
        showCheckoutWeb: this.showCheckoutWeb,
        checkoutWebKind: this.checkoutWebKind,
        checkoutWebUrl: this.checkoutWebUrl,
        onToggleHistory: () => {
          this.showHistory = !this.showHistory;
        },
        onOpenConfig: () => {
          this.configureComposioRuntimeForCurrentUser();
          this.showConfigPage = true;
          this.refreshComposioAuth();
        },
        onOpenSocialHub: () => {
          this.openSocialHub();
        },
        onResetSession: () => {
          this.resetCurrentSession();
        },
        onSendPrompt: () => {
          this.sendPrompt();
        },
        onStartVoiceInput: () => {
          this.startVoiceInput();
        },
        onStopVoiceInput: () => {
          this.stopVoiceInput();
        },
        onCloseCheckoutWeb: () => {
          const closedTrainBooking = this.checkoutWebKind === 'train';
          this.showCheckoutWeb = false;
          if (closedTrainBooking) {
            this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
              ok: true,
              status: 'ready',
              message: '订单与支付结果请以 12306 为准。',
              requestDebug: this.lastModelRequest,
              assistantDebug: this.lastModelOutput,
              error: ''
            }));
            this.getUIContext().getPromptAction().showToast({ message: '订单与支付结果请以 12306 为准。' });
          }
        },
        onCheckoutWebReturn: (url: string) => {
          this.handlePaymentCheckoutReturn(url);
        },
        onAction: (action: A2uiAction) => {
          this.sendAction(action);
        }
      })
    }
  }
}
