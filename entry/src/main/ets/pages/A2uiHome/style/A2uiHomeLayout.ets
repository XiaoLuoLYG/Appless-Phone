export const A2UI_HOME_MAX_WIDTH: number = 840;
export const A2UI_HOME_TITLE_MAX_WIDTH: number = 150;
export const A2UI_HOME_TITLE_MIN_WIDTH: number = 88;

export function a2uiHomeContentWidth(viewportWidth: number): number {
  if (viewportWidth <= 0) {
    return A2UI_HOME_MAX_WIDTH;
  }
  return Math.min(viewportWidth, A2UI_HOME_MAX_WIDTH);
}

export function a2uiHomeTitleWidth(viewportWidth: number): number {
  if (viewportWidth <= 0) {
    return A2UI_HOME_TITLE_MAX_WIDTH;
  }
  if (viewportWidth <= 380) {
    return A2UI_HOME_TITLE_MIN_WIDTH;
  }
  return A2UI_HOME_TITLE_MAX_WIDTH;
}
