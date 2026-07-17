import { describe, it, expect } from '@ohos/hypium';
import { parseSkillMarkdown } from '@loop/agent-core';

export default function skillMarkdownParserTest() {
  describe('skillMarkdownParser', () => {
    it('parses frontmatter and body', 0, () => {
      const skill = parseSkillMarkdown(
        '---\nname: weather\ndescription: Read real weather\nhomepage: https://example.test\n---\nUse the real provider.',
        '/skills/weather/SKILL.md'
      );

      expect(skill.name).assertEqual('weather');
      expect(skill.description).assertEqual('Read real weather');
      expect(skill.homepage).assertEqual('https://example.test');
      expect(skill.location).assertEqual('/skills/weather/SKILL.md');
      expect(skill.instructions()).assertEqual('Use the real provider.');
    });

    it('rejects a file without frontmatter', 0, () => {
      let message = '';
      try {
        parseSkillMarkdown('# Weather', '/skills/weather/SKILL.md');
      } catch (error) {
        message = error instanceof Error ? error.message : `${error}`;
      }

      expect(message).assertEqual('Skill file must start with YAML frontmatter (---).');
    });
  });
}
