import { describe, it, expect } from '@ohos/hypium';
import { A2uiSurfaceState } from '@loop/agent-core';
import { personaMemoryData, personaRuntimeData } from '@loop/agent-core';
import {
  attachLeaderPersonaDataToSurface,
  attachPersonaDataToSurface,
  copyPersonaData,
  leaderPersonaSurfaceUpdate
} from '../main/ets/model/PersonaA2ui';
import { configureDefaultPersonaStoreForTests } from '../main/ets/model/PersonaStore';
import { shouldApplySurfaceUpdate } from '../main/ets/pages/A2uiHome/state/A2uiHomeState';

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

    it('uses the Leader-selected persona and skill in the existing persona surface data', 0, () => {
      configureDefaultPersonaStoreForTests();
      const attached: A2uiSurfaceState = attachLeaderPersonaDataToSurface(
        baseSurface(),
        'travel_companion',
        'travel-planning'
      );

      expect(personaRuntimeData(attached).id).assertEqual('travel_companion');
      expect(personaRuntimeData(attached).name).assertEqual('旅行搭子');
      expect(personaRuntimeData(attached).reason.indexOf('Leader')).assertLarger(-1);
      expect(personaRuntimeData(attached).reason.indexOf('travel-planning')).assertEqual(-1);
      expect(personaMemoryData(attached).summary.length > 0).assertTrue();
    });

    it('preserves a same-persona surface summary produced by an existing scene', 0, () => {
      configureDefaultPersonaStoreForTests();
      const sceneSurface = attachPersonaDataToSurface(baseSurface(), {
        id: 'food_companion',
        name: '饮食搭子',
        avatarKey: 'food',
        status: 'online',
        reason: '用户刚刚更新了长期偏好。'
      }, {
        summary: '已记录：只喝瑞幸咖啡',
        preferences: ['只喝瑞幸咖啡']
      });
      const attached = attachLeaderPersonaDataToSurface(sceneSurface, 'food_companion', '');

      expect(personaMemoryData(attached).summary).assertEqual('已记录：只喝瑞幸咖啡');
      expect(personaRuntimeData(attached).reason).assertEqual('用户刚刚更新了长期偏好。');
    });

    it('creates a monotonic same-surface host update for Leader persona data', 0, () => {
      configureDefaultPersonaStoreForTests();
      const current = baseSurface();
      current.runtimeOwner = 'multi_agent';
      current.runtimeGeneration = 7;
      const next = leaderPersonaSurfaceUpdate(current, 'travel_companion', '');

      expect(next.surfaceId).assertEqual(current.surfaceId);
      expect(next.sequence).assertEqual(current.sequence + 1);
      expect(next.runtimeGeneration).assertEqual(7);
      expect(shouldApplySurfaceUpdate(current, next)).assertTrue();
      expect(personaRuntimeData(next).id).assertEqual('travel_companion');
    });
  });
}
