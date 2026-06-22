import { describe, it, expect } from '@ohos/hypium';
import {
  A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS,
  normalizeFoodPartialThrottleMs,
  normalizeFoodProviderDelayMs
} from '../main/ets/pages/A2uiHome/state/A2uiHomeDebugSettings';

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
  });
}
