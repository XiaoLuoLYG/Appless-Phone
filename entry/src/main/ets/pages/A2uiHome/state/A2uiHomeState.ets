import { A2uiSurfaceState, RuntimeOwner } from '@loop/agent-core';

export const A2UI_SEND_SPINNER_STEP_DEG: number = 24;

export interface ConnectionPanelState {
  connectionStatus: string;
  connectionMessage: string;
  lastModelRequest: string;
  lastModelOutput: string;
  lastError: string;
  refreshTick: number;
}

export interface ConnectionPanelUpdate {
  ok: boolean;
  status: string;
  message: string;
  requestDebug: string;
  assistantDebug: string;
  error: string;
}

export function createInitialConnectionPanelState(): ConnectionPanelState {
  return {
    connectionStatus: 'idle',
    connectionMessage: '尚未测试模型连接。',
    lastModelRequest: '',
    lastModelOutput: '',
    lastError: '',
    refreshTick: 0
  };
}

export function updateConnectionPanelState(current: ConnectionPanelState, update: ConnectionPanelUpdate): ConnectionPanelState {
  return {
    connectionStatus: update.status,
    connectionMessage: update.message,
    lastModelRequest: update.requestDebug,
    lastModelOutput: update.assistantDebug,
    lastError: update.ok ? '' : update.error,
    refreshTick: current.refreshTick + 1
  };
}

export function shouldApplySurfaceUpdate(current: A2uiSurfaceState, next: A2uiSurfaceState): boolean {
  const currentGeneration: number = current.runtimeGeneration === undefined ? 0 : current.runtimeGeneration;
  const nextGeneration: number = next.runtimeGeneration === undefined ? 0 : next.runtimeGeneration;
  if (nextGeneration < currentGeneration) {
    return false;
  }
  if (nextGeneration === currentGeneration && current.runtimeOwner !== undefined &&
    next.runtimeOwner !== undefined && current.runtimeOwner !== next.runtimeOwner) {
    return false;
  }
  return current.surfaceId !== next.surfaceId || current.sequence !== next.sequence;
}

export function runtimeOwnerAllowsSurfaceAction(
  surface: A2uiSurfaceState,
  owner: RuntimeOwner
): boolean {
  return surface.runtimeOwner === owner;
}

export function runtimeCallbackIsCurrent(
  activeOwner: RuntimeOwner,
  activeGeneration: number,
  callbackOwner: RuntimeOwner,
  callbackGeneration: number
): boolean {
  return activeOwner === callbackOwner && activeGeneration === callbackGeneration;
}

export function runtimeSurfaceIdentityMatches(
  current: A2uiSurfaceState,
  retained: A2uiSurfaceState,
  activeOwner: RuntimeOwner,
  activeGeneration: number
): boolean {
  return activeOwner === 'multi_agent' && Number.isSafeInteger(activeGeneration) &&
    activeGeneration > 0 &&
    current.runtimeOwner === activeOwner &&
    retained.runtimeOwner === activeOwner &&
    current.runtimeGeneration === activeGeneration &&
    retained.runtimeGeneration === activeGeneration &&
    current.surfaceId.trim().length > 0 &&
    current.surfaceId === retained.surfaceId;
}

export function shouldPreserveHtmlHomeForPageAction(actionId: string): boolean {
  return actionId === 'html_mail_detail_read';
}

export function nextSendSpinnerRotation(current: number, isBusy: boolean): number {
  if (!isBusy) {
    return 0;
  }
  return current + A2UI_SEND_SPINNER_STEP_DEG;
}

export function isPromptInputEnabled(isBusy: boolean): boolean {
  return !isBusy;
}

export function shouldShowQueryPendingSurface(isBusy: boolean, isAwaitingFirstSurface: boolean): boolean {
  return isBusy && isAwaitingFirstSurface;
}

export function isWelcomeSurface(surface: A2uiSurfaceState): boolean {
  return surface.surfaceId === 'surface_seed' &&
    surface.status === 'idle' &&
    surface.components.length === 0;
}

export function shouldShowWelcome(isBusy: boolean, messageCount: number, surface: A2uiSurfaceState): boolean {
  return !isBusy && messageCount === 0 && isWelcomeSurface(surface);
}

export function inputTextAfterPromptSubmit(current: string): string {
  return current;
}

export function voiceInputTextAfterRecognition(current: string, recognized: string): string {
  const next = recognized.trim();
  if (next.length === 0) {
    return current;
  }
  const draft = current.trim();
  if (draft.length === 0) {
    return next;
  }
  return draft + ' ' + next;
}

export function connectionStatusLabel(status: string): string {
  if (status === 'checking') {
    return '检查中';
  }
  if (status === 'ready') {
    return '连接正常';
  }
  if (status === 'error') {
    return '连接异常';
  }
  return '未检查';
}
