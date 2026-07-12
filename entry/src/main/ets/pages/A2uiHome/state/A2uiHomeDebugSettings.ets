import { HtmlHomeDocument } from '../html/HtmlHomeTypes';
import { personaAvatarDataUri } from '../html/PersonaAvatarDataUri';

export const A2UI_FOOD_PROVIDER_DELAY_MAX_MS: number = 30000;
export const A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS: number = 500;
export const A2UI_FOOD_PARTIAL_THROTTLE_MAX_MS: number = 5000;
export const HTML_HOME_DEBUG_EXPORT_FILE_NAME: string = 'html-home-document-debug.json';

interface HtmlHomeDebugExportDocument extends HtmlHomeDocument {
  isBusy?: boolean;
  personaAvatarDataUri?: string;
}

export function normalizeFoodProviderDelayMs(value: string): number {
  const parsed = Number.parseInt(value.trim());
  if (Number.isNaN(parsed) || parsed < 0) {
    return 0;
  }
  if (parsed > A2UI_FOOD_PROVIDER_DELAY_MAX_MS) {
    return A2UI_FOOD_PROVIDER_DELAY_MAX_MS;
  }
  return parsed;
}

export function normalizeFoodPartialThrottleMs(value: string): number {
  const parsed = Number.parseInt(value.trim());
  if (Number.isNaN(parsed)) {
    return A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS;
  }
  if (parsed < 0) {
    return 0;
  }
  if (parsed > A2UI_FOOD_PARTIAL_THROTTLE_MAX_MS) {
    return A2UI_FOOD_PARTIAL_THROTTLE_MAX_MS;
  }
  return parsed;
}

export function htmlHomeDebugExportJson(document: HtmlHomeDocument, isBusy: boolean): string {
  const exportDocument: HtmlHomeDebugExportDocument = {
    version: document.version,
    source: document.source,
    kind: document.kind,
    title: document.title,
    subtitle: document.subtitle,
    chips: document.chips,
    metrics: document.metrics,
    timeline: document.timeline,
    blocks: document.blocks,
    actions: document.actions,
    history: [],
    persona: document.persona,
    personaMemory: document.personaMemory,
    personaAvatarDataUri: personaAvatarDataUri(document.persona.avatarKey),
    rawSurfaceRoot: null,
    generatedAt: '',
    isBusy: isBusy || (document as HtmlHomeDebugExportDocument).isBusy === true
  };
  return JSON.stringify(exportDocument, null, 2) + '\n';
}
