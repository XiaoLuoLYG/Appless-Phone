import {
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionFollowUp,
  HotelCallArgs,
  HotelNavigateArgs,
  RegisteredActionExecutor,
  hotelDialUri,
  hotelNavigationUri
} from '@loop/agent-core';

export interface SystemUriOpener {
  open(uri: string): Promise<boolean>;
}

export interface HotelActionIdFactory {
  nextId(prefix: string): string;
}

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

export class HotelRegisteredActionExecutor implements RegisteredActionExecutor {
  private readonly catalog: ActionCatalog;
  private readonly opener: SystemUriOpener;
  private readonly ids: HotelActionIdFactory;

  constructor(
    catalog: ActionCatalog,
    opener: SystemUriOpener,
    ids: HotelActionIdFactory
  ) {
    this.catalog = catalog;
    this.opener = opener;
    this.ids = ids;
  }

  async execute(
    actionId: string,
    args: Object,
    context: ActionExecutionContext
  ): Promise<ActionExecutionResult> {
    const current = this.catalog.validateSurfaceExecution(
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
    if (actionId === 'hotel.call') {
      return this.open(
        actionId,
        hotelDialUri((args as HotelCallArgs).dialPhone),
        'System dialer opened.'
      );
    }
    return {
      status: 'error',
      errorCode: 'HOTEL_ACTION_UNSUPPORTED',
      message: 'Unsupported hotel action.'
    };
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
        toolId: 'hotel.detail',
        outputSchema: 'hotelRatePlans',
        args: args
      },
      uiTask: {
        taskId: uiTaskId,
        dataTaskId: dataTaskId,
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
        errorCode: 'HOTEL_SYSTEM_INTENT_INVALID',
        message: 'Hotel system intent URI is invalid.'
      };
    }
    let opened = false;
    try {
      opened = await this.opener.open(uri);
    } catch (_error) {
      opened = false;
    }
    if (!opened) {
      return {
        status: 'error',
        errorCode: 'HOTEL_SYSTEM_INTENT_OPEN_FAILED',
        message: 'System could not open the hotel intent.'
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
