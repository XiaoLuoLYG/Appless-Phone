import {
  A2UI_COMPONENT_AGGREGATE_SEARCH,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_VERSION,
  A2uiComponent,
  A2uiDataValue,
  A2uiEnvelope
} from './A2uiTypes';
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

function dataLine(surfaceId: string, path: string, value: A2uiDataValue): string {
  return jsonLine({
    updateDataModel: {
      surfaceId: surfaceId,
      path: path,
      value: value
    }
  });
}

export function aggregateSearchA2ui(surfaceId: string, result: AggregateSearchResult): string {
  const components: A2uiComponent[] = [
    {
      id: 'root',
      component: A2UI_COMPONENT_SURFACE_ROOT,
      child: 'aggregate_search',
      title: '聚合搜索',
      status: 'ready'
    },
    {
      id: 'aggregate_search',
      component: A2UI_COMPONENT_AGGREGATE_SEARCH,
      title: '聚合搜索',
      body: result.summary,
      status: 'ready',
      dataPath: '/aggregateSearch',
      actions: []
    }
  ];
  return [
    jsonLine({
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: '聚合搜索',
        intent: 'aggregate_search',
        status: 'ready',
        sendDataModel: true
      }
    }),
    jsonLine({
      updateComponents: {
        surfaceId: surfaceId,
        components: components
      }
    }),
    dataLine(surfaceId, '/aggregateSearch', result)
  ].join('\n') + '\n';
}
