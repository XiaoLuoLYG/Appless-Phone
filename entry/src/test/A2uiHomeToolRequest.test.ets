import { describe, it, expect } from '@ohos/hypium';
import {
  directPaymentToolIdForActionId,
  directRideToolIdForActionId,
  resolveA2uiHomeToolRequest,
  surfaceHasSatisfiedToolResult,
  surfaceHasVisibleToolResult
} from '../main/ets/pages/A2uiHome/render/A2uiHomeToolRequest';
import {
  A2uiComponent,
  A2uiFlightData,
  A2uiFormData,
  A2uiFoodData,
  A2uiGenericToolResultData,
  A2uiLabelValueData,
  A2uiRuntimeDataModel,
  A2uiRowGroupsData,
  A2uiSummaryData,
  A2uiSurfaceState,
  A2uiToolRequestData,
  A2uiTravelOptionData,
  A2uiTrainData,
  A2uiTripData
} from '@loop/agent-core';
import { emptySocialHub } from '@loop/agent-core';

interface ToolRequestArgsFixture {
  query: string;
  pageSize: number;
  intentSummary: string;
}

interface GmailReplyActionArgsFixture {
  threadId: string;
  to: string[];
  subject: string;
  replyMode: string;
}

interface GmailReplyModelArgsFixture {
  body: string;
}

interface MediaOverrideArgsFixture {
  query: string;
  sources: string[];
}

interface FoodPreferenceArgsFixture {
  brandPreference: string;
  sweetness: string;
}

interface PaymentFallbackArgsFixture {
  provider: string;
  fundingSource?: string;
}

type ToolRequestArgValue = Object | string | number | boolean | null | undefined;
type ToolRequestArgRecord = Record<string, ToolRequestArgValue>;

function argText(args: Object | null, key: string): string {
  if (args === null) {
    return '';
  }
  const value = (args as ToolRequestArgRecord)[key];
  if (typeof value === 'string') {
    return value;
  }
  return '';
}

function argNumber(args: Object | null, key: string): number {
  if (args === null) {
    return 0;
  }
  const value = (args as ToolRequestArgRecord)[key];
  return typeof value === 'number' ? value : 0;
}

function argSources(args: Object | null): string[] {
  if (args === null) {
    return [];
  }
  const value = (args as ToolRequestArgRecord)['sources'];
  if (!Array.isArray(value)) {
    return [];
  }
  return value as string[];
}

function surfaceWithToolRequest(
  toolId: string,
  prompt: string,
  actionId: string,
  args: Object | null = null,
  form: A2uiFormData | null = null
): A2uiSurfaceState {
  const rows: A2uiLabelValueData[] = [];
  const thoughts: string[] = [];
  const tripRows: A2uiLabelValueData[] = [];
  const trip: A2uiTripData = {
    rows: tripRows
  };
  const trainRows: A2uiLabelValueData[] = [];
  const flightRows: A2uiLabelValueData[] = [];
  const foodRows: A2uiLabelValueData[] = [];
  const rowGroups: A2uiRowGroupsData = {
    train: trainRows,
    flight: flightRows,
    food: foodRows
  };
  const trains: A2uiTrainData[] = [];
  const flights: A2uiFlightData[] = [];
  const travelOptions: A2uiTravelOptionData[] = [];
  const foods: A2uiFoodData[] = [];
  const summary: A2uiSummaryData = {
    text: '',
    toolName: '',
    dataLabel: '',
    count: 0
  };
  const request: A2uiToolRequestData = {
    toolId: toolId,
    prompt: prompt,
    actionId: actionId
  };
  if (args !== null) {
    request.args = args;
  }
  const model: A2uiRuntimeDataModel = {
    rows: rows,
    trains: trains,
    flights: flights,
    travelOptions: travelOptions,
    foods: foods,
    thoughts: thoughts,
    summary: summary,
    trip: trip,
    rowGroups: rowGroups,
    form: form === null ? {} : form,
    toolRequest: request,
    dynamicToolConnect: {
      toolId: '',
      prompt: '',
      manifestId: '',
      displayName: '',
      sourceUrl: '',
      status: '',
      message: '',
      credentialName: '',
      credentialRef: '',
      registrationUrl: '',
      actions: []
    },
    genericToolResults: [],
    socialHub: emptySocialHub(),
    persona: { id: '', name: '', avatarKey: '', status: '', reason: '' },
    personaMemory: { summary: '', preferences: [] }
  };
  const components: A2uiComponent[] = [];
  return {
    surfaceId: 's',
    rootId: 'root',
    title: '测试',
    intent: 'general',
    status: 'calling_tool',
    components: components,
    dataModelJson: JSON.stringify(model),
    error: '',
    sequence: 1
  };
}

function surfaceWithSummaryToolResult(summaryToolName: string, resultToolName: string): A2uiSurfaceState {
  const surface = surfaceWithToolRequest('', '', '');
  const model = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
  model.summary.toolName = summaryToolName;
  const result: A2uiGenericToolResultData = {
    sourceTag: 'Gmail API',
    toolName: resultToolName,
    title: 'Search results',
    status: 'success',
    summary: '',
    rows: [],
    rawPreview: ''
  };
  model.genericToolResults = [result];
  surface.dataModelJson = JSON.stringify(model);
  return surface;
}

function surfaceWithSocialHubComponent(): A2uiSurfaceState {
  const surface = surfaceWithToolRequest('', '', '');
  const component: A2uiComponent = {
    id: 'social_hub',
    component: 'SocialHub',
    title: '社交工作台',
    dataPath: '/socialHub/items',
    status: 'ready'
  };
  surface.components = [component];
  return surface;
}

export default function a2uiHomeToolRequestTest() {
  describe('a2uiHomeToolRequest', () => {
    it('uses the model tool request when present', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('train.search', '查明天北京到上海高铁', 'model_tool_request'),
        '用户原始请求',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('train.search');
      expect(resolved.prompt).assertEqual('查明天北京到上海高铁');
      expect(resolved.actionId).assertEqual('model_tool_request');
    });

    it('falls back to user prompt and action id when model omits them', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('food.search', '', ''),
        '附近有什么吃的',
        'retry_food'
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('food.search');
      expect(resolved.prompt).assertEqual('附近有什么吃的');
      expect(resolved.actionId).assertEqual('retry_food');
    });

    it('reports no tool when the prompt has no tool intent', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(surfaceWithToolRequest('', '', ''), '你好', '');

      expect(resolved.hasTool).assertFalse();
      expect(resolved.toolId).assertEqual('');
    });

    it('treats summary toolName as a satisfied tool result', 0, () => {
      const surface = surfaceWithSummaryToolResult('gmail.mail.search', 'users.threads.list');

      expect(surfaceHasSatisfiedToolResult(surface, 'gmail.mail.search')).assertTrue();
    });

    it('treats Gmail API tool names as satisfied Gmail app tools', 0, () => {
      const draftSurface = surfaceWithSummaryToolResult('', 'users.drafts.create');
      const searchSurface = surfaceWithSummaryToolResult('', 'users.threads.list');

      expect(surfaceHasSatisfiedToolResult(draftSurface, 'gmail.draft.create')).assertTrue();
      expect(surfaceHasSatisfiedToolResult(searchSurface, 'gmail.mail.search')).assertTrue();
    });

    it('treats SocialHub surfaces as satisfied social tool results', 0, () => {
      const surface = surfaceWithSocialHubComponent();

      expect(surfaceHasSatisfiedToolResult(surface, 'social.feed.search')).assertTrue();
      expect(surfaceHasSatisfiedToolResult(surface, 'x.post.search')).assertFalse();
    });

    it('detects visible tool results before intent fallback reruns another tool', 0, () => {
      expect(surfaceHasVisibleToolResult(surfaceWithToolRequest('', '', ''))).assertFalse();
      expect(surfaceHasVisibleToolResult(surfaceWithSummaryToolResult('', 'mail.search'))).assertTrue();
      expect(surfaceHasVisibleToolResult(surfaceWithSocialHubComponent())).assertTrue();
    });

    it('infers food search when the model omits a tool request for nearby food', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我搜索深圳坂田华为基地附近的奶茶店',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('food.search');
      expect(resolved.prompt).assertEqual('帮我搜索深圳坂田华为基地附近的奶茶店');
      expect(resolved.actionId).assertEqual('client_intent_fallback');
    });

    it('does not reroute explicit Google Maps POI requests to food search', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我用 Google Maps 搜索深圳坂田华为基地附近的咖啡店',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('maps.place.search');
      expect(resolved.actionId).assertEqual('client_intent_fallback');
    });

    it('infers PayPal payment only for explicit payment prompts', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '用 PayPal 给 Alex 转 5 美元',
        ''
      );
      const args = resolved.args as PaymentFallbackArgsFixture;

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('payment.send');
      expect(resolved.actionId).assertEqual('client_intent_fallback');
      expect(args.provider).assertEqual('paypal');
    });

    it('treats Google Pay as a funding source for payment prompts', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '用 Google Pay 给罗一格转账 5 美元',
        ''
      );
      const args = resolved.args as PaymentFallbackArgsFixture;

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('payment.send');
      expect(args.provider).assertEqual('');
      expect(args.fundingSource).assertEqual('google_pay');
    });

    it('routes Stripe receiving-account setup separately from payments', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '开通 Stripe 收款账户',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('payment.account.setup');
      expect(resolved.actionId).assertEqual('client_intent_fallback');
    });

    it('routes Stripe receiving-account actions back to setup', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '打开 Stripe 认证',
        'stripe.account.onboard'
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('payment.account.setup');
      expect(resolved.actionId).assertEqual('stripe.account.onboard');
    });

    it('keeps payment confirmation actions off the model path', 0, () => {
      expect(directPaymentToolIdForActionId('payment.confirm')).assertEqual('payment.send');
      expect(directPaymentToolIdForActionId('payment.capture')).assertEqual('payment.send');
      expect(directPaymentToolIdForActionId('payment.checkout.open')).assertEqual('');
    });

    it('keeps ride order confirmation actions off the model path', 0, () => {
      expect(directRideToolIdForActionId('ride.order.confirm')).assertEqual('ride.order.create');
      expect(directRideToolIdForActionId('ride.order.cancel')).assertEqual('ride.order.cancel');
      expect(directRideToolIdForActionId('ride.driver.location.refresh')).assertEqual('ride.driver.location');
      expect(directRideToolIdForActionId('ride.vehicle.change')).assertEqual('');
      expect(directRideToolIdForActionId('ride.open.didi')).assertEqual('');
    });

    it('reroutes model note tool to payment for explicit Stripe payment prompts', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('note', '请确认支付信息', 'model_tool_request'),
        '用 Stripe 给真实商户付款',
        ''
      );
      const args = resolved.args as PaymentFallbackArgsFixture;

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('payment.send');
      expect(resolved.actionId).assertEqual('client_payment_explicit_reroute');
      expect(args.provider).assertEqual('stripe');
    });

    it('does not infer payment for generic provider setup questions', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        'Stripe 是不是必须要商户账号',
        ''
      );

      expect(resolved.hasTool).assertFalse();
      expect(resolved.toolId).assertEqual('');
    });

    it('reroutes model-selected maps to food search when Google Maps is not explicit', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('maps.place.search', '帮我查深圳坂田华为基地附近的咖啡店', 'model_tool_request'),
        '帮我查深圳坂田华为基地附近的咖啡店',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('food.search');
      expect(resolved.actionId).assertEqual('client_maps_safety_reroute');
    });

    it('preserves food preference args from model tool request', 0, () => {
      const args: FoodPreferenceArgsFixture = {
        brandPreference: '瑞幸',
        sweetness: '半糖'
      };
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('food.search', '点一杯咖啡', 'model_tool_request', args),
        '点一杯咖啡',
        ''
      );

      expect(resolved.toolId).assertEqual('food.search');
      expect(argText(resolved.args, 'brandPreference')).assertEqual('瑞幸');
      expect(argText(resolved.args, 'sweetness')).assertEqual('半糖');
    });

    it('keeps explicit gmap requests on Google Maps search', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我用 gmap 搜索深圳坂田华为基地附近的咖啡店',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('maps.place.search');
      expect(resolved.actionId).assertEqual('client_intent_fallback');
    });

    it('reroutes explicit googlemap food prompts back to Google Maps search', 0, () => {
      const prompt = '帮我用googlemap查询伦敦国王十字车站附近的中餐厅';
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('food.search', prompt, 'model_tool_request'),
        prompt,
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('maps.place.search');
      expect(resolved.actionId).assertEqual('client_maps_explicit_reroute');
    });

    it('falls back Bilibili video prompts to media search with Bilibili source', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', '', null),
        '帮我在 B 站搜索 qwen max 官方介绍视频',
        ''
      );
      const sources = argSources(resolved.args);

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('media.video.search');
      expect(sources.length).assertEqual(1);
      expect(sources[0]).assertEqual('bilibili');
      expect(argText(resolved.args, 'query')).assertEqual('');
    });

    it('falls back generic video aggregation prompts to YouTube and Bilibili media search', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', '', null),
        '帮我聚合 qwen max 官方介绍视频',
        ''
      );
      const sources = argSources(resolved.args);

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('media.video.search');
      expect(sources.length).assertEqual(2);
      expect(sources[0]).assertEqual('youtube');
      expect(sources[1]).assertEqual('bilibili');
      expect(argText(resolved.args, 'query')).assertEqual('');
    });

    it('reroutes mistaken dynamic media prompts to aggregate video search', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('dynamic.search', '帮我在b站和youtube里搜索qwen max 的官方视频', 'model_tool_request', null),
        '帮我在b站和youtube里搜索qwen max 的官方视频',
        ''
      );
      const sources = argSources(resolved.args);

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('media.video.search');
      expect(resolved.actionId).assertEqual('client_media_explicit_reroute');
      expect(sources.length).assertEqual(2);
      expect(sources[0]).assertEqual('youtube');
      expect(sources[1]).assertEqual('bilibili');
    });

    it('keeps explicit media source args over fallback media sources', 0, () => {
      const overrideArgs: MediaOverrideArgsFixture = {
        query: 'qwen max',
        sources: ['bilibili']
      };
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('media.video.search', '帮我聚合 qwen max 官方介绍视频', 'model_tool_request', overrideArgs),
        '帮我聚合 qwen max 官方介绍视频',
        ''
      );
      const sources = argSources(resolved.args);

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('media.video.search');
      expect(sources.length).assertEqual(1);
      expect(sources[0]).assertEqual('bilibili');
      expect(argText(resolved.args, 'query')).assertEqual('qwen max');
    });

    it('falls back explicit YouTube video search to YouTube only', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', '', null),
        '帮我在 YouTube 搜索 qwen max 官方介绍视频',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('youtube.video.search');
      expect(argText(resolved.args, 'query')).assertEqual('帮我在 YouTube 搜索 qwen max 官方介绍视频');
      expect(argSources(resolved.args).length).assertEqual(0);
    });

    it('routes YouTube account playlist prompts to the fixed playlist tool', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', '', null),
        '帮我查看我的 YouTube 播放列表',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('youtube.mine.playlists');
    });

    it('adds YouTube hotness fallback args for five hottest videos', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('youtube.video.search', '帮我在 YouTube 上搜索五个最火的世界杯视频', 'model_tool_request', null),
        '帮我在 YouTube 上搜索五个最火的世界杯视频',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('youtube.video.search');
      expect(argText(resolved.args, 'order')).assertEqual('viewCount');
      expect(argNumber(resolved.args, 'maxResults')).assertEqual(5);
    });

    it('adds YouTube hotness fallback args for English most-viewed prompts', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', '', null),
        'Search YouTube for 5 most viewed World Cup videos',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('youtube.video.search');
      expect(argText(resolved.args, 'order')).assertEqual('viewCount');
      expect(argNumber(resolved.args, 'maxResults')).assertEqual(5);
    });

    it('infers SocialHub feed, X public search, and social drafts conservatively', 0, () => {
      const feed = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '打开社交消息聚合，看看 Slack、X、企业微信',
        ''
      );
      const xPost = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我搜索 x.com 上 openai 最近的公开 post',
        ''
      );
      const standaloneX = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我搜索 X 上 openai 最近的公开动态',
        ''
      );
      const draft = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我给 Slack 这条社交消息起草回复草稿',
        ''
      );
      const notDraft = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我回复刚才的邮件',
        ''
      );

      expect(feed.toolId).assertEqual('social.feed.search');
      expect(xPost.toolId).assertEqual('x.post.search');
      expect(standaloneX.toolId).assertEqual('x.post.search');
      expect(draft.toolId).assertEqual('social.reply.draft');
      expect(notDraft.toolId).assertEqual('mail.draft.create');
    });

    it('routes Composio-backed SaaS prompts to dynamic search before fixed social fallbacks', 0, () => {
      const googleDocs = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我在 Google Docs 里找 AIPhoneDemo 设计文档',
        ''
      );
      const composioSlack = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('social.feed.search', '帮我用 Composio Slack 查最近提到 AIPhoneDemo 的消息', 'model_tool_request'),
        '帮我用 Composio Slack 查最近提到 AIPhoneDemo 的消息',
        ''
      );
      const outlook = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我用 Outlook 查最近和 AIPhoneDemo 相关的邮件',
        ''
      );
      const discord = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我用 Discord 查最近提到 AIPhoneDemo 的消息',
        ''
      );
      const plainSlack = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我查看 Slack 最近的消息',
        ''
      );

      expect(googleDocs.toolId).assertEqual('dynamic.search');
      expect(googleDocs.actionId).assertEqual('client_intent_fallback');
      expect(composioSlack.toolId).assertEqual('dynamic.search');
      expect(composioSlack.actionId).assertEqual('model_tool_request');
      expect(outlook.toolId).assertEqual('dynamic.search');
      expect(discord.toolId).assertEqual('dynamic.search');
      expect(plainSlack.toolId).assertEqual('social.feed.search');
    });

    it('does not infer X post search from Xcode or generic post text', 0, () => {
      const xcode = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我搜索 Xcode 构建报错',
        ''
      );
      const postProcessing = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        'search post processing techniques',
        ''
      );

      expect(xcode.toolId).assertEqual('');
      expect(postProcessing.toolId).assertEqual('');
    });

    it('guards model-selected X post requests with the same public-post intent gate', 0, () => {
      const xcode = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('x.post.search', '帮我搜索 Xcode 构建报错', 'model_tool_request'),
        '帮我搜索 Xcode 构建报错',
        ''
      );
      const postProcessing = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('x.post.search', 'search post processing techniques', 'model_tool_request'),
        'search post processing techniques',
        ''
      );
      const twitter = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('x.post.search', 'search Twitter public posts about OpenAI', 'model_tool_request'),
        'search Twitter public posts about OpenAI',
        ''
      );
      const tweet = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('x.post.search', '搜索 OpenAI 最近的推文', 'model_tool_request'),
        '搜索 OpenAI 最近的推文',
        ''
      );
      const xcom = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('x.post.search', '帮我搜索 x.com 上 OpenAI 最近的公开 post', 'model_tool_request'),
        '帮我搜索 x.com 上 OpenAI 最近的公开 post',
        ''
      );

      expect(xcode.hasTool).assertFalse();
      expect(xcode.toolId).assertEqual('');
      expect(postProcessing.hasTool).assertFalse();
      expect(postProcessing.toolId).assertEqual('');
      expect(twitter.toolId).assertEqual('x.post.search');
      expect(tweet.toolId).assertEqual('x.post.search');
      expect(xcom.toolId).assertEqual('x.post.search');
    });

    it('infers explicit Google Calendar tools without inventing args', 0, () => {
      const search = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我看今天的 Google Calendar 日程',
        ''
      );
      const create = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我在明天下午3点创建一个标题为 AIPhoneDemo smoke 的30分钟日程',
        ''
      );
      const update = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '把 AIPhoneDemo smoke 日程改到明天下午4点',
        ''
      );

      expect(search.toolId).assertEqual('calendar.events.search');
      expect(create.toolId).assertEqual('calendar.event.create');
      expect(update.toolId).assertEqual('calendar.event.update');
      expect(create.args === null).assertTrue();
    });

    it('infers ferry search when the user asks for ferry tickets', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我查明天深圳到珠海的船票',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('dynamic.search');
      expect(resolved.actionId).assertEqual('client_intent_fallback');
    });

    it('reroutes ferry tickets to dynamic search even when the model selects travel search', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('travel.search', '帮我查明天深圳到珠海的船票', 'model_tool_request'),
        '帮我查明天深圳到珠海的船票',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('dynamic.search');
      expect(resolved.prompt).assertEqual('帮我查明天深圳到珠海的船票');
      expect(resolved.actionId).assertEqual('model_tool_request');
    });

    it('infers weather and statistics dynamic tools', 0, () => {
      const weather = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我查明天深圳天气',
        ''
      );
      const statistics = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我查询统计局GDP数据',
        ''
      );

      expect(weather.toolId).assertEqual('dynamic.search');
      expect(statistics.toolId).assertEqual('dynamic.search');
    });

    it('infers ppt generation as an unsupported dynamic MCP candidate', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我生成一份深圳低空经济介绍PPT',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('dynamic.search');
      expect(resolved.actionId).assertEqual('client_intent_fallback');
    });

    it('infers unified travel search when the model omits a tool request for travel plans', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '我明天要从北京去上海，帮我搜索出行方案',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('travel.search');
    });

    it('falls back generic mail prompts to aggregate mail search', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我看邮箱里最新的重要邮件',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('mail.search');
      expect(resolved.actionId).assertEqual('client_intent_fallback');
    });

    it('falls back QQ mail prompts to aggregate mail search', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我看 QQ 邮箱里最近的邮件',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('mail.search');
      expect(resolved.actionId).assertEqual('client_intent_fallback');
    });

    it('falls back explicit Gmail and QQ mail aggregation to aggregate mail search', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '聚合展示 Gmail 和 QQ 邮箱里的最新邮件',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('mail.search');
      expect(resolved.actionId).assertEqual('client_intent_fallback');
    });

    it('infers Gmail tools when the model omits a tool request', 0, () => {
      const inbox = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我看下 Gmail 最近的重要邮件',
        ''
      );
      const draft = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我在 Gmail 回复 Alice，先起草一封邮件',
        ''
      );
      const blockedSend = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我 Gmail 直接发送这封邮件，不用确认直接发',
        ''
      );
      const openWeb = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '打开 Gmail 网页版',
        ''
      );

      expect(inbox.toolId).assertEqual('gmail.mail.search');
      expect(draft.toolId).assertEqual('gmail.draft.create');
      expect(blockedSend.toolId).assertEqual('gmail.message.send');
      expect(openWeb.toolId).assertEqual('gmail.open.web');
      expect(blockedSend.actionId).assertEqual('client_intent_fallback');
    });

    it('preserves model-provided Gmail structured args', 0, () => {
      const args: ToolRequestArgsFixture = {
        query: 'from:committee@example.edu newer_than:30d',
        pageSize: 7,
        intentSummary: '模型生成的 Gmail 查询'
      };
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('gmail.mail.search', '查 Gmail 委员会邮件', 'model_tool_request', args),
        '用户原始请求',
        ''
      );
      const serializedArgs = JSON.stringify(resolved.args);

      expect(resolved.toolId).assertEqual('gmail.mail.search');
      expect(serializedArgs.indexOf('committee@example.edu')).assertLarger(-1);
      expect(serializedArgs.indexOf('pageSize')).assertLarger(-1);
    });

    it('routes Gmail AI reply action and merges action context with model body args', 0, () => {
      const actionArgs: GmailReplyActionArgsFixture = {
        threadId: 'thread-123',
        to: ['committee@example.edu'],
        subject: 'Re: Admission decision',
        replyMode: 'reply'
      };
      const modelArgs: GmailReplyModelArgsFixture = {
        body: 'Thank you for the update.'
      };
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('gmail.draft.create', '创建 Gmail 回复草稿', 'model_tool_request', modelArgs),
        'Create reply draft',
        'gmail.ai.reply.draft',
        actionArgs
      );
      const serializedArgs = JSON.stringify(resolved.args);

      expect(resolved.toolId).assertEqual('gmail.draft.create');
      expect(serializedArgs.indexOf('thread-123')).assertLarger(-1);
      expect(serializedArgs.indexOf('committee@example.edu')).assertLarger(-1);
      expect(serializedArgs.indexOf('Re: Admission decision')).assertLarger(-1);
      expect(serializedArgs.indexOf('Thank you for the update.')).assertLarger(-1);
    });

    it('uses model form fields as Gmail draft args when toolRequest args are missing', 0, () => {
      const form: A2uiFormData = {
        to: ['alice@example.com'],
        subject: '邮件确认',
        body: '我收到了'
      };
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', '', null, form),
        '帮我用 Gmail 写一封邮件给 alice@example.com 说我收到了',
        ''
      );
      const serializedArgs = JSON.stringify(resolved.args);

      expect(resolved.toolId).assertEqual('gmail.draft.create');
      expect(serializedArgs.indexOf('alice@example.com')).assertLarger(-1);
      expect(serializedArgs.indexOf('邮件确认')).assertLarger(-1);
      expect(serializedArgs.indexOf('我收到了')).assertLarger(-1);
    });

    it('does not call Gmail draft for AI reply action ids until the model provides body args', 0, () => {
      const actionArgs: GmailReplyActionArgsFixture = {
        threadId: 'thread-123',
        to: ['committee@example.edu'],
        subject: 'Re: Admission decision',
        replyMode: 'reply'
      };
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        'Create reply draft',
        'gmail.ai.reply.draft',
        actionArgs
      );

      expect(resolved.hasTool).assertFalse();
      expect(resolved.toolId).assertEqual('');
      expect(JSON.stringify(resolved.args).indexOf('thread-123')).assertLarger(-1);
    });

    it('forces direct Gmail send prompts into the blocked send tool even when the model selects draft', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('gmail.draft.create', '创建 Gmail 草稿', 'model_tool_request'),
        '用 Gmail 直接发送一封邮件给 alice@example.com 说测试',
        ''
      );

      expect(resolved.toolId).assertEqual('gmail.message.send');
      expect(resolved.actionId).assertEqual('client_gmail_safety_reroute');
    });

    it('routes smoke Gmail prompts without relying on model-provided tool requests', 0, () => {
      const latestImportant = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我看 Gmail 里最新的重要邮件',
        ''
      );
      const openWeb = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '打开 Gmail 网页版',
        ''
      );
      const draftMail = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我用 Gmail 写一封邮件给 alice@example.com 说我收到了',
        ''
      );
      const directSend = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '用 Gmail 直接发送一封邮件给 alice@example.com 说测试',
        ''
      );

      expect(latestImportant.toolId).assertEqual('gmail.mail.search');
      expect(openWeb.toolId).assertEqual('gmail.open.web');
      expect(draftMail.toolId).assertEqual('gmail.draft.create');
      expect(directSend.toolId).assertEqual('gmail.message.send');
    });
  });
}
