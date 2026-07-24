import { A2UI_VERSION, A2UI_COMPONENT_MULTI_TASK_BOARD, A2UI_COMPONENT_SURFACE_ROOT } from '../aiphone/runtime/A2uiTypes';
import { aiLogInfo } from '../aiphone/runtime/AiphoneLogger';
import { A2uiSurfaceStore } from '../aiphone/runtime/A2uiSurfaceStore';
import {
  A2uiComponent,
  A2uiDataValue,
  A2uiEnvelope,
  A2uiSummaryData,
  A2uiSurfaceState
} from '../aiphone/runtime/A2uiTypes';
import { ingestToolObservation, serialStepCompletionReply } from './MultiToolSectionAdapters';
import {
  MultiTaskBoardData,
  MultiToolExecutionMode,
  MultiToolSectionContent,
  MultiToolSectionMeta,
  MultiToolSectionValue,
  MultiToolSlotCall,
  MultiToolSlotStatus
} from './MultiToolTypes';

export type MultiToolSurfaceEmitHandler = (surface: A2uiSurfaceState, raw: string) => void;

class MultiToolSlot {
  slotId: string;
  index: number;
  toolId: string;
  input: string;
  childSurfaceId: string;
  status: MultiToolSlotStatus;
  content: MultiToolSectionContent | null;

  constructor(slotId: string, index: number, toolId: string, input: string, childSurfaceId: string) {
    this.slotId = slotId;
    this.index = index;
    this.toolId = toolId;
    this.input = input;
    this.childSurfaceId = childSurfaceId;
    this.status = 'queued';
    this.content = null;
  }
}

function a2uiLine(envelope: A2uiEnvelope): string {
  const line: A2uiEnvelope = {
    version: A2UI_VERSION
  };
  if (envelope.createSurface !== undefined && envelope.createSurface !== null) {
    line.createSurface = envelope.createSurface;
  }
  if (envelope.updateComponents !== undefined && envelope.updateComponents !== null) {
    line.updateComponents = envelope.updateComponents;
  }
  if (envelope.updateDataModel !== undefined && envelope.updateDataModel !== null) {
    line.updateDataModel = envelope.updateDataModel;
  }
  if (envelope.deleteSurface !== undefined && envelope.deleteSurface !== null) {
    line.deleteSurface = envelope.deleteSurface;
  }
  return JSON.stringify(line) + '\n';
}

function sectionPath(slotId: string): string {
  return '/sections/' + slotId;
}

export class MultiToolSurfaceComposer {
  private batchId: string;
  private compositeSurfaceId: string;
  private store: A2uiSurfaceStore;
  private slots: MultiToolSlot[];
  private slotById: Record<string, MultiToolSlot>;
  private activeSectionId: string;
  private completionOrder: string[];
  private onEmit: MultiToolSurfaceEmitHandler;
  private generation: number;
  private emitGeneration: number;
  private executionMode: MultiToolExecutionMode;

  constructor(compositeSurfaceId: string, onEmit: MultiToolSurfaceEmitHandler) {
    this.batchId = 'batch_' + Date.now().toString();
    this.compositeSurfaceId = compositeSurfaceId;
    this.store = new A2uiSurfaceStore();
    this.slots = [];
    this.slotById = {};
    this.activeSectionId = '';
    this.completionOrder = [];
    this.onEmit = onEmit;
    this.generation = 0;
    this.emitGeneration = 0;
    this.executionMode = 'parallel';
  }

  setExecutionMode(mode: MultiToolExecutionMode): void {
    this.executionMode = mode;
  }

  childSurfaceId(slotId: string): string {
    for (let index = 0; index < this.slots.length; index++) {
      if (this.slots[index].slotId === slotId) {
        return this.slots[index].childSurfaceId;
      }
    }
    return this.compositeSurfaceId + '_' + slotId;
  }

  registerSlots(calls: MultiToolSlotCall[]): void {
    this.slots = [];
    this.slotById = {};
    for (let index = 0; index < calls.length; index++) {
      this.addSlot(calls[index]);
    }
    this.activeSectionId = '';
    this.completionOrder = [];
  }

  appendSlot(call: MultiToolSlotCall): string {
    const slotId = this.addSlot(call);
    this.emitComposite('slot');
    return slotId;
  }

  emitShell(): void {
    this.emitComposite('shell');
  }

  markRunning(slotId: string): void {
    this.updateSlotStatus(slotId, 'running');
  }

  ingestPartial(slotId: string, raw: string, _surface?: A2uiSurfaceState): void {
    if (raw.trim().length === 0) {
      return;
    }
    if (raw.indexOf('genericToolResults') < 0) {
      return;
    }
    this.applySlotContent(slotId, ingestToolObservation(slotId, this.toolIdForSlot(slotId), raw), 'running');
  }

  ingestSlotObservation(slotId: string, raw: string): void {
    if (raw.trim().length === 0) {
      this.markSlotError(slotId, '工具没有返回 observation。');
      return;
    }
    const content = ingestToolObservation(slotId, this.toolIdForSlot(slotId), raw);
    this.applySlotContent(slotId, content, content.status);
  }

  markSlotError(slotId: string, message: string): void {
    const content: MultiToolSectionContent = {
      slotId: slotId,
      toolId: this.toolIdForSlot(slotId),
      title: this.titleForSlot(slotId),
      status: 'error',
      summary: message,
      completionReply: '',
      observationDigest: 'ObservationDigest\nerror: ' + message,
      failureKey: 'slot:error',
      embeddedSurface: null
    };
    content.completionReply = serialStepCompletionReply(content.toolId, content);
    this.applySlotContent(slotId, content, 'error');
  }

  isBatchTerminal(): boolean {
    if (this.slots.length === 0) {
      return true;
    }
    for (let index = 0; index < this.slots.length; index++) {
      const status = this.slots[index].status;
      if (status === 'queued' || status === 'running') {
        return false;
      }
    }
    return true;
  }

  buildBatchObservationText(): string {
    const lines: string[] = [
      'ObservationDigest',
      'batchId: ' + this.batchId,
      'mode: ' + this.executionMode,
      'surface: multi-task composite'
    ];
    for (let index = 0; index < this.slots.length; index++) {
      const slot = this.slots[index];
      lines.push('section ' + slot.slotId + ': toolId=' + slot.toolId + ' status=' + slot.status);
      if (slot.content !== null) {
        lines.push(slot.content.observationDigest);
      }
    }
    return lines.join('\n');
  }

  buildFinalText(): string {
    let readyCount = 0;
    let errorCount = 0;
    for (let index = 0; index < this.slots.length; index++) {
      if (this.slots[index].status === 'ready') {
        readyCount++;
      } else if (this.slots[index].status === 'error') {
        errorCount++;
      }
    }
    if (this.executionMode === 'serial') {
      if (readyCount === 0 && errorCount > 0) {
        return '串行任务未完成，详情已更新到主页。';
      }
      if (errorCount > 0) {
        return '已完成 ' + readyCount.toString() + '/' + this.slots.length.toString() +
          ' 步串行任务，可在页内切换查看；' + errorCount.toString() + ' 步失败。';
      }
      return '串行任务已完成，可在页内切换查看各步骤结果。';
    }
    if (readyCount === 0 && errorCount > 0) {
      return '并行任务均失败，详情已更新到主页。';
    }
    if (errorCount > 0) {
      return '已完成 ' + readyCount.toString() + '/' + this.slots.length.toString() +
        ' 项任务，可在页内切换查看；' + errorCount.toString() + ' 项失败。';
    }
    return '并行任务已完成，可在页内切换查看各结果。';
  }

  batchFailureKey(): string {
    for (let index = 0; index < this.slots.length; index++) {
      const content = this.slots[index].content;
      if (content !== null && content.failureKey.length > 0) {
        return content.failureKey;
      }
    }
    return '';
  }

  cancel(): void {
    this.generation++;
  }

  private addSlot(call: MultiToolSlotCall): string {
    const index = this.slots.length;
    const slotId = 'slot_' + index.toString();
    const slot = new MultiToolSlot(
      slotId,
      index,
      call.name,
      call.input,
      this.compositeSurfaceId + '_' + slotId
    );
    this.slots.push(slot);
    this.slotById[slotId] = slot;
    return slotId;
  }

  private toolIdForSlot(slotId: string): string {
    const slot = this.slotById[slotId];
    return slot === undefined ? '' : slot.toolId;
  }

  private titleForSlot(slotId: string): string {
    const slot = this.slotById[slotId];
    if (slot === undefined) {
      return slotId;
    }
    if (slot.content !== null) {
      return slot.content.title;
    }
    return slot.toolId;
  }

  private updateSlotStatus(slotId: string, status: MultiToolSlotStatus): void {
    const slot = this.slotById[slotId];
    if (slot !== undefined) {
      slot.status = status;
    }
    this.emitComposite('status');
  }

  private applySlotContent(slotId: string, content: MultiToolSectionContent, status: MultiToolSlotStatus): void {
    const slot = this.slotById[slotId];
    if (slot !== undefined) {
      slot.content = content;
      slot.status = status;
    }
    this.noteSlotResult(slotId);
    this.emitComposite('section');
  }

  private slotByIdLookup(slotId: string): MultiToolSlot | null {
    const slot = this.slotById[slotId];
    return slot === undefined ? null : slot;
  }

  private slotHasDisplayableResult(slot: MultiToolSlot): boolean {
    if (slot.status === 'error') {
      return true;
    }
    if (slot.content === null) {
      return false;
    }
    return slot.content.embeddedSurface !== null;
  }

  private noteSlotResult(slotId: string): void {
    const slot = this.slotByIdLookup(slotId);
    if (slot === null) {
      return;
    }
    if (this.executionMode === 'serial') {
      if (slot.status !== 'ready' && slot.status !== 'error') {
        return;
      }
    } else if (!this.slotHasDisplayableResult(slot)) {
      return;
    }
    if (this.completionOrder.indexOf(slotId) >= 0) {
      this.syncActiveSectionFromCompletion();
      return;
    }
    this.completionOrder.push(slotId);
    this.syncActiveSectionFromCompletion();
  }

  private syncActiveSectionFromCompletion(): void {
    if (this.executionMode === 'serial') {
      if (this.completionOrder.length === 0) {
        this.activeSectionId = '';
        return;
      }
      this.activeSectionId = this.completionOrder[this.completionOrder.length - 1];
      return;
    }
    if (this.completionOrder.length === 0) {
      this.activeSectionId = '';
      return;
    }
    this.activeSectionId = this.completionOrder[0];
  }

  private orderedSlots(): MultiToolSlot[] {
    const ordered: MultiToolSlot[] = [];
    const seen: Record<string, boolean> = {};
    for (let index = 0; index < this.completionOrder.length; index++) {
      const slot = this.slotByIdLookup(this.completionOrder[index]);
      if (slot === null) {
        continue;
      }
      ordered.push(slot);
      seen[slot.slotId] = true;
    }
    for (let index = 0; index < this.slots.length; index++) {
      const slot = this.slots[index];
      if (seen[slot.slotId] !== true) {
        ordered.push(slot);
      }
    }
    return ordered;
  }

  private boardData(): MultiTaskBoardData {
    const sections: MultiToolSectionMeta[] = [];
    const ordered = this.orderedSlots();
    for (let index = 0; index < ordered.length; index++) {
      const slot = ordered[index];
      sections.push({
        slotId: slot.slotId,
        toolId: slot.toolId,
        title: slot.content !== null ? slot.content.title : slot.toolId,
        status: slot.status,
        summary: slot.content !== null ? slot.content.summary : '',
        completionReply: slot.content !== null ? slot.content.completionReply : ''
      });
    }
    return {
      batchId: this.batchId,
      mode: this.executionMode,
      activeSectionId: this.activeSectionId,
      sections: sections
    };
  }

  private sectionValues(): Record<string, MultiToolSectionValue> {
    const values: Record<string, MultiToolSectionValue> = {};
    for (let index = 0; index < this.slots.length; index++) {
      const slot = this.slots[index];
      const content = slot.content;
      values[slot.slotId] = {
        slotId: slot.slotId,
        toolId: slot.toolId,
        title: content !== null ? content.title : slot.toolId,
        status: slot.status,
        summary: content !== null ? content.summary : '',
        observationDigest: content !== null ? content.observationDigest : '',
        failureKey: content !== null ? content.failureKey : '',
        embeddedSurface: content !== null ? content.embeddedSurface : null
      };
    }
    return values;
  }

  private batchTitle(): string {
    return this.executionMode === 'serial' ? '串行任务' : '并行任务';
  }

  private batchBody(): string {
    return this.executionMode === 'serial' ? '按顺序查看各步骤结果' : '页内切换查看各工具结果';
  }

  private summaryData(): A2uiSummaryData {
    let readyCount = 0;
    for (let index = 0; index < this.slots.length; index++) {
      if (this.slots[index].status === 'ready' || this.slots[index].status === 'error') {
        readyCount++;
      }
    }
    const label = this.executionMode === 'serial' ? '串行任务进度 ' : '并行任务进度 ';
    return {
      text: label + readyCount.toString() + '/' + this.slots.length.toString(),
      toolName: 'multi.task.batch',
      dataLabel: 'multiTask',
      count: readyCount
    };
  }

  private compositeComponents(): A2uiComponent[] {
    const title = this.batchTitle();
    return [
      {
        id: 'root',
        component: A2UI_COMPONENT_SURFACE_ROOT,
        child: 'board',
        title: title,
        body: '多个工具结果',
        status: 'ready'
      },
      {
        id: 'board',
        component: A2UI_COMPONENT_MULTI_TASK_BOARD,
        title: title,
        body: this.batchBody(),
        status: 'ready',
        dataPath: '/multiTask'
      }
    ];
  }

  private buildEnvelopes(reason: string): A2uiEnvelope[] {
    const surface = this.store.getSurface();
    const envelopes: A2uiEnvelope[] = [];
    const includeSections = reason !== 'status';
    const needsShell = surface.surfaceId.length === 0 || reason === 'shell';
    if (needsShell || this.isBatchTerminal()) {
      envelopes.push({
        createSurface: {
          surfaceId: this.compositeSurfaceId,
          root: 'root',
          title: this.batchTitle(),
          intent: 'multi-task',
          status: this.isBatchTerminal() ? 'ready' : 'calling_tool',
          sendDataModel: true
        }
      });
    }
    if (needsShell) {
      envelopes.push({
        updateComponents: {
          surfaceId: this.compositeSurfaceId,
          components: this.compositeComponents()
        }
      });
    } else if (this.isBatchTerminal()) {
      envelopes.push({
        createSurface: {
          surfaceId: this.compositeSurfaceId,
          root: 'root',
          title: this.batchTitle(),
          intent: 'multi-task',
          status: 'ready',
          sendDataModel: false
        }
      });
    }
    envelopes.push({
      updateDataModel: {
        surfaceId: this.compositeSurfaceId,
        path: '/multiTask',
        value: this.boardData() as A2uiDataValue
      }
    });
    if (includeSections) {
      envelopes.push({
        updateDataModel: {
          surfaceId: this.compositeSurfaceId,
          path: '/sections',
          value: this.sectionValues() as A2uiDataValue
        }
      });
    }
    envelopes.push({
      updateDataModel: {
        surfaceId: this.compositeSurfaceId,
        path: '/summary',
        value: this.summaryData() as A2uiDataValue
      }
    });
    return envelopes;
  }

  private emitComposite(reason: string): void {
    const token = this.generation;
    this.emitGeneration++;
    const envelopes = this.buildEnvelopes(reason);
    let raw = '';
    for (let index = 0; index < envelopes.length; index++) {
      const line = a2uiLine(envelopes[index]);
      raw += line;
      const applied = this.store.apply(envelopes[index]);
      if (!applied.ok) {
        break;
      }
    }
    if (token !== this.generation) {
      return;
    }
    const surface = this.store.getSurface();
    surface.sequence = this.emitGeneration;
    let hasMultiTask = false;
    let hasSections = false;
    let sectionCount = 0;
    try {
      const parsed = JSON.parse(surface.dataModelJson) as Record<string, Object | null | undefined>;
      hasMultiTask = parsed.multiTask !== undefined && parsed.multiTask !== null;
      hasSections = parsed.sections !== undefined && parsed.sections !== null;
      if (hasMultiTask) {
        const board = parsed.multiTask as Record<string, Object | null | undefined>;
        const sectionList = board.sections;
        if (Array.isArray(sectionList)) {
          sectionCount = sectionList.length;
        }
      }
    } catch (_error) {
    }
    aiLogInfo('[AIPhone][MultiTask] emit reason=' + reason +
      ' surfaceId=' + surface.surfaceId +
      ' slots=' + this.slots.length.toString() +
      ' terminal=' + (this.isBatchTerminal() ? 'true' : 'false') +
      ' activeSectionId=' + this.activeSectionId +
      ' completionOrder=' + this.completionOrder.join(',') +
      ' hasMultiTask=' + (hasMultiTask ? 'true' : 'false') +
      ' hasSections=' + (hasSections ? 'true' : 'false') +
      ' sectionCount=' + sectionCount.toString());
    this.onEmit(surface, raw);
  }
}
