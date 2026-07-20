import { describe, expect, it } from '@ohos/hypium';
import {
  ActionAgent,
  ActionArgsValidator,
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionFollowUp,
  ActionPlan,
  ActionPlanCreatePayload,
  ActionPlanReadyPayload,
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
  JsonValue,
  LinkedMessageBus,
  PausedActionRun,
  RegisteredActionExecutor,
  SurfaceActionAuthorizer,
  ToolDefinition,
  ToolDefinitionLookup,
  ToolRiskLevel,
  WorkflowRunArgs
} from '@loop/agent-core';

type JsonRecord = Record<string, JsonValue | undefined>;

class ActionLookup implements ToolDefinitionLookup {
  confirmCall: boolean = false;
  calls: number = 0;

  find(toolId: string): ToolDefinition | null {
    this.calls++;
    if (toolId === 'hotel.search') {
      return definition(toolId, 'read', ['hotel.detail', 'hotel.navigate', 'hotel.call']);
    }
    if (toolId === 'hotel.detail') {
      return definition(toolId, 'read', []);
    }
    if (toolId === 'hotel.navigate') {
      const navigate = definition(toolId, 'draft', []);
      navigate.backendPriority = ['system_intent'];
      navigate.authModes = ['system'];
      return navigate;
    }
    if (toolId === 'hotel.call') {
      return definition(toolId, this.confirmCall ? 'confirm_required' : 'draft', []);
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
    if (!this.allowed ||
      conversationId !== 'conversation-1' ||
      turnId !== 'turn-1' ||
      surfaceId !== 'surface-1') {
      return false;
    }
    if (actionId === 'hotel.detail') {
      return JSON.stringify(args) === '{"hotelId":101}';
    }
    if (actionId === 'hotel.navigate') {
      return JSON.stringify(args) === '{"hotelId":101,"latitude":22.5,"longitude":114}';
    }
    if (actionId === 'hotel.call') {
      return JSON.stringify(args) === '{"hotelId":101,"phone":"+8675588888888"}';
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

class RecordingRegisteredExecutor implements RegisteredActionExecutor {
  readonly actionIds: string[] = [];
  readonly serializedArgs: string[] = [];
  readonly contexts: string[] = [];
  results: ActionExecutionResult[] = [];
  gate: TestGate | null = null;

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
    if (gate !== null) {
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

function compositePlan(planId: string = 'plan-1'): ActionPlan {
  return JSON.parse(
    `{"planId":"${planId}","turnId":"turn-1","surfaceId":"surface-1",` +
      '"label":"Open detail then navigate","steps":[' +
      '{"stepId":"detail","actionId":"hotel.detail","args":{"hotelId":101}},' +
      '{"stepId":"navigate","actionId":"hotel.navigate",' +
      '"args":{"hotelId":101,"latitude":22.5,"longitude":114}}]}'
  ) as ActionPlan;
}

function planCreate(runId: string, candidate: ActionPlan): ActionPlanCreatePayload {
  return {
    runId,
    sourceToolId: 'hotel.search',
    plan: candidate
  };
}

function message(
  type: AgentMessageType,
  payload: Object,
  turnId: string = 'turn-1',
  taskId: string = 'action-task-1'
): AgentMessage {
  return {
    type,
    conversationId: 'conversation-1',
    turnId,
    taskId,
    payload
  };
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
  args: Object
): ActionRunPayload {
  return {
    surfaceId: 'surface-1',
    runId,
    sourceToolId: 'hotel.search',
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
  await Promise.resolve();
  await Promise.resolve();
}

export default function actionAgentTest() {
  describe('actionAgent', () => {
    it('publishes ready only after preflight and returns a correlated invalid-plan error', 0, async () => {
      const bus = new LinkedMessageBus();
      const lookup = new ActionLookup();
      const executor = new RecordingRegisteredExecutor();
      const agent = new ActionAgent(bus, catalog(lookup), executor);
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_PLAN_CREATE,
        planCreate('run-ready', compositePlan())
      ));
      const readyMessage = await receiveType(observer, AgentMessageType.ACTION_PLAN_READY);
      const ready = readyMessage.payload as ActionPlanReadyPayload;

      expect(lookup.calls > 0).assertTrue();
      expect(ready.planId).assertEqual('plan-1');
      expect(ready.runId).assertEqual('run-ready');
      expect(ready.surfaceId).assertEqual('surface-1');
      expect(ready.actionId).assertEqual('workflow.run');
      expect(Object.keys(ready.args).sort().join(',')).assertEqual('planId,runId');

      const invalid = compositePlan('plan-invalid');
      (invalid.steps[0].args as JsonRecord)['eval'] = 'payload is data, never code';
      bus.publish(message(
        AgentMessageType.ACTION_PLAN_CREATE,
        planCreate('run-invalid', invalid),
        'turn-1',
        'create-invalid'
      ));
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
      const agent = new ActionAgent(bus, catalog(new ActionLookup()), executor);
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_PLAN_CREATE,
        planCreate('run-tamper', compositePlan())
      ));
      const ready = (await receiveType(
        observer,
        AgentMessageType.ACTION_PLAN_READY
      )).payload as ActionPlanReadyPayload;
      const tampered = workflowRun(ready) as Object as JsonRecord;
      tampered['steps'] = JSON.parse(
        '[{"stepId":"bad","actionId":"hotel.call","args":{"phone":"attacker"}}]'
      ) as Object;
      bus.publish(message(AgentMessageType.ACTION_RUN, tampered as Object));
      const rejected = (await receiveType(
        observer,
        AgentMessageType.ACTION_RESULT
      )).payload as ActionResultPayload;

      expect(rejected.status).assertEqual('error');
      expect(executor.actionIds.length).assertEqual(0);

      bus.publish(message(
        AgentMessageType.ACTION_PLAN_CREATE,
        planCreate('run-exact', compositePlan('plan-exact'))
      ));
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
      const agent = new ActionAgent(bus, catalog(lookup), executor);
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun(
          'run-confirm',
          'hotel.call',
          JSON.parse('{"hotelId":101,"phone":"+8675588888888"}') as Object
        )
      ));
      const pausedMessage = await receiveType(observer, AgentMessageType.ACTION_RESULT);
      const pausedResult = pausedMessage.payload as ActionResultPayload;
      const paused: PausedActionRun | null = agent.inspectPausedRun('run-confirm');

      expect(pausedResult.status).assertEqual('paused');
      expect(pausedResult.stepId).assertEqual('step-1');
      expect(executor.actionIds.length).assertEqual(0);
      expect(paused === null).assertFalse();
      expect(Object.keys(paused as PausedActionRun).sort().join(',')).assertEqual(
        'context,nextStepIndex,outputs,plan,planId,runId,stepId'
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
      expect(executor.actionIds.join(',')).assertEqual('hotel.call');

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
      const agent = new ActionAgent(bus, catalog(lookup, surface, validator), executor);
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun(
          'run-reauthorize',
          'hotel.call',
          JSON.parse('{"hotelId":101,"phone":"+8675588888888"}') as Object
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
      const agent = new ActionAgent(bus, catalog(lookup), executor);
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_RUN,
        directRun(
          'run-paused-cancel',
          'hotel.call',
          JSON.parse('{"hotelId":101,"phone":"+8675588888888"}') as Object
        )
      ));
      await receiveType(observer, AgentMessageType.ACTION_RESULT);
      bus.publish(message(
        AgentMessageType.ACTION_PLAN_CREATE,
        planCreate('run-ready-cancel', compositePlan('plan-ready-cancel'))
      ));
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
      expect(agent.inspectPausedRun('run-paused-cancel') === null).assertTrue();
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
        dataTaskId: 'data-follow',
        intent: 'Show the exact hotel detail',
        expectedOutputSchema: 'hotelDetail'
      };
      const dataTask: CreateDataTaskPayload = {
        taskId: 'data-follow',
        toolId: 'hotel.detail',
        outputSchema: 'hotelDetail',
        args: JSON.parse('{"hotelId":101}') as Object
      };
      const followUp: ActionFollowUp = {
        turnId: 'turn-follow',
        uiTask,
        dataTask
      };
      executor.results = [
        success('{"hotelId":101,"latitude":22.5}', followUp),
        success('{"opened":true}')
      ];
      const agent = new ActionAgent(bus, catalog(new ActionLookup()), executor);
      const observer = bus.openReader();
      agent.start();

      bus.publish(message(
        AgentMessageType.ACTION_PLAN_CREATE,
        planCreate('run-follow', compositePlan())
      ));
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
      expect(observed[uiIndex].turnId).assertEqual('turn-follow');
      expect(observed[dataIndex].turnId).assertEqual('turn-follow');
      expect(observed[uiIndex].taskId).assertEqual('ui-follow');
      expect(observed[dataIndex].taskId).assertEqual('data-follow');
      expect(executor.actionIds.join(',')).assertEqual('hotel.detail,hotel.navigate');
      expect(executor.contexts[1].indexOf('|run-follow|navigate') > 0).assertTrue();

      agent.stop();
      observer.close();
    });
  });
}
