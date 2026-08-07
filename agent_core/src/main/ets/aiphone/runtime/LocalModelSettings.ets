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
  DEEPSEEK_API_KEY?: string;
}

const DEEPSEEK_PROVIDER: string = 'CSI.AI';
const DEEPSEEK_BASE_URL: string = 'http://113.46.219.251:8080/v1/chat/completions';
const DEEPSEEK_MODEL: string = 'Deepseek-V4-Flash-0731';
const DASHSCOPE_PROVIDER: string = 'DashScope';
const DASHSCOPE_BASE_URL: string = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
const DASHSCOPE_MODEL: string = 'qwen-max';
const DEFAULT_CUSTOM_PARAMETERS_JSON: string = '{"enable_thinking":false}';

let dashScopeApiKey: string = '';
let deepSeekApiKey: string = '';

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
  deepSeekApiKey = textOf(parsed.DEEPSEEK_API_KEY).trim();
}

export function localModelSettingsDebugSummary(): string {
  return 'provider=' + DEEPSEEK_PROVIDER +
    ', model=' + DEEPSEEK_MODEL +
    ', dashScopeApiKey=' + (dashScopeApiKey.length > 0 ? 'present(' + dashScopeApiKey.length.toString() + ')' : 'missing') +
    ', deepSeekApiKey=' + (deepSeekApiKey.length > 0 ? 'present(' + deepSeekApiKey.length.toString() + ')' : 'missing');
}

export function deepSeekModelSettings(): LocalModelSettings {
  return {
    provider: DEEPSEEK_PROVIDER,
    baseUrl: DEEPSEEK_BASE_URL,
    model: DEEPSEEK_MODEL,
    apiKey: deepSeekApiKey,
    customParametersJson: DEFAULT_CUSTOM_PARAMETERS_JSON,
    ignoreToolSurfaceUpdates: false
  };
}

export function dashScopeModelSettings(): LocalModelSettings {
  return {
    provider: DASHSCOPE_PROVIDER,
    baseUrl: DASHSCOPE_BASE_URL,
    model: DASHSCOPE_MODEL,
    apiKey: dashScopeApiKey,
    customParametersJson: DEFAULT_CUSTOM_PARAMETERS_JSON,
    ignoreToolSurfaceUpdates: false
  };
}

export function defaultLocalModelSettings(): LocalModelSettings {
  return deepSeekModelSettings();
}
