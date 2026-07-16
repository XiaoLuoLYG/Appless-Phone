import { toolDefinitionForToolId } from '@loop/agent-core';
import { PersonaMemoryRuntimeData, PersonaPack, PersonaRoute, PersonaRuntimeData } from './PersonaTypes';
import { markdownSectionValue, parsePersonaMarkdown, PersonaSkillMarkdown } from './PersonaMarkdown';
import { allPersonaPacks, personaPackForId } from './PersonaStore';
import { routePersonasForPrompt } from './PersonaRouter';

export interface PreparedPersonaPrompt {
  modelPrompt: string;
  userPrompt: string;
  runtime: PersonaRuntimeData;
  memoryRuntime: PersonaMemoryRuntimeData;
  toolArgs?: Object;
}

export interface PersonaBinding {
  runtime: PersonaRuntimeData;
  memoryRuntime: PersonaMemoryRuntimeData;
  toolArgs?: Object;
}

function preferenceMemoryText(memory: string): string {
  const parsed = parsePersonaMarkdown(memory);
  const stablePreferences = markdownSectionValue(parsed.sections, 'Stable Preferences').trim();
  return stablePreferences.length > 0 ? stablePreferences : parsed.body;
}

function memoryPreferences(memory: string): string[] {
  const preferenceText = preferenceMemoryText(memory);
  const values: string[] = [];
  if ((preferenceText.indexOf('只喝瑞幸') >= 0 || preferenceText.indexOf('只买瑞幸') >= 0 || preferenceText.indexOf('只点瑞幸') >= 0) &&
    values.indexOf('只喝瑞幸') < 0) {
    values.push('只喝瑞幸');
  }
  if (preferenceText.indexOf('半糖') >= 0) {
    values.push('半糖');
  }
  if (preferenceText.indexOf('瑞幸') >= 0 && values.indexOf('只喝瑞幸') < 0) {
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

function skillSummaries(pack: PersonaPack): string {
  const lines: string[] = [];
  pack.skillList.forEach((skill: PersonaSkillMarkdown) => {
    lines.push('- ' + skill.id + ' [' + skill.status + ']: ' + skill.description);
  });
  return lines.join('\n');
}

function bindingForPack(pack: PersonaPack, reason: string): PersonaBinding {
  const preferences = memoryPreferences(pack.memory);
  return {
    runtime: {
      id: pack.manifest.id,
      name: pack.manifest.name,
      avatarKey: pack.manifest.avatarKey,
      status: 'online',
      reason: reason
    },
    memoryRuntime: {
      summary: memorySummary(preferences),
      preferences: preferences
    },
    toolArgs: memoryToolArgs(preferences)
  };
}

export function personaBindingForToolId(toolId: string, fallback: PersonaBinding): PersonaBinding {
  const packs = allPersonaPacks();
  for (let index = 0; index < packs.length; index++) {
    if (packs[index].manifest.defaultTools.indexOf(toolId) >= 0) {
      return bindingForPack(packs[index], '工具 ' + toolId + ' 属于' + packs[index].manifest.name + '。');
    }
  }
  const definition = toolDefinitionForToolId(toolId);
  if (definition !== null) {
    for (let index = 0; index < packs.length; index++) {
      if (packs[index].manifest.domains.indexOf(definition.domain) >= 0) {
        return bindingForPack(packs[index], '工具 ' + toolId + ' 的领域为 ' + definition.domain + '。');
      }
    }
  }
  return fallback;
}

function relevantPersonaContext(routes: PersonaRoute[]): string {
  const sections: string[] = [];
  for (let index = 0; index < routes.length; index++) {
    const pack = personaPackForId(routes[index].personaId);
    sections.push([
      '- ' + pack.manifest.name + ' (' + pack.manifest.id + '): ' + routes[index].reason,
      '  Active skill: ' + pack.activeSkill.description,
      '  Memory: ' + preferenceMemoryText(pack.memory)
    ].join('\n'));
  }
  return sections.join('\n');
}

export function preparePersonaPrompt(prompt: string): PreparedPersonaPrompt {
  const routes = routePersonasForPrompt(prompt);
  const route = routes[0];
  const pack = personaPackForId(route.personaId);
  const binding = bindingForPack(pack, route.reason);
  const modelPrompt = [
    'Persona: ' + pack.manifest.name,
    'Persona id: ' + pack.manifest.id,
    'Persona reason: ' + route.reason,
    'Soul:',
    pack.soul,
    'Active skill:',
    pack.activeSkill.body,
    'Available persona skills:',
    skillSummaries(pack),
    'Memory:',
    pack.memory,
    'Relevant personas for this request:',
    relevantPersonaContext(routes),
    'Tool args instruction:',
    'Call every independent tool needed to satisfy the original user task. Multiple Action lines may be emitted together and will run in parallel. Keep each tool input scoped to that tool. For food.search, include brandPreference and sweetness JSON args when food memory says 瑞幸 or 半糖. Include brandStrict=true when food memory says 只喝瑞幸.',
    'Memory update instruction:',
    'When the user states a durable preference, identity fact, or stable constraint for the active persona, call memory.update with JSON { personaId, summary, memoryText, reason, suggestedAction }. Do not call search tools in the same turn. For the coffee preference example, suggestedAction should let the user rerun the previous coffee task, such as label=按新偏好重新查咖啡 and prompt=点一杯咖啡.',
    'User task:',
    prompt
  ].join('\n');
  return {
    modelPrompt: modelPrompt,
    userPrompt: prompt,
    runtime: binding.runtime,
    memoryRuntime: binding.memoryRuntime,
    toolArgs: binding.toolArgs
  };
}
