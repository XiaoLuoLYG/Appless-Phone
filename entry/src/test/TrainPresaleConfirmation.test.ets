import { describe, it, expect } from '@ohos/hypium';
import { preferences } from '@kit.ArkData';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import {
  cancelScheduledTrainPresaleTask,
  findMatchingTrainPresaleTask,
  reconcileTrainPresaleTask,
  scheduleTrainPresaleTask,
  TrainPresaleConfirmationInput,
  TrainPresaleReconcileResult,
  validateTrainPresaleConfirmation,
  validateTrainPresaleTrip
} from '../main/ets/pages/A2uiHome/components/TrainPresalePanel';
import {
  buildReminderRequest,
  ListedReminderRequest,
  SystemOneShotScheduler
} from '../main/ets/pages/A2uiHome/train/SystemOneShotScheduler';
import { TrainPresaleTask, TrainPresaleTaskStore } from '../main/ets/pages/A2uiHome/train/TrainPresaleTaskStore';

class MemoryPreferences {
  private value: preferences.ValueType = '';
  private writes: number = 0;
  private flushes: number = 0;
  failWrites: boolean = false;
  failWriteAt: number = 0;
  failFlushes: number = 0;
  failFlushAt: number = 0;

  getSync(_key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    return this.value === '' ? defaultValue : this.value;
  }

  putSync(_key: string, value: preferences.ValueType): void {
    this.writes++;
    if (this.failWrites || this.failWriteAt === this.writes) {
      throw new Error('persist failed');
    }
    this.value = value;
  }

  flushSync(): void {
    this.flushes++;
    if (this.failFlushes > 0) {
      this.failFlushes--;
      throw new Error('persist failed');
    }
    if (this.failFlushAt === this.flushes) {
      throw new Error('persist failed');
    }
  }
}

class DuplicateInjectingStore extends TrainPresaleTaskStore {
  private duplicate: TrainPresaleTask;

  constructor(store: preferences.Preferences, duplicate: TrainPresaleTask) {
    super(store);
    this.duplicate = duplicate;
  }

  create(value: TrainPresaleTask): void {
    super.create(value);
    super.create(this.duplicate);
  }
}

function task(): TrainPresaleTask {
  const result = validateTrainPresaleConfirmation(validInput());
  if (result.task === undefined) {
    throw new Error(result.error);
  }
  return result.task;
}

function listedReminder(value: TrainPresaleTask, reminderId: number): ListedReminderRequest {
  const request = buildReminderRequest(value, value.saleAt) as Object as ListedReminderRequest;
  request.reminderId = reminderId;
  return request;
}

function validInput(): TrainPresaleConfirmationInput {
  return {
    source: 'presale',
    trainCode: 'G1',
    travelDate: '2026-08-06',
    fromName: '北京南',
    fromCode: 'VNP',
    toName: '上海虹桥',
    toCode: 'AOH',
    saleAt: '2026-08-06T12:45:00+08:00',
    passengerNames: [' 张三 '],
    seatPriority: '二等座',
    unpaidOrderAuthorized: true,
    debugEnabled: false,
    taskId: 'train-1',
    createdAt: '2026-07-22T02:00:00.000Z'
  };
}

export default function trainPresaleConfirmationTest() {
  describe('trainPresaleConfirmation', () => {
    it('builds a sanitized task with an official booking URL', 0, () => {
      const result = validateTrainPresaleConfirmation(validInput());
      expect(result.error).assertEqual('');
      expect(result.task === undefined).assertFalse();
      if (result.task !== undefined) {
        expect(result.task.passengerNames.length).assertEqual(1);
        expect(result.task.passengerNames[0]).assertEqual('张三');
        expect(result.task.bookingUrl.startsWith('https://kyfw.12306.cn/otn/leftTicket/init?')).assertTrue();
        expect(result.task.bookingUrl.indexOf('date=2026-08-06')).assertLarger(-1);
      }
    });

    it('does not infer a missing passenger', 0, () => {
      const input = validInput();
      input.passengerNames = ['  '];
      const result = validateTrainPresaleConfirmation(input);
      expect(result.task).assertEqual(undefined);
      expect(result.error).assertEqual('请填写至少一位乘车人姓名。');
    });

    it('rejects duplicate passengers before reporting confirmation success', 0, () => {
      const duplicate = validInput();
      duplicate.passengerNames = ['张三', '张三'];
      const whitespaceDuplicate = validInput();
      whitespaceDuplicate.passengerNames = ['张三', ' 张三 '];

      expect(validateTrainPresaleConfirmation(duplicate).task).assertEqual(undefined);
      expect(validateTrainPresaleConfirmation(duplicate).error).assertEqual('乘车人姓名不能重复。');
      expect(validateTrainPresaleConfirmation(whitespaceDuplicate).task).assertEqual(undefined);
      expect(validateTrainPresaleConfirmation(whitespaceDuplicate).error).assertEqual('乘车人姓名不能重复。');
    });

    it('rejects an unsupported seat preference', 0, () => {
      const input = validInput();
      input.seatPriority = '靠窗座';
      const result = validateTrainPresaleConfirmation(input);
      expect(result.task).assertEqual(undefined);
      expect(result.error).assertEqual('请选择支持的席别。');
    });

    it('rejects invalid verified train, date, route, or sale time', 0, () => {
      const invalidTrain = validInput();
      invalidTrain.trainCode = '火车';
      expect(validateTrainPresaleConfirmation(invalidTrain).task).assertEqual(undefined);

      const invalidDate = validInput();
      invalidDate.travelDate = '2026-02-30';
      expect(validateTrainPresaleConfirmation(invalidDate).task).assertEqual(undefined);

      const invalidRoute = validInput();
      invalidRoute.toCode = invalidRoute.fromCode;
      expect(validateTrainPresaleConfirmation(invalidRoute).task).assertEqual(undefined);

      const invalidSaleAt = validInput();
      invalidSaleAt.saleAt = '2026-08-06 12:45';
      expect(validateTrainPresaleConfirmation(invalidSaleAt).task).assertEqual(undefined);

      const invalidClock = validInput();
      invalidClock.saleAt = '2026-08-06T24:00:00+08:00';
      expect(validateTrainPresaleConfirmation(invalidClock).task).assertEqual(undefined);

      const stale = validInput();
      stale.createdAt = '2026-08-06T04:45:01.000Z';
      expect(validateTrainPresaleConfirmation(stale).error).assertEqual('开售时间已过，请重新查询。');
    });

    it('requires explicit real unpaid-order authorization', 0, () => {
      const input = validInput();
      input.unpaidOrderAuthorized = false;
      const result = validateTrainPresaleConfirmation(input);
      expect(result.task).assertEqual(undefined);
      expect(result.error).assertEqual('请明确授权在开售时提交真实未支付订单。');
    });

    it('requires debug availability while using durable authorization as the only order gate', 0, () => {
      const input = validInput();
      input.source = 'debug';
      expect(validateTrainPresaleConfirmation(input).error).assertEqual('当前版本不允许调试测试。');

      input.debugEnabled = true;
      expect(validateTrainPresaleConfirmation(input).task === undefined).assertFalse();
    });

    it('validates a future trip before panel display', 0, () => {
      const input = validInput();
      const result = validateTrainPresaleTrip(input, input.createdAt);
      expect(result.error).assertEqual('');
      expect(result.trip === undefined).assertFalse();

      const stale = validInput();
      stale.travelDate = '2026-07-22';
      stale.saleAt = '2026-07-22T09:59:59+08:00';
      expect(validateTrainPresaleTrip(stale, '2026-07-22T02:00:00.000Z').error)
        .assertEqual('开售时间已过，请重新查询。');
    });

    it('finds one exact non-cancelled task with furthest-progress state priority', 0, () => {
      const exact = task();
      exact.reminderId = 73;
      const reservation = task();
      reservation.taskId = 'reservation';
      reservation.state = 'needs_user';
      reservation.reminderId = -1;
      const otherRoute = task();
      otherRoute.taskId = 'other-route';
      otherRoute.reminderId = 74;
      otherRoute.toCode = 'BJP';
      const awaitingPayment = task();
      awaitingPayment.taskId = 'awaiting-payment';
      awaitingPayment.state = 'awaiting_payment';
      awaitingPayment.reminderId = 75;

      expect(findMatchingTrainPresaleTask([reservation, otherRoute, exact, awaitingPayment], validInput())?.taskId)
        .assertEqual('awaiting-payment');
      const changedSaleTime = validInput();
      changedSaleTime.saleAt = '2026-08-06T13:00:00+08:00';
      expect(findMatchingTrainPresaleTask([exact], changedSaleTime)).assertEqual(undefined);
      exact.state = 'cancelled';
      expect(findMatchingTrainPresaleTask([exact], validInput())).assertEqual(undefined);
    });

    it('finds the persisted task after store reopen so the action does not publish a duplicate', 0, () => {
      const native = new MemoryPreferences();
      const firstStore = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const scheduled = task();
      scheduled.reminderId = 73;
      firstStore.create(scheduled);

      const reopenedStore = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const existing = findMatchingTrainPresaleTask(reopenedStore.list(), validInput());

      expect(existing?.taskId).assertEqual('train-1');
      expect(reopenedStore.list().length).assertEqual(1);
    });

    it('restores a durable needs-user cancellation state instead of allowing a duplicate', 0, () => {
      const attention = task();
      attention.reminderId = 73;
      attention.state = 'needs_user';

      const existing = findMatchingTrainPresaleTask([attention], validInput());

      expect(existing?.taskId).assertEqual('train-1');
      expect(existing?.state).assertEqual('needs_user');
    });

    it('persists and verifies a truthful reservation immediately before publishing', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      let reservationAtPublish = false;
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => {
          const reserved = store.get('train-1');
          reservationAtPublish = reserved?.state === 'needs_user' && reserved.reminderId === -1 &&
            reserved.lastError.indexOf('正在创建') >= 0;
          return 73;
        },
        async (): Promise<void> => {},
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const result = await scheduleTrainPresaleTask(task(), store, scheduler);

      expect(reservationAtPublish).assertTrue();
      expect(result.error).assertEqual('');
      expect(result.task?.reminderId).assertEqual(73);
      expect(store.get('train-1')?.reminderId).assertEqual(73);
    });

    it('does not publish or expose an actionable task when reservation persistence fails', 0, async () => {
      const native = new MemoryPreferences();
      native.failWrites = true;
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      let publishCount = 0;
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => {
          publishCount++;
          return 73;
        },
        async (): Promise<void> => {},
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const result = await scheduleTrainPresaleTask(task(), store, scheduler);

      expect(publishCount).assertEqual(0);
      expect(result.task).assertEqual(undefined);
      expect(result.error.indexOf('persist failed')).assertLarger(-1);
      expect(store.get('train-1')).assertEqual(undefined);
    });

    it('keeps a truthful actionable reservation when reminder publication fails', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      let cancelledId = -1;
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => {
          throw new Error('publish failed');
        },
        async (reminderId: number): Promise<void> => {
          cancelledId = reminderId;
        },
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const result = await scheduleTrainPresaleTask(task(), store, scheduler);

      expect(result.task?.state).assertEqual('needs_user');
      expect(result.error.indexOf('publish failed')).assertLarger(-1);
      expect(store.get('train-1')?.state).assertEqual('needs_user');
      expect(store.get('train-1')?.lastError.indexOf('publish failed')).assertLarger(-1);
      expect(cancelledId).assertEqual(-1);
    });

    it('rejects a non-positive reminder ID and keeps the reservation actionable', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => 0,
        async (): Promise<void> => {},
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const result = await scheduleTrainPresaleTask(task(), store, scheduler);

      expect(result.task?.state).assertEqual('needs_user');
      expect(result.error).assertEqual('提醒创建失败：系统未返回有效的提醒编号。');
      expect(store.get('train-1')?.state).assertEqual('needs_user');
      expect(store.get('train-1')?.reminderId).assertEqual(-1);
    });

    it('cancels a published reminder when complete task persistence fails', 0, async () => {
      const native = new MemoryPreferences();
      native.failFlushAt = 2;
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      let cancelledId = -1;
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => 73,
        async (reminderId: number): Promise<void> => {
          cancelledId = reminderId;
        },
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const result = await scheduleTrainPresaleTask(task(), store, scheduler);

      expect(result.task?.state).assertEqual('cancelled');
      expect(result.error.indexOf('persist failed')).assertLarger(-1);
      expect(cancelledId).assertEqual(73);
      expect(store.get('train-1')?.state).assertEqual('cancelled');
    });

    it('reports cleanup failure without a false scheduled task', 0, async () => {
      const native = new MemoryPreferences();
      native.failFlushAt = 2;
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => 73,
        async (): Promise<void> => {
          throw new Error('cleanup failed');
        },
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const result = await scheduleTrainPresaleTask(task(), store, scheduler);

      expect(result.task?.state).assertEqual('needs_user');
      expect(result.error.indexOf('cleanup failed')).assertLarger(-1);
      expect(store.get('train-1')?.state).assertEqual('needs_user');
    });

    it('refuses an exact duplicate found in the immediate pre-publish recheck', 0, async () => {
      const native = new MemoryPreferences();
      const duplicate = task();
      duplicate.taskId = 'existing-train';
      duplicate.reminderId = 88;
      const store = new DuplicateInjectingStore(native as Object as preferences.Preferences, duplicate);
      let publishCount = 0;
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => {
          publishCount++;
          return 73;
        },
        async (): Promise<void> => {},
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const result = await scheduleTrainPresaleTask(task(), store, scheduler);

      expect(publishCount).assertEqual(0);
      expect(result.task?.taskId).assertEqual('existing-train');
      expect(result.task?.state).assertEqual('needs_user');
      expect(result.error.indexOf('已有开售任务')).assertLarger(-1);
    });

    it('reconciles a false durable scheduled record after combined persistence and rollback failure', 0, async () => {
      const native = new MemoryPreferences();
      native.failFlushAt = 2;
      native.failWriteAt = 3;
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => 73,
        async (): Promise<void> => {},
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const failed = await scheduleTrainPresaleTask(task(), store, scheduler);
      expect(failed.task?.state).assertEqual('needs_user');
      expect(store.get('train-1')?.state).assertEqual('scheduled');

      const reconciled = await reconcileTrainPresaleTask(store.get('train-1') as TrainPresaleTask, store, scheduler);

      expect(reconciled.task.state).assertEqual('needs_user');
      expect(reconciled.error.indexOf('系统提醒不存在')).assertLarger(-1);
      expect(store.get('train-1')?.state).assertEqual('needs_user');
    });

    it('keeps a scheduled task when its reminder ID is still active', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const scheduled = task();
      scheduled.reminderId = 73;
      store.create(scheduled);
      const request: reminderAgentManager.ReminderRequest = buildReminderRequest(scheduled, scheduled.saleAt);
      const listed = request as ListedReminderRequest;
      listed.reminderId = 73;
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => 0,
        async (): Promise<void> => {},
        async (): Promise<reminderAgentManager.ReminderRequest[]> => [listed]
      );

      const reconciled = await reconcileTrainPresaleTask(scheduled, store, scheduler);

      expect(reconciled.task.state).assertEqual('scheduled');
      expect(reconciled.error).assertEqual('');
    });

    it('recovers the unique published reminder after a crash before local reminder ID persistence', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const reservation = task();
      reservation.state = 'needs_user';
      reservation.reminderId = -1;
      reservation.lastError = '正在创建系统提醒；如流程中断，可重试取消或清除预留。';
      store.create(reservation);
      let cancelledId = -1;
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => 0,
        async (reminderId: number): Promise<void> => { cancelledId = reminderId; },
        async (): Promise<reminderAgentManager.ReminderRequest[]> => [listedReminder(reservation, 73)]
      );

      const recovered = await reconcileTrainPresaleTask(reservation, store, scheduler);

      expect(recovered.error).assertEqual('');
      expect(recovered.task.state).assertEqual('scheduled');
      expect(recovered.task.reminderId).assertEqual(73);
      expect(store.get('train-1')?.state).assertEqual('scheduled');
      const cancelled = await cancelScheduledTrainPresaleTask(recovered.task, store, scheduler);
      expect(cancelled.state).assertEqual('cancelled');
      expect(cancelledId).assertEqual(73);
    });

    it('fails closed when publication recovery is absent ambiguous malformed unrelated or unavailable', 0, async () => {
      const reconcileWith = async (reminders: reminderAgentManager.ReminderRequest[]):
        Promise<TrainPresaleReconcileResult> => {
        const native = new MemoryPreferences();
        const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
        const reservation = task();
        reservation.state = 'needs_user';
        reservation.reminderId = -1;
        reservation.lastError = '正在创建系统提醒；如流程中断，可重试取消或清除预留。';
        store.create(reservation);
        const scheduler = new SystemOneShotScheduler(
          async (): Promise<number> => 0,
          async (): Promise<void> => {},
          async (): Promise<reminderAgentManager.ReminderRequest[]> => reminders
        );
        return reconcileTrainPresaleTask(reservation, store, scheduler);
      };
      const reservation = task();
      reservation.state = 'needs_user';
      reservation.reminderId = -1;
      const unrelated = task();
      unrelated.taskId = 'other-task';

      const absent = await reconcileWith([]);
      const unrelatedResult = await reconcileWith([listedReminder(unrelated, 80)]);
      const ambiguous = await reconcileWith([listedReminder(reservation, 73), listedReminder(reservation, 74)]);
      const malformed = await reconcileWith([listedReminder(reservation, 0)]);

      expect(absent.task.state).assertEqual('needs_user');
      expect(absent.error.indexOf('正在创建系统提醒')).assertLarger(-1);
      expect(unrelatedResult.task.state).assertEqual('needs_user');
      expect(unrelatedResult.error.indexOf('正在创建系统提醒')).assertLarger(-1);
      expect(ambiguous.task.state).assertEqual('needs_user');
      expect(ambiguous.error.indexOf('多个')).assertLarger(-1);
      expect(malformed.task.state).assertEqual('needs_user');
      expect(malformed.error.indexOf('编号无效')).assertLarger(-1);

      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const pending = task();
      pending.state = 'needs_user';
      pending.reminderId = -1;
      pending.lastError = 'publication pending';
      store.create(pending);
      const failed = await reconcileTrainPresaleTask(pending, store, new SystemOneShotScheduler(
        async (): Promise<number> => 0,
        async (): Promise<void> => {},
        async (): Promise<reminderAgentManager.ReminderRequest[]> => { throw new Error('list failed'); }
      ));
      expect(failed.task.state).assertEqual('needs_user');
      expect(failed.error.indexOf('list failed')).assertLarger(-1);
    });

    it('restores the durable needs-user error when reopening', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const attention = task();
      attention.state = 'needs_user';
      attention.reminderId = -1;
      attention.lastError = '上次发布失败，请重试或清除预留。';
      store.create(attention);
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => 0,
        async (): Promise<void> => {},
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const reopened = await reconcileTrainPresaleTask(attention, store, scheduler);

      expect(reopened.task.state).assertEqual('needs_user');
      expect(reopened.error).assertEqual('上次发布失败，请重试或清除预留。');
    });

    it('cancels native reminder and persists cancelled state', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const scheduled = task();
      scheduled.reminderId = 73;
      store.create(scheduled);
      let cancelledId = -1;
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => 0,
        async (reminderId: number): Promise<void> => {
          expect(store.get('train-1')?.state).assertEqual('needs_user');
          cancelledId = reminderId;
        },
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const result = await cancelScheduledTrainPresaleTask(scheduled, store, scheduler);

      expect(result.state).assertEqual('cancelled');
      expect(result.error).assertEqual('');
      expect(cancelledId).assertEqual(73);
      expect(store.get('train-1')?.state).assertEqual('cancelled');
    });

    it('keeps scheduled state when native cancellation fails', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const scheduled = task();
      scheduled.reminderId = 73;
      store.create(scheduled);
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => 0,
        async (): Promise<void> => {
          throw new Error('native cancel failed');
        },
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const result = await cancelScheduledTrainPresaleTask(scheduled, store, scheduler);

      expect(result.state).assertEqual('scheduled');
      expect(result.error.indexOf('任务仍为已安排')).assertLarger(-1);
      expect(store.get('train-1')?.state).assertEqual('scheduled');
    });

    it('requires user attention when native cancellation succeeds but local persistence fails', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const scheduled = task();
      scheduled.reminderId = 73;
      store.create(scheduled);
      native.failWriteAt = 3;
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => 0,
        async (): Promise<void> => {},
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const result = await cancelScheduledTrainPresaleTask(scheduled, store, scheduler);

      expect(result.state).assertEqual('needs_user');
      expect(result.error.indexOf('系统提醒已取消，但本地状态保存失败')).assertLarger(-1);
      expect(result.task?.state).assertEqual('needs_user');
    });

    it('retries cancellation from needs-user and locally clears a reservation without a reminder', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const attention = task();
      attention.state = 'needs_user';
      attention.reminderId = -1;
      attention.lastError = '发布失败';
      store.create(attention);
      let nativeCancelCount = 0;
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => 0,
        async (): Promise<void> => {
          nativeCancelCount++;
        },
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const result = await cancelScheduledTrainPresaleTask(attention, store, scheduler);

      expect(result.state).assertEqual('cancelled');
      expect(result.error).assertEqual('');
      expect(nativeCancelCount).assertEqual(0);
      expect(store.get('train-1')?.state).assertEqual('cancelled');
    });

    it('locally completes needs-user cancellation when reconciliation shows the reminder is absent', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const attention = task();
      attention.state = 'needs_user';
      attention.reminderId = 73;
      attention.lastError = '系统提醒状态待核验';
      store.create(attention);
      let nativeCancelCount = 0;
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => 0,
        async (): Promise<void> => {
          nativeCancelCount++;
          throw new Error('absent reminder must not be cancelled');
        },
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const result = await cancelScheduledTrainPresaleTask(attention, store, scheduler);

      expect(result.state).assertEqual('cancelled');
      expect(result.error).assertEqual('');
      expect(nativeCancelCount).assertEqual(0);
      expect(store.get('train-1')?.state).assertEqual('cancelled');
    });

    it('ends only an awaiting-payment debug test without cancelling a consumed system reminder', 0, async () => {
      const native = new MemoryPreferences();
      const store = new TrainPresaleTaskStore(native as Object as preferences.Preferences);
      const debugTask = task();
      debugTask.source = 'debug';
      debugTask.state = 'awaiting_payment';
      debugTask.reminderId = 73;
      store.create(debugTask);
      let nativeCancelCount = 0;
      const scheduler = new SystemOneShotScheduler(
        async (): Promise<number> => 0,
        async (): Promise<void> => {
          nativeCancelCount++;
        },
        async (): Promise<reminderAgentManager.ReminderRequest[]> => []
      );

      const result = await cancelScheduledTrainPresaleTask(debugTask, store, scheduler);

      expect(result.state).assertEqual('cancelled');
      expect(result.error).assertEqual('');
      expect(nativeCancelCount).assertEqual(0);
      expect(store.get('train-1')?.state).assertEqual('cancelled');
    });
  });
}
