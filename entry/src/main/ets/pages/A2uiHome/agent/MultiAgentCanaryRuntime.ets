import {
  ActionArgsValidator,
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionOffer,
  ActionOfferContext,
  ActionPlanRequestPayload,
  ActionValidationResult,
  A2uiAction,
  A2uiSurfaceState,
  ClientActionAuthorizer,
  DataResult,
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
import { MultiAgentRuntime } from './MultiAgentRuntime';
import { MultiAgentTurnOutcome } from './MultiAgentRuntimeTypes';
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
  StructuredHotelDataExecutor,
  hotelOfferResolver
} from './HotelAgentRuntime';
import {
  HotelRegisteredActionExecutor,
  SystemUriOpener
} from './HotelRegisteredActionExecutor';

const MEMORY_ACTION_ID: string = 'memory.update';
const MEMORY_SUMMARY_LIMIT: number = 240;

export interface MultiAgentCanaryOptions {
  model: LocalModel;
  selectedPersonaId: () => string;
  opener: SystemUriOpener;
  onSurface: HotelSurfaceCallback;
  onMemoryUpdate: (update: PersonaMemoryUpdateRequest) => void;
  downstreamWriter?: UiSurfaceWriter;
  uiLayoutPlanner?: UiLayoutPlanner;
  settingsFingerprint?: string;
  submitTimeoutMs?: number;
  actionTimeoutMs?: number;
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
    return validateHotelActionArgs(actionId, args);
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
  async resolve(request: ActionPlanRequestPayload): Promise<VirtualActionIntent | null> {
    if (request.virtual !== true || request.dataTaskIds.length !== 0 ||
      request.allowedActionIds.length !== 1 ||
      request.allowedActionIds[0] !== MEMORY_ACTION_ID ||
      request.personaId === undefined || request.inputText === undefined) {
      return null;
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

class CanaryRegisteredExecutor implements RegisteredActionExecutor {
  private readonly hotel: HotelRegisteredActionExecutor;
  private readonly onMemoryUpdate: (update: PersonaMemoryUpdateRequest) => void;
  private readonly onSurface: HotelSurfaceCallback;
  private sequence: number = 0;

  constructor(
    hotel: HotelRegisteredActionExecutor,
    onMemoryUpdate: (update: PersonaMemoryUpdateRequest) => void,
    onSurface: HotelSurfaceCallback
  ) {
    this.hotel = hotel;
    this.onMemoryUpdate = onMemoryUpdate;
    this.onSurface = onSurface;
  }

  async execute(
    actionId: string,
    args: Object,
    context: ActionExecutionContext
  ): Promise<ActionExecutionResult> {
    if (actionId !== MEMORY_ACTION_ID) {
      return this.hotel.execute(actionId, args, context);
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
  const hotel = toolDefinitionForToolId('hotel.search');
  const tools: LeaderToolMetadata[] = [];
  if (hotel !== null) {
    tools.push({
      toolId: hotel.toolId,
      intent: hotel.intent,
      riskLevel: hotel.riskLevel,
      inputSchema: hotel.inputSchema,
      outputSchema: hotel.outputSchema,
      actions: hotel.actions.slice()
    });
  }
  const memory = memoryDefinition();
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
    personas: leaderPersonaContext(previousPersonaId)
  };
}

export class MultiAgentCanaryRuntime {
  private readonly runtime: MultiAgentRuntime;
  private readonly authority: HotelSurfaceAuthority;
  private readonly surfaceWriter: HotelRuntimeSurfaceWriter;

  constructor(options: MultiAgentCanaryOptions) {
    const conversationId: string = options.conversationId === undefined ?
      'aiphone-canary-' + Date.now().toString() : options.conversationId;
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
    const hotelExecutor = new HotelRegisteredActionExecutor(
      catalog,
      options.opener,
      followUpIds
    );
    const initialContext = canaryPlanningContext(options.selectedPersonaId());
    this.runtime = new MultiAgentRuntime({
      conversationId,
      bus: options.bus,
      planner: new MultiAgentLeaderPlanner(options.model),
      planningContext: initialContext,
      planningContextProvider: (): LeaderPlanningContext =>
        canaryPlanningContext(options.selectedPersonaId()),
      dataAuthorizer: authorizeHotelDataTask,
      dataExecutor: options.dataExecutor === undefined ?
        new StructuredHotelDataExecutor() : options.dataExecutor,
      uiRenderer: new SingleDataUiTaskRendererAdapter(new HotelUiRenderer(
        options.uiLayoutPlanner === undefined ? null : options.uiLayoutPlanner,
        6000
      )),
      surfaceWriter: writer,
      actionCatalog: catalog,
      actionOfferResolver: async (
        data: DataResult,
        context: ActionOfferContext
      ): Promise<ActionOffer[]> => hotelOfferResolver(catalog)(data, context),
      actionExecutor: new CanaryRegisteredExecutor(
        hotelExecutor,
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
  }
}
