import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ChatMessage, ConversationContext, ConversationRole } from './ConversationContext';

const CONVERSATION_STORE: string = 'loop_conversation';
const CONVERSATION_TURNS_KEY: string = 'turns';
const MAX_STORED_TURNS: number = 50;

function textFromValue(value: preferences.ValueType | string | number | boolean | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function readTurnsFromRaw(raw: string): ChatMessage[] {
  if (raw.trim().length === 0) {
    return [];
  }
  try {
    const parsed = JSON.parse(raw) as ChatMessage[] | null;
    if (parsed === null || !Array.isArray(parsed)) {
      return [];
    }
    const turns: ChatMessage[] = [];
    for (const item of parsed) {
      if (item === null || item === undefined || typeof item !== 'object') {
        continue;
      }
      const role = `${item.role ?? ''}`.trim();
      const content = `${item.content ?? ''}`.trim();
      if (content.length === 0) {
        continue;
      }
      if (role !== ConversationRole.USER && role !== ConversationRole.ASSISTANT) {
        continue;
      }
      turns.push({ role, content });
    }
    return turns;
  } catch (_error) {
    return [];
  }
}

function trimTurns(turns: ChatMessage[]): ChatMessage[] {
  if (turns.length <= MAX_STORED_TURNS) {
    return turns;
  }
  return turns.slice(turns.length - MAX_STORED_TURNS);
}

function flushPreferences(store: preferences.Preferences): void {
  store.flush().catch((_error: Error) => {});
}

export function loadConversation(context: common.Context): ConversationContext {
  try {
    const store = preferences.getPreferencesSync(context, { name: CONVERSATION_STORE });
    const raw = textFromValue(store.getSync(CONVERSATION_TURNS_KEY, ''));
    return ConversationContext.fromMessages(readTurnsFromRaw(raw));
  } catch (_error) {
    return new ConversationContext();
  }
}

export function saveConversation(context: common.Context, conversation: ConversationContext): void {
  try {
    const store = preferences.getPreferencesSync(context, { name: CONVERSATION_STORE });
    const turns = trimTurns(conversation.toChatMessages());
    store.putSync(CONVERSATION_TURNS_KEY, JSON.stringify(turns));
    flushPreferences(store);
  } catch (_error) {
  }
}

export function clearStoredConversation(context: common.Context): void {
  try {
    const store = preferences.getPreferencesSync(context, { name: CONVERSATION_STORE });
    store.deleteSync(CONVERSATION_TURNS_KEY);
    flushPreferences(store);
  } catch (_error) {
  }
}
