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

function calendarToolDescription(definition: ToolDefinition): string {
  let description = definition.intent + ' risk=' + definition.riskLevel + ' inputSchema=' + definition.inputSchema +
    ' outputSchema=' + definition.outputSchema;
  if (definition.toolId === 'calendar.events.search') {
    return description + '. Use only for reading or listing Google Calendar events. NEVER use calendar.events.search for a write request, including update, move, modify, or delete; use the dedicated write tool, which resolves real Event IDs internally. Input must be JSON with args.query, args.timeMin, args.timeMax, args.timezone, and optional args.calendarId. query contains only event title text; use an empty query when the request specifies only a date or time. Resolve relative dates from the current device local datetime into RFC3339 timeMin/timeMax; never pass phrases such as tomorrow or 明天.';
  }
  if (definition.toolId === 'calendar.event.create') {
    return description + '. Use for creating Google Calendar events. Required JSON args are title, start, end, and timezone; calendarId is optional. start and end must be RFC3339 timestamps with a numeric offset, for example 2026-07-17T15:00:00+08:00. Resolve relative dates from the current device local datetime. If the title, date, start time, end time, or duration is missing, ask the user in Final and do not call this tool. Never invent a time or pass natural-language time text.';
  }
  if (definition.toolId === 'calendar.event.update') {
    return description + '. For every natural-language update or move request, call calendar.event.update directly, even when the requested new time is incomplete. Pass structured args.query, args.timeMin, args.timeMax, args.start, args.end, args.timezone, and optional args.title or args.calendarId. query contains only event title text; use an empty query when the request specifies only a date or time. timeMin/timeMax identify the existing event; start/end are the requested new RFC3339 times. If the exact new time is incomplete, omit missing start or end instead of inventing it; the client will show matching events or request the missing time without writing. The client updates only when exactly one real event matches and the new time is complete. When a visible event action already provides args.eventId, preserve it. Never ask the user to type or know an Event ID.';
  }
  if (definition.toolId === 'calendar.event.delete') {
    return description + '. For a natural-language delete request, call calendar.event.delete directly with structured args.query, args.timeMin, args.timeMax, args.timezone, and optional args.calendarId. query contains only event title text; use an empty query when the request specifies only a date or time. Resolve relative dates into RFC3339 and never pass phrases such as tomorrow or 明天. The client searches real events internally: exactly one match proceeds to confirmation, while zero or multiple matches are shown for user selection. When the user selected a visible event, pass its internal args.eventId. Never ask the user to type or know an Event ID. The client requires explicit delete confirmation before the Provider call.';
  }
  if (definition.toolId === 'hotel.search') {
    return description + '. Use for real hotel discovery through RollingGo. Input must be JSON with originQuery, place, placeType, countryCode, checkInDate in YYYY-MM-DD, stayNights, adultCount, childCount, childAgeDetails, roomCount, currency, and optional size. Never omit place or dates: the provider otherwise defaults to unrelated inventory. This tool is read-only and does not create a reservation.';
  }
  if (definition.toolId === 'hotel.detail') {
    return description + '. Use only after hotel.search returns a real hotelId. Preserve the action args exactly: hotelId, checkInDate, checkOutDate, countryCode, currency, adultCount, childCount, childAgeDetails, and roomCount. It returns live room ratePlanId, average price/currency, bed, meal, availability, and cancellation policy. The current room surface may open the provider booking page through the registered hotel.booking.open action; this does not create, confirm, or track an order.';
  }
  return description;
}

export function aiphoneToolDescriptionForModel(toolId: string): string {
  if (isSurfaceDerivedHotelActionId(toolId)) {
    return '';
  }
  const definitions = allToolDefinitions();
  for (let index = 0; index < definitions.length; index++) {
    if (definitions[index].toolId === toolId) {
      return calendarToolDescription(definitions[index]);
    }
  }
  return '';
}

export function isSurfaceDerivedHotelActionId(toolId: string): boolean {
  return toolId === 'hotel.navigate' || toolId === 'hotel.booking.open';
}

export class LoopBackend {
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
    const settings = request.modelSettings;
    const provider = new LlmProvider(settings.provider, settings.apiKey, settings.baseUrl, settings.model, settings.customParametersJson);
    return provider.isConfigured() ? new OpenAiCompatibleModel(provider) : new ScriptedLocalModel();
  }

  private buildToolRegistry(request: LoopBackendRequest, callbacks: LoopBackendCallbacks): ToolRegistry {
    const registry = new ToolRegistry();
    const currentPrompt = request.userPrompt === undefined || request.userPrompt.trim().length === 0 ?
      request.prompt : request.userPrompt;
    for (const definition of allToolDefinitions()) {
      if (isSurfaceDerivedHotelActionId(definition.toolId)) {
        continue;
      }
      if (definition.toolId === 'luckin.order.preview' && !isExplicitLuckinOrderPrompt(currentPrompt)) {
        continue;
      }
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
      'dynamic.search inputSchema=dynamicToolSearchQuery outputSchema=dynamicToolConnect. Use for ModelScope/remote MCP discovery, weather requests, Composio-backed app/toolkit requests, and domains not covered by fixed tools. Use dynamic.search when the user names unsupported external apps or SaaS toolkits such as Notion pages/databases, Google Drive files, Google Docs documents, Linear issues, Trello cards/checklists, Asana tasks, GitHub issues, HubSpot, Salesforce, Outlook, Spotify, TikTok, or Ticketmaster. Do not use dynamic.search for any SocialHub inbox, private-message, recent-message, or connection-state request involving X/Twitter, Slack, WeCom, Discord, LinkedIn, WhatsApp, or Instagram; use social.feed.search with structured args.platforms instead. WhatsApp Business message sending uses whatsapp.message.send, never dynamic.search. Gmail, Google Calendar, YouTube account tools, and X public post search have fixed Composio-backed tools; use those fixed tool IDs instead of dynamic.search. Use dynamic.search for Outlook only when the user explicitly names Outlook or Composio Outlook; ordinary mailbox aggregation uses mail.search. World Cup page, schedule, next-match, preview, team, or player-card requests are covered by worldcup.open, not dynamic.search. For Composio, first call with the full user task to discover candidate tools; only call again with {"operation":"execute","toolSlug":"returned slug","arguments":{...}} for read/search/list/get actions. Do not use Composio for payment, Gmail, Calendar, SocialHub, Maps, Food, Travel, World Cup page/schedule requests, or other fixed-tool domains unless the user explicitly asks for an unsupported external app/toolkit. For ferry or boat ticket requests, use dynamic.search; fixed travel tools only cover train and flight options, and dynamic.search may return no_tool_found truthfully.',
      request,
      callbacks
    ));
    return registry;
  }

  private describeAiphoneTool(definition: ToolDefinition): string {
    if (definition.domain === 'calendar') {
      return calendarToolDescription(definition);
    }
    let description = definition.intent + ' risk=' + definition.riskLevel + ' inputSchema=' + definition.inputSchema + ' outputSchema=' + definition.outputSchema;
    if (definition.toolId === 'travel.search') {
      description += '. Use for general train/flight travel options. Do not use for ferry or boat tickets; use dynamic.search for those unsupported transport domains.';
    } else if (definition.toolId === 'train.search') {
      description += '. Use for railway, high-speed rail, bullet train, station-to-station, 12306, or train schedule requests.';
    } else if (definition.toolId === 'flight.search') {
      description += '. Use for flight, airline, airport, or flight-board requests.';
    } else if (definition.toolId === 'hotel.search') {
      description += '. Use for real hotel discovery through RollingGo. Input must be JSON with originQuery, place, placeType, countryCode, checkInDate in YYYY-MM-DD, stayNights, adultCount, childCount, childAgeDetails, roomCount, currency, and optional size. Never omit place or dates: the provider otherwise defaults to unrelated inventory. This tool is read-only and does not create a reservation.';
    } else if (definition.toolId === 'hotel.detail') {
      description += '. Use only after hotel.search returns a real hotelId. Preserve hotelId, checkInDate, checkOutDate, countryCode, currency, adultCount, childCount, childAgeDetails, and roomCount. It returns live room ratePlanId, average price/currency, bed, meal, availability, and cancellation policy. It does not create, confirm, or track an order.';
    } else if (definition.toolId === 'food.search') {
      description += '. Use for restaurants, cafes, coffee, milk tea, drinks, McDonalds, menus, coupons, delivery, and food or beverage places near a location. Do not use for Luckin order placement; use luckin.order.preview for ordering Luckin coffee.';
    } else if (definition.toolId === 'luckin.order.preview') {
      description += '. Use only when the current user message itself explicitly names Luckin/Ruixing and explicitly asks to place or prepare a real order, for example "点一杯瑞幸咖啡", "帮我买一杯瑞幸生椰拿铁", or "瑞幸下单". Do not infer Luckin ordering from saved brand preferences or memory. A Luckin brand mention, store discovery, menu browsing, product question, or price question is not an order and must use food.search instead. This is the first step for explicit Luckin ordering: it queries nearby stores, product SKU/options, and previewOrder pricing. Input must be JSON; at minimum pass {"prompt":"<original user request>"} or {"query":"<original user request>"}. Do not answer with note or food.search when the current message explicitly requests a Luckin order.';
    } else if (definition.toolId === 'luckin.order.create') {
      description += '. Use only after a Luckin order preview card returned real deptId, productId, and skuCode, and the user confirms creating the order. Do not use directly from an initial "order coffee" request.';
    } else if (definition.toolId === 'luckin.order.status') {
      description += '. Use when the user asks to check, refresh, or view a Luckin order status, pickup code, or existing orderId.';
    } else if (definition.toolId === 'social.feed.search') {
      description += '. Use for every SocialHub inbox, received-message, recent-message, private-message, or connection-state request involving X/Twitter, Slack, WeCom, Discord, LinkedIn, WhatsApp, or Instagram, including when the user mentions Composio or authorization. Input must be JSON with args.platforms: use one named platform such as ["whatsapp"] for a single-source request, or ["all"] for the complete SocialHub. Do not use for public X/Twitter posts; use x.post.search for explicit public post searches. This tool reports unsupported read capabilities as limitations and never fabricates social messages.';
    } else if (definition.toolId === 'social.reply.draft') {
      description += '. Use only to draft a reply after a real SocialHub item is selected. Include itemId, platform, and instruction when available. Do not send.';
    } else if (definition.toolId === 'x.post.search') {
      description += '. Use only for explicit X/Twitter/x.com public post searches, not arbitrary letter X or Xcode requests. Never fabricate posts.';
    } else if (definition.toolId === 'maps.place.search') {
      description += '. Use for explicit Google Maps/Google Places searches, non-food places, addresses, and POIs. If the user asks for cafes, coffee, milk tea, restaurants, menus, or delivery without explicitly asking for Google Maps, use food.search.';
    } else if (definition.toolId === 'maps.route.open') {
      description += '. Use for Google Maps directions or navigation only when structured args include origin and destination. Do not parse or guess endpoints from free text.';
    } else if (definition.toolId === 'whatsapp.message.send') {
      description += '. Use for real WhatsApp Business text messages. Include structured args.toNumber and args.text. Preserve args.phoneNumberId or args.wabaId when the user configured a sender. The client requires explicit confirmation and the Provider may reject free text outside the 24-hour conversation window.';
    } else if (definition.toolId === 'mail.search') {
      description += '. Use for generic mailbox/email/inbox requests and aggregate Gmail, QQ Mail, and Outlook search. Action input must be JSON with providers, query, and pageSize. Always include query; if the user wants latest/recent mail and is not searching by keyword, set query to "". Use pageSize for requested count; do not use count, limit, or maxResults. If the user says only mail, email, inbox, or latest important mail, choose mail.search with providers ["gmail","qq","outlook"]. Never fabricate mail rows.';
    } else if (definition.toolId === 'mail.thread.read') {
      description += '. Use only when the user opens or reads a specific aggregate mail result and provider plus messageId/threadId are available.';
    } else if (definition.toolId === 'mail.draft.create') {
      description += '. Use for aggregate mail reply drafts after a real mail row is selected. Include provider, messageId or threadId, to, subject, and body when available.';
    } else if (definition.toolId === 'gmail.mail.search') {
      description += '. Use for searching, listing, or viewing Gmail messages, inboxes, important mail, or keyword-based mail queries. Required Action input is a JSON object with args.query and args.pageSize; do not pass plain keywords. Always include query; if the user wants latest/recent Gmail and is not searching by keyword, set query to "". Use pageSize for requested count; do not use count, limit, or maxResults. Generate args.query from the user request only when the user is searching by keyword; never fabricate Gmail messages. For Chinese academic or application queries, keep user-provided acronyms or names and expand the Gmail query with likely English terms: paper, manuscript, submission, review, conference, journal, camera-ready, admission decision, offer letter, accepted, admitted, congratulations, waitlist, rejection, application status. Use Gmail OR grouping like {user_acronym OR paper OR manuscript OR review}; do not space-AND every term. Keep the query focused to the relevant 6-10 OR terms.';
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
    } else if (definition.toolId === 'media.aggregate.search') {
      description += '. Use only for mixed-content topic research where the user asks for videos plus news, discussions, posts, or public reactions around one topic; use media.video.search for video-only requests. It aggregates YouTube, Bilibili, X public posts, Hacker News and Reddit via Composio, and Zhihu via its official REST API. Never fabricate media or posts.';
    } else if (definition.toolId === 'worldcup.open') {
      description += '. Use when the user wants to open the World Cup experience, view World Cup schedules, next match time, previews, highlights, teams, players, or matchup cards. Use media tools instead for explicit YouTube-only, Bilibili-only, or mixed-content search requests.';
    } else if (definition.toolId === 'youtube.video.search') {
      description += '. Use only for explicit YouTube-only public video search; use media.video.search for Bilibili or multi-source video requests.';
    } else if (definition.toolId === 'payment.send') {
      description += '. Use for explicit PayPal account payments, Stripe connected merchant Checkout, or opening a stored Stripe Payment Link. If the user says Google Pay, treat it as args.fundingSource="google_pay" with provider still PayPal or Stripe; Google Pay is not a separate provider/tool. Always produce a confirmation/payment UI before checkout. Never claim money was sent without a real provider confirmation.';
    } else if (definition.toolId === 'payment.account.setup') {
      description += '. Use when the user wants to create, bind, open, verify, or refresh the current agent Stripe receiving account. Do not use this for paying someone; payment.send handles payments.';
    } else if (definition.toolId === 'ride.estimate') {
      description += '. Use for taxi/ride-hailing fare estimate requests. Shows Didi price estimates only and also returns Didi/Amap app ride links. Required input must include args.origin/from, args.destination/to, and args.city when the city is known or inferable from the user text. If origin, destination, or city is missing, ask for it; never guess coordinates. Never create, cancel, query, or track ride orders, even if the user says "直接帮我叫车".';
    } else if (definition.toolId === 'ride.app.link') {
      description += '. Use when the user wants taxi/ride-hailing app links without prices. Returns Didi and Amap app ride links for user-tapped handoff only. Required input must include args.origin/from, args.destination/to, and args.city when the city is known or inferable from the user text. Do not describe Amap as a price estimate provider. Never create, cancel, query, or track ride orders.';
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
