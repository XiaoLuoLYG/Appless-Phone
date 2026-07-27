import { TrainPresaleTask, TrainPresaleTaskState } from './TrainPresaleTaskStore';

export interface TrainWebAssistRetryOutcome { state: 'retry'; stage: 'query' | 'passenger' | 'confirm'; progress: string; }
export interface TrainWebAssistReadyOutcome { state: 'ready_to_confirm'; }
export interface TrainWebAssistAwaitingPaymentOutcome { state: 'awaiting_payment'; }
export interface TrainWebAssistWaitingUserOutcome { state: 'waiting_user'; reason: string; }
export interface TrainWebAssistNeedsUserOutcome { state: 'needs_user'; reason: string; }
export type TrainWebAssistOutcome = TrainWebAssistRetryOutcome | TrainWebAssistReadyOutcome |
  TrainWebAssistAwaitingPaymentOutcome | TrainWebAssistWaitingUserOutcome | TrainWebAssistNeedsUserOutcome;

interface TrainWebAssistConfig {
  trainCode: string;
  travelDate: string;
  fromName: string;
  fromCode: string;
  toName: string;
  toCode: string;
  passengerNames: string[];
  seatPriority: string;
  unpaidOrderAuthorized: boolean;
}

export type TrainWebAssistRunStage = 'initial' | 'final';
export interface TrainWebAssistExecutionBinding {
  controller: 'main' | 'popup';
  generation: number;
  session: number;
}

export type TrainWebAssistBudgetStage = 'none' | 'query' | 'passenger' | 'confirm';
export interface TrainWebAssistBudget {
  stage: TrainWebAssistBudgetStage;
  attempts: number;
}

const SANITIZED_REASONS: string[] = [
  'login_required', 'captcha_required', 'page_mismatch', 'train_mismatch', 'trip_mismatch', 'missing_passenger',
  'passenger_mismatch', 'missing_seat', 'confirmation_mismatch', 'not_authorized', 'timeout',
  'no_navigation', 'script_error', 'invalid_result'
];

function scriptJson(value: TrainWebAssistConfig): string {
  return JSON.stringify(value).replace(/</g, '\\u003c').replace(/>/g, '\\u003e').replace(/&/g, '\\u0026')
    .replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029');
}

function exactKeys(value: Object, expected: string[]): boolean {
  const keys = Object.keys(value).sort();
  const wanted = expected.slice().sort();
  return JSON.stringify(keys) === JSON.stringify(wanted);
}

function sanitizedReason(value: string): string {
  return SANITIZED_REASONS.indexOf(value) >= 0 ? value : 'invalid_result';
}

export function trainWebAssistRetryLimit(stage: 'query' | 'passenger' | 'confirm'): number {
  return stage === 'query' ? 20 : (stage === 'confirm' ? 80 : 40);
}

export function trainWebAssistRetryExhausted(stage: TrainWebAssistRunStage,
  outcome: TrainWebAssistRetryOutcome, attempts: number): boolean {
  if ((stage === 'final' && outcome.stage !== 'confirm') ||
    (stage === 'initial' && outcome.stage === 'confirm')) return true;
  return attempts >= trainWebAssistRetryLimit(outcome.stage);
}

export function initialTrainWebAssistBudget(): TrainWebAssistBudget {
  return { stage: 'none', attempts: 0 };
}

export function trainWebAssistBudgetAfterActivation(budget: TrainWebAssistBudget): TrainWebAssistBudget {
  return { stage: budget.stage, attempts: budget.attempts };
}

export function trainWebAssistBudgetAfterExecution(budget: TrainWebAssistBudget): TrainWebAssistBudget {
  return { stage: budget.stage, attempts: budget.attempts + 1 };
}

export function trainWebAssistBudgetForOutcome(budget: TrainWebAssistBudget,
  outcome: TrainWebAssistRetryOutcome): TrainWebAssistBudget {
  if (budget.stage === outcome.stage) return { stage: budget.stage, attempts: budget.attempts };
  if (budget.stage === 'none' || (budget.stage === 'query' && outcome.stage === 'passenger')) {
    return { stage: outcome.stage, attempts: 1 };
  }
  return { stage: budget.stage, attempts: budget.attempts };
}

export function trainWebAssistBudgetForStageTransition(stage: 'query' | 'passenger' | 'confirm'):
  TrainWebAssistBudget {
  return { stage, attempts: 0 };
}

export function isCurrentTrainWebAssistExecution(expected: TrainWebAssistExecutionBinding,
  actual: TrainWebAssistExecutionBinding): boolean {
  return expected.controller === actual.controller && expected.generation === actual.generation &&
    expected.session === actual.session;
}

export function isCurrentTrainWebAssistLifecycleEvent(activeController: 'main' | 'popup' | 'none',
  activeGeneration: number, activeSession: number, actual: TrainWebAssistExecutionBinding): boolean {
  return activeController === actual.controller && activeGeneration === actual.generation &&
    activeSession === actual.session;
}

export function trainWebAssistLoadErrorOutcome(reason: string, activeController: 'main' | 'popup' | 'none',
  activeGeneration: number, activeSession: number,
  actual: TrainWebAssistExecutionBinding): TrainWebAssistNeedsUserOutcome | undefined {
  return isCurrentTrainWebAssistLifecycleEvent(activeController, activeGeneration, activeSession, actual) ?
    { state: 'needs_user', reason: sanitizedReason(reason) } : undefined;
}

export function trainWebAssistNavigationTimeoutMs(): number { return 15000; }

export function trainWebAssistNavigationTimeoutOutcome(activeController: 'main' | 'popup' | 'none',
  activeGeneration: number, activeSession: number,
  actual: TrainWebAssistExecutionBinding): TrainWebAssistNeedsUserOutcome | undefined {
  return isCurrentTrainWebAssistLifecycleEvent(activeController, activeGeneration, activeSession, actual) ?
    { state: 'needs_user', reason: 'timeout' } : undefined;
}

export function nextTrainWebAssistEpoch(current: number): number { return current + 1; }

export function isCurrentTrainWebAssistTimer(capturedEpoch: number, currentEpoch: number,
  disposed: boolean): boolean {
  return !disposed && capturedEpoch === currentEpoch;
}

export function trainWebAssistFinalClickMayHaveRun(stage: TrainWebAssistRunStage,
  finalRequestWasInFlight: boolean, outcome: TrainWebAssistOutcome | undefined): boolean {
  return stage === 'final' && (finalRequestWasInFlight || (outcome !== undefined && outcome.state === 'retry' &&
    outcome.stage === 'confirm' && outcome.progress === 'confirm_clicked'));
}

export function isOfficialTrainAssistUrl(value: string): boolean {
  const normalized = value.trim().toLowerCase();
  if (!normalized.startsWith('https://')) return false;
  const remainder = normalized.substring(8);
  let end = remainder.length;
  const separators: number[] = [remainder.indexOf('/'), remainder.indexOf('?'), remainder.indexOf('#')];
  for (let index = 0; index < separators.length; index++) {
    if (separators[index] >= 0 && separators[index] < end) end = separators[index];
  }
  return remainder.substring(0, end) === 'kyfw.12306.cn';
}

export function trainWebAssistDurableGateReason(kind: string, boundTaskId: string, pendingTaskId: string,
  task: TrainPresaleTask | undefined, activeUrl: string): string {
  if (kind !== 'train' || boundTaskId.length === 0 || pendingTaskId !== boundTaskId || task === undefined ||
    task.taskId !== boundTaskId || task.state !== 'executing' || !task.unpaidOrderAuthorized) {
    return 'not_authorized';
  }
  return isOfficialTrainAssistUrl(activeUrl) ? '' : 'page_mismatch';
}

export interface TrainWebAssistExecutionRequest {
  script: string;
  reason: string;
}

export function buildTrainWebAssistExecutionRequest(stage: TrainWebAssistRunStage, kind: string,
  boundTaskId: string, pendingTaskId: string, task: TrainPresaleTask | undefined,
  activeUrl: string): TrainWebAssistExecutionRequest {
  const reason = trainWebAssistDurableGateReason(kind, boundTaskId, pendingTaskId, task, activeUrl);
  if (reason.length > 0 || task === undefined) return { script: '', reason: reason };
  return { script: stage === 'final' ? buildTrainPresaleFinalConfirmScript(task) :
    buildTrainPresaleWebAssistScript(task), reason: '' };
}

function commonScript(config: TrainWebAssistConfig): string {
  return `'use strict';const cfg=${scriptJson(config)};` +
    `const out=(v)=>JSON.stringify(v);const txt=(n)=>n&&n.textContent?n.textContent.trim():'';` +
    `const field=(q)=>{const n=document.querySelector(q);return n&&typeof n.value==='string'?n.value.trim():'';};` +
    `const compact=(v)=>String(v===undefined||v===null?'':v).replace(/\\s+/g,'').trim();` +
    `const exactDate=(v)=>{const raw=compact(v),plain=cfg.travelDate.replace(/-/g,'');` +
    `if(raw===cfg.travelDate||raw===plain)return true;let m=raw.match(/^(\\d{4})-(\\d{2})-(\\d{2})(?:（?周[一二三四五六日]）?)?$/);` +
    `if(!m)m=raw.match(/^(\\d{4})年(\\d{2})月(\\d{2})日(?:（周[一二三四五六日]）)?$/);` +
    `return !!m&&(m[1]+'-'+m[2]+'-'+m[3])===cfg.travelDate;};` +
    `const regex=(v)=>String(v).replace(/[.*+?^\${}()|[\\]\\\\]/g,'\\\\$&');` +
    `const exactStation=(v,name,side)=>{const raw=compact(v),station=compact(name);` +
    `if(raw===station||raw===station+'站')return true;if(side!=='to')return false;` +
    `return new RegExp('^（(?:[01]\\\\d|2[0-3]):[0-5]\\\\d开）—'+regex(station)+'站?$').test(raw);};` +
    `const visible=(n)=>{if(!n)return false;const s=getComputedStyle(n),r=n.getBoundingClientRect();` +
    `return s.display!=='none'&&s.visibility!=='hidden'&&s.opacity!=='0'&&r.width>0&&r.height>0;};` +
    `const shown=(q)=>Array.from(document.querySelectorAll(q)).some(visible);` +
    `const payment=()=>location.protocol.toLowerCase()==='https:'&&` +
    `(location.hostname.toLowerCase()==='epay.12306.cn'||` +
    `(location.hostname.toLowerCase()==='kyfw.12306.cn'&&location.pathname.indexOf('/payOrder/')===0));` +
    `const labelFor=(box,labels)=>Array.from(labels).filter((label)=>label.htmlFor===box.id);` +
    `const marker=window.__aiphoneTrainAssist||(window.__aiphoneTrainAssist={});` +
    `const retry=(stage,progress)=>out({state:'retry',stage:stage,progress:progress});` +
    `const waitUser=(reason)=>out({state:'waiting_user',reason:reason});` +
    `const stop=(reason)=>out({state:'needs_user',reason:reason});` +
    `const queryTrip=()=>{const params=new URLSearchParams(location.search);return ` +
    `params.get('date')===cfg.travelDate&&params.get('fs')===cfg.fromName+','+cfg.fromCode&&` +
    `params.get('ts')===cfg.toName+','+cfg.toCode&&exactDate(field('#train_date'))&&` +
    `field('#fromStationText')===cfg.fromName&&field('#fromStation')===cfg.fromCode&&` +
    `field('#toStationText')===cfg.toName&&field('#toStation')===cfg.toCode;};` +
    `const rowTrip=(row,link)=>{const parts=String(link.id||'').split('_');` +
    `if(parts.length<3||parts[parts.length-2]!==cfg.fromCode||parts[parts.length-1]!==cfg.toCode)return false;` +
    `const names=Array.from(row.querySelectorAll('.cdz strong')).filter(visible).map((n)=>compact(n.getAttribute('title')||txt(n)));` +
    `return names.length===2&&(names[0]!==cfg.fromName||names[1]!==cfg.toName?false:true);};` +
    `const formTrip=()=>{const form=window.ticketInfoForPassengerForm,detail=form&&form.queryLeftNewDetailDTO,` +
    `request=form&&form.queryLeftTicketRequestDTO;if(!detail||!request||detail.station_train_code!==cfg.trainCode||` +
    `detail.from_station_name!==cfg.fromName||` +
    `detail.from_station_telecode!==cfg.fromCode||detail.to_station_name!==cfg.toName||` +
    `detail.to_station_telecode!==cfg.toCode||!exactDate(request.train_date))return false;return true;};` +
    `const modalRows=(modal)=>Array.from(modal.querySelectorAll('#check_ticketInfo_id tr')).filter(visible);` +
    `const verifyModal=()=>{const modal=document.querySelector('#checkticketinfo_id');` +
    `if(!modal||!Array.from(modal.querySelectorAll('td,th,span,strong')).some(visible))return 'wait';` +
    `const cells=Array.from(modal.querySelectorAll('td,th,span,strong')).filter(visible).map(txt);` +
    `if(cells.filter((v)=>v===cfg.trainCode).length!==1)return 'confirmation_mismatch';` +
    `if(!cells.some((v)=>exactDate(v))||!cells.some((v)=>exactStation(v,cfg.fromName,'from'))||` +
    `!cells.some((v)=>exactStation(v,cfg.toName,'to')))return 'confirmation_mismatch';` +
    `const rows=modalRows(modal);if(rows.length!==cfg.passengerNames.length)return 'confirmation_mismatch';` +
    `const names=[];for(const row of rows){const rc=Array.from(row.querySelectorAll('td,span')).filter(visible).map(txt);` +
    `const found=cfg.passengerNames.filter((name)=>rc.filter((v)=>v===name).length===1);` +
    `if(found.length!==1||rc.filter((v)=>v.indexOf(cfg.seatPriority)===0).length!==1)return 'confirmation_mismatch';names.push(found[0]);}` +
    `if(names.slice().sort().join('\\u0000')!==cfg.passengerNames.slice().sort().join('\\u0000'))return 'confirmation_mismatch';return '';};`;
}

export function buildTrainPresaleWebAssistScript(task: TrainPresaleTask): string {
  const config: TrainWebAssistConfig = { trainCode: task.trainCode, travelDate: task.travelDate,
    fromName: task.fromName, fromCode: task.fromCode, toName: task.toName, toCode: task.toCode,
    passengerNames: task.passengerNames,
    seatPriority: task.seatPriority, unpaidOrderAuthorized: task.unpaidOrderAuthorized };
  return `(function(){${commonScript(config)}` +
    `if(payment())return out({state:'awaiting_payment'});` +
    `if(location.protocol.toLowerCase()!=='https:'||location.hostname.toLowerCase()!=='kyfw.12306.cn')return stop('page_mismatch');` +
    `if(shown('.login-hd-account,#J-login'))return waitUser('login_required');` +
    `if(shown('#J-loginImg,.touclick-wrapper'))return waitUser('captcha_required');` +
    `const warningHeader=document.querySelector('#content_defaultwarningAlert_hearder');if(visible(warningHeader)){` +
    `const warningText=compact(txt(warningHeader));` +
    `if(warningText.indexOf('您选择的列车距开车时间很近了')!==0)return stop('unexpected_warning');` +
    `const proceed=document.querySelector('#qd_closeDefaultWarningWindowDialog_id');` +
    `if(!visible(proceed))return retry('query','waiting_departure_warning');` +
    `if(!marker.departureWarningConfirmed){marker.departureWarningConfirmed=true;proceed.click();}` +
    `return retry('query','departure_warning_confirmed');}` +
    `const table=document.querySelector('#queryLeftTable');if(table){if(!queryTrip())return stop('trip_mismatch');` +
    `const rows=Array.from(table.querySelectorAll('tr'));` +
    `const matches=rows.filter((row)=>{const link=row.querySelector('a.number');return visible(link)&&` +
    `txt(link)===cfg.trainCode&&rowTrip(row,link);});` +
    `if(matches.length!==1)return stop('train_mismatch');const booking=matches[0].querySelector('a.btn72');` +
    `if(!visible(booking))return retry('query','waiting_booking');if(!marker.bookingClicked){marker.bookingClicked=true;booking.click();}` +
    `return retry('query','booking_clicked');}` +
    `if(location.pathname==='/otn/leftTicket/init')return retry('query','waiting_query');` +
    `const root=document.querySelector('#normal_passenger_id'),submit=document.querySelector('#submitOrder_id');` +
    `if(!root||!visible(submit))return retry('passenger','waiting_form');` +
    `if(!formTrip())return stop('trip_mismatch');` +
    `if(new Set(cfg.passengerNames).size!==cfg.passengerNames.length)return stop('passenger_mismatch');` +
    `const boxes=Array.from(root.querySelectorAll('input[type=checkbox]')),labels=root.querySelectorAll('label');let changed=false;` +
    `for(const name of cfg.passengerNames){const found=boxes.filter((box)=>{const ls=labelFor(box,labels);return ls.length===1&&txt(ls[0])===name;});` +
    `if(found.length!==1)return stop('missing_passenger');if(!found[0].checked){found[0].click();changed=true;}}` +
    `if(changed)return retry('passenger','passengers_clicked');const selected=boxes.filter((box)=>box.checked);` +
    `const selectedNames=[];for(const box of selected){const ls=labelFor(box,labels);if(ls.length!==1)return stop('passenger_mismatch');selectedNames.push(txt(ls[0]));}` +
    `if(selectedNames.slice().sort().join('\\u0000')!==cfg.passengerNames.slice().sort().join('\\u0000'))return stop('passenger_mismatch');` +
    `let seatChanged=false;for(let i=0;i<selected.length;i+=1){const name=selectedNames[i],seat=document.querySelector('#seatType_'+(i+1));` +
    `if(!seat||cfg.passengerNames.indexOf(name)<0)return stop('missing_seat');const options=Array.from(seat.options);` +
    `const exact=options.filter((option)=>txt(option).indexOf(cfg.seatPriority)===0);if(exact.length!==1)return stop('missing_seat');` +
    `if(seat.value!==exact[0].value){seat.value=exact[0].value;seat.dispatchEvent(new Event('change',{bubbles:true}));seatChanged=true;}` +
    `marker['seat_'+i]=name;}if(seatChanged)return retry('passenger','seats_selected');` +
    `const modalCheck=verifyModal();if(modalCheck===''){return out({state:'ready_to_confirm'});}` +
    `if(modalCheck!=='wait')return stop(modalCheck);if(!marker.submitted){marker.submitted=true;submit.click();}` +
    `return retry('passenger','order_submitted');})()`;
}

export function buildTrainPresaleFinalConfirmScript(task: TrainPresaleTask): string {
  const config: TrainWebAssistConfig = { trainCode: task.trainCode, travelDate: task.travelDate,
    fromName: task.fromName, fromCode: task.fromCode, toName: task.toName, toCode: task.toCode,
    passengerNames: task.passengerNames,
    seatPriority: task.seatPriority, unpaidOrderAuthorized: task.unpaidOrderAuthorized };
  return `(function(){${commonScript(config)}if(payment())return out({state:'awaiting_payment'});` +
    `if(location.protocol.toLowerCase()!=='https:'||location.hostname.toLowerCase()!=='kyfw.12306.cn')return stop('page_mismatch');` +
    `if(shown('.login-hd-account,#J-login'))return waitUser('login_required');` +
    `if(shown('#J-loginImg,.touclick-wrapper'))return waitUser('captcha_required');` +
    `if(!cfg.unpaidOrderAuthorized)return stop('not_authorized');` +
    `if(!formTrip())return stop('trip_mismatch');` +
    `const checked=verifyModal();if(checked==='wait')return retry('confirm','waiting_modal');if(checked!=='')return stop(checked);` +
    `const confirm=document.querySelector('#qr_submit_id');if(!visible(confirm)||!confirm.classList.contains('btn92s'))return retry('confirm','waiting_confirm');` +
    `if(!marker.finalConfirmed){marker.finalConfirmed=true;confirm.click();}return retry('confirm','confirm_clicked');})()`;
}

export function parseTrainWebAssistOutcome(raw: string): TrainWebAssistOutcome {
  try {
    const parsed = JSON.parse(raw) as Object | string;
    const value = typeof parsed === 'string' ? JSON.parse(parsed) as Object : parsed;
    const state = (value as Record<string, string>).state;
    if (state === 'retry' && exactKeys(value, ['state', 'stage', 'progress'])) {
      const stage = (value as Record<string, string>).stage;
      const progress = (value as Record<string, string>).progress;
      if ((stage === 'query' || stage === 'passenger' || stage === 'confirm') && typeof progress === 'string' &&
        progress.length > 0 && progress.length <= 40) return { state: 'retry', stage: stage, progress: progress };
    }
    if (state === 'ready_to_confirm' && exactKeys(value, ['state'])) return { state: 'ready_to_confirm' };
    if (state === 'awaiting_payment' && exactKeys(value, ['state'])) return { state: 'awaiting_payment' };
    if (state === 'waiting_user' && exactKeys(value, ['state', 'reason'])) {
      const reason = (value as Record<string, string>).reason;
      if (reason === 'login_required' || reason === 'captcha_required') {
        return { state: 'waiting_user', reason: reason };
      }
    }
    if (state === 'needs_user' && exactKeys(value, ['state', 'reason'])) {
      const reason = (value as Record<string, string>).reason;
      return { state: 'needs_user', reason: sanitizedReason(typeof reason === 'string' ? reason : '') };
    }
  } catch (_error) {}
  return { state: 'needs_user', reason: 'invalid_result' };
}

export function trainWebAssistTargetState(outcome: TrainWebAssistOutcome): TrainPresaleTaskState | undefined {
  return outcome.state === 'awaiting_payment' || outcome.state === 'needs_user' ? outcome.state : undefined;
}

export function trainWebAssistReasonText(reason: string): string {
  if (reason === 'login_required') return '请在 12306 官方页面登录后手动继续。';
  if (reason === 'captcha_required') return '请在 12306 官方页面完成验证后手动继续。';
  if (reason === 'no_navigation' || reason === 'timeout') return '12306 官方页面未按预期前进，请手动继续。';
  return '12306 官方页面与预期不一致，已停止协助；页面可手动继续。';
}
