import { describe, it, expect } from '@ohos/hypium';
import {
  applyPersonaEditableSnapshots,
  configureDefaultPersonaStoreForTests,
  configurePersonaStoreFromRaw,
  personaEditableSnapshots,
  personaManifestIds,
  personaPackForId,
  personaPromptSectionLimit,
  resetPersonaPackText,
  updatePersonaPackText
} from '../main/ets/model/PersonaStore';

export default function personaStoreTest() {
  describe('personaStore', () => {
    it('loads the default persona packs', 0, () => {
      configureDefaultPersonaStoreForTests();
      const ids = personaManifestIds();

      expect(ids.indexOf('default_companion')).assertLarger(-1);
      expect(ids.indexOf('food_companion')).assertLarger(-1);
      expect(ids.indexOf('travel_companion')).assertLarger(-1);
    });

    it('returns food pack with independent soul skills and memory', 0, () => {
      configureDefaultPersonaStoreForTests();
      const pack = personaPackForId('food_companion');

      expect(pack.manifest.id).assertEqual('food_companion');
      expect(pack.manifest.name).assertEqual('饮食搭子');
      expect(pack.soul.indexOf('饮食')).assertLarger(-1);
      expect(pack.skills.indexOf('food.search')).assertLarger(-1);
      expect(pack.memory.indexOf('暂无固定品牌')).assertLarger(-1);
    });

    it('loads active skill and placeholder skill metadata', 0, () => {
      configureDefaultPersonaStoreForTests();
      const pack = personaPackForId('food_companion');

      expect(pack.activeSkill.id).assertEqual('food-search');
      expect(pack.activeSkill.tools.indexOf('food.search')).assertLarger(-1);
      expect(pack.skills.indexOf('Food Search')).assertLarger(-1);
      expect(pack.skillList.length).assertLarger(1);
      expect(pack.skillList[1].status).assertEqual('placeholder');
    });

    it('falls back to default persona when requested pack is missing', 0, () => {
      configureDefaultPersonaStoreForTests();
      const pack = personaPackForId('missing_persona');

      expect(pack.manifest.id).assertEqual('default_companion');
      expect(pack.manifest.name).assertEqual('默认分身');
    });

    it('truncates long markdown sections', 0, () => {
      const longText = new Array(4000).fill('x').join('');
      configurePersonaStoreFromRaw(
        '[{"id":"default_companion","name":"默认分身","avatarKey":"default","domains":["general"],"defaultTools":[]}]',
        {
          'default_companion/soul.md': longText,
          'default_companion/skills.md': longText,
          'default_companion/memory.md': longText
        }
      );

      const pack = personaPackForId('default_companion');
      expect(pack.soul.length).assertEqual(personaPromptSectionLimit());
      expect(pack.skills.length).assertEqual(personaPromptSectionLimit());
      expect(pack.memory.length).assertEqual(personaPromptSectionLimit());
    });

    it('updates editable soul and memory without changing skills', 0, () => {
      configureDefaultPersonaStoreForTests();
      const before = personaPackForId('food_companion');

      updatePersonaPackText('food_companion', '新的饮食 soul', '用户咖啡偏好：只喝瑞幸咖啡。');
      const after = personaPackForId('food_companion');

      expect(after.soul).assertEqual('新的饮食 soul');
      expect(after.memory).assertEqual('用户咖啡偏好：只喝瑞幸咖啡。');
      expect(after.skills).assertEqual(before.skills);
      expect(personaEditableSnapshots()[0].id.length).assertLarger(0);

      resetPersonaPackText('food_companion');
      expect(personaPackForId('food_companion').soul).assertEqual(before.soul);
    });

    it('does not apply editable snapshots that belong to another persona', 0, () => {
      configureDefaultPersonaStoreForTests();
      const food = personaPackForId('food_companion');
      const travelBefore = personaPackForId('travel_companion');

      applyPersonaEditableSnapshots([
        { id: 'travel_companion', soul: food.soul, memory: food.memory }
      ]);

      expect(personaPackForId('travel_companion').soul).assertEqual(travelBefore.soul);
      expect(personaPackForId('travel_companion').memory).assertEqual(travelBefore.memory);

      applyPersonaEditableSnapshots([
        { id: 'travel_companion', soul: '自定义旅行 soul', memory: '常用出发地：深圳。' }
      ]);

      expect(personaPackForId('travel_companion').soul).assertEqual('自定义旅行 soul');
      expect(personaPackForId('travel_companion').memory).assertEqual('常用出发地：深圳。');
    });
  });
}
