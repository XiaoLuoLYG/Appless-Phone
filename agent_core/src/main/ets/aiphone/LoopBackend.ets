import { AgentEvent, AgentEventKind } from '../agent/AgentEvent';
import { AgentTool } from '../agent/AgentTool';
import { ConversationContext } from '../agent/ConversationContext';
import { ReActAgentRunner } from '../agent/ReActAgentRunner';
import { ToolRegistry } from '../agent/ToolRegistry';
import { LlmProvider } from '../model/LlmProvider';
import { LocalModel } from '../model/LocalModel';
import { OpenAiCompatibleModel } from '../model/OpenAiCompatibleModel';
import { ScriptedLocalModel } from '../model/ScriptedLocalModel';
import { aiphoneInfoJsonl, splitJsonl } from './AiphoneA2ui';
import { allToolDefinitions } from './AiphoneToolDefinitions';
import { runAiphoneTool } from './AiphoneToolExecutor';
import { LoopBackendCallbacks, LoopBackendRequest, LoopRunResult, LoopToolTrace } from './LoopBackendTypes';
import { toolPlanningDescriptionForToolId } from './runtime/ToolDefinitionRegistry';

class AiphoneTool implements AgentTool {
  private toolId: string;
  private descriptionText: string;
  private request: LoopBackendRequest;
  private callbacks: LoopBackendCallbacks;

  constructor(toolId: string, descriptionText: string, request: LoopBackendRequest, callbacks: LoopBackendCallbacks) {
    this.toolId = toolId;
    this.descriptionText = descriptionText;
    this.request = request;
    this.callbacks = callbacks;
  }

  name(): string {
    return this.toolId;
  }

  description(): string {
    return this.descriptionText;
  }

  async run(input: string): Promise<string> {
    if (this.toolId === 'memory.update') {
      return this.runMemoryUpdate(input);
    }
    if (this.toolId === 'worldcup.open') {
      return 'Client intent accepted: worldcup.open. The app will open the World Cup experience.';
    }
    const parsedArgs = this.parseInputArgs(input);
    const userPrompt = this.request.userPrompt === undefined ? '' : this.request.userPrompt;
    const promptForTool = userPrompt.trim().length > 0 ? userPrompt : (input.trim().length > 0 ? input : this.request.prompt);
    const jsonl = await runAiphoneTool(
      this.toolId,
      promptForTool,
      this.request.surfaceId,
      this.request.actionId,
      this.mergeArgs(this.request.args, parsedArgs),
      this.request.ignoreToolSurfaceUpdates === true,
      this.callbacks.onA2uiSurface === undefined ? null : this.callbacks.onA2uiSurface
    );
    for (const line of splitJsonl(jsonl)) {
      this.callbacks.onA2uiJsonl?.(line);
    }
    return jsonl;
  }

  private mergeArgs(baseArgs: Object | undefined, overrideArgs: Object | null): Object | null {
    if (baseArgs === undefined || baseArgs === null) {
      return overrideArgs;
    }
    if (overrideArgs === null) {
      return baseArgs;
    }
    const merged = JSON.parse(JSON.stringify(baseArgs)) as Record<string, Object | string | number | boolean | null | undefined>;
    const overrides = overrideArgs as Record<string, Object | string | number | boolean | null | undefined>;
    Object.keys(overrides).forEach((key: string) => {
      merged[key] = overrides[key];
    });
    return merged;
  }

  private parseInputArgs(input: string): Object | null {
    return parseLoopToolInputArgs(input);
  }

  private runMemoryUpdate(input: string): string {
    const jsonl = aiphoneInfoJsonl(this.request.surfaceId, '记忆更新请求', input);
    for (const line of splitJsonl(jsonl)) {
      this.callbacks.onA2uiJsonl?.(line);
    }
    return jsonl;
  }
}

export function isExplicitLuckinOrderPrompt(prompt: string): boolean {
  const text = prompt.trim();
  const hasLuckin = /瑞幸|luckin|ruixing/i.test(text);
  const hasTransaction = /点一杯|点杯|点个瑞幸|点瑞幸|帮我点|我要点|下单|下一杯|买一杯|买瑞幸|帮我买|购买一杯|购买瑞幸|来一杯|要一杯|\border\b|\bbuy\b/i.test(text);
  return hasLuckin && hasTransaction;
}

function escapeRawLineBreaksInJsonStrings(value: string): string {
  let result = '';
  let inString = false;
  let escaped = false;
  for (let index = 0; index < value.length; index++) {
    const char = value.charAt(index);
    if (escaped) {
      result += char;
      escaped = false;
      continue;
    }
    if (char === '\\') {
      result += char;
      escaped = true;
      continue;
    }
    if (char === '"') {
      inString = !inString;
      result += char;
      continue;
    }
    if (inString && (char === '\n' || char === '\r')) {
      if (char === '\r' && index + 1 < value.length && value.charAt(index + 1) === '\n') {
        index++;
      }
      result += '\\n';
      continue;
    }
    result += char;
  }
  return result;
}

function unwrapSingleArgsEnvelope(parsed: Object): Object {
  const record = parsed as Record<string, Object | string | number | boolean | null | undefined>;
  const keys = Object.keys(record);
  const args = record.args;
  return keys.length === 1 && keys[0] === 'args' && args !== null && args !== undefined &&
    typeof args === 'object' && !Array.isArray(args) ? args as Object : parsed;
}

export function parseLoopToolInputArgs(input: string): Object | null {
  const trimmed = input.trim();
  if (trimmed.length === 0 || trimmed.charAt(0) !== '{') {
    return null;
  }
  try {
    const parsed = JSON.parse(trimmed) as Object | null;
    if (parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return unwrapSingleArgsEnvelope(parsed);
    }
  } catch (_error) {
    try {
      const parsed = JSON.parse(escapeRawLineBreaksInJsonStrings(trimmed)) as Object | null;
      if (parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return unwrapSingleArgsEnvelope(parsed);
      }
    } catch (_repairError) {
    }
  }
  return null;
}

export function aiphoneToolDescriptionForModel(toolId: string): string {
  if (!isLoopToolExposedToModel(toolId)) {
    return '';
  }
  return toolPlanningDescriptionForToolId(toolId);
}

export function isSurfaceDerivedHotelActionId(toolId: string): boolean {
  return toolId === 'hotel.navigate' || toolId === 'hotel.booking.open';
}

function isLoopToolExposedToModel(toolId: string): boolean {
  return !isSurfaceDerivedHotelActionId(toolId) && toolId !== 'gmail.message.send' &&
    toolId !== 'calendar.event.create' && toolId !== 'calendar.event.update' &&
    toolId !== 'calendar.event.delete';
}

export class LoopBackend {
  private readonly modelOverride: LocalModel | null;

  constructor(modelOverride: LocalModel | null = null) {
    this.modelOverride = modelOverride;
  }

  async run(request: LoopBackendRequest, callbacks: LoopBackendCallbacks): Promise<LoopRunResult> {
    const conversation = this.buildConversation(request);
    const model = this.buildModel(request);
    let a2uiLineCount = 0;
    const a2uiCallbacks: LoopBackendCallbacks = {
      onEvent: callbacks.onEvent,
      onA2uiSurface: callbacks.onA2uiSurface,
      onA2uiJsonl: (line: string): void => {
        a2uiLineCount++;
        callbacks.onA2uiJsonl?.(line);
      }
    };
    const runner = new ReActAgentRunner(model, this.buildToolRegistry(request, a2uiCallbacks), request.maxSteps > 0 ? request.maxSteps : 6);
    const toolCalls: LoopToolTrace[] = [];
    let finalAnswer = '';
    let error = '';
    let raw = '';
    let lastAction: LoopToolTrace = { toolId: '', input: '', observation: '' };

    await runner.run(request.prompt, (event: AgentEvent): void => {
      raw += `${event.kind}: ${event.text}\n`;
      try {
        callbacks.onEvent?.(event);
      } catch (callbackError) {
        const message = callbackError instanceof Error ? callbackError.message : `${callbackError}`;
        error = `Callback failed: ${message}`;
        raw += `ERROR: ${error}\n`;
        return;
      }

      if (event.kind === AgentEventKind.FINAL) {
        finalAnswer = event.text;
        if (a2uiLineCount === 0) {
          const jsonl = aiphoneInfoJsonl(request.surfaceId, 'Appless', event.text);
          raw += `A2UI: ${jsonl}`;
          for (const line of splitJsonl(jsonl)) {
            try {
              a2uiLineCount++;
              callbacks.onA2uiJsonl?.(line);
            } catch (callbackError) {
              const message = callbackError instanceof Error ? callbackError.message : `${callbackError}`;
              error = `Callback failed: ${message}`;
              raw += `ERROR: ${error}\n`;
              return;
            }
          }
        }
      } else if (event.kind === AgentEventKind.ERROR) {
        error = event.text;
      } else if (event.kind === AgentEventKind.ACTION) {
        lastAction = this.parseActionTrace(event.text);
      } else if (event.kind === AgentEventKind.OBSERVATION) {
        toolCalls.push({
          toolId: lastAction.toolId,
          input: lastAction.input,
          observation: event.text
        });
      }
    }, conversation);

    return {
      ok: error.length === 0,
      finalAnswer,
      error,
      toolCalls,
      raw: raw.trim()
    };
  }

  private buildConversation(request: LoopBackendRequest): ConversationContext {
    const conversation = new ConversationContext();
    for (const message of request.history) {
      if (message.role === 'user') {
        conversation.addUser(message.content);
      } else if (message.role === 'assistant') {
        conversation.addAssistant(message.content);
      }
    }
    return conversation;
  }

  private buildModel(request: LoopBackendRequest): LocalModel {
    if (this.modelOverride !== null) {
      return this.modelOverride;
    }
    const settings = request.modelSettings;
    const provider = new LlmProvider(settings.provider, settings.apiKey, settings.baseUrl, settings.model, settings.customParametersJson);
    return provider.isConfigured() ? new OpenAiCompatibleModel(provider) : new ScriptedLocalModel();
  }

  private buildToolRegistry(request: LoopBackendRequest, callbacks: LoopBackendCallbacks): ToolRegistry {
    const registry = new ToolRegistry();
    const currentPrompt = request.userPrompt === undefined || request.userPrompt.trim().length === 0 ?
      request.prompt : request.userPrompt;
    for (const definition of allToolDefinitions()) {
      if (!isLoopToolExposedToModel(definition.toolId)) {
        continue;
      }
      if (definition.toolId === 'luckin.order.preview' && !isExplicitLuckinOrderPrompt(currentPrompt)) {
        continue;
      }
      registry.register(new AiphoneTool(
        definition.toolId,
        toolPlanningDescriptionForToolId(definition.toolId),
        request,
        callbacks
      ));
    }
    registry.register(new AiphoneTool(
      'memory.update',
      'memory.update inputSchema=personaMemoryUpdate outputSchema=personaMemoryUpdateCard. Use only when the user states a durable preference, identity fact, or stable constraint that should affect future turns for the active persona. Do not use for one-off tasks. Input must be JSON with personaId, summary, memoryText, reason, and optional suggestedAction { label, prompt, toolId }. Default to the active persona when the user does not name another persona. This tool only records memory; it does not search providers or fabricate results.',
      request,
      callbacks
    ));
    registry.register(new AiphoneTool(
      'dynamic.search',
      toolPlanningDescriptionForToolId('dynamic.search'),
      request,
      callbacks
    ));
    return registry;
  }

  private parseActionTrace(action: string): LoopToolTrace {
    const open = action.indexOf('(');
    const close = action.lastIndexOf(')');
    if (open <= 0 || close < open) {
      return { toolId: action, input: '', observation: '' };
    }
    return {
      toolId: action.substring(0, open).trim(),
      input: action.substring(open + 1, close).trim(),
      observation: ''
    };
  }
}
