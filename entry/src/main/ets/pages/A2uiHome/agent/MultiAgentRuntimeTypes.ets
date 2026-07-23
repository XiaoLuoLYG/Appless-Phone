import {
  ActionCatalog,
  ActionOfferResolver,
  ActionPlanCompiler,
  A2uiAction,
  LegacyHandoff,
  DataTaskAuthorizer,
  DataTaskExecutor,
  DataTaskPlanner,
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
  RuntimeOwner as CoreRuntimeOwner,
  RuntimeOwnershipDecision,
  ToolDefinition,
  allToolDefinitions,
  ownershipForPlan as decideOwnershipForPlan
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
}

const RUNTIME_OWNED_TOOL_IDS: string[] = allToolDefinitions().map(
  (definition: ToolDefinition): string => definition.toolId
);
RUNTIME_OWNED_TOOL_IDS.push('dynamic.search');

export const MIGRATED_TOOL_IDS: Set<string> = new Set<string>(RUNTIME_OWNED_TOOL_IDS);

export function ownershipForPlan(
  toolIds: string[],
  migratedToolIds: Set<string> = MIGRATED_TOOL_IDS
): RuntimeOwnershipDecision {
  return decideOwnershipForPlan(toolIds, migratedToolIds);
}

export type RuntimeOwner = CoreRuntimeOwner;

export interface MultiAgentHandoffOutcome extends LegacyHandoff {
  kind: 'handoff';
  reasonCode: string;
  personaId: string;
  skillId: string;
}

export type MultiAgentTurnOutcome = MultiAgentSettledOutcome | MultiAgentHandoffOutcome;

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
}

export interface MultiAgentActionRequest {
  action: A2uiAction;
  conversationId: string;
  turnId: string;
  surfaceId: string;
  sourceToolId: string;
}
