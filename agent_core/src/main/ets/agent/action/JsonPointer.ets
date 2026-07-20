import { JsonValue } from './ActionPlanTypes';

type JsonRecord = Record<string, JsonValue | undefined>;

interface PointerTokensResult {
  ok: boolean;
  tokens: string[];
  errorCode: string;
  message: string;
}

interface JsonInspectionResult {
  ok: boolean;
  errorCode: string;
  message: string;
}

export interface JsonPointerResult {
  ok: boolean;
  value: JsonValue | undefined;
  errorCode: string;
  message: string;
}

export interface JsonPointerSetResult {
  ok: boolean;
  value: JsonValue | undefined;
  errorCode: string;
  message: string;
}

function pointerFailure(code: string, message: string): JsonPointerResult {
  return {
    ok: false,
    value: undefined,
    errorCode: code,
    message: message
  };
}

function setFailure(code: string, message: string): JsonPointerSetResult {
  return {
    ok: false,
    value: undefined,
    errorCode: code,
    message: message
  };
}

function decodeToken(token: string): PointerTokensResult {
  let decoded = '';
  for (let index = 0; index < token.length; index++) {
    const character = token.charAt(index);
    if (character !== '~') {
      decoded += character;
      continue;
    }
    if (index + 1 >= token.length) {
      return invalidPointer('JSON Pointer contains an incomplete escape.');
    }
    const escaped = token.charAt(index + 1);
    if (escaped === '0') {
      decoded += '~';
    } else if (escaped === '1') {
      decoded += '/';
    } else {
      return invalidPointer('JSON Pointer contains an invalid escape.');
    }
    index += 1;
  }
  if (isPrototypeSegment(decoded)) {
    return {
      ok: false,
      tokens: [],
      errorCode: 'JSON_POINTER_PROTOTYPE',
      message: 'JSON Pointer prototype segments are forbidden.'
    };
  }
  return {
    ok: true,
    tokens: [decoded],
    errorCode: '',
    message: ''
  };
}

function invalidPointer(message: string): PointerTokensResult {
  return {
    ok: false,
    tokens: [],
    errorCode: 'JSON_POINTER_INVALID',
    message: message
  };
}

function pointerTokens(pointer: string): PointerTokensResult {
  if (pointer === '') {
    return {
      ok: true,
      tokens: [],
      errorCode: '',
      message: ''
    };
  }
  if (!pointer.startsWith('/')) {
    return invalidPointer('JSON Pointer must be empty or start with /.');
  }
  const encoded = pointer.substring(1).split('/');
  const tokens: string[] = [];
  for (let index = 0; index < encoded.length; index++) {
    const decoded = decodeToken(encoded[index]);
    if (!decoded.ok) {
      return decoded;
    }
    tokens.push(decoded.tokens[0]);
  }
  return {
    ok: true,
    tokens: tokens,
    errorCode: '',
    message: ''
  };
}

function isPrototypeSegment(segment: string): boolean {
  return segment === '__proto__' ||
    segment === 'prototype' ||
    segment === 'constructor';
}

function canonicalArrayIndex(token: string): number {
  if (token.length === 0 || (token.length > 1 && token.charAt(0) === '0')) {
    return -1;
  }
  for (let index = 0; index < token.length; index++) {
    const code = token.charCodeAt(index);
    if (code < 48 || code > 57) {
      return -1;
    }
  }
  const value = Number(token);
  if (!Number.isSafeInteger(value) || value < 0) {
    return -1;
  }
  return value;
}

function inspectJson(value: JsonValue | undefined, active: Set<Object>): JsonInspectionResult {
  if (value === null || typeof value === 'string' || typeof value === 'boolean') {
    return {
      ok: true,
      errorCode: '',
      message: ''
    };
  }
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      return {
        ok: false,
        errorCode: 'JSON_VALUE_INVALID',
        message: 'JSON numbers must be finite.'
      };
    }
    return {
      ok: true,
      errorCode: '',
      message: ''
    };
  }
  if (value === undefined || typeof value !== 'object') {
    return {
      ok: false,
      errorCode: 'JSON_VALUE_INVALID',
      message: 'Value is not JSON-compatible.'
    };
  }
  const objectValue = value as Object;
  if (active.has(objectValue)) {
    return {
      ok: false,
      errorCode: 'JSON_VALUE_INVALID',
      message: 'Cyclic JSON values are not allowed.'
    };
  }
  active.add(objectValue);
  const keys = Object.keys(objectValue);
  const record = objectValue as JsonRecord;
  for (let index = 0; index < keys.length; index++) {
    const nested = inspectJson(record[keys[index]], active);
    if (!nested.ok) {
      active.delete(objectValue);
      return nested;
    }
  }
  active.delete(objectValue);
  return {
    ok: true,
    errorCode: '',
    message: ''
  };
}

export function inspectJsonValue(value: JsonValue | undefined): JsonInspectionResult {
  try {
    return inspectJson(value, new Set<Object>());
  } catch (_error) {
    return {
      ok: false,
      errorCode: 'JSON_VALUE_INVALID',
      message: 'JSON value inspection failed.'
    };
  }
}

export function cloneJsonValue(value: JsonValue): JsonPointerResult {
  const inspection = inspectJsonValue(value);
  if (!inspection.ok) {
    return pointerFailure(inspection.errorCode, inspection.message);
  }
  try {
    return {
      ok: true,
      value: JSON.parse(JSON.stringify(value)) as JsonValue,
      errorCode: '',
      message: ''
    };
  } catch (_error) {
    return pointerFailure('JSON_VALUE_INVALID', 'JSON value cloning failed.');
  }
}

export function validateJsonPointer(pointer: string): JsonPointerResult {
  try {
    const parsed = pointerTokens(pointer);
    if (!parsed.ok) {
      return pointerFailure(parsed.errorCode, parsed.message);
    }
    return {
      ok: true,
      value: undefined,
      errorCode: '',
      message: ''
    };
  } catch (_error) {
    return pointerFailure('JSON_POINTER_INVALID', 'JSON Pointer validation failed.');
  }
}

function ownValue(parent: Object, token: string): JsonPointerResult {
  if (Object.keys(parent).indexOf(token) < 0) {
    return pointerFailure('JSON_POINTER_MISSING', 'JSON Pointer member does not exist.');
  }
  const record = parent as JsonRecord;
  return {
    ok: true,
    value: record[token],
    errorCode: '',
    message: ''
  };
}

export function resolveJsonPointer(document: JsonValue, pointer: string): JsonPointerResult {
  try {
    const parsed = pointerTokens(pointer);
    if (!parsed.ok) {
      return pointerFailure(parsed.errorCode, parsed.message);
    }
    let current: JsonValue = document;
    for (let index = 0; index < parsed.tokens.length; index++) {
      const token = parsed.tokens[index];
      if (Array.isArray(current)) {
        const arrayIndex = canonicalArrayIndex(token);
        if (arrayIndex < 0) {
          return pointerFailure(
            'JSON_POINTER_INVALID',
            'JSON Pointer array indexes must be canonical non-negative integers.'
          );
        }
        const selected = ownValue(current, token);
        if (!selected.ok) {
          return selected;
        }
        current = selected.value as JsonValue;
      } else if (current !== null && typeof current === 'object') {
        const selected = ownValue(current as Object, token);
        if (!selected.ok) {
          return selected;
        }
        current = selected.value as JsonValue;
      } else {
        return pointerFailure(
          'JSON_POINTER_TARGET_TYPE',
          'JSON Pointer cannot traverse a primitive value.'
        );
      }
    }
    return {
      ok: true,
      value: current,
      errorCode: '',
      message: ''
    };
  } catch (_error) {
    return pointerFailure('JSON_POINTER_FAILED', 'JSON Pointer resolution failed.');
  }
}

export function setJsonPointer(
  document: JsonValue,
  pointer: string,
  replacement: JsonValue
): JsonPointerSetResult {
  try {
    const parsed = pointerTokens(pointer);
    if (!parsed.ok) {
      return setFailure(parsed.errorCode, parsed.message);
    }
    const replacementClone = cloneJsonValue(replacement);
    if (!replacementClone.ok) {
      return setFailure(replacementClone.errorCode, replacementClone.message);
    }
    if (parsed.tokens.length === 0) {
      return {
        ok: true,
        value: replacementClone.value,
        errorCode: '',
        message: ''
      };
    }
    const documentClone = cloneJsonValue(document);
    if (!documentClone.ok) {
      return setFailure(documentClone.errorCode, documentClone.message);
    }
    let parent = documentClone.value as JsonValue;
    for (let index = 0; index < parsed.tokens.length - 1; index++) {
      const selected = resolveJsonPointer(parent, '/' + escapeToken(parsed.tokens[index]));
      if (!selected.ok) {
        return setFailure(selected.errorCode, selected.message);
      }
      parent = selected.value as JsonValue;
    }
    const target = parsed.tokens[parsed.tokens.length - 1];
    if (Array.isArray(parent)) {
      const arrayIndex = canonicalArrayIndex(target);
      if (arrayIndex < 0) {
        return setFailure(
          'JSON_POINTER_INVALID',
          'JSON Pointer array indexes must be canonical non-negative integers.'
        );
      }
      if (arrayIndex >= parent.length) {
        return setFailure('JSON_POINTER_MISSING', 'JSON Pointer array target does not exist.');
      }
      parent[arrayIndex] = replacementClone.value as JsonValue;
    } else if (parent !== null && typeof parent === 'object') {
      const record = parent as JsonRecord;
      record[target] = replacementClone.value;
    } else {
      return setFailure(
        'JSON_POINTER_TARGET_TYPE',
        'JSON Pointer target parent must be an object or array.'
      );
    }
    return {
      ok: true,
      value: documentClone.value,
      errorCode: '',
      message: ''
    };
  } catch (_error) {
    return setFailure('JSON_POINTER_FAILED', 'JSON Pointer assignment failed.');
  }
}

function escapeToken(token: string): string {
  return token.replace(/~/g, '~0').replace(/\//g, '~1');
}
