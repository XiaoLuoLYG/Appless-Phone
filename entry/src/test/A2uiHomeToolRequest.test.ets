import { describe, it, expect } from '@ohos/hypium';
import { resolveA2uiHomeToolRequest } from '../main/ets/pages/A2uiHome/render/A2uiHomeToolRequest';
import {
  A2uiComponent,
  A2uiFlightData,
  A2uiFoodData,
  A2uiLabelValueData,
  A2uiRuntimeDataModel,
  A2uiRowGroupsData,
  A2uiSocialData,
  A2uiSummaryData,
  A2uiSurfaceState,
  A2uiToolRequestData,
  A2uiTravelOptionData,
  A2uiTrainData,
  A2uiTripData
} from '../main/ets/model/A2uiTypes';

function surfaceWithToolRequest(toolId: string, prompt: string, actionId: string): A2uiSurfaceState {
  const rows: A2uiLabelValueData[] = [];
  const thoughts: string[] = [];
  const tripRows: A2uiLabelValueData[] = [];
  const trip: A2uiTripData = {
    rows: tripRows
  };
  const trainRows: A2uiLabelValueData[] = [];
  const flightRows: A2uiLabelValueData[] = [];
  const foodRows: A2uiLabelValueData[] = [];
  const rowGroups: A2uiRowGroupsData = {
    train: trainRows,
    flight: flightRows,
    food: foodRows
  };
  const trains: A2uiTrainData[] = [];
  const flights: A2uiFlightData[] = [];
  const travelOptions: A2uiTravelOptionData[] = [];
  const foods: A2uiFoodData[] = [];
  const social: A2uiSocialData = {
    messages: [],
    replies: [],
    diagnostics: []
  };
  const summary: A2uiSummaryData = {
    text: '',
    toolName: '',
    dataLabel: '',
    count: 0
  };
  const request: A2uiToolRequestData = {
    toolId: toolId,
    prompt: prompt,
    actionId: actionId
  };
  const model: A2uiRuntimeDataModel = {
    rows: rows,
    trains: trains,
    flights: flights,
    travelOptions: travelOptions,
    foods: foods,
    social: social,
    thoughts: thoughts,
    summary: summary,
    trip: trip,
    rowGroups: rowGroups,
    toolRequest: request,
    dynamicToolConnect: {
      toolId: '',
      prompt: '',
      manifestId: '',
      displayName: '',
      sourceUrl: '',
      status: '',
      message: '',
      credentialName: '',
      credentialRef: '',
      registrationUrl: '',
      actions: []
    },
    genericToolResults: []
  };
  const components: A2uiComponent[] = [];
  return {
    surfaceId: 's',
    rootId: 'root',
    title: '测试',
    intent: 'general',
    status: 'calling_tool',
    components: components,
    dataModelJson: JSON.stringify(model),
    error: '',
    sequence: 1
  };
}

export default function a2uiHomeToolRequestTest() {
  describe('a2uiHomeToolRequest', () => {
    it('uses the model tool request when present', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('train.search', '查明天北京到上海高铁', 'model_tool_request'),
        '用户原始请求',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('train.search');
      expect(resolved.prompt).assertEqual('查明天北京到上海高铁');
      expect(resolved.actionId).assertEqual('model_tool_request');
    });

    it('falls back to user prompt and action id when model omits them', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('food.search', '', ''),
        '附近有什么吃的',
        'retry_food'
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('food.search');
      expect(resolved.prompt).assertEqual('附近有什么吃的');
      expect(resolved.actionId).assertEqual('retry_food');
    });

    it('reports no tool when the prompt has no tool intent', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(surfaceWithToolRequest('', '', ''), '你好', '');

      expect(resolved.hasTool).assertFalse();
      expect(resolved.toolId).assertEqual('');
    });

    it('infers food search when the model omits a tool request for nearby food', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我搜索深圳坂田华为基地附近的奶茶店',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('food.search');
      expect(resolved.prompt).assertEqual('帮我搜索深圳坂田华为基地附近的奶茶店');
      expect(resolved.actionId).assertEqual('client_intent_fallback');
    });

    it('infers ferry search when the user asks for ferry tickets', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我查明天深圳到珠海的船票',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('dynamic.search');
      expect(resolved.actionId).assertEqual('client_intent_fallback');
    });

    it('reroutes ferry tickets to dynamic search even when the model selects travel search', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('travel.search', '帮我查明天深圳到珠海的船票', 'model_tool_request'),
        '帮我查明天深圳到珠海的船票',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('dynamic.search');
      expect(resolved.prompt).assertEqual('帮我查明天深圳到珠海的船票');
      expect(resolved.actionId).assertEqual('model_tool_request');
    });

    it('infers weather and statistics dynamic tools', 0, () => {
      const weather = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我查明天深圳天气',
        ''
      );
      const statistics = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我查询统计局GDP数据',
        ''
      );

      expect(weather.toolId).assertEqual('dynamic.search');
      expect(statistics.toolId).assertEqual('dynamic.search');
    });

    it('infers ppt generation as an unsupported dynamic MCP candidate', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我生成一份深圳低空经济介绍PPT',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('dynamic.search');
      expect(resolved.actionId).assertEqual('client_intent_fallback');
    });

    it('infers unified travel search when the model omits a tool request for travel plans', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '我明天要从北京去上海，帮我搜索出行方案',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('travel.search');
    });

    it('infers Gmail read and draft intents without disturbing dynamic tool reroutes', 0, () => {
      const inbox = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我看下 Gmail 最近的重要邮件',
        ''
      );
      const draft = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我在 Gmail 回复 Alice，先起草一封邮件',
        ''
      );
      const blockedSend = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我 Gmail 直接发送这封邮件，不用确认直接发',
        ''
      );
      const openWeb = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '打开 Gmail 网页版',
        ''
      );

      expect(inbox.toolId).assertEqual('gmail.mail.search');
      expect(draft.toolId).assertEqual('gmail.draft.create');
      expect(blockedSend.toolId).assertEqual('gmail.message.send');
      expect(openWeb.toolId).assertEqual('gmail.open.web');
    });

    it('routes requested Gmail visual smoke prompts to safe Gmail tools', 0, () => {
      const latestImportant = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我看 Gmail 里最新的重要邮件',
        ''
      );
      const openWeb = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '打开 Gmail 网页版',
        ''
      );
      const draftMail = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '帮我用 Gmail 写一封邮件给 alice@example.com 说我收到了',
        ''
      );
      const directSend = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('', '', ''),
        '用 Gmail 直接发送一封邮件给 alice@example.com 说测试',
        ''
      );

      expect(latestImportant.toolId).assertEqual('gmail.mail.search');
      expect(openWeb.toolId).assertEqual('gmail.open.web');
      expect(draftMail.toolId).assertEqual('gmail.draft.create');
      expect(directSend.toolId).assertEqual('gmail.message.send');
    });
  });
}
