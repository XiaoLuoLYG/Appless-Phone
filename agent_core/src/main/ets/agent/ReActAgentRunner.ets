import { AgentEvent, AgentEventKind } from './AgentEvent';
import { summarizeA2uiObservation } from './A2uiObservationDigest';
import { ConversationContext } from './ConversationContext';
import { ToolRegistry } from './ToolRegistry';
import { LocalModel } from '../model/LocalModel';
import { skillLogInfo, skillLogWarn } from '../skill/SkillLog';
import { buildSkillsSection, SkillSnapshot } from '../skill/SkillSnapshot';

export type AgentListener = (event: AgentEvent) => void;
export type UiRenderHandler = (description: string) => Promise<string[]>;

export interface ReActRunOptions {
  readonly identityPrompt?: string;
}

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

class ToolCall {
  name: string;
  input: string;

  constructor(name: string, input: string) {
    this.name = name;
    this.input = input;
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

  async run(
    task: string,
    listener: AgentListener,
    conversation?: ConversationContext,
    options?: ReActRunOptions
  ): Promise<void> {
    const scratchpad: string[] = [];

    for (let step = 0; step < this.maxSteps; step++) {
      let response: string;
      try {
        response = await this.model.complete(
          this.buildPrompt(task, scratchpad),
          conversation,
          this.buildSystemPrompt(options)
        );
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

      const call = this.parseAction(response);
      if (call === null) {
        const responseText = response.length > 0 ? response : '(empty response)';
        listener(new AgentEvent(
          AgentEventKind.ERROR,
          `Model did not return an Action or Final answer.\n\nLLM response:\n${responseText}`
        ));
        return;
      }

      listener(new AgentEvent(AgentEventKind.ACTION, `${call.name}(${call.input})`));

      let observation: string;
      try {
        if (call.name === UI_TOOL_NAME && this.tools.has(UI_TOOL_NAME)) {
          if (this.uiHandler === null) {
            throw new Error('UI rendering is not available for this agent.');
          }
          observation = await this.runUiTool(call.input, listener);
        } else {
          if (call.name === READ_TOOL_NAME) {
            skillLogInfo(`ReActAgentRunner: executing skill read input=${call.input}`);
          }
          observation = await this.tools.run(call.name, call.input);
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

  private buildSystemPrompt(options?: ReActRunOptions): string {
    const configuredIdentity = options?.identityPrompt?.trim() ?? '';
    let prompt = configuredIdentity.length > 0
      ? configuredIdentity
      : 'You are Loop, a HarmonyOS ReAct agent with tools.';
    prompt += '\n\nSTRICT REACT OUTPUT CONTRACT\n';
    prompt += 'Every assistant response must use exactly one of the following two forms.\n\n';
    prompt += 'Form 1 - finish or answer without a tool:\n';
    prompt += 'Thought: <one brief sentence explaining the next decision>\n';
    prompt += 'Final: <the answer or execution report>\n\n';
    prompt += 'Form 2 - call exactly one tool:\n';
    prompt += 'Thought: <one brief sentence explaining why the tool is needed>\n';
    prompt += 'Action: <exact_tool_name>[<tool_input>]\n\n';
    prompt += 'Rules:\n';
    prompt += '- Start the response with Thought: and then output exactly one Action: or one Final:.\n';
    prompt += '- Never return ordinary prose without the required labels, even for greetings or very simple questions.\n';
    prompt += '- Do not output both Action: and Final: in the same response.\n';
    prompt += '- Do not output more than one Action: in the same response.\n';
    prompt += '- Do not output Observation:. The runtime supplies tool observations in the next prompt.\n';
    prompt += '- Action must use a tool name exactly as listed under Tools in the current user prompt.\n';
    prompt += '- When a tool requires structured parameters, put a valid JSON object inside the brackets.\n';
    prompt += '- Do not wrap the response in Markdown or code fences and do not add text before Thought:.\n';
    prompt += '- The angle-bracket text in the forms above is explanatory placeholder text; never copy it literally.\n\n';
    prompt += 'Direct-answer example:\n';
    prompt += 'Thought: This greeting does not require a tool.\n';
    prompt += 'Final: 你好！有什么可以帮你的？\n\n';
    prompt += 'Tool-call example:\n';
    prompt += 'Thought: I need the listed time tool to answer accurately.\n';
    prompt += 'Action: time[]';

    if (this.skillsInSystemPrompt) {
      const skillsSection = buildSkillsSection(this.skillSnapshot);
      if (skillsSection.length > 0) {
        prompt += `\n\n${skillsSection}`;
      }
    }
    return prompt.trim();
  }

  private buildPrompt(task: string, scratchpad: string[]): string {
    let prompt = 'Current device local datetime: ' + currentLocalDateTime() + '. Resolve relative dates yourself before calling tools.\n';
    prompt += 'When a tool needs parameters, follow its description and pass structured values as valid JSON inside Action brackets; use normal JSON arrays like ["a@example.com"], and do not pass bare keywords when a schema is required.\n';
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

    const parenCall = this.parseDelimitedAction(action, '(', ')');
    if (parenCall !== null) {
      return parenCall;
    }

    const bracketCall = this.parseDelimitedAction(action, '[', ']');
    if (bracketCall !== null) {
      return bracketCall;
    }

    return null;
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
