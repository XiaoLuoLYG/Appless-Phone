import { ConversationContext } from '../agent/ConversationContext';

export type ModelContentListener = (delta: string) => void;

export interface LocalModel {
  complete(
    prompt: string,
    conversation?: ConversationContext,
    systemPrompt?: string,
    onContent?: ModelContentListener
  ): Promise<string>;
}
