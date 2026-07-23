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

    it('reads one exact Gmail message from a full Composio observation', 0, () => {
      const observation = '{"data":{"messageId":"message-single","threadId":"thread-single",' +
        '"labelIds":["INBOX"],"messageText":"Single message body","payload":{"mimeType":"text/html",' +
        '"headers":[{"name":"Subject","value":"Single subject"},{"name":"From",' +
        '"value":"Alice <alice@example.com>"}],"body":{"data":""}}},"error":null}';
      const detail = gmailMailDetailFromComposioObservation(observation, {
        requestKey: 'gmail:thread-single',
        provider: 'gmail',
        threadId: 'thread-single',
        messageId: 'message-single',
        subject: ''
      });

      expect(detail.requestKey).assertEqual('gmail:thread-single');
      expect(detail.threadId).assertEqual('thread-single');
      expect(detail.messageId).assertEqual('message-single');
      expect(detail.subject).assertEqual('Single subject');
      expect(detail.bodyText).assertEqual('Single message body');
    });

    it('keeps a complete provider observation larger than the dynamic preview limit', 0, () => {
      const body: string = '真实完整 Gmail 正文。'.repeat(1800);
      const observation: string = '{"data":{"messageId":"message-large","threadId":"thread-large",' +
        '"labelIds":["INBOX"],"messageText":' + JSON.stringify(body) + ',' +
        '"payload":{"headers":[{"name":"Subject","value":"Large exact message"}]}}}';
      const detail = gmailMailDetailFromComposioObservation(observation, {
        requestKey: 'gmail:thread-large', provider: 'gmail', threadId: 'thread-large',
        messageId: 'message-large', subject: ''
      });

      expect(observation.length > 16000).assertTrue();
      expect(detail.threadId).assertEqual('thread-large');
      expect(detail.messageId).assertEqual('message-large');
      expect(detail.bodyText).assertEqual(body);
    });

    it('fails closed when the provider omits or changes the requested Gmail identities', 0, () => {
      const observations: string[] = [
        '{"data":{"threadId":"thread-exact","messageText":"missing message ID",' +
          '"payload":{"headers":[]}}}',
        '{"data":{"messageId":"message-exact","messageText":"missing thread ID",' +
          '"payload":{"headers":[]}}}',
        '{"data":{"messageId":"message-wrong","threadId":"thread-exact",' +
          '"messageText":"wrong message ID","payload":{"headers":[]}}}',
        '{"data":{"messageId":"message-exact","threadId":"thread-wrong",' +
          '"messageText":"wrong thread ID","payload":{"headers":[]}}}',
        '{"data":{"id":"thread-exact","messages":[{"id":"message-wrong",' +
          '"threadId":"thread-exact","messageText":"wrong thread member",' +
          '"payload":{"headers":[]}}]}}'
      ];
      let rejected: number = 0;

      observations.forEach((observation: string) => {
        try {
          gmailMailDetailFromComposioObservation(observation, {
            requestKey: 'gmail:thread-exact', provider: 'gmail', threadId: 'thread-exact',
            messageId: 'message-exact', subject: ''
          });
        } catch (_error) {
          rejected++;
        }
      });

      expect(rejected).assertEqual(observations.length);
    });

    it('ignores Gmail drafts when reading a thread fallback', 0, () => {
      const observation = '{"successful":true,"data":{"id":"thread-large","messages":[' +
        '{"id":"message-large","threadId":"thread-large","labelIds":["INBOX"],"messageText":' +
        '"Received body","payload":{"headers":[{"name":"Subject","value":"Received subject"}]}},' +
        '{"id":"message-draft","threadId":"thread-large","labelIds":["DRAFT"],"messageText":' +
        '"Private draft","payload":{"headers":[{"name":"Subject","value":"Draft subject"}]}}]}}';
      const detail = gmailMailDetailFromComposioObservation(observation, {
        requestKey: 'gmail:thread-large', provider: 'gmail', threadId: 'thread-large',
        messageId: 'message-large', subject: ''
      });

      expect(detail.messageId).assertEqual('message-large');
      expect(detail.subject).assertEqual('Received subject');
      expect(detail.bodyText).assertEqual('Received body');
    });

    it('fails closed for only-draft truncated and malformed Gmail observations', 0, () => {
      const failures: string[] = [];
      const observations: string[] = [
        '{"successful":true,"data":{"id":"thread-draft","messages":[{"id":"message-draft",' +
          '"threadId":"thread-draft","labelIds":["DRAFT"],"messageText":"Private draft"}]}}',
        '{"truncated":true,"data":{"messageId":"message-1","threadId":"thread-1",' +
          '"messageText":"partial"}}',
        'not-json'
      ];
      observations.forEach((observation: string) => {
        try {
          gmailMailDetailFromComposioObservation(observation, {
            requestKey: 'gmail:thread-draft', provider: 'gmail', threadId: 'thread-draft',
            messageId: 'message-draft', subject: ''
          });
        } catch (error) {
          failures.push(error instanceof Error ? error.message : `${error}`);
        }
      });

      expect(failures.length).assertEqual(3);
      expect(failures[0].indexOf('only draft')).assertLarger(-1);
      expect(failures[1].indexOf('truncated')).assertLarger(-1);
      expect(failures[2].indexOf('valid JSON')).assertLarger(-1);
    });
  });
}
