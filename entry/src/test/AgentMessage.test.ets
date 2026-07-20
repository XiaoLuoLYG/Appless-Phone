import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageType,
  DataResult,
  DataResultStatus,
  DataSource,
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
        AgentMessageType.ACTION_PLAN_CREATE,
        AgentMessageType.ACTION_PLAN_READY,
        AgentMessageType.ACTION_RUN,
        AgentMessageType.ACTION_PROGRESS,
        AgentMessageType.ACTION_RESULT,
        AgentMessageType.TURN_CANCEL
      ];

      expect(Object.keys(AgentMessageType).length).assertEqual(12);
      expect(types.join(',')).assertEqual('INPUT.USER,TASK.CREATE.UI,TASK.CREATE.DATA,TASK.RESULT.UI,TASK.RESULT.DATA,TASK.ERROR,ACTION.PLAN.CREATE,ACTION.PLAN.READY,ACTION.RUN,ACTION.PROGRESS,ACTION.RESULT,TURN.CANCEL');
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
