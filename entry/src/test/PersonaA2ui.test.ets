import { describe, it, expect } from '@ohos/hypium';
import { A2uiSurfaceState } from '@loop/agent-core';
import { personaMemoryData, personaRuntimeData } from '@loop/agent-core';
import { attachPersonaDataToSurface, copyPersonaData } from '../main/ets/model/PersonaA2ui';

function baseSurface(): A2uiSurfaceState {
  return {
    surfaceId: 's',
    rootId: 'root',
    title: '测试',
    intent: 'general',
    status: 'ready',
    components: [],
    dataModelJson: '{}',
    error: '',
    sequence: 1
  };
}

export default function personaA2uiTest() {
  describe('personaA2ui', () => {
    it('attaches persona and memory data to a surface', 0, () => {
      const surface = attachPersonaDataToSurface(baseSurface(), {
        id: 'food_companion',
        name: '饮食搭子',
        avatarKey: 'food',
        status: 'online',
        reason: '用户请求属于饮食场景。'
      }, {
        summary: '根据你的偏好，优先考虑半糖、瑞幸优先。',
        preferences: ['半糖', '瑞幸优先']
      });

      expect(personaRuntimeData(surface).id).assertEqual('food_companion');
      expect(personaMemoryData(surface).preferences[0]).assertEqual('半糖');
    });

    it('copies persona data from one surface to another', 0, () => {
      const source = attachPersonaDataToSurface(baseSurface(), {
        id: 'food_companion',
        name: '饮食搭子',
        avatarKey: 'food',
        status: 'online',
        reason: '用户请求属于饮食场景。'
      }, {
        summary: '根据你的偏好，优先考虑半糖。',
        preferences: ['半糖']
      });
      const copied = copyPersonaData(source, baseSurface());

      expect(personaRuntimeData(copied).name).assertEqual('饮食搭子');
      expect(personaMemoryData(copied).summary.indexOf('半糖')).assertLarger(-1);
    });
  });
}
