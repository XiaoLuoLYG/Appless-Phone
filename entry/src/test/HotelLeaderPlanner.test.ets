import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageType,
  LeaderPlan,
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
  hotelTurnReadyMessage,
  shouldRouteToHotelAgent
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

async function planFor(text: string, response: string): Promise<LeaderPlan> {
  const model = new FakeHotelModel(response);
  const planner = new HotelLeaderPlanner(
    model,
    (): string => '2026-07-20',
    new SequentialPlannerIds()
  );
  const payload: UserInputPayload = { text: text };
  return planner.plan(input(text), payload);
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
        payload
      );
      const args = plan.data.args as Record<string, Object | string | number | boolean | null | undefined>;

      expect(plan.data.toolId).assertEqual('hotel.search');
      expect(plan.ui.intent).assertEqual('hotel');
      expect(plan.ui.expectedOutputSchema).assertEqual('hotelSearchResults');
      expect(plan.data.outputSchema).assertEqual(plan.ui.expectedOutputSchema);
      expect(plan.ui.taskId === plan.data.taskId).assertFalse();
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

      expect(chinese.data.toolId).assertEqual('hotel.search');
      expect(english.data.toolId).assertEqual('hotel.search');
      expect(JSON.stringify(chinese).indexOf('hotel.book')).assertEqual(-1);
      expect(JSON.stringify(english).indexOf('hotel.book')).assertEqual(-1);
    });

    it('uses the bounded local result limit when the model leaves size empty', 0, async () => {
      const withoutModelDefault = SEARCH_JSON.replace('"size":10', '"size":""');
      const plan = await planFor('8月15日深圳住两晚的酒店', withoutModelDefault);
      const args = plan.data.args as Record<string, Object | string | number | boolean | null | undefined>;

      expect(args.originQuery).assertEqual('8月15日深圳住两晚的酒店');
      expect(args.size).assertEqual(10);
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

    it('routes only explicit Chinese or English hotel requests', 0, () => {
      expect(shouldRouteToHotelAgent('帮我预订深圳酒店')).assertTrue();
      expect(shouldRouteToHotelAgent('找一个杭州住宿')).assertTrue();
      expect(shouldRouteToHotelAgent('Book a hotel in Shanghai')).assertTrue();
      expect(shouldRouteToHotelAgent('find lodging near the airport')).assertTrue();
      expect(shouldRouteToHotelAgent('深圳酒店')).assertTrue();
      expect(shouldRouteToHotelAgent('Shanghai hotel')).assertTrue();
      expect(shouldRouteToHotelAgent('stay in Beijing for two nights')).assertTrue();
      expect(shouldRouteToHotelAgent('rooms near Shanghai airport')).assertTrue();
      expect(shouldRouteToHotelAgent('find a room in Shanghai')).assertTrue();
      expect(shouldRouteToHotelAgent('book a room near the airport')).assertTrue();
      expect(shouldRouteToHotelAgent('reserve a room for August 15')).assertTrue();
      expect(shouldRouteToHotelAgent('search for a room for two nights')).assertTrue();
      expect(shouldRouteToHotelAgent('find a guest room for 2 guests tonight')).assertTrue();
      expect(shouldRouteToHotelAgent('帮我订明天的高铁票')).assertFalse();
      expect(shouldRouteToHotelAgent('打开 Gmail')).assertFalse();
      expect(shouldRouteToHotelAgent('预订')).assertFalse();
      expect(shouldRouteToHotelAgent('酒店行业新闻')).assertFalse();
      expect(shouldRouteToHotelAgent('酒店股票走势')).assertFalse();
      expect(shouldRouteToHotelAgent('翻译 hotel')).assertFalse();
      expect(shouldRouteToHotelAgent('hotel industry news')).assertFalse();
      expect(shouldRouteToHotelAgent('hotel stock analysis')).assertFalse();
      expect(shouldRouteToHotelAgent('translate hotel into Chinese')).assertFalse();
      expect(shouldRouteToHotelAgent('workplace accommodation policy')).assertFalse();
      expect(shouldRouteToHotelAgent('send an accommodation email')).assertFalse();
      expect(shouldRouteToHotelAgent('find a meeting room in Shanghai')).assertFalse();
      expect(shouldRouteToHotelAgent('need room to improve performance')).assertFalse();
      expect(shouldRouteToHotelAgent('I need room for growth')).assertFalse();
      expect(shouldRouteToHotelAgent('find a room for growth')).assertFalse();
      expect(shouldRouteToHotelAgent('find a room for improvement')).assertFalse();
      expect(shouldRouteToHotelAgent('search for room to maneuver')).assertFalse();
      expect(shouldRouteToHotelAgent('find a room in this paragraph')).assertFalse();
      expect(shouldRouteToHotelAgent('find a room in this document')).assertFalse();
      expect(shouldRouteToHotelAgent('find a room in this email')).assertFalse();
      expect(shouldRouteToHotelAgent('room layout ideas')).assertFalse();
      expect(shouldRouteToHotelAgent('search classroom layout')).assertFalse();
      expect(shouldRouteToHotelAgent('send a newsroom email')).assertFalse();
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
