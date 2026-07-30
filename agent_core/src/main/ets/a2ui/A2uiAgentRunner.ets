import { ConversationContext } from '../agent/ConversationContext';
import { A2uiModel } from './A2uiModel';
import { buildCreateSurface, newSurfaceId, parseJsonl } from './A2uiProtocol';

export type A2uiLineListener = (line: string) => void;
export type A2uiErrorListener = (message: string) => void;

export interface UiLayoutPlanner {
  plan(task: string, surfaceId: string): Promise<string | null>;
}

export class A2uiAgentRunner implements UiLayoutPlanner {
  private model: A2uiModel;

  constructor(model: A2uiModel) {
    this.model = model;
  }

  async plan(task: string, surfaceId: string): Promise<string | null> {
    try {
      return await this.generate(task, surfaceId);
    } catch (_error) {
      return null;
    }
  }

  async run(
    task: string,
    onLine: A2uiLineListener,
    onError: A2uiErrorListener,
    conversation?: ConversationContext
  ): Promise<string | null> {
    const surfaceId = newSurfaceId();

    try {
      const raw = await this.generate(task, surfaceId, conversation);
      let lines = parseJsonl(raw);

      const hasCreate = lines.some((line) => line.includes('"createSurface"'));
      if (!hasCreate) {
        lines = [buildCreateSurface(surfaceId), ...lines];
      }

      for (const line of lines) {
        onLine(line);
      }
      return surfaceId;
    } catch (error) {
      const message = error instanceof Error ? error.message : `${error}`;
      onError(message);
      return null;
    }
  }

  private generate(
    task: string,
    surfaceId: string,
    conversation?: ConversationContext
  ): Promise<string> {
    return this.model.generate(task, surfaceId, conversation);
  }
}
