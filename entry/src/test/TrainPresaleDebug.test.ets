import { describe, expect, it } from '@ohos/hypium';
import { preferences } from '@kit.ArkData';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import {
  TrainPresaleDebugSelection,
  TrainPresaleDebugSelectionRequest,
  trainPresaleDebugSelectionFromOfficialPayloadForTest
} from '@loop/agent-core';
import {
  prepareTrainPresaleDebugConfirmation,
  scheduleTrainPresaleTask,
  trainPresaleDebugActionVisible,
  TrainPresaleDebugConfirmationInput
} from '../main/ets/pages/A2uiHome/components/TrainPresalePanel';
import { SystemOneShotScheduler } from '../main/ets/pages/A2uiHome/train/SystemOneShotScheduler';
import { TrainPresaleTaskStore } from '../main/ets/pages/A2uiHome/train/TrainPresaleTaskStore';

class MemoryPreferences {
  private value: preferences.ValueType = '';

  getSync(_key: string, defaultValue: preferences.ValueType): preferences.ValueType {
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
