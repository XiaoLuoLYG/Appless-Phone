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
  DataResult,
  DataTaskExecutor,
  DataTaskAuthorizationResult,
  DynamicGenericToolResult,
  InputUserPayload,
  LeaderDecisionDataTask,
  LeaderPlanningContext,
  LeaderToolMetadata,
  LinkedMessageBus,
  LocalModel,
  RegisteredActionExecutor,
  SurfaceActionAuthorizer,
  ToolDefinition,
  ToolDefinitionLookup,
  UiLayoutPlanner,
  UiSurfaceWriter,
  UserInputPayload,
  VIRTUAL_ACTION_INTENT_SOURCE_TOOL_ID,
  VirtualActionIntent,
  VirtualActionIntentResolver,
  allToolDefinitions,
  callStructuredTool,
  genericToolResultsA2ui,
  normalizedCalendarArgsForPrompt,
  parseA2uiJsonl,
  toolDefinitionForToolId
} from '@loop/agent-core';
import { leaderPersonaContext } from '../../../model/LeaderPersonaContext';
import {
  memoryUpdateSurface,
  parsePersonaMemoryUpdateInput,
  PersonaMemoryUpdateRequest
} from '../../../model/PersonaMemoryUpdate';
import { personaPackForId } from '../../../model/PersonaStore';
import { MultiAgentLeaderPlanner } from './MultiAgentLeaderPlanner';
import {
  HotelLocalDateProvider,
  normalizeHotelSearchTaskInput
} from './HotelLeaderPlanner';
import { MultiAgentRuntime } from './MultiAgentRuntime';
import { MultiAgentTurnOutcome } from './MultiAgentRuntimeTypes';
import { isHtmlHomeActionAllowed } from '../html/HtmlHomeActionPolicy';
import {
  authorizeHotelDataTask,
  HotelRuntimeSurfaceWriter,
  HotelSurfaceAuthority,
  HotelSurfaceCallback,
  HotelVisibility,
  IgnoreHotelSurfaceWriter,
  MonotonicHotelIds,
  PreparedHotelFollowUpIds
} from './HotelAgentRuntime';
import { StructuredToolUiRenderer } from './StructuredToolUiRenderer';
import {
  AiphoneRegisteredActionExecutor,
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

export interface MultiAgentCanaryOptions {
  model: LocalModel;
  selectedPersonaId: () => string;
  opener: SystemUriOpener;
  pageAction?: RegisteredPageAction;
  currentPageSnapshot?: () => RegisteredPageSnapshot | null;
  onSurface: HotelSurfaceCallback;
  onMemoryUpdate: (update: PersonaMemoryUpdateRequest) => void;
  downstreamWriter?: UiSurfaceWriter;
  uiLayoutPlanner?: UiLayoutPlanner;
  settingsFingerprint?: string;
  submitTimeoutMs?: number;
  actionTimeoutMs?: number;
  currentLocalDate?: HotelLocalDateProvider;
  dataExecutor?: DataTaskExecutor;
  bus?: LinkedMessageBus;
  conversationId?: string;
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

function calendarNow(currentLocalDate?: HotelLocalDateProvider): Date {
  if (currentLocalDate === undefined) {
    return new Date();
  }
  const value = currentLocalDate().trim();
  const timestamp = Date.parse(value + 'T00:00:00+08:00');
  return Number.isNaN(timestamp) ? new Date() : new Date(timestamp);
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

function normalizeCanaryTaskInput(
  input: InputUserPayload,
  task: LeaderDecisionDataTask,
  now: Date
): Object {
  if (task.toolId === 'hotel.search') {
    return normalizeHotelSearchTaskInput(input, task);
  }
  if (task.toolId !== 'calendar.events.search') {
    return task.input;
  }
  const update = calendarUpdateSearchArgs(input.text, now);
  if (update !== null) {
    return update as Object;
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
  if (task.toolId !== 'calendar.events.search') {
    return authorizeHotelDataTask(task);
  }
  const valid = task.allowedToolIds.length === 1 &&
    task.allowedToolIds[0] === 'calendar.events.search' &&
    task.outputSchema === 'calendarEvents' && task.required;
  return {
    ok: valid,
    code: valid ? '' : 'CALENDAR_DATA_TASK_DENIED',
    message: valid ? '' : 'Calendar read task is outside the exact allowlist.'
  };
}

class CanaryStructuredDataExecutor implements DataTaskExecutor {
  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    const result = await callStructuredTool(task.toolId, task.goal, task.args);
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

class MemoryIntentResolver implements VirtualActionIntentResolver {
  private readonly currentLocalDate?: HotelLocalDateProvider;

  constructor(currentLocalDate?: HotelLocalDateProvider) {
    this.currentLocalDate = currentLocalDate;
  }

  async resolve(request: ActionPlanRequestPayload): Promise<VirtualActionIntent | null> {
    if (request.virtual !== true || request.dataTaskIds.length !== 0 ||
      request.allowedActionIds.length !== 1 ||
      request.personaId === undefined || request.inputText === undefined) {
      return null;
    }
    const actionId = request.allowedActionIds[0];
    if (actionId !== MEMORY_ACTION_ID) {
      const action = resolveVirtualRegisteredPageAction(
        actionId, request.inputText, calendarNow(this.currentLocalDate)
      );
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
    const separator: string = pack.memory.trim().length === 0 ? '' : '\n';
    const args: PersonaMemoryUpdateRequest = {
      personaId: request.personaId,
      summary,
      memoryText: pack.memory + separator + statement,
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
  private readonly onMemoryUpdate: (update: PersonaMemoryUpdateRequest) => void;
  private readonly onSurface: HotelSurfaceCallback;
  private sequence: number = 0;

  constructor(
    aiphone: AiphoneRegisteredActionExecutor,
    onMemoryUpdate: (update: PersonaMemoryUpdateRequest) => void,
    onSurface: HotelSurfaceCallback
  ) {
    this.aiphone = aiphone;
    this.onMemoryUpdate = onMemoryUpdate;
    this.onSurface = onSurface;
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
      this.onSurface(surface);
      const output: CalendarReviewOutput = { surfaceId };
      return { status: 'success', output };
    }
    if (actionId !== MEMORY_ACTION_ID) {
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
    this.onMemoryUpdate(update);
    this.sequence++;
    const surfaceId: string = 'memory-update:' + this.sequence.toString();
    this.onSurface(memoryUpdateSurface(surfaceId, update));
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

function canaryPlanningContext(previousPersonaId: string): LeaderPlanningContext {
  const tools: LeaderToolMetadata[] = allToolDefinitions().map(
    (definition: ToolDefinition): LeaderToolMetadata => {
      const actions = definition.actions.slice();
      if ((definition.toolId === 'worldcup.open' || definition.toolId === 'maps.route.open' ||
        definition.toolId === 'calendar.event.create') &&
        actions.indexOf(definition.toolId) < 0) {
        actions.push(definition.toolId);
      }
      return {
        toolId: definition.toolId,
        intent: definition.intent,
        riskLevel: definition.riskLevel,
        inputSchema: definition.inputSchema,
        outputSchema: definition.outputSchema,
        actions
      };
    }
  );
  const memory = memoryDefinition();
  tools.push({
    toolId: 'dynamic.search',
    intent: 'dynamic.search',
    riskLevel: 'read',
    inputSchema: 'dynamicToolSearchQuery',
    outputSchema: 'dynamicToolConnect',
    actions: []
  });
  tools.push({
    toolId: memory.toolId,
    intent: memory.intent,
    riskLevel: memory.riskLevel,
    inputSchema: memory.inputSchema,
    outputSchema: memory.outputSchema,
    actions: memory.actions.slice()
  });
  return {
    tools,
    personas: leaderPersonaContext(previousPersonaId),
    runtimeOwnedToolIds: [
      'hotel.search',
      'hotel.detail',
      'hotel.navigate',
      'hotel.booking.open',
      'worldcup.open',
      'maps.route.open',
      'calendar.events.search',
      'calendar.event.create',
      'calendar.event.update',
      MEMORY_ACTION_ID
    ]
  };
}

export class MultiAgentCanaryRuntime {
  private readonly runtime: MultiAgentRuntime;
  private readonly authority: HotelSurfaceAuthority;
  private readonly surfaceWriter: HotelRuntimeSurfaceWriter;
  private readonly conversationId: string;
  private readonly aiphoneExecutor: AiphoneRegisteredActionExecutor;
  private readonly currentPageSnapshot: () => RegisteredPageSnapshot | null;
  private pageGeneration: number = 0;
  private pageFingerprint: string = '';

  constructor(options: MultiAgentCanaryOptions) {
    const conversationId: string = options.conversationId === undefined ?
      'aiphone-canary-' + Date.now().toString() : options.conversationId;
    this.conversationId = conversationId;
    this.currentPageSnapshot = options.currentPageSnapshot === undefined ?
      (): RegisteredPageSnapshot | null => null : options.currentPageSnapshot;
    const ids = new MonotonicHotelIds();
    const followUpIds = new PreparedHotelFollowUpIds(ids);
    this.authority = new HotelSurfaceAuthority();
    const visibility = new HotelVisibility();
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
      options.onSurface,
      this.authority,
      visibility,
      true
    );
    this.surfaceWriter = writer;
    const aiphoneExecutor = new AiphoneRegisteredActionExecutor(
      catalog,
      options.opener,
      followUpIds,
      options.pageAction === undefined ? rejectPageAction : options.pageAction
    );
    this.aiphoneExecutor = aiphoneExecutor;
    const initialContext = canaryPlanningContext(options.selectedPersonaId());
    this.runtime = new MultiAgentRuntime({
      conversationId,
      bus: options.bus,
      planner: new MultiAgentLeaderPlanner(options.model, options.currentLocalDate),
      planningContext: initialContext,
      planningContextProvider: (): LeaderPlanningContext =>
        canaryPlanningContext(options.selectedPersonaId()),
      dataTaskInputNormalizer: (input: InputUserPayload, task: LeaderDecisionDataTask): Object =>
        normalizeCanaryTaskInput(input, task, calendarNow(options.currentLocalDate)),
      dataAuthorizer: authorizeCanaryDataTask,
      dataExecutor: options.dataExecutor === undefined ?
        new CanaryStructuredDataExecutor() : options.dataExecutor,
      uiRenderer: new StructuredToolUiRenderer(
        options.uiLayoutPlanner === undefined ? null : options.uiLayoutPlanner,
        6000
      ),
      surfaceWriter: writer,
      actionCatalog: catalog,
      actionExecutor: new CanaryRegisteredExecutor(
        aiphoneExecutor,
        options.onMemoryUpdate,
        options.onSurface
      ),
      virtualActionResolver: new MemoryIntentResolver(options.currentLocalDate),
      submitTimeoutMs: options.submitTimeoutMs,
      actionTimeoutMs: options.actionTimeoutMs,
      settingsFingerprint: options.settingsFingerprint,
      surfaceTurnActivator: (turnId: string): void => writer.activateAutomaticTurn(turnId)
    });
  }

  submit(text: string, context: UserInputPayload): Promise<MultiAgentTurnOutcome> {
    return this.runtime.submit(text, context);
  }

  runAction(action: A2uiAction, context: MultiAgentCanaryActionContext): Promise<boolean> {
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
    return this.runtime.runAction(action, execution);
  }

  runPageAction(
    clicked: A2uiAction
  ): Promise<boolean> {
    const snapshot = this.currentPageSnapshot();
    if (snapshot === null) {
      return Promise.resolve(false);
    }
    const surface = snapshot.surface;
    const document = snapshot.document;
    const generation = snapshot.generation;
    if (!Number.isSafeInteger(generation) || generation <= 0 ||
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
    this.pageGeneration = 0;
    this.pageFingerprint = '';
  }
}
