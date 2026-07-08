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
  isComposioDynamicPrompt,
  isUnsafeComposioExecute
} from '@loop/agent-core';
import { DynamicGenericToolResult } from '@loop/agent-core';

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
      const draftTool = {
        toolSlug: 'GMAIL_CREATE_DRAFT',
        inputSchema: '{"type":"object","properties":{"to":{"type":"array"},"subject":{"type":"string"},"body":{"type":"string"},"thread_id":{"type":"string"},"reply_mode":{"type":"string"}}}'
      } as Object;
      const draftArgs = composioArgumentsForTool(
        draftTool,
        '创建 Gmail 回复草稿',
        'gmail.draft.apply',
        {
          to: ['alice@example.com'],
          subject: 'Re: Demo',
          body: 'Got it.',
          threadId: 'thread-123',
          replyMode: 'reply'
        } as Object
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(JSON.stringify(draftArgs.to)).assertEqual('["alice@example.com"]');
      expect(draftArgs.subject).assertEqual('Re: Demo');
      expect(draftArgs.body).assertEqual('Got it.');
      expect(draftArgs.thread_id).assertEqual('thread-123');
      expect(draftArgs.reply_mode).assertEqual('reply');

      const threadTool = {
        toolSlug: 'GMAIL_GET_THREAD',
        inputSchema: '{"type":"object","properties":{"threadId":{"type":"string"}}}'
      } as Object;
      const threadArgs = composioArgumentsForTool(
        threadTool,
        '读取 Gmail 线程',
        'gmail.thread.read',
        { threadId: 'thread-999' } as Object
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(threadArgs.threadId).assertEqual('thread-999');
    });

    it('maps Calendar fixed-tool args into create and update schemas', 0, () => {
      const createTool = {
        toolSlug: 'GOOGLECALENDAR_CREATE_EVENT',
        inputSchema: '{"type":"object","properties":{"summary":{"type":"string"},"startDateTime":{"type":"string"},"endDateTime":{"type":"string"},"timeZone":{"type":"string"}}}'
      } as Object;
      const createArgs = composioArgumentsForTool(
        createTool,
        '创建日程',
        'calendar.event.create',
        {
          title: 'AIPhoneDemo',
          start: '2026-07-30T15:00:00+08:00',
          end: '2026-07-30T15:30:00+08:00',
          timezone: 'Asia/Shanghai'
        } as Object
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(createArgs.summary).assertEqual('AIPhoneDemo');
      expect(createArgs.startDateTime).assertEqual('2026-07-30T15:00:00+08:00');
      expect(createArgs.endDateTime).assertEqual('2026-07-30T15:30:00+08:00');
      expect(createArgs.timeZone).assertEqual('Asia/Shanghai');

      const updateTool = {
        toolSlug: 'GOOGLECALENDAR_UPDATE_EVENT',
        inputSchema: '{"type":"object","properties":{"event_id":{"type":"string"},"summary":{"type":"string"},"start":{"type":"string"},"end":{"type":"string"}}}'
      } as Object;
      const updateArgs = composioArgumentsForTool(
        updateTool,
        '更新日程',
        'calendar.event.update',
        {
          eventId: 'evt-1',
          title: 'AIPhoneDemo sync',
          start: '2026-07-30T16:00:00+08:00',
          end: '2026-07-30T16:30:00+08:00'
        } as Object
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(updateArgs.event_id).assertEqual('evt-1');
      expect(updateArgs.summary).assertEqual('AIPhoneDemo sync');
      expect(updateArgs.start).assertEqual('2026-07-30T16:00:00+08:00');
      expect(updateArgs.end).assertEqual('2026-07-30T16:30:00+08:00');
    });

    it('does not synthesize missing fixed write args from prompt text', 0, () => {
      const draftTool = {
        toolSlug: 'GMAIL_CREATE_DRAFT',
        inputSchema: '{"type":"object","required":["body"],"properties":{"body":{"type":"string"},"subject":{"type":"string"},"thread_id":{"type":"string"}}}'
      } as Object;
      const draftArgs = composioArgumentsForTool(
        draftTool,
        '帮我给 Alice 写 Gmail 草稿说我收到了',
        'gmail.draft.create',
        {
          subject: 'Re: Demo'
        } as Object
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(draftArgs.body === undefined).assertTrue();
      expect(draftArgs.subject).assertEqual('Re: Demo');
      expect(draftArgs.thread_id === undefined).assertTrue();

      const updateTool = {
        toolSlug: 'GOOGLECALENDAR_UPDATE_EVENT',
        inputSchema: '{"type":"object","required":["event_id","summary"],"properties":{"event_id":{"type":"string"},"summary":{"type":"string"},"start":{"type":"string"},"end":{"type":"string"}}}'
      } as Object;
      const updateArgs = composioArgumentsForTool(
        updateTool,
        '把刚才的日程改到下午四点',
        'calendar.event.update',
        {
          start: '2026-07-30T16:00:00+08:00'
        } as Object
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(updateArgs.event_id === undefined).assertTrue();
      expect(updateArgs.summary === undefined).assertTrue();
      expect(updateArgs.start).assertEqual('2026-07-30T16:00:00+08:00');
      expect(updateArgs.end === undefined).assertTrue();
    });

    it('returns fixed-tool missing-args errors before Composio auth/config checks', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        const draftResult = await callComposioDynamic(
          '帮我给 Alice 写 Gmail 草稿说我收到了',
          {
            fixedToolId: 'gmail.draft.apply',
            fixedArgs: {
              subject: 'Re: Demo'
            }
          } as Object
        ) as DynamicGenericToolResult;
        expect(draftResult.toolName).assertEqual('gmail.draft.apply');
        expect(draftResult.status).assertEqual('error');
        expect(draftResult.summary.indexOf('body')).assertLarger(-1);
        expect(JSON.stringify(draftResult.rows).indexOf('Missing')).assertLarger(-1);

        const calendarResult = await callComposioDynamic(
          '把刚才的日程改到下午四点',
          {
            fixedToolId: 'calendar.event.update',
            fixedArgs: {} as Object
          } as Object
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
      const calendarRead = { toolSlug: 'GOOGLECALENDAR_LIST_EVENTS', description: 'List events' } as Object;
      const calendarCreate = { toolSlug: 'GOOGLECALENDAR_CREATE_EVENT', description: 'Create event' } as Object;
      expect(composioPreferredToolScore('帮我看今天的 Google Calendar 日程', calendarRead, 'calendar.events.search'))
        .assertLarger(composioPreferredToolScore('帮我看今天的 Google Calendar 日程', calendarCreate, 'calendar.events.search'));

      const gmailRead = { toolSlug: 'GMAIL_GET_THREAD', description: 'Read Gmail thread' } as Object;
      const gmailDraft = { toolSlug: 'GMAIL_CREATE_DRAFT', description: 'Create Gmail draft' } as Object;
      expect(composioPreferredToolScore('帮我读取这封 Gmail 邮件', gmailRead, 'gmail.thread.read'))
        .assertLarger(composioPreferredToolScore('帮我读取这封 Gmail 邮件', gmailDraft, 'gmail.thread.read'));
    });

    it('prefers safe Gmail draft slugs over send or delete draft slugs', 0, () => {
      const createDraft = { toolSlug: 'GMAIL_CREATE_DRAFT', description: 'Create Gmail draft' } as Object;
      const sendDraft = { toolSlug: 'GMAIL_SEND_DRAFT', description: 'Send Gmail draft' } as Object;
      const deleteDraft = { toolSlug: 'GMAIL_DELETE_DRAFT', description: 'Delete Gmail draft' } as Object;

      expect(composioPreferredToolScore('创建 Gmail 回复草稿', createDraft, 'gmail.draft.create'))
        .assertLarger(composioPreferredToolScore('创建 Gmail 回复草稿', sendDraft, 'gmail.draft.create'));
      expect(composioPreferredToolScore('创建 Gmail 回复草稿', createDraft, 'gmail.draft.create'))
        .assertLarger(composioPreferredToolScore('创建 Gmail 回复草稿', deleteDraft, 'gmail.draft.create'));
      expect(composioPreferredToolScore('应用 Gmail 回复草稿', createDraft, 'gmail.draft.apply'))
        .assertLarger(composioPreferredToolScore('应用 Gmail 回复草稿', sendDraft, 'gmail.draft.apply'));
      expect(composioPreferredToolScore('应用 Gmail 回复草稿', createDraft, 'gmail.draft.apply'))
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
