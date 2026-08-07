import {
  SchemaRef,
  SchemaValidationResult,
  ToolSchemaBinding,
  schemaKey
} from '../contracts/SchemaTypes';

export class SchemaRegistry {
  private readonly bindings: Map<string, ToolSchemaBinding> = new Map<string, ToolSchemaBinding>();

  register(binding: ToolSchemaBinding): void {
    const key = schemaKey(binding.ref);
    if (this.bindings.has(key)) {
      return;
    }
    this.bindings.set(key, binding);
  }

  has(ref: SchemaRef): boolean {
    return this.bindings.has(schemaKey(ref));
  }

  validate(ref: SchemaRef, value: Object): SchemaValidationResult {
    const binding = this.bindings.get(schemaKey(ref));
    if (binding === undefined) {
      // Named legacy schemas are registered progressively. Absence means that
      // the compatibility handler remains the validation authority.
      return { ok: true, code: '', message: '' };
    }
    return binding.validator.validate(value);
  }
}
