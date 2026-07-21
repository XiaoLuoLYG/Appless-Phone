import { describe, expect, it } from '@ohos/hypium';
import {
  ActionArgsValidator,
  ActionCatalog,
  ActionOffer,
  ActionOfferContext,
  ActionValidationResult,
  A2uiApplyResult,
  A2uiComponent,
  A2uiEnvelope,
  A2uiSurfaceStore,
  ClientActionAuthorizer,
  CreateUiTaskPayload,
  DataResult,
  HotelDetailResult,
  HotelSearchResult,
  McpToolResultPayload,
  SurfaceActionAuthorizer,
  ToolDefinition,
  ToolDefinitionLookup,
  UiLayoutPlanner,
  parseHotelDetailRequest,
  parseHotelSearchRequest,
  normalizeHotelDetailResult,
  normalizeHotelSearchResult,
  parseA2uiJsonl,
  toolDefinitionForToolId
} from '@loop/agent-core';
import { RegisteredActionOfferResolver } from '../main/ets/pages/A2uiHome/agent/RegisteredActionOfferResolver';
import { StructuredToolUiRenderer } from '../main/ets/pages/A2uiHome/agent/StructuredToolUiRenderer';

type TestValue = Object | string | number | boolean | null | undefined;

class RegistryLookup implements ToolDefinitionLookup {
  find(toolId: string): ToolDefinition | null {
    return toolDefinitionForToolId(toolId);
  }
}

class AllowSurface implements SurfaceActionAuthorizer {
  allows(
    _conversationId: string,
    _turnId: string,
    _surfaceId: string,
    _actionId: string,
    _args: Object
  ): boolean {
    return true;
  }
}

class AllowClient implements ClientActionAuthorizer {
  allows(_actionId: string, _args: Object): boolean {
    return true;
  }
}

class TestArgsValidator implements ActionArgsValidator {
  deniedActionId: string = '';

  validate(actionId: string, _args: Object): ActionValidationResult {
    return actionId === this.deniedActionId ? {
      ok: false,
      code: 'TEST_DENIED',
      message: 'denied by test'
    } : { ok: true, code: '', message: '' };
  }
}

class RecordingPlanner implements UiLayoutPlanner {
  candidate: string | null = null;
  prompt: string = '';
  throwError: boolean = false;
  hang: boolean = false;

  async plan(task: string, _surfaceId: string): Promise<string | null> {
    this.prompt = task;
    if (this.throwError) {
      throw new Error('layout failed');
    }
    if (this.hang) {
      return new Promise<string | null>((_resolve: (value: string | null) => void) => {
      });
    }
    return this.candidate;
  }
}

interface HotelSearchArgsFixture {
  originQuery: string;
  place: string;
  placeType: string;
  countryCode: string;
  checkInDate: string;
  stayNights: number;
  adultCount: number;
  childCount: number;
  childAgeDetails: number[];
  roomCount: number;
  currency: string;
  size: number;
}

interface HotelDetailArgsFixture {
  hotelId: number;
  checkInDate: string;
  checkOutDate: string;
  countryCode: string;
  currency: string;
  adultCount: number;
  childCount: number;
  childAgeDetails: number[];
  roomCount: number;
}

function object(json: string): Object {
  return JSON.parse(json) as Object;
}

function dataResult(toolId: string, outputSchema: string, data: Object): DataResult {
  return {
    toolId,
    outputSchema,
    status: 'success',
    sources: [],
    data,
    warnings: []
  };
}

function uiTask(dataTaskIds: string[] = ['data-1']): CreateUiTaskPayload {
  return {
    taskId: 'ui-1',
    dataTaskIds: dataTaskIds.slice(),
    skillId: '',
    intent: 'show structured results',
    expectedOutputSchema: 'structured'
  };
}

function offerContext(dataTaskId: string = 'data-1'): ActionOfferContext {
  return {
    conversationId: 'conversation-1',
    turnId: 'turn-1',
    dataTaskId
  };
}

function catalog(validator: TestArgsValidator = new TestArgsValidator()): ActionCatalog {
  return new ActionCatalog(
    new RegistryLookup(),
    new AllowSurface(),
    new AllowClient(),
    validator
  );
}

function hotelSearchResult(): HotelSearchResult {
  const args: HotelSearchArgsFixture = {
    originQuery: '深圳酒店',
    place: '深圳',
    placeType: 'CITY',
    countryCode: 'CN',
    checkInDate: '2026-08-15',
    stayNights: 2,
    adultCount: 2,
    childCount: 0,
    childAgeDetails: [],
    roomCount: 1,
    currency: 'CNY',
    size: 10
  };
  const request = parseHotelSearchRequest(args);
  if (request.value === null) {
    throw new Error(request.error);
  }
  const payload: McpToolResultPayload = {
    isError: false,
    structuredContent: object(
      '{"success":true,"message":"ok","hotelInformationList":[{"hotelId":47675,' +
      '"bookingUrl":"https://rollinggo.cn/hotel/47675","name":"深圳测试酒店","nameEn":"Test Hotel",' +
      '"address":"深圳市南山区","destinationId":"6046792","latitude":22.5,"longitude":114,' +
      '"starRating":5,"price":{"message":"2 晚参考价","hasPrice":true,"currency":"CNY",' +
      '"lowestPrice":1100},"imageUrl":"https://img.example/hotel.jpg"}]}'
    )
  };
  return normalizeHotelSearchResult(payload, request.value);
}

function hotelDetailResult(): HotelDetailResult {
  const args: HotelDetailArgsFixture = {
    hotelId: 47675,
    checkInDate: '2026-08-15',
    checkOutDate: '2026-08-17',
    countryCode: 'CN',
    currency: 'CNY',
    adultCount: 2,
    childCount: 0,
    childAgeDetails: [],
    roomCount: 1
  };
  const request = parseHotelDetailRequest(args);
  if (request.value === null) {
    throw new Error(request.error);
  }
  const payload: McpToolResultPayload = {
    isError: false,
    structuredContent: object(
      '{"success":true,"hotelId":47675,"bookingUrl":' +
      '"https://rollinggo.cn/pages/hotel/detail/index?id=47675&checkInDate=2026-08-15&' +
      'checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0",' +
      '"name":"深圳测试酒店","checkIn":"2026-08-15","checkOut":"2026-08-17",' +
      '"roomRatePlans":[{"roomName":"大床房","ratePlanId":"rate-1","ratePlanName":"可取消",' +
      '"averagePrice":550,"currency":"CNY","cancelPolicy":"入住前免费取消"}]}'
    )
  };
  return normalizeHotelDetailResult(payload, request.value);
}

function genericResult(
  toolName: string,
  title: string,
  rowsJson: string,
  actionsJson: string = '[]',
  rawPreview: string = ''
): Object {
  return object(
    '{"results":[{"sourceTag":"fixture","toolName":' + JSON.stringify(toolName) + ',' +
    '"title":' + JSON.stringify(title) + ',"status":"success","summary":"fixture summary",' +
    '"rows":' + rowsJson + ',"rawPreview":' + JSON.stringify(rawPreview) + ',' +
    '"actions":' + actionsJson + '}]}'
  );
}

function actionById(offers: ActionOffer[], actionId: string): ActionOffer | null {
  for (let index = 0; index < offers.length; index++) {
    if (offers[index].actionId === actionId) {
      return offers[index];
    }
  }
  return null;
}

function field(args: Object, key: string): TestValue {
  return (args as Record<string, TestValue>)[key];
}

function layoutCandidate(surfaceId: string, offerId: string): string {
  return '{"version":"v0.9.1","updateComponents":{"surfaceId":' + JSON.stringify(surfaceId) +
    ',"components":[{"id":"root","component":"SurfaceRoot","children":["results","actions"]},' +
    '{"id":"results","component":"GenericToolResults","dataPath":"/genericToolResults"},' +
    '{"id":"actions","component":"ActionBar","actions":[{"offerId":' + JSON.stringify(offerId) +
    '}]}]}}';
}

export default function structuredToolUiRendererTest() {
  describe('structuredToolUiRenderer', () => {
    it('uses a domain-neutral skeleton before structured results arrive', 0, async () => {
      const rendered = await new StructuredToolUiRenderer().skeleton(uiTask(), 'surface-pending');

      expect(rendered.jsonl.indexOf('酒店')).assertEqual(-1);
      expect(rendered.jsonl.indexOf('RollingGo')).assertEqual(-1);
      expect(rendered.jsonl.indexOf('structured_results')).assertLarger(-1);
    });

    it('dispatches every structured Data family to its canonical semantic rows', 0, async () => {
      const renderer = new StructuredToolUiRenderer();
      const fixtures: DataResult[] = [
        dataResult('travel.search', 'travelOptions', object(
          '{"title":"综合出行","body":"真实结果","summary":"1 option","options":[{"id":"travel-1",' +
          '"source":"铁路","sourceTag":"12306","title":"G1","from":"北京","to":"上海",' +
          '"depart":"08:00","arrive":"12:30","duration":"4h30m","price":"553 CNY",' +
          '"availability":"有票","status":"success","detail":"二等座"}],"rows":[]}'
        )),
        dataResult('train.search', 'trains', object(
          '{"title":"高铁","body":"真实车次","summary":"1 train","trains":[{"trainCode":"G1",' +
          '"from":"北京南","to":"上海虹桥","depart":"08:00","arrive":"12:30","duration":"4h30m",' +
          '"seats":"有票","status":"success","business":"--","first":"--","second":"有票",' +
          '"noSeat":"--","hardSeat":"--","sleeperSoft":"--"}]}'
        )),
        dataResult('flight.search', 'flights', object(
          '{"title":"航班","body":"真实航班","summary":"1 flight","flights":[{"flightNo":"CA123",' +
          '"airline":"国航","dep":"PEK","arr":"SHA","depTime":"09:00","arrTime":"11:20",' +
          '"status":"计划","price":"1200 CNY"}]}'
        )),
        dataResult('food.search', 'foodChoices', object(
          '{"title":"餐饮","body":"真实门店","summary":"1 store","foods":[{"name":"测试咖啡",' +
          '"category":"咖啡","address":"南山区","distance":"300m"}],"rows":[]}'
        )),
        dataResult('hotel.search', 'hotelSearchResults', hotelSearchResult() as Object),
        dataResult('hotel.detail', 'hotelRatePlans', hotelDetailResult() as Object),
        dataResult('maps.place.search', 'places', object(
          '{"places":[{"placeId":"place-1","title":"深圳湾","address":"南山区","rating":"4.8",' +
          '"mapLocation":"22.5,113.9","openNow":"true","mapsUrl":"https://maps.google.com/place-1"}],' +
          '"query":"深圳湾"}'
        )),
        dataResult('maps.place.details', 'place', object(
          '{"places":[{"placeId":"place-1","title":"深圳湾","address":"南山区","rating":"4.8",' +
          '"mapLocation":"22.5,113.9","openNow":"true","mapsUrl":"https://maps.google.com/place-1"}],' +
          '"query":"place-1"}'
        )),
        dataResult('media.video.search', 'mediaVideos', genericResult(
          'media.video.search', '视频', '[{"label":"Watch URL","value":"https://youtu.be/video-1"}]'
        )),
        dataResult('youtube.video.search', 'youtubeVideos', genericResult(
          'youtube.video.search', 'YouTube', '[{"label":"Video ID","value":"video-1"}]'
        )),
        dataResult('media.aggregate.search', 'aggregateSearch', object(
          '{"query":"AI","videos":[],"posts":[{"id":"post-1","source":"x","provider":"X",' +
          '"title":"AI post","author":"Alice","handle":"@alice","text":"real post","url":"https://x.com/1",' +
          '"publishedAt":"2026-07-22","score":"1","commentCount":"0","status":"success","rows":[]}],' +
          '"sourceStatuses":[],"summary":"1 post"}'
        )),
        dataResult('social.feed.search', 'socialHubFeed', object(
          '{"items":[{"id":"item-1","platform":"slack","kind":"message","author":"Alice",' +
          '"handle":"alice","text":"hello","timestamp":"2026-07-22T00:00:00Z","url":"",' +
          '"mediaUrl":"","channel":"general","channelId":"C1","threadId":"T1","unread":true}],' +
          '"connections":[{"platform":"slack","status":"connected","displayName":"Slack",' +
          '"accountId":"A1","message":"connected"}]}'
        )),
        dataResult('mail.search', 'mailThreads', object(
          '{"threads":[{"provider":"qq","accountLabel":"work","threadId":"thread-qq",' +
          '"messageId":"message-qq","subject":"QQ subject","from":"alice@example.com",' +
          '"to":["me@example.com"],"participants":[],"snippet":"summary","receivedAt":"2026-07-22",' +
          '"unread":true,"important":false,"sourceUrl":"","rawProviderRef":"ref","requestKey":"qq:message-qq"}],' +
          '"statuses":[],"extras":[]}'
        )),
        dataResult('gmail.mail.search', 'mailThreads', object(
          '{"threads":[{"provider":"gmail","accountLabel":"work","threadId":"thread-gmail",' +
          '"messageId":"message-gmail","subject":"Gmail subject","from":"alice@example.com",' +
          '"to":["me@example.com"],"participants":[],"snippet":"summary","receivedAt":"2026-07-22",' +
          '"unread":true,"important":false,"sourceUrl":"","rawProviderRef":"ref",' +
          '"requestKey":"gmail:thread-gmail"}],"statuses":[],"extras":[]}'
        )),
        dataResult('mail.thread.read', 'mailThread', object(
          '{"requestKey":"qq:message-qq","provider":"qq","threadId":"thread-qq",' +
          '"messageId":"message-qq","internetMessageId":"internet-1","subject":"Full mail",' +
          '"from":"alice@example.com","replyTo":"alice@example.com","to":["me@example.com"],"cc":[],' +
          '"body":"full body","bodyHtml":""}'
        )),
        dataResult('youtube.mine.playlists', 'youtubePlaylists', genericResult(
          'youtube.mine.playlists', 'Playlist', '[{"label":"Playlist ID","value":"PL-real-1"}]'
        )),
        dataResult('youtube.mine.subscriptions', 'youtubeSubscriptions', genericResult(
          'youtube.mine.subscriptions', 'Subscription', '[{"label":"Channel ID","value":"channel-1"}]'
        )),
        dataResult('calendar.events.search', 'calendarEvents', genericResult(
          'calendar.events.search', 'Meeting', '[{"label":"Event ID","value":"event-1"}]'
        )),
        dataResult('luckin.order.status', 'genericToolResults', genericResult(
          'luckin.order.status', 'Order status', '[{"label":"Order ID","value":"order-1"}]'
        ))
      ];
      const markers: string[] = [
        'travelOptions', 'trains', 'flights', 'foods', '47675', 'rate-1', 'place-1', 'place-1',
        'media.video.search', 'youtube.video.search', 'real post', 'item-1', 'message-qq',
        'thread-gmail', 'full body', 'PL-real-1', 'channel-1', 'event-1', 'order-1'
      ];

      for (let index = 0; index < fixtures.length; index++) {
        const rendered = await renderer.result(uiTask(), [fixtures[index]], [], 'surface-' + index.toString());
        expect(rendered.jsonl.indexOf(markers[index])).assertLarger(-1);
        expect(rendered.jsonl.indexOf('"jsonl"')).assertEqual(-1);
      }
    });

    it('combines reverse-arrival ordered travel and train results on one surface', 0, async () => {
      const renderer = new StructuredToolUiRenderer();
      const travel = dataResult('travel.search', 'travelOptions', object(
        '{"title":"旅行","body":"","summary":"travel first","options":[],"rows":[]}'
      ));
      const train = dataResult('train.search', 'trains', object(
        '{"title":"高铁","body":"","summary":"train second","trains":[]}'
      ));

      const rendered = await renderer.result(uiTask(['travel-data', 'train-data']), [travel, train], [], 'surface-multi');

      expect(rendered.jsonl.indexOf('travelOptions')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('trains')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('travelOptions') < rendered.jsonl.indexOf('trains')).assertTrue();
      expect(rendered.jsonl.split('"createSurface"').length - 1).assertEqual(1);
    });

    it('combines mail and calendar rows without dangling duplicate generic components', 0, async () => {
      const renderer = new StructuredToolUiRenderer();
      const mail = dataResult('mail.search', 'mailThreads', object(
        '{"threads":[{"provider":"qq","accountLabel":"work","threadId":"thread-qq",' +
        '"messageId":"message-qq","subject":"QQ subject","from":"alice@example.com","to":[],' +
        '"participants":[],"snippet":"summary","receivedAt":"2026-07-22","unread":true,' +
        '"important":false,"sourceUrl":"","rawProviderRef":"ref","requestKey":"qq:message-qq"}],' +
        '"statuses":[],"extras":[]}'
      ));
      const calendar = dataResult('calendar.events.search', 'calendarEvents', genericResult(
        'calendar.events.search', 'Meeting', '[{"label":"Event ID","value":"event-1"}]'
      ));

      const rendered = await renderer.result(
        uiTask(['mail-data', 'calendar-data']), [mail, calendar], [], 'surface-mail-calendar'
      );
      const parsed = parseA2uiJsonl(rendered.jsonl);
      const store = new A2uiSurfaceStore();
      const componentIds: Set<string> = new Set<string>();
      const referencedChildren: string[] = [];
      let applied = true;
      parsed.envelopes.forEach((envelope: A2uiEnvelope) => {
        const result: A2uiApplyResult = store.apply(envelope);
        applied = applied && result.ok;
        if (envelope.updateComponents !== undefined) {
          envelope.updateComponents.components.forEach((component: A2uiComponent) => {
            componentIds.add(component.id);
            if (component.children !== undefined) {
              component.children.forEach((childId: string) => referencedChildren.push(childId));
            }
          });
        }
      });
      let hasDanglingChild = false;
      referencedChildren.forEach((childId: string) => {
        hasDanglingChild = hasDanglingChild || !componentIds.has(childId);
      });

      expect(parsed.error).assertEqual('');
      expect(applied).assertTrue();
      expect(hasDanglingChild).assertFalse();
      expect(rendered.jsonl.indexOf('message-qq')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('event-1')).assertLarger(-1);
    });

    it('resolves only registered, catalog-approved offers with exact real-item args', 0, async () => {
      const resolver = new RegisteredActionOfferResolver(catalog());
      const search = dataResult('hotel.search', 'hotelSearchResults', hotelSearchResult() as Object);
      const detail = dataResult('hotel.detail', 'hotelRatePlans', hotelDetailResult() as Object);

      const searchOffers = await resolver.resolve(search, offerContext('hotel-search-data'));
      const detailOffers = await resolver.resolve(detail, offerContext('hotel-detail-data'));
      const openDetail = actionById(searchOffers, 'hotel.detail');
      const navigate = actionById(searchOffers, 'hotel.navigate');
      const booking = actionById(detailOffers, 'hotel.booking.open');

      expect(openDetail === null).assertFalse();
      expect(field((openDetail as ActionOffer).args, 'hotelId')).assertEqual(47675);
      expect(field((openDetail as ActionOffer).args, 'checkInDate')).assertEqual('2026-08-15');
      expect(field((openDetail as ActionOffer).args, 'adultCount')).assertEqual(2);
      expect(field((navigate as ActionOffer).args, 'latitude')).assertEqual(22.5);
      expect(field((navigate as ActionOffer).args, 'longitude')).assertEqual(114);
      expect(field((booking as ActionOffer).args, 'hotelId')).assertEqual(47675);
      expect(field((booking as ActionOffer).args, 'bookingUrl')).assertEqual(
        'https://rollinggo.cn/pages/hotel/detail/index?id=47675&checkInDate=2026-08-15&' +
        'checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0'
      );
    });

    it('keeps same-hotel offers on their registered source tool in aggregate rendering', 0, async () => {
      const resolver = new RegisteredActionOfferResolver(catalog());
      const search = dataResult('hotel.search', 'hotelSearchResults', hotelSearchResult() as Object);
      const detail = dataResult('hotel.detail', 'hotelRatePlans', hotelDetailResult() as Object);
      const searchOffers = await resolver.resolve(search, offerContext('hotel-search-data'));
      const detailOffers = await resolver.resolve(detail, offerContext('hotel-detail-data'));
      const offers: ActionOffer[] = searchOffers.concat(detailOffers);
      const renderer = new StructuredToolUiRenderer();

      const rendered = await renderer.result(
        uiTask(['hotel-search-data', 'hotel-detail-data']), [search, detail], offers, 'surface-hotels'
      );

      expect(rendered.jsonl.split('"id":"hotel.detail"').length - 1).assertEqual(1);
      expect(rendered.jsonl.split('"id":"hotel.navigate"').length - 1).assertEqual(1);
      expect(rendered.jsonl.split('"id":"hotel.booking.open"').length - 1).assertEqual(1);
    });

    it('fails closed to canonical placement when one layout spans multiple tool results', 0, async () => {
      const resolver = new RegisteredActionOfferResolver(catalog());
      const search = dataResult('hotel.search', 'hotelSearchResults', hotelSearchResult() as Object);
      const detail = dataResult('hotel.detail', 'hotelRatePlans', hotelDetailResult() as Object);
      const offers: ActionOffer[] = (await resolver.resolve(search, offerContext('hotel-search-data'))).concat(
        await resolver.resolve(detail, offerContext('hotel-detail-data'))
      );
      const baseline = await new StructuredToolUiRenderer().result(
        uiTask(['hotel-search-data', 'hotel-detail-data']), [search, detail], offers, 'surface-cross-tool'
      );
      const planner = new RecordingPlanner();
      const booking = actionById(offers, 'hotel.booking.open') as ActionOffer;
      planner.candidate = layoutCandidate('surface-cross-tool', booking.offerId);

      const rendered = await new StructuredToolUiRenderer(planner, 100).result(
        uiTask(['hotel-search-data', 'hotel-detail-data']), [search, detail], offers, 'surface-cross-tool'
      );

      expect(rendered.jsonl).assertEqual(baseline.jsonl);
    });

    it('rejects forged duplicated mutated cross-item and catalog-denied offers', 0, async () => {
      const validator = new TestArgsValidator();
      validator.deniedActionId = 'ride.open.amap';
      const resolver = new RegisteredActionOfferResolver(catalog(validator));
      const actions = '[{"id":"ride.open.didi","label":"打开滴滴","prompt":"diditaxi://ride?traceId=trace-1",' +
        '"variant":"primary","kind":"client","args":{"traceId":"trace-2","url":"diditaxi://ride?traceId=trace-2"}},' +
        '{"id":"ride.open.amap","label":"打开高德","prompt":"amapuri://drive/takeTaxi?traceId=trace-1",' +
        '"variant":"secondary","kind":"client","args":{"traceId":"trace-1","url":"amapuri://drive/takeTaxi?traceId=trace-1"}},' +
        '{"id":"ride.open.amap","label":"重复","prompt":"duplicate","variant":"secondary","kind":"client",' +
        '"args":{"traceId":"trace-1","url":"amapuri://drive/takeTaxi?traceId=trace-1"}},' +
        '{"id":"hotel.booking.open","label":"伪造","prompt":"forged","variant":"danger","kind":"prompt",' +
        '"args":{"hotelId":999}}]';
      const result = dataResult('ride.app.link', 'genericToolResults', genericResult(
        'ride.app.link', 'Ride link',
        '[{"label":"Trace ID","value":"trace-1"},{"label":"Didi URL","value":"diditaxi://ride?traceId=trace-1"},' +
        '{"label":"Amap URL","value":"amapuri://drive/takeTaxi?traceId=trace-1"}]',
        actions
      ));

      const offers = await resolver.resolve(result, offerContext('ride-data'));

      expect(offers.length).assertEqual(0);
    });

    it('bounds the number of real-field offers emitted from one result', 0, async () => {
      const rows: string[] = [];
      const actions: string[] = [];
      for (let index = 0; index < 80; index++) {
        const traceId = 'trace-' + index.toString();
        const url = 'diditaxi://ride?traceId=' + traceId;
        rows.push('{"label":"Trace","value":' + JSON.stringify(traceId) + '}',
          '{"label":"URL","value":' + JSON.stringify(url) + '}');
        actions.push('{"id":"ride.open.didi","label":"打开滴滴","prompt":"open",' +
          '"variant":"primary","kind":"client","args":{"traceId":' + JSON.stringify(traceId) +
          ',"url":' + JSON.stringify(url) + '}}');
      }
      const result = dataResult('ride.app.link', 'genericToolResults', genericResult(
        'ride.app.link', 'Ride links', '[' + rows.join(',') + ']', '[' + actions.join(',') + ']'
      ));

      const offers = await new RegisteredActionOfferResolver(catalog()).resolve(result, offerContext('ride-data'));

      expect(offers.length).assertEqual(64);
    });

    it('keeps mail and Gmail offer identity scoped to the exact data item and task', 0, async () => {
      const resolver = new RegisteredActionOfferResolver(catalog());
      const mail = dataResult('mail.search', 'mailThreads', object(
        '{"threads":[{"provider":"qq","accountLabel":"work","threadId":"thread-qq",' +
        '"messageId":"message-qq","subject":"QQ subject","from":"alice@example.com",' +
        '"to":[],"participants":[],"snippet":"summary","receivedAt":"2026-07-22","unread":true,' +
        '"important":false,"sourceUrl":"","rawProviderRef":"ref","requestKey":"qq:message-qq"}],' +
        '"statuses":[],"extras":[]}'
      ));
      const gmail = dataResult('gmail.mail.search', 'mailThreads', object(
        '{"threads":[{"provider":"gmail","accountLabel":"work","threadId":"thread-gmail",' +
        '"messageId":"message-gmail","subject":"Gmail subject","from":"alice@example.com",' +
        '"to":[],"participants":[],"snippet":"summary","receivedAt":"2026-07-22","unread":true,' +
        '"important":false,"sourceUrl":"","rawProviderRef":"ref","requestKey":"gmail:thread-gmail"}],' +
        '"statuses":[],"extras":[]}'
      ));

      const mailOffers = await resolver.resolve(mail, offerContext('mail-data'));
      const gmailOffers = await resolver.resolve(gmail, offerContext('gmail-data'));
      const mailRead = actionById(mailOffers, 'mail.thread.read') as ActionOffer;
      const gmailRead = actionById(gmailOffers, 'gmail.thread.read') as ActionOffer;

      expect(field(mailRead.args, 'requestKey')).assertEqual('qq:message-qq');
      expect(field(mailRead.args, 'messageId')).assertEqual('message-qq');
      expect(field(gmailRead.args, 'requestKey')).assertEqual('gmail:thread-gmail');
      expect(field(gmailRead.args, 'threadId')).assertEqual('thread-gmail');
      expect(mailRead.offerId === gmailRead.offerId).assertFalse();
      expect(mailRead.offerId.indexOf('mail-data')).assertLarger(-1);
      expect(gmailRead.offerId.indexOf('gmail-data')).assertLarger(-1);
    });

    it('binds accepted layout references back to immutable original offer args', 0, async () => {
      const resolver = new RegisteredActionOfferResolver(catalog());
      const data = dataResult('hotel.detail', 'hotelRatePlans', hotelDetailResult() as Object);
      const offers = await resolver.resolve(data, offerContext());
      const booking = actionById(offers, 'hotel.booking.open') as ActionOffer;
      const planner = new RecordingPlanner();
      planner.candidate = layoutCandidate('surface-layout', booking.offerId);
      const renderer = new StructuredToolUiRenderer(planner, 100);

      const rendered = await renderer.result(uiTask(), [data], offers, 'surface-layout');

      expect(rendered.jsonl.indexOf('"id":"hotel.booking.open"')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('"hotelId":47675')).assertLarger(-1);
      expect(rendered.jsonl.indexOf(
        '"bookingUrl":"https://rollinggo.cn/pages/hotel/detail/index?id=47675&checkInDate=2026-08-15&' +
        'checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0"'
      )).assertLarger(-1);
      expect(rendered.jsonl.indexOf('"offerId"')).assertEqual(-1);
      expect(planner.prompt.indexOf(booking.actionId)).assertEqual(-1);
      expect(planner.prompt.indexOf('bookingUrl')).assertEqual(-1);
      expect(planner.prompt.indexOf('47675')).assertEqual(-1);
    });

    it('falls back exactly on malformed duplicate unknown timeout and thrown layouts', 0, async () => {
      const resolver = new RegisteredActionOfferResolver(catalog());
      const data = dataResult('hotel.detail', 'hotelRatePlans', hotelDetailResult() as Object);
      const offers = await resolver.resolve(data, offerContext());
      const booking = actionById(offers, 'hotel.booking.open') as ActionOffer;
      const baseline = await new StructuredToolUiRenderer().result(uiTask(), [data], offers, 'surface-fallback');
      const malformed = new RecordingPlanner();
      malformed.candidate = '{"invalid":true}';
      const duplicate = new RecordingPlanner();
      duplicate.candidate =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-fallback",' +
        '"components":[{"id":"root","component":"SurfaceRoot","children":["results","actions"]},' +
        '{"id":"results","component":"GenericToolResults","dataPath":"/genericToolResults"},' +
        '{"id":"actions","component":"ActionBar","actions":[{"offerId":' +
        JSON.stringify(booking.offerId) + '},{"offerId":' + JSON.stringify(booking.offerId) + '}]}]}}';
      const unknown = new RecordingPlanner();
      unknown.candidate = layoutCandidate('surface-fallback', 'forged-offer');
      const timeout = new RecordingPlanner();
      timeout.hang = true;
      const thrown = new RecordingPlanner();
      thrown.throwError = true;
      const oversized = new RecordingPlanner();
      oversized.candidate = 'x'.repeat(32769);
      const planners: RecordingPlanner[] = [malformed, duplicate, unknown, timeout, thrown, oversized];

      for (let index = 0; index < planners.length; index++) {
        const rendered = await new StructuredToolUiRenderer(planners[index], 1).result(
          uiTask(), [data], offers, 'surface-fallback'
        );
        expect(rendered.jsonl).assertEqual(baseline.jsonl);
      }
    });

    it('redacts and bounds layout prompts without provider secrets receipts or mail bodies', 0, async () => {
      const planner = new RecordingPlanner();
      planner.candidate = null;
      const renderer = new StructuredToolUiRenderer(planner, 100);
      const secret = 'provider-token-super-secret';
      const receipt = 'receipt-real-123';
      const body = 'private complete email body';
      const result = dataResult('gmail.thread.read', 'mailThread', object(
        '{"requestKey":"gmail:thread-1","provider":"gmail","threadId":"thread-1",' +
        '"messageId":"message-1","internetMessageId":"internet-1","subject":"Subject",' +
        '"from":"alice@example.com","replyTo":"alice@example.com","to":["me@example.com"],"cc":[],' +
        '"body":' + JSON.stringify(body) + ',"bodyHtml":""}'
      ));
      result.sources = [{
        provider: 'Gmail',
        backend: 'oauth_api',
        operation: 'users.threads.get',
        fetchedAt: '2026-07-22T00:00:00Z',
        receipt
      }];
      result.warnings = [secret];
      const task = uiTask();
      task.intent = 'show results with ' + secret;

      await renderer.result(task, [result], [], 'surface-redaction');

      expect(planner.prompt.length > 0).assertTrue();
      expect(planner.prompt.length <= 4096).assertTrue();
      expect(planner.prompt.indexOf(secret)).assertEqual(-1);
      expect(planner.prompt.indexOf(receipt)).assertEqual(-1);
      expect(planner.prompt.indexOf(body)).assertEqual(-1);
      expect(planner.prompt.indexOf('mailThread')).assertLarger(-1);
    });

    it('returns an honest error surface for unknown schema malformed data and renderer exceptions', 0, async () => {
      const renderer = new StructuredToolUiRenderer();
      const unknown = dataResult('unknown.read', 'unknownSchema', object('{"secret":"do not dump"}'));
      const malformed = dataResult('travel.search', 'travelOptions', object('{"unexpected":true}'));

      const unknownRendered = await renderer.result(uiTask(), [unknown], [], 'surface-unknown');
      const malformedRendered = await renderer.result(uiTask(), [malformed], [], 'surface-malformed');

      expect(unknownRendered.jsonl.indexOf('error')).assertLarger(-1);
      expect(unknownRendered.jsonl.indexOf('do not dump')).assertEqual(-1);
      expect(malformedRendered.jsonl.indexOf('error')).assertLarger(-1);
      expect(malformedRendered.jsonl.indexOf('unexpected')).assertEqual(-1);
    });
  });
}
