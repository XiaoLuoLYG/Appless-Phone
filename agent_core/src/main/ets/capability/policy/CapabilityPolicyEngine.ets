import { PolicyDecision } from '../contracts/PolicyTypes';
import { ToolCall } from '../contracts/ToolCall';
import { ToolEffect } from '../contracts/ToolEffect';
import { ToolSpec } from '../contracts/ToolSpec';
import { ApprovalBroker } from './ApprovalBroker';
import { effectsRequireApproval } from './DefaultPolicyRules';
import { CredentialPolicy } from './CredentialPolicy';
import { DynamicToolPolicy } from './DynamicToolPolicy';
import { SurfaceAuthority } from './SurfaceAuthority';

export class CapabilityPolicyEngine {
  private readonly approvals: ApprovalBroker;
  private readonly credentials: CredentialPolicy = new CredentialPolicy();
  private readonly dynamicTools: DynamicToolPolicy = new DynamicToolPolicy();
  private readonly surfaces: SurfaceAuthority = new SurfaceAuthority();

  constructor(approvals: ApprovalBroker) {
    this.approvals = approvals;
  }

  evaluate(
    call: ToolCall,
    spec: ToolSpec,
    effects: ToolEffect[]
  ): PolicyDecision {
    if (!this.surfaces.allows(call)) {
      return { kind: 'deny', code: 'SURFACE_AUTHORITY_INVALID', message: 'Tool call has no current turn or surface authority.' };
    }
    if (!this.credentials.hasRequiredReferences(spec)) {
      return { kind: 'deny', code: 'CREDENTIAL_REFERENCE_MISSING', message: 'Required credential reference is missing.' };
    }
    if (!this.dynamicTools.allows(spec)) {
      return { kind: 'deny', code: 'DYNAMIC_TOOL_ISOLATED', message: 'Dynamic tool is not eligible for execution.' };
    }
    if (spec.riskLevel === 'blocked') {
      return { kind: 'deny', code: 'TOOL_BLOCKED', message: 'Tool is blocked by capability policy.' };
    }
    if (call.context.agentId === 'data_agent' && spec.riskLevel !== 'read') {
      return {
        kind: 'deny',
        code: 'TOOL_NOT_ALLOWED',
        message: 'DataAgent cannot execute ' + spec.id + '.'
      };
    }
    const needsApproval = spec.riskLevel === 'confirm_required' || effectsRequireApproval(effects);
    if (!needsApproval) {
      return { kind: 'allow', code: '', message: '' };
    }
    if (call.approvalGrant !== undefined) {
      return { kind: 'allow', code: '', message: '' };
    }
    return {
      kind: 'approval_required',
      code: 'APPROVAL_REQUIRED',
      message: 'Tool requires exact user approval before execution.',
      approvalRequest: this.approvals.request(call, spec)
    };
  }
}
