import http from '@ohos.net.http';
import util from '@ohos.util';
import { ChatMessage, ConversationContext } from '../agent/ConversationContext';
import { aiLogInfo } from '../aiphone/runtime/AiphoneLogger';
import { buildSkillsSection, SkillSnapshot } from '../skill/SkillSnapshot';
import { ChatCompletionSseParser } from './ChatCompletionSseParser';
import { LocalModel, ModelContentListener } from './LocalModel';
import { LlmProvider } from './LlmProvider';

const MODEL_CONNECT_TIMEOUT_MS = 20000;
const MODEL_READ_TIMEOUT_MS = 40000;
const MODEL_MAX_ATTEMPTS = 2;

interface ChatRequest {
  model: string;
  messages: ChatMessage[];
  temperature: number;
  stream: boolean;
}

interface ChatChoice {
  message?: ChatMessage;
}

interface ChatResponse {
  choices?: ChatChoice[];
}

interface ChatDelta {
  content?: string | null;
}

interface ChatStreamChoice {
  index?: number;
  delta?: ChatDelta;
  finish_reason?: string | null;
}

interface ChatStreamResponse {
  choices?: ChatStreamChoice[];
}

export class OpenAiCompatibleModel implements LocalModel {
  private provider: LlmProvider;
  private skillSnapshot: SkillSnapshot | null;

  constructor(provider: LlmProvider, skillSnapshot?: SkillSnapshot) {
    this.provider = provider;
    this.skillSnapshot = skillSnapshot ?? null;
  }

  async complete(
    prompt: string,
    conversation?: ConversationContext,
    onContent?: ModelContentListener
  ): Promise<string> {
    if (!this.provider.isConfigured()) {
      throw new Error('LLM provider is not configured.');
    }

    let lastMessage = '';
    let semanticOutputSeen = false;
    const trackedContent = (delta: string): void => {
      if (delta.length > 0) {
        semanticOutputSeen = true;
      }
      onContent?.(delta);
    };
    for (let attempt = 0; attempt < MODEL_MAX_ATTEMPTS; attempt++) {
      try {
        return await this.completeOnce(prompt, conversation, trackedContent);
      } catch (error) {
        lastMessage = this.describeThrown(error);
        if (semanticOutputSeen || attempt + 1 >= MODEL_MAX_ATTEMPTS || !this.isRetryableTransportError(lastMessage)) {
          throw new Error(`LLM request failed: ${lastMessage}`);
        }
      }
    }
    throw new Error(`LLM request failed: ${lastMessage}`);
  }

  private async completeOnce(
    prompt: string,
    conversation: ConversationContext | undefined,
    onContent: ModelContentListener
  ): Promise<string> {
    const httpRequest = http.createHttp();
    const decoder = util.TextDecoder.create('utf-8');
    const sseParser = new ChatCompletionSseParser();
    const requestStartMs = Date.now();
    const rawChunks: string[] = [];
    const contentParts: string[] = [];
    let chunkSequence = 0;
    let sseEventSequence = 0;
    let streamParseError: Error | null = null;
    let streamEndResolve: () => void = () => {};
    const streamEnd = new Promise<void>((resolve: () => void) => {
      streamEndResolve = resolve;
    });
    httpRequest.on('dataReceive', (data: ArrayBuffer) => {
      chunkSequence++;
      const chunk = decoder.decodeToString(new Uint8Array(data), { stream: true });
      rawChunks.push(chunk);
      const preview = chunk.replace(/\r/g, '\\r').replace(/\n/g, '\\n');
      aiLogInfo(
        '[AIPhone][ModelResponseChunk] seq=' + chunkSequence.toString() +
        ' bytes=' + data.byteLength.toString() +
        ' chars=' + chunk.length.toString() +
        ' elapsedMs=' + (Date.now() - requestStartMs).toString() +
        ' data=' + preview
      );
      if (streamParseError === null) {
        try {
          sseEventSequence += this.consumeSsePayloads(sseParser.feed(chunk), contentParts, onContent);
        } catch (error) {
          streamParseError = new Error(this.describeThrown(error));
        }
      }
    });
    httpRequest.on('dataEnd', () => {
      streamEndResolve();
    });
    try {
      const endpoint = this.provider.chatCompletionsUrl();
      const requestJson = this.buildRequestJson(prompt, conversation);
      aiLogInfo(
        '[AIPhone][ModelRequestStart] model=' + this.provider.model +
        ' endpoint=' + endpoint +
        ' stream=true' +
        ' promptHasXmlToolRule=' + (prompt.indexOf('<appless_tool>') >= 0).toString()
      );
      const statusCode = await httpRequest.requestInStream(endpoint, {
        method: http.RequestMethod.POST,
        header: {
          'Authorization': `Bearer ${this.provider.apiKey}`,
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'text/event-stream'
        },
        extraData: requestJson,
        connectTimeout: MODEL_CONNECT_TIMEOUT_MS,
        readTimeout: MODEL_READ_TIMEOUT_MS
      });
      streamEndResolve();
      await streamEnd;
      const decoderTail = decoder.decodeToString(new Uint8Array(0), { stream: false });
      if (decoderTail.length > 0) {
        rawChunks.push(decoderTail);
      }
      if (streamParseError === null) {
        try {
          sseEventSequence += this.consumeSsePayloads(sseParser.feed(decoderTail), contentParts, onContent);
          sseEventSequence += this.consumeSsePayloads(sseParser.finish(), contentParts, onContent);
        } catch (error) {
          streamParseError = new Error(this.describeThrown(error));
        }
      }
      const rawResponse = rawChunks.join('');

      if (statusCode < 200 || statusCode >= 300) {
        throw new Error(`LLM request failed with HTTP ${statusCode}: ${rawResponse}`);
      }
      if (streamParseError !== null) {
        throw streamParseError;
      }

      let content = contentParts.join('').trim();
      if (content.length === 0) {
        content = this.parseContent(rawResponse);
        onContent(content);
      }
      aiLogInfo(
        '[AIPhone][ModelStreamComplete] chunks=' + chunkSequence.toString() +
        ' sseEvents=' + sseEventSequence.toString() +
        ' contentChars=' + content.length.toString() +
        ' elapsedMs=' + (Date.now() - requestStartMs).toString()
      );
      return content;
    } catch (error) {
      throw new Error(this.describeThrown(error));
    } finally {
      httpRequest.destroy();
    }
  }

  private consumeSsePayloads(
    payloads: string[],
    contentParts: string[],
    onContent: ModelContentListener
  ): number {
    let consumed = 0;
    for (let index = 0; index < payloads.length; index++) {
      const payload = payloads[index];
      consumed++;
      if (payload.length === 0 || payload === '[DONE]') {
        continue;
      }

      const event = JSON.parse(payload) as ChatStreamResponse;
      const choices = event.choices;
      if (choices === undefined || choices.length === 0 || choices[0].delta === undefined) {
        continue;
      }
      const deltaContent = choices[0].delta?.content;
      if (typeof deltaContent === 'string' && deltaContent.length > 0) {
        contentParts.push(deltaContent);
        onContent(deltaContent);
      }
    }
    return consumed;
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
        content: this.systemPrompt()
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
      temperature: 0.2,
      stream: true
    };
  }

  private systemPrompt(): string {
    let content = 'You are Loop, a concise ReAct agent on HarmonyOS. Every response must use exactly one of these two forms:\n' +
      'Thought: brief reasoning\n<appless_tool>tool.name({"key":"value"})</appless_tool>\n' +
      'or:\nThought: brief reasoning\nFinal: answer\n' +
      'A response that ends after Thought is invalid. If Thought says a tool will be used, the very next line must be <appless_tool>...</appless_tool>. Never merely describe or announce a tool call. After </appless_tool>, you may continue with ordinary status text, but never emit another tool call in the same response. Use only listed tools and follow the tool-routing rules in the prompt exactly.';
    const skills = buildSkillsSection(this.skillSnapshot);
    if (skills.length > 0) {
      content += `\n\n${skills}`;
    }
    return content;
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
    const trimmed = body.trim();
    if (trimmed.startsWith('{')) {
      return this.parseJsonContent(trimmed);
    }

    let content = '';
    const lines = body.replace(/\r\n/g, '\n').split('\n');
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index].trim();
      if (!line.startsWith('data:')) {
        continue;
      }
      const payload = line.substring('data:'.length).trim();
      if (payload.length === 0 || payload === '[DONE]') {
        continue;
      }
      const event = JSON.parse(payload) as ChatStreamResponse;
      const choices = event.choices;
      if (choices === undefined || choices.length === 0 || choices[0].delta === undefined) {
        continue;
      }
      const deltaContent = choices[0].delta?.content;
      if (typeof deltaContent === 'string') {
        content += deltaContent;
      }
    }
    if (content.length === 0) {
      throw new Error('No streaming message content returned.');
    }
    return content.trim();
  }

  private parseJsonContent(body: string): string {
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
