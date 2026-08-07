import { ActionLinkRegistry } from '../registry/ActionLinkRegistry';

export class LegacyActionCatalogAdapter {
  private readonly links: ActionLinkRegistry;

  constructor(links: ActionLinkRegistry) {
    this.links = links;
  }

  actionsFor(toolId: string): string[] {
    return this.links.targets(toolId);
  }
}
