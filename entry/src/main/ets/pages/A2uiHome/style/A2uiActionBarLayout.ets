import { A2uiAction } from '@loop/agent-core';

export const A2UI_DIALOG_ACTION_COUNT: number = 2;
export const A2UI_DIALOG_ACTION_SIDE_PADDING: number = 6;
export const A2UI_DIALOG_ACTION_GAP: number = 10;

export function usesDialogActionLayout(actionCount: number): boolean {
  return actionCount === A2UI_DIALOG_ACTION_COUNT;
}

export function actionRenderKey(action: A2uiAction): string {
  return action.id + '|' + action.label + '|' + action.variant;
}
