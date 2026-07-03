import { describe, it, expect } from '@ohos/hypium';
import { discoverDynamicToolForPrompt, DynamicToolDiscoveryResult } from '@loop/agent-core';
import { configureDefaultDynamicToolSamplesForTests } from '@loop/agent-core';

export default function dynamicToolDiscoveryTest() {
  describe('dynamicToolDiscovery', () => {
    it('discovers the statistics MCP candidate from a user query', 0, () => {
      configureDefaultDynamicToolSamplesForTests();
      const result = discoverDynamicToolForPrompt('帮我查一下最近的统计局GDP数据') as DynamicToolDiscoveryResult;

      expect(result === null).assertFalse();
      expect(result.toolId).assertEqual('statistics.search');
      expect(result.manifest.id).assertEqual('modelscope.thatcoder.cnbs');
      expect(result.source).assertEqual('modelscope-local-catalog');
    });

    it('discovers an unsupported PPT MCP candidate from a user query', 0, () => {
      configureDefaultDynamicToolSamplesForTests();
      const result = discoverDynamicToolForPrompt('帮我生成一份深圳低空经济介绍PPT') as DynamicToolDiscoveryResult;

      expect(result === null).assertFalse();
      expect(result.toolId).assertEqual('ppt.generate');
      expect(result.manifest.id).assertEqual('modelscope.@deckflow.gezhe-mcp-server');
    });

    it('returns null when the catalog has no matching MCP candidate', 0, () => {
      configureDefaultDynamicToolSamplesForTests();
      const result = discoverDynamicToolForPrompt('帮我查明天深圳到珠海的船票');

      expect(result === null).assertTrue();
    });
  });
}
