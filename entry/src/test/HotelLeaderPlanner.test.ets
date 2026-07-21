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
      intent: 'hotel.search',
      riskLevel: 'read',
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
