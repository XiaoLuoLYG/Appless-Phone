import { A2uiObservationDigest, summarizeAppliedA2uiSurface } from './A2uiObservationDigest';
import { MultiToolSectionContent, MultiToolSlotStatus } from './MultiToolTypes';
import { parseA2uiJsonl } from '../aiphone/runtime/A2uiParser';
import { A2uiSurfaceStore } from '../aiphone/runtime/A2uiSurfaceStore';
import { A2uiEnvelope, A2uiSurfaceState } from '../aiphone/runtime/A2uiTypes';

function defaultSectionTitle(toolId: string): string {
  if (toolId === 'flight.search') {
    return '航班';
  }
  if (toolId === 'food.search') {
    return '美食';
  }
  if (toolId === 'train.search') {
    return '高铁';
  }
  if (toolId === 'travel.search') {
    return '出行';
  }
  if (toolId === 'luckin.order.preview') {
    return '瑞幸点单';
  }
  return toolId;
}

function slotStatusFromDigest(failureKey: string, errorText: string): MultiToolSlotStatus {
  if (failureKey.indexOf(':error') >= 0 || errorText.length > 0) {
    return 'error';
  }
  return 'ready';
}

function nonA2uiDigest(observationRaw: string): A2uiObservationDigest {
  return {
    isA2ui: false,
    text: observationRaw,
    shouldStop: false,
    failureKey: '',
    finalText: ''
  };
}

export function ingestToolObservation(
  slotId: string,
  toolId: string,
  observationRaw: string
): MultiToolSectionContent {
  const parsed = parseA2uiJsonl(observationRaw);
  let embeddedSurface: A2uiSurfaceState | null = null;
  let title = defaultSectionTitle(toolId);
  let digest: A2uiObservationDigest = nonA2uiDigest(observationRaw);
  if (parsed.error.length === 0 && parsed.envelopes.length > 0) {
    const store = new A2uiSurfaceStore();
    for (let index = 0; index < parsed.envelopes.length; index++) {
      const envelope: A2uiEnvelope = parsed.envelopes[index];
      const applied = store.apply(envelope);
      if (!applied.ok) {
        digest = {
          isA2ui: true,
          text: 'ObservationDigest\nerror: ' + applied.error,
          shouldStop: true,
          failureKey: 'a2ui:error',
          finalText: ''
        };
        break;
      }
    }
    if (digest.failureKey !== 'a2ui:error') {
      embeddedSurface = store.getSurface();
      digest = summarizeAppliedA2uiSurface(observationRaw, embeddedSurface);
      if (embeddedSurface.title.trim().length > 0) {
        title = embeddedSurface.title.trim();
      }
    }
  }
  const summary = digest.isA2ui ? digest.text.split('\n').slice(0, 3).join(' ') : observationRaw.substring(0, 180);
  return {
    slotId: slotId,
    toolId: toolId,
    title: title,
    status: slotStatusFromDigest(digest.failureKey, parsed.error),
    summary: summary,
    observationDigest: digest.text,
    failureKey: digest.failureKey,
    embeddedSurface: embeddedSurface
  };
}
