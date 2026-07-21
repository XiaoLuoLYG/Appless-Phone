import { describe, expect, it } from '@ohos/hypium';
import {
  claimDueTrainPresaleTask,
  parseTrainPresaleTaskList,
  serializeTrainPresaleTaskList,
  TrainPresaleTask,
  updateTrainPresaleTask
} from '../main/ets/pages/A2uiHome/train/TrainPresaleTaskStore';

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
    bookingUrl: 'https://kyfw.12306.cn/otn/leftTicket/init',
    reminderId: 0,
    createdAt: '2026-07-21T10:00:00+08:00',
    lastError: ''
  };
}

export default function trainPresaleTaskStoreTest() {
  describe('trainPresaleTaskStore', () => {
    it('serializes and recovers the minimal task list without sensitive fields', 0, () => {
      const raw = serializeTrainPresaleTaskList([task()]);

      expect(parseTrainPresaleTaskList(raw)[0].taskId).assertEqual('task-1');
      expect(raw.indexOf('password')).assertEqual(-1);
      expect(raw.indexOf('identity')).assertEqual(-1);
      expect(raw.indexOf('payment')).assertEqual(-1);
      expect(raw.indexOf('cookie')).assertEqual(-1);
    });

    it('recovers from malformed persisted JSON', 0, () => {
      expect(parseTrainPresaleTaskList('{').length).assertEqual(0);
      expect(parseTrainPresaleTaskList('{"tasks":[]}').length).assertEqual(0);
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

    it('claims one due scheduled task exactly once', 0, () => {
      const result = claimDueTrainPresaleTask([task('later'), task('due')], '2026-07-22T12:45:30+08:00', 'due');

      expect(result.task === undefined).assertFalse();
      if (result.task !== undefined) {
        expect(result.task.taskId).assertEqual('due');
        expect(result.task.state).assertEqual('executing');
      }
      expect(result.tasks[0].state).assertEqual('scheduled');
      expect(claimDueTrainPresaleTask(result.tasks, '2026-07-22T12:45:30+08:00', 'due').task)
        .assertEqual(undefined);
    });

    it('claims a due task when now uses a different ISO offset', 0, () => {
      const result = claimDueTrainPresaleTask([task()], '2026-07-22T04:45:30.000Z');

      expect(result.task === undefined).assertFalse();
    });
  });
}
