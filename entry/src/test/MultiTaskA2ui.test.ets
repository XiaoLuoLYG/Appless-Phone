import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiAction,
  A2uiMultiTaskSectionValue,
  A2uiSurfaceState,
  A2uiSurfaceStore,
  MultiTaskBoardData
} from '@loop/agent-core';
import {
  childSurfaceIdForMultiTaskSlot,
  mergeSlotObservationIntoMultiTaskSurface,
  MultiToolSurfaceComposer,
  resolveMultiTaskSlotId
} from '@loop/agent-core';
import { createHtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeSnapshot';
import { multiTaskHomePayloadJson, renderMultiTaskHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlMultiTaskHomeRenderer';

interface LuckinShopArgsFixture {
  deptId: string;
  deptName: string;
  address: string;
  distance: string;
  status: string;
}

function sectionValues(values: A2uiMultiTaskSectionValue[]): Record<string, A2uiMultiTaskSectionValue> {
  const sections: Record<string, A2uiMultiTaskSectionValue> = {};
  for (let index = 0; index < values.length; index++) {
    sections[values[index].slotId] = values[index];
  }
  return sections;
}

function luckinShopEmbeddedSurface(): A2uiSurfaceState {
  const store = new A2uiSurfaceStore();
  const shopArgs: LuckinShopArgsFixture = {
    deptId: '1001',
    deptName: '瑞幸咖啡 深圳科技园店',
    address: '深圳市南山区科技园',
    distance: '120m',
    status: '营业中'
  };
  const shopAction: A2uiAction = {
    id: 'luckin.order.preview',
    label: '科技园店',
    prompt: '生椰拿铁',
    variant: 'primary',
    kind: 'prompt',
    args: shopArgs
  };
  store.apply({
    version: 'v0.9.1',
    createSurface: {
      surfaceId: 'surface_luckin_slot',
      root: 'root',
      title: '选择瑞幸门店',
      intent: 'luckin',
      status: 'ready',
      sendDataModel: true
    }
  });
  store.apply({
    version: 'v0.9.1',
    updateComponents: {
      surfaceId: 'surface_luckin_slot',
      components: [
        {
          id: 'root',
          component: 'SurfaceRoot',
          child: 'results',
          title: '选择瑞幸门店',
          status: 'ready'
        },
        {
          id: 'results',
          component: 'GenericToolResults',
          title: '选择瑞幸门店',
          body: '',
          status: 'ready',
          dataPath: '/genericToolResults',
          actions: [shopAction]
        }
      ]
    }
  });
  store.apply({
    version: 'v0.9.1',
    updateDataModel: {
      surfaceId: 'surface_luckin_slot',
      path: '/genericToolResults',
      value: [{
        sourceTag: '瑞幸',
        toolName: 'luckin.order.preview',
        title: '选择瑞幸门店',
        status: 'success',
        summary: '请选择要在哪家门店自取，选定后会继续查询商品并核价。',
        rows: [],
        rawPreview: ''
      }]
    }
  });
  return store.getSurface();
}

export default function multiTaskA2uiTest() {
  describe('MultiTaskA2uiTest', () => {
  it('persists_multiTask_and_sections_in_surface_store', 0, () => {
    const store = new A2uiSurfaceStore();
    store.apply({
      version: 'v0.9.1',
      createSurface: {
        surfaceId: 'surface_model',
        root: 'root',
        title: '并行任务',
        intent: 'multi-task',
        status: 'ready',
        sendDataModel: true
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateComponents: {
        surfaceId: 'surface_model',
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'board',
            title: '并行任务',
            body: '',
            status: 'ready'
          },
          {
            id: 'board',
            component: 'MultiTaskBoard',
            title: '并行任务',
            body: '',
            status: 'ready',
            dataPath: '/multiTask'
          }
        ]
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_model',
        path: '/multiTask',
        value: {
          batchId: 'batch_test',
          activeSectionId: 'slot_0',
          sections: [{
            slotId: 'slot_0',
            toolId: 'flight.search',
            title: '机票',
            status: 'ready',
            summary: '请补充出发时间'
          }]
        } as MultiTaskBoardData
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_model',
        path: '/sections',
        value: sectionValues([
          {
            slotId: 'slot_0',
            toolId: 'flight.search',
            title: '机票',
            status: 'ready',
            summary: '请补充出发时间',
            observationDigest: 'ObservationDigest\nsurface status: needs_input',
            failureKey: '',
            embeddedSurface: null
          }
        ])
      }
    });
    const parsed = JSON.parse(store.getSurface().dataModelJson) as Record<string, Object>;
    expect(parsed.multiTask !== undefined && parsed.multiTask !== null).assertTrue();
    expect(parsed.sections !== undefined && parsed.sections !== null).assertTrue();
  });

  it('builds_multi_task_html_blocks', 0, () => {
    const store = new A2uiSurfaceStore();
    store.apply({
      version: 'v0.9.1',
      createSurface: {
        surfaceId: 'surface_model',
        root: 'root',
        title: '并行任务',
        intent: 'multi-task',
        status: 'ready',
        sendDataModel: true
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateComponents: {
        surfaceId: 'surface_model',
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'board',
            title: '并行任务',
            body: '',
            status: 'ready'
          },
          {
            id: 'board',
            component: 'MultiTaskBoard',
            title: '并行任务',
            body: '',
            status: 'ready',
            dataPath: '/multiTask'
          }
        ]
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_model',
        path: '/multiTask',
        value: {
          batchId: 'batch_test',
          activeSectionId: 'slot_0',
          sections: [{
            slotId: 'slot_0',
            toolId: 'flight.search',
            title: '机票',
            status: 'ready',
            summary: '请补充出发时间'
          }, {
            slotId: 'slot_1',
            toolId: 'food.search',
            title: '美食',
            status: 'ready',
            summary: '附近餐厅'
          }]
        } as MultiTaskBoardData
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_model',
        path: '/summary',
        value: {
          text: '并行任务进度 2/2',
          toolName: 'multi.task.batch',
          dataLabel: 'multiTask',
          count: 2
        }
      }
    });
    const document = createHtmlHomeDocument({
      surface: store.getSurface(),
      messages: [],
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    expect(document.kind).assertEqual('multi-task');
    expect(document.blocks.length).assertEqual(2);
  });

  it('embeds_tool_ui_in_multi_task_section', 0, () => {
    const store = new A2uiSurfaceStore();
    store.apply({
      version: 'v0.9.1',
      createSurface: {
        surfaceId: 'surface_model',
        root: 'root',
        title: '并行任务',
        intent: 'multi-task',
        status: 'ready',
        sendDataModel: true
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateComponents: {
        surfaceId: 'surface_model',
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'board',
            title: '并行任务',
            body: '',
            status: 'ready'
          },
          {
            id: 'board',
            component: 'MultiTaskBoard',
            title: '并行任务',
            body: '',
            status: 'ready',
            dataPath: '/multiTask'
          }
        ]
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_model',
        path: '/multiTask',
        value: {
          batchId: 'batch_test',
          activeSectionId: 'slot_0',
          sections: [{
            slotId: 'slot_0',
            toolId: 'luckin.order.preview',
            title: '瑞幸点单',
            status: 'ready',
            summary: '请选择门店'
          }]
        } as MultiTaskBoardData
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_model',
        path: '/sections',
        value: sectionValues([
          {
            slotId: 'slot_0',
            toolId: 'luckin.order.preview',
            title: '瑞幸点单',
            status: 'ready',
            summary: '请选择门店',
            observationDigest: 'ObservationDigest\ntoolId: luckin.order.preview',
            failureKey: '',
            embeddedSurface: luckinShopEmbeddedSurface()
          }
        ])
      }
    });
    const document = createHtmlHomeDocument({
      surface: store.getSurface(),
      messages: [],
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    expect(document.blocks.length).assertEqual(1);
    expect(document.blocks[0].embeddedDocument !== undefined).assertTrue();
    expect(document.blocks[0].embeddedDocument!.kind).assertEqual('luckin');
    expect(document.blocks[0].embeddedDocument!.blocks.length).assertLarger(0);
    const html = renderMultiTaskHomeDocument(document, false);
    expect(html.indexOf('multi-embed-frame')).assertLarger(-1);
    expect(html.indexOf('multi-task-data')).assertLarger(-1);
    expect(html.indexOf('__aiphoneApplyMultiTaskUpdate')).assertLarger(-1);
    expect(html.indexOf('__aiphonePatchEmbeddedLuckinPaymentStatus')).assertLarger(-1);
    expect(html.indexOf('min-height: 420px')).assertEqual(-1);
    expect(html.indexOf('min-height: 360px')).assertEqual(-1);
    expect(html.indexOf('luckin-shop-picker')).assertLarger(-1);
    expect(html.indexOf('深圳科技园店')).assertLarger(-1);
  });

  it('escapes_embedded_html_in_multi_task_payload', 0, () => {
    const store = new A2uiSurfaceStore();
    store.apply({
      version: 'v0.9.1',
      createSurface: {
        surfaceId: 'surface_model',
        root: 'root',
        title: '并行任务',
        intent: 'multi-task',
        status: 'ready',
        sendDataModel: true
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateComponents: {
        surfaceId: 'surface_model',
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'board',
            title: '并行任务',
            body: '',
            status: 'ready'
          },
          {
            id: 'board',
            component: 'MultiTaskBoard',
            title: '并行任务',
            body: '',
            status: 'ready',
            dataPath: '/multiTask'
          }
        ]
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_model',
        path: '/multiTask',
        value: {
          batchId: 'batch_test',
          activeSectionId: 'slot_0',
          sections: [{
            slotId: 'slot_0',
            toolId: 'luckin.order.preview',
            title: '瑞幸点单',
            status: 'ready',
            summary: '请选择门店'
          }, {
            slotId: 'slot_1',
            toolId: 'flight.search',
            title: '机票',
            status: 'ready',
            summary: '请补充出发时间'
          }]
        } as MultiTaskBoardData
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_model',
        path: '/sections',
        value: sectionValues([
          {
            slotId: 'slot_0',
            toolId: 'luckin.order.preview',
            title: '瑞幸点单',
            status: 'ready',
            summary: '请选择门店',
            observationDigest: 'ObservationDigest\ntoolId: luckin.order.preview',
            failureKey: '',
            embeddedSurface: luckinShopEmbeddedSurface()
          }, {
            slotId: 'slot_1',
            toolId: 'flight.search',
            title: '机票',
            status: 'ready',
            summary: '请补充出发时间',
            observationDigest: 'ObservationDigest\ntoolId: flight.search',
            failureKey: '',
            embeddedSurface: null
          }
        ])
      }
    });
    const document = createHtmlHomeDocument({
      surface: store.getSurface(),
      messages: [],
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    const html = renderMultiTaskHomeDocument(document, false);
    expect(html.indexOf('id="multi-task-data" type="application/json"')).assertLarger(-1);
    expect(html.indexOf('\\u003cscript')).assertLarger(-1);
    expect(html.indexOf('multi-shell')).assertLarger(-1);
    expect(html.indexOf('multi-tabs-track')).assertLarger(-1);
  });

  it('merges_follow_up_tool_result_into_multi_task_slot', 0, () => {
    const store = new A2uiSurfaceStore();
    store.apply({
      version: 'v0.9.1',
      createSurface: {
        surfaceId: 'surface_model',
        root: 'root',
        title: '并行任务',
        intent: 'multi-task',
        status: 'ready',
        sendDataModel: true
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateComponents: {
        surfaceId: 'surface_model',
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'board',
            title: '并行任务',
            body: '',
            status: 'ready'
          },
          {
            id: 'board',
            component: 'MultiTaskBoard',
            title: '并行任务',
            body: '',
            status: 'ready',
            dataPath: '/multiTask'
          }
        ]
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_model',
        path: '/multiTask',
        value: {
          batchId: 'batch_test',
          activeSectionId: 'slot_0',
          sections: [{
            slotId: 'slot_0',
            toolId: 'luckin.order.preview',
            title: '瑞幸点单',
            status: 'ready',
            summary: '请选择门店'
          }, {
            slotId: 'slot_1',
            toolId: 'flight.search',
            title: '机票',
            status: 'ready',
            summary: '请补充出发时间'
          }]
        } as MultiTaskBoardData
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_model',
        path: '/sections',
        value: sectionValues([
          {
            slotId: 'slot_0',
            toolId: 'luckin.order.preview',
            title: '瑞幸点单',
            status: 'ready',
            summary: '请选择门店',
            observationDigest: 'ObservationDigest\ntoolId: luckin.order.preview',
            failureKey: '',
            embeddedSurface: luckinShopEmbeddedSurface()
          }, {
            slotId: 'slot_1',
            toolId: 'flight.search',
            title: '机票',
            status: 'ready',
            summary: '请补充出发时间',
            observationDigest: 'ObservationDigest\ntoolId: flight.search',
            failureKey: '',
            embeddedSurface: null
          }
        ])
      }
    });
    const composite = store.getSurface();
    expect(resolveMultiTaskSlotId(composite, 'luckin.order.preview')).assertEqual('slot_0');
    expect(childSurfaceIdForMultiTaskSlot('surface_model', 'slot_0')).assertEqual('surface_model_slot_0');
    const followUpRaw = luckinShopEmbeddedSurface();
    const merged = mergeSlotObservationIntoMultiTaskSurface(
      composite,
      'slot_0',
      'luckin.order.preview',
      JSON.stringify(followUpRaw)
    );
    expect(merged.intent).assertEqual('multi-task');
    const parsedMerged = JSON.parse(merged.dataModelJson) as Record<string, Object>;
    const board = parsedMerged.multiTask as Record<string, string | Object>;
    expect(board.activeSectionId as string).assertEqual('slot_0');
    expect(merged.components.length).assertEqual(composite.components.length);
    const parsed = JSON.parse(merged.dataModelJson) as Record<string, Object>;
    const sections = parsed.sections as Record<string, Record<string, string>>;
    expect(sections.slot_1.summary).assertEqual('请补充出发时间');
    const document = createHtmlHomeDocument({
      surface: merged,
      messages: [],
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    expect(document.kind).assertEqual('multi-task');
    expect(document.blocks.length).assertEqual(2);
  });

  it('activates_and_orders_sections_by_completion_time', 0, () => {
    let latestSurface: A2uiSurfaceState | null = null;
    const composer = new MultiToolSurfaceComposer('surface_batch', (surface) => {
      latestSurface = surface;
    });
    composer.registerSlots([
      { name: 'ride.estimate', input: '{}' },
      { name: 'luckin.order.preview', input: '{}' },
      { name: 'payment.send', input: '{}' }
    ]);
    composer.emitShell();
    composer.markSlotError('slot_1', '瑞幸先返回');
    composer.markSlotError('slot_2', '转账后返回');

    expect(latestSurface !== null).assertTrue();
    const parsedAfterSecond = JSON.parse(latestSurface!.dataModelJson) as Record<string, Object>;
    const boardAfterSecond = parsedAfterSecond.multiTask as Record<string, Object | string>;
    expect(boardAfterSecond.activeSectionId as string).assertEqual('slot_1');
    const sectionsAfterSecond = boardAfterSecond.sections as Array<Record<string, string>>;
    expect(sectionsAfterSecond.length).assertEqual(3);
    expect(sectionsAfterSecond[0].slotId).assertEqual('slot_1');
    expect(sectionsAfterSecond[1].slotId).assertEqual('slot_2');
    expect(sectionsAfterSecond[2].slotId).assertEqual('slot_0');

    const document = createHtmlHomeDocument({
      surface: latestSurface!,
      messages: [],
      isBusy: true,
      isAwaitingFirstSurface: false
    });
    expect(document.activeSectionId).assertEqual('slot_1');
    expect(document.blocks[0].sectionId).assertEqual('slot_1');
    expect(document.blocks[1].sectionId).assertEqual('slot_2');
    expect(document.blocks[2].sectionId).assertEqual('slot_0');
  });

  it('preserves slot errors and settles the composite surface', 0, () => {
    let latestSurface: A2uiSurfaceState | null = null;
    const composer = new MultiToolSurfaceComposer('surface_batch', (surface) => {
      latestSurface = surface;
    });
    composer.registerSlots([{ name: 'flight.search', input: '{}' }]);
    composer.emitShell();
    composer.ingestSlotObservation('slot_0', 'not-a2ui-json');

    expect(latestSurface !== null).assertTrue();
    const parsed = JSON.parse(latestSurface!.dataModelJson) as Record<string, Object>;
    const sections = parsed.sections as Record<string, Record<string, string>>;
    expect(sections.slot_0.status).assertEqual('error');
    expect(latestSurface!.status).assertEqual('ready');
  });

  it('builds_multi_task_inline_patch_payload_json', 0, () => {
    let latestSurface: A2uiSurfaceState | null = null;
    const composer = new MultiToolSurfaceComposer('surface_batch', (surface) => {
      latestSurface = surface;
    });
    composer.registerSlots([
      { name: 'ride.estimate', input: '{}' },
      { name: 'luckin.order.preview', input: '{}' }
    ]);
    composer.emitShell();
    composer.markSlotError('slot_1', '瑞幸先返回');
    expect(latestSurface !== null).assertTrue();
    const document = createHtmlHomeDocument({
      surface: latestSurface!,
      messages: [],
      isBusy: true,
      isAwaitingFirstSurface: false
    });
    document.activeSectionId = 'slot_1';
    const payload = multiTaskHomePayloadJson(document, true);
    expect(payload.indexOf('"activeSectionId":"slot_1"')).assertLarger(-1);
    expect(payload.indexOf('"isBusy":true')).assertLarger(-1);
    expect(payload.indexOf('slot_1')).assertLarger(-1);
  });
  });
}
