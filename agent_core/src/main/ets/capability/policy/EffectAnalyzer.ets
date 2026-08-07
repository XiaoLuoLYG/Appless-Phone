import { ToolCall } from '../contracts/ToolCall';
import { ToolEffect, cloneToolEffects } from '../contracts/ToolEffect';
import { ToolSpec } from '../contracts/ToolSpec';

export class EffectAnalyzer {
  analyze(_call: ToolCall, spec: ToolSpec): ToolEffect[] {
    return cloneToolEffects(spec.declaredEffects);
  }
}
