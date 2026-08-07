import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import { A2uiSurfaceState, LeaderBimDashboardItem } from '@loop/agent-core';
import {
  BimContextSnapshot,
  BimRecord,
  BimRetrievalIndex,
  BimStore,
  createBimRecord,
  parseBimRecords,
  serializeBimRecords
} from '../main/ets/pages/A2uiHome/bim/BimStore';
import { bimDashboardItemsForDisplay, bimDashboardStatusLabel, bimDashboardStatusTone } from
  '../main/ets/pages/A2uiHome/components/BimDashboardView';

class MemoryPreferences {
  private values: Map<string, preferences.ValueType> = new Map();
  private failNextPut: boolean = false;
  failFlush: boolean = false;
  failRollbackWrite: boolean = false;
  flushErrorMessage: string = 'flush failed';

  getSync(key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    return this.values.has(key) ? this.values.get(key) as preferences.ValueType : defaultValue;
  }

  putSync(key: string, value: preferences.ValueType): void {
    if (this.failNextPut) {
      this.failNextPut = false;
      throw new Error('rollback write failed');
    }
    this.values.set(key, value);
  }

  flushSync(): void {
    if (this.failFlush) {
      if (this.failRollbackWrite) this.failNextPut = true;
      throw new Error(this.flushErrorMessage);
    }
  }
}

function nativePreferences(): preferences.Preferences {
  return new MemoryPreferences() as Object as preferences.Preferences;
}

function context(summary: string): BimContextSnapshot {
  return { summary, facts: [], constraints: [], decisions: [] };
}

function index(text: string): BimRetrievalIndex {
  return {
    summary: text, entities: [], timeAnchors: [], locations: [],
    commitments: [], keywords: text.split(' ')
  };
}

function surface(surfaceId: string, dataModelJson: string = '{}', args?: Object): string {
  const state: A2uiSurfaceState = {
    surfaceId, rootId: 'root', title: '当前安排', intent: 'travel', status: 'ready',
    components: [{ id: 'root', component: 'SurfaceRoot' }],
    dataModelJson, error: '', sequence: 1
  };
  if (args !== undefined) {
    state.components[0].actions = [{
      id: 'action-1', label: '继续', prompt: '继续', variant: 'primary', kind: 'submit', args
    }];
  }
  return JSON.stringify(state);
}

function toolSurface(
  surfaceId: string,
  toolName: string,
  marker: string,
  resultStatus: string = 'success'
): string {
  return surface(
    surfaceId,
    '{"summary":{"text":"' + marker + '","toolName":"' + toolName +
      '","dataLabel":"result","count":1},"genericToolResults":[{"sourceTag":"Provider","toolName":"' +
      toolName + '","title":"' + marker + '","status":"' + resultStatus + '","summary":"' + marker +
      '","rows":[],"rawPreview":""}]}'
  );
}

function record(id: string = 'bim-1'): BimRecord {
  return createBimRecord(
    id, '东京旅行', context('东京旅行'), index('东京旅行'),
    surface('surface-1'), '2026-08-03T10:00:00+08:00'
  );
}

export default function bimStoreTest() {
  describe('bimStore', () => {
    it('seeds the three demo matters without overwriting existing records', 0, () => {
      const native = nativePreferences();
      const store = new BimStore(native);
      const existing = record('user-matter');
      existing.title = '用户自己的事项';
      expect(store.create(existing)).assertTrue();

      expect(store.seedDemoRecordsIfMissing('2026-08-07T10:00:00+08:00')).assertTrue();
      const records = store.list();
      expect(records.length).assertEqual(4);
      expect(records.some((item: BimRecord): boolean => item.id === 'user-matter')).assertTrue();
      expect(records.some((item: BimRecord): boolean => item.title === '科目一')).assertTrue();
      expect(records.some((item: BimRecord): boolean => item.title === '南京婚宴')).assertTrue();
      expect(records.some((item: BimRecord): boolean => item.title === '旅行筹备')).assertTrue();
      expect(store.seedDemoRecordsIfMissing('2026-08-07T10:01:00+08:00')).assertFalse();
      expect(store.list().length).assertEqual(4);
    });

    it('seeds only progress and planning cards, never provider completion cards', 0, () => {
      const store = new BimStore(nativePreferences());
      expect(store.seedDemoRecordsIfMissing('2026-08-07T10:00:00+08:00')).assertTrue();
      const records = store.list();
      expect(records.length).assertEqual(3);
      for (let index = 0; index < records.length; index++) {
        const context = JSON.parse(records[index].contextJson) as BimContextSnapshot;
        const items = context.dashboardItems === undefined ? [] : context.dashboardItems;
        expect(items.length > 0).assertTrue();
        expect(items.some((item: LeaderBimDashboardItem): boolean =>
          item.kind === 'hotel' || item.kind === 'flight' || item.kind === 'transport' || item.kind === 'event'
        )).assertFalse();
      }
    });

    it('does not reseed a deleted demo matter after restart', 0, () => {
      const native = nativePreferences();
      const store = new BimStore(native);
      expect(store.seedDemoRecordsIfMissing('2026-08-07T10:00:00+08:00')).assertTrue();
      expect(store.markEnded('demo-bim-exam', '2026-08-07T10:01:00+08:00')).assertTrue();
      expect(store.deleteEnded('demo-bim-exam')).assertTrue();

      const restarted = new BimStore(native);
      expect(restarted.seedDemoRecordsIfMissing('2026-08-07T10:02:00+08:00')).assertFalse();
      expect(restarted.get('demo-bim-exam')).assertEqual(undefined);
      expect(restarted.get('demo-bim-wedding') === undefined).assertFalse();
      expect(restarted.get('demo-bim-travel') === undefined).assertFalse();
    });

    it('recovers from malformed persisted JSON', 0, () => {
      expect(parseBimRecords('{').length).assertEqual(0);
      expect(parseBimRecords('{"records":[]}').length).assertEqual(0);
    });

    it('persists valid records and returns defensive copies', 0, () => {
      const native = nativePreferences();
      const store = new BimStore(native);
      expect(store.create(record())).assertTrue();

      const read = store.get('bim-1');
      expect(read === undefined).assertFalse();
      if (read !== undefined) read.retrievalIndex.keywords[0] = 'changed';
      expect(new BimStore(native).get('bim-1')?.retrievalIndex.keywords[0]).assertEqual('东京旅行');
    });

    it('persists generic dashboard items as the latest BIM state', 0, () => {
      const current = record();
      const initialContext = JSON.parse(current.contextJson) as
        Record<string, Object | string | number | boolean | null>;
      initialContext['dashboardItems'] = JSON.parse(
        '[{"kind":"metric","title":"已确认","value":"49","detail":"位宾客","status":""},' +
          '{"kind":"person","title":"小王","value":"待确认","detail":"","status":"待回复"}]'
      ) as Object[];
      current.contextJson = JSON.stringify(initialContext);
      const store = new BimStore(nativePreferences());

      expect(store.create(current)).assertTrue();
      const saved = store.get('bim-1');
      expect(saved === undefined).assertFalse();
      if (saved !== undefined) {
        expect(saved.contextJson.indexOf('"title":"已确认"')).assertLarger(-1);
        expect(saved.contextJson.indexOf('"title":"小王"')).assertLarger(-1);
      }
    });

    it('keeps planning state but hides unconfirmed result cards', 0, () => {
      const items: LeaderBimDashboardItem[] = [
        { kind: 'metric', title: '已确认', value: '51', detail: '位宾客', status: '' },
        { kind: 'person', title: '李阿姨', value: '参加', detail: '素食', status: '已确认' },
        { kind: 'hotel', title: '成都酒店候选', value: '10月10日—13日', detail: '', status: '候选' },
        { kind: 'hotel', title: '成都酒店', value: '10月10日—13日', detail: '可取消', status: '已预订' },
        { kind: 'hotel', title: '重庆酒店', value: '10月14日—20日', detail: '可取消', status: 'confirmed' },
        { kind: 'flight', title: '重庆到南京', value: '10月20日', detail: '', status: '已出票' }
      ];

      const visible = bimDashboardItemsForDisplay(items);

      expect(visible.length).assertEqual(5);
      expect(visible.some((item: LeaderBimDashboardItem): boolean =>
        item.title === '成都酒店候选'
      )).assertFalse();
      expect(visible.some((item: LeaderBimDashboardItem): boolean =>
        item.title === '成都酒店'
      )).assertTrue();
      expect(visible.some((item: LeaderBimDashboardItem): boolean =>
        item.title === '重庆酒店'
      )).assertTrue();
      expect(bimDashboardStatusLabel('pending')).assertEqual('待补充');
      expect(bimDashboardStatusLabel('completed')).assertEqual('已完成');
      expect(bimDashboardStatusTone('不参加')).assertEqual('error');
    });

    it('maps every persistence exception to a stable safe category and clears it after success', 0, () => {
      const messages: string[] = [
        'write failed Bearer abcdef',
        'cookie=session-secret',
        'ordinary disk failure detail'
      ];
      for (let index = 0; index < messages.length; index++) {
        const native = new MemoryPreferences();
        const store = new BimStore(native as Object as preferences.Preferences);
        native.failFlush = true;
        native.flushErrorMessage = messages[index];

        expect(store.create(record())).assertFalse();
        expect(store.lastPersistenceError()).assertEqual('心上事本地存储写入失败');
        expect(store.lastPersistenceError().indexOf(messages[index])).assertEqual(-1);

        native.failFlush = false;
        expect(store.create(record())).assertTrue();
        expect(store.lastPersistenceError()).assertEqual('');
      }
    });

    it('reports validation failure without including rejected record values', 0, () => {
      const store = new BimStore(nativePreferences());
      const invalid = record();
      invalid.title = '';

      expect(store.create(invalid)).assertFalse();
      expect(store.lastPersistenceError()).assertEqual('心上事本地存储验证失败');
      expect(store.lastPersistenceError().indexOf('东京旅行')).assertEqual(-1);
    });

    it('rejects duplicate IDs in a document and on create', 0, () => {
      const duplicate = '[' + JSON.stringify(record()) + ',' + JSON.stringify(record()) + ']';
      expect(parseBimRecords(duplicate).length).assertEqual(0);
      expect(serializeBimRecords([record(), record()])).assertEqual('[]');

      const store = new BimStore(nativePreferences());
      expect(store.create(record())).assertTrue();
      expect(store.create(record())).assertFalse();
      expect(store.list().length).assertEqual(1);
    });

    it('rejects records with unknown top-level fields', 0, () => {
      const raw = '[' + JSON.stringify(record()).slice(0, -1) + ',"unexpected":true}]';

      expect(parseBimRecords(raw).length).assertEqual(0);
    });

    it('rejects normalized and non-ISO timestamps', 0, () => {
      const normalized = record();
      normalized.createdAt = '2026-02-30T10:00:00+08:00';
      const store = new BimStore(nativePreferences());

      expect(store.create(normalized)).assertFalse();
      expect(store.create(record())).assertTrue();
      expect(store.markEnded('bim-1', '0')).assertFalse();
    });

    it('rejects sensitive values in persisted surface data', 0, () => {
      const dataModelSecret = record();
      dataModelSecret.surfaceJson = surface('surface-1', '{"authorization":"Bearer token"}');
      const actionSecret = record('bim-2');
      actionSecret.surfaceJson = surface('surface-2', '{}', JSON.parse('{"cookie":"secret"}') as Object);
      const credentialSecret = record('bim-3');
      credentialSecret.surfaceJson = surface(
        'surface-3', '{}', JSON.parse('{"credentialValue":"secret"}') as Object
      );
      const clientSecret = record('bim-4');
      clientSecret.surfaceJson = surface('surface-4', '{"client_secret":"secret"}');
      const store = new BimStore(nativePreferences());

      expect(store.create(dataModelSecret)).assertFalse();
      expect(store.create(actionSecret)).assertFalse();
      expect(store.create(credentialSecret)).assertFalse();
      expect(store.create(clientSecret)).assertFalse();
      expect(store.list().length).assertEqual(0);
    });

    it('allows ordinary sensitive-looking string values without sensitive keys', 0, () => {
      const ordinary = record();
      ordinary.title = 'tokenization';
      ordinary.contextJson = JSON.stringify(context('cookie recipe'));
      ordinary.retrievalIndex.summary = 'secretary';
      ordinary.surfaceJson = surface(
        'surface-1', '{"note":"cookie recipe"}', JSON.parse('{"note":"tokenization"}') as Object
      );

      expect(new BimStore(nativePreferences()).create(ordinary)).assertTrue();
    });

    it('replaces context index and surface in one stored record', 0, () => {
      const native = nativePreferences();
      const store = new BimStore(native);
      const initial = record();
      expect(store.create(initial)).assertTrue();

      const ok = store.replaceCurrentState(
        'bim-1',
        context('东京旅行，机票待确认'),
        index('东京旅行 机票'),
        surface('surface-2'),
        [],
        '2026-08-03T11:00:00+08:00'
      );

      expect(ok).assertTrue();
      const saved = store.get('bim-1');
      expect(saved === undefined).assertFalse();
      if (saved !== undefined) {
        expect(saved.surfaceJson.indexOf('surface-2') >= 0).assertTrue();
        expect(saved.retrievalIndex.keywords[1]).assertEqual('机票');
        expect(saved.lastInteractionAt).assertEqual('2026-08-03T11:00:00+08:00');
      }
    });

    it('keeps only confirmed outcomes and one current surface per dashboard section', 0, () => {
      const store = new BimStore(nativePreferences());
      expect(store.create(record())).assertTrue();
      expect(store.replaceCurrentState(
        'bim-1', context('东京旅行，已有航班'), index('东京旅行 航班'),
        toolSurface('flight-1', 'flight.search', 'flight-current'), [],
        '2026-08-03T11:00:00+08:00'
      )).assertTrue();
      expect(store.replaceCurrentState(
        'bim-1', context('东京旅行，已有航班和酒店'), index('东京旅行 航班 酒店'),
        toolSurface('hotel-1', 'hotel.search', 'hotel-old'), [],
        '2026-08-03T12:00:00+08:00'
      )).assertTrue();
      expect(store.replaceCurrentState(
        'bim-1', context('东京旅行，酒店已更新'), index('东京旅行 航班 酒店'),
        toolSurface('hotel-2', 'hotel.search', 'hotel-current'), [],
        '2026-08-03T13:00:00+08:00'
      )).assertTrue();
      expect(store.replaceCurrentState(
        'bim-1', context('东京旅行，日程已创建'), index('东京旅行 日程'),
        toolSurface('calendar-1', 'calendar.event.create', 'calendar-old'), [],
        '2026-08-03T14:00:00+08:00'
      )).assertTrue();
      expect(store.replaceCurrentState(
        'bim-1', context('东京旅行，日程已更新'), index('东京旅行 日程'),
        toolSurface('calendar-2', 'calendar.event.update', 'calendar-current'), [],
        '2026-08-03T15:00:00+08:00'
      )).assertTrue();

      const serialized = JSON.parse(serializeBimRecords(store.list())) as Object[];
      const saved = serialized[0] as
        Record<string, Object | string | number | boolean | null | undefined>;
      const rawDashboard = saved['dashboardSurfaceJsons'];
      expect(Array.isArray(rawDashboard)).assertTrue();
      if (Array.isArray(rawDashboard)) {
        const dashboard = rawDashboard as string[];
        expect(dashboard.length).assertEqual(1);
        expect(dashboard.join('\n').indexOf('calendar-current')).assertLarger(-1);
        expect(dashboard.join('\n').indexOf('calendar-old')).assertEqual(-1);
        expect(dashboard.join('\n').indexOf('flight-current')).assertEqual(-1);
        expect(dashboard.join('\n').indexOf('hotel-current')).assertEqual(-1);
      }
    });

    it('filters a legacy query surface out of the dashboard', 0, () => {
      const current = record();
      const dashboardField = ',"dashboardSurfaceJsons":' + JSON.stringify([current.surfaceJson]);
      const legacyJson = JSON.stringify(current).replace(dashboardField, '');

      const parsed = parseBimRecords('[' + legacyJson + ']');
      const serialized = JSON.parse(serializeBimRecords(parsed)) as Object[];
      const saved = serialized[0] as
        Record<string, Object | string | number | boolean | null | undefined>;
      const rawDashboard = saved['dashboardSurfaceJsons'];

      expect(parsed.length).assertEqual(1);
      expect(Array.isArray(rawDashboard)).assertTrue();
      if (Array.isArray(rawDashboard)) {
        expect((rawDashboard as string[]).length).assertEqual(0);
      }
    });

    it('keeps a confirmed result when creating a heartboard', 0, () => {
      const confirmed = createBimRecord(
        'bim-confirmed', '东京旅行', context('东京旅行'), index('东京旅行'),
        toolSurface('calendar-1', 'calendar.event.create', 'calendar-created'),
        '2026-08-03T10:00:00+08:00'
      );

      expect(confirmed.dashboardSurfaceJsons?.length).assertEqual(1);
      expect(parseBimRecords(serializeBimRecords([confirmed])).length).assertEqual(1);
    });

    it('does not keep a confirmation preview as a completed result', 0, () => {
      const preview = createBimRecord(
        'bim-preview', '东京旅行', context('东京旅行'), index('东京旅行'),
        toolSurface('monitor-preview', 'web.monitor.create', '等待用户确认', 'confirm_required'),
        '2026-08-03T10:00:00+08:00'
      );

      expect(preview.dashboardSurfaceJsons?.length).assertEqual(0);
    });

    it('keeps prior retrieval signals when a model update returns empty index arrays', 0, () => {
      const store = new BimStore(nativePreferences());
      expect(store.create(record())).assertTrue();
      const sparse = index('东京旅行更新');
      sparse.keywords = [];

      expect(store.replaceCurrentState(
        'bim-1', context('东京旅行更新'), sparse, surface('surface-2'), [],
        '2026-08-03T11:00:00+08:00'
      )).assertTrue();

      expect(store.get('bim-1')?.retrievalIndex.keywords[0]).assertEqual('东京旅行');
    });

    it('wakes quiet and tucked records in the same current-state replacement', 0, () => {
      const store = new BimStore(nativePreferences());
      expect(store.create(record('bim-quiet'))).assertTrue();
      expect(store.create(record('bim-tucked'))).assertTrue();
      expect(store.applyLifecycleSweep([
        { id: 'bim-quiet', lifecycle: 'quiet' },
        { id: 'bim-tucked', lifecycle: 'tucked' }
      ], '2026-08-03T10:30:00+08:00')).assertTrue();

      expect(store.replaceCurrentState(
        'bim-quiet', context('quiet update'), index('quiet update'),
        surface('surface-quiet-update'), [], '2026-08-03T11:00:00+08:00'
      )).assertTrue();
      expect(store.replaceCurrentState(
        'bim-tucked', context('tucked update'), index('tucked update'),
        surface('surface-tucked-update'), [], '2026-08-03T11:10:00+08:00'
      )).assertTrue();

      expect(store.get('bim-quiet')?.lifecycle).assertEqual('active');
      expect(store.get('bim-quiet')?.endedAt).assertEqual(undefined);
      expect(store.get('bim-tucked')?.lifecycle).assertEqual('active');
      expect(store.get('bim-tucked')?.endedAt).assertEqual(undefined);
    });

    it('leaves an ended record ended when replacing its current state', 0, () => {
      const store = new BimStore(nativePreferences());
      expect(store.create(record())).assertTrue();
      expect(store.markEnded('bim-1', '2026-08-03T10:30:00+08:00')).assertTrue();

      expect(store.replaceCurrentState(
        'bim-1', context('ended update'), index('ended update'),
        surface('surface-ended-update'), [], '2026-08-03T11:00:00+08:00'
      )).assertTrue();

      expect(store.get('bim-1')?.lifecycle).assertEqual('ended');
      expect(store.get('bim-1')?.endedAt).assertEqual('2026-08-03T10:30:00+08:00');
    });

    it('keeps lifecycle and current state unchanged when a waking replacement cannot flush', 0, () => {
      const native = new MemoryPreferences();
      const store = new BimStore(native as Object as preferences.Preferences);
      expect(store.create(record())).assertTrue();
      expect(store.applyLifecycleSweep(
        [{ id: 'bim-1', lifecycle: 'quiet' }],
        '2026-08-03T10:30:00+08:00'
      )).assertTrue();
      native.failFlush = true;

      expect(store.replaceCurrentState(
        'bim-1', context('replacement'), index('replacement'),
        surface('surface-replacement'), [], '2026-08-03T11:00:00+08:00'
      )).assertFalse();

      const saved = store.get('bim-1');
      expect(saved === undefined).assertFalse();
      if (saved !== undefined) {
        expect(saved.lifecycle).assertEqual('quiet');
        expect(saved.contextJson).assertEqual(JSON.stringify(context('东京旅行')));
        expect(saved.retrievalIndex.summary).assertEqual('东京旅行');
        expect(saved.surfaceJson.indexOf('surface-1') >= 0).assertTrue();
        expect(saved.lastInteractionAt).assertEqual('2026-08-03T10:00:00+08:00');
      }
    });

    it('keeps valid relationship links within the same document', 0, () => {
      const store = new BimStore(nativePreferences());
      expect(store.create(record('bim-1'))).assertTrue();
      expect(store.create(record('bim-2'))).assertTrue();
      expect(store.replaceCurrentState(
        'bim-1', context('东京旅行'), index('东京旅行'), surface('surface-1'), ['bim-2'],
        '2026-08-03T11:00:00+08:00'
      )).assertTrue();
      expect(store.get('bim-1')?.relatedBimIds[0]).assertEqual('bim-2');
      expect(store.replaceCurrentState(
        'bim-1', context('东京旅行'), index('东京旅行'), surface('surface-1'), ['bim-1'],
        '2026-08-03T11:00:00+08:00'
      )).assertFalse();
      expect(store.get('bim-1')?.relatedBimIds[0]).assertEqual('bim-2');
    });

    it('ended records remain readable but leave automatic routing', 0, () => {
      const store = new BimStore(nativePreferences());
      store.create(record());

      expect(store.markEnded('bim-1', '2026-08-04T10:00:00+08:00')).assertTrue();
      expect(store.get('bim-1')?.lifecycle).assertEqual('ended');
      expect(store.get('bim-1')?.endedAt).assertEqual('2026-08-04T10:00:00+08:00');
      expect(store.reactivate('bim-1', '2026-08-05T10:00:00+08:00')).assertTrue();
      expect(store.get('bim-1')?.lifecycle).assertEqual('active');
      expect(store.get('bim-1')?.endedAt).assertEqual(undefined);
    });

    it('deletes only ended records', 0, () => {
      const store = new BimStore(nativePreferences());
      expect(store.create(record())).assertTrue();

      expect(store.deleteEnded('bim-1')).assertFalse();
      expect(store.markEnded('bim-1', '2026-08-04T10:00:00+08:00')).assertTrue();
      expect(store.deleteEnded('bim-1')).assertTrue();
      expect(store.get('bim-1')).assertEqual(undefined);
      expect(store.list().length).assertEqual(0);
    });

    it('applies valid lifecycle sweeps and preserves their metadata', 0, () => {
      const store = new BimStore(nativePreferences());
      store.create(record());

      expect(store.applyLifecycleSweep([{ id: 'bim-1', lifecycle: 'quiet' }],
        '2026-08-04T10:00:00+08:00')).assertTrue();
      expect(store.get('bim-1')?.lifecycle).assertEqual('quiet');
      expect(store.lastLifecycleSweepAt()).assertEqual('2026-08-04T10:00:00+08:00');
    });

    it('restores the prior document when flush fails', 0, () => {
      const native = new MemoryPreferences();
      const store = new BimStore(native as Object as preferences.Preferences);
      expect(store.create(record())).assertTrue();
      native.failFlush = true;

      expect(store.markEnded('bim-1', '2026-08-04T10:00:00+08:00')).assertFalse();
      expect(store.get('bim-1')?.lifecycle).assertEqual('active');
    });

    it('keeps the prior snapshot readable when rollback writes fail', 0, () => {
      const native = new MemoryPreferences();
      const store = new BimStore(native as Object as preferences.Preferences);
      expect(store.create(record())).assertTrue();
      native.failFlush = true;
      native.failRollbackWrite = true;

      expect(store.markEnded('bim-1', '2026-08-04T10:00:00+08:00')).assertFalse();
      expect(store.get('bim-1')?.lifecycle).assertEqual('active');
    });

    it('keeps prior sweep metadata after a failed rollback and later record save', 0, () => {
      const native = new MemoryPreferences();
      const store = new BimStore(native as Object as preferences.Preferences);
      expect(store.create(record())).assertTrue();
      expect(store.applyLifecycleSweep([{ id: 'bim-1', lifecycle: 'quiet' }],
        '2026-08-04T10:00:00+08:00')).assertTrue();
      native.failFlush = true;
      native.failRollbackWrite = true;

      expect(store.applyLifecycleSweep([{ id: 'bim-1', lifecycle: 'active' }],
        '2026-08-05T10:00:00+08:00')).assertFalse();
      native.failFlush = false;
      expect(store.markEnded('bim-1', '2026-08-06T10:00:00+08:00')).assertTrue();
      expect(store.lastLifecycleSweepAt()).assertEqual('2026-08-04T10:00:00+08:00');
      expect(new BimStore(native as Object as preferences.Preferences).lastLifecycleSweepAt())
        .assertEqual('2026-08-04T10:00:00+08:00');
    });
  });
}
