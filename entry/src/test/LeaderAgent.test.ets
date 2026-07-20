import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  InputUserPayload,
  LeaderAgent,
  LeaderDataTask,
  LeaderPlan,
  LeaderPlanner,
  LeaderUiTask,
  LinkedMessageBus,
  TaskErrorPayload
} from '@loop/agent-core';

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

  async plan(_message: AgentMessage, _input: InputUserPayload): Promise<LeaderPlan> {
    this.calls++;
    return this.scriptedPlan;
  }
}

class ThrowingLeaderPlanner implements LeaderPlanner {
  async plan(_message: AgentMessage, _input: InputUserPayload): Promise<LeaderPlan> {
    throw new Error('planner unavailable');
  }
}

class FirstCallHangingPlanner implements LeaderPlanner {
  calls: number = 0;
  private readonly scriptedPlan: LeaderPlan;

  constructor(scriptedPlan: LeaderPlan) {
    this.scriptedPlan = scriptedPlan;
  }

  async plan(_message: AgentMessage, _input: InputUserPayload): Promise<LeaderPlan> {
    this.calls++;
    if (this.calls === 1) {
      return new Promise<LeaderPlan>((_resolve: (plan: LeaderPlan) => void) => {
      });
    }
    return this.scriptedPlan;
  }
}

function hotelPlan(uiTaskId: string = 'ui-1', dataTaskId: string = 'data-1'): LeaderPlan {
  const ui: LeaderUiTask = {
    taskId: uiTaskId,
    intent: 'Show a hotel search surface',
    expectedOutputSchema: 'hotelSearchSurface'
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
  return { ui, data };
}

function hotelPlanWithUnexpectedFields(): LeaderPlan {
  const uiObject: Object = JSON.parse(
    '{"taskId":"ui-1","intent":"Show a hotel search surface","expectedOutputSchema":"hotelSearchSurface",' +
      '"providerOutput":{"secret":"must-not-leak"},"jsonl":"{\\"createSurface\\":true}"}'
  ) as Object;
  const dataObject: Object = JSON.parse(
    '{"taskId":"data-1","toolId":"hotel.search","outputSchema":"hotelSearchResults",' +
      '"args":{"city":"Shenzhen","checkIn":"2026-07-21","checkOut":"2026-07-22","guests":2},' +
      '"providerOutput":{"secret":"must-not-leak"},"jsonl":"forbidden"}'
  ) as Object;
  return {
    ui: uiObject as LeaderUiTask,
    data: dataObject as LeaderDataTask
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

async function receive(reader: AgentMessageReader): Promise<AgentMessage> {
  const message: AgentMessage | null = await reader.receive();
  if (message === null) {
    throw new Error('observer closed before receiving a message');
  }
  return message;
}

export default function leaderAgentTest() {
  describe('leaderAgent', () => {
    it('publishes sanitized correlated UI then Data tasks and no fourth output', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const leader: LeaderAgent = new LeaderAgent(bus, new ScriptedLeaderPlanner(hotelPlanWithUnexpectedFields()));
      const observer: AgentMessageReader = bus.openReader();
      leader.start();

      bus.publish(inputMessage());
      await receive(observer);
      const uiMessage: AgentMessage = await receive(observer);
      const dataMessage: AgentMessage = await receive(observer);
      const ui: LeaderUiTask = uiMessage.payload as LeaderUiTask;
      const data: LeaderDataTask = dataMessage.payload as LeaderDataTask;
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
      expect(data.taskId).assertEqual(dataMessage.taskId);
      expect(data.toolId).assertEqual('hotel.search');
      expect(data.outputSchema).assertEqual('hotelSearchResults');
      expect(args.city).assertEqual('Shenzhen');
      expect(args.guests).assertEqual(2);
      expect(Object.keys(ui).sort().join(',')).assertEqual('expectedOutputSchema,intent,taskId');
      expect(Object.keys(data).sort().join(',')).assertEqual('args,outputSchema,taskId,toolId');
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

    it('publishes one correlated error when planning throws', 0, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const leader: LeaderAgent = new LeaderAgent(bus, new ThrowingLeaderPlanner());
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
      const leader: LeaderAgent = new LeaderAgent(bus, planner);
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
      const leader: LeaderAgent = new LeaderAgent(bus, planner, 10);
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

    it('times out once and ignores late UI and Data results', 1000, async () => {
      const bus: LinkedMessageBus = new LinkedMessageBus();
      const leader: LeaderAgent = new LeaderAgent(bus, new ScriptedLeaderPlanner(hotelPlan()), 10);
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
      const leader: LeaderAgent = new LeaderAgent(bus, new ScriptedLeaderPlanner(hotelPlan()));
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
      const leader: LeaderAgent = new LeaderAgent(bus, new ScriptedLeaderPlanner(hotelPlan()), 10);
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
      const leader: LeaderAgent = new LeaderAgent(bus, new ScriptedLeaderPlanner(hotelPlan()), 10);
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
      const leader: LeaderAgent = new LeaderAgent(bus, new ScriptedLeaderPlanner(hotelPlan()), 10);
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
  });
}
