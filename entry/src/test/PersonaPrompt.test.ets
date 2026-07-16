import { describe, it, expect } from '@ohos/hypium';
import { configureDefaultPersonaStoreForTests, updatePersonaPackText } from '../main/ets/model/PersonaStore';
import { PersonaBinding, personaBindingForToolId, preparePersonaPrompt } from '../main/ets/model/PersonaPrompt';

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

    it('keeps every matching persona in a composite request', 0, () => {
      configureDefaultPersonaStoreForTests();
      const prepared = preparePersonaPrompt('查北京到上海的高铁，再看看上海虹桥站附近有什么吃的');

      expect(prepared.modelPrompt.indexOf('饮食搭子 (food_companion)')).assertLarger(-1);
      expect(prepared.modelPrompt.indexOf('旅行搭子 (travel_companion)')).assertLarger(-1);
      expect(prepared.modelPrompt.indexOf('Call every independent tool needed')).assertLarger(-1);
      expect(prepared.modelPrompt.indexOf('Call exactly one best-fit tool')).assertEqual(-1);
    });

    it('binds each composite tool surface to its own persona', 0, () => {
      configureDefaultPersonaStoreForTests();
      const prepared = preparePersonaPrompt('查北京到上海的高铁，再看看上海虹桥站附近有什么吃的');
      const fallback: PersonaBinding = {
        runtime: prepared.runtime,
        memoryRuntime: prepared.memoryRuntime,
        toolArgs: prepared.toolArgs
      };

      expect(personaBindingForToolId('train.search', fallback).runtime.id).assertEqual('travel_companion');
      expect(personaBindingForToolId('food.search', fallback).runtime.id).assertEqual('food_companion');
    });
  });
}
