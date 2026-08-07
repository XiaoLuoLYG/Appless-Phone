import { ActionLink } from '../contracts/CapabilityModule';

function linkKey(sourceToolId: string, targetToolId: string): string {
  return sourceToolId + '->' + targetToolId;
}

export class ActionLinkRegistry {
  private readonly links: Map<string, ActionLink> = new Map<string, ActionLink>();

  register(link: ActionLink): void {
    const key = linkKey(link.sourceToolId, link.targetToolId);
    if (this.links.has(key)) {
      return;
    }
    this.links.set(key, {
      sourceToolId: link.sourceToolId,
      targetToolId: link.targetToolId
    });
  }

  targets(sourceToolId: string): string[] {
    const result: string[] = [];
    this.links.forEach((link: ActionLink) => {
      if (link.sourceToolId === sourceToolId) {
        result.push(link.targetToolId);
      }
    });
    return result;
  }

  all(): ActionLink[] {
    const result: ActionLink[] = [];
    this.links.forEach((link: ActionLink) => result.push({
      sourceToolId: link.sourceToolId,
      targetToolId: link.targetToolId
    }));
    return result;
  }
}
