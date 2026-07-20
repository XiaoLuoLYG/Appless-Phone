import {
  BackendAvailability,
  BackendResolution,
  cloneToolDefinition,
  ToolBackendType,
  ToolDefinition
} from './ToolDefinitionTypes';

const TOOL_DEFINITIONS: ToolDefinition[] = [
  {
    toolId: 'travel.search',
    domain: 'travel',
    intent: 'travel.search',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['none'],
    inputSchema: 'travelSearchQuery',
    outputSchema: 'travelOptions',
    a2uiComponent: 'TravelOptions',
    actions: []
  },
  {
    toolId: 'train.search',
    domain: 'travel',
    intent: 'travel.train.search',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['none'],
    inputSchema: 'travelTrainSearchQuery',
    outputSchema: 'trains',
    a2uiComponent: 'TrainOptions',
    actions: []
  },
  {
    toolId: 'flight.search',
    domain: 'travel',
    intent: 'travel.flight.search',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key'],
    inputSchema: 'travelFlightSearchQuery',
    outputSchema: 'flights',
    a2uiComponent: 'FlightBoard',
    actions: []
  },
  {
    toolId: 'hotel.search',
    domain: 'hotel',
    intent: 'hotel.search',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key'],
    inputSchema: 'hotelSearchRequest',
    outputSchema: 'hotelSearchResults',
    a2uiComponent: 'GenericToolResults',
    actions: ['hotel.detail']
  },
  {
    toolId: 'hotel.detail',
    domain: 'hotel',
    intent: 'hotel.detail',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key'],
    inputSchema: 'hotelDetailRequest',
    outputSchema: 'hotelRatePlans',
    a2uiComponent: 'GenericToolResults',
    actions: []
  },
  {
    toolId: 'food.search',
    domain: 'food',
    intent: 'local.food.search',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key'],
    inputSchema: 'foodSearchQuery',
    outputSchema: 'foodChoices',
    a2uiComponent: 'FoodChoices',
    actions: []
  },
  {
    toolId: 'luckin.order.preview',
    domain: 'luckin',
    intent: 'luckin.order.preview',
    riskLevel: 'draft',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key'],
    inputSchema: 'luckinOrderPreviewRequest',
    outputSchema: 'genericToolResults',
    a2uiComponent: 'GenericToolResults',
    actions: ['luckin.order.create']
  },
  {
    toolId: 'luckin.order.create',
    domain: 'luckin',
    intent: 'luckin.order.create',
    riskLevel: 'confirm_required',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key'],
    inputSchema: 'luckinOrderCreateRequest',
    outputSchema: 'genericToolResults',
    a2uiComponent: 'GenericToolResults',
    actions: ['luckin.order.status']
  },
  {
    toolId: 'luckin.order.status',
    domain: 'luckin',
    intent: 'luckin.order.status',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key'],
    inputSchema: 'luckinOrderStatusQuery',
    outputSchema: 'genericToolResults',
    a2uiComponent: 'GenericToolResults',
    actions: []
  },
  {
    toolId: 'social.feed.search',
    domain: 'social',
    intent: 'social.feed.search',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['oauth', 'provider_key'],
    inputSchema: 'socialFeedSearchQuery',
    outputSchema: 'socialHubFeed',
    a2uiComponent: 'SocialHub',
    actions: ['social.reply.draft']
  },
  {
    toolId: 'social.reply.draft',
    domain: 'social',
    intent: 'social.reply.draft',
    riskLevel: 'draft',
    backendPriority: ['local_adapter'],
    authModes: ['oauth', 'provider_key'],
    inputSchema: 'socialReplyDraftRequest',
    outputSchema: 'socialHubDraft',
    a2uiComponent: 'SocialHub',
    actions: []
  },
  {
    toolId: 'x.post.search',
    domain: 'x',
    intent: 'x.post.search',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['oauth', 'provider_key'],
    inputSchema: 'xPostSearchQuery',
    outputSchema: 'genericToolResults',
    a2uiComponent: 'GenericToolResults',
    actions: []
  },
  {
    toolId: 'mail.search',
    domain: 'mail',
    intent: 'mail.search',
    riskLevel: 'read',
    backendPriority: ['oauth_api', 'imap', 'workspace_mcp'],
    authModes: ['oauth', 'imap_auth', 'mcp_auth'],
    inputSchema: 'mailSearchQuery',
    outputSchema: 'mailThreads',
    a2uiComponent: 'GenericToolResults',
    actions: ['mail.thread.read', 'mail.draft.create']
  },
  {
    toolId: 'mail.thread.read',
    domain: 'mail',
    intent: 'mail.thread.read',
    riskLevel: 'read',
    backendPriority: ['oauth_api', 'imap'],
    authModes: ['oauth', 'imap_auth'],
    inputSchema: 'mailThreadReadQuery',
    outputSchema: 'mailThread',
    a2uiComponent: 'GenericToolResults',
    actions: ['mail.draft.create']
  },
  {
    toolId: 'mail.draft.create',
    domain: 'mail',
    intent: 'mail.draft.create',
    riskLevel: 'draft',
    backendPriority: ['oauth_api', 'imap'],
    authModes: ['oauth', 'imap_auth'],
    inputSchema: 'mailDraftCreateRequest',
    outputSchema: 'mailDraftResult',
    a2uiComponent: 'GenericToolResults',
    actions: []
  },
  {
    toolId: 'gmail.mail.search',
    domain: 'gmail',
    intent: 'gmail.mail.search',
    riskLevel: 'read',
    backendPriority: ['oauth_api', 'workspace_mcp', 'web_session'],
    authModes: ['oauth', 'mcp_auth', 'web_session'],
    inputSchema: 'mailSearchQuery',
    outputSchema: 'mailThreads',
    a2uiComponent: 'GenericToolResults',
    actions: ['gmail.authorize', 'gmail.thread.read', 'gmail.draft.create', 'gmail.open.web']
  },
  {
    toolId: 'gmail.thread.read',
    domain: 'gmail',
    intent: 'gmail.thread.read',
    riskLevel: 'read',
    backendPriority: ['oauth_api', 'workspace_mcp', 'web_session'],
    authModes: ['oauth', 'mcp_auth', 'web_session'],
    inputSchema: 'mailThreadReadQuery',
    outputSchema: 'mailThread',
    a2uiComponent: 'GenericToolResults',
    actions: ['gmail.authorize', 'gmail.draft.create', 'gmail.open.web']
  },
  {
    toolId: 'gmail.draft.create',
    domain: 'gmail',
    intent: 'gmail.draft.create',
    riskLevel: 'draft',
    backendPriority: ['oauth_api', 'workspace_mcp', 'web_session'],
    authModes: ['oauth', 'mcp_auth', 'web_session'],
    inputSchema: 'draftCreateRequest',
    outputSchema: 'draftReply',
    a2uiComponent: 'GenericToolResults',
    actions: ['gmail.authorize', 'gmail.draft.apply', 'gmail.open.web']
  },
  {
    toolId: 'gmail.draft.apply',
    domain: 'gmail',
    intent: 'gmail.draft.apply',
    riskLevel: 'confirm_required',
    backendPriority: ['oauth_api', 'workspace_mcp', 'web_session', 'system_intent'],
    authModes: ['oauth', 'mcp_auth', 'web_session', 'system'],
    inputSchema: 'draftApplyRequest',
    outputSchema: 'draftApplyResult',
    a2uiComponent: 'GenericToolResults',
    actions: ['gmail.authorize', 'gmail.open.web']
  },
  {
    toolId: 'gmail.open.web',
    domain: 'gmail',
    intent: 'gmail.open.web',
    riskLevel: 'confirm_required',
    backendPriority: ['system_intent'],
    authModes: ['system'],
    inputSchema: 'openWebIntent',
    outputSchema: 'systemIntentResult',
    a2uiComponent: 'GenericToolResults',
    actions: []
  },
  {
    toolId: 'gmail.message.send',
    domain: 'gmail',
    intent: 'gmail.message.send',
    riskLevel: 'blocked',
    backendPriority: ['system_intent'],
    authModes: ['system'],
    inputSchema: 'messageSendRequest',
    outputSchema: 'blockedAction',
    a2uiComponent: 'GenericToolResults',
    actions: ['gmail.authorize', 'gmail.draft.apply', 'gmail.open.web']
  },
  {
    toolId: 'youtube.video.search',
    domain: 'youtube',
    intent: 'youtube.video.search',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key'],
    inputSchema: 'youtubeVideoSearchQuery',
    outputSchema: 'youtubeVideos',
    a2uiComponent: 'GenericToolResults',
    actions: ['youtube.open.web']
  },
  {
    toolId: 'media.video.search',
    domain: 'media',
    intent: 'media.video.search',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key'],
    inputSchema: 'mediaVideoSearchQuery',
    outputSchema: 'mediaVideos',
    a2uiComponent: 'GenericToolResults',
    actions: ['media.open.web']
  },
  {
    toolId: 'media.aggregate.search',
    domain: 'media',
    intent: 'media.aggregate.search',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key', 'oauth', 'mcp_auth'],
    inputSchema: 'aggregateMediaSearchQuery',
    outputSchema: 'aggregateSearch',
    a2uiComponent: 'AggregateSearch',
    actions: ['media.open.web']
  },
  {
    toolId: 'worldcup.open',
    domain: 'media',
    intent: 'worldcup.open',
    riskLevel: 'read',
    backendPriority: ['system_intent'],
    authModes: ['system'],
    inputSchema: 'worldCupExperienceRequest',
    outputSchema: 'worldCupExperience',
    a2uiComponent: 'AnythingDemo',
    actions: []
  },
  {
    toolId: 'youtube.mine.playlists',
    domain: 'youtube',
    intent: 'youtube.mine.playlists',
    riskLevel: 'read',
    backendPriority: ['oauth_api', 'web_session'],
    authModes: ['oauth', 'web_session'],
    inputSchema: 'youtubeMinePlaylistsQuery',
    outputSchema: 'youtubePlaylists',
    a2uiComponent: 'GenericToolResults',
    actions: ['youtube.authorize', 'youtube.open.web']
  },
  {
    toolId: 'youtube.mine.subscriptions',
    domain: 'youtube',
    intent: 'youtube.mine.subscriptions',
    riskLevel: 'read',
    backendPriority: ['oauth_api', 'web_session'],
    authModes: ['oauth', 'web_session'],
    inputSchema: 'youtubeMineSubscriptionsQuery',
    outputSchema: 'youtubeSubscriptions',
    a2uiComponent: 'GenericToolResults',
    actions: ['youtube.authorize', 'youtube.open.web']
  },
  {
    toolId: 'calendar.events.search',
    domain: 'calendar',
    intent: 'calendar.events.search',
    riskLevel: 'read',
    backendPriority: ['oauth_api'],
    authModes: ['oauth'],
    inputSchema: 'calendarEventsSearchQuery',
    outputSchema: 'calendarEvents',
    a2uiComponent: 'GenericToolResults',
    actions: ['calendar.authorize']
  },
  {
    toolId: 'calendar.event.create',
    domain: 'calendar',
    intent: 'calendar.event.create',
    riskLevel: 'confirm_required',
    backendPriority: ['oauth_api'],
    authModes: ['oauth'],
    inputSchema: 'calendarEventCreateRequest',
    outputSchema: 'calendarEvent',
    a2uiComponent: 'GenericToolResults',
    actions: ['calendar.authorize']
  },
  {
    toolId: 'calendar.event.update',
    domain: 'calendar',
    intent: 'calendar.event.update',
    riskLevel: 'confirm_required',
    backendPriority: ['oauth_api'],
    authModes: ['oauth'],
    inputSchema: 'eventId?:string,query?:string,timeMin?:string,timeMax?:string,title?:string,start:string,end:string,timezone:string,calendarId?:string',
    outputSchema: 'calendarEvent',
    a2uiComponent: 'GenericToolResults',
    actions: ['calendar.authorize']
  },
  {
    toolId: 'calendar.event.delete',
    domain: 'calendar',
    intent: 'calendar.event.delete',
    riskLevel: 'confirm_required',
    backendPriority: ['oauth_api'],
    authModes: ['mcp_auth'],
    inputSchema: 'eventId?:string,query?:string,timeMin?:string,timeMax?:string,timezone?:string,calendarId?:string,title?:string,start?:string,end?:string,confirmed?:boolean',
    outputSchema: 'genericToolResults',
    a2uiComponent: 'GenericToolResults',
    actions: ['calendar.event.delete.confirm']
  },
  {
    toolId: 'payment.send',
    domain: 'payment',
    intent: 'payment.send',
    riskLevel: 'confirm_required',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key', 'web_session'],
    inputSchema: 'paymentSendRequest',
    outputSchema: 'paymentCheckout',
    a2uiComponent: 'GenericToolResults',
    actions: ['payment.confirm', 'payment.cancel', 'payment.amount.select', 'payment.provider.select', 'payment.checkout.open']
  },
  {
    toolId: 'payment.account.setup',
    domain: 'payment',
    intent: 'payment.account.setup',
    riskLevel: 'confirm_required',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key'],
    inputSchema: 'stripeReceivingAccountSetupRequest',
    outputSchema: 'stripeReceivingAccountSetupCard',
    a2uiComponent: 'StripeReceivingAccountCard',
    actions: ['stripe.account.create', 'stripe.account.open', 'stripe.account.onboard', 'stripe.account.refresh']
  },
  {
    toolId: 'maps.place.search',
    domain: 'maps',
    intent: 'maps.place.search',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key'],
    inputSchema: 'mapsPlaceSearchQuery',
    outputSchema: 'places',
    a2uiComponent: 'GenericToolResults',
    actions: []
  },
  {
    toolId: 'maps.place.details',
    domain: 'maps',
    intent: 'maps.place.details',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key'],
    inputSchema: 'mapsPlaceDetailsQuery',
    outputSchema: 'place',
    a2uiComponent: 'GenericToolResults',
    actions: []
  },
  {
    toolId: 'maps.route.open',
    domain: 'maps',
    intent: 'maps.route.open',
    riskLevel: 'read',
    backendPriority: ['system_intent'],
    authModes: ['none'],
    inputSchema: 'origin:string,destination:string,travelMode?:driving|walking|bicycling|transit|two-wheeler,navigate?:boolean',
    outputSchema: 'genericToolResults',
    a2uiComponent: 'GenericToolResults',
    actions: ['maps.open.web']
  },
  {
    toolId: 'whatsapp.message.send',
    domain: 'whatsapp',
    intent: 'whatsapp.message.send',
    riskLevel: 'confirm_required',
    backendPriority: ['oauth_api'],
    authModes: ['mcp_auth'],
    inputSchema: 'toNumber:string,text:string,phoneNumberId?:string,wabaId?:string,previewUrl?:boolean,confirmed?:boolean',
    outputSchema: 'genericToolResults',
    a2uiComponent: 'GenericToolResults',
    actions: ['whatsapp.message.send.confirm']
  },
  {
    toolId: 'ride.estimate',
    domain: 'ride',
    intent: 'ride.estimate',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key', 'mcp_auth'],
    inputSchema: 'rideRouteQuery',
    outputSchema: 'genericToolResults',
    a2uiComponent: 'GenericToolResults',
    actions: ['ride.order.confirm', 'ride.open.didi', 'ride.open.amap']
  },
  {
    toolId: 'ride.app.link',
    domain: 'ride',
    intent: 'ride.app.link',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key', 'mcp_auth'],
    inputSchema: 'rideRouteQuery',
    outputSchema: 'genericToolResults',
    a2uiComponent: 'GenericToolResults',
    actions: ['ride.open.didi', 'ride.open.amap']
  },
  {
    toolId: 'ride.order.create',
    domain: 'ride',
    intent: 'ride.order.create',
    riskLevel: 'confirm_required',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key', 'mcp_auth'],
    inputSchema: 'rideOrderCreateRequest',
    outputSchema: 'genericToolResults',
    a2uiComponent: 'GenericToolResults',
    actions: ['ride.driver.location.refresh', 'ride.order.cancel']
  },
  {
    toolId: 'ride.order.cancel',
    domain: 'ride',
    intent: 'ride.order.cancel',
    riskLevel: 'confirm_required',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key', 'mcp_auth'],
    inputSchema: 'rideOrderCancelRequest',
    outputSchema: 'genericToolResults',
    a2uiComponent: 'GenericToolResults',
    actions: ['ride.query.retry', 'ride.vehicle.change']
  },
  {
    toolId: 'ride.driver.location',
    domain: 'ride',
    intent: 'ride.driver.location',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['provider_key', 'mcp_auth'],
    inputSchema: 'rideDriverLocationRequest',
    outputSchema: 'genericToolResults',
    a2uiComponent: 'GenericToolResults',
    actions: ['ride.driver.location.refresh', 'ride.order.cancel']
  }
];

function toolIdsForDomain(domain: string): string[] {
  const toolIds: string[] = [];
  for (let index = 0; index < TOOL_DEFINITIONS.length; index++) {
    const definition = TOOL_DEFINITIONS[index];
    if (definition.domain === domain) {
      toolIds.push(definition.toolId);
    }
  }
  return toolIds;
}

export const GMAIL_TOOL_IDS: string[] = toolIdsForDomain('gmail');

export function allToolDefinitions(): ToolDefinition[] {
  const definitions: ToolDefinition[] = [];
  for (let index = 0; index < TOOL_DEFINITIONS.length; index++) {
    definitions.push(cloneToolDefinition(TOOL_DEFINITIONS[index]));
  }
  return definitions;
}

export function toolDefinitionForToolId(toolId: string): ToolDefinition | null {
  for (let index = 0; index < TOOL_DEFINITIONS.length; index++) {
    const definition = TOOL_DEFINITIONS[index];
    if (definition.toolId === toolId) {
      return cloneToolDefinition(definition);
    }
  }
  return null;
}

export function isKnownDomainToolId(toolId: string): boolean {
  return toolDefinitionForToolId(toolId) !== null;
}

export function isGmailToolId(toolId: string): boolean {
  const definition = toolDefinitionForToolId(toolId);
  return definition !== null && definition.domain === 'gmail';
}

export function isMailToolId(toolId: string): boolean {
  const definition = toolDefinitionForToolId(toolId);
  return definition !== null && definition.domain === 'mail';
}

export function isYouTubeToolId(toolId: string): boolean {
  const definition = toolDefinitionForToolId(toolId);
  return definition !== null && definition.domain === 'youtube';
}

export function isMediaToolId(toolId: string): boolean {
  const definition = toolDefinitionForToolId(toolId);
  return definition !== null && definition.domain === 'media';
}

export function isCalendarToolId(toolId: string): boolean {
  const definition = toolDefinitionForToolId(toolId);
  return definition !== null && definition.domain === 'calendar';
}

export function isMapsToolId(toolId: string): boolean {
  const definition = toolDefinitionForToolId(toolId);
  return definition !== null && definition.domain === 'maps';
}

export function isPaymentToolId(toolId: string): boolean {
  const definition = toolDefinitionForToolId(toolId);
  return definition !== null && definition.domain === 'payment';
}

export function isRideToolId(toolId: string): boolean {
  const definition = toolDefinitionForToolId(toolId);
  return definition !== null && definition.domain === 'ride';
}

export function isLuckinToolId(toolId: string): boolean {
  const definition = toolDefinitionForToolId(toolId);
  return definition !== null && definition.domain === 'luckin';
}

export function isHotelToolId(toolId: string): boolean {
  const definition = toolDefinitionForToolId(toolId);
  return definition !== null && definition.domain === 'hotel';
}

export function isLocalAdapterToolId(toolId: string): boolean {
  const definition = toolDefinitionForToolId(toolId);
  return definition !== null && definition.backendPriority.indexOf('local_adapter') >= 0;
}

export function backendLabel(backend: ToolBackendType): string {
  if (backend === 'local_adapter') {
    return 'Local adapter';
  }
  if (backend === 'oauth_api') {
    return 'OAuth API';
  }
  if (backend === 'imap') {
    return 'IMAP';
  }
  if (backend === 'workspace_mcp') {
    return 'Workspace MCP';
  }
  if (backend === 'web_session') {
    return 'Web session';
  }
  if (backend === 'system_intent') {
    return 'System intent';
  }
  return 'Remote MCP';
}

function firstBackendFor(definition: ToolDefinition | null): ToolBackendType {
  if (definition !== null && definition.backendPriority.length > 0) {
    return definition.backendPriority[0];
  }
  return 'mcp_remote';
}

function availabilityForBackend(backend: ToolBackendType, availability: BackendAvailability[]): BackendAvailability | null {
  for (let index = 0; index < availability.length; index++) {
    const candidate = availability[index];
    if (candidate.backend === backend) {
      return candidate;
    }
  }
  return null;
}

export function resolveBackendForTool(toolId: string, availability: BackendAvailability[]): BackendResolution {
  const definition = toolDefinitionForToolId(toolId);
  const fallbackBackend = firstBackendFor(definition);
  if (definition === null) {
    return {
      ok: false,
      toolId: toolId,
      backend: fallbackBackend,
      reason: 'Tool is not registered.',
      accountHint: ''
    };
  }
  if (definition.riskLevel === 'blocked') {
    return {
      ok: false,
      toolId: toolId,
      backend: fallbackBackend,
      reason: 'Blocked by AIPhone product boundary: ' + toolId,
      accountHint: ''
    };
  }

  for (let index = 0; index < definition.backendPriority.length; index++) {
    const backend = definition.backendPriority[index];
    const candidate = availabilityForBackend(backend, availability);
    if (candidate !== null && candidate.available) {
      return {
        ok: true,
        toolId: toolId,
        backend: backend,
        reason: candidate.reason,
        accountHint: candidate.accountHint
      };
    }
  }

  const fallbackAvailability = availabilityForBackend(fallbackBackend, availability);
  const reason = fallbackAvailability === null ? '' : fallbackAvailability.reason;
  const accountHint = fallbackAvailability === null ? '' : fallbackAvailability.accountHint;
  return {
    ok: false,
    toolId: toolId,
    backend: fallbackBackend,
    reason: reason.length > 0 ? reason : backendLabel(fallbackBackend) + ' is not available.',
    accountHint: accountHint
  };
}
