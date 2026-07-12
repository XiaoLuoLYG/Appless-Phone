import { describe, it, expect } from '@ohos/hypium';
import { A2uiCallResult, A2uiFoodData, A2uiLabelValueData, A2uiSurfaceState, A2uiTravelOptionData } from '@loop/agent-core';
import { genericToolResults, dynamicToolConnect } from '@loop/agent-core';
import { planA2uiPartialUpdate, A2uiPartialUpdateResult } from '@loop/agent-core';
import { buildSystemFoodNavigationUri, foodMapsLatLng } from '@loop/agent-core';
import { DynamicGenericToolResult } from '@loop/agent-core';
import { MailDraftArgs, MailSearchArgs } from '@loop/agent-core';
import {
  aggregateFoodProviderResults,
  buildToolGatewayUrl,
  callToolGateway,
  configureComposioConfigFromRawJson,
  configureLocalPaymentAccountBookJson,
  configureLocalProviderConfigFromRawJson,
  defaultToolGatewayUrl,
  foodA2uiRenderState,
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
  sortTravelOptionsByDeparture,
  streamFoodProviderResultsWithPartials,
  FoodProviderPartialSnapshot,
  FoodProviderResult
} from '@loop/agent-core';

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

export default function toolGatewayClientTest() {
  describe('toolGatewayClient', () => {
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

    it('registers Calendar and Maps tools without delete or routes', 0, () => {
      expect(isRegisteredToolId('calendar.events.search')).assertTrue();
      expect(isRegisteredToolId('calendar.event.create')).assertTrue();
      expect(isRegisteredToolId('calendar.event.update')).assertTrue();
      expect(isRegisteredToolId('maps.place.search')).assertTrue();
      expect(isRegisteredToolId('maps.place.details')).assertTrue();
      expect(isRegisteredToolId('calendar.event.delete')).assertFalse();
      expect(isRegisteredToolId('maps.route.plan')).assertFalse();
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
        expect(JSON.stringify(rendered[0].rows).indexOf('2026-07-30T15:00:00+08:00')).assertLarger(-1);
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
        expect(rendered[0].status).assertEqual('error');
        expect(rendered[0].summary.indexOf('title')).assertLarger(-1);
        expect(rendered[0].summary.indexOf('start')).assertLarger(-1);
        expect(JSON.stringify(rendered[0].rows).indexOf('2026-07-30T15:30:00+08:00')).assertLarger(-1);
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
        expect(rendered[0].status).assertEqual('error');
        expect(rendered[0].summary.indexOf('eventId')).assertLarger(-1);
        expect(rendered[0].summary.indexOf('title/start/end')).assertLarger(-1);
        expect(JSON.stringify(rendered[0].rows).indexOf('Asia/Shanghai')).assertLarger(-1);
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
