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

export type WaterfallContinuationKind = 'cursor' | 'page' | 'offset';

export interface WaterfallContinuation {
  kind: WaterfallContinuationKind;
  value: string;
}

export type WaterfallSourcePhase =
  'loading' | 'success' | 'empty' | 'needs_auth' | 'error' | 'exhausted';

export interface WaterfallSourceState {
  source: string;
  phase: WaterfallSourcePhase;
  continuation: WaterfallContinuation | null;
  inFlight: boolean;
  reservedCount: number;
  message: string;
}

export interface WaterfallFeedState {
  query: string;
  enabledSources: string[];
  preferenceDescription: string;
  shown: WaterfallRankedCandidate[];
  current: WaterfallRankedCandidate | null;
  stable: WaterfallRankedCandidate[];
  tail: WaterfallRankedCandidate[];
  sources: WaterfallSourceState[];
}

export interface WaterfallLoadRequest {
  source: string;
  continuation: WaterfallContinuation;
  limit: number;
}

export interface WaterfallFeedUpdate {
  state: WaterfallFeedState;
  loadRequests: WaterfallLoadRequest[];
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

const WATERFALL_STABLE_LIMIT: number = 2;
const WATERFALL_LOW_WATERMARK: number = 3;
const WATERFALL_TARGET_INVENTORY: number = 8;
const WATERFALL_MAX_REQUEST: number = 5;

function copySourceState(source: WaterfallSourceState): WaterfallSourceState {
  return {
    source: source.source,
    phase: source.phase,
    continuation: source.continuation,
    inFlight: source.inFlight,
    reservedCount: source.reservedCount,
    message: source.message
  };
}

function copySources(sources: WaterfallSourceState[]): WaterfallSourceState[] {
  return sources.map((source: WaterfallSourceState): WaterfallSourceState => copySourceState(source));
}

function copyState(state: WaterfallFeedState): WaterfallFeedState {
  return {
    query: state.query,
    enabledSources: state.enabledSources.slice(),
    preferenceDescription: state.preferenceDescription,
    shown: state.shown.slice(),
    current: state.current,
    stable: state.stable.slice(),
    tail: state.tail.slice(),
    sources: copySources(state.sources)
  };
}

function idsOf(items: WaterfallRankedCandidate[]): string[] {
  return items.map((item: WaterfallRankedCandidate): string => item.id);
}

function addUniqueId(ids: string[], id: string): void {
  if (ids.indexOf(id) < 0) {
    ids.push(id);
  }
}

function fixedDisplayIds(state: WaterfallFeedState): string[] {
  const ids: string[] = state.shown.map((item: WaterfallRankedCandidate): string => item.id);
  if (state.current !== null) {
    addUniqueId(ids, state.current.id);
  }
  state.stable.forEach((item: WaterfallRankedCandidate): void => addUniqueId(ids, item.id));
  return ids;
}

function fixedDisplayUrls(state: WaterfallFeedState): string[] {
  const urls: string[] = state.shown.map((item: WaterfallRankedCandidate): string => item.normalizedUrl);
  if (state.current !== null) {
    urls.push(state.current.normalizedUrl);
  }
  state.stable.forEach((item: WaterfallRankedCandidate): void => {
    urls.push(item.normalizedUrl);
  });
  return urls;
}

function filterEnabled(items: WaterfallRankedCandidate[], enabledSources: string[]): WaterfallRankedCandidate[] {
  return items.filter((item: WaterfallRankedCandidate): boolean => enabledSources.indexOf(item.source) >= 0);
}

function sourceFor(sources: WaterfallSourceState[], source: string): WaterfallSourceState | null {
  for (let index = 0; index < sources.length; index++) {
    if (sources[index].source === source) {
      return sources[index];
    }
  }
  return null;
}

function replaceSource(sources: WaterfallSourceState[], next: WaterfallSourceState): void {
  for (let index = 0; index < sources.length; index++) {
    if (sources[index].source === next.source) {
      sources[index] = next;
      return;
    }
  }
  sources.push(next);
}

function isTerminal(source: WaterfallSourceState): boolean {
  return source.phase === 'empty' || source.phase === 'needs_auth' || source.phase === 'error' || source.phase === 'exhausted';
}

function refreshStableWindow(state: WaterfallFeedState): void {
  while (state.stable.length < WATERFALL_STABLE_LIMIT && state.tail.length > 0) {
    state.stable.push(state.tail.shift() as WaterfallRankedCandidate);
  }
  if (state.stable.length > WATERFALL_STABLE_LIMIT) {
    state.tail = state.stable.splice(WATERFALL_STABLE_LIMIT);
  }
}

function planWaterfallLoads(state: WaterfallFeedState): WaterfallLoadRequest[] {
  const requests: WaterfallLoadRequest[] = [];
  const inventory = state.stable.length + state.tail.length;
  if (inventory > WATERFALL_LOW_WATERMARK) {
    return requests;
  }

  let reserved = 0;
  state.sources.forEach((source: WaterfallSourceState): void => {
    if (state.enabledSources.indexOf(source.source) >= 0) {
      reserved += source.reservedCount;
    }
  });
  let remaining = WATERFALL_TARGET_INVENTORY - inventory - reserved;
  if (remaining <= 0) {
    return requests;
  }

  state.sources.forEach((source: WaterfallSourceState): void => {
    if (remaining <= 0 || state.enabledSources.indexOf(source.source) < 0) {
      return;
    }
    if (source.continuation === null) {
      if (source.phase === 'success') {
        source.phase = 'exhausted';
      }
      return;
    }
    if (source.inFlight || source.phase === 'loading' || isTerminal(source)) {
      return;
    }
    const limit = Math.min(WATERFALL_MAX_REQUEST, remaining);
    requests.push({ source: source.source, continuation: source.continuation, limit: limit });
    source.inFlight = true;
    source.reservedCount += limit;
    remaining -= limit;
  });
  return requests;
}

function finalizeUpdate(state: WaterfallFeedState): WaterfallFeedUpdate {
  return { state: state, loadRequests: planWaterfallLoads(state) };
}

function rankedToCandidates(items: WaterfallRankedCandidate[]): WaterfallCandidate[] {
  return items.map((item: WaterfallRankedCandidate): WaterfallCandidate => ({
    id: item.id,
    source: item.source,
    mediaType: item.mediaType,
    title: item.title,
    summary: item.summary,
    url: item.url,
    coverUrl: item.coverUrl,
    publishedAt: item.publishedAt,
    originalIndex: item.originalIndex
  }));
}

function sortTail(state: WaterfallFeedState, incoming: WaterfallCandidate[], nowMs: number): WaterfallRankedCandidate[] {
  const fixedIds = fixedDisplayIds(state);
  const fixedUrls = fixedDisplayUrls(state);
  const filteredIncoming: WaterfallCandidate[] = incoming.filter((candidate: WaterfallCandidate): boolean => {
    if (fixedIds.indexOf(candidate.id) >= 0) {
      return false;
    }
    return fixedUrls.indexOf(normalizedHttpUrl(candidate.url)) < 0;
  });
  const candidates: WaterfallCandidate[] = rankedToCandidates(state.tail).concat(filteredIncoming);
  return rankWaterfallCandidates({
    query: state.query,
    candidates: candidates,
    enabledSources: state.enabledSources,
    shownIds: fixedIds,
    stableIds: idsOf(state.stable),
    preferenceDescription: state.preferenceDescription
  }, nowMs);
}

function placeInitialBatch(state: WaterfallFeedState, incoming: WaterfallCandidate[], nowMs: number): void {
  const ranked = rankWaterfallCandidates({
    query: state.query,
    candidates: incoming,
    enabledSources: state.enabledSources,
    shownIds: idsOf(state.shown),
    stableIds: [],
    preferenceDescription: state.preferenceDescription
  }, nowMs);
  if (ranked.length === 0) {
    return;
  }
  state.current = ranked.shift() as WaterfallRankedCandidate;
  state.stable = ranked.splice(0, WATERFALL_STABLE_LIMIT);
  state.tail = ranked;
}

export function mergeWaterfallBatch(
  state: WaterfallFeedState,
  incoming: WaterfallCandidate[],
  sourceState: WaterfallSourceState,
  nowMs: number
): WaterfallFeedUpdate {
  return finalizeUpdate(mergeWaterfallBatchState(state, incoming, sourceState, nowMs));
}

function mergeWaterfallBatchState(
  state: WaterfallFeedState,
  incoming: WaterfallCandidate[],
  sourceState: WaterfallSourceState,
  nowMs: number
): WaterfallFeedState {
  const next = copyState(state);
  const received = copySourceState(sourceState);
  received.inFlight = false;
  received.reservedCount = 0;
  replaceSource(next.sources, received);
  if (next.current === null) {
    placeInitialBatch(next, incoming, nowMs);
  } else {
    // ponytail: small feed snapshots use a linear scan; add indexed URLs only if the pool grows materially.
    next.tail = sortTail(next, incoming, nowMs);
    refreshStableWindow(next);
  }
  return next;
}

export function mergeWaterfallFeedSnapshot(
  state: WaterfallFeedState,
  incoming: WaterfallFeedState,
  nowMs: number
): WaterfallFeedUpdate {
  let next = copyState(state);
  const candidates = rankedToCandidates(
    (incoming.current === null ? [] : [incoming.current]).concat(incoming.stable, incoming.tail)
  );
  incoming.sources.forEach((source: WaterfallSourceState): void => {
    next = mergeWaterfallBatchState(
      next,
      candidates.filter((candidate: WaterfallCandidate): boolean => candidate.source === source.source),
      source,
      nowMs
    );
  });
  return finalizeUpdate(next);
}

export function advanceWaterfallFeed(
  state: WaterfallFeedState,
  nowMs: number
): WaterfallFeedUpdate {
  const next = copyState(state);
  if (next.current !== null) {
    next.shown.push(next.current);
  }
  next.current = null;
  if (next.stable.length > 0) {
    next.current = next.stable.shift() as WaterfallRankedCandidate;
  } else if (next.tail.length > 0) {
    next.current = next.tail.shift() as WaterfallRankedCandidate;
  }
  refreshStableWindow(next);
  return finalizeUpdate(next);
}

export function applyWaterfallSourceSelection(
  state: WaterfallFeedState,
  enabledSources: string[],
  nowMs: number
): WaterfallFeedUpdate {
  const next = copyState(state);
  next.enabledSources = enabledSources.slice();
  if (next.current !== null && enabledSources.indexOf(next.current.source) < 0) {
    next.shown.push(next.current);
    next.current = null;
  }
  next.stable = filterEnabled(next.stable, enabledSources);
  next.tail = filterEnabled(next.tail, enabledSources);
  const unshown = rankedToCandidates(next.stable).concat(rankedToCandidates(next.tail));
  const ranked = rankWaterfallCandidates({
    query: next.query,
    candidates: unshown,
    enabledSources: enabledSources,
    shownIds: idsOf(next.shown).concat(next.current === null ? [] : [next.current.id]),
    stableIds: [],
    preferenceDescription: next.preferenceDescription
  }, nowMs);
  next.stable = ranked.splice(0, WATERFALL_STABLE_LIMIT);
  next.tail = ranked;
  if (next.current === null && next.stable.length > 0) {
    next.current = next.stable.shift() as WaterfallRankedCandidate;
  }
  refreshStableWindow(next);
  return finalizeUpdate(next);
}
