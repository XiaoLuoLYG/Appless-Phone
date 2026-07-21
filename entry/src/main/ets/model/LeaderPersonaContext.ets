import { LeaderPersonaMetadata, LeaderSkillMetadata } from '@loop/agent-core';
import { PersonaSkillMarkdown } from './PersonaMarkdown';
import { PersonaPack } from './PersonaTypes';
import { allPersonaPacks } from './PersonaStore';

export function leaderPersonaContext(previousPersonaId: string): LeaderPersonaMetadata[] {
  return allPersonaPacks().map((pack: PersonaPack): LeaderPersonaMetadata => {
    const active = pack.skillList.filter((skill: PersonaSkillMarkdown): boolean =>
      skill.status === 'active').slice(0, 1);
    return {
      personaId: pack.manifest.id,
      name: pack.manifest.name,
      soul: pack.soul,
      memory: pack.memory,
      previous: pack.manifest.id === previousPersonaId,
      activeSkills: active.map((skill: PersonaSkillMarkdown): LeaderSkillMetadata => ({
        skillId: skill.id,
        description: skill.description,
        instructions: skill.body,
        status: skill.status
      }))
    };
  });
}
