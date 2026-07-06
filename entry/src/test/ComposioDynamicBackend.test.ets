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
      expect(isComposioDynamicPrompt('帮我查 Linear 里分配给我的高优先级 bug')).assertTrue();
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
  });
}
