import { ConversationContext } from '../agent/ConversationContext';

export interface LocalModel {
  complete(prompt: string, conversation?: ConversationContext): Promise<string>;
}
