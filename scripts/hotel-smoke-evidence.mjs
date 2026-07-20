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
