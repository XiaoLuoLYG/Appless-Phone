import { describe, it, expect } from '@ohos/hypium';
import {
  A2UI_CIRCLE_BUTTON_BACKGROUND,
  A2UI_CIRCLE_BUTTON_BORDER,
  A2UI_CIRCLE_BUTTON_ICON_SIZE,
  A2UI_CIRCLE_BUTTON_SIZE,
  resolveA2uiButtonColor,
  resolveA2uiButtonStyle
} from '../main/ets/pages/A2uiHome/style/A2uiButtonStyle';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_ACTION_ACTIVATED,
  COLOR_ACTION_DEACTIVATED,
  COLOR_BUTTON_TEXT,
  COLOR_ERROR_SOFT
} from '../main/ets/pages/A2uiHome/style/A2uiHomeTheme';

export default function a2uiButtonStyleTest() {
  describe('a2uiButtonStyle', () => {
    it('uses activated style when active', 0, () => {
      const style = resolveA2uiButtonStyle('secondary', true, true);

      expect(style.backgroundColor).assertEqual(COLOR_ACTION_ACTIVATED);
      expect(style.backgroundColor).assertEqual(COLOR_ACCENT_DEEP);
      expect(style.borderColor).assertEqual(COLOR_ACCENT);
      expect(style.textColor).assertEqual(COLOR_BUTTON_TEXT);
    });

    it('uses disabled style before active or tone', 0, () => {
      const style = resolveA2uiButtonStyle('danger', true, false);

      expect(style.backgroundColor).assertEqual(COLOR_ACTION_DEACTIVATED);
      expect(style.opacity < 1).assertTrue();
    });

    it('keeps deactivated button text bright while enabled', 0, () => {
      const style = resolveA2uiButtonStyle('deactivated', false, true);

      expect(style.backgroundColor).assertEqual(COLOR_ACTION_DEACTIVATED);
      expect(style.textColor).assertEqual(COLOR_BUTTON_TEXT);
      expect(style.opacity).assertEqual(1);
    });

    it('uses danger style when enabled and not overridden by disabled', 0, () => {
      expect(resolveA2uiButtonStyle('danger', false, true).backgroundColor).assertEqual(COLOR_ERROR_SOFT);
    });

    it('uses compact title-bar defaults for circle buttons', 0, () => {
      expect(A2UI_CIRCLE_BUTTON_SIZE).assertEqual(32);
      expect(A2UI_CIRCLE_BUTTON_ICON_SIZE).assertEqual(16);
      expect(A2UI_CIRCLE_BUTTON_BACKGROUND).assertEqual('#18181B');
      expect(A2UI_CIRCLE_BUTTON_BORDER).assertEqual('#27272A');
    });

    it('uses explicit color overrides and falls back for empty values', 0, () => {
      expect(resolveA2uiButtonColor('#0D9488', '#18181B')).assertEqual('#0D9488');
      expect(resolveA2uiButtonColor('', '#18181B')).assertEqual('#18181B');
    });
  });
}
