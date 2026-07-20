export interface LocalModelSettings {
  provider: string;
  baseUrl: string;
  model: string;
  apiKey: string;
  customParametersJson: string;
  ignoreToolSurfaceUpdates: boolean;
}

interface LocalModelRawConfig {
  DASHSCOPE_API_KEY?: string;
}

const DEFAULT_PROVIDER: string = 'DashScope';
const DEFAULT_BASE_URL: string = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
const DEFAULT_MODEL: string = 'qwen-max';
const DEFAULT_CUSTOM_PARAMETERS_JSON: string = '{"enable_thinking":false}';

let dashScopeApiKey: string = '';

function textOf(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

export function configureLocalModelSettingsFromRawJson(rawJson: string): void {
  const parsed = JSON.parse(rawJson) as LocalModelRawConfig;
  dashScopeApiKey = textOf(parsed.DASHSCOPE_API_KEY).trim();
}

export function localModelSettingsDebugSummary(): string {
  return 'provider=' + DEFAULT_PROVIDER +
    ', model=' + DEFAULT_MODEL +
    ', dashScopeApiKey=' + (dashScopeApiKey.length > 0 ? 'present(' + dashScopeApiKey.length.toString() + ')' : 'missing');
}

export function defaultLocalModelSettings(): LocalModelSettings {
  return {
    provider: DEFAULT_PROVIDER,
    baseUrl: DEFAULT_BASE_URL,
    model: DEFAULT_MODEL,
    apiKey: dashScopeApiKey,
    customParametersJson: DEFAULT_CUSTOM_PARAMETERS_JSON,
    ignoreToolSurfaceUpdates: false
  };
}
