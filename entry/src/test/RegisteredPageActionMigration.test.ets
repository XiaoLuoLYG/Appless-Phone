import { describe, expect, it } from '@ohos/hypium';
import {
  A2uiAction,
  A2uiCallResult,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  ActionExecutionResult,
  AgentMessage,
  AgentMessageType,
  CreateDataTaskPayload,
  DataResult,
  DataTaskExecutor,
  LocalModel,
  LinkedMessageBus,
  createSeedA2uiSurface
} from '@loop/agent-core';
import {
  MultiAgentCanaryOptions,
  MultiAgentCanaryRuntime
} from '../main/ets/pages/A2uiHome/agent/MultiAgentCanaryRuntime';
import {
  RegisteredPageActionContext,
  SystemUriOpener
} from '../main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor';
import {
  RegisteredPageActionHandler,
  RegisteredPageToolInvocation,
  RegisteredPageToolInvoker
} from '../main/ets/pages/A2uiHome/agent/RegisteredPageActionHandler';
import {
  RegisteredPageSnapshot,
  RegisteredPageSnapshotStore,
  dispatchRegisteredPageActionCandidate,
  resolveVirtualRegisteredPageAction
} from '../main/ets/pages/A2uiHome/agent/RegisteredPageActionRoute';
import { createHtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeSnapshot';
import { HtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeTypes';

const WORLDCUP_DECISION: string = '{"personaId":"default_companion","skillId":"",' +
  '"requestedCapabilityIds":["worldcup.open"],"roundAction":"execute","dataTasks":[],' +
  '"uiIntent":{"purpose":"worldcup.open","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"actionIntent":{"goal":"open world cup",' +
  '"allowedActionIds":["worldcup.open"]},"reasonCode":"worldcup"}';
const MAPS_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["maps.route.open"],"roundAction":"execute","dataTasks":[],' +
  '"uiIntent":{"purpose":"maps.route.open","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"actionIntent":{"goal":"open maps route",' +
  '"allowedActionIds":["maps.route.open"]},"reasonCode":"maps"}';
const SOCIAL_DECISION: string = '{"personaId":"default_companion","skillId":"",' +
  '"requestedCapabilityIds":["social.reply.draft"],"roundAction":"execute","dataTasks":[],' +
  '"uiIntent":{"purpose":"social.reply.draft","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"actionIntent":{"goal":"draft reply",' +
  '"allowedActionIds":["social.reply.draft"]},"reasonCode":"social"}';

interface ToolInvocationRecord {
  toolId: string;
  prompt: string;
  pageActionId: string;
  args: Object;
}

class QueueModel implements LocalModel {
  private readonly values: string[];

  constructor(values: string[]) {
    this.values = values.slice();
  }

  async complete(_prompt: string): Promise<string> {
    if (this.values.length === 0) {
      throw new Error('No queued Leader response.');
    }
    return this.values.shift() as string;
  }
}

class RejectDataExecutor implements DataTaskExecutor {
  async execute(_task: CreateDataTaskPayload): Promise<DataResult> {
    throw new Error('No Data task expected.');
  }
}

class RecordingOpener implements SystemUriOpener {
  async open(_uri: string): Promise<boolean> {
    return true;
  }
}

class TrackingBus extends LinkedMessageBus {
  readonly messages: AgentMessage[] = [];

  publish(message: AgentMessage): void {
    this.messages.push(message);
    super.publish(message);
  }
}

class RecordingPageToolInvoker implements RegisteredPageToolInvoker {
  readonly calls: ToolInvocationRecord[] = [];
  failingPageActionId: string = '';
  failure: string = '';

  async invoke(
    toolId: string,
    prompt: string,
    pageActionId: string,
    args: Object
  ): Promise<RegisteredPageToolInvocation> {
    this.calls.push({ toolId, prompt, pageActionId, args });
    if (pageActionId === this.failingPageActionId) {
      return { ok: false, result: null, error: this.failure };
    }
    if (toolId === 'worldcup.open') {
      return { ok: true, result: null, error: '' };
    }
    return { ok: true, result: successfulToolResult(toolId), error: '' };
  }
}

function action(id: string, args: Object, kind: string = 'prompt'): A2uiAction {
  return {
    id,
    label: id,
    prompt: id,
    variant: 'primary',
    kind,
    args
  };
}

function pageSurface(sourceToolId: string, clicked: A2uiAction, sequence: number): A2uiSurfaceState {
  const surface = createSeedA2uiSurface();
  const model = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
  model.summary.toolName = sourceToolId;
  model.summary.dataLabel = 'result';
  surface.surfaceId = 'registered-page-' + sequence.toString();
  surface.rootId = 'root';
  surface.title = sourceToolId;
  surface.intent = sourceToolId;
  surface.status = 'ready';
  surface.sequence = sequence;
  surface.components = [{
    id: 'root',
    component: 'SurfaceRoot',
    actions: [clicked]
  }];
  surface.dataModelJson = JSON.stringify(model);
  return surface;
}

function documentFor(surface: A2uiSurfaceState): HtmlHomeDocument {
  return createHtmlHomeDocument({
    surface,
    messages: [],
    isBusy: false,
    isAwaitingFirstSurface: false
  });
}

function snapshot(surface: A2uiSurfaceState, generation: number): RegisteredPageSnapshot {
  return {
    surface,
    document: documentFor(surface),
    generation
  };
}

function successfulToolResult(toolId: string): A2uiCallResult {
  const surface = createSeedA2uiSurface();
  const model = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
  model.summary.toolName = toolId;
  model.summary.dataLabel = 'result';
  surface.surfaceId = 'result-' + toolId;
  surface.title = toolId;
  surface.intent = toolId;
  surface.status = 'ready';
  surface.dataModelJson = JSON.stringify(model);
  return {
    ok: true,
    raw: '{}',
    error: '',
    requestDebug: '',
    assistantDebug: '',
    surface
  };
}

function canary(
  model: LocalModel,
  handler: RegisteredPageActionHandler,
  currentSnapshot: () => RegisteredPageSnapshot | null,
  bus?: LinkedMessageBus
): MultiAgentCanaryRuntime {
  const options: MultiAgentCanaryOptions = {
    model,
    selectedPersonaId: (): string => 'travel_companion',
    opener: new RecordingOpener(),
    pageAction: (
      actionId: string,
      args: Object,
      context: RegisteredPageActionContext
    ): Promise<ActionExecutionResult> => handler.execute(actionId, args, context),
    currentPageSnapshot: currentSnapshot,
    onSurface: (_surface: A2uiSurfaceState): void => {},
    onMemoryUpdate: (): void => {},
    dataExecutor: new RejectDataExecutor(),
    currentLocalDate: (): string => '2026-07-22',
    conversationId: 'registered-page-test',
    bus,
    submitTimeoutMs: 1000,
    actionTimeoutMs: 1000
  };
  return new MultiAgentCanaryRuntime(options);
}

function lastActionResult(bus: TrackingBus): string {
  for (let index = bus.messages.length - 1; index >= 0; index--) {
    if (bus.messages[index].type === AgentMessageType.ACTION_RESULT) {
      return JSON.stringify(bus.messages[index].payload);
    }
  }
  return '';
}

function cloneSnapshot(value: RegisteredPageSnapshot): RegisteredPageSnapshot {
  return JSON.parse(JSON.stringify(value)) as RegisteredPageSnapshot;
}

export default function registeredPageActionMigrationTest() {
  describe('registeredPageActionMigration', () => {
    it('preserves each Stripe page operation through the real registered page handler', 0, async () => {
      const invoker = new RecordingPageToolInvoker();
      invoker.failingPageActionId = 'stripe.account.refresh';
      invoker.failure = 'stripe provider denied refresh';
      const handler = new RegisteredPageActionHandler(invoker);
      const store = new RegisteredPageSnapshotStore();
      const bus = new TrackingBus();
      const runtime = canary(new QueueModel([]), handler, (): RegisteredPageSnapshot | null => store.current(), bus);
      const operations: string[] = [
        'stripe.account.create',
        'stripe.account.onboard',
        'stripe.account.refresh'
      ];

      for (let index = 0; index < operations.length; index++) {
        const clicked = action(
          operations[index],
          JSON.parse('{"country":"US","businessType":"individual"}') as Object,
          'client'
        );
        const surface = pageSurface('payment.account.setup', clicked, index + 1);
        expect(store.record(surface, documentFor(surface), index + 1)).assertTrue();
        const ok = await runtime.runPageAction(clicked);
        expect(ok).assertEqual(index < 2);
      }

      expect(invoker.calls.length).assertEqual(3);
      for (let index = 0; index < operations.length; index++) {
        expect(invoker.calls[index].toolId).assertEqual('payment.account.setup');
        expect(invoker.calls[index].pageActionId).assertEqual(operations[index]);
      }
      expect(lastActionResult(bus).indexOf('stripe provider denied refresh') >= 0).assertTrue();
      expect(lastActionResult(bus).indexOf('"status":"success"') >= 0).assertFalse();
      runtime.dispose();
    });

    it('keeps every migrated candidate out of legacy fallthrough on authority or handler failure', 0, async () => {
      const invoker = new RecordingPageToolInvoker();
      const handler = new RegisteredPageActionHandler(invoker);
      let current: RegisteredPageSnapshot | null = null;
      const runtime = canary(new QueueModel([]), handler, (): RegisteredPageSnapshot | null => current);
      let callToolFallbacks = 0;
      let submitPromptFallbacks = 0;
      const legacy = async (_clicked: A2uiAction): Promise<void> => {
        callToolFallbacks++;
        submitPromptFallbacks++;
      };
      const exact = action(
        'payment.confirm',
        JSON.parse('{"recipient":"real-user","amountText":"5.00","currency":"USD","phase":"confirm"}') as Object
      );

      current = snapshot(pageSurface('missing.source', exact, 1), 1);
      const missing = await dispatchRegisteredPageActionCandidate(
        exact,
        (clicked: A2uiAction): Promise<boolean> => runtime.runPageAction(clicked),
        legacy
      );
      expect(missing.candidate).assertTrue();
      expect(missing.ok).assertFalse();

      const exactSurface = pageSurface('payment.send', exact, 2);
      current = snapshot(exactSurface, 2);
      const mutated = action(
        'payment.confirm',
        JSON.parse('{"recipient":"mallory","amountText":"5000","currency":"USD","phase":"confirm"}') as Object
      );
      const mutatedResult = await dispatchRegisteredPageActionCandidate(
        mutated,
        (clicked: A2uiAction): Promise<boolean> => runtime.runPageAction(clicked),
        legacy
      );
      expect(mutatedResult.candidate).assertTrue();
      expect(mutatedResult.ok).assertFalse();

      expect(await runtime.runPageAction(exact)).assertTrue();
      const stale = cloneSnapshot(current as RegisteredPageSnapshot);
      stale.document.generatedAt = stale.document.generatedAt + '-constructed';
      current = stale;
      const staleResult = await dispatchRegisteredPageActionCandidate(
        exact,
        (clicked: A2uiAction): Promise<boolean> => runtime.runPageAction(clicked),
        legacy
      );
      expect(staleResult.candidate).assertTrue();
      expect(staleResult.ok).assertFalse();

      const handlerArgs = JSON.parse('{"itemId":"post-1","platform":"x","instruction":"draft"}') as Object;
      const handlerAction = action('social.reply.draft', handlerArgs);
      current = snapshot(pageSurface('social.feed.search', handlerAction, 3), 3);
      invoker.failingPageActionId = 'social.reply.draft';
      invoker.failure = 'real SocialHub draft error';
      const handlerResult = await dispatchRegisteredPageActionCandidate(
        handlerAction,
        (clicked: A2uiAction): Promise<boolean> => runtime.runPageAction(clicked),
        legacy
      );
      expect(handlerResult.candidate).assertTrue();
      expect(handlerResult.ok).assertFalse();
      expect(callToolFallbacks).assertEqual(0);
      expect(submitPromptFallbacks).assertEqual(0);
      runtime.dispose();
    });

    it('limits virtual ownership to exact World Cup and structured Maps handlers', 0, async () => {
      const invoker = new RecordingPageToolInvoker();
      const handler = new RegisteredPageActionHandler(invoker);
      const runtime = canary(
        new QueueModel([WORLDCUP_DECISION, MAPS_DECISION, MAPS_DECISION, SOCIAL_DECISION]),
        handler,
        (): RegisteredPageSnapshot | null => null
      );

      const worldcup = await runtime.submit('打开世界杯页面', { text: '' });
      const maps = await runtime.submit('打开深圳北到香港西九龙的路线', { text: '' });
      const ambiguousMaps = await runtime.submit('打开路线', { text: '' });
      const social = await runtime.submit('帮我起草回复', { text: '' });

      expect(worldcup.kind).assertEqual('settled');
      expect(maps.kind).assertEqual('settled');
      expect(ambiguousMaps.kind).assertEqual('settled');
      expect(social.kind).assertEqual('handoff');
      expect(invoker.calls.length).assertEqual(2);
      expect(invoker.calls[0].toolId).assertEqual('worldcup.open');
      expect(invoker.calls[0].pageActionId).assertEqual('worldcup.open');
      expect(JSON.stringify(invoker.calls[0].args)).assertEqual(
        '{"route":"pages/A2uiHome/AnythingDemo"}'
      );
      expect(invoker.calls[1].toolId).assertEqual('maps.route.open');
      expect(invoker.calls[1].pageActionId).assertEqual('maps.route.open');
      expect(JSON.stringify(invoker.calls[1].args)).assertEqual(
        '{"origin":"深圳北","destination":"香港西九龙","travelMode":"driving","navigate":false}'
      );
      expect(resolveVirtualRegisteredPageAction('social.reply.draft', '帮我起草回复')).assertNull();
      expect(resolveVirtualRegisteredPageAction('maps.route.open', '打开路线')).assertNull();
      runtime.dispose();
    });

    it('rejects invalid World Cup arguments before the real handler invocation', 0, async () => {
      const invoker = new RecordingPageToolInvoker();
      const handler = new RegisteredPageActionHandler(invoker);
      const context: RegisteredPageActionContext = {
        conversationId: 'registered-page-test',
        turnId: 'turn-1',
        surfaceId: 'virtual:worldcup',
        sourceToolId: 'virtual.action-intent',
        planId: 'direct:worldcup',
        runId: 'worldcup',
        stepId: 'step-1',
        pageActionId: 'worldcup.open',
        virtualAction: true
      };

      const result = await handler.execute(
        'worldcup.open',
        JSON.parse('{"route":"pages/forged"}') as Object,
        context
      );

      expect(result.status).assertEqual('error');
      expect(invoker.calls.length).assertEqual(0);
    });

    it('binds page authority to the exact current rendered snapshot fingerprint', 0, async () => {
      const invoker = new RecordingPageToolInvoker();
      const handler = new RegisteredPageActionHandler(invoker);
      const args = JSON.parse('{"itemId":"post-1","platform":"x","instruction":"draft"}') as Object;
      const clicked = action('social.reply.draft', args);
      const surface = pageSurface('social.feed.search', clicked, 10);
      let current: RegisteredPageSnapshot | null = snapshot(surface, 10);
      const runtime = canary(new QueueModel([]), handler, (): RegisteredPageSnapshot | null => current);

      expect(await runtime.runPageAction(clicked)).assertTrue();
      expect(await runtime.runPageAction(clicked)).assertTrue();
      expect(invoker.calls.length).assertEqual(2);

      const constructed = cloneSnapshot(current as RegisteredPageSnapshot);
      constructed.document.generatedAt = constructed.document.generatedAt + '-forged';
      current = constructed;
      expect(await runtime.runPageAction(clicked)).assertFalse();
      expect(invoker.calls.length).assertEqual(2);

      const newSurface = pageSurface('social.feed.search', clicked, 11);
      current = snapshot(newSurface, 11);
      expect(await runtime.runPageAction(clicked)).assertTrue();
      expect(invoker.calls.length).assertEqual(3);

      current = snapshot(surface, 9);
      expect(await runtime.runPageAction(clicked)).assertFalse();
      expect(invoker.calls.length).assertEqual(3);

      const store = new RegisteredPageSnapshotStore();
      const stored = snapshot(surface, 20);
      expect(store.record(stored.surface, stored.document, stored.generation)).assertTrue();
      const sameGeneration = cloneSnapshot(stored);
      sameGeneration.surface.dataModelJson = sameGeneration.surface.dataModelJson + ' ';
      expect(store.record(
        sameGeneration.surface,
        sameGeneration.document,
        sameGeneration.generation
      )).assertFalse();
      runtime.dispose();
    });
  });
}
