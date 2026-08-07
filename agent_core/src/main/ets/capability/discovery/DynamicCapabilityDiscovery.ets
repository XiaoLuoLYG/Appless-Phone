import { CapabilityModule } from '../contracts/CapabilityModule';

export interface CapabilityDiscoverySource {
  discover(query: string): Promise<CapabilityModule[]>;
}

export class DynamicCapabilityDiscovery {
  private readonly sources: CapabilityDiscoverySource[];

  constructor(sources: CapabilityDiscoverySource[]) {
    this.sources = sources.slice();
  }

  async discover(query: string): Promise<CapabilityModule[]> {
    const result: CapabilityModule[] = [];
    for (let index = 0; index < this.sources.length; index++) {
      const modules = await this.sources[index].discover(query);
      for (let moduleIndex = 0; moduleIndex < modules.length; moduleIndex++) result.push(modules[moduleIndex]);
    }
    return result;
  }
}
