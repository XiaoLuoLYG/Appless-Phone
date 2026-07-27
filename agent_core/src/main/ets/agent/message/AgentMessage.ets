export enum AgentMessageType {
  INPUT_USER = 'INPUT.USER',
  TASK_CREATE_UI = 'TASK.CREATE.UI',
  TASK_CREATE_DATA = 'TASK.CREATE.DATA',
  TASK_RESULT_UI = 'TASK.RESULT.UI',
  TASK_RESULT_DATA = 'TASK.RESULT.DATA',
  TASK_ERROR = 'TASK.ERROR',
  ACTION_PLAN_DRAFT = 'ACTION.PLAN.DRAFT',
  ACTION_OFFERS_READY = 'ACTION.OFFERS.READY',
  ACTION_PLAN_READY = 'ACTION.PLAN.READY',
  ACTION_RUN = 'ACTION.RUN',
  ACTION_PROGRESS = 'ACTION.PROGRESS',
  ACTION_RESULT = 'ACTION.RESULT',
  TURN_CANCEL = 'TURN.CANCEL',
  ACTION_PLAN_REQUEST = 'ACTION.PLAN.REQUEST',
  TURN_RESULT = 'TURN.RESULT'
}

export interface AgentMessage {
  type: AgentMessageType;
  conversationId: string;
  turnId: string;
  taskId: string;
  payload: Object;
}

export type RuntimeOwner = 'multi_agent' | 'legacy';

export type TurnConversationRole = 'user' | 'assistant';

export interface ConversationTurnMessage {
  role: TurnConversationRole;
  content: string;
}

export interface CurrentSurfaceSummary {
  surfaceId: string;
  kind: string;
  status: string;
  entityRefs: string[];
  actionOfferIds: string[];
}

export interface ObservationDigest {
  taskId: string;
  toolId: string;
  status: string;
  summary: string;
  entityRefs: string[];
}

export interface UserInputPayload {
  text: string;
  recentMessages?: ConversationTurnMessage[];
  previousPersonaId?: string;
  currentSurfaceSummary?: CurrentSurfaceSummary;
  recentObservations?: ObservationDigest[];
}

export type TurnResultStatus = 'success' | 'partial' | 'empty' | 'error' | 'canceled';

export interface TurnResultPayload {
  status: TurnResultStatus;
  surfaceId?: string;
  roundCount: number;
  message: string;
  personaId?: string;
  skillId?: string;
}

export interface UiTaskPayload {
  component: string;
  data: Object;
}

export interface DataTaskPayload {
  toolId: string;
  input: Object;
}

export interface UiResultPayload {
  surfaceId: string;
  data: Object;
}

export interface TaskErrorPayload {
  code: string;
  message: string;
  retryable?: boolean;
}
