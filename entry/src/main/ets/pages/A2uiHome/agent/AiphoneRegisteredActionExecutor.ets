import {
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionFollowUp,
  ActionValidationResult,
  HotelBookingOpenArgs,
  HotelNavigateArgs,
  RegisteredActionExecutor,
  ToolDefinition,
  actionAgentToolDefinitions,
  hotelNavigationUri
} from '@loop/agent-core';

export interface SystemUriOpener {
  open(uri: string): Promise<boolean>;
}

export interface HotelActionIdFactory {
  nextId(prefix: string): string;
}

export interface RegisteredPageActionContext extends ActionExecutionContext {
  pageActionId: string;
}

export type RegisteredPageAction = (
  actionId: string,
  args: Object,
  context: RegisteredPageActionContext
) => Promise<ActionExecutionResult>;

interface HotelFollowUpCreated {
  actionId: string;
  status: string;
}

interface HotelSystemIntentOpened {
  actionId: string;
  status: string;
  uri: string;
  message: string;
}

const REPLAY_IDENTITY_LIMIT: number = 128;

type MailReplyArgValue = Object | string | number | boolean | null | undefined;
type MailReplyArgRecord = Record<string, MailReplyArgValue>;

function nonempty(value: string): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

export function validateGmailReplyActionArgs(args: Object): ActionValidationResult {
  if (args === null || typeof args !== 'object' || Array.isArray(args)) {
    return {
      ok: false,
      code: 'GMAIL_REPLY_ARGS_INVALID',
      message: 'Gmail reply command is invalid.'
    };
  }
  const values = args as MailReplyArgRecord;
  const provider = typeof values['provider'] === 'string' ? values['provider'].trim().toLowerCase() : '';
  const threadId = typeof values['threadId'] === 'string' ? values['threadId'].trim() : '';
  const messageId = typeof values['messageId'] === 'string' ? values['messageId'].trim() : '';
  const requestKey = typeof values['requestKey'] === 'string' ? values['requestKey'].trim() : '';
  const subject = typeof values['subject'] === 'string' ? values['subject'].trim() : '';
  const body = typeof values['body'] === 'string' ? values['body'].trim() : '';
  const replyMode = typeof values['replyMode'] === 'string' ? values['replyMode'].trim() : '';
  const to = values['to'];
  const recipientsValid = Array.isArray(to) && to.length > 0 && to.every(
    (recipient: Object | string | number | boolean | null | undefined): boolean =>
      typeof recipient === 'string' && recipient.trim().length > 0
  );
  const valid = provider === 'gmail' && threadId.length > 0 && messageId.length > 0 &&
    requestKey === 'gmail:' + threadId && subject.length > 0 && body.length > 0 &&
    replyMode === 'reply' && recipientsValid;
  return {
    ok: valid,
    code: valid ? '' : 'GMAIL_REPLY_ARGS_INVALID',
    message: valid ? '' : 'Gmail reply requires the exact current thread, message, recipient, and body.'
  };
}

function validPageResult(result: ActionExecutionResult): boolean {
  if (result === null || typeof result !== 'object' || Array.isArray(result)) {
    return false;
  }
  if (result.status === 'success') {
    return result.output !== undefined;
  }
  return (result.status === 'error' || result.status === 'canceled') &&
    typeof result.errorCode === 'string' &&
    typeof result.message === 'string';
}

export class AiphoneRegisteredActionExecutor implements RegisteredActionExecutor {
  private readonly catalog: ActionCatalog;
  private readonly opener: SystemUriOpener;
  private readonly ids: HotelActionIdFactory;
  private readonly pageAction: RegisteredPageAction;
  private readonly runs: Set<string> = new Set<string>();
  private activeScopeKey: string = '';

  constructor(
    catalog: ActionCatalog,
    opener: SystemUriOpener,
    ids: HotelActionIdFactory,
    pageAction: RegisteredPageAction
  ) {
    this.catalog = catalog;
    this.opener = opener;
    this.ids = ids;
    this.pageAction = pageAction;
  }

  async execute(
    actionId: string,
    args: Object,
    context: ActionExecutionContext
  ): Promise<ActionExecutionResult> {
    if (!nonempty(actionId) || !nonempty(context.conversationId) ||
      !nonempty(context.turnId) || !nonempty(context.surfaceId) ||
      !nonempty(context.sourceToolId) || !nonempty(context.planId) ||
      !nonempty(context.runId) || !nonempty(context.stepId)) {
      return {
        status: 'error',
        errorCode: 'ACTION_EXECUTION_CONTEXT_INVALID',
        message: 'Action execution context is invalid.'
      };
    }
    const registered = actionId === 'hotel.detail' || actionAgentToolDefinitions().some(
      (definition: ToolDefinition): boolean => definition.toolId === actionId
    );
    if (!registered) {
      return {
        status: 'error',
        errorCode: 'ACTION_NOT_REGISTERED',
        message: 'Action is not registered for product execution.'
      };
    }
    const current = context.isSurfaceEntry === false ?
      this.catalog.validateRegisteredStep(actionId, args) :
      context.virtualAction === true ?
        this.catalog.validateActionIntentExecution(actionId, args) :
        context.pageActionId !== undefined && context.pageActionId.length > 0 ?
          this.catalog.validatePageExecution(
            context.conversationId,
            context.turnId,
            context.surfaceId,
            actionId,
            args
          ) :
          this.catalog.validateSurfaceExecution(
            context.conversationId,
            context.turnId,
            context.surfaceId,
            context.sourceToolId,
            actionId,
            args
          );
    if (!current.ok) {
      return {
        status: 'error',
        errorCode: current.code,
        message: current.message
      };
    }
    const scopeKey = this.scopeKey(context);
    if (context.isSurfaceEntry === false) {
      if (this.activeScopeKey.length === 0 || this.activeScopeKey !== scopeKey) {
        return {
          status: 'error',
          errorCode: 'ACTION_EXECUTION_SCOPE_STALE',
          message: 'Action execution scope is not current.'
        };
      }
    } else if (this.activeScopeKey !== scopeKey) {
      this.runs.clear();
      this.activeScopeKey = scopeKey;
    }
    const runKey = this.runKey(context);
    if (this.runs.has(runKey)) {
      return {
        status: 'error',
        errorCode: 'ACTION_RUN_DUPLICATE',
        message: 'Action run identity already exists.'
      };
    }
    if (this.runs.size >= REPLAY_IDENTITY_LIMIT) {
      return {
        status: 'error',
        errorCode: 'ACTION_REPLAY_CAPACITY',
        message: 'Action replay capacity is exhausted for the current surface.'
      };
    }
    this.runs.add(runKey);
    if (actionId === 'hotel.detail') {
      return this.detail(args);
    }
    if (actionId === 'hotel.navigate') {
      return this.open(
        actionId,
        hotelNavigationUri(args as HotelNavigateArgs),
        'Petal Maps opened.'
      );
    }
    if (actionId === 'hotel.booking.open') {
      return this.open(
        actionId,
        (args as HotelBookingOpenArgs).bookingUrl,
        'RollingGo booking opened in App.'
      );
    }
    return this.executePageAction(actionId, args, {
      conversationId: context.conversationId,
      turnId: context.turnId,
      surfaceId: context.surfaceId,
      sourceToolId: context.sourceToolId,
      planId: context.planId,
      runId: context.runId,
      stepId: context.stepId,
      isSurfaceEntry: context.isSurfaceEntry,
      pageActionId: context.pageActionId === undefined || context.pageActionId.length === 0 ?
        actionId : context.pageActionId,
      virtualAction: context.virtualAction
    });
  }

  dispose(): void {
    this.runs.clear();
    this.activeScopeKey = '';
  }

  private async executePageAction(
    actionId: string,
    args: Object,
    context: RegisteredPageActionContext
  ): Promise<ActionExecutionResult> {
    let result: ActionExecutionResult;
    try {
      result = await this.pageAction(actionId, args, context);
    } catch (_error) {
      return {
        status: 'error',
        errorCode: 'ACTION_PAGE_HANDLER_FAILED',
        message: 'Registered page action failed.'
      };
    }
    if (!validPageResult(result)) {
      return {
        status: 'error',
        errorCode: 'ACTION_PAGE_RESULT_INVALID',
        message: 'Registered page action returned an invalid result.'
      };
    }
    return result;
  }

  private runKey(context: ActionExecutionContext): string {
    return context.conversationId.length.toString() + ':' + context.conversationId +
      context.turnId.length.toString() + ':' + context.turnId +
      context.surfaceId.length.toString() + ':' + context.surfaceId +
      context.sourceToolId.length.toString() + ':' + context.sourceToolId +
      context.planId.length.toString() + ':' + context.planId +
      context.runId.length.toString() + ':' + context.runId +
      context.stepId.length.toString() + ':' + context.stepId;
  }

  private scopeKey(context: ActionExecutionContext): string {
    return context.conversationId.length.toString() + ':' + context.conversationId +
      context.turnId.length.toString() + ':' + context.turnId +
      context.surfaceId.length.toString() + ':' + context.surfaceId +
      context.sourceToolId.length.toString() + ':' + context.sourceToolId;
  }

  private detail(args: Object): ActionExecutionResult {
    const dataTaskId = this.ids.nextId('hotel-detail-data');
    const uiTaskId = this.ids.nextId('hotel-detail-ui');
    if (dataTaskId.trim().length === 0 ||
      uiTaskId.trim().length === 0 ||
      dataTaskId === uiTaskId) {
      return {
        status: 'error',
        errorCode: 'HOTEL_FOLLOW_UP_ID_INVALID',
        message: 'Hotel detail follow-up IDs are invalid.'
      };
    }
    const followUp: ActionFollowUp = {
      dataTask: {
        taskId: dataTaskId,
        roundId: dataTaskId,
        skillId: '',
        goal: 'hotel.detail',
        allowedToolIds: ['hotel.detail'],
        toolId: 'hotel.detail',
        outputSchema: 'hotelRatePlans',
        args: args,
        required: true
      },
      uiTask: {
        taskId: uiTaskId,
        dataTaskIds: [dataTaskId],
        skillId: '',
        intent: 'hotel.detail',
        expectedOutputSchema: 'hotelRatePlans'
      }
    };
    const output: HotelFollowUpCreated = {
      actionId: 'hotel.detail',
      status: 'follow_up_created'
    };
    const result: ActionExecutionResult = {
      status: 'success',
      output: output,
      followUp: followUp
    };
    return result;
  }

  private async open(
    actionId: string,
    uri: string,
    message: string
  ): Promise<ActionExecutionResult> {
    if (uri.length === 0) {
      return {
        status: 'error',
        errorCode: 'HOTEL_URI_INVALID',
        message: 'Hotel URI is invalid.'
      };
    }
    let opened = false;
    try {
      opened = await this.opener.open(uri);
    } catch (_error) {
      opened = false;
    }
    if (opened !== true) {
      return {
        status: 'error',
        errorCode: 'HOTEL_URI_OPEN_FAILED',
        message: 'Hotel URI could not be opened.'
      };
    }
    const output: HotelSystemIntentOpened = {
      actionId: actionId,
      status: 'opened',
      uri: uri,
      message: message
    };
    const result: ActionExecutionResult = {
      status: 'success',
      output: output
    };
    return result;
  }
}
