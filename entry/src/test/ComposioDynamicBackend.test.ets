import { describe, it, expect } from '@ohos/hypium';
import {
  composioDynamicMissingConfigResult,
  composioDynamicResultFromObservation,
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

    it('blocks likely side-effect execute requests', 0, () => {
      expect(isUnsafeComposioExecute('GMAIL_SEND_EMAIL', '{}')).assertTrue();
      expect(isUnsafeComposioExecute('NOTION_SEARCH', '{"query":"visa"}')).assertFalse();
      expect(isUnsafeComposioExecute('GITHUB_FIND_PULL_REQUESTS', '{"sort":"updated"}')).assertFalse();
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
