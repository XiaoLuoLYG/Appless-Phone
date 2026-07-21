import { describe, expect, it } from '@ohos/hypium';
import { preferences } from '@kit.ArkData';
import {
  decideTrainPresaleExecution,
  trainPresaleAvailabilityFromOfficialPayloadForTest,
  TrainPresaleAvailabilityCheck,
  TrainPresaleExecutionDecision,
  TrainPresaleExecutionTask,
  TrainPresaleRecheckRequest
} from '@loop/agent-core';
import {
  parseTrainPresaleTaskList,
  TrainPresaleTask,
  TrainPresaleTaskState
} from '../main/ets/pages/A2uiHome/train/TrainPresaleTaskStore';
import {
  claimTrainPresaleHandoff,
  transitionBoundTrainPresaleCheckout,
  transitionTrainPresaleHandoff,
  TRAIN_PRESALE_PENDING_TASK_KEY,
  TRAIN_PRESALE_TASKS_KEY,
  TrainPresaleHandoffClaimResult,
  TrainPresaleHandoffTransitionResult
} from '../main/ets/entryability/EntryAbility';
import { TrainPresaleResumeDrain } from '../main/ets/pages/A2uiHome/train/TrainPresaleResumeDrain';

class MemoryPreferences {
  private values: Map<string, preferences.ValueType> = new Map();

  getSync(key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    return this.values.has(key) ? this.values.get(key) as preferences.ValueType : defaultValue;
  }

  putSync(key: string, value: preferences.ValueType): void {
    this.values.set(key, value);
  }

  deleteSync(key: string): void {
    this.values.delete(key);
  }

  flushSync(): void {}
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

function nativePreferences(): preferences.Preferences {
  return new MemoryPreferences() as Object as preferences.Preferences;
}

function task(state: TrainPresaleTaskState = 'scheduled'): TrainPresaleTask {
  return {
    taskId: 'task-1',
    source: 'presale',
    state: state,
    trainCode: 'G1',
    travelDate: '2026-08-06',
    fromName: '北京南',
    fromCode: 'VNP',
    toName: '上海虹桥',
    toCode: 'AOH',
    saleAt: '2026-07-22T12:45:00+08:00',
    passengerNames: ['张三'],
    seatPriority: '二等座',
    bookingUrl: 'https://kyfw.12306.cn/otn/leftTicket/init?date=2026-08-06',
    reminderId: 73,
    createdAt: '2026-07-21T10:00:00+08:00',
    lastError: ''
  };
}

function executionTask(value: TrainPresaleTask): TrainPresaleExecutionTask {
  return {
    state: value.state,
    trainCode: value.trainCode,
    travelDate: value.travelDate,
    fromName: value.fromName,
    fromCode: value.fromCode,
    toName: value.toName,
    toCode: value.toCode,
    seatPriority: value.seatPriority
  };
}

function availability(
  status: 'verified' | 'sold_out' | 'provider_error' | 'mismatch' | 'unsupported_seat',
  reason: string = ''
): TrainPresaleAvailabilityCheck {
  return {
    status: status,
    reason: reason,
    trainCode: 'G1',
    travelDate: '2026-08-06',
    fromCode: 'VNP',
    toCode: 'AOH',
    seatPriority: '二等座',
    bookingUrl: 'https://kyfw.12306.cn/otn/leftTicket/init?linktypeid=dc&fs=%E5%8C%97%E4%BA%AC%E5%8D%97,VNP&ts=%E4%B8%8A%E6%B5%B7%E8%99%B9%E6%A1%A5,AOH&date=2026-08-06&flag=N,N,Y'
  };
}

function saveTasks(store: preferences.Preferences, tasks: TrainPresaleTask[], pendingTaskId: string = ''): void {
  store.putSync(TRAIN_PRESALE_TASKS_KEY, JSON.stringify(tasks));
  if (pendingTaskId.length > 0) {
    store.putSync(TRAIN_PRESALE_PENDING_TASK_KEY, pendingTaskId);
  }
}

function savedTasks(store: preferences.Preferences): TrainPresaleTask[] {
  const raw = store.getSync(TRAIN_PRESALE_TASKS_KEY, '');
  return parseTrainPresaleTaskList(typeof raw === 'string' ? raw : '');
}

function pendingTaskId(store: preferences.Preferences): string {
  const value = store.getSync(TRAIN_PRESALE_PENDING_TASK_KEY, '');
  return typeof value === 'string' ? value : '';
}

function trainRow(trainCode: string, fromCode: string, toCode: string, second: string, first: string = ''): string {
  const fields: string[] = [];
  for (let index = 0; index < 40; index++) {
    fields.push('');
  }
  fields[3] = trainCode;
  fields[6] = fromCode;
  fields[7] = toCode;
  fields[11] = 'Y';
  fields[30] = second;
  fields[31] = first;
  return fields.join('|');
}

function recheckRequest(): TrainPresaleRecheckRequest {
  return {
    trainCode: 'G1',
    travelDate: '2026-08-06',
    fromName: '北京南',
    fromCode: 'VNP',
    toName: '上海虹桥',
    toCode: 'AOH',
    seatPriority: '二等座'
  };
}

export default function trainPresaleExecutionTest() {
  describe('trainPresaleExecution', () => {
    it('claims a due scheduled handoff once but not an executing or cancelled task', 0, () => {
      const store = nativePreferences();
      const cancelled = task('cancelled');
      cancelled.taskId = 'task-cancelled';
      saveTasks(store, [task(), cancelled]);
      const due: TrainPresaleHandoffClaimResult = claimTrainPresaleHandoff(
        store, '2026-07-22T12:45:00+08:00', 'task-1');
      const claimedAgain: TrainPresaleHandoffClaimResult = claimTrainPresaleHandoff(
        store, '2026-07-22T12:45:01+08:00', 'task-1');
      const cancelledClaim: TrainPresaleHandoffClaimResult = claimTrainPresaleHandoff(
        store, '2026-07-22T12:45:01+08:00', 'task-cancelled');

      expect(due.taskId).assertEqual('task-1');
      expect(due.changed).assertTrue();
      expect(claimedAgain.taskId).assertEqual('task-1');
      expect(claimedAgain.changed).assertFalse();
      expect(cancelledClaim.taskId).assertEqual('task-1');
      expect(cancelledClaim.changed).assertFalse();
      expect(savedTasks(store)[0].state).assertEqual('executing');
      expect(savedTasks(store)[1].state).assertEqual('cancelled');
    });

    it('gives an explicit task precedence and recovers the replaced executing handoff', 0, () => {
      const store = nativePreferences();
      const first = task('executing');
      first.taskId = 'task-a';
      const second = task();
      second.taskId = 'task-b';
      saveTasks(store, [first, second], 'task-a');

      const result: TrainPresaleHandoffClaimResult = claimTrainPresaleHandoff(
        store, '2026-07-22T12:45:00+08:00', 'task-b');
      const tasks = savedTasks(store);

      expect(result.taskId).assertEqual('task-b');
      expect(pendingTaskId(store)).assertEqual('task-b');
      expect(tasks[0].state).assertEqual('needs_user');
      expect(tasks[0].lastError.indexOf('新的开售提醒') >= 0).assertTrue();
      expect(tasks[1].state).assertEqual('executing');
    });

    it('retains an executing handoff for crash reopen and compare-deletes only after durable state', 0, () => {
      const store = nativePreferences();
      saveTasks(store, [task('executing')], 'task-1');

      expect(transitionTrainPresaleHandoff(store, 'task-1', 'executing', '').cleared).assertFalse();
      expect(pendingTaskId(store)).assertEqual('task-1');
      const reopened: TrainPresaleHandoffClaimResult = claimTrainPresaleHandoff(
        store, '2026-07-22T12:46:00+08:00');
      expect(reopened.taskId).assertEqual('task-1');
      expect(reopened.changed).assertFalse();
      expect(transitionTrainPresaleHandoff(store, 'other', 'needs_user', 'ignored').cleared).assertFalse();
      expect(pendingTaskId(store)).assertEqual('task-1');
      const closed: TrainPresaleHandoffTransitionResult = transitionTrainPresaleHandoff(
        store, 'task-1', 'needs_user', '已关闭 12306 购票页，请重新打开任务继续。');

      expect(closed.cleared).assertTrue();
      expect(pendingTaskId(store)).assertEqual('');
      expect(savedTasks(store)[0].state).assertEqual('needs_user');
      expect(savedTasks(store)[0].lastError.indexOf('已关闭') >= 0).assertTrue();
    });

    it('does not clear a handoff when its durable task record is missing', 0, () => {
      const store = nativePreferences();
      saveTasks(store, [], 'missing-task');

      const result: TrainPresaleHandoffTransitionResult = transitionTrainPresaleHandoff(
        store, 'missing-task', 'needs_user', '任务记录缺失');

      expect(result.cleared).assertFalse();
      expect(pendingTaskId(store)).assertEqual('missing-task');
    });

    it('ignores a stale A checkout close while checkout and pending handoff are bound to B', 0, () => {
      const store = nativePreferences();
      const first = task('executing');
      first.taskId = 'task-a';
      const second = task('executing');
      second.taskId = 'task-b';
      saveTasks(store, [first, second], 'task-b');

      const stale: TrainPresaleHandoffTransitionResult = transitionBoundTrainPresaleCheckout(
        store, 'task-b', 'task-a', 'stale close');

      expect(stale.cleared).assertFalse();
      expect(pendingTaskId(store)).assertEqual('task-b');
      expect(savedTasks(store)[0].state).assertEqual('executing');
      expect(savedTasks(store)[1].state).assertEqual('executing');
    });

    it('drains a queued B after awaiting A once and skips repeat show for active B', 0, async () => {
      let pendingTaskId = 'task-a';
      let activeCheckoutTaskId = '';
      const started: string[] = [];
      const firstStarted = new TestGate();
      const releaseFirst = new TestGate();
      const drain = new TrainPresaleResumeDrain(
        (): string => pendingTaskId,
        (): string => activeCheckoutTaskId,
        async (taskId: string): Promise<void> => {
          started.push(taskId);
          if (taskId === 'task-a') {
            firstStarted.open();
            await releaseFirst.promise;
          }
          activeCheckoutTaskId = taskId;
        }
      );

      const running = drain.request();
      await firstStarted.promise;
      pendingTaskId = 'task-b';
      void drain.request();
      releaseFirst.open();
      await running;
      await drain.request();

      expect(started.join(',')).assertEqual('task-a,task-b');
      expect(activeCheckoutTaskId).assertEqual('task-b');

      pendingTaskId = 'task-c';
      await drain.request();
      expect(started.join(',')).assertEqual('task-a,task-b,task-c');
    });

    it('requires the user when the requested seat is sold out', 0, () => {
      const decision: TrainPresaleExecutionDecision = decideTrainPresaleExecution(
        executionTask(task('executing')), availability('sold_out', 'G1 二等座当前无票。'));

      expect(decision.state).assertEqual('needs_user');
      expect(decision.reason).assertEqual('G1 二等座当前无票。');
      expect(decision.bookingUrl).assertEqual('');
    });

    it('preserves the real provider error for user attention', 0, () => {
      const decision: TrainPresaleExecutionDecision = decideTrainPresaleExecution(
        executionTask(task('executing')), availability('provider_error', '12306 返回 HTTP 503。'));

      expect(decision.state).assertEqual('needs_user');
      expect(decision.reason).assertEqual('12306 返回 HTTP 503。');
    });

    it('rejects a train date or route mismatch', 0, () => {
      const mismatched = availability('verified');
      mismatched.trainCode = 'G3';
      const decision: TrainPresaleExecutionDecision = decideTrainPresaleExecution(
        executionTask(task('executing')), mismatched);

      expect(decision.state).assertEqual('needs_user');
      expect(decision.reason.indexOf('不匹配') >= 0).assertTrue();
    });

    it('rejects an unsupported requested seat', 0, () => {
      const requested = task('executing');
      requested.seatPriority = '软卧';
      const decision: TrainPresaleExecutionDecision = decideTrainPresaleExecution(
        executionTask(requested), availability('unsupported_seat', '当前不支持核验席别：软卧。'));

      expect(decision.state).assertEqual('needs_user');
      expect(decision.reason).assertEqual('当前不支持核验席别：软卧。');
    });

    it('keeps verified availability executing and returns only the official booking URL', 0, () => {
      const check = availability('verified');
      const decision: TrainPresaleExecutionDecision = decideTrainPresaleExecution(
        executionTask(task('executing')), check);

      expect(decision.state).assertEqual('executing');
      expect(decision.reason).assertEqual('');
      expect(decision.bookingUrl).assertEqual(check.bookingUrl);
    });

    it('parses the actual official row and requested seat against the station map', 0, () => {
      const row = trainRow('G1', 'VNP', 'AOH', '有', '3');
      const payload = '{"status":true,"data":{"result":[' + JSON.stringify(row) + ']}}';
      const stationPayload = '@bjn|北京南|VNP|beijingnan|bjn@shh|上海虹桥|AOH|shanghaihongqiao|shh';
      const verified: TrainPresaleAvailabilityCheck = trainPresaleAvailabilityFromOfficialPayloadForTest(
        recheckRequest(), stationPayload, payload);
      const firstRequest = recheckRequest();
      firstRequest.seatPriority = '一等座';
      const first: TrainPresaleAvailabilityCheck = trainPresaleAvailabilityFromOfficialPayloadForTest(
        firstRequest, stationPayload, payload);
      const soldOutPayload = '{"status":true,"data":{"result":[' +
        JSON.stringify(trainRow('G1', 'VNP', 'AOH', '无', '3')) + ']}}';
      const soldOut: TrainPresaleAvailabilityCheck = trainPresaleAvailabilityFromOfficialPayloadForTest(
        recheckRequest(), stationPayload, soldOutPayload);

      expect(verified.status).assertEqual('verified');
      expect(verified.bookingUrl.indexOf('%E5%8C%97%E4%BA%AC%E5%8D%97,VNP') >= 0).assertTrue();
      expect(first.status).assertEqual('verified');
      expect(soldOut.status).assertEqual('sold_out');
    });

    it('rejects a stored station name/code mismatch before accepting a row', 0, () => {
      const row = trainRow('G1', 'VNP', 'AOH', '有');
      const payload = '{"status":true,"data":{"result":[' + JSON.stringify(row) + ']}}';
      const request = recheckRequest();
      request.fromName = '北京站';
      const result: TrainPresaleAvailabilityCheck = trainPresaleAvailabilityFromOfficialPayloadForTest(
        request,
        '@bjn|北京南|VNP|beijingnan|bjn@shh|上海虹桥|AOH|shanghaihongqiao|shh',
        payload
      );

      expect(result.status).assertEqual('mismatch');
      expect(result.reason.indexOf('车站') >= 0).assertTrue();
    });

    it('classifies empty or changed station payloads as provider schema errors', 0, () => {
      const payload = '{"status":true,"data":{"result":[]}}';
      const empty: TrainPresaleAvailabilityCheck = trainPresaleAvailabilityFromOfficialPayloadForTest(
        recheckRequest(), '', payload);
      const changed: TrainPresaleAvailabilityCheck = trainPresaleAvailabilityFromOfficialPayloadForTest(
        recheckRequest(), '@bjn|北京南|NOT-A-CODE|beijingnan|bjn', payload);

      expect(empty.status).assertEqual('provider_error');
      expect(changed.status).assertEqual('provider_error');
    });

    it('rejects a truncated exact result row before interpreting its seat as sold out', 0, () => {
      const fields: string[] = [];
      for (let index = 0; index < 12; index++) {
        fields.push('');
      }
      fields[3] = 'G1';
      fields[6] = 'VNP';
      fields[7] = 'AOH';
      fields[11] = 'Y';
      const payload = '{"status":true,"data":{"result":[' + JSON.stringify(fields.join('|')) + ']}}';
      const stationPayload = '@bjn|北京南|VNP|beijingnan|bjn@shh|上海虹桥|AOH|shanghaihongqiao|shh';

      const result: TrainPresaleAvailabilityCheck = trainPresaleAvailabilityFromOfficialPayloadForTest(
        recheckRequest(), stationPayload, payload);

      expect(result.status).assertEqual('provider_error');
    });

    it('rejects a non-string official result row as a provider schema error', 0, () => {
      const stationPayload = '@bjn|北京南|VNP|beijingnan|bjn@shh|上海虹桥|AOH|shanghaihongqiao|shh';
      const payload = '{"status":true,"data":{"result":[123]}}';

      const result: TrainPresaleAvailabilityCheck = trainPresaleAvailabilityFromOfficialPayloadForTest(
        recheckRequest(), stationPayload, payload);

      expect(result.status).assertEqual('provider_error');
    });

    it('keeps valid no-train and empty-seat rows as mismatch and sold out', 0, () => {
      const stationPayload = '@bjn|北京南|VNP|beijingnan|bjn@shh|上海虹桥|AOH|shanghaihongqiao|shh';
      const noTrainPayload = '{"status":true,"data":{"result":[' +
        JSON.stringify(trainRow('G2', 'VNP', 'AOH', '有')) + ']}}';
      const emptySeatPayload = '{"status":true,"data":{"result":[' +
        JSON.stringify(trainRow('G1', 'VNP', 'AOH', '')) + ']}}';

      const noTrain: TrainPresaleAvailabilityCheck = trainPresaleAvailabilityFromOfficialPayloadForTest(
        recheckRequest(), stationPayload, noTrainPayload);
      const emptySeat: TrainPresaleAvailabilityCheck = trainPresaleAvailabilityFromOfficialPayloadForTest(
        recheckRequest(), stationPayload, emptySeatPayload);

      expect(noTrain.status).assertEqual('mismatch');
      expect(emptySeat.status).assertEqual('sold_out');
    });
  });
}
