import { AgentEvent, AgentEventKind } from './AgentEvent';
import { A2uiObservationDigest, summarizeA2uiObservation } from './A2uiObservationDigest';
import { ConversationContext } from './ConversationContext';
import { ToolRegistry } from './ToolRegistry';
import { LocalModel } from '../model/LocalModel';

export type AgentListener = (event: AgentEvent) => void;
export type UiRenderHandler = (description: string) => Promise<string[]>;

const UI_TOOL_NAME = 'ui';
const MAX_PARALLEL_ACTIONS = 6;
const REACT_TAGS: string[] = ['Thought:', 'Action:', 'Observation:', 'Final:'];

class ToolCall {
  name: string;
  input: string;

  constructor(name: string, input: string) {
    this.name = name;
    this.input = input;
  }
}

class ToolExecutionResult {
  call: ToolCall;
  observationForModel: string;
  digest: A2uiObservationDigest;
  error: string;

  constructor(call: ToolCall, observationForModel: string, digest: A2uiObservationDigest, error: string = '') {
    this.call = call;
    this.observationForModel = observationForModel;
    this.digest = digest;
    this.error = error;
  }
}

export class ReActAgentRunner {
  private model: LocalModel;
  private tools: ToolRegistry;
  private maxSteps: number;
  private uiHandler: UiRenderHandler | null;

  constructor(
    model: LocalModel,
    tools: ToolRegistry,
    maxSteps: number,
    uiHandler?: UiRenderHandler
  ) {
    this.model = model;
    this.tools = tools;
    this.maxSteps = maxSteps;
    this.uiHandler = uiHandler ?? null;
  }

  async run(task: string, listener: AgentListener, conversation?: ConversationContext): Promise<void> {
    const scratchpad: string[] = [];

    for (let step = 0; step < this.maxSteps; step++) {
      let response: string;
      try {
        response = await this.model.complete(this.buildPrompt(task, scratchpad, conversation), conversation);
      } catch (error) {
        const message = error instanceof Error ? error.message : `${error}`;
        listener(new AgentEvent(AgentEventKind.ERROR, message));
        return;
      }

      this.emitResponse(response, listener);

      const finalAnswer = this.readLineValue(response, 'Final:');
      if (finalAnswer !== null) {
        listener(new AgentEvent(AgentEventKind.FINAL, finalAnswer));
        return;
      }

      const calls = this.parseActions(response);
      if (calls.length === 0) {
        listener(new AgentEvent(AgentEventKind.ERROR, 'Model did not return an Action or Final answer.'));
        return;
      }

      calls.forEach((call: ToolCall) => {
        listener(new AgentEvent(AgentEventKind.ACTION, `${call.name}(${call.input})`, call.name, call.input));
      });

      const tasks: Promise<ToolExecutionResult>[] = [];
      calls.forEach((call: ToolCall) => {
        tasks.push(this.executeToolCall(call, listener));
      });
      const executions: ToolExecutionResult[] = await Promise.all(tasks);
      let hasA2uiStop = false;
      let hasA2uiError = false;
      let hasA2uiFailure = false;
      let executionError = '';
      scratchpad.push(response);
      executions.forEach((execution: ToolExecutionResult) => {
        scratchpad.push(execution.observationForModel);
        listener(new AgentEvent(
          AgentEventKind.OBSERVATION,
          execution.observationForModel,
          execution.call.name,
          execution.call.input
        ));
        if (execution.error.length > 0 && executionError.length === 0) {
          executionError = execution.error;
        }
        if (execution.digest.isA2ui && execution.digest.shouldStop) {
          hasA2uiStop = true;
          if (execution.digest.failureKey.indexOf(':error') >= 0) {
            hasA2uiError = true;
          } else if (execution.digest.failureKey.length > 0) {
            hasA2uiFailure = true;
          }
        }
      });

      if (executionError.length > 0) {
        listener(new AgentEvent(AgentEventKind.ERROR, executionError));
        return;
      }

      if (hasA2uiStop) {
        if (hasA2uiError) {
          listener(new AgentEvent(AgentEventKind.FINAL, '工具执行失败，结果已更新到主页。'));
        } else if (hasA2uiFailure) {
          listener(new AgentEvent(AgentEventKind.FINAL, '需要用户确认或授权，工具结果已更新到主页。'));
        } else {
          const countText = executions.length > 1 ? executions.length.toString() + ' 个' : '';
          listener(new AgentEvent(AgentEventKind.FINAL, countText + '工具结果已更新到主页。'));
        }
        return;
      }
    }

    listener(new AgentEvent(AgentEventKind.ERROR, `Stopped after ${this.maxSteps} steps without a final answer.`));
  }

  private async executeToolCall(call: ToolCall, listener: AgentListener): Promise<ToolExecutionResult> {
    let observation = '';
    try {
      if (call.name === UI_TOOL_NAME) {
        if (this.uiHandler === null) {
          observation = call.input;
        } else {
          observation = await this.runUiTool(call.input, listener);
        }
      } else {
        observation = await this.tools.run(call.name, call.input);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : `${error}`;
      return new ToolExecutionResult(call, `Observation: Tool ${call.name} failed: ${message}`, summarizeA2uiObservation(''), `Tool ${call.name} failed: ${message}`);
    }
    const digest = summarizeA2uiObservation(observation);
    const observationForModel = digest.isA2ui ? digest.text : `Observation: ${observation}`;
    return new ToolExecutionResult(call, observationForModel, digest);
  }

  private async runUiTool(description: string, listener: AgentListener): Promise<string> {
    if (this.uiHandler === null) {
      return 'UI rendering is not available in this session.';
    }

    const prompt = description.trim().length > 0 ? description : 'Simple information card';
    try {
      const lines = await this.uiHandler(prompt);
      if (lines.length === 0) {
        return 'UI tool returned no protocol data.';
      }
      listener(new AgentEvent(AgentEventKind.UI, lines.join('\n')));
      return `Rendered on-screen UI (${lines.length} protocol lines) for: ${prompt}`;
    } catch (error) {
      const message = error instanceof Error ? error.message : `${error}`;
      return `UI render failed: ${message}`;
    }
  }

  private buildPrompt(task: string, scratchpad: string[], conversation?: ConversationContext): string {
    let prompt = 'You are Loop, a HarmonyOS ReAct agent with tools.\n';
    prompt += 'Use Thought, Action, Observation, and Final.\n';
    prompt += 'When an Action needs parameters, pass a JSON object in parentheses, for example Action: tool.name({"query":"value"}); use normal JSON arrays like ["a@example.com"], and do not pass bare keywords.\n';
    prompt += 'When one user request contains multiple independent tool goals and all arguments can be inferred from the request, return one Action line per goal in the same response, up to 6 Action lines. These Action lines run concurrently. Prefer this over choosing only one requested goal, and do not omit one merely because another tool renders UI.\n';
    if (this.uiHandler !== null) {
      prompt += 'Use the ui tool when the user wants something shown on screen (card, form, dashboard, visual summary).\n';
    } else {
      prompt += 'Do not call ui unless it is listed in Tools. If a tool observation already contains UI or protocol output, return Final with a concise summary.\n';
    }
    prompt += 'When tools expose risk labels, prefer read or draft tools over blocked tools. Use blocked tools only when the user explicitly asks to bypass review or confirmation.\n';
    prompt += 'If a tool observation already contains UI or A2UI protocol output, return Final; the visible result is already on screen.\n';
    prompt += 'Tools that require confirmation, user input, blocked actions, sending, payment, or irreversible writes must stop for user confirmation instead of bypassing review.\n';
    prompt += 'Use other tools or Final for plain text answers.\n\n';

    if (conversation !== undefined && !conversation.isEmpty()) {
      prompt += conversation.formatPriorConversation();
    }

    prompt += 'Tools:\n';
    prompt += this.tools.describeTools();
    prompt += '\nUser task:\n';
    prompt += task;
    prompt += '\n\n';

    for (const item of scratchpad) {
      prompt += `${item}\n`;
    }
    return prompt;
  }

  private emitResponse(response: string, listener: AgentListener): void {
    const thought = this.readLineValue(response, 'Thought:');
    if (thought !== null) {
      listener(new AgentEvent(AgentEventKind.THOUGHT, thought));
    }
  }

  private readLineValue(text: string, prefix: string): string | null {
    const start = this.findTagStart(text, prefix);
    if (start < 0) {
      return null;
    }
    const valueStart = start + prefix.length;
    const tail = text.substring(valueStart);
    const next = this.findNextTagStart(tail, prefix);
    const value = next < 0 ? tail : tail.substring(0, next);
    return value.trim();
  }

  private findTagStart(text: string, prefix: string): number {
    let searchFrom = 0;
    while (searchFrom < text.length) {
      const index = text.indexOf(prefix, searchFrom);
      if (index < 0) {
        return -1;
      }
      if (this.isTagBoundary(text, index)) {
        return index;
      }
      searchFrom = index + prefix.length;
    }
    return -1;
  }

  private findNextTagStart(text: string, currentPrefix: string): number {
    let result = -1;
    for (let index = 0; index < REACT_TAGS.length; index++) {
      const prefix = REACT_TAGS[index];
      if (prefix === currentPrefix) {
        continue;
      }
      const start = this.findTagStart(text, prefix);
      if (start >= 0 && (result < 0 || start < result)) {
        result = start;
      }
    }
    return result;
  }

  private isTagBoundary(text: string, index: number): boolean {
    if (index === 0) {
      return true;
    }
    const previous = text.charAt(index - 1);
    return previous === '\n' || previous === '\r' || previous === ' ' || previous === '\t';
  }

  private parseActions(response: string): ToolCall[] {
    const calls: ToolCall[] = [];
    let cursor = 0;
    while (cursor < response.length && calls.length < MAX_PARALLEL_ACTIONS) {
      const remaining = response.substring(cursor);
      const relativeStart = this.findTagStart(remaining, 'Action:');
      if (relativeStart < 0) {
        break;
      }
      const valueStart = cursor + relativeStart + 'Action:'.length;
      const tail = response.substring(valueStart);
      const next = this.findNextTagStart(tail, '');
      const action = (next < 0 ? tail : tail.substring(0, next)).trim();
      const call = this.parseActionValue(action);
      if (call !== null) {
        calls.push(call);
      }
      if (next < 0) {
        break;
      }
      cursor = valueStart + next;
    }
    return calls;
  }

  private parseActionValue(action: string): ToolCall | null {
    const parenCall = this.parseDelimitedAction(action, '(', ')');
    if (parenCall !== null) {
      return parenCall;
    }
    return this.parseDelimitedAction(action, '[', ']');
  }

  private parseDelimitedAction(action: string, openToken: string, closeToken: string): ToolCall | null {
    const open = action.indexOf(openToken);
    const close = action.lastIndexOf(closeToken);
    if (open <= 0 || close < open) {
      return null;
    }

    const name = action.substring(0, open).trim();
    const input = action.substring(open + 1, close).trim();
    return new ToolCall(name, input);
  }
}
