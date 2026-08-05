import {
  SuggestedActionCandidatePayload,
  SuggestedActionPreparationStatus
} from '../message/AgentMessage';

export type PreparedActionStatus = SuggestedActionPreparationStatus;

export interface PreparedActionDraftStep {
  stepId: string;
  toolId: string;
  args: Object;
}

export interface PreparedActionDraft {
  canImplement: boolean;
  reasonCode: string;
  label: string;
  steps: PreparedActionDraftStep[];
}

export interface SuggestedActionPreparer {
  prepare(goal: string): Promise<PreparedActionDraft>;
}

export interface PreparedActionStep {
  stepId: string;
  toolId: string;
  args: Object;
  bindings: Object[];
}

export interface PreparedActionRecord {
  schemaVersion: number;
  suggestedActionId: string;
  conversationId: string;
  turnId: string;
  taskId: string;
  goal: string;
  status: PreparedActionStatus;
  reasonCode: string;
  label: string;
  sources: Object[];
  steps: PreparedActionStep[];
}

function nonempty(value: string | undefined, maximum: number): boolean {
  return typeof value === 'string' && value.trim().length > 0 &&
    value === value.trim() && value.length <= maximum;
}

function cloneObject(value: Object): Object | null {
  try {
    const encoded: string = JSON.stringify(value);
    if (encoded.length === 0 || encoded.length > 32768) {
      return null;
    }
    const cloned: Object = JSON.parse(encoded) as Object;
    return cloned !== null && typeof cloned === 'object' && !Array.isArray(cloned) ? cloned : null;
  } catch (_error) {
    return null;
  }
}

function validSupportedDraft(draft: PreparedActionDraft): Object | null {
  if (draft === null || typeof draft !== 'object' || Array.isArray(draft) ||
    Object.keys(draft).sort().join(',') !== 'canImplement,label,reasonCode,steps' ||
    draft.canImplement !== true || draft.reasonCode !== '' ||
    !nonempty(draft.label, 80) || !Array.isArray(draft.steps) || draft.steps.length !== 1) {
    return null;
  }
  const step: PreparedActionDraftStep = draft.steps[0];
  if (step === null || typeof step !== 'object' || Array.isArray(step) ||
    Object.keys(step).sort().join(',') !== 'args,stepId,toolId' ||
    !nonempty(step.stepId, 80) || !nonempty(step.toolId, 128) ||
    step.args === null || typeof step.args !== 'object' || Array.isArray(step.args)) {
    return null;
  }
  return cloneObject(step.args);
}

function validUnsupportedDraft(draft: PreparedActionDraft): boolean {
  return draft !== null && typeof draft === 'object' && !Array.isArray(draft) &&
    Object.keys(draft).sort().join(',') === 'canImplement,label,reasonCode,steps' &&
    draft.canImplement === false && nonempty(draft.reasonCode, 80) &&
    draft.label === '' && Array.isArray(draft.steps) && draft.steps.length === 0;
}

export class PreparedActionRegistry {
  private readonly records: Map<string, PreparedActionRecord> =
    new Map<string, PreparedActionRecord>();

  begin(
    conversationId: string,
    turnId: string,
    taskId: string,
    candidate: SuggestedActionCandidatePayload
  ): boolean {
    if (!nonempty(conversationId, 160) || !nonempty(turnId, 160) ||
      !nonempty(taskId, 240) ||
      !nonempty(candidate.suggestedActionId, 240) || !nonempty(candidate.goal, 240) ||
      this.records.has(candidate.suggestedActionId)) {
      return false;
    }
    this.records.set(candidate.suggestedActionId, {
      schemaVersion: 2,
      suggestedActionId: candidate.suggestedActionId,
      conversationId,
      turnId,
      taskId,
      goal: candidate.goal,
      status: 'preparing',
      reasonCode: '',
      label: '',
      sources: [],
      steps: []
    });
    return true;
  }

  complete(suggestedActionId: string, draft: PreparedActionDraft): boolean {
    const record: PreparedActionRecord | undefined = this.records.get(suggestedActionId);
    if (record === undefined || record.status !== 'preparing') {
      return false;
    }
    if (validUnsupportedDraft(draft)) {
      record.status = 'unsupported';
      record.reasonCode = draft.reasonCode;
      return true;
    }
    const args: Object | null = validSupportedDraft(draft);
    if (args === null) {
      return false;
    }
    record.label = draft.label;
    record.reasonCode = '';
    record.steps = [{
      stepId: draft.steps[0].stepId,
      toolId: draft.steps[0].toolId,
      args,
      bindings: []
    }];
    record.status = 'ready';
    return true;
  }

  fail(suggestedActionId: string): boolean {
    const record: PreparedActionRecord | undefined = this.records.get(suggestedActionId);
    if (record === undefined || record.status !== 'preparing') {
      return false;
    }
    record.status = 'failed';
    return true;
  }

  inspect(suggestedActionId: string): PreparedActionRecord | null {
    const record: PreparedActionRecord | undefined = this.records.get(suggestedActionId);
    if (record === undefined) {
      return null;
    }
    const cloned: Object | null = cloneObject(record as Object);
    return cloned === null ? null : cloned as PreparedActionRecord;
  }

  removeTurn(conversationId: string, turnId: string): void {
    const ids: string[] = [];
    this.records.forEach((record: PreparedActionRecord, id: string) => {
      if (record.conversationId === conversationId && record.turnId === turnId) {
        ids.push(id);
      }
    });
    for (let index = 0; index < ids.length; index++) {
      this.records.delete(ids[index]);
    }
  }

  clear(): void {
    this.records.clear();
  }
}
