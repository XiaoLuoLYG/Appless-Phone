import { describe, expect, it } from '@ohos/hypium';
import {
  A2uiAction,
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
  DynamicGenericToolResult,
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
  rideResultsFromMcpPayloadsForTest,
  toolDefinitionForToolId
} from '@loop/agent-core';
import { RegisteredActionOfferResolver } from '../main/ets/pages/A2uiHome/agent/RegisteredActionOfferResolver';
import { StructuredToolUiRenderer } from '../main/ets/pages/A2uiHome/agent/StructuredToolUiRenderer';

type TestValue = Object | string | number | boolean | null | undefined;
type TestRecord = Record<string, TestValue>;

interface GenericResultsFixture {
  results: DynamicGenericToolResult[];
}

interface CalendarReviewFixture {
  results: DynamicGenericToolResult[];
  requestedAction: Object;
}

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
  rawPreview: string = '',
  summary: string = 'fixture summary'
): Object {
  return object(
    '{"results":[{"sourceTag":"fixture","toolName":' + JSON.stringify(toolName) + ',' +
    '"title":' + JSON.stringify(title) + ',"status":"success","summary":' + JSON.stringify(summary) + ',' +
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

function exactRideEstimateResult(): DataResult {
  const estimatePayload = object(
    '{"structuredContent":{"items":[{"productName":"快车","productCategory":"express",' +
    '"priceText":"约 48 元"},{"productName":"专车","productCategory":"premium",' +
    '"priceText":"约 88 元"}],"traceId":"trace-exact"}}'
  );
  const results = rideResultsFromMcpPayloadsForTest(
    '华为坂田基地',
    '秋港花园',
    estimatePayload,
    object('{"structuredContent":{"url":"diditaxi://ride?traceId=trace-exact"}}'),
    object('{"structuredContent":{"url":"amapuri://drive/takeTaxi?traceId=trace-exact"}}'),
    '114.066231,22.657805',
    '114.060432,22.548829'
  );
  const data: GenericResultsFixture = { results };
  return dataResult('ride.estimate', 'genericToolResults', data as Object);
}

function rideConfirmAction(result: DataResult, actionIndex: number = 0): A2uiAction {
  const generic = result.data as GenericResultsFixture;
  const actions = generic.results[0].actions;
  if (actions === undefined || actions.length <= actionIndex) {
    throw new Error('ride confirm fixture action is missing');
  }
  return actions[actionIndex];
}

function mutatedRideConfirm(key: string, value: TestValue): DataResult {
  const result = JSON.parse(JSON.stringify(exactRideEstimateResult())) as DataResult;
  const action = rideConfirmAction(result);
  if (action.args === undefined) {
    throw new Error('ride confirm fixture args are missing');
  }
  (action.args as TestRecord)[key] = value;
  return result;
}

function nestedEstimateCacheMutation(): DataResult {
  const result = JSON.parse(JSON.stringify(exactRideEstimateResult())) as DataResult;
  const action = rideConfirmAction(result);
  if (action.args === undefined) {
    throw new Error('ride confirm fixture args are missing');
  }
  const args = action.args as TestRecord;
  const cache = JSON.parse(args['estimateCacheJson'] as string) as TestRecord;
  const products = cache['products'] as Object[];
  (products[0] as TestRecord)['priceText'] = '约 999 元';
  args['estimateCacheJson'] = JSON.stringify(cache);
  return result;
}

function crossItemRideConfirm(): DataResult {
  const result = JSON.parse(JSON.stringify(exactRideEstimateResult())) as DataResult;
  const first = rideConfirmAction(result, 0);
  const second = rideConfirmAction(result, 1);
  if (first.args === undefined || second.args === undefined) {
    throw new Error('ride confirm fixture args are missing');
  }
  const firstArgs = first.args as TestRecord;
  const secondArgs = second.args as TestRecord;
  firstArgs['productName'] = secondArgs['productName'];
  firstArgs['productCategory'] = secondArgs['productCategory'];
  firstArgs['product_category'] = secondArgs['product_category'];
  return result;
}

function layoutCandidate(surfaceId: string, offerId: string): string {
  return '{"version":"v0.9.1","updateComponents":{"surfaceId":' + JSON.stringify(surfaceId) +
    ',"components":[{"id":"root","component":"SurfaceRoot","children":["results","actions"]},' +
    '{"id":"results","component":"GenericToolResults","dataPath":"/genericToolResults"},' +
    '{"id":"actions","component":"ActionBar","actions":[{"offerId":' + JSON.stringify(offerId) +
    '}]}]}}';
}

function mutatedLayoutCandidate(
  surfaceId: string,
  offerId: string,
  componentType: string,
  extraProperty: string
): string {
  return '{"version":"v0.9.1","updateComponents":{"surfaceId":' + JSON.stringify(surfaceId) +
    ',"components":[{"id":"root","component":"SurfaceRoot","children":["results","actions"]},' +
    '{"id":"results","component":' + JSON.stringify(componentType) +
    ',"dataPath":"/genericToolResults"' + extraProperty + '},' +
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

    it('preserves public community posts through the production structured renderer', 0, async () => {
      const community = dataResult('social.community.search', 'socialHubFeed', object(
        '{"items":[{"id":"t3_real","platform":"reddit","kind":"post","author":"dev_user",' +
        '"handle":"dev_user","text":"Real Reddit discussion","timestamp":"2026-07-22T00:00:00Z",' +
        '"url":"https://reddit.com/r/OpenAI/comments/real","mediaUrl":"","channel":"r/OpenAI",' +
        '"channelId":"OpenAI","threadId":"t3_real","unread":false}],' +
        '"connections":[{"platform":"reddit","status":"connected","displayName":"Reddit",' +
        '"accountId":"reddit-real","message":"connected"}]}'
      ));

      const rendered = await new StructuredToolUiRenderer().result(
        uiTask(), [community], [], 'surface-community'
      );

      expect(rendered.jsonl.indexOf('t3_real')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('Real Reddit discussion')).assertLarger(-1);
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

    it('namespaces same-schema components and every data path without dropping scalar or action data', 0, async () => {
      const first = dataResult('calendar.events.search', 'calendarEvents', genericResult(
        'calendar.events.search', 'First result',
        '[{"label":"Event ID","value":"event-first"}]',
        '[{"id":"calendar.open.web","label":"First action","prompt":"first",' +
        '"variant":"primary","kind":"client","args":{"eventId":"event-first"}}]', '', 'first summary'
      ));
      const second = dataResult('calendar.events.search', 'calendarEvents', genericResult(
        'calendar.events.search', 'Second result',
        '[{"label":"Event ID","value":"event-second"}]',
        '[{"id":"calendar.open.web","label":"Second action","prompt":"second",' +
        '"variant":"secondary","kind":"client","args":{"eventId":"event-second"}}]', '', 'second summary'
      ));
      const renderer = new StructuredToolUiRenderer();

      const rendered = await renderer.result(
        uiTask(['first-data', 'second-data']), [first, second], [], 'surface-same-schema'
      );
      const repeated = await renderer.result(
        uiTask(['first-data', 'second-data']), [first, second], [], 'surface-same-schema'
      );
      const parsed = parseA2uiJsonl(rendered.jsonl);
      const componentIds: Set<string> = new Set<string>();
      const references: string[] = [];
      const dataPaths: string[] = [];
      let duplicateId = false;
      parsed.envelopes.forEach((envelope: A2uiEnvelope) => {
        if (envelope.updateComponents !== undefined) {
          envelope.updateComponents.components.forEach((component: A2uiComponent) => {
            duplicateId = duplicateId || componentIds.has(component.id);
            componentIds.add(component.id);
            if (component.child !== undefined && component.child.length > 0) {
              references.push(component.child);
            }
            if (component.children !== undefined) {
              component.children.forEach((childId: string) => references.push(childId));
            }
          });
        }
        if (envelope.updateDataModel !== undefined) {
          dataPaths.push(envelope.updateDataModel.path);
        }
      });
      let dangling = false;
      references.forEach((childId: string) => dangling = dangling || !componentIds.has(childId));

      expect(parsed.error).assertEqual('');
      expect(duplicateId).assertFalse();
      expect(dangling).assertFalse();
      componentIds.forEach((componentId: string) => {
        const expectedParents = componentId === 'root' ? 0 : 1;
        expect(references.filter((childId: string): boolean => childId === componentId).length)
          .assertEqual(expectedParents);
      });
      expect(dataPaths.indexOf('/results/0/genericToolResults')).assertLarger(-1);
      expect(dataPaths.indexOf('/results/0/summary')).assertLarger(-1);
      expect(dataPaths.indexOf('/results/1/genericToolResults')).assertLarger(-1);
      expect(dataPaths.indexOf('/results/1/summary')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('First result')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('Second result')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('first summary')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('second summary')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('event-first')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('event-second')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('First action')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('Second action')).assertLarger(-1);
      expect(rendered.jsonl).assertEqual(repeated.jsonl);
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

    it('binds a Calendar update review only to one exact provider event ID', 0, async () => {
      const providerEvent = (eventId: string): DynamicGenericToolResult => ({
        sourceTag: 'Composio Google Calendar',
        toolName: 'calendar.events.search',
        title: '产品评审',
        status: 'success',
        summary: 'Real provider event.',
        rows: [
          { label: 'Event ID', value: eventId },
          { label: 'Start', value: '2026-07-30T15:00:00+08:00' },
          { label: 'End', value: '2026-07-30T15:30:00+08:00' }
        ],
        rawPreview: '{"id":' + JSON.stringify(eventId) + '}',
        providerPhase: 'execution'
      });
      const requestedAction = object(
        '{"actionId":"calendar.event.update","title":"产品评审",' +
        '"start":"2026-07-30T16:00:00+08:00","end":"2026-07-30T16:30:00+08:00",' +
        '"timezone":"Asia/Shanghai","calendarId":"primary"}'
      );
      const exactData: CalendarReviewFixture = {
        results: [providerEvent('event-provider-real-1')],
        requestedAction
      };
      const ambiguousData: CalendarReviewFixture = {
        results: [providerEvent('event-provider-real-1'), providerEvent('event-provider-real-2')],
        requestedAction
      };
      const missingData: CalendarReviewFixture = {
        results: [],
        requestedAction
      };
      const exact = dataResult('calendar.events.search', 'calendarEvents', exactData as Object);
      const ambiguous = dataResult('calendar.events.search', 'calendarEvents', ambiguousData as Object);
      const missing = dataResult('calendar.events.search', 'calendarEvents', missingData as Object);
      missing.status = 'empty';
      const resolver = new RegisteredActionOfferResolver(catalog());

      const exactOffers = await resolver.resolve(exact, offerContext('calendar-exact'));
      const ambiguousOffers = await resolver.resolve(ambiguous, offerContext('calendar-ambiguous'));
      const missingOffers = await resolver.resolve(missing, offerContext('calendar-missing'));
      const rendered = await new StructuredToolUiRenderer().result(
        uiTask(), [exact], exactOffers, 'surface-calendar-update'
      );

      expect(exactOffers.length).assertEqual(1);
      expect(exactOffers[0].actionId).assertEqual('calendar.event.update');
      const exactArgs = exactOffers[0].args as Record<string, Object | string | number | boolean | null | undefined>;
      expect(exactArgs['eventId']).assertEqual('event-provider-real-1');
      expect(exactArgs['title']).assertEqual('产品评审');
      expect(exactArgs['start']).assertEqual('2026-07-30T16:00:00+08:00');
      expect(exactArgs['end']).assertEqual('2026-07-30T16:30:00+08:00');
      expect(exactArgs['timezone']).assertEqual('Asia/Shanghai');
      expect(exactArgs['calendarId']).assertEqual('primary');
      expect(ambiguousOffers.length).assertEqual(0);
      expect(missingOffers.length).assertEqual(0);
      expect(rendered.jsonl.indexOf('"id":"calendar.event.update"')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('event-provider-real-1')).assertLarger(-1);
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

    it('keeps embedded client actions canonical and never promotes them into layout offers', 0, async () => {
      const action = '{"id":"ride.open.didi","label":"打开滴滴","prompt":"open",' +
        '"variant":"primary","kind":"client","args":{"traceId":"trace-client",' +
        '"url":"diditaxi://ride?traceId=trace-client"}}';
      const result = dataResult('ride.app.link', 'genericToolResults', genericResult(
        'ride.app.link', 'Ride link',
        '[{"label":"Trace","value":"trace-client"},' +
        '{"label":"URL","value":"diditaxi://ride?traceId=trace-client"}]', '[' + action + ']'
      ));
      const resolver = new RegisteredActionOfferResolver(catalog());
      const offers = await resolver.resolve(result, offerContext('ride-client-data'));
      const planner = new RecordingPlanner();
      const rendered = await new StructuredToolUiRenderer(planner, 100).result(
        uiTask(), [result], offers, 'surface-client-action'
      );

      expect(offers.length).assertEqual(0);
      expect(rendered.jsonl.indexOf('"id":"ride.open.didi"')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('diditaxi://ride?traceId=trace-client')).assertLarger(-1);
      expect(planner.prompt.indexOf('ride.open.didi')).assertEqual(-1);
      expect(planner.prompt.indexOf('trace-client')).assertEqual(-1);
    });

    it('rejects client actions relabeled as prompt and preserves them only in canonical data', 0, async () => {
      const rows = '[{"label":"Trace","value":"trace-dedupe"},' +
        '{"label":"URL","value":"diditaxi://ride?traceId=trace-dedupe"}]';
      const actions = '[{"id":"ride.open.didi","label":"First","prompt":"first",' +
        '"variant":"primary","kind":"prompt","args":{"traceId":"trace-dedupe",' +
        '"url":"diditaxi://ride?traceId=trace-dedupe","meta":{"b":2,"a":1},"order":[1,2]}},' +
        '{"id":"ride.open.didi","label":"Reordered","prompt":"second",' +
        '"variant":"secondary","kind":"prompt","args":{"order":[1,2],"meta":{"a":1,"b":2},' +
        '"url":"diditaxi://ride?traceId=trace-dedupe","traceId":"trace-dedupe"}},' +
        '{"id":"ride.open.didi","label":"Distinct array","prompt":"third",' +
        '"variant":"secondary","kind":"prompt","args":{"traceId":"trace-dedupe",' +
        '"url":"diditaxi://ride?traceId=trace-dedupe","meta":{"a":1,"b":2},"order":[2,1]}}]';
      const duplicateResult = dataResult('ride.app.link', 'genericToolResults', genericResult(
        'ride.app.link', 'Ride links', rows, actions
      ));
      const prototypeResult = dataResult('ride.app.link', 'genericToolResults', genericResult(
        'ride.app.link', 'Prototype args', rows,
        '[{"id":"ride.open.didi","label":"Unsafe","prompt":"unsafe",' +
        '"variant":"primary","kind":"prompt","args":{"traceId":"trace-dedupe",' +
        '"url":"diditaxi://ride?traceId=trace-dedupe","__proto__":{"polluted":true}}}]'
      ));
      const resolver = new RegisteredActionOfferResolver(catalog());

      const duplicateOffers = await resolver.resolve(duplicateResult, offerContext('dedupe-data'));
      const prototypeOffers = await resolver.resolve(prototypeResult, offerContext('prototype-data'));
      const rendered = await new StructuredToolUiRenderer().result(
        uiTask(), [duplicateResult], duplicateOffers, 'surface-relabelled-client'
      );

      expect(duplicateOffers.length).assertEqual(0);
      expect(prototypeOffers.length).assertEqual(0);
      expect(rendered.jsonl.indexOf('"id":"ride.open.didi"')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('"kind":"prompt"')).assertLarger(-1);
    });

    it('removes duplicate offers reconstructed from the same exact normalized item', 0, async () => {
      const duplicateMail = dataResult('mail.search', 'mailThreads', object(
        '{"threads":[{"provider":"qq","accountLabel":"work","threadId":"thread-duplicate",' +
        '"messageId":"message-duplicate","subject":"Duplicate","from":"alice@example.com",' +
        '"to":[],"participants":[],"snippet":"summary","receivedAt":"2026-07-22","unread":true,' +
        '"important":false,"sourceUrl":"","rawProviderRef":"ref","requestKey":"qq:duplicate"},' +
        '{"provider":"qq","accountLabel":"work","threadId":"thread-duplicate",' +
        '"messageId":"message-duplicate","subject":"Duplicate","from":"alice@example.com",' +
        '"to":[],"participants":[],"snippet":"summary","receivedAt":"2026-07-22","unread":true,' +
        '"important":false,"sourceUrl":"","rawProviderRef":"ref","requestKey":"qq:duplicate"}],' +
        '"statuses":[],"extras":[]}'
      ));

      const offers = await new RegisteredActionOfferResolver(catalog()).resolve(
        duplicateMail, offerContext('duplicate-mail-data')
      );

      expect(offers.length).assertEqual(0);
    });

    it('does not promote even an exact ride confirm action without an independent deterministic builder', 0, async () => {
      const result = exactRideEstimateResult();
      const offers = await new RegisteredActionOfferResolver(catalog()).resolve(
        result, offerContext('ride-exact-data')
      );
      const rendered = await new StructuredToolUiRenderer().result(
        uiTask(), [result], offers, 'surface-ride-exact'
      );

      expect(offers.length).assertEqual(0);
      expect(rendered.jsonl.indexOf('"id":"ride.order.confirm"')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('"traceId":"trace-exact"')).assertLarger(-1);
    });

    it('rejects a ride confirm product mutation while preserving trace identity', 0, async () => {
      const result = mutatedRideConfirm('productName', '伪造车型');
      const args = rideConfirmAction(result).args as Object;
      const offers = await new RegisteredActionOfferResolver(catalog()).resolve(
        result, offerContext('ride-product-mutation')
      );

      expect(field(args, 'traceId')).assertEqual('trace-exact');
      expect(offers.length).assertEqual(0);
    });

    it('rejects a ride confirm route mutation while preserving trace identity', 0, async () => {
      const result = mutatedRideConfirm('routeText', '伪造起点 → 伪造终点');
      const args = rideConfirmAction(result).args as Object;
      const offers = await new RegisteredActionOfferResolver(catalog()).resolve(
        result, offerContext('ride-route-mutation')
      );

      expect(field(args, 'traceId')).assertEqual('trace-exact');
      expect(offers.length).assertEqual(0);
    });

    it('rejects a ride confirm price mutation while preserving trace identity', 0, async () => {
      const result = mutatedRideConfirm('priceText', '约 1 元');
      const args = rideConfirmAction(result).args as Object;
      const offers = await new RegisteredActionOfferResolver(catalog()).resolve(
        result, offerContext('ride-price-mutation')
      );

      expect(field(args, 'traceId')).assertEqual('trace-exact');
      expect(offers.length).assertEqual(0);
    });

    it('rejects a ride confirm provider mutation while preserving trace identity', 0, async () => {
      const result = mutatedRideConfirm('provider', 'forged-provider');
      const args = rideConfirmAction(result).args as Object;
      const offers = await new RegisteredActionOfferResolver(catalog()).resolve(
        result, offerContext('ride-provider-mutation')
      );

      expect(field(args, 'traceId')).assertEqual('trace-exact');
      expect(offers.length).assertEqual(0);
    });

    it('rejects a ride confirm deep-link mutation while preserving trace identity', 0, async () => {
      const result = mutatedRideConfirm('deepLink', 'diditaxi://ride?traceId=forged');
      const args = rideConfirmAction(result).args as Object;
      const offers = await new RegisteredActionOfferResolver(catalog()).resolve(
        result, offerContext('ride-link-mutation')
      );

      expect(field(args, 'traceId')).assertEqual('trace-exact');
      expect(offers.length).assertEqual(0);
    });

    it('rejects a nested ride estimate-cache mutation while preserving trace identity', 0, async () => {
      const result = nestedEstimateCacheMutation();
      const args = rideConfirmAction(result).args as Object;
      const offers = await new RegisteredActionOfferResolver(catalog()).resolve(
        result, offerContext('ride-cache-mutation')
      );

      expect(field(args, 'traceId')).assertEqual('trace-exact');
      expect(offers.length).assertEqual(0);
    });

    it('rejects a cross-item ride product mix while preserving trace identity', 0, async () => {
      const result = crossItemRideConfirm();
      const args = rideConfirmAction(result).args as Object;
      const offers = await new RegisteredActionOfferResolver(catalog()).resolve(
        result, offerContext('ride-cross-item-mutation')
      );

      expect(field(args, 'traceId')).assertEqual('trace-exact');
      expect(field(args, 'productName')).assertEqual('专车');
      expect(field(args, 'priceText')).assertEqual('约 48 元');
      expect(offers.length).assertEqual(0);
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
      expect(mailRead.offerId).assertEqual('o0');
      expect(gmailRead.offerId).assertEqual('o0');
    });

    it('uses render-local opaque offer IDs with no correlation action or item substrings', 0, async () => {
      const resolver = new RegisteredActionOfferResolver(catalog());
      const context: ActionOfferContext = {
        conversationId: 'conversation-secret-47675',
        turnId: 'turn-secret-hotel-booking-open',
        dataTaskId: 'data-secret-bookingUrl'
      };
      const offers = await resolver.resolve(
        dataResult('hotel.detail', 'hotelRatePlans', hotelDetailResult() as Object), context
      );

      for (let index = 0; index < offers.length; index++) {
        expect(offers[index].offerId).assertEqual('o' + index.toString());
        expect(offers[index].offerId.indexOf('conversation-secret')).assertEqual(-1);
        expect(offers[index].offerId.indexOf('turn-secret')).assertEqual(-1);
        expect(offers[index].offerId.indexOf('data-secret')).assertEqual(-1);
        expect(offers[index].offerId.indexOf(offers[index].actionId)).assertEqual(-1);
        expect(offers[index].offerId.indexOf('47675')).assertEqual(-1);
      }
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

    it('accepts layout-only placement but rejects authored content properties and type substitution', 0, async () => {
      const resolver = new RegisteredActionOfferResolver(catalog());
      const data = dataResult('hotel.detail', 'hotelRatePlans', hotelDetailResult() as Object);
      const offers = await resolver.resolve(data, offerContext());
      const booking = actionById(offers, 'hotel.booking.open') as ActionOffer;
      const baseline = await new StructuredToolUiRenderer().result(uiTask(), [data], offers, 'surface-layout-only');
      const accepted = new RecordingPlanner();
      accepted.candidate = layoutCandidate('surface-layout-only', booking.offerId);
      const acceptedRender = await new StructuredToolUiRenderer(accepted, 100).result(
        uiTask(), [data], offers, 'surface-layout-only'
      );

      expect(acceptedRender.jsonl === baseline.jsonl).assertFalse();
      expect(acceptedRender.jsonl.indexOf('深圳测试酒店')).assertLarger(-1);
      expect(acceptedRender.jsonl.indexOf('"id":"hotel.search.restore"')).assertLarger(-1);
      expect(acceptedRender.jsonl.indexOf('"id":"hotel.booking.open"')).assertLarger(-1);
      expect(acceptedRender.jsonl.indexOf('"hotelId":47675')).assertLarger(-1);

      const candidates: string[] = [
        mutatedLayoutCandidate('surface-layout-only', booking.offerId, 'GenericToolResults', ',"title":"FORGED TITLE"'),
        mutatedLayoutCandidate('surface-layout-only', booking.offerId, 'GenericToolResults', ',"body":"FORGED BODY"'),
        mutatedLayoutCandidate('surface-layout-only', booking.offerId, 'GenericToolResults', ',"text":"FORGED TEXT"'),
        mutatedLayoutCandidate('surface-layout-only', booking.offerId, 'GenericToolResults', ',"status":"error"'),
        mutatedLayoutCandidate('surface-layout-only', booking.offerId, 'InfoRows', ''),
        mutatedLayoutCandidate('surface-layout-only', booking.offerId, 'UnknownWidget', '')
      ];
      for (let index = 0; index < candidates.length; index++) {
        const planner = new RecordingPlanner();
        planner.candidate = candidates[index];
        const rendered = await new StructuredToolUiRenderer(planner, 100).result(
          uiTask(), [data], offers, 'surface-layout-only'
        );
        expect(rendered.jsonl).assertEqual(baseline.jsonl);
      }
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

    it('preserves the existing handled dynamic registration action for YouTube authorization', 0, async () => {
      const result = dataResult('youtube.mine.playlists', 'youtubePlaylists', genericResult(
        'youtube.mine.playlists', 'YouTube 授权',
        '[{"label":"授权说明","value":"请在 Composio 完成 YouTube OAuth 后重试。"}]',
        '[{"id":"dynamic_open_registration","label":"打开授权页",' +
        '"prompt":"https://app.composio.dev/connections","variant":"primary","kind":"client"}]',
        '',
        'YouTube 尚未授权；请先完成真实账号授权。'
      ));
      result.status = 'error';
      result.error = { code: 'AUTH_REQUIRED', message: 'YouTube account authorization required' };

      const rendered = await new StructuredToolUiRenderer().result(uiTask(), [result], [], 'surface-youtube-auth');
      const parsed = parseA2uiJsonl(rendered.jsonl);
      const serialized = JSON.stringify(parsed.envelopes);

      expect(parsed.error).assertEqual('');
      expect(serialized.indexOf('"id":"dynamic_open_registration"')).assertLarger(-1);
      expect(serialized.indexOf('https://app.composio.dev/connections')).assertLarger(-1);
      expect(serialized.indexOf('YouTube 尚未授权；请先完成真实账号授权。')).assertLarger(-1);
      expect(serialized.indexOf('"id":"youtube.authorize"')).assertEqual(-1);
      expect(serialized.indexOf('"id":"youtube.open.web"')).assertEqual(-1);
      expect(serialized.indexOf('"id":"gmail.authorize"')).assertEqual(-1);
    });

    it('renders truthful YouTube authorization instructions without inventing a button when no link exists', 0, async () => {
      const result = dataResult('youtube.mine.subscriptions', 'youtubeSubscriptions', genericResult(
        'youtube.mine.subscriptions', 'YouTube 授权',
        '[{"label":"下一步","value":"请配置 Composio 并完成 YouTube OAuth，然后重试。"}]',
        '[]',
        '',
        '当前没有可用授权链接；不会伪造 YouTube 账号结果。'
      ));
      result.status = 'error';
      result.error = { code: 'AUTH_REQUIRED', message: 'YouTube account authorization required' };

      const rendered = await new StructuredToolUiRenderer().result(
        uiTask(), [result], [], 'surface-youtube-auth-no-link'
      );

      expect(rendered.jsonl.indexOf('当前没有可用授权链接；不会伪造 YouTube 账号结果。')).assertLarger(-1);
      expect(rendered.jsonl.indexOf('"id":"dynamic_open_registration"')).assertEqual(-1);
      expect(rendered.jsonl.indexOf('"id":"youtube.authorize"')).assertEqual(-1);
      expect(rendered.jsonl.indexOf('"id":"youtube.open.web"')).assertEqual(-1);
    });

    it('keeps valid hotel provider failures canonical while malformed payloads fail closed', 0, async () => {
      const failedSearch = hotelSearchResult();
      failedSearch.ok = false;
      failedSearch.error = 'RollingGo search unavailable';
      failedSearch.message = 'RollingGo search unavailable';
      failedSearch.hotels = [];
      const failedDetail = hotelDetailResult();
      failedDetail.ok = false;
      failedDetail.error = 'RollingGo detail unavailable';
      failedDetail.message = 'RollingGo detail unavailable';
      failedDetail.rates = [];
      const search = dataResult('hotel.search', 'hotelSearchResults', failedSearch as Object);
      const detail = dataResult('hotel.detail', 'hotelRatePlans', failedDetail as Object);
      search.status = 'error';
      detail.status = 'error';
      const malformed = dataResult('hotel.search', 'hotelSearchResults', object('{"ok":false}'));

      const searchRender = await new StructuredToolUiRenderer().result(uiTask(), [search], [], 'surface-hotel-error-search');
      const detailRender = await new StructuredToolUiRenderer().result(uiTask(), [detail], [], 'surface-hotel-error-detail');
      const malformedRender = await new StructuredToolUiRenderer().result(uiTask(), [malformed], [], 'surface-hotel-malformed');

      expect(searchRender.jsonl.indexOf('RollingGo search unavailable')).assertLarger(-1);
      expect(detailRender.jsonl.indexOf('RollingGo detail unavailable')).assertLarger(-1);
      expect(searchRender.jsonl.indexOf('结构化结果格式无效')).assertEqual(-1);
      expect(detailRender.jsonl.indexOf('结构化结果格式无效')).assertEqual(-1);
      expect(malformedRender.jsonl.indexOf('结构化结果格式无效')).assertLarger(-1);
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
