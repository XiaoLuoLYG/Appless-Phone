import http from '@ohos.net.http';
import { ChatMessage, ConversationContext } from '../agent/ConversationContext';
import { LocalModel } from './LocalModel';
import { LlmProvider } from './LlmProvider';

const MODEL_CONNECT_TIMEOUT_MS = 20000;
const MODEL_READ_TIMEOUT_MS = 40000;
const MODEL_MAX_ATTEMPTS = 2;

interface ChatRequest {
  model: string;
  messages: ChatMessage[];
  temperature: number;
}

interface ChatChoice {
  message?: ChatMessage;
}

interface ChatResponse {
  choices?: ChatChoice[];
}

export class OpenAiCompatibleModel implements LocalModel {
  private provider: LlmProvider;

  constructor(provider: LlmProvider) {
    this.provider = provider;
  }

  async complete(prompt: string, conversation?: ConversationContext): Promise<string> {
    if (!this.provider.isConfigured()) {
      throw new Error('LLM provider is not configured.');
    }

    let lastMessage = '';
    for (let attempt = 0; attempt < MODEL_MAX_ATTEMPTS; attempt++) {
      try {
        return await this.completeOnce(prompt, conversation);
      } catch (error) {
        lastMessage = this.describeThrown(error);
        if (attempt + 1 >= MODEL_MAX_ATTEMPTS || !this.isRetryableTransportError(lastMessage)) {
          throw new Error(`LLM request failed: ${lastMessage}`);
        }
      }
    }
    throw new Error(`LLM request failed: ${lastMessage}`);
  }

  private async completeOnce(prompt: string, conversation?: ConversationContext): Promise<string> {
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(this.provider.chatCompletionsUrl(), {
        method: http.RequestMethod.POST,
        header: {
          'Authorization': `Bearer ${this.provider.apiKey}`,
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json'
        },
        extraData: this.buildRequestJson(prompt, conversation),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: MODEL_CONNECT_TIMEOUT_MS,
        readTimeout: MODEL_READ_TIMEOUT_MS
      });

      const statusCode = response.responseCode;
      const body = `${response.result ?? ''}`;
      if (statusCode < 200 || statusCode >= 300) {
        throw new Error(`LLM request failed with HTTP ${statusCode}: ${body}`);
      }

      return this.parseContent(body);
    } catch (error) {
      throw new Error(this.describeThrown(error));
    } finally {
      httpRequest.destroy();
    }
  }

  private describeThrown(error: Error | Object | string | number | boolean | null | undefined): string {
    if (error instanceof Error) {
      return error.message;
    }
    if (error === undefined || error === null) {
      return `${error}`;
    }
    try {
      const json = JSON.stringify(error);
      if (json !== undefined && json.length > 0 && json !== '{}') {
        return json;
      }
    } catch (_jsonError) {
    }
    return `${error}`;
  }

  private isRetryableTransportError(message: string): boolean {
    const lower = message.toLowerCase();
    if (lower.indexOf('http 4') >= 0 || lower.indexOf('http 5') >= 0) {
      return false;
    }
    return lower.indexOf('[object object]') >= 0 ||
      lower.indexOf('2300') >= 0 ||
      lower.indexOf('timeout') >= 0 ||
      lower.indexOf('failed to receive') >= 0 ||
      lower.indexOf('connection') >= 0 ||
      lower.indexOf('network') >= 0;
  }

  private buildRequest(prompt: string, conversation?: ConversationContext): ChatRequest {
    const messages: ChatMessage[] = [
      {
        role: 'system',
        content: 'You are Loop, a concise ReAct agent on HarmonyOS. Reply with Thought and either Action: tool(JSON object) or Final: answer. Use only listed tools and follow the tool-routing rules in the prompt exactly.'
      }
    ];

    if (conversation !== undefined) {
      const history = conversation.toChatMessages();
      for (const turn of history) {
        messages.push(turn);
      }
    }

    messages.push({
      role: 'user',
      content: prompt
    });

    return {
      model: this.provider.model,
      messages,
      temperature: 0.2
    };
  }

  private buildRequestJson(prompt: string, conversation?: ConversationContext): string {
    const baseJson = JSON.stringify(this.buildRequest(prompt, conversation));
    const customJson = this.provider.customParametersJson.trim();
    if (customJson.length === 0) {
      return baseJson;
    }
    try {
      const parsed = JSON.parse(customJson) as Object;
      if (parsed === undefined || parsed === null || Array.isArray(parsed)) {
        return baseJson;
      }
      if (customJson.search(/"model"\s*:/) >= 0 || customJson.search(/"messages"\s*:/) >= 0) {
        return baseJson;
      }
      const normalizedCustomJson = JSON.stringify(parsed);
      if (normalizedCustomJson.length <= 2) {
        return baseJson;
      }
      return baseJson.substring(0, baseJson.length - 1) + ',' + normalizedCustomJson.substring(1);
    } catch (_error) {
      return baseJson;
    }
  }

  private parseContent(body: string): string {
    const json = JSON.parse(body) as ChatResponse;
    const choices = json.choices;
    if (choices === undefined || choices.length === 0) {
      throw new Error('No choices returned.');
    }

    const message = choices[0].message;
    if (message === undefined || message.content === undefined) {
      throw new Error('No message content returned.');
    }
    return message.content.trim();
  }
}
