export type ToolEffectKind =
  'read_data' |
  'create_draft' |
  'network_access' |
  'external_write' |
  'financial_transaction' |
  'device_control' |
  'background_execution';

export interface ToolEffect {
  kind: ToolEffectKind;
  target: string;
  reversible: boolean;
}

export interface ToolEffectRule {
  toolId: string;
  effects: ToolEffect[];
}

export function cloneToolEffect(effect: ToolEffect): ToolEffect {
  return { kind: effect.kind, target: effect.target, reversible: effect.reversible };
}

export function cloneToolEffects(effects: ToolEffect[]): ToolEffect[] {
  return effects.map((effect: ToolEffect): ToolEffect => cloneToolEffect(effect));
}
