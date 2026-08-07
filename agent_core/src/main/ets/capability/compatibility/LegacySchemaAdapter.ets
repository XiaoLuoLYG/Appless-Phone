import { SchemaValidationResult, ToolSchemaValidator } from '../contracts/SchemaTypes';

export class LegacySchemaAdapter implements ToolSchemaValidator {
  validate(_value: Object): SchemaValidationResult {
    return { ok: true, code: '', message: '' };
  }
}
