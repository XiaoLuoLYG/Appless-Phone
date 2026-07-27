import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiLabelValueData,
  DEFAULT_FIRECRAWL_MCP_URL,
  DynamicCredentialSpec,
  DynamicGenericToolResult,
  DynamicMcpTool,
  DynamicPreflightResult,
  DynamicToolRegistration,
  FIRECRAWL_MCP_READ_TIMEOUT_MS,
  FirecrawlConfig,
  FirecrawlMcpClient,
  FirecrawlToolOutput,
  GenericMcpClient,
  McpToolCallResult,
  directFirecrawlToolIdForActionId,
  firecrawlHttpUrlOf
} from '@loop/agent-core';

const REQUIRED_TOOLS: string[] = [
  'firecrawl_search',
  'firecrawl_scrape',
  'firecrawl_monitor_create',
  'firecrawl_monitor_list',
  'firecrawl_monitor_get',
  'firecrawl_monitor_update',
  'firecrawl_monitor_delete',
  'firecrawl_monitor_run',
  'firecrawl_monitor_checks',
  'firecrawl_monitor_check'
];

const TEST_URL: string = 'https://www.firecrawl.dev/monitor';
const TEST_KEY: string = 'fc-task-3-test-secret';
const TEST_MCP_URL: string = 'https://mcp.example.test/v2/mcp';
const TEST_TIME: string = '2026-07-23T03:00:00.000Z';

interface PageReadArgs {
  url: string;
  question?: string;
  includeFullText?: boolean;
}

interface ResearchArgs {
  query: string;
  domains?: string[];
  maxResults?: number;
  recency?: string;
}

interface ShoppingArgs {
  query: string;
  domains?: string[];
  maxProducts?: number;
  preferences?: string[];
}

interface ProductFixture {
  name: string;
  brand: string;
  model?: string;
  variant?: string;
  platform?: string;
  seller?: string;
  offerUrl?: string;
  evidenceUrl?: string;
  market?: string;
  currency?: string;
  priceText?: string;
  listPriceText?: string;
  salePriceText?: string;
  estimatedPriceText?: string;
  couponText?: string;
  shippingText?: string;
}

interface PriceFixture {
  priceText?: string;
  estimatedPriceText?: string;
  comparable: string;
  fen: string;
  kind?: string;
  displayLabel?: string;
}

interface SocialArgs {
  query: string;
  platforms?: string[];
  maxResults?: number;
  recency?: string;
}

interface XiaohongshuCardFixture {
  title: string;
  author: string;
  published: string;
  url: string;
  coverUrl: string;
  isVideo: boolean;
}

interface XiaohongshuDetailFixture {
  title: string;
  author: string;
  description: string;
  url: string;
  imageUrls: string[];
  isVideo: boolean;
  videoDuration: number;
}

interface InteractArgsFixture {
  code?: string;
}

interface MonitorCreateArgs {
  pages?: string[];
  queries?: string[];
  goal: string;
  name?: string;
  scheduleText?: string;
  timezone?: string;
  email?: string;
  confirmed?: boolean;
}

interface MonitorActionArgs {
  id: string;
  checkId?: string;
  limit?: number;
  confirmed?: boolean;
}

function pageArgs(
  url: string = TEST_URL,
  includeFullText: boolean = false
): PageReadArgs {
  return {
    url: url,
    includeFullText: includeFullText
  };
}

function questionArgs(question: string = '它如何监控网页？'): PageReadArgs {
  return {
    url: TEST_URL,
    question: question
  };
}

function tool(name: string): DynamicMcpTool {
  return {
    name: name,
    description: name,
    inputSchema: new Object()
  };
}

function successfulPreflight(names: string[] = REQUIRED_TOOLS): DynamicPreflightResult {
  return {
    ok: true,
    status: 'enabled',
    httpStatus: 200,
    message: '',
    inferredCredential: null,
    tools: names.map((name: string): DynamicMcpTool => tool(name))
  };
}

function failedPreflight(httpStatus: number, message: string): DynamicPreflightResult {
  return {
    ok: false,
    status: httpStatus === 401 ? 'needs_auth' : 'preflight_failed',
    httpStatus: httpStatus,
    message: message,
    inferredCredential: null,
    tools: []
  };
}

function successfulPayload(
  value: Object,
  textFallback: string = '',
  rawPreview: string = ''
): McpToolCallResult {
  return {
    ok: true,
    httpStatus: 200,
    errorMessage: '',
    result: {
      structuredContent: value,
      content: textFallback.length > 0 ? [{ type: 'text', text: textFallback }] : [],
      isError: false
    },
    rawPreview: rawPreview
  };
}

function textPayload(value: Object): McpToolCallResult {
  return {
    ok: true,
    httpStatus: 200,
    errorMessage: '',
    result: {
      content: [{ type: 'text', text: JSON.stringify(value) }],
      isError: false
    },
    rawPreview: ''
  };
}

function textErrorPayload(value: string, rawPreview: string = ''): McpToolCallResult {
  return {
    ok: true,
    httpStatus: 200,
    errorMessage: '',
    result: {
      content: [{ type: 'text', text: value }],
      isError: true
    },
    rawPreview: rawPreview
  };
}

function failedPayload(httpStatus: number, message: string, rawPreview: string = ''): McpToolCallResult {
  return {
    ok: false,
    httpStatus: httpStatus,
    errorMessage: message,
    result: null,
    rawPreview: rawPreview
  };
}

function failedStructuredPayload(
  httpStatus: number,
  message: string,
  providerMessage: string
): McpToolCallResult {
  return {
    ok: false,
    httpStatus: httpStatus,
    errorMessage: message,
    result: {
      structuredContent: JSON.parse(
        '{"success":false,"error":' + JSON.stringify(providerMessage) + '}'
      ) as Object,
      content: [],
      isError: true
    },
    rawPreview: ''
  };
}

function pagePayload(markdown: string = 'Firecrawl Monitor tracks public page changes.'): Object {
  return JSON.parse(
    '{"markdown":' + JSON.stringify(markdown) + ',' +
    '"metadata":{"title":"Firecrawl Monitor","sourceURL":' + JSON.stringify(TEST_URL) + ',' +
    '"publishedTime":"2026-07-22T00:00:00.000Z","statusCode":200},' +
    '"creditsUsed":1}'
  ) as Object;
}

function searchPayload(items: Object[]): Object {
  return JSON.parse(
    '{"success":true,"data":{"web":' + JSON.stringify(items) +
    '},"id":"search-task-4","creditsUsed":1}'
  ) as Object;
}

function searchItem(url: string, title: string, description: string = ''): Object {
  return JSON.parse(
    '{"url":' + JSON.stringify(url) + ',"title":' + JSON.stringify(title) +
    ',"description":' + JSON.stringify(description) + '}'
  ) as Object;
}

function interactPayload(value: Object | Object[]): Object {
  return JSON.parse(
    '{"success":true,"stdout":' + JSON.stringify(JSON.stringify(value)) + '}'
  ) as Object;
}

function productPayload(url: string, product: ProductFixture): Object {
  return JSON.parse(
    '{"json":' + JSON.stringify(product) +
    ',"metadata":{"title":' + JSON.stringify(product.name) +
    ',"sourceURL":' + JSON.stringify(url) + '}}'
  ) as Object;
}

function offerPayload(url: string, offers: ProductFixture[]): Object {
  return JSON.parse(
    '{"json":{"offers":' + JSON.stringify(offers) + '},' +
    '"metadata":{"sourceURL":' + JSON.stringify(url) + '},"creditsUsed":1}'
  ) as Object;
}

function config(apiKey: string = TEST_KEY, mcpUrl: string = TEST_MCP_URL): FirecrawlConfig {
  return {
    apiKey: apiKey,
    mcpUrl: mcpUrl
  };
}

function rowValue(rows: A2uiLabelValueData[], label: string): string {
  const found = rows.find((row: A2uiLabelValueData): boolean => row.label === label);
  return found === undefined ? '' : found.value;
}

function resultForUrl(results: DynamicGenericToolResult[], url: string): DynamicGenericToolResult {
  const found = results.find((result: DynamicGenericToolResult): boolean =>
    rowValue(result.rows, 'URL') === url
  );
  return found as DynamicGenericToolResult;
}

function resultWithTitle(
  results: DynamicGenericToolResult[],
  title: string
): DynamicGenericToolResult {
  const found = results.find((result: DynamicGenericToolResult): boolean => result.title === title);
  return found as DynamicGenericToolResult;
}

function expectSourceActions(result: DynamicGenericToolResult, url: string): void {
  const actions = result.actions === undefined ? [] : result.actions;
  const open = actions.find((action): boolean => action.id === 'web.open.source');
  const read = actions.find((action): boolean => action.id === 'web.page.read');
  expect(open === undefined).assertFalse();
  expect(read === undefined).assertFalse();
  expect(JSON.stringify(read?.args)).assertEqual('{"url":' + JSON.stringify(url) + '}');
}

function actionArgs(
  result: DynamicGenericToolResult,
  actionId: string
): Object {
  const actions = result.actions === undefined ? [] : result.actions;
  const action = actions.find((item): boolean => item.id === actionId);
  expect(action === undefined).assertFalse();
  return action?.args as Object;
}

class ScriptedGenericMcpClient extends GenericMcpClient {
  readonly preflightRegistrations: DynamicToolRegistration[] = [];
  readonly preflightCredentials: string[] = [];
  readonly callRegistrations: DynamicToolRegistration[] = [];
  readonly callCredentials: string[] = [];
  readonly callArgs: Object[] = [];
  preflightResult: DynamicPreflightResult = successfulPreflight();
  responses: McpToolCallResult[] = [];
  thrownMessage: string = '';
  callHandler: ((
    registration: DynamicToolRegistration,
    credentialValue: string,
    args: Object
  ) => Promise<McpToolCallResult>) | null = null;

  async preflight(
    registration: DynamicToolRegistration,
    credentialValue: string
  ): Promise<DynamicPreflightResult> {
    this.preflightRegistrations.push(registration);
    this.preflightCredentials.push(credentialValue);
    return this.preflightResult;
  }

  async callToolPayload(
    registration: DynamicToolRegistration,
    credentialValue: string,
    args: Object
  ): Promise<McpToolCallResult> {
    this.callRegistrations.push(registration);
    this.callCredentials.push(credentialValue);
    this.callArgs.push(args);
    if (this.callHandler !== null) {
      return this.callHandler(registration, credentialValue, args);
    }
    if (this.thrownMessage.length > 0) {
      throw new Error(this.thrownMessage);
    }
    return this.responses.shift() as McpToolCallResult;
  }
}

async function shoppingProductResult(
  query: string,
  product: ProductFixture
): Promise<DynamicGenericToolResult | null> {
  const url = 'https://zol.com.cn/test-product';
  const scripted = new ScriptedGenericMcpClient();
  scripted.responses = [
    successfulPayload(searchPayload([searchItem(url, product.name)])),
    successfulPayload(productPayload(url, product))
  ];
  const output = await new FirecrawlMcpClient(scripted).execute(
    'shopping.research',
    '商品比价',
    '',
    { query: query, domains: ['zol.com.cn'] } as ShoppingArgs,
    config()
  );
  const result = output.results.find((item: DynamicGenericToolResult): boolean =>
    item.title !== '商品研究综述'
  );
  return result === undefined ? null : result;
}

async function statusForFailure(
  response: McpToolCallResult,
  thrownMessage: string = ''
): Promise<string> {
  const scripted = new ScriptedGenericMcpClient();
  scripted.responses = [response];
  scripted.thrownMessage = thrownMessage;
  const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted, (): string => TEST_TIME)
    .execute('web.page.read', '读取页面', '', pageArgs(), config());
  return output.results[0].status;
}

export default function firecrawlMcpClientTest() {
  describe('firecrawlMcpClient', () => {
    it('exports the fixed hosted MCP contract values', 0, () => {
      expect(DEFAULT_FIRECRAWL_MCP_URL).assertEqual('https://mcp.firecrawl.dev/v2/mcp');
      expect(FIRECRAWL_MCP_READ_TIMEOUT_MS).assertEqual(60000);
    });

    it('strictly normalizes only one credential-free Firecrawl HTTP URL', 0, () => {
      const invalid: string[] = [
        'https://',
        'https://example.com/path\nhttps://evil.example/',
        'https://example.com\\@evil.example/path',
        'https://user:pass@example.com/private',
        'https://example.com:65536/path'
      ];
      for (let index = 0; index < invalid.length; index++) {
        expect(firecrawlHttpUrlOf(invalid[index])).assertEqual('');
      }
      expect(firecrawlHttpUrlOf('HTTPS://Example.COM:443/path?q=One#Top'))
        .assertEqual('https://example.com/path?q=One#Top');
    });

    it('maps every visible Firecrawl direct action to its fixed business tool', 0, () => {
      expect(directFirecrawlToolIdForActionId('web.page.read')).assertEqual('web.page.read');
      expect(directFirecrawlToolIdForActionId('web.monitor.create.confirm'))
        .assertEqual('web.monitor.create');
      const monitorActions: string[] = [
        'web.monitor.detail',
        'web.monitor.checks',
        'web.monitor.check',
        'web.monitor.run',
        'web.monitor.run.confirm',
        'web.monitor.pause',
        'web.monitor.pause.confirm',
        'web.monitor.resume',
        'web.monitor.resume.confirm',
        'web.monitor.delete',
        'web.monitor.delete.confirm'
      ];
      for (let index = 0; index < monitorActions.length; index++) {
        expect(directFirecrawlToolIdForActionId(monitorActions[index]))
          .assertEqual('web.monitor.list');
      }
      expect(directFirecrawlToolIdForActionId('web.monitor.unsupported')).assertEqual('');
    });

    it('returns needs_auth without MCP traffic when the key is missing', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config(''));

      expect(output.results.length).assertEqual(1);
      expect(output.results[0].status).assertEqual('needs_auth');
      expect(scripted.preflightRegistrations.length).assertEqual(0);
      expect(scripted.callRegistrations.length).assertEqual(0);
    });

    it('preflights all required tools once per authenticated config', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [textPayload(pagePayload()), textPayload(pagePayload())];
      const client: FirecrawlMcpClient = new FirecrawlMcpClient(scripted, (): string => TEST_TIME);

      await client.execute('web.page.read', '读取页面', '', pageArgs(), config());
      await client.execute('web.page.read', '再次读取', '', pageArgs(), config());

      expect(scripted.preflightRegistrations.length).assertEqual(1);
      expect(scripted.preflightCredentials[0]).assertEqual(TEST_KEY);
      expect(scripted.preflightRegistrations[0].transport.url).assertEqual(TEST_MCP_URL);
      expect(scripted.preflightRegistrations[0].transport.type).assertEqual('streamable_http');
      expect(Object.keys(scripted.preflightRegistrations[0].transport.headers).length).assertEqual(0);
      expect(scripted.preflightRegistrations[0].credentialRef).assertEqual('provider:firecrawl');
      expect(scripted.preflightResult.tools.map((item: DynamicMcpTool): string => item.name).join(','))
        .assertEqual(REQUIRED_TOOLS.join(','));
      expect(scripted.callCredentials.join(',')).assertEqual(TEST_KEY + ',' + TEST_KEY);
    });

    it('rejects an incomplete authenticated MCP tool list before a business call', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.preflightResult = successfulPreflight(REQUIRED_TOOLS.slice(0, 9));
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());

      expect(output.results[0].status).assertEqual('error');
      expect(scripted.callRegistrations.length).assertEqual(0);
    });

    it('maps preflight authentication failures without a business call', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.preflightResult = failedPreflight(401, 'Unauthorized');
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());

      expect(output.results[0].status).assertEqual('needs_auth');
      expect(scripted.callRegistrations.length).assertEqual(0);
    });

    it('honors a preflight needs_auth status without an HTTP code', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.preflightResult = failedPreflight(0, 'OAuth credential required');
      scripted.preflightResult.status = 'needs_auth';
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());

      expect(output.results[0].status).assertEqual('needs_auth');
      expect(scripted.callRegistrations.length).assertEqual(0);
    });

    it('honors an inferred preflight credential without an auth-looking message', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      const inferred: DynamicCredentialSpec = {
        name: 'Authorization',
        description: 'Bearer credential',
        required: true,
        placement: 'header',
        scheme: 'Bearer',
        testValue: ''
      };
      scripted.preflightResult = failedPreflight(200, 'tools/list unavailable');
      scripted.preflightResult.inferredCredential = inferred;
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());

      expect(output.results[0].status).assertEqual('needs_auth');
      expect(scripted.callRegistrations.length).assertEqual(0);
    });

    it('rejects non-HTTP page URLs locally', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs('file:///data/private/page.html'), config());

      expect(output.results[0].status).assertEqual('error');
      expect(scripted.preflightRegistrations.length).assertEqual(0);
      expect(scripted.callRegistrations.length).assertEqual(0);
    });

    it('rejects malformed, controlled, multiple, and non-string URLs locally', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      const invalidArgs: Object[] = [
        pageArgs('https://'),
        pageArgs('http:///missing-host'),
        pageArgs('https://example.com/\tprivate'),
        pageArgs('https://one.example https://two.example'),
        pageArgs('https://user:pass@example.com/private'),
        pageArgs('https://example.com\\private'),
        pageArgs('https://-bad.example/path'),
        pageArgs('https://bad_.example/path'),
        pageArgs('https://example..com/path'),
        pageArgs('http://256.1.1.1/path'),
        pageArgs('https://example.com:notaport'),
        pageArgs('https://example.com:0'),
        pageArgs('https://example.com:65536'),
        pageArgs('https://[2001:db8::1'),
        pageArgs('https://[not-ipv6]/'),
        JSON.parse('{"url":["https://one.example","https://two.example"]}') as Object,
        JSON.parse('{"url":123}') as Object
      ];
      const client: FirecrawlMcpClient = new FirecrawlMcpClient(scripted);
      for (let index = 0; index < invalidArgs.length; index++) {
        const output: FirecrawlToolOutput = await client.execute(
          'web.page.read', '读取页面', '', invalidArgs[index], config()
        );
        expect(output.results[0].status).assertEqual('error');
      }

      expect(scripted.preflightRegistrations.length).assertEqual(0);
      expect(scripted.callRegistrations.length).assertEqual(0);
    });

    it('rejects numeric overflow hosts and unverified A-labels locally', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      const invalidUrls: string[] = [
        'https://4294967296/',
        'https://123/',
        'https://xn--invalid.example/path',
        'https://XN--bcher-kva.example/path'
      ];
      const client: FirecrawlMcpClient = new FirecrawlMcpClient(scripted);

      for (let index = 0; index < invalidUrls.length; index++) {
        const output: FirecrawlToolOutput = await client.execute(
          'web.page.read', '读取页面', '', pageArgs(invalidUrls[index]), config()
        );
        expect(output.results[0].status).assertEqual('error');
      }

      expect(scripted.preflightRegistrations.length).assertEqual(0);
      expect(scripted.callRegistrations.length).assertEqual(0);
    });

    it('accepts and normalizes valid domain IPv4 and conservative IPv6 URLs', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      const inputs: string[] = [
        'HTTPS://Example.COM:443/path?q=One#Section',
        'http://192.168.001.010:8080/path?x=1#top',
        'https://[2001:DB8::1]:8443/path?x=1#top'
      ];
      const expected: string[] = [
        'https://example.com/path?q=One#Section',
        'http://192.168.1.10:8080/path?x=1#top',
        'https://[2001:db8::1]:8443/path?x=1#top'
      ];
      scripted.responses = [
        successfulPayload(pagePayload()),
        successfulPayload(pagePayload()),
        successfulPayload(pagePayload())
      ];
      const client: FirecrawlMcpClient = new FirecrawlMcpClient(scripted);

      for (let index = 0; index < inputs.length; index++) {
        const output: FirecrawlToolOutput = await client.execute(
          'web.page.read', '读取页面', '', pageArgs(inputs[index]), config()
        );
        expect(output.results[0].status).assertEqual('success');
        expect(JSON.stringify(scripted.callArgs[index])).assertEqual(
          '{"url":' + JSON.stringify(expected[index]) +
          ',"formats":["markdown"],"onlyMainContent":true}'
        );
      }
    });

    it('parses the current scrape text response into one source-bound result', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [textPayload(pagePayload())];
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted, (): string => TEST_TIME)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());
      const result: DynamicGenericToolResult = output.results[0];

      expect(output.title).assertEqual('网页读取');
      expect(output.intent).assertEqual('web.page.read');
      expect(output.results.length).assertEqual(1);
      expect(result.sourceTag).assertEqual('Firecrawl');
      expect(result.toolName).assertEqual('web.page.read');
      expect(result.title).assertEqual('Firecrawl Monitor');
      expect(result.status).assertEqual('success');
      expect(result.summary.indexOf('tracks public page changes')).assertLarger(-1);
      expect(rowValue(result.rows, 'URL')).assertEqual(TEST_URL);
      expect(rowValue(result.rows, '抓取时间')).assertEqual(TEST_TIME);
      expect(rowValue(result.rows, '发布时间')).assertEqual('2026-07-22T00:00:00.000Z');
      expect(rowValue(result.rows, 'Provider 状态')).assertEqual('success');
      expect(rowValue(result.rows, 'Credits')).assertEqual('1');
      expect(result.actions?.length).assertEqual(1);
      expect(JSON.stringify(result.actions?.[0])).assertEqual(
        '{"id":"web.open.source","label":"打开原网页","prompt":' + JSON.stringify(TEST_URL) +
        ',"kind":"client","variant":"secondary"}'
      );
    });

    it('prefers structuredContent over the text JSON fallback', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(
          pagePayload('Structured response wins.'),
          JSON.stringify(pagePayload('Text fallback must not win.'))
        )
      ];
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());

      expect(output.results[0].summary.indexOf('Structured response wins.')).assertLarger(-1);
      expect(output.results[0].summary.indexOf('Text fallback')).assertEqual(-1);
    });

    it('ignores successful raw response previews when normalizing provider status', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      const previews: string[] = [
        '{"result":{"content":[{"text":"Guide to API key authentication"}]}}',
        '{"result":{"content":[{"text":"Credits and payment required policies"}]}}',
        '{"result":{"content":[{"text":"How rate limits work"}]}}',
        '{"result":{"content":[{"text":"Login and CAPTCHA accessibility notes"}]}}'
      ];
      scripted.responses = previews.map((preview: string): McpToolCallResult =>
        successfulPayload(pagePayload(), '', preview)
      );
      const client: FirecrawlMcpClient = new FirecrawlMcpClient(scripted);

      for (let index = 0; index < previews.length; index++) {
        const output: FirecrawlToolOutput = await client.execute(
          'web.page.read', '读取页面', '', pageArgs(), config()
        );
        expect(output.results[0].status).assertEqual('success');
      }
    });

    it('keeps terminal-looking successful warnings display-only', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [successfulPayload(JSON.parse(
        '{"markdown":"Usable source body.",' +
        '"warnings":["request timeout guidance","credits accounting note"],' +
        '"metadata":{"sourceURL":' + JSON.stringify(TEST_URL) + ',' +
        '"warnings":["login instructions","rate limit policy"]}}'
      ) as Object)];
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());

      expect(output.results[0].status).assertEqual('success');
      expect(rowValue(output.results[0].rows, '警告')).assertEqual(
        'request timeout guidance\ncredits accounting note\nlogin instructions\nrate limit policy'
      );
    });

    it('normalizes an origin 403 envelope before constructing success', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [successfulPayload(JSON.parse(
        '{"markdown":"Provider returned an access page.",' +
        '"metadata":{"title":"Access page","sourceURL":' + JSON.stringify(TEST_URL) +
        ',"statusCode":403}}'
      ) as Object)];
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());

      expect(output.results[0].status).assertEqual('blocked_by_site');
      expect(output.results[0].actions === undefined).assertTrue();
    });

    it('does not accept a long login page as success', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [successfulPayload(pagePayload(
        'navigation '.repeat(400) + ' Please log in to continue.'
      ))];
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());

      expect(output.results[0].status).assertEqual('blocked_by_site');
    });

    it('uses markdown for a page read without a question', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [textPayload(pagePayload())];
      await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());

      expect(scripted.callRegistrations[0].mcpToolName).assertEqual('firecrawl_scrape');
      expect(JSON.stringify(scripted.callArgs[0])).assertEqual(
        '{"url":' + JSON.stringify(TEST_URL) + ',"formats":["markdown"],"onlyMainContent":true}'
      );
    });

    it('uses the fixed JSON extraction schema when a question is present', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [successfulPayload(JSON.parse(
        '{"json":{"answer":"Firecrawl Monitor tracks changes.","evidence":["Cloud checks run on a schedule."]},' +
        '"metadata":{"title":"Firecrawl Monitor","sourceURL":' + JSON.stringify(TEST_URL) + '}}'
      ) as Object)];
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '回答问题', '', questionArgs(), config());

      expect(JSON.stringify(scripted.callArgs[0])).assertEqual(
        '{"url":' + JSON.stringify(TEST_URL) + ',"formats":["json"],"jsonOptions":{' +
        '"prompt":"它如何监控网页？","schema":{"type":"object","properties":{"answer":{"type":"string"},' +
        '"evidence":{"type":"array","items":{"type":"string"}}},"required":["answer","evidence"]}},' +
        '"onlyMainContent":true}'
      );
      expect(output.results[0].summary).assertEqual('Firecrawl Monitor tracks changes.');
      expect(rowValue(output.results[0].rows, '证据')).assertEqual('Cloud checks run on a schedule.');
    });

    it('returns empty instead of rejecting when question JSON is null', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [successfulPayload(JSON.parse(
        '{"json":null,"metadata":{"title":"No answer","sourceURL":' + JSON.stringify(TEST_URL) + '}}'
      ) as Object)];
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '回答问题', '', questionArgs(), config());

      expect(output.results[0].status).assertEqual('empty');
    });

    it('uses source fallbacks instead of rejecting when metadata is null', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [successfulPayload(JSON.parse(
        '{"markdown":"Usable source content.","metadata":null}'
      ) as Object)];
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());

      expect(output.results[0].status).assertEqual('success');
      expect(rowValue(output.results[0].rows, 'URL')).assertEqual(TEST_URL);
    });

    it('ignores scalar evidence instead of rejecting a usable answer', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [successfulPayload(JSON.parse(
        '{"json":{"answer":"Usable answer.","evidence":"not-an-array"},' +
        '"metadata":{"title":"Answer","sourceURL":' + JSON.stringify(TEST_URL) + '}}'
      ) as Object)];
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '回答问题', '', questionArgs(), config());

      expect(output.results[0].status).assertEqual('success');
      expect(output.results[0].summary).assertEqual('Usable answer.');
      expect(rowValue(output.results[0].rows, '证据')).assertEqual('');
    });

    it('ignores null and scalar top-level warning collections', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(JSON.parse(
          '{"markdown":"Usable page.","warnings":"not-a-list",' +
          '"metadata":{"sourceURL":' + JSON.stringify(TEST_URL) + '}}'
        ) as Object),
        successfulPayload(JSON.parse(
          '{"markdown":"Usable page.","warnings":null,' +
          '"metadata":{"sourceURL":' + JSON.stringify(TEST_URL) + '}}'
        ) as Object)
      ];
      const client: FirecrawlMcpClient = new FirecrawlMcpClient(scripted);

      for (let index = 0; index < 2; index++) {
        const output: FirecrawlToolOutput = await client.execute(
          'web.page.read', '读取页面', '', pageArgs(), config()
        );
        expect(output.results[0].status).assertEqual('success');
        expect(rowValue(output.results[0].rows, '警告')).assertEqual('');
      }
    });

    it('ignores null and scalar metadata warning collections', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(JSON.parse(
          '{"markdown":"Usable page.","metadata":{"sourceURL":' +
          JSON.stringify(TEST_URL) + ',"warnings":"not-a-list"}}'
        ) as Object),
        successfulPayload(JSON.parse(
          '{"markdown":"Usable page.","metadata":{"sourceURL":' +
          JSON.stringify(TEST_URL) + ',"warnings":null}}'
        ) as Object)
      ];
      const client: FirecrawlMcpClient = new FirecrawlMcpClient(scripted);

      for (let index = 0; index < 2; index++) {
        const output: FirecrawlToolOutput = await client.execute(
          'web.page.read', '读取页面', '', pageArgs(), config()
        );
        expect(output.results[0].status).assertEqual('success');
        expect(rowValue(output.results[0].rows, '警告')).assertEqual('');
      }
    });

    it('bounds raw page previews and reports full-text truncation honestly', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      const longPage = 'x'.repeat(13000);
      scripted.responses = [textPayload(pagePayload(longPage)), textPayload(pagePayload(longPage))];
      const client: FirecrawlMcpClient = new FirecrawlMcpClient(scripted);

      const shortOutput: FirecrawlToolOutput = await client.execute(
        'web.page.read', '读取页面', '', pageArgs(TEST_URL, false), config()
      );
      const fullOutput: FirecrawlToolOutput = await client.execute(
        'web.page.read', '读取全文', '', pageArgs(TEST_URL, true), config()
      );

      expect(shortOutput.results[0].rawPreview.length).assertEqual(1200);
      expect(fullOutput.results[0].rawPreview.length).assertEqual(12000);
      expect(rowValue(shortOutput.results[0].rows, '正文状态')).assertEqual('已截断');
      expect(rowValue(fullOutput.results[0].rows, '正文状态')).assertEqual('已截断');
    });

    it('normalizes provider and page failures in the required order', 0, async () => {
      expect(await statusForFailure(failedPayload(401, 'Unauthorized'))).assertEqual('needs_auth');
      expect(await statusForFailure(failedPayload(402, 'Payment required'))).assertEqual('credits_exhausted');
      expect(await statusForFailure(failedPayload(400, 'Insufficient credits remaining'))).assertEqual('credits_exhausted');
      expect(await statusForFailure(failedPayload(429, 'Too many requests'))).assertEqual('rate_limited');
      expect(await statusForFailure(failedPayload(403, 'Forbidden by MCP gateway'))).assertEqual('error');
      expect(await statusForFailure(failedPayload(403, 'Invalid API key'))).assertEqual('needs_auth');
      expect(await statusForFailure(failedPayload(403, 'Bearer credential expired'))).assertEqual('needs_auth');
      expect(await statusForFailure(textErrorPayload('Login required; CAPTCHA shown')))
        .assertEqual('blocked_by_site');
      expect(await statusForFailure(failedPayload(500, 'Provider failed'))).assertEqual('error');
      expect(await statusForFailure(failedPayload(0, ''), 'request timeout after 60000 ms')).assertEqual('timeout');
      expect(await statusForFailure(successfulPayload(pagePayload('')))).assertEqual('empty');
      expect(await statusForFailure(successfulPayload(pagePayload('Please log in to continue.'))))
        .assertEqual('blocked_by_site');
    });

    it('keeps API-key evidence ahead of site-block text in isError results', 0, async () => {
      expect(await statusForFailure(
        textErrorPayload('Access denied because the Firecrawl API key is invalid')
      )).assertEqual('needs_auth');
    });

    it('keeps credit evidence ahead of site-block text in isError results', 0, async () => {
      expect(await statusForFailure(
        textErrorPayload('Access denied because insufficient credits remain')
      )).assertEqual('credits_exhausted');
    });

    it('classifies raw isError API-key text when the transport preview is empty', 0, async () => {
      expect(await statusForFailure(
        textErrorPayload('Unauthorized API key', '')
      )).assertEqual('needs_auth');
    });

    it('classifies an explicit sign-in gate in isError text as site-blocked', 0, async () => {
      expect(await statusForFailure(
        textErrorPayload('Access denied; sign in to continue')
      )).assertEqual('blocked_by_site');
    });

    it('classifies explicit forbidden-by-site text as site-blocked', 0, async () => {
      expect(await statusForFailure(
        textErrorPayload('Forbidden by site')
      )).assertEqual('blocked_by_site');
    });

    it('separates outer MCP failures from explicit origin blocking evidence', 0, async () => {
      const responses: McpToolCallResult[] = [
        failedPayload(403, 'Forbidden by MCP gateway'),
        successfulPayload(JSON.parse(
          '{"markdown":"Origin denied access","metadata":{"statusCode":401}}'
        ) as Object),
        successfulPayload(JSON.parse(
          '{"markdown":"Origin denied access","metadata":{"statusCode":403}}'
        ) as Object),
        textErrorPayload('robots.txt denied this scrape'),
        successfulPayload(JSON.parse(
          '{"success":false,"error":"Access denied; sign in to continue"}'
        ) as Object),
        successfulPayload(pagePayload('Please sign in to continue.'))
      ];
      const expected: string[] = [
        'error',
        'blocked_by_site',
        'blocked_by_site',
        'blocked_by_site',
        'blocked_by_site',
        'blocked_by_site'
      ];
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = responses;
      const client = new FirecrawlMcpClient(scripted);

      for (let index = 0; index < responses.length; index++) {
        const output = await client.execute(
          'web.page.read', '读取页面', '', pageArgs(), config()
        );
        expect(output.results[0].status).assertEqual(expected[index]);
        if (expected[index] === 'blocked_by_site') {
          expect(output.results[0].actions === undefined).assertTrue();
        }
      }
    });

    it('redacts the configured key and MCP URL from errors and raw previews', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        failedPayload(
          500,
          'Provider failed for ' + TEST_KEY + ' at ' + TEST_MCP_URL,
          'raw ' + TEST_KEY + ' ' + TEST_MCP_URL
        )
      ];
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());
      const serialized = JSON.stringify(output);

      expect(serialized.indexOf(TEST_KEY)).assertEqual(-1);
      expect(serialized.indexOf(TEST_MCP_URL)).assertEqual(-1);
      expect(serialized.indexOf('[REDACTED]')).assertLarger(-1);
    });

    it('bounds a large redacted provider error summary', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [failedPayload(
        500,
        'provider-error '.repeat(400) + TEST_KEY + ' ' + TEST_MCP_URL
      )];
      const output: FirecrawlToolOutput = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());

      expect(output.results[0].summary.length).assertLess(1201);
      expect(output.results[0].summary.indexOf(TEST_KEY)).assertEqual(-1);
      expect(output.results[0].summary.indexOf(TEST_MCP_URL)).assertEqual(-1);
    });

    it('bounds A1 to one Search and three de-duplicated Scrapes with truthful partial sources', 0, async () => {
      const firstUrl = 'https://example.com/one';
      const secondUrl = 'https://example.com/two';
      const thirdUrl = 'https://news.example/three';
      const fourthUrl = 'https://example.com/four';
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(searchPayload([
          searchItem(firstUrl, 'One', 'Search description one'),
          searchItem(firstUrl, 'One duplicate', 'Duplicate must be removed'),
          searchItem(secondUrl, 'Two', 'Search description two'),
          searchItem(thirdUrl, 'Three', 'Search description three'),
          searchItem(fourthUrl, 'Four', 'Search description four')
        ])),
        successfulPayload(pagePayload('Deep content one.')),
        successfulPayload(pagePayload('请先登录后继续')),
        successfulPayload(pagePayload('Deep content three.'))
      ];
      const args: ResearchArgs = {
        query: 'Firecrawl 的能力',
        domains: [' Example.COM ', 'example.com', 'NEWS.example'],
        maxResults: 99,
        recency: ' qdr:w '
      };
      const output = await new FirecrawlMcpClient(scripted, (): string => TEST_TIME)
        .execute('web.research.search', '请比较并总结多个公开来源', '', args, config());

      expect(output.intent).assertEqual('web.research.search');
      expect(scripted.callRegistrations.map((item): string => item.mcpToolName).join(','))
        .assertEqual('firecrawl_search,firecrawl_scrape,firecrawl_scrape,firecrawl_scrape');
      expect(JSON.stringify(scripted.callArgs[0])).assertEqual(
        '{"query":"Firecrawl 的能力","tbs":"qdr:w","highlights":true,"limit":10,' +
        '"includeDomains":["example.com","news.example"],"sources":[{"type":"web"}]}'
      );
      expect(JSON.stringify(scripted.callArgs.slice(1))).assertEqual(
        '[{"url":' + JSON.stringify(firstUrl) + ',"formats":["markdown"],"onlyMainContent":true},' +
        '{"url":' + JSON.stringify(secondUrl) + ',"formats":["markdown"],"onlyMainContent":true},' +
        '{"url":' + JSON.stringify(thirdUrl) + ',"formats":["markdown"],"onlyMainContent":true}]'
      );
      expect(output.results[0].status).assertEqual('partial');
      const first = resultForUrl(output.results, firstUrl);
      const second = resultForUrl(output.results, secondUrl);
      const fourth = resultForUrl(output.results, fourthUrl);
      expect(first.status).assertEqual('success');
      expect(second.status).assertEqual('blocked_by_site');
      expect(second.summary.indexOf('Search description two')).assertLarger(-1);
      expect(fourth.status).assertEqual('success');
      expectSourceActions(first, firstUrl);
      expectSourceActions(second, secondUrl);
      expectSourceActions(fourth, fourthUrl);
    });

    it('rejects supplied invalid A1 domains locally instead of widening to all web', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      const args: ResearchArgs = {
        query: 'single result',
        domains: [' ', 'https://not-a-domain.example/path'],
        maxResults: 0
      };
      const output = await new FirecrawlMcpClient(scripted)
        .execute('web.research.search', '搜索网页', '', args, config());

      expect(output.results[0].status).assertEqual('error');
      expect(output.results[0].summary.indexOf('hostname') >= 0).assertTrue();
      expect(scripted.preflightRegistrations.length).assertEqual(0);
      expect(scripted.callRegistrations.length).assertEqual(0);
    });

    it('searches the fixed shopping pool once with a clean product query', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(searchPayload([]))
      ];
      await new FirecrawlMcpClient(scripted).execute(
        'shopping.research',
        '商品比价',
        '',
        { query: '戴森 V12 Detect Slim Fluffy 返回 5 条' } as ShoppingArgs,
        config()
      );

      expect(scripted.callArgs.length).assertEqual(1);
      expect(JSON.stringify(scripted.callArgs[0])).assertEqual(
        '{"query":"戴森 V12 Detect Slim Fluffy","highlights":true,"limit":12,' +
        '"includeDomains":["zol.com.cn","pconline.com.cn","jd.com","tmall.com",' +
        '"taobao.com","idealo.de","amazon.com","bestbuy.com","bhphotovideo.com"],' +
        '"sources":[{"type":"web"}]}'
      );
    });

    it('emits two independently linked platform offers from one evidence page', 0,
      async () => {
        const zolUrl = 'https://detail.zol.com.cn/2106/2105469/price.shtml';
        const jdUrl = 'https://item.jd.com/iphone-16-pro-256';
        const taobaoUrl = 'https://item.taobao.com/item.htm?id=160256';
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [
          successfulPayload(searchPayload([
            searchItem(zolUrl, '苹果 iPhone 16 Pro 256GB 比价')
          ])),
          successfulPayload(offerPayload(zolUrl, [
            {
              name: 'Apple iPhone 16 Pro',
              brand: 'Apple',
              model: 'iPhone 16 Pro',
              variant: '256GB 黑色钛金属',
              platform: '京东',
              seller: 'Apple 产品京东自营旗舰店',
              offerUrl: jdUrl,
              evidenceUrl: zolUrl,
              market: 'CN',
              currency: 'CNY',
              priceText: '¥6999'
            },
            {
              name: 'Apple iPhone 16 Pro',
              brand: 'Apple',
              model: 'iPhone 16 Pro',
              variant: '256GB 黑色钛金属',
              platform: '淘宝',
              seller: '认证数码店',
              offerUrl: taobaoUrl,
              evidenceUrl: zolUrl,
              market: 'CN',
              currency: 'CNY',
              priceText: '¥6888'
            }
          ]))
        ];
        const partials: FirecrawlToolOutput[] = [];

        const output = await new FirecrawlMcpClient(scripted).execute(
          'shopping.research',
          '商品比价',
          '',
          { query: 'iPhone 16 Pro 256GB 黑色钛金属现在多少钱' } as ShoppingArgs,
          config(),
          (partial: FirecrawlToolOutput): void => {
            partials.push(partial);
          }
        );

        expect(scripted.callArgs.length).assertEqual(2);
        expect(JSON.stringify(scripted.callArgs[1]).indexOf('"proxy":"basic"'))
          .assertLarger(-1);
        expect(rowValue(output.results[0].rows, '平台')).assertEqual('淘宝');
        expect(rowValue(output.results[1].rows, '平台')).assertEqual('京东');
        expect(rowValue(output.results[0].rows, '数据页面')).assertEqual(zolUrl);
        expect(rowValue(output.results[1].rows, '数据页面')).assertEqual(zolUrl);
        expect(rowValue(output.results[2].rows, '来源数')).assertEqual('2');
        expect(partials.length).assertEqual(2);
        expect(partials[0].results.length).assertEqual(1);
        expect(partials[1].results.length).assertEqual(2);
      });

    it('deduplicates the same platform offer URL from one evidence page', 0, async () => {
      const pageUrl = 'https://detail.zol.com.cn/2106/2105469/price.shtml';
      const offerUrl = 'https://item.jd.com/iphone-16-pro-256';
      const offer: ProductFixture = {
        name: 'Apple iPhone 16 Pro',
        brand: 'Apple',
        model: 'iPhone 16 Pro',
        variant: '256GB 黑色钛金属',
        platform: '京东',
        offerUrl: offerUrl,
        evidenceUrl: pageUrl,
        market: 'CN',
        currency: 'CNY',
        priceText: '¥6999'
      };
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(searchPayload([
          searchItem(pageUrl, '苹果 iPhone 16 Pro 256GB 比价')
        ])),
        successfulPayload(offerPayload(pageUrl, [offer, offer]))
      ];

      const output = await new FirecrawlMcpClient(scripted).execute(
        'shopping.research',
        '商品比价',
        '',
        { query: 'iPhone 16 Pro 256GB 黑色钛金属现在多少钱' } as ShoppingArgs,
        config()
      );

      expect(output.results.length).assertEqual(2);
      expect(rowValue(output.results[1].rows, '来源数')).assertEqual('1');
    });

    it('keeps one publisher reference when an aggregator offer has no merchant URL', 0,
      async () => {
        const pageUrl = 'https://detail.zol.com.cn/2106/2105469/price.shtml';
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [
          successfulPayload(searchPayload([
            searchItem(pageUrl, '苹果 iPhone 16 Pro 256GB 比价')
          ])),
          successfulPayload(offerPayload(pageUrl, [{
            name: 'Apple iPhone 16 Pro 256GB 黑色钛金属',
            brand: 'Apple',
            model: 'iPhone 16 Pro',
            variant: '',
            platform: '京东',
            market: 'CN',
            currency: 'CNY',
            priceText: '6999'
          }]))
        ];

        const output = await new FirecrawlMcpClient(scripted).execute(
          'shopping.research',
          '商品比价',
          '',
          { query: 'iPhone 16 Pro 256GB 黑色钛金属现在多少钱' } as ShoppingArgs,
          config()
        );

        expect(output.results.length).assertEqual(2);
        expect(rowValue(output.results[0].rows, '平台')).assertEqual('中关村在线');
        expect(rowValue(output.results[0].rows, 'URL')).assertEqual(pageUrl);
        expect(rowValue(output.results[0].rows, '数据页面')).assertEqual(pageUrl);
      });

    it('stops after three invalid pooled Scrapes', 0, async () => {
      const urls: string[] = [
        'https://zol.com.cn/v12-a',
        'https://zol.com.cn/v12-b',
        'https://zol.com.cn/v12-c',
        'https://zol.com.cn/v12-d'
      ];
      const scripted = new ScriptedGenericMcpClient();
      scripted.callHandler = async (
        registration: DynamicToolRegistration,
        _credentialValue: string,
        _args: Object
      ): Promise<McpToolCallResult> => {
        if (registration.mcpToolName === 'firecrawl_search') {
          return successfulPayload(searchPayload(urls.map((url: string): Object =>
            searchItem(url, '戴森 V12 Detect Slim Fluffy')
          )));
        }
        return successfulPayload(JSON.parse(
          '{"success":false,"error":"blocked","creditsUsed":1}'
        ) as Object);
      };

      const output = await new FirecrawlMcpClient(scripted).execute(
        'shopping.research',
        '商品比价',
        '',
        { query: '戴森 V12 Detect Slim Fluffy 现在多少钱' } as ShoppingArgs,
        config()
      );

      expect(scripted.callArgs.length).assertEqual(4);
      expect(output.results.length).assertEqual(1);
      expect(rowValue(output.results[0].rows, '来源数')).assertEqual('0');
      expect(rowValue(output.results[0].rows, 'Scrape Credits')).assertEqual('3');
    });

    it('keeps international offers outside the China comparison key', 0, async () => {
      const pageUrl = 'https://detail.zol.com.cn/v12-price';
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(searchPayload([
          searchItem(pageUrl, '戴森 V12 Detect Slim Fluffy')
        ])),
        successfulPayload(offerPayload(pageUrl, [
          {
            name: '戴森 V12 Detect Slim Fluffy',
            brand: '戴森',
            model: 'V12 Detect Slim Fluffy',
            platform: '京东',
            offerUrl: 'https://item.jd.com/v12',
            evidenceUrl: pageUrl,
            market: 'CN',
            currency: 'CNY',
            priceText: '¥3999'
          },
          {
            name: '戴森 Dyson V12 Detect Slim Fluffy',
            brand: 'Dyson',
            model: 'V12 Detect Slim Fluffy',
            platform: 'Amazon',
            offerUrl: 'https://amazon.com/dp/v12',
            evidenceUrl: pageUrl,
            market: 'US',
            currency: 'USD',
            priceText: '$549'
          }
        ]))
      ];

      const output = await new FirecrawlMcpClient(scripted).execute(
        'shopping.research',
        '商品比价',
        '',
        { query: '戴森 V12 Detect Slim Fluffy 现在多少钱' } as ShoppingArgs,
        config()
      );
      const china = resultForUrl(output.results, 'https://item.jd.com/v12');
      const international = resultForUrl(output.results, 'https://amazon.com/dp/v12');

      expect(rowValue(china.rows, 'comparisonKey') ===
        rowValue(international.rows, 'comparisonKey')).assertFalse();
      expect(rowValue(international.rows, 'comparisonEligible')).assertEqual('false');
      expect(output.results[2].summary).assertEqual('来源规格不同，暂不计算最低价。');
    });

    it('uses one pooled Search while maxProducts caps every visible result set', 0,
      async () => {
        const zolUrl = 'https://zol.com.cn/v12';
        const pcUrl = 'https://pconline.com.cn/v12';
        const scripted = new ScriptedGenericMcpClient();
        scripted.callHandler = async (
          registration: DynamicToolRegistration,
          _credentialValue: string,
          args: Object
        ): Promise<McpToolCallResult> => {
          const raw = JSON.stringify(args);
          if (registration.mcpToolName === 'firecrawl_search') {
            return successfulPayload(searchPayload([
              searchItem(zolUrl, '戴森 V12 Detect Slim Fluffy'),
              searchItem(pcUrl, '戴森 V12 Detect Slim Fluffy')
            ]));
          }
          const isPc = raw.indexOf(pcUrl) >= 0;
          const url = isPc ? pcUrl : zolUrl;
          return successfulPayload(productPayload(url, {
            name: '戴森 V12 Detect Slim Fluffy',
            brand: '戴森',
            model: 'V12 Detect Slim Fluffy',
            priceText: isPc ? '¥3,899' : '¥3,999'
          }));
        };
        const partials: FirecrawlToolOutput[] = [];

        const output = await new FirecrawlMcpClient(scripted).execute(
          'shopping.research',
          '商品比价',
          '',
          {
            query: '戴森 V12 Detect Slim Fluffy 现在多少钱',
            maxProducts: 1
          } as ShoppingArgs,
          config(),
          (partial: FirecrawlToolOutput): void => {
            partials.push(partial);
          }
        );
        const searchCalls = scripted.callRegistrations.filter(
          (item: DynamicToolRegistration): boolean => item.mcpToolName === 'firecrawl_search'
        );

        expect(searchCalls.length).assertEqual(1);
        expect(JSON.stringify(scripted.callArgs).indexOf(
          '"includeDomains":["zol.com.cn","pconline.com.cn"'
        )).assertLarger(-1);
        expect(partials.length).assertEqual(1);
        expect(partials[0].results.length).assertEqual(1);
        expect(output.results.length).assertEqual(2);
        expect(rowValue(output.results[1].rows, '来源数')).assertEqual('1');
      });

    it('removes only shopping instructions from fixed-source Search queries', 0, async () => {
      const queries: string[] = [
        '索尼 WH-1000XM6 黑色现在多少钱',
        '戴森 V12 Detect Slim Fluffy 各平台价格',
        '乐高 10333 巴拉都比价'
      ];
      const expectedQueries: string[] = [
        '索尼 WH-1000XM6 黑色',
        '戴森 V12 Detect Slim Fluffy',
        '乐高 10333 巴拉都'
      ];
      for (let index = 0; index < queries.length; index++) {
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [successfulPayload(searchPayload([]))];
        await new FirecrawlMcpClient(scripted).execute(
          'shopping.research',
          '商品比价',
          '',
          { query: queries[index] } as ShoppingArgs,
          config()
        );

        expect(scripted.callArgs.length).assertEqual(1);
        expect((scripted.callArgs[0] as Record<string, Object>).query as string)
          .assertEqual(expectedQueries[index]);
      }
    });

    it('intersects requested shopping domains with the fixed source set', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [successfulPayload(searchPayload([]))];
      const args: ShoppingArgs = {
        query: '戴森 V12 Detect Slim Fluffy 现在多少钱',
        domains: ['PCONLINE.com.cn', 'taobao.com', 'pconline.com.cn']
      };
      await new FirecrawlMcpClient(scripted).execute(
        'shopping.research', '商品比价', '', args, config()
      );

      expect(scripted.callArgs.length).assertEqual(1);
      expect(JSON.stringify(scripted.callArgs[0])).assertEqual(
        '{"query":"戴森 V12 Detect Slim Fluffy","highlights":true,"limit":12,' +
        '"includeDomains":["pconline.com.cn","taobao.com"],"sources":[{"type":"web"}]}'
      );
    });

    it('returns truthful empty output when a requested supported source has no result', 0,
      async () => {
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [successfulPayload(searchPayload([]))];
        const args: ShoppingArgs = {
          query: '戴森 V12 Detect Slim Fluffy 现在多少钱',
          domains: ['taobao.com']
        };
        const output = await new FirecrawlMcpClient(scripted).execute(
          'shopping.research', '商品比价', '', args, config()
        );

        expect(output.results[0].status).assertEqual('empty');
        expect(output.results[0].summary).assertEqual(
          '暂未找到可核验的同款公开价格。'
        );
        expect(scripted.preflightRegistrations.length).assertEqual(1);
        expect(scripted.callRegistrations.length).assertEqual(1);
      });

    it('Scrapes the best matching pooled candidate first', 0, async () => {
      const accessoryUrl = 'https://detail.zol.com.cn/accessory';
      const productUrl = 'https://detail.zol.com.cn/vacuum';
      const scripted = new ScriptedGenericMcpClient();
      scripted.callHandler = async (
        registration: DynamicToolRegistration,
        _credentialValue: string,
        args: Object
      ): Promise<McpToolCallResult> => {
        if (registration.mcpToolName === 'firecrawl_search') {
          return successfulPayload(searchPayload([
            searchItem(accessoryUrl, '戴森 V12 滤芯配件'),
            searchItem(productUrl, '戴森 V12 Detect Slim Fluffy 吸尘器')
          ]));
        }
        const raw = JSON.stringify(args);
        return raw.indexOf(productUrl) >= 0 ?
          successfulPayload(productPayload(productUrl, {
            name: '戴森 V12 Detect Slim Fluffy 吸尘器',
            brand: '戴森',
            model: 'V12 Detect Slim Fluffy',
            priceText: '¥3,999'
          })) :
          successfulPayload(productPayload(accessoryUrl, {
            name: '戴森 V12 滤芯配件',
            brand: '戴森',
            model: 'V12 滤芯',
            priceText: '¥199'
          }));
      };

      await new FirecrawlMcpClient(scripted).execute(
        'shopping.research',
        '商品比价',
        '',
        {
          query: '戴森 V12 Detect Slim Fluffy 现在多少钱',
          domains: ['zol.com.cn']
        } as ShoppingArgs,
        config()
      );

      expect(scripted.callArgs.length).assertEqual(3);
      expect(JSON.stringify(scripted.callArgs[1]).indexOf(productUrl)).assertLarger(-1);
      expect(JSON.stringify(scripted.callArgs[2]).indexOf(accessoryUrl)).assertLarger(-1);
    });

    it('keeps Search order when fixed-source shopping candidates have equal scores', 0,
      async () => {
        const firstUrl = 'https://detail.zol.com.cn/vacuum-first';
        const secondUrl = 'https://detail.zol.com.cn/vacuum-second';
        const scripted = new ScriptedGenericMcpClient();
        scripted.callHandler = async (
          registration: DynamicToolRegistration,
          _credentialValue: string,
          args: Object
        ): Promise<McpToolCallResult> => {
          if (registration.mcpToolName === 'firecrawl_search') {
            return successfulPayload(searchPayload([
              searchItem(firstUrl, '戴森 V12 Detect Slim Fluffy'),
              searchItem(secondUrl, '戴森 V12 Detect Slim Fluffy')
            ]));
          }
          const raw = JSON.stringify(args);
          const url = raw.indexOf(firstUrl) >= 0 ? firstUrl : secondUrl;
          return successfulPayload(productPayload(url, {
            name: '戴森 V12 Detect Slim Fluffy',
            brand: '戴森',
            model: 'V12 Detect Slim Fluffy',
            priceText: '¥3,999'
          }));
        };

        await new FirecrawlMcpClient(scripted).execute(
          'shopping.research',
          '商品比价',
          '',
          {
            query: '戴森 V12 Detect Slim Fluffy 现在多少钱',
            domains: ['zol.com.cn']
          } as ShoppingArgs,
          config()
        );

        expect(scripted.callArgs.length).assertEqual(3);
        expect(JSON.stringify(scripted.callArgs[1]).indexOf(firstUrl)).assertLarger(-1);
        expect(JSON.stringify(scripted.callArgs[2]).indexOf(secondUrl)).assertLarger(-1);
      });

    it('uses one-character model evidence to choose the matching shopping candidate', 0,
      async () => {
        const wrongUrl = 'https://detail.zol.com.cn/x70';
        const matchingUrl = 'https://detail.zol.com.cn/p70';
        const scripted = new ScriptedGenericMcpClient();
        scripted.callHandler = async (
          registration: DynamicToolRegistration,
          _credentialValue: string,
          args: Object
        ): Promise<McpToolCallResult> => {
          if (registration.mcpToolName === 'firecrawl_search') {
            return successfulPayload(searchPayload([
              searchItem(wrongUrl, '华为 X 70'),
              searchItem(matchingUrl, '华为 P 70')
            ]));
          }
          const raw = JSON.stringify(args);
          const isMatching = raw.indexOf(matchingUrl) >= 0;
          const url = isMatching ? matchingUrl : wrongUrl;
          return successfulPayload(productPayload(url, {
            name: isMatching ? '华为 P 70' : '华为 X 70',
            brand: '华为',
            model: isMatching ? 'P 70' : 'X 70',
            priceText: '¥3,999'
          }));
        };

        const output = await new FirecrawlMcpClient(scripted).execute(
          'shopping.research',
          '商品比价',
          '',
          {
            query: '华为 P 70 现在多少钱',
            domains: ['zol.com.cn'],
            maxProducts: 1
          } as ShoppingArgs,
          config()
        );

        expect(scripted.callArgs.length).assertEqual(2);
        expect(JSON.stringify(scripted.callArgs[1]).indexOf(matchingUrl)).assertLarger(-1);
        expect(rowValue(output.results[0].rows, 'URL')).assertEqual(matchingUrl);
      });

    it('emits a true partial while the second fixed shopping source is still pending', 0,
      async () => {
        const zolUrl = 'https://zol.com.cn/v12';
        const pcUrl = 'https://pconline.com.cn/v12';
        const zolProduct: ProductFixture = {
          name: '戴森 V12 Detect Slim Fluffy',
          brand: '戴森',
          model: 'V12 Detect Slim Fluffy',
          priceText: '¥3,999'
        };
        const pcProduct: ProductFixture = {
          name: '戴森 V12 Detect Slim Fluffy',
          brand: '戴森',
          model: 'V12 Detect Slim Fluffy',
          priceText: '¥3,899'
        };
        const scripted = new ScriptedGenericMcpClient();
        let releaseSecond: () => void = (): void => {};
        let resolveFirstPartial: () => void = (): void => {};
        const secondGate = new Promise<void>((resolve: () => void): void => {
          releaseSecond = resolve;
        });
        const firstPartial = new Promise<void>((resolve: () => void): void => {
          resolveFirstPartial = resolve;
        });
        scripted.callHandler = async (
          registration: DynamicToolRegistration,
          _credentialValue: string,
          args: Object
        ): Promise<McpToolCallResult> => {
          const raw = JSON.stringify(args);
          if (registration.mcpToolName === 'firecrawl_search') {
            return successfulPayload(searchPayload([
              searchItem(zolUrl, '戴森 V12 Detect Slim Fluffy'),
              searchItem(pcUrl, '戴森 V12 Detect Slim Fluffy')
            ]));
          }
          if (raw.indexOf(zolUrl) >= 0) {
            return successfulPayload(productPayload(zolUrl, zolProduct));
          }
          await secondGate;
          return successfulPayload(productPayload(pcUrl, pcProduct));
        };
        const partials: FirecrawlToolOutput[] = [];
        const client = new FirecrawlMcpClient(scripted);

        const outputPromise = client.execute(
          'shopping.research',
          '商品比价',
          '',
          { query: '戴森 V12 Detect Slim Fluffy 现在多少钱' } as ShoppingArgs,
          config(),
          (partial: FirecrawlToolOutput): void => {
            partials.push(partial);
            if (partials.length === 1) {
              resolveFirstPartial();
            }
          }
        );
        await firstPartial;
        expect(partials.length).assertEqual(1);
        expect(partials[0].results.length).assertEqual(1);
        releaseSecond();
        const output = await outputPromise;

        expect(partials.length).assertEqual(2);
        expect(partials[1].results.length).assertEqual(2);
        expect(partials[0].results[0].rows.some(
          (row: A2uiLabelValueData): boolean => row.label === '来源数'
        )).assertFalse();
        expect(output.results.length).assertEqual(3);
      });

    it('isolates a failed pooled candidate without rendering a failure card', 0,
      async () => {
        const zolUrl = 'https://zol.com.cn/v12';
        const pcUrl = 'https://pconline.com.cn/v12';
        const scripted = new ScriptedGenericMcpClient();
        scripted.callHandler = async (
          registration: DynamicToolRegistration,
          _credentialValue: string,
          args: Object
        ): Promise<McpToolCallResult> => {
          const raw = JSON.stringify(args);
          if (registration.mcpToolName === 'firecrawl_search') {
            return successfulPayload(JSON.parse(
              '{"success":true,"data":{"web":[{"url":' + JSON.stringify(zolUrl) +
              ',"title":"戴森 V12 Detect Slim Fluffy"},{"url":' + JSON.stringify(pcUrl) +
              ',"title":"戴森 V12 Detect Slim Fluffy"}]},"creditsUsed":2}'
            ) as Object);
          }
          if (raw.indexOf(zolUrl) >= 0) {
            return successfulPayload(JSON.parse(
              '{"success":false,"error":"ZOL unavailable","creditsUsed":3,' +
              '"warnings":["zol scrape warning"]}'
            ) as Object);
          }
          return successfulPayload(JSON.parse(
            '{"json":{"name":"戴森 V12 Detect Slim Fluffy","brand":"戴森",' +
            '"model":"V12 Detect Slim Fluffy","priceText":"¥3,899"},' +
            '"metadata":{"sourceURL":' + JSON.stringify(pcUrl) + '},"creditsUsed":1}'
          ) as Object);
        };

        const output = await new FirecrawlMcpClient(scripted).execute(
          'shopping.research',
          '商品比价',
          '',
          { query: '戴森 V12 Detect Slim Fluffy 现在多少钱' } as ShoppingArgs,
          config()
        );
        const sourceResults = output.results.filter((result: DynamicGenericToolResult): boolean =>
          result.title !== '商品研究综述'
        );

        expect(sourceResults.length).assertEqual(1);
        expect(rowValue(sourceResults[0].rows, 'URL')).assertEqual(pcUrl);
        expect(output.results.length).assertEqual(2);
        expect(output.results[1].summary).assertEqual('来源不足，暂不能形成比价。');
        expect(rowValue(output.results[1].rows, 'Search Credits')).assertEqual('2');
        expect(rowValue(output.results[1].rows, 'Scrape Credits')).assertEqual('4');
        expect(JSON.stringify(output.results[1].rows).indexOf('zol scrape warning'))
          .assertLarger(-1);
        expect(JSON.stringify(output).indexOf('ZOL unavailable')).assertEqual(-1);
      });

    it('keeps post-Scrape rejection usage in the overview without a source card', 0,
      async () => {
        const url = 'https://zol.com.cn/v12-no-price';
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [
          successfulPayload(JSON.parse(
            '{"success":true,"data":{"web":[{"url":' + JSON.stringify(url) +
            ',"title":"戴森 V12 Detect Slim Fluffy"}]},"creditsUsed":2}'
          ) as Object),
          successfulPayload(JSON.parse(
            '{"json":{"name":"戴森 V12 Detect Slim Fluffy","brand":"戴森",' +
            '"model":"V12 Detect Slim Fluffy"},"metadata":{"sourceURL":' +
            JSON.stringify(url) + '},"creditsUsed":4,"warnings":["rejected scrape warning"]}'
          ) as Object)
        ];

        const output = await new FirecrawlMcpClient(scripted).execute(
          'shopping.research',
          '商品比价',
          '',
          {
            query: '戴森 V12 Detect Slim Fluffy 现在多少钱',
            domains: ['zol.com.cn']
          } as ShoppingArgs,
          config()
        );

        expect(output.results.length).assertEqual(1);
        expect(output.results[0].title).assertEqual('商品研究综述');
        expect(rowValue(output.results[0].rows, '来源数')).assertEqual('0');
        expect(rowValue(output.results[0].rows, 'Search Credits')).assertEqual('2');
        expect(rowValue(output.results[0].rows, 'Scrape Credits')).assertEqual('4');
        expect(JSON.stringify(output.results[0].rows).indexOf('rejected scrape warning'))
          .assertLarger(-1);
        expect(JSON.stringify(output).indexOf(url)).assertEqual(-1);
      });

    it('sorts comparable shopping sources by price and reports comparison counts', 0,
      async () => {
        const zolUrl = 'https://zol.com.cn/v12';
        const pcUrl = 'https://pconline.com.cn/v12';
        const scripted = new ScriptedGenericMcpClient();
        scripted.callHandler = async (
          registration: DynamicToolRegistration,
          _credentialValue: string,
          args: Object
        ): Promise<McpToolCallResult> => {
          const raw = JSON.stringify(args);
          if (registration.mcpToolName === 'firecrawl_search') {
            return successfulPayload(searchPayload([
              searchItem(zolUrl, '戴森 V12 Detect Slim Fluffy'),
              searchItem(pcUrl, '戴森 V12 Detect Slim Fluffy')
            ]));
          }
          const isPc = raw.indexOf(pcUrl) >= 0;
          const url = isPc ? pcUrl : zolUrl;
          return successfulPayload(productPayload(url, {
            name: '戴森 V12 Detect Slim Fluffy',
            brand: '戴森',
            model: 'V12 Detect Slim Fluffy',
            priceText: isPc ? '¥3,899' : '¥3,999'
          }));
        };

        const output = await new FirecrawlMcpClient(scripted).execute(
          'shopping.research',
          '商品比价',
          '',
          { query: '戴森 V12 Detect Slim Fluffy 现在多少钱' } as ShoppingArgs,
          config()
        );
        const overview = output.results[2];

        expect(rowValue(output.results[0].rows, 'URL')).assertEqual(pcUrl);
        expect(rowValue(output.results[1].rows, 'URL')).assertEqual(zolUrl);
        expect(rowValue(overview.rows, '来源数')).assertEqual('2');
        expect(rowValue(overview.rows, '可比来源数')).assertEqual('2');
        expect(overview.summary).assertEqual('已找到 2 个同规格公开价格来源。');
      });

    it('groups observed Sony and 索尼 brand aliases for the same model and variant', 0,
      async () => {
        const zolUrl = 'https://detail.zol.com.cn/2141/2140050/param.shtml';
        const pcUrl = 'https://best.pconline.com.cn/youhui/16182052.html';
        const scripted = new ScriptedGenericMcpClient();
        scripted.callHandler = async (
          registration: DynamicToolRegistration,
          _credentialValue: string,
          args: Object
        ): Promise<McpToolCallResult> => {
          const raw = JSON.stringify(args);
          if (registration.mcpToolName === 'firecrawl_search') {
            return successfulPayload(searchPayload([
              searchItem(zolUrl, '索尼 WH-1000XM6 黑色'),
              searchItem(pcUrl, '索尼 WH-1000XM6 黑色')
            ]));
          }
          const isPc = raw.indexOf(pcUrl) >= 0;
          const url = isPc ? pcUrl : zolUrl;
          return successfulPayload(productPayload(url, {
            name: isPc ? '索尼（SONY）WH-1000XM6 黑色' : '索尼WH-1000XM6',
            brand: isPc ? '索尼（SONY）' : '索尼',
            model: 'WH-1000XM6',
            variant: '黑色',
            salePriceText: isPc ? '3699元' : '￥2610'
          }));
        };

        const output = await new FirecrawlMcpClient(scripted).execute(
          'shopping.research',
          '商品比价',
          '',
          { query: '索尼 WH-1000XM6 黑色现在多少钱' } as ShoppingArgs,
          config()
        );
        const overview = output.results[2];
        const firstKey = rowValue(output.results[0].rows, 'comparisonKey');
        const secondKey = rowValue(output.results[1].rows, 'comparisonKey');

        expect(firstKey).assertEqual(secondKey);
        expect(rowValue(overview.rows, '可比来源数')).assertEqual('2');
        expect(overview.summary).assertEqual('已找到 2 个同规格公开价格来源。');
      });

    it('groups observed Dyson brand aliases and treats 无 as an absent variant', 0,
      async () => {
        const zolUrl = 'https://detail.zol.com.cn/ProductComp_param_1800700-1372341.html';
        const pcUrl = 'https://best.pconline.com.cn/youhui/15738269.html';
        const scripted = new ScriptedGenericMcpClient();
        scripted.callHandler = async (
          registration: DynamicToolRegistration,
          _credentialValue: string,
          args: Object
        ): Promise<McpToolCallResult> => {
          const raw = JSON.stringify(args);
          if (registration.mcpToolName === 'firecrawl_search') {
            return successfulPayload(searchPayload([
              searchItem(zolUrl, '戴森 V12 Detect Slim Fluffy'),
              searchItem(pcUrl, '戴森 V12 Detect Slim Fluffy')
            ]));
          }
          const isPc = raw.indexOf(pcUrl) >= 0;
          const url = isPc ? pcUrl : zolUrl;
          return successfulPayload(productPayload(url, {
            name: '戴森 V12 Detect Slim Fluffy',
            brand: isPc ? 'dyson' : 'dyson（戴森）',
            model: 'V12 Detect Slim Fluffy',
            variant: isPc ? '无' : '',
            salePriceText: isPc ? '3399元' : '¥4490'
          }));
        };

        const output = await new FirecrawlMcpClient(scripted).execute(
          'shopping.research',
          '商品比价',
          '',
          { query: '戴森 V12 Detect Slim Fluffy 现在多少钱' } as ShoppingArgs,
          config()
        );
        const overview = output.results[2];
        const firstKey = rowValue(output.results[0].rows, 'comparisonKey');
        const secondKey = rowValue(output.results[1].rows, 'comparisonKey');

        expect(firstKey).assertEqual(secondKey);
        expect(firstKey).assertEqual('CN|CNY|dyson v12 detect slim fluffy');
        expect(rowValue(overview.rows, '可比来源数')).assertEqual('2');
        expect(overview.summary).assertEqual('已找到 2 个同规格公开价格来源。');
      });

    it('infers a missing shopping brand from the exact product name', 0,
      async () => {
        const zolUrl = 'https://detail.zol.com.cn/dyson-v12';
        const pcUrl = 'https://best.pconline.com.cn/dyson-v12';
        const scripted = new ScriptedGenericMcpClient();
        scripted.callHandler = async (
          registration: DynamicToolRegistration,
          _credentialValue: string,
          args: Object
        ): Promise<McpToolCallResult> => {
          const raw = JSON.stringify(args);
          if (registration.mcpToolName === 'firecrawl_search') {
            return successfulPayload(searchPayload([
              searchItem(zolUrl, '戴森 V12 Detect Slim Fluffy'),
              searchItem(pcUrl, '戴森 V12 Detect Slim Fluffy')
            ]));
          }
          const isPc = raw.indexOf(pcUrl) >= 0;
          const url = isPc ? pcUrl : zolUrl;
          return successfulPayload(productPayload(url, {
            name: '戴森 V12 Detect Slim Fluffy',
            brand: isPc ? 'dyson' : '',
            model: 'V12 Detect Slim Fluffy',
            salePriceText: isPc ? '3399元' : '¥4490'
          }));
        };

        const output = await new FirecrawlMcpClient(scripted).execute(
          'shopping.research',
          '商品比价',
          '',
          { query: '戴森 V12 Detect Slim Fluffy 现在多少钱' } as ShoppingArgs,
          config()
        );
        const overview = output.results[2];

        expect(rowValue(output.results[0].rows, 'comparisonKey'))
          .assertEqual(rowValue(output.results[1].rows, 'comparisonKey'));
        expect(rowValue(overview.rows, '可比来源数')).assertEqual('2');
        expect(overview.summary).assertEqual('已找到 2 个同规格公开价格来源。');
      });

    it('ignores an absent sale-price placeholder and uses the explicit RMB price', 0,
      async () => {
        const source = await shoppingProductResult('小米米家空气净化器 4 Pro 现在多少钱', {
          name: '米家空气净化器4Pro',
          brand: '米家',
          model: '空气净化器4Pro',
          variant: '无',
          priceText: '¥589',
          salePriceText: '无'
        });
        const rows = source?.rows as A2uiLabelValueData[];

        expect(source === null).assertFalse();
        expect(rowValue(rows, '价格')).assertEqual('¥589');
        expect(rowValue(rows, '销售价')).assertEqual('');
        expect(rowValue(rows, 'comparisonEligible')).assertEqual('true');
        expect(rowValue(rows, 'comparisonPriceFen')).assertEqual('58900');
      });

    it('does not treat a coupon saving as the observed sale price', 0,
      async () => {
        const source = await shoppingProductResult('索尼 WH-1000XM6 黑色现在多少钱', {
          name: '索尼 WH-1000XM6 黑色',
          brand: '索尼',
          model: 'WH-1000XM6',
          variant: '黑色',
          priceText: '3699元',
          salePriceText: '券后省300'
        });
        const rows = source?.rows as A2uiLabelValueData[];

        expect(source === null).assertFalse();
        expect(rowValue(rows, '价格')).assertEqual('3699元');
        expect(rowValue(rows, '销售价')).assertEqual('');
        expect(rowValue(rows, 'comparisonEligible')).assertEqual('true');
        expect(rowValue(rows, 'comparisonPriceFen')).assertEqual('369900');
      });

    it('falls through currency-denominated savings to the observed product price', 0,
      async () => {
        const savings: string[] = ['券后省300元', '立减¥300', '优惠￥200'];
        for (let index = 0; index < savings.length; index++) {
          const source = await shoppingProductResult('索尼 WH-1000XM6 黑色现在多少钱', {
            name: '索尼 WH-1000XM6 黑色',
            brand: '索尼',
            model: 'WH-1000XM6',
            variant: '黑色',
            priceText: '3699元',
            salePriceText: savings[index]
          });
          const rows = source?.rows as A2uiLabelValueData[];

          expect(source === null).assertFalse();
          expect(rowValue(rows, '价格')).assertEqual('3699元');
          expect(rowValue(rows, '销售价')).assertEqual('');
          expect(rowValue(rows, 'comparisonEligible')).assertEqual('true');
          expect(rowValue(rows, 'comparisonPriceFen')).assertEqual('369900');
        }
      });

    it('accepts explicit coupon and final price phrases as comparable prices', 0,
      async () => {
        const explicitPrices: string[] = ['券后价¥2999', '到手价2999元'];
        for (let index = 0; index < explicitPrices.length; index++) {
          const source = await shoppingProductResult('索尼 WH-1000XM6 黑色现在多少钱', {
            name: '索尼 WH-1000XM6 黑色',
            brand: '索尼',
            model: 'WH-1000XM6',
            variant: '黑色',
            priceText: '3699元',
            salePriceText: explicitPrices[index]
          });
          const rows = source?.rows as A2uiLabelValueData[];

          expect(source === null).assertFalse();
          expect(rowValue(rows, '价格')).assertEqual(explicitPrices[index]);
          expect(rowValue(rows, '销售价')).assertEqual(explicitPrices[index]);
          expect(rowValue(rows, 'comparisonEligible')).assertEqual('true');
          expect(rowValue(rows, 'comparisonPriceFen')).assertEqual('299900');
        }
      });

    it('does not declare a lowest price when fixed-source product specifications differ', 0,
      async () => {
        const zolUrl = 'https://zol.com.cn/v12-standard';
        const pcUrl = 'https://pconline.com.cn/v12-light';
        const scripted = new ScriptedGenericMcpClient();
        scripted.callHandler = async (
          registration: DynamicToolRegistration,
          _credentialValue: string,
          args: Object
        ): Promise<McpToolCallResult> => {
          const raw = JSON.stringify(args);
          if (registration.mcpToolName === 'firecrawl_search') {
            return successfulPayload(searchPayload([
              searchItem(zolUrl, '戴森 V12 Detect Slim Fluffy'),
              searchItem(pcUrl, '戴森 V12 Detect Slim Fluffy')
            ]));
          }
          const isPc = raw.indexOf(pcUrl) >= 0;
          const url = isPc ? pcUrl : zolUrl;
          return successfulPayload(productPayload(url, {
            name: '戴森 V12 Detect Slim Fluffy',
            brand: '戴森',
            model: 'V12 Detect Slim Fluffy',
            variant: isPc ? '轻量版' : '标准版',
            priceText: isPc ? '¥3,899' : '¥3,999'
          }));
        };

        const output = await new FirecrawlMcpClient(scripted).execute(
          'shopping.research',
          '商品比价',
          '',
          { query: '戴森 V12 Detect Slim Fluffy 现在多少钱' } as ShoppingArgs,
          config()
        );
        const overview = output.results[2];

        expect(rowValue(overview.rows, '可比来源数')).assertEqual('2');
        expect(overview.summary).assertEqual('来源规格不同，暂不计算最低价。');
      });

    it('reports insufficient comparable prices for same-key mixed price evidence', 0,
      async () => {
        const zolUrl = 'https://zol.com.cn/v12-starting-price';
        const pcUrl = 'https://pconline.com.cn/v12-price';
        const scripted = new ScriptedGenericMcpClient();
        scripted.callHandler = async (
          registration: DynamicToolRegistration,
          _credentialValue: string,
          args: Object
        ): Promise<McpToolCallResult> => {
          const raw = JSON.stringify(args);
          if (registration.mcpToolName === 'firecrawl_search') {
            return successfulPayload(searchPayload([
              searchItem(zolUrl, '戴森 V12 Detect Slim Fluffy'),
              searchItem(pcUrl, '戴森 V12 Detect Slim Fluffy')
            ]));
          }
          const isPc = raw.indexOf(pcUrl) >= 0;
          const url = isPc ? pcUrl : zolUrl;
          return successfulPayload(productPayload(url, {
            name: '戴森 V12 Detect Slim Fluffy',
            brand: '戴森',
            model: 'V12 Detect Slim Fluffy',
            priceText: isPc ? '¥3,899' : '¥3,999起'
          }));
        };

        const output = await new FirecrawlMcpClient(scripted).execute(
          'shopping.research',
          '商品比价',
          '',
          { query: '戴森 V12 Detect Slim Fluffy 现在多少钱' } as ShoppingArgs,
          config()
        );
        const overview = output.results[2];

        expect(rowValue(overview.rows, '来源数')).assertEqual('2');
        expect(rowValue(overview.rows, '可比来源数')).assertEqual('1');
        expect(overview.summary).assertEqual('来源不足，暂不能形成比价。');
      });

    it('classifies only explicit single RMB prices as comparable shopping evidence', 0, async () => {
      const cases: PriceFixture[] = [
        { priceText: '¥2,999', comparable: 'true', fen: '299900' },
        { priceText: '2999元', comparable: 'true', fen: '299900' },
        { estimatedPriceText: '预估到手 ¥2,899', comparable: 'true', fen: '289900',
          kind: 'estimated', displayLabel: '预估到手价' },
        { priceText: '¥2999起', comparable: 'false', fen: '0' },
        { priceText: '¥2999-3299', comparable: 'false', fen: '0' },
        { priceText: '$349', comparable: 'false', fen: '0' }
      ];
      for (let index = 0; index < cases.length; index++) {
        const priceCase = cases[index];
        const product: ProductFixture = {
          name: '商品 Test Phone',
          brand: 'Test',
          priceText: priceCase.priceText,
          estimatedPriceText: priceCase.estimatedPriceText
        };
        const source = await shoppingProductResult('商品价格', product);

        expect(source === null).assertFalse();
        expect(rowValue(source?.rows as A2uiLabelValueData[], 'comparisonEligible'))
          .assertEqual(priceCase.comparable);
        expect(rowValue(source?.rows as A2uiLabelValueData[], 'comparisonPriceFen'))
          .assertEqual(priceCase.fen);
        expect(rowValue(source?.rows as A2uiLabelValueData[], 'comparisonPriceKind'))
          .assertEqual(priceCase.kind === undefined ? 'public' : priceCase.kind);
        if (priceCase.displayLabel !== undefined) {
          expect(rowValue(source?.rows as A2uiLabelValueData[], priceCase.displayLabel))
            .assertEqual(priceCase.estimatedPriceText as string);
        }
      }
    });

    it('projects explicit shopping commerce details into source rows', 0, async () => {
      const source = await shoppingProductResult('Sony WH-1000XM6 黑色', {
        name: 'Sony WH-1000XM6 黑色',
        brand: 'Sony',
        model: 'WH-1000XM6',
        variant: '黑色',
        seller: '京东自营',
        priceText: '¥3,299',
        listPriceText: '¥3,499',
        salePriceText: '¥3,199',
        estimatedPriceText: '预估到手 ¥3,099',
        couponText: '满 3000 减 100',
        shippingText: '包邮'
      });
      const rows = source?.rows as A2uiLabelValueData[];

      expect(source === null).assertFalse();
      expect(rowValue(rows, '卖家')).assertEqual('京东自营');
      expect(rowValue(rows, '标价')).assertEqual('¥3,499');
      expect(rowValue(rows, '销售价')).assertEqual('¥3,199');
      expect(rowValue(rows, '预估到手价')).assertEqual('预估到手 ¥3,099');
      expect(rowValue(rows, '优惠券')).assertEqual('满 3000 减 100');
      expect(rowValue(rows, '运费')).assertEqual('包邮');
    });

    it('does not synthesize absent shopping commerce detail rows', 0, async () => {
      const source = await shoppingProductResult('Sony WH-1000XM6 黑色', {
        name: 'Sony WH-1000XM6 黑色',
        brand: 'Sony',
        model: 'WH-1000XM6',
        variant: '黑色',
        priceText: '¥3,299'
      });
      const rows = source?.rows as A2uiLabelValueData[];

      expect(source === null).assertFalse();
      expect(rowValue(rows, '卖家')).assertEqual('');
      expect(rowValue(rows, '标价')).assertEqual('');
      expect(rowValue(rows, '销售价')).assertEqual('');
      expect(rowValue(rows, '预估到手价')).assertEqual('');
      expect(rowValue(rows, '优惠券')).assertEqual('');
      expect(rowValue(rows, '运费')).assertEqual('');
    });

    it('keeps only the exact model and explicit variant in a shopping comparison', 0, async () => {
      const query = 'iPhone 16 Pro 256GB 黑色钛金属现在多少钱';
      const exact: ProductFixture = {
        name: 'Apple iPhone 16 Pro',
        brand: 'Apple',
        model: 'iPhone 16 Pro',
        variant: '256GB 黑色钛金属',
        seller: '公开商城',
        priceText: '¥8,999'
      };
      const wrongCapacity: ProductFixture = {
        name: 'Apple iPhone 16 Pro',
        brand: 'Apple',
        model: 'iPhone 16 Pro',
        variant: '128GB 黑色钛金属',
        seller: '公开商城',
        priceText: '¥7,999'
      };
      const accessory: ProductFixture = {
        name: 'iPhone 16 Pro 手机壳',
        brand: '第三方',
        model: 'iPhone 16 Pro 保护壳',
        variant: '黑色',
        seller: '配件店',
        priceText: '¥99'
      };
      const exactResult = await shoppingProductResult(query, exact);
      const wrongCapacityResult = await shoppingProductResult(query, wrongCapacity);
      const accessoryResult = await shoppingProductResult(query, accessory);

      expect(exactResult === null).assertFalse();
      expect(wrongCapacityResult === null).assertTrue();
      expect(accessoryResult === null).assertTrue();
      expect(rowValue(exactResult?.rows as A2uiLabelValueData[], 'comparisonKey'))
        .assertEqual('CN|CNY|apple iphone 16 pro|256gb 黑色钛金属');
    });

    it('shows a matching base model when the page omits requested variant fields', 0,
      async () => {
        const source = await shoppingProductResult(
          'iPhone 16 Pro 256GB 黑色钛金属现在多少钱',
          {
            name: 'Apple iPhone 16 Pro',
            brand: 'Apple',
            model: 'iPhone 16 Pro',
            variant: '',
            currency: 'CNY',
            priceText: '6999'
          }
        );

        expect(source === null).assertFalse();
        expect(rowValue(source?.rows as A2uiLabelValueData[], '价格')).assertEqual('6999');
        expect(rowValue(source?.rows as A2uiLabelValueData[], 'comparisonEligible'))
          .assertEqual('false');
      });

    it('uses requested variant evidence from the product title for comparison', 0,
      async () => {
        const source = await shoppingProductResult(
          'iPhone 16 Pro 256GB 黑色钛金属现在多少钱',
          {
            name: 'Apple iPhone 16 Pro 256GB 黑色钛金属',
            brand: 'Apple',
            model: 'iPhone 16 Pro',
            variant: '',
            currency: 'CNY',
            priceText: '6999'
          }
        );

        expect(source === null).assertFalse();
        expect(rowValue(source?.rows as A2uiLabelValueData[], 'comparisonEligible'))
          .assertEqual('true');
        expect(rowValue(source?.rows as A2uiLabelValueData[], 'comparisonPriceFen'))
          .assertEqual('699900');
      });

    it('keeps non-accessory Mijia candidates and still rejects filters', 0,
      async () => {
        const result = await shoppingProductResult('小米米家空气净化器 4 Pro 现在多少钱', {
          name: '米家空气净化器4Pro',
          brand: 'mijia（米家）',
          model: '空气净化器4Pro',
          variant: '无',
          priceText: '¥589',
          salePriceText: '¥589'
        });
        const wrongModel = await shoppingProductResult(
          '小米米家空气净化器 4 Pro 现在多少钱',
          {
            name: '米家空气净化器4',
            brand: '米家',
            model: '米家 AC-M16-SC',
            variant: '无',
            priceText: '￥999'
          }
        );
        const filter = await shoppingProductResult(
          '小米米家空气净化器 4 Pro 现在多少钱',
          {
            name: '米家空气净化器4 Pro 滤芯',
            brand: '米家',
            model: '空气净化器4 Pro 滤芯',
            variant: '',
            priceText: '251.1元'
          }
        );

        expect(result === null).assertFalse();
        expect(result?.title).assertEqual('米家空气净化器4Pro');
        expect(rowValue(result?.rows as A2uiLabelValueData[], '价格')).assertEqual('¥589');
        expect(wrongModel === null).assertFalse();
        expect(filter === null).assertTrue();
      });

    it('keeps a valid product when the query contains natural-language words absent from the title', 0,
      async () => {
        const source = await shoppingProductResult(
          '帮我查一下 Dyson V12 Detect Slim Fluffy 的售价',
          {
            name: 'Dyson V12 Detect Slim Fluffy 无绳吸尘器',
            brand: 'Dyson',
            model: 'V12 Detect Slim Fluffy',
            variant: '',
            priceText: '¥3,399'
          }
        );

        expect(source === null).assertFalse();
        expect(source?.title).assertEqual('Dyson V12 Detect Slim Fluffy 无绳吸尘器');
      });

    it('keeps a near-name candidate so comparison grouping can separate it', 0, async () => {
      const query = 'iPhone 16 Pro 256GB 黑色钛金属现在多少钱';
      const exact: ProductFixture = {
        name: 'Apple iPhone 16 Pro', brand: 'Apple', model: 'iPhone 16 Pro',
        variant: '256GB 黑色钛金属', priceText: '¥8,999'
      };
      const nearMatch: ProductFixture = {
        name: 'Apple iPhone 16 Product', brand: 'Apple', model: 'iPhone 16 Product',
        variant: '256GB 黑色钛金属', priceText: '¥8,999'
      };
      const exactResult = await shoppingProductResult(query, exact);
      const nearResult = await shoppingProductResult(query, nearMatch);

      expect(exactResult?.title).assertEqual(exact.name);
      expect(nearResult?.title).assertEqual(nearMatch.name);
    });

    it('rejects a longer title when product model evidence is absent', 0, async () => {
      const query = 'iPhone 16 Pro 256GB 黑色钛金属现在多少钱';
      const exact: ProductFixture = {
        name: 'Apple iPhone 16 Pro', brand: 'Apple', variant: '256GB 黑色钛金属',
        priceText: '¥8,999'
      };
      const proMax: ProductFixture = {
        name: 'iPhone 16 Pro Max', brand: 'Apple', variant: '256GB 黑色钛金属',
        priceText: '¥9,999'
      };
      const exactResult = await shoppingProductResult(query, exact);
      const maxResult = await shoppingProductResult(query, proMax);

      expect(exactResult?.title).assertEqual(exact.name);
      expect(maxResult === null).assertTrue();
    });

    it('rejects a longer title when structured model omits its extra tier', 0, async () => {
      const result = await shoppingProductResult(
        'iPhone 16 Pro 256GB 黑色钛金属现在多少钱',
        {
          name: 'Apple iPhone 16 Pro Max',
          brand: 'Apple',
          model: 'iPhone 16 Pro',
          variant: '256GB 黑色钛金属',
          priceText: '7736.01元'
        }
      );

      expect(result === null).assertTrue();
    });

    it('rejects an explicit higher tier but keeps a different-brand candidate', 0, async () => {
      const query = '华为 Mate 70 Pro 午夜色 礼盒装现在多少钱';
      const exact: ProductFixture = {
        name: '华为 Mate 70 Pro', brand: '华为', model: 'Mate 70 Pro',
        variant: '午夜色 礼盒装', priceText: '¥6,999'
      };
      const proMax: ProductFixture = {
        name: '华为 Mate 70 Pro Max', brand: '华为', model: 'Mate 70 Pro Max',
        variant: '午夜色 礼盒装', priceText: '¥7,999'
      };
      const wrongBrand: ProductFixture = {
        name: '苹果 Mate 70 Pro', brand: '苹果', model: 'Mate 70 Pro',
        variant: '午夜色 礼盒装', priceText: '¥6,999'
      };
      const exactResult = await shoppingProductResult(query, exact);
      const maxResult = await shoppingProductResult(query, proMax);
      const wrongBrandResult = await shoppingProductResult(query, wrongBrand);

      expect(exactResult?.title).assertEqual(exact.name);
      expect(maxResult === null).assertTrue();
      expect(wrongBrandResult?.title).assertEqual(wrongBrand.name);
    });

    it('requires query-specified free-form color and bundle evidence in the variant', 0, async () => {
      const query = '华为 Mate 70 Pro 午夜色 礼盒装现在多少钱';
      const exact: ProductFixture = {
        name: '华为 Mate 70 Pro', brand: '华为', model: 'Mate 70 Pro',
        variant: '午夜色 礼盒装', priceText: '¥6,999'
      };
      const wrongColor: ProductFixture = {
        name: '华为 Mate 70 Pro', brand: '华为', model: 'Mate 70 Pro',
        variant: '星空色 礼盒装', priceText: '¥6,999'
      };
      const wrongBundle: ProductFixture = {
        name: '华为 Mate 70 Pro', brand: '华为', model: 'Mate 70 Pro',
        variant: '午夜色 普通装', priceText: '¥6,999'
      };
      const exactResult = await shoppingProductResult(query, exact);
      const wrongColorResult = await shoppingProductResult(query, wrongColor);
      const wrongBundleResult = await shoppingProductResult(query, wrongBundle);

      expect(exactResult?.title).assertEqual(exact.name);
      expect(wrongColorResult === null).assertTrue();
      expect(wrongBundleResult === null).assertTrue();
    });

    it('extracts natural-language color and bundle suffix terms without requiring the prose', 0, async () => {
      const query = '我想要午夜色的 Mate 70 Pro 我想要礼盒装的现在多少钱';
      const exact: ProductFixture = {
        name: 'Mate 70 Pro', brand: '华为', model: 'Mate 70 Pro',
        variant: '午夜色 礼盒装', priceText: '¥6,999'
      };
      const wrongColor: ProductFixture = {
        name: 'Mate 70 Pro', brand: '华为', model: 'Mate 70 Pro',
        variant: '星空色 礼盒装', priceText: '¥6,999'
      };
      const wrongBundle: ProductFixture = {
        name: 'Mate 70 Pro', brand: '华为', model: 'Mate 70 Pro',
        variant: '午夜色 普通装', priceText: '¥6,999'
      };
      const exactResult = await shoppingProductResult(query, exact);
      const wrongColorResult = await shoppingProductResult(query, wrongColor);
      const wrongBundleResult = await shoppingProductResult(query, wrongBundle);

      expect(exactResult?.title).assertEqual(exact.name);
      expect(wrongColorResult === null).assertTrue();
      expect(wrongBundleResult === null).assertTrue();
    });

    it('uses one pooled Search, basic Scrapes and no purchase actions', 0, async () => {
      const urls: string[] = [
        'https://zol.com.cn/v12',
        'https://pconline.com.cn/v12'
      ];
      const scripted = new ScriptedGenericMcpClient();
      scripted.callHandler = async (
        registration: DynamicToolRegistration,
        _credentialValue: string,
        args: Object
      ): Promise<McpToolCallResult> => {
        const raw = JSON.stringify(args);
        if (registration.mcpToolName === 'firecrawl_search') {
          return successfulPayload(searchPayload([
            searchItem(urls[0], '戴森 V12 Detect Slim Fluffy'),
            searchItem(urls[1], '戴森 V12 Detect Slim Fluffy')
          ]));
        }
        const isPc = raw.indexOf(urls[1]) >= 0;
        return successfulPayload(productPayload(isPc ? urls[1] : urls[0], {
          name: '戴森 V12 Detect Slim Fluffy',
          brand: '戴森',
          model: 'V12 Detect Slim Fluffy',
          priceText: isPc ? '¥3899' : '¥3999'
        }));
      };
      const output = await new FirecrawlMcpClient(scripted, (): string => TEST_TIME)
        .execute('shopping.research', '比较商品', '', {
          query: '戴森 V12 Detect Slim Fluffy 现在多少钱',
          maxProducts: 99,
          preferences: [' 预算 5000 元 ', '长续航', '长续航', ' ']
        } as ShoppingArgs, config());

      expect(scripted.callRegistrations.map((item): string => item.mcpToolName).join(','))
        .assertEqual('firecrawl_search,firecrawl_scrape,firecrawl_scrape');
      expect(JSON.stringify(scripted.callArgs[1]).indexOf('"proxy":"basic"'))
        .assertLarger(-1);
      expect(JSON.stringify(scripted.callArgs[2]).indexOf('"proxy":"basic"'))
        .assertLarger(-1);
      expect(output.results.length).assertEqual(3);
      expect(rowValue(output.results[0].rows, '检索偏好')).assertEqual('预算 5000 元；长续航');
      const serializedActions = JSON.stringify(output.results.map((result) => result.actions));
      expect(serializedActions.indexOf('inventory')).assertEqual(-1);
      expect(serializedActions.indexOf('checkout')).assertEqual(-1);
      expect(serializedActions.indexOf('order')).assertEqual(-1);
      expect(serializedActions.indexOf('payment')).assertEqual(-1);
      expectSourceActions(output.results[0], urls[1]);
      expectSourceActions(output.results[1], urls[0]);
    });

    it('bounds normalized A3 preferences without displacing source evidence', 0, async () => {
      const shortUrl = 'https://zol.com.cn/short';
      const shortScripted = new ScriptedGenericMcpClient();
      shortScripted.responses = [
        successfulPayload(searchPayload([searchItem(shortUrl, '耳机 Short preferences')])),
        successfulPayload(productPayload(shortUrl, {
          name: '耳机 Short', brand: 'Brand', priceText: '¥299'
        }))
      ];
      const shortArgs: ShoppingArgs = {
        query: '耳机',
        domains: ['zol.com.cn'],
        maxProducts: 1,
        preferences: ['一', '二', '三', '四', '五', '六']
      };
      const shortOutput = await new FirecrawlMcpClient(shortScripted)
        .execute('shopping.research', '比较商品', '', shortArgs, config());

      expect(JSON.stringify(shortScripted.callArgs[0])).assertEqual(
        '{"query":"耳机 一；二；三；四；五","highlights":true,"limit":12,' +
        '"includeDomains":["zol.com.cn"],"sources":[{"type":"web"}]}'
      );
      expect(rowValue(shortOutput.results[0].rows, '检索偏好')).assertEqual('一；二；三；四；五');

      const first = '甲'.repeat(100);
      const second = '乙'.repeat(100);
      const third = '丙'.repeat(100);
      const expected = '甲'.repeat(80) + '；' + '乙'.repeat(80) + '；' + '丙'.repeat(78);
      const longUrl = 'https://zol.com.cn/long';
      const longScripted = new ScriptedGenericMcpClient();
      longScripted.responses = [
        successfulPayload(searchPayload([searchItem(longUrl, '耳机 Long preferences')])),
        successfulPayload(productPayload(longUrl, {
          name: '耳机 Long', brand: 'Brand', priceText: '¥399'
        }))
      ];
      const longArgs: ShoppingArgs = {
        query: '耳机',
        domains: ['zol.com.cn'],
        maxProducts: 1,
        preferences: [' ' + first + ' ', first, second, third, '丁'.repeat(100)]
      };
      const longOutput = await new FirecrawlMcpClient(longScripted)
        .execute('shopping.research', '比较商品', '', longArgs, config());
      const preferenceRow = rowValue(longOutput.results[0].rows, '检索偏好');

      expect(JSON.stringify(longScripted.callArgs[0])).assertEqual(
        '{"query":' + JSON.stringify('耳机 ' + expected) +
        ',"highlights":true,"limit":12,"includeDomains":["zol.com.cn"],' +
        '"sources":[{"type":"web"}]}'
      );
      expect(preferenceRow).assertEqual(expected);
      expect(preferenceRow.length).assertEqual(240);
    });

    it('requires an observed price when an A3 query explicitly asks for prices', 0, async () => {
      const withoutPrice = 'https://zol.com.cn/no-price';
      const withPrice = 'https://pconline.com.cn/with-price';
      const scripted = new ScriptedGenericMcpClient();
      scripted.callHandler = async (
        registration: DynamicToolRegistration,
        _credentialValue: string,
        args: Object
      ): Promise<McpToolCallResult> => {
        const raw = JSON.stringify(args);
        if (registration.mcpToolName === 'firecrawl_search') {
          return successfulPayload(searchPayload([
            searchItem(withoutPrice, 'Sony WH-1000XM6'),
            searchItem(withPrice, 'Sony WH-1000XM6')
          ]));
        }
        return raw.indexOf(withPrice) >= 0 ?
          successfulPayload(productPayload(withPrice, {
            name: 'Sony WH-1000XM6', brand: 'Sony', priceText: '¥2,999'
          })) :
          successfulPayload(productPayload(withoutPrice, {
            name: 'Sony WH-1000XM6', brand: 'Sony'
          }));
      };
      const args: ShoppingArgs = {
        query: '比较 Sony WH-1000XM6 和 Bose QuietComfort Ultra 的公开规格与页面价格，保留来源'
      };
      const output = await new FirecrawlMcpClient(scripted)
        .execute('shopping.research', '比较商品', '', args, config());

      expect(JSON.stringify(scripted.callArgs[0])).assertEqual(
        '{"query":"比较 Sony WH-1000XM6 和 Bose QuietComfort Ultra 的公开规格与页面价格，保留来源",' +
        '"highlights":true,"limit":12,"includeDomains":["zol.com.cn","pconline.com.cn",' +
        '"jd.com","tmall.com","taobao.com","idealo.de","amazon.com","bestbuy.com",' +
        '"bhphotovideo.com"],' +
        '"sources":[{"type":"web"}]}'
      );
      expect(output.results.length).assertEqual(2);
      expect(resultForUrl(output.results, withPrice).title).assertEqual('Sony WH-1000XM6');
      expect(JSON.stringify(output.results).indexOf(withoutPrice)).assertEqual(-1);
    });

    it('continues after a budget-truncated A3 preference duplicates an earlier item', 0, async () => {
      const url = 'https://zol.com.cn/truncated-duplicate';
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(searchPayload([searchItem(url, '耳机 Truncated duplicate')])),
        successfulPayload(productPayload(url, {
          name: '耳机 Duplicate', brand: 'Brand', priceText: '¥299'
        }))
      ];
      const expected = '甲'.repeat(79) + '；' + '乙'.repeat(80) + '；丙';
      const args: ShoppingArgs = {
        query: '耳机',
        domains: ['zol.com.cn'],
        maxProducts: 1,
        preferences: ['甲'.repeat(79), '乙'.repeat(80), '甲'.repeat(80), '丙']
      };
      const output = await new FirecrawlMcpClient(scripted)
        .execute('shopping.research', '比较商品', '', args, config());
      const preferenceRow = rowValue(output.results[0].rows, '检索偏好');

      expect(preferenceRow).assertEqual(expected);
      expect(preferenceRow.length).assertLess(241);
      expect(JSON.stringify(scripted.callArgs[0])).assertEqual(
        '{"query":' + JSON.stringify('耳机 ' + expected) +
        ',"highlights":true,"limit":12,"includeDomains":["zol.com.cn"],' +
        '"sources":[{"type":"web"}]}'
      );
    });

    it('forces B1 to Xiaohongshu and keeps its indexed result when the page is restricted', 0, async () => {
      const xhsUrl = 'https://www.xiaohongshu.com/explore/one';
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(searchPayload([
          searchItem('https://www.xiaohongshu.com/download', '小红书下载页', '不应作为公开内容'),
          searchItem(xhsUrl, '小红书公开讨论', '小红书索引摘要'),
          searchItem('https://www.zhihu.com/question/two', '知乎公开讨论', '知乎索引摘要'),
          searchItem('https://www.bilibili.com/video/three', '哔哩哔哩公开讨论', '视频索引摘要')
        ])),
        successfulPayload(pagePayload('请先登录后继续'))
      ];
      const args: SocialArgs = {
        query: '鸿蒙应用开发',
        platforms: ['小红书', '知乎', '微博', '哔哩哔哩'],
        maxResults: 10,
        recency: 'qdr:m'
      };
      const output = await new FirecrawlMcpClient(scripted, (): string => TEST_TIME)
        .execute('social.public.search', '搜索公开讨论', '', args, config());

      expect(output.intent).assertEqual('social.public.search');
      expect(scripted.callRegistrations.map((item): string => item.mcpToolName).join(','))
        .assertEqual('firecrawl_search,firecrawl_scrape');
      expect(JSON.stringify(scripted.callArgs[0])).assertEqual(
        '{"query":"鸿蒙应用开发","tbs":"qdr:m","highlights":true,"limit":10,' +
        '"includeDomains":["xiaohongshu.com"],' +
        '"sources":[{"type":"web"}]}'
      );
      expect(resultWithTitle(output.results, '小红书').status).assertEqual('blocked_by_site');
      expect(resultWithTitle(output.results, '小红书').summary.indexOf('知乎')).assertEqual(-1);
      expectSourceActions(resultForUrl(output.results, xhsUrl), xhsUrl);
    });

    it('uses the authenticated Xiaohongshu browser path when hosted MCP exposes interact', 0,
      async () => {
        const sourceUrl =
          'https://www.xiaohongshu.com/search_result/note-one?xsec_token=token-one';
        const secondSourceUrl =
          'https://www.xiaohongshu.com/search_result/note-two?xsec_token=token-two';
        const coverUrl = 'https://sns-webpic-qc.xhscdn.com/note-cover.webp';
        const secondImageUrl = 'https://sns-webpic-qc.xhscdn.com/note-second.webp';
        const secondCoverUrl = 'https://sns-webpic-qc.xhscdn.com/note-two-cover.webp';
        const scripted = new ScriptedGenericMcpClient();
        scripted.preflightResult = successfulPreflight(
          REQUIRED_TOOLS.concat(['firecrawl_interact', 'firecrawl_interact_stop'])
        );
        const cards: XiaohongshuCardFixture[] = [{
          title: '鸿蒙原生应用开发',
          author: '开发者 07-24',
          published: '07-24',
          url: sourceUrl,
          coverUrl: coverUrl,
          isVideo: false
        }, {
          title: '周末城市散步路线',
          author: '散步爱好者 07-23',
          published: '07-23',
          url: secondSourceUrl,
          coverUrl: secondCoverUrl,
          isVideo: false
        }];
        const detail: XiaohongshuDetailFixture = {
          title: '鸿蒙原生应用开发',
          author: '开发者',
          description: '这是一篇真实的小红书笔记正文。',
          url: sourceUrl,
          imageUrls: [coverUrl, secondImageUrl],
          isVideo: true,
          videoDuration: 83
        };
        const secondDetail: XiaohongshuDetailFixture = {
          title: '周末城市散步路线',
          author: '散步爱好者',
          description: '第二篇笔记也返回了完整正文。',
          url: secondSourceUrl,
          imageUrls: [secondCoverUrl],
          isVideo: false,
          videoDuration: 0
        };
        scripted.responses = [
          successfulPayload(JSON.parse(
            '{"markdown":"已登录；页面外壳同时包含手机号登录和获取验证码文案",' +
            '"metadata":{"title":"鸿蒙应用开发 - 小红书搜索",' +
            '"sourceURL":"https://www.xiaohongshu.com/search_result","statusCode":200,' +
            '"scrapeId":"scrape-xhs-one"},"creditsUsed":5}'
          ) as Object),
          failedPayload(500, 'Browser session is warming up'),
          successfulPayload(interactPayload(cards)),
          successfulPayload(interactPayload(detail)),
          successfulPayload(interactPayload(secondDetail)),
          successfulPayload(JSON.parse('{"success":true,"creditsBilled":1}') as Object)
        ];
        const args: SocialArgs = {
          query: '鸿蒙应用开发',
          platforms: ['小红书'],
          maxResults: 2
        };
        const partialCounts: number[] = [];
        const output = await new FirecrawlMcpClient(scripted, (): string => TEST_TIME)
          .execute(
            'social.public.search',
            '搜索公开讨论',
            '',
            args,
            config(),
            (partial: FirecrawlToolOutput): void => {
              partialCounts.push(partial.results.length);
            }
          );

        expect(JSON.stringify(partialCounts)).assertEqual('[1,2]');
        expect(scripted.callRegistrations.map((item): string => item.mcpToolName).join(','))
          .assertEqual(
            'firecrawl_scrape,firecrawl_interact,firecrawl_interact,' +
            'firecrawl_interact,firecrawl_interact,firecrawl_interact_stop'
          );
        expect(JSON.stringify(scripted.callArgs[0])).assertEqual(
          '{"url":"https://www.xiaohongshu.com/search_result?keyword=' +
          '%E9%B8%BF%E8%92%99%E5%BA%94%E7%94%A8%E5%BC%80%E5%8F%91&source=web_search_result_notes",' +
          '"formats":["markdown"],"onlyMainContent":false,"waitFor":5000,"maxAge":0,' +
          '"storeInCache":false,"proxy":"auto","profile":{' +
          '"name":"aiphone-xiaohongshu-login","saveChanges":true}}'
        );
        const detailArgs = scripted.callArgs[3] as InteractArgsFixture;
        expect((detailArgs.code === undefined ? '' : detailArgs.code).indexOf(
          'agent-browser open "' + sourceUrl + '" >/dev/null'
        )).assertLarger(-1);
        const source = resultForUrl(output.results, sourceUrl);
        expect(source.status).assertEqual('success');
        expect(source.title).assertEqual('鸿蒙原生应用开发');
        expect(source.summary).assertEqual('这是一篇真实的小红书笔记正文。');
        expect(rowValue(source.rows, '作者')).assertEqual('开发者');
        expect(rowValue(source.rows, '完整正文')).assertEqual(
          '这是一篇真实的小红书笔记正文。'
        );
        expect(rowValue(source.rows, '封面图')).assertEqual(coverUrl);
        expect(rowValue(source.rows, '图片列表')).assertEqual(
          coverUrl + '\n' + secondImageUrl
        );
        expect(rowValue(source.rows, '图片数量')).assertEqual('2');
        expect(rowValue(source.rows, '内容类型')).assertEqual('视频');
        expect(rowValue(source.rows, '视频时长')).assertEqual('1:23');
        expect(source.actions?.length).assertEqual(0);
        const secondDetailArgs = scripted.callArgs[4] as InteractArgsFixture;
        expect((secondDetailArgs.code === undefined ? '' : secondDetailArgs.code).indexOf(
          'agent-browser open "' + secondSourceUrl + '" >/dev/null'
        )).assertLarger(-1);
        const secondSource = resultForUrl(output.results, secondSourceUrl);
        expect(secondSource.status).assertEqual('success');
        expect(secondSource.summary).assertEqual('第二篇笔记也返回了完整正文。');
        expect(rowValue(secondSource.rows, '完整正文')).assertEqual(
          '第二篇笔记也返回了完整正文。'
        );
        expect(secondSource.actions?.length).assertEqual(0);
        expect(resultWithTitle(output.results, '小红书').status).assertEqual('success');
      });

    it('keeps one empty Xiaohongshu status card when Search is empty', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [successfulPayload(searchPayload([]))];
      const args: SocialArgs = {
        query: '没有公开结果的查询',
        platforms: ['小红书', '微博']
      };
      const output = await new FirecrawlMcpClient(scripted)
        .execute('social.public.search', '搜索公开讨论', '', args, config());

      expect(output.results.length).assertEqual(2);
      expect(resultWithTitle(output.results, '小红书').status).assertEqual('empty');
      expect(scripted.callRegistrations.length).assertEqual(1);
    });

    it('reports B1 partial when one platform has blocked and search-only public sources', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(searchPayload([
          searchItem('https://www.xiaohongshu.com/explore/blocked', '受限结果', '公开索引摘要'),
          searchItem('https://www.zhihu.com/question/ok', '知乎结果', '知乎索引摘要'),
          searchItem('https://www.xiaohongshu.com/explore/indexed', '索引结果', '另一条公开索引摘要')
        ])),
        successfulPayload(pagePayload('请先登录后继续')),
        successfulPayload(pagePayload('知乎公开正文'))
      ];
      const args: SocialArgs = {
        query: '鸿蒙应用开发',
        platforms: ['小红书']
      };
      const output = await new FirecrawlMcpClient(scripted)
        .execute('social.public.search', '搜索公开讨论', '', args, config());

      expect(resultWithTitle(output.results, '小红书').status).assertEqual('partial');
    });

    it('keeps B1 platform cards strict when indexed evidence has non-site Scrape failures', 0, async () => {
      const failures: McpToolCallResult[] = [
        failedPayload(0, 'request timeout after 60000 ms'),
        failedPayload(429, 'Too many requests'),
        failedPayload(401, 'Unauthorized'),
        failedPayload(500, 'Provider failed')
      ];
      const allowed: string[] = ['success', 'partial', 'empty', 'blocked_by_site'];
      for (let index = 0; index < failures.length; index++) {
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [
          successfulPayload(searchPayload([
            searchItem(
              'https://www.xiaohongshu.com/explore/' + index.toString(),
              '公开索引结果',
              '已有可核验的 Search 摘要'
            )
          ])),
          failures[index]
        ];
        const args: SocialArgs = {
          query: '鸿蒙应用开发',
          platforms: ['小红书']
        };
        const output = await new FirecrawlMcpClient(scripted)
          .execute('social.public.search', '搜索公开讨论', '', args, config());
        const platform = resultWithTitle(output.results, '小红书');

        expect(platform.status).assertEqual('partial');
        expect(allowed.indexOf(platform.status)).assertLarger(-1);
      }
    });

    it('aggregates B1 success and blocked sources to partial independent of order', 0, async () => {
      const firstUrl = 'https://www.xiaohongshu.com/explore/first';
      const secondUrl = 'https://www.xiaohongshu.com/explore/second';
      const responseOrders: McpToolCallResult[][] = [
        [
          successfulPayload(pagePayload('公开正文')),
          successfulPayload(pagePayload('登录即可查看完整内容'))
        ],
        [
          successfulPayload(pagePayload('登录即可查看完整内容')),
          successfulPayload(pagePayload('公开正文'))
        ]
      ];
      for (let index = 0; index < responseOrders.length; index++) {
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [
          successfulPayload(searchPayload([
            searchItem(firstUrl, '第一条', '第一条索引摘要'),
            searchItem(secondUrl, '第二条', '第二条索引摘要')
          ]))
        ].concat(responseOrders[index]);
        const args: SocialArgs = {
          query: '鸿蒙应用开发',
          platforms: ['小红书']
        };
        const output = await new FirecrawlMcpClient(scripted)
          .execute('social.public.search', '搜索公开讨论', '', args, config());

        expect(resultWithTitle(output.results, '小红书').status).assertEqual('partial');
      }
    });

    it('does not block a normal long article merely discussing CAPTCHA or login', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      const article = (
        '本文分析公开网站如何设计访问提示、错误恢复和无障碍体验，并提供可验证的技术背景。'
      ).repeat(80) + ' 文中也会讨论 CAPTCHA 和 login 对用户体验的影响。';
      scripted.responses = [successfulPayload(pagePayload(article))];
      const output = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());

      expect(output.results[0].status).assertEqual('success');
    });

    it('blocks short login verification and app-only shell pages without bypassing them', 0, async () => {
      const shells: string[] = [
        '登录即可查看完整内容',
        '请输入验证码以完成安全验证',
        '打开 App 查看完整内容'
      ];
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = shells.map((body: string): McpToolCallResult =>
        successfulPayload(pagePayload(body))
      );
      const client = new FirecrawlMcpClient(scripted);
      for (let index = 0; index < shells.length; index++) {
        const output = await client.execute(
          'web.page.read', '读取页面', '', pageArgs(), config()
        );
        expect(output.results[0].status).assertEqual('blocked_by_site');
      }
    });

    it('does not treat bare gate-related words in a normal short article as a shell', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [successfulPayload(pagePayload(
        '这篇短文比较 CAPTCHA 与验证码的可访问性，也说明如何打开小红书查看作者公开发布的内容。'
      ))];
      const output = await new FirecrawlMcpClient(scripted)
        .execute('web.page.read', '读取页面', '', pageArgs(), config());

      expect(output.results[0].status).assertEqual('success');
    });

    it('treats null Search data as empty instead of throwing', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [successfulPayload(JSON.parse(
        '{"success":true,"data":null,"id":"null-data"}'
      ) as Object)];
      let output: FirecrawlToolOutput | null = null;
      let thrown = '';
      try {
        const args: ResearchArgs = { query: '公开资料' };
        output = await new FirecrawlMcpClient(scripted)
          .execute('web.research.search', '搜索网页', '', args, config());
      } catch (error) {
        thrown = error instanceof Error ? error.message : 'unknown error';
      }

      expect(thrown).assertEqual('');
      expect(output === null).assertFalse();
      if (output !== null) {
        expect(output.results[0].status).assertEqual('empty');
      }
    });

    it('filters malformed Search web entries before URL validation', 0, async () => {
      const validUrl = 'https://example.com/valid';
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [successfulPayload(JSON.parse(
        '{"success":true,"data":{"web":[null,7,"bad",{},{"url":"file:///private"},' +
        '{"url":' + JSON.stringify(validUrl) +
        ',"title":"Valid","description":"可核验摘要"}]}}'
      ) as Object)];
      let output: FirecrawlToolOutput | null = null;
      let thrown = '';
      try {
        const args: ResearchArgs = { query: '公开资料' };
        output = await new FirecrawlMcpClient(scripted)
          .execute('web.research.search', '搜索网页', '', args, config());
      } catch (error) {
        thrown = error instanceof Error ? error.message : 'unknown error';
      }

      expect(thrown).assertEqual('');
      expect(output === null).assertFalse();
      if (output !== null) {
        expect(output.results.length).assertEqual(2);
        expect(rowValue(output.results[1].rows, 'URL')).assertEqual(validUrl);
      }
    });

    it('de-duplicates normalized Search URLs without counting fragments as sources', 0, async () => {
      const firstUrl = 'https://example.com/article#intro';
      const duplicateUrl = 'https://example.com/article#details';
      const secondUrl = 'https://example.com/other';
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(searchPayload([
          searchItem(firstUrl, 'Article', 'Intro'),
          searchItem(duplicateUrl, 'Article duplicate', 'Details'),
          searchItem(secondUrl, 'Other', 'Other source')
        ])),
        successfulPayload(pagePayload('Article body')),
        successfulPayload(pagePayload('Other body')),
        successfulPayload(pagePayload('Unexpected duplicate body'))
      ];
      const args: ResearchArgs = {
        query: '公开资料',
        maxResults: 10
      };
      const output = await new FirecrawlMcpClient(scripted)
        .execute('web.research.search', '请研究并总结', '', args, config());

      expect(scripted.callRegistrations.length).assertEqual(3);
      expect(JSON.stringify(scripted.callArgs.slice(1))).assertEqual(
        '[{"url":' + JSON.stringify(firstUrl) +
        ',"formats":["markdown"],"onlyMainContent":true},{"url":' +
        JSON.stringify(secondUrl) + ',"formats":["markdown"],"onlyMainContent":true}]'
      );
      expect(output.results.length).assertEqual(3);
    });

    it('previews a bounded page monitor with defaults and no MCP mutation', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      const args: MonitorCreateArgs = {
        pages: [
          'https://example.com/1',
          'https://example.com/2',
          'https://example.com/3',
          'https://example.com/4',
          'https://example.com/5',
          'https://example.com/6'
        ],
        goal: '跟踪公开页面更新',
        name: '公开页面监控',
        email: 'alerts@example.com'
      };
      const output = await new FirecrawlMcpClient(scripted)
        .execute('web.monitor.create', '创建监控', '', args, config());

      expect(scripted.preflightRegistrations.length).assertEqual(0);
      expect(scripted.callRegistrations.length).assertEqual(0);
      expect(output.results[0].status).assertEqual('confirm_required');
      expect(rowValue(output.results[0].rows, '页面数')).assertEqual('5');
      expect(rowValue(output.results[0].rows, 'Monitor 名称')).assertEqual('公开页面监控');
      expect(rowValue(output.results[0].rows, '页面 1')).assertEqual('https://example.com/1');
      expect(rowValue(output.results[0].rows, '页面 2')).assertEqual('https://example.com/2');
      expect(rowValue(output.results[0].rows, '页面 3')).assertEqual('https://example.com/3');
      expect(rowValue(output.results[0].rows, '页面 4')).assertEqual('https://example.com/4');
      expect(rowValue(output.results[0].rows, '页面 5')).assertEqual('https://example.com/5');
      expect(rowValue(output.results[0].rows, '目标')).assertEqual('跟踪公开页面更新');
      expect(rowValue(output.results[0].rows, '计划')).assertEqual('daily');
      expect(rowValue(output.results[0].rows, '时区')).assertEqual('Asia/Shanghai');
      expect(rowValue(output.results[0].rows, 'Email')).assertEqual('alerts@example.com');
      expect(rowValue(output.results[0].rows, '运行方式')).assertEqual(
        '持续运行；Firecrawl 按计划执行'
      );
      expect(rowValue(output.results[0].rows, '停止方式')).assertEqual(
        '创建后可暂停或删除 Monitor'
      );
      expect(rowValue(output.results[0].rows, '月度检查估算').indexOf('150') >= 0)
        .assertTrue();
      expect(JSON.stringify(actionArgs(output.results[0], 'web.monitor.create.confirm')))
        .assertEqual(
          '{"pages":["https://example.com/1","https://example.com/2",' +
          '"https://example.com/3","https://example.com/4","https://example.com/5"],' +
          '"goal":"跟踪公开页面更新","name":"公开页面监控","scheduleText":"daily",' +
          '"timezone":"Asia/Shanghai","email":"alerts@example.com","confirmed":true}'
        );

      const hourlyArgs: MonitorCreateArgs = {
        pages: ['https://example.com/a', 'https://example.com/b'],
        goal: '每小时跟踪',
        scheduleText: 'hourly'
      };
      const hourly = await new FirecrawlMcpClient(scripted).execute(
        'web.monitor.create', '创建每小时监控', '', hourlyArgs, config()
      );
      expect(rowValue(hourly.results[0].rows, '月度检查估算').indexOf('1440') >= 0)
        .assertTrue();

      const weeklyArgs: MonitorCreateArgs = {
        pages: ['https://example.com/a', 'https://example.com/b'],
        goal: '每周跟踪',
        scheduleText: 'weekly'
      };
      const weekly = await new FirecrawlMcpClient(scripted).execute(
        'web.monitor.create', '创建每周监控', '', weeklyArgs, config()
      );
      expect(rowValue(weekly.results[0].rows, '月度检查估算').indexOf('8') >= 0)
        .assertTrue();
      expect(scripted.callRegistrations.length).assertEqual(0);
    });

    it('rejects missing or mixed monitor modes and labels uncertain estimates honestly', 0, async () => {
      const invalidClient = new ScriptedGenericMcpClient();
      const missingArgs: MonitorCreateArgs = { goal: '跟踪更新' };
      const missing = await new FirecrawlMcpClient(invalidClient).execute(
        'web.monitor.create',
        '创建监控',
        '',
        missingArgs,
        config()
      );
      const mixedArgs: MonitorCreateArgs = {
        pages: ['https://example.com'],
        queries: ['Firecrawl'],
        goal: '跟踪更新'
      };
      const mixed = await new FirecrawlMcpClient(invalidClient).execute(
        'web.monitor.create',
        '创建监控',
        '',
        mixedArgs,
        config()
      );
      expect(missing.results[0].status).assertEqual('error');
      expect(mixed.results[0].status).assertEqual('error');
      expect(invalidClient.callRegistrations.length).assertEqual(0);

      const queryClient = new ScriptedGenericMcpClient();
      const queryArgs: MonitorCreateArgs = {
        queries: ['Firecrawl 1', 'Firecrawl 2', 'Firecrawl 3', 'Firecrawl 4'],
        goal: '跟踪公开搜索变化'
      };
      const queryPreview = await new FirecrawlMcpClient(queryClient).execute(
        'web.monitor.create',
        '创建查询监控',
        '',
        queryArgs,
        config()
      );
      expect(rowValue(queryPreview.results[0].rows, '查询数')).assertEqual('3');
      expect(rowValue(queryPreview.results[0].rows, 'Monitor 名称'))
        .assertEqual('未设置（由 Provider 生成）');
      expect(rowValue(queryPreview.results[0].rows, '查询 1')).assertEqual('Firecrawl 1');
      expect(rowValue(queryPreview.results[0].rows, '查询 2')).assertEqual('Firecrawl 2');
      expect(rowValue(queryPreview.results[0].rows, '查询 3')).assertEqual('Firecrawl 3');
      const queryEstimate = rowValue(queryPreview.results[0].rows, '月度检查估算');
      expect(queryEstimate.indexOf('近似') >= 0 || queryEstimate.indexOf('未知') >= 0)
        .assertTrue();
      expect(JSON.stringify(actionArgs(queryPreview.results[0], 'web.monitor.create.confirm'))
        .indexOf('Firecrawl 4')).assertEqual(-1);

      const customClient = new ScriptedGenericMcpClient();
      const customArgs: MonitorCreateArgs = {
        pages: ['https://example.com'],
        goal: '跟踪更新',
        scheduleText: 'every 2 days'
      };
      const customPreview = await new FirecrawlMcpClient(customClient).execute(
        'web.monitor.create',
        '创建自定义监控',
        '',
        customArgs,
        config()
      );
      expect(rowValue(customPreview.results[0].rows, '月度检查估算'))
        .assertEqual('Provider estimate unavailable');
      expect(customClient.callRegistrations.length).assertEqual(0);
    });

    it('creates a monitor exactly once only from the visible confirmation args', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [successfulPayload(JSON.parse(
        '{"success":true,"data":{"id":"mon-created","name":"Provider 规范名称","status":"active"}}'
      ) as Object)];
      const createArgs: MonitorCreateArgs = {
        pages: ['https://example.com/a'],
        goal: '跟踪公开页面更新',
        name: '公开页面监控',
        scheduleText: 'weekly',
        timezone: 'Asia/Shanghai',
        email: 'alerts@example.com',
        confirmed: true
      };
      const output = await new FirecrawlMcpClient(scripted).execute(
        'web.monitor.create',
        '确认创建监控',
        'web.monitor.create.confirm',
        createArgs,
        config()
      );

      expect(scripted.callRegistrations.length).assertEqual(1);
      expect(scripted.callRegistrations[0].mcpToolName).assertEqual('firecrawl_monitor_create');
      expect(JSON.stringify(scripted.callArgs[0])).assertEqual(
        '{"page":"https://example.com/a",' +
        '"goal":"跟踪公开页面更新","name":"公开页面监控","scheduleText":"weekly",' +
        '"timezone":"Asia/Shanghai","email":"alerts@example.com"}'
      );
      expect(output.results[0].status).assertEqual('success');
      expect(rowValue(output.results[0].rows, 'Monitor 名称')).assertEqual('Provider 规范名称');
      expect(rowValue(output.results[0].rows, '名称来源')).assertEqual('Provider 响应');
      expect(rowValue(output.results[0].rows, 'Monitor ID')).assertEqual('mon-created');

      const idOnly = new ScriptedGenericMcpClient();
      idOnly.responses = [successfulPayload(JSON.parse(
        '{"success":true,"data":{"id":"mon-id-only","status":"active"}}'
      ) as Object)];
      const idOnlyOutput = await new FirecrawlMcpClient(idOnly).execute(
        'web.monitor.create',
        '确认创建监控',
        'web.monitor.create.confirm',
        createArgs,
        config()
      );
      expect(rowValue(idOnlyOutput.results[0].rows, 'Monitor 名称'))
        .assertEqual('公开页面监控');
      expect(rowValue(idOnlyOutput.results[0].rows, '名称来源'))
        .assertEqual('本次已确认创建请求');
    });

    it('preserves real monitor and check IDs across all read actions', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(JSON.parse(
          '{"success":true,"data":{"monitors":[{"id":"mon-real","name":"真实监控",' +
          '"status":"active","lastRunAt":"2026-07-23T01:00:00.000Z",' +
          '"nextRunAt":"2026-07-24T01:00:00.000Z","lastCheck":{' +
          '"id":"check-latest","status":"completed",' +
          '"completedAt":"2026-07-23T01:02:00.000Z"}}]}}'
        ) as Object),
        successfulPayload(JSON.parse(
          '{"success":true,"data":{"id":"mon-real","name":"真实监控","status":"active"}}'
        ) as Object),
        successfulPayload(JSON.parse(
          '{"success":true,"data":{"checks":[{"id":"check-real","monitorId":"mon-real",' +
          '"status":"completed"}]}}'
        ) as Object),
        successfulPayload(JSON.parse(
          '{"success":true,"data":{"id":"check-real","monitorId":"mon-real",' +
          '"status":"completed","pages":[]}}'
        ) as Object)
      ];
      const client = new FirecrawlMcpClient(scripted);
      const list = await client.execute(
        'web.monitor.list',
        '列出监控',
        '',
        JSON.parse('{}') as Object,
        config()
      );
      const monitor = list.results[0];
      const actionIds: string[] = [
        'web.monitor.detail',
        'web.monitor.checks',
        'web.monitor.run',
        'web.monitor.pause',
        'web.monitor.resume',
        'web.monitor.delete'
      ];
      for (let index = 0; index < actionIds.length; index++) {
        expect(JSON.stringify(actionArgs(monitor, actionIds[index])))
          .assertEqual('{"id":"mon-real"}');
      }
      expect(rowValue(monitor.rows, '上次运行')).assertEqual('2026-07-23T01:00:00.000Z');
      expect(rowValue(monitor.rows, '下次运行')).assertEqual('2026-07-24T01:00:00.000Z');
      expect(rowValue(monitor.rows, '最近 Check ID')).assertEqual('check-latest');
      expect(rowValue(monitor.rows, '最近 Check 状态')).assertEqual('completed');
      expect(rowValue(monitor.rows, '最近 Check 时间'))
        .assertEqual('2026-07-23T01:02:00.000Z');

      const detailArgs: MonitorActionArgs = { id: 'mon-real' };
      const detail = await client.execute(
        'web.monitor.list',
        '查看监控',
        'web.monitor.detail',
        detailArgs,
        config()
      );
      expect(JSON.stringify(actionArgs(detail.results[0], 'web.monitor.checks')))
        .assertEqual('{"id":"mon-real"}');

      const checksArgs: MonitorActionArgs = { id: 'mon-real', limit: 7 };
      const checks = await client.execute(
        'web.monitor.list',
        '查看检查记录',
        'web.monitor.checks',
        checksArgs,
        config()
      );
      expect(JSON.stringify(actionArgs(checks.results[0], 'web.monitor.check')))
        .assertEqual('{"id":"mon-real","checkId":"check-real"}');

      const checkArgs: MonitorActionArgs = { id: 'mon-real', checkId: 'check-real' };
      const check = await client.execute(
        'web.monitor.list',
        '查看单次检查',
        'web.monitor.check',
        checkArgs,
        config()
      );
      expect(JSON.stringify(actionArgs(check.results[0], 'web.monitor.check')))
        .assertEqual('{"id":"mon-real","checkId":"check-real"}');
      expect(scripted.callRegistrations.map((item): string => item.mcpToolName).join(','))
        .assertEqual(
          'firecrawl_monitor_list,firecrawl_monitor_get,firecrawl_monitor_checks,' +
          'firecrawl_monitor_check'
        );
      expect(JSON.stringify(scripted.callArgs)).assertEqual(
        '[{},{"id":"mon-real"},{"id":"mon-real","limit":7},' +
        '{"id":"mon-real","checkId":"check-real"}]'
      );
    });

    it('previews every monitor mutation and calls each exact MCP tool once after confirmation', 0,
      async () => {
        const cases = [
          ['web.monitor.run', 'firecrawl_monitor_run', '{"id":"mon-run"}'],
          ['web.monitor.pause', 'firecrawl_monitor_update',
            '{"id":"mon-pause","body":{"status":"paused"}}'],
          ['web.monitor.resume', 'firecrawl_monitor_update',
            '{"id":"mon-resume","body":{"status":"active"}}'],
          ['web.monitor.delete', 'firecrawl_monitor_delete', '{"id":"mon-delete"}']
        ];
        for (let index = 0; index < cases.length; index++) {
          const scripted = new ScriptedGenericMcpClient();
          scripted.responses = [successfulPayload(JSON.parse(
            '{"success":true,"data":{"id":' +
            JSON.stringify((JSON.parse(cases[index][2]) as MonitorActionArgs).id) +
            ',"status":"accepted"}}'
          ) as Object)];
          const client = new FirecrawlMcpClient(scripted);
          const id = (JSON.parse(cases[index][2]) as MonitorActionArgs).id;
          const previewArgs: MonitorActionArgs = { id: id };
          const preview = await client.execute(
            'web.monitor.list',
            '变更监控',
            cases[index][0],
            previewArgs,
            config()
          );
          expect(scripted.callRegistrations.length).assertEqual(0);
          expect(scripted.preflightRegistrations.length).assertEqual(0);
          const confirmId = cases[index][0] + '.confirm';
          const confirmedArgs = actionArgs(preview.results[0], confirmId);
          expect((confirmedArgs as MonitorActionArgs).id).assertEqual(id);
          expect((confirmedArgs as MonitorActionArgs).confirmed).assertTrue();

          const changed = await client.execute(
            'web.monitor.list',
            '确认变更监控',
            confirmId,
            confirmedArgs,
            config()
          );
          expect(scripted.callRegistrations.length).assertEqual(1);
          expect(scripted.callRegistrations[0].mcpToolName).assertEqual(cases[index][1]);
          expect(JSON.stringify(scripted.callArgs[0])).assertEqual(cases[index][2]);
          if (cases[index][0] === 'web.monitor.delete') {
            expect(changed.results[0].status).assertEqual('partial');
            expect(changed.results[0].summary.indexOf('最终删除证明') >= 0).assertTrue();
            expect(JSON.stringify(actionArgs(changed.results[0], 'web.monitor.detail')))
              .assertEqual('{"id":"mon-delete"}');
          }
        }
      });

    it('does not retry an unknown monitor mutation and tells the user to query Provider state',
      0, async () => {
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [failedPayload(0, 'request timed out before a response')];
        const runArgs: MonitorActionArgs = { id: 'mon-timeout', confirmed: true };
        const output = await new FirecrawlMcpClient(scripted).execute(
          'web.monitor.list',
          '立即运行监控',
          'web.monitor.run.confirm',
          runArgs,
          config()
        );

        expect(scripted.callRegistrations.length).assertEqual(1);
        expect(scripted.callRegistrations[0].mcpToolName).assertEqual('firecrawl_monitor_run');
        expect(output.results[0].status).assertEqual('error');
        expect(output.results[0].summary.indexOf('先重新查询 Provider 状态') >= 0).assertTrue();
      });

    it('rejects malformed mutation envelopes instead of claiming a Provider change', 0,
      async () => {
        const payloads: string[] = [
          '{}',
          '[]',
          '42',
          '{"data":{"id":"mon-malformed"}}',
          '{"success":false}'
        ];
        for (let index = 0; index < payloads.length; index++) {
          const scripted = new ScriptedGenericMcpClient();
          scripted.responses = [
            successfulPayload(JSON.parse(payloads[index]) as Object)
          ];
          const args: MonitorActionArgs = { id: 'mon-malformed', confirmed: true };
          const output = await new FirecrawlMcpClient(scripted).execute(
            'web.monitor.list',
            '确认立即运行',
            'web.monitor.run.confirm',
            args,
            config()
          );

          expect(scripted.callRegistrations.length).assertEqual(1);
          expect(output.results[0].status).assertEqual('error');
          expect(output.results[0].summary.indexOf('先重新查询 Provider 状态') >= 0)
            .assertTrue();
          expect(output.results[0].title).assertEqual('Firecrawl Monitor 操作失败');
        }
      });

    it('rejects empty or mismatched Provider IDs for monitor detail and check reads', 0,
      async () => {
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [
          successfulPayload(JSON.parse(
            '{"success":true,"data":{"id":"","status":"active"}}'
          ) as Object),
          successfulPayload(JSON.parse(
            '{"success":true,"data":{"id":"mon-other","status":"active"}}'
          ) as Object),
          successfulPayload(JSON.parse(
            '{"success":true,"data":{"id":"","monitorId":"mon-real","status":"completed"}}'
          ) as Object),
          successfulPayload(JSON.parse(
            '{"success":true,"data":{"id":"check-other","monitorId":"mon-other",' +
            '"status":"completed"}}'
          ) as Object)
        ];
        const client = new FirecrawlMcpClient(scripted);
        const detailArgs: MonitorActionArgs = { id: 'mon-real' };
        const checkArgs: MonitorActionArgs = {
          id: 'mon-real',
          checkId: 'check-real'
        };
        const emptyDetail = await client.execute(
          'web.monitor.list', '查看监控', 'web.monitor.detail', detailArgs, config()
        );
        const mismatchDetail = await client.execute(
          'web.monitor.list', '查看监控', 'web.monitor.detail', detailArgs, config()
        );
        const emptyCheck = await client.execute(
          'web.monitor.list', '查看检查', 'web.monitor.check', checkArgs, config()
        );
        const mismatchCheck = await client.execute(
          'web.monitor.list', '查看检查', 'web.monitor.check', checkArgs, config()
        );

        expect(emptyDetail.results[0].status).assertEqual('error');
        expect(mismatchDetail.results[0].status).assertEqual('error');
        expect(emptyCheck.results[0].status).assertEqual('error');
        expect(mismatchCheck.results[0].status).assertEqual('error');
      });

    it('filters malformed list and check records without inventing action IDs', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(JSON.parse(
          '{"success":true,"data":{"monitors":[{"name":"missing id"},' +
          '{"id":"mon-real","name":"real"}]}}'
        ) as Object),
        successfulPayload(JSON.parse(
          '{"success":true,"data":{"checks":[{"status":"completed"},' +
          '{"id":"check-wrong-monitor","monitorId":"mon-other","status":"completed"},' +
          '{"id":"check-real","monitorId":"mon-real","status":"completed"}]}}'
        ) as Object)
      ];
      const client = new FirecrawlMcpClient(scripted);
      const list = await client.execute(
        'web.monitor.list', '列出监控', '', JSON.parse('{}') as Object, config()
      );
      const checksArgs: MonitorActionArgs = { id: 'mon-real', limit: 10 };
      const checks = await client.execute(
        'web.monitor.list', '列出检查', 'web.monitor.checks', checksArgs, config()
      );

      expect(list.results.length).assertEqual(1);
      expect(rowValue(list.results[0].rows, 'Monitor ID')).assertEqual('mon-real');
      expect(checks.results.length).assertEqual(1);
      expect(JSON.stringify(actionArgs(checks.results[0], 'web.monitor.check')))
        .assertEqual('{"id":"mon-real","checkId":"check-real"}');
    });

    it('requires every listed check to carry the matching Provider monitorId', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [successfulPayload(JSON.parse(
        '{"success":true,"data":[{"id":"check-unbound","status":"completed"},' +
        '{"id":"check-real","monitorId":"mon-real","status":"completed"}]}'
      ) as Object)];
      const checksArgs: MonitorActionArgs = { id: 'mon-real', limit: 10 };
      const checks = await new FirecrawlMcpClient(scripted).execute(
        'web.monitor.list', '列出检查', 'web.monitor.checks', checksArgs, config()
      );

      expect(checks.results.length).assertEqual(1);
      expect(JSON.stringify(actionArgs(checks.results[0], 'web.monitor.check')))
        .assertEqual('{"id":"mon-real","checkId":"check-real"}');
    });

    it('shows official currentCheckId from data-array list and detail responses', 0,
      async () => {
        const response = successfulPayload(JSON.parse(
          '{"success":true,"data":[{"id":"mon-current","name":"当前监控",' +
          '"status":"active","currentCheckId":"check-current"}]}'
        ) as Object);
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [response, response];
        const client = new FirecrawlMcpClient(scripted);
        const list = await client.execute(
          'web.monitor.list', '列出监控', '', JSON.parse('{}') as Object, config()
        );
        const detailArgs: MonitorActionArgs = { id: 'mon-current' };
        const detail = await client.execute(
          'web.monitor.list', '查看监控', 'web.monitor.detail', detailArgs, config()
        );

        expect(rowValue(list.results[0].rows, '最近 Check ID')).assertEqual('check-current');
        expect(JSON.stringify(actionArgs(list.results[0], 'web.monitor.check')))
          .assertEqual('{"id":"mon-current","checkId":"check-current"}');
        expect(rowValue(detail.results[0].rows, '最近 Check ID')).assertEqual('check-current');
        expect(JSON.stringify(actionArgs(detail.results[0], 'web.monitor.check')))
          .assertEqual('{"id":"mon-current","checkId":"check-current"}');
      });

    it('uses MCP isError text only on failure paths for status and reason', 0, async () => {
      const cases: string[][] = [
        ['Unauthorized: Firecrawl API key is invalid', 'needs_auth'],
        ['Payment required: credits exhausted', 'credits_exhausted'],
        ['Too many requests: rate limit reached', 'rate_limited'],
        ['Monitor not found (404)', 'error']
      ];
      for (let index = 0; index < cases.length; index++) {
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [textErrorPayload(cases[index][0])];
        const output = await new FirecrawlMcpClient(scripted).execute(
          'web.monitor.list', '列出监控', '', JSON.parse('{}') as Object, config()
        );

        expect(output.results[0].status).assertEqual(cases[index][1]);
        expect(output.results[0].summary.indexOf(cases[index][0]) >= 0).assertTrue();
      }

      const secretClient = new ScriptedGenericMcpClient();
      secretClient.responses = [textErrorPayload(
        'Unauthorized ' + TEST_KEY + ' ' + TEST_MCP_URL + ' ' + 'failure '.repeat(300)
      )];
      const redacted = await new FirecrawlMcpClient(secretClient).execute(
        'web.monitor.list', '列出监控', '', JSON.parse('{}') as Object, config()
      );
      expect(redacted.results[0].summary.indexOf(TEST_KEY)).assertEqual(-1);
      expect(redacted.results[0].summary.indexOf(TEST_MCP_URL)).assertEqual(-1);
      expect(redacted.results[0].rawPreview.indexOf(TEST_KEY)).assertEqual(-1);
      expect(redacted.results[0].rawPreview.indexOf(TEST_MCP_URL)).assertEqual(-1);
      expect(redacted.results[0].summary.length <= 1200).assertTrue();
      expect(redacted.results[0].rawPreview.length <= 1200).assertTrue();

      const successClient = new ScriptedGenericMcpClient();
      successClient.responses = [successfulPayload(
        JSON.parse(
          '{"success":true,"data":{"monitors":[{"id":"mon-success",' +
          '"name":"API key credits rate limit login","status":"active"}]}}'
        ) as Object,
        '',
        'Unauthorized credits exhausted rate limit login'
      )];
      const success = await new FirecrawlMcpClient(successClient).execute(
        'web.monitor.list', '列出监控', '', JSON.parse('{}') as Object, config()
      );
      expect(success.results[0].status).assertEqual('success');
    });

    it('keeps unmatched or unconfirmed monitor confirmations fully local', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      const createArgs: MonitorCreateArgs = {
        pages: ['https://example.com'],
        goal: '跟踪变化',
        confirmed: false
      };
      const create = await new FirecrawlMcpClient(scripted).execute(
        'web.monitor.create',
        '确认创建',
        'web.monitor.create.confirm',
        createArgs,
        config()
      );
      const unconfirmedArgs: MonitorActionArgs = { id: 'mon-real', confirmed: false };
      const unconfirmed = await new FirecrawlMcpClient(scripted).execute(
        'web.monitor.list',
        '确认暂停',
        'web.monitor.pause.confirm',
        unconfirmedArgs,
        config()
      );
      const mismatchedArgs: MonitorActionArgs = { id: 'mon-real', confirmed: true };
      const mismatched = await new FirecrawlMcpClient(scripted).execute(
        'web.monitor.list',
        '错误确认',
        'web.monitor.unsupported.confirm',
        mismatchedArgs,
        config()
      );

      expect(create.results[0].status).assertEqual('error');
      expect(unconfirmed.results[0].status).assertEqual('error');
      expect(mismatched.results[0].status).assertEqual('error');
      expect(scripted.preflightRegistrations.length).assertEqual(0);
      expect(scripted.callRegistrations.length).assertEqual(0);
    });

    it('treats every confirmed Monitor 5xx as unknown without retrying the mutation', 0,
      async () => {
        const actionIds: string[] = [
          'web.monitor.create.confirm',
          'web.monitor.run.confirm',
          'web.monitor.pause.confirm',
          'web.monitor.resume.confirm',
          'web.monitor.delete.confirm'
        ];
        const statusCodes: number[] = [500, 502, 503, 500, 502];
        for (let index = 0; index < actionIds.length; index++) {
          const scripted = new ScriptedGenericMcpClient();
          scripted.responses = [
            failedStructuredPayload(
              statusCodes[index],
              'Firecrawl service failed',
              'Explicit Provider server error'
            )
          ];
          const isCreate = index === 0;
          const args: Object = isCreate ? {
            pages: ['https://example.com/watch'],
            goal: '跟踪变化',
            confirmed: true
          } as MonitorCreateArgs : {
            id: 'mon-server-error',
            confirmed: true
          } as MonitorActionArgs;
          const output = await new FirecrawlMcpClient(scripted).execute(
            isCreate ? 'web.monitor.create' : 'web.monitor.list',
            '确认 Monitor 变更',
            actionIds[index],
            args,
            config()
          );

          expect(scripted.callRegistrations.length).assertEqual(1);
          expect(output.results[0].status).assertEqual('error');
          expect(output.results[0].summary.indexOf('结果未知') >= 0).assertTrue();
          expect(output.results[0].summary.indexOf('先重新查询 Provider 状态') >= 0)
            .assertTrue();
        }
      });

    it('keeps explicit Monitor 4xx and HTTP0 DNS failures known', 0, async () => {
      const responses: McpToolCallResult[] = [
        failedStructuredPayload(400, 'Bad request', 'Schedule is invalid'),
        failedPayload(0, 'Could not resolve host mcp.firecrawl.dev')
      ];
      for (let index = 0; index < responses.length; index++) {
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [responses[index]];
        const args: MonitorActionArgs = { id: 'mon-known-failure', confirmed: true };
        const output = await new FirecrawlMcpClient(scripted).execute(
          'web.monitor.list',
          '确认立即运行',
          'web.monitor.run.confirm',
          args,
          config()
        );

        expect(scripted.callRegistrations.length).assertEqual(1);
        expect(output.results[0].status).assertEqual('error');
        expect(output.results[0].summary.indexOf('结果未知')).assertEqual(-1);
        expect(output.results[0].summary.indexOf('先重新查询 Provider 状态')).assertEqual(-1);
      }
    });

    it('treats a post-preflight HTTP0 no-response mutation as unknown', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [failedPayload(0, 'Connection closed before any response')];
      const args: MonitorActionArgs = { id: 'mon-no-response', confirmed: true };
      const output = await new FirecrawlMcpClient(scripted).execute(
        'web.monitor.list',
        '确认立即运行',
        'web.monitor.run.confirm',
        args,
        config()
      );

      expect(scripted.callRegistrations.length).assertEqual(1);
      expect(output.results[0].status).assertEqual('error');
      expect(output.results[0].summary.indexOf('结果未知') >= 0).assertTrue();
      expect(output.results[0].summary.indexOf('先重新查询 Provider 状态') >= 0).assertTrue();
    });

    it('shows official Search and Scrape usage once at the matching evidence level', 0,
      async () => {
        const url = 'https://example.com/evidence';
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [
          successfulPayload(JSON.parse(
            '{"success":true,"data":{"web":[{"url":' + JSON.stringify(url) +
            ',"title":"Evidence","description":"Search evidence"}]},' +
            '"id":"search-official","creditsUsed":2,"warnings":["search warning"]}'
          ) as Object),
          successfulPayload(JSON.parse(
            '{"markdown":"Verified source body.","creditsUsed":1,' +
            '"warnings":["scrape warning"],"metadata":{"sourceURL":' +
            JSON.stringify(url) + '}}'
          ) as Object)
        ];
        const args: ResearchArgs = { query: 'evidence', maxResults: 1 };
        const output = await new FirecrawlMcpClient(scripted).execute(
          'web.research.search', '请研究并总结', '', args, config()
        );
        const overview = resultWithTitle(output.results, '网页研究综述');
        const source = resultForUrl(output.results, url);

        expect(rowValue(overview.rows, 'Search ID')).assertEqual('search-official');
        expect(rowValue(overview.rows, 'Search Credits')).assertEqual('2');
        expect(rowValue(overview.rows, '警告')).assertEqual('search warning');
        expect(rowValue(source.rows, 'Scrape Credits')).assertEqual('1');
        expect(rowValue(source.rows, '警告')).assertEqual('scrape warning');
        expect(rowValue(source.rows, 'Search Credits')).assertEqual('');
      });

    it('shows account fallbacks and top-level Scrape usage without changing status from warnings',
      0, async () => {
        const noUsage = new ScriptedGenericMcpClient();
        noUsage.responses = [successfulPayload(JSON.parse(
          '{"markdown":"No usage response.","metadata":{"sourceURL":' +
          JSON.stringify(TEST_URL) + '}}'
        ) as Object)];
        const noUsageOutput = await new FirecrawlMcpClient(noUsage).execute(
          'web.page.read', '读取页面', '', pageArgs(), config()
        );
        expect(rowValue(noUsageOutput.results[0].rows, 'Credits'))
          .assertEqual('未返回，以 Firecrawl 账户为准');

        const topLevel = new ScriptedGenericMcpClient();
        topLevel.responses = [successfulPayload(JSON.parse(
          '{"data":{"markdown":"Nested page body.","metadata":{"sourceURL":' +
          JSON.stringify(TEST_URL) + '}},"creditsUsed":7,' +
          '"warnings":["top-level timeout guidance"]}'
        ) as Object)];
        const topLevelOutput = await new FirecrawlMcpClient(topLevel).execute(
          'web.page.read', '读取页面', '', pageArgs(), config()
        );
        expect(topLevelOutput.results[0].status).assertEqual('success');
        expect(rowValue(topLevelOutput.results[0].rows, 'Credits')).assertEqual('7');
        expect(rowValue(topLevelOutput.results[0].rows, '警告'))
          .assertEqual('top-level timeout guidance');
      });

    it('adds Search and per-Scrape usage to A3 and B1 sources', 0, async () => {
      const productUrl = 'https://zol.com.cn/item';
      const shopping = new ScriptedGenericMcpClient();
      shopping.responses = [
        successfulPayload(JSON.parse(
          '{"success":true,"data":{"web":[{"url":' + JSON.stringify(productUrl) +
          ',"title":"Item"}]},"creditsUsed":3,"warnings":["shopping search warning"]}'
        ) as Object),
        successfulPayload(JSON.parse(
          '{"json":{"name":"Item","brand":"Brand","priceText":"¥299",' +
          '"strengths":["fact"]},' +
          '"creditsUsed":2,"warnings":["product scrape warning"],"metadata":{"sourceURL":' +
          JSON.stringify(productUrl) + '}}'
        ) as Object)
      ];
      const shoppingArgs: ShoppingArgs = {
        query: 'item',
        domains: ['zol.com.cn'],
        maxProducts: 1
      };
      const shoppingOutput = await new FirecrawlMcpClient(shopping).execute(
        'shopping.research', '商品研究', '', shoppingArgs, config()
      );
      const shoppingSource = resultForUrl(shoppingOutput.results, productUrl);
      expect(rowValue(shoppingSource.rows, 'Search Credits')).assertEqual('3');
      expect(rowValue(shoppingSource.rows, '警告')).assertEqual('shopping search warning');
      expect(rowValue(shoppingOutput.results[0].rows, 'Scrape Credits')).assertEqual('2');
      expect(JSON.stringify(shoppingOutput.results[0].rows).indexOf('product scrape warning'))
        .assertLarger(-1);

      const socialUrl = 'https://www.xiaohongshu.com/explore/usage';
      const social = new ScriptedGenericMcpClient();
      social.responses = [
        successfulPayload(JSON.parse(
          '{"success":true,"data":{"web":[{"url":' + JSON.stringify(socialUrl) +
          ',"title":"Public","description":"Search summary"}]},' +
          '"creditsUsed":4,"warnings":["social search warning"]}'
        ) as Object),
        successfulPayload(JSON.parse(
          '{"markdown":"Public body.","creditsUsed":1,"warnings":["social scrape warning"],' +
          '"metadata":{"sourceURL":' + JSON.stringify(socialUrl) + '}}'
        ) as Object)
      ];
      const socialArgs: SocialArgs = {
        query: 'public',
        platforms: ['xiaohongshu'],
        maxResults: 1
      };
      const socialOutput = await new FirecrawlMcpClient(social).execute(
        'social.public.search', '公开搜索', '', socialArgs, config()
      );
      const socialOverview = resultWithTitle(socialOutput.results, '公开社交搜索综述');
      const socialSource = resultForUrl(socialOutput.results, socialUrl);
      expect(rowValue(socialOverview.rows, 'Search Credits')).assertEqual('4');
      expect(rowValue(socialOverview.rows, '警告')).assertEqual('social search warning');
      expect(rowValue(socialSource.rows, 'Scrape Credits')).assertEqual('1');
      expect(rowValue(socialSource.rows, '警告')).assertEqual('social scrape warning');
    });

    it('shows Monitor usage or account fallback on create, mutation, and read results', 0,
      async () => {
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [
          successfulPayload(JSON.parse(
            '{"success":true,"data":{"id":"mon-usage","name":"Usage","status":"active"},' +
            '"creditsUsed":5,"warnings":["create warning"]}'
          ) as Object),
          successfulPayload(JSON.parse(
            '{"success":true,"data":{"id":"mon-usage","status":"accepted"},' +
            '"creditsUsed":1,"warnings":["run warning"]}'
          ) as Object),
          successfulPayload(JSON.parse(
            '{"success":true,"data":{"monitors":[{"id":"mon-usage",' +
            '"name":"Usage","status":"active"}]}}'
          ) as Object)
        ];
        const client = new FirecrawlMcpClient(scripted);
        const createArgs: MonitorCreateArgs = {
          pages: ['https://example.com/watch'],
          goal: '跟踪变化',
          name: 'Usage',
          confirmed: true
        };
        const created = await client.execute(
          'web.monitor.create', '确认创建', 'web.monitor.create.confirm', createArgs, config()
        );
        expect(rowValue(created.results[0].rows, 'Credits')).assertEqual('5');
        expect(rowValue(created.results[0].rows, '警告')).assertEqual('create warning');

        const runArgs: MonitorActionArgs = { id: 'mon-usage', confirmed: true };
        const changed = await client.execute(
          'web.monitor.list', '确认运行', 'web.monitor.run.confirm', runArgs, config()
        );
        expect(rowValue(changed.results[0].rows, 'Credits')).assertEqual('1');
        expect(rowValue(changed.results[0].rows, '警告')).assertEqual('run warning');

        const listed = await client.execute(
          'web.monitor.list', '列出监控', '', JSON.parse('{}') as Object, config()
        );
        expect(rowValue(listed.results[0].rows, 'Credits'))
          .assertEqual('未返回，以 Firecrawl 账户为准');
      });

    it('preserves A1 and B1 Search usage while isolating A3 source failures', 0, async () => {
      const toolIds: string[] = [
        'web.research.search',
        'shopping.research',
        'social.public.search'
      ];
      const args: Object[] = [
        { query: '研究资料' } as ResearchArgs,
        { query: '商品资料', domains: ['zol.com.cn'] } as ShoppingArgs,
        { query: '公开资料', platforms: ['xiaohongshu'] } as SocialArgs
      ];
      for (let index = 0; index < toolIds.length; index++) {
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [successfulPayload(JSON.parse(
          '{"success":false,"id":"search-failed-' + index.toString() + '",' +
          '"creditsUsed":2,"warnings":["search failure warning"],' +
          '"error":"Provider search failed"}'
        ) as Object)];
        const output = await new FirecrawlMcpClient(scripted).execute(
          toolIds[index], '研究', '', args[index], config()
        );

        if (toolIds[index] === 'shopping.research') {
          expect(output.results[0].status).assertEqual('empty');
          expect(output.results[0].summary)
            .assertEqual('暂未找到可核验的同款公开价格。');
          expect(JSON.stringify(output).indexOf('Provider search failed')).assertEqual(-1);
        } else {
          expect(output.results[0].status).assertEqual('error');
          expect(rowValue(output.results[0].rows, 'Search ID'))
            .assertEqual('search-failed-' + index.toString());
          expect(rowValue(output.results[0].rows, 'Search Credits')).assertEqual('2');
          expect(rowValue(output.results[0].rows, '警告')).assertEqual('search failure warning');
        }
      }
    });

    it('returns the fixed A3 empty summary when both sources have no product candidate', 0,
      async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(searchPayload([])),
        successfulPayload(searchPayload([]))
      ];
      const args: ShoppingArgs = { query: '不存在的商品' };
      const output = await new FirecrawlMcpClient(scripted).execute(
        'shopping.research', '商品研究', '', args, config()
      );

      expect(output.results[0].status).assertEqual('empty');
      expect(output.results[0].summary).assertEqual('暂未找到可核验的同款公开价格。');
      expect(rowValue(output.results[0].rows, '来源数')).assertEqual('0');
      expect(rowValue(output.results[0].rows, '可比来源数')).assertEqual('0');
    });

    it('preserves Scrape usage on failed, empty, login, and exception A2 terminals', 0,
      async () => {
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [
          successfulPayload(JSON.parse(
            '{"success":false,"error":"Origin failed","creditsUsed":3,' +
            '"warnings":["scrape failure warning"]}'
          ) as Object),
          successfulPayload(JSON.parse(
            '{"markdown":"","metadata":{"sourceURL":' + JSON.stringify(TEST_URL) + '}}'
          ) as Object),
          successfulPayload(JSON.parse(
            '{"markdown":"Please sign in to continue.","creditsUsed":1,' +
            '"warnings":["login warning"],"metadata":{"sourceURL":' +
            JSON.stringify(TEST_URL) + '}}'
          ) as Object)
        ];
        const client = new FirecrawlMcpClient(scripted);
        const failed = await client.execute(
          'web.page.read', '读取页面', '', pageArgs(), config()
        );
        const empty = await client.execute(
          'web.page.read', '读取页面', '', pageArgs(), config()
        );
        const login = await client.execute(
          'web.page.read', '读取页面', '', pageArgs(), config()
        );

        expect(failed.results[0].status).assertEqual('error');
        expect(rowValue(failed.results[0].rows, 'Credits')).assertEqual('3');
        expect(rowValue(failed.results[0].rows, '警告')).assertEqual('scrape failure warning');
        expect(empty.results[0].status).assertEqual('empty');
        expect(rowValue(empty.results[0].rows, 'Credits'))
          .assertEqual('未返回，以 Firecrawl 账户为准');
        expect(login.results[0].status).assertEqual('blocked_by_site');
        expect(rowValue(login.results[0].rows, 'Credits')).assertEqual('1');
        expect(rowValue(login.results[0].rows, '警告')).assertEqual('login warning');

        const throwing = new ScriptedGenericMcpClient();
        throwing.thrownMessage = 'Connection closed';
        const exception = await new FirecrawlMcpClient(throwing).execute(
          'web.page.read', '读取页面', '', pageArgs(), config()
        );
        expect(exception.results[0].status).assertEqual('error');
        expect(rowValue(exception.results[0].rows, 'Credits'))
          .assertEqual('未返回，以 Firecrawl 账户为准');
      });

    it('preserves Monitor usage on failed, empty, and invalid-ID terminals', 0, async () => {
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(JSON.parse(
          '{"success":false,"error":"Provider rejected","creditsUsed":2,' +
          '"warnings":["monitor failure warning"]}'
        ) as Object),
        successfulPayload(JSON.parse(
          '{"success":true,"data":{"monitors":[]},"creditsUsed":1,' +
          '"warnings":["monitor empty warning"]}'
        ) as Object),
        successfulPayload(JSON.parse(
          '{"success":true,"data":{"monitors":[{"id":"","name":"invalid"}]},' +
          '"warnings":["monitor invalid warning"]}'
        ) as Object)
      ];
      const client = new FirecrawlMcpClient(scripted);
      const failed = await client.execute(
        'web.monitor.list', '列出监控', '', JSON.parse('{}') as Object, config()
      );
      const empty = await client.execute(
        'web.monitor.list', '列出监控', '', JSON.parse('{}') as Object, config()
      );
      const invalid = await client.execute(
        'web.monitor.list', '列出监控', '', JSON.parse('{}') as Object, config()
      );

      expect(failed.results[0].status).assertEqual('error');
      expect(rowValue(failed.results[0].rows, 'Credits')).assertEqual('2');
      expect(rowValue(failed.results[0].rows, '警告')).assertEqual('monitor failure warning');
      expect(empty.results[0].status).assertEqual('empty');
      expect(rowValue(empty.results[0].rows, 'Credits')).assertEqual('1');
      expect(rowValue(empty.results[0].rows, '警告')).assertEqual('monitor empty warning');
      expect(invalid.results[0].status).assertEqual('empty');
      expect(rowValue(invalid.results[0].rows, 'Credits'))
        .assertEqual('未返回，以 Firecrawl 账户为准');
      expect(rowValue(invalid.results[0].rows, '警告')).assertEqual('monitor invalid warning');
    });

    it('counts only successful or partial A1 evidence as verified', 0, async () => {
      const firstUrl = 'https://example.com/blocked-one';
      const secondUrl = 'https://example.com/blocked-two';
      const scripted = new ScriptedGenericMcpClient();
      scripted.responses = [
        successfulPayload(searchPayload([
          searchItem(firstUrl, 'Blocked one', 'Indexed candidate one'),
          searchItem(secondUrl, 'Blocked two', 'Indexed candidate two')
        ])),
        successfulPayload(pagePayload('请先登录后继续')),
        successfulPayload(pagePayload('打开 App 查看完整内容'))
      ];
      const args: ResearchArgs = { query: 'blocked sources', maxResults: 2 };
      const output = await new FirecrawlMcpClient(scripted).execute(
        'web.research.search', '请研究并总结', '', args, config()
      );
      const overview = resultWithTitle(output.results, '网页研究综述');

      expect(overview.summary.indexOf('已核验 0 个公开来源') >= 0).assertTrue();
      expect(overview.summary.indexOf('候选 2 个公开来源') >= 0).assertTrue();
      expect(overview.summary.indexOf('可核验')).assertEqual(-1);
      expect(rowValue(overview.rows, '已核验来源')).assertEqual('0');
      expect(rowValue(overview.rows, '候选来源')).assertEqual('2');
    });

    it('fails closed for every supplied invalid A1 or A3 hostname list', 0, async () => {
      const invalidDomains: string[][] = [
        [],
        [' '],
        ['example.com', 'https://evil.example/path'],
        ['例子.测试'],
        ['xn--bcher-kva.example']
      ];
      for (let index = 0; index < invalidDomains.length; index++) {
        const researchClient = new ScriptedGenericMcpClient();
        const researchArgs: ResearchArgs = {
          query: 'research',
          domains: invalidDomains[index]
        };
        const research = await new FirecrawlMcpClient(researchClient).execute(
          'web.research.search', '研究', '', researchArgs, config()
        );
        expect(research.results[0].status).assertEqual('error');
        expect(researchClient.preflightRegistrations.length).assertEqual(0);
        expect(researchClient.callRegistrations.length).assertEqual(0);

        const shoppingClient = new ScriptedGenericMcpClient();
        const shoppingArgs: ShoppingArgs = {
          query: 'shopping',
          domains: invalidDomains[index]
        };
        const shopping = await new FirecrawlMcpClient(shoppingClient).execute(
          'shopping.research', '商品研究', '', shoppingArgs, config()
        );
        expect(shopping.results[0].status).assertEqual('error');
        expect(shoppingClient.preflightRegistrations.length).assertEqual(0);
        expect(shoppingClient.callRegistrations.length).assertEqual(0);
      }
    });

    it('distinguishes outer MCP 403 from an origin page 403 during deep research', 0,
      async () => {
        const outerUrl = 'https://example.com/outer';
        const originUrl = 'https://example.com/origin';
        const scripted = new ScriptedGenericMcpClient();
        scripted.responses = [
          successfulPayload(searchPayload([
            searchItem(outerUrl, 'Outer', 'Outer candidate'),
            searchItem(originUrl, 'Origin', 'Origin candidate')
          ])),
          failedPayload(403, 'Forbidden by MCP gateway'),
          successfulPayload(JSON.parse(
            '{"markdown":"Origin access page.","metadata":{"sourceURL":' +
            JSON.stringify(originUrl) + ',"statusCode":403}}'
          ) as Object)
        ];
        const args: ResearchArgs = { query: '403 sources', maxResults: 2 };
        const output = await new FirecrawlMcpClient(scripted).execute(
          'web.research.search', '请研究并总结', '', args, config()
        );

        expect(resultForUrl(output.results, outerUrl).status).assertEqual('error');
        expect(resultForUrl(output.results, originUrl).status).assertEqual('blocked_by_site');
      });
  });
}
