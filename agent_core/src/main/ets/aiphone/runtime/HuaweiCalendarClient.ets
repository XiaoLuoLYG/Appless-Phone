import { common } from '@kit.AbilityKit';
import { calendarManager } from '@kit.CalendarKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { aiLogError, aiLogInfo } from './AiphoneLogger';
import { HuaweiCalendarAddResult, MailCalendarSuggestion } from './MailToolTypes';

function textOf(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

function parseEventTime(value: string): number {
  const parsed = Date.parse(value.trim());
  return Number.isNaN(parsed) ? 0 : parsed;
}

function fallbackEndTime(startMs: number, endMs: number): number {
  if (endMs > startMs) {
    return endMs;
  }
  return startMs + 30 * 60 * 1000;
}

function eventDescription(suggestion: MailCalendarSuggestion): string {
  const parts: string[] = [];
  const description = textOf(suggestion.description).trim();
  if (description.length > 0) {
    parts.push(description);
  }
  parts.push('Source: Appless Phone mail');
  parts.push('Provider: ' + textOf(suggestion.provider));
  parts.push('Thread ID: ' + textOf(suggestion.threadId));
  parts.push('Message ID: ' + textOf(suggestion.messageId));
  return parts.join('\n');
}

export async function addHuaweiCalendarEvent(
  context: common.UIAbilityContext,
  suggestion: MailCalendarSuggestion
): Promise<HuaweiCalendarAddResult> {
  const title = textOf(suggestion.title).trim();
  const startMs = parseEventTime(suggestion.start);
  const endMs = fallbackEndTime(startMs, parseEventTime(suggestion.end));
  if (title.length === 0 || startMs <= 0) {
    throw new Error('日程缺少标题或开始时间。');
  }
  try {
    const calendarMgr = calendarManager.getCalendarManager(context);
    const calendar = await calendarMgr.getCalendar();
    const event: calendarManager.Event = {
      title: title,
      type: calendarManager.EventType.NORMAL,
      startTime: startMs,
      endTime: endMs,
      location: { location: textOf(suggestion.location).trim() },
      reminderTime: [10],
      description: eventDescription(suggestion)
    };
    const eventId = await calendar.addEvent(event);
    aiLogInfo('[AIPhone][HuaweiCalendarAdd] ok=true eventId=' + eventId.toString() +
      ' requestKey=' + textOf(suggestion.requestKey));
    return {
      requestKey: textOf(suggestion.requestKey),
      eventId: eventId.toString(),
      status: 'success',
      message: '已添加日程'
    };
  } catch (error) {
    const businessError = error as BusinessError;
    const message = businessError.message !== undefined ? businessError.message :
      (error instanceof Error ? error.message : JSON.stringify(error));
    aiLogError('[AIPhone][HuaweiCalendarAdd] ok=false message=' + message.substring(0, 240));
    throw new Error(message);
  }
}
