import { common } from '@kit.AbilityKit';
import util from '@ohos.util';

const DEFAULT_COMPOSIO_URL: string = 'https://backend.composio.dev/api/v3.1';
const COMPOSIO_CONFIG_RAWFILE: string = 'composio_config.json';

interface ComposioConfigJson {
  apiKey?: string;
  baseUrl?: string;
  userId?: string;
}

export class ComposioConfig {
  readonly apiKey: string;
  readonly baseUrl: string;
  readonly userId: string;

  constructor(apiKey: string, baseUrl: string, userId: string) {
    this.apiKey = apiKey.trim();
    this.baseUrl = ComposioConfig.trimTrailingSlash(
      baseUrl.trim().length > 0 ? baseUrl : DEFAULT_COMPOSIO_URL
    );
    this.userId = userId.trim();
  }

  isConfigured(): boolean {
    return this.apiKey.length > 0 &&
      this.baseUrl.length > 0 &&
      this.userId.length > 0;
  }

  missingConfiguration(): string {
    const missing: string[] = [];
    if (this.apiKey.length === 0) {
      missing.push('apiKey');
    }
    if (this.userId.length === 0) {
      missing.push('userId');
    }
    return missing.join(', ');
  }

  static async fromContext(context: common.UIAbilityContext): Promise<ComposioConfig> {
    try {
      const raw = await context.resourceManager.getRawFileContent(COMPOSIO_CONFIG_RAWFILE);
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const bytes = raw instanceof ArrayBuffer ? new Uint8Array(raw) : new Uint8Array(raw.buffer);
      const parsed = JSON.parse(decoder.decodeToString(bytes)) as ComposioConfigJson;
      return new ComposioConfig(
        parsed.apiKey ?? '',
        parsed.baseUrl ?? DEFAULT_COMPOSIO_URL,
        parsed.userId ?? ''
      );
    } catch (_error) {
      return new ComposioConfig('', DEFAULT_COMPOSIO_URL, '');
    }
  }

  static fromRawJson(rawJson: string): ComposioConfig {
    try {
      const parsed = JSON.parse(rawJson) as ComposioConfigJson;
      return new ComposioConfig(
        parsed.apiKey ?? '',
        parsed.baseUrl ?? DEFAULT_COMPOSIO_URL,
        parsed.userId ?? ''
      );
    } catch (_error) {
      return new ComposioConfig('', DEFAULT_COMPOSIO_URL, '');
    }
  }

  private static trimTrailingSlash(value: string): string {
    let result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
