import { PersonaMemoryRuntimeData, PersonaRuntimeData } from './PersonaTypes';
import { personaPackForId } from './PersonaStore';
import { routePersonaForPrompt } from './PersonaRouter';

export interface PreparedPersonaPrompt {
  modelPrompt: string;
  userPrompt: string;
  runtime: PersonaRuntimeData;
  memoryRuntime: PersonaMemoryRuntimeData;
  toolArgs?: Object;
}

function memoryPreferences(memory: string): string[] {
  const values: string[] = [];
  if ((memory.indexOf('只喝瑞幸') >= 0 || memory.indexOf('只买瑞幸') >= 0 || memory.indexOf('只点瑞幸') >= 0) &&
    values.indexOf('只喝瑞幸') < 0) {
    values.push('只喝瑞幸');
  }
  if (memory.indexOf('半糖') >= 0) {
    values.push('半糖');
  }
  if (memory.indexOf('瑞幸') >= 0 && values.indexOf('只喝瑞幸') < 0) {
    values.push('瑞幸优先');
  }
  return values;
}

function memorySummary(preferences: string[]): string {
  if (preferences.indexOf('只喝瑞幸') >= 0) {
    return '根据你的偏好，只展示瑞幸相关真实结果。';
  }
  return preferences.length === 0 ? '' : '根据你的偏好，优先考虑' + preferences.join('、') + '。';
}

function memoryToolArgs(preferences: string[]): Object | undefined {
  const args: Record<string, string | boolean> = {};
  if (preferences.indexOf('只喝瑞幸') >= 0) {
    args.brandPreference = '瑞幸';
    args.brandStrict = true;
  }
  if (preferences.indexOf('瑞幸优先') >= 0) {
    args.brandPreference = '瑞幸';
  }
  if (preferences.indexOf('半糖') >= 0) {
    args.sweetness = '半糖';
  }
  return Object.keys(args).length > 0 ? args : undefined;
}

export function preparePersonaPrompt(prompt: string): PreparedPersonaPrompt {
  const route = routePersonaForPrompt(prompt);
  const pack = personaPackForId(route.personaId);
  const preferences = memoryPreferences(pack.memory);
  const runtime: PersonaRuntimeData = {
    id: pack.manifest.id,
    name: pack.manifest.name,
    avatarKey: pack.manifest.avatarKey,
    status: 'online',
    reason: route.reason
  };
  const memoryRuntime: PersonaMemoryRuntimeData = {
    summary: memorySummary(preferences),
    preferences: preferences
  };
  const modelPrompt = [
    'Persona: ' + pack.manifest.name,
    'Persona id: ' + pack.manifest.id,
    'Persona reason: ' + route.reason,
    'Soul:',
    pack.soul,
    'Skills:',
    pack.skills,
    'Memory:',
    pack.memory,
    'Tool args instruction:',
    'Call exactly one best-fit tool when a tool is needed. Preserve the original user task. For food.search, include brandPreference and sweetness JSON args when memory says 瑞幸 or 半糖. Include brandStrict=true when memory says 只喝瑞幸.',
    'User task:',
    prompt
  ].join('\n');
  return {
    modelPrompt: modelPrompt,
    userPrompt: prompt,
    runtime: runtime,
    memoryRuntime: memoryRuntime,
    toolArgs: memoryToolArgs(preferences)
  };
}
