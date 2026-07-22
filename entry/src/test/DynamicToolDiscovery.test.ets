import { describe, it, expect } from '@ohos/hypium';
import {
  callStructuredTool,
  configureDynamicReadExecutorForTests,
  discoverDynamicToolForPrompt,
  DynamicReadExecution,
  DynamicStructuredData,
  DynamicGenericToolResult,
  DynamicToolDiscoveryResult,
  configureDefaultDynamicToolSamplesForTests
} from '@loop/agent-core';

type DynamicArgValue = Object | string | null | undefined;
type DynamicArgRecord = Record<string, DynamicArgValue>;

function looseObject(raw: string): Object {
  return JSON.parse(raw) as Object;
}

export default function dynamicToolDiscoveryTest() {
  describe('dynamicToolDiscovery', () => {
    it('discovers the statistics MCP candidate from a user query', 0, () => {
      configureDefaultDynamicToolSamplesForTests();
      const result = discoverDynamicToolForPrompt('帮我查一下最近的统计局GDP数据') as DynamicToolDiscoveryResult;

      expect(result === null).assertFalse();
      expect(result.toolId).assertEqual('statistics.search');
      expect(result.manifest.id).assertEqual('modelscope.thatcoder.cnbs');
      expect(result.source).assertEqual('modelscope-local-catalog');
    });

    it('discovers an unsupported PPT MCP candidate from a user query', 0, () => {
      configureDefaultDynamicToolSamplesForTests();
      const result = discoverDynamicToolForPrompt('帮我生成一份深圳低空经济介绍PPT') as DynamicToolDiscoveryResult;

      expect(result === null).assertFalse();
      expect(result.toolId).assertEqual('ppt.generate');
      expect(result.manifest.id).assertEqual('modelscope.@deckflow.gezhe-mcp-server');
    });

    it('returns null when the catalog has no matching MCP candidate', 0, () => {
      configureDefaultDynamicToolSamplesForTests();
      const result = discoverDynamicToolForPrompt('帮我查明天深圳到珠海的船票');

      expect(result === null).assertTrue();
    });

    it('allows safe dynamic reads and preserves turn-scoped registration metadata', 0, async () => {
      let calls = 0;
      configureDynamicReadExecutorForTests(async (_prompt: string, args: Object | null): Promise<DynamicReadExecution> => {
        calls += 1;
        const record = args === null ? JSON.parse('{}') as DynamicArgRecord : args as DynamicArgRecord;
        const qualifiedName = typeof record.qualifiedName === 'string' ? record.qualifiedName : 'unknown';
        const receipt = typeof record.receipt === 'string' ? record.receipt : '';
        const providerResult: DynamicGenericToolResult = {
          sourceTag: 'Composio', toolName: qualifiedName, title: 'Read result', status: 'success',
          summary: 'one row', rows: [{ label: 'id', value: receipt }], rawPreview: receipt
        };
        return {
          results: [providerResult],
          registration: {
            provider: 'Composio', qualifiedName: qualifiedName,
            inputSchema: looseObject('{"type":"object"}'), outputSchema: looseObject('{}'), receipt: receipt
          }
        };
      });
      try {
        const first = await callStructuredTool(
          'dynamic.search', 'find docs',
          looseObject('{"operation":"search","qualifiedName":"NOTION_SEARCH","schema":{"type":"object"},"receipt":"turn-1"}')
        );
        const second = await callStructuredTool(
          'dynamic.search', 'list files',
          looseObject('{"operation":"list","qualifiedName":"GOOGLEDRIVE_LIST_FILES","schema":{"type":"object"},"receipt":"turn-2"}')
        );
        const third = await callStructuredTool(
          'dynamic.search', 'read a page',
          looseObject('{"operation":"read","qualifiedName":"NOTION_READ_PAGE","schema":{"type":"object"},"receipt":"turn-3"}')
        );
        const fourth = await callStructuredTool(
          'dynamic.search', 'get a repository',
          looseObject('{"operation":"get","qualifiedName":"GITHUB_GET_REPOSITORY","schema":{"type":"object"},"receipt":"turn-4"}')
        );
        const firstData = first.data as DynamicStructuredData;
        const secondData = second.data as DynamicStructuredData;
        const thirdData = third.data as DynamicStructuredData;
        const fourthData = fourth.data as DynamicStructuredData;

        expect(first.status).assertEqual('success');
        expect(first.outputSchema).assertEqual('dynamicToolConnect');
        expect(firstData.registration.provider).assertEqual('Composio');
        expect(firstData.registration.qualifiedName).assertEqual('NOTION_SEARCH');
        expect(firstData.registration.receipt).assertEqual('turn-1');
        expect(first.sources[0].operation).assertEqual('NOTION_SEARCH');
        expect(first.sources[0].receipt).assertEqual('turn-1');
        expect(JSON.stringify(firstData.results).indexOf('registration')).assertEqual(-1);
        expect(secondData.registration.qualifiedName).assertEqual('GOOGLEDRIVE_LIST_FILES');
        expect(secondData.registration.receipt).assertEqual('turn-2');
        expect(JSON.stringify(second.data).indexOf('turn-1')).assertEqual(-1);
        expect(thirdData.registration.qualifiedName).assertEqual('NOTION_READ_PAGE');
        expect(fourthData.registration.qualifiedName).assertEqual('GITHUB_GET_REPOSITORY');
        expect(JSON.stringify(fourth.data).indexOf('turn-3')).assertEqual(-1);
        expect(calls).assertEqual(4);
      } finally {
        configureDynamicReadExecutorForTests(null);
      }
    });

    it('rejects unsafe and unknown dynamic operations before provider execution', 0, async () => {
      let calls = 0;
      configureDynamicReadExecutorForTests(async (_prompt: string, _args: Object | null): Promise<DynamicReadExecution> => {
        calls += 1;
        return {
          results: [],
          registration: {
            provider: 'recording', qualifiedName: 'never',
            inputSchema: looseObject('{}'), outputSchema: looseObject('{}'), receipt: ''
          }
        };
      });
      try {
        const cases: Object[] = [
          looseObject('{"operation":"delete","qualifiedName":"NOTION_DELETE_PAGE"}'),
          looseObject('{"operation":"create","qualifiedName":"NOTION_CREATE_PAGE"}'),
          looseObject('{"operation":"update","qualifiedName":"LINEAR_UPDATE_ISSUE"}'),
          looseObject('{"operation":"send","qualifiedName":"GMAIL_SEND_EMAIL"}'),
          looseObject('{"operation":"write","qualifiedName":"GOOGLEDRIVE_WRITE_FILE"}'),
          looseObject('{"operation":"execute","qualifiedName":"GITHUB_GET_REPOSITORY"}'),
          looseObject('{"operation":"search","qualifiedName":"NOTION_DELETE_PAGE"}'),
          looseObject('{"operation":"dance","qualifiedName":"UNKNOWN_TOOL"}')
        ];
        for (let index = 0; index < cases.length; index++) {
          const result = await callStructuredTool('dynamic.search', 'unsafe', cases[index]);
          expect(result.status).assertEqual('error');
          expect(result.outputSchema).assertEqual('dynamicToolConnect');
          expect(result.error?.code).assertEqual('DYNAMIC_WRITE_NOT_ALLOWED');
        }
        expect(calls).assertEqual(0);
      } finally {
        configureDynamicReadExecutorForTests(null);
      }
    });
  });
}
