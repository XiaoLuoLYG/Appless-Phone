import {
  A2UI_COMPONENT_AGGREGATE_SEARCH,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_VERSION,
  A2uiComponent,
  A2uiDataValue,
  A2uiEnvelope
} from './A2uiTypes';
import {
  A2uiPartialDataPatch,
  A2uiPartialRenderState,
  planA2uiPartialUpdate
} from './A2uiPartialUpdatePlanner';
import { AggregateSearchResult } from './AggregateSearchTypes';

function jsonLine(envelope: A2uiEnvelope): string {
  const versioned: A2uiEnvelope = {
    version: A2UI_VERSION
  };
  if (envelope.createSurface !== undefined && envelope.createSurface !== null) {
    versioned.createSurface = envelope.createSurface;
  }
  if (envelope.updateComponents !== undefined && envelope.updateComponents !== null) {
    versioned.updateComponents = envelope.updateComponents;
  }
  if (envelope.updateDataModel !== undefined && envelope.updateDataModel !== null) {
    versioned.updateDataModel = envelope.updateDataModel;
  }
  return JSON.stringify(versioned);
}

function aggregateSearchComponents(result: AggregateSearchResult, status: string): A2uiComponent[] {
  const components: A2uiComponent[] = [
    {
      id: 'root',
      component: A2UI_COMPONENT_SURFACE_ROOT,
      child: 'aggregate_search',
      title: '聚合搜索',
      status: status
    },
    {
      id: 'aggregate_search',
      component: A2UI_COMPONENT_AGGREGATE_SEARCH,
      title: '聚合搜索',
      body: result.summary,
      status: status,
      dataPath: '/aggregateSearch',
      actions: []
    }
  ];
  return components;
}

export function aggregateSearchA2uiRenderState(
  surfaceId: string,
  result: AggregateSearchResult,
  status: string = 'ready'
): A2uiPartialRenderState {
  const dataPatches: A2uiPartialDataPatch[] = [{
    path: '/aggregateSearch',
    value: result,
    signature: JSON.stringify(result)
  }];
  return {
    surfaceId: surfaceId,
    root: 'root',
    title: '聚合搜索',
    intent: 'aggregate_search',
    status: status,
    sendDataModel: true,
    components: aggregateSearchComponents(result, status),
    componentsSignature: 'aggregate-search-v1|status=' + status,
    dataPatches: dataPatches
  };
}

export function aggregateSearchA2ui(surfaceId: string, result: AggregateSearchResult): string {
  return planA2uiPartialUpdate(null, aggregateSearchA2uiRenderState(surfaceId, result, 'ready')).jsonl;
}
