import { describe, it, expect } from '@ohos/hypium';
import { DynamicGenericToolResult } from '@loop/agent-core';
import { GmailDraftPreview, GmailThreadPreview } from '@loop/agent-core';
import {
  compactPreviewText,
  draftReplyResultFromPreview,
  mailThreadRowsFromPreviews,
  redactEmailAddress
} from '@loop/agent-core';

function gmailThread(): GmailThreadPreview {
  return {
    id: 'thread_fixture_1',
    subject: 'Project launch notes',
    from: 'alice@example.com',
    participants: ['alice@example.com', 'user@example.com'],
    snippet: 'Alice shared the latest project launch notes and asked for confirmation.',
    fullBody: 'FULL BODY SHOULD NOT LEAK. Private detailed body.',
    labels: ['INBOX', 'IMPORTANT'],
    unread: true,
    important: true,
    receivedAt: '2026-06-23T09:15:00Z',
    sourceUrl: 'https://mail.google.com/mail/u/0/#inbox/thread_fixture_1'
  };
}

function gmailDraft(): GmailDraftPreview {
  return {
    id: 'draft_fixture_1',
    targetThreadId: 'thread_fixture_1',
    to: ['alice@example.com'],
    subject: 'Re: Project launch notes',
    body: 'Thanks Alice. FULL BODY SHOULD NOT LEAK.',
    status: 'ready_to_apply'
  };
}

function rowValue(result: DynamicGenericToolResult, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value;
    }
  }
  expect(false).assertTrue();
  return '';
}

function expectNoLeak(result: DynamicGenericToolResult, forbidden: string): void {
  expect(result.summary.indexOf(forbidden)).assertEqual(-1);
  expect(result.rawPreview.indexOf(forbidden)).assertEqual(-1);
  for (let index = 0; index < result.rows.length; index++) {
    expect(result.rows[index].value.indexOf(forbidden)).assertEqual(-1);
  }
}

export default function gmailToolNormalizerTest() {
  describe('gmailToolNormalizer', () => {
    it('maps Gmail thread previews into safe generic result rows', 0, () => {
      const results: DynamicGenericToolResult[] = mailThreadRowsFromPreviews([gmailThread()] as GmailThreadPreview[]);
      const first: DynamicGenericToolResult = results[0];
      const rawPreview = JSON.parse(first.rawPreview) as Record<string, Object>;

      expect(results.length).assertEqual(1);
      expect(first.sourceTag).assertEqual('Gmail Preview');
      expect(first.toolName).assertEqual('gmail.mail.search');
      expect(first.title).assertEqual('Project launch notes');
      expect(first.status).assertEqual('success');
      expect(rowValue(first, 'From')).assertEqual('a***@example.com');
      expect(rowValue(first, 'Labels')).assertEqual('INBOX, IMPORTANT');
      expectNoLeak(first, 'FULL BODY SHOULD NOT LEAK');
      expectNoLeak(first, 'Private detailed body');
      expect(Object.keys(rawPreview).indexOf('fullBody')).assertEqual(-1);
      expect(Object.keys(rawPreview).indexOf('body')).assertEqual(-1);
    });

    it('redacts addresses and compacts snippets deterministically', 0, () => {
      expect(redactEmailAddress('alice@example.com')).assertEqual('a***@example.com');
      expect(redactEmailAddress('not an email')).assertEqual('not an email');
      expect(compactPreviewText('Before   after\nwith several extra words', 18)).assertEqual('Before after with ...');
    });

    it('maps draft previews without reporting send success or leaking body text', 0, () => {
      const result: DynamicGenericToolResult = draftReplyResultFromPreview(gmailDraft());
      const rawPreview = JSON.parse(result.rawPreview) as Record<string, Object>;

      expect(result.toolName).assertEqual('gmail.draft.create');
      expect(result.status).assertEqual('draft');
      expect(result.summary.indexOf('has not been sent')).assertLarger(-1);
      expect(result.summary.indexOf('success')).assertEqual(-1);
      expect(rowValue(result, 'Status')).assertEqual('ready_to_apply');
      expectNoLeak(result, 'FULL BODY SHOULD NOT LEAK');
      expectNoLeak(result, 'Thanks Alice');
      expect(Object.keys(rawPreview).indexOf('body')).assertEqual(-1);
      expect(Object.keys(rawPreview).indexOf('sent')).assertEqual(-1);
      expect(rawPreview['status'] as string).assertEqual('ready_to_apply');
    });
  });
}
