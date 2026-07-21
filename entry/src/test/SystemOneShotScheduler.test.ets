import { describe, expect, it } from '@ohos/hypium';
import { buildReminderRequest } from '../main/ets/pages/A2uiHome/train/SystemOneShotScheduler';
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
  bookingUrl: 'https://kyfw.12306.cn/otn/leftTicket/init',
  reminderId: 0,
  createdAt: '2026-07-21T10:00:00+08:00',
  lastError: ''
};

export default function systemOneShotSchedulerTest() {
  describe('systemOneShotScheduler', () => {
    it('builds a one-shot calendar reminder with only its task ID', 0, () => {
      const request = buildReminderRequest(TASK, '2026-07-22T12:45:30+08:00');
      const parameters = request.wantAgent === undefined ? undefined : request.wantAgent.parameters;

      expect(request.reminderType).assertEqual(1);
      expect(request.dateTime.year).assertEqual(2026);
      expect(request.dateTime.month).assertEqual(7);
      expect(request.dateTime.day).assertEqual(22);
      expect(request.dateTime.hour).assertEqual(12);
      expect(request.dateTime.minute).assertEqual(45);
      expect(request.dateTime.second).assertEqual(30);
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
  });
}
