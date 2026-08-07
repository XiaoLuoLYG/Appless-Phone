import { describe, it, expect } from '@ohos/hypium';
import {
  directModelRequestDebug,
  directModelSystemPrompt
} from '../main/ets/model/LocalModelClient';
import { configureLocalModelSettingsFromRawJson, defaultLocalModelSettings } from '@loop/agent-core';

export default function localModelClientTest() {
  describe('localModelClient', () => {
    it('uses a tool-free direct model prompt for non-orchestration utilities', 0, () => {
      const baseline = directModelSystemPrompt();
      expect(baseline.length > 0).assertTrue();
      expect(baseline.indexOf('Do not call tools.')).assertLarger(-1);
      expect(baseline.indexOf('ReAct')).assertEqual(-1);
      expect(baseline.indexOf('A2UI')).assertEqual(-1);
    });

    it('reports a direct model request without a tool-loop endpoint', 0, () => {
      const settings = defaultLocalModelSettings();
      const debug = directModelRequestDebug(settings, 'reply', 3);
      expect(debug.indexOf('OpenAiCompatibleModel.direct')).assertLarger(-1);
      expect(debug.indexOf('LoopBackend')).assertEqual(-1);
      expect(debug.indexOf('"historyTurns":3')).assertLarger(-1);
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
