import http from '@ohos.net.http';
import { ChatMessage, ConversationContext } from '../agent/ConversationContext';
import { LlmProvider } from '../model/LlmProvider';
import { AIPHONE_COMPONENT_CATALOG_JSON } from '../aiphone/runtime/A2uiComponentCatalogConst';
import { A2UI_VERSION } from './A2uiProtocol';
import { A2uiModel } from './A2uiModel';

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

export class OpenAiA2uiModel implements A2uiModel {
  private provider: LlmProvider;

  constructor(provider: LlmProvider) {
    this.provider = provider;
  }

  async generate(userTask: string, surfaceId: string, conversation?: ConversationContext): Promise<string> {
    if (!this.provider.isConfigured()) {
      throw new Error('LLM provider is not configured.');
    }

    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(this.provider.chatCompletionsUrl(), {
        method: http.RequestMethod.POST,
        header: {
          'Authorization': `Bearer ${this.provider.apiKey}`,
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json'
        },
        extraData: JSON.stringify(this.buildRequest(userTask, surfaceId, conversation)),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 120000
      });

      const statusCode = response.responseCode;
      const body = `${response.result ?? ''}`;
      if (statusCode < 200 || statusCode >= 300) {
        throw new Error(`LLM request failed with HTTP ${statusCode}: ${body}`);
      }

      return this.parseContent(body);
    } catch (error) {
      const message = error instanceof Error ? error.message : `${error}`;
      throw new Error(`A2UI LLM request failed: ${message}`);
    } finally {
      httpRequest.destroy();
    }
  }

  private buildRequest(userTask: string, surfaceId: string, conversation?: ConversationContext): ChatRequest {
    const systemPrompt =
      `You plan one constrained A2UI ${A2UI_VERSION} component layout for a mobile UI renderer.\n` +
      'Rules:\n' +
      '- Output exactly one compact JSON line. No markdown or explanation.\n' +
      `- The only envelope is updateComponents for surfaceId "${surfaceId}".\n` +
      '- Never output createSurface, updateDataModel, deleteSurface, provider facts, action IDs, or action args.\n' +
      '- The root component id must be "root" and all children must form one connected acyclic tree.\n' +
      '- Bind content only through dataPath values explicitly listed in the user task.\n' +
      '- An action slot contains only {"offerId":"an offered id"}; never invent or alter an offer.\n' +
      '- Keep at most 24 components. Use only this catalog:\n' +
      AIPHONE_COMPONENT_CATALOG_JSON;

    const messages: ChatMessage[] = [
      { role: 'system', content: systemPrompt }
    ];

    if (conversation !== undefined) {
      const history = conversation.toChatMessages();
      for (const turn of history) {
        messages.push(turn);
      }
    }

    messages.push({
      role: 'user',
      content: userTask
    });

    return {
      model: this.provider.model,
      messages,
      temperature: 0.2
    };
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
