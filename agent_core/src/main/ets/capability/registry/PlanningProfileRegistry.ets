import { ToolPlanningProfile } from '../contracts/CapabilityModule';

export class PlanningProfileRegistry {
  private readonly profiles: Map<string, ToolPlanningProfile> = new Map<string, ToolPlanningProfile>();

  register(profile: ToolPlanningProfile): void {
    if (this.profiles.has(profile.toolId)) {
      throw new Error('Duplicate planning profile: ' + profile.toolId);
    }
    this.profiles.set(profile.toolId, {
      toolId: profile.toolId,
      summary: profile.summary,
      useWhen: profile.useWhen,
      avoidWhen: profile.avoidWhen
    });
  }

  find(toolId: string): ToolPlanningProfile | null {
    const profile = this.profiles.get(toolId);
    if (profile === undefined) {
      return null;
    }
    return {
      toolId: profile.toolId,
      summary: profile.summary,
      useWhen: profile.useWhen,
      avoidWhen: profile.avoidWhen
    };
  }
}
