import { describe, it, expect } from '@ohos/hypium';
import { preferences } from '@kit.ArkData';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import {
  scheduleTrainPresaleTask,
  TrainPresaleConfirmationInput,
  validateTrainPresaleConfirmation
} from '../main/ets/pages/A2uiHome/components/TrainPresalePanel';
import { SystemOneShotScheduler } from '../main/ets/pages/A2uiHome/train/SystemOneShotScheduler';
import { TrainPresaleTask, TrainPresaleTaskStore } from '../main/ets/pages/A2uiHome/train/TrainPresaleTaskStore';

class MemoryPreferences {
  private value: preferences.ValueType = '';
  private writes: number = 0;
  failAfterFirstWrite: boolean = false;

  getSync(_key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    return this.value === '' ? defaultValue : this.value;
  }

  putSync(_key: string, value: preferences.ValueType): void {
    this.writes++;
    if (this.failAfterFirstWrite && this.writes > 1) {
      throw new Error('persist failed');
    }
    this.value = value;
  }

  flushSync(): void {}
}

function task(): TrainPresaleTask {
  const result = validateTrainPresaleConfirmation(validInput());
  if (result.task === undefined) {
    throw new Error(result.error);
  }
  return result.task;
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
    debugConfirmed: false,
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
    });

    it('requires explicit real unpaid-order authorization', 0, () => {
      const input = validInput();
      input.unpaidOrderAuthorized = false;
      const result = validateTrainPresaleConfirmation(input);
      expect(result.task).assertEqual(undefined);
      expect(result.error).assertEqual('请明确授权在开售时提交真实未支付订单。');
    });

    it('requires debug availability and a second explicit confirmation', 0, () => {
      const input = validInput();
      input.source = 'debug';
      expect(validateTrainPresaleConfirmation(input).task).assertEqual(undefined);

      input.debugEnabled = true;
      expect(validateTrainPresaleConfirmation(input).error).assertEqual('请再次确认这是调试测试。');

      input.debugConfirmed = true;
      expect(validateTrainPresaleConfirmation(input).task === undefined).assertFalse();
    });

    it('does not report scheduled when reminder publication fails', 0, async () => {
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

      expect(result.task).assertEqual(undefined);
      expect(result.error.indexOf('publish failed')).assertLarger(-1);
      expect(store.get('train-1')?.state).assertEqual('cancelled');
      expect(cancelledId).assertEqual(-1);
    });

    it('cancels a published reminder when reminder ID persistence fails', 0, async () => {
      const native = new MemoryPreferences();
      native.failAfterFirstWrite = true;
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

      expect(result.task).assertEqual(undefined);
      expect(result.error.indexOf('persist failed')).assertLarger(-1);
      expect(cancelledId).assertEqual(73);
      expect(store.get('train-1')?.reminderId).assertEqual(-1);
    });
  });
}
