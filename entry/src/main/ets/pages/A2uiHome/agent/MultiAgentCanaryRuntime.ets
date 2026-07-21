import {
  ActionArgsValidator,
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionOffer,
  ActionPlanRequestPayload,
  ActionValidationResult,
  A2uiAction,
  A2uiSurfaceState,
  ClientActionAuthorizer,
  DataTaskExecutor,
  LeaderPlanningContext,
  LeaderToolMetadata,
  LinkedMessageBus,
  LocalModel,
  RegisteredActionExecutor,
  SingleDataUiTaskRendererAdapter,
  SurfaceActionAuthorizer,
  ToolDefinition,
  ToolDefinitionLookup,
  UiLayoutPlanner,
  UiSurfaceWriter,
  UserInputPayload,
  VirtualActionIntent,
  VirtualActionIntentResolver,
  allToolDefinitions,
  validateHotelActionArgs,
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
import { HtmlHomeDocument } from '../html/HtmlHomeTypes';
import {
  authorizeHotelDataTask,
  HotelRuntimeSurfaceWriter,
  HotelSurfaceAuthority,
  HotelSurfaceCallback,
  HotelUiRenderer,
  HotelVisibility,
  IgnoreHotelSurfaceWriter,
  MonotonicHotelIds,
  PreparedHotelFollowUpIds,
  StructuredHotelDataExecutor
} from './HotelAgentRuntime';
import {
  AiphoneRegisteredActionExecutor,
  RegisteredPageAction,
  SystemUriOpener
} from './AiphoneRegisteredActionExecutor';
import {
  isInitialRegisteredPageAction,
  registeredPageSourceToolId,
  resolveRegisteredPageAction
} from './RegisteredPageActionRoute';

const MEMORY_ACTION_ID: string = 'memory.update';
const MEMORY_SUMMARY_LIMIT: number = 240;

export interface MultiAgentCanaryOptions {
  model: LocalModel;
  selectedPersonaId: () => string;
  opener: SystemUriOpener;
  pageAction?: RegisteredPageAction;
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
    if (actionId.indexOf('hotel.') === 0) {
      return validateHotelActionArgs(actionId, args);
    }
    const valid = args !== null && typeof args === 'object' && !Array.isArray(args);
    return {
      ok: valid,
      code: valid ? '' : 'ACTION_ARGS_INVALID',
      message: valid ? '' : 'Action args are invalid.'
    };
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
    if (surfaceId.startsWith('virtual:') && isInitialRegisteredPageAction(actionId)) {
      const values = args as Record<string, Object | string | number | boolean | null | undefined>;
      return conversationId.length > 0 && turnId.length > 0 &&
        typeof values['originalQuery'] === 'string' &&
        (values['originalQuery'] as string).trim().length > 0;
    }
    return this.hotel.allows(conversationId, turnId, surfaceId, actionId, args);
  }
}

class MemoryIntentResolver implements VirtualActionIntentResolver {
  async resolve(request: ActionPlanRequestPayload): Promise<VirtualActionIntent | null> {
    if (request.virtual !== true || request.dataTaskIds.length !== 0 ||
      request.allowedActionIds.length !== 1 ||
      request.personaId === undefined || request.inputText === undefined) {
      return null;
    }
    const actionId = request.allowedActionIds[0];
    if (actionId !== MEMORY_ACTION_ID) {
      const originalQuery = request.inputText.trim();
      if (!isInitialRegisteredPageAction(actionId) || originalQuery.length === 0) {
        return null;
      }
      const args: InitialActionArgs = { originalQuery: originalQuery };
      const offer: ActionOffer = {
        offerId: 'initial-action:' + actionId,
        actionId: actionId,
        label: actionId,
        variant: 'primary',
        args: args
      };
      const intent: VirtualActionIntent = {
        sourceToolId: actionId,
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

interface InitialActionArgs {
  originalQuery: string;
}

function canaryPlanningContext(previousPersonaId: string): LeaderPlanningContext {
  const tools: LeaderToolMetadata[] = allToolDefinitions().map(
    (definition: ToolDefinition): LeaderToolMetadata => {
      const actions = definition.actions.slice();
      if (isInitialRegisteredPageAction(definition.toolId) &&
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
      'luckin.order.preview',
      'social.reply.draft',
      'mail.draft.create',
      'gmail.draft.create',
      'worldcup.open',
      'maps.route.open',
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
  private pageGeneration: number = 0;
  private pageFingerprint: string = '';

  constructor(options: MultiAgentCanaryOptions) {
    const conversationId: string = options.conversationId === undefined ?
      'aiphone-canary-' + Date.now().toString() : options.conversationId;
    this.conversationId = conversationId;
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
      dataTaskInputNormalizer: normalizeHotelSearchTaskInput,
      dataAuthorizer: authorizeHotelDataTask,
      dataExecutor: options.dataExecutor === undefined ?
        new StructuredHotelDataExecutor() : options.dataExecutor,
      uiRenderer: new SingleDataUiTaskRendererAdapter(new HotelUiRenderer(
        options.uiLayoutPlanner === undefined ? null : options.uiLayoutPlanner,
        6000
      )),
      surfaceWriter: writer,
      actionCatalog: catalog,
      actionExecutor: new CanaryRegisteredExecutor(
        aiphoneExecutor,
        options.onMemoryUpdate,
        options.onSurface
      ),
      virtualActionResolver: new MemoryIntentResolver(),
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
      stepId: ''
    };
    return this.runtime.runAction(action, execution);
  }

  runPageAction(
    clicked: A2uiAction,
    surface: A2uiSurfaceState,
    document: HtmlHomeDocument,
    generation: number
  ): Promise<boolean> {
    if (!Number.isSafeInteger(generation) || generation <= 0 ||
      surface.surfaceId.trim().length === 0 || clicked.args === undefined ||
      !isHtmlHomeActionAllowed(document, clicked)) {
      return Promise.resolve(false);
    }
    const sourceToolId = registeredPageSourceToolId(surface);
    const execution = resolveRegisteredPageAction(sourceToolId, clicked);
    if (execution === null || execution.args === undefined) {
      return Promise.resolve(false);
    }
    const fingerprint = surface.surfaceId + '\n' + surface.sequence.toString() + '\n' +
      sourceToolId + '\n' + JSON.stringify(surface);
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
      document
    );
    const context: MultiAgentCanaryActionContext = {
      conversationId: this.conversationId,
      turnId,
      surfaceId: surface.surfaceId,
      sourceToolId
    };
    return this.runAction(execution, context);
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
