import { SchemaRegistry } from '../registry/SchemaRegistry';
import { ToolResult } from '../contracts/ToolResult';
import { ToolSpec } from '../contracts/ToolSpec';

export interface ToolResultValidation {
  ok: boolean;
  code: string;
  message: string;
}

export class ToolResultValidator {
  private readonly schemas: SchemaRegistry;

  constructor(schemas: SchemaRegistry) {
    this.schemas = schemas;
  }

  validate(spec: ToolSpec, result: ToolResult): ToolResultValidation {
    if (result.toolId !== spec.id || result.toolVersion !== spec.version) {
      return { ok: false, code: 'RESULT_IDENTITY_MISMATCH', message: 'Backend returned a result for another tool.' };
    }
    const schemaResult = this.schemas.validate(spec.outputSchemaRef, result.data);
    if (!schemaResult.ok) {
      return { ok: false, code: schemaResult.code, message: schemaResult.message };
    }
    for (let effectIndex = 0; effectIndex < result.observedEffects.length; effectIndex++) {
      const observed = result.observedEffects[effectIndex];
      const declared = spec.declaredEffects.some((effect): boolean => effect.kind === observed.kind);
      if (!declared) {
        return {
          ok: false,
          code: 'RESULT_EFFECT_UNDECLARED',
          message: 'Backend reported an effect that was not declared by ToolSpec.'
        };
      }
    }
    if (result.status === 'success' && spec.idempotency === 'non_idempotent') {
      const hasReceipt = result.sources.some((source): boolean =>
        source.receipt !== undefined && source.receipt.trim().length > 0
      );
      if (!hasReceipt) {
        return {
          ok: false,
          code: 'RESULT_RECEIPT_MISSING',
          message: 'Non-idempotent success requires a provider receipt or durable operation ID.'
        };
      }
    }
    return { ok: true, code: '', message: '' };
  }
}
