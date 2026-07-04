import {
  A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_VERSION,
  A2uiAction,
  A2uiComponent,
  A2uiEnvelope,
  A2uiGenericToolResultData,
  A2uiGenericToolResultRowData,
  A2uiSummaryData
} from '../runtime/A2uiTypes';
import {
  PaymentProvider,
  PaymentTargetType,
  PaymentValidationResult,
  PaymentValidationStatus
} from './PaymentCore';

export interface PaymentActionArgs {
  recipient: string;
  provider: PaymentProvider;
  amountText: string;
  currency: string;
  note: string;
  phase: string;
  accountId: string;
  targetType: PaymentTargetType;
}

function envelopeWithVersion(envelope: A2uiEnvelope): A2uiEnvelope {
  const versioned: A2uiEnvelope = {
    version: A2UI_VERSION
  };
  if (envelope.createSurface !== undefined && envelope.createSurface !== null) {
    versioned.createSurface = envelope.createSurface;
  }
  if (envelope.updateComponents !== undefined && envelope.updateComponents !== null) {
    versioned.updateComponents = envelope.updateComponents;
  }
  if (envelope.updateDataModel !== undefined && envelope.updateDataModel !== null) {
    versioned.updateDataModel = envelope.updateDataModel;
  }
  if (envelope.deleteSurface !== undefined && envelope.deleteSurface !== null) {
    versioned.deleteSurface = envelope.deleteSurface;
  }
  return versioned;
}

function a2uiLine(envelope: A2uiEnvelope): string {
  return JSON.stringify(envelopeWithVersion(envelope)) + '\n';
}

function a2uiJsonl(envelopes: A2uiEnvelope[]): string {
  let jsonl = '';
  envelopes.forEach((envelope: A2uiEnvelope) => {
    jsonl += a2uiLine(envelope);
  });
  return jsonl;
}

function providerFromTarget(result: PaymentValidationResult): PaymentProvider {
  if (result.provider.length > 0) {
    return result.provider;
  }
  if (result.targetType === 'paypal') {
    return 'paypal';
  }
  if (result.targetType === 'stripe_connected' || result.targetType === 'stripe_payment_link') {
    return 'stripe';
  }
  return '';
}

function providerLabel(result: PaymentValidationResult): string {
  const provider = providerFromTarget(result);
  if (provider === 'paypal') {
    return 'PayPal';
  }
  if (result.targetType === 'stripe_payment_link') {
    return 'Stripe Payment Link';
  }
  if (provider === 'stripe') {
    return 'Stripe';
  }
  return '待选择';
}

function targetLabel(targetType: PaymentTargetType): string {
  if (targetType === 'paypal') {
    return 'PayPal account';
  }
  if (targetType === 'stripe_connected') {
    return 'Stripe connected merchant';
  }
  if (targetType === 'stripe_payment_link') {
    return 'Stripe Payment Link';
  }
  if (targetType === 'choice') {
    return 'PayPal or Stripe';
  }
  return '未设置';
}

function titleForStatus(status: PaymentValidationStatus): string {
  if (status === 'needs_amount') {
    return '补充金额';
  }
  if (status === 'needs_provider') {
    return '选择支付方式';
  }
  if (status === 'blocked') {
    return '支付不可用';
  }
  if (status === 'checkout') {
    return '打开支付确认页';
  }
  if (status === 'cancelled') {
    return '支付已取消';
  }
  return '确认支付';
}

function surfaceStatusFor(status: PaymentValidationStatus): string {
  if (status === 'blocked') {
    return 'error';
  }
  if (status === 'cancelled') {
    return 'ready';
  }
  return 'needs_input';
}

function resultStatusFor(status: PaymentValidationStatus): string {
  if (status === 'blocked') {
    return 'blocked';
  }
  if (status === 'cancelled') {
    return 'cancelled';
  }
  return 'needs_user';
}

function amountLabel(result: PaymentValidationResult): string {
  if (result.amountText.trim().length > 0) {
    return result.amountText.trim() + ' ' + result.currency;
  }
  if (result.amountMinor <= 0) {
    return result.targetType === 'stripe_payment_link' ? '由商户付款页决定' : '待补充';
  }
  if (result.currency === 'JPY' || result.currency === 'KRW' || result.currency === 'VND') {
    return result.amountMinor.toString() + ' ' + result.currency;
  }
  const whole = Math.floor(result.amountMinor / 100);
  const cents = result.amountMinor % 100;
  const centsText = cents < 10 ? '0' + cents.toString() : cents.toString();
  return whole.toString() + '.' + centsText + ' ' + result.currency;
}

function targetAccount(result: PaymentValidationResult): string {
  if (result.targetType === 'paypal') {
    return result.paypalEmail.length > 0 ? result.paypalEmail : result.paypalMerchantId;
  }
  if (result.targetType === 'stripe_connected') {
    return result.stripeAccountId;
  }
  if (result.targetType === 'stripe_payment_link') {
    return result.stripePaymentLinkUrl;
  }
  return '';
}

function row(label: string, value: string): A2uiGenericToolResultRowData {
  return {
    label: label,
    value: value
  };
}

function rowsFor(result: PaymentValidationResult): A2uiGenericToolResultRowData[] {
  const rows: A2uiGenericToolResultRowData[] = [
    row('收款方', result.displayName.length > 0 ? result.displayName : result.recipient),
    row('支付方式', providerLabel(result)),
    row('金额', amountLabel(result)),
    row('模式', result.mode === 'live' ? 'Live' : 'Test'),
    row('目标类型', targetLabel(result.targetType))
  ];
  const account = targetAccount(result);
  if (account.length > 0) {
    rows.push(row('账号', account));
  }
  if (result.note.length > 0) {
    rows.push(row('备注', result.note));
  }
  if (result.reason.length > 0) {
    rows.push(row('状态说明', result.reason));
  }
  return rows;
}

function summaryFor(result: PaymentValidationResult): string {
  const recipient = result.displayName.length > 0 ? result.displayName : result.recipient;
  if (result.status === 'needs_amount') {
    return '需要补充金额后才能继续支付给 ' + recipient + '。';
  }
  if (result.status === 'needs_provider') {
    return '请选择使用 PayPal 还是 Stripe 支付给 ' + recipient + '。';
  }
  if (result.status === 'blocked') {
    return result.reason.length > 0 ? result.reason : '当前支付请求被安全策略拦截。';
  }
  if (result.status === 'checkout') {
    return '将在 app 内打开 ' + providerLabel(result) + ' 确认页面。';
  }
  if (result.status === 'cancelled') {
    return '这笔支付已经取消，没有发起扣款。';
  }
  return '请确认是否通过 ' + providerLabel(result) + ' 向 ' + recipient + ' 支付 ' + amountLabel(result) + '。';
}

function actionArgs(result: PaymentValidationResult, phase: string, provider: PaymentProvider, amountText: string): PaymentActionArgs {
  return {
    recipient: result.displayName.length > 0 ? result.displayName : result.recipient,
    provider: provider,
    amountText: amountText,
    currency: result.currency,
    note: result.note,
    phase: phase,
    accountId: result.accountId,
    targetType: result.targetType
  };
}

function paymentAction(
  id: string,
  label: string,
  prompt: string,
  variant: string,
  kind: string,
  args: PaymentActionArgs
): A2uiAction {
  return {
    id: id,
    label: label,
    prompt: prompt,
    variant: variant,
    kind: kind,
    args: args
  };
}

function amountActions(result: PaymentValidationResult): A2uiAction[] {
  const provider = providerFromTarget(result);
  return [
    paymentAction('payment.amount.select', '1 ' + result.currency, '选择支付金额 1 ' + result.currency, 'secondary', 'prompt', actionArgs(result, 'amount', provider, '1')),
    paymentAction('payment.amount.select', '5 ' + result.currency, '选择支付金额 5 ' + result.currency, 'primary', 'prompt', actionArgs(result, 'amount', provider, '5')),
    paymentAction('payment.amount.select', '10 ' + result.currency, '选择支付金额 10 ' + result.currency, 'secondary', 'prompt', actionArgs(result, 'amount', provider, '10')),
    paymentAction('payment.cancel', '取消', '取消支付', 'secondary', 'prompt', actionArgs(result, 'cancel', provider, result.amountText))
  ];
}

function providerActions(result: PaymentValidationResult): A2uiAction[] {
  const actions: A2uiAction[] = [];
  if (result.paypalEmail.length > 0 || result.paypalMerchantId.length > 0) {
    actions.push(paymentAction('payment.provider.select', 'PayPal', '选择 PayPal 支付', 'primary', 'prompt', actionArgs(result, 'provider', 'paypal', result.amountText)));
  }
  if (result.stripeAccountId.length > 0 || result.stripePaymentLinkUrl.length > 0) {
    actions.push(paymentAction('payment.provider.select', 'Stripe', '选择 Stripe 支付', 'secondary', 'prompt', actionArgs(result, 'provider', 'stripe', result.amountText)));
  }
  actions.push(paymentAction('payment.cancel', '取消', '取消支付', 'secondary', 'prompt', actionArgs(result, 'cancel', providerFromTarget(result), result.amountText)));
  return actions;
}

function confirmActions(result: PaymentValidationResult): A2uiAction[] {
  const provider = providerFromTarget(result);
  return [
    paymentAction('payment.confirm', '确认支付', '确认支付', 'primary', 'prompt', actionArgs(result, 'confirm', provider, result.amountText)),
    paymentAction('payment.cancel', '取消', '取消支付', 'secondary', 'prompt', actionArgs(result, 'cancel', provider, result.amountText))
  ];
}

function checkoutActions(result: PaymentValidationResult): A2uiAction[] {
  const provider = providerFromTarget(result);
  return [
    paymentAction('payment.checkout.open', '打开确认页', '打开支付确认页', 'primary', 'client', actionArgs(result, 'checkout', provider, result.amountText)),
    paymentAction('payment.cancel', '取消', '取消支付', 'secondary', 'prompt', actionArgs(result, 'cancel', provider, result.amountText))
  ];
}

function actionsFor(result: PaymentValidationResult): A2uiAction[] {
  if (result.status === 'needs_amount') {
    return amountActions(result);
  }
  if (result.status === 'needs_provider') {
    return providerActions(result);
  }
  if (result.status === 'confirm') {
    return confirmActions(result);
  }
  if (result.status === 'checkout') {
    return checkoutActions(result);
  }
  return [];
}

function paymentComponents(result: PaymentValidationResult): A2uiComponent[] {
  const title = titleForStatus(result.status);
  const status = surfaceStatusFor(result.status);
  const root: A2uiComponent = {
    id: 'root',
    component: A2UI_COMPONENT_SURFACE_ROOT,
    child: 'payment',
    title: 'AIPhone Pay',
    status: status
  };
  const payment: A2uiComponent = {
    id: 'payment',
    component: A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
    title: title,
    body: summaryFor(result),
    status: status,
    dataPath: '/genericToolResults',
    actions: actionsFor(result)
  };
  return [root, payment];
}

function paymentResult(result: PaymentValidationResult): A2uiGenericToolResultData {
  return {
    sourceTag: providerLabel(result),
    toolName: 'payment.send',
    title: titleForStatus(result.status),
    status: resultStatusFor(result.status),
    summary: summaryFor(result),
    rows: rowsFor(result),
    rawPreview: ''
  };
}

export function paymentValidationA2ui(surfaceId: string, result: PaymentValidationResult): string {
  const results: A2uiGenericToolResultData[] = [paymentResult(result)];
  const summary: A2uiSummaryData = {
    text: summaryFor(result),
    toolName: 'payment.send',
    dataLabel: 'genericToolResults',
    count: 1
  };
  const envelopes: A2uiEnvelope[] = [
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: 'AIPhone Pay',
        intent: 'payment',
        status: surfaceStatusFor(result.status),
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
        components: paymentComponents(result)
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/genericToolResults',
        value: results
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/summary',
        value: summary
      }
    }
  ];
  return a2uiJsonl(envelopes);
}

export function paymentCancelledA2ui(surfaceId: string, result: PaymentValidationResult): string {
  const cancelled: PaymentValidationResult = {
    status: 'cancelled',
    targetType: result.targetType,
    reason: 'User cancelled payment.',
    recipient: result.recipient,
    accountId: result.accountId,
    displayName: result.displayName,
    provider: result.provider,
    amountMinor: result.amountMinor,
    amountText: result.amountText,
    currency: result.currency,
    note: result.note,
    mode: result.mode,
    paypalEmail: result.paypalEmail,
    paypalMerchantId: result.paypalMerchantId,
    stripeAccountId: result.stripeAccountId,
    stripePaymentLinkUrl: result.stripePaymentLinkUrl
  };
  return paymentValidationA2ui(surfaceId, cancelled);
}
