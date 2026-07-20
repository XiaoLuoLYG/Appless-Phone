import { describe, it, expect } from '@ohos/hypium';
import { ChatMessage, ConversationContext } from '@loop/agent-core';

export default function conversationContextTest() {
  describe('conversationContext', () => {
    it('restores only user and assistant messages', 0, () => {
      const messages: ChatMessage[] = [
        { role: 'user', content: ' first ' },
        { role: 'tool', content: 'ignore me' },
        { role: 'assistant', content: ' second ' }
      ];

      const restored = ConversationContext.fromMessages(messages).toChatMessages();

      expect(restored.length).assertEqual(2);
      expect(restored[0].role).assertEqual('user');
      expect(restored[0].content).assertEqual('first');
      expect(restored[1].role).assertEqual('assistant');
      expect(restored[1].content).assertEqual('second');
    });
  });
}
