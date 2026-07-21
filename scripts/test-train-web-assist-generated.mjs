import fs from 'node:fs';
import vm from 'node:vm';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const typescript = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
const sourcePath = new URL('../entry/src/main/ets/pages/A2uiHome/train/TrainPresaleWebAutomation.ets', import.meta.url);
const compiled = typescript.transpileModule(fs.readFileSync(sourcePath, 'utf8'), {
  compilerOptions: { module: typescript.ModuleKind.CommonJS, target: typescript.ScriptTarget.ES2020 }
}).outputText;
const commonJs = { exports: {} };
vm.runInNewContext(compiled, {
  module: commonJs,
  exports: commonJs.exports,
  require: (id) => { throw new Error(`Unexpected runtime import: ${id}`); }
}, { filename: sourcePath.pathname, timeout: 1000 });
const { buildTrainPresaleWebAssistScript, buildTrainPresaleFinalConfirmScript } = commonJs.exports;

const authorized = {
  taskId: 'task-7', source: 'presale', state: 'executing', trainCode: 'G10', travelDate: '2026-07-23',
  fromName: '上海虹桥', fromCode: 'AOH', toName: '北京南', toCode: 'VNP',
  saleAt: '2026-07-23T12:30:00+08:00', passengerNames: ['张三', '李四'], seatPriority: '二等座',
  unpaidOrderAuthorized: true, bookingUrl: 'https://kyfw.12306.cn/otn/leftTicket/init', reminderId: 7,
  createdAt: '2026-07-22T12:00:00+08:00', lastError: ''
};

function assert(value, message) {
  if (!value) throw new Error(message);
}

function visibleNode(text = '') {
  return {
    textContent: text,
    getBoundingClientRect: () => ({ width: 20, height: 20 }),
    getAttribute: () => null
  };
}

function clickNode(text = '') {
  const node = visibleNode(text);
  node.clickCount = 0;
  node.click = () => { node.clickCount += 1; };
  return node;
}

function inputNode(value) {
  const node = visibleNode();
  node.value = value;
  return node;
}

function labelNode(id, text) {
  const node = visibleNode(text);
  node.htmlFor = id;
  return node;
}

function run(script, document, location, window = {}) {
  const raw = vm.runInNewContext(script, {
    document,
    location,
    window,
    URLSearchParams,
    Event,
    getComputedStyle: () => ({ display: 'block', visibility: 'visible', opacity: '1' })
  }, { timeout: 1000 });
  return JSON.parse(raw);
}

function queryCase(changes = {}) {
  const trip = { travelDate: authorized.travelDate, fromName: authorized.fromName, fromCode: authorized.fromCode,
    toName: authorized.toName, toCode: authorized.toCode, ...changes };
  const booking = clickNode('预订');
  const link = visibleNode(authorized.trainCode);
  link.id = `24000000G10_${trip.fromCode}_${trip.toCode}`;
  const from = visibleNode(trip.fromName);
  from.getAttribute = (name) => name === 'title' ? trip.fromName : null;
  const to = visibleNode(trip.toName);
  to.getAttribute = (name) => name === 'title' ? trip.toName : null;
  const row = {
    querySelector: (selector) => selector === 'a.number' ? link : (selector === 'a.btn72' ? booking : null),
    querySelectorAll: (selector) => selector === '.cdz strong' ? [from, to] : []
  };
  const table = { querySelectorAll: (selector) => selector === 'tr' ? [row] : [] };
  const fields = {
    '#train_date': inputNode(trip.travelDate), '#fromStationText': inputNode(trip.fromName),
    '#fromStation': inputNode(trip.fromCode), '#toStationText': inputNode(trip.toName),
    '#toStation': inputNode(trip.toCode), '#queryLeftTable': table
  };
  const document = {
    querySelector: (selector) => fields[selector] ?? null,
    querySelectorAll: () => []
  };
  const search = '?date=' + encodeURIComponent(trip.travelDate) +
    '&fs=' + encodeURIComponent(`${trip.fromName},${trip.fromCode}`) +
    '&ts=' + encodeURIComponent(`${trip.toName},${trip.toCode}`);
  return {
    booking,
    outcome: run(buildTrainPresaleWebAssistScript(authorized), document,
      { protocol: 'https:', hostname: 'kyfw.12306.cn', pathname: '/otn/leftTicket/init', search }, {})
  };
}

function formDetail(changes = {}) {
  const trip = { travelDate: authorized.travelDate, fromName: authorized.fromName, fromCode: authorized.fromCode,
    toName: authorized.toName, toCode: authorized.toCode, ...changes };
  return {
    station_train_code: authorized.trainCode,
    start_train_date: trip.travelDate.replace(/-/g, ''),
    from_station_name: trip.fromName,
    from_station_telecode: trip.fromCode,
    to_station_name: trip.toName,
    to_station_telecode: trip.toCode
  };
}

function passengerCase(changes = {}) {
  const submit = clickNode('提交订单');
  const boxes = authorized.passengerNames.map((name, index) => {
    const box = clickNode();
    box.id = `passenger_${index}`;
    box.checked = true;
    box.passengerName = name;
    return box;
  });
  const labels = boxes.map((box) => labelNode(box.id, box.passengerName));
  const root = {
    querySelectorAll: (selector) => selector === 'input[type=checkbox]' ? boxes :
      (selector === 'label' ? labels : [])
  };
  const seats = authorized.passengerNames.map(() => {
    const option = visibleNode('二等座');
    option.value = 'O';
    return { value: 'O', options: [option], dispatchEvent: () => {} };
  });
  const document = {
    querySelector: (selector) => {
      if (selector === '#normal_passenger_id') return root;
      if (selector === '#submitOrder_id') return submit;
      if (selector === '#checkticketinfo_id') return null;
      if (selector.startsWith('#seatType_')) return seats[Number(selector.substring(10)) - 1] ?? null;
      return null;
    },
    querySelectorAll: () => []
  };
  return {
    submit,
    outcome: run(buildTrainPresaleWebAssistScript(authorized), document,
      { protocol: 'https:', hostname: 'kyfw.12306.cn', pathname: '/otn/confirmPassenger/initDc', search: '' },
      { ticketInfoForPassengerForm: { queryLeftNewDetailDTO: formDetail(changes) } })
  };
}

function finalCase(formChanges = {}, modalChanges = {}) {
  const confirm = clickNode('确认');
  const cells = [modalChanges.travelDate ?? authorized.travelDate, authorized.trainCode,
    modalChanges.fromName ?? authorized.fromName, modalChanges.toName ?? authorized.toName].map(visibleNode);
  const rows = authorized.passengerNames.map((name) => {
    const values = [visibleNode(name), visibleNode(authorized.seatPriority)];
    const row = visibleNode();
    row.querySelectorAll = () => values;
    return row;
  });
  const modal = visibleNode();
  modal.querySelectorAll = (selector) => selector === 'td,th,span,strong' ? cells :
    (selector === '.passenger-info tbody tr,#orderTable tbody tr' ? rows : []);
  const document = {
    querySelector: (selector) => selector === '#checkticketinfo_id' ? modal :
      (selector === '#qr_submit_id' ? confirm : null),
    querySelectorAll: () => []
  };
  return {
    confirm,
    outcome: run(buildTrainPresaleFinalConfirmScript(authorized), document,
      { protocol: 'https:', hostname: 'kyfw.12306.cn', pathname: '/otn/confirmPassenger/initDc', search: '' },
      { ticketInfoForPassengerForm: { queryLeftNewDetailDTO: formDetail(formChanges) } })
  };
}

function assertStopped(result, spy, label) {
  assert(result.outcome.state === 'needs_user', `${label}: expected needs_user, got ${result.outcome.state}`);
  assert(spy.clickCount === 0, `${label}: unsafe click count ${spy.clickCount}`);
}

const queryHappy = queryCase();
assert(queryHappy.outcome.progress === 'booking_clicked' && queryHappy.booking.clickCount === 1,
  'query happy path did not click exactly once');
for (const [field, value] of [['travelDate', '2026-07-24'], ['fromName', '上海站'], ['fromCode', 'SHH'],
  ['toName', '北京站'], ['toCode', 'BJP']]) {
  const result = queryCase({ [field]: value });
  assertStopped(result, result.booking, `query ${field}`);
}

const passengerHappy = passengerCase();
assert(passengerHappy.outcome.progress === 'order_submitted' && passengerHappy.submit.clickCount === 1,
  'passenger happy path did not submit exactly once');
for (const [field, value] of [['travelDate', '2026-07-24'], ['fromName', '上海站'], ['fromCode', 'SHH'],
  ['toName', '北京站'], ['toCode', 'BJP']]) {
  const result = passengerCase({ [field]: value });
  assertStopped(result, result.submit, `passenger ${field}`);
}

const finalHappy = finalCase();
assert(finalHappy.outcome.progress === 'confirm_clicked' && finalHappy.confirm.clickCount === 1,
  'final happy path did not confirm exactly once');
for (const [field, value] of [['travelDate', '2026-07-24'], ['fromName', '上海站'], ['toName', '北京站']]) {
  const result = finalCase({}, { [field]: value });
  assertStopped(result, result.confirm, `final modal ${field}`);
}
for (const [field, value] of [['fromCode', 'SHH'], ['toCode', 'BJP']]) {
  const result = finalCase({ [field]: value });
  assertStopped(result, result.confirm, `final form ${field}`);
}

console.log('PASS generated 12306 scripts: query=6 passenger=6 final=6, unsafe_clicks=0');
