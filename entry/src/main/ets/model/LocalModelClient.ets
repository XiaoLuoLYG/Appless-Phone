import {
  A2uiMessage,
  ConversationContext,
  LlmProvider,
  LocalModelSettings,
  OpenAiCompatibleModel,
  aiLogError,
  aiLogInfo
} from '@loop/agent-core';

export interface DirectModelCallResult {
  ok: boolean;
  raw: string;
  error: string;
  requestDebug: string;
  assistantDebug: string;
}

export function directModelSystemPrompt(): string {
  return 'You are Appless direct text model. Return only the requested text or JSON. Do not call tools.';
}

export function directModelRequestDebug(
  settings: LocalModelSettings,
  prompt: string,
  historyTurns: number
): string {
  return JSON.stringify({
    endpoint: 'OpenAiCompatibleModel.direct',
    provider: settings.provider,
    baseUrl: settings.baseUrl,
    model: settings.model,
    promptChars: prompt.length,
    historyTurns
  });
}

function directConversation(history: A2uiMessage[]): ConversationContext {
  const conversation = new ConversationContext();
  history.forEach((message: A2uiMessage) => {
    if (message.role === 'user') {
      conversation.addUser(message.content);
    } else if (message.role === 'assistant') {
      conversation.addAssistant(message.content);
    }
  });
  return conversation;
}

export async function callDirectModel(
  settings: LocalModelSettings,
  prompt: string,
  history: A2uiMessage[],
  systemPrompt: string = directModelSystemPrompt()
): Promise<DirectModelCallResult> {
  const requestDebug = directModelRequestDebug(settings, prompt, history.length);
  const provider = new LlmProvider(
    settings.provider,
    settings.apiKey,
    settings.baseUrl,
    settings.model,
    settings.customParametersJson
  );
  const model = new OpenAiCompatibleModel(provider);
  try {
    const raw = await model.complete(
      prompt,
      directConversation(history),
      systemPrompt
    );
    aiLogInfo('[AIPhone][DirectModelResult] ok=true rawChars=' + raw.length.toString());
    return {
      ok: true,
      raw,
      error: '',
      requestDebug,
      assistantDebug: raw
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    aiLogError('[AIPhone][DirectModelException] ' + message.substring(0, 240));
    return {
      ok: false,
      raw: '',
      error: message,
      requestDebug,
      assistantDebug: ''
    };
  }
}
