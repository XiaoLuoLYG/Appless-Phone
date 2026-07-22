import { multiAgentTurnEvidence } from './multi-agent-smoke-evidence.mjs';

function objectArgs(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function positiveHotelId(args) {
  return Number.isInteger(args.hotelId) && args.hotelId > 0;
}

function validIsoDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function validPositiveInteger(value, minimum = 1) {
  return Number.isInteger(value) && value >= minimum;
}

function bookingUrlEvidence(args) {
  const evidence = {
    hostValid: false,
    pathValid: false,
    hotelIdMatches: false,
    datesValid: false,
    occupancyValid: false,
    argsValid: false
  };
  if (typeof args.bookingUrl !== 'string' || args.bookingUrl.trim().length === 0) {
    return evidence;
  }
  let url;
  try {
    url = new URL(args.bookingUrl);
  } catch (_error) {
    return evidence;
  }
  const queryKeys = [...url.searchParams.keys()];
  if (new Set(queryKeys).size !== queryKeys.length) {
    return evidence;
  }
  const authorityMatch = /^https:\/\/([^\/?#]+)/i.exec(args.bookingUrl.trim());
  const authority = authorityMatch === null ? '' : authorityMatch[1].toLowerCase();
  evidence.hostValid = url.protocol === 'https:' &&
    authority === 'rollinggo.cn' &&
    url.hostname === 'rollinggo.cn' &&
    url.port.length === 0 &&
    url.username.length === 0 &&
    url.password.length === 0;
  evidence.pathValid = url.pathname === '/pages/hotel/detail/index';
  const urlHotelIdText = url.searchParams.get('id') || '';
  evidence.hotelIdMatches = /^[1-9]\d*$/.test(urlHotelIdText) &&
    positiveHotelId(args) && urlHotelIdText === args.hotelId.toString();
  const checkInDate = url.searchParams.get('checkInDate') || '';
  const checkOutDate = url.searchParams.get('checkOutDate') || '';
  evidence.datesValid = validIsoDate(checkInDate) &&
    validIsoDate(checkOutDate) &&
    checkOutDate > checkInDate;
  const parseCount = (name) => {
    const value = url.searchParams.get(name) || '';
    return /^\d+$/.test(value) ? Number(value) : Number.NaN;
  };
  const roomCount = parseCount('roomCount');
  const adultCount = parseCount('adultCount');
  const childCount = parseCount('childCount');
  evidence.occupancyValid = validPositiveInteger(roomCount) &&
    validPositiveInteger(adultCount) &&
    validPositiveInteger(childCount, 0);
  evidence.argsValid = evidence.hostValid && evidence.pathValid &&
    evidence.hotelIdMatches && evidence.datesValid && evidence.occupancyValid;
  return evidence;
}

export function hotelActionEvidenceFromLogs(logText) {
  let latest = null;
  for (const line of String(logText || '').split('\n')) {
    const marker = '[AIPhone][HotelHomeActionEvidence] evidence=';
    const markerIndex = line.indexOf(marker);
    if (markerIndex < 0) {
      continue;
    }
    let decoded = line.slice(markerIndex + marker.length).trim();
    try {
      decoded = JSON.parse(decoded);
      if (typeof decoded === 'string') {
        decoded = JSON.parse(decoded);
      }
      if (decoded !== null && typeof decoded === 'object' && !Array.isArray(decoded)) {
        latest = decoded;
      }
    } catch (_error) {}
  }
  return latest || { surfaceId: '', actions: [] };
}

export function hasPopulatedHotelActionEvidence(evidence) {
  return typeof evidence?.surfaceId === 'string' &&
    evidence.surfaceId.length > 0 &&
    Array.isArray(evidence.actions) &&
    evidence.actions.length > 0;
}

export function hotelToolLifecycleFromLogs(logText) {
  const callingBySurface = new Map();
  const hotelDocuments = [];
  const providerRequests = [];
  const providerResponses = [];
  const readyEvents = [];
  const lines = String(logText || '').split('\n');
  lines.forEach((line, index) => {
    const surface = /\[AIPhone\]\[A2uiHomeSurfaceUpdate\][^\n]*surfaceId=([^ \n]+)[^\n]*status=([^ \n]+)/.exec(line);
    if (surface !== null) {
      if (surface[2] === 'calling_tool') {
        callingBySurface.set(surface[1], index);
      } else if (surface[2] === 'ready') {
        readyEvents.push({ surfaceId: surface[1], index });
      }
    }
    const request = /\[AIPhone\]\[RollingGoHotelRequest] operation=(searchHotels|getHotelDetail)\s*$/.exec(line.trim());
    if (request !== null) {
      providerRequests.push({ operation: request[1], index });
    }
    const response = /\[AIPhone\]\[RollingGoHotelResponse] operation=(searchHotels|getHotelDetail) provider=RollingGo status=(success|partial|empty) sources=(\d+)\s*$/.exec(line.trim());
    if (response !== null && Number.parseInt(response[3], 10) > 0) {
      providerResponses.push({
        operation: response[1],
        status: response[2],
        sources: Number.parseInt(response[3], 10),
        index
      });
    }
    const document = /\[AIPhone\]\[HtmlHomeDocument\][^\n]*source=tool[^\n]*kind=hotel[^\n]*chars=(\d+)[^\n]*blocks=(\d+)/.exec(line);
    if (document !== null &&
      Number.parseInt(document[1], 10) > 0 &&
      Number.parseInt(document[2], 10) > 0) {
      hotelDocuments.push({
        index,
        chars: Number.parseInt(document[1], 10),
        blocks: Number.parseInt(document[2], 10)
      });
    }
  });
  let completed;
  let completedProvider;
  let completedDocument;
  for (let readyOffset = readyEvents.length - 1; readyOffset >= 0; readyOffset -= 1) {
    const ready = readyEvents[readyOffset];
    const callingIndex = callingBySurface.get(ready.surfaceId);
    if (callingIndex === undefined) {
      continue;
    }
    const document = hotelDocuments.find((candidate) =>
      candidate.index > callingIndex && candidate.index < ready.index);
    if (document === undefined) {
      continue;
    }
    const response = providerResponses.find((candidate) =>
      candidate.index > callingIndex && candidate.index < document.index &&
      providerRequests.some((request) => request.operation === candidate.operation &&
        request.index > callingIndex && request.index < candidate.index));
    if (response === undefined) {
      continue;
    }
    const request = providerRequests.find((candidate) =>
      candidate.operation === response.operation &&
      candidate.index > callingIndex && candidate.index < response.index);
    completed = ready;
    completedProvider = { request, response };
    completedDocument = document;
    break;
  }
  return {
    requested: callingBySurface.size > 0,
    ok: completed !== undefined,
    surfaceId: completed?.surfaceId || '',
    operation: completedProvider?.response.operation || '',
    providerResponse: completedProvider !== undefined,
    sources: completedProvider?.response.sources || 0,
    blocks: completedDocument?.blocks || 0,
    requestIndex: completedProvider?.request.index ?? -1,
    responseIndex: completedProvider?.response.index ?? -1,
    documentIndex: completedDocument?.index ?? -1,
    readyIndex: completed?.index ?? -1
  };
}

export function hotelDetailLifecycleFromLogs(logText) {
  return hotelToolLifecycleFromLogs(logText);
}

export function hotelMultiAgentSearchEvidence(logText) {
  const lifecycle = multiAgentTurnEvidence(logText, {
    expectedToolIds: ['hotel.search']
  });
  const rawProvider = hotelToolLifecycleFromLogs(logText);
  const lines = String(logText || '').split('\n');
  let finalUiIndex = -1;
  if (lifecycle.finalUiSurfaceId) {
    const escapedSurface = lifecycle.finalUiSurfaceId.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const finalUiPattern = new RegExp(
      `\\[AIPhone\\]\\[MultiAgentUiResult][^\\n]*surface=${escapedSurface}[^\\n]*state=result(?:\\s|$)`
    );
    finalUiIndex = lines.findIndex((line) => finalUiPattern.test(line));
  }
  const orderedProviderChain = rawProvider.ok &&
    rawProvider.operation === 'searchHotels' &&
    rawProvider.surfaceId === lifecycle.surfaceId &&
    rawProvider.requestIndex < rawProvider.responseIndex &&
    rawProvider.responseIndex < rawProvider.documentIndex &&
    rawProvider.documentIndex < rawProvider.readyIndex &&
    rawProvider.readyIndex < lifecycle.terminalIndex &&
    rawProvider.documentIndex < finalUiIndex &&
    finalUiIndex < lifecycle.terminalIndex;
  const provider = {
    ...rawProvider,
    rawSurfaceId: rawProvider.surfaceId
  };
  return {
    ok: lifecycle.ok && orderedProviderChain && provider.blocks > 0 &&
      lifecycle.surfaceId === lifecycle.finalUiSurfaceId,
    lifecycle,
    provider
  };
}

export function hasSafeHotelSystemIntentOpen(logText, expectedScheme) {
  if (expectedScheme !== 'petalmaps') {
    return false;
  }
  return new RegExp(
    `\\[AIPhone\\]\\[A2uiHomeOpenUrl\\] ok=true scheme=${expectedScheme} chars=\\d+`
  ).test(String(logText || ''));
}

export function foregroundBundleFromAbilityDump(output) {
  const missions = String(output || '').split(/(?=\s*Mission ID #)/);
  const foreground = missions.find((mission) =>
    /\bstate #FOREGROUND\b/.test(mission) || /\bapp state #FOREGROUND\b/.test(mission));
  if (foreground === undefined) {
    return '';
  }
  const match = /\bbundle name \[([^\]]+)\]/.exec(foreground);
  return match === null ? '' : match[1].trim();
}

export function isExpectedHotelSystemBundle(actionId, bundleName) {
  if (typeof bundleName !== 'string' ||
    bundleName.length === 0 ||
    bundleName === 'com.example.aiphonedemo') {
    return false;
  }
  return actionId === 'hotel.navigate' && /(?:^|[._-])maps?(?:[._-]|$)/i.test(bundleName);
}

export function shouldRetryHotelReturnToApp(bundleName, backPressCount, maxBackPresses = 3) {
  return bundleName !== 'com.example.aiphonedemo' &&
    Number.isInteger(backPressCount) &&
    Number.isInteger(maxBackPresses) &&
    backPressCount >= 0 &&
    maxBackPresses > 0 &&
    backPressCount < maxBackPresses;
}

function sanitizeAction(action) {
  const actionId = typeof action?.id === 'string' ? action.id : '';
  const args = objectArgs(action?.args) ? action.args : {};
  const argsObject = objectArgs(action?.args);
  const hotelIdPositive = argsObject && positiveHotelId(args);
  const evidence = {
    actionId,
    argsObject,
    hotelIdPositive,
    argsValid: false
  };
  if (actionId === 'hotel.navigate') {
    evidence.latitudeValid = Number.isFinite(args.latitude) && args.latitude >= -90 && args.latitude <= 90;
    evidence.longitudeValid = Number.isFinite(args.longitude) && args.longitude >= -180 && args.longitude <= 180;
    evidence.coordinatesValid = evidence.latitudeValid && evidence.longitudeValid;
    evidence.argsValid = hotelIdPositive && evidence.coordinatesValid;
  } else if (actionId === 'hotel.booking.open') {
    Object.assign(evidence, bookingUrlEvidence(args));
  } else if (actionId === 'hotel.detail') {
    evidence.clickLabel = typeof action?.label === 'string' ? action.label.trim() : '';
    evidence.argsValid = hotelIdPositive;
  }
  return evidence;
}

const HOTEL_ACTION_PATTERN = /^hotel\.(?:detail|navigate|booking\.open)$/;

export function hotelSearchActionEvidence(surfaceId, actions) {
  const safeActions = Array.isArray(actions) ? actions : [];
  return {
    surfaceId: typeof surfaceId === 'string' ? surfaceId : '',
    actions: safeActions
      .filter((action) => HOTEL_ACTION_PATTERN.test(String(action?.id || '')))
      .map(sanitizeAction)
  };
}

function statusFor(actions, actionId) {
  const matches = actions.filter((action) => action.actionId === actionId);
  if (matches.length === 0) {
    return { status: 'hidden', count: 0 };
  }
  const valid = matches.every((action) => action.argsValid === true);
  return { status: valid ? 'visible' : 'invalid', count: matches.length };
}

function sanitizeCollectedAction(action) {
  const actionId = typeof action?.actionId === 'string' ? action.actionId : '';
  const sanitized = {
    actionId,
    argsObject: action?.argsObject === true,
    hotelIdPositive: action?.hotelIdPositive === true,
    argsValid: false
  };
  if (actionId === 'hotel.navigate') {
    sanitized.latitudeValid = action?.latitudeValid === true;
    sanitized.longitudeValid = action?.longitudeValid === true;
    sanitized.coordinatesValid = action?.coordinatesValid === true;
    sanitized.argsValid = action?.argsValid === true &&
      sanitized.argsObject && sanitized.hotelIdPositive &&
      sanitized.latitudeValid && sanitized.longitudeValid && sanitized.coordinatesValid;
  } else if (actionId === 'hotel.booking.open') {
    sanitized.hostValid = action?.hostValid === true;
    sanitized.pathValid = action?.pathValid === true;
    sanitized.hotelIdMatches = action?.hotelIdMatches === true;
    sanitized.datesValid = action?.datesValid === true;
    sanitized.occupancyValid = action?.occupancyValid === true;
    sanitized.argsValid = action?.argsValid === true && sanitized.argsObject &&
      sanitized.hotelIdPositive && sanitized.hostValid && sanitized.pathValid &&
      sanitized.hotelIdMatches && sanitized.datesValid && sanitized.occupancyValid;
  } else if (actionId === 'hotel.detail') {
    sanitized.clickLabel = typeof action?.clickLabel === 'string' ? action.clickLabel.trim() : '';
    sanitized.argsValid = action?.argsValid === true && sanitized.argsObject && sanitized.hotelIdPositive;
  }
  return sanitized;
}

export function validateHotelSearchActionEvidence(evidence) {
  const actions = Array.isArray(evidence?.actions)
    ? evidence.actions.filter((action) => HOTEL_ACTION_PATTERN.test(String(action?.actionId || '')))
      .map(sanitizeCollectedAction)
    : [];
  const detail = statusFor(actions, 'hotel.detail');
  const navigation = statusFor(actions, 'hotel.navigate');
  const booking = statusFor(actions, 'hotel.booking.open');
  return {
    ok: typeof evidence?.surfaceId === 'string' && evidence.surfaceId.trim().length > 0 &&
      detail.status === 'visible' && navigation.status !== 'invalid' && booking.status === 'hidden',
    surfaceId: typeof evidence?.surfaceId === 'string' ? evidence.surfaceId : '',
    detail,
    navigation,
    booking,
    actions
  };
}

export function validateHotelDetailBookingEvidence(evidence) {
  const actions = Array.isArray(evidence?.actions)
    ? evidence.actions.filter((action) => action?.id === 'hotel.booking.open' ||
      action?.actionId === 'hotel.booking.open').map((action) => {
      if (action?.actionId === 'hotel.booking.open') {
        return sanitizeCollectedAction(action);
      }
      return sanitizeAction(action);
    })
    : [];
  const booking = statusFor(actions, 'hotel.booking.open');
  const surfaceId = typeof evidence?.surfaceId === 'string' ? evidence.surfaceId : '';
  return {
    ok: surfaceId.trim().length > 0 && booking.status === 'visible' && booking.count === 1,
    surfaceId,
    booking,
    actions
  };
}

export function hotelDetailClickLocator(evidence) {
  const validated = validateHotelSearchActionEvidence(evidence);
  const labels = validated.actions
    .filter((action) => action.actionId === 'hotel.detail' && action.argsValid && action.clickLabel.length > 0)
    .map((action) => action.clickLabel);
  return { ok: validated.ok && labels.length > 0, labels };
}

export function matchesHotelDetailAccessibleLabel(candidate, actionLabel) {
  if (typeof candidate !== 'string' || typeof actionLabel !== 'string') {
    return false;
  }
  const expected = actionLabel.trim();
  const actual = candidate.trim();
  if (expected.length === 0) {
    return false;
  }
  if (actual === expected) {
    return true;
  }
  const contextualPrefix = `${expected}：`;
  return actual.startsWith(contextualPrefix) && actual.slice(contextualPrefix.length).trim().length > 0;
}

function systemActionE2e(action, runtime, options = {}) {
  if (action.status === 'invalid') {
    return { status: 'BLOCKED', reason: 'action arguments are invalid; system surface was not opened' };
  }
  if (action.status === 'hidden') {
    return { status: 'NOT_RUN', reason: options.hiddenReason };
  }
  const missing = [];
  if (runtime?.systemSurfaceOpened !== true) missing.push('system surface not verified');
  if (runtime?.evidenceCaptured !== true) missing.push('system surface screenshot not captured');
  if (runtime?.returnedToApp !== true) missing.push('return to AIPhone not verified');
  if (missing.length > 0) {
    return { status: 'BLOCKED', reason: missing.join('; ') };
  }
  return { status: 'PASS', reason: options.passReason };
}

export function evaluateHotelSystemActionEvidence(evidence, runtime = {}) {
  const validated = validateHotelSearchActionEvidence(evidence);
  const navigationE2e = systemActionE2e(validated.navigation, runtime.navigation, {
    hiddenReason: 'valid hotel coordinates unavailable; navigation E2E not run',
    passReason: 'system map opened, evidence captured, and AIPhone restored'
  });
  const acceptableE2e = (result) => result.status === 'PASS' || result.status === 'NOT_RUN';
  return {
    ok: validated.ok && acceptableE2e(navigationE2e),
    detail: validated.detail,
    navigation: {
      actionStatus: validated.navigation.status,
      count: validated.navigation.count,
      e2e: navigationE2e
    },
    booking: validated.booking
  };
}

export function validateHotelSurfaceIdentity(searchSurfaceId, detailSurfaceId, restoredSurfaceId) {
  return {
    ok: typeof searchSurfaceId === 'string' && searchSurfaceId.trim().length > 0 &&
      typeof detailSurfaceId === 'string' && detailSurfaceId.trim().length > 0 &&
      detailSurfaceId !== searchSurfaceId && restoredSurfaceId === searchSurfaceId,
    searchSurfaceId,
    detailSurfaceId,
    restoredSurfaceId
  };
}
