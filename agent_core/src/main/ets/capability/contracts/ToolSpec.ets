import { SchemaRef, cloneSchemaRef } from './SchemaTypes';
import { ToolEffect, cloneToolEffects } from './ToolEffect';

export type CapabilityRiskLevel = 'read' | 'draft' | 'confirm_required' | 'blocked';
export type ToolIdempotencyPolicy = 'idempotent' | 'non_idempotent' | 'provider_key_required';
export type ToolParallelPolicy = 'parallel' | 'serial' | 'exclusive';

export interface BackendCandidate {
  backendId: string;
  priority: number;
}

export interface CredentialRequirement {
  mode: string;
  reference: string;
  required: boolean;
}

export interface ToolSpec {
  id: string;
  version: string;
  capabilityId: string;
  domain: string;
  riskLevel: CapabilityRiskLevel;
  inputSchemaRef: SchemaRef;
  outputSchemaRef: SchemaRef;
  declaredEffects: ToolEffect[];
  backendCandidates: BackendCandidate[];
  credentialRequirements: CredentialRequirement[];
  timeoutMs: number;
  cancellable: boolean;
  idempotency: ToolIdempotencyPolicy;
  parallelPolicy: ToolParallelPolicy;
  supportedSurfaces: string[];
}

export function cloneToolSpec(spec: ToolSpec): ToolSpec {
  return {
    id: spec.id,
    version: spec.version,
    capabilityId: spec.capabilityId,
    domain: spec.domain,
    riskLevel: spec.riskLevel,
    inputSchemaRef: cloneSchemaRef(spec.inputSchemaRef),
    outputSchemaRef: cloneSchemaRef(spec.outputSchemaRef),
    declaredEffects: cloneToolEffects(spec.declaredEffects),
    backendCandidates: spec.backendCandidates.map((candidate: BackendCandidate): BackendCandidate => ({
      backendId: candidate.backendId,
      priority: candidate.priority
    })),
    credentialRequirements: spec.credentialRequirements.map(
      (requirement: CredentialRequirement): CredentialRequirement => ({
        mode: requirement.mode,
        reference: requirement.reference,
        required: requirement.required
      })
    ),
    timeoutMs: spec.timeoutMs,
    cancellable: spec.cancellable,
    idempotency: spec.idempotency,
    parallelPolicy: spec.parallelPolicy,
    supportedSurfaces: spec.supportedSurfaces.slice()
  };
}
