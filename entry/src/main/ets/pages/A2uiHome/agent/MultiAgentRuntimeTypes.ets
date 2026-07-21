import {
  ActionCatalog,
  ActionOfferResolver,
  ActionPlanCompiler,
  A2uiAction,
  DataTaskAuthorizer,
  DataTaskExecutor,
  DataTaskPlanner,
  LeaderPlanner,
  LeaderDataTaskInputNormalizer,
  LeaderPlanningContext,
  LinkedMessageBus,
  RegisteredActionExecutor,
  TurnResultStatus,
  UiLayoutPlanner,
  UiSurfaceWriter,
  UiTaskRenderer,
  VirtualActionIntentResolver
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
}

export interface MultiAgentHandoffOutcome {
  kind: 'handoff';
  reasonCode: string;
  personaId: string;
  skillId: string;
}

export type MultiAgentTurnOutcome = MultiAgentSettledOutcome | MultiAgentHandoffOutcome;

export interface MultiAgentRuntimeOptions {
  planner: LeaderPlanner;
  planningContext: LeaderPlanningContext;
  planningContextProvider?: () => LeaderPlanningContext;
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
  surfaceTurnActivator?: (turnId: string) => void;
}

export interface MultiAgentActionRequest {
  action: A2uiAction;
  conversationId: string;
  turnId: string;
  surfaceId: string;
  sourceToolId: string;
}
