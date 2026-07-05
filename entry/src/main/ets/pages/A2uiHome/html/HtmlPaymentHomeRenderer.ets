import { HtmlHomeBlock, HtmlHomeDocument } from './HtmlHomeTypes';

interface HtmlPaymentHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
}

type HtmlPaymentValue = Object | string | number | boolean | null | undefined;

function escapeHtmlText(value: string): string {
  return value.replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function escapeScriptJson(value: string): string {
  return value.replace(/</g, '\\u003c')
    .replace(/>/g, '\\u003e')
    .replace(/&/g, '\\u0026')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
}

function text(value: HtmlPaymentValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function metric(block: HtmlHomeBlock, labels: string[]): string {
  const rows = block.rows.concat(block.metrics);
  for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    const row = rows[rowIndex];
    const label = row.label.toLowerCase();
    for (let labelIndex = 0; labelIndex < labels.length; labelIndex++) {
      if (label === labels[labelIndex].toLowerCase()) {
        return row.value;
      }
    }
  }
  return '';
}

function paymentTargetCount(document: HtmlHomeDocument): number {
  let count = 0;
  for (let index = 0; index < document.blocks.length; index++) {
    if (document.blocks[index].kind === 'generic-tool-result' && metric(document.blocks[index], ['toolName']) === 'payment.send') {
      count += 1;
    }
  }
  return count;
}

const PAYMENT_HOME_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f5f2ee;
  --panel: #fffaf4;
  --panel-strong: #ffffff;
  --ink: #211b17;
  --ink-soft: #493f38;
  --muted: #786e66;
  --line: rgba(33, 27, 23, 0.12);
  --accent: #995f4c;
  --accent-soft: rgba(153, 95, 76, 0.12);
  --good: #397a55;
  --bad: #b04a42;
  --shadow: 0 16px 42px rgba(44, 34, 26, 0.09);
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100dvh;
  background: var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
}
button, input { font: inherit; }
button { cursor: pointer; }
button:disabled, input:disabled { opacity: .55; cursor: default; }
.payment-shell {
  width: min(100%, 760px);
  margin: 0 auto;
  padding: 16px 14px calc(100px + env(safe-area-inset-bottom, 0px));
}
.pay-hero {
  position: relative;
  overflow: hidden;
  border: 1px solid var(--line);
  border-radius: 28px;
  padding: 22px;
  background:
    linear-gradient(135deg, rgba(153, 95, 76, .13), rgba(255,255,255,.34) 46%, rgba(57,122,85,.08)),
    var(--panel);
  box-shadow: var(--shadow);
}
.pay-kicker {
  color: var(--muted);
  font-size: 12px;
  line-height: 1.35;
  font-weight: 760;
}
h1, h2, p { margin: 0; }
h1 {
  margin-top: 8px;
  font-size: 32px;
  line-height: 1.05;
  font-weight: 840;
  letter-spacing: 0;
}
.pay-summary {
  margin-top: 10px;
  max-width: 34em;
  color: var(--ink-soft);
  font-size: 14px;
  line-height: 1.55;
}
.pay-route {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 44px minmax(0, 1fr);
  align-items: center;
  gap: 10px;
  margin-top: 18px;
}
.pay-party {
  min-width: 0;
  border: 1px solid var(--line);
  border-radius: 18px;
  padding: 12px;
  background: rgba(255,255,255,.72);
}
.pay-party span, .pay-stat span {
  display: block;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.3;
}
.pay-party b {
  display: block;
  margin-top: 4px;
  overflow-wrap: anywhere;
  font-size: 15px;
  line-height: 1.25;
}
.pay-arrow {
  display: grid;
  place-items: center;
  height: 44px;
  border-radius: 999px;
  background: var(--accent);
  color: #fff;
  font-size: 20px;
  font-weight: 780;
}
.pay-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
  margin-top: 12px;
}
.pay-stat {
  min-width: 0;
  border: 1px solid var(--line);
  border-radius: 16px;
  padding: 10px;
  background: rgba(255,255,255,.62);
}
.pay-stat b {
  display: block;
  margin-top: 4px;
  overflow-wrap: anywhere;
  font-size: 13px;
  line-height: 1.25;
}
.payment-card, .payee-card {
  margin-top: 14px;
  border: 1px solid var(--line);
  border-radius: 24px;
  background: var(--panel-strong);
  box-shadow: var(--shadow);
}
.payment-card { overflow: hidden; }
.payment-top {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 16px;
}
.provider-mark {
  display: grid;
  place-items: center;
  flex: 0 0 auto;
  width: 48px;
  height: 48px;
  overflow: hidden;
  border: 1px solid rgba(255,255,255,.62);
  border-radius: 14px;
  background: var(--accent-soft);
  box-shadow: inset 0 1px 0 rgba(255,255,255,.42), 0 10px 24px rgba(33,27,23,.08);
}
.provider-mark.paypal {
  background: linear-gradient(135deg, #003087, #009cde);
}
.provider-mark.stripe {
  background: #635bff;
}
.provider-mark.generic {
  background: var(--accent);
}
.provider-logo {
  color: #fff;
  font-size: 9px;
  line-height: 1;
  font-weight: 860;
  letter-spacing: 0;
}
.provider-mark img {
  display: block;
  width: 100%;
  height: 100%;
}
.provider-mark img + .provider-logo {
  display: none;
}
.provider-mark[data-broken="true"] img {
  display: none;
}
.provider-mark[data-broken="true"] .provider-logo {
  display: block;
}
.payment-title { min-width: 0; flex: 1 1 auto; }
.payment-title h2 {
  overflow-wrap: anywhere;
  font-size: 20px;
  line-height: 1.18;
  font-weight: 840;
}
.payment-title p {
  margin-top: 5px;
  color: var(--muted);
  font-size: 13px;
  line-height: 1.45;
}
.status-pill {
  flex: 0 0 auto;
  border: 1px solid var(--line);
  border-radius: 999px;
  padding: 7px 10px;
  color: var(--ink-soft);
  background: var(--paper);
  font-size: 12px;
  font-weight: 720;
}
.status-pill.success { color: var(--good); background: rgba(57,122,85,.1); }
.status-pill.blocked { color: var(--bad); background: rgba(176,74,66,.1); }
.detail-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0 14px;
  padding: 0 16px 14px;
}
.detail-row {
  min-width: 0;
  border-top: 1px solid var(--line);
  padding: 10px 0;
}
.detail-row b {
  display: block;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.3;
}
.detail-row span {
  display: block;
  margin-top: 4px;
  overflow-wrap: anywhere;
  color: var(--ink);
  font-size: 13px;
  line-height: 1.35;
  font-weight: 650;
}
.actions {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  align-items: flex-start;
  padding: 0 16px 16px;
}
.action {
  border: 1px solid var(--line);
  border-radius: 999px;
  min-height: 42px;
  padding: 0 16px;
  background: var(--accent);
  color: #fff;
  font-size: 14px;
  font-weight: 760;
}
.action.secondary {
  background: var(--paper);
  color: var(--ink-soft);
}
.action:active { transform: translateY(1px); }
.google-pay-action {
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: 188px;
  max-width: min(100%, 240px);
}
.google-pay-button-slot {
  min-height: 42px;
  display: flex;
  align-items: center;
}
.google-pay-button-slot > * {
  width: 100%;
}
.google-pay-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 42px;
  width: 100%;
  border: 0;
  border-radius: 999px;
  background: #111;
  color: #fff;
  font-size: 14px;
  font-weight: 760;
  font: inherit;
}
.google-pay-placeholder:disabled {
  opacity: .62;
  cursor: default;
}
.google-pay-status {
  margin: 0;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.45;
}
.google-pay-status.error { color: var(--bad); }
.google-pay-status.ready { color: var(--good); }
.payee-card {
  padding: 16px;
}
.form-actions {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  margin-top: 14px;
}
.form-actions .action {
  min-width: 124px;
}
.payee-head {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: baseline;
}
.payee-head h2 {
  font-size: 18px;
  line-height: 1.2;
}
.payee-head span {
  color: var(--muted);
  font-size: 12px;
}
.payee-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin-top: 14px;
}
.field { min-width: 0; }
.field label {
  display: block;
  margin-bottom: 6px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.3;
  font-weight: 680;
}
.field input {
  width: 100%;
  height: 42px;
  border: 1px solid var(--line);
  border-radius: 14px;
  padding: 0 12px;
  background: #fff;
  color: var(--ink);
  outline: none;
}
.field input:focus {
  border-color: rgba(153,95,76,.62);
  box-shadow: 0 0 0 3px var(--accent-soft);
}
.form-error {
  display: none;
  margin-top: 10px;
  color: var(--bad);
  font-size: 12px;
  line-height: 1.45;
}
@media (max-width: 560px) {
  .payment-shell { padding: 12px 10px calc(96px + env(safe-area-inset-bottom, 0px)); }
  .pay-hero, .payment-card, .payee-card { border-radius: 22px; }
  h1 { font-size: 28px; }
  .pay-route { grid-template-columns: minmax(0, 1fr); }
  .pay-arrow { width: 44px; justify-self: center; transform: rotate(90deg); }
  .pay-stats, .detail-grid, .payee-grid { grid-template-columns: 1fr; }
}
`;

const PAYMENT_HOME_JS: string = `
(function () {
  var data = JSON.parse(document.getElementById('payment-data').textContent || '{}');
  var isBusy = data.isBusy === true;
  var PROVIDER_ICONS = {
    paypal: '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><rect width="48" height="48" rx="12" fill="#ffffff"/><rect x="3" y="3" width="42" height="42" rx="10" fill="#003087"/><text x="24" y="27" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="9.5" font-weight="800" fill="#ffffff">PayPal</text><rect x="12" y="31" width="24" height="3" rx="1.5" fill="#009cde"/></svg>',
    stripe: '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><rect width="48" height="48" rx="12" fill="#635bff"/><text x="24" y="29" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="12" font-weight="700" fill="#ffffff">stripe</text></svg>'
  };
  function text(value) {
    if (value === undefined || value === null) { return ''; }
    return String(value);
  }
  function list(value) {
    return Array.isArray(value) ? value : [];
  }
  function add(parent, tag, className, value) {
    var node = document.createElement(tag);
    if (className) { node.className = className; }
    if (value !== undefined && value !== null) { node.textContent = text(value); }
    parent.appendChild(node);
    return node;
  }
  function metric(block, labels) {
    var rows = list(block.rows).concat(list(block.metrics));
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
      var label = text(rows[rowIndex].label).toLowerCase();
      for (var labelIndex = 0; labelIndex < labels.length; labelIndex += 1) {
        if (label === text(labels[labelIndex]).toLowerCase()) {
          return text(rows[rowIndex].value);
        }
      }
    }
    return '';
  }
  function providerKey(block) {
    var raw = (metric(block, ['支付方式']) + ' ' + text(block.source) + ' ' + text(block.title)).toLowerCase();
    if (raw.indexOf('paypal') >= 0 || raw.indexOf('贝宝') >= 0) { return 'paypal'; }
    if (raw.indexOf('stripe') >= 0) { return 'stripe'; }
    return 'generic';
  }
  function addProviderMark(parent, block) {
    var key = providerKey(block);
    var label = key === 'paypal' ? 'PayPal' : (key === 'stripe' ? 'stripe' : 'Pay');
    var mark = add(parent, 'div', 'provider-mark ' + key);
    mark.setAttribute('aria-label', key === 'generic' ? '支付方式' : label);
    if (PROVIDER_ICONS[key]) {
      var img = add(mark, 'img');
      img.src = 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(PROVIDER_ICONS[key]);
      img.alt = '';
      img.setAttribute('aria-hidden', 'true');
      img.onerror = function () { mark.setAttribute('data-broken', 'true'); };
    }
    add(mark, 'span', 'provider-logo', label);
  }
  function postAction(action) {
    if (isBusy) { return; }
    try {
      if (window.AIPhoneHome && typeof window.AIPhoneHome.postAction === 'function') {
        window.AIPhoneHome.postAction(JSON.stringify({
          id: text(action.id),
          label: text(action.label || action.id),
          prompt: text(action.prompt),
          variant: text(action.variant),
          kind: text(action.kind),
          args: action.args && typeof action.args === 'object' ? action.args : null
        }));
      }
    } catch (error) {}
  }
  function firstPaymentBlock() {
    var blocks = list(data.blocks);
    for (var index = 0; index < blocks.length; index += 1) {
      if (blocks[index].kind === 'StripeReceivingAccountCard') {
        return blocks[index];
      }
    }
    for (var index = 0; index < blocks.length; index += 1) {
      if (blocks[index].kind === 'generic-tool-result' && metric(blocks[index], ['toolName']) === 'payment.send') {
        return blocks[index];
      }
    }
    return null;
  }
  function statusLabel(status) {
    if (status === 'success') { return '完成'; }
    if (status === 'blocked') { return '不可用'; }
    if (status === 'cancelled') { return '已取消'; }
    return '待确认';
  }
  function addDetailRows(parent, block) {
    list(block.rows).forEach(function (row) {
      var label = text(row.label);
      if (label === 'toolName' || label === 'source') { return; }
      var item = add(parent, 'div', 'detail-row');
      add(item, 'b', '', label);
      add(item, 'span', '', row.value);
    });
  }
  function addActions(parent, actions, block) {
    var kept = list(actions).filter(function (action) { return text(action.label || action.id).length > 0; });
    var googlePayConfig = block ? googlePayCheckoutConfig(block) : null;
    if (kept.length === 0 && googlePayConfig === null) { return; }
    var row = add(parent, 'div', 'actions');
    kept.forEach(function (action) {
      var button = add(row, 'button', text(action.variant) === 'primary' ? 'action' : 'action secondary', action.label || action.id);
      button.type = 'button';
      button.disabled = isBusy;
      button.addEventListener('click', function (event) {
        event.stopPropagation();
        postAction(actionForBlock(action, block));
      });
    });
    addGooglePayAction(row, googlePayConfig);
  }
  function actionForBlock(action, block) {
    if (block && block.kind === 'StripeReceivingAccountCard' && text(action.id) === 'stripe.account.open') {
      var receiving = block.stripeReceiving || null;
      var url = receiving ? text(receiving.onboardingUrl) : '';
      if (url.indexOf('https://connect.stripe.com/') === 0) {
        return {
          id: 'stripe.account.open',
          label: text(action.label || '打开 Stripe 托管认证'),
          prompt: url,
          variant: text(action.variant || 'primary'),
          kind: 'client',
          args: { onboardingUrl: url }
        };
      }
    }
    return action;
  }
  function actionById(block, id) {
    var actions = list(block.actions);
    for (var index = 0; index < actions.length; index += 1) {
      if (text(actions[index].id) === id) {
        return actions[index];
      }
    }
    return null;
  }
  function actionArg(action, key) {
    if (!action || !action.args || typeof action.args !== 'object') { return ''; }
    return text(action.args[key]);
  }
  function googlePayCheckoutConfig(block) {
    var provider = metric(block, ['支付方式']).toLowerCase();
    var funding = metric(block, ['付款方式偏好']).toLowerCase();
    var checkout = actionById(block, 'payment.checkout.open');
    if (provider.indexOf('paypal') < 0 || funding.indexOf('google pay') < 0 || checkout === null) {
      return null;
    }
    return {
      clientId: actionArg(checkout, 'paypalClientId'),
      environment: actionArg(checkout, 'paypalEnvironment') === 'live' ? 'live' : 'sandbox',
      orderId: actionArg(checkout, 'providerSessionId'),
      amountText: actionArg(checkout, 'amountText') || metric(block, ['金额']).split(' ')[0],
      currency: (actionArg(checkout, 'currency') || 'USD').toUpperCase(),
      paypalMerchantId: actionArg(checkout, 'paypalMerchantId'),
      recipient: actionArg(checkout, 'recipient'),
      captureAction: {
        id: 'payment.capture',
        label: '确认 Google Pay 支付',
        prompt: 'PayPal Google Pay approved, capture order ' + actionArg(checkout, 'providerSessionId'),
        variant: 'primary',
        kind: 'prompt',
        args: Object.assign({}, checkout.args || {}, { phase: 'capture' })
      }
    };
  }
  function loadScript(src) {
    return new Promise(function (resolve, reject) {
      var existing = document.querySelector('script[data-src-key="' + src + '"]');
      if (existing && existing.getAttribute('data-loaded') === 'true') {
        resolve();
        return;
      }
      if (existing) {
        existing.parentNode.removeChild(existing);
      }
      var script = document.createElement('script');
      var settled = false;
      var timeout = window.setTimeout(function () {
        if (settled) { return; }
        settled = true;
        reject(new Error('脚本加载超时：' + src));
      }, 60000);
      script.src = src;
      script.async = true;
      script.setAttribute('data-src-key', src);
      script.onload = function () {
        if (settled) { return; }
        settled = true;
        window.clearTimeout(timeout);
        script.setAttribute('data-loaded', 'true');
        resolve();
      };
      script.onerror = function () {
        if (settled) { return; }
        settled = true;
        window.clearTimeout(timeout);
        reject(new Error('脚本加载失败：' + src));
      };
      document.head.appendChild(script);
    });
  }
  function withTimeout(promise, label) {
    return new Promise(function (resolve, reject) {
      var settled = false;
      var timeout = window.setTimeout(function () {
        if (settled) { return; }
        settled = true;
        reject(new Error(label + ' 超时。'));
      }, 60000);
      promise.then(function (value) {
        if (settled) { return; }
        settled = true;
        window.clearTimeout(timeout);
        resolve(value);
      }).catch(function (error) {
        if (settled) { return; }
        settled = true;
        window.clearTimeout(timeout);
        reject(error);
      });
    });
  }
  function googlePayErrorText(error) {
    if (!error) { return 'Google Pay 当前不可用。'; }
    var message = error.message ? String(error.message) : '';
    if (message.indexOf('pay.google.com/gp/p/js/pay.js') >= 0) {
      return '手机 WebView 当前访问不了 Google Pay SDK。请确认手机本地 VPN/网络能打开 pay.google.com，或先使用“打开确认页”。';
    }
    if (message.indexOf('www.paypal.com/sdk/js') >= 0) {
      return '手机 WebView 当前访问不了 PayPal SDK。请确认手机本地网络能打开 paypal.com。';
    }
    if (message.length > 0) { return message; }
    try { return JSON.stringify(error); } catch (_error) { return String(error); }
  }
  function paypalGooglePaySdkUrl(config) {
    var params = [
      'client-id=' + encodeURIComponent(config.clientId),
      'currency=' + encodeURIComponent(config.currency),
      'components=googlepay'
    ];
    if (config.environment !== 'live') {
      params.push('buyer-country=US');
    }
    if (config.paypalMerchantId.length > 0) {
      params.push('merchant-id=' + encodeURIComponent(config.paypalMerchantId));
    }
    return 'https://www.paypal.com/sdk/js?' + params.join('&');
  }
  function setGooglePayStatus(node, message, className) {
    node.textContent = message;
    node.className = 'google-pay-status' + (className ? ' ' + className : '');
    node.style.display = message.length > 0 ? 'block' : 'none';
  }
  function openGooglePaySheet(paymentsClient, paymentDataRequest, status) {
    setGooglePayStatus(status, '正在打开 Google Pay；如果面板空白，请返回并使用打开确认页。', '');
    withTimeout(paymentsClient.loadPaymentData(paymentDataRequest), 'Google Pay 确认面板').catch(function (error) {
      setGooglePayStatus(status, 'Google Pay 没有完成授权：' + googlePayErrorText(error), 'error');
    });
  }
  function mountGooglePayButton(slot, status, config, openAfterReady) {
      var fallback = slot.querySelector('.google-pay-placeholder');
      if (config.clientId.length === 0 || config.orderId.length === 0) {
        setGooglePayStatus(status, '缺少 PayPal client id 或 order id，不能启动 Google Pay。', 'error');
        return;
      }
      if (fallback) { fallback.disabled = true; }
      setGooglePayStatus(status, '正在准备 Google Pay 按钮（PayPal 负责订单确认）...', '');
      Promise.all([
        loadScript(paypalGooglePaySdkUrl(config)),
        loadScript('https://pay.google.com/gp/p/js/pay.js')
      ]).then(function () {
        if (!window.paypal || typeof window.paypal.Googlepay !== 'function') {
          throw new Error('PayPal Google Pay 组件未加载。');
        }
        if (!window.google || !window.google.payments || !window.google.payments.api) {
          throw new Error('Google Pay Web SDK 未加载。');
        }
        var paypalGooglePay = window.paypal.Googlepay();
        return withTimeout(paypalGooglePay.config(), 'PayPal Google Pay config').then(function (paypalConfig) {
          var baseRequest = {
            apiVersion: paypalConfig.apiVersion || 2,
            apiVersionMinor: paypalConfig.apiVersionMinor || 0,
            allowedPaymentMethods: paypalConfig.allowedPaymentMethods
          };
          var paymentsClient = new window.google.payments.api.PaymentsClient({
            environment: config.environment === 'live' ? 'PRODUCTION' : 'TEST',
            paymentDataCallbacks: {
              onPaymentAuthorized: function (paymentData) {
                setGooglePayStatus(status, 'Google Pay 已授权，正在交给 PayPal 确认订单...', '');
                return window.paypal.Googlepay().confirmOrder({
                  orderId: config.orderId,
                  paymentMethodData: paymentData.paymentMethodData
                }).then(function (confirmResult) {
                  var providerStatus = text(confirmResult && confirmResult.status).toUpperCase();
                  if (providerStatus === 'APPROVED' || providerStatus === 'COMPLETED' || providerStatus.length === 0) {
                    setGooglePayStatus(status, 'PayPal 已确认授权，正在 capture 订单。', 'ready');
                    postAction(config.captureAction);
                    return { transactionState: 'SUCCESS' };
                  }
                  if (providerStatus === 'PAYER_ACTION_REQUIRED' && typeof window.paypal.Googlepay().initiatePayerAction === 'function') {
                    setGooglePayStatus(status, 'PayPal 需要额外验证，正在打开确认页面...', '');
                    return window.paypal.Googlepay().initiatePayerAction({ orderId: config.orderId }).then(function () {
                      setGooglePayStatus(status, 'PayPal 额外验证已完成，正在 capture 订单。', 'ready');
                      postAction(config.captureAction);
                      return { transactionState: 'SUCCESS' };
                    });
                  }
                  setGooglePayStatus(status, 'PayPal 未批准此 Google Pay 订单：' + providerStatus, 'error');
                  return { transactionState: 'ERROR' };
                }).catch(function (error) {
                  setGooglePayStatus(status, 'PayPal confirmOrder 失败：' + googlePayErrorText(error), 'error');
                  return { transactionState: 'ERROR' };
                });
              }
            }
          });
          return withTimeout(paymentsClient.isReadyToPay(baseRequest), 'Google Pay isReadyToPay').then(function (ready) {
            if (!ready || ready.result !== true) {
              throw new Error('此设备或 WebView 当前未通过 Google Pay isReadyToPay。');
            }
            var paymentDataRequest = Object.assign({}, baseRequest, {
              transactionInfo: {
                currencyCode: config.currency,
                totalPriceStatus: 'FINAL',
                totalPrice: config.amountText
              },
              merchantInfo: paypalConfig.merchantInfo,
              callbackIntents: ['PAYMENT_AUTHORIZATION']
            });
            var button = paymentsClient.createButton({
              onClick: function () {
                openGooglePaySheet(paymentsClient, paymentDataRequest, status);
              },
              buttonType: 'pay',
              buttonColor: 'black'
            });
            slot.textContent = '';
            slot.appendChild(button);
            if (openAfterReady === true) {
              openGooglePaySheet(paymentsClient, paymentDataRequest, status);
              return;
            }
            setGooglePayStatus(status, 'Google Pay 已准备好，请点上方按钮打开确认面板。', 'ready');
          });
        });
      }).catch(function (error) {
        if (fallback) { fallback.disabled = false; }
        setGooglePayStatus(status, googlePayErrorText(error), 'error');
      });
  }
  function addGooglePayAction(parent, config) {
    if (config === null) { return; }
    var wrap = add(parent, 'div', 'google-pay-action');
    var slot = add(wrap, 'div', 'google-pay-button-slot');
    var fallback = add(slot, 'button', 'google-pay-placeholder', 'Pay with G Pay');
    fallback.type = 'button';
    fallback.disabled = isBusy;
    var status = add(wrap, 'p', 'google-pay-status', isBusy ? '正在处理上一笔支付。' : '');
    if (!isBusy) { status.style.display = 'none'; }
    if (isBusy) { return; }
    fallback.addEventListener('click', function (event) {
      event.stopPropagation();
      mountGooglePayButton(slot, status, config, true);
    });
  }
  function valueOf(id) {
    var node = document.getElementById(id);
    return node && node.value ? String(node.value).trim() : '';
  }
  function savePayee() {
    var error = document.getElementById('payment-form-error');
    var payload = {
      displayName: valueOf('payee-name'),
      aliases: valueOf('payee-aliases'),
      paypalEmail: valueOf('payee-paypal'),
      paypalMerchantId: valueOf('payee-paypal-merchant'),
      stripeAccountId: valueOf('payee-stripe-account'),
      stripePaymentLinkUrl: valueOf('payee-stripe-link')
    };
    if (payload.displayName.length === 0) {
      error.textContent = '先填写名称。';
      error.style.display = 'block';
      return;
    }
    if ([payload.paypalEmail, payload.paypalMerchantId, payload.stripeAccountId, payload.stripePaymentLinkUrl].join('').length === 0) {
      error.textContent = '至少填写一个 PayPal 或 Stripe 账号。';
      error.style.display = 'block';
      return;
    }
    error.style.display = 'none';
    postAction({
      id: 'payment.account.save',
      label: '保存付款对象',
      prompt: JSON.stringify(payload),
      variant: 'primary',
      kind: 'client',
      args: payload
    });
  }
  var app = document.getElementById('app');
  var block = firstPaymentBlock();
  app.textContent = '';
  var shell = add(app, 'main', 'payment-shell');
  var hero = add(shell, 'header', 'pay-hero');
  add(hero, 'div', 'pay-kicker', 'AIPhone Pay');
  add(hero, 'h1', '', text(data.title) || '支付');
  add(hero, 'p', 'pay-summary', block ? text(block.subtitle) : (text(data.subtitle) || '管理付款对象与确认支付。'));
  var route = add(hero, 'section', 'pay-route');
  var payer = add(route, 'div', 'pay-party');
  add(payer, 'span', '', '付款方');
  add(payer, 'b', '', '当前用户');
  add(route, 'div', 'pay-arrow', '→');
  var payee = add(route, 'div', 'pay-party');
  add(payee, 'span', '', '收款方');
  add(payee, 'b', '', block ? (metric(block, ['收款方']) || '待选择') : '待添加');
  var stats = add(hero, 'section', 'pay-stats');
  [['渠道', block ? (metric(block, ['支付方式']) || '待选择') : '待选择'], ['金额', block ? (metric(block, ['金额']) || '待补充') : '待补充'], ['模式', block ? (metric(block, ['模式']) || 'Test') : 'Test']].forEach(function (item) {
    var stat = add(stats, 'div', 'pay-stat');
    add(stat, 'span', '', item[0]);
    add(stat, 'b', '', item[1]);
  });
  if (block) {
    var card = add(shell, 'article', 'payment-card');
    var top = add(card, 'div', 'payment-top');
    addProviderMark(top, block);
    var title = add(top, 'div', 'payment-title');
    add(title, 'h2', '', block.title);
    add(title, 'p', '', block.subtitle);
    var pill = add(top, 'div', 'status-pill ' + text(block.status), statusLabel(block.status));
    pill.setAttribute('data-status', text(block.status));
    var grid = add(card, 'div', 'detail-grid');
    addDetailRows(grid, block);
    addActions(card, block.actions, block);
  }
  var form = add(shell, 'section', 'payee-card');
  var head = add(form, 'div', 'payee-head');
  add(head, 'h2', '', '添加付款对象');
  add(head, 'span', '', '保存在本机');
  var grid = add(form, 'div', 'payee-grid');
  [
    ['payee-name', '名称', 'Alex / 商户名称'],
    ['payee-aliases', '别名', '小明, 常用商户'],
    ['payee-paypal', 'PayPal 邮箱', 'seller@example.com'],
    ['payee-paypal-merchant', 'PayPal Merchant ID', '可选'],
    ['payee-stripe-link', 'Stripe Payment Link', 'https://buy.stripe.com/...'],
    ['payee-stripe-account', 'Stripe Connected Account', 'acct_...']
  ].forEach(function (field) {
    var wrap = add(grid, 'div', 'field');
    var label = add(wrap, 'label', '', field[1]);
    label.setAttribute('for', field[0]);
    var input = add(wrap, 'input');
    input.id = field[0];
    input.placeholder = field[2];
    input.disabled = isBusy;
  });
  var error = add(form, 'p', 'form-error', '');
  error.id = 'payment-form-error';
  var row = add(form, 'div', 'form-actions');
  var save = add(row, 'button', 'action', '保存对象');
  save.type = 'button';
  save.disabled = isBusy;
  save.addEventListener('click', savePayee);
})();
`;

export function shouldRenderPaymentHomeDocument(document: HtmlHomeDocument): boolean {
  return document.kind === 'payment' && paymentTargetCount(document) > 0;
}

export function renderPaymentHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  const renderDocument: HtmlPaymentHomeDocumentWithBusy = {
    version: document.version,
    source: document.source,
    kind: document.kind,
    title: document.title,
    subtitle: document.subtitle,
    chips: document.chips,
    metrics: document.metrics,
    timeline: document.timeline,
    blocks: document.blocks,
    actions: document.actions,
    history: [],
    persona: document.persona,
    personaMemory: document.personaMemory,
    rawSurfaceRoot: null,
    generatedAt: '',
    isBusy: isBusy || (document as HtmlPaymentHomeDocumentWithBusy).isBusy === true
  };
  const json = escapeScriptJson(JSON.stringify(renderDocument));
  const title = escapeHtmlText(document.title.length > 0 ? document.title : 'AIPhone Pay');
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<style>${PAYMENT_HOME_CSS}</style>
</head>
<body>
<div id="app"></div>
<script id="payment-data" type="application/json">${json}</script>
<script>${PAYMENT_HOME_JS}</script>
</body>
</html>`;
}
