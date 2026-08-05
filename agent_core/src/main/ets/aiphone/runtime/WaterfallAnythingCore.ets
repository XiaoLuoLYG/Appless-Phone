export type WaterfallMediaType = 'video' | 'image_text' | 'post';

export interface WaterfallCandidate {
  id: string;
  source: string;
  mediaType: WaterfallMediaType;
  title: string;
  summary: string;
  url: string;
  coverUrl: string;
  publishedAt: string;
  originalIndex: number;
}

export interface WaterfallRankSignals {
  relevanceTier: number;
  titleHits: number;
  summaryHits: number;
  freshnessTier: number;
}

export interface WaterfallRankedCandidate extends WaterfallCandidate {
  normalizedUrl: string;
  signals: WaterfallRankSignals;
  reason: string;
}

export interface WaterfallOrderInput {
  query: string;
  candidates: WaterfallCandidate[];
  enabledSources: string[];
  shownIds: string[];
  stableIds: string[];
  preferenceDescription: string;
}

interface RankedCandidateInternal {
  candidate: WaterfallCandidate;
  normalizedUrl: string;
  signals: WaterfallRankSignals;
}

interface CandidateText {
  title: string;
  summary: string;
}

function normalizedText(value: string): string {
  return value.trim().toLowerCase();
}

function queryTokens(query: string): string[] {
  const clean = normalizedText(query).replace(/[\s,，。！？!?:：；;、/\\()[\]{}"“”‘’]+/g, ' ').trim();
  if (clean.length === 0) {
    return [];
  }
  const tokens: string[] = [];
  clean.split(' ').forEach((token: string) => {
    if (token.length > 0 && tokens.indexOf(token) < 0) {
      tokens.push(token);
    }
  });
  return tokens;
}

function textForCandidate(candidate: WaterfallCandidate): CandidateText {
  return {
    title: normalizedText(candidate.title),
    summary: normalizedText(candidate.summary)
  };
}

function tokenHits(tokens: string[], value: string): number {
  let hits = 0;
  tokens.forEach((token: string) => {
    if (value.indexOf(token) >= 0) {
      hits += 1;
    }
  });
  return hits;
}

function relevanceSignals(query: string, candidate: WaterfallCandidate): WaterfallRankSignals {
  const phrase = normalizedText(query);
  const tokens = queryTokens(query);
  const text = textForCandidate(candidate);
  const titleHits = tokenHits(tokens, text.title);
  const summaryHits = tokenHits(tokens, text.summary);
  const phraseHit = phrase.length > 0 && (text.title.indexOf(phrase) >= 0 || text.summary.indexOf(phrase) >= 0);
  const allTokensHit = tokens.length > 0 && titleHits + summaryHits >= tokens.length;
  const anyTokenHit = titleHits + summaryHits > 0;
  return {
    relevanceTier: phraseHit || allTokensHit ? 3 : (anyTokenHit ? 2 : 1),
    titleHits: titleHits,
    summaryHits: summaryHits,
    freshnessTier: 0
  };
}

function freshnessTier(publishedAt: string, nowMs: number): number {
  const parsed = Date.parse(publishedAt.trim());
  if (!Number.isFinite(parsed) || parsed > nowMs) {
    return 0;
  }
  const ageMs = nowMs - parsed;
  if (ageMs <= 24 * 60 * 60 * 1000) {
    return 4;
  }
  if (ageMs <= 7 * 24 * 60 * 60 * 1000) {
    return 3;
  }
  if (ageMs <= 30 * 24 * 60 * 60 * 1000) {
    return 2;
  }
  return 1;
}

function normalizedHttpUrl(value: string): string {
  let url = value.trim();
  const lower = url.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    return '';
  }
  const fragment = url.indexOf('#');
  if (fragment >= 0) {
    url = url.substring(0, fragment);
  }
  const schemeEnd = url.indexOf('://');
  if (schemeEnd < 0) {
    return '';
  }
  const authorityStart = schemeEnd + 3;
  let authorityEnd = url.length;
  const slash = url.indexOf('/', authorityStart);
  const question = url.indexOf('?', authorityStart);
  if (slash >= 0 && slash < authorityEnd) {
    authorityEnd = slash;
  }
  if (question >= 0 && question < authorityEnd) {
    authorityEnd = question;
  }
  const authority = url.substring(authorityStart, authorityEnd).toLowerCase();
  if (authority.length === 0) {
    return '';
  }
  return lower.substring(0, schemeEnd) + '://' + authority + url.substring(authorityEnd);
}

function qualityCompare(left: RankedCandidateInternal, right: RankedCandidateInternal): number {
  if (left.signals.relevanceTier !== right.signals.relevanceTier) {
    return right.signals.relevanceTier - left.signals.relevanceTier;
  }
  if (left.signals.freshnessTier !== right.signals.freshnessTier) {
    return right.signals.freshnessTier - left.signals.freshnessTier;
  }
  if (left.signals.titleHits !== right.signals.titleHits) {
    return right.signals.titleHits - left.signals.titleHits;
  }
  if (left.signals.summaryHits !== right.signals.summaryHits) {
    return right.signals.summaryHits - left.signals.summaryHits;
  }
  return left.candidate.originalIndex - right.candidate.originalIndex;
}

function sourceCount(sourceCounts: string[], source: string): number {
  let count = 0;
  sourceCounts.forEach((item: string) => {
    if (item === source) {
      count += 1;
    }
  });
  return count;
}

function appendSource(sourceCounts: string[], source: string): void {
  sourceCounts.push(source);
}

function balancedCompare(
  left: RankedCandidateInternal,
  right: RankedCandidateInternal,
  sourceCounts: string[]
): number {
  if (left.signals.relevanceTier !== right.signals.relevanceTier) {
    return right.signals.relevanceTier - left.signals.relevanceTier;
  }
  const leftSourceCount = sourceCount(sourceCounts, left.candidate.source);
  const rightSourceCount = sourceCount(sourceCounts, right.candidate.source);
  if (leftSourceCount !== rightSourceCount) {
    return leftSourceCount - rightSourceCount;
  }
  return qualityCompare(left, right);
}

function reasonFor(signals: WaterfallRankSignals): string {
  const parts: string[] = [];
  if (signals.titleHits > 0) {
    parts.push('标题命中查询');
  } else if (signals.summaryHits > 0) {
    parts.push('摘要命中查询');
  } else {
    parts.push('相关内容');
  }
  if (signals.freshnessTier === 4) {
    parts.push('24 小时内发布');
  } else if (signals.freshnessTier === 3) {
    parts.push('7 天内发布');
  } else if (signals.freshnessTier === 2) {
    parts.push('30 天内发布');
  }
  return parts.slice(0, 2).join(' · ');
}

function hasId(ids: string[], id: string): boolean {
  return ids.indexOf(id) >= 0;
}

function bestDuplicate(
  current: RankedCandidateInternal,
  next: RankedCandidateInternal
): RankedCandidateInternal {
  return qualityCompare(current, next) <= 0 ? current : next;
}

export function rankWaterfallCandidates(
  input: WaterfallOrderInput,
  nowMs: number
): WaterfallRankedCandidate[] {
  const enabled = input.enabledSources;
  const internal: RankedCandidateInternal[] = [];
  input.candidates.forEach((candidate: WaterfallCandidate) => {
    if (enabled.indexOf(candidate.source) < 0 || hasId(input.shownIds, candidate.id)) {
      return;
    }
    const normalizedUrl = normalizedHttpUrl(candidate.url);
    if (normalizedUrl.length === 0) {
      return;
    }
    const signals = relevanceSignals(input.query, candidate);
    signals.freshnessTier = freshnessTier(candidate.publishedAt, nowMs);
    const ranked: RankedCandidateInternal = {
      candidate: candidate,
      normalizedUrl: normalizedUrl,
      signals: signals
    };
    let duplicateIndex = -1;
    for (let index = 0; index < internal.length; index++) {
      if (internal[index].normalizedUrl === normalizedUrl) {
        duplicateIndex = index;
        break;
      }
    }
    if (duplicateIndex < 0) {
      internal.push(ranked);
    } else {
      internal[duplicateIndex] = bestDuplicate(internal[duplicateIndex], ranked);
    }
  });

  const sourceCounts: string[] = [];
  input.candidates.forEach((candidate: WaterfallCandidate) => {
    if (hasId(input.shownIds, candidate.id) || hasId(input.stableIds, candidate.id)) {
      sourceCounts.push(candidate.source);
    }
  });
  const ordered: WaterfallRankedCandidate[] = [];
  while (internal.length > 0) {
    let bestIndex = 0;
    for (let index = 1; index < internal.length; index++) {
      if (balancedCompare(internal[index], internal[bestIndex], sourceCounts) < 0) {
        bestIndex = index;
      }
    }
    const best = internal.splice(bestIndex, 1)[0];
    ordered.push({
      id: best.candidate.id,
      source: best.candidate.source,
      mediaType: best.candidate.mediaType,
      title: best.candidate.title,
      summary: best.candidate.summary,
      url: best.candidate.url,
      coverUrl: best.candidate.coverUrl,
      publishedAt: best.candidate.publishedAt,
      originalIndex: best.candidate.originalIndex,
      normalizedUrl: best.normalizedUrl,
      signals: best.signals,
      reason: reasonFor(best.signals)
    });
    appendSource(sourceCounts, best.candidate.source);
  }
  return ordered;
}
