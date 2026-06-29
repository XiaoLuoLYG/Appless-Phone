import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { A2uiLabelValueData } from './A2uiTypes';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import { aiLogError, aiLogInfo } from './AiphoneLogger';

const CALENDAR_API_BASE_URL: string = 'https://www.googleapis.com/calendar/v3/calendars';

export interface CalendarEventArgs {
  eventId?: string;
  title?: string;
  start?: string;
  end?: string;
  timezone?: string;
  calendarId?: string;
  query?: string;
  timeMin?: string;
  timeMax?: string;
}

interface CalendarListPayload {
  items?: CalendarEventPayload[];
}

interface CalendarEventBodyTime {
  dateTime: string;
  timeZone: string;
}

interface CalendarEventBody {
  summary: string;
  start: CalendarEventBodyTime;
  end: CalendarEventBodyTime;
}

interface CalendarEventPayload {
  id?: string;
  summary?: string;
  htmlLink?: string;
  updated?: string;
  start?: CalendarEventTime;
  end?: CalendarEventTime;
}

interface CalendarEventTime {
  dateTime?: string;
  date?: string;
  timeZone?: string;
}

interface GoogleApiError {
  message?: string;
  status?: string;
}

interface GoogleApiErrorPayload {
  error?: GoogleApiError;
}

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

function responseText(result: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(result));
  }
  return textOf(result);
}

function encodeParam(value: string): string {
  return encodeURIComponent(value);
}

function urlWithParams(baseUrl: string, params: string[][]): string {
  const pairs: string[] = [];
  params.forEach((pair: string[]) => {
    if (pair.length < 2 || pair[1].length === 0) {
      return;
    }
    pairs.push(encodeParam(pair[0]) + '=' + encodeParam(pair[1]));
  });
  return pairs.length === 0 ? baseUrl : baseUrl + '?' + pairs.join('&');
}

function eventTime(value: CalendarEventTime | undefined): string {
  if (value === undefined) {
    return '';
  }
  return textOf(value.dateTime).length > 0 ? textOf(value.dateTime) : textOf(value.date);
}

function eventRows(item: CalendarEventPayload): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [
    { label: 'Event ID', value: textOf(item.id) },
    { label: 'Start', value: eventTime(item.start) },
    { label: 'End', value: eventTime(item.end) }
  ];
  if (textOf(item.updated).length > 0) {
    rows.push({ label: 'Updated', value: textOf(item.updated) });
  }
  if (textOf(item.htmlLink).length > 0) {
    rows.push({ label: 'Link', value: textOf(item.htmlLink) });
  }
  return rows;
}

function eventResult(toolId: string, item: CalendarEventPayload, summary: string): DynamicGenericToolResult {
  const id = textOf(item.id);
  const title = textOf(item.summary);
  return {
    sourceTag: 'Google Calendar API',
    toolName: toolId,
    title: title.length > 0 ? title : '(no title)',
    status: 'success',
    summary: summary,
    rows: eventRows(item),
    rawPreview: 'eventId=' + id + ' start=' + eventTime(item.start)
  };
}

function errorResult(toolId: string, title: string, message: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Google Calendar API',
    toolName: toolId,
    title: title,
    status: 'error',
    summary: message.substring(0, 240),
    rows: [{ label: 'Error', value: message.substring(0, 160) }],
    rawPreview: 'error=' + message.substring(0, 320)
  };
}

function calendarArgs(args: Object | null): CalendarEventArgs {
  if (args === null) {
    return JSON.parse('{}') as CalendarEventArgs;
  }
  return args as CalendarEventArgs;
}

export function calendarId(args: CalendarEventArgs): string {
  const value = textOf(args.calendarId).trim();
  return value.length > 0 ? value : 'primary';
}

export function calendarEventRequiredFields(toolId: string, args: CalendarEventArgs): string[] {
  const missing: string[] = [];
  if (toolId === 'calendar.event.update' && textOf(args.eventId).trim().length === 0) {
    missing.push('eventId');
  }
  if ((toolId === 'calendar.event.create' || toolId === 'calendar.event.update') && textOf(args.title).trim().length === 0) {
    missing.push('title');
  }
  if ((toolId === 'calendar.event.create' || toolId === 'calendar.event.update') && textOf(args.start).trim().length === 0) {
    missing.push('start');
  }
  if ((toolId === 'calendar.event.create' || toolId === 'calendar.event.update') && textOf(args.end).trim().length === 0) {
    missing.push('end');
  }
  return missing;
}

export function calendarEventResultsFromListPayload(rawJson: string): DynamicGenericToolResult[] {
  const payload = JSON.parse(rawJson) as CalendarListPayload;
  const items = Array.isArray(payload.items) ? payload.items : [];
  const results: DynamicGenericToolResult[] = [];
  for (let index = 0; index < items.length; index++) {
    results.push(eventResult('calendar.events.search', items[index], 'Google Calendar event returned by the real API.'));
  }
  if (results.length === 0) {
    return [{
      sourceTag: 'Google Calendar API',
      toolName: 'calendar.events.search',
      title: '没有找到日程',
      status: 'success',
      summary: 'Google Calendar API 查询成功，但没有可展示事件。',
      rows: [],
      rawPreview: 'empty calendar list'
    }];
  }
  return results;
}

export function calendarCreateBody(args: CalendarEventArgs): CalendarEventBody {
  return {
    summary: textOf(args.title),
    start: { dateTime: textOf(args.start), timeZone: textOf(args.timezone) },
    end: { dateTime: textOf(args.end), timeZone: textOf(args.timezone) }
  };
}

export function calendarUpdateBody(args: CalendarEventArgs): CalendarEventBody {
  return calendarCreateBody(args);
}

export function calendarMissingArgsResult(toolId: string, missing: string[]): DynamicGenericToolResult {
  return {
    sourceTag: 'Google Calendar API',
    toolName: toolId,
    title: '缺少 Google Calendar 参数',
    status: 'error',
    summary: '缺少字段：' + missing.join(', '),
    rows: missing.map((name: string): A2uiLabelValueData => ({ label: 'Missing', value: name })),
    rawPreview: 'missing=' + missing.join(',')
  };
}

async function requestJson(method: http.RequestMethod, url: string, accessToken: string, body: Object | null): Promise<Object> {
  const request = http.createHttp();
  try {
    const headers: Record<string, string> = {
      'Authorization': 'Bearer ' + accessToken,
      'Accept': 'application/json'
    };
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 20000
    };
    if (body !== null) {
      headers['Content-Type'] = 'application/json';
      options.extraData = JSON.stringify(body);
    }
    aiLogInfo('[AIPhone][CalendarApiHttpStart] url=' + url.substring(0, 180));
    const response = await request.request(url, options);
    const text = responseText(response.result);
    const payload = text.length > 0 ? JSON.parse(text) as Object : new Object();
    if (response.responseCode < 200 || response.responseCode >= 300) {
      const errorPayload = payload as GoogleApiErrorPayload;
      const message = errorPayload.error === undefined ? '' : textOf(errorPayload.error.message);
      const status = errorPayload.error === undefined ? '' : textOf(errorPayload.error.status);
      throw new Error(message.length > 0 ? message : (status.length > 0 ? status : 'HTTP ' + response.responseCode.toString()));
    }
    return payload;
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    aiLogError('[AIPhone][CalendarApiHttpError] error=' + message.substring(0, 220));
    throw new Error(message);
  } finally {
    request.destroy();
  }
}

async function searchEvents(accessToken: string, prompt: string, args: CalendarEventArgs): Promise<DynamicGenericToolResult[]> {
  const query = textOf(args.query).trim();
  const id = textOf(args.calendarId).trim();
  const url = urlWithParams(CALENDAR_API_BASE_URL + '/' + encodeParam(id.length > 0 ? id : 'primary') + '/events', [
    ['singleEvents', 'true'],
    ['orderBy', 'startTime'],
    ['q', query.length > 0 ? query : prompt],
    ['timeMin', textOf(args.timeMin).trim()],
    ['timeMax', textOf(args.timeMax).trim()],
    ['maxResults', '10']
  ]);
  const payload = await requestJson(http.RequestMethod.GET, url, accessToken, null);
  return calendarEventResultsFromListPayload(JSON.stringify(payload));
}

export async function callCalendarTool(toolId: string, prompt: string, accessToken: string, args: Object | null = null): Promise<DynamicGenericToolResult[]> {
  try {
    const eventArgs = calendarArgs(args);
    const missing = calendarEventRequiredFields(toolId, eventArgs);
    if (missing.length > 0) {
      return [calendarMissingArgsResult(toolId, missing)];
    }
    const base = CALENDAR_API_BASE_URL + '/' + encodeParam(calendarId(eventArgs)) + '/events';
    if (toolId === 'calendar.events.search') {
      return await searchEvents(accessToken, prompt, eventArgs);
    }
    if (toolId === 'calendar.event.create') {
      const created = await requestJson(http.RequestMethod.POST, base, accessToken, calendarCreateBody(eventArgs)) as CalendarEventPayload;
      return [eventResult(toolId, created, '已直接写入真实 Google Calendar。')];
    }
    if (toolId === 'calendar.event.update') {
      const updated = await requestJson(http.RequestMethod.PUT, base + '/' + encodeParam(textOf(eventArgs.eventId)), accessToken, calendarUpdateBody(eventArgs)) as CalendarEventPayload;
      return [eventResult(toolId, updated, '已直接更新真实 Google Calendar。')];
    }
    return [errorResult(toolId, '不支持的 Google Calendar 工具', toolId)];
  } catch (error) {
    return [errorResult(toolId, 'Google Calendar API 调用失败', error instanceof Error ? error.message : JSON.stringify(error))];
  }
}
