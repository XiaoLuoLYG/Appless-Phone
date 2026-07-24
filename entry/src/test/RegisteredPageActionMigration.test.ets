import { describe, expect, it } from '@ohos/hypium';
import {
  A2uiAction,
  A2uiCallResult,
  A2uiLabelValueData,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  ActionExecutionErrorResult,
  ActionExecutionResult,
  AgentMessage,
  AgentMessageType,
  CreateDataTaskPayload,
  DataResult,
  DataStepDecision,
  DataTaskExecutor,
  DataTaskPlanner,
  DynamicGenericToolResult,
  MailCalendarSuggestion,
  LocalModel,
  LinkedMessageBus,
  ObservationDigest,
  createSeedA2uiSurface,
  whatsAppProviderResultFromObservationForTest
} from '@loop/agent-core';
import {
  MultiAgentCanaryOptions,
  MultiAgentCanaryRuntime,
  MailDetailInPlaceEvent,
  MailDetailWriteLease
} from '../main/ets/pages/A2uiHome/agent/MultiAgentCanaryRuntime';
import {
  MailDetailSuggestionGuard,
  MailDetailUiEvent,
  publishMailDetailThenSuggest
} from '../main/ets/pages/A2uiHome/agent/MailDetailInPlaceUpdater';
import {
  RegisteredPageAction,
  RegisteredPageActionContext,
  SystemUriOpener,
  validateRegisteredPageActionArgs
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

interface MailThreadDataFixture {
  requestKey: string;
  provider: string;
  threadId: string;
  messageId: string;
  internetMessageId: string;
  subject: string;
  from: string;
  replyTo: string;
  to: string[];
  cc: string[];
  body: string;
  bodyHtml: string;
}

interface TestCancelPayload {
  reason: string;
}

interface QqMailReadFixture {
  clicked: A2uiAction;
  current: RegisteredPageSnapshot;
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

class PassthroughDataPlanner implements DataTaskPlanner {
  async next(
    task: CreateDataTaskPayload,
    observations: ObservationDigest[],
    _step: number
  ): Promise<DataStepDecision> {
    if (observations.length === 0) {
      return {
        kind: 'call',
        toolId: task.toolId,
        args: task.args,
        summary: 'execute registered read'
      };
    }
    return {
      kind: 'finish',
      toolId: task.toolId,
      args: JSON.parse('{}') as Object,
      summary: 'return observed read result'
    };
  }
}

class RecordingOpener implements SystemUriOpener {
  readonly uris: string[] = [];

  async open(uri: string): Promise<boolean> {
    this.uris.push(uri);
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

class CancelBeforeMailUiBus extends TrackingBus {
  cancelBeforeUi: boolean = true;

  publish(message: AgentMessage): void {
    if (this.cancelBeforeUi && message.type === AgentMessageType.TASK_CREATE_UI &&
      (JSON.stringify(message.payload).indexOf('mail.thread.read') >= 0 ||
        JSON.stringify(message.payload).indexOf('gmail.thread.read') >= 0)) {
      const payload: TestCancelPayload = {
        reason: 'test_cancel_before_skeleton'
      };
      const cancel: AgentMessage = {
        type: AgentMessageType.TURN_CANCEL,
        conversationId: message.conversationId,
        turnId: message.turnId,
        taskId: 'cancel-before-mail-ui',
        payload
      };
      super.publish(cancel);
    }
    super.publish(message);
  }
}

class DeferredValue<T> {
  readonly promise: Promise<T>;
  private resolveValue: ((value: T) => void) | null = null;

  constructor() {
    this.promise = new Promise<T>((resolve: (value: T) => void) => {
      this.resolveValue = resolve;
    });
  }

  resolve(value: T): void {
    const current = this.resolveValue;
    this.resolveValue = null;
    if (current !== null) {
      current(value);
    }
  }
}

async function pause(ms: number = 0): Promise<void> {
  await new Promise<void>((resolve: () => void) => setTimeout(resolve, ms));
}

async function waitForMailCalls(executor: DeferredMailReadExecutor, expected: number): Promise<void> {
  for (let attempt = 0; attempt < 100 && executor.calls.length < expected; attempt++) {
    await pause(1);
  }
  if (executor.calls.length < expected) {
    throw new Error('Mail Data executor did not receive the expected call.');
  }
}

function mailLeaseInactive(value: MailDetailWriteLease | null): boolean {
  return value === null || !value.isActive();
}

function successfulMailThreadData(task: CreateDataTaskPayload, body: string): DataResult {
  const args = task.args as Record<string, Object | string | number | boolean | null | undefined>;
  const data: MailThreadDataFixture = {
    requestKey: args['requestKey'] as string,
    provider: args['provider'] as string,
    threadId: args['threadId'] as string,
    messageId: args['messageId'] as string,
    internetMessageId: '',
    subject: args['subject'] as string,
    from: 'Sender <sender@example.com>',
    replyTo: 'sender@example.com',
    to: ['qa@example.com'],
    cc: [],
    body,
    bodyHtml: '<p>' + body + '</p>'
  };
  return {
    toolId: task.toolId,
    outputSchema: 'mailThread',
    status: 'success',
    data: data as Object,
    sources: [{
      provider: task.toolId === 'gmail.thread.read' ? 'Gmail API' : 'QQ Mail',
      backend: task.toolId === 'gmail.thread.read' ? 'oauth_api' : 'imap',
      operation: 'thread.read',
      fetchedAt: '2026-07-23T00:00:00.000Z'
    }],
    warnings: []
  };
}

class ImmediateMailReadExecutor implements DataTaskExecutor {
  calls: number = 0;

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls++;
    return successfulMailThreadData(task, '真实邮件正文');
  }
}

class DeferredMailReadExecutor implements DataTaskExecutor {
  readonly calls: CreateDataTaskPayload[] = [];
  readonly values: DeferredValue<DataResult>[] = [];

  execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls.push(task);
    const value = new DeferredValue<DataResult>();
    this.values.push(value);
    return value.promise;
  }

  succeed(index: number): void {
    this.values[index].resolve(successfulMailThreadData(this.calls[index], '真实邮件正文'));
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

class WhatsAppConfirmationInvoker implements RegisteredPageToolInvoker {
  readonly calls: ToolInvocationRecord[] = [];

  async invoke(
    toolId: string,
    prompt: string,
    pageActionId: string,
    args: Object
  ): Promise<RegisteredPageToolInvocation> {
    this.calls.push({ toolId, prompt, pageActionId, args });
    const result = successfulToolResult(toolId);
    const model = JSON.parse(result.surface.dataModelJson) as A2uiRuntimeDataModel;
    model.genericToolResults = [{
      sourceTag: 'Composio WhatsApp Business',
      toolName: 'whatsapp.message.send',
      title: '确认发送 WhatsApp 消息',
      status: 'confirm_required',
      summary: '将通过已授权的 WhatsApp Business 账号发送。',
      rows: [
        { label: '收件人', value: '+8613800138000' },
        { label: '消息', value: 'Appless QA run-1' }
      ],
      rawPreview: 'confirm whatsapp send to=+8613800138000',
      actions: [{
        id: 'whatsapp.message.send.confirm',
        label: '确认发送',
        prompt: '确认通过 WhatsApp Business 发送消息',
        variant: 'danger',
        kind: 'prompt',
        args
      }]
    }];
    result.surface.dataModelJson = JSON.stringify(model);
    return { ok: true, result, error: '' };
  }
}

class FixedProviderResultInvoker implements RegisteredPageToolInvoker {
  calls: number = 0;
  private readonly provider: DynamicGenericToolResult;

  constructor(provider: DynamicGenericToolResult) {
    this.provider = provider;
  }

  async invoke(
    toolId: string,
    _prompt: string,
    _pageActionId: string,
    _args: Object
  ): Promise<RegisteredPageToolInvocation> {
    this.calls++;
    const result = successfulToolResult(toolId);
    const model = JSON.parse(result.surface.dataModelJson) as A2uiRuntimeDataModel;
    model.genericToolResults = [{
      sourceTag: this.provider.sourceTag,
      toolName: this.provider.toolName,
      title: this.provider.title,
      status: this.provider.status,
      summary: this.provider.summary,
      rows: this.provider.rows,
      rawPreview: this.provider.rawPreview,
      actions: this.provider.actions
    }];
    result.surface.dataModelJson = JSON.stringify(model);
    return { ok: true, result, error: '' };
  }
}

class SocialPublicationErrorInvoker implements RegisteredPageToolInvoker {
  async invoke(
    toolId: string,
    _prompt: string,
    _pageActionId: string,
    _args: Object
  ): Promise<RegisteredPageToolInvocation> {
    const result = successfulToolResult(toolId);
    const model = JSON.parse(result.surface.dataModelJson) as A2uiRuntimeDataModel;
    model.socialHub.publication = {
      platform: 'x',
      operation: 'publish',
      accountId: '',
      accountName: '',
      text: 'Appless',
      status: 'error',
      updatedAt: '2026-07-24T00:00:00.000Z',
      error: 'Provider 没有返回真实账号 ID；不会创建或发布帖子。'
    };
    result.surface.dataModelJson = JSON.stringify(model);
    return { ok: true, result, error: '' };
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
  surface.runtimeOwner = 'multi_agent';
  surface.runtimeGeneration = sequence;
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
  pageAction?: RegisteredPageAction,
  opener: RecordingOpener = new RecordingOpener(),
  currentHostSurface?: () => A2uiSurfaceState | null,
  currentHostGeneration?: () => number,
  dataExecutor: DataTaskExecutor = new RejectDataExecutor(),
  onMailDetail?: (
    event: MailDetailInPlaceEvent,
    generation: number,
    lease: MailDetailWriteLease
  ) => Promise<void>,
  actionTimeoutMs: number = 1000
): MultiAgentCanaryRuntime {
  const options: MultiAgentCanaryOptions = {
    model,
    opener,
    pageAction: pageAction === undefined ? (
      actionId: string,
      args: Object,
      context: RegisteredPageActionContext
    ): Promise<ActionExecutionResult> => handler.execute(actionId, args, context) : pageAction,
    currentPageSnapshot: currentSnapshot,
    currentHostSurface: currentHostSurface === undefined ? (): A2uiSurfaceState | null => {
      const snapshot = currentSnapshot();
      return snapshot === null ? null : snapshot.surface;
    } : currentHostSurface,
    currentHostGeneration: currentHostGeneration === undefined ? (): number => {
      const snapshot = currentSnapshot();
      const generation = snapshot === null ? undefined : snapshot.surface.runtimeGeneration;
      return generation === undefined ? 0 : generation;
    } : currentHostGeneration,
    onSurface: (_surface: A2uiSurfaceState): boolean => true,
    onMemoryUpdate: (): void => {},
    dataPlanner: new PassthroughDataPlanner(),
    dataExecutor,
    onMailDetail,
    currentLocalDate: (): string => '2026-07-22',
    conversationId: 'registered-page-test',
    bus,
    submitTimeoutMs: 1000,
    actionTimeoutMs
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

function qqMailReadFixture(sequence: number = 1): QqMailReadFixture {
  const args = JSON.parse('{"requestKey":"qq:101","provider":"qq",' +
    '"threadId":"","messageId":"101","subject":"QA"}') as Object;
  const clicked = action('html_mail_detail_read', args, 'client');
  clicked.label = '加载正文';
  clicked.prompt = 'qq:101';
  const surface = pageSurface('mail.search', clicked, sequence);
  const current: RegisteredPageSnapshot = {
    surface,
    document: mailReplyDocument(surface, 'qq', args),
    generation: sequence
  };
  const fixture: QqMailReadFixture = {
    clicked,
    current
  };
  return fixture;
}

function mailCalendarSuggestion(requestKey: string = 'qq:101'): MailCalendarSuggestion {
  return {
    requestKey,
    provider: 'qq',
    threadId: '',
    messageId: '101',
    isWorkRelated: true,
    hasMeeting: true,
    title: '项目同步',
    start: '2026-07-24T10:00:00+08:00',
    end: '2026-07-24T10:30:00+08:00',
    displayTime: '明天 10:00',
    timezone: 'Asia/Shanghai',
    location: '',
    description: '项目同步',
    confidence: 'high',
    reason: '正文包含明确会议时间。'
  };
}

export default function registeredPageActionMigrationTest() {
  describe('registeredPageActionMigration', () => {
    it('routes exact current QQ and Gmail body reads through Action and Data agents in place', 0, async () => {
      class MailReadDataExecutor implements DataTaskExecutor {
        readonly calls: CreateDataTaskPayload[] = [];

        async execute(task: CreateDataTaskPayload): Promise<DataResult> {
          this.calls.push(task);
          const args = task.args as Record<string, Object | string | number | boolean | null | undefined>;
          const data: MailThreadDataFixture = {
            requestKey: args['requestKey'] as string,
            provider: args['provider'] as string,
            threadId: args['threadId'] as string,
            messageId: args['messageId'] as string,
            internetMessageId: '',
            subject: args['subject'] as string,
            from: 'Sender <sender@example.com>',
            replyTo: 'sender@example.com',
            to: ['qa@example.com'],
            cc: [],
            body: '真实邮件正文',
            bodyHtml: '<p>真实邮件正文</p>'
          };
          return {
            toolId: task.toolId,
            outputSchema: 'mailThread',
            status: 'success',
            data: data as Object,
            sources: [{
              provider: task.toolId === 'gmail.thread.read' ? 'Gmail API' : 'QQ Mail',
              backend: task.toolId === 'gmail.thread.read' ? 'oauth_api' : 'imap',
              operation: 'thread.read',
              fetchedAt: '2026-07-23T00:00:00.000Z'
            }],
            warnings: []
          };
        }
      }
      const providers: string[] = ['qq', 'gmail'];
      const expectedTools: string[] = ['mail.thread.read', 'gmail.thread.read'];
      for (let index = 0; index < providers.length; index++) {
        const provider = providers[index];
        const identity = provider === 'gmail' ? 'gmail-thread-real-1' : '101';
        const args = JSON.parse('{"requestKey":"' + provider + ':' + identity + '",' +
          '"provider":"' + provider + '","threadId":"' +
          (provider === 'gmail' ? identity : '') + '","messageId":"' +
          (provider === 'gmail' ? 'gmail-message-real-1' : identity) + '","subject":"QA"}') as Object;
        const clicked = action('html_mail_detail_read', args, 'client');
        clicked.label = '加载正文';
        clicked.prompt = provider + ':' + identity;
        const surface = pageSurface(provider === 'gmail' ? 'gmail.mail.search' : 'mail.search', clicked, index + 1);
        const current: RegisteredPageSnapshot = {
          surface,
          document: mailReplyDocument(surface, provider, args),
          generation: index + 1
        };
        const bus = new TrackingBus();
        const executor = new MailReadDataExecutor();
        const events: MailDetailInPlaceEvent[] = [];
        const runtime = canary(
          new QueueModel([]),
          new RegisteredPageActionHandler(new RecordingPageToolInvoker()),
          (): RegisteredPageSnapshot | null => current,
          bus,
          undefined,
          new RecordingOpener(),
          undefined,
          undefined,
          executor,
          async (event: MailDetailInPlaceEvent, generation: number): Promise<void> => {
            expect(generation).assertEqual(index + 1);
            events.push(event);
          }
        );
        let legacyCalls = 0;
        const result = await dispatchRegisteredPageActionCandidate(
          clicked,
          (candidate: A2uiAction): Promise<boolean> => runtime.runPageAction(candidate),
          async (_legacy: A2uiAction): Promise<void> => { legacyCalls++; }
        );

        expect(result.candidate).assertTrue();
        expect(result.ok).assertTrue();
        expect(legacyCalls).assertEqual(0);
        expect(executor.calls.length).assertEqual(1);
        expect(executor.calls[0].toolId).assertEqual(expectedTools[index]);
        expect(JSON.stringify(executor.calls[0].args)).assertEqual(JSON.stringify(args));
        expect(events.length).assertEqual(1);
        expect(events[0].status).assertEqual('success');
        expect(events[0].requestKey).assertEqual(provider + ':' + identity);
        expect(events[0].detail?.bodyText).assertEqual('真实邮件正文');
        expect(bus.messages.filter((message: AgentMessage): boolean =>
          message.type === AgentMessageType.INPUT_USER
        ).length).assertEqual(0);
        expect(bus.messages.filter((message: AgentMessage): boolean =>
          message.type === AgentMessageType.TASK_CREATE_DATA
        ).length).assertEqual(1);
        expect(bus.messages.filter((message: AgentMessage): boolean =>
          message.type === AgentMessageType.TASK_RESULT_DATA
        ).length).assertEqual(1);
        runtime.dispose();
      }
    });

    it('settles the mail body before a deferred calendar suggestion and enriches later without another provider or action', 0, async () => {
      const fixture = qqMailReadFixture();
      const executor = new ImmediateMailReadExecutor();
      const bus = new TrackingBus();
      const suggestion = new DeferredValue<MailCalendarSuggestion>();
      const events: MailDetailUiEvent[] = [];
      const guard = new MailDetailSuggestionGuard();
      const suggestionToken = guard.beginDetail();
      const runtime = canary(
        new QueueModel([]),
        new RegisteredPageActionHandler(new RecordingPageToolInvoker()),
        (): RegisteredPageSnapshot | null => fixture.current,
        bus,
        undefined,
        new RecordingOpener(),
        undefined,
        undefined,
        executor,
        async (
          event: MailDetailInPlaceEvent,
          _generation: number,
          lease: MailDetailWriteLease
        ): Promise<void> => publishMailDetailThenSuggest(event, {
          initialIsCurrent: (): boolean => guard.isCurrent(suggestionToken) && lease.isActive(),
          enrichmentIsCurrent: (): boolean => guard.isCurrent(suggestionToken),
          writeEvent: (next: MailDetailUiEvent): void => { events.push(next); },
          saveSuggestion: (_requestKey: string, _value: MailCalendarSuggestion): void => {},
          suggest: (_detail): Promise<MailCalendarSuggestion> => suggestion.promise
        }),
        20
      );

      expect(await runtime.runPageAction(fixture.clicked)).assertTrue();
      expect(events.length).assertEqual(1);
      expect(events[0].detail?.bodyText).assertEqual('真实邮件正文');
      expect(events[0].calendarSuggestion === undefined).assertTrue();
      expect(executor.calls).assertEqual(1);
      expect(bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.ACTION_RUN
      ).length).assertEqual(1);

      suggestion.resolve(mailCalendarSuggestion());
      await pause(5);
      expect(events.length).assertEqual(2);
      expect(events[1].detail?.bodyText).assertEqual('真实邮件正文');
      expect(events[1].calendarSuggestion?.title).assertEqual('项目同步');
      expect(executor.calls).assertEqual(1);
      expect(bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.ACTION_RUN
      ).length).assertEqual(1);
      guard.invalidate();
      runtime.dispose();
    });

    it('invalidates the previous suggestion when the next mail read starts but its provider remains pending', 0, async () => {
      const detailEvent: MailDetailInPlaceEvent = {
        requestKey: 'qq:101', provider: 'qq', identityDigest: 'identity-101',
        status: 'success',
        detail: {
          requestKey: 'qq:101', provider: 'qq', threadId: '', messageId: '101',
          internetMessageId: '', subject: 'A', from: 'sender@example.com',
          replyTo: 'sender@example.com', to: ['qa@example.com'], cc: [],
          bodyText: 'A 的真实邮件正文', bodyHtml: '<p>A 的真实邮件正文</p>'
        },
        error: ''
      };
      const guard = new MailDetailSuggestionGuard();
      const token = guard.beginDetail();
      const suggestion = new DeferredValue<MailCalendarSuggestion>();
      const events: MailDetailUiEvent[] = [];
      await publishMailDetailThenSuggest(detailEvent, {
        initialIsCurrent: (): boolean => guard.isCurrent(token),
        enrichmentIsCurrent: (): boolean => guard.isCurrent(token),
        writeEvent: (event: MailDetailUiEvent): void => { events.push(event); },
        saveSuggestion: (_requestKey: string, _value: MailCalendarSuggestion): void => {},
        suggest: (_detail): Promise<MailCalendarSuggestion> => suggestion.promise
      });

      const fixture = qqMailReadFixture(2);
      const blockedProvider = new DeferredMailReadExecutor();
      const runtime = canary(
        new QueueModel([]),
        new RegisteredPageActionHandler(new RecordingPageToolInvoker()),
        (): RegisteredPageSnapshot | null => fixture.current,
        undefined,
        undefined,
        new RecordingOpener(),
        undefined,
        undefined,
        blockedProvider,
        async (_event: MailDetailInPlaceEvent): Promise<void> => {},
        1000
      );
      guard.invalidateForPageAction(fixture.clicked.id);
      const pending = runtime.runPageAction(fixture.clicked);
      await waitForMailCalls(blockedProvider, 1);
      suggestion.resolve(mailCalendarSuggestion('qq:101'));
      await pause(5);
      expect(events.length).assertEqual(1);
      expect(events[0].detail?.bodyText).assertEqual('A 的真实邮件正文');
      runtime.cancelActiveTurn('blocked_provider_test_done');
      expect(await pending).assertFalse();
      runtime.dispose();
    });

    it('invalidates the previous suggestion even when the next mail read is rejected before runtime execution', 0, async () => {
      const detailEvent: MailDetailInPlaceEvent = {
        requestKey: 'qq:101', provider: 'qq', identityDigest: 'identity-101',
        status: 'success',
        detail: {
          requestKey: 'qq:101', provider: 'qq', threadId: '', messageId: '101',
          internetMessageId: '', subject: 'A', from: 'sender@example.com',
          replyTo: 'sender@example.com', to: ['qa@example.com'], cc: [],
          bodyText: 'A 的真实邮件正文', bodyHtml: '<p>A 的真实邮件正文</p>'
        },
        error: ''
      };
      const guard = new MailDetailSuggestionGuard();
      const token = guard.beginDetail();
      const suggestion = new DeferredValue<MailCalendarSuggestion>();
      const events: MailDetailUiEvent[] = [];
      await publishMailDetailThenSuggest(detailEvent, {
        initialIsCurrent: (): boolean => guard.isCurrent(token),
        enrichmentIsCurrent: (): boolean => guard.isCurrent(token),
        writeEvent: (event: MailDetailUiEvent): void => { events.push(event); },
        saveSuggestion: (_requestKey: string, _value: MailCalendarSuggestion): void => {},
        suggest: (_detail): Promise<MailCalendarSuggestion> => suggestion.promise
      });

      const fixture = qqMailReadFixture(2);
      const mutated = JSON.parse(JSON.stringify(fixture.clicked)) as A2uiAction;
      (mutated.args as Record<string, Object | string | number | boolean | null | undefined>)['messageId'] = '102';
      const runtime = canary(
        new QueueModel([]),
        new RegisteredPageActionHandler(new RecordingPageToolInvoker()),
        (): RegisteredPageSnapshot | null => fixture.current
      );
      guard.invalidateForPageAction(mutated.id);
      expect(await runtime.runPageAction(mutated)).assertFalse();
      suggestion.resolve(mailCalendarSuggestion('qq:101'));
      await pause(5);
      expect(events.length).assertEqual(1);
      expect(events[0].detail?.bodyText).assertEqual('A 的真实邮件正文');
      runtime.dispose();
    });

    it('keeps one body event when calendar suggestion rejects or becomes stale', 0, async () => {
      const detailEvent: MailDetailInPlaceEvent = {
        requestKey: 'qq:101',
        provider: 'qq',
        identityDigest: 'identity-101',
        status: 'success',
        detail: {
          requestKey: 'qq:101', provider: 'qq', threadId: '', messageId: '101',
          internetMessageId: '', subject: 'QA', from: 'sender@example.com',
          replyTo: 'sender@example.com', to: ['qa@example.com'], cc: [],
          bodyText: '真实邮件正文', bodyHtml: '<p>真实邮件正文</p>'
        },
        error: ''
      };
      const rejected: MailDetailUiEvent[] = [];
      await publishMailDetailThenSuggest(detailEvent, {
        initialIsCurrent: (): boolean => true,
        enrichmentIsCurrent: (): boolean => true,
        writeEvent: (event: MailDetailUiEvent): void => { rejected.push(event); },
        saveSuggestion: (_requestKey: string, _value: MailCalendarSuggestion): void => {},
        suggest: (_detail): Promise<MailCalendarSuggestion> => Promise.reject(new Error('suggestion timeout'))
      });
      await pause(5);
      expect(rejected.length).assertEqual(1);
      expect(rejected[0].detail?.bodyText).assertEqual('真实邮件正文');

      const staleModes: string[] = ['new_surface', 'new_generation', 'dispose'];
      for (let index = 0; index < staleModes.length; index++) {
        const deferred = new DeferredValue<MailCalendarSuggestion>();
        const events: MailDetailUiEvent[] = [];
        let current = true;
        await publishMailDetailThenSuggest(detailEvent, {
          initialIsCurrent: (): boolean => current,
          enrichmentIsCurrent: (): boolean => current,
          writeEvent: (event: MailDetailUiEvent): void => { events.push(event); },
          saveSuggestion: (_requestKey: string, _value: MailCalendarSuggestion): void => {},
          suggest: (_detail): Promise<MailCalendarSuggestion> => deferred.promise
        });
        current = false;
        deferred.resolve(mailCalendarSuggestion());
        await pause(5);
        expect(events.length).assertEqual(1);
        expect(events[0].detail?.bodyText).assertEqual('真实邮件正文');
      }
    });

    it('rejects stale or mutated mail body reads before Data execution', 0, async () => {
      const args = JSON.parse('{"requestKey":"qq:101","provider":"qq",' +
        '"threadId":"","messageId":"101","subject":"QA"}') as Object;
      const clicked = action('html_mail_detail_read', args, 'client');
      clicked.label = '加载正文';
      clicked.prompt = 'qq:101';
      const surface = pageSurface('mail.search', clicked, 1);
      let current: RegisteredPageSnapshot = {
        surface,
        document: mailReplyDocument(surface, 'qq', args),
        generation: 1
      };
      const executor = new RejectDataExecutor();
      const runtime = canary(
        new QueueModel([]),
        new RegisteredPageActionHandler(new RecordingPageToolInvoker()),
        (): RegisteredPageSnapshot | null => current,
        undefined,
        undefined,
        new RecordingOpener(),
        undefined,
        undefined,
        executor
      );
      const mutated = JSON.parse(JSON.stringify(clicked)) as A2uiAction;
      (mutated.args as Record<string, Object | string | number | boolean | null | undefined>)['messageId'] =
        '102';
      expect(await runtime.runPageAction(mutated)).assertFalse();
      const stale = cloneSnapshot(current);
      stale.surface.surfaceId = 'stale-mail-surface';
      current = stale;
      expect(await runtime.runPageAction(clicked)).assertFalse();
      runtime.dispose();
    });

    it('returns the exact provider error in place with one Data call and no legacy host read', 0, async () => {
      class FailingMailReadExecutor implements DataTaskExecutor {
        calls: number = 0;

        async execute(task: CreateDataTaskPayload): Promise<DataResult> {
          this.calls++;
          return {
            toolId: task.toolId,
            outputSchema: 'mailThread',
            status: 'error',
            data: new Object(),
            sources: [],
            warnings: [],
            error: {
              code: 'PROVIDER_ERROR',
              message: 'QQ IMAP timeout',
              retryable: true
            }
          };
        }
      }
      const args = JSON.parse('{"requestKey":"qq:101","provider":"qq",' +
        '"threadId":"","messageId":"101","subject":"QA"}') as Object;
      const clicked = action('html_mail_detail_read', args, 'client');
      clicked.label = '加载正文';
      clicked.prompt = 'qq:101';
      const surface = pageSurface('mail.search', clicked, 1);
      const current: RegisteredPageSnapshot = {
        surface,
        document: mailReplyDocument(surface, 'qq', args),
        generation: 1
      };
      const executor = new FailingMailReadExecutor();
      const events: MailDetailInPlaceEvent[] = [];
      const runtime = canary(
        new QueueModel([]),
        new RegisteredPageActionHandler(new RecordingPageToolInvoker()),
        (): RegisteredPageSnapshot | null => current,
        undefined,
        undefined,
        new RecordingOpener(),
        undefined,
        undefined,
        executor,
        async (event: MailDetailInPlaceEvent): Promise<void> => { events.push(event); }
      );
      expect(await runtime.runPageAction(clicked)).assertFalse();
      expect(executor.calls).assertEqual(1);
      expect(events.length).assertEqual(1);
      expect(events[0].status).assertEqual('error');
      expect(events[0].requestKey).assertEqual('qq:101');
      expect(events[0].error).assertEqual('QQ IMAP timeout');
      runtime.dispose();
    });

    it('clears prepared mail state after repeated cancel before skeleton and accepts the next read', 0, async () => {
      let fixture = qqMailReadFixture();
      const bus = new CancelBeforeMailUiBus();
      const executor = new ImmediateMailReadExecutor();
      const events: MailDetailInPlaceEvent[] = [];
      const runtime = canary(
        new QueueModel([]),
        new RegisteredPageActionHandler(new RecordingPageToolInvoker()),
        (): RegisteredPageSnapshot | null => fixture.current,
        bus,
        undefined,
        new RecordingOpener(),
        undefined,
        undefined,
        executor,
        async (event: MailDetailInPlaceEvent): Promise<void> => { events.push(event); },
        20
      );
      for (let index = 0; index < 8; index++) {
        fixture = qqMailReadFixture(index + 1);
        expect(await runtime.runPageAction(fixture.clicked)).assertFalse();
      }
      bus.cancelBeforeUi = false;
      fixture = qqMailReadFixture(9);
      expect(await runtime.runPageAction(fixture.clicked)).assertTrue();
      expect(events.length).assertEqual(1);
      expect(events[0].requestKey).assertEqual('qq:101');
      runtime.dispose();
    });

    it('suppresses late provider and writer completion after cancel and dispose', 0, async () => {
      let fixture = qqMailReadFixture();
      const executor = new DeferredMailReadExecutor();
      const events: MailDetailInPlaceEvent[] = [];
      const runtime = canary(
        new QueueModel([]),
        new RegisteredPageActionHandler(new RecordingPageToolInvoker()),
        (): RegisteredPageSnapshot | null => fixture.current,
        undefined,
        undefined,
        new RecordingOpener(),
        undefined,
        undefined,
        executor,
        async (event: MailDetailInPlaceEvent): Promise<void> => { events.push(event); },
        1000
      );
      const canceled = runtime.runPageAction(fixture.clicked);
      await waitForMailCalls(executor, 1);
      runtime.cancelActiveTurn('test_cancel_after_skeleton');
      expect(await canceled).assertFalse();
      executor.succeed(0);
      await pause(20);
      expect(events.length).assertEqual(0);

      fixture = qqMailReadFixture(2);
      const disposed = runtime.runPageAction(fixture.clicked);
      await waitForMailCalls(executor, 2);
      runtime.dispose();
      expect(await disposed).assertFalse();
      executor.succeed(1);
      await pause(20);
      expect(events.length).assertEqual(0);
    });

    it('invalidates the host write lease when callback is slower than the action deadline', 0, async () => {
      const fixture = qqMailReadFixture();
      const started = new DeferredValue<boolean>();
      const release = new DeferredValue<boolean>();
      let capturedLease: MailDetailWriteLease | null = null;
      let applied = 0;
      const runtime = canary(
        new QueueModel([]),
        new RegisteredPageActionHandler(new RecordingPageToolInvoker()),
        (): RegisteredPageSnapshot | null => fixture.current,
        undefined,
        undefined,
        new RecordingOpener(),
        undefined,
        undefined,
        new ImmediateMailReadExecutor(),
        async (
          _event: MailDetailInPlaceEvent,
          _generation: number,
          lease: MailDetailWriteLease
        ): Promise<void> => {
          capturedLease = lease;
          started.resolve(true);
          await release.promise;
          if (lease.isActive()) {
            applied++;
          }
        },
        20
      );
      const running = runtime.runPageAction(fixture.clicked);
      await started.promise;
      expect(await running).assertFalse();
      expect(mailLeaseInactive(capturedLease)).assertTrue();
      release.resolve(true);
      await pause(20);
      expect(applied).assertEqual(0);
      runtime.dispose();
    });

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
        JSON.parse('{"provider":"stripe","recipient":"real-user","amountText":"5.00",' +
          '"currency":"USD","phase":"confirm"}') as Object
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
        JSON.parse('{"provider":"stripe","recipient":"mallory","amountText":"5000",' +
          '"currency":"USD","phase":"confirm"}') as Object
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

    it('rejects stale Gmail payment ride and hotel writes until all host identities are exact', 0, async () => {
      const invoker = new RecordingPageToolInvoker();
      const handler = new RegisteredPageActionHandler(invoker);
      const opener = new RecordingOpener();
      let retained: RegisteredPageSnapshot | null = null;
      let host: A2uiSurfaceState | null = null;
      let hostGeneration = 0;
      let pageCalls = 0;
      const runtime = canary(
        new QueueModel([]),
        handler,
        (): RegisteredPageSnapshot | null => retained,
        undefined,
        async (): Promise<ActionExecutionResult> => {
          pageCalls++;
          return {
            status: 'success',
            output: JSON.parse('{"providerStatus":"exact"}') as Object
          };
        },
        opener,
        (): A2uiSurfaceState | null => host,
        (): number => hostGeneration
      );
      const cases: Array<[string, A2uiAction]> = [
        ['gmail.draft.create', action('gmail.draft.apply', JSON.parse(
          '{"provider":"gmail_oauth","draftId":"draft-1","threadId":"thread-1",' +
            '"to":"a@example.com","subject":"QA","body":"exact"}'
        ) as Object)],
        ['payment.send', action('payment.confirm', JSON.parse(
          '{"provider":"stripe","recipient":"real-user","amountText":"5.00",' +
            '"currency":"USD","phase":"confirm"}'
        ) as Object)],
        ['ride.estimate', action('ride.order.confirm', JSON.parse(
          '{"productCategory":"Express","estimateTraceId":"trace-real-1"}'
        ) as Object)],
        ['hotel.detail', action('hotel.booking.open', JSON.parse(
          '{"hotelId":319,"bookingUrl":"https://rollinggo.cn/pages/hotel/detail/index?' +
            'id=319&checkInDate=2026-07-22&checkOutDate=2026-07-23&roomCount=1&adultCount=2&childCount=0"}'
        ) as Object)]
      ];

      for (let index = 0; index < cases.length; index++) {
        const oldSurface = pageSurface(cases[index][0], cases[index][1], index + 40);
        retained = snapshot(oldSurface, index + 1);
        host = pageSurface(cases[index][0], cases[index][1], index + 80);
        hostGeneration = host.runtimeGeneration as number;
        expect(await runtime.runPageAction(cases[index][1])).assertFalse();

        host = cloneSnapshot(retained as RegisteredPageSnapshot).surface;
        host.runtimeOwner = 'legacy';
        hostGeneration = host.runtimeGeneration as number;
        expect(await runtime.runPageAction(cases[index][1])).assertFalse();

        host = cloneSnapshot(retained as RegisteredPageSnapshot).surface;
        hostGeneration = host.runtimeGeneration as number;
        expect(await runtime.runPageAction(cases[index][1])).assertTrue();
      }

      expect(pageCalls).assertEqual(3);
      expect(invoker.calls.length).assertEqual(0);
      expect(opener.uris.length).assertEqual(1);
      runtime.dispose();
    });

    it('maps every exact Wave 4 rendered confirmation to its fixed Action owner', 0, () => {
      const sourceIds: string[] = [
        'luckin.order.preview',
        'calendar.events.search',
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

    it('keeps hotel navigation and booking clicks terminal in the registered route', 0, async () => {
      const candidateIds: string[] = ['hotel.navigate', 'hotel.booking.open'];
      let registeredCalls = 0;
      let legacyCalls = 0;
      for (let index = 0; index < candidateIds.length; index++) {
        const result = await dispatchRegisteredPageActionCandidate(
          action(candidateIds[index], JSON.parse('{"marker":"exact"}') as Object),
          async (_clicked: A2uiAction): Promise<boolean> => {
            registeredCalls++;
            return false;
          },
          async (_legacy: A2uiAction): Promise<void> => { legacyCalls++; }
        );
        expect(result.candidate).assertTrue();
        expect(result.ok).assertFalse();
      }
      expect(registeredCalls).assertEqual(2);
      expect(legacyCalls).assertEqual(0);
    });

    it('rejects a constructed Calendar delete when it is not the exact current search-card action', 0, async () => {
      const invoker = new ProviderEvidenceInvoker('success');
      const handler = new RegisteredPageActionHandler(invoker);
      const exactArgs = JSON.parse('{"eventId":"event-provider-real-1","calendarId":"primary","sendUpdates":"none"}') as Object;
      const exact = action('calendar.event.delete.confirm', exactArgs);
      const surface = pageSurface('calendar.events.search', exact, 30);
      let current: RegisteredPageSnapshot | null = snapshot(surface, 30);
      const runtime = canary(new QueueModel([]), handler, (): RegisteredPageSnapshot | null => current);
      const forged = action(
        'calendar.event.delete.confirm',
        JSON.parse('{"eventId":"event-forged","calendarId":"primary","sendUpdates":"none"}') as Object
      );

      expect(await runtime.runPageAction(forged)).assertFalse();
      expect(await runtime.runPageAction(exact)).assertTrue();
      expect(invoker.calls.length).assertEqual(1);
      expect(invoker.calls[0].toolId).assertEqual('calendar.event.delete');
      expect(invoker.calls[0].pageActionId).assertEqual('calendar.event.delete.confirm');
      expect(JSON.stringify(invoker.calls[0].args)).assertEqual(JSON.stringify(exactArgs));
      current = null;
      expect(await runtime.runPageAction(exact)).assertFalse();
      expect(invoker.calls.length).assertEqual(1);
      runtime.dispose();
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

    it('resolves only an unambiguous Calendar create into a review action without guessing event IDs', 0, () => {
      const create = resolveVirtualRegisteredPageAction(
        'calendar.event.create',
        '帮我在 2026年7月30日下午3点创建一个title为AIPhoneDemo的30分钟日程'
      );
      expect(create === null).assertFalse();
      expect(JSON.stringify((create as A2uiAction).args)).assertEqual(
        '{"title":"AIPhoneDemo","start":"2026-07-30T15:00:00+08:00",' +
        '"end":"2026-07-30T15:30:00+08:00","timezone":"Asia/Shanghai","calendarId":"primary"}'
      );
      expect(resolveVirtualRegisteredPageAction(
        'calendar.event.create', '明天下午帮我创建一个日程'
      )).assertNull();

      const actionIds: string[] = [
        'luckin.order.create',
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

    it('normalizes the real WhatsApp messages payload into one canonical provider completion', 0, async () => {
      const provider: DynamicGenericToolResult = whatsAppProviderResultFromObservationForTest(
        '{"data":{"messages":[{"id":"wamid.provider-real-1"}]},"error":null}'
      );
      const malformed: DynamicGenericToolResult = whatsAppProviderResultFromObservationForTest(
        '{not-json'
      );
      const missing: DynamicGenericToolResult = whatsAppProviderResultFromObservationForTest(
        '{"data":{"messages":[]},"error":null}'
      );
      const failed: DynamicGenericToolResult = whatsAppProviderResultFromObservationForTest(
        '{"data":{"messages":[{"id":"wamid.must-not-pass"}]},"successful":false,' +
        '"error":"provider rejected send"}'
      );
      const objectError: DynamicGenericToolResult = whatsAppProviderResultFromObservationForTest(
        '{"data":{"messages":[{"id":"wamid.must-not-pass-object"}]},' +
        '"error":{"code":100,"message":"provider rejected send"}}'
      );
      const nestedError: DynamicGenericToolResult = whatsAppProviderResultFromObservationForTest(
        '{"data":{"messages":[{"id":"wamid.must-not-pass-nested"}],' +
        '"error":[{"code":100,"message":"nested provider rejection"}]},"error":null}'
      );
      const invoker = new FixedProviderResultInvoker(provider);
      const context: RegisteredPageActionContext = {
        conversationId: 'whatsapp-provider-shape',
        turnId: 'turn-1',
        surfaceId: 'surface-1',
        sourceToolId: 'whatsapp.message.send',
        planId: 'plan-1',
        runId: 'run-1',
        stepId: 'step-1',
        pageActionId: 'whatsapp.message.send.confirm'
      };
      const completed = await new RegisteredPageActionHandler(invoker).execute(
        'whatsapp.message.send',
        JSON.parse('{"toNumber":"+8613800138000","text":"QA"}') as Object,
        context
      );

      expect(provider.status).assertEqual('success');
      expect(provider.rows.filter((row: A2uiLabelValueData): boolean =>
        row.label === 'Message ID' && row.value === 'wamid.provider-real-1'
      ).length).assertEqual(1);
      expect(provider.actions === undefined || provider.actions.length === 0).assertTrue();
      expect(completed.status).assertEqual('success');
      expect(invoker.calls).assertEqual(1);
      expect(malformed.status).assertEqual('error');
      expect(missing.status).assertEqual('error');
      expect(failed.status).assertEqual('error');
      expect(objectError.status).assertEqual('error');
      expect(objectError.rows.filter((row: A2uiLabelValueData): boolean =>
        row.label === 'Message ID'
      ).length).assertEqual(0);
      expect(nestedError.status).assertEqual('error');
      expect(nestedError.rows.filter((row: A2uiLabelValueData): boolean =>
        row.label === 'Message ID'
      ).length).assertEqual(0);
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
      expect(social.kind).assertEqual('settled');
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

    it('resolves and invokes only bounded safe initial Action requests without write authority', 0, async () => {
      const luckinPrompt = '帮我点一杯瑞幸生椰拿铁，半糖少冰';
      const socialPreviewPrompt = '帮我在 X 发帖：Appless migration ready（只生成预览，不发布）';
      const paypalPrompt = '用 PayPal 给罗一格转 1 美元';
      const googlePayPrompt = '用 Google Pay 给罗一格转 1 美元';
      const stripePrompt = '帮我设置 Stripe 收款账户';
      const whatsappPrompt =
        '帮我给 WhatsApp 测试联系人 +8613800138000 发送消息：Appless QA run-1';

      expect(JSON.stringify(resolveVirtualRegisteredPageAction(
        'luckin.order.preview', luckinPrompt
      )?.args)).assertEqual('{"originalQuery":"' + luckinPrompt + '"}');
      expect(JSON.stringify(resolveVirtualRegisteredPageAction(
        'social.post.preview', socialPreviewPrompt
      )?.args)).assertEqual(
        '{"platform":"x","operation":"publish","text":"Appless migration ready"}'
      );
      expect(resolveVirtualRegisteredPageAction(
        'social.post.preview', '帮我发一条社交动态'
      )).assertNull();
      expect(JSON.stringify(resolveVirtualRegisteredPageAction(
        'social.post.preview', '帮我为 X 起草一条介绍 Appless 新版本的帖子'
      )?.args)).assertEqual(
        '{"platform":"x","operation":"publish","text":"介绍 Appless 新版本"}'
      );
      expect(JSON.stringify(resolveVirtualRegisteredPageAction(
        'social.post.preview', '帮我在 LinkedIn 发帖：从 X 迁移到 Appless'
      )?.args)).assertEqual(
        '{"platform":"linkedin","operation":"publish","text":"从 X 迁移到 Appless"}'
      );
      expect(JSON.stringify(resolveVirtualRegisteredPageAction(
        'social.post.preview', '帮我为 LinkedIn 起草一条从 X 迁移到 Appless 的帖子'
      )?.args)).assertEqual(
        '{"platform":"linkedin","operation":"publish","text":"从 X 迁移到 Appless"}'
      );
      expect(resolveVirtualRegisteredPageAction(
        'social.post.preview', '帮我在 X 和 LinkedIn 发帖：Appless'
      )).assertNull();
      expect(JSON.stringify(resolveVirtualRegisteredPageAction(
        'payment.send', paypalPrompt
      )?.args)).assertEqual('{"originalQuery":"' + paypalPrompt + '"}');
      expect(JSON.stringify(resolveVirtualRegisteredPageAction(
        'payment.send', googlePayPrompt
      )?.args)).assertEqual('{"originalQuery":"' + googlePayPrompt + '"}');
      expect(JSON.stringify(resolveVirtualRegisteredPageAction(
        'payment.account.setup', stripePrompt
      )?.args)).assertEqual('{"originalQuery":"' + stripePrompt + '"}');
      expect(JSON.stringify(resolveVirtualRegisteredPageAction(
        'whatsapp.message.send', whatsappPrompt
      )?.args)).assertEqual(
        '{"toNumber":"+8613800138000","text":"Appless QA run-1"}'
      );
      expect(resolveVirtualRegisteredPageAction(
        'whatsapp.message.send', '帮我给 WhatsApp 测试联系人发送消息：Appless QA run-1'
      )).assertNull();
      expect(resolveVirtualRegisteredPageAction(
        'whatsapp.message.send', '帮我给 WhatsApp 测试联系人 +8613800138000 发送消息：'
      )).assertNull();
      expect(resolveVirtualRegisteredPageAction(
        'whatsapp.message.send',
        '帮我给 WhatsApp 测试联系人 +1234567890123456 发送消息：Appless QA run-1'
      )).assertNull();

      expect(validateRegisteredPageActionArgs(
        'luckin.order.preview', JSON.parse('{"originalQuery":"' + luckinPrompt + '"}') as Object
      ).ok).assertTrue();
      expect(validateRegisteredPageActionArgs(
        'social.post.preview',
        JSON.parse('{"platform":"x","operation":"publish","text":"Appless migration ready"}') as Object
      ).ok).assertTrue();
      expect(validateRegisteredPageActionArgs(
        'social.post.preview',
        JSON.parse('{"platform":"x","operation":"publish","text":""}') as Object
      ).ok).assertFalse();
      expect(validateRegisteredPageActionArgs(
        'payment.send', JSON.parse('{"originalQuery":"' + paypalPrompt + '"}') as Object
      ).ok).assertTrue();
      expect(validateRegisteredPageActionArgs(
        'payment.account.setup', JSON.parse('{"originalQuery":"' + stripePrompt + '"}') as Object
      ).ok).assertTrue();
      const unsafe: string[] = [
        'luckin.order.create',
        'payment.confirm',
        'payment.capture',
        'stripe.account.create',
        'whatsapp.message.send.confirm',
        'ride.order.create'
      ];
      for (let index = 0; index < unsafe.length; index++) {
        expect(validateRegisteredPageActionArgs(
          unsafe[index], JSON.parse('{"originalQuery":"请直接执行"}') as Object
        ).ok).assertFalse();
      }

      const invoker = new RecordingPageToolInvoker();
      const handler = new RegisteredPageActionHandler(invoker);
      const prompts: string[] = [luckinPrompt, paypalPrompt, googlePayPrompt, stripePrompt];
      const actionIds: string[] = [
        'luckin.order.preview',
        'payment.send',
        'payment.send',
        'payment.account.setup'
      ];
      for (let index = 0; index < actionIds.length; index++) {
        const resolved = resolveVirtualRegisteredPageAction(actionIds[index], prompts[index]);
        const result = await handler.execute(
          actionIds[index],
          (resolved as A2uiAction).args as Object,
          {
            conversationId: 'safe-initial',
            turnId: 'turn-' + index.toString(),
            surfaceId: 'virtual:' + actionIds[index],
            sourceToolId: 'virtual.action-intent',
            planId: 'direct:' + index.toString(),
            runId: 'run-' + index.toString(),
            stepId: 'step-1',
            pageActionId: actionIds[index],
            virtualAction: true
          }
        );
        expect(result.status).assertEqual('success');
      }
      expect(invoker.calls.length).assertEqual(4);
      expect(invoker.calls[0].toolId).assertEqual('luckin.order.preview');
      expect(invoker.calls[0].prompt).assertEqual(luckinPrompt);
      expect(invoker.calls[1].toolId).assertEqual('payment.send');
      expect(invoker.calls[1].prompt).assertEqual(paypalPrompt);
      expect(invoker.calls[2].toolId).assertEqual('payment.send');
      expect(invoker.calls[2].prompt).assertEqual(googlePayPrompt);
      expect(invoker.calls[3].toolId).assertEqual('payment.account.setup');
      expect(invoker.calls[3].prompt).assertEqual(stripePrompt);
      const serializedCalls = JSON.stringify(invoker.calls);
      expect(serializedCalls.indexOf('luckin.order.create')).assertEqual(-1);
      expect(serializedCalls.indexOf('payment.confirm')).assertEqual(-1);
      expect(serializedCalls.indexOf('payment.capture')).assertEqual(-1);
      expect(serializedCalls.indexOf('stripe.account.create')).assertEqual(-1);
    });

    it('returns SocialHub publication errors from the production page action handler', 0, async () => {
      const result = await new RegisteredPageActionHandler(
        new SocialPublicationErrorInvoker()
      ).execute(
        'social.post.preview',
        JSON.parse('{"platform":"x","operation":"publish","text":"Appless"}') as Object,
        {
          conversationId: 'social-preview',
          turnId: 'turn-1',
          surfaceId: 'virtual:social-preview',
          sourceToolId: 'virtual.action-intent',
          planId: 'direct:social-preview',
          runId: 'social-preview',
          stepId: 'step-1',
          pageActionId: 'social.post.preview',
          virtualAction: true
        }
      );
      const failure = result as ActionExecutionErrorResult;

      expect(result.status).assertEqual('error');
      expect(failure.errorCode).assertEqual('ACTION_PAGE_PROVIDER_ERROR');
      expect(failure.message).assertEqual(
        'Provider 没有返回真实账号 ID；不会创建或发布帖子。'
      );
    });

    it('invokes WhatsApp only as its existing confirm-required surface', 0, async () => {
      const invoker = new WhatsAppConfirmationInvoker();
      const args = JSON.parse(
        '{"toNumber":"+8613800138000","text":"Appless QA run-1"}'
      ) as Object;
      const result = await new RegisteredPageActionHandler(invoker).execute(
        'whatsapp.message.send',
        args,
        {
          conversationId: 'whatsapp-preview',
          turnId: 'turn-1',
          surfaceId: 'virtual:whatsapp',
          sourceToolId: 'virtual.action-intent',
          planId: 'direct:whatsapp',
          runId: 'whatsapp',
          stepId: 'step-1',
          pageActionId: 'whatsapp.message.send',
          virtualAction: true
        }
      );

      expect(result.status).assertEqual('success');
      expect(invoker.calls.length).assertEqual(1);
      expect(invoker.calls[0].toolId).assertEqual('whatsapp.message.send');
      expect(invoker.calls[0].pageActionId).assertEqual('whatsapp.message.send');
      expect(invoker.calls[0].prompt).assertEqual('whatsapp.message.send');
      expect(JSON.stringify(invoker.calls[0].args)).assertEqual(JSON.stringify(args));
      expect(JSON.stringify(invoker.calls).indexOf('whatsapp.message.send.confirm')).assertEqual(-1);
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
