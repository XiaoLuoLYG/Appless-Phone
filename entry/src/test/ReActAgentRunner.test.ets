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

class SequenceModel implements LocalModel {
  responses: string[];
  prompts: string[] = [];

  constructor(responses: string[]) {
    this.responses = responses;
  }

  async complete(prompt: string, _conversation?: ConversationContext): Promise<string> {
    this.prompts.push(prompt);
    const index = this.prompts.length - 1;
    return index < this.responses.length ? this.responses[index] : 'Final: no more responses';
  }
}

class FixedTool implements AgentTool {
  private toolName: string;
  private output: string;
  calls: string[] = [];

  constructor(toolName: string, output: string) {
    this.toolName = toolName;
    this.output = output;
  }

  name(): string {
    return this.toolName;
  }

  description(): string {
    return 'fixed tool output';
  }

  async run(input: string): Promise<string> {
    this.calls.push(input);
    return this.output;
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
      const failureStatuses: string[] = ['error', 'blocked', 'auth_required'];
      failureStatuses.forEach((status: string) => {
        const digest = summarizeA2uiObservation(componentOnlyStatusJsonl(status));

        expect(digest.isA2ui).assertTrue();
        expect(digest.failureKey.indexOf(status)).assertLarger(-1);
        if (status !== 'error') {
          expect(digest.shouldStop).assertTrue();
        }
      });
    });

    it('continues after an A2UI observation and lets the model decide final', 0, async () => {
      const model = new SequenceModel([
        'Thought: need video\nAction: youtube.video.search({"query":"world cup"})',
        'Thought: the video result is enough\nFinal: found video'
      ]);
      const youtube = new FixedTool(
        'youtube.video.search',
        genericToolResultsA2ui('surface_youtube', 'youtube.video.search', [mediaResult()])
      );
      const registry = new ToolRegistry();
      registry.register(youtube);
      const runner = new ReActAgentRunner(model, registry, 3);
      let finalText = '';
      let observationText = '';

      await runner.run('find a world cup video', (event: AgentEvent) => {
        if (event.kind === AgentEventKind.FINAL) {
          finalText = event.text;
        }
        if (event.kind === AgentEventKind.OBSERVATION) {
          observationText = event.text;
        }
      });

      expect(model.prompts.length).assertEqual(2);
      expect(finalText).assertEqual('found video');
      expect(observationText.indexOf('ObservationDigest')).assertLarger(-1);
      expect(model.prompts[1].indexOf('Watch URL: https://youtube.example/watch?v=abc123')).assertLarger(-1);
      expect(model.prompts[1].indexOf('"createSurface"')).assertEqual(-1);
    });

    it('runs a read tool followed by a draft tool before final', 0, async () => {
      const model = new SequenceModel([
        'Thought: search first\nAction: youtube.video.search({"query":"world cup","order":"viewCount","maxResults":5})',
        'Thought: draft email with video\nAction: gmail.draft.create({"to":["xxx@example.com"],"subject":"World Cup videos","body":"https://youtube.example/watch?v=abc123"})',
        'Thought: draft exists\nFinal: Gmail draft prepared for review'
      ]);
      const youtube = new FixedTool(
        'youtube.video.search',
        genericToolResultsA2ui('surface_youtube', 'youtube.video.search', [mediaResult()])
      );
      const draft: DynamicGenericToolResult = {
        sourceTag: 'Gmail API',
        toolName: 'gmail.draft.create',
        title: 'Gmail draft created',
        status: 'success',
        summary: 'Draft saved in Gmail for user review.',
        rows: [{ label: 'Draft ID', value: 'draft-1' }],
        rawPreview: 'draftId=draft-1'
      };
      const gmail = new FixedTool(
        'gmail.draft.create',
        genericToolResultsA2ui('surface_gmail', 'gmail.draft.create', [draft])
      );
      const registry = new ToolRegistry();
      registry.register(youtube);
      registry.register(gmail);
      const runner = new ReActAgentRunner(model, registry, 4);
      let finalText = '';

      await runner.run('search and draft', (event: AgentEvent) => {
        if (event.kind === AgentEventKind.FINAL) {
          finalText = event.text;
        }
      });

      expect(youtube.calls.length).assertEqual(1);
      expect(gmail.calls.length).assertEqual(1);
      expect(model.prompts.length).assertEqual(3);
      expect(finalText).assertEqual('Gmail draft prepared for review');
      expect(model.prompts[2].indexOf('Draft ID: draft-1')).assertLarger(-1);
    });

    it('stops after blocked A2UI observations without asking the model for another step', 0, async () => {
      const model = new SequenceModel([
        'Thought: send directly\nAction: gmail.message.send({"to":["xxx@example.com"],"body":"hi"})',
        'Thought: should not run\nFinal: bad'
      ]);
      const blocked: DynamicGenericToolResult = {
        sourceTag: 'Gmail API',
        toolName: 'gmail.message.send',
        title: 'UnsafeActionBlocked',
        status: 'blocked',
        summary: '不会自动发送 Gmail',
        rows: [{ label: 'Error', value: '不会自动发送 Gmail' }],
        rawPreview: 'blocked'
      };
      const sendTool = new FixedTool(
        'gmail.message.send',
        genericToolResultsA2ui('surface_blocked_send', 'gmail.message.send', [blocked])
      );
      const registry = new ToolRegistry();
      registry.register(sendTool);
      const runner = new ReActAgentRunner(model, registry, 4);
      let finalText = '';

      await runner.run('send email', (event: AgentEvent) => {
        if (event.kind === AgentEventKind.FINAL) {
          finalText = event.text;
        }
      });

      expect(model.prompts.length).assertEqual(1);
      expect(finalText.indexOf('需要用户确认或输入')).assertLarger(-1);
    });

    it('stops after the same A2UI error repeats twice', 0, async () => {
      const model = new SequenceModel([
        'Thought: first try\nAction: youtube.video.search({"query":"world cup"})',
        'Thought: retry once\nAction: youtube.video.search({"query":"world cup highlights"})',
        'Thought: should not run\nFinal: bad'
      ]);
      const failing: DynamicGenericToolResult = {
        sourceTag: 'YouTube Data API',
        toolName: 'youtube.video.search',
        title: 'YouTube API 调用失败',
        status: 'error',
        summary: 'missing YOUTUBE_API_KEY',
        rows: [{ label: 'Error', value: 'missing YOUTUBE_API_KEY' }],
        rawPreview: 'missing YOUTUBE_API_KEY'
      };
      const youtube = new FixedTool(
        'youtube.video.search',
        genericToolResultsA2ui('surface_youtube_error', 'youtube.video.search', [failing])
      );
      const registry = new ToolRegistry();
      registry.register(youtube);
      const runner = new ReActAgentRunner(model, registry, 5);
      let finalText = '';

      await runner.run('search videos', (event: AgentEvent) => {
        if (event.kind === AgentEventKind.FINAL) {
          finalText = event.text;
        }
      });

      expect(youtube.calls.length).assertEqual(2);
      expect(model.prompts.length).assertEqual(2);
      expect(finalText.indexOf('工具重复失败')).assertLarger(-1);
      expect(finalText.indexOf('youtube.video.search')).assertLarger(-1);
    });
  });
}
