import { describe, it, expect } from '@ohos/hypium';
import { genericToolResults } from '@loop/agent-core';
import { parseA2uiJsonl } from '@loop/agent-core';
import { A2uiSurfaceStore } from '@loop/agent-core';
import {
  mailReplyDraftAction,
  mailResultsA2ui,
  mailSearchStructuredDataA2ui,
  mailThreadSummary
} from '@loop/agent-core';
import { MailProviderStatus, MailThreadResult } from '@loop/agent-core';
import { DynamicGenericToolResult } from '@loop/agent-core';

function surfaceFromJsonl(jsonl: string): A2uiSurfaceStore {
  const parsed = parseA2uiJsonl(jsonl);
  const store = new A2uiSurfaceStore();
  expect(parsed.error).assertEqual('');
  parsed.envelopes.forEach(envelope => store.apply(envelope));
  return store;
}

function thread(provider: string, receivedAt: string, subject: string): MailThreadResult {
  return {
    provider: provider,
    accountLabel: provider === 'gmail' ? 'g***@gmail.com' : 'q***@qq.com',
    threadId: provider + '-thread',
    messageId: provider + '-message',
    subject: subject,
    from: 'Alice Example <alice@example.com>',
    to: ['me@example.com'],
    participants: ['alice@example.com', 'me@example.com'],
    snippet: 'Short real snippet',
    receivedAt: receivedAt,
    unread: false,
    important: true,
    sourceUrl: '',
    rawProviderRef: provider + '-ref'
  };
}

export default function mailToolA2uiTest() {
  describe('mailToolA2ui', () => {
    it('renders mixed Gmail and QQ rows sorted by received time', 0, () => {
      const store = surfaceFromJsonl(mailResultsA2ui('mail_surface', 'mail.search', [
        thread('gmail', '2026-06-29T08:00:00+08:00', 'Older Gmail'),
        thread('qq', '2026-06-30T09:00:00+08:00', 'Newer QQ')
      ], []));
      const rows = genericToolResults(store.getSurface());

      expect(rows.length).assertEqual(2);
      expect(rows[0].sourceTag).assertEqual('QQ Mail');
      expect(rows[0].title).assertEqual('Newer QQ');
      expect(rows[1].sourceTag).assertEqual('Gmail');
      expect(rows[1].title).assertEqual('Older Gmail');
      expect(store.getSurface().dataModelJson.indexOf('Short real snippet')).assertLarger(-1);
      expect(store.getSurface().dataModelJson.indexOf('raw body')).assertEqual(-1);
    });

    it('keeps provider status cards before long mail result lists', 0, () => {
      const status: MailProviderStatus = {
        provider: 'gmail',
        status: 'error',
        title: 'Gmail 调用失败',
        message: 'Gmail API timeout'
      };
      const store = surfaceFromJsonl(mailResultsA2ui('mail_surface', 'mail.search', [
        thread('qq', '2026-06-30T09:00:00+08:00', 'QQ thread')
      ], [status]));
      const rows = genericToolResults(store.getSurface());

      expect(rows.length).assertEqual(2);
      expect(rows[0].sourceTag).assertEqual('Gmail');
      expect(rows[0].toolName).assertEqual('mail.provider.status');
      expect(rows[1].sourceTag).assertEqual('QQ Mail');
      expect(rows[1].toolName).assertEqual('mail.thread');
    });

    it('hides successful provider status cards from aggregate mail results', 0, () => {
      const status: MailProviderStatus = {
        provider: 'gmail',
        status: 'success',
        title: 'Composio Gmail 结果',
        message: 'Composio 已执行 GMAIL_LIST_THREADS。'
      };
      const store = surfaceFromJsonl(mailResultsA2ui('mail_surface', 'mail.search', [
        thread('qq', '2026-06-30T09:00:00+08:00', 'QQ thread')
      ], [status]));
      const rows = genericToolResults(store.getSurface());

      expect(rows.length).assertEqual(1);
      expect(rows[0].sourceTag).assertEqual('QQ Mail');
      expect(store.getSurface().dataModelJson.indexOf('Composio Gmail 结果')).assertEqual(-1);
    });

    it('keeps failed Composio Gmail provider status in the old mail wording', 0, () => {
      const status: MailProviderStatus = {
        provider: 'gmail',
        status: 'error',
        title: 'Composio Gmail 结果',
        message: 'Composio 搜索工具失败：Operation timeout'
      };
      const store = surfaceFromJsonl(mailResultsA2ui('mail_surface', 'mail.search', [], [status]));
      const rows = genericToolResults(store.getSurface());

      expect(rows.length).assertEqual(1);
      expect(rows[0].sourceTag).assertEqual('Gmail');
      expect(rows[0].title).assertEqual('Gmail 调用失败');
      expect(store.getSurface().dataModelJson.indexOf('Composio Gmail 结果')).assertEqual(-1);
    });

    it('keeps Outlook Composio extras in aggregate mail results', 0, () => {
      const outlook: DynamicGenericToolResult = {
        sourceTag: 'Composio',
        toolName: 'OUTLOOK_SEARCH_MESSAGES',
        title: 'Composio Outlook 结果',
        status: 'success',
        summary: 'Composio 已执行 OUTLOOK_SEARCH_MESSAGES，返回 1 条可展示结果。',
        rows: [
          { label: '执行工具', value: 'OUTLOOK_SEARCH_MESSAGES' },
          { label: 'AIPhoneDemo follow-up', value: 'Product Team | https://outlook.office.com/mail/id/1' }
        ],
        rawPreview: 'outlook'
      };
      const store = surfaceFromJsonl(mailResultsA2ui('mail_surface', 'mail.search', [
        thread('gmail', '2026-06-29T08:00:00+08:00', 'Gmail thread')
      ], [], [outlook]));
      const rows = genericToolResults(store.getSurface());

      expect(rows.length).assertEqual(2);
      expect(rows[1].title).assertEqual('Composio Outlook 结果');
      expect(rows[1].toolName).assertEqual('OUTLOOK_SEARCH_MESSAGES');
    });

    it('adapts Composio Gmail extras into normal aggregate mail cards', 0, () => {
      const gmail: DynamicGenericToolResult = {
        sourceTag: 'Composio Gmail',
        toolName: 'gmail.mail.search',
        title: 'Composio Gmail 结果',
        status: 'success',
        summary: 'Composio 已执行 GMAIL_LIST_THREADS，返回 1 条可展示结果。',
        rows: [{ label: '结果数量', value: '1' }],
        rawPreview: '{"data":{"threads":[{"id":"thread-composio-1","subject":"Important Gmail thread","from":"Alice <alice@example.com>","date":"Wed, 8 Jul 2026 09:00:00 +0800","snippet":"Short Gmail snippet."}]}}'
      };
      const store = surfaceFromJsonl(mailResultsA2ui('mail_surface', 'mail.search', [
        thread('qq', '2026-06-30T09:00:00+08:00', 'QQ thread')
      ], [], [gmail]));
      const rows = genericToolResults(store.getSurface());

      expect(rows.length).assertEqual(2);
      expect(rows[0].sourceTag).assertEqual('QQ Mail');
      expect(rows[1].sourceTag).assertEqual('Gmail API');
      expect(rows[1].toolName).assertEqual('users.threads.get');
      expect(rows[1].title).assertEqual('Important Gmail thread');
      expect(rows[1].summary).assertEqual('Short Gmail snippet.');
    });

    it('hides Gmail search summary cards from aggregate mail results', 0, () => {
      const summary: DynamicGenericToolResult = {
        sourceTag: 'Gmail API',
        toolName: 'users.threads.list',
        title: 'Gmail 搜索条件',
        status: 'success',
        summary: '已使用真实 Gmail API 搜索邮件线程；下面展示匹配结果。',
        rows: [{ label: 'Query', value: 'newer_than:30d' }],
        rawPreview: 'query=newer_than:30d returned=1 resultSize=1'
      };
      const store = surfaceFromJsonl(mailResultsA2ui('mail_surface', 'mail.search', [
        thread('qq', '2026-06-30T09:00:00+08:00', 'QQ thread')
      ], [], [summary]));
      const rows = genericToolResults(store.getSurface());

      expect(rows.length).assertEqual(1);
      expect(rows[0].sourceTag).assertEqual('QQ Mail');
      expect(rows[0].title).assertEqual('QQ thread');
    });

    it('builds provider-aware reply draft actions', 0, () => {
      const store = surfaceFromJsonl(mailResultsA2ui('mail_surface', 'mail.search', [
        thread('qq', '2026-06-30T09:00:00+08:00', 'QQ thread')
      ], []));
      const action = mailReplyDraftAction(genericToolResults(store.getSurface())[0]);

      expect(action !== null).assertTrue();
      if (action !== null) {
        expect(action.id).assertEqual('mail.ai.reply.draft');
        expect(action.label).assertEqual('AI 回复草稿');
        expect(action.prompt.indexOf('mail.draft.create')).assertLarger(-1);
        expect(action.prompt.indexOf('gmail.message.send')).assertEqual(-1);
        expect(action.prompt.indexOf('"provider":"qq"')).assertLarger(-1);
        expect(action.prompt.indexOf('"messageId":"qq-message"')).assertLarger(-1);
      }
    });

    it('renders the same aggregate mail data from one structured object', 0, () => {
      const source = thread('qq', '2026-06-30T09:00:00+08:00', 'QQ structured thread');
      const status: MailProviderStatus = {
        provider: 'gmail', status: 'error', title: 'Gmail 调用失败', message: 'transport timeout'
      };
      const oldRows = genericToolResults(surfaceFromJsonl(
        mailResultsA2ui('mail_old', 'mail.search', [source], [status])
      ).getSurface());
      const newRows = genericToolResults(surfaceFromJsonl(mailSearchStructuredDataA2ui(
        'mail_new',
        'mail.search',
        { threads: [mailThreadSummary(source)], statuses: [status], extras: [] }
      )).getSurface());

      expect(JSON.stringify(newRows)).assertEqual(JSON.stringify(oldRows));
      expect(mailThreadSummary(source).requestKey).assertEqual('qq:qq-message');
      const action = mailReplyDraftAction(newRows[1]);
      expect(action !== null).assertTrue();
      if (action !== null) {
        expect(JSON.stringify(action.args).indexOf('qq-message')).assertLarger(-1);
      }
    });
  });
}
