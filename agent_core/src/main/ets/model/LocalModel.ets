import { ConversationContext } from '../agent/ConversationContext';

export type ModelContentListener = (delta: string) => void;

export interface LocalModel {
  complete(prompt: string, conversation?: ConversationContext, onContent?: ModelContentListener): Promise<string>;
}
