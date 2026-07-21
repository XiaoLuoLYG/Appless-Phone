import {
  A2UI_COMPONENT_COLUMN,
  A2UI_COMPONENT_ERROR_NOTICE,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_TEXT,
  A2UI_VERSION,
  A2uiAction,
  A2uiComponent,
  A2uiDataValue,
  A2uiEnvelope,
  A2uiLabelValueData,
  A2uiSummaryData,
  ActionOffer,
  AggregateSearchResult,
  CreateUiTaskPayload,
  DataResult,
  DynamicGenericToolResult,
  FlightStructuredData,
  FoodStructuredData,
  GenericStructuredData,
  GmailSearchStructuredData,
  HotelDetailResult,
  HotelSearchResult,
  MailSearchStructuredData,
  SocialHubStructuredData,
  TrainStructuredData,
  TravelStructuredData,
  UiLayoutPlanner,
  UiRenderResult,
  UiTaskRenderer,
  aggregateSearchA2ui,
  calendarAuthRequiredA2ui,
  flightStructuredDataA2ui,
  foodStructuredDataA2ui,
  genericToolResultsA2ui,
  gmailAuthRequiredA2ui,
  gmailSearchStructuredDataA2ui,
  gmailThreadResultsA2ui,
  hotelDetailA2uiFromOffers,
  hotelSearchA2uiFromOffers,
  mailResultsFromDynamicA2ui,
  mailSearchStructuredDataA2ui,
  mapsDataResultA2ui,
  mediaVideoStructuredDataA2ui,
  mergeA2uiLayout,
  parseA2uiJsonl,
  socialHubStructuredDataA2ui,
  toolDefinitionForToolId,
  trainStructuredDataA2ui,
  travelStructuredDataA2ui
} from '@loop/agent-core';

type StructuredValue = Object | string | number | boolean | null | undefined;
type StructuredRecord = Record<string, StructuredValue>;

const DEFAULT_LAYOUT_TIMEOUT_MS: number = 6000;
const MAX_LAYOUT_TIMEOUT_MS: number = 12000;
const MAX_LAYOUT_PROMPT_LENGTH: number = 4096;
const MAX_LAYOUT_OUTPUT_LENGTH: number = 32768;
const ACTION_TARGET_KEYS: string[] = [
  'requestKey', 'threadId', 'messageId', 'hotelId', 'itemId', 'eventId', 'orderId', 'traceId', 'bookingUrl', 'url'
];

interface PromptOffer {
  offerId: string;
  label: string;
  variant: string;
}

interface ActionStatusRecord {
  actionId?: string;
  status?: string;
  message?: string;
}

function recordOf(value: StructuredValue): StructuredRecord | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as StructuredRecord;
}

function hasArray(record: StructuredRecord | null, key: string): boolean {
  return record !== null && Array.isArray(record[key]);
}

function hasText(record: StructuredRecord | null, key: string): boolean {
  return record !== null && typeof record[key] === 'string';
}

function cloneDataResults(data: DataResult[]): DataResult[] {
  return JSON.parse(JSON.stringify(data)) as DataResult[];
}

function cloneOffers(offers: ActionOffer[]): ActionOffer[] {
  return JSON.parse(JSON.stringify(offers)) as ActionOffer[];
}

function offersForTool(data: DataResult, offers: ActionOffer[]): ActionOffer[] {
  const definition = toolDefinitionForToolId(data.toolId);
  if (definition === null) {
    return [];
  }
  return offers.filter((offer: ActionOffer): boolean => definition.actions.indexOf(offer.actionId) >= 0);
}

function offerTarget(offer: ActionOffer): string {
  const args = recordOf(offer.args);
  if (args === null) {
    return '';
  }
  for (let index = 0; index < ACTION_TARGET_KEYS.length; index++) {
    const value = args[ACTION_TARGET_KEYS[index]];
    if (typeof value === 'string' && value.trim().length > 0) {
      return ACTION_TARGET_KEYS[index] + ':' + value;
    }
    if (typeof value === 'number' && Number.isFinite(value)) {
      return ACTION_TARGET_KEYS[index] + ':' + value.toString();
    }
  }
  return '';
}

function hasAmbiguousOfferTargets(data: DataResult[], offers: ActionOffer[]): boolean {
  if (offers.length === 0) {
    return false;
  }
  if (data.length > 1) {
    return true;
  }
  const targets: Set<string> = new Set<string>();
  for (let index = 0; index < offers.length; index++) {
    const target = offerTarget(offers[index]);
    if (target.length === 0 && offers.length > 1) {
      return true;
    }
    if (target.length > 0) {
      targets.add(target);
    }
  }
  return targets.size > 1;
}

function boundedTimeout(value: number | undefined): number {
  if (value === undefined || !Number.isFinite(value) || value <= 0) {
    return DEFAULT_LAYOUT_TIMEOUT_MS;
  }
  return Math.min(Math.floor(value), MAX_LAYOUT_TIMEOUT_MS);
}

function rendered(jsonl: string): UiRenderResult {
  return { jsonl };
}

function messageJsonl(
  surfaceId: string,
  title: string,
  message: string,
  componentType: string,
  status: string,
  intent: string
): string {
  const text = message.substring(0, 300);
  const components: A2uiComponent[] = [
    {
      id: 'root',
      component: A2UI_COMPONENT_SURFACE_ROOT,
      child: 'message',
      title,
      status
    },
    {
      id: 'message',
      component: componentType,
      title,
      text,
      body: text,
      status
    }
  ];
  const envelopes: A2uiEnvelope[] = [
    {
      version: A2UI_VERSION,
      createSurface: {
        surfaceId,
        root: 'root',
        title,
        intent,
        status,
        sendDataModel: true
      }
    },
    {
      version: A2UI_VERSION,
      updateComponents: { surfaceId, components }
    }
  ];
  return envelopes.map((envelope: A2uiEnvelope): string => JSON.stringify(envelope)).join('\n') + '\n';
}

function errorJsonl(surfaceId: string, message: string): string {
  return messageJsonl(
    surfaceId, '结果无法显示', message, A2UI_COMPONENT_ERROR_NOTICE, 'error', 'error'
  );
}

function genericData(data: DataResult): GenericStructuredData | null {
  const record = recordOf(data.data);
  return hasArray(record, 'results') ? data.data as GenericStructuredData : null;
}

function mailThreadDynamic(data: DataResult): DynamicGenericToolResult | null {
  const record = recordOf(data.data);
  if (!hasText(record, 'provider') || !hasText(record, 'requestKey') ||
    !hasText(record, 'threadId') || !hasText(record, 'messageId') || !hasText(record, 'subject') ||
    !hasText(record, 'from') || !hasArray(record, 'to') || !hasText(record, 'body') ||
    !hasText(record, 'bodyHtml')) {
    return null;
  }
  const provider = record!['provider'] as string;
  const body = record!['body'] as string;
  const bodyHtml = record!['bodyHtml'] as string;
  const rows: A2uiLabelValueData[] = [
    { label: 'Provider', value: provider },
    { label: 'Request Key', value: record!['requestKey'] as string },
    { label: 'Thread ID', value: record!['threadId'] as string },
    { label: 'Message ID', value: record!['messageId'] as string },
    { label: 'From', value: record!['from'] as string },
    { label: 'To', value: (record!['to'] as string[]).join(', ') }
  ];
  return {
    sourceTag: provider === 'gmail' ? 'Gmail API' : 'QQ Mail',
    toolName: provider === 'gmail' ? 'users.threads.get' : data.toolId,
    title: record!['subject'] as string,
    status: 'success',
    summary: body.length > 0 ? body : bodyHtml,
    rows,
    rawPreview: JSON.stringify({
      provider,
      requestKey: record!['requestKey'],
      threadId: record!['threadId'],
      messageId: record!['messageId']
    })
  };
}

function canonicalJsonl(data: DataResult, offers: ActionOffer[], surfaceId: string): string {
  const record = recordOf(data.data);
  switch (data.outputSchema) {
    case 'travelOptions':
      if (!hasArray(record, 'options') || !hasArray(record, 'rows')) {
        throw new Error('travelOptions data is malformed');
      }
      return travelStructuredDataA2ui(surfaceId, data.data as TravelStructuredData);
    case 'trains':
      if (!hasArray(record, 'trains')) {
        throw new Error('trains data is malformed');
      }
      return trainStructuredDataA2ui(surfaceId, data.data as TrainStructuredData);
    case 'flights':
      if (!hasArray(record, 'flights')) {
        throw new Error('flights data is malformed');
      }
      return flightStructuredDataA2ui(surfaceId, data.data as FlightStructuredData);
    case 'foodChoices':
      if (!hasArray(record, 'foods') || !hasArray(record, 'rows')) {
        throw new Error('foodChoices data is malformed');
      }
      return foodStructuredDataA2ui(surfaceId, data.data as FoodStructuredData);
    case 'hotelSearchResults':
      if (!hasArray(record, 'hotels') || record === null || record['ok'] !== true) {
        throw new Error('hotelSearchResults data is malformed');
      }
      return hotelSearchA2uiFromOffers(
        surfaceId, data.data as HotelSearchResult, offers, data.warnings
      );
    case 'hotelRatePlans':
      if (!hasArray(record, 'rates') || record === null || record['ok'] !== true) {
        throw new Error('hotelRatePlans data is malformed');
      }
      return hotelDetailA2uiFromOffers(
        surfaceId, data.data as HotelDetailResult, offers, data.warnings
      );
    case 'places':
    case 'place':
      if (!hasArray(record, 'places') || !hasText(record, 'query')) {
        throw new Error('maps data is malformed');
      }
      return mapsDataResultA2ui(surfaceId, data);
    case 'mediaVideos':
    case 'youtubeVideos': {
      const generic = genericData(data);
      if (generic === null) {
        throw new Error('video data is malformed');
      }
      return mediaVideoStructuredDataA2ui(surfaceId, data.toolId, generic);
    }
    case 'aggregateSearch':
      if (!hasArray(record, 'videos') || !hasArray(record, 'posts') || !hasArray(record, 'sourceStatuses')) {
        throw new Error('aggregateSearch data is malformed');
      }
      return aggregateSearchA2ui(surfaceId, data.data as AggregateSearchResult);
    case 'socialHubFeed':
      if (!hasArray(record, 'items') || !hasArray(record, 'connections')) {
        throw new Error('socialHubFeed data is malformed');
      }
      return socialHubStructuredDataA2ui(surfaceId, data.data as SocialHubStructuredData);
    case 'mailThreads':
      if (!hasArray(record, 'threads') || !hasArray(record, 'statuses') || !hasArray(record, 'extras')) {
        throw new Error('mailThreads data is malformed');
      }
      return data.toolId === 'gmail.mail.search' ?
        gmailSearchStructuredDataA2ui(surfaceId, data.toolId, data.data as GmailSearchStructuredData) :
        mailSearchStructuredDataA2ui(surfaceId, data.toolId, data.data as MailSearchStructuredData);
    case 'mailThread': {
      const thread = mailThreadDynamic(data);
      if (thread === null) {
        throw new Error('mailThread data is malformed');
      }
      return data.toolId === 'gmail.thread.read' ?
        gmailThreadResultsA2ui(surfaceId, data.toolId, [thread]) :
        mailResultsFromDynamicA2ui(surfaceId, data.toolId, [thread]);
    }
    case 'youtubePlaylists':
    case 'youtubeSubscriptions':
    case 'calendarEvents':
    case 'genericToolResults': {
      const generic = genericData(data);
      if (generic === null) {
        throw new Error(data.outputSchema + ' data is malformed');
      }
      return genericToolResultsA2ui(surfaceId, data.toolId, generic.results);
    }
    default:
      throw new Error('Unsupported structured output schema: ' + data.outputSchema);
  }
}

function authJsonl(data: DataResult, surfaceId: string): string | null {
  if (data.error === undefined || data.error.code !== 'AUTH_REQUIRED') {
    return null;
  }
  if (data.toolId.indexOf('gmail.') === 0 || data.toolId.indexOf('youtube.') === 0) {
    return gmailAuthRequiredA2ui(surfaceId, data.toolId, data.error.message);
  }
  if (data.toolId.indexOf('calendar.') === 0) {
    return calendarAuthRequiredA2ui(surfaceId, data.toolId, data.error.message);
  }
  return null;
}

function cloneComponent(component: A2uiComponent, prefix: string): A2uiComponent {
  const cloned = JSON.parse(JSON.stringify(component)) as A2uiComponent;
  cloned.id = prefix + component.id;
  if (component.child !== undefined) {
    cloned.child = prefix + component.child;
  }
  if (component.children !== undefined) {
    cloned.children = component.children.map((id: string): string => prefix + id);
  }
  if (component.actions !== undefined) {
    cloned.actions = JSON.parse(JSON.stringify(component.actions)) as A2uiAction[];
  }
  return cloned;
}

function mergeDataValue(left: A2uiDataValue, right: A2uiDataValue): A2uiDataValue {
  if (Array.isArray(left) && Array.isArray(right)) {
    const combined: Object[] = [];
    (left as Object[]).forEach((item: Object) => combined.push(item));
    (right as Object[]).forEach((item: Object) => combined.push(item));
    return combined as A2uiDataValue;
  }
  return left;
}

function aggregateJsonl(jsonls: string[], surfaceId: string): string {
  if (jsonls.length === 1) {
    return jsonls[0];
  }
  const components: A2uiComponent[] = [];
  const children: string[] = [];
  const componentKeys: Set<string> = new Set<string>();
  const dataByPath: Map<string, A2uiDataValue> = new Map<string, A2uiDataValue>();
  const pathOrder: string[] = [];
  for (let resultIndex = 0; resultIndex < jsonls.length; resultIndex++) {
    const parsed = parseA2uiJsonl(jsonls[resultIndex]);
    if (parsed.error.length > 0) {
      throw new Error(parsed.error);
    }
    let rootId = '';
    let resultComponents: A2uiComponent[] = [];
    parsed.envelopes.forEach((envelope: A2uiEnvelope) => {
      if (envelope.createSurface !== undefined && envelope.createSurface.root !== undefined) {
        rootId = envelope.createSurface.root;
      }
      if (envelope.updateComponents !== undefined) {
        resultComponents = envelope.updateComponents.components;
      }
      if (envelope.updateDataModel !== undefined) {
        const path = envelope.updateDataModel.path;
        const current = dataByPath.get(path);
        if (current === undefined) {
          dataByPath.set(path, envelope.updateDataModel.value);
          pathOrder.push(path);
        } else {
          dataByPath.set(path, mergeDataValue(current, envelope.updateDataModel.value));
        }
      }
    });
    if (rootId.length === 0 || resultComponents.length === 0) {
      throw new Error('Structured renderer returned an incomplete surface');
    }
    const prefix = 'result_' + resultIndex.toString() + '_';
    for (let componentIndex = 0; componentIndex < resultComponents.length; componentIndex++) {
      const component = resultComponents[componentIndex];
      if (component.id === rootId) {
        const rootChildren = component.children === undefined ?
          (component.child === undefined ? [] : [component.child]) : component.children;
        rootChildren.forEach((id: string) => children.push(prefix + id));
        continue;
      }
      const key = component.component + '\n' + (component.dataPath === undefined ? prefix + component.id : component.dataPath);
      if (componentKeys.has(key)) {
        continue;
      }
      componentKeys.add(key);
      components.push(cloneComponent(component, prefix));
    }
  }
  const root: A2uiComponent = {
    id: 'root',
    component: A2UI_COMPONENT_SURFACE_ROOT,
    child: 'results',
    title: '结构化结果',
    status: 'ready'
  };
  const column: A2uiComponent = {
    id: 'results',
    component: A2UI_COMPONENT_COLUMN,
    children,
    title: '结构化结果',
    status: 'ready'
  };
  const envelopes: A2uiEnvelope[] = [
    {
      version: A2UI_VERSION,
      createSurface: {
        surfaceId,
        root: 'root',
        title: '结构化结果',
        intent: 'structured_results',
        status: 'ready',
        sendDataModel: true
      }
    },
    {
      version: A2UI_VERSION,
      updateComponents: { surfaceId, components: [root, column].concat(components) }
    }
  ];
  pathOrder.forEach((path: string) => {
    const value = dataByPath.get(path);
    if (value !== undefined) {
      envelopes.push({
        version: A2UI_VERSION,
        updateDataModel: { surfaceId, path, value }
      });
    }
  });
  return envelopes.map((envelope: A2uiEnvelope): string => JSON.stringify(envelope)).join('\n') + '\n';
}

function componentDataPaths(jsonl: string): string[] {
  const paths: string[] = [];
  const parsed = parseA2uiJsonl(jsonl);
  if (parsed.error.length > 0) {
    return paths;
  }
  parsed.envelopes.forEach((envelope: A2uiEnvelope) => {
    if (envelope.updateComponents === undefined) {
      return;
    }
    envelope.updateComponents.components.forEach((component: A2uiComponent) => {
      if (component.dataPath !== undefined && paths.indexOf(component.dataPath) < 0) {
        paths.push(component.dataPath);
      }
    });
  });
  return paths;
}

function preservesSemanticPaths(baseline: string, candidate: string): boolean {
  const required = componentDataPaths(baseline);
  const actual = componentDataPaths(candidate);
  for (let index = 0; index < required.length; index++) {
    if (actual.indexOf(required[index]) < 0) {
      return false;
    }
  }
  return true;
}

export class StructuredToolUiRenderer implements UiTaskRenderer {
  private readonly layoutPlanner: UiLayoutPlanner | null;
  private readonly layoutTimeoutMs: number;

  constructor(
    layoutPlanner: UiLayoutPlanner | null = null,
    layoutTimeoutMs?: number
  ) {
    this.layoutPlanner = layoutPlanner;
    this.layoutTimeoutMs = boundedTimeout(layoutTimeoutMs);
  }

  async skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult> {
    const intent = task.intent.length > 0 ? task.intent : 'structured results';
    return rendered(messageJsonl(
      surfaceId,
      '正在准备结果',
      '正在等待 ' + intent.substring(0, 120) + ' 的真实结果。',
      A2UI_COMPONENT_TEXT,
      'calling_tool',
      'structured_results'
    ));
  }

  async result(
    _task: CreateUiTaskPayload,
    data: DataResult[],
    offers: ActionOffer[],
    surfaceId: string
  ): Promise<UiRenderResult> {
    if (data.length === 0) {
      return rendered(errorJsonl(surfaceId, '没有可展示的结构化结果。'));
    }
    try {
      const safeData = cloneDataResults(data);
      const safeOffers = cloneOffers(offers);
      const jsonls: string[] = [];
      for (let index = 0; index < safeData.length; index++) {
        const auth = authJsonl(safeData[index], surfaceId);
        jsonls.push(auth === null ? canonicalJsonl(
          safeData[index], offersForTool(safeData[index], safeOffers), surfaceId
        ) : auth);
      }
      const baseline = aggregateJsonl(jsonls, surfaceId);
      return rendered(await this.layout(safeData, safeOffers, surfaceId, baseline));
    } catch (_error) {
      return rendered(errorJsonl(surfaceId, '结构化结果格式无效或暂不受支持。'));
    }
  }

  async error(
    _task: CreateUiTaskPayload,
    message: string,
    surfaceId: string
  ): Promise<UiRenderResult> {
    return rendered(errorJsonl(surfaceId, message));
  }

  async actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult> {
    const status = payload as ActionStatusRecord;
    const message = status.message === undefined || status.message.trim().length === 0 ?
      (status.status === undefined ? '操作状态已更新。' : '操作状态：' + status.status) : status.message;
    const summary: A2uiSummaryData = {
      text: message.substring(0, 300),
      toolName: status.actionId === undefined ? 'action' : status.actionId,
      dataLabel: 'actionStatus',
      count: 0
    };
    const envelope: A2uiEnvelope = {
      version: A2UI_VERSION,
      updateDataModel: { surfaceId, path: '/summary', value: summary }
    };
    return rendered(JSON.stringify(envelope));
  }

  private async layout(
    data: DataResult[],
    offers: ActionOffer[],
    surfaceId: string,
    baseline: string
  ): Promise<string> {
    if (this.layoutPlanner === null || !data.some((item: DataResult): boolean =>
      item.status === 'success' || item.status === 'partial') || hasAmbiguousOfferTargets(data, offers)) {
      return baseline;
    }
    let timerId: number = -1;
    const timeout = new Promise<string | null>((resolve: (value: string | null) => void) => {
      timerId = setTimeout((): void => resolve(null), this.layoutTimeoutMs);
    });
    try {
      const candidate = await Promise.race<string | null>([
        this.layoutPlanner.plan(this.layoutPrompt(data, offers, baseline), surfaceId),
        timeout
      ]);
      if (candidate === null || candidate.length > MAX_LAYOUT_OUTPUT_LENGTH) {
        return baseline;
      }
      const merged = mergeA2uiLayout(baseline, candidate, surfaceId, offers);
      return preservesSemanticPaths(baseline, merged) ? merged : baseline;
    } catch (_error) {
      return baseline;
    } finally {
      if (timerId >= 0) {
        clearTimeout(timerId);
      }
    }
  }

  private layoutPrompt(
    data: DataResult[],
    offers: ActionOffer[],
    baseline: string
  ): string {
    const schemas: string[] = [];
    data.forEach((item: DataResult) => {
      schemas.push(item.outputSchema + ':' + item.status);
    });
    const promptOffers: PromptOffer[] = [];
    offers.slice(0, 24).forEach((offer: ActionOffer) => {
      promptOffers.push({
        offerId: offer.offerId.substring(0, 160),
        label: offer.label.substring(0, 80),
        variant: offer.variant.substring(0, 24)
      });
    });
    const prompt = 'Arrange the existing structured result without inventing facts.\n' +
      'schemas=' + schemas.slice(0, 24).join(',') + '\n' +
      'allowedDataPaths=' + componentDataPaths(baseline).slice(0, 24).join(',') + '\n' +
      'offers=' + JSON.stringify(promptOffers) + '\n' +
      'Use only the supplied data paths and offerId references. Preserve every semantic data path.';
    return prompt.substring(0, MAX_LAYOUT_PROMPT_LENGTH);
  }
}
