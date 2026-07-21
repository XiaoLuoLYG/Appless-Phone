import { TrainPresaleTask, TrainPresaleTaskState } from './TrainPresaleTaskStore';

export interface TrainWebAssistContinuingOutcome {
  state: 'continuing';
}

export interface TrainWebAssistAwaitingPaymentOutcome {
  state: 'awaiting_payment';
}

export interface TrainWebAssistNeedsUserOutcome {
  state: 'needs_user';
  reason: string;
}

export type TrainWebAssistOutcome = TrainWebAssistContinuingOutcome |
  TrainWebAssistAwaitingPaymentOutcome | TrainWebAssistNeedsUserOutcome;

interface TrainWebAssistConfig {
  trainCode: string;
  passengerNames: string[];
  seatPriority: string;
  unpaidOrderAuthorized: boolean;
}

interface TrainWebAssistProtocol {
  state?: string;
  reason?: string;
}

const SANITIZED_REASONS: string[] = [
  'login_required',
  'captcha_required',
  'page_mismatch',
  'train_mismatch',
  'missing_passenger',
  'passenger_mismatch',
  'missing_seat',
  'confirmation_mismatch',
  'not_authorized',
  'timeout',
  'script_error',
  'invalid_result'
];

function scriptJson(value: TrainWebAssistConfig): string {
  return JSON.stringify(value)
    .replace(/</g, '\\u003c')
    .replace(/>/g, '\\u003e')
    .replace(/&/g, '\\u0026')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
}

function sanitizedReason(value: string): string {
  return SANITIZED_REASONS.indexOf(value) >= 0 ? value : 'invalid_result';
}

export function buildTrainPresaleWebAssistScript(task: TrainPresaleTask): string {
  const config: TrainWebAssistConfig = {
    trainCode: task.trainCode,
    passengerNames: task.passengerNames,
    seatPriority: task.seatPriority,
    unpaidOrderAuthorized: true
  };
  return `(function(){'use strict';const cfg=${scriptJson(config)};` +
    `const QUERY_POLL_LIMIT=20;const PASSENGER_POLL_LIMIT=40;const POLL_MS=250;` +
    `return new Promise(function(resolve){let done=false;let timer=-1;let queryPolls=0;` +
    `let passengerPolls=0;let submitted=false;` +
    `function finish(state,reason){if(done){return;}done=true;if(timer>=0){clearInterval(timer);}` +
    `resolve(JSON.stringify(reason?{state:state,reason:reason}:{state:state}));}` +
    `function text(node){return node&&node.textContent?node.textContent.trim():'';}` +
    `function paymentPage(){const protocol=location.protocol.toLowerCase();` +
    `const hostname=location.hostname.toLowerCase();const pathname=location.pathname;` +
    `return protocol==='https:'&&(hostname==='epay.12306.cn'||` +
    `(hostname==='kyfw.12306.cn'&&pathname.indexOf('/payOrder/')>=0));}` +
    `function associatedLabel(box,labels){for(let i=0;i<labels.length;i+=1){` +
    `if(labels[i].htmlFor===box.id){return labels[i];}}return null;}` +
    `function queryStep(table){queryPolls+=1;if(!table){` +
    `if(queryPolls>=QUERY_POLL_LIMIT){finish('needs_user','page_mismatch');}return;}` +
    `const rows=table.querySelectorAll('tr');let sawTrain=false;` +
    `for(let i=0;i<rows.length;i+=1){const link=rows[i].querySelector('a.number');` +
    `if(!link){continue;}sawTrain=true;if(text(link)===cfg.trainCode){` +
    `const booking=rows[i].querySelector('a.btn72');if(!booking){` +
    `if(queryPolls>=QUERY_POLL_LIMIT){finish('needs_user','page_mismatch');}return;}` +
    `booking.click();finish('continuing');return;}}` +
    `if(queryPolls>=QUERY_POLL_LIMIT){finish('needs_user',sawTrain?'train_mismatch':'timeout');}}` +
    `function passengerStep(){passengerPolls+=1;const passengerRoot=document.querySelector('#normal_passenger_id');` +
    `const submit=document.querySelector('#submitOrder_id');` +
    `if(!passengerRoot||!submit){if(passengerPolls>=PASSENGER_POLL_LIMIT){` +
    `finish('needs_user','page_mismatch');}return;}` +
    `if(new Set(cfg.passengerNames).size!==cfg.passengerNames.length){` +
    `finish('needs_user','passenger_mismatch');return;}` +
    `if(submitted){const modal=document.querySelector('#checkticketinfo_id');` +
    `const confirm=document.querySelector('#qr_submit_id');` +
    `if(!modal||!confirm){if(passengerPolls>=PASSENGER_POLL_LIMIT){finish('needs_user','timeout');}return;}` +
    `const modalText=text(modal);if(modalText.indexOf(cfg.trainCode)<0){` +
    `finish('needs_user','confirmation_mismatch');return;}` +
    `for(let nameIndex=0;nameIndex<cfg.passengerNames.length;nameIndex+=1){const name=cfg.passengerNames[nameIndex];` +
    `if(modalText.indexOf(name)<0){finish('needs_user','confirmation_mismatch');return;}}` +
    `if(!cfg.unpaidOrderAuthorized){finish('needs_user','not_authorized');return;}` +
    `confirm.click();finish('continuing');return;}` +
    `const boxes=passengerRoot.querySelectorAll('input[type=checkbox]');` +
    `const labels=passengerRoot.querySelectorAll('label');let missingPassenger=false;let clickedPassenger=false;` +
    `for(let nameIndex=0;nameIndex<cfg.passengerNames.length;nameIndex+=1){` +
    `const name=cfg.passengerNames[nameIndex];let exactBox=null;` +
    `for(let boxIndex=0;boxIndex<boxes.length;boxIndex+=1){const label=associatedLabel(boxes[boxIndex],labels);` +
    `if(label&&text(label)===name){exactBox=boxes[boxIndex];break;}}` +
    `if(!exactBox){missingPassenger=true;break;}if(!exactBox.checked){exactBox.click();clickedPassenger=true;}}` +
    `if(missingPassenger){if(passengerPolls>=PASSENGER_POLL_LIMIT){` +
    `finish('needs_user','missing_passenger');}return;}` +
    `for(let boxIndex=0;boxIndex<boxes.length;boxIndex+=1){const label=associatedLabel(boxes[boxIndex],labels);` +
    `if(boxes[boxIndex].checked&&(!label||cfg.passengerNames.indexOf(text(label))<0)){` +
    `finish('needs_user','passenger_mismatch');return;}}if(clickedPassenger){return;}` +
    `const firstSeat=document.querySelector('#seatType_1');` +
    `const seatNodes=document.querySelectorAll('select[id^=seatType_]');` +
    `if(!firstSeat||seatNodes.length<cfg.passengerNames.length){` +
    `if(passengerPolls>=PASSENGER_POLL_LIMIT){finish('needs_user','missing_seat');}return;}` +
    `for(let seatIndex=0;seatIndex<cfg.passengerNames.length;seatIndex+=1){const options=seatNodes[seatIndex].options;` +
    `let exactOption=null;for(let optionIndex=0;optionIndex<options.length;optionIndex+=1){` +
    `if(text(options[optionIndex]).indexOf(cfg.seatPriority)===0){exactOption=options[optionIndex];break;}}` +
    `if(!exactOption){if(passengerPolls>=PASSENGER_POLL_LIMIT){finish('needs_user','missing_seat');}return;}` +
    `seatNodes[seatIndex].value=exactOption.value;seatNodes[seatIndex].dispatchEvent(new Event('change',{bubbles:true}));}` +
    `submitted=true;submit.click();}` +
    `function step(){if(paymentPage()){finish('awaiting_payment');return;}` +
    `if(location.protocol.toLowerCase()!=='https:'||location.hostname.toLowerCase()!=='kyfw.12306.cn'){` +
    `finish('needs_user','page_mismatch');return;}` +
    `const pathname=location.pathname.toLowerCase();const bodyText=document.body?text(document.body):'';` +
    `if(pathname.indexOf('login')>=0){finish('needs_user','login_required');return;}` +
    `if(bodyText.indexOf('验证码')>=0){finish('needs_user','captcha_required');return;}` +
    `const table=document.querySelector('#queryLeftTable');` +
    `if(table||location.pathname==='/otn/leftTicket/init'){queryStep(table);return;}` +
    `passengerStep();}` +
    `step();if(!done){timer=setInterval(step,POLL_MS);}});})()`;
}

export function trainPresaleWebAssistScriptForCheckout(
  kind: string,
  boundTaskId: string,
  task: TrainPresaleTask | undefined
): string {
  if (kind !== 'train' || boundTaskId.length === 0 || task === undefined ||
    task.taskId !== boundTaskId || task.state !== 'executing') {
    return '';
  }
  return buildTrainPresaleWebAssistScript(task);
}

export function parseTrainWebAssistOutcome(raw: string): TrainWebAssistOutcome {
  try {
    const value = JSON.parse(raw) as TrainWebAssistProtocol;
    if (value.state === 'continuing') {
      const outcome: TrainWebAssistContinuingOutcome = { state: 'continuing' };
      return outcome;
    }
    if (value.state === 'awaiting_payment') {
      const outcome: TrainWebAssistAwaitingPaymentOutcome = { state: 'awaiting_payment' };
      return outcome;
    }
    if (value.state === 'needs_user') {
      const outcome: TrainWebAssistNeedsUserOutcome = {
        state: 'needs_user',
        reason: sanitizedReason(value.reason === undefined ? '' : value.reason)
      };
      return outcome;
    }
  } catch (_error) {
  }
  const invalid: TrainWebAssistNeedsUserOutcome = { state: 'needs_user', reason: 'invalid_result' };
  return invalid;
}

export function trainWebAssistTargetState(outcome: TrainWebAssistOutcome): TrainPresaleTaskState | undefined {
  return outcome.state === 'continuing' ? undefined : outcome.state;
}

export function trainWebAssistReasonText(reason: string): string {
  if (reason === 'login_required') {
    return '请在 12306 官方页面登录后手动继续。';
  }
  if (reason === 'captcha_required') {
    return '请在 12306 官方页面完成验证后手动继续。';
  }
  if (reason === 'train_mismatch') {
    return '官方页面未找到预定车次，请手动核对。';
  }
  if (reason === 'missing_passenger') {
    return '官方页面未找到预定乘车人，请手动处理。';
  }
  if (reason === 'passenger_mismatch') {
    return '官方页面已选乘车人与授权名单不一致，已停止协助。';
  }
  if (reason === 'missing_seat') {
    return '官方页面未找到预定席别，请手动处理。';
  }
  if (reason === 'confirmation_mismatch') {
    return '订单确认页的车次或乘车人不匹配，已停止协助。';
  }
  if (reason === 'timeout') {
    return '12306 官方页面等待超时，请手动继续。';
  }
  return '12306 官方页面与预期不一致，已停止协助；页面可手动继续。';
}
