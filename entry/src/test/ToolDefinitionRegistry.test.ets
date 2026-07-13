import { describe, it, expect } from '@ohos/hypium';
import {
  GMAIL_TOOL_IDS,
  allToolDefinitions,
  backendLabel,
  isCalendarToolId,
  isGmailToolId,
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

export default function toolDefinitionRegistryTest() {
  describe('toolDefinitionRegistry', () => {
    it('recognizes existing local adapters and Gmail tools through one registry', 0, () => {
      expect(isKnownDomainToolId('travel.search')).assertTrue();
      expect(isKnownDomainToolId('food.search')).assertTrue();
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
      expect(isKnownDomainToolId('maps.place.search')).assertTrue();
      expect(isKnownDomainToolId('maps.place.details')).assertTrue();
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
      expect(isCalendarToolId('calendar.event.delete')).assertFalse();
      expect(mapsSearch.domain).assertEqual('maps');
      expect(mapsSearch.authModes.join(',')).assertEqual('provider_key');
      expect(mapsSearch.outputSchema).assertEqual('places');
      expect(isMapsToolId('maps.place.details')).assertTrue();
      expect(toolDefinitionForToolId('maps.route.plan')).assertEqual(null);
      expect(toolDefinitionForToolId('calendar.event.delete')).assertEqual(null);
    });

    it('keeps Gmail definitions declarative and direct send blocked', 0, () => {
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
      expect(messageSend.riskLevel).assertEqual('blocked');
      expect(messageSend.outputSchema).assertEqual('blockedAction');
      expect(GMAIL_TOOL_IDS.indexOf('gmail.message.send') >= 0).assertTrue();
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
  });
}
