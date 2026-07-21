import { describe, it, expect } from '@ohos/hypium';
import {
  ActionArgsValidator,
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionValidationResult,
  ClientActionAuthorizer,
  HotelBookingOpenArgs,
  HotelNavigateArgs,
  SurfaceActionAuthorizer,
  ToolDefinition,
  ToolDefinitionLookup,
  toolDefinitionForToolId,
  validateHotelActionArgs
} from '@loop/agent-core';
import {
  AiphoneRegisteredActionExecutor,
  HotelActionIdFactory,
  RegisteredPageAction,
  RegisteredPageActionContext,
  SystemUriOpener,
  validateGmailReplyActionArgs
} from '../main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor';

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
    const valid = args !== null && typeof args === 'object' && !Array.isArray(args);
    return {
      ok: valid,
      code: valid ? '' : 'ACTION_ARGS_INVALID',
      message: valid ? '' : 'Action args are invalid.'
    };
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

    it('rejects unknown Data client-only and explicitly deferred Task 8 actions', 0, async () => {
      const rejected: string[] = [
        'unknown.action',
        'travel.search',
        'payment.confirm',
        'luckin.order.create',
        'calendar.event.create',
        'calendar.event.update',
        'calendar.event.delete',
        'whatsapp.message.send',
        'ride.order.create',
        'ride.order.cancel'
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
