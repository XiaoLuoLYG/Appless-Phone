function objectArgs(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function compactPhone(value) {
  if (typeof value !== 'string') {
    return '';
  }
  const compact = value.replace(/[ ()-]/g, '');
  return /^\+?[0-9]{5,20}$/.test(compact) ? compact : '';
}

function positiveHotelId(args) {
  return Number.isInteger(args.hotelId) && args.hotelId > 0;
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
  if (actionId === 'hotel.navigate') {
    return /(?:^|[._-])maps?(?:[._-]|$)/i.test(bundleName);
  }
  if (actionId === 'hotel.call') {
    return /(?:contacts?|dialer)/i.test(bundleName);
  }
  return false;
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
  } else if (actionId === 'hotel.call') {
    evidence.providerPresent = typeof args.provider === 'string' && args.provider.trim().length > 0;
    evidence.providerPlaceIdPresent =
      typeof args.providerPlaceId === 'string' && args.providerPlaceId.trim().length > 0;
    let displayCompact = compactPhone(args.displayPhone);
    let dialCompact = compactPhone(args.dialPhone);
    evidence.phoneShapeValid = dialCompact.length > 0;
    evidence.phoneMatchesDisplay = displayCompact.length > 0 && displayCompact === dialCompact;
    evidence.maskedSuffix = evidence.phoneShapeValid ? '***' + dialCompact.slice(-4) : '';
    evidence.argsValid = hotelIdPositive &&
      evidence.providerPresent &&
      evidence.providerPlaceIdPresent &&
      evidence.phoneShapeValid &&
      evidence.phoneMatchesDisplay;
    displayCompact = '';
    dialCompact = '';
  } else if (actionId === 'hotel.detail') {
    evidence.clickLabel = typeof action?.label === 'string' ? action.label.trim() : '';
    evidence.argsValid = hotelIdPositive;
  }
  return evidence;
}

export function hotelSearchActionEvidence(surfaceId, actions) {
  const safeActions = Array.isArray(actions) ? actions : [];
  return {
    surfaceId: typeof surfaceId === 'string' ? surfaceId : '',
    actions: safeActions
      .filter((action) => /^hotel\.(detail|navigate|call|book)$/.test(String(action?.id || '')))
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
      sanitized.argsObject &&
      sanitized.hotelIdPositive &&
      sanitized.latitudeValid &&
      sanitized.longitudeValid &&
      sanitized.coordinatesValid;
  } else if (actionId === 'hotel.call') {
    sanitized.providerPresent = action?.providerPresent === true;
    sanitized.providerPlaceIdPresent = action?.providerPlaceIdPresent === true;
    sanitized.phoneShapeValid = action?.phoneShapeValid === true;
    sanitized.phoneMatchesDisplay = action?.phoneMatchesDisplay === true;
    sanitized.maskedSuffix = typeof action?.maskedSuffix === 'string' &&
      /^\*\*\*[0-9]{4}$/.test(action.maskedSuffix)
      ? action.maskedSuffix
      : '';
    sanitized.argsValid = action?.argsValid === true &&
      sanitized.argsObject &&
      sanitized.hotelIdPositive &&
      sanitized.providerPresent &&
      sanitized.providerPlaceIdPresent &&
      sanitized.phoneShapeValid &&
      sanitized.phoneMatchesDisplay &&
      sanitized.maskedSuffix.length > 0;
  } else if (actionId === 'hotel.detail') {
    sanitized.clickLabel = typeof action?.clickLabel === 'string' ? action.clickLabel.trim() : '';
    sanitized.argsValid = action?.argsValid === true &&
      sanitized.argsObject &&
      sanitized.hotelIdPositive;
  }
  return sanitized;
}

export function validateHotelSearchActionEvidence(evidence) {
  const actions = Array.isArray(evidence?.actions)
    ? evidence.actions
      .filter((action) => /^hotel\.(detail|navigate|call|book)$/.test(String(action?.actionId || '')))
      .map(sanitizeCollectedAction)
    : [];
  const detail = statusFor(actions, 'hotel.detail');
  const navigation = statusFor(actions, 'hotel.navigate');
  const call = statusFor(actions, 'hotel.call');
  const bookingCount = actions.filter((action) => action.actionId === 'hotel.book').length;
  return {
    ok: typeof evidence?.surfaceId === 'string' &&
      evidence.surfaceId.trim().length > 0 &&
      detail.status === 'visible' &&
      navigation.status !== 'invalid' &&
      call.status !== 'invalid' &&
      bookingCount === 0,
    surfaceId: typeof evidence?.surfaceId === 'string' ? evidence.surfaceId : '',
    detail,
    navigation,
    call,
    bookingCount,
    actions
  };
}

export function hotelDetailClickLocator(evidence) {
  const validated = validateHotelSearchActionEvidence(evidence);
  const labels = validated.actions
    .filter((action) => action.actionId === 'hotel.detail' && action.argsValid && action.clickLabel.length > 0)
    .map((action) => action.clickLabel);
  return {
    ok: validated.ok && labels.length > 0,
    labels
  };
}

function systemActionE2e(action, runtime, options = {}) {
  if (options.finalDial === true && runtime?.finalDialTriggered === true) {
    return {
      status: 'FAIL',
      reason: 'safety boundary violated: final dial was triggered'
    };
  }
  if (action.status === 'invalid') {
    return {
      status: 'BLOCKED',
      reason: 'action arguments are invalid; system surface was not opened'
    };
  }
  if (action.status === 'hidden') {
    return {
      status: 'NOT_RUN',
      reason: options.hiddenReason
    };
  }
  const missing = [];
  if (runtime?.systemSurfaceOpened !== true) {
    missing.push('system surface not verified');
  }
  if (runtime?.evidenceCaptured !== true) {
    missing.push('system surface screenshot not captured');
  }
  if (runtime?.returnedToApp !== true) {
    missing.push('return to AIPhone not verified');
  }
  if (missing.length > 0) {
    return {
      status: 'BLOCKED',
      reason: missing.join('; ')
    };
  }
  return {
    status: 'PASS',
    reason: options.passReason
  };
}

export function evaluateHotelSystemActionEvidence(evidence, runtime = {}) {
  const validated = validateHotelSearchActionEvidence(evidence);
  const navigationE2e = systemActionE2e(validated.navigation, runtime.navigation, {
    hiddenReason: 'valid hotel coordinates unavailable; navigation E2E not run',
    passReason: 'system map opened, evidence captured, and AIPhone restored'
  });
  const callButton = validated.call.status === 'visible'
    ? {
      status: 'PASS',
      reason: 'verified phone action is visible'
    }
    : validated.call.status === 'hidden'
      ? runtime.call?.buttonVisible === false
        ? {
          status: 'PASS',
          reason: 'verified phone unavailable; call action correctly hidden'
        }
        : {
          status: 'BLOCKED',
          reason: 'verified phone unavailable; hidden call button was not verified in the UI'
        }
      : {
        status: 'FAIL',
        reason: 'call action is visible with invalid verification arguments'
      };
  const callE2e = systemActionE2e(validated.call, runtime.call, {
    finalDial: true,
    hiddenReason: 'verified phone unavailable; dialer E2E not run',
    passReason: 'dialer opened with a prefilled number, evidence captured, and AIPhone restored'
  });
  const acceptableE2e = (result) => result.status === 'PASS' || result.status === 'NOT_RUN';
  return {
    ok: validated.ok &&
      acceptableE2e(navigationE2e) &&
      callButton.status === 'PASS' &&
      acceptableE2e(callE2e),
    navigation: {
      actionStatus: validated.navigation.status,
      count: validated.navigation.count,
      e2e: navigationE2e
    },
    call: {
      actionStatus: validated.call.status,
      count: validated.call.count,
      button: callButton,
      e2e: callE2e
    }
  };
}

export function validateHotelSurfaceIdentity(searchSurfaceId, detailSurfaceId, restoredSurfaceId) {
  return {
    ok: typeof searchSurfaceId === 'string' &&
      searchSurfaceId.trim().length > 0 &&
      typeof detailSurfaceId === 'string' &&
      detailSurfaceId.trim().length > 0 &&
      detailSurfaceId !== searchSurfaceId &&
      restoredSurfaceId === searchSurfaceId,
    searchSurfaceId,
    detailSurfaceId,
    restoredSurfaceId
  };
}
