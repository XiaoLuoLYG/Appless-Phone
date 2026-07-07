import { describe, it, expect } from '@ohos/hypium';
import {
  composioDynamicMissingConfigResult,
  composioDynamicResultFromObservation,
  proxyToolkitAccountsPreview,
  shouldAttemptComposioDynamic,
  configureComposioUserId,
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

    it('keeps configured app user id for Composio dynamic calls', 0, () => {
      configureComposioUserId('aiphone-user-device-1');
      expect(currentComposioUserId()).assertEqual('aiphone-user-device-1');
    });

    it('keeps generic dynamic.search fallback eligible once Composio is configured', 0, () => {
      expect(isComposioDynamicPrompt('帮我查最近重要邮件')).assertFalse();
      expect(shouldAttemptComposioDynamic('帮我查最近重要邮件', '', false)).assertFalse();
      expect(shouldAttemptComposioDynamic('帮我查最近重要邮件', '', true)).assertTrue();
      expect(shouldAttemptComposioDynamic('随便什么都行', 'execute', false)).assertTrue();
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
