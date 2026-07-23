import { describe, it, expect } from '@ohos/hypium';
import {
  AgentEvent,
  AgentEventKind,
  AgentSkill,
  AgentTool,
  AgentToolRunOptions,
  aiphoneToolSurfaceCallback,
  A2uiEnvelope,
  A2uiSurfaceState,
  ConversationContext,
  DynamicGenericToolResult,
  genericToolResultsA2ui,
  isExplicitLuckinOrderPrompt,
  LocalModel,
  parseLoopToolInputArgs,
  ReActAgentRunner,
  SkillSnapshot,
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

  async run(input: string, _options?: AgentToolRunOptions): Promise<string> {
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
  private timeline: string[] | null;
  calls: string[] = [];

  constructor(toolName: string, output: string, timeline: string[] | null = null) {
    this.toolName = toolName;
    this.output = output;
    this.timeline = timeline;
  }

  name(): string {
    return this.toolName;
  }

  description(): string {
    return 'fixed tool output';
  }

  async run(input: string, _options?: AgentToolRunOptions): Promise<string> {
    this.calls.push(input);
    if (this.timeline !== null) {
      this.timeline.push(this.toolName + ':start');
      await Promise.resolve();
      this.timeline.push(this.toolName + ':end');
    }
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

function componentOnlyStatusJsonl(status: string, surfaceId: string = 'surface_component_only'): string {
  const envelopes: A2uiEnvelope[] = [
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: 'Component-only failure',
        intent: 'dynamic_tool',
        status: 'ready',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
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

function longText(prefix: string): string {
  let value = prefix;
  for (let index = 0; index < 40; index++) {
    value += '0123456789';
  }
  return value + '-tail-marker';
}

export default function reActAgentRunnerTest() {
  describe('reActAgentRunner', () => {
    it('forwards or ignores tool surfaces according to the runtime switch', 0, () => {
      let forwarded = 0;
      const onSurface = (_surface: A2uiSurfaceState, _raw: string): void => {
        forwarded++;
      };
      const surface: A2uiSurfaceState = {
        surfaceId: 'surface_food',
        rootId: 'root',
        title: 'Food',
        intent: 'food',
        status: 'calling_tool',
        components: [],
        dataModelJson: '{}',
        error: '',
        sequence: 1
      };

      aiphoneToolSurfaceCallback(false, onSurface)(surface, 'partial');
      aiphoneToolSurfaceCallback(true, onSurface)(surface, 'ignored');

      expect(forwarded).assertEqual(1);
    });

    it('emits the selected skill while preserving the normal observation', 0, async () => {
      const skill = new AgentSkill(
        'weather',
        'Read real weather',
        '',
        '',
        '/skills/weather/SKILL.md',
        'Use the real weather provider.'
      );
      const snapshot = new SkillSnapshot([skill], '<available_skills></available_skills>');
      const read = new FixedTool('read', '# Skill: weather\n\nUse the real weather provider.');
      const registry = new ToolRegistry();
      registry.register(read);
      const runner = new ReActAgentRunner(
        new SingleActionModel('Thought: load skill\nAction: read(weather)'),
        registry,
        1,
        undefined,
        snapshot
      );
      let selectedSkill = '';
      let observation = '';

      await runner.run('weather', (event: AgentEvent) => {
        if (event.kind === AgentEventKind.SKILL) {
          selectedSkill = event.text;
        }
        if (event.kind === AgentEventKind.OBSERVATION) {
          observation = event.text;
        }
      });

      expect(selectedSkill).assertEqual('weather');
      expect(observation.indexOf('# Skill: weather')).assertLarger(-1);
    });

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

    it('puts the Calendar write-routing rule before the tool list', 0, async () => {
      const model = new SequenceModel(['Final: need a specific morning time']);
      const runner = new ReActAgentRunner(model, new ToolRegistry(), 1);

      await runner.run('把明天下午的日程移到上午', (_event: AgentEvent) => {});

      expect(model.prompts[0].indexOf('Calendar write rule')).assertLarger(-1);
      expect(model.prompts[0].indexOf('never calendar.events.search')).assertLarger(-1);
      expect(model.prompts[0].indexOf('omit missing new start or end')).assertLarger(-1);
    });

    it('repairs raw line breaks inside JSON string tool args', 0, () => {
      const parsed = parseLoopToolInputArgs('{"to":["a@example.com"],"body":"hello\nworld"}') as Record<string, Object | string | undefined>;

      expect(JSON.stringify(parsed).indexOf('"to":["a@example.com"]')).assertLarger(-1);
      expect(JSON.stringify(parsed).indexOf('hello\\nworld')).assertLarger(-1);
    });

    it('unwraps model tool arguments from a single args envelope', 0, () => {
      const parsed = parseLoopToolInputArgs('{"args":{"query":"","pageSize":10}}') as Record<string, Object | string | number | undefined>;

      expect(parsed.query).assertEqual('');
      expect(parsed.pageSize).assertEqual(10);
      expect(parsed.args === undefined).assertTrue();
    });

    it('exposes Luckin ordering only for an explicit current-message transaction', 0, () => {
      expect(isExplicitLuckinOrderPrompt('瑞幸生椰拿铁多少钱')).assertFalse();
      expect(isExplicitLuckinOrderPrompt('帮我查附近的瑞幸门店')).assertFalse();
      expect(isExplicitLuckinOrderPrompt('点一杯咖啡')).assertFalse();
      expect(isExplicitLuckinOrderPrompt('帮我点一杯瑞幸生椰拿铁')).assertTrue();
    });

    it('summarizes A2UI observations without leaking raw JSONL or thumbnails', 0, () => {
      const jsonl = genericToolResultsA2ui('surface_media', 'youtube.video.search', [mediaResult()]);
      const digest = summarizeA2uiObservation(jsonl);

      expect(digest.isA2ui).assertTrue();
      expect(digest.shouldStop).assertTrue();
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

    it('keeps real Calendar Event IDs in the next-turn model context', 0, () => {
      const calendarResult: DynamicGenericToolResult = {
        sourceTag: 'Composio Google Calendar',
        toolName: 'calendar.events.search',
        title: '全量QA',
        status: 'success',
        summary: 'Google Calendar event returned by the real API.',
        rows: [
          { label: 'Event ID', value: 'event-real-123' },
          { label: 'Start', value: '2026-07-17T09:00:00+08:00' },
          { label: 'End', value: '2026-07-17T11:00:00+08:00' }
        ],
        rawPreview: 'must not leak'
      };
      const digest = summarizeA2uiObservation(
        genericToolResultsA2ui('surface_calendar', 'calendar.events.search', [calendarResult])
      );

      expect(digest.text.indexOf('Event ID: event-real-123')).assertLarger(-1);
      expect(digest.finalText.indexOf('event-real-123')).assertLarger(-1);
      expect(digest.finalText.indexOf('全量QA')).assertLarger(-1);
      expect(digest.finalText.indexOf('用户无需输入 Event ID')).assertLarger(-1);
      expect(digest.finalText.indexOf('必须使用')).assertEqual(-1);
      expect(digest.finalText.indexOf('must not leak')).assertEqual(-1);
    });

    it('marks terminal A2UI statuses and failure keys', 0, () => {
      const stopStatuses: string[] = ['blocked', 'confirm_required', 'needs_input', 'needs_user', 'auth_required', 'needs_auth', 'unsafe_action_blocked'];
      stopStatuses.forEach((status: string) => {
        const digest = summarizeA2uiObservation(genericToolResultsA2ui('surface_media', 'youtube.video.search', [mediaResult(status)]));
        expect(digest.shouldStop).assertTrue();
      });

      const failureStatuses: string[] = ['error', 'blocked', 'confirm_required', 'needs_input', 'needs_user', 'auth_required', 'needs_auth', 'unsafe_action_blocked'];
      failureStatuses.forEach((status: string) => {
        const digest = summarizeA2uiObservation(genericToolResultsA2ui('surface_media', 'youtube.video.search', [mediaResult(status)]));
        expect(digest.failureKey.indexOf('youtube.video.search')).assertLarger(-1);
        expect(digest.failureKey.indexOf(status)).assertLarger(-1);
      });
    });

    it('sets failure keys from component-only terminal statuses', 0, () => {
      const failureStatuses: string[] = ['error', 'blocked', 'confirm_required', 'needs_input', 'auth_required'];
      failureStatuses.forEach((status: string) => {
        const digest = summarizeA2uiObservation(componentOnlyStatusJsonl(status));

        expect(digest.isA2ui).assertTrue();
        expect(digest.failureKey.indexOf(status)).assertLarger(-1);
        expect(digest.shouldStop).assertTrue();
      });
    });

    it('keeps component failure keys stable across generated surface ids', 0, () => {
      const first = summarizeA2uiObservation(componentOnlyStatusJsonl('blocked', 'surface_one'));
      const second = summarizeA2uiObservation(componentOnlyStatusJsonl('blocked', 'surface_two'));

      expect(first.failureKey).assertEqual(second.failureKey);
    });

    it('compacts large A2UI digest text and caps detailed result rows', 0, () => {
      const results: DynamicGenericToolResult[] = [];
      for (let index = 0; index < 7; index++) {
        results.push({
          sourceTag: longText('source-' + index.toString()),
          toolName: 'youtube.video.search',
          title: index === 6 ? 'Result 6 should not be detailed' : longText('title-' + index.toString()),
          status: 'success',
          summary: longText('summary-' + index.toString()),
          rows: [{ label: 'Watch URL', value: longText('https://youtube.example/watch-' + index.toString()) }],
          rawPreview: longText('raw-' + index.toString())
        });
      }
      const digest = summarizeA2uiObservation(genericToolResultsA2ui('surface_large', 'youtube.video.search', results));

      expect(digest.text.indexOf('result count: 7')).assertLarger(-1);
      expect(digest.text.indexOf('result 6')).assertEqual(-1);
      expect(digest.text.indexOf('Result 6 should not be detailed')).assertEqual(-1);
      expect(digest.text.indexOf('tail-marker')).assertEqual(-1);
      expect(digest.text.indexOf('raw-')).assertEqual(-1);
    });

    it('stops after an A2UI observation instead of asking the model for another step', 0, async () => {
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

      expect(model.prompts.length).assertEqual(1);
      expect(finalText).assertEqual('工具结果已更新到主页。');
      expect(observationText.indexOf('ObservationDigest')).assertLarger(-1);
    });

    it('does not chain a second A2UI tool over the first displayed result', 0, async () => {
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
      expect(gmail.calls.length).assertEqual(0);
      expect(model.prompts.length).assertEqual(1);
      expect(finalText).assertEqual('工具结果已更新到主页。');
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
      expect(finalText.indexOf('需要用户确认或授权')).assertLarger(-1);
    });

    it('stops after the first A2UI error without retrying through the model', 0, async () => {
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

      expect(youtube.calls.length).assertEqual(1);
      expect(model.prompts.length).assertEqual(1);
      expect(finalText.indexOf('工具执行失败')).assertLarger(-1);
    });

    it('adds ModelScope guidance only when the registry contains the tool', 0, async () => {
      const withoutModelScope = new SequenceModel(['Final: done']);
      const withoutRegistry = new ToolRegistry();
      await new ReActAgentRunner(withoutModelScope, withoutRegistry, 1).run(
        'plain task',
        (_event: AgentEvent): void => {}
      );

      const withModelScope = new SequenceModel(['Final: done']);
      const withRegistry = new ToolRegistry();
      withRegistry.register(new FixedTool('modelscope', 'unavailable'));
      await new ReActAgentRunner(withModelScope, withRegistry, 1).run(
        'provider task',
        (_event: AgentEvent): void => {}
      );

      expect(withoutModelScope.prompts[0].indexOf('Call modelscope only')).assertEqual(-1);
      expect(withModelScope.prompts[0].indexOf('Call modelscope only')).assertLarger(-1);
    });

    it('runs independent tools in parallel when Execution is parallel', 0, async () => {
      const timeline: string[] = [];
      const timeTool = new FixedTool('time', '2026-07-21T10:00:00', timeline);
      const noteTool = new FixedTool('note', 'shopping list', timeline);
      const registry = new ToolRegistry();
      registry.register(timeTool, true);
      registry.register(noteTool, true);
      const runner = new ReActAgentRunner(
        new SingleActionModel(
          'Thought: need time and note independently\nExecution: parallel\nAction: time[]\nAction: note[shopping list]'
        ),
        registry,
        1
      );
      const actions: string[] = [];

      await runner.run('time and note', (event: AgentEvent) => {
        if (event.kind === AgentEventKind.ACTION) {
          actions.push(event.text);
        }
      });

      expect(timeTool.calls.length).assertEqual(1);
      expect(noteTool.calls.length).assertEqual(1);
      expect(actions.length).assertEqual(2);
      expect(timeline.join(',')).assertEqual('time:start,note:start,time:end,note:end');
    });

    it('falls back to serial for tools not marked parallel-safe', 0, async () => {
      const timeline: string[] = [];
      const first = new FixedTool('tool.a', 'result-a', timeline);
      const second = new FixedTool('tool.b', 'result-b', timeline);
      const registry = new ToolRegistry();
      registry.register(first);
      registry.register(second);
      const runner = new ReActAgentRunner(
        new SingleActionModel(
          'Thought: requested parallel writes\nExecution: parallel\nAction: tool.a[]\nAction: tool.b[]'
        ),
        registry,
        1
      );

      await runner.run('unsafe tools', (_event: AgentEvent): void => {});

      expect(timeline.join(',')).assertEqual('tool.a:start,tool.a:end,tool.b:start,tool.b:end');
    });

    it('falls back to serial for parallel-safe tools from the same family', 0, async () => {
      const timeline: string[] = [];
      const estimate = new FixedTool('ride.estimate', 'estimate', timeline);
      const location = new FixedTool('ride.driver.location', 'location', timeline);
      const registry = new ToolRegistry();
      registry.register(estimate, true);
      registry.register(location, true);
      const runner = new ReActAgentRunner(
        new SingleActionModel(
          'Thought: two ride calls\nExecution: parallel\nAction: ride.estimate[]\nAction: ride.driver.location[]'
        ),
        registry,
        1
      );

      await runner.run('ride calls', (_event: AgentEvent): void => {});

      expect(timeline.join(',')).assertEqual(
        'ride.estimate:start,ride.estimate:end,ride.driver.location:start,ride.driver.location:end'
      );
    });

    it('runs multiple actions serially in declaration order', 0, async () => {
      const first = new FixedTool('tool.a', 'result-a');
      const second = new FixedTool('tool.b', 'result-b');
      const registry = new ToolRegistry();
      registry.register(first);
      registry.register(second);
      const runner = new ReActAgentRunner(
        new SingleActionModel(
          'Thought: second depends on first\nExecution: serial\nAction: tool.a({})\nAction: tool.b({})'
        ),
        registry,
        1
      );
      const actions: string[] = [];

      await runner.run('serial tools', (event: AgentEvent) => {
        if (event.kind === AgentEventKind.ACTION) {
          actions.push(event.text);
        }
      });

      expect(first.calls.length).assertEqual(1);
      expect(second.calls.length).assertEqual(1);
      expect(actions.length).assertEqual(2);
      expect(actions[0].indexOf('tool.a')).assertLarger(-1);
      expect(actions[1].indexOf('tool.b')).assertLarger(-1);
    });

    it('runs all serial A2UI tools before emitting final', 0, async () => {
      const calendar = new FixedTool('calendar.event.create', componentOnlyStatusJsonl('ready', 'surface_calendar'));
      const gmail = new FixedTool('gmail.draft.create', componentOnlyStatusJsonl('ready', 'surface_gmail'));
      const registry = new ToolRegistry();
      registry.register(calendar);
      registry.register(gmail);
      const runner = new ReActAgentRunner(
        new SingleActionModel(
          'Thought: create event then draft email\nExecution: serial\n' +
          'Action: calendar.event.create({"title":"会议"})\n' +
          'Action: gmail.draft.create({"to":"test@example.com","subject":"会议","body":"明天见"})'
        ),
        registry,
        1
      );
      const actions: string[] = [];
      let finalCount = 0;
      let observationCount = 0;

      await runner.run('serial a2ui chain', (event: AgentEvent) => {
        if (event.kind === AgentEventKind.ACTION) {
          actions.push(event.text);
        }
        if (event.kind === AgentEventKind.FINAL) {
          finalCount++;
        }
        if (event.kind === AgentEventKind.OBSERVATION) {
          observationCount++;
        }
      });

      expect(calendar.calls.length).assertEqual(1);
      expect(gmail.calls.length).assertEqual(1);
      expect(actions.length).assertEqual(2);
      expect(observationCount).assertEqual(2);
      expect(finalCount).assertEqual(1);
    });

    it('waits for all parallel A2UI tools before emitting final', 0, async () => {
      const first = new FixedTool('tool.a', componentOnlyStatusJsonl('ready', 'surface_a'));
      const second = new FixedTool('service.b', componentOnlyStatusJsonl('ready', 'surface_b'));
      const registry = new ToolRegistry();
      registry.register(first, true);
      registry.register(second, true);
      const runner = new ReActAgentRunner(
        new SingleActionModel(
          'Thought: two independent A2UI tools\nExecution: parallel\nAction: tool.a[]\nAction: service.b[]'
        ),
        registry,
        1
      );
      let finalCount = 0;
      let observationCount = 0;

      await runner.run('parallel a2ui', (event: AgentEvent) => {
        if (event.kind === AgentEventKind.FINAL) {
          finalCount++;
        }
        if (event.kind === AgentEventKind.OBSERVATION) {
          observationCount++;
        }
      });

      expect(first.calls.length).assertEqual(1);
      expect(second.calls.length).assertEqual(1);
      expect(observationCount).assertEqual(2);
      expect(finalCount).assertEqual(1);
    });

    it('runs read and time in parallel when Execution is parallel', 0, async () => {
      const readTool = new FixedTool('read', '# Skill: weather\n\nUse weather API.');
      const timeTool = new FixedTool('time', '2026-07-21T10:00:00');
      const registry = new ToolRegistry();
      registry.register(readTool, true);
      registry.register(timeTool, true);
      const runner = new ReActAgentRunner(
        new SingleActionModel(
          'Thought: read skill and get time\nExecution: parallel\nAction: read[weather]\nAction: time[]'
        ),
        registry,
        1
      );
      const actions: string[] = [];

      await runner.run('read and time', (event: AgentEvent) => {
        if (event.kind === AgentEventKind.ACTION) {
          actions.push(event.text);
        }
      });

      expect(readTool.calls.length).assertEqual(1);
      expect(timeTool.calls.length).assertEqual(1);
      expect(actions.length).assertEqual(2);
    });

    it('rejects malformed action plans without executing tools', 0, async () => {
      const first = new FixedTool('tool.a', 'result-a');
      const second = new FixedTool('tool.b', 'result-b');
      const registry = new ToolRegistry();
      registry.register(first);
      registry.register(second);
      let errorText = '';
      const runner = new ReActAgentRunner(
        new SingleActionModel(
          'Thought: broken plan\nExecution: serial\nAction: tool.a({})\nAction: tool.b[{invalid json}'
        ),
        registry,
        1
      );

      await runner.run('broken plan', (event: AgentEvent) => {
        if (event.kind === AgentEventKind.ERROR) {
          errorText = event.text;
        }
      });

      expect(first.calls.length).assertEqual(0);
      expect(second.calls.length).assertEqual(0);
      expect(errorText.indexOf('Action or Final')).assertLarger(-1);
    });

    it('downgrades parallel to serial when more than four actions are requested', 0, async () => {
      const tools: FixedTool[] = [];
      const registry = new ToolRegistry();
      for (let index = 0; index < 5; index++) {
        const tool = new FixedTool('tool.' + index.toString(), 'result-' + index.toString());
        tools.push(tool);
        registry.register(tool, true);
      }
      const response =
        'Thought: too many parallel actions\nExecution: parallel\n' +
        'Action: tool.0[]\nAction: tool.1[]\nAction: tool.2[]\nAction: tool.3[]\nAction: tool.4[]';
      const runner = new ReActAgentRunner(new SingleActionModel(response), registry, 1);
      const actions: string[] = [];

      await runner.run('too many tools', (event: AgentEvent) => {
        if (event.kind === AgentEventKind.ACTION) {
          actions.push(event.text);
        }
      });

      expect(actions.length).assertEqual(5);
      expect(actions[0].indexOf('tool.0')).assertLarger(-1);
      expect(actions[4].indexOf('tool.4')).assertLarger(-1);
    });
  });
}
