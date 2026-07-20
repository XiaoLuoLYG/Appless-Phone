import { AgentSkill } from './AgentSkill';

export function buildSkillCatalog(skills: AgentSkill[]): string {
  if (skills.length === 0) {
    return '';
  }

  let catalog = '<available_skills>\n';
  for (const skill of skills) {
    catalog += `  <skill name="${escapeXml(skill.name)}" location="${escapeXml(skill.location)}">\n`;
    catalog += `    ${escapeXml(skill.description)}\n`;
    catalog += '  </skill>\n';
  }
  catalog += '</available_skills>';
  return catalog;
}

function escapeXml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
