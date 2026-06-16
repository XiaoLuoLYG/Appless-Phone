import { describe, it, expect } from '@ohos/hypium';
import { A2uiFoodData, A2uiTravelOptionData } from '../main/ets/model/A2uiTypes';
import { buildSystemFoodNavigationUri, foodMapsLatLng } from '../main/ets/model/FoodNavigation';
import {
  aggregateFoodProviderResults,
  buildToolGatewayUrl,
  defaultToolGatewayUrl,
  foodDistanceMeters,
  foodRecordFromBaiduPlace,
  foodRecordsFromLuckinMcpTool,
  foodRecordsFromMcDonaldsMcpTool,
  foodRecordFromMeituanUnion,
  foodRecordFromTencentMapPlace,
  foodRecordFromTaobaoFlashStore,
  isReadonlyBrandMcpTool,
  isLocalToolGatewayUrl,
  isRegisteredToolId,
  providerIssueRows,
  sortTravelOptionsByDeparture
} from '../main/ets/model/ToolGatewayClient';

export default function toolGatewayClientTest() {
  describe('toolGatewayClient', () => {
    it('defaults to the in-app local tool route', 0, () => {
      expect(defaultToolGatewayUrl()).assertEqual('local://aiphone-tools');
      expect(isLocalToolGatewayUrl(defaultToolGatewayUrl())).assertTrue();
      expect(buildToolGatewayUrl(defaultToolGatewayUrl())).assertEqual('local://aiphone-tools');
    });

    it('still supports explicit HTTP tool gateways', 0, () => {
      expect(isLocalToolGatewayUrl('http://127.0.0.1:8787')).assertFalse();
      expect(buildToolGatewayUrl('http://127.0.0.1:8787')).assertEqual('http://127.0.0.1:8787/api/aiphone/tool');
    });

    it('does not create a tool-specific override for provider tools', 0, () => {
      const endpoint = buildToolGatewayUrl(defaultToolGatewayUrl());
      expect(endpoint).assertEqual('local://aiphone-tools');
      expect(isLocalToolGatewayUrl(endpoint)).assertTrue();
    });

    it('registers unified travel search as a real query tool', 0, () => {
      expect(isRegisteredToolId('travel.search')).assertTrue();
      expect(isRegisteredToolId('train.search')).assertTrue();
      expect(isRegisteredToolId('flight.search')).assertTrue();
      expect(isRegisteredToolId('food.search')).assertTrue();
      expect(isRegisteredToolId('social.reply.send')).assertTrue();
    });

    it('keeps brand MCP adapters query-only', 0, () => {
      expect(isReadonlyBrandMcpTool('麦当劳', 'query-nearby-stores')).assertTrue();
      expect(isReadonlyBrandMcpTool('麦当劳', 'query-meals')).assertTrue();
      expect(isReadonlyBrandMcpTool('麦当劳', 'create-order')).assertFalse();
      expect(isReadonlyBrandMcpTool('麦当劳', 'auto-bind-coupons')).assertFalse();
      expect(isReadonlyBrandMcpTool('瑞幸', 'queryShopList')).assertTrue();
      expect(isReadonlyBrandMcpTool('瑞幸', 'searchProductForMcp')).assertTrue();
      expect(isReadonlyBrandMcpTool('瑞幸', 'createOrder')).assertFalse();
      expect(isReadonlyBrandMcpTool('瑞幸', 'cancelOrder')).assertFalse();
    });

    it('maps McDonalds MCP store and menu query payloads to food records', 0, () => {
      const stores = foodRecordsFromMcDonaldsMcpTool('query-nearby-stores', {
        data: [
          {
            storeName: '麦当劳深圳科技园餐厅',
            address: '深圳市南山区科苑路',
            distance: '320米',
            businessStatus: true,
            businessStartTime: '07:00',
            businessEndTime: '22:00'
          }
        ]
      });
      const meals = foodRecordsFromMcDonaldsMcpTool('query-meals', {
        data: {
          categories: [
            {
              name: '人气热卖',
              meals: [
                { code: '920215', tags: ['第二份半价'] }
              ]
            }
          ],
          meals: {
            '920215': {
              name: '培根安格斯厚牛堡大套餐',
              currentPrice: '55.5'
            }
          }
        }
      });

      expect(stores[0].name).assertEqual('麦当劳深圳科技园餐厅');
      expect(stores[0].category.indexOf('营业中')).assertLarger(-1);
      expect(stores[0].distance).assertEqual('320米');
      expect((stores[0].sourceTags === undefined ? [] : stores[0].sourceTags)[0]).assertEqual('麦当劳');
      expect(meals[0].name).assertEqual('麦当劳 · 培根安格斯厚牛堡大套餐');
      expect(meals[0].category.indexOf('¥55.5')).assertLarger(-1);
      expect(meals[0].address.indexOf('第二份半价')).assertLarger(-1);
    });

    it('maps Luckin MCP shop and product query payloads to food records', 0, () => {
      const shops = foodRecordsFromLuckinMcpTool('queryShopList', {
        data: [
          {
            deptName: '瑞幸咖啡 深圳科技园店',
            address: '深圳市南山区科技园',
            distance: 0.42,
            deptTags: ['可自提'],
            longitude: 114.0579,
            latitude: 22.5431
          }
        ]
      });
      const products = foodRecordsFromLuckinMcpTool('searchProductForMcp', {
        data: [
          {
            productName: '生椰拿铁',
            price: 19,
            skuCode: 'SKU001',
            productAttrs: [
              { attributeName: '温度', productSubAttrs: [{ attributeName: '冰', selected: true }] }
            ],
            tags: ['人气']
          }
        ]
      });

      expect(shops[0].name).assertEqual('瑞幸咖啡 深圳科技园店');
      expect(shops[0].category.indexOf('可自提')).assertLarger(-1);
      expect(shops[0].distance).assertEqual('420米');
      expect(shops[0].location).assertEqual('114.0579,22.5431');
      expect((shops[0].sourceTags === undefined ? [] : shops[0].sourceTags)[0]).assertEqual('瑞幸');
      expect(products[0].name).assertEqual('瑞幸 · 生椰拿铁');
      expect(products[0].category.indexOf('SKU001')).assertLarger(-1);
      expect(products[0].address.indexOf('温度:冰')).assertLarger(-1);
    });

    it('builds system map food destination search', 0, () => {
      expect(foodMapsLatLng('116.397470,39.908823')).assertEqual('39.908823,116.397470');
      expect(buildSystemFoodNavigationUri('116.397470,39.908823', '')).assertEqual('petalmaps://poidetail?center=39.908823,116.397470&z=16&marker=39.908823,116.397470&name=%E7%9B%AE%E7%9A%84%E5%9C%B0&utm_source=com.example.aiphonedemo');
      expect(buildSystemFoodNavigationUri('116.397470,39.908823', '116.398470,39.909823', '喜茶(深圳坂田华创里店)')).assertEqual('petalmaps://poidetail?center=39.908823,116.397470&z=16&marker=39.908823,116.397470&name=%E5%96%9C%E8%8C%B6%28%E6%B7%B1%E5%9C%B3%E5%9D%82%E7%94%B0%E5%8D%8E%E5%88%9B%E9%87%8C%E5%BA%97%29&utm_source=com.example.aiphonedemo');
    });

    it('sorts unified travel options by departure time', 0, () => {
      const rows: A2uiTravelOptionData[] = [
        {
          id: 'flight-empty',
          source: 'flight',
          sourceTag: '飞机 · 飞常准',
          title: '',
          from: 'BJS',
          to: 'SHA',
          depart: '',
          arrive: '',
          duration: '',
          price: '',
          availability: '',
          status: '计划',
          detail: '缺少时间'
        },
        {
          id: 'train-early',
          source: 'train',
          sourceTag: '高铁 · 12306',
          title: 'G5',
          from: '北京南',
          to: '上海虹桥',
          depart: '06:30',
          arrive: '12:00',
          duration: '5小时30分',
          price: '',
          availability: '二等座有票',
          status: '可查',
          detail: '真实高铁'
        },
        {
          id: 'train-fast',
          source: 'train',
          sourceTag: '高铁 · 12306',
          title: 'G1',
          from: '北京南',
          to: '上海虹桥',
          depart: '09:00',
          arrive: '13:28',
          duration: '4小时28分',
          price: '',
          availability: '二等座有票',
          status: '可查',
          detail: '真实高铁'
        },
        {
          id: 'flight-priced',
          source: 'flight',
          sourceTag: '飞机 · 飞常准',
          title: 'MU5101',
          from: 'BJS',
          to: 'SHA',
          depart: '07:00',
          arrive: '09:15',
          duration: '2小时15分',
          price: '¥680',
          availability: '',
          status: '计划',
          detail: '真实航班'
        }
      ];

      const sorted = sortTravelOptionsByDeparture(rows);
      expect(sorted[0].id).assertEqual('train-early');
      expect(sorted[1].id).assertEqual('flight-priced');
      expect(sorted[3].id).assertEqual('flight-empty');
    });

    it('maps Meituan union delivery coupon results to food records', 0, () => {
      const record = foodRecordFromMeituanUnion({
        brandInfo: {
          brandName: '茶百道',
          brandLogoUrl: 'https://example.test/logo.png'
        },
        couponPackDetail: {
          name: '双杯奶茶套餐兑换券',
          sellPrice: '19.90',
          saleVolume: '10000+'
        },
        deliverablePoiInfo: {
          poiName: '茶百道 深圳科技园店',
          deliveryDistance: '1.2',
          distributionCost: '3.0',
          deliveryDuration: '30',
          lastDeliveryFee: '20'
        }
      });

      expect(record.name).assertEqual('茶百道 深圳科技园店');
      expect(record.category.indexOf('双杯奶茶套餐兑换券')).assertLarger(-1);
      expect(record.address.indexOf('配送费3.0元')).assertLarger(-1);
      expect(record.distance).assertEqual('1.2千米');
      const tags = record.sourceTags === undefined ? [] : record.sourceTags;
      expect(tags[0]).assertEqual('美团');
    });

    it('maps Taobao flash store promotion results to food records', 0, () => {
      const record = foodRecordFromTaobaoFlashStore({
        title: '肯德基 科技园店',
        category_1_name: '全球美食',
        delivery_distance: 820,
        delivery_time: 34,
        delivery_price: '4.0',
        service_rating: '4.6',
        items: [
          {
            title: '香辣鸡腿堡套餐',
            price: '29.9'
          }
        ]
      });

      expect(record.name).assertEqual('肯德基 科技园店');
      expect(record.category.indexOf('香辣鸡腿堡套餐')).assertLarger(-1);
      expect(record.address.indexOf('评分4.6')).assertLarger(-1);
      expect(record.distance).assertEqual('820米');
      const tags = record.sourceTags === undefined ? [] : record.sourceTags;
      expect(tags[0]).assertEqual('淘宝闪购');
    });

    it('maps Tencent map nearby POI results to food records', 0, () => {
      const record = foodRecordFromTencentMapPlace({
        title: '瑞幸咖啡 深圳科技园店',
        category: '美食:咖啡厅',
        address: '深圳市南山区科技园',
        _distance: 230,
        location: {
          lat: 22.5431,
          lng: 114.0579
        }
      });

      expect(record.name).assertEqual('瑞幸咖啡 深圳科技园店');
      expect(record.category).assertEqual('美食:咖啡厅');
      expect(record.address).assertEqual('深圳市南山区科技园');
      expect(record.distance).assertEqual('230米');
      expect(record.location).assertEqual('114.0579,22.5431');
      const tags = record.sourceTags === undefined ? [] : record.sourceTags;
      expect(tags[0]).assertEqual('腾讯地图');
    });

    it('maps Baidu place nearby POI results to food records', 0, () => {
      const record = foodRecordFromBaiduPlace({
        name: '星巴克 深圳科技园店',
        address: '深圳市南山区科苑路',
        location: {
          lat: 22.544,
          lng: 114.058
        },
        detail_info: {
          tag: '美食;咖啡厅',
          distance: 410,
          overall_rating: '4.5'
        }
      });

      expect(record.name).assertEqual('星巴克 深圳科技园店');
      expect(record.category.indexOf('美食;咖啡厅')).assertLarger(-1);
      expect(record.address.indexOf('评分4.5')).assertLarger(-1);
      expect(record.distance).assertEqual('410米');
      expect(record.location).assertEqual('114.058,22.544');
      const tags = record.sourceTags === undefined ? [] : record.sourceTags;
      expect(tags[0]).assertEqual('百度地图');
    });

    it('parses food distance text for local range filters', 0, () => {
      expect(foodDistanceMeters('832米')).assertEqual(832);
      expect(foodDistanceMeters('1.2千米')).assertEqual(1200);
      expect(foodDistanceMeters('0.85公里')).assertEqual(850);
    });

    it('deduplicates food results and merges source tags without fake rows', 0, () => {
      const amap: A2uiFoodData = {
        name: '喜茶 深圳科技园店',
        category: '餐饮服务',
        address: '南山科技园',
        distance: '120米',
        sourceTags: ['高德']
      };
      const meituan: A2uiFoodData = {
        name: '喜茶深圳科技园店',
        category: '芝芝莓莓',
        address: '配送费3元 · 预计28分钟',
        distance: '0.1千米',
        sourceTags: ['美团']
      };

      const merged = aggregateFoodProviderResults([
        { provider: '高德', foods: [amap], error: '' },
        { provider: '美团', foods: [meituan], error: '' },
        { provider: '腾讯地图', foods: [{ name: '喜茶-深圳科技园店', category: '美食', address: '科技园', distance: '100米', sourceTags: ['腾讯地图'] }], error: '' },
        { provider: '淘宝闪购', foods: [], error: '未配置 TAOBAO_APP_KEY' }
      ]);

      expect(merged.foods.length).assertEqual(1);
      const tags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;
      expect(tags.length).assertEqual(3);
      expect(tags[0]).assertEqual('高德');
      expect(tags[1]).assertEqual('美团');
      expect(tags[2]).assertEqual('腾讯地图');
      expect(providerIssueRows(merged.issues)[0].label).assertEqual('淘宝闪购');
    });

    it('merges the same store when map providers include different city prefixes', 0, () => {
      const merged = aggregateFoodProviderResults([
        {
          provider: '高德',
          foods: [{
            name: '茶百道(北京东城故宫东华门店)',
            category: '餐饮服务;冷饮店;冷饮店',
            address: '北京城区东华门大街83号2幢',
            distance: '832米',
            sourceTags: ['高德']
          }],
          error: ''
        },
        {
          provider: '腾讯地图',
          foods: [{
            name: '茶百道(东城故宫东华门店)',
            category: '美食:冷饮店',
            address: '北京市东城区东华门大街83号2幢',
            distance: '835.32米',
            sourceTags: ['腾讯地图']
          }],
          error: ''
        }
      ]);

      expect(merged.foods.length).assertEqual(1);
      expect(merged.foods[0].distance).assertEqual('832米');
      const tags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;
      expect(tags.length).assertEqual(2);
      expect(tags[0]).assertEqual('高德');
      expect(tags[1]).assertEqual('腾讯地图');
    });

    it('merges the same store when one map address includes street direction words', 0, () => {
      const merged = aggregateFoodProviderResults([
        {
          provider: '高德',
          foods: [{
            name: '蜜雪冰城(东华门大街店)',
            category: '餐饮服务;冷饮店;冷饮店',
            address: '东华门大街56号',
            distance: '863米',
            sourceTags: ['高德']
          }],
          error: ''
        },
        {
          provider: '腾讯地图',
          foods: [{
            name: '蜜雪冰城(故宫东门店)',
            category: '美食:冷饮店',
            address: '北京市东城区东华门街道东华门大街路南56号',
            distance: '860.31米',
            sourceTags: ['腾讯地图']
          }],
          error: ''
        }
      ]);

      expect(merged.foods.length).assertEqual(1);
      expect(merged.foods[0].distance).assertEqual('860.31米');
      const tags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;
      expect(tags.indexOf('高德')).assertLarger(-1);
      expect(tags.indexOf('腾讯地图')).assertLarger(-1);
    });

    it('orders merged-source food results first and then by distance', 0, () => {
      const merged = aggregateFoodProviderResults([
        {
          provider: '高德',
          foods: [
            {
              name: '近距离单源店',
              category: '餐饮服务',
              address: '近距离地址',
              distance: '50米',
              sourceTags: ['高德']
            },
            {
              name: '远距离多源店',
              category: '餐饮服务',
              address: '远距离地址',
              distance: '500米',
              sourceTags: ['高德']
            },
            {
              name: '近距离多源店',
              category: '餐饮服务',
              address: '近多源地址',
              distance: '200米',
              sourceTags: ['高德']
            }
          ],
          error: ''
        },
        {
          provider: '百度地图',
          foods: [
            {
              name: '远距离多源店',
              category: '美食',
              address: '远距离地址',
              distance: '480米',
              sourceTags: ['百度地图']
            },
            {
              name: '近距离多源店',
              category: '美食',
              address: '近多源地址',
              distance: '210米',
              sourceTags: ['百度地图']
            }
          ],
          error: ''
        }
      ]);

      expect(merged.foods[0].name).assertEqual('近距离多源店');
      expect(merged.foods[1].name).assertEqual('远距离多源店');
      expect(merged.foods[2].name).assertEqual('近距离单源店');
    });

    it('keeps later map provider tags visible when Amap fills the limit first', 0, () => {
      const amapFoods: A2uiFoodData[] = [];
      for (let index = 0; index < 8; index++) {
        amapFoods.push({
          name: index === 0 ? '茶百道(北京东城故宫东华门店)' : '高德餐饮 ' + index.toString(),
          category: '餐饮服务',
          address: index === 0 ? '北京城区东华门大街83号2幢' : '高德地址 ' + index.toString(),
          distance: (100 + index).toString() + '米',
          sourceTags: ['高德']
        });
      }

      const merged = aggregateFoodProviderResults([
        { provider: '高德', foods: amapFoods, error: '' },
        {
          provider: '腾讯地图',
          foods: [{
            name: '茶百道(东城故宫东华门店)',
            category: '美食:冷饮店',
            address: '北京市东城区东华门大街83号2幢',
            distance: '110米',
            sourceTags: ['腾讯地图']
          }],
          error: ''
        },
        {
          provider: '百度地图',
          foods: [{
            name: '茶百道(东城故宫东华门店)',
            category: '美食;冷饮店',
            address: '北京市东城区东华门大街83号2幢',
            distance: '120米',
            sourceTags: ['百度地图']
          }],
          error: ''
        }
      ]);

      expect(merged.foods.length).assertEqual(8);
      const firstTags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;
      expect(firstTags.indexOf('高德')).assertLarger(-1);
      expect(firstTags.indexOf('腾讯地图')).assertLarger(-1);
      expect(firstTags.indexOf('百度地图')).assertLarger(-1);
    });

    it('keeps more than the default visible food rows for client show more', 0, () => {
      const amapFoods: A2uiFoodData[] = [];
      const tencentFoods: A2uiFoodData[] = [];
      for (let index = 0; index < 10; index++) {
        amapFoods.push({
          name: '高德餐饮 ' + index.toString(),
          category: '餐饮服务',
          address: '高德地址 ' + index.toString(),
          distance: (100 + index).toString() + '米',
          sourceTags: ['高德']
        });
        tencentFoods.push({
          name: '腾讯餐饮 ' + index.toString(),
          category: '美食',
          address: '腾讯地址 ' + index.toString(),
          distance: (300 + index).toString() + '米',
          sourceTags: ['腾讯地图']
        });
      }

      const merged = aggregateFoodProviderResults([
        { provider: '高德', foods: amapFoods, error: '' },
        { provider: '腾讯地图', foods: tencentFoods, error: '' }
      ]);

      expect(merged.foods.length).assertLarger(8);
    });

    it('keeps legacy food records without source tags renderable', 0, () => {
      const legacy: A2uiFoodData = {
        name: '老乡鸡 科技园店',
        category: '中式快餐',
        address: '科技园',
        distance: '300米'
      };
      const merged = aggregateFoodProviderResults([
        { provider: '高德', foods: [legacy], error: '' }
      ]);
      const tags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;

      expect(merged.foods.length).assertEqual(1);
      expect(tags[0]).assertEqual('高德');
    });
  });
}
