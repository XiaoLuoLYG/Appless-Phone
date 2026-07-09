import {
  A2uiPersonaData,
  A2uiPersonaMemoryData,
  A2uiRuntimeDataModel,
  A2uiSurfaceState
} from '@loop/agent-core';
import { personaMemoryData, personaRuntimeData } from '@loop/agent-core';

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
    sequence: surface.sequence
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
