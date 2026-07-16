export class HtmlHomeSceneUpdate {
  surfaceId: string;
  documentKey: string;
  html: string;
  isBusy: boolean;
  renderTick: number;

  constructor(surfaceId: string, documentKey: string, html: string, isBusy: boolean, renderTick: number) {
    this.surfaceId = surfaceId;
    this.documentKey = documentKey;
    this.html = html;
    this.isBusy = isBusy;
    this.renderTick = renderTick;
  }
}

export type HtmlHomeSceneUpdateListener = (update: HtmlHomeSceneUpdate) => void;

const sceneUpdateListeners: Map<string, HtmlHomeSceneUpdateListener> = new Map();
const latestSceneUpdates: Map<string, HtmlHomeSceneUpdate> = new Map();

export function registerHtmlHomeSceneUpdateListener(
  surfaceId: string,
  listener: HtmlHomeSceneUpdateListener
): void {
  if (surfaceId.length === 0) {
    return;
  }
  sceneUpdateListeners.set(surfaceId, listener);
  const latest = latestSceneUpdates.get(surfaceId);
  if (latest !== undefined) {
    listener(latest);
  }
}

export function unregisterHtmlHomeSceneUpdateListener(
  surfaceId: string,
  listener: HtmlHomeSceneUpdateListener
): void {
  if (sceneUpdateListeners.get(surfaceId) === listener) {
    sceneUpdateListeners.delete(surfaceId);
  }
}

export function publishHtmlHomeSceneUpdate(update: HtmlHomeSceneUpdate): void {
  if (update.surfaceId.length === 0 || update.html.length === 0) {
    return;
  }
  latestSceneUpdates.set(update.surfaceId, update);
  const listener = sceneUpdateListeners.get(update.surfaceId);
  if (listener !== undefined) {
    listener(update);
  }
}

export function clearHtmlHomeSceneUpdates(): void {
  latestSceneUpdates.clear();
}
