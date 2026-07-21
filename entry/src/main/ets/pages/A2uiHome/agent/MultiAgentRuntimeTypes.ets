import {
  ActionCatalog,
  ActionOfferResolver,
  ActionPlanCompiler,
  A2uiAction,
  DataTaskAuthorizer,
  DataTaskExecutor,
  DataTaskPlanner,
  LeaderPlanner,
  LeaderPlanningContext,
  LinkedMessageBus,
  RegisteredActionExecutor,
  TurnResultStatus,
  UiSurfaceWriter,
  UiTaskRenderer,
  VirtualActionIntentResolver
} from '@loop/agent-core';

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
  dataAuthorizer: DataTaskAuthorizer;
  dataExecutor: DataTaskExecutor;
  uiRenderer: UiTaskRenderer;
  surfaceWriter: UiSurfaceWriter;
  actionCatalog: ActionCatalog;
  actionOfferResolver: ActionOfferResolver;
  actionExecutor: RegisteredActionExecutor;
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
