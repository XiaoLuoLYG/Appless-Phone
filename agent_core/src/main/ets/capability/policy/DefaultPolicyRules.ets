import { ToolEffect } from '../contracts/ToolEffect';

export function effectsRequireApproval(effects: ToolEffect[]): boolean {
  return effects.some((effect: ToolEffect): boolean =>
    effect.kind === 'external_write' ||
    effect.kind === 'financial_transaction' ||
    effect.kind === 'device_control' ||
    effect.kind === 'background_execution'
  );
}
