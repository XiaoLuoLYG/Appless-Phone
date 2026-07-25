import { AgentTool } from '../agent/AgentTool';
import { AgentToolRunOptions } from '../agent/AgentToolRunOptions';
import { AgentSkill } from './AgentSkill';
import { skillLogInfo, skillLogWarn } from './SkillLog';
import { SkillSnapshot } from './SkillSnapshot';

/** Loads full SKILL.md instructions on demand (progressive disclosure). */
export class SkillReadTool implements AgentTool {
  private snapshot: SkillSnapshot;

  constructor(snapshot: SkillSnapshot) {
    this.snapshot = snapshot;
  }

  name(): string {
    return 'read';
  }

  description(): string {
    return 'Loads the full SKILL.md instructions for a skill. Input: skill name from ' +
      '<available_skills> (e.g. weather). Call once after choosing a skill, then follow ' +
      'the returned instructions.';
  }

  async run(input: string, _options?: AgentToolRunOptions): Promise<string> {
    const trimmed = input.trim();
    if (trimmed.length === 0) {
      skillLogWarn('SkillReadTool: read requested without a skill name');
      return `No skill name provided. Available: ${this.listNames()}`;
    }

    skillLogInfo(`SkillReadTool: read requested input=${trimmed}`);
    const skill = this.resolveSkill(trimmed);
    if (skill === null) {
      skillLogWarn(`SkillReadTool: unknown skill input=${trimmed} available=${this.listNames()}`);
      return `Unknown skill: ${trimmed}. Available: ${this.listNames()}`;
    }

    skillLogInfo(`SkillReadTool: returning skill name=${skill.name} location=${skill.location}`);
    return `# Skill: ${skill.name}\n\n${skill.instructions()}`;
  }

  private resolveSkill(input: string): AgentSkill | null {
    const byName = this.snapshot.findByName(input);
    if (byName !== null) {
      return byName;
    }

    for (const skill of this.snapshot.eligible) {
      if (skill.location === input || skill.location.endsWith(`/${input}`)) {
        return skill;
      }
    }
    return null;
  }

  private listNames(): string {
    const names: string[] = [];
    for (const skill of this.snapshot.eligible) {
      names.push(skill.name);
    }
    return names.join(', ');
  }
}
