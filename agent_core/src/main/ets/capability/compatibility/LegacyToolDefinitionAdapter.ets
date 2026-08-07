import { ToolDefinition } from '../../aiphone/runtime/ToolDefinitionTypes';
import { CapabilityManifest } from '../contracts/CapabilityManifest';
import { ActionLink, ToolPlanningProfile } from '../contracts/CapabilityModule';
import { ToolEffect, ToolEffectKind } from '../contracts/ToolEffect';
import { BackendCandidate, CredentialRequirement, ToolSpec } from '../contracts/ToolSpec';

export function capabilityIdForLegacyDomain(domain: string): string {
  if (domain === 'hotel') return 'travel.hotel';
  if (domain === 'travel' || domain === 'train' || domain === 'flight') return 'travel.transport';
  if (domain === 'calendar') return 'productivity.calendar';
  if (domain === 'food' || domain === 'maps' || domain === 'ride' || domain === 'luckin') return 'local_life.' + domain;
  if (domain === 'mail' || domain === 'gmail' || domain === 'social' || domain === 'whatsapp' || domain === 'x') {
    return 'communication.' + domain;
  }
  if (domain === 'media' || domain === 'youtube' || domain === 'worldcup') return 'media.' + domain;
  if (domain === 'payment' || domain === 'shopping' || domain === 'commerce') return 'commerce.' + domain;
  if (domain === 'web' || domain === 'research' || domain === 'monitor' || domain === 'firecrawl') return 'research.' + domain;
  if (domain === 'system' || domain === 'core') return 'core';
  return 'connectors.' + domain;
}

function effect(kind: ToolEffectKind, target: string, reversible: boolean): ToolEffect {
  return { kind, target, reversible };
}

export function effectsForLegacyTool(definition: ToolDefinition): ToolEffect[] {
  const effects: ToolEffect[] = [];
  if (definition.riskLevel === 'read') {
    effects.push(effect('read_data', definition.domain, true));
  } else if (definition.riskLevel === 'draft') {
    effects.push(effect('create_draft', definition.domain, true));
  } else {
    effects.push(effect('external_write', definition.domain, false));
  }
  if (definition.toolId.indexOf('payment') >= 0 || definition.toolId.indexOf('order.create') >= 0) {
    effects.push(effect('financial_transaction', definition.domain, false));
  }
  if (definition.backendPriority.indexOf('system_intent') >= 0) {
    effects.push(effect('device_control', definition.domain, true));
  } else if (definition.backendPriority.indexOf('local_adapter') < 0) {
    effects.push(effect('network_access', definition.domain, true));
  }
  return effects;
}

export function legacyToolDefinitionToSpec(definition: ToolDefinition): ToolSpec {
  const candidates = definition.backendPriority.map((backendId: string, index: number): BackendCandidate => ({
    backendId,
    priority: index
  }));
  const credentials = definition.authModes.map((mode: string): CredentialRequirement => ({
    mode,
    reference: definition.domain + ':' + mode,
    required: mode !== 'none'
  }));
  const idempotency = definition.riskLevel === 'confirm_required' ? 'non_idempotent' : 'idempotent';
  return {
    id: definition.toolId,
    version: '1.0.0',
    capabilityId: capabilityIdForLegacyDomain(definition.domain),
    domain: definition.domain,
    riskLevel: definition.riskLevel,
    inputSchemaRef: { id: definition.inputSchema, version: '1.0.0' },
    outputSchemaRef: { id: definition.outputSchema, version: '1.0.0' },
    declaredEffects: effectsForLegacyTool(definition),
    backendCandidates: candidates,
    credentialRequirements: credentials,
    timeoutMs: 30000,
    cancellable: definition.riskLevel === 'read',
    idempotency,
    parallelPolicy: definition.riskLevel === 'read' ? 'parallel' : 'serial',
    supportedSurfaces: ['a2ui', 'agent']
  };
}

export function legacyActionLinks(definition: ToolDefinition): ActionLink[] {
  return definition.actions.map((targetToolId: string): ActionLink => ({
    sourceToolId: definition.toolId,
    targetToolId
  }));
}

export function legacyPlanningProfile(definition: ToolDefinition): ToolPlanningProfile {
  return {
    toolId: definition.toolId,
    summary: definition.intent,
    useWhen: 'Use when the user intent matches ' + definition.intent + '.',
    avoidWhen: definition.riskLevel === 'read' ? '' : 'Do not execute without the required action workflow and policy approval.'
  };
}

export function legacyCapabilityManifest(capabilityId: string, definitions: ToolDefinition[]): CapabilityManifest {
  const domains: string[] = [];
  const presenters: string[] = [];
  const permissions: string[] = [];
  definitions.forEach((definition: ToolDefinition) => {
    if (domains.indexOf(definition.domain) < 0) domains.push(definition.domain);
    const presenterId = 'legacy:' + definition.a2uiComponent;
    if (presenters.indexOf(presenterId) < 0) presenters.push(presenterId);
    definition.authModes.forEach((mode: string) => {
      if (mode !== 'none' && permissions.indexOf(mode) < 0) permissions.push(mode);
    });
    effectsForLegacyTool(definition).forEach((toolEffect: ToolEffect) => {
      if (permissions.indexOf(toolEffect.kind) < 0) permissions.push(toolEffect.kind);
    });
  });
  return {
    id: capabilityId,
    version: '1.0.0',
    displayName: capabilityId,
    domains,
    toolIds: definitions.map((definition: ToolDefinition): string => definition.toolId),
    presenterIds: presenters,
    skillRefs: [],
    requiredPermissions: permissions,
    supportedSurfaces: ['a2ui', 'agent'],
    dynamic: false
  };
}
