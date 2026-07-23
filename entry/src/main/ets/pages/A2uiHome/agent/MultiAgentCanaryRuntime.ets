import {
  ActionArgsValidator,
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionOffer,
  ActionPlanRequestPayload,
  ActionValidationResult,
  A2uiAction,
  A2uiSurfaceStore,
  A2uiSurfaceState,
  CalendarEventArgs,
  ClientActionAuthorizer,
  CreateDataTaskPayload,
  CreateUiTaskPayload,
  DataResult,
  DataTaskExecutor,
  DataTaskAuthorizationResult,
  DynamicGenericToolResult,
  InputUserPayload,
  JsonValue,
  LeaderDataTaskInputNormalizer,
  LeaderDecisionDataTask,
  LeaderPlanningContext,
  LeaderToolMetadata,
  LinkedMessageBus,
  LocalModel,
  MailDetail,
  MailDetailRequest,
  RegisteredActionExecutor,
  SurfaceActionAuthorizer,
  ToolDefinition,
  ToolDefinitionLookup,
  UiLayoutPlanner,
  UiRenderResult,
  UiSurfaceWriteLease,
  UiSurfaceWriter,
  UiTaskRenderer,
  UserInputPayload,
  VIRTUAL_ACTION_INTENT_SOURCE_TOOL_ID,
  VirtualActionIntent,
  VirtualActionIntentResolver,
  allToolDefinitions,
  callStructuredTool,
  genericToolResultsA2ui,
  isExplicitLuckinOrderPrompt,
  normalizedCalendarArgsForPrompt,
  parseA2uiJsonl,
  setJsonPointer,
  toolDefinitionForToolId,
  toolPlanningDescriptionForToolId
} from '@loop/agent-core';
import { leaderPersonaContext } from '../../../model/LeaderPersonaContext';
import {
  memoryUpdateSurface,
  parsePersonaMemoryUpdateInput,
  PersonaMemoryUpdateRequest
} from '../../../model/PersonaMemoryUpdate';
import { personaPackForId } from '../../../model/PersonaStore';
import { MultiAgentLeaderPlanner } from './MultiAgentLeaderPlanner';
import { MultiAgentActionPlanCompiler } from './MultiAgentActionPlanCompiler';
import {
  HotelLocalDateProvider,
  normalizeHotelSearchTaskInput
} from './HotelLeaderPlanner';
import { mailDetailIdentityDigest, MultiAgentRuntime } from './MultiAgentRuntime';
import { MIGRATED_TOOL_IDS, MultiAgentTurnOutcome } from './MultiAgentRuntimeTypes';
import { isHtmlHomeActionAllowed } from '../html/HtmlHomeActionPolicy';
import {
  authorizeHotelDataTask,
  HotelRuntimeSurfaceWriter,
  HotelSurfaceAuthority,
  HotelVisibility,
  IgnoreHotelSurfaceWriter,
  MonotonicHotelIds,
  PreparedHotelFollowUpIds
} from './HotelAgentRuntime';
import { StructuredToolUiRenderer } from './StructuredToolUiRenderer';
import {
  AiphoneRegisteredActionExecutor,
  MailDetailFollowUpPreparer,
  RegisteredPageAction,
  SystemUriOpener,
  validateRegisteredPageActionArgs
} from './AiphoneRegisteredActionExecutor';
import {
  RegisteredPageSnapshot,
  registeredPageSourceToolId,
  registeredPageSnapshotFingerprint,
  resolveRegisteredPageAction,
  resolveVirtualRegisteredPageAction
} from './RegisteredPageActionRoute';

const MEMORY_ACTION_ID: string = 'memory.update';
const MEMORY_SUMMARY_LIMIT: number = 240;
const TURN_HOST_GENERATION_LIMIT: number = 32;

interface CalendarReviewOutput {
  surfaceId: string;
}

interface CalendarUpdateRequestArgs extends CalendarEventArgs {
  actionId: string;
}

interface CalendarUpdateSearchArgs {
  query: string;
  date: string;
  timeMin: string;
  timeMax: string;
  timezone: string;
  calendarId: string;
  requestedAction: CalendarUpdateRequestArgs;
}

interface CalendarDeleteRequestArgs {
  actionId: string;
  query: string;
  calendarId: string;
}

interface CalendarDeleteSearchArgs {
  query: string;
  date: string;
  timeMin: string;
  timeMax: string;
  timezone: string;
  calendarId: string;
  requestedAction: CalendarDeleteRequestArgs;
}

interface SocialFeedTaskInput {
  platforms: string[];
}

export interface MultiAgentCanaryOptions {
  model: LocalModel;
  opener: SystemUriOpener;
  pageAction?: RegisteredPageAction;
  currentPageSnapshot?: () => RegisteredPageSnapshot | null;
  currentHostSurface?: () => A2uiSurfaceState | null;
  currentHostGeneration?: () => number;
  onSurface: (surface: A2uiSurfaceState, runtimeGeneration: number) => boolean;
  onMemoryUpdate: (update: PersonaMemoryUpdateRequest, runtimeGeneration: number) => void;
  onMailDetail?: (
    event: MailDetailInPlaceEvent,
    runtimeGeneration: number,
    lease: MailDetailWriteLease
  ) => Promise<void>;
  downstreamWriter?: UiSurfaceWriter;
  uiLayoutPlanner?: UiLayoutPlanner;
  settingsFingerprint?: string;
  submitTimeoutMs?: number;
  actionTimeoutMs?: number;
  currentLocalDate?: HotelLocalDateProvider;
  dataExecutor?: DataTaskExecutor;
  structuredToolCall?: (toolId: string, prompt: string, args: Object) => Promise<DataResult>;
  bus?: LinkedMessageBus;
  conversationId?: string;
}

export interface MailDetailInPlaceEvent {
  requestKey: string;
  provider: string;
  identityDigest: string;
  status: 'success' | 'error';
  detail?: MailDetail;
  error: string;
}

interface PreparedMailDetail {
  request: MailDetailRequest;
  generation: number;
}

interface MailDetailSurfaceState extends PreparedMailDetail {
  uiTaskId: string;
  event: MailDetailInPlaceEvent | null;
  epoch: number;
  canceled: boolean;
}

export interface MailDetailWriteLease {
  isActive(): boolean;
}

const MAIL_DETAIL_STATE_LIMIT: number = 8;

function mailText(value: Object | string | number | boolean | null | undefined): string {
  return typeof value === 'string' ? value : '';
}

function mailStrings(value: Object | string | number | boolean | null | undefined): string[] | null {
  if (!Array.isArray(value)) {
    return null;
  }
  const values = value as (Object | string | number | boolean | null | undefined)[];
  const result: string[] = [];
  for (let index = 0; index < values.length; index++) {
    if (typeof values[index] !== 'string') {
      return null;
    }
    result.push(values[index] as string);
  }
  return result;
}

function mailDetailFromData(
  data: DataResult,
  request: MailDetailRequest
): MailDetailInPlaceEvent {
  const identityDigest = mailDetailIdentityDigest(request);
  const providerError = data.error === undefined ? '' : data.error.message;
  if (data.status === 'error') {
    return {
      requestKey: request.requestKey,
      provider: request.provider,
      identityDigest,
      status: 'error',
      error: providerError.trim().length > 0 ? providerError : '邮件正文读取失败。'
    };
  }
  if (data.status !== 'success' || data.outputSchema !== 'mailThread' ||
    data.data === null || typeof data.data !== 'object' || Array.isArray(data.data)) {
    return {
      requestKey: request.requestKey,
      provider: request.provider,
      identityDigest,
      status: 'error',
      error: '邮件正文数据无效。'
    };
  }
  const values = data.data as Record<string, Object | string | number | boolean | null | undefined>;
  const to = mailStrings(values['to']);
  const cc = mailStrings(values['cc']);
  const body = mailText(values['body']);
  const bodyHtml = mailText(values['bodyHtml']);
  if (mailText(values['requestKey']) !== request.requestKey ||
    mailText(values['provider']) !== request.provider ||
    mailText(values['threadId']) !== request.threadId ||
    mailText(values['messageId']) !== request.messageId ||
    to === null || cc === null || (body.trim().length === 0 && bodyHtml.trim().length === 0)) {
    return {
      requestKey: request.requestKey,
      provider: request.provider,
      identityDigest,
      status: 'error',
      error: '邮件正文身份或内容无效。'
    };
  }
  const detail: MailDetail = {
    requestKey: request.requestKey,
    provider: request.provider,
    threadId: request.threadId,
    messageId: request.messageId,
    internetMessageId: mailText(values['internetMessageId']),
    subject: mailText(values['subject']),
    from: mailText(values['from']),
    replyTo: mailText(values['replyTo']),
    to,
    cc,
    bodyText: body,
    bodyHtml
  };
  return {
    requestKey: request.requestKey,
    provider: request.provider,
    identityDigest,
    status: 'success',
    detail,
    error: ''
  };
}

class MailDetailBridgeLease implements MailDetailWriteLease {
  private readonly active: () => boolean;

  constructor(active: () => boolean) {
    this.active = active;
  }

  isActive(): boolean {
    return this.active();
  }
}

class MailDetailInPlaceBridge implements UiTaskRenderer, UiSurfaceWriter, MailDetailFollowUpPreparer {
  private readonly renderer: UiTaskRenderer;
  private readonly mailRenderer: UiTaskRenderer;
  private readonly writer: UiSurfaceWriter;
  private readonly currentGeneration: () => number;
  private readonly callback: ((
    event: MailDetailInPlaceEvent,
    generation: number,
    lease: MailDetailWriteLease
  ) => Promise<void>) | null;
  private readonly prepared: Map<string, PreparedMailDetail> = new Map<string, PreparedMailDetail>();
  private readonly canceledPrepared: Map<string, PreparedMailDetail> = new Map<string, PreparedMailDetail>();
  private readonly surfaces: Map<string, MailDetailSurfaceState> = new Map<string, MailDetailSurfaceState>();
  private epoch: number = 1;
  private disposed: boolean = false;

  constructor(
    renderer: UiTaskRenderer,
    writer: UiSurfaceWriter,
    currentGeneration: () => number,
    callback?: (
      event: MailDetailInPlaceEvent,
      generation: number,
      lease: MailDetailWriteLease
    ) => Promise<void>
  ) {
    this.renderer = renderer;
    this.mailRenderer = new StructuredToolUiRenderer(null, 6000);
    this.writer = writer;
    this.currentGeneration = currentGeneration;
    this.callback = callback === undefined ? null : callback;
  }

  private stateCount(): number {
    return this.prepared.size + this.canceledPrepared.size + this.surfaces.size;
  }

  private pruneCanceledState(): void {
    while (this.stateCount() >= MAIL_DETAIL_STATE_LIMIT && this.canceledPrepared.size > 0) {
      const first = this.canceledPrepared.keys().next();
      if (first.done) {
        break;
      }
      this.canceledPrepared.delete(first.value);
    }
    if (this.stateCount() < MAIL_DETAIL_STATE_LIMIT) {
      return;
    }
    const entries = this.surfaces.entries();
    let next = entries.next();
    while (!next.done && this.stateCount() >= MAIL_DETAIL_STATE_LIMIT) {
      if (next.value[1].canceled) {
        this.surfaces.delete(next.value[0]);
      }
      next = entries.next();
    }
  }

  prepare(uiTaskId: string, request: MailDetailRequest): boolean {
    const actionId = request.provider === 'gmail' ? 'gmail.thread.read' : 'mail.thread.read';
    const generation = this.currentGeneration();
    this.pruneCanceledState();
    if (this.disposed || this.callback === null || this.stateCount() >= MAIL_DETAIL_STATE_LIMIT ||
      uiTaskId.trim().length === 0 || !Number.isSafeInteger(generation) || generation <= 0 ||
      !validateRegisteredPageActionArgs(actionId, request).ok) {
      return false;
    }
    this.prepared.set(uiTaskId, {
      request: {
        requestKey: request.requestKey,
        provider: request.provider,
        threadId: request.threadId,
        messageId: request.messageId,
        subject: request.subject
      },
      generation
    });
    return true;
  }

  async skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult> {
    const prepared = this.prepared.get(task.taskId);
    const canceled = this.canceledPrepared.get(task.taskId);
    const mailTask = task.dataTaskIds.length === 1 && task.expectedOutputSchema === 'mailThread' &&
      (task.intent === 'mail.thread.read' || task.intent === 'gmail.thread.read');
    if (prepared === undefined && canceled !== undefined && mailTask) {
      this.canceledPrepared.delete(task.taskId);
      this.surfaces.set(surfaceId, {
        uiTaskId: task.taskId,
        request: canceled.request,
        generation: canceled.generation,
        event: null,
        epoch: this.epoch,
        canceled: true
      });
      return this.mailRenderer.skeleton(task, surfaceId);
    }
    if (prepared === undefined || !mailTask ||
      this.disposed) {
      return this.renderer.skeleton(task, surfaceId);
    }
    this.prepared.delete(task.taskId);
    this.surfaces.set(surfaceId, {
      uiTaskId: task.taskId,
      request: prepared.request,
      generation: prepared.generation,
      event: null,
      epoch: this.epoch,
      canceled: false
    });
    return this.mailRenderer.skeleton(task, surfaceId);
  }

  async result(
    task: CreateUiTaskPayload,
    data: DataResult[],
    offers: ActionOffer[],
    surfaceId: string
  ): Promise<UiRenderResult> {
    const state = this.surfaces.get(surfaceId);
    if (state === undefined || state.uiTaskId !== task.taskId) {
      return this.renderer.result(task, data, offers, surfaceId);
    }
    if (data.length !== 1 || data[0].toolId !== task.intent) {
      state.event = {
        requestKey: state.request.requestKey,
        provider: state.request.provider,
        identityDigest: mailDetailIdentityDigest(state.request),
        status: 'error',
        error: '邮件正文结果关联无效。'
      };
      return this.mailRenderer.error(task, state.event.error, surfaceId);
    }
    state.event = mailDetailFromData(data[0], state.request);
    return state.event.status === 'success' ?
      this.mailRenderer.result(task, data, [], surfaceId) :
      this.mailRenderer.error(task, state.event.error, surfaceId);
  }

  async error(task: CreateUiTaskPayload, message: string, surfaceId: string): Promise<UiRenderResult> {
    const state = this.surfaces.get(surfaceId);
    if (state === undefined || state.uiTaskId !== task.taskId) {
      return this.renderer.error(task, message, surfaceId);
    }
    state.event = {
      requestKey: state.request.requestKey,
      provider: state.request.provider,
      identityDigest: mailDetailIdentityDigest(state.request),
      status: 'error',
      error: message.trim().length > 0 ? message : '邮件正文读取失败。'
    };
    return this.mailRenderer.error(task, state.event.error, surfaceId);
  }

  actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult> {
    return this.renderer.actionStatus(payload, surfaceId);
  }

  async write(
    turnId: string,
    surfaceId: string,
    jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void> {
    const state = this.surfaces.get(surfaceId);
    if (state === undefined) {
      if (!lease.isActive()) {
        return;
      }
      return this.writer.write(turnId, surfaceId, jsonl, lease);
    }
    if (state.canceled || state.event === null || !lease.isActive() || this.disposed) {
      if (state.canceled || !lease.isActive() || this.disposed) {
        this.surfaces.delete(surfaceId);
      }
      return;
    }
    const event = state.event;
    if (this.callback === null) {
      throw new Error('Mail detail callback is unavailable.');
    }
    const expectedEpoch = state.epoch;
    const writeLease: MailDetailWriteLease = new MailDetailBridgeLease((): boolean =>
      !this.disposed && this.epoch === expectedEpoch && lease.isActive() &&
        this.surfaces.get(surfaceId) === state && !state.canceled
    );
    try {
      await this.callback(event, state.generation, writeLease);
      if (!writeLease.isActive()) {
        return;
      }
      if (event.status === 'error') {
        throw new Error(event.error);
      }
    } finally {
      if (this.surfaces.get(surfaceId) === state) {
        this.surfaces.delete(surfaceId);
      }
    }
  }

  actionSettled(ok: boolean): void {
    if (ok) {
      this.prepared.clear();
      return;
    }
    this.epoch++;
    this.prepared.forEach((prepared: PreparedMailDetail, taskId: string) => {
      this.canceledPrepared.set(taskId, prepared);
    });
    this.prepared.clear();
    this.surfaces.forEach((surface: MailDetailSurfaceState) => {
      surface.canceled = true;
    });
    this.pruneCanceledState();
  }

  dispose(): void {
    this.disposed = true;
    this.epoch++;
    this.prepared.clear();
    this.canceledPrepared.clear();
    this.surfaces.clear();
  }
}

export interface MultiAgentCanaryActionContext {
  conversationId: string;
  turnId: string;
  surfaceId: string;
  sourceToolId: string;
  pageActionId?: string;
}

function memoryDefinition(): ToolDefinition {
  return {
    toolId: MEMORY_ACTION_ID,
    domain: 'persona',
    intent: MEMORY_ACTION_ID,
    riskLevel: 'draft',
    backendPriority: ['local_adapter'],
    authModes: ['none'],
    inputSchema: 'memoryUpdateRequest',
    outputSchema: 'memoryUpdateResult',
    a2uiComponent: 'InfoRows',
    actions: [MEMORY_ACTION_ID]
  };
}

class CanaryToolLookup implements ToolDefinitionLookup {
  find(toolId: string): ToolDefinition | null {
    if (toolId === MEMORY_ACTION_ID) {
      return memoryDefinition();
    }
    return toolDefinitionForToolId(toolId);
  }
}

class RejectClientAction implements ClientActionAuthorizer {
  allows(_actionId: string, _args: Object): boolean {
    return false;
  }
}

function calendarNow(currentLocalDate: string | undefined): Date | null {
  if (currentLocalDate === undefined || currentLocalDate.length !== 10 ||
    currentLocalDate.charCodeAt(4) !== 45 || currentLocalDate.charCodeAt(7) !== 45) {
    return null;
  }
  const digitIndexes: number[] = [0, 1, 2, 3, 5, 6, 8, 9];
  for (let index = 0; index < digitIndexes.length; index++) {
    const code: number = currentLocalDate.charCodeAt(digitIndexes[index]);
    if (code < 48 || code > 57) {
      return null;
    }
  }
  const year: number = Number(currentLocalDate.substring(0, 4));
  const month: number = Number(currentLocalDate.substring(5, 7));
  const day: number = Number(currentLocalDate.substring(8, 10));
  const utc: Date = new Date(Date.UTC(year, month - 1, day));
  if (year < 2000 || year > 2100 || month < 1 || month > 12 || day < 1 ||
    utc.getUTCFullYear() !== year || utc.getUTCMonth() + 1 !== month || utc.getUTCDate() !== day) {
    return null;
  }
  const timestamp: number = Date.parse(currentLocalDate + 'T00:00:00+08:00');
  return Number.isNaN(timestamp) ? null : new Date(timestamp);
}

function calendarUpdateSearchArgs(input: string, now: Date): CalendarUpdateSearchArgs | null {
  const normalized = normalizedCalendarArgsForPrompt('calendar.event.update', input, {}, now, true);
  const query = normalized.query === undefined ? '' : normalized.query.trim();
  const title = normalized.title === undefined ? '' : normalized.title.trim();
  const start = normalized.start === undefined ? '' : normalized.start.trim();
  if (query.length === 0 || (title.length === 0 && start.length === 0)) {
    return null;
  }
  return {
    query,
    date: normalized.date === undefined ? '' : normalized.date,
    timeMin: normalized.timeMin === undefined ? '' : normalized.timeMin,
    timeMax: normalized.timeMax === undefined ? '' : normalized.timeMax,
    timezone: normalized.timezone === undefined ? '' : normalized.timezone,
    calendarId: normalized.calendarId === undefined ? '' : normalized.calendarId,
    requestedAction: {
      actionId: 'calendar.event.update',
      title,
      start,
      end: normalized.end === undefined ? '' : normalized.end,
      timezone: normalized.timezone === undefined ? '' : normalized.timezone,
      calendarId: normalized.calendarId === undefined ? '' : normalized.calendarId
    }
  };
}

function calendarDeleteSearchArgs(input: string, now: Date): CalendarDeleteSearchArgs | null {
  if (input.indexOf('删除') < 0) {
    return null;
  }
  const titleMatch = /标题为\s*(.+?)\s*的\s*Google\s+Calendar\s*日程/i.exec(input);
  const chineseDate = /(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日/.exec(input);
  const isoDate = /(\d{4})-(\d{1,2})-(\d{1,2})/.exec(input);
  const dateMatch = chineseDate === null ? isoDate : chineseDate;
  if (titleMatch === null || dateMatch === null) {
    return null;
  }
  const title = titleMatch[1].trim();
  const month = Number(dateMatch[2]);
  const day = Number(dateMatch[3]);
  const year = Number(dateMatch[1]);
  const checked = new Date(Date.UTC(year, month - 1, day));
  if (title.length === 0 || title.length > 240 || year < 2000 || year > 2100 ||
    month < 1 || month > 12 || day < 1 ||
    checked.getUTCFullYear() !== year || checked.getUTCMonth() + 1 !== month ||
    checked.getUTCDate() !== day) {
    return null;
  }
  const date = year.toString().padStart(4, '0') + '-' +
    month.toString().padStart(2, '0') + '-' + day.toString().padStart(2, '0');
  const normalized = normalizedCalendarArgsForPrompt('calendar.events.search', input, {
    query: title,
    date,
    timezone: 'Asia/Shanghai',
    calendarId: 'primary'
  }, now);
  return {
    query: title,
    date,
    timeMin: normalized.timeMin === undefined ? '' : normalized.timeMin,
    timeMax: normalized.timeMax === undefined ? '' : normalized.timeMax,
    timezone: normalized.timezone === undefined ? '' : normalized.timezone,
    calendarId: normalized.calendarId === undefined ? 'primary' : normalized.calendarId,
    requestedAction: {
      actionId: 'calendar.event.delete',
      query: title,
      calendarId: normalized.calendarId === undefined ? 'primary' : normalized.calendarId
    }
  };
}

function unwrapSingleArgsEnvelope(input: Object): Object {
  const source = input as Record<string, Object | string | number | boolean | null | undefined>;
  const keys = Object.keys(source);
  if (keys.length !== 1 || keys[0] !== 'args') {
    return input;
  }
  const args = source['args'];
  return args !== null && args !== undefined && typeof args === 'object' && !Array.isArray(args) ?
    args as Object : input;
}

function normalizedSocialFeedTaskInput(input: Object): Object {
  const source = input as Record<string, Object | string | number | boolean | null | undefined>;
  const keys = Object.keys(source);
  const raw: Object | string | number | boolean | null | undefined = source['platforms'];
  if (keys.length !== 1 || keys[0] !== 'platforms' || !Array.isArray(raw) || raw.length === 0) {
    throw new Error('SOCIAL_FEED_PLATFORMS_INVALID');
  }
  const rawPlatforms: Object[] = raw as Object[];
  const allowed: string[] = ['x', 'slack', 'wecom', 'discord', 'linkedin', 'whatsapp', 'instagram', 'all'];
  const platforms: string[] = [];
  for (let index = 0; index < rawPlatforms.length; index++) {
    const value: Object = rawPlatforms[index];
    if (typeof value !== 'string') {
      throw new Error('SOCIAL_FEED_PLATFORMS_INVALID');
    }
    const platform = value.trim().toLowerCase();
    if (allowed.indexOf(platform) < 0 || platforms.indexOf(platform) >= 0) {
      throw new Error('SOCIAL_FEED_PLATFORMS_INVALID');
    }
    platforms.push(platform);
  }
  if (platforms.indexOf('all') >= 0 && platforms.length !== 1) {
    throw new Error('SOCIAL_FEED_PLATFORMS_INVALID');
  }
  const result: SocialFeedTaskInput = { platforms };
  return result;
}

function validSocialFeedTaskInput(input: Object): boolean {
  try {
    normalizedSocialFeedTaskInput(input);
    return true;
  } catch (_error) {
    return false;
  }
}

function normalizeCanaryTaskInput(
  input: InputUserPayload,
  task: LeaderDecisionDataTask,
  currentLocalDate: string
): Object {
  // MultiAgentLeaderPlanner owns the date snapshot and replaces task.input with
  // the normalized value. LeaderAgent receives the same host-only authority
  // for its defense-in-depth pass and never calls an independent clock.
  if (task.toolId === 'hotel.search') {
    return normalizeHotelSearchTaskInput(input, task, currentLocalDate);
  }
  if (task.toolId === 'travel.search' || task.toolId === 'train.search' ||
    task.toolId === 'flight.search') {
    const normalized = setJsonPointer(task.input as JsonValue, '/query', input.text);
    if (!normalized.ok || normalized.value === undefined || normalized.value === null ||
      typeof normalized.value !== 'object' || Array.isArray(normalized.value)) {
      throw new Error(normalized.errorCode.length > 0 ?
        normalized.errorCode : 'TRAVEL_TASK_INPUT_INVALID');
    }
    return normalized.value as Object;
  }
  if (task.toolId === 'social.feed.search') {
    return normalizedSocialFeedTaskInput(unwrapSingleArgsEnvelope(task.input));
  }
  if (task.toolId !== 'calendar.events.search') {
    return task.input;
  }
  const timestamp: number = Date.parse(currentLocalDate + 'T00:00:00+08:00');
  if (Number.isNaN(timestamp)) {
    throw new Error('CURRENT_LOCAL_DATE_INVALID');
  }
  const now = new Date(timestamp);
  const update = calendarUpdateSearchArgs(input.text, now);
  if (update !== null) {
    return update as Object;
  }
  const remove = calendarDeleteSearchArgs(input.text, now);
  if (remove !== null) {
    return remove as Object;
  }
  const source = task.input as Record<string, Object | string | number | boolean | null | undefined>;
  const safe: Record<string, Object | string | number | boolean> = {};
  Object.keys(source).forEach((key: string) => {
    const value = source[key];
    if (key !== 'eventId' && key !== 'requestedAction' && value !== null && value !== undefined) {
      safe[key] = value as Object | string | number | boolean;
    }
  });
  return normalizedCalendarArgsForPrompt('calendar.events.search', input.text, safe, now) as Object;
}

function authorizeCanaryDataTask(task: CreateDataTaskPayload): DataTaskAuthorizationResult {
  if (task.toolId === 'dynamic.search') {
    const validDynamic = task.required && task.outputSchema === 'dynamicToolConnect' &&
      task.allowedToolIds.length === 1 && task.allowedToolIds[0] === 'dynamic.search';
    return {
      ok: validDynamic,
      code: validDynamic ? '' : 'DATA_TASK_UNAUTHORIZED',
      message: validDynamic ? '' : 'Dynamic data tasks require the exact read-only virtual tool.'
    };
  }
  if (task.toolId === 'hotel.search' || task.toolId === 'hotel.detail') {
    return authorizeHotelDataTask(task);
  }
  const definition = toolDefinitionForToolId(task.toolId);
  let valid: boolean = definition !== null && definition.riskLevel === 'read' &&
    definition.outputSchema === task.outputSchema && task.required &&
    definition.backendPriority.indexOf('system_intent') < 0 &&
    task.allowedToolIds.length > 0;
  const allowed: Set<string> = new Set<string>();
  for (let index = 0; valid && index < task.allowedToolIds.length; index++) {
    const toolId: string = task.allowedToolIds[index];
    const allowedDefinition = toolDefinitionForToolId(toolId);
    if (allowed.has(toolId) || allowedDefinition === null ||
      allowedDefinition.riskLevel !== 'read' ||
      allowedDefinition.backendPriority.indexOf('system_intent') >= 0) {
      valid = false;
    } else {
      allowed.add(toolId);
    }
  }
  valid = valid && allowed.has(task.toolId);
  if (valid && task.toolId === 'social.feed.search') {
    valid = validSocialFeedTaskInput(task.args);
  }
  return {
    ok: valid,
    code: valid ? '' : 'DATA_TASK_UNAUTHORIZED',
    message: valid ? '' : 'Data task is outside the registered read allowlist.'
  };
}

class CanaryStructuredDataExecutor implements DataTaskExecutor {
  private readonly structuredToolCall: (
    toolId: string,
    prompt: string,
    args: Object
  ) => Promise<DataResult>;

  constructor(structuredToolCall?: (
    toolId: string,
    prompt: string,
    args: Object
  ) => Promise<DataResult>) {
    this.structuredToolCall = structuredToolCall === undefined ? callStructuredTool : structuredToolCall;
  }

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    let prompt: string = task.goal;
    if (task.toolId === 'travel.search' || task.toolId === 'train.search' ||
      task.toolId === 'flight.search') {
      const values = task.args as Record<string, Object | string | number | boolean | null | undefined>;
      const query = values['query'];
      if (typeof query !== 'string' || query.trim().length === 0) {
        throw new Error('TRAVEL_QUERY_MISSING');
      }
      prompt = query;
    }
    const result = await this.structuredToolCall(task.toolId, prompt, task.args);
    if (task.toolId !== 'calendar.events.search' || result.status === 'error') {
      return result;
    }
    const taskValues = task.args as Record<string, Object | string | number | boolean | null | undefined>;
    const requestedAction = taskValues['requestedAction'];
    if (requestedAction === null || requestedAction === undefined ||
      typeof requestedAction !== 'object' || Array.isArray(requestedAction)) {
      return result;
    }
    const data = result.data as Record<string, Object | string | number | boolean | null | undefined>;
    data['requestedAction'] = requestedAction;
    return result;
  }
}

function surfaceFromJsonl(jsonl: string): A2uiSurfaceState | null {
  const parsed = parseA2uiJsonl(jsonl);
  if (parsed.error.length > 0) {
    return null;
  }
  const store = new A2uiSurfaceStore();
  for (let index = 0; index < parsed.envelopes.length; index++) {
    if (!store.apply(parsed.envelopes[index]).ok) {
      return null;
    }
  }
  return store.getSurface();
}

function calendarReviewSurface(
  surfaceId: string,
  actionId: string,
  args: Object
): A2uiSurfaceState | null {
  const values = args as Record<string, Object | string | number | boolean | null | undefined>;
  const review: DynamicGenericToolResult = {
    sourceTag: 'Composio Google Calendar',
    toolName: actionId,
    title: actionId === 'calendar.event.create' ? '确认创建日程' : '确认更新日程',
    status: 'confirm_required',
    summary: '请核对当前日程参数；只有点击此卡片上的精确操作才会调用 Provider。',
    rows: [
      { label: 'Title', value: typeof values['title'] === 'string' ? values['title'] : '' },
      { label: 'Start', value: typeof values['start'] === 'string' ? values['start'] : '' },
      { label: 'End', value: typeof values['end'] === 'string' ? values['end'] : '' }
    ],
    rawPreview: JSON.stringify(args),
    actions: [{
      id: actionId,
      label: actionId === 'calendar.event.create' ? '确认创建' : '确认更新',
      prompt: actionId,
      variant: 'primary',
      kind: 'prompt',
      args
    }]
  };
  return surfaceFromJsonl(genericToolResultsA2ui(
    surfaceId, actionId, [review], 'calendar', review.title
  ));
}

function memoryRequest(args: Object): PersonaMemoryUpdateRequest | null {
  if (args === null || typeof args !== 'object' || Array.isArray(args)) {
    return null;
  }
  const values = args as Record<string, Object | string | number | boolean | null | undefined>;
  const personaId = values['personaId'];
  if (typeof personaId !== 'string' || personaId.trim().length === 0) {
    return null;
  }
  return parsePersonaMemoryUpdateInput(JSON.stringify(args), personaId);
}

class CanaryArgsValidator implements ActionArgsValidator {
  validate(actionId: string, args: Object): ActionValidationResult {
    if (actionId === MEMORY_ACTION_ID) {
      const valid = memoryRequest(args) !== null;
      return {
        ok: valid,
        code: valid ? '' : 'MEMORY_UPDATE_ARGS_INVALID',
        message: valid ? '' : 'Memory update args are invalid.'
      };
    }
    return validateRegisteredPageActionArgs(actionId, args);
  }
}

class CanarySurfaceAuthorizer implements SurfaceActionAuthorizer {
  private readonly hotel: HotelSurfaceAuthority;

  constructor(hotel: HotelSurfaceAuthority) {
    this.hotel = hotel;
  }

  allows(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    actionId: string,
    args: Object
  ): boolean {
    if (actionId === MEMORY_ACTION_ID) {
      return surfaceId.startsWith('virtual:') &&
        conversationId.length > 0 && turnId.length > 0 && memoryRequest(args) !== null;
    }
    return this.hotel.allows(conversationId, turnId, surfaceId, actionId, args);
  }
}

function exactCurrentGmailDraftApplyAction(
  snapshot: RegisteredPageSnapshot | null,
  currentHost: A2uiSurfaceState | null,
  hostGeneration: number
): A2uiAction | null {
  if (snapshot === null || currentHost === null ||
    !Number.isSafeInteger(snapshot.generation) || snapshot.generation <= 0 ||
    !Number.isSafeInteger(hostGeneration) || hostGeneration <= 0 ||
    snapshot.surface.runtimeOwner !== 'multi_agent' ||
    currentHost.runtimeOwner !== 'multi_agent' ||
    snapshot.surface.runtimeGeneration !== hostGeneration ||
    currentHost.runtimeGeneration !== hostGeneration ||
    snapshot.surface.surfaceId !== currentHost.surfaceId ||
    snapshot.document.surfaceId !== snapshot.surface.surfaceId ||
    snapshot.document.generatedAt.trim().length === 0 ||
    registeredPageSourceToolId(snapshot.surface) !== 'gmail.draft.create') {
    return null;
  }
  const candidates: A2uiAction[] = [];
  const append = (
    id: string,
    label: string,
    prompt: string,
    variant: string,
    kind: string,
    args: Object | undefined
  ): void => {
    if (id !== 'gmail.draft.apply' || args === undefined) {
      return;
    }
    const clicked: A2uiAction = { id, label, prompt, variant, kind, args };
    if (!isHtmlHomeActionAllowed(snapshot.document, clicked)) {
      return;
    }
    const route = resolveRegisteredPageAction('gmail.draft.create', clicked);
    if (route !== null && route.pageActionId === 'gmail.draft.apply' &&
      route.action.id === 'gmail.draft.apply' && route.action.args !== undefined) {
      candidates.push(route.action);
    }
  };
  snapshot.document.actions.forEach((candidate) => {
    append(
      candidate.id, candidate.label, candidate.prompt,
      candidate.variant, candidate.kind, candidate.args
    );
  });
  snapshot.document.blocks.forEach((block) => {
    block.actions.forEach((candidate) => {
      append(
        candidate.id, candidate.label, candidate.prompt,
        candidate.variant, candidate.kind, candidate.args
      );
    });
  });
  if (candidates.length === 0) {
    return null;
  }
  const expected = JSON.stringify(candidates[0]);
  for (let index = 1; index < candidates.length; index++) {
    if (JSON.stringify(candidates[index]) !== expected) {
      return null;
    }
  }
  return candidates[0];
}

class MemoryIntentResolver implements VirtualActionIntentResolver {
  private readonly currentGmailDraftApply: () => A2uiAction | null;

  constructor(currentGmailDraftApply: () => A2uiAction | null) {
    this.currentGmailDraftApply = currentGmailDraftApply;
  }

  async resolve(request: ActionPlanRequestPayload): Promise<VirtualActionIntent | null> {
    if (request.virtual !== true || request.dataTaskIds.length !== 0 ||
      request.allowedActionIds.length !== 1 ||
      request.personaId === undefined || request.inputText === undefined) {
      return null;
    }
    const actionId = request.allowedActionIds[0];
    if (actionId !== MEMORY_ACTION_ID) {
      let action: A2uiAction | null = null;
      if (actionId === 'gmail.draft.apply') {
        action = request.inputText.trim() === '确认应用刚才的 Gmail 草稿' ?
          this.currentGmailDraftApply() : null;
      } else {
        const now: Date | null = calendarNow(request.currentLocalDate);
        if (now === null) {
          return null;
        }
        action = resolveVirtualRegisteredPageAction(
          actionId, request.inputText, now
        );
      }
      if (action === null || action.args === undefined) {
        return null;
      }
      const offer: ActionOffer = {
        offerId: 'initial-action:' + actionId,
        actionId: actionId,
        label: actionId,
        variant: 'primary',
        args: action.args
      };
      const intent: VirtualActionIntent = {
        sourceToolId: VIRTUAL_ACTION_INTENT_SOURCE_TOOL_ID,
        offer: offer,
        autoRun: true
      };
      return intent;
    }
    const pack = personaPackForId(request.personaId);
    if (pack.manifest.id !== request.personaId) {
      return null;
    }
    const statement: string = request.inputText.trim();
    if (statement.length === 0) {
      return null;
    }
    const summary: string = statement.length > MEMORY_SUMMARY_LIMIT ?
      statement.substring(0, MEMORY_SUMMARY_LIMIT) : statement;
    const args: PersonaMemoryUpdateRequest = {
      personaId: request.personaId,
      summary,
      memoryText: statement,
      reason: '用户明确表达了可长期保存的偏好。'
    };
    const offer: ActionOffer = {
      offerId: 'memory-update:' + request.personaId,
      actionId: MEMORY_ACTION_ID,
      label: '更新记忆',
      variant: 'primary',
      args
    };
    return {
      sourceToolId: MEMORY_ACTION_ID,
      offer,
      autoRun: true
    };
  }
}

const rejectPageAction: RegisteredPageAction = async (
  _actionId: string,
  _args: Object,
  _context: ActionExecutionContext
): Promise<ActionExecutionResult> => ({
  status: 'error',
  errorCode: 'ACTION_PAGE_ROUTE_UNAVAILABLE',
  message: 'Registered page action is unavailable.'
});

class CanaryRegisteredExecutor implements RegisteredActionExecutor {
  private readonly aiphone: AiphoneRegisteredActionExecutor;
  private readonly onMemoryUpdate: (
    update: PersonaMemoryUpdateRequest,
    context: ActionExecutionContext
  ) => void;
  private readonly onSurface: (surface: A2uiSurfaceState, context: ActionExecutionContext) => void;
  private readonly currentGmailDraftApply: () => A2uiAction | null;
  private sequence: number = 0;

  constructor(
    aiphone: AiphoneRegisteredActionExecutor,
    onMemoryUpdate: (
      update: PersonaMemoryUpdateRequest,
      context: ActionExecutionContext
    ) => void,
    onSurface: (surface: A2uiSurfaceState, context: ActionExecutionContext) => void,
    currentGmailDraftApply: () => A2uiAction | null
  ) {
    this.aiphone = aiphone;
    this.onMemoryUpdate = onMemoryUpdate;
    this.onSurface = onSurface;
    this.currentGmailDraftApply = currentGmailDraftApply;
  }

  async execute(
    actionId: string,
    args: Object,
    context: ActionExecutionContext
  ): Promise<ActionExecutionResult> {
    if (actionId === 'calendar.event.create' && context.virtualAction === true) {
      this.sequence++;
      const surfaceId = 'calendar-review:' + this.sequence.toString();
      const surface = calendarReviewSurface(surfaceId, actionId, args);
      if (surface === null) {
        return {
          status: 'error',
          errorCode: 'CALENDAR_REVIEW_RENDER_FAILED',
          message: 'Calendar review surface could not be rendered.'
        };
      }
      this.onSurface(surface, context);
      const output: CalendarReviewOutput = { surfaceId };
      return { status: 'success', output };
    }
    if (actionId !== MEMORY_ACTION_ID) {
      if (actionId === 'gmail.draft.apply' && context.virtualAction === true) {
        const current = this.currentGmailDraftApply();
        if (current === null || current.args === undefined ||
          JSON.stringify(current.args) !== JSON.stringify(args)) {
          return {
            status: 'error',
            errorCode: 'GMAIL_DRAFT_SURFACE_STALE',
            message: 'Gmail draft no longer matches the exact current surface.'
          };
        }
      }
      return this.aiphone.execute(actionId, args, context);
    }
    const update = memoryRequest(args);
    if (update === null) {
      return {
        status: 'error',
        errorCode: 'MEMORY_UPDATE_ARGS_INVALID',
        message: 'Memory update args are invalid.'
      };
    }
    this.onMemoryUpdate(update, context);
    this.sequence++;
    const surfaceId: string = 'memory-update:' + this.sequence.toString();
    this.onSurface(memoryUpdateSurface(surfaceId, update), context);
    const output: MemorySurfaceOutput = { surfaceId };
    return {
      status: 'success',
      output
    };
  }
}

interface MemorySurfaceOutput {
  surfaceId: string;
}

function canaryPlanningContext(previousPersonaId: string, prompt: string = ''): LeaderPlanningContext {
  const tools: LeaderToolMetadata[] = allToolDefinitions()
    .filter((definition: ToolDefinition): boolean =>
      definition.toolId !== 'gmail.message.send' &&
        (definition.toolId !== 'luckin.order.preview' || isExplicitLuckinOrderPrompt(prompt))
    )
    .map(
    (definition: ToolDefinition): LeaderToolMetadata => {
      const actions = definition.actions.filter(
        (actionId: string): boolean => toolDefinitionForToolId(actionId) !== null
      );
      return {
        toolId: definition.toolId,
        domain: definition.domain,
        intent: definition.intent,
        riskLevel: definition.riskLevel,
        registeredBackends: definition.backendPriority.slice(),
        inputSchema: definition.inputSchema,
        outputSchema: definition.outputSchema,
        actions,
        planningHint: toolPlanningDescriptionForToolId(definition.toolId)
      };
    }
  );
  const memory = memoryDefinition();
  tools.push({
    toolId: 'dynamic.search',
    domain: 'dynamic',
    intent: 'dynamic.search',
    riskLevel: 'read',
    registeredBackends: ['mcp_remote', 'oauth_api'],
    inputSchema: 'dynamicToolSearchQuery',
    outputSchema: 'dynamicToolConnect',
    actions: [],
    planningHint: toolPlanningDescriptionForToolId('dynamic.search')
  });
  tools.push({
    toolId: memory.toolId,
    domain: memory.domain,
    intent: memory.intent,
    riskLevel: memory.riskLevel,
    registeredBackends: memory.backendPriority.slice(),
    inputSchema: memory.inputSchema,
    outputSchema: memory.outputSchema,
    actions: memory.actions.slice()
  });
  const runtimeOwnedToolIds: string[] = [];
  MIGRATED_TOOL_IDS.forEach((toolId: string): void => {
    runtimeOwnedToolIds.push(toolId);
  });
  runtimeOwnedToolIds.push(MEMORY_ACTION_ID);
  return {
    tools,
    personas: leaderPersonaContext(previousPersonaId),
    runtimeOwnedToolIds
  };
}

export function rememberedPersonaAfterOutcome(
  currentPersonaId: string,
  outcome: MultiAgentTurnOutcome,
  isLatestSubmission: boolean
): string {
  if (!isLatestSubmission ||
    outcome.kind !== 'settled' ||
    (outcome.status !== 'success' && outcome.status !== 'partial' && outcome.status !== 'empty') ||
    outcome.personaId.trim().length === 0) {
    return currentPersonaId;
  }
  return outcome.personaId;
}

export class MultiAgentCanaryRuntime {
  private readonly runtime: MultiAgentRuntime;
  private readonly authority: HotelSurfaceAuthority;
  private readonly surfaceWriter: HotelRuntimeSurfaceWriter;
  private readonly conversationId: string;
  private readonly aiphoneExecutor: AiphoneRegisteredActionExecutor;
  private readonly mailDetailBridge: MailDetailInPlaceBridge;
  private readonly currentPageSnapshot: () => RegisteredPageSnapshot | null;
  private readonly currentHostSurface: () => A2uiSurfaceState | null;
  private readonly currentHostGeneration: () => number;
  private readonly turnHostGenerations: Map<string, number> = new Map<string, number>();
  private readonly turnHostGenerationOrder: string[] = [];
  private pageGeneration: number = 0;
  private pageFingerprint: string = '';
  private surfaceGeneration: number = 0;
  private lastLeaderPersonaId: string = '';
  private submissionSequence: number = 0;

  constructor(options: MultiAgentCanaryOptions) {
    const conversationId: string = options.conversationId === undefined ?
      'aiphone-canary-' + Date.now().toString() : options.conversationId;
    this.conversationId = conversationId;
    this.currentPageSnapshot = options.currentPageSnapshot === undefined ?
      (): RegisteredPageSnapshot | null => null : options.currentPageSnapshot;
    this.currentHostSurface = options.currentHostSurface === undefined ?
      (): A2uiSurfaceState | null => {
        const snapshot = this.currentPageSnapshot();
        return snapshot === null ? null : snapshot.surface;
      } : options.currentHostSurface;
    this.currentHostGeneration = options.currentHostGeneration === undefined ?
      (): number => {
        const current = this.currentHostSurface();
        return current === null || current.runtimeGeneration === undefined ?
          0 : current.runtimeGeneration;
      } : options.currentHostGeneration;
    const currentGmailDraftApply = (): A2uiAction | null =>
      exactCurrentGmailDraftApplyAction(
        this.currentPageSnapshot(),
        this.currentHostSurface(),
        this.currentHostGeneration()
      );
    const ids = new MonotonicHotelIds();
    const followUpIds = new PreparedHotelFollowUpIds(ids);
    this.authority = new HotelSurfaceAuthority();
    const visibility = new HotelVisibility();
    const onOwnedSurface = (
      surface: A2uiSurfaceState,
      _generation: number,
      turnId: string
    ): boolean => {
      const hostGeneration = this.turnHostGenerations.get(turnId);
      if (hostGeneration === undefined || hostGeneration <= 0) {
        return false;
      }
      surface.runtimeOwner = 'multi_agent';
      surface.runtimeGeneration = hostGeneration;
      return options.onSurface(surface, hostGeneration);
    };
    const lookup = new CanaryToolLookup();
    const catalog = new ActionCatalog(
      lookup,
      new CanarySurfaceAuthorizer(this.authority),
      new RejectClientAction(),
      new CanaryArgsValidator()
    );
    const writer = new HotelRuntimeSurfaceWriter(
      conversationId,
      options.downstreamWriter === undefined ?
        new IgnoreHotelSurfaceWriter() : options.downstreamWriter,
      onOwnedSurface,
      this.authority,
      visibility,
      true
    );
    this.surfaceWriter = writer;
    const structuredRenderer = new StructuredToolUiRenderer(
      options.uiLayoutPlanner === undefined ? null : options.uiLayoutPlanner,
      6000
    );
    const mailDetailBridge = new MailDetailInPlaceBridge(
      structuredRenderer,
      writer,
      this.currentHostGeneration,
      options.onMailDetail
    );
    this.mailDetailBridge = mailDetailBridge;
    const aiphoneExecutor = new AiphoneRegisteredActionExecutor(
      catalog,
      options.opener,
      followUpIds,
      options.pageAction === undefined ? rejectPageAction : options.pageAction,
      mailDetailBridge
    );
    this.aiphoneExecutor = aiphoneExecutor;
    const initialContext = canaryPlanningContext(this.lastLeaderPersonaId);
    const dataTaskInputNormalizer: LeaderDataTaskInputNormalizer = (
      input: InputUserPayload,
      task: LeaderDecisionDataTask,
      currentLocalDate: string
    ): Object => normalizeCanaryTaskInput(input, task, currentLocalDate);
    this.runtime = new MultiAgentRuntime({
      conversationId,
      bus: options.bus,
      planner: new MultiAgentLeaderPlanner(
        options.model,
        undefined,
        dataTaskInputNormalizer
      ),
      planningContext: initialContext,
      planningContextProvider: (prompt: string): LeaderPlanningContext =>
        canaryPlanningContext(this.lastLeaderPersonaId, prompt),
      currentLocalDateProvider: options.currentLocalDate,
      dataTaskInputNormalizer,
      dataAuthorizer: authorizeCanaryDataTask,
      dataExecutor: options.dataExecutor === undefined ?
        new CanaryStructuredDataExecutor(options.structuredToolCall) : options.dataExecutor,
      uiRenderer: mailDetailBridge,
      surfaceWriter: mailDetailBridge,
      actionCatalog: catalog,
      actionCompiler: new MultiAgentActionPlanCompiler(options.model),
      actionExecutor: new CanaryRegisteredExecutor(
        aiphoneExecutor,
        (update: PersonaMemoryUpdateRequest, context: ActionExecutionContext): void => {
          const hostGeneration = this.turnHostGenerations.get(context.turnId);
          if (hostGeneration !== undefined && hostGeneration > 0) {
            options.onMemoryUpdate(update, hostGeneration);
          }
        },
        (surface: A2uiSurfaceState, context: ActionExecutionContext): void => {
          const hostGeneration = this.turnHostGenerations.get(context.turnId);
          if (hostGeneration === undefined || hostGeneration <= 0) {
            return;
          }
          surface.runtimeOwner = 'multi_agent';
          surface.runtimeGeneration = hostGeneration;
          options.onSurface(surface, hostGeneration);
        },
        currentGmailDraftApply
      ),
      virtualActionResolver: new MemoryIntentResolver(currentGmailDraftApply),
      submitTimeoutMs: options.submitTimeoutMs,
      actionTimeoutMs: options.actionTimeoutMs,
      settingsFingerprint: options.settingsFingerprint,
      surfaceTurnActivator: (turnId: string, hostGeneration: number): void => {
        this.rememberTurnHostGeneration(turnId, hostGeneration);
        writer.activateAutomaticTurn(turnId);
      },
      turnGenerationObserver: (turnId: string, hostGeneration: number): void => {
        this.rememberTurnHostGeneration(turnId, hostGeneration);
      }
    });
  }

  submit(
    text: string,
    context: UserInputPayload,
    hostGeneration: number = 0
  ): Promise<MultiAgentTurnOutcome> {
    this.submissionSequence++;
    const submissionSequence: number = this.submissionSequence;
    const capturedGeneration = Number.isSafeInteger(hostGeneration) && hostGeneration > 0 ?
      hostGeneration : 0;
    const input: UserInputPayload = {
      text: context.text,
      recentMessages: context.recentMessages,
      previousPersonaId: this.lastLeaderPersonaId,
      currentSurfaceSummary: context.currentSurfaceSummary,
      recentObservations: context.recentObservations
    };
    return this.runtime.submit(text, input, capturedGeneration)
      .then((outcome: MultiAgentTurnOutcome): MultiAgentTurnOutcome => {
        this.lastLeaderPersonaId = rememberedPersonaAfterOutcome(
          this.lastLeaderPersonaId,
          outcome,
          submissionSequence === this.submissionSequence
        );
        return outcome;
      });
  }

  runAction(action: A2uiAction, context: MultiAgentCanaryActionContext): Promise<boolean> {
    if (action.id === 'hotel.detail' && !this.currentHotelDetailContext(context)) {
      return Promise.resolve(false);
    }
    const execution: ActionExecutionContext = {
      conversationId: context.conversationId,
      turnId: context.turnId,
      surfaceId: context.surfaceId,
      sourceToolId: context.sourceToolId,
      planId: '',
      runId: '',
      stepId: '',
      pageActionId: context.pageActionId
    };
    return this.runtime.runAction(action, execution, this.currentHostGeneration())
      .then((ok: boolean): boolean => {
        this.mailDetailBridge.actionSettled(ok);
        return ok;
      });
  }

  runPageAction(
    clicked: A2uiAction
  ): Promise<boolean> {
    const snapshot = this.currentPageSnapshot();
    const currentHost = this.currentHostSurface();
    const hostGeneration = this.currentHostGeneration();
    if (snapshot === null || currentHost === null) {
      return Promise.resolve(false);
    }
    const surface = snapshot.surface;
    const document = snapshot.document;
    const generation = snapshot.generation;
    if (!Number.isSafeInteger(generation) || generation <= 0 ||
      !Number.isSafeInteger(hostGeneration) || hostGeneration <= 0 ||
      surface.runtimeOwner !== 'multi_agent' || currentHost.runtimeOwner !== 'multi_agent' ||
      surface.runtimeGeneration !== hostGeneration ||
      currentHost.runtimeGeneration !== hostGeneration ||
      currentHost.surfaceId !== surface.surfaceId ||
      surface.surfaceId.trim().length === 0 || clicked.args === undefined ||
      document.surfaceId === undefined || document.surfaceId !== surface.surfaceId ||
      document.generatedAt.trim().length === 0 ||
      !isHtmlHomeActionAllowed(document, clicked)) {
      return Promise.resolve(false);
    }
    const sourceToolId = registeredPageSourceToolId(surface);
    const route = resolveRegisteredPageAction(sourceToolId, clicked);
    if (route === null || route.action.args === undefined) {
      return Promise.resolve(false);
    }
    const fingerprint = registeredPageSnapshotFingerprint(snapshot);
    if (generation < this.pageGeneration ||
      (generation === this.pageGeneration && fingerprint !== this.pageFingerprint)) {
      return Promise.resolve(false);
    }
    if (generation > this.pageGeneration) {
      this.pageGeneration = generation;
      this.pageFingerprint = fingerprint;
    }
    const turnId = 'page-turn-' + generation.toString();
    this.authority.activate(
      this.conversationId,
      turnId,
      surface.surfaceId,
      sourceToolId,
      document,
      route.action
    );
    const context: MultiAgentCanaryActionContext = {
      conversationId: this.conversationId,
      turnId,
      surfaceId: surface.surfaceId,
      sourceToolId,
      pageActionId: route.pageActionId
    };
    return this.runAction(route.action, context);
  }

  currentActionContext(): MultiAgentCanaryActionContext | null {
    const context = this.authority.context();
    if (context === null) {
      return null;
    }
    return {
      conversationId: context.conversationId,
      turnId: context.turnId,
      surfaceId: context.surfaceId,
      sourceToolId: context.sourceToolId
    };
  }

  cancelActiveTurn(reason: string): void {
    this.runtime.cancelActiveTurn(reason);
  }

  restoreSearchSurface(): boolean {
    return this.surfaceWriter.restoreLatestSearchSurface();
  }

  dispose(): void {
    this.runtime.dispose();
    this.aiphoneExecutor.dispose();
    this.mailDetailBridge.dispose();
    this.pageGeneration = 0;
    this.pageFingerprint = '';
    this.surfaceGeneration = 0;
    this.turnHostGenerations.clear();
    this.turnHostGenerationOrder.splice(0, this.turnHostGenerationOrder.length);
  }

  private currentHotelDetailContext(context: MultiAgentCanaryActionContext): boolean {
    const snapshot = this.currentPageSnapshot();
    const currentHost = this.currentHostSurface();
    const hostGeneration = this.currentHostGeneration();
    if (snapshot === null || currentHost === null ||
      !Number.isSafeInteger(hostGeneration) || hostGeneration <= 0 ||
      !Number.isSafeInteger(snapshot.generation) || snapshot.generation <= 0) {
      return false;
    }
    const surface = snapshot.surface;
    const exact = currentHost.runtimeOwner === 'multi_agent' &&
      surface.runtimeOwner === 'multi_agent' &&
      currentHost.runtimeGeneration === hostGeneration &&
      surface.runtimeGeneration === hostGeneration &&
      currentHost.surfaceId === surface.surfaceId &&
      surface.surfaceId === context.surfaceId &&
      snapshot.document.surfaceId === surface.surfaceId &&
      context.sourceToolId === 'hotel.search' &&
      registeredPageSourceToolId(surface) === context.sourceToolId;
    return exact;
  }

  private rememberTurnHostGeneration(turnId: string, hostGeneration: number): void {
    if (turnId.trim().length === 0) {
      return;
    }
    let capturedGeneration = hostGeneration;
    if (!Number.isSafeInteger(capturedGeneration) || capturedGeneration <= 0) {
      const retained = this.turnHostGenerations.get(turnId);
      if (retained !== undefined && retained > 0) {
        capturedGeneration = retained;
      } else {
        this.surfaceGeneration++;
        capturedGeneration = this.surfaceGeneration;
      }
    }
    if (!this.turnHostGenerations.has(turnId)) {
      this.turnHostGenerationOrder.push(turnId);
    }
    this.turnHostGenerations.set(turnId, capturedGeneration);
    while (this.turnHostGenerationOrder.length > TURN_HOST_GENERATION_LIMIT) {
      const removedTurnId = this.turnHostGenerationOrder[0];
      this.turnHostGenerationOrder.splice(0, 1);
      this.turnHostGenerations.delete(removedTurnId);
    }
  }
}
