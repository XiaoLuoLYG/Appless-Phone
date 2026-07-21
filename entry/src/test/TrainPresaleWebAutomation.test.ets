import { describe, it, expect } from '@ohos/hypium';
import { preferences } from '@kit.ArkData';
import {
  buildTrainPresaleFinalConfirmScript, buildTrainPresaleWebAssistScript,
  buildTrainWebAssistExecutionRequest,
  isCurrentTrainWebAssistExecution, isCurrentTrainWebAssistTimer, nextTrainWebAssistEpoch,
  parseTrainWebAssistOutcome, trainWebAssistDurableGateReason,
  trainWebAssistFinalClickMayHaveRun, trainWebAssistRetryExhausted, trainWebAssistTargetState,
  TrainWebAssistExecutionBinding,
  TrainWebAssistOutcome, TrainWebAssistRetryOutcome
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

    it('production script snapshot enforces exact visible modal multiplicity and seat-row alignment', 0, () => {
      const script = buildTrainPresaleFinalConfirmScript(task());
      expect(script.indexOf("cells.filter((v)=>v===cfg.trainCode).length!==1") >= 0).assertTrue();
      expect(script.indexOf('rows.length!==cfg.passengerNames.length') >= 0).assertTrue();
      expect(script.indexOf("rc.filter((v)=>v===name).length===1") >= 0).assertTrue();
      expect(script.indexOf("rc.filter((v)=>v.indexOf(cfg.seatPriority)===0).length!==1") >= 0).assertTrue();
      expect(script.indexOf("names.slice().sort().join('\\u0000')") >= 0).assertTrue();
      expect(script.indexOf("s.display!=='none'") >= 0).assertTrue();
      expect(script.indexOf('r.width>0&&r.height>0') >= 0).assertTrue();
    });

    it('uses visible fixed login captcha selectors and no body text heuristic', 0, () => {
      const script = buildTrainPresaleWebAssistScript(task());
      expect(script.indexOf("shown('#login_user,.login-hd-account,#J-login')") >= 0).assertTrue();
      expect(script.indexOf("shown('#J-loginImg,.touclick-wrapper')") >= 0).assertTrue();
      expect(script.indexOf('#floatTable')).assertEqual(-1);
      expect(script.indexOf('bodyText')).assertEqual(-1);
      const finalScript = buildTrainPresaleFinalConfirmScript(task());
      expect(finalScript.indexOf("hostname.toLowerCase()!=='kyfw.12306.cn'") >= 0).assertTrue();
      expect(finalScript.indexOf("shown('#login_user,.login-hd-account,#J-login')") >= 0).assertTrue();
      expect(finalScript.indexOf("shown('#J-loginImg,.touclick-wrapper')") >= 0).assertTrue();
      expect(finalScript.indexOf("retry('confirm','waiting_modal')") >= 0).assertTrue();
      expect(finalScript.indexOf("retry('confirm','waiting_confirm')") >= 0).assertTrue();
    });

    it('requires durable authorization pending binding state and official active URL before every request', 0, () => {
      const value = task();
      expect(trainWebAssistDurableGateReason('train', 'task-7', 'task-7', value,
        'https://kyfw.12306.cn/otn/confirmPassenger/initDc')).assertEqual('');
      value.unpaidOrderAuthorized = false;
      expect(trainWebAssistDurableGateReason('train', 'task-7', 'task-7', value,
        'https://kyfw.12306.cn/')).assertEqual('not_authorized');
      expect(trainWebAssistDurableGateReason('train', 'task-7', 'replacement', task(),
        'https://kyfw.12306.cn/')).assertEqual('not_authorized');
      expect(trainWebAssistDurableGateReason('train', 'task-7', 'task-7', task(),
        'https://kyfw.12306.cn.evil.example/')).assertEqual('page_mismatch');
      expect(buildTrainWebAssistExecutionRequest('final', 'train', 'task-7', 'task-7', task(),
        'https://kyfw.12306.cn/otn/confirmPassenger/initDc').script.indexOf("confirm.click()") >= 0).assertTrue();
      expect(buildTrainWebAssistExecutionRequest('final', 'train', 'task-7', 'replacement', task(),
        'https://kyfw.12306.cn/otn/confirmPassenger/initDc').script).assertEqual('');
      const expected: TrainWebAssistExecutionBinding = { controller: 'popup', generation: 4, session: 7 };
      expect(isCurrentTrainWebAssistExecution(expected,
        { controller: 'popup', generation: 4, session: 7 })).assertTrue();
      expect(isCurrentTrainWebAssistExecution(expected,
        { controller: 'main', generation: 4, session: 7 })).assertFalse();
      expect(isCurrentTrainWebAssistExecution(expected,
        { controller: 'popup', generation: 5, session: 7 })).assertFalse();
      expect(isCurrentTrainWebAssistExecution(expected,
        { controller: 'popup', generation: 4, session: 8 })).assertFalse();
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
      const query: TrainWebAssistRetryOutcome = { state: 'retry', stage: 'query', progress: 'waiting' };
      const finalWait: TrainWebAssistRetryOutcome = { state: 'retry', stage: 'confirm', progress: 'waiting_modal' };
      expect(trainWebAssistRetryExhausted('initial', query, 19)).assertFalse();
      expect(trainWebAssistRetryExhausted('initial', query, 20)).assertTrue();
      expect(trainWebAssistRetryExhausted('final', finalWait, 39)).assertFalse();
      expect(trainWebAssistRetryExhausted('final', finalWait, 40)).assertTrue();
      const cancelledEpoch = nextTrainWebAssistEpoch(4);
      expect(isCurrentTrainWebAssistTimer(4, cancelledEpoch, false)).assertFalse();
      expect(isCurrentTrainWebAssistTimer(cancelledEpoch, cancelledEpoch, true)).assertFalse();
      expect(trainWebAssistFinalClickMayHaveRun('final', false,
        { state: 'retry', stage: 'confirm', progress: 'confirm_clicked' })).assertTrue();
      expect(trainWebAssistFinalClickMayHaveRun('final', true, undefined)).assertTrue();
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
