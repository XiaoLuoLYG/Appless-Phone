import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  ActionPlanRequestPayload,
  ConversationContext,
  CreateDataTaskPayload,
  CreateUiTaskPayload,
  DataResult,
  DataResultStatus,
  InputUserPayload,
  LeaderAgent,
  LeaderDataTaskInputNormalizer,
  LeaderDataTask,
  LeaderDecision,
  LeaderDecisionDataTask,
  LegacyHandoffPayload,
  LeaderPlan,
  LeaderPlanner,
  LeaderPlannerResult,
  LeaderPlanningContext,
  LeaderToolMetadata,
  LeaderUiTask,
  LinkedMessageBus,
  LocalModel,
  MAX_LEADER_DATA_TASKS_PER_ROUND,
  MAX_LEADER_DATA_TASKS_PER_TURN,
  TaskErrorPayload,
  TurnResultPayload,
  UiRenderResultPayload
} from '@loop/agent-core';
import { MultiAgentLeaderPlanner } from '../main/ets/pages/A2uiHome/agent/MultiAgentLeaderPlanner';
import { leaderPersonaContext } from '../main/ets/model/LeaderPersonaContext';
import { routePersonaForPrompt } from '../main/ets/model/PersonaRouter';

interface HotelSearchArgs {
  city: string;
  checkIn: string;
  checkOut: string;
  guests: number;
}

class ScriptedLeaderPlanner implements LeaderPlanner {
  calls: number = 0;
  private readonly scriptedPlan: LeaderPlan;

  constructor(scriptedPlan: LeaderPlan) {
    this.scriptedPlan = scriptedPlan;
  }

  async plan(
    _message: AgentMessage,
    _input: InputUserPayload,
    _context: LeaderPlanningContext
  ): Promise<LeaderPlan> {
    this.calls++;
    return this.scriptedPlan;
  }
}

class ThrowingLeaderPlanner implements LeaderPlanner {
  async plan(
    _message: AgentMessage,
    _input: InputUserPayload,
    _context: LeaderPlanningContext
  ): Promise<LeaderPlan> {
    throw new Error('planner unavailable');
  }
}

class CapturingLeaderPlanner implements LeaderPlanner {
  lastInput: InputUserPayload | null = null;

  async plan(
    _message: AgentMessage,
    input: InputUserPayload,
    _context: LeaderPlanningContext
  ): Promise<LeaderPlan> {
    this.lastInput = input;
    return hotelPlan();
  }
}

class RoutedPersonaPlanner implements LeaderPlanner {
  lastInput: InputUserPayload | null = null;
  lastContext: LeaderPlanningContext | null = null;
  lastPlan: LeaderPlan | null = null;

  async plan(
    _message: AgentMessage,
    input: InputUserPayload,
    context: LeaderPlanningContext
  ): Promise<LeaderPlan> {
    this.lastInput = input;
    this.lastContext = context;
    const personaId = routePersonaForPrompt(input.text).personaId;
    const persona = context.personas.filter((item): boolean => item.personaId === personaId)[0];
    const plan = hotelPlan('persona-ui', 'persona-data');
    plan.personaId = personaId;
    plan.skillId = persona.activeSkills.length === 0 ? '' : persona.activeSkills[0].skillId;
    this.lastPlan = plan;
    return plan;
  }
}

class FirstCallHangingPlanner implements LeaderPlanner {
  calls: number = 0;
  private readonly scriptedPlan: LeaderPlan;

  constructor(scriptedPlan: LeaderPlan) {
    this.scriptedPlan = scriptedPlan;
  }

  async plan(
    _message: AgentMessage,
    _input: InputUserPayload,
    _context: LeaderPlanningContext
  ): Promise<LeaderPlan> {
    this.calls++;
    if (this.calls === 1) {
      return new Promise<LeaderPlan>((_resolve: (plan: LeaderPlan) => void) => {
      });
    }
    return this.scriptedPlan;
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
    const resolve: (() => void) | null = this.resolvePromise;
    this.resolvePromise = null;
    if (resolve !== null) {
      resolve();
    }
  }
}

class ControlledFirstPlanner implements LeaderPlanner {
  calls: number = 0;
  readonly firstStarted: TestGate = new TestGate();
  private readonly nextPlan: LeaderPlan;
  private resolveFirst: ((plan: LeaderPlan) => void) | null = null;

  constructor(nextPlan: LeaderPlan) {
    this.nextPlan = nextPlan;
  }

  async plan(
    _message: AgentMessage,
    _input: InputUserPayload,
    _context: LeaderPlanningContext
  ): Promise<LeaderPlan> {
    this.calls++;
    if (this.calls === 1) {
      return new Promise<LeaderPlan>((resolve: (plan: LeaderPlan) => void) => {
        this.resolveFirst = resolve;
        this.firstStarted.open();
      });
    }
    return this.nextPlan;
  }

  finishFirst(plan: LeaderPlan): void {
    const resolve: ((plan: LeaderPlan) => void) | null = this.resolveFirst;
    this.resolveFirst = null;
    if (resolve !== null) {
      resolve(plan);
    }
  }
}

class ControlledInvalidLeaderModel implements LocalModel {
  prompts: string[] = [];
  readonly firstStarted: TestGate = new TestGate();
  readonly releaseFirst: TestGate = new TestGate();

  async complete(
    prompt: string,
    _conversation?: ConversationContext,
    _systemPrompt?: string
  ): Promise<string> {
    this.prompts.push(prompt);
    if (this.prompts.length === 1) {
      this.firstStarted.open();
      await this.releaseFirst.promise;
    }
    return '{"answer":"invalid without the strict decision fields"}';
  }
}

class RoundScriptedPlanner implements LeaderPlanner {
  calls: number = 0;
  inputs: InputUserPayload[] = [];
  rounds: number[] = [];
  private readonly decisions: LeaderDecision[];

  constructor(decisions: LeaderDecision[]) {
    this.decisions = decisions.slice();
  }

  async plan(
    _message: AgentMessage,
    input: InputUserPayload,
    _context: LeaderPlanningContext,
    round: number = 1
  ): Promise<LeaderDecision> {
    this.calls++;
    this.inputs.push(input);
    this.rounds.push(round);
    if (this.decisions.length === 0) {
      throw new Error('No scripted Leader decision');
    }
    return this.decisions.shift() as LeaderDecision;
  }
}

class ThrowingPostObservationPlanner implements LeaderPlanner {
  calls: number = 0;
  private readonly firstDecision: LeaderDecision;

  constructor(firstDecision: LeaderDecision) {
    this.firstDecision = firstDecision;
  }

  async plan(
    _message: AgentMessage,
    _input: InputUserPayload,
    _context: LeaderPlanningContext,
    _round: number = 1
  ): Promise<LeaderDecision> {
    this.calls++;
    if (this.calls === 1) {
      return this.firstDecision;
    }
    throw new Error('LEADER_UNBOUND_LATER_TOOL');
  }
}

class ControlledPostObservationPlanner implements LeaderPlanner {
  calls: number = 0;
  readonly secondStarted: TestGate = new TestGate();
  private readonly firstDecision: LeaderDecision;
  private resolveSecond: ((decision: LeaderDecision) => void) | null = null;

  constructor(firstDecision: LeaderDecision) {
    this.firstDecision = firstDecision;
  }

  async plan(
    _message: AgentMessage,
    _input: InputUserPayload,
    _context: LeaderPlanningContext,
    _round: number = 1
  ): Promise<LeaderDecision> {
    this.calls++;
    if (this.calls === 1) {
      return this.firstDecision;
    }
    return new Promise<LeaderDecision>((resolve: (decision: LeaderDecision) => void) => {
      this.resolveSecond = resolve;
      this.secondStarted.open();
    });
  }

  finishSecond(decision: LeaderDecision): void {
    const resolve: ((decision: LeaderDecision) => void) | null = this.resolveSecond;
    this.resolveSecond = null;
    if (resolve !== null) {
      resolve(decision);
    }
  }
}

class MixedRoundPlanner implements LeaderPlanner {
  calls: number = 0;
  private readonly results: LeaderPlannerResult[];

  constructor(results: LeaderPlannerResult[]) {
    this.results = results.slice();
  }

  async plan(
    _message: AgentMessage,
    _input: InputUserPayload,
    _context: LeaderPlanningContext,
    _round: number = 1
  ): Promise<LeaderPlannerResult> {
    this.calls++;
    if (this.results.length === 0) {
      throw new Error('No mixed Leader result');
    }
    return this.results.shift() as LeaderPlannerResult;
  }
}

function hotelPlan(uiTaskId: string = 'ui-1', dataTaskId: string = 'data-1'): LeaderPlan {
  const ui: LeaderUiTask = {
    taskId: uiTaskId,
    intent: 'Show a hotel search surface',
    expectedOutputSchema: 'hotelSearchResults'
  };
  const args: HotelSearchArgs = {
    city: 'Shenzhen',
    checkIn: '2026-07-21',
    checkOut: '2026-07-22',
    guests: 2
  };
  const data: LeaderDataTask = {
    taskId: dataTaskId,
    toolId: 'hotel.search',
    outputSchema: 'hotelSearchResults',
    args
  };
  return {
    personaId: '',
    skillId: '',
    roundAction: 'execute',
    ui,
    dataTasks: [data],
    reasonCode: 'hotel_search'
  };
}

function semanticDataTask(localId: string, toolId: string = 'hotel.search'): LeaderDecisionDataTask {
  return {
    localId,
    goal: 'Read real data for ' + localId,
    allowedToolIds: [toolId],
    toolId,
    input: new Object(),
    required: false
  };
}

function semanticDecision(tasks: LeaderDecisionDataTask[], action: string = 'execute'): LeaderDecision {
  const requestedCapabilityIds: string[] = [];
  for (let index = 0; index < tasks.length; index++) {
    for (let allowedIndex = 0; allowedIndex < tasks[index].allowedToolIds.length; allowedIndex++) {
      const toolId: string = tasks[index].allowedToolIds[allowedIndex];
      if (requestedCapabilityIds.indexOf(toolId) < 0) {
        requestedCapabilityIds.push(toolId);
      }
    }
  }
  if (action === 'answer') {
    requestedCapabilityIds.push('hotel.search');
  }
  const decision: LeaderDecision = {
    personaId: 'travel_companion',
    skillId: '',
    requestedCapabilityIds,
    roundAction: action === 'answer' ? 'answer' : 'execute',
    dataTasks: tasks,
    uiIntent: {
      purpose: 'Show real data',
      preferredDensity: 'comfortable',
      requiredSections: tasks.map((task: LeaderDecisionDataTask): string => task.localId)
    },
    reasonCode: action === 'answer' ? 'observed' : 'read'
  };
  if (action === 'answer') {
    decision.answer = 'Enough observations';
  }
  return decision;
}

function withNormalizationDate(
  decision: LeaderDecision,
  currentLocalDate: string = '2026-07-20'
): LeaderDecision {
  decision.normalizationCurrentLocalDate = currentLocalDate;
  return decision;
}

function fixedCurrentLocalDate(): string {
  return '2026-07-20';
}

function repeatedSemanticTasks(count: number): LeaderDecisionDataTask[] {
  const tasks: LeaderDecisionDataTask[] = [];
  for (let index = 0; index < count; index++) {
    tasks.push(semanticDataTask('travel-' + index.toString(), 'travel.search'));
  }
  return tasks;
}

function planningContext(): LeaderPlanningContext {
  return {
    tools: [{
      toolId: 'hotel.search',
      domain: 'hotel',
      intent: 'hotel.search',
      riskLevel: 'read',
      registeredBackends: ['mcp_remote'],
      inputSchema: 'hotelSearchRequest',
      outputSchema: 'hotelSearchResults',
      actions: ['hotel.detail', 'hotel.navigate', 'hotel.book.external']
    }, {
      toolId: 'hotel.detail',
      domain: 'hotel',
      intent: 'hotel.detail',
      riskLevel: 'read',
      registeredBackends: ['local_adapter'],
      inputSchema: 'hotelDetailRequest',
      outputSchema: 'hotelRatePlans',
      actions: []
    }, {
      toolId: 'hotel.navigate',
      domain: 'hotel',
      intent: 'hotel.navigate',
      riskLevel: 'read',
      registeredBackends: ['system_intent'],
      inputSchema: 'hotelNavigateRequest',
      outputSchema: 'systemIntentResult',
      actions: []
    }],
    personas: []
  };
}

function realPersonaPlanningContext(): LeaderPlanningContext {
  return {
    tools: planningContext().tools,
    personas: leaderPersonaContext('food_companion')
  };
}

function semanticPlanningContext(): LeaderPlanningContext {
  return {
    tools: planningContext().tools,
    personas: [{
      personaId: 'travel_companion',
      name: 'Travel Companion',
      soul: 'Use real travel results.',
      memory: 'No saved preference.',
      previous: false,
      activeSkills: []
    }]
  };
}

function nineDataPlanningContext(): LeaderPlanningContext {
  const ids: string[] = [
    'travel.search',
    'train.search',
    'flight.search',
    'hotel.search',
    'food.search',
    'social.feed.search',
    'x.post.search',
    'mail.search',
    'mail.thread.read'
  ];
  const tools: LeaderToolMetadata[] = [];
  for (let index = 0; index < ids.length; index++) {
    tools.push({
      toolId: ids[index],
      domain: ids[index].split('.')[0],
      intent: ids[index],
      riskLevel: 'read',
      registeredBackends: ['local_adapter'],
      inputSchema: ids[index] + '.input',
      outputSchema: ids[index] + '.output',
      actions: []
    });
  }
  return {
    tools,
    personas: semanticPlanningContext().personas
  };
}

function normalizationPlanningContext(): LeaderPlanningContext {
  const context = nineDataPlanningContext();
  context.tools.push({
    toolId: 'calendar.events.search',
    domain: 'calendar',
    intent: 'calendar.events.search',
    riskLevel: 'read',
    registeredBackends: ['local_adapter'],
    inputSchema: 'calendar.events.search.input',
    outputSchema: 'calendar.events.search.output',
    actions: []
  });
  return context;
}

function dependentDataPlanningContext(): LeaderPlanningContext {
  const context = nineDataPlanningContext();
  context.tools.push({
    toolId: 'maps.place.search',
    domain: 'maps',
    intent: 'maps.place.search',
    riskLevel: 'read',
    registeredBackends: ['oauth_api'],
    inputSchema: 'mapsPlaceSearchQuery',
    outputSchema: 'places',
    actions: []
  });
  context.tools.push({
    toolId: 'maps.place.details',
    domain: 'maps',
    intent: 'maps.place.details',
    riskLevel: 'read',
    registeredBackends: ['oauth_api'],
    inputSchema: 'mapsPlaceDetailsQuery',
    outputSchema: 'place',
    actions: []
  });
  return context;
}

function addHotelNavigateActionMetadata(context: LeaderPlanningContext): void {
  const hotelTool = context.tools.filter(
    (tool: LeaderToolMetadata): boolean => tool.toolId === 'hotel.search'
  )[0];
  hotelTool.actions.push('hotel.navigate');
  context.tools.push({
    toolId: 'hotel.navigate',
    domain: 'hotel',
    intent: 'hotel.navigate',
    riskLevel: 'read',
    registeredBackends: ['system_intent'],
    inputSchema: 'hotelNavigateRequest',
    outputSchema: 'systemIntentResult',
    actions: []
  });
}

function aggregatePlanningContext(): LeaderPlanningContext {
  const context = semanticPlanningContext();
  context.tools.push({
    toolId: 'media.aggregate.search',
    domain: 'media',
    intent: 'media.aggregate.search',
    riskLevel: 'read',
    registeredBackends: ['local_adapter'],
    inputSchema: 'media.aggregate.search.input',
    outputSchema: 'media.aggregate.search.output',
    actions: []
  });
  return context;
}

function hybridLeaderResult(): LeaderPlannerResult {
  return JSON.parse(
    '{"personaId":"","skillId":"","roundAction":"execute",' +
    '"ui":{"taskId":"hybrid-ui","intent":"Show hotels","expectedOutputSchema":"hotelSearchResults"},' +
    '"dataTasks":[{"taskId":"hybrid-data","toolId":"hotel.search",' +
    '"outputSchema":"hotelSearchResults","args":{"city":"Shenzhen"}}],' +
    '"uiIntent":{"purpose":"bypass","preferredDensity":"comfortable","requiredSections":["hotel"]},' +
    '"reasonCode":"hybrid"}'
  ) as LeaderPlannerResult;
}

function inputMessage(
  conversationId: string = 'conversation-hotel',
  turnId: string = 'turn-1',
  taskId: string = 'input-1',
  text: string = 'Find a Shenzhen hotel'
): AgentMessage {
  const payload: InputUserPayload = { text };
  return {
    type: AgentMessageType.INPUT_USER,
    conversationId,
    turnId,
    taskId,
    payload
  };
}

function terminalMessage(type: AgentMessageType, taskId: string, turnId: string = 'turn-1'): AgentMessage {
  return {
    type,
    conversationId: 'conversation-hotel',
    turnId,
    taskId,
    payload: new Object()
  };
}

function dataResultMessage(task: AgentMessage, summary: string = 'real result'): AgentMessage {
  const payload: DataResult = {
    toolId: (task.payload as CreateDataTaskPayload).toolId,
    outputSchema: (task.payload as CreateDataTaskPayload).outputSchema,
    status: 'success',
    sources: [],
    data: JSON.parse('{"summary":"' + summary + '","entityRefs":["entity-1"],"secret":"must-not-reach-model"}') as Object,
    warnings: []
  };
  return {
    type: AgentMessageType.TASK_RESULT_DATA,
    conversationId: task.conversationId,
    turnId: task.turnId,
    taskId: task.taskId,
    payload
  };
}

function dataResultMessageWithEntityRefs(
  task: AgentMessage,
  summary: string,
  entityRefs: string[]
): AgentMessage {
  const message: AgentMessage = dataResultMessage(task, summary);
  (message.payload as DataResult).data = JSON.parse(
    '{"summary":' + JSON.stringify(summary) + ',"entityRefs":' + JSON.stringify(entityRefs) +
    ',"secret":"must-not-reach-model"}'
  ) as Object;
  return message;
}

function dataResultMessageWithStatus(task: AgentMessage, status: DataResultStatus): AgentMessage {
  const payload: DataResult = {
    toolId: (task.payload as CreateDataTaskPayload).toolId,
    outputSchema: (task.payload as CreateDataTaskPayload).outputSchema,
    status,
    sources: [],
    data: JSON.parse('{"summary":"' + status + '","entityRefs":[]}') as Object,
    warnings: []
  };
  return {
    type: AgentMessageType.TASK_RESULT_DATA,
    conversationId: task.conversationId,
    turnId: task.turnId,
    taskId: task.taskId,
    payload
  };
}

async function semanticTerminalStatus(statuses: DataResultStatus[]): Promise<string> {
  const bus = new LinkedMessageBus();
  const tasks: LeaderDecisionDataTask[] = statuses.map(
    (_status: DataResultStatus, index: number): LeaderDecisionDataTask =>
      semanticDataTask('status-' + index.toString())
  );
  const planner = new RoundScriptedPlanner([
    semanticDecision(tasks),
    semanticDecision([], 'answer')
  ]);
  const leader = new LeaderAgent(bus, planner, semanticPlanningContext());
  const observer = bus.openReader();
  leader.start();
  try {
    bus.publish(inputMessage());
    await receive(observer);
    const dataTasks: AgentMessage[] = [];
    for (let index = 0; index < statuses.length; index++) {
      dataTasks.push(await receive(observer));
    }
    for (let index = 0; index < statuses.length; index++) {
      bus.publish(dataResultMessageWithStatus(dataTasks[index], statuses[index]));
      await receive(observer);
    }
    const uiTask: AgentMessage = await receive(observer);
    const uiResult: UiRenderResultPayload = {
      surfaceId: 'surface-status',
      state: 'result'
    };
    bus.publish({
      type: AgentMessageType.TASK_RESULT_UI,
      conversationId: uiTask.conversationId,
      turnId: uiTask.turnId,
      taskId: uiTask.taskId,
      payload: uiResult
    });
    await receive(observer);
    const terminal: AgentMessage = await receive(observer);
    return (terminal.payload as TurnResultPayload).status;
  } finally {
    leader.stop();
    observer.close();
  }
}

async function receive(reader: AgentMessageReader): Promise<AgentMessage> {
  const message: AgentMessage | null = await reader.receive();
  if (message === null) {
    throw new Error('observer closed before receiving a message');
  }
  return message;
}

async function settle(): Promise<void> {
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
}

async function rejectionAfterNormalizedInput(normalized: Object): Promise<string> {
  const firstTask = semanticDataTask('place-search', 'maps.place.search');
  firstTask.input = JSON.parse('{"query":"深圳咖啡"}') as Object;
  const secondTask = semanticDataTask('place-details', 'maps.place.details');
  secondTask.input = new Object();
  const planner = new RoundScriptedPlanner([
    withNormalizationDate(semanticDecision([firstTask])),
    withNormalizationDate(semanticDecision([secondTask]))
  ]);
  const normalizer: LeaderDataTaskInputNormalizer = (
    _input: InputUserPayload,
    task: LeaderDecisionDataTask
  ): Object => task.toolId === 'maps.place.details' ? normalized : task.input;
  const bus = new LinkedMessageBus();
  const leader = new LeaderAgent(
    bus,
    planner,
    dependentDataPlanningContext(),
    30000,
    normalizer,
    undefined,
    fixedCurrentLocalDate
  );
  const observer = bus.openReader();
  leader.start();
  try {
    bus.publish(inputMessage());
    await receive(observer);
    const firstData = await receive(observer);
    bus.publish(dataResultMessage(firstData));
    await receive(observer);
    const blocked = await receive(observer);
    return blocked.type === AgentMessageType.TASK_ERROR ?
      (blocked.payload as TaskErrorPayload).code : 'PUBLISHED_' + blocked.type.toString();
  } finally {
    leader.stop();
    observer.close();
  }
}

async function repairCallsAfterTerminal(kind: string): Promise<number> {
  const bus = new LinkedMessageBus();
  const model = new ControlledInvalidLeaderModel();
  const leader = new LeaderAgent(
    bus,
    new MultiAgentLeaderPlanner(model),
    semanticPlanningContext(),
    kind === 'timeout' ? 10 : 200
  );
  const observer = bus.openReader();
  leader.start();
  try {
    bus.publish(inputMessage());
    await receive(observer);
    await model.firstStarted.promise;
    if (kind === 'cancel') {
      bus.publish(terminalMessage(AgentMessageType.TURN_CANCEL, 'cancel-repair'));
      await receive(observer);
    } else if (kind === 'timeout') {
      await receive(observer);
    } else {
      leader.stop();
    }
    model.releaseFirst.open();
    await settle();
    return model.prompts.length;
  } finally {
    leader.stop();
    observer.close();
  }
}

export default function leaderAgentTest() {
  describe('leaderAgent', () => {
    it('publishes an exact valid legacy hotel shape on round one', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const leader: LeaderAgent = new LeaderAgent(
        bus,
        new ScriptedLeaderPlanner(hotelPlan()),
        planningContext()
      );
      const observer: AgentMessageReader = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const uiMessage: AgentMessage = await receive(observer);
      const dataMessage: AgentMessage = await receive(observer);
      const ui: CreateUiTaskPayload = uiMessage.payload as CreateUiTaskPayload;
      const data: CreateDataTaskPayload = dataMessage.payload as CreateDataTaskPayload;
      const args: HotelSearchArgs = data.args as HotelSearchArgs;

      expect(uiMessage.type).assertEqual(AgentMessageType.TASK_CREATE_UI);
      expect(dataMessage.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      expect(uiMessage.conversationId).assertEqual('conversation-hotel');
      expect(dataMessage.conversationId).assertEqual('conversation-hotel');
      expect(uiMessage.turnId).assertEqual('turn-1');
      expect(dataMessage.turnId).assertEqual('turn-1');
      expect(uiMessage.taskId.length > 0).assertTrue();
      expect(dataMessage.taskId.length > 0).assertTrue();
      expect(uiMessage.taskId === dataMessage.taskId).assertFalse();
      expect(ui.taskId).assertEqual(uiMessage.taskId);
      expect(ui.dataTaskIds[0]).assertEqual(dataMessage.taskId);
      expect(data.taskId).assertEqual(dataMessage.taskId);
      expect(data.toolId).assertEqual('hotel.search');
      expect(data.outputSchema).assertEqual('hotelSearchResults');
      expect(ui.skillId).assertEqual('');
      expect(data.skillId).assertEqual('');
      expect(args.city).assertEqual('Shenzhen');
      expect(args.guests).assertEqual(2);
      expect(Object.keys(ui).sort().join(',')).assertEqual('dataTaskIds,expectedOutputSchema,intent,skillId,taskId');
      expect(Object.keys(data).sort().join(',')).assertEqual('allowedToolIds,args,goal,outputSchema,required,roundId,skillId,taskId,toolId');
      expect(JSON.stringify(ui).indexOf('provider')).assertEqual(-1);
      expect(JSON.stringify(ui).indexOf('jsonl')).assertEqual(-1);
      expect(JSON.stringify(ui).indexOf('createSurface')).assertEqual(-1);
      expect(JSON.stringify(data).indexOf('provider')).assertEqual(-1);
      expect(JSON.stringify(data).indexOf('jsonl')).assertEqual(-1);

      bus.publish(terminalMessage(AgentMessageType.TURN_CANCEL, 'cancel-1'));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TURN_CANCEL);
      leader.stop();
      observer.close();
    });

    it('rejects a hybrid semantic and legacy result before publishing tasks', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new MixedRoundPlanner([hybridLeaderResult()]);
      const leader = new LeaderAgent(bus, planner, semanticPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const error = await receive(observer);

      expect(error.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect(error.taskId).assertEqual('input-1');
      expect((error.payload as TaskErrorPayload).code).assertEqual('LEADER_PLAN_INVALID');
      expect(planner.calls).assertEqual(1);
      leader.stop();
      observer.close();
    });

    it('rejects a legacy-shaped second round immediately and keeps the pump available', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new MixedRoundPlanner([
        semanticDecision([semanticDataTask('semantic-round-1')]),
        hotelPlan('forbidden-round-2-ui', 'forbidden-round-2-data'),
        hotelPlan('recovery-ui', 'recovery-data')
      ]);
      const leader = new LeaderAgent(bus, planner, semanticPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const semanticTask = await receive(observer);
      expect(semanticTask.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      bus.publish(dataResultMessage(semanticTask));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      const error = await receive(observer);

      expect(error.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect(error.taskId).assertEqual('input-1');
      expect((error.payload as TaskErrorPayload).code).assertEqual('LEADER_PLAN_INVALID');

      bus.publish(inputMessage('conversation-hotel', 'turn-2', 'input-2'));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const recoveryUi = await receive(observer);
      const recoveryData = await receive(observer);
      expect(recoveryUi.type).assertEqual(AgentMessageType.TASK_CREATE_UI);
      expect(recoveryData.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      expect(recoveryUi.taskId).assertEqual('recovery-ui');
      expect(recoveryData.taskId).assertEqual('recovery-data');
      expect(planner.calls).assertEqual(3);
      leader.stop();
      observer.close();
    });

    it('rejects a non-execute legacy result before tasks and keeps the pump available', 0, async () => {
      const nonExecute = hotelPlan('forbidden-answer-ui', 'forbidden-answer-data');
      nonExecute.roundAction = 'answer';
      nonExecute.answer = 'Do not publish legacy tasks';
      const bus = new LinkedMessageBus();
      const planner = new MixedRoundPlanner([
        nonExecute,
        hotelPlan('answer-recovery-ui', 'answer-recovery-data')
      ]);
      const leader = new LeaderAgent(bus, planner, planningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const error = await receive(observer);
      expect(error.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect((error.payload as TaskErrorPayload).code).assertEqual('LEADER_PLAN_INVALID');

      bus.publish(inputMessage('conversation-hotel', 'turn-answer-recovery', 'input-answer-recovery'));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      expect((await receive(observer)).taskId).assertEqual('answer-recovery-ui');
      expect((await receive(observer)).taskId).assertEqual('answer-recovery-data');
      expect(planner.calls).assertEqual(2);
      leader.stop();
      observer.close();
    });

    it('passes supplied bounded input context to the planner', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new CapturingLeaderPlanner();
      const leader = new LeaderAgent(bus, planner, planningContext());
      const observer = bus.openReader();
      leader.start();
      const payload: InputUserPayload = {
        text: 'Find a Shenzhen hotel',
        recentMessages: [{ role: 'user', content: 'Near Futian' }],
        previousPersonaId: 'travel_companion',
        currentSurfaceSummary: {
          surfaceId: 'surface-1',
          kind: 'hotel',
          status: 'ready',
          entityRefs: ['hotel-1'],
          actionOfferIds: ['offer-1']
        },
        recentObservations: [{
          taskId: 'data-1',
          toolId: 'hotel.search',
          status: 'success',
          summary: 'one hotel',
          entityRefs: ['hotel-1']
        }]
      };
      bus.publish({
        type: AgentMessageType.INPUT_USER,
        conversationId: 'conversation-context',
        turnId: 'turn-context',
        taskId: 'input-context',
        payload
      });
      await receive(observer);
      await receive(observer);
      await receive(observer);
      const input = planner.lastInput as InputUserPayload;

      expect(input.recentMessages!.length).assertEqual(1);
      expect(input.previousPersonaId).assertEqual('travel_companion');
      expect(input.currentSurfaceSummary!.surfaceId).assertEqual('surface-1');
      expect(input.recentObservations![0].toolId).assertEqual('hotel.search');
      leader.stop();
      observer.close();
    });

    it('normalizes omitted bounded input context before planning', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new CapturingLeaderPlanner();
      const leader = new LeaderAgent(bus, planner, planningContext());
      const observer = bus.openReader();
      leader.start();
      bus.publish(inputMessage());
      await receive(observer);
      await receive(observer);
      await receive(observer);
      const input = planner.lastInput as InputUserPayload;

      expect(input.recentMessages!.length).assertEqual(0);
      expect(input.previousPersonaId).assertEqual('');
      expect(input.currentSurfaceSummary!.surfaceId).assertEqual('');
      expect(input.currentSurfaceSummary!.entityRefs.length).assertEqual(0);
      expect(input.currentSurfaceSummary!.actionOfferIds.length).assertEqual(0);
      expect(input.recentObservations!.length).assertEqual(0);
      leader.stop();
      observer.close();
    });

    it('caps and sanitizes supplied observation history before the first model call', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new CapturingLeaderPlanner();
      const leader = new LeaderAgent(bus, planner, planningContext());
      const observer = bus.openReader();
      leader.start();
      const observations: Object[] = [];
      for (let index = 0; index < 10; index++) {
        observations.push(JSON.parse('{"taskId":"task-' + index.toString() + '","toolId":"hotel.search",' +
          '"status":"success","summary":"' + 'x'.repeat(300) + '","entityRefs":["hotel-1"],' +
          '"providerSecret":"must-not-reach-model"}') as Object);
      }
      const payload: Object = JSON.parse('{"text":"Find a hotel"}') as Object;
      (payload as Record<string, Object | string | number | boolean | null | undefined>)['recentObservations'] =
        observations;
      bus.publish({
        type: AgentMessageType.INPUT_USER,
        conversationId: 'conversation-bounded-observations',
        turnId: 'turn-bounded-observations',
        taskId: 'input-bounded-observations',
        payload
      });
      await receive(observer);
      await receive(observer);
      await receive(observer);
      const input = planner.lastInput as InputUserPayload;

      expect(input.recentObservations!.length).assertEqual(8);
      expect(input.recentObservations![0].taskId).assertEqual('task-2');
      expect(input.recentObservations![0].summary.length).assertEqual(240);
      expect(JSON.stringify(input).indexOf('must-not-reach-model')).assertEqual(-1);
      leader.stop();
      observer.close();
    });

    it('publishes one semantic UI, ordered Data tasks, then the optional Action request', 0, async () => {
      const bus = new LinkedMessageBus();
      const flightTask = semanticDataTask('flight', 'flight.search');
      flightTask.allowedToolIds.push('train.search');
      const decision = semanticDecision([flightTask, semanticDataTask('train', 'train.search')]);
      decision.actionIntent = {
        goal: 'Navigate after results',
        allowedActionIds: ['hotel.navigate']
      };
      decision.requestedCapabilityIds.push('hotel.navigate');
      const planner = new RoundScriptedPlanner([decision, semanticDecision([], 'answer')]);
      const context = semanticPlanningContext();
      context.tools.push({
        toolId: 'flight.search',
        domain: 'travel',
        intent: 'flight.search',
        riskLevel: 'read',
        registeredBackends: ['mcp_remote'],
        inputSchema: 'flightSearchRequest',
        outputSchema: 'flights',
        actions: []
      }, {
        toolId: 'train.search',
        domain: 'travel',
        intent: 'train.search',
        riskLevel: 'read',
        registeredBackends: ['local_adapter'],
        inputSchema: 'trainSearchRequest',
        outputSchema: 'trains',
        actions: []
      });
      const leader = new LeaderAgent(bus, planner, context);
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const first = await receive(observer);
      const second = await receive(observer);
      bus.publish(dataResultMessage(first));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      bus.publish(dataResultMessage(second));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      const uiMessage = await receive(observer);
      const actionMessage = await receive(observer);
      const ui = uiMessage.payload as CreateUiTaskPayload;
      const firstPayload = first.payload as CreateDataTaskPayload;
      const secondPayload = second.payload as CreateDataTaskPayload;
      const action = actionMessage.payload as ActionPlanRequestPayload;

      expect(uiMessage.type).assertEqual(AgentMessageType.TASK_CREATE_UI);
      expect(first.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      expect(second.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      expect(actionMessage.type).assertEqual(AgentMessageType.ACTION_PLAN_REQUEST);
      expect(uiMessage.taskId).assertEqual('input-1:ui');
      expect(ui.dataTaskIds.join(',')).assertEqual(
        'input-1:round-1:flight,input-1:round-1:train'
      );
      expect(ui.intent).assertEqual('Show real data');
      expect(ui.expectedOutputSchema).assertEqual('flights');
      expect(first.taskId === second.taskId).assertFalse();
      expect(firstPayload.roundId).assertEqual(secondPayload.roundId);
      expect(firstPayload.goal).assertEqual('Read real data for flight');
      expect(secondPayload.goal).assertEqual('Read real data for train');
      expect(action.uiTaskId).assertEqual(uiMessage.taskId);
      expect(action.dataTaskIds.join(',')).assertEqual(ui.dataTaskIds.join(','));
      expect(action.goal).assertEqual('Navigate after results');
      expect(action.allowedActionIds.join(',')).assertEqual('hotel.navigate');
      expect(action.personaId).assertEqual('travel_companion');
      expect(action.inputText).assertEqual('Find a Shenzhen hotel');
      expect(planner.calls).assertEqual(2);

      bus.publish(terminalMessage(AgentMessageType.TURN_CANCEL, 'cancel-parallel'));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TURN_CANCEL);
      leader.stop();
      observer.close();
    });

    it('rejects a custom planner same-round dependency after normalization and before observation or tasks', 0, async () => {
      const search = semanticDataTask('place-search', 'maps.place.search');
      search.input = JSON.parse('{"query":"深圳咖啡"}') as Object;
      const details = semanticDataTask('place-details', 'maps.place.details');
      details.input = JSON.parse('{"placeId":"place-forged"}') as Object;
      const planner = new RoundScriptedPlanner([
        withNormalizationDate(semanticDecision([details, search]))
      ]);
      let normalized: number = 0;
      let observed: number = 0;
      const normalizer: LeaderDataTaskInputNormalizer = (
        _input: InputUserPayload,
        task: LeaderDecisionDataTask
      ): Object => {
        normalized++;
        return task.input;
      };
      const bus = new LinkedMessageBus();
      const leader = new LeaderAgent(
        bus,
        planner,
        dependentDataPlanningContext(),
        30000,
        normalizer,
        (): void => {
          observed++;
        },
        fixedCurrentLocalDate
      );
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const blocked = await receive(observer);

      expect(blocked.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect((blocked.payload as TaskErrorPayload).code).assertEqual('LEADER_SAME_ROUND_DEPENDENCY');
      expect(normalized).assertEqual(2);
      expect(observed).assertEqual(0);
      bus.publish(terminalMessage(AgentMessageType.ACTION_RESULT, 'same-round-marker'));
      expect((await receive(observer)).taskId).assertEqual('same-round-marker');
      leader.stop();
      observer.close();
    });

    it('rejects an owned requested capability outside the exact execution union', 0, async () => {
      const bus = new LinkedMessageBus();
      const decision = semanticDecision([semanticDataTask('hotel')]);
      decision.requestedCapabilityIds.push('memory.update');
      const context = semanticPlanningContext();
      context.tools.push({
        toolId: 'memory.update',
        domain: 'persona',
        intent: 'memory.update',
        riskLevel: 'draft',
        registeredBackends: ['local_adapter'],
        inputSchema: 'memoryUpdateRequest',
        outputSchema: 'memoryUpdateResult',
        actions: ['memory.update']
      });
      context.runtimeOwnedToolIds = ['hotel.search', 'memory.update'];
      const leader = new LeaderAgent(bus, new RoundScriptedPlanner([decision]), context);
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const error = await receive(observer);

      expect(error.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect(error.taskId).assertEqual('input-1');
      expect((error.payload as TaskErrorPayload).code).assertEqual('LEADER_PLAN_INVALID');
      leader.stop();
      observer.close();
    });

    it('does not attach an inherited surface to a direct semantic answer', 0, async () => {
      const bus = new LinkedMessageBus();
      const direct = semanticDecision([], 'answer');
      direct.requestedCapabilityIds = [];
      const planner = new RoundScriptedPlanner([direct]);
      const leader = new LeaderAgent(bus, planner, semanticPlanningContext());
      const observer = bus.openReader();
      leader.start();
      const input = inputMessage();
      const payload = input.payload as InputUserPayload;
      payload.currentSurfaceSummary = {
        surfaceId: 'surface-previous',
        kind: 'hotelSearchResults',
        status: 'result',
        entityRefs: ['hotel-101'],
        actionOfferIds: []
      };

      bus.publish(input);
      await settle();
      bus.publish(inputMessage(
        'marker-conversation',
        'marker-turn',
        'marker-task',
        'marker'
      ));
      const beforeMarker: AgentMessage[] = [];
      let next = await receive(observer);
      while (next.taskId !== 'marker-task') {
        beforeMarker.push(next);
        next = await receive(observer);
      }
      const turnResults = beforeMarker.filter(
        (message: AgentMessage): boolean => message.type === AgentMessageType.TURN_RESULT
      );

      expect(turnResults.length).assertEqual(1);
      expect(turnResults[0].conversationId).assertEqual('conversation-hotel');
      expect(turnResults[0].turnId).assertEqual('turn-1');
      expect(turnResults[0].taskId).assertEqual('input-1');
      const result = turnResults[0].payload as TurnResultPayload;
      expect(result.status).assertEqual('success');
      expect(result.surfaceId).assertEqual(undefined);
      expect(result.roundCount).assertEqual(1);
      expect(result.message).assertEqual('Enough observations');
      expect(beforeMarker.filter(
        (message: AgentMessage): boolean => message.type === AgentMessageType.TASK_CREATE_DATA ||
          message.type === AgentMessageType.TASK_CREATE_UI ||
          message.type === AgentMessageType.ACTION_PLAN_REQUEST
      ).length).assertEqual(0);
      leader.stop();
      observer.close();
    });

    it('attaches the exact rendered surface to a capability-backed semantic answer', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new RoundScriptedPlanner([
        semanticDecision([semanticDataTask('travel', 'travel.search')]),
        semanticDecision([], 'answer')
      ]);
      const leader = new LeaderAgent(bus, planner, nineDataPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const dataTask = await receive(observer);
      bus.publish(dataResultMessage(dataTask));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      const uiTask = await receive(observer);
      const uiResult: UiRenderResultPayload = {
        surfaceId: 'loop_surface_1784723405216',
        state: 'result'
      };
      bus.publish({
        type: AgentMessageType.TASK_RESULT_UI,
        conversationId: uiTask.conversationId,
        turnId: uiTask.turnId,
        taskId: uiTask.taskId,
        payload: uiResult
      });
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_UI);
      const terminal = await receive(observer);

      expect(terminal.type).assertEqual(AgentMessageType.TURN_RESULT);
      expect((terminal.payload as TurnResultPayload).surfaceId).assertEqual(
        'loop_surface_1784723405216'
      );
      leader.stop();
      observer.close();
    });

    it('waits for the exact rendered surface when Data completes before UI', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new RoundScriptedPlanner([
        semanticDecision([semanticDataTask('travel', 'travel.search')]),
        semanticDecision([], 'answer')
      ]);
      const leader = new LeaderAgent(bus, planner, nineDataPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const dataTask = await receive(observer);
      bus.publish(dataResultMessage(dataTask));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      const uiTask = await receive(observer);
      const uiResult: UiRenderResultPayload = {
        surfaceId: 'loop_surface_data_first',
        state: 'result'
      };
      bus.publish({
        type: AgentMessageType.TASK_RESULT_UI,
        conversationId: uiTask.conversationId,
        turnId: uiTask.turnId,
        taskId: uiTask.taskId,
        payload: uiResult
      });
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_UI);
      const terminal = await receive(observer);

      expect(terminal.type).assertEqual(AgentMessageType.TURN_RESULT);
      expect((terminal.payload as TurnResultPayload).surfaceId).assertEqual(
        'loop_surface_data_first'
      );
      leader.stop();
      observer.close();
    });

    it('lets an exact terminal UI error override the Data-derived terminal status', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new RoundScriptedPlanner([
        semanticDecision([semanticDataTask('travel', 'travel.search')]),
        semanticDecision([], 'answer')
      ]);
      const leader = new LeaderAgent(bus, planner, nineDataPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const dataTask = await receive(observer);
      bus.publish(dataResultMessage(dataTask));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      const uiTask = await receive(observer);
      const uiResult: UiRenderResultPayload = {
        surfaceId: 'loop_surface_ui_error_first',
        state: 'error'
      };
      bus.publish({
        type: AgentMessageType.TASK_RESULT_UI,
        conversationId: uiTask.conversationId,
        turnId: uiTask.turnId,
        taskId: uiTask.taskId,
        payload: uiResult
      });
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_UI);
      const terminal = await receive(observer);
      const payload = terminal.payload as TurnResultPayload;

      expect(terminal.type).assertEqual(AgentMessageType.TURN_RESULT);
      expect(payload.status).assertEqual('error');
      expect(payload.surfaceId).assertEqual('loop_surface_ui_error_first');
      leader.stop();
      observer.close();
    });

    it('lets an exact Data-first UI error own the single terminal', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new RoundScriptedPlanner([
        semanticDecision([semanticDataTask('travel', 'travel.search')]),
        semanticDecision([], 'answer')
      ]);
      const leader = new LeaderAgent(bus, planner, nineDataPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const dataTask = await receive(observer);
      bus.publish(dataResultMessage(dataTask));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      const uiTask = await receive(observer);
      const uiResult: UiRenderResultPayload = {
        surfaceId: 'loop_surface_data_error_first',
        state: 'error'
      };
      bus.publish({
        type: AgentMessageType.TASK_RESULT_UI,
        conversationId: uiTask.conversationId,
        turnId: uiTask.turnId,
        taskId: uiTask.taskId,
        payload: uiResult
      });
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_UI);
      const terminal = await receive(observer);
      const payload = terminal.payload as TurnResultPayload;

      expect(terminal.type).assertEqual(AgentMessageType.TURN_RESULT);
      expect(payload.status).assertEqual('error');
      expect(payload.surfaceId).assertEqual('loop_surface_data_error_first');
      leader.stop();
      observer.close();
    });

    it('does not attach an inherited surface to a direct clarification', 0, async () => {
      const bus = new LinkedMessageBus();
      const direct = semanticDecision([], 'answer');
      direct.roundAction = 'clarify';
      direct.answer = 'Please provide a city.';
      direct.requestedCapabilityIds = [];
      const leader = new LeaderAgent(
        bus,
        new RoundScriptedPlanner([direct]),
        semanticPlanningContext()
      );
      const observer = bus.openReader();
      leader.start();
      const input = inputMessage();
      (input.payload as InputUserPayload).currentSurfaceSummary = {
        surfaceId: 'surface-previous',
        kind: 'hotelSearchResults',
        status: 'result',
        entityRefs: ['hotel-101'],
        actionOfferIds: []
      };

      bus.publish(input);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const terminal = await receive(observer);

      expect(terminal.type).assertEqual(AgentMessageType.TURN_RESULT);
      expect((terminal.payload as TurnResultPayload).surfaceId).assertEqual(undefined);
      leader.stop();
      observer.close();
    });

    it('publishes only a virtual Action request for a zero-Data semantic execute decision', 0, async () => {
      const bus = new LinkedMessageBus();
      const decision = semanticDecision([]);
      decision.actionIntent = {
        goal: 'Remember the explicit user statement',
        allowedActionIds: ['memory.update']
      };
      decision.requestedCapabilityIds = ['memory.update'];
      const context = semanticPlanningContext();
      context.tools.push({
        toolId: 'memory.update',
        domain: 'persona',
        intent: 'memory.update',
        riskLevel: 'draft',
        registeredBackends: ['local_adapter'],
        inputSchema: 'memoryUpdateRequest',
        outputSchema: 'memoryUpdateResult',
        actions: ['memory.update']
      });
      context.runtimeOwnedToolIds = ['memory.update'];
      const leader = new LeaderAgent(bus, new RoundScriptedPlanner([decision]), context);
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage(
        'conversation-hotel',
        'turn-1',
        'input-1',
        '我在北京'
      ));
      await settle();
      bus.publish(inputMessage('marker-conversation', 'marker-turn', 'marker-task', 'marker'));
      const beforeMarker: AgentMessage[] = [];
      let next = await receive(observer);
      while (next.taskId !== 'marker-task') {
        beforeMarker.push(next);
        next = await receive(observer);
      }
      const requests = beforeMarker.filter(
        (message: AgentMessage): boolean => message.type === AgentMessageType.ACTION_PLAN_REQUEST
      );

      expect(requests.length).assertEqual(1);
      expect(beforeMarker.filter(
        (message: AgentMessage): boolean => message.type === AgentMessageType.TASK_CREATE_DATA ||
          message.type === AgentMessageType.TASK_CREATE_UI
      ).length).assertEqual(0);
      const request = requests[0].payload as ActionPlanRequestPayload;
      expect(request.uiTaskId).assertEqual('input-1:round-1:virtual');
      expect(request.dataTaskIds.length).assertEqual(0);
      expect(request.goal).assertEqual('Remember the explicit user statement');
      expect(request.allowedActionIds.join(',')).assertEqual('memory.update');
      expect(request.personaId).assertEqual('travel_companion');
      expect(request.inputText).assertEqual('我在北京');
      expect(request.virtual).assertTrue();
      leader.stop();
      observer.close();
    });

    it('accepts a registered Action owner self ID when no source declares it as a follow-up', 0, async () => {
      const bus = new LinkedMessageBus();
      const decision = semanticDecision([]);
      decision.actionIntent = {
        goal: 'Open the World Cup page',
        allowedActionIds: ['worldcup.open']
      };
      decision.requestedCapabilityIds = ['worldcup.open'];
      const context = semanticPlanningContext();
      context.tools.push({
        toolId: 'worldcup.open',
        domain: 'media',
        intent: 'worldcup.open',
        riskLevel: 'read',
        registeredBackends: ['system_intent'],
        inputSchema: 'worldCupExperienceRequest',
        outputSchema: 'worldCupExperience',
        actions: []
      });
      const leader = new LeaderAgent(bus, new RoundScriptedPlanner([decision]), context);
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const request = await receive(observer);

      expect(request.type).assertEqual(AgentMessageType.ACTION_PLAN_REQUEST);
      expect((request.payload as ActionPlanRequestPayload).allowedActionIds[0])
        .assertEqual('worldcup.open');
      leader.stop();
      observer.close();
    });

    it('rejects a source-declared page-only action from semantic actionIntent', 0, async () => {
      const bus = new LinkedMessageBus();
      const decision = semanticDecision([]);
      decision.actionIntent = {
        goal: 'Open a renderer-local page operation',
        allowedActionIds: ['hotel.book.external']
      };
      decision.requestedCapabilityIds = ['hotel.book.external'];
      const leader = new LeaderAgent(
        bus,
        new RoundScriptedPlanner([decision]),
        semanticPlanningContext()
      );
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const rejected = await receive(observer);

      expect(rejected.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect((rejected.payload as TaskErrorPayload).code).assertEqual('LEADER_PLAN_INVALID');
      leader.stop();
      observer.close();
    });

    it('accepts a dynamic memory Action owner end to end without a self action declaration', 0, async () => {
      const bus = new LinkedMessageBus();
      const decision = semanticDecision([]);
      decision.actionIntent = {
        goal: 'Remember the explicit user statement',
        allowedActionIds: ['memory.update']
      };
      decision.requestedCapabilityIds = ['memory.update'];
      const context = semanticPlanningContext();
      context.tools.push({
        toolId: 'memory.update',
        domain: 'persona',
        intent: 'memory.update',
        riskLevel: 'draft',
        registeredBackends: ['local_adapter'],
        inputSchema: 'memoryUpdateRequest',
        outputSchema: 'memoryUpdateResult',
        actions: []
      });
      context.runtimeOwnedToolIds = ['hotel.search', 'memory.update'];
      const leader = new LeaderAgent(bus, new RoundScriptedPlanner([decision]), context);
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const request = await receive(observer);

      expect(request.type).assertEqual(AgentMessageType.ACTION_PLAN_REQUEST);
      expect((request.payload as ActionPlanRequestPayload).allowedActionIds[0])
        .assertEqual('memory.update');
      leader.stop();
      observer.close();
    });

    it('publishes a typed semantic legacy handoff before any execution message', 0, async () => {
      const bus = new LinkedMessageBus();
      const decision = semanticDecision([]);
      decision.roundAction = 'legacy_handoff';
      decision.requestedCapabilityIds = ['unknown.search'];
      decision.reasonCode = 'unmigrated_tool';
      const context = semanticPlanningContext();
      context.tools.push({
        toolId: 'unknown.search',
        domain: 'unknown',
        intent: 'unknown.search',
        riskLevel: 'read',
        registeredBackends: [],
        inputSchema: 'dynamicToolSearchQuery',
        outputSchema: 'dynamicToolConnect',
        actions: []
      });
      context.runtimeOwnedToolIds = ['hotel.search'];
      const leader = new LeaderAgent(
        bus,
        new RoundScriptedPlanner([decision]),
        context
      );
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await settle();
      bus.publish(inputMessage('marker-conversation', 'marker-turn', 'marker-task', 'marker'));
      const beforeMarker: AgentMessage[] = [];
      let next = await receive(observer);
      while (next.taskId !== 'marker-task') {
        beforeMarker.push(next);
        next = await receive(observer);
      }

      expect(beforeMarker.length).assertEqual(2);
      expect(beforeMarker[0].type).assertEqual(AgentMessageType.INPUT_USER);
      expect(beforeMarker[1].type).assertEqual(AgentMessageType.TURN_HANDOFF);
      const handoff = beforeMarker[1].payload as LegacyHandoffPayload;
      expect(handoff.owner).assertEqual('legacy');
      expect(handoff.reason).assertEqual('unmigrated_tool');
      expect(handoff.unmigratedToolIds.join(',')).assertEqual('unknown.search');
      expect(handoff.reasonCode).assertEqual('unmigrated_tool');
      expect(handoff.personaId).assertEqual('travel_companion');
      expect(handoff.skillId).assertEqual('');
      leader.stop();
      observer.close();
    });

    it('starts a dependent second round with only bounded observation digests', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new RoundScriptedPlanner([
        semanticDecision([semanticDataTask('place')]),
        semanticDecision([], 'answer')
      ]);
      const leader = new LeaderAgent(bus, planner, semanticPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const task = await receive(observer);
      expect(task.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      bus.publish(dataResultMessage(task));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      await settle();

      expect(planner.calls).assertEqual(2);
      expect(planner.rounds[0]).assertEqual(1);
      expect(planner.rounds[1]).assertEqual(2);
      expect(planner.inputs[1].recentObservations!.length).assertEqual(1);
      expect(planner.inputs[1].recentObservations![0].summary).assertEqual('real result');
      expect(planner.inputs[1].recentObservations![0].entityRefs[0]).assertEqual('entity-1');
      expect(JSON.stringify(planner.inputs[1]).indexOf('must-not-reach-model')).assertEqual(-1);

      leader.stop();
      observer.close();
    });

    it('renders an error DataResult when post-observation planning throws', 0, async () => {
      const firstDecision = semanticDecision([semanticDataTask('maps', 'maps.place.search')]);
      firstDecision.actionIntent = {
        goal: 'Navigate after results',
        allowedActionIds: ['hotel.navigate']
      };
      firstDecision.requestedCapabilityIds.push('hotel.navigate');
      const planner = new ThrowingPostObservationPlanner(firstDecision);
      const bus = new LinkedMessageBus();
      const context = dependentDataPlanningContext();
      addHotelNavigateActionMetadata(context);
      const leader = new LeaderAgent(bus, planner, context, 300);
      const observer = bus.openReader();
      leader.start();

      try {
        bus.publish(inputMessage());
        expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
        const dataTask = await receive(observer);
        expect(dataTask.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
        bus.publish(dataResultMessageWithStatus(dataTask, 'error'));
        expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
        const uiTask = await receive(observer);
        const uiPayload = uiTask.payload as CreateUiTaskPayload;

        expect(uiTask.type).assertEqual(AgentMessageType.TASK_CREATE_UI);
        expect(uiPayload.dataTaskIds.length).assertEqual(1);
        expect(uiPayload.dataTaskIds[0]).assertEqual(dataTask.taskId);
        const actionRequest = await receive(observer);
        const actionPayload = actionRequest.payload as ActionPlanRequestPayload;
        expect(actionRequest.type).assertEqual(AgentMessageType.ACTION_PLAN_REQUEST);
        expect(actionPayload.uiTaskId).assertEqual(uiTask.taskId);
        expect(actionPayload.dataTaskIds.join(',')).assertEqual(uiPayload.dataTaskIds.join(','));
        expect(actionPayload.allowedActionIds[0]).assertEqual('hotel.navigate');
        bus.publish({
          type: AgentMessageType.TASK_RESULT_UI,
          conversationId: uiTask.conversationId,
          turnId: uiTask.turnId,
          taskId: uiTask.taskId,
          payload: { surfaceId: 'surface-fallback-error', state: 'result' } as UiRenderResultPayload
        });
        expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_UI);
        const terminal = await receive(observer);
        const payload = terminal.payload as TurnResultPayload;
        expect(terminal.type).assertEqual(AgentMessageType.TURN_RESULT);
        expect(payload.status).assertEqual('error');
        expect(payload.surfaceId).assertEqual('surface-fallback-error');
        expect(planner.calls).assertEqual(2);
      } finally {
        leader.stop();
        observer.close();
      }
    });

    it('renders a partial DataResult before a slow post-observation planner consumes the turn deadline', 2000, async () => {
      const firstDecision = semanticDecision([
        semanticDataTask('aggregate', 'media.aggregate.search')
      ]);
      firstDecision.actionIntent = {
        goal: 'Navigate after results',
        allowedActionIds: ['hotel.navigate']
      };
      firstDecision.requestedCapabilityIds.push('hotel.navigate');
      const planner = new ControlledPostObservationPlanner(firstDecision);
      const bus = new LinkedMessageBus();
      const leader = new LeaderAgent(bus, planner, aggregatePlanningContext(), 300);
      const observer = bus.openReader();
      leader.start();

      try {
        bus.publish(inputMessage());
        expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
        const dataTask = await receive(observer);
        expect(dataTask.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
        bus.publish(dataResultMessageWithStatus(dataTask, 'partial'));
        expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
        await planner.secondStarted.promise;
        const uiTask = await receive(observer);
        const uiPayload = uiTask.payload as CreateUiTaskPayload;

        expect(uiTask.type).assertEqual(AgentMessageType.TASK_CREATE_UI);
        expect(uiPayload.dataTaskIds.length).assertEqual(1);
        expect(uiPayload.dataTaskIds[0]).assertEqual(dataTask.taskId);
        const actionRequest = await receive(observer);
        const actionPayload = actionRequest.payload as ActionPlanRequestPayload;
        expect(actionRequest.type).assertEqual(AgentMessageType.ACTION_PLAN_REQUEST);
        expect(actionPayload.uiTaskId).assertEqual(uiTask.taskId);
        expect(actionPayload.dataTaskIds.join(',')).assertEqual(uiPayload.dataTaskIds.join(','));
        expect(actionPayload.allowedActionIds[0]).assertEqual('hotel.navigate');
        bus.publish({
          type: AgentMessageType.TASK_RESULT_UI,
          conversationId: uiTask.conversationId,
          turnId: uiTask.turnId,
          taskId: uiTask.taskId,
          payload: { surfaceId: 'surface-fallback-partial', state: 'result' } as UiRenderResultPayload
        });
        expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_UI);
        const terminal = await receive(observer);
        const payload = terminal.payload as TurnResultPayload;
        expect(terminal.type).assertEqual(AgentMessageType.TURN_RESULT);
        expect(payload.status).assertEqual('partial');
        expect(payload.surfaceId).assertEqual('surface-fallback-partial');

        planner.finishSecond(semanticDecision([
          semanticDataTask('late-repeat', 'media.aggregate.search')
        ]));
        await settle();
        bus.publish(terminalMessage(AgentMessageType.ACTION_RESULT, 'fallback-marker'));
        let replayed: number = 0;
        let observed = await receive(observer);
        while (observed.taskId !== 'fallback-marker') {
          if (observed.type === AgentMessageType.TASK_CREATE_DATA ||
            observed.type === AgentMessageType.TASK_CREATE_UI ||
            observed.type === AgentMessageType.ACTION_PLAN_REQUEST ||
            observed.type === AgentMessageType.TURN_RESULT) {
            replayed++;
          }
          observed = await receive(observer);
        }
        expect(replayed).assertEqual(0);
        expect(planner.calls).assertEqual(2);
      } finally {
        leader.stop();
        observer.close();
      }
    });

    it('delays one UI task until two dependent Data rounds are terminal', 0, async () => {
      const firstTask = semanticDataTask('place-search', 'maps.place.search');
      firstTask.input = JSON.parse('{"query":"深圳咖啡"}') as Object;
      const secondTask = semanticDataTask('place-details', 'maps.place.details');
      secondTask.input = JSON.parse('{"placeId":"entity-1"}') as Object;
      const planner = new RoundScriptedPlanner([
        semanticDecision([firstTask]),
        semanticDecision([secondTask]),
        semanticDecision([], 'answer')
      ]);
      const bus = new LinkedMessageBus();
      const leader = new LeaderAgent(bus, planner, dependentDataPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const firstData = await receive(observer);
      expect(firstData.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      bus.publish(dataResultMessage(firstData));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      const secondData = await receive(observer);
      expect(secondData.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      bus.publish(dataResultMessage(secondData));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      const uiTask = await receive(observer);
      expect(uiTask.type).assertEqual(AgentMessageType.TASK_CREATE_UI);
      const uiPayload = uiTask.payload as CreateUiTaskPayload;
      expect(uiPayload.dataTaskIds.join(',')).assertEqual(firstData.taskId + ',' + secondData.taskId);
      expect(uiTask.taskId).assertEqual('input-1:ui');

      bus.publish({
        type: AgentMessageType.TASK_RESULT_UI,
        conversationId: uiTask.conversationId,
        turnId: uiTask.turnId,
        taskId: uiTask.taskId,
        payload: { surfaceId: 'surface-two-rounds', state: 'result' } as UiRenderResultPayload
      });
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_UI);
      const terminal = await receive(observer);
      expect(terminal.type).assertEqual(AgentMessageType.TURN_RESULT);
      expect((terminal.payload as TurnResultPayload).surfaceId).assertEqual('surface-two-rounds');
      leader.stop();
      observer.close();
    });

    it('rejects an unbound different Data tool after input normalization and before publication', 0, async () => {
      const firstTask = semanticDataTask('place-search', 'maps.place.search');
      firstTask.input = JSON.parse('{"query":"深圳咖啡"}') as Object;
      const unbound = semanticDataTask('food', 'food.search');
      unbound.input = JSON.parse('{"query":"附近餐厅"}') as Object;
      const planner = new RoundScriptedPlanner([
        semanticDecision([firstTask]),
        semanticDecision([unbound])
      ]);
      const bus = new LinkedMessageBus();
      const leader = new LeaderAgent(bus, planner, dependentDataPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const firstData = await receive(observer);
      expect(firstData.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      bus.publish(dataResultMessage(firstData));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      const blocked = await receive(observer);

      expect(blocked.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect((blocked.payload as TaskErrorPayload).code).assertEqual('LEADER_UNBOUND_LATER_TOOL');
      leader.stop();
      observer.close();
    });

    it('authorizes a later Data task from its safe normalized real entity reference', 0, async () => {
      const firstTask = semanticDataTask('place-search', 'maps.place.search');
      firstTask.input = JSON.parse('{"query":"深圳咖啡"}') as Object;
      const secondTask = semanticDataTask('place-details', 'maps.place.details');
      secondTask.input = new Object();
      const planner = new RoundScriptedPlanner([
        withNormalizationDate(semanticDecision([firstTask])),
        withNormalizationDate(semanticDecision([secondTask]))
      ]);
      const normalizer: LeaderDataTaskInputNormalizer = (
        _input: InputUserPayload,
        task: LeaderDecisionDataTask
      ): Object => task.toolId === 'maps.place.details' ?
        JSON.parse('{"placeId":"entity-1","unused":{"placeId":"forged"}}') as Object : task.input;
      const bus = new LinkedMessageBus();
      const leader = new LeaderAgent(
        bus,
        planner,
        dependentDataPlanningContext(),
        30000,
        normalizer,
        undefined,
        fixedCurrentLocalDate
      );
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const firstData = await receive(observer);
      bus.publish(dataResultMessage(firstData));
      await receive(observer);
      const secondData = await receive(observer);
      const args = (secondData.payload as CreateDataTaskPayload).args as
        Record<string, string | Record<string, string>>;

      expect(secondData.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      expect(args['placeId'] as string).assertEqual('entity-1');
      bus.publish(terminalMessage(AgentMessageType.TURN_CANCEL, 'cancel-normalized'));
      await receive(observer);
      leader.stop();
      observer.close();
    });

    it('rejects alternate planners without valid normalization date authority before normalization', 0, async () => {
      const tools: string[] = [
        'hotel.search',
        'travel.search',
        'social.feed.search',
        'calendar.events.search'
      ];
      for (let dateIndex = 0; dateIndex < 2; dateIndex++) {
        const tasks: LeaderDecisionDataTask[] = [];
        for (let toolIndex = 0; toolIndex < tools.length; toolIndex++) {
          const task = semanticDataTask('authority-' + toolIndex.toString(), tools[toolIndex]);
          task.input = JSON.parse('{"forged":"model-value"}') as Object;
          tasks.push(task);
        }
        const decision = semanticDecision(tasks);
        if (dateIndex === 1) {
          decision.normalizationCurrentLocalDate = '2026-02-30';
        }
        let normalizeCalls: number = 0;
        const normalizer: LeaderDataTaskInputNormalizer = (
          _input: InputUserPayload,
          task: LeaderDecisionDataTask,
          _currentLocalDate: string
        ): Object => {
          normalizeCalls++;
          return task.input;
        };
        const bus = new LinkedMessageBus();
        const leader = new LeaderAgent(
          bus,
          new RoundScriptedPlanner([decision]),
          normalizationPlanningContext(),
          30000,
          normalizer,
          undefined,
          fixedCurrentLocalDate
        );
        const observer = bus.openReader();
        leader.start();

        bus.publish(inputMessage());
        expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
        const rejected = await receive(observer);

        expect(rejected.type).assertEqual(AgentMessageType.TASK_ERROR);
        expect((rejected.payload as TaskErrorPayload).code).assertEqual('LEADER_PLAN_INVALID');
        expect(normalizeCalls).assertEqual(0);
        leader.stop();
        observer.close();
      }
    });

    it('rejects a valid but forged planner date instead of treating it as host authority', 0, async () => {
      const task = semanticDataTask('hotel', 'hotel.search');
      task.input = JSON.parse('{"forged":"model-value"}') as Object;
      const decision = withNormalizationDate(semanticDecision([task]), '2027-01-01');
      let normalizeCalls: number = 0;
      const normalizer: LeaderDataTaskInputNormalizer = (
        _input: InputUserPayload,
        plannedTask: LeaderDecisionDataTask,
        _currentLocalDate: string
      ): Object => {
        normalizeCalls++;
        return plannedTask.input;
      };
      const bus = new LinkedMessageBus();
      const leader = new LeaderAgent(
        bus,
        new RoundScriptedPlanner([decision]),
        normalizationPlanningContext(),
        30000,
        normalizer,
        undefined,
        (): string => '2026-07-23'
      );
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const rejected = await receive(observer);

      expect(rejected.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect((rejected.payload as TaskErrorPayload).code).assertEqual('LEADER_PLAN_INVALID');
      expect(normalizeCalls).assertEqual(0);
      leader.stop();
      observer.close();
    });

    it('passes trusted date authority to every alternate-planner Data input normalizer', 0, async () => {
      const tools: string[] = [
        'hotel.search',
        'travel.search',
        'social.feed.search',
        'calendar.events.search'
      ];
      const tasks: LeaderDecisionDataTask[] = [];
      for (let index = 0; index < tools.length; index++) {
        const task = semanticDataTask('bound-' + index.toString(), tools[index]);
        task.input = JSON.parse('{"forged":"model-value"}') as Object;
        tasks.push(task);
      }
      const decision = withNormalizationDate(semanticDecision(tasks));
      const normalized: string[] = [];
      const normalizer: LeaderDataTaskInputNormalizer = (
        _input: InputUserPayload,
        task: LeaderDecisionDataTask,
        currentLocalDate: string
      ): Object => {
        normalized.push(task.toolId + '@' + currentLocalDate);
        return JSON.parse(
          '{"bound":"' + task.toolId + '@' + currentLocalDate + '"}'
        ) as Object;
      };
      const bus = new LinkedMessageBus();
      const leader = new LeaderAgent(
        bus,
        new RoundScriptedPlanner([decision]),
        normalizationPlanningContext(),
        30000,
        normalizer,
        undefined,
        fixedCurrentLocalDate
      );
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      for (let index = 0; index < tools.length; index++) {
        const dataMessage = await receive(observer);
        const payload = dataMessage.payload as CreateDataTaskPayload;
        const args = payload.args as Record<string, string>;
        expect(dataMessage.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
        expect(payload.toolId).assertEqual(tools[index]);
        expect(args['bound']).assertEqual(tools[index] + '@2026-07-20');
      }
      expect(normalized.join(',')).assertEqual(
        'hotel.search@2026-07-20,travel.search@2026-07-20,' +
        'social.feed.search@2026-07-20,calendar.events.search@2026-07-20'
      );
      leader.stop();
      observer.close();
    });

    it('rejects cyclic dangerous and over-depth normalized authority inputs', 0, async () => {
      const cyclic = new Object() as Record<string, Object>;
      cyclic['self'] = cyclic;
      const dangerous = JSON.parse('{"constructor":{"placeId":"entity-1"}}') as Object;
      let deepJson: string = '{"placeId":"entity-1"}';
      for (let index = 0; index < 14; index++) {
        deepJson = '{"next":' + deepJson + '}';
      }
      const deep = JSON.parse(deepJson) as Object;

      expect(await rejectionAfterNormalizedInput(cyclic as Object))
        .assertEqual('LEADER_UNBOUND_LATER_TOOL');
      expect(await rejectionAfterNormalizedInput(dangerous))
        .assertEqual('LEADER_UNBOUND_LATER_TOOL');
      expect(await rejectionAfterNormalizedInput(deep))
        .assertEqual('LEADER_UNBOUND_LATER_TOOL');
    });

    it('blocks a completed tool omitted from the bounded planner observations', 0, async () => {
      const bus = new LinkedMessageBus();
      const ids: string[] = [
        'travel.search',
        'train.search',
        'flight.search',
        'hotel.search',
        'food.search',
        'social.feed.search',
        'x.post.search',
        'maps.place.search'
      ];
      const firstRoundTasks: LeaderDecisionDataTask[] = ids.map(
        (toolId: string, index: number): LeaderDecisionDataTask =>
          semanticDataTask('tool-' + index.toString(), toolId)
      );
      const dependent = semanticDataTask('place-details', 'maps.place.details');
      dependent.input = JSON.parse('{"placeId":"entity-1"}') as Object;
      const planner = new RoundScriptedPlanner([
        semanticDecision(firstRoundTasks),
        semanticDecision([dependent]),
        semanticDecision([semanticDataTask('repeat-travel', 'travel.search')])
      ]);
      const leader = new LeaderAgent(bus, planner, dependentDataPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const tasks: AgentMessage[] = [];
      for (let index = 0; index < ids.length; index++) {
        const task: AgentMessage = await receive(observer);
        expect(task.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
        tasks.push(task);
      }
      for (let index = 0; index < tasks.length; index++) {
        bus.publish(dataResultMessage(tasks[index], 'result-' + index.toString()));
        expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      }
      const dependentTask = await receive(observer);
      expect(dependentTask.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      expect((dependentTask.payload as CreateDataTaskPayload).toolId)
        .assertEqual('maps.place.details');
      bus.publish(dataResultMessage(dependentTask, 'place-details'));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      const blocked: AgentMessage = await receive(observer);

      expect(planner.calls).assertEqual(3);
      expect(planner.inputs[2].recentObservations!.length).assertEqual(8);
      expect(planner.inputs[2].recentObservations!.some(
        (observation): boolean => observation.toolId === 'travel.search'
      )).assertFalse();
      expect(blocked.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect((blocked.payload as TaskErrorPayload).code).assertEqual('LEADER_COMPLETED_TOOL_REUSE');
      leader.stop();
      observer.close();
    });

    it('rejects a malicious oversized planner result and remains live for the next turn', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new RoundScriptedPlanner([
        semanticDecision(repeatedSemanticTasks(33)),
        semanticDecision([semanticDataTask('next-turn', 'travel.search')])
      ]);
      const leader = new LeaderAgent(bus, planner, nineDataPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const rejected = await receive(observer);
      expect(rejected.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect((rejected.payload as TaskErrorPayload).code).assertEqual('LEADER_DATA_TASK_LIMIT');

      bus.publish(inputMessage('conversation-hotel', 'turn-2', 'input-2', '继续查询'));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const next = await receive(observer);
      expect(next.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      expect((next.payload as CreateDataTaskPayload).toolId).assertEqual('travel.search');
      expect(planner.calls).assertEqual(2);
      leader.stop();
      observer.close();
    });

    it('publishes eight legal independent Data tasks in one round', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new RoundScriptedPlanner([
        semanticDecision(repeatedSemanticTasks(8))
      ]);
      const leader = new LeaderAgent(bus, planner, nineDataPlanningContext());
      const observer = bus.openReader();
      leader.start();

      expect(MAX_LEADER_DATA_TASKS_PER_ROUND).assertEqual(8);
      expect(MAX_LEADER_DATA_TASKS_PER_TURN).assertEqual(24);
      expect(MAX_LEADER_DATA_TASKS_PER_TURN <= 32).assertTrue();
      bus.publish(inputMessage());
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      for (let index = 0; index < 8; index++) {
        const task = await receive(observer);
        expect(task.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
        expect(task.taskId.indexOf(':round-1:travel-') >= 0).assertTrue();
      }
      expect(planner.calls).assertEqual(1);
      leader.stop();
      observer.close();
    });

    it('derives data-backed terminal status from only this turn observations', 0, async () => {
      expect(await semanticTerminalStatus(['error', 'error'])).assertEqual('error');
      expect(await semanticTerminalStatus(['error', 'empty'])).assertEqual('error');
      expect(await semanticTerminalStatus(['empty', 'error'])).assertEqual('error');
      expect(await semanticTerminalStatus(['success', 'error'])).assertEqual('partial');
      expect(await semanticTerminalStatus(['success', 'empty'])).assertEqual('partial');
      expect(await semanticTerminalStatus(['success', 'error', 'empty'])).assertEqual('partial');
      expect(await semanticTerminalStatus(['partial'])).assertEqual('partial');
      expect(await semanticTerminalStatus(['partial', 'error'])).assertEqual('partial');
      expect(await semanticTerminalStatus(['partial', 'empty'])).assertEqual('partial');
      expect(await semanticTerminalStatus(['empty', 'empty'])).assertEqual('empty');
      expect(await semanticTerminalStatus(['success', 'success'])).assertEqual('success');
    });

    it('turns malformed results and wrong schemas into bounded digests without stopping the pump', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new RoundScriptedPlanner([
        semanticDecision([
          semanticDataTask('malformed'),
          semanticDataTask('wrong-schema'),
          semanticDataTask('null-payload')
        ]),
        semanticDecision([], 'answer')
      ]);
      const leader = new LeaderAgent(bus, planner, semanticPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const malformedTask = await receive(observer);
      const wrongSchemaTask = await receive(observer);
      const nullPayloadTask = await receive(observer);
      const malformedPayload: Object = JSON.parse(
        '{"toolId":"hotel.search","outputSchema":"hotelSearchResults","status":"error",' +
        '"sources":[],"data":{},"warnings":[],"error":{}}'
      ) as Object;
      const wrongSchemaPayload: Object = JSON.parse(
        '{"toolId":"hotel.search","outputSchema":"wrongSchema","status":"success",' +
        '"sources":[],"data":{"summary":"must-not-be-trusted"},"warnings":[]}'
      ) as Object;
      bus.publish({
        type: AgentMessageType.TASK_RESULT_DATA,
        conversationId: malformedTask.conversationId,
        turnId: malformedTask.turnId,
        taskId: malformedTask.taskId,
        payload: malformedPayload
      });
      bus.publish({
        type: AgentMessageType.TASK_RESULT_DATA,
        conversationId: wrongSchemaTask.conversationId,
        turnId: wrongSchemaTask.turnId,
        taskId: wrongSchemaTask.taskId,
        payload: wrongSchemaPayload
      });
      bus.publish({
        type: AgentMessageType.TASK_RESULT_DATA,
        conversationId: nullPayloadTask.conversationId,
        turnId: nullPayloadTask.turnId,
        taskId: nullPayloadTask.taskId,
        payload: JSON.parse('null') as Object
      });
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      await settle();

      expect(planner.calls).assertEqual(2);
      expect(planner.inputs[1].recentObservations!.length).assertEqual(3);
      expect(planner.inputs[1].recentObservations![0].status).assertEqual('error');
      expect(planner.inputs[1].recentObservations![1].status).assertEqual('error');
      expect(planner.inputs[1].recentObservations![2].status).assertEqual('error');
      expect(planner.inputs[1].recentObservations![0].summary).assertEqual('Data task output was invalid');
      expect(planner.inputs[1].recentObservations![1].summary).assertEqual('Data task output was invalid');
      expect(planner.inputs[1].recentObservations![2].summary).assertEqual('Data task output was invalid');
      expect(JSON.stringify(planner.inputs[1]).indexOf('must-not-be-trusted')).assertEqual(-1);
      leader.stop();
      observer.close();
    });

    it('renders accumulated Data and its pending action after the third round without planning a fourth', 0, async () => {
      const bus = new LinkedMessageBus();
      const roundOneMaps = semanticDataTask('round-1-maps', 'maps.place.search');
      const roundOneMail = semanticDataTask('round-1-mail', 'mail.search');
      const roundTwo = semanticDataTask('round-2', 'maps.place.details');
      const roundThree = semanticDataTask('round-3', 'mail.thread.read');
      roundTwo.input = JSON.parse('{"placeId":"entity-1"}') as Object;
      roundThree.input = JSON.parse('{"provider":"gmail","requestKey":"gmail:entity-1",' +
        '"threadId":"entity-1","messageId":"entity-1"}') as Object;
      const firstDecision = semanticDecision([roundOneMaps, roundOneMail]);
      firstDecision.actionIntent = {
        goal: 'Navigate after results',
        allowedActionIds: ['hotel.navigate']
      };
      firstDecision.requestedCapabilityIds.push('hotel.navigate');
      const planner = new RoundScriptedPlanner([
        firstDecision,
        semanticDecision([roundTwo]),
        semanticDecision([roundThree])
      ]);
      const context = dependentDataPlanningContext();
      addHotelNavigateActionMetadata(context);
      const leader = new LeaderAgent(bus, planner, context);
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const firstTasks: AgentMessage[] = [await receive(observer), await receive(observer)];
      for (let index = 0; index < firstTasks.length; index++) {
        expect(firstTasks[index].type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
        expect((firstTasks[index].payload as CreateDataTaskPayload).roundId.indexOf('1') >= 0).assertTrue();
        const toolId: string = (firstTasks[index].payload as CreateDataTaskPayload).toolId;
        bus.publish(toolId === 'mail.search' ?
          dataResultMessageWithEntityRefs(
            firstTasks[index], 'round-1', ['gmail:entity-1', 'entity-1']
          ) : dataResultMessage(firstTasks[index], 'round-1'));
        expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      }
      for (let round = 2; round <= 3; round++) {
        const task: AgentMessage = await receive(observer);
        expect(task.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
        expect((task.payload as CreateDataTaskPayload).roundId.indexOf(round.toString()) >= 0).assertTrue();
        bus.publish(dataResultMessage(task, 'round-' + round.toString()));
        expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      }
      const uiTask = await receive(observer);
      const uiPayload = uiTask.payload as CreateUiTaskPayload;
      const actionRequest = await receive(observer);
      const actionPayload = actionRequest.payload as ActionPlanRequestPayload;

      expect(uiTask.type).assertEqual(AgentMessageType.TASK_CREATE_UI);
      expect(uiPayload.dataTaskIds.length).assertEqual(4);
      expect(actionRequest.type).assertEqual(AgentMessageType.ACTION_PLAN_REQUEST);
      expect(actionPayload.uiTaskId).assertEqual(uiTask.taskId);
      expect(actionPayload.dataTaskIds.join(',')).assertEqual(uiPayload.dataTaskIds.join(','));
      expect(actionPayload.allowedActionIds[0]).assertEqual('hotel.navigate');
      bus.publish({
        type: AgentMessageType.TASK_RESULT_UI,
        conversationId: uiTask.conversationId,
        turnId: uiTask.turnId,
        taskId: uiTask.taskId,
        payload: { surfaceId: 'surface-round-three', state: 'result' } as UiRenderResultPayload
      });
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_UI);
      const terminal = await receive(observer);
      expect(terminal.type).assertEqual(AgentMessageType.TURN_RESULT);
      expect((terminal.payload as TurnResultPayload).status).assertEqual('success');
      expect((terminal.payload as TurnResultPayload).surfaceId).assertEqual('surface-round-three');
      expect(planner.calls).assertEqual(3);
      leader.stop();
      observer.close();
    });

    it('cancels during post-observation planning without fallback or late replay', 1000, async () => {
      const planner = new ControlledPostObservationPlanner(
        semanticDecision([semanticDataTask('cancel-after-data')])
      );
      const bus = new LinkedMessageBus();
      const leader = new LeaderAgent(bus, planner, semanticPlanningContext(), 300);
      const observer = bus.openReader();
      leader.start();

      try {
        bus.publish(inputMessage());
        expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
        const dataTask = await receive(observer);
        expect(dataTask.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
        bus.publish(dataResultMessageWithStatus(dataTask, 'partial'));
        expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
        await planner.secondStarted.promise;
        bus.publish(terminalMessage(AgentMessageType.TURN_CANCEL, 'cancel-post-observation'));
        expect((await receive(observer)).type).assertEqual(AgentMessageType.TURN_CANCEL);

        planner.finishSecond(semanticDecision([], 'answer'));
        await settle();
        bus.publish(terminalMessage(AgentMessageType.ACTION_RESULT, 'cancel-fallback-marker'));
        let replayed: number = 0;
        let observed = await receive(observer);
        while (observed.taskId !== 'cancel-fallback-marker') {
          if (observed.type === AgentMessageType.TASK_CREATE_DATA ||
            observed.type === AgentMessageType.TASK_CREATE_UI ||
            observed.type === AgentMessageType.ACTION_PLAN_REQUEST ||
            observed.type === AgentMessageType.TURN_RESULT) {
            replayed++;
          }
          observed = await receive(observer);
        }
        expect(replayed).assertEqual(0);
        expect(planner.calls).assertEqual(2);
      } finally {
        leader.stop();
        observer.close();
      }
    });

    it('cancels a semantic turn before observations can trigger another round', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new RoundScriptedPlanner([
        semanticDecision([semanticDataTask('cancel')]),
        semanticDecision([semanticDataTask('must-not-run')])
      ]);
      const leader = new LeaderAgent(bus, planner, semanticPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const task = await receive(observer);
      expect(task.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      bus.publish(terminalMessage(AgentMessageType.TURN_CANCEL, 'cancel-semantic'));
      bus.publish(dataResultMessage(task));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TURN_CANCEL);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      await settle();

      expect(planner.calls).assertEqual(1);
      leader.stop();
      observer.close();
    });

    it('times out a semantic turn waiting for observations', 1000, async () => {
      const bus = new LinkedMessageBus();
      const planner = new RoundScriptedPlanner([
        semanticDecision([semanticDataTask('timeout')])
      ]);
      const leader = new LeaderAgent(bus, planner, semanticPlanningContext(), 10);
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      const timeout = await receive(observer);

      expect(timeout.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect((timeout.payload as TaskErrorPayload).code).assertEqual('LEADER_TURN_TIMEOUT');
      expect(planner.calls).assertEqual(1);
      leader.stop();
      observer.close();
    });

    it('rejects a skill owned by a different persona', 0, async () => {
      const plan = hotelPlan();
      plan.personaId = 'work_companion';
      plan.skillId = 'food-search';
      const bus = new LinkedMessageBus();
      const leader = new LeaderAgent(bus, new ScriptedLeaderPlanner(plan), realPersonaPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const error = await receive(observer);

      expect(error.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect((error.payload as TaskErrorPayload).code).assertEqual('LEADER_PLAN_INVALID');
      leader.stop();
      observer.close();
    });

    it('rejects a non-empty skill without a selected persona', 0, async () => {
      const plan = hotelPlan();
      plan.skillId = 'food-search';
      const bus = new LinkedMessageBus();
      const leader = new LeaderAgent(bus, new ScriptedLeaderPlanner(plan), realPersonaPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const error = await receive(observer);

      expect(error.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect((error.payload as TaskErrorPayload).code).assertEqual('LEADER_PLAN_INVALID');
      leader.stop();
      observer.close();
    });

    it('accepts matching work persona skill for explicit work wording', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new RoutedPersonaPlanner();
      const leader = new LeaderAgent(bus, planner, realPersonaPlanningContext());
      const observer = bus.openReader();
      leader.start();
      const payload: InputUserPayload = {
        text: '用工作分身',
        previousPersonaId: 'food_companion'
      };
      const workMessage: AgentMessage = {
        type: AgentMessageType.INPUT_USER,
        conversationId: 'conversation-work',
        turnId: 'turn-work',
        taskId: 'input-work',
        payload: payload
      };
      bus.publish(workMessage);
      await receive(observer);
      const ui = await receive(observer);
      const data = await receive(observer);
      const plan = planner.lastPlan as LeaderPlan;
      const context = planner.lastContext as LeaderPlanningContext;
      const input = planner.lastInput as InputUserPayload;
      const selected = context.personas.filter((item): boolean => item.personaId === plan.personaId)[0];
      const controlInput: InputUserPayload = { text: '点一杯咖啡' };
      const controlPlan = await new RoutedPersonaPlanner().plan(
        inputMessage('conversation-food', 'turn-food', 'input-food', controlInput.text),
        controlInput,
        context
      );

      expect(input.text).assertEqual('用工作分身');
      expect(input.previousPersonaId).assertEqual('food_companion');
      expect(plan.personaId).assertEqual('work_companion');
      expect(selected.activeSkills[0].skillId).assertEqual(plan.skillId);
      expect((ui.payload as CreateUiTaskPayload).skillId).assertEqual(plan.skillId);
      expect((data.payload as CreateDataTaskPayload).skillId).assertEqual(plan.skillId);
      expect(controlPlan.personaId).assertEqual('food_companion');
      expect(controlPlan.personaId === plan.personaId).assertFalse();
      leader.stop();
      observer.close();
    });

    it('rejects a plan whose UI expected schema does not match its Data output schema', 0, async () => {
      const plan: LeaderPlan = hotelPlan();
      plan.ui.expectedOutputSchema = 'differentSchema';
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const leader: LeaderAgent = new LeaderAgent(bus, new ScriptedLeaderPlanner(plan), planningContext());
      const observer: AgentMessageReader = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const errorMessage: AgentMessage = await receive(observer);

      expect(errorMessage.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect((errorMessage.payload as TaskErrorPayload).code).assertEqual('LEADER_PLAN_INVALID');
      leader.stop();
      observer.close();
    });

    it('publishes one correlated error when planning throws', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const leader: LeaderAgent = new LeaderAgent(bus, new ThrowingLeaderPlanner(), planningContext());
      const observer: AgentMessageReader = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const errorMessage: AgentMessage = await receive(observer);
      const error: TaskErrorPayload = errorMessage.payload as TaskErrorPayload;
      expect(errorMessage.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect(errorMessage.conversationId).assertEqual('conversation-hotel');
      expect(errorMessage.turnId).assertEqual('turn-1');
      expect(errorMessage.taskId).assertEqual('input-1');
      expect(error.code).assertEqual('LEADER_PLAN_FAILED');
      expect(error.message).assertEqual('planner unavailable');

      bus.publish(terminalMessage(AgentMessageType.TURN_CANCEL, 'cancel-1'));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TURN_CANCEL);
      leader.stop();
      observer.close();
    });

    it('rejects malformed text without stopping the next valid input', 1000, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const planner: ScriptedLeaderPlanner = new ScriptedLeaderPlanner(hotelPlan());
      const leader: LeaderAgent = new LeaderAgent(bus, planner, planningContext());
      const observer: AgentMessageReader = bus.openReader();
      leader.start();

      bus.publish(inputMessage('', '', '', 'hotel'));
      bus.publish({
        type: AgentMessageType.INPUT_USER,
        conversationId: 'conversation-invalid',
        turnId: 'turn-invalid',
        taskId: 'input-invalid',
        payload: JSON.parse('{"text":42}') as Object
      });
      bus.publish(inputMessage());
      await receive(observer);
      await receive(observer);
      await receive(observer);
      const validationError: AgentMessage = await receive(observer);
      const uiMessage: AgentMessage = await receive(observer);
      const dataMessage: AgentMessage = await receive(observer);

      expect(validationError.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect(validationError.conversationId).assertEqual('conversation-invalid');
      expect(validationError.turnId).assertEqual('turn-invalid');
      expect(validationError.taskId).assertEqual('input-invalid');
      expect((validationError.payload as TaskErrorPayload).code).assertEqual('LEADER_INPUT_INVALID');
      expect(uiMessage.type).assertEqual(AgentMessageType.TASK_CREATE_UI);
      expect(dataMessage.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      expect(planner.calls).assertEqual(1);

      leader.stop();
      observer.close();
    });

    it('bounds planner latency and processes the next input after timeout', 1000, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const planner: FirstCallHangingPlanner = new FirstCallHangingPlanner(hotelPlan('ui-2', 'data-2'));
      const leader: LeaderAgent = new LeaderAgent(bus, planner, planningContext(), 10);
      const observer: AgentMessageReader = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const timeoutError: AgentMessage = await receive(observer);
      expect(timeoutError.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect(timeoutError.conversationId).assertEqual('conversation-hotel');
      expect(timeoutError.turnId).assertEqual('turn-1');
      expect(timeoutError.taskId).assertEqual('input-1');
      expect((timeoutError.payload as TaskErrorPayload).code).assertEqual('LEADER_TURN_TIMEOUT');

      bus.publish(inputMessage('conversation-hotel', 'turn-2', 'input-2'));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const nextUi: AgentMessage = await receive(observer);
      const nextData: AgentMessage = await receive(observer);
      expect(nextUi.type).assertEqual(AgentMessageType.TASK_CREATE_UI);
      expect(nextData.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      expect(nextUi.turnId).assertEqual('turn-2');
      expect(nextData.turnId).assertEqual('turn-2');
      expect(planner.calls).assertEqual(2);

      leader.stop();
      observer.close();
    });

    it('cancels an in-flight planner before timeout and keeps the pump available', 1000, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const planner: ControlledFirstPlanner = new ControlledFirstPlanner(hotelPlan('ui-2', 'data-2'));
      const leader: LeaderAgent = new LeaderAgent(bus, planner, planningContext(), 200);
      const observer: AgentMessageReader = bus.openReader();
      leader.start();

      try {
        bus.publish(inputMessage());
        await receive(observer);
        await planner.firstStarted.promise;
        bus.publish(terminalMessage(AgentMessageType.TURN_CANCEL, 'cancel-1'));
        bus.publish(inputMessage('conversation-hotel', 'turn-2', 'input-2'));
        expect((await receive(observer)).type).assertEqual(AgentMessageType.TURN_CANCEL);
        expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
        const nextUi: AgentMessage = await receive(observer);
        const nextData: AgentMessage = await receive(observer);
        expect(nextUi.type).assertEqual(AgentMessageType.TASK_CREATE_UI);
        expect(nextData.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
        expect(nextUi.turnId).assertEqual('turn-2');
        expect(nextData.turnId).assertEqual('turn-2');

        bus.publish(terminalMessage(AgentMessageType.TASK_RESULT_UI, 'ui-2', 'turn-2'));
        bus.publish(terminalMessage(AgentMessageType.TASK_RESULT_DATA, 'data-2', 'turn-2'));
        expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_UI);
        expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
        planner.finishFirst(hotelPlan('ui-late', 'data-late'));
        setTimeout(() => {
          bus.publish(terminalMessage(AgentMessageType.ACTION_RESULT, 'observer-marker'));
        }, 250);
        expect((await receive(observer)).taskId).assertEqual('observer-marker');
        expect(planner.calls).assertEqual(2);
      } finally {
        leader.stop();
        observer.close();
      }
    });

    it('does not start schema repair after cancel timeout or stop', 1000, async () => {
      expect(await repairCallsAfterTerminal('cancel')).assertEqual(1);
      expect(await repairCallsAfterTerminal('timeout')).assertEqual(1);
      expect(await repairCallsAfterTerminal('stop')).assertEqual(1);
    });

    it('times out once and ignores late UI and Data results', 1000, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const leader: LeaderAgent = new LeaderAgent(
        bus,
        new ScriptedLeaderPlanner(hotelPlan()),
        planningContext(),
        10
      );
      const observer: AgentMessageReader = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      await receive(observer);
      await receive(observer);
      const timeoutError: AgentMessage = await receive(observer);
      expect(timeoutError.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect(timeoutError.conversationId).assertEqual('conversation-hotel');
      expect(timeoutError.turnId).assertEqual('turn-1');
      expect(timeoutError.taskId).assertEqual('input-1');
      expect((timeoutError.payload as TaskErrorPayload).code).assertEqual('LEADER_TURN_TIMEOUT');

      bus.publish(terminalMessage(AgentMessageType.TASK_RESULT_UI, 'ui-1'));
      bus.publish(terminalMessage(AgentMessageType.TASK_RESULT_DATA, 'data-1'));
      bus.publish(inputMessage('conversation-hotel', 'turn-2', 'input-2'));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_UI);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const nextUi: AgentMessage = await receive(observer);
      const nextData: AgentMessage = await receive(observer);
      expect(nextUi.type).assertEqual(AgentMessageType.TASK_CREATE_UI);
      expect(nextData.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      expect(nextUi.turnId).assertEqual('turn-2');
      expect(nextData.turnId).assertEqual('turn-2');

      leader.stop();
      observer.close();
    });

    it('keeps a canceled turn terminal when late results arrive', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const leader: LeaderAgent = new LeaderAgent(
        bus,
        new ScriptedLeaderPlanner(hotelPlan()),
        planningContext()
      );
      const observer: AgentMessageReader = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      await receive(observer);
      await receive(observer);
      bus.publish(terminalMessage(AgentMessageType.TURN_CANCEL, 'cancel-1'));
      bus.publish(terminalMessage(AgentMessageType.TASK_RESULT_UI, 'ui-1'));
      bus.publish(terminalMessage(AgentMessageType.TASK_RESULT_DATA, 'data-1'));
      bus.publish(inputMessage('conversation-hotel', 'turn-2', 'input-2'));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TURN_CANCEL);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_UI);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.INPUT_USER);
      const nextUi: AgentMessage = await receive(observer);
      const nextData: AgentMessage = await receive(observer);
      expect(nextUi.type).assertEqual(AgentMessageType.TASK_CREATE_UI);
      expect(nextData.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      expect(nextUi.turnId).assertEqual('turn-2');
      expect(nextData.turnId).assertEqual('turn-2');

      leader.stop();
      observer.close();
    });

    it('ignores Action results and downstream errors with the wrong task id', 1000, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const leader: LeaderAgent = new LeaderAgent(
        bus,
        new ScriptedLeaderPlanner(hotelPlan()),
        planningContext(),
        10
      );
      const observer: AgentMessageReader = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      await receive(observer);
      await receive(observer);
      bus.publish(terminalMessage(AgentMessageType.TASK_RESULT_UI, 'ui-1'));
      bus.publish(terminalMessage(AgentMessageType.ACTION_RESULT, 'input-1'));
      bus.publish(terminalMessage(AgentMessageType.TASK_ERROR, 'data-for-another-turn'));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_UI);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.ACTION_RESULT);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_ERROR);
      const timeoutError: AgentMessage = await receive(observer);

      expect(timeoutError.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect(timeoutError.taskId).assertEqual('input-1');
      expect((timeoutError.payload as TaskErrorPayload).code).assertEqual('LEADER_TURN_TIMEOUT');
      leader.stop();
      observer.close();
    });

    it('treats a matching downstream error as terminal for only that task', 1000, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const leader: LeaderAgent = new LeaderAgent(
        bus,
        new ScriptedLeaderPlanner(hotelPlan()),
        planningContext(),
        10
      );
      const observer: AgentMessageReader = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      await receive(observer);
      await receive(observer);
      bus.publish(terminalMessage(AgentMessageType.TASK_RESULT_UI, 'ui-1'));
      bus.publish(terminalMessage(AgentMessageType.TASK_ERROR, 'data-1'));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_UI);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_ERROR);
      setTimeout(() => {
        bus.publish(terminalMessage(AgentMessageType.ACTION_RESULT, 'observer-marker'));
      }, 30);
      expect((await receive(observer)).taskId).assertEqual('observer-marker');

      leader.stop();
      observer.close();
    });

    it('keeps normal completion terminal when a late result arrives', 1000, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const leader: LeaderAgent = new LeaderAgent(
        bus,
        new ScriptedLeaderPlanner(hotelPlan()),
        planningContext(),
        10
      );
      const observer: AgentMessageReader = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      await receive(observer);
      await receive(observer);
      bus.publish(terminalMessage(AgentMessageType.TASK_RESULT_UI, 'ui-1'));
      bus.publish(terminalMessage(AgentMessageType.TASK_RESULT_DATA, 'data-1'));
      bus.publish(terminalMessage(AgentMessageType.TASK_RESULT_DATA, 'data-1'));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_UI);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      setTimeout(() => {
        bus.publish(terminalMessage(AgentMessageType.ACTION_RESULT, 'observer-marker'));
      }, 30);
      expect((await receive(observer)).taskId).assertEqual('observer-marker');

      leader.stop();
      observer.close();
    });

    it('retains exact terminal turn identities during a long conversation', 1000, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const planner: ScriptedLeaderPlanner = new ScriptedLeaderPlanner(hotelPlan());
      const leader: LeaderAgent = new LeaderAgent(bus, planner, planningContext());
      const observer: AgentMessageReader = bus.openReader();
      leader.start();

      for (let index = 0; index < 129; index++) {
        const turnId: string = `capacity-turn-${index}`;
        bus.publish(inputMessage('conversation-hotel', turnId, `input-${index}`));
        await receive(observer);
        await receive(observer);
        await receive(observer);
        bus.publish(terminalMessage(AgentMessageType.TASK_RESULT_UI, 'ui-1', turnId));
        bus.publish(terminalMessage(AgentMessageType.TASK_RESULT_DATA, 'data-1', turnId));
        await receive(observer);
        await receive(observer);
      }

      bus.publish(inputMessage('conversation-hotel', 'capacity-turn-0', 'input-0'));
      await receive(observer);
      await settle();
      bus.publish(terminalMessage(AgentMessageType.ACTION_RESULT, 'capacity-marker', 'marker-turn'));
      let createdTasks: number = 0;
      let observed: AgentMessage = await receive(observer);
      while (observed.taskId !== 'capacity-marker') {
        if (observed.type === AgentMessageType.TASK_CREATE_UI ||
          observed.type === AgentMessageType.TASK_CREATE_DATA) {
          createdTasks++;
        }
        observed = await receive(observer);
      }

      expect(planner.calls).assertEqual(129);
      expect(createdTasks).assertEqual(0);
      leader.stop();
      observer.close();
    });
  });
}
