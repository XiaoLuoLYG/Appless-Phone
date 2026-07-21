import { DynamicGenericToolResult } from './DynamicToolTypes';
import { GmailDraftPreview, GmailThreadPreview } from './GmailToolTypes';
import { MailProviderStatus, MailThreadResult } from './MailToolTypes';

type GmailProviderJsonValue = Object | string | number | boolean | null | undefined;

export interface GmailThreadSummary extends MailThreadResult {
  requestKey: string;
}

export interface GmailSearchStructuredData {
  threads: GmailThreadSummary[];
  statuses: MailProviderStatus[];
  extras: DynamicGenericToolResult[];
}

function providerText(value: GmailProviderJsonValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value.trim();
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function providerField(record: Record<string, GmailProviderJsonValue>, names: string[]): string {
  for (let index = 0; index < names.length; index++) {
    const value = providerText(record[names[index]]);
    if (value.length > 0) {
      return value;
    }
  }
  return '';
}

function providerNestedField(record: Record<string, GmailProviderJsonValue>, names: string[]): string {
  const direct = providerField(record, names);
  if (direct.length > 0) {
    return direct;
  }
  for (let index = 0; index < names.length; index++) {
    const value = record[names[index]];
    if (value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value)) {
      const nested = value as Record<string, GmailProviderJsonValue>;
      const text = providerField(nested, ['email', 'address', 'name', 'displayName', 'display_name', 'value', 'id']);
      if (text.length > 0) {
        return text;
      }
    }
  }
  return '';
}

function providerStringList(value: GmailProviderJsonValue): string[] {
  const values: string[] = [];
  if (Array.isArray(value)) {
    value.forEach((item: GmailProviderJsonValue) => {
      const text = providerText(item);
      if (text.length > 0) {
        values.push(text);
      } else if (item !== null && item !== undefined && typeof item === 'object') {
        const nested = item as Record<string, GmailProviderJsonValue>;
        const nestedText = providerField(nested, ['email', 'address', 'name', 'displayName', 'value']);
        if (nestedText.length > 0) {
          values.push(nestedText);
        }
      }
    });
    return values;
  }
  const text = providerText(value);
  if (text.length > 0) {
    text.split(',').forEach((item: string) => {
      if (item.trim().length > 0) {
        values.push(item.trim());
      }
    });
  }
  return values;
}

function providerBoolean(record: Record<string, GmailProviderJsonValue>, names: string[]): boolean {
  for (let index = 0; index < names.length; index++) {
    const value = record[names[index]];
    if (typeof value === 'boolean') {
      return value;
    }
    const text = providerText(value).toLowerCase();
    if (text === 'true' || text === '1' || text === 'yes') {
      return true;
    }
  }
  return false;
}

function collectProviderObjects(value: GmailProviderJsonValue, records: Object[], depth: number): void {
  if (records.length >= 20 || depth > 6 || value === undefined || value === null) {
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item: GmailProviderJsonValue) => {
      if (records.length < 20 && item !== undefined && item !== null && typeof item === 'object') {
        records.push(item as Object);
      }
    });
    return;
  }
  if (typeof value !== 'object') {
    return;
  }
  const record = value as Record<string, GmailProviderJsonValue>;
  if (providerField(record, ['threadId', 'thread_id', 'threadID']).length > 0) {
    records.push(value as Object);
    return;
  }
  const arrays = ['threads', 'messages', 'emails', 'mails', 'items', 'results'];
  for (let index = 0; index < arrays.length; index++) {
    const child = record[arrays[index]];
    if (Array.isArray(child)) {
      collectProviderObjects(child, records, depth + 1);
      if (records.length > 0) {
        return;
      }
    }
  }
  const nested = ['data', 'result', 'response', 'response_data'];
  for (let index = 0; index < nested.length; index++) {
    collectProviderObjects(record[nested[index]], records, depth + 1);
    if (records.length > 0) {
      return;
    }
  }
}

function providerRecords(rawPreview: string): Object[] {
  const records: Object[] = [];
  if (rawPreview.trim().length === 0) {
    return records;
  }
  try {
    collectProviderObjects(JSON.parse(rawPreview) as GmailProviderJsonValue, records, 0);
  } catch (_error) {
  }
  return records;
}

function providerReference(record: Record<string, GmailProviderJsonValue>): string {
  const value = record['rawProviderRef'];
  const text = providerText(value);
  if (text.length > 0) {
    return text;
  }
  if (value !== undefined && value !== null && typeof value === 'object') {
    return JSON.stringify(value);
  }
  return '';
}

function providerThread(record: Object): GmailThreadSummary | null {
  const row = record as Record<string, GmailProviderJsonValue>;
  const threadId = providerField(row, ['threadId', 'thread_id', 'threadID', 'id']);
  if (threadId.length === 0) {
    return null;
  }
  const from = providerNestedField(row, ['from', 'sender', 'author']);
  let toValue = row['to'];
  if (toValue === undefined) {
    toValue = row['recipients'] === undefined ? row['recipient'] : row['recipients'];
  }
  const to = providerStringList(toValue);
  let participants = providerStringList(row['participants']);
  if (participants.length === 0) {
    participants = [];
    if (from.length > 0) {
      participants.push(from);
    }
    to.forEach((recipient: string) => participants.push(recipient));
  }
  const provider = providerField(row, ['provider']);
  return {
    provider: provider.length > 0 ? provider : 'gmail',
    accountLabel: providerField(row, ['accountLabel', 'account_label', 'account']),
    threadId: threadId,
    messageId: providerField(row, ['messageId', 'message_id', 'messageID']),
    subject: providerField(row, ['subject', 'title', 'name']),
    from: from,
    to: to,
    participants: participants,
    snippet: providerField(row, ['snippet', 'preview', 'summary', 'description', 'text', 'message', 'messageText', 'message_text']),
    receivedAt: providerField(row, [
      'receivedAt', 'received_at', 'receivedDateTime', 'date', 'internalDate',
      'createdAt', 'created_at', 'updatedAt', 'updated_at'
    ]),
    unread: providerBoolean(row, ['unread', 'isUnread', 'is_unread']),
    important: providerBoolean(row, ['important', 'isImportant', 'is_important']),
    sourceUrl: providerField(row, ['sourceUrl', 'source_url', 'webUrl', 'web_url']),
    rawProviderRef: providerReference(row),
    requestKey: 'gmail:' + threadId
  };
}

export function gmailSearchStructuredDataFromResults(results: DynamicGenericToolResult[]): GmailSearchStructuredData {
  const threads: GmailThreadSummary[] = [];
  const statuses: MailProviderStatus[] = [];
  const extras: DynamicGenericToolResult[] = [];
  results.forEach((result: DynamicGenericToolResult) => {
    let added = false;
    if (result.status === 'success') {
      providerRecords(result.rawPreview).forEach((record: Object) => {
        const thread = providerThread(record);
        if (thread !== null) {
          threads.push(thread);
          added = true;
        }
      });
    }
    if (!added) {
      extras.push(result);
      if (result.status !== 'success' && result.status !== 'empty') {
        statuses.push({
          provider: 'gmail',
          status: result.status,
          title: result.title,
          message: result.summary
        });
      }
    }
  });
  return { threads: threads, statuses: statuses, extras: extras };
}

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
