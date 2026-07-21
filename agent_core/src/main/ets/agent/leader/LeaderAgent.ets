import { MessageDrivenAgent } from '../MessageDrivenAgent';
import {
  AgentMessage,
  AgentMessageType,
  ConversationTurnMessage,
  CurrentSurfaceSummary,
  ObservationDigest,
  TaskErrorPayload
} from '../message/AgentMessage';
import { LinkedMessageBus } from '../message/LinkedMessageBus';
import {
  InputUserPayload,
  LeaderDataTask,
  LeaderPlan,
  LeaderPlanner,
  LeaderPlanningContext,
  LeaderSkillMetadata,
  LeaderToolMetadata,
  LeaderUiTask
} from './LeaderTypes';
import { CreateUiTaskPayload } from '../ui/UiAgentTypes';
import { CreateDataTaskPayload } from '../data/DataAgentTypes';

interface LeaderTurnState {
  conversationId: string;
  turnId: string;
  inputTaskId: string;
  uiTaskId: string;
  dataTaskId: string;
  skillId: string;
  uiDone: boolean;
  dataDone: boolean;
  terminal: boolean;
  timerId: number;
  releasePlanning: (() => void) | null;
}

export class LeaderAgent extends MessageDrivenAgent {
  private readonly bus: LinkedMessageBus;
  private readonly planner: LeaderPlanner;
  private readonly planningContext: LeaderPlanningContext;
  private readonly timeoutMs: number;
  private readonly turns: Map<string, LeaderTurnState> = new Map<string, LeaderTurnState>();
  // Terminal state is reduced to exact identities so active turn payloads and
  // timers are released without permitting an old input to be dispatched twice.
  private readonly terminalTurns: Set<string> = new Set<string>();

  constructor(
    bus: LinkedMessageBus,
    planner: LeaderPlanner,
    planningContext: LeaderPlanningContext,
    timeoutMs: number = 30000
  ) {
    super(bus);
    this.bus = bus;
    this.planner = planner;
    this.planningContext = this.copyPlanningContext(planningContext);
    this.timeoutMs = timeoutMs > 0 ? timeoutMs : 30000;
  }

  stop(): void {
    this.turns.forEach((state: LeaderTurnState) => {
      this.finishTurn(state);
    });
    this.turns.clear();
    this.terminalTurns.clear();
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
      this.handleInput(message);
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

  private handleInput(message: AgentMessage): void {
    if (!this.hasCorrelation(message)) {
      return;
    }
    const inputRecord = message.payload as Record<string, Object | string | number | boolean | null | undefined>;
    const inputText: Object | string | number | boolean | null | undefined = inputRecord['text'];
    if (typeof inputText !== 'string' || inputText.trim().length === 0) {
      this.publishError(message, 'LEADER_INPUT_INVALID', 'User input text must not be empty');
      return;
    }
    const recentMessages = inputRecord['recentMessages'];
    const previousPersonaId = inputRecord['previousPersonaId'];
    const currentSurfaceSummary = inputRecord['currentSurfaceSummary'];
    const recentObservations = inputRecord['recentObservations'];
    const input: InputUserPayload = {
      text: inputText,
      recentMessages: Array.isArray(recentMessages) ? recentMessages as ConversationTurnMessage[] : [],
      previousPersonaId: typeof previousPersonaId === 'string' ? previousPersonaId : '',
      currentSurfaceSummary: currentSurfaceSummary !== null &&
        typeof currentSurfaceSummary === 'object' && !Array.isArray(currentSurfaceSummary) ?
        currentSurfaceSummary as CurrentSurfaceSummary : {
          surfaceId: '', kind: '', status: '', entityRefs: [], actionOfferIds: []
        },
      recentObservations: Array.isArray(recentObservations) ? recentObservations as ObservationDigest[] : []
    };
    const key: string = this.turnKey(message);
    if (this.turns.has(key) || this.terminalTurns.has(key)) {
      return;
    }
    const state: LeaderTurnState = {
      conversationId: message.conversationId,
      turnId: message.turnId,
      inputTaskId: message.taskId,
      uiTaskId: '',
      dataTaskId: '',
      skillId: '',
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
    this.startPlanning(message, input, state, timeoutSignal);
  }

  private startPlanning(
    message: AgentMessage,
    input: InputUserPayload,
    state: LeaderTurnState,
    timeoutSignal: Promise<void>
  ): void {
    try {
      Promise.race([
        this.planner.plan(message, input, this.copyPlanningContext(this.planningContext)),
        timeoutSignal
      ])
        .then((outcome: LeaderPlan | void) => {
          this.completePlanning(message, state, outcome);
        })
        .catch((error: Object) => {
          this.failPlanning(message, state, error);
        });
    } catch (error) {
      this.failPlanning(message, state, error);
    }
  }

  private completePlanning(message: AgentMessage, state: LeaderTurnState, outcome: LeaderPlan | void): void {
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
    const dataTask: LeaderDataTask = plan.dataTasks[0];
    state.dataTaskId = dataTask.taskId;
    state.skillId = plan.skillId;
    this.publishUiTask(message, plan.ui, dataTask.taskId);
    this.publishDataTask(message, dataTask);
  }

  private failPlanning(message: AgentMessage, state: LeaderTurnState, error: Object): void {
    state.releasePlanning = null;
    if (state.terminal) {
      return;
    }
    this.finishTurn(state);
    const detail: string = error instanceof Error ? error.message : `${error}`;
    this.publishError(message, 'LEADER_PLAN_FAILED', detail);
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
    if (plan === undefined || plan === null ||
      typeof plan.skillId !== 'string' ||
      !this.validSelectedSkill(plan.skillId) ||
      plan.ui === undefined || !Array.isArray(plan.dataTasks) || plan.dataTasks.length !== 1) {
      return false;
    }
    const dataTask: LeaderDataTask = plan.dataTasks[0];
    const tool: LeaderToolMetadata | null = this.toolMetadata(dataTask.toolId);
    if (tool === null || tool.riskLevel !== 'read' ||
      tool.outputSchema !== dataTask.outputSchema ||
      tool.outputSchema !== plan.ui.expectedOutputSchema) {
      return false;
    }
    return plan.ui.taskId.trim().length > 0 &&
      dataTask.taskId.trim().length > 0 &&
      plan.ui.taskId !== dataTask.taskId &&
      plan.ui.intent.trim().length > 0 &&
      plan.ui.expectedOutputSchema.trim().length > 0 &&
      plan.ui.expectedOutputSchema === dataTask.outputSchema &&
      dataTask.toolId.trim().length > 0 &&
      dataTask.outputSchema.trim().length > 0;
  }

  private validSelectedSkill(skillId: string): boolean {
    if (skillId.trim().length === 0) {
      return true;
    }
    for (let index = 0; index < this.planningContext.skills.length; index++) {
      if (this.planningContext.skills[index].skillId === skillId) {
        return true;
      }
    }
    return false;
  }

  private toolMetadata(toolId: string): LeaderToolMetadata | null {
    for (let index = 0; index < this.planningContext.tools.length; index++) {
      const tool = this.planningContext.tools[index];
      if (tool.toolId === toolId) {
        return tool;
      }
    }
    return null;
  }

  private turnKey(message: AgentMessage): string {
    return this.turnKeyFor(message.conversationId, message.turnId);
  }

  private publishUiTask(input: AgentMessage, task: LeaderUiTask, dataTaskId: string): void {
    const payload: CreateUiTaskPayload = {
      taskId: task.taskId,
      dataTaskIds: [dataTaskId],
      skillId: this.currentSkillId(input),
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
    const payload: CreateDataTaskPayload = {
      taskId: task.taskId,
      roundId: input.turnId,
      skillId: this.currentSkillId(input),
      goal: task.toolId,
      allowedToolIds: [task.toolId],
      toolId: task.toolId,
      outputSchema: task.outputSchema,
      args: task.args,
      required: true
    };
    this.bus.publish({
      type: AgentMessageType.TASK_CREATE_DATA,
      conversationId: input.conversationId,
      turnId: input.turnId,
      taskId: task.taskId,
      payload
    });
  }

  private currentSkillId(input: AgentMessage): string {
    const state: LeaderTurnState | undefined = this.turns.get(this.turnKey(input));
    if (state === undefined) {
      return '';
    }
    return state.skillId;
  }

  private copyPlanningContext(context: LeaderPlanningContext): LeaderPlanningContext {
    const tools: LeaderToolMetadata[] = [];
    const skills: LeaderSkillMetadata[] = [];
    for (let index = 0; index < context.tools.length; index++) {
      const tool = context.tools[index];
      tools.push({
        toolId: tool.toolId,
        intent: tool.intent,
        riskLevel: tool.riskLevel,
        inputSchema: tool.inputSchema,
        outputSchema: tool.outputSchema,
        actions: tool.actions.slice()
      });
    }
    for (let index = 0; index < context.skills.length; index++) {
      const skill = context.skills[index];
      skills.push({
        skillId: skill.skillId,
        description: skill.description,
        instructions: skill.instructions
      });
    }
    return { tools, skills };
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
    this.finishTurn(state);
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
  }

  private finishTurn(state: LeaderTurnState): void {
    if (state.terminal) {
      return;
    }
    state.terminal = true;
    this.clearTurnTimer(state);
    this.releasePlanning(state);
    const key: string = this.turnKeyFor(state.conversationId, state.turnId);
    if (this.turns.get(key) === state) {
      this.turns.delete(key);
    }
    this.rememberTerminalTurn(key);
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

  private rememberTerminalTurn(key: string): void {
    if (this.terminalTurns.has(key)) {
      return;
    }
    this.terminalTurns.add(key);
  }

  private turnKeyFor(conversationId: string, turnId: string): string {
    return `${conversationId.length}:${conversationId}${turnId}`;
  }
}
