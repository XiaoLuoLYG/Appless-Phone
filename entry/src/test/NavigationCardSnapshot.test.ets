import { describe, it, expect } from '@ohos/hypium';
import { A2uiFoodData } from '../main/ets/model/A2uiTypes';
import {
  CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
  NAVIGATION_CARD_PIN_ACTION_ID,
  MemoryNavigationCardSnapshotStore,
  NavigationCardSnapshot,
  NavigationCardSnapshotBuildResult,
  buildEmptyNavigationCardBindingData,
  buildNavigationCardBindingData,
  canCreateNavigationCardFromFoodOption,
  navigationCardPinActionFromFoodOption,
  navigationCardFormEventFromMessage,
  navigationCardSnapshotExpired,
  navigationCardSnapshotFromFoodOption,
  sanitizeNavigationCardSourceTags
} from '../main/ets/model/NavigationCardSnapshot';

function foodOptionWithLocation(): A2uiFoodData {
  return {
    name: '喜茶(深圳坂田华创里店)',
    category: '饮品店',
    address: '深圳市龙岗区坂田街道华创里',
    distance: '860米',
    location: '116.397470,39.908823',
    sourceTags: ['高德', '高德', '', '腾讯地图']
  };
}

function readySnapshot(): NavigationCardSnapshot {
  const result = navigationCardSnapshotFromFoodOption(foodOptionWithLocation(), {
    surfaceId: 'surface_food',
    toolId: 'food.search',
    updatedAt: 1770000000000,
    expiresAt: 1770003600000
  });
  if (result.snapshot === undefined) {
    return {
      kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
      status: 'error',
      title: '',
      subtitle: '',
      address: '',
      location: '',
      sourceTags: [],
      mapUri: '',
      surfaceId: '',
      toolId: '',
      updatedAt: 0,
      expiresAt: 0,
      error: 'fixture failed'
    };
  }
  return result.snapshot;
}

export default function navigationCardSnapshotTest() {
  describe('navigationCardSnapshot', () => {
    it('creates a navigation destination snapshot from a real coordinate-backed food row', 0, () => {
      const result: NavigationCardSnapshotBuildResult = navigationCardSnapshotFromFoodOption(foodOptionWithLocation(), {
        surfaceId: 'surface_food',
        toolId: 'food.search',
        updatedAt: 1770000000000,
        expiresAt: 1770003600000
      });

      expect(result.ok).assertTrue();
      expect(result.error).assertEqual('');
      expect(result.snapshot === undefined).assertFalse();
      if (result.snapshot !== undefined) {
        expect(result.snapshot.kind).assertEqual(CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION);
        expect(result.snapshot.status).assertEqual('ready');
        expect(result.snapshot.title).assertEqual('喜茶(深圳坂田华创里店)');
        expect(result.snapshot.address).assertEqual('深圳市龙岗区坂田街道华创里');
        expect(result.snapshot.location).assertEqual('116.397470,39.908823');
        expect(result.snapshot.sourceTags.join('/')).assertEqual('高德/腾讯地图');
        expect(result.snapshot.mapUri).assertEqual('petalmaps://poidetail?center=39.908823,116.397470&z=16&marker=39.908823,116.397470&name=%E5%96%9C%E8%8C%B6%28%E6%B7%B1%E5%9C%B3%E5%9D%82%E7%94%B0%E5%8D%8E%E5%88%9B%E9%87%8C%E5%BA%97%29&utm_source=com.example.aiphonedemo');
      }
    });

    it('rejects food rows without real coordinates', 0, () => {
      const item = foodOptionWithLocation();
      item.location = '';
      const result = navigationCardSnapshotFromFoodOption(item, {
        surfaceId: 'surface_food',
        toolId: 'food.search',
        updatedAt: 1770000000000,
        expiresAt: 1770003600000
      });

      expect(result.ok).assertFalse();
      expect(result.error).assertEqual('缺少真实坐标，不能生成导航卡片');
      expect(result.snapshot === undefined).assertTrue();
    });

    it('deduplicates and limits source tags without inventing providers', 0, () => {
      expect(sanitizeNavigationCardSourceTags(['高德', '高德', '', '腾讯地图', '百度地图', '美团', '淘宝闪购']).join('/'))
        .assertEqual('高德/腾讯地图/百度地图/美团');
    });

    it('exposes a stable local pin action only for coordinate-backed food rows', 0, () => {
      const item = foodOptionWithLocation();
      expect(canCreateNavigationCardFromFoodOption(item)).assertTrue();
      expect(navigationCardPinActionFromFoodOption(item).id).assertEqual(NAVIGATION_CARD_PIN_ACTION_ID);
      expect(navigationCardPinActionFromFoodOption(item).kind).assertEqual('client');
      expect(navigationCardPinActionFromFoodOption(item).label).assertEqual('固定为导航卡片');

      item.location = '';
      expect(canCreateNavigationCardFromFoodOption(item)).assertFalse();
      expect(navigationCardPinActionFromFoodOption(item).id).assertEqual('');
    });

    it('maps ready, expired, error, and empty states to stable binding data', 0, () => {
      const ready = buildNavigationCardBindingData(readySnapshot(), 1770000100000);
      expect(ready.status).assertEqual('ready');
      expect(ready.title).assertEqual('喜茶(深圳坂田华创里店)');
      expect(ready.sourceText).assertEqual('高德 / 腾讯地图');
      expect(ready.primaryAction).assertEqual('open_map');
      expect(ready.secondaryAction).assertEqual('open_agent');

      const expired = buildNavigationCardBindingData(readySnapshot(), 1770007200000);
      expect(expired.status).assertEqual('expired');
      expect(expired.primaryAction).assertEqual('open_agent');
      expect(expired.message).assertEqual('导航卡片已过期，请回到 PocketAgent 刷新真实结果');

      const failed: NavigationCardSnapshot = readySnapshot();
      failed.status = 'error';
      failed.error = '地图 provider 未返回真实坐标';
      const error = buildNavigationCardBindingData(failed, 1770000100000);
      expect(error.status).assertEqual('error');
      expect(error.primaryAction).assertEqual('open_agent');
      expect(error.message).assertEqual('地图 provider 未返回真实坐标');

      const empty = buildEmptyNavigationCardBindingData();
      expect(empty.status).assertEqual('empty');
      expect(empty.primaryAction).assertEqual('open_agent');
      expect(empty.message).assertEqual('从 PocketAgent 对话生成导航卡片');
    });

    it('detects expiry by absolute timestamp', 0, () => {
      expect(navigationCardSnapshotExpired(readySnapshot(), 1770003599999)).assertFalse();
      expect(navigationCardSnapshotExpired(readySnapshot(), 1770003600000)).assertTrue();
    });

    it('stores one current snapshot and registered form ids in memory tests', 0, async () => {
      const store = new MemoryNavigationCardSnapshotStore();
      await store.saveSnapshot(readySnapshot());
      await store.addFormId('form-1');
      await store.addFormId('form-1');
      await store.addFormId('form-2');
      await store.removeFormId('form-1');

      const snapshot = await store.getSnapshot();
      expect(snapshot === null).assertFalse();
      if (snapshot !== null) {
        expect(snapshot.title).assertEqual('喜茶(深圳坂田华创里店)');
      }
      expect((await store.getFormIds()).join(',')).assertEqual('form-2');
    });

    it('accepts only supported card form events', 0, () => {
      expect(navigationCardFormEventFromMessage('open_map')).assertEqual('open_map');
      expect(navigationCardFormEventFromMessage('open_agent')).assertEqual('open_agent');
      expect(navigationCardFormEventFromMessage('refresh')).assertEqual('refresh');
      expect(navigationCardFormEventFromMessage('pay')).assertEqual('');
      expect(navigationCardFormEventFromMessage('{"action":"open_map"}')).assertEqual('open_map');
    });
  });
}
