import { A2uiSurfaceState } from '../aiphone/runtime/A2uiTypes';
import { summarizeAppliedA2uiSurface } from './A2uiObservationDigest';
import { mergeSectionIntoDataModel, readySectionCount } from './MultiTaskDataModel';
import { ingestToolObservation, serialStepCompletionReply } from './MultiToolSectionAdapters';
import { MultiTaskBoardData, MultiToolSectionContent, MultiToolSectionValue } from './MultiToolTypes';
import { MultiToolSurfaceComposer } from './MultiToolSurfaceComposer';

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
  const board = parsed.multiTask as MultiTaskBoardData | undefined;
  const status = board !== undefined &&
    readySectionCount(board) === board.sections.length ? 'ready' : 'calling_tool';

  return {
    surfaceId: composite.surfaceId,
    rootId: composite.rootId.length > 0 ? composite.rootId : 'root',
    title: composite.title.length > 0 ? composite.title : '并行任务',
    intent: 'multi-task',
    status,
    components: composite.components,
    dataModelJson: JSON.stringify(parsed),
    error: composite.error,
    sequence: composite.sequence + 1
  };
}

export function mergeSurfaceIntoMultiTaskSurface(
  composite: A2uiSurfaceState,
  slotId: string,
  toolId: string,
  surface: A2uiSurfaceState,
  activateSlot: boolean = false
): A2uiSurfaceState {
  const digest = summarizeAppliedA2uiSurface('', surface);
  const content: MultiToolSectionContent = {
    slotId,
    toolId,
    title: surface.title,
    status: surface.status === 'error' ? 'error' : 'ready',
    summary: digest.text.split('\n').slice(0, 3).join(' '),
    completionReply: '',
    observationDigest: digest.text,
    failureKey: digest.failureKey,
    embeddedSurface: surface
  };
  content.completionReply = serialStepCompletionReply(toolId, content);
  let parsed = JSON.parse(composite.dataModelJson) as Record<string, Object | null | undefined>;
  parsed = mergeSectionIntoDataModel(parsed, slotId, content, activateSlot);
  const board = parsed.multiTask as MultiTaskBoardData;
  return {
    surfaceId: composite.surfaceId,
    rootId: composite.rootId,
    title: composite.title,
    intent: composite.intent,
    status: readySectionCount(board) === board.sections.length ? 'ready' : 'calling_tool',
    components: composite.components,
    dataModelJson: JSON.stringify(parsed),
    error: composite.error,
    sequence: composite.sequence + 1
  };
}

export function appendMultiTaskSlot(
  composite: A2uiSurfaceState,
  toolId: string
): A2uiSurfaceState {
  const parsed = JSON.parse(composite.dataModelJson) as
    Record<string, Object | null | undefined>;
  const board = parsed.multiTask as MultiTaskBoardData;
  const sections = parsed.sections as Record<string, MultiToolSectionValue>;
  let slotIndex = board.sections.length;
  let slotId = 'slot_' + slotIndex.toString();
  while (sections[slotId] !== undefined) {
    slotIndex++;
    slotId = 'slot_' + slotIndex.toString();
  }
  if (board.mode !== 'serial') {
    board.sections.push({
      slotId,
      toolId,
      title: toolId,
      status: 'queued',
      summary: ''
    });
  }
  sections[slotId] = {
    slotId,
    toolId,
    title: toolId,
    status: 'queued',
    summary: '',
    observationDigest: '',
    failureKey: '',
    embeddedSurface: null
  };
  parsed.multiTask = board as Object;
  parsed.sections = sections as Object;
  const summary = parsed.summary as
    Record<string, Object | string | number | boolean | null | undefined>;
  summary.text = '串行任务进度 ' + readySectionCount(board).toString() + '/' +
    Object.keys(sections).length.toString();
  summary.count = readySectionCount(board);
  parsed.summary = summary as Object;
  return {
    surfaceId: composite.surfaceId,
    rootId: composite.rootId,
    title: composite.title,
    intent: composite.intent,
    status: 'calling_tool',
    components: composite.components,
    dataModelJson: JSON.stringify(parsed),
    error: composite.error,
    sequence: composite.sequence + 1
  };
}

export function wrapSurfaceWithMultiTaskAction(
  surface: A2uiSurfaceState,
  sourceToolId: string,
  actionId: string
): A2uiSurfaceState {
  let composite: A2uiSurfaceState = surface;
  const composer = new MultiToolSurfaceComposer(
    surface.surfaceId,
    (next: A2uiSurfaceState): void => {
      composite = next;
    }
  );
  composer.setExecutionMode('serial');
  composer.registerSlots([
    { name: sourceToolId, input: '' },
    { name: actionId, input: '' }
  ]);
  composer.emitShell();
  composer.ingestSurface('slot_0', surface);
  composer.markRunning('slot_1');
  return composite;
}
