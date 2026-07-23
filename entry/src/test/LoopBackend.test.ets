import { describe, expect, it } from '@ohos/hypium';
import {
  ConversationContext,
  LocalModel,
  LoopBackend,
  LoopBackendRequest,
  configureComposioConfigFromRawJson
} from '@loop/agent-core';

class CalendarWriteAttemptModel implements LocalModel {
  calls: number = 0;

  async complete(_prompt: string, _conversation?: ConversationContext): Promise<string> {
    this.calls++;
    if (this.calls === 1) {
      return 'Thought: try the write\nAction: calendar.event.create[' +
        '{"title":"Blocked","start":"2026-07-30T15:00:00+08:00",' +
        '"end":"2026-07-30T15:30:00+08:00","timezone":"Asia/Shanghai"}]';
    }
    return 'Thought: stop\nFinal: The write was not available.';
  }
}

class InventedSocialReplyModel implements LocalModel {
  calls: number = 0;

  async complete(_prompt: string, _conversation?: ConversationContext): Promise<string> {
    this.calls++;
    if (this.calls === 1) {
      return 'Thought: invent a selection\nAction: social.reply.draft[' +
        '{"itemId":"invented-item","platform":"x","instruction":"draft a reply"}]';
    }
    return 'Thought: stop\nFinal: The reply draft was not available.';
  }
}

function request(): LoopBackendRequest {
  return {
    prompt: '创建日程',
    userPrompt: '创建日程',
    history: [],
    modelSettings: {
      provider: '', baseUrl: '', apiKey: '', model: '', customParametersJson: ''
    },
    surfaceId: 'legacy-calendar-write',
    actionId: 'model_tool_request',
    ignoreToolSurfaceUpdates: false,
    maxSteps: 2
  };
}

export default function loopBackendTest() {
  describe('loopBackend', () => {
    it('does not dispatch a model-requested Calendar write to an authorized provider gateway', 0, async () => {
      configureComposioConfigFromRawJson('{"COMPOSIO_API_KEY":"authorized-fake"}');
      try {
        const model = new CalendarWriteAttemptModel();
        const backend = new LoopBackend(model);
        let providerGatewayCalls = 0;

        const result = await backend.run(request(), {
          onA2uiSurface: (): void => { providerGatewayCalls++; }
        });

        expect(model.calls).assertEqual(2);
        expect(providerGatewayCalls).assertEqual(0);
        expect(result.toolCalls.length).assertEqual(1);
        expect(result.toolCalls[0].observation.indexOf('Unknown tool: calendar.event.create'))
          .assertLarger(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
      }
    });

    it('does not dispatch an invented SocialHub item ID from the legacy model', 0, async () => {
      const model = new InventedSocialReplyModel();
      const backend = new LoopBackend(model);
      let toolSurfaceCalls = 0;

      const result = await backend.run(request(), {
        onA2uiSurface: (): void => { toolSurfaceCalls++; }
      });

      expect(model.calls).assertEqual(2);
      expect(toolSurfaceCalls).assertEqual(0);
      expect(result.toolCalls.length).assertEqual(1);
      expect(result.toolCalls[0].observation.indexOf('Unknown tool: social.reply.draft'))
        .assertLarger(-1);
      expect(result.raw.indexOf('invented-item')).assertLarger(-1);
      expect(result.raw.indexOf('"status":"draft"')).assertEqual(-1);
    });
  });
}
