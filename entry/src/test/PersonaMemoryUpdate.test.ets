import { describe, it, expect } from '@ohos/hypium';
import { actionsOf, labelValues } from '@loop/agent-core';
import { configureDefaultPersonaStoreForTests } from '../main/ets/model/PersonaStore';
import {
  memoryUpdateSurface,
  parsePersonaMemoryUpdateInput,
  PersonaMemorySuggestedAction,
  PersonaMemoryUpdateRequest
} from '../main/ets/model/PersonaMemoryUpdate';

export default function personaMemoryUpdateTest() {
  describe('personaMemoryUpdate', () => {
    it('parses a valid memory.update input for the active persona', 0, () => {
      configureDefaultPersonaStoreForTests();
      const update = parsePersonaMemoryUpdateInput('{"personaId":"food_companion","summary":"只喝瑞幸咖啡","memoryText":"用户咖啡偏好：只喝瑞幸咖啡。","reason":"用户明确表达长期饮品偏好","suggestedAction":{"label":"按新偏好重新查咖啡","prompt":"点一杯咖啡","toolId":"food.search"}}', 'food_companion');

      expect(update === null).assertFalse();
      const parsed = update as PersonaMemoryUpdateRequest;
      expect(parsed.personaId).assertEqual('food_companion');
      expect(parsed.summary).assertEqual('只喝瑞幸咖啡');
      expect(parsed.memoryText).assertEqual('用户咖啡偏好：只喝瑞幸咖啡。');
      expect(parsed.suggestedAction === undefined).assertFalse();
      expect((parsed.suggestedAction as PersonaMemorySuggestedAction).label).assertEqual('按新偏好重新查咖啡');
    });

    it('defaults an empty personaId to the active persona', 0, () => {
      configureDefaultPersonaStoreForTests();
      const update = parsePersonaMemoryUpdateInput(JSON.stringify({
        summary: '只喝瑞幸咖啡',
        memoryText: '用户咖啡偏好：只喝瑞幸咖啡。'
      }), 'food_companion');

      expect(update === null).assertFalse();
      expect((update as PersonaMemoryUpdateRequest).personaId).assertEqual('food_companion');
    });

    it('uses the active persona when model-supplied personaId differs', 0, () => {
      configureDefaultPersonaStoreForTests();
      const update = parsePersonaMemoryUpdateInput(JSON.stringify({
        personaId: 'shopping_companion',
        summary: '只坐高铁二等座',
        memoryText: '用户出行偏好：只坐高铁二等座。'
      }), 'travel_companion');

      expect(update === null).assertFalse();
      expect((update as PersonaMemoryUpdateRequest).personaId).assertEqual('travel_companion');
    });

    it('rejects unknown active personas and empty memory text', 0, () => {
      configureDefaultPersonaStoreForTests();
      expect(parsePersonaMemoryUpdateInput(JSON.stringify({
        personaId: 'food_companion',
        summary: '偏好',
        memoryText: '用户偏好：测试。'
      }), 'missing') === null).assertTrue();

      expect(parsePersonaMemoryUpdateInput(JSON.stringify({
        personaId: 'food_companion',
        summary: '偏好',
        memoryText: ''
      }), 'food_companion') === null).assertTrue();
    });

    it('builds a summarized InfoRows surface with rerun and edit actions', 0, () => {
      configureDefaultPersonaStoreForTests();
      const update = parsePersonaMemoryUpdateInput('{"personaId":"food_companion","summary":"只喝瑞幸咖啡","memoryText":"用户咖啡偏好：只喝瑞幸咖啡。","suggestedAction":{"label":"按新偏好重新查咖啡","prompt":"点一杯咖啡","toolId":"food.search"}}', 'food_companion') as PersonaMemoryUpdateRequest;

      const surface = memoryUpdateSurface('surface_model', update);
      const card = surface.components[1];
      const rows = labelValues(surface, card);
      const actions = actionsOf(card);

      expect(surface.title).assertEqual('饮食搭子已更新记忆');
      expect(rows[0].label).assertEqual('已记录');
      expect(rows[1].label).assertEqual('原因');
      expect(rows[2].label).assertEqual('Memory 摘要');
      expect(rows[2].value).assertEqual('用户咖啡偏好：只喝瑞幸咖啡。');
      expect(rows[3].label).assertEqual('Soul 摘要');
      expect(actions[0].label).assertEqual('按新偏好重新查咖啡');
      expect(actions[0].kind).assertEqual('prompt');
      expect(actions[0].prompt).assertEqual('点一杯咖啡');
      expect(actions[1].id).assertEqual('persona_memory_edit');
      expect(actions[1].kind).assertEqual('client');
      expect(actions[1].prompt).assertEqual('food_companion');
      expect(actions[2].id).assertEqual('persona_soul_edit');
      expect(actions[2].kind).assertEqual('client');
    });
  });
}
