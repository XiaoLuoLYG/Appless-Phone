import {
  ActionJsonSchema,
  ActionSchemaValidationResult,
  cloneActionSchema,
  validateActionSchema
} from './ActionJsonSchema';

export interface ActionSchemaRegistration {
  schemaId: string;
  revision: string;
  schema: ActionJsonSchema;
}

export interface ActionSchemaSnapshot {
  schemaId: string;
  revision: string;
  fingerprint: string;
  schema: ActionJsonSchema;
}

interface StoredActionSchema {
  schemaId: string;
  revision: string;
  fingerprint: string;
  schema: ActionJsonSchema;
}

function nonempty(value: string): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function canonicalJsonValue(value: Object | string | number | boolean | null): string {
  if (value === null || typeof value !== 'object') {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    const items: string[] = [];
    for (let index = 0; index < value.length; index++) {
      items.push(canonicalJsonValue(
        value[index] as Object | string | number | boolean | null
      ));
    }
    return `[${items.join(',')}]`;
  }
  const record =
    value as Record<string, Object | string | number | boolean | null>;
  const keys = Object.keys(record).sort();
  const fields: string[] = [];
  for (let index = 0; index < keys.length; index++) {
    fields.push(
      `${JSON.stringify(keys[index])}:${canonicalJsonValue(record[keys[index]])}`
    );
  }
  return `{${fields.join(',')}}`;
}

function schemaField(name: string, value: string): string {
  return `${JSON.stringify(name)}:${value}`;
}

function canonicalSchema(schema: ActionJsonSchema): string {
  const fields: string[] = [
    schemaField('type', JSON.stringify(schema.type))
  ];
  if (schema.description !== undefined) {
    fields.push(schemaField('description', JSON.stringify(schema.description)));
  }
  if (schema.type === 'object') {
    const properties = schema.properties === undefined ?
      {} as Record<string, ActionJsonSchema> : schema.properties;
    const propertyKeys = Object.keys(properties).sort();
    const propertyFields: string[] = [];
    for (let index = 0; index < propertyKeys.length; index++) {
      const key = propertyKeys[index];
      propertyFields.push(schemaField(key, canonicalSchema(properties[key])));
    }
    fields.push(schemaField('properties', `{${propertyFields.join(',')}}`));
    if (schema.required !== undefined) {
      const required = schema.required.slice().sort();
      fields.push(schemaField('required', JSON.stringify(required)));
    }
    if (schema.additionalProperties !== undefined) {
      fields.push(schemaField(
        'additionalProperties',
        JSON.stringify(schema.additionalProperties)
      ));
    }
  }
  if (schema.type === 'array' && schema.items !== undefined) {
    fields.push(schemaField('items', canonicalSchema(schema.items)));
  }
  if (schema.enum !== undefined) {
    fields.push(schemaField(
      'enum',
      canonicalJsonValue(schema.enum as Object)
    ));
  }
  if (schema.minimum !== undefined) {
    fields.push(schemaField('minimum', JSON.stringify(schema.minimum)));
  }
  if (schema.maximum !== undefined) {
    fields.push(schemaField('maximum', JSON.stringify(schema.maximum)));
  }
  if (schema.minLength !== undefined) {
    fields.push(schemaField('minLength', JSON.stringify(schema.minLength)));
  }
  return `{${fields.join(',')}}`;
}

function fingerprintValue(value: string): string {
  let hash: number = 2166136261;
  for (let index = 0; index < value.length; index++) {
    hash = Math.imul(hash ^ value.charCodeAt(index), 16777619) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}

export function actionSchemaFingerprint(
  schemaId: string,
  revision: string,
  schema: ActionJsonSchema
): string {
  return fingerprintValue(
    `${schemaId.length}:${schemaId}${revision.length}:${revision}${canonicalSchema(schema)}`
  );
}

function snapshot(stored: StoredActionSchema): ActionSchemaSnapshot {
  return {
    schemaId: stored.schemaId,
    revision: stored.revision,
    fingerprint: stored.fingerprint,
    schema: cloneActionSchema(stored.schema)
  };
}

export class ActionSchemaCatalog {
  private readonly schemas: Map<string, StoredActionSchema> =
    new Map<string, StoredActionSchema>();

  register(registration: ActionSchemaRegistration): ActionSchemaSnapshot {
    if (registration === null || typeof registration !== 'object' ||
      !nonempty(registration.schemaId) || !nonempty(registration.revision)) {
      throw new Error('Action schema registration identity is invalid.');
    }
    if (this.schemas.has(registration.schemaId)) {
      throw new Error(`Duplicate Action schema id: ${registration.schemaId}.`);
    }
    const validation: ActionSchemaValidationResult =
      validateActionSchema(registration.schema);
    if (!validation.ok) {
      throw new Error(
        `Invalid Action schema ${registration.schemaId} at ${validation.path}: ` +
          `${validation.code}.`
      );
    }
    const schema = cloneActionSchema(registration.schema);
    const stored: StoredActionSchema = {
      schemaId: registration.schemaId,
      revision: registration.revision,
      fingerprint: actionSchemaFingerprint(
        registration.schemaId,
        registration.revision,
        schema
      ),
      schema
    };
    this.schemas.set(stored.schemaId, stored);
    return snapshot(stored);
  }

  find(schemaId: string): ActionSchemaSnapshot | null {
    const stored = this.schemas.get(schemaId);
    return stored === undefined ? null : snapshot(stored);
  }

  describe(schemaIds: string[]): ActionSchemaSnapshot[] {
    const result: ActionSchemaSnapshot[] = [];
    const seen: Set<string> = new Set<string>();
    for (let index = 0; index < schemaIds.length; index++) {
      const schemaId = schemaIds[index];
      if (!nonempty(schemaId) || seen.has(schemaId)) {
        throw new Error(`Invalid or duplicate Action schema id: ${schemaId}.`);
      }
      const stored = this.schemas.get(schemaId);
      if (stored === undefined) {
        throw new Error(`Unknown Action schema id: ${schemaId}.`);
      }
      seen.add(schemaId);
      result.push(snapshot(stored));
    }
    return result;
  }

  size(): number {
    return this.schemas.size;
  }
}
