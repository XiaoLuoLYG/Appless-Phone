import { AgentEvent, AgentEventKind } from './AgentEvent';
import { ChatMessage, ConversationContext } from './ConversationContext';
import {
  AgentListener,
  ReActAgentRunner,
  ReActRunOptions,
  UiRenderHandler
} from './ReActAgentRunner';
import { ToolRegistry } from './ToolRegistry';
import { LocalModel } from '../model/LocalModel';

const MAX_CONTEXT_MESSAGES: number = 50;

export class ReActAgent {
  readonly name: string;

  private readonly identityPrompt: string;
  private readonly tools: ToolRegistry;
  private readonly runner: ReActAgentRunner;
  private conversation: ConversationContext;

  constructor(
    name: string,
    identityPrompt: string,
    model: LocalModel,
    maxSteps: number,
    tools: ToolRegistry,
    uiHandler?: UiRenderHandler,
    initialContext?: ConversationContext
  ) {
    this.name = name;
    this.identityPrompt = identityPrompt.trim();
    tools.seal();
    this.tools = tools;
    this.runner = new ReActAgentRunner(model, tools, maxSteps, uiHandler);
    this.conversation = initialContext === undefined
      ? new ConversationContext()
      : ConversationContext.fromMessages(initialContext.toChatMessages());
  }

  protected clearContext(): void {
    this.conversation.clear();
  }

  async close(): Promise<void> {
    await this.tools.close();
  }

  protected async executeTask(task: string, listener: AgentListener): Promise<void> {
    const normalizedTask = task.trim();
    if (normalizedTask.length === 0) {
      listener(new AgentEvent(AgentEventKind.ERROR, 'Agent task is empty.'));
      return;
    }

    let finalAnswer: string | null = null;
    const options: ReActRunOptions = {
      identityPrompt: this.identityPrompt
    };
    await this.runner.run(
      normalizedTask,
      (event: AgentEvent): void => {
        if (finalAnswer === null && event.kind === AgentEventKind.FINAL) {
          finalAnswer = event.text;
        }
        listener(event);
      },
      this.conversation,
      options
    );

    if (finalAnswer !== null) {
      this.appendContext(normalizedTask, finalAnswer);
    }
  }

  private appendContext(task: string, finalAnswer: string): void {
    const messages = this.conversation.toChatMessages();
    messages.push({ role: 'user', content: task });
    messages.push({ role: 'assistant', content: finalAnswer.trim() });
    const retained: ChatMessage[] = messages.length > MAX_CONTEXT_MESSAGES
      ? messages.slice(messages.length - MAX_CONTEXT_MESSAGES)
      : messages;
    this.conversation = ConversationContext.fromMessages(retained);
  }
}
