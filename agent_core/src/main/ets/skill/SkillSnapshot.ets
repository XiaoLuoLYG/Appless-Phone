import { common } from '@kit.AbilityKit';
import { AgentSkill } from './AgentSkill';
import { buildSkillCatalog } from './SkillCatalog';
import { loadSkillsFromContext } from './SkillLoader';

export class SkillSnapshot {
  readonly eligible: AgentSkill[];
  readonly catalogText: string;

  constructor(eligible: AgentSkill[], catalogText: string) {
    this.eligible = eligible;
    this.catalogText = catalogText;
  }

  findByName(name: string): AgentSkill | null {
    const trimmed = name.trim();
    for (const skill of this.eligible) {
      if (skill.name === trimmed) {
        return skill;
      }
    }
    return null;
  }

  isEmpty(): boolean {
    return this.eligible.length === 0;
  }
}

export async function createSkillSnapshot(context: common.UIAbilityContext): Promise<SkillSnapshot> {
  const skills = await loadSkillsFromContext(context);
  return new SkillSnapshot(skills, buildSkillCatalog(skills));
}

export function buildSkillsSection(snapshot: SkillSnapshot | null): string {
  if (snapshot === null || snapshot.isEmpty()) {
    return '';
  }

  let section = '## Skills\n';
  section += 'Before replying: scan <available_skills> descriptions in this message.\n';
  section += '- If exactly one skill clearly applies: Action: read[skill_name], then follow the loaded instructions.\n';
  section += '- If multiple could apply: choose the most specific one, then read it.\n';
  section += '- If none clearly apply: do not read any skill; use other tools or Final.\n';
  section += '- Read at most one skill up front per task.\n\n';
  section += 'If the user explicitly asks to create, save, update, or persist a skill: read skill_creator first, ';
  section += 'then follow it to call write_sandbox_file for skills/{skill_name}/SKILL.md with the complete markdown.\n\n';
  section += snapshot.catalogText;
  return section;
}

export function buildLoopSystemPrompt(snapshot: SkillSnapshot | null): string {
  let content = 'You are Loop, a concise ReAct agent on HarmonyOS.';
  content += buildReActFormatRules();
  content += ' Use the ui tool when the user asks to show, display, or visualize something on screen.';

  const skillsSection = buildSkillsSection(snapshot);
  if (skillsSection.length > 0) {
    content += '\n\n';
    content += skillsSection;
  }

  return content;
}

export function buildReActFormatRules(): string {
  return ' Every reply MUST include Thought: on its own line, then exactly one of:\n'
    + '- Action: tool_name[input]  (e.g. Action: time[], Action: read[weather])\n'
    + '- Final: answer\n'
    + 'Do not use markdown bold, bullets, or code blocks on Action/Final lines. '
    + 'Use only listed tools.';
}
