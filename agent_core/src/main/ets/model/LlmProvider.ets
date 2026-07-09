import util from '@ohos.util';
import { common } from '@kit.AbilityKit';

interface LlmConfigJson {
  providerName?: string;
  apiKey?: string;
  baseUrl?: string;
  model?: string;
  customParametersJson?: string;
}

export class LlmProvider {
  readonly name: string;
  readonly apiKey: string;
  readonly baseUrl: string;
  readonly model: string;
  readonly customParametersJson: string;

  constructor(name: string, apiKey: string, baseUrl: string, model: string, customParametersJson: string = '') {
    this.name = name;
    this.apiKey = apiKey;
    this.baseUrl = LlmProvider.trimTrailingSlash(baseUrl);
    this.model = model;
    this.customParametersJson = customParametersJson.trim();
  }

  isConfigured(): boolean {
    return this.apiKey.trim().length > 0
      && this.baseUrl.trim().length > 0
      && this.model.trim().length > 0;
  }

  chatCompletionsUrl(): string {
    if (this.baseUrl.endsWith('/v1/chat/completions') || this.baseUrl.endsWith('/chat/completions')) {
      return this.baseUrl;
    }
    if (this.baseUrl.endsWith('/v1')) {
      return `${this.baseUrl}/chat/completions`;
    }
    return `${this.baseUrl}/v1/chat/completions`;
  }

  static async fromContext(context: common.UIAbilityContext): Promise<LlmProvider> {
    try {
      const raw = await context.resourceManager.getRawFileContent('llm_config.json');
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const bytes = raw instanceof ArrayBuffer ? new Uint8Array(raw) : new Uint8Array(raw.buffer);
      const text = decoder.decodeToString(bytes);
      const json = JSON.parse(text) as LlmConfigJson;
      return new LlmProvider(
        json.providerName ?? '',
        json.apiKey ?? '',
        json.baseUrl ?? '',
        json.model ?? '',
        json.customParametersJson ?? ''
      );
    } catch (_error) {
      return new LlmProvider('', '', '', '');
    }
  }

  private static trimTrailingSlash(value: string): string {
    let trimmed = value.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
