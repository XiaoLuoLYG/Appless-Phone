import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import {
  A2uiSurfaceState,
  ActionExecutionResult,
  AgentMessage,
  AgentMessageType,
  InputUserPayload,
  LeaderPlanner,
  LeaderPlannerResult,
  LeaderPlanningContext,
  LeaderPlanningSignal,
  LocalModel,
  emptyA2uiSurface
} from '@loop/agent-core';
import {
  BimContextSnapshot,
  BimLifecycleState,
  BimRecord,
  BimStore
} from '../main/ets/pages/A2uiHome/bim/BimStore';
import {
  BimGatedLeaderPlanner,
  BimPageActionAdmission,
  BimRouteDecision,
  BimTurnGate,
  bimGateWaitMs,
  bimPageActionAdmission,
  bimPageActionPresentation,
  bimContextUpdateForSave,
  buildBimAgentInput,
  buildBimExecutionPrompt,
  judgeBimLifecycle,
  lifecycleSweepCandidates,
  bimSurfaceDestination,
  bimTurnOwnsTransientState,
  compactBimRetrievalIndexForPrompt,
  localBimCandidates,
  bimRememberFailureMessage,
  bimDetailRenderKey,
  selectedBimRecordForRender,
  refreshedSelectedBimRecord,
  initialBimContextForNewBim,
  routeBimQuery,
  runBimPageActionWithAdmission,
  runWeeklyBimLifecycleSweep,
  surfaceForNewBim,
  shouldPrepareVirtualPageAction,
  bimTravelQueryNeedsDetails,
  weeklySweepDue
} from '../main/ets/pages/A2uiHome/bim/BimRuntime';

class Deferred<T> {
  readonly promise: Promise<T>;
  resolve: (value: T) => void = (_value: T): void => {};

  constructor() {
    this.promise = new Promise<T>((resolve: (value: T) => void): void => {
      this.resolve = resolve;
    });
  }
}

class ImmediatePlanner implements LeaderPlanner {
  calls: number = 0;
  round: number = 0;
  signal: LeaderPlanningSignal | undefined = undefined;
  currentLocalDate: string = '';

  async plan(
    _message: AgentMessage,
    _input: InputUserPayload,
    _context: LeaderPlanningContext,
    round?: number,
    signal?: LeaderPlanningSignal,
    currentLocalDate?: string
  ): Promise<LeaderPlannerResult> {
    this.calls++;
    this.round = round === undefined ? 0 : round;
    this.signal = signal;
    this.currentLocalDate = currentLocalDate === undefined ? '' : currentLocalDate;
    return {
      personaId: '',
      skillId: '',
      requestedCapabilityIds: [],
      roundAction: 'answer',
      dataTasks: [],
      uiIntent: { purpose: 'answer', preferredDensity: 'comfortable', requiredSections: [] },
      answer: 'ok',
      reasonCode: 'answer'
    };
  }
}

function noMatch(): BimRouteDecision {
  return { status: 'none', primaryBimId: '', secondaryBimIds: [], reason: 'none' };
}

function routed(status: 'matched' | 'ambiguous' | 'unknown'): BimRouteDecision {
  return {
    status,
    primaryBimId: status === 'matched' ? 'bim-trip' : '',
    secondaryBimIds: status === 'ambiguous' ? ['bim-trip', 'bim-osaka'] : [],
    reason: status
  };
}

function message(turnId: string): AgentMessage {
  return {
    type: AgentMessageType.INPUT_USER,
    conversationId: 'bim-test',
    turnId,
    taskId: 'input-1',
    payload: new Object()
  };
}

function input(text: string): InputUserPayload {
  return { text };
}

function planningContext(): LeaderPlanningContext {
  return { tools: [], personas: [] };
}

function loggedWaitMs(line: string): number {
  const prefix: string = '[AIPhone][BimGate] toolGateWaitMs=';
  return line.indexOf(prefix) === 0 ? Number(line.substring(prefix.length)) : -1;
}

class CountingModel implements LocalModel {
  calls: number = 0;
  prompts: string[] = [];
  private readonly output: string;

  constructor(output: string) {
    this.output = output;
  }

  async complete(prompt: string): Promise<string> {
    this.calls++;
    this.prompts.push(prompt);
    return this.output;
  }
}

class DeferredModel implements LocalModel {
  calls: number = 0;
  readonly completion: Deferred<string> = new Deferred<string>();

  async complete(_prompt: string): Promise<string> {
    this.calls++;
    return this.completion.promise;
  }
}

class FailingModel implements LocalModel {
  calls: number = 0;

  async complete(_prompt: string): Promise<string> {
    this.calls++;
    throw new Error('model unavailable');
  }
}

class RuntimeMemoryPreferences {
  private readonly values: Map<string, preferences.ValueType> = new Map();

  getSync(key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    return this.values.has(key) ? this.values.get(key) as preferences.ValueType : defaultValue;
  }

  putSync(key: string, value: preferences.ValueType): void {
    this.values.set(key, value);
  }

  flushSync(): void {}
}

function runtimeStoreWith(records: BimRecord[]): BimStore {
  const native = new RuntimeMemoryPreferences() as Object as preferences.Preferences;
  const store = new BimStore(native);
  records.forEach((item: BimRecord): void => { store.create(item); });
  return store;
}

function storeWithRecentRecord(): BimStore {
  const store = runtimeStoreWith([
    runtimeRecord('bim-recent', '最近事项', 'active', '2026-08-02T10:00:00Z')
  ]);
  store.applyLifecycleSweep([], '2026-07-27T00:00:00Z');
  return store;
}

function storeWithOldRecord(): BimStore {
  const store = runtimeStoreWith([
    runtimeRecord('bim-old', '旧事项', 'active', '2026-07-20T10:00:00Z')
  ]);
  store.applyLifecycleSweep([], '2026-07-27T00:00:00Z');
  return store;
}

function runtimeRecord(
  id: string,
  title: string,
  lifecycle: BimLifecycleState = 'active',
  lastInteractionAt: string = '2026-08-03T10:00:00+08:00',
  contextMarker: string = title,
  surfaceMarker: string = '当前安排'
): BimRecord {
  const surface: A2uiSurfaceState = {
    surfaceId: 'surface-' + id, rootId: 'root', title: surfaceMarker,
    intent: 'travel', status: 'ready',
    components: [{ id: 'root', component: 'SurfaceRoot' }],
    dataModelJson: '{}', error: '', sequence: 1
  };
  return {
    id, title, lifecycle,
    createdAt: '2026-08-01T10:00:00+08:00',
    updatedAt: lastInteractionAt,
    lastInteractionAt,
    lastLifecycleCheckAt: '2026-08-01T10:00:00+08:00',
    relatedBimIds: [],
    contextJson: JSON.stringify({
      summary: contextMarker, facts: [], constraints: [], decisions: []
    }),
    retrievalIndex: {
      summary: title, entities: [title], timeAnchors: [], locations: [title.substring(0, 2)],
      commitments: [], keywords: [title, '机票']
    },
    surfaceJson: JSON.stringify(surface)
  };
}

function tokyoRecord(contextMarker: string = '东京旅行', surfaceMarker: string = '当前安排'): BimRecord {
  return runtimeRecord('bim-trip', '东京旅行', 'active',
    '2026-08-03T10:00:00+08:00', contextMarker, surfaceMarker);
}

function osakaRecord(contextMarker: string, surfaceMarker: string): BimRecord {
  return runtimeRecord('bim-osaka', '大阪旅行', 'active',
    '2026-08-03T10:00:00+08:00', contextMarker, surfaceMarker);
}

export default function bimRuntimeTest() {
  describe('bimRuntime', () => {
    it('creates a truthful generic Surface when the turn produced no Surface', 0, () => {
      const json = surfaceForNewBim('', emptyA2uiSurface(), {
        title: '东京旅行',
        summary: '八月东京一周旅行',
        reason: '还需要继续选择机票与酒店',
        keywords: ['东京', '旅行', '机票', '酒店']
      });
      expect(json.indexOf('东京旅行') >= 0).assertTrue();
      expect(json.indexOf('八月东京一周旅行') >= 0).assertTrue();
      expect(json.indexOf('"actions"')).assertEqual(-1);
    });

    it('keeps a generic new-matter context free of the previous Surface facts', 0, () => {
      const previous = emptyA2uiSurface('surface-previous');
      previous.status = 'ready';
      previous.components = [{ id: 'root', component: 'Text', text: 'PROVIDER_RECEIPT_OLD' }];
      const context = initialBimContextForNewBim('', previous, {
        title: '东京旅行',
        summary: '八月东京一周旅行',
        reason: '还需要继续选择机票与酒店',
        keywords: ['东京', '旅行']
      });

      expect(context.summary).assertEqual('东京旅行：八月东京一周旅行');
      expect(context.facts.length).assertEqual(0);
      expect(JSON.stringify(context).indexOf('PROVIDER_RECEIPT_OLD')).assertEqual(-1);
    });

    it('starts a new matter with the model-provided dashboard state', 0, () => {
      const context = initialBimContextForNewBim('', emptyA2uiSurface(), {
        title: '婚宴宾客',
        summary: '跟进宾客确认与桌数',
        reason: '需要跨多次沟通更新',
        keywords: ['婚宴', '宾客']
      }, {
        summary: '南京婚宴，当前确认 49 人',
        facts: ['婚宴日期为 2027 年 2 月 14 日'],
        constraints: ['每桌 10 人'],
        decisions: [],
        entities: ['小王', '李阿姨'],
        timeAnchors: ['2027-02-14'],
        locations: ['南京'],
        commitments: [],
        keywords: ['婚宴', '宾客', '桌数'],
        dashboardItems: [
          { kind: 'metric', title: '已确认', value: '49', detail: '位宾客', status: '' },
          { kind: 'person', title: '小王', value: '待回复', detail: '', status: '待确认' }
        ]
      });

      expect(context.summary).assertEqual('南京婚宴，当前确认 49 人');
      expect(context.dashboardItems?.length).assertEqual(2);
      expect(context.dashboardItems?.[1].title).assertEqual('小王');
    });

    it('replaces the selected detail snapshot after a stored BIM update', 0, () => {
      const previous = tokyoRecord('考试进度 0/4');
      const updated = tokyoRecord('考试进度 1/4，科目一已通过');

      const selected = refreshedSelectedBimRecord(previous.id, [updated]);

      expect(selected?.contextJson.indexOf('1/4')).assertLarger(-1);
      expect(selected === previous).assertFalse();
    });

    it('renders the current selected snapshot instead of a stale record', 0, () => {
      const updated = tokyoRecord('考试进度 1/4，科目一已通过');

      expect(selectedBimRecordForRender(updated.id, updated)).assertEqual(updated);
      expect(selectedBimRecordForRender('other-bim', updated)).assertNull();
    });

    it('changes the detail render identity for every refreshed snapshot', 0, () => {
      const first = bimDetailRenderKey('bim-exam', 1);
      const second = bimDetailRenderKey('bim-exam', 2);

      expect(first === second).assertFalse();
    });

    it('uses a safe local Store error before the fixed fallback', 0, () => {
      expect(bimRememberFailureMessage('flush failed')).assertEqual('flush failed');
      expect(bimRememberFailureMessage('')).assertEqual('心上事保存失败');
    });

    it('logs actual route-first and planner-first Promise settlement order', 0, async () => {
      const routeFirstGate: BimTurnGate = new BimTurnGate();
      const routeFirstLogs: string[] = [];
      routeFirstGate.begin(5, Promise.resolve(noMatch()));
      routeFirstGate.bind('route-first', 5);
      await new BimGatedLeaderPlanner(
        new ImmediatePlanner(),
        routeFirstGate,
        (line: string): void => {
          routeFirstLogs.push(line);
        }
      ).plan(message('route-first'), input('route first'), planningContext());

      const plannerFirstGate: BimTurnGate = new BimTurnGate();
      const plannerFirstLogs: string[] = [];
      const deferredRoute = new Deferred<BimRouteDecision>();
      plannerFirstGate.begin(6, deferredRoute.promise);
      plannerFirstGate.bind('planner-first', 6);
      const plannerFirst = new BimGatedLeaderPlanner(
        new ImmediatePlanner(),
        plannerFirstGate,
        (line: string): void => {
          plannerFirstLogs.push(line);
        }
      ).plan(message('planner-first'), input('planner first'), planningContext());
      await Promise.resolve();
      deferredRoute.resolve(noMatch());
      await plannerFirst;

      expect(routeFirstLogs.length).assertEqual(1);
      expect(loggedWaitMs(routeFirstLogs[0])).assertEqual(0);
      expect(plannerFirstLogs.length).assertEqual(1);
      expect(loggedWaitMs(plannerFirstLogs[0]) >= 1).assertTrue();
      expect(bimGateWaitMs(false, 101, 100)).assertEqual(1);
    });

    it('starts Leader planning before routing resolves but withholds the decision', 0, async () => {
      const planner = new ImmediatePlanner();
      const gate: BimTurnGate = new BimTurnGate();
      const routedDecision = new Deferred<BimRouteDecision>();
      const signal = (): boolean => true;
      gate.begin(7, routedDecision.promise);
      gate.bind('turn-1', 7);

      let admitted = false;
      const result: Promise<LeaderPlannerResult> = new BimGatedLeaderPlanner(planner, gate).plan(
        message('turn-1'), input('东京机票'), planningContext(), 2, signal, '2026-08-03'
      );
      result.then((): void => {
        admitted = true;
      }).catch((): void => {});
      await Promise.resolve();

      expect(planner.calls).assertEqual(1);
      expect(planner.round).assertEqual(2);
      expect(planner.signal === signal).assertTrue();
      expect(planner.currentLocalDate).assertEqual('2026-08-03');
      expect(admitted).assertFalse();

      routedDecision.resolve(noMatch());
      expect((await result).reasonCode).assertEqual('answer');
      gate.clear(7);
      expect(gate.routeFor('turn-1')).assertNull();
    });

    it('rejects every routed BIM status before Leader can publish work', 0, async () => {
      const statuses: ('matched' | 'ambiguous' | 'unknown')[] = ['matched', 'ambiguous', 'unknown'];
      for (let index = 0; index < statuses.length; index++) {
        const gate: BimTurnGate = new BimTurnGate();
        const generation = 8 + index;
        const turnId = 'turn-' + generation.toString();
        gate.begin(generation, Promise.resolve(routed(statuses[index])));
        gate.bind(turnId, generation);

        let error = '';
        try {
          await new BimGatedLeaderPlanner(new ImmediatePlanner(), gate).plan(
            message(turnId), input('买机票'), planningContext(), 1
          );
        } catch (caught) {
          error = caught instanceof Error ? caught.message : '';
        }
        expect(error).assertEqual('BIM_MAIN_TURN_NOT_ADMITTED');
      }
    });

    it('loads full primary context but never injects persisted Surface JSON into the model prompt', 0, () => {
      const prompt = buildBimExecutionPrompt(
        tokyoRecord('PRIMARY_PRIVATE_CONTEXT', 'PRIMARY_PRIVATE_SURFACE'),
        [osakaRecord('SECONDARY_PRIVATE_CONTEXT', 'SECONDARY_PRIVATE_SURFACE')],
        '比较东京与大阪行程'
      );

      expect(prompt.indexOf('PRIMARY_PRIVATE_CONTEXT') >= 0).assertTrue();
      expect(prompt.indexOf('PRIMARY_PRIVATE_SURFACE')).assertEqual(-1);
      expect(prompt.indexOf('SECONDARY_PRIVATE_CONTEXT')).assertEqual(-1);
      expect(prompt.indexOf('SECONDARY_PRIVATE_SURFACE')).assertEqual(-1);
      expect(prompt.indexOf('[BIM_CONTEXT]') >= 0).assertTrue();
      expect(prompt.indexOf('never call memory.update') >= 0).assertTrue();
      expect(prompt.indexOf('self-contained query') >= 0).assertTrue();
    });

    it('starts a direct BIM turn without conversation history', 0, () => {
      const input = buildBimAgentInput(tokyoRecord(), '不要红眼航班');

      expect(input.text).assertEqual('不要红眼航班');
      expect(input.recentMessages?.length).assertEqual(0);
      expect(input.recentObservations?.length).assertEqual(0);
    });

    it('keeps newer BIM transient ownership when an older turn finalizes', 0, () => {
      expect(bimTurnOwnsTransientState(12, 11)).assertFalse();
      expect(bimTurnOwnsTransientState(12, 12)).assertTrue();
    });

    it('keeps stale and detail BIM surfaces out of Home', 0, () => {
      expect(bimSurfaceDestination(false, 'bim-trip', true)).assertEqual('reject');
      expect(bimSurfaceDestination(true, '', false)).assertEqual('home');
      expect(bimSurfaceDestination(true, 'bim-trip', false)).assertEqual('home');
      expect(bimSurfaceDestination(true, 'bim-trip', true)).assertEqual('detail');
    });

    it('keeps direct-detail page action results and failures out of Home transcript', 0, () => {
      const stale = bimPageActionPresentation(false, 'bim-trip', true);
      expect(stale.destination).assertEqual('reject');
      expect(stale.appendAssistantMessage).assertFalse();

      const home = bimPageActionPresentation(true, '', false);
      expect(home.destination).assertEqual('home');
      expect(home.appendAssistantMessage).assertTrue();

      const homeBim = bimPageActionPresentation(true, 'bim-trip', false);
      expect(homeBim.destination).assertEqual('home');
      expect(homeBim.appendAssistantMessage).assertTrue();

      const detail = bimPageActionPresentation(true, 'bim-trip', true);
      expect(detail.destination).assertEqual('detail');
      expect(detail.appendAssistantMessage).assertFalse();
    });

    it('skips virtual Home preparation before an owned direct-detail BIM action', 0, () => {
      expect(shouldPrepareVirtualPageAction(true, 12, 12, 'bim-trip', true)).assertFalse();
      expect(shouldPrepareVirtualPageAction(true, 12, 12, 'bim-trip', false)).assertTrue();
      expect(shouldPrepareVirtualPageAction(true, 12, 11, 'bim-trip', true)).assertTrue();
      expect(shouldPrepareVirtualPageAction(true, 12, 12, '', false)).assertTrue();
      expect(shouldPrepareVirtualPageAction(false, 12, 12, 'bim-trip', true)).assertFalse();
    });

    it('rejects an N callback at N+1 before preparation or execution', 0, async () => {
      let prepareCount: number = 0;
      let executeCount: number = 0;
      const prepare = (): void => {
        prepareCount++;
      };
      const execute = async (): Promise<ActionExecutionResult> => {
        executeCount++;
        return { status: 'success', output: JSON.parse('{"status":"ok"}') as Object };
      };

      const stale: BimPageActionAdmission = bimPageActionAdmission(
        true, 41, 42, 42, 'bim-new', true
      );
      const staleResult = await runBimPageActionWithAdmission(stale, prepare, execute);
      const missingResult = await runBimPageActionWithAdmission(
        bimPageActionAdmission(true, undefined, 42, 42, 'bim-new', true),
        prepare,
        execute
      );
      const invalidResult = await runBimPageActionWithAdmission(
        bimPageActionAdmission(true, 0, 42, 42, 'bim-new', true),
        prepare,
        execute
      );

      let staleErrorCode: string = '';
      if (staleResult.status === 'error') {
        staleErrorCode = staleResult.errorCode;
      }
      expect(staleResult.status).assertEqual('error');
      expect(staleErrorCode).assertEqual('BIM_PAGE_ACTION_GENERATION_STALE');
      expect(missingResult.status).assertEqual('error');
      expect(invalidResult.status).assertEqual('error');
      expect(prepareCount).assertEqual(0);
      expect(executeCount).assertEqual(0);

      const detailResult = await runBimPageActionWithAdmission(
        bimPageActionAdmission(true, 42, 42, 42, 'bim-new', true),
        prepare,
        execute
      );
      expect(detailResult.status).assertEqual('success');
      expect(prepareCount).assertEqual(0);
      expect(executeCount).assertEqual(1);

      await runBimPageActionWithAdmission(
        bimPageActionAdmission(true, 42, 42, 42, 'bim-new', false),
        prepare,
        execute
      );
      await runBimPageActionWithAdmission(
        bimPageActionAdmission(true, 42, 42, 42, '', false),
        prepare,
        execute
      );
      expect(prepareCount).assertEqual(2);
      expect(executeCount).assertEqual(3);
    });

    it('rejects a BIM execution prompt over 32000 characters', 0, () => {
      let message = '';
      try {
        buildBimExecutionPrompt(tokyoRecord(), [], 'x'.repeat(32000));
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      expect(message).assertEqual('BIM_CONTEXT_LIMIT');
    });

    it('rejects malformed persisted Surface JSON at the BIM prompt boundary', 0, () => {
      const record = tokyoRecord();
      record.surfaceJson = '{';
      let promptError = '';
      let inputError = '';
      try {
        buildBimExecutionPrompt(record, [], '继续');
      } catch (error) {
        promptError = error instanceof Error ? error.message : '';
      }
      try {
        buildBimAgentInput(record, '继续');
      } catch (error) {
        inputError = error instanceof Error ? error.message : '';
      }

      expect(promptError).assertEqual('BIM_SURFACE_INVALID');
      expect(inputError).assertEqual('BIM_SURFACE_INVALID');
    });

    it('rejects every valid-JSON Surface that the Store rejects', 0, () => {
      const validSurface = tokyoRecord().surfaceJson;
      const invalidSurfaces: string[] = [
        validSurface.substring(0, validSurface.length - 1) + ',"extra":true}',
        validSurface.replace('"title":"当前安排",', ''),
        validSurface.replace(
          '"components":[{"id":"root","component":"SurfaceRoot"}]',
          '"components":[{"id":"root","component":"SurfaceRoot",' +
            '"actions":[{"id":"bad","label":"","prompt":"","variant":"","kind":7}]}]'
        ),
        validSurface.replace(
          '"dataModelJson":"{}"',
          '"dataModelJson":' + JSON.stringify('x'.repeat(96001))
        )
      ];

      for (let index = 0; index < invalidSurfaces.length; index++) {
        const record = tokyoRecord();
        record.surfaceJson = invalidSurfaces[index];
        let promptError = '';
        let inputError = '';
        try {
          buildBimExecutionPrompt(record, [], '继续');
        } catch (error) {
          promptError = error instanceof Error ? error.message : '';
        }
        try {
          buildBimAgentInput(record, '继续');
        } catch (error) {
          inputError = error instanceof Error ? error.message : '';
        }
        expect(promptError).assertEqual('BIM_SURFACE_INVALID');
        expect(inputError).assertEqual('BIM_SURFACE_INVALID');
      }
    });

    it('preserves context only when a successful business Surface changed', 0, () => {
      const record = tokyoRecord();
      const hotelSurface = JSON.parse(record.surfaceJson) as A2uiSurfaceState;
      hotelSurface.intent = 'hotel';
      hotelSurface.title = '东京酒店';
      hotelSurface.sequence += 1;
      const preserved = bimContextUpdateForSave(record, JSON.stringify(hotelSurface), undefined);

      expect(preserved?.summary).assertEqual('东京旅行');
      expect(preserved?.entities[0]).assertEqual('东京旅行');
      expect(bimContextUpdateForSave(record, record.surfaceJson, undefined)).assertEqual(undefined);

      hotelSurface.status = 'error';
      expect(
        bimContextUpdateForSave(record, JSON.stringify(hotelSurface), undefined)
      ).assertEqual(undefined);
    });

    it('rejects a core-only update that would leave stale dashboard state', 0, () => {
      const record = tokyoRecord();
      const context = JSON.parse(record.contextJson) as BimContextSnapshot;
      context.dashboardItems = [
        { kind: 'person', title: '小王', value: '参加', detail: '', status: '已确认' }
      ];
      record.contextJson = JSON.stringify(context);

      const update = bimContextUpdateForSave(record, record.surfaceJson, {
        summary: '小王改为不参加',
        facts: ['小王不参加'],
        constraints: [],
        decisions: [],
        entities: ['小王'],
        timeAnchors: [],
        locations: [],
        commitments: [],
        keywords: ['婚宴', '小王']
      });

      expect(update).assertEqual(undefined);
    });

    it('does not call the model when the local index has no candidate', 0, async () => {
      const model = new CountingModel('{"status":"none","primaryBimId":"","secondaryBimIds":[],"reason":"none"}');
      const result = await routeBimQuery('解释一下量子计算', [tokyoRecord()], model);

      expect(result.status).assertEqual('none');
      expect(model.calls).assertEqual(0);
    });

    it('does not treat a retrieval summary as a local candidate', 0, async () => {
      const record = tokyoRecord();
      record.title = '周末安排';
      record.retrievalIndex.summary = '量子计算';
      record.retrievalIndex.entities = [];
      record.retrievalIndex.timeAnchors = [];
      record.retrievalIndex.locations = [];
      record.retrievalIndex.commitments = [];
      record.retrievalIndex.keywords = [];
      const model = new CountingModel(
        '{"status":"matched","primaryBimId":"bim-trip","secondaryBimIds":[],"reason":"wrong"}'
      );
      const result = await routeBimQuery('解释一下量子计算', [record], model);

      expect(result.status).assertEqual('none');
      expect(model.calls).assertEqual(0);
    });

    it('does not wake Tokyo travel from an unrelated exhibition plan', 0, () => {
      const record = tokyoRecord();
      record.retrievalIndex.entities = ['东京旅行', '同事'];
      record.retrievalIndex.timeAnchors = ['2027年5月'];
      record.retrievalIndex.locations = ['东京'];
      record.retrievalIndex.commitments = ['每周跟进准备状态'];
      record.retrievalIndex.keywords = ['旅行', '东京', '同事', '规划', '准备'];
      record.contextJson = JSON.stringify({
        summary: '东京旅行筹备计划',
        facts: ['同行 4 人', '与三位同事同行'],
        constraints: ['住宿与交通尚未确认'],
        decisions: []
      });

      expect(localBimCandidates(
        '展会计划有变化，地点改到杭州了，时间是在8.30号，第一阶段报名已经完成了，下一步确认展位了。',
        [record]
      ).length).assertEqual(0);
    });

    it('wakes a matter from a short topic in its retrieval index', 0, () => {
      const record = tokyoRecord('用户计划下个月去杭州参加展会');
      record.title = '上海展会行程安排';
      record.retrievalIndex.entities = ['展会'];
      record.retrievalIndex.timeAnchors = [];
      record.retrievalIndex.locations = [];
      record.retrievalIndex.commitments = [];
      record.retrievalIndex.keywords = [];

      expect(localBimCandidates('帮我订从深圳出发的机票去展会', [record]).length).assertEqual(1);
    });

    it('requires route and date before a BIM travel provider query', 0, () => {
      expect(bimTravelQueryNeedsDetails('帮我查去展会的机票')).assertTrue();
      expect(bimTravelQueryNeedsDetails('帮我查从北京到上海 2026年8月的航班')).assertTrue();
      expect(bimTravelQueryNeedsDetails('帮我查从深圳到杭州 2026年8月30日的机票')).assertFalse();
      expect(bimTravelQueryNeedsDetails('帮我查明天从北京到上海的航班')).assertFalse();
      expect(bimTravelQueryNeedsDetails('帮我查明天北京到上海航班')).assertFalse();
      expect(bimTravelQueryNeedsDetails('帮我查明天 MU2157 航班')).assertFalse();
      expect(bimTravelQueryNeedsDetails('机票已经确认，把状态更新一下')).assertFalse();
      expect(bimTravelQueryNeedsDetails('把展会计划的下一步改成确认展位')).assertFalse();
    });

    it('confirms candidates semantically and rejects unknown returned IDs', 0, async () => {
      const model = new CountingModel(
        '{"status":"matched","primaryBimId":"not-present","secondaryBimIds":[],"reason":"trip"}'
      );
      const result = await routeBimQuery('帮我买东京机票', [tokyoRecord()], model);

      expect(model.calls).assertEqual(1);
      expect(result.status).assertEqual('unknown');
    });

    it('never routes an ended matter automatically', 0, async () => {
      const record = tokyoRecord();
      record.lifecycle = 'ended';
      const model = new CountingModel('');

      expect((await routeBimQuery('继续东京旅行', [record], model)).status).assertEqual('none');
      expect(model.calls).assertEqual(0);
    });

    it('accepts one primary and multiple secondary candidate IDs', 0, async () => {
      const model = new CountingModel(
        '{"status":"matched","primaryBimId":"bim-trip","secondaryBimIds":["bim-osaka"],"reason":"both trips"}'
      );
      const result = await routeBimQuery('机票安排', [tokyoRecord(), osakaRecord('大阪旅行', '大阪安排')], model);

      expect(result.status).assertEqual('matched');
      expect(result.primaryBimId).assertEqual('bim-trip');
      expect(result.secondaryBimIds.length).assertEqual(1);
      expect(result.secondaryBimIds[0]).assertEqual('bim-osaka');
    });

    it('accepts the existing model Thought and Action wrapper around one route object', 0, async () => {
      const model = new CountingModel(
        'Thought: query matches the trip.\nAction: ' +
        '{"status":"matched","primaryBimId":"bim-trip","secondaryBimIds":[],"reason":"trip"}'
      );
      const result = await routeBimQuery('东京机票', [tokyoRecord()], model);

      expect(result.status).assertEqual('matched');
      expect(result.primaryBimId).assertEqual('bim-trip');
    });

    it('returns unknown for malformed semantic output', 0, async () => {
      const result = await routeBimQuery('东京机票', [tokyoRecord()], new CountingModel('{'));

      expect(result.status).assertEqual('unknown');
    });

    it('keeps a valid ambiguous candidate set', 0, async () => {
      const model = new CountingModel(
        '{"status":"ambiguous","primaryBimId":"","secondaryBimIds":["bim-trip","bim-osaka"],"reason":"which trip"}'
      );
      const result = await routeBimQuery('机票安排', [tokyoRecord(), osakaRecord('大阪旅行', '大阪安排')], model);

      expect(result.status).assertEqual('ambiguous');
      expect(result.secondaryBimIds.length).assertEqual(2);
    });

    it('keeps context and surface data out of a compact semantic prompt', 0, async () => {
      const model = new CountingModel(
        '{"status":"matched","primaryBimId":"bim-trip","secondaryBimIds":[],"reason":"trip"}'
      );
      const record = tokyoRecord('private-context-marker', 'private-surface-marker');
      record.retrievalIndex.entities = ['x'.repeat(60), 'two', 'three', 'four', 'five'];
      record.retrievalIndex.keywords = ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'];
      const result = await routeBimQuery('东京机票', [record], model);
      const compact = compactBimRetrievalIndexForPrompt(record.retrievalIndex);

      expect(result.status).assertEqual('matched');
      expect(model.prompts[0].indexOf('private-context-marker') < 0).assertTrue();
      expect(model.prompts[0].indexOf('private-surface-marker') < 0).assertTrue();
      expect(compact.entities.length).assertEqual(4);
      expect(compact.entities[0].length).assertEqual(48);
      expect(compact.keywords.length).assertEqual(8);
    });

    it('tells semantic routing that a new hotel search can further an existing trip', 0, async () => {
      const model = new CountingModel(
        '{"status":"matched","primaryBimId":"bim-trip","secondaryBimIds":[],"reason":"trip hotel"}'
      );

      await routeBimQuery(
        '请帮我搜索2026年8月15日至17日东京的酒店，4位成人，2间房',
        [tokyoRecord()],
        model
      );

      expect(model.prompts[0].indexOf('further the matter') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('hotel') >= 0).assertTrue();
    });

    it('does not call the model for an oversized semantic prompt', 0, async () => {
      let query: string = '东京';
      for (let index = 0; index < 12000; index++) query += 'x';
      const model = new CountingModel('');
      const result = await routeBimQuery(query, [tokyoRecord()], model);

      expect(result.status).assertEqual('unknown');
      expect(model.calls).assertEqual(0);
    });

    it('only wakes tucked matters on exact title entity location or time-anchor matches', 0, () => {
      const tucked = runtimeRecord('bim-tucked', '东京旅行', 'tucked');
      tucked.retrievalIndex.entities = ['小林'];
      tucked.retrievalIndex.locations = ['涩谷'];
      tucked.retrievalIndex.timeAnchors = ['下周三'];
      tucked.retrievalIndex.keywords = ['机票'];

      expect(localBimCandidates('继续东京旅行', [tucked]).length).assertEqual(1);
      expect(localBimCandidates('联系小林', [tucked]).length).assertEqual(1);
      expect(localBimCandidates('去涩谷', [tucked]).length).assertEqual(1);
      expect(localBimCandidates('下周三出发', [tucked]).length).assertEqual(1);
      expect(localBimCandidates('继续东行', [tucked]).length).assertEqual(0);
    });

    it('keeps six candidates ordered by exact tier and updatedAt', 0, () => {
      const exactOlder = runtimeRecord('exact-older', '东京旅行', 'active', '2026-08-03T10:00:00+08:00');
      const exactNewer = runtimeRecord('exact-newer', '东京安排', 'active', '2026-08-03T11:00:00+08:00');
      const keywordOldest = runtimeRecord('keyword-oldest', '周末安排', 'active', '2026-08-03T12:00:00+08:00');
      const keywordOne = runtimeRecord('keyword-one', '周末计划', 'active', '2026-08-03T13:00:00+08:00');
      const keywordTwo = runtimeRecord('keyword-two', '周末出行', 'active', '2026-08-03T14:00:00+08:00');
      const keywordThree = runtimeRecord('keyword-three', '周末代办', 'active', '2026-08-03T15:00:00+08:00');
      const keywordFour = runtimeRecord('keyword-four', '周末清单', 'active', '2026-08-03T16:00:00+08:00');
      const keywords: BimRecord[] = [keywordOldest, keywordOne, keywordTwo, keywordThree, keywordFour];
      for (let index = 0; index < keywords.length; index++) {
        keywords[index].retrievalIndex.entities = [];
        keywords[index].retrievalIndex.timeAnchors = [];
        keywords[index].retrievalIndex.locations = [];
        keywords[index].retrievalIndex.commitments = [];
        keywords[index].retrievalIndex.keywords = ['东京机票'];
      }
      const candidates = localBimCandidates(
        '东京机票', [exactOlder, keywordOldest, exactNewer, keywordOne, keywordTwo, keywordThree, keywordFour]
      );

      expect(candidates.length).assertEqual(6);
      expect(candidates[0].id).assertEqual('exact-newer');
      expect(candidates[1].id).assertEqual('exact-older');
      expect(candidates[5].id).assertEqual('keyword-one');
    });

    it('checks only records with no interaction since the prior sweep', 0, () => {
      const candidates = lifecycleSweepCandidates(
        [
          runtimeRecord('bim-old', '旧事项', 'active', '2026-07-20T10:00:00Z'),
          runtimeRecord('bim-used', '最近事项', 'active', '2026-08-02T10:00:00Z')
        ],
        '2026-07-27T00:00:00Z',
        '2026-08-03T00:00:00Z'
      );
      expect(candidates.length).assertEqual(1);
      expect(candidates[0].id).assertEqual('bim-old');
    });

    it('uses the seven-day stored-time due calculation', 0, () => {
      expect(weeklySweepDue('2026-08-03T00:00:00Z', '2026-07-27T00:00:00Z')).assertTrue();
      expect(weeklySweepDue('2026-08-02T23:59:59Z', '2026-07-27T00:00:00Z')).assertFalse();
      expect(weeklySweepDue('2026-08-03T00:00:00Z', '')).assertTrue();
    });

    it('does not call the model when nothing is eligible', 0, async () => {
      const model = new CountingModel('[]');
      const result = await runWeeklyBimLifecycleSweep(
        storeWithRecentRecord(), model, '2026-08-03T00:00:00Z'
      );
      expect(result.ok).assertTrue();
      expect(model.calls).assertEqual(0);
    });

    it('updates lifecycle only and preserves context and surface bytes', 0, async () => {
      const store = storeWithOldRecord();
      const before = store.get('bim-old');
      const model = new CountingModel(
        '[{"id":"bim-old","lifecycle":"quiet","reason":"本周没有新调用"}]'
      );
      const result = await runWeeklyBimLifecycleSweep(store, model, '2026-08-03T00:00:00Z');
      const after = store.get('bim-old');

      expect(result.ok).assertTrue();
      expect(after?.lifecycle).assertEqual('quiet');
      expect(after?.contextJson).assertEqual(before?.contextJson);
      expect(after?.surfaceJson).assertEqual(before?.surfaceJson);
    });

    it('rejects malformed, unknown, extra, ended, and oversized lifecycle decisions atomically', 0,
      async () => {
        const outputs: string[] = [
          '{',
          '[{"id":"unknown","lifecycle":"quiet","reason":"no"}]',
          '[{"id":"bim-old","lifecycle":"quiet","reason":"one"},{"id":"bim-old","lifecycle":"active","reason":"two"}]',
          '[{"id":"bim-old","lifecycle":"quiet","reason":"no","extra":true}]',
          '[{"id":"bim-old","lifecycle":"ended","reason":"no"}]',
          '[{"id":"bim-old","lifecycle":"quiet","reason":"' + 'x'.repeat(241) + '"}]'
        ];
        for (let index = 0; index < outputs.length; index++) {
          const store = storeWithOldRecord();
          const before = store.get('bim-old');
          const result = await runWeeklyBimLifecycleSweep(
            store, new CountingModel(outputs[index]), '2026-08-03T00:00:00Z'
          );
          const after = store.get('bim-old');
          expect(result.ok).assertFalse();
          expect(after?.lifecycle).assertEqual(before?.lifecycle);
          expect(store.lastLifecycleSweepAt()).assertEqual('2026-07-27T00:00:00Z');
        }
      });

    it('rejects duplicate lifecycle IDs even when the decision count fits the candidates', 0, async () => {
      const store = runtimeStoreWith([
        runtimeRecord('bim-old', '旧事项', 'active', '2026-07-20T10:00:00Z'),
        runtimeRecord('bim-other', '另一事项', 'active', '2026-07-20T10:00:00Z')
      ]);
      store.applyLifecycleSweep([], '2026-07-27T00:00:00Z');
      const result = await runWeeklyBimLifecycleSweep(store, new CountingModel(
        '[{"id":"bim-old","lifecycle":"quiet","reason":"one"},{"id":"bim-old","lifecycle":"active","reason":"two"}]'
      ), '2026-08-03T00:00:00Z');

      expect(result.ok).assertFalse();
      expect(store.get('bim-old')?.lifecycle).assertEqual('active');
      expect(store.get('bim-other')?.lifecycle).assertEqual('active');
      expect(store.lastLifecycleSweepAt()).assertEqual('2026-07-27T00:00:00Z');
    });

    it('leaves the overdue sweep retryable when the model fails', 0, async () => {
      const store = storeWithOldRecord();
      const model = new FailingModel();
      const result = await runWeeklyBimLifecycleSweep(store, model, '2026-08-03T00:00:00Z');

      expect(result.ok).assertFalse();
      expect(model.calls).assertEqual(1);
      expect(store.lastLifecycleSweepAt()).assertEqual('2026-07-27T00:00:00Z');
    });

    it('rejects a stale lifecycle decision after the captured matter is updated', 0, async () => {
      const store = storeWithOldRecord();
      const captured: BimRecord = store.get('bim-old') as BimRecord;
      const model = new DeferredModel();
      const pending = runWeeklyBimLifecycleSweep(store, model, '2026-08-03T00:00:00Z');
      const touchedContext: BimContextSnapshot = {
        summary: '用户刚刚更新', facts: [], constraints: [], decisions: []
      };
      expect(model.calls).assertEqual(1);
      expect(store.replaceCurrentState(
        'bim-old', touchedContext,
        captured.retrievalIndex,
        captured.surfaceJson,
        captured.relatedBimIds,
        '2026-08-02T10:00:00Z'
      )).assertTrue();
      model.completion.resolve('[{"id":"bim-old","lifecycle":"quiet","reason":"old view"}]');
      const result = await pending;

      expect(result.ok).assertFalse();
      expect(store.get('bim-old')?.lifecycle).assertEqual('active');
      expect(store.get('bim-old')?.lastInteractionAt).assertEqual('2026-08-02T10:00:00Z');
      expect(store.lastLifecycleSweepAt()).assertEqual('2026-07-27T00:00:00Z');
    });

    it('keeps the lifecycle judge prompt local and bounded to its candidates', 0, async () => {
      const record = runtimeRecord(
        'bim-old', '旧事项', 'active', '2026-07-20T10:00:00Z',
        'secret-context-marker', 'secret-surface-marker'
      );
      const model = new CountingModel('[{"id":"bim-old","lifecycle":"quiet","reason":"no activity"}]');
      const decisions = await judgeBimLifecycle(model, [record]);

      expect(decisions.length).assertEqual(1);
      expect(model.prompts[0].indexOf('secret-context-marker') < 0).assertTrue();
      expect(model.prompts[0].indexOf('secret-surface-marker') < 0).assertTrue();
    });
  });
}
