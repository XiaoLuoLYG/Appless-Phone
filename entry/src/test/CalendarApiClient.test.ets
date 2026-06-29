import { describe, it, expect } from '@ohos/hypium';
import {
  calendarCreateBody,
  calendarEventRequiredFields,
  calendarEventResultsFromListPayload,
  calendarMissingArgsResult,
  calendarUpdateBody
} from '../main/ets/model/CalendarApiClient';

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

    it('returns real missing-field errors instead of guessing dates', 0, () => {
      const missing = calendarEventRequiredFields('calendar.event.create', {
        title: 'AIPhoneDemo smoke'
      });
      const result = calendarMissingArgsResult('calendar.event.create', missing);
      expect(missing.join(',')).assertEqual('start,end');
      expect(result.status).assertEqual('error');
      expect(result.summary.indexOf('start')).assertLarger(-1);
      expect(result.summary.indexOf('end')).assertLarger(-1);
    });
  });
}
