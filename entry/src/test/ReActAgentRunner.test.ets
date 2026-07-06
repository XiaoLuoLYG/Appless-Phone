import { describe, it, expect } from '@ohos/hypium';
import {
  AgentEvent,
  AgentEventKind,
  AgentTool,
  ConversationContext,
  LocalModel,
  parseLoopToolInputArgs,
  ReActAgentRunner,
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
  });
}
