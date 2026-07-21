import { describe, expect, it } from '@ohos/hypium';
import {
  ActionOffer,
  ActionPlanDraft,
  AgentMessage,
  AgentMessageType,
  CreateDataTaskPayload,
  CreateUiTaskPayload,
  DataResult,
  DataResultStatus,
  DataSource,
  LeaderPlan,
  LeaderDataTask,
  LeaderPlanningContext,
  LeaderUiTask,
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
        AgentMessageType.TURN_CANCEL
      ];

      expect(Object.keys(AgentMessageType).length).assertEqual(13);
      expect(types.join(',')).assertEqual('INPUT.USER,TASK.CREATE.UI,TASK.CREATE.DATA,TASK.RESULT.UI,TASK.RESULT.DATA,TASK.ERROR,ACTION.PLAN.DRAFT,ACTION.OFFERS.READY,ACTION.PLAN.READY,ACTION.RUN,ACTION.PROGRESS,ACTION.RESULT,TURN.CANCEL');
    });

    it('exposes the canonical planning offer and task contracts', 0, () => {
      const draft: ActionPlanDraft = {
        planId: 'plan-1',
        runId: 'run-1',
        label: '查看详情后导航',
        steps: []
      };
      const planningContext: LeaderPlanningContext = {
        tools: [{
          toolId: 'hotel.search',
          intent: 'hotel.search',
          riskLevel: 'read',
          inputSchema: 'hotelSearchRequest',
          outputSchema: 'hotelSearchResults',
          actions: ['hotel.detail', 'hotel.navigate']
        }],
        skills: [{
          skillId: 'hotel-search',
          description: 'Search real hotel inventory.',
          instructions: 'Use hotel.search and do not claim booking.'
        }]
      };
      const ui: CreateUiTaskPayload = {
        taskId: 'ui-1',
        dataTaskId: 'data-1',
        skillId: 'hotel-search',
        intent: 'hotel.search.results',
        expectedOutputSchema: 'hotelSearchResults'
      };
      const data: CreateDataTaskPayload = {
        taskId: 'data-1',
        skillId: 'hotel-search',
        toolId: 'hotel.search',
        outputSchema: 'hotelSearchResults',
        args: new Object()
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
        skillId: 'hotel-search',
        ui: leaderUi,
        data: leaderData,
        actionPlan: draft
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
      expect(plan.skillId).assertEqual(ui.skillId);
      expect(data.skillId).assertEqual(ui.skillId);
      expect(plan.actionPlan?.runId).assertEqual('run-1');
      expect(offer.actionId).assertEqual('hotel.navigate');
      expect(Object.keys(render).join(',')).assertEqual('jsonl');
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
