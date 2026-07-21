import { describe, expect, it } from '@ohos/hypium';
import { preferences } from '@kit.ArkData';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import {
  current12306BeijingDate,
  TrainPresaleDebugSelection,
  TrainPresaleDebugSelectionRequest,
  trainPresaleDebugSelectionFromOfficialPayloadForTest
} from '@loop/agent-core';
import {
  prepareTrainPresaleDebugConfirmation,
  readTrainPresaleDebugBuildState,
  runTrainPresaleDebugConfirmation,
  scheduleTrainPresaleTask,
  trainPresaleDebugActionVisible,
  TrainPresaleDebugConfirmationInput,
  TrainPresaleDebugRunInput
} from '../main/ets/pages/A2uiHome/components/TrainPresalePanel';
import { SystemOneShotScheduler } from '../main/ets/pages/A2uiHome/train/SystemOneShotScheduler';
import {
  TrainPresaleTask,
  TrainPresaleTaskState,
  TrainPresaleTaskStore
} from '../main/ets/pages/A2uiHome/train/TrainPresaleTaskStore';

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

class EpochSequence {
  private values: number[];
  private index: number = 0;

  constructor(values: number[]) {
    this.values = values;
  }

  now(): number {
    const offset = this.index < this.values.length ? this.index : this.values.length - 1;
    this.index++;
    return this.values[offset];
  }
}

class MemoryPreferences {
  private value: preferences.ValueType = '';
  reads: number = 0;

  getSync(_key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    this.reads++;
    return this.value === '' ? defaultValue : this.value;
  }

  putSync(_key: string, value: preferences.ValueType): void {
    this.value = value;
  }

  flushSync(): void {}
}

function request(): TrainPresaleDebugSelectionRequest {
  return {
    fromName: '北京南',
    fromCode: 'VNP',
    toName: '上海虹桥',
    toCode: 'AOH',
    seatPriority: '二等座'
  };
}

function confirmation(): TrainPresaleDebugConfirmationInput {
  return {
    debugEnabled: true,
    debugConfirmed: true,
    fromName: '北京南',
    fromCode: 'VNP',
    toName: '上海虹桥',
    toCode: 'AOH',
    passengerNames: ['张三'],
    seatPriority: '二等座',
    unpaidOrderAuthorized: true,
    taskId: 'debug-1',
    createdAt: '2026-07-22T04:00:00.000Z'
  };
}

function runInput(): TrainPresaleDebugRunInput {
  return {
    debugEnabled: true,
    debugConfirmed: true,
    fromName: '北京南',
    fromCode: 'VNP',
    toName: '上海虹桥',
    toCode: 'AOH',
    passengerNames: ['张三'],
    seatPriority: '二等座',
    unpaidOrderAuthorized: true
  };
}

function activeDebugTask(state: TrainPresaleTaskState = 'scheduled'): TrainPresaleTask {
  return {
    taskId: 'debug-existing',
    source: 'debug',
    state: state,
    trainCode: 'G1',
    travelDate: '2026-07-22',
    fromName: '北京南',
    fromCode: 'VNP',
    toName: '上海虹桥',
    toCode: 'AOH',
    saleAt: '2026-07-22T12:00:10+08:00',
    passengerNames: ['张三'],
    seatPriority: '二等座',
    unpaidOrderAuthorized: true,
    bookingUrl: verifiedSelection().bookingUrl,
    reminderId: state === 'scheduled' ? 88 : -1,
    createdAt: '2026-07-22T04:00:00.000Z',
    lastError: state === 'needs_user' ? '需要用户处理' : ''
  };
}

function testScheduler(onPublish: () => void): SystemOneShotScheduler {
  return new SystemOneShotScheduler(
    async (_reminder: reminderAgentManager.ReminderRequestCalendar): Promise<number> => {
      onPublish();
      return 88;
    },
    async (_reminderId: number): Promise<void> => {},
    async (): Promise<reminderAgentManager.ReminderRequest[]> => []
  );
}

function verifiedSelection(): TrainPresaleDebugSelection {
  return {
    status: 'verified',
    reason: '',
    trainCode: 'G1',
    travelDate: '2026-07-22',
    fromName: '北京南',
    fromCode: 'VNP',
    toName: '上海虹桥',
    toCode: 'AOH',
    seatPriority: '二等座',
    bookingUrl: 'https://kyfw.12306.cn/otn/leftTicket/init?linktypeid=dc&fs=%E5%8C%97%E4%BA%AC%E5%8D%97,VNP&ts=%E4%B8%8A%E6%B5%B7%E8%99%B9%E6%A1%A5,AOH&date=2026-07-22&flag=N,N,Y'
  };
}

function selectedTrain(trainCode: string, seatPriority: string = '二等座'): TrainPresaleDebugSelection {
  const selection = verifiedSelection();
  selection.trainCode = trainCode;
  selection.seatPriority = seatPriority;
  return selection;
}

function trainRow(trainCode: string, fromCode: string, toCode: string, second: string, canBook: string = 'Y'): string {
  const fields: string[] = [];
  for (let index = 0; index < 40; index++) {
    fields.push('');
  }
  fields[1] = '预订';
  fields[3] = trainCode;
  fields[6] = fromCode;
  fields[7] = toCode;
  fields[8] = '09:00';
  fields[9] = '13:30';
  fields[10] = '04:30';
  fields[11] = canBook;
  fields[30] = second;
  return fields.join('|');
}

export default function trainPresaleDebugTest() {
  describe('trainPresaleDebug', () => {
    it('reads the real runtime debug seam as true only for an explicit appInfo debug flag', 0, () => {
      expect(readTrainPresaleDebugBuildState((): boolean | undefined => true)).assertTrue();
      expect(readTrainPresaleDebugBuildState((): boolean | undefined => false)).assertFalse();
      expect(readTrainPresaleDebugBuildState((): boolean | undefined => undefined)).assertFalse();
      expect(readTrainPresaleDebugBuildState((): boolean | undefined => {
        throw new Error('bundle unavailable');
      })).assertFalse();
    });

    it('uses fixed Beijing dates across UTC midnight and the Beijing day boundary', 0, () => {
      expect(current12306BeijingDate(
        (): number => new Date('2026-07-22T15:59:59.000Z').getTime())).assertEqual('2026-07-22');
      expect(current12306BeijingDate(
        (): number => new Date('2026-07-22T16:00:00.000Z').getTime())).assertEqual('2026-07-23');
    });

    it('hides the action and rejects the handler before provider access outside debug builds', 0, async () => {
      expect(trainPresaleDebugActionVisible(false)).assertFalse();
      expect(trainPresaleDebugActionVisible(true)).assertTrue();
      const input = confirmation();
      input.debugEnabled = false;
      let providerCalls = 0;

      const result = await prepareTrainPresaleDebugConfirmation(input,
        async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => {
          providerCalls++;
          return verifiedSelection();
        });

      expect(result.task).assertEqual(undefined);
      expect(result.error).assertEqual('当前版本不允许调试测试。');
      expect(providerCalls).assertEqual(0);
    });

    it('treats an unconfirmed or cancelled second confirmation as no provider and no task', 0, async () => {
      const input = confirmation();
      input.debugConfirmed = false;
      let providerCalls = 0;

      const result = await prepareTrainPresaleDebugConfirmation(input,
        async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => {
          providerCalls++;
          return verifiedSelection();
        });

      expect(result.task).assertEqual(undefined);
      expect(result.error).assertEqual('请再次确认将创建真实未支付订单，支付仍需手动完成。');
      expect(providerCalls).assertEqual(0);
    });

    it('keeps production orchestration closed before provider and scheduler without debug confirmation', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const input = runInput();
      input.debugEnabled = false;
      let providerCalls = 0;
      let publishCalls = 0;

      const nonDebug = await runTrainPresaleDebugConfirmation(
        input,
        store,
        testScheduler((): void => { publishCalls++; }),
        async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => {
          providerCalls++;
          return verifiedSelection();
        },
        (): number => new Date('2026-07-22T04:00:00.000Z').getTime()
      );

      expect(nonDebug.task).assertEqual(undefined);
      expect(providerCalls).assertEqual(0);
      expect(publishCalls).assertEqual(0);

      input.debugEnabled = true;
      input.debugConfirmed = false;
      const result = await runTrainPresaleDebugConfirmation(
        input,
        store,
        testScheduler((): void => { publishCalls++; }),
        async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => {
          providerCalls++;
          return verifiedSelection();
        },
        (): number => new Date('2026-07-22T04:00:00.000Z').getTime()
      );

      expect(result.task).assertEqual(undefined);
      expect(providerCalls).assertEqual(0);
      expect(publishCalls).assertEqual(0);
      expect(store.list().length).assertEqual(0);
    });

    it('rejects every unsafe debug input before store, provider, or scheduler access', 0, async () => {
      const invalidInputs: TrainPresaleDebugRunInput[] = [];
      const unauthorized = runInput();
      unauthorized.unpaidOrderAuthorized = false;
      invalidInputs.push(unauthorized);
      const missingPassenger = runInput();
      missingPassenger.passengerNames = ['  '];
      invalidInputs.push(missingPassenger);
      const duplicatePassenger = runInput();
      duplicatePassenger.passengerNames = ['张三', ' 张三 '];
      invalidInputs.push(duplicatePassenger);
      const invalidPassengerSchema = runInput();
      invalidPassengerSchema.passengerNames = [null] as Object as string[];
      invalidInputs.push(invalidPassengerSchema);
      const unsupportedSeat = runInput();
      unsupportedSeat.seatPriority = '靠窗座';
      invalidInputs.push(unsupportedSeat);
      const invalidRoute = runInput();
      invalidRoute.toCode = invalidRoute.fromCode;
      invalidInputs.push(invalidRoute);

      for (let index = 0; index < invalidInputs.length; index++) {
        const native = new MemoryPreferences();
        const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
        let providerCalls = 0;
        let publishCalls = 0;
        const result = await runTrainPresaleDebugConfirmation(
          invalidInputs[index], store, testScheduler((): void => { publishCalls++; }),
          async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => {
            providerCalls++;
            return verifiedSelection();
          },
          (): number => new Date('2026-07-22T04:00:00.000Z').getTime());

        expect(result.task).assertEqual(undefined);
        expect(native.reads).assertEqual(0);
        expect(providerCalls).assertEqual(0);
        expect(publishCalls).assertEqual(0);
      }
    });

    it('selects only a real bookable high-speed train with exact official identity and seat inventory', 0, () => {
      const stations = '@bjn|北京南|VNP|beijingnan|bjn|0@shh|上海虹桥|AOH|shanghaihongqiao|shhq|1';
      const payload = '{"status":true,"data":{"result":[' +
        JSON.stringify(trainRow('K1', 'VNP', 'AOH', '有')) + ',' +
        JSON.stringify(trainRow('G2', 'VNP', 'AOH', '无')) + ',' +
        JSON.stringify(trainRow('G1', 'VNP', 'AOH', '3')) + ']}}';

      const result = trainPresaleDebugSelectionFromOfficialPayloadForTest(
        request(), '2026-07-22', stations, payload);

      expect(result.status).assertEqual('verified');
      expect(result.trainCode).assertEqual('G1');
      expect(result.travelDate).assertEqual('2026-07-22');
      expect(result.fromCode).assertEqual('VNP');
      expect(result.toCode).assertEqual('AOH');
      expect(result.bookingUrl.indexOf('date=2026-07-22')).assertLarger(-1);
    });

    it('never falls back to a hardcoded train when official inventory has no candidate', 0, () => {
      const stations = '@bjn|北京南|VNP|beijingnan|bjn|0@shh|上海虹桥|AOH|shanghaihongqiao|shhq|1';
      const result = trainPresaleDebugSelectionFromOfficialPayloadForTest(
        request(), '2026-07-22', stations,
        '{"status":true,"data":{"result":[' +
          JSON.stringify(trainRow('G1', 'VNP', 'AOH', '无')) + ']}}');

      expect(result.status).assertEqual('sold_out');
      expect(result.trainCode).assertEqual('');
      expect(result.travelDate).assertEqual('');
      expect(result.bookingUrl).assertEqual('');
      expect(result.reason.length > 0).assertTrue();
    });

    it('returns provider schema errors without creating a task', 0, async () => {
      const input = confirmation();
      const providerFailure = verifiedSelection();
      providerFailure.status = 'provider_error';
      providerFailure.reason = '12306 余票响应缺少有效结果。';
      providerFailure.trainCode = '';
      providerFailure.travelDate = '';
      providerFailure.bookingUrl = '';

      const result = await prepareTrainPresaleDebugConfirmation(input,
        async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => providerFailure);

      expect(result.task).assertEqual(undefined);
      expect(result.error).assertEqual('12306 余票响应缺少有效结果。');
    });

    it('converts a thrown provider failure into a truthful non-task result', 0, async () => {
      const result = await prepareTrainPresaleDebugConfirmation(confirmation(),
        async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => {
          throw new Error('network unavailable');
        });

      expect(result.task).assertEqual(undefined);
      expect(result.error).assertEqual('12306 调试车次查询失败：network unavailable');
    });

    it('computes the ten-second fire time from fresh provider success time', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const clock = new EpochSequence([
        new Date('2026-07-22T04:00:00.000Z').getTime(),
        new Date('2026-07-22T04:00:30.000Z').getTime(),
        new Date('2026-07-22T04:00:30.100Z').getTime()
      ]);
      const events: string[] = [];

      const result = await runTrainPresaleDebugConfirmation(
        runInput(), store, testScheduler((): void => { events.push('schedule'); }),
        async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => {
          events.push('provider');
          return verifiedSelection();
        },
        (): number => clock.now(), (): string => 'fresh-clock');

      expect(result.task?.createdAt).assertEqual('2026-07-22T04:00:30.000Z');
      expect(result.task?.saleAt).assertEqual('2026-07-22T12:00:40+08:00');
      expect(result.task?.source).assertEqual('debug');
      expect(events.join(',')).assertEqual('provider,schedule');
    });

    it('fails closed before persistence when the fresh fire time has expired', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const clock = new EpochSequence([
        new Date('2026-07-22T04:00:00.000Z').getTime(),
        new Date('2026-07-22T04:00:30.000Z').getTime(),
        new Date('2026-07-22T04:00:40.000Z').getTime()
      ]);
      let publishCalls = 0;

      const result = await runTrainPresaleDebugConfirmation(
        runInput(), store, testScheduler((): void => { publishCalls++; }),
        async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => verifiedSelection(),
        (): number => clock.now(), (): string => 'expired-clock');

      expect(result.task).assertEqual(undefined);
      expect(result.error).assertEqual('10秒测试触发时间已过，请重新确认。');
      expect(store.list().length).assertEqual(0);
      expect(publishCalls).assertEqual(0);
    });

    it('fails closed on an invalid epoch before provider access', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      let providerCalls = 0;

      const result = await runTrainPresaleDebugConfirmation(
        runInput(), store, testScheduler((): void => {}),
        async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => {
          providerCalls++;
          return verifiedSelection();
        },
        (): number => Number.NaN);

      expect(result.task).assertEqual(undefined);
      expect(result.error).assertEqual('无法读取10秒测试时间，请重试。');
      expect(providerCalls).assertEqual(0);
      expect(store.list().length).assertEqual(0);
    });

    it('fails closed when a provider result crosses the Beijing travel-date boundary', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const clock = new EpochSequence([
        new Date('2026-07-22T15:59:59.000Z').getTime(),
        new Date('2026-07-22T16:00:01.000Z').getTime()
      ]);

      const result = await runTrainPresaleDebugConfirmation(
        runInput(), store, testScheduler((): void => {}),
        async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => verifiedSelection(),
        (): number => clock.now(), (): string => 'beijing-boundary');

      expect(result.task).assertEqual(undefined);
      expect(result.error).assertEqual('12306 返回的调试车次日期已不是当前北京时间日期，请重新确认。');
      expect(store.list().length).assertEqual(0);
    });

    it('reselects the exact train before reusing every active debug state after reopen', 0, async () => {
      const states: TrainPresaleTaskState[] = ['scheduled', 'executing', 'awaiting_payment', 'needs_user'];
      for (let index = 0; index < states.length; index++) {
        const native = new MemoryPreferences();
        new TrainPresaleTaskStore(native as Object as preferences.Preferences).create(activeDebugTask(states[index]));
        const reopened = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
        let providerCalls = 0;
        let publishCalls = 0;

        const result = await runTrainPresaleDebugConfirmation(
          runInput(), reopened, testScheduler((): void => { publishCalls++; }),
          async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => {
            providerCalls++;
            return verifiedSelection();
          },
          (): number => new Date('2026-07-22T04:01:00.000Z').getTime(),
          (): string => 'reopen-' + index.toString());

        expect(result.task?.taskId).assertEqual('debug-existing');
        expect(result.task?.state).assertEqual(states[index]);
        expect(result.error.indexOf('已有10秒测试任务')).assertLarger(-1);
        expect(providerCalls).assertEqual(1);
        expect(publishCalls).assertEqual(0);
        expect(reopened.list().length).assertEqual(1);
      }
    });

    it('does not reuse an old train when the live selector now returns another train', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      store.create(activeDebugTask('scheduled'));
      let providerCalls = 0;
      let publishCalls = 0;

      const result = await runTrainPresaleDebugConfirmation(
        runInput(), store, testScheduler((): void => { publishCalls++; }),
        async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => {
          providerCalls++;
          return selectedTrain('G2');
        },
        (): number => new Date('2026-07-22T04:01:00.000Z').getTime(),
        (): string => 'new-train');

      expect(providerCalls).assertEqual(1);
      expect(publishCalls).assertEqual(1);
      expect(result.task?.trainCode).assertEqual('G2');
      expect(store.list().length).assertEqual(2);
    });

    it('allows a new demo after cancellation but not a duplicate with a different fire time', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      store.create(activeDebugTask('cancelled'));
      let publishCalls = 0;

      const created = await runTrainPresaleDebugConfirmation(
        runInput(), store, testScheduler((): void => { publishCalls++; }),
        async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => verifiedSelection(),
        (): number => new Date('2026-07-22T04:02:00.000Z').getTime(),
        (): string => 'after-cancel');

      expect(created.task?.state).assertEqual('scheduled');
      expect(store.list().length).assertEqual(2);
      expect(publishCalls).assertEqual(1);

      const duplicate = activeDebugTask('scheduled');
      duplicate.taskId = 'debug-later';
      duplicate.saleAt = '2026-07-22T12:09:10+08:00';
      duplicate.createdAt = '2026-07-22T04:09:00.000Z';
      duplicate.reminderId = -1;
      const duplicateResult = await scheduleTrainPresaleTask(
        duplicate, store, testScheduler((): void => { publishCalls++; }));

      expect(duplicateResult.task?.taskId).assertEqual(created.task?.taskId);
      expect(duplicateResult.error.indexOf('已有')).assertLarger(-1);
      expect(publishCalls).assertEqual(1);
      expect(store.list().length).assertEqual(2);
    });

    it('serializes two slow-provider confirmations into one durable task and one reminder', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const gate = new TestGate();
      let providerCalls = 0;
      let publishCalls = 0;
      const selector = async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => {
        providerCalls++;
        await gate.promise;
        return verifiedSelection();
      };
      const scheduler = testScheduler((): void => { publishCalls++; });
      const clock = (): number => new Date('2026-07-22T04:03:00.000Z').getTime();

      const firstPromise = runTrainPresaleDebugConfirmation(
        runInput(), store, scheduler, selector, clock, (): string => 'same-a');
      const secondPromise = runTrainPresaleDebugConfirmation(
        runInput(), store, scheduler, selector, clock, (): string => 'same-b');
      gate.open();
      const first = await firstPromise;
      const second = await secondPromise;

      expect(providerCalls).assertEqual(2);
      expect(publishCalls).assertEqual(1);
      expect(store.list().length).assertEqual(1);
      expect(first.task?.taskId).assertEqual(second.task?.taskId);
      expect(first.task?.state).assertEqual('scheduled');
      expect(second.error.indexOf('已有')).assertLarger(-1);
    });

    it('keeps same-millisecond confirmations for different passengers isolated', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      let publishCalls = 0;
      const scheduler = testScheduler((): void => { publishCalls++; });
      const firstInput = runInput();
      const secondInput = runInput();
      secondInput.passengerNames = ['李四'];
      const selector = async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> =>
        verifiedSelection();
      const clock = (): number => new Date('2026-07-22T04:03:00.000Z').getTime();

      const results = await Promise.all([
        runTrainPresaleDebugConfirmation(firstInput, store, scheduler, selector, clock, (): string => 'passenger-a'),
        runTrainPresaleDebugConfirmation(secondInput, store, scheduler, selector, clock, (): string => 'passenger-b')
      ]);

      expect(results[0].task?.taskId === results[1].task?.taskId).assertFalse();
      expect(store.list().length).assertEqual(2);
      expect(store.list()[0].state).assertEqual('scheduled');
      expect(store.list()[1].state).assertEqual('scheduled');
      expect(publishCalls).assertEqual(2);
    });

    it('keeps same-millisecond confirmations for different seats isolated', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      let publishCalls = 0;
      const scheduler = testScheduler((): void => { publishCalls++; });
      const secondClass = runInput();
      const firstClass = runInput();
      firstClass.seatPriority = '一等座';
      const clock = (): number => new Date('2026-07-22T04:03:00.000Z').getTime();

      const results = await Promise.all([
        runTrainPresaleDebugConfirmation(secondClass, store, scheduler,
          async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => selectedTrain('G1'),
          clock, (): string => 'seat-a'),
        runTrainPresaleDebugConfirmation(firstClass, store, scheduler,
          async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> =>
            selectedTrain('G1', '一等座'), clock, (): string => 'seat-b')
      ]);

      expect(results[0].task?.taskId === results[1].task?.taskId).assertFalse();
      expect(store.list().length).assertEqual(2);
      expect(publishCalls).assertEqual(2);
    });

    it('keeps same-millisecond confirmations for different trains isolated', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      let publishCalls = 0;
      const scheduler = testScheduler((): void => { publishCalls++; });
      const clock = (): number => new Date('2026-07-22T04:03:00.000Z').getTime();

      const results = await Promise.all([
        runTrainPresaleDebugConfirmation(runInput(), store, scheduler,
          async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => selectedTrain('G1'),
          clock, (): string => 'train-a'),
        runTrainPresaleDebugConfirmation(runInput(), store, scheduler,
          async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => selectedTrain('G2'),
          clock, (): string => 'train-b')
      ]);

      expect(results[0].task?.taskId === results[1].task?.taskId).assertFalse();
      expect(store.list().length).assertEqual(2);
      expect(publishCalls).assertEqual(2);
    });

    it('does not cancel or mutate another debug identity when reservation id creation collides', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const owner = activeDebugTask('needs_user');
      owner.taskId = 'collision';
      store.create(owner);
      const contender = activeDebugTask('scheduled');
      contender.taskId = 'collision';
      contender.trainCode = 'G2';
      contender.passengerNames = ['李四'];
      let publishCalls = 0;

      const result = await scheduleTrainPresaleTask(
        contender, store, testScheduler((): void => { publishCalls++; }));
      const persisted = store.get('collision');

      expect(result.task).assertEqual(undefined);
      expect(result.error.indexOf('任务编号冲突')).assertLarger(-1);
      expect(persisted?.trainCode).assertEqual('G1');
      expect(persisted?.passengerNames[0]).assertEqual('张三');
      expect(persisted?.state).assertEqual('needs_user');
      expect(persisted?.lastError).assertEqual('需要用户处理');
      expect(publishCalls).assertEqual(0);
    });

    it('creates a durable debug task for ten seconds later through the production scheduler seam', 0, async () => {
      const prepared = await prepareTrainPresaleDebugConfirmation(confirmation(),
        async (_request: TrainPresaleDebugSelectionRequest): Promise<TrainPresaleDebugSelection> => verifiedSelection());
      expect(prepared.error).assertEqual('');
      expect(prepared.task?.source).assertEqual('debug');
      expect(prepared.task?.saleAt).assertEqual('2026-07-22T12:00:10+08:00');
      expect(prepared.task?.unpaidOrderAuthorized).assertTrue();
      if (prepared.task === undefined) {
        return;
      }

      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      let publishedTaskId = '';
      let publishedSecond = -1;
      const scheduler = new SystemOneShotScheduler(
        async (reminder: reminderAgentManager.ReminderRequestCalendar): Promise<number> => {
          publishedTaskId = reminder.wantAgent?.parameters?.trainPresaleTaskId as string;
          publishedSecond = reminder.dateTime.second === undefined ? -1 : reminder.dateTime.second;
          return 88;
        },
        async (_reminderId: number): Promise<void> => {},
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const scheduled = await scheduleTrainPresaleTask(prepared.task, store, scheduler);

      expect(scheduled.error).assertEqual('');
      expect(scheduled.task?.state).assertEqual('scheduled');
      expect(scheduled.task?.source).assertEqual('debug');
      expect(scheduled.task?.reminderId).assertEqual(88);
      expect(store.get('debug-1')?.source).assertEqual('debug');
      expect(publishedTaskId).assertEqual('debug-1');
      expect(publishedSecond).assertEqual(10);
    });
  });
}
