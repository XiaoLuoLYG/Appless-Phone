import { describe, it, expect } from '@ohos/hypium';
import { preferences } from '@kit.ArkData';
import {
  buildTrainPresaleFinalConfirmScript, buildTrainPresaleWebAssistScript,
  buildTrainWebAssistExecutionRequest,
  isCurrentTrainWebAssistExecution, isCurrentTrainWebAssistLifecycleEvent,
  isCurrentTrainWebAssistTimer, nextTrainWebAssistEpoch,
  parseTrainWebAssistOutcome, trainWebAssistDurableGateReason,
  trainWebAssistFinalClickMayHaveRun, trainWebAssistRetryExhausted, trainWebAssistTargetState,
  initialTrainWebAssistBudget, trainWebAssistBudgetAfterActivation,
  trainWebAssistBudgetAfterExecution, trainWebAssistBudgetForOutcome,
  trainWebAssistBudgetForStageTransition, trainWebAssistLoadErrorOutcome,
  trainWebAssistNavigationTimeoutMs, trainWebAssistNavigationTimeoutOutcome,
  TrainWebAssistBudget, TrainWebAssistExecutionBinding,
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

interface GeneratedScriptConfig {
  trainCode: string;
  travelDate: string;
  fromName: string;
  fromCode: string;
  toName: string;
  toCode: string;
}

interface QueryDomFixture {
  search: string;
  trainDate: string;
  fromName: string;
  fromCode: string;
  toName: string;
  toCode: string;
  rowTrainCode: string;
  rowId: string;
  rowFromName: string;
  rowToName: string;
}

interface FormDomFixture {
  trainCode: string;
  travelDate: string;
  fromName: string;
  fromCode: string;
  toName: string;
  toCode: string;
}

interface ModalDomFixture {
  cells: string[];
  form: FormDomFixture;
}

interface ScriptHarnessOutcome {
  state: 'retry' | 'needs_user';
  reason: string;
  progress: string;
}

class ClickSpy {
  count: number = 0;
  click(): void { this.count += 1; }
}

function generatedConfig(script: string): GeneratedScriptConfig | undefined {
  const prefix = 'const cfg=';
  const start = script.indexOf(prefix);
  const end = script.indexOf(';const out=', start + prefix.length);
  if (start < 0 || end < 0) return undefined;
  try {
    return JSON.parse(script.substring(start + prefix.length, end)) as GeneratedScriptConfig;
  } catch (_error) {
    return undefined;
  }
}

function hasScriptGuards(script: string, guards: string[]): boolean {
  for (let index = 0; index < guards.length; index++) {
    if (script.indexOf(guards[index]) < 0) return false;
  }
  return true;
}

function searchParam(search: string, name: string): string {
  const parts = search.replace(/^\?/, '').split('&');
  for (let index = 0; index < parts.length; index++) {
    const pair = parts[index].split('=');
    if (decodeURIComponent(pair[0]) === name) return decodeURIComponent(pair.slice(1).join('='));
  }
  return '';
}

function formMatches(config: GeneratedScriptConfig, form: FormDomFixture): boolean {
  return form.trainCode === config.trainCode && form.travelDate === config.travelDate &&
    form.fromName === config.fromName && form.fromCode === config.fromCode &&
    form.toName === config.toName && form.toCode === config.toCode;
}

function executeGeneratedQueryContract(script: string, dom: QueryDomFixture, booking: ClickSpy): ScriptHarnessOutcome {
  const config = generatedConfig(script);
  const guarded = hasScriptGuards(script, ["params.get('date')===cfg.travelDate",
    "field('#fromStationText')===cfg.fromName", "field('#fromStation')===cfg.fromCode",
    "field('#toStationText')===cfg.toName", "field('#toStation')===cfg.toCode",
    'parts[parts.length-2]!==cfg.fromCode', 'parts[parts.length-1]!==cfg.toCode',
    'names[0]!==cfg.fromName||names[1]!==cfg.toName', "return stop('trip_mismatch')"]);
  if (config === undefined || !guarded) return { state: 'needs_user', reason: 'invalid_result', progress: '' };
  const rowParts = dom.rowId.split('_');
  const matches = searchParam(dom.search, 'date') === config.travelDate &&
    searchParam(dom.search, 'fs') === config.fromName + ',' + config.fromCode &&
    searchParam(dom.search, 'ts') === config.toName + ',' + config.toCode &&
    dom.trainDate === config.travelDate && dom.fromName === config.fromName && dom.fromCode === config.fromCode &&
    dom.toName === config.toName && dom.toCode === config.toCode && dom.rowTrainCode === config.trainCode &&
    rowParts.length >= 3 && rowParts[rowParts.length - 2] === config.fromCode &&
    rowParts[rowParts.length - 1] === config.toCode && dom.rowFromName === config.fromName &&
    dom.rowToName === config.toName;
  if (!matches) return { state: 'needs_user', reason: 'trip_mismatch', progress: '' };
  booking.click();
  return { state: 'retry', reason: '', progress: 'booking_clicked' };
}

function executeGeneratedFormContract(script: string, form: FormDomFixture, submit: ClickSpy): ScriptHarnessOutcome {
  const config = generatedConfig(script);
  const guarded = hasScriptGuards(script, ['detail.station_train_code!==cfg.trainCode',
    'detail.from_station_name!==cfg.fromName', 'detail.from_station_telecode!==cfg.fromCode',
    'detail.to_station_name!==cfg.toName', 'detail.to_station_telecode!==cfg.toCode',
    'exactDate(detail.start_train_date)', "if(!formTrip())return stop('trip_mismatch')"]);
  if (config === undefined || !guarded) return { state: 'needs_user', reason: 'invalid_result', progress: '' };
  if (!formMatches(config, form)) return { state: 'needs_user', reason: 'trip_mismatch', progress: '' };
  submit.click();
  return { state: 'retry', reason: '', progress: 'order_submitted' };
}

function executeGeneratedFinalContract(script: string, modal: ModalDomFixture,
  confirm: ClickSpy): ScriptHarnessOutcome {
  const config = generatedConfig(script);
  const guarded = hasScriptGuards(script, ["cells.some((v)=>exactDate(v))",
    "cells.some((v)=>exactStation(v,cfg.fromName,'from'))",
    "cells.some((v)=>exactStation(v,cfg.toName,'to'))", "if(!formTrip())return stop('trip_mismatch')",
    'confirm.click()']);
  if (config === undefined || !guarded) return { state: 'needs_user', reason: 'invalid_result', progress: '' };
  if (!formMatches(config, modal.form)) return { state: 'needs_user', reason: 'trip_mismatch', progress: '' };
  if (modal.cells.indexOf(config.trainCode) < 0 || modal.cells.indexOf(config.travelDate) < 0 ||
    modal.cells.indexOf(config.fromName) < 0 || modal.cells.indexOf(config.toName) < 0) {
    return { state: 'needs_user', reason: 'confirmation_mismatch', progress: '' };
  }
  confirm.click();
  return { state: 'retry', reason: '', progress: 'confirm_clicked' };
}

function queryFixture(): QueryDomFixture {
  return {
    search: '?date=2026-07-23&fs=' + encodeURIComponent('上海虹桥,AOH') +
      '&ts=' + encodeURIComponent('北京南,VNP'),
    trainDate: '2026-07-23', fromName: '上海虹桥', fromCode: 'AOH', toName: '北京南', toCode: 'VNP',
    rowTrainCode: 'G10', rowId: '24000000G10_AOH_VNP', rowFromName: '上海虹桥', rowToName: '北京南'
  };
}

function formFixture(): FormDomFixture {
  return { trainCode: 'G10', travelDate: '2026-07-23', fromName: '上海虹桥', fromCode: 'AOH',
    toName: '北京南', toCode: 'VNP' };
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
      expect(initial.indexOf('"travelDate":"2026-07-23"') >= 0).assertTrue();
      expect(initial.indexOf('"fromName":"上海虹桥"') >= 0).assertTrue();
      expect(initial.indexOf('"fromCode":"AOH"') >= 0).assertTrue();
      expect(initial.indexOf('"toName":"北京南"') >= 0).assertTrue();
      expect(initial.indexOf('"toCode":"VNP"') >= 0).assertTrue();
    });

    it('production query and form seams fail closed on any stale authorized trip identity', 0, () => {
      const initial = buildTrainPresaleWebAssistScript(task());
      const finalScript = buildTrainPresaleFinalConfirmScript(task());
      expect(initial.indexOf('new URLSearchParams(location.search)') >= 0).assertTrue();
      expect(initial.indexOf("params.get('date')===cfg.travelDate") >= 0).assertTrue();
      expect(initial.indexOf("params.get('fs')===cfg.fromName+','+cfg.fromCode") >= 0).assertTrue();
      expect(initial.indexOf("params.get('ts')===cfg.toName+','+cfg.toCode") >= 0).assertTrue();
      expect(initial.indexOf("field('#train_date')") >= 0).assertTrue();
      expect(initial.indexOf("field('#fromStationText')===cfg.fromName") >= 0).assertTrue();
      expect(initial.indexOf("field('#fromStation')===cfg.fromCode") >= 0).assertTrue();
      expect(initial.indexOf("field('#toStationText')===cfg.toName") >= 0).assertTrue();
      expect(initial.indexOf("field('#toStation')===cfg.toCode") >= 0).assertTrue();
      expect(initial.indexOf("parts[parts.length-2]!==cfg.fromCode") >= 0).assertTrue();
      expect(initial.indexOf("parts[parts.length-1]!==cfg.toCode") >= 0).assertTrue();
      expect(initial.indexOf("names[0]!==cfg.fromName||names[1]!==cfg.toName") >= 0).assertTrue();
      expect(initial.indexOf("detail.station_train_code!==cfg.trainCode") >= 0).assertTrue();
      expect(initial.indexOf("detail.from_station_name!==cfg.fromName") >= 0).assertTrue();
      expect(initial.indexOf("detail.from_station_telecode!==cfg.fromCode") >= 0).assertTrue();
      expect(initial.indexOf("detail.to_station_name!==cfg.toName") >= 0).assertTrue();
      expect(initial.indexOf("detail.to_station_telecode!==cfg.toCode") >= 0).assertTrue();
      expect(initial.indexOf("exactDate(detail.start_train_date)") >= 0).assertTrue();
      expect(initial.indexOf("return stop('trip_mismatch')") >= 0).assertTrue();
      expect(finalScript.indexOf('formTrip()') >= 0).assertTrue();
      const unsafe = task();
      unsafe.fromName = '</script><script>alert(1)</script>';
      expect(buildTrainPresaleWebAssistScript(unsafe).indexOf('</script>')).assertEqual(-1);
      expect(buildTrainPresaleWebAssistScript(unsafe).indexOf('\\u003c/script\\u003e')).assertLarger(-1);
    });

    it('executes generated query contract fixtures without booking a mutated trip', 0, () => {
      const script = buildTrainPresaleWebAssistScript(task());
      const happy = queryFixture();
      const happyClick = new ClickSpy();
      expect(executeGeneratedQueryContract(script, happy, happyClick).progress).assertEqual('booking_clicked');
      expect(happyClick.count).assertEqual(1);

      let wrong = queryFixture(); let click = new ClickSpy();
      wrong.search = '?date=2026-07-24&fs=' + encodeURIComponent('上海虹桥,AOH') +
        '&ts=' + encodeURIComponent('北京南,VNP'); wrong.trainDate = '2026-07-24';
      expect(executeGeneratedQueryContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);

      wrong = queryFixture(); click = new ClickSpy(); wrong.fromName = '上海站'; wrong.rowFromName = '上海站';
      wrong.search = '?date=2026-07-23&fs=' + encodeURIComponent('上海站,AOH') +
        '&ts=' + encodeURIComponent('北京南,VNP');
      expect(executeGeneratedQueryContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);

      wrong = queryFixture(); click = new ClickSpy(); wrong.fromCode = 'SHH'; wrong.rowId = '24000000G10_SHH_VNP';
      wrong.search = '?date=2026-07-23&fs=' + encodeURIComponent('上海虹桥,SHH') +
        '&ts=' + encodeURIComponent('北京南,VNP');
      expect(executeGeneratedQueryContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);

      wrong = queryFixture(); click = new ClickSpy(); wrong.toName = '北京站'; wrong.rowToName = '北京站';
      wrong.search = '?date=2026-07-23&fs=' + encodeURIComponent('上海虹桥,AOH') +
        '&ts=' + encodeURIComponent('北京站,VNP');
      expect(executeGeneratedQueryContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);

      wrong = queryFixture(); click = new ClickSpy(); wrong.toCode = 'BJP'; wrong.rowId = '24000000G10_AOH_BJP';
      wrong.search = '?date=2026-07-23&fs=' + encodeURIComponent('上海虹桥,AOH') +
        '&ts=' + encodeURIComponent('北京南,BJP');
      expect(executeGeneratedQueryContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);
    });

    it('executes generated passenger form contract fixtures without submitting a mutated trip', 0, () => {
      const script = buildTrainPresaleWebAssistScript(task());
      const happyClick = new ClickSpy();
      expect(executeGeneratedFormContract(script, formFixture(), happyClick).progress).assertEqual('order_submitted');
      expect(happyClick.count).assertEqual(1);

      let wrong = formFixture(); let click = new ClickSpy(); wrong.travelDate = '2026-07-24';
      expect(executeGeneratedFormContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);
      wrong = formFixture(); click = new ClickSpy(); wrong.fromName = '上海站';
      expect(executeGeneratedFormContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);
      wrong = formFixture(); click = new ClickSpy(); wrong.fromCode = 'SHH';
      expect(executeGeneratedFormContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);
      wrong = formFixture(); click = new ClickSpy(); wrong.toName = '北京站';
      expect(executeGeneratedFormContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);
      wrong = formFixture(); click = new ClickSpy(); wrong.toCode = 'BJP';
      expect(executeGeneratedFormContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);
    });

    it('executes generated final modal contract fixtures without confirming a mutated trip', 0, () => {
      const script = buildTrainPresaleFinalConfirmScript(task());
      const happyClick = new ClickSpy();
      const happy: ModalDomFixture = { cells: ['2026-07-23', 'G10', '上海虹桥', '北京南'], form: formFixture() };
      expect(executeGeneratedFinalContract(script, happy, happyClick).progress).assertEqual('confirm_clicked');
      expect(happyClick.count).assertEqual(1);

      let wrong: ModalDomFixture = { cells: ['2026-07-24', 'G10', '上海虹桥', '北京南'], form: formFixture() };
      let click = new ClickSpy();
      expect(executeGeneratedFinalContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);
      wrong = { cells: ['2026-07-23', 'G10', '上海站', '北京南'], form: formFixture() }; click = new ClickSpy();
      expect(executeGeneratedFinalContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);
      wrong = { cells: ['2026-07-23', 'G10', '上海虹桥', '北京南'], form: formFixture() };
      wrong.form.fromCode = 'SHH'; click = new ClickSpy();
      expect(executeGeneratedFinalContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);
      wrong = { cells: ['2026-07-23', 'G10', '上海虹桥', '北京站'], form: formFixture() }; click = new ClickSpy();
      expect(executeGeneratedFinalContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);
      wrong = { cells: ['2026-07-23', 'G10', '上海虹桥', '北京南'], form: formFixture() };
      wrong.form.toCode = 'BJP'; click = new ClickSpy();
      expect(executeGeneratedFinalContract(script, wrong, click).state).assertEqual('needs_user');
      expect(click.count).assertEqual(0);
    });

    it('production script snapshot enforces exact visible modal multiplicity and seat-row alignment', 0, () => {
      const script = buildTrainPresaleFinalConfirmScript(task());
      expect(script.indexOf("cells.filter((v)=>v===cfg.trainCode).length!==1") >= 0).assertTrue();
      expect(script.indexOf("cells.some((v)=>exactDate(v))") >= 0).assertTrue();
      expect(script.indexOf("cells.some((v)=>exactStation(v,cfg.fromName,'from'))") >= 0).assertTrue();
      expect(script.indexOf("cells.some((v)=>exactStation(v,cfg.toName,'to'))") >= 0).assertTrue();
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
      let budget: TrainWebAssistBudget = initialTrainWebAssistBudget();
      budget = trainWebAssistBudgetAfterExecution(budget);
      budget = trainWebAssistBudgetForOutcome(budget, query);
      for (let index = 1; index < 19; index++) {
        budget = trainWebAssistBudgetAfterActivation(budget);
        budget = trainWebAssistBudgetAfterExecution(budget);
        budget = trainWebAssistBudgetForOutcome(budget, query);
      }
      expect(budget.attempts).assertEqual(19);
      expect(trainWebAssistRetryExhausted('initial', query, budget.attempts)).assertFalse();
      budget = trainWebAssistBudgetAfterExecution(trainWebAssistBudgetAfterActivation(budget));
      budget = trainWebAssistBudgetForOutcome(budget, query);
      expect(trainWebAssistRetryExhausted('initial', query, budget.attempts)).assertTrue();
      const passengerBudget = trainWebAssistBudgetForOutcome(budget,
        { state: 'retry', stage: 'passenger', progress: 'waiting_form' });
      expect(passengerBudget.attempts).assertEqual(1);
      const passengerAttempt = trainWebAssistBudgetAfterExecution(passengerBudget);
      const backwardOutcome = trainWebAssistBudgetForOutcome(passengerAttempt, query);
      expect(backwardOutcome.stage).assertEqual('passenger');
      expect(backwardOutcome.attempts).assertEqual(2);
      expect(trainWebAssistBudgetForStageTransition('confirm').attempts).assertEqual(0);
      const activeError: TrainWebAssistExecutionBinding = { controller: 'main', generation: 7, session: 11 };
      expect(isCurrentTrainWebAssistLifecycleEvent('main', 7, 11, activeError)).assertTrue();
      expect(isCurrentTrainWebAssistLifecycleEvent('main', 8, 11, activeError)).assertFalse();
      expect(isCurrentTrainWebAssistLifecycleEvent('popup', 7, 11, activeError)).assertFalse();
      expect(isCurrentTrainWebAssistLifecycleEvent('main', 7, 12, activeError)).assertFalse();
      expect(trainWebAssistLoadErrorOutcome('page_mismatch', 'main', 7, 11, activeError)?.state)
        .assertEqual('needs_user');
      expect(trainWebAssistLoadErrorOutcome('network-secret', 'main', 7, 11, activeError)?.reason)
        .assertEqual('invalid_result');
      expect(trainWebAssistLoadErrorOutcome('page_mismatch', 'main', 8, 11, activeError))
        .assertEqual(undefined);
      expect(trainWebAssistNavigationTimeoutMs()).assertEqual(15000);
      const timeoutOutcome = trainWebAssistNavigationTimeoutOutcome('main', 7, 11, activeError);
      expect(timeoutOutcome?.reason).assertEqual('timeout');
      expect(timeoutOutcome === undefined ? undefined : trainWebAssistTargetState(timeoutOutcome))
        .assertEqual('needs_user');
      expect(trainWebAssistNavigationTimeoutOutcome('main', 8, 11, activeError))
        .assertEqual(undefined);
      const popupTimeout: TrainWebAssistExecutionBinding = { controller: 'popup', generation: 9, session: 13 };
      expect(trainWebAssistNavigationTimeoutOutcome('popup', 9, 13, popupTimeout)?.state)
        .assertEqual('needs_user');
      const timeoutCancelledEpoch = nextTrainWebAssistEpoch(12);
      expect(isCurrentTrainWebAssistTimer(12, timeoutCancelledEpoch, false)).assertFalse();
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
