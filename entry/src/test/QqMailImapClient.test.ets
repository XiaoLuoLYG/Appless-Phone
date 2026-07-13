import { describe, it, expect } from '@ohos/hypium';
import {
  buildQqDraftMime,
  buildQqReplyMime,
  decodeMimeWords,
  ImapTransport,
  MailDraftArgs,
  parseImapEnvelopeList,
  pickDraftMailbox,
  QqMailImapClient,
  SmtpTransport
} from '@loop/agent-core';

class FakeSearchTransport implements ImapTransport {
  events: string[] = [];

  async connect(host: string, port: number): Promise<void> {
    this.events.push('connect:' + host + ':' + port.toString());
  }

  async send(line: string): Promise<void> {
    this.events.push('send:' + line);
  }

  async readUntil(tag: string): Promise<string[]> {
    this.events.push('read:' + tag);
    if (tag === '*') {
      return ['* OK QQMail XMIMAP4Server ready'];
    }
    if (tag === 'a1') {
      return ['a1 OK LOGIN completed'];
    }
    if (tag === 'a2') {
      return ['a2 OK SELECT completed'];
    }
    if (tag === 'a3') {
      return ['* SEARCH 7', 'a3 OK SEARCH completed'];
    }
    if (tag === 'a4') {
      return [
        '* 7 FETCH (UID 777 ENVELOPE ("Tue, 30 Jun 2026 09:00:00 +0800" "loopy QQ Subject" (("Alice" NIL "alice" "example.com")) NIL NIL NIL NIL NIL NIL "<msg-777@example.com>") FLAGS (\\\\Seen))',
        'a4 OK FETCH completed'
      ];
    }
    return [tag + ' OK'];
  }

  async close(): Promise<void> {
    this.events.push('close');
  }
}

class FakeDetailTransport implements ImapTransport {
  events: string[] = [];

  async connect(host: string, port: number): Promise<void> {
    this.events.push('connect:' + host + ':' + port.toString());
  }

  async send(line: string): Promise<void> {
    this.events.push('send:' + line);
  }

  async readUntil(tag: string): Promise<string[]> {
    this.events.push('read:' + tag);
    if (tag === '*') {
      return ['* OK QQMail XMIMAP4Server ready'];
    }
    if (tag === 'a1') {
      return ['a1 OK LOGIN completed'];
    }
    if (tag === 'a2') {
      return ['a2 OK SELECT completed'];
    }
    if (tag === 'a3') {
      return [
        '* 7 FETCH (UID 777 BODY[] {240}',
        'From: Alice <alice@example.com>',
        'To: Me <me@qq.com>',
        'Cc: Bob <bob@example.com>',
        'Subject: QQ detail subject',
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
        'Content-Transfer-Encoding: quoted-printable',
        '',
        'Hello =E4=BD=A0=E5=A5=BD',
        ')',
        'a3 OK FETCH completed'
      ];
    }
    return [tag + ' OK'];
  }

  async close(): Promise<void> {
    this.events.push('close');
  }
}

class FakeMultipartDetailTransport implements ImapTransport {
  events: string[] = [];

  async connect(host: string, port: number): Promise<void> {
    this.events.push('connect:' + host + ':' + port.toString());
  }

  async send(line: string): Promise<void> {
    this.events.push('send:' + line);
  }

  async readUntil(tag: string): Promise<string[]> {
    this.events.push('read:' + tag);
    if (tag === '*') {
      return ['* OK QQMail XMIMAP4Server ready'];
    }
    if (tag === 'a1') {
      return ['a1 OK LOGIN completed'];
    }
    if (tag === 'a2') {
      return ['a2 OK SELECT completed'];
    }
    if (tag === 'a3') {
      return [
        '* 8 FETCH (UID 888 BODY[] {900}',
        'From: Alice <alice@example.com>',
        'To: Me <me@qq.com>',
        'Subject: Multipart detail subject',
        'X-QQ-XMAILINFO: Ni9x4/rit5OgikMei5BmSFhfCMz+V1aT4B2jhUFshKjwQTUTig+Phj66jalguE',
        'MIME-Version: 1.0',
        'Content-Type: multipart/related;',
        ' boundary="----=_Part_CaseSensitiveA1B2"',
        '',
        'This is a multipart MIME message.',
        '------=_Part_CaseSensitiveA1B2',
        'Content-Type: multipart/alternative;',
        ' boundary="----=_Alt_CaseSensitiveC3D4"',
        '',
        '------=_Alt_CaseSensitiveC3D4',
        'Content-Type: text/plain; charset=UTF-8',
        'Content-Transfer-Encoding: quoted-printable',
        '',
        'Readable =E6=AD=A3=E6=96=87',
        '------=_Alt_CaseSensitiveC3D4',
        'Content-Type: text/html; charset=UTF-8',
        'Content-Transfer-Encoding: quoted-printable',
        '',
        '<p>Readable <strong>HTML</strong></p>',
        '------=_Alt_CaseSensitiveC3D4--',
        '------=_Part_CaseSensitiveA1B2',
        'Content-Type: image/png; name="pixel.png"',
        'Content-Transfer-Encoding: base64',
        '',
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB',
        '------=_Part_CaseSensitiveA1B2--',
        ')',
        'a3 OK FETCH completed'
      ];
    }
    return [tag + ' OK'];
  }

  async close(): Promise<void> {
    this.events.push('close');
  }
}

class FakeEncodedHtmlDetailTransport implements ImapTransport {
  async connect(_host: string, _port: number): Promise<void> {
  }

  async send(_line: string): Promise<void> {
  }

  async readUntil(tag: string): Promise<string[]> {
    if (tag === '*') {
      return ['* OK QQMail XMIMAP4Server ready'];
    }
    if (tag === 'a1') {
      return ['a1 OK LOGIN completed'];
    }
    if (tag === 'a2') {
      return ['a2 OK SELECT completed'];
    }
    if (tag === 'a3') {
      return [
        '* 9 FETCH (UID 999 BODY[] {320}',
        'From: Sender <sender@example.com>',
        'To: Me <me@qq.com>',
        'Subject: Encoded HTML detail',
        'MIME-Version: 1.0',
        'Content-Type: text/html; charset=UTF-8',
        'Content-Transfer-Encoding: quoted-printable',
        '',
        '<div>&zwnj;=E4=B8=AD=E6=96=87 &#064;</div>',
        '<div><br><br><br>Line&nbsp;two</div>',
        ')',
        'a3 OK FETCH completed'
      ];
    }
    return [tag + ' OK'];
  }

  async close(): Promise<void> {
  }
}

class FakeSmtpTransport implements SmtpTransport {
  sent: string[] = [];
  private responses: string[][] = [
    ['220 smtp.qq.com ready'],
    ['250-smtp.qq.com', '250 AUTH LOGIN'],
    ['334 VXNlcm5hbWU6'],
    ['334 UGFzc3dvcmQ6'],
    ['235 Authentication successful'],
    ['250 Sender OK'],
    ['250 Recipient OK'],
    ['354 End data with <CR><LF>.<CR><LF>'],
    ['250 Message accepted']
  ];

  async connect(host: string, port: number): Promise<void> {
    this.sent.push('connect:' + host + ':' + port.toString());
  }

  async send(value: string): Promise<void> {
    this.sent.push(value);
  }

  async readResponse(): Promise<string[]> {
    return this.responses.length > 0 ? this.responses.shift() as string[] : ['221 Bye'];
  }

  async close(): Promise<void> {
    this.sent.push('close');
  }
}

export default function qqMailImapClientTest() {
  describe('qqMailImapClient', () => {
    it('decodes simple MIME encoded words', 0, () => {
      expect(decodeMimeWords('=?UTF-8?B?5rWL6K+V?=')).assertEqual('测试');
      expect(decodeMimeWords('=?utf-8?B?5rWL6K+V?=')).assertEqual('测试');
      expect(decodeMimeWords('Project Update')).assertEqual('Project Update');
    });

    it('picks a drafts mailbox from common QQ folder names', 0, () => {
      expect(pickDraftMailbox(['INBOX', 'Sent Messages', 'Drafts'], '')).assertEqual('Drafts');
      expect(pickDraftMailbox(['INBOX', '&g0l6P3ux-'], '')).assertEqual('&g0l6P3ux-');
      expect(pickDraftMailbox(['INBOX'], 'MyDrafts')).assertEqual('MyDrafts');
    });

    it('parses minimal IMAP envelope responses into mail threads', 0, () => {
      const parsed = parseImapEnvelopeList([
        '* 7 FETCH (UID 777 ENVELOPE ("Tue, 30 Jun 2026 09:00:00 +0800" "QQ Subject" (("Alice" NIL "alice" "example.com")) NIL NIL (("Me" NIL "me" "qq.com")) NIL NIL NIL "<msg-777@example.com>") FLAGS (\\\\Seen))'
      ], 'q***@qq.com');

      expect(parsed.length).assertEqual(1);
      expect(parsed[0].provider).assertEqual('qq');
      expect(parsed[0].messageId).assertEqual('777');
      expect(parsed[0].subject).assertEqual('QQ Subject');
      expect(parsed[0].from).assertEqual('Alice <alice@example.com>');
      expect(parsed[0].snippet).assertEqual('');
      expect(parsed[0].receivedAt).assertEqual('2026-06-30T09:00:00.000+08:00');
    });

    it('reads QQ body with BODY.PEEK without marking the message as seen', 0, async () => {
      const fake = new FakeDetailTransport();
      const client = new QqMailImapClient({
        address: 'me@qq.com',
        authCode: 'auth-code',
        imapHost: 'imap.qq.com',
        imapPort: 993,
        draftsMailbox: ''
      }, () => fake);

      const detail = await client.readDetail({
        requestKey: 'qq:777',
        provider: 'qq',
        threadId: '',
        messageId: '777',
        subject: 'QQ detail subject'
      });

      const fetch = fake.events.filter((event: string) => event.indexOf('send:a3 UID FETCH') === 0)[0];
      expect(fetch.indexOf('BODY.PEEK[]')).assertLarger(-1);
      expect(detail.bodyText).assertEqual('Hello 你好');
      expect(detail.to[0]).assertEqual('Me <me@qq.com>');
      expect(detail.cc[0]).assertEqual('Bob <bob@example.com>');
    });

    it('preserves case-sensitive MIME boundaries and ignores base64 image parts', 0, async () => {
      const fake = new FakeMultipartDetailTransport();
      const client = new QqMailImapClient({
        address: 'me@qq.com',
        authCode: 'auth-code',
        imapHost: 'imap.qq.com',
        imapPort: 993,
        draftsMailbox: ''
      }, () => fake);

      const detail = await client.readDetail({
        requestKey: 'qq:888',
        provider: 'qq',
        threadId: '',
        messageId: '888',
        subject: 'Multipart detail subject'
      });

      expect(detail.bodyText).assertEqual('Readable 正文');
      expect(detail.bodyText.indexOf('iVBORw0KGgo')).assertEqual(-1);
      expect(detail.bodyText.indexOf('Ni9x4/rit5')).assertEqual(-1);
      expect(detail.bodyText.indexOf('<strong>')).assertEqual(-1);
      expect(detail.bodyHtml.indexOf('<strong>HTML</strong>')).assertLarger(-1);
    });

    it('decodes declared UTF-8 and removes HTML text entities', 0, async () => {
      const client = new QqMailImapClient({
        address: 'me@qq.com',
        authCode: 'auth-code',
        imapHost: 'imap.qq.com',
        imapPort: 993,
        draftsMailbox: ''
      }, () => new FakeEncodedHtmlDetailTransport());

      const detail = await client.readDetail({
        requestKey: 'qq:999',
        provider: 'qq',
        threadId: '',
        messageId: '999',
        subject: 'Encoded HTML detail'
      });

      expect(detail.bodyText.indexOf('&zwnj;')).assertEqual(-1);
      expect(detail.bodyText.indexOf('&#064;')).assertEqual(-1);
      expect(detail.bodyText.indexOf('中文 @')).assertLarger(-1);
      expect(detail.bodyText.indexOf('\n\n\n')).assertEqual(-1);
    });

    it('waits for the IMAP greeting before sending QQ login', 0, async () => {
      const fake = new FakeSearchTransport();
      const client = new QqMailImapClient({
        address: 'me@qq.com',
        authCode: 'auth-code',
        imapHost: 'imap.qq.com',
        imapPort: 993,
        draftsMailbox: ''
      }, () => fake);

      const rows = await client.search({
        query: '',
        pageSize: 1,
        providers: ['qq'],
        intentSummary: ''
      });

      expect(fake.events[0]).assertEqual('connect:imap.qq.com:993');
      expect(fake.events[1]).assertEqual('read:*');
      expect(fake.events[2].indexOf('send:a1 LOGIN')).assertEqual(0);
      expect(fake.events[fake.events.length - 1]).assertEqual('close');
      expect(rows.length).assertEqual(1);
      expect(rows[0].provider).assertEqual('qq');
    });

    it('uses newer_than and keyword as a scoped IMAP search instead of scanning all mail', 0, async () => {
      const fake = new FakeSearchTransport();
      const client = new QqMailImapClient({
        address: 'me@qq.com',
        authCode: 'auth-code',
        imapHost: 'imap.qq.com',
        imapPort: 993,
        draftsMailbox: ''
      }, () => fake);

      await client.search({
        query: 'newer_than:30d loopy',
        pageSize: 1,
        providers: ['qq'],
        intentSummary: ''
      });

      const search = fake.events.filter((event: string) => event.indexOf('send:a3 UID SEARCH') === 0)[0];
      expect(search.indexOf('send:a3 UID SEARCH SINCE ')).assertEqual(0);
      expect(search.indexOf('TEXT "loopy"')).assertLarger(-1);
      expect(search.indexOf('ALL')).assertEqual(-1);
    });

    it('builds a reply draft MIME message without claiming send', 0, () => {
      const mime = buildQqDraftMime({
        provider: 'qq',
        accountLabel: 'q***@qq.com',
        threadId: '',
        messageId: '<msg-777@example.com>',
        to: ['alice@example.com'],
        subject: 'Re: QQ Subject',
        body: 'Thanks for the update.',
        replyMode: 'reply',
        contextSummary: 'Alice asked for a quick confirmation.'
      }, 'me@qq.com');

      expect(mime.indexOf('To: alice@example.com')).assertLarger(-1);
      expect(mime.indexOf('Subject: Re: QQ Subject')).assertLarger(-1);
      expect(mime.indexOf('In-Reply-To: <msg-777@example.com>')).assertLarger(-1);
      expect(mime.indexOf('Thanks for the update.')).assertLarger(-1);
    });

    it('sends QQ replies through authenticated SMTP with reply headers', 0, async () => {
      const smtp = new FakeSmtpTransport();
      const client = new QqMailImapClient({
        address: 'me@qq.com',
        authCode: 'auth-code',
        imapHost: 'imap.qq.com',
        imapPort: 993,
        draftsMailbox: ''
      }, () => new FakeSearchTransport(), () => smtp);
      const args: MailDraftArgs = {
        provider: 'qq',
        accountLabel: 'm***@qq.com',
        threadId: '',
        messageId: '777',
        internetMessageId: '<message-777@example.com>',
        to: ['Alice <alice@example.com>'],
        subject: 'Re: Status update',
        body: '.first line\nsecond line',
        replyMode: 'reply',
        contextSummary: ''
      };

      const mime = buildQqReplyMime(args, 'me@qq.com');
      expect(mime.indexOf('In-Reply-To: <message-777@example.com>')).assertLarger(-1);
      const result = await client.sendReply(args);
      expect(result.status).assertEqual('success');
      expect(smtp.sent[0]).assertEqual('connect:smtp.qq.com:465');
      expect(smtp.sent.indexOf('AUTH LOGIN')).assertLarger(-1);
      expect(smtp.sent.indexOf('RCPT TO:<alice@example.com>')).assertLarger(-1);
      const data = smtp.sent.filter((value: string) => value.indexOf('Content-Transfer-Encoding: base64') >= 0)[0];
      expect(data.length).assertLarger(0);
      expect(smtp.sent[smtp.sent.length - 1]).assertEqual('close');
    });
  });
}
