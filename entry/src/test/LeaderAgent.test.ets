import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  CreateDataTaskPayload,
  CreateUiTaskPayload,
  DataResult,
  InputUserPayload,
  LeaderAgent,
  LeaderDataTask,
  LeaderDecision,
  LeaderDecisionDataTask,
  LeaderPlan,
  LeaderPlanner,
  LeaderPlanningContext,
  LeaderUiTask,
  LinkedMessageBus,
  TaskErrorPayload
} from '@loop/agent-core';
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
  const decision: LeaderDecision = {
    personaId: 'travel_companion',
    skillId: '',
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

function planningContext(): LeaderPlanningContext {
  return {
    tools: [{
      toolId: 'hotel.search',
      intent: 'hotel.search',
      riskLevel: 'read',
      inputSchema: 'hotelSearchRequest',
      outputSchema: 'hotelSearchResults',
      actions: ['hotel.detail', 'hotel.navigate', 'hotel.book.external']
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

function hotelPlanWithUnexpectedFields(): LeaderPlan {
  const uiObject: Object = JSON.parse(
    '{"taskId":"ui-1","intent":"Show a hotel search surface","expectedOutputSchema":"hotelSearchResults",' +
      '"providerOutput":{"secret":"must-not-leak"},"jsonl":"{\\"createSurface\\":true}"}'
  ) as Object;
  const dataObject: Object = JSON.parse(
    '{"taskId":"data-1","toolId":"hotel.search","outputSchema":"hotelSearchResults",' +
      '"args":{"city":"Shenzhen","checkIn":"2026-07-21","checkOut":"2026-07-22","guests":2},' +
      '"providerOutput":{"secret":"must-not-leak"},"jsonl":"forbidden"}'
  ) as Object;
  return {
    personaId: '',
    skillId: '',
    roundAction: 'execute',
    ui: uiObject as LeaderUiTask,
    dataTasks: [dataObject as LeaderDataTask],
    reasonCode: 'hotel_search'
  };
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

export default function leaderAgentTest() {
  describe('leaderAgent', () => {
    it('publishes sanitized correlated UI then Data tasks and no fourth output', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const leader: LeaderAgent = new LeaderAgent(
        bus,
        new ScriptedLeaderPlanner(hotelPlanWithUnexpectedFields()),
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

    it('publishes every independent semantic Data task before observing results', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new RoundScriptedPlanner([
        semanticDecision([semanticDataTask('flight'), semanticDataTask('train')])
      ]);
      const leader = new LeaderAgent(bus, planner, semanticPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const first = await receive(observer);
      const second = await receive(observer);
      const firstPayload = first.payload as CreateDataTaskPayload;
      const secondPayload = second.payload as CreateDataTaskPayload;

      expect(first.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      expect(second.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
      expect(first.taskId === second.taskId).assertFalse();
      expect(firstPayload.roundId).assertEqual(secondPayload.roundId);
      expect(firstPayload.goal).assertEqual('Read real data for flight');
      expect(secondPayload.goal).assertEqual('Read real data for train');
      expect(planner.calls).assertEqual(1);

      bus.publish(terminalMessage(AgentMessageType.TURN_CANCEL, 'cancel-parallel'));
      expect((await receive(observer)).type).assertEqual(AgentMessageType.TURN_CANCEL);
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

    it('rejects planning a fourth semantic round without publishing another task', 0, async () => {
      const bus = new LinkedMessageBus();
      const planner = new RoundScriptedPlanner([
        semanticDecision([semanticDataTask('round-1')]),
        semanticDecision([semanticDataTask('round-2')]),
        semanticDecision([semanticDataTask('round-3')])
      ]);
      const leader = new LeaderAgent(bus, planner, semanticPlanningContext());
      const observer = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      for (let round = 1; round <= 3; round++) {
        const task = await receive(observer);
        expect(task.type).assertEqual(AgentMessageType.TASK_CREATE_DATA);
        expect((task.payload as CreateDataTaskPayload).roundId.indexOf(round.toString()) >= 0).assertTrue();
        bus.publish(dataResultMessage(task, 'round-' + round.toString()));
        expect((await receive(observer)).type).assertEqual(AgentMessageType.TASK_RESULT_DATA);
      }
      const limit = await receive(observer);

      expect(limit.type).assertEqual(AgentMessageType.TASK_ERROR);
      expect((limit.payload as TaskErrorPayload).code).assertEqual('LEADER_ROUND_LIMIT');
      expect(planner.calls).assertEqual(3);
      leader.stop();
      observer.close();
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
