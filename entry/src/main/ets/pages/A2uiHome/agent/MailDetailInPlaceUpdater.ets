import { MailCalendarSuggestion, MailDetail } from '@loop/agent-core';
import { MailDetailInPlaceEvent } from './MultiAgentCanaryRuntime';

export interface MailDetailUiEvent {
  sequence: number;
  requestKey: string;
  status: string;
  detail?: MailDetail;
  calendarSuggestion?: MailCalendarSuggestion;
  error: string;
}

export interface MailDetailSuggestionCallbacks {
  initialIsCurrent: () => boolean;
  enrichmentIsCurrent: () => boolean;
  writeEvent: (event: MailDetailUiEvent) => void;
  saveSuggestion: (requestKey: string, suggestion: MailCalendarSuggestion) => void;
  suggest: (detail: MailDetail) => Promise<MailCalendarSuggestion>;
  onSuggestionError?: (message: string) => void;
}

function successEvent(
  result: MailDetailInPlaceEvent,
  detail: MailDetail,
  suggestion?: MailCalendarSuggestion
): MailDetailUiEvent {
  const event: MailDetailUiEvent = {
    sequence: Date.now(),
    requestKey: result.requestKey,
    status: 'success',
    detail,
    error: ''
  };
  if (suggestion !== undefined) {
    event.calendarSuggestion = suggestion;
  }
  return event;
}

export async function publishMailDetailThenSuggest(
  result: MailDetailInPlaceEvent,
  callbacks: MailDetailSuggestionCallbacks
): Promise<void> {
  if (!callbacks.initialIsCurrent()) {
    throw new Error('Mail detail surface is stale.');
  }
  if (result.status !== 'success' || result.detail === undefined) {
    callbacks.writeEvent({
      sequence: Date.now(),
      requestKey: result.requestKey,
      status: 'error',
      error: result.error
    });
    return;
  }

  const detail = result.detail;
  callbacks.writeEvent(successEvent(result, detail));
  void callbacks.suggest(detail).then(
    (suggestion: MailCalendarSuggestion): void => {
      if (!callbacks.enrichmentIsCurrent()) {
        return;
      }
      callbacks.saveSuggestion(result.requestKey, suggestion);
      callbacks.writeEvent(successEvent(result, detail, suggestion));
    },
    (error: Error): void => {
      if (callbacks.onSuggestionError !== undefined) {
        callbacks.onSuggestionError(error.message);
      }
    }
  );
}
