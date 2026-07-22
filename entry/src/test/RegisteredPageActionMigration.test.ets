import { describe, expect, it } from '@ohos/hypium';
import {
  A2uiAction,
  A2uiCallResult,
  A2uiLabelValueData,
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
  RegisteredPageAction,
  RegisteredPageActionContext,
  SystemUriOpener
} from '../main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor';
import {
  RegisteredPageActionHandler,
  RegisteredPageToolInvocation,
  RegisteredPageToolInvoker
} from '../main/ets/pages/A2uiHome/agent/RegisteredPageActionHandler';
import {
  RegisteredPageActionResolution,
  RegisteredPageSnapshot,
  RegisteredPageSnapshotStore,
  dispatchRegisteredPageActionCandidate,
  isRegisteredPageActionCandidate,
  resolveRegisteredPageAction,
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

function mailReplyDocument(
  surface: A2uiSurfaceState,
  provider: string,
  args: Object
): HtmlHomeDocument {
  const command = args as Record<string, Object | string | number | boolean | null | undefined>;
  const document = documentFor(surface);
  const expected = JSON.parse(JSON.stringify(args)) as Record<string, Object | string | number | boolean | null | undefined>;
  expected['requestKey'] = '';
  expected['body'] = '';
  document.kind = 'gmail';
  document.actions = [];
  document.blocks = [{
    id: provider + '-message-real-1',
    kind: 'generic-tool-result',
    title: 'QA',
    subtitle: '',
    status: 'success',
    source: provider === 'gmail' ? 'Gmail' : 'QQ Mail',
    metrics: [],
    rows: [],
    actions: [{
      id: 'html_mail_detail_read',
      label: '加载正文',
      prompt: command['requestKey'] as string,
      variant: 'secondary',
      kind: 'client',
      args: args
    }, {
      id: provider === 'gmail' ? 'gmail.ai.reply.draft' : 'mail.ai.reply.draft',
      label: 'AI 回复草稿',
      prompt: 'reply',
      variant: 'primary',
      kind: 'prompt',
      args: expected as Object
    }]
  }];
  return document;
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

function providerWriteToolResult(toolId: string, status: string = 'success'): A2uiCallResult {
  const result = successfulToolResult(toolId);
  const model = JSON.parse(result.surface.dataModelJson) as A2uiRuntimeDataModel;
  let rows: A2uiLabelValueData[] = status === 'success' ?
    [{ label: 'Receipt', value: 'provider-receipt-1' }] : [];
  if (status === 'success' && (toolId === 'luckin.order.create' || toolId === 'ride.order.create')) {
    rows = [{ label: '订单号', value: 'provider-order-1' }];
  } else if (status === 'success' && toolId.indexOf('calendar.event.') === 0) {
    rows = [{ label: 'Event ID', value: 'provider-event-1' }];
  } else if (status === 'success' && toolId === 'whatsapp.message.send') {
    rows = [{ label: 'Message ID', value: 'provider-message-1' }];
  } else if (status === 'success' && toolId === 'ride.order.cancel') {
    rows = [{ label: '状态', value: 'cancelled' }];
  }
  let sourceTag = 'Composio Google Calendar';
  if (toolId === 'luckin.order.create') {
    sourceTag = '瑞幸';
  } else if (toolId === 'whatsapp.message.send') {
    sourceTag = 'Composio WhatsApp Business';
  } else if (toolId.indexOf('ride.order.') === 0) {
    sourceTag = '滴滴';
  }
  model.genericToolResults = [{
    sourceTag,
    toolName: toolId,
    title: toolId,
    status,
    summary: status === 'success' ? 'Provider confirmed completion.' : 'Confirmation required.',
    rows,
    rawPreview: status === 'success' ? '{"success":true,"id":"provider-receipt-1"}' : ''
  }];
  result.surface.dataModelJson = JSON.stringify(model);
  return result;
}

class ProviderEvidenceInvoker implements RegisteredPageToolInvoker {
  readonly calls: ToolInvocationRecord[] = [];
  private readonly status: string;

  constructor(status: string) {
    this.status = status;
  }

  async invoke(
    toolId: string,
    prompt: string,
    pageActionId: string,
    args: Object
  ): Promise<RegisteredPageToolInvocation> {
    this.calls.push({ toolId, prompt, pageActionId, args });
    return { ok: true, result: providerWriteToolResult(toolId, this.status), error: '' };
  }
}

class RawProviderEvidenceInvoker implements RegisteredPageToolInvoker {
  private readonly rawPreview: string;

  constructor(rawPreview: string) {
    this.rawPreview = rawPreview;
  }

  async invoke(
    toolId: string,
    _prompt: string,
    _pageActionId: string,
    _args: Object
  ): Promise<RegisteredPageToolInvocation> {
    const result = successfulToolResult(toolId);
    const model = JSON.parse(result.surface.dataModelJson) as A2uiRuntimeDataModel;
    model.genericToolResults = [{
      sourceTag: toolId === 'whatsapp.message.send' ?
        'Composio WhatsApp Business' : 'Composio Google Calendar',
      toolName: toolId,
      title: toolId,
      status: 'success',
      summary: 'Untrusted provider payload.',
      rows: [],
      rawPreview: this.rawPreview
    }];
    result.surface.dataModelJson = JSON.stringify(model);
    return { ok: true, result, error: '' };
  }
}

class WrongSourceProviderEvidenceInvoker implements RegisteredPageToolInvoker {
  async invoke(
    toolId: string,
    _prompt: string,
    _pageActionId: string,
    _args: Object
  ): Promise<RegisteredPageToolInvocation> {
    const result = providerWriteToolResult(toolId);
    const model = JSON.parse(result.surface.dataModelJson) as A2uiRuntimeDataModel;
    model.genericToolResults[0].sourceTag = 'Unrelated provider';
    result.surface.dataModelJson = JSON.stringify(model);
    return { ok: true, result, error: '' };
  }
}

class FailedReceiptProviderEvidenceInvoker implements RegisteredPageToolInvoker {
  async invoke(
    toolId: string,
    _prompt: string,
    _pageActionId: string,
    _args: Object
  ): Promise<RegisteredPageToolInvocation> {
    const result = providerWriteToolResult(toolId);
    const model = JSON.parse(result.surface.dataModelJson) as A2uiRuntimeDataModel;
    model.genericToolResults[0].rawPreview =
      '{"data":{"successful":false,"status":"failed"}}';
    result.surface.dataModelJson = JSON.stringify(model);
    return { ok: true, result, error: '' };
  }
}

class MissingDeleteAckProviderEvidenceInvoker implements RegisteredPageToolInvoker {
  async invoke(
    toolId: string,
    _prompt: string,
    _pageActionId: string,
    _args: Object
  ): Promise<RegisteredPageToolInvocation> {
    const result = providerWriteToolResult(toolId);
    const model = JSON.parse(result.surface.dataModelJson) as A2uiRuntimeDataModel;
    model.genericToolResults[0].rawPreview = '{}';
    result.surface.dataModelJson = JSON.stringify(model);
    return { ok: true, result, error: '' };
  }
}

function canary(
  model: LocalModel,
  handler: RegisteredPageActionHandler,
  currentSnapshot: () => RegisteredPageSnapshot | null,
  bus?: LinkedMessageBus,
  pageAction?: RegisteredPageAction
): MultiAgentCanaryRuntime {
  const options: MultiAgentCanaryOptions = {
    model,
    selectedPersonaId: (): string => 'travel_companion',
    opener: new RecordingOpener(),
    pageAction: pageAction === undefined ? (
      actionId: string,
      args: Object,
      context: RegisteredPageActionContext
    ): Promise<ActionExecutionResult> => handler.execute(actionId, args, context) : pageAction,
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
    it('routes the exact current Gmail Send click once without a second confirmation pause', 0, async () => {
      const invoker = new RecordingPageToolInvoker();
      const handler = new RegisteredPageActionHandler(invoker);
      const bus = new TrackingBus();
      const command = JSON.parse(
        '{"requestKey":"gmail:thread-real-1","provider":"gmail","accountLabel":"g***@gmail.com",' +
        '"threadId":"thread-real-1","messageId":"message-real-1","to":["alice@example.com"],' +
        '"subject":"Re: QA","body":"Exact reply","replyMode":"reply","contextSummary":"QA"}'
      ) as Object;
      const clicked = action('html_mail_reply_send', command, 'client');
      clicked.label = '发送回复';
      clicked.prompt = 'gmail:thread-real-1';
      const surface = pageSurface('gmail.mail.search', action(
        'gmail.ai.reply.draft', command
      ), 1);
      let current: RegisteredPageSnapshot | null = {
        surface,
        document: mailReplyDocument(surface, 'gmail', command),
        generation: 1
      };
      let sendCalls = 0;
      const pageAction: RegisteredPageAction = async (
        actionId: string,
        args: Object,
        context: RegisteredPageActionContext
      ): Promise<ActionExecutionResult> => {
        sendCalls++;
        expect(actionId).assertEqual('gmail.message.send');
        expect(context.pageActionId).assertEqual('html_mail_reply_send');
        expect(JSON.stringify(args)).assertEqual(JSON.stringify(command));
        return {
          status: 'success',
          output: JSON.parse(
            '{"requestKey":"gmail:thread-real-1","operation":"send",' +
            '"provider":"gmail","status":"success","message":"Gmail 回复已发送。"}'
          ) as Object
        };
      };
      const runtime = canary(
        new QueueModel([]), handler, (): RegisteredPageSnapshot | null => current, bus, pageAction
      );
      let legacyCalls = 0;
      const dispatched = await dispatchRegisteredPageActionCandidate(
        clicked,
        (currentAction: A2uiAction): Promise<boolean> => runtime.runPageAction(currentAction),
        async (_legacy: A2uiAction): Promise<void> => { legacyCalls++; }
      );

      expect(dispatched.candidate).assertTrue();
      expect(dispatched.ok).assertTrue();
      expect(sendCalls).assertEqual(1);
      expect(legacyCalls).assertEqual(0);
      expect(bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.ACTION_RESULT &&
          JSON.stringify(message.payload).indexOf('"status":"paused"') >= 0
      ).length).assertEqual(0);

      const stale = cloneSnapshot(current as RegisteredPageSnapshot);
      stale.document.generatedAt = stale.document.generatedAt + '-stale';
      current = stale;
      const staleResult = await dispatchRegisteredPageActionCandidate(
        clicked,
        (currentAction: A2uiAction): Promise<boolean> => runtime.runPageAction(currentAction),
        async (_legacy: A2uiAction): Promise<void> => { legacyCalls++; }
      );
      expect(staleResult.candidate).assertTrue();
      expect(staleResult.ok).assertFalse();
      expect(sendCalls).assertEqual(1);
      expect(legacyCalls).assertEqual(0);
      runtime.dispose();
    });

    it('keeps the same QQ mail Send action on the existing client route', 0, async () => {
      const invoker = new RecordingPageToolInvoker();
      const handler = new RegisteredPageActionHandler(invoker);
      const command = JSON.parse(
        '{"requestKey":"qq:message-real-1","provider":"qq","accountLabel":"q***@qq.com",' +
        '"threadId":"thread-real-1","messageId":"message-real-1","to":["alice@example.com"],' +
        '"subject":"Re: QA","body":"Exact reply","replyMode":"reply","contextSummary":"QA"}'
      ) as Object;
      const clicked = action('html_mail_reply_send', command, 'client');
      clicked.label = '发送回复';
      clicked.prompt = 'qq:message-real-1';
      const surface = pageSurface('mail.search', action('mail.ai.reply.draft', command), 1);
      const current: RegisteredPageSnapshot = {
        surface,
        document: mailReplyDocument(surface, 'qq', command),
        generation: 1
      };
      let registeredCalls = 0;
      let legacyCalls = 0;
      const runtime = canary(
        new QueueModel([]), handler, (): RegisteredPageSnapshot | null => current
      );
      const dispatched = await dispatchRegisteredPageActionCandidate(
        clicked,
        async (_currentAction: A2uiAction): Promise<boolean> => {
          registeredCalls++;
          return runtime.runPageAction(clicked);
        },
        async (_legacy: A2uiAction): Promise<void> => { legacyCalls++; }
      );

      expect(dispatched.candidate).assertFalse();
      expect(dispatched.ok).assertTrue();
      expect(registeredCalls).assertEqual(0);
      expect(legacyCalls).assertEqual(1);
      runtime.dispose();
    });

    it('surfaces Gmail provider failure without legacy fallthrough or fake success', 0, async () => {
      const invoker = new RecordingPageToolInvoker();
      const handler = new RegisteredPageActionHandler(invoker);
      const bus = new TrackingBus();
      const command = JSON.parse(
        '{"requestKey":"gmail:thread-real-1","provider":"gmail","accountLabel":"g***@gmail.com",' +
        '"threadId":"thread-real-1","messageId":"message-real-1","to":["alice@example.com"],' +
        '"subject":"Re: QA","body":"Exact reply","replyMode":"reply","contextSummary":"QA"}'
      ) as Object;
      const clicked = action('html_mail_reply_send', command, 'client');
      clicked.label = '发送回复';
      clicked.prompt = 'gmail:thread-real-1';
      const surface = pageSurface('gmail.thread.read', action('gmail.ai.reply.draft', command), 1);
      const current: RegisteredPageSnapshot = {
        surface,
        document: mailReplyDocument(surface, 'gmail', command),
        generation: 1
      };
      let providerCalls = 0;
      let legacyCalls = 0;
      const runtime = canary(
        new QueueModel([]),
        handler,
        (): RegisteredPageSnapshot | null => current,
        bus,
        async (_actionId: string, _args: Object, _context: RegisteredPageActionContext): Promise<ActionExecutionResult> => {
          providerCalls++;
          return {
            status: 'error',
            errorCode: 'GMAIL_AUTH_REQUIRED',
            message: 'Gmail OAuth account is not connected.'
          };
        }
      );
      const dispatched = await dispatchRegisteredPageActionCandidate(
        clicked,
        (currentAction: A2uiAction): Promise<boolean> => runtime.runPageAction(currentAction),
        async (_legacy: A2uiAction): Promise<void> => { legacyCalls++; }
      );

      expect(dispatched.candidate).assertTrue();
      expect(dispatched.ok).assertFalse();
      expect(providerCalls).assertEqual(1);
      expect(legacyCalls).assertEqual(0);
      expect(lastActionResult(bus).indexOf('Gmail OAuth account is not connected.')).assertLarger(-1);
      expect(lastActionResult(bus).indexOf('"status":"success"')).assertEqual(-1);
      runtime.dispose();
    });

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

    it('maps every exact Wave 4 rendered confirmation to its fixed Action owner', 0, () => {
      const sourceIds: string[] = [
        'luckin.order.preview',
        'calendar.event.delete',
        'whatsapp.message.send',
        'ride.estimate',
        'ride.order.create'
      ];
      const pageActionIds: string[] = [
        'luckin.order.create',
        'calendar.event.delete.confirm',
        'whatsapp.message.send.confirm',
        'ride.order.confirm',
        'ride.order.cancel'
      ];
      const targetIds: string[] = [
        'luckin.order.create',
        'calendar.event.delete',
        'whatsapp.message.send',
        'ride.order.create',
        'ride.order.cancel'
      ];

      for (let index = 0; index < pageActionIds.length; index++) {
        const resolved = resolveRegisteredPageAction(
          sourceIds[index], action(pageActionIds[index], JSON.parse('{"marker":"exact"}') as Object)
        );
        expect(resolved === null).assertFalse();
        expect((resolved as RegisteredPageActionResolution).action.id).assertEqual(targetIds[index]);
        expect(isRegisteredPageActionCandidate(pageActionIds[index])).assertTrue();
      }

      expect(resolveRegisteredPageAction(
        'ride.app.link',
        action('ride.order.confirm', JSON.parse('{"estimateTraceId":"trace-real-1"}') as Object)
      )).assertNull();
    });

    it('keeps all Wave 4 candidates terminal when registered authority or provider fails', 0, async () => {
      const candidateIds: string[] = [
        'luckin.order.create',
        'calendar.event.delete.confirm',
        'whatsapp.message.send.confirm',
        'ride.order.confirm',
        'ride.order.cancel'
      ];
      let registeredCalls = 0;
      let legacyCalls = 0;

      for (let index = 0; index < candidateIds.length; index++) {
        const dispatched = await dispatchRegisteredPageActionCandidate(
          action(candidateIds[index], JSON.parse('{"marker":"exact"}') as Object),
          async (_clicked: A2uiAction): Promise<boolean> => {
            registeredCalls++;
            return false;
          },
          async (_legacy: A2uiAction): Promise<void> => { legacyCalls++; }
        );
        expect(dispatched.candidate).assertTrue();
        expect(dispatched.ok).assertFalse();
      }

      expect(registeredCalls).assertEqual(candidateIds.length);
      expect(legacyCalls).assertEqual(0);
    });

    it('does not turn natural language into a direct Wave 4 write action', 0, () => {
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
        expect(resolveVirtualRegisteredPageAction(actionIds[index], '请直接执行')).assertNull();
      }
    });

    it('requires positive provider completion evidence for every external Wave 4 write', 0, async () => {
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
        const invoker = new RecordingPageToolInvoker();
        const handler = new RegisteredPageActionHandler(invoker);
        const executionContext: RegisteredPageActionContext = {
          conversationId: 'provider-evidence',
          turnId: 'turn-1',
          surfaceId: 'surface-1',
          sourceToolId: actionId,
          planId: 'plan-1',
          runId: 'run-1',
          stepId: 'step-1',
          pageActionId: actionId
        };

        const missing = await handler.execute(actionId, JSON.parse('{}') as Object, executionContext);
        expect(missing.status).assertEqual('error');

        const positiveInvoker = new ProviderEvidenceInvoker('success');
        const positive = await new RegisteredPageActionHandler(positiveInvoker).execute(
          actionId, JSON.parse('{}') as Object, executionContext
        );
        expect(positive.status).assertEqual('success');

        const pausedInvoker = new ProviderEvidenceInvoker('confirm_required');
        const paused = await new RegisteredPageActionHandler(pausedInvoker).execute(
          actionId, JSON.parse('{}') as Object, executionContext
        );
        expect(paused.status).assertEqual('error');
      }
    });

    it('rejects malformed and explicitly failed inner provider write payloads', 0, async () => {
      const actionId = 'whatsapp.message.send';
      const executionContext: RegisteredPageActionContext = {
        conversationId: 'provider-inner-status',
        turnId: 'turn-1',
        surfaceId: 'surface-1',
        sourceToolId: actionId,
        planId: 'plan-1',
        runId: 'run-1',
        stepId: 'step-1',
        pageActionId: 'whatsapp.message.send.confirm'
      };

      const malformed = await new RegisteredPageActionHandler(
        new RawProviderEvidenceInvoker('{}')
      ).execute(actionId, JSON.parse('{}') as Object, executionContext);
      const innerFailure = await new RegisteredPageActionHandler(
        new RawProviderEvidenceInvoker('{"status":"failed","id":"message-fake"}')
      ).execute(actionId, JSON.parse('{}') as Object, executionContext);

      expect(malformed.status).assertEqual('error');
      expect(innerFailure.status).assertEqual('error');
    });

    it('rejects receipt-shaped evidence from the wrong action or negative status', 0, async () => {
      const executionContext: RegisteredPageActionContext = {
        conversationId: 'provider-action-evidence',
        turnId: 'turn-1',
        surfaceId: 'surface-1',
        sourceToolId: 'calendar.event.create',
        planId: 'plan-1',
        runId: 'run-1',
        stepId: 'step-1',
        pageActionId: 'calendar.event.create'
      };
      const wrongAction = await new RegisteredPageActionHandler(
        new RawProviderEvidenceInvoker('{"success":true,"orderId":"order-wrong-domain"}')
      ).execute('calendar.event.create', JSON.parse('{}') as Object, executionContext);
      const negativeStatus = await new RegisteredPageActionHandler(
        new RawProviderEvidenceInvoker('{"status":"failed","eventId":"event-fake"}')
      ).execute('calendar.event.create', JSON.parse('{}') as Object, executionContext);
      const wrongSource = await new RegisteredPageActionHandler(
        new WrongSourceProviderEvidenceInvoker()
      ).execute('calendar.event.create', JSON.parse('{}') as Object, executionContext);
      const failedReceipt = await new RegisteredPageActionHandler(
        new FailedReceiptProviderEvidenceInvoker()
      ).execute('calendar.event.create', JSON.parse('{}') as Object, executionContext);
      const deleteContext = JSON.parse(JSON.stringify(executionContext)) as RegisteredPageActionContext;
      deleteContext.sourceToolId = 'calendar.event.delete';
      deleteContext.pageActionId = 'calendar.event.delete.confirm';
      const missingDeleteAck = await new RegisteredPageActionHandler(
        new MissingDeleteAckProviderEvidenceInvoker()
      ).execute('calendar.event.delete', JSON.parse('{}') as Object, deleteContext);

      expect(wrongAction.status).assertEqual('error');
      expect(negativeStatus.status).assertEqual('error');
      expect(wrongSource.status).assertEqual('error');
      expect(failedReceipt.status).assertEqual('error');
      expect(missingDeleteAck.status).assertEqual('error');
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
