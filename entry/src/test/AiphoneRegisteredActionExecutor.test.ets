import { describe, it, expect } from '@ohos/hypium';
import {
  ActionArgsValidator,
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionPlan,
  ActionPlanPausedOutcome,
  ActionPlanRunContext,
  ActionPlanRunner,
  ActionValidationResult,
  A2uiCallResult,
  A2uiRuntimeDataModel,
  ClientActionAuthorizer,
  HotelBookingOpenArgs,
  HotelNavigateArgs,
  SurfaceActionAuthorizer,
  ToolDefinition,
  ToolDefinitionLookup,
  actionAgentToolDefinitions,
  createSeedA2uiSurface,
  toolDefinitionForToolId,
  validateHotelActionArgs
} from '@loop/agent-core';
import {
  AiphoneRegisteredActionExecutor,
  HotelActionIdFactory,
  RegisteredPageAction,
  RegisteredPageActionContext,
  SystemUriOpener,
  validateGmailReplyActionArgs,
  validateRegisteredPageActionArgs
} from '../main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor';
import {
  RegisteredPageActionHandler,
  RegisteredPageToolInvocation,
  RegisteredPageToolInvoker
} from '../main/ets/pages/A2uiHome/agent/RegisteredPageActionHandler';
import { isFixedRegisteredPageAction } from '../main/ets/pages/A2uiHome/agent/RegisteredPageActionRoute';

function object(raw: string): Object {
  return JSON.parse(raw) as Object;
}

function definition(toolId: string): ToolDefinition {
  return {
    toolId: toolId,
    domain: 'hotel',
    intent: toolId,
    riskLevel: toolId === 'hotel.booking.open' ? 'draft' : 'read',
    backendPriority: [toolId === 'hotel.detail' ? 'local_adapter' : (toolId === 'hotel.booking.open' ? 'web_session' : 'system_intent')],
    authModes: [toolId === 'hotel.detail' ? 'provider_key' : (toolId === 'hotel.booking.open' ? 'web_session' : 'system')],
    inputSchema: toolId === 'hotel.booking.open' ? 'hotelBookingOpenRequest' : toolId + 'Request',
    outputSchema: toolId === 'hotel.detail' ? 'hotelRatePlans' : (toolId === 'hotel.booking.open' ? 'webSessionOpenResult' : 'systemIntentResult'),
    a2uiComponent: 'GenericToolResults',
    actions: []
  };
}

class RegisteredDefinitions implements ToolDefinitionLookup {
  constructor(_sourceToolId: string = '', _actionId: string = '') {
  }

  find(toolId: string): ToolDefinition | null {
    if (toolId === 'hotel.search') {
      const source = definition(toolId);
      source.actions = ['hotel.detail', 'hotel.navigate'];
      return source;
    }
    if (toolId === 'hotel.detail' || toolId === 'hotel.navigate' || toolId === 'hotel.booking.open') {
      const source = definition(toolId);
      if (toolId === 'hotel.detail') {
        source.actions = ['hotel.booking.open'];
      }
      return source;
    }
    const registered = toolDefinitionForToolId(toolId);
    if (registered === null) {
      return null;
    }
    return registered;
  }
}

class ExactSurface implements SurfaceActionAuthorizer {
  private actionId: string;
  private serializedArgs: string;

  constructor(actionId: string, args: Object) {
    this.actionId = actionId;
    this.serializedArgs = JSON.stringify(args);
  }

  allows(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    actionId: string,
    args: Object
  ): boolean {
    return conversationId === 'conversation-1' &&
      turnId === 'turn-1' &&
      surfaceId === 'surface-1' &&
      actionId === this.actionId &&
      JSON.stringify(args) === this.serializedArgs;
  }
}

class MutableExactSurface implements SurfaceActionAuthorizer {
  conversationId: string = 'conversation-1';
  turnId: string = 'turn-1';
  surfaceId: string = 'surface-1';
  actionId: string;
  serializedArgs: string;

  constructor(actionId: string, args: Object) {
    this.actionId = actionId;
    this.serializedArgs = JSON.stringify(args);
  }

  allows(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    actionId: string,
    args: Object
  ): boolean {
    return conversationId === this.conversationId &&
      turnId === this.turnId &&
      surfaceId === this.surfaceId &&
      actionId === this.actionId &&
      JSON.stringify(args) === this.serializedArgs;
  }
}

class NoClientAction implements ClientActionAuthorizer {
  allows(_actionId: string, _args: Object): boolean {
    return false;
  }
}

class RegisteredArgsValidator implements ActionArgsValidator {
  validate(actionId: string, args: Object): ActionValidationResult {
    if (actionId === 'gmail.message.send') {
      return validateGmailReplyActionArgs(args);
    }
    if (actionId.indexOf('hotel.') === 0) {
      return validateHotelActionArgs(actionId, args);
    }
    return validateRegisteredPageActionArgs(actionId, args);
  }
}

class FakeUriOpener implements SystemUriOpener {
  opened: boolean = true;
  uris: string[] = [];

  async open(uri: string): Promise<boolean> {
    this.uris.push(uri);
    return this.opened;
  }
}

class RuntimeValueUriOpener implements SystemUriOpener {
  rawValue: string;
  calls: number = 0;

  constructor(rawValue: string) {
    this.rawValue = rawValue;
  }

  async open(_uri: string): Promise<boolean> {
    this.calls += 1;
    return JSON.parse(this.rawValue) as boolean;
  }
}

class RejectingUriOpener implements SystemUriOpener {
  calls: number = 0;

  async open(_uri: string): Promise<boolean> {
    this.calls += 1;
    throw new Error('system rejected URI');
  }
}

class DeterministicIds implements HotelActionIdFactory {
  next: number = 0;

  nextId(prefix: string): string {
    this.next += 1;
    return prefix + '-' + this.next.toString();
  }
}

interface PageCall {
  actionId: string;
  args: Object;
  context: ActionExecutionContext;
}

class RecordingPageAction {
  calls: PageCall[] = [];
  result: ActionExecutionResult = {
    status: 'success',
    output: object('{"receipt":"provider-receipt-1","status":"draft_saved"}')
  };
  shouldThrow: boolean = false;
  returnFalse: boolean = false;

  async execute(
    actionId: string,
    args: Object,
    executionContext: ActionExecutionContext
  ): Promise<ActionExecutionResult> {
    this.calls.push({ actionId, args, context: executionContext });
    if (this.shouldThrow) {
      throw new Error('page handler failed');
    }
    if (this.returnFalse) {
      return JSON.parse('false') as ActionExecutionResult;
    }
    return this.result;
  }
}

interface CalendarProviderCall {
  toolId: string;
  pageActionId: string;
  args: Object;
}

class CalendarLifecycleInvoker implements RegisteredPageToolInvoker {
  calls: CalendarProviderCall[] = [];
  failingToolId: string = '';

  async invoke(
    toolId: string,
    _prompt: string,
    pageActionId: string,
    args: Object
  ): Promise<RegisteredPageToolInvocation> {
    this.calls.push({ toolId, pageActionId, args });
    if (toolId === this.failingToolId) {
      return { ok: false, result: null, error: 'Calendar provider failed.' };
    }
    const result = createSeedA2uiSurface();
    const model = JSON.parse(result.dataModelJson) as A2uiRuntimeDataModel;
    model.genericToolResults = [{
      sourceTag: 'Composio Google Calendar',
      toolName: toolId,
      title: toolId,
      status: 'success',
      summary: 'Provider confirmed Calendar write.',
      rows: [{ label: 'Event ID', value: 'event-provider-real-1' }],
      rawPreview: '{"successful":true}'
    }];
    result.surfaceId = 'calendar-result-' + this.calls.length.toString();
    result.status = 'ready';
    result.dataModelJson = JSON.stringify(model);
    const callResult: A2uiCallResult = {
      ok: true,
      raw: '{}',
      error: '',
      requestDebug: '',
      assistantDebug: '',
      surface: result
    };
    return { ok: true, result: callResult, error: '' };
  }
}

function pageCallback(recorder: RecordingPageAction): RegisteredPageAction {
  return (
    actionId: string,
    args: Object,
    executionContext: ActionExecutionContext
  ): Promise<ActionExecutionResult> => recorder.execute(actionId, args, executionContext);
}

function catalog(
  actionId: string,
  args: Object,
  sourceToolId: string = ''
): ActionCatalog {
  return new ActionCatalog(
    new RegisteredDefinitions(sourceToolId, actionId),
    new ExactSurface(actionId, args),
    new NoClientAction(),
    new RegisteredArgsValidator()
  );
}

function context(sourceToolId: string = 'hotel.search', isSurfaceEntry?: boolean): ActionExecutionContext {
  return {
    conversationId: 'conversation-1',
    turnId: 'turn-1',
    surfaceId: 'surface-1',
    sourceToolId: sourceToolId,
    planId: 'plan-1',
    runId: 'run-1',
    stepId: 'step-1',
    isSurfaceEntry: isSurfaceEntry
  };
}

function pageContext(pageActionId: string, sourceToolId: string = pageActionId): ActionExecutionContext {
  const current = context(sourceToolId);
  current.pageActionId = pageActionId;
  return current;
}

function navigateArgs(): HotelNavigateArgs {
  return {
    hotelId: 47675,
    name: '深圳测试酒店',
    address: '深圳市南山区科技南路 88 号',
    latitude: 22.5431,
    longitude: 114.0579
  };
}

function bookingArgs(): HotelBookingOpenArgs {
  return {
    hotelId: 47675,
    bookingUrl: 'https://rollinggo.cn/pages/hotel/detail/index?id=47675&' +
      'checkInDate=2026-08-15&checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0'
  };
}

function wave4Args(actionId: string): Object {
  if (actionId === 'luckin.order.create') {
    return object('{"deptId":"store-1","productId":"product-1","skuCode":"sku-1"}');
  }
  if (actionId === 'calendar.event.create') {
    return object('{"title":"QA","start":"2026-07-29T15:00:00+08:00",' +
      '"end":"2026-07-29T15:30:00+08:00"}');
  }
  if (actionId === 'calendar.event.update') {
    return object('{"eventId":"event-1","title":"QA","start":"2026-07-29T16:00:00+08:00",' +
      '"end":"2026-07-29T16:30:00+08:00"}');
  }
  if (actionId === 'calendar.event.delete') {
    return object('{"eventId":"event-1","calendarId":"primary"}');
  }
  if (actionId === 'whatsapp.message.send') {
    return object('{"toNumber":"+8613800138000","text":"QA"}');
  }
  if (actionId === 'ride.order.create') {
    return object('{"productCategory":"express","estimateTraceId":"trace-1"}');
  }
  return object('{"orderId":"order-1"}');
}

async function executeTampered(
  expected: Object,
  actionId: string,
  tampered: Object,
  opener: FakeUriOpener
): Promise<ActionExecutionResult> {
  const executor = new AiphoneRegisteredActionExecutor(
    catalog(actionId, expected),
    opener,
    new DeterministicIds(),
    pageCallback(new RecordingPageAction())
  );
  return executor.execute(actionId, tampered, actionId === 'hotel.booking.open' ? context('hotel.detail') : context());
}

function pageExecutor(
  actionId: string,
  args: Object,
  recorder: RecordingPageAction,
  opener: FakeUriOpener = new FakeUriOpener(),
  sourceToolId: string = 'hotel.search'
): AiphoneRegisteredActionExecutor {
  return new AiphoneRegisteredActionExecutor(
    catalog(actionId, args, sourceToolId),
    opener,
    new DeterministicIds(),
    pageCallback(recorder)
  );
}

export default function aiphoneRegisteredActionExecutorTest() {
  describe('aiphoneRegisteredActionExecutor', () => {
    it('opens one exact Petal Maps URI only after current catalog validation', 0, async () => {
      const args = navigateArgs();
      const opener = new FakeUriOpener();
      const executor = new AiphoneRegisteredActionExecutor(
        catalog('hotel.navigate', args),
        opener,
        new DeterministicIds(),
        pageCallback(new RecordingPageAction())
      );

      const result = await executor.execute('hotel.navigate', args, context());

      expect(result.status).assertEqual('success');
      expect(opener.uris.length).assertEqual(1);
      expect(opener.uris[0]).assertEqual(
        'petalmaps://poidetail?center=22.5431,114.0579&z=16&marker=22.5431,114.0579&' +
        'name=%E6%B7%B1%E5%9C%B3%E6%B5%8B%E8%AF%95%E9%85%92%E5%BA%97&' +
        'utm_source=com.example.aiphonedemo'
      );
    });

    it('opens the registered RollingGo booking URL once', 0, async () => {
      const args = bookingArgs();
      const opener = new FakeUriOpener();
      const executor = new AiphoneRegisteredActionExecutor(
        catalog('hotel.booking.open', args),
        opener,
        new DeterministicIds(),
        pageCallback(new RecordingPageAction())
      );

      const result = await executor.execute('hotel.booking.open', args, context('hotel.detail'));
      const serialized = JSON.stringify(result);

      expect(result.status).assertEqual('success');
      expect(opener.uris.join(',')).assertEqual(args.bookingUrl);
      expect(serialized.indexOf('RollingGo booking opened')).assertLarger(-1);
    });

    it('allows a registered booking action after a prior composite step', 0, async () => {
      const args = bookingArgs();
      const opener = new FakeUriOpener();
      const executor = new AiphoneRegisteredActionExecutor(
        catalog('hotel.booking.open', args),
        opener,
        new DeterministicIds(),
        pageCallback(new RecordingPageAction())
      );

      const entry = context('hotel.detail');
      const entryResult = await executor.execute('hotel.booking.open', args, entry);
      const later = context('hotel.search', false);
      later.sourceToolId = 'hotel.detail';
      later.stepId = 'step-2';
      const result = await executor.execute(
        'hotel.booking.open',
        args,
        later
      );

      expect(entryResult.status).assertEqual('success');
      expect(result.status).assertEqual('success');
      expect(opener.uris.length).assertEqual(2);
    });

    it('rejects tampered booking URL and hotel ID before opening', 0, async () => {
      const opener = new FakeUriOpener();
      const booking = bookingArgs();
      const tamperedUrl = bookingArgs();
      tamperedUrl.bookingUrl = tamperedUrl.bookingUrl.replace('rollinggo.cn', 'evil.example');
      const tamperedHotel = bookingArgs();
      tamperedHotel.hotelId = 99999;
      const navigate = navigateArgs();
      const tamperedCoordinate = navigateArgs();
      tamperedCoordinate.latitude = 22.6;
      const tamperedNavigateHotel = navigateArgs();
      tamperedNavigateHotel.hotelId = 99999;

      expect((await executeTampered(booking, 'hotel.booking.open', tamperedUrl, opener)).status)
        .assertEqual('error');
      expect((await executeTampered(booking, 'hotel.booking.open', tamperedHotel, opener)).status)
        .assertEqual('error');
      expect((await executeTampered(navigate, 'hotel.navigate', tamperedCoordinate, opener)).status)
        .assertEqual('error');
      expect((await executeTampered(navigate, 'hotel.navigate', tamperedNavigateHotel, opener)).status)
        .assertEqual('error');
      expect(opener.uris.length).assertEqual(0);
    });

    it('returns one paired typed detail follow-up and preserves exact query args', 0, async () => {
      const args = object(
        '{"hotelId":47675,"checkInDate":"2026-08-15","checkOutDate":"2026-08-17",' +
        '"countryCode":"CN","currency":"CNY","adultCount":2,"childCount":1,' +
        '"childAgeDetails":[8],"roomCount":1}'
      );
      const opener = new FakeUriOpener();
      const executor = new AiphoneRegisteredActionExecutor(
        catalog('hotel.detail', args),
        opener,
        new DeterministicIds(),
        pageCallback(new RecordingPageAction())
      );

      const result = await executor.execute('hotel.detail', args, context());
      const serialized = JSON.stringify(result);

      expect(result.status).assertEqual('success');
      expect(opener.uris.length).assertEqual(0);
      expect(serialized.indexOf('"taskId":"hotel-detail-data-1"')).assertLarger(-1);
      expect(serialized.indexOf('"taskId":"hotel-detail-ui-2"')).assertLarger(-1);
      expect(serialized.indexOf('"dataTaskIds":["hotel-detail-data-1"]')).assertLarger(-1);
      expect(serialized.indexOf('"toolId":"hotel.detail"')).assertLarger(-1);
      expect(serialized.indexOf('"outputSchema":"hotelRatePlans"')).assertLarger(-1);
      expect(serialized.indexOf(JSON.stringify(args))).assertLarger(-1);
      expect(serialized.indexOf('turnId')).assertEqual(-1);
    });

    it('rejects unregistered booking without opening a URI', 0, async () => {
      const args = object('{"hotelId":47675,"ratePlanId":"real-rate"}');
      const opener = new FakeUriOpener();
      const executor = new AiphoneRegisteredActionExecutor(
        catalog('hotel.book', args),
        opener,
        new DeterministicIds(),
        pageCallback(new RecordingPageAction())
      );

      const result = await executor.execute('hotel.book', args, context());

      expect(result.status).assertEqual('error');
      expect(opener.uris.length).assertEqual(0);
    });

    it('returns an error when the system rejects the URI', 0, async () => {
      const args = navigateArgs();
      const opener = new FakeUriOpener();
      opener.opened = false;
      const executor = new AiphoneRegisteredActionExecutor(
        catalog('hotel.navigate', args),
        opener,
        new DeterministicIds(),
        pageCallback(new RecordingPageAction())
      );

      const result = await executor.execute('hotel.navigate', args, context());

      expect(result.status).assertEqual('error');
      expect(opener.uris.length).assertEqual(1);
      expect(JSON.stringify(result).indexOf('OPEN_FAILED')).assertLarger(-1);
    });

    it('accepts only the exact boolean true from the runtime opener', 0, async () => {
      const args = navigateArgs();
      const values: string[] = ['"true"', '1', '{}'];
      for (let index = 0; index < values.length; index++) {
        const opener = new RuntimeValueUriOpener(values[index]);
        const executor = new AiphoneRegisteredActionExecutor(
          catalog('hotel.navigate', args),
          opener,
          new DeterministicIds(),
          pageCallback(new RecordingPageAction())
        );

        const result = await executor.execute('hotel.navigate', args, context());

        expect(result.status).assertEqual('error');
        expect(opener.calls).assertEqual(1);
      }
    });

    it('contains a rejected opener promise as one typed error', 0, async () => {
      const args = navigateArgs();
      const opener = new RejectingUriOpener();
      const executor = new AiphoneRegisteredActionExecutor(
        catalog('hotel.navigate', args),
        opener,
        new DeterministicIds(),
        pageCallback(new RecordingPageAction())
      );

      const result = await executor.execute('hotel.navigate', args, context());

      expect(result.status).assertEqual('error');
      expect(opener.calls).assertEqual(1);
      expect(JSON.stringify(result).indexOf('OPEN_FAILED')).assertLarger(-1);
    });

    it('routes gmail draft create once with exact args context and provider output', 0, async () => {
      const args = object(
        '{"provider":"gmail","threadId":"thread-real-1","messageId":"message-real-1",' +
        '"requestKey":"gmail:thread-real-1","to":"alice@example.com",' +
        '"subject":"Re: QA","body":"Reviewed draft"}'
      );
      const recorder = new RecordingPageAction();
      const executor = pageExecutor('gmail.draft.create', args, recorder, new FakeUriOpener(), 'gmail.thread.read');

      const result = await executor.execute('gmail.draft.create', args, context('gmail.thread.read'));

      expect(result.status).assertEqual('success');
      expect(recorder.calls.length).assertEqual(1);
      expect(recorder.calls[0].actionId).assertEqual('gmail.draft.create');
      expect(JSON.stringify(recorder.calls[0].args)).assertEqual(JSON.stringify(args));
      expect(recorder.calls[0].context.runId).assertEqual('run-1');
      expect(JSON.stringify(result)).assertEqual(JSON.stringify(recorder.result));
    });

    it('routes payment send once without changing recipient amount provider or receipt', 0, async () => {
      const args = object(
        '{"provider":"paypal","fundingSource":"google_pay","recipient":"real-user",' +
        '"amountText":"5.00","currency":"USD","orderId":"order-real-1"}'
      );
      const recorder = new RecordingPageAction();
      recorder.result = {
        status: 'success',
        output: object('{"receipt":"paypal-receipt-real-1","status":"approved"}')
      };
      const executor = pageExecutor('payment.send', args, recorder, new FakeUriOpener(), 'payment.send');

      const result = await executor.execute('payment.send', args, pageContext('payment.send'));

      expect(result.status).assertEqual('success');
      expect(recorder.calls.length).assertEqual(1);
      expect(JSON.stringify(recorder.calls[0].args)).assertEqual(JSON.stringify(args));
      expect(JSON.stringify(result)).assertEqual(JSON.stringify(recorder.result));
    });

    it('routes maps route open once with exact endpoints and provider output', 0, async () => {
      const args = object(
        '{"origin":"Shenzhen North Station","destination":"Hong Kong West Kowloon",' +
        '"travelMode":"transit","navigate":true}'
      );
      const recorder = new RecordingPageAction();
      const executor = pageExecutor('maps.route.open', args, recorder, new FakeUriOpener(), 'maps.route.open');

      const result = await executor.execute('maps.route.open', args, pageContext('maps.route.open'));

      expect(result.status).assertEqual('success');
      expect(recorder.calls.length).assertEqual(1);
      expect(JSON.stringify(recorder.calls[0].args)).assertEqual(JSON.stringify(args));
      expect(JSON.stringify(result)).assertEqual(JSON.stringify(recorder.result));
    });

    it('routes one exact confirmed Gmail reply send and rejects its replay', 0, async () => {
      const args = object(
        '{"requestKey":"gmail:thread-real-1","provider":"gmail","accountLabel":"g***@gmail.com",' +
        '"threadId":"thread-real-1","messageId":"message-real-1","to":["alice@example.com"],' +
        '"subject":"Re: QA","body":"Exact reply","replyMode":"reply","contextSummary":"QA"}'
      );
      const recorder = new RecordingPageAction();
      const executor = pageExecutor(
        'gmail.message.send', args, recorder, new FakeUriOpener(), 'gmail.thread.read'
      );

      const first = await executor.execute(
        'gmail.message.send', args, pageContext('html_mail_reply_send', 'gmail.thread.read')
      );
      const replay = await executor.execute(
        'gmail.message.send', args, pageContext('html_mail_reply_send', 'gmail.thread.read')
      );

      expect(first.status).assertEqual('success');
      expect(replay.status).assertEqual('error');
      expect(JSON.stringify(replay).indexOf('DUPLICATE')).assertLarger(-1);
      expect(recorder.calls.length).assertEqual(1);
      expect(recorder.calls[0].actionId).assertEqual('gmail.message.send');
      expect((recorder.calls[0].context as RegisteredPageActionContext).pageActionId)
        .assertEqual('html_mail_reply_send');
    });

    it('rejects Gmail reply provider mismatch before the page provider callback', 0, async () => {
      const args = object(
        '{"requestKey":"qq:message-real-1","provider":"qq","accountLabel":"q***@qq.com",' +
        '"threadId":"thread-real-1","messageId":"message-real-1","to":["alice@example.com"],' +
        '"subject":"Re: QA","body":"Exact reply","replyMode":"reply","contextSummary":"QA"}'
      );
      const recorder = new RecordingPageAction();
      const executor = pageExecutor(
        'gmail.message.send', args, recorder, new FakeUriOpener(), 'mail.search'
      );

      const result = await executor.execute(
        'gmail.message.send', args, pageContext('html_mail_reply_send', 'mail.search')
      );

      expect(result.status).assertEqual('error');
      expect(recorder.calls.length).assertEqual(0);
    });

    it('surfaces the real Gmail reply provider error without a success receipt', 0, async () => {
      const args = object(
        '{"requestKey":"gmail:thread-real-1","provider":"gmail","accountLabel":"g***@gmail.com",' +
        '"threadId":"thread-real-1","messageId":"message-real-1","to":["alice@example.com"],' +
        '"subject":"Re: QA","body":"Exact reply","replyMode":"reply","contextSummary":"QA"}'
      );
      const recorder = new RecordingPageAction();
      recorder.result = {
        status: 'error',
        errorCode: 'GMAIL_AUTH_REQUIRED',
        message: 'Gmail OAuth account is not connected.'
      };
      const executor = pageExecutor(
        'gmail.message.send', args, recorder, new FakeUriOpener(), 'gmail.mail.search'
      );

      const result = await executor.execute(
        'gmail.message.send', args, pageContext('html_mail_reply_send', 'gmail.mail.search')
      );

      expect(JSON.stringify(result)).assertEqual(JSON.stringify(recorder.result));
      expect(JSON.stringify(result).indexOf('provider-receipt')).assertEqual(-1);
      expect(recorder.calls.length).assertEqual(1);
    });

    it('routes every current Wave 3 draft preview system and Web action explicitly', 0, async () => {
      const actionIds: string[] = [
        'luckin.order.preview',
        'social.reply.draft',
        'mail.draft.create',
        'gmail.draft.apply',
        'gmail.open.web',
        'worldcup.open',
        'payment.account.setup'
      ];
      for (let index = 0; index < actionIds.length; index++) {
        const actionId = actionIds[index];
        const args = object('{"marker":"exact-' + index.toString() + '"}');
        const recorder = new RecordingPageAction();
        const executor = pageExecutor(actionId, args, recorder, new FakeUriOpener(), actionId);
        const result = await executor.execute(actionId, args, pageContext(actionId));

        expect(result.status).assertEqual('success');
        expect(recorder.calls.length).assertEqual(1);
        expect(recorder.calls[0].actionId).assertEqual(actionId);
        expect(JSON.stringify(recorder.calls[0].args)).assertEqual(JSON.stringify(args));
      }
    });

    it('gives every fixed Action definition one explicit executable owner route', 0, () => {
      const expected: string[] = [
        'hotel.navigate', 'hotel.booking.open', 'luckin.order.preview', 'luckin.order.create',
        'social.reply.draft', 'mail.draft.create', 'gmail.draft.create', 'gmail.draft.apply',
        'gmail.open.web', 'gmail.message.send', 'worldcup.open', 'calendar.event.create',
        'calendar.event.update', 'calendar.event.delete', 'payment.send', 'payment.account.setup',
        'maps.route.open', 'whatsapp.message.send', 'ride.order.create', 'ride.order.cancel'
      ];
      const definitions = actionAgentToolDefinitions();

      expect(definitions.length).assertEqual(20);
      expect(definitions.map((current: ToolDefinition): string => current.toolId).sort().join(','))
        .assertEqual(expected.slice().sort().join(','));
      for (let index = 0; index < expected.length; index++) {
        expect(isFixedRegisteredPageAction(expected[index])).assertTrue();
      }
    });

    it('rejects incomplete registered write args before any page provider callback', 0, async () => {
      const actionIds: string[] = [
        'luckin.order.create', 'calendar.event.create', 'calendar.event.update',
        'calendar.event.delete', 'whatsapp.message.send', 'ride.order.create', 'ride.order.cancel'
      ];
      for (let index = 0; index < actionIds.length; index++) {
        const recorder = new RecordingPageAction();
        const executor = pageExecutor(
          actionIds[index], object('{}'), recorder, new FakeUriOpener(), actionIds[index]
        );
        const result = await executor.execute(
          actionIds[index], object('{}'), pageContext(actionIds[index], actionIds[index])
        );
        expect(result.status).assertEqual('error');
        expect(recorder.calls.length).assertEqual(0);
      }
    });

    it('routes every Wave 4 write through the registered page callback', 0, async () => {
      const actionIds: string[] = [
        'luckin.order.create',
        'calendar.event.create',
        'calendar.event.update',
        'calendar.event.delete',
        'whatsapp.message.send',
        'ride.order.create',
        'ride.order.cancel'
      ];
      for (let index = 0; index < actionIds.length; index++) {
        const actionId = actionIds[index];
        const args = wave4Args(actionId);
        const recorder = new RecordingPageAction();
        const executor = pageExecutor(actionId, args, recorder, new FakeUriOpener(), actionId);
        const result = await executor.execute(actionId, args, pageContext(actionId));

        expect(result.status).assertEqual('success');
        expect(recorder.calls.length).assertEqual(1);
        expect(recorder.calls[0].actionId).assertEqual(actionId);
      }
    });

    it('binds the production Calendar handler eventId through create update and delete', 0, async () => {
      const createArgs = object(
        '{"title":"Appless QA","start":"2026-07-29T15:00:00+08:00",' +
        '"end":"2026-07-29T15:30:00+08:00","calendarId":"primary"}'
      );
      const currentCatalog = catalog('calendar.event.create', createArgs, 'calendar.event.create');
      const invoker = new CalendarLifecycleInvoker();
      const handler = new RegisteredPageActionHandler(invoker);
      const executor = new AiphoneRegisteredActionExecutor(
        currentCatalog,
        new FakeUriOpener(),
        new DeterministicIds(),
        (
          actionId: string,
          args: Object,
          executionContext: RegisteredPageActionContext
        ): Promise<ActionExecutionResult> => handler.execute(actionId, args, executionContext)
      );
      const runner = new ActionPlanRunner(currentCatalog, executor);
      const actionPlan = object(
        '{"planId":"calendar-lifecycle","turnId":"turn-1","surfaceId":"surface-1",' +
        '"label":"Calendar lifecycle","steps":[' +
        '{"stepId":"create","actionId":"calendar.event.create","args":' + JSON.stringify(createArgs) + '},' +
        '{"stepId":"update","actionId":"calendar.event.update",' +
        '"args":{"title":"Appless QA","start":"2026-07-29T16:00:00+08:00",' +
        '"end":"2026-07-29T16:30:00+08:00","calendarId":"primary"},' +
        '"inputFrom":[{"target":"/eventId","stepId":"create",' +
        '"path":"/data/genericToolResults/0/rows/0/value"}]},' +
        '{"stepId":"delete","actionId":"calendar.event.delete",' +
        '"args":{"calendarId":"primary"},' +
        '"inputFrom":[{"target":"/eventId","stepId":"update",' +
        '"path":"/data/genericToolResults/0/rows/0/value"}]}]}'
      ) as ActionPlan;
      const runContext: ActionPlanRunContext = {
        conversationId: 'conversation-1',
        turnId: 'turn-1',
        surfaceId: 'surface-1',
        sourceToolId: 'calendar.event.create',
        planId: 'calendar-lifecycle',
        runId: 'calendar-lifecycle-run',
        pageActionId: 'calendar.event.create'
      };
      const initial = await runner.run(actionPlan, runContext);
      const afterCreate = await runner.resume(actionPlan, runContext, 0, [], 'create');
      const createPause = afterCreate as ActionPlanPausedOutcome;
      const afterUpdate = await runner.resume(
        actionPlan, runContext, createPause.nextStepIndex, createPause.outputs, 'update'
      );
      const updatePause = afterUpdate as ActionPlanPausedOutcome;
      const completed = await runner.resume(
        actionPlan, runContext, updatePause.nextStepIndex, updatePause.outputs, 'delete'
      );

      expect(initial.status).assertEqual('paused');
      expect(afterCreate.status).assertEqual('paused');
      expect(afterUpdate.status).assertEqual('paused');
      expect(completed.status).assertEqual('success');
      expect(invoker.calls.length).assertEqual(3);
      expect(invoker.calls[0].pageActionId).assertEqual('calendar.event.create');
      expect(invoker.calls[1].pageActionId).assertEqual('calendar.event.update');
      expect(invoker.calls[2].pageActionId).assertEqual('calendar.event.delete');
      expect(JSON.stringify(invoker.calls[1].args).indexOf('event-provider-real-1')).assertLarger(-1);
      expect(JSON.stringify(invoker.calls[2].args).indexOf('event-provider-real-1')).assertLarger(-1);
    });

    it('stops a Calendar plan after provider error or cancellation without a later provider call', 0, async () => {
      const createArgs = object(
        '{"title":"Appless QA","start":"2026-07-29T15:00:00+08:00",' +
        '"end":"2026-07-29T15:30:00+08:00","calendarId":"primary"}'
      );
      const actionPlan = object(
        '{"planId":"calendar-stop","turnId":"turn-1","surfaceId":"surface-1",' +
        '"label":"Calendar stop","steps":[' +
        '{"stepId":"create","actionId":"calendar.event.create","args":' + JSON.stringify(createArgs) + '},' +
        '{"stepId":"update","actionId":"calendar.event.update",' +
        '"args":{"title":"Appless QA","start":"2026-07-29T16:00:00+08:00",' +
        '"end":"2026-07-29T16:30:00+08:00"},' +
        '"inputFrom":[{"target":"/eventId","stepId":"create",' +
        '"path":"/data/genericToolResults/0/rows/0/value"}]}]}'
      ) as ActionPlan;
      const runContext: ActionPlanRunContext = {
        conversationId: 'conversation-1', turnId: 'turn-1', surfaceId: 'surface-1',
        sourceToolId: 'calendar.event.create', planId: 'calendar-stop', runId: 'provider-error',
        pageActionId: 'calendar.event.create'
      };
      const errorCatalog = catalog('calendar.event.create', createArgs, 'calendar.event.create');
      const errorInvoker = new CalendarLifecycleInvoker();
      errorInvoker.failingToolId = 'calendar.event.create';
      const errorHandler = new RegisteredPageActionHandler(errorInvoker);
      const errorExecutor = new AiphoneRegisteredActionExecutor(
        errorCatalog, new FakeUriOpener(), new DeterministicIds(),
        (
          actionId: string, args: Object, executionContext: RegisteredPageActionContext
        ): Promise<ActionExecutionResult> => errorHandler.execute(actionId, args, executionContext)
      );
      const errored = await new ActionPlanRunner(errorCatalog, errorExecutor).resume(
        actionPlan, runContext, 0, [], 'create'
      );

      const cancelCatalog = catalog('calendar.event.create', createArgs, 'calendar.event.create');
      const cancelInvoker = new CalendarLifecycleInvoker();
      const cancelHandler = new RegisteredPageActionHandler(cancelInvoker);
      const cancelExecutor = new AiphoneRegisteredActionExecutor(
        cancelCatalog, new FakeUriOpener(), new DeterministicIds(),
        async (
          actionId: string, args: Object, executionContext: RegisteredPageActionContext
        ): Promise<ActionExecutionResult> => {
          if (actionId === 'calendar.event.create') {
            return {
              status: 'canceled',
              errorCode: 'CALENDAR_WRITE_CANCELED',
              message: 'Calendar write canceled.'
            };
          }
          return cancelHandler.execute(actionId, args, executionContext);
        }
      );
      const cancelContext = object(JSON.stringify(runContext)) as ActionPlanRunContext;
      cancelContext.runId = 'provider-cancel';
      const canceled = await new ActionPlanRunner(cancelCatalog, cancelExecutor).resume(
        actionPlan, cancelContext, 0, [], 'create'
      );

      expect(errored.status).assertEqual('error');
      expect(errorInvoker.calls.length).assertEqual(1);
      expect(errorInvoker.calls[0].toolId).assertEqual('calendar.event.create');
      expect(canceled.status).assertEqual('canceled');
      expect(cancelInvoker.calls.length).assertEqual(0);
    });

    it('rejects unknown Data client-only and review-required write actions', 0, async () => {
      const rejected: string[] = [
        'unknown.action',
        'travel.search',
        'payment.confirm',
        'work.item.create.confirm',
        'work.item.comment.confirm',
        'work.item.update.confirm',
        'knowledge.create.confirm',
        'knowledge.append.confirm',
        'knowledge.overwrite.confirm',
        'knowledge.share.confirm'
      ];
      for (let index = 0; index < rejected.length; index++) {
        const actionId = rejected[index];
        const args = object('{"marker":"rejected-' + index.toString() + '"}');
        const recorder = new RecordingPageAction();
        const executor = pageExecutor(actionId, args, recorder, new FakeUriOpener(), actionId);
        const result = await executor.execute(actionId, args, context(actionId));

        expect(result.status).assertEqual('error');
        expect(recorder.calls.length).assertEqual(0);
      }
    });

    it('rejects stale conversation turn surface source action args and malformed run identity before callback', 0, async () => {
      const args = object('{"to":"alice@example.com","subject":"QA","body":"Exact"}');
      const cases: ActionExecutionContext[] = [];
      const wrongConversation = context('gmail.thread.read');
      wrongConversation.conversationId = 'conversation-stale';
      cases.push(wrongConversation);
      const wrongTurn = context('gmail.thread.read');
      wrongTurn.turnId = 'turn-stale';
      cases.push(wrongTurn);
      const wrongSurface = context('gmail.thread.read');
      wrongSurface.surfaceId = 'surface-stale';
      cases.push(wrongSurface);
      const wrongSource = context('hotel.search');
      cases.push(wrongSource);
      const emptyPlan = context('gmail.thread.read');
      emptyPlan.planId = '';
      cases.push(emptyPlan);
      const emptyRun = context('gmail.thread.read');
      emptyRun.runId = '';
      cases.push(emptyRun);
      const emptyStep = context('gmail.thread.read');
      emptyStep.stepId = '';
      cases.push(emptyStep);

      for (let index = 0; index < cases.length; index++) {
        const recorder = new RecordingPageAction();
        const executor = pageExecutor(
          'gmail.draft.create', args, recorder, new FakeUriOpener(), 'gmail.thread.read'
        );
        const result = await executor.execute('gmail.draft.create', args, cases[index]);
        expect(result.status).assertEqual('error');
        expect(recorder.calls.length).assertEqual(0);
      }

      const mutated = object('{"to":"mallory@example.com","subject":"QA","body":"Exact"}');
      const mutatedRecorder = new RecordingPageAction();
      const mutatedExecutor = pageExecutor(
        'gmail.draft.create', args, mutatedRecorder, new FakeUriOpener(), 'gmail.thread.read'
      );
      expect((await mutatedExecutor.execute(
        'gmail.draft.create', mutated, context('gmail.thread.read')
      )).status).assertEqual('error');
      expect(mutatedRecorder.calls.length).assertEqual(0);

      const actionRecorder = new RecordingPageAction();
      const actionExecutor = pageExecutor(
        'gmail.draft.create', args, actionRecorder, new FakeUriOpener(), 'gmail.thread.read'
      );
      expect((await actionExecutor.execute(
        'mail.draft.create', args, context('gmail.thread.read')
      )).status).assertEqual('error');
      expect(actionRecorder.calls.length).assertEqual(0);
    });

    it('rejects replay before a second callback', 0, async () => {
      const args = object('{"origin":"A","destination":"B"}');
      const recorder = new RecordingPageAction();
      const executor = pageExecutor('maps.route.open', args, recorder, new FakeUriOpener(), 'maps.route.open');

      const first = await executor.execute('maps.route.open', args, pageContext('maps.route.open'));
      const replay = await executor.execute('maps.route.open', args, pageContext('maps.route.open'));

      expect(first.status).assertEqual('success');
      expect(replay.status).assertEqual('error');
      expect(JSON.stringify(replay).indexOf('DUPLICATE')).assertLarger(-1);
      expect(recorder.calls.length).assertEqual(1);
    });

    it('keeps distinct plan steps executable under one action run', 0, async () => {
      const args = object('{"to":"alice@example.com","subject":"QA","body":"Exact"}');
      const recorder = new RecordingPageAction();
      const executor = pageExecutor(
        'gmail.draft.create', args, recorder, new FakeUriOpener(), 'gmail.thread.read'
      );
      const first = context('gmail.thread.read');
      const second = context('gmail.thread.read');
      second.stepId = 'step-2';

      const firstResult = await executor.execute('gmail.draft.create', args, first);
      const secondResult = await executor.execute('gmail.draft.create', args, second);

      expect(firstResult.status).assertEqual('success');
      expect(secondResult.status).assertEqual('success');
      expect(recorder.calls.length).assertEqual(2);
    });

    it('bounds replay identities without evicting any live-scope execution', 0, async () => {
      const args = object('{"to":"alice@example.com","subject":"QA","body":"Exact"}');
      const recorder = new RecordingPageAction();
      const executor = pageExecutor(
        'gmail.draft.create', args, recorder, new FakeUriOpener(), 'gmail.thread.read'
      );

      for (let index = 0; index < 128; index++) {
        const current = context('gmail.thread.read');
        current.stepId = 'step-' + index.toString();
        expect((await executor.execute('gmail.draft.create', args, current)).status)
          .assertEqual('success');
      }
      const overflow = context('gmail.thread.read');
      overflow.stepId = 'step-overflow';
      const overflowResult = await executor.execute('gmail.draft.create', args, overflow);
      const firstReplay = context('gmail.thread.read');
      firstReplay.stepId = 'step-0';
      const replayResult = await executor.execute('gmail.draft.create', args, firstReplay);

      expect(overflowResult.status).assertEqual('error');
      expect(JSON.stringify(overflowResult).indexOf('CAPACITY')).assertLarger(-1);
      expect(replayResult.status).assertEqual('error');
      expect(JSON.stringify(replayResult).indexOf('DUPLICATE')).assertLarger(-1);
      expect(recorder.calls.length).assertEqual(128);
    });

    it('changes replay scope only after current surface authority validates the transition', 0, async () => {
      const args = object('{"to":"alice@example.com","subject":"QA","body":"Exact"}');
      const authority = new MutableExactSurface('gmail.draft.create', args);
      const actionCatalog = new ActionCatalog(
        new RegisteredDefinitions(),
        authority,
        new NoClientAction(),
        new RegisteredArgsValidator()
      );
      const recorder = new RecordingPageAction();
      const executor = new AiphoneRegisteredActionExecutor(
        actionCatalog,
        new FakeUriOpener(),
        new DeterministicIds(),
        pageCallback(recorder)
      );
      const first = context('gmail.thread.read');
      expect((await executor.execute('gmail.draft.create', args, first)).status)
        .assertEqual('success');

      const forged = context('gmail.thread.read');
      forged.turnId = 'turn-forged';
      forged.surfaceId = 'surface-forged';
      expect((await executor.execute('gmail.draft.create', args, forged)).status)
        .assertEqual('error');
      expect((await executor.execute('gmail.draft.create', args, first)).status)
        .assertEqual('error');

      authority.turnId = 'turn-2';
      authority.surfaceId = 'surface-2';
      const second = context('gmail.thread.read');
      second.turnId = 'turn-2';
      second.surfaceId = 'surface-2';
      expect((await executor.execute('gmail.draft.create', args, second)).status)
        .assertEqual('success');
      expect((await executor.execute('gmail.draft.create', args, first)).status)
        .assertEqual('error');
      expect(recorder.calls.length).assertEqual(2);
    });

    it('clears replay state only when the executor is disposed', 0, async () => {
      const args = object('{"to":"alice@example.com","subject":"QA","body":"Exact"}');
      const recorder = new RecordingPageAction();
      const executor = pageExecutor(
        'gmail.draft.create', args, recorder, new FakeUriOpener(), 'gmail.thread.read'
      );
      const current = context('gmail.thread.read');

      expect((await executor.execute('gmail.draft.create', args, current)).status)
        .assertEqual('success');
      executor.dispose();
      expect((await executor.execute('gmail.draft.create', args, current)).status)
        .assertEqual('success');
      expect(recorder.calls.length).assertEqual(2);
    });

    it('contains thrown false and real handler failures without a fake receipt', 0, async () => {
      const args = object('{"origin":"A","destination":"B"}');
      const thrown = new RecordingPageAction();
      thrown.shouldThrow = true;
      const thrownResult = await pageExecutor(
        'maps.route.open', args, thrown, new FakeUriOpener(), 'maps.route.open'
      ).execute('maps.route.open', args, pageContext('maps.route.open'));
      expect(thrownResult.status).assertEqual('error');
      expect(JSON.stringify(thrownResult).indexOf('provider-receipt')).assertEqual(-1);

      const falseHandler = new RecordingPageAction();
      falseHandler.returnFalse = true;
      const falseResult = await pageExecutor(
        'maps.route.open', args, falseHandler, new FakeUriOpener(), 'maps.route.open'
      ).execute('maps.route.open', args, pageContext('maps.route.open'));
      expect(falseResult.status).assertEqual('error');
      expect(JSON.stringify(falseResult).indexOf('provider-receipt')).assertEqual(-1);

      const realError = new RecordingPageAction();
      realError.result = {
        status: 'error',
        errorCode: 'PROVIDER_REAL_ERROR',
        message: 'Provider rejected the route.'
      };
      const errorResult = await pageExecutor(
        'maps.route.open', args, realError, new FakeUriOpener(), 'maps.route.open'
      ).execute('maps.route.open', args, pageContext('maps.route.open'));
      expect(JSON.stringify(errorResult)).assertEqual(JSON.stringify(realError.result));
      expect(JSON.stringify(errorResult).indexOf('provider-receipt')).assertEqual(-1);
    });
  });
}
