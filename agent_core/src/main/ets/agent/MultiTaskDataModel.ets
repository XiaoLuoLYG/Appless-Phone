import { MultiTaskBoardData, MultiToolSectionContent, MultiToolSectionValue } from './MultiToolTypes';

export function sectionValueFromContent(content: MultiToolSectionContent): MultiToolSectionValue {
  const value: MultiToolSectionValue = {
    slotId: content.slotId,
    toolId: content.toolId,
    title: content.title,
    status: content.status,
    summary: content.summary,
    observationDigest: content.observationDigest,
    failureKey: content.failureKey,
    embeddedSurface: content.embeddedSurface
  };
  return value;
}

export function readySectionCount(board: MultiTaskBoardData): number {
  let readyCount = 0;
  for (let index = 0; index < board.sections.length; index++) {
    const status = board.sections[index].status;
    if (status === 'ready' || status === 'error') {
      readyCount++;
    }
  }
  return readyCount;
}

export function mergeSectionIntoDataModel(
  parsed: Record<string, Object | null | undefined>,
  slotId: string,
  content: MultiToolSectionContent,
  activateSlot: boolean = true
): Record<string, Object | null | undefined> {
  const sectionValue = sectionValueFromContent(content);
  let sectionsValue = parsed.sections;
  let sections: Record<string, MultiToolSectionValue> = {};
  if (sectionsValue !== undefined && sectionsValue !== null &&
    typeof sectionsValue === 'object' && !Array.isArray(sectionsValue)) {
    sections = sectionsValue as Record<string, MultiToolSectionValue>;
  }
  sections[slotId] = sectionValue;
  parsed.sections = sections as Object;

  const boardValue = parsed.multiTask;
  if (boardValue !== undefined && boardValue !== null &&
    typeof boardValue === 'object' && !Array.isArray(boardValue)) {
    const board = boardValue as MultiTaskBoardData;
    for (let index = 0; index < board.sections.length; index++) {
      if (board.sections[index].slotId !== slotId) {
        continue;
      }
      board.sections[index].title = content.title;
      board.sections[index].status = content.status;
      board.sections[index].summary = content.summary;
      break;
    }
    if (activateSlot) {
      board.activeSectionId = slotId;
    }
    parsed.multiTask = board as Object;
  }

  const summaryValue = parsed.summary;
  const boardAfter = parsed.multiTask;
  if (boardAfter !== undefined && boardAfter !== null &&
    typeof boardAfter === 'object' && !Array.isArray(boardAfter) &&
    summaryValue !== undefined && summaryValue !== null &&
    typeof summaryValue === 'object' && !Array.isArray(summaryValue)) {
    const board = boardAfter as MultiTaskBoardData;
    const summary = summaryValue as Record<string, Object | string | number | boolean | null | undefined>;
    const readyCount = readySectionCount(board);
    const progressLabel = board.mode === 'serial' ? '串行任务进度 ' : '并行任务进度 ';
    summary.text = progressLabel + readyCount.toString() + '/' + board.sections.length.toString();
    summary.count = readyCount;
    parsed.summary = summary as Object;
  }

  return parsed;
}
