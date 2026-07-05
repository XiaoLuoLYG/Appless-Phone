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
import { allToolDefinitions, ToolDefinition } from './AiphoneToolDefinitions';
import { runAiphoneTool } from './AiphoneToolExecutor';
import { LoopBackendCallbacks, LoopBackendRequest, LoopRunResult, LoopToolTrace } from './LoopBackendTypes';

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
    const parsedArgs = this.parseInputArgs(input);
    const userPrompt = this.request.userPrompt === undefined ? '' : this.request.userPrompt;
    const promptForTool = userPrompt.trim().length > 0 ? userPrompt : (input.trim().length > 0 ? input : this.request.prompt);
    const jsonl = await runAiphoneTool(
      this.toolId,
      promptForTool,
      this.request.surfaceId,
      this.request.actionId,
      this.mergeArgs(this.request.args, parsedArgs)
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
    const trimmed = input.trim();
    if (trimmed.length === 0 || trimmed.charAt(0) !== '{') {
      return null;
    }
    try {
      const parsed = JSON.parse(trimmed) as Object | null;
      if (parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed;
      }
    } catch (_error) {
      return null;
    }
    return null;
  }

  private runMemoryUpdate(input: string): string {
    const jsonl = aiphoneInfoJsonl(this.request.surfaceId, '记忆更新请求', input);
    for (const line of splitJsonl(jsonl)) {
      this.callbacks.onA2uiJsonl?.(line);
    }
    return jsonl;
  }
}

export class LoopBackend {
  async run(request: LoopBackendRequest, callbacks: LoopBackendCallbacks): Promise<LoopRunResult> {
    const conversation = this.buildConversation(request);
    const model = this.buildModel(request);
    let a2uiLineCount = 0;
    const a2uiCallbacks: LoopBackendCallbacks = {
      onEvent: callbacks.onEvent,
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
          const jsonl = aiphoneInfoJsonl(request.surfaceId, 'Appless Phone', event.text);
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
    const settings = request.modelSettings;
    const provider = new LlmProvider(settings.provider, settings.apiKey, settings.baseUrl, settings.model, settings.customParametersJson);
    return provider.isConfigured() ? new OpenAiCompatibleModel(provider) : new ScriptedLocalModel();
  }

  private buildToolRegistry(request: LoopBackendRequest, callbacks: LoopBackendCallbacks): ToolRegistry {
    const registry = new ToolRegistry();
    for (const definition of allToolDefinitions()) {
      registry.register(new AiphoneTool(
        definition.toolId,
        this.describeAiphoneTool(definition),
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
      'dynamic.search inputSchema=dynamicToolSearchQuery outputSchema=dynamicToolConnect. Use for ModelScope/remote MCP discovery, weather requests, and domains not covered by fixed tools. For weather, dynamic.search discovers weather.query/maps.weather. For ferry or boat ticket requests, use dynamic.search; fixed travel tools only cover train and flight options, and dynamic.search may return no_tool_found truthfully.',
      request,
      callbacks
    ));
    return registry;
  }

  private describeAiphoneTool(definition: ToolDefinition): string {
    let description = definition.intent + ' risk=' + definition.riskLevel + ' inputSchema=' + definition.inputSchema + ' outputSchema=' + definition.outputSchema;
    if (definition.toolId === 'travel.search') {
      description += '. Use for general train/flight travel options. Do not use for ferry or boat tickets; use dynamic.search for those unsupported transport domains.';
    } else if (definition.toolId === 'train.search') {
      description += '. Use for railway, high-speed rail, bullet train, station-to-station, 12306, or train schedule requests.';
    } else if (definition.toolId === 'flight.search') {
      description += '. Use for flight, airline, airport, or flight-board requests.';
    } else if (definition.toolId === 'food.search') {
      description += '. Use for restaurants, cafes, coffee, milk tea, drinks, McDonalds, Luckin, menus, coupons, delivery, and food or beverage places near a location.';
    } else if (definition.toolId === 'social.feed.search') {
      description += '. Use for SocialHub aggregate X/Twitter, Slack, and WeCom feed or connection-state requests. Never fabricate social messages.';
    } else if (definition.toolId === 'social.reply.draft') {
      description += '. Use only to draft a reply after a real SocialHub item is selected. Include itemId, platform, and instruction when available. Do not send.';
    } else if (definition.toolId === 'x.post.search') {
      description += '. Use only for explicit X/Twitter/x.com public post searches, not arbitrary letter X or Xcode requests. Never fabricate posts.';
    } else if (definition.toolId === 'maps.place.search') {
      description += '. Use for explicit Google Maps/Google Places searches, non-food places, addresses, and POIs. If the user asks for cafes, coffee, milk tea, restaurants, menus, or delivery without explicitly asking for Google Maps, use food.search.';
    } else if (definition.toolId === 'mail.search') {
      description += '. Use for generic mailbox/email/inbox requests and aggregate Gmail plus QQ Mail search. If the user says only mail, email, inbox, or latest important mail, choose mail.search with providers ["gmail","qq"]. Never fabricate mail rows.';
    } else if (definition.toolId === 'mail.thread.read') {
      description += '. Use only when the user opens or reads a specific aggregate mail result and provider plus messageId/threadId are available.';
    } else if (definition.toolId === 'mail.draft.create') {
      description += '. Use for aggregate mail reply drafts after a real mail row is selected. Include provider, messageId or threadId, to, subject, and body when available.';
    } else if (definition.toolId === 'gmail.mail.search') {
      description += '. Use for searching, listing, or viewing Gmail messages, inboxes, important mail, or keyword-based mail queries. Generate args.query from the user request; never fabricate Gmail messages. For Chinese academic or application queries, expand the Gmail query with likely English terms: paper, manuscript, submission, review, conference, journal, camera-ready, admission decision, offer letter, accepted, admitted, congratulations, waitlist, rejection, application status. Use Gmail OR grouping such as {eccv OR paper OR manuscript OR submission OR review}; do not space-AND every term. Keep the query focused to the relevant 6-10 OR terms.';
    } else if (definition.toolId === 'gmail.thread.read') {
      description += '. Use only when the user asks to read a specific Gmail thread and a threadId is available.';
    } else if (definition.toolId === 'gmail.draft.create') {
      description += '. Use for Gmail replies, writing email, composing email, saying something to a recipient, or creating a draft. For normal "send/write an email saying..." requests, create a draft first instead of using gmail.message.send. Include args.to, args.subject, and args.body when available.';
    } else if (definition.toolId === 'gmail.draft.apply') {
      description += '. Use only after a user has already reviewed and confirmed an existing Gmail draft.';
    } else if (definition.toolId === 'gmail.open.web') {
      description += '. Use only when the user explicitly asks to open Gmail in the browser/web app.';
    } else if (definition.toolId === 'gmail.message.send') {
      description += '. Blocked safety fallback. Do not use for ordinary writing, composing, replying, or "send an email saying..." requests; use gmail.draft.create. Use only if the user explicitly asks to bypass review or confirmation and send immediately, and expect the client to block it.';
    } else if (definition.toolId === 'media.video.search') {
      description += '. Use for Bilibili/B站/哔哩哔哩 video search or multi-source video search. If the same request mentions YouTube and Bilibili, choose media.video.search with sources ["youtube","bilibili"].';
    } else if (definition.toolId === 'youtube.video.search') {
      description += '. Use only for explicit YouTube-only public video search; use media.video.search for Bilibili or multi-source video requests.';
    } else if (definition.toolId === 'calendar.events.search') {
      description += '. Use for reading Google Calendar events or schedules.';
    } else if (definition.toolId === 'calendar.event.create') {
      description += '. Use for drafting or creating Google Calendar events; confirm_required.';
    } else if (definition.toolId === 'payment.send') {
      description += '. Use for explicit PayPal account payments, Stripe connected merchant Checkout, or opening a stored Stripe Payment Link. If the user says Google Pay, treat it as args.fundingSource="google_pay" with provider still PayPal or Stripe; Google Pay is not a separate provider/tool. Always produce a confirmation/payment UI before checkout. Never claim money was sent without a real provider confirmation.';
    } else if (definition.toolId === 'payment.account.setup') {
      description += '. Use when the user wants to create, bind, open, verify, or refresh the current agent Stripe receiving account. Do not use this for paying someone; payment.send handles payments.';
    }
    return description;
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
