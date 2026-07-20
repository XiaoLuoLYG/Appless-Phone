import { describe, it, expect } from '@ohos/hypium';
import {
  DynamicMcpTool,
  McpToolAnnotations,
  ModelScopeClient,
  ModelScopeConfig,
  ModelScopeDirectClient,
  ModelScopeTool,
  modelScopeExecutionDecision
} from '@loop/agent-core';

class FakeModelScopeClient implements ModelScopeClient {
  lastSearch: string = '';
  lastQualifiedName: string = '';

  async initialize(): Promise<void> {
  }

  toolDescription(): string {
    return 'fake ModelScope';
  }

  async search(useCase: string): Promise<string> {
    this.lastSearch = useCase;
    return 'search-result';
  }

  async execute(qualifiedName: string, _args: Object): Promise<string> {
    this.lastQualifiedName = qualifiedName;
    return 'execute-result';
  }
}

function tool(annotations?: McpToolAnnotations): DynamicMcpTool {
  return {
    name: 'fixture',
    description: 'fixture tool',
    inputSchema: new Object(),
    annotations: annotations
  };
}

export default function modelScopeDirectClientTest() {
  describe('modelScopeDirectClient', () => {
    it('reports unavailable when the token is missing', 0, async () => {
      const direct = new ModelScopeDirectClient(
        new ModelScopeConfig('', '', 'https://modelscope.cn')
      );

      await direct.initialize();

      expect(direct.toolDescription().indexOf('unavailable')).assertLarger(-1);
      expect(await direct.search('read activated tools')).assertEqual(
        'ModelScope Direct 未配置：modelscopeToken'
      );
    });

    it('allows only recently discovered explicit read-only tools', 0, () => {
      expect(modelScopeExecutionDecision(false, tool({
        readOnlyHint: true,
        destructiveHint: false
      }))).assertEqual('unsearched');
      expect(modelScopeExecutionDecision(true, null)).assertEqual('missing');
      expect(modelScopeExecutionDecision(true, tool())).assertEqual('unsafe');
      expect(modelScopeExecutionDecision(true, tool({
        readOnlyHint: true,
        destructiveHint: true
      }))).assertEqual('unsafe');
      expect(modelScopeExecutionDecision(true, tool({
        readOnlyHint: true,
        destructiveHint: false
      }))).assertEqual('allow');
    });

    it('routes search and execute JSON without inventing names', 0, async () => {
      const client = new FakeModelScopeClient();
      const metaTool = new ModelScopeTool(client);

      const search = await metaTool.run('{"operation":"search","useCase":"read my activated tools"}');
      const execute = await metaTool.run('{"operation":"execute","qualifiedName":"mcp__0_demo__read","arguments":{"id":"1"}}');

      expect(search).assertEqual('search-result');
      expect(client.lastSearch).assertEqual('read my activated tools');
      expect(execute).assertEqual('execute-result');
      expect(client.lastQualifiedName).assertEqual('mcp__0_demo__read');
    });

    it('rejects invalid meta-tool input', 0, async () => {
      const metaTool = new ModelScopeTool(new FakeModelScopeClient());

      expect(await metaTool.run('{broken')).assertEqual('ModelScope 参数错误：输入必须是 JSON。');
      expect(await metaTool.run('{"operation":"remove"}')).assertEqual('ModelScope 参数错误：operation 必须是 search 或 execute。');
    });
  });
}
