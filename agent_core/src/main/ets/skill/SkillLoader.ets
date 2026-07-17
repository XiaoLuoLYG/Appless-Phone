import { common } from '@kit.AbilityKit';
import { AgentSkill } from './AgentSkill';
import { skillLogInfo, skillLogWarn } from './SkillLog';
import { loadSandboxSkills } from './SkillStore';

/** Ensures bundled skills exist in sandbox, then loads skills from the sandbox only. */
export async function loadSkillsFromContext(context: common.UIAbilityContext): Promise<AgentSkill[]> {
  try {
    const skills = await loadSandboxSkills(context);
    skillLogInfo(`SkillLoader: ready skillCount=${skills.length}`);
    return skills;
  } catch (error) {
    const message = error instanceof Error ? error.message : `${error}`;
    skillLogWarn(`SkillLoader: failed to load sandbox skills; ${message}`);
    return [];
  }
}
