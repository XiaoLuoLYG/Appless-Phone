import { common } from '@kit.AbilityKit';
import util from '@ohos.util';

const MODELSCOPE_CONFIG_RAWFILE: string = 'modelscope_config.json';

interface ModelScopeConfigJson {
  mode?: string;
  modelscopeToken?: string;
  modelScopeToken?: string;
  token?: string;
  modelscopeApiBaseUrl?: string;
  modelScopeApiBaseUrl?: string;
}

export class ModelScopeConfig {
  readonly mode: string;
  readonly modelscopeToken: string;
  readonly modelscopeApiBaseUrl: string;

  constructor(
    mode: string,
    modelscopeToken: string,
    modelscopeApiBaseUrl: string
  ) {
    this.mode = mode.trim().toLowerCase();
    this.modelscopeToken = modelscopeToken.trim();
    this.modelscopeApiBaseUrl = ModelScopeConfig.trimTrailingSlash(modelscopeApiBaseUrl.length > 0 ? modelscopeApiBaseUrl : 'https://modelscope.cn');
  }

  isConfigured(): boolean {
    return this.modelscopeToken.length > 0;
  }

  isDirectMode(): boolean {
    return true;
  }

  missingConfiguration(): string {
    const missing: string[] = [];
    if (this.modelscopeToken.length === 0) {
      missing.push('modelscopeToken');
    }
    return missing.join(', ');
  }

  static async fromContext(context: common.UIAbilityContext): Promise<ModelScopeConfig> {
    try {
      const raw = await context.resourceManager.getRawFileContent(MODELSCOPE_CONFIG_RAWFILE);
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const bytes = raw instanceof ArrayBuffer ? new Uint8Array(raw) : new Uint8Array(raw.buffer);
      const parsed = JSON.parse(decoder.decodeToString(bytes)) as ModelScopeConfigJson;
      return new ModelScopeConfig(
        parsed.mode ?? '',
        parsed.modelscopeToken ?? parsed.modelScopeToken ?? parsed.token ?? '',
        parsed.modelscopeApiBaseUrl ?? parsed.modelScopeApiBaseUrl ?? 'https://modelscope.cn'
      );
    } catch (_error) {
      return new ModelScopeConfig('', '', 'https://modelscope.cn');
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
