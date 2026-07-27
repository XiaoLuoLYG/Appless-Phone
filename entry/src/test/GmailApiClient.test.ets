import { describe, it, expect } from '@ohos/hypium';
import { gmailMailDetailFromComposioObservation, gmailMailDetailFromPayload } from '@loop/agent-core';

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

    it('keeps a real full Gmail MIME body beyond the Dynamic preview limit', 0, () => {
      const encodedBody = 'QUFB'.repeat(500);
      const payload = JSON.parse('{"successful":true,"data":{"id":"thread-long","messages":[' +
        '{"id":"message-long","threadId":"thread-long","payload":{"mimeType":"text/plain",' +
        '"headers":[{"name":"Subject","value":"Long status"},{"name":"From",' +
        '"value":"Alice <alice@example.com>"},{"name":"To","value":"Me <me@example.com>"}],' +
        '"body":{"data":"' + encodedBody + '"}}}]}}') as Object;
      const detail = gmailMailDetailFromPayload(payload, {
        requestKey: 'gmail:thread-long',
        provider: 'gmail',
        threadId: 'thread-long',
        messageId: 'message-long',
        subject: 'Fallback subject'
      });

      expect(detail.bodyText.length).assertEqual(1500);
      expect(detail.bodyText).assertEqual('A'.repeat(1500));
    });

    it('ignores drafts when parsing the legacy Gmail thread fallback', 0, () => {
      const payload = JSON.parse('{"successful":true,"data":{"id":"thread-large","messages":[' +
        '{"id":"message-large","threadId":"thread-large","labelIds":["INBOX"],"payload":' +
        '{"mimeType":"text/plain","headers":[{"name":"Subject","value":"Large thread"},' +
        '{"name":"From","value":"Alice <alice@example.com>"},{"name":"To","value":"Me <me@example.com>"}],' +
        '"body":{"data":"SGVsbG8gZnJvbSBhIGxhcmdlIHRocmVhZA=="}}},' +
        '{"id":"message-draft","threadId":"thread-large","labelIds":["DRAFT"],' +
        '"messageText":"Draft text must not replace the received message.","payload":' +
        '{"mimeType":"text/html","headers":[{"name":"Subject","value":"Draft reply"},' +
        '{"name":"From","value":"Me <me@example.com>"}],"body":{"data":"PHA+RHJhZnQgYm9keTwvcD4="}}}],' +
        '"ignoredField":"thread fallback"}}') as Object;
      const observation = JSON.stringify(payload);
      const detail = gmailMailDetailFromComposioObservation(observation, {
        requestKey: 'gmail:thread-large',
        provider: 'gmail',
        threadId: 'thread-large',
        messageId: 'message-large',
        subject: ''
      });

      expect(detail.subject).assertEqual('Large thread');
      expect(detail.bodyText).assertEqual('Hello from a large thread');
      expect(detail.messageId).assertEqual('message-large');
    });

    it('reads one Gmail message by messageId without substituting threadId', 0, () => {
      const observation = '{"data":{"messageId":"message-single","threadId":"thread-single",' +
        '"labelIds":["INBOX"],"messageText":"Single message body","payload":{"mimeType":"text/html"}}}';
      const detail = gmailMailDetailFromComposioObservation(observation, {
        requestKey: 'gmail:message-single',
        provider: 'gmail',
        threadId: 'thread-single',
        messageId: 'message-single',
        subject: 'Fallback'
      });

      expect(detail.messageId).assertEqual('message-single');
      expect(detail.threadId).assertEqual('thread-single');
      expect(detail.bodyText).assertEqual('Single message body');
    });

    it('uses a full direct Gmail body before stale MIME fallback text', 0, () => {
      const payload = JSON.parse('{"data":{"messageId":"message-direct","threadId":"thread-direct",' +
        '"labelIds":["INBOX"],"messageText":"Complete provider body",' +
        '"payload":{"mimeType":"text/plain","body":{"data":"U3RhbGUgTUlNRSBib2R5"}}}}') as Object;
      const detail = gmailMailDetailFromPayload(payload, {
        requestKey: 'gmail:message-direct',
        provider: 'gmail',
        threadId: 'thread-direct',
        messageId: 'message-direct',
        subject: 'Fallback'
      });

      expect(detail.bodyText).assertEqual('Complete provider body');
    });

    it('ignores a newer draft when selecting the received Gmail body', 0, () => {
      const payload = JSON.parse('{"successful":true,"data":{"id":"thread-1","messages":[' +
        '{"id":"received","threadId":"thread-1","labelIds":["INBOX"],"messageText":"Received"},' +
        '{"id":"draft","threadId":"thread-1","labelIds":["DRAFT"],"messageText":"Private draft"}]}}') as Object;
      const detail = gmailMailDetailFromPayload(payload, {
        requestKey: 'gmail:thread-1', provider: 'gmail',
        threadId: 'thread-1', messageId: 'received', subject: 'Fallback'
      });

      expect(detail.messageId).assertEqual('received');
      expect(detail.bodyText).assertEqual('Received');
    });

    it('rejects a Gmail thread containing only drafts', 0, () => {
      const observation = '{"successful":true,"data":{"id":"thread-draft","messages":[' +
        '{"id":"message-draft","threadId":"thread-draft","labelIds":["DRAFT"],' +
        '"messageText":"Private draft text","payload":{"mimeType":"text/plain"}}]}}';
      let errorMessage = '';
      try {
        gmailMailDetailFromComposioObservation(observation, {
          requestKey: 'gmail:thread-draft',
          provider: 'gmail',
          threadId: 'thread-draft',
          messageId: 'message-draft',
          subject: ''
        });
      } catch (error) {
        errorMessage = error instanceof Error ? error.message : `${error}`;
      }

      expect(errorMessage).assertEqual('Composio Gmail thread contained only draft messages.');
    });
  });
}
