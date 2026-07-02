export enum ConversationRole {
  USER = 'user',
  ASSISTANT = 'assistant'
}

export interface ChatMessage {
  role: string;
  content: string;
}

export class ConversationContext {
  private turns: ChatMessage[] = [];

  addUser(text: string): void {
    this.turns.push({ role: ConversationRole.USER, content: text.trim() });
  }

  addAssistant(text: string): void {
    this.turns.push({ role: ConversationRole.ASSISTANT, content: text.trim() });
  }

  clear(): void {
    this.turns = [];
  }

  isEmpty(): boolean {
    return this.turns.length === 0;
  }

  toChatMessages(): ChatMessage[] {
    return this.turns.slice();
  }

  formatPriorConversation(): string {
    if (this.isEmpty()) {
      return '';
    }

    let block = 'Previous conversation:\n';
    for (const turn of this.turns) {
      const label = turn.role === ConversationRole.USER ? 'User' : 'Assistant';
      block += `${label}: ${turn.content}\n`;
    }
    return `${block.trim()}\n\n`;
  }
}
