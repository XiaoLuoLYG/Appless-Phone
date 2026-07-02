export interface GmailThreadPreview {
  id: string;
  subject: string;
  from: string;
  participants: string[];
  snippet: string;
  fullBody: string;
  labels: string[];
  unread: boolean;
  important: boolean;
  receivedAt: string;
  sourceUrl: string;
}

export interface GmailDraftPreview {
  id: string;
  targetThreadId: string;
  to: string[];
  subject: string;
  body: string;
  status: string;
}
