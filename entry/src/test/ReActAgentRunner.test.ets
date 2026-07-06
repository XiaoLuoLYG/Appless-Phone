import { describe, it, expect } from '@ohos/hypium';
import {
  AgentEvent,
  AgentEventKind,
  AgentTool,
  A2uiEnvelope,
  ConversationContext,
  DynamicGenericToolResult,
  genericToolResultsA2ui,
  LocalModel,
  parseLoopToolInputArgs,
  ReActAgentRunner,
  summarizeA2uiObservation,
  ToolRegistry
} from '@loop/agent-core';

class SingleActionModel implements LocalModel {
  private response: string;

  constructor(response: string) {
    this.response = response;
  }

  async complete(_prompt: string, _conversation?: ConversationContext): Promise<string> {
    return this.response;
  }
}

class CaptureTool implements AgentTool {
  called: boolean = false;
  input: string = '';

  name(): string {
    return 'gmail.draft.create';
  }

  description(): string {
    return 'capture tool input';
  }

  async run(input: string): Promise<string> {
    this.called = true;
    this.input = input;
    return 'captured';
  }
}

function mediaResult(status: string = 'success'): DynamicGenericToolResult {
  return {
    sourceTag: 'YouTube API',
    toolName: 'youtube.video.search',
    title: 'Qwen demo',
    status: status,
    summary: 'Found a real provider video result.',
    rows: [
      { label: 'Watch URL', value: 'https://youtube.example/watch?v=abc123' },
      { label: 'Video ID', value: 'abc123' },
      { label: 'Thumbnail', value: 'https://images.example/thumb.jpg' }
    ],
    rawPreview: '{"raw":"must not leak"}'
  };
}

function componentOnlyStatusJsonl(status: string): string {
  const envelopes: A2uiEnvelope[] = [
    {
      createSurface: {
        surfaceId: 'surface_component_only',
        root: 'root',
        title: 'Component-only failure',
        intent: 'dynamic_tool',
        status: 'ready',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: 'surface_component_only',
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'notice',
            title: 'Component-only failure',
            status: 'ready'
          },
          {
            id: 'notice',
            component: 'ErrorNotice',
            title: 'Needs attention',
            body: 'Component status carries the terminal state.',
            status: status
          }
        ]
      }
    }
  ];
  let jsonl = '';
  envelopes.forEach((envelope: A2uiEnvelope) => jsonl += JSON.stringify(envelope) + '\n');
  return jsonl;
}

export default function reActAgentRunnerTest() {
  describe('reActAgentRunner', () => {
    it('parses parenthesized JSON actions that contain arrays', 0, async () => {
      const tool = new CaptureTool();
      const registry = new ToolRegistry();
      registry.register(tool);
      const runner = new ReActAgentRunner(
        new SingleActionModel('Thought: create draft\nAction: gmail.draft.create({"to":["a@example.com"],"body":"hi"})'),
        registry,
        1
      );
      let actionText = '';
      await runner.run('draft', (event: AgentEvent) => {
        if (event.kind === AgentEventKind.ACTION) {
          actionText = event.text;
        }
      });

      expect(tool.called).assertTrue();
      expect(tool.input).assertEqual('{"to":["a@example.com"],"body":"hi"}');
      expect(actionText).assertEqual('gmail.draft.create({"to":["a@example.com"],"body":"hi"})');
    });

    it('repairs raw line breaks inside JSON string tool args', 0, () => {
      const parsed = parseLoopToolInputArgs('{"to":["a@example.com"],"body":"hello\nworld"}') as Record<string, Object | string | undefined>;

      expect(JSON.stringify(parsed).indexOf('"to":["a@example.com"]')).assertLarger(-1);
      expect(JSON.stringify(parsed).indexOf('hello\\nworld')).assertLarger(-1);
    });

    it('summarizes A2UI observations without leaking raw JSONL or thumbnails', 0, () => {
      const jsonl = genericToolResultsA2ui('surface_media', 'youtube.video.search', [mediaResult()]);
      const digest = summarizeA2uiObservation(jsonl);

      expect(digest.isA2ui).assertTrue();
      expect(digest.shouldStop).assertFalse();
      expect(digest.failureKey).assertEqual('');
      expect(digest.text.indexOf('ObservationDigest')).assertLarger(-1);
      expect(digest.text.indexOf('toolId: youtube.video.search')).assertLarger(-1);
      expect(digest.text.indexOf('surface status: ready')).assertLarger(-1);
      expect(digest.text.indexOf('result count: 1')).assertLarger(-1);
      expect(digest.text.indexOf('Qwen demo')).assertLarger(-1);
      expect(digest.text.indexOf('status=success')).assertLarger(-1);
      expect(digest.text.indexOf('source=YouTube API')).assertLarger(-1);
      expect(digest.text.indexOf('Found a real provider video result.')).assertLarger(-1);
      expect(digest.text.indexOf('Watch URL: https://youtube.example/watch?v=abc123')).assertLarger(-1);
      expect(digest.text.indexOf('Video ID: abc123')).assertLarger(-1);
      expect(digest.text.indexOf('"createSurface"')).assertEqual(-1);
      expect(digest.text.indexOf('Thumbnail')).assertEqual(-1);
      expect(digest.text.indexOf('thumb.jpg')).assertEqual(-1);
      expect(digest.text.indexOf('must not leak')).assertEqual(-1);
    });

    it('marks terminal A2UI statuses and failure keys', 0, () => {
      const stopStatuses: string[] = ['blocked', 'confirm_required', 'needs_input', 'needs_user', 'auth_required'];
      stopStatuses.forEach((status: string) => {
        const digest = summarizeA2uiObservation(genericToolResultsA2ui('surface_media', 'youtube.video.search', [mediaResult(status)]));
        expect(digest.shouldStop).assertTrue();
      });

      const failureStatuses: string[] = ['error', 'blocked', 'auth_required'];
      failureStatuses.forEach((status: string) => {
        const digest = summarizeA2uiObservation(genericToolResultsA2ui('surface_media', 'youtube.video.search', [mediaResult(status)]));
        expect(digest.failureKey.indexOf('youtube.video.search')).assertLarger(-1);
        expect(digest.failureKey.indexOf(status)).assertLarger(-1);
      });
    });

    it('sets failure keys from component-only terminal statuses', 0, () => {
      const digest = summarizeA2uiObservation(componentOnlyStatusJsonl('blocked'));

      expect(digest.isA2ui).assertTrue();
      expect(digest.shouldStop).assertTrue();
      expect(digest.failureKey.indexOf('blocked')).assertLarger(-1);
    });
  });
}
