import { JsonValue } from '../../agent/action/ActionPlanTypes';

export type ToolInputJsonSchemaType =
  'object' | 'array' | 'string' | 'number' | 'integer' | 'boolean' | 'null';

export interface ToolInputJsonSchema {
  type: ToolInputJsonSchemaType;
  description?: string;
  properties?: Record<string, ToolInputJsonSchema>;
  required?: string[];
  additionalProperties?: boolean;
  items?: ToolInputJsonSchema;
  enum?: JsonValue[];
  minimum?: number;
  maximum?: number;
  minLength?: number;
}

export interface ToolInputValidationResult {
  ok: boolean;
  path: string;
  code: string;
  message: string;
}

const MAX_TOOL_INPUT_DEPTH: number = 12;

function valid(path: string = '$'): ToolInputValidationResult {
  return { ok: true, path, code: '', message: '' };
}

function invalid(path: string, code: string, message: string): ToolInputValidationResult {
  return { ok: false, path, code, message };
}

function valueRecord(
  value: JsonValue
): Record<string, Object | string | number | boolean | null | undefined> {
  return value as Record<string, Object | string | number | boolean | null | undefined>;
}

function enumMatches(expected: JsonValue, actual: JsonValue): boolean {
  if (expected === null || actual === null ||
    typeof expected !== 'object' || typeof actual !== 'object') {
    return expected === actual;
  }
  return JSON.stringify(expected) === JSON.stringify(actual);
}

function validateEnum(
  schema: ToolInputJsonSchema,
  value: JsonValue,
  path: string
): ToolInputValidationResult {
  if (schema.enum === undefined) {
    return valid(path);
  }
  for (let index = 0; index < schema.enum.length; index++) {
    if (enumMatches(schema.enum[index], value)) {
      return valid(path);
    }
  }
  return invalid(path, 'TOOL_INPUT_NOT_IN_ENUM', 'Value is not one of the allowed enum values.');
}

function validateObject(
  schema: ToolInputJsonSchema,
  value: JsonValue,
  path: string,
  depth: number
): ToolInputValidationResult {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return invalid(path, 'TOOL_INPUT_TYPE_MISMATCH', 'Expected an object.');
  }
  const record = valueRecord(value);
  const properties = schema.properties === undefined ?
    {} as Record<string, ToolInputJsonSchema> : schema.properties;
  const required = schema.required === undefined ? [] : schema.required;
  const keys = Object.keys(record);
  for (let index = 0; index < required.length; index++) {
    if (keys.indexOf(required[index]) < 0) {
      return invalid(
        path + '/' + required[index],
        'TOOL_INPUT_REQUIRED_PROPERTY_MISSING',
        'Required property is missing: ' + required[index] + '.'
      );
    }
  }
  for (let index = 0; index < keys.length; index++) {
    const key = keys[index];
    const propertySchema = properties[key];
    if (propertySchema === undefined) {
      if (schema.additionalProperties === false) {
        return invalid(
          path + '/' + key,
          'TOOL_INPUT_ADDITIONAL_PROPERTY',
          'Additional property is not allowed: ' + key + '.'
        );
      }
      continue;
    }
    const result = validateToolInputValue(
      propertySchema,
      record[key] as JsonValue,
      path + '/' + key,
      depth + 1
    );
    if (!result.ok) {
      return result;
    }
  }
  return valid(path);
}

function validateArray(
  schema: ToolInputJsonSchema,
  value: JsonValue,
  path: string,
  depth: number
): ToolInputValidationResult {
  if (!Array.isArray(value)) {
    return invalid(path, 'TOOL_INPUT_TYPE_MISMATCH', 'Expected an array.');
  }
  if (schema.items === undefined) {
    return valid(path);
  }
  for (let index = 0; index < value.length; index++) {
    const result = validateToolInputValue(
      schema.items,
      value[index] as JsonValue,
      path + '/' + index.toString(),
      depth + 1
    );
    if (!result.ok) {
      return result;
    }
  }
  return valid(path);
}

function validateString(
  schema: ToolInputJsonSchema,
  value: JsonValue,
  path: string
): ToolInputValidationResult {
  if (typeof value !== 'string') {
    return invalid(path, 'TOOL_INPUT_TYPE_MISMATCH', 'Expected a string.');
  }
  if (schema.minLength !== undefined && value.length < schema.minLength) {
    return invalid(path, 'TOOL_INPUT_STRING_TOO_SHORT', 'String is shorter than minLength.');
  }
  return valid(path);
}

function validateNumber(
  schema: ToolInputJsonSchema,
  value: JsonValue,
  path: string,
  integer: boolean
): ToolInputValidationResult {
  if (typeof value !== 'number' || !Number.isFinite(value) ||
    (integer && !Number.isInteger(value))) {
    return invalid(path, 'TOOL_INPUT_TYPE_MISMATCH', integer ? 'Expected an integer.' : 'Expected a number.');
  }
  if (schema.minimum !== undefined && value < schema.minimum) {
    return invalid(path, 'TOOL_INPUT_NUMBER_TOO_SMALL', 'Number is smaller than minimum.');
  }
  if (schema.maximum !== undefined && value > schema.maximum) {
    return invalid(path, 'TOOL_INPUT_NUMBER_TOO_LARGE', 'Number is larger than maximum.');
  }
  return valid(path);
}

export function validateToolInputValue(
  schema: ToolInputJsonSchema,
  value: JsonValue,
  path: string = '$',
  depth: number = 0
): ToolInputValidationResult {
  if (depth > MAX_TOOL_INPUT_DEPTH) {
    return invalid(path, 'TOOL_INPUT_DEPTH_EXCEEDED', 'Tool input nesting exceeds the limit.');
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
    return typeof value === 'boolean' ? valid(path) :
      invalid(path, 'TOOL_INPUT_TYPE_MISMATCH', 'Expected a boolean.');
  }
  return value === null ? valid(path) :
    invalid(path, 'TOOL_INPUT_TYPE_MISMATCH', 'Expected null.');
}

export function cloneToolInputJsonSchema(schema: ToolInputJsonSchema): ToolInputJsonSchema {
  return JSON.parse(JSON.stringify(schema)) as ToolInputJsonSchema;
}
