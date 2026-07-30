import { JsonValue } from '../ActionPlanTypes';

export type ActionJsonSchemaType =
  'object' | 'array' | 'string' | 'number' | 'integer' | 'boolean' | 'null';

/**
 * Deliberately small JSON Schema subset used by Action planning.
 *
 * The subset is strict enough for deterministic plan validation while avoiding
 * model-facing keywords that the runtime cannot enforce.
 */
export interface ActionJsonSchema {
  type: ActionJsonSchemaType;
  description?: string;
  properties?: Record<string, ActionJsonSchema>;
  required?: string[];
  additionalProperties?: boolean;
  items?: ActionJsonSchema;
  enum?: JsonValue[];
  minimum?: number;
  maximum?: number;
  minLength?: number;
}

export interface ActionSchemaValidationResult {
  ok: boolean;
  path: string;
  code: string;
  message: string;
}

const MAX_ACTION_SCHEMA_DEPTH: number = 12;

function valid(path: string = '$'): ActionSchemaValidationResult {
  return {
    ok: true,
    path,
    code: '',
    message: ''
  };
}

function invalid(
  path: string,
  code: string,
  message: string
): ActionSchemaValidationResult {
  return {
    ok: false,
    path,
    code,
    message
  };
}

function supportedType(type: string): boolean {
  return type === 'object' || type === 'array' || type === 'string' ||
    type === 'number' || type === 'integer' || type === 'boolean' ||
    type === 'null';
}

function valueRecord(
  value: JsonValue
): Record<string, Object | string | number | boolean | null | undefined> {
  return value as Record<string, Object | string | number | boolean | null | undefined>;
}

function owns(
  record: Record<string, Object | string | number | boolean | null | undefined>,
  key: string
): boolean {
  return Object.keys(record).indexOf(key) >= 0;
}

function enumMatches(expected: JsonValue, actual: JsonValue): boolean {
  if (expected === null || actual === null ||
    typeof expected !== 'object' || typeof actual !== 'object') {
    return expected === actual;
  }
  try {
    return JSON.stringify(expected) === JSON.stringify(actual);
  } catch (_error) {
    return false;
  }
}

function validateEnum(
  schema: ActionJsonSchema,
  value: JsonValue,
  path: string
): ActionSchemaValidationResult {
  if (schema.enum === undefined) {
    return valid(path);
  }
  if (!Array.isArray(schema.enum) || schema.enum.length === 0) {
    return invalid(path, 'ACTION_SCHEMA_ENUM_INVALID', 'Schema enum must not be empty.');
  }
  for (let index = 0; index < schema.enum.length; index++) {
    if (enumMatches(schema.enum[index], value)) {
      return valid(path);
    }
  }
  return invalid(
    path,
    'ACTION_VALUE_NOT_IN_ENUM',
    'Value is not one of the allowed enum values.'
  );
}

function validateObject(
  schema: ActionJsonSchema,
  value: JsonValue,
  path: string,
  depth: number
): ActionSchemaValidationResult {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return invalid(path, 'ACTION_VALUE_TYPE_MISMATCH', 'Expected an object.');
  }
  const record = valueRecord(value);
  const properties = schema.properties === undefined ?
    {} as Record<string, ActionJsonSchema> : schema.properties;
  const required = schema.required === undefined ? [] : schema.required;
  for (let index = 0; index < required.length; index++) {
    if (!owns(record, required[index])) {
      return invalid(
        `${path}/${required[index]}`,
        'ACTION_VALUE_REQUIRED_PROPERTY_MISSING',
        `Required property is missing: ${required[index]}.`
      );
    }
  }
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    const key = keys[index];
    const propertySchema = properties[key];
    if (propertySchema === undefined) {
      if (schema.additionalProperties === false) {
        return invalid(
          `${path}/${key}`,
          'ACTION_VALUE_ADDITIONAL_PROPERTY',
          `Additional property is not allowed: ${key}.`
        );
      }
      continue;
    }
    const propertyValue = record[key] as JsonValue;
    const result = validateActionValue(
      propertySchema,
      propertyValue,
      `${path}/${key}`,
      depth + 1
    );
    if (!result.ok) {
      return result;
    }
  }
  return valid(path);
}

function validateArray(
  schema: ActionJsonSchema,
  value: JsonValue,
  path: string,
  depth: number
): ActionSchemaValidationResult {
  if (!Array.isArray(value)) {
    return invalid(path, 'ACTION_VALUE_TYPE_MISMATCH', 'Expected an array.');
  }
  if (schema.items === undefined) {
    return valid(path);
  }
  for (let index = 0; index < value.length; index++) {
    const result = validateActionValue(
      schema.items,
      value[index] as JsonValue,
      `${path}/${index}`,
      depth + 1
    );
    if (!result.ok) {
      return result;
    }
  }
  return valid(path);
}

function validateString(
  schema: ActionJsonSchema,
  value: JsonValue,
  path: string
): ActionSchemaValidationResult {
  if (typeof value !== 'string') {
    return invalid(path, 'ACTION_VALUE_TYPE_MISMATCH', 'Expected a string.');
  }
  if (schema.minLength !== undefined && value.length < schema.minLength) {
    return invalid(
      path,
      'ACTION_VALUE_STRING_TOO_SHORT',
      'String is shorter than minLength.'
    );
  }
  return valid(path);
}

function validateNumber(
  schema: ActionJsonSchema,
  value: JsonValue,
  path: string,
  integer: boolean
): ActionSchemaValidationResult {
  if (typeof value !== 'number' || !Number.isFinite(value) ||
    (integer && Math.floor(value) !== value)) {
    return invalid(
      path,
      'ACTION_VALUE_TYPE_MISMATCH',
      integer ? 'Expected an integer.' : 'Expected a finite number.'
    );
  }
  if (schema.minimum !== undefined && value < schema.minimum) {
    return invalid(
      path,
      'ACTION_VALUE_NUMBER_TOO_SMALL',
      'Number is smaller than minimum.'
    );
  }
  if (schema.maximum !== undefined && value > schema.maximum) {
    return invalid(
      path,
      'ACTION_VALUE_NUMBER_TOO_LARGE',
      'Number is larger than maximum.'
    );
  }
  return valid(path);
}

export function validateActionValue(
  schema: ActionJsonSchema,
  value: JsonValue,
  path: string = '$',
  depth: number = 0
): ActionSchemaValidationResult {
  if (depth > MAX_ACTION_SCHEMA_DEPTH) {
    return invalid(
      path,
      'ACTION_SCHEMA_DEPTH_EXCEEDED',
      'Schema nesting exceeds the Action limit.'
    );
  }
  const enumResult = validateEnum(schema, value, path);
  if (!enumResult.ok) {
    return enumResult;
  }
  if (schema.type === 'object') {
    return validateObject(schema, value, path, depth);
  }
  if (schema.type === 'array') {
    return validateArray(schema, value, path, depth);
  }
  if (schema.type === 'string') {
    return validateString(schema, value, path);
  }
  if (schema.type === 'number') {
    return validateNumber(schema, value, path, false);
  }
  if (schema.type === 'integer') {
    return validateNumber(schema, value, path, true);
  }
  if (schema.type === 'boolean') {
    return typeof value === 'boolean' ?
      valid(path) :
      invalid(path, 'ACTION_VALUE_TYPE_MISMATCH', 'Expected a boolean.');
  }
  return value === null ?
    valid(path) :
    invalid(path, 'ACTION_VALUE_TYPE_MISMATCH', 'Expected null.');
}

function validateSchemaNode(
  schema: ActionJsonSchema,
  path: string,
  depth: number
): ActionSchemaValidationResult {
  if (schema === null || typeof schema !== 'object' || Array.isArray(schema)) {
    return invalid(path, 'ACTION_SCHEMA_INVALID', 'Schema must be an object.');
  }
  if (depth > MAX_ACTION_SCHEMA_DEPTH) {
    return invalid(
      path,
      'ACTION_SCHEMA_DEPTH_EXCEEDED',
      'Schema nesting exceeds the Action limit.'
    );
  }
  if (typeof schema.type !== 'string' || !supportedType(schema.type)) {
    return invalid(
      `${path}/type`,
      'ACTION_SCHEMA_TYPE_INVALID',
      'Schema type is unsupported.'
    );
  }
  if (schema.description !== undefined &&
    typeof schema.description !== 'string') {
    return invalid(
      `${path}/description`,
      'ACTION_SCHEMA_DESCRIPTION_INVALID',
      'Schema description must be a string.'
    );
  }
  if (schema.minimum !== undefined &&
    (typeof schema.minimum !== 'number' || !Number.isFinite(schema.minimum))) {
    return invalid(
      `${path}/minimum`,
      'ACTION_SCHEMA_MINIMUM_INVALID',
      'Schema minimum must be finite.'
    );
  }
  if (schema.maximum !== undefined &&
    (typeof schema.maximum !== 'number' || !Number.isFinite(schema.maximum))) {
    return invalid(
      `${path}/maximum`,
      'ACTION_SCHEMA_MAXIMUM_INVALID',
      'Schema maximum must be finite.'
    );
  }
  if (schema.minimum !== undefined && schema.maximum !== undefined &&
    schema.minimum > schema.maximum) {
    return invalid(
      path,
      'ACTION_SCHEMA_NUMBER_RANGE_INVALID',
      'Schema minimum exceeds maximum.'
    );
  }
  if (schema.minLength !== undefined &&
    (typeof schema.minLength !== 'number' ||
      !Number.isFinite(schema.minLength) ||
      schema.minLength < 0 ||
      Math.floor(schema.minLength) !== schema.minLength)) {
    return invalid(
      `${path}/minLength`,
      'ACTION_SCHEMA_MIN_LENGTH_INVALID',
      'Schema minLength must be a non-negative integer.'
    );
  }
  if (schema.enum !== undefined &&
    (!Array.isArray(schema.enum) || schema.enum.length === 0)) {
    return invalid(
      `${path}/enum`,
      'ACTION_SCHEMA_ENUM_INVALID',
      'Schema enum must not be empty.'
    );
  }
  if (schema.type === 'object') {
    const properties = schema.properties === undefined ?
      {} as Record<string, ActionJsonSchema> : schema.properties;
    const propertyKeys = Object.keys(properties);
    for (let index = 0; index < propertyKeys.length; index++) {
      const key = propertyKeys[index];
      const result = validateSchemaNode(
        properties[key],
        `${path}/properties/${key}`,
        depth + 1
      );
      if (!result.ok) {
        return result;
      }
    }
    const required = schema.required === undefined ? [] : schema.required;
    const seen: Set<string> = new Set<string>();
    for (let index = 0; index < required.length; index++) {
      const key = required[index];
      if (typeof key !== 'string' || key.length === 0 || seen.has(key) ||
        properties[key] === undefined) {
        return invalid(
          `${path}/required`,
          'ACTION_SCHEMA_REQUIRED_INVALID',
          'Required keys must be unique declared properties.'
        );
      }
      seen.add(key);
    }
  }
  if (schema.type === 'array') {
    if (schema.items === undefined) {
      return invalid(
        `${path}/items`,
        'ACTION_SCHEMA_ITEMS_MISSING',
        'Array schema requires an items schema.'
      );
    }
    return validateSchemaNode(schema.items, `${path}/items`, depth + 1);
  }
  return valid(path);
}

export function validateActionSchema(
  schema: ActionJsonSchema
): ActionSchemaValidationResult {
  return validateSchemaNode(schema, '$', 0);
}

export function cloneActionSchema(schema: ActionJsonSchema): ActionJsonSchema {
  return JSON.parse(JSON.stringify(schema)) as ActionJsonSchema;
}
