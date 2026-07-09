import { describe, it, expect } from '@ohos/hypium';
import {
  buildInitializeRequest,
  buildToolsCallRequest,
  buildToolsListRequest,
  inferCredentialFromMcpFailure,
  McpToolResultPayload,
  parseMcpJsonRpcResponse,
  summarizeMcpToolResult
} from '@loop/agent-core';
import { DynamicCredentialSpec } from '@loop/agent-core';

interface TestCityArgs {
  city: string;
}

interface TestStructuredContent {
  city: string;
  weather: string;
}

interface TestStatusItem {
  text: string;
  url: string;
  thumbnail_pic: string;
}

interface TestStructuredArrayContent {
  statuses: TestStatusItem[];
}

export default function genericMcpClientTest() {
  describe('genericMcpClient', () => {
    it('builds initialize and tool requests', 0, () => {
      const args: TestCityArgs = { city: '深圳' };

      expect(buildInitializeRequest(1).method).assertEqual('initialize');
      expect(buildToolsListRequest(2).method).assertEqual('tools/list');
      expect(buildToolsCallRequest(3, 'maps_weather', args).params.name).assertEqual('maps_weather');
    });

    it('parses tools/list JSON-RPC responses', 0, () => {
      const parsed = parseMcpJsonRpcResponse('{"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"maps_weather","description":"weather","inputSchema":{"type":"object"}}]}}');

      expect(parsed.ok).assertTrue();
      expect(parsed.tools.length).assertEqual(1);
      expect(parsed.tools[0].name).assertEqual('maps_weather');
      expect(parsed.tools[0].description).assertEqual('weather');
    });

    it('parses tools/list JSON-RPC responses from event-stream data', 0, () => {
      const raw =
        'event: message\n' +
          'data: {"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"echo","description":"fixture","inputSchema":{"type":"object"}}]}}\n\n';
      const parsed = parseMcpJsonRpcResponse(raw);

      expect(parsed.ok).assertTrue();
      expect(parsed.tools.length).assertEqual(1);
      expect(parsed.tools[0].name).assertEqual('echo');
    });

    it('parses JSON-RPC auth errors', 0, () => {
      const parsed = parseMcpJsonRpcResponse('{"jsonrpc":"2.0","id":null,"error":{"code":-32600,"message":"Authentication failed: Missing Authorization header"}}');
      const credential = inferCredentialFromMcpFailure(401, parsed.errorMessage) as DynamicCredentialSpec;

      expect(parsed.ok).assertFalse();
      expect(parsed.errorMessage.indexOf('Missing Authorization header')).assertLarger(-1);
      expect(credential.name).assertEqual('Authorization');
      expect(credential.placement).assertEqual('header');
    });

    it('infers API key failures from text', 0, () => {
      const credential = inferCredentialFromMcpFailure(400, 'missing api key') as DynamicCredentialSpec;

      expect(credential.name).assertEqual('api_key');
      expect(credential.placement).assertEqual('query');
    });

    it('returns parser errors for invalid JSON', 0, () => {
      const parsed = parseMcpJsonRpcResponse('{not-json');

      expect(parsed.ok).assertFalse();
      expect(parsed.tools.length).assertEqual(0);
      expect(parsed.result === null).assertTrue();
    });

    it('summarizes tool content and structured content', 0, () => {
      const structured: TestStructuredContent = { city: '深圳', weather: '晴' };
      const payload: McpToolResultPayload = {
        content: [{ type: 'text', text: '天气晴朗' }],
        structuredContent: structured,
        isError: false
      };
      const summary = summarizeMcpToolResult(payload);

      expect(summary.summary.indexOf('天气晴朗')).assertLarger(-1);
      expect(summary.rows.length).assertLarger(0);
      expect(summary.rawPreview.indexOf('深圳')).assertLarger(-1);
      expect(summary.status).assertEqual('success');
    });

    it('expands structured content arrays into display rows', 0, () => {
      const statuses: TestStatusItem[] = [{
        text: 'OpenAI Codex 新讨论',
        url: 'https://example.com/1',
        thumbnail_pic: 'https://img.example.com/codex.jpg'
      }];
      const structured: TestStructuredArrayContent = {
        statuses: statuses
      };
      const payload: McpToolResultPayload = {
        content: [{ type: 'text', text: '返回 1 条内容' }],
        structuredContent: structured,
        isError: false
      };
      const summary = summarizeMcpToolResult(payload);

      expect(summary.rows.length).assertEqual(1);
      expect(summary.rows[0].label).assertEqual('statuses 1');
      expect(summary.rows[0].value.indexOf('OpenAI Codex 新讨论')).assertLarger(-1);
      expect(summary.rows[0].value.indexOf('codex.jpg')).assertLarger(-1);
    });
  });
}
