import {
  A2uiObservationDigest,
  A2uiSurfaceState,
  ActionExecutionResult,
  AgentMessage,
  InputUserPayload,
  LeaderBimContextUpdate,
  LeaderBimDashboardItem,
  LeaderBimSuggestion,
  LeaderPlanner,
  LeaderPlannerResult,
  LeaderPlanningContext,
  LeaderPlanningSignal,
  LocalModel,
  UserInputPayload,
  aiLogInfo,
  calendarDateFromPrompt,
  emptyA2uiSurface,
  extractJsonObjects,
  summarizeAppliedA2uiSurface
} from '@loop/agent-core';
import {
  BimContextSnapshot,
  BimLifecycleUpdate,
  BimLifecycleState,
  BimRecord,
  BimRetrievalIndex,
  BimStore,
  isValidBimSurfaceJson
} from './BimStore';

const MAX_BIM_SEMANTIC_CANDIDATES: number = 6;
const MAX_BIM_ROUTE_PROMPT_CHARS: number = 12000;
const MAX_BIM_EXECUTION_PROMPT_CHARS: number = 32000;
const MAX_PROMPT_INDEX_VALUE_CHARS: number = 48;
const WEEKLY_LIFECYCLE_SWEEP_MS: number = 7 * 24 * 60 * 60 * 1000;

export type BimRouteStatus = 'none' | 'matched' | 'ambiguous' | 'unknown';

export interface BimRouteDecision {
  status: BimRouteStatus;
  primaryBimId: string;
  secondaryBimIds: string[];
  reason: string;
}

export type BimSurfaceDestination = 'reject' | 'home' | 'detail';

export interface BimPageActionPresentation {
  destination: BimSurfaceDestination;
  appendAssistantMessage: boolean;
}

export interface BimPageActionAdmission {
  accepted: boolean;
  prepareVirtualHome: boolean;
}

export function refreshedSelectedBimRecord(
  selectedBimId: string,
  records: BimRecord[]
): BimRecord | null {
  for (let index = 0; index < records.length; index++) {
    if (records[index].id === selectedBimId) return records[index];
  }
  return null;
}

export function selectedBimRecordForRender(
  selectedBimId: string,
  snapshot: BimRecord | null
): BimRecord | null {
  return snapshot !== null && snapshot.id === selectedBimId ? snapshot : null;
}

export function bimDetailRenderKey(recordId: string, renderTick: number): string {
  return recordId + '-' + renderTick.toString();
}

export function bimContextUpdateForSave(
  record: BimRecord,
  surfaceJson: string,
  update: LeaderBimContextUpdate | undefined
): LeaderBimContextUpdate | undefined {
  if (update !== undefined) {
    try {
      const current = JSON.parse(record.contextJson) as BimContextSnapshot;
      if (current.dashboardItems !== undefined && update.dashboardItems === undefined) return undefined;
    } catch (_error) {
      return undefined;
    }
    return update;
  }
  if (surfaceJson === record.surfaceJson || !isValidBimSurfaceJson(surfaceJson)) return undefined;
  try {
    const surface = JSON.parse(surfaceJson) as A2uiSurfaceState;
    const context = JSON.parse(record.contextJson) as BimContextSnapshot;
    if (surface.status !== 'ready' || surface.error.length > 0 ||
      typeof context.summary !== 'string' ||
      !Array.isArray(context.facts) ||
      !Array.isArray(context.constraints) ||
      !Array.isArray(context.decisions)) {
      return undefined;
    }
    const preserved: LeaderBimContextUpdate = {
      summary: context.summary,
      facts: context.facts.slice(),
      constraints: context.constraints.slice(),
      decisions: context.decisions.slice(),
      entities: record.retrievalIndex.entities.slice(),
      timeAnchors: record.retrievalIndex.timeAnchors.slice(),
      locations: record.retrievalIndex.locations.slice(),
      commitments: record.retrievalIndex.commitments.slice(),
      keywords: record.retrievalIndex.keywords.slice()
    };
    if (context.dashboardItems !== undefined) {
      preserved.dashboardItems = context.dashboardItems.map(
        (item: LeaderBimDashboardItem): LeaderBimDashboardItem => ({
          kind: item.kind,
          title: item.title,
          value: item.value,
          detail: item.detail,
          status: item.status
        })
      );
    }
    return preserved;
  } catch (_error) {
    return undefined;
  }
}

export function initialBimContextForNewBim(
  outcomeSurfaceId: string,
  currentSurface: A2uiSurfaceState,
  suggestion: LeaderBimSuggestion,
  initialUpdate?: LeaderBimContextUpdate
): BimContextSnapshot {
  if (initialUpdate !== undefined) {
    const context: BimContextSnapshot = {
      summary: initialUpdate.summary,
      facts: initialUpdate.facts.slice(),
      constraints: initialUpdate.constraints.slice(),
      decisions: initialUpdate.decisions.slice()
    };
    if (initialUpdate.dashboardItems !== undefined) {
      context.dashboardItems = initialUpdate.dashboardItems.map(
        (item: LeaderBimDashboardItem): LeaderBimDashboardItem => ({
          kind: item.kind,
          title: item.title,
          value: item.value,
          detail: item.detail,
          status: item.status
        })
      );
    }
    return context;
  }
  const facts: string[] = [];
  if (outcomeSurfaceId.length > 0 && outcomeSurfaceId === currentSurface.surfaceId) {
    const digest = summarizeAppliedA2uiSurface('', currentSurface).text.trim().substring(0, 240);
    if (digest.length > 0) {
      facts.push(digest);
    }
  }
  return {
    summary: suggestion.title.trim() + '：' + suggestion.summary.trim(),
    facts,
    constraints: [],
    decisions: []
  };
}

export function bimRememberFailureMessage(localError: string): string {
  const message = localError.trim();
  return message.length > 0 ? message : '心上事保存失败';
}

export function surfaceForNewBim(
  outcomeSurfaceId: string,
  currentSurface: A2uiSurfaceState,
  suggestion: LeaderBimSuggestion
): string {
  if (outcomeSurfaceId.length > 0 && outcomeSurfaceId === currentSurface.surfaceId) {
    return JSON.stringify(currentSurface);
  }
  const surface = emptyA2uiSurface('surface_bim_suggestion');
  surface.title = suggestion.title;
  surface.intent = 'bim';
  surface.status = 'ready';
  surface.components = [
    { id: 'root', component: 'SurfaceRoot', child: 'summary' },
    { id: 'summary', component: 'Text', text: suggestion.summary }
  ];
  return JSON.stringify(surface);
}

export function bimTurnOwnsTransientState(ownerGeneration: number, turnGeneration: number): boolean {
  return ownerGeneration === turnGeneration;
}

export function bimSurfaceDestination(
  callbackIsCurrent: boolean,
  activeBimId: string,
  turnStartedInDetail: boolean
): BimSurfaceDestination {
  if (!callbackIsCurrent) return 'reject';
  return activeBimId.length > 0 && turnStartedInDetail ? 'detail' : 'home';
}

export function bimPageActionPresentation(
  callbackIsCurrent: boolean,
  activeBimId: string,
  turnStartedInDetail: boolean
): BimPageActionPresentation {
  const destination = bimSurfaceDestination(callbackIsCurrent, activeBimId, turnStartedInDetail);
  return {
    destination,
    appendAssistantMessage: destination === 'home'
  };
}

export function shouldPrepareVirtualPageAction(
  callbackIsCurrent: boolean,
  transientOwnerGeneration: number,
  actionGeneration: number,
  activeBimId: string,
  turnStartedInDetail: boolean
): boolean {
  if (!callbackIsCurrent) {
    return false;
  }
  const ownedActiveBimId = bimTurnOwnsTransientState(
    transientOwnerGeneration, actionGeneration
  ) ? activeBimId : '';
  return bimPageActionPresentation(
    true, ownedActiveBimId, turnStartedInDetail
  ).destination === 'home';
}

export function bimPageActionAdmission(
  activeRuntimeIsMultiAgent: boolean,
  originHostGeneration: number | undefined,
  currentHostGeneration: number,
  transientOwnerGeneration: number,
  activeBimId: string,
  turnStartedInDetail: boolean
): BimPageActionAdmission {
  const originIsValid = originHostGeneration !== undefined &&
    Number.isSafeInteger(originHostGeneration) && originHostGeneration > 0;
  const currentIsValid = Number.isSafeInteger(currentHostGeneration) && currentHostGeneration > 0;
  const accepted = activeRuntimeIsMultiAgent && originIsValid && currentIsValid &&
    originHostGeneration === currentHostGeneration;
  return {
    accepted,
    prepareVirtualHome: accepted && shouldPrepareVirtualPageAction(
      true,
      transientOwnerGeneration,
      currentHostGeneration,
      activeBimId,
      turnStartedInDetail
    )
  };
}

export async function runBimPageActionWithAdmission(
  admission: BimPageActionAdmission,
  prepareVirtualHome: () => void,
  execute: () => Promise<ActionExecutionResult>
): Promise<ActionExecutionResult> {
  if (!admission.accepted) {
    return {
      status: 'error',
      errorCode: 'BIM_PAGE_ACTION_GENERATION_STALE',
      message: 'Page action no longer belongs to the current turn.'
    };
  }
  if (admission.prepareVirtualHome) {
    prepareVirtualHome();
  }
  return execute();
}

interface BimRouteState {
  route: Promise<BimRouteDecision>;
  settledAt: number;
}

export function bimGateWaitMs(
  routeSettledBeforePlanner: boolean,
  plannedSettledAt: number,
  routeSettledAt: number
): number {
  return routeSettledBeforePlanner ? 0 : Math.max(1, routeSettledAt - plannedSettledAt);
}

export class BimTurnGate {
  private readonly routes: Map<number, BimRouteState> = new Map<number, BimRouteState>();
  private readonly turnGenerations: Map<string, number> = new Map<string, number>();

  begin(hostGeneration: number, route: Promise<BimRouteDecision>): void {
    const state: BimRouteState = { route, settledAt: 0 };
    this.routes.set(hostGeneration, state);
    route.then(
      (): void => {
        state.settledAt = Date.now();
      },
      (): void => {
        state.settledAt = Date.now();
      }
    );
  }

  bind(turnId: string, hostGeneration: number): void {
    this.turnGenerations.set(turnId, hostGeneration);
  }

  routeFor(turnId: string): Promise<BimRouteDecision> | null {
    const hostGeneration: number | undefined = this.turnGenerations.get(turnId);
    if (hostGeneration === undefined) return null;
    const state: BimRouteState | undefined = this.routes.get(hostGeneration);
    return state === undefined ? null : state.route;
  }

  routeSettledAtFor(turnId: string): number {
    const hostGeneration: number | undefined = this.turnGenerations.get(turnId);
    if (hostGeneration === undefined) return 0;
    const state: BimRouteState | undefined = this.routes.get(hostGeneration);
    return state === undefined ? 0 : state.settledAt;
  }

  clear(hostGeneration: number): void {
    this.routes.delete(hostGeneration);
    this.turnGenerations.forEach((generation: number, turnId: string): void => {
      if (generation === hostGeneration) this.turnGenerations.delete(turnId);
    });
  }
}

export class BimGatedLeaderPlanner implements LeaderPlanner {
  private readonly inner: LeaderPlanner;
  private readonly gate: BimTurnGate;
  private readonly logInfo: (message: string) => void;

  constructor(inner: LeaderPlanner, gate: BimTurnGate, logInfo?: (message: string) => void) {
    this.inner = inner;
    this.gate = gate;
    this.logInfo = logInfo === undefined ? aiLogInfo : logInfo;
  }

  async plan(
    message: AgentMessage,
    input: InputUserPayload,
    context: LeaderPlanningContext,
    round?: number,
    signal?: LeaderPlanningSignal,
    currentLocalDate?: string
  ): Promise<LeaderPlannerResult> {
    let plannedSettledAt: number = 0;
    let routeSettledBeforePlanner: boolean = false;
    const planned: Promise<LeaderPlannerResult> =
      this.inner.plan(message, input, context, round, signal, currentLocalDate);
    const recordPlannedSettlement = (): void => {
      routeSettledBeforePlanner = this.gate.routeSettledAtFor(message.turnId) !== 0;
      plannedSettledAt = Date.now();
    };
    planned.then(recordPlannedSettlement, recordPlannedSettlement);
    planned.catch((): void => {});
    const route: Promise<BimRouteDecision> | null = this.gate.routeFor(message.turnId);
    if (route === null) return planned;
    const decision: BimRouteDecision = await route;
    const waitMs: number = bimGateWaitMs(
      plannedSettledAt === 0 || routeSettledBeforePlanner,
      plannedSettledAt,
      this.gate.routeSettledAtFor(message.turnId)
    );
    this.logInfo('[AIPhone][BimGate] toolGateWaitMs=' + waitMs.toString());
    if (decision.status !== 'none') {
      throw new Error('BIM_MAIN_TURN_NOT_ADMITTED');
    }
    return planned;
  }
}

interface RankedBimRecord {
  record: BimRecord;
  score: number;
  updatedAt: number;
}

interface BimRoutePromptCandidate {
  id: string;
  title: string;
  lifecycle: BimLifecycleState;
  retrievalIndex: BimRetrievalIndex;
}

interface BimExecutionPrimary {
  id: string;
  title: string;
  contextJson: string;
  appliedSurfaceDigest: A2uiObservationDigest;
}

interface BimExecutionSecondary {
  id: string;
  title: string;
  retrievalIndex: BimRetrievalIndex;
}

interface BimExecutionContext {
  primary: BimExecutionPrimary;
  secondary: BimExecutionSecondary[];
  query: string;
}

function normalized(value: string): string {
  return value.toLowerCase().replace(/\s+/g, '');
}

function includesExact(query: string, values: string[]): boolean {
  for (let index = 0; index < values.length; index++) {
    const value = normalized(values[index]);
    if (value.length > 0 && query.indexOf(value) >= 0) return true;
  }
  return false;
}

function includesSubstring(query: string, values: string[]): boolean {
  for (let index = 0; index < values.length; index++) {
    const value = normalized(values[index]);
    if (value.length > 0 && (query.indexOf(value) >= 0 || value.indexOf(query) >= 0)) return true;
  }
  return false;
}

function exactWakeValues(record: BimRecord): string[] {
  return [record.title].concat(
    record.retrievalIndex.entities,
    record.retrievalIndex.locations,
    record.retrievalIndex.timeAnchors
  );
}

function candidateScore(query: string, record: BimRecord): number {
  const exactValues: string[] = exactWakeValues(record);
  if (includesExact(query, exactValues)) return 2;
  const index: BimRetrievalIndex = record.retrievalIndex;
  const values: string[] = [record.title].concat(
    index.entities,
    index.timeAnchors,
    index.locations,
    index.commitments,
    index.keywords
  );
  return includesSubstring(query, values) ? 1 : 0;
}

function truncated(values: string[], count: number): string[] {
  return values.slice(0, count).map((value: string): string => value.substring(0, MAX_PROMPT_INDEX_VALUE_CHARS));
}

export function compactBimRetrievalIndexForPrompt(index: BimRetrievalIndex): BimRetrievalIndex {
  return {
    summary: index.summary,
    entities: truncated(index.entities, 4),
    timeAnchors: truncated(index.timeAnchors, 4),
    locations: truncated(index.locations, 4),
    commitments: truncated(index.commitments, 4),
    keywords: truncated(index.keywords, 8)
  };
}

function parsedPersistedSurface(record: BimRecord): A2uiSurfaceState {
  if (!isValidBimSurfaceJson(record.surfaceJson)) {
    throw new Error('BIM_SURFACE_INVALID');
  }
  try {
    return JSON.parse(record.surfaceJson) as A2uiSurfaceState;
  } catch (_error) {
    throw new Error('BIM_SURFACE_INVALID');
  }
}

export function buildBimExecutionPrompt(
  primary: BimRecord,
  secondary: BimRecord[],
  query: string
): string {
  const surface = parsedPersistedSurface(primary);
  const secondaryContext: BimExecutionSecondary[] = secondary.map(
    (record: BimRecord): BimExecutionSecondary => ({
      id: record.id,
      title: record.title,
      retrievalIndex: compactBimRetrievalIndexForPrompt(record.retrievalIndex)
    })
  );
  const context: BimExecutionContext = {
    primary: {
      id: primary.id,
      title: primary.title,
      contextJson: primary.contextJson,
      appliedSurfaceDigest: summarizeAppliedA2uiSurface('', surface)
    },
    secondary: secondaryContext,
    query
  };
  const prompt = '[BIM_CONTEXT]\n' +
    'Continue the primary matter using its semantic context and applied Surface digest. ' +
    'BIM state is separate from Persona Memory; never call memory.update for a BIM update. ' +
    'Changing matter state such as participants, room preferences, dates, budgets, constraints, or decisions ' +
    'is not by itself a search or business-tool request. For a state-only change, answer without capabilities ' +
    'and return the complete updated bimContextUpdate. Call a business tool only when the user explicitly asks ' +
    'to search, read, or execute it. ' +
    'Preserve still-valid sections, preserve new user constraints verbatim when safe, replace superseded results, ' +
    'and return bimContextUpdate in the terminal decision. dashboardItems must contain only the latest state, ' +
    'using generic progress, metric, person, timeline, task, hotel, flight, transport, or event items. ' +
    'Replace reversed people and metrics in place. Use hotel, flight, transport, or event cards only after the ' +
    'user explicitly says they are confirmed or a real provider confirms them; never save search candidates.\n' +
    'For travel, flight, or train searches, put a self-contained query in dataTasks[].input.query with dates, ' +
    'route, and other constraints resolved from this BIM context.\n' +
    JSON.stringify(context);
  if (prompt.length > MAX_BIM_EXECUTION_PROMPT_CHARS) {
    throw new Error('BIM_CONTEXT_LIMIT');
  }
  return prompt;
}

export function originalQueryFromBimPrompt(prompt: string): string {
  if (prompt.indexOf('[BIM_CONTEXT]\n') !== 0) return prompt;
  const contextStart = prompt.lastIndexOf('\n{"primary":');
  if (contextStart < 0) return prompt;
  try {
    const context = JSON.parse(prompt.substring(contextStart + 1)) as BimExecutionContext;
    return typeof context.query === 'string' && context.query.trim().length > 0 ?
      context.query : prompt;
  } catch (_error) {
    return prompt;
  }
}

export function buildBimAgentInput(primary: BimRecord, query: string): UserInputPayload {
  const surface = parsedPersistedSurface(primary);
  return {
    text: query,
    recentMessages: [],
    previousPersonaId: '',
    currentSurfaceSummary: {
      surfaceId: surface.surfaceId,
      kind: surface.intent,
      status: surface.status,
      entityRefs: [],
      actionOfferIds: []
    },
    recentObservations: []
  };
}

export function bimTravelQueryNeedsDetails(query: string): boolean {
  const value = query.trim().toLowerCase();
  const asksTravel = value.indexOf('机票') >= 0 || value.indexOf('航班') >= 0 ||
    value.indexOf('飞机') >= 0 || value.indexOf('高铁') >= 0 || value.indexOf('火车') >= 0 ||
    value.indexOf('flight') >= 0 || value.indexOf('train') >= 0;
  const asksSearch = /查|搜|找|看|search|find/.test(value);
  return asksTravel && asksSearch && !bimTravelQueryIsComplete(value);
}

export function bimTravelQueryIsComplete(query: string, now: Date = new Date()): boolean {
  const value = query.trim();
  const from = value.indexOf('从');
  const to = value.indexOf('到');
  const flightNumber = /\b[A-Z0-9]{2,3}\d{1,4}\b/i.exec(value);
  const hasFlightNumber = flightNumber !== null && /[A-Z]/i.test(flightNumber[0]);
  return ((from >= 0 && to > from) || hasFlightNumber) &&
    calendarDateFromPrompt(value, now).length > 0;
}

// ponytail: O(n) over at most 100 local matters and six semantic candidates; add an indexed store only after device measurements show need.
export function localBimCandidates(query: string, records: BimRecord[]): BimRecord[] {
  const normalizedQuery: string = normalized(query);
  if (normalizedQuery.length === 0) return [];
  const ranked: RankedBimRecord[] = [];
  for (let index = 0; index < records.length; index++) {
    const record: BimRecord = records[index];
    if (record.lifecycle === 'ended') continue;
    const score: number = candidateScore(normalizedQuery, record);
    if (score === 0 || (record.lifecycle === 'tucked' && !includesExact(normalizedQuery, exactWakeValues(record)))) {
      continue;
    }
    const candidate: RankedBimRecord = { record, score, updatedAt: new Date(record.updatedAt).getTime() };
    let insertAt: number = ranked.length;
    for (let position = 0; position < ranked.length; position++) {
      const current: RankedBimRecord = ranked[position];
      if (candidate.score > current.score ||
        (candidate.score === current.score && candidate.updatedAt > current.updatedAt)) {
        insertAt = position;
        break;
      }
    }
    if (insertAt < MAX_BIM_SEMANTIC_CANDIDATES) ranked.splice(insertAt, 0, candidate);
    if (ranked.length > MAX_BIM_SEMANTIC_CANDIDATES) ranked.pop();
  }
  return ranked.map((item: RankedBimRecord): BimRecord => item.record);
}

function unknownDecision(): BimRouteDecision {
  return { status: 'unknown', primaryBimId: '', secondaryBimIds: [], reason: '' };
}

function routePrompt(query: string, records: BimRecord[]): string {
  const candidates: BimRoutePromptCandidate[] = records.map((record: BimRecord): BimRoutePromptCandidate => ({
    id: record.id,
    title: record.title,
    lifecycle: record.lifecycle,
    retrievalIndex: compactBimRetrievalIndexForPrompt(record.retrievalIndex)
  }));
  return 'Choose the relevant local matter for the query. Return one JSON object only with ' +
    'status (none|matched|ambiguous), primaryBimId, secondaryBimIds, and a short reason. ' +
    'A query is relevant when it updates, checks, or takes an action to further the matter; ' +
    'for example, a hotel, flight, restaurant, ticket, or schedule request for an existing trip remains relevant ' +
    'even when that specific result is not stored yet. ' +
    'Use only candidate IDs. matched requires one primary; none has no IDs; ambiguous has two to six secondary IDs.\n' +
    JSON.stringify({ query, candidates });
}

function validOutputShape(value: Object): boolean {
  return Object.keys(value).sort().join(',') === 'primaryBimId,reason,secondaryBimIds,status';
}

function validReason(value: Object | string | number | boolean | null): boolean {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= 240;
}

function outputIds(value: Object | string | number | boolean | null): string[] | null {
  if (!Array.isArray(value)) return null;
  const ids: string[] = [];
  const rawIds: string[] = value as string[];
  for (let index = 0; index < rawIds.length; index++) {
    const id: string = rawIds[index];
    if (typeof id !== 'string' || id.trim().length === 0 || ids.indexOf(id) >= 0) return null;
    ids.push(id);
  }
  return ids;
}

function parseRouteDecision(raw: string, candidates: BimRecord[]): BimRouteDecision {
  try {
    const objects: string[] = extractJsonObjects(raw);
    if (objects.length !== 1) return unknownDecision();
    const parsed: Object = JSON.parse(objects[0]) as Object;
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed) || !validOutputShape(parsed)) {
      return unknownDecision();
    }
    const value: Record<string, Object | string | number | boolean | null> =
      parsed as Record<string, Object | string | number | boolean | null>;
    const status: string = value['status'] as string;
    const primary: Object | string | number | boolean | null = value['primaryBimId'];
    const secondary: string[] | null = outputIds(value['secondaryBimIds']);
    if (typeof status !== 'string' ||
      (status !== 'none' && status !== 'matched' && status !== 'ambiguous') ||
      typeof primary !== 'string' || secondary === null || !validReason(value['reason'])) {
      return unknownDecision();
    }
    const reason: string = value['reason'] as string;
    const candidateIds: string[] = candidates.map((candidate: BimRecord): string => candidate.id);
    if ((primary.length > 0 && candidateIds.indexOf(primary) < 0) ||
      secondary.some((id: string): boolean => candidateIds.indexOf(id) < 0 || id === primary)) {
      return unknownDecision();
    }
    if (status === 'none' && primary.length === 0 && secondary.length === 0) {
      return { status, primaryBimId: primary, secondaryBimIds: secondary, reason };
    }
    if (status === 'matched' && primary.length > 0) {
      return { status, primaryBimId: primary, secondaryBimIds: secondary, reason };
    }
    if (status === 'ambiguous' && primary.length === 0 && secondary.length >= 2 &&
      secondary.length <= MAX_BIM_SEMANTIC_CANDIDATES) {
      return { status, primaryBimId: primary, secondaryBimIds: secondary, reason };
    }
  } catch (_error) {
    return unknownDecision();
  }
  return unknownDecision();
}

function logRoute(startedAt: number, candidates: number, semantic: boolean, status: BimRouteStatus): void {
  aiLogInfo('[AIPhone][BimRoute] routeMs=' + Math.max(0, Date.now() - startedAt).toString() +
    ' candidates=' + candidates.toString() + ' semantic=' + (semantic ? 'true' : 'false') + ' status=' + status);
}

export async function routeBimQuery(
  query: string,
  records: BimRecord[],
  model: LocalModel
): Promise<BimRouteDecision> {
  const startedAt: number = Date.now();
  const localCandidates: BimRecord[] = localBimCandidates(query, records);
  if (localCandidates.length === 0) {
    const decision: BimRouteDecision = { status: 'none', primaryBimId: '', secondaryBimIds: [], reason: '' };
    logRoute(startedAt, 0, false, decision.status);
    return decision;
  }
  const semanticCandidates: BimRecord[] = localCandidates.slice(0, MAX_BIM_SEMANTIC_CANDIDATES);
  const prompt: string = routePrompt(query, semanticCandidates);
  if (prompt.length > MAX_BIM_ROUTE_PROMPT_CHARS) {
    const decision: BimRouteDecision = unknownDecision();
    logRoute(startedAt, semanticCandidates.length, false, decision.status);
    return decision;
  }
  let decision: BimRouteDecision = unknownDecision();
  try {
    decision = parseRouteDecision(await model.complete(prompt), semanticCandidates);
  } catch (_error) {
    decision = unknownDecision();
  }
  logRoute(startedAt, semanticCandidates.length, true, decision.status);
  return decision;
}

export interface BimLifecycleDecision {
  id: string;
  lifecycle: 'active' | 'quiet' | 'tucked';
  reason: string;
}

export interface BimLifecycleSweepResult {
  ok: boolean;
  decisions: BimLifecycleDecision[];
}

interface BimLifecyclePromptCandidate {
  id: string;
  title: string;
  lifecycle: 'active' | 'quiet' | 'tucked';
  retrievalIndex: BimRetrievalIndex;
  lastInteractionAt: string;
  lastLifecycleCheckAt: string;
}

function timestampMs(value: string): number {
  if (typeof value !== 'string' || value.length === 0) return -1;
  const parsed: number = new Date(value).getTime();
  return isNaN(parsed) ? -1 : parsed;
}

function isActiveBimLifecycle(value: Object | string | number | boolean | null): boolean {
  return value === 'active' || value === 'quiet' || value === 'tucked';
}

function lifecyclePrompt(candidates: BimRecord[]): string {
  const items: BimLifecyclePromptCandidate[] = [];
  for (let index = 0; index < candidates.length; index++) {
    const record = candidates[index];
    if (!isActiveBimLifecycle(record.lifecycle)) continue;
    items.push({
      id: record.id,
      title: record.title,
      lifecycle: record.lifecycle as 'active' | 'quiet' | 'tucked',
      retrievalIndex: record.retrievalIndex,
      lastInteractionAt: record.lastInteractionAt,
      lastLifecycleCheckAt: record.lastLifecycleCheckAt
    });
  }
  return 'Judge only the local matter lifecycle. Return one JSON array only; every item must have ' +
    'id, lifecycle (active|quiet|tucked), and a short reason. Do not end matters, call tools, ' +
    'or change context or surfaces. Use only the listed IDs.\n' + JSON.stringify(items);
}

function validLifecycleDecisionShape(value: Object): boolean {
  return Object.keys(value).sort().join(',') === 'id,lifecycle,reason';
}

function parsedLifecycleDecision(raw: Object, candidateIds: string[], seen: string[]): BimLifecycleDecision | null {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw) || !validLifecycleDecisionShape(raw)) {
    return null;
  }
  const value: Record<string, Object | string | number | boolean | null> =
    raw as Record<string, Object | string | number | boolean | null>;
  const id: Object | string | number | boolean | null = value['id'];
  const lifecycle: Object | string | number | boolean | null = value['lifecycle'];
  const reason: Object | string | number | boolean | null = value['reason'];
  if (typeof id !== 'string' || candidateIds.indexOf(id) < 0 || seen.indexOf(id) >= 0 ||
    !isActiveBimLifecycle(lifecycle) || typeof reason !== 'string' ||
    reason.trim().length === 0 || reason.length > 240) {
    return null;
  }
  return { id, lifecycle: lifecycle as 'active' | 'quiet' | 'tucked', reason };
}

export function weeklySweepDue(nowIso: string, lastSweepAt: string): boolean {
  const now: number = timestampMs(nowIso);
  if (now < 0) return false;
  const lastSweep: number = timestampMs(lastSweepAt);
  return lastSweep < 0 || now - lastSweep >= WEEKLY_LIFECYCLE_SWEEP_MS;
}

export function lifecycleSweepCandidates(
  records: BimRecord[], lastSweepAt: string, nowIso: string
): BimRecord[] {
  const lastSweep: number = timestampMs(lastSweepAt);
  const now: number = timestampMs(nowIso);
  if (lastSweep < 0 || now < lastSweep) return [];
  const candidates: BimRecord[] = [];
  for (let index = 0; index < records.length; index++) {
    const record = records[index];
    if (!isActiveBimLifecycle(record.lifecycle)) continue;
    const lastInteraction: number = timestampMs(record.lastInteractionAt);
    if (lastInteraction >= 0 && lastInteraction <= lastSweep) {
      candidates.push(record);
    }
  }
  return candidates;
}

export async function judgeBimLifecycle(
  model: LocalModel, candidates: BimRecord[]
): Promise<BimLifecycleDecision[]> {
  const raw: string = await model.complete(lifecyclePrompt(candidates));
  const parsed: Object = JSON.parse(raw.trim()) as Object;
  if (!Array.isArray(parsed) || parsed.length > candidates.length) {
    throw new Error('BIM_LIFECYCLE_OUTPUT_INVALID');
  }
  const candidateIds: string[] = candidates.map((record: BimRecord): string => record.id);
  const seen: string[] = [];
  const decisions: BimLifecycleDecision[] = [];
  const items: Object[] = parsed as Object[];
  for (let index = 0; index < items.length; index++) {
    const decision: BimLifecycleDecision | null = parsedLifecycleDecision(items[index], candidateIds, seen);
    if (decision === null) throw new Error('BIM_LIFECYCLE_OUTPUT_INVALID');
    seen.push(decision.id);
    decisions.push(decision);
  }
  return decisions;
}

export async function runWeeklyBimLifecycleSweep(
  store: BimStore, model: LocalModel, nowIso: string
): Promise<BimLifecycleSweepResult> {
  try {
    const lastSweepAt: string = store.lastLifecycleSweepAt();
    const candidates: BimRecord[] = lifecycleSweepCandidates(store.list(), lastSweepAt, nowIso);
    if (candidates.length === 0) {
      return { ok: store.applyLifecycleSweep([], nowIso), decisions: [] };
    }
    const decisions: BimLifecycleDecision[] = await judgeBimLifecycle(model, candidates);
    if (store.lastLifecycleSweepAt() !== lastSweepAt) {
      return { ok: false, decisions: [] };
    }
    for (let index = 0; index < candidates.length; index++) {
      const captured: BimRecord = candidates[index];
      const current: BimRecord | undefined = store.get(captured.id);
      if (current === undefined || current.lifecycle !== captured.lifecycle ||
        current.lastInteractionAt !== captured.lastInteractionAt ||
        current.lastLifecycleCheckAt !== captured.lastLifecycleCheckAt ||
        current.updatedAt !== captured.updatedAt) {
        return { ok: false, decisions: [] };
      }
    }
    const updates: BimLifecycleUpdate[] = decisions.map((decision: BimLifecycleDecision): BimLifecycleUpdate => ({
      id: decision.id,
      lifecycle: decision.lifecycle
    }));
    return { ok: store.applyLifecycleSweep(updates, nowIso), decisions };
  } catch (_error) {
    return { ok: false, decisions: [] };
  }
}
