export interface SchemaRef {
  id: string;
  version: string;
}

export interface SchemaValidationResult {
  ok: boolean;
  code: string;
  message: string;
}

export interface ToolSchemaValidator {
  validate(value: Object): SchemaValidationResult;
}

export interface ToolSchemaBinding {
  ref: SchemaRef;
  validator: ToolSchemaValidator;
}

export function cloneSchemaRef(ref: SchemaRef): SchemaRef {
  return { id: ref.id, version: ref.version };
}

export function schemaKey(ref: SchemaRef): string {
  return ref.id + '@' + ref.version;
}
