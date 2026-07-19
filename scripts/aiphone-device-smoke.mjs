#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { spawn, spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const outDir = join(rootDir, 'tool-gateway', '.smoke');
mkdirSync(outDir, { recursive: true });

const defaultCases = [
  { query: '我明天要从北京去上海，帮我搜索出行方案', expectsTool: true, expectedToolId: 'travel.search' },
  { query: '帮我搜索深圳坂田华为基地附近的咖啡店', expectsTool: true, expectedToolId: 'food.search' },
  { query: '帮我用 Google Maps 搜索伦敦国王十字车站附近的中餐', expectsTool: true, expectedToolId: 'maps.place.search' },
  { query: '帮我查看邮箱里最新的重要邮件', expectsTool: true, expectedToolId: 'mail.search' },
  { query: '帮我查看我Gmail里和我eccv论文相关的邮件', expectsTool: true, expectedToolId: 'gmail.mail.search' },
  { query: '帮我在b站和youtube里搜索qwen的官方视频', expectsTool: true, expectedToolId: 'media.video.search' },
  { query: '我想看看有关 openai codex 的相关新闻和讨论', expectsTool: true, expectedToolId: 'media.aggregate.search' },
  { query: '帮我查看我今天 X 和 Slack 上的消息', expectsTool: true, expectedToolId: 'social.feed.search' },
  { query: '帮我查看 X 上 openai 最近的公开 post', expectsTool: true, expectedToolId: 'x.post.search' },
  { query: '点一杯咖啡', expectsTool: true, expectedToolId: 'food.search' },
  { query: '我只喝瑞幸咖啡', expectsTool: false, expectedToolId: '' },
  { query: '点一杯咖啡', expectsTool: true, expectedToolId: 'food.search', expectedPersonaMemory: 'luckin_only' }
];

const dynamicCases = [
  {
    query: '帮我查明天深圳天气',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'weather.query'
  }
];

const composioCases = [
  {
    query: '帮我在 GitHub 里找 Appless-Phone 最近的 pr',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我在 Google Drive 里找专利交底书',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我在 Google Docs 里找 AIPhoneDemo 设计文档',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我用 Composio Slack 查最近提到 AIPhoneDemo 的消息',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我查看邮箱里最新的重要邮件',
    expectsTool: true,
    expectedToolId: 'mail.search'
  },
  {
    query: '帮我用 Discord 查最近提到 AIPhoneDemo 的消息',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我在 LinkedIn 查 AIPhoneDemo 相关动态',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我用 WhatsApp 查最近提到 AIPhoneDemo 的消息',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我用 Instagram 查 AIPhoneDemo 相关评论',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我用 Spotify 搜适合 AIPhoneDemo demo 的播放列表',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我用 TikTok 搜 AIPhoneDemo 相关短视频',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我查看今天的社交聚合消息',
    expectsTool: true,
    expectedToolId: 'social.feed.search'
  }
];

const gmailCases = [
  { query: '帮我看 Gmail 里最新的重要邮件', expectsTool: true, expectedToolId: 'gmail.mail.search' },
  { query: '帮我用 Gmail 写一封邮件给 alice@example.com 说我收到了', expectsTool: true, expectedToolId: 'gmail.draft.create' },
  { query: '帮我查看我Gmail里和我eccv论文相关的邮件', expectsTool: true, expectedToolId: 'gmail.mail.search' }
];

const mailCases = [
  { query: '帮我看邮箱里最新的重要邮件', expectsTool: true, expectedToolId: 'mail.search' },
  { query: '帮我看 QQ 邮箱里最新邮件', expectsTool: true, expectedToolId: 'mail.search' }
];

const googleAppCases = [
  { query: '帮我在 YouTube 搜索 世界杯相关视频', expectsTool: true, expectedToolId: 'youtube.video.search' },
  { query: '帮我查看我的 YouTube 播放列表', expectsTool: true, expectedToolId: 'youtube.mine.playlists' },
  { query: '帮我看本月的 Google Calendar 日程', expectsTool: true, expectedToolId: 'calendar.events.search' },
  { query: '帮我在 2026年7月30日下午3点创建一个标题为 AIPhoneDemo 的30分钟日程', expectsTool: true, expectedToolId: 'calendar.event.create' },
  { query: '帮我用 Google Maps 搜索深圳坂田华为基地附近的咖啡店', expectsTool: true, expectedToolId: 'maps.place.search' }
];

const smokeRunId = process.env.AIPHONE_SMOKE_RUN_ID ||
  new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 14);
const whatsappTestTo = (process.env.AIPHONE_WHATSAPP_TEST_TO || '').trim();
const qaDateValue = new Date();
qaDateValue.setDate(qaDateValue.getDate() + 7);
const qaDate = `${qaDateValue.getFullYear()}年${String(qaDateValue.getMonth() + 1).padStart(2, '0')}月${String(qaDateValue.getDate()).padStart(2, '0')}日`;
const qaTitle = `Appless QA ${smokeRunId}`;
const whatsappRecipient = whatsappTestTo.length > 0 ? whatsappTestTo : '{AIPHONE_WHATSAPP_TEST_TO}';

const coreRegressionCases = [
  { id: 'C01', query: '你好', expectsTool: false, expectedToolId: '' },
  { id: 'C02', query: '我明天要从北京去上海，帮我搜索出行方案', expectsTool: true, expectedToolId: 'travel.search' },
  { id: 'C03', query: '帮我搜索深圳坂田华为基地附近的咖啡店', expectsTool: true, expectedToolId: 'food.search' },
  { id: 'C04', query: '帮我用 Google Maps 搜索伦敦国王十字车站附近的中餐', expectsTool: true, expectedToolId: 'maps.place.search' },
  { id: 'C05', query: '帮我查看邮箱里最新的重要邮件', expectsTool: true, expectedToolId: 'mail.search', verifyMailBody: true },
  { id: 'C06', query: '帮我查看我 Gmail 里和 ECCV 论文相关的邮件', expectsTool: true, expectedToolId: 'gmail.mail.search' },
  { id: 'C07', query: '帮我在 B 站和 YouTube 里搜索 Qwen 的官方视频', expectsTool: true, expectedToolId: 'media.video.search' },
  { id: 'C08', query: '我想看看有关 OpenAI Codex 的相关新闻和讨论', expectsTool: true, expectedToolId: 'media.aggregate.search' },
  { id: 'C09', query: '帮我查看我今天 X 和 Slack 上的消息', expectsTool: true, expectedToolId: 'social.feed.search', verifySocialDraft: true },
  { id: 'C10', query: '帮我查看 X 上 OpenAI 最近的公开 post', expectsTool: true, expectedToolId: 'x.post.search' },
  { id: 'C11a', query: '点一杯咖啡', expectsTool: true, expectedToolId: 'food.search' },
  { id: 'C11b', query: '我只喝瑞幸咖啡', expectsTool: false, expectedToolId: '' },
  { id: 'C11c', query: '点一杯咖啡', expectsTool: true, expectedToolId: 'food.search', expectedPersonaMemory: 'luckin_only' },
  { id: 'C12', query: '我想看世界杯下一场比赛和赛程', expectsTool: true, expectedToolId: 'worldcup.open' },
  { id: 'C13', query: '帮我查明天深圳天气', expectsTool: true, expectedToolId: 'dynamic.search', expectedDiscoveredToolId: 'weather.query' },
  { id: 'C14', query: '帮我看从深圳湾万象城到深圳北站打车多少钱', expectsTool: true, expectedToolId: 'ride.estimate' },
  { id: 'C15', query: '帮我点一杯瑞幸生椰拿铁，半糖少冰', expectsTool: true, expectedToolId: 'luckin.order.preview' },
  { id: 'C16', query: '帮我用 Google Maps 查询从深圳北站到深圳湾口岸的驾车路线并发起导航', expectsTool: true, expectedToolId: 'maps.route.open' },
  { id: 'C17', query: '用 PayPal 给罗一格转 1 美元', expectsTool: true, expectedToolId: 'payment.send' },
  {
    id: 'C18',
    query: `帮我给 WhatsApp 测试联系人 ${whatsappRecipient} 发送消息：Appless QA ${smokeRunId}`,
    expectsTool: true,
    expectedToolId: 'whatsapp.message.send',
    blockedWithoutWhatsAppTestTo: true
  },
  { id: 'C19a', query: `帮我查询 ${qaDate} 的 Google Calendar 日程`, expectsTool: true, expectedToolId: 'calendar.events.search' },
  { id: 'C19b', query: `帮我在 ${qaDate} 下午3点创建标题为 ${qaTitle} 的30分钟日程`, expectsTool: true, expectedToolId: 'calendar.event.create' },
  { id: 'C19c', query: `把 ${qaDate} 的 ${qaTitle} 日程改到下午4点，保持30分钟`, expectsTool: true, expectedToolId: 'calendar.event.update' },
  { id: 'C19d', query: `帮我查询 ${qaDate} 标题为 ${qaTitle} 的 Google Calendar 日程`, expectsTool: true, expectedToolId: 'calendar.events.search' },
  { id: 'C19e', query: `删除 ${qaDate} 标题为 ${qaTitle} 的 Google Calendar 日程`, expectsTool: true, expectedToolId: 'calendar.event.delete', verifyCalendarDelete: true },
  { id: 'C19f', query: `再次查询 ${qaDate} 标题为 ${qaTitle} 的 Google Calendar 日程，确认它不存在`, expectsTool: true, expectedToolId: 'calendar.events.search', expectAbsentText: qaTitle },
  {
    id: 'C20',
    query: '帮我搜索2026年8月8日至10日深圳南山区科技园附近的酒店，2位成人1间房',
    expectsTool: true,
    expectedToolId: 'hotel.search',
    verifyHotelDetail: true
  }
];

const retainedFullCases = [
  { id: 'F01', query: '帮我查明天北京到上海的航班', expectsTool: true, expectedToolId: 'flight.search' },
  { id: 'F02', query: '帮我查询明天晚上六点以后深圳北到香港西九龙的高铁', expectsTool: true, expectedToolId: 'train.search' },
  { id: 'F03', query: '帮我查深圳坂田附近麦当劳门店和菜单', expectsTool: true, expectedToolId: 'food.search' },
  { id: 'F04', query: '瑞幸生椰拿铁多少钱', expectsTool: true, expectedToolId: 'food.search' },
  { id: 'F05', query: '用 Google Pay 给罗一格转 1 美元', expectsTool: true, expectedToolId: 'payment.send' },
  { id: 'F06', query: '帮我设置 Stripe 收款账户', expectsTool: true, expectedToolId: 'payment.account.setup' },
  { id: 'F07', query: '帮我用 Gmail 写一封邮件给 alice@example.com，说我收到了', expectsTool: true, expectedToolId: 'gmail.draft.create' },
  { id: 'F08', query: '确认应用刚才的 Gmail 草稿', expectsTool: true, expectedToolId: 'gmail.draft.apply' },
  { id: 'F09', query: '帮我在 YouTube 搜索世界杯相关视频', expectsTool: true, expectedToolId: 'youtube.video.search' },
  { id: 'F10', query: '帮我查看我的 YouTube 播放列表', expectsTool: true, expectedToolId: 'youtube.mine.playlists' },
  { id: 'F11', query: '帮我查看我的 YouTube 订阅', expectsTool: true, expectedToolId: 'youtube.mine.subscriptions' },
  { id: 'F13', query: '帮我在 GitHub 里找 Appless-Phone 最近的 pr', expectsTool: true, expectedToolId: 'dynamic.search', expectedDiscoveredToolId: 'dynamic.search' },
  { id: 'F14', query: '帮我在 Google Drive 里找专利交底书', expectsTool: true, expectedToolId: 'dynamic.search', expectedDiscoveredToolId: 'dynamic.search' },
  { id: 'F15', query: '帮我在 Google Docs 里找 AIPhoneDemo 设计文档', expectsTool: true, expectedToolId: 'dynamic.search', expectedDiscoveredToolId: 'dynamic.search' }
];

const fullRegressionCases = [...coreRegressionCases, ...retainedFullCases];

const forbiddenSocialHubLegacyMarkers = [
  'SocialInbox',
  'social.reply.send',
  '微信消息收件箱',
  '通知中心桥接',
  '辅助捕获'
];

const forbiddenSyntheticMarkers = [
  '高铁 G 字头',
  '动车 D 字头',
  '直飞航班',
  '早晚低峰',
  '附近咖啡优先',
  '安静办公优先',
  '连锁稳定优先',
  '可查选项',
  ...forbiddenSocialHubLegacyMarkers
];

const visibleDomainMarkers = [
  '北京',
  '上海',
  '深圳',
  '高铁',
  '航班',
  '高铁 · 12306',
  '飞机 · 飞常准',
  '12306',
  '飞常准',
  '餐饮',
  '酒店',
  '咖啡',
  '奶茶',
  '坂田',
  '华为',
  '接入工具',
  'dynamic.search',
  'Composio',
  'GitHub',
  'Notion',
  'Google Drive',
  'Google Docs',
  'Linear',
  'Trello',
  'Asana',
  'HubSpot',
  'Salesforce',
  'Outlook',
  'Discord',
  'LinkedIn',
  'WhatsApp',
  'Instagram',
  'Spotify',
  'TikTok',
  'Ticketmaster',
  'needs_auth',
  'ferry.ticket.search',
  'weather.query',
  'statistics.search',
  'ppt.generate',
  'Gmail',
  'mail.search',
  'Mailbox',
  'QQ Mail',
  'AI 回复草稿',
  'YouTube',
  'youtube.video.search',
  'youtube.mine.playlists',
  'YOUTUBE_API_KEY',
  'Google Calendar',
  'calendar.events.search',
  'calendar.event.create',
  'calendar.event.delete',
  'Google OAuth',
  'Google Places',
  'Google Maps',
  'maps.place.search',
  'maps.route.open',
  'whatsapp.message.send',
  'GOOGLE_MAPS_API_KEY',
  'Gmail Web',
  'google.gmail',
  'gmail.mail.search',
  'gmail.draft.create',
  'gmail.open.web',
  'gmail.message.send',
  'Composio Gmail',
  '授权 Gmail',
  'UnsafeActionBlocked',
  '不会模拟 Gmail 邮件',
  '不会自动发送 Gmail',
  'AMAP_MAPS_API_KEY',
  'Authorization',
  'API_KEY',
  '歌者PPT',
  '多展示一些',
  '选最快的',
  'SocialHub',
  '社交工作台',
  'social.feed.search',
  'x.post.search',
  '生成草稿',
  'Slack',
  '企业微信'
];

const forbiddenLayoutActionMarkers = [
  '换个时间',
  '换个车站'
];

const finalLayoutBlockingMarkers = [
  'A2UI 流解析失败',
  '模型正在思考',
  '工具供应商调用异常',
  '需要供应商配置',
  '需要配置：',
  '查询失败',
  'Google Places API 调用失败',
  'Gmail 调用失败',
  'Gmail API 调用失败',
  'Gmail MCP 调用失败',
  'QQ 邮箱调用失败',
  'QQ IMAP timeout',
  'Operation timeout',
  '2300028',
  'MCP 工具调用失败',
  'Internal error',
  '2300999',
  'Bad Request',
  'invalid request data provided',
  'Composio 调用失败',
  'Failed to resolve the host name',
  '同步失败',
  'WhatsApp Business 账号不可用',
  '暂无可展示数据',
  '暂不支持的组件',
  '把一句话变成可执行界面',
  '告诉 AIPhone 你要安排的事',
  '[object Object]',
  '{"version"'
];

const finalLayoutRouteMarkers = [
  '北京',
  '上海'
];

const finalLayoutBlockingPatterns = [
  { name: 'iso-date', pattern: /\b20\d{2}[-/]\d{1,2}[-/]\d{1,2}\b/ },
  { name: 'zh-date', pattern: /\b\d{4}年\d{1,2}月\d{1,2}日\b/ }
];

const forbiddenGmailSendSuccessPatterns = [
  { name: 'gmail-send-success-en', pattern: /sent successfully|message sent/i },
  { name: 'gmail-send-success-zh', pattern: /发送成功|已发送成功|邮件已发送/ }
];

const retryableProviderLayoutMarkers = [
  'Google Places API 调用失败',
  'Gmail 调用失败',
  'Gmail API 调用失败',
  'QQ 邮箱调用失败',
  'QQ IMAP timeout',
  'Operation timeout',
  '2300028',
  'invalid request data provided',
  'Composio 调用失败',
  'Failed to resolve the host name',
  '同步失败',
  'WhatsApp Business 账号不可用'
];

function hasTechnicalGmailArgsCard(text) {
  return /(?:^|\n)args\n\{[\s\S]{0,180}"query"/.test(text);
}

const socialHubTruthfulBlockingMarkers = [
  '需要供应商配置',
  '需要配置：',
  '查询失败',
  'Operation timeout',
  '2300028',
  'MCP 工具调用失败',
  'Internal error',
  '2300999',
  'Bad Request'
];

const aggregateMediaTruthfulBlockingMarkers = [
  '工具供应商调用异常',
  '需要供应商配置',
  '需要配置：',
  '查询失败',
  'Operation timeout',
  '2300028',
  'MCP 工具调用失败',
  'Internal error',
  '2300999',
  'Bad Request'
];

const argv = process.argv.slice(2);
const cleanData = process.env.AIPHONE_SMOKE_CLEAN_DATA === '1' || argv.includes('--clean-data');
const runDynamicCases = argv.includes('--dynamic-tools');
const runComposioCases = argv.includes('--composio-tools');
const runComposioAuthCases = argv.includes('--composio-auth');
const runGoogleApps = argv.includes('--google-apps');
const runFullRegression = argv.includes('--full-regression');
const runCoreRegression = argv.includes('--core-regression');
const listCases = argv.includes('--list-cases');
const queryArgs = argv.filter((arg) => arg !== '--clean-data' &&
  arg !== '--dynamic-tools' &&
  arg !== '--composio-tools' &&
  arg !== '--composio-auth' &&
  arg !== '--google-apps' &&
  arg !== '--full-regression' &&
  arg !== '--core-regression' &&
  arg !== '--list-cases');
const selectedDefaultCases = runComposioCases ? composioCases :
  (runFullRegression ? fullRegressionCases :
    (runCoreRegression ? coreRegressionCases :
      (runGoogleApps ? defaultCases.concat(googleAppCases) :
        (runDynamicCases ? defaultCases.concat(dynamicCases) : defaultCases))));
const useDefaultCases = queryArgs.length === 0;
const queries = useDefaultCases ? selectedDefaultCases.map((testCase) => testCase.query) : queryArgs;
if (listCases) {
  console.log(JSON.stringify(selectedDefaultCases, null, 2));
  process.exit(0);
}
const target = process.env.AIPHONE_HDC_TARGET || firstTarget();
const timeoutMs = Number.parseInt(process.env.AIPHONE_QUERY_TIMEOUT_MS || '90000', 10);
const queryRetryLimit = Number.parseInt(process.env.AIPHONE_QUERY_RETRY_LIMIT || '2', 10);
const mailActionScrollLimit = Number.parseInt(process.env.AIPHONE_MAIL_ACTION_SCROLL_LIMIT || '16', 10);

function isWhatsAppSendQuery(query) {
  return /WhatsApp|Whats\s*App/i.test(query) && /发|发送|消息给|send/i.test(query) && /消息|信息|message/i.test(query);
}

function isMapsRouteQuery(query) {
  return /Google\s*Maps?|GMap|谷歌地图/i.test(query) && /路线|导航|怎么走|directions?|navigate|从.+到/.test(query);
}

function isHotelQuery(query) {
  return /酒店|hotel/i.test(query);
}

function expectedCaseForQuery(query) {
  if (isPersonaMemoryUpdateQuery(query)) {
    return {
      expectsTool: false,
      expectedToolId: ''
    };
  }
  if (/^你好$|问候|打招呼/.test(query)) {
    return {
      expectsTool: false,
      expectedToolId: ''
    };
  }
  if (/船票|轮渡|客船|渡轮|码头/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'dynamic.search',
      expectedDiscoveredToolId: 'none'
    };
  }
  if (/天气|气温|下雨|降雨/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'dynamic.search',
      expectedDiscoveredToolId: 'weather.query'
    };
  }
  if (/统计局|GDP|CPI|人口|经济数据/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'dynamic.search',
      expectedDiscoveredToolId: 'statistics.search'
    };
  }
  if (/PPT|ppt|幻灯片|演示文稿/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'dynamic.search',
      expectedDiscoveredToolId: 'ppt.generate'
    };
  }
  if (isWhatsAppSendQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'whatsapp.message.send'
    };
  }
  if (isSocialFeedQuery(query) &&
    (!isXPostSearchQuery(query) || !/公开\s*posts?\b|public\s+posts?\b|x\.com/i.test(query))) {
    return {
      expectsTool: true,
      expectedToolId: 'social.feed.search'
    };
  }
  if (/Composio|GitHub|Notion|Google\s*Drive|Google\s*Docs|Linear|Asana|Trello|HubSpot|Salesforce|Outlook|Spotify|Soptify|TikTok|Ticketmaster/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'dynamic.search',
      expectedDiscoveredToolId: 'dynamic.search'
    };
  }
  if (/PayPal|Google\s*Pay|GPay|支付|转账|付款/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'payment.send'
    };
  }
  if (isAggregateMediaSearchQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'media.aggregate.search'
    };
  }
  if (isXPostSearchQuery(query) && (!isSocialFeedQuery(query) || /公开\s*posts?\b|public\s+posts?\b|x\.com/i.test(query))) {
    return {
      expectsTool: true,
      expectedToolId: 'x.post.search'
    };
  }
  if (isSocialFeedQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'social.feed.search'
    };
  }
  if (/邮箱|邮件|收件箱/.test(query) && isMailAggregationQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'mail.search'
    };
  }
  if (/邮箱|邮件|收件箱/.test(query) && !/Gmail|谷歌邮箱|谷歌邮件/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: /写一封|写邮件|起草|草稿|回复|撰写/.test(query) ? 'mail.draft.create' : 'mail.search'
    };
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/i.test(query) && /打开|网页版|网页/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'gmail.open.web'
    };
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/i.test(query) && /直接发送|立刻发送|马上发送|不确认直接发/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'gmail.message.send'
    };
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/i.test(query) && /写一封|写邮件|起草|草稿|回复|撰写/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'gmail.draft.create'
    };
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'gmail.mail.search'
    };
  }
  if (/YouTube|油管/i.test(query) && /播放列表|playlist/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'youtube.mine.playlists'
    };
  }
  if (/YouTube|油管/i.test(query) && /订阅|subscriptions?/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'youtube.mine.subscriptions'
    };
  }
  if (isYouTubeBilibiliQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'media.video.search'
    };
  }
  if (/YouTube|油管/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'youtube.video.search'
    };
  }
  if (/B站|B 站|Bilibili|哔哩哔哩/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'media.video.search'
    };
  }
  if (/世界杯|world\s*cup|worldcup/i.test(query) && /想看|打开|进入|页面|界面|赛程|下一场|下场|什么时候|几点|开始|开赛|前瞻|集锦|球星|数据|对阵|比赛|schedule|fixture|preview|next match/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'worldcup.open'
    };
  }
  if (/Google\s*Calendar|谷歌日历/i.test(query) || /日程|会议|约会/.test(query)) {
    if (/删除|取消/.test(query)) {
      return {
        expectsTool: true,
        expectedToolId: 'calendar.event.delete'
      };
    }
    if (/创建|新建|添加|安排|预约/.test(query)) {
      return {
        expectsTool: true,
        expectedToolId: 'calendar.event.create'
      };
    }
    if (/更新|修改|改到|改为|调整/.test(query)) {
      return {
        expectsTool: true,
        expectedToolId: 'calendar.event.update'
      };
    }
    return {
      expectsTool: true,
      expectedToolId: 'calendar.events.search'
    };
  }
  if (/Google\s*Maps?|Google\s*Places|GMap|谷歌地图/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: isMapsRouteQuery(query) ? 'maps.route.open' :
        (/详情|placeId|地点 ID|地点ID/i.test(query) ? 'maps.place.details' : 'maps.place.search')
    };
  }
  if (/出行方案|搜索出行|怎么去|比较出行|出行选项|整理可查|可查的出行/.test(query) && /北京|上海|广州|深圳|杭州|成都|重庆|西安|南京|武汉|厦门|青岛|长沙|昆明|海口|三亚/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'travel.search'
    };
  }
  if (/航班|机票|飞机/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'flight.search'
    };
  }
  if (/高铁|火车|车票|12306/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'train.search'
    };
  }
  if (isHotelQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'hotel.search',
      verifyHotelDetail: true
    };
  }
  if (/瑞幸|luckin|ruixing/i.test(query) && /点一杯|点杯|点个瑞幸|点瑞幸|帮我点|我要点|下单|下一杯|买一杯|帮我买|购买一杯|购买瑞幸|来一杯|要一杯/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'luckin.order.preview'
    };
  }
  if (/附近|周边|外卖|咖啡|奶茶|肯德基|麦当劳|瑞幸|汉堡|餐饮|美食/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'food.search'
    };
  }
  return {
    expectsTool: null,
    expectedToolId: ''
  };
}

function firstTarget() {
  const result = spawnSync('hdc', ['list', 'targets'], { encoding: 'utf8', timeout: 12000 });
  const output = `${result.stdout || ''}${result.stderr || ''}`.trim();
  if (result.error !== undefined) {
    throw new Error(`hdc list targets failed before finding a device: ${result.error.message}`);
  }
  if (result.status !== 0 || /Connect server failed/i.test(output)) {
    throw new Error(`hdc list targets failed before finding a device: ${output}`);
  }
  const lines = output.split('\n').map((line) => line.trim()).filter((line) => line.length > 0 && !/list of targets/i.test(line));
  if (lines.length === 0) {
    throw new Error(`No hdc target found. Set AIPHONE_HDC_TARGET. hdc output: ${output}`);
  }
  return lines[0];
}

function hdc(args, options = {}) {
  const result = spawnSync('hdc', ['-t', target, ...args], {
    encoding: 'utf8',
    maxBuffer: 20 * 1024 * 1024,
    ...options
  });
  const output = `${result.stdout || ''}${result.stderr || ''}`;
  if (result.status !== 0 || /Connect server failed/i.test(output)) {
    throw new Error(`hdc ${args.join(' ')} failed:\n${result.stdout}\n${result.stderr}`);
  }
  return result.stdout;
}

function appWindowRect() {
  const output = hdc(['shell', 'hidumper', '-s', 'WindowManagerService', '-a', '-a']);
  const line = output.split('\n').find((value) => value.includes('aiphonedemo'));
  if (line === undefined) {
    return null;
  }
  const match = /\[\s*(-?\d+)\s+(-?\d+)\s+(\d+)\s+(\d+)\s+\]/.exec(line);
  if (match === null) {
    return null;
  }
  return {
    x: Number.parseInt(match[1], 10),
    y: Number.parseInt(match[2], 10),
    width: Number.parseInt(match[3], 10),
    height: Number.parseInt(match[4], 10)
  };
}

function moveAppWindowIntoScreenshot() {
  const rect = appWindowRect();
  if (rect === null || rect.y >= 0 && rect.y <= 220) {
    return;
  }
  const x = Math.max(80, Math.floor(rect.x + rect.width / 2));
  const fromY = Math.max(40, rect.y + 40);
  hdc(['shell', 'uitest', 'uiInput', 'drag', String(x), String(fromY), String(x), '120', '2000']);
  spawnSync('sleep', ['1']);
}

function clearHilog() {
  try {
    hdc(['shell', 'hilog', '-r']);
  } catch (error) {
    console.warn(`Could not clear hilog buffer: ${error instanceof Error ? error.message : String(error)}`);
  }
}

function cleanBundleData() {
  try {
    hdc(['shell', 'bm', 'clean', '-n', 'com.example.aiphonedemo', '-d']);
  } catch (error) {
    console.warn(`Could not clean bundle data: ${error instanceof Error ? error.message : String(error)}`);
  }
}

const personaStorePath = '/data/app/el2/100/base/com.example.aiphonedemo/haps/entry/preferences/aiphone_persona_store';
const personaBackupPath = `/data/local/tmp/aiphone-persona-store-${smokeRunId}`;

function backupPersonaMemoryStore() {
  hdc(['shell', 'aa', 'force-stop', 'com.example.aiphonedemo']);
  const output = hdc(['shell',
    `if [ -f ${personaStorePath} ]; then cp ${personaStorePath} ${personaBackupPath} && echo PRESENT; else echo ABSENT; fi`
  ]).trim();
  if (output !== 'PRESENT' && output !== 'ABSENT') {
    throw new Error(`Could not determine persona store state before C11: ${output}`);
  }
  return {
    existed: output === 'PRESENT',
    backupPath: personaBackupPath
  };
}

function restorePersonaMemoryStore(backup) {
  hdc(['shell', 'aa', 'force-stop', 'com.example.aiphonedemo']);
  const restoreCommand = backup.existed
    ? `cp ${backup.backupPath} ${personaStorePath} && cmp -s ${backup.backupPath} ${personaStorePath} && echo RESTORED`
    : `rm -f ${personaStorePath} && [ ! -f ${personaStorePath} ] && echo RESTORED`;
  const output = hdc(['shell', restoreCommand]).trim();
  hdc(['shell', `rm -f ${backup.backupPath}`]);
  if (output !== 'RESTORED') {
    throw new Error(`Persona store restoration could not be verified: ${output}`);
  }
  return {
    ok: true,
    existedBeforeRun: backup.existed
  };
}

function probeLocalModel() {
  const result = spawnSync('hdc', ['-t', target, 'shell', 'curl', '-sS', '-m', '3', 'http://127.0.0.1:11434/v1/models'], {
    encoding: 'utf8',
    maxBuffer: 2 * 1024 * 1024
  });
  const output = `${result.stdout || ''}${result.stderr || ''}`.trim();
  const hdcUnavailable = /Connect server failed/i.test(output);
  const connectionRefused = hdcUnavailable || /Failed to connect|Couldn.t connect|Connection refused|curl:\s*\(7\)/i.test(output);
  const listenerReachable = !connectionRefused && (
    /403|Call is not allowed/i.test(output) ||
    (result.status === 0 && output.length > 0 && !/curl:\s*\(\d+\)/i.test(output))
  );
  return {
    status: result.status,
    hdcUnavailable,
    listenerReachable,
    connectionRefused,
    output: output.length > 500 ? `${output.slice(0, 500)}...<truncated>` : output
  };
}

function startModelFoundation() {
  const result = spawnSync('hdc', ['-t', target, 'shell', 'aa', 'start', '-b', 'com.huawei.hmos.hmmodelfoundation', '-a', 'EntryAbility'], {
    encoding: 'utf8',
    maxBuffer: 2 * 1024 * 1024
  });
  return {
    status: result.status,
    output: `${result.stdout || ''}${result.stderr || ''}`.trim()
  };
}

async function ensureLocalModel() {
  const initial = probeLocalModel();
  if (initial.hdcUnavailable) {
    throw new Error(`hdc unavailable before local model probe: ${initial.output}`);
  }
  if (!initial.connectionRefused) {
    return initial;
  }
  const recovery = startModelFoundation();
  await sleep(3000);
  const afterStart = probeLocalModel();
  if (afterStart.hdcUnavailable) {
    throw new Error(`hdc unavailable after model foundation recovery attempt: ${afterStart.output}`);
  }
  return {
    ...afterStart,
    recovery
  };
}

function cleanupHilogProcesses() {
  const targetHilogPattern = `-t ${target} hilog`;
  const killMatching = (signal) => {
    for (const line of activeHilogProcesses()) {
      if (!line.includes(targetHilogPattern)) {
        continue;
      }
      const match = /^(\d+)\s+/.exec(line);
      if (match !== null) {
        spawnSync('kill', [`-${signal}`, match[1]], { encoding: 'utf8' });
      }
    }
  };
  killMatching('TERM');
  spawnSync('sleep', ['0.3']);
  killMatching('KILL');
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function walk(node, visit) {
  visit(node);
  for (const child of node.children || []) {
    walk(child, visit);
  }
}

function parseBounds(bounds) {
  const match = /^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/.exec(bounds || '');
  if (!match) {
    return null;
  }
  const left = Number.parseInt(match[1], 10);
  const top = Number.parseInt(match[2], 10);
  const right = Number.parseInt(match[3], 10);
  const bottom = Number.parseInt(match[4], 10);
  return {
    left,
    top,
    right,
    bottom,
    width: right - left,
    height: bottom - top,
    x: Math.floor((left + right) / 2),
    y: Math.floor((top + bottom) / 2)
  };
}

function center(bounds) {
  const parsed = parseBounds(bounds);
  if (parsed === null) {
    return null;
  }
  return {
    x: parsed.x,
    y: parsed.y
  };
}

function verticallyOverlaps(a, b) {
  return a.top <= b.bottom && b.top <= a.bottom;
}

function attrIsTrue(value) {
  return value === true || value === 'true';
}

function attrIsFalse(value) {
  return value === false || value === 'false';
}

function dumpLayout(localName = 'latest-layout.json') {
  const remote = '/data/local/tmp/aiphone-smoke-layout.json';
  const local = join(outDir, localName);
  let lastError = null;
  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      hdc(['shell', 'uitest', 'dumpLayout', '-p', remote, '-b', 'com.example.aiphonedemo']);
      hdc(['file', 'recv', remote, local]);
      const raw = readFileSync(local, 'utf8').trim();
      if (raw.length === 0) {
        throw new Error('dumpLayout produced an empty file');
      }
      const layout = JSON.parse(raw);
      if (!Array.isArray(layout.children) || layout.children.length === 0) {
        throw new Error('dumpLayout produced an empty accessibility tree');
      }
      return layout;
    } catch (error) {
      lastError = error;
      spawnSync('sleep', ['0.5']);
    }
  }
  throw lastError instanceof Error ? lastError : new Error(String(lastError));
}

function captureScreen(localName = 'latest-screen.png') {
  moveAppWindowIntoScreenshot();
  const remote = '/data/local/tmp/aiphone-smoke-screen.png';
  const local = join(outDir, localName);
  hdc(['shell', 'uitest', 'screenCap', '-p', remote]);
  hdc(['file', 'recv', remote, local]);
  return local;
}

function collectLayoutText(layout) {
  const values = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    ['text', 'content', 'description', 'hint'].forEach((key) => {
      const value = attrs[key];
      if (typeof value === 'string' && value.trim().length > 0) {
        values.push(value.trim());
      }
    });
  });
  return [...new Set(values)];
}

function findTextCenter(layout, marker) {
  const matches = findTextMatches(layout, marker);
  if (matches.length === 0) {
    return null;
  }
  return {
    x: matches[0].bounds.x,
    y: matches[0].bounds.y
  };
}

function findExactTextCenter(layout, marker) {
  const match = findTextMatches(layout, marker).find((item) =>
    item.text.split('|').some((value) => value.trim() === marker));
  return match === undefined ? null : { x: match.bounds.x, y: match.bounds.y };
}

function findTextCenters(layout, marker) {
  return findTextMatches(layout, marker).map((match) => ({ x: match.bounds.x, y: match.bounds.y }));
}

function findTextMatches(layout, marker) {
  const matches = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    const bounds = parseBounds(attrs.bounds);
    if (bounds === null) {
      return;
    }
    const text = ['text', 'content', 'description', 'hint']
      .map((key) => attrs[key])
      .filter((value) => typeof value === 'string' && value.includes(marker))
      .join('|');
    if (text.length > 0) {
      matches.push({
        text,
        bounds
      });
    }
  });
  matches.sort((a, b) => a.bounds.top - b.bounds.top || a.bounds.left - b.bounds.left);
  return matches;
}

function findHeaderSettingsCenter(layout) {
  const candidates = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    const bounds = parseBounds(attrs.bounds);
    if (bounds === null || !attrIsTrue(attrs.clickable) || attrIsFalse(attrs.enabled)) {
      return;
    }
    if (bounds.top <= 360 && bounds.width >= 32 && bounds.width <= 160 && bounds.height >= 32 && bounds.height <= 160) {
      candidates.push(bounds);
    }
  });
  candidates.sort((left, right) => right.x - left.x);
  return candidates.length >= 2 ? { x: candidates[1].x, y: candidates[1].y } : null;
}

async function findTextCenterWithScroll(marker, localNamePrefix, maxSwipes = 4) {
  for (let attempt = 0; attempt <= maxSwipes; attempt += 1) {
    const layout = dumpLayout(`${localNamePrefix}-${attempt + 1}.json`);
    const text = collectLayoutText(layout).join('\n');
    writeFileSync(join(outDir, `${localNamePrefix}-${attempt + 1}-text.txt`), text + '\n');
    const found = findTextCenter(layout, marker);
    if (found !== null) {
      return found;
    }
    swipeResultsUp();
    await sleep(800);
  }
  return null;
}

function collectInputText(layout) {
  const values = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    if (attrs.type === 'TextInput' || attrs.type === 'TextArea') {
      ['text', 'content', 'description', 'hint'].forEach((key) => {
        const value = attrs[key];
        if (typeof value === 'string' && value.trim().length > 0) {
          values.push(value.trim());
        }
      });
    }
  });
  return values.join('|');
}

function findControls(layout) {
  let input = null;
  let inputBounds = null;
  let generate = null;
  const clickable = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    const bounds = parseBounds(attrs.bounds);
    if ((attrs.type === 'TextInput' || attrs.type === 'TextArea') && input === null && bounds !== null) {
      inputBounds = bounds;
      input = {
        x: bounds.x,
        y: bounds.y
      };
    }
    if (bounds !== null && attrIsTrue(attrs.clickable) && !attrIsFalse(attrs.enabled)) {
      clickable.push({
        type: attrs.type || '',
        text: attrs.text || '',
        bounds
      });
    }
    if (attrs.type === 'Button' && attrs.text === '生成' && bounds !== null) {
      generate = {
        x: bounds.x,
        y: bounds.y
      };
    }
  });
  if (input === null) {
    throw new Error('Could not locate AIPhone input control.');
  }
  if (generate === null && inputBounds !== null) {
    const sendCandidate = clickable
      .filter((item) => item.bounds.left >= inputBounds.right - 4 &&
        item.bounds.left <= inputBounds.right + 360 &&
        verticallyOverlaps(item.bounds, inputBounds) &&
        item.bounds.width >= 24 &&
        item.bounds.width <= 180 &&
        item.bounds.height >= 24 &&
        item.bounds.height <= 180)
      .sort((a, b) => b.bounds.x - a.bounds.x)[0];
    if (sendCandidate) {
      generate = {
        x: sendCandidate.bounds.x,
        y: sendCandidate.bounds.y
      };
    }
  }
  if (generate === null) {
    throw new Error('Could not locate AIPhone send control.');
  }
  return { input, generate };
}

async function waitForControls(localName = 'latest-layout.json', attempts = 10) {
  let lastError = null;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      return findControls(dumpLayout(localName));
    } catch (error) {
      lastError = error;
      await sleep(500);
    }
  }
  throw lastError || new Error('Could not locate AIPhone input/generate controls.');
}

function lineMatchesPid(line, pid) {
  if (pid.length === 0) {
    return true;
  }
  return line.indexOf(` ${pid} `) >= 0;
}

async function captureWhile(appPid, runAction) {
  const logs = [];
  const child = spawn('hdc', ['-t', target, 'hilog'], {
    stdio: ['ignore', 'pipe', 'pipe']
  });
  child.stdout.setEncoding('utf8');
  child.stderr.setEncoding('utf8');
  let buffer = '';
  const onData = (chunk) => {
    buffer += chunk;
    const parts = buffer.split('\n');
    buffer = parts.pop() || '';
    for (const line of parts) {
      if (lineMatchesPid(line, appPid) && (line.includes('AIPhone') || line.includes('aiphonedemo') || line.includes('NETSTACK') || line.includes('11434'))) {
        logs.push(line);
      }
    }
  };
  child.stdout.on('data', onData);
  child.stderr.on('data', onData);

  let actionError = null;
  try {
    await sleep(800);
    await runAction();

    const started = Date.now();
    let doneAt = 0;
    while (Date.now() - started < timeoutMs) {
      await sleep(500);
      const text = logs.join('\n');
      const done = /\[AIPhone\]\[(ToolResult|A2uiHomeToolResult)\] ok=/.test(text) ||
        /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest)\] none/.test(text) ||
        /\[AIPhone\]\[PersonaMemoryUpdate\]/.test(text);
      const hasQueryHtmlDocument = /\[AIPhone\]\[HtmlHomeDocument\][^\n]*source=(?!welcome\b)[^ \n]+[^\n]*chars=\d+[^\n]*blocks=\d+/.test(text);
      if (done && doneAt === 0) {
        doneAt = Date.now();
      }
      if (done && (hasQueryHtmlDocument || Date.now() - doneAt > 3000)) {
        break;
      }
      const modelFailed = /\[AIPhone\]\[(ModelResult|A2uiHomeModelResult)\] ok=false/.test(text);
      const hasToolRequest = /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel)\][^\n]*toolId=/.test(text);
      if (modelFailed && !hasToolRequest && Date.now() - started > 5000) {
        break;
      }
    }
  } catch (error) {
    actionError = error;
  } finally {
    child.kill('SIGTERM');
    await waitForProcessExit(child, 1500);
    if (child.exitCode === null) {
      child.kill('SIGKILL');
      await waitForProcessExit(child, 1500);
    }
    cleanupHilogProcesses();
  }
  if (actionError !== null) {
    throw actionError;
  }
  return logs;
}

function waitForProcessExit(child, timeoutMs) {
  return new Promise((resolve) => {
    let resolved = false;
    const finish = () => {
      if (!resolved) {
        resolved = true;
        resolve();
      }
    };
    child.once('exit', finish);
    setTimeout(finish, timeoutMs);
  });
}

function activeHilogProcesses() {
  const result = spawnSync('ps', ['-axo', 'pid=,command='], { encoding: 'utf8' });
  return result.stdout
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.includes('hdc') && line.includes('hilog'));
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function htmlHomeDocumentEvidence(logs) {
  const documents = [];
  for (const line of logs) {
    const match = /\[AIPhone\]\[HtmlHomeDocument\][^\n]*source=([^ \n]+)[^\n]*kind=([^ \n]+)[^\n]*chars=(\d+)[^\n]*blocks=(\d+)/.exec(line);
    if (match === null) {
      continue;
    }
    documents.push({
      source: match[1],
      kind: match[2],
      chars: Number.parseInt(match[3], 10),
      blocks: Number.parseInt(match[4], 10)
    });
  }
  const queryDocuments = documents.filter((document) => document.source !== 'welcome');
  return {
    count: documents.length,
    queryCount: queryDocuments.length,
    maxChars: documents.reduce((max, document) => Math.max(max, document.chars), 0),
    maxBlocks: documents.reduce((max, document) => Math.max(max, document.blocks), 0),
    ok: queryDocuments.some((document) => document.chars > 0 && document.blocks > 0)
  };
}

function htmlHomeSurfaceLoadEvidence(logs) {
  const loads = [];
  for (const line of logs) {
    const match = /\[AIPhone\]\[HtmlHomeSurfaceLoad\][^\n]*chars=(\d+)[^\n]*renderTick=(\d+)/.exec(line);
    if (match === null) {
      continue;
    }
    loads.push({
      chars: Number.parseInt(match[1], 10),
      renderTick: Number.parseInt(match[2], 10)
    });
  }
  return {
    count: loads.length,
    maxChars: loads.reduce((max, load) => Math.max(max, load.chars), 0),
    ok: loads.some((load) => load.chars > 0)
  };
}

function analyze(query, logs, expectedTool, expectedToolId = '', expectedDiscoveredToolId = '') {
  const text = logs.join('\n');
  const htmlHomeDocument = htmlHomeDocumentEvidence(logs);
  const htmlHomeSurfaceLoad = htmlHomeSurfaceLoadEvidence(logs);
  const escapedToolId = escapeRegExp(expectedToolId);
  const toolIdPattern = expectedToolId.length > 0 ?
    new RegExp(`\\[AIPhone\\]\\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel)\\][^\\n]*toolId=${escapedToolId}`) :
    null;
  const hasExpectedToolId = toolIdPattern === null ? true : toolIdPattern.test(text);
  const discoveryPattern = expectedDiscoveredToolId.length > 0 ?
    new RegExp(`\\[AIPhone\\]\\[DynamicToolDiscovery\\][^\\n]*selectedToolId=${expectedDiscoveredToolId.replace('.', '\\.')}`) :
    null;
  const hasExpectedDiscoveredToolId = discoveryPattern === null ? true : discoveryPattern.test(text);
  const missingConfig = /\[AIPhone\]\[LocalToolMissingConfig\]/.test(text);
  const modelSelectedExpectedToolId = expectedToolId.length === 0 ||
    new RegExp(`"toolId":"${escapedToolId}"`).test(text) ||
    new RegExp(`toolId=${escapedToolId}`).test(text);
  const personaCoffeeProof = !isPersonaCoffeeQuery(query) || /饮食搭子上线|饮食搭子/.test(text);
  const personaMemoryUpdateProof = !isPersonaMemoryUpdateQuery(query) ||
    (/\[AIPhone\]\[PersonaMemoryUpdate\][^\n]*ok=true[^\n]*personaId=food_companion/.test(text) &&
      /\[AIPhone\]\[ToolRequest\][^\n]*toolId=memory\.update/.test(text) &&
      /\[AIPhone\]\[ToolResult\] ok=true toolId=memory\.update/.test(text));
  const result = {
    query,
    expectedTool,
    expectedToolId,
    expectedDiscoveredToolId,
    hasExpectedToolId,
    hasExpectedDiscoveredToolId,
    htmlHomeDocument,
    htmlHomeSurfaceLoad,
    htmlLoadError: /\[AIPhone\]\[HtmlHomeSurfaceLoadError\]/.test(text),
    modelSelectedExpectedToolId,
    personaCoffeeProof,
    personaMemoryUpdateProof,
    directIntent: /\[AIPhone\]\[(ToolRequestByIntent|A2uiHomeToolRequestByIntent)\] toolId=/.test(text),
    localToolRequest: /\[AIPhone\]\[LocalToolRequest\] endpoint=local:\/\/aiphone-tools toolId=/.test(text),
    model200: /\[AIPhone\]\[(ModelStreamResponse|ModelRawResponse)\] code=200/.test(text) || /response_code":200[\s\S]*dst_port":11434/.test(text),
    modelOk: /\[AIPhone\]\[(ModelResult|A2uiHomeModelResult)\] ok=true/.test(text),
    toolRequested: /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel)\][^\n]*toolId=/.test(text),
    toolOk: /\[AIPhone\]\[(ToolResult|A2uiHomeToolResult)\] ok=true/.test(text),
    failedConnect: /failed to connect|Could not connect|Couldn.t connect|ECONNREFUSED|server is not running|CURLcode result 7|curl_code":7|os_errno":111/i.test(text),
    providerFailed: /\[AIPhone\]\[LocalTool12306Endpoint\][^\n]*code=[45]\d\d/.test(text) ||
      /\[AIPhone\]\[LocalToolException\]/.test(text) ||
      /\[AIPhone\]\[A2uiHomeToolOutput\][^\n]*"status":"error"/.test(text) ||
      /Google Calendar API 调用失败/.test(text) ||
      /invalid request data provided|Composio 调用失败|WhatsApp Business 账号不可用/i.test(text) ||
      (missingConfig && expectedToolId !== 'travel.search'),
    modelFailed: /\[AIPhone\]\[(ModelResult|A2uiHomeModelResult)\] ok=false/.test(text),
    toolNone: /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest)\] none/.test(text),
    gmailWebOpened: /\[AIPhone\]\[A2uiHomeOpenUrl\] ok=true url=https:\/\/mail\.google\.com/.test(text),
    worldCupOpened: /\[AIPhone\]\[AnythingDemoRouteByTool\]/.test(text),
    syntheticFallback: forbiddenSyntheticMarkers.some((marker) => text.includes(marker))
  };
  const modelFallbackOnlyAfterSameToolSelection = result.modelFailed && result.directIntent && result.modelSelectedExpectedToolId;
  const modelPassed = modelFallbackOnlyAfterSameToolSelection || (result.model200 && result.modelOk && !result.modelFailed);
  const htmlDocumentPassed = result.htmlHomeDocument.ok ||
    (isSocialHubExpectedToolId(expectedToolId) && result.htmlHomeDocument.count > 0) ||
    (expectedToolId === 'worldcup.open' && result.worldCupOpened);
  const baseWithoutTransport = !result.htmlLoadError &&
    result.htmlHomeSurfaceLoad.ok &&
    !result.syntheticFallback &&
    (!result.directIntent || modelFallbackOnlyAfterSameToolSelection || (expectedToolId === 'worldcup.open' && result.worldCupOpened)) &&
    htmlDocumentPassed;
  result.modelPassed = modelPassed;
  result.transportPassed = !result.failedConnect && !result.providerFailed;
  result.basePassedWithoutTransport = baseWithoutTransport;
  const basePassed = result.transportPassed && baseWithoutTransport;
  if (isPersonaMemoryUpdateQuery(query)) {
    result.modelPassed = result.personaMemoryUpdateProof === true;
    result.transportPassed = true;
    result.basePassedWithoutTransport = true;
    result.ok = result.personaMemoryUpdateProof === true &&
      /\[AIPhone\]\[ToolRequest\][^\n]*toolId=memory\.update/.test(text) &&
      /\[AIPhone\]\[ToolResult\] ok=true toolId=memory\.update/.test(text);
  } else if (expectedTool === true) {
    result.ok = basePassed && modelPassed && result.toolRequested &&
      (result.localToolRequest || (expectedToolId === 'worldcup.open' && result.worldCupOpened)) &&
      result.toolOk && result.hasExpectedToolId && result.hasExpectedDiscoveredToolId && result.personaCoffeeProof;
  } else if (expectedTool === false) {
    result.ok = basePassed && modelPassed && result.toolNone && !result.toolRequested && !result.localToolRequest;
  } else {
    result.ok = basePassed && modelPassed &&
      (result.toolRequested ? (result.localToolRequest && result.toolOk) : (result.toolNone && !result.localToolRequest));
  }
  return result;
}

function isGmailWebQuery(query) {
  return /Gmail|谷歌邮箱|谷歌邮件/i.test(query) && /打开|网页版|网页/.test(query);
}

function isPersonaCoffeeQuery(query) {
  return /点一杯咖啡|来一杯咖啡|买杯咖啡/.test(query);
}

function isPersonaMemoryUpdateQuery(query) {
  return /瑞幸/.test(query) && /只喝|只买|只点/.test(query);
}

function hasLuckinMemoryEvidence(text) {
  return /只展示瑞幸|只喝瑞幸|瑞幸相关真实结果|瑞幸优先/.test(text);
}

function isGmailEccvQuery(query) {
  return /Gmail|谷歌邮箱|谷歌邮件/i.test(query) && /eccv/i.test(query);
}

function isQqMailQuery(query) {
  return /QQ\s*邮箱|QQ邮箱/i.test(query);
}

function isMailAggregationQuery(query) {
  return /Gmail|谷歌邮箱|谷歌邮件/i.test(query) && isQqMailQuery(query);
}

function isYouTubeBilibiliQuery(query) {
  return /YouTube|油管/i.test(query) && /B站|B 站|Bilibili|哔哩哔哩/i.test(query);
}

function isAggregateMediaSearchQuery(query) {
  if (isSocialFeedQuery(query)) {
    return false;
  }
  const wantsTopic = /有关|关于|看看|搜索|搜|聚合|整理|汇总|追踪|了解/.test(query);
  const wantsDiscussion = /新闻|讨论|热议|舆论|观点|帖子|po文|post|posts|reaction|reactions|public/i.test(query);
  if (!wantsTopic || !wantsDiscussion) {
    return false;
  }
  const mentionsVideoSource = /YouTube|油管|B站|B 站|Bilibili|哔哩哔哩/i.test(query);
  const mentionsTextSource = /Twitter|推文|x\.com|知乎|Hacker\s*News|HackNews|HackerNews|\bHN\b|Reddit|红迪/i.test(query) ||
    (hasStandaloneXMarker(query) && /上|平台|推文|公开\s*posts?\b|public\s+posts?\b/i.test(query));
  const asksMixedView = /聚合|多来源|多平台|汇总|新闻.*讨论|讨论.*新闻/.test(query) ||
    (/视频.*讨论|讨论.*视频/.test(query) && (!mentionsVideoSource || mentionsTextSource));
  if (mentionsVideoSource && !mentionsTextSource && !asksMixedView) {
    return false;
  }
  if (isXPostSearchQuery(query) && !mentionsVideoSource && !asksMixedView) {
    return false;
  }
  return asksMixedView || mentionsVideoSource && mentionsTextSource || !mentionsVideoSource && !mentionsTextSource;
}

function isSocialFeedQuery(query) {
  return /社交|消息聚合|多平台消息|已授权应用.*私信|私信消息|Slack|企业微信|Discord|LinkedIn|WhatsApp|Instagram|Instgram/i.test(query);
}

function isSocialHubExpectedToolId(expectedToolId) {
  return expectedToolId === 'social.feed.search';
}

function hasStandaloneXMarker(query) {
  return /(^|[^A-Za-z0-9_])X(?=$|[^A-Za-z0-9_])/i.test(query.replace(/Xcode/gi, ''));
}

function isXPostSearchQuery(query) {
  const text = query.replace(/Xcode/gi, '');
  if (/posts?\s*[- ]?\s*processing/i.test(text)) {
    return false;
  }
  const hasPlatform = /Twitter|推文|x\.com/i.test(text) ||
    (hasStandaloneXMarker(text) && /上|平台|推文|公开\s*posts?\b|public\s+posts?\b/i.test(text));
  return hasPlatform && /读|看|查看|查|查询|搜索|搜|最近|公开|read|search|find|recent|latest|public/i.test(text);
}

function hasTruthfulSocialHubState(text) {
  return /SocialHub/.test(text) &&
    /授权状态/.test(text) &&
    /来源\s*·|暂无可读消息/.test(text) &&
    /发信人\s*·|当前.*不提供|读取失败|尚未连接|没有可读消息|暂无可读消息/i.test(text);
}

function hasVisibleSocialHubOutput(text, expectedToolId) {
  if (!hasTruthfulSocialHubState(text)) {
    return false;
  }
  if (expectedToolId === 'x.post.search') {
    return /\bX\b/.test(text);
  }
  if (expectedToolId === 'social.feed.search') {
    return /来源\s*·/.test(text) && /发信人\s*·/.test(text) && /回复/.test(text) ||
      /暂无可读消息/.test(text);
  }
  return false;
}

function hasVisibleAggregateMediaOutput(text) {
  return /聚合搜索/.test(text) &&
    /视频/.test(text) &&
    /讨论/.test(text) &&
    /YouTube/.test(text) &&
    /B 站/.test(text) &&
    /\bX\b/.test(text) &&
    /\bHN\b/.test(text);
}

function isCalendarQuery(query) {
  return /Google\s*Calendar|谷歌日历/i.test(query) || /日程|会议|约会/.test(query);
}

function isComposioCardQuery(query) {
  return (/GitHub/i.test(query) && /Appless-Phone/i.test(query) && /\bpr\b|pull\s*request/i.test(query)) ||
    (/Google\s*Drive/i.test(query) && /专利交底书/.test(query)) ||
    (/Google\s*Docs?/i.test(query) && /AIPhoneDemo/.test(query)) ||
    (/Composio/i.test(query) && /Slack/i.test(query) && /AIPhoneDemo/.test(query) && !isSocialFeedQuery(query)) ||
    (/Outlook|Spotify|Soptify|TikTok|Ticketmaster/i.test(query) && !isSocialFeedQuery(query));
}

function layoutExpectationsForQuery(query) {
  if (isPersonaMemoryUpdateQuery(query)) {
    return [];
  }
  if (isSocialFeedQuery(query) && !isWhatsAppSendQuery(query)) {
    return ['SocialHub', '授权状态'];
  }
  if (/GitHub/i.test(query) && /Appless-Phone/i.test(query) && /\bpr\b|pull\s*request/i.test(query)) {
    return ['Composio 工具结果', 'Composio GitHub 结果', 'GITHUB_FIND_PULL_REQUESTS', 'Appless-Phone'];
  }
  if (/Google\s*Drive/i.test(query) && /专利交底书/.test(query)) {
    return ['Composio 工具结果', 'Composio Google Drive 结果', 'GOOGLEDRIVE_FIND_FILE', '专利交底书'];
  }
  if (/Google\s*Docs?/i.test(query) && /AIPhoneDemo/.test(query)) {
    return ['Composio 工具结果', 'Composio Google Docs 结果', 'GOOGLEDOCS_SEARCH_DOCUMENTS', 'AIPhoneDemo'];
  }
  if (/Composio/i.test(query) && /Slack/i.test(query) && /AIPhoneDemo/.test(query)) {
    return ['Composio 工具结果', 'Composio Slack 结果', 'SLACK_SEARCH_MESSAGES', 'AIPhoneDemo'];
  }
  if (/Outlook/i.test(query)) {
    return ['Composio Outlook 结果', 'Outlook'];
  }
  if (/Discord/i.test(query)) {
    return ['Composio Discord 结果', 'Discord'];
  }
  if (/LinkedIn/i.test(query)) {
    return ['Composio LinkedIn 结果', 'LinkedIn'];
  }
  if (isWhatsAppSendQuery(query)) {
    return ['WhatsApp Business', 'whatsapp.message.send', '确认发送'];
  }
  if (/Spotify|Soptify/i.test(query)) {
    return ['Composio Spotify 结果', 'Spotify'];
  }
  if (/TikTok/i.test(query)) {
    return ['Composio TikTok 结果', 'TikTok'];
  }
  if (/Ticketmaster/i.test(query)) {
    return ['Composio Ticketmaster 结果', 'Ticketmaster'];
  }
  if (/^你好$|问候|打招呼/.test(query)) {
    return ['你好'];
  }
  if (/船票|轮渡|客船|渡轮|码头/.test(query)) {
    return ['接入工具', 'dynamic.search', '没有找到'];
  }
  if (/天气|气温|下雨|降雨/.test(query)) {
    return ['接入工具', 'weather.query', 'AMAP_MAPS_API_KEY', '高德天气预报', '预报日期'];
  }
  if (/统计局|GDP|CPI|人口|经济数据/.test(query)) {
    return ['接入工具', 'statistics.search', 'Authorization', '中国国家统计局'];
  }
  if (/PPT|ppt|幻灯片|演示文稿/.test(query)) {
    return ['接入工具', 'ppt.generate', 'API_KEY', 'unsupported_transport', '歌者PPT'];
  }
  if (isXPostSearchQuery(query) && (!isSocialFeedQuery(query) || /公开\s*posts?\b|public\s+posts?\b|x\.com/i.test(query))) {
    return ['Composio', 'x.post.search', 'Twitter'];
  }
  if (isSocialFeedQuery(query)) {
    return ['SocialHub'];
  }
  if (isMailAggregationQuery(query)) {
    return ['mail.search', 'Gmail', 'QQ Mail', 'Outlook', '不会模拟'];
  }
  if (isQqMailQuery(query)) {
    return ['mail.search', 'QQ Mail', '不会模拟'];
  }
  if (/邮箱|邮件|收件箱/.test(query) && !/Gmail|谷歌邮箱|谷歌邮件/i.test(query)) {
    return ['mail.search', 'Gmail', 'QQ Mail', 'Outlook', '不会模拟'];
  }
  if (isGmailWebQuery(query)) {
    return ['Gmail Web', 'gmail.open.web', 'https://mail.google.com'];
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/i.test(query) && /直接发送|立刻发送|马上发送|不确认直接发/.test(query)) {
    return ['UnsafeActionBlocked', '不会自动发送 Gmail', 'gmail.message.send'];
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/i.test(query) && /写一封|写邮件|起草|草稿|回复|撰写/.test(query)) {
    return ['gmail.draft.create', 'Composio Gmail', '授权 Gmail', 'Draft saved', 'Saved in Gmail', 'ready_to_apply', '不会模拟 Gmail 邮件'];
  }
  if (isGmailEccvQuery(query)) {
    return ['Composio', 'Gmail', 'gmail.mail.search', '不会模拟 Gmail 邮件'];
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/i.test(query)) {
    return ['Composio', 'Gmail', 'gmail.mail.search', '不会模拟 Gmail 邮件'];
  }
  if (/PayPal|Google\s*Pay|GPay|支付|转账|付款/i.test(query)) {
    return ['AIPhone Pay', 'PayPal', 'Google Pay', '5 USD', '确认支付'];
  }
  if (/YouTube|油管/i.test(query) && /播放列表|playlist/i.test(query)) {
    return ['Composio', 'YouTube', 'youtube.mine.playlists', '不会模拟播放列表'];
  }
  if (/YouTube|油管/i.test(query) && /订阅|subscriptions?/i.test(query)) {
    return ['Composio', 'YouTube', 'youtube.mine.subscriptions', '不会模拟播放列表'];
  }
  if (isYouTubeBilibiliQuery(query)) {
    return ['YouTube', 'YouTube Data API', '哔哩哔哩', 'Bilibili'];
  }
  if (isAggregateMediaSearchQuery(query)) {
    return ['聚合搜索', '视频', '讨论', 'YouTube', 'B 站', 'X', 'HN', 'Reddit'];
  }
  if (/YouTube|油管/i.test(query)) {
    return ['YouTube', 'youtube.video.search', 'YouTube Data API', 'YOUTUBE_API_KEY'];
  }
  if (/B站|B 站|Bilibili|哔哩哔哩/i.test(query)) {
    return ['哔哩哔哩', 'media.video.search', '跳转'];
  }
  if (isCalendarQuery(query)) {
    return /删除|取消/.test(query)
      ? ['Composio', 'Google Calendar', 'calendar.event.delete']
      : (/创建|新建|添加|安排|预约/.test(query)
      ? ['Composio', 'Google Calendar', 'calendar.event.create']
      : (/改到|改成|更新|挪到|延期/.test(query)
        ? ['Composio', 'Google Calendar', 'calendar.event.update']
        : ['Composio', 'Google Calendar', 'calendar.events.search']));
  }
  if (/Google\s*Maps?|Google\s*Places|GMap|谷歌地图/i.test(query)) {
    return isMapsRouteQuery(query)
      ? ['Google Maps', '查看路线']
      : ['Google Places', 'Google Maps', 'GOOGLE_MAPS_API_KEY', 'maps.place.search'];
  }
  if (/出行方案|搜索出行|怎么去|比较出行|出行选项|整理可查|可查的出行/.test(query)) {
    return ['北京', '上海'];
  }
  if (/航班|机票|飞机/.test(query)) {
    return ['航班', '飞常准', 'flight.search', '来源状态'];
  }
  if (/高铁|火车|车票|12306/.test(query)) {
    return ['高铁', '12306', 'train.search'];
  }
  if (isHotelQuery(query)) {
    return ['酒店 · 实时房价', 'RollingGo', '查看详情'];
  }
  if (/瑞幸|luckin|ruixing/i.test(query) && /点一杯|点杯|点个瑞幸|点瑞幸|帮我点|我要点|下单|下一杯|买一杯|帮我买|购买一杯|购买瑞幸|来一杯|要一杯/.test(query)) {
    return ['瑞幸', 'luckin.order.preview', '选择瑞幸门店', '确认瑞幸订单', '确认下单'];
  }
  if (/附近|周边|外卖|咖啡|奶茶|肯德基|麦当劳|瑞幸|汉堡|餐饮|美食/.test(query)) {
    if (isPersonaCoffeeQuery(query)) {
      return ['饮食搭子', '餐饮', '咖啡', '高德', '百度地图'];
    }
    return ['奶茶', '餐饮', '高德', '腾讯地图', '百度地图', '美团', '淘宝闪购'];
  }
  return [];
}

function swipeResultsUp() {
  hdc(['shell', 'uitest', 'uiInput', 'swipe', '650', '2200', '650', '950', '600']);
}

function requiredScrolledMarkersForQuery(query, expectedToolId) {
  if (expectedToolId === 'mail.search') {
    if (isQqMailQuery(query)) {
      return ['QQ Mail'];
    }
    return ['Gmail', 'QQ Mail', 'Outlook'];
  }
  if (expectedToolId === 'gmail.mail.search' && isGmailEccvQuery(query)) {
    return ['ECCV'];
  }
  if (expectedToolId === 'media.aggregate.search') {
    return ['聚合搜索', '视频', '讨论', 'YouTube', 'B 站', 'X', 'HN', 'Reddit'];
  }
  return [];
}

async function collectScrolledLayoutEvidence(initialLayout, initialText, index, requiredMarkers) {
  const texts = [initialText];
  const layoutPaths = [join(outDir, `query-${index + 1}-final-layout.json`)];
  const textPaths = [join(outDir, `query-${index + 1}-final-layout-text.txt`)];
  const screenPaths = [];
  let currentLayout = initialLayout;
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const combinedText = texts.join('\n');
    if (requiredMarkers.every((marker) => combinedText.includes(marker))) {
      break;
    }
    swipeResultsUp();
    await sleep(900);
    currentLayout = dumpLayout(`query-${index + 1}-scroll-${attempt + 1}-layout.json`);
    const scrolledText = collectLayoutText(currentLayout).join('\n');
    const scrolledTextPath = join(outDir, `query-${index + 1}-scroll-${attempt + 1}-layout-text.txt`);
    writeFileSync(scrolledTextPath, scrolledText + '\n');
    const scrolledScreenPath = captureScreen(`query-${index + 1}-scroll-${attempt + 1}-screen.png`);
    texts.push(scrolledText);
    layoutPaths.push(join(outDir, `query-${index + 1}-scroll-${attempt + 1}-layout.json`));
    textPaths.push(scrolledTextPath);
    screenPaths.push(scrolledScreenPath);
  }
  const uniqueText = [...new Set(texts.join('\n').split('\n').filter((line) => line.trim().length > 0))].join('\n');
  const combinedTextPath = join(outDir, `query-${index + 1}-scrolled-layout-text.txt`);
  writeFileSync(combinedTextPath, uniqueText + '\n');
  return {
    text: uniqueText,
    currentLayout,
    combinedTextPath,
    layoutPaths,
    textPaths,
    screenPaths,
    requiredMarkers,
    foundMarkers: requiredMarkers.filter((marker) => uniqueText.includes(marker))
  };
}

function expandMatchesForTarget(layout, targetMarker) {
  const expands = findTextMatches(layout, '展开')
    .filter((item) => item.bounds.y > 400 && item.bounds.y < 2450);
  if (targetMarker.length === 0) {
    return expands;
  }
  const targets = findTextMatches(layout, targetMarker);
  if (targets.length === 0) {
    return [];
  }
  return expands
    .filter((expand) => targets.some((target) =>
      Math.abs(expand.bounds.y - target.bounds.y) < 360 ||
      verticallyOverlaps(expand.bounds, target.bounds)))
    .sort((left, right) => {
      const leftDistance = Math.min(...targets.map((target) => Math.abs(left.bounds.y - target.bounds.y)));
      const rightDistance = Math.min(...targets.map((target) => Math.abs(right.bounds.y - target.bounds.y)));
      return leftDistance - rightDistance;
    });
}

async function verifyMailExpandedBody(layout, index) {
  let currentLayout = layout;
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const matches = expandMatchesForTarget(currentLayout, '');
    if (matches.length > 0) {
      const target = matches[0].bounds;
      hdc(['shell', 'uitest', 'uiInput', 'click', String(target.x), String(target.y)]);
      await sleep(900);
      const expanded = dumpLayout(`query-${index + 1}-mail-body-layout.json`);
      const text = collectLayoutText(expanded).join('\n');
      const textPath = join(outDir, `query-${index + 1}-mail-body-layout-text.txt`);
      writeFileSync(textPath, text + '\n');
      return {
        ok: /正文|发件人|收件人|主题|回复/.test(text) && !hasTechnicalGmailArgsCard(text),
        capability: 'mail.thread.read',
        textPath,
        screenPath: captureScreen(`query-${index + 1}-mail-body-screen.png`)
      };
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-mail-body-scroll-${attempt + 1}.json`);
  }
  return { ok: false, capability: 'mail.thread.read', reason: 'mail expand button not found' };
}

async function verifySocialDraftAction(layout, index) {
  let currentLayout = layout;
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const center = findTextCenter(currentLayout, '生成草稿');
    if (center !== null) {
      hdc(['shell', 'uitest', 'uiInput', 'click', String(center.x), String(center.y)]);
      await sleep(1000);
      const resultLayout = dumpLayout(`query-${index + 1}-social-draft-layout.json`);
      const text = collectLayoutText(resultLayout).join('\n');
      const textPath = join(outDir, `query-${index + 1}-social-draft-layout-text.txt`);
      writeFileSync(textPath, text + '\n');
      return {
        ok: /回复草稿|本地草稿预览|尚未生成草稿/.test(text) && !/已发送|发送成功/.test(text),
        capability: 'social.reply.draft',
        textPath,
        screenPath: captureScreen(`query-${index + 1}-social-draft-screen.png`)
      };
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-social-draft-scroll-${attempt + 1}.json`);
  }
  return { ok: false, capability: 'social.reply.draft', reason: '生成草稿 button not found' };
}

async function verifyCalendarDeleteAction(layout, index, appPid) {
  let currentLayout = layout;
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const center = findTextCenter(currentLayout, '确认删除');
    if (center !== null) {
      clearHilog();
      const actionLogs = await captureWhile(appPid, async () => {
        hdc(['shell', 'uitest', 'uiInput', 'click', String(center.x), String(center.y)]);
      });
      const resultLayout = dumpLayout(`query-${index + 1}-calendar-delete-layout.json`);
      const text = collectLayoutText(resultLayout).join('\n');
      const logs = actionLogs.join('\n');
      const logPath = join(outDir, `query-${index + 1}-calendar-delete.log`);
      const textPath = join(outDir, `query-${index + 1}-calendar-delete-layout-text.txt`);
      writeFileSync(logPath, logs + '\n');
      writeFileSync(textPath, text + '\n');
      return {
        ok: /calendar\.event\.delete/.test(`${text}\n${logs}`) &&
          !/status":"error"|删除失败/.test(`${text}\n${logs}`),
        capability: 'calendar.event.delete.confirm',
        logPath,
        textPath,
        screenPath: captureScreen(`query-${index + 1}-calendar-delete-screen.png`)
      };
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-calendar-delete-scroll-${attempt + 1}.json`);
  }
  return { ok: false, capability: 'calendar.event.delete.confirm', reason: '确认删除 button not found' };
}

async function verifyHotelDetailAction(layout, index, appPid) {
  let currentLayout = layout;
  let expandCenter = null;
  for (let attempt = 0; attempt < 8; attempt += 1) {
    expandCenter = findTextCenter(currentLayout, '查看详情');
    if (expandCenter !== null) {
      break;
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-hotel-search-scroll-${attempt + 1}.json`);
  }
  if (expandCenter === null) {
    return { ok: false, capability: 'hotel.detail', reason: 'hotel expand button not found' };
  }
  hdc(['shell', 'uitest', 'uiInput', 'click', String(expandCenter.x), String(expandCenter.y)]);
  await sleep(700);
  currentLayout = dumpLayout(`query-${index + 1}-hotel-expanded-layout.json`);
  const expandedTextPath = join(outDir, `query-${index + 1}-hotel-expanded-layout-text.txt`);
  writeFileSync(expandedTextPath, collectLayoutText(currentLayout).join('\n') + '\n');
  const expandedScreenPath = captureScreen(`query-${index + 1}-hotel-expanded-screen.png`);

  let detailCenter = null;
  for (let attempt = 0; attempt < 8; attempt += 1) {
    detailCenter = findTextCenter(currentLayout, '查看实时房型');
    if (detailCenter !== null) {
      break;
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-hotel-detail-scroll-${attempt + 1}.json`);
  }
  if (detailCenter === null) {
    return {
      ok: false,
      capability: 'hotel.detail',
      reason: 'hotel detail button not found',
      expandedTextPath,
      expandedScreenPath
    };
  }

  clearHilog();
  const detailLogs = await captureWhile(appPid, async () => {
    hdc(['shell', 'uitest', 'uiInput', 'click', String(detailCenter.x), String(detailCenter.y)]);
  });
  const detailLogText = detailLogs.join('\n');
  const detailLogPath = join(outDir, `query-${index + 1}-hotel-detail.log`);
  writeFileSync(detailLogPath, detailLogText + '\n');
  await sleep(700);
  currentLayout = dumpLayout(`query-${index + 1}-hotel-rates-layout.json`);

  let rateExpand = findTextCenter(currentLayout, '查看详情');
  for (let attempt = 0; rateExpand === null && attempt < 6; attempt += 1) {
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-hotel-rates-scroll-${attempt + 1}.json`);
    rateExpand = findTextCenter(currentLayout, '查看详情');
  }
  if (rateExpand !== null) {
    hdc(['shell', 'uitest', 'uiInput', 'click', String(rateExpand.x), String(rateExpand.y)]);
    await sleep(700);
    currentLayout = dumpLayout(`query-${index + 1}-hotel-rate-expanded-layout.json`);
  }
  const text = collectLayoutText(currentLayout).join('\n');
  const textPath = join(outDir, `query-${index + 1}-hotel-rate-expanded-layout-text.txt`);
  writeFileSync(textPath, text + '\n');
  const detailRequested = /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel)\][^\n]*toolId=hotel\.detail/.test(detailLogText) ||
    /\[AIPhone\]\[LocalToolRequest\][^\n]*toolId=hotel\.detail/.test(detailLogText);
  const detailOk = /\[AIPhone\]\[(ToolResult|A2uiHomeToolResult|LocalToolResult)\][^\n]*ok=true/.test(detailLogText);
  return {
    ok: detailRequested && detailOk && /实时房型/.test(text) && /床型|餐食|取消政策/.test(text),
    capability: 'hotel.detail',
    detailRequested,
    detailOk,
    expandedTextPath,
    expandedScreenPath,
    detailLogPath,
    textPath,
    screenPath: captureScreen(`query-${index + 1}-hotel-rate-expanded-screen.png`)
  };
}

async function findVisibleReplyDraftAction(layout, index) {
  let currentLayout = layout;
  let actionText = collectLayoutText(currentLayout).join('\n');
  let actionLayoutPath = '';
  let actionTextPath = '';
  let actionScreenPath = '';
  for (let attempt = 0; attempt < mailActionScrollLimit; attempt += 1) {
    actionLayoutPath = join(outDir, `query-${index + 1}-mail-action-${attempt + 1}-layout.json`);
    actionTextPath = join(outDir, `query-${index + 1}-mail-action-${attempt + 1}-layout-text.txt`);
    writeFileSync(actionLayoutPath, JSON.stringify(currentLayout, null, 2));
    writeFileSync(actionTextPath, actionText + '\n');
    actionScreenPath = captureScreen(`query-${index + 1}-mail-action-${attempt + 1}-screen.png`);
    if (actionText.includes('AI 回复草稿') || actionText.split('\n').includes('回复')) {
      return {
        layout: currentLayout,
        text: actionText,
        layoutPath: actionLayoutPath,
        textPath: actionTextPath,
        screenPath: actionScreenPath
      };
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-mail-action-${attempt + 2}-layout.json`);
    actionLayoutPath = join(outDir, `query-${index + 1}-mail-action-${attempt + 2}-layout.json`);
    actionText = collectLayoutText(currentLayout).join('\n');
  }
  return {
    layout: currentLayout,
    text: actionText,
    layoutPath: actionLayoutPath,
    textPath: actionTextPath,
    screenPath: actionScreenPath
  };
}

function mailReplyEditorText(layout) {
  const values = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    if (String(attrs.type || '').toLowerCase() !== 'textfield') {
      return;
    }
    const value = typeof attrs.text === 'string' ? attrs.text.trim() : '';
    if (value.length > 0) {
      values.push(value);
    }
  });
  return values.join('\n');
}

async function verifyMailReplyComposer(actionEvidence, index) {
  const replyCenter = findExactTextCenter(actionEvidence.layout, '回复');
  if (replyCenter === null) {
    return null;
  }
  hdc(['shell', 'uitest', 'uiInput', 'click', String(replyCenter.x), String(replyCenter.y)]);
  await sleep(900);
  let composerLayout = dumpLayout(`query-${index + 1}-mail-reply-editor-layout.json`);
  let composerText = collectLayoutText(composerLayout).join('\n');
  const editorLayoutPath = join(outDir, `query-${index + 1}-mail-reply-editor-layout.json`);
  const editorTextPath = join(outDir, `query-${index + 1}-mail-reply-editor-layout-text.txt`);
  writeFileSync(editorTextPath, composerText + '\n');
  const editorScreenPath = captureScreen(`query-${index + 1}-mail-reply-editor-screen.png`);
  const aiCenter = findExactTextCenter(composerLayout, 'AI回复');
  if (aiCenter === null) {
    return {
      clicked: true,
      actionVisible: true,
      draftClicked: false,
      draftToolRequested: false,
      draftToolOk: false,
      draftVisible: false,
      reason: 'Reply editor opened without an AI reply button.',
      layoutPath: editorLayoutPath,
      layoutTextPath: editorTextPath,
      screenPath: editorScreenPath
    };
  }
  clearHilog();
  hdc(['shell', 'uitest', 'uiInput', 'click', String(aiCenter.x), String(aiCenter.y)]);
  let generated = '';
  for (let attempt = 0; attempt < 45; attempt += 1) {
    await sleep(2000);
    composerLayout = dumpLayout(`query-${index + 1}-mail-reply-ai-layout.json`);
    generated = mailReplyEditorText(composerLayout);
    if (generated.length > 0) {
      break;
    }
  }
  const aiLayoutPath = join(outDir, `query-${index + 1}-mail-reply-ai-layout.json`);
  const aiTextPath = join(outDir, `query-${index + 1}-mail-reply-ai-layout-text.txt`);
  composerText = collectLayoutText(composerLayout).join('\n');
  writeFileSync(aiTextPath, composerText + '\n');
  const aiScreenPath = captureScreen(`query-${index + 1}-mail-reply-ai-screen.png`);
  if (generated.length === 0) {
    return {
      clicked: true,
      actionVisible: true,
      draftClicked: true,
      draftToolRequested: false,
      draftToolOk: false,
      draftVisible: false,
      reason: 'AI reply button did not populate the editor.',
      layoutPath: aiLayoutPath,
      layoutTextPath: aiTextPath,
      screenPath: aiScreenPath
    };
  }
  let saveCenter = findExactTextCenter(composerLayout, '保存草稿');
  for (let attempt = 0; saveCenter === null && attempt < 5; attempt += 1) {
    hdc(['shell', 'uitest', 'uiInput', 'swipe', '650', '1350', '650', '650', '500']);
    await sleep(800);
    composerLayout = dumpLayout(`query-${index + 1}-mail-reply-save-${attempt + 1}-layout.json`);
    saveCenter = findExactTextCenter(composerLayout, '保存草稿');
  }
  if (saveCenter === null) {
    return {
      clicked: true,
      actionVisible: true,
      draftClicked: true,
      draftToolRequested: false,
      draftToolOk: false,
      draftVisible: true,
      reason: 'AI reply was generated but the save draft button was not reachable.',
      layoutPath: aiLayoutPath,
      layoutTextPath: aiTextPath,
      screenPath: aiScreenPath
    };
  }
  hdc(['shell', 'uitest', 'uiInput', 'click', String(saveCenter.x), String(saveCenter.y)]);
  let saved = false;
  let savedLayout = composerLayout;
  for (let attempt = 0; attempt < 45; attempt += 1) {
    await sleep(2000);
    savedLayout = dumpLayout(`query-${index + 1}-mail-reply-saved-layout.json`);
    if (!collectLayoutText(savedLayout).includes('编辑回复')) {
      saved = true;
      break;
    }
  }
  const savedLayoutPath = join(outDir, `query-${index + 1}-mail-reply-saved-layout.json`);
  const savedTextPath = join(outDir, `query-${index + 1}-mail-reply-saved-layout-text.txt`);
  const savedText = collectLayoutText(savedLayout).join('\n');
  writeFileSync(savedTextPath, savedText + '\n');
  const savedScreenPath = captureScreen(`query-${index + 1}-mail-reply-saved-screen.png`);
  const draftLogs = hdc(['shell', 'hilog', '-x']);
  const draftLogPath = join(outDir, `query-${index + 1}-mail-draft.log`);
  writeFileSync(draftLogPath, draftLogs);
  const draftToolRequested = draftLogs.includes('id=html_mail_reply_save');
  const draftToolOk = saved && draftToolRequested && !draftLogs.includes('[AIPhone][MailReplyOperationFailed]');
  return {
    clicked: true,
    actionVisible: true,
    draftClicked: true,
    draftToolRequested,
    draftToolOk,
    draftVisible: generated.length > 0,
    draftModelFailed: false,
    draftProviderFailed: !draftToolOk,
    layoutPath: actionEvidence.layoutPath,
    layoutTextPath: actionEvidence.textPath,
    screenPath: actionEvidence.screenPath,
    draftLogPath,
    draftLayoutPath: savedLayoutPath,
    draftTextPath: savedTextPath,
    draftScreenPath: savedScreenPath
  };
}

async function verifyMailExpandedActions(layout, index, appPid, targetMarker = '') {
  let currentLayout = layout;
  let lastExpandedText = '';
  let lastExpandedTextPath = '';
  let lastExpandedLayoutPath = '';
  let lastExpandedScreenPath = '';
  for (let page = 0; page < 6; page += 1) {
    const matches = expandMatchesForTarget(currentLayout, targetMarker);
    for (let matchIndex = 0; matchIndex < matches.length; matchIndex += 1) {
      const clickTarget = matches[matchIndex].bounds;
      hdc(['shell', 'uitest', 'uiInput', 'click', String(clickTarget.x), String(clickTarget.y)]);
      await sleep(900);
      currentLayout = dumpLayout(`query-${index + 1}-mail-expanded-layout.json`);
      lastExpandedLayoutPath = join(outDir, `query-${index + 1}-mail-expanded-layout.json`);
      lastExpandedText = collectLayoutText(currentLayout).join('\n');
      lastExpandedTextPath = join(outDir, `query-${index + 1}-mail-expanded-layout-text.txt`);
      writeFileSync(lastExpandedTextPath, lastExpandedText + '\n');
      lastExpandedScreenPath = captureScreen(`query-${index + 1}-mail-expanded-screen.png`);
      const actionEvidence = await findVisibleReplyDraftAction(currentLayout, index);
      lastExpandedText = actionEvidence.text;
      lastExpandedTextPath = actionEvidence.textPath;
      lastExpandedLayoutPath = actionEvidence.layoutPath;
      lastExpandedScreenPath = actionEvidence.screenPath;
      currentLayout = actionEvidence.layout;
      if (!actionEvidence.text.includes('AI 回复草稿') && !actionEvidence.text.split('\n').includes('回复')) {
        continue;
      }
      const composerEvidence = await verifyMailReplyComposer(actionEvidence, index);
      if (composerEvidence !== null) {
        return {
          ...composerEvidence,
          targetMarker
        };
      }
      const draftCenter = findTextCenter(actionEvidence.layout, 'AI 回复草稿');
      if (draftCenter === null) {
        return {
          clicked: true,
          actionVisible: true,
          draftClicked: false,
          draftToolRequested: false,
          draftToolOk: false,
          draftVisible: false,
          targetMarker,
          reason: 'AI 回复草稿 was visible but no clickable center was found.',
          layoutPath: lastExpandedLayoutPath,
          layoutTextPath: lastExpandedTextPath,
          screenPath: lastExpandedScreenPath
        };
      }
      clearHilog();
      await sleep(300);
      const draftLogs = await captureWhile(appPid, async () => {
        hdc(['shell', 'uitest', 'uiInput', 'click', String(draftCenter.x), String(draftCenter.y)]);
      });
      const draftLogPath = join(outDir, `query-${index + 1}-mail-draft.log`);
      writeFileSync(draftLogPath, draftLogs.join('\n') + '\n');
      const draftLogText = draftLogs.join('\n');
      const draftLayout = dumpLayout(`query-${index + 1}-mail-draft-layout.json`);
      const draftLayoutPath = join(outDir, `query-${index + 1}-mail-draft-layout.json`);
      const draftText = collectLayoutText(draftLayout).join('\n');
      const draftTextPath = join(outDir, `query-${index + 1}-mail-draft-layout-text.txt`);
      writeFileSync(draftTextPath, draftText + '\n');
      const draftScreenPath = captureScreen(`query-${index + 1}-mail-draft-screen.png`);
      const draftToolRequested = /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel)\][^\n]*toolId=(gmail|mail)\.draft\.create/.test(draftLogText) ||
        /\[AIPhone\]\[LocalToolRequest\][^\n]*toolId=(gmail|mail)\.draft\.create/.test(draftLogText) ||
        /\b(gmail|mail)\.draft\.create\b/.test(draftText);
      const draftToolOk = draftToolRequested &&
        /\[AIPhone\]\[(ToolResult|A2uiHomeToolResult)\][^\n]*ok=true/.test(draftLogText) &&
        !/failed to connect|Could not connect|Couldn.t connect|ECONNREFUSED|CURLcode result 7|curl_code":7|os_errno":111/i.test(draftLogText);
      const draftVisible = /\b(gmail|mail)\.draft\.create\b|Draft saved|Saved in Gmail|Mail Draft Preview|草稿|跳转到Gmail/.test(draftText);
      const draftModelFailed = /\[AIPhone\]\[ModelException\]|\[AIPhone\]\[(ModelResult|A2uiHomeModelResult)\][^\n]*ok=false/.test(draftLogText);
      const draftProviderFailed = /Operation timeout|2300028|2300056|Failed to receive data from the peer|QQ IMAP timeout|Gmail 调用失败|QQ 邮箱调用失败/i.test(draftLogText);
      return {
        clicked: true,
        actionVisible: true,
        draftClicked: true,
        draftToolRequested,
        draftToolOk,
        draftVisible,
        draftModelFailed,
        draftProviderFailed,
        targetMarker,
        layoutPath: lastExpandedLayoutPath,
        layoutTextPath: lastExpandedTextPath,
        screenPath: lastExpandedScreenPath,
        draftLogPath,
        draftLayoutPath,
        draftTextPath,
        draftScreenPath
      };
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-mail-search-scroll-${page + 1}-layout.json`);
  }
  if (lastExpandedText.length === 0) {
    return {
      clicked: false,
      actionVisible: false,
      draftClicked: false,
      draftToolRequested: false,
      draftToolOk: false,
      draftVisible: false,
      targetMarker,
      reason: 'Could not locate a visible mail result expand button.'
    };
  }
  return {
    clicked: true,
    actionVisible: false,
    draftClicked: false,
    draftToolRequested: false,
    draftToolOk: false,
    draftVisible: false,
    targetMarker,
    layoutPath: lastExpandedLayoutPath,
    layoutTextPath: lastExpandedTextPath,
    screenPath: lastExpandedScreenPath
  };
}

async function runQuery(query, index, expectedTool) {
  clearHilog();
  hdc(['shell', 'aa', 'force-stop', 'com.example.aiphonedemo']);
  if (cleanData) {
    cleanBundleData();
  }
  hdc(['shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.example.aiphonedemo']);
  await sleep(3000);
  moveAppWindowIntoScreenshot();
  const appPid = hdc(['shell', 'pidof', 'com.example.aiphonedemo']).trim().split(/\s+/)[0] || '';
  const controls = await waitForControls();
  const logs = await captureWhile(appPid, async () => {
    let typed = false;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      hdc(['shell', 'uitest', 'uiInput', 'click', String(controls.input.x), String(controls.input.y)]);
      hdc(['shell', 'uitest', 'uiInput', 'keyEvent', '2072', '2017']);
      hdc(['shell', 'uitest', 'uiInput', 'keyEvent', '2055']);
      hdc(['shell', 'uitest', 'uiInput', 'text', query]);
      await sleep(1200);
      const inputText = collectInputText(dumpLayout(`query-${index + 1}-input-attempt-${attempt + 1}.json`));
      if (inputText.includes(query)) {
        typed = true;
        break;
      }
    }
    if (!typed) {
      throw new Error(`Could not type full query into AIPhone input: ${query}`);
    }
    const submitControls = await waitForControls(`query-${index + 1}-submit-layout.json`, 2);
    hdc(['shell', 'uitest', 'uiInput', 'click', String(submitControls.generate.x), String(submitControls.generate.y)]);
  });
  const logPath = join(outDir, `query-${index + 1}.log`);
  writeFileSync(logPath, logs.join('\n') + '\n');
  const expectedCase = useDefaultCases ? selectedDefaultCases[index] : expectedCaseForQuery(query);
  const expectedToolId = expectedCase.expectedToolId || '';
  const expectedDiscoveredToolId = expectedCase.expectedDiscoveredToolId || '';
  const expectedPersonaMemory = expectedCase.expectedPersonaMemory || '';
  const summary = analyze(query, logs, expectedTool, expectedToolId, expectedDiscoveredToolId);
  summary.caseId = expectedCase.id || '';
  summary.expectedPersonaMemory = expectedPersonaMemory;
  summary.logPath = logPath;
  const layout = dumpLayout(`query-${index + 1}-final-layout.json`);
  const layoutTextValues = collectLayoutText(layout);
  const layoutText = layoutTextValues.join('\n');
  const layoutTextPath = join(outDir, `query-${index + 1}-final-layout-text.txt`);
  writeFileSync(layoutTextPath, layoutText + '\n');
  const expectedMarkers = layoutExpectationsForQuery(query);
  const scrollEvidence = await collectScrolledLayoutEvidence(
    layout,
    layoutText,
    index,
    requiredScrolledMarkersForQuery(query, expectedToolId)
  );
  const evidenceText = scrollEvidence.text;
  const evidenceLayout = scrollEvidence.currentLayout;
  if (isPersonaCoffeeQuery(query) && /饮食搭子上线|饮食搭子/.test(evidenceText)) {
    summary.personaCoffeeProof = true;
    summary.personaExpectedMemoryProof = expectedPersonaMemory !== 'luckin_only' || hasLuckinMemoryEvidence(evidenceText);
    if (expectedTool === true &&
      summary.basePassedWithoutTransport === true &&
      summary.modelPassed === true &&
      summary.toolRequested &&
      summary.localToolRequest &&
      summary.toolOk &&
      summary.hasExpectedToolId &&
      summary.hasExpectedDiscoveredToolId &&
      summary.personaExpectedMemoryProof) {
      summary.ok = true;
    }
  }
  const expectedHits = expectedMarkers.filter((marker) => evidenceText.includes(marker));
  const expectedMisses = expectedMarkers.filter((marker) => !evidenceText.includes(marker));
  const calendarMarkersOk = !isCalendarQuery(query) || expectedMisses.length === 0;
  const composioCardMarkersOk = !isComposioCardQuery(query) || expectedMisses.length === 0;
  const forbiddenSocialHubLegacyHits = forbiddenSocialHubLegacyMarkers.filter((marker) => evidenceText.includes(marker));
  const isSocialHubCase = isSocialHubExpectedToolId(expectedToolId);
  const socialHubVisibleOutput = isSocialHubCase && hasVisibleSocialHubOutput(evidenceText, expectedToolId);
  const allowsSocialHubTruthfulState = socialHubVisibleOutput && hasTruthfulSocialHubState(evidenceText);
  const aggregateMediaVisibleOutput = expectedToolId === 'media.aggregate.search' && hasVisibleAggregateMediaOutput(evidenceText);
  const worldCupVisibleOutput = expectedToolId === 'worldcup.open' && evidenceText.includes('世界杯 Anything OS');
  const allowsExternalGmailWeb = isGmailWebQuery(query) && summary.gmailWebOpened === true;
  const allowsAggregateMailProviderFailure = expectedToolId === 'mail.search' &&
    !isQqMailQuery(query) &&
    /Gmail/.test(evidenceText) &&
    /QQ Mail/.test(evidenceText) &&
    /Outlook/.test(evidenceText);
  const allowsPartialTravelSourceFailure = expectedToolId === 'travel.search' &&
    summary.toolOk === true &&
    (evidenceText.includes('来源状态') || evidenceText.includes('飞常准')) &&
    (evidenceText.includes('耗时') || /\bG\d+\b/.test(evidenceText) || evidenceText.includes('高铁 · 12306'));
  const layoutBlockingHits = finalLayoutBlockingMarkers.filter((marker) => {
    if (allowsPartialTravelSourceFailure && marker === '查询失败') {
      return false;
    }
    if (allowsSocialHubTruthfulState && socialHubTruthfulBlockingMarkers.includes(marker)) {
      return false;
    }
    if (aggregateMediaVisibleOutput && aggregateMediaTruthfulBlockingMarkers.includes(marker)) {
      return false;
    }
    if (allowsAggregateMailProviderFailure && (/^(Gmail|QQ)/.test(marker) || marker === 'Operation timeout' || marker === '2300028')) {
      return false;
    }
    return evidenceText.includes(marker);
  });
  if (expectedToolId === 'gmail.mail.search' && hasTechnicalGmailArgsCard(evidenceText)) {
    layoutBlockingHits.push('gmail-technical-args-card');
  }
  if (expectedToolId === 'gmail.message.send') {
    for (const blockingPattern of forbiddenGmailSendSuccessPatterns) {
      if (blockingPattern.pattern.test(evidenceText)) {
        layoutBlockingHits.push(blockingPattern.name);
      }
    }
  }
  const providerLayoutFailed = retryableProviderLayoutMarkers.some((marker) => evidenceText.includes(marker));
  summary.providerFailed = summary.providerFailed || (providerLayoutFailed && !allowsSocialHubTruthfulState && !aggregateMediaVisibleOutput && !allowsAggregateMailProviderFailure);
  summary.layoutPath = join(outDir, `query-${index + 1}-final-layout.json`);
  summary.layoutTextPath = layoutTextPath;
  summary.layoutScrolledTextPath = scrollEvidence.combinedTextPath;
  summary.layoutScrolledRequiredMarkers = scrollEvidence.requiredMarkers;
  summary.layoutScrolledFoundMarkers = scrollEvidence.foundMarkers;
  summary.layoutScrollTextPaths = scrollEvidence.textPaths;
  summary.layoutScrollScreenPaths = scrollEvidence.screenPaths;
  const evidenceToolName = (expectedToolId.length > 0 ? expectedToolId : 'no-tool').replace(/[^a-z0-9]+/gi, '-').replace(/^-+|-+$/g, '');
  summary.screenPath = captureScreen(`query-${index + 1}-${evidenceToolName}-final-screen.png`);
  summary.layoutExpectedHits = expectedHits;
  summary.layoutExpectedMisses = expectedMisses;
  summary.socialHubVisibleOutput = socialHubVisibleOutput;
  summary.layoutForbiddenSocialHubLegacyHits = forbiddenSocialHubLegacyHits;
  summary.layoutBlockingHits = layoutBlockingHits;
  summary.gmailEccvKeywordVisible = !isGmailEccvQuery(query) || /eccv/i.test(evidenceText);
  const aggregateMediaMarkersOk = expectedToolId !== 'media.aggregate.search' || expectedMisses.length === 0;
  summary.layoutTextExposed = isSocialHubCase ?
    socialHubVisibleOutput :
    (worldCupVisibleOutput || expectedMarkers.length === 0 || expectedHits.length > 0) &&
    calendarMarkersOk &&
    composioCardMarkersOk &&
    aggregateMediaMarkersOk &&
    summary.gmailEccvKeywordVisible;
  if (expectedPersonaMemory === 'luckin_only') {
    summary.personaExpectedMemoryProof = hasLuckinMemoryEvidence(evidenceText);
    summary.layoutTextExposed = summary.layoutTextExposed && summary.personaExpectedMemoryProof;
  }
  summary.mailAggregateVisible = expectedToolId !== 'mail.search' ||
    (isMailAggregationQuery(query) ? (/Gmail/.test(evidenceText) && /QQ Mail/.test(evidenceText) && /Outlook/.test(evidenceText)) :
      (isQqMailQuery(query) ? /QQ Mail/.test(evidenceText) : (/Gmail/.test(evidenceText) && /QQ Mail/.test(evidenceText) && /Outlook/.test(evidenceText))));
  const expectsMailDraftAction = expectedToolId === 'gmail.mail.search' && isGmailEccvQuery(query);
  summary.mailExpandedActions = expectsMailDraftAction
    ? await verifyMailExpandedActions(evidenceLayout, index, appPid, isGmailEccvQuery(query) ? 'ECCV' : '')
    : {
      clicked: false,
      actionVisible: true,
      draftClicked: false,
      draftToolRequested: true,
      draftToolOk: true,
      draftVisible: true
    };
  summary.mailExpandedBody = expectedCase.verifyMailBody === true
    ? await verifyMailExpandedBody(evidenceLayout, index)
    : { ok: true, skipped: true };
  summary.socialDraftAction = expectedCase.verifySocialDraft === true
    ? await verifySocialDraftAction(evidenceLayout, index)
    : { ok: true, skipped: true };
  summary.calendarDeleteAction = expectedCase.verifyCalendarDelete === true
    ? await verifyCalendarDeleteAction(evidenceLayout, index, appPid)
    : { ok: true, skipped: true };
  summary.hotelDetailAction = expectedCase.verifyHotelDetail === true
    ? await verifyHotelDetailAction(evidenceLayout, index, appPid)
    : { ok: true, skipped: true };
  summary.expectedAbsentText = expectedCase.expectAbsentText || '';
  summary.absenceVerified = summary.expectedAbsentText.length === 0 ||
    !evidenceText.includes(summary.expectedAbsentText) ||
    /无结果|没有找到|不存在|0 条|0个/.test(evidenceText);
  if (isPersonaMemoryUpdateQuery(query)) {
    summary.mailAggregateVisible = true;
    summary.layoutTextExposed = summary.personaMemoryUpdateProof === true;
    summary.layoutOk = layoutBlockingHits.length === 0 &&
      forbiddenSocialHubLegacyHits.length === 0 &&
      summary.layoutTextExposed;
    summary.ok = summary.ok && summary.layoutOk &&
      summary.mailExpandedBody.ok &&
      summary.socialDraftAction.ok &&
      summary.calendarDeleteAction.ok &&
      summary.hotelDetailAction.ok &&
      summary.absenceVerified;
    return summary;
  }
  summary.modelFailed = summary.modelFailed || summary.mailExpandedActions.draftModelFailed === true;
  summary.providerFailed = summary.providerFailed || summary.mailExpandedActions.draftProviderFailed === true;
  if (expectsMailDraftAction) {
    summary.layoutTextExposed = summary.layoutTextExposed &&
      summary.mailAggregateVisible &&
      summary.mailExpandedActions.actionVisible &&
      summary.mailExpandedActions.draftClicked &&
      summary.mailExpandedActions.draftToolRequested &&
      summary.mailExpandedActions.draftToolOk &&
      summary.mailExpandedActions.draftVisible;
  } else {
    summary.layoutTextExposed = summary.layoutTextExposed && summary.mailAggregateVisible;
  }
  const allowsHtmlDocumentOnly = !isSocialHubCase && !expectsMailDraftAction && expectedToolId !== 'mail.search' &&
    expectedToolId !== 'media.aggregate.search' && summary.htmlHomeDocument.ok;
  summary.layoutOk = layoutBlockingHits.length === 0 &&
    forbiddenSocialHubLegacyHits.length === 0 &&
    (isSocialHubCase ? socialHubVisibleOutput : (allowsExternalGmailWeb || summary.layoutTextExposed || allowsHtmlDocumentOnly));
  const layoutEvidenceRecovered = expectedTool === true &&
    !summary.basePassedWithoutTransport &&
    summary.htmlHomeSurfaceLoad.ok &&
    !summary.htmlLoadError &&
    !summary.syntheticFallback &&
    summary.layoutOk;
  summary.layoutEvidenceRecovered = layoutEvidenceRecovered;
  if (isSocialHubCase) {
    const socialHubRecovered = socialHubVisibleOutput &&
      summary.htmlHomeSurfaceLoad.ok &&
      !summary.htmlLoadError &&
      !summary.syntheticFallback &&
      summary.layoutOk;
    if (socialHubRecovered) {
      summary.basePassedWithoutTransport = true;
    }
    summary.ok = summary.basePassedWithoutTransport === true &&
      summary.modelPassed === true &&
      summary.toolRequested &&
      summary.localToolRequest &&
      summary.toolOk &&
      summary.hasExpectedToolId &&
      summary.hasExpectedDiscoveredToolId &&
      (summary.transportPassed === true || allowsSocialHubTruthfulState) &&
      summary.layoutOk;
  } else if (expectedToolId === 'worldcup.open') {
    summary.ok = summary.basePassedWithoutTransport === true &&
      summary.modelPassed === true &&
      summary.toolRequested &&
      summary.toolOk &&
      summary.hasExpectedToolId &&
      summary.worldCupOpened === true &&
      worldCupVisibleOutput &&
      summary.layoutOk;
  } else if (layoutEvidenceRecovered) {
    summary.basePassedWithoutTransport = true;
    summary.ok = summary.modelPassed === true &&
      summary.transportPassed === true &&
      summary.toolRequested &&
      summary.localToolRequest &&
      summary.toolOk &&
      summary.hasExpectedToolId &&
      summary.hasExpectedDiscoveredToolId &&
      summary.personaCoffeeProof === true &&
      summary.layoutOk;
  } else {
    summary.ok = summary.ok && summary.layoutOk;
  }
  summary.ok = summary.ok &&
    summary.mailExpandedBody.ok &&
    summary.socialDraftAction.ok &&
    summary.calendarDeleteAction.ok &&
    summary.hotelDetailAction.ok &&
    summary.absenceVerified;
  return summary;
}

async function waitForComposioAuthEvidence() {
  const requiredMarkers = ['Composio 授权', '当前用户'];
  const authActionLabels = ['授权', '重新授权'];
  const authStatusLabels = [
    '待授权',
    '已连接',
    '异常',
    '已停用'
  ];
  const toolkitMarkers = [
    'GitHub',
    'Notion',
    'Google Drive',
    'Google Docs',
    'Slack',
    'OAuth',
    'Composio ·'
  ];
  let last = null;
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const layout = dumpLayout(`composio-auth-page-${attempt + 1}.json`);
    const layoutTextValues = collectLayoutText(layout);
    const text = layoutTextValues.join('\n');
    const textPath = join(outDir, `composio-auth-page-${attempt + 1}-text.txt`);
    writeFileSync(textPath, text + '\n');
    last = {
      layout,
      text,
      layoutPath: join(outDir, `composio-auth-page-${attempt + 1}.json`),
      textPath,
      markerHits: requiredMarkers.filter((marker) => text.includes(marker)),
      authActionHits: authActionLabels.filter((marker) => layoutTextValues.includes(marker)),
      authStatusHits: authStatusLabels.filter((marker) => layoutTextValues.includes(marker)),
      toolkitHits: toolkitMarkers.filter((marker) => text.includes(marker))
    };
    if (last.markerHits.length === requiredMarkers.length &&
      last.authActionHits.length > 0 &&
      last.authStatusHits.length > 0) {
      return last;
    }
    await sleep(1000);
  }
  return last;
}

async function runComposioAuthSmoke() {
  clearHilog();
  hdc(['shell', 'aa', 'force-stop', 'com.example.aiphonedemo']);
  if (cleanData) {
    cleanBundleData();
  }
  hdc(['shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.example.aiphonedemo']);
  await sleep(3000);
  moveAppWindowIntoScreenshot();

  const homeLayout = dumpLayout('composio-auth-home-layout.json');
  writeFileSync(join(outDir, 'composio-auth-home-layout-text.txt'), collectLayoutText(homeLayout).join('\n') + '\n');
  const settings = findHeaderSettingsCenter(homeLayout);
  if (settings === null) {
    throw new Error('Could not locate the home header settings button for Composio auth smoke.');
  }
  hdc(['shell', 'uitest', 'uiInput', 'click', String(settings.x), String(settings.y)]);
  await sleep(1200);

  const configLayout = dumpLayout('composio-auth-config-collapsed.json');
  const configText = collectLayoutText(configLayout).join('\n');
  writeFileSync(join(outDir, 'composio-auth-config-collapsed-text.txt'), configText + '\n');
  if (!configText.includes('Composio 授权')) {
    const expandAuth = findTextCenter(configLayout, '展开');
    if (expandAuth !== null) {
      hdc(['shell', 'uitest', 'uiInput', 'click', String(expandAuth.x), String(expandAuth.y)]);
      await sleep(800);
    }
  }

  const authButton = await findTextCenterWithScroll('Composio 授权', 'composio-auth-config-layout');
  if (authButton === null) {
    throw new Error('Could not locate the Config page Composio 授权 button.');
  }
  hdc(['shell', 'uitest', 'uiInput', 'click', String(authButton.x), String(authButton.y)]);

  const evidence = await waitForComposioAuthEvidence();
  if (evidence === null) {
    throw new Error('Could not capture Composio auth page layout evidence.');
  }
  const screenPath = captureScreen('composio-auth-page-screen.png');
  const summary = {
    mode: 'composio-auth',
    ok: evidence.markerHits.length === 2 && evidence.authActionHits.length > 0 && evidence.authStatusHits.length > 0,
    requiredMarkers: ['Composio 授权', '当前用户'],
    markerHits: evidence.markerHits,
    authActionHits: evidence.authActionHits,
    authStatusHits: evidence.authStatusHits,
    toolkitHits: evidence.toolkitHits,
    layoutPath: evidence.layoutPath,
    textPath: evidence.textPath,
    screenPath
  };
  writeFileSync(join(outDir, 'composio-auth-summary.json'), JSON.stringify(summary, null, 2));
  return summary;
}

console.log(`cleanData: ${cleanData ? 'true' : 'false'}`);

if (runComposioAuthCases) {
  const summary = await runComposioAuthSmoke();
  console.log(JSON.stringify(summary, null, 2));
  if (!summary.ok) {
    process.exit(1);
  }
  if (!runComposioCases && queryArgs.length === 0) {
    process.exit(0);
  }
}
const modelHealth = await ensureLocalModel();
console.log(`modelHealth: ${JSON.stringify(modelHealth, null, 2)}`);

const summaries = [];
let personaMemoryBackup = null;
let personaMemoryRestore = { ok: true, skipped: true };
if (useDefaultCases && selectedDefaultCases.some((testCase) => /^C11/.test(testCase.id || ''))) {
  try {
    personaMemoryBackup = backupPersonaMemoryStore();
    personaMemoryRestore = { ok: false, skipped: false, pending: true };
  } catch (error) {
    personaMemoryRestore = {
      ok: false,
      skipped: false,
      reason: error instanceof Error ? error.message : String(error)
    };
  }
}
try {
for (let index = 0; index < queries.length; index += 1) {
  const query = queries[index];
  console.log(`\n[${index + 1}/${queries.length}] ${query}`);
  const inferredCase = useDefaultCases ? selectedDefaultCases[index] : expectedCaseForQuery(query);
  if (/^C11/.test(inferredCase.id || '') && personaMemoryBackup === null) {
    const blockedSummary = {
      caseId: inferredCase.id || '',
      query,
      expectedTool: inferredCase.expectsTool,
      expectedToolId: inferredCase.expectedToolId || '',
      status: 'BLOCKED',
      ok: false,
      reason: `Persona memory could not be backed up safely: ${personaMemoryRestore.reason || 'unknown backup failure'}`
    };
    summaries.push(blockedSummary);
    console.log(JSON.stringify(blockedSummary, null, 2));
    continue;
  }
  if (inferredCase.blockedWithoutWhatsAppTestTo === true && whatsappTestTo.length === 0) {
    const blockedSummary = {
      caseId: inferredCase.id || '',
      query,
      expectedTool: inferredCase.expectsTool,
      expectedToolId: inferredCase.expectedToolId || '',
      status: 'BLOCKED',
      ok: false,
      reason: 'AIPHONE_WHATSAPP_TEST_TO is missing; no recipient was guessed and no message action was opened.'
    };
    summaries.push(blockedSummary);
    console.log(JSON.stringify(blockedSummary, null, 2));
    continue;
  }
  const expectedTool = inferredCase.expectsTool;
  let summary = null;
  for (let attempt = 0; attempt <= queryRetryLimit; attempt += 1) {
    summary = await runQuery(query, index, expectedTool);
    summary.attempt = attempt + 1;
    summary.retryLimit = queryRetryLimit;
    const missingScrolledMarkers = Array.isArray(summary.layoutScrolledRequiredMarkers) &&
      Array.isArray(summary.layoutScrolledFoundMarkers) &&
      summary.layoutScrolledRequiredMarkers.some((marker) => !summary.layoutScrolledFoundMarkers.includes(marker));
    const retryableFailure = summary.providerFailed || summary.modelFailed || missingScrolledMarkers;
    if (summary.ok || !retryableFailure || attempt === queryRetryLimit) {
      break;
    }
    console.warn(`retryable failure for query ${index + 1}, retrying attempt ${attempt + 2}/${queryRetryLimit + 1}`);
  }
  if (summary === null) {
    throw new Error(`No summary produced for query: ${query}`);
  }
  summary.status = summary.ok ? 'PASS' : (summary.providerFailed ? 'BLOCKED' : 'FAIL');
  summaries.push(summary);
  console.log(JSON.stringify(summary, null, 2));
  if (inferredCase.id === 'C11c' && personaMemoryBackup !== null) {
    personaMemoryRestore = restorePersonaMemoryStore(personaMemoryBackup);
    personaMemoryBackup = null;
  }
}
} finally {
  if (personaMemoryBackup !== null) {
    personaMemoryRestore = restorePersonaMemoryStore(personaMemoryBackup);
    personaMemoryBackup = null;
  }
}

const finalLayout = dumpLayout('final-layout.json');
const finalScreenPath = captureScreen('final-screen.png');
const finalLayoutTextValues = collectLayoutText(finalLayout);
const finalLayoutText = finalLayoutTextValues.join('\n');
const finalLayoutTextPath = join(outDir, 'final-layout-text.txt');
writeFileSync(finalLayoutTextPath, finalLayoutText + '\n');
const finalLayoutDomainHits = visibleDomainMarkers.filter((marker) => finalLayoutText.includes(marker));
const finalLayoutSyntheticHits = forbiddenSyntheticMarkers.filter((marker) => finalLayoutText.includes(marker));
const finalLayoutForbiddenActionHits = forbiddenLayoutActionMarkers.filter((marker) => finalLayoutText.includes(marker));
const finalQuery = queries.length > 0 ? queries[queries.length - 1] : '';
const finalAllowsPartialTravel = /出行方案|搜索出行|怎么去|比较出行|出行选项|整理可查|可查的出行/.test(finalQuery);
const finalSummary = summaries.length > 0 ? summaries[summaries.length - 1] : null;
const finalAllowsPersonaMemoryUpdate = finalSummary !== null && finalSummary.personaMemoryUpdateProof === true;
const finalAllowsExternalGmailWeb = isGmailWebQuery(finalQuery) &&
  finalSummary !== null &&
  finalSummary.gmailWebOpened === true;
const finalAllowsSocialHubTruthfulState =
  finalSummary !== null &&
  isSocialHubExpectedToolId(finalSummary.expectedToolId) &&
  hasVisibleSocialHubOutput(finalLayoutText, finalSummary.expectedToolId);
const finalAllowsAggregateMailProviderFailure =
  finalSummary !== null &&
  finalSummary.expectedToolId === 'mail.search' &&
  finalSummary.mailAggregateVisible === true;
const finalAggregateMediaVisibleOutput =
  finalSummary !== null &&
  finalSummary.expectedToolId === 'media.aggregate.search' &&
  hasVisibleAggregateMediaOutput(finalLayoutText);
const finalAllowsSourceFailure =
  finalAllowsPartialTravel &&
  finalSummary !== null &&
  finalSummary.expectedToolId === 'travel.search' &&
  finalSummary.toolOk === true &&
  (finalLayoutText.includes('来源状态') || finalLayoutText.includes('飞常准')) &&
  finalLayoutText.includes('耗时');
const finalLayoutBlockingHits = finalLayoutBlockingMarkers.filter((marker) => {
  if (finalAllowsPartialTravel && (marker === '需要供应商配置' || marker === '需要配置：')) {
    return false;
  }
  if (finalAllowsSourceFailure && marker === '查询失败') {
    return false;
  }
  if (finalAllowsSocialHubTruthfulState && socialHubTruthfulBlockingMarkers.includes(marker)) {
    return false;
  }
  if (finalAggregateMediaVisibleOutput && aggregateMediaTruthfulBlockingMarkers.includes(marker)) {
    return false;
  }
  if (finalAllowsAggregateMailProviderFailure && /^(Gmail|QQ)/.test(marker)) {
    return false;
  }
  return finalLayoutText.includes(marker);
});
if (finalSummary !== null && finalSummary.expectedToolId === 'gmail.mail.search' && hasTechnicalGmailArgsCard(finalLayoutText)) {
  finalLayoutBlockingHits.push('gmail-technical-args-card');
}
for (const blockingPattern of finalLayoutBlockingPatterns) {
  if (finalSummary !== null &&
    (finalSummary.expectedToolId.startsWith('calendar.') || finalSummary.expectedToolId.startsWith('hotel.'))) {
    continue;
  }
  if (finalSummary !== null &&
    finalSummary.expectedToolId === 'dynamic.search' &&
    finalSummary.expectedDiscoveredToolId === 'weather.query' &&
    finalLayoutText.includes('高德天气')) {
    continue;
  }
  if (blockingPattern.pattern.test(finalLayoutText)) {
    finalLayoutBlockingHits.push(blockingPattern.name);
  }
}
if (finalSummary !== null && finalSummary.expectedToolId === 'gmail.message.send') {
  for (const blockingPattern of forbiddenGmailSendSuccessPatterns) {
    if (blockingPattern.pattern.test(finalLayoutText)) {
      finalLayoutBlockingHits.push(blockingPattern.name);
    }
  }
}
const finalLayoutRouteHits = finalLayoutRouteMarkers.filter((marker) => finalLayoutText.includes(marker));
const hilogProcesses = activeHilogProcesses();
const visibleOutput = {
  layoutPath: join(outDir, 'final-layout.json'),
  screenPath: finalScreenPath,
  textPath: finalLayoutTextPath,
  domainHits: finalLayoutDomainHits,
  routeHits: finalLayoutRouteHits,
  syntheticHits: finalLayoutSyntheticHits,
  forbiddenActionHits: finalLayoutForbiddenActionHits,
  blockingHits: finalLayoutBlockingHits,
  ok: (finalAllowsSocialHubTruthfulState || finalAllowsExternalGmailWeb || finalAllowsPersonaMemoryUpdate || finalLayoutDomainHits.length > 0 ||
    (finalSummary !== null &&
      !isSocialHubExpectedToolId(finalSummary.expectedToolId) &&
      finalSummary.htmlHomeDocument !== undefined &&
      finalSummary.htmlHomeDocument.ok === true)) &&
    finalLayoutSyntheticHits.length === 0 &&
    finalLayoutForbiddenActionHits.length === 0 &&
    finalLayoutBlockingHits.length === 0
};
const processCleanup = {
  activeHilogProcesses: hilogProcesses,
  ok: hilogProcesses.length === 0
};

const summaryPath = join(outDir, 'summary.json');
writeFileSync(summaryPath, JSON.stringify({
  target,
  timeoutMs,
  cleanData,
  modelHealth,
  personaMemoryRestore,
  summaries,
  visibleOutput,
  processCleanup
}, null, 2));
console.log(`\nsummary: ${summaryPath}`);
console.log(`personaMemoryRestore: ${JSON.stringify(personaMemoryRestore, null, 2)}`);
console.log(`visibleOutput: ${JSON.stringify(visibleOutput, null, 2)}`);
console.log(`processCleanup: ${JSON.stringify(processCleanup, null, 2)}`);
const failed = summaries.filter((summary) => !summary.ok);
process.exitCode = failed.length === 0 && personaMemoryRestore.ok && visibleOutput.ok && processCleanup.ok ? 0 : 1;
