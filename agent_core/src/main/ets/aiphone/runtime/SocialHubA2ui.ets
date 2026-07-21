import {
  A2UI_COMPONENT_SOCIAL_HUB,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_VERSION,
  A2uiComponent,
  A2uiDataValue,
  A2uiEnvelope
} from './A2uiTypes';
import {
  emptySocialHubDraft,
  emptySocialHubItem,
  SocialHubConnectionData,
  SocialHubDraftData,
  SocialHubItemData
} from './SocialHubTypes';
import { socialHubPrivateItems } from './SocialHubClient';

export interface SocialHubStructuredData {
  items: SocialHubItemData[];
  connections: SocialHubConnectionData[];
}

function jsonLine(envelope: A2uiEnvelope): string {
  return JSON.stringify(envelope);
}

function surfaceLines(surfaceId: string): string[] {
  const components: A2uiComponent[] = [
    {
      id: 'root',
      component: A2UI_COMPONENT_SURFACE_ROOT,
      child: 'social_hub',
      title: 'SocialHub',
      status: 'ready'
    },
    {
      id: 'social_hub',
      component: A2UI_COMPONENT_SOCIAL_HUB,
      title: '社交工作台',
      dataPath: '/socialHub/items',
      status: 'ready'
    }
  ];
  return [
    jsonLine({
      version: A2UI_VERSION,
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: 'SocialHub',
        intent: 'social',
        status: 'ready',
        sendDataModel: true
      }
    }),
    jsonLine({
      version: A2UI_VERSION,
      updateComponents: {
        surfaceId: surfaceId,
        components: components
      }
    })
  ];
}

function dataLine(surfaceId: string, path: string, value: A2uiDataValue): string {
  return jsonLine({
    version: A2UI_VERSION,
    updateDataModel: {
      surfaceId: surfaceId,
      path: path,
      value: value
    }
  });
}

export function socialHubFeedA2ui(surfaceId: string, items: SocialHubItemData[], connections: SocialHubConnectionData[]): string {
  const privateItems = socialHubPrivateItems(items);
  const selected = privateItems.length > 0 ? privateItems[0] : emptySocialHubItem();
  return surfaceLines(surfaceId).concat([
    dataLine(surfaceId, '/socialHub/items', privateItems),
    dataLine(surfaceId, '/socialHub/selected', selected),
    dataLine(surfaceId, '/socialHub/draft', emptySocialHubDraft()),
    dataLine(surfaceId, '/socialHub/connections', connections)
  ]).join('\n') + '\n';
}

export function socialHubStructuredDataA2ui(surfaceId: string, data: SocialHubStructuredData): string {
  return socialHubFeedA2ui(surfaceId, data.items, data.connections);
}

export function socialHubDraftA2ui(surfaceId: string, draft: SocialHubDraftData): string {
  const items: SocialHubItemData[] = [];
  const connections: SocialHubConnectionData[] = [];
  return surfaceLines(surfaceId).concat([
    dataLine(surfaceId, '/socialHub/items', items),
    dataLine(surfaceId, '/socialHub/selected', emptySocialHubItem()),
    dataLine(surfaceId, '/socialHub/draft', draft),
    dataLine(surfaceId, '/socialHub/connections', connections)
  ]).join('\n') + '\n';
}
