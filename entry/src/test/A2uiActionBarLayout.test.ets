import { describe, it, expect } from '@ohos/hypium';
import {
  A2UI_DIALOG_ACTION_COUNT,
  actionRenderKey,
  usesDialogActionLayout
} from '../main/ets/pages/A2uiHome/style/A2uiActionBarLayout';

export default function a2uiActionBarLayoutTest() {
  describe('a2uiActionBarLayout', () => {
    it('uses dialog action layout for exactly two actions', 0, () => {
      expect(usesDialogActionLayout(A2UI_DIALOG_ACTION_COUNT)).assertTrue();
    });

    it('keeps wrap layout for zero one or dense actions', 0, () => {
      expect(usesDialogActionLayout(0)).assertFalse();
      expect(usesDialogActionLayout(1)).assertFalse();
      expect(usesDialogActionLayout(3)).assertFalse();
      expect(usesDialogActionLayout(7)).assertFalse();
    });

    it('includes variant in action render keys so active state refreshes', 0, () => {
      const inactiveKey = actionRenderKey({
        id: 'client_show_more',
        label: '展示全部',
        prompt: 'client_show_more',
        kind: 'client',
        variant: 'deactivated'
      });
      const activeKey = actionRenderKey({
        id: 'client_show_more',
        label: '展示全部',
        prompt: 'client_show_more',
        kind: 'client',
        variant: 'activated'
      });

      expect(inactiveKey === activeKey).assertFalse();
    });
  });
}
