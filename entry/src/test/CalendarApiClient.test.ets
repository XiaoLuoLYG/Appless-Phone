import { describe, it, expect } from '@ohos/hypium';
import {
  CalendarEventArgs,
  calendarEventMatchesArgs,
  calendarCreateBody,
  calendarEventRequiredFields,
  calendarResultsFromComposioObservation,
  calendarEventResultsFromListPayload,
  calendarMatchingExistingEventFromListPayload,
  calendarMissingArgsResult,
  calendarProviderDateTime,
  calendarSearchQueryText,
  calendarUpdateArgsFromResults,
  calendarUpdateNeedsInputResults,
  calendarUpdateBody,
  normalizedCalendarArgsForPrompt,
  remainingReadStructuredDataResult
} from '@loop/agent-core';

export default function calendarApiClientTest() {
  describe('calendarApiClient', () => {
    it('maps list payload into generic results', 0, () => {
      const payload = '{"items":[{"id":"event-123","summary":"AIPhoneDemo smoke","start":{"dateTime":"2026-06-30T15:00:00+08:00"},"end":{"dateTime":"2026-06-30T15:30:00+08:00"},"htmlLink":"https://calendar.google.com/event?eid=123"}]}';
      const results = calendarEventResultsFromListPayload(payload);
      expect(results.length).assertEqual(1);
      expect(results[0].toolName).assertEqual('calendar.events.search');
      expect(results[0].title).assertEqual('AIPhoneDemo smoke');
      expect(results[0].rows[0].value).assertEqual('event-123');
    });

    it('builds create and update bodies from structured args', 0, () => {
      const create = calendarCreateBody({
        title: 'AIPhoneDemo smoke',
        start: '2026-06-30T15:00:00+08:00',
        end: '2026-06-30T15:30:00+08:00',
        timezone: 'Asia/Shanghai'
      });
      const update = calendarUpdateBody({
        eventId: 'event-123',
        title: 'AIPhoneDemo smoke',
        start: '2026-06-30T16:00:00+08:00',
        end: '2026-06-30T16:30:00+08:00',
        timezone: 'Asia/Shanghai'
      });

      expect(JSON.stringify(create).indexOf('"summary":"AIPhoneDemo smoke"')).assertLarger(-1);
      expect(JSON.stringify(update).indexOf('"dateTime":"2026-06-30T16:00:00+08:00"')).assertLarger(-1);
    });

    it('keeps model-owned new values while resolving one real event for update', 0, () => {
      const matches = calendarEventResultsFromListPayload(
        '{"items":[{"id":"event-123","summary":"团队同步","start":{"dateTime":"2026-07-18T16:00:00+08:00"},"end":{"dateTime":"2026-07-18T16:30:00+08:00"}}]}'
      );
      const resolved = calendarUpdateArgsFromResults({
        query: '团队同步',
        timeMin: '2026-07-18T16:00:00+08:00',
        timeMax: '2026-07-18T17:00:00+08:00',
        start: '2026-07-18T16:30:00+08:00',
        end: '2026-07-18T17:00:00+08:00',
        timezone: 'Asia/Shanghai'
      }, matches) as CalendarEventArgs;

      expect(resolved.eventId).assertEqual('event-123');
      expect(resolved.title).assertEqual('团队同步');
      expect(resolved.start).assertEqual('2026-07-18T16:30:00+08:00');
      expect(resolved.end).assertEqual('2026-07-18T17:00:00+08:00');
    });

    it('keeps the real event duration when moving it to a new start time', 0, () => {
      const matches = calendarEventResultsFromListPayload(
        '{"items":[{"id":"event-123","summary":"团队同步","start":{"dateTime":"2026-07-18T16:00:00+08:00"},"end":{"dateTime":"2026-07-18T16:30:00+08:00"}}]}'
      );
      const resolved = calendarUpdateArgsFromResults({
        query: '团队同步',
        timeMin: '2026-07-18T12:00:00+08:00',
        timeMax: '2026-07-18T18:00:00+08:00',
        start: '2026-07-18T09:00:00',
        end: '',
        timezone: 'Asia/Shanghai'
      }, matches) as CalendarEventArgs;

      expect(resolved.eventId).assertEqual('event-123');
      expect(resolved.start).assertEqual('2026-07-18T09:00:00');
      expect(resolved.end).assertEqual('2026-07-18T09:30:00');
    });

    it('does not guess an eventId when a Calendar selector is ambiguous', 0, () => {
      const matches = calendarEventResultsFromListPayload(
        '{"items":[' +
        '{"id":"event-real-1","summary":"团队同步","start":{"dateTime":"2026-07-18T16:00:00+08:00"},"end":{"dateTime":"2026-07-18T16:30:00+08:00"}},' +
        '{"id":"event-real-2","summary":"团队同步","start":{"dateTime":"2026-07-18T17:00:00+08:00"},"end":{"dateTime":"2026-07-18T17:30:00+08:00"}}]}'
      );
      const resolved = calendarUpdateArgsFromResults({
        query: '团队同步',
        timeMin: '2026-07-18T15:00:00+08:00',
        timeMax: '2026-07-18T18:00:00+08:00',
        start: '2026-07-18T19:00:00+08:00',
        end: '2026-07-18T19:30:00+08:00'
      }, matches);

      expect(resolved).assertNull();
      expect(calendarEventRequiredFields('calendar.event.update', {
        title: '团队同步',
        start: '2026-07-18T19:00:00+08:00',
        end: '2026-07-18T19:30:00+08:00'
      }).indexOf('eventId')).assertLarger(-1);
    });

    it('keeps the resolved real event visible while asking for a missing destination time', 0, () => {
      const matches = calendarEventResultsFromListPayload(
        '{"items":[{"id":"event-123","summary":"团队同步","start":{"dateTime":"2026-07-18T16:00:00+08:00"},"end":{"dateTime":"2026-07-18T16:30:00+08:00"}}]}'
      );
      const results = calendarUpdateNeedsInputResults(matches, ['start', 'end']);

      expect(results.length).assertEqual(2);
      expect(results[0].title).assertEqual('团队同步');
      expect(results[1].status).assertEqual('needs_input');
      expect(results[1].summary.indexOf('开始时间')).assertLarger(-1);
    });

    it('preserves model-owned wall time when adapting to the Composio Calendar schema', 0, () => {
      expect(calendarProviderDateTime('2026-07-17T15:00:00+08:00')).assertEqual('2026-07-17T15:00:00');
      expect(calendarProviderDateTime('2026-07-17T15:30+08:00')).assertEqual('2026-07-17T15:30');
    });

    it('returns real missing-field errors instead of guessing dates', 0, () => {
      const missing = calendarEventRequiredFields('calendar.event.create', {
        title: 'AIPhoneDemo smoke'
      });
      const result = calendarMissingArgsResult('calendar.event.create', missing);
      expect(missing.join(',')).assertEqual('start,end');
      expect(result.status).assertEqual('needs_input');
      expect(result.summary.indexOf('开始时间')).assertLarger(-1);
      expect(result.summary.indexOf('结束时间')).assertLarger(-1);
    });

    it('rejects natural-language timestamps before the Calendar Provider call', 0, () => {
      const missing = calendarEventRequiredFields('calendar.event.create', {
        title: 'CalendarCRUDQA-C-20260716',
        start: '明天 15:00',
        end: '明天 15:30',
        timezone: 'Asia/Shanghai'
      });
      const result = calendarMissingArgsResult('calendar.event.create', missing);

      expect(missing.join(',')).assertEqual('start,end');
      expect(result.status).assertEqual('needs_input');
      expect(result.summary.indexOf('明确')).assertLarger(-1);
    });

    it('does not use the whole prompt as the Calendar search query', 0, () => {
      expect(calendarSearchQueryText({})).assertEqual('');
      expect(calendarSearchQueryText({ query: '产品同步' })).assertEqual('产品同步');
    });

    it('keeps the requested window on empty search results', 0, () => {
      const results = calendarEventResultsFromListPayload('{"items":[]}', {
        timeMin: '2026-07-02T00:00:00+08:00',
        timeMax: '2026-07-03T00:00:00+08:00'
      });

      expect(results.length).assertEqual(1);
      expect(results[0].title).assertEqual('没有找到日程');
      expect(results[0].rows[0].label).assertEqual('Window Start');
      expect(results[0].rows[0].value).assertEqual('2026-07-02T00:00:00+08:00');
      expect(results[0].rows[1].label).assertEqual('Window End');
      expect(results[0].rows[1].value).assertEqual('2026-07-03T00:00:00+08:00');
    });

    it('detects an existing event before creating a duplicate', 0, () => {
      const args: CalendarEventArgs = {
        title: '一对一会议',
        start: '2026-07-02T16:30:00+08:00',
        end: '2026-07-02T17:00:00+08:00'
      };
      const payload = '{"items":[{"id":"existing-1","summary":"一对一会议","start":{"dateTime":"2026-07-02T16:30:00+08:00"},"end":{"dateTime":"2026-07-02T17:00:00+08:00"}}]}';
      const existing = calendarMatchingExistingEventFromListPayload(payload, args);

      expect(existing === null).assertFalse();
      if (existing !== null) {
        expect(existing.id).assertEqual('existing-1');
        expect(calendarEventMatchesArgs(existing, args)).assertTrue();
      }
    });

    it('normalizes stale model dates for relative search prompts', 0, () => {
      const args: CalendarEventArgs = normalizedCalendarArgsForPrompt('calendar.events.search', '帮我查看我明天的google calendar日程', {
        timeMin: '2023-10-05T00:00:00+08:00',
        timeMax: '2023-10-06T00:00:00+08:00',
        timezone: 'Asia/Shanghai',
        calendarId: 'primary'
      }, new Date('2026-07-01T09:00:00+08:00'));

      expect(args.timeMin).assertEqual('2026-07-02T00:00:00+08:00');
      expect(args.timeMax).assertEqual('2026-07-03T00:00:00+08:00');
      expect(args.calendarId).assertEqual('primary');
    });

    it('keeps a valid sub-day window on the requested relative day', 0, () => {
      const args: CalendarEventArgs = normalizedCalendarArgsForPrompt('calendar.events.search',
        '查看我明天下午的 Google Calendar 日程', {
          timeMin: '2026-07-18T12:00:00+08:00',
          timeMax: '2026-07-18T18:00:00+08:00',
          timezone: 'Asia/Shanghai'
        }, new Date('2026-07-17T10:00:00+08:00'));

      expect(args.timeMin).assertEqual('2026-07-18T12:00:00+08:00');
      expect(args.timeMax).assertEqual('2026-07-18T18:00:00+08:00');
    });

    it('normalizes an absolute date argument into an exact search window', 0, () => {
      const args: CalendarEventArgs = normalizedCalendarArgsForPrompt('calendar.events.search',
        '查看我 2026年7月31日的 Google Calendar 日程', {
          date: '2026-07-31',
          calendarId: 'primary'
        }, new Date('2026-07-16T09:00:00+08:00'));

      expect(args.timeMin).assertEqual('2026-07-31T00:00:00+08:00');
      expect(args.timeMax).assertEqual('2026-08-01T00:00:00+08:00');
      expect(args.timezone).assertEqual('Asia/Shanghai');
    });

    it('maps nested Composio Calendar payloads into real event cards', 0, () => {
      const observation = '{"data":{"items":[{"id":"event-composio-1","summary":"AIPhoneDemo 真机测试","start":{"dateTime":"2026-07-31T15:00:00+08:00"},"end":{"dateTime":"2026-07-31T15:30:00+08:00"},"htmlLink":"https://calendar.google.com/event?eid=1"}]},"error":null}';
      const results = calendarResultsFromComposioObservation('calendar.events.search', observation, {
        timeMin: '2026-07-31T00:00:00+08:00',
        timeMax: '2026-08-01T00:00:00+08:00'
      });

      expect(results.length).assertEqual(1);
      expect(results[0].title).assertEqual('AIPhoneDemo 真机测试');
      expect(results[0].sourceTag).assertEqual('Composio Google Calendar');
      expect(results[0].rows[0].value).assertEqual('event-composio-1');
      expect(results[0].rows[1].value).assertEqual('2026-07-31T15:00:00+08:00');
    });

    it('preserves real Calendar event IDs in structured data without rendered envelopes', 0, () => {
      const observation = '{"data":{"items":[{"id":"event-structured-real-1","summary":"Structured QA",' +
        '"start":{"dateTime":"2026-07-31T15:00:00+08:00"},' +
        '"end":{"dateTime":"2026-07-31T15:30:00+08:00"}}]},"error":null}';
      const provider = calendarResultsFromComposioObservation('calendar.events.search', observation);
      provider[0].providerPhase = 'execution';
      const structured = remainingReadStructuredDataResult(
        'calendar.events.search', 'calendarEvents', provider
      );
      const serialized = JSON.stringify(structured.data);

      expect(structured.status).assertEqual('success');
      expect(serialized.indexOf('event-structured-real-1')).assertLarger(-1);
      expect(serialized.indexOf('updateComponents')).assertEqual(-1);
      expect(serialized.indexOf('createSurface')).assertEqual(-1);
      expect(serialized.indexOf('jsonl')).assertEqual(-1);
    });

    it('separates Calendar missing auth successful empty and inner provider error', 0, () => {
      const auth = remainingReadStructuredDataResult('calendar.events.search', 'calendarEvents', [{
        sourceTag: 'Composio Google Calendar', toolName: 'calendar.events.search', title: 'Composio 未配置',
        status: 'needs_auth', summary: 'Google Calendar OAuth 未授权。', rows: [], rawPreview: ''
      }]);
      const emptyProvider = calendarEventResultsFromListPayload('{"items":[]}');
      emptyProvider[0].providerPhase = 'execution';
      const empty = remainingReadStructuredDataResult('calendar.events.search', 'calendarEvents', emptyProvider);
      const inner = calendarResultsFromComposioObservation(
        'calendar.events.search', '{"data":null,"error":"calendar backend unavailable"}'
      );
      inner[0].providerPhase = 'execution';
      const error = remainingReadStructuredDataResult('calendar.events.search', 'calendarEvents', inner);

      expect(auth.error?.code).assertEqual('AUTH_REQUIRED');
      expect(auth.sources.length).assertEqual(0);
      expect(empty.status).assertEqual('empty');
      expect(empty.sources.length).assertEqual(1);
      expect(error.error?.code).assertEqual('PROVIDER_ERROR');
      expect(error.error?.message.indexOf('calendar backend unavailable')).assertLarger(-1);
      expect(error.sources.length).assertEqual(1);
    });

    it('maps a Composio Calendar create payload into a visible confirmation event', 0, () => {
      const observation = '{"data":{"id":"event-created-1","summary":"AIPhoneDemo 创建测试","start":{"dateTime":"2026-08-01T15:00:00+08:00"},"end":{"dateTime":"2026-08-01T15:30:00+08:00"},"htmlLink":"https://calendar.google.com/event?eid=2"},"error":null}';
      const results = calendarResultsFromComposioObservation('calendar.event.create', observation);

      expect(results.length).assertEqual(1);
      expect(results[0].toolName).assertEqual('calendar.event.create');
      expect(results[0].title).assertEqual('AIPhoneDemo 创建测试');
      expect(results[0].rows[0].value).assertEqual('event-created-1');
      expect(results[0].summary.indexOf('已直接写入')).assertLarger(-1);
    });

    it('unwraps the real Composio create response_data payload', 0, () => {
      const observation = '{"data":{"composio_execution_message":null,"display_url":"https://calendar.google.com/event?eid=3","response_data":{"id":"event-created-real","summary":"AIPhoneDemo Calendar 修复验证","start":{"dateTime":"2026-08-01T15:00:00+08:00","timeZone":"Asia/Shanghai"},"end":{"dateTime":"2026-08-01T15:30:00+08:00","timeZone":"Asia/Shanghai"},"htmlLink":"https://calendar.google.com/event?eid=3"}},"error":null}';
      const results = calendarResultsFromComposioObservation('calendar.event.create', observation);

      expect(results.length).assertEqual(1);
      expect(results[0].title).assertEqual('AIPhoneDemo Calendar 修复验证');
      expect(results[0].rows[0].value).assertEqual('event-created-real');
      expect(results[0].rows[1].value).assertEqual('2026-08-01T15:00:00+08:00');
      expect(results[0].status).assertEqual('success');
    });

    it('fails Calendar writes closed on nested negative provider truth', 0, () => {
      const create = calendarResultsFromComposioObservation(
        'calendar.event.create',
        '{"data":{"successful":false,"response_data":{"id":"event-fake"}},"error":null}'
      );
      const update = calendarResultsFromComposioObservation(
        'calendar.event.update',
        '{"data":{"response_data":{"success":false,"id":"event-fake"}},"error":null}'
      );
      const remove = calendarResultsFromComposioObservation(
        'calendar.event.delete',
        '{"data":{"response_data":{"status":"delete_failed"}},"error":null}',
        { eventId: 'event-request-only', calendarId: 'primary' }
      );

      expect(create[0].status).assertEqual('error');
      expect(update[0].status).assertEqual('error');
      expect(remove[0].status).assertEqual('error');
      expect(JSON.stringify(remove[0].rows).indexOf('event-request-only')).assertEqual(-1);
    });

    it('requires positive provider evidence before returning Calendar delete success', 0, () => {
      const missing = calendarResultsFromComposioObservation(
        'calendar.event.delete', '{"data":{},"error":null}',
        { eventId: 'event-request-only', calendarId: 'primary' }
      );
      const positive = calendarResultsFromComposioObservation(
        'calendar.event.delete', '{"data":{"successful":true},"error":null}',
        { eventId: 'event-provider-confirmed', calendarId: 'primary' }
      );

      expect(missing[0].status).assertEqual('error');
      expect(positive[0].status).assertEqual('success');
      expect(positive[0].rows[0].value).assertEqual('event-provider-confirmed');
    });

    it('normalizes current week search prompts before calling Calendar', 0, () => {
      const args: CalendarEventArgs = normalizedCalendarArgsForPrompt('calendar.events.search', '帮我查看我本周的calendar日程', {
        timeRange: 'this week',
        timezone: 'Asia/Shanghai',
        calendarId: 'primary'
      }, new Date('2026-07-07T09:00:00+08:00'));

      expect(args.timeMin).assertEqual('2026-07-06T00:00:00+08:00');
      expect(args.timeMax).assertEqual('2026-07-13T00:00:00+08:00');
      expect(args.calendarId).assertEqual('primary');
    });

    it('replaces model timezone placeholders with a valid IANA timezone', 0, () => {
      const args: CalendarEventArgs = normalizedCalendarArgsForPrompt('calendar.events.search',
        '帮我看本月的 Google Calendar 日程', {
          timeMin: '本月开始',
          timeMax: '本月结束',
          timezone: '用户时区',
          calendarId: 'primary'
        }, new Date('2026-07-16T09:00:00+08:00'));

      expect(args.timezone).assertEqual('Asia/Shanghai');
      expect(args.timeMin).assertEqual('2026-07-01T00:00:00+08:00');
      expect(args.timeMax).assertEqual('2026-08-01T00:00:00+08:00');
    });

    it('parses the documented Calendar create prompt through the shared normalizer', 0, () => {
      const args: CalendarEventArgs = normalizedCalendarArgsForPrompt(
        'calendar.event.create',
        '帮我在 2026年7月30日下午3点创建一个title为AIPhoneDemo的30分钟日程',
        {},
        new Date('2026-07-22T09:00:00+08:00'),
        true
      );

      expect(args.title).assertEqual('AIPhoneDemo');
      expect(args.start).assertEqual('2026-07-30T15:00:00+08:00');
      expect(args.end).assertEqual('2026-07-30T15:30:00+08:00');
      expect(args.timezone).assertEqual('Asia/Shanghai');
      expect(args.calendarId).assertEqual('primary');
    });

    it('parses an unlabeled relative create prompt but rejects a missing explicit time', 0, () => {
      const exact = normalizedCalendarArgsForPrompt(
        'calendar.event.create',
        '明天下午3点帮我创建一个30分钟的产品评审日程',
        {},
        new Date('2026-07-22T09:00:00+08:00'),
        true
      );
      const vague = normalizedCalendarArgsForPrompt(
        'calendar.event.create',
        '明天下午帮我创建标题为产品评审的日程',
        {},
        new Date('2026-07-22T09:00:00+08:00'),
        true
      );

      expect(exact.title).assertEqual('产品评审');
      expect(exact.start).assertEqual('2026-07-23T15:00:00+08:00');
      expect(exact.end).assertEqual('2026-07-23T15:30:00+08:00');
      expect(calendarEventRequiredFields('calendar.event.create', vague).join(','))
        .assertEqual('start,end');
    });

    it('parses documented and common Calendar updates without accepting an eventId', 0, () => {
      const documented = normalizedCalendarArgsForPrompt(
        'calendar.event.update',
        '把 2026年7月30日 的 Appless QA run-1 日程改到下午4点',
        { eventId: 'user-forged' },
        new Date('2026-07-22T09:00:00+08:00'),
        true
      );
      const renamed = normalizedCalendarArgsForPrompt(
        'calendar.event.update',
        '把明天下午的产品评审日程改名为产品终审并改到上午9点',
        {},
        new Date('2026-07-22T09:00:00+08:00'),
        true
      );
      const vague = normalizedCalendarArgsForPrompt(
        'calendar.event.update',
        '把明天下午的产品评审日程移到上午',
        {},
        new Date('2026-07-22T09:00:00+08:00'),
        true
      );

      expect(documented.eventId).assertEqual('');
      expect(documented.query).assertEqual('Appless QA run-1');
      expect(documented.timeMin).assertEqual('2026-07-30T00:00:00+08:00');
      expect(documented.timeMax).assertEqual('2026-07-31T00:00:00+08:00');
      expect(documented.start).assertEqual('2026-07-30T16:00:00+08:00');
      expect(documented.end).assertEqual('');
      expect(renamed.query).assertEqual('产品评审');
      expect(renamed.title).assertEqual('产品终审');
      expect(renamed.start).assertEqual('2026-07-23T09:00:00+08:00');
      expect(vague.query).assertEqual('产品评审');
      expect(vague.start).assertEqual('');
    });
  });
}
