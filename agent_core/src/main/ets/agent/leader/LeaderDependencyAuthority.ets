import { JsonValue } from '../action/ActionPlanTypes';
import { cloneJsonValue } from '../action/JsonPointer';

const MAX_AUTHORITY_DEPTH: number = 12;
const MAX_AUTHORITY_NODES: number = 512;

interface AuthorityTraversalState {
  nodes: number;
  entityRefs: Set<string>;
}

function containsEntityRef(
  value: JsonValue,
  depth: number,
  state: AuthorityTraversalState
): boolean {
  if (depth > MAX_AUTHORITY_DEPTH || state.nodes >= MAX_AUTHORITY_NODES) {
    return false;
  }
  state.nodes++;
  if (typeof value === 'string') {
    return state.entityRefs.has(value);
  }
  if (value === null || typeof value === 'number' || typeof value === 'boolean') {
    return false;
  }
  if (Array.isArray(value)) {
    for (let index = 0; index < value.length; index++) {
      if (containsEntityRef(value[index] as JsonValue, depth + 1, state)) {
        return true;
      }
    }
    return false;
  }
  const keys: string[] = Object.keys(value);
  const record = value as Record<string, JsonValue | undefined>;
  for (let index = 0; index < keys.length; index++) {
    const nested: JsonValue | undefined = record[keys[index]];
    if (nested !== undefined && containsEntityRef(nested, depth + 1, state)) {
      return true;
    }
  }
  return false;
}

export function leaderInputHasEntityAuthority(input: Object, entityRefs: string[]): boolean {
  const refs: Set<string> = new Set<string>();
  for (let index = 0; index < entityRefs.length; index++) {
    const value: string = entityRefs[index];
    if (typeof value === 'string' && value.trim().length > 0) {
      refs.add(value);
    }
  }
  if (refs.size === 0) {
    return false;
  }
  const cloned = cloneJsonValue(input as JsonValue);
  if (!cloned.ok || cloned.value === undefined) {
    return false;
  }
  return containsEntityRef(cloned.value, 0, { nodes: 0, entityRefs: refs });
}
