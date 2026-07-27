import { MessageDrivenAgent } from '../MessageDrivenAgent';
import {
  AgentMessage,
  AgentMessageType,
  ObservationDigest,
  TaskErrorPayload
} from '../message/AgentMessage';
import { DataResult } from '../message/DataResult';
import { LinkedMessageBus } from '../message/LinkedMessageBus';
import {
  dataAgentToolDefinitions
} from '../../aiphone/runtime/ToolDefinitionRegistry';
import { ToolDefinition } from '../../aiphone/runtime/ToolDefinitionTypes';
import {
  CreateDataTaskPayload,
  DataStepDecision,
  DataTaskAuthorizationResult,
  DataTaskAuthorizer,
  DataTaskExecutor,
  DataTaskPlanner
} from './DataAgentTypes';

const MAX_DATA_CALLS: number = 3;
const DYNAMIC_SEARCH_TOOL_ID: string = 'dynamic.search';
const DYNAMIC_SEARCH_OUTPUT_SCHEMA: string = 'dynamicToolConnect';

export class DataAgent extends MessageDrivenAgent {
  private readonly bus: LinkedMessageBus;
  private readonly authorizer: DataTaskAuthorizer;
  private readonly executor: DataTaskExecutor;
  private readonly planner: DataTaskPlanner | null;
  private readonly dataTools: Map<string, ToolDefinition> = new Map<string, ToolDefinition>();
  private readonly canceled: Set<string> = new Set<string>();
  private readonly runningTasks: Set<string> = new Set<string>();
  private active: boolean = false;
  private generation: number = 0;

  constructor(
    bus: LinkedMessageBus,
    authorizer: DataTaskAuthorizer,
    executor: DataTaskExecutor,
    planner?: DataTaskPlanner
  ) {
    super(bus);
    this.bus = bus;
    this.authorizer = authorizer;
    this.executor = executor;
    this.planner = planner === undefined ? null : planner;
    const definitions: ToolDefinition[] = dataAgentToolDefinitions();
    for (let index = 0; index < definitions.length; index++) {
      this.dataTools.set(definitions[index].toolId, definitions[index]);
    }
  }

  start(): void {
    if (this.active) {
      return;
    }
    this.active = true;
    this.generation++;
    super.start();
  }

  stop(): void {
    this.active = false;
    this.generation++;
    super.stop();
    this.canceled.clear();
    this.runningTasks.clear();
  }

  protected accepts(message: AgentMessage): boolean {
    return message.type === AgentMessageType.TASK_CREATE_DATA ||
      message.type === AgentMessageType.TURN_CANCEL;
  }

  protected async process(message: AgentMessage): Promise<void> {
    const key: string = this.turnKey(message);
    if (message.type === AgentMessageType.TURN_CANCEL) {
      this.canceled.add(key);
      return;
    }
    if (this.canceled.has(key)) {
      return;
    }
    const task: CreateDataTaskPayload | null = this.dataTask(message.payload, message.taskId);
    if (task === null) {
      this.publishInputError(message, 'DATA_TASK_INVALID', 'Data task payload is malformed');
      return;
    }
    if (this.planner === null) {
      let authorization: DataTaskAuthorizationResult;
      try {
        authorization = this.authorizer(task);
      } catch (_error) {
        this.publishInputError(message, 'DATA_TASK_UNAUTHORIZED', 'Data task authorization failed');
        return;
      }
      if (!authorization.ok) {
        this.publishInputError(
          message,
          authorization.code.length === 0 ? 'DATA_TASK_UNAUTHORIZED' : authorization.code,
          authorization.message.length === 0 ? 'Data task is not authorized' : authorization.message
        );
        return;
      }
      this.execute(message, task, key, '');
      return;
    }
    if (!this.validToolIds(task.allowedToolIds as Object[])) {
      this.publishInputError(message, 'DATA_TASK_INVALID', 'Data task payload is malformed');
      return;
    }
    const taskKey: string = this.taskKey(message);
    if (this.runningTasks.has(taskKey)) {
      return;
    }
    this.runningTasks.add(taskKey);
    if (!this.allowedReadCall(task, task.toolId)) {
      this.publishInputError(message, 'TOOL_NOT_ALLOWED', 'Data task selected a disallowed tool');
      this.completeTask(taskKey, this.generation);
      return;
    }
    this.executePlanned(message, task, key, taskKey);
  }

  private execute(
    message: AgentMessage,
    task: CreateDataTaskPayload,
    key: string,
    taskKey: string
  ): void {
    const generation: number = this.generation;
    try {
      this.executor.execute(task)
        .then((result: DataResult) => {
          if (this.canPublish(key, generation)) {
            if (this.validResult(task, result)) {
              this.publishResult(message, result);
            } else {
              this.publishInputError(
                message,
                'DATA_TASK_OUTPUT_INVALID',
                'Data task output does not match the authorized task'
              );
            }
          }
          this.completeTask(taskKey, generation);
        })
        .catch((error: Object) => {
          if (this.canPublish(key, generation)) {
            this.publishError(message, error);
          }
          this.completeTask(taskKey, generation);
        });
    } catch (error) {
      if (this.canPublish(key, generation)) {
        this.publishError(message, error as Object);
      }
      this.completeTask(taskKey, generation);
    }
  }

  private executePlanned(
    message: AgentMessage,
    task: CreateDataTaskPayload,
    key: string,
    taskKey: string
  ): void {
    const generation: number = this.generation;
    this.runPlanned(message, task, key, taskKey, generation)
      .catch((error: Object) => {
        if (this.canPublish(key, generation)) {
          const detail: string = error instanceof Error ? error.message : `${error}`;
          this.publishInputError(message, 'DATA_PLAN_INVALID', detail);
        }
        this.completeTask(taskKey, generation);
      });
  }

  private async runPlanned(
    message: AgentMessage,
    task: CreateDataTaskPayload,
    key: string,
    taskKey: string,
    generation: number
  ): Promise<void> {
    const planner: DataTaskPlanner | null = this.planner;
    if (planner === null) {
      return;
    }
    const observations: ObservationDigest[] = [];
    const results: DataResult[] = [];
    let calls: number = 0;
    while (this.canPublish(key, generation)) {
      let decision: DataStepDecision;
      try {
        decision = await planner.next(task, observations.slice(), calls + 1);
      } catch (error) {
        if (this.canPublish(key, generation)) {
          const detail: string = error instanceof Error ? error.message : `${error}`;
          this.publishInputError(message, 'DATA_PLAN_INVALID', detail);
        }
        this.completeTask(taskKey, generation);
        return;
      }
      if (!this.canPublish(key, generation)) {
        this.completeTask(taskKey, generation);
        return;
      }
      if (!this.validDecision(decision)) {
        this.publishInputError(message, 'DATA_PLAN_INVALID', 'Data planner decision is malformed');
        this.completeTask(taskKey, generation);
        return;
      }
      if (decision.kind === 'finish') {
        const result: DataResult | null = this.finishedResult(task, decision.toolId, results);
        if (result === null) {
          this.publishInputError(
            message,
            'DATA_FINISH_INVALID',
            'Data finish must select an executed result matching the task'
          );
        } else {
          this.publishResult(message, result);
        }
        this.completeTask(taskKey, generation);
        return;
      }
      if (calls >= MAX_DATA_CALLS) {
        this.publishInputError(message, 'DATA_STEP_LIMIT', 'Data task cannot execute more than three calls');
        this.completeTask(taskKey, generation);
        return;
      }
      const callTask: CreateDataTaskPayload | null = this.plannedCallTask(task, decision);
      if (callTask === null) {
        this.publishInputError(message, 'TOOL_NOT_ALLOWED', 'Data planner selected a disallowed tool');
        this.completeTask(taskKey, generation);
        return;
      }
      let authorization: DataTaskAuthorizationResult;
      try {
        authorization = this.authorizer(callTask);
      } catch (_error) {
        this.publishInputError(message, 'DATA_TASK_UNAUTHORIZED', 'Data task authorization failed');
        this.completeTask(taskKey, generation);
        return;
      }
      if (!authorization.ok) {
        this.publishInputError(
          message,
          authorization.code.length === 0 ? 'DATA_TASK_UNAUTHORIZED' : authorization.code,
          authorization.message.length === 0 ? 'Data task is not authorized' : authorization.message
        );
        this.completeTask(taskKey, generation);
        return;
      }
      calls++;
      let result: DataResult;
      try {
        result = await this.executor.execute(callTask);
      } catch (error) {
        if (this.canPublish(key, generation)) {
          this.publishError(message, error as Object);
        }
        this.completeTask(taskKey, generation);
        return;
      }
      if (!this.canPublish(key, generation)) {
        this.completeTask(taskKey, generation);
        return;
      }
      if (!this.validResult(callTask, result)) {
        this.publishInputError(
          message,
          'DATA_TASK_OUTPUT_INVALID',
          'Data task output does not match the authorized call'
        );
        this.completeTask(taskKey, generation);
        return;
      }
      results.push(result);
      observations.push(this.observation(task.taskId, result));
      if (result.toolId === task.toolId) {
        this.publishResult(message, result);
        this.completeTask(taskKey, generation);
        return;
      }
    }
    this.completeTask(taskKey, generation);
  }

  private validDecision(decision: DataStepDecision): boolean {
    return decision !== null && typeof decision === 'object' && !Array.isArray(decision) &&
      Object.keys(decision).sort().join(',') === 'args,kind,summary,toolId' &&
      (decision.kind === 'call' || decision.kind === 'finish') &&
      typeof decision.toolId === 'string' && decision.toolId.trim().length > 0 &&
      decision.args !== null && typeof decision.args === 'object' && !Array.isArray(decision.args) &&
      typeof decision.summary === 'string' && decision.summary.trim().length > 0;
  }

  private plannedCallTask(
    task: CreateDataTaskPayload,
    decision: DataStepDecision
  ): CreateDataTaskPayload | null {
    if (!this.allowedReadCall(task, decision.toolId)) {
      return null;
    }
    const definition: ToolDefinition | undefined = this.dataTools.get(decision.toolId);
    let outputSchema: string;
    if (decision.toolId === DYNAMIC_SEARCH_TOOL_ID) {
      outputSchema = task.toolId === DYNAMIC_SEARCH_TOOL_ID ?
        task.outputSchema : DYNAMIC_SEARCH_OUTPUT_SCHEMA;
    } else if (definition !== undefined) {
      outputSchema = definition.outputSchema;
    } else {
      return null;
    }
    return {
      taskId: task.taskId,
      roundId: task.roundId,
      skillId: task.skillId,
      goal: task.goal,
      allowedToolIds: task.allowedToolIds.slice(),
      toolId: decision.toolId,
      outputSchema,
      args: decision.toolId === task.toolId ? task.args : decision.args,
      required: task.required
    };
  }

  private allowedReadCall(task: CreateDataTaskPayload, toolId: string): boolean {
    return task.allowedToolIds.indexOf(toolId) >= 0 &&
      (toolId === DYNAMIC_SEARCH_TOOL_ID || this.dataTools.has(toolId));
  }

  private finishedResult(
    task: CreateDataTaskPayload,
    toolId: string,
    results: DataResult[]
  ): DataResult | null {
    if (toolId !== task.toolId) {
      return null;
    }
    for (let index = results.length - 1; index >= 0; index--) {
      if (this.validResult(task, results[index])) {
        return results[index];
      }
    }
    return null;
  }

  private observation(taskId: string, result: DataResult): ObservationDigest {
    const providers: string[] = [];
    for (let index = 0; index < result.sources.length && providers.length < 4; index++) {
      const source = result.sources[index];
      const label: string = this.boundedText(source.provider + ':' + source.operation, 128);
      if (label.length > 1 && providers.indexOf(label) < 0) {
        providers.push(label);
      }
    }
    let summary: string = result.toolId + ' returned ' + result.status;
    if (providers.length > 0) {
      summary += ' via ' + providers.join(', ');
    }
    let entityRefs: string[] = [];
    if (result.data !== null && typeof result.data === 'object' && !Array.isArray(result.data)) {
      const values = result.data as Record<string, Object | string | number | boolean | null | undefined>;
      const rawRefs = values['entityRefs'];
      if (Array.isArray(rawRefs)) {
        entityRefs = this.boundedStrings(rawRefs as Object[], 16, 128);
      }
    }
    return {
      taskId: this.boundedText(taskId, 128),
      toolId: this.boundedText(result.toolId, 128),
      status: this.boundedText(result.status, 32),
      summary: this.boundedText(summary, 240),
      entityRefs
    };
  }

  private boundedStrings(values: Object[], maximum: number, length: number): string[] {
    const result: string[] = [];
    for (let index = 0; index < values.length && result.length < maximum; index++) {
      const value = values[index];
      if (typeof value === 'string' && value.trim().length > 0) {
        result.push(this.boundedText(value, length));
      }
    }
    return result;
  }

  private boundedText(value: string, maximum: number): string {
    const trimmed: string = value.trim();
    return trimmed.length > maximum ? trimmed.substring(0, maximum) : trimmed;
  }

  private completeTask(taskKey: string, generation: number): void {
    if (generation !== this.generation) {
      return;
    }
    this.runningTasks.delete(taskKey);
  }

  private canPublish(key: string, generation: number): boolean {
    return this.active && this.generation === generation && !this.canceled.has(key);
  }

  private publishResult(message: AgentMessage, result: DataResult): void {
    this.bus.publish({
      type: AgentMessageType.TASK_RESULT_DATA,
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: message.taskId,
      payload: result
    });
  }

  private publishError(message: AgentMessage, error: Object): void {
    const payload: TaskErrorPayload = {
      code: 'DATA_TASK_FAILED',
      message: error instanceof Error ? error.message : `${error}`
    };
    this.publishTaskError(message, payload);
  }

  private publishInputError(message: AgentMessage, code: string, detail: string): void {
    const payload: TaskErrorPayload = {
      code,
      message: detail
    };
    this.publishTaskError(message, payload);
  }

  private publishTaskError(message: AgentMessage, payload: TaskErrorPayload): void {
    this.bus.publish({
      type: AgentMessageType.TASK_ERROR,
      conversationId: message.conversationId,
      turnId: message.turnId,
      taskId: message.taskId,
      payload
    });
  }

  private dataTask(payload: Object, taskId: string): CreateDataTaskPayload | null {
    if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
      return null;
    }
    const values = payload as Record<string, Object | string | number | boolean | null | undefined>;
    const payloadTaskId = values['taskId'];
    const roundId = values['roundId'];
    const skillId = values['skillId'];
    const goal = values['goal'];
    const allowedToolIds = values['allowedToolIds'];
    const toolId = values['toolId'];
    const outputSchema = values['outputSchema'];
    const args = values['args'];
    const required = values['required'];
    if (typeof payloadTaskId !== 'string' || payloadTaskId !== taskId ||
      typeof roundId !== 'string' || roundId.trim().length === 0 ||
      typeof skillId !== 'string' ||
      typeof goal !== 'string' || goal.trim().length === 0 ||
      !Array.isArray(allowedToolIds) || allowedToolIds.length === 0 ||
      typeof toolId !== 'string' || toolId.trim().length === 0 ||
      typeof outputSchema !== 'string' || outputSchema.trim().length === 0 ||
      args === null || typeof args !== 'object' || Array.isArray(args) ||
      typeof required !== 'boolean') {
      return null;
    }
    return payload as CreateDataTaskPayload;
  }

  private validToolIds(values: Object[]): boolean {
    const seen: Set<string> = new Set<string>();
    for (let index = 0; index < values.length; index++) {
      const value = values[index];
      if (typeof value !== 'string' || value.trim().length === 0 || seen.has(value)) {
        return false;
      }
      seen.add(value);
    }
    return values.length > 0;
  }

  private validResult(task: CreateDataTaskPayload, result: DataResult): boolean {
    return result !== null && typeof result === 'object' &&
      result.toolId === task.toolId && result.outputSchema === task.outputSchema &&
      Array.isArray(result.sources) && Array.isArray(result.warnings) &&
      (result.status === 'success' || result.status === 'partial' ||
        result.status === 'empty' || result.status === 'error');
  }

  private turnKey(message: AgentMessage): string {
    return `${message.conversationId.length}:${message.conversationId}${message.turnId}`;
  }

  private taskKey(message: AgentMessage): string {
    return `${message.conversationId.length}:${message.conversationId}` +
      `${message.turnId.length}:${message.turnId}${message.taskId.length}:${message.taskId}`;
  }

}
