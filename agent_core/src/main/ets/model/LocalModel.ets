import { ConversationContext } from '../agent/ConversationContext';

export interface LocalModel {
  complete(prompt: string, conversation?: ConversationContext, systemPrompt?: string): Promise<string>;
}
