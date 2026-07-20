import { AgentEvent, AgentEventKind } from './AgentEvent';
import { summarizeA2uiObservation } from './A2uiObservationDigest';
import { ConversationContext } from './ConversationContext';
import { ToolRegistry } from './ToolRegistry';
import { LocalModel } from '../model/LocalModel';
import { aiLogInfo } from '../aiphone/runtime/AiphoneLogger';
import { skillLogInfo, skillLogWarn } from '../skill/SkillLog';
import { buildSkillsSection, SkillSnapshot } from '../skill/SkillSnapshot';
import { parseToolCallText, StreamingToolCallParser, ToolCall } from './StreamingToolCallParser';

export type AgentListener = (event: AgentEvent) => void;
export type UiRenderHandler = (description: string) => Promise<string[]>;

const UI_TOOL_NAME = 'ui';
const READ_TOOL_NAME = 'read';
const REACT_TAGS: string[] = ['Thought:', 'Action:', 'Observation:', 'Final:'];

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

class ToolRunOutcome {
  observation: string;
  error: string;

  constructor(observation: string, error: string) {
    this.observation = observation;
    this.error = error;
  }
}

class StreamingStepState {
  call: ToolCall | null = null;
  tool: Promise<ToolRunOutcome> | null = null;
  thoughtEmitted: boolean = false;
  contentReceived: boolean = false;
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
      const streamParser = new StreamingToolCallParser();
      const streamState = new StreamingStepState();
      try {
        response = await this.model.complete(
          this.buildPrompt(task, scratchpad, conversation),
          conversation,
          (delta: string): void => {
            this.handleModelContent(delta, streamParser, streamState, listener);
          }
        );
        if (!streamState.contentReceived) {
          this.handleModelContent(response, streamParser, streamState, listener);
        }
        streamParser.finish();
      } catch (error) {
        const message = error instanceof Error ? error.message : `${error}`;
        listener(new AgentEvent(AgentEventKind.ERROR, message));
        return;
      }

      if (!streamState.thoughtEmitted) {
        this.emitResponse(response, listener);
      }

      if (streamState.call === null) {
        const finalAnswer = this.readLineValue(response, 'Final:');
        if (finalAnswer !== null) {
          listener(new AgentEvent(AgentEventKind.FINAL, finalAnswer));
          return;
        }
      }

      const call = streamState.call ?? this.parseAction(response);
      if (call === null) {
        listener(new AgentEvent(AgentEventKind.ERROR, 'Model did not return an Action or Final answer.'));
        return;
      }

      if (streamState.call === null) {
        listener(new AgentEvent(AgentEventKind.ACTION, `${call.name}(${call.input})`));
      }

      let observation: string;
      try {
        if (call.name === UI_TOOL_NAME) {
          if (this.uiHandler === null) {
            listener(new AgentEvent(AgentEventKind.FINAL, call.input));
            return;
          }
          observation = await this.runUiTool(call.input, listener);
        } else {
          if (call.name === READ_TOOL_NAME && streamState.tool === null) {
            skillLogInfo(`ReActAgentRunner: executing skill read input=${call.input}`);
          }
          if (streamState.tool !== null) {
            const outcome = await streamState.tool;
            if (outcome.error.length > 0) {
              throw new Error(outcome.error);
            }
            observation = outcome.observation;
          } else {
            observation = await this.tools.run(call.name, call.input);
          }
          if (call.name === READ_TOOL_NAME) {
            this.emitSkillRead(call.input, observation, listener);
          }
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : `${error}`;
        listener(new AgentEvent(AgentEventKind.ERROR, `Tool ${call.name} failed: ${message}`));
        return;
      }

      const digest = summarizeA2uiObservation(observation);
      const observationForModel = digest.isA2ui ? digest.text : `Observation: ${observation}`;
      scratchpad.push(response);
      scratchpad.push(observationForModel);
      listener(new AgentEvent(AgentEventKind.OBSERVATION, observationForModel));

      if (digest.isA2ui && digest.shouldStop) {
        if (digest.failureKey.indexOf(':error') >= 0) {
          listener(new AgentEvent(AgentEventKind.FINAL, '工具执行失败，结果已更新到主页。'));
        } else if (digest.failureKey.length > 0) {
          listener(new AgentEvent(AgentEventKind.FINAL, '需要用户确认或授权，工具结果已更新到主页。'));
        } else {
          listener(new AgentEvent(AgentEventKind.FINAL,
            digest.finalText.length > 0 ? digest.finalText : '工具结果已更新到主页。'));
        }
        return;
      }
    }

    listener(new AgentEvent(AgentEventKind.ERROR, `Stopped after ${this.maxSteps} steps without a final answer.`));
  }

  private startTool(call: ToolCall): Promise<ToolRunOutcome> {
    return this.tools.run(call.name, call.input).then(
      (observation: string): ToolRunOutcome => new ToolRunOutcome(observation, ''),
      (error: Error | Object | string | number | boolean | null | undefined): ToolRunOutcome => {
        const message = error instanceof Error ? error.message : `${error}`;
        return new ToolRunOutcome('', message);
      }
    );
  }

  private handleModelContent(
    delta: string,
    parser: StreamingToolCallParser,
    state: StreamingStepState,
    listener: AgentListener
  ): void {
    if (delta.length === 0) {
      return;
    }
    state.contentReceived = true;
    const call = parser.feed(delta);
    if (call === null || state.call !== null) {
      return;
    }

    state.call = call;
    this.emitResponse(parser.leadingText(), listener);
    state.thoughtEmitted = true;
    listener(new AgentEvent(AgentEventKind.ACTION, `${call.name}(${call.input})`));
    aiLogInfo('[AIPhone][ModelToolCallReady] toolId=' + call.name +
      ' inputChars=' + call.input.length.toString());
    if (call.name !== UI_TOOL_NAME) {
      if (call.name === READ_TOOL_NAME) {
        skillLogInfo(`ReActAgentRunner: executing skill read input=${call.input}`);
      }
      state.tool = this.startTool(call);
    }
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
    prompt += 'Current device local datetime: ' + currentLocalDateTime() + '. Resolve relative dates yourself before calling tools.\n';
    prompt += 'Use Thought, tool calls, Observation, and Final. Never end a response after Thought alone.\n';
    prompt += 'When calling a tool, output exactly one <appless_tool>tool.name({"query":"value"})</appless_tool> on the line immediately after Thought. For example: Thought: I need nearby restaurants.\n<appless_tool>food.search({"query":"restaurants near Hongqiao Railway Station"})</appless_tool>\n';
    prompt += 'Do not merely say that you will use a tool: emit the XML tool call. Use a JSON object in parentheses, use normal JSON arrays like ["a@example.com"], and do not pass bare keywords. After </appless_tool>, you may continue with ordinary status text, but never emit another tool call in the same response.\n';
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
    prompt += '\nOutput contract for the next step:\n';
    prompt += 'If a tool is needed, do not stop after Thought or merely announce the tool. Emit exactly one <appless_tool>tool.name({"key":"value"})</appless_tool>. Ordinary status text may follow its closing tag.\n';
    prompt += 'If no tool is needed, emit Thought followed by Final.\n';
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

  private parseAction(response: string): ToolCall | null {
    const action = this.readLineValue(response, 'Action:');
    if (action === null) {
      return null;
    }
    return parseToolCallText(action);
  }
}
