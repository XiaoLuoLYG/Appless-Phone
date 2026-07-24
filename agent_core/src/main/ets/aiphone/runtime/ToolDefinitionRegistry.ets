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
    actions: ['hotel.detail', 'hotel.navigate']
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
    actions: ['hotel.booking.open']
  },
  {
    toolId: 'hotel.navigate',
    domain: 'hotel',
    intent: 'hotel.navigate',
    riskLevel: 'read',
    backendPriority: ['system_intent'],
    authModes: ['system'],
    inputSchema: 'hotelNavigateRequest',
    outputSchema: 'systemIntentResult',
    a2uiComponent: 'GenericToolResults',
    actions: []
  },
  {
    toolId: 'hotel.booking.open',
    domain: 'hotel',
    intent: 'hotel.booking.open',
    riskLevel: 'draft',
    backendPriority: ['web_session'],
    authModes: ['web_session'],
    inputSchema: 'hotelBookingOpenRequest',
    outputSchema: 'webSessionOpenResult',
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
    toolId: 'social.community.search',
    domain: 'social',
    intent: 'social.community.search',
    riskLevel: 'read',
    backendPriority: ['local_adapter'],
    authModes: ['oauth', 'provider_key'],
    inputSchema: 'socialCommunitySearchQuery',
    outputSchema: 'socialHubFeed',
    a2uiComponent: 'SocialHub',
    actions: []
  },
  {
    toolId: 'social.post.preview',
    domain: 'social',
    intent: 'social.post.preview',
    riskLevel: 'draft',
    backendPriority: ['local_adapter'],
    authModes: ['oauth', 'provider_key'],
    inputSchema: 'socialPostPreviewRequest',
    outputSchema: 'socialHubPublication',
    a2uiComponent: 'SocialHub',
    actions: []
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
    riskLevel: 'confirm_required',
    backendPriority: ['oauth_api'],
    authModes: ['oauth'],
    inputSchema: 'mailReplyCommand',
    outputSchema: 'mailReplyOperationResult',
    a2uiComponent: 'GenericToolResults',
    actions: []
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
    actions: ['calendar.authorize', 'calendar.event.update', 'calendar.event.delete']
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
    inputSchema: 'eventId?:string,query?:string,timeMin?:string,timeMax?:string,title?:string,start?:string,end?:string,timezone?:string,calendarId?:string',
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
    inputSchema: 'eventId?:string,query?:string,timeMin?:string,timeMax?:string,timezone?:string,calendarId?:string,title?:string,start?:string,end?:string',
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
    inputSchema: 'toNumber:string,text:string,phoneNumberId?:string,wabaId?:string,previewUrl?:boolean',
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

const DYNAMIC_SEARCH_PLANNING_DESCRIPTION: string =
  'dynamic.search inputSchema=dynamicToolSearchQuery outputSchema=dynamicToolConnect. ' +
  'Use for ModelScope/remote MCP discovery, weather requests, Composio-backed app/toolkit requests, and domains ' +
  'not covered by fixed tools. Use dynamic.search when the user names unsupported external apps or SaaS toolkits ' +
  'such as Notion pages/databases, Google Drive files, Google Docs documents, Linear issues, Trello cards/checklists, ' +
  'Asana tasks, GitHub issues, HubSpot, Salesforce, Outlook, Spotify, TikTok, or Ticketmaster. Do not use ' +
  'dynamic.search for any SocialHub inbox, private-message, recent-message, or connection-state request involving ' +
  'X/Twitter, Slack, WeCom, Discord, LinkedIn, WhatsApp, or Instagram; use social.feed.search with structured ' +
  'top-level platforms instead. LeaderDecision uses dataTasks[].input.platforms; legacy ToolCall uses args.platforms. ' +
  'WhatsApp Business message sending uses whatsapp.message.send, never dynamic.search. ' +
  'Gmail, Google Calendar, YouTube account tools, and X public post search have fixed Composio-backed tools; use ' +
  'those fixed tool IDs instead of dynamic.search. Use dynamic.search for Outlook only when the user explicitly ' +
  'names Outlook or Composio Outlook; ordinary mailbox aggregation uses mail.search. World Cup page, schedule, ' +
  'next-match, preview, team, or player-card requests are covered by worldcup.open, not dynamic.search. For ' +
  'Composio, first call with the full user task to discover candidate tools; only call again with ' +
  '{"operation":"execute","toolSlug":"returned slug","arguments":{...}} for read/search/list/get actions. Do not ' +
  'use Composio for payment, Gmail, Calendar, SocialHub, Maps, Food, Travel, World Cup page/schedule requests, or ' +
  'other fixed-tool domains unless the user explicitly asks for an unsupported external app/toolkit. For ferry or ' +
  'boat ticket requests, use dynamic.search; fixed travel tools only cover train and flight options, and ' +
  'dynamic.search may return no_tool_found truthfully.';

export function toolPlanningDescriptionForToolId(toolId: string): string {
  if (toolId === 'dynamic.search') {
    return DYNAMIC_SEARCH_PLANNING_DESCRIPTION;
  }
  const definition = toolDefinitionForToolId(toolId);
  if (definition === null) {
    return '';
  }
  let description = definition.intent + ' risk=' + definition.riskLevel +
    ' inputSchema=' + definition.inputSchema + ' outputSchema=' + definition.outputSchema;
  if (definition.toolId === 'travel.search') {
    description += '. Use for general train/flight travel options. Do not use for ferry or boat tickets; use dynamic.search for those unsupported transport domains.';
  } else if (definition.toolId === 'train.search') {
    description += '. Use for railway, high-speed rail, bullet train, station-to-station, 12306, or train schedule requests.';
  } else if (definition.toolId === 'flight.search') {
    description += '. Use for flight, airline, airport, or flight-board requests.';
  } else if (definition.toolId === 'hotel.search') {
    description += '. Use for real hotel discovery through RollingGo. Input must be JSON with originQuery, place, placeType, countryCode, checkInDate in YYYY-MM-DD, stayNights, adultCount, childCount, childAgeDetails, roomCount, currency, and optional size. Never omit place or dates: the provider otherwise defaults to unrelated inventory. This tool is read-only and does not create a reservation.';
  } else if (definition.toolId === 'hotel.detail') {
    description += '. Use only after hotel.search returns a real hotelId. Preserve hotelId, checkInDate, checkOutDate, countryCode, currency, adultCount, childCount, childAgeDetails, and roomCount. It returns live room ratePlanId, average price/currency, bed, meal, availability, and cancellation policy. It does not create, confirm, or track an order.';
  } else if (definition.toolId === 'food.search') {
    description += '. Use for restaurants, cafes, coffee, milk tea, drinks, McDonalds, menus, coupons, delivery, and food or beverage places near a location. Do not use for Luckin order placement; use luckin.order.preview for ordering Luckin coffee.';
  } else if (definition.toolId === 'luckin.order.preview') {
    description += '. Use only when the current user message itself explicitly names Luckin/Ruixing and explicitly asks to place or prepare a real order, for example "点一杯瑞幸咖啡", "帮我买一杯瑞幸生椰拿铁", or "瑞幸下单". Do not infer Luckin ordering from saved brand preferences or memory. A Luckin brand mention, store discovery, menu browsing, product question, or price question is not an order and must use food.search instead. This is the first step for explicit Luckin ordering: it queries nearby stores, product SKU/options, and previewOrder pricing. Input must be JSON; at minimum pass {"prompt":"<original user request>"} or {"query":"<original user request>"}. Do not answer with note or food.search when the current message explicitly requests a Luckin order.';
  } else if (definition.toolId === 'luckin.order.create') {
    description += '. Use only after a Luckin order preview card returned real deptId, productId, and skuCode, and the user confirms creating the order. Do not use directly from an initial "order coffee" request.';
  } else if (definition.toolId === 'luckin.order.status') {
    description += '. Use when the user asks to check, refresh, or view a Luckin order status, pickup code, or existing orderId.';
  } else if (definition.toolId === 'social.feed.search') {
    description += '. Use for every SocialHub inbox, received-message, recent-message, private-message, or connection-state request involving X/Twitter, Slack, WeCom, Discord, LinkedIn, WhatsApp, or Instagram, including when the user mentions Composio or authorization. The tool argument object must contain exactly one key named platforms: LeaderDecision uses dataTasks[].input.platforms; legacy ToolCall uses args.platforms. Do not add date, query, or limit. Use one named platform such as ["whatsapp"] for a single-source request, named platforms such as ["x","slack"] for a combined request, or ["all"] for the complete SocialHub. Do not use for public X/Twitter posts; use x.post.search for explicit public post searches. This tool reports unsupported read capabilities as limitations and never fabricates social messages.';
  } else if (definition.toolId === 'social.community.search') {
    description += '. Use for read-only public community content on Reddit, LinkedIn, Instagram, or X when the user asks for the SocialHub community view. Preserve platform, query, resourceId, and limit. Do not use x.post.search for SocialHub community requests. Never fabricate posts or hide provider auth/network failures.';
  } else if (definition.toolId === 'social.post.preview') {
    description += '. Use only for a standalone public X, LinkedIn, Instagram, or Reddit post draft. It creates a reviewable preview and does not publish. Include platform, operation="publish", and non-empty text. Never replace this with social.reply.draft, which requires a selected real inbox/feed item.';
  } else if (definition.toolId === 'social.reply.draft') {
    description += '. Use only to draft a reply after a real SocialHub inbox/feed item is selected. Include itemId, platform, and instruction when available. Never use for a standalone public post. Do not send.';
  } else if (definition.toolId === 'x.post.search') {
    description += '. Use only for explicit X/Twitter/x.com public post searches, not arbitrary letter X or Xcode requests. Never use it for SocialHub inbox or private social messages. Never fabricate posts.';
  } else if (definition.toolId === 'maps.place.search') {
    description += '. Use for explicit Google Maps/Google Places searches, non-food places, addresses, and POIs. If the user asks for cafes, coffee, milk tea, restaurants, menus, or delivery without explicitly asking for Google Maps, use food.search.';
  } else if (definition.toolId === 'maps.route.open') {
    description += '. Use for Google Maps directions or navigation only when structured args include origin and destination. Do not parse or guess endpoints from free text.';
  } else if (definition.toolId === 'whatsapp.message.send') {
    description += '. Use for real WhatsApp Business text messages. Include structured args.toNumber and args.text. Preserve args.phoneNumberId or args.wabaId when the user configured a sender. The client requires explicit confirmation and the Provider may reject free text outside the 24-hour conversation window.';
  } else if (definition.toolId === 'mail.search') {
    description += '. Use for generic mailbox/email/inbox requests and aggregate Gmail, QQ Mail, and Outlook search. Action input must be JSON with providers, query, and pageSize. Always include query; if the user wants latest/recent mail and is not searching by keyword, set query to "". Use pageSize for requested count; do not use count, limit, or maxResults. If the user says only mail, email, inbox, or latest important mail, choose mail.search with providers ["gmail","qq","outlook"]. Never use it for SocialHub messages. Never fabricate mail rows.';
  } else if (definition.toolId === 'mail.thread.read') {
    description += '. Use only when the user opens or reads a specific aggregate mail result and provider plus messageId/threadId are available.';
  } else if (definition.toolId === 'mail.draft.create') {
    description += '. Use for aggregate mail reply drafts after a real mail row is selected. Include provider, messageId or threadId, to, subject, and body when available.';
  } else if (definition.toolId === 'gmail.mail.search') {
    description += '. Use for searching, listing, or viewing Gmail messages, inboxes, important mail, or keyword-based mail queries. Required Action input is a JSON object with args.query and args.pageSize; do not pass plain keywords. Always include query; if the user wants latest/recent Gmail and is not searching by keyword, set query to "". Use pageSize for requested count; do not use count, limit, or maxResults. Generate args.query from the user request only when the user is searching by keyword; never fabricate Gmail messages. For Chinese academic or application queries, keep user-provided acronyms or names and expand the Gmail query with likely English terms: paper, manuscript, submission, review, conference, journal, camera-ready, admission decision, offer letter, accepted, admitted, congratulations, waitlist, rejection, application status. Use Gmail OR grouping like {user_acronym OR paper OR manuscript OR review}; do not space-AND every term. Keep the query focused to the relevant 6-10 OR terms.';
  } else if (definition.toolId === 'gmail.thread.read') {
    description += '. Use only when the user asks to read a specific Gmail thread and a threadId is available.';
  } else if (definition.toolId === 'gmail.draft.create') {
    description += '. Use for Gmail replies, writing email, composing email, saying something to a recipient, or creating a draft. For normal "send/write an email saying..." requests, create a draft first instead of using gmail.message.send. Include args.to, args.subject, and args.body when available. gmail.message.send is available only from the exact current mail reply Send button.';
  } else if (definition.toolId === 'gmail.draft.apply') {
    description += '. Use only after a user has already reviewed and confirmed an existing Gmail draft.';
  } else if (definition.toolId === 'gmail.open.web') {
    description += '. Use only when the user explicitly asks to open Gmail in the browser/web app.';
  } else if (definition.toolId === 'gmail.message.send') {
    description += '. Available only from the exact current mail reply Send button after surface and argument validation. Never select it for a natural-language request; create a reviewable Gmail draft first.';
  } else if (definition.toolId === 'media.video.search') {
    description += '. Use for Bilibili/B站/哔哩哔哩 video search or multi-source video search. If the same request mentions YouTube and Bilibili, choose media.video.search with sources ["youtube","bilibili"].';
  } else if (definition.toolId === 'media.aggregate.search') {
    description += '. Use only for mixed-content topic research where the user asks for videos plus news, discussions, posts, or public reactions around one topic; use media.video.search for video-only requests. It aggregates YouTube, Bilibili, X public posts, Hacker News and Reddit via Composio, and Zhihu via its official REST API. Never fabricate media or posts.';
  } else if (definition.toolId === 'worldcup.open') {
    description += '. Use when the user wants to open the World Cup experience, view World Cup schedules, next match time, previews, highlights, teams, players, or matchup cards. Use media tools instead for explicit YouTube-only, Bilibili-only, or mixed-content search requests.';
  } else if (definition.toolId === 'youtube.video.search') {
    description += '. Use only for explicit YouTube-only public video search; use media.video.search for Bilibili or multi-source video requests.';
  } else if (definition.toolId === 'calendar.events.search') {
    description += '. Use for reading or listing Google Calendar events, and as the first step for a natural-language update, move, modify, or delete that lacks a current trusted Event ID. Input must be JSON with args.query, args.timeMin, args.timeMax, args.timezone, and optional args.calendarId. query contains only event title text; use an empty query when the request specifies only a date or time. Resolve relative dates from the current device local datetime into RFC3339 timeMin/timeMax; never pass phrases such as tomorrow or 明天.';
  } else if (definition.toolId === 'calendar.event.create') {
    description += '. Use for creating Google Calendar events. Required JSON args are title, start, end, and timezone; calendarId is optional. start and end must be RFC3339 timestamps with a numeric offset, for example 2026-07-17T15:00:00+08:00. Resolve relative dates from the current device local datetime. If the title, date, start time, end time, or duration is missing, ask the user in Final and do not call this tool. Never invent a time or pass natural-language time text.';
  } else if (definition.toolId === 'calendar.event.update') {
    description += '. Use only from the exact current provider-backed update confirmation. For a natural-language update or move without a current trusted Event ID, call calendar.events.search first. The client updates only when exactly one real event matches and the new time is complete. When a visible event action already provides args.eventId, preserve it. Never ask the user to type or know an Event ID.';
  } else if (definition.toolId === 'calendar.event.delete') {
    description += '. Use only from the exact current provider-backed delete confirmation. For a natural-language delete without a current trusted Event ID, call calendar.events.search first. When the user selected a visible event, preserve its internal args.eventId. Never ask the user to type or know an Event ID. The client requires explicit delete confirmation before the Provider call.';
  } else if (definition.toolId === 'payment.send') {
    description += '. Use for explicit PayPal account payments, Stripe connected merchant Checkout, or opening a stored Stripe Payment Link. If the user says Google Pay, treat it as args.fundingSource="google_pay" with provider still PayPal or Stripe; Google Pay is not a separate provider/tool. Always produce a confirmation/payment UI before checkout. Never claim money was sent without a real provider confirmation.';
  } else if (definition.toolId === 'payment.account.setup') {
    description += '. Use when the user wants to create, bind, open, verify, or refresh the current agent Stripe receiving account. Do not use this for paying someone; payment.send handles payments.';
  } else if (definition.toolId === 'ride.estimate') {
    description += '. Use for taxi/ride-hailing fare estimate requests. Shows Didi price estimates only and also returns Didi/Amap app ride links. Required input must include args.origin/from, args.destination/to, and args.city when the city is known or inferable from the user text. If origin, destination, or city is missing, ask for it; never guess coordinates. Never create, cancel, query, or track ride orders, even if the user says "直接帮我叫车".';
  } else if (definition.toolId === 'ride.app.link') {
    description += '. Use when the user wants taxi/ride-hailing app links without prices. Returns Didi and Amap app ride links for user-tapped handoff only. Required input must include args.origin/from, args.destination/to, and args.city when the city is known or inferable from the user text. Do not describe Amap as a price estimate provider. Never create, cancel, query, or track ride orders.';
  }
  return description;
}

export function isExplicitLuckinOrderPrompt(prompt: string): boolean {
  const text = prompt.trim();
  const hasLuckin = /瑞幸|luckin|ruixing/i.test(text);
  const hasTransaction =
    /点一杯|点杯|点个瑞幸|点瑞幸|帮我点|我要点|下单|下一杯|买一杯|买瑞幸|帮我买|购买一杯|购买瑞幸|来一杯|要一杯|\border\b|\bbuy\b/i
      .test(text);
  return hasLuckin && hasTransaction;
}

export function isSurfaceDerivedHotelActionId(toolId: string): boolean {
  return toolId === 'hotel.navigate' || toolId === 'hotel.booking.open';
}

export function aiphoneToolDescriptionForModel(toolId: string): string {
  if (isSurfaceDerivedHotelActionId(toolId) ||
    toolId === 'gmail.message.send' ||
    toolId === 'social.reply.draft' ||
    toolId === 'calendar.event.create' ||
    toolId === 'calendar.event.update' ||
    toolId === 'calendar.event.delete') {
    return '';
  }
  return toolPlanningDescriptionForToolId(toolId);
}

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

function isExternalActionBackend(definition: ToolDefinition): boolean {
  return definition.backendPriority.indexOf('system_intent') >= 0;
}

function isDataAgentDefinition(definition: ToolDefinition): boolean {
  return definition.riskLevel === 'read' && !isExternalActionBackend(definition);
}

export function dataAgentToolDefinitions(): ToolDefinition[] {
  return allToolDefinitions().filter(isDataAgentDefinition);
}

export function actionAgentToolDefinitions(): ToolDefinition[] {
  return allToolDefinitions().filter((definition: ToolDefinition): boolean =>
    !isDataAgentDefinition(definition));
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
