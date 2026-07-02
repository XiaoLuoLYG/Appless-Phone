import { DynamicGenericToolResult } from './DynamicToolTypes';
import { GmailDraftPreview, GmailThreadPreview } from './GmailToolTypes';

function booleanLabel(value: boolean): string {
  return value ? 'true' : 'false';
}

function redactEmailAddresses(values: string[]): string {
  const redacted: string[] = [];
  for (let index = 0; index < values.length; index++) {
    redacted.push(redactEmailAddress(values[index]));
  }
  return redacted.join(', ');
}

export function redactEmailAddress(email: string): string {
  const atIndex = email.indexOf('@');
  if (atIndex <= 0 || atIndex === email.length - 1) {
    return email;
  }
  const local = email.substring(0, atIndex);
  const domain = email.substring(atIndex + 1);
  if (local.length === 0 || domain.length === 0 || domain.indexOf('.') < 0) {
    return email;
  }
  return local.substring(0, 1) + '***@' + domain;
}

export function compactPreviewText(value: string, maxChars: number = 120): string {
  const safeSnippet = value
    .replace(/\s+/g, ' ')
    .trim();

  if (maxChars <= 0 || safeSnippet.length <= maxChars) {
    return safeSnippet;
  }
  return safeSnippet.substring(0, maxChars) + '...';
}

export function mailThreadRowsFromPreviews(threads: GmailThreadPreview[]): DynamicGenericToolResult[] {
  const results: DynamicGenericToolResult[] = [];
  for (let index = 0; index < threads.length; index++) {
    const thread = threads[index];
    const redactedSender = redactEmailAddress(thread.from);
    const safeSnippet = compactPreviewText(thread.snippet);

    results.push({
      sourceTag: 'Gmail Preview',
      toolName: 'gmail.mail.search',
      title: thread.subject,
      status: 'success',
      summary: 'From ' + redactedSender + ': ' + safeSnippet,
      rows: [
        { label: 'From', value: redactedSender },
        { label: 'Participants', value: redactEmailAddresses(thread.participants) },
        { label: 'Received', value: thread.receivedAt },
        { label: 'Labels', value: thread.labels.join(', ') },
        { label: 'Unread', value: booleanLabel(thread.unread) },
        { label: 'Important', value: booleanLabel(thread.important) },
        { label: 'Source', value: thread.sourceUrl }
      ],
      rawPreview: JSON.stringify({
        id: thread.id,
        subject: thread.subject,
        from: redactedSender,
        participants: redactEmailAddresses(thread.participants),
        snippet: safeSnippet,
        labels: thread.labels,
        unread: thread.unread,
        important: thread.important,
        receivedAt: thread.receivedAt,
        sourceUrl: thread.sourceUrl
      })
    });
  }
  return results;
}

export function draftReplyResultFromPreview(draft: GmailDraftPreview): DynamicGenericToolResult {
  return {
    sourceTag: 'Gmail Draft · Local preview',
    toolName: 'gmail.draft.create',
    title: draft.subject,
    status: 'draft',
    summary: 'Draft prepared for review. It has not been sent.',
    rows: [
      { label: 'To', value: redactEmailAddresses(draft.to) },
      { label: 'Thread', value: draft.targetThreadId },
      { label: 'Preview', value: 'Draft body withheld from generic preview.' },
      { label: 'Status', value: draft.status }
    ],
    rawPreview: JSON.stringify({
      id: draft.id,
      targetThreadId: draft.targetThreadId,
      to: redactEmailAddresses(draft.to),
      subject: draft.subject,
      status: draft.status
    })
  };
}
