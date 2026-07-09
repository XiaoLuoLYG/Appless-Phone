export type AggregateSearchSource = 'youtube' | 'bilibili' | 'x' | 'hackernews' | 'reddit' | 'zhihu';
export type AggregateSearchStatus = 'success' | 'empty' | 'needs_auth' | 'unsupported' | 'error';

export interface AggregateSearchRowData {
  label: string;
  value: string;
}

export interface AggregateSearchSourceStatus {
  source: AggregateSearchSource;
  label: string;
  status: AggregateSearchStatus;
  message: string;
  count: number;
}

export interface AggregateSearchVideo {
  id: string;
  source: AggregateSearchSource;
  provider: string;
  title: string;
  summary: string;
  url: string;
  thumbnail: string;
  publishedAt: string;
  duration: string;
  status: AggregateSearchStatus;
  rows: AggregateSearchRowData[];
}

export interface AggregateSearchPost {
  id: string;
  source: AggregateSearchSource;
  provider: string;
  title: string;
  author: string;
  handle: string;
  text: string;
  url: string;
  publishedAt: string;
  score: string;
  commentCount: string;
  status: AggregateSearchStatus;
  rows: AggregateSearchRowData[];
}

export interface AggregateSearchResult {
  query: string;
  videos: AggregateSearchVideo[];
  posts: AggregateSearchPost[];
  sourceStatuses: AggregateSearchSourceStatus[];
  summary: string;
}

export function emptyAggregateSearchResult(): AggregateSearchResult {
  return {
    query: '',
    videos: [],
    posts: [],
    sourceStatuses: [],
    summary: ''
  };
}

export function aggregateSourceLabel(source: AggregateSearchSource): string {
  if (source === 'youtube') {
    return 'YouTube';
  }
  if (source === 'bilibili') {
    return 'B 站';
  }
  if (source === 'x') {
    return 'X';
  }
  if (source === 'hackernews') {
    return 'HN';
  }
  if (source === 'reddit') {
    return 'Reddit';
  }
  return '知乎';
}
