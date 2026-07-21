import {
  A2uiAction,
  ActionCatalog,
  ActionOffer,
  ActionOfferContext,
  DataResult,
  DynamicGenericToolResult,
  HotelDetailResult,
  HotelSearchResult,
  MailThreadSummary,
  SocialHubItemData,
  ToolDefinition,
  hotelActionsFor,
  hotelBookingOpenAction,
  toolDefinitionForToolId
} from '@loop/agent-core';

type OfferValue = Object | string | number | boolean | null | undefined;
type OfferRecord = Record<string, OfferValue>;

const IDENTITY_KEYS: string[] = [
  'bookingUrl', 'eventId', 'hotelId', 'itemId', 'messageId',
  'orderId', 'requestKey', 'threadId', 'traceId', 'url'
];
const MAX_ACTION_OFFERS: number = 64;
const MAX_ACTION_CANDIDATES: number = 256;
const MAX_ACTION_ARGS_LENGTH: number = 8192;

interface CandidateOffer {
  action: A2uiAction;
  trusted: boolean;
  sourceValues: Set<string>;
}

interface MailReadArgs {
  requestKey: string;
  provider: string;
  threadId: string;
  messageId: string;
  subject: string;
}

interface SocialDraftArgs {
  itemId: string;
  platform: string;
  instruction: string;
}

function recordOf(value: OfferValue): OfferRecord | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as OfferRecord;
}

function safeSegment(value: string): string {
  const source = value.trim();
  let result = '';
  for (let index = 0; index < source.length && result.length < 64; index++) {
    const char = source.charAt(index);
    const code = source.charCodeAt(index);
    if (code >= 48 && code <= 57 || code >= 65 && code <= 90 || code >= 97 && code <= 122 ||
      char === '.' || char === '_' || char === '-') {
      result += char;
    }
  }
  return result.length > 0 ? result : 'item';
}

function cloneArgs(args: Object): Object | null {
  try {
    return JSON.parse(JSON.stringify(args)) as Object;
  } catch (_error) {
    return null;
  }
}

function primitiveText(value: OfferValue): string {
  if (typeof value === 'string') {
    return value.trim();
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function sourceValues(result: DynamicGenericToolResult): Set<string> {
  const values: Set<string> = new Set<string>();
  result.rows.forEach((row) => {
    const value = row.value.trim();
    if (value.length > 0) {
      values.add(value);
    }
  });
  return values;
}

function argsBelongToSource(args: Object, values: Set<string>): boolean {
  const record = args as OfferRecord;
  let identityCount = 0;
  for (let index = 0; index < IDENTITY_KEYS.length; index++) {
    const value = primitiveText(record[IDENTITY_KEYS[index]]);
    if (value.length === 0) {
      continue;
    }
    identityCount++;
    if (!values.has(value)) {
      return false;
    }
  }
  return identityCount === 0 || values.size > 0;
}

function action(
  id: string,
  label: string,
  variant: string,
  args: Object
): A2uiAction {
  return {
    id,
    label,
    prompt: label,
    variant,
    kind: 'prompt',
    args
  };
}

function mailReadCandidate(toolId: string, thread: MailThreadSummary): CandidateOffer {
  const args: MailReadArgs = {
    requestKey: thread.requestKey,
    provider: thread.provider,
    threadId: thread.threadId,
    messageId: thread.messageId,
    subject: thread.subject
  };
  return {
    action: action(toolId, '加载正文', 'secondary', args),
    trusted: true,
    sourceValues: new Set<string>()
  };
}

function socialDraftCandidate(item: SocialHubItemData): CandidateOffer {
  const args: SocialDraftArgs = {
    itemId: item.id,
    platform: item.platform,
    instruction: '生成一条简洁、可审核的回复草稿'
  };
  return {
    action: action('social.reply.draft', '生成草稿', 'primary', args),
    trusted: true,
    sourceValues: new Set<string>()
  };
}

function embeddedCandidates(data: DataResult): CandidateOffer[] {
  const record = recordOf(data.data);
  if (record === null || !Array.isArray(record['results'])) {
    return [];
  }
  const results = record['results'] as DynamicGenericToolResult[];
  const candidates: CandidateOffer[] = [];
  for (let resultIndex = 0; resultIndex < results.length; resultIndex++) {
    const result = results[resultIndex];
    if (!Array.isArray(result.actions)) {
      continue;
    }
    const values = sourceValues(result);
    for (let actionIndex = 0; actionIndex < result.actions.length; actionIndex++) {
      candidates.push({
        action: result.actions[actionIndex],
        trusted: false,
        sourceValues: values
      });
    }
  }
  return candidates;
}

function candidatesFor(data: DataResult): CandidateOffer[] {
  const record = recordOf(data.data);
  if (data.toolId === 'hotel.search' && record !== null && record['ok'] === true &&
    Array.isArray(record['hotels'])) {
    const result = data.data as HotelSearchResult;
    const candidates: CandidateOffer[] = [];
    for (let index = 0; index < result.hotels.length; index++) {
      const actions = hotelActionsFor(result.hotels[index], result.query, (_action: A2uiAction): boolean => true);
      actions.forEach((item: A2uiAction) => {
        candidates.push({
          action: item,
          trusted: true,
          sourceValues: new Set<string>()
        });
      });
    }
    return candidates;
  }
  if (data.toolId === 'hotel.detail' && record !== null && record['ok'] === true &&
    Array.isArray(record['rates'])) {
    const detail = data.data as HotelDetailResult;
    return [{
      action: hotelBookingOpenAction(detail),
      trusted: true,
      sourceValues: new Set<string>()
    }];
  }
  if ((data.toolId === 'mail.search' || data.toolId === 'gmail.mail.search') &&
    record !== null && Array.isArray(record['threads'])) {
    const readId = data.toolId === 'gmail.mail.search' ? 'gmail.thread.read' : 'mail.thread.read';
    const threads = record['threads'] as MailThreadSummary[];
    const candidates: CandidateOffer[] = [];
    for (let index = 0; index < threads.length; index++) {
      candidates.push(mailReadCandidate(readId, threads[index]));
    }
    return candidates.concat(embeddedCandidates(data));
  }
  if (data.toolId === 'social.feed.search' && record !== null && Array.isArray(record['items'])) {
    const items = record['items'] as SocialHubItemData[];
    const candidates: CandidateOffer[] = [];
    for (let index = 0; index < items.length; index++) {
      if (items[index].id.trim().length > 0) {
        candidates.push(socialDraftCandidate(items[index]));
      }
    }
    return candidates;
  }
  return embeddedCandidates(data);
}

export class RegisteredActionOfferResolver {
  private readonly catalog: ActionCatalog;

  constructor(catalog: ActionCatalog) {
    this.catalog = catalog;
  }

  async resolve(data: DataResult, context: ActionOfferContext): Promise<ActionOffer[]> {
    if (context.conversationId.trim().length === 0 || context.turnId.trim().length === 0 ||
      context.dataTaskId.trim().length === 0 || data.status === 'error') {
      return [];
    }
    const definition: ToolDefinition | null = toolDefinitionForToolId(data.toolId);
    if (definition === null || definition.outputSchema !== data.outputSchema) {
      return [];
    }
    const source = candidatesFor(data).slice(0, MAX_ACTION_CANDIDATES);
    const offers: ActionOffer[] = [];
    const indexes: Map<string, number> = new Map<string, number>();
    const duplicated: Set<string> = new Set<string>();
    for (let index = 0; index < source.length; index++) {
      const candidate = source[index];
      if (candidate.action.args === undefined || definition.actions.indexOf(candidate.action.id) < 0 ||
        candidate.action.label.trim().length === 0 || candidate.action.variant.trim().length === 0) {
        continue;
      }
      const args = cloneArgs(candidate.action.args);
      if (args === null || !candidate.trusted && !argsBelongToSource(args, candidate.sourceValues) ||
        !this.catalog.validatePlacement(data.toolId, candidate.action.id, args).ok) {
        continue;
      }
      const serializedArgs = JSON.stringify(args);
      if (serializedArgs.length > MAX_ACTION_ARGS_LENGTH) {
        continue;
      }
      const key = candidate.action.id + '\n' + serializedArgs;
      if (duplicated.has(key)) {
        continue;
      }
      const previous = indexes.get(key);
      if (previous !== undefined) {
        offers.splice(previous, 1);
        indexes.delete(key);
        duplicated.add(key);
        indexes.forEach((offerIndex: number, offerKey: string) => {
          if (offerIndex > previous) {
            indexes.set(offerKey, offerIndex - 1);
          }
        });
        continue;
      }
      if (offers.length >= MAX_ACTION_OFFERS) {
        continue;
      }
      const offer: ActionOffer = {
        offerId: safeSegment(context.conversationId) + ':' + safeSegment(context.turnId) + ':' +
          safeSegment(context.dataTaskId) + ':offer-' + index.toString(),
        actionId: candidate.action.id,
        label: candidate.action.label.substring(0, 80),
        variant: candidate.action.variant.substring(0, 24),
        args
      };
      indexes.set(key, offers.length);
      offers.push(offer);
    }
    return offers;
  }
}
