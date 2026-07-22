import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { A2uiLabelValueData } from './A2uiTypes';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import { aiLogError, aiLogInfo } from './AiphoneLogger';

const CALENDAR_API_BASE_URL: string = 'https://www.googleapis.com/calendar/v3/calendars';

export interface CalendarEventArgs {
  date?: string;
  eventId?: string;
  title?: string;
  start?: string;
  end?: string;
  timezone?: string;
  calendarId?: string;
  query?: string;
  timeRange?: string;
  timeMin?: string;
  timeMax?: string;
}

interface CalendarListPayload {
  items?: CalendarEventPayload[];
}

interface CalendarComposioPayload {
  data?: Object;
  error?: Object | string | null;
}

interface CalendarComposioData {
  response_data?: CalendarEventPayload;
}

type CalendarProviderValue = Object | string | number | boolean | null | undefined;
type CalendarProviderRecord = Record<string, CalendarProviderValue>;

interface CalendarEventBodyTime {
  dateTime: string;
  timeZone: string;
}

interface CalendarEventBody {
  summary: string;
  start: CalendarEventBodyTime;
  end: CalendarEventBodyTime;
}

export interface CalendarEventPayload {
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

export function calendarEventMatchesArgs(item: CalendarEventPayload, args: CalendarEventArgs): boolean {
  return textOf(item.summary).trim() === textOf(args.title).trim() &&
    eventTime(item.start) === textOf(args.start).trim() &&
    eventTime(item.end) === textOf(args.end).trim();
}

export function calendarMatchingExistingEventFromListPayload(rawJson: string, args: CalendarEventArgs): CalendarEventPayload | null {
  const payload = JSON.parse(rawJson) as CalendarListPayload;
  const items = Array.isArray(payload.items) ? payload.items : [];
  for (let index = 0; index < items.length; index++) {
    if (calendarEventMatchesArgs(items[index], args)) {
      return items[index];
    }
  }
  return null;
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

function cloneCalendarArgs(args: CalendarEventArgs): CalendarEventArgs {
  return {
    date: textOf(args.date),
    eventId: textOf(args.eventId),
    title: textOf(args.title),
    start: textOf(args.start),
    end: textOf(args.end),
    timezone: textOf(args.timezone),
    calendarId: textOf(args.calendarId),
    query: textOf(args.query),
    timeRange: textOf(args.timeRange),
    timeMin: textOf(args.timeMin),
    timeMax: textOf(args.timeMax)
  };
}

function relativeDayOffset(prompt: string): number {
  if (prompt.indexOf('大后天') >= 0) {
    return 3;
  }
  if (prompt.indexOf('后天') >= 0) {
    return 2;
  }
  if (prompt.indexOf('明天') >= 0 || prompt.indexOf('明日') >= 0) {
    return 1;
  }
  if (prompt.indexOf('今天') >= 0 || prompt.indexOf('今日') >= 0) {
    return 0;
  }
  return -1;
}

function relativeMonthOffset(prompt: string): number | null {
  if (prompt.indexOf('下下个月') >= 0) {
    return 2;
  }
  if (prompt.indexOf('下个月') >= 0 || prompt.indexOf('下月') >= 0) {
    return 1;
  }
  if (prompt.indexOf('上个月') >= 0 || prompt.indexOf('上月') >= 0) {
    return -1;
  }
  if (prompt.indexOf('本月') >= 0 || prompt.indexOf('这个月') >= 0 || prompt.indexOf('当月') >= 0) {
    return 0;
  }
  return null;
}

function relativeWeekOffset(prompt: string): number | null {
  const lower = prompt.toLowerCase();
  if (prompt.indexOf('下下周') >= 0 || prompt.indexOf('下下星期') >= 0 || prompt.indexOf('下下礼拜') >= 0) {
    return 2;
  }
  if (prompt.indexOf('下周') >= 0 || prompt.indexOf('下星期') >= 0 || prompt.indexOf('下礼拜') >= 0 || lower.indexOf('next week') >= 0) {
    return 1;
  }
  if (prompt.indexOf('上周') >= 0 || prompt.indexOf('上星期') >= 0 || prompt.indexOf('上礼拜') >= 0 || lower.indexOf('last week') >= 0) {
    return -1;
  }
  if (prompt.indexOf('本周') >= 0 || prompt.indexOf('这周') >= 0 || prompt.indexOf('本星期') >= 0 || prompt.indexOf('这个星期') >= 0 ||
    prompt.indexOf('本礼拜') >= 0 || prompt.indexOf('这礼拜') >= 0 || lower.indexOf('this week') >= 0 || lower.indexOf('current week') >= 0) {
    return 0;
  }
  return null;
}

function pad2Date(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

function localDateAfter(now: Date, offset: number): Date {
  return new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset);
}

function localMonthAfter(now: Date, offset: number): Date {
  return new Date(now.getFullYear(), now.getMonth() + offset, 1);
}

function startOfLocalWeek(now: Date): Date {
  const day = now.getDay() === 0 ? 7 : now.getDay();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate() - day + 1);
}

function localDateString(date: Date): string {
  return date.getFullYear().toString() + '-' + pad2Date(date.getMonth() + 1) + '-' + pad2Date(date.getDate());
}

function startOfLocalDay(date: Date): string {
  return localDateString(date) + 'T00:00:00+08:00';
}

function calendarWindowWithinDay(args: CalendarEventArgs, day: Date, nextDay: Date): boolean {
  const start = Date.parse(textOf(args.timeMin));
  const end = Date.parse(textOf(args.timeMax));
  const dayStart = Date.parse(startOfLocalDay(day));
  const dayEnd = Date.parse(startOfLocalDay(nextDay));
  return !Number.isNaN(start) && !Number.isNaN(end) && start >= dayStart && start < dayEnd && end > start && end <= dayEnd;
}

function startOfLocalMonth(date: Date): string {
  const firstDay = new Date(date.getFullYear(), date.getMonth(), 1);
  return localDateString(firstDay) + 'T00:00:00+08:00';
}

function absoluteDateArg(args: CalendarEventArgs): Date | null {
  const value = textOf(args.date).trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return null;
  }
  const year = Number.parseInt(value.substring(0, 4), 10);
  const month = Number.parseInt(value.substring(5, 7), 10);
  const day = Number.parseInt(value.substring(8, 10), 10);
  const date = new Date(year, month - 1, day);
  return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day ? date : null;
}

function normalizedCalendarTimezone(value: string): string {
  const timezone = value.trim();
  return timezone === 'UTC' || /^[A-Za-z_]+\/[A-Za-z0-9_+\/-]+$/.test(timezone) ? timezone : 'Asia/Shanghai';
}

export function calendarDateFromPrompt(prompt: string, now: Date = new Date()): string {
  const chinese = /(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日/.exec(prompt);
  const dashed = /(\d{4})[-/](\d{1,2})[-/](\d{1,2})/.exec(prompt);
  const match = chinese === null ? dashed : chinese;
  if (match !== null) {
    const date = new Date(Number.parseInt(match[1], 10), Number.parseInt(match[2], 10) - 1,
      Number.parseInt(match[3], 10));
    if (date.getFullYear().toString() === match[1] && date.getMonth() + 1 === Number.parseInt(match[2], 10) &&
      date.getDate() === Number.parseInt(match[3], 10)) {
      return localDateString(date);
    }
    return '';
  }
  const offset = relativeDayOffset(prompt);
  if (offset >= 0) {
    return localDateString(localDateAfter(now, offset));
  }
  const monthDay = /(\d{1,2})\s*(?:月|-|\/)\s*(\d{1,2})\s*(?:日|号)?/.exec(prompt);
  if (monthDay === null) {
    return '';
  }
  const date = new Date(now.getFullYear(), Number.parseInt(monthDay[1], 10) - 1,
    Number.parseInt(monthDay[2], 10));
  return date.getMonth() + 1 === Number.parseInt(monthDay[1], 10) &&
    date.getDate() === Number.parseInt(monthDay[2], 10) ? localDateString(date) : '';
}

function calendarChineseNumber(token: string): number {
  const raw = token.trim();
  if (/^\d+$/.test(raw)) {
    return Number.parseInt(raw, 10);
  }
  if (raw === '两') {
    return 2;
  }
  const digits = '零一二三四五六七八九';
  if (raw.length === 1) {
    const value = digits.indexOf(raw);
    return value < 0 ? (raw === '十' ? 10 : -1) : value;
  }
  const tens = /^([一二三四五六七八九])?十([一二三四五六七八九])?$/.exec(raw);
  if (tens === null) {
    return -1;
  }
  const high = tens[1] === undefined ? 1 : calendarChineseNumber(tens[1]);
  const low = tens[2] === undefined ? 0 : calendarChineseNumber(tens[2]);
  return high * 10 + low;
}

export function calendarTimeFromPrompt(prompt: string): string {
  const colon = /(\d{1,2})\s*[:：]\s*(\d{2})/.exec(prompt);
  let hour = colon === null ? -1 : Number.parseInt(colon[1], 10);
  let minute = colon === null ? -1 : Number.parseInt(colon[2], 10);
  if (colon === null) {
    const point = /(凌晨|早上|上午|中午|下午|傍晚|晚上|夜间)?\s*([零一二三四五六七八九十两\d]{1,4})\s*点(?:\s*(半)|\s*([零一二三四五六七八九十\d]{1,2})\s*分?)?/.exec(prompt);
    if (point === null) {
      return '';
    }
    hour = calendarChineseNumber(point[2]);
    minute = point[3] === undefined ? (point[4] === undefined ? 0 : calendarChineseNumber(point[4])) : 30;
    const period = point[1] === undefined ? '' : point[1];
    if ((period === '下午' || period === '晚上' || period === '傍晚') && hour >= 1 && hour <= 11) {
      hour += 12;
    } else if ((period === '凌晨' || period === '早上' || period === '上午') && hour === 12) {
      hour = 0;
    }
  }
  return hour >= 0 && hour < 24 && minute >= 0 && minute < 60 ?
    pad2Date(hour) + ':' + pad2Date(minute) : '';
}

function calendarDurationMinutes(prompt: string): number {
  const minutes = /(\d+)\s*分钟/.exec(prompt);
  if (minutes !== null) {
    return Number.parseInt(minutes[1], 10);
  }
  if (/半(?:个)?小时/.test(prompt)) {
    return 30;
  }
  const hours = /(\d+)\s*(?:个)?小时/.exec(prompt);
  return hours === null ? 0 : Number.parseInt(hours[1], 10) * 60;
}

function calendarEndAfter(start: string, minutes: number): string {
  const wallStart = Date.parse(calendarProviderDateTime(start) + 'Z');
  return minutes > 0 && !Number.isNaN(wallStart) ?
    new Date(wallStart + minutes * 60000).toISOString().substring(0, 19) + '+08:00' : '';
}

function calendarLabeledValue(input: string, label: string): string {
  const index = input.indexOf(label);
  if (index < 0) {
    return '';
  }
  const start = index + label.length;
  const semicolon = input.indexOf('；', start);
  const asciiSemicolon = input.indexOf(';', start);
  let end = semicolon;
  if (end < 0 || (asciiSemicolon >= 0 && asciiSemicolon < end)) {
    end = asciiSemicolon;
  }
  return input.substring(start, end < 0 ? input.length : end).trim();
}

function calendarCreateTitle(prompt: string): string {
  const labeled = calendarLabeledValue(prompt, '标题：');
  if (labeled.length > 0) {
    return labeled;
  }
  const named = /(?:title|标题)\s*为\s*(.+?)(?:的(?:\d+\s*分钟|半(?:个)?小时|\d+\s*(?:个)?小时)?\s*日程|日程|$)/i.exec(prompt);
  if (named !== null) {
    return named[1].trim();
  }
  const durationFirst = /(?:\d+\s*分钟|半(?:个)?小时|\d+\s*(?:个)?小时)\s*的\s*(.+?)日程/.exec(prompt);
  return durationFirst === null ? '' : durationFirst[1].trim();
}

function calendarUpdateQuery(prompt: string): string {
  const labeled = calendarLabeledValue(prompt, '原日程：');
  if (labeled.length > 0) {
    return labeled;
  }
  const match = /把\s*(.+?)\s*日程(?:改到|移到|改名)/.exec(prompt);
  if (match === null) {
    return '';
  }
  return match[1]
    .replace(/\d{4}年\s*\d{1,2}月\s*\d{1,2}日/g, '')
    .replace(/\d{4}-\d{1,2}-\d{1,2}/g, '')
    .replace(/今天|今日|明天|明日|后天|大后天/g, '')
    .replace(/凌晨|早上|上午|中午|下午|晚上/g, '')
    .replace(/^\s*的\s*|\s*的\s*$/g, '').trim();
}

function calendarUpdateTitle(prompt: string): string {
  const labeled = calendarLabeledValue(prompt, '新标题：');
  if (labeled.length > 0) {
    return labeled;
  }
  const match = /改名为\s*(.+?)(?:并|再|且|，|,|。|$)/.exec(prompt);
  return match === null ? '' : match[1].trim();
}

function calendarExplicitRange(prompt: string): string[] {
  const match = /(?:时间|新时间)[：:]\s*(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})\s*(?:至|到)\s*(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})/.exec(prompt);
  return match === null ? [] : [match[1] + 'T' + match[2] + ':00+08:00',
    match[3] + 'T' + match[4] + ':00+08:00'];
}

function normalizeCalendarWritePrompt(toolId: string, prompt: string, args: CalendarEventArgs, now: Date): boolean {
  const create = toolId === 'calendar.event.create' && prompt.indexOf('创建') >= 0 && prompt.indexOf('日程') >= 0;
  const update = toolId === 'calendar.event.update' &&
    ((prompt.indexOf('把') >= 0 && prompt.indexOf('日程') >= 0) || prompt.indexOf('原日程：') >= 0);
  if (!create && !update) {
    return false;
  }
  args.eventId = '';
  args.title = create ? calendarCreateTitle(prompt) : calendarUpdateTitle(prompt);
  args.start = '';
  args.end = '';
  args.query = update ? calendarUpdateQuery(prompt) : '';
  args.date = calendarDateFromPrompt(prompt, now);
  args.calendarId = 'primary';
  const range = calendarExplicitRange(prompt);
  if (range.length === 2) {
    args.start = range[0];
    args.end = range[1];
  } else if (textOf(args.date).length > 0) {
    const destinationIndex = update ? Math.max(prompt.indexOf('改到'), prompt.indexOf('移到')) : -1;
    const timePrompt = destinationIndex >= 0 ? prompt.substring(destinationIndex + 2) : prompt;
    const time = calendarTimeFromPrompt(timePrompt);
    if (time.length > 0) {
      args.start = textOf(args.date) + 'T' + time + ':00+08:00';
      args.end = calendarEndAfter(textOf(args.start), calendarDurationMinutes(prompt));
    }
  }
  if (update && textOf(args.date).length > 0) {
    const day = absoluteDateArg(args);
    if (day !== null) {
      args.timeMin = startOfLocalDay(day);
      args.timeMax = startOfLocalDay(localDateAfter(day, 1));
    }
  }
  return true;
}

export function normalizedCalendarArgsForPrompt(
  toolId: string,
  prompt: string,
  args: CalendarEventArgs,
  now: Date = new Date(),
  parseNaturalWrite: boolean = false
): CalendarEventArgs {
  const normalized = cloneCalendarArgs(args);
  normalized.timezone = normalizedCalendarTimezone(textOf(normalized.timezone));
  if (toolId === 'calendar.event.create' || toolId === 'calendar.event.update') {
    if (parseNaturalWrite) {
      normalizeCalendarWritePrompt(toolId, prompt, normalized, now);
    }
    return normalized;
  }
  const relativeText = prompt + ' ' + textOf(normalized.timeRange);
  const offset = relativeDayOffset(relativeText);
  if (offset >= 0) {
    const targetDate = localDateAfter(now, offset);
    if (textOf(normalized.timezone).length === 0) {
      normalized.timezone = 'Asia/Shanghai';
    }
    if (toolId === 'calendar.events.search') {
      const nextDate = localDateAfter(now, offset + 1);
      if (calendarWindowWithinDay(normalized, targetDate, nextDate)) {
        return normalized;
      }
      normalized.timeMin = startOfLocalDay(targetDate);
      normalized.timeMax = startOfLocalDay(nextDate);
      return normalized;
    }
    return normalized;
  }

  const absoluteDate = absoluteDateArg(normalized);
  if (absoluteDate !== null && toolId === 'calendar.events.search') {
    normalized.timezone = textOf(normalized.timezone).length > 0 ? normalized.timezone : 'Asia/Shanghai';
    normalized.timeMin = startOfLocalDay(absoluteDate);
    normalized.timeMax = startOfLocalDay(localDateAfter(absoluteDate, 1));
    return normalized;
  }

  const weekOffset = relativeWeekOffset(relativeText);
  if (weekOffset !== null && toolId === 'calendar.events.search') {
    const weekStart = localDateAfter(startOfLocalWeek(now), weekOffset * 7);
    if (textOf(normalized.timezone).length === 0) {
      normalized.timezone = 'Asia/Shanghai';
    }
    normalized.timeMin = startOfLocalDay(weekStart);
    normalized.timeMax = startOfLocalDay(localDateAfter(weekStart, 7));
    return normalized;
  }

  const monthOffset = relativeMonthOffset(relativeText);
  if (monthOffset !== null) {
    const monthStart = localMonthAfter(now, monthOffset);
    const monthEnd = localMonthAfter(now, monthOffset + 1);
    if (textOf(normalized.timezone).length === 0) {
      normalized.timezone = 'Asia/Shanghai';
    }
    normalized.timeMin = startOfLocalMonth(monthStart);
    normalized.timeMax = startOfLocalMonth(monthEnd);
    return normalized;
  }

  if (offset < 0 && monthOffset === null) {
    return normalized;
  }
  return normalized;
}

export function calendarId(args: CalendarEventArgs): string {
  const value = textOf(args.calendarId).trim();
  return value.length > 0 ? value : 'primary';
}

export function calendarSearchQueryText(args: CalendarEventArgs): string {
  return textOf(args.query).trim();
}

export function calendarEventRequiredFields(toolId: string, args: CalendarEventArgs): string[] {
  const missing: string[] = [];
  if (toolId === 'calendar.event.update' && textOf(args.eventId).trim().length === 0) {
    missing.push('eventId');
  }
  if ((toolId === 'calendar.event.create' || toolId === 'calendar.event.update') && textOf(args.title).trim().length === 0) {
    missing.push('title');
  }
  if ((toolId === 'calendar.event.create' || toolId === 'calendar.event.update') && !isCalendarProviderDateTime(textOf(args.start))) {
    missing.push('start');
  }
  if ((toolId === 'calendar.event.create' || toolId === 'calendar.event.update') && !isCalendarProviderDateTime(textOf(args.end))) {
    missing.push('end');
  }
  return missing;
}

function isCalendarProviderDateTime(value: string): boolean {
  const text = value.trim();
  if (!/^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2})?(\.\d+)?(Z|[+-]\d{1,2}(:?\d{2})?)?$/.test(text)) {
    return false;
  }
  return !Number.isNaN(Date.parse(text));
}

export function calendarProviderDateTime(value: string): string {
  const text = value.trim();
  return text.substring(0, text.length > 16 && text.charAt(16) === ':' ? 19 : 16);
}

export function calendarEventResultsFromListPayload(rawJson: string, args: CalendarEventArgs | null = null): DynamicGenericToolResult[] {
  const payload = JSON.parse(rawJson) as CalendarListPayload;
  const items = Array.isArray(payload.items) ? payload.items : [];
  const results: DynamicGenericToolResult[] = [];
  for (let index = 0; index < items.length; index++) {
    results.push(eventResult('calendar.events.search', items[index], 'Google Calendar event returned by the real API.'));
  }
  if (results.length === 0) {
    const rows: A2uiLabelValueData[] = [];
    if (args !== null && textOf(args.timeMin).length > 0) {
      rows.push({ label: 'Window Start', value: textOf(args.timeMin) });
    }
    if (args !== null && textOf(args.timeMax).length > 0) {
      rows.push({ label: 'Window End', value: textOf(args.timeMax) });
    }
    return [{
      sourceTag: 'Google Calendar API',
      toolName: 'calendar.events.search',
      title: '没有找到日程',
      status: 'success',
      summary: 'Google Calendar API 查询成功，但没有可展示事件。',
      rows: rows,
      rawPreview: 'empty calendar list'
    }];
  }
  return results;
}

function composioCalendarResults(results: DynamicGenericToolResult[]): DynamicGenericToolResult[] {
  results.forEach((result: DynamicGenericToolResult) => result.sourceTag = 'Composio Google Calendar');
  return results;
}

function calendarProviderObject(value: CalendarProviderValue): Object | null {
  return value !== null && value !== undefined && typeof value === 'object' && !Array.isArray(value) ?
    value as Object : null;
}

function calendarProviderRecords(payload: CalendarComposioPayload): Object[] {
  const records: Object[] = [payload as Object];
  const data = calendarProviderObject(payload.data);
  if (data !== null) {
    records.push(data);
    const response = calendarProviderObject((data as CalendarProviderRecord)['response_data']);
    if (response !== null) {
      records.push(response);
    }
  }
  return records;
}

function negativeCalendarStatus(value: string): boolean {
  const status = value.trim().toLowerCase();
  return status.indexOf('fail') >= 0 || status.indexOf('error') >= 0 ||
    status.indexOf('reject') >= 0 || status.indexOf('denied') >= 0 ||
    status.indexOf('invalid') >= 0;
}

function calendarWriteFailure(payload: CalendarComposioPayload): string {
  const records = calendarProviderRecords(payload);
  for (let index = 0; index < records.length; index++) {
    const record = records[index] as CalendarProviderRecord;
    if (record['success'] === false || record['success'] === 'false' ||
      record['successful'] === false || record['successful'] === 'false') {
      return textOf(record['message']).trim().length > 0 ? textOf(record['message']) :
        'Provider explicitly reported failure.';
    }
    if (negativeCalendarStatus(textOf(record['status']))) {
      return 'Provider returned failure status: ' + textOf(record['status']);
    }
    const error = textOf(record['error']).trim();
    if (error.length > 0 && error !== 'null') {
      return error;
    }
  }
  return '';
}

function calendarDeleteConfirmed(payload: CalendarComposioPayload): boolean {
  const records = calendarProviderRecords(payload);
  for (let index = 0; index < records.length; index++) {
    const record = records[index] as CalendarProviderRecord;
    if (record['success'] === true || record['success'] === 'true' ||
      record['successful'] === true || record['successful'] === 'true') {
      return true;
    }
    const status = textOf(record['status']).trim().toLowerCase();
    if (status === 'success' || status === 'succeeded' || status === 'completed' ||
      status === 'ok' || status === 'deleted') {
      return true;
    }
  }
  return false;
}

export function calendarResultsFromComposioObservation(
  toolId: string,
  rawJson: string,
  args: CalendarEventArgs | null = null
): DynamicGenericToolResult[] {
  try {
    const payload = JSON.parse(rawJson) as CalendarComposioPayload;
    if (payload.error !== undefined && payload.error !== null && textOf(payload.error).trim().length > 0) {
      return composioCalendarResults([errorResult(toolId, 'Google Calendar 调用失败', textOf(payload.error))]);
    }
    if (payload.data === undefined || payload.data === null) {
      return composioCalendarResults([errorResult(toolId, 'Google Calendar 返回无效', 'Provider 未返回 data。')]);
    }
    const writeFailure = calendarWriteFailure(payload);
    if (toolId !== 'calendar.events.search' && writeFailure.length > 0) {
      return composioCalendarResults([errorResult(toolId, 'Google Calendar 调用失败', writeFailure)]);
    }
    if (toolId === 'calendar.events.search') {
      return composioCalendarResults(calendarEventResultsFromListPayload(JSON.stringify(payload.data), args));
    }
    if (toolId === 'calendar.event.create' || toolId === 'calendar.event.update') {
      const data = payload.data as CalendarComposioData;
      const item = data.response_data === undefined ? payload.data as CalendarEventPayload : data.response_data;
      if (textOf(item.id).trim().length === 0) {
        return composioCalendarResults([errorResult(toolId, 'Google Calendar 返回无效', 'Provider 未返回 Event ID。')]);
      }
      return composioCalendarResults([eventResult(toolId, item, toolId === 'calendar.event.create' ?
        '已直接写入真实 Google Calendar。' : '已直接更新真实 Google Calendar。')]);
    }
    if (toolId === 'calendar.event.delete') {
      if (!calendarDeleteConfirmed(payload)) {
        return composioCalendarResults([errorResult(
          toolId, 'Google Calendar 返回无效', 'Provider 未返回明确的删除成功状态。'
        )]);
      }
      const eventId = args === null ? '' : textOf(args.eventId).trim();
      return [{
        sourceTag: 'Composio Google Calendar',
        toolName: toolId,
        title: '日程已删除',
        status: 'success',
        summary: '已从真实 Google Calendar 删除日程。',
        rows: eventId.length > 0 ? [{ label: 'Event ID', value: eventId }] : [],
        rawPreview: rawJson.substring(0, 1200)
      }];
    }
    return composioCalendarResults([errorResult(toolId, '不支持的 Google Calendar 工具', toolId)]);
  } catch (error) {
    return composioCalendarResults([errorResult(toolId, 'Google Calendar 返回无效', error instanceof Error ? error.message : JSON.stringify(error))]);
  }
}

function calendarResultRow(result: DynamicGenericToolResult, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value;
    }
  }
  return '';
}

export function calendarDeleteTargetFromResultsForTest(results: DynamicGenericToolResult[]): CalendarEventArgs | null {
  if (results.length !== 1 || results[0].status !== 'success') {
    return null;
  }
  const eventId = calendarResultRow(results[0], 'Event ID').trim();
  if (eventId.length === 0) {
    return null;
  }
  return {
    eventId: eventId,
    title: results[0].title,
    start: calendarResultRow(results[0], 'Start'),
    end: calendarResultRow(results[0], 'End')
  };
}

export function calendarUpdateArgsFromResults(
  args: CalendarEventArgs,
  results: DynamicGenericToolResult[]
): CalendarEventArgs | null {
  const target = calendarDeleteTargetFromResultsForTest(results);
  if (target === null) {
    return null;
  }
  const updated = cloneCalendarArgs(args);
  updated.eventId = target.eventId;
  if (textOf(updated.title).trim().length === 0) {
    updated.title = target.title;
  }
  if (textOf(updated.start).trim().length === 0) {
    updated.start = target.start;
    updated.end = target.end;
  }
  if (textOf(updated.end).trim().length === 0 && isCalendarProviderDateTime(textOf(updated.start)) &&
    textOf(target.start).indexOf('T') >= 0 && textOf(target.end).indexOf('T') >= 0) {
    const duration = Date.parse(textOf(target.end)) - Date.parse(textOf(target.start));
    const wallStart = Date.parse(calendarProviderDateTime(textOf(updated.start)) + 'Z');
    if (duration > 0 && !Number.isNaN(wallStart)) {
      updated.end = new Date(wallStart + duration).toISOString().substring(0, 19);
    }
  }
  return updated;
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
  const needs: string[] = [];
  if (missing.indexOf('eventId') >= 0) {
    needs.push('请先查询并选择要修改的真实日程');
  }
  if (missing.indexOf('title') >= 0) {
    needs.push('请补充日程标题');
  }
  if (missing.indexOf('start') >= 0) {
    needs.push('请补充明确的开始时间');
  }
  if (missing.indexOf('end') >= 0) {
    needs.push('请补充明确的结束时间或时长');
  }
  return {
    sourceTag: 'Google Calendar API',
    toolName: toolId,
    title: '还需要补充日程信息',
    status: 'needs_input',
    summary: needs.join('；') + '。',
    rows: needs.map((value: string): A2uiLabelValueData => ({ label: '需要补充', value: value })),
    rawPreview: 'missing=' + missing.join(',')
  };
}

export function calendarUpdateNeedsInputResults(
  matches: DynamicGenericToolResult[],
  missing: string[]
): DynamicGenericToolResult[] {
  const results: DynamicGenericToolResult[] = [];
  matches.forEach((match: DynamicGenericToolResult) => results.push(match));
  results.push(calendarMissingArgsResult('calendar.event.update', missing));
  return results;
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
  const query = calendarSearchQueryText(args);
  const id = textOf(args.calendarId).trim();
  const url = urlWithParams(CALENDAR_API_BASE_URL + '/' + encodeParam(id.length > 0 ? id : 'primary') + '/events', [
    ['singleEvents', 'true'],
    ['orderBy', 'startTime'],
    ['q', query],
    ['timeMin', textOf(args.timeMin).trim()],
    ['timeMax', textOf(args.timeMax).trim()],
    ['maxResults', '10']
  ]);
  const payload = await requestJson(http.RequestMethod.GET, url, accessToken, null);
  return calendarEventResultsFromListPayload(JSON.stringify(payload), args);
}

async function findExistingCreateEvent(accessToken: string, args: CalendarEventArgs): Promise<CalendarEventPayload | null> {
  const title = textOf(args.title).trim();
  const start = textOf(args.start).trim();
  const end = textOf(args.end).trim();
  if (title.length === 0 || start.length === 0 || end.length === 0) {
    return null;
  }
  const url = urlWithParams(CALENDAR_API_BASE_URL + '/' + encodeParam(calendarId(args)) + '/events', [
    ['singleEvents', 'true'],
    ['orderBy', 'startTime'],
    ['q', title],
    ['timeMin', start],
    ['timeMax', end],
    ['maxResults', '10']
  ]);
  const payload = await requestJson(http.RequestMethod.GET, url, accessToken, null);
  return calendarMatchingExistingEventFromListPayload(JSON.stringify(payload), args);
}

export async function callCalendarTool(toolId: string, prompt: string, accessToken: string, args: Object | null = null): Promise<DynamicGenericToolResult[]> {
  try {
    const eventArgs = normalizedCalendarArgsForPrompt(toolId, prompt, calendarArgs(args));
    const missing = calendarEventRequiredFields(toolId, eventArgs);
    if (missing.length > 0) {
      return [calendarMissingArgsResult(toolId, missing)];
    }
    const base = CALENDAR_API_BASE_URL + '/' + encodeParam(calendarId(eventArgs)) + '/events';
    if (toolId === 'calendar.events.search') {
      return await searchEvents(accessToken, prompt, eventArgs);
    }
    if (toolId === 'calendar.event.create') {
      try {
        const existing = await findExistingCreateEvent(accessToken, eventArgs);
        if (existing !== null) {
          return [eventResult(toolId, existing, '真实 Google Calendar 中已有同名同时间日程，本次避免重复写入。')];
        }
      } catch (error) {
        aiLogError('[AIPhone][CalendarApiExistingLookupError] error=' + (error instanceof Error ? error.message : JSON.stringify(error)).substring(0, 220));
      }
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
