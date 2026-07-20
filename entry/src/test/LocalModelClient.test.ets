import { describe, it, expect } from '@ohos/hypium';
import { buildChatCompletionsUrl, resolveSystemPrompt } from '../main/ets/model/LocalModelClient';
import { configureLocalModelSettingsFromRawJson, defaultLocalModelSettings } from '@loop/agent-core';

export default function localModelClientTest() {
  describe('localModelClient', () => {
    it('uses the same Loopy adapter prompt for every user query', 0, () => {
      const baseline = resolveSystemPrompt('');
      expect(baseline.length > 0).assertTrue();
      expect(baseline.indexOf('Loopy adapter')).assertLarger(-1);
      expect(baseline.indexOf('@loop/agent-core')).assertLarger(-1);
      expect(baseline.indexOf('A2UI v0.9.1 JSONL')).assertEqual(-1);
      expect(resolveSystemPrompt('你好')).assertEqual(baseline);
      expect(resolveSystemPrompt('帮我查明天北京到上海高铁票')).assertEqual(baseline);
      expect(resolveSystemPrompt('帮我看 Gmail 里最新的重要邮件')).assertEqual(baseline);
      expect(resolveSystemPrompt('我想明天从北京去上海，帮我整理可查的出行选项')).assertEqual(baseline);
    });

    it('builds DashScope compatible chat completion URLs without double appending paths', 0, () => {
      expect(buildChatCompletionsUrl('https://dashscope.aliyuncs.com/compatible-mode/v1')).assertEqual('https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions');
      expect(buildChatCompletionsUrl('https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions')).assertEqual('https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions');
    });

    it('defaults to DashScope qwen-max and reads its local rawfile key', 0, () => {
      configureLocalModelSettingsFromRawJson('{"DASHSCOPE_API_KEY":"test-key"}');
      const settings = defaultLocalModelSettings();
      expect(settings.provider).assertEqual('DashScope');
      expect(settings.baseUrl).assertEqual('https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions');
      expect(settings.model).assertEqual('qwen-max');
      expect(settings.apiKey).assertEqual('test-key');
      expect(settings.customParametersJson).assertEqual('{"enable_thinking":false}');
      expect(settings.ignoreToolSurfaceUpdates).assertFalse();
      configureLocalModelSettingsFromRawJson('{}');
    });
  });
}
