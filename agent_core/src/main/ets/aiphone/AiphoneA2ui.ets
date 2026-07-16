import { A2UI_VERSION } from '../a2ui/A2uiProtocol';

interface AiphoneCreateSurfaceBody {
  surfaceId: string;
  root?: string;
  status: string;
  title: string;
  intent?: string;
  sendDataModel?: boolean;
}

interface AiphoneCreateSurfaceEnvelope {
  version: string;
  createSurface: AiphoneCreateSurfaceBody;
}

interface AiphoneRow {
  label: string;
  value: string;
}

interface AiphoneUpdateDataModelBody {
  surfaceId: string;
  path: string;
  value: AiphoneRow[];
}

interface AiphoneUpdateDataModelEnvelope {
  version: string;
  updateDataModel: AiphoneUpdateDataModelBody;
}

interface AiphoneComponent {
  id: string;
  component: string;
  child?: string;
  title?: string;
  status?: string;
  dataPath?: string;
  actions?: Object[];
}

interface AiphoneUpdateComponentsBody {
  surfaceId: string;
  components: AiphoneComponent[];
}

interface AiphoneUpdateComponentsEnvelope {
  version: string;
  updateComponents: AiphoneUpdateComponentsBody;
}

export function aiphoneErrorJsonl(surfaceId: string, title: string, body: string): string {
  const create: AiphoneCreateSurfaceEnvelope = {
    version: A2UI_VERSION,
    createSurface: {
      surfaceId: surfaceId,
      status: 'error',
      title: title
    }
  };
  const rows: AiphoneUpdateDataModelEnvelope = {
    version: A2UI_VERSION,
    updateDataModel: {
      surfaceId: surfaceId,
      path: '/rows',
      value: [
        { label: '错误', value: body }
      ]
    }
  };
  return JSON.stringify(create) + '\n' + JSON.stringify(rows) + '\n';
}

export function aiphoneInfoJsonl(surfaceId: string, title: string, body: string): string {
  const create: AiphoneCreateSurfaceEnvelope = {
    version: A2UI_VERSION,
    createSurface: {
      surfaceId: surfaceId,
      root: 'root',
      status: 'ready',
      title: title,
      intent: 'general',
      sendDataModel: true
    }
  };
  const components: AiphoneUpdateComponentsEnvelope = {
    version: A2UI_VERSION,
    updateComponents: {
      surfaceId: surfaceId,
      components: [
        {
          id: 'root',
          component: 'SurfaceRoot',
          child: 'rows',
          title: title,
          status: 'ready'
        },
        {
          id: 'rows',
          component: 'InfoRows',
          title: title,
          status: 'ready',
          dataPath: '/rows',
          actions: []
        }
      ]
    }
  };
  const rows: AiphoneUpdateDataModelEnvelope = {
    version: A2UI_VERSION,
    updateDataModel: {
      surfaceId: surfaceId,
      path: '/rows',
      value: [
        { label: '回答', value: body }
      ]
    }
  };
  return JSON.stringify(create) + '\n' + JSON.stringify(components) + '\n' + JSON.stringify(rows) + '\n';
}

export function aiphonePendingJsonl(surfaceId: string, title: string, intent: string): string {
  const create: AiphoneCreateSurfaceEnvelope = {
    version: A2UI_VERSION,
    createSurface: {
      surfaceId: surfaceId,
      root: 'root',
      status: 'calling_tool',
      title: title,
      intent: intent,
      sendDataModel: true
    }
  };
  const components: AiphoneUpdateComponentsEnvelope = {
    version: A2UI_VERSION,
    updateComponents: {
      surfaceId: surfaceId,
      components: [
        {
          id: 'root',
          component: 'SurfaceRoot',
          child: 'rows',
          title: title,
          status: 'calling_tool'
        },
        {
          id: 'rows',
          component: 'InfoRows',
          title: title,
          status: 'calling_tool',
          dataPath: '/rows',
          actions: []
        }
      ]
    }
  };
  const rows: AiphoneUpdateDataModelEnvelope = {
    version: A2UI_VERSION,
    updateDataModel: {
      surfaceId: surfaceId,
      path: '/rows',
      value: [
        { label: '状态', value: '正在调用 ' + title }
      ]
    }
  };
  return JSON.stringify(create) + '\n' + JSON.stringify(components) + '\n' + JSON.stringify(rows) + '\n';
}

export function splitJsonl(jsonl: string): string[] {
  return jsonl.split(/\r?\n/).map((line: string) => line.trim()).filter((line: string) => line.length > 0);
}
