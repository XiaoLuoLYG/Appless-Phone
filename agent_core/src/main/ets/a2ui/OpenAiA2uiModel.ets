import http from '@ohos.net.http';
import { ChatMessage, ConversationContext } from '../agent/ConversationContext';
import { LlmProvider } from '../model/LlmProvider';
import { AGENUI_CATALOG_ID, A2UI_VERSION } from './A2uiProtocol';
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
    const exampleComponents =
      `{"version":"${A2UI_VERSION}","updateComponents":{"surfaceId":"${surfaceId}",` +
      `"components":[{"id":"root","component":"Card","child":"col"},` +
      `{"id":"col","component":"Column","children":["title","body"],"align":"stretch"},` +
      `{"id":"title","component":"Text","text":"Hello","variant":"h3"},` +
      `{"id":"body","component":"Text","text":"Your message here","variant":"body"}]}}`;

    const systemPrompt =
      `You output A2UI ${A2UI_VERSION} JSONL for a mobile UI renderer.\n` +
      'Rules:\n' +
      '- Output ONLY JSON lines. No markdown, no explanation.\n' +
      `- Line 1: createSurface with surfaceId "${surfaceId}" and catalogId "${AGENUI_CATALOG_ID}"\n` +
      '- Line 2: updateComponents with a flat components array and id "root"\n' +
      '- Use only: Card, Column, Row, Text, Button, Divider\n' +
      '- Text must use plain string "text", not markdown\n' +
      '- Keep 4-8 components maximum\n' +
      `Example line 2:\n${exampleComponents}`;

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
      content:
        `Build a simple Card UI for: ${userTask}\n` +
        'Include a title Text (variant h3) and body Text (variant body).'
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
