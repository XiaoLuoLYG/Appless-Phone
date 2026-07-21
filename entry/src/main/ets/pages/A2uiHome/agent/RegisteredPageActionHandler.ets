import {
  A2uiCallResult,
  A2uiRuntimeDataModel,
  ActionExecutionResult
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
  return actionId === 'luckin.order.preview' ||
    actionId === 'social.reply.draft' ||
    actionId === 'mail.draft.create' ||
    actionId === 'gmail.draft.create' ||
    actionId === 'gmail.draft.apply' ||
    actionId === 'gmail.open.web' ||
    actionId === 'payment.send' ||
    actionId === 'payment.account.setup' ||
    actionId === 'maps.route.open';
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
