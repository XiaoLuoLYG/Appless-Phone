import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageType,
  LeaderPlan,
  LeaderPlanningContext,
  LocalModelSettings,
  LocalModel,
  UserInputPayload
} from '@loop/agent-core';
import {
  HotelLeaderPlanner,
  HotelPlannerIdFactory
} from '../main/ets/pages/A2uiHome/agent/HotelLeaderPlanner';
import {
  hotelModelSettingsFingerprint,
  hotelTurnReadyMessage
} from '../main/ets/pages/A2uiHome/Index';

const SEARCH_JSON: string = '{' +
  '"originQuery":"8月15日深圳住两晚的酒店",' +
  '"place":"深圳",' +
  '"placeType":"CITY",' +
  '"countryCode":"CN",' +
  '"checkInDate":"2026-08-15",' +
  '"stayNights":2,' +
  '"adultCount":2,' +
  '"childCount":0,' +
  '"childAgeDetails":[],' +
  '"roomCount":1,' +
  '"currency":"CNY",' +
  '"size":10' +
  '}';

const C20_MODEL_QUERY: string = '8月8日到10日深圳科技园附近的酒店，2位成人1间房';
const C20_SEARCH_JSON: string = '{' +
  '"originQuery":"' + C20_MODEL_QUERY + '",' +
  '"place":"深圳科技园",' +
  '"placeType":"POI",' +
  '"countryCode":"CN",' +
  '"checkInDate":"2026-08-08",' +
  '"stayNights":2,' +
  '"adultCount":2,' +
  '"childCount":0,' +
  '"childAgeDetails":[],' +
  '"roomCount":1,' +
  '"currency":"CNY",' +
  '"size":10' +
  '}';

const C20_DEVICE_SEARCH_JSON: string = '{' +
  '"originQuery":"' + C20_MODEL_QUERY + '",' +
  '"place":"深圳科技园",' +
  '"placeType":"neighborhood",' +
  '"countryCode":"CN",' +
  '"checkInDate":"2026-08-08",' +
  '"stayNights":2,' +
  '"adultCount":2,' +
  '"childCount":0,' +
  '"childAgeDetails":[],' +
  '"roomCount":1,' +
  '"currency":"",' +
  '"size":0' +
  '}';

const CROSS_YEAR_MODEL_QUERY: string =
  '12月31日到1月2日深圳科技园附近的酒店，2位成人1间房';
const CROSS_YEAR_SEARCH_JSON: string = '{' +
  '"originQuery":"' + CROSS_YEAR_MODEL_QUERY + '",' +
  '"place":"深圳科技园",' +
  '"placeType":"POI",' +
  '"countryCode":"CN",' +
  '"checkInDate":"2026-12-31",' +
  '"stayNights":2,' +
  '"adultCount":2,' +
  '"childCount":0,' +
  '"childAgeDetails":[],' +
  '"roomCount":1,' +
  '"currency":"CNY",' +
  '"size":10' +
  '}';

class FakeHotelModel implements LocalModel {
  response: string;
  prompts: string[] = [];

  constructor(response: string) {
    this.response = response;
  }

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    return this.response;
  }
}

class SequentialPlannerIds implements HotelPlannerIdFactory {
  next: number = 0;

  nextId(prefix: string): string {
    this.next += 1;
    return prefix + '-' + this.next.toString();
  }
}

function input(text: string): AgentMessage {
  const payload: UserInputPayload = { text: text };
  return {
    type: AgentMessageType.INPUT_USER,
    conversationId: 'hotel-session',
    turnId: 'turn-1',
    taskId: 'input-1',
    payload: payload
  };
}

function planningContext(): LeaderPlanningContext {
  return {
    tools: [{
      toolId: 'hotel.search',
      domain: 'hotel',
      intent: 'hotel.search',
      riskLevel: 'read',
      registeredBackends: ['mcp_remote'],
      inputSchema: 'hotelSearchRequest',
      outputSchema: 'hotelSearchResults',
      actions: ['hotel.detail', 'hotel.navigate', 'hotel.book.external']
    }],
    personas: []
  };
}

async function planFor(text: string, response: string): Promise<LeaderPlan> {
  const model = new FakeHotelModel(response);
  const planner = new HotelLeaderPlanner(
    model,
    (): string => '2026-07-20',
    new SequentialPlannerIds()
  );
  const payload: UserInputPayload = { text: text };
  return planner.plan(input(text), payload, planningContext());
}

async function rejected(text: string, response: string): Promise<boolean> {
  try {
    await planFor(text, response);
    return false;
  } catch (_error) {
    return true;
  }
}

export default function hotelLeaderPlannerTest() {
  describe('hotelLeaderPlanner', () => {
    it('extracts one fenced object and builds paired hotel search tasks', 0, async () => {
      const model = new FakeHotelModel('Thought: extract only.\n```json\n' + SEARCH_JSON + '\n```');
      const ids = new SequentialPlannerIds();
      const planner = new HotelLeaderPlanner(
        model,
        (): string => '2026-07-20',
        ids
      );

      const payload: UserInputPayload = { text: '8月15日深圳住两晚的酒店' };
      const plan = await planner.plan(
        input('8月15日深圳住两晚的酒店'),
        payload,
        planningContext()
      );
      const args = plan.dataTasks[0].args as Record<string, Object | string | number | boolean | null | undefined>;

      expect(plan.dataTasks[0].toolId).assertEqual('hotel.search');
      expect(plan.ui.intent).assertEqual('hotel.search');
      expect(plan.ui.expectedOutputSchema).assertEqual('hotelSearchResults');
      expect(plan.dataTasks[0].outputSchema).assertEqual(plan.ui.expectedOutputSchema);
      expect(plan.ui.taskId === plan.dataTasks[0].taskId).assertFalse();
      expect(args.originQuery).assertEqual('8月15日深圳住两晚的酒店');
      expect(args.place).assertEqual('深圳');
      expect(args.checkInDate).assertEqual('2026-08-15');
      expect(args.checkOutDate).assertEqual('2026-08-17');
      expect(args.stayNights).assertEqual(2);
      expect(args.adultCount).assertEqual(2);
      expect(args.childCount).assertEqual(0);
      expect(JSON.stringify(args.childAgeDetails)).assertEqual('[]');
      expect(args.roomCount).assertEqual(1);
      expect(args.currency).assertEqual('CNY');
      expect(args.size).assertEqual(10);
      expect(model.prompts[0].indexOf('2026-07-20')).assertLarger(-1);
      expect(model.prompts[0].indexOf('预订')).assertLarger(-1);
      expect(model.prompts[0].indexOf('hotel.search')).assertLarger(-1);
    });

    it('maps Chinese and English booking wording to search and real rates only', 0, async () => {
      const chinese = await planFor('8月15日深圳住两晚的酒店', SEARCH_JSON);
      const englishJson = SEARCH_JSON.replace(
        '8月15日深圳住两晚的酒店',
        'Book a Shenzhen hotel for two nights on August 15'
      );
      const english = await planFor(
        'Book a Shenzhen hotel for two nights on August 15',
        englishJson
      );

      expect(chinese.dataTasks[0].toolId).assertEqual('hotel.search');
      expect(english.dataTasks[0].toolId).assertEqual('hotel.search');
      expect(JSON.stringify(chinese).indexOf('hotel.book')).assertEqual(-1);
      expect(JSON.stringify(english).indexOf('hotel.book')).assertEqual(-1);
    });

    it('uses bounded local locale and result defaults when the model leaves them empty', 0, async () => {
      const withoutModelDefaults = SEARCH_JSON
        .replace('"currency":"CNY"', '"currency":""')
        .replace('"size":10', '"size":0');
      const plan = await planFor('8月15日深圳住两晚的酒店', withoutModelDefaults);
      const args = plan.dataTasks[0].args as Record<string, Object | string | number | boolean | null | undefined>;

      expect(args.originQuery).assertEqual('8月15日深圳住两晚的酒店');
      expect(args.currency).assertEqual('CNY');
      expect(args.size).assertEqual(10);
    });

    it('restores the exact trusted C20 query for only the allowed polite prefixes', 0, async () => {
      const trustedQueries: string[] = [
        '帮我找' + C20_MODEL_QUERY,
        '请帮我找' + C20_MODEL_QUERY
      ];
      for (let index = 0; index < trustedQueries.length; index++) {
        const trustedQuery = trustedQueries[index];
        const plan = await planFor(trustedQuery, C20_SEARCH_JSON);
        const args = plan.dataTasks[0].args as
          Record<string, Object | string | number | boolean | null | undefined>;

        expect(args.originQuery).assertEqual(trustedQuery);
        expect(args.countryCode).assertEqual('CN');
        expect(args.place).assertEqual('深圳科技园');
        expect(args.checkInDate).assertEqual('2026-08-08');
        expect(args.stayNights).assertEqual(2);
        expect(args.adultCount).assertEqual(2);
        expect(args.childCount).assertEqual(0);
        expect(args.roomCount).assertEqual(1);
      }
    });

    it('normalizes the device neighborhood alias only for the exact nearby POI', 0, async () => {
      const trustedQuery: string = '帮我找' + C20_MODEL_QUERY;
      const plan = await planFor(trustedQuery, C20_DEVICE_SEARCH_JSON);
      const args = plan.dataTasks[0].args as
        Record<string, Object | string | number | boolean | null | undefined>;

      expect(args.originQuery).assertEqual(trustedQuery);
      expect(args.place).assertEqual('深圳科技园');
      expect(args.placeType).assertEqual('POI');
      expect(args.currency).assertEqual('CNY');
      expect(args.size).assertEqual(10);

      const changedPlace = C20_DEVICE_SEARCH_JSON.replace(
        '"place":"深圳科技园"',
        '"place":"深圳"'
      );
      expect(await rejected(trustedQuery, changedPlace)).assertTrue();
    });

    it('accepts a polite-prefix range that crosses month and year by exactly two UTC days', 0,
      async () => {
        const trustedQuery: string = '帮我找' + CROSS_YEAR_MODEL_QUERY;
        const plan = await planFor(trustedQuery, CROSS_YEAR_SEARCH_JSON);
        const args = plan.dataTasks[0].args as
          Record<string, Object | string | number | boolean | null | undefined>;

        expect(args.originQuery).assertEqual(trustedQuery);
        expect(args.checkInDate).assertEqual('2026-12-31');
        expect(args.checkOutDate).assertEqual('2027-01-02');
        expect(args.stayNights).assertEqual(2);
      });

    it('rejects empty generalized arbitrary and Unicode-mutated omitted prefixes', 0, async () => {
      const emptyQuery = C20_SEARCH_JSON.replace(C20_MODEL_QUERY, '');
      const generalized = C20_SEARCH_JSON.replace(C20_MODEL_QUERY, '酒店');
      const arbitraryPrefixes: string[] = [
        '我要找' + C20_MODEL_QUERY,
        '12345678' + C20_MODEL_QUERY,
        '123456789' + C20_MODEL_QUERY,
        '🙏帮我找' + C20_MODEL_QUERY,
        '请\u0301帮我找' + C20_MODEL_QUERY,
        '帮我\u200B找' + C20_MODEL_QUERY
      ];

      expect(await rejected('深圳酒店', emptyQuery)).assertTrue();
      expect(await rejected('帮我找' + C20_MODEL_QUERY, generalized)).assertTrue();
      for (let index = 0; index < arbitraryPrefixes.length; index++) {
        expect(await rejected(arbitraryPrefixes[index], C20_SEARCH_JSON)).assertTrue();
      }
    });

    it('rejects every raw origin query boundary mutation in exact and polite-prefix paths', 0, async () => {
      const boundaryCharacters: string[] = [' ', '\u00A0', '\uFEFF', '\u200B'];
      for (let index = 0; index < boundaryCharacters.length; index++) {
        const boundary: string = boundaryCharacters[index];
        const leading: string = C20_SEARCH_JSON.replace(
          C20_MODEL_QUERY,
          boundary + C20_MODEL_QUERY
        );
        const trailing: string = C20_SEARCH_JSON.replace(
          C20_MODEL_QUERY,
          C20_MODEL_QUERY + boundary
        );

        expect(await rejected(C20_MODEL_QUERY, leading)).assertTrue();
        expect(await rejected(C20_MODEL_QUERY, trailing)).assertTrue();
        expect(await rejected('帮我找' + C20_MODEL_QUERY, leading)).assertTrue();
        expect(await rejected('帮我找' + C20_MODEL_QUERY, trailing)).assertTrue();
      }
    });

    it('rejects every semantic field mutation on the polite-prefix recovery path', 0, async () => {
      const trustedQuery: string = '帮我找' + C20_MODEL_QUERY;
      const mutations: string[] = [
        C20_SEARCH_JSON.replace('"place":"深圳科技园"', '"place":"曼谷"'),
        C20_SEARCH_JSON.replace('"place":"深圳科技园"', '"place":"深圳"'),
        C20_SEARCH_JSON.replace('"placeType":"POI"', '"placeType":"CITY"'),
        C20_SEARCH_JSON.replace('"countryCode":"CN"', '"countryCode":"TH"'),
        C20_SEARCH_JSON.replace('"checkInDate":"2026-08-08"', '"checkInDate":"2026-08-09"'),
        C20_SEARCH_JSON.replace('"checkInDate":"2026-08-08"', '"checkInDate":"2027-08-08"'),
        C20_SEARCH_JSON.replace('"stayNights":2', '"stayNights":3'),
        C20_SEARCH_JSON.replace('"adultCount":2', '"adultCount":3'),
        C20_SEARCH_JSON
          .replace('"childCount":0', '"childCount":1')
          .replace('"childAgeDetails":[]', '"childAgeDetails":[5]'),
        C20_SEARCH_JSON.replace('"roomCount":1', '"roomCount":2')
      ];

      for (let index = 0; index < mutations.length; index++) {
        expect(await rejected(trustedQuery, mutations[index])).assertTrue();
      }
    });

    it('rejects every semantic field mutation when originQuery exactly matches the user text', 0,
      async () => {
        const mutations: string[] = [
          C20_SEARCH_JSON.replace('"place":"深圳科技园"', '"place":"曼谷"'),
          C20_SEARCH_JSON.replace('"placeType":"POI"', '"placeType":"CITY"'),
          C20_SEARCH_JSON.replace('"countryCode":"CN"', '"countryCode":"TH"'),
          C20_SEARCH_JSON.replace('"checkInDate":"2026-08-08"', '"checkInDate":"2026-08-09"'),
          C20_SEARCH_JSON.replace('"stayNights":2', '"stayNights":3'),
          C20_SEARCH_JSON.replace('"adultCount":2', '"adultCount":3'),
          C20_SEARCH_JSON
            .replace('"childCount":0', '"childCount":1')
            .replace('"childAgeDetails":[]', '"childAgeDetails":[5]'),
          C20_SEARCH_JSON.replace('"roomCount":1', '"roomCount":2')
        ];

        for (let index = 0; index < mutations.length; index++) {
          expect(await rejected(C20_MODEL_QUERY, mutations[index])).assertTrue();
        }
      });

    it('rejects exact-query city country date and stay mutations on the direct search form', 0,
      async () => {
        const mutations: string[] = [
          SEARCH_JSON.replace('"place":"深圳"', '"place":"曼谷"'),
          SEARCH_JSON.replace('"placeType":"CITY"', '"placeType":"POI"'),
          SEARCH_JSON.replace('"countryCode":"CN"', '"countryCode":"TH"'),
          SEARCH_JSON.replace('"checkInDate":"2026-08-15"', '"checkInDate":"2026-08-16"'),
          SEARCH_JSON.replace('"stayNights":2', '"stayNights":3')
        ];

        for (let index = 0; index < mutations.length; index++) {
          expect(await rejected('8月15日深圳住两晚的酒店', mutations[index])).assertTrue();
        }
      });

    it('rejects missing fields malformed multiple unknown and booking output', 0, async () => {
      const missingPlace = SEARCH_JSON.replace('"place":"深圳",', '');
      const unknown = SEARCH_JSON.substring(0, SEARCH_JSON.length - 1) + ',"toolId":"hotel.unknown"}';
      const booking = SEARCH_JSON.substring(0, SEARCH_JSON.length - 1) + ',"actionId":"hotel.book"}';

      expect(await rejected('8月15日深圳住两晚的酒店', missingPlace)).assertTrue();
      expect(await rejected('8月15日深圳住两晚的酒店', '{bad json')).assertTrue();
      expect(await rejected('8月15日深圳住两晚的酒店', SEARCH_JSON + '\n' + SEARCH_JSON)).assertTrue();
      expect(await rejected('8月15日深圳住两晚的酒店', unknown)).assertTrue();
      expect(await rejected('8月15日深圳住两晚的酒店', booking)).assertTrue();
    });

    it('rejects invented or changed origin query instead of silently replacing it', 0, async () => {
      const invented = SEARCH_JSON.replace('8月15日深圳住两晚的酒店', '默认曼谷酒店');
      expect(await rejected('8月15日深圳住两晚的酒店', invented)).assertTrue();
    });

    it('fingerprints every live model setting without exposing it in a status message', 0, () => {
      const settings: LocalModelSettings = {
        provider: 'provider-a',
        baseUrl: 'https://model.example/v1',
        model: 'hotel-model',
        apiKey: 'secret-a',
        customParametersJson: '{"temperature":0}',
        ignoreToolSurfaceUpdates: false
      };
      const baseline: string = hotelModelSettingsFingerprint(settings);
      const changedEndpoint: LocalModelSettings = {
        provider: settings.provider,
        baseUrl: 'https://other.example/v1',
        model: settings.model,
        apiKey: settings.apiKey,
        customParametersJson: settings.customParametersJson,
        ignoreToolSurfaceUpdates: settings.ignoreToolSurfaceUpdates
      };
      const changedKey: LocalModelSettings = {
        provider: settings.provider,
        baseUrl: settings.baseUrl,
        model: settings.model,
        apiKey: 'secret-b',
        customParametersJson: settings.customParametersJson,
        ignoreToolSurfaceUpdates: settings.ignoreToolSurfaceUpdates
      };
      const changedModel: LocalModelSettings = {
        provider: settings.provider,
        baseUrl: settings.baseUrl,
        model: 'hotel-model-2',
        apiKey: settings.apiKey,
        customParametersJson: settings.customParametersJson,
        ignoreToolSurfaceUpdates: settings.ignoreToolSurfaceUpdates
      };
      const changedParameters: LocalModelSettings = {
        provider: settings.provider,
        baseUrl: settings.baseUrl,
        model: settings.model,
        apiKey: settings.apiKey,
        customParametersJson: '{"temperature":1}',
        ignoreToolSurfaceUpdates: settings.ignoreToolSurfaceUpdates
      };

      expect(baseline === hotelModelSettingsFingerprint(changedEndpoint)).assertFalse();
      expect(baseline === hotelModelSettingsFingerprint(changedKey)).assertFalse();
      expect(baseline === hotelModelSettingsFingerprint(changedModel)).assertFalse();
      expect(baseline === hotelModelSettingsFingerprint(changedParameters)).assertFalse();
      expect(baseline.indexOf('secret-a')).assertEqual(-1);
      expect(baseline.indexOf('temperature')).assertEqual(-1);
      expect(baseline.indexOf(settings.customParametersJson)).assertEqual(-1);
      expect(hotelTurnReadyMessage('error', '酒店查询')).assertEqual('');
      expect(hotelTurnReadyMessage('empty', '酒店查询').indexOf('真实酒店结果')).assertEqual(-1);
      expect(hotelTurnReadyMessage('partial', '酒店查询').indexOf('部分')).assertLarger(-1);
      expect(hotelTurnReadyMessage('success', '酒店查询').indexOf('真实酒店结果')).assertLarger(-1);
    });
  });
}
