import {
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionFollowUp,
  ActionStepExecutor,
  ActionValidationResult,
  CalendarEventArgs,
  HotelBookingOpenArgs,
  HotelNavigateArgs,
  RegisteredActionExecutor,
  calendarEventRequiredFields,
  hotelNavigationUri,
  validateHotelActionArgs
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

function argText(values: MailReplyArgRecord, keys: string[]): string {
  for (let index = 0; index < keys.length; index++) {
    const value = values[keys[index]];
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
    if (typeof value === 'number') {
      return value.toString();
    }
  }
  return '';
}

function validation(ok: boolean, code: string, message: string): ActionValidationResult {
  return {
    ok,
    code: ok ? '' : code,
    message: ok ? '' : message
  };
}

function recipientsValid(value: MailReplyArgValue): boolean {
  if (typeof value === 'string') {
    return value.trim().length > 0;
  }
  return Array.isArray(value) && value.length > 0 && value.every(
    (recipient: MailReplyArgValue): boolean =>
      typeof recipient === 'string' && recipient.trim().length > 0
  );
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

export function validateRegisteredPageActionArgs(
  actionId: string,
  args: Object
): ActionValidationResult {
  if (args === null || typeof args !== 'object' || Array.isArray(args)) {
    return validation(false, 'ACTION_ARGS_INVALID', 'Registered action args are invalid.');
  }
  if (actionId.indexOf('hotel.') === 0) {
    return validateHotelActionArgs(actionId, args);
  }
  if (actionId === 'gmail.message.send') {
    return validateGmailReplyActionArgs(args);
  }
  const values = args as MailReplyArgRecord;
  if (actionId === 'luckin.order.preview') {
    return validation(
      argText(values, ['deptId']).length > 0,
      'LUCKIN_PREVIEW_ARGS_INVALID', 'Luckin preview requires the exact store.'
    );
  }
  if (actionId === 'luckin.order.create') {
    return validation(
      argText(values, ['deptId']).length > 0 && argText(values, ['productId']).length > 0 &&
        argText(values, ['skuCode']).length > 0,
      'LUCKIN_ORDER_ARGS_INVALID', 'Luckin order requires the exact store, product, and SKU.'
    );
  }
  if (actionId === 'social.reply.draft') {
    return validation(
      argText(values, ['itemId']).length > 0 && argText(values, ['platform']).length > 0 &&
        argText(values, ['instruction']).length > 0,
      'SOCIAL_DRAFT_ARGS_INVALID', 'Social draft requires the exact item, platform, and instruction.'
    );
  }
  if (actionId === 'mail.draft.create') {
    const provider = argText(values, ['provider']).toLowerCase();
    return validation(
      (provider === 'gmail' || provider === 'qq') && recipientsValid(values['to']) &&
        argText(values, ['body']).length > 0,
      'MAIL_DRAFT_ARGS_INVALID', 'Mail draft requires an exact provider, recipient, and body.'
    );
  }
  if (actionId === 'gmail.draft.create') {
    return validation(
      recipientsValid(values['to']) && argText(values, ['body']).length > 0,
      'GMAIL_DRAFT_ARGS_INVALID', 'Gmail draft requires an exact recipient and body.'
    );
  }
  if (actionId === 'gmail.draft.apply') {
    return validation(
      argText(values, ['threadId']).length > 0 && recipientsValid(values['to']) &&
        argText(values, ['subject']).length > 0 && argText(values, ['replyMode']) === 'reply' &&
        argText(values, ['body']).length > 0,
      'GMAIL_DRAFT_ARGS_INVALID', 'Gmail apply requires the exact thread, recipients, subject, mode, and body.'
    );
  }
  if (actionId === 'gmail.open.web') {
    return validation(
      argText(values, ['url']).startsWith('https://mail.google.com/'),
      'GMAIL_WEB_ARGS_INVALID', 'Gmail Web requires an exact Google Mail URL.'
    );
  }
  if (actionId === 'worldcup.open') {
    return validation(
      argText(values, ['route']) === 'pages/A2uiHome/AnythingDemo',
      'WORLDCUP_ARGS_INVALID', 'World Cup requires the exact registered page route.'
    );
  }
  if (actionId === 'calendar.event.create' || actionId === 'calendar.event.update') {
    return validation(
      calendarEventRequiredFields(actionId, args as CalendarEventArgs).length === 0,
      'CALENDAR_EVENT_ARGS_INVALID', 'Calendar write args are incomplete or invalid.'
    );
  }
  if (actionId === 'calendar.event.delete') {
    return validation(
      argText(values, ['eventId']).length > 0,
      'CALENDAR_EVENT_ARGS_INVALID', 'Calendar delete requires the exact Event ID.'
    );
  }
  if (actionId === 'payment.send') {
    return validation(
      argText(values, ['provider']).length > 0 && argText(values, ['recipient']).length > 0 &&
        argText(values, ['amountText']).length > 0 && argText(values, ['currency']).length > 0,
      'PAYMENT_SEND_ARGS_INVALID', 'Payment requires the exact provider, recipient, amount, and currency.'
    );
  }
  if (actionId === 'payment.account.setup') {
    return validation(
      argText(values, ['country']).length > 0 && argText(values, ['businessType']).length > 0,
      'PAYMENT_ACCOUNT_ARGS_INVALID', 'Payment account setup requires exact country and business type.'
    );
  }
  if (actionId === 'maps.route.open') {
    const mode = argText(values, ['travelMode']);
    const navigate = values['navigate'];
    return validation(
      argText(values, ['origin']).length > 0 && argText(values, ['destination']).length > 0 &&
        (mode.length === 0 || ['driving', 'walking', 'bicycling', 'transit', 'two-wheeler'].indexOf(mode) >= 0) &&
        (navigate === undefined || typeof navigate === 'boolean'),
      'MAPS_ROUTE_ARGS_INVALID', 'Maps route requires exact origin and destination.'
    );
  }
  if (actionId === 'whatsapp.message.send') {
    return validation(
      argText(values, ['toNumber']).length > 0 && argText(values, ['text']).length > 0,
      'WHATSAPP_SEND_ARGS_INVALID', 'WhatsApp send requires the exact target and message.'
    );
  }
  if (actionId === 'ride.order.create') {
    return validation(
      argText(values, ['productCategory', 'product_category']).length > 0 &&
        argText(values, ['estimateTraceId', 'estimate_trace_id', 'traceId']).length > 0,
      'RIDE_ORDER_ARGS_INVALID', 'Ride create requires the exact vehicle and estimate trace.'
    );
  }
  if (actionId === 'ride.order.cancel') {
    return validation(
      argText(values, ['orderId', 'order_id']).length > 0,
      'RIDE_ORDER_ARGS_INVALID', 'Ride cancel requires the exact order ID.'
    );
  }
  return validation(false, 'ACTION_NOT_REGISTERED', 'Action is not registered for product execution.');
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

export class AiphoneRegisteredActionExecutor implements RegisteredActionExecutor, ActionStepExecutor {
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
    const registered = actionId === 'hotel.detail' ||
      validateRegisteredPageActionArgs(actionId, args).code !== 'ACTION_NOT_REGISTERED';
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
      pageActionId: context.isSurfaceEntry === false ?
        (actionId === 'calendar.event.delete' ? 'calendar.event.delete.confirm' : actionId) :
        (context.pageActionId === undefined || context.pageActionId.length === 0 ?
          actionId : context.pageActionId),
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
