import { describe, it, expect } from '@ohos/hypium';
import {
  markdownSectionValue,
  parsePersonaMarkdown,
  parsePersonaSkillMarkdown
} from '../main/ets/model/PersonaMarkdown';

export default function personaMarkdownTest() {
  describe('personaMarkdown', () => {
    it('parses frontmatter and second-level sections', 0, () => {
      const parsed = parsePersonaMarkdown([
        '---',
        'name: food-companion-soul',
        'description: Food persona rules',
        '---',
        '# Soul',
        '',
        '## Identity',
        '本地饮食搭子',
        '',
        '## Boundaries',
        '- 不伪造门店'
      ].join('\n'));

      expect(parsed.frontmatter['name']).assertEqual('food-companion-soul');
      expect(parsed.frontmatter['description']).assertEqual('Food persona rules');
      expect(markdownSectionValue(parsed.sections, 'Identity')).assertEqual('本地饮食搭子');
      expect(markdownSectionValue(parsed.sections, 'Boundaries')).assertEqual('- 不伪造门店');
    });

    it('parses skill metadata with tools list', 0, () => {
      const skill = parsePersonaSkillMarkdown('food-search', [
        '---',
        'name: food-search',
        'description: Search food with real providers.',
        'tools:',
        '  - food.search',
        '  - memory.update',
        'status: active',
        '---',
        '# Food Search',
        '## Checklist',
        '- Call one tool'
      ].join('\n'));

      expect(skill.id).assertEqual('food-search');
      expect(skill.name).assertEqual('food-search');
      expect(skill.description).assertEqual('Search food with real providers.');
      expect(skill.tools[0]).assertEqual('food.search');
      expect(skill.tools[1]).assertEqual('memory.update');
      expect(skill.status).assertEqual('active');
      expect(skill.body.indexOf('Call one tool')).assertLarger(-1);
    });
  });
}
