import { describe, expect, it } from '@ohos/hypium';
import {
  ActionAgent,
  ActionArgsValidator,
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionFollowUp,
  ActionOffer,
  ActionOfferContext,
  ActionOffersReadyPayload,
  ActionPlan,
  ActionPlanCompiler,
  ActionPlanDraft,
  ActionPlanDraftPayload,
  ActionPlanRequestPayload,
  ActionPlanReadyPayload,
  ActionPlanStepOutput,
  ActionProgressPayload,
  ActionResultPayload,
  ActionRunPayload,
  ActionValidationResult,
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  ClientActionAuthorizer,
  CreateDataTaskPayload,
  CreateUiTaskPayload,
  DataResult,
  JsonValue,
  LinkedMessageBus,
  PausedActionRun,
  RegisteredActionExecutor,
  SurfaceActionAuthorizer,
  ToolDefinition,
  ToolDefinitionLookup,
  ToolRiskLevel,
  UiRenderResultPayload,
  VirtualActionIntent,
  VirtualActionIntentResolver,
  WorkflowRunArgs
} from '@loop/agent-core';

type JsonRecord = Record<string, JsonValue | undefined>;

class ActionLookup implements ToolDefinitionLookup {
  confirmCall: boolean = false;
  calls: number = 0;

  find(toolId: string): ToolDefinition | null {
    this.calls++;
    if (toolId === 'hotel.search') {
      return definition(toolId, 'read', ['hotel.detail', 'hotel.navigate']);
    }
    if (toolId === 'hotel.detail') {
      return definition(toolId, 'read', ['hotel.booking.open']);
    }
    if (toolId === 'hotel.navigate') {
      const navigate = definition(toolId, 'draft', []);
      navigate.backendPriority = ['system_intent'];
      navigate.authModes = ['system'];
      return navigate;
    }
    if (toolId === 'hotel.booking.open') {
      return definition(toolId, this.confirmCall ? 'confirm_required' : 'draft', []);
    }
    if (toolId === 'social.source') {
      return definition(toolId, 'read', ['social.reply.draft']);
    }
    if (toolId === 'gmail.source') {
      return definition(toolId, 'read', ['gmail.draft.create']);
    }
    if (toolId === 'social.reply.draft' || toolId === 'gmail.draft.create') {
      return definition(toolId, 'draft', []);
    }
    if (toolId === 'memory.update') {
      return definition(toolId, 'draft', ['memory.update']);
    }
    return null;
  }
}

function definition(
  toolId: string,
  riskLevel: ToolRiskLevel,
  actions: string[]
): ToolDefinition {
  return {
    toolId,
    domain: 'hotel',
    intent: toolId,
    riskLevel,
    backendPriority: ['local_adapter'],
    authModes: ['none'],
    inputSchema: `${toolId}Request`,
    outputSchema: `${toolId}Result`,
    a2uiComponent: 'HotelResults',
    actions: actions.slice()
  };
}

class ExactActionSurface implements SurfaceActionAuthorizer {
  allowed: boolean = true;

  allows(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    actionId: string,
    args: Object
  ): boolean {
    const primary = conversationId === 'conversation-1' &&
      turnId === 'turn-1' &&
      surfaceId === 'surface-1';
    const secondary = conversationId === 'conversation-2' &&
      turnId === 'turn-2' &&
      surfaceId === 'surface-2';
    const virtual = conversationId === 'conversation-1' &&
      turnId === 'turn-1' &&
      surfaceId === 'virtual:virtual-request';
    if (!this.allowed || (!primary && !secondary && !virtual)) {
      return false;
    }
    if (actionId === 'hotel.detail') {
      return JSON.stringify(args) === '{"hotelId":101}';
    }
    if (actionId === 'hotel.navigate') {
      return JSON.stringify(args) === '{"hotelId":101,"latitude":22.5,"longitude":114}';
    }
    if (actionId === 'hotel.booking.open') {
      return JSON.stringify(args).indexOf('"hotelId":101') >= 0 &&
        JSON.stringify(args).indexOf('rollinggo.cn/pages/hotel/detail/index') >= 0;
    }
    if (actionId === 'social.reply.draft') {
      return JSON.stringify(args) === '{}';
    }
    if (actionId === 'memory.update') {
      return conversationId === 'conversation-1' &&
        turnId === 'turn-1' &&
        surfaceId === 'virtual:virtual-request' &&
        JSON.stringify(args) ===
          '{"personaId":"travel_companion","summary":"我在北京",' +
          '"memoryText":"No saved preference. 我在北京",' +
          '"reason":"User explicitly stated a stable location."}';
    }
    return false;
  }
}

class NoClientAction implements ClientActionAuthorizer {
  allows(_actionId: string, _args: Object): boolean {
    return false;
  }
}

class ExactArgs implements ActionArgsValidator {
  reject: boolean = false;

  validate(_actionId: string, args: Object): ActionValidationResult {
    if (this.reject || args === null || typeof args !== 'object' || Array.isArray(args)) {
      return {
        ok: false,
        code: 'ACTION_ARGS_REJECTED',
        message: 'Action args rejected.'
      };
    }
    return {
      ok: true,
      code: '',
      message: ''
    };
  }
}

class TestGate {
  readonly promise: Promise<void>;
  private resolvePromise: (() => void) | null = null;

  constructor() {
    this.promise = new Promise<void>((resolve: () => void) => {
      this.resolvePromise = resolve;
    });
  }

  open(): void {
    const resolve = this.resolvePromise;
    this.resolvePromise = null;
    if (resolve !== null) {
      resolve();
    }
  }
}

class DeferredOfferResolver {
  readonly starts: TestGate[] = [new TestGate(), new TestGate()];
  calls: number = 0;
  private readonly resolvers: Array<((offers: ActionOffer[]) => void) | null> = [];

  async resolve(
    _data: DataResult,
    _context: ActionOfferContext
  ): Promise<ActionOffer[]> {
    const index = this.calls;
    this.calls++;
    const pending = new Promise<ActionOffer[]>((resolve: (offers: ActionOffer[]) => void) => {
      this.resolvers[index] = resolve;
    });
    this.starts[index].open();
    return pending;
  }

  finish(index: number, offers: ActionOffer[]): void {
    const resolve = this.resolvers[index];
    this.resolvers[index] = null;
    if (resolve !== null && resolve !== undefined) {
      resolve(offers);
    }
  }
}

class RecordingRegisteredExecutor implements RegisteredActionExecutor {
  readonly actionIds: string[] = [];
  readonly serializedArgs: string[] = [];
  readonly contexts: string[] = [];
  results: ActionExecutionResult[] = [];
  gate: TestGate | null = null;
  gateActionId: string = '';

  async execute(
    actionId: string,
    args: Object,
    context: ActionExecutionContext
  ): Promise<ActionExecutionResult> {
    this.actionIds.push(actionId);
    this.serializedArgs.push(JSON.stringify(args));
    this.contexts.push(
      `${context.conversationId}|${context.turnId}|${context.surfaceId}|` +
        `${context.planId}|${context.runId}|${context.stepId}`
    );
    const gate = this.gate;
    if (gate !== null &&
      (this.gateActionId.length === 0 || this.gateActionId === actionId)) {
      await gate.promise;
    }
    const result = this.results[this.actionIds.length - 1];
    if (result !== undefined) {
      return result;
    }
    return {
      status: 'success',
      output: JSON.parse(`{"actionId":"${actionId}"}`) as Object
    };
  }
}

function success(output: string, followUp?: ActionFollowUp): ActionExecutionResult {
  const result: ActionExecutionResult = {
    status: 'success',
    output: JSON.parse(output) as Object
  };
  if (followUp !== undefined) {
    result.followUp = followUp;
  }
  return result;
}

function catalog(
  lookup: ActionLookup,
  surface: ExactActionSurface = new ExactActionSurface(),
  validator: ExactArgs = new ExactArgs()
): ActionCatalog {
  return new ActionCatalog(lookup, surface, new NoClientAction(), validator);
}

async function noOffers(
  _data: DataResult,
  _context: ActionOfferContext
): Promise<ActionOffer[]> {
  return [];
}

class ScriptedActionPlanCompiler implements ActionPlanCompiler {
  readonly goals: string[] = [];
  readonly offerIds: string[] = [];
  readonly allowedIds: string[] = [];
  draft: ActionPlanDraft;

  constructor(draft: ActionPlanDraft) {
    this.draft = draft;
  }

  async compile(
    goal: string,
    offers: ActionOffer[],
    allowedActionIds: string[]
  ): Promise<ActionPlanDraft> {
    this.goals.push(goal);
    for (let index = 0; index < offers.length; index++) {
      this.offerIds.push(offers[index].offerId);
    }
    for (let index = 0; index < allowedActionIds.length; index++) {
      this.allowedIds.push(allowedActionIds[index]);
    }
    return this.draft;
  }
}

class MemoryVirtualIntentResolver implements VirtualActionIntentResolver {
  calls: number = 0;

  async resolve(request: ActionPlanRequestPayload): Promise<VirtualActionIntent | null> {
    this.calls++;
    if (request.virtual !== true || request.personaId !== 'travel_companion' ||
      request.inputText !== '我在北京') {
      return null;
    }
    return {
      sourceToolId: 'memory.update',
      offer: {
        offerId: 'memory-update',
        actionId: 'memory.update',
        label: '更新记忆',
        variant: 'primary',
        args: JSON.parse(
          '{"personaId":"travel_companion","summary":"我在北京",' +
          '"memoryText":"No saved preference. 我在北京",' +
          '"reason":"User explicitly stated a stable location."}'
        ) as Object
      },
      autoRun: true
    };
  }
}

async function composedOffers(
  data: DataResult,
  _context: ActionOfferContext
): Promise<ActionOffer[]> {
  if (data.toolId === 'social.source') {
    return [{
      offerId: 'offer-generate',
      actionId: 'social.reply.draft',
      label: '生成回复',
      variant: 'primary',
      args: new Object()
    }];
  }
  return [{
    offerId: 'offer-save',
    actionId: 'gmail.draft.create',
    label: '保存草稿',
    variant: 'secondary',
    args: new Object()
  }];
}

function compiledPlan(firstArgs: Object = new Object()): ActionPlanDraft {
  return {
    planId: 'plan-1',
    runId: 'run-1',
    label: '生成并保存',
    steps: [{
      stepId: 'generate',
      actionId: 'social.reply.draft',
      args: firstArgs
    }, {
      stepId: 'save',
      actionId: 'gmail.draft.create',
      args: new Object(),
      inputFrom: [{
        target: '/body',
        stepId: 'generate',
        path: '/body'
      }]
    }]
  };
}

function singleOfferPlan(
  planId: string = 'single-plan',
  runId: string = 'single-run'
): ActionPlanDraft {
  return {
    planId,
    runId,
    label: '生成回复',
    steps: [{
      stepId: 'generate',
      actionId: 'social.reply.draft',
      args: new Object()
    }]
  };
}

function singlePlanRequest(index: number): ActionPlanRequestPayload {
  return {
    uiTaskId: `capacity-ui-${index}`,
    dataTaskIds: [`capacity-data-${index}`],
    goal: `capacity-goal-${index}`,
    allowedActionIds: ['social.reply.draft'],
    skillId: ''
  };
}

function navigateOffer(offerId: string): ActionOffer {
  return {
    offerId,
    actionId: 'hotel.navigate',
    label: '导航到酒店',
    variant: 'secondary',
    args: JSON.parse(
      '{"hotelId":101,"latitude":22.5,"longitude":114}'
    ) as Object
  };
}

function compositePlan(
  planId: string = 'plan-1',
  turnId: string = 'turn-1',
  surfaceId: string = 'surface-1'
): ActionPlan {
  return JSON.parse(
    `{"planId":"${planId}","turnId":"${turnId}","surfaceId":"${surfaceId}",` +
      '"label":"Open detail then navigate","steps":[' +
      '{"stepId":"detail","actionId":"hotel.detail","args":{"hotelId":101}},' +
      '{"stepId":"navigate","actionId":"hotel.navigate",' +
      '"args":{"hotelId":101,"latitude":22.5,"longitude":114}}]}'
  ) as ActionPlan;
}

function followUpThenConfirmPlan(planId: string): ActionPlan {
  return JSON.parse(
    `{"planId":"${planId}","turnId":"turn-1","surfaceId":"surface-1",` +
      '"label":"Open detail then confirm booking","steps":[' +
      '{"stepId":"detail","actionId":"hotel.detail","args":{"hotelId":101}},' +
      '{"stepId":"booking","actionId":"hotel.booking.open",' +
      '"args":{"hotelId":101,"bookingUrl":"https://rollinggo.cn/pages/hotel/detail/index?id=101&checkInDate=2026-08-15&checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0"}}]}'
  ) as ActionPlan;
}

function planCreate(runId: string, candidate: ActionPlan): ActionPlanDraftPayload {
  const draft: ActionPlanDraft = {
    planId: candidate.planId,
    runId: runId,
    label: candidate.label,
    steps: candidate.steps
  };
  return {
    uiTaskId: 'ui-1',
    dataTaskId: 'data-1',
    sourceToolId: 'hotel.search',
    draft
  };
}

function message(
  type: AgentMessageType,
  payload: Object,
  turnId: string = 'turn-1',
  taskId: string = 'action-task-1',
  conversationId: string = 'conversation-1'
): AgentMessage {
  return {
    type,
    conversationId,
    turnId,
    taskId,
    payload
  };
}

function planRequest(): ActionPlanRequestPayload {
  return {
    uiTaskId: 'ui-1',
    dataTaskIds: ['social-data', 'gmail-data'],
    goal: '生成回复后保存草稿',
    allowedActionIds: ['social.reply.draft', 'gmail.draft.create'],
    skillId: ''
  };
}

function observedTask(taskId: string, toolId: string): CreateDataTaskPayload {
  return {
    taskId,
    roundId: 'turn-1',
    skillId: '',
    goal: toolId,
    allowedToolIds: [toolId],
    toolId,
    outputSchema: `${toolId}Result`,
    args: new Object(),
    required: true
  };
}

function observedResult(toolId: string): DataResult {
  return {
    toolId,
    outputSchema: `${toolId}Result`,
    status: 'success',
    sources: [],
    data: new Object(),
    warnings: []
  };
}

function publishCompilerInputs(bus: LinkedMessageBus): void {
  bus.publish(message(
    AgentMessageType.TASK_CREATE_DATA,
    observedTask('social-data', 'social.source'),
    'turn-1',
    'social-data'
  ));
  bus.publish(message(
    AgentMessageType.TASK_CREATE_DATA,
    observedTask('gmail-data', 'gmail.source'),
    'turn-1',
    'gmail-data'
  ));
  bus.publish(message(
    AgentMessageType.TASK_RESULT_DATA,
    observedResult('gmail.source'),
    'turn-1',
    'gmail-data'
  ));
  bus.publish(message(
    AgentMessageType.TASK_RESULT_DATA,
    observedResult('social.source'),
    'turn-1',
    'social-data'
  ));
}

function publishPlan(
  bus: LinkedMessageBus,
  payload: ActionPlanDraftPayload,
  turnId: string = 'turn-1',
  taskId: string = 'action-task-1',
  conversationId: string = 'conversation-1',
  surfaceId: string = 'surface-1'
): void {
  const uiResult: UiRenderResultPayload = { surfaceId: surfaceId, state: 'result' };
  bus.publish(message(
    AgentMessageType.ACTION_PLAN_DRAFT,
    payload,
    turnId,
    taskId,
    conversationId
  ));
  bus.publish(message(
    AgentMessageType.TASK_RESULT_UI,
    uiResult,
    turnId,
    payload.uiTaskId,
    conversationId
  ));
}

function workflowRun(
  ready: ActionPlanReadyPayload,
  confirmedStepId?: string
): ActionRunPayload {
  const args: WorkflowRunArgs = {
    planId: ready.planId,
    runId: ready.runId
  };
  const payload: ActionRunPayload = {
    surfaceId: ready.surfaceId,
    runId: ready.runId,
    actionId: 'workflow.run',
    args
  };
  if (confirmedStepId !== undefined) {
    payload.confirmedStepId = confirmedStepId;
  }
  return payload;
}

function readyIdentity(
  planId: string,
  runId: string,
  surfaceId: string = 'surface-1'
): ActionPlanReadyPayload {
  const args: WorkflowRunArgs = {
    planId,
    runId
  };
  return {
    uiTaskId: 'ui-1',
    surfaceId,
    planId,
    runId,
    label: 'confirmed action',
    actionId: 'workflow.run',
    args
  };
}

function directRun(
  runId: string,
  actionId: string,
  args: Object,
  surfaceId: string = 'surface-1',
  sourceToolId: string = 'hotel.search'
): ActionRunPayload {
  return {
    surfaceId,
    runId,
    sourceToolId,
    actionId,
    args
  };
}

async function receive(reader: AgentMessageReader): Promise<AgentMessage> {
  const next = await reader.receive();
  if (next === null) {
    throw new Error('observer closed');
  }
  return next;
}

async function receiveType(
  reader: AgentMessageReader,
  type: AgentMessageType
): Promise<AgentMessage> {
  while (true) {
    const next = await receive(reader);
    if (next.type === type) {
      return next;
    }
  }
}

async function settle(): Promise<void> {
  for (let index = 0; index < 12; index++) {
    await Promise.resolve();
  }
}

async function receiveUntilResult(reader: AgentMessageReader): Promise<AgentMessage[]> {
  const messages: AgentMessage[] = [];
  while (true) {
    const next = await receive(reader);
    messages.push(next);
    if (next.type === AgentMessageType.ACTION_RESULT) {
      return messages;
    }
  }
}

function messagesOfType(
  messages: AgentMessage[],
  type: AgentMessageType
): AgentMessage[] {
  return messages.filter(
    (current: AgentMessage): boolean => current.type === type
  );
}

export default function actionAgentTest() {
  describe('actionAgent', () => {
    it('auto-runs one exact zero-Data virtual Action without compiler or UI', 0, async () => {
      const bus = new LinkedMessageBus();
      const compiler = new ScriptedActionPlanCompiler(compiledPlan());
      const virtualResolver = new MemoryVirtualIntentResolver();
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(
        bus,
        catalog(new ActionLookup()),
        noOffers,
        executor,
        compiler,
        virtualResolver
      );
      const observer = bus.openReader();
      agent.start();
      const request: ActionPlanRequestPayload = {
        uiTaskId: 'input-1:round-1:virtual',
        dataTaskIds: [],
        goal: 'Remember the explicit user statement',
        allowedActionIds: ['memory.update'],
        personaId: 'travel_companion',
        skillId: '',
        inputText: '我在北京',
        virtual: true
      };

      bus.publish(message(
        AgentMessageType.ACTION_PLAN_REQUEST,
        request,
        'turn-1',
        'virtual-request'
      ));
      const observed = await receiveUntilResult(observer);
      const result = observed[observed.length - 1].payload as ActionResultPayload;

      expect(result.status).assertEqual('success');
      expect(result.surfaceId).assertEqual('virtual:virtual-request');
      expect(virtualResolver.calls).assertEqual(1);
      expect(compiler.goals.length).assertEqual(0);
      expect(executor.actionIds.join(',')).assertEqual('memory.update');
      expect(executor.serializedArgs.join(',')).assertEqual(
        '{"personaId":"travel_companion","summary":"我在北京",' +
        '"memoryText":"No saved preference. 我在北京",' +
        '"reason":"User explicitly stated a stable location."}'
      );
      expect(messagesOfType(observed, AgentMessageType.ACTION_PLAN_DRAFT).length).assertEqual(0);
      expect(messagesOfType(observed, AgentMessageType.ACTION_PLAN_READY).length).assertEqual(0);
      expect(messagesOfType(observed, AgentMessageType.TASK_CREATE_UI).length).assertEqual(0);
      agent.stop();
      observer.close();
    });

    it('rejects a zero-Data Action request when no virtual resolver owns it', 0, async () => {
      const bus = new LinkedMessageBus();
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(
        bus,
        catalog(new ActionLookup()),
        noOffers,
        executor,
        new ScriptedActionPlanCompiler(compiledPlan())
      );
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_PLAN_REQUEST,
        {
          uiTaskId: 'input-1:round-1:virtual',
          dataTaskIds: [],
          goal: 'Unowned virtual request',
          allowedActionIds: ['memory.update'],
          personaId: 'travel_companion',
          skillId: '',
          inputText: '我在北京',
          virtual: true
        } as ActionPlanRequestPayload,
        'turn-1',
        'unowned-virtual-request'
      ));
      const result = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;

      expect(result.status).assertEqual('error');
      expect(result.errorCode).assertEqual('ACTION_VIRTUAL_INTENT_UNAVAILABLE');
      expect(result.surfaceId).assertEqual('virtual:unowned-virtual-request');
      expect(result.planId).assertEqual('direct:virtual:unowned-virtual-request');
      expect(result.runId).assertEqual('virtual:unowned-virtual-request');
      expect(executor.actionIds.length).assertEqual(0);
      agent.stop();
      observer.close();
    });

    it('compiles a composed request from ordered current offers before READY', 0, async () => {
      const bus = new LinkedMessageBus();
      const compiler = new ScriptedActionPlanCompiler(compiledPlan());
      const agent = new ActionAgent(
        bus,
        catalog(new ActionLookup()),
        composedOffers,
        new RecordingRegisteredExecutor(),
        compiler
      );
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_PLAN_REQUEST,
        planRequest(),
        'turn-1',
        'plan-request'
      ));
      publishCompilerInputs(bus);
      const draftMessage = await receiveType(observer, AgentMessageType.ACTION_PLAN_DRAFT);
      const payload = draftMessage.payload as ActionPlanDraftPayload;
      const uiResult: UiRenderResultPayload = {
        surfaceId: 'surface-1',
        state: 'result'
      };
      bus.publish(message(
        AgentMessageType.TASK_RESULT_UI,
        uiResult,
        'turn-1',
        'ui-1'
      ));
      const ready = (await receiveType(
        observer,
        AgentMessageType.ACTION_PLAN_READY
      )).payload as ActionPlanReadyPayload;

      expect(compiler.goals.join(',')).assertEqual('生成回复后保存草稿');
      expect(compiler.offerIds.join(',')).assertEqual('offer-generate,offer-save');
      expect(compiler.allowedIds.join(',')).assertEqual(
        'social.reply.draft,gmail.draft.create'
      );
      expect(payload.dataTaskId).assertEqual('social-data');
      expect(payload.sourceToolId).assertEqual('social.source');
      expect(payload.draft.steps[1].inputFrom![0].target).assertEqual('/body');
      expect(ready.uiTaskId).assertEqual('ui-1');
      expect(ready.surfaceId).assertEqual('surface-1');
      expect(ready.planId).assertEqual('plan-1');
      expect(ready.runId).assertEqual('run-1');

      agent.stop();
      observer.close();
    });

    it('rejects compiler steps that mutate or invent current offers', 0, async () => {
      const bus = new LinkedMessageBus();
      const compiler = new ScriptedActionPlanCompiler(
        compiledPlan(JSON.parse('{"invented":true}') as Object)
      );
      const agent = new ActionAgent(
        bus,
        catalog(new ActionLookup()),
        composedOffers,
        new RecordingRegisteredExecutor(),
        compiler
      );
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_PLAN_REQUEST,
        planRequest(),
        'turn-1',
        'invalid-plan-request'
      ));
      publishCompilerInputs(bus);
      const observed = await receiveUntilResult(observer);
      const result = observed[observed.length - 1].payload as ActionResultPayload;

      expect(result.errorCode).assertEqual('ACTION_PLAN_OFFER_MISMATCH');
      expect(messagesOfType(observed, AgentMessageType.ACTION_PLAN_DRAFT).length).assertEqual(0);
      expect(messagesOfType(observed, AgentMessageType.ACTION_PLAN_READY).length).assertEqual(0);
      agent.stop();
      observer.close();
    });

    it('runs an exact direct offer without invoking the optional compiler', 0, async () => {
      const bus = new LinkedMessageBus();
      const compiler = new ScriptedActionPlanCompiler(compiledPlan());
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(
        bus,
        catalog(new ActionLookup()),
        noOffers,
        executor,
        compiler
      );
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun(
          'run-direct-no-compiler',
          'hotel.navigate',
          JSON.parse(
            '{"hotelId":101,"latitude":22.5,"longitude":114}'
          ) as Object
        )
      ));
      const result = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;

      expect(result.status).assertEqual('success');
      expect(compiler.goals.length).assertEqual(0);
      expect(executor.actionIds.join(',')).assertEqual('hotel.navigate');
      agent.stop();
      observer.close();
    });

    it('treats only an internally authorized exact confirm-required surface click as direct confirmation', 0, async () => {
      const bus = new LinkedMessageBus();
      const lookup = new ActionLookup();
      lookup.confirmCall = true;
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(bus, catalog(lookup), noOffers, executor);
      const observer = bus.openReader();
      agent.start();
      const args = JSON.parse(
        '{"hotelId":101,"bookingUrl":"https://rollinggo.cn/pages/hotel/detail/index?id=101&' +
          'checkInDate=2026-08-15&checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0"}'
      ) as Object;
      const exact = message(
        AgentMessageType.ACTION_RUN,
        directRun('run-exact-click', 'hotel.booking.open', args, 'surface-1', 'hotel.detail'),
        'turn-1',
        'exact-click'
      );

      expect(agent.authorizeDirectSurfaceRun(exact)).assertTrue();
      const forgedArgs = message(
        AgentMessageType.ACTION_RUN,
        directRun(
          'run-exact-click',
          'hotel.booking.open',
          JSON.parse(
            '{"hotelId":999,"bookingUrl":"https://rollinggo.cn/pages/hotel/detail/index?id=999"}'
          ) as Object,
          'surface-1',
          'hotel.detail'
        ),
        'turn-1',
        'exact-click'
      );
      bus.publish(forgedArgs);
      const forged = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(forged.status).assertEqual('error');
      expect(executor.actionIds.length).assertEqual(0);

      bus.publish(exact);
      const completed = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(completed.status).assertEqual('success');
      expect(executor.actionIds.join(',')).assertEqual('hotel.booking.open');

      const unconfirmed = message(
        AgentMessageType.ACTION_RUN,
        directRun('run-unconfirmed', 'hotel.booking.open', args, 'surface-1', 'hotel.detail'),
        'turn-1',
        'unconfirmed-click'
      );
      bus.publish(unconfirmed);
      const paused = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(paused.status).assertEqual('paused');
      expect(executor.actionIds.length).assertEqual(1);

      const stopped = message(
        AgentMessageType.ACTION_RUN,
        directRun('run-stopped-proof', 'hotel.booking.open', args, 'surface-1', 'hotel.detail'),
        'turn-1',
        'stopped-proof'
      );
      expect(agent.authorizeDirectSurfaceRun(stopped)).assertTrue();
      agent.stop();
      agent.start();
      bus.publish(stopped);
      const stoppedResult = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(stoppedResult.status).assertEqual('paused');
      expect(executor.actionIds.length).assertEqual(1);

      agent.stop();
      observer.close();
    });

    it('does not let a pending offer resolver block cancellation or later Actions', 0, async () => {
      const bus = new LinkedMessageBus();
      const deferred = new DeferredOfferResolver();
      const executor = new RecordingRegisteredExecutor();
      const resolveOffers = async (
        data: DataResult,
        context: ActionOfferContext
      ): Promise<ActionOffer[]> => deferred.resolve(data, context);
      const agent = new ActionAgent(
        bus,
        catalog(new ActionLookup()),
        resolveOffers,
        executor
      );
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.TASK_CREATE_DATA,
        observedTask('resolver-data', 'hotel.search'),
        'turn-1',
        'resolver-data'
      ));
      bus.publish(message(
        AgentMessageType.TASK_RESULT_DATA,
        observedResult('hotel.search'),
        'turn-1',
        'resolver-data'
      ));
      await deferred.starts[0].promise;
      bus.publish(message(
        AgentMessageType.TURN_CANCEL,
        new Object(),
        'turn-1',
        'cancel-resolver'
      ));
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun(
          'after-resolver-cancel',
          'hotel.navigate',
          JSON.parse(
            '{"hotelId":101,"latitude":22.5,"longitude":114}'
          ) as Object,
          'surface-2'
        ),
        'turn-2',
        'after-resolver-cancel',
        'conversation-2'
      ));
      await settle();
      const recoveredBeforeResolver = executor.actionIds.length === 1;

      deferred.finish(0, [navigateOffer('late-canceled-offer')]);
      await settle();
      bus.publish(message(
        AgentMessageType.INPUT_USER,
        JSON.parse('{"text":"resolver-cancel-marker"}') as Object,
        'marker-turn',
        'resolver-cancel-marker'
      ));
      let lateOffers = 0;
      let next = await receive(observer);
      while (next.type !== AgentMessageType.INPUT_USER) {
        if (next.type === AgentMessageType.ACTION_OFFERS_READY &&
          next.taskId === 'resolver-data') {
          lateOffers++;
        }
        next = await receive(observer);
      }

      expect(recoveredBeforeResolver).assertTrue();
      expect(executor.actionIds.join(',')).assertEqual('hotel.navigate');
      expect(lateOffers).assertEqual(0);
      agent.stop();
      observer.close();
    });

    it('fences late offer resolution across stop and reused task identities', 0, async () => {
      const bus = new LinkedMessageBus();
      const deferred = new DeferredOfferResolver();
      const resolveOffers = async (
        data: DataResult,
        context: ActionOfferContext
      ): Promise<ActionOffer[]> => deferred.resolve(data, context);
      const agent = new ActionAgent(
        bus,
        catalog(new ActionLookup()),
        resolveOffers,
        new RecordingRegisteredExecutor()
      );
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.TASK_CREATE_DATA,
        observedTask('reused-data', 'hotel.search'),
        'turn-1',
        'reused-data'
      ));
      bus.publish(message(
        AgentMessageType.TASK_RESULT_DATA,
        observedResult('hotel.search'),
        'turn-1',
        'reused-data'
      ));
      await deferred.starts[0].promise;

      agent.stop();
      agent.start();
      bus.publish(message(
        AgentMessageType.TASK_CREATE_DATA,
        observedTask('reused-data', 'hotel.search'),
        'turn-1',
        'reused-data'
      ));
      bus.publish(message(
        AgentMessageType.TASK_RESULT_DATA,
        observedResult('hotel.search'),
        'turn-1',
        'reused-data'
      ));
      await settle();
      const restartedBeforeOldCompletion = deferred.calls === 2;

      deferred.finish(0, [navigateOffer('stale-reused-offer')]);
      await deferred.starts[1].promise;
      deferred.finish(1, [navigateOffer('current-reused-offer')]);
      await settle();
      bus.publish(message(
        AgentMessageType.INPUT_USER,
        JSON.parse('{"text":"resolver-restart-marker"}') as Object,
        'marker-turn',
        'resolver-restart-marker'
      ));
      const offers: ActionOffersReadyPayload[] = [];
      let next = await receive(observer);
      while (next.type !== AgentMessageType.INPUT_USER) {
        if (next.type === AgentMessageType.ACTION_OFFERS_READY &&
          next.taskId === 'reused-data') {
          offers.push(next.payload as ActionOffersReadyPayload);
        }
        next = await receive(observer);
      }

      expect(restartedBeforeOldCompletion).assertTrue();
      expect(offers.length).assertEqual(1);
      expect(offers[0].offers[0].offerId).assertEqual('current-reused-offer');
      agent.stop();
      observer.close();
    });

    it('publishes only catalog-approved immutable Action offers for an observed Data result', 0, async () => {
      const bus = new LinkedMessageBus();
      const navigateArgs = JSON.parse(
        '{"hotelId":101,"latitude":22.5,"longitude":114}'
      ) as Object;
      const resolveOffers = async (
        _data: DataResult,
        _context: ActionOfferContext
      ): Promise<ActionOffer[]> => {
        return [{
          offerId: 'navigate-101',
          actionId: 'hotel.navigate',
          label: '导航到酒店',
          variant: 'secondary',
          args: navigateArgs
        }, {
          offerId: 'booking-101',
          actionId: 'hotel.booking.open',
          label: '越权预订',
          variant: 'primary',
          args: JSON.parse('{"hotelId":101,"bookingUrl":"https://evil.example"}') as Object
        }];
      };
      const agent = new ActionAgent(
        bus,
        catalog(new ActionLookup()),
        resolveOffers,
        new RecordingRegisteredExecutor()
      );
      const observer = bus.openReader();
      agent.start();
      const dataTask: CreateDataTaskPayload = {
        taskId: 'data-offers',
        roundId: 'turn-offers',
        skillId: '',
        goal: 'hotel.search',
        allowedToolIds: ['hotel.search'],
        toolId: 'hotel.search',
        outputSchema: 'hotelSearchResults',
        args: JSON.parse('{"place":"深圳"}') as Object,
        required: true
      };
      bus.publish(message(
        AgentMessageType.TASK_CREATE_DATA,
        dataTask,
        'turn-offers',
        'data-offers'
      ));
      const data: DataResult = {
        toolId: 'hotel.search',
        outputSchema: 'hotelSearchResults',
        status: 'success',
        sources: [],
        data: JSON.parse('{"hotels":[]}') as Object,
        warnings: []
      };
      bus.publish(message(
        AgentMessageType.TASK_RESULT_DATA,
        data,
        'turn-offers',
        'data-offers'
      ));
      const readyMessage = await receiveType(observer, AgentMessageType.ACTION_OFFERS_READY);
      const ready = readyMessage.payload as ActionOffersReadyPayload;
      const original = navigateArgs as JsonRecord;
      original['hotelId'] = 999;

      expect(ready.sourceToolId).assertEqual('hotel.search');
      expect(ready.offers.length).assertEqual(1);
      expect(ready.offers[0].actionId).assertEqual('hotel.navigate');
      expect((ready.offers[0].args as JsonRecord)['hotelId'] as number).assertEqual(101);
      agent.stop();
      observer.close();
    });

    it('publishes ready only after preflight and returns a correlated invalid-plan error', 0, async () => {
      const bus = new LinkedMessageBus();
      const lookup = new ActionLookup();
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(bus, catalog(lookup), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      publishPlan(bus, planCreate('run-ready', compositePlan()));
      const readyMessage = await receiveType(observer, AgentMessageType.ACTION_PLAN_READY);
      const ready = readyMessage.payload as ActionPlanReadyPayload;

      expect(lookup.calls > 0).assertTrue();
      expect(ready.planId).assertEqual('plan-1');
      expect(ready.runId).assertEqual('run-ready');
      expect(ready.surfaceId).assertEqual('surface-1');
      expect(ready.actionId).assertEqual('workflow.run');
      expect(Object.keys(ready.args).sort().join(',')).assertEqual('planId,runId');

      const surfaceDraft = planCreate('run-surface-draft', compositePlan('plan-surface-draft'));
      const draftRecord = surfaceDraft.draft as Object as JsonRecord;
      draftRecord['surfaceId'] = 'surface-must-not-come-from-leader';
      bus.publish(message(
        AgentMessageType.ACTION_PLAN_DRAFT,
        surfaceDraft,
        'turn-1',
        'surface-draft'
      ));
      const rejectedDraft = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(rejectedDraft.errorCode).assertEqual('ACTION_PLAN_MALFORMED');

      const invalid = compositePlan('plan-invalid');
      (invalid.steps[0].args as JsonRecord)['eval'] = 'payload is data, never code';
      publishPlan(bus, planCreate('run-invalid', invalid), 'turn-1', 'create-invalid');
      const errorMessage = await receiveType(observer, AgentMessageType.ACTION_RESULT);
      const error = errorMessage.payload as ActionResultPayload;

      expect(errorMessage.turnId).assertEqual('turn-1');
      expect(errorMessage.taskId).assertEqual('create-invalid');
      expect(error.runId).assertEqual('run-invalid');
      expect(error.planId).assertEqual('plan-invalid');
      expect(error.status).assertEqual('error');
      expect(executor.actionIds.length).assertEqual(0);

      agent.stop();
      observer.close();
    });

    it('selects the stored workflow by exact identity and rejects replacement steps', 0, async () => {
      const bus = new LinkedMessageBus();
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(bus, catalog(new ActionLookup()), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      publishPlan(bus, planCreate('run-tamper', compositePlan()));
      const ready = (await receiveType(
        observer,
        AgentMessageType.ACTION_PLAN_READY
      )).payload as ActionPlanReadyPayload;
      const tampered = workflowRun(ready) as Object as JsonRecord;
      tampered['steps'] = JSON.parse(
        '[{"stepId":"bad","actionId":"hotel.booking.open","args":{"hotelId":101,"bookingUrl":"https://evil.example/attacker"}}]'
      ) as Object;
      bus.publish(message(AgentMessageType.ACTION_RUN, tampered as Object));
      const rejected = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;

      expect(rejected.status).assertEqual('error');
      expect(executor.actionIds.length).assertEqual(0);

      publishPlan(bus, planCreate('run-exact', compositePlan('plan-exact')));
      const exactReady = (await receiveType(
        observer,
        AgentMessageType.ACTION_PLAN_READY
      )).payload as ActionPlanReadyPayload;
      bus.publish(message(AgentMessageType.ACTION_RUN, workflowRun(exactReady)));
      const terminal = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;

      expect(terminal.status).assertEqual('success');
      expect(executor.actionIds.join(',')).assertEqual('hotel.detail,hotel.navigate');
      expect(executor.serializedArgs.join('|')).assertEqual(
        '{"hotelId":101}|{"hotelId":101,"latitude":22.5,"longitude":114}'
      );

      agent.stop();
      observer.close();
    });

    it('resumes only the exact paused identity with one-shot confirmation', 0, async () => {
      const bus = new LinkedMessageBus();
      const lookup = new ActionLookup();
      lookup.confirmCall = true;
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(bus, catalog(lookup), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun(
          'run-confirm',
          'hotel.booking.open',
          JSON.parse('{"hotelId":101,"bookingUrl":"https://rollinggo.cn/pages/hotel/detail/index?id=101&checkInDate=2026-08-15&checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0"}') as Object,
          'surface-1',
          'hotel.detail'
        )
      ));
      const pausedMessage = await receiveType(observer, AgentMessageType.ACTION_RESULT);
      const pausedResult = pausedMessage.payload as ActionResultPayload;
      const paused: PausedActionRun | null = agent.inspectPausedRun(
        'conversation-1',
        'turn-1',
        'surface-1',
        'run-confirm'
      );

      expect(pausedResult.status).assertEqual('paused');
      expect(pausedResult.stepId).assertEqual('step-1');
      expect(executor.actionIds.length).assertEqual(0);
      expect(paused === null).assertFalse();
      expect(Object.keys(paused as PausedActionRun).sort().join(',')).assertEqual(
        'context,followUpPublished,nextStepIndex,outputs,plan,planId,runId,stepId'
      );

      const resumeReady = readyIdentity(pausedResult.planId, 'run-confirm');
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        workflowRun(resumeReady, 'step-1'),
        'turn-wrong',
        'resume-wrong'
      ));
      const wrong = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(wrong.status).assertEqual('error');
      expect(executor.actionIds.length).assertEqual(0);

      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        workflowRun(
          readyIdentity(pausedResult.planId, 'run-confirm', 'surface-wrong'),
          'step-1'
        ),
        'turn-1',
        'resume-wrong-surface'
      ));
      await receiveType(observer, AgentMessageType.ACTION_RESULT);
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        workflowRun(readyIdentity(pausedResult.planId, 'run-wrong'), 'step-1'),
        'turn-1',
        'resume-wrong-run'
      ));
      await receiveType(observer, AgentMessageType.ACTION_RESULT);
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        workflowRun(resumeReady, 'step-wrong'),
        'turn-1',
        'resume-wrong-step'
      ));
      await receiveType(observer, AgentMessageType.ACTION_RESULT);
      expect(executor.actionIds.length).assertEqual(0);

      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        workflowRun(resumeReady, 'step-1'),
        'turn-1',
        'resume-exact'
      ));
      const completed = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(completed.status).assertEqual('success');
      expect(executor.actionIds.join(',')).assertEqual('hotel.booking.open');

      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        workflowRun(resumeReady, 'step-1'),
        'turn-1',
        'resume-replay'
      ));
      const replay = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(replay.status).assertEqual('error');
      expect(executor.actionIds.length).assertEqual(1);

      agent.stop();
      observer.close();
    });

    it('reauthorizes the exact surface and full args immediately before confirmed execution', 0, async () => {
      const bus = new LinkedMessageBus();
      const lookup = new ActionLookup();
      lookup.confirmCall = true;
      const surface = new ExactActionSurface();
      const validator = new ExactArgs();
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(bus, catalog(lookup, surface, validator), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun(
          'run-reauthorize',
          'hotel.booking.open',
          JSON.parse('{"hotelId":101,"bookingUrl":"https://rollinggo.cn/pages/hotel/detail/index?id=101&checkInDate=2026-08-15&checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0"}') as Object,
          'surface-1',
          'hotel.detail'
        )
      ));
      const paused = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      surface.allowed = false;
      validator.reject = true;
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        workflowRun(
          readyIdentity(paused.planId, 'run-reauthorize'),
          paused.stepId
        )
      ));
      const rejected = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;

      expect(rejected.status).assertEqual('error');
      expect(
        rejected.errorCode === 'ACTION_SURFACE_DENIED' ||
          rejected.errorCode === 'ACTION_ARGS_REJECTED'
      ).assertTrue();
      expect(executor.actionIds.length).assertEqual(0);

      agent.stop();
      observer.close();
    });

    it('cancels paused and in-flight runs without late progress or results', 0, async () => {
      const bus = new LinkedMessageBus();
      const lookup = new ActionLookup();
      lookup.confirmCall = true;
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(bus, catalog(lookup), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun(
          'run-paused-cancel',
          'hotel.booking.open',
          JSON.parse('{"hotelId":101,"bookingUrl":"https://rollinggo.cn/pages/hotel/detail/index?id=101&checkInDate=2026-08-15&checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0"}') as Object,
          'surface-1',
          'hotel.detail'
        )
      ));
      await receiveType(observer, AgentMessageType.ACTION_RESULT);
      publishPlan(bus, planCreate('run-ready-cancel', compositePlan('plan-ready-cancel')));
      const readyCanceled = (await receiveType(
        observer,
        AgentMessageType.ACTION_PLAN_READY
      )).payload as ActionPlanReadyPayload;
      lookup.confirmCall = false;
      executor.gate = new TestGate();
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun(
          'run-late',
          'hotel.navigate',
          JSON.parse(
            '{"hotelId":101,"latitude":22.5,"longitude":114}'
          ) as Object
        ),
        'turn-1',
        'run-late-task'
      ));
      await receiveType(observer, AgentMessageType.ACTION_PROGRESS);
      bus.publish(message(
        AgentMessageType.TURN_CANCEL,
        new Object(),
        'turn-1',
        'cancel-all'
      ));
      const pausedCanceled = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      const activeCanceled = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      const thirdCanceled = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;

      expect(pausedCanceled.status).assertEqual('canceled');
      expect(activeCanceled.status).assertEqual('canceled');
      expect(thirdCanceled.status).assertEqual('canceled');
      expect(agent.inspectPausedRun(
        'conversation-1',
        'turn-1',
        'surface-1',
        'run-paused-cancel'
      ) === null).assertTrue();
      executor.gate.open();
      await settle();
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        workflowRun(readyCanceled),
        'turn-1',
        'ready-after-cancel'
      ));
      bus.publish(message(
        AgentMessageType.INPUT_USER,
        JSON.parse('{"text":"marker"}') as Object,
        'marker-turn',
        'marker'
      ));
      let lateActionMessages = 0;
      let next = await receive(observer);
      while (next.type !== AgentMessageType.INPUT_USER) {
        if (next.type === AgentMessageType.ACTION_PROGRESS ||
          next.type === AgentMessageType.ACTION_RESULT) {
          lateActionMessages++;
        }
        next = await receive(observer);
      }

      expect(lateActionMessages).assertEqual(0);
      expect(executor.actionIds.join(',')).assertEqual('hotel.navigate');

      agent.stop();
      observer.close();
    });

    it('publishes ordered typed progress and one sanitized paired follow-up', 0, async () => {
      const bus = new LinkedMessageBus();
      const executor = new RecordingRegisteredExecutor();
      const uiTask: CreateUiTaskPayload = {
        taskId: 'ui-follow',
        dataTaskIds: ['data-follow'],
        skillId: '',
        intent: 'Show the exact hotel detail',
        expectedOutputSchema: 'hotelDetail'
      };
      const dataTask: CreateDataTaskPayload = {
        taskId: 'data-follow',
        roundId: 'turn-follow',
        skillId: '',
        goal: 'hotel.detail',
        allowedToolIds: ['hotel.detail'],
        toolId: 'hotel.detail',
        outputSchema: 'hotelDetail',
        args: JSON.parse('{"hotelId":101}') as Object,
        required: true
      };
      const followUp: ActionFollowUp = {
        uiTask,
        dataTask
      };
      executor.results = [
        success('{"hotelId":101,"latitude":22.5}', followUp),
        success('{"opened":true}')
      ];
      const agent = new ActionAgent(bus, catalog(new ActionLookup()), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      publishPlan(bus, planCreate('run-follow', compositePlan()));
      const ready = (await receiveType(
        observer,
        AgentMessageType.ACTION_PLAN_READY
      )).payload as ActionPlanReadyPayload;
      bus.publish(message(AgentMessageType.ACTION_RUN, workflowRun(ready)));

      const observed: AgentMessage[] = [];
      while (true) {
        const next = await receive(observer);
        if (next.type === AgentMessageType.ACTION_PROGRESS ||
          next.type === AgentMessageType.TASK_CREATE_UI ||
          next.type === AgentMessageType.TASK_CREATE_DATA ||
          next.type === AgentMessageType.ACTION_RESULT) {
          observed.push(next);
        }
        if (next.type === AgentMessageType.ACTION_RESULT) {
          break;
        }
      }
      const progress: string[] = [];
      let terminalCount = 0;
      for (let index = 0; index < observed.length; index++) {
        if (observed[index].type === AgentMessageType.ACTION_PROGRESS) {
          const payload = observed[index].payload as ActionProgressPayload;
          progress.push(`${payload.stepId}:${payload.status}`);
        }
        if (observed[index].type === AgentMessageType.ACTION_RESULT) {
          terminalCount++;
        }
      }
      const uiIndex = observed.findIndex(
        (current: AgentMessage): boolean => current.type === AgentMessageType.TASK_CREATE_UI
      );
      const dataIndex = observed.findIndex(
        (current: AgentMessage): boolean => current.type === AgentMessageType.TASK_CREATE_DATA
      );

      expect(progress.join(',')).assertEqual(
        'detail:running,detail:success,navigate:running,navigate:success'
      );
      expect(terminalCount).assertEqual(1);
      expect(uiIndex >= 0).assertTrue();
      expect(dataIndex).assertEqual(uiIndex + 1);
      expect(observed[uiIndex].turnId === 'turn-1').assertFalse();
      expect(observed[dataIndex].turnId).assertEqual(observed[uiIndex].turnId);
      expect(observed[uiIndex].turnId.indexOf('conversation-1') >= 0).assertTrue();
      expect(observed[uiIndex].taskId).assertEqual('ui-follow');
      expect(observed[dataIndex].taskId).assertEqual('data-follow');
      expect(executor.actionIds.join(',')).assertEqual('hotel.detail,hotel.navigate');
      expect(executor.contexts[1].indexOf('|run-follow|navigate') > 0).assertTrue();

      agent.stop();
      observer.close();
    });

    it('keeps one follow-up across pause and resume and allocates a fresh correlated turn', 0, async () => {
      const bus = new LinkedMessageBus();
      const lookup = new ActionLookup();
      lookup.confirmCall = true;
      const executor = new RecordingRegisteredExecutor();
      const firstArgs = JSON.parse('{"hotelId":101,"marker":"original"}') as Object;
      const firstFollowUp = JSON.parse(
        '{"uiTask":{"taskId":"ui-first","dataTaskIds":["data-first"],' +
          '"skillId":"","intent":"Show detail","expectedOutputSchema":"hotelDetail"},' +
          '"dataTask":{"taskId":"data-first","roundId":"round-first","skillId":"","goal":"hotel.detail",' +
          '"allowedToolIds":["hotel.detail"],"toolId":"hotel.detail","outputSchema":"hotelDetail",' +
          '"args":{"hotelId":101,"marker":"original"},"required":true}}'
      ) as ActionFollowUp;
      firstFollowUp.dataTask.args = firstArgs;
      const secondFollowUp = JSON.parse(
        '{"uiTask":{"taskId":"ui-second","dataTaskIds":["data-second"],' +
          '"skillId":"","intent":"Must not publish","expectedOutputSchema":"hotelDetail"},' +
          '"dataTask":{"taskId":"data-second","roundId":"round-second","skillId":"","goal":"hotel.detail",' +
          '"allowedToolIds":["hotel.detail"],"toolId":"hotel.detail","outputSchema":"hotelDetail",' +
          '"args":{"hotelId":202},"required":true}}'
      ) as ActionFollowUp;
      executor.results = [
        success('{"hotelId":101}', firstFollowUp),
        success('{"called":true}', secondFollowUp)
      ];
      const agent = new ActionAgent(bus, catalog(lookup), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      publishPlan(
        bus,
        planCreate('run-follow-confirm', followUpThenConfirmPlan('plan-follow-confirm'))
      );
      const ready = (await receiveType(
        observer,
        AgentMessageType.ACTION_PLAN_READY
      )).payload as ActionPlanReadyPayload;
      bus.publish(message(AgentMessageType.ACTION_RUN, workflowRun(ready)));
      const beforeResume = await receiveUntilResult(observer);
      const paused = beforeResume[beforeResume.length - 1].payload as ActionResultPayload;
      const saved = agent.inspectPausedRun(
        'conversation-1',
        'turn-1',
        'surface-1',
        'run-follow-confirm'
      ) as PausedActionRun;
      (firstArgs as JsonRecord)['marker'] = 'mutated';

      expect(paused.status).assertEqual('paused');
      expect(saved.followUpPublished).assertTrue();
      expect(messagesOfType(beforeResume, AgentMessageType.TASK_CREATE_UI).length).assertEqual(1);
      expect(messagesOfType(beforeResume, AgentMessageType.TASK_CREATE_DATA).length).assertEqual(1);
      const firstUi = messagesOfType(beforeResume, AgentMessageType.TASK_CREATE_UI)[0];
      const firstData = messagesOfType(beforeResume, AgentMessageType.TASK_CREATE_DATA)[0];
      expect(firstUi.turnId === 'turn-1').assertFalse();
      expect(firstData.turnId).assertEqual(firstUi.turnId);
      expect(firstUi.turnId.indexOf('conversation-1') >= 0).assertTrue();
      expect(((firstData.payload as CreateDataTaskPayload).args as JsonRecord)['marker'] as string)
        .assertEqual('original');

      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        workflowRun(readyIdentity(paused.planId, paused.runId), paused.stepId),
        'turn-1',
        'resume-follow-confirm'
      ));
      const afterResume = await receiveUntilResult(observer);
      const completed = afterResume[afterResume.length - 1].payload as ActionResultPayload;

      expect(completed.status).assertEqual('success');
      expect(messagesOfType(afterResume, AgentMessageType.TASK_CREATE_UI).length).assertEqual(0);
      expect(messagesOfType(afterResume, AgentMessageType.TASK_CREATE_DATA).length).assertEqual(0);
      expect(executor.actionIds.join(',')).assertEqual('hotel.detail,hotel.booking.open');

      agent.stop();
      observer.close();
    });

    it('rejects executor-selected turns and unknown follow-up descriptor fields', 0, async () => {
      const bus = new LinkedMessageBus();
      const executor = new RecordingRegisteredExecutor();
      const topLevelExtra = JSON.parse(
        '{"turnId":"turn-1","extra":"route-me",' +
          '"uiTask":{"taskId":"ui-bad-1","dataTaskId":"data-bad-1",' +
          '"intent":"bad","expectedOutputSchema":"hotelDetail"},' +
          '"dataTask":{"taskId":"data-bad-1","toolId":"hotel.detail",' +
          '"outputSchema":"hotelDetail","args":{"hotelId":101}}}'
      ) as ActionFollowUp;
      const descriptorExtra = JSON.parse(
        '{"uiTask":{"taskId":"ui-bad-2","dataTaskId":"data-bad-2",' +
          '"intent":"bad","expectedOutputSchema":"hotelDetail","component":"script"},' +
          '"dataTask":{"taskId":"data-bad-2","toolId":"hotel.detail",' +
          '"outputSchema":"hotelDetail","args":{"hotelId":101},"extra":true}}'
      ) as ActionFollowUp;
      executor.results = [
        success('{"hotelId":101}', topLevelExtra),
        success('{"hotelId":101}', descriptorExtra)
      ];
      const agent = new ActionAgent(bus, catalog(new ActionLookup()), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun('run-bad-follow-1', 'hotel.detail', JSON.parse('{"hotelId":101}') as Object)
      ));
      const first = await receiveUntilResult(observer);
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun('run-bad-follow-2', 'hotel.detail', JSON.parse('{"hotelId":101}') as Object)
      ));
      const second = await receiveUntilResult(observer);

      expect((first[first.length - 1].payload as ActionResultPayload).status).assertEqual('error');
      expect((second[second.length - 1].payload as ActionResultPayload).status).assertEqual('error');
      expect(messagesOfType(first, AgentMessageType.TASK_CREATE_UI).length).assertEqual(0);
      expect(messagesOfType(first, AgentMessageType.TASK_CREATE_DATA).length).assertEqual(0);
      expect(messagesOfType(second, AgentMessageType.TASK_CREATE_UI).length).assertEqual(0);
      expect(messagesOfType(second, AgentMessageType.TASK_CREATE_DATA).length).assertEqual(0);

      agent.stop();
      observer.close();
    });

    it('isolates identical run ids by exact conversation turn and surface key', 0, async () => {
      const bus = new LinkedMessageBus();
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(bus, catalog(new ActionLookup()), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      publishPlan(bus, planCreate('shared-run', compositePlan('plan-a')));
      publishPlan(
        bus,
        planCreate(
          'shared-run',
          compositePlan('plan-b', 'turn-2', 'surface-2')
        ),
        'turn-2',
        'create-b',
        'conversation-2',
        'surface-2'
      );
      await settle();
      bus.publish(message(
        AgentMessageType.INPUT_USER,
        JSON.parse('{"text":"marker"}') as Object,
        'marker-turn',
        'marker'
      ));
      const readyMessages: AgentMessage[] = [];
      let observed = await receive(observer);
      while (observed.type !== AgentMessageType.INPUT_USER) {
        if (observed.type === AgentMessageType.ACTION_PLAN_READY) {
          readyMessages.push(observed);
        }
        observed = await receive(observer);
      }
      expect(readyMessages.length).assertEqual(2);
      const readyA = readyMessages.find(
        (current: AgentMessage): boolean => current.conversationId === 'conversation-1'
      )?.payload as ActionPlanReadyPayload;
      const readyB = readyMessages.find(
        (current: AgentMessage): boolean => current.conversationId === 'conversation-2'
      )?.payload as ActionPlanReadyPayload;

      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        workflowRun(readyA),
        'turn-2',
        'cross-collision',
        'conversation-2'
      ));
      const cross = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(cross.status).assertEqual('error');

      bus.publish(message(AgentMessageType.ACTION_RUN, workflowRun(readyA)));
      await receiveType(observer, AgentMessageType.ACTION_RESULT);
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        workflowRun(readyB),
        'turn-2',
        'run-b',
        'conversation-2'
      ));
      await receiveType(observer, AgentMessageType.ACTION_RESULT);

      expect(executor.actionIds.join(',')).assertEqual(
        'hotel.detail,hotel.navigate,hotel.detail,hotel.navigate'
      );

      agent.stop();
      observer.close();
    });

    it('rejects the 129th pending compiler request without losing earlier work', 0, async () => {
      const bus = new LinkedMessageBus();
      const compiler = new ScriptedActionPlanCompiler(singleOfferPlan());
      const agent = new ActionAgent(
        bus,
        catalog(new ActionLookup()),
        composedOffers,
        new RecordingRegisteredExecutor(),
        compiler
      );
      const observer = bus.openReader();
      agent.start();

      for (let index = 0; index < 129; index++) {
        bus.publish(message(
          AgentMessageType.ACTION_PLAN_REQUEST,
          singlePlanRequest(index),
          'turn-1',
          `capacity-request-${index}`
        ));
      }
      const overflow = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(overflow.errorCode).assertEqual('ACTION_STATE_CAPACITY');

      bus.publish(message(
        AgentMessageType.TASK_CREATE_DATA,
        observedTask('capacity-data-0', 'social.source'),
        'turn-1',
        'capacity-data-0'
      ));
      bus.publish(message(
        AgentMessageType.TASK_RESULT_DATA,
        observedResult('social.source'),
        'turn-1',
        'capacity-data-0'
      ));
      await receiveType(observer, AgentMessageType.ACTION_PLAN_DRAFT);
      const ui: UiRenderResultPayload = { surfaceId: 'surface-1', state: 'result' };
      bus.publish(message(
        AgentMessageType.TASK_RESULT_UI,
        ui,
        'turn-1',
        'capacity-ui-0'
      ));
      const ready = (await receiveType(
        observer,
        AgentMessageType.ACTION_PLAN_READY
      )).payload as ActionPlanReadyPayload;

      expect(compiler.goals.join(',')).assertEqual('capacity-goal-0');
      expect(ready.uiTaskId).assertEqual('capacity-ui-0');
      agent.stop();
      observer.close();
    });

    it('rejects excess early offer state instead of evicting a live correlation', 0, async () => {
      const bus = new LinkedMessageBus();
      const compiler = new ScriptedActionPlanCompiler(singleOfferPlan());
      const agent = new ActionAgent(
        bus,
        catalog(new ActionLookup()),
        composedOffers,
        new RecordingRegisteredExecutor(),
        compiler
      );
      const observer = bus.openReader();
      agent.start();

      for (let index = 0; index < 129; index++) {
        const taskId = `early-offer-${index}`;
        bus.publish(message(
          AgentMessageType.TASK_CREATE_DATA,
          observedTask(taskId, 'social.source'),
          'turn-1',
          taskId
        ));
        bus.publish(message(
          AgentMessageType.TASK_RESULT_DATA,
          observedResult('social.source'),
          'turn-1',
          taskId
        ));
      }
      let readyOffers = 0;
      let capacityErrors = 0;
      while (readyOffers < 129) {
        const next = await receive(observer);
        if (next.type === AgentMessageType.ACTION_OFFERS_READY) {
          readyOffers++;
        }
        if (next.type === AgentMessageType.ACTION_RESULT &&
          (next.payload as ActionResultPayload).errorCode === 'ACTION_STATE_CAPACITY') {
          capacityErrors++;
        }
      }

      let firstCorrelationCompleted = false;
      if (capacityErrors === 1) {
        const firstRequest: ActionPlanRequestPayload = {
          uiTaskId: 'early-offer-ui',
          dataTaskIds: ['early-offer-0'],
          goal: 'use preserved first offer',
          allowedActionIds: ['social.reply.draft'],
          skillId: ''
        };
        bus.publish(message(
          AgentMessageType.ACTION_PLAN_REQUEST,
          firstRequest,
          'turn-1',
          'early-offer-request'
        ));
        await receiveType(observer, AgentMessageType.ACTION_PLAN_DRAFT);
        const ui: UiRenderResultPayload = { surfaceId: 'surface-1', state: 'result' };
        bus.publish(message(
          AgentMessageType.TASK_RESULT_UI,
          ui,
          'turn-1',
          'early-offer-ui'
        ));
        await receiveType(observer, AgentMessageType.ACTION_PLAN_READY);
        firstCorrelationCompleted = true;
      }

      expect(capacityErrors).assertEqual(1);
      expect(firstCorrelationCompleted).assertTrue();
      agent.stop();
      observer.close();
    });

    it('rejects excess early UI state and preserves the first surface binding', 0, async () => {
      const bus = new LinkedMessageBus();
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(bus, catalog(new ActionLookup()), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      const ui: UiRenderResultPayload = { surfaceId: 'surface-1', state: 'result' };
      for (let index = 0; index < 129; index++) {
        bus.publish(message(
          AgentMessageType.TASK_RESULT_UI,
          ui,
          'turn-1',
          `early-ui-${index}`
        ));
      }
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun(
          'early-ui-barrier',
          'hotel.detail',
          JSON.parse('{"hotelId":101}') as Object
        ),
        'turn-1',
        'early-ui-barrier'
      ));
      let capacityErrors = 0;
      let barrierComplete = false;
      while (!barrierComplete) {
        const next = await receive(observer);
        if (next.type === AgentMessageType.ACTION_RESULT) {
          const result = next.payload as ActionResultPayload;
          if (result.errorCode === 'ACTION_STATE_CAPACITY') {
            capacityErrors++;
          }
          barrierComplete = result.runId === 'early-ui-barrier';
        }
      }

      let firstSurfaceBound = false;
      if (capacityErrors === 1) {
        const draftPayload: ActionPlanDraftPayload = {
          uiTaskId: 'early-ui-0',
          dataTaskId: 'early-ui-data',
          sourceToolId: 'social.source',
          draft: singleOfferPlan('early-ui-plan', 'early-ui-run')
        };
        bus.publish(message(
          AgentMessageType.ACTION_PLAN_DRAFT,
          draftPayload,
          'turn-1',
          'early-ui-draft'
        ));
        const ready = (await receiveType(
          observer,
          AgentMessageType.ACTION_PLAN_READY
        )).payload as ActionPlanReadyPayload;
        firstSurfaceBound = ready.surfaceId === 'surface-1';
      }

      expect(capacityErrors).assertEqual(1);
      expect(firstSurfaceBound).assertTrue();
      agent.stop();
      observer.close();
    });

    it('bounds compiler-request tombstones while protecting current duplicates', 0, async () => {
      const bus = new LinkedMessageBus();
      const agent = new ActionAgent(
        bus,
        catalog(new ActionLookup()),
        noOffers,
        new RecordingRegisteredExecutor()
      );
      const observer = bus.openReader();
      agent.start();

      for (let index = 0; index < 129; index++) {
        bus.publish(message(
          AgentMessageType.ACTION_PLAN_REQUEST,
          singlePlanRequest(index),
          'turn-1',
          `terminal-request-${index}`
        ));
        await receiveType(observer, AgentMessageType.ACTION_RESULT);
      }
      bus.publish(message(
        AgentMessageType.ACTION_PLAN_REQUEST,
        singlePlanRequest(0),
        'turn-1',
        'terminal-request-oldest-replay'
      ));
      const oldest = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      bus.publish(message(
        AgentMessageType.ACTION_PLAN_REQUEST,
        singlePlanRequest(128),
        'turn-1',
        'terminal-request-current-replay'
      ));
      const current = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;

      expect(oldest.errorCode).assertEqual('ACTION_PLAN_COMPILER_UNAVAILABLE');
      expect(current.errorCode).assertEqual('ACTION_PLAN_REQUEST_DUPLICATE');
      agent.stop();
      observer.close();
    });

    it('bounds live payload state and retains old terminal identities', 0, async () => {
      const bus = new LinkedMessageBus();
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(bus, catalog(new ActionLookup()), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      for (let index = 0; index < 128; index++) {
        publishPlan(
          bus,
          planCreate(`capacity-run-${index}`, compositePlan(`capacity-plan-${index}`)),
          'turn-1',
          `capacity-task-${index}`
        );
        await receiveType(observer, AgentMessageType.ACTION_PLAN_READY);
      }
      publishPlan(
        bus,
        planCreate('capacity-overflow', compositePlan('capacity-overflow-plan')),
        'turn-1',
        'capacity-overflow-task'
      );
      await settle();
      bus.publish(message(
        AgentMessageType.INPUT_USER,
        JSON.parse('{"text":"capacity-marker"}') as Object,
        'marker-turn',
        'capacity-marker'
      ));
      let overflow: ActionResultPayload | null = null;
      let next = await receive(observer);
      while (next.type !== AgentMessageType.INPUT_USER) {
        if (next.type === AgentMessageType.ACTION_RESULT) {
          overflow = next.payload as ActionResultPayload;
        }
        next = await receive(observer);
      }
      expect((overflow as ActionResultPayload).errorCode).assertEqual('ACTION_STATE_CAPACITY');

      bus.publish(message(
        AgentMessageType.TURN_CANCEL,
        new Object(),
        'turn-1',
        'capacity-cancel'
      ));
      for (let index = 0; index < 128; index++) {
        const canceled = (await receiveType(
          observer,
          AgentMessageType.ACTION_RESULT
        )).payload as ActionResultPayload;
        expect(canceled.status).assertEqual('canceled');
      }
      agent.stop();
      agent.start();
      publishPlan(
        bus,
        planCreate('after-capacity', compositePlan('after-capacity-plan')),
        'turn-1',
        'after-capacity-task'
      );
      await settle();
      bus.publish(message(
        AgentMessageType.INPUT_USER,
        JSON.parse('{"text":"restart-marker"}') as Object,
        'marker-turn',
        'restart-marker'
      ));
      let readyAfterRestart = 0;
      next = await receive(observer);
      while (next.type !== AgentMessageType.INPUT_USER) {
        if (next.type === AgentMessageType.ACTION_PLAN_READY) {
          readyAfterRestart++;
        }
        next = await receive(observer);
      }
      expect(readyAfterRestart).assertEqual(1);
      agent.stop();
      observer.close();

      const tombstoneBus = new LinkedMessageBus();
      const tombstoneExecutor = new RecordingRegisteredExecutor();
      const tombstoneAgent = new ActionAgent(
        tombstoneBus,
        catalog(new ActionLookup()),
        noOffers,
        tombstoneExecutor
      );
      const tombstoneObserver = tombstoneBus.openReader();
      tombstoneAgent.start();
      for (let index = 0; index < 129; index++) {
        tombstoneBus.publish(message(
          AgentMessageType.ACTION_RUN,
          directRun(
            `terminal-${index}`,
            'hotel.detail',
            JSON.parse('{"hotelId":101}') as Object
          ),
          'turn-1',
          `terminal-task-${index}`
        ));
        await receiveType(tombstoneObserver, AgentMessageType.ACTION_RESULT);
      }
      tombstoneBus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun(
          'terminal-0',
          'hotel.detail',
          JSON.parse('{"hotelId":101}') as Object
        ),
        'turn-1',
        'terminal-replay'
      ));
      const replay = (await receiveType(
        tombstoneObserver,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(replay.status).assertEqual('error');
      expect(replay.errorCode).assertEqual('ACTION_RUN_DUPLICATE');
      expect(replay.runId).assertEqual('terminal-0');
      expect(tombstoneExecutor.actionIds.length).assertEqual(129);
      tombstoneAgent.stop();
      tombstoneObserver.close();
    });

    it('retains canceled turn identities for the Action Agent session', 1000, async () => {
      const bus = new LinkedMessageBus();
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(bus, catalog(new ActionLookup()), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      for (let index = 0; index < 129; index++) {
        bus.publish(message(
          AgentMessageType.TURN_CANCEL,
          new Object(),
          index === 0 ? 'turn-1' : `canceled-turn-${index}`,
          `cancel-${index}`
        ));
      }
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun(
          'canceled-replay',
          'hotel.detail',
          JSON.parse('{"hotelId":101}') as Object
        ),
        'turn-1',
        'canceled-replay-task'
      ));
      setTimeout(() => {
        bus.publish(message(
          AgentMessageType.INPUT_USER,
          JSON.parse('{"text":"canceled-marker"}') as Object,
          'marker-turn',
          'canceled-marker'
        ));
      }, 30);

      let actionMessages = 0;
      let observed = await receive(observer);
      while (observed.type !== AgentMessageType.INPUT_USER) {
        if (observed.type === AgentMessageType.ACTION_PROGRESS ||
          observed.type === AgentMessageType.ACTION_RESULT) {
          actionMessages++;
        }
        observed = await receive(observer);
      }
      expect(actionMessages).assertEqual(0);
      expect(executor.actionIds.length).assertEqual(0);

      agent.stop();
      observer.close();
    });

    it('retains an old workflow identity after many terminals', 0, async () => {
      const bus = new LinkedMessageBus();
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(bus, catalog(new ActionLookup()), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      const originalCreate = planCreate(
        'original-workflow-run',
        compositePlan('original-workflow-plan')
      );
      publishPlan(bus, originalCreate);
      const originalReady = (await receiveType(
        observer,
        AgentMessageType.ACTION_PLAN_READY
      )).payload as ActionPlanReadyPayload;
      bus.publish(message(AgentMessageType.ACTION_RUN, workflowRun(originalReady)));
      await receiveType(observer, AgentMessageType.ACTION_RESULT);
      for (let index = 0; index < 129; index++) {
        bus.publish(message(
          AgentMessageType.ACTION_RUN,
          directRun(
            `later-terminal-${index}`,
            'hotel.detail',
            JSON.parse('{"hotelId":101}') as Object
          ),
          'turn-1',
          `later-terminal-task-${index}`
        ));
        await receiveType(observer, AgentMessageType.ACTION_RESULT);
      }
      const executorCount = executor.actionIds.length;

      publishPlan(
        bus,
        originalCreate,
        'turn-1',
        'original-plan-replay'
      );
      await settle();
      bus.publish(message(
        AgentMessageType.INPUT_USER,
        JSON.parse('{"text":"plan-replay-marker"}') as Object,
        'marker-turn',
        'plan-replay-marker'
      ));
      let replayReadyCount = 0;
      let replayCreateError: ActionResultPayload | null = null;
      let observed = await receive(observer);
      while (observed.type !== AgentMessageType.INPUT_USER) {
        if (observed.type === AgentMessageType.ACTION_PLAN_READY) {
          replayReadyCount++;
        }
        if (observed.type === AgentMessageType.ACTION_RESULT) {
          replayCreateError = observed.payload as ActionResultPayload;
        }
        observed = await receive(observer);
      }
      expect(replayReadyCount).assertEqual(0);
      expect(replayCreateError === null).assertFalse();
      expect((replayCreateError as ActionResultPayload).errorCode)
        .assertEqual('ACTION_RUN_DUPLICATE');

      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        workflowRun(originalReady),
        'turn-1',
        'original-workflow-replay'
      ));
      const workflowReplay = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(workflowReplay.status).assertEqual('error');
      expect(workflowReplay.errorCode).assertEqual('ACTION_RUN_DUPLICATE');
      expect(executor.actionIds.length).assertEqual(executorCount);

      agent.stop();
      observer.close();
    });

    it('reports cloned completed outputs when canceling paused and later active steps', 0, async () => {
      const pausedBus = new LinkedMessageBus();
      const pausedLookup = new ActionLookup();
      pausedLookup.confirmCall = true;
      const pausedExecutor = new RecordingRegisteredExecutor();
      pausedExecutor.results = [success('{"hotelId":101,"detail":"kept"}')];
      const pausedAgent = new ActionAgent(
        pausedBus,
        catalog(pausedLookup),
        noOffers,
        pausedExecutor
      );
      const pausedObserver = pausedBus.openReader();
      pausedAgent.start();
      publishPlan(
        pausedBus,
        planCreate('cancel-paused-output', followUpThenConfirmPlan('cancel-paused-plan'))
      );
      const pausedReady = (await receiveType(
        pausedObserver,
        AgentMessageType.ACTION_PLAN_READY
      )).payload as ActionPlanReadyPayload;
      pausedBus.publish(message(AgentMessageType.ACTION_RUN, workflowRun(pausedReady)));
      await receiveType(pausedObserver, AgentMessageType.ACTION_RESULT);
      pausedBus.publish(message(AgentMessageType.TURN_CANCEL, new Object()));
      const pausedCanceled = (await receiveType(
        pausedObserver,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;

      expect(pausedCanceled.completedStepIds.join(',')).assertEqual('detail');
      expect((pausedCanceled.outputs as ActionPlanStepOutput[]).length).assertEqual(1);
      expect(((pausedCanceled.outputs as ActionPlanStepOutput[])[0].output as JsonRecord)['detail'] as string)
        .assertEqual('kept');
      pausedAgent.stop();
      pausedObserver.close();

      const activeBus = new LinkedMessageBus();
      const activeExecutor = new RecordingRegisteredExecutor();
      activeExecutor.results = [
        success('{"hotelId":101,"detail":"active-kept"}'),
        success('{"opened":true}')
      ];
      activeExecutor.gate = new TestGate();
      activeExecutor.gateActionId = 'hotel.navigate';
      const activeAgent = new ActionAgent(
        activeBus,
        catalog(new ActionLookup()),
        noOffers,
        activeExecutor
      );
      const activeObserver = activeBus.openReader();
      activeAgent.start();
      publishPlan(
        activeBus,
        planCreate('cancel-active-output', compositePlan('cancel-active-plan'))
      );
      const activeReady = (await receiveType(
        activeObserver,
        AgentMessageType.ACTION_PLAN_READY
      )).payload as ActionPlanReadyPayload;
      activeBus.publish(message(AgentMessageType.ACTION_RUN, workflowRun(activeReady)));
      let runningNavigate = false;
      while (!runningNavigate) {
        const current = await receive(activeObserver);
        if (current.type === AgentMessageType.ACTION_PROGRESS) {
          const progress = current.payload as ActionProgressPayload;
          runningNavigate = progress.stepId === 'navigate' && progress.status === 'running';
        }
      }
      activeBus.publish(message(AgentMessageType.TURN_CANCEL, new Object()));
      const activeCanceled = (await receiveType(
        activeObserver,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;

      expect(activeCanceled.completedStepIds.join(',')).assertEqual('detail');
      expect((activeCanceled.outputs as ActionPlanStepOutput[]).length).assertEqual(1);
      expect(((activeCanceled.outputs as ActionPlanStepOutput[])[0].output as JsonRecord)['detail'] as string)
        .assertEqual('active-kept');
      activeExecutor.gate.open();
      activeAgent.stop();
      activeObserver.close();
    });

    it('restarts after stop without publishing a pending old completion', 0, async () => {
      const bus = new LinkedMessageBus();
      const executor = new RecordingRegisteredExecutor();
      executor.gate = new TestGate();
      executor.gateActionId = 'hotel.navigate';
      const agent = new ActionAgent(bus, catalog(new ActionLookup()), noOffers, executor);
      const observer = bus.openReader();
      agent.start();
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun(
          'old-pending',
          'hotel.navigate',
          JSON.parse('{"hotelId":101,"latitude":22.5,"longitude":114}') as Object
        )
      ));
      await receiveType(observer, AgentMessageType.ACTION_PROGRESS);

      agent.stop();
      agent.start();
      executor.gate.open();
      executor.gate = null;
      await settle();
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun('new-after-restart', 'hotel.detail', JSON.parse('{"hotelId":101}') as Object),
        'turn-1',
        'new-after-restart-task'
      ));
      await settle();
      bus.publish(message(
        AgentMessageType.INPUT_USER,
        JSON.parse('{"text":"restart-marker"}') as Object,
        'marker-turn',
        'restart-marker'
      ));
      const results: ActionResultPayload[] = [];
      let next = await receive(observer);
      while (next.type !== AgentMessageType.INPUT_USER) {
        if (next.type === AgentMessageType.ACTION_RESULT) {
          results.push(next.payload as ActionResultPayload);
        }
        next = await receive(observer);
      }

      expect(results.length).assertEqual(1);
      expect(results[0].runId).assertEqual('new-after-restart');
      expect(executor.actionIds.join(',')).assertEqual('hotel.navigate,hotel.detail');

      agent.stop();
      observer.close();
    });

    it('survives malformed payloads, rejects duplicates, and ignores its own result messages', 0, async () => {
      const bus = new LinkedMessageBus();
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(bus, catalog(new ActionLookup()), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_PLAN_DRAFT,
        JSON.parse('null') as Object,
        'turn-1',
        'malformed-plan'
      ));
      const malformedPlan = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        JSON.parse('null') as Object,
        'turn-1',
        'malformed-run'
      ));
      const malformedRun = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(typeof malformedPlan.planId).assertEqual('string');
      expect(typeof malformedPlan.runId).assertEqual('string');
      expect(typeof malformedPlan.surfaceId).assertEqual('string');
      expect(typeof malformedRun.planId).assertEqual('string');
      expect(typeof malformedRun.runId).assertEqual('string');
      expect(typeof malformedRun.surfaceId).assertEqual('string');

      bus.publish(message(
        AgentMessageType.ACTION_PLAN_READY,
        JSON.parse('{"runId":"self"}') as Object
      ));
      bus.publish(message(
        AgentMessageType.ACTION_PROGRESS,
        JSON.parse('{"runId":"self"}') as Object
      ));
      bus.publish(message(
        AgentMessageType.ACTION_RESULT,
        JSON.parse('{"runId":"self"}') as Object
      ));
      bus.publish(message(
        AgentMessageType.INPUT_USER,
        JSON.parse('{"text":"self-marker"}') as Object,
        'marker-turn',
        'self-marker'
      ));
      let ownMessage = await receive(observer);
      while (ownMessage.type !== AgentMessageType.INPUT_USER) {
        ownMessage = await receive(observer);
      }
      publishPlan(bus, planCreate('duplicate-run', compositePlan('duplicate-plan')));
      const ready = (await receiveType(
        observer,
        AgentMessageType.ACTION_PLAN_READY
      )).payload as ActionPlanReadyPayload;
      publishPlan(bus, planCreate('duplicate-run', compositePlan('duplicate-plan')));
      const duplicate = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(duplicate.errorCode).assertEqual('ACTION_RUN_DUPLICATE');
      bus.publish(message(AgentMessageType.ACTION_RUN, workflowRun(ready)));
      const completed = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      expect(completed.status).assertEqual('success');

      agent.stop();
      observer.close();
    });

    it('reauthorizes the whole surface entry before resuming a later confirmed step', 0, async () => {
      const bus = new LinkedMessageBus();
      const lookup = new ActionLookup();
      lookup.confirmCall = true;
      const surface = new ExactActionSurface();
      const validator = new ExactArgs();
      const executor = new RecordingRegisteredExecutor();
      executor.results = [success('{"hotelId":101}')];
      const agent = new ActionAgent(bus, catalog(lookup, surface, validator), noOffers, executor);
      const observer = bus.openReader();
      agent.start();

      publishPlan(
        bus,
        planCreate('later-confirm', followUpThenConfirmPlan('later-confirm-plan'))
      );
      const ready = (await receiveType(
        observer,
        AgentMessageType.ACTION_PLAN_READY
      )).payload as ActionPlanReadyPayload;
      bus.publish(message(AgentMessageType.ACTION_RUN, workflowRun(ready)));
      const paused = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;
      surface.allowed = false;
      validator.reject = true;
      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        workflowRun(readyIdentity(paused.planId, paused.runId), paused.stepId)
      ));
      const rejected = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;

      expect(rejected.status).assertEqual('error');
      expect(
        rejected.errorCode === 'ACTION_SURFACE_DENIED' ||
          rejected.errorCode === 'ACTION_ARGS_REJECTED'
      ).assertTrue();
      expect(executor.actionIds.join(',')).assertEqual('hotel.detail');

      agent.stop();
      observer.close();
    });
  });
}
