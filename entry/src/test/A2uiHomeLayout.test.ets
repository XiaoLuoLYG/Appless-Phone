import { describe, it, expect } from '@ohos/hypium';
import {
  A2UI_HOME_MAX_WIDTH,
  A2UI_HOME_TITLE_MAX_WIDTH,
  A2UI_HOME_TITLE_MIN_WIDTH,
  a2uiHomeContentWidth,
  a2uiHomeTitleWidth
} from '../main/ets/pages/A2uiHome/style/A2uiHomeLayout';

export default function a2uiHomeLayoutTest() {
  describe('a2uiHomeLayout', () => {
    it('caps the home surface on large screens', 0, () => {
      expect(a2uiHomeContentWidth(1200)).assertEqual(A2UI_HOME_MAX_WIDTH);
      expect(a2uiHomeContentWidth(A2UI_HOME_MAX_WIDTH - 1)).assertEqual(A2UI_HOME_MAX_WIDTH - 1);
    });

    it('keeps the title within adaptive bounds instead of relying on ellipsis', 0, () => {
      expect(a2uiHomeTitleWidth(360)).assertEqual(A2UI_HOME_TITLE_MIN_WIDTH);
      expect(a2uiHomeTitleWidth(720)).assertEqual(A2UI_HOME_TITLE_MAX_WIDTH);
    });
  });
}
