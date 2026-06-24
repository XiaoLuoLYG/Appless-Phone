import { describe, it, expect } from '@ohos/hypium';
import { resolveSystemPrompt } from '../main/ets/model/LocalModelClient';

export default function localModelClientTest() {
  describe('localModelClient', () => {
    it('uses the same system prompt for every user query', 0, () => {
      const baseline = resolveSystemPrompt('');
      expect(baseline.length > 0).assertTrue();
      expect(baseline.indexOf('A2UI v0.9.1 JSONL') >= 0).assertTrue();
      expect(baseline.indexOf('示例 A，寒暄') >= 0).assertTrue();
      expect(baseline.indexOf('示例 B，实时查高铁') >= 0).assertTrue();
      expect(baseline.indexOf('示例 C，非实时整理规划思路') >= 0).assertTrue();
      expect(baseline.indexOf('示例 E，查看 Gmail') >= 0).assertTrue();
      expect(baseline.indexOf('麦当劳官方 MCP 查询结果') >= 0).assertTrue();
      expect(baseline.indexOf('禁止创建订单、支付、自动领券') >= 0).assertTrue();
      expect(baseline.indexOf('gmail.mail.search|gmail.thread.read|gmail.draft.create|gmail.draft.apply|gmail.open.web|gmail.message.send') >= 0).assertTrue();
      expect(baseline.indexOf('模型阶段禁止编造 Gmail 邮件') >= 0).assertTrue();
      expect(baseline.indexOf('dynamic.search|gmail.mail.search') >= 0).assertTrue();
      expect(resolveSystemPrompt('你好')).assertEqual(baseline);
      expect(resolveSystemPrompt('帮我查明天北京到上海高铁票')).assertEqual(baseline);
      expect(resolveSystemPrompt('帮我看 Gmail 里最新的重要邮件')).assertEqual(baseline);
      expect(resolveSystemPrompt('我想明天从北京去上海，帮我整理可查的出行选项')).assertEqual(baseline);
    });
  });
}
