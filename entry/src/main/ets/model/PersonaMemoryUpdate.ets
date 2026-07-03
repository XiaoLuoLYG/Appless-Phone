import {
  A2uiAction,
  A2uiComponent,
  A2uiLabelValueData,
  A2uiPersonaData,
  A2uiPersonaMemoryData,
  A2uiSurfaceState
} from '@loop/agent-core';
import { markdownSectionValue, parsePersonaMarkdown } from './PersonaMarkdown';
import { personaManifestIds, personaPackForId } from './PersonaStore';

type RawValue = Object | string | number | boolean | null | undefined;
type RawRecord = Record<string, RawValue>;

export interface PersonaMemorySuggestedAction {
  label: string;
  prompt: string;
  toolId: string;
}

export interface PersonaMemoryUpdateRequest {
  personaId: string;
  summary: string;
  memoryText: string;
  reason: string;
  suggestedAction?: PersonaMemorySuggestedAction;
}

function textOf(value: RawValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value.trim();
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function objectOf(value: RawValue): RawRecord | null {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as RawRecord;
}

function isKnownPersonaId(personaId: string): boolean {
  return personaManifestIds().indexOf(personaId) >= 0;
}

function parseSuggestedAction(raw: RawRecord | null): PersonaMemorySuggestedAction | undefined {
  if (raw === null) {
    return undefined;
  }
  const label = textOf(raw.label);
  const prompt = textOf(raw.prompt);
  if (label.length === 0 || prompt.length === 0) {
    return undefined;
  }
  return {
    label: label,
    prompt: prompt,
    toolId: textOf(raw.toolId)
  };
}

export function parsePersonaMemoryUpdateInput(input: string, activePersonaId: string): PersonaMemoryUpdateRequest | null {
  try {
    const parsed = JSON.parse(input.length > 0 ? input : '{}') as RawRecord;
    const personaId = activePersonaId;
    const memoryText = textOf(parsed.memoryText);
    if (personaId.length === 0 || !isKnownPersonaId(personaId) || memoryText.length === 0) {
      return null;
    }
    const rawSummary = textOf(parsed.summary);
    const summary = rawSummary.length > 0 ? rawSummary : memoryText;
    return {
      personaId: personaId,
      summary: summary,
      memoryText: memoryText,
      reason: textOf(parsed.reason),
      suggestedAction: parseSuggestedAction(objectOf(parsed.suggestedAction))
    };
  } catch (_error) {
    return null;
  }
}

function rerunActions(update: PersonaMemoryUpdateRequest): A2uiAction[] {
  if (update.suggestedAction === undefined || update.suggestedAction.prompt.length === 0) {
    return [];
  }
  return [{
    id: 'persona_memory_rerun',
    label: update.suggestedAction.label,
    prompt: update.suggestedAction.prompt,
    variant: 'primary',
    kind: 'prompt'
  }];
}

function editActions(update: PersonaMemoryUpdateRequest): A2uiAction[] {
  return [
    {
      id: 'persona_memory_edit',
      label: '编辑 memory',
      prompt: update.personaId,
      variant: 'secondary',
      kind: 'client'
    },
    {
      id: 'persona_soul_edit',
      label: '编辑 soul',
      prompt: update.personaId,
      variant: 'secondary',
      kind: 'client'
    }
  ];
}

function cardActions(update: PersonaMemoryUpdateRequest): A2uiAction[] {
  return rerunActions(update).concat(editActions(update));
}

function clipped(text: string): string {
  const value = text.trim();
  return value.length <= 240 ? value : value.substring(0, 240) + '...';
}

function markdownSummary(text: string, sectionTitle: string): string {
  const parsed = parsePersonaMarkdown(text);
  const section = markdownSectionValue(parsed.sections, sectionTitle).trim();
  return clipped(section.length > 0 ? section : parsed.body);
}

export function memoryUpdateSurface(surfaceId: string, update: PersonaMemoryUpdateRequest): A2uiSurfaceState {
  const pack = personaPackForId(update.personaId);
  const rows: A2uiLabelValueData[] = [
    { label: '已记录', value: update.summary },
    { label: '原因', value: update.reason.length > 0 ? update.reason : '用户更新了该分身的长期偏好。' },
    { label: 'Memory 摘要', value: markdownSummary(update.memoryText, 'Stable Preferences') },
    { label: 'Soul 摘要', value: markdownSummary(pack.soul, 'Identity') }
  ];
  const persona: A2uiPersonaData = {
    id: pack.manifest.id,
    name: pack.manifest.name,
    avatarKey: pack.manifest.avatarKey,
    status: 'online',
    reason: update.reason.length > 0 ? update.reason : '用户更新了该分身的长期偏好。'
  };
  const personaMemory: A2uiPersonaMemoryData = {
    summary: '已记录：' + update.summary,
    preferences: [update.summary]
  };
  const root: A2uiComponent = {
    id: 'root',
    component: 'SurfaceRoot',
    child: 'memory_update',
    title: pack.manifest.name + '已更新记忆',
    status: 'ready'
  };
  const card: A2uiComponent = {
    id: 'memory_update',
    component: 'InfoRows',
    title: pack.manifest.name + '已更新记忆',
    status: 'ready',
    dataPath: '/rows',
    actions: cardActions(update)
  };
  return {
    surfaceId: surfaceId,
    rootId: 'root',
    title: pack.manifest.name + '已更新记忆',
    intent: 'persona.memory.update',
    status: 'ready',
    components: [root, card],
    dataModelJson: JSON.stringify({
      rows: rows,
      persona: persona,
      personaMemory: personaMemory
    }),
    error: '',
    sequence: Date.now()
  };
}
