import { describe, it, expect } from '@ohos/hypium';
import {
  ActionArgsValidator,
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionValidationResult,
  ClientActionAuthorizer,
  HotelCallArgs,
  HotelNavigateArgs,
  SurfaceActionAuthorizer,
  ToolDefinition,
  ToolDefinitionLookup,
  validateHotelActionArgs
} from '@loop/agent-core';
import {
  HotelActionIdFactory,
  HotelRegisteredActionExecutor,
  SystemUriOpener
} from '../main/ets/pages/A2uiHome/agent/HotelRegisteredActionExecutor';

function object(raw: string): Object {
  return JSON.parse(raw) as Object;
}

function definition(toolId: string): ToolDefinition {
  return {
    toolId: toolId,
    domain: 'hotel',
    intent: toolId,
    riskLevel: toolId === 'hotel.call' ? 'draft' : 'read',
    backendPriority: [toolId === 'hotel.detail' ? 'local_adapter' : 'system_intent'],
    authModes: [toolId === 'hotel.detail' ? 'provider_key' : 'system'],
    inputSchema: toolId + 'Request',
    outputSchema: toolId === 'hotel.detail' ? 'hotelRatePlans' : 'systemIntentResult',
    a2uiComponent: 'GenericToolResults',
    actions: []
  };
}

class HotelDefinitions implements ToolDefinitionLookup {
  find(toolId: string): ToolDefinition | null {
    if (toolId === 'hotel.search') {
      const source = definition(toolId);
      source.actions = ['hotel.detail', 'hotel.navigate', 'hotel.call'];
      return source;
    }
    if (toolId === 'hotel.detail' || toolId === 'hotel.navigate' || toolId === 'hotel.call') {
      return definition(toolId);
    }
    return null;
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

class NoClientAction implements ClientActionAuthorizer {
  allows(_actionId: string, _args: Object): boolean {
    return false;
  }
}

class HotelArgsValidator implements ActionArgsValidator {
  validate(actionId: string, args: Object): ActionValidationResult {
    return validateHotelActionArgs(actionId, args);
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

class DeterministicIds implements HotelActionIdFactory {
  next: number = 0;

  nextId(prefix: string): string {
    this.next += 1;
    return prefix + '-' + this.next.toString();
  }
}

function catalog(actionId: string, args: Object): ActionCatalog {
  return new ActionCatalog(
    new HotelDefinitions(),
    new ExactSurface(actionId, args),
    new NoClientAction(),
    new HotelArgsValidator()
  );
}

function context(): ActionExecutionContext {
  return {
    conversationId: 'conversation-1',
    turnId: 'turn-1',
    surfaceId: 'surface-1',
    sourceToolId: 'hotel.search',
    planId: 'plan-1',
    runId: 'run-1',
    stepId: 'step-1'
  };
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

function callArgs(): HotelCallArgs {
  return {
    hotelId: 47675,
    name: '深圳测试酒店',
    displayPhone: '+86 138 0013 8000',
    dialPhone: '+8613800138000',
    provider: 'Google Places',
    providerPlaceId: 'place-real-47675'
  };
}

async function executeTampered(
  expected: Object,
  actionId: string,
  tampered: Object,
  opener: FakeUriOpener
): Promise<ActionExecutionResult> {
  const executor = new HotelRegisteredActionExecutor(
    catalog(actionId, expected),
    opener,
    new DeterministicIds()
  );
  return executor.execute(actionId, tampered, context());
}

export default function hotelRegisteredActionExecutorTest() {
  describe('hotelRegisteredActionExecutor', () => {
    it('opens one exact Petal Maps URI only after current catalog validation', 0, async () => {
      const args = navigateArgs();
      const opener = new FakeUriOpener();
      const executor = new HotelRegisteredActionExecutor(
        catalog('hotel.navigate', args),
        opener,
        new DeterministicIds()
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

    it('opens the dialer once without claiming a call was placed', 0, async () => {
      const args = callArgs();
      const opener = new FakeUriOpener();
      const executor = new HotelRegisteredActionExecutor(
        catalog('hotel.call', args),
        opener,
        new DeterministicIds()
      );

      const result = await executor.execute('hotel.call', args, context());
      const serialized = JSON.stringify(result);

      expect(result.status).assertEqual('success');
      expect(opener.uris.join(',')).assertEqual('tel:+8613800138000');
      expect(serialized.indexOf('dialer opened')).assertLarger(-1);
      expect(serialized.indexOf('call placed')).assertEqual(-1);
      expect(serialized.indexOf('telprompt:')).assertEqual(-1);
    });

    it('rejects tampered phone coordinates hotel and place IDs before opening', 0, async () => {
      const opener = new FakeUriOpener();
      const call = callArgs();
      const tamperedPhone = callArgs();
      tamperedPhone.dialPhone = '+8613900139000';
      const tamperedCallHotel = callArgs();
      tamperedCallHotel.hotelId = 99999;
      const tamperedPlace = callArgs();
      tamperedPlace.providerPlaceId = 'place-attacker';
      const navigate = navigateArgs();
      const tamperedCoordinate = navigateArgs();
      tamperedCoordinate.latitude = 22.6;
      const tamperedNavigateHotel = navigateArgs();
      tamperedNavigateHotel.hotelId = 99999;

      expect((await executeTampered(call, 'hotel.call', tamperedPhone, opener)).status)
        .assertEqual('error');
      expect((await executeTampered(call, 'hotel.call', tamperedCallHotel, opener)).status)
        .assertEqual('error');
      expect((await executeTampered(call, 'hotel.call', tamperedPlace, opener)).status)
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
      const executor = new HotelRegisteredActionExecutor(
        catalog('hotel.detail', args),
        opener,
        new DeterministicIds()
      );

      const result = await executor.execute('hotel.detail', args, context());
      const serialized = JSON.stringify(result);

      expect(result.status).assertEqual('success');
      expect(opener.uris.length).assertEqual(0);
      expect(serialized.indexOf('"taskId":"hotel-detail-data-1"')).assertLarger(-1);
      expect(serialized.indexOf('"taskId":"hotel-detail-ui-2"')).assertLarger(-1);
      expect(serialized.indexOf('"dataTaskId":"hotel-detail-data-1"')).assertLarger(-1);
      expect(serialized.indexOf('"toolId":"hotel.detail"')).assertLarger(-1);
      expect(serialized.indexOf('"outputSchema":"hotelRatePlans"')).assertLarger(-1);
      expect(serialized.indexOf(JSON.stringify(args))).assertLarger(-1);
      expect(serialized.indexOf('turnId')).assertEqual(-1);
    });

    it('rejects unregistered booking without opening a URI', 0, async () => {
      const args = object('{"hotelId":47675,"ratePlanId":"real-rate"}');
      const opener = new FakeUriOpener();
      const executor = new HotelRegisteredActionExecutor(
        catalog('hotel.book', args),
        opener,
        new DeterministicIds()
      );

      const result = await executor.execute('hotel.book', args, context());

      expect(result.status).assertEqual('error');
      expect(opener.uris.length).assertEqual(0);
    });

    it('returns an error when the system rejects the URI', 0, async () => {
      const args = navigateArgs();
      const opener = new FakeUriOpener();
      opener.opened = false;
      const executor = new HotelRegisteredActionExecutor(
        catalog('hotel.navigate', args),
        opener,
        new DeterministicIds()
      );

      const result = await executor.execute('hotel.navigate', args, context());

      expect(result.status).assertEqual('error');
      expect(opener.uris.length).assertEqual(1);
      expect(JSON.stringify(result).indexOf('OPEN_FAILED')).assertLarger(-1);
    });
  });
}
