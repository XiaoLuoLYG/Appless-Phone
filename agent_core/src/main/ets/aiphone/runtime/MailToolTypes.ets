import { DynamicGenericToolResult } from './DynamicToolTypes';

export interface MailThreadResult {
  provider: string;
  accountLabel: string;
  threadId: string;
  messageId: string;
  subject: string;
  from: string;
  to: string[];
  participants: string[];
  snippet: string;
  receivedAt: string;
  unread: boolean;
  important: boolean;
  sourceUrl: string;
  rawProviderRef: string;
}

export interface MailProviderStatus {
  provider: string;
  status: string;
  title: string;
  message: string;
}

export interface MailSearchArgs {
  query: string;
  pageSize: number;
  providers: string[];
  intentSummary: string;
}

export interface MailDetailRequest {
  requestKey: string;
  provider: string;
  threadId: string;
  messageId: string;
  subject: string;
}

export interface MailDetail {
  requestKey: string;
  provider: string;
  threadId: string;
  messageId: string;
  internetMessageId?: string;
  subject: string;
  from: string;
  replyTo: string;
  to: string[];
  cc: string[];
  bodyText: string;
  bodyHtml: string;
}

export interface MailDraftArgs {
  provider: string;
  accountLabel: string;
  threadId: string;
  messageId: string;
  internetMessageId?: string;
  to: string[];
  subject: string;
  body: string;
  replyMode: string;
  contextSummary: string;
}

export interface MailReplyCommand extends MailDraftArgs {
  requestKey: string;
}

export interface MailReplyOperationResult {
  requestKey: string;
  operation: string;
  provider: string;
  status: string;
  message: string;
}

export interface MailProvider {
  search(args: MailSearchArgs): Promise<MailThreadResult[]>;
  createDraft(args: MailDraftArgs): Promise<DynamicGenericToolResult>;
}
