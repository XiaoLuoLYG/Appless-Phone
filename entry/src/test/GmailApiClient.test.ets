import { describe, it, expect } from '@ohos/hypium';
import { gmailMailDetailFromPayload } from '@loop/agent-core';

export default function gmailApiClientTest() {
  describe('gmailApiClient', () => {
    it('reads a full Gmail thread payload returned through Composio', 0, () => {
      const payload = JSON.parse('{"successful":true,"data":{"id":"thread-1","messages":[{"id":"message-1","threadId":"thread-1","payload":{"mimeType":"multipart/alternative","headers":[{"name":"Subject","value":"Status update"},{"name":"From","value":"Alice <alice@example.com>"},{"name":"To","value":"Me <me@example.com>"},{"name":"Cc","value":"Bob <bob@example.com>"}],"parts":[{"mimeType":"text/plain","body":{"data":"SGVsbG8gR21haWw="}},{"mimeType":"text/html","body":{"data":"PHA+SGVsbG8gR21haWw8L3A+"}}]}}]}}') as Object;
      const detail = gmailMailDetailFromPayload(payload, {
        requestKey: 'gmail:thread-1',
        provider: 'gmail',
        threadId: 'thread-1',
        messageId: 'message-1',
        subject: 'Fallback subject'
      });

      expect(detail.subject).assertEqual('Status update');
      expect(detail.from).assertEqual('Alice <alice@example.com>');
      expect(detail.to[0]).assertEqual('Me <me@example.com>');
      expect(detail.cc[0]).assertEqual('Bob <bob@example.com>');
      expect(detail.bodyText).assertEqual('Hello Gmail');
    });
  });
}
