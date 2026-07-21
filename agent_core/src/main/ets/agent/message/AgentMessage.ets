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
  TURN_CANCEL = 'TURN.CANCEL'
}

export interface AgentMessage {
  type: AgentMessageType;
  conversationId: string;
  turnId: string;
  taskId: string;
  payload: Object;
}

export interface UserInputPayload {
  text: string;
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
