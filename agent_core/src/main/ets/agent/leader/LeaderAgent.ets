import { MessageDrivenAgent } from '../MessageDrivenAgent';
import {
  AgentMessage,
  AgentMessageType,
  TaskErrorPayload
} from '../message/AgentMessage';
import { LinkedMessageBus } from '../message/LinkedMessageBus';
import {
  InputUserPayload,
  LeaderDataTask,
  LeaderPlan,
  LeaderPlanner,
  LeaderUiTask
} from './LeaderTypes';

interface LeaderTurnState {
  conversationId: string;
  turnId: string;
  inputTaskId: string;
  uiTaskId: string;
  dataTaskId: string;
  uiDone: boolean;
  dataDone: boolean;
  terminal: boolean;
  timerId: number;
  releasePlanning: (() => void) | null;
}

export class LeaderAgent extends MessageDrivenAgent {
  private readonly bus: LinkedMessageBus;
  private readonly planner: LeaderPlanner;
  private readonly timeoutMs: number;
  private readonly turns: Map<string, LeaderTurnState> = new Map<string, LeaderTurnState>();

  constructor(bus: LinkedMessageBus, planner: LeaderPlanner, timeoutMs: number = 30000) {
    super(bus);
    this.bus = bus;
    this.planner = planner;
    this.timeoutMs = timeoutMs > 0 ? timeoutMs : 30000;
  }

  stop(): void {
    this.turns.forEach((state: LeaderTurnState) => {
      this.finishTurn(state);
    });
    this.turns.clear();
    super.stop();
  }

  protected accepts(message: AgentMessage): boolean {
    return message.type === AgentMessageType.INPUT_USER ||
      message.type === AgentMessageType.TASK_RESULT_UI ||
      message.type === AgentMessageType.TASK_RESULT_DATA ||
      message.type === AgentMessageType.ACTION_RESULT ||
      message.type === AgentMessageType.TASK_ERROR ||
      message.type === AgentMessageType.TURN_CANCEL;
  }

  protected async process(message: AgentMessage): Promise<void> {
    if (message.type === AgentMessageType.INPUT_USER) {
      await this.handleInput(message);
      return;
    }
    if (!this.hasCorrelation(message)) {
      return;
    }
    const state: LeaderTurnState | undefined = this.turns.get(this.turnKey(message));
    if (state === undefined || state.terminal) {
      return;
    }
    if (message.type === AgentMessageType.TURN_CANCEL) {
      this.finishTurn(state);
      return;
    }
    if (message.type === AgentMessageType.ACTION_RESULT) {
      return;
    }
    if (message.type === AgentMessageType.TASK_RESULT_UI && message.taskId === state.uiTaskId) {
      state.uiDone = true;
    } else if (message.type === AgentMessageType.TASK_RESULT_DATA && message.taskId === state.dataTaskId) {
      state.dataDone = true;
    } else if (message.type === AgentMessageType.TASK_ERROR) {
      if (message.taskId === state.uiTaskId) {
        state.uiDone = true;
      } else if (message.taskId === state.dataTaskId) {
        state.dataDone = true;
      } else if (message.taskId === state.inputTaskId) {
        this.finishTurn(state);
        return;
      } else {
        return;
      }
    } else {
      return;
    }
    if (state.uiDone && state.dataDone) {
      this.finishTurn(state);
    }
  }

  private async handleInput(message: AgentMessage): Promise<void> {
    if (!this.hasCorrelation(message)) {
      return;
    }
    const inputRecord = message.payload as Record<string, Object | string | number | boolean | null | undefined>;
    const inputText: Object | string | number | boolean | null | undefined = inputRecord['text'];
    if (typeof inputText !== 'string' || inputText.trim().length === 0) {
      this.publishError(message, 'LEADER_INPUT_INVALID', 'User input text must not be empty');
      return;
    }
    const input: InputUserPayload = { text: inputText };
    const key: string = this.turnKey(message);
    if (this.turns.has(key)) {
      return;
    }
    const state: LeaderTurnState = {
      conversationId: message.conversationId,
      turnId: message.turnId,
      inputTaskId: message.taskId,
      uiTaskId: '',
      dataTaskId: '',
      uiDone: false,
      dataDone: false,
      terminal: false,
      timerId: -1,
      releasePlanning: null
    };
    const timeoutSignal: Promise<void> = new Promise<void>((resolve: () => void) => {
      state.releasePlanning = resolve;
    });
    this.turns.set(key, state);
    state.timerId = setTimeout(() => {
      this.timeoutTurn(key);
    }, this.timeoutMs);
    try {
      const outcome: LeaderPlan | void = await Promise.race([this.planner.plan(message, input), timeoutSignal]);
      state.releasePlanning = null;
      if (state.terminal) {
        return;
      }
      const plan: LeaderPlan = outcome as LeaderPlan;
      if (!this.validPlan(plan)) {
        this.finishTurn(state);
        this.publishError(message, 'LEADER_PLAN_INVALID', 'Leader plan task fields must be non-empty and unique');
        return;
      }
      state.uiTaskId = plan.ui.taskId;
      state.dataTaskId = plan.data.taskId;
      this.publishUiTask(message, plan.ui);
      this.publishDataTask(message, plan.data);
    } catch (error) {
      state.releasePlanning = null;
      if (state.terminal) {
        return;
      }
      this.finishTurn(state);
      const detail: string = error instanceof Error ? error.message : `${error}`;
      this.publishError(message, 'LEADER_PLAN_FAILED', detail);
    }
  }

  private hasCorrelation(message: AgentMessage): boolean {
    return this.nonEmptyString(message.conversationId) &&
      this.nonEmptyString(message.turnId) &&
      this.nonEmptyString(message.taskId);
  }

  private nonEmptyString(value: string): boolean {
    return typeof value === 'string' && value.trim().length > 0;
  }

  private validPlan(plan: LeaderPlan): boolean {
    return plan.ui.taskId.trim().length > 0 &&
      plan.data.taskId.trim().length > 0 &&
      plan.ui.taskId !== plan.data.taskId &&
      plan.ui.intent.trim().length > 0 &&
      plan.ui.expectedOutputSchema.trim().length > 0 &&
      plan.data.toolId.trim().length > 0 &&
      plan.data.outputSchema.trim().length > 0;
  }

  private turnKey(message: AgentMessage): string {
    return `${message.conversationId.length}:${message.conversationId}${message.turnId}`;
  }

  private publishUiTask(input: AgentMessage, task: LeaderUiTask): void {
    const payload: LeaderUiTask = {
      taskId: task.taskId,
      intent: task.intent,
      expectedOutputSchema: task.expectedOutputSchema
    };
    this.bus.publish({
      type: AgentMessageType.TASK_CREATE_UI,
      conversationId: input.conversationId,
      turnId: input.turnId,
      taskId: task.taskId,
      payload
    });
  }

  private publishDataTask(input: AgentMessage, task: LeaderDataTask): void {
    const payload: LeaderDataTask = {
      taskId: task.taskId,
      toolId: task.toolId,
      outputSchema: task.outputSchema,
      args: task.args
    };
    this.bus.publish({
      type: AgentMessageType.TASK_CREATE_DATA,
      conversationId: input.conversationId,
      turnId: input.turnId,
      taskId: task.taskId,
      payload
    });
  }

  private publishError(message: AgentMessage, code: string, detail: string): void {
    const payload: TaskErrorPayload = {
      code,
      message: detail
    };
    this.bus.publish({
      type: AgentMessageType.TASK_ERROR,
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: message.taskId,
      payload
    });
  }

  private timeoutTurn(key: string): void {
    const state: LeaderTurnState | undefined = this.turns.get(key);
    if (state === undefined || state.terminal) {
      return;
    }
    state.terminal = true;
    state.timerId = -1;
    const payload: TaskErrorPayload = {
      code: 'LEADER_TURN_TIMEOUT',
      message: 'Leader turn timed out'
    };
    this.bus.publish({
      type: AgentMessageType.TASK_ERROR,
      conversationId: state.conversationId,
      turnId: state.turnId,
      taskId: state.inputTaskId,
      payload
    });
    this.releasePlanning(state);
  }

  private finishTurn(state: LeaderTurnState): void {
    state.terminal = true;
    this.clearTurnTimer(state);
    this.releasePlanning(state);
  }

  private clearTurnTimer(state: LeaderTurnState): void {
    if (state.timerId >= 0) {
      clearTimeout(state.timerId);
      state.timerId = -1;
    }
  }

  private releasePlanning(state: LeaderTurnState): void {
    const release: (() => void) | null = state.releasePlanning;
    state.releasePlanning = null;
    if (release !== null) {
      release();
    }
  }
}
