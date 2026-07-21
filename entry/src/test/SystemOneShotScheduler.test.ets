import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { describe, expect, it } from '@ohos/hypium';
import { buildReminderRequest, SystemOneShotScheduler } from '../main/ets/pages/A2uiHome/train/SystemOneShotScheduler';
import { TrainPresaleTask } from '../main/ets/pages/A2uiHome/train/TrainPresaleTaskStore';

const TASK: TrainPresaleTask = {
  taskId: 'task-1',
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

export default function systemOneShotSchedulerTest() {
  describe('systemOneShotScheduler', () => {
    it('builds a one-shot calendar reminder with only its task ID', 0, () => {
      const fireAt = '2026-07-22T04:45:30.000Z';
      const expected = new Date(fireAt);
      const request = buildReminderRequest(TASK, fireAt);
      const parameters = request.wantAgent === undefined ? undefined : request.wantAgent.parameters;

      expect(request.reminderType).assertEqual(reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR);
      expect(request.dateTime.year).assertEqual(expected.getFullYear());
      expect(request.dateTime.month).assertEqual(expected.getMonth() + 1);
      expect(request.dateTime.day).assertEqual(expected.getDate());
      expect(request.dateTime.hour).assertEqual(expected.getHours());
      expect(request.dateTime.minute).assertEqual(expected.getMinutes());
      expect(request.dateTime.second).assertEqual(expected.getSeconds());
      expect(request.wantAgent === undefined).assertFalse();
      if (request.wantAgent !== undefined) {
        expect(request.wantAgent.pkgName).assertEqual('com.example.aiphonedemo');
        expect(request.wantAgent.abilityName).assertEqual('EntryAbility');
      }
      expect(request.maxScreenWantAgent === undefined).assertFalse();
      if (request.maxScreenWantAgent !== undefined) {
        expect(request.maxScreenWantAgent.pkgName).assertEqual('com.example.aiphonedemo');
        expect(request.maxScreenWantAgent.abilityName).assertEqual('EntryAbility');
      }
      expect(request.title).assertEqual('G1 开售提醒');
      expect(request.content).assertEqual('北京南 → 上海虹桥 即将开售');
      expect(request.tapDismissed).assertTrue();
      expect(parameters === undefined).assertFalse();
      if (parameters !== undefined) {
        expect((parameters['trainPresaleTaskId'] as string)).assertEqual('task-1');
        expect(Object.keys(parameters).length).assertEqual(1);
      }
      expect(Object.keys(request).indexOf('repeatMonths')).assertEqual(-1);
      expect(Object.keys(request).indexOf('repeatDays')).assertEqual(-1);
      expect(Object.keys(request).indexOf('daysOfWeek')).assertEqual(-1);
      expect(JSON.stringify(request).indexOf('张三')).assertEqual(-1);
    });

    it('delegates schedule cancel and list through injected platform functions', 0, async () => {
      let published: reminderAgentManager.ReminderRequestCalendar | undefined;
      let cancelledId: number = 0;
      const scheduler = new SystemOneShotScheduler(
        async (request: reminderAgentManager.ReminderRequestCalendar): Promise<number> => {
          published = request;
          return 73;
        },
        async (reminderId: number): Promise<void> => {
          cancelledId = reminderId;
        },
        async (): Promise<reminderAgentManager.ReminderRequest[]> => [buildReminderRequest(TASK, TASK.saleAt)]
      );
      const scheduled: TrainPresaleTask = TASK;
      scheduled.reminderId = 0;

      expect(await scheduler.schedule(scheduled, scheduled.saleAt)).assertEqual(73);
      expect(scheduled.reminderId).assertEqual(73);
      expect(published === undefined).assertFalse();
      await scheduler.cancel(73);
      expect(cancelledId).assertEqual(73);
      expect((await scheduler.list()).length).assertEqual(1);
    });
  });
}
