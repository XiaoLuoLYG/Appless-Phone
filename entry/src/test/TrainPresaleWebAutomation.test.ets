import { describe, it, expect } from '@ohos/hypium';
import { preferences } from '@kit.ArkData';
import {
  buildTrainPresaleFinalConfirmScript, buildTrainPresaleWebAssistScript,
  evaluateTrainWebAssistFixture, exactTrainWebAssistMultiset, parseTrainWebAssistOutcome,
  trainPresaleWebAssistScriptForCheckout, trainWebAssistTargetState, TrainWebAssistFixture,
  TrainWebAssistOutcome
} from '../main/ets/pages/A2uiHome/train/TrainPresaleWebAutomation';
import { TrainPresaleTask, TrainPresaleTaskState } from '../main/ets/pages/A2uiHome/train/TrainPresaleTaskStore';
import { transitionTrainPresaleHandoff, TRAIN_PRESALE_PENDING_TASK_KEY,
  TRAIN_PRESALE_TASKS_KEY } from '../main/ets/entryability/EntryAbility';

class FlushTrackingPreferences {
  private values: Map<string, preferences.ValueType> = new Map();
  snapshots: string[] = [];
  getSync(key: string, fallback: preferences.ValueType): preferences.ValueType {
    return this.values.has(key) ? this.values.get(key) as preferences.ValueType : fallback;
  }
  putSync(key: string, value: preferences.ValueType): void { this.values.set(key, value); }
  deleteSync(key: string): void { this.values.delete(key); }
  flushSync(): void {
    this.snapshots.push(String(this.getSync(TRAIN_PRESALE_PENDING_TASK_KEY, '')) + '|' +
      String(this.getSync(TRAIN_PRESALE_TASKS_KEY, '')));
  }
}

class ReplacingPreferences extends FlushTrackingPreferences {
  flushCount: number = 0;
  flushSync(): void {
    super.flushSync();
    this.flushCount += 1;
    if (this.flushCount === 1) this.putSync(TRAIN_PRESALE_PENDING_TASK_KEY, 'replacement-task');
  }
}

function task(state: TrainPresaleTaskState = 'executing'): TrainPresaleTask {
  return { taskId: 'task-7', source: 'presale', state, trainCode: 'G10', travelDate: '2026-07-23',
    fromName: '上海虹桥', fromCode: 'AOH', toName: '北京南', toCode: 'VNP',
    saleAt: '2026-07-23T12:30:00+08:00', passengerNames: ['张三', '李四'], seatPriority: '二等座',
    unpaidOrderAuthorized: true, bookingUrl: 'https://kyfw.12306.cn/otn/leftTicket/init', reminderId: 7,
    createdAt: '2026-07-22T12:00:00+08:00', lastError: '' };
}

function fixture(train: string = 'G10'): TrainWebAssistFixture {
  return { trainCells: [train], loginVisible: false, captchaVisible: false, passengerRows: [
    { cells: ['张三', '二等座'], visible: true, width: 100, height: 20 },
    { cells: ['李四', '二等座'], visible: true, width: 100, height: 20 }
  ] };
}

export default function trainPresaleWebAutomationTest() {
  describe('trainPresaleWebAutomation', () => {
    it('emits immediate synchronous scripts and separates final confirmation', 0, () => {
      const initial = buildTrainPresaleWebAssistScript(task());
      const finalScript = buildTrainPresaleFinalConfirmScript(task());
      expect(initial.indexOf('Promise')).assertEqual(-1);
      expect(initial.indexOf('setInterval')).assertEqual(-1);
      expect(initial.indexOf('setTimeout')).assertEqual(-1);
      expect(initial.indexOf("state:'ready_to_confirm'") >= 0).assertTrue();
      expect(initial.indexOf("confirm.click()") >= 0).assertFalse();
      expect(finalScript.indexOf("confirm.click()") >= 0).assertTrue();
      expect(initial.indexOf('txt(link)===cfg.trainCode') >= 0).assertTrue();
      expect(initial.indexOf("'#seatType_'+(i+1)") >= 0).assertTrue();
    });

    it('checks exact modal identity multiplicity visibility and seat alignment', 0, () => {
      expect(evaluateTrainWebAssistFixture(task(), fixture())).assertEqual('');
      expect(evaluateTrainWebAssistFixture(task(), fixture('G100'))).assertEqual('confirmation_mismatch');
      const extra = fixture(); extra.passengerRows.push(
        { cells: ['王五', '二等座'], visible: true, width: 100, height: 20 });
      expect(evaluateTrainWebAssistFixture(task(), extra)).assertEqual('confirmation_mismatch');
      const duplicate = fixture(); duplicate.passengerRows[1].cells = ['张三', '二等座'];
      expect(evaluateTrainWebAssistFixture(task(), duplicate)).assertEqual('confirmation_mismatch');
      const wrongSeat = fixture(); wrongSeat.passengerRows[1].cells = ['李四', '一等座'];
      expect(evaluateTrainWebAssistFixture(task(), wrongSeat)).assertEqual('confirmation_mismatch');
      const hiddenExtra = fixture(); hiddenExtra.passengerRows.push(
        { cells: ['王五', '二等座'], visible: false, width: 100, height: 20 });
      expect(evaluateTrainWebAssistFixture(task(), hiddenExtra)).assertEqual('');
      expect(exactTrainWebAssistMultiset(['张三', '李四'], ['李四', '张三'])).assertTrue();
    });

    it('uses visible fixed login captcha selectors and no body text heuristic', 0, () => {
      const script = buildTrainPresaleWebAssistScript(task());
      expect(script.indexOf("shown('#login_user,.login-hd-account,#J-login')") >= 0).assertTrue();
      expect(script.indexOf("shown('#J-loginImg,.touclick-wrapper,#floatTable')") >= 0).assertTrue();
      expect(script.indexOf('bodyText')).assertEqual(-1);
      const login = fixture(); login.loginVisible = true;
      expect(evaluateTrainWebAssistFixture(task(), login)).assertEqual('login_required');
      const captcha = fixture(); captcha.captchaVisible = true;
      expect(evaluateTrainWebAssistFixture(task(), captcha)).assertEqual('captcha_required');
    });

    it('requires durable authorization and exact bound executing task', 0, () => {
      const value = task();
      expect(trainPresaleWebAssistScriptForCheckout('train', 'task-7', value).length > 0).assertTrue();
      value.unpaidOrderAuthorized = false;
      expect(trainPresaleWebAssistScriptForCheckout('train', 'task-7', value)).assertEqual('');
      expect(trainPresaleWebAssistScriptForCheckout('train', 'other', task())).assertEqual('');
      expect(trainPresaleWebAssistScriptForCheckout('train', 'task-7', task('scheduled'))).assertEqual('');
    });

    it('accepts only exact allowlisted protocol shapes', 0, () => {
      const retry = parseTrainWebAssistOutcome('{"state":"retry","stage":"query","progress":"booking_clicked"}');
      const ready = parseTrainWebAssistOutcome('{"state":"ready_to_confirm"}');
      const rawExtra = parseTrainWebAssistOutcome('{"state":"needs_user","reason":"login_required","raw":"x"}');
      const unknown = parseTrainWebAssistOutcome('{"state":"needs_user","reason":"secret"}');
      expect(retry.state).assertEqual('retry'); expect(ready.state).assertEqual('ready_to_confirm');
      expect(rawExtra.state === 'needs_user' ? rawExtra.reason : '').assertEqual('invalid_result');
      expect(unknown.state === 'needs_user' ? unknown.reason : '').assertEqual('invalid_result');
      expect(parseTrainWebAssistOutcome('x').state).assertEqual('needs_user');
    });

    it('maps only terminal outcomes', 0, () => {
      const retry: TrainWebAssistOutcome = { state: 'retry', stage: 'query', progress: 'x' };
      expect(trainWebAssistTargetState(retry)).assertEqual(undefined);
      expect(trainWebAssistTargetState({ state: 'ready_to_confirm' })).assertEqual(undefined);
      expect(trainWebAssistTargetState({ state: 'awaiting_payment' })).assertEqual('awaiting_payment');
    });

    it('flushes terminal task before compare-and-clearing matching handoff', 0, () => {
      const memory = new FlushTrackingPreferences(); const store = memory as Object as preferences.Preferences;
      store.putSync(TRAIN_PRESALE_TASKS_KEY, JSON.stringify([task()]));
      store.putSync(TRAIN_PRESALE_PENDING_TASK_KEY, 'task-7');
      const result = transitionTrainPresaleHandoff(store, 'task-7', 'awaiting_payment', '');
      expect(result.cleared).assertTrue(); expect(memory.snapshots.length).assertEqual(2);
      expect(memory.snapshots[0].startsWith('task-7|')).assertTrue();
      expect(memory.snapshots[1].startsWith('|')).assertTrue();
    });

    it('never deletes a replacement handoff written after terminal task flush', 0, () => {
      const memory = new ReplacingPreferences(); const store = memory as Object as preferences.Preferences;
      store.putSync(TRAIN_PRESALE_TASKS_KEY, JSON.stringify([task()]));
      store.putSync(TRAIN_PRESALE_PENDING_TASK_KEY, 'task-7');
      const result = transitionTrainPresaleHandoff(store, 'task-7', 'awaiting_payment', '');
      expect(result.cleared).assertFalse();
      expect(store.getSync(TRAIN_PRESALE_PENDING_TASK_KEY, '')).assertEqual('replacement-task');
    });
  });
}
