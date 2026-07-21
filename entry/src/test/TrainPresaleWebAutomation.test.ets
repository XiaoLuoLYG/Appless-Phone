import { describe, it, expect } from '@ohos/hypium';
import { preferences } from '@kit.ArkData';
import {
  buildTrainPresaleWebAssistScript,
  parseTrainWebAssistOutcome,
  trainPresaleWebAssistScriptForCheckout,
  trainWebAssistTargetState,
  TrainWebAssistAwaitingPaymentOutcome,
  TrainWebAssistContinuingOutcome,
  TrainWebAssistNeedsUserOutcome,
  TrainWebAssistOutcome
} from '../main/ets/pages/A2uiHome/train/TrainPresaleWebAutomation';
import {
  TrainPresaleTask,
  TrainPresaleTaskState
} from '../main/ets/pages/A2uiHome/train/TrainPresaleTaskStore';
import {
  transitionTrainPresaleHandoff,
  TRAIN_PRESALE_PENDING_TASK_KEY,
  TRAIN_PRESALE_TASKS_KEY
} from '../main/ets/entryability/EntryAbility';

class FlushTrackingPreferences {
  private values: Map<string, preferences.ValueType> = new Map();
  snapshots: string[] = [];

  getSync(key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    return this.values.has(key) ? this.values.get(key) as preferences.ValueType : defaultValue;
  }

  putSync(key: string, value: preferences.ValueType): void {
    this.values.set(key, value);
  }

  deleteSync(key: string): void {
    this.values.delete(key);
  }

  flushSync(): void {
    const pending = this.getSync(TRAIN_PRESALE_PENDING_TASK_KEY, '');
    const tasks = this.getSync(TRAIN_PRESALE_TASKS_KEY, '');
    this.snapshots.push((typeof pending === 'string' ? pending : '') + '|' +
      (typeof tasks === 'string' ? tasks : ''));
  }
}

function task(state: TrainPresaleTaskState = 'executing'): TrainPresaleTask {
  return {
    taskId: 'task-7',
    source: 'presale',
    state: state,
    trainCode: 'G100',
    travelDate: '2026-07-23',
    fromName: '上海虹桥',
    fromCode: 'AOH',
    toName: '北京南',
    toCode: 'VNP',
    saleAt: '2026-07-23T12:30:00+08:00',
    passengerNames: ['张三', '李四'],
    seatPriority: '二等座',
    bookingUrl: 'https://kyfw.12306.cn/otn/leftTicket/init?linktypeid=dc',
    reminderId: 7,
    createdAt: '2026-07-22T12:00:00+08:00',
    lastError: ''
  };
}

export default function trainPresaleWebAutomationTest() {
  describe('trainPresaleWebAutomation', () => {
    it('generates only the fixed 12306 selectors with bounded polling', 0, () => {
      const script = buildTrainPresaleWebAssistScript(task());

      expect(script.indexOf('#queryLeftTable') >= 0).assertTrue();
      expect(script.indexOf('a.number') >= 0).assertTrue();
      expect(script.indexOf('a.btn72') >= 0).assertTrue();
      expect(script.indexOf('#normal_passenger_id') >= 0).assertTrue();
      expect(script.indexOf('#seatType_1') >= 0).assertTrue();
      expect(script.indexOf('select[id^=seatType_]') >= 0).assertTrue();
      expect(script.indexOf('#submitOrder_id') >= 0).assertTrue();
      expect(script.indexOf('#checkticketinfo_id') >= 0).assertTrue();
      expect(script.indexOf('#qr_submit_id') >= 0).assertTrue();
      expect(script.indexOf('QUERY_POLL_LIMIT=20') >= 0).assertTrue();
      expect(script.indexOf('PASSENGER_POLL_LIMIT=40') >= 0).assertTrue();
      expect(script.indexOf('POLL_MS=250') >= 0).assertTrue();
      expect(script.indexOf('setInterval') >= 0).assertTrue();
      expect(script.indexOf('console.') >= 0).assertFalse();
    });

    it('uses exact train passenger seat-prefix and modal identity checks', 0, () => {
      const script = buildTrainPresaleWebAssistScript(task());

      expect(script.indexOf('===cfg.trainCode') >= 0).assertTrue();
      expect(script.indexOf('===name') >= 0).assertTrue();
      expect(script.indexOf('indexOf(cfg.seatPriority)===0') >= 0).assertTrue();
      expect(script.indexOf('modalText.indexOf(cfg.trainCode)') >= 0).assertTrue();
      expect(script.indexOf('modalText.indexOf(name)') >= 0).assertTrue();
    });

    it('refuses extra selected passengers and changes seats only for the authorized names', 0, () => {
      const script = buildTrainPresaleWebAssistScript(task());

      expect(script.indexOf("finish('needs_user','passenger_mismatch')") >= 0).assertTrue();
      expect(script.indexOf('new Set(cfg.passengerNames).size!==cfg.passengerNames.length') >= 0).assertTrue();
      expect(script.indexOf('seatIndex<cfg.passengerNames.length') >= 0).assertTrue();
    });

    it('JSON-escapes task values before embedding them in executable source', 0, () => {
      const value = task();
      value.passengerNames = ['A\";window.pwned=true;//\u2028</script>'];
      const script = buildTrainPresaleWebAssistScript(value);

      expect(script.indexOf('A";window.pwned=true') >= 0).assertFalse();
      expect(script.indexOf('</script>') >= 0).assertFalse();
      expect(script.indexOf('\\u003c/script\\u003e') >= 0).assertTrue();
      expect(script.indexOf('\\u2028') >= 0).assertTrue();
    });

    it('activates only for the exact bound executing train task', 0, () => {
      const executing = task();

      expect(trainPresaleWebAssistScriptForCheckout('train', 'task-7', executing).length > 0).assertTrue();
      expect(trainPresaleWebAssistScriptForCheckout('train', '', executing)).assertEqual('');
      expect(trainPresaleWebAssistScriptForCheckout('train', 'other', executing)).assertEqual('');
      expect(trainPresaleWebAssistScriptForCheckout('hotel', 'task-7', executing)).assertEqual('');
      expect(trainPresaleWebAssistScriptForCheckout('payment', 'task-7', executing)).assertEqual('');
      expect(trainPresaleWebAssistScriptForCheckout('train', 'task-7', task('scheduled'))).assertEqual('');
      expect(trainPresaleWebAssistScriptForCheckout('train', 'task-7', task('needs_user'))).assertEqual('');
    });

    it('accepts only the small sanitized result protocol', 0, () => {
      const continuing: TrainWebAssistOutcome = parseTrainWebAssistOutcome('{"state":"continuing"}');
      const payment: TrainWebAssistOutcome = parseTrainWebAssistOutcome('{"state":"awaiting_payment"}');
      const login: TrainWebAssistOutcome = parseTrainWebAssistOutcome(
        '{"state":"needs_user","reason":"login_required","page":"raw page"}');
      const captcha: TrainWebAssistOutcome = parseTrainWebAssistOutcome(
        '{"state":"needs_user","reason":"captcha_required"}');
      const mismatch: TrainWebAssistOutcome = parseTrainWebAssistOutcome(
        '{"state":"needs_user","reason":"train_mismatch"}');
      const invalid: TrainWebAssistOutcome = parseTrainWebAssistOutcome(
        '{"state":"needs_user","reason":"secret passenger contents"}');

      expect(continuing.state).assertEqual('continuing');
      expect(payment.state).assertEqual('awaiting_payment');
      expect(login.state).assertEqual('needs_user');
      expect(login.state === 'needs_user' ? login.reason : '').assertEqual('login_required');
      expect(captcha.state === 'needs_user' ? captcha.reason : '').assertEqual('captcha_required');
      expect(mismatch.state === 'needs_user' ? mismatch.reason : '').assertEqual('train_mismatch');
      expect(invalid.state === 'needs_user' ? invalid.reason : '').assertEqual('invalid_result');
      expect(parseTrainWebAssistOutcome('not json').state).assertEqual('needs_user');
    });

    it('maps only terminal results away from executing', 0, () => {
      const continuing: TrainWebAssistContinuingOutcome = { state: 'continuing' };
      const payment: TrainWebAssistAwaitingPaymentOutcome = { state: 'awaiting_payment' };
      const attention: TrainWebAssistNeedsUserOutcome = { state: 'needs_user', reason: 'timeout' };
      expect(trainWebAssistTargetState(continuing)).assertEqual(undefined);
      expect(trainWebAssistTargetState(payment)).assertEqual('awaiting_payment');
      expect(trainWebAssistTargetState(attention)).assertEqual('needs_user');
    });

    it('flushes the terminal task before clearing its matching handoff', 0, () => {
      const memory = new FlushTrackingPreferences();
      const store = memory as Object as preferences.Preferences;
      store.putSync(TRAIN_PRESALE_TASKS_KEY, JSON.stringify([task()]));
      store.putSync(TRAIN_PRESALE_PENDING_TASK_KEY, 'task-7');

      const result = transitionTrainPresaleHandoff(store, 'task-7', 'awaiting_payment', '');

      expect(result.cleared).assertTrue();
      expect(memory.snapshots.length).assertEqual(2);
      expect(memory.snapshots[0].startsWith('task-7|')).assertTrue();
      expect(memory.snapshots[0].indexOf('"state":"awaiting_payment"') >= 0).assertTrue();
      expect(memory.snapshots[1].startsWith('|')).assertTrue();
    });

    it('stops at verified official payment identities without a payment click', 0, () => {
      const script = buildTrainPresaleWebAssistScript(task());

      expect(script.indexOf("hostname==='epay.12306.cn'") >= 0).assertTrue();
      expect(script.indexOf("pathname.indexOf('/payOrder/')>=0") >= 0).assertTrue();
      expect(script.indexOf("finish('awaiting_payment')") >= 0).assertTrue();
      expect(script.indexOf('payment.submit') >= 0).assertFalse();
      expect(script.indexOf('payButton') >= 0).assertFalse();
    });

    it('has explicit sanitized stops for login captcha mismatch missing selectors and timeout', 0, () => {
      const script = buildTrainPresaleWebAssistScript(task());
      const reasons = [
        'login_required', 'captcha_required', 'page_mismatch', 'train_mismatch',
        'missing_passenger', 'passenger_mismatch', 'missing_seat', 'confirmation_mismatch', 'timeout'
      ];

      for (let index = 0; index < reasons.length; index++) {
        expect(script.indexOf(reasons[index]) >= 0).assertTrue();
      }
    });
  });
}
