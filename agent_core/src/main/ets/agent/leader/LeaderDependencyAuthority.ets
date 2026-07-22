import { JsonValue } from '../action/ActionPlanTypes';
import { cloneJsonValue } from '../action/JsonPointer';
import { ObservationDigest } from '../message/AgentMessage';

interface LeaderDependencyContract {
  sourceToolIds: string[];
}

// This is a dependency contract, not a second tool registry. Only tools whose
// provider call consumes an earlier entity identity may run after round one.
function dependencyContract(toolId: string): LeaderDependencyContract | null {
  if (toolId === 'maps.place.details') {
    return {
      sourceToolIds: ['maps.place.search']
    };
  }
  if (toolId === 'mail.thread.read') {
    return {
      sourceToolIds: ['mail.search']
    };
  }
  if (toolId === 'gmail.thread.read') {
    return {
      sourceToolIds: ['gmail.mail.search']
    };
  }
  return null;
}

function inputString(values: Record<string, JsonValue | undefined>, key: string): string {
  const value: JsonValue | undefined = values[key];
  return typeof value === 'string' ? value.trim() : '';
}

function mapsPlaceIdentityAuthorized(
  values: Record<string, JsonValue | undefined>,
  refs: Set<string>
): boolean {
  // ToolGatewayClient consumes placeId first and falls back to id only when
  // placeId is empty. Authorization must validate that exact resolved value.
  const placeId: string = inputString(values, 'placeId');
  const consumed: string = placeId.length > 0 ? placeId : inputString(values, 'id');
  return consumed.length > 0 && refs.has(consumed);
}

function optionalIdentityAuthorized(value: string, refs: Set<string>): boolean {
  return value.length === 0 || refs.has(value);
}

function mailIdentityAuthorized(
  values: Record<string, JsonValue | undefined>,
  refs: Set<string>,
  gmailOnly: boolean
): boolean {
  const suppliedProvider: string = inputString(values, 'provider').toLowerCase();
  if (gmailOnly && suppliedProvider.length > 0 && suppliedProvider !== 'gmail') {
    return false;
  }
  const provider: string = gmailOnly ? 'gmail' : suppliedProvider;
  if (provider !== 'gmail' && provider !== 'qq') {
    return false;
  }
  const threadId: string = inputString(values, 'threadId');
  const messageId: string = inputString(values, 'messageId');
  const consumedIdentity: string = provider === 'gmail' ? threadId : messageId;
  const requestKey: string = inputString(values, 'requestKey');
  if (consumedIdentity.length === 0 || requestKey !== provider + ':' + consumedIdentity ||
    !refs.has(consumedIdentity) || !refs.has(requestKey)) {
    return false;
  }
  // The provider response matcher also consumes either optional identity when
  // present, so neither may be used as an unrelated real-ref decoy.
  return optionalIdentityAuthorized(threadId, refs) &&
    optionalIdentityAuthorized(messageId, refs);
}

export function leaderInputHasEntityAuthority(
  toolId: string,
  input: Object,
  observations: ObservationDigest[]
): boolean {
  const contract: LeaderDependencyContract | null = dependencyContract(toolId);
  if (contract === null) {
    return false;
  }
  const refs: Set<string> = new Set<string>();
  for (let index = 0; index < observations.length; index++) {
    const observation: ObservationDigest = observations[index];
    if ((observation.status !== 'success' && observation.status !== 'partial') ||
      contract.sourceToolIds.indexOf(observation.toolId) < 0) {
      continue;
    }
    for (let refIndex = 0; refIndex < observation.entityRefs.length; refIndex++) {
      const value: string = observation.entityRefs[refIndex];
      if (typeof value === 'string' && value.trim().length > 0) {
        refs.add(value.trim());
      }
    }
  }
  if (refs.size === 0) {
    return false;
  }
  const cloned = cloneJsonValue(input as JsonValue);
  if (!cloned.ok || cloned.value === undefined) {
    return false;
  }
  if (cloned.value === null || typeof cloned.value !== 'object' || Array.isArray(cloned.value)) {
    return false;
  }
  const values = cloned.value as Record<string, JsonValue | undefined>;
  if (toolId === 'maps.place.details') {
    return mapsPlaceIdentityAuthorized(values, refs);
  }
  if (toolId === 'mail.thread.read') {
    return mailIdentityAuthorized(values, refs, false);
  }
  if (toolId === 'gmail.thread.read') {
    return mailIdentityAuthorized(values, refs, true);
  }
  return false;
}
