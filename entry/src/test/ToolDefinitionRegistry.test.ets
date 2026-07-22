import { describe, it, expect } from '@ohos/hypium';
import {
  GMAIL_TOOL_IDS,
  aiphoneToolDefinitionCount,
  allAiphoneToolDefinitions,
  aiphoneToolDescriptionForModel,
  actionAgentToolDefinitions,
  allToolDefinitions,
  backendLabel,
  dataAgentToolDefinitions,
  isCalendarToolId,
  isGmailToolId,
  isHotelToolId,
  isKnownDomainToolId,
  isLuckinToolId,
  isLocalAdapterToolId,
  isMailToolId,
  isMapsToolId,
  isMediaToolId,
  isPaymentToolId,
  isRideToolId,
  isRegisteredAiphoneToolId,
  isYouTubeToolId,
  resolveBackendForTool,
  isSurfaceDerivedHotelActionId,
  toolDefinitionForToolId
} from '@loop/agent-core';
import { BackendAvailability, BackendResolution, ToolBackendType, ToolDefinition } from '@loop/agent-core';

function availability(
  backend: ToolBackendType,
  available: boolean,
  reason: string,
  accountHint: string
): BackendAvailability {
  return {
    backend: backend,
    available: available,
    reason: reason,
    accountHint: accountHint
  };
}

function hotelDefinitions(definitions: ToolDefinition[]): ToolDefinition[] {
  const hotels: ToolDefinition[] = [];
  for (let index = 0; index < definitions.length; index++) {
    if (definitions[index].domain === 'hotel') {
      hotels.push(definitions[index]);
    }
  }
  return hotels;
}

export default function toolDefinitionRegistryTest() {
  describe('toolDefinitionRegistry', () => {
    it('recognizes existing local adapters and Gmail tools through one registry', 0, () => {
      expect(isKnownDomainToolId('travel.search')).assertTrue();
      expect(isKnownDomainToolId('food.search')).assertTrue();
      expect(isKnownDomainToolId('hotel.search')).assertTrue();
      expect(isKnownDomainToolId('hotel.detail')).assertTrue();
      expect(isKnownDomainToolId('luckin.order.preview')).assertTrue();
      expect(isKnownDomainToolId('luckin.order.create')).assertTrue();
      expect(isKnownDomainToolId('luckin.order.status')).assertTrue();
      expect(isKnownDomainToolId('social.reply.send')).assertFalse();
      expect(isKnownDomainToolId('social.feed.search')).assertTrue();
      expect(isKnownDomainToolId('social.reply.draft')).assertTrue();
      expect(isKnownDomainToolId('x.post.search')).assertTrue();
      expect(isKnownDomainToolId('gmail.mail.search')).assertTrue();
      expect(isKnownDomainToolId('gmail.thread.read')).assertTrue();
      expect(isKnownDomainToolId('gmail.draft.create')).assertTrue();
      expect(isKnownDomainToolId('gmail.draft.apply')).assertTrue();
      expect(isKnownDomainToolId('gmail.open.web')).assertTrue();
      expect(isKnownDomainToolId('gmail.message.send')).assertTrue();
      expect(isKnownDomainToolId('calendar.events.search')).assertTrue();
      expect(isKnownDomainToolId('calendar.event.create')).assertTrue();
      expect(isKnownDomainToolId('calendar.event.update')).assertTrue();
      expect(isKnownDomainToolId('calendar.event.delete')).assertTrue();
      expect(isKnownDomainToolId('maps.place.search')).assertTrue();
      expect(isKnownDomainToolId('maps.place.details')).assertTrue();
      expect(isKnownDomainToolId('maps.route.open')).assertTrue();
      expect(isKnownDomainToolId('whatsapp.message.send')).assertTrue();
      expect(isKnownDomainToolId('ride.estimate')).assertTrue();
      expect(isKnownDomainToolId('ride.app.link')).assertTrue();
      expect(isKnownDomainToolId('ride.order.create')).assertTrue();
      expect(isKnownDomainToolId('ride.order.cancel')).assertTrue();
      expect(isKnownDomainToolId('ride.driver.location')).assertTrue();
      expect(isKnownDomainToolId('gmail.unknown')).assertFalse();
      expect(isKnownDomainToolId('youtube.video.search')).assertTrue();
      expect(isKnownDomainToolId('youtube.mine.playlists')).assertTrue();
      expect(isKnownDomainToolId('youtube.mine.subscriptions')).assertTrue();
      expect(isKnownDomainToolId('media.video.search')).assertTrue();
      expect(isKnownDomainToolId('youtube.unknown')).assertFalse();

      expect(isLocalAdapterToolId('travel.search')).assertTrue();
      expect(isLocalAdapterToolId('hotel.search')).assertTrue();
      expect(isHotelToolId('hotel.search')).assertTrue();
      expect(isHotelToolId('hotel.detail')).assertTrue();
      expect(isHotelToolId('hotel.create')).assertFalse();
      expect(isLocalAdapterToolId('luckin.order.preview')).assertTrue();
      expect(isLuckinToolId('luckin.order.create')).assertTrue();
      expect(isLuckinToolId('food.search')).assertFalse();
      expect(isLocalAdapterToolId('gmail.mail.search')).assertFalse();
      expect(isGmailToolId('gmail.mail.search')).assertTrue();
      expect(isGmailToolId('food.search')).assertFalse();
      expect(isYouTubeToolId('youtube.video.search')).assertTrue();
      expect(isYouTubeToolId('gmail.mail.search')).assertFalse();
      expect(isYouTubeToolId('media.video.search')).assertFalse();
      expect(isMediaToolId('media.video.search')).assertTrue();
      expect(isMediaToolId('youtube.video.search')).assertFalse();
      expect(isRideToolId('ride.estimate')).assertTrue();
      expect(isRideToolId('ride.app.link')).assertTrue();
      expect(isRideToolId('ride.order.create')).assertTrue();
      expect(isRideToolId('ride.order.cancel')).assertTrue();
      expect(isRideToolId('ride.driver.location')).assertTrue();
      expect(isKnownDomainToolId('media.aggregate.search')).assertTrue();
      expect(isMediaToolId('media.aggregate.search')).assertTrue();
    });

    it('registers SocialHub read and draft tools without send', 0, () => {
      const feed = toolDefinitionForToolId('social.feed.search') as ToolDefinition;
      const draft = toolDefinitionForToolId('social.reply.draft') as ToolDefinition;
      const xPost = toolDefinitionForToolId('x.post.search') as ToolDefinition;

      expect(feed.domain).assertEqual('social');
      expect(feed.riskLevel).assertEqual('read');
      expect(feed.outputSchema).assertEqual('socialHubFeed');
      expect(feed.a2uiComponent).assertEqual('SocialHub');
      expect(feed.actions[0]).assertEqual('social.reply.draft');
      expect(draft.riskLevel).assertEqual('draft');
      expect(draft.outputSchema).assertEqual('socialHubDraft');
      expect(draft.actions.length).assertEqual(0);
      expect(xPost.domain).assertEqual('x');
      expect(xPost.riskLevel).assertEqual('read');
      expect(xPost.outputSchema).assertEqual('genericToolResults');
      expect(xPost.a2uiComponent).assertEqual('GenericToolResults');
      expect(xPost.actions.length).assertEqual(0);
      expect(toolDefinitionForToolId('social.reply.send')).assertEqual(null);
    });

    it('registers only truthful hotel actions with aligned public and runtime registries', 0, () => {
      const search = toolDefinitionForToolId('hotel.search') as ToolDefinition;
      const detail = toolDefinitionForToolId('hotel.detail') as ToolDefinition;
      const navigate = toolDefinitionForToolId('hotel.navigate') as ToolDefinition;
      const booking = toolDefinitionForToolId('hotel.booking.open') as ToolDefinition;

      expect(search.domain).assertEqual('hotel');
      expect(search.riskLevel).assertEqual('read');
      expect(search.backendPriority.join(',')).assertEqual('local_adapter');
      expect(search.authModes.join(',')).assertEqual('provider_key');
      expect(search.inputSchema).assertEqual('hotelSearchRequest');
      expect(search.outputSchema).assertEqual('hotelSearchResults');
      expect(search.a2uiComponent).assertEqual('GenericToolResults');
      expect(search.actions.join(',')).assertEqual('hotel.detail,hotel.navigate');
      expect(detail.domain).assertEqual('hotel');
      expect(detail.riskLevel).assertEqual('read');
      expect(detail.backendPriority.join(',')).assertEqual('local_adapter');
      expect(detail.authModes.join(',')).assertEqual('provider_key');
      expect(detail.inputSchema).assertEqual('hotelDetailRequest');
      expect(detail.outputSchema).assertEqual('hotelRatePlans');
      expect(detail.a2uiComponent).assertEqual('GenericToolResults');
      expect(detail.actions.join(',')).assertEqual('hotel.booking.open');
      expect(navigate.riskLevel).assertEqual('read');
      expect(navigate.backendPriority.join(',')).assertEqual('system_intent');
      expect(navigate.authModes.join(',')).assertEqual('system');
      expect(navigate.inputSchema).assertEqual('hotelNavigateRequest');
      expect(navigate.outputSchema).assertEqual('systemIntentResult');
      expect(navigate.actions.length).assertEqual(0);
      expect(booking.riskLevel).assertEqual('draft');
      expect(booking.backendPriority.join(',')).assertEqual('web_session');
      expect(booking.authModes.join(',')).assertEqual('web_session');
      expect(booking.inputSchema).assertEqual('hotelBookingOpenRequest');
      expect(booking.outputSchema).assertEqual('webSessionOpenResult');
      expect(booking.actions.length).assertEqual(0);
      const removedDialActionId = 'hotel.' + 'call';
      expect(toolDefinitionForToolId(removedDialActionId)).assertEqual(null);
      expect(toolDefinitionForToolId('hotel.book')).assertEqual(null);
      expect(toolDefinitionForToolId('hotel.create')).assertEqual(null);
      expect(toolDefinitionForToolId('hotel.status')).assertEqual(null);
      expect(toolDefinitionForToolId('hotel.cancel')).assertEqual(null);
      expect(isRegisteredAiphoneToolId('hotel.search')).assertTrue();
      expect(isRegisteredAiphoneToolId('hotel.detail')).assertTrue();
      expect(isRegisteredAiphoneToolId('hotel.navigate')).assertTrue();
      expect(isRegisteredAiphoneToolId('hotel.booking.open')).assertTrue();
      expect(isRegisteredAiphoneToolId(removedDialActionId)).assertFalse();
      expect(isRegisteredAiphoneToolId('hotel.create')).assertFalse();
      expect(aiphoneToolDefinitionCount()).assertEqual(allToolDefinitions().length);
      expect(JSON.stringify(hotelDefinitions(allAiphoneToolDefinitions())))
        .assertEqual(JSON.stringify(hotelDefinitions(allToolDefinitions())));
      expect(isSurfaceDerivedHotelActionId('hotel.navigate')).assertTrue();
      expect(isSurfaceDerivedHotelActionId('hotel.booking.open')).assertTrue();
      expect(isSurfaceDerivedHotelActionId('hotel.detail')).assertFalse();
    });

    it('gives the model exact structured hotel contracts without order claims', 0, () => {
      const search = aiphoneToolDescriptionForModel('hotel.search');
      const detail = aiphoneToolDescriptionForModel('hotel.detail');
      const navigate = aiphoneToolDescriptionForModel('hotel.navigate');
      const booking = aiphoneToolDescriptionForModel('hotel.booking.open');

      expect(search.indexOf('checkInDate')).assertLarger(-1);
      expect(search.indexOf('stayNights')).assertLarger(-1);
      expect(search.indexOf('adultCount')).assertLarger(-1);
      expect(search.indexOf('roomCount')).assertLarger(-1);
      expect(detail.indexOf('hotelId')).assertLarger(-1);
      expect(detail.indexOf('checkOutDate')).assertLarger(-1);
      expect(detail.indexOf('ratePlanId')).assertLarger(-1);
      expect(detail.indexOf('does not create')).assertLarger(-1);
      expect(navigate).assertEqual('');
      expect(booking).assertEqual('');
    });

    it('registers Calendar writes and Maps POI search explicitly', 0, () => {
      const calendarCreate = toolDefinitionForToolId('calendar.event.create') as ToolDefinition;
      const calendarUpdate = toolDefinitionForToolId('calendar.event.update') as ToolDefinition;
      const mapsSearch = toolDefinitionForToolId('maps.place.search') as ToolDefinition;

      expect(calendarCreate.domain).assertEqual('calendar');
      expect(calendarCreate.riskLevel).assertEqual('confirm_required');
      expect(calendarCreate.backendPriority.join(',')).assertEqual('oauth_api');
      expect(calendarCreate.outputSchema).assertEqual('calendarEvent');
      expect(calendarUpdate.riskLevel).assertEqual('confirm_required');
      expect(isCalendarToolId('calendar.events.search')).assertTrue();
      const calendarDelete = toolDefinitionForToolId('calendar.event.delete') as ToolDefinition;
      const mapsRoute = toolDefinitionForToolId('maps.route.open') as ToolDefinition;
      const whatsappSend = toolDefinitionForToolId('whatsapp.message.send') as ToolDefinition;
      expect(isCalendarToolId('calendar.event.delete')).assertTrue();
      expect(calendarDelete.riskLevel).assertEqual('confirm_required');
      expect(calendarDelete.actions[0]).assertEqual('calendar.event.delete.confirm');
      expect(calendarDelete.inputSchema.indexOf('timeMin')).assertLarger(-1);
      expect(calendarDelete.inputSchema.indexOf('timeMax')).assertLarger(-1);
      expect(calendarDelete.inputSchema.indexOf('confirmed')).assertEqual(-1);
      expect(mapsSearch.domain).assertEqual('maps');
      expect(mapsSearch.authModes.join(',')).assertEqual('provider_key');
      expect(mapsSearch.outputSchema).assertEqual('places');
      expect(isMapsToolId('maps.place.details')).assertTrue();
      expect(isMapsToolId('maps.route.open')).assertTrue();
      expect(mapsRoute.riskLevel).assertEqual('read');
      expect(mapsRoute.actions[0]).assertEqual('maps.open.web');
      expect(whatsappSend.domain).assertEqual('whatsapp');
      expect(whatsappSend.riskLevel).assertEqual('confirm_required');
      expect(whatsappSend.actions[0]).assertEqual('whatsapp.message.send.confirm');
      expect(whatsappSend.inputSchema.indexOf('confirmed')).assertEqual(-1);
    });

    it('exposes only the Calendar read contract to the legacy model loop', 0, () => {
      const searchDescription = aiphoneToolDescriptionForModel('calendar.events.search');
      const createDescription = aiphoneToolDescriptionForModel('calendar.event.create');
      const updateDescription = aiphoneToolDescriptionForModel('calendar.event.update');
      const deleteDescription = aiphoneToolDescriptionForModel('calendar.event.delete');

      expect(searchDescription.indexOf('timeMin')).assertLarger(-1);
      expect(searchDescription.indexOf('timeMax')).assertLarger(-1);
      expect(searchDescription.indexOf('first step before update or delete')).assertEqual(-1);
      expect(searchDescription.indexOf('NEVER use calendar.events.search for a write request')).assertLarger(-1);
      expect(searchDescription.indexOf('query contains only event title text')).assertLarger(-1);
      expect(createDescription).assertEqual('');
      expect(updateDescription).assertEqual('');
      expect(deleteDescription).assertEqual('');
    });

    it('registers Gmail reply send as an exact OAuth confirmation action only', 0, () => {
      const mailSearch = toolDefinitionForToolId('gmail.mail.search') as ToolDefinition;
      const draftApply = toolDefinitionForToolId('gmail.draft.apply') as ToolDefinition;
      const messageSend = toolDefinitionForToolId('gmail.message.send') as ToolDefinition;

      expect(mailSearch.domain).assertEqual('gmail');
      expect(mailSearch.riskLevel).assertEqual('read');
      expect(mailSearch.backendPriority.join(',')).assertEqual('oauth_api,workspace_mcp,web_session');
      expect(mailSearch.authModes.join(',')).assertEqual('oauth,mcp_auth,web_session');
      expect(mailSearch.outputSchema).assertEqual('mailThreads');
      expect(mailSearch.a2uiComponent).assertEqual('GenericToolResults');
      expect(mailSearch.actions[0]).assertEqual('gmail.authorize');
      expect(draftApply.riskLevel).assertEqual('confirm_required');
      expect(messageSend.riskLevel).assertEqual('confirm_required');
      expect(messageSend.backendPriority.join(',')).assertEqual('oauth_api');
      expect(messageSend.authModes.join(',')).assertEqual('oauth');
      expect(messageSend.inputSchema).assertEqual('mailReplyCommand');
      expect(messageSend.outputSchema).assertEqual('mailReplyOperationResult');
      expect(messageSend.actions.length).assertEqual(0);
      expect(GMAIL_TOOL_IDS.indexOf('gmail.message.send') >= 0).assertTrue();
      expect(aiphoneToolDescriptionForModel('gmail.message.send')).assertEqual('');
      expect(aiphoneToolDescriptionForModel('gmail.draft.create').indexOf('create a draft first'))
        .assertLarger(-1);
    });

    it('keeps every public and runtime tool contract semantically aligned', 0, () => {
      const publicDefinitions: ToolDefinition[] = allAiphoneToolDefinitions();
      const runtimeDefinitions: ToolDefinition[] = allToolDefinitions();
      const publicUpdate = publicDefinitions.filter((definition: ToolDefinition): boolean =>
        definition.toolId === 'calendar.event.update')[0];
      const runtimeUpdate = runtimeDefinitions.filter((definition: ToolDefinition): boolean =>
        definition.toolId === 'calendar.event.update')[0];
      const optionalUpdateSchema = 'eventId?:string,query?:string,timeMin?:string,timeMax?:string,' +
        'title?:string,start?:string,end?:string,timezone?:string,calendarId?:string';

      expect(JSON.stringify(publicDefinitions)).assertEqual(JSON.stringify(runtimeDefinitions));
      expect(publicUpdate.inputSchema).assertEqual(optionalUpdateSchema);
      expect(runtimeUpdate.inputSchema).assertEqual(optionalUpdateSchema);
    });

    it('registers aggregate mail tools without enabling send', 0, () => {
      expect(isKnownDomainToolId('mail.search')).assertTrue();
      expect(isKnownDomainToolId('mail.thread.read')).assertTrue();
      expect(isKnownDomainToolId('mail.draft.create')).assertTrue();
      expect(isKnownDomainToolId('mail.message.send')).assertFalse();
      expect(isMailToolId('mail.search')).assertTrue();
      expect(isMailToolId('gmail.mail.search')).assertFalse();

      const mailSearch = toolDefinitionForToolId('mail.search');
      expect(mailSearch !== null).assertTrue();
      if (mailSearch !== null) {
        expect(mailSearch.domain).assertEqual('mail');
        expect(mailSearch.riskLevel).assertEqual('read');
        expect(mailSearch.backendPriority.indexOf('imap') >= 0).assertTrue();
        expect(mailSearch.authModes.indexOf('imap_auth') >= 0).assertTrue();
        expect(mailSearch.a2uiComponent).assertEqual('GenericToolResults');
      }
    });

    it('keeps YouTube public search separate from OAuth account tools', 0, () => {
      const search = toolDefinitionForToolId('youtube.video.search') as ToolDefinition;
      const playlists = toolDefinitionForToolId('youtube.mine.playlists') as ToolDefinition;

      expect(search.domain).assertEqual('youtube');
      expect(search.riskLevel).assertEqual('read');
      expect(search.backendPriority.join(',')).assertEqual('local_adapter');
      expect(search.authModes.join(',')).assertEqual('provider_key');
      expect(search.outputSchema).assertEqual('youtubeVideos');
      expect(search.a2uiComponent).assertEqual('GenericToolResults');
      expect(playlists.backendPriority.join(',')).assertEqual('oauth_api,web_session');
      expect(playlists.authModes.join(',')).assertEqual('oauth,web_session');
    });

    it('registers media video aggregation as a read-only local adapter', 0, () => {
      const media = toolDefinitionForToolId('media.video.search') as ToolDefinition;
      const aggregate = toolDefinitionForToolId('media.aggregate.search') as ToolDefinition;

      expect(media.domain).assertEqual('media');
      expect(media.riskLevel).assertEqual('read');
      expect(media.backendPriority.join(',')).assertEqual('local_adapter');
      expect(media.authModes.join(',')).assertEqual('provider_key');
      expect(media.inputSchema).assertEqual('mediaVideoSearchQuery');
      expect(media.outputSchema).assertEqual('mediaVideos');
      expect(media.a2uiComponent).assertEqual('GenericToolResults');
      expect(media.actions[0]).assertEqual('media.open.web');
      expect(aggregate.domain).assertEqual('media');
      expect(aggregate.riskLevel).assertEqual('read');
      expect(aggregate.backendPriority.join(',')).assertEqual('local_adapter');
      expect(aggregate.authModes.join(',')).assertEqual('provider_key,oauth,mcp_auth');
      expect(aggregate.inputSchema).assertEqual('aggregateMediaSearchQuery');
      expect(aggregate.outputSchema).assertEqual('aggregateSearch');
      expect(aggregate.a2uiComponent).assertEqual('AggregateSearch');
      expect(aggregate.actions[0]).assertEqual('media.open.web');
      expect(isKnownDomainToolId('media.aggregate.search')).assertTrue();
      expect(isMediaToolId('media.aggregate.search')).assertTrue();
    });

    it('registers payment send as a confirm-required local adapter', 0, () => {
      const payment = toolDefinitionForToolId('payment.send') as ToolDefinition;

      expect(isKnownDomainToolId('payment.send')).assertTrue();
      expect(isLocalAdapterToolId('payment.send')).assertTrue();
      expect(isPaymentToolId('payment.send')).assertTrue();
      expect(isRegisteredAiphoneToolId('payment.send')).assertTrue();
      expect(payment.domain).assertEqual('payment');
      expect(payment.riskLevel).assertEqual('confirm_required');
      expect(payment.backendPriority.join(',')).assertEqual('local_adapter');
      expect(payment.authModes.join(',')).assertEqual('provider_key,web_session');
      expect(payment.inputSchema).assertEqual('paymentSendRequest');
      expect(payment.outputSchema).assertEqual('paymentCheckout');
      expect(payment.a2uiComponent).assertEqual('GenericToolResults');
      expect(payment.actions[0]).assertEqual('payment.confirm');
    });

    it('registers ride estimate, app link, and confirmed order tools as local adapters', 0, () => {
      const estimate = toolDefinitionForToolId('ride.estimate') as ToolDefinition;
      const link = toolDefinitionForToolId('ride.app.link') as ToolDefinition;
      const createOrder = toolDefinitionForToolId('ride.order.create') as ToolDefinition;
      const cancelOrder = toolDefinitionForToolId('ride.order.cancel') as ToolDefinition;
      const driverLocation = toolDefinitionForToolId('ride.driver.location') as ToolDefinition;

      expect(estimate.domain).assertEqual('ride');
      expect(estimate.riskLevel).assertEqual('read');
      expect(estimate.backendPriority.join(',')).assertEqual('local_adapter');
      expect(estimate.authModes.join(',')).assertEqual('provider_key,mcp_auth');
      expect(estimate.inputSchema).assertEqual('rideRouteQuery');
      expect(estimate.outputSchema).assertEqual('genericToolResults');
      expect(estimate.a2uiComponent).assertEqual('GenericToolResults');
      expect(estimate.actions[0]).assertEqual('ride.order.confirm');
      expect(estimate.actions[1]).assertEqual('ride.open.didi');
      expect(estimate.actions[2]).assertEqual('ride.open.amap');
      expect(link.domain).assertEqual('ride');
      expect(link.riskLevel).assertEqual('read');
      expect(createOrder.domain).assertEqual('ride');
      expect(createOrder.riskLevel).assertEqual('confirm_required');
      expect(createOrder.actions[0]).assertEqual('ride.driver.location.refresh');
      expect(createOrder.actions[1]).assertEqual('ride.order.cancel');
      expect(cancelOrder.domain).assertEqual('ride');
      expect(cancelOrder.riskLevel).assertEqual('confirm_required');
      expect(cancelOrder.actions[0]).assertEqual('ride.query.retry');
      expect(cancelOrder.actions[1]).assertEqual('ride.vehicle.change');
      expect(driverLocation.domain).assertEqual('ride');
      expect(driverLocation.riskLevel).assertEqual('read');
      expect(driverLocation.actions[0]).assertEqual('ride.driver.location.refresh');
      expect(driverLocation.actions[1]).assertEqual('ride.order.cancel');
      expect(isLocalAdapterToolId('ride.estimate')).assertTrue();
      expect(isLocalAdapterToolId('ride.app.link')).assertTrue();
      expect(isLocalAdapterToolId('ride.order.create')).assertTrue();
      expect(isLocalAdapterToolId('ride.order.cancel')).assertTrue();
      expect(isLocalAdapterToolId('ride.driver.location')).assertTrue();
      expect(isRegisteredAiphoneToolId('ride.estimate')).assertTrue();
    });

    it('registers Luckin order tools as local adapters with confirmation boundary', 0, () => {
      const preview = toolDefinitionForToolId('luckin.order.preview') as ToolDefinition;
      const create = toolDefinitionForToolId('luckin.order.create') as ToolDefinition;
      const status = toolDefinitionForToolId('luckin.order.status') as ToolDefinition;

      expect(preview.domain).assertEqual('luckin');
      expect(preview.riskLevel).assertEqual('draft');
      expect(preview.backendPriority.join(',')).assertEqual('local_adapter');
      expect(preview.outputSchema).assertEqual('genericToolResults');
      expect(preview.actions[0]).assertEqual('luckin.order.create');
      expect(create.riskLevel).assertEqual('confirm_required');
      expect(create.actions[0]).assertEqual('luckin.order.status');
      expect(status.riskLevel).assertEqual('read');
    });

    it('resolves available Gmail backends before returning an auth-needed reason', 0, () => {
      const webFallback: BackendResolution = resolveBackendForTool('gmail.mail.search', [
        availability('oauth_api', false, 'OAuth API sign-in is required.', 'u***@gmail.com'),
        availability('workspace_mcp', false, 'Workspace MCP auth is required.', ''),
        availability('web_session', true, '', 'browser-session')
      ] as BackendAvailability[]);

      expect(webFallback.ok).assertTrue();
      expect(webFallback.backend).assertEqual('web_session');
      expect(webFallback.accountHint).assertEqual('browser-session');

      const missing: BackendResolution = resolveBackendForTool('gmail.mail.search', [
        availability('oauth_api', false, 'OAuth API sign-in is required.', 'u***@gmail.com'),
        availability('web_session', false, 'Gmail Web session is not connected.', '')
      ] as BackendAvailability[]);

      expect(missing.ok).assertFalse();
      expect(missing.backend).assertEqual('oauth_api');
      expect(missing.reason).assertEqual('OAuth API sign-in is required.');
      expect(missing.accountHint).assertEqual('u***@gmail.com');
    });

    it('clones definitions and labels runner types stably', 0, () => {
      const definitions: ToolDefinition[] = allToolDefinitions();
      definitions[0].toolId = 'mutated.tool';
      definitions[0].backendPriority.push('web_session');

      const fresh: ToolDefinition[] = allToolDefinitions();
      expect(fresh[0].toolId).assertEqual('travel.search');
      expect(fresh[0].backendPriority.join(',')).assertEqual('local_adapter');
      expect(backendLabel('local_adapter')).assertEqual('Local adapter');
      expect(backendLabel('oauth_api')).assertEqual('OAuth API');
      expect(backendLabel('imap')).assertEqual('IMAP');
      expect(backendLabel('workspace_mcp')).assertEqual('Workspace MCP');
      expect(backendLabel('web_session')).assertEqual('Web session');
      expect(backendLabel('system_intent')).assertEqual('System intent');
      expect(backendLabel('mcp_remote')).assertEqual('Remote MCP');
    });

    it('derives disjoint cloned Data and Action capability views from the registry', 0, () => {
      const all: ToolDefinition[] = allToolDefinitions();
      const data: ToolDefinition[] = dataAgentToolDefinitions();
      const action: ToolDefinition[] = actionAgentToolDefinitions();
      const ids: string[] = data.concat(action).map((item: ToolDefinition): string => item.toolId);

      expect(all.length).assertEqual(44);
      expect(data.length).assertEqual(24);
      expect(action.length).assertEqual(20);
      expect(new Set<string>(ids).size).assertEqual(44);
      expect(all.filter((item: ToolDefinition): boolean => item.riskLevel === 'blocked').length)
        .assertEqual(0);
      expect(ids.indexOf('hotel.navigate') >= 0).assertTrue();
      expect(data.map((item: ToolDefinition): string => item.toolId).indexOf('hotel.navigate')).assertEqual(-1);
      expect(ids.indexOf('dynamic.search')).assertEqual(-1);
      expect(ids.indexOf('memory.update')).assertEqual(-1);

      data[0].toolId = 'mutated.tool';
      data[0].backendPriority.push('web_session');
      const laterData: ToolDefinition[] = dataAgentToolDefinitions();
      expect(laterData[0].toolId).assertEqual('travel.search');
      expect(laterData[0].backendPriority.join(',')).assertEqual('local_adapter');
    });
  });
}
