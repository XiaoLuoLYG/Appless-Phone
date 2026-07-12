import { describe, it, expect } from '@ohos/hypium';
import {
  A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS,
  HTML_HOME_DEBUG_EXPORT_FILE_NAME,
  htmlHomeDebugExportJson,
  normalizeFoodPartialThrottleMs,
  normalizeFoodProviderDelayMs
} from '../main/ets/pages/A2uiHome/state/A2uiHomeDebugSettings';
import { HtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeTypes';

function htmlHomeDocumentFixture(): HtmlHomeDocument {
  return {
    version: 1,
    source: 'tool',
    kind: 'food',
    title: '附近咖啡',
    subtitle: '真实餐饮结果',
    chips: [],
    metrics: [],
    timeline: [],
    blocks: [{
      id: 'food-0',
      kind: 'food-result',
      title: '瑞幸咖啡',
      subtitle: '咖啡',
      source: '高德',
      metrics: [{ label: 'distance', value: '120米' }],
      rows: [],
      actions: []
    }],
    actions: [],
    history: [{ id: 'm1', role: 'user', content: '帮我找咖啡' }],
    persona: { id: 'food_companion', name: 'Foodie', avatarKey: 'chef', status: 'active', reason: '餐饮场景' },
    personaMemory: { summary: '用户喜欢咖啡', preferences: ['咖啡'] },
    rawSurfaceRoot: {
      id: 'root',
      component: 'surfaceRoot',
      children: []
    },
    generatedAt: '2026-07-08T00:00:00.000Z'
  };
}

export default function a2uiHomeDebugSettingsTest() {
  describe('a2uiHomeDebugSettings', () => {
    it('normalizes food provider delay milliseconds for debug settings', 0, () => {
      expect(normalizeFoodProviderDelayMs('')).assertEqual(0);
      expect(normalizeFoodProviderDelayMs(' 2500 ')).assertEqual(2500);
      expect(normalizeFoodProviderDelayMs('-3')).assertEqual(0);
      expect(normalizeFoodProviderDelayMs('abc')).assertEqual(0);
      expect(normalizeFoodProviderDelayMs('90000')).assertEqual(30000);
    });

    it('defaults and bounds food partial render throttle milliseconds', 0, () => {
      expect(A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS).assertEqual(500);
      expect(normalizeFoodPartialThrottleMs('')).assertEqual(500);
      expect(normalizeFoodPartialThrottleMs(' 750 ')).assertEqual(750);
      expect(normalizeFoodPartialThrottleMs('-1')).assertEqual(0);
      expect(normalizeFoodPartialThrottleMs('abc')).assertEqual(500);
      expect(normalizeFoodPartialThrottleMs('90000')).assertEqual(5000);
    });

    it('serializes the html home debug export as pretty JSON for file dumps', 0, () => {
      const json = htmlHomeDebugExportJson(htmlHomeDocumentFixture(), true);
      const parsed = JSON.parse(json) as Record<string, Object | string | number | boolean | null>;

      expect(HTML_HOME_DEBUG_EXPORT_FILE_NAME).assertEqual('html-home-document-debug.json');
      expect(json.indexOf('\n  "kind": "food"')).assertLarger(-1);
      expect(parsed['kind'] as string).assertEqual('food');
      expect(parsed['isBusy'] as boolean).assertTrue();
      expect(parsed['rawSurfaceRoot']).assertEqual(null);
      expect(parsed['generatedAt'] as string).assertEqual('');
      expect((parsed['history'] as Object[]).length).assertEqual(0);
      expect((parsed['personaAvatarDataUri'] as string).length).assertLarger(0);
    });
  });
}
