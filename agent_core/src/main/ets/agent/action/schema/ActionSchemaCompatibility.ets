import { JsonValue } from '../ActionPlanTypes';
import { ActionJsonSchema } from './ActionJsonSchema';

export interface ActionSchemaPathResult {
  ok: boolean;
  schema: ActionJsonSchema | null;
  code: string;
  message: string;
}

function pathFailure(code: string, message: string): ActionSchemaPathResult {
  return {
    ok: false,
    schema: null,
    code,
    message
  };
}

function decodeToken(token: string): string | null {
  let decoded = '';
  for (let index = 0; index < token.length; index++) {
    const current = token.charAt(index);
    if (current !== '~') {
      decoded += current;
      continue;
    }
    if (index + 1 >= token.length) {
      return null;
    }
    const escaped = token.charAt(index + 1);
    if (escaped === '0') {
      decoded += '~';
    } else if (escaped === '1') {
      decoded += '/';
    } else {
      return null;
    }
    index++;
  }
  return decoded;
}

function canonicalArrayIndex(token: string): boolean {
  if (token.length === 0 || (token.length > 1 && token.charAt(0) === '0')) {
    return false;
  }
  for (let index = 0; index < token.length; index++) {
    const code = token.charCodeAt(index);
    if (code < 48 || code > 57) {
      return false;
    }
  }
  return Number.isSafeInteger(Number(token));
}

export function resolveActionSchemaPath(
  root: ActionJsonSchema,
  pointer: string
): ActionSchemaPathResult {
  if (pointer === '') {
    return {
      ok: true,
      schema: root,
      code: '',
      message: ''
    };
  }
  if (!pointer.startsWith('/')) {
    return pathFailure(
      'ACTION_SCHEMA_POINTER_INVALID',
      'Schema path must be a JSON Pointer.'
    );
  }
  const encoded = pointer.substring(1).split('/');
  let current: ActionJsonSchema = root;
  for (let index = 0; index < encoded.length; index++) {
    const token = decodeToken(encoded[index]);
    if (token === null) {
      return pathFailure(
        'ACTION_SCHEMA_POINTER_INVALID',
        'Schema path contains an invalid JSON Pointer escape.'
      );
    }
    if (current.type === 'object') {
      const properties = current.properties;
      if (properties === undefined || properties[token] === undefined) {
        return pathFailure(
          'ACTION_SCHEMA_PATH_NOT_FOUND',
          `Schema property does not exist: ${token}.`
        );
      }
      current = properties[token];
      continue;
    }
    if (current.type === 'array') {
      if (!canonicalArrayIndex(token) || current.items === undefined) {
        return pathFailure(
          'ACTION_SCHEMA_ARRAY_PATH_INVALID',
          'Schema array path must use a canonical index.'
        );
      }
      current = current.items;
      continue;
    }
    return pathFailure(
      'ACTION_SCHEMA_PATH_PRIMITIVE',
      'Schema path traverses a primitive value.'
    );
  }
  return {
    ok: true,
    schema: current,
    code: '',
    message: ''
  };
}

function jsonEquals(left: JsonValue, right: JsonValue): boolean {
  try {
    return JSON.stringify(left) === JSON.stringify(right);
  } catch (_error) {
    return false;
  }
}

function enumAssignable(
  source: ActionJsonSchema,
  target: ActionJsonSchema
): boolean {
  if (target.enum === undefined) {
    return true;
  }
  if (source.enum === undefined) {
    return false;
  }
  for (let sourceIndex = 0; sourceIndex < source.enum.length; sourceIndex++) {
    let found = false;
    for (let targetIndex = 0; targetIndex < target.enum.length; targetIndex++) {
      if (jsonEquals(source.enum[sourceIndex], target.enum[targetIndex])) {
        found = true;
        break;
      }
    }
    if (!found) {
      return false;
    }
  }
  return true;
}

function numericAssignable(
  source: ActionJsonSchema,
  target: ActionJsonSchema
): boolean {
  if (target.minimum !== undefined &&
    (source.minimum === undefined || source.minimum < target.minimum)) {
    return false;
  }
  if (target.maximum !== undefined &&
    (source.maximum === undefined || source.maximum > target.maximum)) {
    return false;
  }
  return true;
}

function objectAssignable(
  source: ActionJsonSchema,
  target: ActionJsonSchema,
  depth: number
): boolean {
  const sourceProperties = source.properties === undefined ?
    {} as Record<string, ActionJsonSchema> : source.properties;
  const targetProperties = target.properties === undefined ?
    {} as Record<string, ActionJsonSchema> : target.properties;
  const sourceRequired = source.required === undefined ? [] : source.required;
  const targetRequired = target.required === undefined ? [] : target.required;
  for (let index = 0; index < targetRequired.length; index++) {
    const key = targetRequired[index];
    if (sourceRequired.indexOf(key) < 0 ||
      sourceProperties[key] === undefined ||
      targetProperties[key] === undefined ||
      !actionSchemasAssignable(
        sourceProperties[key],
        targetProperties[key],
        depth + 1
      )) {
      return false;
    }
  }
  if (target.additionalProperties === false) {
    if (source.additionalProperties !== false) {
      return false;
    }
    const sourceKeys = Object.keys(sourceProperties);
    for (let index = 0; index < sourceKeys.length; index++) {
      const key = sourceKeys[index];
      if (targetProperties[key] === undefined ||
        !actionSchemasAssignable(
          sourceProperties[key],
          targetProperties[key],
          depth + 1
        )) {
        return false;
      }
    }
  }
  return true;
}

export function actionSchemasAssignable(
  source: ActionJsonSchema,
  target: ActionJsonSchema,
  depth: number = 0
): boolean {
  if (depth > 12 ||
    (source.type !== target.type &&
      !(source.type === 'integer' && target.type === 'number')) ||
    !enumAssignable(source, target)) {
    return false;
  }
  if ((target.type === 'number' || target.type === 'integer') &&
    !numericAssignable(source, target)) {
    return false;
  }
  if (target.type === 'string' &&
    target.minLength !== undefined &&
    (source.minLength === undefined || source.minLength < target.minLength)) {
    return false;
  }
  if (target.type === 'object') {
    return objectAssignable(source, target, depth);
  }
  if (target.type === 'array') {
    return source.items !== undefined &&
      target.items !== undefined &&
      actionSchemasAssignable(source.items, target.items, depth + 1);
  }
  return true;
}

export function actionSchemaPointersOverlap(left: string, right: string): boolean {
  return left === right ||
    left.startsWith(`${right}/`) ||
    right.startsWith(`${left}/`);
}
