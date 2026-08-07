import { describe, expect, it } from '@ohos/hypium';
import {
  ApplessCapabilityRuntimeFactory,
  ApprovalBroker,
  DataResult,
  ToolCall,
  ToolDefinition,
  ToolSpec,
  allToolDefinitions,
  approvalArgsDigest
} from '@loop/agent-core';

class IsolatedCapabilityTestData {
}

async function isolatedLegacyCaller(toolId: string, _prompt: string, _args: Object | null): Promise<DataResult> {
  return {
    toolId,
    outputSchema: '',
    status: 'error',
    sources: [],
    data: new IsolatedCapabilityTestData(),
    warnings: [],
    error: {
      code: 'TEST_HANDLER_MUST_NOT_EXECUTE',
      message: 'Capability policy tests must not execute a production provider.',
      retryable: false
    }
  };
}

const TEST_CAPABILITY_ENVIRONMENT = ApplessCapabilityRuntimeFactory.create(isolatedLegacyCaller);

function approvalCall(toolId: string): ToolCall {
  return {
    traceId: 'trace-approval',
    callId: 'call-approval',
    toolId,
    toolVersion: '1.0.0',
    args: new Object(),
    context: {
      conversationId: 'conversation-a',
      turnId: 'turn-a',
      taskId: 'task-a',
      agentId: 'action_agent',
      surfaceId: 'surface-a',
      stepId: 'step-a',
      inputText: '',
      deadlineAtMs: Date.now() + 60000
    }
  };
}

export default function capabilityRuntimeTest() {
  describe('capabilityRuntime', () => {
    it('projects all 53 fixed definitions into one registry without changing tool ids', 0, () => {
      const legacyIds = allToolDefinitions().map((definition: ToolDefinition): string => definition.toolId).sort();
      const registry = TEST_CAPABILITY_ENVIRONMENT.registry;
      const fixedIds = registry.listTools().filter((spec: ToolSpec): boolean => spec.id !== 'dynamic.search')
        .map((spec: ToolSpec): string => spec.id).sort();

      expect(fixedIds.length).assertEqual(53);
      expect(fixedIds.join(',')).assertEqual(legacyIds.join(','));
      expect(registry.capabilityForTool('hotel.search')?.id).assertEqual('travel.hotel');
      expect(registry.capabilityForTool('calendar.event.create')?.id).assertEqual('productivity.calendar');
      expect(registry.actionLinks.targets('hotel.search').indexOf('hotel.detail')).assertLarger(-1);
      expect(registry.validateIntegrity().ok).assertTrue();
    });

    it('binds approvals to exact turn surface arguments and consumes them once', 0, () => {
      const broker = new ApprovalBroker();
      const call = approvalCall('calendar.event.create');
      const spec = TEST_CAPABILITY_ENVIRONMENT.registry.findTool(call.toolId) as ToolSpec;
      const request = broker.request(call, spec, 1000);
      const grant = broker.issueGrant(request.requestId, 1100);
      expect(grant !== null).assertTrue();
      if (grant === null) return;

      const wrongTurn = approvalCall('calendar.event.create');
      wrongTurn.context.turnId = 'turn-b';
      expect(broker.validateAndConsume(wrongTurn, grant, 1200).code).assertEqual('APPROVAL_MISMATCH');
      expect(broker.validateAndConsume(call, grant, 1200).ok).assertTrue();
      expect(broker.validateAndConsume(call, grant, 1200).code).assertEqual('APPROVAL_UNKNOWN');
      expect(approvalArgsDigest(new Object())).assertEqual(
        '44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a'
      );
    });

    it('keeps Gmail send manual-only through the centralized policy', 0, async () => {
      const outcome = await TEST_CAPABILITY_ENVIRONMENT.runtime.invoke(approvalCall('gmail.message.send'));
      expect(outcome.kind).assertEqual('approval_required');
      expect(outcome.approvalRequest?.toolId).assertEqual('gmail.message.send');
    });
  });
}
