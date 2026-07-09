import { ConversationContext } from '../agent/ConversationContext';

export interface A2uiModel {
  generate(userTask: string, surfaceId: string, conversation?: ConversationContext): Promise<string>;
}
