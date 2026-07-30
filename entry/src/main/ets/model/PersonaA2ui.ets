import {
  A2uiPersonaData,
  A2uiPersonaMemoryData,
  A2uiRuntimeDataModel,
  A2uiSurfaceState
} from '@loop/agent-core';
import { personaMemoryData, personaRuntimeData } from '@loop/agent-core';
import { markdownSectionValue, parsePersonaMarkdown } from './PersonaMarkdown';
import { personaPackForId } from './PersonaStore';

function cloneSurface(surface: A2uiSurfaceState, dataModelJson: string): A2uiSurfaceState {
  return {
    surfaceId: surface.surfaceId,
    rootId: surface.rootId,
    title: surface.title,
    intent: surface.intent,
    status: surface.status,
    components: surface.components,
    dataModelJson: dataModelJson,
    error: surface.error,
    sequence: surface.sequence,
    runtimeOwner: surface.runtimeOwner,
    runtimeGeneration: surface.runtimeGeneration
  };
}

export function attachPersonaDataToSurface(
  surface: A2uiSurfaceState,
  persona: A2uiPersonaData,
  personaMemory: A2uiPersonaMemoryData
): A2uiSurfaceState {
  try {
    const model = JSON.parse(surface.dataModelJson.length > 0 ? surface.dataModelJson : '{}') as A2uiRuntimeDataModel;
    model.persona = persona;
    model.personaMemory = personaMemory;
    return cloneSurface(surface, JSON.stringify(model));
  } catch (_error) {
    return cloneSurface(surface, JSON.stringify({
      persona: persona,
      personaMemory: personaMemory
    }));
  }
}

export function copyPersonaData(source: A2uiSurfaceState, target: A2uiSurfaceState): A2uiSurfaceState {
  const persona = personaRuntimeData(source);
  if (persona.id.length === 0) {
    return target;
  }
  return attachPersonaDataToSurface(target, persona, personaMemoryData(source));
}

function stablePreferenceLines(memory: string): string[] {
  const parsed = parsePersonaMarkdown(memory);
  const stable = markdownSectionValue(parsed.sections, 'Stable Preferences').trim();
  const source = stable.length > 0 ? stable : parsed.body;
  return source.split('\n')
    .map((line: string): string => line.replace(/^[-*]\s*/, '').trim())
    .filter((line: string): boolean => line.length > 0)
    .slice(0, 4);
}

export function attachLeaderPersonaDataToSurface(
  surface: A2uiSurfaceState,
  personaId: string,
  skillId: string
): A2uiSurfaceState {
  if (personaRuntimeData(surface).id === personaId) {
    return surface;
  }
  const pack = personaPackForId(personaId);
  if (pack.manifest.id !== personaId) {
    return surface;
  }
  const preferences = stablePreferenceLines(pack.memory);
  return attachPersonaDataToSurface(surface, {
    id: pack.manifest.id,
    name: pack.manifest.name,
    avatarKey: pack.manifest.avatarKey,
    status: 'online',
    reason: skillId.length > 0 ?
      'Leader 已选择该分身及其场景能力。' : 'Leader 已选择该分身。'
  }, {
    summary: preferences.length > 0 ? preferences.join('；') : '暂无已记录的稳定偏好。',
    preferences
  });
}

export function leaderPersonaSurfaceUpdate(
  surface: A2uiSurfaceState,
  personaId: string,
  skillId: string
): A2uiSurfaceState {
  const attached: A2uiSurfaceState =
    attachLeaderPersonaDataToSurface(surface, personaId, skillId);
  if (attached === surface || attached.dataModelJson === surface.dataModelJson) {
    return surface;
  }
  attached.sequence = surface.sequence + 1;
  return attached;
}
