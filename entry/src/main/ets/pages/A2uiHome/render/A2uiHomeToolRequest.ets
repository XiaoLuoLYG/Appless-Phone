import { A2uiSurfaceState, aggregateSearchQueryFromArgs } from '@loop/agent-core';
import { genericToolResults, summaryData, toolRequest } from '@loop/agent-core';

type ToolRequestArgValue = Object | string | number | boolean | null | undefined;
type ToolRequestArgRecord = Record<string, ToolRequestArgValue>;
type DataModelRecord = Record<string, Object | string | number | boolean | null | undefined>;

interface DraftFormData {
  to?: string[];
  subject?: string;
  body?: string;
  threadId?: string;
  replyMode?: string;
}

interface MediaFallbackArgs {
  sources: string[];
}

interface AggregateFallbackArgs {
  sources: string[];
  query?: string;
}

interface YouTubeFallbackArgs {
  query: string;
  order?: string;
  maxResults?: number;
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

export interface A2uiHomeResolvedToolRequest {
  hasTool: boolean;
  toolId: string;
  prompt: string;
  actionId: string;
  args: Object | null;
  modelPromptChars: number;
}

function containsAny(text: string, words: string[]): boolean {
  for (let index = 0; index < words.length; index++) {
    if (text.indexOf(words[index]) >= 0) {
      return true;
    }
  }
  return false;
}

function hasExplicitMapsIntent(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  return prompt.indexOf('谷歌地图') >= 0 ||
    lowerPrompt.indexOf('google maps') >= 0 ||
    lowerPrompt.indexOf('google map') >= 0 ||
    lowerPrompt.indexOf('googlemap') >= 0 ||
    lowerPrompt.indexOf('google places') >= 0 ||
    lowerPrompt.indexOf('gmap') >= 0;
}

function hasExplicitYouTubeIntent(prompt: string): boolean {
  return prompt.toLowerCase().indexOf('youtube') >= 0 || prompt.indexOf('油管') >= 0;
}

function hasGmailContext(prompt: string): boolean {
  return prompt.toLowerCase().indexOf('gmail') >= 0 || containsAny(prompt, ['谷歌邮箱', '谷歌邮件']);
}

function hasBilibiliIntent(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  return lowerPrompt.indexOf('bilibili') >= 0 ||
    lowerPrompt.indexOf('b站') >= 0 ||
    lowerPrompt.indexOf('b 站') >= 0 ||
    prompt.indexOf('哔哩哔哩') >= 0;
}

function hasMediaSearchVerb(prompt: string): boolean {
  return containsAny(prompt, ['查', '查询', '搜索', '帮我搜']);
}

function hasMediaAggregationIntent(prompt: string): boolean {
  return containsAny(prompt, ['聚合搜索', '聚合视频', '媒体聚合', '多源视频', '多平台视频']) ||
    (prompt.indexOf('聚合') >= 0 && containsAny(prompt, ['视频', '短视频', '媒体']));
}

function hasAggregateSearchIntent(prompt: string): boolean {
  if (hasSocialHubContext(prompt)) {
    return false;
  }
  const lowerPrompt = prompt.toLowerCase();
  if (lowerPrompt.indexOf('weibo') >= 0 || prompt.indexOf('微博') >= 0) {
    return false;
  }
  const cleanedQuery = aggregateSearchQueryFromArgs(prompt, null);
  const hasCompactTopic = cleanedQuery.length > 0 && cleanedQuery !== prompt.trim();
  const wantsTopic = hasCompactTopic || containsAny(prompt, ['有关', '关于', '看看', '搜索', '搜', '聚合', '整理', '汇总', '追踪', '了解']);
  const wantsDiscussion = containsAny(prompt, ['新闻', '讨论', '热议', '舆论', '观点', '帖子', 'po文', '公开动态']) ||
    lowerPrompt.indexOf('post') >= 0 ||
    lowerPrompt.indexOf('reaction') >= 0 ||
    lowerPrompt.indexOf('public') >= 0 ||
    (containsAny(prompt, ['聚合搜索', '媒体聚合', '多来源', '多平台']) && hasCompactTopic);
  if (!wantsTopic || !wantsDiscussion) {
    return false;
  }
  const mentionsVideoSource = hasExplicitYouTubeIntent(prompt) || hasBilibiliIntent(prompt);
  const mentionsTextSource = hasXPostContext(prompt) ||
    containsAny(prompt, ['知乎', 'Hacker News', 'HackNews', 'HackerNews', 'Reddit', 'reddit', '红迪']) ||
    prompt.indexOf('HN') >= 0;
  const asksMixedView = containsAny(prompt, ['聚合', '多来源', '多平台', '汇总']) ||
    (containsAny(prompt, ['新闻']) && containsAny(prompt, ['讨论', '观点', '热议', '舆论'])) ||
    (containsAny(prompt, ['视频', '短视频']) && containsAny(prompt, ['讨论', '帖子', 'po文', '观点', '热议', '舆论']) &&
      (!mentionsVideoSource || mentionsTextSource));
  if (mentionsVideoSource && !mentionsTextSource && !asksMixedView) {
    return false;
  }
  if (allowsXPostSearchPrompt(prompt) && !mentionsVideoSource && !asksMixedView) {
    return false;
  }
  return asksMixedView || mentionsVideoSource && mentionsTextSource || !mentionsVideoSource && !mentionsTextSource;
}

function hasComposioDynamicIntent(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  if ((lowerPrompt.indexOf('whatsapp') >= 0 || lowerPrompt.indexOf('whats app') >= 0) &&
    containsAny(prompt, ['发', '发送', '消息给', '给']) &&
    containsAny(prompt, ['消息', '信息', 'message'])) {
    return false;
  }
  if (lowerPrompt.indexOf('weibo') >= 0 || prompt.indexOf('微博') >= 0 ||
    lowerPrompt.indexOf('zhihu') >= 0 || prompt.indexOf('知乎') >= 0) {
    return false;
  }
  if ((lowerPrompt.indexOf('reddit') >= 0 || prompt.indexOf('红迪') >= 0) && hasAggregateSearchIntent(prompt)) {
    return false;
  }
  const explicitComposio = lowerPrompt.indexOf('composio') >= 0;
  const unsupportedToolkit = lowerPrompt.indexOf('notion') >= 0 ||
    lowerPrompt.indexOf('google drive') >= 0 ||
    lowerPrompt.indexOf('google docs') >= 0 ||
    lowerPrompt.indexOf('google doc') >= 0 ||
    lowerPrompt.indexOf('linear') >= 0 ||
    lowerPrompt.indexOf('github') >= 0 ||
    lowerPrompt.indexOf('asana') >= 0 ||
    lowerPrompt.indexOf('trello') >= 0 ||
    lowerPrompt.indexOf('hubspot') >= 0 ||
    lowerPrompt.indexOf('salesforce') >= 0 ||
    lowerPrompt.indexOf('outlook') >= 0 ||
    lowerPrompt.indexOf('微软邮箱') >= 0 ||
    lowerPrompt.indexOf('discord') >= 0 ||
    lowerPrompt.indexOf('linkedin') >= 0 ||
    prompt.indexOf('领英') >= 0 ||
    lowerPrompt.indexOf('whatsapp') >= 0 ||
    lowerPrompt.indexOf('whats app') >= 0 ||
    lowerPrompt.indexOf('instagram') >= 0 ||
    lowerPrompt.indexOf('instgram') >= 0 ||
    lowerPrompt.indexOf('spotify') >= 0 ||
    lowerPrompt.indexOf('soptify') >= 0 ||
    lowerPrompt.indexOf('tiktok') >= 0 ||
    lowerPrompt.indexOf('tik tok') >= 0 ||
    lowerPrompt.indexOf('ticketmaster') >= 0 ||
    lowerPrompt.indexOf('ticket master') >= 0 ||
    lowerPrompt.indexOf('reddit') >= 0 ||
    prompt.indexOf('红迪') >= 0;
  return explicitComposio || unsupportedToolkit;
}

function mediaArgsForPrompt(prompt: string): Object | null {
  const bilibiliIntent = hasBilibiliIntent(prompt);
  const youtubeIntent = hasExplicitYouTubeIntent(prompt);
  const aggregationIntent = hasMediaAggregationIntent(prompt);
  const genericVideoSearch = hasMediaSearchVerb(prompt) && containsAny(prompt, ['视频', '短视频']);
  if (bilibiliIntent && !youtubeIntent && !aggregationIntent) {
    const args: MediaFallbackArgs = { sources: ['bilibili'] };
    return args;
  }
  if (youtubeIntent && !bilibiliIntent && !aggregationIntent) {
    return null;
  }
  if (aggregationIntent || genericVideoSearch || bilibiliIntent) {
    const args: MediaFallbackArgs = { sources: ['youtube', 'bilibili'] };
    return args;
  }
  return null;
}

function aggregateArgsForPrompt(prompt: string): Object | null {
  if (!hasAggregateSearchIntent(prompt)) {
    return null;
  }
  const query = aggregateSearchQueryFromArgs(prompt, null);
  const args: AggregateFallbackArgs = { sources: ['youtube', 'bilibili', 'x', 'hackernews', 'reddit', 'zhihu'] };
  if (query.length > 0 && query !== prompt.trim()) {
    args.query = query;
  }
  return args;
}

function inferredAggregateSearchToolIdForPrompt(prompt: string): string {
  return aggregateArgsForPrompt(prompt) === null ? '' : 'media.aggregate.search';
}

function forcedDynamicToolIdForPrompt(prompt: string): string {
  if (prompt.length === 0) {
    return '';
  }
  if (hasComposioDynamicIntent(prompt)) {
    return 'dynamic.search';
  }
  if (containsAny(prompt, ['船票', '轮渡', '客船', '渡轮', '码头']) &&
    containsAny(prompt, ['查', '查询', '搜索', '帮我搜', '票', '余票', '班次'])) {
    return 'dynamic.search';
  }
  if (containsAny(prompt, ['天气', '气温', '下雨', '降雨']) &&
    containsAny(prompt, ['查', '查询', '搜索', '帮我搜', '今天', '明天'])) {
    return 'dynamic.search';
  }
  if (containsAny(prompt, ['统计局', 'GDP', 'CPI', '人口', '经济数据']) &&
    containsAny(prompt, ['查', '查询', '搜索', '帮我搜'])) {
    return 'dynamic.search';
  }
  if (containsAny(prompt, ['PPT', 'ppt', '幻灯片', '演示文稿']) &&
    containsAny(prompt, ['生成', '做', '制作', '创建'])) {
    return 'dynamic.search';
  }
  return '';
}

function forcedGmailToolIdForPrompt(prompt: string): string {
  if (!hasGmailContext(prompt)) {
    return '';
  }
  if (containsAny(prompt, ['直接发送', '立刻发送', '马上发送', '不用确认', '不确认直接发', '直接发'])) {
    return 'gmail.draft.create';
  }
  if (containsAny(prompt, ['打开', '网页版', '网页'])) {
    return 'gmail.open.web';
  }
  return '';
}

function inferredGmailToolIdForPrompt(prompt: string): string {
  const forcedToolId = forcedGmailToolIdForPrompt(prompt);
  if (forcedToolId.length > 0) {
    return forcedToolId;
  }
  if (!hasGmailContext(prompt)) {
    return '';
  }
  if (containsAny(prompt, ['写一封', '写邮件', '起草', '草稿', '回复', '撰写'])) {
    return 'gmail.draft.create';
  }
  if (containsAny(prompt, ['看', '查看', '查', '查询', '搜索', '最新', '重要', '邮件'])) {
    return 'gmail.mail.search';
  }
  return '';
}

function inferredMailToolIdForPrompt(prompt: string): string {
  const hasGmail = hasGmailContext(prompt);
  const hasQqMail = containsAny(prompt, ['QQ邮箱', 'QQ 邮箱', 'QQ邮件', 'QQ 邮件']);
  if ((hasGmail && !hasQqMail) ||
    !containsAny(prompt, ['邮箱', '邮件', '收件箱', 'QQ邮箱', 'QQ 邮箱'])) {
    return '';
  }
  if (containsAny(prompt, ['直接发送', '立刻发送', '马上发送', '不用确认', '不确认直接发', '直接发'])) {
    return '';
  }
  if (containsAny(prompt, ['写一封', '写邮件', '起草', '草稿', '回复', '撰写'])) {
    return 'mail.draft.create';
  }
  if (containsAny(prompt, ['看', '查看', '查', '查询', '搜索', '最新', '重要', '邮件', '收件箱'])) {
    return 'mail.search';
  }
  return '';
}

function inferredCalendarToolIdForPrompt(prompt: string): string {
  if (!containsAny(prompt, ['Google Calendar', '谷歌日历', '日程'])) {
    return '';
  }
  if (containsAny(prompt, ['创建', '新建', '添加', '新增', '安排'])) {
    return 'calendar.event.create';
  }
  if (containsAny(prompt, ['修改', '改到', '更新', '调整'])) {
    return 'calendar.event.update';
  }
  if (containsAny(prompt, ['删除', '取消日程', '移除'])) {
    return 'calendar.event.delete';
  }
  return 'calendar.events.search';
}

function inferredWhatsAppToolIdForPrompt(prompt: string): string {
  const lowerPrompt = prompt.toLowerCase();
  const hasWhatsApp = lowerPrompt.indexOf('whatsapp') >= 0 || lowerPrompt.indexOf('whats app') >= 0;
  const hasSend = containsAny(prompt, ['发送', '发消息', '消息给', '给']) || lowerPrompt.indexOf('send') >= 0;
  const hasMessage = containsAny(prompt, ['消息', '信息']) || lowerPrompt.indexOf('message') >= 0;
  return hasWhatsApp && hasSend && hasMessage ? 'whatsapp.message.send' : '';
}

function paymentProviderForPrompt(prompt: string): string {
  const lowerPrompt = prompt.toLowerCase();
  if (lowerPrompt.indexOf('paypal') >= 0 || prompt.indexOf('贝宝') >= 0) {
    return 'paypal';
  }
  if (lowerPrompt.indexOf('stripe') >= 0) {
    return 'stripe';
  }
  return '';
}

function paymentFundingSourceForPrompt(prompt: string): string {
  const lowerPrompt = prompt.toLowerCase();
  if (lowerPrompt.indexOf('google pay') >= 0 ||
    lowerPrompt.indexOf('googlepay') >= 0 ||
    lowerPrompt.indexOf('google wallet') >= 0 ||
    prompt.indexOf('谷歌支付') >= 0) {
    return 'google_pay';
  }
  return '';
}

function hasStripeReceivingAccountIntent(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  const hasStripe = lowerPrompt.indexOf('stripe') >= 0;
  const hasAccountWord = containsAny(prompt, ['收款账户', '收款账号', '收款', '账户', '账号', '绑定', '开通', '开户']) ||
    lowerPrompt.indexOf('connected account') >= 0 ||
    lowerPrompt.indexOf('connect account') >= 0 ||
    lowerPrompt.indexOf('onboarding') >= 0;
  const hasSetupWord = containsAny(prompt, ['开通', '绑定', '创建', '新建', '开户', '设置', '配置', '认证', '入驻', '刷新', '状态', '查看']);
  if (hasStripe && hasAccountWord && hasSetupWord) {
    return true;
  }
  return containsAny(prompt, ['开通 agent 收款', '开通Agent收款', '绑定 agent 收款', '创建 agent 收款', '创建Agent收款']);
}

function inferredStripeReceivingAccountToolIdForPrompt(prompt: string): string {
  return hasStripeReceivingAccountIntent(prompt) ? 'payment.account.setup' : '';
}

function hasExplicitPaymentIntent(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  const provider = paymentProviderForPrompt(prompt);
  const hasProvider = provider.length > 0;
  const hasPaymentVerb = containsAny(prompt, ['转账', '付款', '支付', '打款', '付钱', '收款', '付款页', '支付台']) ||
    lowerPrompt.indexOf('pay') >= 0 ||
    lowerPrompt.indexOf('payment') >= 0 ||
    lowerPrompt.indexOf('transfer') >= 0 ||
    lowerPrompt.indexOf('checkout') >= 0;
  if (hasProvider && hasPaymentVerb) {
    return true;
  }
  const hasRecipientHint = prompt.indexOf('给') >= 0 || lowerPrompt.indexOf(' to ') >= 0;
  return hasRecipientHint && containsAny(prompt, ['转账', '打款', '付款', '付钱']);
}

function paymentArgsForPrompt(prompt: string): Object | null {
  if (!hasExplicitPaymentIntent(prompt)) {
    return null;
  }
  const args: PaymentFallbackArgs = {
    provider: paymentProviderForPrompt(prompt),
    fundingSource: paymentFundingSourceForPrompt(prompt),
    recipient: '',
    amountText: '',
    currency: '',
    note: '',
    originalQuery: prompt.trim()
  };
  return args;
}

function inferredPaymentToolIdForPrompt(prompt: string): string {
  return paymentArgsForPrompt(prompt) === null ? '' : 'payment.send';
}

function inferredMapsToolIdForPrompt(prompt: string): string {
  if (!hasExplicitMapsIntent(prompt)) {
    return '';
  }
  if (containsAny(prompt, ['详情', '详细', 'placeId', 'Place ID'])) {
    return 'maps.place.details';
  }
  if (containsAny(prompt, ['路线', '导航', 'directions', 'route']) ||
    (prompt.indexOf('从') >= 0 && prompt.indexOf('到') >= 0)) {
    return 'maps.route.open';
  }
  return 'maps.place.search';
}

function inferredMediaToolIdForPrompt(prompt: string): string {
  return mediaArgsForPrompt(prompt) === null ? '' : 'media.video.search';
}

function hasSocialHubContext(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  return containsAny(prompt, ['Slack', '企业微信', '社交', '消息聚合', '多平台消息', '社交消息']) ||
    lowerPrompt.indexOf('slack') >= 0;
}

function hasSocialDraftIntent(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  return containsAny(prompt, ['草稿', '回复', '起草']) ||
    lowerPrompt.indexOf('draft') >= 0 ||
    lowerPrompt.indexOf('reply') >= 0;
}

function isAsciiAlphaNumeric(char: string): boolean {
  return (char >= 'A' && char <= 'Z') ||
    (char >= 'a' && char <= 'z') ||
    (char >= '0' && char <= '9') ||
    char === '_';
}

function hasStandaloneXMarker(prompt: string): boolean {
  for (let index = 0; index < prompt.length; index++) {
    const char = prompt.charAt(index);
    if (char !== 'X' && char !== 'x') {
      continue;
    }
    const previous = index === 0 ? '' : prompt.charAt(index - 1);
    const next = index + 1 >= prompt.length ? '' : prompt.charAt(index + 1);
    if ((previous.length === 0 || !isAsciiAlphaNumeric(previous)) &&
      (next.length === 0 || !isAsciiAlphaNumeric(next))) {
      return true;
    }
  }
  return false;
}

function hasXPostContext(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  return containsAny(prompt, ['Twitter', '推文', '公开 post']) ||
    hasStandaloneXMarker(prompt) ||
    lowerPrompt.indexOf('twitter') >= 0 ||
    lowerPrompt.indexOf('x.com') >= 0 ||
    lowerPrompt.indexOf('public post') >= 0;
}

function hasSocialReadIntent(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  return containsAny(prompt, ['读', '看', '查看', '查', '查询', '搜索', '搜', '最近', '公开']) ||
    lowerPrompt.indexOf('read') >= 0 ||
    lowerPrompt.indexOf('search') >= 0;
}

function allowsXPostSearchPrompt(prompt: string): boolean {
  return hasXPostContext(prompt) && hasSocialReadIntent(prompt);
}

function inferredSocialHubToolIdForPrompt(prompt: string): string {
  const socialContext = hasSocialHubContext(prompt);
  if (socialContext && hasSocialDraftIntent(prompt)) {
    return 'social.reply.draft';
  }
  if (allowsXPostSearchPrompt(prompt) &&
    (!socialContext || containsAny(prompt, ['公开 post']) || prompt.toLowerCase().indexOf('x.com') >= 0 || prompt.toLowerCase().indexOf('public post') >= 0)) {
    return 'x.post.search';
  }
  if (socialContext) {
    return 'social.feed.search';
  }
  return '';
}

function inferredLuckinOrderToolIdForPrompt(prompt: string): string {
  const lowerPrompt = prompt.toLowerCase();
  const hasLuckin = prompt.indexOf('瑞幸') >= 0 || lowerPrompt.indexOf('luckin') >= 0 || lowerPrompt.indexOf('ruixing') >= 0;
  if (!hasLuckin) {
    return '';
  }
  if (containsAny(prompt, ['只喝', '只买', '只点', '不喝', '不买', '不点', '偏好', '喜欢', '记住', '以后'])) {
    return '';
  }
  if (containsAny(prompt, ['订单状态', '取餐码', '取餐号', '刷新订单', '查询订单'])) {
    return 'luckin.order.status';
  }
  if (containsAny(prompt, ['点一杯', '点杯', '点个瑞幸', '点瑞幸', '帮我点', '我要点', '下单', '下一杯', '买一杯', '帮我买', '购买一杯', '购买瑞幸', '来一杯', '要一杯'])) {
    return 'luckin.order.preview';
  }
  return '';
}

function hasHotVideoIntent(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  return containsAny(prompt, ['最火', '最热门', '热门', '播放量最高']) ||
    lowerPrompt.indexOf('popular') >= 0 ||
    lowerPrompt.indexOf('most viewed') >= 0;
}

function requestedYouTubeResultCount(prompt: string): number {
  const lowerPrompt = prompt.toLowerCase();
  if (containsAny(prompt, ['五个', '5个', '5 个']) || lowerPrompt.indexOf('five') >= 0 || hasStandaloneFive(prompt)) {
    return 5;
  }
  return 10;
}

function hasStandaloneFive(prompt: string): boolean {
  for (let index = 0; index < prompt.length; index++) {
    if (prompt.charAt(index) !== '5') {
      continue;
    }
    const previous = index === 0 ? '' : prompt.charAt(index - 1);
    const next = index + 1 >= prompt.length ? '' : prompt.charAt(index + 1);
    if ((previous.length === 0 || !isAsciiAlphaNumeric(previous)) &&
      (next.length === 0 || !isAsciiAlphaNumeric(next))) {
      return true;
    }
  }
  return false;
}

function youtubeArgsForPrompt(prompt: string): Object | null {
  if (hasExplicitYouTubeIntent(prompt) &&
    !hasBilibiliIntent(prompt) &&
    !hasMediaAggregationIntent(prompt) &&
    (hasMediaSearchVerb(prompt) || containsAny(prompt, ['视频']) || hasHotVideoIntent(prompt))) {
    const args: YouTubeFallbackArgs = { query: prompt.trim() };
    if (hasHotVideoIntent(prompt)) {
      args.order = 'viewCount';
      args.maxResults = requestedYouTubeResultCount(prompt);
    }
    return args;
  }
  return null;
}

function inferredYouTubeToolIdForPrompt(prompt: string): string {
  const lowerPrompt = prompt.toLowerCase();
  if (hasExplicitYouTubeIntent(prompt) && (prompt.indexOf('播放列表') >= 0 || lowerPrompt.indexOf('playlist') >= 0)) {
    return 'youtube.mine.playlists';
  }
  if (hasExplicitYouTubeIntent(prompt) && (prompt.indexOf('订阅') >= 0 || lowerPrompt.indexOf('subscription') >= 0)) {
    return 'youtube.mine.subscriptions';
  }
  return youtubeArgsForPrompt(prompt) === null ? '' : 'youtube.video.search';
}

function inferredToolIdForPrompt(prompt: string): string {
  const whatsappToolId = inferredWhatsAppToolIdForPrompt(prompt);
  if (whatsappToolId.length > 0) {
    return whatsappToolId;
  }
  const dynamicToolId = forcedDynamicToolIdForPrompt(prompt);
  if (dynamicToolId.length > 0) {
    return dynamicToolId;
  }
  const mailToolId = inferredMailToolIdForPrompt(prompt);
  if (mailToolId.length > 0) {
    return mailToolId;
  }
  const stripeReceivingToolId = inferredStripeReceivingAccountToolIdForPrompt(prompt);
  if (stripeReceivingToolId.length > 0) {
    return stripeReceivingToolId;
  }
  const paymentToolId = inferredPaymentToolIdForPrompt(prompt);
  if (paymentToolId.length > 0) {
    return paymentToolId;
  }
  const gmailToolId = inferredGmailToolIdForPrompt(prompt);
  if (gmailToolId.length > 0) {
    return gmailToolId;
  }
  const calendarToolId = inferredCalendarToolIdForPrompt(prompt);
  if (calendarToolId.length > 0) {
    return calendarToolId;
  }
  const mapsToolId = inferredMapsToolIdForPrompt(prompt);
  if (mapsToolId.length > 0) {
    return mapsToolId;
  }
  const aggregateToolId = inferredAggregateSearchToolIdForPrompt(prompt);
  if (aggregateToolId.length > 0) {
    return aggregateToolId;
  }
  const youtubeToolId = inferredYouTubeToolIdForPrompt(prompt);
  if (youtubeToolId.length > 0) {
    return youtubeToolId;
  }
  const mediaToolId = inferredMediaToolIdForPrompt(prompt);
  if (mediaToolId.length > 0) {
    return mediaToolId;
  }
  const socialHubToolId = inferredSocialHubToolIdForPrompt(prompt);
  if (socialHubToolId.length > 0) {
    return socialHubToolId;
  }
  const luckinOrderToolId = inferredLuckinOrderToolIdForPrompt(prompt);
  if (luckinOrderToolId.length > 0) {
    return luckinOrderToolId;
  }
  if (containsAny(prompt, ['附近', '周边', '外卖', '咖啡', '奶茶', '餐饮', '美食', '肯德基']) &&
    containsAny(prompt, ['查', '查询', '搜索', '帮我搜', '附近', '周边'])) {
    return 'food.search';
  }
  if (containsAny(prompt, ['出行方案', '搜索出行', '怎么去', '比较出行', '出行选项', '可查的出行'])) {
    return 'travel.search';
  }
  if (containsAny(prompt, ['航班', '机票', '飞机'])) {
    return 'flight.search';
  }
  if (containsAny(prompt, ['高铁', '火车', '车票', '12306'])) {
    return 'train.search';
  }
  return '';
}

function toolIdForActionId(actionId: string): string {
  if (actionId === 'whatsapp.message.send.confirm') {
    return 'whatsapp.message.send';
  }
  if (actionId === 'calendar.event.delete.confirm') {
    return 'calendar.event.delete';
  }
  if (actionId === 'gmail.ai.reply.draft') {
    return 'gmail.draft.create';
  }
  if (actionId === 'payment.confirm' ||
    actionId === 'payment.capture' ||
    actionId === 'payment.cancel' ||
    actionId === 'payment.amount.select' ||
    actionId === 'payment.provider.select' ||
    actionId === 'payment.checkout.open') {
    return 'payment.send';
  }
  if (actionId === 'luckin.order.create') {
    return 'luckin.order.create';
  }
  if (actionId === 'luckin.order.preview') {
    return 'luckin.order.preview';
  }
  if (actionId === 'luckin.order.status') {
    return 'luckin.order.status';
  }
  if (actionId === 'stripe.account.create' ||
    actionId === 'stripe.account.onboard' ||
    actionId === 'stripe.account.refresh') {
    return 'payment.account.setup';
  }
  return '';
}

export function directPaymentToolIdForActionId(actionId: string): string {
  if (actionId === 'whatsapp.message.send.confirm') {
    return 'whatsapp.message.send';
  }
  if (actionId === 'calendar.event.delete.confirm') {
    return 'calendar.event.delete';
  }
  if (actionId === 'payment.confirm' ||
    actionId === 'payment.capture' ||
    actionId === 'payment.cancel' ||
    actionId === 'payment.amount.select' ||
    actionId === 'payment.provider.select') {
    return 'payment.send';
  }
  return '';
}

export function directRideToolIdForActionId(actionId: string): string {
  if (actionId === 'ride.order.confirm') {
    return 'ride.order.create';
  }
  if (actionId === 'ride.order.cancel') {
    return 'ride.order.cancel';
  }
  if (actionId === 'ride.driver.location.refresh') {
    return 'ride.driver.location';
  }
  if (actionId === 'ride.query.retry') {
    return 'ride.estimate';
  }
  return '';
}

export function surfaceHasSatisfiedToolResult(surface: A2uiSurfaceState, toolId: string): boolean {
  const results = genericToolResults(surface);
  for (let index = 0; index < results.length; index++) {
    if (toolNameSatisfied(toolId, results[index].toolName)) {
      return true;
    }
  }
  if (toolId === 'social.feed.search') {
    for (let index = 0; index < surface.components.length; index++) {
      if (surface.components[index].component === 'SocialHub') {
        return true;
      }
    }
  }
  if (toolId === 'media.aggregate.search') {
    for (let index = 0; index < surface.components.length; index++) {
      if (surface.components[index].component === 'AggregateSearch') {
        return true;
      }
    }
  }
  // ponytail: Gmail surfaces can expose raw Google tool names; add aliases here when real providers need them.
  return toolNameSatisfied(toolId, summaryData(surface).toolName);
}

export function surfaceHasVisibleToolResult(surface: A2uiSurfaceState): boolean {
  if (genericToolResults(surface).length > 0) {
    return true;
  }
  for (let index = 0; index < surface.components.length; index++) {
    if (surface.components[index].component === 'SocialHub' ||
      surface.components[index].component === 'AggregateSearch') {
      return true;
    }
  }
  return false;
}

function toolNameSatisfied(expectedToolId: string, actualToolName: string): boolean {
  if (actualToolName === expectedToolId) {
    return true;
  }
  if (expectedToolId === 'gmail.mail.search') {
    return actualToolName.indexOf('users.threads') === 0 || actualToolName === 'search_threads';
  }
  if (expectedToolId === 'gmail.draft.create') {
    return actualToolName.indexOf('users.drafts') === 0 || actualToolName === 'create_draft';
  }
  return false;
}

function mergeArgs(base: Object | null, override: Object | null): Object | null {
  if (base === null) {
    return override;
  }
  if (override === null) {
    return base;
  }
  const merged: ToolRequestArgRecord = {};
  const baseRecord = base as ToolRequestArgRecord;
  Object.keys(baseRecord).forEach((key: string) => {
    merged[key] = baseRecord[key];
  });
  const overrideRecord = override as ToolRequestArgRecord;
  Object.keys(overrideRecord).forEach((key: string) => {
    merged[key] = overrideRecord[key];
  });
  return merged;
}

function argText(args: Object | null, key: string): string {
  if (args === null) {
    return '';
  }
  const value = (args as ToolRequestArgRecord)[key];
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

function textOf(value: ToolRequestArgValue): string {
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

function stringArrayFrom(value: ToolRequestArgValue): string[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    const values: string[] = [];
    value.forEach((item: Object | string | number | boolean | null) => {
      const text = textOf(item);
      if (text.length > 0) {
        values.push(text);
      }
    });
    return values;
  }
  const text = textOf(value);
  return text.length > 0 ? [text] : [];
}

function draftFormArgs(surface: A2uiSurfaceState): Object | null {
  try {
    const model = JSON.parse(surface.dataModelJson) as DataModelRecord;
    const formValue = model.form;
    if (formValue === undefined || formValue === null ||
      typeof formValue === 'string' || typeof formValue === 'number' || typeof formValue === 'boolean') {
      return null;
    }
    const form = formValue as DraftFormData;
    const args: ToolRequestArgRecord = {};
    const to = stringArrayFrom(form.to);
    if (to.length > 0) {
      args.to = to;
    }
    const subject = textOf(form.subject);
    if (subject.length > 0) {
      args.subject = subject;
    }
    const body = textOf(form.body);
    if (body.length > 0) {
      args.body = body;
    }
    const threadId = textOf(form.threadId);
    if (threadId.length > 0) {
      args.threadId = threadId;
    }
    const replyMode = textOf(form.replyMode);
    if (replyMode.length > 0) {
      args.replyMode = replyMode;
    }
    return Object.keys(args).length > 0 ? args : null;
  } catch (_error) {
    return null;
  }
}

export function resolveA2uiHomeToolRequest(
  surface: A2uiSurfaceState,
  fallbackPrompt: string,
  fallbackActionId: string,
  fallbackArgs: Object | null = null,
  allowIntentFallback: boolean = true
): A2uiHomeResolvedToolRequest {
  const request = toolRequest(surface);
  if (!allowIntentFallback && request.toolId.length === 0) {
    return {
      hasTool: false,
      toolId: '',
      prompt: fallbackPrompt,
      actionId: fallbackActionId,
      args: null,
      modelPromptChars: fallbackPrompt.length
    };
  }
  let toolId = request.toolId;
  let prompt = request.prompt.length > 0 ? request.prompt : fallbackPrompt;
  let actionId = request.actionId.length > 0 ? request.actionId : fallbackActionId;
  const originalPrompt = fallbackPrompt.length > 0 ? fallbackPrompt : prompt;
  const forcedDynamicToolId = forcedDynamicToolIdForPrompt(prompt);
  const forcedWhatsAppToolId = inferredWhatsAppToolIdForPrompt(originalPrompt);
  const forcedGmailToolId = forcedGmailToolIdForPrompt(fallbackPrompt.length > 0 ? fallbackPrompt : prompt);
  const forcedStripeReceivingToolId = inferredStripeReceivingAccountToolIdForPrompt(fallbackPrompt.length > 0 ? fallbackPrompt : prompt);
  const forcedPaymentToolId = inferredPaymentToolIdForPrompt(fallbackPrompt.length > 0 ? fallbackPrompt : prompt);
  const forcedLuckinOrderToolId = inferredLuckinOrderToolIdForPrompt(fallbackPrompt.length > 0 ? fallbackPrompt : prompt);
  const forcedMapsToolId = inferredMapsToolIdForPrompt(prompt);
  const forcedAggregateToolId = inferredAggregateSearchToolIdForPrompt(originalPrompt);
  const forcedMediaToolId = inferredMediaToolIdForPrompt(prompt);
  const actionToolId = toolIdForActionId(fallbackActionId);
  if (forcedWhatsAppToolId.length > 0) {
    toolId = forcedWhatsAppToolId;
    if (request.toolId !== forcedWhatsAppToolId && actionId.length === 0) {
      actionId = request.toolId.length > 0 ? 'client_whatsapp_send_reroute' : 'client_intent_fallback';
    }
  } else if (forcedDynamicToolId.length > 0) {
    toolId = forcedDynamicToolId;
    if (actionId.length === 0) {
      actionId = request.toolId.length > 0 ? 'client_dynamic_reroute' : 'client_intent_fallback';
    }
  } else if (forcedGmailToolId.length > 0) {
    if (request.toolId.length > 0 && request.toolId !== forcedGmailToolId) {
      actionId = 'client_gmail_safety_reroute';
    } else if (actionId.length === 0) {
      actionId = 'client_intent_fallback';
    }
    toolId = forcedGmailToolId;
  } else if (request.toolId === 'gmail.message.send') {
    toolId = 'gmail.draft.create';
    actionId = 'client_gmail_safety_reroute';
  } else if (forcedStripeReceivingToolId.length > 0 && request.toolId !== forcedStripeReceivingToolId) {
    actionId = request.toolId.length > 0 ? 'client_stripe_receiving_reroute' : 'client_intent_fallback';
    toolId = forcedStripeReceivingToolId;
    prompt = originalPrompt;
  } else if (forcedPaymentToolId.length > 0 && request.toolId !== forcedPaymentToolId) {
    actionId = request.toolId.length > 0 ? 'client_payment_explicit_reroute' : 'client_intent_fallback';
    toolId = forcedPaymentToolId;
    prompt = originalPrompt;
  } else if (forcedLuckinOrderToolId.length > 0 && request.toolId !== forcedLuckinOrderToolId) {
    actionId = request.toolId.length > 0 ? 'client_luckin_order_reroute' : 'client_intent_fallback';
    toolId = forcedLuckinOrderToolId;
    prompt = originalPrompt;
  } else if (actionToolId.length > 0) {
    if (actionId.length === 0) {
      actionId = 'client_action_fallback';
    }
    toolId = actionToolId;
  } else if (forcedMapsToolId.length > 0 && toolId !== forcedMapsToolId) {
    actionId = request.toolId.length > 0 ? 'client_maps_explicit_reroute' : 'client_intent_fallback';
    toolId = forcedMapsToolId;
  } else if (forcedAggregateToolId.length > 0 && toolId !== forcedAggregateToolId) {
    actionId = request.toolId.length > 0 ? 'client_aggregate_search_reroute' : 'client_intent_fallback';
    toolId = forcedAggregateToolId;
    prompt = originalPrompt;
  } else if (forcedMediaToolId.length > 0 && toolId !== forcedMediaToolId) {
    actionId = request.toolId.length > 0 ? 'client_media_explicit_reroute' : 'client_intent_fallback';
    toolId = forcedMediaToolId;
  } else if (request.toolId === 'x.post.search' && !allowsXPostSearchPrompt(originalPrompt)) {
    toolId = inferredToolIdForPrompt(originalPrompt);
    actionId = toolId.length > 0 ? 'client_x_post_safety_reroute' : '';
  } else if ((toolId === 'maps.place.search' || toolId === 'maps.place.details' || toolId === 'maps.route.open') && !hasExplicitMapsIntent(prompt)) {
    toolId = inferredToolIdForPrompt(prompt);
    actionId = 'client_maps_safety_reroute';
  } else if (toolId.length === 0) {
    toolId = inferredToolIdForPrompt(fallbackPrompt);
    if (toolId.length > 0 && actionId.length === 0) {
      actionId = 'client_intent_fallback';
    }
  }
  let args = mergeArgs(fallbackArgs, request.args === undefined || request.args === null ? null : request.args);
  if (toolId === 'media.video.search') {
    args = mergeArgs(mediaArgsForPrompt(prompt), args);
  }
  if (toolId === 'media.aggregate.search') {
    args = mergeArgs(aggregateArgsForPrompt(prompt), args);
  }
  if (toolId === 'youtube.video.search') {
    args = mergeArgs(youtubeArgsForPrompt(prompt), args);
  }
  if (toolId === 'payment.send') {
    args = mergeArgs(paymentArgsForPrompt(originalPrompt), args);
  }
  if (toolId === 'gmail.draft.create') {
    args = mergeArgs(draftFormArgs(surface), args);
  }
  if (fallbackActionId === 'gmail.ai.reply.draft' && toolId === 'gmail.draft.create' && argText(args, 'body').trim().length === 0) {
    toolId = '';
  }
  return {
    hasTool: toolId.length > 0,
    toolId: toolId,
    prompt: prompt,
    actionId: actionId,
    args: args,
    modelPromptChars: request.prompt.length
  };
}
