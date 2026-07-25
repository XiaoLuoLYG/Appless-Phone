import { A2uiSurfaceState } from '../aiphone/runtime/A2uiTypes';
import { mergeSectionIntoDataModel } from './MultiTaskDataModel';
import { ingestToolObservation } from './MultiToolSectionAdapters';
import { MultiTaskBoardData, MultiToolSectionValue } from './MultiToolTypes';

function toolIdMatchesSlot(slotToolId: string, actionToolId: string): boolean {
  if (slotToolId === actionToolId) {
    return true;
  }
  if (slotToolId.indexOf('luckin.') === 0 && actionToolId.indexOf('luckin.') === 0) {
    return true;
  }
  if (slotToolId.indexOf('ride.') === 0 && actionToolId.indexOf('ride.') === 0) {
    return true;
  }
  if (slotToolId.indexOf('payment.') === 0 && actionToolId.indexOf('payment.') === 0) {
    return true;
  }
  return false;
}

export function isMultiTaskSurface(surface: A2uiSurfaceState): boolean {
  return surface.intent === 'multi-task';
}

export function childSurfaceIdForMultiTaskSlot(compositeSurfaceId: string, slotId: string): string {
  return compositeSurfaceId + '_' + slotId;
}

export function resolveMultiTaskSlotId(surface: A2uiSurfaceState, toolId: string): string {
  try {
    const parsed = JSON.parse(surface.dataModelJson) as Record<string, Object | null | undefined>;
    const sectionsValue = parsed.sections;
    if (sectionsValue !== undefined && sectionsValue !== null && typeof sectionsValue === 'object' && !Array.isArray(sectionsValue)) {
      const sections = sectionsValue as Record<string, MultiToolSectionValue>;
      const keys = Object.keys(sections);
      for (let index = 0; index < keys.length; index++) {
        const slotId = keys[index];
        const section = sections[slotId];
        if (section !== undefined && toolIdMatchesSlot(section.toolId, toolId)) {
          return slotId;
        }
      }
    }
    const boardValue = parsed.multiTask;
    if (boardValue !== undefined && boardValue !== null && typeof boardValue === 'object' && !Array.isArray(boardValue)) {
      const board = boardValue as MultiTaskBoardData;
      for (let index = 0; index < board.sections.length; index++) {
        const meta = board.sections[index];
        if (toolIdMatchesSlot(meta.toolId, toolId)) {
          return meta.slotId;
        }
      }
    }
  } catch (_error) {
  }
  return '';
}

export function mergeSlotObservationIntoMultiTaskSurface(
  composite: A2uiSurfaceState,
  slotId: string,
  toolId: string,
  observationRaw: string,
  activateSlot: boolean = true
): A2uiSurfaceState {
  const content = ingestToolObservation(slotId, toolId, observationRaw);
  let parsed: Record<string, Object | null | undefined> = {};
  try {
    parsed = JSON.parse(composite.dataModelJson) as Record<string, Object | null | undefined>;
  } catch (_error) {
    parsed = {};
  }
  parsed = mergeSectionIntoDataModel(parsed, slotId, content, activateSlot);

  return {
    surfaceId: composite.surfaceId,
    rootId: composite.rootId.length > 0 ? composite.rootId : 'root',
    title: composite.title.length > 0 ? composite.title : '并行任务',
    intent: 'multi-task',
    status: composite.status,
    components: composite.components,
    dataModelJson: JSON.stringify(parsed),
    error: composite.error,
    sequence: composite.sequence + 1
  };
}
