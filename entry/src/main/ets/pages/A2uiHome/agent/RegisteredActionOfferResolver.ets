import {
  A2uiAction,
  ActionCatalog,
  ActionOffer,
  ActionOfferContext,
  DataResult,
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

const MAX_ACTION_OFFERS: number = 64;
const MAX_ACTION_CANDIDATES: number = 256;
const MAX_ACTION_ARGS_LENGTH: number = 8192;
const MAX_ACTION_ARGS_DEPTH: number = 12;
const MAX_ACTION_ARGS_NODES: number = 512;
const DANGEROUS_ARG_KEYS: string[] = ['__proto__', 'constructor', 'prototype'];

interface CandidateOffer {
  action: A2uiAction;
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

interface CanonicalState {
  nodes: number;
}

function recordOf(value: OfferValue): OfferRecord | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as OfferRecord;
}

function canonicalJson(value: OfferValue, depth: number, state: CanonicalState): string | null {
  state.nodes++;
  if (state.nodes > MAX_ACTION_ARGS_NODES || depth > MAX_ACTION_ARGS_DEPTH) {
    return null;
  }
  if (value === null) {
    return 'null';
  }
  if (typeof value === 'string' || typeof value === 'boolean') {
    return JSON.stringify(value);
  }
  if (typeof value === 'number') {
    return Number.isFinite(value) ? JSON.stringify(value) : null;
  }
  if (typeof value !== 'object') {
    return null;
  }
  if (Array.isArray(value)) {
    const array = value as OfferValue[];
    if (Object.keys(array).length !== array.length) {
      return null;
    }
    const items: string[] = [];
    for (let index = 0; index < array.length; index++) {
      const item = canonicalJson(array[index], depth + 1, state);
      if (item === null) {
        return null;
      }
      items.push(item);
    }
    return '[' + items.join(',') + ']';
  }
  const record = value as OfferRecord;
  const keys = Object.keys(record).sort();
  const fields: string[] = [];
  for (let index = 0; index < keys.length; index++) {
    const key = keys[index];
    if (DANGEROUS_ARG_KEYS.indexOf(key) >= 0) {
      return null;
    }
    const item = canonicalJson(record[key], depth + 1, state);
    if (item === null) {
      return null;
    }
    fields.push(JSON.stringify(key) + ':' + item);
  }
  return '{' + fields.join(',') + '}';
}

function canonicalArgs(args: Object): string | null {
  try {
    const serialized = canonicalJson(args, 0, { nodes: 0 });
    return serialized !== null && serialized.length <= MAX_ACTION_ARGS_LENGTH ? serialized : null;
  } catch (_error) {
    return null;
  }
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
    action: action(toolId, '加载正文', 'secondary', args)
  };
}

function socialDraftCandidate(item: SocialHubItemData): CandidateOffer {
  const args: SocialDraftArgs = {
    itemId: item.id,
    platform: item.platform,
    instruction: '生成一条简洁、可审核的回复草稿'
  };
  return {
    action: action('social.reply.draft', '生成草稿', 'primary', args)
  };
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
        candidates.push({ action: item });
      });
    }
    return candidates;
  }
  if (data.toolId === 'hotel.detail' && record !== null && record['ok'] === true &&
    Array.isArray(record['rates'])) {
    const detail = data.data as HotelDetailResult;
    return [{
      action: hotelBookingOpenAction(detail)
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
    return candidates;
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
  return [];
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
      const serializedArgs = canonicalArgs(candidate.action.args);
      if (serializedArgs === null) {
        continue;
      }
      const args = JSON.parse(serializedArgs) as Object;
      if (!this.catalog.validateRegisteredAction(candidate.action.id).ok ||
        !this.catalog.validatePlacement(data.toolId, candidate.action.id, args).ok) {
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
        offerId: 'o' + index.toString(),
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
