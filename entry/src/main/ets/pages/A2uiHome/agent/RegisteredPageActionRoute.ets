import {
  A2uiAction,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  ToolDefinition,
  actionAgentToolDefinitions,
  toolDefinitionForToolId
} from '@loop/agent-core';

const FIXED_PAGE_ACTION_IDS: string[] = [
  'luckin.order.preview',
  'social.reply.draft',
  'mail.draft.create',
  'gmail.draft.create',
  'gmail.draft.apply',
  'gmail.open.web',
  'worldcup.open',
  'payment.send',
  'payment.account.setup',
  'maps.route.open'
];

function registeredProductAction(actionId: string): boolean {
  if (FIXED_PAGE_ACTION_IDS.indexOf(actionId) < 0) {
    return false;
  }
  return actionAgentToolDefinitions().some(
    (definition: ToolDefinition): boolean => definition.toolId === actionId
  );
}

function adaptedTarget(sourceToolId: string, clickedActionId: string): string {
  if (sourceToolId === 'payment.send' && clickedActionId === 'payment.confirm') {
    return 'payment.send';
  }
  if (sourceToolId === 'payment.account.setup' &&
    (clickedActionId === 'stripe.account.create' ||
      clickedActionId === 'stripe.account.onboard' ||
      clickedActionId === 'stripe.account.refresh')) {
    return 'payment.account.setup';
  }
  return '';
}

export function registeredPageSourceToolId(surface: A2uiSurfaceState): string {
  try {
    const model = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
    const sourceToolId = model.summary.toolName.trim();
    return toolDefinitionForToolId(sourceToolId) === null ? '' : sourceToolId;
  } catch (_error) {
    return '';
  }
}

export function resolveRegisteredPageAction(
  sourceToolId: string,
  clicked: A2uiAction
): A2uiAction | null {
  if (clicked.args === undefined || clicked.args === null ||
    typeof clicked.args !== 'object' || Array.isArray(clicked.args)) {
    return null;
  }
  const source = toolDefinitionForToolId(sourceToolId);
  if (source === null) {
    return null;
  }
  let targetId = '';
  if (source.actions.indexOf(clicked.id) >= 0 && registeredProductAction(clicked.id)) {
    targetId = clicked.id;
  } else if (sourceToolId === 'luckin.order.preview' && clicked.id === 'luckin.order.preview') {
    // The existing Luckin selection/option flow re-enters the same preview tool
    // with exact provider-backed selection args from the current document.
    targetId = clicked.id;
  } else {
    targetId = adaptedTarget(sourceToolId, clicked.id);
  }
  if (!registeredProductAction(targetId)) {
    return null;
  }
  return {
    id: targetId,
    label: clicked.label,
    prompt: clicked.prompt,
    variant: clicked.variant,
    kind: clicked.kind,
    args: clicked.args
  };
}

export function isFixedRegisteredPageAction(actionId: string): boolean {
  return registeredProductAction(actionId);
}

export function isInitialRegisteredPageAction(actionId: string): boolean {
  const definition = toolDefinitionForToolId(actionId);
  return registeredProductAction(actionId) && definition !== null &&
    definition.riskLevel !== 'confirm_required';
}
