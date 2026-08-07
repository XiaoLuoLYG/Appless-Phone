import { ToolSpec } from '../contracts/ToolSpec';

export class DynamicToolPolicy {
  allows(spec: ToolSpec): boolean {
    const dynamic = spec.capabilityId.indexOf('dynamic') >= 0 || spec.id.indexOf('mcp:') === 0 ||
      spec.id.indexOf('connector:') === 0;
    if (!dynamic) {
      return true;
    }
    return spec.riskLevel === 'read' && !spec.declaredEffects.some((effect): boolean =>
      effect.kind === 'external_write' || effect.kind === 'financial_transaction'
    );
  }
}
