import { AgentTool } from '../agent/AgentTool';
import { AgentToolRunOptions } from '../agent/AgentToolRunOptions';
import { ModelScopeClient } from './ModelScopeClient';

interface ModelScopeToolInput {
  operation?: string;
  useCase?: string;
  qualifiedName?: string;
  arguments?: Object;
}

export class ModelScopeTool implements AgentTool {
  private client: ModelScopeClient;

  constructor(client: ModelScopeClient) {
    this.client = client;
  }

  name(): string {
    return 'modelscope';
  }

  description(): string {
    return this.client.toolDescription();
  }

  async run(input: string, _options?: AgentToolRunOptions): Promise<string> {
    let parsed: ModelScopeToolInput;
    try {
      parsed = JSON.parse(input) as ModelScopeToolInput;
    } catch (_error) {
      return 'ModelScope 参数错误：输入必须是 JSON。';
    }
    if (parsed.operation === 'search') {
      return this.client.search(parsed.useCase ?? '');
    }
    if (parsed.operation === 'execute') {
      return this.client.execute(parsed.qualifiedName ?? '', parsed.arguments ?? new Object());
    }
    return 'ModelScope 参数错误：operation 必须是 search 或 execute。';
  }
}
