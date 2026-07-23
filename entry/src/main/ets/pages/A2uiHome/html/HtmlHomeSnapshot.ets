import { aiLogInfo } from '@loop/agent-core';
import {
  A2UI_COMPONENT_ACTION_BAR,
  A2UI_COMPONENT_AGGREGATE_SEARCH,
  A2UI_COMPONENT_COLUMN,
  A2UI_COMPONENT_ERROR_NOTICE,
  A2UI_COMPONENT_FLIGHT_BOARD,
  A2UI_COMPONENT_FOOD_CHOICES,
  A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
  A2UI_COMPONENT_INFO_ROWS,
  A2UI_COMPONENT_ROW,
  A2UI_COMPONENT_SOCIAL_HUB,
  A2UI_COMPONENT_STRIPE_RECEIVING_ACCOUNT_CARD,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_TEXT,
  A2UI_COMPONENT_THINKING_CARD,
  A2UI_COMPONENT_THINKING_STREAM,
  A2UI_COMPONENT_TOOL_CONNECT_CARD,
  A2UI_COMPONENT_TRAVEL_OPTIONS,
  A2UI_COMPONENT_TRAIN_OPTIONS,
  A2UI_COMPONENT_MULTI_TASK_BOARD,
  A2uiAction,
  A2uiComponent,
  A2uiDynamicToolConnectData,
  A2uiFoodData,
  A2uiFlightData,
  A2uiGenericToolResultData,
  A2uiLabelValueData,
  A2uiMessage,
  A2uiSummaryData,
  A2uiSurfaceState,
  A2uiTrainData,
  A2uiTravelOptionData,
  AggregateSearchPost,
  AggregateSearchResult,
  AggregateSearchSourceStatus,
  AggregateSearchVideo,
  StripeReceivingAccountCardData
} from '@loop/agent-core';
import {
  actionsOf,
  dynamicToolConnect,
  flightOptions,
  foodOptions,
  genericToolResults,
  labelValues,
  personaMemoryData,
  personaRuntimeData,
  resolveData,
  socialHubConnections,
  socialHubDraft,
  socialHubItems,
  stripeReceivingAccount,
  trainOptions,
  travelOptions
} from '@loop/agent-core';
import {
  componentBodyOf,
  componentStatusOf,
  componentTextOf,
  componentTitleOf,
  findA2uiComponent
} from '../render/A2uiRenderData';
import {
  RideEstimateCard,
  RideToolPanelState,
  buildRideToolPanelState,
  isRideToolResult
} from '../state/RideToolResultsState';
import { gmailOpenDraftAction, gmailReplyDraftAction } from '@loop/agent-core';
import { mailReplyDraftAction } from '@loop/agent-core';
import { isMediaVideoResult, mediaVideoPlaybackAction, officialMediaVideoPlaybackUrl } from '@loop/agent-core';
import { SocialHubConnectionData, SocialHubDraftData, SocialHubItemData } from '@loop/agent-core';
import {
  HtmlHomeAction,
  HtmlHomeBlock,
  HtmlHomeDocument,
  HtmlHomeHistoryItem,
  HtmlHomeKind,
  HtmlHomeMediaEmbed,
  HtmlHomeMetric,
  HtmlHomePersona,
  HtmlHomePersonaMemory,
  HtmlHomeSource,
  HtmlHomeStripeReceiving,
  HtmlHomeTimelineItem
} from './HtmlHomeTypes';

const HTML_HOME_VERSION: number = 1;
const HISTORY_LIMIT: number = 6;
type HtmlHomeTextValue = Object | string | number | boolean | null | undefined;

interface HtmlHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy: boolean;
}

interface StripeOnboardingActionArgs {
  onboardingUrl: string;
}

interface MailDetailActionArgs {
  requestKey: string;
  provider: string;
  threadId: string;
  messageId: string;
  subject: string;
}

export interface CreateHtmlHomeDocumentParams {
  surface?: A2uiSurfaceState;
  messages: A2uiMessage[];
  isBusy: boolean;
  isAwaitingFirstSurface: boolean;
  inputText?: string;
}

function emptyHtmlPersona(): HtmlHomePersona {
  return {
    id: '',
    name: '',
    avatarKey: '',
    status: '',
    reason: ''
  };
}

function emptyHtmlPersonaMemory(): HtmlHomePersonaMemory {
  return {
    summary: '',
    preferences: []
  };
}

function htmlPersona(surface: A2uiSurfaceState): HtmlHomePersona {
  const persona = personaRuntimeData(surface);
  return {
    id: persona.id,
    name: persona.name,
    avatarKey: persona.avatarKey,
    status: persona.status,
    reason: persona.reason
  };
}

function htmlPersonaMemory(surface: A2uiSurfaceState): HtmlHomePersonaMemory {
  const memory = personaMemoryData(surface);
  return {
    summary: memory.summary,
    preferences: memory.preferences
  };
}

export function createHtmlHomeDocument(params: CreateHtmlHomeDocumentParams): HtmlHomeDocument {
  const prompt = firstText(params.inputText, lastUserMessage(params.messages));
  if (params.surface === undefined || params.surface === null) {
    return params.isBusy || params.isAwaitingFirstSurface ? pendingDocument(params, prompt) : welcomeDocument(params);
  }

  const surface = params.surface;
  const kind = kindOf(surface);
  const root = findA2uiComponent(surface, surface.rootId.length > 0 ? surface.rootId : 'root');
  const aggregate = kind === 'aggregate-search' ? aggregateSearchData(surface) : null;
  const aggregateComponent = kind === 'aggregate-search' ? firstComponentByName(surface, A2UI_COMPONENT_AGGREGATE_SEARCH) : null;
  const aggregateTitle = aggregateComponent === null ? '' : componentTitleOf(aggregateComponent);
  const aggregateBaseTitle = firstText(surface.title, surface.surfaceId, 'A2UI');
  const aggregateSubtitle = aggregate === null
    ? firstText(surface.error, prompt)
    : firstText(aggregate.query, aggregate.summary, firstText(surface.error, prompt));
  const baseDocument: HtmlHomeDocument = {
    version: HTML_HOME_VERSION,
    source: sourceOf(kind, surface, params.isBusy),
    kind: kind,
    title: kind === 'aggregate-search' ? firstText(aggregateTitle, aggregateBaseTitle) : aggregateBaseTitle,
    subtitle: kind === 'aggregate-search' ? aggregateSubtitle : firstText(surface.error, prompt),
    chips: [],
    metrics: [],
    timeline: [],
    blocks: [],
    actions: [],
    history: recentHistory(params.messages),
    persona: htmlPersona(surface),
    personaMemory: htmlPersonaMemory(surface),
    rawSurfaceRoot: root,
    generatedAt: new Date().toISOString()
  };
  const document: HtmlHomeDocument = withBusy(baseDocument, params.isBusy);

  if (kind === 'multi-task') {
    appendMultiTaskBlocks(document, surface);
    dropCompletedThinkingBlocks(document, params.isBusy);
    return document;
  }

  surface.components.forEach((component: A2uiComponent) => {
    appendComponentActions(document.actions, component);
    appendBlocksForComponent(document, surface, component);
  });
  if (kind === 'aggregate-search' && aggregateComponent === null && aggregate !== null && hasAggregateData(aggregate)) {
    appendAggregateSearchBlocks(document, surface, aggregateSearchFallbackComponent(surface));
  }

  dropCompletedThinkingBlocks(document, params.isBusy);
  return document;
}

function welcomeDocument(params: CreateHtmlHomeDocumentParams): HtmlHomeDocument {
  const document: HtmlHomeDocument = {
    version: HTML_HOME_VERSION,
    source: 'welcome',
    kind: 'welcome',
    title: 'Appless',
    subtitle: '',
    chips: [],
    metrics: [],
    timeline: [],
    blocks: [],
    actions: [],
    history: recentHistory(params.messages),
    persona: emptyHtmlPersona(),
    personaMemory: emptyHtmlPersonaMemory(),
    rawSurfaceRoot: null,
    generatedAt: new Date().toISOString()
  };
  return withBusy(document, params.isBusy);
}

function pendingDocument(params: CreateHtmlHomeDocumentParams, prompt: string): HtmlHomeDocument {
  const timeline: HtmlHomeTimelineItem[] = [];
  if (prompt.length > 0) {
    timeline.push({
      title: 'prompt',
      subtitle: prompt,
      status: 'pending'
    });
  }
  const document: HtmlHomeDocument = {
    version: HTML_HOME_VERSION,
    source: 'pending',
    kind: 'thinking',
    title: 'Generating',
    subtitle: prompt,
    chips: [],
    metrics: [],
    timeline: timeline,
    blocks: [],
    actions: [],
    history: recentHistory(params.messages),
    persona: emptyHtmlPersona(),
    personaMemory: emptyHtmlPersonaMemory(),
    rawSurfaceRoot: null,
    generatedAt: new Date().toISOString()
  };
  return withBusy(document, params.isBusy);
}

function parseEmbeddedSurface(value: HtmlHomeTextValue): A2uiSurfaceState | null {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  const record = value as Record<string, HtmlHomeTextValue | A2uiComponent[]>;
  const surfaceId = firstText(record.surfaceId as string, '');
  if (surfaceId.length === 0) {
    return null;
  }
  const components = Array.isArray(record.components) ? record.components as A2uiComponent[] : [];
  return {
    surfaceId: surfaceId,
    rootId: firstText(record.rootId as string, 'root'),
    title: firstText(record.title as string, ''),
    intent: firstText(record.intent as string, 'general'),
    status: firstText(record.status as string, 'ready'),
    components: components,
    dataModelJson: firstText(record.dataModelJson as string, '{}'),
    error: firstText(record.error as string, ''),
    sequence: typeof record.sequence === 'number' ? record.sequence as number : 0
  };
}

function embeddedKindForSection(toolId: string, surface: A2uiSurfaceState): HtmlHomeKind {
  if (toolId.indexOf('luckin.') === 0) {
    return 'luckin';
  }
  if (toolId === 'flight.search' || toolId === 'train.search' || toolId === 'travel.search') {
    return 'travel';
  }
  if (toolId === 'food.search') {
    return 'food';
  }
  if (toolId === 'hotel.search') {
    return 'hotel';
  }
  return kindOf(surface);
}

function buildEmbeddedDocumentFromSurface(
  embedded: A2uiSurfaceState,
  kind: HtmlHomeKind,
  persona: HtmlHomePersona,
  personaMemory: HtmlHomePersonaMemory
): HtmlHomeDocument {
  const root = findA2uiComponent(embedded, embedded.rootId.length > 0 ? embedded.rootId : 'root');
  const document: HtmlHomeDocument = {
    version: HTML_HOME_VERSION,
    source: 'tool',
    kind: kind,
    title: firstText(embedded.title, embedded.surfaceId),
    subtitle: firstText(embedded.error),
    chips: [],
    metrics: [],
    timeline: [],
    blocks: [],
    actions: [],
    history: [],
    persona: persona,
    personaMemory: personaMemory,
    rawSurfaceRoot: root,
    generatedAt: new Date().toISOString()
  };
  embedded.components.forEach((component: A2uiComponent) => {
    appendComponentActions(document.actions, component);
    appendBlocksForComponent(document, embedded, component);
  });
  dropCompletedThinkingBlocks(document, false);
  return document;
}

function multiTaskSectionTitle(toolId: string, title: string): string {
  const normalizedTitle = title.trim();
  if (normalizedTitle.length > 0 && normalizedTitle !== toolId) {
    return normalizedTitle;
  }
  if (toolId === 'flight.search') {
    return '航班';
  }
  if (toolId === 'food.search') {
    return '美食';
  }
  if (toolId === 'train.search') {
    return '高铁';
  }
  if (toolId === 'travel.search') {
    return '出行';
  }
  if (toolId.indexOf('luckin.') === 0) {
    return '瑞幸点单';
  }
  if (toolId === 'ride.estimate') {
    return '打车';
  }
  if (toolId === 'payment.send') {
    return '支付';
  }
  return normalizedTitle.length > 0 ? normalizedTitle : toolId;
}

function appendMultiTaskBlocks(document: HtmlHomeDocument, surface: A2uiSurfaceState): void {
  let board: Record<string, Object | string | number | boolean | null | undefined> | null = null;
  let sections: Record<string, Object | string | number | boolean | null | undefined> | null = null;
  try {
    const parsed = JSON.parse(surface.dataModelJson) as Record<string, Object | string | number | boolean | null | undefined>;
    const boardValue = parsed.multiTask;
    if (boardValue !== undefined && boardValue !== null && typeof boardValue === 'object' && !Array.isArray(boardValue)) {
      board = boardValue as Record<string, Object | string | number | boolean | null | undefined>;
    }
    const sectionValue = parsed.sections;
    if (sectionValue !== undefined && sectionValue !== null && typeof sectionValue === 'object' && !Array.isArray(sectionValue)) {
      sections = sectionValue as Record<string, Object | string | number | boolean | null | undefined>;
    }
  } catch (_error) {
  }
  if (board !== null) {
    document.activeSectionId = firstText(board.activeSectionId as string, document.activeSectionId ?? '');
    const boardMode = firstText(board.mode as string).trim();
    if (boardMode === 'serial' || boardMode === 'parallel') {
      document.executionMode = boardMode;
    }
    const sectionList = board.sections;
    if (Array.isArray(sectionList)) {
      for (let index = 0; index < sectionList.length; index++) {
        const meta = sectionList[index] as Record<string, Object | string | number | boolean | null | undefined>;
        const slotId = firstText(meta.slotId as string, 'slot_' + index.toString());
        const toolId = firstText(meta.toolId as string);
        const block = newBlock(
          slotId,
          'multi-task-section',
          multiTaskSectionTitle(toolId, firstText(meta.title as string, toolId, slotId))
        );
        block.sectionId = slotId;
        block.toolId = toolId;
        block.status = firstText(meta.status as string, 'loading');
        block.subtitle = firstText(meta.summary as string);
        block.completionReply = firstText(meta.completionReply as string);
        if (sections !== null) {
          const sectionContent = sections[slotId] as Record<string, Object | string | number | boolean | null | undefined> | undefined;
          if (sectionContent !== undefined) {
            block.rawPreview = firstText(sectionContent.observationDigest as string, sectionContent.summary as string);
            block.subtitle = firstText(sectionContent.summary as string, block.subtitle);
            if (block.completionReply.length === 0) {
              block.completionReply = firstText(meta.completionReply as string);
            }
            const embedded = parseEmbeddedSurface(sectionContent.embeddedSurface as HtmlHomeTextValue);
            if (embedded !== null) {
              const embeddedKind = embeddedKindForSection(firstText(block.toolId), embedded);
              block.embeddedDocument = buildEmbeddedDocumentFromSurface(
                embedded,
                embeddedKind,
                document.persona,
                document.personaMemory
              );
              if (block.embeddedDocument.blocks.length > 0) {
                block.subtitle = firstText(block.embeddedDocument.blocks[0].subtitle, block.subtitle);
              }
            }
            block.title = multiTaskSectionTitle(
              firstText(block.toolId),
              firstText(sectionContent.title as string, block.title)
            );
          }
        }
        document.blocks.push(block);
      }
    }
  }
}

function appendBlocksForComponent(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  if (component.component === A2UI_COMPONENT_MULTI_TASK_BOARD) {
    appendMultiTaskBlocks(document, surface);
    return;
  }
  if (component.component === A2UI_COMPONENT_AGGREGATE_SEARCH) {
    appendAggregateSearchBlocks(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_TRAVEL_OPTIONS) {
    appendTravelBlocks(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_TRAIN_OPTIONS) {
    appendTrainBlocks(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_FLIGHT_BOARD) {
    appendFlightBlocks(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_FOOD_CHOICES) {
    appendFoodBlocks(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_TOOL_CONNECT_CARD) {
    appendDynamicConnectBlock(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_GENERIC_TOOL_RESULTS) {
    appendGenericToolResultBlocks(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_SOCIAL_HUB) {
    appendSocialHubBlocks(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_STRIPE_RECEIVING_ACCOUNT_CARD) {
    appendStripeReceivingBlock(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_ACTION_BAR ||
    component.component === A2UI_COMPONENT_SURFACE_ROOT ||
    component.component === A2UI_COMPONENT_COLUMN ||
    component.component === A2UI_COMPONENT_ROW) {
    return;
  }
  appendGenericComponentBlock(document, surface, component);
}

function appendTravelBlocks(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const options = travelOptions(surface, component);
  options.forEach((item: A2uiTravelOptionData, index: number) => {
    const block = newBlock(component.id + '-' + index.toString(), 'travel-option', firstText(item.title, item.id, component.id));
    block.subtitle = joinText([item.from, item.to], ' -> ');
    block.status = item.status;
    block.source = firstText(item.sourceTag, item.source);
    appendMetric(block.metrics, 'source', item.source);
    appendMetric(block.metrics, 'from', item.from);
    appendMetric(block.metrics, 'to', item.to);
    appendMetric(block.metrics, 'depart', item.depart);
    appendMetric(block.metrics, 'arrive', item.arrive);
    appendMetric(block.metrics, 'duration', item.duration);
    appendMetric(block.metrics, 'price', item.price);
    appendMetric(block.metrics, 'availability', item.availability);
    appendMetric(block.rows, 'detail', item.detail);
    block.actions.push(clientAction('html_pin_travel', '固定到桌面', JSON.stringify({
      index: index,
      id: textOf(item.id),
      source: textOf(item.source),
      depart: textOf(item.depart),
      from: textOf(item.from),
      to: textOf(item.to)
    }), component.id));
    document.blocks.push(block);
  });
}

function appendTrainBlocks(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const trains = trainOptions(surface, component);
  if (trains.length === 0) {
    appendGenericComponentBlock(document, surface, component);
    return;
  }
  trains.forEach((item: A2uiTrainData, index: number) => {
    const block = newBlock(component.id + '-' + index.toString(), 'train-option', firstText(item.trainCode, component.id));
    block.subtitle = joinText([item.from, item.to], ' -> ');
    block.status = item.status;
    appendMetric(block.metrics, 'from', item.from);
    appendMetric(block.metrics, 'to', item.to);
    appendMetric(block.metrics, 'depart', item.depart);
    appendMetric(block.metrics, 'arrive', item.arrive);
    appendMetric(block.metrics, 'duration', item.duration);
    appendMetric(block.rows, 'seats', item.seats);
    appendMetric(block.rows, 'business', item.business);
    appendMetric(block.rows, 'first', item.first);
    appendMetric(block.rows, 'second', item.second);
    appendMetric(block.rows, 'noSeat', item.noSeat);
    appendMetric(block.rows, 'hardSeat', item.hardSeat);
    appendMetric(block.rows, 'sleeperSoft', item.sleeperSoft);
    block.actions.push(clientAction('html_pin_train', '固定到桌面', JSON.stringify({
      index: index,
      trainCode: textOf(item.trainCode),
      depart: textOf(item.depart),
      from: textOf(item.from),
      to: textOf(item.to)
    }), component.id));
    document.blocks.push(block);
  });
}

function appendFlightBlocks(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const flights = flightOptions(surface, component);
  if (flights.length === 0) {
    appendGenericComponentBlock(document, surface, component);
    return;
  }
  flights.forEach((item: A2uiFlightData, index: number) => {
    const block = newBlock(component.id + '-' + index.toString(), 'flight-option', firstText(item.flightNo, item.airline, component.id));
    block.subtitle = joinText([item.dep, item.arr], ' -> ');
    block.status = item.status;
    const retryDate = firstDateText(
      componentTitleOf(component),
      componentBodyOf(component),
      surface.title,
      surface.error,
      summaryText(surface)
    );
    if (retryDate.length > 0) {
      block.prompt = retryDate;
    }
    appendMetric(block.metrics, 'airline', item.airline);
    appendMetric(block.metrics, 'dep', item.dep);
    appendMetric(block.metrics, 'arr', item.arr);
    appendMetric(block.metrics, 'depTime', item.depTime);
    appendMetric(block.metrics, 'arrTime', item.arrTime);
    appendMetric(block.metrics, 'price', item.price);
    block.actions.push(clientAction('html_pin_flight', '固定到桌面', JSON.stringify({
      index: index,
      flightNo: textOf(item.flightNo),
      depTime: textOf(item.depTime),
      dep: textOf(item.dep),
      arr: textOf(item.arr)
    }), component.id));
    document.blocks.push(block);
  });
}

function appendFoodBlocks(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const foods = foodOptions(surface, component);
  foods.forEach((item: A2uiFoodData, index: number) => {
    const block = newBlock(component.id + '-' + index.toString(), 'food-result', firstText(item.name, component.id));
    block.subtitle = item.category;
    block.source = sourceTagsText(item.sourceTags);
    appendMetric(block.metrics, 'category', item.category);
    appendMetric(block.metrics, 'address', item.address);
    appendMetric(block.metrics, 'distance', item.distance);
    appendMetric(block.metrics, 'location', item.location === undefined ? '' : item.location);
    appendMetric(block.metrics, 'source', block.source === undefined ? '' : block.source);
    const payload = JSON.stringify({
      index: index,
      name: textOf(item.name),
      address: textOf(item.address),
      location: textOf(item.location),
      distance: textOf(item.distance)
    });
    block.actions.push(clientAction('html_pin_food', '固定到桌面', payload, component.id));
    block.actions.push(clientAction('html_open_food_map', '导航去', payload, component.id));
    document.blocks.push(block);
  });
}

function appendDynamicConnectBlock(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const data = dynamicToolConnect(surface);
  if (!hasConnectData(data)) {
    appendGenericComponentBlock(document, surface, component);
    return;
  }
  const block = newBlock(component.id, 'dynamic-tool-connect', firstText(data.displayName, data.toolId, componentTitleOf(component, component.id)));
  block.subtitle = data.message;
  block.status = data.status;
  block.source = firstText(data.sourceUrl, data.manifestId);
  block.credentialName = data.credentialName;
  block.credentialRef = data.credentialRef;
  block.toolId = data.toolId;
  block.prompt = data.prompt;
  appendMetric(block.metrics, 'provider', data.displayName);
  appendMetric(block.metrics, 'toolId', data.toolId);
  appendMetric(block.metrics, 'manifest', data.manifestId);
  appendMetric(block.metrics, 'source', block.source === undefined ? '' : block.source);
  appendMetric(block.metrics, 'credential', data.credentialName);
  block.actions = htmlActions(actionsOf(component).length > 0 ? actionsOf(component) : data.actions, component.id);
  block.actions.forEach((action: HtmlHomeAction) => {
    appendAction(document.actions, action);
  });
  document.blocks.push(block);
}

function appendGenericToolResultBlocks(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const results = genericToolResults(surface);
  if (results.length === 0) {
    appendGenericComponentBlock(document, surface, component);
    return;
  }
  if (hasRideToolResults(results)) {
    appendRideToolPanelBlock(document, results, component);
    return;
  }
  results.forEach((item: A2uiGenericToolResultData, index: number) => {
    const block = newBlock(component.id + '-' + index.toString(), 'generic-tool-result', firstText(item.title, item.toolName, component.id));
    block.subtitle = item.summary;
    block.status = item.status;
    block.source = item.sourceTag;
    appendMetric(block.metrics, 'source', item.sourceTag);
    appendMetric(block.metrics, 'toolName', item.toolName);
    item.rows.forEach((row: A2uiLabelValueData) => {
      appendMetric(block.rows, row.label, row.value);
    });
    if (item.rawPreview.length > 0) {
      block.rawPreview = item.rawPreview;
    }
    const mediaEmbed = mediaEmbedForResult(item);
    if (mediaEmbed !== null) {
      block.mediaEmbed = mediaEmbed;
    }
    block.actions = htmlActions(actionsOf(component).concat(item.actions === undefined ? [] : item.actions), component.id);
    if (block.actions.length === 0 && document.actions.length > 0) {
      block.actions = document.actions.slice();
    }
    const mailAction = mailReplyDraftAction(item);
    if (mailAction !== null) {
      block.actions = block.actions.concat(htmlActions([mailAction], component.id));
    }
    const gmailAction = gmailReplyDraftAction(item);
    if (gmailAction !== null) {
      block.actions = block.actions.concat(htmlActions([gmailAction], component.id));
    }
    const gmailOpenDraft = gmailOpenDraftAction(item);
    if (gmailOpenDraft !== null) {
      block.actions = block.actions.concat(htmlActions([gmailOpenDraft], component.id));
    }
    const mailDetailRead = mailDetailReadAction(item);
    if (mailDetailRead !== null) {
      block.actions = block.actions.concat(htmlActions([mailDetailRead], component.id));
    }
    const mapsOpenWeb = mapsOpenWebAction(item);
    if (mapsOpenWeb !== null) {
      block.actions = block.actions.concat(htmlActions([mapsOpenWeb], component.id));
    }
    const mediaPlayback = mediaVideoPlaybackAction(item);
    if (mediaPlayback !== null) {
      block.actions = block.actions.concat(htmlActions([mediaPlayback], component.id));
    }
    document.blocks.push(block);
  });
}

function hasRideToolResults(results: A2uiGenericToolResultData[]): boolean {
  for (let index = 0; index < results.length; index++) {
    if (isRideToolResult(results[index])) {
      return true;
    }
  }
  return false;
}

function rideDangerActions(actions: A2uiAction[]): A2uiAction[] {
  const next: A2uiAction[] = [];
  actions.forEach((action: A2uiAction) => {
    next.push({
      id: action.id,
      label: action.label,
      prompt: action.prompt,
      kind: action.kind,
      variant: 'danger',
      args: action.args
    });
  });
  return next;
}

function appendRideToolPanelBlock(
  document: HtmlHomeDocument,
  results: A2uiGenericToolResultData[],
  component: A2uiComponent
): void {
  const panel: RideToolPanelState = buildRideToolPanelState(results);
  const block = newBlock(component.id + '-ride', 'ride-tool-panel', panel.title);
  block.subtitle = firstText(panel.routeText, panel.visualLabel);
  block.status = panel.stage;
  block.source = panel.sourceText;
  appendMetric(block.metrics, 'stage', panel.stage);
  appendMetric(block.metrics, 'routeText', panel.routeText);
  appendMetric(block.metrics, 'pickupLocation', panel.pickupLocation);
  appendMetric(block.metrics, 'destinationLocation', panel.destinationLocation);
  appendMetric(block.metrics, 'selectedVehicleText', panel.selectedVehicleText);
  appendMetric(block.metrics, 'visualLabel', panel.visualLabel);
  appendMetric(block.metrics, 'showDriverMarker', panel.showDriverMarker ? 'true' : 'false');
  appendMetric(block.metrics, 'orderId', panel.orderId);
  appendMetric(block.metrics, 'statusText', panel.statusText);
  appendMetric(block.metrics, 'driverLocation', panel.driverLocation);
  appendMetric(block.metrics, 'driverName', panel.driverName);
  appendMetric(block.metrics, 'driverEtaText', panel.driverEtaText);
  appendMetric(block.metrics, 'sourceText', panel.sourceText);
  panel.estimateCards.forEach((card: RideEstimateCard) => {
    appendMetric(block.rows, 'estimate|' + card.category + '|' + card.name, card.priceText);
  });
  block.actions = htmlActions(
    panel.primaryActions
      .concat(panel.handoffActions)
      .concat(rideDangerActions(panel.destructiveActions))
      .concat(panel.secondaryActions),
    component.id
  );
  document.blocks.push(block);
}

function appendAggregateSearchBlocks(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const aggregate = aggregateSearchData(surface);
  const hasAggregateComponent = component.component === A2UI_COMPONENT_AGGREGATE_SEARCH;
  if (!hasAggregateData(aggregate) && !hasAggregateComponent && document.kind !== 'aggregate-search') {
    appendGenericComponentBlock(document, surface, component);
    return;
  }
  aggregate.videos.forEach((item: AggregateSearchVideo, index: number) => {
    const block = newBlock(component.id + '-video-' + index.toString(), 'aggregate-video', firstText(item.title, item.provider, item.id));
    block.subtitle = '';
    block.status = item.status;
    block.source = item.source;
    const mediaEmbed = mediaEmbedForResult(aggregateVideoResult(item));
    if (mediaEmbed !== null) {
      block.mediaEmbed = mediaEmbed;
    }
    document.blocks.push(block);
  });
  aggregate.posts.forEach((item: AggregateSearchPost, index: number) => {
    const block = newBlock(component.id + '-post-' + index.toString(), 'aggregate-post', firstText(item.title, item.provider, item.id));
    block.subtitle = firstText(item.text, item.author, item.handle);
    block.status = item.status;
    block.source = item.source;
    appendMetric(block.metrics, 'author', item.author);
    appendMetric(block.metrics, 'handle', item.handle);
    appendMetric(block.metrics, 'publishedAt', item.publishedAt);
    appendMetric(block.metrics, 'score', item.score);
    appendMetric(block.metrics, 'commentCount', item.commentCount);
    appendMetric(block.rows, 'url', item.url);
    item.rows.forEach((row) => {
      const label = row.label.toLowerCase();
      if (label === 'mediaurl' || label === 'image' || label === 'images' || label === 'thumbnail' ||
        label === 'cover' || label === 'pic' || label === 'picture' || label === 'url') {
        appendMetric(block.rows, row.label, row.value);
      }
    });
    document.blocks.push(block);
  });
  aggregate.sourceStatuses.forEach((item: AggregateSearchSourceStatus, index: number) => {
    if (item.message.length === 0 && item.count <= 0) {
      return;
    }
    const block = newBlock(component.id + '-status-' + index.toString(), 'aggregate-source-status', firstText(item.label, item.source));
    block.subtitle = item.message;
    block.status = item.status;
    block.source = item.source;
    appendMetric(block.metrics, 'source', item.source);
    appendMetric(block.metrics, 'count', item.count);
    document.blocks.push(block);
  });
}

function appendSocialHubBlocks(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  socialHubItems(surface).forEach((item: SocialHubItemData, index: number) => {
    const block = newBlock(component.id + '-item-' + index.toString(), 'social-hub-item', firstText(item.handle, item.author, item.platform));
    block.subtitle = item.text;
    block.status = item.unread ? 'unread' : item.kind;
    block.source = item.platform;
    block.prompt = item.id;
    appendMetric(block.metrics, 'platform', item.platform);
    appendMetric(block.metrics, 'kind', item.kind);
    appendMetric(block.metrics, 'time', item.timestamp);
    appendMetric(block.metrics, 'author', item.author);
    appendMetric(block.metrics, 'handle', item.handle);
    appendMetric(block.rows, 'text', item.text);
    appendMetric(block.rows, 'url', item.url);
    appendMetric(block.rows, 'channel', item.channel);
    appendMetric(block.rows, 'threadId', item.threadId);
    appendMetric(block.rows, 'unread', item.unread);
    if (item.id.length > 0) {
      block.actions.push(clientAction('social_hub_select_item', '查看', item.id, component.id));
      block.actions.push(clientAction('social_hub_draft_reply', '生成草稿', item.id, component.id));
    }
    if (item.url.length > 0) {
      block.actions.push(clientAction('social_hub_open_source', '打开原文', item.url, component.id));
    }
    document.blocks.push(block);
  });

  socialHubConnections(surface).forEach((connection: SocialHubConnectionData, index: number) => {
    const block = newBlock(component.id + '-connection-' + index.toString(), 'social-hub-connection', firstText(connection.displayName, connection.platform));
    block.subtitle = connection.message;
    block.status = connection.status;
    block.source = connection.platform;
    appendMetric(block.metrics, 'platform', connection.platform);
    appendMetric(block.metrics, 'status', connection.status);
    appendMetric(block.rows, 'message', connection.message);
    appendMetric(block.rows, 'accountId', connection.accountId);
    document.blocks.push(block);
  });

  const draft: SocialHubDraftData = socialHubDraft(surface);
  if (draft.text.length > 0 || draft.error.length > 0) {
    const block = newBlock(component.id + '-draft', 'social-hub-draft', '回复草稿');
    block.subtitle = draft.error;
    block.status = draft.status;
    block.source = draft.platform;
    block.prompt = draft.itemId;
    appendMetric(block.metrics, 'platform', draft.platform);
    appendMetric(block.metrics, 'status', draft.status);
    appendMetric(block.rows, 'text', draft.text);
    appendMetric(block.rows, 'error', draft.error);
    appendMetric(block.rows, 'itemId', draft.itemId);
    appendMetric(block.rows, 'localOnly', draft.localOnly);
    appendMetric(block.rows, 'sent', draft.sent);
    document.blocks.push(block);
  }
}

function mediaEmbedForResult(result: A2uiGenericToolResultData): HtmlHomeMediaEmbed | null {
  if (result.status !== 'success') {
    return null;
  }
  let pageUrl = firstText(firstText(
    genericResultRowValue(result, 'Watch URL'),
    genericResultRowValue(result, 'Playback URL'),
    genericResultRowValue(result, 'Share URL')),
    genericResultRowValue(result, 'Video URL')
  );
  if (pageUrl.length === 0 && isMediaVideoResult(result)) {
    pageUrl = firstOfficialMediaUrl(result);
  }
  if (pageUrl.length === 0 && result.toolName === 'youtube.mine.playlists') {
    const playlistId = firstYoutubePlaylistId(result);
    if (playlistId.length > 0) {
      pageUrl = 'https://www.youtube.com/playlist?list=' + playlistId;
    }
  }
  const embedUrl = mediaEmbedUrl(pageUrl, result);
  if (embedUrl.length === 0) {
    return null;
  }
  return {
    provider: firstText(result.sourceTag, result.toolName),
    title: result.title,
    embedUrl: embedUrl,
    pageUrl: pageUrl,
    thumbnail: genericResultRowValue(result, 'Thumbnail')
  };
}

function mediaEmbedUrl(pageUrl: string, result: A2uiGenericToolResultData): string {
  const youtubeId = youtubeVideoId(pageUrl, genericResultRowValue(result, 'Video ID'));
  if (youtubeId.length > 0) {
    return 'https://www.youtube.com/embed/' + encodeURIComponent(youtubeId) +
      '?playsinline=1&rel=0&enablejsapi=1&origin=https%3A%2F%2Faiphone.local';
  }
  const playlistId = youtubePlaylistId(pageUrl, genericResultRowValue(result, 'Playlist ID'));
  if (playlistId.length > 0) {
    const thumbnailVideoId = firstYoutubeThumbnailVideoId(result);
    if (thumbnailVideoId.length > 0) {
      return 'https://www.youtube.com/embed/' + encodeURIComponent(thumbnailVideoId) +
        '?playsinline=1&rel=0&enablejsapi=1&origin=https%3A%2F%2Faiphone.local';
    }
    return 'https://www.youtube.com/embed/videoseries?list=' + encodeURIComponent(playlistId) +
      '&playsinline=1&rel=0&enablejsapi=1&origin=https%3A%2F%2Faiphone.local';
  }
  const bvid = bilibiliBvid(pageUrl, genericResultRowValue(result, 'BVID'));
  if (bvid.length > 0) {
    const cid = genericResultRowValue(result, 'CID');
    return 'https://player.bilibili.com/player.html?bvid=' + encodeURIComponent(bvid) +
      (cid.length > 0 ? '&cid=' + encodeURIComponent(cid) : '') +
      '&p=1&autoplay=0&poster=true&danmaku=0&isOutside=true';
  }
  return '';
}

function firstOfficialMediaUrl(result: A2uiGenericToolResultData): string {
  for (let index = 0; index < result.rows.length; index++) {
    const parts = result.rows[index].value.split('|').join(' ').split(' ');
    for (let partIndex = 0; partIndex < parts.length; partIndex++) {
      const url = officialMediaVideoPlaybackUrl(cleanUrlToken(parts[partIndex]));
      if (url.length > 0) {
        return url;
      }
    }
  }
  return '';
}

function firstYoutubePlaylistId(result: A2uiGenericToolResultData): string {
  const direct = genericResultRowValue(result, 'Playlist ID').trim();
  if (direct.length > 0) {
    return direct;
  }
  const chunks: string[] = [result.title, result.summary, result.rawPreview];
  result.rows.forEach((row: A2uiLabelValueData) => chunks.push(row.label + ' ' + row.value));
  for (let index = 0; index < chunks.length; index++) {
    const fromUrl = youtubePlaylistId(chunks[index], '');
    if (fromUrl.length > 0) {
      return fromUrl;
    }
    const fromKey = firstJsonishValue(chunks[index], ['playlistId', 'playlist_id', 'id']);
    if (looksLikeYoutubePlaylistId(fromKey)) {
      return fromKey;
    }
  }
  return '';
}

function firstYoutubeThumbnailVideoId(result: A2uiGenericToolResultData): string {
  const chunks: string[] = [genericResultRowValue(result, 'Thumbnail'), result.rawPreview, result.summary];
  result.rows.forEach((row: A2uiLabelValueData) => chunks.push(row.value));
  for (let index = 0; index < chunks.length; index++) {
    const marker = 'i.ytimg.com/vi/';
    const hit = chunks[index].indexOf(marker);
    if (hit >= 0) {
      return tokenUntil(chunks[index].substring(hit + marker.length), ['/', '?', '&', '#', '"', '\\']);
    }
  }
  return '';
}

function firstJsonishValue(text: string, keys: string[]): string {
  for (let index = 0; index < keys.length; index++) {
    const marker = '"' + keys[index] + '"';
    const markerIndex = text.indexOf(marker);
    if (markerIndex < 0) {
      continue;
    }
    const colonIndex = text.indexOf(':', markerIndex + marker.length);
    if (colonIndex < 0) {
      continue;
    }
    const after = text.substring(colonIndex + 1).trim();
    if (after.startsWith('"')) {
      return tokenUntil(after.substring(1), ['"', '&', '#', '?', '/', ',', '}']);
    }
    return tokenUntil(after, ['"', '&', '#', '?', '/', ',', '}']);
  }
  return '';
}

function looksLikeYoutubePlaylistId(value: string): boolean {
  const id = value.trim();
  if (id.length < 8 || id.length > 80) {
    return false;
  }
  return id.startsWith('PL') || id.startsWith('UU') || id.startsWith('OLAK') ||
    id.startsWith('FL') || id.startsWith('LL') || id.startsWith('RD');
}

function cleanUrlToken(value: string): string {
  let token = value.trim();
  while (token.length > 0) {
    const last = token.charAt(token.length - 1);
    if (last === ')' || last === ']' || last === ',' || last === ';' || last === '.') {
      token = token.substring(0, token.length - 1);
    } else {
      break;
    }
  }
  return token;
}

function youtubeVideoId(pageUrl: string, rowValue: string): string {
  const direct = rowValue.trim();
  if (direct.length > 0) {
    return direct;
  }
  const watchMarker = 'youtube.com/watch?v=';
  const watchIndex = pageUrl.indexOf(watchMarker);
  if (watchIndex >= 0) {
    return tokenUntil(pageUrl.substring(watchIndex + watchMarker.length), ['&', '#', '?', '/']);
  }
  const shortMarker = 'youtu.be/';
  const shortIndex = pageUrl.indexOf(shortMarker);
  if (shortIndex >= 0) {
    return tokenUntil(pageUrl.substring(shortIndex + shortMarker.length), ['&', '#', '?', '/']);
  }
  return '';
}

function youtubePlaylistId(pageUrl: string, rowValue: string): string {
  const direct = rowValue.trim();
  if (direct.length > 0) {
    return direct;
  }
  const listMarker = 'list=';
  const listIndex = pageUrl.indexOf(listMarker);
  if (listIndex >= 0 && (pageUrl.indexOf('youtube.com/playlist?') >= 0 || pageUrl.indexOf('youtube.com/watch?') >= 0)) {
    return tokenUntil(pageUrl.substring(listIndex + listMarker.length), ['&', '#', '?', '/']);
  }
  return '';
}

function bilibiliBvid(pageUrl: string, rowValue: string): string {
  const direct = rowValue.trim();
  if (direct.startsWith('BV')) {
    return direct;
  }
  const marker = '/video/';
  const index = pageUrl.indexOf(marker);
  if (index >= 0) {
    const token = tokenUntil(pageUrl.substring(index + marker.length), ['?', '#', '/', '&']);
    return token.startsWith('BV') ? token : '';
  }
  const queryMarker = 'bvid=';
  const queryIndex = pageUrl.indexOf(queryMarker);
  if (queryIndex >= 0) {
    const token = tokenUntil(pageUrl.substring(queryIndex + queryMarker.length), ['&', '#', '?', '/']);
    return token.startsWith('BV') ? token : '';
  }
  return '';
}

function tokenUntil(value: string, stops: string[]): string {
  let end = value.length;
  for (let index = 0; index < stops.length; index++) {
    const hit = value.indexOf(stops[index]);
    if (hit >= 0 && hit < end) {
      end = hit;
    }
  }
  return value.substring(0, end).trim();
}

function mapsOpenWebAction(result: A2uiGenericToolResultData): A2uiAction | null {
  if (result.sourceTag !== 'Google Places API' && result.toolName.indexOf('maps.place.') !== 0) {
    return null;
  }
  const url = genericResultRowValue(result, 'Maps URL');
  if (url.length === 0) {
    return null;
  }
  return {
    id: 'maps.open.web',
    label: '打开 Google Maps',
    prompt: url,
    variant: 'secondary',
    kind: 'client'
  };
}

function genericResultRowValue(result: A2uiGenericToolResultData, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value.trim();
    }
  }
  return '';
}

function mailDetailReadAction(result: A2uiGenericToolResultData): A2uiAction | null {
  const source = result.sourceTag.toLowerCase();
  const rowProvider = genericResultRowValue(result, 'Provider').toLowerCase();
  const provider = rowProvider === 'qq' || source.indexOf('qq mail') >= 0 ? 'qq' :
    (rowProvider === 'gmail' || source.indexOf('gmail') >= 0 ? 'gmail' : '');
  if (provider.length === 0 || result.status !== 'success') {
    return null;
  }
  const threadId = genericResultRowValue(result, 'Thread ID');
  const messageId = genericResultRowValue(result, 'Message ID');
  const identity = provider === 'gmail' ? threadId : messageId;
  if (identity.length === 0) {
    return null;
  }
  const requestKey = provider + ':' + identity;
  const args: MailDetailActionArgs = {
    requestKey: requestKey,
    provider: provider,
    threadId: threadId,
    messageId: messageId,
    subject: result.title
  };
  const action: A2uiAction = {
    id: 'html_mail_detail_read',
    label: '加载正文',
    prompt: requestKey,
    variant: 'secondary',
    kind: 'client',
    args: args
  };
  return action;
}

function appendGenericComponentBlock(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  if (component.component === A2UI_COMPONENT_INFO_ROWS && component.id === 'memory_update') {
    appendPersonaMemoryUpdateBlock(document, surface, component);
    return;
  }
  const title = firstText(componentTitleOf(component), componentTextOf(component), component.component + ':' + component.id);
  const block = newBlock(component.id, component.component, title);
  block.subtitle = componentBodyOf(component);
  block.status = componentStatusOf(component, '');
  block.source = component.dataPath === undefined ? '' : component.dataPath;
  if (component.component === A2UI_COMPONENT_INFO_ROWS) {
    labelValues(surface, component).forEach((row: A2uiLabelValueData) => {
      appendMetric(block.rows, row.label, row.value);
    });
  }
  block.actions = htmlActions(actionsOf(component), component.id);
  if (block.subtitle !== undefined && block.subtitle.length > 0 || block.status !== undefined && block.status.length > 0 ||
    block.rows.length > 0 || block.actions.length > 0 || component.component === A2UI_COMPONENT_TEXT ||
    component.component === A2UI_COMPONENT_ERROR_NOTICE || component.component === A2UI_COMPONENT_THINKING_STREAM ||
    component.component === A2UI_COMPONENT_THINKING_CARD || component.component === A2UI_COMPONENT_INFO_ROWS ||
    component.component === A2UI_COMPONENT_TRAIN_OPTIONS || component.component === A2UI_COMPONENT_FLIGHT_BOARD) {
    document.blocks.push(block);
  }
}

function appendPersonaMemoryUpdateBlock(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const persona = personaRuntimeData(surface);
  const memory = personaMemoryData(surface);
  const title = firstText(componentTitleOf(component), persona.name.length > 0 ? persona.name + '已更新记忆' : '记忆已更新');
  const block = newBlock(component.id, 'persona-memory-update', title);
  block.subtitle = firstText(memory.summary, persona.reason, componentBodyOf(component));
  block.status = componentStatusOf(component, '');
  block.source = persona.id;
  labelValues(surface, component).forEach((row: A2uiLabelValueData) => {
    appendMetric(block.rows, row.label, row.value);
  });
  block.actions = htmlActions(actionsOf(component), component.id);
  document.blocks.push(block);
}

function appendStripeReceivingBlock(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const account: StripeReceivingAccountCardData = stripeReceivingAccount(surface);
  const block = newBlock(component.id, A2UI_COMPONENT_STRIPE_RECEIVING_ACCOUNT_CARD, firstText(account.title, componentTitleOf(component), 'Stripe 收款账户'));
  block.subtitle = account.message;
  block.status = firstText(account.status, surface.status);
  block.source = account.businessType;
  appendMetric(block.rows, 'Agent', account.displayName);
  appendMetric(block.rows, 'Email', account.email);
  appendMetric(block.rows, 'Country', account.country);
  appendMetric(block.rows, 'Stripe', account.stripeAccountId.length > 0 ? account.stripeAccountId : '未创建');
  if (account.currentlyDue.length > 0) {
    appendMetric(block.rows, '仍需资料', account.currentlyDue.join(', '));
  }
  const receiving: HtmlHomeStripeReceiving = {
    status: account.status,
    message: account.message,
    stripeAccountId: account.stripeAccountId,
    onboardingUrl: account.onboardingUrl,
    currentlyDue: account.currentlyDue.slice()
  };
  block.stripeReceiving = receiving;
  block.actions = htmlActions(actionsOf(component), component.id);
  if (account.onboardingUrl.startsWith('https://connect.stripe.com/')) {
    const args: StripeOnboardingActionArgs = { onboardingUrl: account.onboardingUrl };
    const openAction: HtmlHomeAction = {
      id: 'stripe.account.open',
      label: '打开 Stripe 托管认证',
      prompt: account.onboardingUrl,
      variant: 'primary',
      kind: 'client',
      sourceComponentId: component.id,
      args: args
    };
    block.actions = [openAction];
    removeStripeReceivingActions(document.actions);
    appendAction(document.actions, openAction);
  }
  document.blocks.push(block);
}

function removeStripeReceivingActions(actions: HtmlHomeAction[]): void {
  for (let index = actions.length - 1; index >= 0; index -= 1) {
    if (actions[index].id === 'stripe.account.open' ||
      actions[index].id === 'stripe.account.onboard' ||
      actions[index].id === 'stripe.account.create') {
      actions.splice(index, 1);
    }
  }
}

function dropCompletedThinkingBlocks(document: HtmlHomeDocument, _isBusy: boolean): void {
  if (!hasNonThinkingBlock(document.blocks)) {
    return;
  }
  document.blocks = document.blocks.filter((block: HtmlHomeBlock) => !isThinkingBlock(block));
}

function hasNonThinkingBlock(blocks: HtmlHomeBlock[]): boolean {
  for (let index = 0; index < blocks.length; index++) {
    if (!isThinkingBlock(blocks[index])) {
      return true;
    }
  }
  return false;
}

function isThinkingBlock(block: HtmlHomeBlock): boolean {
  return block.kind === A2UI_COMPONENT_THINKING_STREAM || block.kind === A2UI_COMPONENT_THINKING_CARD ||
    block.kind === 'thinking';
}

function kindOf(surface: A2uiSurfaceState): HtmlHomeKind {
  if (surface.intent === 'multi-task' || hasComponent(surface, A2UI_COMPONENT_MULTI_TASK_BOARD)) {
    return 'multi-task';
  }
  if (hasComponent(surface, A2UI_COMPONENT_SOCIAL_HUB) || surface.intent === 'social') {
    return 'social';
  }
  if (hasAggregateSearchSurface(surface)) {
    return 'aggregate-search';
  }
  if (hasGmailData(surface)) {
    return 'gmail';
  }
  if (hasComponent(surface, A2UI_COMPONENT_TRAVEL_OPTIONS) ||
    hasComponent(surface, A2UI_COMPONENT_TRAIN_OPTIONS) ||
    hasComponent(surface, A2UI_COMPONENT_FLIGHT_BOARD) ||
    surface.intent === 'travel') {
    return 'travel';
  }
  if (hasComponent(surface, A2UI_COMPONENT_FOOD_CHOICES) || surface.intent === 'food') {
    return 'food';
  }
  if (surface.intent === 'media' || hasMediaVideoData(surface)) {
    return 'media';
  }
  if (surface.intent === 'payment' || surface.intent === 'payment.account.setup' || hasPaymentData(surface)) {
    return 'payment';
  }
  if (surface.intent === 'luckin') {
    return 'luckin';
  }
  if (surface.intent === 'hotel') {
    return 'hotel';
  }
  if (hasComponent(surface, A2UI_COMPONENT_TOOL_CONNECT_CARD) ||
    hasComponent(surface, A2UI_COMPONENT_GENERIC_TOOL_RESULTS) ||
    surface.intent === 'dynamic_tool' ||
    hasDynamicData(surface)) {
    return 'dynamic-tools';
  }
  if (hasComponent(surface, A2UI_COMPONENT_THINKING_STREAM) ||
    hasComponent(surface, A2UI_COMPONENT_THINKING_CARD) ||
    surface.status === 'thinking') {
    return 'thinking';
  }
  return 'generic';
}

function sourceOf(kind: HtmlHomeKind, surface: A2uiSurfaceState, isBusy: boolean): HtmlHomeSource {
  if (kind === 'thinking' || isBusy && surface.status !== 'ready') {
    return 'pending';
  }
  if (kind === 'travel' || kind === 'hotel' || kind === 'food' || kind === 'social' || kind === 'dynamic-tools' || kind === 'gmail' || kind === 'media' || kind === 'payment' || kind === 'aggregate-search' || kind === 'luckin' || kind === 'multi-task') {
    return 'tool';
  }
  return 'model';
}

function hasComponent(surface: A2uiSurfaceState, componentName: string): boolean {
  for (let index = 0; index < surface.components.length; index++) {
    if (surface.components[index].component === componentName) {
      return true;
    }
  }
  return false;
}

function firstComponentByName(surface: A2uiSurfaceState, componentName: string): A2uiComponent | null {
  for (let index = 0; index < surface.components.length; index++) {
    if (surface.components[index].component === componentName) {
      return surface.components[index];
    }
  }
  return null;
}

function aggregateSearchFallbackComponent(surface: A2uiSurfaceState): A2uiComponent {
  return {
    id: firstText(surface.rootId, 'aggregate_search'),
    component: A2UI_COMPONENT_AGGREGATE_SEARCH,
    title: firstText(surface.title, '聚合搜索'),
    status: surface.status,
    dataPath: '/aggregateSearch'
  };
}

function hasDynamicData(surface: A2uiSurfaceState): boolean {
  const connect = dynamicToolConnect(surface);
  return hasConnectData(connect) || genericToolResults(surface).length > 0;
}

function aggregateSearchData(surface: A2uiSurfaceState): AggregateSearchResult {
  const result = resolveData(surface, '/aggregateSearch') as AggregateSearchResult;
  if (result === undefined || result === null) {
    return {
      query: '',
      videos: [],
      posts: [],
      sourceStatuses: [],
      summary: ''
    };
  }
  return result;
}

function hasAggregateSearchSurface(surface: A2uiSurfaceState): boolean {
  if (surface.intent === 'aggregate_search' || hasComponent(surface, A2UI_COMPONENT_AGGREGATE_SEARCH)) {
    return true;
  }
  return hasAggregateData(aggregateSearchData(surface));
}

function hasAggregateData(result: AggregateSearchResult): boolean {
  return result.query.length > 0 || result.summary.length > 0 || result.videos.length > 0 ||
    result.posts.length > 0 || result.sourceStatuses.length > 0;
}

function hasMediaVideoData(surface: A2uiSurfaceState): boolean {
  const results = genericToolResults(surface);
  for (let index = 0; index < results.length; index++) {
    if (isMediaVideoResult(results[index])) {
      return true;
    }
  }
  return false;
}

function hasPaymentData(surface: A2uiSurfaceState): boolean {
  if (hasComponent(surface, A2UI_COMPONENT_STRIPE_RECEIVING_ACCOUNT_CARD)) {
    return true;
  }
  const results = genericToolResults(surface);
  for (let index = 0; index < results.length; index++) {
    if (results[index].toolName === 'payment.send') {
      return true;
    }
  }
  return false;
}

function hasConnectData(data: A2uiDynamicToolConnectData): boolean {
  return data.toolId.length > 0 || data.displayName.length > 0 || data.sourceUrl.length > 0 ||
    data.status.length > 0 || data.message.length > 0 || data.credentialName.length > 0 ||
    data.credentialRef.length > 0 || data.actions.length > 0;
}

function hasGmailData(surface: A2uiSurfaceState): boolean {
  const connect = dynamicToolConnect(surface);
  if (connect.toolId.indexOf('gmail.') >= 0 || connect.toolId.indexOf('mail.') >= 0 ||
    connect.displayName.indexOf('Gmail') >= 0 || connect.displayName.indexOf('Mail') >= 0 ||
    connect.displayName.indexOf('邮箱') >= 0) {
    return true;
  }
  const results = genericToolResults(surface);
  for (let index = 0; index < results.length; index++) {
    if (results[index].sourceTag === 'Gmail API' ||
      results[index].sourceTag === 'Gmail' ||
      results[index].sourceTag === 'QQ Mail' ||
      results[index].sourceTag.indexOf('Mail') >= 0 ||
      results[index].sourceTag.indexOf('邮箱') >= 0 ||
      results[index].toolName.indexOf('gmail.') >= 0 ||
      results[index].toolName.indexOf('mail.') >= 0 ||
      results[index].toolName.indexOf('users.') === 0) {
      return true;
    }
  }
  return false;
}

function appendComponentActions(actions: HtmlHomeAction[], component: A2uiComponent): void {
  htmlActions(actionsOf(component), component.id).forEach((action: HtmlHomeAction) => {
    appendAction(actions, action);
  });
}

function htmlActions(actions: A2uiAction[], sourceComponentId: string): HtmlHomeAction[] {
  const mapped: HtmlHomeAction[] = [];
  if (actions === undefined || actions === null || !Array.isArray(actions)) {
    return mapped;
  }
  actions.forEach((action: A2uiAction) => {
    if (action === undefined || action === null) {
      return;
    }
    const actionId = textOf(action.id);
    const actionLabel = textOf(action.label);
    const prompt = textOf(action.prompt);
    if (actionId.length === 0 && actionLabel.length === 0 && prompt.length === 0) {
      return;
    }
    const id = firstText(actionId, sourceComponentId);
    const label = firstText(actionLabel, id);
    mapped.push({
      id: id,
      label: label,
      prompt: prompt,
      variant: textOf(action.variant),
      kind: textOf(action.kind),
      sourceComponentId: sourceComponentId,
      args: action.args
    });
  });
  return mapped;
}

function clientAction(id: string, label: string, prompt: string, sourceComponentId: string): HtmlHomeAction {
  return {
    id: id,
    label: label,
    prompt: prompt,
    variant: 'secondary',
    kind: 'client',
    sourceComponentId: sourceComponentId
  };
}

function appendAction(actions: HtmlHomeAction[], action: HtmlHomeAction): void {
  for (let index = 0; index < actions.length; index++) {
    if (actions[index].id === action.id && actions[index].prompt === action.prompt) {
      return;
    }
  }
  actions.push(action);
}

function withBusy(document: HtmlHomeDocument, isBusy: boolean): HtmlHomeDocument {
  (document as HtmlHomeDocumentWithBusy).isBusy = isBusy;
  return document;
}

function sourceTagsText(sourceTags: string[] | null | undefined): string {
  if (sourceTags === undefined || sourceTags === null || !Array.isArray(sourceTags)) {
    return '';
  }
  return sourceTags.join(' / ');
}

function newBlock(id: string, kind: string, title: string): HtmlHomeBlock {
  return {
    id: textOf(id),
    kind: textOf(kind),
    title: textOf(title),
    metrics: [],
    rows: [],
    actions: []
  };
}

function appendMetric(metrics: HtmlHomeMetric[], label: HtmlHomeTextValue, value: HtmlHomeTextValue): void {
  const labelText = textOf(label);
  const valueText = textOf(value);
  if (labelText.length === 0 || valueText.length === 0) {
    return;
  }
  metrics.push({
    label: labelText,
    value: valueText
  });
}

function appendTimeline(timeline: HtmlHomeTimelineItem[], title: HtmlHomeTextValue, subtitle: HtmlHomeTextValue, status: HtmlHomeTextValue): void {
  const titleText = textOf(title);
  const subtitleText = textOf(subtitle);
  const statusText = textOf(status);
  if (titleText.length === 0 && subtitleText.length === 0 && statusText.length === 0) {
    return;
  }
  timeline.push({
    title: titleText,
    subtitle: subtitleText,
    status: statusText
  });
}

function recentHistory(messages: A2uiMessage[]): HtmlHomeHistoryItem[] {
  const start = messages.length > HISTORY_LIMIT ? messages.length - HISTORY_LIMIT : 0;
  const history: HtmlHomeHistoryItem[] = [];
  for (let index = start; index < messages.length; index++) {
    const content = visibleHistoryContent(messages[index]);
    if (content.length === 0) {
      continue;
    }
    history.push({
      id: messages[index].id,
      role: messages[index].role,
      content: content
    });
  }
  return history;
}

function visibleHistoryContent(message: A2uiMessage): string {
  const content = message.content.trim();
  if (message.role === 'assistant' &&
    (content.indexOf('<think>') >= 0 ||
      content.indexOf('"createSurface"') >= 0 ||
      content.indexOf('"updateComponents"') >= 0 ||
      content.indexOf('"updateDataModel"') >= 0)) {
    return '';
  }
  return content;
}

function lastUserMessage(messages: A2uiMessage[]): string {
  for (let index = messages.length - 1; index >= 0; index--) {
    if (messages[index].role === 'user' && messages[index].content.length > 0) {
      return messages[index].content;
    }
  }
  return '';
}

function textOf(value: HtmlHomeTextValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function firstText(first: HtmlHomeTextValue, second: HtmlHomeTextValue = '', third: HtmlHomeTextValue = ''): string {
  const firstValue = textOf(first);
  if (firstValue.length > 0) {
    return firstValue;
  }
  const secondValue = textOf(second);
  if (secondValue.length > 0) {
    return secondValue;
  }
  return textOf(third);
}

function joinText(values: HtmlHomeTextValue[], separator: string): string {
  const kept: string[] = [];
  values.forEach((value: HtmlHomeTextValue) => {
    const text = textOf(value);
    if (text.length > 0) {
      kept.push(text);
    }
  });
  return kept.join(separator);
}

function firstDateText(...values: HtmlHomeTextValue[]): string {
  const match = /(\d{4}-\d{1,2}-\d{1,2})/.exec(joinText(values, ' '));
  return match === null ? '' : match[1];
}

function summaryText(surface: A2uiSurfaceState): string {
  const summary = resolveData(surface, '/summary') as A2uiSummaryData;
  return summary === undefined || summary === null ? '' : textOf(summary.text);
}

function aggregateVideoResult(item: AggregateSearchVideo): A2uiGenericToolResultData {
  const rows: A2uiLabelValueData[] = [{
    label: 'Video URL',
    value: item.url
  }, {
    label: 'Thumbnail',
    value: item.thumbnail
  }];
  item.rows.forEach((row: A2uiLabelValueData) => rows.push(row));
  return {
    toolName: 'media.video.search',
    title: item.title,
    summary: item.summary,
    status: item.status,
    sourceTag: item.provider,
    rows: rows,
    rawPreview: ''
  };
}
