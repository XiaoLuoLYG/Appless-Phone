import { describe, it, expect } from '@ohos/hypium';
import { LeaderPersonaMetadata } from '@loop/agent-core';
import {
  configureDefaultPersonaStoreForTests,
  configurePersonaStoreFromRaw,
  updatePersonaPackText
} from '../main/ets/model/PersonaStore';
import { preparePersonaPrompt } from '../main/ets/model/PersonaPrompt';
import { leaderPersonaContext } from '../main/ets/model/LeaderPersonaContext';

export default function personaPromptTest() {
  describe('personaPrompt', () => {
    it('injects food soul skills and memory before user task', 0, () => {
      configureDefaultPersonaStoreForTests();
      const prepared = preparePersonaPrompt('点一杯咖啡');

      expect(prepared.modelPrompt.indexOf('Persona: 饮食搭子')).assertLarger(-1);
      expect(prepared.modelPrompt.indexOf('food.search')).assertLarger(-1);
      expect(prepared.modelPrompt.indexOf('User task:\n点一杯咖啡')).assertLarger(-1);
      expect(prepared.userPrompt).assertEqual('点一杯咖啡');
      expect(prepared.runtime.id).assertEqual('food_companion');
      expect(prepared.memoryRuntime.preferences.length).assertEqual(0);
      expect(prepared.toolArgs === undefined).assertTrue();
    });

    it('keeps plain greeting on default persona', 0, () => {
      configureDefaultPersonaStoreForTests();
      const prepared = preparePersonaPrompt('你好');

      expect(prepared.runtime.id).assertEqual('default_companion');
      expect(prepared.userPrompt).assertEqual('你好');
    });

    it('turns Luckin-only memory into strict food args', 0, () => {
      configureDefaultPersonaStoreForTests();
      updatePersonaPackText('food_companion', '你是饮食搭子。', '用户咖啡偏好：只喝瑞幸咖啡。');
      const prepared = preparePersonaPrompt('点一杯咖啡');
      const args = prepared.toolArgs as Record<string, Object | string | boolean | undefined>;

      expect(prepared.memoryRuntime.preferences.indexOf('只喝瑞幸')).assertLarger(-1);
      expect(args.brandPreference as string).assertEqual('瑞幸');
      expect(args.brandStrict as boolean).assertTrue();
    });

    it('does not treat markdown evidence examples as food preferences', 0, () => {
      configureDefaultPersonaStoreForTests();
      updatePersonaPackText('food_companion', '你是饮食搭子。', [
        '# 饮食搭子 Memory',
        '',
        '## Stable Preferences',
        '- 咖啡品牌：暂无固定品牌。',
        '- 甜度：未记录。',
        '',
        '## Evidence',
        '- 用户说“我只喝瑞幸咖啡”后再更新偏好。'
      ].join('\n'));
      const prepared = preparePersonaPrompt('点一杯咖啡');

      expect(prepared.memoryRuntime.preferences.length).assertEqual(0);
      expect(prepared.toolArgs === undefined).assertTrue();
    });

    it('injects only the active persona skill body', 0, () => {
      configureDefaultPersonaStoreForTests();
      const prepared = preparePersonaPrompt('点一杯咖啡');

      expect(prepared.modelPrompt.indexOf('Active skill:')).assertLarger(-1);
      expect(prepared.modelPrompt.indexOf('# Food Search')).assertLarger(-1);
      expect(prepared.modelPrompt.indexOf('coffee-order')).assertLarger(-1);
      expect(prepared.modelPrompt.indexOf('Planned capability')).assertEqual(-1);
    });

    it('exposes every active skill candidate while keeping placeholders out', 0, () => {
      try {
        configurePersonaStoreFromRaw(
          '[{"id":"food_companion","name":"饮食搭子","avatarKey":"food",' +
            '"domains":["food"],"defaultTools":["food.search"]}]',
          {
            'food_companion/soul.md': '饮食搭子',
            'food_companion/memory.md': '## Stable Preferences\n- 半糖',
            'food_companion/skills.json': '{"activeSkillId":"food-search","skills":[' +
              '{"id":"food-search","path":"skills/food/SKILL.md","status":"active"},' +
              '{"id":"coffee-order","path":"skills/coffee/SKILL.md","status":"active"},' +
              '{"id":"planned","path":"skills/planned/SKILL.md","status":"placeholder"}]}',
            'food_companion/skills/food/SKILL.md': '---\nname: food-search\n' +
              'description: search\ntools:\n  - food.search\nstatus: active\n---\n# Food',
            'food_companion/skills/coffee/SKILL.md': '---\nname: coffee-order\n' +
              'description: order\ntools:\n  - luckin.order.preview\nstatus: active\n---\n# Coffee',
            'food_companion/skills/planned/SKILL.md': '---\nname: planned\n' +
              'description: later\ntools: []\nstatus: placeholder\n---\n# Planned'
          }
        );
        const catalog = leaderPersonaContext('food_companion');
        const food = catalog.filter((item: LeaderPersonaMetadata): boolean =>
          item.personaId === 'food_companion')[0];

        expect(food.previous).assertTrue();
        expect(food.activeSkills.length).assertEqual(2);
        expect(food.activeSkills.map((skill): string => skill.skillId).join(','))
          .assertEqual('food-search,coffee-order');
        expect(food.activeSkills[0].toolIds.join(',')).assertEqual('food.search');
        expect(food.activeSkills[1].toolIds.join(',')).assertEqual('luckin.order.preview');
        expect(food.activeSkills[0].status).assertEqual('active');
        expect(food.soul.length > 0).assertTrue();
        expect(food.memory.length > 0).assertTrue();
        expect(JSON.stringify(catalog).indexOf('placeholder')).assertEqual(-1);
      } finally {
        configureDefaultPersonaStoreForTests();
      }
    });
  });
}
