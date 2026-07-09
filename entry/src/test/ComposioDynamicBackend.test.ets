import { describe, it, expect } from '@ohos/hypium';
import {
  callComposioDynamic,
  composioDynamicMissingConfigResult,
  composioArgumentsForTool,
  composioDynamicResultFromObservation,
  composioPreferredToolScore,
  configureComposioConfigFromRawJson,
  proxyToolkitAccountsPreview,
  shouldAttemptComposioDynamic,
  configureComposioUserId,
  currentComposioConfig,
  currentComposioUserId,
  ComposioSearchTool,
  isComposioDynamicPrompt,
  isUnsafeComposioExecute,
  slackSearchQueryForPrompt
} from '@loop/agent-core';
import { DynamicGenericToolResult } from '@loop/agent-core';

function looseObject(raw: string): Object {
  return JSON.parse(raw) as Object;
}

function composioTool(raw: string): ComposioSearchTool {
  return JSON.parse(raw) as ComposioSearchTool;
}

interface TestComposioHeader {
  name: string;
  value: string;
}

interface TestComposioMessagePayload {
  headers: TestComposioHeader[];
}

interface TestComposioMessage {
  threadId: string;
  messageId: string;
  sender: string;
  subject: string;
  messageText: string;
  payload: TestComposioMessagePayload;
}

interface TestComposioObservationData {
  messages: TestComposioMessage[];
}

interface TestComposioObservation {
  data: TestComposioObservationData;
  error: null;
}

export default function composioDynamicBackendTest() {
  describe('composioDynamicBackend', () => {
    it('recognizes unsupported high-frequency app queries', 0, () => {
      expect(isComposioDynamicPrompt('帮我在 Notion 里找一下 7 月旅行计划相关页面')).assertTrue();
      expect(isComposioDynamicPrompt('帮我在 Google Docs 里找 AIPhoneDemo 设计文档')).assertTrue();
      expect(isComposioDynamicPrompt('帮我查 Linear 里分配给我的高优先级 bug')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Composio Slack 查最近提到 AIPhoneDemo 的消息')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Outlook 查最近和 AIPhoneDemo 相关的邮件')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Composio Gmail 查最近重要邮件')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Composio Google Calendar 查本月日程')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Composio YouTube 查我的播放列表')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Composio X 查 openai 最近公开 post')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Composio Twitter 查我的私信')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Discord 查最近提到 AIPhoneDemo 的消息')).assertTrue();
      expect(isComposioDynamicPrompt('帮我在 LinkedIn 查 AIPhoneDemo 相关动态')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 WhatsApp 查最近提到 AIPhoneDemo 的消息')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Instgram 查 AIPhoneDemo 相关评论')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 soptify 搜适合 demo 的播放列表')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 TikTok 搜 AIPhoneDemo 相关短视频')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Ticketmaster 查深圳本周末演唱会')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Reddit 查 openai codex 讨论')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Weibo 查 openai codex 讨论')).assertFalse();
      expect(isComposioDynamicPrompt('帮我用 Composio Weibo 查 openai codex 讨论')).assertFalse();
      expect(isComposioDynamicPrompt('帮我用知乎查 openai codex 讨论')).assertFalse();
      expect(isComposioDynamicPrompt('帮我查最近重要邮件')).assertFalse();
    });

    it('maps missing config to a truthful result', 0, () => {
      const result: DynamicGenericToolResult = composioDynamicMissingConfigResult('帮我在 Notion 里找签证材料');

      expect(result.sourceTag).assertEqual('Composio');
      expect(result.toolName).assertEqual('dynamic.search');
      expect(result.status).assertEqual('needs_auth');
      expect(result.summary.indexOf('Composio 未配置')).assertLarger(-1);
      expect(result.rawPreview.indexOf('Notion')).assertLarger(-1);
    });

    it('allows Composio side-effect execute after session search selection', 0, () => {
      expect(isUnsafeComposioExecute('GMAIL_SEND_EMAIL', '{}')).assertFalse();
      expect(isUnsafeComposioExecute('NOTION_CREATE_PAGE', '{"title":"AIPhoneDemo"}')).assertFalse();
      expect(isUnsafeComposioExecute('GITHUB_FIND_PULL_REQUESTS', '{"sort":"updated"}')).assertFalse();
    });

    it('maps Gmail fixed-tool args into the matched Composio schema', 0, () => {
      const draftTool = composioTool('{"toolSlug":"GMAIL_CREATE_DRAFT","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"to\\":{\\"type\\":\\"array\\"},\\"subject\\":{\\"type\\":\\"string\\"},\\"body\\":{\\"type\\":\\"string\\"},\\"thread_id\\":{\\"type\\":\\"string\\"},\\"reply_mode\\":{\\"type\\":\\"string\\"}}}"}');
      const draftArgs = composioArgumentsForTool(
        draftTool,
        '创建 Gmail 回复草稿',
        'gmail.draft.apply',
        looseObject('{"to":["alice@example.com"],"subject":"Re: Demo","body":"Got it.","threadId":"thread-123","replyMode":"reply"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(JSON.stringify(draftArgs.to)).assertEqual('["alice@example.com"]');
      expect(draftArgs.subject).assertEqual('Re: Demo');
      expect(draftArgs.body).assertEqual('Got it.');
      expect(draftArgs.thread_id).assertEqual('thread-123');
      expect(draftArgs.reply_mode).assertEqual('reply');

      const threadTool = composioTool('{"toolSlug":"GMAIL_GET_THREAD","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"threadId\\":{\\"type\\":\\"string\\"}}}"}');
      const threadArgs = composioArgumentsForTool(
        threadTool,
        '读取 Gmail 线程',
        'gmail.thread.read',
        looseObject('{"threadId":"thread-999"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(threadArgs.threadId).assertEqual('thread-999');

      const searchTool = composioTool('{"toolSlug":"GMAIL_FETCH_EMAILS","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"query\\":{\\"type\\":\\"string\\"},\\"max_results\\":{\\"type\\":\\"number\\"},\\"include_payload\\":{\\"type\\":\\"boolean\\"},\\"verbose\\":{\\"type\\":\\"boolean\\"}}}"}');
      const searchArgs = composioArgumentsForTool(
        searchTool,
        '帮我查看我Gmail里和我eccv论文相关的邮件',
        'gmail.mail.search',
        looseObject('{"query":"ECCV OR paper OR manuscript OR submission OR review"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(searchArgs.query).assertEqual('ECCV OR paper OR manuscript OR submission OR review');
      expect(searchArgs.max_results).assertEqual(5);
      expect(searchArgs.include_payload).assertFalse();
      expect(searchArgs.verbose).assertTrue();
    });

    it('maps Calendar fixed-tool args into create and update schemas', 0, () => {
      const createTool = composioTool('{"toolSlug":"GOOGLECALENDAR_CREATE_EVENT","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"summary\\":{\\"type\\":\\"string\\"},\\"startDateTime\\":{\\"type\\":\\"string\\"},\\"endDateTime\\":{\\"type\\":\\"string\\"},\\"timeZone\\":{\\"type\\":\\"string\\"}}}"}');
      const createArgs = composioArgumentsForTool(
        createTool,
        '创建日程',
        'calendar.event.create',
        looseObject('{"title":"AIPhoneDemo","start":"2026-07-30T15:00:00+08:00","end":"2026-07-30T15:30:00+08:00","timezone":"Asia/Shanghai"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(createArgs.summary).assertEqual('AIPhoneDemo');
      expect(createArgs.startDateTime).assertEqual('2026-07-30T15:00:00+08:00');
      expect(createArgs.endDateTime).assertEqual('2026-07-30T15:30:00+08:00');
      expect(createArgs.timeZone).assertEqual('Asia/Shanghai');

      const updateTool = composioTool('{"toolSlug":"GOOGLECALENDAR_UPDATE_EVENT","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"event_id\\":{\\"type\\":\\"string\\"},\\"summary\\":{\\"type\\":\\"string\\"},\\"start\\":{\\"type\\":\\"string\\"},\\"end\\":{\\"type\\":\\"string\\"}}}"}');
      const updateArgs = composioArgumentsForTool(
        updateTool,
        '更新日程',
        'calendar.event.update',
        looseObject('{"eventId":"evt-1","title":"AIPhoneDemo sync","start":"2026-07-30T16:00:00+08:00","end":"2026-07-30T16:30:00+08:00"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(updateArgs.event_id).assertEqual('evt-1');
      expect(updateArgs.summary).assertEqual('AIPhoneDemo sync');
      expect(updateArgs.start).assertEqual('2026-07-30T16:00:00+08:00');
      expect(updateArgs.end).assertEqual('2026-07-30T16:30:00+08:00');
    });

    it('uses a bounded Slack query for default recent-message SocialHub prompts', 0, () => {
      const searchTool = composioTool('{"toolSlug":"SLACK_SEARCH_MESSAGES","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"query\\":{\\"type\\":\\"string\\"},\\"sort\\":{\\"type\\":\\"string\\"},\\"count\\":{\\"type\\":\\"number\\"}}}"}');
      const args = composioArgumentsForTool(
        searchTool,
        '帮我用 Composio Slack 查最近30天所有已授权应用收到的私信消息',
        '',
        null
      ) as Record<string, Object | string | number | boolean | null | undefined>;

      expect(slackSearchQueryForPrompt('帮我用 Composio Slack 查最近提到 AIPhoneDemo 的消息')).assertEqual('AIPhoneDemo');
      expect((args.query as string).indexOf('after:')).assertEqual(0);
      expect(args.sort).assertEqual('timestamp');
      expect(args.count).assertEqual(5);
    });

    it('keeps Composio Gmail execute previews compact and parseable', 0, () => {
      const headers: TestComposioHeader[] = [{ name: 'X-Large', value: 'x'.repeat(20000) }];
      const messages: TestComposioMessage[] = [{
        threadId: 'thread-1',
        messageId: 'message-1',
        sender: 'OpenReview <noreply@openreview.net>',
        subject: '[ECCV 2026] Paper Decision Notification',
        messageText: 'ECCV decision '.repeat(2000),
        payload: { headers: headers }
      }];
      const payload: TestComposioObservation = {
        data: {
          messages: messages
        },
        error: null
      };
      const observation = JSON.stringify(payload);
      const result = composioDynamicResultFromObservation('execute', observation, 'GMAIL_FETCH_EMAILS', 'Gmail ECCV');
      const preview = JSON.parse(result.rawPreview) as Record<string, Object[]>;

      expect(result.status).assertEqual('success');
      expect(preview.messages.length).assertEqual(1);
      expect(JSON.stringify(preview).indexOf('[ECCV 2026]')).assertLarger(-1);
      expect(result.rawPreview.length).assertLess(16000);
    });

    it('does not synthesize missing fixed write args from prompt text', 0, () => {
      const draftTool = composioTool('{"toolSlug":"GMAIL_CREATE_DRAFT","inputSchema":"{\\"type\\":\\"object\\",\\"required\\":[\\"body\\"],\\"properties\\":{\\"body\\":{\\"type\\":\\"string\\"},\\"subject\\":{\\"type\\":\\"string\\"},\\"thread_id\\":{\\"type\\":\\"string\\"}}}"}');
      const draftArgs = composioArgumentsForTool(
        draftTool,
        '帮我给 Alice 写 Gmail 草稿说我收到了',
        'gmail.draft.create',
        looseObject('{"subject":"Re: Demo"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(draftArgs.body === undefined).assertTrue();
      expect(draftArgs.subject).assertEqual('Re: Demo');
      expect(draftArgs.thread_id === undefined).assertTrue();

      const updateTool = composioTool('{"toolSlug":"GOOGLECALENDAR_UPDATE_EVENT","inputSchema":"{\\"type\\":\\"object\\",\\"required\\":[\\"event_id\\",\\"summary\\"],\\"properties\\":{\\"event_id\\":{\\"type\\":\\"string\\"},\\"summary\\":{\\"type\\":\\"string\\"},\\"start\\":{\\"type\\":\\"string\\"},\\"end\\":{\\"type\\":\\"string\\"}}}"}');
      const updateArgs = composioArgumentsForTool(
        updateTool,
        '把刚才的日程改到下午四点',
        'calendar.event.update',
        looseObject('{"start":"2026-07-30T16:00:00+08:00"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(updateArgs.event_id === undefined).assertTrue();
      expect(updateArgs.summary === undefined).assertTrue();
      expect(updateArgs.start).assertEqual('2026-07-30T16:00:00+08:00');
      expect(updateArgs.end === undefined).assertTrue();
    });

    it('returns fixed-tool missing-args errors before Composio auth/config checks', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        const createResult = await callComposioDynamic(
          '帮我给 Alice 写 Gmail 草稿说我收到了',
          looseObject('{"fixedToolId":"gmail.draft.create","fixedArgs":{"body":"Got it."}}')
        ) as DynamicGenericToolResult;
        expect(createResult.toolName).assertEqual('gmail.draft.create');
        expect(createResult.status).assertEqual('error');
        expect(createResult.summary.indexOf('to')).assertLarger(-1);
        expect(createResult.summary.indexOf('Composio 未配置')).assertEqual(-1);
        expect(JSON.stringify(createResult.rows).indexOf('gmail.draft.create')).assertLarger(-1);

        const emptyRecipientResult = await callComposioDynamic(
          '帮我给 Alice 写 Gmail 草稿说我收到了',
          looseObject('{"fixedToolId":"gmail.draft.create","fixedArgs":{"to":[""],"body":"Got it."}}')
        ) as DynamicGenericToolResult;
        expect(emptyRecipientResult.toolName).assertEqual('gmail.draft.create');
        expect(emptyRecipientResult.status).assertEqual('error');
        expect(emptyRecipientResult.summary.indexOf('to')).assertLarger(-1);
        expect(emptyRecipientResult.summary.indexOf('Composio 未配置')).assertEqual(-1);
        expect(JSON.stringify(emptyRecipientResult.rows).indexOf('gmail.draft.create')).assertLarger(-1);

        const blankRecipientResult = await callComposioDynamic(
          '确认应用刚才的 Gmail 草稿',
          looseObject('{"fixedToolId":"gmail.draft.apply","fixedArgs":{"threadId":"thread-123","to":["   "],"subject":"Re: Demo","replyMode":"reply","body":"Got it."}}')
        ) as DynamicGenericToolResult;
        expect(blankRecipientResult.toolName).assertEqual('gmail.draft.apply');
        expect(blankRecipientResult.status).assertEqual('error');
        expect(blankRecipientResult.summary.indexOf('to')).assertLarger(-1);
        expect(blankRecipientResult.summary.indexOf('Composio 未配置')).assertEqual(-1);
        expect(JSON.stringify(blankRecipientResult.rows).indexOf('gmail.draft.apply')).assertLarger(-1);

        const draftResult = await callComposioDynamic(
          '帮我给 Alice 写 Gmail 草稿说我收到了',
          looseObject('{"fixedToolId":"gmail.draft.apply","fixedArgs":{"threadId":"thread-123","to":["alice@example.com"],"subject":"Re: Demo","body":"Got it."}}')
        ) as DynamicGenericToolResult;
        expect(draftResult.toolName).assertEqual('gmail.draft.apply');
        expect(draftResult.status).assertEqual('error');
        expect(draftResult.summary.indexOf('replyMode')).assertLarger(-1);
        expect(draftResult.summary.indexOf('Composio 未配置')).assertEqual(-1);
        expect(JSON.stringify(draftResult.rows).indexOf('Missing')).assertLarger(-1);

        const calendarResult = await callComposioDynamic(
          '把刚才的日程改到下午四点',
          looseObject('{"fixedToolId":"calendar.event.update","fixedArgs":{}}')
        ) as DynamicGenericToolResult;
        expect(calendarResult.toolName).assertEqual('calendar.event.update');
        expect(calendarResult.status).assertEqual('error');
        expect(calendarResult.summary.indexOf('eventId')).assertLarger(-1);
        expect(calendarResult.summary.indexOf('title/start/end')).assertLarger(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
      }
    });

    it('keeps read/search fixed tools below side-effect Composio matches', 0, () => {
      const calendarRead = composioTool('{"toolSlug":"GOOGLECALENDAR_LIST_EVENTS","description":"List events"}');
      const calendarCreate = composioTool('{"toolSlug":"GOOGLECALENDAR_CREATE_EVENT","description":"Create event"}');
      expect(composioPreferredToolScore('帮我看今天的 Google Calendar 日程', calendarRead, 'calendar.events.search'))
        .assertLarger(composioPreferredToolScore('帮我看今天的 Google Calendar 日程', calendarCreate, 'calendar.events.search'));

      const gmailRead = composioTool('{"toolSlug":"GMAIL_GET_THREAD","description":"Read Gmail thread"}');
      const gmailDraft = composioTool('{"toolSlug":"GMAIL_CREATE_DRAFT","description":"Create Gmail draft"}');
      const gmailEmails = composioTool('{"toolSlug":"GMAIL_FETCH_EMAILS","description":"Fetch Gmail emails"}');
      const gmailThreads = composioTool('{"toolSlug":"GMAIL_LIST_THREADS","description":"List Gmail threads"}');
      const gmailPeople = composioTool('{"toolSlug":"GMAIL_SEARCH_PEOPLE","description":"Search Gmail people and contacts"}');
      expect(composioPreferredToolScore('帮我读取这封 Gmail 邮件', gmailRead, 'gmail.thread.read'))
        .assertLarger(composioPreferredToolScore('帮我读取这封 Gmail 邮件', gmailDraft, 'gmail.thread.read'));
      expect(composioPreferredToolScore('帮我查看我Gmail里和我eccv论文相关的邮件', gmailEmails, 'gmail.mail.search'))
        .assertLarger(composioPreferredToolScore('帮我查看我Gmail里和我eccv论文相关的邮件', gmailThreads, 'gmail.mail.search'));
      expect(composioPreferredToolScore('帮我查看我Gmail里和我eccv论文相关的邮件', gmailEmails, 'gmail.mail.search'))
        .assertLarger(composioPreferredToolScore('帮我查看我Gmail里和我eccv论文相关的邮件', gmailPeople, 'gmail.mail.search'));

      const playlistList = composioTool('{"toolSlug":"YOUTUBE_LIST_USER_PLAYLISTS","description":"List user playlists"}');
      const playlistItems = composioTool('{"toolSlug":"YOUTUBE_LIST_PLAYLIST_ITEMS","description":"List playlist items"}');
      expect(composioPreferredToolScore('帮我查看我的 YouTube 播放列表', playlistList, 'youtube.mine.playlists'))
        .assertLarger(composioPreferredToolScore('帮我查看我的 YouTube 播放列表', playlistItems, 'youtube.mine.playlists'));
    });

    it('prefers safe Gmail draft slugs over send or delete draft slugs', 0, () => {
      const createDraft = composioTool('{"toolSlug":"GMAIL_CREATE_DRAFT","description":"Create Gmail draft"}');
      const updateDraft = composioTool('{"toolSlug":"GMAIL_UPDATE_DRAFT","description":"Update Gmail draft"}');
      const editDraft = composioTool('{"toolSlug":"GMAIL_EDIT_DRAFT","description":"Edit Gmail draft"}');
      const applyDraft = composioTool('{"toolSlug":"GMAIL_APPLY_DRAFT","description":"Apply Gmail draft"}');
      const sendDraft = composioTool('{"toolSlug":"GMAIL_SEND_DRAFT","description":"Send Gmail draft"}');
      const deleteDraft = composioTool('{"toolSlug":"GMAIL_DELETE_DRAFT","description":"Delete Gmail draft"}');

      expect(composioPreferredToolScore('创建 Gmail 回复草稿', createDraft, 'gmail.draft.create'))
        .assertLarger(composioPreferredToolScore('创建 Gmail 回复草稿', sendDraft, 'gmail.draft.create'));
      expect(composioPreferredToolScore('创建 Gmail 回复草稿', createDraft, 'gmail.draft.create'))
        .assertLarger(composioPreferredToolScore('创建 Gmail 回复草稿', deleteDraft, 'gmail.draft.create'));
      expect(composioPreferredToolScore('创建 Gmail 回复草稿', createDraft, 'gmail.draft.create'))
        .assertLarger(composioPreferredToolScore('创建 Gmail 回复草稿', updateDraft, 'gmail.draft.create'));
      expect(composioPreferredToolScore('创建 Gmail 回复草稿', createDraft, 'gmail.draft.create'))
        .assertLarger(composioPreferredToolScore('创建 Gmail 回复草稿', editDraft, 'gmail.draft.create'));
      expect(composioPreferredToolScore('创建 Gmail 回复草稿', createDraft, 'gmail.draft.create'))
        .assertLarger(composioPreferredToolScore('创建 Gmail 回复草稿', applyDraft, 'gmail.draft.create'));
      expect(composioPreferredToolScore('应用 Gmail 回复草稿', createDraft, 'gmail.draft.apply'))
        .assertLarger(composioPreferredToolScore('应用 Gmail 回复草稿', sendDraft, 'gmail.draft.apply'));
      expect(composioPreferredToolScore('应用 Gmail 回复草稿', createDraft, 'gmail.draft.apply'))
        .assertLarger(composioPreferredToolScore('应用 Gmail 回复草稿', deleteDraft, 'gmail.draft.apply'));
      expect(composioPreferredToolScore('应用 Gmail 回复草稿', updateDraft, 'gmail.draft.apply'))
        .assertLarger(composioPreferredToolScore('应用 Gmail 回复草稿', sendDraft, 'gmail.draft.apply'));
      expect(composioPreferredToolScore('应用 Gmail 回复草稿', editDraft, 'gmail.draft.apply'))
        .assertLarger(composioPreferredToolScore('应用 Gmail 回复草稿', deleteDraft, 'gmail.draft.apply'));
    });

    it('keeps configured app user id for Composio dynamic calls', 0, () => {
      configureComposioUserId('aiphone-user-device-1');
      expect(currentComposioUserId()).assertEqual('aiphone-user-device-1');
    });

    it('uses raw Composio config without forcing a proxy', 0, () => {
      configureComposioConfigFromRawJson('{"apiKey":"ak_test","baseUrl":"https://backend.composio.dev/api/v3.1","userId":"aiphone-luoyige"}');
      configureComposioUserId('');

      expect(currentComposioUserId()).assertEqual('aiphone-luoyige');
      expect(currentComposioConfig().apiKey).assertEqual('ak_test');
      expect(currentComposioConfig().proxyBaseUrl).assertEqual('');
    });

    it('keeps generic dynamic.search fallback eligible once Composio is configured', 0, () => {
      expect(isComposioDynamicPrompt('帮我查最近重要邮件')).assertFalse();
      expect(shouldAttemptComposioDynamic('帮我查最近重要邮件', '', false)).assertFalse();
      expect(shouldAttemptComposioDynamic('帮我查最近重要邮件', '', true)).assertFalse();
      expect(shouldAttemptComposioDynamic('随便什么都行', 'execute', false)).assertFalse();
      expect(shouldAttemptComposioDynamic('帮我在 GitHub 里找 Appless-Phone 最近的 pr', 'execute', false)).assertTrue();
    });

    it('maps proxy auth configs to executable toolkit accounts only', 0, () => {
      const payload = JSON.parse('{"ok":true,"userId":"app-user-1","items":[{"authConfigId":"ac_1","toolkitSlug":"github","status":"connected","connectedAccountId":"ca_1","canExecute":true},{"authConfigId":"ac_2","toolkitSlug":"slack","status":"connected","connectedAccountId":"ca_2","canExecute":false},{"authConfigId":"ac_3","toolkitSlug":"notion","status":"needs_auth","connectedAccountId":"ca_3","canExecute":true},{"authConfigId":"ac_4","toolkitSlug":"discord","status":"connected","canExecute":true}]}') as Object;
      const accounts: Record<string, string> = proxyToolkitAccountsPreview(payload, ['github', 'slack', 'notion', 'discord']);

      expect(accounts['github']).assertEqual('ca_1');
      expect(Object.keys(accounts).length).assertEqual(1);
    });

    it('maps a Composio search observation to a generic result', 0, () => {
      const observation = '{"source":"Composio","authorizedToolkits":["notion"],"tools":[{"toolSlug":"NOTION_SEARCH","description":"Search pages","inputSchema":"{}"}],"instruction":"Choose one returned toolSlug"}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation('search', observation);

      expect(result.sourceTag).assertEqual('Composio');
      expect(result.toolName).assertEqual('dynamic.search');
      expect(result.status).assertEqual('success');
      expect(result.summary.indexOf('NOTION_SEARCH')).assertLarger(-1);
      expect(result.rawPreview.indexOf('authorizedToolkits')).assertLarger(-1);
    });

    it('maps a Composio execute observation to display rows', 0, () => {
      const observation = '{"data":{"pull_requests":[{"number":39,"title":"Add Composio dynamic backend","state":"merged","html_url":"https://github.com/XiaoLuoLYG/Appless-Phone/pull/39","author":{"login":"XiaoLuoLYG"},"updated_at":"2026-07-06T09:00:00Z"}]}}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        observation,
        'GITHUB_FIND_PULL_REQUESTS',
        '帮我在 GitHub 里找 Appless-Phone 最近的 pr'
      );

      expect(result.sourceTag).assertEqual('Composio');
      expect(result.toolName).assertEqual('GITHUB_FIND_PULL_REQUESTS');
      expect(result.title).assertEqual('Composio GitHub 结果');
      expect(result.summary.indexOf('返回 1 条')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('Add Composio dynamic backend')).assertLarger(-1);
    });

    it('treats Gmail draft payloads with draft ids as successful execute results', 0, () => {
      const observation = '{"data":{"display_url":"https://mail.google.com/mail/u/0/#drafts/r-1","id":"draft-1","threadId":"thread-1"},"error":{"display_url":"https://mail.google.com/mail/u/0/#drafts/r-1","id":"draft-1","threadId":"thread-1"}}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        observation,
        'GMAIL_CREATE_EMAIL_DRAFT',
        '创建 Gmail 回复草稿'
      );

      expect(result.status).assertEqual('success');
      expect(result.summary.indexOf('GMAIL_CREATE_EMAIL_DRAFT')).assertLarger(-1);
      expect(result.rawPreview.indexOf('mail.google.com')).assertLarger(-1);
    });

    it('maps Google Docs file payload to display rows', 0, () => {
      const observation = '{"data":{"files":[{"id":"doc_1","name":"AIPhoneDemo 设计文档","modifiedTime":"2026-07-06T12:41:26.011Z","webViewLink":"https://docs.google.com/document/d/doc_1/edit"}]}}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        observation,
        'GOOGLEDOCS_SEARCH_DOCUMENTS',
        '帮我在 Google Docs 里找 AIPhoneDemo 设计文档'
      );

      expect(result.status).assertEqual('success');
      expect(result.summary.indexOf('返回 1 条')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('AIPhoneDemo 设计文档')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('docs.google.com')).assertLarger(-1);
    });

    it('maps new Composio app payloads to app-specific result cards', 0, () => {
      const outlookObservation = '{"data":{"messages":[{"subject":"AIPhoneDemo follow-up","from":{"name":"Product Team"},"receivedDateTime":"2026-07-07T08:30:00Z","webLink":"https://outlook.office.com/mail/id/1"}]}}';
      const outlookResult: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        outlookObservation,
        'OUTLOOK_SEARCH_MESSAGES',
        '帮我用 Outlook 查最近和 AIPhoneDemo 相关的邮件'
      );

      expect(outlookResult.title).assertEqual('Composio Outlook 结果');
      expect(outlookResult.summary.indexOf('返回 1 条')).assertLarger(-1);
      expect(JSON.stringify(outlookResult.rows).indexOf('AIPhoneDemo follow-up')).assertLarger(-1);

      const ticketmasterObservation = '{"data":{"events":[{"name":"Shenzhen Live","status":"onsale","start_time":"2026-07-11T20:00:00+08:00","venue":{"name":"Shenzhen Bay Sports Center"},"url":"https://www.ticketmaster.com/event/1"}]}}';
      const ticketmasterResult: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        ticketmasterObservation,
        'TICKETMASTER_SEARCH_EVENTS',
        '帮我用 Ticketmaster 查深圳本周末的演唱会'
      );

      expect(ticketmasterResult.title).assertEqual('Composio Ticketmaster 结果');
      expect(ticketmasterResult.summary.indexOf('返回 1 条')).assertLarger(-1);
      expect(JSON.stringify(ticketmasterResult.rows).indexOf('Shenzhen Live')).assertLarger(-1);
    });

    it('recognizes Hacker News search prompts and maps execute rows', 0, () => {
      expect(isComposioDynamicPrompt('帮我用 Composio Hacker News 搜 openai codex 的帖子')).assertTrue();
      expect(shouldAttemptComposioDynamic('帮我用 Composio Hacker News 搜 openai codex 的帖子', 'execute', false)).assertTrue();

      const observation = '{"data":{"hits":[{"title":"OpenAI Codex discussion","author":"pg","points":128,"num_comments":42,"url":"https://news.ycombinator.com/item?id=123","created_at":"2026-07-09T01:00:00Z"}]}}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        observation,
        'HACKERNEWS_SEARCH_POSTS',
        '帮我用 Composio Hacker News 搜 openai codex 的帖子'
      );

      expect(result.title).assertEqual('Composio Hacker News 结果');
      expect(result.status).assertEqual('success');
      expect(result.summary.indexOf('返回 1 条')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('OpenAI Codex discussion')).assertLarger(-1);
    });

    it('recognizes Reddit search prompts and maps execute rows', 0, () => {
      expect(isComposioDynamicPrompt('帮我用 Reddit 查 openai codex 讨论')).assertTrue();
      expect(shouldAttemptComposioDynamic('帮我用 Reddit 查 openai codex 讨论', 'execute', false)).assertTrue();

      const observation = '{"data":{"children":[{"data":{"title":"OpenAI Codex on Reddit","author":"dev_user","ups":88,"num_comments":12,"permalink":"/r/OpenAI/comments/1/codex","selftext":"Long discussion"}}]}}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        observation,
        'REDDIT_SEARCH_POSTS',
        '帮我用 Reddit 查 openai codex 讨论'
      );

      expect(result.title).assertEqual('Composio Reddit 结果');
      expect(result.status).assertEqual('success');
      expect(result.summary.indexOf('返回 1 条')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('OpenAI Codex on Reddit')).assertLarger(-1);
    });

    it('keeps john on the GitHub path instead of Hacker News', 0, () => {
      const prompt = '帮我用 Composio GitHub 查 john 的 PR';

      expect(isComposioDynamicPrompt(prompt)).assertTrue();
      expect(shouldAttemptComposioDynamic(prompt, 'execute', false)).assertTrue();

      const observation = '{"source":"Composio","authorizedToolkits":["github"],"tools":[{"toolSlug":"GITHUB_FIND_PULL_REQUESTS","description":"Search GitHub pull requests","inputSchema":"{}"}]}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation('search', observation, '', prompt);

      expect(result.title).assertEqual('Composio GitHub 结果');
      expect(JSON.stringify(result.rows).indexOf('GITHUB_FIND_PULL_REQUESTS')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('Hacker News')).assertEqual(-1);
    });

    it('keeps target app identity when Composio has no authorized matching tool', 0, () => {
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'search',
        'Composio 没有在已授权 Toolkit 中找到匹配工具。',
        '',
        '帮我用 Discord 查最近提到 AIPhoneDemo 的消息'
      );

      expect(result.title).assertEqual('Composio Discord 结果');
      expect(result.status).assertEqual('error');
      expect(JSON.stringify(result.rows).indexOf('AIPhoneDemo')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('没有在已授权 Toolkit')).assertLarger(-1);
    });

    it('does not treat Composio execute errors as successful results', 0, () => {
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        '{"data":null,"error":"Invalid request data provided","log_id":"log_1"}',
        'GOOGLEDOCS_SEARCH_DOCUMENTS',
        '帮我在 Google Docs 里找 AIPhoneDemo 设计文档'
      );

      expect(result.status).assertEqual('error');
      expect(result.summary.indexOf('Invalid request data provided')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('Invalid request data provided')).assertLarger(-1);
    });
  });
}
