import {
  A2uiCallResult,
  A2uiLabelValueData,
  A2uiRuntimeDataModel,
  ActionExecutionResult,
  ToolDefinition,
  actionAgentToolDefinitions
} from '@loop/agent-core';
import { RegisteredPageActionContext } from './AiphoneRegisteredActionExecutor';

export interface RegisteredPageToolInvocation {
  ok: boolean;
  result: A2uiCallResult | null;
  error: string;
}

export interface RegisteredPageToolInvoker {
  invoke(
    toolId: string,
    prompt: string,
    pageActionId: string,
    args: Object
  ): Promise<RegisteredPageToolInvocation>;
}

interface WorldCupPageActionOutput {
  actionId: string;
  route: string;
  status: string;
}

interface RegisteredToolPageActionOutput {
  actionId: string;
  pageActionId: string;
  conversationId: string;
  turnId: string;
  surfaceId: string;
  status: string;
  data: A2uiRuntimeDataModel;
}

type HandlerArgValue = Object | string | number | boolean | null | undefined;
type HandlerArgRecord = Record<string, HandlerArgValue>;

function pageRoute(actionId: string): boolean {
  if (actionId === 'hotel.navigate' || actionId === 'hotel.booking.open') {
    return false;
  }
  return actionAgentToolDefinitions().some(
    (definition: ToolDefinition): boolean => definition.toolId === actionId
  );
}

function externalWrite(actionId: string): boolean {
  return actionId === 'luckin.order.create' ||
    actionId === 'calendar.event.create' ||
    actionId === 'calendar.event.update' ||
    actionId === 'calendar.event.delete' ||
    actionId === 'whatsapp.message.send' ||
    actionId === 'ride.order.create' ||
    actionId === 'ride.order.cancel';
}

function evidenceRow(
  rows: A2uiLabelValueData[],
  labels: string[]
): string {
  for (let index = 0; index < rows.length; index++) {
    const label = rows[index].label.trim().toLowerCase();
    if (labels.indexOf(label) >= 0 && rows[index].value.trim().length > 0) {
      return rows[index].value.trim();
    }
  }
  return '';
}

function positiveCompletionStatus(value: string): boolean {
  const status = value.trim().toLowerCase();
  return status === 'success' || status === 'succeeded' || status === 'completed' ||
    status === 'ok' || status === 'created' || status === 'accepted' ||
    status === 'sent' || status === 'updated' || status === 'deleted' ||
    status === 'cancel' || status === 'canceled' || status === 'cancelled';
}

function hasActionCompletionEvidence(
  actionId: string,
  rows: A2uiLabelValueData[],
  rawPreview: string
): boolean {
  if (actionId === 'luckin.order.create' || actionId === 'ride.order.create') {
    return evidenceRow(rows, ['order id', '订单号']).length > 0;
  }
  if (actionId === 'calendar.event.create' || actionId === 'calendar.event.update') {
    return evidenceRow(rows, ['event id']).length > 0;
  }
  if (actionId === 'calendar.event.delete') {
    return evidenceRow(rows, ['event id']).length > 0 && rawProviderSucceeded(rawPreview);
  }
  if (actionId === 'whatsapp.message.send') {
    return evidenceRow(rows, ['message id']).length > 0;
  }
  if (actionId === 'ride.order.cancel') {
    return positiveCompletionStatus(evidenceRow(rows, ['status', '状态']));
  }
  return false;
}

function matchingProviderSource(actionId: string, sourceTag: string): boolean {
  if (actionId === 'luckin.order.create') {
    return sourceTag === '瑞幸';
  }
  if (actionId.indexOf('calendar.event.') === 0) {
    return sourceTag === 'Composio Google Calendar';
  }
  if (actionId === 'whatsapp.message.send') {
    return sourceTag === 'Composio WhatsApp Business';
  }
  if (actionId === 'ride.order.create' || actionId === 'ride.order.cancel') {
    return sourceTag === '滴滴';
  }
  return false;
}

function providerValueFailed(value: HandlerArgValue, depth: number): boolean {
  if (depth > 8 || value === null || value === undefined || typeof value !== 'object') {
    return false;
  }
  if (Array.isArray(value)) {
    const values = value as HandlerArgValue[];
    for (let index = 0; index < values.length; index++) {
      if (providerValueFailed(values[index], depth + 1)) {
        return true;
      }
    }
    return false;
  }
  const record = value as HandlerArgRecord;
  if (record['success'] === false || record['success'] === 'false' ||
    record['successful'] === false || record['successful'] === 'false') {
    return true;
  }
  const status = typeof record['status'] === 'string' ? record['status'].trim().toLowerCase() : '';
  if (status.indexOf('fail') >= 0 || status.indexOf('error') >= 0 ||
    status.indexOf('reject') >= 0 || status.indexOf('denied') >= 0 ||
    status.indexOf('invalid') >= 0) {
    return true;
  }
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    if (providerValueFailed(record[keys[index]], depth + 1)) {
      return true;
    }
  }
  return false;
}

function rawProviderFailed(rawPreview: string): boolean {
  const raw = rawPreview.trim();
  if (raw.length === 0 || raw.charAt(0) !== '{') {
    return false;
  }
  try {
    return providerValueFailed(JSON.parse(raw) as Object, 0);
  } catch (_error) {
    return true;
  }
}

function providerValueSucceeded(value: HandlerArgValue, depth: number): boolean {
  if (depth > 8 || value === null || value === undefined || typeof value !== 'object') {
    return false;
  }
  if (Array.isArray(value)) {
    const values = value as HandlerArgValue[];
    for (let index = 0; index < values.length; index++) {
      if (providerValueSucceeded(values[index], depth + 1)) {
        return true;
      }
    }
    return false;
  }
  const record = value as HandlerArgRecord;
  if (record['success'] === true || record['success'] === 'true' ||
    record['successful'] === true || record['successful'] === 'true') {
    return true;
  }
  const status = typeof record['status'] === 'string' ? record['status'].trim().toLowerCase() : '';
  if (status === 'success' || status === 'succeeded' || status === 'completed' ||
    status === 'ok' || status === 'deleted') {
    return true;
  }
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    if (providerValueSucceeded(record[keys[index]], depth + 1)) {
      return true;
    }
  }
  return false;
}

function rawProviderSucceeded(rawPreview: string): boolean {
  const raw = rawPreview.trim();
  if (raw.length === 0 || raw.charAt(0) !== '{') {
    return false;
  }
  try {
    const parsed = JSON.parse(raw) as Object;
    return !providerValueFailed(parsed, 0) && providerValueSucceeded(parsed, 0);
  } catch (_error) {
    return false;
  }
}

function hasPositiveWriteEvidence(model: A2uiRuntimeDataModel, actionId: string): boolean {
  for (let index = 0; index < model.genericToolResults.length; index++) {
    const result = model.genericToolResults[index];
    if (result.toolName !== actionId || result.status !== 'success' ||
      !matchingProviderSource(actionId, result.sourceTag) ||
      rawProviderFailed(result.rawPreview)) {
      continue;
    }
    if (hasActionCompletionEvidence(actionId, result.rows, result.rawPreview)) {
      return true;
    }
  }
  return false;
}

function hasVirtualWhatsAppConfirmation(
  model: A2uiRuntimeDataModel,
  args: Object
): boolean {
  const requested = args as HandlerArgRecord;
  const toNumber = typeof requested['toNumber'] === 'string' ?
    requested['toNumber'].trim() : '';
  const text = typeof requested['text'] === 'string' ? requested['text'].trim() : '';
  for (let index = 0; index < model.genericToolResults.length; index++) {
    const result = model.genericToolResults[index];
    const actions = result.actions === undefined ? [] : result.actions;
    if (result.sourceTag !== 'Composio WhatsApp Business' ||
      result.toolName !== 'whatsapp.message.send' ||
      result.status !== 'confirm_required' || actions.length !== 1 ||
      actions[0].id !== 'whatsapp.message.send.confirm' ||
      actions[0].args === undefined || actions[0].args === null ||
      Array.isArray(actions[0].args)) {
      continue;
    }
    const confirmation = actions[0].args as HandlerArgRecord;
    if (toNumber.length > 0 && text.length > 0 &&
      confirmation['toNumber'] === toNumber && confirmation['text'] === text) {
      return true;
    }
  }
  return false;
}

function providerError(model: A2uiRuntimeDataModel): string {
  for (let index = 0; index < model.genericToolResults.length; index++) {
    const result = model.genericToolResults[index];
    if (result.status === 'error' || result.status === 'blocked') {
      return result.summary.length > 0 ? result.summary : result.title;
    }
  }
  if (model.socialHub.draft.status === 'error') {
    return model.socialHub.draft.error;
  }
  if (model.socialHub.publication.status === 'error') {
    return model.socialHub.publication.error;
  }
  if (model.stripeReceivingAccount !== undefined &&
    (model.stripeReceivingAccount.status === 'error' ||
      model.stripeReceivingAccount.status === 'blocked')) {
    return model.stripeReceivingAccount.message;
  }
  return '';
}

function promptFor(actionId: string, pageActionId: string, args: Object): string {
  const values = args as HandlerArgRecord;
  const originalQuery = values['originalQuery'];
  if (typeof originalQuery === 'string' && originalQuery.trim().length > 0) {
    return originalQuery.trim();
  }
  return pageActionId.length > 0 ? pageActionId : actionId;
}

export class RegisteredPageActionHandler {
  private readonly invoker: RegisteredPageToolInvoker;

  constructor(invoker: RegisteredPageToolInvoker) {
    this.invoker = invoker;
  }

  async execute(
    actionId: string,
    args: Object,
    context: RegisteredPageActionContext
  ): Promise<ActionExecutionResult> {
    if (context.pageActionId.trim().length === 0) {
      return {
        status: 'error',
        errorCode: 'ACTION_PAGE_OPERATION_MISSING',
        message: 'Registered page operation identity is missing.'
      };
    }
    if (actionId !== 'worldcup.open' && !pageRoute(actionId)) {
      return {
        status: 'error',
        errorCode: 'ACTION_PAGE_ROUTE_UNSUPPORTED',
        message: 'Registered page action route is unsupported.'
      };
    }
    if (actionId === 'worldcup.open') {
      const values = args as HandlerArgRecord;
      if (context.pageActionId !== 'worldcup.open' ||
        values['route'] !== 'pages/A2uiHome/AnythingDemo') {
        return {
          status: 'error',
          errorCode: 'ACTION_PAGE_ARGS_INVALID',
          message: 'World Cup page action arguments are invalid.'
        };
      }
    }
    const invocation = await this.invoker.invoke(
      actionId,
      promptFor(actionId, context.pageActionId, args),
      context.pageActionId,
      args
    );
    if (!invocation.ok) {
      const message = invocation.error.trim();
      return {
        status: 'error',
        errorCode: 'ACTION_PAGE_TOOL_FAILED',
        message: message.length > 0 ? message : 'Registered page tool failed.'
      };
    }
    if (actionId === 'worldcup.open') {
      const output: WorldCupPageActionOutput = {
        actionId,
        route: 'pages/A2uiHome/AnythingDemo',
        status: 'opened'
      };
      return { status: 'success', output };
    }
    if (invocation.result === null) {
      return {
        status: 'error',
        errorCode: 'ACTION_PAGE_TOOL_FAILED',
        message: 'Registered page tool returned no result.'
      };
    }
    const result = invocation.result;
    if (result.surface.status === 'error' || result.surface.error.length > 0) {
      return {
        status: 'error',
        errorCode: 'ACTION_PAGE_PROVIDER_ERROR',
        message: result.surface.error.length > 0 ? result.surface.error : result.surface.title
      };
    }
    let model: A2uiRuntimeDataModel;
    try {
      model = JSON.parse(result.surface.dataModelJson) as A2uiRuntimeDataModel;
    } catch (_error) {
      return {
        status: 'error',
        errorCode: 'ACTION_PAGE_TOOL_RESULT_INVALID',
        message: 'Registered page tool returned an invalid data model.'
      };
    }
    const error = providerError(model);
    if (error.length > 0) {
      return {
        status: 'error',
        errorCode: 'ACTION_PAGE_PROVIDER_ERROR',
        message: error
      };
    }
    const virtualWhatsAppConfirmation = actionId === 'whatsapp.message.send' &&
      context.virtualAction === true &&
      context.pageActionId === 'whatsapp.message.send' &&
      hasVirtualWhatsAppConfirmation(model, args);
    if (externalWrite(actionId) && !virtualWhatsAppConfirmation &&
      !hasPositiveWriteEvidence(model, actionId)) {
      return {
        status: 'error',
        errorCode: 'ACTION_PAGE_COMPLETION_UNVERIFIED',
        message: 'Provider did not return positive write completion evidence.'
      };
    }
    const output: RegisteredToolPageActionOutput = {
      actionId,
      pageActionId: context.pageActionId,
      conversationId: context.conversationId,
      turnId: context.turnId,
      surfaceId: result.surface.surfaceId,
      status: result.surface.status,
      data: model
    };
    return { status: 'success', output };
  }
}
