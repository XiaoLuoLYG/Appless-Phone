import { AgentSkill } from './AgentSkill';

export function parseSkillMarkdown(text: string, location: string): AgentSkill {
  const trimmed = text.trim();
  if (!trimmed.startsWith('---')) {
    throw new Error('Skill file must start with YAML frontmatter (---).');
  }

  const end = trimmed.indexOf('---', 3);
  if (end === -1) {
    throw new Error('Skill file frontmatter is not closed with ---.');
  }

  const frontmatter = trimmed.substring(3, end).trim();
  const body = trimmed.substring(end + 3).trim();
  const fields = parseFrontmatter(frontmatter);

  const name = fields.get('name') ?? '';
  const description = fields.get('description') ?? '';
  if (name.length === 0) {
    throw new Error('Skill frontmatter must include name.');
  }

  return new AgentSkill(
    name,
    description,
    fields.get('homepage') ?? '',
    fields.get('metadata') ?? '',
    location,
    body
  );
}

function parseFrontmatter(frontmatter: string): Map<string, string> {
  const fields: Map<string, string> = new Map();
  const lines = frontmatter.split(/\r?\n/);

  for (const line of lines) {
    const colon = line.indexOf(':');
    if (colon <= 0) {
      continue;
    }
    const key = line.substring(0, colon).trim();
    const value = line.substring(colon + 1).trim();
    fields.set(key, value);
  }

  return fields;
}
