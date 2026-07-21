import { AgentEvent, AgentEventKind } from './AgentEvent';
import { summarizeA2uiObservation } from './A2uiObservationDigest';
import { ConversationContext } from './ConversationContext';
import { ToolRegistry } from './ToolRegistry';
import { LocalModel } from '../model/LocalModel';
import { skillLogInfo, skillLogWarn } from '../skill/SkillLog';
import { buildSkillsSection, SkillSnapshot } from '../skill/SkillSnapshot';

export type AgentListener = (event: AgentEvent) => void;
export type UiRenderHandler = (description: string) => Promise<string[]>;

const UI_TOOL_NAME = 'ui';
const READ_TOOL_NAME = 'read';
const REACT_TAGS: string[] = ['Thought:', 'Execution:', 'Action:', 'Observation:', 'Final:'];

type ExecutionMode = 'parallel' | 'serial';

function padDatePart(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

function currentLocalDateTime(now: Date = new Date()): string {
  const offsetMinutes = -now.getTimezoneOffset();
  const sign = offsetMinutes >= 0 ? '+' : '-';
  const absoluteOffset = Math.abs(offsetMinutes);
  return now.getFullYear().toString() + '-' + padDatePart(now.getMonth() + 1) + '-' + padDatePart(now.getDate()) +
    'T' + padDatePart(now.getHours()) + ':' + padDatePart(now.getMinutes()) + ':' + padDatePart(now.getSeconds()) +
    sign + padDatePart(Math.floor(absoluteOffset / 60)) + ':' + padDatePart(absoluteOffset % 60);
}

class ToolCall {
  name: string;
  input: string;

  constructor(name: string, input: string) {
    this.name = name;
    this.input = input;
  }
}

class ActionPlan {
  mode: ExecutionMode;
  calls: ToolCall[];

  constructor(mode: ExecutionMode, calls: ToolCall[]) {
    this.mode = mode;
    this.calls = calls;
  }
}

class ProcessedObservation {
  text: string;
  shouldStop: boolean;
  failureKey: string;
  finalText: string;

  constructor(text: string, shouldStop: boolean, failureKey: string, finalText: string) {
    this.text = text;
    this.shouldStop = shouldStop;
    this.failureKey = failureKey;
    this.finalText = finalText;
  }
}

class ParallelToolFinish {
  index: number;
  call: ToolCall;
  observation: string | null;

  constructor(index: number, call: ToolCall, observation: string | null) {
    this.index = index;
    this.call = call;
    this.observation = observation;
  }
}

export class ReActAgentRunner {
  private model: LocalModel;
  private tools: ToolRegistry;
  private skillSnapshot: SkillSnapshot | null;
  private skillsInSystemPrompt: boolean;
  private maxSteps: number;
  private uiHandler: UiRenderHandler | null;

  constructor(
    model: LocalModel,
    tools: ToolRegistry,
    maxSteps: number,
    uiHandler?: UiRenderHandler,
    skillSnapshot?: SkillSnapshot,
    skillsInSystemPrompt: boolean = false
  ) {
    this.model = model;
    this.tools = tools;
    this.skillSnapshot = skillSnapshot ?? null;
    this.skillsInSystemPrompt = skillsInSystemPrompt;
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

      const plan = this.parseActionPlan(response);
      if (plan === null) {
        const responseText = response.length > 0 ? response : '(empty response)';
        listener(new AgentEvent(
          AgentEventKind.ERROR,
          `Model did not return an Action or Final answer.\n\nLLM response:\n${responseText}`
        ));
        return;
      }

      skillLogInfo(`ReActAgentRunner: execution=${plan.mode} toolCount=${plan.calls.length}`);

      const observationsForModel: string[] = [];
      try {
        if (plan.mode === 'parallel' && plan.calls.length > 1) {
          const parallelObservations = await this.executeParallelToolCalls(plan.calls, listener);
          if (parallelObservations === null) {
            return;
          }
          for (let index = 0; index < parallelObservations.length; index++) {
            observationsForModel.push(parallelObservations[index]);
          }
        } else {
          for (let index = 0; index < plan.calls.length; index++) {
            const call = plan.calls[index];
            const observation = await this.executeToolCall(call, listener);
            if (observation === null) {
              return;
            }
            listener(new AgentEvent(AgentEventKind.ACTION, `${call.name}(${call.input})`));
            const processed = this.processObservation(observation, listener);
            observationsForModel.push(processed.text);
            if (processed.shouldStop) {
              this.emitDigestFinal(processed, listener);
              return;
            }
          }
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : `${error}`;
        listener(new AgentEvent(AgentEventKind.ERROR, message));
        return;
      }

      scratchpad.push(response);
      for (const observationForModel of observationsForModel) {
        scratchpad.push(observationForModel);
      }
    }

    listener(new AgentEvent(AgentEventKind.ERROR, `Stopped after ${this.maxSteps} steps without a final answer.`));
  }

  private async executeParallelToolCalls(
    calls: ToolCall[],
    listener: AgentListener
  ): Promise<string[] | null> {
    const observationsForModel: string[] = [];
    const pending = new Map<number, Promise<ParallelToolFinish>>();

    for (let index = 0; index < calls.length; index++) {
      const call = calls[index];
      const finished = this.executeToolCall(call, listener).then(
        (value: string | null): ParallelToolFinish => new ParallelToolFinish(index, call, value),
        (reason: Error | Object | string | number | boolean | null | undefined): ParallelToolFinish => {
          const message = reason instanceof Error ? reason.message : `${reason}`;
          return new ParallelToolFinish(index, call, `Tool ${call.name} failed: ${message}`);
        }
      );
      pending.set(index, finished);
    }

    while (pending.size > 0) {
      const result = await Promise.race(pending.values());
      pending.delete(result.index);

      if (result.observation === null) {
        return null;
      }

      listener(new AgentEvent(AgentEventKind.ACTION, `${result.call.name}(${result.call.input})`));
      const processed = this.processObservation(result.observation, listener);
      observationsForModel.push(processed.text);
      if (processed.shouldStop) {
        this.emitDigestFinal(processed, listener);
        return null;
      }
    }

    return observationsForModel;
  }

  private async executeToolCall(call: ToolCall, listener: AgentListener): Promise<string | null> {
    if (call.name === UI_TOOL_NAME && this.tools.has(UI_TOOL_NAME)) {
      if (this.uiHandler === null) {
        listener(new AgentEvent(AgentEventKind.FINAL, call.input));
        return null;
      }
      return await this.runUiTool(call.input, listener);
    }

    if (call.name === READ_TOOL_NAME) {
      skillLogInfo(`ReActAgentRunner: executing skill read input=${call.input}`);
    }

    let observation: string;
    try {
      observation = await this.tools.run(call.name, call.input);
    } catch (error) {
      const message = error instanceof Error ? error.message : `${error}`;
      throw new Error(`Tool ${call.name} failed: ${message}`);
    }

    if (call.name === READ_TOOL_NAME) {
      this.emitSkillRead(call.input, observation, listener);
    }
    return observation;
  }

  private processObservation(observation: string, listener: AgentListener): ProcessedObservation {
    const digest = summarizeA2uiObservation(observation);
    const text = digest.isA2ui ? digest.text : `Observation: ${observation}`;
    listener(new AgentEvent(AgentEventKind.OBSERVATION, text));
    return new ProcessedObservation(
      text,
      digest.isA2ui && digest.shouldStop,
      digest.failureKey,
      digest.finalText
    );
  }

  private emitDigestFinal(processed: ProcessedObservation, listener: AgentListener): void {
    if (processed.failureKey.indexOf(':error') >= 0) {
      listener(new AgentEvent(AgentEventKind.FINAL, '工具执行失败，结果已更新到主页。'));
      return;
    }
    if (processed.failureKey.length > 0) {
      listener(new AgentEvent(AgentEventKind.FINAL, '需要用户确认或授权，工具结果已更新到主页。'));
      return;
    }
    listener(new AgentEvent(AgentEventKind.FINAL,
      processed.finalText.length > 0 ? processed.finalText : '工具结果已更新到主页。'));
  }

  private emitSkillRead(input: string, observation: string, listener: AgentListener): void {
    if (this.skillSnapshot === null || !observation.startsWith('# Skill:')) {
      skillLogWarn(`ReActAgentRunner: skill read did not return skill content input=${input}`);
      return;
    }
    const skill = this.skillSnapshot.findByName(input.trim());
    if (skill !== null) {
      skillLogInfo(`ReActAgentRunner: skill selected name=${skill.name}`);
      listener(new AgentEvent(AgentEventKind.SKILL, skill.name));
    } else {
      skillLogWarn(`ReActAgentRunner: skill content returned but snapshot lookup failed input=${input}`);
    }
  }

  private parseJsonAction(action: string): ToolCall | null {
    const trimmed = action.trim();
    if (!trimmed.startsWith('{')) {
      return null;
    }
    try {
      const parsed = JSON.parse(trimmed) as Record<string, Object | string | number | boolean | null | undefined>;
      const operation = `${parsed.operation ?? ''}`;
      if (operation === 'search' || operation === 'execute') {
        return new ToolCall('modelscope', trimmed);
      }
    } catch (_error) {
    }
    return null;
  }

  private async runUiTool(description: string, listener: AgentListener): Promise<string> {
    if (this.uiHandler === null) {
      throw new Error('UI rendering is not available for this agent.');
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
    let prompt = 'Current device local datetime: ' + currentLocalDateTime() + '. Resolve relative dates yourself before calling tools.\n';
    prompt += this.buildParallelExecutionRules();
    prompt += 'Every tool call must use exactly this syntax on one line: Action: tool_name(input) or Action: tool_name[input]. The tool name is mandatory; never put raw JSON directly after Action:.\n';
    prompt += 'When a tool needs parameters, follow its description and pass structured values as valid JSON inside Action parentheses or brackets; use normal JSON arrays like ["a@example.com"], and do not pass bare keywords when a schema is required.\n';
    if (this.uiHandler !== null) {
      prompt += 'Use the ui tool when the user wants something shown on screen (card, form, dashboard, visual summary).\n';
    } else {
      prompt += 'Do not call ui unless it is listed in Tools. If a tool observation already contains UI or protocol output, return Final with a concise summary.\n';
    }
    prompt += 'When tools expose risk labels, prefer read or draft tools over blocked tools. Use blocked tools only when the user explicitly asks to bypass review or confirmation.\n';
    prompt += 'If a tool observation already contains UI or A2UI protocol output, return Final; the visible result is already on screen.\n';
    prompt += 'Tools that require confirmation, user input, blocked actions, sending, payment, or irreversible writes must stop for user confirmation instead of bypassing review.\n';
    if (this.tools.has('modelscope')) {
      prompt += 'Call modelscope only for an activated ModelScope MCP. First call modelscope with operation=search and the full task; then execute one returned qualifiedName whose risk is read.\n';
      prompt += 'Never invent a ModelScope qualifiedName. If ModelScope blocks an unsafe or unannotated tool, stop and explain that a real confirmation flow is required.\n';
    }
    prompt += 'Calendar write rule: when the requested end state creates, updates, moves, or deletes a Google Calendar event, use the matching calendar.event.* write tool, never calendar.events.search. For an update or move with an incomplete destination time, call calendar.event.update with the existing-event query/timeMin/timeMax selector and omit missing new start or end; the client will keep real matches visible and ask for the missing time without writing. Never ask the user for an Event ID.\n';
    prompt += 'Use other tools or Final for plain text answers.\n\n';

    if (conversation !== undefined && !conversation.isEmpty()) {
      prompt += conversation.formatPriorConversation();
    }

    if (!this.skillsInSystemPrompt) {
      const skillsSection = buildSkillsSection(this.skillSnapshot);
      if (skillsSection.length > 0) {
        prompt += `${skillsSection}\n\n`;
      }
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

  private buildParallelExecutionRules(): string {
    return 'Before calling tools, decide whether they can run in parallel. Add Execution: parallel or Execution: serial on its own line after Thought:.\n'
      + 'Use Execution: parallel only when every Action in this reply is independent (no output from one is needed by another). Good examples: time[] plus note[...].\n'
      + 'Use Execution: serial when tools depend on each other, when using read or ui, or when modelscope needs search then execute across steps.\n'
      + 'For parallel execution, emit multiple Action: lines (one tool per line). For serial execution with multiple tools, also emit multiple Action: lines in the required order.\n'
      + 'For a single independent tool, use Execution: serial with one Action: line.\n';
  }

  private emitResponse(response: string, listener: AgentListener): void {
    const thought = this.readLineValue(response, 'Thought:');
    if (thought !== null) {
      listener(new AgentEvent(AgentEventKind.THOUGHT, thought));
    }
    const execution = this.readLineValue(response, 'Execution:');
    if (execution !== null) {
      skillLogInfo(`ReActAgentRunner: model chose execution=${execution.trim().toLowerCase()}`);
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

  private parseActionPlan(response: string): ActionPlan | null {
    const actionTexts = this.extractTaggedLines(response, 'Action:');
    if (actionTexts.length === 0) {
      return null;
    }

    const calls: ToolCall[] = [];
    for (let index = 0; index < actionTexts.length; index++) {
      const call = this.parseActionText(actionTexts[index]);
      if (call !== null) {
        calls.push(call);
      }
    }
    if (calls.length === 0) {
      return null;
    }

    return new ActionPlan(this.parseExecutionMode(response, calls), calls);
  }

  private parseExecutionMode(response: string, calls: ToolCall[]): ExecutionMode {
    const raw = this.readLineValue(response, 'Execution:');
    if (raw === null) {
      return 'serial';
    }

    const normalized = raw.trim().toLowerCase();
    if (normalized === 'parallel' && calls.length > 1 && !this.hasParallelUnsafeTools(calls)) {
      return 'parallel';
    }
    return 'serial';
  }

  private hasParallelUnsafeTools(calls: ToolCall[]): boolean {
    for (let index = 0; index < calls.length; index++) {
      const name = calls[index].name;
      if (name === READ_TOOL_NAME || name === UI_TOOL_NAME || name === 'composio' || name === 'modelscope') {
        return true;
      }
    }
    return false;
  }

  private extractTaggedLines(text: string, prefix: string): string[] {
    const values: string[] = [];
    const lines = text.split(/\r?\n/);
    for (let index = 0; index < lines.length; index++) {
      const trimmed = lines[index].trim();
      if (trimmed.startsWith(prefix)) {
        values.push(trimmed.substring(prefix.length).trim());
      }
    }
    return values;
  }

  private parseActionText(action: string): ToolCall | null {
    const parenCall = this.parseDelimitedAction(action, '(', ')');
    if (parenCall !== null) {
      return parenCall;
    }

    const bracketCall = this.parseDelimitedAction(action, '[', ']');
    if (bracketCall !== null) {
      return bracketCall;
    }

    return this.parseJsonAction(action);
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
