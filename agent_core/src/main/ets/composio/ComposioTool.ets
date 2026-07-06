import { AgentTool } from '../agent/AgentTool';
import { ComposioSessionClient } from './ComposioSessionClient';

interface ComposioToolInput {
  operation?: string;
  useCase?: string;
  toolSlug?: string;
  arguments?: Object;
}

export class ComposioTool implements AgentTool {
  private client: ComposioSessionClient;

  constructor(client: ComposioSessionClient) {
    this.client = client;
  }

  name(): string {
    return 'composio';
  }

  description(): string {
    return this.client.toolDescription();
  }

  async run(input: string): Promise<string> {
    let parsed: ComposioToolInput;
    try {
      parsed = JSON.parse(input) as ComposioToolInput;
    } catch (_error) {
      return 'composio 参数错误：输入必须是 JSON。';
    }
    if (parsed.operation === 'search') {
      return this.client.search(parsed.useCase ?? '');
    }
    if (parsed.operation === 'execute') {
      return this.client.execute(parsed.toolSlug ?? '', parsed.arguments ?? new Object());
    }
    return 'composio 参数错误：operation 必须是 search 或 execute。';
  }
}
