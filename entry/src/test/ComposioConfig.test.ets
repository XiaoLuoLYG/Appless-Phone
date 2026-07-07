import { describe, it, expect } from '@ohos/hypium';
import { ComposioConfig, describeComposioFailure } from '@loop/agent-core';

export default function composioConfigTest() {
  describe('composioConfig', () => {
    it('parses raw JSON config and trims trailing slashes', 0, () => {
      const config: ComposioConfig = ComposioConfig.fromRawJson('{"apiKey":" key ","baseUrl":"https://example.test/api/","userId":" user ","proxyBaseUrl":"http://127.0.0.1:8787"}');

      expect(config.apiKey).assertEqual('key');
      expect(config.baseUrl).assertEqual('https://example.test/api');
      expect(config.userId).assertEqual('user');
      expect(config.proxyBaseUrl).assertEqual('http://127.0.0.1:8787');
      expect(config.isConfigured()).assertTrue();
    });

    it('accepts proxy-only config when user id and proxy base url exist', 0, () => {
      const proxyOnly: ComposioConfig = ComposioConfig.fromRawJson('{"userId":"user-1","proxyBaseUrl":"http://127.0.0.1:8787"}');

      expect(proxyOnly.isConfigured()).assertTrue();
      expect(proxyOnly.missingConfiguration()).assertEqual('');
    });

    it('returns a safe empty config for invalid JSON', 0, () => {
      const config: ComposioConfig = ComposioConfig.fromRawJson('{broken');

      expect(config.apiKey).assertEqual('');
      expect(config.baseUrl).assertEqual('https://backend.composio.dev/api/v3.1');
      expect(config.userId).assertEqual('');
      expect(config.isConfigured()).assertFalse();
      expect(config.missingConfiguration()).assertEqual('userId, apiKey or proxyBaseUrl');
    });

    it('formats object failures without object placeholder text', 0, () => {
      const failure = JSON.parse('{"code":2300028,"message":{"name":"NetworkError","message":"request timeout"}}') as Object;
      const message = describeComposioFailure(failure);

      expect(message.indexOf('[object Object]')).assertEqual(-1);
      expect(message.indexOf('request timeout')).assertLarger(-1);
    });
  });
}
