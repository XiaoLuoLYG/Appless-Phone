import { describe, it, expect } from '@ohos/hypium';
import { ComposioConfig } from '@loop/agent-core';

export default function composioConfigTest() {
  describe('composioConfig', () => {
    it('parses raw JSON config and trims trailing slashes', 0, () => {
      const config: ComposioConfig = ComposioConfig.fromRawJson('{"apiKey":" key ","baseUrl":"https://example.test/api/","userId":" user "}');

      expect(config.apiKey).assertEqual('key');
      expect(config.baseUrl).assertEqual('https://example.test/api');
      expect(config.userId).assertEqual('user');
      expect(config.isConfigured()).assertTrue();
    });

    it('returns a safe empty config for invalid JSON', 0, () => {
      const config: ComposioConfig = ComposioConfig.fromRawJson('{broken');

      expect(config.apiKey).assertEqual('');
      expect(config.baseUrl).assertEqual('https://backend.composio.dev/api/v3.1');
      expect(config.userId).assertEqual('');
      expect(config.isConfigured()).assertFalse();
      expect(config.missingConfiguration()).assertEqual('apiKey, userId');
    });
  });
}
