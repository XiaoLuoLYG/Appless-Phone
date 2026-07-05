import {
  A2UI_COMPONENT_STRIPE_RECEIVING_ACCOUNT_CARD,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_VERSION,
  A2uiAction,
  A2uiComponent,
  A2uiEnvelope,
  StripeReceivingAccountCardData
} from '../runtime/A2uiTypes';

export const STRIPE_RECEIVING_ACCOUNT_DATA_PATH: string = '/stripeReceivingAccount';

interface StripeReceivingActionArgs {
  agentId: string;
  deviceId: string;
  displayName: string;
  email: string;
  country: string;
  businessType: string;
  stripeAccountId: string;
}

function jsonLine(envelope: A2uiEnvelope): string {
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
  return JSON.stringify(versioned) + '\n';
}

function action(id: string, label: string, prompt: string, variant: string, args: Object | null = null): A2uiAction {
  const next: A2uiAction = {
    id: id,
    label: label,
    prompt: prompt,
    variant: variant,
    kind: 'client'
  };
  if (args !== null) {
    next.args = args;
  }
  return next;
}

function actionArgs(card: StripeReceivingAccountCardData): StripeReceivingActionArgs {
  return {
    agentId: card.agentId,
    deviceId: card.deviceId,
    displayName: card.displayName,
    email: card.email,
    country: card.country,
    businessType: card.businessType,
    stripeAccountId: card.stripeAccountId
  };
}

function actionsFor(card: StripeReceivingAccountCardData): A2uiAction[] {
  if (card.actions.length > 0) {
    return card.actions;
  }
  const args = actionArgs(card);
  if (card.status === 'not_created' || card.status === 'config_missing') {
    return [action('stripe.account.create', '开始绑定', '创建 Stripe 收款账户并打开认证', 'primary', args)];
  }
  if (card.status === 'onboarding_required') {
    return [action('stripe.account.onboard', '继续认证', '打开 Stripe 认证', 'primary', args)];
  }
  return [action('stripe.account.refresh', '刷新状态', '刷新 Stripe 收款状态', 'secondary', args)];
}

function surfaceStatus(status: string): string {
  if (status === 'blocked' || status === 'config_missing') {
    return 'error';
  }
  if (status === 'receivable') {
    return 'ready';
  }
  return 'needs_input';
}

function rootComponent(title: string, status: string): A2uiComponent {
  return {
    id: 'root',
    component: A2UI_COMPONENT_SURFACE_ROOT,
    child: 'stripe_receiving_account',
    title: title,
    status: status
  };
}

function stripeReceivingComponent(title: string, status: string, actions: A2uiAction[]): A2uiComponent {
  return {
    id: 'stripe_receiving_account',
    component: A2UI_COMPONENT_STRIPE_RECEIVING_ACCOUNT_CARD,
    title: title,
    status: status,
    dataPath: STRIPE_RECEIVING_ACCOUNT_DATA_PATH,
    actions: actions
  };
}

function withDefaultActions(card: StripeReceivingAccountCardData): StripeReceivingAccountCardData {
  return {
    status: card.status,
    title: card.title,
    message: card.message,
    agentId: card.agentId,
    deviceId: card.deviceId,
    displayName: card.displayName,
    email: card.email,
    country: card.country,
    businessType: card.businessType,
    stripeAccountId: card.stripeAccountId,
    onboardingUrl: card.onboardingUrl,
    currentlyDue: card.currentlyDue.slice(),
    actions: actionsFor(card)
  };
}

export function stripeReceivingAccountA2ui(surfaceId: string, card: StripeReceivingAccountCardData): string {
  const intent = withDefaultActions(card);
  const status = surfaceStatus(intent.status);
  return jsonLine({
    createSurface: {
      surfaceId: surfaceId,
      root: 'root',
      title: intent.title,
      intent: 'payment.account.setup',
      status: status,
      sendDataModel: true
    }
  }) + jsonLine({
    updateComponents: {
      surfaceId: surfaceId,
      components: [
        rootComponent(intent.title, status),
        stripeReceivingComponent(intent.title, intent.status, intent.actions)
      ]
    }
  }) + jsonLine({
    updateDataModel: {
      surfaceId: surfaceId,
      path: STRIPE_RECEIVING_ACCOUNT_DATA_PATH,
      value: intent
    }
  });
}
