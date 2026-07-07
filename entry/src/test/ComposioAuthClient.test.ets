import { describe, it, expect } from '@ohos/hypium';
import {
  normalizeComposioHttpResponse,
  normalizeComposioAuthConfigsResponse,
  normalizeComposioLinkResponse,
  normalizeComposioUserId,
  shortComposioUserId
} from '@loop/agent-core';

function parseObject(raw: string): Object {
  return JSON.parse(raw) as Object;
}

export default function composioAuthClientTest() {
  describe('composioAuthClient', () => {
    it('normalizes auth configs without a fixed toolkit list', 0, () => {
      const payload = parseObject('{"ok":true,"userId":"app-user-1","items":[{"authConfigId":"ac_1","toolkitSlug":"github","toolkitName":"GitHub","status":"connected","connectedAccountId":"ca_1"},{"authConfigId":"ac_2","toolkitSlug":"ticketmaster","toolkitName":"Ticketmaster","status":"needs_auth"}]}');
      const result = normalizeComposioAuthConfigsResponse(payload);

      expect(result.ok).assertTrue();
      expect(result.userId).assertEqual('app-user-1');
      expect(result.items.length).assertEqual(2);
      expect(result.items[1].toolkitSlug).assertEqual('ticketmaster');
      expect(result.items[1].status).assertEqual('needs_auth');
    });

    it('keeps valid redirect URLs and rejects missing links', 0, () => {
      const ok = normalizeComposioLinkResponse(parseObject('{"ok":true,"redirectUrl":"https://mock.composio.local/connect/github"}'));
      const bad = normalizeComposioLinkResponse(parseObject('{"ok":true}'));

      expect(ok.redirectUrl).assertEqual('https://mock.composio.local/connect/github');
      expect(bad.ok).assertFalse();
      expect(bad.error.indexOf('redirectUrl')).assertLarger(-1);
    });

    it('preserves proxy error text for non-2xx auth-config responses', 0, () => {
      const payload = normalizeComposioHttpResponse(400, '{"error":"userId is required."}');
      const result = normalizeComposioAuthConfigsResponse(payload);

      expect(result.ok).assertFalse();
      expect(result.error).assertEqual('userId is required.');
      expect(result.items.length).assertEqual(0);
    });

    it('preserves proxy error text for non-2xx link responses', 0, () => {
      const payload = normalizeComposioHttpResponse(400, '{"error":"userId is required."}');
      const result = normalizeComposioLinkResponse(payload);

      expect(result.ok).assertFalse();
      expect(result.error).assertEqual('userId is required.');
      expect(result.redirectUrl).assertEqual('');
    });

    it('normalizes and shortens app user ids', 0, () => {
      expect(normalizeComposioUserId(' User 1 / Device ')).assertEqual('user-1-device');
      expect(shortComposioUserId('aiphone-user-abcdef123456')).assertEqual('abcdef123456');
    });
  });
}
