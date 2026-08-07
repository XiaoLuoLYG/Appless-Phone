import {
  ActionCatalog,
  ActionExecutionContext,
  ActionOfferResolver,
  ActionPlanCompiler,
  A2uiAction,
  DataTaskAuthorizer,
  DataTaskExecutor,
  DataTaskPlanner,
  LeaderBimContextUpdate,
  LeaderBimSuggestion,
  LeaderCurrentLocalDateProvider,
  LeaderPlanner,
  LeaderDataTaskInputNormalizer,
  LeaderPlanningContext,
  LinkedMessageBus,
  RegisteredActionExecutor,
  TurnResultStatus,
  UiLayoutPlanner,
  UiSurfaceWriter,
  UiTaskRenderer,
  VirtualActionIntentResolver,
  RuntimeOwner as CoreRuntimeOwner
} from '@loop/agent-core';
import {
  HotelActionIdFactory,
  RegisteredPageAction,
  SystemUriOpener
} from './AiphoneRegisteredActionExecutor';

export interface MultiAgentSettledOutcome {
  kind: 'settled';
  ok: boolean;
  status: TurnResultStatus;
  surfaceId: string;
  message: string;
  personaId: string;
  skillId: string;
  bimSuggestion?: LeaderBimSuggestion;
  bimContextUpdate?: LeaderBimContextUpdate;
}

export type RuntimeOwner = CoreRuntimeOwner;

export type MultiAgentTurnOutcome = MultiAgentSettledOutcome;

export interface MultiAgentRuntimeOptions {
  planner: LeaderPlanner;
  planningContext: LeaderPlanningContext;
  planningContextProvider?: (prompt: string) => LeaderPlanningContext;
  currentLocalDateProvider?: LeaderCurrentLocalDateProvider;
  dataTaskInputNormalizer?: LeaderDataTaskInputNormalizer;
  dataAuthorizer: DataTaskAuthorizer;
  dataExecutor: DataTaskExecutor;
  uiRenderer?: UiTaskRenderer;
  uiLayoutPlanner?: UiLayoutPlanner;
  uiLayoutTimeoutMs?: number;
  surfaceWriter: UiSurfaceWriter;
  actionCatalog: ActionCatalog;
  actionOfferResolver?: ActionOfferResolver;
  actionExecutor?: RegisteredActionExecutor;
  registeredPageAction?: RegisteredPageAction;
  systemUriOpener?: SystemUriOpener;
  actionIdFactory?: HotelActionIdFactory;
  bus?: LinkedMessageBus;
  conversationId?: string;
  dataPlanner?: DataTaskPlanner;
  actionCompiler?: ActionPlanCompiler;
  virtualActionResolver?: VirtualActionIntentResolver;
  submitTimeoutMs?: number;
  actionTimeoutMs?: number;
  settingsFingerprint?: string;
  surfaceTurnActivator?: (turnId: string, hostGeneration: number) => void;
  turnGenerationObserver?: (turnId: string, hostGeneration: number) => void;
  directActionAdmission?: (action: A2uiAction, context: ActionExecutionContext) => boolean;
}

export interface MultiAgentActionRequest {
  action: A2uiAction;
  conversationId: string;
  turnId: string;
  surfaceId: string;
  sourceToolId: string;
}
