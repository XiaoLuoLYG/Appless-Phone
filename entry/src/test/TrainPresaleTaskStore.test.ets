import { preferences } from '@kit.ArkData';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { describe, expect, it } from '@ohos/hypium';
import {
  claimDueTrainPresaleTask,
  parseTrainPresaleTaskList,
  serializeTrainPresaleTaskList,
  TrainPresaleTask,
  TrainPresaleTaskStore,
  updateTrainPresaleTask
} from '../main/ets/pages/A2uiHome/train/TrainPresaleTaskStore';
import { SystemOneShotScheduler } from '../main/ets/pages/A2uiHome/train/SystemOneShotScheduler';

class MemoryPreferences {
  private values: Map<string, preferences.ValueType> = new Map();

  getSync(key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    return this.values.has(key) ? this.values.get(key) as preferences.ValueType : defaultValue;
  }

  putSync(key: string, value: preferences.ValueType): void {
    this.values.set(key, value);
  }

  flushSync(): void {}
}

function nativePreferences(): preferences.Preferences {
  return new MemoryPreferences() as Object as preferences.Preferences;
}

function task(taskId: string = 'task-1'): TrainPresaleTask {
  return {
    taskId,
    source: 'presale',
    state: 'scheduled',
    trainCode: 'G1',
    travelDate: '2026-08-06',
    fromName: '北京南',
    fromCode: 'VNP',
    toName: '上海虹桥',
    toCode: 'AOH',
    saleAt: '2026-07-22T12:45:30+08:00',
    passengerNames: ['张三'],
    seatPriority: '二等座',
    unpaidOrderAuthorized: true,
    bookingUrl: 'https://kyfw.12306.cn/otn/leftTicket/init',
    reminderId: 0,
    createdAt: '2026-07-21T10:00:00+08:00',
    lastError: ''
  };
}

export default function trainPresaleTaskStoreTest() {
  describe('trainPresaleTaskStore', () => {
    it('serializes and recovers only valid task records without sensitive fields', 0, () => {
      const valid = task();
      valid.passengerNames = [' 张三 '];
      const invalidUrl = task('unsafe-url');
      invalidUrl.bookingUrl = 'javascript:alert(1)';
      const invalidPassenger = task('unsafe-passenger');
      const nestedPassenger = JSON.stringify(invalidPassenger)
        .replace('"张三"', '{"identityNumber":"110101199001010000"}');
      const raw = '[null,' + serializeTrainPresaleTaskList([valid]).slice(1, -1) + ',' +
        JSON.stringify(invalidUrl) + ',' + nestedPassenger + ']';
      const tasks = parseTrainPresaleTaskList(raw);

      expect(tasks.length).assertEqual(1);
      expect(tasks[0].taskId).assertEqual('task-1');
      expect(tasks[0].passengerNames[0]).assertEqual('张三');
      const saved = serializeTrainPresaleTaskList(tasks);
      expect(saved.indexOf('password')).assertEqual(-1);
      expect(saved.indexOf('identity')).assertEqual(-1);
      expect(saved.indexOf('payment')).assertEqual(-1);
      expect(saved.indexOf('cookie')).assertEqual(-1);
    });

    it('recovers from malformed persisted JSON', 0, () => {
      expect(parseTrainPresaleTaskList('{').length).assertEqual(0);
      expect(parseTrainPresaleTaskList('{"tasks":[]}').length).assertEqual(0);
    });

    it('requires the explicit durable unpaid-order authorization field', 0, () => {
      const missing = JSON.stringify(task()).replace(',"unpaidOrderAuthorized":true', '');
      const wrongType = JSON.stringify(task()).replace('"unpaidOrderAuthorized":true',
        '"unpaidOrderAuthorized":"true"');
      expect(parseTrainPresaleTaskList(missing).length).assertEqual(0);
      expect(parseTrainPresaleTaskList(wrongType).length).assertEqual(0);
      expect(parseTrainPresaleTaskList(JSON.stringify([task()]))[0].unpaidOrderAuthorized).assertTrue();
    });

    it('updates only allowed task state transitions and cancels scheduled work', 0, () => {
      const scheduled = task();
      const executing = updateTrainPresaleTask(scheduled, { state: 'executing' });
      const waitingForPayment = updateTrainPresaleTask(executing, { state: 'awaiting_payment' });

      expect(executing.state).assertEqual('executing');
      expect(waitingForPayment.state).assertEqual('awaiting_payment');
      expect(updateTrainPresaleTask(waitingForPayment, { state: 'scheduled' }).state)
        .assertEqual('awaiting_payment');
      expect(updateTrainPresaleTask(scheduled, { state: 'cancelled' }).state).assertEqual('cancelled');
    });

    it('persists actual create get list update cancel and idempotent claims', 0, () => {
      const native = nativePreferences();
      const store = new TrainPresaleTaskStore(native);
      store.create(task());
      store.create(task('due'));
      const invalid = task('unsafe');
      invalid.bookingUrl = 'javascript:alert(1)';
      store.create(invalid);

      expect(store.get('task-1') === undefined).assertFalse();
      expect(store.list().length).assertEqual(2);
      expect(store.get('unsafe')).assertEqual(undefined);
      store.update('task-1', { lastError: 'retry later' });
      expect(store.get('task-1')?.lastError).assertEqual('retry later');
      store.cancel('task-1');
      expect(store.get('task-1')?.state).assertEqual('cancelled');
      expect(store.claimDue('2026-07-22T12:45:30+08:00', 'due')?.state).assertEqual('executing');
      expect(store.claimDue('2026-07-22T12:45:30+08:00', 'due')).assertEqual(undefined);
    });

    it('rejects malformed runtime passengers without changing stored tasks', 0, () => {
      const native = nativePreferences();
      const store = new TrainPresaleTaskStore(native);
      store.create(task());
      const malformed = task('malformed-passenger') as Object as TrainPresaleTask;
      malformed.passengerNames = [null] as Object as string[];

      store.create(malformed);

      expect(store.list().length).assertEqual(1);
      expect(store.get('task-1') === undefined).assertFalse();
      expect(store.get('malformed-passenger')).assertEqual(undefined);
    });

    it('rejects unparseable task timestamps on create and reload', 0, () => {
      const native = nativePreferences();
      const store = new TrainPresaleTaskStore(native);
      const invalidSaleAt = task('invalid-sale-at');
      invalidSaleAt.saleAt = 'not-a-date';
      const invalidCreatedAt = task('invalid-created-at');
      invalidCreatedAt.createdAt = 'not-a-date';

      store.create(invalidSaleAt);
      store.create(invalidCreatedAt);

      expect(store.list().length).assertEqual(0);
      expect(parseTrainPresaleTaskList(JSON.stringify([invalidSaleAt, invalidCreatedAt])).length).assertEqual(0);
    });

    it('persists the reminder ID after scheduler orchestration updates the task', 0, async () => {
      const native = nativePreferences();
      const store = new TrainPresaleTaskStore(native);
      store.create(task());
      const scheduled = store.get('task-1');
      expect(scheduled === undefined).assertFalse();
      if (scheduled !== undefined) {
        const scheduler = new SystemOneShotScheduler(
          async (): Promise<number> => 73,
          async (): Promise<void> => {},
          async (): Promise<reminderAgentManager.ReminderRequest[]> => []
        );
        store.update(scheduled.taskId, { reminderId: await scheduler.schedule(scheduled, scheduled.saleAt) });
      }

      expect(new TrainPresaleTaskStore(native).get('task-1')?.reminderId).assertEqual(73);
    });

    it('claims a due task when now uses a different ISO offset', 0, () => {
      const result = claimDueTrainPresaleTask([task()], '2026-07-22T04:45:30.000Z');

      expect(result.task === undefined).assertFalse();
    });
  });
}
