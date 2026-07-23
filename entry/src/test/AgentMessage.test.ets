import { describe, expect, it } from '@ohos/hypium';
import {
  ActionOffer,
  AgentMessage,
  AgentMessageType,
  ConversationRole,
  CreateDataTaskPayload,
  CreateUiTaskPayload,
  DataResult,
  DataResultStatus,
  DataSource,
  LeaderPlan,
  LeaderDataTask,
  LeaderPlanningContext,
  LeaderUiTask,
  TurnConversationRole,
  TurnResultPayload,
  UiRenderResult,
  UserInputPayload
} from '@loop/agent-core';

function dataResult(status: DataResultStatus): DataResult {
  const source: DataSource = {
    provider: 'rollinggo',
    backend: 'oauth_api',
    operation: 'searchHotels',
    fetchedAt: '2026-07-20T00:00:00.000Z'
  };
  return {
    toolId: 'hotel.search',
    outputSchema: 'hotel.search.v1',
    status,
    sources: [source],
    data: new Object(),
    warnings: []
  };
}

export default function agentMessageTest() {
  describe('agentMessage', () => {
    it('keeps conversation turn and task correlation on every message', 0, () => {
      const payload: UserInputPayload = { text: '深圳酒店' };
      const message: AgentMessage = {
        type: AgentMessageType.INPUT_USER,
        conversationId: 'conversation-a',
        turnId: 'turn-2',
        taskId: 'input-2',
        payload
      };

      expect(message.conversationId).assertEqual('conversation-a');
      expect(message.turnId).assertEqual('turn-2');
      expect(message.taskId).assertEqual('input-2');
    });

    it('exposes only approved public message types', 0, () => {
      const types: AgentMessageType[] = [
        AgentMessageType.INPUT_USER,
        AgentMessageType.TASK_CREATE_UI,
        AgentMessageType.TASK_CREATE_DATA,
        AgentMessageType.TASK_RESULT_UI,
        AgentMessageType.TASK_RESULT_DATA,
        AgentMessageType.TASK_ERROR,
        AgentMessageType.ACTION_PLAN_DRAFT,
        AgentMessageType.ACTION_OFFERS_READY,
        AgentMessageType.ACTION_PLAN_READY,
        AgentMessageType.ACTION_RUN,
        AgentMessageType.ACTION_PROGRESS,
        AgentMessageType.ACTION_RESULT,
        AgentMessageType.TURN_CANCEL,
        AgentMessageType.ACTION_PLAN_REQUEST,
        AgentMessageType.TURN_RESULT,
        AgentMessageType.TURN_HANDOFF
      ];

      expect(Object.keys(AgentMessageType).length).assertEqual(16);
      expect(types.join(',')).assertEqual('INPUT.USER,TASK.CREATE.UI,TASK.CREATE.DATA,TASK.RESULT.UI,TASK.RESULT.DATA,TASK.ERROR,ACTION.PLAN.DRAFT,ACTION.OFFERS.READY,ACTION.PLAN.READY,ACTION.RUN,ACTION.PROGRESS,ACTION.RESULT,TURN.CANCEL,ACTION.PLAN.REQUEST,TURN.RESULT,TURN.HANDOFF');
    });

    it('exposes the canonical planning offer and task contracts', 0, () => {
      const role: TurnConversationRole = 'user';
      const planningContext: LeaderPlanningContext = {
        tools: [{
          toolId: 'hotel.search',
          domain: 'hotel',
          intent: 'hotel.search',
          riskLevel: 'read',
          registeredBackends: ['mcp_remote'],
          inputSchema: 'hotelSearchRequest',
          outputSchema: 'hotelSearchResults',
          actions: ['hotel.detail', 'hotel.navigate']
        }],
        personas: []
      };
      const ui: CreateUiTaskPayload = {
        taskId: 'ui-1',
        dataTaskIds: ['data-1', 'data-2'],
        personaId: 'travel_companion',
        skillId: 'hotel-search',
        intent: 'hotel.search.results',
        expectedOutputSchema: 'hotelSearchResults'
      };
      const data: CreateDataTaskPayload = {
        taskId: 'data-1',
        roundId: 'round-1',
        skillId: 'hotel-search',
        goal: 'Find hotels',
        allowedToolIds: ['hotel.search'],
        toolId: 'hotel.search',
        outputSchema: 'hotelSearchResults',
        args: new Object(),
        required: true
      };
      const leaderUi: LeaderUiTask = {
        taskId: ui.taskId,
        intent: ui.intent,
        expectedOutputSchema: ui.expectedOutputSchema
      };
      const leaderData: LeaderDataTask = {
        taskId: data.taskId,
        toolId: data.toolId,
        outputSchema: data.outputSchema,
        args: data.args
      };
      const plan: LeaderPlan = {
        personaId: 'travel_companion',
        skillId: 'hotel-search',
        roundAction: 'execute',
        ui: leaderUi,
        dataTasks: [leaderData, {
          taskId: 'data-2',
          toolId: 'hotel.detail',
          outputSchema: 'hotelDetail',
          args: new Object()
        }],
        reasonCode: 'hotel_search',
        actionIntent: {
          goal: 'Find hotels',
          allowedActionIds: ['hotel.navigate']
        }
      };
      const offer: ActionOffer = {
        offerId: 'offer-1',
        actionId: 'hotel.navigate',
        label: '一键导航',
        variant: 'secondary',
        args: new Object()
      };
      const render: UiRenderResult = { jsonl: '{}' };

      expect(planningContext.tools[0].riskLevel).assertEqual('read');
      expect(role).assertEqual('user');
      expect(ConversationRole.USER).assertEqual('user');
      expect(ConversationRole.ASSISTANT).assertEqual('assistant');
      expect(plan.skillId).assertEqual(ui.skillId);
      expect(data.skillId).assertEqual(ui.skillId);
      expect(plan.dataTasks.length).assertEqual(2);
      expect(ui.dataTaskIds.length).assertEqual(2);
      expect(offer.actionId).assertEqual('hotel.navigate');
      expect(Object.keys(render).join(',')).assertEqual('jsonl');
    });

    it('carries bounded turn context and turn results', 0, () => {
      const input: UserInputPayload = {
        text: '查询天气',
        recentMessages: [{ role: 'user', content: '我在北京' }],
        previousPersonaId: 'travel_companion',
        currentSurfaceSummary: {
          surfaceId: 'surface-1',
          kind: 'travel',
          status: 'ready',
          entityRefs: [],
          actionOfferIds: []
        },
        recentObservations: []
      };
      const turn: TurnResultPayload = {
        status: 'partial',
        surfaceId: 'surface-1',
        roundCount: 2,
        message: 'one source unavailable',
        personaId: 'travel_companion',
        skillId: 'hotel-search'
      };

      expect(AgentMessageType.TURN_RESULT).assertEqual('TURN.RESULT');
      expect(AgentMessageType.ACTION_PLAN_REQUEST).assertEqual('ACTION.PLAN.REQUEST');
      expect(input.recentMessages!.length).assertEqual(1);
      expect(turn.roundCount).assertEqual(2);
      expect(turn.personaId).assertEqual('travel_companion');
    });

    it('retains each structured data result status', 0, () => {
      const results: DataResult[] = [
        dataResult('success'),
        dataResult('partial'),
        dataResult('empty'),
        dataResult('error')
      ];

      expect(results.map((result: DataResult): string => result.status).join(',')).assertEqual('success,partial,empty,error');
    });
  });
}
