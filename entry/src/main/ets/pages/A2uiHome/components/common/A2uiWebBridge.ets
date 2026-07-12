export type A2uiWebMessageValue = Object | string | number | boolean | null | undefined;
export type A2uiWebMessage = Record<string, A2uiWebMessageValue>;

export function parseA2uiWebMessage(raw: string): A2uiWebMessage | null {
  try {
    const parsed = JSON.parse(raw) as A2uiWebMessage;
    if (parsed === null || typeof parsed !== 'object') {
      return null;
    }
    return parsed;
  } catch (error) {
    return null;
  }
}

export class A2uiWebBridge {
  onMessage: (message: A2uiWebMessage) => void = (_message: A2uiWebMessage): void => {};

  postMessage(raw: string): void {
    const message = parseA2uiWebMessage(raw);
    if (message !== null) {
      this.onMessage(message);
    }
  }
}
