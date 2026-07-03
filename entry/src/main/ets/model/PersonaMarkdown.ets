export interface PersonaMarkdownDocument {
  frontmatter: Record<string, string>;
  body: string;
  sections: PersonaMarkdownSection[];
}

export interface PersonaMarkdownSection {
  title: string;
  body: string;
}

export interface PersonaSkillMarkdown {
  id: string;
  name: string;
  description: string;
  tools: string[];
  status: string;
  body: string;
  sections: PersonaMarkdownSection[];
}

function splitLines(text: string): string[] {
  return text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
}

function parseFrontmatter(lines: string[]): Record<string, string> {
  const values: Record<string, string> = {};
  let activeKey = '';
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index];
    if (line.trim().length === 0) {
      continue;
    }
    if (line.indexOf('  - ') === 0 && activeKey.length > 0) {
      const previous = values[activeKey] === undefined ? '' : values[activeKey];
      const next = line.substring(4).trim();
      values[activeKey] = previous.length > 0 ? previous + ',' + next : next;
      continue;
    }
    const colon = line.indexOf(':');
    if (colon <= 0) {
      continue;
    }
    activeKey = line.substring(0, colon).trim();
    values[activeKey] = line.substring(colon + 1).trim();
  }
  return values;
}

function parseSections(body: string): PersonaMarkdownSection[] {
  const sections: PersonaMarkdownSection[] = [];
  const lines = splitLines(body);
  let currentTitle = '';
  let currentBody: string[] = [];
  const flush = (): void => {
    if (currentTitle.length === 0) {
      return;
    }
    sections.push({ title: currentTitle, body: currentBody.join('\n').trim() });
  };
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index];
    if (line.indexOf('## ') === 0) {
      flush();
      currentTitle = line.substring(3).trim();
      currentBody = [];
    } else if (currentTitle.length > 0) {
      currentBody.push(line);
    }
  }
  flush();
  return sections;
}

export function parsePersonaMarkdown(text: string): PersonaMarkdownDocument {
  const lines = splitLines(text);
  if (lines.length > 2 && lines[0].trim() === '---') {
    let end = -1;
    for (let index = 1; index < lines.length; index++) {
      if (lines[index].trim() === '---') {
        end = index;
        break;
      }
    }
    if (end > 0) {
      const body = lines.slice(end + 1).join('\n').trim();
      return {
        frontmatter: parseFrontmatter(lines.slice(1, end)),
        body: body,
        sections: parseSections(body)
      };
    }
  }
  const body = text.trim();
  return { frontmatter: {}, body: body, sections: parseSections(body) };
}

export function markdownSectionValue(sections: PersonaMarkdownSection[], title: string): string {
  for (let index = 0; index < sections.length; index++) {
    if (sections[index].title === title) {
      return sections[index].body;
    }
  }
  return '';
}

export function parsePersonaSkillMarkdown(id: string, text: string): PersonaSkillMarkdown {
  const parsed = parsePersonaMarkdown(text);
  const name = parsed.frontmatter['name'] === undefined ? '' : parsed.frontmatter['name'];
  const description = parsed.frontmatter['description'] === undefined ? '' : parsed.frontmatter['description'];
  const tools = parsed.frontmatter['tools'] === undefined ? '' : parsed.frontmatter['tools'];
  const status = parsed.frontmatter['status'] === undefined ? '' : parsed.frontmatter['status'];
  const toolList = tools.trim() === '[]' ? '' : tools;
  return {
    id: id,
    name: name.length > 0 ? name : id,
    description: description,
    tools: toolList.length > 0 ? toolList.split(',').map((item: string): string => item.trim()).filter((item: string): boolean => item.length > 0 && item !== '[]') : [],
    status: status.length > 0 ? status : 'active',
    body: parsed.body,
    sections: parsed.sections
  };
}
