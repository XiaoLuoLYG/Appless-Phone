import { CapabilityRiskLevel } from '../contracts/ToolSpec';

export interface DynamicToolSafetyClassification {
  riskLevel: CapabilityRiskLevel;
  executable: boolean;
  reason: string;
}

export class DynamicToolSafetyClassifier {
  classify(declaredReadOnly: boolean, declaredDestructive: boolean): DynamicToolSafetyClassification {
    if (declaredDestructive) {
      return { riskLevel: 'blocked', executable: false, reason: 'Unknown destructive dynamic tools are isolated.' };
    }
    if (declaredReadOnly) {
      return { riskLevel: 'read', executable: true, reason: 'Provider explicitly declared the tool read-only.' };
    }
    return { riskLevel: 'confirm_required', executable: false, reason: 'Unknown write authority cannot be inferred from a name.' };
  }
}
